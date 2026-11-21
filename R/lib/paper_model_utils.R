paper_team_size_bin <- function(x) {
  values <- as.numeric(x)
  labels <- ifelse(
    is.na(values),
    NA_character_,
    ifelse(
      values <= 5L,
      as.character(values),
      ifelse(values <= 10L, "6-10", "11+")
    )
  )
  factor(
    labels,
    levels = c("1", "2", "3", "4", "5", "6-10", "11+")
  )
}

paper_prepare_covariates <- function(data, publisher_levels = 12L) {
  data$team_size_bin <- paper_team_size_bin(data$team_size)
  data$publication_year_c <- data$publication_year - 2018
  data$publication_year_c2 <- data$publication_year_c^2
  data$match_group <- factor(data$match_group)
  data$match_layer <- factor(ifelse(
    is.na(data$match_layer) | data$match_layer == "",
    "unknown",
    data$match_layer
  ))
  data$field_group <- factor(ifelse(
    is.na(data$field_id) | data$field_id == "",
    "unknown",
    data$field_id
  ))
  data$openalex_type <- factor(ifelse(
    is.na(data$openalex_type) | data$openalex_type == "",
    "unknown",
    data$openalex_type
  ))
  publisher_label <- ifelse(
    is.na(data$publisher) | data$publisher == "",
    "unknown",
    data$publisher
  )
  publisher_counts <- sort(table(publisher_label), decreasing = TRUE)
  retained_publishers <- names(publisher_counts)[
    seq_len(min(publisher_levels, length(publisher_counts)))
  ]
  data$publisher_group <- factor(ifelse(
    publisher_label %in% retained_publishers,
    publisher_label,
    "other"
  ))
  data$case_indicator <- as.integer(data$is_retraction %in% TRUE)
  data
}

paper_extract_coefficient <- function(
    coefficient_matrix,
    term,
    exponentiate = TRUE,
    confidence_level = 0.95) {
  estimate_column <- intersect(
    c("Estimate", "coef"),
    colnames(coefficient_matrix)
  )
  error_column <- intersect(
    c("Std. Error", "se(coef)"),
    colnames(coefficient_matrix)
  )
  if (length(estimate_column) == 0L || length(error_column) == 0L) {
    stop("Coefficient matrix requires an estimate and standard error column.")
  }
  if (!term %in% rownames(coefficient_matrix)) {
    return(data.frame(
      estimate = NA_real_,
      std_error = NA_real_,
      effect_ratio = NA_real_,
      ci_low = NA_real_,
      ci_high = NA_real_,
      p_value = NA_real_,
      stringsAsFactors = FALSE
    ))
  }
  estimate <- coefficient_matrix[term, estimate_column[[1]]]
  std_error <- coefficient_matrix[term, error_column[[1]]]
  p_column <- grep("^Pr\\(", colnames(coefficient_matrix), value = TRUE)
  p_value <- if (length(p_column) > 0L) {
    coefficient_matrix[term, p_column[[1]]]
  } else {
    test_column <- grep("(z|t) value", colnames(coefficient_matrix), value = TRUE)
    if (length(test_column) > 0L) {
      test_statistic <- coefficient_matrix[term, test_column[[1]]]
      2 * stats::pnorm(abs(test_statistic), lower.tail = FALSE)
    } else {
      NA_real_
    }
  }
  z_value <- stats::qnorm(1 - (1 - confidence_level) / 2)
  data.frame(
    estimate = estimate,
    std_error = std_error,
    effect_ratio = if (exponentiate) exp(estimate) else estimate,
    ci_low = if (exponentiate) {
      exp(estimate - z_value * std_error)
    } else {
      estimate - z_value * std_error
    },
    ci_high = if (exponentiate) {
      exp(estimate + z_value * std_error)
    } else {
      estimate + z_value * std_error
    },
    p_value = p_value,
    stringsAsFactors = FALSE
  )
}

paper_cluster_robust_effect <- function(
    model,
    cluster,
    term,
    exponentiate = TRUE) {
  estimates <- stats::coef(model)
  covariance <- sandwich::vcovCL(
    model,
    cluster = cluster,
    type = "HC0"
  )
  if (!term %in% names(estimates)) {
    stop("Cluster-robust model does not contain term: ", term)
  }
  estimate <- estimates[[term]]
  std_error <- sqrt(covariance[term, term])
  z_value <- stats::qnorm(0.975)
  data.frame(
    estimate = estimate,
    std_error = std_error,
    effect_ratio = if (exponentiate) exp(estimate) else estimate,
    ci_low = if (exponentiate) {
      exp(estimate - z_value * std_error)
    } else {
      estimate - z_value * std_error
    },
    ci_high = if (exponentiate) {
      exp(estimate + z_value * std_error)
    } else {
      estimate + z_value * std_error
    },
    p_value = 2 * stats::pnorm(abs(estimate / std_error), lower.tail = FALSE),
    stringsAsFactors = FALSE
  )
}
