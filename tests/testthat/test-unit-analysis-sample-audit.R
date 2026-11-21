project_root_for_analysis_audit <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

test_that("analysis sample audit helpers ignore missing values and zero variance", {
  project_root <- project_root_for_analysis_audit()
  source(
    file.path(project_root, "R", "lib", "analysis_sample_audit.R"),
    local = TRUE
  )

  expect_equal(analysis_safe_rate(c(TRUE, FALSE, NA)), 0.5)
  expect_true(is.na(analysis_safe_rate(c(NA, NA))))
  expect_equal(
    analysis_standardized_mean_difference(c(1, 2, 3), c(2, 3, 4)),
    -1,
    tolerance = 1e-12
  )
  expect_true(is.na(
    analysis_standardized_mean_difference(c(1, 1, 1), c(2, 2, 2))
  ))
})

test_that("analysis group summaries retain family shares", {
  project_root <- project_root_for_analysis_audit()
  source(
    file.path(project_root, "R", "lib", "analysis_sample_audit.R"),
    local = TRUE
  )

  data <- data.frame(
    sample_group = c("a", "a", "b"),
    controls_matched = c(0L, 2L, 1L),
    source_present = c(TRUE, FALSE, TRUE),
    all_authors_have_institution = c(TRUE, TRUE, FALSE),
    network_complete = c(FALSE, TRUE, TRUE),
    any_control_metadata_gap = c(FALSE, TRUE, FALSE),
    publication_year = c(2020L, 2021L, 2022L),
    retraction_year_first = c(2021L, 2022L, 2023L),
    n_authorships = c(3L, 4L, 5L),
    family_test = c(TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
  result <- analysis_group_characteristics(
    data,
    "sample_group",
    "family_test"
  )
  result <- result[order(result$sample_group), , drop = FALSE]

  expect_equal(result$sample_group, c("a", "b"))
  expect_equal(result$cases, c(2L, 1L))
  expect_equal(result$zero_control_share, c(0.5, 0))
  expect_equal(result$family_test_share, c(0.5, 1))
})

test_that("analysis coverage counts the original rows in each group", {
  project_root <- project_root_for_analysis_audit()
  source(
    file.path(project_root, "R", "lib", "analysis_sample_audit.R"),
    local = TRUE
  )

  data <- data.frame(
    group = c("a", "a", "b", "b", "b"),
    included = c(TRUE, FALSE, TRUE, TRUE, FALSE),
    n_authorships = c(2L, 4L, 3L, 5L, 7L),
    stringsAsFactors = FALSE
  )
  result <- analysis_coverage_by_group(data, "group", "included")
  result <- result[order(result$group_value), , drop = FALSE]

  expect_equal(result$cases, c(2L, 3L))
  expect_equal(result$network_cases, c(1L, 2L))
  expect_equal(result$excluded_cases, c(1L, 1L))
  expect_equal(result$network_coverage, c(0.5, 2 / 3))
  expect_equal(result$included_mean_team_size, c(2, 4))
  expect_equal(result$excluded_mean_team_size, c(4, 7))
})
