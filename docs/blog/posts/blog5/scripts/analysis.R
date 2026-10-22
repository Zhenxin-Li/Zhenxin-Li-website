inputs <- load_inputs()
sector_labels <- c(`1013` = "Manufacturing", `1024` = "Professional/business services")
conus_states <- c("01", "04", "05", "06", "08", "09", "10", "11", "12", "13", "16", "17", "18",
                  "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31",
                  "32", "33", "34", "35", "36", "37", "38", "39", "40", "41", "42", "44", "45",
                  "46", "47", "48", "49", "50", "51", "53", "54", "55", "56")
shapes <- inputs$shapes |> filter(STATEFP %in% conus_states) |> select(GEOID, STATEFP, NAME)
if (any(!st_is_valid(shapes))) shapes <- st_make_valid(shapes)
shapes <- st_transform(shapes, 5070)
stopifnot(st_crs(shapes)$epsg == 5070, !anyDuplicated(shapes$GEOID))
county_ids <- shapes$GEOID
q <- inputs$qcew |> filter(own_code == "5", size_code == "0")

# Official national employment, rather than an incomplete sum of published counties.
national <- q |> filter(area_fips == "US000") |>
  select(year, industry_code, employment, published)
stopifnot(nrow(national) == 6L, all(national$published), all(national$employment > 0),
          !anyDuplicated(national[c("year", "industry_code")]))
national <- national |> pivot_wider(names_from = industry_code, values_from = c(employment, published))
national_share <- national |> transmute(year, `1013` = employment_1013 / employment_10,
                                        `1024` = employment_1024 / employment_10) |>
  pivot_longer(-year, names_to = "industry_code", values_to = "us_share")

unallocated <- q |> filter(agglvl_code %in% c("71", "73"), grepl("^[0-9]{5}$", area_fips),
                            substr(area_fips, 1, 2) %in% conus_states, substr(area_fips, 3, 5) == "999") |>
  select(year, area_fips, industry_code, employment, published)
write_csv(unallocated, file.path(results_dir, "unallocated_county_records.csv"))
county <- q |> filter(agglvl_code %in% c("71", "73"), grepl("^[0-9]{5}$", area_fips),
                       substr(area_fips, 1, 2) %in% conus_states, substr(area_fips, 3, 5) != "999") |>
  transmute(year, GEOID = area_fips, industry_code, employment, published)
stopifnot(!anyDuplicated(county[c("year", "GEOID", "industry_code")]))
unmatched <- county |> filter(!GEOID %in% county_ids) |> distinct(year, GEOID)
write_csv(unmatched, file.path(results_dir, "unmatched_qcew_keys.csv"))
# In 2019 Connecticut uses old counties, in 2024 it uses planning regions.
# Current maps include the planning regions; growth calculations exclude CT.
unexpected <- unmatched |> filter(substr(GEOID, 1, 2) != "09")
if (nrow(unexpected)) stop("Unexpected unmatched QCEW keys; inspect the saved join audit.")

denominator <- county |> filter(industry_code == "10") |>
  transmute(year, GEOID, total = if_else(published, employment, NA_real_))
sector <- county |> filter(industry_code %in% names(sector_labels)) |>
  transmute(year, GEOID, industry_code, record_exists = TRUE, published,
            employment = if_else(published, employment, NA_real_))
panel <- tidyr::expand_grid(year = c("2019", "2024"), GEOID = county_ids,
                            industry_code = names(sector_labels)) |>
  left_join(sector, by = c("year", "GEOID", "industry_code")) |>
  left_join(denominator, by = c("year", "GEOID")) |>
  left_join(national_share, by = c("year", "industry_code")) |>
  mutate(sector = unname(sector_labels[industry_code]),
         status = case_when(is.na(record_exists) ~ "No published record",
                             !published ~ "Suppressed",
                             !is.finite(employment) | is.na(total) | total <= 0 ~ "Invalid denominator/value",
                             TRUE ~ "Available"),
         job_available = coalesce(record_exists, FALSE) & coalesce(published, FALSE) &
           is.finite(employment) & employment >= 0,
         share = if_else(status == "Available", employment / total, NA_real_),
         lq = share / us_share)
stopifnot(all(panel$share >= 0 & panel$share <= 1, na.rm = TRUE),
          all(is.finite(panel$lq[panel$status == "Available"])))

lq_levels <- c("Below 0.5", "0.5 to <1", "1 to <2", "2 or more", "Unavailable")
current <- panel |> filter(year == "2024") |>
  left_join(inputs$acs, by = "GEOID") |>
  mutate(lq_band = cut(lq, breaks = c(-Inf, .5, 1, 2, Inf), right = FALSE,
                       labels = lq_levels[1:4]),
         lq_band = factor(if_else(is.na(lq_band), "Unavailable", as.character(lq_band)), levels = lq_levels),
         concentration = factor(if_else(lq >= 1, "At/above U.S. share", "Below U.S. share"),
                                levels = c("Below U.S. share", "At/above U.S. share")))
stopifnot(nrow(current) == 2L * nrow(shapes),
          all(!is.na(current$county_name)),
          !anyDuplicated(current[c("GEOID", "industry_code")]))

