#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/openalex_parse.R", encoding = "UTF-8")
source("R/lib/title_similarity.R", encoding = "UTF-8")

input_path <- file.path(
  processed_dir,
  "p0",
  "china_candidate_panel.rds"
)
if (!file.exists(input_path)) {
  stop("Run R/04_screen_china.R first. Missing: ", input_path)
}

cache_root <- file.path(
  project_dir,
  project_config$paths$cache,
  "openalex",
  "p0",
  "works-batches"
)
candidate_panel <- readRDS(input_path)
parsed <- parse_openalex_cache(cache_root, candidate_panel)

if (nrow(parsed$request_audit) == 0) {
  stop("No OpenAlex p0 fetch metadata found in: ", cache_root)
}

requested <- parsed$requested_panel
exact_works <- parsed$works[
  which(parsed$works$match_status == "exact"),
  ,
  drop = FALSE
]
exact_works <- exact_works[!duplicated(exact_works$doi_canonical), , drop = FALSE]
exact_works$candidate_title <- requested$title[
  match(exact_works$paper_key, requested$paper_key)
]
exact_works$title_jaccard <- token_jaccard(
  exact_works$candidate_title,
  exact_works$openalex_title
)
exact_works$title_containment <- token_containment(
  exact_works$candidate_title,
  exact_works$openalex_title
)
exact_works$title_linkage_status <- ifelse(
  !is.na(exact_works$title_containment) &
    exact_works$title_containment < 0.2,
  "excluded_title_mismatch",
  "accepted"
)
exact_authorships <- parsed$authorships[
  which(parsed$authorships$match_status == "exact"),
  ,
  drop = FALSE
]
doi_less_works <- parsed$works[
  is.na(parsed$works$doi_canonical),
  ,
  drop = FALSE
]
unmatched_returned_works <- parsed$works[
  which(is.na(parsed$works$match_status)),
  ,
  drop = FALSE
]
mainland_works_all <- exact_works[
  which(exact_works$confirmed_mainland),
  ,
  drop = FALSE
]
mainland_works <- mainland_works_all[
  which(mainland_works_all$title_linkage_status == "accepted"),
  ,
  drop = FALSE
]
title_mismatch_excluded <- mainland_works_all[
  which(
    mainland_works_all$title_linkage_status == "excluded_title_mismatch"
  ),
  ,
  drop = FALSE
]
mainland_institution_complete <- mainland_works[
  which(mainland_works$all_authors_have_institution),
  ,
  drop = FALSE
]
mainland_network_complete <- mainland_works[
  which(
    mainland_works$all_authors_have_institution &
      mainland_works$all_authors_have_id
  ),
  ,
  drop = FALSE
]
mainland_authorships <- exact_authorships[
  exact_authorships$paper_key %in% mainland_works$paper_key,
  ,
  drop = FALSE
]
work_columns_for_join <- setdiff(
  names(exact_works),
  c("doi_canonical", "match_status")
)
openalex_paper_panel <- merge(
  requested,
  exact_works[, work_columns_for_join, drop = FALSE],
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)
mainland_paper_panel <- openalex_paper_panel[
  which(openalex_paper_panel$confirmed_mainland),
  ,
  drop = FALSE
]
mainland_analysis_paper_panel <- mainland_paper_panel[
  which(mainland_paper_panel$title_linkage_status == "accepted"),
  ,
  drop = FALSE
]
institution_complete_paper_panel <- mainland_analysis_paper_panel[
  which(mainland_analysis_paper_panel$all_authors_have_institution),
  ,
  drop = FALSE
]
network_complete_paper_panel <- mainland_analysis_paper_panel[
  which(
    mainland_analysis_paper_panel$all_authors_have_institution &
      mainland_analysis_paper_panel$all_authors_have_id
  ),
  ,
  drop = FALSE
]

