# Blog8 rubric evidence

1. Concrete question and motivation: whether a positive sample saving supports positive population-average savings; independent households, one model, one mean.
2. Accessible explanation: resample means, fresh-dataset coverage, null-model surprise explained in prose.
3. Interpretation and takeaway: a nonsignificant sample can arise under the known nonzero mean; do not turn a population mean into an individual guarantee.
4. Data and presentation: all data explicitly simulated Normal(3,20); seed and method sources documented; three labeled figures with static fallbacks.
5. Repository: scripts, data/simulated, results, assets, includes, figures and reproduction README.
6. Reproducibility: seeded draws, saved outputs, input hashes, numeric inline results; offline targeted render;24 simulation and33 independent R checks passed.
7. Bootstrap: observed sample resampled with replacement9,999 times; distribution of means and percentile limits displayed.
8. Coverage:2,000 NEW samples, each with999 resamples, yield1,895/2,000 coverage at default95% (94.75%); first100 shown without selection.
9. Null simulation:50,000 new zero-mean samples at each n generate Studentized-mean statistics.
10. Rejection and p-value: two-sided |t| tails, red significance boundaries, exact unbinned Monte Carlo tail counts with+1 correction; correct definitions in prose.

Additional interaction: sample size, confidence level, tail shading and reset. Nine combinations and both highlight modes passed controller unit tests;27 figure specifications passed Plotly schema checks. This is not an actual browser test: file:// access was blocked by browser security policy. Static PNGs visually inspected. No bypass attempted.
