"""Generate prose and comparison table from verified saved numerical results."""
from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
f=json.loads((R/'results/facts.json').read_text())
c=json.loads((R/'results/classroom_facts.json').read_text())
m={r['model']:r for r in f['metrics']};i={r['model']:r for r in f['investment']}
def num(v):return f'{v:.2f}'
def pct(v):return f'{100*v:.1f}%'
text=f'''---
title: "Better Stock Forecasts, Better Investments?"
subtitle: "Testing changes designed to reduce overfitting in stock-return prediction"
author: "Zhenxin Li"
date: "2026-11-16"
categories: [machine-learning, stock-returns]
resources:
  - README.md
  - requirements.txt
  - scripts/*
  - data/raw/*
  - data/processed/*
  - data/classroom/*
  - results/*
  - figures/*
format:
  html:
    theme: [cosmo, local-fonts.scss]
    toc: false
---

**Can changes designed to reduce overfitting improve the original gradient-boosting model's forecasts and portfolio performance on unseen data?** The starting model uses past price movements and volatility to predict returns and select ten stocks. I change its predictors, prediction target and tree complexity, then test it on 2025 data excluded from training and model selection. I compare forecast errors with the original specification and a historical-mean forecast, and portfolio returns after assumed trading costs with the original specification, equal weighting and SPY.

## What we learned from the original experiment

In the [classroom stock game](data/classroom/assignment.pdf), {c['n']} teams each managed two simulated $100,000 portfolios. Average two-month returns were **{num(100*c['mean_return1'])}%** for intuition-based choices and **{num(100*c['mean_return2'])}%** for choices using indicators, optimized weights or XGBoost. The analysis-based portfolio led in **{c['p2_wins']} teams**, but the varied methods prevent attributing the difference to XGBoost.

The accompanying [XGBoost script](scripts/classroom_original.R) uses momentum, volatility and recent performance to predict returns and select ten stocks. It trains on pre-2024 observations and tests on later data. Boosting adds trees sequentially to correct earlier prediction errors; the original uses 300 trees of depth five. The teaching example reports beating SPY, an ETF tracking the S&P 500, but notes the result may depend on the period and stock universe. A profitable example therefore motivates further testing rather than establishing a lasting advantage.

Predicting returns is difficult because historical relationships can change. Stocks share market shocks, and overlapping future-return windows provide less independent information than the row count suggests. A flexible model may fit accidental patterns in historical returns that fail to repeat—a problem known as overfitting.

## Make the model less eager to fit

I use [Yahoo Finance](https://finance.yahoo.com/) prices for the same 95 stocks over 2022–2025, adjusted for splits and distributions. The revision drops absolute prices, replaces absolute share volume with volume relative to its 21-day average, adds momentum relative to SPY, and predicts stock returns minus SPY returns. Shallower trees and slower learning limit how aggressively it fits training errors.

I train on 2022–2023 and select among six settings using 2024 alone. Validation chooses **depth {f['selected_depth']} and {f['selected_trees']} trees**. Both specifications are then refitted on pre-2025 data and tested on 2025. Observations whose outcome windows cross a training boundary are removed. This evaluates the revised procedure as a whole, rather than identifying which change helped.

## Better predictions, but a small edge over simplicity

The forecast target runs from the next trading day's close to the twentieth following close. For the revised model, the training-period average market return converts relative forecasts back to stock-return forecasts.

![Out-of-sample prediction errors for the classroom specification, revised model and historical-mean forecast.](figures/prediction.png)

Figure 1 compares errors across **{f['test_rows']:,} stock-date predictions** from January 2 to December 2, 2025. Root mean squared error measures typical forecast error while penalizing large misses. It falls from **{num(m['Original']['rmse']*100)} to {num(m['Improved']['rmse']*100)} percentage points**. Yet the constant historical-mean forecast scores **{num(m['Historical mean']['rmse']*100)}**. The revision improves on the original model but only slightly beats this simple benchmark.

## Did the rankings help an investor?

On each month's first trading day, I rank stocks and buy the top ten in equal weights at the following close. Both model portfolios use equal weights to compare selection, replacing the classroom script's forecast-proportional weights. Positions remain until the next monthly entry; the last portfolio is sold December 31. Both models, the equal-weight 95-stock portfolio and SPY use identical dates. Returns include an assumed **0.10% cost per dollar bought or sold**, including entry and liquidation.

![Value of $100 invested using each strategy, after modeled transaction costs.](figures/wealth.png)

The revised portfolio earns **{pct(i['Improved']['net_return'])}**, versus **{pct(i['Original']['net_return'])}** for the classroom specification, **{pct(i['Equal weight']['net_return'])}** for equal weighting and **{pct(i['SPY']['net_return'])}** for SPY. Annualized monthly volatility is **{pct(i['Improved']['annualized_vol'])}**, compared with **{pct(i['Equal weight']['annualized_vol'])}** for equal weighting: higher returns came with larger fluctuations. The chart records monthly endpoints.

Forecast error evaluates every stock-date prediction; the portfolio uses only the ten highest-ranked stocks each month. A small reduction in average prediction error therefore need not produce a similarly small difference in portfolio returns.

## Takeaway

The revised model improved on the original specification in 2025, but barely beat the historical-mean forecast. Its portfolio earned more than the benchmarks while fluctuating more than equal weighting. For investors evaluating a forecasting model, these results show why forecast accuracy and portfolio returns should be assessed separately, with simple benchmarks, trading costs and risk included in the comparison.

[Code, data and replication instructions](README.md) · [Source repository](https://github.com/zhenxin-li/Zhenxin-Li-website)
'''
(R/'index.qmd').write_text(text,encoding='utf-8')
