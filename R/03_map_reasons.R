#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

input_path <- file.path(
  processed_dir,
  "p0",
  "paper_panel_descriptive.rds"
)
if (!file.exists(input_path)) {
  stop("Run R/02_build_doi_panel.R first. Missing: ", input_path)
}

panel <- readRDS(input_path)
mapping_dir <- file.path(project_dir, analysis_config$reason_mapping$registry)
mapping_dir <- dirname(mapping_dir)

registry_file <- file.path(
  project_dir,
  analysis_config$reason_mapping$registry
)
domain_file <- file.path(
  project_dir,
  analysis_config$reason_mapping$domain_map
)
context_file <- file.path(
  project_dir,
  analysis_config$reason_mapping$context_map
)
family_file <- file.path(
  project_dir,
  analysis_config$reason_mapping$analysis_family_map
)

registry <- data.table::fread(
  registry_file,
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
domains <- data.table::fread(
  domain_file,
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
contexts <- data.table::fread(
  context_file,
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
families <- data.table::fread(
  family_file,
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)

if (anyDuplicated(registry$reason_label) > 0) {
  stop("Reason registry contains duplicate labels.")
}

observed_labels <- sort(unique(unlist(panel$reason_labels, use.names = FALSE)))
unknown_labels <- setdiff(observed_labels, registry$reason_label)
if (length(unknown_labels) > 0) {
  stop("Unmapped reason labels: ", paste(unknown_labels, collapse = "; "))
}

label_domains <- split(domains$issue_domain, domains$reason_label)
label_contexts <- split(contexts$context_tag, contexts$reason_label)
label_evidence <- stats::setNames(
  registry$evidence_status,
  registry$reason_label
)

panel$reason_issue_domains <- I(lapply(panel$reason_labels, function(labels) {
  unique(unlist(label_domains[labels], use.names = FALSE))
}))
panel$reason_context_tags <- I(lapply(panel$reason_labels, function(labels) {
  unique(unlist(label_contexts[labels], use.names = FALSE))
}))
panel$reason_evidence_statuses <- I(lapply(
  panel$reason_labels,
  function(labels) {
    unique(unname(label_evidence[labels]))
  }
))

flag_labels <- function(labels, candidates) {
  any(labels %in% candidates)
}

flag_domain <- function(reason_labels, domain, statuses = NULL) {
  domain_labels <- domains$reason_label[
    domains$issue_domain == domain
  ]
  if (!is.null(statuses)) {
    domain_labels <- domain_labels[
      label_evidence[domain_labels] %in% statuses
    ]
  }
  any(reason_labels %in% domain_labels)
}

family_domains <- split(families$issue_domain, families$analysis_family)
family_labels <- lapply(family_domains, function(domain_values) {
  unique(domains$reason_label[
    domains$issue_domain %in% domain_values
  ])
})
family_labels_narrow <- lapply(family_labels, function(labels) {
  labels[label_evidence[labels] == "substantive_finding"]
})

panel$family_publication_process <- vapply(
  panel$reason_labels,
  flag_labels,
  logical(1),
  family_labels_narrow$publication_process
)
panel$family_image_integrity <- vapply(
  panel$reason_labels,
  flag_labels,
  logical(1),
  family_labels_narrow$image_integrity
)
panel$family_plagiarism_authorship <- vapply(
  panel$reason_labels,
  flag_labels,
  logical(1),
  family_labels_narrow$plagiarism_authorship
)
panel$family_data_integrity <- vapply(
  panel$reason_labels,
  flag_labels,
  logical(1),
  family_labels_narrow$data_integrity
)
panel$family_research_ethics_compliance_narrow <- vapply(
  panel$reason_labels,
  flag_labels,
  logical(1),
  family_labels_narrow$research_ethics_compliance
)
panel$family_materials_methods_integrity_narrow <- vapply(
  panel$reason_labels,
  flag_labels,
  logical(1),
  family_labels_narrow$materials_methods_integrity
)
panel$family_research_ethics_compliance <- vapply(
  panel$reason_labels,
  flag_domain,
  logical(1),
  "research_ethics_compliance"
)
panel$family_materials_methods_integrity <- vapply(
  panel$reason_labels,
  flag_domain,
  logical(1),
  "materials_methods_integrity"
)
panel$family_publication_process_broad <- vapply(
  panel$reason_labels,
  flag_domain,
  logical(1),
  "publication_peer_review"
)
panel$family_image_integrity_broad <- vapply(
  panel$reason_labels,
  flag_domain,
  logical(1),
  "image_integrity"
)
panel$family_plagiarism_authorship_broad <- vapply(
  panel$reason_labels,
  flag_labels,
  logical(1),
  family_labels$plagiarism_authorship
)
panel$family_data_integrity_broad <- vapply(
  panel$reason_labels,
  flag_domain,
  logical(1),
  "data_results_integrity"
)
panel$domain_textual_reuse <- vapply(
  panel$reason_labels,
  flag_domain,
  logical(1),
  "textual_reuse"
)
panel$domain_authorship_affiliation <- vapply(
  panel$reason_labels,
  flag_domain,
  logical(1),
  "authorship_affiliation"
)
panel$domain_unspecified_integrity <- vapply(
  panel$reason_labels,
  flag_domain,
  logical(1),
  "unspecified_integrity"
)
panel$reason_domain_any <- lengths(panel$reason_issue_domains) > 0
panel$reason_mapping_unmapped <- vapply(
  panel$reason_labels,
  function(labels) {
    any(
      registry$mapping_status[
        match(labels, registry$reason_label)
      ] != "reviewed"
    )
  },
  logical(1)
)

narrow_family_matrix <- cbind(
  panel$family_publication_process,
  panel$family_image_integrity,
  panel$family_plagiarism_authorship,
  panel$family_data_integrity,
  panel$family_research_ethics_compliance_narrow,
  panel$family_materials_methods_integrity_narrow
)
panel$family_error_control <- vapply(
  panel$reason_evidence_statuses,
  function(statuses) {
    any(statuses %in% c("error_unreliable", "insufficient_information"))
  },
  logical(1)
) & !apply(narrow_family_matrix, 1, any)
panel$family_unclassified <- !(
  apply(narrow_family_matrix, 1, any) |
    panel$family_research_ethics_compliance |
    panel$family_materials_methods_integrity |
    panel$family_error_control
)

panel$reason_issue_domains_text <- list_to_delimited(
  panel$reason_issue_domains
)
panel$reason_context_tags_text <- list_to_delimited(
  panel$reason_context_tags
)
panel$reason_evidence_statuses_text <- list_to_delimited(
  panel$reason_evidence_statuses
)
panel$reason_labels_text <- list_to_delimited(panel$reason_labels)

output_path <- file.path(
  processed_dir,
  "p0",
  "paper_panel_mapped.rds"
)
saveRDS(panel, output_path)

family_flags <- c(
  "publication_process" = "family_publication_process",
  "image_integrity" = "family_image_integrity",
  "plagiarism_authorship" = "family_plagiarism_authorship",
  "data_integrity" = "family_data_integrity",
  "research_ethics_compliance" = "family_research_ethics_compliance",
  "materials_methods_integrity" = "family_materials_methods_integrity",
  "error_control" = "family_error_control",
  "unclassified" = "family_unclassified"
)

family_audit <- data.frame(
  reason_family = names(family_flags),
  descriptive_papers = vapply(
    family_flags,
    function(column) sum(panel[[column]]),
    integer(1)
  ),
  linkable_papers = vapply(
    family_flags,
    function(column) sum(panel[[column]] & panel$doi_status == "linkable"),
    integer(1)
  ),
  stringsAsFactors = FALSE
)
family_audit$descriptive_share <- family_audit$descriptive_papers / nrow(panel)
family_audit$linkable_share <- family_audit$linkable_papers / sum(
  panel$doi_status == "linkable"
)

write_csv_utf8(
  family_audit,
  file.path(audit_table_dir, "p0_reason_family_audit.csv")
)

write_audit_manifest()
message("P0 reason mapping completed.")
