# blog/posts/blog2/scripts/clean_finviz_all.R
library(dplyr)
library(stringr)

if (!dir.exists("data/processed")) dir.create("data/processed", recursive = TRUE)

raw_df <- read.csv("data/raw/finviz_all_views_raw.csv", stringsAsFactors = FALSE)

clean_df <- raw_df |>
  filter(!is.na(ticker), ticker != "") |>
  filter(pe != "", inst_own != "", short_float != "", market_cap != "") |>
  mutate(
    pe_num                     = as.numeric(str_remove(pe, "x")),
    institutional_ownership_pct = as.numeric(str_remove(inst_own, "%")),
    short_float_pct            = as.numeric(str_remove(short_float, "%")),
    roa_num                    = as.numeric(str_remove(roa, "%")),
    roe_num                    = as.numeric(str_remove(roe, "%")),
    profit_margin_pct          = as.numeric(str_remove(profit_m, "%"))
  ) |>
  filter(pe_num > 0, pe_num <= 200) |>
  mutate(
    market_cap_value = case_when(
      str_ends(market_cap, "B") ~ as.numeric(str_remove(market_cap, "B")) * 1e9,
      str_ends(market_cap, "M") ~ as.numeric(str_remove(market_cap, "M")) * 1e6,
      TRUE ~ NA_real_
    ),
    cap_group = if_else(market_cap_value < 10e9, "Small‑Mid Cap", "Large Cap")
  ) |>
  filter(cap_group == "Small‑Mid Cap") |>
  mutate(sector = str_squish(sector)) |>
  select(
    ticker, company_name, sector, industry, country,
    market_cap, market_cap_value, cap_group,
    pe_num, peg, ps, pb,
    institutional_ownership_pct, short_float_pct,
    roa_num, roe_num, profit_margin_pct
  )

write.csv(clean_df, "data/processed/finviz_clean_all.csv", row.names = FALSE, na = "")
message("✅ Clean dataset saved. Rows after clean: ", nrow(clean_df))
print(head(clean_df))
