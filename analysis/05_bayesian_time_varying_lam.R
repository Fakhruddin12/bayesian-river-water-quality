# This file fits the Bayesian time-varying LAM separately for each site and determinand.
# It models total concentration and point-source share with smooth time splines and a monthly seasonal effect.
# It saves parameter trajectories, test metrics, uncertainty intervals and sampler diagnostics.

library(tidyverse)
library(brms)
library(posterior)

options(mc.cores = 4)
set.seed(25062026)

model_data <- readRDS("data/processed/model_data_split.rds")
dir.create("output/bayesian_time_varying_lam/fits", recursive = TRUE,
           showWarnings = FALSE)

# Total concentration and point-source share vary smoothly through time.
lam_formula <- bf(
  response | cens(censor_type, response_upper) ~
    logtotal + seasonal +
    log10(
      (1 / (1 + exp(-logitshare))) *
        exp(((1 / (1 + exp(-braw))) - 1) * log_q_ratio) +
        (1 - (1 / (1 + exp(-logitshare)))) *
        exp(exp(drawpar) * log_q_ratio)
    ),
  logtotal ~ 0 + Intercept + s(time_scaled, k = 8, bs = "tp"),
  logitshare ~ 0 + Intercept + s(time_scaled, k = 8, bs = "tp"),
  seasonal ~ 0 + s(month_cycle, k = 6, bs = "cc"),
  braw ~ 0 + Intercept,
  drawpar ~ 0 + Intercept,
  nl = TRUE
)

priors <- c(
  set_prior("normal(0, 2)", class = "b", nlpar = "logtotal"),
  set_prior("normal(0, 1.5)", class = "b", nlpar = "logitshare"),
  set_prior("normal(0, 1.5)", class = "b", nlpar = "braw"),
  set_prior("normal(log(0.3), 1)", class = "b", nlpar = "drawpar"),
  set_prior("normal(0, 0.5)", class = "sds", nlpar = "logtotal"),
  set_prior("normal(0, 0.75)", class = "sds", nlpar = "logitshare"),
  set_prior("normal(0, 0.25)", class = "sds", nlpar = "seasonal"),
  set_prior("student_t(3, 0, 0.5)", class = "sigma")
)

# Calculates log(mean(exp(x))) in a numerically stable way.
# It is used to average the test log-likelihood across posterior draws.
log_mean_exp <- function(x) {
  m <- max(x)
  m + log(mean(exp(x - m)))
}

# Calculates randomised quantile residuals from posterior predictive draws.
# It returns one residual for each exact or censored observation.
bayesian_rqr <- function(data, draws) {
  lower_cdf <- colMeans(sweep(draws, 2, data$log10_lower, "<="))
  upper_cdf <- colMeans(sweep(draws, 2, data$log10_upper, "<="))
  p <- numeric(nrow(data))

  exact <- data$day_type == "all exact"
  left <- data$day_type == "all censored"
  interval <- data$day_type == "mixed"

  p[exact] <- upper_cdf[exact]
  p[left] <- data$rqr_random[left] * upper_cdf[left]
  p[interval] <- lower_cdf[interval] + data$rqr_random[interval] *
    (upper_cdf[interval] - lower_cdf[interval])

  qnorm(pmin(pmax(p, 1e-10), 1 - 1e-10))
}

# Summarises posterior draws for one parameter.
# It returns the median and 95% credible interval with the site and determinand names.
parameter_summary <- function(draws, name, site, det) {
  tibble(site_name = site, determinand = det, parameter = name,
         median = median(draws), lower_95 = quantile(draws, 0.025),
         upper_95 = quantile(draws, 0.975))
}

groups <- distinct(model_data, site_name, determinand)
parameters <- list()
trajectories <- list()
seasonal_effects <- list()
metrics <- list()
diagnostics <- list()
predictions <- list()

