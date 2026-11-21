#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/analysis_sample_audit.R", encoding = "UTF-8")

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
edge_summary <- readRDS(file.path(
  processed_dir,
  "p1",
  "network_edge_summary.rds"
))
component_membership <- readRDS(file.path(
  processed_dir,
  "p1",
  "repeat_component_membership.rds"
))
final_clusters <- utils::read.csv(
  file.path(audit_table_dir, "audit_clusters_final_25.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
family_null <- utils::read.csv(
  file.path(audit_table_dir, "network_null_family_summary.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
network_family <- utils::read.csv(
  file.path(audit_table_dir, "network_family_summary.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
analysis_paper_panel <- readRDS(file.path(
  processed_dir,
  "p1",
  "analysis_paper_panel.rds"
))$paper_panel

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

assert_columns(
  network_panel,
  c(
    "paper_key",
    "retraction_year_first",
    "original_paper_year_first",
    "retraction_first_date",
    "journal",
    "publisher",
    "field_id",
    family_columns
  ),
  "network paper panel"
)
assert_columns(
  component_membership,
  c("author_id", "component_id"),
  "repeat component membership"
)

network_authors <- data.table::as.data.table(authorships_long)
network_authors <- network_authors[
  paper_key %in% network_panel$paper_key &
    !is.na(author_id) &
    author_id != "",
  .(paper_key, author_id)
]
network_authors <- unique(network_authors)
paper_team_size <- network_authors[
  ,
  .(paper_team_size = .N),
  by = paper_key
]

paper_family <- network_panel[, c("paper_key", family_columns), drop = FALSE]
paper_family <- merge(
  paper_team_size,
  paper_family,
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)
paper_family$paper_pairs <- choose(paper_family$paper_team_size, 2L)
family_pair_occurrences <- vapply(family_columns, function(family) {
  sum(
    paper_family$paper_pairs[paper_family[[family]] %in% TRUE],
    na.rm = TRUE
  )
}, numeric(1))

network_family$pair_occurrences <- unname(
  family_pair_occurrences[network_family$analysis_family]
)
network_family$repeat_rate <-
  network_family$repeat_edges / network_family$pair_occurrences
network_family$multi_year_repeat_rate <-
  network_family$multi_year_repeat_edges / network_family$repeat_edges

family_comparison <- merge(
  family_null,
  network_family,
  by = "analysis_family",
  all.x = TRUE,
  sort = FALSE
)
family_comparison$null_repeat_rate <-
  family_comparison$null_mean / family_comparison$pair_occurrences
family_comparison$observed_null_rate_ratio <-
  family_comparison$observed / family_comparison$null_mean
family_comparison$excess_per_1000_pair_occurrences <-
  (family_comparison$observed - family_comparison$null_mean) /
  family_comparison$pair_occurrences *
  1000
family_comparison$null_rate_q025 <-
  family_comparison$null_q025 / family_comparison$pair_occurrences
family_comparison$null_rate_q975 <-
  family_comparison$null_q975 / family_comparison$pair_occurrences
family_comparison$p_fdr <- stats::p.adjust(
  family_comparison$p_one_sided,
  method = "BH"
)
family_comparison <- family_comparison[
  order(
    -family_comparison$excess_per_1000_pair_occurrences,
    family_comparison$analysis_family
  ),
  ,
  drop = FALSE
]

edge_structure_rows <- lapply(family_columns, function(family) {
  edges <- edge_summary[edge_summary[[family]] %in% TRUE, , drop = FALSE]
  repeated <- edges[edges$paper_count >= 2L, , drop = FALSE]
  same_year <- repeated[repeated$year_span == 0L, , drop = FALSE]
  cross_year <- repeated[repeated$year_span > 0L, , drop = FALSE]
  data.frame(
    analysis_family = family,
    unique_edges = nrow(edges),
    edge_occurrences = sum(edges$paper_count, na.rm = TRUE),
    repeat_edges = nrow(repeated),
    repeat_edge_share = if (nrow(edges) == 0L) {
      NA_real_
    } else {
      nrow(repeated) / nrow(edges)
    },
    same_year_repeat_edges = nrow(same_year),
    cross_year_repeat_edges = nrow(cross_year),
    cross_year_repeat_share = if (nrow(repeated) == 0L) {
      NA_real_
    } else {
      nrow(cross_year) / nrow(repeated)
    },
    max_repeat_count = if (nrow(repeated) == 0L) {
      0L
    } else {
      max(repeated$paper_count)
    },
    stringsAsFactors = FALSE
  )
})
edge_structure <- data.table::rbindlist(
  edge_structure_rows,
  fill = TRUE
)

top_value <- function(values) {
  values <- as.character(values)
  values <- values[
    !is.na(values) & values != "" & values != "(missing)"
  ]
  if (length(values) == 0L) {
    return(NA_character_)
  }
  counts <- sort(table(values), decreasing = TRUE)
  names(counts)[[1]]
}

top_share <- function(values) {
  values <- as.character(values)
  values <- values[!is.na(values) & values != ""]
  if (length(values) == 0L) {
    return(NA_real_)
  }
  max(table(values)) / length(values)
}

final_clusters <- final_clusters[
  order(final_clusters$candidate_rank),
  ,
  drop = FALSE
]
selected_components <- setNames(
  final_clusters$audit_cluster_id,
  final_clusters$component_id
)

membership <- as.data.frame(component_membership)
paper_authors <- merge(
  network_authors,
  membership,
  by = "author_id",
  all.x = FALSE,
  sort = FALSE
)
paper_authors <- paper_authors[
  paper_authors$component_id %in% final_clusters$component_id,
  ,
  drop = FALSE
]
paper_cluster_counts <- data.table::as.data.table(paper_authors)[
  ,
  .(cluster_member_count = .N),
  by = .(paper_key, component_id)
]
paper_cluster_counts <- paper_cluster_counts[
  cluster_member_count >= 2L,
  ,
  drop = FALSE
]
paper_cluster_counts$audit_cluster_id <- unname(
  selected_components[as.character(paper_cluster_counts$component_id)]
)

paper_meta <- network_panel[, c(
  "paper_key",
  "retraction_year_first",
  "original_paper_year_first",
  "retraction_first_date",
  "journal",
  "publisher",
  "field_id",
  family_columns
), drop = FALSE]
paper_meta$batch_key <- paste(
  as.character(paper_meta$retraction_first_date),
  paper_meta$publisher,
  sep = "|"
)

panel_metrics <- analysis_paper_panel[
  analysis_paper_panel$is_retraction,
  c(
    "case_paper_key",
    "team_size",
    "cross_tier",
    "geo_level",
    "domestic_cross_province",
    "international",
    "median_domestic_geo_distance_km"
  ),
  drop = FALSE
]
panel_metrics <- unique(panel_metrics)
names(panel_metrics)[names(panel_metrics) == "case_paper_key"] <- "paper_key"

paper_membership <- merge(
  as.data.frame(paper_cluster_counts),
  paper_meta,
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)
paper_membership <- merge(
  paper_membership,
  panel_metrics,
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)
paper_membership <- paper_membership[
  order(
    paper_membership$audit_cluster_id,
    paper_membership$retraction_year_first,
    paper_membership$paper_key
  ),
  ,
  drop = FALSE
]

family_count_rows <- list()
geo_rows <- list()
venue_rows <- list()
batch_rows <- list()
profile_rows <- list()

for (cluster_index in seq_len(nrow(final_clusters))) {
  cluster <- final_clusters[cluster_index, , drop = FALSE]
  cluster_id <- cluster$audit_cluster_id[[1]]
  papers <- paper_membership[
    paper_membership$audit_cluster_id == cluster_id,
    ,
    drop = FALSE
  ]
  member_ids <- membership$author_id[
    membership$component_id == cluster$component_id[[1]]
  ]
  internal_edges <- edge_summary[
    edge_summary$author_lo %in% member_ids &
      edge_summary$author_hi %in% member_ids,
    ,
    drop = FALSE
  ]
  repeated_internal <- internal_edges[
    internal_edges$paper_count >= 2L,
    ,
    drop = FALSE
  ]

  for (family in family_columns) {
    family_count_rows[[length(family_count_rows) + 1L]] <- data.frame(
      audit_cluster_id = cluster_id,
      component_id = cluster$component_id[[1]],
      analysis_family = family,
      papers = sum(papers[[family]] %in% TRUE),
      cluster_papers = nrow(papers),
      share = if (nrow(papers) == 0L) {
        NA_real_
      } else {
        sum(papers[[family]] %in% TRUE) / nrow(papers)
      },
      stringsAsFactors = FALSE
    )
  }

  geo_levels <- c(
    "single_city",
    "same_province_multi_city",
    "domestic_cross_province",
    "hmt_involved",
    "international",
    "unknown"
  )
  for (geo_level in geo_levels) {
    geo_rows[[length(geo_rows) + 1L]] <- data.frame(
      audit_cluster_id = cluster_id,
      component_id = cluster$component_id[[1]],
      geo_level = geo_level,
      papers = sum(papers$geo_level == geo_level, na.rm = TRUE),
      cluster_papers = nrow(papers),
      share = if (nrow(papers) == 0L) {
        NA_real_
      } else {
        sum(papers$geo_level == geo_level, na.rm = TRUE) / nrow(papers)
      },
      stringsAsFactors = FALSE
    )
  }

  for (value_type in c("publisher", "journal", "field_id")) {
    values <- papers[[value_type]]
    counts <- sort(
      table(values[!is.na(values) & values != ""]),
      decreasing = TRUE
    )
    if (length(counts) > 0L) {
      for (rank in seq_len(min(3L, length(counts)))) {
        venue_rows[[length(venue_rows) + 1L]] <- data.frame(
          audit_cluster_id = cluster_id,
          value_type = value_type,
          rank = rank,
          value = names(counts)[[rank]],
          papers = as.integer(counts[[rank]]),
          cluster_papers = nrow(papers),
          share = as.integer(counts[[rank]]) / nrow(papers),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  batch_counts <- sort(table(papers$batch_key), decreasing = TRUE)
  if (length(batch_counts) > 0L) {
    for (rank in seq_len(min(3L, length(batch_counts)))) {
      batch_value <- names(batch_counts)[[rank]]
      batch_parts <- strsplit(batch_value, "|", fixed = TRUE)[[1]]
      batch_rows[[length(batch_rows) + 1L]] <- data.frame(
        audit_cluster_id = cluster_id,
        rank = rank,
        batch_key = batch_value,
        batch_date = batch_parts[[1]],
        batch_publisher = if (length(batch_parts) >= 2L) {
          paste(batch_parts[-1], collapse = "|")
        } else {
          NA_character_
        },
        papers = as.integer(batch_counts[[rank]]),
        cluster_papers = nrow(papers),
        share = as.integer(batch_counts[[rank]]) / nrow(papers),
        stringsAsFactors = FALSE
      )
    }
  }

  top_publisher <- top_value(papers$publisher)
  top_journal <- top_value(papers$journal)
  top_field <- top_value(papers$field_id)
  top_batch <- if (length(batch_counts) == 0L) {
    NA_character_
  } else {
    names(batch_counts)[[1]]
  }
  top_batch_parts <- if (is.na(top_batch)) {
    c(NA_character_, NA_character_)
  } else {
    strsplit(top_batch, "|", fixed = TRUE)[[1]]
  }
  positive_distance <- papers$median_domestic_geo_distance_km[
    is.finite(papers$median_domestic_geo_distance_km) &
      papers$median_domestic_geo_distance_km > 0
  ]

  profile_rows[[length(profile_rows) + 1L]] <- data.frame(
    audit_cluster_id = cluster_id,
    component_id = cluster$component_id[[1]],
    authors = cluster$authors,
    network_papers = cluster$papers_with_two_members,
    profile_papers = nrow(papers),
    first_year = cluster$first_year,
    last_year = cluster$last_year,
    year_span = cluster$last_year - cluster$first_year + 1L,
    papers_2023 = sum(papers$retraction_year_first == 2023L, na.rm = TRUE),
    share_2023 = mean(papers$retraction_year_first == 2023L, na.rm = TRUE),
    share_original_2021_2022 = mean(
      papers$original_paper_year_first %in% c(2021L, 2022L),
      na.rm = TRUE
    ),
    internal_edges = nrow(internal_edges),
    repeated_internal_edges = nrow(repeated_internal),
    multi_year_repeated_edges = sum(
      repeated_internal$year_span > 0L,
      na.rm = TRUE
    ),
    max_pair_paper_count = if (nrow(repeated_internal) == 0L) {
      0L
    } else {
      max(repeated_internal$paper_count)
    },
    publisher_count = data.table::uniqueN(papers$publisher[
      !is.na(papers$publisher)
    ]),
    journal_count = data.table::uniqueN(papers$journal[
      !is.na(papers$journal)
    ]),
    field_count = data.table::uniqueN(papers$field_id[
      !is.na(papers$field_id)
    ]),
    top_publisher = top_publisher,
    top_publisher_share = top_share(papers$publisher),
    top_journal = top_journal,
    top_journal_share = top_share(papers$journal),
    top_field_id = top_field,
    top_field_share = top_share(papers$field_id),
    top_batch_date = top_batch_parts[[1]],
    top_batch_publisher = if (length(top_batch_parts) >= 2L) {
      paste(top_batch_parts[-1], collapse = "|")
    } else {
      NA_character_
    },
    top_batch_share = top_share(papers$batch_key),
    cross_tier_share = analysis_safe_rate(papers$cross_tier),
    domestic_cross_province_share = analysis_safe_rate(
      papers$domestic_cross_province
    ),
    international_share = analysis_safe_rate(papers$international),
    positive_distance_share = if (nrow(papers) == 0L) {
      NA_real_
    } else {
      mean(
        is.finite(papers$median_domestic_geo_distance_km) &
          papers$median_domestic_geo_distance_km > 0
      )
    },
    median_positive_distance_km = if (length(positive_distance) == 0L) {
      NA_real_
    } else {
      stats::median(positive_distance)
    },
    median_team_size = stats::median(papers$team_size, na.rm = TRUE),
    bootstrap_stability_mean = cluster$bootstrap_stability_mean,
    excluding_2023_stability = cluster$excluding_2023_stability,
    stringsAsFactors = FALSE
  )
}

cluster_profiles <- data.table::rbindlist(profile_rows, fill = TRUE)
cluster_family_counts <- data.table::rbindlist(family_count_rows, fill = TRUE)
cluster_geo_counts <- data.table::rbindlist(geo_rows, fill = TRUE)
cluster_top_venues <- data.table::rbindlist(venue_rows, fill = TRUE)
cluster_top_batches <- data.table::rbindlist(batch_rows, fill = TRUE)

main_family_totals <- vapply(
  c(
    "family_publication_process",
    "family_image_integrity",
    "family_plagiarism_authorship"
  ),
  function(family) {
    sum(
      cluster_family_counts$papers[
        cluster_family_counts$analysis_family == family
      ],
      na.rm = TRUE
    )
  },
  numeric(1)
)
primary_field_counts <- sort(
  table(
    cluster_top_venues$value[
      cluster_top_venues$value_type == "field_id" &
        cluster_top_venues$rank == 1L
    ]
  ),
  decreasing = TRUE
)
portfolio_summary <- data.frame(
  metric = c(
    "audit_clusters",
    "cluster_authors",
    "cluster_papers",
    "median_cluster_2023_share",
    "clusters_2023_share_above_25pct",
    "clusters_international_above_50pct",
    "clusters_cross_tier_above_50pct",
    "clusters_positive_distance_above_50pct",
    "clusters_top_publisher_above_50pct",
    "cluster_paper_family_image_integrity",
    "cluster_paper_family_publication_process",
    "cluster_paper_family_plagiarism_authorship",
    "top_field_1_id",
    "top_field_1_clusters",
    "top_field_2_id",
    "top_field_2_clusters"
  ),
  value = c(
    nrow(cluster_profiles),
    sum(cluster_profiles$authors),
    sum(cluster_profiles$profile_papers),
    stats::median(cluster_profiles$share_2023, na.rm = TRUE),
    sum(cluster_profiles$share_2023 > 0.25, na.rm = TRUE),
    sum(cluster_profiles$international_share > 0.5, na.rm = TRUE),
    sum(cluster_profiles$cross_tier_share > 0.5, na.rm = TRUE),
    sum(cluster_profiles$positive_distance_share > 0.5, na.rm = TRUE),
    sum(cluster_profiles$top_publisher_share > 0.5, na.rm = TRUE),
    unname(main_family_totals[["family_image_integrity"]]),
    unname(main_family_totals[["family_publication_process"]]),
    unname(main_family_totals[["family_plagiarism_authorship"]]),
    names(primary_field_counts)[[1]],
    as.integer(primary_field_counts[[1]]),
    names(primary_field_counts)[[2]],
    as.integer(primary_field_counts[[2]])
  ),
  stringsAsFactors = FALSE
)
hypothesis_evidence <- data.frame(
  hypothesis = "H3",
  status = "partial_metric_dependent",
  evidence = paste0(
    "Publication process has the highest observed/null ratio (",
    sprintf(
      "%.3f",
      family_comparison$observed_null_rate_ratio[
        family_comparison$analysis_family ==
          "family_publication_process"
      ]
    ),
    "), while image integrity has the highest excess per 1,000 pair ",
    "occurrences (",
    sprintf(
      "%.2f",
      family_comparison$excess_per_1000_pair_occurrences[
        family_comparison$analysis_family ==
          "family_image_integrity"
      ]
    ),
    ")."
  ),
  stringsAsFactors = FALSE
)

write_csv_utf8(
  family_comparison,
  file.path(audit_table_dir, "p2_network_family_standardized_excess.csv")
)
write_csv_utf8(
  edge_structure,
  file.path(audit_table_dir, "p2_network_family_edge_structure.csv")
)
write_csv_utf8(
  as.data.frame(cluster_profiles),
  file.path(audit_table_dir, "p2_audit_cluster_profiles.csv")
)
write_csv_utf8(
  as.data.frame(cluster_family_counts),
  file.path(audit_table_dir, "p2_audit_cluster_family_counts.csv")
)
write_csv_utf8(
  as.data.frame(cluster_geo_counts),
  file.path(audit_table_dir, "p2_audit_cluster_geo_counts.csv")
)
write_csv_utf8(
  as.data.frame(cluster_top_venues),
  file.path(audit_table_dir, "p2_audit_cluster_top_venues.csv")
)
write_csv_utf8(
  as.data.frame(cluster_top_batches),
  file.path(audit_table_dir, "p2_audit_cluster_top_batches.csv")
)
write_csv_utf8(
  portfolio_summary,
  file.path(audit_table_dir, "p2_audit_cluster_portfolio_summary.csv")
)
write_csv_utf8(
  hypothesis_evidence,
  file.path(audit_table_dir, "p2_hypothesis_evidence.csv")
)
write_csv_utf8(
  paper_membership[, c(
    "audit_cluster_id",
    "component_id",
    "paper_key",
    "cluster_member_count",
    "team_size",
    "retraction_year_first",
    "original_paper_year_first",
    "publisher",
    "journal",
    "field_id",
    "cross_tier",
    "geo_level",
    "median_domestic_geo_distance_km",
    family_columns
  ), drop = FALSE],
  file.path(audit_table_dir, "p2_audit_cluster_paper_membership.csv")
)

write_audit_manifest()
message("P2 network comparison and audit-cluster profiling completed.")
