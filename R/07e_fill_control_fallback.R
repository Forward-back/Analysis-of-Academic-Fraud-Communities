#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

cases <- readRDS(file.path(processed_dir, "p1", "control_cases.rds"))
case_paper_count <- nrow(cases)
cases_without_stratum <- sum(!cases$control_eligible)
cases <- cases[cases$control_eligible, , drop = FALSE]
candidates <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_candidates.rds"
))
control_links <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_links.rds"
))
case_match <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_case_match.rds"
))

post_fetch_validation_path <- file.path(
  processed_dir,
  "p1",
  "control_works_full.rds"
)
exclusion_state_path <- file.path(
  processed_dir,
  "p1",
  "control_post_fetch_exclusions.rds"
)
validation_audit_path <- file.path(
  audit_table_dir,
  "p1_post_fetch_link_validation.csv"
)
invalid_work_ids <- character()
validation_audit <- data.frame(
  paper_key = character(),
  openalex_work_id = character(),
  topic_match_level = character(),
  control_rank = integer(),
  expected_publication_year = integer(),
  actual_publication_year = integer(),
  expected_openalex_type = character(),
  actual_openalex_type = character(),
  year_match = logical(),
  type_match = logical(),
  consistent = logical(),
  stringsAsFactors = FALSE
)
post_fetch_exclusions <- if (file.exists(exclusion_state_path)) {
  readRDS(exclusion_state_path)
} else if (file.exists(validation_audit_path)) {
  utils::read.csv(
    validation_audit_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
} else {
  validation_audit
}
if (!"control_rank" %in% names(post_fetch_exclusions)) {
  post_fetch_exclusions$control_rank <- NA_integer_
}
post_fetch_exclusions <- post_fetch_exclusions[
  ,
  names(validation_audit),
  drop = FALSE
]
if (nrow(post_fetch_exclusions) > 0L) {
  exclusion_order <- order(
    is.na(post_fetch_exclusions$control_rank),
    post_fetch_exclusions$paper_key,
    post_fetch_exclusions$openalex_work_id
  )
  post_fetch_exclusions <- post_fetch_exclusions[
    exclusion_order,
    ,
    drop = FALSE
  ]
  exclusion_key <- paste(
    post_fetch_exclusions$paper_key,
    post_fetch_exclusions$openalex_work_id,
    sep = "|"
  )
  post_fetch_exclusions <- post_fetch_exclusions[
    !duplicated(exclusion_key),
    ,
    drop = FALSE
  ]
}
blocked_fallback_cases <- unique(post_fetch_exclusions$paper_key)

if (file.exists(post_fetch_validation_path)) {
  case_types <- readRDS(file.path(
    processed_dir,
    "p0",
    "openalex_mainland_accepted_paper_panel.rds"
  ))
  case_types <- unique(case_types[, c(
    "paper_key",
    "publication_year",
    "openalex_type"
  ), drop = FALSE])
  work_types <- readRDS(post_fetch_validation_path)
  work_types <- unique(work_types[, c(
    "openalex_work_id",
    "publication_year",
    "openalex_type"
  ), drop = FALSE])

  case_index <- match(control_links$paper_key, case_types$paper_key)
  work_index <- match(
    control_links$openalex_work_id,
    work_types$openalex_work_id
  )
  expected_year <- case_types$publication_year[case_index]
  actual_year <- work_types$publication_year[work_index]
  expected_type <- case_types$openalex_type[case_index]
  actual_type <- work_types$openalex_type[work_index]

  year_match <- !is.na(expected_year) &
    !is.na(actual_year) &
    expected_year == actual_year
  type_match <- !is.na(expected_type) &
    !is.na(actual_type) &
    expected_type == actual_type
  consistent <- year_match &
    type_match &
    !control_links$openalex_work_id %in%
      post_fetch_exclusions$openalex_work_id

  validation_audit <- data.frame(
    paper_key = control_links$paper_key,
    openalex_work_id = control_links$openalex_work_id,
    topic_match_level = control_links$topic_match_level,
    control_rank = control_links$control_rank,
    expected_publication_year = expected_year,
    actual_publication_year = actual_year,
    expected_openalex_type = expected_type,
    actual_openalex_type = actual_type,
    year_match = year_match,
    type_match = type_match,
    consistent = consistent,
    stringsAsFactors = FALSE
  )
  post_fetch_exclusions <- unique(rbind(
    post_fetch_exclusions,
    validation_audit[!consistent, , drop = FALSE]
  ))
  if (nrow(post_fetch_exclusions) > 0L) {
    post_fetch_exclusions <- post_fetch_exclusions[
      order(
        is.na(post_fetch_exclusions$control_rank),
        post_fetch_exclusions$paper_key,
        post_fetch_exclusions$openalex_work_id
      ),
      ,
      drop = FALSE
    ]
    exclusion_key <- paste(
      post_fetch_exclusions$paper_key,
      post_fetch_exclusions$openalex_work_id,
      sep = "|"
    )
    post_fetch_exclusions <- post_fetch_exclusions[
      !duplicated(exclusion_key),
      ,
      drop = FALSE
    ]
  }
  saveRDS(
    post_fetch_exclusions,
    exclusion_state_path
  )
  write_csv_utf8(
    post_fetch_exclusions,
    validation_audit_path
  )

  invalid_work_ids <- unique(post_fetch_exclusions$openalex_work_id)
  control_links <- control_links[consistent, , drop = FALSE]
  candidates <- candidates[
    !candidates$openalex_work_id %in% invalid_work_ids,
    ,
    drop = FALSE
  ]
} else {
  write_csv_utf8(
    post_fetch_exclusions,
    validation_audit_path
  )
  if (nrow(post_fetch_exclusions) > 0L) {
    invalid_work_ids <- unique(post_fetch_exclusions$openalex_work_id)
    control_links <- control_links[
      !control_links$openalex_work_id %in% invalid_work_ids,
      ,
      drop = FALSE
    ]
    candidates <- candidates[
      !candidates$openalex_work_id %in% invalid_work_ids,
      ,
      drop = FALSE
    ]
  }
}
blocked_fallback_cases <- unique(post_fetch_exclusions$paper_key)

link_counts <- table(control_links$paper_key)
case_match$controls_matched <- unname(link_counts[case_match$paper_key])
case_match$controls_matched[is.na(case_match$controls_matched)] <- 0L
first_link <- control_links[
  order(control_links$paper_key, control_links$control_rank),
  ,
  drop = FALSE
]
first_link <- first_link[!duplicated(first_link$paper_key), , drop = FALSE]
case_match$best_available_level <- first_link$topic_match_level[
  match(case_match$paper_key, first_link$paper_key)
]

cases$fallback_key <- ifelse(
  is.na(cases$publication_year) |
    is.na(cases$openalex_type) |
    cases$openalex_type == "" |
    is.na(cases$field_id) |
    cases$field_id == "" |
    is.na(cases$host_organization) |
    cases$host_organization == "",
  NA_character_,
  paste(
    cases$publication_year,
    cases$openalex_type,
    cases$field_id,
    cases$host_organization,
    sep = "|"
  )
)
candidates$fallback_key <- paste(
  candidates$publication_year,
  candidates$openalex_type,
  candidates$field_id,
  candidates$publisher_id,
  sep = "|"
)

candidate_used <- new.env(hash = TRUE, parent = emptyenv())
doi_used <- new.env(hash = TRUE, parent = emptyenv())
for (work_id in unique(control_links$openalex_work_id)) {
  assign(work_id, TRUE, envir = candidate_used)
}
doi_keys <- unique(doi_environment_key(control_links$control_doi[
  !is.na(control_links$control_doi)
]))
for (doi_key in doi_keys[!is.na(doi_keys)]) {
  assign(doi_key, TRUE, envir = doi_used)
}

candidates_by_key <- split(
  seq_len(nrow(candidates)),
  candidates$fallback_key,
  drop = TRUE
)
cases_with_key <- cases[!is.na(cases$fallback_key), , drop = FALSE]
cases_with_key <- cases_with_key[
  !cases_with_key$paper_key %in% blocked_fallback_cases,
  ,
  drop = FALSE
]
fallback_available <- vapply(
  cases_with_key$fallback_key,
  function(key) {
    indices <- candidates_by_key[[key]]
    if (is.null(indices)) 0L else length(indices)
  },
  integer(1)
)
cases_with_key <- cases_with_key[
  order(fallback_available, cases_with_key$paper_key),
  ,
  drop = FALSE
]
next_position <- setNames(
  rep(1L, length(candidates_by_key)),
  names(candidates_by_key)
)

current_match <- setNames(
  case_match$controls_matched,
  case_match$paper_key
)
best_level <- setNames(
  case_match$best_available_level,
  case_match$paper_key
)
new_rows <- list()

for (case_index in seq_len(nrow(cases_with_key))) {
  case_key <- cases_with_key$paper_key[[case_index]]
  needed <- 2L - current_match[[case_key]]
  if (needed <= 0L) {
    next
  }
  indices <- candidates_by_key[[cases_with_key$fallback_key[[case_index]]]]
  if (is.null(indices) || length(indices) == 0L) {
    next
  }
  key <- cases_with_key$fallback_key[[case_index]]
  position <- next_position[[key]]
  next_rank <- current_match[[case_key]] + 1L
  while (position <= length(indices) && needed > 0L) {
    candidate_index <- indices[[position]]
    position <- position + 1L
    candidate <- candidates[candidate_index, , drop = FALSE]
    work_id <- candidate$openalex_work_id
    doi <- candidate$doi_canonical
    doi_key <- doi_environment_key(doi)
    if (exists(work_id, envir = candidate_used, inherits = FALSE)) {
      next
    }
    if (
      !is.na(doi_key) &&
        exists(doi_key, envir = doi_used, inherits = FALSE)
    ) {
      next
    }
    assign(work_id, TRUE, envir = candidate_used)
    if (!is.na(doi_key)) {
      assign(doi_key, TRUE, envir = doi_used)
    }
    new_rows[[length(new_rows) + 1L]] <- data.frame(
      paper_key = case_key,
      control_layer_id = case_match$control_layer_id[
        match(case_key, case_match$paper_key)
      ],
      control_rank = next_rank,
      topic_match_level = "publisher_fallback",
      openalex_work_id = work_id,
      control_doi = doi,
      control_title = candidate$title,
      control_publication_year = candidate$publication_year,
      control_source_id = candidate$source_id,
      control_source_name = candidate$source_name,
      control_publisher_name = candidate$publisher_name,
      control_primary_topic_id = candidate$primary_topic_id,
      control_subfield_id = candidate$subfield_id,
      control_field_id = candidate$field_id,
      control_domain_id = candidate$domain_id,
      stringsAsFactors = FALSE
    )
    current_match[[case_key]] <- current_match[[case_key]] + 1L
    next_rank <- next_rank + 1L
    if (is.na(best_level[[case_key]])) {
      best_level[[case_key]] <- "publisher_fallback"
    }
    needed <- needed - 1L
  }
  next_position[[key]] <- position
}

if (length(new_rows) > 0L) {
  fallback_links <- do.call(rbind, new_rows)
  control_links <- rbind(control_links, fallback_links)
} else {
  fallback_links <- control_links[0, , drop = FALSE]
}
fallback_links_total <- control_links[
  control_links$topic_match_level == "publisher_fallback",
  ,
  drop = FALSE
]

case_match$controls_matched <- as.integer(current_match[case_match$paper_key])
case_match$best_available_level <- unname(best_level[case_match$paper_key])
case_match <- case_match[order(case_match$paper_key), , drop = FALSE]

saveRDS(
  control_links,
  file.path(processed_dir, "p1", "control_links.rds")
)
saveRDS(
  case_match,
  file.path(processed_dir, "p1", "control_case_match.rds")
)
saveRDS(
  fallback_links_total,
  file.path(processed_dir, "p1", "control_fallback_links.rds")
)

eligible_control_ratio <- as.data.frame(
  table(case_match$controls_matched),
  stringsAsFactors = FALSE
)
names(eligible_control_ratio) <- c("controls_matched", "cases")
write_csv_utf8(
  eligible_control_ratio,
  file.path(audit_table_dir, "p1_control_match_ratio_eligible.csv")
)

control_ratio <- data.frame(
  controls_matched = c("0", "1", "2"),
  cases = c(
    cases_without_stratum + sum(case_match$controls_matched == 0L),
    sum(case_match$controls_matched == 1L),
    sum(case_match$controls_matched == 2L)
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  control_ratio,
  file.path(audit_table_dir, "p1_control_match_ratio.csv")
)

match_level <- as.data.frame(
  table(control_links$topic_match_level),
  stringsAsFactors = FALSE
)
names(match_level) <- c("topic_match_level", "control_links")
write_csv_utf8(
  match_level,
  file.path(audit_table_dir, "p1_control_match_level.csv")
)

write_csv_utf8(
  case_match[case_match$controls_matched == 0L, , drop = FALSE],
  file.path(audit_table_dir, "p1_control_cases_unmatched.csv")
)

write_csv_utf8(
  data.frame(
    metric = c(
      "cases_with_two_controls",
      "cases_with_one_control",
      "cases_with_zero_controls",
      "post_fetch_excluded_links",
      "fallback_blocked_cases",
      "publisher_fallback_links",
      "control_links",
      "unique_control_works"
    ),
    value = c(
      sum(case_match$controls_matched == 2L),
      sum(case_match$controls_matched == 1L),
      sum(case_match$controls_matched == 0L),
      nrow(post_fetch_exclusions),
      length(blocked_fallback_cases),
      nrow(fallback_links_total),
      nrow(control_links),
      length(unique(control_links$openalex_work_id))
    ),
    stringsAsFactors = FALSE
  ),
  file.path(audit_table_dir, "p1_control_fallback_summary.csv")
)

write_csv_utf8(
  data.frame(
    metric = c(
      "main_sample_cases",
      "control_eligible_cases",
      "cases_without_stratum",
      "main_sample_zero_controls",
      "cases_with_one_control",
      "cases_with_two_controls"
    ),
    value = c(
      case_paper_count,
      nrow(case_match),
      cases_without_stratum,
      cases_without_stratum + sum(case_match$controls_matched == 0L),
      sum(case_match$controls_matched == 1L),
      sum(case_match$controls_matched == 2L)
    ),
    stringsAsFactors = FALSE
  ),
  file.path(audit_table_dir, "p1_control_integrity_summary.csv")
)

write_audit_manifest()
message("Control publisher fallback completed.")
