#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

input_path <- file.path(
  processed_dir,
  "p0",
  "openalex_mainland_accepted_paper_panel.rds"
)
if (!file.exists(input_path)) {
  stop("Run R/06_build_authorships.R first. Missing: ", input_path)
}

cases <- readRDS(input_path)
required_case_columns <- c(
  "paper_key",
  "doi_canonical",
  "publication_year",
  "openalex_type",
  "source_id",
  "primary_topic_id",
  "subfield_id",
  "field_id",
  "domain_id"
)
assert_columns(cases, required_case_columns, "Mainland accepted paper panel")

cases$source_id_short <- sub(
  "^https://openalex\\.org/",
  "",
  cases$source_id
)
cases$topic_id_short <- sub(
  "^https://openalex\\.org/",
  "",
  cases$primary_topic_id
)
cases$subfield_id_short <- sub(
  "^https://openalex\\.org/",
  "",
  cases$subfield_id
)
cases$field_id_short <- sub(
  "^https://openalex\\.org/",
  "",
  cases$field_id
)
cases$domain_id_short <- sub(
  "^https://openalex\\.org/",
  "",
  cases$domain_id
)

cases$control_stratum <- ifelse(
  is.na(cases$source_id_short) |
    cases$source_id_short == "" |
    is.na(cases$publication_year) |
    is.na(cases$openalex_type) |
    cases$openalex_type == "",
  NA_character_,
  paste(
    cases$source_id_short,
    cases$publication_year,
    cases$openalex_type,
    sep = "|"
  )
)
cases$control_eligible <- !is.na(cases$control_stratum)
cases$control_exclusion_reason <- ifelse(
  cases$control_eligible,
  "",
  ifelse(
    is.na(cases$source_id_short) | cases$source_id_short == "",
    "missing_source",
    "missing_year_or_type"
  )
)

eligible <- cases[cases$control_eligible, , drop = FALSE]
stratum_counts <- as.data.frame(
  table(eligible$control_stratum),
  stringsAsFactors = FALSE
)
names(stratum_counts) <- c("control_stratum", "cases")
stratum_counts <- stratum_counts[
  order(stratum_counts$control_stratum),
  ,
  drop = FALSE
]
stratum_counts$control_layer_id <- sprintf(
  "control_layer_%05d",
  seq_len(nrow(stratum_counts))
)
stratum_counts$target_pool_size <- pmax(50L, 4L * stratum_counts$cases)
stratum_counts$sample_batches <- ceiling(
  stratum_counts$target_pool_size / 200L
)

split_keys <- strsplit(
  stratum_counts$control_stratum,
  "|",
  fixed = TRUE
)
stratum_counts$source_id <- vapply(
  split_keys,
  function(values) values[[1]],
  character(1)
)
stratum_counts$publication_year <- as.integer(vapply(
  split_keys,
  function(values) values[[2]],
  character(1)
))
stratum_counts$openalex_type <- vapply(
  split_keys,
  function(values) values[[3]],
  character(1)
)
write_csv_utf8(
  stratum_counts[
    ,
    c(
      "control_layer_id",
      "control_stratum",
      "source_id",
      "publication_year",
      "openalex_type",
      "cases",
      "target_pool_size",
      "sample_batches"
    )
  ],
  file.path(audit_table_dir, "p1_control_layer_plan.csv")
)

batch_rows <- lapply(seq_len(nrow(stratum_counts)), function(index) {
  count <- stratum_counts$sample_batches[[index]]
  target <- stratum_counts$target_pool_size[[index]]
  sizes <- rep(200L, count)
  sizes[[count]] <- target - 200L * (count - 1L)
  data.frame(
    control_layer_id = stratum_counts$control_layer_id[[index]],
    sample_batch = seq_len(count),
    sample_size = sizes,
    seed = as.integer(project_config$project$random_seed) +
      index * 1000L +
      seq_len(count),
    stringsAsFactors = FALSE
  )
})
sample_plan <- do.call(rbind, batch_rows)
write_csv_utf8(
  sample_plan,
  file.path(audit_table_dir, "p1_control_sample_plan.csv")
)

excluded_cases <- cases[
  !cases$control_eligible,
  c(
    "paper_key",
    "doi_canonical",
    "retraction_year_first",
    "original_paper_year_first",
    "openalex_type",
    "source_id",
    "control_exclusion_reason"
  ),
  drop = FALSE
]
write_csv_utf8(
  excluded_cases,
  file.path(audit_table_dir, "p1_control_cases_without_stratum.csv")
)

plan_summary <- data.frame(
  metric = c(
    "case_papers",
    "control_eligible_cases",
    "cases_without_stratum",
    "control_layers",
    "sample_batches",
    "target_candidate_pool_works",
    "layers_with_multiple_batches"
  ),
  value = c(
    nrow(cases),
    nrow(eligible),
    nrow(excluded_cases),
    nrow(stratum_counts),
    nrow(sample_plan),
    sum(stratum_counts$target_pool_size),
    sum(stratum_counts$sample_batches > 1L)
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  plan_summary,
  file.path(audit_table_dir, "p1_control_plan_summary.csv")
)

saveRDS(
  cases,
  file.path(processed_dir, "p1", "control_cases.rds")
)

write_audit_manifest()
message("Control matching plan built.")
