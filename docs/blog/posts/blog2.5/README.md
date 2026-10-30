# Blog 2.5: Berkshire bank-holdings case

Title: **Low P/E Is a Starting Point, Not an Investment Recommendation**. This Berkshire case is now the Blog2.5 alternative at /blog/posts/blog2.5/; the packaging-stock screen is primary Blog2.

## Question and scope

Did the two lowest price/FY2023-EPS U.S. bank holding-company positions in Berkshire's June 2024 disclosure outperform a bank ETF over the following month-end-to-month-end year? This is one historical case, not a causal estimate, a validated strategy or evidence about institutional motives.

The filing is accession 000095012324008740, report date June 30, 2024, filed August 14, 2024. 13f.info aggregates positions across the original filing's other managers; use its aggregated 41-position dataset, not individual submanager rows. Source: https://13f.info/13f/000095012324008740-berkshire-hathaway-inc-q2-2024 . The public table advertises its /data/13f/000095012324008740 endpoint through a data-url attribute, extracted with rvest. No private or guessed endpoint is used.

Five U.S. bank holding-company common-stock positions are included: AXP, BAC, C, COF, ALLY. American Express is included despite its card/payments emphasis. NU is foreign; Jefferies is an investment-bank holding, not in this depository-bank group. Insurers, payments networks and other nonbank businesses are excluded. This focused universe is not all banks, all Berkshire holdings or a representative stock-market sample. KBE is a broad bank-ETF benchmark, not a precisely business-model-matched control.

## Frozen analytical rules

See data/design.json. Entry is the first month-end after the filing, August 30, 2024; exit is August 29, 2025. This is not an immediate filing-day trade. A prior feasibility inspection had already viewed BAC price history. Dates and the two-of-five screen were written before downloading the other five price series or calculating case returns. This is an illustrative retrospective case, not a preregistered experiment; do not imply that the year was randomly selected or that outperformance establishes a stable effect.

Rank price / originally reported FY2023 GAAP diluted EPS and retain the lowest two positive ratios. Both prices and fiscal earnings were available by entry. Annual FY2023 EPS is deliberately lagged and is NOT TTM, forward earnings or adjusted earnings. The bottom two of five is 40%; this is a transparent local ranking choice, not a full replication of Dreman's screens or evidence that the stocks were undervalued. The saved top-1 through top-5 sensitivity results expose dependence on list size.

Each selected stock receives half the initial capital. There is no rebalancing, reinvestment or sale triggered by later Berkshire transactions. Both initial names and the three exclusions remain in the outcome table. No stock in this five-name cohort delisted or split during the observation window; COF's acquisition changed its business but does not justify removing it retrospectively.

## EPS input provenance: important

The five EPS entries in data/eps_2023_source_ledger.csv are curated raw inputs from original issuer documents, with source URLs and pre-entry public dates. They are not represented as rvest-extracted earnings. rvest supplies the substantive holdings, historical prices and dividends used by the analysis. C, COF and AXP values were checked against the original issuer releases consulted separately. BAC's original HTML report and Ally's original PDF were also downloaded and retained privately. Check data/raw/ALLY_eps_verification.txt and scripts/verify_original_eps.py.

Original values are BAC 3.08, C 4.04, COF 11.95, ALLY 2.98, AXP 11.21. Do not substitute current historical-table values such as BAC 3.05, C 3.63 or ALLY 2.77. Restated/reclassified histories can differ from the original reports. Ally's original PDF page 3 explicitly gives 2.98; its 2023 10-K was public February 20, 2024. The analysis reads these source inputs but computes all P/E ratios, selections, returns, tables and figure programmatically.

Some issuer robot requests returned HTTP 403 (Citi, Capital One and the AXP document host). Collection was stopped for those hosts; no retry, login, alternate identity or access bypass was used. Their earlier public-document checks are documented as manual source verification, not falsely logged as successful R downloads.

## Price and dividend calculations

