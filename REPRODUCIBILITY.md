# Reproduction status

## What is available

- Five R analysis scripts from `Dissertation_1_code.zip`.
- The dissertation report, which is the evidence for the 16,233 records, 23 groups, censoring rates and 18/23 GAM comparison.

## What needs restoring

1. `import_hde_function.R` and `import_wq_function.R`, referenced by the preprocessing script.
2. The exact source-data snapshot, with source dates and checksums, or the saved `data/processed/model_data_split.rds` used for fitting.
3. Saved fit diagnostics and metric tables for independent numerical verification.

Place the helper scripts in the repository root, because the preprocessing script sources them relative to that directory. It currently uses `Sys.Date()` for acquisition: record and fix the end date when reconstructing the historical experiment. Running it at a later date does not recreate the original snapshot.

## Report and code revisions

The final dissertation describes a hierarchical seasonal Bayesian model with site-level partial pooling. The five-file source archive contains per-site static and time-varying LAM implementations. They are useful, inspectable research code, but the package should not be described as an exact executable reproduction of every final-dissertation table. The GAM result is attributed to the report; dynamic-model percentages are not promoted as independently verified results.

## R environment

Install `tidyverse`, `lubridate`, `mgcv`, `brms` and `posterior`, together with the C++ toolchain needed by Stan. Run the scripts in numeric order from the repository root after restoring the inputs. Bayesian runs use multiple chains and may be expensive. Retain per-fit R-hat, bulk/tail ESS, divergences and tree-depth diagnostics before making convergence claims.
