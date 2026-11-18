project_root_for_p0_integration <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

read_p0_metric_table <- function(project_root, filename) {
  utils::read.csv(
    file.path(project_root, "data/outputs/audits/tables", filename),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("P0 outputs preserve the frozen source and DOI fold counts", {
  project_root <- project_root_for_p0_integration()
  ingest <- read_p0_metric_table(project_root, "p0_ingest_summary.csv")
  fold <- read_p0_metric_table(project_root, "p0_doi_fold_summary.csv")

  ingest_values <- setNames(ingest$value, ingest$metric)
  fold_values <- setNames(fold$value, fold$metric)

  expect_equal(unname(ingest_values[["notification_records"]]), "73597")
  expect_equal(unname(ingest_values[["retraction_records"]]), "68155")
  expect_equal(
    unname(ingest_values[["core_retraction_records"]]),
    "52638"
  )
  expect_equal(unname(fold_values[["unique_valid_dois"]]), 49294L)
  expect_equal(unname(fold_values[["linkable_papers"]]), 49291L)
  expect_equal(unname(fold_values[["ambiguous_doi_groups"]]), 3L)
  expect_equal(unname(fold_values[["ambiguous_doi_records"]]), 153L)
})

test_that("P0 China candidate screen retains the frozen candidate count", {
  project_root <- project_root_for_p0_integration()
  sample_flow <- read_p0_metric_table(project_root, "p0_sample_flow.csv")
  sample_values <- setNames(sample_flow$papers, sample_flow$stage)

  expect_equal(
    unname(sample_values[["china_candidate_descriptive"]]),
    26526L
  )
  expect_equal(
    unname(sample_values[["china_candidate_linkable"]]),
    26526L
  )
})

test_that("P0 audits expose DOI collisions and HMT co-labels", {
  project_root <- project_root_for_p0_integration()
  collisions <- read_p0_metric_table(
    project_root,
    "p0_doi_collision_audit.csv"
  )
  hmt <- read_p0_metric_table(
    project_root,
    "p0_hmt_country_label_audit.csv"
  )

  expect_equal(nrow(collisions), 3L)
  expect_equal(
    collisions$notification_records[
      collisions$doi_canonical == "10.1080/02699052.2023.2194723"
    ],
    145L
  )
  expect_true(all(hmt$china_candidate_papers > 0L))
})

test_that("P0 OpenAlex match and analysis subsets are frozen", {
  project_root <- project_root_for_p0_integration()
  match_summary <- read_p0_metric_table(
    project_root,
    "p0_openalex_match_summary.csv"
  )
  match_values <- setNames(match_summary$value, match_summary$metric)

  expect_equal(unname(match_values[["candidate_dois"]]), 26526L)
  expect_equal(unname(match_values[["exact_single_doi_matches"]]), 26497L)
  expect_equal(unname(match_values[["multiple_exact_matches"]]), 4L)
  expect_equal(unname(match_values[["not_found_dois"]]), 25L)
  expect_equal(unname(match_values[["openalex_confirmed_mainland"]]), 24978L)
  expect_equal(unname(match_values[["title_mismatch_excluded"]]), 4L)
  expect_equal(unname(match_values[["mainland_analysis_eligible"]]), 24974L)
  expect_equal(unname(match_values[["institution_complete_mainland"]]), 21842L)
  expect_equal(unname(match_values[["network_complete_mainland"]]), 14827L)
})

test_that("P0 title review flags a short manual-review list", {
  project_root <- project_root_for_p0_integration()
  title_summary <- read_p0_metric_table(
    project_root,
    "p0_openalex_title_review_summary.csv"
  )
  title_values <- setNames(title_summary$value, title_summary$metric)

  expect_equal(unname(title_values[["mainland_exact_works"]]), 24978L)
  expect_equal(unname(title_values[["title_jaccard_below_0_5"]]), 37L)
  expect_equal(unname(title_values[["title_containment_below_0_2"]]), 4L)
})
