#!/usr/bin/env Rscript

packages <- c(
  "renv", "data.table", "readr", "dplyr", "tidyr", "stringr", "ggplot2", "scales",
  "digest", "jsonlite", "forcats"
)

status <- data.frame(
  package = packages,
  installed = vapply(packages, requireNamespace, logical(1), quietly = TRUE)
)

print(status, row.names = FALSE)
cat("\nR version:", R.version.string, "\n")
