project_root_for_model_robustness <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

read_robustness_table <- function(project_root, filename) {
  utils::read.csv(
    file.path(project_root, "data/outputs/audits/tables", filename),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("P1C robustness sample flow is frozen", {
  project_root <- project_root_for_model_robustness()
  flow <- read_robustness_table(
    project_root,
    "p1c_robustness_flow.csv"
  )
  flow_values <- setNames(flow$value, flow$metric)

  expect_equal(
    unname(flow_values[["shared_author_controls"]]),
    17979L
  )
  expect_equal(
    unname(flow_values[["groups_remaining_author_filtered"]]),
    17431L
  )
  expect_equal(
    unname(flow_values[["primary_institution_groups"]]),
    13168L
  )
  expect_equal(
    unname(flow_values[["top5_batch_groups_excluded"]]),
    1897L
  )
})

test_that("author overlap exclusion is reflected in core estimates", {
  project_root <- project_root_for_model_robustness()
  effects <- read_robustness_table(
    project_root,
    "p1c_sensitivity_effects.csv"
  )

  image_team <- effects[
    effects$analysis_set == "author_overlap_excluded" &
      effects$analysis_family == "family_image_integrity" &
      effects$outcome == "team_size",
    ,
    drop = FALSE
  ]
  expect_equal(
    image_team$effect_ratio,
    1.02837531560628,
    tolerance = 1e-12
  )
  expect_lt(image_team$ci_low, 1)
  expect_gt(image_team$ci_high, 1)

  publication_international <- effects[
    effects$analysis_set == "author_overlap_excluded" &
      effects$analysis_family == "family_publication_process" &
      effects$outcome == "international" &
      effects$model_type == "primary_mixed",
    ,
    drop = FALSE
  ]
  expect_equal(
    publication_international$effect_ratio,
    1.91601235747879,
    tolerance = 1e-12
  )
})

test_that("primary institution and fixed tier models are frozen", {
  project_root <- project_root_for_model_robustness()
  effects <- read_robustness_table(
    project_root,
    "p1c_sensitivity_effects.csv"
  )
  publication_cross_tier <- effects[
    effects$analysis_set == "primary_institution" &
      effects$analysis_family == "family_publication_process" &
      effects$outcome == "cross_tier" &
      effects$model_type == "primary_mixed",
    ,
    drop = FALSE
  ]
  expect_equal(
    publication_cross_tier$effect_ratio,
    0.732192149302767,
    tolerance = 1e-12
  )

  fixed_tier <- read_robustness_table(
    project_root,
    "p1c_fixed_tier_effects.csv"
  )
  expect_equal(nrow(fixed_tier), 6L)
  expect_true(all(fixed_tier$effect_ratio < 1))
  expect_true(all(fixed_tier$ci_high < 1))
})

test_that("team-size strata flag separation instead of ranking it", {
  project_root <- project_root_for_model_robustness()
  strata <- read_robustness_table(
    project_root,
    "p1c_team_size_strata_effects.csv"
  )

  expect_equal(
    sum(strata$effect_stability == "stable"),
    116L
  )
  expect_equal(
    sum(strata$effect_stability == "unstable_or_separation"),
    10L
  )
  expect_true(all(
    strata$effect_stability[
      is.infinite(strata$ci_high) |
        !is.finite(strata$effect_ratio)
    ] == "unstable_or_separation"
  ))
})

test_that("top five batch exclusion uses frozen Hindawi dates", {
  project_root <- project_root_for_model_robustness()
  batches <- read_robustness_table(
    project_root,
    "p1c_top5_batches.csv"
  )

  expect_equal(nrow(batches), 5L)
  expect_equal(
    as.character(batches$retraction_date),
    c(
      "2023-06-21",
      "2023-06-28",
      "2023-08-16",
      "2023-07-19",
      "2023-07-26"
    )
  )
  expect_true(all(batches$publisher == "Hindawi"))
})
