# Blog 4: replication

Question: How did grocery prices change relative to overall prices and nominal median household income, comparing 2015-2024 with 2020-2024?

## Layout

```text
blog/posts/blog4/
  blog4_index.qmd    # Article, acquisition, checks, analysis, and plotting code
  README.md
  data/raw/         # Validated input CSVs and actual-source metadata
    sources/        # Original official BLS JSON / Census XLSX fallback responses
  results/          # Derived tables, checksums, R session information
  figures/          # Four generated PNGs
```

Use the existing website root `styles.css`; the QMD refers to it as `../../../styles.css`. The revision package includes a copy for standalone preview.

## Software

Install R 4.1 or newer and Quarto. In R, install:

```r
install.packages(c("dplyr", "tidyr", "ggplot2", "readr", "scales", "knitr", "rmarkdown", "jsonlite", "readxl"))
```

`jsonlite` and `readxl` support the official-source fallback. The saved snapshots can be analyzed without those two packages if no download is needed.

From the website repository root, run:

```sh
quarto render blog/posts/blog4/blog4_index.qmd
quarto preview blog/posts/blog4/blog4_index.qmd
```

Use Ctrl+C to stop preview. The existing website configuration controls the published output directory. The revision package can also be rendered from its own root using the same render command.

## Data acquisition and offline reproduction

The code reuses each existing validated CSV. When a CSV is missing it first tries the FRED graph CSV endpoint, then the official publisher if FRED fails or returns HTML. DATE, date, and observation_date headers are recognized. The code never interprets an HTML maintenance page as observations.

This updated package includes all eight **real** input snapshots, actual-source metadata, original publisher responses, four figures, and calculated results. With these files and installed software, rendering the analysis requires no new data downloads. Keep `data/raw/` in Git alongside the code and README. Do not replace it with the synthetic fixtures used for earlier tests.

FRED was under maintenance when these snapshots were prepared, so all seven CPI series were obtained directly from the BLS API and income from Census Table H-5. The normalized CSV filenames retain the familiar FRED identifiers as series keys; they are not represented as original FRED downloads. The actual source and URL are recorded in each `.source.txt` file. Original BLS JSON and Census XLSX bytes are retained under `data/raw/sources/`.

### Official fallback

- BLS API URL: `https://api.bls.gov/publicAPI/v2/timeseries/data/SERIES?startyear=START&endyear=END`. The code requests 2014-2023 and 2024 separately, within the unregistered ten-year request window. `CPIAUCSL` maps to the equivalent BLS seasonally adjusted all-items series `CUSR0000SA0`; other CPI IDs are unchanged.
- Census workbook: `https://www2.census.gov/programs-surveys/cps/tables/time-series/historical-income-households/h05.xlsx`. Select Table H-5, All Races, Median income, Current dollars. Use the first, updated row when a year appears twice (2017). Published values are rounded and can differ slightly from a FRED vintage. The code confirms the section and column labels and requires all 2014-2024 years.
- [BLS API documentation](https://www.bls.gov/developers/api_signature_v2.htm)
- [Census household income tables and footnotes](https://www.census.gov/data/tables/time-series/demo/income-poverty/historical-income-households.html)

## Series dictionary

| CSV series key | Measure | Original publisher |
| --- | --- | --- |
| CUSR0000SAF11 | Food at home | BLS |
| CPIAUCSL | All items; BLS equivalent CUSR0000SA0 | BLS |
| CUSR0000SAF111 | Cereals and bakery products | BLS |
| CUSR0000SAF112 | Meats, poultry, fish, and eggs | BLS |
| CUSR0000SAF113 | Fruits and vegetables | BLS |
| CUSR0000SAF114 | Nonalcoholic beverages and beverage materials | BLS |
| CUSR0000SEFJ | Dairy and related products | BLS |
| MEHOINUSA646N | Nominal median household income; Census H-5 fallback | Census |

All CPI series are monthly, seasonally adjusted CPI-U indexes for the U.S. city average, 1982-1984 = 100. Income is annual current-dollar median household income, not wages or inflation-adjusted income. FRED definitions can be consulted at `https://fred.stlouisfed.org/series/SERIES_KEY`.

## Transformations

1. Validate January 2014-December 2024 monthly CPI and 2014-2024 annual income. Reject unexpected, duplicate, missing, or nonpositive observations.
2. Average twelve monthly CPI levels per year; use 2015-2024 for annual analysis.
3. Relative food price: `100 * (food_CPI / overall_CPI) / (food_CPI_2015 / overall_CPI_2015)`.
4. Monthly food inflation: `100 * (CPI_t / CPI_t_minus_12 - 1)`. Compute the lag before dropping 2014.
5. Category growth: `100 * (CPI_2024 / CPI_2015 - 1)`. Selected categories are unweighted comparisons, not contributions to total inflation.
6. Food purchasing power: `100 * (nominal_income / food_CPI) / (nominal_income_2015 / food_CPI_2015)`.
7. Report endpoint percentage changes for both 2015-2024 and 2020-2024. Values in the article are calculated automatically.

## Refresh and outputs

For an intentional refresh, archive and move aside the entire `data/raw/` folder, including `sources/`, then render with internet access. This avoids combining old publisher responses with newly requested observations. Partial downloads may leave incomplete source files; if a fallback download failed, inspect or remove that failed source file before retrying. Do not remove working snapshots merely because FRED is temporarily unavailable.

`results/` contains annual CPI, endpoint comparisons, relative prices and purchasing power, monthly inflation, category changes, input checksums, and R session information. Figures are also saved as PNGs. Exact package versions are recorded after execution but are not automatically locked. Historical revisions and the Census table's rounding can change results across snapshots.

## Validation

The revised code completed a real-data Quarto render using official publisher downloads. The package now contains those real observations; the earlier FRED-only failure has been resolved through the fallback. An additional cached render checks that data acquisition is unnecessary once the snapshots exist. Synthetic data are not included in this package.
