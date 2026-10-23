# Zhenxin Li's Personal Website


Welcome to my personal website repository. This project contains the source files for my academic and personal website, including information about me, my resume, blog posts, data analysis, figures, and other supporting materials.

The website is built using [Quarto](https://quarto.org/) and is maintained using Git and GitHub.

## About This Website

This website serves as a personal academic portfolio and provides information about my background, interests, and coursework. It also contains a collection of blog posts that document data analysis, visualization, and research-related projects.

The website includes:

- Personal and academic information
- Biography
- Resume/CV
- Blog posts

## Repository Structure

The main directory structure is organized as follows:

```text
mywebsite/
│
├── README.md
├── _quarto.yml
├── index.qmd
├── about.qmd
├── bio.qmd
├── resume.qmd
├── styles.css
│
├── blog/
│   ├── index.qmd
│   └── posts/
│       ├── blog1/
│       │   ├── index.qmd
│       │   └── figure1.png
│       │ 
│       ├── blog2/
│       │   ├── index.qmd
│       │   ├── scripts/
│       │   └── figures/
│       │ 
│       ├── blog3/
│       │   ├── index.qmd
│       │   ├── scripts/
│       │   ├── results/
│       │   └── figures/
│       │ 
│       ├── blog4/
│       │   ├── blog4_index.qmd
│       │   ├── data/
│       │   └── figures/
│       │ 
│       ├── blog5/
│       │   ├── index.qmd
│       │   ├── data/
│       │   └── figures/
│       │  
│       ├── blog6/
│       │   ├── index.qmd
│       │   ├── README.md
│       │   ├── data/
│       │   └── scripts/
├── data/
├── docs/
├── files/
└── images/
```

## Main Files

### `_quarto.yml`

This file contains the configuration for the Quarto website, including website navigation, theme, output settings, and other site-wide options.

### `index.qmd`

This is the main homepage of the website.

### `about.qmd`

This page provides additional information about me and my background.

### `bio.qmd`

This page contains my biography and academic background.

### `resume.qmd`

This page contains my resume/CV and related professional information.

### `styles.css`

This file contains custom CSS used to control the appearance and styling of the website.

### `README.md`

This file provides an overview of the repository, its organization, and instructions for working with the project.

## Blog Posts

The blog section is organized under:

```text
blog/posts/
```

The current repository contains the following blog directories:

```text
blog/
└── posts/
    ├── blog1/
    ├── blog2/
    ├── blog3/
    ├── post1/
    └── post2/
```

Each blog post is organized in its own directory. A typical blog post may contain an `index.qmd` file along with figures, data, and other supporting materials.

For example:

```text
blog/posts/blog3/
├── index.qmd
├── README_blog.md
├── scripts/
├── results/
└── figures/
```

The `index.qmd` file contains the main content and analysis for the corresponding blog post, while the `figures/` directory contains figures used in the post.

## Data and Supporting Materials

The repository contains several directories for organizing data and other resources.

### `data/`

This directory contains data files used for analysis and other project-related work.

### `figures/`

This directory contains figures and visualizations used by the website and analysis projects.

### `images/`

This directory contains images and other visual assets used throughout the website.

### `files/`

This directory contains additional supporting files used by the website or individual projects.

### `docs/`

This directory contains rendered website files and other generated documentation when applicable.

## Software and Tools

This project uses the following tools and technologies:

- **Quarto** — for creating and rendering the website
- **R** — for data analysis and statistical computing
- **Markdown / Quarto Markdown** — for writing website and blog content
- **CSS** — for custom website styling
- **Git** — for version control
- **GitHub** — for repository hosting and version control

## Rendering the Website

To render the website locally, first open a terminal in the project root directory:

```text
D:/6400/Github/mywebsite/
```

Then run:

```bash
quarto render
```

This command renders the Quarto website using the configuration specified in `_quarto.yml`.

The website can also be previewed during development with:

```bash
quarto preview
```

The preview command starts a local preview of the website and automatically updates the page when source files are changed.

## Working with Individual Blog Posts

Individual blog posts can be rendered or previewed while working on them.

For example, the Blog 3 source file is located at:

```text
blog/posts/blog3/index.qmd
```

A blog post should use relative paths when referring to figures and other files whenever possible.

For example:

```markdown
![Figure 1](figures/figure1_overall_trend.png)
```

Using relative paths makes the project more portable and helps ensure that the website can be rendered on different computers.

## Reproducibility

The project is organized so that the website and its analytical content can be reproduced from the source files.

When working with data and figures:

1. Data files should be stored in the appropriate project directory.
2. Analysis code should be included in the relevant `.qmd` files or supporting scripts.
3. Figures generated by the analysis should be stored in the appropriate `figures/` directory.
4. Relative file paths should be used instead of computer-specific absolute paths whenever possible.
5. The website should be rendered from the project root directory.

For example, avoid using computer-specific paths such as:

```text
D:/6400/Github/mywebsite/...
```

and instead use project-relative paths such as:

```text
figures/figure1_overall_trend.png
```

This allows the project to be used on different computers without changing file paths.

## Version Control

Git is used to track changes to the project.

A typical workflow is:

```bash
git status
```

to check the current status of the repository.

After making changes:

```bash
git add .
git commit -m "Update website"
git push
```

These commands add the changes, create a commit, and push the changes to the GitHub repository.

## Project Organization

The repository separates website content, blog posts, data, figures, and other supporting files into different directories. This organization makes the project easier to maintain and helps keep source files separate from generated or supporting materials.

The general organization is:

```text
Website
│
├── Main pages
│   ├── index.qmd
│   ├── about.qmd
│   ├── bio.qmd
│   └── resume.qmd
│
├── Blog
│   └── posts/
│       ├── blog1/
│       ├── blog2/
│       ├── blog3/
│       ├── post1/
│       └── post2/
│
├── Data
│   └── data/
│
├── Figures
│   └── figures/
│
├── Images
│   └── images/
│
└── Configuration
    ├── _quarto.yml
    └── styles.css
```

## Author

**Zhenxin Li**

ECON 6400

## Acknowledgments

This website and its associated blog posts were developed as part of my academic coursework and personal projects.

The repository will be updated as new blog posts, analyses, and website content are added.

## Blog 4 replication

Blog 4 compares grocery prices, overall prices, and nominal median household income in 2015-2024 and 2020-2024. [Detailed replication instructions](blog/posts/blog4/README.md) cover the saved snapshots, official fallback sources, transformations, and checks.

Install R and Quarto, then install the R packages:

```r
install.packages(c("dplyr", "tidyr", "ggplot2", "readr", "scales", "knitr", "rmarkdown", "jsonlite", "readxl"))
```

From the repository root:

```sh
quarto render blog/posts/blog4/blog4_index.qmd
```

The eight real input CSVs are saved under `blog/posts/blog4/data/raw/`; rendering reuses them without downloading again. If snapshots are absent, the code tries FRED, then the official BLS API and Census H-5 workbook. Actual sources and original publisher responses are preserved. Derived tables and R session information go into `results/`, and four generated PNGs into `figures/`. Keep data, source code, and the README in the repository. Submit both the published article URL and repository URL.

## Blog 5 replication

Blog 5 asks one question: do counties with above-average manufacturing or professional/business-services employment shares also have higher resident household incomes? The two figures locate industrial specialization and directly compare grouped income distributions. The post does not analyze employment growth, unemployment, population, or education, and makes no causal claims.

See the [Blog 5 README](blog/posts/blog5/README.md) for definitions, dependencies, data coverage, sensitivity checks, and replication. From the repository root:

```sh
quarto render blog/posts/blog5/index.qmd
```

Five real QCEW/ACS/boundary snapshots and provenance are saved in `blog/posts/blog5/data/raw/`; rendering reuses them without network access or an API key. Include that directory, the QMD, README, scripts, figures, and results in Git. The former `.gitignore` exclusion of this data directory has been removed. Check the file list before committing and pushing; local existence does not mean files are already on GitHub.

The article's published path is `blog/posts/blog5/` or its `index.html`, **not** the `blog/` listing. Verify the deployed title **Industry Specialization and County Household Income** and submit the article URL plus the repository URL.


## Blog 6 replication

[Matching Fathers and Sons in PSID with Python and SQL](https://zhenxin-li.github.io/Zhenxin-Li-website/blog/posts/blog6/) is a tutorial on linking recorded parents and children using two-part personal identifiers, matching annual family income, and applying SQL selection, joins, grouping, and aggregation within Python. It asks whether measuring the same sons’ incomes earlier gives a lower intergenerational income elasticity (IGE).

The analysis uses real PSID records and compares single-year and three-year-average family incomes for the same 191 sons and 170 fathers. Later measurement and averaging give higher point estimates, but both paired difference intervals include zero. The post distinguishes the illustration of life-cycle bias from what this selected, unweighted sample can establish; it does not identify a causal age effect or a national long-run IGE.

### Files

```text
blog/posts/blog6/
├── index.qmd                 # Tutorial and generated results table
├── README.md                 # File list, variable definitions, and replication
├── requirements.txt          # Python dependencies
├── scripts/                  # PSID preparation, SQL, analysis, walkthrough
└── data/
    ├── aggregate/            # Saved results, CPI, provenance, and checks
    ├── raw/                  # Local registered PSID downloads; not published
    └── private/              # Local SQLite database; not published
```

### Render the article

Install Quarto, R, and the R packages `knitr` and `rmarkdown`. From the repository root, render only Blog 6:

```sh
quarto render blog/posts/blog6/index.qmd
```

Rendering reads saved aggregate results and requires no PSID login, data download, or Python execution. Website output is written to `docs/blog/posts/blog6/`.

### Reproduce the analysis

Follow the [Blog 6 replication guide](blog/posts/blog6/README.md) for the exact PSID downloads and directory layout. With Python 3.10+ installed, run from `blog/posts/blog6/`:

```sh
python -m pip install -r requirements.txt
python scripts/prepare_psid_linkage.py --raw data/raw --db data/private/psid.sqlite --out data/aggregate
python scripts/psid_analysis.py --raw data/raw --db data/private/psid.sqlite --out data/aggregate --cpi data/aggregate/cpi_annual.csv
python scripts/walkthrough.py
```

The preparation command requires a new database; skip it when reusing an existing prepared database. The analysis saves aggregate estimates, bootstrap intervals, sample counts, and validation checks. The walkthrough runs the article’s Python blocks in order.

Keep source code, aggregate results, the post README, and updated publication files in the repository. Keep registered PSID microdata and the SQLite database local and excluded from Git. Submit the article URL above, rather than the blog listing, together with the repository URL.

## Blog 1 replication

Blog 1 explains why a Lagrange multiplier predicts the marginal gain from relaxing a budget, using a hypothetical log-utility example. See [replication instructions](blog/posts/blog1/README.md). Run quarto render blog/posts/blog1/index.qmd from the repository root. The base-R script generates both figures, result tables and numerical checks without data downloads. Include the updated docs publication files when committing; the article is at blog/posts/blog1/, not the blog listing.


## Blog 2 replication

Blog 2 reanalyses the preserved original Finviz rvest CSV to ask whether low-P/E companies consistently have high institutional ownership. See [the post README](blog/posts/blog2/README.md). Render with quarto render blog/posts/blog2/index.qmd from the repository root. The saved source data support offline analysis; code, sample-flow audit, integrity checks, sensitivity results and one generated company-level figure are included. The original collector is retained as inert archival text. No new screener requests are made. Original HTML/capture logs were not preserved, so historical reacquisition and permissions cannot be retrospectively verified. Include updated docs publication files when committing.


