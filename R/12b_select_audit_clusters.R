#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

if (!requireNamespace("igraph", quietly = TRUE)) {
  stop("Package 'igraph' is required for audit-cluster selection.")
}

seed <- as.integer(project_config$project$random_seed)
bootstrap_replicates <- 20L
bootstrap_fraction <- 0.8
minimum_papers <- 5L
minimum_years <- 2L
fixed_cluster_count <- 25L

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
repeat_edges <- edge_summary[edge_summary$paper_count >= 2L, , drop = FALSE]

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

vertex_ids <- sort(unique(c(repeat_edges$author_lo, repeat_edges$author_hi)))
vertices <- data.frame(name = vertex_ids, stringsAsFactors = FALSE)
component_graph <- igraph::graph_from_data_frame(
  repeat_edges[, c("author_lo", "author_hi"), drop = FALSE],
  directed = FALSE,
  vertices = vertices
)
component_info <- igraph::components(component_graph)
component_membership <- component_info$membership
names(component_membership) <- vertices$name

max_jaccard_by_component <- function(primary, alternate) {
  alternate <- alternate[names(primary)]
  alternate[is.na(alternate)] <- 0L
  primary_sizes <- table(primary)
  alternate_sizes <- table(alternate)
  overlap <- table(primary, alternate)
  vapply(seq_len(nrow(overlap)), function(index) {
    primary_id <- rownames(overlap)[[index]]
    counts <- overlap[index, ]
    boot_ids <- as.integer(names(counts))
    intersections <- as.numeric(counts)
    unions <- primary_sizes[[primary_id]] +
      alternate_sizes[as.character(boot_ids)] -
      intersections
    max(intersections / unions)
  }, numeric(1))
}

bootstrap_stability <- matrix(
  NA_real_,
  nrow = component_info$no,
  ncol = bootstrap_replicates
)
for (replicate in seq_len(bootstrap_replicates)) {
  set.seed(seed + 20000L + replicate)
  keep <- sample.int(
    nrow(repeat_edges),
    size = floor(nrow(repeat_edges) * bootstrap_fraction)
  )
  bootstrap_graph <- igraph::graph_from_data_frame(
    repeat_edges[keep, c("author_lo", "author_hi"), drop = FALSE],
    directed = FALSE,
    vertices = vertices
  )
  bootstrap_membership <- igraph::components(
    bootstrap_graph
  )$membership
  names(bootstrap_membership) <- vertices$name
  bootstrap_stability[, replicate] <- max_jaccard_by_component(
    component_membership,
    bootstrap_membership
  )
}

paper_authors <- data.table::as.data.table(authorships_long)
paper_authors <- paper_authors[paper_key %in% network_panel$paper_key]
paper_authors <- unique(paper_authors[, .(paper_key, author_id)])
paper_authors$community <- component_membership[paper_authors$author_id]
paper_authors <- paper_authors[!is.na(community)]

paper_meta <- data.table::as.data.table(network_panel[, c(
  "paper_key",
  "retraction_year_first",
  "publisher",
  family_columns
)])
paper_summary <- paper_authors[, .(
  community_authors = .N
), by = .(paper_key, community)][community_authors >= 2L]
paper_summary <- merge(
  paper_summary,
  paper_meta,
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)

repeat_edges$community_a <- component_membership[repeat_edges$author_lo]
repeat_edges$community_b <- component_membership[repeat_edges$author_hi]
internal_edges <- repeat_edges[
  repeat_edges$community_a == repeat_edges$community_b,
  ,
  drop = FALSE
]

