#!/usr/bin/env Rscript

# Initial audit and exploratory analysis for the Retraction Watch database.
# Run from the project root. Frozen outputs are written below data/outputs/baseline.

options(stringsAsFactors = FALSE)
suppressWarnings(Sys.setlocale("LC_ALL", "Chinese"))

suppressPackageStartupMessages({
  library(data.table)
  library(readr)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(stringr)
  library(ggplot2)
  library(scales)
  library(forcats)
})

# readr's Windows file handling does not reliably support a Chinese project
# path. Base connections preserve the same UTF-8 CSV contract here.
write_csv <- function(x, file) {
  utils::write.csv(x, file, row.names = FALSE, fileEncoding = "UTF-8", na = "")
}

raw_file <- file.path("data", "raw", "retractions.csv")
output_dir <- file.path("data", "outputs", "baseline")
table_dir <- file.path(output_dir, "tables")
figure_dir <- file.path(output_dir, "figures")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

to_project_relative <- function(paths) {
  project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  prefix <- paste0(project_root, "/")
  vapply(
    paths,
    function(path) {
      normalized <- normalizePath(path, winslash = "/", mustWork = FALSE)
      if (!startsWith(tolower(normalized), tolower(prefix))) {
        stop("Path is outside project root: ", normalized)
      }
      substring(normalized, nchar(prefix) + 1L)
    },
    character(1)
  )
}

if (!file.exists(raw_file)) {
  stop("Raw file not found: ", raw_file)
}

source_size <- file.info(raw_file)$size
source_hash <- digest::digest(file = raw_file, algo = "sha256")

raw <- data.table::fread(
  raw_file,
  colClasses = "character",
  check.names = FALSE,
  encoding = "UTF-8",
  data.table = FALSE
)

# The downloaded CSV has a trailing empty field. It carries no information.
raw <- raw[, !names(raw) %in% c("", "V21"), drop = FALSE]

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
  out <- str_split(if_else(is.na(x), "", x), ";", simplify = FALSE)
  lapply(out, function(z) {
    z <- str_trim(z)
    unique(z[z != ""])
  })
}

count_reason_labels <- function(x) {
  lengths(split_semicolon(x))
}

raw$retraction_date <- parse_us_date(raw$`RetractionDate`)
raw$original_paper_date <- parse_us_date(raw$`OriginalPaperDate`)
raw$retraction_year <- as.integer(format(raw$retraction_date, "%Y"))
raw$original_paper_year <- as.integer(format(raw$original_paper_date, "%Y"))
raw$doi_canonical <- normalize_doi(raw$OriginalPaperDOI)
raw$reason_labels <- split_semicolon(raw$Reason)
raw$n_reason_labels <- count_reason_labels(raw$Reason)
raw$author_count <- lengths(split_semicolon(raw$Author))
raw$country_count <- lengths(split_semicolon(raw$Country))
raw$institution_count <- lengths(split_semicolon(raw$Institution))
raw$subject_primary <- str_extract(raw$Subject, "^\\([A-Z/]+\\)")
raw$retraction_year_outside_1900_2026 <- !is.na(raw$retraction_year) &
  (raw$retraction_year < 1900 | raw$retraction_year > 2026)

all_label_counts <- unlist(raw$reason_labels, use.names = FALSE)

mapping_dir <- file.path("data", "reference", "mappings")
registry_file <- file.path(mapping_dir, "reason_label_registry_v2.csv")
domain_map_file <- file.path(mapping_dir, "reason_domain_map_v2.csv")
context_map_file <- file.path(mapping_dir, "reason_context_map_v2.csv")
analysis_family_file <- file.path(mapping_dir, "analysis_family_domains_v2.csv")
required_mapping_files <- c(
  registry_file,
  domain_map_file,
  context_map_file,
  analysis_family_file
)
missing_mapping_files <- required_mapping_files[!file.exists(required_mapping_files)]
if (length(missing_mapping_files) > 0) {
  stop("Missing reason mapping files: ", paste(missing_mapping_files, collapse = ", "))
}

