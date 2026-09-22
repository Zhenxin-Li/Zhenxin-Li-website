# blog/posts/blog2/scripts/analysis_plot.R
library(dplyr)
library(ggplot2)

# 目标文件夹：相对于项目根目录
fig_dir <- file.path("blog", "posts", "blog2", "figures")
if (!dir.exists(fig_dir)) dir.create(fig_dir, recursive = TRUE)
message("目标输出文件夹完整路径：", normalizePath(fig_dir))

# 读取数据（项目根目录下data文件夹）
df <- read.csv(file.path("data","processed","finviz_clean_all.csv"), stringsAsFactors = FALSE)

# 行业聚合统计，至少2家公司才保留该行业
sector_summary <- df |>
  group_by(sector) |>
  summarise(
    n_firms           = n(),
    med_pe            = median(pe_num, na.rm = TRUE),
    med_inst_own      = median(institutional_ownership_pct, na.rm = TRUE),
    med_short_float   = median(short_float_pct, na.rm = TRUE),
    med_roe           = median(roe_num, na.rm = TRUE),
    med_profit_margin = median(profit_margin_pct, na.rm = TRUE),
    .groups = "drop"
  ) |>
  filter(n_firms >= 2)

pe_med       <- median(sector_summary$med_pe, na.rm = TRUE)
inst_own_med <- median(sector_summary$med_inst_own, na.rm = TRUE)

sector_summary <- sector_summary |>
  mutate(
    group = case_when(
      med_pe       <= pe_med & med_inst_own >= inst_own_med ~ "Low‑PE / High‑Inst (Approved Value)",
      med_pe       <= pe_med & med_inst_own <  inst_own_med ~ "Low‑PE / Low‑Inst (Value‑Trap Risk)",
      med_pe       >  pe_med & med_inst_own >= inst_own_med ~ "High‑PE / High‑Inst (Growth Quality)",
      TRUE                                                 ~ "High‑PE / Low‑Inst (Other)"
    )
  )

message("==== Sector Aggregate Summary ====")
print(sector_summary)

# Figure1
fig1 <- ggplot(sector_summary, aes(x = med_pe, y = med_inst_own, color = group)) +
  geom_point(size = 3, alpha = 0.8) +
  geom_text(aes(label = sector), hjust = -0.12, size = 3, show.legend = FALSE) +
  geom_vline(xintercept = pe_med, linetype = "dashed", color = "grey40") +
  geom_hline(yintercept = inst_own_med, linetype = "dashed", color = "grey40") +
  labs(
    title    = "Small‑MidCap Sectors: Median P/E vs Median Institutional Ownership",
    subtitle = "Dashed lines = cross‑sector median",
    x        = "Sector Median P/E Ratio",
    y        = "Sector Median Institutional Ownership (%)",
    color    = "Quadrant Category",
    caption  = "Source: rvest scrape Finviz screener 2026"
  ) + theme_bw()

ggsave(file.path(fig_dir, "fig1_pe_vs_institutional.png"), fig1, width = 11, height =7, dpi=300)

# Figure2
low_pe_sectors <- sector_summary |> filter(med_pe <= pe_med)
fig2 <- ggplot(low_pe_sectors, aes(x = reorder(sector, med_short_float), y = med_short_float, fill = group)) +
  geom_col() + coord_flip() +
  labs(
    title = "Median Short‑Float % for Low‑PE Small‑MidCap Sectors",
    subtitle = "Higher short float signals potential value‑trap risk",
    x = NULL, y = "Median Short Float (%)", fill = "Quadrant",
    caption = "Source: rvest scrape Finviz screener 2026"
  ) + theme_bw()

ggsave(file.path(fig_dir, "fig2_short_float_by_sector.png"), fig2, width=10, height=6, dpi=300)

# Figure3
df <- df |>
  mutate(
    pe_bin = cut(pe_num, breaks = c(0,10,20,40,200), labels = c("0‑10","10‑20","20‑40","40+")),
    inst_group = if_else(
      institutional_ownership_pct >= median(df$institutional_ownership_pct, na.rm = TRUE),
      "High Institutional Ownership", "Low Institutional Ownership"
    )
  )

fig3 <- ggplot(df, aes(x = pe_bin, fill = inst_group)) +
  geom_bar(position = "stack") +
  labs(
    title = "Firm Count: PE Bins vs Institutional Ownership (Small‑MidCap)",
    x = "P/E Ratio Bin", y = "Number of Firms", fill = NULL,
    caption = "Source: rvest scrape Finviz screener 2026"
  ) + theme_bw()

ggsave(file.path(fig_dir, "fig3_pe_bin_institutional.png"), fig3, width=10, height=6, dpi=300)

message("✅ All figures saved to: ", normalizePath(fig_dir))
