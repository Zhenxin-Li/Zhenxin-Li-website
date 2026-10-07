---
draft: true
---

# Zhenxin Li's Personal Website - blog 4
 
 This is introduction about how to reproduce blog 4.
 
## Data Sources and Reproducibility

All data are obtained programmatically in the R code above.

### Primary data sources

- **U.S. Bureau of Labor Statistics, Consumer Price Index:** Food at Home, All Items, and selected grocery categories.
- **Federal Reserve Bank of St. Louis FRED:** Programmatic access to the BLS CPI series.
- **U.S. Census Bureau:** Median household income, distributed through FRED.

The CPI data are monthly, so annual averages are calculated in R before being compared with annual household income. The analysis uses 2015–2025 because 2025 is the latest complete year available for the annual household-income series.

### Replication

From the project root, the blog can be rendered with:

```bash
quarto render blog/posts/blog4/index.qmd
```

The code automatically downloads the required FRED series, transforms the data, creates the seven figures, and saves the figures in the Blog 4 directory.

The resulting folder structure is:

```text
blog/
└── posts/
    └── blog4/
        ├── index.qmd
        ├── README_blog4.md
        ├── data/
        └── figures/
            ├── figure1_food_vs_all_items.png
            ├── figure2_monthly_food_inflation.png
            ├── figure3_food_price_gap.png
            ├── figure4_category_price_changes.png
            ├── figure5_category_price_heatmap.png
            ├── figure6_income_vs_food_prices.png
            └── figure7_food_purchasing_power.png
```

## Conclusion

The broader economic lesson is that **inflation, relative prices, and purchasing power are related but distinct concepts**. Understanding their relationship helps connect national economic statistics to the prices and incomes that households encounter in everyday economic decisions.

## Author

**Zhenxin Li**

ECON 6400
