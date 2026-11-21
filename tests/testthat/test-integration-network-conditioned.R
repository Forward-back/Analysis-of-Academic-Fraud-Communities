project_root_for_network_conditioned <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

read_network_conditioned_table <- function(project_root, filename) {
  utils::read.csv(
    file.path(project_root, "data/outputs/audits/tables", filename),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("P2 family-specific network excess is frozen", {
  project_root <- project_root_for_network_conditioned()
  effects <- read_network_conditioned_table(
    project_root,
    "p2_network_family_standardized_excess.csv"
  )

  expect_equal(nrow(effects), 8L)
  publication <- effects[
    effects$analysis_family == "family_publication_process",
    ,
    drop = FALSE
  ]
  expect_equal(publication$observed, 1357L)
  expect_equal(
    publication$observed_null_rate_ratio,
    2.15726921829593,
    tolerance = 1e-12
  )
  expect_equal(
    publication$excess_per_1000_pair_occurrences,
    15.4938702537034,
    tolerance = 1e-12
  )

  image <- effects[
    effects$analysis_family == "family_image_integrity",
    ,
    drop = FALSE
  ]
  expect_equal(
    image$excess_per_1000_pair_occurrences,
    23.7127649922884,
    tolerance = 1e-12
  )
  expect_gt(
    image$excess_per_1000_pair_occurrences,
    publication$excess_per_1000_pair_occurrences
  )
})

test_that("P2 family edge structure preserves repeat and cross-year shares", {
  project_root <- project_root_for_network_conditioned()
  structure <- read_network_conditioned_table(
    project_root,
    "p2_network_family_edge_structure.csv"
  )

  image <- structure[
    structure$analysis_family == "family_image_integrity",
    ,
    drop = FALSE
  ]
  expect_equal(image$unique_edges, 30242L)
  expect_equal(image$repeat_edges, 2625L)
  expect_equal(
    image$cross_year_repeat_share,
    0.597714285714286,
    tolerance = 1e-12
  )
})

test_that("P2 audit cluster profiles cover the frozen 25 clusters", {
  project_root <- project_root_for_network_conditioned()
  profiles <- read_network_conditioned_table(
    project_root,
    "p2_audit_cluster_profiles.csv"
  )
  summary <- read_network_conditioned_table(
    project_root,
    "p2_audit_cluster_portfolio_summary.csv"
  )
  summary_values <- setNames(summary$value, summary$metric)

  expect_equal(nrow(profiles), 25L)
  expect_equal(sum(profiles$authors), 375L)
  expect_equal(sum(profiles$profile_papers), 308L)
  expect_equal(
    unname(summary_values[["clusters_2023_share_above_25pct"]]),
    "2"
  )
  expect_equal(
    unname(summary_values[["clusters_top_publisher_above_50pct"]]),
    "16"
  )
})

test_that("P2 cluster family portfolio is explicit", {
  project_root <- project_root_for_network_conditioned()
  families <- read_network_conditioned_table(
    project_root,
    "p2_audit_cluster_family_counts.csv"
  )

  image_papers <- sum(
    families$papers[
      families$analysis_family == "family_image_integrity"
    ]
  )
  publication_papers <- sum(
    families$papers[
      families$analysis_family == "family_publication_process"
    ]
  )
  plagiarism_papers <- sum(
    families$papers[
      families$analysis_family == "family_plagiarism_authorship"
    ]
  )

  expect_equal(image_papers, 141L)
  expect_equal(publication_papers, 100L)
  expect_equal(plagiarism_papers, 72L)
})

test_that("P2 H3 status records metric dependence", {
  project_root <- project_root_for_network_conditioned()
  evidence <- read_network_conditioned_table(
    project_root,
    "p2_hypothesis_evidence.csv"
  )

  expect_equal(nrow(evidence), 1L)
  expect_equal(evidence$hypothesis, "H3")
  expect_equal(evidence$status, "partial_metric_dependent")
  expect_match(evidence$evidence, "highest observed/null ratio")
  expect_match(evidence$evidence, "highest excess per 1,000 pair")
})
