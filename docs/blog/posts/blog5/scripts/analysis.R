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
q <- inputs$qcew |> filter(own_code == "5", size_code == "0")
national <- q |> filter(area_fips == "US000") |> select(industry_code, employment, published)
stopifnot(nrow(national) == 3L, !anyDuplicated(national$industry_code),
          all(national$published), all(is.finite(national$employment)), all(national$employment > 0))
national_total <- national$employment[national$industry_code == "10"]
national_share <- national |> filter(industry_code %in% names(sector_labels)) |>
  transmute(industry_code, us_share = employment / national_total)
county_records <- q |> filter(agglvl_code %in% c("71", "73"), grepl("^[0-9]{5}$", area_fips),
                               substr(area_fips, 1, 2) %in% conus_states)
unallocated <- county_records |> filter(substr(area_fips, 3, 5) == "999")
county <- county_records |> filter(substr(area_fips, 3, 5) != "999") |>
  transmute(GEOID = area_fips, industry_code, employment, published)
stopifnot(!anyDuplicated(county[c("GEOID", "industry_code")]))
unmatched <- county |> filter(!GEOID %in% shapes$GEOID) |> distinct(GEOID)
write_csv(unmatched, file.path(results_dir, "unmatched_qcew_keys.csv"))
if (nrow(unmatched)) stop("Unmatched 2024 county keys; inspect join audit.")
denominator <- county |> filter(industry_code == "10") |>
  transmute(GEOID, total = if_else(published, employment, NA_real_))
sector <- county |> filter(industry_code %in% names(sector_labels)) |>
  transmute(GEOID, industry_code, record_exists = TRUE, published,
            employment = if_else(published, employment, NA_real_))
current <- expand_grid(GEOID = shapes$GEOID, industry_code = names(sector_labels)) |>
  left_join(sector, by = c("GEOID", "industry_code")) |>
  left_join(denominator, by = "GEOID") |>
  left_join(national_share, by = "industry_code") |>
  left_join(inputs$acs, by = "GEOID") |>
  mutate(sector = unname(sector_labels[industry_code]),
         status = case_when(is.na(record_exists) ~ "No published record", !published ~ "Suppressed",
                             !is.finite(employment) | is.na(total) | total <= 0 ~ "Invalid denominator/value",
                             TRUE ~ "Available"),
         share = if_else(status == "Available", employment / total, NA_real_), lq = share / us_share,
         concentration = factor(if_else(lq >= 1, "At/above U.S. share", "Below U.S. share"),
                                levels = c("Below U.S. share", "At/above U.S. share")))
stopifnot(nrow(current) == 2L * nrow(shapes), !anyDuplicated(current[c("GEOID", "industry_code")]),
          all(!is.na(current$county_name)), all(current$share >= 0 & current$share <= 1, na.rm = TRUE),
          all(is.finite(current$lq[current$status == "Available"])))
lq_levels <- c("Below 0.5", "0.5 to <1", "1 to <2", "2 or more", "Unavailable")
current <- current |> mutate(lq_band = cut(lq, breaks = c(-Inf, .5, 1, 2, Inf), right = FALSE,
                                          labels = lq_levels[1:4]),
                              lq_band = factor(if_else(is.na(lq_band), "Unavailable", as.character(lq_band)),
                                               levels = lq_levels))
income_sample <- current |> filter(is.finite(lq), !is.na(income), !is.na(income_moe))
summarize_income <- function(x) x |> group_by(sector, concentration) |>
  summarise(n_counties = n(), median_income = median(income), q25 = quantile(income, .25),
            q75 = quantile(income, .75), .groups = "drop")
income_summary <- summarize_income(income_sample)
income_precision <- income_sample |> filter(income_moe / income <= .3) |> summarize_income()
common_ids <- income_sample |> count(GEOID) |> filter(n == 2L) |> pull(GEOID)
income_common <- income_sample |> filter(GEOID %in% common_ids) |> summarize_income()
coverage <- current |> group_by(sector) |> summarise(
  map_counties = n(), valid_lq = sum(is.finite(lq)), suppressed = sum(status == "Suppressed"),
  no_record = sum(status == "No published record"),
  other_unavailable = sum(status == "Invalid denominator/value"), .groups = "drop")
coverage <- coverage |> left_join(income_sample |> count(sector, name = "income_sample"), by = "sector")
examples <- current |> filter(lq >= 1.5) |> group_by(sector) |>
  slice_max(employment, n = 3, with_ties = FALSE) |> ungroup() |>
  select(sector, county_name, employment, share, lq, income)
write_csv(current, file.path(results_dir, "county_analysis_2024.csv"))
write_csv(national_share, file.path(results_dir, "national_benchmarks.csv"))
write_csv(income_summary, file.path(results_dir, "income_group_summary.csv"))
write_csv(income_precision, file.path(results_dir, "income_precision_sensitivity.csv"))
write_csv(income_common, file.path(results_dir, "common_county_sensitivity.csv"))
write_csv(coverage, file.path(results_dir, "sample_coverage.csv"))
write_csv(examples, file.path(results_dir, "large_specialized_counties.csv"))
write_csv(unallocated |> select(area_fips, industry_code, employment, published),
          file.path(results_dir, "unallocated_county_records.csv"))
write_csv(tibble(check = c("Unique spatial keys", "Unique county-sector keys", "No unmatched QCEW keys",
                          "Complete ACS geography match", "Shares within [0,1]", "Published national denominator"),
                 passed = TRUE), file.path(results_dir, "validation_checks.csv"))
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
dollars <- function(x) scales::dollar(x, accuracy = 1)
income_gap <- function(which_sector, tab = income_summary) {
  x <- tab |> filter(sector == which_sector)
  x$median_income[x$concentration == "At/above U.S. share"] - x$median_income[x$concentration == "Below U.S. share"]
}
gap_text <- function(x) paste(dollars(abs(x)), if (x >= 0) "higher" else "lower")
