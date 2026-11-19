project_root_for_contract <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

test_that("required repository contract files exist", {
  project_root <- project_root_for_contract()
  required <- c(
    "README.md",
    "CONTEXT.md",
    "CONTRIBUTING.md",
    ".gitattributes",
    ".github/pull_request_template.md",
    "config/project.yml",
    "config/analysis.yml",
    "data/reference/mappings/rwdb_field_dictionary_v1.csv",
    "data/reference/mappings/reason_dictionary_v1.csv",
    "data/reference/mappings/reason_label_registry_v2.csv",
    "data/reference/mappings/reason_domain_map_v2.csv",
    "data/reference/mappings/reason_context_map_v2.csv",
    "data/reference/mappings/analysis_family_domains_v2.csv",
    "data/reference/mappings/institution_tier_aliases_v1.csv",
    "data/reference/mappings/institution_tier_registry_v1.csv",
    "data/reference/mappings/china_region_codes_v1.csv",
    "data/reference/mappings/provenance.json",
    "data/outputs/audits/manifest.json",
    "data/outputs/baseline/README.md",
    "data/outputs/baseline/manifest.json",
    "data/outputs/final/README.md",
    "data/outputs/app/README.md",
    "docs/decisions/0002-repository-file-contract.md",
    "docs/decisions/0007-institution-tier-year-versions.md",
    "docs/decisions/0008-control-matching-and-fallback.md",
    "docs/specs/README.md",
    "scripts/build_deliverables.R",
    "R/lib/file_hash.R",
    "R/lib/identity_keys.R",
    "R/00_setup.R",
    "R/01_ingest_rwdb.R",
    "R/02_build_doi_panel.R",
    "R/03_map_reasons.R",
    "R/04_screen_china.R",
    "R/05_fetch_openalex.R",
    "R/06_build_authorships.R",
    "R/06a_fetch_openalex_institutions.R",
    "R/06b_parse_openalex_institutions.R",
    "R/06c_fetch_institution_tier_sources.R",
    "R/06d_build_institution_tier_candidates.R",
    "R/06e_freeze_institution_tier_registry.R",
    "R/06f_enrich_institutions.R",
    "R/07a_build_control_strata.R",
    "R/07b_fetch_control_pools.R",
    "R/07c_parse_control_pools.R",
    "R/07d_match_controls_layer.R",
    "R/07e_fill_control_fallback.R",
    "R/07f_fetch_selected_controls.R",
    "R/07g_parse_selected_controls.R",
    "R/08_match_balance_audit.R",
    "R/09_build_networks.R",
    "R/13_event_2023.R",
    "R/90_baseline_eda.R",
    "scripts/run_match_balance_audit.R",
    "scripts/run_network_baseline.R",
    "scripts/run_event_2023.R",
    "docs/data/quality-audit.md",
    "docs/operations/analysis-todo.md",
    "docs/progress/current-status.md"
  )

  expect_true(all(file.exists(file.path(project_root, required))))
})

