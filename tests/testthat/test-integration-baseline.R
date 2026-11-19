project_root_for_baseline <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

raw_file_for_baseline <- function(project_root) {
  file.path(project_root, "data/raw/retractions.csv")
}

test_that("raw data hash matches the frozen manifest", {
  project_root <- project_root_for_baseline()
  raw_file <- raw_file_for_baseline(project_root)
  testthat::skip_if_not(
    file.exists(raw_file),
    "Raw Retraction Watch data is not available in this checkout."
  )

  expect_equal(
    digest::digest(file = raw_file, algo = "sha256"),
    "eefbe08a9ecfa75308951fb7b03d265e9ccd8431eca32d9727b7ddc8c4b70faa"
  )
})

test_that("baseline quality output preserves core counts", {
  project_root <- project_root_for_baseline()
  raw_file <- raw_file_for_baseline(project_root)
  testthat::skip_if_not(
    file.exists(raw_file),
    "Raw Retraction Watch data is not available in this checkout."
  )

  quality_file <- file.path(
    project_root,
    "data/outputs/baseline/tables/data_quality_summary.csv"
  )
  expect_true(file.exists(quality_file))

  quality <- utils::read.csv(
    quality_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  values <- setNames(quality$value, quality$metric)

  expect_equal(unname(values[["total_notification_records"]]), "73597")
  expect_equal(unname(values[["retraction_records"]]), "68155")
  expect_equal(unname(values[["core_retraction_records_2012_2025"]]), "52638")
})

test_that("frozen reason registry covers all labels in raw data", {
  project_root <- project_root_for_baseline()
  raw_file <- raw_file_for_baseline(project_root)
  testthat::skip_if_not(
    file.exists(raw_file),
    "Raw Retraction Watch data is not available in this checkout."
  )

  raw <- data.table::fread(
    raw_file,
    colClasses = "character",
    check.names = FALSE,
    encoding = "UTF-8",
    data.table = FALSE
  )
  reason_labels <- unlist(
    strsplit(raw$Reason, ";", fixed = TRUE),
    use.names = FALSE
  )
  reason_labels <- trimws(reason_labels)
  reason_labels <- unique(reason_labels[reason_labels != ""])

  registry_file <- file.path(
    project_root,
    "data/reference/mappings/reason_label_registry_v2.csv"
  )
  registry <- utils::read.csv(registry_file, stringsAsFactors = FALSE)

  expect_equal(length(reason_labels), 112L)
  expect_setequal(reason_labels, registry$reason_label)
  expect_equal(
    digest::digest(file = registry_file, algo = "sha256"),
    "e106566b7f3c6169c30dbfa036d89885e58e53bec4110f41758b559a60e65370"
  )
})

test_that("network baseline and 2023 local decomposition are frozen", {
  project_root <- project_root_for_baseline()
  network_file <- file.path(
    project_root,
    "data/outputs/audits/tables/network_baseline_summary.csv"
  )
  network <- utils::read.csv(
    network_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  network_values <- setNames(network$value, network$metric)

  expect_equal(
    unname(network_values[["network_complete_papers"]]),
    14827L
  )
  expect_equal(unname(network_values[["nodes"]]), 46074L)
  expect_equal(unname(network_values[["unique_edges"]]), 111783L)
  expect_equal(unname(network_values[["repeat_edges"]]), 4587L)

  null_file <- file.path(
    project_root,
    "data/outputs/audits/tables/network_null_summary.csv"
  )
  null_summary <- utils::read.csv(
    null_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  null_values <- setNames(null_summary$value, null_summary$metric)
  expect_equal(as.integer(null_values[["permutations"]]), 1000L)
  expect_equal(as.integer(null_values[["observed_repeat_edges"]]), 4587L)
  expect_lt(null_values[["repeat_p_one_sided"]], 0.01)
  expect_gt(null_values[["repeat_z"]], 1)

  null_family_file <- file.path(
    project_root,
    "data/outputs/audits/tables/network_null_family_summary.csv"
  )
  null_family <- utils::read.csv(
    null_family_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_true(all(
    null_family$p_one_sided[
      null_family$analysis_family %in% c(
        "family_publication_process",
        "family_image_integrity",
        "family_plagiarism_authorship"
      )
    ] < 0.01
  ))

  cluster_file <- file.path(
    project_root,
    "data/outputs/audits/tables/audit_cluster_candidates.csv"
  )
  clusters <- utils::read.csv(
    cluster_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_equal(nrow(clusters), 38L)
  expect_equal(sum(clusters$selected %in% TRUE), 25L)
  expect_true(all(clusters$share_2023 <= 0.5))
  expect_true(all(clusters$excluding_2023_stability >= 0.5))
  expect_equal(anyDuplicated(clusters$component_id), 0L)

  final_cluster_file <- file.path(
    project_root,
    "data/outputs/audits/tables/audit_clusters_final_25.csv"
  )
  final_clusters <- utils::read.csv(
    final_cluster_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_equal(nrow(final_clusters), 25L)
  expect_equal(anyDuplicated(final_clusters$audit_cluster_id), 0L)

  event_file <- file.path(
    project_root,
    "data/outputs/audits/tables/event_2023_summary.csv"
  )
  event <- utils::read.csv(
    event_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  event_values <- setNames(event$value, event$metric)

  expect_equal(
    as.integer(event_values[["accepted_mainland_2023_papers"]]),
    10028L
  )

  publisher_file <- file.path(
    project_root,
    "data/outputs/audits/tables/event_2023_publisher.csv"
  )
  publishers <- utils::read.csv(
    publisher_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_equal(publishers$papers[publishers$publisher == "Hindawi"], 8036L)
})
