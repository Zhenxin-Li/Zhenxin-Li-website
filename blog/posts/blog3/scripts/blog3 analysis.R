# ============================================================
# Blog 3
# The Evolution of Working Hours in the United States, 2015-2025
#
# Data: IPUMS CPS March ASEC
# Main variable: UHRSWORK1
# Weight: ASECWT
#
# Research Question:
# How did usual weekly working hours change among U.S. workers
# between 2015 and 2025, and how did these changes differ
# across educational attainment groups?
# ============================================================


# ============================================================
# 0. Packages
# ============================================================

required_packages <- c(
  "ipumsr",
  "dplyr",
  "ggplot2",
  "scales",
  "readr",
  "tidyr"
)

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
}

library(ipumsr)
library(dplyr)
library(ggplot2)
library(scales)
library(readr)
library(tidyr)


# ============================================================
# 1. Set working directory
# ============================================================

project_dir <- "D:/6400/Github/mywebsite/blog/posts/blog3"

setwd(project_dir)

dir.create("figures", showWarnings = FALSE)


# ============================================================
# 2. Read IPUMS CPS extract
# ============================================================

ddi_file <- file.path(project_dir, "cps_00002.xml")

ddi <- read_ipums_ddi(ddi_file)

# Variables required for the analysis
required_vars <- c(
  "YEAR",
  "MONTH",
  "EMPSTAT",
  "UHRSWORK1",
  "EDUC",
  "ASECWT"
)

available_variables <- ipums_var_info(ddi)$var_name

missing_vars <- setdiff(required_vars, available_variables)

if (length(missing_vars) > 0) {
  stop(
    paste(
      "The following variables are missing from the IPUMS extract:",
      paste(missing_vars, collapse = ", ")
    )
  )
}


# ============================================================
# 3. Read the microdata
# ============================================================

cps <- read_ipums_micro(
  ddi,
  data_file = file.path(project_dir, "cps_00002.dat"),
  vars = required_vars
)


# ============================================================
# 4. Convert variables to numeric
# ============================================================

cps <- cps %>%
  mutate(
    YEAR_num = as.numeric(YEAR),
    MONTH_num = as.numeric(MONTH),
    EMPSTAT_num = as.numeric(EMPSTAT),
    UHRSWORK1_num = as.numeric(UHRSWORK1),
    EDUC_num = as.numeric(EDUC),
    ASECWT_num = as.numeric(ASECWT)
  )


# ============================================================
# 5. Construct educational attainment groups
# ============================================================
#
# IPUMS recommends using the first two digits of EDUC
# for comparability across time.
#
# Groups:
# 0-6   = Less than High School
# 7     = High School Graduate
# 8-10  = Some College
# 11-12 = Bachelor's or Higher
# ============================================================

cps <- cps %>%
  mutate(
    EDUC2 = floor(EDUC_num / 10),
    
    education_group = case_when(
      EDUC2 >= 0 & EDUC2 <= 6 ~ "Less than High School",
      EDUC2 == 7 ~ "High School Graduate",
      EDUC2 >= 8 & EDUC2 <= 10 ~ "Some College",
      EDUC2 >= 11 & EDUC2 <= 12 ~ "Bachelor's or Higher",
      TRUE ~ NA_character_
    )
  )


# ============================================================
# 6. Construct analysis sample
# ============================================================
#
# We use March ASEC consistently across all years.
#
# EMPSTAT:
# 10 = At work
# 12 = Has job, not at work
#
# UHRSWORK1:
# 0-98 = exact reported usual hours
# 99    = 99 hours or more
# 997   = Hours vary
# 999   = NIU
#
# For the mean-hours analysis:
# keep 0-98 only because 99 represents an open-ended
# category rather than an exact number.
#
# ASECWT is the appropriate person-level weight for ASEC.
# ============================================================

