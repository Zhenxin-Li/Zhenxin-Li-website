install.packages(c("rvest","dplyr","ggplot2","tidyr","stringr","chromote","purrr"))
# scripts/scrape_finviz.R
# Blog Post2-B: Finviz small-midcap scraping (rvest only)
# v=141 = Ownership view, contains Institutional Own & Short Float
# Blog2: rvest scrape finviz ownership view v=131
# scripts/scrape_finviz.R
# blog/posts/blog2/scripts/scrape_finviz.R
library(rvest)
library(dplyr)
library(purrr)

# -------------------------- 配置项 --------------------------
#page_sequence <- 1:2      # 抓取前2页，每页20支股票
#sleep_seconds <- 4        # 伦理爬虫，请求间隔
# 本地增强版，仅自己测试用，不要作为仓库默认配置
page_sequence <- 1:10
sleep_seconds <-7

if (!dir.exists("data/raw")) dir.create("data/raw", recursive = TRUE)

# -------------------------- 通用抓取函数 --------------------------
scrape_finviz_view <- function(view_code){
  base_url <- paste0("https://finviz.com/screener.ashx?v=", view_code)
  out_df <- tibble()
  
  for(page_num in page_sequence){
    offset <- (page_num - 1L)*20L
    full_url <- paste0(base_url, "&r=", offset)
    message("\nScraping view v=", view_code, " Page ", page_num, " | ", full_url)
    
    page <- read_html(full_url)
    stock_rows <- html_elements(page, css = "tr.styled-row")
    message("Stock rows found: ", length(stock_rows))
    
    page_df <- tibble()
    for(row_node in stock_rows){
      # 提取股票代码ticker
      ticker_link <- html_element(row_node, "a[href*='stock?t=']")
      ticker <- if(!is.na(ticker_link)) html_text2(ticker_link) else NA_character_
      
      td_nodes <- html_elements(row_node, "td")
      cell_values <- map_chr(td_nodes, function(td){
        val <- html_attr(td, "data-boxover-value")
        if(is.na(val)) val <- html_text2(td)
        val
      })
      page_df <- bind_rows(page_df, tibble(ticker = ticker, cells = list(cell_values)))
    }
    out_df <- bind_rows(out_df, page_df)
    Sys.sleep(sleep_seconds)
  }
  return(out_df)
}

# -------------------------- 抓取4套视图数据 --------------------------
# ⚠️ 重要：cell_values[1] = 页面序号No.，真实业务字段全部从【下标2】开始！
# v=111 Overview：Ticker,Company,Sector,Industry,Country,MarketCap,P/E
df_v111_raw <- scrape_finviz_view("111")
df_v111 <- df_v111_raw %>%
  rowwise() %>%
  mutate(
    company_name = cells[3],
    sector       = cells[4],
    industry     = cells[5],
    country      = cells[6],
    market_cap   = cells[7],
    pe           = cells[8]
  ) %>%
  ungroup() %>%
  select(-cells)

# v=121 Valuation：估值指标
df_v121_raw <- scrape_finviz_view("121")
df_v121 <- df_v121_raw %>%
  rowwise() %>%
  mutate(
    market_cap_v = cells[3],
    pe_v         = cells[4],
    forward_pe   = cells[5],
    peg          = cells[6],
    ps           = cells[7],
    pb           = cells[8]
  ) %>%
  ungroup() %>%
  select(-cells)

# v=131 Ownership：机构持仓、空头指标（核心研究变量）
df_v131_raw <- scrape_finviz_view("131")
df_v131 <- df_v131_raw %>%
  rowwise() %>%
  mutate(
    market_cap_o     = cells[3],
    outstanding      = cells[4],
    float            = cells[5],
    insider_own      = cells[6],
    insider_trans    = cells[7],
    inst_own         = cells[8],
    short_float      = cells[9],
    short_ratio      = cells[10]
  ) %>%
  ungroup() %>%
  select(-cells)

# v=161 Financial：财务指标 ROA ROE 利润率
df_v161_raw <- scrape_finviz_view("161")
df_v161 <- df_v161_raw %>%
  rowwise() %>%
  mutate(
    market_cap_f = cells[3],
    roa          = cells[5],
    roe          = cells[6],
    profit_m     = cells[14]
  ) %>%
  ungroup() %>%
  select(-cells)

# -------------------------- 多表按ticker合并 --------------------------
combined_all <- df_v111 %>%
  inner_join(df_v121, by = "ticker") %>%
  inner_join(df_v131, by = "ticker") %>%
  inner_join(df_v161, by = "ticker")

write.csv(combined_all, "data/raw/finviz_all_views_raw.csv", row.names = FALSE, na = "")
message("\n✅ Finished scraping. Total merged rows = ", nrow(combined_all))
message("=== preview ===")
print(head(combined_all, 3))

