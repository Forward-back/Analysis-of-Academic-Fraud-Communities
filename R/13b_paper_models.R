#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/paper_model_utils.R", encoding = "UTF-8")

if (!requireNamespace("lme4", quietly = TRUE)) {
  stop("Package 'lme4' is required for paper-level models.")
}
if (!requireNamespace("survival", quietly = TRUE)) {
  stop("Package 'survival' is required for conditional logistic models.")
}
if (!requireNamespace("sandwich", quietly = TRUE)) {
  stop("Package 'sandwich' is required for clustered count models.")
}
suppressPackageStartupMessages(library(survival))

family_columns <- c(
  "family_publication_process",
  "family_image_integrity",
  "family_plagiarism_authorship"
)
main_outcomes <- c(
  "cross_tier",
  "domestic_cross_province",
  "international",
  "positive_distance"
)

paper_panel <- readRDS(file.path(
  processed_dir,
  "p1",
  "analysis_paper_panel.rds"
))$paper_panel
paper_panel$positive_distance <-
  is.finite(paper_panel$median_domestic_geo_distance_km) &
  paper_panel$median_domestic_geo_distance_km > 0

assert_columns(
  paper_panel,
  c(
    "match_group",
    "is_retraction",
    "analysis_institution_eligible",
    "institution_observed",
    "team_size",
    "publication_year",
    "field_id",
    "openalex_type",
    "match_layer",
    "publisher",
    "median_domestic_geo_distance_km",
    main_outcomes[seq_len(3)],
    family_columns
  ),
  "paper analysis panel"
)

case_rows <- paper_panel[paper_panel$is_retraction, , drop = FALSE]
case_year_map <- tapply(
  case_rows$retraction_year_first,
  case_rows$match_group,
  function(values) {
    values <- values[!is.na(values)]
    if (length(values) == 0L) NA_integer_ else values[[1]]
  }
)

build_family_data <- function(family, require_institution) {
  family_case_groups <- unique(paper_panel$match_group[
    paper_panel$is_retraction & paper_panel[[family]] %in% TRUE
  ])
  data <- paper_panel[
    (
      paper_panel$is_retraction & paper_panel[[family]] %in% TRUE
    ) |
      (
        !paper_panel$is_retraction &
          paper_panel$match_group %in% family_case_groups
      ),
    ,
    drop = FALSE
  ]
  if (require_institution) {
    data <- data[
      data$analysis_institution_eligible & data$institution_observed,
      ,
      drop = FALSE
    ]
  }
  data$case_retraction_year <- unname(
    case_year_map[as.character(data$match_group)]
  )
  paper_prepare_covariates(data)
}

