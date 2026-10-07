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
│       
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