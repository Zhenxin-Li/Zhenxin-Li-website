# Blog7: State renter cost burdens, 2019-2024

## Question

Which states saw the largest increase in the share of renter households spending at least 30% of household income on gross rent between 2019 and 2024?

This replaces the earlier life-expectancy topic. The article uses one interactive ranked Plotly point chart. A state is one observation, not a tracked household. The principal answer concerns percentage-point changes; 2024 levels provide a contrasting comparison. Rankings are rankings of estimates, not proven population ranks.

## Files

- `index.qmd`, `post.css`: English article and responsive iframe styling.
- `scripts/download_data.py`: validates saved official responses; requests downloads only with `--refresh`.
- `scripts/build.py`: parses both table formats, checks definitions, computes shares and approximate uncertainty, and builds the plot offline.
- `scripts/chart_template.html.txt`: accessible HTML controls and the Plotly filtering logic. This is a text template, not a separate blog post.
- `scripts/test_controls.cjs`: optional Node.js test of the actual generated control logic; not a real browser test.
- `data/raw/`: original public Census bulk files, geography file, table shells, metadata and hash manifest.
- `data/processed/state_comparison.csv`: exactly 50 plotted state records, all endpoint percentages, changes, intervals and denominators.
- `data/processed/annual_measures.csv`: 100 state-year numerator, denominator, excluded, and MOE records.
- `results/`: full ranked estimates, top-five table, variable definitions, validation and QA scope.
- `figures/rent_burden.html`: self-contained chart with embedded Plotly.js; no CDN.
- `figures/figure_spec.json`: generated Plotly specification.

## Official sources and definitions

Both years are **ACS 1-year Detailed Table B25070**. Do not substitute 5-year estimates. The fixed endpoints are 2019 and 2024, not a claim that 2024 is the latest available year.

