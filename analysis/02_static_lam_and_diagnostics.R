# This file fits the static Load Apportionment Model (LAM) for each site and determinand.
# It calculates test-set performance measures, randomised quantile residuals and parameter diagnostics.

library(tidyverse)

model_data <- readRDS("data/processed/model_data_split.rds")
dir.create("output/static_lam", recursive = TRUE, showWarnings = FALSE)

# Converts the optimisation parameters into the LAM parameters and predicted concentrations.
# It takes a parameter vector and flow values, and returns the fitted parameters and concentrations.
lam_values <- function(par, flow) {
  A <- exp(par[1])
  M <- exp(par[2])
  B <- plogis(par[3])
  D <- 1 + exp(par[4])
  sigma <- exp(par[5])
  concentration <- A * flow^(B - 1) + M * flow^(D - 1)

  list(A = A, B = B, M = M, D = D, sigma = sigma,
       concentration = concentration,
       log10_concentration = log10(concentration))
}

# Calculates the log-likelihood contribution for every observation.
# It handles exact, left-censored and interval-censored concentration measurements.
lam_loglik <- function(par, data) {
  fitted <- lam_values(par, data$flow)
  mu <- fitted$log10_concentration
  sigma <- fitted$sigma
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

# Adds the negative log-likelihood values to give the quantity minimised by optim().
lam_nll <- function(par, data) -sum(lam_loglik(par, data))

# Calculates randomised quantile residuals using the fitted mean and standard deviation.
# It returns one residual for each exact or censored observation.
lam_rqr <- function(data, mu, sigma) {
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
starts <- tribble(
  ~B, ~D, ~point_share,
  0.10, 1.10, 0.80,
  0.30, 1.30, 0.60,
  0.50, 1.50, 0.50,
  0.80, 2.00, 0.20
)

models <- list()
parameters <- list()
metrics <- list()
diagnostics <- list()
predictions <- list()

for (i in 1:nrow(groups)) {
  site <- groups$site_name[i]
  det <- groups$determinand[i]
  train <- filter(model_data, site_name == site, determinand == det,
                  split == "train")
  test <- filter(model_data, site_name == site, determinand == det,
                 split == "test") %>% arrange(date)

  median_flow <- median(train$flow)
  median_concentration <- median(train$daily_upper)
  sigma_start <- sd(train$log10_upper[train$day_type == "all exact"])
  if (!is.finite(sigma_start) || sigma_start <= 0) sigma_start <- 0.3

  best_fit <- NULL

  for (j in 1:nrow(starts)) {
    A_start <- starts$point_share[j] * median_concentration /
      median_flow^(starts$B[j] - 1)
    M_start <- (1 - starts$point_share[j]) * median_concentration /
      median_flow^(starts$D[j] - 1)

    initial <- c(log(A_start), log(M_start), qlogis(starts$B[j]),
                 log(starts$D[j] - 1), log(sigma_start))

    fit <- optim(initial, lam_nll, data = train, method = "BFGS",
                 control = list(maxit = 5000))

    if (is.null(best_fit) || fit$value < best_fit$value) best_fit <- fit
  }

  fitted <- lam_values(best_fit$par, test$flow)
  loglik <- lam_loglik(best_fit$par, test)
  rqr <- lam_rqr(test, fitted$log10_concentration, fitted$sigma)
  exact <- test$day_type == "all exact"

  parameters[[i]] <- tibble(
    site_name = site, determinand = det,
    A = fitted$A, B = fitted$B, M = fitted$M, D = fitted$D,
    sigma_log10 = fitted$sigma, convergence = best_fit$convergence
  )

  metrics[[i]] <- tibble(
    site_name = site, determinand = det, model = "static_lam",
    mean_test_nll = -mean(loglik),
    mae_log10 = mean(abs(test$log10_upper[exact] -
                           fitted$log10_concentration[exact])),
    rmse_log10 = sqrt(mean((test$log10_upper[exact] -
                              fitted$log10_concentration[exact])^2)),
    bias_log10 = mean(fitted$log10_concentration[exact] -
                        test$log10_upper[exact])
  )

  diagnostics[[i]] <- tibble(
    site_name = site, determinand = det,
    mean_rqr = mean(rqr), sd_rqr = sd(rqr),
    percent_outside_95 = 100 * mean(abs(rqr) > 1.96),
    B_near_boundary = fitted$B < 0.01 || fitted$B > 0.99,
    D_near_boundary = fitted$D < 1.01
  )

  predictions[[i]] <- test %>%
    mutate(predicted_log10 = fitted$log10_concentration, rqr = rqr)
  models[[paste(site, det, sep = "__")]] <- best_fit

  cat("Completed:", site, "|", det, "\n")
}

parameter_results <- bind_rows(parameters)
metric_results <- bind_rows(metrics)
diagnostic_results <- bind_rows(diagnostics)
test_predictions <- bind_rows(predictions)
overall_metrics <- metric_results %>%
  summarise(mean_nll = mean(mean_test_nll),
            mean_mae = mean(mae_log10),
            mean_rmse = mean(rmse_log10),
            mean_bias = mean(bias_log10))

pdf("output/static_lam/rqr_qq_plots.pdf", width = 6, height = 5)
for (i in 1:nrow(groups)) {
  x <- test_predictions %>%
    filter(site_name == groups$site_name[i],
           determinand == groups$determinand[i]) %>%
    pull(rqr)
  qqnorm(x, main = paste(groups$site_name[i], groups$determinand[i],
                         sep = " | "))
  qqline(x)
}
dev.off()

saveRDS(list(models = models, parameters = parameter_results,
             metrics = metric_results, overall_metrics = overall_metrics,
             diagnostics = diagnostic_results,
             test_predictions = test_predictions),
        "output/static_lam/static_lam_results.rds")

print(parameter_results)
print(metric_results)
print(overall_metrics)
print(diagnostic_results)
