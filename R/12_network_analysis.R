#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

args <- commandArgs(trailingOnly = TRUE)
permutations <- 1000L
seed <- as.integer(project_config$project$random_seed)
detected_cores <- parallel::detectCores()
workers <- if (is.na(detected_cores)) {
  1L
} else {
  min(4L, max(1L, detected_cores - 1L))
}
for (arg in args) {
  if (grepl("^--permutations=", arg)) {
    permutations <- as.integer(sub("^--permutations=", "", arg))
  } else if (grepl("^--seed=", arg)) {
    seed <- as.integer(sub("^--seed=", "", arg))
  } else if (grepl("^--workers=", arg)) {
    workers <- as.integer(sub("^--workers=", "", arg))
  } else {
    stop("Unknown argument: ", arg)
  }
}
if (is.na(permutations) || permutations < 1L) {
  stop("Permutation count must be a positive integer.")
}
if (is.na(workers) || workers < 1L) {
  stop("Worker count must be a positive integer.")
}

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

paper_columns <- c(
  "paper_key",
  "retraction_year_first",
  "field_id",
  "publisher",
  family_columns
)
paper_meta <- data.table::as.data.table(
  network_panel[, paper_columns, drop = FALSE]
)
paper_meta[, field_id := ifelse(
  is.na(field_id) | field_id == "",
  "missing_field",
  field_id
)]
paper_meta[, publisher := ifelse(
  is.na(publisher) | publisher == "",
  "missing_publisher",
  publisher
)]
paper_meta[, stratum := paste(
  retraction_year_first,
  field_id,
  publisher,
  sep = "|"
)]

authorships <- data.table::as.data.table(authorships_long)
authorships <- authorships[paper_key %in% network_panel$paper_key]
authorships <- unique(authorships[, .(paper_key, author_id)])
authorships <- authorships[!is.na(author_id) & author_id != ""]
data.table::setorder(authorships, paper_key, author_id)

author_ids <- sort(unique(authorships$author_id))
author_count <- length(author_ids)
authorships[, author_int := match(author_id, author_ids)]
authorships <- merge(
  authorships,
  paper_meta,
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)
paper_keys <- sort(unique(authorships$paper_key))
authorships[, paper_index := match(paper_key, paper_keys)]
data.table::setorder(authorships, paper_index, author_int)
authorships[, slot_id := seq_len(.N)]
authorships[, original_author_int := author_int]
paper_meta <- paper_meta[match(paper_keys, paper_key)]
paper_meta[, paper_index := seq_len(.N)]
paper_of_slot <- authorships$paper_index
paper_stratum <- paper_meta$stratum
paper_slot_indices <- split(
  seq_len(nrow(authorships)),
  authorships$paper_index
)
stratum_pools <- lapply(
  split(authorships$author_int, authorships$stratum),
  function(ids) {
    frequencies <- table(ids)
    list(
      ids = as.integer(names(frequencies)),
      weights = as.numeric(frequencies)
    )
  }
)

pair_slots <- authorships[, {
  slot_ids <- slot_id
  if (length(slot_ids) < 2L) {
    NULL
  } else {
    pair_matrix <- utils::combn(slot_ids, 2L)
    list(
      slot_a = pair_matrix[1L, ],
      slot_b = pair_matrix[2L, ]
    )
  }
}, by = paper_index]
pair_paper_index <- pair_slots$paper_index
family_by_paper <- as.matrix(
  paper_meta[, family_columns, with = FALSE]
)
paper_year_code <- as.integer(paper_meta$retraction_year_first) - 2000L

count_repeat_keys <- function(keys) {
  if (length(keys) == 0L) {
    return(0L)
  }
  sorted <- sort.int(keys, method = "radix")
  sum(rle(sorted)$lengths >= 2L)
}

make_pair_keys <- function(slot_authors) {
  first <- slot_authors[pair_slots$slot_a]
  second <- slot_authors[pair_slots$slot_b]
  pmin(first, second) * (author_count + 1) + pmax(first, second)
}

