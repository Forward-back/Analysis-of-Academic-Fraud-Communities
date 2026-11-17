test_that("required project files exist", {
  project_root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
  required <- c(
    "README.md",
    "CONTEXT.md",
    "config/project.yml",
    "config/analysis.yml",
    "data/raw/retractions.csv",
    "data/external/mappings/rwdb_field_dictionary_v1.csv",
    "data/external/mappings/reason_dictionary_v1.csv",
    "R/90_baseline_eda.R",
    "docs/data/quality-audit.md",
    "docs/progress/current-status.md"
  )

  expect_true(all(file.exists(file.path(project_root, required))))
})

test_that("raw data hash matches the frozen manifest", {
  project_root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
  raw_file <- file.path(project_root, "data/raw/retractions.csv")
  expect_true(file.exists(raw_file))
  expect_equal(
    digest::digest(file = raw_file, algo = "sha256"),
    "eefbe08a9ecfa75308951fb7b03d265e9ccd8431eca32d9727b7ddc8c4b70faa"
  )
})

test_that("baseline quality output preserves core counts", {
  project_root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
  quality_file <- file.path(project_root, "data/outputs/baseline/data_quality_summary.csv")
  expect_true(file.exists(quality_file))

  quality <- utils::read.csv(
    quality_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  values <- setNames(quality$value, quality$metric)

  expect_equal(unname(values[["total_notification_records"]]), "73597")
  expect_equal(unname(values[["retraction_records"]]), "68155")
  expect_equal(unname(values[["core_retraction_records_2012_2025"]]), "52638")
})
