#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

args <- commandArgs(trailingOnly = TRUE)
refresh <- "--refresh" %in% args
top_journal_count <- 20L
years <- 2018:2025

normalize_journal_name <- function(value) {
  value <- tolower(trimws(value))
  value <- gsub("&", " and ", value, fixed = TRUE)
  value <- gsub("^the\\s+", "", value, perl = TRUE)
  value <- gsub("[^a-z0-9]+", " ", value, perl = TRUE)
  value <- gsub("\\band\\b", " ", value, perl = TRUE)
  trimws(gsub("\\s+", " ", value, perl = TRUE))
}

event_journal_path <- file.path(
  audit_table_dir,
  "event_2023_journal_top.csv"
)
if (!file.exists(event_journal_path)) {
  stop("Run R/13_event_2023.R first. Missing: ", event_journal_path)
}
top_journals <- utils::read.csv(
  event_journal_path,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
top_journals <- head(top_journals, top_journal_count)

case_panel <- readRDS(file.path(
  processed_dir,
  "p0",
  "openalex_mainland_accepted_paper_panel.rds"
))
panel_sources <- data.table::as.data.table(case_panel)[
  !is.na(source_id) & source_id != "",
  .(papers = .N),
  by = .(source_id, source_name)
]
panel_sources[, source_name_key := normalize_journal_name(source_name)]

openalex_cache_dir <- file.path(
  project_dir,
  "data",
  "cache",
  "openalex",
  "p0",
  "works-batches"
)
cache_files <- list.files(
  openalex_cache_dir,
  pattern = "\\.json$",
  full.names = TRUE
)
if (length(cache_files) == 0L) {
  stop("OpenAlex work cache is required to resolve ISSNs.")
}

target_names <- unique(normalize_journal_name(top_journals$journal))
source_lookup <- list()
for (path in cache_files) {
  payload <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(error) NULL
  )
  if (is.null(payload$results)) {
    next
  }
  for (work in payload$results) {
    source <- work$primary_location$source
    if (is.null(source$id) || is.null(source$display_name)) {
      next
    }
    source_name_key <- normalize_journal_name(source$display_name)
    if (!source_name_key %in% target_names) {
      next
    }
    if (is.null(source_lookup[[source$id]])) {
      source_lookup[[source$id]] <- list(
        source_id = source$id,
        source_name = source$display_name,
        issn_l = if (is.null(source$issn_l)) NA_character_ else source$issn_l,
        issns = if (is.null(source$issn)) {
          character()
        } else {
          unlist(source$issn, use.names = FALSE)
        }
      )
    }
  }
}

journal_identifiers <- data.table::rbindlist(lapply(
  seq_len(nrow(top_journals)),
  function(index) {
    journal <- top_journals[index, ]
    source_candidates <- panel_sources[
      source_name_key == normalize_journal_name(journal$journal)
    ]
    source_id <- if (nrow(source_candidates) == 0L) {
      NA_character_
    } else {
      source_candidates$source_id[
        which.max(source_candidates$papers)
      ]
    }
    source_record <- if (!is.na(source_id)) {
      source_lookup[[source_id]]
    } else {
      NULL
    }
    issn_l <- if (is.null(source_record$issn_l)) {
      NA_character_
    } else {
      source_record$issn_l
    }
    issns <- if (is.null(source_record$issns)) {
      character()
    } else {
      source_record$issns
    }
    issn_candidates <- unique(c(issn_l, issns))
    issn_candidates <- issn_candidates[
      !is.na(issn_candidates) & issn_candidates != ""
    ]
    data.frame(
      rank = journal$rank,
      journal = journal$journal,
      papers_2023 = journal$papers,
      publisher = journal$publisher,
      source_id = source_id,
      issn_l = issn_l,
      issns = paste(issns, collapse = ";"),
      issn_used = if (length(issn_candidates) > 0L) {
        issn_candidates[[1L]]
      } else {
        NA_character_
      },
      issn_candidates = paste(issn_candidates, collapse = ";"),
      stringsAsFactors = FALSE
    )
  }
), fill = TRUE)

