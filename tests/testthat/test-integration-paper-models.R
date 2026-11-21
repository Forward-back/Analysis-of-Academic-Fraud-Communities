project_root_for_paper_models_integration <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

read_paper_model_table <- function(project_root, filename) {
  utils::read.csv(
    file.path(project_root, "data/outputs/audits/tables", filename),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("P1B primary binary models are complete and converged", {
  project_root <- project_root_for_paper_models_integration()
  fit <- read_paper_model_table(
    project_root,
    "p1b_binary_model_fit.csv"
  )
  primary <- fit[fit$analysis_set == "primary", , drop = FALSE]

  expect_equal(nrow(primary), 24L)
  expect_true(all(primary$status == "ok"))
  expect_true(all(primary$converged %in% TRUE))
  expect_equal(sum(primary$singular %in% TRUE), 0L)
})

test_that("P1B adjusted structural effects are frozen", {
  project_root <- project_root_for_paper_models_integration()
  effects <- read_paper_model_table(
    project_root,
    "p1b_binary_effects.csv"
  )

  publication_cross_tier <- effects[
    effects$analysis_set == "primary" &
      effects$analysis_family == "family_publication_process" &
      effects$outcome == "cross_tier" &
      effects$model_type == "primary_mixed",
    ,
    drop = FALSE
  ]
  expect_equal(
    publication_cross_tier$effect_ratio,
    0.663561171554733,
    tolerance = 1e-12
  )
  expect_lt(publication_cross_tier$ci_high, 1)
  expect_lt(publication_cross_tier$bh_fdr, 0.05)

  plagiarism_international <- effects[
    effects$analysis_set == "primary" &
      effects$analysis_family == "family_plagiarism_authorship" &
      effects$outcome == "international" &
      effects$model_type == "primary_mixed",
    ,
    drop = FALSE
  ]
  expect_equal(
    plagiarism_international$effect_ratio,
    2.18576364328003,
    tolerance = 1e-12
  )
  expect_gt(plagiarism_international$ci_low, 1)
})

test_that("P1B team-size and distance results preserve their scales", {
  project_root <- project_root_for_paper_models_integration()
  effects <- read_paper_model_table(
    project_root,
    "p1b_continuous_effects.csv"
  )

  publication_team <- effects[
    effects$analysis_set == "primary" &
      effects$analysis_family == "family_publication_process" &
      effects$model_type == "cluster_robust_negative_binomial",
    ,
    drop = FALSE
  ]
  expect_equal(
    publication_team$effect_ratio,
    0.782768817606821,
    tolerance = 1e-12
  )

  distance_models <- effects[
    effects$analysis_set == "primary" &
      effects$model_type == "positive_distance_lmer",
    ,
    drop = FALSE
  ]
  expect_equal(nrow(distance_models), 3L)
  expect_true(all(distance_models$ci_low < 1))
  expect_true(all(distance_models$ci_high > 1))
})

test_that("P1B hypothesis evidence does not overclaim H1", {
  project_root <- project_root_for_paper_models_integration()
  evidence <- read_paper_model_table(
    project_root,
    "p1b_hypothesis_evidence.csv"
  )

  expect_equal(
    evidence$status[evidence$hypothesis == "H1"],
    "not_supported_in_current_sample"
  )
  expect_equal(
    evidence$status[evidence$hypothesis == "H2"],
    "partial_support"
  )
  expect_equal(
    evidence$status[evidence$hypothesis == "H3"],
    "pending_network_conditional_models"
  )
})
