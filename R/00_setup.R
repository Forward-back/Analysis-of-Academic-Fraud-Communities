#!/usr/bin/env Rscript

# Shared environment and utilities for the numbered analysis pipeline.

options(stringsAsFactors = FALSE)
suppressWarnings(Sys.setlocale("LC_ALL", "Chinese"))

required_packages <- c(
  "data.table",
  "digest",
  "dplyr",
  "httr",
  "httr2",
  "jsonlite",
  "purrr",
  "stringr",
  "tibble",
  "tidyr",
  "yaml"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  stop("Missing required packages: ", paste(missing_packages, collapse = ", "))
}

project_config <- yaml::read_yaml("config/project.yml")
analysis_config <- yaml::read_yaml("config/analysis.yml")

project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)

path_from_config <- function(key) {
  path <- project_config$paths[[key]]
  if (is.null(path) || !nzchar(path)) {
    stop("Missing path in config/project.yml: ", key)
  }
  file.path(project_dir, path)
}

interim_dir <- path_from_config("interim")
processed_dir <- path_from_config("processed")
outputs_dir <- path_from_config("outputs")
audit_table_dir <- file.path(outputs_dir, "audits", "tables")
audit_figure_dir <- file.path(outputs_dir, "audits", "figures")

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

project_relative_path <- function(paths) {
  vapply(
    paths,
    function(path) {
      normalized <- normalizePath(path, winslash = "/", mustWork = FALSE)
      if (!startsWith(tolower(normalized), tolower(project_dir))) {
        stop("Path is outside project root: ", normalized)
      }
      if (identical(normalized, project_dir)) {
        return(".")
      }
      substring(normalized, nchar(project_dir) + 2L)
    },
    character(1),
    USE.NAMES = FALSE
  )
}

write_csv_utf8 <- function(data, path) {
  ensure_dir(dirname(path))
  utils::write.csv(
    data,
    path,
    row.names = FALSE,
    fileEncoding = "UTF-8",
    na = ""
  )
  invisible(path)
}

parse_rwdb_date <- function(x) {
  clean <- stringr::str_trim(x)
  clean <- stringr::str_replace(
    clean,
    "\\s+\\d{1,2}:\\d{2}.*$",
    ""
  )
  as.Date(clean, format = "%m/%d/%Y")
}

normalize_doi <- function(x) {
  out <- stringr::str_trim(x)
  out <- stringr::str_to_lower(out)
  out <- stringr::str_replace(out, "^https?://(dx\\.)?doi\\.org/", "")
  out <- stringr::str_replace(out, "^doi:\\s*", "")
  out <- stringr::str_replace(out, "[\\.,;]+$", "")
  out[is.na(out) | out == "" | out %in% c("unavailable", "n/a", "na")] <-
    NA_character_
  out
}

normalize_title <- function(x) {
  out <- stringr::str_to_lower(stringr::str_trim(x))
  out <- stringr::str_replace_all(out, "[^\\p{L}\\p{N}]+", " ")
  out <- stringr::str_squish(out)
  out[out == ""] <- NA_character_
  out
}

split_semicolon <- function(x) {
  pieces <- stringr::str_split(ifelse(is.na(x), "", x), ";", simplify = FALSE)
  lapply(pieces, function(values) {
    values <- stringr::str_trim(values)
    unique(values[values != ""])
  })
}

concat_values <- function(x) {
  values <- unlist(x, use.names = FALSE)
  values <- stringr::str_trim(values)
  values <- values[!is.na(values) & values != ""]
  sort(unique(values))
}

mode_nonmissing <- function(x) {
  x <- x[!is.na(x) & x != ""]
  if (length(x) == 0) {
    return(NA_character_)
  }
  counts <- sort(table(x), decreasing = TRUE)
  names(counts)[[1]]
}

list_to_delimited <- function(x) {
  vapply(x, function(values) {
    values <- values[!is.na(values) & values != ""]
    paste(values, collapse = ";")
  }, character(1))
}

assert_columns <- function(data, required, label) {
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop(
      label,
      " is missing required columns: ",
      paste(missing, collapse = ", ")
    )
  }
  invisible(TRUE)
}

sha256_file <- function(path) {
  digest::digest(file = path, algo = "sha256")
}

write_audit_manifest <- function() {
  ensure_dir(audit_table_dir)
  ensure_dir(audit_figure_dir)

  files <- list.files(
    c(audit_table_dir, audit_figure_dir),
    full.names = TRUE,
    recursive = FALSE
  )
  files <- files[
    !basename(files) %in% c("README.md", "manifest.json") &
      !dir.exists(files)
  ]
  files <- sort(files)

  manifest <- list(
    contract_version = "1.0",
    artifact = "audits",
    generated_at = format(Sys.Date(), "%Y-%m-%d"),
    source_path_type = "project-relative",
    files = lapply(files, function(path) {
      list(
        path = project_relative_path(path),
        sha256 = sha256_file(path)
      )
    })
  )

  jsonlite::write_json(
    manifest,
    file.path(outputs_dir, "audits", "manifest.json"),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  invisible(manifest)
}

ensure_dir(interim_dir)
ensure_dir(processed_dir)
ensure_dir(audit_table_dir)
ensure_dir(audit_figure_dir)
