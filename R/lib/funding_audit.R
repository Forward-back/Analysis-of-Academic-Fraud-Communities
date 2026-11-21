allocate_stratified_sample <- function(strata_sizes, maximum_n) {
  sizes <- as.integer(strata_sizes)
  if (any(is.na(sizes)) || any(sizes < 0L)) {
    stop("Stratum sizes must be non-negative integers.")
  }
  total <- sum(sizes)
  maximum_n <- as.integer(maximum_n)
  if (maximum_n >= total) {
    return(sizes)
  }
  nonempty <- which(sizes > 0L)
  if (length(nonempty) == 0L) {
    return(integer(length(sizes)))
  }
  if (length(nonempty) > maximum_n) {
    keep <- nonempty[
      order(-sizes[nonempty], seq_along(nonempty))
    ][seq_len(maximum_n)]
    allocation <- integer(length(sizes))
    allocation[keep] <- 1L
    return(allocation)
  }
  allocation <- integer(length(sizes))
  allocation[nonempty] <- 1L
  remaining <- maximum_n - length(nonempty)
  while (remaining > 0L) {
    deficits <- sizes * maximum_n / total - allocation
    eligible <- which(sizes > allocation)
    if (length(eligible) == 0L) {
      break
    }
    chosen <- eligible[
      order(
        -deficits[eligible],
        -sizes[eligible],
        eligible
      )
    ][[1]]
    allocation[[chosen]] <- allocation[[chosen]] + 1L
    remaining <- remaining - 1L
  }
  allocation
}

funding_sample_within_cluster <- function(
    data,
    maximum_n = 20L,
    seed,
    cluster_id,
    paper_column = "paper_key",
    year_column = "retraction_year_first",
    publisher_column = "publisher") {
  required <- c(paper_column, year_column, publisher_column)
  missing <- setdiff(required, names(data))
  if (length(missing) > 0L) {
    stop("Missing funding sample columns: ", paste(missing, collapse = ", "))
  }
  if (nrow(data) <= maximum_n) {
    result <- data
    result$funding_stratum <- paste(
      result[[year_column]],
      result[[publisher_column]],
      sep = "|"
    )
    result$stratum_size <- ave(
      seq_len(nrow(result)),
      result$funding_stratum,
      FUN = length
    )
    result$stratum_sample_n <- result$stratum_size
    result$funding_sample_rank <- seq_len(nrow(result))
    return(result)
  }
  data <- data[
    order(
      data[[year_column]],
      data[[publisher_column]],
      data[[paper_column]]
    ),
    ,
    drop = FALSE
  ]
  data$funding_stratum <- paste(
    data[[year_column]],
    data[[publisher_column]],
    sep = "|"
  )
  strata <- split(seq_len(nrow(data)), data$funding_stratum, drop = TRUE)
  allocation <- allocate_stratified_sample(
    vapply(strata, length, integer(1)),
    maximum_n
  )
  set.seed(as.integer(seed))
  selected <- list()
  for (index in seq_along(strata)) {
    indices <- strata[[index]]
    if (allocation[[index]] == 0L) {
      next
    }
    chosen <- if (allocation[[index]] >= length(indices)) {
      indices
    } else {
      indices[sample.int(
        length(indices),
        size = allocation[[index]],
        replace = FALSE
      )]
    }
    block <- data[chosen, , drop = FALSE]
    block$stratum_size <- length(indices)
    block$stratum_sample_n <- allocation[[index]]
    block$funding_sample_rank <- rank(
      block[[paper_column]],
      ties.method = "first"
    )
    selected[[length(selected) + 1L]] <- block
  }
  result <- do.call(rbind, selected)
  rownames(result) <- NULL
  result
}
