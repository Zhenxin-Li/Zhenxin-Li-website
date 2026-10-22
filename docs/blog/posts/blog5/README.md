# Blog 5: specialization and household income

**Single question:** Do counties with above-average manufacturing or professional/business-services employment shares also have higher median household incomes?

The post has two complementary figures. The county maps locate sector concentration; the grouped income distributions directly display the relationship in the question. There is no employment-growth, wage, unemployment, population, or education analysis in this revision. No causal effects are estimated.

## Reproduce

Install R 4.1 or newer, Quarto, and the R packages:

```r
install.packages(c("dplyr", "tidyr", "ggplot2", "sf", "readr", "scales", "jsonlite", "knitr", "rmarkdown"))
```

From the website repository root:

```sh
quarto render blog/posts/blog5/index.qmd
```

In RStudio, open this QMD and use the document's Render button or Ctrl+Shift+K. The existing single-render setup avoids launching a whole-site preview. A parent blog listing may still be regenerated without executing other articles' analyses.

All five real source snapshots are included. **Ordinary rendering needs no download and no Census API key.** Source/output paths are derived from the QMD location; the stylesheet path is relative. Exact R and spatial-library versions are saved in `results/sessionInfo.txt`; versions are recorded rather than automatically locked. A working `sf` installation needs GDAL/GEOS/PROJ; the Windows binary normally supplies them.

## Files

```text
blog/posts/blog5/
  index.qmd                     # Article and both figure definitions
  README.md
  scripts/data.R                # Acquisition, validation, and cache reuse
  scripts/analysis.R            # Joins, LQ, income groups, and audits
  data/raw/
    qcew_2024_10.csv
    qcew_2024_1013.csv
    qcew_2024_1024.csv
    acs5_2024_income.json
    cb_2024_us_county_20m.zip
    *.source.txt                # Actual URL without credentials, UTC retrieval time
  figures/
    figure1_specialization_maps.png
    figure2_income_comparison.png
  results/                      # Derived records, summaries, and validation audits
```

[Acquisition code](scripts/data.R) and [analysis code](scripts/analysis.R) are part of the post. The figures and numerical prose are generated from saved source data. No values are manually pasted into the article. Historical files from the previous version are backed up separately and are not required to reproduce this revision.

## Sources and definitions

| Input | Official source and definition |
| --- | --- |
| QCEW codes 10, 1013, 1024 | `https://data.bls.gov/cew/data/api/2024/a/industry/CODE.csv`; annual-average employment, private ownership 5, establishment-size code 0 |
| ACS B19013 | County API request at `https://api.census.gov/data/2024/acs/acs5`, fields `NAME,B19013_001E,B19013_001M`; 2020-2024 median household income and 90% margin of error, in 2024 dollars |
| County geometry | `https://www2.census.gov/geo/tiger/GENZ2024/shp/cb_2024_us_county_20m.zip`; 2024 Census cartographic polygons, 1:20,000,000 display scale |