reason_registry <- data.table::fread(
  registry_file,
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
reason_domains <- data.table::fread(
  domain_map_file,
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
reason_contexts <- data.table::fread(
  context_map_file,
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
analysis_families <- data.table::fread(
  analysis_family_file,
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)

allowed_evidence_statuses <- c(
  "substantive_finding",
  "concern_allegation",
  "error_unreliable",
  "insufficient_information",
  "not_applicable"
)
allowed_domains <- c(
  "publication_peer_review",
  "image_integrity",
  "data_results_integrity",
  "textual_reuse",
  "authorship_affiliation",
  "research_ethics_compliance",
  "materials_methods_integrity",
  "unspecified_integrity"
)
if (anyDuplicated(reason_registry$reason_label) > 0) {
  stop("Reason registry contains duplicate labels.")
}
if (!all(reason_registry$evidence_status %in% allowed_evidence_statuses)) {
  stop("Reason registry contains an unsupported evidence status.")
}
if (!all(reason_domains$issue_domain %in% allowed_domains)) {
  stop("Reason domain map contains an unsupported issue domain.")
}

all_reason_labels <- sort(unique(all_label_counts))
unknown_reason_labels <- setdiff(all_reason_labels, reason_registry$reason_label)
if (length(unknown_reason_labels) > 0) {
  stop("Unmapped reason labels: ", paste(unknown_reason_labels, collapse = "; "))
}

label_domains <- split(reason_domains$issue_domain, reason_domains$reason_label)
label_contexts <- split(reason_contexts$context_tag, reason_contexts$reason_label)
label_evidence <- setNames(reason_registry$evidence_status, reason_registry$reason_label)

raw$issue_domains <- lapply(raw$reason_labels, function(labels) {
  unique(unlist(label_domains[labels], use.names = FALSE))
})
raw$reason_contexts <- lapply(raw$reason_labels, function(labels) {
  unique(unlist(label_contexts[labels], use.names = FALSE))
})
raw$reason_evidence <- lapply(raw$reason_labels, function(labels) {
  unique(unname(label_evidence[labels]))
})

flag_labels <- function(labels, candidates) {
  vapply(labels, function(values) any(values %in% candidates), logical(1))
}

flag_domain <- function(labels, domain, statuses = NULL) {
  domain_labels <- reason_domains$reason_label[
    reason_domains$issue_domain == domain
  ]
  if (!is.null(statuses)) {
    domain_labels <- domain_labels[
      label_evidence[domain_labels] %in% statuses
    ]
  }
  flag_labels(labels, domain_labels)
}

family_domain_list <- split(
  analysis_families$issue_domain,
  analysis_families$analysis_family
)
family_labels <- lapply(family_domain_list, function(domains) {
  unique(reason_domains$reason_label[
    reason_domains$issue_domain %in% domains
  ])
})
family_labels_narrow <- lapply(family_labels, function(labels) {
  labels[label_evidence[labels] == "substantive_finding"]
})

raw$family_process <- flag_labels(raw$reason_labels, family_labels_narrow$publication_process)
raw$family_image <- flag_labels(raw$reason_labels, family_labels_narrow$image_integrity)
raw$family_plagiarism <- flag_labels(
  raw$reason_labels,
  family_labels_narrow$plagiarism_authorship
)
raw$family_data <- flag_labels(raw$reason_labels, family_labels_narrow$data_integrity)
raw$family_research_ethics_narrow <- flag_labels(
  raw$reason_labels,
  family_labels_narrow$research_ethics_compliance
)
raw$family_materials_methods_narrow <- flag_labels(
  raw$reason_labels,
  family_labels_narrow$materials_methods_integrity
)
raw$family_research_ethics <- flag_domain(
  raw$reason_labels,
  "research_ethics_compliance"
)
raw$family_materials_methods <- flag_domain(
  raw$reason_labels,
  "materials_methods_integrity"
)

raw$family_process_broad <- flag_domain(
  raw$reason_labels,
  "publication_peer_review"
)
raw$family_image_broad <- flag_domain(raw$reason_labels, "image_integrity")
raw$family_plagiarism_broad <- flag_labels(
  raw$reason_labels,
  family_labels$plagiarism_authorship
)
raw$family_data_broad <- flag_domain(raw$reason_labels, "data_results_integrity")

raw$domain_textual_reuse <- flag_domain(raw$reason_labels, "textual_reuse")
raw$domain_authorship_affiliation <- flag_domain(
  raw$reason_labels,
  "authorship_affiliation"
)
raw$domain_unspecified_integrity <- flag_domain(
  raw$reason_labels,
  "unspecified_integrity"
)
raw$reason_domain_any <- vapply(
  raw$issue_domains,
  function(domains) length(domains) > 0,
  logical(1)
)
raw$reason_mapping_unmapped <- vapply(
  raw$reason_labels,
  function(labels) {
    any(reason_registry$mapping_status[
      match(labels, reason_registry$reason_label)
    ] != "reviewed")
  },
  logical(1)
)
raw$family_control_candidate <- vapply(
  raw$reason_evidence,
  function(statuses) {
    any(statuses %in% c("error_unreliable", "insufficient_information"))
  },
  logical(1)
)

raw$family_control <- raw$family_control_candidate & !(
  raw$family_process |
    raw$family_image |
    raw$family_plagiarism |
    raw$family_data |
    raw$family_research_ethics_narrow |
    raw$family_materials_methods_narrow
)
raw$family_unclassified <- !(
  raw$family_process |
    raw$family_image |
    raw$family_plagiarism |
    raw$family_data |
    raw$family_research_ethics |
    raw$family_materials_methods |
    raw$family_control
)

retractions <- raw %>%
  filter(RetractionNature == "Retraction")

core <- retractions %>%
  filter(!is.na(retraction_year), retraction_year >= 2012, retraction_year <= 2025)

core_valid_doi <- core %>% filter(!is.na(doi_canonical))

year_nature <- raw %>%
  filter(!is.na(retraction_year), retraction_year >= 2000) %>%
  count(retraction_year, RetractionNature, name = "records") %>%
  complete(
    retraction_year = full_seq(retraction_year, 1),
    RetractionNature,
    fill = list(records = 0)
  )
write_csv(year_nature, file.path(table_dir, "year_nature_counts.csv"))

doi_by_year <- retractions %>%
  filter(!is.na(retraction_year), retraction_year >= 2012) %>%
  group_by(retraction_year) %>%
  summarise(
    retraction_records = n(),
    valid_doi_records = sum(!is.na(doi_canonical)),
    valid_doi_share = valid_doi_records / retraction_records,
    unique_valid_dois = n_distinct(doi_canonical, na.rm = TRUE),
    .groups = "drop"
  )
write_csv(doi_by_year, file.path(table_dir, "doi_coverage_by_year.csv"))

reason_counts_all <- tibble(reason_label = all_label_counts) %>%
  count(reason_label, sort = TRUE, name = "records")
write_csv(reason_counts_all, file.path(table_dir, "reason_label_counts_all.csv"))

core_reason_counts <- core %>%
  select(reason_labels) %>%
  unnest_longer(reason_labels, values_to = "reason_label") %>%
  filter(!is.na(reason_label), reason_label != "") %>%
  count(reason_label, sort = TRUE, name = "records")
write_csv(core_reason_counts, file.path(table_dir, "reason_label_counts_core.csv"))

coarse_family_flags <- list(
  publication_process = core$family_process,
  image_integrity = core$family_image,
  plagiarism_authorship = core$family_plagiarism,
  data_integrity = core$family_data,
  research_ethics_compliance = core$family_research_ethics,
  materials_methods_integrity = core$family_materials_methods,
  error_control = core$family_control,
  unclassified = core$family_unclassified
)

family_summary <- tibble(
  reason_family = names(coarse_family_flags),
  records = vapply(coarse_family_flags, sum, integer(1))
) %>%
  mutate(share_of_core = records / nrow(core))
write_csv(family_summary, file.path(table_dir, "reason_family_counts_core.csv"))

detailed_domain_flags <- list(
  publication_peer_review = core$family_process_broad,
  image_integrity = core$family_image_broad,
  data_results_integrity = core$family_data_broad,
  textual_reuse = core$domain_textual_reuse,
  authorship_affiliation = core$domain_authorship_affiliation,
  research_ethics_compliance = flag_domain(
    core$reason_labels,
    "research_ethics_compliance"
  ),
  materials_methods_integrity = flag_domain(
    core$reason_labels,
    "materials_methods_integrity"
  ),
  unspecified_integrity = core$domain_unspecified_integrity
)
domain_summary <- tibble(
  issue_domain = names(detailed_domain_flags),
  records = vapply(detailed_domain_flags, sum, integer(1))
) %>%
  mutate(share_of_core = records / nrow(core))
write_csv(domain_summary, file.path(table_dir, "reason_domain_counts_core.csv"))

family_sensitivity <- tibble(
  reason_family = c(
    "publication_process",
    "image_integrity",
    "plagiarism_authorship",
    "data_integrity",
    "research_ethics_compliance",
    "materials_methods_integrity"
  ),
  narrow_records = c(
    sum(core$family_process),
    sum(core$family_image),
    sum(core$family_plagiarism),
    sum(core$family_data),
    sum(core$family_research_ethics_narrow),
    sum(core$family_materials_methods_narrow)
  ),
  broad_records = c(
    sum(core$family_process_broad),
    sum(core$family_image_broad),
    sum(core$family_plagiarism_broad),
    sum(core$family_data_broad),
    sum(core$family_research_ethics),
    sum(core$family_materials_methods)
  )
) %>%
  mutate(
    narrow_share = narrow_records / nrow(core),
    broad_share = broad_records / nrow(core)
  )
write_csv(
  family_sensitivity,
  file.path(table_dir, "reason_family_sensitivity_core.csv")
)

core_reason_long <- core %>%
  select(reason_labels) %>%
  unnest_longer(reason_labels, values_to = "reason_label") %>%
  filter(!is.na(reason_label), reason_label != "") %>%
  left_join(reason_registry, by = "reason_label")

core_label_mapping <- core_reason_long %>%
  left_join(
    reason_domains %>%
      group_by(reason_label) %>%
      summarise(
        issue_domains = paste(sort(unique(issue_domain)), collapse = ";"),
        .groups = "drop"
      ),
    by = "reason_label"
  ) %>%
  left_join(
    reason_contexts %>%
      group_by(reason_label) %>%
      summarise(
        context_tags = paste(sort(unique(context_tag)), collapse = ";"),
        .groups = "drop"
      ),
    by = "reason_label"
  ) %>%
  count(
    reason_label,
    evidence_status,
    issue_domains,
    context_tags,
    mapping_status,
    name = "records"
  )
write_csv(
  core_label_mapping,
  file.path(table_dir, "reason_label_mapping_core.csv")
)

evidence_status_summary <- core_reason_long %>%
  count(evidence_status, sort = TRUE, name = "label_occurrences") %>%
  mutate(label_occurrences_per_core_record = label_occurrences / nrow(core))
write_csv(
  evidence_status_summary,
  file.path(table_dir, "reason_evidence_status_counts_core.csv")
)

context_summary <- core_reason_long %>%
  inner_join(
    reason_contexts,
    by = "reason_label",
    relationship = "many-to-many"
  ) %>%
  count(context_tag, sort = TRUE, name = "label_occurrences") %>%
  mutate(label_occurrences_per_core_record = label_occurrences / nrow(core))
write_csv(
  context_summary,
  file.path(table_dir, "reason_context_counts_core.csv")
)

context_only_summary <- tibble(
  unit = "core_records",
  records = sum(
    vapply(core$reason_contexts, length, integer(1)) > 0 &
      !core$reason_domain_any
  )
)
write_csv(
  context_only_summary,
  file.path(table_dir, "reason_context_only_summary_core.csv")
)

family_year <- bind_cols(
  tibble(retraction_year = core$retraction_year),
  as_tibble(coarse_family_flags)
) %>%
  pivot_longer(-retraction_year, names_to = "reason_family", values_to = "flagged") %>%
  filter(flagged) %>%
  count(retraction_year, reason_family, name = "records")
write_csv(family_year, file.path(table_dir, "reason_family_counts_by_year_core.csv"))

family_matrix <- as.matrix(as.data.frame(coarse_family_flags))

cooccurrence <- crossprod(family_matrix)
cooccurrence_df <- as.data.frame(cooccurrence) %>%
  tibble::rownames_to_column("family_1") %>%
  pivot_longer(-family_1, names_to = "family_2", values_to = "records")
write_csv(cooccurrence_df, file.path(table_dir, "reason_family_cooccurrence.csv"))

reason_family_patterns <- tibble(
  pattern = apply(
    family_matrix,
    1,
    function(flags) paste(names(coarse_family_flags)[flags], collapse = "+")
  )
) %>%
  count(pattern, sort = TRUE, name = "records") %>%
  mutate(share_of_core = records / nrow(core))
write_csv(reason_family_patterns, file.path(table_dir, "reason_family_patterns_core.csv"))

unclassified_reason_counts <- core %>%
  filter(family_unclassified) %>%
  select(reason_labels) %>%
  unnest_longer(reason_labels, values_to = "reason_label") %>%
  filter(!is.na(reason_label), reason_label != "") %>%
  count(reason_label, sort = TRUE, name = "records")
write_csv(
  unclassified_reason_counts,
  file.path(table_dir, "reason_labels_within_unclassified_core.csv")
)

article_type_counts <- core %>%
  count(ArticleType, sort = TRUE, name = "records")
write_csv(article_type_counts, file.path(table_dir, "article_type_counts_core.csv"))

subject_counts <- core %>%
  count(subject_primary, sort = TRUE, name = "records") %>%
  filter(!is.na(subject_primary))
write_csv(subject_counts, file.path(table_dir, "subject_counts_core.csv"))

publisher_counts <- core %>%
  count(Publisher, sort = TRUE, name = "records") %>%
  filter(!is.na(Publisher), Publisher != "")
write_csv(publisher_counts, file.path(table_dir, "publisher_counts_core.csv"))

publisher_year_counts <- core %>%
  filter(!is.na(Publisher), Publisher != "") %>%
  count(retraction_year, Publisher, name = "records", sort = TRUE)
write_csv(publisher_year_counts, file.path(table_dir, "publisher_year_counts_core.csv"))

author_summary <- tibble(
  metric = c("min", "p25", "median", "mean", "p75", "p90", "p95", "p99", "max", "missing_or_zero"),
  value = c(
    min(core$author_count),
    quantile(core$author_count, 0.25, names = FALSE),
    median(core$author_count),
    mean(core$author_count),
    quantile(core$author_count, 0.75, names = FALSE),
    quantile(core$author_count, 0.90, names = FALSE),
    quantile(core$author_count, 0.95, names = FALSE),
    quantile(core$author_count, 0.99, names = FALSE),
    max(core$author_count),
    sum(core$author_count == 0)
  )
)
write_csv(author_summary, file.path(table_dir, "author_count_summary_core.csv"))

delay_years <- as.numeric(core$retraction_date - core$original_paper_date) / 365.25
delay_summary <- tibble(
  metric = c("available", "negative", "zero_to_one", "one_to_three", "three_to_five", "five_plus"),
  records = c(
    sum(!is.na(delay_years)),
    sum(delay_years < 0, na.rm = TRUE),
    sum(delay_years >= 0 & delay_years <= 1, na.rm = TRUE),
    sum(delay_years > 1 & delay_years <= 3, na.rm = TRUE),
    sum(delay_years > 3 & delay_years <= 5, na.rm = TRUE),
    sum(delay_years > 5, na.rm = TRUE)
  )
) %>%
  mutate(share_of_available = records / sum(records[metric == "available"]))
write_csv(delay_summary, file.path(table_dir, "retraction_delay_summary_core.csv"))

atomic_raw_fields <- names(raw)[vapply(raw, is.atomic, logical(1))]
missing_summary <- tibble(
  field = atomic_raw_fields,
  missing_records = vapply(raw[atomic_raw_fields], function(z) sum(is.na(z) | z == ""), integer(1)),
  missing_share = missing_records / nrow(raw)
)
write_csv(missing_summary, file.path(table_dir, "missing_values.csv"))

duplicate_dois <- core_valid_doi %>%
  count(doi_canonical, name = "retraction_records") %>%
  filter(retraction_records > 1)

quality_summary <- tibble(
  metric = c(
    "source_bytes",
    "source_sha256",
    "total_notification_records",
    "reference_count_in_prior_project_docs",
    "current_file_minus_prior_document_count",
    "unique_record_ids",
    "retraction_records",
    "expression_of_concern_records",
    "correction_records",
    "reinstatement_records",
    "unique_retraction_natures",
    "unique_reason_labels",
    "retraction_date_missing",
    "retraction_date_min",
    "retraction_date_max",
    "out_of_range_retraction_years",
    "core_retraction_records_2012_2025",
    "core_valid_doi_records",
    "core_valid_doi_share",
    "core_unique_valid_dois",
    "core_duplicate_doi_records",
    "core_duplicate_doi_groups",
    "core_unclassified_records",
    "core_unclassified_share"
  ),
  value = c(
    as.character(source_size),
    source_hash,
    as.character(nrow(raw)),
    "73519",
    as.character(nrow(raw) - 73519),
    as.character(n_distinct(raw$`Record ID`)),
    as.character(sum(raw$RetractionNature == "Retraction")),
    as.character(sum(raw$RetractionNature == "Expression of concern")),
    as.character(sum(raw$RetractionNature == "Correction")),
    as.character(sum(raw$RetractionNature == "Reinstatement")),
    as.character(n_distinct(raw$RetractionNature)),
    as.character(length(all_reason_labels)),
    as.character(sum(is.na(raw$retraction_date))),
    as.character(min(raw$retraction_date, na.rm = TRUE)),
    as.character(max(raw$retraction_date, na.rm = TRUE)),
    as.character(sum(raw$retraction_year_outside_1900_2026)),
    as.character(nrow(core)),
    as.character(nrow(core_valid_doi)),
    sprintf("%.6f", nrow(core_valid_doi) / nrow(core)),
    as.character(n_distinct(core_valid_doi$doi_canonical)),
    as.character(sum(duplicated(core_valid_doi$doi_canonical))),
    as.character(nrow(duplicate_dois)),
    as.character(sum(core$family_unclassified)),
    sprintf("%.6f", mean(core$family_unclassified))
  )
)
write_csv(quality_summary, file.path(table_dir, "data_quality_summary.csv"))

line_colors <- c(
  "Retraction" = "#C0392B",
  "Expression of concern" = "#D68910",
  "Correction" = "#2471A3",
  "Reinstatement" = "#148F77"
)

p1 <- year_nature %>%
  filter(retraction_year >= 2010, retraction_year <= 2026) %>%
  ggplot(aes(x = retraction_year, y = records, color = RetractionNature)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.8) +
  scale_color_manual(values = line_colors) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Retraction Watch notification records by year",
    x = NULL,
    y = "Records",
    color = NULL,
    caption = "Source: Retraction Watch/Crossref file observed on 2026-11-04."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "top",
    panel.grid.minor = element_blank(),
    plot.title.position = "plot"
  )
ggsave(file.path(figure_dir, "01_records_by_year_nature.png"), p1, width = 9, height = 5, dpi = 180)

p2 <- doi_by_year %>%
  ggplot(aes(x = retraction_year)) +
  geom_col(aes(y = retraction_records), fill = "#AEB6BF") +
  geom_line(aes(y = valid_doi_records), color = "#C0392B", linewidth = 1) +
  geom_point(aes(y = valid_doi_records), color = "#C0392B", size = 1.8) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Retraction records and valid original-paper DOI coverage",
    subtitle = "Grey bars: all retraction records; red line: records with a usable DOI",
    x = NULL,
    y = "Records"
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), plot.title.position = "plot")
ggsave(file.path(figure_dir, "02_doi_coverage_by_year.png"), p2, width = 9, height = 5, dpi = 180)