# Rebuild non-2023 repeat edges for temporal stability.
pair_source <- data.table::as.data.table(authorships_long)
pair_source <- pair_source[pair_source$paper_key %in% network_panel$paper_key]
pair_source <- unique(pair_source[, .(paper_key, author_id)])
pair_source <- merge(
  pair_source,
  paper_meta[, c("paper_key", "retraction_year_first")],
  by = "paper_key",
  all.x = TRUE
)
pair_source <- pair_source[pair_source$retraction_year_first != 2023L]
non2023_pairs <- pair_source[, {
  ids <- sort(unique(author_id))
  if (length(ids) < 2L) {
    NULL
  } else {
    pair_matrix <- utils::combn(ids, 2L)
    list(
      author_lo = pair_matrix[1L, ],
      author_b = pair_matrix[2L, ]
    )
  }
}, by = paper_key]
non2023_pairs$author_a <- pmin(non2023_pairs$author_lo, non2023_pairs$author_b)
non2023_pairs$author_b2 <- pmax(non2023_pairs$author_lo, non2023_pairs$author_b)
non2023_pairs <- data.table::as.data.table(non2023_pairs)[
  ,
  .(paper_count = .N),
  by = .(author_lo = author_a, author_hi = author_b2)
][paper_count >= 2L]
non2023_graph <- igraph::graph_from_data_frame(
  non2023_pairs[, .(author_lo, author_hi)],
  directed = FALSE,
  vertices = vertices
)
non2023_membership <- igraph::components(non2023_graph)$membership
names(non2023_membership) <- vertices$name
non2023_stability <- max_jaccard_by_component(
  component_membership,
  non2023_membership
)

profile_rows <- lapply(seq_len(component_info$no), function(community_id) {
  members <- paper_summary[community == community_id]
  internal <- internal_edges[internal_edges$community_a == community_id]
  if (nrow(members) == 0L) {
    return(NULL)
  }
  family_counts <- vapply(
    family_columns,
    function(family) sum(members[[family]] %in% TRUE),
    integer(1)
  )
  row <- data.frame(
    component_id = community_id,
    authors = sum(component_membership == community_id),
    papers_with_two_members = nrow(members),
    years = data.table::uniqueN(members$retraction_year_first),
    first_year = min(members$retraction_year_first, na.rm = TRUE),
    last_year = max(members$retraction_year_first, na.rm = TRUE),
    repeated_internal_edges = nrow(internal),
    multi_year_repeated_internal_edges = sum(internal$year_span > 0L),
    publisher_count = data.table::uniqueN(members$publisher),
    papers_2023 = sum(members$retraction_year_first == 2023L),
    share_2023 = mean(members$retraction_year_first == 2023L),
    bootstrap_stability_mean = mean(bootstrap_stability[community_id, ]),
    bootstrap_stability_min = min(bootstrap_stability[community_id, ]),
    excluding_2023_stability = non2023_stability[[community_id]],
    stringsAsFactors = FALSE
  )
  for (family in family_columns) {
    row[[paste0("papers_", family)]] <- family_counts[[family]]
  }
  row
})
component_profiles <- data.table::rbindlist(profile_rows, fill = TRUE)

candidate_profiles <- component_profiles[
  papers_with_two_members >= minimum_papers &
    years >= minimum_years &
    share_2023 <= 0.5 &
    excluding_2023_stability >= 0.5,
  ,
  drop = FALSE
]
data.table::setorder(
  candidate_profiles,
  -multi_year_repeated_internal_edges,
  -repeated_internal_edges,
  -papers_with_two_members,
  -years,
  -bootstrap_stability_mean,
  component_id
)
candidate_profiles[, candidate_rank := seq_len(.N)]
candidate_profiles[, selected := candidate_rank <= fixed_cluster_count]
write_csv_utf8(
  as.data.frame(component_profiles),
  file.path(audit_table_dir, "repeat_component_profiles.csv")
)
write_csv_utf8(
  as.data.frame(candidate_profiles),
  file.path(audit_table_dir, "audit_cluster_candidates.csv")
)

final_clusters <- candidate_profiles[selected == TRUE, , drop = FALSE]
final_clusters[, audit_cluster_id := sprintf(
  "audit_cluster_%02d",
  seq_len(.N)
)]
write_csv_utf8(
  as.data.frame(final_clusters),
  file.path(audit_table_dir, "audit_clusters_final_25.csv")
)

seed_membership <- data.table::data.table(
  author_id = vertices$name,
  component_id = component_membership
)
saveRDS(
  seed_membership,
  file.path(processed_dir, "p1", "repeat_component_membership.rds")
)

write_audit_manifest()
message("Repeat-collaboration audit clusters selected.")
