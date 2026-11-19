#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

if (!requireNamespace("igraph", quietly = TRUE)) {
  stop("Package 'igraph' is required for network baseline construction.")
}

network_panel <- readRDS(file.path(
  processed_dir,
  "p0",
  "openalex_mainland_network_complete_paper_panel.rds"
))
accepted_panel <- readRDS(file.path(
  processed_dir,
  "p0",
  "openalex_mainland_accepted_paper_panel.rds"
))
authorships_long <- readRDS(file.path(
  processed_dir,
  "p0",
  "mainland_authorships_long.rds"
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

authorships <- data.table::as.data.table(authorships_long)
authorships <- authorships[paper_key %in% network_panel$paper_key]
authorships <- unique(authorships[, .(paper_key, author_id)])
authorships <- authorships[!is.na(author_id) & author_id != ""]
data.table::setorder(authorships, paper_key, author_id)

edges_by_paper <- authorships[, {
  ids <- author_id
  if (length(ids) < 2L) {
    NULL
  } else {
    pair_matrix <- utils::combn(ids, 2L)
    list(
      author_a = pair_matrix[1L, ],
      author_b = pair_matrix[2L, ]
    )
  }
}, by = paper_key]

paper_columns <- c(
  "paper_key",
  "retraction_year_first",
  "publication_year",
  "publisher",
  "field_id",
  family_columns
)
paper_slice <- data.table::as.data.table(
  network_panel[, paper_columns, drop = FALSE]
)
edges <- merge(
  edges_by_paper,
  paper_slice,
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)
edges[, `:=`(
  author_lo = pmin(author_a, author_b),
  author_hi = pmax(author_a, author_b)
)]

edge_summary <- edges[, {
  summary_row <- list(
    paper_count = .N,
    first_retraction_year = min(retraction_year_first, na.rm = TRUE),
    last_retraction_year = max(retraction_year_first, na.rm = TRUE)
  )
  for (family in family_columns) {
    summary_row[[family]] <- any(get(family))
  }
  summary_row
}, by = .(author_lo, author_hi)]
edge_summary$year_span <- edge_summary$last_retraction_year -
  edge_summary$first_retraction_year

saveRDS(
  edge_summary,
  file.path(processed_dir, "p1", "network_edge_summary.rds")
)

vertex_ids <- unique(authorships$author_id)
graph <- igraph::graph_from_data_frame(
  edge_summary[, c("author_lo", "author_hi"), with = FALSE],
  directed = FALSE,
  vertices = data.frame(name = vertex_ids, stringsAsFactors = FALSE)
)
component_info <- igraph::components(graph)
degrees <- igraph::degree(graph)

repeat_edges <- sum(edge_summary$paper_count >= 2L)
multi_year_repeat_edges <- sum(
  edge_summary$paper_count >= 2L & edge_summary$year_span > 0L
)

network_summary <- data.frame(
  metric = c(
    "network_complete_papers",
    "all_accepted_mainland_papers",
    "network_complete_rate",
    "nodes",
    "papers_without_edges",
    "pair_occurrences",
    "unique_edges",
    "repeat_edges",
    "repeat_edge_share",
    "multi_year_repeat_edges",
    "components",
    "largest_component_nodes",
    "largest_component_share",
    "isolated_nodes",
    "mean_degree",
    "median_degree",
    "degree_q95",
    "degree_q99",
    "max_degree",
    "edge_density",
    "global_transitivity"
  ),
  value = c(
    nrow(network_panel),
    nrow(accepted_panel),
    nrow(network_panel) / nrow(accepted_panel),
    length(vertex_ids),
    nrow(network_panel) - data.table::uniqueN(edges$paper_key),
    nrow(edges),
    nrow(edge_summary),
    repeat_edges,
    repeat_edges / nrow(edge_summary),
    multi_year_repeat_edges,
    component_info$no,
    max(component_info$csize),
    max(component_info$csize) / length(vertex_ids),
    sum(degrees == 0L),
    mean(degrees),
    stats::median(degrees),
    unname(stats::quantile(degrees, 0.95)),
    unname(stats::quantile(degrees, 0.99)),
    max(degrees),
    igraph::edge_density(graph),
    igraph::transitivity(graph, type = "global")
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  network_summary,
  file.path(audit_table_dir, "network_baseline_summary.csv")
)

repeat_distribution <- data.table::as.data.table(edge_summary)[
  ,
  .(edges = .N),
  by = paper_count
]
data.table::setorder(repeat_distribution, paper_count)
write_csv_utf8(
  as.data.frame(repeat_distribution),
  file.path(audit_table_dir, "network_repeat_edge_distribution.csv")
)

year_crossing <- data.table::as.data.table(
  edge_summary[edge_summary$paper_count >= 2L, , drop = FALSE]
)
year_crossing[, year_span_group := cut(
  year_span,
  breaks = c(-Inf, 0, 1, 3, Inf),
  labels = c("same_year", "one_year", "two_to_three_years", "four_plus_years"),
  right = TRUE
)]
year_crossing_summary <- year_crossing[
  ,
  .(repeat_edges = .N),
  by = year_span_group
]
write_csv_utf8(
  as.data.frame(year_crossing_summary),
  file.path(audit_table_dir, "network_repeat_year_crossing.csv")
)

summarize_family_network <- function(family) {
  family_edges <- if (family == "all_network") {
    edges
  } else {
    edges[get(family) %in% TRUE]
  }
  pair_counts <- family_edges[, .(
    papers = .N,
    years = data.table::uniqueN(retraction_year_first)
  ), by = .(author_lo, author_hi)]
  data.frame(
    analysis_family = family,
    papers_with_edges = data.table::uniqueN(family_edges$paper_key),
    nodes_with_edges = data.table::uniqueN(c(
      family_edges$author_lo,
      family_edges$author_hi
    )),
    unique_edges = nrow(pair_counts),
    repeat_edges = sum(pair_counts$papers >= 2L),
    repeat_edge_share = mean(pair_counts$papers >= 2L),
    multi_year_repeat_edges = sum(pair_counts$years >= 2L),
    stringsAsFactors = FALSE
  )
}

family_network <- data.table::rbindlist(
  lapply(c("all_network", family_columns), summarize_family_network),
  fill = TRUE
)
write_csv_utf8(
  family_network,
  file.path(audit_table_dir, "network_family_summary.csv")
)

write_audit_manifest()
message("Author-paper network baseline completed.")
