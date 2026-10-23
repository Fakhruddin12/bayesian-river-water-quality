# This file fits the two GAMs for each site and determinand.
# It compares their test performance and calculates randomised quantile residual diagnostics.

library(tidyverse)
library(mgcv)

model_data <- readRDS("data/processed/model_data_split.rds")
dir.create("output/gam_models", recursive = TRUE, showWarnings = FALSE)

# Calculates the log-likelihood contribution for every observation.
# It handles exact, left-censored and interval-censored concentration measurements.
gam_loglik <- function(data, mu, sigma) {
  value <- numeric(nrow(data))
  exact <- data$day_type == "all exact"
  left <- data$day_type == "all censored"
  interval <- data$day_type == "mixed"

  value[exact] <- dnorm(data$log10_upper[exact], mu[exact], sigma,
                        log = TRUE)
  value[left] <- pnorm(data$log10_upper[left], mu[left], sigma,
                       log.p = TRUE)

  if (any(interval)) {
    probability <- pnorm(data$log10_upper[interval], mu[interval], sigma) -
      pnorm(data$log10_lower[interval], mu[interval], sigma)
    value[interval] <- log(pmax(probability, .Machine$double.xmin))
  }

  value
}

# Calculates randomised quantile residuals using the GAM predictions and standard deviation.
# It returns one residual for each exact or censored observation.
gam_rqr <- function(data, mu, sigma) {
  p <- numeric(nrow(data))
  exact <- data$day_type == "all exact"
  left <- data$day_type == "all censored"
  interval <- data$day_type == "mixed"

  p[exact] <- pnorm(data$log10_upper[exact], mu[exact], sigma)
  p[left] <- data$rqr_random[left] *
    pnorm(data$log10_upper[left], mu[left], sigma)
  p[interval] <- pnorm(data$log10_lower[interval], mu[interval], sigma) +
    data$rqr_random[interval] *
    (pnorm(data$log10_upper[interval], mu[interval], sigma) -
       pnorm(data$log10_lower[interval], mu[interval], sigma))

  qnorm(pmin(pmax(p, 1e-10), 1 - 1e-10))
}

groups <- distinct(model_data, site_name, determinand)
models <- list()
metrics <- list()
diagnostics <- list()
predictions <- list()
k <- 1

for (i in 1:nrow(groups)) {
  site <- groups$site_name[i]
  det <- groups$determinand[i]
  train <- filter(model_data, site_name == site, determinand == det,
                  split == "train")
  test <- filter(model_data, site_name == site, determinand == det,
                 split == "test") %>% arrange(date)

  model_1 <- gam(
    cbind(cnorm_first, cnorm_second) ~
      s(decimal_date, k = 20) + s(month_num, bs = "cc", k = 12),
    family = cnorm(), data = train, method = "REML",
    knots = list(month_num = c(0.5, 12.5))
  )

  model_2 <- gam(
    cbind(cnorm_first, cnorm_second) ~
      s(decimal_date, k = 20) + s(month_num, bs = "cc", k = 12) +
      s(log10_flow, k = 8),
    family = cnorm(), data = train, method = "REML",
    knots = list(month_num = c(0.5, 12.5))
  )

  group_models <- list(time_season = model_1,
                       time_season_flow = model_2)
  models[[paste(site, det, sep = "__")]] <- group_models

  for (model_name in names(group_models)) {
    model <- group_models[[model_name]]
    mu <- predict(model, newdata = test, type = "response")
    sigma <- model$family$getTheta(trans = TRUE)
    loglik <- gam_loglik(test, mu, sigma)
    rqr <- gam_rqr(test, mu, sigma)
    exact <- test$day_type == "all exact"

    metrics[[k]] <- tibble(
      site_name = site, determinand = det, model = model_name,
      mean_test_nll = -mean(loglik),
      mae_log10 = mean(abs(test$log10_upper[exact] - mu[exact])),
      rmse_log10 = sqrt(mean((test$log10_upper[exact] - mu[exact])^2)),
      bias_log10 = mean(mu[exact] - test$log10_upper[exact])
    )

    diagnostics[[k]] <- tibble(
      site_name = site, determinand = det, model = model_name,
      mean_rqr = mean(rqr), sd_rqr = sd(rqr),
      percent_outside_95 = 100 * mean(abs(rqr) > 1.96)
    )

    predictions[[k]] <- test %>%
      mutate(model = model_name, predicted_log10 = mu, rqr = rqr)
    k <- k + 1
  }

  cat("Completed:", site, "|", det, "\n")
}

metric_results <- bind_rows(metrics)
diagnostic_results <- bind_rows(diagnostics)
test_predictions <- bind_rows(predictions)
overall_metrics <- metric_results %>%
  group_by(model) %>%
  summarise(mean_nll = mean(mean_test_nll),
            mean_mae = mean(mae_log10),
            mean_rmse = mean(rmse_log10),
            mean_bias = mean(bias_log10), .groups = "drop")

pdf("output/gam_models/rqr_qq_plots.pdf", width = 10, height = 5)
for (i in 1:nrow(groups)) {
  par(mfrow = c(1, 2))
  for (model_name in c("time_season", "time_season_flow")) {
    x <- test_predictions %>%
      filter(site_name == groups$site_name[i],
             determinand == groups$determinand[i],
             model == model_name) %>%
      pull(rqr)
    qqnorm(x, main = paste(groups$site_name[i],
                           groups$determinand[i], model_name, sep = " | "))
    qqline(x)
  }
}
dev.off()

saveRDS(list(models = models, metrics = metric_results,
             overall_metrics = overall_metrics,
             diagnostics = diagnostic_results,
             test_predictions = test_predictions),
        "output/gam_models/gam_results.rds")

print(metric_results , n = 46)
print(overall_metrics)
print(diagnostic_results , n = 46)
