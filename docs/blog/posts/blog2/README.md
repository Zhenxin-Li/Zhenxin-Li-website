# Blog2 replication

**Low P/E Is a Starting Point, Not an Institutional Endorsement**

Question: Did the August2024 low-P/E bank candidates all attract additions by a majority of five managers, and did restricting the shortlist to those stocks improve following-year returns? The primary practical comparison is the filtered five-stock basket versus the complete seven-stock basket; the two excluded stocks are also shown. The earnings-review version is backed up separately and is not part of this article.

## Reproduce the frozen analysis

From this post directory, install missing R packages once, then analyze or render:

```sh
Rscript -e "install.packages(c('rvest','xml2','httr2','jsonlite','dplyr','ggplot2','knitr','rmarkdown'))"
Rscript scripts/analysis.R
quarto render index.qmd --to html
```

From the website root, render only this article:

```sh
quarto render blog/posts/blog2/index.qmd
```

Normal rendering verifies the saved raw-data MD5 manifest and regenerates figures and results **without network requests**. No credentials, private full captures or Python are required for this frozen R analysis. The CSS path is relative to the website. Outputs are saved to data/processed, results and figures.

English dividend dates are parsed explicitly by `scripts/dates.R`, independent of the system language. The analysis works under Chinese and English `LC_TIME` settings without changing RStudio's settings. If validation fails, the error names the failed checks and saves their status in `results/validation.csv`.

## Universe and timing

- The universe is the first ten directly U.S.-listed U.S. parent companies in the asset-ranked table on printed page38 of the New York Fed's Fourth Quarter2023 *Quarterly Trends for Consolidated U.S. Banking Organizations*. Read in rank order and exclude TD Group US Holdings LLC, an unlisted subsidiary of a Canadian parent. The included tickers are JPM,BAC,C,WFC,GS,MS,USB,PNC,TFC,COF. This is a complete application of that size-and-listing rule **within the report's table**, not an industry census. The report excludes savings holding companies and certain non-typical institutions; do not call it the ten largest of every U.S. financial company. Investment banking groups remain included.
- Official source: https://www.newyorkfed.org/medialibrary/media/research/banking_research/QuarterlyTrends2023Q4.pdf?hash=085DF7EB1CAEE14D2FCC011A20B37FD7&sc_lang=en . The retained PDF is the 2023Q4 vintage, with creation/modification metadata April10,2024. Do not substitute a current ranking. `scripts/extract_universe.py` extracts the first eleven rows and applies the disclosed ticker/listing mapping; `data/raw/nyfed_universe.csv` contains the offline factual extract and source URL. The original table was also visually inspected.
- Five-manager panel fixed before inspecting expanded-sample outcomes: Vanguard (CIK102909), BlackRock (CIK1364742), State Street (CIK93751), FMR (CIK315066), Geode (CIK1214717). These are five large filers, **not a representative census of institutions or five independent recommendations**. A firm's consolidated filing combines positions across managed accounts/funds. The primary comparison treats each manager equally when counting additions; it does not infer motives or active conviction.
- Ten original 13F-HR filings, Q1 and Q2 of2024, all published by August14,2024. Their exact accessions, publication dates, report dates and public table endpoints are saved in `data/raw/filings.csv`. No later amendment or quarter-end table containing later filings is substituted for an original filing. Extraction asserts original form type and pre-entry disclosure dates.
- Entry August30,2024; exit August29,2025: each is the last trading day of August. This is one retrospective, exploratory holding period, not a preregistered or out-of-sample strategy validation. Earlier single-manager conclusions were not carried over. Historical market sources for BAC,C,COF,KBE were inherited from the verified case; other prices and all additional filings were collected October30,2026. The three inherited earnings rows and original market captures retain their provenance. Collection in2026 is not presented as collection in2024.

## Earnings multiple and cutoff

