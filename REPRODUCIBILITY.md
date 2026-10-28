# Reproduction status

## Available evidence

- The final dissertation, including the hierarchical Bayesian comparison in Table 5 on printed page 12.
- Five R scripts from the earlier source archive, covering preprocessing, classical source models, GAMs and per-site Bayesian models.
- A [transcription of the reported Bayesian metrics](reports/RESULTS.md), with all four pollutants and metric units.

The report is the source for the 16,233 readings, 23 usable series, censoring rates and numerical findings. These are reported results; the portfolio documentation update did not refit the dissertation models.

## Model revisions are different

The final dissertation describes nonlinear hierarchical models, one joint multi-site fit per pollutant, with site-level source sizes and trends partially pooled across sites. Flow exponents are shared within a pollutant. Annual seasonality uses sine/cosine terms and the time-varying source sizes have linear trends. The likelihood is Gaussian on log10 concentrations and retains censored observations.

The archived scripts fit earlier per-site static and time-varying models, including a different seasonal/time parameterisation. They are useful research code but are not an exact executable reproduction of the final hierarchical model. Do not infer that every feature of the final model is present in scripts 04 and 05.

## Required before a full rerun

1. Restore `import_hde_function.R` and `import_wq_function.R`, which preprocessing sources from the repository root.
2. Restore the exact source-data snapshot, with acquisition dates and checksums, or the saved `data/processed/model_data_split.rds` used in the original fits.
3. Restore the final hierarchical model code and its fit/metric artifacts to reproduce Table 5 exactly.
4. Record the environment and inspect each fit's prior sensitivity, R-hat, effective sample sizes, divergences, tree depth and posterior predictions.

The preprocessing code currently uses `Sys.Date()` for acquisition. Fix and record the original end date when rebuilding the input snapshot; a current download will not reproduce the original historical sample.

## Preflight and R environment

```bash
python scripts/check_inputs.py
```

The preflight check lists available and missing inputs. For the archived analysis, install tidyverse, lubridate, mgcv, brms and posterior plus a Stan-capable C++ toolchain, then run scripts in numeric order from the repository root after restoring their inputs. Bayesian fitting can be expensive. The presence of code is not a blanket convergence claim.
