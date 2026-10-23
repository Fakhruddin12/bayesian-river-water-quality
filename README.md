# Bayesian River Water-Quality Modelling
### Censored measurements, nonlinear source models and changing river conditions

**Question:** How can concentration–flow models distinguish point and diffuse source behaviour while accounting for measurements reported below a laboratory detection limit?

The dissertation studies **16,233 concentration records**, six river sites and four determinands, producing **23 usable site–determinand series**. It compares a load-apportionment model (LAM), GAM baselines and Bayesian extensions.

**Reported finding:** Adding flow to time-and-season GAMs improved held-out negative log-likelihood in **18 of 23 series**. Censoring affected up to **42.6%** of ammonia observations, making a censoring-aware likelihood central to the analysis.

[**Dissertation**](reports/dissertation.pdf) · [**Analysis scripts**](analysis/) · [**Reproduction status**](REPRODUCIBILITY.md)

## Statistical approach

The source model expresses concentration as the sum of two flow-dependent components:

$$C(Q)=A Q^{B-1}+M Q^{D-1},\qquad A,M>0,\;0<B<1,\;D>1.$$

The first component declines with flow, while the second rises. This provides an interpretable source-apportionment structure. It is a model-based decomposition rather than a direct causal measurement of individual pollution sources.

The workflow preserves exact, left-censored and interval-censored observations; combines concentration with daily discharge; and uses an **80/20 chronological split** within each series. The R scripts include maximum-likelihood fitting, GAMs, Bayesian static models and time-varying source parameters with seasonality.

## What to inspect

| Script | Purpose |
|---|---|
| [01: preprocessing and EDA](analysis/01_data_preprocessing_and_eda.R) | Join sources, aggregate by day and preserve censoring |
| [02: static LAM](analysis/02_static_lam_and_diagnostics.R) | Constrained likelihood fitting and residual diagnostics |
| [03: GAM baselines](analysis/03_gam_models.R) | Compare time, season and flow information |
| [04: Bayesian static LAM](analysis/04_bayesian_static_lam.R) | Posterior inference and predictive diagnostics |
| [05: time-varying LAM](analysis/05_bayesian_time_varying_lam.R) | Changing source parameters and seasonal structure |

## Reproduction status

The supplied archive contains the five analysis scripts. It does **not** contain the two original import helper files or the frozen input snapshot. The dissertation's numerical findings are preserved as reported results and have not been regenerated from this package. The code archive and final dissertation also represent different model revisions; see [the exact distinction and required inputs](REPRODUCIBILITY.md).

```bash
python scripts/check_inputs.py
```

This preflight check lists what is available and what must be restored before an R run. A Stan-capable R environment with `brms` is required for Bayesian fitting. Convergence must be assessed fit by fit; no blanket convergence claim is made.

**Author:** Fakhruddin Hakim Hussain · MSc Statistics with Data Science, University of Edinburgh  
[Portfolio](https://github.com/Fakhruddin12)