processed_p0_dir <- file.path(processed_dir, "p0")
saveRDS(
  parsed$requested_panel,
  file.path(processed_p0_dir, "openalex_work_panel.rds")
)
saveRDS(
  parsed$works,
  file.path(processed_p0_dir, "openalex_works_long.rds")
)
saveRDS(
  exact_works,
  file.path(processed_p0_dir, "openalex_works_exact.rds")
)
saveRDS(
  exact_authorships,
  file.path(processed_p0_dir, "authorships_long.rds")
)
saveRDS(
  mainland_works,
  file.path(processed_p0_dir, "openalex_mainland_works.rds")
)
saveRDS(
  mainland_institution_complete,
  file.path(processed_p0_dir, "openalex_mainland_institution_complete.rds")
)
saveRDS(
  mainland_network_complete,
  file.path(processed_p0_dir, "openalex_mainland_network_complete.rds")
)
saveRDS(
  mainland_authorships,
  file.path(processed_p0_dir, "mainland_authorships_long.rds")
)
saveRDS(
  openalex_paper_panel,
  file.path(processed_p0_dir, "openalex_paper_panel.rds")
)
saveRDS(
  mainland_paper_panel,
  file.path(processed_p0_dir, "openalex_mainland_paper_panel.rds")
)
saveRDS(
  mainland_works_all,
  file.path(processed_p0_dir, "openalex_mainland_works_all.rds")
)
saveRDS(
  mainland_works,
  file.path(processed_p0_dir, "openalex_mainland_accepted_works.rds")
)
saveRDS(
  title_mismatch_excluded,
  file.path(processed_p0_dir, "openalex_title_mismatch_excluded.rds")
)
saveRDS(
  mainland_analysis_paper_panel,
  file.path(processed_p0_dir, "openalex_mainland_accepted_paper_panel.rds")
)
saveRDS(
  institution_complete_paper_panel,
  file.path(
    processed_p0_dir,
    "openalex_mainland_institution_complete_paper_panel.rds"
  )
)
saveRDS(
  network_complete_paper_panel,
  file.path(
    processed_p0_dir,
    "openalex_mainland_network_complete_paper_panel.rds"
  )
)
write_csv_utf8(
  doi_less_works[
    ,
    c(
      "batch_id",
      "openalex_work_id",
      "openalex_title",
      "publication_year",
      "publication_date",
      "openalex_type",
      "is_retracted"
    ),
    drop = FALSE
  ],
  file.path(audit_table_dir, "p0_openalex_doi_less_works.csv")
)
write_csv_utf8(
  unmatched_returned_works[
    ,
    c(
      "batch_id",
      "doi_canonical",
      "openalex_work_id",
      "openalex_title",
      "publication_year",
      "publication_date",
      "openalex_type",
      "is_retracted"
    ),
    drop = FALSE
  ],
  file.path(audit_table_dir, "p0_openalex_unmatched_returned_works.csv")
)

