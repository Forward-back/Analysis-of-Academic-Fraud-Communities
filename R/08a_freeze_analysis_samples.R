#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/analysis_sample_audit.R", encoding = "UTF-8")

family_columns <- c(
  "family_publication_process",
  "family_image_integrity",
  "family_plagiarism_authorship",
  "family_data_integrity",
  "family_research_ethics_compliance_narrow",
  "family_materials_methods_integrity_narrow",
  "family_error_control",
  "family_unclassified"
)

case_panel <- readRDS(file.path(
  processed_dir,
  "p0",
  "openalex_mainland_accepted_paper_panel.rds"
))
network_panel <- readRDS(file.path(
  processed_dir,
  "p0",
  "openalex_mainland_network_complete_paper_panel.rds"
))
control_cases <- readRDS(file.path(processed_dir, "p1", "control_cases.rds"))
case_match <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_case_match.rds"
))
control_links <- readRDS(file.path(processed_dir, "p1", "control_links.rds"))
control_works <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_works_full.rds"
))
institutions <- readRDS(file.path(
  processed_dir,
  "p1",
  "institutions_enriched.rds"
))

assert_columns(
  case_panel,
  c(
    "paper_key",
    "retraction_year_first",
    "publication_year",
    "publisher",
    "source_id",
    "source_present",
    "openalex_type",
    "openalex_work_id",
    "n_authorships",
    "all_authors_have_institution",
    family_columns
  ),
  "mainland case panel"
)
assert_columns(
  control_cases,
  c("paper_key", "control_eligible"),
  "control case panel"
)
assert_columns(
  case_match,
  c("paper_key", "controls_matched"),
  "control case match"
)
assert_columns(
  control_links,
  c("paper_key", "openalex_work_id", "topic_match_level"),
  "control links"
)
assert_columns(
  control_works,
  c(
    "openalex_work_id",
    "all_authors_have_institution",
    "institution_ids"
  ),
  "control works"
)
assert_columns(institutions, "institution_id", "institutions")

if (anyDuplicated(case_panel$paper_key)) {
  stop("Mainland case panel contains duplicate paper keys.")
}
if (anyDuplicated(control_links$openalex_work_id)) {
  stop("Selected control works are not globally unique.")
}

case_audit <- as.data.frame(case_panel)
control_case_index <- match(case_audit$paper_key, control_cases$paper_key)
case_match_index <- match(case_audit$paper_key, case_match$paper_key)

case_audit$control_eligible <- control_cases$control_eligible[
  control_case_index
]
case_audit$controls_matched <- case_match$controls_matched[
  case_match_index
]
case_audit$controls_matched[
  is.na(case_audit$controls_matched) & case_audit$control_eligible
] <- 0L
case_audit$controls_matched[
  is.na(case_audit$controls_matched)
] <- 0L
case_audit$controls_matched <- as.integer(case_audit$controls_matched)

case_audit$match_group <- ifelse(
  !case_audit$control_eligible,
  "no_stratum",
  paste0("controls_", case_audit$controls_matched)
)
case_audit$match_group <- factor(
  case_audit$match_group,
  levels = c("controls_2", "controls_1", "controls_0", "no_stratum")
)

final_control_ids <- unique(control_links$openalex_work_id)
control_works <- control_works[
  control_works$openalex_work_id %in% final_control_ids,
  ,
  drop = FALSE
]
if (nrow(control_works) != length(final_control_ids)) {
  stop("Control metadata does not cover every final control work exactly once.")
}

existing_institution_ids <- unique(institutions$institution_id)
control_works$missing_institution_count <- vapply(
  control_works$institution_ids,
  function(ids) sum(!ids %in% existing_institution_ids),
  integer(1)
)
control_works$has_missing_institution_metadata <-
  control_works$missing_institution_count > 0L
control_works$control_metadata_incomplete <-
  !control_works$all_authors_have_institution |
  control_works$has_missing_institution_metadata
control_works$control_metadata_gap_type <- ifelse(
  !control_works$all_authors_have_institution &
    control_works$has_missing_institution_metadata,
  "author_institution_and_enriched_metadata",
  ifelse(
    !control_works$all_authors_have_institution,
    "author_institution_only",
    ifelse(
      control_works$has_missing_institution_metadata,
      "enriched_metadata_only",
      "complete"
    )
  )
)

