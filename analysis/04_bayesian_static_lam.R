# This file fits the Bayesian static LAM separately for each site and determinand.
# It saves posterior parameter summaries, test metrics, uncertainty intervals and sampler diagnostics.

library(tidyverse)
library(brms)
library(posterior)

options(mc.cores = 4)
set.seed(123)

model_data <- readRDS("data/processed/model_data_split.rds")
dir.create("output/bayesian_static_lam/fits", recursive = TRUE,
           showWarnings = FALSE)

lam_formula <- bf(
  response | cens(censor_type, response_upper) ~
    log10(totalref * (
      pointshare * exp((bparameter - 1) * log_q_ratio) +
        (1 - pointshare) * exp(dminusone * log_q_ratio)
    )),
  totalref ~ 0 + Intercept,
  pointshare ~ 0 + Intercept,
  bparameter ~ 0 + Intercept,
  dminusone ~ 0 + Intercept,
  nl = TRUE
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
metrics <- list()
diagnostics <- list()
predictions <- list()

for (i in 1:nrow(groups)) {
  site <- groups$site_name[i]
  det <- groups$determinand[i]
  group_data <- filter(model_data, site_name == site, determinand == det) %>%
    arrange(date)

  q_ref <- median(group_data$flow[group_data$split == "train"])

  group_data <- group_data %>%
    mutate(
      log_q_ratio = log(flow / q_ref),
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
  prior_centre <- log(median(train$daily_upper))

  priors <- c(
    set_prior(paste0("lognormal(", prior_centre, ", 1)"),
              class = "b", nlpar = "totalref", lb = 0),
    set_prior("beta(1, 1)", class = "b", nlpar = "pointshare",
              lb = 0, ub = 1),
    set_prior("beta(1, 1)", class = "b", nlpar = "bparameter",
              lb = 0, ub = 1),
    set_prior("lognormal(log(0.5), 0.75)", class = "b",
              nlpar = "dminusone", lb = 0),
    set_prior("normal(0, 0.5)", class = "sigma")
  )

  file_name <- str_replace_all(paste(site, det, sep = "__"),
                               "[^A-Za-z0-9]+", "_")

  fit <- brm(
    lam_formula, data = train, family = gaussian(), prior = priors,
    backend = "rstan", chains = 4, cores = 4,
    iter = 2000, warmup = 1000, seed = 123 + i, init = 0,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    file = file.path("output/bayesian_static_lam/fits", file_name),
    file_refit = "on_change", refresh = 250
  )

  expected <- posterior_epred(fit, newdata = test, re_formula = NA)
  predictive <- posterior_predict(fit, newdata = test, re_formula = NA)
  loglik <- log_lik(fit, newdata = test, re_formula = NA)
  predicted <- colMeans(expected)
  rqr <- bayesian_rqr(test, predictive)
  exact <- test$day_type == "all exact"

  metrics[[i]] <- tibble(
    site_name = site, determinand = det, model = "bayesian_static_lam",
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
  totalref <- as.numeric(posterior_epred(
    fit, newdata = one_row, nlpar = "totalref", re_formula = NA)[, 1])
  pointshare <- as.numeric(posterior_epred(
    fit, newdata = one_row, nlpar = "pointshare", re_formula = NA)[, 1])
  B <- as.numeric(posterior_epred(
    fit, newdata = one_row, nlpar = "bparameter", re_formula = NA)[, 1])
  dminusone <- as.numeric(posterior_epred(
    fit, newdata = one_row, nlpar = "dminusone", re_formula = NA)[, 1])
  sigma <- as_draws_df(fit)$sigma

  A <- totalref * pointshare / q_ref^(B - 1)
  M <- totalref * (1 - pointshare) / q_ref^dminusone

  parameters[[i]] <- bind_rows(
    parameter_summary(A, "A", site, det),
    parameter_summary(B, "B", site, det),
    parameter_summary(M, "M", site, det),
    parameter_summary(1 + dminusone, "D", site, det),
    parameter_summary(sigma, "sigma_log10", site, det),
    parameter_summary(totalref, "total_at_reference_flow", site, det),
    parameter_summary(pointshare, "point_share_at_reference_flow", site, det)
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
  parameters = bind_rows(parameters),
  metrics = bind_rows(metrics),
  overall_metrics = overall_metrics,
  diagnostics = bind_rows(diagnostics),
  test_predictions = bind_rows(predictions)
)

saveRDS(results,
        "output/bayesian_static_lam/bayesian_static_lam_results.rds")

print(results$parameters)
print(results$metrics)
print(results$overall_metrics)
print(results$diagnostics)