- [2019 public table-based file](https://www2.census.gov/programs-surveys/acs/summary_file/2019/prototype/1YRData/acsdt1y2019-b25070.dat)
- [2024 public table-based file](https://www2.census.gov/programs-surveys/acs/summary_file/2024/table-based-SF/data/1YRData/acsdt1y2024-b25070.dat)
- [Table-based format guidance](https://www.census.gov/programs-surveys/acs/data/summary-file.Getting_Started.html): 2018-2020 files are under the Prototype folder. This refers to file packaging, not experimental estimates.
- [2024 subject definitions](https://www2.census.gov/programs-surveys/acs/tech_docs/subject_definitions/2024_ACSSubjectDefinitions.pdf)
- [Comparing ACS data](https://www.census.gov/programs-surveys/acs/guidance/comparing-acs-data.html)
- [Census region definitions](https://www2.census.gov/geo/pdfs/maps-data/maps/reference/us_regdiv.pdf)

The Census API data endpoints require a key in the current environment. These public bulk downloads require none. The original bytes are retained; no third-party data mirror or simulation is used. `manifest.json` records the URLs, sizes, recording time and SHA-256 values. The optional metadata endpoint is a metadata query, not an authenticated data query.

The build checks all 11 categories and the renter-occupied housing-unit universe against both saved table shells. Variable names in bulk files are `B25070_E007`, etc.; API spellings reorder the suffix (`B25070_007E`). The two published bulk schemas are the same for this table. The 2019 geography file's `DADSID` matches the data `GEO_ID`; its shorter `GEOID` does not. State names and postal abbreviations are joined on the former. Exclude DC (11) and PR (72); all 50 states are present in both years. State geography is stable for this comparison. Census regions are fixed metadata, not estimated values; their counts are 9 Northeast, 12 Midwest, 16 South and 13 West.

Gross rent is contract rent plus utilities/fuels paid separately by the tenant. Income is total pretax household income. The reported ratio concerns the past 12 months and is computed for each household, rather than dividing a state's median rent by median income. B25070's universe includes all renter-occupied units; cell 011 includes ratios not computed, including no cash rent and zero/negative income. These households are removed from the denominator, not assigned a zero burden. The result therefore refers to households with a computable ratio, not all renters. The exclusion counts and total counts for both years are saved.

Let E### and M### be a cell estimate and its published 90% margin of error:

```text
A = E007 + E008 + E009 + E010    # 30.0-34.9, 35.0-39.9, 40.0-49.9, 50.0+ percent
D = E001 - E011                 # computable rent/income ratios
p = A / D
share = 100*p
change_pp = share_2024 - share_2019
```

The code checks E001 equals the sum of E002 through E011 for each state-year, uses unrounded values throughout, rejects negative/sentinel values, and verifies all source hashes. There is no missing-state interpolation. Each state has one point, regardless of population. No national share is constructed by averaging state percentages.

## Approximate uncertainty

Follow the [Census derived-estimate guidance](https://www.census.gov/content/dam/Census/library/publications/2020/acs/acs_general_handbook_2020_ch08.pdf), chapter 8:

```text
MOE_A = sqrt(M007^2 + M008^2 + M009^2 + M010^2)
MOE_D = sqrt(M001^2 + M011^2)
MOE_share = (100/D) * sqrt(MOE_A^2 - p^2 * MOE_D^2)
```

If the radicand is negative, use the general ratio approximation with a plus sign instead, as the Census guidance instructs. The build saves the number of fallback cases. For the change, approximate the two annual estimates as independent:

```text
MOE_change = sqrt(MOE_share_2019^2 + MOE_share_2024^2)
90% change interval = change_pp +/- MOE_change
```

These are approximations that do not recover all covariance among cells or design effects from microdata. Annual error bars are individual 90% margins, not a joint confidence region. Change intervals are pointwise, not simultaneous intervals for 50-state ranking. The article does not assert a statistically distinct winner or interpret every positive point estimate as a statistically established increase. A rank comparison would require its own uncertainty calculation. No policy, migration, or rent-versus-income causal decomposition is estimated, and the samples do not follow the same households.

## Offline replication

With Python 3.10+, from this post directory:

```sh
python -m pip install -r requirements.txt
python scripts/download_data.py
python scripts/build.py
```

The default download script only validates saved data; it makes no requests. The build uses Python standard libraries and Plotly 6.3.1, including ZIP/XML parsing for the saved Excel table shell; Excel or an additional spreadsheet library is unnecessary.

Optional explicit refresh:

```sh
python scripts/download_data.py --refresh
python scripts/build.py
```

A refresh validates every response before replacing any snapshot. Revisions may change estimates and descriptive rankings; review the article afterward. Rendering never silently refreshes data.

Install Quarto, R and R packages `knitr`, `rmarkdown`. From the website root, render this post only:

```sh
quarto render blog/posts/blog7/index.qmd
```

Rendering reads saved CSV results and embeds the local self-contained figure; it does not run Python or access the network. Rebuild before rendering after any analysis change. The website writes `docs/blog/posts/blog7/` and updates the blog listing. Publish the corresponding docs files as well as the source directory. The source HTML can also be opened directly without serving it.

## Interaction

- The default view ranks the ten largest estimated percentage-point increases. State names are row labels; horizontal position is the estimated change and the zero line means no change.
- Switch to 2024 burden share to reorder the same underlying dataset by current level. Horizontal intervals then change to the approximate annual MOE; the change view uses approximate MOEs of differences. Hover preserves both endpoint shares and the change in either view.
- Region filtering happens before sorting and the top-ten cutoff. Therefore Top 10 is the top ten *within the selected region and measure*, not an intersection with a fixed national list.
- All matching states exposes every state in the selected region; use the keyboard-focusable scrolling plot area to view long lists. The full national list has 50 records.
- Choosing a single state clears the region filter and overrides the count limit. Metric switches preserve that selected state. Changing the region or count restores group exploration.
- Approximate 90% intervals are visible by default and can be hidden. They are pointwise, not confidence intervals for ranks.
- Reset restores the national top ten by change, clears the selected state, and shows intervals. Axis ranges stay fixed within each measure: -12 to +12 percentage points for changes, 30% to 66% for levels.
- Colors and marker shapes identify regions, supplemented by region text in hover. Native controls have labels, focus styles and live status. The article's top-five table and full CSV provide text alternatives.
- Only the ranked point chart is retained; the former scatter view is replaced. No additional substantive figure or expanded research question is introduced.

## Validation and submission

Nine numerical/schema checks are saved in `results/validation.csv`. Optional control-logic test:

```sh
node scripts/test_controls.cjs
```

This state-based test does not substitute for actual browser clicks or visual layout inspection. `results/interaction_checks.txt` records the verification scope and any limitations. Rebuilding from the same snapshots must reproduce processed CSVs and figure HTML byte for byte.

Publish and submit `https://zhenxin-li.github.io/Zhenxin-Li-website/blog/posts/blog7/` plus the GitHub repository URL. Verify the deployed title **Where Did Rent Burdens Rise Most?** The `blog/` index is not the article URL. Keep code, snapshots/provenance, derived CSVs, diagnostics, figure, requirements and README together in Git. Do not include Python caches, local package installations or temporary preview servers.
