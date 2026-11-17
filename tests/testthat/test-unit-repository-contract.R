project_root_for_contract <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

test_that("required repository contract files exist", {
  project_root <- project_root_for_contract()
  required <- c(
    "README.md",
    "CONTEXT.md",
    "CONTRIBUTING.md",
    ".gitattributes",
    ".github/pull_request_template.md",
    "config/project.yml",
    "config/analysis.yml",
    "data/reference/mappings/rwdb_field_dictionary_v1.csv",
    "data/reference/mappings/reason_dictionary_v1.csv",
    "data/reference/mappings/provenance.json",
    "data/outputs/audits/manifest.json",
    "data/outputs/baseline/README.md",
    "data/outputs/baseline/manifest.json",
    "data/outputs/final/README.md",
    "data/outputs/app/README.md",
    "docs/decisions/0002-repository-file-contract.md",
    "docs/specs/README.md",
    "scripts/build_deliverables.R",
    "R/90_baseline_eda.R",
    "docs/data/quality-audit.md",
    "docs/progress/current-status.md"
  )

  expect_true(all(file.exists(file.path(project_root, required))))
})

test_that("reference mappings are frozen and internally consistent", {
  project_root <- project_root_for_contract()
  mapping_file <- file.path(
    project_root,
    "data/reference/mappings/reason_dictionary_v1.csv"
  )
  mapping <- utils::read.csv(
    mapping_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  allowed_families <- c(
    "publication_process",
    "image_integrity",
    "plagiarism_authorship",
    "data_integrity",
    "error_control",
    "unclassified"
  )

  expect_equal(anyDuplicated(mapping$reason_label), 0L)
  expect_true(all(unique(mapping$reason_family) %in% allowed_families))
  expect_setequal(unique(mapping$mapping_version), "1.0-frozen")
})

test_that("reference provenance hashes match frozen files", {
  project_root <- project_root_for_contract()
  provenance_file <- file.path(
    project_root,
    "data/reference/mappings/provenance.json"
  )
  provenance <- jsonlite::read_json(provenance_file, simplifyVector = FALSE)

  for (item in provenance$files) {
    path <- file.path(project_root, item$path)
    expect_true(file.exists(path))
    expect_equal(
      digest::digest(file = path, algo = "sha256"),
      item$sha256
    )
  }
})

test_that("outputs use phase-first structure", {
  project_root <- project_root_for_contract()
  expected_directories <- c(
    "data/outputs/audits/figures",
    "data/outputs/audits/tables",
    "data/outputs/baseline/tables",
    "data/outputs/baseline/figures",
    "data/outputs/final/tables",
    "data/outputs/final/figures",
    "data/outputs/final/models",
    "data/outputs/app",
    "data/outputs/app/tables"
  )
  legacy_directories <- c(
    "data/outputs/tables",
    "data/outputs/figures",
    "data/outputs/shiny"
  )

  expect_true(all(dir.exists(file.path(project_root, expected_directories))))
  expect_false(any(dir.exists(file.path(project_root, legacy_directories))))
})

test_that("baseline manifest uses project-relative paths", {
  project_root <- project_root_for_contract()
  manifest_file <- file.path(
    project_root,
    "data/outputs/baseline/manifest.json"
  )
  manifest <- jsonlite::read_json(manifest_file, simplifyVector = FALSE)

  expect_equal(manifest$contract_version, "1.0")
  expect_equal(manifest$source_path_type, "project-relative")
  expect_equal(manifest$source_file, "data/raw/retractions.csv")
  expect_false(grepl("^([A-Za-z]:|/)", manifest$source_file))

  for (output in manifest$outputs) {
    expect_false(grepl("^([A-Za-z]:|/)", output$path))
  }
})

test_that("audit manifest hashes match frozen audit files", {
  project_root <- project_root_for_contract()
  manifest_file <- file.path(project_root, "data/outputs/audits/manifest.json")
  manifest <- jsonlite::read_json(manifest_file, simplifyVector = FALSE)

  expect_equal(manifest$contract_version, "1.0")
  expect_equal(manifest$source_path_type, "project-relative")

  for (item in manifest$files) {
    path <- file.path(project_root, item$path)
    expect_true(file.exists(path))
    expect_equal(
      digest::digest(file = path, algo = "sha256"),
      item$sha256
    )
  }
})

test_that("active Markdown links resolve", {
  project_root <- project_root_for_contract()
  markdown_files <- list.files(
    project_root,
    pattern = "\\.md$",
    recursive = TRUE,
    full.names = TRUE
  )
  markdown_files <- markdown_files[
    !grepl("[/\\\\]docs[/\\\\]archive[/\\\\]", markdown_files)
  ]

  broken <- character()
  for (file in markdown_files) {
    text <- paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    matches <- regmatches(
      text,
      gregexpr("\\[[^]]+\\]\\(([^)]+)\\)", text, perl = TRUE)
    )[[1]]
    if (identical(matches, character(0)) || identical(matches, "-1")) {
      next
    }
    for (match in matches) {
      target <- sub("^.*\\((.*)\\)$", "\\1", match)
      target <- sub("#.*$", "", target)
      if (target == "" || grepl("^(https?:|mailto:)", target)) {
        next
      }
      target <- utils::URLdecode(target)
      resolved <- file.path(dirname(file), target)
      if (!file.exists(resolved)) {
        broken <- c(
          broken,
          paste0(sub(paste0(project_root, "/?"), "", file), ": ", target)
        )
      }
    }
  }

  expect_equal(broken, character(0))
})
