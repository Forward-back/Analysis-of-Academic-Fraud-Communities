#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

refresh <- "--refresh" %in% commandArgs(trailingOnly = TRUE)
funder_reuse <- utils::read.csv(
  file.path(audit_table_dir, "funding_audit_funder_reuse.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
if (nrow(funder_reuse) == 0L) {
  stop("Funding funder reuse table is empty.")
}

openalex_ids <- sub("^https://openalex.org/", "", funder_reuse$funder_id)
cache_root <- file.path(
  project_dir,
  project_config$paths$cache,
  "openalex",
  "funders",
  "funding-audit-v1"
)
ensure_dir(cache_root)
batch_size <- 25L
batches <- split(
  openalex_ids,
  ceiling(seq_along(openalex_ids) / batch_size)
)

metadata_rows <- list()
request_rows <- list()
for (batch_index in seq_along(batches)) {
  batch_ids <- batches[[batch_index]]
  batch_id <- sprintf("funders_%03d", batch_index)
  response_path <- file.path(cache_root, paste0(batch_id, ".json"))
  metadata_path <- file.path(
    cache_root,
    "metadata",
    paste0(batch_id, ".json")
  )
  ensure_dir(dirname(metadata_path))

  if (refresh || !file.exists(response_path) || !file.exists(metadata_path)) {
    query <- list(
      filter = paste0("ids.openalex:", paste(batch_ids, collapse = "|")),
      select = paste(
        c(
          "id",
          "display_name",
          "country_code",
          "homepage_url",
          "ids",
          "awards_count",
          "works_count"
        ),
        collapse = ","
      ),
      per_page = 100L
    )
    api_key <- Sys.getenv("OPENALEX_API_KEY")
    if (nzchar(api_key)) {
      query$api_key <- api_key
    }
    response <- httr::GET(
      "https://api.openalex.org/funders",
      query = query,
      httr::user_agent("RetractionResourceNetwork/1.0")
    )
    status <- httr::status_code(response)
    content_text <- httr::content(response, as = "text", encoding = "UTF-8")
    json_valid <- jsonlite::validate(content_text)
    metadata <- list(
      batch_id = batch_id,
      requested_ids = batch_ids,
      http_status = status,
      json_valid = json_valid,
      requested_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    )
    if (status != 200L || !json_valid) {
      stop(
        "OpenAlex funder request failed for ",
        batch_id,
        ": status ",
        status
      )
    }
    writeLines(content_text, response_path, useBytes = TRUE)
    jsonlite::write_json(
      metadata,
      metadata_path,
      auto_unbox = TRUE,
      pretty = TRUE
    )
  }

  response <- jsonlite::read_json(response_path, simplifyVector = FALSE)
  results <- response$results
  if (is.null(results) || length(results) == 0L) {
    next
  }
  for (funder in results) {
    metadata_rows[[length(metadata_rows) + 1L]] <- data.frame(
      funder_id = if (is.null(funder$id)) NA_character_ else funder$id,
      funder_name = if (is.null(funder$display_name)) {
        NA_character_
      } else {
        funder$display_name
      },
      country_code = if (is.null(funder$country_code)) {
        NA_character_
      } else {
        funder$country_code
      },
      homepage_url = if (is.null(funder$homepage_url)) {
        NA_character_
      } else {
        funder$homepage_url
      },
      crossref_funder_id = if (
        is.null(funder$ids$crossref)
      ) {
        NA_character_
      } else {
        funder$ids$crossref
      },
      funder_doi = if (is.null(funder$ids$doi)) {
        NA_character_
      } else {
        funder$ids$doi
      },
      works_count = if (is.null(funder$works_count)) {
        NA_integer_
      } else {
        as.integer(funder$works_count)
      },
      awards_count = if (is.null(funder$awards_count)) {
        NA_integer_
      } else {
        as.integer(funder$awards_count)
      },
      stringsAsFactors = FALSE
    )
  }
  request_rows[[length(request_rows) + 1L]] <- data.frame(
    batch_id = batch_id,
    requested_funders = length(batch_ids),
    returned_funders = length(results),
    response_path = batch_id,
    stringsAsFactors = FALSE
  )
}

funder_metadata <- data.table::rbindlist(metadata_rows, fill = TRUE)
funder_metadata <- as.data.frame(funder_metadata)
if (anyDuplicated(funder_metadata$funder_id)) {
  funder_metadata <- funder_metadata[
    !duplicated(funder_metadata$funder_id),
    ,
    drop = FALSE
  ]
}
funder_reuse_named <- merge(
  funder_reuse,
  funder_metadata,
  by = "funder_id",
  all.x = TRUE,
  sort = FALSE
)
funder_reuse_named <- funder_reuse_named[
  order(
    -funder_reuse_named$papers,
    -funder_reuse_named$clusters,
    funder_reuse_named$funder_id
  ),
  ,
  drop = FALSE
]

request_audit <- data.table::rbindlist(request_rows, fill = TRUE)
summary <- data.frame(
  metric = c(
    "requested_funders",
    "returned_funders",
    "unmatched_funders",
    "requests",
    "cache_directory"
  ),
  value = c(
    length(openalex_ids),
    nrow(funder_metadata),
    length(setdiff(openalex_ids, sub(
      "^https://openalex.org/",
      "",
      funder_metadata$funder_id
    ))),
    nrow(request_audit),
    project_relative_path(cache_root)
  ),
  stringsAsFactors = FALSE
)

write_csv_utf8(
  funder_metadata,
  file.path(audit_table_dir, "funding_funder_metadata.csv")
)
write_csv_utf8(
  funder_reuse_named,
  file.path(audit_table_dir, "funding_funder_reuse_named.csv")
)
write_csv_utf8(
  as.data.frame(request_audit),
  file.path(audit_table_dir, "funding_funder_request_audit.csv")
)
write_csv_utf8(
  summary,
  file.path(audit_table_dir, "funding_funder_metadata_summary.csv")
)

write_audit_manifest()
message("OpenAlex funder metadata completed.")
