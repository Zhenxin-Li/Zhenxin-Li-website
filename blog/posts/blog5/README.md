# Blog 5: county industrial geography

This post asks where manufacturing and professional/business services are concentrated, how their county employment changed from 2019 to 2024, and whether concentration coincides with higher resident household income. It uses three complementary figures: concentration maps, employment-change maps, and income distributions. It is descriptive and does not estimate causal effects.

## Reproduce the post

Install R 4.1 or newer and Quarto. Install these R packages once:

```r
install.packages(c("dplyr", "tidyr", "ggplot2", "sf", "readr", "scales", "jsonlite", "knitr", "rmarkdown"))
```

Use an R installation with working GDAL/GEOS/PROJ support for `sf` (the Windows CRAN binary includes these dependencies). No packages are installed automatically during rendering. Exact versions and spatial-library versions are recorded in `results/sessionInfo.txt`; package versions are documented, not automatically locked.

From the website repository root:

```sh
quarto render blog/posts/blog5/index.qmd
```

In RStudio, open `blog/posts/blog5/index.qmd` and click the document's Render button (Ctrl+Shift+K). The existing RStudio single-render configuration avoids starting a whole-site preview. The website can still regenerate its parent blog listing as part of an incremental render; this does not execute other blog analyses.

All eight real source snapshots are included in `data/raw/`. With the snapshots and installed dependencies, rendering needs neither internet access nor a Census API key. It never downloads again simply because a render was requested. The stylesheet is referenced relative to the QMD (`../../../styles.css`), and data/output locations are resolved from the QMD's location, not a drive letter or the terminal's working directory.

## Repository layout

```text
blog/posts/blog5/
  index.qmd                   # Article and figure code
  README.md                   # This file
  scripts/
    data.R                    # Download, response validation, and caching
    analysis.R                # Joins, transformations, summaries, and assertions
  data/raw/
    qcew_2019_10.csv
    qcew_2019_1013.csv
    qcew_2019_1024.csv
    qcew_2024_10.csv
    qcew_2024_1013.csv
    qcew_2024_1024.csv
    acs5_2024_income.json
    cb_2024_us_county_20m.zip
    *.source.txt              # Actual source URL (no credentials) and UTC retrieval time
  results/                    # Derived CSVs, audits, checksums, and session information
  figures/                    # Three saved PNGs (two maps per map figure)
```

The QMD generates figures from the data; it does not display manually edited or copied results. [Acquisition code](scripts/data.R) and [analysis code](scripts/analysis.R) are part of the replication package. Commit the raw snapshots, metadata, scripts, QMD, README, figures, and results to the repository. Generated website HTML goes to the project's configured output directory (`docs/` in the original website).

## Sources and units