p3 <- core_reason_counts %>%
  slice_max(records, n = 20) %>%
  mutate(reason_label = fct_reorder(reason_label, records)) %>%
  ggplot(aes(x = records, y = reason_label, fill = records)) +
  geom_col(show.legend = FALSE) +
  scale_fill_gradient(low = "#D6EAF8", high = "#2874A6") +
  scale_x_continuous(labels = comma) +
  labs(
    title = "Most frequent reason labels in the core window",
    subtitle = "2012-2025 retraction records; labels remain multi-valued",
    x = "Records",
    y = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), plot.title.position = "plot")
ggsave(file.path(figure_dir, "03_top_reason_labels_core.png"), p3, width = 9, height = 6, dpi = 180)

family_labels <- c(
  publication_process = "Publication/peer review",
  image_integrity = "Image integrity",
  plagiarism_authorship = "Plagiarism/authorship",
  data_integrity = "Data/results integrity",
  research_ethics_compliance = "Research ethics (any)",
  materials_methods_integrity = "Materials/methods (any)",
  error_control = "Strict error control",
  unclassified = "Unclassified"
)
family_colors <- c(
  publication_process = "#457B9D",
  image_integrity = "#2A9D8F",
  plagiarism_authorship = "#D4AC0D",
  data_integrity = "#E76F51",
  research_ethics_compliance = "#8E6C8A",
  materials_methods_integrity = "#2E8B57",
  error_control = "#7F8C8D",
  unclassified = "#9B59B6"
)

