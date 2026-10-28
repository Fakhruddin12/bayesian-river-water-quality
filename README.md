# Understanding How River Pollution Changes

**How do direct discharges and rain-driven runoff contribute to river pollution, and how do those contributions change over time?**

This MSc dissertation combines river-flow data with **16,233 pollutant readings from six sites**. It estimates two source components: direct or point-source discharges, whose concentrations tend to dilute as flow rises, and diffuse runoff, whose contribution can increase with flow. The measurements do not directly label either source, so the decomposition depends on an explicit statistical model.

I developed **nonlinear hierarchical Bayesian models** that share information across sites, retain measurements below laboratory detection limits and quantify uncertainty. Allowing source contributions to change over time reduced test prediction error by approximately **31% for dissolved zinc** and **20% for orthophosphate**, compared with static Bayesian models. That added complexity did not help every pollutant.

[**MSc dissertation**](reports/dissertation.pdf) · [**Results, including weaker cases**](reports/RESULTS.md) · [**Code and reproduction status**](REPRODUCIBILITY.md)

## What I did

- Combined water-quality measurements with daily river flow, retaining exact and censored readings rather than replacing below-limit values with arbitrary constants.
- Built a nonlinear source model with **partial pooling**: sites have their own source contributions, while related site estimates inform one another.
- Added annual seasonality and site-level changes in source contributions, fitted with R/brms/Stan.
- Checked prior sensitivity, MCMC diagnostics and posterior predictions, and reported **95% credible intervals**.
- Compared models on later observations using an **80/20 chronological split** within each river–pollutant series.

## Results in context

The study covers four pollutants and 23 usable site–pollutant series. The table below is transcribed from **Table 5, dissertation page 12**, and averages prediction errors across sites within each pollutant.

| Pollutant | Static Bayesian model: test RMSE | Time-varying Bayesian model: test RMSE | Interpretation |
|---|---:|---:|---|
| Dissolved zinc | 0.236 | **0.164** | About **31% lower** error |
| Orthophosphate | 0.352 | **0.282** | About **20% lower** error |
| Nitrate | **0.101** | 0.103 | Little benefit from time variation |
| Ammonia | **1.031** | 1.422 | Time-varying model performs worse |

RMSE penalises large forecast mistakes. These values are on the **log10 concentration scale**: they measure prediction error, not a percentage reduction in river pollution. The percentages above are rounded from the table's reported values. [All three metrics and source table](reports/RESULTS.md).

A separate regression comparison found that adding river flow improved test predictive likelihood in **18 of 23 series**. That is a supporting result about useful information, not the Bayesian-model comparison above. Heavy censoring—up to 42.6% of ammonia readings—remains a major challenge.

## How the source model works

The load-apportionment model represents concentration as two flow-dependent components:

$$C(Q)=A Q^{B-1}+M Q^{D-1},\qquad A,M>0,\;0<B<1,\;D>1.$$

The first component decreases with flow; the second increases. In the final dissertation, source levels and their time trends vary by site with hierarchical pooling, flow exponents are shared within each pollutant, and annual seasonality uses sine/cosine terms. A censored Gaussian likelihood is applied to log concentrations. Uncertainty in this model-based decomposition is retained rather than treating source shares as directly observed facts.

## What can be reproduced

The dissertation and five archived R scripts are available. The scripts are earlier **per-site model revisions**; they are not an exact executable copy of the final hierarchical model. Original import helpers, the frozen input snapshot and final fit artifacts are missing. The numerical results above are **reported dissertation findings, not a fresh rerun**.

```bash
python scripts/check_inputs.py
```

This preflight check lists the inputs that must be restored. [Exact missing files and model-version distinction](REPRODUCIBILITY.md) · [Archived analysis scripts](analysis/).

**Author:** Fakhruddin Hakim Hussain · MSc Statistics with Data Science, University of Edinburgh · [Portfolio](https://github.com/Fakhruddin12)