control_link_audit <- merge(
  control_links,
  control_works[, c(
    "openalex_work_id",
    "all_authors_have_institution",
    "missing_institution_count",
    "has_missing_institution_metadata",
    "control_metadata_incomplete"
  ), drop = FALSE],
  by = "openalex_work_id",
  all.x = TRUE,
  sort = FALSE
)
if (any(is.na(control_link_audit$control_metadata_incomplete))) {
  stop("Some final control links are missing metadata rows.")
}

control_link_summary <- data.table::as.data.table(control_link_audit)[
  ,
  .(
    control_works_linked = .N,
    control_metadata_gap_works = sum(control_metadata_incomplete),
    control_author_institution_gap_works = sum(
      !all_authors_have_institution
    ),
    control_enriched_metadata_gap_works = sum(
      has_missing_institution_metadata
    )
  ),
  by = paper_key
]
control_link_summary <- as.data.frame(control_link_summary)
link_index <- match(case_audit$paper_key, control_link_summary$paper_key)
case_audit$control_works_linked <- control_link_summary$control_works_linked[
  link_index
]
case_audit$control_works_linked[
  is.na(case_audit$control_works_linked)
] <- 0L
case_audit$control_metadata_gap_works <-
  control_link_summary$control_metadata_gap_works[link_index]
case_audit$control_metadata_gap_works[
  is.na(case_audit$control_metadata_gap_works)
] <- 0L
case_audit$control_author_institution_gap_works <-
  control_link_summary$control_author_institution_gap_works[link_index]
case_audit$control_author_institution_gap_works[
  is.na(case_audit$control_author_institution_gap_works)
] <- 0L
case_audit$control_enriched_metadata_gap_works <-
  control_link_summary$control_enriched_metadata_gap_works[link_index]
case_audit$control_enriched_metadata_gap_works[
  is.na(case_audit$control_enriched_metadata_gap_works)
] <- 0L

if (any(case_audit$control_works_linked != case_audit$controls_matched)) {
  stop("Control link counts disagree with the frozen case-match table.")
}

case_audit$any_control_metadata_gap <-
  case_audit$control_metadata_gap_works > 0L
case_audit$all_controls_metadata_complete <-
  case_audit$control_works_linked > 0L &
  !case_audit$any_control_metadata_gap
case_audit$case_institution_complete <-
  case_audit$all_authors_have_institution %in% TRUE
case_audit$network_complete <- case_audit$paper_key %in% network_panel$paper_key

case_audit$sample_descriptive_full <- TRUE
case_audit$sample_matched_any <- case_audit$control_works_linked > 0L
case_audit$sample_team_size_compare <- case_audit$sample_matched_any
case_audit$sample_institution_compare <-
  case_audit$sample_matched_any &
  case_audit$case_institution_complete &
  case_audit$all_controls_metadata_complete
case_audit$sample_network <- case_audit$network_complete

detail_columns <- c(
  "paper_key",
  "retraction_year_first",
  "publication_year",
  "publisher",
  "source_id",
  "source_present",
  "openalex_type",
  "openalex_work_id",
  "n_authorships",
  "n_unique_author_ids",
  "control_eligible",
  "controls_matched",
  "match_group",
  "control_works_linked",
  "control_metadata_gap_works",
  "control_author_institution_gap_works",
  "control_enriched_metadata_gap_works",
  "any_control_metadata_gap",
  "all_controls_metadata_complete",
  "case_institution_complete",
  "network_complete",
  "sample_descriptive_full",
  "sample_matched_any",
  "sample_team_size_compare",
  "sample_institution_compare",
  "sample_network",
  family_columns
)
write_csv_utf8(
  case_audit[, detail_columns, drop = FALSE],
  file.path(audit_table_dir, "analysis_case_audit.csv")
)

control_work_gap_counts <- table(control_works$control_metadata_gap_type)
case_complete <- case_audit$sample_matched_any &
  !case_audit$any_control_metadata_gap
case_author_only <- case_audit$sample_matched_any &
  case_audit$control_author_institution_gap_works > 0L &
  case_audit$control_enriched_metadata_gap_works == 0L
case_enriched_only <- case_audit$sample_matched_any &
  case_audit$control_author_institution_gap_works == 0L &
  case_audit$control_enriched_metadata_gap_works > 0L
case_both_gaps <- case_audit$sample_matched_any &
  case_audit$control_author_institution_gap_works > 0L &
  case_audit$control_enriched_metadata_gap_works > 0L
