# Blog8: simulation, bootstrap intervals and hypothesis testing

**Does the Sample Show That the New Electricity Plan Saves Money?**

One question connects three figures: how much evidence does a positive sample mean provide that a different electricity plan saves money on average? This is a known-answer statistical demonstration using entirely simulated savings, not a recommendation about an actual tariff or a claim about observed households.

## Render the saved analysis offline

With R and Quarto installed, install any missing R packages once:

```r
install.packages(c("jsonlite", "ggplot2", "knitr", "rmarkdown"))
```

From the website root:

```sh
quarto render blog/posts/blog8/index.qmd --to html
```

Or from this post directory: `quarto render index.qmd --to html`.
Rendering reads the saved simulation results and regenerates static fallback figures. It does not install packages, access the internet or run the expensive coverage simulation. Relative paths and saved inputs permit reproduction on another computer. JavaScript loads local assets rather than a CDN and does not use fetch(), so the supplied standalone preview also works under file://. PNG fallbacks remain available without JavaScript and when printing. The CSS file ../../../styles.css belongs to the website root.

The local SCSS override disables the Cosmo theme's Google Fonts import and uses system fonts. A portable single-file preview can be regenerated from THIS post directory with `quarto render index.qmd --to html --embed-resources --output blog8-standalone.html`. If keeping both previews, render the normal index.qmd last to regenerate its resource directory. This embeds rendering resources; it does not change the app's local-file access policy or verify its file viewer.

## Regenerate every random draw

From this post directory, with Python and R on PATH:

```sh
python -m pip install -r requirements.txt
python scripts/simulate.py
Rscript scripts/validate.R
python scripts/check_inputs.py --refresh
quarto render index.qmd --to html
```

Only NumPy is required in Python. Python3.12 and NumPy2.3.5 were used for the frozen draws. The generator processes draws in bounded batches; it took about30 seconds in the author's environment, but runtime varies. Seed20261101 is fixed. Distinct SeedSequence streams separate observed bootstraps, fresh datasets, their bootstraps and null samples at each n. The observed dataset uses one master draw; samples of50,200,800 are nested prefixes. Coverage experiments are independently drawn new datasets, not prefixes of the observed sample. Increasing n therefore changes the observed estimate as well as its precision. No seeds or outcomes are selected to force significance or exactly95% coverage.

After regeneration, use the manifest-builder step documented in scripts/check_inputs.py to refresh the snapshot hashes. The same script validates them without modifying data.

## Data-generating model

Saving = old-plan monthly bill minus new-plan monthly bill, holding the household's monthly usage fixed and including fees. Positive means the new plan costs less; negative means it costs more. Independent household savings follow Normal(mean3 dollars, standard deviation20 dollars). This is a convenient teaching distribution for differences, which may be negative. It is not a calibrated electricity-demand model. The true mean is known because the data are generated. No market prices, provider claims, behavioral response, causal estimates or actual household records enter the article.

The statistic of interest is the population mean saving, not the saving of each individual household. The null model changes only the mean to zero; the normal shape and standard deviation20 are retained. The test statistic nevertheless uses each dataset's own sample standard deviation, not the population standard deviation as a substitute.

## Three different repetitions

1. **One-sample bootstrap:** at each n, resample n household savings with replacement9,999 times and compute their means. The percentile interval is the alpha/2 and1−alpha/2 quantiles, with NumPy's linear interpolation (R type7). The histogram contains bootstrap MEANS, not household savings. Reusing observations does not increase the number of distinct households.
2. **Coverage:** for each n, generate2,000 independent samples from Normal(3,20). For EACH new sample, draw999 bootstrap resamples and construct new percentile intervals. Evaluate90%,95%,99% from the same bootstrap draws to isolate changes in confidence level. Coverage checks whether3 lies between each pair of endpoints. The displayed first100 are in their original experiment order, not chosen to exaggerate or improve coverage. Every reported rate uses all2,000. The Monte Carlo standard error of the estimated coverage is sqrt(rate*(1−rate)/2000); it concerns the simulation, not the observed mean's confidence interval. Percentile coverage is approximate, with finite-sample and finite-bootstrap error; it is not assumed exactly equal to the nominal level.
3. **Null simulation:** independently generate50,000 datasets of size n from Normal(0,20). Calculate t=mean/(sample SD/sqrt(n)) for every dataset. The sample SD uses denominator n−1. The two-sided test statistic is |t|, so the Monte Carlo p is (1+number of null |t|>=observed |t|)/(50000+1). This absolute-tail definition is intentional: it need not numerically match SciPy's default convention of twice the smaller simulated signed tail. Under the symmetric normal null both estimate the same theoretical two-sided tail probability. Red rejection boundaries are ±quantile(|null t|, confidence level), giving total tail probability alpha=1−confidence level. A finite simulation never returns p=0.

