#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

sample_plan <- data.table::fread(
  file.path(audit_table_dir, "p1_control_sample_plan.csv"),
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
sample_plan$sample_batch <- as.integer(sample_plan$sample_batch)
sample_plan$sample_size <- as.integer(sample_plan$sample_size)
sample_plan$seed <- as.integer(sample_plan$seed)
sample_plan$request_id <- paste0(
  sample_plan$control_layer_id,
  "_sample_",
  sprintf("%02d", sample_plan$sample_batch)
)

cache_root <- file.path(
  project_dir,
  project_config$paths$cache,
  "openalex",
  "p1",
  "control-pools"
)
sample_plan$cache_path <- file.path(
  cache_root,
  paste0(sample_plan$request_id, ".json")
)
if (any(!file.exists(sample_plan$cache_path))) {
  stop("Missing control pool cache files.")
}

case_panel <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_cases.rds"
))
case_lookup <- case_panel[
  ,
  c("paper_key", "control_stratum"),
  drop = FALSE
]
layer_cases <- aggregate(
  case_lookup$paper_key,
  list(control_stratum = case_lookup$control_stratum),
  length
)
names(layer_cases)[[2]] <- "cases"

rows <- list()
for (index in seq_len(nrow(sample_plan))) {
  response <- jsonlite::read_json(
    sample_plan$cache_path[[index]],
    simplifyVector = FALSE
  )
  works <- response$results
  if (is.null(works) || length(works) == 0L) {
    next
  }
  for (work_index in seq_along(works)) {
    work <- works[[work_index]]
    topic <- work$primary_topic
    source <- work$primary_location$source
    rows[[length(rows) + 1L]] <- data.frame(
      control_layer_id = sample_plan$control_layer_id[[index]],
      request_id = sample_plan$request_id[[index]],
      openalex_work_id = if (is.null(work$id)) {
        NA_character_
      } else {
        work$id
      },
      doi_canonical = if (
        is.null(work$doi) || length(work$doi) == 0L
      ) {
        NA_character_
      } else {
        normalize_doi(work$doi)
      },
      title = if (is.null(work$title)) NA_character_ else work$title,
      publication_year = if (is.null(work$publication_year)) {
        NA_integer_
      } else {
        as.integer(work$publication_year)
      },
      publication_date = if (is.null(work$publication_date)) {
        NA_character_
      } else {
        work$publication_date
      },
      openalex_type = if (is.null(work$type)) NA_character_ else work$type,
      is_retracted = isTRUE(work$is_retracted),
      source_id = if (is.null(source$id)) {
        NA_character_
      } else {
        source$id
      },
      source_name = if (is.null(source$display_name)) {
        NA_character_
      } else {
        source$display_name
      },
      publisher_id = if (is.null(source$host_organization)) {
        NA_character_
      } else {
        source$host_organization
      },
      publisher_name = if (is.null(source$host_organization_name)) {
        NA_character_
      } else {
        source$host_organization_name
      },
      primary_topic_id = if (is.null(topic$id)) {
        NA_character_
      } else {
        topic$id
      },
      primary_topic_name = if (is.null(topic$display_name)) {
        NA_character_
      } else {
        topic$display_name
      },
      subfield_id = if (is.null(topic$subfield$id)) {
        NA_character_
      } else {
        topic$subfield$id
      },
      field_id = if (is.null(topic$field$id)) {
        NA_character_
      } else {
        topic$field$id
      },
      domain_id = if (is.null(topic$domain$id)) {
        NA_character_
      } else {
        topic$domain$id
      },
      stringsAsFactors = FALSE
    )
  }
  if (index %% 500L == 0L || index == nrow(sample_plan)) {
    message("parsed ", index, "/", nrow(sample_plan))
  }
}

candidates <- do.call(rbind, rows)
candidates$source_id_short <- sub(
  "^https://openalex\\.org/",
  "",
  candidates$source_id
)
candidates$control_stratum <- paste(
  candidates$source_id_short,
  candidates$publication_year,
  candidates$openalex_type,
  sep = "|"
)

layer_plan <- data.table::fread(
  file.path(audit_table_dir, "p1_control_layer_plan.csv"),
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
candidates$expected_layer_id <- layer_plan$control_layer_id[
  match(candidates$control_stratum, layer_plan$control_stratum)
]
validation <- data.frame(
  metric = c(
    "raw_candidate_rows",
    "unique_openalex_work_ids",
    "unique_dois",
    "retracted_flagged",
    "layer_mismatch_rows",
    "missing_work_id"
  ),
  value = c(
    nrow(candidates),
    length(unique(candidates$openalex_work_id)),
    length(unique(candidates$doi_canonical)),
    sum(candidates$is_retracted),
    sum(
      is.na(candidates$expected_layer_id) |
        candidates$expected_layer_id != candidates$control_layer_id
    ),
    sum(is.na(candidates$openalex_work_id))
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  validation,
  file.path(audit_table_dir, "p1_control_candidate_validation.csv")
)

candidates <- candidates[
  !is.na(candidates$openalex_work_id) &
    !candidates$is_retracted &
    !is.na(candidates$expected_layer_id) &
    candidates$expected_layer_id == candidates$control_layer_id,
  ,
  drop = FALSE
]
candidates <- candidates[
  order(
    candidates$control_layer_id,
    candidates$primary_topic_id,
    candidates$openalex_work_id
  ),
  ,
  drop = FALSE
]
candidates <- candidates[
  !duplicated(candidates$openalex_work_id),
  ,
  drop = FALSE
]

saveRDS(
  candidates,
  file.path(processed_dir, "p1", "control_candidates.rds")
)

pool_summary <- aggregate(
  candidates$openalex_work_id,
  list(control_layer_id = candidates$control_layer_id),
  length
)
names(pool_summary)[[2]] <- "candidate_works"
pool_summary <- merge(
  layer_plan[
    ,
    c("control_layer_id", "control_stratum", "cases"),
    drop = FALSE
  ],
  pool_summary,
  by = "control_layer_id",
  all.x = TRUE
)
pool_summary$cases <- as.integer(pool_summary$cases)
pool_summary$candidate_works[
  is.na(pool_summary$candidate_works)
] <- 0L
pool_summary$candidate_to_case_ratio <- ifelse(
  pool_summary$cases > 0,
  pool_summary$candidate_works / pool_summary$cases,
  NA_real_
)
write_csv_utf8(
  pool_summary,
  file.path(audit_table_dir, "p1_control_pool_by_layer.csv")
)

write_csv_utf8(
  data.frame(
    metric = c(
      "candidate_works",
      "control_layers",
      "layers_with_zero_candidates",
      "layers_with_one_or_more",
      "median_candidates_per_layer",
      "cases_in_zero_pool_layers"
    ),
    value = c(
      nrow(candidates),
      nrow(pool_summary),
      sum(pool_summary$candidate_works == 0L),
      sum(pool_summary$candidate_works > 0L),
      stats::median(pool_summary$candidate_works),
      sum(pool_summary$cases[pool_summary$candidate_works == 0L])
    ),
    stringsAsFactors = FALSE
  ),
  file.path(audit_table_dir, "p1_control_pool_summary.csv")
)

write_audit_manifest()
message("Control pools parsed.")
