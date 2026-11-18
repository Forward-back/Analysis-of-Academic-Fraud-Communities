#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")
source("R/lib/title_similarity.R", encoding = "UTF-8")

input_path <- file.path(
  processed_dir,
  "p0",
  "openalex_mainland_paper_panel.rds"
)
if (!file.exists(input_path)) {
  stop("Run R/06_build_authorships.R first. Missing: ", input_path)
}

panel <- readRDS(input_path)
panel$title_jaccard <- token_jaccard(
  panel$title,
  panel$openalex_title
)
panel$title_containment <- token_containment(
  panel$title,
  panel$openalex_title
)
panel$title_similarity_review <- !is.na(panel$title_jaccard) &
  panel$title_jaccard < 0.5
panel$title_linkage_suspect <- !is.na(panel$title_containment) &
  panel$title_containment < 0.2

review_columns <- c(
  "paper_key",
  "doi_canonical",
  "title",
  "openalex_title",
  "retraction_year_first",
  "publication_year",
  "openalex_type",
  "reason_labels_text",
  "family_publication_process",
  "family_image_integrity",
  "family_plagiarism_authorship",
  "family_data_integrity",
  "title_jaccard",
  "title_containment",
  "title_similarity_review",
  "title_linkage_suspect"
)
review <- panel[
  which(panel$title_similarity_review),
  review_columns,
  drop = FALSE
]
review <- review[
  order(review$title_containment, review$title_jaccard, review$doi_canonical),
]
write_csv_utf8(
  review,
  file.path(audit_table_dir, "p0_openalex_title_review.csv")
)

summary <- data.frame(
  metric = c(
    "mainland_exact_works",
    "title_jaccard_available",
    "title_jaccard_below_0_5",
    "title_jaccard_below_0_3",
    "title_containment_below_0_2",
    "title_containment_below_0_5",
    "title_containment_below_0_7",
    "title_jaccard_median",
    "title_jaccard_minimum",
    "title_containment_median"
  ),
  value = c(
    nrow(panel),
    sum(!is.na(panel$title_jaccard)),
    sum(panel$title_jaccard < 0.5, na.rm = TRUE),
    sum(panel$title_jaccard < 0.3, na.rm = TRUE),
    sum(panel$title_containment < 0.2, na.rm = TRUE),
    sum(panel$title_containment < 0.5, na.rm = TRUE),
    sum(panel$title_containment < 0.7, na.rm = TRUE),
    stats::median(panel$title_jaccard, na.rm = TRUE),
    min(panel$title_jaccard, na.rm = TRUE),
    stats::median(panel$title_containment, na.rm = TRUE)
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  summary,
  file.path(audit_table_dir, "p0_openalex_title_review_summary.csv")
)

write_audit_manifest()
message("P0 OpenAlex title audit completed.")
