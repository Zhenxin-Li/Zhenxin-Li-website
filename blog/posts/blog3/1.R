#==============================================================================
# Blog3 Script: Education & Labor Force Participation
# 不需要薪资变量，仅使用 EDUC, EMPSTAT, YEAR, WTFINL
#==============================================================================
required_packages <- c("tidyverse","scales","here","ipumsr")
new_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(new_packages)>0){
  install.packages(new_packages)
}

library(tidyverse)
library(scales)
library(here)
library(ipumsr)

# 创建图片文件夹
fig_dir <- here("blog","posts","blog3","figures")
if(!dir.exists(fig_dir)) dir.create(fig_dir)

# 读取IPUMS数据
ddi_file <- here("blog","posts","blog3","cps_00002.xml")
ddi <- read_ipums_ddi(ddi_file)
raw_cps <- read_ipums_micro(ddi)

#===================== 数据清洗 =====================
cps_clean <- raw_cps |>
  mutate(
    EMPSTAT_NUM = as.integer(EMPSTAT),
    # 定义是否属于劳动力：就业(10,11) OR 失业求职(20,21)
    in_labor_force = case_when(
      EMPSTAT_NUM %in% c(10,11,20,21) ~ 1,
      EMPSTAT_NUM %in% c(30,31) ~ 0,
      TRUE ~ NA_real_
    )
  ) |>
  filter(!is.na(in_labor_force)) |>
  filter(!is.na(WTFINL)) |> # 剔除权重缺失
  mutate(
    # 教育分组（标准4组）
    edu_group = case_when(
      EDUC < 6 ~ "Less than High School",
      EDUC >= 6  & EDUC < 10 ~ "High School Graduate",
      EDUC >= 10 & EDUC < 14 ~ "Some College",
      EDUC >= 14 ~ "Bachelor’s or Higher"
    ),
    edu_group = factor(
      edu_group,
      levels = c("Less than High School",
                 "High School Graduate",
                 "Some College",
                 "Bachelor’s or Higher")
    )
  )

# 查看样本年份
table(cps_clean$YEAR)

#===================== 加权计算劳动力参与率 =====================
# 图2：整体劳动力参与率逐年趋势
lfp_total <- cps_clean |>
  group_by(YEAR) |>
  summarise(
    lfp_rate = sum(in_labor_force * WTFINL, na.rm = TRUE) / sum(WTFINL, na.rm = TRUE)
  )

# 图1：分教育组LFP时间趋势
lfp_edu_trend <- cps_clean |>
  group_by(YEAR, edu_group) |>
  summarise(
    lfp_rate = sum(in_labor_force * WTFINL, na.rm = TRUE) / sum(WTFINL, na.rm = TRUE),
    .groups = "drop"
  )

# 图3：最新年份分教育LFP柱状图
latest_year <- max(cps_clean$YEAR)
lfp_latest <- cps_clean |>
  filter(YEAR == latest_year) |>
  group_by(edu_group) |>
  summarise(
    lfp_rate = sum(in_labor_force * WTFINL, na.rm = TRUE) / sum(WTFINL, na.rm = TRUE)
  )

#===================== 绘图 =====================
## 图1：分教育水平劳动力参与率趋势
p1 <- ggplot(lfp_edu_trend, aes(x = YEAR, y = lfp_rate, color = edu_group)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 1.8) +
  scale_y_continuous(labels = percent_format(), limits = c(0,1)) +
  labs(
    title = "Labor Force Participation Rate by Educational Attainment",
    x = "Survey Year",
    y = "Labor Force Participation Rate",
    color = "Education Group",
    caption = "Source: IPUMS-CPS, weighted by WTFINL sampling weight"
  ) +
  theme_minimal()

ggsave(file.path(fig_dir,"fig1_lfp_by_edu_trend.png"), p1, width=10, height=5.5, dpi=300)

## 图2：全美整体劳动力参与率
p2 <- ggplot(lfp_total, aes(x = YEAR, y = lfp_rate)) +
  geom_line(linewidth = 1.2, color = "#2c3e50") +
  geom_point(size = 2) +
  scale_y_continuous(labels = percent_format(), limits = c(0,1)) +
  labs(
    title = "U.S. Aggregate Labor Force Participation Rate (2022–2026)",
    subtitle = "Civilian non-institutional population, population-weighted",
    x = "Survey Year",
    y = "Labor Force Participation Rate",
    caption = "Source: IPUMS-CPS, weighted by WTFINL sampling weight"
  ) + theme_minimal()

ggsave(file.path(fig_dir,"fig2_total_lfp_trend.png"), p2, width=9, height=5, dpi=300)

## 图3：最新年份各教育水平LFP柱状图
p3 <- ggplot(lfp_latest, aes(x = edu_group, y = lfp_rate, fill = edu_group)) +
  geom_col() +
  scale_y_continuous(labels = percent_format(), limits = c(0,1)) +
  labs(
    title = paste0("Labor Force Participation by Education (",latest_year,")"),
    x = "Educational Attainment",
    y = "Labor Force Participation Rate",
    caption = "Source: IPUMS-CPS, weighted by WTFINL sampling weight"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave(file.path(fig_dir,"fig3_lfp_latest_year.png"), p3, width=8, height=5, dpi=300)

# 打印图
print(p1)
print(p2)
print(p3)

cat("\n===== Analysis Complete. 3 figures saved =====\n")
