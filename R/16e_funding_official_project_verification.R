#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

verification_config <- yaml::read_yaml("config/funding-verification.yml")
queue <- utils::read.csv(
  file.path(audit_table_dir, "funding_project_verification_queue.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
nsfc_raw <- data.table::fread(
  file.path(audit_table_dir, "funding_nsfc_verification_raw.csv"),
  encoding = "UTF-8",
  data.table = FALSE
)
network_panel <- readRDS(file.path(
  processed_dir,
  "p0",
  "openalex_mainland_network_complete_paper_panel.rds"
))
award_papers <- data.table::fread(
  file.path(audit_table_dir, "funding_crossref_award_papers.csv"),
  encoding = "UTF-8",
  data.table = FALSE
)

assert_columns(
  queue,
  c(
    "award_number",
    "papers_in_sample",
    "clusters_in_sample",
    "funder_names",
    "cluster_ids"
  ),
  "funding verification queue"
)
assert_columns(
  nsfc_raw,
  c(
    "award_number",
    "verification_status",
    "official_project_title",
    "project_type",
    "undertaking_unit",
    "project_leader",
    "approved_year",
    "conclusion_year",
    "amount",
    "currency",
    "amount_unit",
    "official_record_url",
    "access_date",
    "source_snapshot"
  ),
  "NSFC raw verification"
)
assert_columns(
  award_papers,
  c(
    "audit_cluster_id",
    "paper_key",
    "doi_canonical",
    "award_number"
  ),
  "Crossref award-paper metadata"
)
assert_columns(
  network_panel,
  c("paper_key", "openalex_title", "doi_canonical"),
  "network paper panel"
)

queue$official_verification_status <- "pending"
queue$official_project_title <- NA_character_
queue$funding_organization <- NA_character_
queue$undertaking_unit <- NA_character_
queue$project_leader <- NA_character_
queue$approved_year <- NA_character_
queue$conclusion_year <- NA_character_
queue$start_year <- NA_character_
queue$end_year <- NA_character_
queue$amount <- NA_character_
queue$currency <- NA_character_
queue$amount_unit <- NA_character_
queue$amount_status <- "not_verified"
queue$official_record_url <- NA_character_
queue$access_date <- as.character(Sys.Date())
queue$official_supporting_text <- NA_character_
queue$verification_note <- NA_character_
queue$project_period_status <- NA_character_
queue$source_snapshot <- NA_character_

nsfc_match <- match(queue$award_number, nsfc_raw$award_number)
for (index in seq_len(nrow(queue))) {
  raw_index <- nsfc_match[[index]]
  if (is.na(raw_index)) {
    next
  }
  raw <- nsfc_raw[raw_index, , drop = FALSE]
  if (identical(raw$verification_status[[1]], "officially_verified")) {
    queue$official_verification_status[[index]] <-
      "officially_verified_completion_record"
    queue$official_project_title[[index]] <- raw$official_project_title[[1]]
    queue$funding_organization[[index]] <-
      verification_config$nsfc_organization
    queue$undertaking_unit[[index]] <- raw$undertaking_unit[[1]]
    queue$project_leader[[index]] <- raw$project_leader[[1]]
    queue$approved_year[[index]] <- raw$approved_year[[1]]
    queue$conclusion_year[[index]] <- raw$conclusion_year[[1]]
    queue$amount[[index]] <- raw$amount[[1]]
    queue$currency[[index]] <- "CNY"
    queue$amount_unit[[index]] <- verification_config$amount_unit
    queue$amount_status[[index]] <- "officially_verified"
    queue$official_record_url[[index]] <- raw$official_record_url[[1]]
    queue$access_date[[index]] <- raw$access_date[[1]]
    queue$source_snapshot[[index]] <- raw$source_snapshot[[1]]
    queue$official_supporting_text[[index]] <- sprintf(
      verification_config$supporting_text_template,
      queue$award_number[[index]],
      raw$official_project_title[[1]],
      raw$project_type[[1]],
      raw$project_leader[[1]],
      raw$amount[[1]],
      raw$approved_year[[1]],
      raw$conclusion_year[[1]],
      raw$undertaking_unit[[1]]
    )
    queue$verification_note[[index]] <-
      "Official completion-project query returned one exact award-number record."
    queue$project_period_status[[index]] <-
      verification_config$project_period_note
  } else if (
    identical(raw$verification_status[[1]], "not_found")
  ) {
    queue$official_verification_status[[index]] <-
      "not_found_in_nsfc_completion_database"
    queue$funding_organization[[index]] <-
      verification_config$nsfc_organization
    queue$official_record_url[[index]] <-
      "https://kd.nsfc.cn/finalProjectInit?advanced=true"
    queue$access_date[[index]] <- raw$access_date[[1]]
    queue$source_snapshot[[index]] <- raw$source_snapshot[[1]]
    queue$official_supporting_text[[index]] <-
      verification_config$nsfc_not_found_note
    queue$verification_note[[index]] <-
      "Award number not returned by the public completion-project query; project existence is not disproved."
    queue$project_period_status[[index]] <- "not_available"
  }
}

external_awards <- queue$award_number[
  queue$official_verification_status == "pending"
]
for (award in external_awards) {
  authority <- verification_config$external_authorities[[award]]
  if (is.null(authority)) {
    stop("Missing external authority configuration for award: ", award)
  }
  index <- match(award, queue$award_number)
  queue$official_verification_status[[index]] <-
    "not_found_in_public_official_project_search"
  queue$funding_organization[[index]] <- authority$organization
  queue$official_record_url[[index]] <- authority$official_url
  queue$official_supporting_text[[index]] <-
    verification_config$external_not_found_note
  queue$verification_note[[index]] <-
    "No exact public project record located; paper metadata is not treated as official evidence."
  queue$project_period_status[[index]] <- "not_available"
}

if (any(queue$official_verification_status == "pending")) {
  stop("Official verification queue still contains pending records.")
}

queue <- queue[, c(
  "priority",
  "award_number",
  "papers_in_sample",
  "clusters_in_sample",
  "cluster_ids",
  "official_verification_status",
  "official_project_title",
  "funding_organization",
  "undertaking_unit",
  "project_leader",
  "approved_year",
  "conclusion_year",
  "start_year",
  "end_year",
  "amount",
  "currency",
  "amount_unit",
  "amount_status",
  "official_record_url",
  "access_date",
  "official_supporting_text",
  "verification_note",
  "project_period_status",
  "source_snapshot"
), drop = FALSE]

queue_path <- file.path(
  audit_table_dir,
  "funding_official_project_verification.csv"
)
write_csv_utf8(queue, queue_path)

network_titles <- unique(network_panel[, c(
  "paper_key",
  "doi_canonical",
  "openalex_title",
  "publication_year"
)])
paper_evidence <- merge(
  award_papers,
  network_titles,
  by = c("paper_key", "doi_canonical"),
  all.x = TRUE,
  sort = FALSE
)
paper_evidence <- merge(
  paper_evidence,
  queue[, c(
    "award_number",
    "official_verification_status",
    "official_project_title",
    "funding_organization",
    "undertaking_unit",
    "project_leader",
    "approved_year",
    "conclusion_year",
    "amount",
    "currency",
    "amount_unit",
    "amount_status"
  ), drop = FALSE],
  by = "award_number",
  all.x = TRUE,
  sort = FALSE
)
paper_evidence <- paper_evidence[
  order(
    paper_evidence$award_number,
    paper_evidence$audit_cluster_id,
    paper_evidence$doi_canonical
  ),
  ,
  drop = FALSE
]
paper_evidence <- unique(paper_evidence[, c(
  "award_number",
  "audit_cluster_id",
  "paper_key",
  "doi_canonical",
  "openalex_title",
  "publication_year",
  "official_verification_status",
  "official_project_title",
  "funding_organization",
  "undertaking_unit",
  "project_leader",
  "approved_year",
  "conclusion_year",
  "amount",
  "currency",
  "amount_unit",
  "amount_status"
)])
write_csv_utf8(
  paper_evidence,
  file.path(audit_table_dir, "funding_project_paper_evidence.csv")
)

reuse_summary <- data.table::as.data.table(paper_evidence)[
  ,
  .(
    doi_papers = data.table::uniqueN(doi_canonical),
    doi_clusters = data.table::uniqueN(audit_cluster_id),
    representative_doi = doi_canonical[[1]],
    representative_paper_key = paper_key[[1]]
  ),
  by = award_number
]
reuse_summary <- as.data.frame(reuse_summary)
reuse_summary <- merge(
  queue,
  reuse_summary,
  by = "award_number",
  all.x = TRUE,
  sort = FALSE
)
write_csv_utf8(
  reuse_summary,
  file.path(audit_table_dir, "funding_award_doi_reuse_verified.csv")
)

coverage <- utils::read.csv(
  file.path(
    audit_table_dir,
    "funding_source_symmetric_group_coverage.csv"
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
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
contrast_rows <- list()
for (metric in c(
  "oa_funder_coverage",
  "oa_award_coverage",
  "oa_any_coverage",
  "crossref_funder_coverage",
  "crossref_award_coverage",
  "crossref_any_coverage",
  "union_funder_coverage",
  "union_award_coverage",
  "union_any_coverage"
)) {
  contrast_rows[[length(contrast_rows) + 1L]] <- data.frame(
    metric = metric,
    selected = selected[[metric]][[1]],
    matched_controls = controls[[metric]][[1]],
    unselected_candidate_clusters = unselected[[metric]][[1]],
    selected_minus_controls =
      selected[[metric]][[1]] - controls[[metric]][[1]],
    selected_minus_unselected =
      selected[[metric]][[1]] - unselected[[metric]][[1]],
    stringsAsFactors = FALSE
  )
}
contrasts <- as.data.frame(data.table::rbindlist(
  contrast_rows,
  fill = TRUE
))
write_csv_utf8(
  contrasts,
  file.path(
    audit_table_dir,
    "funding_source_symmetric_contrasts.csv"
  )
)

verified <- queue[
  queue$official_verification_status ==
    "officially_verified_completion_record",
  ,
  drop = FALSE
]
verified_papers <- paper_evidence[
  paper_evidence$award_number %in% verified$award_number,
  ,
  drop = FALSE
]
hypothesis_evidence <- data.frame(
  hypothesis = "H5",
  status = paste0(
    "descriptive_support_after_source_symmetric_comparison_",
    "and_partial_official_verification"
  ),
  selected_union_any_coverage =
    selected$union_any_coverage[[1]],
  matched_control_union_any_coverage =
    controls$union_any_coverage[[1]],
  unselected_union_any_coverage =
    unselected$union_any_coverage[[1]],
  officially_verified_awards = nrow(verified),
  verification_queue_awards = nrow(queue),
  verified_unique_doi_papers =
    data.table::uniqueN(verified_papers$doi_canonical),
  verified_doi_clusters =
    data.table::uniqueN(verified_papers$audit_cluster_id),
  cross_cluster_award_reuse = sum(reuse_summary$clusters_in_sample > 1L),
  evidence = paste0(
    "Source-symmetric union funding coverage is ",
    sprintf("%.1f%%", 100 * selected$union_any_coverage[[1]]),
    " for selected clusters, ",
    sprintf("%.1f%%", 100 * controls$union_any_coverage[[1]]),
    " for matched controls, and ",
    sprintf("%.1f%%", 100 * unselected$union_any_coverage[[1]]),
    " for non-selected candidate papers. ",
    nrow(verified),
    " of ",
    nrow(queue),
    " audited awards were verified as official completion records. ",
    "Verified award-number reuse spans ",
    data.table::uniqueN(verified_papers$audit_cluster_id),
    " clusters. Repeated awards remain descriptive; they are not motive, ",
    "risk, or responsibility evidence."
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  hypothesis_evidence,
  file.path(audit_table_dir, "funding_h5_final_evidence.csv")
)

nsfc_snapshot_files <- list.files(
  file.path(
    project_dir,
    "data",
    "external",
    "snapshots",
    "funding_official_verification_v1",
    "nsfc"
  ),
  pattern = "\\.json$",
  full.names = TRUE
)
nsfc_snapshot_files <- sort(nsfc_snapshot_files)
jsonlite::write_json(
  list(
    contract_version = "1.0",
    artifact = "funding-official-project-verification-v1",
    frozen_on = as.character(Sys.Date()),
    verification_summary = project_relative_path(queue_path),
    files = lapply(nsfc_snapshot_files, function(path) {
      list(
        path = project_relative_path(path),
        sha256 = sha256_canonical_file(path)
      )
    })
  ),
  file.path(
    project_dir,
    "data",
    "external",
    "snapshots",
    "funding_official_verification_v1",
    "manifest.json"
  ),
  auto_unbox = TRUE,
  pretty = TRUE
)

write_audit_manifest()
message("Official project verification integration completed.")

