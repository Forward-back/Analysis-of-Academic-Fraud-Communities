#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

case_panel <- readRDS(file.path(
  processed_dir,
  "p0",
  "openalex_mainland_accepted_paper_panel.rds"
))
event_papers <- data.table::as.data.table(
  case_panel[case_panel$retraction_year_first == 2023L, , drop = FALSE]
)
event_papers[, retraction_date := as.Date(retraction_first_date)]
event_papers[, publisher := ifelse(
  is.na(publisher) | publisher == "",
  "(missing)",
  publisher
)]

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

event_summary <- data.frame(
  metric = c(
    "accepted_mainland_2023_papers",
    "notification_records",
    "publishers",
    "journals",
    "first_retraction_date",
    "last_retraction_date",
    "original_papers_2021",
    "original_papers_2022",
    "notifications_original_2021",
    "notifications_original_2022",
    "papers_missing_journal",
    "papers_missing_publisher"
  ),
  value = c(
    nrow(event_papers),
    sum(event_papers$n_notification_records, na.rm = TRUE),
    data.table::uniqueN(event_papers$publisher),
    data.table::uniqueN(event_papers$journal[
      !is.na(event_papers$journal) & event_papers$journal != ""
    ]),
    as.character(min(event_papers$retraction_date, na.rm = TRUE)),
    as.character(max(event_papers$retraction_date, na.rm = TRUE)),
    sum(event_papers$original_paper_year_first == 2021L, na.rm = TRUE),
    sum(event_papers$original_paper_year_first == 2022L, na.rm = TRUE),
    sum(
      event_papers$n_notification_records[
        event_papers$original_paper_year_first == 2021L
      ],
      na.rm = TRUE
    ),
    sum(
      event_papers$n_notification_records[
        event_papers$original_paper_year_first == 2022L
      ],
      na.rm = TRUE
    ),
    sum(is.na(event_papers$journal) | event_papers$journal == ""),
    sum(is.na(event_papers$publisher) | event_papers$publisher == "(missing)")
  ),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  event_summary,
  file.path(audit_table_dir, "event_2023_summary.csv")
)

monthly <- event_papers[, .(
  papers = .N,
  notification_records = sum(n_notification_records, na.rm = TRUE),
  publishers = data.table::uniqueN(publisher),
  journals = data.table::uniqueN(journal[
    !is.na(journal) & journal != ""
  ])
), by = .(month = format(retraction_date, "%Y-%m"))]
data.table::setorder(monthly, month)
write_csv_utf8(
  as.data.frame(monthly),
  file.path(audit_table_dir, "event_2023_monthly.csv")
)

publisher_summary <- event_papers[, .(
  papers = .N,
  notification_records = sum(n_notification_records, na.rm = TRUE),
  journals = data.table::uniqueN(journal[
    !is.na(journal) & journal != ""
  ]),
  first_date = as.character(min(retraction_date, na.rm = TRUE)),
  last_date = as.character(max(retraction_date, na.rm = TRUE))
), by = publisher]
publisher_summary[, paper_share := papers / sum(papers)]
publisher_summary[, record_share := notification_records /
  sum(notification_records)]
data.table::setorder(publisher_summary, -papers, publisher)
write_csv_utf8(
  as.data.frame(publisher_summary),
  file.path(audit_table_dir, "event_2023_publisher.csv")
)

journal_summary <- event_papers[, .(
  papers = .N,
  notification_records = sum(n_notification_records, na.rm = TRUE),
  publisher = publisher[[1L]]
), by = journal]
data.table::setorder(journal_summary, -papers, -notification_records, journal)
journal_summary <- journal_summary[seq_len(min(30L, .N))]
journal_summary[, rank := seq_len(.N)]
write_csv_utf8(
  as.data.frame(journal_summary),
  file.path(audit_table_dir, "event_2023_journal_top.csv")
)

original_year <- event_papers[, .(
  papers = .N,
  notification_records = sum(n_notification_records, na.rm = TRUE)
), by = original_paper_year_first]
data.table::setorder(original_year, original_paper_year_first)
write_csv_utf8(
  as.data.frame(original_year),
  file.path(audit_table_dir, "event_2023_original_year.csv")
)

family_summary <- data.table::rbindlist(
  lapply(family_columns, function(family) {
    subset <- event_papers[get(family) %in% TRUE]
    data.frame(
      analysis_family = family,
      papers = nrow(subset),
      notification_records = sum(
        subset$n_notification_records,
        na.rm = TRUE
      ),
      paper_share = nrow(subset) / nrow(event_papers),
      stringsAsFactors = FALSE
    )
  }),
  fill = TRUE
)
write_csv_utf8(
  family_summary,
  file.path(audit_table_dir, "event_2023_reason_family.csv")
)

same_day_batches <- event_papers[, .(
  papers = .N,
  notification_records = sum(n_notification_records, na.rm = TRUE),
  journals = data.table::uniqueN(journal[
    !is.na(journal) & journal != ""
  ])
), by = .(retraction_date, publisher)]
data.table::setorder(
  same_day_batches,
  -notification_records,
  -papers,
  retraction_date,
  publisher
)
write_csv_utf8(
  as.data.frame(same_day_batches),
  file.path(audit_table_dir, "event_2023_same_day_batches.csv")
)

write_audit_manifest()
message("2023 local event decomposition completed.")
