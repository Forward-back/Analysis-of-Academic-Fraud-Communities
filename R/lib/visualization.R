visualization_config <- yaml::read_yaml("config/visualization.yml")
audit_palettes <- visualization_config$palettes

audit_font_family <- function() {
  if (!requireNamespace("systemfonts", quietly = TRUE)) {
    return("sans")
  }
  available <- unique(systemfonts::system_fonts()[["family"]])
  if ("Arial" %in% available) {
    return("Arial")
  }
  if ("Microsoft YaHei" %in% available) {
    return("Microsoft YaHei")
  }
  "sans"
}

audit_theme <- function(palette_name = c("B", "C"), base_size = 8.5) {
  palette_name <- match.arg(palette_name)
  palette <- audit_palettes[[palette_name]]
  font_family <- audit_font_family()

  ggplot2::theme_minimal(
    base_family = font_family,
    base_size = base_size
  ) +
    ggplot2::theme(
      text = ggplot2::element_text(color = palette[["ink"]]),
      plot.background = ggplot2::element_rect(
        fill = palette[["paper"]],
        color = NA
      ),
      panel.background = ggplot2::element_rect(
        fill = palette[["paper"]],
        color = NA
      ),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_line(
        color = "#DDDAD3",
        linewidth = 0.3
      ),
      axis.line = ggplot2::element_line(
        color = palette[["neutral"]],
        linewidth = 0.6
      ),
      axis.ticks = ggplot2::element_line(
        color = palette[["neutral"]],
        linewidth = 0.6
      ),
      axis.text = ggplot2::element_text(
        color = palette[["ink"]],
        size = 8
      ),
      axis.title = ggplot2::element_text(
        color = palette[["ink"]],
        size = 8.5
      ),
      plot.title = ggplot2::element_text(
        family = font_family,
        color = palette[["ink"]],
        size = 10.5,
        face = "bold",
        hjust = 0.5
      ),
      plot.subtitle = ggplot2::element_text(
        family = font_family,
        color = palette[["ink"]],
        size = 8.5,
        hjust = 0.5,
        margin = ggplot2::margin(b = 6)
      ),
      plot.caption = ggplot2::element_text(
        family = font_family,
        color = palette[["neutral"]],
        size = 7.5,
        hjust = 0
      ),
      plot.caption.position = "plot",
      plot.title.position = "plot",
      legend.position = "top",
      legend.justification = "center",
      legend.title = ggplot2::element_blank(),
      legend.text = ggplot2::element_text(size = 8),
      plot.margin = ggplot2::margin(8, 12, 8, 8)
    )
}

save_audit_figure <- function(
    plot,
    output_dir,
    figure_id,
    palette_name = c("B", "C"),
    report_width_mm = 165,
    report_height_mm = 95,
    desktop_width_px = 1600L,
    desktop_height_px = 1000L,
    mobile_width_px = 800L,
    mobile_height_px = 1200L) {
  palette_name <- match.arg(palette_name)
  palette <- audit_palettes[[palette_name]]
  ensure_dir(output_dir)

  paths <- c(
    svg = file.path(output_dir, paste0(figure_id, ".svg")),
    pdf = file.path(output_dir, paste0(figure_id, ".pdf")),
    desktop_png = file.path(
      output_dir,
      paste0(figure_id, "_desktop.png")
    ),
    mobile_png = file.path(
      output_dir,
      paste0(figure_id, "_mobile.png")
    )
  )

  ggplot2::ggsave(
    filename = paths[["svg"]],
    plot = plot,
    device = grDevices::svg,
    width = report_width_mm,
    height = report_height_mm,
    units = "mm",
    bg = palette[["paper"]]
  )
  ggplot2::ggsave(
    filename = paths[["pdf"]],
    plot = plot,
    device = grDevices::cairo_pdf,
    width = report_width_mm,
    height = report_height_mm,
    units = "mm",
    bg = palette[["paper"]]
  )
  ragg::agg_png(
    filename = paths[["desktop_png"]],
    width = as.integer(desktop_width_px),
    height = as.integer(desktop_height_px),
    units = "px",
    res = 144,
    background = palette[["paper"]],
    scaling = 1
  )
  print(plot)
  grDevices::dev.off()
  ragg::agg_png(
    filename = paths[["mobile_png"]],
    width = as.integer(mobile_width_px),
    height = as.integer(mobile_height_px),
    units = "px",
    res = 144,
    background = palette[["paper"]],
    scaling = 1
  )
  print(plot)
  grDevices::dev.off()

  paths
}

write_audit_figure_metadata <- function(records, path) {
  jsonlite::write_json(
    list(
      contract_version = "1.0",
      generated_on = as.character(Sys.Date()),
      figures = records
    ),
    path,
    auto_unbox = TRUE,
    pretty = TRUE
  )
  invisible(path)
}

