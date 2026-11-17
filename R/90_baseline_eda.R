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
candidate_mapping_dir <- file.path("data", "interim", "mappings")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(candidate_mapping_dir, recursive = TRUE, showWarnings = FALSE)

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

data_families <- c(
  "Falsification/Fabrication of Data",
  "Manipulation of Data",
  "Duplication of Data",
  "Falsification/Fabrication of Results",
  "Manipulation of Results"
)
image_families <- c(
  "Falsification/Fabrication of Image",
  "Manipulation of Images",
  "Duplication of/in Image"
)
process_families <- c(
  "Paper Mill",
  "Compromised Peer Review",
  "Concerns/Issues about Peer Review",
  "Rogue Editor",
  "Taken via Peer Review",
  "Computer-Aided Content or Computer-Generated Content"
)
plagiarism_families <- c(
  "Plagiarism of Data",
  "Plagiarism of Image",
  "Plagiarism of Text",
  "Plagiarism of/in Article",
  "Euphemisms for Plagiarism",
  "Duplication of/in Article",
  "Duplication of Text",
  "Euphemisms for Duplication",
  "Concerns/Issues about Authorship/Affiliation"
)
control_labels <- c(
  "Error in Data",
  "Error in Image",
  "Error in Results and/or Conclusions",
  "Results Not Reproducible",
  "Unreliable Data",
  "Unreliable Image",
  "Unreliable Results and/or Conclusions",
  "Concerns/Issues about Data",
  "Concerns/Issues about Image",
  "Concerns/Issues about Results and/or Conclusions",
  "Notice - Limited or No Information",
  "Date of Article and/or Notice Unknown"
)

family_lookup <- bind_rows(
  tibble(label = data_families, reason_family = "data_integrity"),
  tibble(label = image_families, reason_family = "image_integrity"),
  tibble(label = process_families, reason_family = "publication_process"),
  tibble(label = plagiarism_families, reason_family = "plagiarism_authorship"),
  tibble(label = control_labels, reason_family = "error_control")
) %>%
  distinct(label, reason_family)

all_reason_labels <- sort(unique(all_label_counts))
reason_dictionary <- tibble(reason_label = all_reason_labels) %>%
  left_join(family_lookup, by = c("reason_label" = "label"), relationship = "many-to-many") %>%
  mutate(
    reason_family = replace_na(reason_family, "unclassified"),
    mapping_version = "1.0-candidate",
    reviewer_note = if_else(
      reason_family == "unclassified",
      "Not mapped in the project's initial strict dictionary.",
      ""
    )
  )

write_csv(
  reason_dictionary,
  file.path(candidate_mapping_dir, "reason_dictionary_candidate.csv")
)

flag_family <- function(labels, dictionary_labels) {
  vapply(labels, function(z) any(z %in% dictionary_labels), logical(1))
}

raw$family_data <- flag_family(raw$reason_labels, data_families)
raw$family_image <- flag_family(raw$reason_labels, image_families)
raw$family_process <- flag_family(raw$reason_labels, process_families)
raw$family_plagiarism <- flag_family(raw$reason_labels, plagiarism_families)
raw$family_control_candidate <- flag_family(raw$reason_labels, control_labels)
raw$family_control <- raw$family_control_candidate &
  !(raw$family_data | raw$family_image | raw$family_process | raw$family_plagiarism)
