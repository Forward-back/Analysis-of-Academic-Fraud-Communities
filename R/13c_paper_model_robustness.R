#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/analysis_sample_audit.R", encoding = "UTF-8")
source("R/lib/paper_model_utils.R", encoding = "UTF-8")
source("R/lib/institution_structure.R", encoding = "UTF-8")

if (!requireNamespace("lme4", quietly = TRUE)) {
  stop("Package 'lme4' is required for robustness models.")
}
if (!requireNamespace("survival", quietly = TRUE)) {
  stop("Package 'survival' is required for conditional models.")
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

panel <- readRDS(file.path(
  processed_dir,
  "p1",
  "analysis_paper_panel.rds"
))$paper_panel
case_audit <- readRDS(file.path(
  processed_dir,
  "p1",
  "analysis_samples.rds"
))$case_audit
authorships <- readRDS(file.path(
  processed_dir,
  "p0",
  "mainland_authorships_long.rds"
))
control_authors <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_authorships_long.rds"
))
control_works <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_works_full.rds"
))
control_links <- readRDS(file.path(processed_dir, "p1", "control_links.rds"))
institutions <- readRDS(file.path(
  processed_dir,
  "p1",
  "institutions_enriched.rds"
))
event_batches <- data.table::fread(
  file.path(audit_table_dir, "event_2023_same_day_batches.csv"),
  encoding = "UTF-8",
  data.table = FALSE
)

assert_columns(
  panel,
  c(
    "match_group",
    "case_paper_key",
    "is_retraction",
    "openalex_work_id",
    "team_size",
    "publication_year",
    "field_id",
    "openalex_type",
    "match_layer",
    "publisher",
    "cross_tier",
    "legacy_985_211_cross_tier",
    "domestic_cross_province",
    "international",
    "median_domestic_geo_distance_km",
    family_columns
  ),
  "paper analysis panel"
)
assert_columns(
  authorships,
  c("paper_key", "author_id"),
  "mainland authorships"
)
assert_columns(
  control_authors,
  c("control_work_id", "author_id", "institution_ids"),
  "control authorships"
)

panel$positive_distance <-
  is.finite(panel$median_domestic_geo_distance_km) &
  panel$median_domestic_geo_distance_km > 0

prepare_family_data <- function(data, family, require_institution = TRUE) {
  family_case_groups <- unique(data$match_group[
    data$is_retraction & data[[family]] %in% TRUE
  ])
  model_data <- data[
    (
      data$is_retraction & data[[family]] %in% TRUE
    ) |
      (
        !data$is_retraction &
          data$match_group %in% family_case_groups
      ),
    ,
    drop = FALSE
  ]
  if (require_institution) {
    model_data <- model_data[
      model_data$analysis_institution_eligible &
        model_data$institution_observed,
      ,
      drop = FALSE
    ]
  }
  paper_prepare_covariates(model_data)
}

