#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

input_path <- file.path(processed_dir, "p0", "paper_panel_mapped.rds")
if (!file.exists(input_path)) {
  stop("Run R/03_map_reasons.R first. Missing: ", input_path)
}

panel <- readRDS(input_path)
linkable <- panel[panel$doi_status == "linkable", , drop = FALSE]
china_candidate <- linkable[linkable$country_candidate_mainland, , drop = FALSE]

if (nrow(china_candidate) == 0) {
  stop("No mainland-candidate papers remained after DOI screening.")
}

hmt_values <- c(
  "Hong Kong",
  "Macao",
  "Macau",
  "Taiwan",
  "Chinese Taipei"
)
panel$country_candidate_hmt <- vapply(
  panel$country_labels,
  function(labels) any(labels %in% hmt_values),
  logical(1)
)
panel$country_hmt_labels <- I(lapply(panel$country_labels, function(labels) {
  sort(unique(labels[labels %in% hmt_values]))
}))
panel$country_hmt_labels_text <- list_to_delimited(panel$country_hmt_labels)
china_candidate <- panel[panel$country_candidate_mainland, , drop = FALSE]

processed_p0_dir <- file.path(processed_dir, "p0")
saveRDS(panel, file.path(processed_p0_dir, "paper_panel_mapped.rds"))
saveRDS(
  china_candidate,
  file.path(processed_p0_dir, "china_candidate_panel.rds")
)

sample_flow <- data.frame(
  stage = c(
    "core_valid_doi_records",
    "descriptive_papers",
    "linkable_papers",
    "china_candidate_descriptive",
    "china_candidate_linkable",
    "china_candidate_with_hmt_co_label",
    "china_candidate_with_reason_family",
    "china_candidate_with_article_type",
    "china_candidate_with_original_year"
  ),
  papers = c(
    sum(linkable$n_notification_records) +
      sum(panel$n_notification_records[panel$doi_status == "ambiguous_doi"]),
    nrow(panel),
    nrow(linkable),
    sum(panel$country_candidate_mainland),
    nrow(china_candidate),
    sum(china_candidate$country_candidate_hmt),
    sum(
      china_candidate$reason_domain_any |
        china_candidate$family_error_control |
        china_candidate$family_unclassified
    ),
    sum(!is.na(china_candidate$article_type) & china_candidate$article_type != ""),
    sum(!is.na(china_candidate$original_paper_year_first))
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  sample_flow,
  file.path(audit_table_dir, "p0_sample_flow.csv")
)

year_counts <- as.data.frame(
  table(
    retraction_year = china_candidate$retraction_year_first,
    useNA = "no"
  )
)
names(year_counts)[[2]] <- "papers"
write_csv_utf8(
  year_counts,
  file.path(audit_table_dir, "p0_china_candidate_by_retraction_year.csv")
)

family_columns <- c(
  "family_publication_process",
  "family_image_integrity",
  "family_plagiarism_authorship",
  "family_data_integrity",
  "family_research_ethics_compliance",
  "family_materials_methods_integrity",
  "family_error_control",
  "family_unclassified"
)
family_year <- do.call(
  rbind,
  lapply(family_columns, function(column) {
    data.frame(
      reason_family = sub("^family_", "", column),
      retraction_year = china_candidate$retraction_year_first,
      flagged = china_candidate[[column]],
      stringsAsFactors = FALSE
    )
  })
)
family_year <- stats::aggregate(
  family_year$flagged,
  list(
    reason_family = family_year$reason_family,
    retraction_year = family_year$retraction_year
  ),
  sum
)
names(family_year)[[3]] <- "papers"
family_year <- family_year[family_year$papers > 0, ]
write_csv_utf8(
  family_year,
  file.path(audit_table_dir, "p0_china_candidate_family_by_year.csv")
)

family_audit <- data.frame(
  reason_family = sub("^family_", "", family_columns),
  papers = vapply(
    family_columns,
    function(column) sum(china_candidate[[column]]),
    integer(1)
  ),
  stringsAsFactors = FALSE
)
family_audit$share <- family_audit$papers / nrow(china_candidate)
family_audit <- family_audit[order(-family_audit$papers), ]
write_csv_utf8(
  family_audit,
  file.path(audit_table_dir, "p0_china_candidate_family_audit.csv")
)

publisher_audit <- as.data.frame(
  table(publisher = china_candidate$publisher),
  stringsAsFactors = FALSE
)
names(publisher_audit)[[2]] <- "papers"
publisher_audit <- publisher_audit[
  order(-publisher_audit$papers, publisher_audit$publisher),
]
publisher_audit$share <- publisher_audit$papers / nrow(china_candidate)
write_csv_utf8(
  publisher_audit,
  file.path(audit_table_dir, "p0_china_candidate_publisher_audit.csv")
)

article_type_audit <- as.data.frame(
  table(article_type = china_candidate$article_type),
  stringsAsFactors = FALSE
)
names(article_type_audit)[[2]] <- "papers"
article_type_audit <- article_type_audit[
  order(-article_type_audit$papers, article_type_audit$article_type),
]
article_type_audit$share <- article_type_audit$papers /
  nrow(china_candidate)
write_csv_utf8(
  article_type_audit,
  file.path(audit_table_dir, "p0_china_candidate_article_type_audit.csv")
)

family_matrix <- as.matrix(china_candidate[, family_columns, drop = FALSE])
family_short_names <- sub("^family_", "", family_columns)
reason_patterns <- vapply(
  seq_len(nrow(family_matrix)),
  function(index) {
    flags <- family_short_names[family_matrix[index, ]]
    if (length(flags) == 0) {
      "none"
    } else {
      paste(flags, collapse = "+")
    }
  },
  character(1)
)
pattern_audit <- as.data.frame(
  table(reason_pattern = reason_patterns),
  stringsAsFactors = FALSE
)
names(pattern_audit)[[2]] <- "papers"
pattern_audit <- pattern_audit[
  order(-pattern_audit$papers, pattern_audit$reason_pattern),
]
pattern_audit$share <- pattern_audit$papers / nrow(china_candidate)
write_csv_utf8(
  pattern_audit,
  file.path(audit_table_dir, "p0_china_candidate_reason_pattern_audit.csv")
)

country_label_rows <- unlist(panel$country_labels, use.names = FALSE)
country_label_audit <- as.data.frame(
  table(country_label = country_label_rows),
  stringsAsFactors = FALSE
)
names(country_label_audit)[[2]] <- "descriptive_papers"
write_csv_utf8(
  country_label_audit,
  file.path(audit_table_dir, "p0_country_label_audit.csv")
)

hmt_pattern <- paste(
  c(
    "Hong Kong",
    "Macao",
    "Macau",
    "Taiwan",
    "Chinese Taipei"
  ),
  collapse = "|"
)
hmt_labels <- unique(grep(
  hmt_pattern,
  country_label_rows,
  value = TRUE,
  ignore.case = TRUE
))
hmt_audit <- data.frame(
  country_label = hmt_labels,
  descriptive_papers = vapply(
    hmt_labels,
    function(label) {
      sum(vapply(
        panel$country_labels,
        function(labels) label %in% labels,
        logical(1)
      ))
    },
    integer(1)
  ),
  china_candidate_papers = vapply(
    hmt_labels,
    function(label) {
      sum(vapply(
        china_candidate$country_labels,
        function(labels) label %in% labels,
        logical(1)
      ))
    },
    integer(1)
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  hmt_audit,
  file.path(audit_table_dir, "p0_hmt_country_label_audit.csv")
)

write_audit_manifest()
message("P0 China candidate screen completed.")