growth <- panel |> select(year, GEOID, industry_code, sector, employment, status, job_available) |>
  pivot_wider(names_from = year, values_from = c(employment, status, job_available)) |>
  mutate(growth_status = case_when(substr(GEOID, 1, 2) == "09" ~ "Boundary change (Connecticut)",
                                   !job_available_2019 | !job_available_2024 ~ "Unavailable endpoint",
                                   employment_2019 < 100 ~ "Fewer than 100 initial jobs",
                                   TRUE ~ "Comparable"),
         change = if_else(growth_status == "Comparable", employment_2024 / employment_2019 - 1, NA_real_),
         change_band = case_when(is.na(change) ~ "Unavailable/excluded", change < -.2 ~ "Below -20%",
                                  change < 0 ~ "-20% to <0%", change == 0 ~ "No change",
                                  change <= .2 ~ ">0% to 20%", TRUE ~ "Above 20%"),
         change_band = factor(change_band, levels = c("Below -20%", "-20% to <0%", "No change",
                                                       ">0% to 20%", "Above 20%", "Unavailable/excluded")))
stopifnot(all(is.finite(growth$change[growth$growth_status == "Comparable"])),
          !any(growth$growth_status == "Comparable" & substr(growth$GEOID, 1, 2) == "09"))

income_sample <- current |> filter(is.finite(lq), !is.na(income), !is.na(income_moe))
income_summary <- income_sample |> group_by(sector, concentration) |>
  summarise(n_counties = n(), median_income = median(income), q25 = quantile(income, .25),
            q75 = quantile(income, .75), .groups = "drop")
income_sensitivity <- income_sample |> filter(income_moe / income <= .3) |>
  group_by(sector, concentration) |>
  summarise(n_counties = n(), median_income = median(income), .groups = "drop")
growth_summary <- growth |> filter(growth_status == "Comparable") |> group_by(sector) |>
  summarise(n_counties = n(), n_gained = sum(change > 0), share_gained = mean(change > 0),
            median_change = median(change),
            matched_job_change = sum(employment_2024) / sum(employment_2019) - 1, .groups = "drop")
threshold_sensitivity <- bind_rows(lapply(c(1, 50, 100, 250), function(threshold) {
  growth |> filter(substr(GEOID, 1, 2) != "09", job_available_2019, job_available_2024,
                    employment_2019 >= threshold) |>
    group_by(sector) |>
    summarise(minimum_initial_jobs = threshold, n_counties = n(),
              share_gained = mean(employment_2024 > employment_2019),
              matched_job_change = sum(employment_2024) / sum(employment_2019) - 1,
              .groups = "drop")
}))
coverage <- panel |> count(year, sector, status, name = "n_counties")
growth_coverage <- growth |> count(sector, growth_status, name = "n_counties")
examples <- current |> filter(lq >= 1.5, is.finite(employment)) |>
  group_by(sector) |> slice_max(employment, n = 3, with_ties = FALSE) |> ungroup() |>
  select(sector, county_name, employment, share, lq)
top_changes <- growth |> filter(growth_status == "Comparable") |>
  mutate(job_change = employment_2024 - employment_2019) |>
  left_join(inputs$acs |> select(GEOID, county_name), by = "GEOID") |>
  group_by(sector) |> slice_max(abs(job_change), n = 5, with_ties = FALSE) |> ungroup()

write_csv(panel, file.path(results_dir, "county_sector_panel.csv"))
write_csv(current, file.path(results_dir, "current_county_analysis.csv"))
write_csv(growth, file.path(results_dir, "county_sector_growth.csv"))
write_csv(coverage, file.path(results_dir, "disclosure_coverage.csv"))
write_csv(growth_coverage, file.path(results_dir, "growth_coverage.csv"))
write_csv(income_summary, file.path(results_dir, "income_group_summary.csv"))
write_csv(income_sensitivity, file.path(results_dir, "income_precision_sensitivity.csv"))
write_csv(growth_summary, file.path(results_dir, "growth_summary.csv"))
write_csv(threshold_sensitivity, file.path(results_dir, "initial_jobs_sensitivity.csv"))
write_csv(national_share, file.path(results_dir, "national_benchmarks.csv"))
write_csv(examples, file.path(results_dir, "large_specialized_counties.csv"))
write_csv(top_changes, file.path(results_dir, "largest_absolute_changes.csv"))
checks <- tibble(check = c("Unique spatial GEOIDs", "Unique county-year-sector keys", "Employment shares in [0,1]",
                          "Complete 2024 ACS geography match", "CT excluded from growth", "National benchmark published"),
                 passed = TRUE)
write_csv(checks, file.path(results_dir, "validation_checks.csv"))
writeLines(capture.output(sessionInfo()), file.path(results_dir, "sessionInfo.txt"))
raw_files <- list.files(raw_dir, full.names = TRUE)
write_csv(tibble(file = basename(raw_files), md5 = unname(tools::md5sum(raw_files))),
          file.path(results_dir, "snapshot_checksums.csv"))

theme_set(theme_minimal(base_size = 11) + theme(panel.grid.minor = element_blank(),
           plot.title = element_text(face = "bold"), legend.position = "bottom"))
save_figure <- function(p, filename, width = 10, height = 8) {
  ggsave(file.path(fig_dir, filename), p, width = width, height = height, dpi = 240, bg = "white")
  p
}
percent <- function(x) sprintf("%.1f%%", 100 * x)
dollars <- function(x) scales::dollar(x, accuracy = 1)
sector_stat <- function(table, which_sector, variable) table[[variable]][table$sector == which_sector]
income_gap <- function(which_sector, tab = income_summary) {
  x <- tab |> filter(sector == which_sector)
  x$median_income[x$concentration == "At/above U.S. share"] - x$median_income[x$concentration == "Below U.S. share"]
}
gap_text <- function(x) paste(dollars(abs(x)), if (x >= 0) "higher" else "lower")
example_text <- function(which_sector) paste(examples$county_name[examples$sector == which_sector], collapse = "; ")