cps_analysis <- cps %>%
  filter(
    YEAR_num >= 2015,
    YEAR_num <= 2025,
    
    # March ASEC
    MONTH_num == 3,
    
    # Employed population
    EMPSTAT_num %in% c(10, 12),
    
    # Exact usual hours for mean calculation
    !is.na(UHRSWORK1_num),
    UHRSWORK1_num >= 0,
    UHRSWORK1_num <= 98,
    
    # ASEC person weight
    !is.na(ASECWT_num),
    ASECWT_num > 0,
    
    # Valid education group
    !is.na(education_group)
  )


# ============================================================
# 7. Basic sample diagnostics
# ============================================================

cat("\n============================================\n")
cat("Sample diagnostics\n")
cat("============================================\n")

cat("\nObservations in analysis sample:\n")
print(nrow(cps_analysis))

cat("\nYears represented:\n")
print(table(cps_analysis$YEAR_num))

cat("\nEducation groups:\n")
print(table(cps_analysis$education_group))


# ============================================================
# 8. Weighted mean helper function
# ============================================================

weighted_mean <- function(x, w) {
  
  valid <- !is.na(x) & !is.na(w) & w > 0
  
  if (sum(valid) == 0) {
    return(NA_real_)
  }
  
  sum(x[valid] * w[valid]) /
    sum(w[valid])
}


# ============================================================
# 9. Overall annual average usual weekly hours
# ============================================================

overall_hours <- cps_analysis %>%
  group_by(YEAR_num) %>%
  summarise(
    avg_hours = weighted_mean(
      UHRSWORK1_num,
      ASECWT_num
    ),
    .groups = "drop"
  )


# ============================================================
# 10. Average hours by educational attainment
# ============================================================

education_hours <- cps_analysis %>%
  group_by(
    YEAR_num,
    education_group
  ) %>%
  summarise(
    avg_hours = weighted_mean(
      UHRSWORK1_num,
      ASECWT_num
    ),
    .groups = "drop"
  )


# ============================================================
# 11. 2015 vs 2025 comparison
# ============================================================

comparison_2015_2025 <- education_hours %>%
  filter(
    YEAR_num %in% c(2015, 2025)
  ) %>%
  mutate(
    year_label = as.character(YEAR_num)
  )


# ============================================================
# 12. Education gap
# ============================================================
#
# Gap =
# Bachelor's or Higher
# minus
# Less than High School
#
# This measures how many more usual weekly hours
# the higher-education group reports relative to
# the lower-education group.
# ============================================================

education_gap <- education_hours %>%
  select(
    YEAR_num,
    education_group,
    avg_hours
  ) %>%
  pivot_wider(
    names_from = education_group,
    values_from = avg_hours
  ) %>%
  mutate(
    education_gap =
      `Bachelor's or Higher` -
      `Less than High School`
  )


# ============================================================
# 13. Year-to-year change in overall hours
# ============================================================

yoy_change <- overall_hours %>%
  arrange(YEAR_num) %>%
  mutate(
    change_hours =
      avg_hours - lag(avg_hours)
  ) %>%
  filter(
    !is.na(change_hours)
  )


# ============================================================
# 14. 40+ hours indicator
# ============================================================
#
# IMPORTANT:
# UHRSWORK1 = 99 means 99 hours or more.
# Therefore, 99 should be included in the 40+ category.
#
# We create a separate dataset for this analysis rather than
# using the mean-hours sample.
# ============================================================

cps_40plus <- cps %>%
  filter(
    YEAR_num >= 2015,
    YEAR_num <= 2025,
    MONTH_num == 3,
    EMPSTAT_num %in% c(10, 12),
    !is.na(UHRSWORK1_num),
    UHRSWORK1_num >= 0,
    UHRSWORK1_num <= 99,
    !is.na(ASECWT_num),
    ASECWT_num > 0,
    !is.na(education_group)
  ) %>%
  mutate(
    hours_40plus =
      UHRSWORK1_num >= 40
  )


