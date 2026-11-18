#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/openalex_parse.R", encoding = "UTF-8")

parse_args <- function(args) {
  values <- list(limit = NA_integer_, dry_run = FALSE)
  for (arg in args) {
    if (arg == "--dry-run") {
      values$dry_run <- TRUE
    } else if (startsWith(arg, "--limit=")) {
      values$limit <- as.integer(sub("^--limit=", "", arg))
    } else {
      stop("Unknown argument: ", arg)
    }
  }
  values
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
links <- readRDS(file.path(processed_dir, "p1", "control_links.rds"))
work_urls <- sort(unique(links$openalex_work_id))
work_ids <- sub("^https://openalex\\.org/", "", work_urls)

batch_size <- 100L
batch_ids <- ceiling(seq_along(work_ids) / batch_size)
batches <- split(work_ids, batch_ids)
plan <- data.frame(
  batch_id = sprintf("control_works_%04d", seq_along(batches)),
  n_works = lengths(batches),
  first_work = vapply(batches, function(values) values[[1]], character(1)),
  last_work = vapply(
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
  "selected-control-works"
)
metadata_root <- file.path(cache_root, "metadata")
ensure_dir(cache_root)
ensure_dir(metadata_root)
plan$cache_path <- file.path(
  cache_root,
  paste0(plan$batch_id, ".json")
)
plan$metadata_path <- file.path(
  metadata_root,
  paste0(plan$batch_id, ".json")
)

cache_valid <- function(path) {
  if (!file.exists(path) || file.info(path)$size == 0) {
    return(FALSE)
  }
  parsed <- tryCatch(
    jsonlite::read_json(path, simplifyVector = FALSE),
    error = function(error) NULL
  )
  !is.null(parsed) && !is.null(parsed$results)
}
cache_matches <- function(metadata_path, requested_ids) {
  if (!file.exists(metadata_path)) {
    return(FALSE)
  }
  metadata <- tryCatch(
    jsonlite::read_json(metadata_path, simplifyVector = FALSE),
    error = function(error) NULL
  )
  !is.null(metadata) &&
    setequal(
      unlist(metadata$requested_work_ids, use.names = FALSE),
      requested_ids
    )
}
plan$cached <- vapply(seq_len(nrow(plan)), function(index) {
  cache_valid(plan$cache_path[[index]]) &&
    cache_matches(plan$metadata_path[[index]], batches[[index]])
}, logical(1))

pending <- which(!plan$cached)
if (!is.na(args$limit)) {
  pending <- head(pending, args$limit)
}

if (args$dry_run) {
  write_csv_utf8(
    data.frame(
      metric = c(
        "selected_control_works",
        "planned_batches",
        "cached_batches",
        "pending_batches",
        "api_key_present"
      ),
      value = c(
        length(work_ids),
        nrow(plan),
        sum(plan$cached),
        length(pending),
        nzchar(Sys.getenv("OPENALEX_API_KEY", unset = ""))
      ),
      stringsAsFactors = FALSE
    ),
    file.path(audit_table_dir, "p1_selected_control_fetch_plan.csv")
  )
  write_audit_manifest()
  message("Selected control fetch dry run completed.")
  quit(save = "no", status = 0)
}

api_key <- Sys.getenv("OPENALEX_API_KEY", unset = "")
if (!nzchar(api_key)) {
  stop("OPENALEX_API_KEY is not set.")
}

select_fields <- paste(
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

make_request <- function(ids) {
  httr2::request("https://api.openalex.org/works") |>
    httr2::req_url_query(
      filter = paste0("ids.openalex:", paste(ids, collapse = "|")),
      per_page = length(ids),
      select = select_fields,
      api_key = api_key
    ) |>
    httr2::req_user_agent(
      "china-retraction-resource-network/1.0"
    ) |>
    httr2::req_retry(max_tries = 4, retry_on_failure = TRUE) |>
    httr2::req_throttle(
      rate = 300,
      fill_time_s = 60,
      realm = "openalex-selected-controls"
    )
}

chunks <- split(pending, ceiling(seq_along(pending) / 60L))
for (chunk_index in seq_along(chunks)) {
  indices <- chunks[[chunk_index]]
  requests <- lapply(indices, function(index) {
    make_request(batches[[index]])
  })
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
      jsonlite::read_json(
        plan$cache_path[[index]],
        simplifyVector = FALSE
      )
    } else {
      NULL
    }
    metadata <- list(
      batch_id = plan$batch_id[[index]],
      requested_work_ids = batches[[index]],
      requested_count = length(batches[[index]]),
      returned_count = if (is.null(parsed)) {
        0L
      } else {
        length(parsed$results)
      },
      response_sha256 = if (file.exists(plan$cache_path[[index]])) {
        sha256_file(plan$cache_path[[index]])
      } else {
        ""
      }
    )
    jsonlite::write_json(
      metadata,
      plan$metadata_path[[index]],
      auto_unbox = TRUE,
      pretty = TRUE
    )
  }
  message(
    "chunk ",
    chunk_index,
    "/",
    length(chunks),
    " completed"
  )
}

valid <- vapply(plan$cache_path, cache_valid, logical(1))
returned <- vapply(seq_len(nrow(plan)), function(index) {
  if (!valid[[index]]) return(NA_integer_)
  length(jsonlite::read_json(
    plan$cache_path[[index]],
    simplifyVector = FALSE
  )$results)
}, integer(1))
batch_audit <- data.frame(
  batch_id = plan$batch_id,
  requested_works = plan$n_works,
  returned_works = returned,
  cached = valid,
  stringsAsFactors = FALSE
)
write_csv_utf8(
  batch_audit,
  file.path(audit_table_dir, "p1_selected_control_batches.csv")
)
write_csv_utf8(
  data.frame(
    metric = c(
      "selected_control_works",
      "successful_batches",
      "failed_batches",
      "returned_works"
    ),
    value = c(
      length(work_ids),
      sum(valid),
      sum(!valid),
      sum(returned, na.rm = TRUE)
    ),
    stringsAsFactors = FALSE
  ),
  file.path(audit_table_dir, "p1_selected_control_fetch_summary.csv")
)

write_audit_manifest()
message("Selected control fetch completed.")
