# Blog 2 replication: low P/E and institutional ownership

The revised post answers one descriptive question in a saved historical sample. It is written as an article, with intuitive methods and evidence before a single folded code appendix. It does not establish fair value, predict returns or provide a current recommendation to buy or sell.

## Reproduce offline

Install R, Quarto, and R packages:

```r
install.packages(c("dplyr", "ggplot2", "knitr", "rmarkdown", "rvest"))
```

From the website repository root:

```sh
quarto render blog/posts/blog2/index.qmd
```

The QMD executes `scripts/analysis.R`, reads the saved CSV, regenerates all results and the figure, and inserts computed values and a company table into the article. Only dplyr/ggplot2 are needed by the analysis; rvest is needed for the acquisition code and parser check. Normal rendering performs no downloads and does not install packages. Base-R knitr execution needs no Python or Jupyter.

## Files and provenance

- `data/raw/finviz_original.csv`: unchanged real CSV from the original project, originally located at repository `data/raw/finviz_all_views_raw.csv`; 214 merged rows. The checksum is in `results/snapshot_checksum.csv`.
- `data/raw/provenance.txt`: known source, file timestamp and limitations. Timestamp is not a verified capture date.
- `scripts/scrape_original.R.txt`: original rvest collector retained as inert text for historical provenance. It is not automatically sourced. It includes old positional assumptions and an install command; do not run it unchanged.
- `scripts/parse_saved_html.R`: replacement local-HTML rvest parser requiring header-labelled columns, valid actual tickers and unique keys. It does not acquire new financial observations. The original HTML was not retained, so this cannot retrospectively reconstruct every field from the old pages.
- `scripts/analysis.R`: complete runnable cached analysis. Its text appears as one folded block after the article; code is not interleaved with directory-management explanations.
- `scripts/verify_parser.R`: synthetic HTML unit fixture, never used as data; rejects numeric pseudo-tickers and duplicate tickers. Run `Rscript blog/posts/blog2/scripts/verify_parser.R blog/posts/blog2` from the repository root.
- `results/`: sample flow, clean companies, low-P/E subset, thresholds, sensitivity comparisons, integrity checks, snapshot hash and actual session information.
- `figures/company_screen.png`: one substantive joint company-level figure; the article's table supplies exact low-P/E values. Blog2 does not require three figures.

The analytical sample has 22 companies: 214 raw rows, 199 distinct full records, 87 USA records excluding ETFs/shells, 53 in the USD300m–<10bn range, 31 with P/E in (0,200] and usable nonnegative institutional ownership, then 22 after requiring ownership <=100%. There are 6 P/E<=10 companies, 3 below the sample ownership median 70.905%. The lowest and highest ownership in this subset are 20.64% and 98.61%.

## Corrections and scope

The old ticker field contains numeric page-row IDs. It is renamed `source_row_number`, never presented as a trading ticker or used to join new observations. Unique company names are adequate only inside this fixed saved file; they are not universal stable identifiers. Exact duplicated full rows are removed, and distinct company names are verified. No attempt is made to recreate possibly lost mismatches during the original merging process.

The source columns `short_float` and `short_ratio` are ambiguous relative to their labels: the former includes signed percentages and the latter percentage strings, inconsistent with the old interpretation. They are excluded completely from the revised analysis. Negative signed changes are not converted to zero or described as negative short interest. There is no historical HTML to validate a repair, so the article no longer makes a short-interest/value-trap claim.

P/E is a positive trailing multiple; 10 is a transparent illustrative screen, not a fair-value estimate. We do not turn missing earnings into zero. Ownership is the reported percentage, not institutional confidence or evidence of recent buying/selling. Nine records with ownership >100% are excluded from the main analysis without clipping; a sensitivity retains them (31 observations, 7 low-P/E companies, 5 below that expanded sample's median of 90.11%). The interpretation remains descriptive and cutoff-dependent.

P/E cutoffs 8/10/12 yield 5/6/9 companies, respectively; below-median-ownership counts are 3/3/5. The sample is alphabetical and nonrandom, with no sector weights, time series or return outcome. Sector comparisons and market-wide conclusions are not supported.

## Acquisition and access restrictions

The original code uses rvest::read_html, HTML row/cell extraction and joins across four views. It specifies 10 pages **per view** (40 attempted requests), 7-second pauses, no sort parameter, no geographic/size filters and offsets 0,20,...180. Thus old claims of only ten total requests, multi-sort sampling and a prefiltered U.S. universe are not supported by that code. The revision corrects those statements rather than reproducing them.

This revision fetches no new screener pages. Current generic screener restrictions are visible at https://finviz.com/robots.txt . Future collection must first check current robots rules, terms and permission; do not try alternate endpoints to evade restrictions, logins, CAPTCHAs or paywalls. Rate limiting alone does not establish permission. No original request log, robots snapshot, or raw HTML was retained; historical compliance and capture time cannot now be independently established. The revised code does not claim otherwise. Reanalysis of the existing CSV is reproducible; complete reacquisition of identical historical source pages is not.

Definitions: https://finviz.com/help/screener (P/E and institutional ownership). The rvest parser uses official documented table extraction: https://rvest.tidyverse.org/reference/html_table.html . Preserve future permitted raw HTML, source URLs, UTC capture timestamps, request counts and data dictionaries before making claims.

## Publish and submit

Website article: https://zhenxin-li.github.io/Zhenxin-Li-website/blog/posts/blog2/

Repository: https://github.com/Zhenxin-Li/Zhenxin-Li-website

Keep raw snapshots, README, source scripts, results and figure in Git. Also commit updated `docs/blog/posts/blog2/` and `docs/blog/index.html` if Pages publishes from docs. Local rendering is not deployment. After pushing, verify the new title and table at the exact article URL; do not submit the blog index.