# ============================================================
# 15. Weighted share working 40+ hours
# ============================================================

share_40plus <- cps_40plus %>%
  group_by(
    YEAR_num,
    education_group
  ) %>%
  summarise(
    share_40plus =
      weighted_mean(
        as.numeric(hours_40plus),
        ASECWT_num
      ),
    .groups = "drop"
  )


# ============================================================
# 16. 2015 vs 2025 40+ comparison
# ============================================================

share_40plus_comparison <- share_40plus %>%
  filter(
    YEAR_num %in% c(2015, 2025)
  )


# ============================================================
# 17. Print key results
# ============================================================

cat("\n============================================\n")
cat("Overall average usual weekly hours\n")
cat("============================================\n")

print(
  overall_hours %>%
    mutate(
      avg_hours = round(avg_hours, 2)
    )
)


cat("\n============================================\n")
cat("Education-specific average hours\n")
cat("============================================\n")

print(
  education_hours %>%
    mutate(
      avg_hours = round(avg_hours, 2)
    )
)


cat("\n============================================\n")
cat("2015 vs 2025\n")
cat("============================================\n")

print(
  comparison_2015_2025 %>%
    mutate(
      avg_hours = round(avg_hours, 2)
    )
)


cat("\n============================================\n")
cat("Education gap\n")
cat("============================================\n")

print(
  education_gap %>%
    mutate(
      education_gap = round(education_gap, 2)
    )
)


cat("\n============================================\n")
cat("Year-to-year changes\n")
cat("============================================\n")

print(
  yoy_change %>%
    mutate(
      change_hours = round(change_hours, 2)
    )
)


cat("\n============================================\n")
cat("Share working 40+ hours\n")
cat("============================================\n")

print(
  share_40plus_comparison %>%
    mutate(
      share_40plus = percent(
        share_40plus,
        accuracy = 0.1
      )
    )
)


# ============================================================
# 18. Color palettes
# ============================================================

education_colors <- c(
  "Bachelor's or Higher" = "#0072B2",
  "High School Graduate" = "#E69F00",
  "Some College" = "#009E73",
  "Less than High School" = "#CC79A7"
)

year_colors <- c(
  "2015" = "#7F8C8D",
  "2025" = "#D55E00"
)


# ============================================================
# 19. Common graph theme
# ============================================================

blog_theme <- theme_minimal(
  base_size = 14
) +
  theme(
    plot.title = element_text(
      size = 20,
      face = "bold",
      color = "#222222",
      margin = margin(
        b = 6
      )
    ),
    
    plot.subtitle = element_text(
      size = 13,
      color = "#555555",
      margin = margin(
        b = 14
      )
    ),
    
    axis.title = element_text(
      size = 14,
      face = "bold",
      color = "#333333"
    ),
    
    axis.text = element_text(
      size = 12,
      color = "#444444"
    ),
    
    legend.title = element_text(
      size = 12,
      face = "bold"
    ),
    
    legend.text = element_text(
      size = 11
    ),
    
    legend.position = "bottom",
    
    panel.grid.major = element_line(
      color = "#E5E7EB",
      linewidth = 0.6
    ),
    
    panel.grid.minor = element_line(
      color = "#F1F3F5",
      linewidth = 0.35
    ),
    
    plot.margin = margin(
      15, 20, 15, 15
    )
  )


# ============================================================
# FIGURE 1
# Overall trend
# ============================================================