count_multi_year_keys <- function(keys) {
  if (length(keys) == 0L) {
    return(0L)
  }
  year_keys <- unique(sort.int(
    keys * 32 + (paper_year_code[pair_paper_index] + 1L),
    method = "radix"
  ))
  sum(rle(floor(year_keys / 32))$lengths >= 2L)
}

observed_keys <- make_pair_keys(authorships$original_author_int)
observed_global <- count_repeat_keys(observed_keys)
observed_multi_year <- count_multi_year_keys(observed_keys)
observed_family <- vapply(
  seq_along(family_columns),
  function(index) {
    count_repeat_keys(observed_keys[family_by_paper[pair_paper_index, index]])
  },
  integer(1)
)
names(observed_family) <- family_columns

baseline_summary <- utils::read.csv(
  file.path(audit_table_dir, "network_baseline_summary.csv"),
  stringsAsFactors = FALSE
)
baseline_values <- setNames(
  baseline_summary$value,
  baseline_summary$metric
)
if (observed_global != baseline_values[["repeat_edges"]]) {
  stop("Observed repeat edges do not match the frozen network baseline.")
}

run_permutation <- function(iteration, overall_seed, state) {
  set.seed(overall_seed + iteration)
  null_authors <- integer(state$slot_count)
  for (paper_index in seq_along(state$paper_slot_indices)) {
    indices <- state$paper_slot_indices[[paper_index]]
    pool <- state$stratum_pools[[state$paper_stratum[[paper_index]]]]
    selected <- sample.int(
      length(pool$ids),
      size = length(indices),
      replace = FALSE,
      prob = pool$weights
    )
    null_authors[indices] <- pool$ids[selected]
  }

  first <- null_authors[state$pair_slot_a]
  second <- null_authors[state$pair_slot_b]
  pair_keys <- pmin(first, second) * (state$author_count + 1) +
    pmax(first, second)
  sorted <- sort.int(pair_keys, method = "radix")
  repeat_edges <- sum(rle(sorted)$lengths >= 2L)

  year_selected <- state$paper_year_code[state$pair_paper_index] + 1L
  year_keys <- unique(sort.int(
    pair_keys * 32 + year_selected,
    method = "radix"
  ))
  multi_year_repeat_edges <- sum(
    rle(floor(year_keys / 32))$lengths >= 2L
  )

  family_values <- vapply(
    seq_len(state$family_count),
    function(index) {
      selected_keys <- pair_keys[
        state$family_by_paper[state$pair_paper_index, index]
      ]
      sorted_family <- sort.int(selected_keys, method = "radix")
      sum(rle(sorted_family)$lengths >= 2L)
    },
    integer(1)
  )

  row <- data.frame(
    iteration = iteration,
    repeat_edges = repeat_edges,
    multi_year_repeat_edges = multi_year_repeat_edges,
    duplicate_resample_rounds = 0L,
    observed_fallback_papers = 0L,
    stringsAsFactors = FALSE
  )
  for (index in seq_len(state$family_count)) {
    row[[state$family_columns[[index]]]] <- family_values[[index]]
  }
  row
}
environment(run_permutation) <- baseenv()

worker_state <- list(
  slot_count = nrow(authorships),
  paper_slot_indices = paper_slot_indices,
  paper_stratum = paper_stratum,
  stratum_pools = stratum_pools,
  pair_slot_a = pair_slots$slot_a,
  pair_slot_b = pair_slots$slot_b,
  pair_paper_index = pair_paper_index,
  family_by_paper = family_by_paper,
  paper_year_code = paper_year_code,
  author_count = author_count,
  family_count = length(family_columns),
  family_columns = family_columns
)

