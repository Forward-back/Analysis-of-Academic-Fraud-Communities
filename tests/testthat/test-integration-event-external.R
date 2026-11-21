project_root_for_event_external <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

read_event_external_table <- function(project_root, filename) {
  utils::read.csv(
    file.path(project_root, "data/outputs/audits/tables", filename),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("2023 external source coverage is frozen", {
  project_root <- project_root_for_event_external()
  validation <- read_event_external_table(
    project_root,
    "event_2023_external_validation.csv"
  )
  values <- setNames(validation$value, validation$metric)

  expect_equal(unname(values[["sources"]]), "10")
  expect_equal(unname(values[["claims"]]), "13")
  expect_equal(unname(values[["primary_sources"]]), "6")
  expect_equal(unname(values[["secondary_sources"]]), "4")
  expect_equal(unname(values[["sources_with_archive"]]), "2")
  expect_equal(unname(values[["local_hindawi_2023_papers"]]), "8036")
  expect_equal(unname(values[["largest_same_day_batch"]]), "465")
})

test_that("every external claim has a quote and local alignment", {
  project_root <- project_root_for_event_external()
  evidence <- read_event_external_table(
    project_root,
    "event_2023_external_evidence.csv"
  )
  quality <- read_event_external_table(
    project_root,
    "event_2023_external_claim_quality.csv"
  )

  expect_equal(nrow(evidence), 13L)
  expect_equal(sum(nzchar(evidence$quote_original)), 13L)
  expect_equal(sum(nzchar(evidence$local_alignment)), 13L)
  expect_true(all(quality$source_id_valid))
  expect_true(all(quality$url_present))
  expect_true(all(quality$has_boundary))
})

test_that("required 2023 governance claims are registered", {
  project_root <- project_root_for_event_external()
  evidence <- read_event_external_table(
    project_root,
    "event_2023_external_evidence.csv"
  )

  expect_true("C01" %in% evidence$claim_id)
  expect_match(
    evidence$quote_original[evidence$claim_id == "C01"],
    "closed four journals"
  )
  expect_match(
    evidence$quote_original[evidence$claim_id == "C04"],
    "1,200 compromised papers"
  )
  expect_match(
    evidence$quote_original[evidence$claim_id == "C09"],
    "over 8,000 articles"
  )
  expect_match(
    evidence$quote_original[evidence$claim_id == "C07"],
    "sunset the Hindawi brand"
  )
})

test_that("2023 counterfactual boundaries are explicit", {
  project_root <- project_root_for_event_external()
  boundaries <- read_event_external_table(
    project_root,
    "event_2023_counterfactual_boundaries.csv"
  )
  hypothesis <- read_event_external_table(
    project_root,
    "event_2023_hypothesis_evidence.csv"
  )

  expect_equal(nrow(boundaries), 6L)
  expect_true("B01" %in% boundaries$boundary_id)
  expect_true("B06" %in% boundaries$boundary_id)
  expect_equal(hypothesis$hypothesis, "H4")
  expect_equal(
    hypothesis$status,
    "supported_as_publisher_cleanup_event_not_national_incidence"
  )
})

test_that("2023 timeline links external actions and local batches", {
  project_root <- project_root_for_event_external()
  timeline <- read_event_external_table(
    project_root,
    "event_2023_external_timeline.csv"
  )

  expect_true(any(timeline$timeline_type == "external"))
  expect_true(any(timeline$timeline_type == "local_month"))
  expect_true(any(timeline$timeline_type == "local_same_day_batch"))
  expect_equal(
    timeline$count[
      timeline$timeline_type == "local_same_day_batch" &
        timeline$date == "2023-06-21"
    ],
    465L
  )
})