P/E = entry closing price / **originally reported full-year2023 GAAP diluted EPS**. This is not TTM, forecast, normalized or subsequently restated EPS. It deliberately uses the same full-year earnings period across companies, rather than claiming to summarize all financial information available in August2024. The earnings source ledger identifies each issuer, source, earnings-release date and definition. Most ledger dates refer to earnings announcements; USB's linked annual financial statements independently verify the annual EPS, not a claimed January publication date for that PDF.

Original EPS: JPM16.23, BAC3.08, C4.04, WFC4.83, GS22.87, MS5.18, USB3.27, PNC12.79, TFC−1.08, COF11.95. The original Truist January release reports −1.08; later reports show −1.09. It is excluded for nonpositive earnings under either value. Source-specific original disclosures, rather than current restated database values, determine the frozen screen. The original C, BAC and COF sources were already verified in the preceding case; other issuer sources were checked for this expansion. EPS transcription is a sourced input, not falsely described as an all-rvest issuer-document extraction.

Primary screen: positive earnings and **unrounded P/E<=20**, retaining seven stocks. GS22.3109 and MS20.0019305 exceed the ceiling; TFC has negative earnings. Display rounding never changes membership. Cutoffs15,16,20,25 were specified in the expanded design. The additional20.01 diagnostic was added after observing MS's near-boundary multiple, and is disclosed as such in `data/design.json`. It was not chosen as an optimal rule. All five cutoffs are reported; the primary20 rule is unchanged.

## Holding changes and completeness

- rvest reads original HTML filing metadata and the actual `table[data-url]` link. httr2 retrieves the advertised public JSON; jsonlite parses it. Selected JSON fields are ticker,issuer,class,CUSIP,value,rounded portfolio weight,shares,principal/other field,option type. Only common-share rows with a null option type are used. Market value changes are not called buying.
- Security matching uses the nine-character CUSIP in `data/security_identity.csv`, derived from the original Vanguard Q1 table. The same key matches each of the ten securities in every other filing. A duplicate common CUSIP row stops the analysis rather than being summed arbitrarily.
- Full captured JSON row counts are checked against the original page's number of holdings before extracting relevant rows. The public JSON retains the selected securities' common and option rows plus `source_total_rows`; private full-capture hashes are recorded. Thus exclusions can be reproduced while the full provider database is not redistributed.
- The stock-by-manager grid contains all ten stocks for all five managers in both periods. A missing common-share row in a validated complete filing would be a zero position, allowing both new positions and exits. A missing/incomplete filing stops the analysis. No conditioning on continuous ownership is imposed. In this actual sample, all50 pairs have positive positions at both endpoints; no new positions or exits occur.
- Primary signal: at least3/5 managers have Q2 shares>Q1 shares. This measures the breadth of additions in the selected panel, not the fraction of all institutions buying. It does not measure purchases minus sales during the quarter, trade dates or investor intent.
- Also report change in the sum of the five filers' positions. This is a sum of **reported positions**, not an independently deduplicated ownership register, outstanding-share percentage or aggregate institutional capital flow. The panel is not assumed to consist of independent decisions. In the seven-stock screen its positive/negative classification happens to match the majority signal.
- No stock splits affect the sampled share quantities in Q1–Q2 or the selected market-price series during the return window. Options and dollar-value changes never enter the common-share signal.

## Returns and results

Return=(exit price−entry price+eligible cash dividends)/entry price. Use Digrin's **Real price** column, not its dividend-adjusted column, and Stock Analysis distributions with ex-date>entry and <=exit. This prevents double-counting dividends. There are four eligible distributions for each of eleven securities, including KBE. Capital One's August25,2025 ex-dividend entitlement is included although paid in September; treat it as a receivable at exit. Dividend entitlements are not reinvested. No fees, taxes or risk adjustment. This is a hypothetical equal-dollar buy-and-hold comparison, not the managers' own realized performance.

Sources:

- Prices: `https://www.digrin.com/stocks/detail/{TICKER}/price`.
- Dividends: `https://stockanalysis.com/stocks/{ticker}/dividend/`; KBE `https://stockanalysis.com/etf/kbe/dividend/`.
- Original manager filings: all ten exact URLs and public JSON endpoints in `data/raw/filings.csv`.
- Original earnings: all ten issuer sources in `data/eps_2023_source_ledger.csv`.

Primary results: majority additions select JPM,C,USB,PNC,COF (5 stocks), mean34.7471%; other stocks BAC,WFC (2), mean35.2201%; all seven34.8823%; KBE15.9793%. The selected group trails the other group by0.4730percentage points and the original shortlist by0.1351points. These are descriptive sample means, not an equivalence test or a statistical finding that institutions lack information.

Sensitivity output retains counterevidence: at20.01, adding MS changes the comparison to37.1027% vs35.2201%. Removing Vanguard, State Street or Geode and requiring a strict majority of the four remaining managers (3/4) moves USB out of the selected group, giving41.5283% vs26.0208%. Removing BlackRock or FMR leaves the primary grouping unchanged. Requiring >1% additions by at least three managers retains only COF; its56.2785% return is a one-company result, not validation of that stricter rule. No favorable variant is promoted to the headline rule.

## Recollect separately

Review the current robots files and terms before any new collection. Do not run the collector during rendering. Copy scripts, design and the original EPS ledger to a fresh project directory; do not overwrite the dated snapshot. With R working in that fresh post directory:

```sh
Rscript scripts/collect.R
python -m pip install pypdf
python scripts/extract_universe.py
Rscript scripts/make_excerpts.R
Rscript scripts/analysis.R
```

The collector identifies the academic AI agent, issues sequential requests at least five seconds apart, caches responses, logs URL/time/status, and stops on a non-200 response. It uses public table-advertised endpoints. No login, CAPTCHA, paywall, hidden paid export or blocked-host workaround. Saved Stock Analysis terms explicitly exempt compliant AI agents/crawlers following robots rules from the general automated-access restriction. Check specific target paths in all robots files before collection, not just the script's root-disallow guard. Full captures are kept in ignored `data/private/full_html`; only small source-linked factual extracts are published. Recollection can change provider history and therefore is separate from frozen replication.

Published logs distinguish new multi-manager requests, new market/universe requests, inherited BlackRock requests, and inherited market requests. These are source provenance, not claims that every artifact was collected in one run. PDF universe extraction and manual original EPS verification supplement the relevant rvest collection. Full documents and provider pages remain local outside the distributed package; their checksums accompany the extracts.

## Files and validation

- `data/design.json`: fixed primary definitions, exploratory status and sensitivity diagnostics.
- `data/raw/`: eleven-row historical universe extract, ten source-linked filing metadata/JSON extracts, selected price/dividend rows, request logs, robots and MD5 manifest.
- `data/security_identity.csv`: stable security keys and original filing descriptions.
- `data/processed/comparison.csv`: every sampled company, including exclusions, all returns and signals.
- `data/processed/manager_positions.csv`: all50 manager–security pairs, counts, changes and entry/exit flags.
- `results/`: primary comparison, all cutoff variants, all five leave-one-manager-out variants, single-manager comparisons, alternative signal definitions, benchmark, fifteen validation checks and R session information.
- `figures/`: two figures generated by R from the saved inputs.
- `scripts/`: collection, factual excerpt creation, universe extraction and offline analysis.

Independent validation compares all ten original filing captures and all eleven securities' full market tables with the small published extracts, checks all100 share quantities and44 dividends, recomputes screening and returns, and checks the NYFed table against the selected universe. Figures were visually inspected. This does not claim a browser interaction test.

Post URL: https://zhenxin-li.github.io/Zhenxin-Li-website/blog/posts/blog2/

Repository: https://github.com/Zhenxin-Li/Zhenxin-Li-website/tree/main/blog/posts/blog2

The title and Blog2 URL are preserved. Blog2.5 remains the separate, unchanged Berkshire case.
