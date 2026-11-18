#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/openalex_parse.R", encoding = "UTF-8")

input_path <- file.path(
  processed_dir,
  "p0",
  "mainland_authorships_long.rds"
)
if (!file.exists(input_path)) {
  stop("Run R/06_build_authorships.R first. Missing: ", input_path)
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
  values
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
authorships <- readRDS(input_path)
institution_urls <- sort(unique(unlist(
  authorships$institution_ids,
  use.names = FALSE
)))
institution_urls <- institution_urls[!is.na(institution_urls)]
institution_ids <- sub("^https://openalex\\.org/", "", institution_urls)

if (!is.na(args$limit)) {
  set.seed(as.integer(project_config$project$random_seed))
  institution_ids <- sort(sample(
    institution_ids,
    min(args$limit, length(institution_ids))
  ))
}

batch_size <- as.integer(project_config$api$openalex_batch_size)
batches <- split(
  institution_ids,
  ceiling(seq_along(institution_ids) / batch_size)
)
batch_plan <- data.frame(
  batch_id = sprintf("batch_%04d", seq_along(batches)),
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
write_csv_utf8(
  batch_plan,
  file.path(audit_table_dir, "p1_institution_batch_plan.csv")
)

cache_root <- file.path(
  project_dir,
  project_config$paths$cache,
  "openalex",
  "p1",
  "institutions-batches"
)
metadata_root <- file.path(cache_root, "metadata")
ensure_dir(cache_root)
ensure_dir(metadata_root)

if (args$dry_run) {
  write_csv_utf8(
    data.frame(
      metric = c(
        "institution_ids",
        "batch_size",
        "planned_batches",
        "api_key_present"
      ),
      value = c(
        length(institution_ids),
        batch_size,
        length(batches),
        nzchar(Sys.getenv("OPENALEX_API_KEY", unset = ""))
      ),
      stringsAsFactors = FALSE
    ),
    file.path(audit_table_dir, "p1_institution_plan_summary.csv")
  )
  write_audit_manifest()
  message("Institution fetch dry run completed.")
  quit(save = "no", status = 0)
}

api_key <- Sys.getenv("OPENALEX_API_KEY", unset = "")
if (!nzchar(api_key)) {
  stop("OPENALEX_API_KEY is not set.")
}

institution_select <- paste(
  c(
    "id",
    "ror",
    "display_name",
    "country_code",
    "type",
    "homepage_url",
    "image_url",
    "created_date",
    "updated_date",
    "works_count",
    "cited_by_count",
    "geo",
    "lineage",
    "associated_institutions"
  ),
  collapse = ","
)

fetch_batch <- function(batch_id, ids) {
  response_path <- file.path(cache_root, paste0(batch_id, ".json"))
  metadata_path <- file.path(metadata_root, paste0(batch_id, ".json"))

  cache_matches <- FALSE
  if (file.exists(metadata_path)) {
    metadata <- tryCatch(
      jsonlite::read_json(metadata_path, simplifyVector = FALSE),
      error = function(error) NULL
    )
    if (!is.null(metadata)) {
      cache_matches <- setequal(
        unlist(metadata$requested_institution_ids, use.names = FALSE),
        ids
      )
    }
  }
  cached <- file.exists(response_path) &&
    file.exists(metadata_path) &&
    file.info(response_path)$size > 0 &&
    cache_matches
  if (cached && !args$refresh) {
    parsed <- tryCatch(
      jsonlite::read_json(response_path, simplifyVector = FALSE),
      error = function(error) NULL
    )
    if (!is.null(parsed)) {
      return(list(
        batch_id = batch_id,
        status = "cached",
        requested = length(ids),
        returned = length(parsed$results),
        http_status = 200L,
        error = ""
      ))
    }
  }

  query <- list(
    filter = paste0("ids.openalex:", paste(ids, collapse = "|")),
    per_page = length(ids),
    select = institution_select,
    api_key = api_key
  )
  response <- tryCatch(
    httr::RETRY(
      "GET",
      "https://api.openalex.org/institutions",
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
    json_valid <- parsed_body$json_valid
    parse_error <- parsed_body$error
    if (json_valid) {
      returned <- length(parsed_body$parsed$results)
    }
  }

  metadata <- list(
    batch_id = batch_id,
    requested_institution_ids = ids,
    requested_count = length(ids),
    returned_count = returned,
    http_status = status,
    json_valid = json_valid,
    fetched_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    response_sha256 = if (file.exists(response_path)) {
      sha256_file(response_path)
    } else {
      ""
    },
    error = if (nzchar(parse_error)) parse_error else error_message
  )
  jsonlite::write_json(
    metadata,
    metadata_path,
    auto_unbox = TRUE,
    pretty = TRUE
  )

  list(
    batch_id = batch_id,
    status = if (json_valid) "fetched" else "failed",
    requested = length(ids),
    returned = returned,
    http_status = status,
    error = metadata$error
  )
}

results <- vector("list", length(batches))
for (index in seq_along(batches)) {
  results[[index]] <- fetch_batch(
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
      requested_institutions = result$requested,
      returned_institutions = result$returned,
      http_status = result$http_status,
      error = result$error,
      stringsAsFactors = FALSE
    )
  })
)
write_csv_utf8(
  batch_results,
  file.path(audit_table_dir, "p1_institution_fetch_batches.csv")
)
write_csv_utf8(
  data.frame(
    metric = c(
      "requested_institution_ids",
      "planned_batches",
      "successful_batches",
      "cached_batches",
      "failed_batches",
      "returned_institutions"
    ),
    value = c(
      length(institution_ids),
      nrow(batch_results),
      sum(batch_results$status == "fetched"),
      sum(batch_results$status == "cached"),
      sum(batch_results$status == "failed"),
      sum(batch_results$returned_institutions)
    ),
    stringsAsFactors = FALSE
  ),
  file.path(audit_table_dir, "p1_institution_fetch_summary.csv")
)

write_audit_manifest()
message("Institution fetch completed.")