fig1 <- ggplot(
  overall_hours,
  aes(
    x = YEAR_num,
    y = avg_hours
  )
) +
  
  geom_line(
    linewidth = 1.4,
    color = "#0072B2"
  ) +
  
  geom_point(
    size = 3.5,
    color = "#0072B2"
  ) +
  
  geom_point(
    data = overall_hours %>%
      filter(YEAR_num %in% c(2015, 2025)),
    size = 4.5,
    color = "#D55E00"
  ) +
  
  geom_text(
    data = overall_hours %>%
      filter(YEAR_num %in% c(2015, 2025)),
    aes(
      label = sprintf(
        "%.1f",
        avg_hours
      )
    ),
    vjust = -1.0,
    size = 4,
    fontface = "bold",
    color = "#333333"
  ) +
  
  scale_x_continuous(
    breaks = 2015:2025
  ) +
  
  scale_y_continuous(
    labels = function(x) {
      sprintf(
        "%.1f",
        x
      )
    },
    expand = expansion(
      mult = c(
        0.03,
        0.12
      )
    )
  ) +
  
  labs(
    title =
      "Usual Weekly Working Hours in the United States, 2015–2025",
    
    subtitle =
      "March ASEC estimates using person-level ASEC weights",
    
    x = "Year",
    
    y =
      "Average usual weekly hours"
  ) +
  
  blog_theme


ggsave(
  filename =
    "figures/figure1_overall_trend.png",
  plot = fig1,
  width = 11,
  height = 7,
  dpi = 300
)

print(fig1)


# ============================================================
# FIGURE 2
# Hours by educational attainment
# ============================================================

fig2 <- ggplot(
  education_hours,
  aes(
    x = YEAR_num,
    y = avg_hours,
    color = education_group,
    linetype = education_group
  )
) +
  
  geom_line(
    linewidth = 1.15
  ) +
  
  geom_point(
    size = 2.8
  ) +
  
  scale_color_manual(
    values = education_colors
  ) +
  
  scale_linetype_manual(
    values = c(
      "Bachelor's or Higher" = "solid",
      "High School Graduate" = "dashed",
      "Some College" = "dotdash",
      "Less than High School" = "longdash"
    )
  ) +
  
  scale_x_continuous(
    breaks = 2015:2025
  ) +
  
  scale_y_continuous(
    breaks = seq(
      30,
      41,
      1
    ),
    expand = expansion(
      mult = c(
        0.02,
        0.05
      )
    )
  ) +
  
  labs(
    title =
      "Usual Weekly Working Hours by Educational Attainment",
    
    subtitle =
      "March ASEC estimates, 2015–2025",
    
    x = "Year",
    
    y =
      "Average usual weekly hours",
    
    color = "Educational attainment",
    
    linetype = "Educational attainment"
  ) +
  
  guides(
    color = guide_legend(
      nrow = 2,
      byrow = TRUE
    ),
    linetype = guide_legend(
      nrow = 2,
      byrow = TRUE
    )
  ) +
  
  blog_theme


ggsave(
  filename =
    "figures/figure2_education_trends.png",
  plot = fig2,
  width = 12,
  height = 7.5,
  dpi = 300
)

print(fig2)


# ============================================================
# FIGURE 3
# Improved connected dot plot: 2015 vs 2025
# ============================================================
#
# This replaces the original Figure 3.
#
# Main question:
# How much did usual weekly working hours change between
# 2015 and 2025 for each education group?
#
# Each horizontal line represents the change within an
# education group.
# ============================================================

fig3 <- comparison_2015_2025 %>%
  mutate(
    education_group = factor(
      education_group,
      levels = c(
        "Bachelor's or Higher",
        "High School Graduate",
        "Some College",
        "Less than High School"
      )
    )
  ) %>%
  
  ggplot(
    aes(
      x = avg_hours,
      y = education_group
    )
  ) +
  
  geom_segment(
    data = comparison_2015_2025 %>%
      group_by(education_group) %>%
      summarise(
        x_start =
          avg_hours[
            YEAR_num == 2015
          ],
        
        x_end =
          avg_hours[
            YEAR_num == 2025
          ],
        
        .groups = "drop"
      ),
    aes(
      x = x_start,
      xend = x_end,
      y = education_group,
      yend = education_group
    ),
    linewidth = 2,
    color = "#BFC5CC"
  ) +
  
  geom_point(
    aes(
      color = year_label
    ),
    size = 5
  ) +
  
  geom_text(
    aes(
      label = sprintf(
        "%.1f",
        avg_hours
      ),
      color = year_label
    ),
    hjust = -0.35,
    size = 4,
    fontface = "bold"
  ) +
  
  scale_color_manual(
    values = year_colors,
    name = "Year"
  ) +
  
  scale_x_continuous(
    limits = c(
      30,
      40.5
    ),
    breaks = seq(
      30,
      40,
      2
    ),
    expand = expansion(
      mult = c(
        0.01,
        0.08
      )
    )
  ) +
  
  labs(
    title =
      "Usual Weekly Working Hours: 2015 vs. 2025",
    
    subtitle =
      "Within-group changes across educational attainment",
    
    x =
      "Average usual weekly hours",
    
    y =
      "Educational attainment"
  ) +
  
  blog_theme


