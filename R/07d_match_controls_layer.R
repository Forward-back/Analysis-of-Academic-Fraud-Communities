#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

refresh_cache <- "--refresh" %in% commandArgs(trailingOnly = TRUE)
cases <- readRDS(file.path(processed_dir, "p1", "control_cases.rds"))
candidates <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_candidates.rds"
))
layer_plan <- data.table::fread(
  file.path(audit_table_dir, "p1_control_layer_plan.csv"),
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
cases <- cases[cases$control_eligible, , drop = FALSE]
cases$control_layer_id <- layer_plan$control_layer_id[
  match(cases$control_stratum, layer_plan$control_stratum)
]

control_links_path <- file.path(
  processed_dir,
  "p1",
  "control_links.rds"
)
case_match_path <- file.path(
  processed_dir,
  "p1",
  "control_case_match.rds"
)

if (
  !refresh_cache &&
    file.exists(control_links_path) &&
    file.exists(case_match_path)
) {
  message("Using cached control matching results.")
  control_links <- readRDS(control_links_path)
  case_match <- readRDS(case_match_path)
} else {
  level_names <- c(
    "primary_topic",
    "subfield",
    "field",
    "domain",
    "source_only"
  )
  level_columns <- c(
    primary_topic = "primary_topic_id",
    subfield = "subfield_id",
    field = "field_id",
    domain = "domain_id"
  )

  candidate_used <- new.env(hash = TRUE, parent = emptyenv())
  candidate_doi_used <- new.env(hash = TRUE, parent = emptyenv())

  cases_by_layer <- split(cases, cases$control_stratum, drop = TRUE)
  candidates_by_layer <- split(
    candidates,
    candidates$control_stratum,
    drop = TRUE
  )

  match_rows <- list()
  summary_rows <- list()
  for (layer_index in seq_along(cases_by_layer)) {
    layer_name <- names(cases_by_layer)[[layer_index]]
    case_block <- cases_by_layer[[layer_name]]
    candidate_block <- candidates_by_layer[[layer_name]]
    if (is.null(candidate_block)) {
      candidate_block <- candidates[0, , drop = FALSE]
    }
    candidate_block <- candidate_block[
      order(candidate_block$openalex_work_id),
      ,
      drop = FALSE
    ]

    level_maps <- list()
    for (level in names(level_columns)) {
      values <- candidate_block[[level_columns[[level]]]]
      valid <- !is.na(values) & values != ""
      level_maps[[level]] <- if (any(valid)) {
        split(seq_len(nrow(candidate_block))[valid], values[valid])
      } else {
        list()
      }
    }
    level_maps$source_only <- list(
      `__all__` = seq_len(nrow(candidate_block))
    )
    available_indices <- function(indices = seq_len(nrow(candidate_block))) {
      if (length(indices) == 0L) {
        return(integer())
      }
      works <- candidate_block$openalex_work_id[indices]
      dois <- candidate_block$doi_canonical[indices]
      used_work <- vapply(
        works,
        exists,
        logical(1),
        envir = candidate_used,
        inherits = FALSE
      )
      used_doi <- vapply(
        seq_along(dois),
        function(index) {
          !is.na(dois[[index]]) &&
            exists(
              dois[[index]],
              envir = candidate_doi_used,
              inherits = FALSE
            )
        },
        logical(1)
      )
      keep <- !used_work & !used_doi
      indices[keep]
    }

    level_counts <- matrix(
      0L,
      nrow = nrow(case_block),
      ncol = length(level_names),
      dimnames = list(NULL, level_names)
    )
    for (level in names(level_columns)) {
      for (case_index in seq_len(nrow(case_block))) {
        case_value <- case_block[[level_columns[[level]]]][[case_index]]
        if (is.na(case_value) || case_value == "") {
          next
        }
        indices <- level_maps[[level]][[case_value]]
        if (!is.null(indices)) {
          level_counts[case_index, level] <- length(available_indices(indices))
        }
      }
    }
    level_counts[, "source_only"] <- length(available_indices())

    preferred_level <- vapply(seq_len(nrow(case_block)), function(index) {
      for (level in level_names) {
        if (level_counts[index, level] >= 2L) {
          return(level)
        }
      }
      for (level in level_names) {
        if (level_counts[index, level] >= 1L) {
          return(level)
        }
      }
      NA_character_
    }, character(1))
    preferred_count <- vapply(seq_along(preferred_level), function(index) {
      level <- preferred_level[[index]]
      if (is.na(level)) 0L else level_counts[index, level]
    }, integer(1))

    for (case_index in order(preferred_count, case_block$paper_key)) {
      case_key <- case_block$paper_key[[case_index]]
      selected <- integer()
      selected_levels <- character()
      preferred <- preferred_level[[case_index]]
      start_level <- if (is.na(preferred)) {
        length(level_names)
      } else {
        match(preferred, level_names)
      }
      for (level_index in start_level:length(level_names)) {
        level <- level_names[[level_index]]
        if (level == "source_only") {
          indices <- available_indices()
        } else {
          case_value <- case_block[[level_columns[[level]]]][[case_index]]
          if (is.na(case_value) || case_value == "") {
            next
          }
          indices <- available_indices(level_maps[[level]][[case_value]])
        }
        indices <- setdiff(indices, selected)
        if (length(indices) == 0L) {
          next
        }
        take <- head(indices, 2L - length(selected))
        selected <- c(selected, take)
        selected_levels <- c(selected_levels, rep(level, length(take)))
        if (length(selected) >= 2L) {
          break
        }
      }

      if (length(selected) > 0L) {
        for (control_index in seq_along(selected)) {
          candidate_index <- selected[[control_index]]
          candidate <- candidate_block[candidate_index, , drop = FALSE]
          assign(
            candidate$openalex_work_id,
            TRUE,
            envir = candidate_used
          )
          if (!is.na(candidate$doi_canonical)) {
            assign(
              candidate$doi_canonical,
              TRUE,
              envir = candidate_doi_used
            )
          }
          match_rows[[length(match_rows) + 1L]] <- data.frame(
            paper_key = case_key,
            control_layer_id = case_block$control_layer_id[[case_index]],
            control_rank = control_index,
            topic_match_level = selected_levels[[control_index]],
            openalex_work_id = candidate$openalex_work_id,
            control_doi = candidate$doi_canonical,
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
        }
      }
      summary_rows[[length(summary_rows) + 1L]] <- data.frame(
        paper_key = case_key,
        control_layer_id = case_block$control_layer_id[[case_index]],
        controls_matched = length(selected),
        best_available_level = if (length(selected_levels) > 0L) {
          selected_levels[[1]]
        } else {
          NA_character_
        },
        layer_candidate_count = nrow(candidate_block),
        stringsAsFactors = FALSE
      )
    }
    if (layer_index %% 500L == 0L) {
      message("matched layer ", layer_index, "/", length(cases_by_layer))
    }
  }

  control_links <- do.call(rbind, match_rows)
  case_match <- do.call(rbind, summary_rows)
  case_match <- case_match[order(case_match$paper_key), , drop = FALSE]
  saveRDS(control_links, control_links_path)
  saveRDS(case_match, case_match_path)
}

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

case_match_dt <- data.table::as.data.table(case_match)
layer_match <- case_match_dt[
  ,
  .(
    cases = .N,
    matched_two = sum(controls_matched == 2L),
    matched_one = sum(controls_matched == 1L),
    matched_zero = sum(controls_matched == 0L),
    controls = sum(controls_matched)
  ),
  by = control_layer_id
]
candidate_counts <- data.table::as.data.table(candidates)[
  ,
  .(candidate_works = .N),
  by = control_layer_id
]
layer_match <- merge(
  layer_match,
  candidate_counts,
  by = "control_layer_id",
  all.x = TRUE
)
layer_match <- as.data.frame(layer_match)
layer_match$candidate_works[
  is.na(layer_match$candidate_works)
] <- 0L
write_csv_utf8(
  layer_match,
  file.path(audit_table_dir, "p1_control_match_by_layer.csv")
)

write_csv_utf8(
  case_match[case_match$controls_matched == 0L, , drop = FALSE],
  file.path(audit_table_dir, "p1_control_cases_unmatched.csv")
)

write_csv_utf8(
  data.frame(
    metric = c(
      "eligible_cases",
      "cases_with_two_controls",
      "cases_with_one_control",
      "cases_with_zero_controls",
      "control_links",
      "unique_control_works",
      "exact_topic_links",
      "subfield_links",
      "field_links",
      "domain_links",
      "source_only_links"
    ),
    value = c(
      nrow(case_match),
      sum(case_match$controls_matched == 2L),
      sum(case_match$controls_matched == 1L),
      sum(case_match$controls_matched == 0L),
      nrow(control_links),
      length(unique(control_links$openalex_work_id)),
      sum(control_links$topic_match_level == "primary_topic"),
      sum(control_links$topic_match_level == "subfield"),
      sum(control_links$topic_match_level == "field"),
      sum(control_links$topic_match_level == "domain"),
      sum(control_links$topic_match_level == "source_only")
    ),
    stringsAsFactors = FALSE
  ),
  file.path(audit_table_dir, "p1_control_match_summary.csv")
)

write_audit_manifest()
message("Control matching completed.")
