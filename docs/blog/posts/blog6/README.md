# Blog6: real PSID father-son income tutorial

This version replaces the earlier simulation. All reported estimates use actual locally downloaded PSID public-use files. The article teaches SQL matching and aggregation within Python; a generated results table is the main output. It makes no national or causal claim and has no known true IGE benchmark.

## Two levels of replication

### Render the article from published aggregate results

Install R, Quarto, knitr and rmarkdown, then from the website root:

```sh
quarto render blog/posts/blog6/index.qmd
```

Rendering reads saved aggregate CSVs under `data/aggregate/`. It does not download data, require a PSID login, run Python, regenerate microdata, or silently fall back to simulation. Missing or failed validation output stops rendering.

### Rebuild all estimates from licensed local PSID files

Install Python 3.10+ and `python -m pip install -r requirements.txt`. From this post directory:

```sh
python scripts/prepare_psid_linkage.py --raw data/raw --db data/private/psid.sqlite --out data/aggregate
python scripts/psid_analysis.py --raw data/raw --db data/private/psid.sqlite --out data/aggregate --cpi data/aggregate/cpi_annual.csv
python scripts/walkthrough.py
```

The first command requires a new database path and will refuse to overwrite an existing one. To rebuild again, select a different local `.sqlite` filename in both commands, or retain the prepared database and rerun the second command. The second script replaces only its own analytical tables, uses a fixed bootstrap seed, and saves aggregate outputs. `walkthrough.py` contains the exact Python blocks from the article; it does not regenerate a fake teaching panel.

Required local structure:

```text
data/raw/ind2023er/IND2023ER.txt
data/raw/ind2023er/IND2023ER.sas
data/raw/pid23/PID23.txt
data/raw/pid23/PID23.sas
data/raw/fam1969.zip
data/raw/fam1970.zip
data/raw/fam1971.zip
data/raw/fam1985.zip
data/raw/fam1986.zip
data/raw/fam1987.zip
data/raw/fam1995er.zip
data/raw/fam1996er.zip
data/raw/fam1997er.zip
```

Keep the nine Family ZIPs intact: the script reads the TXT and corresponding SAS column positions directly from each ZIP without requiring SAS/Stata. The 1997 income field contains an explicit decimal point; it is parsed as a float, not divided by 100 a second time. PSID originals are user-downloaded and require registration/conditions of use: https://simba.isr.umich.edu/Zips/ZipMain.aspx . They are intentionally not bundled or published in GitHub. Consult https://simba.isr.umich.edu/U/CondUse.aspx before sharing microdata. `data/private/` and `data/raw/` belong in `.gitignore`; ignore rules do not automatically untrack files previously committed.

## Source identifiers and selection

2023 Parent Identification Release2 and matching 1968–2023 Individual File: child `(PID2,PID3)` joins `(ER30001,ER30002)`, recorded father `(PID23,PID24)` joins the same two-part Individual key. Positive recorded father IDs with person number1–995 are retained only when both people are in Individual. No same-current-household or same-1968-family condition is imposed. PID documentation cautions that some father identifications do not distinguish biological from adoptive fatherhood; therefore the article says recorded father.

85,536 Individual records and103,725 Parent Identification records pass expected row counts and unique-key checks. Full links:29,218 recorded-father links and41,839 recorded-mother links, not independent family counts.

The application then selects male children with modal reported birth year1955–1959, excluding cross-wave birth-year discrepancies over one year. Father must be a responding head in each1969–1971 wave, age25–65; son must be a responding head in each1985–1987 and1995–1997 wave. Responding status uses Individual sequence1–20. Head code is1 in early waves and10 in later waves; presence must also be checked because relationship codes can describe departed former heads. Headship permits attaching total family income to the family unit being described without confusing an other-family-member labor variable with head income.

Sample flow:543 linked sons ->197 with complete structural coverage ->191 with all nine usable incomes;170 distinct recorded fathers. This is a deliberately selected unweighted tutorial sample, including original core sample components. It is not a representative U.S. IGE. It excludes women, non-head adult sons, attritors and families lacking usable incomes; no population inference is made. Each son counts once, with father-cluster bootstrap to account for siblings.

## Income definition and verified variables

Income is total family money income before personal income taxes, including household members' sources and transfers; not father/son individual wages, not disposable income, and not equivalized for family size. It may change with marriage and household composition. Early and late individual-labor-income fields have different farm/business coverage, so those fields were deliberately not spliced together.

