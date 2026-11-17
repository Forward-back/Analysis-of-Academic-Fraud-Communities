project_root_for_baseline <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

raw_file_for_baseline <- function(project_root) {
  file.path(project_root, "data/raw/retractions.csv")
}

test_that("raw data hash matches the frozen manifest", {
  project_root <- project_root_for_baseline()
  raw_file <- raw_file_for_baseline(project_root)
  testthat::skip_if_not(
    file.exists(raw_file),
    "Raw Retraction Watch data is not available in this checkout."
  )

  expect_equal(
    digest::digest(file = raw_file, algo = "sha256"),
    "eefbe08a9ecfa75308951fb7b03d265e9ccd8431eca32d9727b7ddc8c4b70faa"
  )
})

test_that("baseline quality output preserves core counts", {
  project_root <- project_root_for_baseline()
  raw_file <- raw_file_for_baseline(project_root)
  testthat::skip_if_not(
    file.exists(raw_file),
    "Raw Retraction Watch data is not available in this checkout."
  )

  quality_file <- file.path(
    project_root,
    "data/outputs/baseline/tables/data_quality_summary.csv"
  )
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

test_that("candidate mapping is generated outside reference data", {
  project_root <- project_root_for_baseline()
  raw_file <- raw_file_for_baseline(project_root)
  testthat::skip_if_not(
    file.exists(raw_file),
    "Raw Retraction Watch data is not available in this checkout."
  )

  candidate_file <- file.path(
    project_root,
    "data/interim/mappings/reason_dictionary_candidate.csv"
  )
  reference_file <- file.path(
    project_root,
    "data/reference/mappings/reason_dictionary_v1.csv"
  )
  expect_true(file.exists(candidate_file))
  expect_true(file.exists(reference_file))

  candidate <- utils::read.csv(candidate_file, stringsAsFactors = FALSE)
  expect_equal(nrow(candidate), 112L)
  expect_equal(anyDuplicated(candidate$reason_label), 0L)
  expect_equal(
    digest::digest(file = reference_file, algo = "sha256"),
    "241a0a2f1401eeecb6d7795be12b3313f92adbe84924f5b9f2b4dc7bd388c910"
  )
})
