#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/analysis_sample_audit.R", encoding = "UTF-8")
source("R/lib/institution_structure.R", encoding = "UTF-8")

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

case_audit <- readRDS(file.path(
  processed_dir,
  "p1",
  "analysis_samples.rds"
))$case_audit
case_institution_long <- readRDS(file.path(
  processed_dir,
  "p1",
  "author_institution_long.rds"
))
control_links <- readRDS(file.path(processed_dir, "p1", "control_links.rds"))
control_case_match <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_case_match.rds"
))
control_authors <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_authorships_long.rds"
))
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
  case_audit,
  c(
    "paper_key",
    "retraction_year_first",
    "publication_year",
    "n_authorships",
    "sample_matched_any",
    "sample_institution_compare",
    family_columns
  ),
  "frozen case audit"
)
assert_columns(
  control_authors,
  c(
    "case_paper_key",
    "control_work_id",
    "author_id",
    "institution_ids"
  ),
  "control authorships"
)
assert_columns(
  control_works,
  c(
    "openalex_work_id",
    "publication_year",
    "n_authorships",
    "all_authors_have_institution",
    "institution_ids"
  ),
  "control works"
)

case_structure <- summarize_institution_structure(
  case_institution_long,
  "paper_key"
)
cases <- merge(
  case_audit,
  case_structure,
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)
cases$institution_observed <- cases$paper_key %in%
  case_structure$paper_key
cases$team_size <- cases$n_authorships

final_control_ids <- unique(control_links$openalex_work_id)
control_works <- control_works[
  control_works$openalex_work_id %in% final_control_ids,
  ,
  drop = FALSE
]
if (nrow(control_works) != length(final_control_ids)) {
  stop("Final control works are not unique in the control work panel.")
}

existing_institution_ids <- unique(institutions$institution_id)
control_works$missing_institution_count <- vapply(
  control_works$institution_ids,
  function(ids) sum(!ids %in% existing_institution_ids),
  integer(1)
)
control_works$institution_metadata_complete <-
  control_works$all_authors_have_institution %in% TRUE &
  control_works$missing_institution_count == 0L

control_author_dt <- data.table::as.data.table(control_authors)
control_author_dt[, control_authorship_id := seq_len(.N)]
control_author_dt <- control_author_dt[
  control_work_id %in% final_control_ids,
  ,
  drop = FALSE
]

control_institution_long <- control_author_dt[
  ,
  {
    ids <- institution_ids[[1]]
    if (length(ids) == 0L) {
      list(
        institution_id = character(),
        institution_order = integer()
      )
    } else {
      list(
        institution_id = ids,
        institution_order = seq_along(ids)
      )
    }
  },
  by = .(
    control_authorship_id,
    case_paper_key,
    control_work_id,
    author_order,
    author_id
  )
]

institution_columns <- c(
  "institution_id",
  "institution_name",
  "country_code",
  "effective_country_code",
  "region",
  "region_code",
  "province_name_zh",
  "region_type",
  "city",
  "latitude",
  "longitude",
  "is_mainland_institution",
  "is_hmt_institution",
  "is_foreign_institution",
  "tier_985",
  "tier_211",
  "tier_double_first_class_2017",
  "tier_double_first_class_2022"
)
control_institution_long <- merge(
  control_institution_long,
  institutions[, institution_columns, drop = FALSE],
  by = "institution_id",
  all.x = TRUE,
  sort = FALSE
)
control_year_lookup <- unique(control_works[, c(
  "openalex_work_id",
  "publication_year"
)])
control_institution_long$publication_year <-
  control_year_lookup$publication_year[
    match(
      control_institution_long$control_work_id,
      control_year_lookup$openalex_work_id
    )
  ]
control_institution_long <- institution_add_year_tier(
  control_institution_long,
  "publication_year"
)
control_structure <- summarize_institution_structure(
  control_institution_long,
  "control_work_id"
)

