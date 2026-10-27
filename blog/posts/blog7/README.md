# Blog 7: Interactive G7 life expectancy comparison

## Question and deliverables

By 2023, how far was each G7 country's life expectancy from its own 2019 level?

- `index.qmd`: English article and generated endpoint table.
- `figures/life_expectancy.html`: self-contained Plotly chart, including Plotly.js.
- `figures/figure_spec.json`: figure specification for inspection.
- `scripts/download_data.py`: explicit World Bank API refresh and snapshot validation.
- `scripts/build.py`: offline transformations, numerical checks, and interactive figure creation.
- `data/raw/wdi_life_expectancy.json`: verbatim public official response (63 observations, 2015-2023).
- `data/raw/manifest.json`: URL, retrieval time, API update date, and SHA-256.
- `data/processed/life_expectancy.csv`: exactly the 35 plotted observations, 2019-2023.
- `results/country_summary.csv`, `facts.json`, `validation.csv`: generated endpoints, troughs, provenance, and checks.

Public article path after deployment: `https://zhenxin-li.github.io/Zhenxin-Li-website/blog/posts/blog7/`.
This is the article path, not the blog listing. Creation here does not itself deploy it.

## Data source, definitions, and scope

World Bank World Development Indicators, indicator **SP.DYN.LE00.IN**, source 2:

https://api.worldbank.org/v2/country/CAN;FRA;DEU;ITA;JPN;GBR;USA/indicator/SP.DYN.LE00.IN?date=2015:2023&format=json&per_page=1000

[Official definition and source metadata](https://databank.worldbank.org/metadataglossary/health-nutrition-and-population-statistics/series/SP.DYN.LE00.IN).
The World Bank lists UN World Population Prospects, national statistical offices and Eurostat as source providers; data are annual and licensed CC BY 4.0. Life expectancy is a period mortality summary, not an observed cohort lifespan or mean age at death. The source compiles different demographic inputs and may revise observations.

The fixed set is Canada, France, Germany, Italy, Japan, UK and US. The API snapshot includes earlier context years but the article deliberately plots only the complete common 2019-2023 window. No missing values, interpolation, population aggregation, smoothing, or causal modeling are introduced. Do not interpret a line between annual markers as additional observations. All analysis uses unrounded values.

`gap_years = life_expectancy[country, year] - life_expectancy[country, 2019]`.
The baseline is fixed and country-specific. This answers an endpoint comparison, not whether countries resumed a pre-2019 growth trend. A trough is the minimum *among the plotted post-baseline years 2020-2023*, not an all-time minimum. Rebound equals 2023 minus that minimum. These are descriptive comparisons without sampling intervals. The 0.1-year closeness threshold is an explicitly descriptive sensitivity check, not a significance test. France's approximately +0.004878 years is described as essentially level, not a meaningful lead.

## Reproduce offline

Use Python 3.10+ and install the pinned Plotly version. From this post directory:

```sh
python -m pip install -r requirements.txt
python scripts/download_data.py
python scripts/build.py
```

The first script, without flags, validates the saved response and does not request the network. `build.py` validates its SHA-256 against the manifest, refuses missing/invalid observations, recomputes every plotted value and all endpoints, saves diagnostics, and generates the complete chart. It makes no network requests and uses only Python's standard library plus Plotly. Dependencies/version information is saved in `results/facts.json`. No simulated or fallback data are used.

Install Quarto, R, and R packages `knitr` and `rmarkdown`. From the website root:

```sh
quarto render blog/posts/blog7/index.qmd
```

Rendering reads the saved country summary, validates saved checks, and embeds the saved chart. It does not execute Python or fetch data; run `build.py` first after any analysis change. The website output goes to `docs/blog/posts/blog7/`. Copy/commit that generated folder and the refreshed `docs/blog/index.html` when deploying this existing docs-based website. Preserve the root `_quarto.yml` and existing `site_libs/` structure.

## Optional explicit refresh

```sh
python scripts/download_data.py --refresh
python scripts/build.py
```

Refresh replaces the public response only after shape/coverage/value validation and records the new vintage/hash. Revised data can change the results; review the article's numerical descriptions and interpretations, including the France classification, before publishing a refreshed version. Ordinary rendering never refreshes data.

## Interaction and accessibility

- Measure buttons switch Plotly trace values between the gap and absolute life expectancy. Hover always retains actual level, baseline, and exact gap.
- Country selector shows one country or all seven; the native Plotly legend supports arbitrary subsets.
- Reset restores all countries and the gap measure, including its fixed axes and zero reference.
- Switching measure preserves the selected countries. Axes remain fixed within each measure to prevent autoscaling from exaggerating an isolated country's changes.
- Buttons and selector are standard keyboard-focusable HTML controls, with visible focus and a live status message. The iframe has a descriptive title.
- The article provides a collapsible endpoint table and downloadable plotted CSV as text alternatives. Hover/legend operation is complemented by the selector; neither color nor hover is required to read endpoint values.
- Plotly.js is embedded; no CDN, API key or server is required to use the saved figure. The HTTP server used during local QA is only a preview convenience.

## Validation

`results/validation.csv` contains eight numerical/packaging checks. Control-logic verification (`node scripts/test_controls.cjs`, optional Node.js dependency) and browser-validation limitations are recorded separately in `results/interaction_checks.txt` after testing the generated chart in a browser. Tests must not be described as passed until performed. Rebuilding the same saved snapshot must reproduce the processed CSV and country summary byte for byte.

Submit both the published article URL and its GitHub repository. Include the QMD, README, scripts, requirements, public raw snapshot/provenance, processed data, results, figure, and generated publication files. Avoid machine-specific paths and do not commit Python package caches or temporary preview servers.
