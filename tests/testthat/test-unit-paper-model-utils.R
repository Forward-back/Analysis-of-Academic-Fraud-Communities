project_root_for_paper_models <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

test_that("paper team size bins keep zero and missing distinct", {
  project_root <- project_root_for_paper_models()
  source(
    file.path(project_root, "R", "lib", "paper_model_utils.R"),
    local = TRUE
  )

  result <- paper_team_size_bin(c(1, 5, 6, 10, 11, NA))
  expect_equal(
    as.character(result),
    c("1", "5", "6-10", "6-10", "11+", NA)
  )
  expect_equal(
    levels(result),
    c("1", "2", "3", "4", "5", "6-10", "11+")
  )
})

test_that("paper coefficient extraction reports odds ratios", {
  project_root <- project_root_for_paper_models()
  source(
    file.path(project_root, "R", "lib", "paper_model_utils.R"),
    local = TRUE
  )

  coefficients <- rbind(
    is_retractionTRUE = c(
      Estimate = log(0.7),
      `Std. Error` = 0.1,
      `z value` = -3.5667,
      `Pr(>|z|)` = 0.00036
    )
  )
  result <- paper_extract_coefficient(
    coefficients,
    "is_retractionTRUE"
  )

  expect_equal(result$estimate, log(0.7), tolerance = 1e-12)
  expect_equal(result$effect_ratio, 0.7, tolerance = 1e-12)
  expect_lt(result$ci_low, 0.7)
  expect_gt(result$ci_high, 0.7)
  expect_equal(result$p_value, 0.00036)
})

test_that("paper coefficient extraction accepts conditional logistic columns", {
  project_root <- project_root_for_paper_models()
  source(
    file.path(project_root, "R", "lib", "paper_model_utils.R"),
    local = TRUE
  )

  coefficients <- rbind(
    is_retractionTRUE = c(
      coef = log(0.8),
      `exp(coef)` = 0.8,
      `se(coef)` = 0.05,
      z = -4.46,
      `Pr(>|z|)` = 8e-06
    )
  )
  result <- paper_extract_coefficient(
    coefficients,
    "is_retractionTRUE"
  )

  expect_equal(result$effect_ratio, 0.8, tolerance = 1e-12)
  expect_equal(result$std_error, 0.05)
  expect_equal(result$p_value, 8e-06)
})
