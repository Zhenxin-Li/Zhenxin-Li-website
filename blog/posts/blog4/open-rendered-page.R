# Open the main HTML from a successful single-document render in RStudio.
# This hook does not render or execute any other document.
open_rendered_page <- function() {
  if (Sys.getenv("RSTUDIO") != "1" ||
      Sys.getenv("QUARTO_PROJECT_RENDER_ALL") == "1" ||
      tolower(Sys.getenv("CI")) == "true") return(invisible(NULL))
  outputs <- strsplit(Sys.getenv("QUARTO_PROJECT_OUTPUT_FILES"), "\n", fixed = TRUE)[[1]]
  outputs <- outputs[nzchar(outputs)]
  # Quarto can use a list file for large output lists.
  list_file <- Sys.getenv("QUARTO_PROJECT_OUTPUT_FILES_FILE")
  if (!length(outputs) && nzchar(list_file) && file.exists(list_file)) {
    outputs <- readLines(list_file, warn = FALSE)
  }
  html <- outputs[grepl("\\.html?$", outputs, ignore.case = TRUE) & file.exists(outputs)]
  if (!length(html)) return(invisible(NULL))
  # Website renders can also regenerate a parent listing page. Prefer the
  # article over that supplemental listing; still open listings rendered alone.
  if (length(html) > 1L) {
    listing <- vapply(html, function(path) {
      any(grepl('class="[^"]*quarto-listing', readLines(path, warn = FALSE)))
    }, logical(1))
    if (any(!listing)) html <- html[!listing]
  }
  target <- normalizePath(html[1], winslash = "/", mustWork = TRUE)
  url <- paste0(if (.Platform$OS.type == "windows") "file:///" else "file://",
                utils::URLencode(target))
  tryCatch(utils::browseURL(url), error = function(e) {
    message("Rendered successfully. Open this HTML file: ", target)
  })
}
open_rendered_page()
