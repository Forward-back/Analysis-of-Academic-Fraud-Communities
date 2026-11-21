project_root_for_p1_integration <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

read_p1_metric_table <- function(project_root, filename) {
  utils::read.csv(
    file.path(project_root, "data/outputs/audits/tables", filename),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("P1 institution metadata and tier mappings are frozen", {
  project_root <- project_root_for_p1_integration()
  coverage <- read_p1_metric_table(
    project_root,
    "p1_institution_metadata_coverage.csv"
  )
  coverage_values <- setNames(coverage$value, coverage$metric)

  expect_equal(unname(coverage_values[["unique_institutions"]]), 5720L)
  expect_equal(unname(coverage_values[["with_ror"]]), 5720L)
  expect_equal(unname(coverage_values[["with_city"]]), 5720L)
  expect_equal(unname(coverage_values[["with_coordinates"]]), 5720L)

  tier_summary <- read_p1_metric_table(
    project_root,
    "p1_institution_tier_registry_summary.csv"
  )
  expect_equal(
    tier_summary$unique_institution_ids[
      tier_summary$tier_name == "985"
    ],
    39L
  )
  expect_equal(
    tier_summary$not_in_sample[
      tier_summary$tier_name == "double_first_class_2022"
    ],
    3L
  )
})

test_that("P1 region mapping has no unmatched mainland or HMT labels", {
  project_root <- project_root_for_p1_integration()
  region_audit <- read_p1_metric_table(
    project_root,
    "p1_region_mapping_audit.csv"
  )

  expect_equal(sum(!region_audit$mapped), 0L)
})

test_that("P1 control matching and fallback counts are frozen", {
  project_root <- project_root_for_p1_integration()
  fallback <- read_p1_metric_table(
    project_root,
    "p1_control_fallback_summary.csv"
  )
  fallback_values <- setNames(fallback$value, fallback$metric)

  expect_equal(
    unname(fallback_values[["cases_with_two_controls"]]),
    22089L
  )
  expect_equal(
    unname(fallback_values[["cases_with_one_control"]]),
    109L
  )
  expect_equal(
    unname(fallback_values[["cases_with_zero_controls"]]),
    2462L
  )
  expect_equal(
    unname(fallback_values[["publisher_fallback_links"]]),
    3813L
  )
  expect_equal(
    unname(fallback_values[["unique_control_works"]]),
    44287L
  )
})

test_that("P1 control completeness uses the full mainland analysis sample", {
  project_root <- project_root_for_p1_integration()
  integrity <- read_p1_metric_table(
    project_root,
    "p1_control_integrity_summary.csv"
  )
  integrity_values <- setNames(integrity$value, integrity$metric)

  expect_equal(
    unname(integrity_values[["main_sample_cases"]]),
    24974L
  )
  expect_equal(
    unname(integrity_values[["control_eligible_cases"]]),
    24660L
  )
  expect_equal(
    unname(integrity_values[["cases_without_stratum"]]),
    314L
  )
  expect_equal(
    unname(integrity_values[["main_sample_zero_controls"]]),
    2776L
  )
  expect_equal(
    unname(integrity_values[["cases_with_one_control"]]),
    109L
  )
  expect_equal(
    unname(integrity_values[["cases_with_two_controls"]]),
    22089L
  )
})

test_that("P1 selected control works are complete and non-retracted", {
  project_root <- project_root_for_p1_integration()
  parse_audit <- read_p1_metric_table(
    project_root,
    "p1_selected_control_parse_audit.csv"
  )
  parse_values <- setNames(parse_audit$value, parse_audit$metric)

  expect_equal(
    unname(parse_values[["requested_control_works"]]),
    44287L
  )
  expect_equal(
    unname(parse_values[["parsed_control_works"]]),
    44287L
  )
  expect_equal(unname(parse_values[["retracted_flagged"]]), 0L)
  expect_equal(unname(parse_values[["missing_case_key"]]), 0L)
  expect_equal(unname(parse_values[["confirmed_mainland"]]), 44287L)
})

test_that("P1 matching balance and institution metadata gaps are frozen", {
  project_root <- project_root_for_p1_integration()
  balance <- read_p1_metric_table(
    project_root,
    "match_balance_summary.csv"
  )
  balance_values <- setNames(balance$value, balance$metric)

  expect_equal(unname(balance_values[["control_links"]]), 44287L)
  expect_equal(unname(balance_values[["matched_cases"]]), 22198L)
  expect_equal(unname(balance_values[["year_match_rate"]]), 1)
  expect_equal(unname(balance_values[["type_mismatch_links"]]), 0L)
  expect_equal(
    unname(balance_values[["team_size_smd"]]),
    -0.306992447272884,
    tolerance = 1e-12
  )

  gap <- read_p1_metric_table(
    project_root,
    "control_institution_gap_summary.csv"
  )
  gap_values <- setNames(gap$value, gap$metric)

  expect_equal(unname(gap_values[["missing_institution_metadata"]]), 3767L)
  expect_equal(
    unname(gap_values[["control_works_with_missing_metadata"]]),
    4684L
  )
  expect_equal(unname(gap_values[["affected_matched_cases"]]), 4267L)

  validation <- utils::read.csv(
    file.path(
      project_root,
      "data/outputs/audits/tables/p1_post_fetch_link_validation.csv"
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_equal(nrow(validation), 1L)
  expect_equal(validation$control_rank, 2L)
  expect_false(validation$consistent)
})