control_panel <- merge(
  control_links,
  control_works[, c(
    "openalex_work_id",
    "case_paper_key",
    "publication_year",
    "openalex_type",
    "n_authorships",
    "n_unique_author_ids",
    "source_id",
    "publisher_id",
    "publisher_name",
    "primary_topic_id",
    "subfield_id",
    "field_id",
    "domain_id",
    "institution_metadata_complete"
  ), drop = FALSE],
  by = "openalex_work_id",
  all.x = TRUE,
  sort = FALSE
)
control_panel <- merge(
  control_panel,
  control_structure,
  by.x = "openalex_work_id",
  by.y = "control_work_id",
  all.x = TRUE,
  sort = FALSE
)
control_panel$institution_observed <-
  control_panel$institution_metadata_complete &
  control_panel$openalex_work_id %in% control_structure$control_work_id

case_sample_flags <- case_audit[, c(
  "paper_key",
  "sample_matched_any",
  "sample_institution_compare",
  family_columns
), drop = FALSE]
names(case_sample_flags)[names(case_sample_flags) == "paper_key"] <-
  "case_paper_key"

case_rows <- cases[cases$sample_matched_any, , drop = FALSE]
case_rows <- merge(
  case_rows,
  control_case_match[, c(
    "paper_key",
    "best_available_level"
  ), drop = FALSE],
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)
case_rows$analysis_paper_id <- paste0("case:", case_rows$paper_key)
case_rows$match_group <- case_rows$paper_key
case_rows$case_paper_key <- case_rows$paper_key
case_rows$is_retraction <- TRUE
case_rows$control_rank <- 0L
case_rows$match_layer <- case_rows$best_available_level
case_rows$team_size <- case_rows$n_authorships
case_rows$analysis_institution_eligible <-
  case_rows$sample_institution_compare

control_panel <- merge(
  control_panel,
  case_sample_flags,
  by = "case_paper_key",
  all.x = TRUE,
  sort = FALSE
)
control_panel$analysis_paper_id <- paste0(
  "control:",
  control_panel$openalex_work_id
)
control_panel$match_group <- control_panel$case_paper_key
control_panel$is_retraction <- FALSE
control_panel$match_layer <- control_panel$topic_match_level
control_panel$team_size <- control_panel$n_authorships
control_panel$analysis_institution_eligible <-
  control_panel$sample_institution_compare
control_panel$retraction_year_first <- NA_integer_
for (family in family_columns) {
  control_panel[[family]] <- FALSE
}

common_columns <- c(
  "analysis_paper_id",
  "match_group",
  "case_paper_key",
  "is_retraction",
  "control_rank",
  "match_layer",
  "openalex_work_id",
  "publication_year",
  "retraction_year_first",
  "openalex_type",
  "source_id",
  "publisher",
  "team_size",
  "n_unique_author_ids",
  "primary_topic_id",
  "subfield_id",
  "field_id",
  "domain_id",
  "analysis_institution_eligible",
  "institution_observed",
  "n_institution_links",
  "n_unique_institutions",
  "n_mainland_institutions",
  "n_hmt_institutions",
  "n_foreign_institutions",
  "national_key_institution_count",
  "non_national_mainland_institution_count",
  "national_key_present",
  "non_national_mainland_present",
  "cross_tier",
  "legacy_985_211_cross_tier",
  "institution_hmt_present",
  "institution_foreign_present",
  "geo_level",
  "main_city_count",
  "main_region_count",
  "tier_rule",
  "median_domestic_geo_distance_km",
  "max_domestic_geo_distance_km",
  "median_all_geo_distance_km",
  "max_all_geo_distance_km",
  family_columns
)

case_panel <- case_rows[, common_columns, drop = FALSE]
control_panel$publisher <- control_panel$publisher_name
control_panel <- control_panel[, common_columns, drop = FALSE]

paper_panel <- rbind(case_panel, control_panel)
paper_panel$domestic_cross_province <-
  paper_panel$geo_level == "domestic_cross_province"
paper_panel$international <- paper_panel$geo_level == "international"
paper_panel$hmt_involved <- paper_panel$geo_level == "hmt_involved"
paper_panel$same_province_multi_city <-
  paper_panel$geo_level == "same_province_multi_city"
paper_panel$single_city <- paper_panel$geo_level == "single_city"

