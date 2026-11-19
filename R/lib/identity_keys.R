doi_environment_key <- function(doi) {
  vapply(doi, function(value) {
    if (length(value) == 0L || is.na(value) || !nzchar(value)) {
      return(NA_character_)
    }
    digest::digest(
      charToRaw(enc2utf8(value)),
      algo = "sha256",
      serialize = FALSE
    )
  }, character(1), USE.NAMES = FALSE)
}