test_that("reason registry v2 is complete and internally consistent", {
  project_root <- project_root_for_contract()
  mapping_file <- file.path(
    project_root,
    "data/reference/mappings/reason_label_registry_v2.csv"
  )
  mapping <- utils::read.csv(
    mapping_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  allowed_statuses <- c(
    "substantive_finding",
    "concern_allegation",
    "error_unreliable",
    "insufficient_information",
    "not_applicable"
  )

  expect_equal(nrow(mapping), 112L)
  expect_equal(anyDuplicated(mapping$reason_label), 0L)
  expect_true(all(mapping$evidence_status %in% allowed_statuses))
  expect_setequal(unique(mapping$mapping_status), "reviewed")
  expect_setequal(unique(mapping$mapping_version), "2.0-frozen")
})

test_that("reason domain and context maps are valid many-to-many relations", {
  project_root <- project_root_for_contract()
  registry <- utils::read.csv(
    file.path(project_root, "data/reference/mappings/reason_label_registry_v2.csv"),
    stringsAsFactors = FALSE
  )
  domains <- utils::read.csv(
    file.path(project_root, "data/reference/mappings/reason_domain_map_v2.csv"),
    stringsAsFactors = FALSE
  )
  contexts <- utils::read.csv(
    file.path(project_root, "data/reference/mappings/reason_context_map_v2.csv"),
    stringsAsFactors = FALSE
  )
  families <- utils::read.csv(
    file.path(project_root, "data/reference/mappings/analysis_family_domains_v2.csv"),
    stringsAsFactors = FALSE
  )
  allowed_domains <- c(
    "publication_peer_review",
    "image_integrity",
    "data_results_integrity",
    "textual_reuse",
    "authorship_affiliation",
    "research_ethics_compliance",
    "materials_methods_integrity",
    "unspecified_integrity"
  )
  allowed_contexts <- c(
    "investigation",
    "legal",
    "administrative_status",
    "communication",
    "third_party",
    "external_complaint",
    "objection",
    "data_availability",
    "institutional_authorization",
    "metadata_limitation",
    "unclear"
  )

  expect_true(all(domains$reason_label %in% registry$reason_label))
  expect_true(all(domains$issue_domain %in% allowed_domains))
  expect_true(all(contexts$reason_label %in% registry$reason_label))
  expect_true(all(contexts$context_tag %in% allowed_contexts))
  expect_true(all(families$issue_domain %in% domains$issue_domain))
  expect_gt(sum(domains$reason_label == "Plagiarism of Image"), 1L)
  expect_equal(anyDuplicated(domains[c("reason_label", "issue_domain")]), 0L)
})

test_that("reference provenance hashes match frozen files", {
  project_root <- project_root_for_contract()
  source(file.path(project_root, "R/lib/file_hash.R"), encoding = "UTF-8")
  provenance_file <- file.path(
    project_root,
    "data/reference/mappings/provenance.json"
  )
  provenance <- jsonlite::read_json(provenance_file, simplifyVector = FALSE)

  for (item in provenance$files) {
    path <- file.path(project_root, item$path)
    expect_true(file.exists(path))
    expect_equal(
      sha256_canonical_file(path),
      item$sha256
    )
  }
})

test_that("canonical text hashes ignore checkout line endings", {
  project_root <- project_root_for_contract()
  source(file.path(project_root, "R/lib/file_hash.R"), encoding = "UTF-8")
  lf_file <- tempfile(fileext = ".csv")
  crlf_file <- tempfile(fileext = ".csv")

  writeBin(charToRaw("a,b\n1,2\n"), lf_file)
  writeBin(charToRaw("a,b\r\n1,2\r\n"), crlf_file)

  expect_equal(
    sha256_canonical_file(lf_file),
    sha256_canonical_file(crlf_file)
  )
  expect_false(identical(
    digest::digest(file = lf_file, algo = "sha256"),
    digest::digest(file = crlf_file, algo = "sha256")
  ))
})

test_that("outputs use phase-first structure", {
  project_root <- project_root_for_contract()
  expected_directories <- c(
    "data/outputs/audits/figures",
    "data/outputs/audits/tables",
    "data/outputs/baseline/tables",
    "data/outputs/baseline/figures",
    "data/outputs/final/tables",
    "data/outputs/final/figures",
    "data/outputs/final/models",
    "data/outputs/app",
    "data/outputs/app/tables"
  )
  legacy_directories <- c(
    "data/outputs/tables",
    "data/outputs/figures",
    "data/outputs/shiny"
  )

  expect_true(all(dir.exists(file.path(project_root, expected_directories))))
  expect_false(any(dir.exists(file.path(project_root, legacy_directories))))
})

test_that("baseline manifest uses project-relative paths", {
  project_root <- project_root_for_contract()
  manifest_file <- file.path(
    project_root,
    "data/outputs/baseline/manifest.json"
  )
  manifest <- jsonlite::read_json(manifest_file, simplifyVector = FALSE)

  expect_equal(manifest$contract_version, "1.0")
  expect_equal(manifest$mapping_version, "2.0-frozen")
  expect_equal(manifest$mapping_registry_labels, 112)
  expect_equal(manifest$mapping_unmapped_labels, 0)
  expect_equal(manifest$mapping_unmapped_core_records, 0)
  expect_equal(manifest$source_path_type, "project-relative")
  expect_equal(manifest$source_file, "data/raw/retractions.csv")
  expect_false(grepl("^([A-Za-z]:|/)", manifest$source_file))

  for (output in manifest$outputs) {
    expect_false(grepl("^([A-Za-z]:|/)", output$path))
  }
})

test_that("audit manifest hashes match frozen audit files", {
  project_root <- project_root_for_contract()
  source(file.path(project_root, "R/lib/file_hash.R"), encoding = "UTF-8")
  manifest_file <- file.path(project_root, "data/outputs/audits/manifest.json")
  manifest <- jsonlite::read_json(manifest_file, simplifyVector = FALSE)

  expect_equal(manifest$contract_version, "1.0")
  expect_equal(manifest$source_path_type, "project-relative")

  for (item in manifest$files) {
    path <- file.path(project_root, item$path)
    expect_true(file.exists(path))
    expect_equal(
      sha256_canonical_file(path),
      item$sha256
    )
  }
})

test_that("active Markdown links resolve", {
  project_root <- project_root_for_contract()
  markdown_files <- list.files(
    project_root,
    pattern = "\\.md$",
    recursive = TRUE,
    full.names = TRUE
  )
  markdown_files <- markdown_files[
    !grepl("[/\\\\]docs[/\\\\]archive[/\\\\]", markdown_files)
  ]

  broken <- character()
  for (file in markdown_files) {
    text <- paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    matches <- regmatches(
      text,
      gregexpr("\\[[^]]+\\]\\(([^)]+)\\)", text, perl = TRUE)
    )[[1]]
    if (identical(matches, character(0)) || identical(matches, "-1")) {
      next
    }
    for (match in matches) {
      target <- sub("^.*\\((.*)\\)$", "\\1", match)
      target <- sub("#.*$", "", target)
      if (target == "" || grepl("^(https?:|mailto:)", target)) {
        next
      }
      target <- utils::URLdecode(target)
      resolved <- file.path(dirname(file), target)
      if (!file.exists(resolved)) {
        broken <- c(
          broken,
          paste0(sub(paste0(project_root, "/?"), "", file), ": ", target)
        )
      }
    }
  }

  expect_equal(broken, character(0))
})