p4 <- family_summary %>%
  mutate(
    family_label = factor(family_labels[reason_family], levels = family_labels),
    share_label = percent(share_of_core, accuracy = 0.1)
  ) %>%
  ggplot(aes(x = records, y = family_label, fill = reason_family)) +
  geom_col(show.legend = FALSE) +
  scale_fill_manual(values = family_colors) +
  geom_text(aes(label = share_label), hjust = -0.1, size = 3.2) +
  scale_x_continuous(labels = comma, expand = expansion(mult = c(0, 0.14))) +
  labs(
    title = "Reason-family coverage in the reviewed v2 mapping",
    subtitle = "Families overlap; main families use substantive findings",
    x = "Core-window records",
    y = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), plot.title.position = "plot")
ggsave(file.path(figure_dir, "04_reason_family_coverage_core.png"), p4, width = 9, height = 4.8, dpi = 180)

author_distribution <- core %>%
  mutate(author_bin = if_else(author_count > 15, "16+", as.character(author_count))) %>%
  count(author_bin, name = "records") %>%
  mutate(author_bin = factor(author_bin, levels = c(as.character(0:15), "16+")))

p5 <- author_distribution %>%
  ggplot(aes(x = author_bin, y = records)) +
  geom_col(fill = "#2874A6") +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Authors per retracted paper",
    subtitle = "Core window; 16+ grouped for display",
    x = "Author count",
    y = "Records"
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), plot.title.position = "plot")
ggsave(file.path(figure_dir, "05_author_count_distribution_core.png"), p5, width = 9, height = 4.8, dpi = 180)

