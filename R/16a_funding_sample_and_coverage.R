#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/funding_audit.R", encoding = "UTF-8")

seed <- as.integer(project_config$project$random_seed)
maximum_cluster_papers <- 20L
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

final_clusters <- utils::read.csv(
  file.path(audit_table_dir, "audit_clusters_final_25.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
candidate_clusters <- utils::read.csv(
  file.path(audit_table_dir, "audit_cluster_candidates.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
component_membership <- readRDS(file.path(
  processed_dir,
  "p1",
  "repeat_component_membership.rds"
))
network_panel <- readRDS(file.path(
  processed_dir,
  "p0",
  "openalex_mainland_network_complete_paper_panel.rds"
))
authorships_long <- readRDS(file.path(
  processed_dir,
  "p0",
  "mainland_authorships_long.rds"
))
paper_panel <- readRDS(file.path(
  processed_dir,
  "p1",
  "analysis_paper_panel.rds"
))$paper_panel
control_works <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_works_full.rds"
))

assert_columns(
  network_panel,
  c(
    "paper_key",
    "retraction_year_first",
    "original_paper_year_first",
    "publisher",
    "journal",
    "field_id",
    "openalex_work_id",
    "funders_present",
    "awards_present",
    "funder_ids",
    "award_ids",
    family_columns
  ),
  "network panel"
)
assert_columns(
  control_works,
  c(
    "openalex_work_id",
    "funders_present",
    "awards_present",
    "funder_ids",
    "award_ids"
  ),
  "control works"
)
assert_columns(
  component_membership,
  c("author_id", "component_id"),
  "component membership"
)

network_authors <- data.table::as.data.table(authorships_long)
network_authors <- network_authors[
  paper_key %in% network_panel$paper_key &
    !is.na(author_id) &
    author_id != "",
  .(paper_key, author_id)
]
network_authors <- unique(network_authors)
membership <- as.data.frame(component_membership)
paper_authors <- merge(
  network_authors,
  membership,
  by = "author_id",
  all.x = FALSE,
  sort = FALSE
)
candidate_component_ids <- candidate_clusters$component_id
paper_authors <- paper_authors[
  paper_authors$component_id %in% candidate_component_ids,
  ,
  drop = FALSE
]
paper_component_counts <- data.table::as.data.table(paper_authors)[
  ,
  .(cluster_member_count = .N),
  by = .(paper_key, component_id)
]
paper_component_counts <- as.data.frame(
  paper_component_counts[cluster_member_count >= 2L]
)

audit_cluster_map <- setNames(
  final_clusters$audit_cluster_id,
  final_clusters$component_id
)
paper_component_counts$audit_cluster_id <- unname(
  audit_cluster_map[as.character(paper_component_counts$component_id)]
)

paper_columns <- c(
  "paper_key",
  "doi_canonical",
  "retraction_year_first",
  "original_paper_year_first",
  "publisher",
  "journal",
  "field_id",
  "openalex_work_id",
  "funders_present",
  "awards_present",
  "funder_ids",
  "award_ids",
  family_columns
)
candidate_paper_pool <- merge(
  paper_component_counts,
  network_panel[, paper_columns, drop = FALSE],
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)

selected_pool <- candidate_paper_pool[
  !is.na(candidate_paper_pool$audit_cluster_id),
  ,
  drop = FALSE
]
unselected_pool <- candidate_paper_pool[
  is.na(candidate_paper_pool$audit_cluster_id),
  ,
  drop = FALSE
]

sample_rows <- list()
sample_summary_rows <- list()
for (cluster_index in seq_len(nrow(final_clusters))) {
  cluster <- final_clusters[cluster_index, , drop = FALSE]
  cluster_id <- cluster$audit_cluster_id[[1]]
  component_id <- cluster$component_id[[1]]
  cluster_papers <- selected_pool[
    selected_pool$audit_cluster_id == cluster_id,
    ,
    drop = FALSE
  ]
  cluster_seed <- seed + as.integer(component_id) * 1009L
  sampled <- funding_sample_within_cluster(
    cluster_papers,
    maximum_n = maximum_cluster_papers,
    seed = cluster_seed,
    cluster_id = component_id
  )
  sampled$audit_cluster_id <- cluster_id
  sampled$component_id <- component_id
  sampled$cluster_seed <- cluster_seed
  sample_rows[[length(sample_rows) + 1L]] <- sampled
  sample_summary_rows[[length(sample_summary_rows) + 1L]] <- data.frame(
    audit_cluster_id = cluster_id,
    component_id = component_id,
    candidate_papers = nrow(cluster_papers),
    sampled_papers = nrow(sampled),
    sampling_strata = length(unique(sampled$funding_stratum)),
    cluster_seed = cluster_seed,
    maximum_per_cluster = maximum_cluster_papers,
    stringsAsFactors = FALSE
  )
}

funding_sample <- data.table::rbindlist(sample_rows, fill = TRUE)
funding_sample <- as.data.frame(funding_sample)
funding_sample <- funding_sample[
  order(funding_sample$audit_cluster_id, funding_sample$paper_key),
  ,
  drop = FALSE
]
sample_summary <- data.table::rbindlist(
  sample_summary_rows,
  fill = TRUE
)

funding_sample$funders_present[
  is.na(funding_sample$funders_present)
] <- FALSE
funding_sample$awards_present[
  is.na(funding_sample$awards_present)
] <- FALSE
funding_sample$any_funding_metadata <-
  funding_sample$funders_present |
  funding_sample$awards_present
funding_sample_unique <- funding_sample[
  !duplicated(funding_sample$paper_key),
  ,
  drop = FALSE
]

sample_strata <- data.table::as.data.table(funding_sample)[
  ,
  .(
    sample_papers = .N,
    funded_papers = sum(funders_present),
    award_papers = sum(awards_present)
  ),
  by = .(
    audit_cluster_id,
    funding_stratum,
    stratum_size,
    stratum_sample_n
  )
]
sample_strata <- as.data.frame(sample_strata)
sample_strata <- sample_strata[
  order(sample_strata$audit_cluster_id, sample_strata$funding_stratum),
  ,
  drop = FALSE
]

sample_case_groups <- unique(paper_panel$match_group[
  paper_panel$is_retraction &
    paper_panel$case_paper_key %in% funding_sample_unique$paper_key
])
matched_controls <- paper_panel[
  !paper_panel$is_retraction &
    paper_panel$match_group %in% sample_case_groups,
  c(
    "case_paper_key",
    "match_group",
    "openalex_work_id",
    "publication_year",
    "publisher"
  ),
  drop = FALSE
]
matched_controls <- matched_controls[
  !duplicated(matched_controls$openalex_work_id),
  ,
  drop = FALSE
]
matched_controls <- merge(
  matched_controls,
  control_works[, c(
    "openalex_work_id",
    "funders_present",
    "awards_present",
    "funder_ids",
    "award_ids"
  ), drop = FALSE],
  by = "openalex_work_id",
  all.x = TRUE,
  sort = FALSE
)
matched_controls$funders_present[
  is.na(matched_controls$funders_present)
] <- FALSE
matched_controls$awards_present[
  is.na(matched_controls$awards_present)
] <- FALSE
matched_controls$any_funding_metadata <-
  matched_controls$funders_present |
  matched_controls$awards_present

unselected_pool$funders_present[
  is.na(unselected_pool$funders_present)
] <- FALSE
unselected_pool$awards_present[
  is.na(unselected_pool$awards_present)
] <- FALSE
unselected_pool$any_funding_metadata <-
  unselected_pool$funders_present |
  unselected_pool$awards_present

wilson_interval <- function(successes, total, z = qnorm(0.975)) {
  if (total == 0L) {
    return(c(low = NA_real_, high = NA_real_))
  }
  p <- successes / total
  denominator <- 1 + z^2 / total
  center <- (p + z^2 / (2 * total)) / denominator
  half <- z * sqrt(
    p * (1 - p) / total + z^2 / (4 * total^2)
  ) / denominator
  c(low = center - half, high = center + half)
}

group_coverage_rows <- list()
coverage_groups <- list(
  selected_cluster_sample = funding_sample_unique,
  matched_controls = matched_controls,
  unselected_candidate_clusters = unselected_pool
)
for (group_name in names(coverage_groups)) {
  group <- coverage_groups[[group_name]]
  funded_n <- sum(group$funders_present %in% TRUE)
  award_n <- sum(group$awards_present %in% TRUE)
  any_n <- sum(group$any_funding_metadata %in% TRUE)
  interval <- wilson_interval(any_n, nrow(group))
  group_coverage_rows[[length(group_coverage_rows) + 1L]] <- data.frame(
    analysis_group = group_name,
    papers = nrow(group),
    funder_papers = funded_n,
    funder_coverage = funded_n / nrow(group),
    award_papers = award_n,
    award_coverage = award_n / nrow(group),
    any_funding_papers = any_n,
    any_funding_coverage = any_n / nrow(group),
    coverage_ci_low = interval[["low"]],
    coverage_ci_high = interval[["high"]],
    stringsAsFactors = FALSE
  )
}
group_coverage <- data.table::rbindlist(group_coverage_rows, fill = TRUE)

cluster_coverage <- data.table::as.data.table(funding_sample)[
  ,
  .(
    sampled_papers = .N,
    funder_papers = sum(funders_present),
    award_papers = sum(awards_present),
    any_funding_papers = sum(any_funding_metadata),
    multi_funder_papers = sum(vapply(
      funder_ids,
      function(ids) length(unique(ids)) > 1L,
      logical(1)
    )),
    multi_award_papers = sum(vapply(
      award_ids,
      function(ids) length(unique(ids)) > 1L,
      logical(1)
    ))
  ),
  by = audit_cluster_id
]
cluster_coverage <- as.data.frame(cluster_coverage)
cluster_coverage$funder_coverage <-
  cluster_coverage$funder_papers / cluster_coverage$sampled_papers
cluster_coverage$award_coverage <-
  cluster_coverage$award_papers / cluster_coverage$sampled_papers
cluster_coverage$any_funding_coverage <-
  cluster_coverage$any_funding_papers / cluster_coverage$sampled_papers
sample_summary <- merge(
  sample_summary,
  cluster_coverage[, c(
    "audit_cluster_id",
    "funder_papers",
    "award_papers",
    "any_funding_papers",
    "multi_funder_papers",
    "multi_award_papers",
    "funder_coverage",
    "award_coverage",
    "any_funding_coverage"
  ), drop = FALSE],
  by = "audit_cluster_id",
  all.x = TRUE,
  sort = FALSE
)

expand_id_column <- function(data, id_column, output_column) {
  rows <- lapply(seq_len(nrow(data)), function(index) {
    ids <- unique(data[[id_column]][[index]])
    ids <- ids[!is.na(ids) & ids != ""]
    if (length(ids) == 0L) {
      return(NULL)
    }
    data.frame(
      audit_cluster_id = data$audit_cluster_id[[index]],
      paper_key = data$paper_key[[index]],
      value = ids,
      stringsAsFactors = FALSE
    )
  })
  result <- data.table::rbindlist(rows, fill = TRUE)
  names(result)[names(result) == "value"] <- output_column
  as.data.frame(result)
}

funder_paper <- expand_id_column(
  funding_sample_unique,
  "funder_ids",
  "funder_id"
)
award_paper <- expand_id_column(
  funding_sample_unique,
  "award_ids",
  "award_id"
)

funder_reuse <- data.table::as.data.table(funder_paper)[
  ,
  .(
    papers = data.table::uniqueN(paper_key),
    clusters = data.table::uniqueN(audit_cluster_id)
  ),
  by = funder_id
]
funder_reuse <- as.data.frame(funder_reuse)
funder_reuse$reused_across_papers <- funder_reuse$papers > 1L
funder_reuse$reused_across_clusters <- funder_reuse$clusters > 1L
funder_reuse <- funder_reuse[
  order(-funder_reuse$papers, -funder_reuse$clusters, funder_reuse$funder_id),
  ,
  drop = FALSE
]

award_reuse <- data.table::as.data.table(award_paper)[
  ,
  .(
    papers = data.table::uniqueN(paper_key),
    clusters = data.table::uniqueN(audit_cluster_id)
  ),
  by = award_id
]
award_reuse <- as.data.frame(award_reuse)
award_reuse$reused_across_papers <- award_reuse$papers > 1L
award_reuse$reused_across_clusters <- award_reuse$clusters > 1L
award_reuse <- award_reuse[
  order(-award_reuse$papers, -award_reuse$clusters, award_reuse$award_id),
  ,
  drop = FALSE
]

sample_overall_any <- mean(funding_sample_unique$any_funding_metadata)
decision <- data.frame(
  decision_date = as.character(Sys.Date()),
  sampled_papers = nrow(funding_sample_unique),
  cluster_paper_assignments = nrow(funding_sample),
  overlapped_paper_assignments = nrow(funding_sample) -
    nrow(funding_sample_unique),
  funder_coverage = mean(funding_sample_unique$funders_present),
  award_coverage = mean(funding_sample_unique$awards_present),
  any_funding_coverage = sample_overall_any,
  quality_gate = 0.50,
  openalex_status = if (sample_overall_any < 0.50) {
    "below_quality_gate"
  } else {
    "meets_quality_gate"
  },
  crossref_supplement = "pending",
  final_disposition = if (sample_overall_any < 0.50) {
    "appendix_only_unless_crossref_raises_coverage"
  } else {
    "eligible_for_main_analysis_after_crossref_verification"
  },
  amount_audit = "not_started",
  stringsAsFactors = FALSE
)

sample_output <- funding_sample
sample_output$funder_ids <- list_to_delimited(sample_output$funder_ids)
sample_output$award_ids <- list_to_delimited(sample_output$award_ids)
sample_output <- sample_output[, c(
  "audit_cluster_id",
  "component_id",
  "paper_key",
  "doi_canonical",
  "openalex_work_id",
  "retraction_year_first",
  "original_paper_year_first",
  "publisher",
  "journal",
  "field_id",
  "funding_stratum",
  "stratum_size",
  "stratum_sample_n",
  "funding_sample_rank",
  "funders_present",
  "awards_present",
  "any_funding_metadata",
  "funder_ids",
  "award_ids",
  "cluster_seed",
  family_columns
), drop = FALSE]

write_csv_utf8(
  sample_output,
  file.path(audit_table_dir, "funding_audit_sample.csv")
)
write_csv_utf8(
  as.data.frame(sample_summary),
  file.path(audit_table_dir, "funding_audit_sample_summary.csv")
)
write_csv_utf8(
  sample_strata,
  file.path(audit_table_dir, "funding_audit_sample_strata.csv")
)
write_csv_utf8(
  as.data.frame(group_coverage),
  file.path(audit_table_dir, "funding_audit_group_coverage.csv")
)
write_csv_utf8(
  cluster_coverage,
  file.path(audit_table_dir, "funding_audit_cluster_coverage.csv")
)
write_csv_utf8(
  funder_reuse,
  file.path(audit_table_dir, "funding_audit_funder_reuse.csv")
)
write_csv_utf8(
  award_reuse,
  file.path(audit_table_dir, "funding_audit_award_reuse.csv")
)
write_csv_utf8(
  funder_paper,
  file.path(audit_table_dir, "funding_audit_funder_papers.csv")
)
write_csv_utf8(
  award_paper,
  file.path(audit_table_dir, "funding_audit_award_papers.csv")
)
write_csv_utf8(
  decision,
  file.path(audit_table_dir, "funding_audit_decision.csv")
)

snapshot_manifest_path <- file.path(
  project_dir,
  "data",
  "external",
  "snapshots",
  "funding_audit_v1",
  "manifest.json"
)
ensure_dir(dirname(snapshot_manifest_path))
freeze_files <- c(
  file.path(audit_table_dir, "funding_audit_sample.csv"),
  file.path(audit_table_dir, "funding_audit_sample_summary.csv"),
  file.path(audit_table_dir, "funding_audit_sample_strata.csv")
)
jsonlite::write_json(
  list(
    contract_version = "1.0",
    artifact = "funding-audit-sample-v1",
    frozen_on = as.character(Sys.Date()),
    random_seed = seed,
    maximum_papers_per_cluster = maximum_cluster_papers,
    files = lapply(freeze_files, function(path) {
      list(
        path = project_relative_path(path),
        sha256 = sha256_canonical_file(path)
      )
    })
  ),
  snapshot_manifest_path,
  auto_unbox = TRUE,
  pretty = TRUE
)

write_audit_manifest()
message("Funding audit sample freeze and OpenAlex coverage completed.")
