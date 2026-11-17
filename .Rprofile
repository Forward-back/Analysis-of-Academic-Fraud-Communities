if (identical(Sys.getenv("RENV_AUTOLOADER_ENABLED"), "FALSE")) {
  invisible(NULL)
} else if (!file.exists("renv/activate.R")) {
  invisible(NULL)
} else if (grepl("[^ -~]", getwd())) {
  message(
    "renv autoactivation skipped: project path contains non-ASCII characters. ",
    "Use an ASCII path or set RENV_AUTOLOADER_ENABLED=TRUE after restoring renv."
  )
} else {
  source("renv/activate.R")
}
