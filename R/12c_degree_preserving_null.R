#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

seed <- as.integer(project_config$project$random_seed)
permutations <- 200L
edge_summary <- readRDS(file.path(
  processed_dir,
  "p1",
  "network_edge_summary.rds"
))

edge_occurrences <- edge_summary[rep(
  seq_len(nrow(edge_summary)),
  edge_summary$paper_count
), c("author_lo", "author_hi"), drop = FALSE]
author_ids <- sort(unique(c(
  edge_occurrences$author_lo,
  edge_occurrences$author_hi
)))
author_count <- length(author_ids)
edge_count <- nrow(edge_occurrences)
endpoints <- c(
  match(edge_occurrences$author_lo, author_ids),
  match(edge_occurrences$author_hi, author_ids)
)

count_pair_structure <- function(first, second) {
  self_loops <- sum(first == second)
  keep <- first != second
  first <- first[keep]
  second <- second[keep]
  pair_key <- pmin(first, second) * (author_count + 1) +
    pmax(first, second)
  sorted <- sort.int(pair_key, method = "radix")
  lengths <- rle(sorted)$lengths
  list(
    repeat_edges = sum(lengths >= 2L),
    unique_edges = length(lengths),
    edge_occurrences_non_loop = length(pair_key),
    self_loops = self_loops
  )
}

observed <- count_pair_structure(
  endpoints[seq_len(edge_count)],
  endpoints[edge_count + seq_len(edge_count)]
)

null_rows <- vector("list", permutations)
for (iteration in seq_len(permutations)) {
  set.seed(seed + 30000L + iteration)
  shuffled <- endpoints[sample.int(length(endpoints))]
  result <- count_pair_structure(
    shuffled[seq_len(edge_count)],
    shuffled[edge_count + seq_len(edge_count)]
  )
  null_rows[[iteration]] <- data.frame(
    iteration = iteration,
    repeat_edges = result$repeat_edges,
    unique_edges = result$unique_edges,
    self_loops = result$self_loops,
    stringsAsFactors = FALSE
  )
  if (iteration %% 50L == 0L || iteration == permutations) {
    message("degree-preserving null permutation ", iteration, "/", permutations)
  }
}

null_iterations <- data.table::rbindlist(null_rows, fill = TRUE)
null_mean <- mean(null_iterations$repeat_edges)
null_sd <- stats::sd(null_iterations$repeat_edges)
summary <- data.frame(
  metric = c(
    "permutations",
    "seed",
    "edge_occurrences",
    "authors",
    "observed_repeat_edges",
    "null_repeat_mean",
    "null_repeat_sd",
    "null_repeat_q025",
    "null_repeat_q975",
    "repeat_excess",
    "repeat_z",
    "repeat_p_one_sided",
    "mean_self_loops",
    "max_self_loops"
  ),
  value = c(
    permutations,
    seed,
    edge_count,
    author_count,
    observed$repeat_edges,
    null_mean,
    null_sd,
    unname(stats::quantile(null_iterations$repeat_edges, 0.025)),
    unname(stats::quantile(null_iterations$repeat_edges, 0.975)),
    observed$repeat_edges - null_mean,
    if (is.finite(null_sd) && null_sd > 0) {
      (observed$repeat_edges - null_mean) / null_sd
    } else {
      NA_real_
    },
    (1 + sum(null_iterations$repeat_edges >= observed$repeat_edges)) /
      (permutations + 1),
    mean(null_iterations$self_loops),
    max(null_iterations$self_loops)
  ),
  stringsAsFactors = FALSE
)

write_csv_utf8(
  summary,
  file.path(audit_table_dir, "network_degree_null_summary.csv")
)
write_csv_utf8(
  as.data.frame(null_iterations),
  file.path(audit_table_dir, "network_degree_null_iterations.csv")
)
saveRDS(
  null_iterations,
  file.path(processed_dir, "p1", "network_degree_null_iterations.rds")
)
write_audit_manifest()
message("Degree-preserving null sensitivity completed.")
