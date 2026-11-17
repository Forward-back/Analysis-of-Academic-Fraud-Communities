#!/usr/bin/env Rscript

# Build deployable application data and report assets from frozen analysis outputs.
# Run from the project root.

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(digest)
  library(jsonlite)
})

project_root <- normalizePath(getwd(), mustWork = TRUE)

assert_project_root <- function(root) {
  required <- c("config/project.yml", "data/outputs", "reports", "app")
  missing <- required[!file.exists(file.path(root, required))]
  if (length(missing) > 0) {
    stop("Not a project root; missing: ", paste(missing, collapse = ", "))
  }
}

relative_path <- function(path, root) {
  normalized <- normalizePath(path, winslash = "/", mustWork = FALSE)
  normalized_root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  prefix <- paste0(normalized_root, "/")
  if (!startsWith(tolower(normalized), tolower(prefix))) {
    stop("Path is outside project root: ", normalized)
  }
  substring(normalized, nchar(prefix) + 1L)
}

read_previous_manifest <- function(path) {
  if (!file.exists(path)) {
    return(character())
  }
  parsed <- tryCatch(
    jsonlite::read_json(path, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(parsed) || is.null(parsed$files)) {
    return(character())
  }
  vapply(parsed$files, function(item) as.character(item$path), character(1))
}

remove_previous_generated <- function(destination, previous_paths) {
  if (length(previous_paths) == 0) {
    return(invisible(NULL))
  }
  normalized_destination <- normalizePath(destination, winslash = "/", mustWork = TRUE)
  prefix <- paste0(normalized_destination, "/")
  for (relative in previous_paths) {
    target <- normalizePath(
      file.path(normalized_destination, relative),
      winslash = "/",
      mustWork = FALSE
    )
    if (!startsWith(tolower(target), tolower(prefix))) {
      stop("Refusing to remove generated file outside destination: ", target)
    }
    if (file.exists(target)) {
      unlink(target, force = TRUE)
    }
  }
}

copy_generated_tree <- function(source, destination, label) {
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  manifest_path <- file.path(destination, "manifest.json")
  previous_paths <- read_previous_manifest(manifest_path)
  remove_previous_generated(destination, previous_paths)

  all_files <- list.files(
    source,
    recursive = TRUE,
    full.names = TRUE,
    all.files = FALSE
  )
  all_files <- all_files[file.info(all_files)$isdir %in% FALSE]
  all_files <- all_files[basename(all_files) != "README.md"]

  if (length(all_files) == 0) {
    file_rows <- data.frame(
      path = character(),
      bytes = integer(),
      sha256 = character(),
      stringsAsFactors = FALSE
    )
  } else {
    destination_paths <- file.path(
      destination,
      substring(all_files, nchar(normalizePath(source, winslash = "/")) + 2L)
    )
    destination_dirs <- unique(dirname(destination_paths))
    for (directory in destination_dirs) {
      dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    }
    copied <- file.copy(all_files, destination_paths, overwrite = TRUE)
    if (!all(copied)) {
      stop("Failed to copy one or more files for ", label)
    }
    file_rows <- data.frame(
      path = relative_path(destination_paths, destination),
      bytes = file.info(destination_paths)$size,
      sha256 = vapply(destination_paths, digest, character(1), file = TRUE, algo = "sha256"),
      stringsAsFactors = FALSE
    )
  }

  manifest <- list(
    contract_version = "1.0",
    artifact = label,
    source_root = relative_path(source, project_root),
    destination_root = relative_path(destination, project_root),
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    file_count = nrow(file_rows),
    files = file_rows
  )
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE)
  message(label, ": ", nrow(file_rows), " files -> ", destination)
}

assert_project_root(project_root)

app_source <- file.path(project_root, "data", "outputs", "app")
app_destination <- file.path(project_root, "app", "data")
report_source <- file.path(project_root, "data", "outputs", "final", "figures")
report_destination <- file.path(project_root, "reports", "assets", "figures")

for (path in c(app_source, report_source)) {
  if (!dir.exists(path)) {
    stop("Missing source directory: ", relative_path(path, project_root))
  }
}

copy_generated_tree(app_source, app_destination, "application data")
copy_generated_tree(report_source, report_destination, "report figures")
