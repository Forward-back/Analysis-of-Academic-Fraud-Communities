project_root_for_p0 <- function() {
  normalizePath(file.path(testthat::test_path(), "..", ".."))
}

test_that("P0 normalization helpers are deterministic", {
  project_root <- project_root_for_p0()
  old_working_directory <- setwd(project_root)
  on.exit(setwd(old_working_directory), add = TRUE)
  source(file.path(project_root, "R", "00_setup.R"), local = TRUE)

  expect_equal(
    normalize_doi(c(" https://doi.org/10.123/ABC. ", "doi: 10.555/X")),
    c("10.123/abc", "10.555/x")
  )
  expect_equal(
    normalize_title(c("A  title & more", "Second-title")),
    c("a title more", "second title")
  )

  unicode_doi <- paste0(
    "10.3969/j.issn.1672",
    intToUtf8(0x2043),
    "6731.2022.01.007"
  )
  doi_key <- doi_environment_key(unicode_doi)
  expect_match(doi_key, "^[0-9a-f]{64}$")
  doi_env <- new.env(parent = emptyenv())
  assign(doi_key, TRUE, envir = doi_env)
  expect_true(exists(doi_key, envir = doi_env, inherits = FALSE))
})

test_that("OpenAlex parser creates work and authorship audits", {
  project_root <- project_root_for_p0()
  old_working_directory <- setwd(project_root)
  on.exit(setwd(old_working_directory), add = TRUE)
  source(file.path(project_root, "R", "00_setup.R"), local = TRUE)
  source(
    file.path(project_root, "R", "lib", "openalex_parse.R"),
    local = TRUE
  )

  cache_root <- tempfile("openalex-cache-")
  metadata_root <- file.path(cache_root, "metadata")
  dir.create(metadata_root, recursive = TRUE)

  metadata <- list(
    batch_id = "batch_0001",
    requested_dois = "10.1234/example",
    http_status = 200L,
    json_valid = TRUE
  )
  jsonlite::write_json(
    metadata,
    file.path(metadata_root, "batch_0001.json"),
    auto_unbox = TRUE
  )

  response <- list(
    results = list(
      list(
        id = "https://openalex.org/W1",
        doi = "https://doi.org/10.1234/example",
        title = "Example",
        publication_year = 2020L,
        publication_date = "2020-01-01",
        type = "article",
        is_retracted = TRUE,
        authorships = list(
          list(
            author = list(
              id = "https://openalex.org/A1",
              display_name = "Author One",
              orcid = NULL
            ),
            institutions = list(
              list(
                id = "https://openalex.org/I1",
                display_name = "Example University",
                country_code = "CN"
              )
            ),
            countries = list("CN"),
            is_corresponding = TRUE,
            raw_affiliation_strings = list("Example University")
          )
        ),
        primary_location = list(
          source = list(
            id = "https://openalex.org/S1",
            display_name = "Example Journal",
            host_organization = "https://openalex.org/P1",
            host_organization_name = "Example Publisher"
          )
        ),
        primary_topic = list(
          id = "https://openalex.org/T1",
          display_name = "Example Topic",
          subfield = list(id = "subfields/1"),
          field = list(id = "fields/1"),
          domain = list(id = "domains/1")
        ),
        funders = list(),
        awards = list(),
        updated_date = "2026-01-01",
        cited_by_count = 1L
      )
    )
  )
  jsonlite::write_json(
    response,
    file.path(cache_root, "batch_0001.json"),
    auto_unbox = TRUE
  )

  candidates <- data.frame(
    paper_key = "paper_000001",
    doi_canonical = "10.1234/example",
    stringsAsFactors = FALSE
  )
  parsed <- parse_openalex_cache(cache_root, candidates)

  expect_equal(parsed$requested_panel$match_status, "exact")
  expect_equal(parsed$works$match_status, "exact")
  expect_equal(parsed$works$confirmed_mainland, TRUE)
  expect_equal(parsed$works$all_authors_have_id, TRUE)
  expect_equal(parsed$works$all_authors_have_institution, TRUE)
  expect_equal(parsed$works$source_present, TRUE)
  expect_equal(nrow(parsed$authorships), 1L)
  expect_equal(parsed$authorships$author_id, "https://openalex.org/A1")
})

test_that("OpenAlex response text is parsed as JSON content", {
  project_root <- project_root_for_p0()
  source(
    file.path(project_root, "R", "lib", "openalex_parse.R"),
    local = TRUE
  )

  body <- '{"results":[{"id":"https://openalex.org/W1"}]}'
  parsed <- parse_openalex_body(body)

  expect_true(parsed$json_valid)
  expect_equal(parsed$error, "")
  expect_equal(parsed$parsed$results[[1]]$id, "https://openalex.org/W1")
})

test_that("title similarity handles notice prefixes and unrelated titles", {
  project_root <- project_root_for_p0()
  old_working_directory <- setwd(project_root)
  on.exit(setwd(old_working_directory), add = TRUE)
  source(file.path(project_root, "R", "00_setup.R"), local = TRUE)
  source(
    file.path(project_root, "R", "lib", "title_similarity.R"),
    local = TRUE
  )

  expect_equal(
    token_containment("A study of cells", "RETRACTED: A study of cells"),
    1
  )
  expect_lt(
    token_containment("Growth factors and beta cell replication", "Notice"),
    0.5
  )
})
