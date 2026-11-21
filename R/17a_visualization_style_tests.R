#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/visualization.R", encoding = "UTF-8")

suppressPackageStartupMessages({
  library(ggplot2)
  library(scales)
})

palette_b <- audit_palettes$B
palette_c <- audit_palettes$C
font_family <- audit_font_family()
labels <- visualization_config$labels

figure_b_id <- "style_test_b_group_coverage"
coverage <- utils::read.csv(
  file.path(audit_table_dir, "funding_audit_group_coverage.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
assert_columns(
  coverage,
  c(
    "analysis_group",
    "papers",
    "any_funding_papers",
    "any_funding_coverage",
    "coverage_ci_low",
    "coverage_ci_high"
  ),
  "funding group coverage"
)

group_labels <- unlist(labels$groups, use.names = TRUE)
coverage <- coverage[
  coverage$analysis_group %in% names(group_labels),
  ,
  drop = FALSE
]
coverage$group_label <- unname(group_labels[coverage$analysis_group])
coverage$group_label <- factor(
  coverage$group_label,
  levels = unname(group_labels)
)
coverage$group_color <- factor(
  coverage$analysis_group,
  levels = names(group_labels),
  labels = group_labels
)
coverage$group_shape <- coverage$analysis_group
coverage$label <- sprintf(
  "%.1f%%  (%d/%d)",
  100 * coverage$any_funding_coverage,
  coverage$any_funding_papers,
  coverage$papers
)

coverage_data <- coverage[, c(
  "analysis_group",
  "group_label",
  "papers",
  "any_funding_papers",
  "any_funding_coverage",
  "coverage_ci_low",
  "coverage_ci_high"
), drop = FALSE]
coverage_data_path <- file.path(
  audit_table_dir,
  paste0(figure_b_id, "_data.csv")
)
write_csv_utf8(coverage_data, coverage_data_path)

coverage_plot <- ggplot(
  coverage,
  aes(
    x = any_funding_coverage,
    y = group_label,
    color = group_color,
    shape = group_shape
  )
) +
  geom_errorbar(
    aes(xmin = coverage_ci_low, xmax = coverage_ci_high),
    width = 0.16,
    orientation = "y",
    linewidth = 0.9,
    show.legend = FALSE
  ) +
  geom_point(size = 4.2, stroke = 1.1) +
  geom_text(
    aes(x = coverage_ci_high + 0.025, label = label),
    family = font_family,
    size = 3,
    hjust = 0,
    show.legend = FALSE
  ) +
  scale_color_manual(
    values = setNames(
      unname(palette_b[c("primary", "secondary", "tertiary")]),
      unname(group_labels)
    )
  ) +
  scale_shape_manual(
    values = c(
      selected_cluster_sample = 16,
      matched_controls = 17,
      unselected_candidate_clusters = 15
    )
  ) +
  scale_x_continuous(
    labels = percent_format(accuracy = 1),
    breaks = seq(0, 1, by = 0.2),
    limits = c(0, 1),
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  labs(
    title = labels$style_test_b$title,
    subtitle = labels$style_test_b$subtitle,
    x = labels$style_test_b$axis_x,
    y = NULL,
    caption = labels$style_test_b$caption
  ) +
  audit_theme("B") +
  theme(
    legend.position = "none",
    panel.grid.major.x = element_line(
      color = "#DDDAD3",
      linewidth = 0.3
    )
  )

coverage_paths <- save_audit_figure(
  coverage_plot,
  audit_figure_dir,
  figure_b_id,
  palette_name = "B",
  report_height_mm = 85,
  desktop_height_px = 900L,
  mobile_height_px = 1100L
)

figure_c_id <- "style_test_c_event_monthly"
monthly <- utils::read.csv(
  file.path(audit_table_dir, "event_2023_monthly.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
assert_columns(
  monthly,
  c("month", "papers"),
  "2023 monthly event data"
)
monthly$date <- as.Date(paste0(monthly$month, "-01"))
monthly$is_peak <- monthly$papers == max(monthly$papers, na.rm = TRUE)
monthly_data_path <- file.path(
  audit_table_dir,
  paste0(figure_c_id, "_data.csv")
)
write_csv_utf8(monthly, monthly_data_path)

batch_start <- as.Date("2023-06-21")
peak_row <- monthly[monthly$is_peak, , drop = FALSE][1, , drop = FALSE]

monthly_plot <- ggplot(monthly, aes(x = date, y = papers)) +
  geom_vline(
    xintercept = batch_start,
    color = palette_c[["secondary"]],
    linewidth = 0.65,
    linetype = "22"
  ) +
  geom_line(
    color = palette_c[["tertiary"]],
    linewidth = 1.2
  ) +
  geom_point(
    color = palette_c[["primary"]],
    fill = palette_c[["paper"]],
    shape = 21,
    stroke = 1,
    size = 2.8
  ) +
  geom_point(
    data = monthly[monthly$is_peak, , drop = FALSE],
    color = palette_c[["secondary"]],
    fill = palette_c[["secondary"]],
    shape = 21,
    size = 3.6
  ) +
  annotate(
    "text",
    x = batch_start,
    y = max(monthly$papers, na.rm = TRUE) * 0.52,
    label = labels$style_test_c$batch_annotation,
    family = font_family,
    size = 2.8,
    hjust = -0.08,
    color = palette_c[["secondary"]]
  ) +
  annotate(
    "text",
    x = peak_row$date,
    y = peak_row$papers,
    label = sprintf(
      labels$style_test_c$peak_label_format,
      format(peak_row$papers, big.mark = ",")
    ),
    family = font_family,
    size = 2.9,
    vjust = -1.2,
    hjust = 0.92,
    color = palette_c[["ink"]]
  ) +
  scale_x_date(
    date_breaks = "2 months",
    date_labels = labels$style_test_c$month_label_format,
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  scale_y_continuous(
    labels = comma,
    limits = c(0, max(monthly$papers, na.rm = TRUE) * 1.12),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    title = labels$style_test_c$title,
    subtitle = labels$style_test_c$subtitle,
    x = NULL,
    y = labels$style_test_c$axis_y,
    caption = labels$style_test_c$caption
  ) +
  audit_theme("C") +
  theme(
    legend.position = "none",
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(
      color = "#DDDAD3",
      linewidth = 0.3
    )
  )

monthly_paths <- save_audit_figure(
  monthly_plot,
  audit_figure_dir,
  figure_c_id,
  palette_name = "C",
  report_height_mm = 90,
  desktop_height_px = 900L,
  mobile_height_px = 1200L
)

figure_metadata <- list(
  list(
    figure_id = figure_b_id,
    palette = "B",
    question = labels$style_test_b$question,
    denominator = labels$style_test_b$denominator,
    source_tables = c(
      "data/outputs/audits/tables/funding_audit_group_coverage.csv"
    ),
    missing_rule = labels$style_test_b$missing_rule,
    script = "R/17a_visualization_style_tests.R",
    access_date = as.character(Sys.Date()),
    alt_text = labels$style_test_b$alt_text,
    table_fallback = project_relative_path(coverage_data_path),
    data_sha256 = sha256_canonical_file(coverage_data_path),
    outputs = lapply(coverage_paths, function(path) {
      list(
        path = project_relative_path(path),
        sha256 = digest::digest(file = path, algo = "sha256")
      )
    })
  ),
  list(
    figure_id = figure_c_id,
    palette = "C",
    question = labels$style_test_c$question,
    denominator = labels$style_test_c$denominator,
    source_tables = c(
      "data/outputs/audits/tables/event_2023_monthly.csv",
      "data/outputs/audits/tables/event_2023_same_day_batches.csv"
    ),
    missing_rule = labels$style_test_c$missing_rule,
    script = "R/17a_visualization_style_tests.R",
    access_date = as.character(Sys.Date()),
    alt_text = labels$style_test_c$alt_text,
    table_fallback = project_relative_path(monthly_data_path),
    data_sha256 = sha256_canonical_file(monthly_data_path),
    outputs = lapply(monthly_paths, function(path) {
      list(
        path = project_relative_path(path),
        sha256 = digest::digest(file = path, algo = "sha256")
      )
    })
  )
)

write_audit_figure_metadata(
  figure_metadata,
  file.path(audit_figure_dir, "style_test_metadata.json")
)
write_audit_manifest()
message("Visualization style test figures completed.")

