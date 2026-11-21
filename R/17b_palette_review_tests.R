#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/visualization.R", encoding = "UTF-8")

suppressPackageStartupMessages({
  library(colorspace)
  library(farver)
  library(ggplot2)
  library(scales)
})

review_palettes <- visualization_config$review_palettes
review_labels <- visualization_config$labels$palette_review
group_labels <- unlist(
  visualization_config$labels$groups,
  use.names = TRUE
)
palette_b <- audit_palettes$B
font_family <- audit_font_family()
paper <- palette_b[["paper"]]
ink <- palette_b[["ink"]]
grid_color <- "#E7E3DB"

review_theme <- function() {
  audit_theme("B") +
    theme(
      panel.grid.major.x = element_line(
        color = grid_color,
        linewidth = 0.3
      )
    )
}

save_review_figure <- function(
    plot,
    figure_id,
    report_height_mm = 90,
    desktop_height_px = 1000L,
    mobile_height_px = 1200L) {
  save_audit_figure(
    plot,
    audit_figure_dir,
    figure_id,
    palette_name = "B",
    report_height_mm = report_height_mm,
    desktop_height_px = desktop_height_px,
    mobile_height_px = mobile_height_px
  )
}

write_figure_data <- function(data, figure_id) {
  path <- file.path(
    audit_table_dir,
    paste0(figure_id, "_data.csv")
  )
  write_csv_utf8(data, path)
  path
}

figure_records <- list()
record_figure <- function(
    figure_id,
    palette,
    scenario,
    paths,
    data_path,
    alt_text) {
  figure_records[[length(figure_records) + 1L]] <<- list(
    figure_id = figure_id,
    palette = palette,
    scenario = scenario,
    source_tables = c(
      "data/outputs/audits/tables/funding_audit_group_coverage.csv",
      "data/outputs/audits/tables/funding_audit_cluster_coverage.csv",
      "data/outputs/audits/tables/funding_crossref_paper_metadata.csv",
      "data/outputs/audits/tables/event_2023_monthly.csv",
      "data/outputs/audits/tables/event_2023_same_day_batches.csv",
      "data/outputs/audits/tables/p2_audit_cluster_profiles.csv",
      "data/outputs/audits/tables/p2_audit_cluster_family_counts.csv"
    ),
    script = "R/17b_palette_review_tests.R",
    access_date = as.character(Sys.Date()),
    alt_text = alt_text,
    table_fallback = project_relative_path(data_path),
    data_sha256 = sha256_canonical_file(data_path),
    outputs = lapply(paths, function(path) {
      list(
        path = project_relative_path(path),
        sha256 = digest::digest(file = path, algo = "sha256")
      )
    })
  )
}

