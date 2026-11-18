#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

interim_path <- file.path(interim_dir, "p0", "rwdb_records.rds")
if (!file.exists(interim_path)) {
  stop("Run R/01_ingest_rwdb.R first. Missing: ", interim_path)
}

records <- readRDS(interim_path)
core <- records[records$in_core_window & !is.na(records$doi_canonical), ]

if (nrow(core) == 0) {
  stop("No core retraction records with a valid DOI.")
}

title_identity <- ifelse(
  is.na(core$title_normalized),
  "<missing-title>",
  core$title_normalized
)
core <- core[
  order(core$doi_canonical, title_identity, core$record_id),
  ,
  drop = FALSE
]
title_identity <- ifelse(
  is.na(core$title_normalized),
  "<missing-title>",
  core$title_normalized
)
identity <- paste(core$doi_canonical, title_identity, sep = "|")
core$paper_key <- sprintf(
  "paper_%06d",
  match(identity, unique(identity))
)

doi_title_counts <- stats::aggregate(
  title_identity,
  list(doi = core$doi_canonical),
  function(values) length(unique(values))
)
names(doi_title_counts)[[2]] <- "unique_title_count"

doi_record_counts <- stats::aggregate(
  core$record_id,
  list(doi = core$doi_canonical),
  length
)
names(doi_record_counts)[[2]] <- "notification_record_count"

doi_identity <- merge(
  doi_title_counts,
  doi_record_counts,
  by = "doi",
  sort = FALSE
)
doi_identity$doi_status <- ifelse(
  doi_identity$unique_title_count == 1L,
  "linkable",
  "ambiguous_doi"
)

core$doi_status <- doi_identity$doi_status[
  match(core$doi_canonical, doi_identity$doi)
]
core$doi_unique_title_count <- doi_identity$unique_title_count[
  match(core$doi_canonical, doi_identity$doi)
]

core_dt <- data.table::as.data.table(core)
paper_panel_dt <- core_dt[
  order(doi_canonical, title_normalized, retraction_date, record_id),
  {
    retraction_dates <- retraction_date[!is.na(retraction_date)]
    original_dates <- original_paper_date[!is.na(original_paper_date)]
    .(
      paper_key = paper_key[[1]],
      doi_status = doi_status[[1]],
      doi_unique_title_count = doi_unique_title_count[[1]],
      title = title[
        which(!is.na(title))[1]
      ],
      journal = tail(
        journal[!is.na(journal) & journal != ""],
        1
      ),
      publisher = tail(
        publisher[!is.na(publisher) & publisher != ""],
        1
      ),
      article_type = mode_nonmissing(
        unlist(article_types, use.names = FALSE)
      ),
      retraction_first_date = if (length(retraction_dates) > 0) {
        min(retraction_dates)
      } else {
        as.Date(NA)
      },
      retraction_last_date = if (length(retraction_dates) > 0) {
        max(retraction_dates)
      } else {
        as.Date(NA)
      },
      retraction_year_first = if (length(retraction_dates) > 0) {
        as.integer(format(min(retraction_dates), "%Y"))
      } else {
        NA_integer_
      },
      original_paper_date_first = if (length(original_dates) > 0) {
        min(original_dates)
      } else {
        as.Date(NA)
      },
      original_paper_year_first = if (length(original_dates) > 0) {
        as.integer(format(min(original_dates), "%Y"))
      } else {
        NA_integer_
      },
      n_notification_records = .N,
      n_unique_journals = length(unique(
        journal[!is.na(journal) & journal != ""]
      )),
      country_candidate_mainland = any(
        unlist(country_labels, use.names = FALSE) == "China"
      ),
      rwdb_record_ids = list(sort(unique(record_id))),
      reason_labels = list(concat_values(reason_labels)),
      country_labels = list(concat_values(country_labels)),
      article_types = list(concat_values(article_types)),
      subjects = list(concat_values(subjects)),
      authors_raw = list(concat_values(authors_raw)),
      institutions_raw = list(concat_values(institutions_raw)),
      record_titles = list(sort(unique(title[!is.na(title)])))
    )
  },
  by = .(doi_canonical, title_normalized)
]

