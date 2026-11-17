#!/usr/bin/env Rscript

# Read-only diagnostics for the reviewed v2 reason taxonomy.
# Run through scripts/run_in_ascii_stage.ps1 -IncludeOutputs.

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(tidyr)
  library(stringr)
})

parse_us_date <- function(x) {
  clean <- str_trim(x)
  clean <- str_replace(clean, "\\s+\\d{1,2}:\\d{2}.*$", "")
  as.Date(clean, format = "%m/%d/%Y")
}

normalize_doi <- function(x) {
  out <- str_trim(x)
  out <- str_to_lower(out)
  out <- str_replace(out, "^https?://(dx\\.)?doi\\.org/", "")
  out <- str_replace(out, "^doi:\\s*", "")
  out <- str_replace(out, "[\\.,;]+$", "")
  out[is.na(out) | out == "" | out %in% c("unavailable", "n/a", "na")] <- NA_character_
  out
}

split_semicolon <- function(x) {
  lapply(str_split(if_else(is.na(x), "", x), ";", simplify = FALSE), function(z) {
    z <- str_trim(z)
    unique(z[z != ""])
  })
}

raw <- data.table::fread(
  "data/raw/retractions.csv",
  colClasses = "character",
  check.names = FALSE,
  encoding = "UTF-8",
  data.table = FALSE
)
raw <- raw[, !names(raw) %in% c("", "V21"), drop = FALSE]
raw$retraction_date <- parse_us_date(raw$RetractionDate)
raw$retraction_year <- as.integer(format(raw$retraction_date, "%Y"))
raw$doi_canonical <- normalize_doi(raw$OriginalPaperDOI)
raw$reason_labels <- split_semicolon(raw$Reason)

core <- raw[
  raw$RetractionNature == "Retraction" &
    !is.na(raw$retraction_year) &
    raw$retraction_year >= 2012 &
    raw$retraction_year <= 2025,
]
china <- core[grepl("(^|;)\\s*China\\s*(;|$)", core$Country), ]

mapping_dir <- file.path("data", "reference", "mappings")
registry <- data.table::fread(
  file.path(mapping_dir, "reason_label_registry_v2.csv"),
  data.table = FALSE
)
domain_map <- data.table::fread(
  file.path(mapping_dir, "reason_domain_map_v2.csv"),
  data.table = FALSE
)
context_map <- data.table::fread(
  file.path(mapping_dir, "reason_context_map_v2.csv"),
  data.table = FALSE
)
analysis_family_map <- data.table::fread(
  file.path(mapping_dir, "analysis_family_domains_v2.csv"),
  data.table = FALSE
)

status_by_label <- setNames(registry$evidence_status, registry$reason_label)
domains_by_label <- split(domain_map$issue_domain, domain_map$reason_label)
contexts_by_label <- split(context_map$context_tag, context_map$reason_label)

record_statuses <- lapply(raw$reason_labels, function(labels) {
  unique(unname(status_by_label[labels]))
})
record_domains <- lapply(raw$reason_labels, function(labels) {
  unique(unlist(domains_by_label[labels], use.names = FALSE))
})
record_contexts <- lapply(raw$reason_labels, function(labels) {
  unique(unlist(contexts_by_label[labels], use.names = FALSE))
})

flag_domain <- function(label_lists, domain, statuses = NULL) {
  labels <- domain_map$reason_label[domain_map$issue_domain == domain]
  if (!is.null(statuses)) {
    labels <- labels[status_by_label[labels] %in% statuses]
  }
  vapply(label_lists, function(values) any(values %in% labels), logical(1))
}

analysis_domains <- split(
  analysis_family_map$issue_domain,
  analysis_family_map$analysis_family
)
analysis_flags <- lapply(names(analysis_domains), function(family) {
  domains <- analysis_domains[[family]]
  if (family %in% c("research_ethics_compliance", "materials_methods_integrity")) {
    vapply(record_domains, function(values) any(values %in% domains), logical(1))
  } else {
    vapply(raw$reason_labels, function(labels) {
      any(labels %in% domain_map$reason_label[
        domain_map$issue_domain %in% domains &
          status_by_label[domain_map$reason_label] == "substantive_finding"
      ])
    }, logical(1))
  }
})
names(analysis_flags) <- names(analysis_domains)

