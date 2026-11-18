#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

candidate_file <- file.path(
  interim_dir,
  "mappings",
  "institution_tier_candidates_v1.csv"
)
if (!file.exists(candidate_file)) {
  stop("Run R/06d_build_institution_tier_candidates.R first.")
}

candidates <- data.table::fread(
  candidate_file,
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
institutions <- readRDS(file.path(
  processed_dir,
  "p1",
  "openalex_institutions.rds"
))

resolved <- candidates[
  !is.na(candidates$openalex_institution_id) &
    candidates$openalex_institution_id != "",
  ,
  drop = FALSE
]
institution_match <- match(
  resolved$openalex_institution_id,
  institutions$institution_id
)
resolved$openalex_institution_name <- institutions$institution_name[
  institution_match
]
resolved$country_code <- institutions$country_code[institution_match]
resolved$region <- institutions$region[institution_match]
resolved$city <- institutions$city[institution_match]
resolved$ror_id <- institutions$ror_id[institution_match]

resolved <- resolved[
  order(
    resolved$tier_name,
    resolved$openalex_institution_name,
    resolved$university_name
  ),
  ,
  drop = FALSE
]

tier_order <- c(
  "985",
  "211",
  "double_first_class_2017",
  "double_first_class_2022"
)
registry <- resolved[
  ,
  c(
    "tier_name",
    "university_name",
    "source_chinese_name",
    "openalex_institution_id",
    "openalex_institution_name",
    "ror_id",
    "country_code",
    "region",
    "city",
    "match_method"
  ),
  drop = FALSE
]
registry$tier_name <- factor(registry$tier_name, levels = tier_order)
registry <- registry[order(registry$tier_name), , drop = FALSE]
registry$tier_name <- as.character(registry$tier_name)
registry$registry_version <- "1.0-frozen"
registry$review_status <- "reviewed"

registry_file <- file.path(
  project_dir,
  "data",
  "reference",
  "mappings",
  "institution_tier_registry_v1.csv"
)
write_csv_utf8(registry, registry_file)

summary <- do.call(
  rbind,
  lapply(tier_order, function(tier_name) {
    subset <- registry[registry$tier_name == tier_name, , drop = FALSE]
    unresolved <- candidates[
      candidates$tier_name == tier_name &
        (
          is.na(candidates$openalex_institution_id) |
            candidates$openalex_institution_id == ""
        ),
      ,
      drop = FALSE
    ]
    data.frame(
      tier_name = tier_name,
      list_entries = sum(candidates$tier_name == tier_name),
      resolved_entries = nrow(subset),
      unique_institution_ids = length(unique(
        subset$openalex_institution_id
      )),
      manual_aliases = sum(subset$match_method == "manual_alias"),
      not_in_sample = nrow(unresolved),
      stringsAsFactors = FALSE
    )
  })
)
write_csv_utf8(
  summary,
  file.path(audit_table_dir, "p1_institution_tier_registry_summary.csv")
)

not_in_sample <- candidates[
  is.na(candidates$openalex_institution_id) |
    candidates$openalex_institution_id == "",
  ,
  drop = FALSE
]
write_csv_utf8(
  not_in_sample,
  file.path(audit_table_dir, "p1_institution_tier_not_in_sample.csv")
)

write_audit_manifest()
message("Institution tier registry frozen.")
