library(tidyverse)
library(lubridate)

set.seed(123)

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
dir.create("output/eda", recursive = TRUE, showWarnings = FALSE)
source("import_hde_function.R")
source("import_wq_function.R")

sites <- tribble(
  ~site_name,                       ~conc_site,    ~flow_site,
  "Thames_at_Ted",                  "TH-PTHR0107", "3400TH",
  "Severn_Haw_Bridge",              "MD-00025085", "2606",
  "Tees_Low_Worsall",               "NE-45400013", "F3606",
  "Eden_Sheepmount",                "NW-88006427", "765512",
  "Trent_Dunham",                   "MD-36701570", "4022",
  "Wensum Sweet Briar Road Bridge", "AN-WEN250",   "034001"
)

determinand_names <- tribble(
  ~determinand_code, ~determinand,
  "0180", "Orthophosphate",
  "3408", "Dissolved Zinc",
  "0111", "Ammonia",
  "0117", "Nitrate"
)

conc_list <- list()
flow_list <- list()

for (i in 1:nrow(sites)) {
  conc_list[[i]] <- import_wq(
    sites = sites$conc_site[i],
    dets = determinand_names$determinand_code,
    start_date = "2000-01-01",
    end_date = Sys.Date(),
    save = FALSE
  ) %>%
    mutate(site_name = sites$site_name[i])

  flow_list[[i]] <- import_hde(
    sites = sites$flow_site[i],
    start_date = "2000-01-01",
    end_date = Sys.Date()
  ) %>%
    mutate(site_name = sites$site_name[i])
}

concentration_raw <- bind_rows(conc_list)
flow_raw <- bind_rows(flow_list)

saveRDS(concentration_raw, "data/raw/concentration_raw.rds")
saveRDS(flow_raw, "data/raw/flow_raw.rds")
nrow(concentration_raw)
unique(concentration_raw$determinand)
# Prepare the concentration measurements.
concentration <- concentration_raw %>%
  transmute(
    site_name,
    determinand_raw = as.character(determinand),
    date_time = as.character(date_time),
    date = as.Date(sub(" .*", "", date_time)),
    result = as.numeric(result),
    qualifier = na_if(trimws(as.character(qualifier)), "")
  ) %>%
  mutate(
    # Extract the determinand code and restore leading zeros.
    determinand_code = str_extract(determinand_raw, "[0-9]+"),
    determinand_code = str_pad(determinand_code, width = 4, pad = "0")
  ) %>%
  left_join(determinand_names, by = "determinand_code") %>%
  mutate(
    # Keep the original determinand name if the lookup is unnecessary.
    determinand = coalesce(determinand, determinand_raw),
    is_exact = is.na(qualifier),
    is_censored = !is.na(qualifier) & qualifier == "<"
  ) %>%
  filter(
    !is.na(date),
    date <= as.Date("2025-12-31"),
    !is.na(result),
    result > 0,
    !is.na(determinand_raw)
  ) %>%
  distinct(
    site_name,
    determinand,
    date_time,
    result,
    qualifier,
    .keep_all = TRUE
  )

if (any(!is.na(concentration$qualifier) & concentration$qualifier != "<")) {
  stop("A qualifier other than NA or '<' was found.")
}
# Filtering data

concentration <- concentration %>%
  mutate(
    is_exact = is.na(qualifier),
    is_censored = !is.na(qualifier) & qualifier == "<"
  ) %>%
  filter(
    !is.na(date),
    date <= as.Date("2025-12-31"),
    !is.na(result),
    result > 0,
    !is.na(determinand)
  ) %>%
  distinct(site_name, determinand, date_time, result, qualifier,
           .keep_all = TRUE)

# Repeated samples on one day are converted into one daily observation.
concentration
daily_concentration <- concentration %>%
  group_by(site_name, determinand, date) %>%
  summarise(
    n_samples = n(),
    n_exact = sum(is_exact),
    n_censored = sum(is_censored),
    exact_sum = sum(result[is_exact]),
    daily_upper = mean(result),
    .groups = "drop"
  ) %>%
  mutate(
    day_type = case_when(
      n_exact == n_samples ~ "all exact",
      n_censored == n_samples ~ "all censored",
      TRUE ~ "mixed"
    ),
    daily_lower = case_when(
      day_type == "all exact" ~ daily_upper,
      day_type == "mixed" ~ exact_sum / n_samples,
      TRUE ~ NA_real_
    ),
    log10_lower = if_else(is.na(daily_lower), NA_real_, log10(daily_lower)),
    log10_upper = log10(daily_upper),
    log10_result_exact = if_else(
      day_type == "all exact", log10(daily_upper), NA_real_
    )
  ) %>%
  select(-exact_sum)


