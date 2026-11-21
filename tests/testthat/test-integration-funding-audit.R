project_root_for_funding_integration <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

read_funding_table <- function(project_root, filename) {
  utils::read.csv(
    file.path(project_root, "data/outputs/audits/tables", filename),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("P4 funding sample is frozen and cluster capped", {
  project_root <- project_root_for_funding_integration()
  sample <- read_funding_table(
    project_root,
    "funding_audit_sample.csv"
  )
  summary <- read_funding_table(
    project_root,
    "funding_audit_sample_summary.csv"
  )

  expect_equal(nrow(sample), 250L)
  expect_equal(length(unique(sample$paper_key)), 250L)
  expect_equal(length(unique(sample$audit_cluster_id)), 25L)
  expect_true(all(summary$sampled_papers <= 20L))
  expect_equal(sum(summary$sampled_papers), 250L)
  expect_true(all(summary$sampling_strata >= 1L))
})

test_that("P4 OpenAlex funding coverage is explicit", {
  project_root <- project_root_for_funding_integration()
  decision <- read_funding_table(
    project_root,
    "funding_audit_decision.csv"
  )
  group <- read_funding_table(
    project_root,
    "funding_audit_group_coverage.csv"
  )

  expect_equal(decision$sampled_papers, 250L)
  expect_equal(decision$funder_coverage, 0.624, tolerance = 1e-12)
  expect_equal(decision$award_coverage, 0.484, tolerance = 1e-12)
  expect_equal(
    group$any_funding_coverage[
      group$analysis_group == "matched_controls"
    ],
    0.67004048582996,
    tolerance = 1e-12
  )
})

test_that("P4 OpenAlex funder names are frozen", {
  project_root <- project_root_for_funding_integration()
  summary <- read_funding_table(
    project_root,
    "funding_funder_metadata_summary.csv"
  )
  values <- setNames(summary$value, summary$metric)
  reuse <- read_funding_table(
    project_root,
    "funding_funder_reuse_named.csv"
  )

  expect_equal(unname(values[["requested_funders"]]), "103")
  expect_equal(unname(values[["returned_funders"]]), "102")
  nsfc <- reuse[
    reuse$funder_name == "National Natural Science Foundation of China",
    ,
    drop = FALSE
  ]
  expect_equal(nsfc$papers, 117L)
  expect_equal(nsfc$clusters, 20L)
})

test_that("P4 Crossref supplement raises combined coverage above gate", {
  project_root <- project_root_for_funding_integration()
  combined <- read_funding_table(
    project_root,
    "funding_audit_combined_decision.csv"
  )
  request <- read_funding_table(
    project_root,
    "funding_crossref_summary.csv"
  )
  request_values <- setNames(request$value, request$metric)

  expect_equal(unname(request_values[["http_200"]]), 250)
  expect_equal(unname(request_values[["http_404"]]), 0)
  expect_equal(combined$combined_any_coverage, 0.652, tolerance = 1e-12)
  expect_equal(combined$combined_award_coverage, 0.524, tolerance = 1e-12)
  expect_match(combined$final_disposition, "eligible_for_main_analysis")
})

test_that("P4 repeated award numbers and H5 status are preserved", {
  project_root <- project_root_for_funding_integration()
  awards <- read_funding_table(
    project_root,
    "funding_crossref_award_reuse.csv"
  )
  evidence <- read_funding_table(
    project_root,
    "funding_hypothesis_evidence.csv"
  )

  expect_equal(max(awards$papers), 10L)
  expect_true(all(awards$clusters == 1L))
  expect_equal(evidence$hypothesis, "H5")
  expect_equal(
    evidence$status,
    "exploratory_support_pending_official_project_verification"
  )
  expect_match(evidence$evidence, "65.2%")

  queue <- read_funding_table(
    project_root,
    "funding_project_verification_queue.csv"
  )
  expect_equal(nrow(queue), 25L)
  expect_true(all(queue$verification_status == "pending"))
})
