# Blog8: confidence intervals and hypothesis tests

**How Do Confidence Intervals and Hypothesis Tests Turn a Sample into Evidence?**

The article asks whether a nonzero sample mean is sufficient evidence of a nonzero population mean. One known-answer numerical model connects a bootstrap interval, repeated coverage, and a null simulation. The observations are unitless simulated values.

## Render the saved results offline

Install missing R packages once:

```r
install.packages(c("jsonlite", "ggplot2", "knitr", "rmarkdown"))
```

From the website root:

```sh
quarto render blog/posts/blog8/index.qmd --to html
```

Or from the post directory: `quarto render index.qmd --to html`.
Rendering verifies saved input hashes, reads results and regenerates PNG fallbacks. It does not run the expensive simulation, install packages or access the network. Native MathML, local Plotly assets and system fonts permit offline viewing. Keep index_files, assets and figures alongside the normal index.html preview.

For one portable HTML file, run FROM THIS POST DIRECTORY:

```sh
quarto render index.qmd --to html --embed-resources --output blog8-standalone.html
```

If keeping both previews, render the normal index.qmd last to regenerate its resource directory. The portable file embeds rendering resources; links to code and this README still refer to the accompanying files. It does not change the app's local-file access policy.

## Regenerate the simulation

With Python and R on PATH, from this post directory:

```sh
python -m pip install -r requirements.txt
python scripts/simulate.py
Rscript scripts/validate.R
python scripts/check_inputs.py --refresh
quarto render index.qmd --to html
```

NumPy2.3.5 and Python3.12 produced the frozen draws. Only NumPy is required in Python. The seed is20261101. Bounded batches keep memory use modest; runtime is environment-dependent (about30 seconds when originally generated). The generator separates observed-bootstrap, coverage-sample, coverage-bootstrap and null streams with SeedSequence.

The former application labels were removed without changing any numerical draws. observations.csv has observation_id and value columns; observed-bootstrap CSVs have resample and sample_mean. The old themed version is backed up outside the source and delivery folders.

## Model and repeated experiments

All observations are independent draws from Normal(mean3,standard deviation20). These are abstract numerical values. The analyst treats the mean as unknown, while the simulator knows it and can evaluate interval coverage. Sample sizes are50,200,800; levels are90%,95%,99%. Observed samples are nested prefixes of a master800-observation draw, so increasing n can move the estimate as well as its precision. Coverage datasets are NEW independent samples, not repeated bootstraps of that observed dataset. Neither the seed nor results were changed to force significance or exactly95% coverage.

1. **One-sample bootstrap:** at each n, draw n values with replacement from the observed sample9,999 times. Calculate each resample mean. The percentile bounds are the alpha/2 and1−alpha/2 quantiles, using linear interpolation (R type7). The histogram is of means, not individual values.
2. **Coverage:** at each n, generate2,000 new datasets from Normal(3,20). Construct an interval for EACH using999 bootstrap resamples. The same bootstrap draws provide90%,95%,99% bounds. Count intervals containing3. Display the first100 in their original order; compute rates across all2,000. The Monte Carlo SE is sqrt(rate*(1−rate)/2000). Coverage is approximate: finite sample size, percentile approximation and finite bootstrap repetitions all matter.
3. **Null distribution:** generate50,000 new datasets at each n from Normal(0,20). Compute t=mean/(sample SD/sqrt(n)), with SD denominator n−1, for each. For the two-sided statistic |t|, p=(1+count of null |t|>=observed |t|)/(50000+1). The +1 correction prevents simulated p=0. Rejection boundaries are ±quantile(|null t|,confidence level), with total tail size alpha=1−confidence.

The absolute-tail convention is explicit. SciPy's default two-sided Monte Carlo convention instead doubles the smaller simulated signed tail; under a symmetric null these estimate the same theoretical probability but need not give identical finite simulation numbers. This implementation uses NumPy rather than calling SciPy.

The percentile interval and simulated Student t test are different procedures. Their decisions are not claimed to agree exactly for every sample. The test uses the specified normal null; it is not a distribution-free conclusion about every possible population. The sample SD is computed in every dataset, not replaced by the population SD.

## Default numerical results

At n200 and95%: mean1.651509, bootstrap interval[−1.258690,4.468609], observed t1.144340, p0.2553349. Of2,000 fresh intervals,1,895 contain3:94.75%. The5% critical boundary is approximately±1.97882. At n50,95% coverage is93.55%; at n800 it is94.55%. Use precise rates when interpreting rounded displays.

The nonzero sample mean is insufficient to reject zero in the default experiment, even though the true population mean is3. This demonstrates that failure to reject does not establish a zero mean. Repeated coverage evaluates the interval procedure, not a probability that the fixed parameter lies in one observed interval.

## Interactive controls and verification

- Sample size50/200/800 updates the sample, bootstrap distribution, coverage experiment and null distribution.
- Confidence90/95/99% updates percentile bounds, coverage and the linked rejection boundaries. It leaves a given sample's mean, t and p-value unchanged.
- Highlight toggles Figure3 shading between p-value tails and rejection regions without changing numerical results.
- Reset restores200,95% and p-value-tail shading. Hover, zoom and local image export are provided by local Plotly.js.

Controls select frozen seeded experiments rather than silently rerolling samples. Exact rates and p-values use unbinned draws. Static PNGs remain visible without JavaScript and in print.

The real controller was unit-tested with mock DOM/Plotly adapters across all nine combinations, both shading modes and reset;27 corresponding Plotly specifications passed schema validation. These are NOT actual browser tests. Browser automation rejected file:// under its URL policy; no bypass was attempted. Static figures were inspected visually. See results/interaction_checks.json for scope.

## Files and checks

- scripts/simulate.py: data generator, bootstrap, coverage and null simulations;24 internal checks.
- scripts/validate.R:33 independent checks using saved draws, R quantiles, exact conditional bootstrap moments and the analytic normal-model Student t distribution.
- scripts/check_inputs.py: SHA256 and rendering MD5 manifests; replacement/constant-sample edge checks and figure counts. Use --refresh only after intentional data regeneration.
- scripts/test_controls.cjs: optional Node controller unit tests, not a browser test.
- scripts/figures.R: static figures and Quarto facts.
- data/simulated/:800 numerical observations plus bootstrap means and null statistics for each n.
- results/coverage_intervals.csv:18,000 intervals (3 sizes ×3 levels ×2,000 fresh datasets), means and coverage flags.
- results/summary.csv, facts.json, explorer.json: generated facts, bins and first100 intervals.
- assets/:Plotly.js3.1.1 and MIT license, controller, local styles, data wrapper.
- includes/: controls, figure wrappers and fallbacks.

## Method references

- [SciPy bootstrap documentation](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.bootstrap.html): percentile construction and repeated-coverage interpretation. This article explicitly uses percentile rather than the API's default BCa method.
- [SciPy Monte Carlo test documentation](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.monte_carlo_test.html): null simulations and tail probabilities. See the absolute-tail and +1 definitions above.

## Submission

After commit and publication, submit both the article and source repository:

- https://zhenxin-li.github.io/Zhenxin-Li-website/blog/posts/blog8/
- https://github.com/Zhenxin-Li/Zhenxin-Li-website/tree/main/blog/posts/blog8

Include the entire source post and generated docs/blog/posts/blog8 plus the updated blog listing. A successful local render does not establish a completed GitHub deployment.
