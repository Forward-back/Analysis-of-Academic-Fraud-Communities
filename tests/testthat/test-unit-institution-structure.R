project_root_for_institution_structure <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

test_that("institution year rules follow the frozen tier versions", {
  project_root <- project_root_for_institution_structure()
  source(
    file.path(project_root, "R", "lib", "institution_structure.R"),
    local = TRUE
  )

  data <- data.frame(
    publication_year = c(2016L, 2017L, 2021L, 2022L, NA),
    is_mainland_institution = TRUE,
    is_hmt_institution = FALSE,
    is_foreign_institution = FALSE,
    tier_985 = c(TRUE, FALSE, FALSE, FALSE, FALSE),
    tier_211 = FALSE,
    tier_double_first_class_2017 = c(FALSE, TRUE, TRUE, FALSE, FALSE),
    tier_double_first_class_2022 = c(FALSE, FALSE, FALSE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  result <- institution_add_year_tier(data, "publication_year")

  expect_equal(
    result$tier_rule,
    c(
      "985_211_2016",
      "double_first_class_2017_2021",
      "double_first_class_2017_2021",
      "double_first_class_2022_2025",
      "unknown"
    )
  )
  expect_equal(
    result$national_key_institution,
    c(TRUE, TRUE, TRUE, TRUE, FALSE)
  )
})

test_that("institution distance and paper structure are deterministic", {
  project_root <- project_root_for_institution_structure()
  source(
    file.path(project_root, "R", "lib", "institution_structure.R"),
    local = TRUE
  )

  distance <- haversine_km(39.9042, 116.4074, 31.2304, 121.4737)
  expect_true(distance > 1000 && distance < 1150)

  data <- data.frame(
    paper_key = c("p1", "p1", "p2"),
    institution_id = c("i1", "i2", "i3"),
    city = c("Beijing", "Shanghai", "Beijing"),
    region_code = c("BJ", "SH", "BJ"),
    latitude = c(39.9042, 31.2304, 39.9042),
    longitude = c(116.4074, 121.4737, 116.4074),
    is_mainland_institution = c(TRUE, TRUE, FALSE),
    is_hmt_institution = c(FALSE, FALSE, TRUE),
    is_foreign_institution = FALSE,
    national_key_institution = c(TRUE, FALSE, FALSE),
    legacy_985_211_institution = c(TRUE, FALSE, FALSE),
    tier_rule = "double_first_class_2022_2025",
    stringsAsFactors = FALSE
  )
  result <- summarize_institution_structure(data, "paper_key")
  result <- result[order(result$paper_key), , drop = FALSE]

  expect_equal(result$cross_tier, c(TRUE, FALSE))
  expect_equal(
    result$geo_level,
    c("domestic_cross_province", "hmt_involved")
  )
  expect_true(result$median_domestic_geo_distance_km[[1]] > 1000)
  expect_equal(result$n_unique_institutions, c(2L, 1L))
})