p6 <- family_year %>%
  ggplot(aes(x = retraction_year, y = records, color = reason_family)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.6) +
  scale_color_manual(values = family_colors, labels = family_labels) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Reason-family trends in the core window",
    subtitle = "A record can contribute to more than one family",
    x = NULL,
    y = "Records",
    color = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "top",
    panel.grid.minor = element_blank(),
    plot.title.position = "plot"
  )
ggsave(file.path(figure_dir, "06_reason_family_trends_core.png"), p6, width = 9, height = 5.2, dpi = 180)

writeLines(
  c(
    paste0("Records: ", nrow(raw)),
    paste0("Retractions: ", nrow(retractions)),
    paste0("Core retractions (2012-2025): ", nrow(core)),
    paste0("Unique reason labels: ", length(all_reason_labels)),
    paste0("Core valid DOI records: ", nrow(core_valid_doi)),
    paste0("Core valid DOI share: ", percent(nrow(core_valid_doi) / nrow(core), accuracy = 0.01)),
    paste0("Core unclassified share: ", percent(mean(core$family_unclassified), accuracy = 0.01))
  ),
  file.path(table_dir, "eda_console_summary.txt"),
  useBytes = TRUE
)

output_files <- c(
  list.files(table_dir, full.names = TRUE),
  list.files(figure_dir, full.names = TRUE)
)
output_files <- output_files[basename(output_files) != "README.md"]
output_rows <- data.frame(
  path = to_project_relative(output_files),
  bytes = file.info(output_files)$size,
  sha256 = vapply(output_files, digest::digest, character(1), file = TRUE, algo = "sha256"),
  stringsAsFactors = FALSE
)
output_manifest_rows <- lapply(seq_len(nrow(output_rows)), function(index) {
  list(
    path = output_rows$path[[index]],
    bytes = output_rows$bytes[[index]],
    sha256 = output_rows$sha256[[index]]
  )
})

