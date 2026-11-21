#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/visualization.R", encoding = "UTF-8")

suppressPackageStartupMessages({
  library(ggplot2)
  library(scales)
})

funding_labels <- visualization_config$labels$funding
font_family <- audit_font_family()
palette_b <- audit_palettes$B
palette_c <- audit_palettes$C

coverage <- utils::read.csv(
  file.path(
    audit_table_dir,
    "funding_source_symmetric_group_coverage.csv"
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
agreement <- utils::read.csv(
  file.path(
    audit_table_dir,
    "funding_source_symmetric_agreement.csv"
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
verification <- data.table::fread(
  file.path(
    audit_table_dir,
    "funding_official_project_verification.csv"
  ),
  encoding = "UTF-8",
  data.table = FALSE
)

group_map <- c(
  selected_cluster_sample = funding_labels$group_selected,
  matched_controls = funding_labels$group_controls,
  unselected_candidate_clusters = funding_labels$group_unselected
)
coverage$group_label <- unname(group_map[coverage$analysis_group])
coverage$group_label <- factor(
  coverage$group_label,
  levels = unname(group_map)
)
coverage$group_n <- sprintf(
  "%s (n=%d)",
  coverage$group_label,
  coverage$papers
)
coverage$group_n <- factor(
  coverage$group_n,
  levels = coverage$group_n
)

coverage_long <- data.frame(
  analysis_group = rep(coverage$analysis_group, times = 3L),
  group_n = rep(coverage$group_n, times = 3L),
  source = rep(
    c("oa", "crossref", "union"),
    each = nrow(coverage)
  ),
  coverage = c(
    coverage$oa_any_coverage,
    coverage$crossref_any_coverage,
    coverage$union_any_coverage
  ),
  ci_low = c(
    rep(NA_real_, nrow(coverage)),
    rep(NA_real_, nrow(coverage)),
    coverage$union_any_ci_low
  ),
  ci_high = c(
    rep(NA_real_, nrow(coverage)),
    rep(NA_real_, nrow(coverage)),
    coverage$union_any_ci_high
  ),
  papers = rep(coverage$papers, times = 3L),
  stringsAsFactors = FALSE
)
coverage_long$source_label <- factor(
  unname(c(
    oa = funding_labels$source_oa,
    crossref = funding_labels$source_crossref,
    union = funding_labels$source_union
  )[coverage_long$source]),
  levels = unname(c(
    oa = funding_labels$source_oa,
    crossref = funding_labels$source_crossref,
    union = funding_labels$source_union
  ))
)

coverage_data_path <- file.path(
  audit_table_dir,
  "p4_funding_coverage_source_symmetric_data.csv"
)
write_csv_utf8(coverage_long, coverage_data_path)

coverage_plot <- ggplot(
  coverage_long,
  aes(
    x = coverage,
    y = group_n,
    color = source_label,
    shape = source_label
  )
) +
  geom_errorbar(
    aes(xmin = ci_low, xmax = ci_high),
    width = 0.14,
    orientation = "y",
    linewidth = 0.8,
    na.rm = TRUE,
    position = position_dodge(width = 0.55)
  ) +
  geom_point(
    size = 3.8,
    stroke = 1,
    position = position_dodge(width = 0.55)
  ) +
  scale_color_manual(
    values = setNames(
      unname(palette_b[c("primary", "secondary", "ink")]),
      unname(c(
        funding_labels$source_oa,
        funding_labels$source_crossref,
        funding_labels$source_union
      ))
    )
  ) +
  scale_shape_manual(values = c(16, 17, 15)) +
  scale_x_continuous(
    labels = percent_format(accuracy = 1),
    limits = c(0, 1),
    breaks = seq(0, 1, by = 0.2),
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  labs(
    title = funding_labels$coverage_title,
    subtitle = funding_labels$coverage_subtitle,
    x = funding_labels$coverage_axis,
    y = NULL,
    color = NULL,
    shape = NULL,
    caption = funding_labels$coverage_caption
  ) +
  audit_theme("B") +
  theme(
    legend.position = "top",
    legend.justification = "center",
    panel.grid.major.x = element_line(
      color = "#E7E3DB",
      linewidth = 0.3
    )
  )

coverage_paths <- save_audit_figure(
  coverage_plot,
  audit_figure_dir,
  "p4_funding_coverage_source_symmetric",
  palette_name = "B",
  report_height_mm = 95,
  desktop_height_px = 1000L,
  mobile_height_px = 1200L
)

agreement$group_label <- unname(group_map[agreement$analysis_group])
agreement$group_label <- factor(
  agreement$group_label,
  levels = rev(unname(group_map))
)
agreement_long <- data.frame(
  analysis_group = rep(agreement$analysis_group, times = 4L),
  group_label = rep(agreement$group_label, times = 4L),
  category = rep(
    c("both", "oa_only", "crossref_only", "neither"),
    each = nrow(agreement)
  ),
  papers = c(
    agreement$both_sources,
    agreement$openalex_only,
    agreement$crossref_only,
    agreement$neither_source
  ),
  group_papers = rep(agreement$papers, times = 4L),
  stringsAsFactors = FALSE
)
agreement_long$share <-
  agreement_long$papers / agreement_long$group_papers
agreement_label_map <- c(
  both = funding_labels$agreement_both,
  oa_only = funding_labels$agreement_oa_only,
  crossref_only = funding_labels$agreement_crossref_only,
  neither = funding_labels$agreement_neither
)
agreement_long$category_label <- factor(
  unname(agreement_label_map[agreement_long$category]),
  levels = unname(agreement_label_map)
)
agreement_long$text_color <- ifelse(
  agreement_long$category %in% c("both", "crossref_only"),
  "#FFFFFF",
  palette_b[["ink"]]
)

agreement_data_path <- file.path(
  audit_table_dir,
  "p4_funding_source_agreement_data.csv"
)
write_csv_utf8(agreement_long, agreement_data_path)

agreement_plot <- ggplot(
  agreement_long,
  aes(
    x = share,
    y = group_label,
    fill = category_label
  )
) +
  geom_col(width = 0.64, position = position_stack(reverse = TRUE)) +
  geom_text(
    aes(
      label = ifelse(share >= 0.08, percent(share, accuracy = 1), ""),
      color = text_color
    ),
    family = font_family,
    position = position_stack(vjust = 0.5, reverse = TRUE),
    size = 2.8
  ) +
  scale_fill_manual(
    values = setNames(
      unname(palette_b[c(
        "primary",
        "tertiary",
        "secondary",
        "missing"
      )]),
      unname(c(
        funding_labels$agreement_both,
        funding_labels$agreement_oa_only,
        funding_labels$agreement_crossref_only,
        funding_labels$agreement_neither
      ))
    )
  ) +
  scale_color_identity() +
  scale_x_continuous(
    labels = percent_format(accuracy = 1),
    limits = c(0, 1),
    breaks = seq(0, 1, by = 0.2),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    title = funding_labels$agreement_title,
    subtitle = funding_labels$agreement_subtitle,
    x = funding_labels$agreement_axis,
    y = NULL,
    fill = NULL,
    caption = funding_labels$agreement_caption
  ) +
  audit_theme("B") +
  theme(
    legend.position = "top",
    legend.justification = "center",
    panel.grid.major.y = element_blank()
  )

agreement_paths <- save_audit_figure(
  agreement_plot,
  audit_figure_dir,
  "p4_funding_source_agreement",
  palette_name = "B",
  report_height_mm = 85,
  desktop_height_px = 900L,
  mobile_height_px = 1100L
)

status_map <- c(
  officially_verified_completion_record = funding_labels$status_verified,
  not_found_in_nsfc_completion_database =
    funding_labels$status_nsfc_not_found,
  not_found_in_public_official_project_search =
    funding_labels$status_external_not_found
)
status_summary <- as.data.frame(table(
  verification$official_verification_status
))
names(status_summary) <- c("status", "awards")
status_summary$status_label <- factor(
  unname(status_map[
    match(status_summary$status, names(status_map))
  ]),
  levels = unname(status_map)
)
status_data_path <- file.path(
  audit_table_dir,
  "p4_funding_official_verification_status_data.csv"
)
write_csv_utf8(status_summary, status_data_path)

status_plot <- ggplot(
  status_summary,
  aes(x = status_label, y = awards, fill = status_label)
) +
  geom_col(width = 0.62) +
  geom_text(
    aes(label = awards),
    family = font_family,
    vjust = -0.35,
    size = 3.2,
    color = palette_c[["ink"]]
  ) +
  scale_fill_manual(
    values = setNames(
      unname(palette_c[c("primary", "secondary", "uncertain")]),
      unname(c(
        funding_labels$status_verified,
        funding_labels$status_nsfc_not_found,
        funding_labels$status_external_not_found
      ))
    )
  ) +
  scale_y_continuous(
    breaks = pretty_breaks(),
    limits = c(0, max(status_summary$awards) * 1.18),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    title = funding_labels$status_title,
    subtitle = funding_labels$status_subtitle,
    x = NULL,
    y = funding_labels$status_axis,
    caption = funding_labels$status_caption
  ) +
  audit_theme("C") +
  theme(
    legend.position = "none",
    panel.grid.major.y = element_line(
      color = "#E7E3DB",
      linewidth = 0.3
    )
  )

status_paths <- save_audit_figure(
  status_plot,
  audit_figure_dir,
  "p4_funding_official_verification_status",
  palette_name = "C",
  report_height_mm = 85,
  desktop_height_px = 900L,
  mobile_height_px = 1100L
)

figure_records <- list(
  list(
    figure_id = "p4_funding_coverage_source_symmetric",
    palette = "B",
    question = funding_labels$coverage_title,
    denominator = funding_labels$coverage_denominator,
    source_tables = c(
      "data/outputs/audits/tables/funding_source_symmetric_group_coverage.csv"
    ),
    missing_rule = funding_labels$coverage_missing_rule,
    script = "R/16f_funding_visualizations.R",
    table_fallback = project_relative_path(coverage_data_path),
    data_sha256 = sha256_canonical_file(coverage_data_path),
    alt_text = funding_labels$coverage_alt_text,
    outputs = lapply(coverage_paths, function(path) {
      list(
        path = project_relative_path(path),
        sha256 = digest::digest(file = path, algo = "sha256")
      )
    })
  ),
  list(
    figure_id = "p4_funding_source_agreement",
    palette = "B",
    question = funding_labels$agreement_title,
    denominator = funding_labels$agreement_denominator,
    source_tables = c(
      "data/outputs/audits/tables/funding_source_symmetric_agreement.csv"
    ),
    missing_rule = funding_labels$agreement_missing_rule,
    script = "R/16f_funding_visualizations.R",
    table_fallback = project_relative_path(agreement_data_path),
    data_sha256 = sha256_canonical_file(agreement_data_path),
    alt_text = funding_labels$agreement_alt_text,
    outputs = lapply(agreement_paths, function(path) {
      list(
        path = project_relative_path(path),
        sha256 = digest::digest(file = path, algo = "sha256")
      )
    })
  ),
  list(
    figure_id = "p4_funding_official_verification_status",
    palette = "C",
    question = funding_labels$status_title,
    denominator = funding_labels$status_denominator,
    source_tables = c(
      "data/outputs/audits/tables/funding_official_project_verification.csv"
    ),
    missing_rule = funding_labels$status_missing_rule,
    script = "R/16f_funding_visualizations.R",
    table_fallback = project_relative_path(status_data_path),
    data_sha256 = sha256_canonical_file(status_data_path),
    alt_text = funding_labels$status_alt_text,
    outputs = lapply(status_paths, function(path) {
      list(
        path = project_relative_path(path),
        sha256 = digest::digest(file = path, algo = "sha256")
      )
    })
  )
)

write_audit_figure_metadata(
  figure_records,
  file.path(audit_figure_dir, "funding_figures_metadata.json")
)
write_audit_manifest()
message("P4 funding figures completed.")