Documentation: [QCEW slices](https://www.bls.gov/cew/additional-resources/open-data/csv-data-slices.htm), [sector definitions](https://www.bls.gov/cew/classifications/industry/industry-titles.htm), [ACS B19013](https://api.census.gov/data/2024/acs/acs5/groups/B19013.html), [Census boundaries](https://www.census.gov/geographies/mapping-files/time-series/geo/cartographic-boundary.html).

The professional/business-services supersector includes NAICS 54, 55, and 56: professional/technical work, management, and administrative/support/waste services. It is not exclusively high-skill work. QCEW describes covered jobs at workplaces, not distinct resident workers or all self-employment. ACS describes resident households, and its five-year estimate is not a single-year 2024 observation or a measure of change. Current-dollar units within this five-year release are adjusted to common 2024 dollars, not to each county's cost of living.

## Geographic and statistical choices

- Study area: the contiguous 48 states plus DC, 3,109 county/county-equivalent polygons in this snapshot. Alaska, Hawaii, and territories are outside the displayed sample. Current Connecticut planning regions are consistently matched across 2024 QCEW, ACS, and boundaries; no historical county comparison is attempted.
- Preserve five-character GEOIDs as strings. Match by GEOID, not names. Require unique keys, a matching ACS county name for every polygon, and no unmatched real QCEW county keys. Keep county aggregation codes 71/73; exclude state/MSA rows. Area codes ending in 999 are unallocated employment records and are saved separately, never mapped as counties.
- Use NAD83 / Conus Albers, EPSG:5070. Both map panels share fixed LQ classes and state outlines. Polygon area is land area, not employment weight. Gray indicates missing/suppressed/invalid observations, not zero.
- Compute `LQ = (county sector employment / county total private employment) / (U.S. sector employment / U.S. total private employment)`. The national benchmark uses published `US000` totals, including employment outside the mapped subset. Do not sum incomplete county disclosures to estimate the U.S. share.
- The author-calculated private-employment LQ is intentionally different from the raw file's precomputed LQ, whose denominator covers all ownerships ([BLS definition](https://www.bls.gov/cew/about-data/location-quotients-explained.htm)). The article states its private-sector denominator explicitly.
- `disclosure_code == N` is suppressed employment, even if a raw numeric field contains zero. Convert it to NA. Absent rows remain missing. A published zero may be used when the total private-employment denominator is positive. Require all computed shares to lie in [0,1].
- Figure 2 groups counties at LQ < 1 versus LQ >= 1. Require a finite LQ, positive ACS income estimate, and nonnegative reported MOE; negative ACS sentinels become NA. Counties receive equal weight. Boxes describe a distribution of county medians, not individual households or workers. The reported difference is the difference between the two groups' medians of county estimates; it is not a household-level treatment effect or a national median.
- Repeat comparisons (a) after dropping estimates with MOE/estimate > 0.30, and (b) on the same counties observed in both sectors. These sensitivity checks address precision and composition, without asserting significance or causality. Suppression is not random, so even stable results need that limitation.
- Education, urbanization, household composition, commuting, nonwage income, and local costs are not controlled for. Do not claim that industry lowers unemployment, attracts population, or raises household incomes from these comparisons.

## Saved outputs and checks

`county_analysis_2024.csv` contains every map county-sector record and availability flag. `national_benchmarks.csv` saves U.S. sector shares. `income_group_summary.csv` supports Figure 2 and the main comparisons. `income_precision_sensitivity.csv` and `common_county_sensitivity.csv` support the two sensitivity checks. `sample_coverage.csv`, `unmatched_qcew_keys.csv`, and `unallocated_county_records.csv` audit inclusion and geography. `large_specialized_counties.csv` is an optional audit of large employment centers, not an additional claim in the article.

Assertions cover key uniqueness, spatial validity, matching, denominators, and shares. `validation_checks.csv` records passed checks; `snapshot_checksums.csv` identifies raw bytes; `sessionInfo.txt` records software. The post has been rendered using the cached files while R download calls were disabled, and both figures have been visually inspected.

## Refresh deliberately

Archive and move aside `data/raw/`, then render with internet access. Set your private `CENSUS_API_KEY` only if a missing ACS snapshot must be refreshed and the API requires it. Never commit `.Renviron` or a key. Responses are validated before saving; errors and source metadata omit credentials. Ordinary renders never refresh files just because the upstream data may have changed. Revisions upstream can change results, so the saved snapshots define this version.

## Git and submission: important

The former `.gitignore` rule excluding `/blog/posts/blog5/data/` must be removed. A local file is not automatically in GitHub. From the repository root, check:

```sh
git status --short --untracked-files=all -- blog/posts/blog5
git check-ignore blog/posts/blog5/data/raw/qcew_2024_10.csv
```

The second command should print nothing and return exit code 1 (not ignored). Stage the full post, including its saved data, plus the updated root README and `.gitignore`, then inspect the staged diff and file list before committing and pushing. Publication and pushing are separate from local rendering; they have not been performed automatically.

Submit the published **article**, whose path is `blog/posts/blog5/` (or its `index.html`), plus the GitHub repository URL. Do not submit `blog/`, which is the listing. Confirm that the final URL opens the title **Do Specialized Counties Have Higher Household Incomes?**, not **Blog**. The exact public origin must be verified against the user's actual deployment; see the accompanying submission guide.


## Editorial revision under the updated grading guidance

The rendered article has 650 words of paragraph text (excluding title, headings, captions and code). It asks one question, uses two complementary figures, reports the group income levels and differences explicitly, and makes no unsupported claim about causes or policy effectiveness. Technical detail and sensitivity outputs remain here and in results/. All estimates are unchanged from the audited data pipeline.