daily_flow <- flow_raw %>%
  transmute(
    site_name,
    date = as.Date(sub(" .*", "", as.character(date))),
    flow = as.numeric(flow)
  ) %>%
  filter(date <= as.Date("2025-12-31")) %>%
  group_by(site_name, date) %>%
  summarise(flow = mean(flow, na.rm = TRUE), .groups = "drop") %>%
  filter(is.finite(flow), flow > 0)

model_data_daily <- daily_concentration %>%
  left_join(daily_flow, by = c("site_name", "date")) %>%
  filter(is.finite(flow), flow > 0) %>%
  mutate(
    log10_flow = log10(flow),
    month_num = month(date),
    decimal_date = decimal_date(date)
  )

saveRDS(daily_concentration, "data/processed/daily_concentration.rds")
saveRDS(model_data_daily, "data/processed/model_data_daily.rds")

group_counts <- model_data_daily %>%
  count(site_name, determinand, name = "n_observations")

excluded_groups <- group_counts %>% filter(n_observations < 30)

model_data <- model_data_daily %>%
  anti_join(excluded_groups, by = c("site_name", "determinand")) %>%
  mutate(
    cnorm_first = case_when(
      day_type == "all exact" ~ log10_upper,
      day_type == "all censored" ~ log10_upper,
      day_type == "mixed" ~ log10_lower
    ),
    cnorm_second = case_when(
      day_type == "all exact" ~ log10_upper,
      day_type == "all censored" ~ -Inf,
      day_type == "mixed" ~ log10_upper
    )
  )

stopifnot(
  nrow(model_data %>% count(site_name, determinand, date) %>% filter(n > 1)) == 0
)

model_data_split <- model_data %>%
  arrange(site_name, determinand, date) %>%
  group_by(site_name, determinand) %>%
  mutate(
    row_number = row_number(),
    train_end = floor(0.80 * n()),
    split = if_else(row_number <= train_end, "train", "test")
  ) %>%
  ungroup() %>%
  select(-row_number, -train_end) %>%
  mutate(rqr_random = runif(n()))

saveRDS(model_data_split, "data/processed/model_data_split.rds")

eda_summary <- model_data_daily %>%
  group_by(determinand, site_name) %>%
  summarise(
    n_observations = n(),
    first_date = min(date),
    last_date = max(date),
    percent_censored = 100 * mean(day_type != "all exact"),
    .groups = "drop"
  )

write_csv(eda_summary, "output/eda/eda_summary.csv")

p1 <- ggplot(model_data_daily, aes(date, daily_upper, shape = day_type)) +
  geom_point(alpha = 0.5, size = 0.8) +
  scale_y_log10() +
  facet_grid(determinand ~ site_name, scales = "free_y") +
  labs(x = NULL, y = "Concentration or upper limit", shape = NULL) +
  theme_minimal()

ggsave("output/eda/concentration_through_time.png", p1,
       width = 18, height = 12, dpi = 300)

p2 <- ggplot(model_data_daily, aes(log10_flow, log10_upper,
                                   shape = day_type)) +
  geom_point(alpha = 0.5, size = 0.8) +
  facet_grid(determinand ~ site_name, scales = "free") +
  labs(x = "log10(flow)", y = "log10(concentration or upper limit)",
       shape = NULL) +
  theme_minimal()

ggsave("output/eda/concentration_against_flow.png", p2,
       width = 18, height = 12, dpi = 300)

p3 <- model_data_daily %>%
  filter(day_type == "all exact") %>%
  ggplot(aes(factor(month_num), log10_result_exact)) +
  geom_boxplot(outlier.shape = NA) +
  facet_grid(determinand ~ site_name, scales = "free_y") +
  labs(x = "Month", y = "log10(exact concentration)") +
  theme_minimal()

ggsave("output/eda/monthly_seasonality.png", p3,
       width = 18, height = 12, dpi = 300)

print(eda_summary)
print(excluded_groups)
print(count(model_data_split, split, day_type))