raw$family_unclassified <- !(
  raw$family_data | raw$family_image | raw$family_process |
    raw$family_plagiarism | raw$family_control
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

family_summary <- tibble(
  reason_family = c(
    "data_integrity",
    "image_integrity",
    "publication_process",
    "plagiarism_authorship",
    "error_control",
    "unclassified"
  ),
  records = c(
    sum(core$family_data),
    sum(core$family_image),
    sum(core$family_process),
    sum(core$family_plagiarism),
    sum(core$family_control),
    sum(core$family_unclassified)
  )
) %>%
  mutate(share_of_core = records / nrow(core))
write_csv(family_summary, file.path(table_dir, "reason_family_counts_core.csv"))

family_year <- core %>%
  select(
    retraction_year,
    data_integrity = family_data,
    image_integrity = family_image,
    publication_process = family_process,
    plagiarism_authorship = family_plagiarism,
    error_control = family_control,
    unclassified = family_unclassified
  ) %>%
  pivot_longer(-retraction_year, names_to = "reason_family", values_to = "flagged") %>%
  filter(flagged) %>%
  count(retraction_year, reason_family, name = "records")
write_csv(family_year, file.path(table_dir, "reason_family_counts_by_year_core.csv"))

family_matrix <- core %>%
  transmute(
    data_integrity = family_data,
    image_integrity = family_image,
    publication_process = family_process,
    plagiarism_authorship = family_plagiarism,
    error_control = family_control,
    unclassified = family_unclassified
  ) %>%
  as.matrix()

cooccurrence <- crossprod(family_matrix)
cooccurrence_df <- as.data.frame(cooccurrence) %>%
  tibble::rownames_to_column("family_1") %>%
  pivot_longer(-family_1, names_to = "family_2", values_to = "records")
write_csv(cooccurrence_df, file.path(table_dir, "reason_family_cooccurrence.csv"))

reason_family_patterns <- core %>%
  transmute(
    pattern = pmap_chr(
      list(
        family_data,
        family_image,
        family_process,
        family_plagiarism,
        family_control,
        family_unclassified
      ),
      function(data_flag, image_flag, process_flag, plagiarism_flag, control_flag, unclassified_flag) {
        active <- c(
          "data_integrity" = data_flag,
          "image_integrity" = image_flag,
          "publication_process" = process_flag,
          "plagiarism_authorship" = plagiarism_flag,
          "error_control" = control_flag,
          "unclassified" = unclassified_flag
        )
        paste(names(active)[active], collapse = "+")
      }
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
  data_integrity = "Data integrity",
  image_integrity = "Image integrity",
  publication_process = "Publication process",
  plagiarism_authorship = "Plagiarism/authorship",
  error_control = "Strict error control",
  unclassified = "Unclassified"
)
family_colors <- c(
  data_integrity = "#E76F51",
  image_integrity = "#2A9D8F",
  publication_process = "#457B9D",
  plagiarism_authorship = "#D4AC0D",
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
    title = "Reason-family coverage in the strict v1 mapping",
    subtitle = "Families overlap; shares do not add to 100%",
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

reference_mapping_file <- file.path(
  "data", "reference", "mappings", "reason_dictionary_v1.csv"
)
candidate_mapping_file <- file.path(
  candidate_mapping_dir, "reason_dictionary_candidate.csv"
)

candidate_mapping_matches_reference <- FALSE
if (file.exists(reference_mapping_file)) {
  reference_mapping <- data.table::fread(
    reference_mapping_file,
    colClasses = "character",
    encoding = "UTF-8",
    data.table = FALSE
  )
  candidate_key <- reason_dictionary[
    order(reason_dictionary$reason_label),
    c("reason_label", "reason_family")
  ]
  reference_key <- reference_mapping[
    order(reference_mapping$reason_label),
    c("reason_label", "reason_family")
  ]
  rownames(candidate_key) <- NULL
  rownames(reference_key) <- NULL
  candidate_mapping_matches_reference <- identical(candidate_key, reference_key)
}

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
  mapping_version = "1.0-candidate",
  reference_mapping_file = to_project_relative(reference_mapping_file),
  reference_mapping_sha256 = if (file.exists(reference_mapping_file)) {
    digest::digest(file = reference_mapping_file, algo = "sha256")
  } else {
    NA_character_
  },
  candidate_mapping_file = to_project_relative(candidate_mapping_file),
  candidate_mapping_sha256 = digest::digest(file = candidate_mapping_file, algo = "sha256"),
  candidate_mapping_matches_reference = candidate_mapping_matches_reference,
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
