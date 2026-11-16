# Blog9: stock-return prediction with gradient boosting

This is a retrospective reproduction and extension of the supplied classroom experiment, not a trading recommendation. The article is generated from saved results; the original classroom script is preserved byte-for-byte in `scripts/classroom_original.R`.

## Reproduce

Use Python 3.12 and Quarto. From this directory:

```powershell
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt
.venv/Scripts/python scripts/classroom_results.py
.venv/Scripts/python scripts/analyze.py
.venv/Scripts/python scripts/validate.py
.venv/Scripts/python scripts/write_article.py
quarto render index.qmd --to html
```

Raw Yahoo responses are included, so analysis and rendering do not require a network connection. `python scripts/download.py` fetches missing responses only; it requests one public daily-chart response per symbol, pauses between requests, and fails on an inaccessible response. The manifest records URLs and SHA256 hashes. `capture.json` records the retrieval time. This is a 2026 retrieval of 2022–2025 history, not a point-in-time archived price database. Adjusted prices incorporate splits and distributions: https://in.help.yahoo.com/kb/adjusted-close-sln28256.html .

## What is original, and what changed?

The instructor's local file was found at `D:/6400/Slides Supplementary Material/class 1/UPenn_XGBoostStockPrediction copy.R`. Its comments call the universe 100 companies, but the literal list contains 95. We use the literal list plus SPY. No companies were selected based on this test's returns; however, the original hand-selected universe is not a historical investable index and has selection/survivorship limitations.

The original recipe includes all numeric fields other than date/symbol/target: OHLCV, adjusted price, stock and market daily returns, three inverse-momentum ratios, lagged volatility, five-day inverse return and stock-minus-SPY daily return. We retain those exact predictor definitions for the classroom-specification baseline. Its XGBoost settings are 300 rounds, depth 5, eta .05, minimum child weight 10 and gamma 0. This is a Python core-XGBoost reimplementation, not an assertion of bitwise identity with the R/tidymodels fit. Both model fits use the same frozen data and implementation. No original classroom output was supplied; reported results are rerun results, not invented classroom scores.

Shared evaluation corrections are applied to both models rather than counted as the improvement: purge training labels extending into the next period; execute at the next close; use identical calendar holding windows; equal-weight the ten selected stocks; include transaction costs; annualize monthly volatility using sqrt(12). The original script weights positive forecasts, uses a future twentieth-close/next-close target for monthly performance while computing SPY within calendar months, and annualizes monthly Sharpe with sqrt(252). We do not reproduce those mismatched performance calculations.

## Chronology and target

- Data: 2022-01-01 through 2025-12-31. Features begin after the 126-session lookback.
- Initial training: signals before 2024 with label endpoints before 2024.
- Validation: 2024 signals whose label endpoints remain in 2024.
- Model selection: six candidate improved fits, depths 1/2/3 and rounds 100/300. All use eta .03 and minimum child weight 30; choose lowest validation MSE for excess returns. No 2025 test score selects a model.
- Final training: all pre-2025 signals with endpoints before 2025. Both specifications are refit on this identical dataset, extending the original classroom cutoff.
- Final test: 2025 signals whose twentieth-session price is observable in 2025. This is held out from fitting and tuning, but is a historical backtest, not a prospective trial.
- Prediction target: adjusted close at t+20 divided by adjusted close at t+1 minus one: 19 close-to-close trading intervals. Daily test labels overlap. Rows must not be treated as independent observations for significance tests.

The improved model forecasts this return minus SPY's same-horizon return, using price-invariant momentum/relative momentum (21/63/126 sessions), 22-session lagged and 63-session current volatility, five-day inverse return, daily excess return, relative volume and market daily return. Unlike the baseline, it omits price levels and absolute share volume. Validation chooses tree complexity. To evaluate raw-return RMSE, add the final training sample's mean SPY target to each excess-return forecast; this constant does not affect within-day rankings. This market adjustment is part of the improved procedure, not knowledge of future market returns.

The constant forecast benchmark is the final training sample's pooled historical stock-return mean. Out-of-sample R-squared is one minus test MSE divided by the constant benchmark's test MSE. RMSE and MAE are pooled stock-date losses. The improvement is a bundle of changes; this comparison does not identify which component caused a difference.

## Investment calculation

For each first trading day of a 2025 month, select the ten largest forecasts with ticker as the deterministic tie-break. Buy equal weights at the following trading day's adjusted close; hold until the following monthly entry, with the final position liquidated at the December 31 close. The daily forecast target and calendar investment horizon are close but not identical; investment returns are reconstructed from actual entry/exit prices, never compounded overlapping forecast labels. The December prediction remains fully observed. SPY and a monthly rebalanced equal-weight portfolio of the same 95 stocks use identical windows.

Cost assumption: 0.10% per dollar bought or sold. Initial purchase and final liquidation are included. Inter-rebalance trading is sum(abs(new weights minus drifted old weights)); therefore replacing one position with another charges both the sale and purchase. Net factor = (1-cost*trading)*(1+gross return), with an additional terminal liquidation factor. No leverage, shorts, cash-timing, tax or market-impact model is used. Costs are an illustrative assumption, not measured execution costs. Volatility uses monthly standard deviation times sqrt(12); drawdowns use monthly endpoints only and can understate intramonth losses. We do not estimate a reliable alpha or statistical significance from twelve months.

## Files and checks

- `data/raw`: 96 cached chart responses, capture metadata, URL/hash manifest.
- `data/processed/features.csv`: complete modeling panel.
- `scripts`: source classroom script, acquisition, model/backtest, independent checks, article generation.
- `results/experiment_plan.json`: design recorded before first model execution.
- `results/tuning.csv`: all six validation scores.
- `results/test_predictions.csv`: every held-out prediction and realized target.
- `results/holdings.csv`, `monthly_returns.csv`, `investment_metrics.csv`: investment reconstruction.
- `results/checks.json`, `independent_checks.json`: timing, hashes, metrics, portfolios and weights.
- `figures`: two figures, generated from saved results.

Model reference: https://xgboost.readthedocs.io/en/stable/parameter.html . XGBoost fits new trees sequentially to reduce the remaining squared prediction errors. Smaller trees and smaller learning rates limit how aggressively the model fits training patterns; they do not guarantee useful forecasts.

The article and source must be published and a GitHub source link submitted, as required by the course. Local rendering alone does not fulfill URL submission. Nothing in this package automatically commits or pushes.

## Classroom game evidence

`data/classroom/assignment.pdf` is the supplied assignment. `results.xlsx` preserves the supplied 45 paired outcomes; `paired_results.csv` is a numeric extraction in the same folder. Run `scripts/classroom_results.py` to regenerate `results/classroom_facts.json`. Each portfolio starts at $100,000; the assigned horizon is two months. The second portfolio may use indicators, optimized weights and/or XGBoost. The workbook does not identify the actual method used by each team, so its outcomes cannot identify XGBoost's effect. Cross-team final-value dispersion is not time-series volatility.

`scripts/classroom_results_original.R` preserves the results-analysis attachment with its original absolute workbook path. The portable replication reads the local workbook instead. The article reports descriptive outcomes without treating the original script's regressions or bootstrap tests as evidence of model skill. The assignment's previous-semester 113-team outcomes are distinct from the supplied 45-team workbook. Its illustrative XGBoost backtest beating SPY is attributed to the assignment and kept distinct from our 2025 rerun.