Digrin's price pages contain a monthly Date / Adjusted price / Real price table. Use **Real price**, not Adjusted price: dividends are added separately. The August observations are month-end closes; entry BAC 40.75 and COF 146.93 also match independently inspected dated historical tables. Retain both source columns so the distinction can be audited. The provider's rounding is cents, so displayed percentage results are rounded to one decimal.

Stock Analysis dividend tables give ex-dividend dates, per-share amounts and payment dates. Each of the six securities has four eligible distributions with ex-dates in (2024-08-30, 2025-08-29]. Return = (exit price - entry price + eligible dividends) / entry price. Dividends are not reinvested. This is wealth including dividend entitlements: COF's August 2025 dividend had been earned by exit but was payable in September, so it is a receivable at exit. Do not describe the whole dividend sum as cash already received. The investor can receive it after selling once the ex-date has passed. Taxes, transaction costs and interest on cash are omitted consistently. ETF operating expenses are already reflected in the fund's traded value.

The equal-weight return is the average of constituent buy-and-hold returns, not an average of daily percentage changes. KBE uses identical dates and dividend handling. It is a quoted ETF price comparison, not NAV performance and not a reinvested-dividend index return. The all-five comparison overlaps the selected basket and is not an independent control group.

## Ethical acquisition and saved evidence

scripts/collect.R uses httr2 HTTP requests and rvest extraction. Requests are sequential and delayed at least five seconds within that collection. It saves status, timestamp, content type and URL, stops on errors and has no challenge-solving or login functionality. The linked JSON is public table data. All page identities and dates are checked before analysis.

- 13f.info robots disallow search/form-D paths, not the filing/table paths used here; its public data require no account.
- Digrin robots disallow /search. Its terms prohibit scraping that burdens systems or violates terms. This one-off collection is limited to six public price tables, sequential and low frequency; no account content or paid interface was accessed.
- Stock Analysis explicitly excepts robots-compliant AI agents from its general automation prohibition. This collection used the identified Codex AI agent under that exception; its wildcard blocked /e/ and /p/, neither requested. This is not blanket permission for future users.
- Yahoo's query host returned robots Disallow: /. It was not used for data.

The full source pages and original documents are in data/private/full_html, ignored by Git and excluded from all publishing and ZIPs. Shared source-linked excerpts contain just the two relevant monthly rows and four relevant dividend rows for each security, plus filing metadata and small factual holdings JSON. URLs, request logs, original hashes and excerpt hashes are in data/raw. Recheck terms and robots before any new live acquisition. Rendering never makes network requests.

## Offline replication

Required: R with rvest, xml2, httr2, jsonlite, dplyr, ggplot2, knitr and rmarkdown; Quarto. Exact R package versions: results/sessionInfo.txt. Optional original-PDF verification uses Python with pypdf.

From this post directory:

```r
post_dir <- normalizePath('.')
source('scripts/analysis.R')
```

From the website root, render only this post:

```sh
quarto render blog/posts/blog2.5/index.qmd
```

A standalone copy needs the supplied website-root styles.css. analysis.R checks the saved manifest, parses source tables, joins by ticker, checks historical dates and complete observations, then writes all results and figure. No absolute local drive paths are required in article analysis. For a future fresh collection, run collect.R from a website-shaped project after setting its documented post path; use a fresh snapshot directory rather than mixing collection dates. make_excerpts.R accepts post via an R variable, or the website-relative default. It requires private originals; it is optional for reproducing the published results from supplied excerpts.

## Outputs

- data/processed/case_data.csv: all five records, earnings sources, P/E, selection and returns.
- data/processed/all_filing_holdings.csv: all 41 factual source holdings.
- results/investor_review.csv: review table with prices, dividend sums and bank-benchmark differences.
- results/portfolio_returns.csv: selected basket, all-five basket and KBE.
- results/screen_sensitivity.csv: lowest one through five holdings.
- results/validation.csv: eight consistency checks.
- figures/one_year_outcomes.png: the sole outcome figure.

This alternative is published at https://zhenxin-li.github.io/Zhenxin-Li-website/blog/posts/blog2.5/ . The /blog/posts/blog2/ URL now points to the packaging-stock screen. No commit, push or deployment is performed automatically.