control_metadata_gap_decomposition <- data.frame(
  metric = c(
    "final_control_works",
    "control_works_complete",
    "control_works_author_institution_only",
    "control_works_enriched_metadata_only",
    "control_works_author_institution_and_enriched_metadata",
    "control_works_any_gap",
    "matched_cases_any_gap",
    "matched_cases_complete",
    "matched_cases_author_institution_only",
    "matched_cases_enriched_metadata_only",
    "matched_cases_author_institution_and_enriched_metadata"
  ),
  value = c(
    nrow(control_works),
    sum(control_work_gap_counts["complete"]),
    sum(control_work_gap_counts["author_institution_only"]),
    sum(control_work_gap_counts["enriched_metadata_only"]),
    sum(control_work_gap_counts[
      "author_institution_and_enriched_metadata"
    ]),
    sum(control_works$control_metadata_incomplete),
    sum(case_audit$any_control_metadata_gap),
    sum(case_complete),
    sum(case_author_only),
    sum(case_enriched_only),
    sum(case_both_gaps)
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  control_metadata_gap_decomposition,
  file.path(
    audit_table_dir,
    "control_metadata_gap_decomposition.csv"
  )
)

sample_registry <- data.frame(
  sample_name = c(
    "descriptive_full",
    "control_eligible",
    "without_match_stratum",
    "matched_any_control",
    "matched_institution_compare",
    "team_size_compare",
    "network_complete",
    "network_excluded"
  ),
  definition = c(
    "All OpenAlex-confirmed mainland retraction cases.",
    "Cases with a defined year-topic-publisher matching stratum.",
    "Cases without a usable matching stratum.",
    "Cases linked to one or two final non-retraction controls.",
    "Matched cases with complete case institutions and complete metadata for every linked control.",
    "Matched cases with a case and control team size.",
    "Cases with complete author IDs and institution data in the network subset.",
    "Mainland retraction cases outside the network-complete subset."
  ),
  cases = c(
    sum(case_audit$sample_descriptive_full),
    sum(case_audit$control_eligible %in% TRUE),
    sum(!case_audit$control_eligible %in% TRUE),
    sum(case_audit$sample_matched_any),
    sum(case_audit$sample_institution_compare),
    sum(case_audit$sample_team_size_compare),
    sum(case_audit$sample_network),
    sum(!case_audit$sample_network)
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  sample_registry,
  file.path(audit_table_dir, "analysis_sample_registry.csv")
)

analysis_group_characteristics(
  case_audit,
  "match_group",
  family_columns
) -> match_group_characteristics
write_csv_utf8(
  match_group_characteristics,
  file.path(audit_table_dir, "match_selection_by_group.csv")
)

family_selection_rows <- lapply(family_columns, function(family) {
  family_cases <- case_audit[case_audit[[family]] %in% TRUE, , drop = FALSE]
  zero <- family_cases[family_cases$control_works_linked == 0L, , drop = FALSE]
  matched <- family_cases[
    family_cases$control_works_linked > 0L,
    ,
    drop = FALSE
  ]
  data.frame(
    analysis_family = family,
    cases = nrow(family_cases),
    zero_control_cases = nrow(zero),
    matched_cases = nrow(matched),
    zero_control_share = nrow(zero) / nrow(family_cases),
    zero_mean_team_size = mean(zero$n_authorships, na.rm = TRUE),
    matched_mean_team_size = mean(matched$n_authorships, na.rm = TRUE),
    zero_vs_matched_team_size_smd =
      analysis_standardized_mean_difference(
        zero$n_authorships,
        matched$n_authorships
      ),
    zero_mean_retraction_year = mean(
      zero$retraction_year_first,
      na.rm = TRUE
    ),
    matched_mean_retraction_year = mean(
      matched$retraction_year_first,
      na.rm = TRUE
    ),
    zero_source_missing_share = mean(!zero$source_present),
    matched_source_missing_share = mean(!matched$source_present),
    zero_institution_complete_share = mean(
      zero$case_institution_complete
    ),
    matched_institution_complete_share = mean(
      matched$case_institution_complete
    ),
    zero_network_complete_share = mean(zero$network_complete),
    matched_network_complete_share = mean(matched$network_complete),
    matched_control_metadata_gap_share = mean(
      matched$any_control_metadata_gap
    ),
    stringsAsFactors = FALSE
  )
})
family_selection <- data.table::rbindlist(
  family_selection_rows,
  fill = TRUE
)
write_csv_utf8(
  as.data.frame(family_selection),
  file.path(audit_table_dir, "match_selection_by_family.csv")
)

case_audit$control_metadata_group <- ifelse(
  case_audit$control_works_linked == 0L,
  "no_control",
  ifelse(
    case_audit$any_control_metadata_gap,
    "any_control_gap",
    "all_controls_complete"
  )
)
case_audit$control_metadata_group <- factor(
  case_audit$control_metadata_group,
  levels = c("all_controls_complete", "any_control_gap", "no_control")
)
control_metadata_characteristics <- analysis_group_characteristics(
  case_audit,
  "control_metadata_group",
  family_columns
)
write_csv_utf8(
  control_metadata_characteristics,
  file.path(
    audit_table_dir,
    "control_metadata_selection_by_group.csv"
  )
)

case_audit$network_sample_status <- ifelse(
  case_audit$network_complete,
  "included",
  "excluded"
)
case_audit$network_sample_status <- factor(
  case_audit$network_sample_status,
  levels = c("included", "excluded")
)
network_selection_by_group <- analysis_group_characteristics(
  case_audit,
  "network_sample_status",
  family_columns
)
write_csv_utf8(
  network_selection_by_group,
  file.path(audit_table_dir, "network_selection_by_group.csv")
)

network_comparison_metrics <- c(
  "n_authorships",
  "n_unique_author_ids",
  "publication_year",
  "retraction_year_first",
  "controls_matched",
  "source_present",
  "case_institution_complete",
  "sample_matched_any",
  family_columns
)
network_selection_metrics <- analysis_standardized_comparison(
  case_audit,
  "network_complete",
  network_comparison_metrics
)
write_csv_utf8(
  network_selection_metrics,
  file.path(audit_table_dir, "network_selection_metrics.csv")
)

network_family_rows <- lapply(family_columns, function(family) {
  family_cases <- case_audit[case_audit[[family]] %in% TRUE, , drop = FALSE]
  included <- family_cases$network_complete %in% TRUE
  data.frame(
    analysis_family = family,
    mainland_cases = nrow(family_cases),
    network_cases = sum(included),
    network_coverage = mean(included),
    included_mean_team_size = mean(
      family_cases$n_authorships[included],
      na.rm = TRUE
    ),
    excluded_mean_team_size = mean(
      family_cases$n_authorships[!included],
      na.rm = TRUE
    ),
    team_size_smd = analysis_standardized_mean_difference(
      family_cases$n_authorships[included],
      family_cases$n_authorships[!included]
    ),
    stringsAsFactors = FALSE
  )
})
network_selection_by_family <- data.table::rbindlist(
  network_family_rows,
  fill = TRUE
)
write_csv_utf8(
  as.data.frame(network_selection_by_family),
  file.path(audit_table_dir, "network_selection_by_family.csv")
)

network_selection_by_year <- analysis_coverage_by_group(
  case_audit,
  "retraction_year_first",
  "network_complete"
)
network_selection_by_year <- network_selection_by_year[
  order(network_selection_by_year$group_value),
  ,
  drop = FALSE
]
names(network_selection_by_year)[
  names(network_selection_by_year) == "group_value"
] <- "retraction_year_first"
write_csv_utf8(
  network_selection_by_year,
  file.path(audit_table_dir, "network_selection_by_year.csv")
)

case_audit$publisher_label <- case_audit$publisher
case_audit$publisher_label[
  is.na(case_audit$publisher_label) | case_audit$publisher_label == ""
] <- "unknown"
network_selection_by_publisher <- analysis_coverage_by_group(
  case_audit,
  "publisher_label",
  "network_complete"
)
network_selection_by_publisher <- network_selection_by_publisher[
  order(
    -network_selection_by_publisher$cases,
    network_selection_by_publisher$group_value
  ),
  ,
  drop = FALSE
]
names(network_selection_by_publisher)[
  names(network_selection_by_publisher) == "group_value"
] <- "publisher"
write_csv_utf8(
  network_selection_by_publisher,
  file.path(audit_table_dir, "network_selection_by_publisher.csv")
)

saveRDS(
  list(
    generated_on = Sys.Date(),
    family_columns = family_columns,
    sample_registry = sample_registry,
    case_audit = case_audit,
    control_link_audit = control_link_audit
  ),
  file.path(processed_dir, "p1", "analysis_samples.rds")
)

write_audit_manifest()
message("Analysis samples frozen and selection audits completed.")
