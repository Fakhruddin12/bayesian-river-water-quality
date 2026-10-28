# Dissertation results and their meaning

Source: [dissertation.pdf](dissertation.pdf), Table 5, printed page 12. These values are transcribed from the report, not regenerated from the archived code. The table compares the final hierarchical Bayesian static seasonal model with its linear time-varying extension on the same chronological test observations. Results are averaged across sites within each pollutant.

| Pollutant | Model | Mean negative log-likelihood | MAE, log10 concentration | RMSE, log10 concentration |
|---|---|---:|---:|---:|
| Ammonia | Static Bayesian | 1.305 | 0.920 | 1.031 |
| Ammonia | Time-varying Bayesian | 1.362 | 1.288 | 1.422 |
| Nitrate | Static Bayesian | -0.836 | 0.077 | 0.101 |
| Nitrate | Time-varying Bayesian | -0.845 | 0.083 | 0.103 |
| Orthophosphate | Static Bayesian | 0.693 | 0.314 | 0.352 |
| Orthophosphate | Time-varying Bayesian | 0.293 | 0.244 | 0.282 |
| Dissolved zinc | Static Bayesian | 0.200 | 0.208 | 0.236 |
| Dissolved zinc | Time-varying Bayesian | -0.400 | 0.126 | 0.164 |

Lower values are better. Negative log-likelihood assesses the predictive distribution, MAE is average absolute prediction error, and RMSE gives larger errors greater weight. Negative likelihood scores are possible for continuous densities; they are not negative probabilities.

Using the rounded table values, RMSE reductions are `(0.236-0.164)/0.236 = 30.5%` for zinc and `(0.352-0.282)/0.352 = 19.9%` for orthophosphate, reported approximately as 31% and 20%. These are reductions in error on log concentrations, not reductions in pollutant levels. [Machine-readable transcription](reported_bayesian_metrics.csv).

## Interpretation across pollutants

Time variation helps zinc most and orthophosphate to a lesser extent, consistent with source contributions changing over the observation period. For nitrate, the small likelihood improvement is accompanied by slightly worse point-prediction errors, so the static structure is sufficient. For ammonia, every measure worsens. Heavy censoring, between-site variation and abrupt changes remain poorly described by the simple time structure.

The separate result that flow improves test likelihood in 18 of 23 series compares GAM baselines. It should not be substituted for, or conflated with, this Bayesian comparison.

These are model-based source interpretations, not direct causal identification of individual discharges. Reproducing the final tables needs the final hierarchical specification and frozen inputs; the earlier per-site scripts alone are insufficient. [Reproduction status](../REPRODUCIBILITY.md).