narrow_family_flags <- lapply(names(analysis_domains), function(family) {
  labels <- domain_map$reason_label[
    domain_map$issue_domain %in% analysis_domains[[family]] &
      status_by_label[domain_map$reason_label] == "substantive_finding"
  ]
  vapply(raw$reason_labels, function(values) any(values %in% labels), logical(1))
})
names(narrow_family_flags) <- names(analysis_domains)
control_candidate <- vapply(record_statuses, function(statuses) {
  any(statuses %in% c("error_unreliable", "insufficient_information"))
}, logical(1))
control <- control_candidate & !Reduce(`|`, narrow_family_flags)

domain_names <- sort(unique(domain_map$issue_domain))
domain_flags <- lapply(domain_names, function(domain) {
  flag_domain(raw$reason_labels, domain)
})
names(domain_flags) <- domain_names

domain_frame <- as.data.frame(domain_flags)
domain_frame$china <- grepl("(^|;)\\s*China\\s*(;|$)", raw$Country)
domain_frame$doi <- raw$doi_canonical
domain_frame$core <- raw$RetractionNature == "Retraction" &
  raw$retraction_year >= 2012 &
  raw$retraction_year <= 2025 &
  !is.na(raw$retraction_year)
domain_frame$context_only <- vapply(record_domains, length, integer(1)) == 0 &
  vapply(record_contexts, length, integer(1)) > 0

cat("REGISTRY LABELS", nrow(registry), "\n")
cat("DUPLICATE LABELS", anyDuplicated(registry$reason_label), "\n")
cat("UNMAPPED LABELS", sum(registry$mapping_status != "reviewed"), "\n")
cat("\nEVIDENCE STATUS LABEL COUNTS\n")
print(count(registry, evidence_status, sort = TRUE))
cat("\nLABELS WITH MULTIPLE DOMAINS\n")
print(
  domain_map %>%
    count(reason_label, name = "domain_count") %>%
    filter(domain_count > 1) %>%
    arrange(desc(domain_count), reason_label)
)
cat("\nCORE DOMAIN COUNTS\n")
print(colSums(domain_frame[domain_frame$core, domain_names, drop = FALSE]))
cat("\nCHINA CORE DOMAIN COUNTS\n")
print(colSums(domain_frame[domain_frame$core & domain_frame$china, domain_names, drop = FALSE]))
cat("\nANALYSIS FAMILY COUNTS (CORE RECORDS)\n")
print(vapply(
  analysis_flags,
  function(flag) sum(flag & domain_frame$core),
  integer(1)
))
cat("\nANALYSIS FAMILY COUNTS (CHINA CORE RECORDS)\n")
print(vapply(
  analysis_flags,
  function(flag) sum(flag & domain_frame$core & domain_frame$china),
  integer(1)
))
analysis_flag_frame <- as.data.frame(analysis_flags)
analysis_flag_frame$doi <- raw$doi_canonical
analysis_flag_frame$core <- domain_frame$core
analysis_flag_frame$china <- domain_frame$china
china_doi_family <- analysis_flag_frame %>%
  filter(!is.na(doi), core, china) %>%
  group_by(doi) %>%
  summarise(across(all_of(names(analysis_flags)), any), .groups = "drop")
cat("\nANALYSIS FAMILY COUNTS (CHINA UNIQUE DOIS)\n")
print(colSums(china_doi_family[names(analysis_flags)]))
cat("\nSTRICT CONTROL CORE RECORDS", sum(control & domain_frame$core), "\n")
cat(
  "STRICT CONTROL CHINA CORE RECORDS",
  sum(control & domain_frame$core & domain_frame$china),
  "\n"
)
control_frame <- data.frame(
  doi = raw$doi_canonical,
  control = control,
  core = domain_frame$core,
  china = domain_frame$china
)
control_doi <- control_frame %>%
  filter(!is.na(doi), core, china) %>%
  group_by(doi) %>%
  summarise(control = any(control), .groups = "drop")
cat("STRICT CONTROL CHINA UNIQUE DOIS", sum(control_doi$control), "\n")
cat("CONTEXT-ONLY CORE RECORDS", sum(domain_frame$context_only & domain_frame$core), "\n")
cat(
  "CONTEXT-ONLY CHINA CORE RECORDS",
  sum(domain_frame$context_only & domain_frame$core & domain_frame$china),
  "\n"
)