capture_model <- function(expression) {
  model_warnings <- character()
  result <- withCallingHandlers(
    tryCatch(force(expression), error = function(error) error),
    warning = function(warning) {
      model_warnings <<- c(model_warnings, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }
  )
  list(model = result, warnings = unique(model_warnings))
}

fit_summary <- function(
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
    singular <- tryCatch(lme4::isSingular(model), error = function(e) NA)
    aic <- stats::AIC(model)
    bic <- stats::BIC(model)
  } else if (inherits(model, "coxph")) {
    converged <- is.finite(
      stats::coef(model)[["is_retractionTRUE"]]
    )
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

mixed_binary_result <- function(
    data,
    family,
    outcome,
    analysis_set) {
  model_data <- data[!is.na(data[[outcome]]), , drop = FALSE]
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
    fit <- fit_summary(
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
  effect <- cbind(
    data.frame(
      model_type = "primary_mixed",
      analysis_set = analysis_set,
      analysis_family = family,
      outcome = outcome,
      effect_scale = "odds_ratio",
      stringsAsFactors = FALSE
    ),
    paper_extract_coefficient(
      summary(captured$model)$coefficients,
      "is_retractionTRUE"
    )
  )
  fit <- fit_summary(
    "primary_mixed",
    analysis_set,
    family,
    outcome,
    model_data,
    captured$model,
    captured$warnings,
    "ok",
    random_effect_sd = sqrt(as.numeric(
      lme4::VarCorr(captured$model)$match_group[1, 1]
    ))
  )
  list(effect = effect, fit = fit)
}

conditional_binary_result <- function(
    data,
    family,
    outcome,
    analysis_set) {
  model_data <- data[!is.na(data[[outcome]]), , drop = FALSE]
  model_data$model_outcome <- as.integer(model_data[[outcome]])
  captured <- capture_model(
    survival::clogit(
      model_outcome ~ is_retraction + team_size_bin +
        strata(match_group),
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
    fit <- fit_summary(
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
  effect <- cbind(
    data.frame(
      model_type = "matched_conditional",
      analysis_set = analysis_set,
      analysis_family = family,
      outcome = outcome,
      effect_scale = "odds_ratio",
      stringsAsFactors = FALSE
    ),
    paper_extract_coefficient(
      summary(captured$model)$coefficients,
      "is_retractionTRUE"
    )
  )
  fit <- fit_summary(
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

team_size_result <- function(
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
    fit <- fit_summary(
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
  effect <- cbind(
    data.frame(
      model_type = "cluster_robust_negative_binomial",
      analysis_set = analysis_set,
      analysis_family = family,
      outcome = "team_size",
      effect_scale = "incidence_rate_ratio",
      stringsAsFactors = FALSE
    ),
    paper_cluster_robust_effect(
      captured$model,
      cluster = model_data$match_group,
      term = "is_retractionTRUE"
    )
  )
  fit <- fit_summary(
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

add_bh_fdr <- function(effects) {
  effects$bh_fdr <- NA_real_
  if (nrow(effects) == 0L) {
    return(effects)
  }
  group_columns <- c(
    "analysis_set",
    "model_type",
    "outcome"
  )
  if ("team_size_bin" %in% names(effects)) {
    group_columns <- c(group_columns, "team_size_bin")
  }
  group_values <- lapply(group_columns, function(column) {
    values <- as.character(effects[[column]])
    values[is.na(values)] <- "unknown"
    values
  })
  grouping <- do.call(paste, c(group_values, sep = "|"))
  for (group_indices in split(seq_len(nrow(effects)), grouping)) {
    valid <- group_indices[is.finite(effects$p_value[group_indices])]
    if (length(valid) > 0L) {
      effects$bh_fdr[valid] <- stats::p.adjust(
        effects$p_value[valid],
        method = "BH"
      )
    }
  }
  effects
}

retraction_author_ids <- unique(authorships$author_id[
  !is.na(authorships$author_id) & authorships$author_id != ""
])
control_author_overlap <- unique(control_authors$control_work_id[
  control_authors$author_id %in% retraction_author_ids
])
panel$control_shares_retraction_author <-
  !panel$is_retraction &
  panel$openalex_work_id %in% control_author_overlap

affected_groups_before <- unique(panel$match_group[
  panel$control_shares_retraction_author
])
kept_groups_author <- unique(panel$match_group[
  !panel$is_retraction & !panel$control_shares_retraction_author
])
author_filtered_panel <- panel[
  panel$match_group %in% kept_groups_author &
    (
      panel$is_retraction |
        !panel$control_shares_retraction_author
    ),
  ,
  drop = FALSE
]

event_batches <- event_batches[
  order(
    -event_batches$notification_records,
    -event_batches$papers,
    event_batches$retraction_date,
    event_batches$publisher
  ),
  ,
  drop = FALSE
]
top_five_batches <- head(event_batches, 5L)
top_five_batch_keys <- paste(
  top_five_batches$retraction_date,
  top_five_batches$publisher,
  sep = "|"
)
case_batch_key <- paste(
  as.character(case_audit$retraction_first_date),
  case_audit$publisher,
  sep = "|"
)
batch_by_group <- tapply(
  case_batch_key,
  case_audit$paper_key,
  function(values) values[[1]]
)
panel$case_batch_key <- unname(
  batch_by_group[as.character(panel$match_group)]
)
top_five_groups <- unique(panel$match_group[
  panel$case_batch_key %in% top_five_batch_keys
])
top_five_panel <- panel[
  !panel$match_group %in% top_five_groups,
  ,
  drop = FALSE
]

institution_columns <- c(
  "institution_id",
  "institution_name",
  "country_code",
  "effective_country_code",
  "region",
  "region_code",
  "province_name_zh",
  "region_type",
  "city",
  "latitude",
  "longitude",
  "is_mainland_institution",
  "is_hmt_institution",
  "is_foreign_institution",
  "tier_985",
  "tier_211",
  "tier_double_first_class_2017",
  "tier_double_first_class_2022"
)

case_author_dt <- data.table::as.data.table(authorships)
case_author_dt[, authorships_row_id := seq_len(.N)]
case_first_institutions <- case_author_dt[
  ,
  .(
    institution_id = {
      ids <- institution_ids[[1]]
      if (length(ids) == 0L) NA_character_ else ids[[1]]
    }
  ),
  by = .(authorships_row_id, paper_key, author_id)
]
case_first_institutions <- case_first_institutions[
  !is.na(institution_id) & institution_id != "",
  ,
  drop = FALSE
]
case_first_institutions <- merge(
  case_first_institutions,
  institutions[, institution_columns, drop = FALSE],
  by = "institution_id",
  all.x = TRUE,
  sort = FALSE
)
case_year_lookup <- unique(panel[
  panel$is_retraction,
  c("case_paper_key", "publication_year"),
  drop = FALSE
])
case_first_institutions$publication_year <-
  case_year_lookup$publication_year[
    match(
      case_first_institutions$paper_key,
      case_year_lookup$case_paper_key
    )
  ]
case_first_institutions <- institution_add_year_tier(
  case_first_institutions,
  "publication_year"
)
case_primary_structure <- summarize_institution_structure(
  case_first_institutions,
  "paper_key"
)

control_author_dt <- data.table::as.data.table(control_authors)
control_author_dt <- control_author_dt[
  control_work_id %in% unique(control_links$openalex_work_id),
  ,
  drop = FALSE
]
control_author_dt[, control_authorship_id := seq_len(.N)]
control_first_institutions <- control_author_dt[
  ,
  .(
    institution_id = {
      ids <- institution_ids[[1]]
      if (length(ids) == 0L) NA_character_ else ids[[1]]
    }
  ),
  by = .(control_authorship_id, control_work_id, case_paper_key, author_id)
]
control_first_institutions <- control_first_institutions[
  !is.na(institution_id) & institution_id != "",
  ,
  drop = FALSE
]
control_first_institutions <- merge(
  control_first_institutions,
  institutions[, institution_columns, drop = FALSE],
  by = "institution_id",
  all.x = TRUE,
  sort = FALSE
)
control_work_year <- unique(control_works[
  control_works$openalex_work_id %in% unique(control_links$openalex_work_id),
  c("openalex_work_id", "publication_year"),
  drop = FALSE
])
control_first_institutions$publication_year <-
  control_work_year$publication_year[
    match(
      control_first_institutions$control_work_id,
      control_work_year$openalex_work_id
    )
  ]
control_first_institutions <- institution_add_year_tier(
  control_first_institutions,
  "publication_year"
)
control_primary_structure <- summarize_institution_structure(
  control_first_institutions,
  "control_work_id"
)

case_complete_lookup <- setNames(
  case_audit$case_institution_complete,
  case_audit$paper_key
)
case_primary_observed <- panel$is_retraction &
  case_complete_lookup[panel$case_paper_key] %in% TRUE &
  panel$case_paper_key %in% case_primary_structure$paper_key
control_first_valid <- vapply(
  control_author_dt$institution_ids,
  function(ids) {
    length(ids) > 0L &&
      !is.na(ids[[1]]) &&
      ids[[1]] %in% institutions$institution_id
  },
  logical(1)
)
control_first_counts <- data.table::data.table(
  openalex_work_id = control_author_dt$control_work_id,
  first_valid = control_first_valid
)[
  ,
  .(authors = .N, valid_first_institutions = sum(first_valid)),
  by = openalex_work_id
]
control_work_complete <- unique(control_works[, c(
  "openalex_work_id",
  "all_authors_have_institution"
), drop = FALSE])
control_primary_flags <- merge(
  control_work_complete,
  as.data.frame(control_first_counts),
  by = "openalex_work_id",
  all.x = TRUE,
  sort = FALSE
)
control_primary_flags$primary_observed <-
  control_primary_flags$all_authors_have_institution %in% TRUE &
  control_primary_flags$authors ==
    control_primary_flags$valid_first_institutions &
  control_primary_flags$openalex_work_id %in%
    control_primary_structure$control_work_id

panel$primary_case_observed <- case_primary_observed
panel$primary_control_observed <- FALSE
control_match <- match(
  panel$openalex_work_id[!panel$is_retraction],
  control_primary_flags$openalex_work_id
)
panel$primary_control_observed[!panel$is_retraction] <-
  control_primary_flags$primary_observed[control_match] %in% TRUE

group_case_complete <- tapply(
  panel$primary_case_observed[panel$is_retraction],
  panel$match_group[panel$is_retraction],
  all
)
group_control_complete <- tapply(
  panel$primary_control_observed[!panel$is_retraction],
  panel$match_group[!panel$is_retraction],
  all
)
primary_complete_group <- names(group_case_complete)[
  group_case_complete &
    group_control_complete[names(group_case_complete)]
]
primary_complete_group <- primary_complete_group[
  !is.na(primary_complete_group)
]

metric_columns <- c(
  "n_institution_links",
  "n_unique_institutions",
  "n_mainland_institutions",
  "n_hmt_institutions",
  "n_foreign_institutions",
  "national_key_institution_count",
  "non_national_mainland_institution_count",
  "national_key_present",
  "non_national_mainland_present",
  "cross_tier",
  "legacy_985_211_cross_tier",
  "institution_hmt_present",
  "institution_foreign_present",
  "geo_level",
  "main_city_count",
  "main_region_count",
  "tier_rule",
  "median_domestic_geo_distance_km",
  "max_domestic_geo_distance_km",
  "median_all_geo_distance_km",
  "max_all_geo_distance_km"
)
primary_panel <- panel
for (column in metric_columns) {
  primary_panel[[column]] <- NA
}
case_structure_index <- match(
  primary_panel$case_paper_key[primary_panel$is_retraction],
  case_primary_structure$paper_key
)
control_structure_index <- match(
  primary_panel$openalex_work_id[!primary_panel$is_retraction],
  control_primary_structure$control_work_id
)
for (column in metric_columns) {
  primary_panel[[column]][primary_panel$is_retraction] <-
    case_primary_structure[[column]][case_structure_index]
  primary_panel[[column]][!primary_panel$is_retraction] <-
    control_primary_structure[[column]][control_structure_index]
}
primary_panel$domestic_cross_province <-
  primary_panel$geo_level == "domestic_cross_province"
primary_panel$international <- primary_panel$geo_level == "international"
primary_panel$positive_distance <-
  is.finite(primary_panel$median_domestic_geo_distance_km) &
  primary_panel$median_domestic_geo_distance_km > 0
primary_panel$institution_observed <- !is.na(primary_panel$cross_tier)
primary_panel$analysis_institution_eligible <-
  primary_panel$match_group %in% primary_complete_group
primary_panel <- primary_panel[
  primary_panel$analysis_institution_eligible &
    primary_panel$institution_observed,
  ,
  drop = FALSE
]

variant_panels <- list(
  author_overlap_excluded = author_filtered_panel,
  primary_institution = primary_panel,
  top5_batch_excluded = top_five_panel
)

variants <- names(variant_panels)
effect_rows <- list()
fit_rows <- list()
store_result <- function(result) {
  effect_rows[[length(effect_rows) + 1L]] <<- result$effect
  fit_rows[[length(fit_rows) + 1L]] <<- result$fit
}

for (variant in variants) {
  variant_panel <- variant_panels[[variant]]
  for (family in family_columns) {
    binary_data <- prepare_family_data(
      variant_panel,
      family,
      require_institution = TRUE
    )
    if (nrow(binary_data) > 0L) {
      for (outcome in main_outcomes) {
        store_result(mixed_binary_result(
          binary_data,
          family,
          outcome,
          variant
        ))
        store_result(conditional_binary_result(
          binary_data,
          family,
          outcome,
          variant
        ))
      }
    }
    team_data <- prepare_family_data(
      variant_panel,
      family,
      require_institution = FALSE
    )
    if (nrow(team_data) > 0L) {
      store_result(team_size_result(
        team_data,
        family,
        variant
      ))
    }
  }
}

fixed_tier_rows <- list()
for (family in family_columns) {
  fixed_data <- prepare_family_data(
    panel,
    family,
    require_institution = TRUE
  )
  fixed_tier_rows[[length(fixed_tier_rows) + 1L]] <-
    mixed_binary_result(
      fixed_data,
      family,
      "legacy_985_211_cross_tier",
      "fixed_985_211_tier"
    )
  fixed_tier_rows[[length(fixed_tier_rows) + 1L]] <-
    conditional_binary_result(
      fixed_data,
      family,
      "legacy_985_211_cross_tier",
      "fixed_985_211_tier"
    )
}

sensitivity_effects <- data.table::rbindlist(
  effect_rows,
  fill = TRUE
)
sensitivity_fits <- data.table::rbindlist(fit_rows, fill = TRUE)
fixed_tier_results <- lapply(fixed_tier_rows, function(result) {
  result
})
fixed_tier_effects <- data.table::rbindlist(
  lapply(fixed_tier_results, function(result) result$effect),
  fill = TRUE
)
fixed_tier_fits <- data.table::rbindlist(
  lapply(fixed_tier_results, function(result) result$fit),
  fill = TRUE
)

sensitivity_effects <- add_bh_fdr(sensitivity_effects)
fixed_tier_effects <- add_bh_fdr(fixed_tier_effects)

extract_bin_contrasts <- function(
    model,
    model_type,
    family,
    outcome,
    bin_levels,
    analysis_data) {
  coefficients <- if (inherits(model, "merMod")) {
    lme4::fixef(model)
  } else {
    stats::coef(model)
  }
  covariance <- stats::vcov(model)
  rows <- lapply(seq_along(bin_levels), function(index) {
    level <- bin_levels[[index]]
    level_rows <- analysis_data[
      analysis_data$team_size_bin == level &
        !is.na(analysis_data[[outcome]]),
      ,
      drop = FALSE
    ]
    terms <- "is_retractionTRUE"
    if (index > 1L) {
      terms <- c(
        terms,
        paste0("is_retractionTRUE:team_size_bin", level)
      )
    }
    if (!all(terms %in% names(coefficients))) {
      return(data.frame(
        model_type = model_type,
        analysis_family = family,
        outcome = outcome,
        team_size_bin = level,
        cases = sum(level_rows$is_retraction %in% TRUE),
        controls = sum(!level_rows$is_retraction %in% TRUE),
        estimate = NA_real_,
        std_error = NA_real_,
        effect_ratio = NA_real_,
        ci_low = NA_real_,
        ci_high = NA_real_,
        p_value = NA_real_,
        stringsAsFactors = FALSE
      ))
    }
    contrast <- setNames(rep(0, length(coefficients)), names(coefficients))
    contrast[terms] <- 1
    estimate <- sum(contrast * coefficients)
    std_error <- sqrt(as.numeric(
      t(contrast) %*% covariance %*% contrast
    ))
    z_value <- stats::qnorm(0.975)
    data.frame(
      model_type = model_type,
      analysis_family = family,
      outcome = outcome,
      team_size_bin = level,
      cases = sum(level_rows$is_retraction %in% TRUE),
      controls = sum(!level_rows$is_retraction %in% TRUE),
      estimate = estimate,
      std_error = std_error,
      effect_ratio = exp(estimate),
      ci_low = exp(estimate - z_value * std_error),
      ci_high = exp(estimate + z_value * std_error),
      p_value = 2 * stats::pnorm(
        abs(estimate / std_error),
        lower.tail = FALSE
      ),
      stringsAsFactors = FALSE
    )
  })
  data.table::rbindlist(rows, fill = TRUE)
}

strata_effects <- list()
strata_fits <- list()
for (family in family_columns) {
  structural_data <- prepare_family_data(
    panel,
    family,
    require_institution = TRUE
  )
  for (outcome in c(
    "cross_tier",
    "domestic_cross_province",
    "international"
  )) {
    model_data <- structural_data[
      !is.na(structural_data[[outcome]]),
      ,
      drop = FALSE
    ]
    model_data$model_outcome <- as.integer(model_data[[outcome]])
    model_data$team_size_bin <- relevel(
      model_data$team_size_bin,
      ref = "1"
    )
    captured_mixed <- capture_model(
      lme4::glmer(
        model_outcome ~ is_retraction * team_size_bin +
          publication_year_c + publication_year_c2 + match_layer +
          field_group + openalex_type + publisher_group +
          (1 | match_group),
        data = model_data,
        family = stats::binomial(),
        nAGQ = 0,
        control = lme4::glmerControl(
          optimizer = "bobyqa",
          optCtrl = list(maxfun = 30000)
        )
      )
    )
    if (!inherits(captured_mixed$model, "error")) {
      strata_effects[[length(strata_effects) + 1L]] <-
        extract_bin_contrasts(
          captured_mixed$model,
          "mixed_interaction",
          family,
          outcome,
          levels(model_data$team_size_bin),
          model_data
        )
      strata_fits[[length(strata_fits) + 1L]] <- fit_summary(
        "mixed_interaction",
        "team_size_strata",
        family,
        outcome,
        model_data,
        captured_mixed$model,
        captured_mixed$warnings,
        "ok",
        random_effect_sd = sqrt(as.numeric(
          lme4::VarCorr(captured_mixed$model)$match_group[1, 1]
        ))
      )
    }
    captured_conditional <- capture_model(
      survival::clogit(
        model_outcome ~ is_retraction * team_size_bin +
          strata(match_group),
        data = model_data
      )
    )
    if (!inherits(captured_conditional$model, "error")) {
      strata_effects[[length(strata_effects) + 1L]] <-
        extract_bin_contrasts(
          captured_conditional$model,
          "conditional_interaction",
          family,
          outcome,
          levels(model_data$team_size_bin),
          model_data
        )
      strata_fits[[length(strata_fits) + 1L]] <- fit_summary(
        "conditional_interaction",
        "team_size_strata",
        family,
        outcome,
        model_data,
        captured_conditional$model,
        captured_conditional$warnings,
        "ok"
      )
    }
  }
}

strata_effects <- data.table::rbindlist(strata_effects, fill = TRUE)
strata_effects$effect_stability <- ifelse(
  is.finite(strata_effects$effect_ratio) &
    is.finite(strata_effects$ci_low) &
    is.finite(strata_effects$ci_high) &
    strata_effects$std_error < 1 &
    abs(strata_effects$estimate) < 5,
  "stable",
  "unstable_or_separation"
)
strata_effects <- add_bh_fdr(strata_effects)
strata_fits <- data.table::rbindlist(strata_fits, fill = TRUE)

flow <- data.frame(
  metric = c(
    "base_panel_rows",
    "retraction_author_ids",
    "shared_author_controls",
    "groups_affected_by_shared_author",
    "groups_remaining_author_filtered",
    "author_filtered_panel_rows",
    "primary_institution_groups",
    "primary_institution_panel_rows",
    "top5_batch_groups_excluded",
    "top5_batch_panel_rows"
  ),
  value = c(
    nrow(panel),
    length(retraction_author_ids),
    length(control_author_overlap),
    length(affected_groups_before),
    length(kept_groups_author),
    nrow(author_filtered_panel),
    length(primary_complete_group),
    nrow(primary_panel),
    length(top_five_groups),
    nrow(top_five_panel)
  ),
  stringsAsFactors = FALSE
)

write_csv_utf8(
  flow,
  file.path(audit_table_dir, "p1c_robustness_flow.csv")
)
write_csv_utf8(
  as.data.frame(sensitivity_effects),
  file.path(audit_table_dir, "p1c_sensitivity_effects.csv")
)
write_csv_utf8(
  as.data.frame(sensitivity_fits),
  file.path(audit_table_dir, "p1c_sensitivity_model_fit.csv")
)
write_csv_utf8(
  as.data.frame(fixed_tier_effects),
  file.path(audit_table_dir, "p1c_fixed_tier_effects.csv")
)
write_csv_utf8(
  as.data.frame(fixed_tier_fits),
  file.path(audit_table_dir, "p1c_fixed_tier_model_fit.csv")
)
write_csv_utf8(
  as.data.frame(strata_effects),
  file.path(audit_table_dir, "p1c_team_size_strata_effects.csv")
)
write_csv_utf8(
  as.data.frame(strata_fits),
  file.path(audit_table_dir, "p1c_team_size_strata_model_fit.csv")
)
write_csv_utf8(
  top_five_batches,
  file.path(audit_table_dir, "p1c_top5_batches.csv")
)

write_audit_manifest()
message("P1C robustness models completed.")