if (anyDuplicated(paper_panel$analysis_paper_id)) {
  stop("Analysis paper IDs are not unique across cases and controls.")
}

saveRDS(
  list(
    generated_on = Sys.Date(),
    family_columns = family_columns,
    paper_panel = paper_panel
  ),
  file.path(processed_dir, "p1", "analysis_paper_panel.rds")
)

sample_flow <- data.frame(
  metric = c(
    "matched_cases",
    "matched_controls",
    "analysis_panel_rows",
    "institution_comparable_cases",
    "institution_comparable_controls",
    "team_size_cases",
    "team_size_controls"
  ),
  value = c(
    sum(case_panel$is_retraction),
    sum(!control_panel$is_retraction),
    nrow(paper_panel),
    sum(case_panel$analysis_institution_eligible),
    sum(control_panel$analysis_institution_eligible),
    sum(case_panel$is_retraction & is.finite(case_panel$team_size)),
    sum(!control_panel$is_retraction & is.finite(control_panel$team_size))
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  sample_flow,
  file.path(audit_table_dir, "p1a_analysis_panel_flow.csv")
)

safe_mean <- function(x) {
  values <- suppressWarnings(as.numeric(x))
  values <- values[is.finite(values)]
  if (length(values) == 0L) {
    return(NA_real_)
  }
  mean(values)
}

safe_median <- function(x) {
  values <- suppressWarnings(as.numeric(x))
  values <- values[is.finite(values)]
  if (length(values) == 0L) {
    return(NA_real_)
  }
  stats::median(values)
}

safe_share <- function(x) {
  values <- as.logical(x)
  values <- values[!is.na(values)]
  if (length(values) == 0L) {
    return(NA_real_)
  }
  mean(values)
}

safe_difference <- function(x, y) {
  if (!is.finite(x) || !is.finite(y)) {
    return(NA_real_)
  }
  x - y
}

family_comparison_rows <- lapply(family_columns, function(family) {
  family_cases <- paper_panel[
    paper_panel$is_retraction & paper_panel[[family]] %in% TRUE,
    ,
    drop = FALSE
  ]
  family_controls <- paper_panel[
    !paper_panel$is_retraction &
      paper_panel$match_group %in% family_cases$match_group,
    ,
    drop = FALSE
  ]
  structural_cases <- family_cases[
    family_cases$analysis_institution_eligible &
      family_cases$institution_observed,
    ,
    drop = FALSE
  ]
  structural_controls <- family_controls[
    family_controls$analysis_institution_eligible &
      family_controls$institution_observed,
    ,
    drop = FALSE
  ]

  case_cross_tier <- safe_share(structural_cases$cross_tier)
  control_cross_tier <- safe_share(structural_controls$cross_tier)
  case_international <- safe_share(structural_cases$international)
  control_international <- safe_share(structural_controls$international)
  case_cross_province <- safe_share(
    structural_cases$domestic_cross_province
  )
  control_cross_province <- safe_share(
    structural_controls$domestic_cross_province
  )
  case_single_city <- safe_share(structural_cases$single_city)
  control_single_city <- safe_share(structural_controls$single_city)
  case_same_province <- safe_share(
    structural_cases$same_province_multi_city
  )
  control_same_province <- safe_share(
    structural_controls$same_province_multi_city
  )
  case_hmt <- safe_share(structural_cases$hmt_involved)
  control_hmt <- safe_share(structural_controls$hmt_involved)
  case_national_key <- safe_share(structural_cases$national_key_present)
  control_national_key <- safe_share(
    structural_controls$national_key_present
  )

  data.frame(
    analysis_family = family,
    matched_cases = nrow(family_cases),
    matched_controls = nrow(family_controls),
    institution_cases = nrow(structural_cases),
    institution_controls = nrow(structural_controls),
    case_mean_team_size = safe_mean(family_cases$team_size),
    control_mean_team_size = safe_mean(family_controls$team_size),
    team_size_difference = safe_difference(
      safe_mean(family_cases$team_size),
      safe_mean(family_controls$team_size)
    ),
    team_size_smd = analysis_standardized_mean_difference(
      family_cases$team_size,
      family_controls$team_size
    ),
    case_cross_tier_share = case_cross_tier,
    control_cross_tier_share = control_cross_tier,
    cross_tier_difference = safe_difference(
      case_cross_tier,
      control_cross_tier
    ),
    case_national_key_share = case_national_key,
    control_national_key_share = control_national_key,
    national_key_difference = safe_difference(
      case_national_key,
      control_national_key
    ),
    case_international_share = case_international,
    control_international_share = control_international,
    international_difference = safe_difference(
      case_international,
      control_international
    ),
    case_cross_province_share = case_cross_province,
    control_cross_province_share = control_cross_province,
    cross_province_difference = safe_difference(
      case_cross_province,
      control_cross_province
    ),
    case_hmt_share = case_hmt,
    control_hmt_share = control_hmt,
    hmt_difference = safe_difference(case_hmt, control_hmt),
    case_single_city_share = case_single_city,
    control_single_city_share = control_single_city,
    single_city_difference = safe_difference(
      case_single_city,
      control_single_city
    ),
    case_same_province_share = case_same_province,
    control_same_province_share = control_same_province,
    same_province_difference = safe_difference(
      case_same_province,
      control_same_province
    ),
    case_median_domestic_distance_km = safe_median(
      structural_cases$median_domestic_geo_distance_km
    ),
    control_median_domestic_distance_km = safe_median(
      structural_controls$median_domestic_geo_distance_km
    ),
    median_distance_difference_km = safe_difference(
      safe_median(structural_cases$median_domestic_geo_distance_km),
      safe_median(structural_controls$median_domestic_geo_distance_km)
    ),
    case_positive_distance_share = safe_share(
      structural_cases$median_domestic_geo_distance_km > 0
    ),
    control_positive_distance_share = safe_share(
      structural_controls$median_domestic_geo_distance_km > 0
    ),
    positive_distance_difference = safe_difference(
      safe_share(structural_cases$median_domestic_geo_distance_km > 0),
      safe_share(structural_controls$median_domestic_geo_distance_km > 0)
    ),
    stringsAsFactors = FALSE
  )
})
family_comparison <- data.table::rbindlist(
  family_comparison_rows,
  fill = TRUE
)
write_csv_utf8(
  as.data.frame(family_comparison),
  file.path(audit_table_dir, "p1a_family_structural_comparison.csv")
)

family_selection_rows <- lapply(family_columns, function(family) {
  family_all <- cases[cases[[family]] %in% TRUE, , drop = FALSE]
  family_matched <- family_all[
    family_all$sample_matched_any,
    ,
    drop = FALSE
  ]
  family_institution <- family_all[
    family_all$sample_institution_compare,
    ,
    drop = FALSE
  ]
  data.frame(
    analysis_family = family,
    all_cases = nrow(family_all),
    matched_cases = nrow(family_matched),
    institution_comparable_cases = nrow(family_institution),
    matched_share = nrow(family_matched) / nrow(family_all),
    institution_comparable_share = nrow(family_institution) / nrow(family_all),
    all_mean_team_size = safe_mean(family_all$team_size),
    matched_mean_team_size = safe_mean(family_matched$team_size),
    institution_mean_team_size = safe_mean(family_institution$team_size),
    all_share_2023 = safe_share(family_all$retraction_year_first == 2023L),
    matched_share_2023 = safe_share(
      family_matched$retraction_year_first == 2023L
    ),
    institution_share_2023 = safe_share(
      family_institution$retraction_year_first == 2023L
    ),
    all_network_complete_share = safe_share(
      family_all$network_complete
    ),
    matched_network_complete_share = safe_share(
      family_matched$network_complete
    ),
    institution_network_complete_share = safe_share(
      family_institution$network_complete
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
  file.path(audit_table_dir, "p1a_family_sample_selection.csv")
)

geo_levels <- c(
  "single_city",
  "same_province_multi_city",
  "domestic_cross_province",
  "hmt_involved",
  "international",
  "unknown"
)
geo_rows <- list()
for (family in family_columns) {
  case_group <- paper_panel[
    paper_panel$is_retraction &
      paper_panel[[family]] %in% TRUE &
      paper_panel$analysis_institution_eligible &
      paper_panel$institution_observed,
    ,
    drop = FALSE
  ]
  control_group <- paper_panel[
    !paper_panel$is_retraction &
      paper_panel$match_group %in% case_group$match_group &
      paper_panel$analysis_institution_eligible &
      paper_panel$institution_observed,
    ,
    drop = FALSE
  ]
  for (group_name in c("case", "control")) {
    group_data <- if (group_name == "case") case_group else control_group
    for (level in geo_levels) {
      geo_rows[[length(geo_rows) + 1L]] <- data.frame(
        analysis_family = family,
        group = group_name,
        geo_level = level,
        papers = sum(group_data$geo_level == level, na.rm = TRUE),
        group_papers = nrow(group_data),
        share = if (nrow(group_data) == 0L) {
          NA_real_
        } else {
          sum(group_data$geo_level == level, na.rm = TRUE) / nrow(group_data)
        },
        stringsAsFactors = FALSE
      )
    }
  }
}
geo_composition <- data.table::rbindlist(geo_rows, fill = TRUE)
write_csv_utf8(
  as.data.frame(geo_composition),
  file.path(audit_table_dir, "p1a_geo_level_composition.csv")
)

team_bins <- c("1", "2", "3", "4", "5", "6-10", "11+")
team_bin <- function(x) {
  ifelse(
    is.na(x),
    NA_character_,
    ifelse(x <= 5L, as.character(x), ifelse(x <= 10L, "6-10", "11+"))
  )
}
paper_panel$team_size_bin <- team_bin(paper_panel$team_size)
team_rows <- list()
for (family in family_columns) {
  case_group <- paper_panel[
    paper_panel$is_retraction & paper_panel[[family]] %in% TRUE,
    ,
    drop = FALSE
  ]
  control_group <- paper_panel[
    !paper_panel$is_retraction &
      paper_panel$match_group %in% case_group$match_group,
    ,
    drop = FALSE
  ]
  for (group_name in c("case", "control")) {
    group_data <- if (group_name == "case") case_group else control_group
    for (bin in team_bins) {
      team_rows[[length(team_rows) + 1L]] <- data.frame(
        analysis_family = family,
        group = group_name,
        team_size_bin = bin,
        papers = sum(group_data$team_size_bin == bin, na.rm = TRUE),
        group_papers = nrow(group_data),
        share = if (nrow(group_data) == 0L) {
          NA_real_
        } else {
          sum(group_data$team_size_bin == bin, na.rm = TRUE) /
            nrow(group_data)
        },
        stringsAsFactors = FALSE
      )
    }
  }
}
team_composition <- data.table::rbindlist(team_rows, fill = TRUE)
write_csv_utf8(
  as.data.frame(team_composition),
  file.path(audit_table_dir, "p1a_team_size_composition.csv")
)

layer_rows <- list()
for (family in family_columns) {
  case_group <- paper_panel[
    paper_panel$is_retraction & paper_panel[[family]] %in% TRUE,
    ,
    drop = FALSE
  ]
  control_group <- paper_panel[
    !paper_panel$is_retraction &
      paper_panel$match_group %in% case_group$match_group,
    ,
    drop = FALSE
  ]
  for (group_name in c("case", "control")) {
    group_data <- if (group_name == "case") case_group else control_group
    layers <- sort(unique(group_data$match_layer[
      !is.na(group_data$match_layer)
    ]))
    for (layer in layers) {
      layer_rows[[length(layer_rows) + 1L]] <- data.frame(
        analysis_family = family,
        group = group_name,
        match_layer = layer,
        papers = sum(group_data$match_layer == layer, na.rm = TRUE),
        group_papers = nrow(group_data),
        share = sum(group_data$match_layer == layer, na.rm = TRUE) /
          nrow(group_data),
        stringsAsFactors = FALSE
      )
    }
  }
}
layer_composition <- data.table::rbindlist(layer_rows, fill = TRUE)
write_csv_utf8(
  as.data.frame(layer_composition),
  file.path(audit_table_dir, "p1a_match_layer_composition.csv")
)

write_audit_manifest()
message("P1A paper panel and family descriptives completed.")
