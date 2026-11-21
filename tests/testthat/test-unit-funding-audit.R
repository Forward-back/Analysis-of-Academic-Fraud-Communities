project_root_for_funding_audit <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

test_that("stratified allocation respects size and total constraints", {
  project_root <- project_root_for_funding_audit()
  source(
    file.path(project_root, "R", "lib", "funding_audit.R"),
    local = TRUE
  )

  allocation <- allocate_stratified_sample(c(30L, 10L, 5L), 20L)
  expect_equal(sum(allocation), 20L)
  expect_true(all(allocation > 0L))
  expect_true(all(allocation <= c(30L, 10L, 5L)))

  full <- allocate_stratified_sample(c(5L, 3L), 20L)
  expect_equal(full, c(5L, 3L))
})

test_that("funding sample is deterministic within a cluster", {
  project_root <- project_root_for_funding_audit()
  source(
    file.path(project_root, "R", "lib", "funding_audit.R"),
    local = TRUE
  )

  data <- data.frame(
    paper_key = sprintf("paper_%02d", seq_len(30L)),
    retraction_year_first = rep(c(2021L, 2022L, 2023L), each = 10L),
    publisher = rep(c("A", "B"), 15L),
    stringsAsFactors = FALSE
  )
  first <- funding_sample_within_cluster(data, 12L, 123L, 7L)
  second <- funding_sample_within_cluster(data, 12L, 123L, 7L)

  expect_equal(nrow(first), 12L)
  expect_equal(first$paper_key, second$paper_key)
  stratum_allocations <- unique(first[, c(
    "funding_stratum",
    "stratum_sample_n"
  ), drop = FALSE])
  expect_equal(sum(stratum_allocations$stratum_sample_n), 12L)
  expect_true(all(first$stratum_sample_n <= first$stratum_size))
})