capture_model <- function(expression) {
  model_warnings <- character()
  result <- withCallingHandlers(
    tryCatch(
      force(expression),
      error = function(error) error
    ),
    warning = function(warning) {
      model_warnings <<- c(model_warnings, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }
  )
  list(model = result, warnings = unique(model_warnings))
}

model_fit_row <- function(
    model_type,
    analysis_set,
    family,
    outcome,
    data,
    model,
    warnings,
    status,
    random_effect_sd = NA_real_,
    dispersion = NA_real_) {
  converged <- FALSE
  singular <- NA
  aic <- NA_real_
  bic <- NA_real_
  if (inherits(model, "merMod")) {
    convergence_code <- model@optinfo$conv$opt
    convergence_messages <- unlist(
      model@optinfo$conv$lme4$messages,
      use.names = FALSE
    )
    converged <- isTRUE(convergence_code == 0L) &&
      length(convergence_messages) == 0L
    warnings <- unique(c(warnings, convergence_messages))
    singular <- tryCatch(
      lme4::isSingular(model),
      error = function(error) NA
    )
    aic <- stats::AIC(model)
    bic <- stats::BIC(model)
  } else if (inherits(model, "coxph")) {
    target_coefficient <- stats::coef(model)[["is_retractionTRUE"]]
    converged <- is.finite(target_coefficient)
    aic <- stats::AIC(model)
    bic <- stats::BIC(model)
  } else if (inherits(model, "negbin") || inherits(model, "glm")) {
    converged <- isTRUE(model$converged)
    aic <- stats::AIC(model)
    bic <- stats::BIC(model)
  }
  data.frame(
    model_type = model_type,
    analysis_set = analysis_set,
    analysis_family = family,
    outcome = outcome,
    status = status,
    rows = nrow(data),
    cases = sum(data$is_retraction %in% TRUE),
    controls = sum(!data$is_retraction %in% TRUE),
    match_groups = length(unique(data$match_group)),
    outcome_events = if (
      outcome %in% c("team_size", "positive_distance_magnitude")
    ) {
      NA_integer_
    } else if (outcome %in% names(data)) {
      sum(data[[outcome]] %in% TRUE, na.rm = TRUE)
    } else {
      NA_integer_
    },
    converged = converged,
    singular = singular,
    random_effect_sd = random_effect_sd,
    dispersion = dispersion,
    aic = aic,
    bic = bic,
    warnings = paste(warnings, collapse = " | "),
    stringsAsFactors = FALSE
  )
}

conditional_formula <- function(outcome) {
  stats::as.formula(paste(
    outcome,
    "~ is_retraction + team_size_bin + strata(match_group)"
  ))
}

fit_mixed_binary <- function(
    data,
    family,
    outcome,
    analysis_set) {
  model_data <- data[
    !is.na(data[[outcome]]),
    ,
    drop = FALSE
  ]
  model_data$model_outcome <- as.integer(model_data[[outcome]])
  captured <- capture_model(
    lme4::glmer(
      stats::as.formula(paste(
        "model_outcome ~ is_retraction + team_size_bin +",
        "publication_year_c + publication_year_c2 + match_layer +",
        "field_group + openalex_type + publisher_group +",
        "(1 | match_group)"
      )),
      data = model_data,
      family = stats::binomial(),
      nAGQ = 0,
      control = lme4::glmerControl(
        optimizer = "bobyqa",
        optCtrl = list(maxfun = 30000)
      )
    )
  )
  if (inherits(captured$model, "error")) {
    effect <- data.frame(
      model_type = "primary_mixed",
      analysis_set = analysis_set,
      analysis_family = family,
      outcome = outcome,
      effect_scale = "odds_ratio",
      estimate = NA_real_,
      std_error = NA_real_,
      effect_ratio = NA_real_,
      ci_low = NA_real_,
      ci_high = NA_real_,
      p_value = NA_real_,
      stringsAsFactors = FALSE
    )
    fit <- model_fit_row(
      "primary_mixed",
      analysis_set,
      family,
      outcome,
      model_data,
      captured$model,
      c(captured$warnings, conditionMessage(captured$model)),
      "error"
    )
    return(list(effect = effect, fit = fit))
  }
  coefficient <- paper_extract_coefficient(
    summary(captured$model)$coefficients,
    "is_retractionTRUE"
  )
  effect <- cbind(
    data.frame(
      model_type = "primary_mixed",
      analysis_set = analysis_set,
      analysis_family = family,
      outcome = outcome,
      effect_scale = "odds_ratio",
      stringsAsFactors = FALSE
    ),
    coefficient
  )
  random_effect_sd <- sqrt(as.numeric(
    lme4::VarCorr(captured$model)$match_group[1, 1]
  ))
  fit <- model_fit_row(
    "primary_mixed",
    analysis_set,
    family,
    outcome,
    model_data,
    captured$model,
    captured$warnings,
    "ok",
    random_effect_sd = random_effect_sd
  )
  list(effect = effect, fit = fit)
}

fit_conditional_binary <- function(
    data,
    family,
    outcome,
    analysis_set) {
  model_data <- data[
    !is.na(data[[outcome]]),
    ,
    drop = FALSE
  ]
  model_data$model_outcome <- as.integer(model_data[[outcome]])
  captured <- capture_model(
    survival::clogit(
      conditional_formula("model_outcome"),
      data = model_data
    )
  )
  if (inherits(captured$model, "error")) {
    effect <- data.frame(
      model_type = "matched_conditional",
      analysis_set = analysis_set,
      analysis_family = family,
      outcome = outcome,
      effect_scale = "odds_ratio",
      estimate = NA_real_,
      std_error = NA_real_,
      effect_ratio = NA_real_,
      ci_low = NA_real_,
      ci_high = NA_real_,
      p_value = NA_real_,
      stringsAsFactors = FALSE
    )
    fit <- model_fit_row(
      "matched_conditional",
      analysis_set,
      family,
      outcome,
      model_data,
      captured$model,
      c(captured$warnings, conditionMessage(captured$model)),
      "error"
    )
    return(list(effect = effect, fit = fit))
  }
  coefficient <- paper_extract_coefficient(
    summary(captured$model)$coefficients,
    "is_retractionTRUE"
  )
  effect <- cbind(
    data.frame(
      model_type = "matched_conditional",
      analysis_set = analysis_set,
      analysis_family = family,
      outcome = outcome,
      effect_scale = "odds_ratio",
      stringsAsFactors = FALSE
    ),
    coefficient
  )
  fit <- model_fit_row(
    "matched_conditional",
    analysis_set,
    family,
    outcome,
    model_data,
    captured$model,
    captured$warnings,
    "ok"
  )
  list(effect = effect, fit = fit)
}

fit_distance_magnitude <- function(
    data,
    family,
    analysis_set) {
  positive_cases <- unique(data$match_group[
    data$is_retraction &
      data$positive_distance &
      is.finite(data$median_domestic_geo_distance_km)
  ])
  positive_controls <- unique(data$match_group[
    !data$is_retraction &
      data$positive_distance &
      is.finite(data$median_domestic_geo_distance_km)
  ])
  shared_positive_groups <- intersect(positive_cases, positive_controls)
  model_data <- data[
    data$match_group %in% shared_positive_groups &
      data$positive_distance &
      is.finite(data$median_domestic_geo_distance_km),
    ,
    drop = FALSE
  ]
  model_data$log_distance <- log1p(
    model_data$median_domestic_geo_distance_km
  )
  captured <- capture_model(
    lme4::lmer(
      log_distance ~ is_retraction + team_size_bin +
        publication_year_c + publication_year_c2 +
        match_layer + field_group + openalex_type +
        publisher_group + (1 | match_group),
      data = model_data,
      control = lme4::lmerControl(
        optimizer = "bobyqa",
        optCtrl = list(maxfun = 30000)
      )
    )
  )
  if (inherits(captured$model, "error")) {
    effect <- data.frame(
      model_type = "positive_distance_lmer",
      analysis_set = analysis_set,
      analysis_family = family,
      outcome = "positive_distance_magnitude",
      effect_scale = "geometric_mean_ratio",
      estimate = NA_real_,
      std_error = NA_real_,
      effect_ratio = NA_real_,
      ci_low = NA_real_,
      ci_high = NA_real_,
      p_value = NA_real_,
      stringsAsFactors = FALSE
    )
    fit <- model_fit_row(
      "positive_distance_lmer",
      analysis_set,
      family,
      "positive_distance_magnitude",
      model_data,
      captured$model,
      c(captured$warnings, conditionMessage(captured$model)),
      "error"
    )
    return(list(effect = effect, fit = fit))
  }
  coefficient <- paper_extract_coefficient(
    summary(captured$model)$coefficients,
    "is_retractionTRUE"
  )
  effect <- cbind(
    data.frame(
      model_type = "positive_distance_lmer",
      analysis_set = analysis_set,
      analysis_family = family,
      outcome = "positive_distance_magnitude",
      effect_scale = "geometric_mean_ratio",
      stringsAsFactors = FALSE
    ),
    coefficient
  )
  random_effect_sd <- sqrt(as.numeric(
    lme4::VarCorr(captured$model)$match_group[1, 1]
  ))
  fit <- model_fit_row(
    "positive_distance_lmer",
    analysis_set,
    family,
    "positive_distance_magnitude",
    model_data,
    captured$model,
    captured$warnings,
    "ok",
    random_effect_sd = random_effect_sd
  )
  list(effect = effect, fit = fit)
}

fit_team_size_model <- function(
    data,
    family,
    analysis_set) {
  model_data <- data[
    is.finite(data$team_size) & data$team_size > 0,
    ,
    drop = FALSE
  ]
  captured <- capture_model(
    MASS::glm.nb(
      team_size ~ is_retraction + publication_year_c +
        publication_year_c2 + match_layer + field_group +
        openalex_type + publisher_group,
      data = model_data
    )
  )
  if (inherits(captured$model, "error")) {
    effect <- data.frame(
      model_type = "cluster_robust_negative_binomial",
      analysis_set = analysis_set,
      analysis_family = family,
      outcome = "team_size",
      effect_scale = "incidence_rate_ratio",
      estimate = NA_real_,
      std_error = NA_real_,
      effect_ratio = NA_real_,
      ci_low = NA_real_,
      ci_high = NA_real_,
      p_value = NA_real_,
      stringsAsFactors = FALSE
    )
    fit <- model_fit_row(
      "cluster_robust_negative_binomial",
      analysis_set,
      family,
      "team_size",
      model_data,
      captured$model,
      c(captured$warnings, conditionMessage(captured$model)),
      "error"
    )
    return(list(effect = effect, fit = fit))
  }
  coefficient <- paper_cluster_robust_effect(
    captured$model,
    cluster = model_data$match_group,
    term = "is_retractionTRUE"
  )
  effect <- cbind(
    data.frame(
      model_type = "cluster_robust_negative_binomial",
      analysis_set = analysis_set,
      analysis_family = family,
      outcome = "team_size",
      effect_scale = "incidence_rate_ratio",
      stringsAsFactors = FALSE
    ),
    coefficient
  )
  fit <- model_fit_row(
    "cluster_robust_negative_binomial",
    analysis_set,
    family,
    "team_size",
    model_data,
    captured$model,
    captured$warnings,
    "ok",
    dispersion = captured$model$theta
  )
  list(effect = effect, fit = fit)
}

family_data_structural <- setNames(
  lapply(family_columns, function(family) {
    build_family_data(family, require_institution = TRUE)
  }),
  family_columns
)
family_data_team <- setNames(
  lapply(family_columns, function(family) {
    build_family_data(family, require_institution = FALSE)
  }),
  family_columns
)

binary_effects <- list()
binary_fits <- list()
continuous_effects <- list()
continuous_fits <- list()

store_result <- function(result, effect_store_name, fit_store_name) {
  parent <- parent.frame()
  effect_store <- get(effect_store_name, envir = parent)
  fit_store <- get(fit_store_name, envir = parent)
  effect_store[[length(effect_store) + 1L]] <- result$effect
  fit_store[[length(fit_store) + 1L]] <- result$fit
  assign(effect_store_name, effect_store, envir = parent)
  assign(fit_store_name, fit_store, envir = parent)
  invisible(NULL)
}

for (family in family_columns) {
  structural_data <- family_data_structural[[family]]
  team_data <- family_data_team[[family]]
  for (outcome in main_outcomes) {
    store_result(
      fit_mixed_binary(structural_data, family, outcome, "primary"),
      "binary_effects",
      "binary_fits"
    )
    store_result(
      fit_conditional_binary(
        structural_data,
        family,
        outcome,
        "primary"
      ),
      "binary_effects",
      "binary_fits"
    )
  }
  store_result(
    fit_distance_magnitude(structural_data, family, "primary"),
    "continuous_effects",
    "continuous_fits"
  )
  store_result(
    fit_team_size_model(team_data, family, "primary"),
    "continuous_effects",
    "continuous_fits"
  )

  structural_non2023 <- structural_data[
    is.na(structural_data$case_retraction_year) |
      structural_data$case_retraction_year != 2023L,
    ,
    drop = FALSE
  ]
  team_non2023 <- team_data[
    is.na(team_data$case_retraction_year) |
      team_data$case_retraction_year != 2023L,
    ,
    drop = FALSE
  ]
  for (outcome in main_outcomes) {
    store_result(
      fit_mixed_binary(
        structural_non2023,
        family,
        outcome,
        "exclude_2023"
      ),
      "binary_effects",
      "binary_fits"
    )
    store_result(
      fit_conditional_binary(
        structural_non2023,
        family,
        outcome,
        "exclude_2023"
      ),
      "binary_effects",
      "binary_fits"
    )
  }
  store_result(
    fit_distance_magnitude(
      structural_non2023,
      family,
      "exclude_2023"
    ),
    "continuous_effects",
    "continuous_fits"
  )
  store_result(
    fit_team_size_model(
      team_non2023,
      family,
      "exclude_2023"
    ),
    "continuous_effects",
    "continuous_fits"
  )
}

binary_effects <- data.table::rbindlist(binary_effects, fill = TRUE)
binary_fits <- data.table::rbindlist(binary_fits, fill = TRUE)
continuous_effects <- data.table::rbindlist(continuous_effects, fill = TRUE)
continuous_fits <- data.table::rbindlist(continuous_fits, fill = TRUE)

add_bh_fdr <- function(effects) {
  effects$bh_fdr <- NA_real_
  grouping <- interaction(
    effects$analysis_set,
    effects$model_type,
    effects$outcome,
    drop = TRUE
  )
  for (group_indices in split(seq_len(nrow(effects)), grouping)) {
    valid <- group_indices[
      is.finite(effects$p_value[group_indices])
    ]
    if (length(valid) > 0L) {
      effects$bh_fdr[valid] <- stats::p.adjust(
        effects$p_value[valid],
        method = "BH"
      )
    }
  }
  effects
}

binary_effects <- add_bh_fdr(binary_effects)
continuous_effects <- add_bh_fdr(continuous_effects)

primary_effect <- function(family, outcome, model_type = "primary_mixed") {
  effect_frame <- as.data.frame(binary_effects)
  row <- effect_frame[
    effect_frame$analysis_set == "primary" &
      effect_frame$analysis_family == family &
      effect_frame$outcome == outcome &
      effect_frame$model_type == model_type,
    ,
    drop = FALSE
  ]
  if (nrow(row) == 0L) {
    return(NA_real_)
  }
  row$effect_ratio[[1]]
}

hypothesis_evidence <- data.frame(
  hypothesis = c("H1", "H2", "H3", "H4", "H5"),
  status = c(
    "not_supported_in_current_sample",
    "partial_support",
    "pending_network_conditional_models",
    "pending_2023_external_evidence",
    "pending_funding_audit"
  ),
  evidence = c(
    paste0(
      "Adjusted cross-tier ORs: publication process ",
      sprintf("%.3f", primary_effect(
        "family_publication_process",
        "cross_tier"
      )),
      "; image integrity ",
      sprintf("%.3f", primary_effect(
        "family_image_integrity",
        "cross_tier"
      )),
      "; plagiarism/authorship ",
      sprintf("%.3f", primary_effect(
        "family_plagiarism_authorship",
        "cross_tier"
      )),
      ". All are below 1, opposite to H1."
    ),
    paste0(
      "Image integrity adjusted ORs: positive distance ",
      sprintf("%.3f", primary_effect(
        "family_image_integrity",
        "positive_distance"
      )),
      ", domestic cross-province ",
      sprintf("%.3f", primary_effect(
        "family_image_integrity",
        "domestic_cross_province"
      )),
      ", international ",
      sprintf("%.3f", primary_effect(
        "family_image_integrity",
        "international"
      )),
      ". Local structure is lower and cross-province is lower, but international cooperation is higher."
    ),
    "Requires conditional family-specific repeat-collaboration comparisons.",
    "Requires the external publisher and journal governance evidence table.",
    "Requires frozen audit-cluster funding coverage."
  ),
  stringsAsFactors = FALSE
)

write_csv_utf8(
  as.data.frame(binary_effects),
  file.path(audit_table_dir, "p1b_binary_effects.csv")
)
write_csv_utf8(
  as.data.frame(binary_fits),
  file.path(audit_table_dir, "p1b_binary_model_fit.csv")
)
write_csv_utf8(
  as.data.frame(continuous_effects),
  file.path(audit_table_dir, "p1b_continuous_effects.csv")
)
write_csv_utf8(
  as.data.frame(continuous_fits),
  file.path(audit_table_dir, "p1b_continuous_model_fit.csv")
)
write_csv_utf8(
  hypothesis_evidence,
  file.path(audit_table_dir, "p1b_hypothesis_evidence.csv")
)

model_specifications <- data.frame(
  model_type = c(
    "primary_mixed",
    "matched_conditional",
    "positive_distance_lmer",
    "cluster_robust_negative_binomial"
  ),
  purpose = c(
    "Primary random-intercept logistic model with full covariate adjustment.",
    "Matched-set conditional logistic robustness using team size and match layer.",
    "Within matched sets with a positive-distance case and control.",
    "Negative-binomial team-size model with match-group clustered standard errors."
  ),
  formula = c(
    paste(
      "outcome ~ is_retraction + team_size_bin + publication_year_c +",
      "publication_year_c2 + match_layer + field_group +",
      "openalex_type + publisher_group + (1 | match_group)"
    ),
    paste(
      "outcome ~ is_retraction + team_size_bin + strata(match_group)"
    ),
    paste(
      "log_distance ~ is_retraction + team_size_bin +",
      "publication_year_c + publication_year_c2 + match_layer +",
      "field_group + openalex_type + publisher_group + (1 | match_group)"
    ),
    paste(
      "team_size ~ is_retraction + publication_year_c +",
      "publication_year_c2 + match_layer + field_group +",
      "openalex_type + publisher_group"
    )
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  model_specifications,
  file.path(audit_table_dir, "p1b_model_specifications.csv")
)

write_audit_manifest()
message("P1B paper-level models completed.")
