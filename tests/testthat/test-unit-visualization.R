project_root_for_visualization <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

read_visualization_config <- function(project_root) {
  yaml::read_yaml(file.path(
    project_root,
    "config",
    "visualization.yml"
  ))
}

test_that("project palettes preserve approved bright Morandi values", {
  config <- read_visualization_config(project_root_for_visualization())

  expect_equal(
    unlist(config$palettes$B[c(
      "primary",
      "secondary",
      "tertiary",
      "paper"
    )]),
    c(
      primary = "#2F8F9D",
      secondary = "#D96C62",
      tertiary = "#86B86E",
      paper = "#FBFAF7"
    )
  )
  expect_equal(
    unlist(config$palettes$C[c(
      "primary",
      "secondary",
      "tertiary",
      "paper"
    )]),
    c(
      primary = "#6FA35B",
      secondary = "#DE765B",
      tertiary = "#479DB5",
      paper = "#FBFAF7"
    )
  )
})

test_that("review palettes preserve the proposed color values", {
  config <- read_visualization_config(project_root_for_visualization())

  expect_equal(
    unlist(config$review_palettes$tableau10),
    c(
      "#4E79A7",
      "#F28E2B",
      "#E15759",
      "#76B7B2",
      "#59A14F",
      "#EDC948",
      "#B07AA1",
      "#FF9DA7",
      "#9C755F",
      "#BAB0AC"
    )
  )
  expect_equal(
    unlist(config$review_palettes$viridis),
    c(
      "#440154",
      "#482878",
      "#3E4A89",
      "#31688E",
      "#26828E",
      "#1F9E89",
      "#35B779",
      "#6DCD59",
      "#B4DE2C",
      "#FDE725"
    )
  )
  expect_equal(
    unlist(config$review_palettes$okabe_ito),
    c(
      "#E69F00",
      "#56B4E9",
      "#009E73",
      "#F0E442",
      "#0072B2",
      "#D55E00",
      "#CC79A7"
    )
  )
})

test_that("palette review outputs and hashes are complete", {
  project_root <- project_root_for_visualization()
  source(file.path(project_root, "R", "lib", "file_hash.R"))
  metadata <- jsonlite::read_json(
    file.path(
      project_root,
      "data",
      "outputs",
      "audits",
      "figures",
      "palette_review_metadata.json"
    ),
    simplifyVector = FALSE
  )

  expect_equal(length(metadata$figures), 10L)
  expect_setequal(
    vapply(
      metadata$figures,
      function(figure) as.character(figure$figure_id),
      character(1)
    ),
    c(
      "review_00_palette_swatches",
      "review_01_tableau10_group_coverage",
      "review_02_viridis_funding_heatmap",
      "review_03_rdbu_source_difference",
      "review_04_bloomberg_monthly_index",
      "review_05_signed_pair_source_difference",
      "review_06_tab10_soft_cluster_scatter",
      "review_07_gray_accent_batches",
      "review_08_morandi_group_coverage",
      "review_09_okabe_ito_group_coverage"
    )
  )

  for (figure in metadata$figures) {
    table_path <- file.path(
      project_root,
      as.character(figure$table_fallback)
    )
    expect_true(file.exists(table_path))
    expect_equal(
      sha256_canonical_file(table_path),
      as.character(figure$data_sha256)
    )
    expect_equal(length(figure$outputs), 4L)
    for (output in figure$outputs) {
      path <- file.path(project_root, as.character(output$path))
      expect_true(file.exists(path))
      expect_equal(
        digest::digest(file = path, algo = "sha256"),
        as.character(output$sha256)
      )
    }
  }
})

test_that("palette review metrics cover every proposed palette", {
  metrics <- data.table::fread(
    file.path(
      project_root_for_visualization(),
      "data",
      "outputs",
      "audits",
      "tables",
      "palette_review_metrics.csv"
    ),
    encoding = "UTF-8",
    data.table = FALSE
  )

  expect_equal(nrow(metrics), 9L)
  expect_setequal(
    metrics$palette_id,
    c(
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
  )
  expect_equal(metrics$palette_id[[1]], "tableau10")
  expect_true(all(is.finite(metrics$minimum_contrast_vs_paper)))
  expect_lt(
    metrics$minimum_ciede2000_deutan[
      metrics$palette_id == "tableau10"
    ],
    2
  )
  expect_gt(
    metrics$minimum_ciede2000_test_subset_deutan[
      metrics$palette_id == "tableau10"
    ],
    10
  )
})

