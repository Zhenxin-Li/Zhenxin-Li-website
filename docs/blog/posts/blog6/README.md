# Blog 6: Matching generations with Python and SQL

This is an educational simulation, not an empirical estimate of U.S. mobility. One focused question: how does income timing change the IGE for the same families?

## Reproduce

Install Python 3.10+ and run from this directory:

```sh
python -m pip install -r requirements.txt
python scripts/analysis.py
```

Only numpy is external; sqlite3, csv, pathlib, and SVG generation use the Python standard library. `results/environment.json` records the tested versions. The full pipeline runs offline once numpy is installed. There are no external data downloads or credentials.

For the webpage, install Quarto, R, and the R packages knitr and rmarkdown. From the repository root run:

```sh
quarto render blog/posts/blog6/index.qmd
```

The QMD executes the complete Python analysis with `system2` and imports generated numbers into the narrative. Set `BLOG6_PYTHON` to your Python executable if it is not on PATH or RStudio finds the wrong interpreter. Example in RStudio: `Sys.setenv(BLOG6_PYTHON = "C:/path/to/python.exe")`. This is a user setting, not a hard-coded source path. No Jupyter installation is needed. Python/SQL blocks in the article explain the pipeline; `analysis.py` and `match.sql` contain the full runnable implementation.

## Files and data dictionary

- `scripts/analysis.py`: deterministic generation when snapshots are absent, CSV loading, SQL execution, OLS, 400 family-pair bootstrap replicates, audits and SVGs.
- `scripts/match.sql`: identity match, person-level conditional aggregation, coverage filter, final joined sample.
- `data/raw/persons.csv`: 8,000 people; unique person_id; shared origin_family_id; current_family_id differs across generations; role; parent_id (blank for parents); birth_year.
- `data/raw/income.csv`: 168,000 person-years (ages 25–45 inclusive); unique person_id/year; positive real_income in constant purchasing-power dollars. Parent cohort 1940 and child cohort 1965 imply income observations 1965–2010. These dates and amounts are fictional.
- `data/raw/truth.csv`: latent permanent log incomes used only for the oracle and benchmark, never ordinary regressions.
- `data/raw/simulation.json`: seed, units, exact equations and assumptions. These are author-created data, not a third-party dataset.
- `results/`: matched pairs, IGE estimates and percentile intervals, age profiles, integrity checks, SHA256 hashes, environment.
- `figures/`: two complementary vector graphics, generated directly from the calculated estimates.

The saved snapshots are reused on every ordinary run. `python scripts/analysis.py --regenerate` intentionally rebuilds them using seed 640006 and then reruns everything. Preserve all four raw files in Git. `--regenerate` is appropriate only for the synthetic teaching panel, not for replacing real observations.

## Statistical design and interpretation

4,000 independent families, one linked parent and one adult child each; no siblings, weights, zero/negative incomes, selection, attrition, or missing years. The parent is 25 years older. Permanent log parent income is normal with mean 10.7 and SD .6; child permanent log income is 10.7 + .4*(parent-10.7) + independent normal SD .5. Hence the population permanent-income IGE is exactly .4. Annual log income has age mean 10.7+.02*(age-35), permanent-income loading min(1,.5+.05*(age-25)), and independent normal shock SD .45. Loading assumptions explicitly build a life-cycle measurement problem into both generations; the example demonstrates a mechanism rather than discovers an empirical regularity.

All ordinary specifications use the same 4,000 pairs. Income levels are averaged BEFORE taking logs. Parent/child single-year comparison uses ages 35/35 or 35/25; averages use parent 35–39 and child 35–39 or 25–29. The age-profile figure fixes parent 35–39 and varies child single ages 25–45 or centered windows 25–29 through 41–45. Midcareer averaging reduces transitory noise; early averaging does not remove systematically different early earnings loadings. Parental measurement error remains even after averaging. The simulated oracle sample slope can differ from .4 due to finite-sample variability.

Percentile 95% intervals use 400 resamples of whole families, seed 640007. They quantify finite-sample uncertainty under this independent-family design, not life-cycle bias. Real siblings require clustering at the shared parent/family level; real panels need defensible linkage, deflation, harmonized income concepts, zero-income policy, age restrictions, attrition checks and possibly survey weights. Do not claim causal transmission or national mobility from this exercise.

## Submission

Article: https://zhenxin-li.github.io/Zhenxin-Li-website/blog/posts/blog6/

Repository: https://github.com/Zhenxin-Li/Zhenxin-Li-website

Submit the article, not the `blog/` listing. Local rendering does not publish. Before submission, commit/push source, README, four raw snapshots, scripts, results and figures; check `git status --short --untracked-files=all -- blog/posts/blog6` and confirm no necessary files are ignored. After publishing, open the exact article URL and verify the new title, both figures, code links and README.

## Sources

- Author-generated simulation, equations above; no real respondents.
- Python Software Foundation: https://docs.python.org/3/library/sqlite3.html
- Haider and Solon (2006), Life-Cycle Variation in the Association between Current and Lifetime Earnings: https://www.nber.org/papers/w11943 . Cited for conceptual background; this script does not replicate their empirical data or results.

## Verification

Run python scripts/verify_sql.py for an adversarial SQL fixture (split households, incorrect origin-family link, missing year, duplicate record, correct aggregation). Six full-panel checks are saved in results/validation.csv. Tested with Python 3.12.14, numpy 2.3.5, SQLite 3.53.1. Repeated normal runs must leave results and raw-file checksums unchanged.