iteration_ids <- seq_len(permutations)
if (workers == 1L) {
  null_rows <- lapply(iteration_ids, function(iteration) {
    if (iteration %% 50L == 0L || iteration == permutations) {
      message("network null permutation ", iteration, "/", permutations)
    }
    run_permutation(iteration, seed, worker_state)
  })
} else {
  cluster <- parallel::makeCluster(workers)
  parallel::clusterExport(
    cluster,
    c("run_permutation", "worker_state", "seed"),
    envir = environment()
  )
  message("Running ", permutations, " permutations on ", workers, " workers.")
  null_rows <- parallel::parLapplyLB(
    cluster,
    iteration_ids,
    function(iteration) run_permutation(iteration, seed, worker_state)
  )
  parallel::stopCluster(cluster)
}

null_iterations <- data.table::rbindlist(null_rows, fill = TRUE)
data.table::setorder(null_iterations, iteration)
saveRDS(
  null_iterations,
  file.path(processed_dir, "p1", "network_null_iterations.rds")
)
write_csv_utf8(
  as.data.frame(null_iterations),
  file.path(audit_table_dir, "network_null_iterations.csv")
)

summarize_null <- function(observed, values) {
  values <- as.numeric(values)
  null_mean <- mean(values)
  null_sd <- stats::sd(values)
  data.frame(
    observed = observed,
    null_mean = null_mean,
    null_sd = null_sd,
    null_q025 = unname(stats::quantile(values, 0.025)),
    null_q975 = unname(stats::quantile(values, 0.975)),
    excess = observed - null_mean,
    z_score = if (is.finite(null_sd) && null_sd > 0) {
      (observed - null_mean) / null_sd
    } else {
      NA_real_
    },
    p_one_sided = (1 + sum(values >= observed)) / (length(values) + 1),
    stringsAsFactors = FALSE
  )
}

global_null <- summarize_null(
  observed_global,
  null_iterations$repeat_edges
)
multi_year_null <- summarize_null(
  observed_multi_year,
  null_iterations$multi_year_repeat_edges
)
summary_rows <- data.frame(
  metric = c(
    "permutations",
    "workers",
    "seed",
    "observed_repeat_edges",
    "null_repeat_mean",
    "null_repeat_sd",
    "null_repeat_q025",
    "null_repeat_q975",
    "repeat_excess",
    "repeat_z",
    "repeat_p_one_sided",
    "observed_multi_year_repeat_edges",
    "null_multi_year_mean",
    "null_multi_year_q025",
    "null_multi_year_q975",
    "multi_year_excess",
    "multi_year_z",
    "multi_year_p_one_sided",
    "mean_duplicate_resample_rounds",
    "fallback_papers"
  ),
  value = c(
    permutations,
    workers,
    seed,
    global_null$observed,
    global_null$null_mean,
    global_null$null_sd,
    global_null$null_q025,
    global_null$null_q975,
    global_null$excess,
    global_null$z_score,
    global_null$p_one_sided,
    multi_year_null$observed,
    multi_year_null$null_mean,
    multi_year_null$null_q025,
    multi_year_null$null_q975,
    multi_year_null$excess,
    multi_year_null$z_score,
    multi_year_null$p_one_sided,
    mean(null_iterations$duplicate_resample_rounds),
    sum(null_iterations$observed_fallback_papers)
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  summary_rows,
  file.path(audit_table_dir, "network_null_summary.csv")
)

family_null_rows <- lapply(family_columns, function(family) {
  result <- summarize_null(
    observed_family[[family]],
    null_iterations[[family]]
  )
  data.frame(
    analysis_family = family,
    result,
    stringsAsFactors = FALSE
  )
})
family_null <- data.table::rbindlist(family_null_rows, fill = TRUE)
family_null$p_fdr <- stats::p.adjust(
  family_null$p_one_sided,
  method = "BH"
)
write_csv_utf8(
  as.data.frame(family_null),
  file.path(audit_table_dir, "network_null_family_summary.csv")
)

write_audit_manifest()
message("Team-composition network null model completed.")
