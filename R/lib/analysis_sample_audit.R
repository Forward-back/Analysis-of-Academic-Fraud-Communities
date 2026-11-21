analysis_safe_rate <- function(x) {
  values <- as.logical(x)
  values <- values[!is.na(values)]
  if (length(values) == 0L) {
    return(NA_real_)
  }
  mean(values)
}

analysis_standardized_mean_difference <- function(x, y) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  x <- x[is.finite(x)]
  y <- y[is.finite(y)]
  if (length(x) < 2L || length(y) < 2L) {
    return(NA_real_)
  }
  pooled <- sqrt((stats::var(x) + stats::var(y)) / 2)
  if (!is.finite(pooled) || pooled == 0) {
    return(NA_real_)
  }
  (mean(x) - mean(y)) / pooled
}

analysis_group_characteristics <- function(data, group_column, family_columns) {
  groups <- split(data, data[[group_column]], drop = TRUE)
  rows <- lapply(names(groups), function(group_name) {
    group_data <- groups[[group_name]]
    row <- data.frame(
      sample_group = group_name,
      cases = nrow(group_data),
      control_works = sum(group_data$controls_matched, na.rm = TRUE),
      controls_matched_mean = mean(
        group_data$controls_matched,
        na.rm = TRUE
      ),
      zero_control_share = mean(group_data$controls_matched == 0L),
      source_missing_share = analysis_safe_rate(!group_data$source_present),
      case_institution_complete_share = analysis_safe_rate(
        group_data$all_authors_have_institution
      ),
      network_complete_share = mean(group_data$network_complete),
      any_control_metadata_gap_share = mean(
        group_data$any_control_metadata_gap
      ),
      mean_publication_year = mean(
        group_data$publication_year,
        na.rm = TRUE
      ),
      mean_retraction_year = mean(
        group_data$retraction_year_first,
        na.rm = TRUE
      ),
      share_retraction_2023 = mean(
        group_data$retraction_year_first == 2023L,
        na.rm = TRUE
      ),
      mean_team_size = mean(group_data$n_authorships, na.rm = TRUE),
      median_team_size = stats::median(
        group_data$n_authorships,
        na.rm = TRUE
      ),
      stringsAsFactors = FALSE
    )
    for (family in family_columns) {
      row[[paste0(family, "_share")]] <- mean(group_data[[family]] %in% TRUE)
    }
    row
  })
  result <- data.table::rbindlist(rows, fill = TRUE)
  as.data.frame(result)
}

analysis_standardized_comparison <- function(
    data,
    included_column,
    metric_columns
) {
  included <- data[[included_column]] %in% TRUE
  rows <- lapply(metric_columns, function(metric) {
    included_values <- as.numeric(data[[metric]][included])
    excluded_values <- as.numeric(data[[metric]][!included])
    data.frame(
      metric = metric,
      included_n = sum(is.finite(included_values)),
      excluded_n = sum(is.finite(excluded_values)),
      included_mean = mean(included_values, na.rm = TRUE),
      excluded_mean = mean(excluded_values, na.rm = TRUE),
      standardized_mean_difference = analysis_standardized_mean_difference(
        included_values,
        excluded_values
      ),
      stringsAsFactors = FALSE
    )
  })
  data.table::rbindlist(rows, fill = TRUE)
}

analysis_coverage_by_group <- function(data, group_column, included_column) {
  audit_data <- data.table::data.table(
    group_value = as.character(data[[group_column]]),
    included = data[[included_column]] %in% TRUE,
    team_size = as.numeric(data$n_authorships)
  )
  result <- audit_data[
    ,
    .(
      cases = .N,
      network_cases = sum(included),
      excluded_cases = sum(!included),
      network_coverage = mean(included),
      included_mean_team_size = mean(
        team_size[included],
        na.rm = TRUE
      ),
      excluded_mean_team_size = mean(
        team_size[!included],
        na.rm = TRUE
      ),
      team_size_smd = analysis_standardized_mean_difference(
        team_size[included],
        team_size[!included]
      )
    ),
    by = group_value
  ]
  as.data.frame(result)
}