ggsave(
  filename =
    "figures/figure3_2015_vs_2025.png",
  plot = fig3,
  width = 11,
  height = 7,
  dpi = 300
)

print(fig3)


# ============================================================
# FIGURE 4
# Education gap over time
# ============================================================
#
# Main question:
# Did the difference in usual weekly hours between workers
# with Bachelor's or higher education and workers with less
# than high school education change over time?
# ============================================================

fig4 <- ggplot(
  education_gap,
  aes(
    x = YEAR_num,
    y = education_gap
  )
) +
  
  geom_hline(
    yintercept = 0,
    linetype = "dashed",
    linewidth = 0.8,
    color = "#777777"
  ) +
  
  geom_ribbon(
    aes(
      ymin = 0,
      ymax = education_gap
    ),
    fill = "#56B4E9",
    alpha = 0.20
  ) +
  
  geom_line(
    linewidth = 1.3,
    color = "#0072B2"
  ) +
  
  geom_point(
    size = 3.5,
    color = "#0072B2"
  ) +
  
  geom_text(
    aes(
      label = sprintf(
        "%.1f",
        education_gap
      )
    ),
    vjust = -1.0,
    size = 3.5,
    color = "#333333"
  ) +
  
  scale_x_continuous(
    breaks = 2015:2025
  ) +
  
  scale_y_continuous(
    labels = function(x) {
      paste0(
        x,
        " hrs"
      )
    },
    expand = expansion(
      mult = c(
        0.03,
        0.12
      )
    )
  ) +
  
  labs(
    title =
      "Education Gap in Usual Weekly Working Hours",
    
    subtitle =
      "Bachelor's or higher minus less than high school",
    
    x = "Year",
    
    y =
      "Difference in average usual weekly hours"
  ) +
  
  blog_theme


ggsave(
  filename =
    "figures/figure4_education_gap.png",
  plot = fig4,
  width = 11,
  height = 7,
  dpi = 300
)

print(fig4)


# ============================================================
# FIGURE 5
# Year-to-year changes
# ============================================================
#
# Main question:
# Which years experienced the largest changes in the overall
# average usual workweek?
# ============================================================

fig5 <- ggplot(
  yoy_change,
  aes(
    x = YEAR_num,
    y = change_hours,
    fill = change_hours >= 0
  )
) +
  
  geom_hline(
    yintercept = 0,
    linetype = "dashed",
    linewidth = 0.9,
    color = "#444444"
  ) +
  
  geom_col(
    width = 0.65,
    show.legend = FALSE
  ) +
  
  geom_text(
    aes(
      label = sprintf(
        "%+.2f",
        change_hours
      )
    ),
    vjust = ifelse(
      yoy_change$change_hours >= 0,
      -0.45,
      1.45
    ),
    size = 3.8,
    fontface = "bold"
  ) +
  
  scale_fill_manual(
    values = c(
      "TRUE" = "#009E73",
      "FALSE" = "#D55E00"
    )
  ) +
  
  scale_x_continuous(
    breaks = 2016:2025
  ) +
  
  scale_y_continuous(
    labels = function(x) {
      paste0(
        x,
        " hrs"
      )
    },
    expand = expansion(
      mult = c(
        0.15,
        0.15
      )
    )
  ) +
  
  labs(
    title =
      "Year-to-Year Change in Average Usual Weekly Hours",
    
    subtitle =
      "Change relative to the previous March ASEC",
    
    x = "Year",
    
    y =
      "Change in average weekly hours"
  ) +
  
  blog_theme