paper_panel <- as.data.frame(paper_panel_dt)
paper_panel$n_unique_titles <- 1L
paper_panel <- paper_panel[
  order(paper_panel$doi_canonical, paper_panel$title_normalized),
  ,
  drop = FALSE
]

linkable_panel <- paper_panel[paper_panel$doi_status == "linkable", , drop = FALSE]

if (anyDuplicated(linkable_panel$doi_canonical) > 0) {
  stop("Linkable panel still contains duplicate DOI values.")
}

processed_p0_dir <- file.path(processed_dir, "p0")
ensure_dir(processed_p0_dir)
saveRDS(
  paper_panel,
  file.path(processed_p0_dir, "paper_panel_descriptive.rds")
)
saveRDS(
  linkable_panel,
  file.path(processed_p0_dir, "paper_panel_linkable.rds")
)

ambiguous <- doi_identity[doi_identity$doi_status == "ambiguous_doi", ]
ambiguous_records <- core[core$doi_status == "ambiguous_doi", ]
ambiguous_audit <- if (nrow(ambiguous) == 0) {
  data.frame(
    doi_canonical = character(),
    notification_records = integer(),
    unique_titles = integer(),
    first_retraction_date = as.Date(character()),
    last_retraction_date = as.Date(character()),
    title_examples = character(),
    stringsAsFactors = FALSE
  )
} else {
  rows <- lapply(seq_len(nrow(ambiguous)), function(index) {
    doi <- ambiguous$doi[[index]]
    block <- ambiguous_records[ambiguous_records$doi_canonical == doi, ]
    data.frame(
      doi_canonical = doi,
      notification_records = nrow(block),
      unique_titles = length(unique(block$title_normalized)),
      first_retraction_date = min(block$retraction_date, na.rm = TRUE),
      last_retraction_date = max(block$retraction_date, na.rm = TRUE),
      title_examples = paste(
        head(sort(unique(block$title)), 3),
        collapse = " | "
      ),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

write_csv_utf8(
  ambiguous_audit,
  file.path(audit_table_dir, "p0_doi_collision_audit.csv")
)

duplicate_dois <- doi_identity[doi_identity$notification_record_count > 1, ]
duplicate_audit <- data.frame(
  doi_canonical = duplicate_dois$doi,
  notification_records = duplicate_dois$notification_record_count,
  unique_titles = duplicate_dois$unique_title_count,
  doi_status = duplicate_dois$doi_status,
  stringsAsFactors = FALSE
)
write_csv_utf8(
  duplicate_audit,
  file.path(audit_table_dir, "p0_duplicate_doi_audit.csv")
)

fold_summary <- data.frame(
  metric = c(
    "core_valid_doi_records",
    "unique_valid_dois",
    "descriptive_papers",
    "linkable_papers",
    "linkable_records",
    "ambiguous_doi_groups",
    "ambiguous_doi_records",
    "ambiguous_title_papers",
    "duplicate_doi_groups",
    "same_title_duplicate_groups",
    "same_title_extra_records_collapsed",
    "records_excluded_from_linkable_panel",
    "missing_title_records"
  ),
  value = c(
    nrow(core),
    nrow(doi_identity),
    nrow(paper_panel),
    nrow(linkable_panel),
    sum(linkable_panel$n_notification_records),
    nrow(ambiguous),
    sum(ambiguous$notification_record_count),
    nrow(paper_panel) - nrow(linkable_panel),
    nrow(duplicate_dois),
    sum(duplicate_dois$unique_title_count == 1L),
    sum(
      duplicate_dois$notification_record_count[
        duplicate_dois$unique_title_count == 1L
      ] - 1L
    ),
    nrow(core) - sum(linkable_panel$n_notification_records),
    sum(is.na(core$title_normalized))
  ),
  stringsAsFactors = FALSE
)

write_csv_utf8(
  fold_summary,
  file.path(audit_table_dir, "p0_doi_fold_summary.csv")
)

write_audit_manifest()
message("P0 DOI panel completed.")
