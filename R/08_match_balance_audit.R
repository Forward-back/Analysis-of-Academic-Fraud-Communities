#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

case_panel <- readRDS(file.path(
  processed_dir,
  "p0",
  "openalex_mainland_accepted_paper_panel.rds"
))
control_cases <- readRDS(file.path(processed_dir, "p1", "control_cases.rds"))
control_case_match <- readRDS(file.path(
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
final_control_works <- control_works[
  control_works$openalex_work_id %in% control_links$openalex_work_id,
  ,
  drop = FALSE
]
institutions <- readRDS(file.path(
  processed_dir,
  "p1",
  "institutions_enriched.rds"
))

family_columns <- c(
  "family_publication_process",
  "family_image_integrity",
  "family_plagiarism_authorship",
  "family_data_integrity",
  "family_research_ethics_compliance",
  "family_materials_methods_integrity",
  "family_error_control",
  "family_unclassified"
)

control_work_columns <- c(
  "openalex_work_id",
  "case_paper_key",
  "openalex_type",
  "source_id",
  "publisher_id",
  "primary_topic_id",
  "subfield_id",
  "field_id",
  "domain_id",
  "n_authorships",
  "n_unique_author_ids",
  "all_authors_have_id",
  "all_authors_have_institution",
  "all_authors_have_country",
  "institution_ids"
)
control_slice <- final_control_works[, control_work_columns, drop = FALSE]
names(control_slice) <- c(
  "openalex_work_id",
  "linked_case_paper_key",
  "control_work_type",
  "control_work_source_id",
  "control_publisher_id",
  "control_work_primary_topic_id",
  "control_work_subfield_id",
  "control_work_field_id",
  "control_work_domain_id",
  "control_team_size",
  "control_unique_author_ids",
  "control_all_authors_have_id",
  "control_all_authors_have_institution",
  "control_all_authors_have_country",
  "control_institution_ids"
)

case_slice <- unique(case_panel[, c(
  "paper_key",
  "publication_year",
  "openalex_type",
  "source_id",
  "source_present",
  "host_organization",
  "primary_topic_id",
  "subfield_id",
  "field_id",
  "domain_id",
  "n_authorships",
  "n_unique_author_ids",
  "all_authors_have_id",
  "all_authors_have_institution",
  "all_authors_have_country",
  family_columns
), drop = FALSE])

link_balance <- merge(
  control_links,
  case_slice,
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)
link_balance <- merge(
  link_balance,
  control_slice,
  by = "openalex_work_id",
  all.x = TRUE,
  sort = FALSE
)

link_balance$year_match <- link_balance$control_publication_year ==
  link_balance$publication_year
link_balance$type_match <- link_balance$control_work_type ==
  link_balance$openalex_type
link_balance$source_match <- link_balance$control_source_id ==
  link_balance$source_id
link_balance$publisher_match <- link_balance$control_publisher_id ==
  link_balance$host_organization
link_balance$primary_topic_match <-
  link_balance$control_primary_topic_id == link_balance$primary_topic_id
link_balance$subfield_match <- link_balance$control_subfield_id ==
  link_balance$subfield_id
link_balance$field_match <- link_balance$control_field_id ==
  link_balance$field_id
link_balance$domain_match <- link_balance$control_domain_id ==
  link_balance$domain_id
link_balance$any_topic_match <- (
  link_balance$primary_topic_match |
    link_balance$subfield_match |
    link_balance$field_match |
    link_balance$domain_match
)
link_balance$case_team_size <- as.numeric(link_balance$n_authorships)
link_balance$control_team_size <- as.numeric(link_balance$control_team_size)

consistency_audit <- link_balance[
  !link_balance$year_match | !link_balance$type_match,
  c(
    "paper_key",
    "openalex_work_id",
    "topic_match_level",
    "publication_year",
    "control_publication_year",
    "openalex_type",
    "control_work_type"
  ),
  drop = FALSE
]
write_csv_utf8(
  consistency_audit,
  file.path(audit_table_dir, "match_link_consistency_audit.csv")
)

safe_rate <- function(x) {
  values <- x[!is.na(x)]
  if (length(values) == 0L) {
    return(NA_real_)
  }
  mean(values)
}

standardized_mean_difference <- function(x, y) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  x <- x[is.finite(x)]
  y <- y[is.finite(y)]
  if (length(x) < 2L || length(y) < 2L) {
    return(NA_real_)
  }
  pooled <- sqrt((stats::var(x) + stats::var(y)) / 2)
  if (!is.finite(pooled) || pooled == 0) {
    return(NA_real_)
  }
  (mean(x) - mean(y)) / pooled
}

summarize_links <- function(data, analysis_family) {
  data.frame(
    analysis_family = analysis_family,
    links = nrow(data),
    cases = length(unique(data$paper_key)),
    year_match_rate = safe_rate(data$year_match),
    type_match_rate = safe_rate(data$type_match),
    source_match_rate = safe_rate(data$source_match),
    publisher_match_rate = safe_rate(data$publisher_match),
    primary_topic_match_rate = safe_rate(data$primary_topic_match),
    subfield_match_rate = safe_rate(data$subfield_match),
    field_match_rate = safe_rate(data$field_match),
    domain_match_rate = safe_rate(data$domain_match),
    any_topic_match_rate = safe_rate(data$any_topic_match),
    mean_case_team_size = mean(data$case_team_size, na.rm = TRUE),
    mean_control_team_size = mean(data$control_team_size, na.rm = TRUE),
    team_size_smd = standardized_mean_difference(
      data$case_team_size,
      data$control_team_size
    ),
    stringsAsFactors = FALSE
  )
}

balance_by_family <- data.table::rbindlist(
  c(
    list(summarize_links(link_balance, "all_matched")),
    lapply(family_columns, function(family) {
      summarize_links(
        link_balance[link_balance[[family]] %in% TRUE, , drop = FALSE],
        family
      )
    })
  ),
  fill = TRUE
)
write_csv_utf8(
  balance_by_family,
  file.path(audit_table_dir, "match_balance_by_family.csv")
)

balance_by_layer <- data.table::rbindlist(
  lapply(
    split(link_balance, link_balance$topic_match_level),
    function(data) summarize_links(data, data$topic_match_level[[1]])
  ),
  fill = TRUE
)
write_csv_utf8(
  balance_by_layer,
  file.path(audit_table_dir, "match_balance_by_layer.csv")
)

balance_summary <- data.frame(
  metric = c(
    "control_links",
    "matched_cases",
    "year_match_rate",
    "type_match_rate",
    "type_mismatch_links",
    "source_match_rate",
    "publisher_match_rate",
    "field_match_rate",
    "any_topic_match_rate",
    "mean_case_team_size",
    "mean_control_team_size",
    "team_size_smd",
    "case_key_mismatch",
    "control_all_authors_have_id_rate",
    "control_all_authors_have_institution_rate",
    "control_all_authors_have_country_rate"
  ),
  value = c(
    nrow(link_balance),
    length(unique(link_balance$paper_key)),
    safe_rate(link_balance$year_match),
    safe_rate(link_balance$type_match),
    sum(!link_balance$type_match),
    safe_rate(link_balance$source_match),
    safe_rate(link_balance$publisher_match),
    safe_rate(link_balance$field_match),
    safe_rate(link_balance$any_topic_match),
    mean(link_balance$case_team_size, na.rm = TRUE),
    mean(link_balance$control_team_size, na.rm = TRUE),
    standardized_mean_difference(
      link_balance$case_team_size,
      link_balance$control_team_size
    ),
    sum(
      !is.na(link_balance$linked_case_paper_key) &
        link_balance$linked_case_paper_key != link_balance$paper_key
    ),
    safe_rate(link_balance$control_all_authors_have_id),
    safe_rate(link_balance$control_all_authors_have_institution),
    safe_rate(link_balance$control_all_authors_have_country)
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  balance_summary,
  file.path(audit_table_dir, "match_balance_summary.csv")
)

case_selection <- merge(
  case_slice,
  control_cases[, c("paper_key", "control_eligible"), drop = FALSE],
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)
case_selection <- merge(
  case_selection,
  control_case_match[, c("paper_key", "controls_matched"), drop = FALSE],
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)
case_selection$match_group <- ifelse(
  !case_selection$control_eligible,
  "no_stratum",
  ifelse(
    is.na(case_selection$controls_matched),
    "not_matched",
    paste0("controls_", case_selection$controls_matched)
  )
)
case_selection$match_group <- factor(
  case_selection$match_group,
  levels = c("controls_2", "controls_1", "controls_0", "no_stratum")
)

selection_rows <- lapply(
  split(case_selection, case_selection$match_group, drop = TRUE),
  function(data) {
    row <- data.frame(
      match_group = as.character(data$match_group[[1]]),
      cases = nrow(data),
      mean_retraction_year = mean(data$publication_year, na.rm = TRUE),
      median_team_size = stats::median(data$n_authorships, na.rm = TRUE),
      mean_team_size = mean(data$n_authorships, na.rm = TRUE),
      source_missing_rate = mean(!data$source_present, na.rm = TRUE),
      all_authors_have_id_rate = mean(data$all_authors_have_id, na.rm = TRUE),
      all_authors_have_institution_rate = mean(
        data$all_authors_have_institution,
        na.rm = TRUE
      ),
      stringsAsFactors = FALSE
    )
    for (family in family_columns) {
      row[[paste0(family, "_rate")]] <- mean(data[[family]] %in% TRUE)
    }
    row
  }
)
selection_summary <- data.table::rbindlist(selection_rows, fill = TRUE)
write_csv_utf8(
  selection_summary,
  file.path(audit_table_dir, "match_selection_by_match_count.csv")
)

existing_institution_ids <- unique(institutions$institution_id)
all_control_institution_ids <- unique(unlist(
  final_control_works$institution_ids,
  use.names = FALSE
))
missing_institution_ids <- setdiff(
  all_control_institution_ids,
  existing_institution_ids
)
final_control_works$missing_institution_count <- vapply(
  final_control_works$institution_ids,
  function(ids) sum(!ids %in% existing_institution_ids),
  integer(1)
)
final_control_works$has_missing_institution_metadata <-
  final_control_works$missing_institution_count > 0L

gap_summary <- data.frame(
  metric = c(
    "control_works",
    "control_works_with_institution_link",
    "control_works_without_institution_link",
    "unique_control_institutions",
    "enriched_institution_metadata",
    "missing_institution_metadata",
    "control_works_with_missing_metadata",
    "affected_matched_cases"
  ),
  value = c(
    nrow(final_control_works),
    sum(final_control_works$all_authors_have_institution),
    sum(!final_control_works$all_authors_have_institution),
    length(all_control_institution_ids),
    length(intersect(all_control_institution_ids, existing_institution_ids)),
    length(missing_institution_ids),
    sum(final_control_works$has_missing_institution_metadata),
    length(unique(final_control_works$case_paper_key[
      final_control_works$has_missing_institution_metadata
    ]))
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  gap_summary,
  file.path(audit_table_dir, "control_institution_gap_summary.csv")
)

gap_by_family <- data.table::rbindlist(
  lapply(family_columns, function(family) {
    family_cases <- case_panel$paper_key[case_panel[[family]] %in% TRUE]
    family_controls <- final_control_works[
      final_control_works$case_paper_key %in% family_cases,
      ,
      drop = FALSE
    ]
    data.frame(
      analysis_family = family,
      cases = length(unique(family_controls$case_paper_key)),
      controls = nrow(family_controls),
      controls_with_missing_metadata = sum(
        family_controls$has_missing_institution_metadata
      ),
      missing_institutions = length(unique(unlist(
        family_controls$institution_ids[
          family_controls$has_missing_institution_metadata
        ],
        use.names = FALSE
      ))),
      stringsAsFactors = FALSE
    )
  }),
  fill = TRUE
)
write_csv_utf8(
  gap_by_family,
  file.path(audit_table_dir, "control_institution_gap_by_family.csv")
)

link_gap <- merge(
  control_links[, c("openalex_work_id", "topic_match_level"), drop = FALSE],
  final_control_works[, c(
    "openalex_work_id",
    "has_missing_institution_metadata"
  ), drop = FALSE],
  by = "openalex_work_id",
  all.x = TRUE,
  sort = FALSE
)
gap_by_layer <- data.table::as.data.table(link_gap)[
  ,
  .(
    links = .N,
    links_with_missing_metadata = sum(has_missing_institution_metadata)
  ),
  by = topic_match_level
]
gap_by_layer <- as.data.frame(gap_by_layer)
gap_by_layer$missing_metadata_rate <-
  gap_by_layer$links_with_missing_metadata / gap_by_layer$links
write_csv_utf8(
  gap_by_layer[order(gap_by_layer$topic_match_level), , drop = FALSE],
  file.path(audit_table_dir, "control_institution_gap_by_layer.csv")
)

write_audit_manifest()
message("Matching balance and control metadata gap audit completed.")
