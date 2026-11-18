#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

required_rwdb_fields <- c(
  "Record ID",
  "Title",
  "Subject",
  "Institution",
  "Journal",
  "Publisher",
  "Country",
  "Author",
  "URLS",
  "ArticleType",
  "RetractionDate",
  "RetractionDOI",
  "RetractionPubMedID",
  "OriginalPaperDate",
  "OriginalPaperDOI",
  "OriginalPaperPubMedID",
  "RetractionNature",
  "Reason",
  "Paywalled",
  "Notes"
)

raw_file <- file.path(project_dir, project_config$paths$raw)
if (!file.exists(raw_file)) {
  stop("Raw file not found: ", raw_file)
}

raw <- data.table::fread(
  raw_file,
  colClasses = "character",
  check.names = FALSE,
  encoding = "UTF-8",
  data.table = FALSE
)

assert_columns(raw, required_rwdb_fields, "Retraction Watch CSV")

empty_columns <- names(raw)[names(raw) == "" | grepl("^V[0-9]+$", names(raw))]
if (length(empty_columns) > 0) {
  raw <- raw[, !names(raw) %in% empty_columns, drop = FALSE]
}

standard <- raw[, required_rwdb_fields, drop = FALSE]
names(standard) <- c(
  "record_id",
  "title",
  "subject_raw",
  "institution_raw",
  "journal",
  "publisher",
  "country_raw",
  "author_raw",
  "urls",
  "article_type_raw",
  "retraction_date_raw",
  "retraction_doi_raw",
  "retraction_pubmed_id",
  "original_paper_date_raw",
  "original_paper_doi_raw",
  "original_paper_pubmed_id",
  "retraction_nature",
  "reason_raw",
  "paywalled",
  "notes"
)

standard$record_id <- stringr::str_trim(standard$record_id)
standard$retraction_date <- parse_rwdb_date(standard$retraction_date_raw)
standard$original_paper_date <- parse_rwdb_date(
  standard$original_paper_date_raw
)
standard$retraction_year <- as.integer(format(standard$retraction_date, "%Y"))
standard$original_paper_year <- as.integer(
  format(standard$original_paper_date, "%Y")
)
standard$doi_canonical <- normalize_doi(standard$original_paper_doi_raw)
standard$title_normalized <- normalize_title(standard$title)
standard$reason_labels <- split_semicolon(standard$reason_raw)
standard$country_labels <- split_semicolon(standard$country_raw)
standard$article_types <- split_semicolon(standard$article_type_raw)
standard$subjects <- split_semicolon(standard$subject_raw)
standard$authors_raw <- split_semicolon(standard$author_raw)
standard$institutions_raw <- split_semicolon(standard$institution_raw)

if (anyDuplicated(standard$record_id) > 0) {
  stop("Record ID is not unique in the raw Retraction Watch file.")
}

core_start <- as.integer(project_config$sample$retraction_year_start)
core_end <- as.integer(project_config$sample$retraction_year_end)
standard$in_core_window <- standard$retraction_nature == "Retraction" &
  !is.na(standard$retraction_year) &
  standard$retraction_year >= core_start &
  standard$retraction_year <= core_end

interim_path <- file.path(interim_dir, "p0", "rwdb_records.rds")
ensure_dir(dirname(interim_path))
saveRDS(standard, interim_path)

ingest_summary <- data.frame(
  metric = c(
    "source_bytes",
    "source_sha256",
    "notification_records",
    "unique_record_ids",
    "retraction_records",
    "core_window_start",
    "core_window_end",
    "core_retraction_records",
    "core_valid_doi_records",
    "retraction_date_missing",
    "original_paper_date_missing",
    "core_title_missing"
  ),
  value = c(
    as.character(file.info(raw_file)$size),
    sha256_file(raw_file),
    as.character(nrow(standard)),
    as.character(length(unique(standard$record_id))),
    as.character(sum(standard$retraction_nature == "Retraction")),
    as.character(core_start),
    as.character(core_end),
    as.character(sum(standard$in_core_window)),
    as.character(sum(standard$in_core_window & !is.na(standard$doi_canonical))),
    as.character(sum(is.na(standard$retraction_date))),
    as.character(sum(is.na(standard$original_paper_date))),
    as.character(sum(standard$in_core_window & is.na(standard$title_normalized)))
  ),
  stringsAsFactors = FALSE
)

write_csv_utf8(
  ingest_summary,
  file.path(audit_table_dir, "p0_ingest_summary.csv")
)

field_audit <- data.frame(
  field = names(standard),
  is_list = vapply(standard, is.list, logical(1)),
  missing_records = vapply(
    standard,
    function(values) {
      if (is.list(values)) {
        return(sum(vapply(values, length, integer(1)) == 0))
      }
      sum(is.na(values) | values == "")
    },
    integer(1)
  ),
  stringsAsFactors = FALSE
)
field_audit$missing_share <- field_audit$missing_records / nrow(standard)

write_csv_utf8(
  field_audit,
  file.path(audit_table_dir, "p0_ingest_field_audit.csv")
)

write_audit_manifest()
message("P0 ingest completed.")