ggsave(
  filename =
    "figures/figure5_yoy_change.png",
  plot = fig5,
  width = 11,
  height = 7,
  dpi = 300
)

print(fig5)


# ============================================================
# FIGURE 6
# Share of workers reporting 40+ hours
# ============================================================
#
# This provides a different perspective from the mean:
#
# Instead of asking:
# "How many hours does the average worker report?"
#
# we ask:
# "What share of workers report a workweek of at least
# 40 hours?"
#
# This helps determine whether changes in average hours are
# associated with changes in the prevalence of full-time/
# long-hours work.
# ============================================================

fig6 <- share_40plus_comparison %>%
  mutate(
    education_group = factor(
      education_group,
      levels = c(
        "Bachelor's or Higher",
        "High School Graduate",
        "Some College",
        "Less than High School"
      )
    ),
    
    year_label = factor(
      YEAR_num,
      levels = c(
        2015,
        2025
      )
    )
  ) %>%
  
  ggplot(
    aes(
      x = education_group,
      y = share_40plus,
      fill = year_label
    )
  ) +
  
  geom_col(
    position = position_dodge(
      width = 0.75
    ),
    width = 0.65
  ) +
  
  geom_text(
    aes(
      label = percent(
        share_40plus,
        accuracy = 0.1
      )
    ),
    position = position_dodge(
      width = 0.75
    ),
    vjust = -0.35,
    size = 3.7,
    fontface = "bold"
  ) +
  
  scale_fill_manual(
    values = year_colors,
    name = "Year"
  ) +
  
  scale_y_continuous(
    labels = percent_format(
      accuracy = 1
    ),
    limits = c(
      0,
      1
    ),
    expand = expansion(
      mult = c(
        0,
        0.08
      )
    )
  ) +
  
  labs(
    title =
      "Share of Workers Reporting 40 or More Usual Hours",
    
    subtitle =
      "Comparison between 2015 and 2025 by educational attainment",
    
    x =
      "Educational attainment",
    
    y =
      "Share of workers"
  ) +
  
  blog_theme


ggsave(
  filename =
    "figures/figure6_40plus_hours.png",
  plot = fig6,
  width = 11,
  height = 7,
  dpi = 300
)

print(fig6)


# ============================================================
# 20. Export analytical datasets
# ============================================================

write_csv(
  overall_hours,
  "figures/overall_hours.csv"
)

write_csv(
  education_hours,
  "figures/education_hours.csv"
)

write_csv(
  comparison_2015_2025,
  "figures/comparison_2015_2025.csv"
)

write_csv(
  education_gap,
  "figures/education_gap.csv"
)

write_csv(
  yoy_change,
  "figures/yoy_change.csv"
)

write_csv(
  share_40plus,
  "figures/share_40plus.csv"
)


# ============================================================
# 21. Final message
# ============================================================

cat("\n\n============================================\n")
cat("BLOG 3 ANALYSIS COMPLETE\n")
cat("============================================\n")

cat("\nSix figures have been generated:\n")

cat("\n1. figure1_overall_trend.png")
cat("\n2. figure2_education_trends.png")
cat("\n3. figure3_2015_vs_2025.png")
cat("\n4. figure4_education_gap.png")
cat("\n5. figure5_yoy_change.png")
cat("\n6. figure6_40plus_hours.png\n")

cat("\nAll figures are saved in:\n")
cat(file.path(project_dir, "figures"))
cat("\n\n")