# Header-based rvest parser for a permitted, saved screener HTML page.
# It performs no network request. Never use row position as a ticker identifier.
parse_saved_html <- function(path) {
  stopifnot(file.exists(path))
  page <- rvest::read_html(path)
  tables <- rvest::html_table(rvest::html_elements(page,"table"),fill=TRUE)
  wanted <- c("Ticker","Inst Own")
  candidates <- Filter(function(x) all(wanted %in% names(x)),tables)
  if(length(candidates)!=1L) stop("Expected one header-labelled ownership table; inspect the saved HTML instead of guessing column positions.")
  x <- candidates[[1]]
  if(!all(grepl("^[A-Za-z][A-Za-z0-9.-]*$",x$Ticker))) stop("Invalid ticker column; possible row-number extraction.")
  if(anyDuplicated(x$Ticker)) stop("Duplicate tickers: check pagination before joining.")
  x
}