manifest <- list(
  contract_version = "1.0",
  source_file = to_project_relative(raw_file),
  source_path_type = "project-relative",
  source_bytes = source_size,
  source_sha256 = source_hash,
  downloaded_or_observed_on = "2026-11-04",
  source_version_verified = FALSE,
  source_version_note = paste(
    "Prior project documentation reports 73,519 records; the current file has 73,597.",
    "The available metadata cannot establish why the counts differ."
  ),
  total_records = nrow(raw),
  retraction_records = sum(raw$RetractionNature == "Retraction"),
  core_window = "2012-2025",
  core_records = nrow(core),
  unique_reason_labels = length(all_reason_labels),
  mapping_version = unique(reason_registry$mapping_version),
  mapping_registry_labels = nrow(reason_registry),
  mapping_unmapped_labels = sum(reason_registry$mapping_status != "reviewed"),
  mapping_unmapped_core_records = sum(core$reason_mapping_unmapped),
  domain_map_rows = nrow(reason_domains),
  context_map_rows = nrow(reason_contexts),
  analysis_family_rows = nrow(analysis_families),
  reason_registry_file = to_project_relative(registry_file),
  reason_registry_sha256 = sha256_canonical_file(registry_file),
  reason_domain_map_file = to_project_relative(domain_map_file),
  reason_domain_map_sha256 = sha256_canonical_file(domain_map_file),
  reason_context_map_file = to_project_relative(context_map_file),
  reason_context_map_sha256 = sha256_canonical_file(context_map_file),
  analysis_family_file = to_project_relative(analysis_family_file),
  analysis_family_sha256 = sha256_canonical_file(analysis_family_file),
  r_version = R.version.string,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  output_file_count = nrow(output_rows),
  outputs = output_manifest_rows
)
jsonlite::write_json(
  manifest,
  file.path(output_dir, "manifest.json"),
  auto_unbox = TRUE,
  pretty = TRUE
)

message("Initial EDA completed.")
message("Outputs: ", normalizePath(output_dir, mustWork = TRUE))
message("Figures: ", normalizePath(figure_dir, mustWork = TRUE))
