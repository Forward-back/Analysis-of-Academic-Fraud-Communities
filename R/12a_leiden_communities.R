#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

if (!requireNamespace("igraph", quietly = TRUE)) {
  stop("Package 'igraph' is required for Leiden community analysis.")
}

seed <- as.integer(project_config$project$random_seed)
resolutions <- c(0.5, 0.75, 1.0, 1.25, 1.5, 2.0)
bootstrap_replicates <- 3L
bootstrap_fraction <- 0.8

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

repeat_edge_summary <- edge_summary[edge_summary$paper_count >= 2L, ,
  drop = FALSE
]
make_network <- function(edges) {
  vertex_ids <- sort(unique(c(edges$author_lo, edges$author_hi)))
  vertices <- data.frame(name = vertex_ids, stringsAsFactors = FALSE)
  graph <- igraph::graph_from_data_frame(
    edges[, c("author_lo", "author_hi"), drop = FALSE],
    directed = FALSE,
    vertices = vertices
  )
  list(
    graph = graph,
    vertices = vertices,
    edge_weights = edges$paper_count
  )
}
networks <- list(
  repeat_only = make_network(repeat_edge_summary),
  full_network = make_network(edge_summary)
)

run_leiden <- function(network, weights, resolution) {
  membership <- igraph::membership(igraph::cluster_leiden(
    network$graph,
    objective_function = "modularity",
    weights = weights,
    resolution = resolution,
    n_iterations = 10L
  ))
  names(membership) <- network$vertices$name
  membership
}

resolution_rows <- list()
partitions <- list()
for (network_scope in names(networks)) {
  network <- networks[[network_scope]]
  for (weighted in c(TRUE, FALSE)) {
    weight_label <- if (weighted) "weighted" else "unweighted"
    weight_values <- if (weighted) network$edge_weights else NULL
    for (resolution in resolutions) {
      membership <- run_leiden(network, weight_values, resolution)
      key <- paste(network_scope, weight_label, resolution, sep = "_")
      partitions[[key]] <- membership
      sizes <- table(membership)
      resolution_rows[[key]] <- data.frame(
        network_scope = network_scope,
        weights = weight_label,
        resolution = resolution,
        communities = length(sizes),
        non_singleton_communities = sum(sizes >= 2L),
        largest_community_nodes = max(sizes),
        modularity = igraph::modularity(
          network$graph,
          membership,
          weights = weight_values
        ),
        stringsAsFactors = FALSE
      )
    }
  }
}
resolution_summary <- data.table::rbindlist(resolution_rows, fill = TRUE)
write_csv_utf8(
  as.data.frame(resolution_summary),
  file.path(audit_table_dir, "leiden_resolution_summary.csv")
)

baseline_memberships <- partitions[
  c(
    "repeat_only_weighted_1",
    "repeat_only_unweighted_1",
    "full_network_weighted_1",
    "full_network_unweighted_1"
  )
]
stability_rows <- list()
for (network_scope in names(networks)) {
  for (weight_label in c("weighted", "unweighted")) {
    baseline <- baseline_memberships[[paste(
      network_scope,
      weight_label,
      1,
      sep = "_"
    )]]
    for (resolution in resolutions) {
      candidate <- partitions[[paste(
        network_scope,
        weight_label,
        resolution,
        sep = "_"
      )]]
      stability_rows[[paste(network_scope, weight_label, resolution)]] <-
        data.frame(
          network_scope = network_scope,
          weights = weight_label,
          comparison = paste0("resolution_", resolution, "_vs_1"),
          variation_of_information = igraph::compare(
            baseline,
            candidate,
            method = "vi"
          ),
          normalized_mutual_information = igraph::compare(
            baseline,
            candidate,
            method = "nmi"
          ),
          stringsAsFactors = FALSE
        )
    }
  }
}

