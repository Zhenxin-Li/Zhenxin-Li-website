# Parse English source dates without depending on the user's LC_TIME setting.
parse_english_date <- function(x, strict=TRUE) {
  x <- trimws(as.character(x))
  parts <- strsplit(gsub(',', '', x, fixed=TRUE), '[[:space:]]+')
  iso <- vapply(parts, function(p) {
    if(length(p)!=3L) return(NA_character_)
    month <- match(tolower(p[1]), tolower(month.abb))
    if(is.na(month) || !grepl('^[0-9]{1,2}$',p[2]) ||
       !grepl('^[0-9]{4}$',p[3])) return(NA_character_)
    sprintf('%s-%02d-%02d',p[3],month,as.integer(p[2]))
  }, character(1))
  dates <- as.Date(iso,format='%Y-%m-%d')
  bad <- which(is.na(dates))
  if(strict && length(bad)) stop(
    paste0('Unrecognized English source date: ',paste(unique(x[bad]),collapse=', ')),
    call.=FALSE)
  dates
}