| Interview wave | Income year | Family key | Family money income |
|---|---|---|---|
|1969|1968|V442|V529|
|1970|1969|V1102|V1514|
|1971|1970|V1802|V2226|
|1985|1984|V11102|V12371|
|1986|1985|V12502|V13623|
|1987|1986|V13702|V14670|
|1995|1994|ER5002|ER6993|
|1996|1995|ER7002|ER9244|
|1997|1996|ER10002|ER12079|

Definitions and codes were read from each locally downloaded official Family codebook. Early total money incomes combine head/spouse taxable income, transfers and other family members' taxable/transfer income; later totals additionally display Social Security separately in their summation. Negative/zero income was bottom-coded to1 in some early waves. Main analysis conservatively requires nominal income>1 in all nine waves, not merely a positive three-year average. Upper/sentinel cutoffs are99999 for1969–1971,999999 for1985,9999999 for1986/1987/1995/1996,999999 for1997. Upper-coded amounts are excluded, not assumed exact. `source_variables.csv` records exact labels, bounds, full-wave counts and SHA256 hashes. Imputations embedded in official total-income measures are retained; no imputation-free claim is made.

Income is deflated using CPI-U annual averages, all items, U.S. city average, to1996 dollars: `real=nominal*CPI_1996/CPI_income_year`. Annual values are saved in `cpi_annual.csv`; original public HTML is retained as `cpi_source.html`. Source: Federal Reserve Bank of Minneapolis compilation of BLS CPI-U, https://www.minneapolisfed.org/about-us/monetary-policy/inflation-calculator/consumer-price-index-1913- . Using an arbitrary common base would change log intercepts, not the IGE; deflation before multi-year averaging still matters.

## Estimation and uncertainty

Single-year parent income is calendar1969 (wave1970); son early is1985 (wave1986), midlife1995 (wave1996). Multi-year means are calendar1968–1970,1984–1986,1994–1996. Take logs AFTER averaging real income levels. All four OLS regressions include an intercept and identical191 pairs. Mean interview ages are father42.97 in1970, son28.51 in1986 and38.42 in1996; income-year ages are roughly one year younger. These are not identical ages for every respondent.

IGE estimates: early single .350706; midlife single .496287; early average .390783; midlife average .524885. Percentile95% intervals resample170 recorded fathers with replacement and retain all their included sons,500 times with seed640006. The same cluster draws yield paired intervals for differences; these include zero for both midlife-minus-early single-year and midlife averaging-minus-single-year. Do not infer a statistically established increase from the point estimates.

The ten-calendar-year age-window comparison is relevant to life-cycle measurement sensitivity, but period conditions and household composition also change. True permanent income is unobserved; there is no proof of the direction/magnitude of bias in these data. The rationale for averaging is reduction of transitory fluctuations, under assumptions; persistent shocks, selection and household changes can limit this. Background: Haider and Solon(2006), https://www.nber.org/papers/w11943 . This is not a replication of their sample or estimates.

Sensitivity outputs add child birth-year and parent-age controls, select one son per father (first stable child key, not chosen by income), and exclude one age record whose reported age increment is8 rather than9–11. Among all191, increments between1986/1996 are8(1),9(19),10(167),11(4). This reporting/timing variation is documented, not silently forced to10. The age-consistent190-person sample gives nearly identical estimates; these checks do not remove all confounding.

## Public outputs and tests

`data/aggregate/` contains only grouped statistics and provenance: estimates, paired differences, sample flow, age summaries, sensitivities, source-variable mapping, validation and manifest; no household IDs, income records or individual database is exported. `scripts/` contains the actual parser, SQL matching/aggregation, main estimation and runnable tutorial.

Six main checks pass: unique child pairs; all nine required positive usable incomes; decade-separated windows with increasing reported ages; three incomes per accepted window; nonzero composite parent keys; finite OLS results. The full parser and analysis were rerun from all original files into a fresh SQLite database, reproducing the estimates CSV byte-for-byte. All article Python blocks were executed on a copy of the real database and reproduced the four estimates.

## Submission

Article: https://zhenxin-li.github.io/Zhenxin-Li-website/blog/posts/blog6/

Repository: https://github.com/Zhenxin-Li/Zhenxin-Li-website

Commit code, aggregate data, README and updated docs article/listing. Do not commit raw/private PSID files. Local completion is not publishing; verify the new PSID title and191-pair result table after deployment. Simulation files from the former article were backed up outside the live post rather than mixed into this PSID version.

## Final assignment review

The final article contains 686 words of paragraph text, excluding headings, code and the result table. It explicitly displays the final composite-key joins and checks 191 outputs. A conditional log-income example explains how life-cycle bias can arise; it is distinguished from the real-data age-window comparison, which cannot identify pure age effects. Final tutorial blocks were executed in order against a private database copy and reproduced the four IGE estimates.
