# Blog 1: What is one more dollar worth?

This article answers a specific conceptual puzzle: why does the multiplier introduced to enforce a constraint predict the gain from relaxing it, without separately solving every adjustment? A log-utility example distinguishes a marginal prediction from a finite change.

## Reproduce

Install R and Quarto, then install R packages `knitr` and `rmarkdown` if absent. No other packages, empirical datasets, downloads, credentials, or Python are required.

From the website repository root:

```sh
quarto render blog/posts/blog1/index.qmd
```

This executes only Blog1 analysis; Quarto may also refresh its parent listing. Website output is `docs/blog/posts/blog1/index.html`. A standalone copy outside the website project renders to `blog/posts/blog1/index.html`. Do not confuse source-adjacent HTML with the website's `docs` publication output.

## Organization

- `index.qmd`: explanatory article; sources the analysis with portable paths and inserts calculated finite-change values into the prose.
- `scripts/analysis.R`: base-R analytical example, numerical verification and two complementary plots.
- `figures/budget_tangency.png`: feasible set, optimal baskets and utility-curve tangencies.
- `figures/marginal_vs_finite.png`: exact gain versus the initial multiplier's local linear prediction.
- `results/optimal_bundles.csv`: budgets, optimal quantities, values and multipliers.
- `results/finite_changes.csv`: exact and predicted gains for additional budgets .01, 1 and 10.
- `results/validation.csv`: numerical optimizer versus analytic optimum, budget exhaustion, finite-difference derivative and tangent comparison.
- `results/sessionInfo.txt`: actual R environment.

No raw-data folder is needed: every number is derived from the explicitly stated hypothetical model, not a population dataset. Preserve the script, figures, results and README in Git. The original illustrative PNG is not used by the revised article.

## Model and limits

Natural logs, positive divisible quantities, unit prices, budget I>0; utility log(x)+log(y). Monotonicity exhausts the budget; strict concavity gives a unique global optimum x=y=I/2. With L=U+lambda*(I-x-y), lambda=2/I=V'(I). For a finite expansion d, the exact gain is 2*log((I+d)/I); lambda(I)*d is only its first-order approximation. Utility is ordinal: positive rescaling changes lambda but not optimal choices. This utility multiplier is not a dollar willingness-to-pay measure, a market price or an interpersonal welfare scale. Binding alone does not establish a strictly positive marginal value in arbitrary problems.

The old sqrt(x*y) example had a value function linear in budget at unit prices, making its “approximation” exact. The new log example deliberately reveals the local character of the shadow-value prediction.

## References and submission

Conceptual background: Jonathan Levin and Paul Milgrom, Consumer Theory (2004), https://web.stanford.edu/~jdlevin/Econ%20202/Consumer%20Theory.pdf . Algebra and numerical illustration in this post are derived explicitly.

Published article path: https://zhenxin-li.github.io/Zhenxin-Li-website/blog/posts/blog1/

Repository: https://github.com/Zhenxin-Li/Zhenxin-Li-website

Local rendering is not publishing. Commit/push the changed `docs` page, both images and supporting resources as well as the source; then verify the exact article URL displays the new title. Submit the article URL rather than the blog listing. Blog1's assignment does not require a GitHub link, but this repository provides replication materials anyway.
