# Bayesian river water quality — LinkedIn Projects entry

## Project name
Bayesian Modelling of River Water Quality

## Description
Studied how river flow and concentration measurements can inform a model-based decomposition of point-source and diffuse pollution, using 16,233 reported readings from six sites and four pollutants.

Developed nonlinear hierarchical Bayesian models in R/brms/Stan, partially pooling site-level source contributions and adding seasonality and linear temporal change. Retained below-detection-limit observations through censored likelihoods and combined repeated daily samples using exact or interval-valued means. Compared the models with classical source models and generalised additive benchmarks on later observations in each series.

The dissertation reports approximately 31% lower site-averaged zinc test RMSE and 20% lower orthophosphate RMSE versus static Bayesian models, on the log10 concentration scale. Results varied by pollutant: temporal complexity did not help ammonia or nitrate, and the flow-based GAM retained lower orthophosphate point error. Assessed prior sensitivity, sampler diagnostics and posterior source uncertainty.

The report presents these as dissertation findings. Earlier per-site scripts are public. Reproducing the final hierarchical results requires the frozen inputs and final fit artifacts.

## Skills to associate
Bayesian Statistics; Statistical Modeling; R; Time Series Analysis; Research

Choose the closest existing label in LinkedIn's selector if needed.

## Project URL
https://github.com/Fakhruddin12/bayesian-river-water-quality

## Association
MSc Statistics with Data Science, University of Edinburgh. The dissertation confirms this association. Use the actual project start/end dates from your records; do not use the report assembly date as a project date.

## Media attachment
- File: Bayesian_River_Dissertation.pdf
- Title: Original MSc Dissertation
- Description: Original submitted dissertation, including the study methodology, results, discussion and references. Later portfolio verification is documented separately in the repository.

## Evidence notes — not part of the pasted description
- Source version: 2b8b7b0137bd67def35f9b2db3b56309b181aa0d.
- Primary source: Censoring-Aware and Time-Varying Load Apportionment Modelling of River Water Quality. Original declaration dated 26 June 2026.
- Reported counts: 16,233 valid raw readings; 13,227 daily records; 23 usable site–pollutant series. These are reported totals; exact post-flow-match fit counts need the frozen data.
- Main Bayesian comparison: Table 5, printed dissertation page 12. Static/dynamic zinc RMSE: 0.236/0.164; orthophosphate: 0.352/0.282. Percent reductions are calculated from rounded table values.
- Classical/GAM controls: Table 4, printed page 10. Dynamic zinc RMSE 0.164 versus best GAM 0.180. Dynamic orthophosphate RMSE 0.282 versus flow GAM 0.200.
- Ammonia dynamic RMSE is worse: 1.422 versus static Bayesian 1.031. Nitrate changes little: 0.103 versus 0.101.
- MAE and RMSE use exact test observations, on the log10 concentration scale. NLL incorporates censoring. Reported pollutant summaries average site metrics rather than pooling every observation.
- A separate GAM comparison finds flow improves test likelihood in 18/23 series. It is not the same comparison as dynamic versus static Bayes.
- Final models use hierarchical site effects, linear log-source trends and sine/cosine seasonality. Do not substitute older per-site spline-model claims or diagnostics for these fits.
- All five archived R scripts match the supplied code archive. Missing import helpers, frozen inputs and final hierarchical artifacts prevent a fresh model rerun. Evidence checks validate transcription and mathematical consistency, not posterior convergence or original predictive performance.
- Source shares are model-dependent components, not directly identified discharges or causal intervention effects.

## Public report link
https://github.com/Fakhruddin12/bayesian-river-water-quality/blob/master/reports/dissertation.pdf

## October review clarification — evidence note
Reported zinc log10-RMSE is 0.164 versus static Bayesian 0.236 and best GAM 0.180 (8.9% below that stronger control). Orthophosphate is 0.282 versus static Bayesian 0.352 but worse than GAM 0.200. Dynamic ammonia also worsens. These are dissertation findings, not new fitted results.

The final code, frozen split and fit artifacts are missing; public R scripts are earlier per-site revisions. Source shares are model-dependent flow components, not measured physical discharges. Prior-scale and residual-scale details and a common calendar cutoff remain unresolved.

## Media decision — 1 November 2026
Use the original dissertation PDF as LinkedIn media. The separate portfolio review summary is supporting audit material, not the attachment. Later replay checks must not be presented as if they appear in the submitted dissertation.
