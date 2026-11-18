#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/openalex_parse.R", encoding = "UTF-8")

mainland_authorships <- readRDS(file.path(
  processed_dir,
  "p0",
  "mainland_authorships_long.rds"
))
control_authorships <- readRDS(file.path(
  processed_dir,
  "p1",
  "control_authorships_long.rds"
))
existing <- readRDS(file.path(
  processed_dir,
  "p1",
  "openalex_institutions.rds"
))

required_urls <- unique(c(
  unlist(mainland_authorships$institution_ids, use.names = FALSE),
  unlist(control_authorships$institution_ids, use.names = FALSE)
))
required_urls <- required_urls[!is.na(required_urls)]
missing_urls <- setdiff(required_urls, existing$institution_id)
missing_ids <- sub("^https://openalex\\.org/", "", missing_urls)
missing_ids <- sort(missing_ids)

batches <- split(
  missing_ids,
  ceiling(seq_along(missing_ids) / 100L)
)
plan <- data.frame(
  batch_id = sprintf("control_institutions_%04d", seq_along(batches)),
  n_institutions = lengths(batches),
  first_institution = vapply(
    batches,
    function(values) values[[1]],
    character(1)
  ),
  last_institution = vapply(
    batches,
    function(values) values[[length(values)]],
    character(1)
  ),
  stringsAsFactors = FALSE
)

cache_root <- file.path(
  project_dir,
  project_config$paths$cache,
  "openalex",
  "p1",
  "control-institutions"
)
metadata_root <- file.path(cache_root, "metadata")
ensure_dir(cache_root)
ensure_dir(metadata_root)
plan$cache_path <- file.path(cache_root, paste0(plan$batch_id, ".json"))
plan$metadata_path <- file.path(
  metadata_root,
  paste0(plan$batch_id, ".json")
)

cache_valid <- function(path) {
  if (!file.exists(path) || file.info(path)$size == 0) return(FALSE)
  parsed <- tryCatch(
    jsonlite::read_json(path, simplifyVector = FALSE),
    error = function(error) NULL
  )
  !is.null(parsed) && !is.null(parsed$results)
}
cache_matches <- function(path, ids) {
  if (!file.exists(path)) return(FALSE)
  metadata <- tryCatch(
    jsonlite::read_json(path, simplifyVector = FALSE),
    error = function(error) NULL
  )
  !is.null(metadata) &&
    setequal(
      unlist(metadata$requested_institution_ids, use.names = FALSE),
      ids
    )
}
plan$cached <- vapply(seq_len(nrow(plan)), function(index) {
  cache_valid(plan$cache_path[[index]]) &&
    cache_matches(plan$metadata_path[[index]], batches[[index]])
}, logical(1))

pending <- which(!plan$cached)
if (length(pending) > 0L) {
  api_key <- Sys.getenv("OPENALEX_API_KEY", unset = "")
  if (!nzchar(api_key)) stop("OPENALEX_API_KEY is not set.")
  select_fields <- paste(
    c(
      "id","ror","display_name","country_code","type",
      "homepage_url","created_date","updated_date","works_count",
      "cited_by_count","geo","lineage","associated_institutions"
    ),
    collapse = ","
  )
  make_request <- function(ids) {
    httr2::request("https://api.openalex.org/institutions") |>
      httr2::req_url_query(
        filter = paste0("ids.openalex:", paste(ids, collapse = "|")),
        per_page = length(ids),
        select = select_fields,
        api_key = api_key
      ) |>
      httr2::req_retry(max_tries = 4, retry_on_failure = TRUE) |>
      httr2::req_throttle(
        rate = 300,
        fill_time_s = 60,
        realm = "openalex-control-institutions"
      )
  }
  chunks <- split(pending, ceiling(seq_along(pending) / 30L))
  for (chunk_index in seq_along(chunks)) {
    indices <- chunks[[chunk_index]]
    requests <- lapply(indices, function(index) make_request(batches[[index]]))
    httr2::req_perform_parallel(
      requests,
      paths = plan$cache_path[indices],
      on_error = "return",
      progress = FALSE,
      max_active = 8
    )
    Sys.sleep(1)
    for (index in indices) {
      parsed <- if (cache_valid(plan$cache_path[[index]])) {
        jsonlite::read_json(plan$cache_path[[index]], simplifyVector = FALSE)
      } else {
        NULL
      }
      metadata <- list(
        batch_id = plan$batch_id[[index]],
        requested_institution_ids = batches[[index]],
        requested_count = length(batches[[index]]),
        returned_count = if (is.null(parsed)) 0L else length(parsed$results),
        response_sha256 = if (file.exists(plan$cache_path[[index]])) {
          sha256_file(plan$cache_path[[index]])
        } else ""
      )
      jsonlite::write_json(
        metadata,
        plan$metadata_path[[index]],
        auto_unbox = TRUE,
        pretty = TRUE
      )
    }
    message("chunk ", chunk_index, "/", length(chunks))
  }
}

valid <- vapply(plan$cache_path, cache_valid, logical(1))
returned <- vapply(seq_len(nrow(plan)), function(index) {
  if (!valid[[index]]) return(NA_integer_)
  length(jsonlite::read_json(
    plan$cache_path[[index]],
    simplifyVector = FALSE
  )$results)
}, integer(1))
write_csv_utf8(
  data.frame(
    batch_id = plan$batch_id,
    requested_institutions = plan$n_institutions,
    returned_institutions = returned,
    cached = valid,
    stringsAsFactors = FALSE
  ),
  file.path(audit_table_dir, "p1_control_institution_batches.csv")
)
write_csv_utf8(
  data.frame(
    metric = c(
      "required_institutions",
      "existing_institutions",
      "missing_institution_ids",
      "planned_batches",
      "successful_batches",
      "returned_institutions"
    ),
    value = c(
      length(required_urls),
      nrow(existing),
      length(missing_ids),
      nrow(plan),
      sum(valid),
      sum(returned, na.rm = TRUE)
    ),
    stringsAsFactors = FALSE
  ),
  file.path(audit_table_dir, "p1_control_institution_fetch_summary.csv")
)

write_audit_manifest()
message("Control institution fetch completed.")