The percentile interval and simulated Student t test are different approximate procedures. The article does not claim their decisions must agree exactly for every sample/confidence level. Both address the same mean, but the interval uses an empirical bootstrap while the test uses the stated normal null. Neither automatically applies to clustered or nonrepresentative real-world samples.

## Frozen default results

At n200 and95%: observed mean1.651509 dollars, interval[−1.258690,4.468609], observed t1.144340, Monte Carlo p0.2553349. Of2,000 new intervals,1,895 cover3 (94.75%, displayed94.8%). Simulated5% critical boundary is approximately±1.97882. At n50,95% coverage is93.5%; at n800,94.6%. These are simulation results, not estimates of a population's electricity savings.

The default failure to reject occurs even though the model's true mean is3. This supplies a direct example of why a nonsignificant test does not establish zero effect. Significant outcomes under some controls do not guarantee an individual household benefits. The normal model is a transparent assumption, not an empirical finding.

## Interactive controls

- **Sample size50/200/800:** changes the observed sample, its bootstrap, the independent coverage experiment and the null distribution. Larger samples can improve precision while the observed mean moves.
- **Confidence90/95/99%:** changes percentile bounds, coverage and rejection boundaries; alpha is linked to1−confidence. It does NOT change a fixed sample's mean, t statistic or p-value.
- **Highlight:** toggles the shading in Figure3 between p-value tails and rejection regions. It does not change any statistical result.
- **Reset:** restores n200,95% and p-value-tail shading.
- All charts support hover, zoom and local image export. They use precomputed seeded results; controls do not silently reroll samples. Exact p-values and coverage come from unbinned draws, not the displayed histogram bins.

Offline controller tests cover all nine sample-size/confidence combinations, both shading modes, and reset, using a mock DOM/Plotly adapter. All27 corresponding Plotly figure specifications also passed schema validation. This is not an actual browser rendering test. Browser automation rejected the local file:// preview under its URL security policy; no workaround was attempted. Static figures were inspected visually. See results/interaction_checks.json for the exact verification scope.

## Files

- `scripts/simulate.py`: readable model, resampling, coverage and null simulations;24 internal checks.
- `scripts/validate.R`: independent checks using raw saved draws, R type7 quantiles, exact conditional bootstrap moments, and the normal-model Student t distribution.
- `scripts/check_inputs.py`: manifest creation and verification; tiny-sample bootstrap properties.
- `scripts/figures.R`: regenerated PNG fallbacks and numerical values used by Quarto prose.
- `data/simulated/`: one800-household master dataset,9,999 observed bootstrap means and50,000 null t statistics for each n. These are all simulation outputs, not external raw data.
- `results/coverage_intervals.csv`: all18,000 intervals (3 sizes ×3 confidence levels ×2,000 experiments), sample means and coverage flags.
- `results/summary.csv`, `facts.json`, `explorer.json`: machine-generated numerical results; plot bins and first100 intervals.
- `assets/`: vendored Plotly.js3.1.1 (MIT license retained), local controller, styles and data wrapper. No Python Plotly dependency or CDN is needed.
- `includes/`: accessible controls, figure wrappers and static fallbacks.
- `results/validation.csv`, `independent_validation.csv`, `interaction_checks.json`: computational and interaction verification.

## Method sources

- [SciPy: bootstrap procedure and percentile intervals](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.bootstrap.html). This article uses the percentile method explicitly, not SciPy's default BCa method; simulation itself is implemented in NumPy.
- [SciPy: Monte Carlo testing](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.monte_carlo_test.html). See the explicit absolute-tail statistic and +1 correction above.

## Submission

After committing and publishing, submit both:

- Article: https://zhenxin-li.github.io/Zhenxin-Li-website/blog/posts/blog8/
- Repository: https://github.com/Zhenxin-Li/Zhenxin-Li-website/tree/main/blog/posts/blog8

The repository must include the whole post folder and generated docs/blog/posts/blog8 plus the updated blog listing. A local successful preview is not evidence of a completed GitHub deployment.
