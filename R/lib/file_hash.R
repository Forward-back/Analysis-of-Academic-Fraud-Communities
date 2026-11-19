normalize_text_line_endings <- function(bytes) {
  values <- as.integer(bytes)
  if (length(values) == 0L) {
    return(bytes)
  }

  next_is_lf <- c(values[-1L] == 10L, FALSE)
  remove_lf_after_cr <- values == 13L & next_is_lf
  values[values == 13L] <- 10L
  as.raw(values[!remove_lf_after_cr])
}

sha256_canonical_file <- function(path) {
  if (!file.exists(path)) {
    stop("File does not exist: ", path)
  }

  text_extensions <- c(
    "csv", "json", "md", "txt", "tsv", "tex",
    "r", "rmd", "qmd", "yml", "yaml"
  )
  extension <- tolower(tools::file_ext(path))
  if (!extension %in% text_extensions) {
    return(digest::digest(file = path, algo = "sha256"))
  }

  size <- file.info(path)$size
  bytes <- readBin(path, what = "raw", n = size)
  digest::digest(
    normalize_text_line_endings(bytes),
    algo = "sha256",
    serialize = FALSE
  )
}
