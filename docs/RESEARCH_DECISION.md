# Bayesian River Water Quality: research decision

Reviewed 31 October 2026. This note separates the supported result from the next research decision.

## Decision

Restore the exact final hierarchical workflow before extending the model or claiming numerical reproduction.

## Strongest relevant comparison

Reported zinc log10-RMSE is 0.164 versus static Bayesian 0.236 and best GAM 0.180 (8.9% below that stronger control). Orthophosphate is 0.282 versus static Bayesian 0.352 but worse than GAM 0.200. Dynamic ammonia also worsens. These are dissertation findings, not new fitted results.

## Evidence limits

The final code, frozen split and fit artifacts are missing; public R scripts are earlier per-site revisions. Source shares are model-dependent flow components, not measured physical discharges. Prior-scale and residual-scale details and a common calendar cutoff remain unresolved.

## Checks and changes

Sixty main-table values were checked against the dissertation in the preceding audit. The new scope-aware preflight requires a hashed final-input/code manifest by default; archived scope checks only split availability. Three tests pass. Preflight success never establishes a fit, metric reproduction or convergence.

## Next independent milestone

Restore a hashed input/code manifest and posterior/prediction artifacts, resolve specification ambiguities, then reproduce one pollutant against all LAM/GAM controls before expanding.

[Project report](../reports/PROJECT_REPORT.pdf) · [Prepared LinkedIn Projects entry](../reports/LINKEDIN_PROJECT_ENTRY.md)

The report and entry are portfolio summaries. Original experimental source version: `2b8b7b0137bd67def35f9b2db3b56309b181aa0d`. The report records verification scope and distinguishes earlier numerical replays from this presentation/code review.