crossref_cache_root <- file.path(
  project_dir,
  "data",
  "cache",
  "crossref",
  "event-2023",
  "journals"
)
ensure_dir(crossref_cache_root)

crossref_url <- function(issn, year) {
  paste0(
    "https://api.crossref.org/journals/",
    utils::URLencode(issn, reserved = TRUE),
    "/works?filter=from-pub-date:", year, "-01-01",
    ",until-pub-date:", year, "-12-31",
    "&rows=0"
  )
}

fetch_total <- function(url, raw_path, refresh = FALSE) {
  if (!refresh && file.exists(raw_path)) {
    payload <- tryCatch(
      jsonlite::fromJSON(raw_path, simplifyVector = FALSE),
      error = function(error) NULL
    )
    if (!is.null(payload$message$`total-results`)) {
      return(list(
        total_results = as.integer(payload$message$`total-results`),
        status = 200L,
        source = "cache"
      ))
    }
  }

  response <- NULL
  for (attempt in seq_len(3L)) {
    response <- tryCatch(
      httr::GET(
        url,
        httr::add_headers(
          `User-Agent` = "china-retraction-resource-network/1.0"
        ),
        httr::timeout(45)
      ),
      error = function(error) error
    )
    if (!inherits(response, "error") &&
        httr::status_code(response) == 200L) {
      break
    }
    Sys.sleep(attempt)
  }

  if (inherits(response, "error")) {
    return(list(
      total_results = NA_integer_,
      status = NA_integer_,
      source = "error",
      error = conditionMessage(response)
    ))
  }

  status <- as.integer(httr::status_code(response))
  text <- httr::content(response, as = "text", encoding = "UTF-8")
  if (status != 200L) {
    return(list(
      total_results = NA_integer_,
      status = status,
      source = "api",
      error = substr(text, 1L, 500L)
    ))
  }

  payload <- jsonlite::fromJSON(text, simplifyVector = FALSE)
  writeLines(text, raw_path, useBytes = TRUE)
  list(
    total_results = as.integer(payload$message$`total-results`),
    status = status,
    source = "api"
  )
}

for (index in seq_len(nrow(journal_identifiers))) {
  candidates <- strsplit(
    journal_identifiers$issn_candidates[[index]],
    ";",
    fixed = TRUE
  )[[1L]]
  candidates <- candidates[candidates != ""]
  if (length(candidates) <= 1L) {
    next
  }

  selected_issn <- journal_identifiers$issn_used[[index]]
  for (candidate in candidates) {
    safe_candidate <- gsub("[^0-9Xx-]", "_", candidate)
    candidate_dir <- file.path(crossref_cache_root, safe_candidate)
    ensure_dir(candidate_dir)
    candidate_path <- file.path(candidate_dir, "2023.json")
    candidate_result <- fetch_total(
      crossref_url(candidate, 2023L),
      candidate_path,
      refresh = refresh
    )
    if (!is.na(candidate_result$total_results) &&
        candidate_result$total_results > 0L) {
      selected_issn <- candidate
      break
    }
  }
  journal_identifiers$issn_used[[index]] <- selected_issn
}

write_csv_utf8(
  journal_identifiers,
  file.path(audit_table_dir, "event_2023_journal_identifiers.csv")
)

request_rows <- list()
request_index <- 0L
for (index in seq_len(nrow(journal_identifiers))) {
  journal <- journal_identifiers[index]
  if (is.na(journal$issn_used) || journal$issn_used == "") {
    for (year in years) {
      request_index <- request_index + 1L
      request_rows[[request_index]] <- data.frame(
        rank = journal$rank,
        journal = journal$journal,
        issn = NA_character_,
        year = year,
        total_results = NA_integer_,
        status = NA_integer_,
        source = "missing_issn",
        url = NA_character_,
        cache_path = NA_character_,
        stringsAsFactors = FALSE
      )
    }
    next
  }

  safe_issn <- gsub("[^0-9Xx-]", "_", journal$issn_used)
  journal_cache_dir <- file.path(crossref_cache_root, safe_issn)
  ensure_dir(journal_cache_dir)
  for (year in years) {
    url <- crossref_url(journal$issn_used, year)
    raw_path <- file.path(journal_cache_dir, paste0(year, ".json"))
    result <- fetch_total(url, raw_path, refresh = refresh)
    request_index <- request_index + 1L
    request_rows[[request_index]] <- data.frame(
      rank = journal$rank,
      journal = journal$journal,
      issn = journal$issn_used,
      year = year,
      total_results = result$total_results,
      status = result$status,
      source = result$source,
      url = url,
      cache_path = if (file.exists(raw_path)) {
        project_relative_path(raw_path)
      } else {
        NA_character_
      },
      stringsAsFactors = FALSE
    )
    if (result$source == "api") {
      Sys.sleep(0.1)
    }
  }
}