match_summary <- data.frame(
  metric = c(
    "candidate_dois",
    "requested_dois",
    "http_success_dois",
    "returned_works",
    "doi_less_returned_works",
    "unmatched_returned_works",
    "exact_single_doi_matches",
    "multiple_exact_matches",
    "not_found_dois",
    "failed_dois",
    "openalex_confirmed_mainland",
    "hmt_present_exact",
    "hmt_only_excluded",
    "mainland_with_hmt_institution",
    "title_mismatch_excluded",
    "mainland_analysis_eligible",
    "institution_complete",
    "institution_complete_mainland",
    "all_author_ids_mainland",
    "network_complete_mainland",
    "works_without_author_records",
    "country_complete",
    "source_present",
    "topic_present",
    "funders_present",
    "awards_present"
  ),
  value = c(
    nrow(candidate_panel),
    nrow(requested),
    sum(requested$openalex_http_status == 200L),
    nrow(parsed$works),
    nrow(doi_less_works),
    nrow(unmatched_returned_works),
    sum(requested$match_status == "exact"),
    sum(requested$match_status == "multiple_exact"),
    sum(requested$match_status == "not_found"),
    sum(requested$match_status == "failed"),
    sum(exact_works$confirmed_mainland, na.rm = TRUE),
    sum(exact_works$hmt_present, na.rm = TRUE),
    sum(exact_works$hmt_only, na.rm = TRUE),
    sum(
      mainland_works_all$confirmed_mainland &
        mainland_works_all$hmt_present,
      na.rm = TRUE
    ),
    nrow(title_mismatch_excluded),
    nrow(mainland_works),
    sum(exact_works$all_authors_have_institution, na.rm = TRUE),
    nrow(mainland_institution_complete),
    sum(mainland_works$all_authors_have_id, na.rm = TRUE),
    nrow(mainland_network_complete),
    sum(exact_works$n_authorships == 0L, na.rm = TRUE),
    sum(exact_works$all_authors_have_country, na.rm = TRUE),
    sum(exact_works$source_present, na.rm = TRUE),
    sum(exact_works$topic_present, na.rm = TRUE),
    sum(exact_works$funders_present, na.rm = TRUE),
    sum(exact_works$awards_present, na.rm = TRUE)
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  match_summary,
  file.path(audit_table_dir, "p0_openalex_match_summary.csv")
)

openalex_sample_flow <- data.frame(
  stage = c(
    "china_candidate_dois",
    "exact_single_doi_matches",
    "confirmed_mainland",
    "title_mismatch_excluded",
    "mainland_analysis_eligible",
    "hmt_only_excluded",
    "mainland_institution_complete",
    "mainland_all_author_ids",
    "mainland_network_complete"
  ),
  works = c(
    nrow(candidate_panel),
    sum(requested$match_status == "exact"),
    nrow(mainland_works_all),
    nrow(title_mismatch_excluded),
    nrow(mainland_works),
    sum(exact_works$hmt_only, na.rm = TRUE),
    nrow(mainland_institution_complete),
    sum(mainland_works$all_authors_have_id, na.rm = TRUE),
    nrow(mainland_network_complete)
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  openalex_sample_flow,
  file.path(audit_table_dir, "p0_openalex_sample_flow.csv")
)

coverage_by_year <- aggregate(
  cbind(
    requested = rep(1L, nrow(requested)),
    exact = as.integer(requested$match_status == "exact")
  ),
  list(retraction_year = requested$retraction_year_first),
  sum
)
if (nrow(exact_works) > 0) {
  work_with_year <- merge(
    exact_works[
      ,
      c(
        "paper_key",
        "confirmed_mainland",
        "all_authors_have_institution"
      ),
      drop = FALSE
    ],
    requested[, c("paper_key", "retraction_year_first"), drop = FALSE],
    by = "paper_key",
    all.x = TRUE
  )
  work_year <- aggregate(
    cbind(
      confirmed_mainland = as.integer(work_with_year$confirmed_mainland),
      institution_complete = as.integer(
        work_with_year$all_authors_have_institution
      )
    ),
    list(retraction_year = work_with_year$retraction_year_first),
    sum
  )
  coverage_by_year <- merge(coverage_by_year, work_year, by = "retraction_year")
}
write_csv_utf8(
  coverage_by_year,
  file.path(audit_table_dir, "p0_openalex_coverage_by_retraction_year.csv")
)

failure_table <- requested[
  requested$match_status != "exact",
  c(
    "paper_key",
    "doi_canonical",
    "match_status",
    "openalex_http_status",
    "returned_work_count",
    "retraction_year_first"
  ),
  drop = FALSE
]
write_csv_utf8(
  failure_table,
  file.path(audit_table_dir, "p0_openalex_failures.csv")
)

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
family_coverage <- do.call(
  rbind,
  lapply(family_columns, function(column) {
    requested_subset <- requested[requested[[column]], , drop = FALSE]
    mainland_subset <- mainland_paper_panel[
      mainland_paper_panel[[column]],
      ,
      drop = FALSE
    ]
    institution_subset <- institution_complete_paper_panel[
      institution_complete_paper_panel[[column]],
      ,
      drop = FALSE
    ]
    network_subset <- network_complete_paper_panel[
      network_complete_paper_panel[[column]],
      ,
      drop = FALSE
    ]
    data.frame(
      reason_family = sub("^family_", "", column),
      requested = nrow(requested_subset),
      exact = sum(requested_subset$match_status == "exact"),
      confirmed_mainland = nrow(mainland_subset),
      institution_complete = nrow(institution_subset),
      network_complete = nrow(network_subset),
      stringsAsFactors = FALSE
    )
  })
)
family_coverage$exact_rate <- ifelse(
  family_coverage$requested > 0,
  family_coverage$exact / family_coverage$requested,
  NA_real_
)
family_coverage$mainland_confirmation_rate <- ifelse(
  family_coverage$exact > 0,
  family_coverage$confirmed_mainland / family_coverage$exact,
  NA_real_
)
write_csv_utf8(
  family_coverage,
  file.path(audit_table_dir, "p0_openalex_coverage_by_reason_family.csv")
)

write_audit_manifest()
message("P0 OpenAlex parse completed.")
