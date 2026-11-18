#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

cases <- readRDS(file.path(processed_dir, "p1", "control_cases.rds"))
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
for (doi in unique(control_links$control_doi[
  !is.na(control_links$control_doi)
])) {
  assign(enc2utf8(doi), TRUE, envir = doi_used)
}

candidates_by_key <- split(
  seq_len(nrow(candidates)),
  candidates$fallback_key,
  drop = TRUE
)
cases_with_key <- cases[!is.na(cases$fallback_key), , drop = FALSE]
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
    if (exists(work_id, envir = candidate_used, inherits = FALSE)) {
      next
    }
    if (
      !is.na(doi) &&
        exists(enc2utf8(doi), envir = doi_used, inherits = FALSE)
    ) {
      next
    }
    assign(work_id, TRUE, envir = candidate_used)
    if (!is.na(doi)) {
      assign(enc2utf8(doi), TRUE, envir = doi_used)
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
  fallback_links,
  file.path(processed_dir, "p1", "control_fallback_links.rds")
)

control_ratio <- as.data.frame(
  table(case_match$controls_matched),
  stringsAsFactors = FALSE
)
names(control_ratio) <- c("controls_matched", "cases")
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
      "publisher_fallback_links",
      "control_links",
      "unique_control_works"
    ),
    value = c(
      sum(case_match$controls_matched == 2L),
      sum(case_match$controls_matched == 1L),
      sum(case_match$controls_matched == 0L),
      nrow(fallback_links),
      nrow(control_links),
      length(unique(control_links$openalex_work_id))
    ),
    stringsAsFactors = FALSE
  ),
  file.path(audit_table_dir, "p1_control_fallback_summary.csv")
)

write_audit_manifest()
message("Control publisher fallback completed.")
