project_root_for_analysis_samples <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

read_analysis_metric_table <- function(project_root, filename) {
  utils::read.csv(
    file.path(project_root, "data/outputs/audits/tables", filename),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("analysis sample registry is frozen", {
  project_root <- project_root_for_analysis_samples()
  registry <- read_analysis_metric_table(
    project_root,
    "analysis_sample_registry.csv"
  )
  registry_values <- setNames(registry$cases, registry$sample_name)

  expect_equal(
    unname(registry_values[["descriptive_full"]]),
    24974L
  )
  expect_equal(
    unname(registry_values[["matched_any_control"]]),
    22198L
  )
  expect_equal(
    unname(registry_values[["matched_institution_compare"]]),
    12373L
  )
  expect_equal(
    unname(registry_values[["team_size_compare"]]),
    22198L
  )
  expect_equal(
    unname(registry_values[["network_complete"]]),
    14827L
  )
})

test_that("zero-control and control metadata selection are audited", {
  project_root <- project_root_for_analysis_samples()
  decomposition <- read_analysis_metric_table(
    project_root,
    "control_metadata_gap_decomposition.csv"
  )
  decomposition_values <- setNames(
    decomposition$value,
    decomposition$metric
  )

  expect_equal(
    unname(decomposition_values[["final_control_works"]]),
    44287L
  )
  expect_equal(
    unname(decomposition_values[["control_works_any_gap"]]),
    9342L
  )
  expect_equal(
    unname(decomposition_values[["matched_cases_any_gap"]]),
    8149L
  )
  expect_equal(
    unname(decomposition_values[["matched_cases_complete"]]),
    14049L
  )

  family_selection <- read_analysis_metric_table(
    project_root,
    "match_selection_by_family.csv"
  )
  publication <- family_selection[
    family_selection$analysis_family == "family_publication_process",
    ,
    drop = FALSE
  ]
  expect_equal(publication$cases, 14644L)
  expect_equal(publication$zero_control_cases, 1919L)

  image <- family_selection[
    family_selection$analysis_family == "family_image_integrity",
    ,
    drop = FALSE
  ]
  expect_equal(image$cases, 3319L)
  expect_equal(image$zero_control_cases, 23L)
})

test_that("network-complete selection differences are frozen", {
  project_root <- project_root_for_analysis_samples()
  metrics <- read_analysis_metric_table(
    project_root,
    "network_selection_metrics.csv"
  )
  metrics_values <- setNames(
    metrics$included_mean - metrics$excluded_mean,
    metrics$metric
  )

  expect_equal(
    unname(metrics_values[["n_authorships"]]),
    -1.87699639737752,
    tolerance = 1e-12
  )

  family_metrics <- read_analysis_metric_table(
    project_root,
    "network_selection_by_family.csv"
  )
  image <- family_metrics[
    family_metrics$analysis_family == "family_image_integrity",
    ,
    drop = FALSE
  ]
  expect_equal(image$network_cases, 1559L)
  expect_equal(image$network_coverage, 0.469719795119012, tolerance = 1e-12)
})