for (i in 1:nrow(groups)) {
  site <- groups$site_name[i]
  det <- groups$determinand[i]
  group_data <- filter(model_data, site_name == site, determinand == det) %>%
    arrange(date)

  train_rows <- group_data$split == "train"
  q_ref <- median(group_data$flow[train_rows])
  time_center <- mean(group_data$decimal_date[train_rows])
  time_scale <- sd(group_data$decimal_date[train_rows])

  group_data <- group_data %>%
    mutate(
      log_q_ratio = log(flow / q_ref),
      time_scaled = (decimal_date - time_center) / time_scale,
      month_cycle = (as.integer(format(date, "%m")) - 0.5) / 12,
      censor_type = case_when(
        day_type == "all exact" ~ "none",
        day_type == "all censored" ~ "left",
        day_type == "mixed" ~ "interval"
      ),
      response = case_when(
        day_type == "all exact" ~ log10_upper,
        day_type == "all censored" ~ log10_upper,
        day_type == "mixed" ~ log10_lower
      ),
      response_upper = if_else(day_type == "mixed", log10_upper, response)
    )

  train <- filter(group_data, split == "train")
  test <- filter(group_data, split == "test")

  file_name <- str_replace_all(paste(site, det, sep = "__"),
                               "[^A-Za-z0-9]+", "_")

  fit <- brm(
    lam_formula, data = train, family = gaussian(), prior = priors,
    knots = list(month_cycle = c(0, 1)), backend = "rstan",
    chains = 4, cores = 4, iter = 2500, warmup = 1250,
    seed = 25062026 + i, init = 0,
    control = list(adapt_delta = 0.99, max_treedepth = 12),
    file = file.path("output/bayesian_time_varying_lam/fits", file_name),
    file_refit = "on_change", refresh = 100
  )

  expected <- posterior_epred(fit, newdata = test, re_formula = NA)
  predictive <- posterior_predict(fit, newdata = test, re_formula = NA)
  loglik <- log_lik(fit, newdata = test, re_formula = NA)
  predicted <- colMeans(expected)
  rqr <- bayesian_rqr(test, predictive)
  exact <- test$day_type == "all exact"

  metrics[[i]] <- tibble(
    site_name = site, determinand = det,
    model = "bayesian_time_varying_lam",
    mean_test_nll = -mean(apply(loglik, 2, log_mean_exp)),
    mae_log10 = mean(abs(test$log10_upper[exact] - predicted[exact])),
    rmse_log10 = sqrt(mean((test$log10_upper[exact] - predicted[exact])^2)),
    bias_log10 = mean(predicted[exact] - test$log10_upper[exact])
  )

  draw_summary <- summarise_draws(as_draws(fit))
  nuts <- nuts_params(fit)

  diagnostics[[i]] <- tibble(
    site_name = site, determinand = det,
    divergences = sum(nuts$Parameter == "divergent__" & nuts$Value == 1),
    treedepth_hits = sum(nuts$Parameter == "treedepth__" & nuts$Value >= 12),
    max_rhat = max(draw_summary$rhat, na.rm = TRUE),
    min_bulk_ess = min(draw_summary$ess_bulk, na.rm = TRUE),
    min_tail_ess = min(draw_summary$ess_tail, na.rm = TRUE),
    mean_rqr = mean(rqr), sd_rqr = sd(rqr),
    percent_outside_95 = 100 * mean(abs(rqr) > 1.96)
  )

  one_row <- train[1, , drop = FALSE]
  braw <- as.numeric(posterior_epred(
    fit, newdata = one_row, nlpar = "braw", re_formula = NA)[, 1])
  drawpar <- as.numeric(posterior_epred(
    fit, newdata = one_row, nlpar = "drawpar", re_formula = NA)[, 1])

  parameters[[i]] <- bind_rows(
    parameter_summary(plogis(braw), "B", site, det),
    parameter_summary(1 + exp(drawpar), "D", site, det),
    parameter_summary(as_draws_df(fit)$sigma, "sigma_log10", site, det)
  )

  logtotal <- posterior_epred(
    fit, newdata = group_data, nlpar = "logtotal", re_formula = NA)
  logitshare <- posterior_epred(
    fit, newdata = group_data, nlpar = "logitshare", re_formula = NA)

  total <- 10^logtotal
  share <- plogis(logitshare)

  trajectories[[i]] <- tibble(
    site_name = site, determinand = det, date = group_data$date,
    split = group_data$split, reference_flow = q_ref,
    total_at_reference_flow = apply(total, 2, median),
    total_lower_95 = apply(total, 2, quantile, 0.025),
    total_upper_95 = apply(total, 2, quantile, 0.975),
    point_share = apply(share, 2, median),
    point_share_lower_95 = apply(share, 2, quantile, 0.025),
    point_share_upper_95 = apply(share, 2, quantile, 0.975)
  )

  month_data <- one_row[rep(1, 12), , drop = FALSE]
  month_data$month_cycle <- ((1:12) - 0.5) / 12
  seasonal <- posterior_epred(
    fit, newdata = month_data, nlpar = "seasonal", re_formula = NA)

  seasonal_effects[[i]] <- tibble(
    site_name = site, determinand = det, month = 1:12,
    seasonal_log10 = apply(seasonal, 2, median),
    lower_95 = apply(seasonal, 2, quantile, 0.025),
    upper_95 = apply(seasonal, 2, quantile, 0.975)
  )

  predictions[[i]] <- test %>%
    mutate(predicted_mean_log10 = predicted,
           lower_95 = apply(expected, 2, quantile, 0.025),
           upper_95 = apply(expected, 2, quantile, 0.975),
           rqr = rqr)

  cat("Completed:", site, "|", det, "\n")
}

overall_metrics <- bind_rows(metrics) %>%
  summarise(mean_nll = mean(mean_test_nll),
            mean_mae = mean(mae_log10),
            mean_rmse = mean(rmse_log10),
            mean_bias = mean(bias_log10))

results <- list(
  formula = lam_formula,
  priors = priors,
  parameters = bind_rows(parameters),
  time_varying_parameters = bind_rows(trajectories),
  seasonal_effects = bind_rows(seasonal_effects),
  metrics = bind_rows(metrics),
  overall_metrics = overall_metrics,
  diagnostics = bind_rows(diagnostics),
  test_predictions = bind_rows(predictions)
)

saveRDS(results,
        "output/bayesian_time_varying_lam/bayesian_time_varying_lam_results.rds")

print(results$parameters)
print(results$metrics)
print(results$overall_metrics)
print(results$diagnostics)
