#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/funding_audit.R", encoding = "UTF-8")

refresh <- "--refresh" %in% commandArgs(trailingOnly = TRUE)

final_clusters <- utils::read.csv(
  file.path(audit_table_dir, "audit_clusters_final_25.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
candidate_clusters <- utils::read.csv(
  file.path(audit_table_dir, "audit_cluster_candidates.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
component_membership <- readRDS(file.path(
  processed_dir,
  "p1",
  "repeat_component_membership.rds"
))
network_panel <- readRDS(file.path(
  processed_dir,
  "p0",
  "openalex_mainland_network_complete_paper_panel.rds"
))
authorships_long <- readRDS(file.path(
  processed_dir,
  "p0",
  "mainland_authorships_long.rds"
))
paper_panel <- readRDS(file.path(
  processed_dir,
  "p1",
  "analysis_paper_panel.rds"
))$paper_panel
control_works <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_works_full.rds"
))
selected <- utils::read.csv(
  file.path(audit_table_dir, "funding_audit_sample.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

assert_columns(
  selected,
  c(
    "audit_cluster_id",
    "paper_key",
    "doi_canonical",
    "openalex_work_id",
    "original_paper_year_first",
    "publisher",
    "funders_present",
    "awards_present",
    "any_funding_metadata"
  ),
  "selected funding sample"
)
assert_columns(
  control_works,
  c(
    "openalex_work_id",
    "case_paper_key",
    "doi_canonical",
    "publication_year",
    "publisher_name",
    "funders_present",
    "awards_present"
  ),
  "control works"
)

network_authors <- data.table::as.data.table(authorships_long)
network_authors <- network_authors[
  paper_key %in% network_panel$paper_key &
    !is.na(author_id) &
    author_id != "",
  .(paper_key, author_id)
]
network_authors <- unique(network_authors)
paper_authors <- merge(
  as.data.frame(network_authors),
  as.data.frame(component_membership),
  by = "author_id",
  all.x = FALSE,
  sort = FALSE
)
paper_authors <- paper_authors[
  paper_authors$component_id %in% candidate_clusters$component_id,
  ,
  drop = FALSE
]
paper_component_counts <- data.table::as.data.table(paper_authors)[
  ,
  .(cluster_member_count = .N),
  by = .(paper_key, component_id)
]
paper_component_counts <- as.data.frame(
  paper_component_counts[cluster_member_count >= 2L]
)

audit_cluster_map <- setNames(
  final_clusters$audit_cluster_id,
  final_clusters$component_id
)
paper_component_counts$audit_cluster_id <- unname(
  audit_cluster_map[as.character(paper_component_counts$component_id)]
)

paper_columns <- c(
  "paper_key",
  "doi_canonical",
  "retraction_year_first",
  "original_paper_year_first",
  "publisher",
  "field_id",
  "openalex_work_id",
  "funders_present",
  "awards_present",
  "funder_ids",
  "award_ids"
)
candidate_paper_pool <- merge(
  paper_component_counts,
  network_panel[, paper_columns, drop = FALSE],
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)
unselected_pool <- candidate_paper_pool[
  is.na(candidate_paper_pool$audit_cluster_id) &
    !candidate_paper_pool$paper_key %in% selected$paper_key,
  ,
  drop = FALSE
]
unselected_pool <- unselected_pool[
  !duplicated(unselected_pool$paper_key),
  ,
  drop = FALSE
]

sample_case_groups <- unique(paper_panel$match_group[
  paper_panel$is_retraction &
    paper_panel$case_paper_key %in% selected$paper_key
])
matched_control_ids <- unique(paper_panel$openalex_work_id[
  !paper_panel$is_retraction &
    paper_panel$match_group %in% sample_case_groups
])
matched_controls <- control_works[
  control_works$openalex_work_id %in% matched_control_ids,
  ,
  drop = FALSE
]
selected_cluster_lookup <- setNames(
  selected$audit_cluster_id,
  selected$paper_key
)
matched_controls$audit_cluster_id <- unname(
  selected_cluster_lookup[matched_controls$case_paper_key]
)

selected_comparison <- data.frame(
  group = "selected_cluster_sample",
  record_id = paste("selected", selected$paper_key, sep = ":"),
  paper_key = selected$paper_key,
  openalex_work_id = selected$openalex_work_id,
  doi_canonical = selected$doi_canonical,
  audit_cluster_id = selected$audit_cluster_id,
  case_paper_key = selected$paper_key,
  publication_year = selected$original_paper_year_first,
  publisher = selected$publisher,
  oa_funder_present = selected$funders_present %in% TRUE,
  oa_award_present = selected$awards_present %in% TRUE,
  oa_any_funding = selected$any_funding_metadata %in% TRUE,
  stringsAsFactors = FALSE
)

control_comparison <- data.frame(
  group = "matched_controls",
  record_id = paste(
    "control",
    matched_controls$openalex_work_id,
    sep = ":"
  ),
  paper_key = NA_character_,
  openalex_work_id = matched_controls$openalex_work_id,
  doi_canonical = matched_controls$doi_canonical,
  audit_cluster_id = matched_controls$audit_cluster_id,
  case_paper_key = matched_controls$case_paper_key,
  publication_year = matched_controls$publication_year,
  publisher = matched_controls$publisher_name,
  oa_funder_present = matched_controls$funders_present %in% TRUE,
  oa_award_present = matched_controls$awards_present %in% TRUE,
  oa_any_funding =
    matched_controls$funders_present %in% TRUE |
    matched_controls$awards_present %in% TRUE,
  stringsAsFactors = FALSE
)

unselected_comparison <- data.frame(
  group = "unselected_candidate_clusters",
  record_id = paste("unselected", unselected_pool$paper_key, sep = ":"),
  paper_key = unselected_pool$paper_key,
  openalex_work_id = unselected_pool$openalex_work_id,
  doi_canonical = unselected_pool$doi_canonical,
  audit_cluster_id = NA_character_,
  case_paper_key = unselected_pool$paper_key,
  publication_year = unselected_pool$original_paper_year_first,
  publisher = unselected_pool$publisher,
  oa_funder_present = unselected_pool$funders_present %in% TRUE,
  oa_award_present = unselected_pool$awards_present %in% TRUE,
  oa_any_funding =
    unselected_pool$funders_present %in% TRUE |
    unselected_pool$awards_present %in% TRUE,
  stringsAsFactors = FALSE
)

comparison <- rbind(
  selected_comparison,
  control_comparison,
  unselected_comparison
)
comparison$doi_canonical <- normalize_doi(comparison$doi_canonical)
comparison$doi_available <- !is.na(comparison$doi_canonical)
comparison <- comparison[
  order(comparison$group, comparison$record_id),
  ,
  drop = FALSE
]

expected_counts <- c(
  selected_cluster_sample = 250L,
  matched_controls = 494L,
  unselected_candidate_clusters = 87L
)
observed_counts <- table(comparison$group)
if (!identical(
  as.integer(observed_counts[names(expected_counts)]),
  unname(expected_counts)
)) {
  stop(
    "Source-symmetric comparison counts changed: ",
    paste(names(observed_counts), observed_counts, collapse = ", ")
  )
}
if (anyDuplicated(comparison$record_id)) {
  stop("Comparison record IDs must be unique.")
}

comparison_path <- file.path(
  audit_table_dir,
  "funding_source_symmetric_comparison_works.csv"
)
write_csv_utf8(comparison, comparison_path)

snapshot_dir <- file.path(
  project_dir,
  "data",
  "external",
  "snapshots",
  "funding_source_symmetric_v1"
)
ensure_dir(snapshot_dir)
jsonlite::write_json(
  list(
    contract_version = "1.0",
    artifact = "funding-source-symmetric-comparison-v1",
    frozen_on = as.character(Sys.Date()),
    groups = as.list(expected_counts),
    files = list(
      list(
        path = project_relative_path(comparison_path),
        sha256 = sha256_canonical_file(comparison_path)
      )
    )
  ),
  file.path(snapshot_dir, "frozen_comparison_manifest.json"),
  auto_unbox = TRUE,
  pretty = TRUE
)

cache_root <- file.path(
  project_dir,
  project_config$paths$cache,
  "crossref",
  "funding-audit-v1",
  "works"
)
metadata_root <- file.path(cache_root, "metadata")
ensure_dir(cache_root)
ensure_dir(metadata_root)
mailto <- Sys.getenv("CROSSREF_MAILTO")

doi_records <- unique(comparison[
  comparison$doi_available,
  c("doi_canonical"),
  drop = FALSE
])
request_rows <- list()
paper_rows <- list()
funder_rows <- list()
award_rows <- list()

for (index in seq_len(nrow(doi_records))) {
  doi <- doi_records$doi_canonical[[index]]
  doi_key <- doi_environment_key(doi)
  content_path <- file.path(cache_root, paste0(doi_key, ".json"))
  metadata_path <- file.path(
    metadata_root,
    paste0(doi_key, ".json")
  )

  if (refresh || !file.exists(content_path) || !file.exists(metadata_path)) {
    encoded_doi <- utils::URLencode(doi, reserved = TRUE)
    response <- NULL
    error_message <- ""
    for (attempt in seq_len(3L)) {
      response <- tryCatch(
        httr::GET(
          paste0("https://api.crossref.org/works/", encoded_doi),
          query = if (nzchar(mailto)) list(mailto = mailto) else list(),
          httr::user_agent("RetractionResourceNetwork/1.0")
        ),
        error = function(error) error
      )
      if (!inherits(response, "error")) {
        break
      }
      error_message <- conditionMessage(response)
      Sys.sleep(attempt)
    }
    if (inherits(response, "error")) {
      metadata <- list(
        doi = doi,
        http_status = NA_integer_,
        json_valid = FALSE,
        error = error_message,
        requested_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
      )
      writeLines("", content_path, useBytes = TRUE)
    } else {
      status <- httr::status_code(response)
      content_text <- httr::content(response, as = "text", encoding = "UTF-8")
      metadata <- list(
        doi = doi,
        http_status = status,
        json_valid = jsonlite::validate(content_text),
        error = "",
        requested_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
      )
      writeLines(content_text, content_path, useBytes = TRUE)
    }
    jsonlite::write_json(
      metadata,
      metadata_path,
      auto_unbox = TRUE,
      pretty = TRUE
    )
    Sys.sleep(0.1)
  }

  metadata <- jsonlite::read_json(metadata_path, simplifyVector = FALSE)
  content_text <- paste(readLines(content_path, warn = FALSE), collapse = "\n")
  parsed <- if (isTRUE(metadata$json_valid) && nzchar(content_text)) {
    tryCatch(
      jsonlite::fromJSON(content_text, simplifyVector = FALSE),
      error = function(error) NULL
    )
  } else {
    NULL
  }
  funders <- parsed$message$funder
  if (is.null(funders)) {
    funders <- list()
  }

  funder_names <- character()
  funder_dois <- character()
  award_numbers <- character()
  for (funder in funders) {
    funder_name <- if (is.null(funder$name)) "" else funder$name
    funder_doi <- if (is.null(funder$DOI)) "" else funder$DOI
    if (nzchar(funder_name)) {
      funder_names <- c(funder_names, funder_name)
    }
    if (nzchar(funder_doi)) {
      funder_dois <- c(funder_dois, funder_doi)
    }
    awards <- unlist(funder$award, use.names = FALSE)
    awards <- unique(as.character(awards[!is.na(awards) & awards != ""]))
    if (length(awards) > 0L) {
      award_numbers <- c(award_numbers, awards)
      for (award in awards) {
        award_rows[[length(award_rows) + 1L]] <- data.frame(
          doi_canonical = doi,
          award_number = award,
          funder_name = funder_name,
          funder_doi = funder_doi,
          stringsAsFactors = FALSE
        )
      }
    }
    if (nzchar(funder_name) || nzchar(funder_doi)) {
      funder_rows[[length(funder_rows) + 1L]] <- data.frame(
        doi_canonical = doi,
        funder_name = funder_name,
        funder_doi = funder_doi,
        funder_key = if (nzchar(funder_doi)) {
          funder_doi
        } else {
          paste0("name:", funder_name)
        },
        stringsAsFactors = FALSE
      )
    }
  }
  paper_rows[[length(paper_rows) + 1L]] <- data.frame(
    doi_canonical = doi,
    crossref_http_status = if (is.null(metadata$http_status)) {
      NA_integer_
    } else {
      as.integer(metadata$http_status)
    },
    crossref_json_valid = isTRUE(metadata$json_valid),
    crossref_funder_present = length(unique(funder_names)) > 0L ||
      length(unique(funder_dois)) > 0L,
    crossref_award_present = length(unique(award_numbers)) > 0L,
    crossref_funder_names = paste(
      sort(unique(funder_names)),
      collapse = ";"
    ),
    crossref_funder_dois = paste(
      sort(unique(funder_dois)),
      collapse = ";"
    ),
    crossref_award_numbers = paste(
      sort(unique(award_numbers)),
      collapse = ";"
    ),
    stringsAsFactors = FALSE
  )
  request_rows[[length(request_rows) + 1L]] <- data.frame(
    doi_canonical = doi,
    http_status = if (is.null(metadata$http_status)) {
      NA_integer_
    } else {
      as.integer(metadata$http_status)
    },
    json_valid = isTRUE(metadata$json_valid),
    error = if (is.null(metadata$error)) "" else metadata$error,
    stringsAsFactors = FALSE
  )
  if (index %% 50L == 0L || index == nrow(doi_records)) {
    message("Crossref source-symmetric ", index, "/", nrow(doi_records))
  }
}

crossref_papers <- as.data.frame(data.table::rbindlist(
  paper_rows,
  fill = TRUE
))
request_audit <- as.data.frame(data.table::rbindlist(
  request_rows,
  fill = TRUE
))
crossref_funders <- as.data.frame(data.table::rbindlist(
  funder_rows,
  fill = TRUE
))
crossref_awards <- as.data.frame(data.table::rbindlist(
  award_rows,
  fill = TRUE
))

combined <- merge(
  comparison,
  crossref_papers,
  by = "doi_canonical",
  all.x = TRUE,
  sort = FALSE
)
combined$crossref_funder_present[
  is.na(combined$crossref_funder_present)
] <- FALSE
combined$crossref_award_present[
  is.na(combined$crossref_award_present)
] <- FALSE
combined$crossref_any_funding <-
  combined$crossref_funder_present |
  combined$crossref_award_present
combined$union_funder_present <-
  combined$oa_funder_present |
  combined$crossref_funder_present
combined$union_award_present <-
  combined$oa_award_present |
  combined$crossref_award_present
combined$union_any_funding <-
  combined$oa_any_funding |
  combined$crossref_any_funding

wilson_interval <- function(successes, total, z = qnorm(0.975)) {
  if (total == 0L) {
    return(c(low = NA_real_, high = NA_real_))
  }
  p <- successes / total
  denominator <- 1 + z^2 / total
  center <- (p + z^2 / (2 * total)) / denominator
  half <- z * sqrt(
    p * (1 - p) / total + z^2 / (4 * total^2)
  ) / denominator
  c(low = center - half, high = center + half)
}

coverage_rows <- list()
agreement_rows <- list()
for (group_name in names(expected_counts)) {
  group <- combined[combined$group == group_name, , drop = FALSE]
  interval <- wilson_interval(
    sum(group$union_any_funding),
    nrow(group)
  )
  coverage_rows[[length(coverage_rows) + 1L]] <- data.frame(
    analysis_group = group_name,
    papers = nrow(group),
    doi_available = sum(group$doi_available),
    oa_funder_papers = sum(group$oa_funder_present),
    oa_award_papers = sum(group$oa_award_present),
    oa_any_papers = sum(group$oa_any_funding),
    crossref_funder_papers = sum(group$crossref_funder_present),
    crossref_award_papers = sum(group$crossref_award_present),
    crossref_any_papers = sum(group$crossref_any_funding),
    union_funder_papers = sum(group$union_funder_present),
    union_award_papers = sum(group$union_award_present),
    union_any_papers = sum(group$union_any_funding),
    oa_funder_coverage = mean(group$oa_funder_present),
    oa_award_coverage = mean(group$oa_award_present),
    oa_any_coverage = mean(group$oa_any_funding),
    crossref_funder_coverage = mean(group$crossref_funder_present),
    crossref_award_coverage = mean(group$crossref_award_present),
    crossref_any_coverage = mean(group$crossref_any_funding),
    union_funder_coverage = mean(group$union_funder_present),
    union_award_coverage = mean(group$union_award_present),
    union_any_coverage = mean(group$union_any_funding),
    union_any_ci_low = interval[["low"]],
    union_any_ci_high = interval[["high"]],
    stringsAsFactors = FALSE
  )
  agreement_rows[[length(agreement_rows) + 1L]] <- data.frame(
    analysis_group = group_name,
    papers = nrow(group),
    both_sources = sum(
      group$oa_any_funding & group$crossref_any_funding
    ),
    openalex_only = sum(
      group$oa_any_funding & !group$crossref_any_funding
    ),
    crossref_only = sum(
      !group$oa_any_funding & group$crossref_any_funding
    ),
    neither_source = sum(
      !group$oa_any_funding & !group$crossref_any_funding
    ),
    stringsAsFactors = FALSE
  )
}
group_coverage <- as.data.frame(data.table::rbindlist(
  coverage_rows,
  fill = TRUE
))
source_agreement <- as.data.frame(data.table::rbindlist(
  agreement_rows,
  fill = TRUE
))

cluster_rows <- list()
for (group_name in c(
  "selected_cluster_sample",
  "matched_controls"
)) {
  group <- combined[
    combined$group == group_name &
      !is.na(combined$audit_cluster_id),
    ,
    drop = FALSE
  ]
  cluster_summary <- data.table::as.data.table(group)[
    ,
    .(
      papers = .N,
      oa_any_papers = sum(oa_any_funding),
      crossref_any_papers = sum(crossref_any_funding),
      union_any_papers = sum(union_any_funding)
    ),
    by = audit_cluster_id
  ]
  cluster_summary <- as.data.frame(cluster_summary)
  cluster_summary$analysis_group <- group_name
  cluster_summary$oa_any_coverage <-
    cluster_summary$oa_any_papers / cluster_summary$papers
  cluster_summary$crossref_any_coverage <-
    cluster_summary$crossref_any_papers / cluster_summary$papers
  cluster_summary$union_any_coverage <-
    cluster_summary$union_any_papers / cluster_summary$papers
  cluster_rows[[length(cluster_rows) + 1L]] <- cluster_summary
}
cluster_coverage <- as.data.frame(data.table::rbindlist(
  cluster_rows,
  fill = TRUE
))

request_summary <- data.frame(
  metric = c(
    "unique_dois",
    "http_200",
    "http_404",
    "network_or_json_failures",
    "papers_with_crossref_funders",
    "papers_with_crossref_awards"
  ),
  value = c(
    nrow(request_audit),
    sum(request_audit$http_status == 200L, na.rm = TRUE),
    sum(request_audit$http_status == 404L, na.rm = TRUE),
    sum(
      is.na(request_audit$http_status) |
        !request_audit$json_valid,
      na.rm = TRUE
    ),
    sum(crossref_papers$crossref_funder_present),
    sum(crossref_papers$crossref_award_present)
  ),
  stringsAsFactors = FALSE
)

write_csv_utf8(
  combined,
  file.path(audit_table_dir, "funding_source_symmetric_paper_metadata.csv")
)
write_csv_utf8(
  group_coverage,
  file.path(audit_table_dir, "funding_source_symmetric_group_coverage.csv")
)
write_csv_utf8(
  source_agreement,
  file.path(audit_table_dir, "funding_source_symmetric_agreement.csv")
)
write_csv_utf8(
  cluster_coverage,
  file.path(audit_table_dir, "funding_source_symmetric_cluster_coverage.csv")
)
write_csv_utf8(
  request_audit,
  file.path(audit_table_dir, "funding_source_symmetric_request_audit.csv")
)
write_csv_utf8(
  request_summary,
  file.path(audit_table_dir, "funding_source_symmetric_request_summary.csv")
)
write_csv_utf8(
  crossref_funders,
  file.path(audit_table_dir, "funding_source_symmetric_crossref_funders.csv")
)
write_csv_utf8(
  crossref_awards,
  file.path(audit_table_dir, "funding_source_symmetric_crossref_awards.csv")
)

write_audit_manifest()
message("Source-symmetric funding comparison completed.")

