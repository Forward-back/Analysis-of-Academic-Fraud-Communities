#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/openalex_parse.R", encoding = "UTF-8")

input_path <- file.path(
  processed_dir,
  "p0",
  "china_candidate_panel.rds"
)
if (!file.exists(input_path)) {
  stop("Run R/04_screen_china.R first. Missing: ", input_path)
}

parse_args <- function(args) {
  values <- list(
    dry_run = FALSE,
    limit = NA_integer_,
    refresh = FALSE
  )
  for (arg in args) {
    if (arg == "--dry-run") {
      values$dry_run <- TRUE
    } else if (arg == "--refresh") {
      values$refresh <- TRUE
    } else if (startsWith(arg, "--limit=")) {
      values$limit <- as.integer(sub("^--limit=", "", arg))
    } else {
      stop("Unknown argument: ", arg)
    }
  }
  if (!is.na(values$limit) && values$limit < 1L) {
    stop("--limit must be a positive integer.")
  }
  values
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
panel <- readRDS(input_path)
dois <- sort(unique(panel$doi_canonical))

if (!is.na(args$limit)) {
  if (is.null(project_config$project$random_seed)) {
    stop("A fixed random seed is required for limited fetches.")
  }
  set.seed(as.integer(project_config$project$random_seed))
  dois <- sort(sample(dois, min(args$limit, length(dois))))
}

batch_size <- as.integer(project_config$api$openalex_batch_size)
if (is.na(batch_size) || batch_size < 1L || batch_size > 100L) {
  stop("openalex_batch_size must be between 1 and 100.")
}

batch_ids <- ceiling(seq_along(dois) / batch_size)
batches <- split(dois, batch_ids)
batch_plan <- data.frame(
  batch_id = sprintf("batch_%04d", seq_along(batches)),
  n_dois = lengths(batches),
  first_doi = vapply(batches, function(values) values[[1]], character(1)),
  last_doi = vapply(
    batches,
    function(values) values[[length(values)]],
    character(1)
  ),
  stringsAsFactors = FALSE
)

write_csv_utf8(
  batch_plan,
  file.path(audit_table_dir, "p0_openalex_batch_plan.csv")
)

cache_root <- file.path(
  project_config$paths$cache,
  "openalex",
  "p0",
  "works-batches"
)
cache_root <- file.path(project_dir, cache_root)
ensure_dir(cache_root)

meta_root <- file.path(cache_root, "metadata")
ensure_dir(meta_root)

if (args$dry_run) {
  dry_run_summary <- data.frame(
    metric = c(
      "candidate_dois",
      "batch_size",
      "planned_batches",
      "api_key_present"
    ),
    value = c(
      as.character(length(dois)),
      as.character(batch_size),
      as.character(length(batches)),
      as.character(!is.null(Sys.getenv("OPENALEX_API_KEY", unset = "")) &&
        nzchar(Sys.getenv("OPENALEX_API_KEY", unset = "")))
    ),
    stringsAsFactors = FALSE
  )
  write_csv_utf8(
    dry_run_summary,
    file.path(audit_table_dir, "p0_openalex_plan_summary.csv")
  )
  write_audit_manifest()
  message("OpenAlex dry run completed.")
  quit(save = "no", status = 0)
}

api_key <- Sys.getenv("OPENALEX_API_KEY", unset = "")
if (!nzchar(api_key)) {
  stop(
    "OPENALEX_API_KEY is not set. Use --dry-run to validate the request plan."
  )
}

openalex_select <- paste(
  c(
    "id",
    "doi",
    "title",
    "publication_year",
    "publication_date",
    "type",
    "is_retracted",
    "authorships",
    "primary_location",
    "primary_topic",
    "topics",
    "funders",
    "awards",
    "updated_date",
    "cited_by_count"
  ),
  collapse = ","
)

fetch_one_batch <- function(batch_id, doi_values) {
  response_path <- file.path(cache_root, paste0(batch_id, ".json"))
  meta_path <- file.path(meta_root, paste0(batch_id, ".json"))
  cache_matches_request <- FALSE
  if (file.exists(meta_path)) {
    cached_metadata <- tryCatch(
      jsonlite::read_json(meta_path, simplifyVector = FALSE),
      error = function(error) NULL
    )
    if (!is.null(cached_metadata)) {
      cached_dois <- normalize_doi(unlist(
        cached_metadata$requested_dois,
        use.names = FALSE
      ))
      cache_matches_request <- setequal(cached_dois, doi_values)
    }
  }
  cached <- file.exists(response_path) &&
    file.exists(meta_path) &&
    file.info(response_path)$size > 0 &&
    cache_matches_request

  if (cached && !args$refresh) {
    parsed <- tryCatch(
      jsonlite::read_json(response_path, simplifyVector = FALSE),
      error = function(error) NULL
    )
    if (!is.null(parsed)) {
      return(list(
        batch_id = batch_id,
        status = "cached",
        requested = length(doi_values),
        returned = length(parsed$results),
        http_status = 200L,
        error = ""
      ))
    }
  }

  query <- list(
    filter = paste0("doi:", paste(doi_values, collapse = "|")),
    per_page = length(doi_values),
    select = openalex_select,
    api_key = api_key
  )
  safe_query <- query
  safe_query$api_key <- "<redacted>"
  safe_url <- httr::modify_url(
    "https://api.openalex.org/works",
    query = safe_query
  )

  response <- tryCatch(
    httr::RETRY(
      "GET",
      "https://api.openalex.org/works",
      query = query,
      times = 4,
      pause_base = 2,
      pause_cap = 30,
      quiet = TRUE
    ),
    error = function(error) error
  )

  if (inherits(response, "error")) {
    status <- 0L
    body <- ""
    error_message <- conditionMessage(response)
  } else {
    status <- httr::status_code(response)
    body <- httr::content(response, as = "text", encoding = "UTF-8")
    error_message <- if (status == 200L) "" else substr(body, 1, 500)
  }

  json_valid <- FALSE
  returned <- 0L
  parse_error <- ""
  if (status == 200L) {
    writeLines(body, response_path, useBytes = TRUE)
    parsed_body <- parse_openalex_body(body)
    parse_error <- parsed_body$error
    json_valid <- parsed_body$json_valid
    if (json_valid) {
      returned <- length(parsed_body$parsed$results)
    }
  }

  meta <- list(
    batch_id = batch_id,
    requested_dois = doi_values,
    requested_count = length(doi_values),
    returned_count = returned,
    http_status = status,
    json_valid = json_valid,
    fetched_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    safe_url = safe_url,
    response_sha256 = if (file.exists(response_path)) {
      sha256_file(response_path)
    } else {
      ""
    },
    error = if (nzchar(parse_error)) parse_error else error_message
  )
  jsonlite::write_json(meta, meta_path, auto_unbox = TRUE, pretty = TRUE)

  list(
    batch_id = batch_id,
    status = if (json_valid) "fetched" else "failed",
    requested = length(doi_values),
    returned = returned,
    http_status = status,
    error = error_message
  )
}

results <- vector("list", length(batches))
for (index in seq_along(batches)) {
  results[[index]] <- fetch_one_batch(
    batch_plan$batch_id[[index]],
    batches[[index]]
  )
  message(
    batch_plan$batch_id[[index]],
    ": ",
    results[[index]]$status,
    " (",
    results[[index]]$returned,
    "/",
    results[[index]]$requested,
    ")"
  )
  Sys.sleep(0.2)
}

batch_results <- do.call(
  rbind,
  lapply(results, function(result) {
    data.frame(
      batch_id = result$batch_id,
      status = result$status,
      requested_dois = result$requested,
      returned_works = result$returned,
      http_status = result$http_status,
      error = result$error,
      stringsAsFactors = FALSE
    )
  })
)

write_csv_utf8(
  batch_results,
  file.path(audit_table_dir, "p0_openalex_fetch_batches.csv")
)

fetch_summary <- data.frame(
  metric = c(
    "requested_dois",
    "planned_batches",
    "successful_batches",
    "cached_batches",
    "failed_batches",
    "returned_works",
    "http_200_batches"
  ),
  value = c(
    length(dois),
    nrow(batch_results),
    sum(batch_results$status == "fetched"),
    sum(batch_results$status == "cached"),
    sum(batch_results$status == "failed"),
    sum(batch_results$returned_works),
    sum(batch_results$http_status == 200L)
  ),
  stringsAsFactors = FALSE
)

write_csv_utf8(
  fetch_summary,
  file.path(audit_table_dir, "p0_openalex_fetch_summary.csv")
)

write_audit_manifest()
message("OpenAlex fetch completed.")