weighted_baseline <- baseline_memberships[["repeat_only_weighted_1"]]
for (network_scope in names(networks)) {
  network <- networks[[network_scope]]
  baseline <- baseline_memberships[[paste(
    network_scope,
    "weighted",
    1,
    sep = "_"
  )]]
  for (replicate in seq_len(bootstrap_replicates)) {
    set.seed(seed + 10000L + replicate)
    keep <- sample.int(length(network$edge_weights), size = floor(
      length(network$edge_weights) * bootstrap_fraction
    ))
    edge_info <- if (network_scope == "repeat_only") {
      repeat_edge_summary
    } else {
      edge_summary
    }
    bootstrap_graph <- igraph::graph_from_data_frame(
      edge_info[keep, c("author_lo", "author_hi"), drop = FALSE],
      directed = FALSE,
      vertices = network$vertices
    )
    bootstrap_membership <- igraph::membership(igraph::cluster_leiden(
      bootstrap_graph,
      objective_function = "modularity",
      weights = network$edge_weights[keep],
      resolution = 1,
      n_iterations = 10L
    ))
    names(bootstrap_membership) <- network$vertices$name
    stability_rows[[paste(network_scope, "bootstrap", replicate, sep = "_")]] <-
      data.frame(
        network_scope = network_scope,
        weights = "weighted",
        comparison = paste0("bootstrap_", replicate),
        variation_of_information = igraph::compare(
          baseline,
          bootstrap_membership,
          method = "vi"
        ),
        normalized_mutual_information = igraph::compare(
          baseline,
          bootstrap_membership,
          method = "nmi"
        ),
        stringsAsFactors = FALSE
      )
  }
}
stability_summary <- data.table::rbindlist(stability_rows, fill = TRUE)
write_csv_utf8(
  as.data.frame(stability_summary),
  file.path(audit_table_dir, "leiden_stability_summary.csv")
)

paper_authors <- data.table::as.data.table(authorships_long)
paper_authors <- paper_authors[paper_key %in% network_panel$paper_key]
paper_authors <- unique(paper_authors[, .(paper_key, author_id)])
paper_authors[, community := weighted_baseline[author_id]]
paper_authors <- paper_authors[!is.na(community)]

paper_summary <- paper_authors[, .(
  community_authors = .N
), by = .(paper_key, community)][community_authors >= 2L]
paper_meta <- data.table::as.data.table(network_panel[, c(
  "paper_key",
  "retraction_year_first",
  "publisher",
  family_columns
)])
paper_summary <- merge(
  paper_summary,
  paper_meta,
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)

edge_summary$community_a <- weighted_baseline[edge_summary$author_lo]
edge_summary$community_b <- weighted_baseline[edge_summary$author_hi]
internal_edges <- edge_summary[
  !is.na(edge_summary$community_a) &
    edge_summary$community_a == edge_summary$community_b,
  ,
  drop = FALSE
]

community_ids <- sort(unique(weighted_baseline))
profile_rows <- lapply(community_ids, function(community_id) {
  members <- paper_summary[community == community_id]
  internal <- internal_edges[
    internal_edges$community_a == community_id,
    ,
    drop = FALSE
  ]
  if (nrow(members) == 0L) {
    return(NULL)
  }
  family_counts <- vapply(
    family_columns,
    function(family) sum(members[[family]] %in% TRUE),
    integer(1)
  )
  profile <- data.frame(
    community_id = community_id,
    authors = sum(weighted_baseline == community_id),
    papers_with_two_members = nrow(members),
    years = data.table::uniqueN(members$retraction_year_first),
    first_year = min(members$retraction_year_first, na.rm = TRUE),
    last_year = max(members$retraction_year_first, na.rm = TRUE),
    internal_edges = nrow(internal),
    repeated_internal_edges = sum(internal$paper_count >= 2L),
    multi_year_repeated_internal_edges = sum(
      internal$paper_count >= 2L & internal$year_span > 0L
    ),
    publisher_count = data.table::uniqueN(members$publisher),
    papers_2023 = sum(members$retraction_year_first == 2023L),
    share_2023 = mean(members$retraction_year_first == 2023L),
    stringsAsFactors = FALSE
  )
  for (family in family_columns) {
    profile[[paste0("papers_", family)]] <- family_counts[[family]]
  }
  profile
})
community_profiles <- data.table::rbindlist(
  profile_rows,
  fill = TRUE
)
data.table::setorder(
  community_profiles,
  -repeated_internal_edges,
  -multi_year_repeated_internal_edges,
  -papers_with_two_members,
  community_id
)
write_csv_utf8(
  as.data.frame(community_profiles),
  file.path(audit_table_dir, "leiden_community_profiles.csv")
)

top_communities <- community_profiles[
  papers_with_two_members >= 5L &
    years >= 2L,
  ,
  drop = FALSE
]
top_communities <- head(top_communities, 50L)
write_csv_utf8(
  as.data.frame(top_communities),
  file.path(audit_table_dir, "leiden_top_communities_exploratory.csv")
)

saveRDS(
  partitions,
  file.path(processed_dir, "p1", "leiden_partitions.rds")
)
write_audit_manifest()
message("Leiden community exploration completed.")
