#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

cache_root <- file.path(
  project_dir,
  project_config$paths$cache,
  "openalex",
  "p1",
  "selected-control-works"
)
response_files <- list.files(
  cache_root,
  pattern = "^control_works_[0-9]+\\.json$",
  full.names = TRUE
)
if (length(response_files) == 0L) {
  stop("Selected control response files not found.")
}

links <- readRDS(file.path(processed_dir, "p1", "control_links.rds"))
link_lookup <- new.env(hash = TRUE, parent = emptyenv())
for (index in seq_len(nrow(links))) {
  assign(
    links$openalex_work_id[[index]],
    links$paper_key[[index]],
    envir = link_lookup
  )
}

work_rows <- list()
author_rows <- list()
for (file_index in seq_along(response_files)) {
  response <- jsonlite::read_json(
    response_files[[file_index]],
    simplifyVector = FALSE
  )
  works <- response$results
  if (is.null(works) || length(works) == 0L) {
    next
  }
  for (work_index in seq_along(works)) {
    work <- works[[work_index]]
    work_id <- if (is.null(work$id)) NA_character_ else work$id
    if (
      is.na(work_id) ||
        !exists(work_id, envir = link_lookup, inherits = FALSE)
    ) {
      message("Skipping non-selected OpenAlex work returned by cached batch: ", work_id)
      next
    }
    authorships <- work$authorships
    if (is.null(authorships)) authorships <- list()

    author_ids <- vapply(authorships, function(authorship) {
      value <- authorship$author$id
      if (is.null(value)) "" else value
    }, character(1))
    author_names <- vapply(authorships, function(authorship) {
      value <- authorship$author$display_name
      if (is.null(value)) "" else value
    }, character(1))
    orcids <- vapply(authorships, function(authorship) {
      value <- authorship$author$orcid
      if (is.null(value)) "" else value
    }, character(1))
    corresponding <- vapply(authorships, function(authorship) {
      isTRUE(authorship$is_corresponding)
    }, logical(1))
    institution_lists <- lapply(authorships, function(authorship) {
      institutions <- authorship$institutions
      if (is.null(institutions)) return(character())
      unique(vapply(institutions, function(institution) {
        value <- institution$id
        if (is.null(value)) "" else value
      }, character(1)))
    })
    country_lists <- lapply(authorships, function(authorship) {
      countries <- authorship$countries
      if (is.null(countries)) return(character())
      unique(unlist(countries, use.names = FALSE))
    })
    raw_affiliation_lists <- lapply(authorships, function(authorship) {
      values <- authorship$raw_affiliation_strings
      if (is.null(values)) return(character())
      unique(unlist(values, use.names = FALSE))
    })

    institution_ids <- unique(unlist(
      institution_lists,
      use.names = FALSE
    ))
    country_codes <- unique(unlist(country_lists, use.names = FALSE))
    funder_rows <- work$funders
    funder_ids <- if (is.null(funder_rows)) {
      character()
    } else {
      unique(unlist(lapply(funder_rows, function(funder) funder$id)))
    }
    award_rows <- work$awards
    award_ids <- if (is.null(award_rows)) {
      character()
    } else {
      unique(unlist(lapply(award_rows, function(award) award$id)))
    }
    source <- work$primary_location$source
    topic <- work$primary_topic
    work_rows[[length(work_rows) + 1L]] <- data.frame(
      openalex_work_id = work_id,
      case_paper_key = get(work_id, envir = link_lookup),
      doi_canonical = if (is.null(work$doi)) {
        NA_character_
      } else {
        normalize_doi(work$doi)
      },
      title = if (is.null(work$title)) NA_character_ else work$title,
      publication_year = if (is.null(work$publication_year)) {
        NA_integer_
      } else {
        as.integer(work$publication_year)
      },
      publication_date = if (is.null(work$publication_date)) {
        NA_character_
      } else {
        work$publication_date
      },
      openalex_type = if (is.null(work$type)) NA_character_ else work$type,
      is_retracted = isTRUE(work$is_retracted),
      n_authorships = length(authorships),
      n_unique_author_ids = length(unique(author_ids[author_ids != ""])),
      all_authors_have_id = length(authorships) > 0L &&
        all(author_ids != ""),
      all_authors_have_institution = length(authorships) > 0L &&
        all(lengths(institution_lists) > 0L),
      all_authors_have_country = length(authorships) > 0L &&
        all(lengths(country_lists) > 0L),
      confirmed_mainland = "CN" %in% country_codes,
      funders_present = length(funder_ids) > 0L,
      awards_present = length(award_ids) > 0L,
      source_id = if (is.null(source$id)) NA_character_ else source$id,
      source_name = if (is.null(source$display_name)) {
        NA_character_
      } else {
        source$display_name
      },
      publisher_id = if (is.null(source$host_organization)) {
        NA_character_
      } else {
        source$host_organization
      },
      publisher_name = if (is.null(source$host_organization_name)) {
        NA_character_
      } else {
        source$host_organization_name
      },
      primary_topic_id = if (is.null(topic$id)) {
        NA_character_
      } else {
        topic$id
      },
      subfield_id = if (is.null(topic$subfield$id)) {
        NA_character_
      } else {
        topic$subfield$id
      },
      field_id = if (is.null(topic$field$id)) {
        NA_character_
      } else {
        topic$field$id
      },
      domain_id = if (is.null(topic$domain$id)) {
        NA_character_
      } else {
        topic$domain$id
      },
      institution_ids = I(list(institution_ids)),
      country_codes = I(list(country_codes)),
      funder_ids = I(list(funder_ids)),
      award_ids = I(list(award_ids)),
      stringsAsFactors = FALSE
    )

    if (length(authorships) > 0L) {
      author_rows[[length(author_rows) + 1L]] <- data.frame(
        case_paper_key = get(work_id, envir = link_lookup),
        control_work_id = work_id,
        author_order = seq_along(authorships),
        author_id = author_ids,
        author_name = author_names,
        orcid = orcids,
        is_corresponding = corresponding,
        has_institution = lengths(institution_lists) > 0L,
        has_country = lengths(country_lists) > 0L,
        country_codes = I(country_lists),
        institution_ids = I(institution_lists),
        raw_affiliation_strings = I(raw_affiliation_lists),
        stringsAsFactors = FALSE
      )
    }
  }
  if (file_index %% 100L == 0L || file_index == length(response_files)) {
    message("parsed ", file_index, "/", length(response_files))
  }
}

control_works <- do.call(rbind, work_rows)
control_authorships <- do.call(rbind, author_rows)

audit <- data.frame(
  metric = c(
    "requested_control_works",
    "parsed_control_works",
    "parsed_authorships",
    "retracted_flagged",
    "missing_case_key",
    "confirmed_mainland",
    "all_authors_have_institution",
    "all_authors_have_id",
    "all_authors_have_country"
  ),
  value = c(
    nrow(links),
    nrow(control_works),
    nrow(control_authorships),
    sum(control_works$is_retracted),
    sum(is.na(control_works$case_paper_key)),
    sum(control_works$confirmed_mainland),
    sum(control_works$all_authors_have_institution),
    sum(control_works$all_authors_have_id),
    sum(control_works$all_authors_have_country)
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  audit,
  file.path(audit_table_dir, "p1_selected_control_parse_audit.csv")
)

saveRDS(
  control_works,
  file.path(processed_dir, "p1", "control_works_full.rds")
)
saveRDS(
  control_authorships,
  file.path(processed_dir, "p1", "control_authorships_long.rds")
)

write_audit_manifest()
message("Selected control parsing completed.")