denominators <- data.table::rbindlist(request_rows, fill = TRUE)
write_csv_utf8(
  as.data.frame(denominators),
  file.path(audit_table_dir, "event_2023_journal_annual_denominators.csv")
)

coverage <- data.frame(
  metric = c(
    "journals_requested",
    "journals_with_issn",
    "journal_year_requests",
    "successful_year_counts",
    "missing_year_counts",
    "event_2023_papers_covered",
    "event_2023_papers_total"
  ),
  value = c(
    nrow(journal_identifiers),
    sum(!is.na(journal_identifiers$issn_used) &
      journal_identifiers$issn_used != ""),
    nrow(denominators),
    sum(!is.na(denominators$total_results)),
    sum(is.na(denominators$total_results)),
    sum(top_journals$papers[
      top_journals$rank %in% denominators$rank[
        denominators$year == 2023L &
          !is.na(denominators$total_results)
      ]
    ]),
    sum(as.integer(top_journals$papers))
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  coverage,
  file.path(audit_table_dir, "event_2023_crossref_coverage.csv")
)

top_journal_keys <- data.frame(
  rank = top_journals$rank,
  journal = top_journals$journal,
  journal_key = normalize_journal_name(top_journals$journal),
  stringsAsFactors = FALSE
)
event_original <- data.table::as.data.table(case_panel)[
  retraction_year_first == 2023L,
  .(
    event_papers = .N
  ),
  by = .(source_name, original_paper_year_first)
]
event_original[, journal_key := normalize_journal_name(source_name)]
event_original <- merge(
  event_original,
  top_journal_keys,
  by = "journal_key",
  all = FALSE,
  sort = FALSE
)
event_original <- event_original[, .(
  event_papers = sum(event_papers)
), by = .(rank, journal, original_paper_year_first)]

original_year_rates <- merge(
  denominators[, c(
    "rank",
    "year",
    "total_results",
    "status",
    "source"
  ), drop = FALSE],
  top_journals[, c("rank", "journal", "publisher"), drop = FALSE],
  by = "rank",
  all.x = TRUE,
  sort = FALSE
)
original_year_rates <- merge(
  original_year_rates,
  event_original,
  by.x = c("rank", "journal", "year"),
  by.y = c("rank", "journal", "original_paper_year_first"),
  all.x = TRUE,
  sort = FALSE
)
original_year_rates$event_papers[is.na(original_year_rates$event_papers)] <- 0L
original_year_rates$denominator <- as.numeric(original_year_rates$total_results)
original_year_rates$event_share_per_1000 <- ifelse(
  is.na(original_year_rates$denominator) |
    original_year_rates$denominator == 0,
  NA_real_,
  1000 * original_year_rates$event_papers / original_year_rates$denominator
)
original_year_rates <- original_year_rates[, c(
  "rank",
  "journal",
  "publisher",
  "year",
  "event_papers",
  "denominator",
  "event_share_per_1000",
  "status",
  "source"
)]
write_csv_utf8(
  original_year_rates,
  file.path(
    audit_table_dir,
    "event_2023_journal_original_year_rates.csv"
  )
)

legacy_rate_path <- file.path(
  audit_table_dir,
  "event_2023_journal_event_rates.csv"
)
if (file.exists(legacy_rate_path)) {
  unlink(legacy_rate_path)
}

write_audit_manifest()
message("Crossref journal denominator collection completed.")
