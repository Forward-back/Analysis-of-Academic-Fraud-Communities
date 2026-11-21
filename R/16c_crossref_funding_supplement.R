#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

refresh <- "--refresh" %in% commandArgs(trailingOnly = TRUE)
sample <- utils::read.csv(
  file.path(audit_table_dir, "funding_audit_sample.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
assert_columns(
  sample,
  c(
    "audit_cluster_id",
    "paper_key",
    "doi_canonical",
    "funders_present",
    "awards_present",
    "any_funding_metadata"
  ),
  "funding audit sample"
)
if (anyDuplicated(sample$doi_canonical)) {
  stop("Funding audit sample DOIs must be unique.")
}

cache_root <- file.path(
  project_dir,
  project_config$paths$cache,
  "crossref",
  "funding-audit-v1",
  "works"
)
metadata_root <- file.path(cache_root, "metadata")
ensure_dir(cache_root)
ensure_dir(metadata_root)

request_audit_rows <- list()
paper_rows <- list()
funder_rows <- list()
award_rows <- list()
mailto <- Sys.getenv("CROSSREF_MAILTO")

for (index in seq_len(nrow(sample))) {
  doi <- sample$doi_canonical[[index]]
  doi_key <- doi_environment_key(doi)
  content_path <- file.path(cache_root, paste0(doi_key, ".json"))
  metadata_path <- file.path(
    metadata_root,
    paste0(doi_key, ".json")
  )

  if (refresh || !file.exists(content_path) || !file.exists(metadata_path)) {
    encoded_doi <- utils::URLencode(doi, reserved = TRUE)
    response <- NULL
    error_message <- ""
    for (attempt in seq_len(3L)) {
      response <- tryCatch(
        httr::GET(
          paste0("https://api.crossref.org/works/", encoded_doi),
          query = if (nzchar(mailto)) list(mailto = mailto) else list(),
          httr::user_agent("RetractionResourceNetwork/1.0")
        ),
        error = function(error) error
      )
      if (!inherits(response, "error")) {
        break
      }
      error_message <- conditionMessage(response)
      Sys.sleep(attempt)
    }
    if (inherits(response, "error")) {
      metadata <- list(
        doi = doi,
        http_status = NA_integer_,
        json_valid = FALSE,
        error = error_message,
        requested_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
      )
      writeLines("", content_path, useBytes = TRUE)
    } else {
      status <- httr::status_code(response)
      content_text <- httr::content(response, as = "text", encoding = "UTF-8")
      json_valid <- jsonlite::validate(content_text)
      metadata <- list(
        doi = doi,
        http_status = status,
        json_valid = json_valid,
        error = "",
        requested_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
      )
      writeLines(content_text, content_path, useBytes = TRUE)
    }
    jsonlite::write_json(
      metadata,
      metadata_path,
      auto_unbox = TRUE,
      pretty = TRUE
    )
    Sys.sleep(0.1)
  }

  metadata <- jsonlite::read_json(metadata_path, simplifyVector = FALSE)
  content_text <- paste(readLines(content_path, warn = FALSE), collapse = "\n")
  parsed <- if (
    isTRUE(metadata$json_valid) &&
      nzchar(content_text)
  ) {
    tryCatch(
      jsonlite::fromJSON(content_text, simplifyVector = FALSE),
      error = function(error) NULL
    )
  } else {
    NULL
  }
  funders <- parsed$message$funder
  if (is.null(funders)) {
    funders <- list()
  }

  funder_names <- character()
  funder_dois <- character()
  funder_pairs <- list()
  award_entries <- list()
  for (funder in funders) {
    funder_name <- if (is.null(funder$name)) "" else funder$name
    funder_doi <- if (is.null(funder$DOI)) "" else funder$DOI
    if (nzchar(funder_name)) {
      funder_names <- c(funder_names, funder_name)
    }
    if (nzchar(funder_doi)) {
      funder_dois <- c(funder_dois, funder_doi)
    }
    if (nzchar(funder_name) || nzchar(funder_doi)) {
      funder_pairs[[length(funder_pairs) + 1L]] <- data.frame(
        funder_name = funder_name,
        funder_doi = funder_doi,
        stringsAsFactors = FALSE
      )
    }
    awards <- unlist(funder$award, use.names = FALSE)
    awards <- unique(as.character(awards[!is.na(awards) & awards != ""]))
    if (length(awards) > 0L) {
      for (award in awards) {
        award_rows[[length(award_rows) + 1L]] <- data.frame(
          audit_cluster_id = sample$audit_cluster_id[[index]],
          paper_key = sample$paper_key[[index]],
          doi_canonical = doi,
          award_number = award,
          funder_name = funder_name,
          funder_doi = funder_doi,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  funder_names <- sort(unique(funder_names))
  funder_dois <- sort(unique(funder_dois))
  funder_pairs <- if (length(funder_pairs) > 0L) {
    unique(data.table::rbindlist(funder_pairs, fill = TRUE))
  } else {
    data.frame()
  }
  for (funder_index in seq_len(nrow(funder_pairs))) {
    funder_doi <- funder_pairs$funder_doi[[funder_index]]
    funder_name <- funder_pairs$funder_name[[funder_index]]
    funder_rows[[length(funder_rows) + 1L]] <- data.frame(
      audit_cluster_id = sample$audit_cluster_id[[index]],
      paper_key = sample$paper_key[[index]],
      doi_canonical = doi,
      funder_doi = funder_doi,
      funder_name = funder_name,
      funder_key = if (nzchar(funder_doi)) {
        funder_doi
      } else if (nzchar(funder_name)) {
        paste0("name:", funder_name)
      } else {
        NA_character_
      },
      stringsAsFactors = FALSE
    )
  }
  paper_rows[[length(paper_rows) + 1L]] <- data.frame(
    audit_cluster_id = sample$audit_cluster_id[[index]],
    paper_key = sample$paper_key[[index]],
    doi_canonical = doi,
    crossref_http_status = if (is.null(metadata$http_status)) {
      NA_integer_
    } else {
      as.integer(metadata$http_status)
    },
    crossref_json_valid = isTRUE(metadata$json_valid),
    crossref_funders_present = length(funder_dois) > 0L ||
      length(funder_names) > 0L,
    crossref_awards_present = length(award_entries) > 0L ||
      any(vapply(funders, function(funder) {
        length(funder$award) > 0L
      }, logical(1))),
    crossref_funder_count = nrow(funder_pairs),
    crossref_award_count = length(unique(unlist(
      lapply(funders, function(funder) funder$award),
      use.names = FALSE
    ))),
    crossref_funder_names = paste(funder_names, collapse = ";"),
    crossref_funder_dois = paste(funder_dois, collapse = ";"),
    stringsAsFactors = FALSE
  )
  request_audit_rows[[length(request_audit_rows) + 1L]] <- data.frame(
    doi_canonical = doi,
    http_status = if (is.null(metadata$http_status)) {
      NA_integer_
    } else {
      as.integer(metadata$http_status)
    },
    json_valid = isTRUE(metadata$json_valid),
    error = if (is.null(metadata$error)) "" else metadata$error,
    stringsAsFactors = FALSE
  )
  if (index %% 25L == 0L || index == nrow(sample)) {
    message("Crossref funding ", index, "/", nrow(sample))
  }
}

paper_metadata <- data.table::rbindlist(paper_rows, fill = TRUE)
paper_metadata <- as.data.frame(paper_metadata)
request_audit <- data.table::rbindlist(request_audit_rows, fill = TRUE)
funder_papers <- data.table::rbindlist(funder_rows, fill = TRUE)
award_papers <- data.table::rbindlist(award_rows, fill = TRUE)

if (nrow(funder_papers) > 0L) {
  funder_reuse <- data.table::as.data.table(funder_papers)[
    ,
    .(
      papers = data.table::uniqueN(paper_key),
      clusters = data.table::uniqueN(audit_cluster_id),
      funder_name = mode_nonmissing(funder_name),
      funder_doi = mode_nonmissing(funder_doi),
      cluster_ids = paste(
        sort(unique(audit_cluster_id)),
        collapse = ";"
      )
    ),
    by = funder_key
  ]
  funder_reuse <- as.data.frame(funder_reuse)
  funder_reuse <- funder_reuse[
    order(-funder_reuse$papers, -funder_reuse$clusters, funder_reuse$funder_doi),
    ,
    drop = FALSE
  ]
} else {
  funder_reuse <- data.frame()
}

if (nrow(award_papers) > 0L) {
  award_reuse <- data.table::as.data.table(award_papers)[
    ,
    .(
      papers = data.table::uniqueN(paper_key),
      clusters = data.table::uniqueN(audit_cluster_id),
      funder_names = paste(sort(unique(funder_name[
        !is.na(funder_name) & funder_name != ""
      ])), collapse = ";"),
      cluster_ids = paste(
        sort(unique(audit_cluster_id)),
        collapse = ";"
      )
    ),
    by = award_number
  ]
  award_reuse <- as.data.frame(award_reuse)
  award_reuse$reused_across_papers <- award_reuse$papers > 1L
  award_reuse$reused_across_clusters <- award_reuse$clusters > 1L
  award_reuse <- award_reuse[
    order(-award_reuse$papers, -award_reuse$clusters, award_reuse$award_number),
    ,
    drop = FALSE
  ]
} else {
  award_reuse <- data.frame()
}

combined <- merge(
  sample[, c(
    "audit_cluster_id",
    "paper_key",
    "doi_canonical",
    "funders_present",
    "awards_present",
    "any_funding_metadata"
  )],
  paper_metadata,
  by = c("audit_cluster_id", "paper_key", "doi_canonical"),
  all.x = TRUE,
  sort = FALSE
)
combined$crossref_funders_present[
  is.na(combined$crossref_funders_present)
] <- FALSE
combined$crossref_awards_present[
  is.na(combined$crossref_awards_present)
] <- FALSE
combined$combined_funders_present <-
  combined$funders_present %in% TRUE |
  combined$crossref_funders_present %in% TRUE
combined$combined_awards_present <-
  combined$awards_present %in% TRUE |
  combined$crossref_awards_present %in% TRUE
combined$combined_any_funding <-
  combined$any_funding_metadata %in% TRUE |
  combined$crossref_funders_present %in% TRUE |
  combined$crossref_awards_present %in% TRUE

combined_decision <- data.frame(
  decision_date = as.character(Sys.Date()),
  sampled_papers = nrow(combined),
  openalex_any_coverage = mean(combined$any_funding_metadata),
  crossref_funder_coverage = mean(combined$crossref_funders_present),
  crossref_award_coverage = mean(combined$crossref_awards_present),
  combined_funder_coverage = mean(combined$combined_funders_present),
  combined_award_coverage = mean(combined$combined_awards_present),
  combined_any_coverage = mean(combined$combined_any_funding),
  quality_gate = 0.50,
  final_disposition = if (mean(combined$combined_any_funding) < 0.50) {
    "appendix_only"
  } else {
    "eligible_for_main_analysis_pending_official_project_verification"
  },
  amount_audit = "pending_official_project_records",
  stringsAsFactors = FALSE
)

nsfc_papers <- if (nrow(funder_reuse) > 0L) {
  value <- funder_reuse$papers[
    funder_reuse$funder_doi == "10.13039/501100001809"
  ]
  if (length(value) == 0L) NA_integer_ else as.integer(value[[1]])
} else {
  NA_integer_
}
nsfc_clusters <- if (nrow(funder_reuse) > 0L) {
  value <- funder_reuse$clusters[
    funder_reuse$funder_doi == "10.13039/501100001809"
  ]
  if (length(value) == 0L) NA_integer_ else as.integer(value[[1]])
} else {
  NA_integer_
}
max_award_papers <- if (nrow(award_reuse) > 0L) {
  max(award_reuse$papers, na.rm = TRUE)
} else {
  NA_integer_
}
cross_cluster_awards <- if (nrow(award_reuse) > 0L) {
  sum(award_reuse$clusters > 1L)
} else {
  NA_integer_
}
funding_hypothesis_evidence <- data.frame(
  hypothesis = "H5",
  status = "exploratory_support_pending_official_project_verification",
  evidence = paste0(
    "Combined OpenAlex and Crossref funding coverage is ",
    sprintf("%.1f%%", 100 * mean(combined$combined_any_funding)),
    ". Crossref lists NSFC on ", nsfc_papers,
    " sampled papers across ", nsfc_clusters,
    " clusters, and the most repeated award number appears on ",
    max_award_papers,
    " papers. Crossref award numbers spanning more than one cluster: ",
    cross_cluster_awards,
    ".",
    " These are descriptive funding-composition overlaps, not ",
    "motive or risk estimates."
  ),
  stringsAsFactors = FALSE
)

project_verification_queue <- if (nrow(award_reuse) > 0L) {
  queue <- award_reuse[
    order(-award_reuse$papers, -award_reuse$clusters, award_reuse$award_number),
    ,
    drop = FALSE
  ]
  queue <- head(queue, 25L)
  data.frame(
    priority = seq_len(nrow(queue)),
    award_number = queue$award_number,
    papers_in_sample = queue$papers,
    clusters_in_sample = queue$clusters,
    funder_names = queue$funder_names,
    cluster_ids = queue$cluster_ids,
    verification_status = "pending",
    official_record_required = TRUE,
    amount_status = "not_verified",
    stringsAsFactors = FALSE
  )
} else {
  data.frame()
}

request_summary <- data.frame(
  metric = c(
    "requested_dois",
    "http_200",
    "http_404",
    "network_or_json_failures",
    "papers_with_crossref_funders",
    "papers_with_crossref_awards",
    "combined_any_funding_coverage"
  ),
  value = c(
    nrow(request_audit),
    sum(request_audit$http_status == 200L, na.rm = TRUE),
    sum(request_audit$http_status == 404L, na.rm = TRUE),
    sum(
      is.na(request_audit$http_status) |
        !request_audit$json_valid,
      na.rm = TRUE
    ),
    sum(paper_metadata$crossref_funders_present),
    sum(paper_metadata$crossref_awards_present),
    mean(combined$combined_any_funding)
  ),
  stringsAsFactors = FALSE
)

write_csv_utf8(
  paper_metadata,
  file.path(audit_table_dir, "funding_crossref_paper_metadata.csv")
)
write_csv_utf8(
  as.data.frame(request_audit),
  file.path(audit_table_dir, "funding_crossref_request_audit.csv")
)
write_csv_utf8(
  as.data.frame(funder_papers),
  file.path(audit_table_dir, "funding_crossref_funder_papers.csv")
)
write_csv_utf8(
  as.data.frame(award_papers),
  file.path(audit_table_dir, "funding_crossref_award_papers.csv")
)
write_csv_utf8(
  funder_reuse,
  file.path(audit_table_dir, "funding_crossref_funder_reuse.csv")
)
write_csv_utf8(
  award_reuse,
  file.path(audit_table_dir, "funding_crossref_award_reuse.csv")
)
write_csv_utf8(
  combined,
  file.path(audit_table_dir, "funding_combined_paper_metadata.csv")
)
write_csv_utf8(
  combined_decision,
  file.path(audit_table_dir, "funding_audit_combined_decision.csv")
)
write_csv_utf8(
  funding_hypothesis_evidence,
  file.path(audit_table_dir, "funding_hypothesis_evidence.csv")
)
write_csv_utf8(
  project_verification_queue,
  file.path(audit_table_dir, "funding_project_verification_queue.csv")
)
write_csv_utf8(
  request_summary,
  file.path(audit_table_dir, "funding_crossref_summary.csv")
)

write_audit_manifest()
message("Crossref funding supplement completed.")
