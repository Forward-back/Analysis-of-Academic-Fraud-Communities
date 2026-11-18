parse_openalex_body <- function(body) {
  parsed <- tryCatch(
    jsonlite::fromJSON(body, simplifyVector = FALSE),
    error = function(error) error
  )
  if (inherits(parsed, "error")) {
    return(list(
      json_valid = FALSE,
      parsed = NULL,
      error = conditionMessage(parsed)
    ))
  }
  list(
    json_valid = !is.null(parsed$results),
    parsed = parsed,
    error = ""
  )
}

parse_openalex_cache <- function(cache_root, candidate_panel) {
  scalar_text <- function(value) {
    if (is.null(value) || length(value) == 0L) {
      return("")
    }
    as.character(unlist(value, use.names = FALSE)[[1]])
  }

  if (!dir.exists(cache_root)) {
    stop("OpenAlex cache directory not found: ", cache_root)
  }

  metadata_root <- file.path(cache_root, "metadata")
  metadata_files <- if (dir.exists(metadata_root)) {
    list.files(
      metadata_root,
      pattern = "^batch_[0-9]+\\.json$",
      full.names = TRUE
    )
  } else {
    character()
  }

  request_audit <- if (length(metadata_files) == 0) {
    data.frame(
      batch_id = character(),
      doi_canonical = character(),
      http_status = integer(),
      json_valid = logical(),
      stringsAsFactors = FALSE
    )
  } else {
    rows <- lapply(metadata_files, function(path) {
      metadata <- jsonlite::read_json(path, simplifyVector = FALSE)
      requested <- unlist(metadata$requested_dois, use.names = FALSE)
      data.frame(
        batch_id = rep(metadata$batch_id, length(requested)),
        doi_canonical = normalize_doi(requested),
        http_status = as.integer(metadata$http_status),
        json_valid = isTRUE(metadata$json_valid),
        stringsAsFactors = FALSE
      )
    })
    do.call(rbind, rows)
  }

  response_files <- list.files(
    cache_root,
    pattern = "^batch_[0-9]+\\.json$",
    full.names = TRUE,
    recursive = FALSE
  )

  author_rows <- list()
  work_rows <- list()
  if (length(response_files) > 0) {
    for (file_index in seq_along(response_files)) {
      response_path <- response_files[[file_index]]
      response <- jsonlite::read_json(
        response_path,
        simplifyVector = FALSE
      )
      batch_id <- sub("\\.json$", "", basename(response_path))
      works <- response$results
      if (is.null(works)) {
        next
      }
      if (length(works) == 0) {
        next
      }

      for (work_index in seq_along(works)) {
        work <- works[[work_index]]
        authorships <- work$authorships
        if (is.null(authorships)) {
          authorships <- list()
        }

        author_ids <- vapply(
          authorships,
          function(authorship) {
            scalar_text(authorship$author$id)
          },
          character(1)
        )
        author_names <- vapply(
          authorships,
          function(authorship) {
            scalar_text(authorship$author$display_name)
          },
          character(1)
        )
        orcids <- vapply(
          authorships,
          function(authorship) {
            scalar_text(authorship$author$orcid)
          },
          character(1)
        )
        corresponding <- vapply(
          authorships,
          function(authorship) isTRUE(authorship$is_corresponding),
          logical(1)
        )
        institution_lists <- lapply(authorships, function(authorship) {
          institutions <- authorship$institutions
          if (is.null(institutions)) {
            return(character())
          }
          unique(vapply(
            institutions,
            function(institution) {
              scalar_text(institution$id)
            },
            character(1)
          ))
        })
        institution_name_lists <- lapply(authorships, function(authorship) {
          institutions <- authorship$institutions
          if (is.null(institutions)) {
            return(character())
          }
          unique(vapply(
            institutions,
            function(institution) {
              scalar_text(institution$display_name)
            },
            character(1)
          ))
        })
        country_lists <- lapply(authorships, function(authorship) {
          countries <- authorship$countries
          if (is.null(countries)) {
            return(character())
          }
          unique(unlist(countries, use.names = FALSE))
        })
        raw_affiliation_lists <- lapply(authorships, function(authorship) {
          strings <- authorship$raw_affiliation_strings
          if (is.null(strings)) {
            return(character())
          }
          unique(unlist(strings, use.names = FALSE))
        })

        institution_ids <- unique(unlist(
          institution_lists,
          use.names = FALSE
        ))
        country_codes <- unique(unlist(country_lists, use.names = FALSE))
        author_ids_present <- author_ids[author_ids != ""]
        n_authorships <- length(authorships)
        all_authors_have_institution <- n_authorships > 0L &&
          all(lengths(institution_lists) > 0L)
        all_authors_have_id <- n_authorships > 0L &&
          all(author_ids != "")
        all_authors_have_country <- n_authorships > 0L &&
          all(lengths(country_lists) > 0L)

        source <- work$primary_location$source
        source_id <- if (is.null(source$id)) NA_character_ else source$id
        source_name <- if (is.null(source$display_name)) {
          NA_character_
        } else {
          source$display_name
        }
        host_organization <- if (is.null(source$host_organization)) {
          NA_character_
        } else {
          source$host_organization
        }
        host_organization_name <- if (
          is.null(source$host_organization_name)
        ) {
          NA_character_
        } else {
          source$host_organization_name
        }

        topic <- work$primary_topic
        primary_topic_id <- if (is.null(topic$id)) {
          NA_character_
        } else {
          topic$id
        }
        primary_topic_name <- if (is.null(topic$display_name)) {
          NA_character_
        } else {
          topic$display_name
        }
        subfield_id <- if (is.null(topic$subfield$id)) {
          NA_character_
        } else {
          topic$subfield$id
        }
        field_id <- if (is.null(topic$field$id)) {
          NA_character_
        } else {
          topic$field$id
        }
        domain_id <- if (is.null(topic$domain$id)) {
          NA_character_
        } else {
          topic$domain$id
        }

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

        work_rows[[length(work_rows) + 1L]] <- data.frame(
          batch_id = batch_id,
          doi_canonical = normalize_doi(work$doi),
          openalex_work_id = if (is.null(work$id)) NA_character_ else work$id,
          openalex_title = if (is.null(work$title)) NA_character_ else work$title,
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
          n_authorships = n_authorships,
          n_unique_author_ids = length(unique(author_ids_present)),
          n_authors_with_id = length(author_ids_present),
          n_authorships_with_institution = sum(lengths(institution_lists) > 0L),
          n_institutions = length(institution_ids),
          n_countries = length(country_codes),
          all_authors_have_id = all_authors_have_id,
          all_authors_have_institution = all_authors_have_institution,
          all_authors_have_country = all_authors_have_country,
          confirmed_mainland = "CN" %in% country_codes,
          hmt_present = any(country_codes %in% c("HK", "MO", "TW")),
          hmt_only = !("CN" %in% country_codes) &&
            any(country_codes %in% c("HK", "MO", "TW")),
          source_present = !is.null(source),
          source_id = source_id,
          source_name = source_name,
          host_organization = host_organization,
          host_organization_name = host_organization_name,
          topic_present = !is.null(topic),
          primary_topic_id = primary_topic_id,
          primary_topic_name = primary_topic_name,
          subfield_id = subfield_id,
          field_id = field_id,
          domain_id = domain_id,
          funders_present = length(funder_ids) > 0L,
          awards_present = length(award_ids) > 0L,
          updated_date = if (is.null(work$updated_date)) {
            NA_character_
          } else {
            work$updated_date
          },
          cited_by_count = if (is.null(work$cited_by_count)) {
            NA_integer_
          } else {
            as.integer(work$cited_by_count)
          },
          country_codes = I(list(country_codes)),
          institution_ids = I(list(institution_ids)),
          funder_ids = I(list(funder_ids)),
          award_ids = I(list(award_ids)),
          stringsAsFactors = FALSE
        )

        if (n_authorships > 0) {
          author_rows[[length(author_rows) + 1L]] <- data.frame(
            batch_id = batch_id,
            doi_canonical = normalize_doi(work$doi),
            openalex_work_id = if (is.null(work$id)) {
              NA_character_
            } else {
              work$id
            },
            author_order = seq_len(n_authorships),
            author_id = author_ids,
            author_name = author_names,
            orcid = orcids,
            is_corresponding = corresponding,
            has_institution = lengths(institution_lists) > 0L,
            has_country = lengths(country_lists) > 0L,
            country_codes = I(country_lists),
            institution_ids = I(institution_lists),
            institution_names = I(institution_name_lists),
            raw_affiliation_strings = I(raw_affiliation_lists),
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }

  returned_works <- if (length(work_rows) == 0) {
    data.frame()
  } else {
    do.call(rbind, work_rows)
  }
  authorships_long <- if (length(author_rows) == 0) {
    data.frame()
  } else {
    do.call(rbind, author_rows)
  }

  requested_dois <- unique(request_audit$doi_canonical)
  candidate_requested <- candidate_panel[
    candidate_panel$doi_canonical %in% requested_dois,
    ,
    drop = FALSE
  ]

  match_counts <- if (nrow(returned_works) == 0) {
    data.frame(
      doi_canonical = character(),
      returned_work_count = integer(),
      stringsAsFactors = FALSE
    )
  } else {
    returned_works_with_doi <- returned_works[
      !is.na(returned_works$doi_canonical),
      ,
      drop = FALSE
    ]
    counts <- aggregate(
      returned_works_with_doi$openalex_work_id,
      list(doi_canonical = returned_works_with_doi$doi_canonical),
      length
    )
    names(counts)[[2]] <- "returned_work_count"
    counts
  }
  candidate_requested$returned_work_count <- 0L
  if (nrow(match_counts) > 0) {
    matched_counts <- match_counts$returned_work_count[
      match(candidate_requested$doi_canonical, match_counts$doi_canonical)
    ]
    matched_counts[is.na(matched_counts)] <- 0L
    candidate_requested$returned_work_count <- matched_counts
  }
  request_status <- request_audit[
    match(candidate_requested$doi_canonical, request_audit$doi_canonical),
  ]
  candidate_requested$openalex_http_status <- request_status$http_status
  candidate_requested$openalex_json_valid <- request_status$json_valid
  candidate_requested$match_status <- ifelse(
    request_status$http_status != 200L | !request_status$json_valid,
    "failed",
    ifelse(
      candidate_requested$returned_work_count == 0L,
      "not_found",
      ifelse(
        candidate_requested$returned_work_count == 1L,
        "exact",
        "multiple_exact"
      )
    )
  )

  work_join <- returned_works
  if (nrow(work_join) > 0) {
    work_join$paper_key <- candidate_panel$paper_key[
      match(work_join$doi_canonical, candidate_panel$doi_canonical)
    ]
    work_join$match_status <- candidate_requested$match_status[
      match(work_join$doi_canonical, candidate_requested$doi_canonical)
    ]
    authorships_long$paper_key <- candidate_panel$paper_key[
      match(authorships_long$doi_canonical, candidate_panel$doi_canonical)
    ]
    authorships_long$match_status <- candidate_requested$match_status[
      match(
        authorships_long$doi_canonical,
        candidate_requested$doi_canonical
      )
    ]
  }

  list(
    requested_panel = candidate_requested,
    works = work_join,
    authorships = authorships_long,
    request_audit = request_audit
  )
}
