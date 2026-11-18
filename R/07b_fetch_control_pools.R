#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

parse_args <- function(args) {
  values <- list(limit = NA_integer_, refresh = FALSE, dry_run = FALSE)
  for (arg in args) {
    if (arg == "--refresh") {
      values$refresh <- TRUE
    } else if (arg == "--dry-run") {
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
layer_plan <- data.table::fread(
  file.path(audit_table_dir, "p1_control_layer_plan.csv"),
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
sample_plan <- data.table::fread(
  file.path(audit_table_dir, "p1_control_sample_plan.csv"),
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
layer_plan$publication_year <- as.integer(layer_plan$publication_year)
sample_plan$sample_batch <- as.integer(sample_plan$sample_batch)
sample_plan$sample_size <- as.integer(sample_plan$sample_size)
sample_plan$seed <- as.integer(sample_plan$seed)

sample_plan <- merge(
  sample_plan,
  layer_plan[
    ,
    c(
      "control_layer_id",
      "source_id",
      "publication_year",
      "openalex_type"
    ),
    drop = FALSE
  ],
  by = "control_layer_id",
  all.x = TRUE,
  sort = FALSE
)
sample_plan$request_id <- paste0(
  sample_plan$control_layer_id,
  "_sample_",
  sprintf("%02d", sample_plan$sample_batch)
)

cache_root <- file.path(
  project_dir,
  project_config$paths$cache,
  "openalex",
  "p1",
  "control-pools"
)
ensure_dir(cache_root)
sample_plan$cache_path <- file.path(
  cache_root,
  paste0(sample_plan$request_id, ".json")
)
ensure_dir(unique(dirname(sample_plan$cache_path)))

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
sample_plan$cached <- vapply(
  sample_plan$cache_path,
  cache_valid,
  logical(1)
)

pending <- sample_plan[
  args$refresh | !sample_plan$cached,
  ,
  drop = FALSE
]
if (!is.na(args$limit)) {
  pending <- head(pending, args$limit)
}

if (args$dry_run) {
  write_csv_utf8(
    data.frame(
      metric = c(
        "planned_requests",
        "cached_requests",
        "pending_requests",
        "selected_requests",
        "api_key_present"
      ),
      value = c(
        nrow(sample_plan),
        sum(sample_plan$cached),
        sum(!sample_plan$cached),
        nrow(pending),
        nzchar(Sys.getenv("OPENALEX_API_KEY", unset = ""))
      ),
      stringsAsFactors = FALSE
    ),
    file.path(audit_table_dir, "p1_control_fetch_plan_summary.csv")
  )
  write_audit_manifest()
  message("Control pool fetch dry run completed.")
  quit(save = "no", status = 0)
}

api_key <- Sys.getenv("OPENALEX_API_KEY", unset = "")
if (!nzchar(api_key)) {
  stop("OPENALEX_API_KEY is not set.")
}
if (nrow(pending) == 0L) {
  message("No pending control pool requests.")
  quit(save = "no", status = 0)
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
    "primary_location",
    "primary_topic"
  ),
  collapse = ","
)

make_request <- function(row) {
  filter <- paste(
    c(
      "authorships.countries:CN",
      "is_retracted:false",
      paste0("publication_year:", row$publication_year),
      paste0("type:", row$openalex_type),
      paste0("primary_location.source.id:", row$source_id)
    ),
    collapse = ","
  )
  httr2::request("https://api.openalex.org/works") |>
    httr2::req_url_query(
      filter = filter,
      sample = row$sample_size,
      seed = row$seed,
      per_page = row$sample_size,
      select = select_fields,
      api_key = api_key
    ) |>
    httr2::req_user_agent(
      "china-retraction-resource-network/1.0"
    ) |>
    httr2::req_retry(
      max_tries = 4,
      retry_on_failure = TRUE
    ) |>
    httr2::req_throttle(
      rate = 300,
      fill_time_s = 60,
      realm = "openalex-control-pools"
    )
}

chunk_size <- 80L
chunks <- split(
  seq_len(nrow(pending)),
  ceiling(seq_len(nrow(pending)) / chunk_size)
)

for (chunk_index in seq_along(chunks)) {
  indices <- chunks[[chunk_index]]
  chunk <- pending[indices, , drop = FALSE]
  requests <- lapply(seq_len(nrow(chunk)), function(index) {
    make_request(chunk[index, , drop = FALSE])
  })
  httr2::req_perform_parallel(
    requests,
    paths = chunk$cache_path,
    on_error = "return",
    progress = FALSE,
    max_active = 8
  )
  Sys.sleep(1)
  valid_now <- vapply(chunk$cache_path, cache_valid, logical(1))
  message(
    "chunk ",
    chunk_index,
    "/",
    length(chunks),
    ": ",
    sum(valid_now),
    "/",
    nrow(chunk),
    " valid"
  )
}

Sys.sleep(1)
sample_plan$cached <- vapply(
  sample_plan$cache_path,
  cache_valid,
  logical(1)
)
returned_counts <- vapply(
  seq_len(nrow(sample_plan)),
  function(index) {
    if (!sample_plan$cached[[index]]) {
      return(NA_integer_)
    }
    parsed <- jsonlite::read_json(
      sample_plan$cache_path[[index]],
      simplifyVector = FALSE
    )
    length(parsed$results)
  },
  integer(1)
)
batch_audit <- data.frame(
  control_layer_id = sample_plan$control_layer_id,
  sample_batch = sample_plan$sample_batch,
  requested_sample = sample_plan$sample_size,
  returned_works = returned_counts,
  cached = sample_plan$cached,
  stringsAsFactors = FALSE
)
write_csv_utf8(
  batch_audit,
  file.path(audit_table_dir, "p1_control_fetch_batches.csv")
)
write_csv_utf8(
  data.frame(
    metric = c(
      "planned_requests",
      "successful_requests",
      "not_yet_fetched_requests",
      "returned_candidate_works"
    ),
    value = c(
      nrow(sample_plan),
      sum(sample_plan$cached),
      sum(!sample_plan$cached),
      sum(returned_counts, na.rm = TRUE)
    ),
    stringsAsFactors = FALSE
  ),
  file.path(audit_table_dir, "p1_control_fetch_summary.csv")
)

write_audit_manifest()
message("Control pool fetch completed.")
