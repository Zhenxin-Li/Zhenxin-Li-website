# Acquisition helpers: every successful response is saved before analysis.
# Existing snapshots are validated and reused; credentials are never written.
read_qcew <- function(path, expected_year, expected_industry) {
  x <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()),
                       na = c("", "NA"), show_col_types = FALSE, progress = FALSE)
  required <- c("area_fips", "own_code", "industry_code", "agglvl_code", "size_code", "year",
                "disclosure_code", "annual_avg_emplvl")
  if (!all(required %in% names(x)) || !nrow(x)) stop("Invalid QCEW CSV: ", basename(path))
  if (any(x$year != as.character(expected_year)) ||
      any(x$industry_code != expected_industry)) stop("Unexpected QCEW year or sector.")
  x |>
    dplyr::mutate(employment = readr::parse_double(annual_avg_emplvl),
                  published = is.na(disclosure_code) | trimws(disclosure_code) != "N")
}

read_acs <- function(path) {
  x <- jsonlite::fromJSON(path)
  required <- c("NAME", "B19013_001E", "B19013_001M", "state", "county")
  if (!is.matrix(x) || !all(required %in% x[1, ])) stop("Invalid ACS response (expected JSON data).")
  out <- as.data.frame(x[-1, , drop = FALSE], stringsAsFactors = FALSE)
  names(out) <- x[1, ]
  out <- tibble::as_tibble(out) |>
    dplyr::transmute(GEOID = paste0(state, county), county_name = NAME,
                     income_raw = readr::parse_double(B19013_001E),
                     moe_raw = readr::parse_double(B19013_001M)) |>
    dplyr::mutate(income = dplyr::if_else(income_raw > 0, income_raw, NA_real_),
                  income_moe = dplyr::if_else(moe_raw >= 0, moe_raw, NA_real_))
  if (anyDuplicated(out$GEOID) || any(!grepl("^[0-9]{5}$", out$GEOID))) stop("Invalid ACS county keys.")
  out
}

read_geometry <- function(path) {
  archive <- utils::unzip(path, list = TRUE)
  member <- archive$Name[grepl("\\.shp$", archive$Name)]
  if (length(member) != 1L) stop("County archive must contain exactly one shapefile.")
  shapes <- sf::st_read(paste0("/vsizip/", normalizePath(path, winslash = "/"), "/", member), quiet = TRUE)
  if (!all(c("GEOID", "STATEFP", "NAME") %in% names(shapes)) ||
      anyDuplicated(shapes$GEOID) || any(sf::st_is_empty(shapes))) stop("Invalid county geometry.")
  shapes
}

cached_download <- function(url, filename, validator, private_url = url) {
  path <- file.path(raw_dir, filename)
  if (file.exists(path)) {
    validator(path)
    return(path)
  }
  tmp <- tempfile(fileext = paste0(".", tools::file_ext(filename)))
  on.exit(unlink(tmp), add = TRUE)
  # Sanitized errors prevent a Census API key from appearing in logs.
  ok <- tryCatch({
    suppressWarnings(utils::download.file(private_url, tmp, mode = "wb", quiet = TRUE))
    validator(tmp)
    TRUE
  }, error = function(e) FALSE)
  if (!ok) stop("Download or validation failed for ", filename,
                ". Existing local snapshots were not changed. Check source availability",
                if (grepl("acs", filename)) " and CENSUS_API_KEY if refreshing ACS." else ".")
  if (!file.copy(tmp, path)) stop("Cannot save snapshot: ", filename)
  writeLines(c(paste0("URL (credentials omitted): ", url),
               paste0("Retrieved UTC: ", format(Sys.time(), tz = "UTC", usetz = TRUE))),
             paste0(path, ".source.txt"))
  path
}

load_inputs <- function() {
  qcew <- dplyr::bind_rows(lapply(c(2019L, 2024L), function(y) {
    dplyr::bind_rows(lapply(c("10", "1013", "1024"), function(code) {
      validator <- function(p) read_qcew(p, y, code)
      path <- cached_download(
        sprintf("https://data.bls.gov/cew/data/api/%s/a/industry/%s.csv", y, code),
        sprintf("qcew_%s_%s.csv", y, code), validator)
      read_qcew(path, y, code)
    }))
  }))
  acs_url <- paste0("https://api.census.gov/data/2024/acs/acs5?",
                    "get=NAME,B19013_001E,B19013_001M&for=county:*")
  key <- Sys.getenv("CENSUS_API_KEY")
  private_url <- if (nzchar(key)) paste0(acs_url, "&key=", key) else acs_url
  acs_path <- cached_download(acs_url, "acs5_2024_income.json", read_acs, private_url)
  geo_path <- cached_download(
    "https://www2.census.gov/geo/tiger/GENZ2024/shp/cb_2024_us_county_20m.zip",
    "cb_2024_us_county_20m.zip", read_geometry)
  list(qcew = qcew, acs = read_acs(acs_path), shapes = read_geometry(geo_path))
}
