project_root_for_funding_integration <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

read_funding_table <- function(project_root, filename) {
  utils::read.csv(
    file.path(project_root, "data/outputs/audits/tables", filename),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("P4 funding sample is frozen and cluster capped", {
  project_root <- project_root_for_funding_integration()
  sample <- read_funding_table(
    project_root,
    "funding_audit_sample.csv"
  )
  summary <- read_funding_table(
    project_root,
    "funding_audit_sample_summary.csv"
  )

  expect_equal(nrow(sample), 250L)
  expect_equal(length(unique(sample$paper_key)), 250L)
  expect_equal(length(unique(sample$audit_cluster_id)), 25L)
  expect_true(all(summary$sampled_papers <= 20L))
  expect_equal(sum(summary$sampled_papers), 250L)
  expect_true(all(summary$sampling_strata >= 1L))
})

test_that("P4 OpenAlex funding coverage is explicit", {
  project_root <- project_root_for_funding_integration()
  decision <- read_funding_table(
    project_root,
    "funding_audit_decision.csv"
  )
  group <- read_funding_table(
    project_root,
    "funding_audit_group_coverage.csv"
  )

  expect_equal(decision$sampled_papers, 250L)
  expect_equal(decision$funder_coverage, 0.624, tolerance = 1e-12)
  expect_equal(decision$award_coverage, 0.484, tolerance = 1e-12)
  expect_equal(
    group$any_funding_coverage[
      group$analysis_group == "matched_controls"
    ],
    0.67004048582996,
    tolerance = 1e-12
  )
})

test_that("P4 OpenAlex funder names are frozen", {
  project_root <- project_root_for_funding_integration()
  summary <- read_funding_table(
    project_root,
    "funding_funder_metadata_summary.csv"
  )
  values <- setNames(summary$value, summary$metric)
  reuse <- read_funding_table(
    project_root,
    "funding_funder_reuse_named.csv"
  )

  expect_equal(unname(values[["requested_funders"]]), "103")
  expect_equal(unname(values[["returned_funders"]]), "102")
  nsfc <- reuse[
    reuse$funder_name == "National Natural Science Foundation of China",
    ,
    drop = FALSE
  ]
  expect_equal(nsfc$papers, 117L)
  expect_equal(nsfc$clusters, 20L)
})

test_that("P4 Crossref supplement raises combined coverage above gate", {
  project_root <- project_root_for_funding_integration()
  combined <- read_funding_table(
    project_root,
    "funding_audit_combined_decision.csv"
  )
  request <- read_funding_table(
    project_root,
    "funding_crossref_summary.csv"
  )
  request_values <- setNames(request$value, request$metric)

  expect_equal(unname(request_values[["http_200"]]), 250)
  expect_equal(unname(request_values[["http_404"]]), 0)
  expect_equal(combined$combined_any_coverage, 0.652, tolerance = 1e-12)
  expect_equal(combined$combined_award_coverage, 0.524, tolerance = 1e-12)
  expect_match(combined$final_disposition, "eligible_for_main_analysis")
})

test_that("P4 repeated award numbers and H5 status are preserved", {
  project_root <- project_root_for_funding_integration()
  awards <- read_funding_table(
    project_root,
    "funding_crossref_award_reuse.csv"
  )
  evidence <- read_funding_table(
    project_root,
    "funding_hypothesis_evidence.csv"
  )

  expect_equal(max(awards$papers), 10L)
  expect_true(all(awards$clusters == 1L))
  expect_equal(evidence$hypothesis, "H5")
  expect_equal(
    evidence$status,
    "exploratory_support_pending_official_project_verification"
  )
  expect_match(evidence$evidence, "65.2%")

  queue <- read_funding_table(
    project_root,
    "funding_project_verification_queue.csv"
  )
  expect_equal(nrow(queue), 25L)
  expect_true(all(queue$verification_status == "pending"))
})

test_that("P4B source-symmetric comparison is frozen and disjoint", {
  project_root <- project_root_for_funding_integration()
  comparison <- read_funding_table(
    project_root,
    "funding_source_symmetric_comparison_works.csv"
  )

  expect_equal(nrow(comparison), 831L)
  expect_equal(length(unique(comparison$doi_canonical)), 831L)
  expect_equal(anyDuplicated(comparison$doi_canonical), 0L)
  counts <- table(comparison$group)
  expect_equal(
    unname(counts[[
      "selected_cluster_sample"
    ]]),
    250L
  )
  expect_equal(
    unname(counts[["matched_controls"]]),
    494L
  )
  expect_equal(
    unname(counts[[
      "unselected_candidate_clusters"
    ]]),
    87L
  )
})

test_that("P4B source-symmetric coverage and agreement are complete", {
  project_root <- project_root_for_funding_integration()
  coverage <- read_funding_table(
    project_root,
    "funding_source_symmetric_group_coverage.csv"
  )
  agreement <- read_funding_table(
    project_root,
    "funding_source_symmetric_agreement.csv"
  )
  request <- read_funding_table(
    project_root,
    "funding_source_symmetric_request_summary.csv"
  )
  request_values <- setNames(request$value, request$metric)

  selected <- coverage[
    coverage$analysis_group == "selected_cluster_sample",
    ,
    drop = FALSE
  ]
  controls <- coverage[
    coverage$analysis_group == "matched_controls",
    ,
    drop = FALSE
  ]
  unselected <- coverage[
    coverage$analysis_group == "unselected_candidate_clusters",
    ,
    drop = FALSE
  ]
  expect_equal(selected$union_any_coverage, 0.652, tolerance = 1e-12)
  expect_equal(
    controls$union_any_coverage,
    0.684210526315789,
    tolerance = 1e-12
  )
  expect_equal(
    unselected$union_any_coverage,
    0.344827586206897,
    tolerance = 1e-12
  )
  expect_equal(selected$union_any_papers, 163L)
  expect_equal(controls$union_any_papers, 338L)
  expect_equal(unselected$union_any_papers, 30L)
  expect_equal(unname(request_values[["unique_dois"]]), 831)
  expect_equal(unname(request_values[["http_200"]]), 831)
  expect_equal(unname(request_values[["http_404"]]), 0)
  expect_equal(
    unname(request_values[["network_or_json_failures"]]),
    0
  )
  expect_equal(
    agreement$both_sources[
      agreement$analysis_group == "selected_cluster_sample"
    ],
    88L
  )
  expect_equal(
    agreement$openalex_only[
      agreement$analysis_group == "selected_cluster_sample"
    ],
    68L
  )
  expect_equal(
    agreement$crossref_only[
      agreement$analysis_group == "selected_cluster_sample"
    ],
    7L
  )
  expect_equal(
    agreement$neither_source[
      agreement$analysis_group == "selected_cluster_sample"
    ],
    87L
  )
})

test_that("P4B official verification preserves unresolved boundaries", {
  project_root <- project_root_for_funding_integration()
  verification <- read_funding_table(
    project_root,
    "funding_official_project_verification.csv"
  )

  expect_equal(nrow(verification), 25L)
  status <- table(verification$official_verification_status)
  expect_equal(
    unname(status[[
      "officially_verified_completion_record"
    ]]),
    10L
  )
  expect_equal(
    unname(status[[
      "not_found_in_nsfc_completion_database"
    ]]),
    7L
  )
  expect_equal(
    unname(status[[
      "not_found_in_public_official_project_search"
    ]]),
    8L
  )
  verified <- verification[
    verification$official_verification_status ==
      "officially_verified_completion_record",
    ,
    drop = FALSE
  ]
  expect_true(all(verified$amount_status == "officially_verified"))
  expect_true(all(!is.na(verified$amount)))
  expect_true(all(verified$currency == "CNY"))
  expect_true(all(is.na(verification$start_year)))
  expect_true(all(is.na(verification$end_year)))
  expect_true(all(nzchar(verification$official_record_url)))
  expect_true(all(nzchar(verification$official_supporting_text)))
})

test_that("P4B award-level DOI evidence supports H5 boundaries", {
  project_root <- project_root_for_funding_integration()
  evidence <- read_funding_table(
    project_root,
    "funding_project_paper_evidence.csv"
  )
  hypothesis <- read_funding_table(
    project_root,
    "funding_h5_final_evidence.csv"
  )

  expect_gt(nrow(evidence), 200L)
  expect_equal(length(unique(evidence$doi_canonical)), 85L)
  verified <- evidence[
    evidence$official_verification_status ==
      "officially_verified_completion_record",
    ,
    drop = FALSE
  ]
  expect_equal(length(unique(verified$doi_canonical)), 26L)
  expect_equal(length(unique(verified$audit_cluster_id)), 3L)
  expect_equal(hypothesis$selected_union_any_coverage, 0.652)
  expect_equal(
    hypothesis$matched_control_union_any_coverage,
    0.684210526315789,
    tolerance = 1e-12
  )
  expect_equal(hypothesis$officially_verified_awards, 10L)
  expect_equal(hypothesis$verification_queue_awards, 25L)
  expect_equal(hypothesis$cross_cluster_award_reuse, 0L)
  expect_match(
    hypothesis$status,
    "partial_official_verification"
  )
})

test_that("P4B official and figure manifests resolve hashes", {
  project_root <- project_root_for_funding_integration()
  source(file.path(project_root, "R", "lib", "file_hash.R"))

  official_manifest <- jsonlite::read_json(
    file.path(
      project_root,
      "data/external/snapshots/funding_official_verification_v1/manifest.json"
    ),
    simplifyVector = FALSE
  )
  expect_equal(length(official_manifest$files), 17L)
  for (item in official_manifest$files) {
    path <- file.path(project_root, as.character(item$path))
    expect_true(file.exists(path))
    expect_equal(
      sha256_canonical_file(path),
      as.character(item$sha256)
    )
  }

  figure_manifest <- jsonlite::read_json(
    file.path(
      project_root,
      "data/outputs/audits/figures/funding_figures_metadata.json"
    ),
    simplifyVector = FALSE
  )
  expect_equal(length(figure_manifest$figures), 3L)
  for (figure in figure_manifest$figures) {
    table_path <- file.path(
      project_root,
      as.character(figure$table_fallback)
    )
    expect_true(file.exists(table_path))
    expect_equal(
      sha256_canonical_file(table_path),
      as.character(figure$data_sha256)
    )
    for (output in figure$outputs) {
      path <- file.path(project_root, as.character(output$path))
      expect_true(file.exists(path))
      expect_equal(
        digest::digest(file = path, algo = "sha256"),
        as.character(output$sha256)
      )
    }
  }
})