coverage <- utils::read.csv(
  file.path(audit_table_dir, "funding_audit_group_coverage.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
coverage$group_label <- unname(group_labels[coverage$analysis_group])
coverage$group_label <- factor(
  coverage$group_label,
  levels = unname(group_labels)
)
coverage$label <- sprintf(
  "%.1f%%",
  100 * coverage$any_funding_coverage
)

make_group_bar <- function(colors, title, subtitle) {
  ggplot(
    coverage,
    aes(x = any_funding_coverage, y = group_label, fill = group_label)
  ) +
    geom_col(width = 0.62) +
    geom_text(
      aes(label = label),
      family = font_family,
      size = 3.2,
      hjust = -0.12,
      color = ink
    ) +
    scale_fill_manual(values = setNames(colors, unname(group_labels))) +
    scale_x_continuous(
      labels = percent_format(accuracy = 1),
      limits = c(0, 1),
      breaks = seq(0, 1, by = 0.2),
      expand = expansion(mult = c(0.01, 0.04))
    ) +
    labs(
      title = title,
      subtitle = subtitle,
      x = review_labels$x_coverage,
      y = NULL,
      caption = review_labels$caption
    ) +
    review_theme() +
    theme(legend.position = "none")
}

fig_01 <- "review_01_tableau10_group_coverage"
plot_01 <- make_group_bar(
  review_palettes$tableau10[1:3],
  review_labels$tableau10_title,
  review_labels$tableau10_subtitle
)
paths_01 <- save_review_figure(
  plot_01,
  fig_01,
  report_height_mm = 85,
  desktop_height_px = 900L
)
data_01 <- write_figure_data(coverage, fig_01)
record_figure(
  fig_01,
  "Tableau 10",
  "categorical_group_comparison",
  paths_01,
  data_01,
  review_labels$alt_texts[[fig_01]]
)

oa_cluster <- utils::read.csv(
  file.path(audit_table_dir, "funding_audit_cluster_coverage.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
heat_data <- oa_cluster[, c(
  "audit_cluster_id",
  "funder_coverage",
  "award_coverage",
  "any_funding_coverage"
), drop = FALSE]
heat_long <- data.frame(
  audit_cluster_id = rep(heat_data$audit_cluster_id, times = 3L),
  metric = rep(
    c("Funders", "Awards", "Any funding"),
    each = nrow(heat_data)
  ),
  coverage = c(
    heat_data$funder_coverage,
    heat_data$award_coverage,
    heat_data$any_funding_coverage
  ),
  stringsAsFactors = FALSE
)
heat_long$cluster_label <- sub(
  "^audit_cluster_",
  "C",
  heat_long$audit_cluster_id
)
heat_long$cluster_label <- factor(
  heat_long$cluster_label,
  levels = rev(unique(heat_long$cluster_label))
)
heat_long$metric <- factor(
  heat_long$metric,
  levels = c("Funders", "Awards", "Any funding")
)
heat_data_path <- file.path(
  audit_table_dir,
  "review_02_viridis_funding_heatmap_data.csv"
)
write_csv_utf8(heat_long, heat_data_path)
fig_02 <- "review_02_viridis_funding_heatmap"
plot_02 <- ggplot(
  heat_long,
  aes(x = metric, y = cluster_label, fill = coverage)
) +
  geom_tile(color = paper, linewidth = 0.6) +
  scale_fill_gradientn(
    colors = unlist(review_palettes$viridis),
    limits = c(0, 1),
    breaks = seq(0, 1, by = 0.2),
    labels = percent_format(accuracy = 1)
  ) +
  labs(
    title = review_labels$viridis_title,
    subtitle = review_labels$viridis_subtitle,
    x = NULL,
    y = review_labels$y_cluster,
    fill = review_labels$x_coverage,
    caption = review_labels$caption
  ) +
  review_theme() +
  theme(
    panel.grid = element_blank(),
    axis.text.x = element_text(angle = 0, hjust = 0.5),
    legend.position = "bottom",
    legend.justification = "center"
  )
paths_02 <- save_review_figure(
  plot_02,
  fig_02,
  report_height_mm = 135,
  desktop_height_px = 1400L,
  mobile_height_px = 1700L
)
record_figure(
  fig_02,
  "Viridis",
  "continuous_heatmap",
  paths_02,
  heat_data_path,
  review_labels$alt_texts[[fig_02]]
)

crossref <- utils::read.csv(
  file.path(audit_table_dir, "funding_crossref_paper_metadata.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
for (column in c(
  "crossref_funders_present",
  "crossref_awards_present"
)) {
  crossref[[column]] <- as.logical(crossref[[column]])
}
crossref$crossref_any_funding <-
  crossref$crossref_funders_present |
  crossref$crossref_awards_present
crossref_cluster <- aggregate(
  cbind(
    crossref_funder_coverage = crossref$crossref_funders_present,
    crossref_award_coverage = crossref$crossref_awards_present,
    crossref_any_coverage = crossref$crossref_any_funding
  ) ~ audit_cluster_id,
  data = crossref,
  FUN = mean
)
oa_match <- oa_cluster[
  match(crossref_cluster$audit_cluster_id, oa_cluster$audit_cluster_id),
  ,
  drop = FALSE
]
cluster_difference <- data.frame(
  audit_cluster_id = crossref_cluster$audit_cluster_id,
  funder_difference =
    crossref_cluster$crossref_funder_coverage -
    oa_match$funder_coverage,
  award_difference =
    crossref_cluster$crossref_award_coverage -
    oa_match$award_coverage,
  any_difference =
    crossref_cluster$crossref_any_coverage -
    oa_match$any_funding_coverage,
  stringsAsFactors = FALSE
)
difference_long <- data.frame(
  audit_cluster_id = rep(
    cluster_difference$audit_cluster_id,
    times = 3L
  ),
  metric = rep(
    c("Funders", "Awards", "Any funding"),
    each = nrow(cluster_difference)
  ),
  difference = c(
    cluster_difference$funder_difference,
    cluster_difference$award_difference,
    cluster_difference$any_difference
  ),
  stringsAsFactors = FALSE
)
difference_long$cluster_label <- sub(
  "^audit_cluster_",
  "C",
  difference_long$audit_cluster_id
)
difference_long$cluster_label <- factor(
  difference_long$cluster_label,
  levels = rev(unique(difference_long$cluster_label))
)
difference_long$metric <- factor(
  difference_long$metric,
  levels = c("Funders", "Awards", "Any funding")
)
difference_long$text_color <- ifelse(
  abs(difference_long$difference) >= 0.65,
  "#FFFFFF",
  ink
)
difference_path <- file.path(
  audit_table_dir,
  "review_03_rdbu_source_difference_data.csv"
)
write_csv_utf8(difference_long, difference_path)
fig_03 <- "review_03_rdbu_source_difference"
plot_03 <- ggplot(
  difference_long,
  aes(x = metric, y = cluster_label, fill = difference)
) +
  geom_tile(color = paper, linewidth = 0.6) +
  geom_text(
    aes(label = sprintf("%+.2f", difference)),
    family = font_family,
    size = 2.2,
    color = difference_long$text_color
  ) +
  scale_fill_gradientn(
    colors = unlist(review_palettes$rdbu),
    limits = c(-1, 1),
    breaks = c(-1, -0.5, 0, 0.5, 1),
    labels = percent_format(accuracy = 1),
    oob = squish
  ) +
  labs(
    title = review_labels$rdbu_title,
    subtitle = review_labels$rdbu_subtitle,
    x = NULL,
    y = review_labels$y_cluster,
    fill = review_labels$x_difference,
    caption = review_labels$caption
  ) +
  review_theme() +
  theme(
    panel.grid = element_blank(),
    legend.position = "bottom",
    legend.justification = "center"
  )
paths_03 <- save_review_figure(
  plot_03,
  fig_03,
  report_height_mm = 135,
  desktop_height_px = 1400L,
  mobile_height_px = 1700L
)
record_figure(
  fig_03,
  "RdBu_r",
  "signed_difference_heatmap",
  paths_03,
  difference_path,
  review_labels$alt_texts[[fig_03]]
)

monthly <- utils::read.csv(
  file.path(audit_table_dir, "event_2023_monthly.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
monthly$date <- as.Date(paste0(monthly$month, "-01"))
series_map <- c(
  papers = "Papers",
  publishers = "Publishers",
  journals = "Journals"
)
indexed_rows <- lapply(names(series_map), function(column) {
  data.frame(
    date = monthly$date,
    series = series_map[[column]],
    index = 100 * monthly[[column]] / monthly[[column]][[1]],
    stringsAsFactors = FALSE
  )
})
indexed <- do.call(rbind, indexed_rows)
indexed$series <- factor(
  indexed$series,
  levels = unname(series_map)
)
index_path <- file.path(
  audit_table_dir,
  "review_04_bloomberg_monthly_index_data.csv"
)
write_csv_utf8(indexed, index_path)
fig_04 <- "review_04_bloomberg_monthly_index"
plot_04 <- ggplot(
  indexed,
  aes(x = date, y = index, color = series, shape = series)
) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.8, stroke = 0.9) +
  scale_color_manual(values = unlist(review_palettes$bloomberg[1:3])) +
  scale_shape_manual(values = c(16, 17, 15)) +
  scale_x_date(
    date_breaks = "2 months",
    date_labels = visualization_config$labels$style_test_c$month_label_format,
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  scale_y_continuous(labels = comma) +
  labs(
    title = review_labels$bloomberg_title,
    subtitle = review_labels$bloomberg_subtitle,
    x = NULL,
    y = review_labels$x_index,
    color = NULL,
    shape = NULL,
    caption = review_labels$caption
  ) +
  review_theme() +
  theme(
    legend.position = "top",
    legend.justification = "center",
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(
      color = grid_color,
      linewidth = 0.3
    )
  )
paths_04 <- save_review_figure(
  plot_04,
  fig_04,
  report_height_mm = 95,
  desktop_height_px = 1000L
)
record_figure(
  fig_04,
  "Bloomberg",
  "time_series_multi_line",
  paths_04,
  index_path,
  review_labels$alt_texts[[fig_04]]
)

signed_data <- cluster_difference[, c(
  "audit_cluster_id",
  "any_difference"
), drop = FALSE]
positive_data <- signed_data[
  signed_data$any_difference > 1e-9,
  ,
  drop = FALSE
]
negative_data <- signed_data[
  signed_data$any_difference < -1e-9,
  ,
  drop = FALSE
]
positive_data <- head(
  positive_data[
    order(-positive_data$any_difference),
    ,
    drop = FALSE
  ],
  5L
)
negative_data <- head(
  negative_data[
    order(-abs(negative_data$any_difference)),
    ,
    drop = FALSE
  ],
  7L
)
signed_data <- rbind(positive_data, negative_data)
signed_data$direction <- ifelse(
  signed_data$any_difference > 0,
  "positive",
  "negative"
)
signed_data$cluster_label <- sub(
  "^audit_cluster_",
  "C",
  signed_data$audit_cluster_id
)
signed_data$cluster_label <- factor(
  signed_data$cluster_label,
  levels = signed_data$cluster_label[
    order(signed_data$any_difference)
  ]
)
signed_path <- file.path(
  audit_table_dir,
  "review_05_signed_pair_source_difference_data.csv"
)
write_csv_utf8(signed_data, signed_path)
fig_05 <- "review_05_signed_pair_source_difference"
plot_05 <- ggplot(
  signed_data,
  aes(x = any_difference, y = cluster_label, fill = direction)
) +
  geom_vline(
    xintercept = 0,
    color = review_palettes$signed_pair$neutral,
    linewidth = 0.7
  ) +
  geom_col(width = 0.62) +
  geom_text(
    aes(
      label = sprintf("%+.2f", any_difference),
      hjust = ifelse(any_difference >= 0, -0.1, 1.1)
    ),
    family = font_family,
    size = 2.8,
    color = ink
  ) +
  scale_fill_manual(
    values = c(
      positive = review_palettes$signed_pair$positive,
      negative = review_palettes$signed_pair$negative
    )
  ) +
  scale_x_continuous(
    labels = percent_format(accuracy = 1),
    limits = c(
      -max(abs(signed_data$any_difference)) * 1.25,
      max(abs(signed_data$any_difference)) * 1.25
    )
  ) +
  labs(
    title = review_labels$signed_pair_title,
    subtitle = review_labels$signed_pair_subtitle,
    x = review_labels$x_difference,
    y = review_labels$y_cluster,
    caption = review_labels$caption
  ) +
  review_theme() +
  theme(legend.position = "none")
paths_05 <- save_review_figure(
  plot_05,
  fig_05,
  report_height_mm = 105,
  desktop_height_px = 1100L
)
record_figure(
  fig_05,
  "Signed blue-coral pair",
  "signed_values",
  paths_05,
  signed_path,
  review_labels$alt_texts[[fig_05]]
)

profiles <- utils::read.csv(
  file.path(audit_table_dir, "p2_audit_cluster_profiles.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
family_counts <- utils::read.csv(
  file.path(audit_table_dir, "p2_audit_cluster_family_counts.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
family_order <- c(
  "family_publication_process",
  "family_image_integrity",
  "family_plagiarism_authorship"
)
dominant_family <- vapply(
  split(family_counts, family_counts$audit_cluster_id),
  function(data) {
    data <- data[data$analysis_family %in% family_order, , drop = FALSE]
    if (nrow(data) == 0L) {
      return("family_other")
    }
    data$family_order <- match(data$analysis_family, family_order)
    data <- data[
      order(-data$papers, data$family_order),
      ,
      drop = FALSE
    ]
    data$analysis_family[[1]]
  },
  character(1)
)
profiles$dominant_family <- unname(
  dominant_family[profiles$audit_cluster_id]
)
profiles$dominant_family[
  is.na(profiles$dominant_family)
] <- "family_other"
family_label_map <- c(
  family_publication_process =
    review_labels$family_publication_process,
  family_image_integrity =
    review_labels$family_image_integrity,
  family_plagiarism_authorship =
    review_labels$family_plagiarism_authorship,
  family_other = review_labels$family_other
)
profiles$family_label <- factor(
  unname(family_label_map[profiles$dominant_family]),
  levels = unname(family_label_map)
)
scatter_data <- profiles[, c(
  "audit_cluster_id",
  "authors",
  "repeated_internal_edges",
  "dominant_family",
  "family_label"
), drop = FALSE]
scatter_path <- file.path(
  audit_table_dir,
  "review_06_tab10_soft_cluster_scatter_data.csv"
)
write_csv_utf8(scatter_data, scatter_path)
fig_06 <- "review_06_tab10_soft_cluster_scatter"
plot_06 <- ggplot(
  profiles,
  aes(
    x = authors,
    y = repeated_internal_edges,
    color = family_label,
    shape = family_label
  )
) +
  geom_point(size = 3.8, stroke = 1.2) +
  scale_color_manual(
    values = setNames(
      c(
        review_palettes$tab10_soft[[1]],
        review_palettes$tab10_soft[[3]],
        review_palettes$tab10_soft[[5]],
        review_palettes$tab10_soft[[10]]
      ),
      unname(family_label_map)
    )
  ) +
  scale_shape_manual(values = c(16, 17, 15, 3)) +
  labs(
    title = review_labels$tab10_soft_title,
    subtitle = review_labels$tab10_soft_subtitle,
    x = review_labels$x_authors,
    y = review_labels$x_repeated_edges,
    color = NULL,
    shape = NULL,
    caption = review_labels$caption
  ) +
  review_theme() +
  theme(
    legend.position = "top",
    legend.justification = "center",
    panel.grid.major.y = element_line(
      color = grid_color,
      linewidth = 0.3
    )
  )
paths_06 <- save_review_figure(
  plot_06,
  fig_06,
  report_height_mm = 100,
  desktop_height_px = 1050L
)
record_figure(
  fig_06,
  "Tab10 soft",
  "categorical_scatter",
  paths_06,
  scatter_path,
  review_labels$alt_texts[[fig_06]]
)

batches <- utils::read.csv(
  file.path(audit_table_dir, "event_2023_same_day_batches.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
batches <- head(batches, 10L)
batches$highlight <- seq_len(nrow(batches)) == 1L
batches$batch_label <- paste(
  batches$retraction_date,
  batches$publisher,
  sep = " | "
)
batches$batch_label <- factor(
  batches$batch_label,
  levels = batches$batch_label[order(batches$papers)]
)
batches_path <- file.path(
  audit_table_dir,
  "review_07_gray_accent_batches_data.csv"
)
write_csv_utf8(batches, batches_path)
fig_07 <- "review_07_gray_accent_batches"
plot_07 <- ggplot(
  batches,
  aes(x = papers, y = batch_label, fill = highlight)
) +
  geom_col(width = 0.65) +
  geom_text(
    aes(label = comma(papers)),
    family = font_family,
    size = 2.9,
    hjust = -0.08,
    color = ink
  ) +
  scale_fill_manual(
    values = c(
      `FALSE` = review_palettes$gray_accent[[1]],
      `TRUE` = review_palettes$gray_accent[[2]]
    )
  ) +
  scale_x_continuous(
    labels = comma,
    expand = expansion(mult = c(0, 0.08))
  ) +
  labs(
    title = review_labels$gray_accent_title,
    subtitle = review_labels$gray_accent_subtitle,
    x = review_labels$x_papers,
    y = NULL,
    caption = review_labels$caption
  ) +
  review_theme() +
  theme(legend.position = "none")
paths_07 <- save_review_figure(
  plot_07,
  fig_07,
  report_height_mm = 105,
  desktop_height_px = 1100L
)
record_figure(
  fig_07,
  "Gray + single accent",
  "emphasis",
  paths_07,
  batches_path,
  review_labels$alt_texts[[fig_07]]
)

fig_08 <- "review_08_morandi_group_coverage"
plot_08 <- make_group_bar(
  unlist(review_palettes$morandi_report[1:3]),
  review_labels$morandi_title,
  review_labels$morandi_subtitle
)
paths_08 <- save_review_figure(
  plot_08,
  fig_08,
  report_height_mm = 85,
  desktop_height_px = 900L
)
data_08 <- write_figure_data(coverage, fig_08)
record_figure(
  fig_08,
  "Morandi low saturation",
  "low_saturation_categorical",
  paths_08,
  data_08,
  review_labels$alt_texts[[fig_08]]
)

fig_09 <- "review_09_okabe_ito_group_coverage"
okabe_colors <- unlist(review_palettes$okabe_ito[c(1, 2, 3)])
coverage$okabe_group <- factor(
  coverage$analysis_group,
  levels = names(group_labels),
  labels = unname(group_labels)
)
plot_09 <- ggplot(
  coverage,
  aes(
    x = any_funding_coverage,
    y = group_label,
    fill = group_label,
    shape = group_label
  )
) +
  geom_errorbar(
    aes(xmin = coverage_ci_low, xmax = coverage_ci_high),
    width = 0.16,
    orientation = "y",
    linewidth = 0.9,
    color = palette_b[["neutral"]],
    show.legend = FALSE
  ) +
  geom_point(
    size = 4.4,
    stroke = 1.1,
    color = ink
  ) +
  geom_text(
    aes(x = coverage_ci_high + 0.025, label = label),
    family = font_family,
    size = 3,
    hjust = 0,
    color = ink,
    show.legend = FALSE
  ) +
  scale_fill_manual(values = setNames(okabe_colors, unname(group_labels))) +
  scale_shape_manual(values = c(21, 24, 22)) +
  scale_x_continuous(
    labels = percent_format(accuracy = 1),
    limits = c(0, 1),
    breaks = seq(0, 1, by = 0.2),
    expand = expansion(mult = c(0.01, 0.04))
  ) +
  labs(
    title = review_labels$okabe_ito_title,
    subtitle = review_labels$okabe_ito_subtitle,
    x = review_labels$x_coverage,
    y = NULL,
    caption = review_labels$caption
  ) +
  review_theme() +
  theme(legend.position = "none")
paths_09 <- save_review_figure(
  plot_09,
  fig_09,
  report_height_mm = 85,
  desktop_height_px = 900L
)
data_09 <- write_figure_data(coverage, fig_09)
record_figure(
  fig_09,
  "Okabe-Ito",
  "colorblind_safe_categorical",
  paths_09,
  data_09,
  review_labels$alt_texts[[fig_09]]
)

palette_order <- c(
  "tableau10",
  "viridis",
  "rdbu",
  "bloomberg",
  "signed_pair",
  "tab10_soft",
  "gray_accent",
  "morandi_report",
  "okabe_ito"
)
swatch_rows <- list()
for (palette_index in seq_along(palette_order)) {
  palette_id <- palette_order[[palette_index]]
  colors <- unlist(review_palettes[[palette_id]], use.names = FALSE)
  swatch_rows[[length(swatch_rows) + 1L]] <- data.frame(
    palette_id = palette_id,
    palette_label = review_labels$palette_names[[palette_id]],
    position = seq_along(colors),
    hex = colors,
    stringsAsFactors = FALSE
  )
}
swatches <- do.call(rbind, swatch_rows)
swatches$palette_label <- factor(
  swatches$palette_label,
  levels = rev(vapply(
    palette_order,
    function(id) review_labels$palette_names[[id]],
    character(1)
  ))
)
swatches_path <- file.path(
  audit_table_dir,
  "review_00_palette_swatches_data.csv"
)
write_csv_utf8(swatches, swatches_path)
fig_00 <- "review_00_palette_swatches"
plot_00 <- ggplot(
  swatches,
  aes(x = position, y = palette_label, fill = hex)
) +
  geom_tile(width = 0.94, height = 0.62, color = paper, linewidth = 0.6) +
  scale_fill_identity() +
  scale_x_continuous(
    limits = c(0.5, max(swatches$position) + 0.5),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    title = review_labels$swatches_title,
    subtitle = review_labels$swatches_subtitle
  ) +
  theme_void(base_family = font_family) +
  theme(
    plot.background = element_rect(fill = paper, color = NA),
    plot.title = element_text(
      family = font_family,
      color = ink,
      size = 13,
      face = "bold",
      hjust = 0.5
    ),
    plot.subtitle = element_text(
      family = font_family,
      color = ink,
      size = 9,
      hjust = 0.5,
      margin = margin(b = 8)
    ),
    axis.text.y = element_text(
      family = font_family,
      color = ink,
      size = 8,
      hjust = 1
    ),
    plot.margin = margin(10, 18, 10, 10)
  )
paths_00 <- save_review_figure(
  plot_00,
  fig_00,
  report_height_mm = 120,
  desktop_height_px = 1100L,
  mobile_height_px = 1400L
)
record_figure(
  fig_00,
  "all reviewed palettes",
  "palette_swatches",
  paths_00,
  swatches_path,
  review_labels$alt_texts[[fig_00]]
)

contrast_ratio <- function(hex, background = paper) {
  parse <- function(value) {
    value <- sub("^#", "", value)
    grDevices::col2rgb(paste0("#", value))[, 1] / 255
  }
  linear <- function(rgb) {
    ifelse(
      rgb <= 0.04045,
      rgb / 12.92,
      ((rgb + 0.055) / 1.055)^2.4
    )
  }
  luminance <- function(rgb) {
    rgb <- linear(rgb)
    0.2126 * rgb[[1]] + 0.7152 * rgb[[2]] + 0.0722 * rgb[[3]]
  }
  foreground_luminance <- luminance(parse(hex))
  background_luminance <- luminance(parse(background))
  lighter <- pmax(foreground_luminance, background_luminance)
  darker <- pmin(foreground_luminance, background_luminance)
  (lighter + 0.05) / (darker + 0.05)
}

minimum_pairwise_delta_e <- function(colors) {
  if (length(colors) < 2L) {
    return(NA_real_)
  }
  rgb <- farver::decode_colour(colors)
  distances <- farver::compare_colour(
    rgb,
    from_space = "rgb",
    method = "cie2000"
  )
  min(distances[upper.tri(distances)])
}

simulated_minimum_delta_e <- function(colors, type) {
  simulated <- switch(
    type,
    deutan = colorspace::deutan(colors),
    protan = colorspace::protan(colors),
    tritan = colorspace::tritan(colors)
  )
  minimum_pairwise_delta_e(as.character(simulated))
}

palette_type <- c(
  tableau10 = "categorical",
  viridis = "sequential",
  rdbu = "diverging",
  bloomberg = "categorical",
  signed_pair = "signed_pair",
  tab10_soft = "categorical",
  gray_accent = "emphasis",
  morandi_report = "categorical",
  okabe_ito = "categorical"
)
max_series <- c(
  tableau10 = 4L,
  viridis = NA_integer_,
  rdbu = NA_integer_,
  bloomberg = 3L,
  signed_pair = 2L,
  tab10_soft = 4L,
  gray_accent = 2L,
  morandi_report = 3L,
  okabe_ito = 4L
)
review_test_subsets <- list(
  tableau10 = unlist(review_palettes$tableau10[1:3]),
  viridis = unlist(review_palettes$viridis),
  rdbu = unlist(review_palettes$rdbu),
  bloomberg = unlist(review_palettes$bloomberg[1:3]),
  signed_pair = unlist(review_palettes$signed_pair),
  tab10_soft = unlist(review_palettes$tab10_soft[c(1, 3, 5, 10)]),
  gray_accent = unlist(review_palettes$gray_accent),
  morandi_report = unlist(review_palettes$morandi_report[1:3]),
  okabe_ito = unlist(review_palettes$okabe_ito[1:3])
)
metric_rows <- list()
color_rows <- list()
for (palette_id in palette_order) {
  colors <- unlist(review_palettes[[palette_id]], use.names = FALSE)
  categorical <- palette_type[[palette_id]] %in%
    c("categorical", "signed_pair", "emphasis")
  metric_rows[[length(metric_rows) + 1L]] <- data.frame(
    palette_id = palette_id,
    palette = review_labels$palette_names[[palette_id]],
    palette_type = palette_type[[palette_id]],
    colors = length(colors),
    max_recommended_series = max_series[[palette_id]],
    minimum_contrast_vs_paper = min(contrast_ratio(colors)),
    minimum_ciede2000 = if (categorical) {
      minimum_pairwise_delta_e(colors)
    } else {
      NA_real_
    },
    minimum_ciede2000_deutan = if (categorical) {
      simulated_minimum_delta_e(colors, "deutan")
    } else {
      NA_real_
    },
    minimum_ciede2000_protan = if (categorical) {
      simulated_minimum_delta_e(colors, "protan")
    } else {
      NA_real_
    },
    minimum_ciede2000_tritan = if (categorical) {
      simulated_minimum_delta_e(colors, "tritan")
    } else {
      NA_real_
    },
    minimum_ciede2000_test_subset = if (categorical) {
      minimum_pairwise_delta_e(review_test_subsets[[palette_id]])
    } else {
      NA_real_
    },
    minimum_ciede2000_test_subset_deutan = if (categorical) {
      simulated_minimum_delta_e(
        review_test_subsets[[palette_id]],
        "deutan"
      )
    } else {
      NA_real_
    },
    minimum_ciede2000_test_subset_protan = if (categorical) {
      simulated_minimum_delta_e(
        review_test_subsets[[palette_id]],
        "protan"
      )
    } else {
      NA_real_
    },
    minimum_ciede2000_test_subset_tritan = if (categorical) {
      simulated_minimum_delta_e(
        review_test_subsets[[palette_id]],
        "tritan"
      )
    } else {
      NA_real_
    },
    stringsAsFactors = FALSE
  )
  color_rows[[length(color_rows) + 1L]] <- data.frame(
    palette_id = palette_id,
    position = seq_along(colors),
    hex = colors,
    contrast_vs_paper = contrast_ratio(colors),
    stringsAsFactors = FALSE
  )
}
palette_metrics <- do.call(rbind, metric_rows)
color_metrics <- do.call(rbind, color_rows)
write_csv_utf8(
  palette_metrics,
  file.path(audit_table_dir, "palette_review_metrics.csv")
)
write_csv_utf8(
  color_metrics,
  file.path(audit_table_dir, "palette_review_color_metrics.csv")
)

write_audit_figure_metadata(
  figure_records,
  file.path(audit_figure_dir, "palette_review_metadata.json")
)
write_audit_manifest()
message("Palette review test figures completed.")

