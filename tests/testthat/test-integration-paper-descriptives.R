project_root_for_paper_descriptives <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

read_paper_metric_table <- function(project_root, filename) {
  utils::read.csv(
    file.path(project_root, "data/outputs/audits/tables", filename),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("P1A paper panel flow is frozen", {
  project_root <- project_root_for_paper_descriptives()
  flow <- read_paper_metric_table(
    project_root,
    "p1a_analysis_panel_flow.csv"
  )
  flow_values <- setNames(flow$value, flow$metric)

  expect_equal(unname(flow_values[["matched_cases"]]), 22198L)
  expect_equal(unname(flow_values[["matched_controls"]]), 44287L)
  expect_equal(unname(flow_values[["analysis_panel_rows"]]), 66485L)
  expect_equal(
    unname(flow_values[["institution_comparable_cases"]]),
    12373L
  )
  expect_equal(
    unname(flow_values[["institution_comparable_controls"]]),
    24668L
  )
})

test_that("P1A family descriptives preserve key structural contrasts", {
  project_root <- project_root_for_paper_descriptives()
  comparison <- read_paper_metric_table(
    project_root,
    "p1a_family_structural_comparison.csv"
  )
  publication <- comparison[
    comparison$analysis_family == "family_publication_process",
    ,
    drop = FALSE
  ]
  expect_equal(publication$matched_cases, 12725L)
  expect_equal(publication$matched_controls, 25394L)
  expect_equal(
    publication$case_cross_tier_share,
    0.194318649650062,
    tolerance = 1e-12
  )
  expect_equal(
    publication$control_cross_tier_share,
    0.281232801320859,
    tolerance = 1e-12
  )
  expect_equal(
    publication$team_size_smd,
    -0.43098241713952,
    tolerance = 1e-12
  )

  image <- comparison[
    comparison$analysis_family == "family_image_integrity",
    ,
    drop = FALSE
  ]
  expect_equal(image$institution_cases, 1805L)
  expect_equal(
    image$case_single_city_share,
    0.640443213296399,
    tolerance = 1e-12
  )
  expect_equal(
    image$positive_distance_difference,
    -0.0601108033240997,
    tolerance = 1e-12
  )
})

test_that("P1A family sample selection keeps denominators explicit", {
  project_root <- project_root_for_paper_descriptives()
  selection <- read_paper_metric_table(
    project_root,
    "p1a_family_sample_selection.csv"
  )
  publication <- selection[
    selection$analysis_family == "family_publication_process",
    ,
    drop = FALSE
  ]

  expect_equal(publication$all_cases, 14644L)
  expect_equal(publication$matched_cases, 12725L)
  expect_equal(publication$institution_comparable_cases, 7287L)
  expect_equal(
    publication$institution_comparable_share,
    0.497609942638623,
    tolerance = 1e-12
  )
  expect_equal(
    publication$institution_mean_team_size,
    3.46342802250583,
    tolerance = 1e-12
  )
})