| Source | Exact inputs | Definition |
| --- | --- | --- |
| [BLS QCEW CSV slices](https://www.bls.gov/cew/additional-resources/open-data/csv-data-slices.htm) | `https://data.bls.gov/cew/data/api/YEAR/a/industry/CODE.csv`; years 2019, 2024; codes 10, 1013, 1024 | Annual-average jobs at covered workplaces; ownership 5 (private), size 0 (all establishment sizes) |
| [BLS industry definitions](https://www.bls.gov/cew/classifications/industry/industry-titles.htm) | 10: all industries; 1013: manufacturing; 1024: professional and business services | Sector and denominator use the same private ownership universe |
| [ACS 2024 five-year B19013](https://api.census.gov/data/2024/acs/acs5/groups/B19013.html) | County API request: `NAME,B19013_001E,B19013_001M`; `for=county:*` | Resident median household income and its 90% margin of error; 2020-2024 estimate in 2024 inflation-adjusted dollars |
| [Census cartographic boundaries](https://www.census.gov/geographies/mapping-files/time-series/geo/cartographic-boundary.html) | `https://www2.census.gov/geo/tiger/GENZ2024/shp/cb_2024_us_county_20m.zip` | Generalized 2024 county/county-equivalent polygons at 1:20,000,000 scale |

QCEW covers most wage-and-salary employment but not all work, including most self-employment. Jobs are not unique workers and can be held by commuters. The professional/business-services supersector includes NAICS 54, 55, and 56: professional/technical work, management, and administrative/support/waste services. It must not be interpreted as exclusively high-skill or high-wage employment.

Income is used only cross-sectionally. No comparison of nominal dollar values from different years is made. The ACS five-year period must not be called a single-year 2024 observation. Common 2024 dollar units are not an adjustment for geographic living costs. Survey uncertainty, household composition, and commuting limit comparisons between workplace industry and resident income.

## Geographic universe and joins

- The displayed study area is the contiguous 48 states plus DC: 3,109 polygons in this snapshot. Alaska, Hawaii, and territories are outside the study area, not silently presented as part of an all-county map.
- Preserve five-character county GEOIDs as strings. Join by GEOID, never county name. Assert unique geometry, county-year-sector, and ACS keys. Require a matching ACS geography name for every 2024 map polygon.
- Keep only county-level QCEW aggregation codes 71 (private total) and 73 (private supersector). Exclude state/MSA/national rows from county calculations. Codes ending in 999 are unallocated county records, not actual counties; save them separately.
- Use the official `US000` private-employment totals and sector totals for each year's U.S. LQ benchmark. This is intentionally a national benchmark, not a benchmark estimated from the mapped subset or only nonsuppressed counties.
- These are author-calculated **private-employment** LQs. The precomputed LQ columns in the raw QCEW files use all-industry, all-ownership denominators ([BLS definition](https://www.bls.gov/cew/about-data/location-quotients-explained.htm)), so those columns are deliberately not substituted for the stated private-employment formula.
- [Connecticut replaced its old counties in QCEW beginning in 2024](https://www.bls.gov/cew/classifications/areas/new-2024-connecticut-counties.htm). The 2024 map and ACS join use the new planning regions. All Connecticut observations are excluded from 2019-2024 growth; no false old-to-new county crosswalk is imposed. The only unmatched real county keys allowed are the eight historical Connecticut counties in 2019; any other unexpected unmatched key stops the analysis.
- Use NAD83 / Conus Albers, EPSG:5070, for both map figures. State outlines aid orientation. Simplified polygons are intended for national display, not local boundary measurement. Land area is not employment weight.

## Missingness, disclosure, and transformations

1. Preserve the BLS disclosure flag. `disclosure_code == N` means suppressed; employment becomes NA, never zero. Missing rows remain missing, not evidence that an industry is absent. Published zero employment can be retained where the denominator is valid.
2. County share is sector employment divided by published positive total private employment. LQ divides that share by the matching year's official U.S. private-sector share. Assert all calculated shares lie in [0,1].
3. Both concentration maps use fixed LQ bins: below 0.5, 0.5 to below 1, 1 to below 2, and 2 or above. Gray is unavailable. The scale is identical across sectors and does not cap extreme observations.
4. Growth is `(employment_2024 / employment_2019) - 1`, using published endpoints and at least 100 sector jobs in 2019. It does not require a local all-industry denominator. The same fixed positive/negative percentage classes apply in both maps; open-ended tails avoid hiding values through clipping. No annualized growth rate or pandemic/policy effect is claimed.
5. Growth samples differ across sectors because disclosure and the 100-job baseline rule differ. Report county shares and matched-sample employment totals separately; neither is described as national growth. `initial_jobs_sensitivity.csv` repeats calculations with starting thresholds of 1, 50, 100, and 250 jobs. A five-year endpoint change does not identify its within-period timing. Broad supersectors aid comparability, but establishment reclassification and NAICS changes mean this is not a fixed-establishment panel.
6. ACS negative sentinel estimates/MOEs become NA. Figure 3 requires finite LQ, positive income, and a nonnegative reported margin of error. Each county has equal weight. Its boxes describe distributions of county medians, not households or workers. No point estimates are presented as statistically significant.
7. An income precision sensitivity check excludes estimates with `MOE / estimate > 0.30`. This arbitrary precision screen is documented and does not convert descriptive comparisons into causal or significance tests.

## Saved results

`county_sector_panel.csv`, `current_county_analysis.csv`, and `county_sector_growth.csv` contain the analysis records. `national_benchmarks.csv` saves the published benchmark shares. `income_group_summary.csv`, `income_precision_sensitivity.csv`, `growth_summary.csv`, and `initial_jobs_sensitivity.csv` support all reported numerical comparisons. `large_specialized_counties.csv` selects the examples using an explicit employment ranking within LQ >= 1.5; `largest_absolute_changes.csv` documents large absolute job shifts.

`disclosure_coverage.csv` and `growth_coverage.csv` count every availability/exclusion category. `unmatched_qcew_keys.csv` and `unallocated_county_records.csv` audit geography. `validation_checks.csv` records the completed assertions; `snapshot_checksums.csv` identifies exact input files; `sessionInfo.txt` records the software and spatial libraries. Raw data may be revised upstream, so the saved snapshots define these results.

## Refresh deliberately

Archive and move aside the complete `data/raw/` directory, then render with internet access to request a fresh snapshot. Do not refresh just one sector or year for a comparison without documenting the mixed vintage. For the Census API, set your own `CENSUS_API_KEY` in your private environment if the endpoint requires one; never commit `.Renviron` or an actual key. Missing snapshots are the only reason to request data. Download errors are sanitized, source metadata omits credentials, and a response is validated before it becomes a cached file. Failed downloads do not overwrite working snapshots.

## Validation and submission

The revised post has been rendered with actual BLS/Census data and visually checked. A separate render with R data-download calls disabled verifies use of the saved snapshots. Original code is backed up separately and old generated figures are not used by this revision. The accompanying rubric review explains the ten criteria; it is a self-audit, not a promise of a particular grade.

Submit both the published Blog 5 URL and corresponding GitHub repository URL. Local render verification does not itself publish the site or push commits.
