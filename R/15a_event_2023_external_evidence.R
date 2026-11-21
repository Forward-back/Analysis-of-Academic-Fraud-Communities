#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

sources <- data.table::fread(
  file.path(
    project_dir,
    "data",
    "reference",
    "event_2023_external_sources.csv"
  ),
  encoding = "UTF-8",
  data.table = FALSE
)
claims <- data.table::fread(
  file.path(
    project_dir,
    "data",
    "reference",
    "event_2023_external_claims.csv"
  ),
  encoding = "UTF-8",
  data.table = FALSE
)
event_summary <- utils::read.csv(
  file.path(audit_table_dir, "event_2023_summary.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
event_monthly <- utils::read.csv(
  file.path(audit_table_dir, "event_2023_monthly.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
same_day_batches <- utils::read.csv(
  file.path(audit_table_dir, "event_2023_same_day_batches.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
event_family <- utils::read.csv(
  file.path(audit_table_dir, "event_2023_reason_family.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
event_publisher <- utils::read.csv(
  file.path(audit_table_dir, "event_2023_publisher.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

assert_columns(
  sources,
  c(
    "source_id",
    "source_type",
    "organization",
    "title",
    "published_date",
    "url",
    "access_status",
    "trust_tier",
    "accessed_date"
  ),
  "external source registry"
)
assert_columns(
  claims,
  c(
    "claim_id",
    "source_id",
    "claim_date",
    "mechanism_category",
    "claim_summary_zh",
    "quote_original",
    "local_alignment",
    "interpretation_limit",
    "verification_note"
  ),
  "external claim registry"
)

if (anyDuplicated(sources$source_id)) {
  stop("External source IDs must be unique.")
}
if (anyDuplicated(claims$claim_id)) {
  stop("External claim IDs must be unique.")
}
unknown_sources <- setdiff(unique(claims$source_id), sources$source_id)
if (length(unknown_sources) > 0L) {
  stop("Claims reference unknown source IDs: ", paste(
    unknown_sources,
    collapse = ", "
  ))
}
if (any(!nzchar(claims$quote_original))) {
  stop("Every external claim requires an original-language quote.")
}
if (any(!nzchar(claims$local_alignment))) {
  stop("Every external claim requires a local alignment note.")
}

sources$published_date <- as.Date(sources$published_date)
sources$accessed_date <- as.Date(sources$accessed_date)
claims$claim_date <- as.Date(claims$claim_date)
if (any(is.na(sources$published_date))) {
  stop("External source dates must use ISO YYYY-MM-DD format.")
}
if (any(is.na(claims$claim_date))) {
  stop("External claim dates must use ISO YYYY-MM-DD format.")
}

external_evidence <- merge(
  claims,
  sources,
  by = "source_id",
  all.x = TRUE,
  sort = FALSE
)
external_evidence <- external_evidence[
  order(external_evidence$claim_date, external_evidence$claim_id),
  ,
  drop = FALSE
]
external_evidence$access_or_archive_url <- ifelse(
  is.na(external_evidence$archive_url) |
    external_evidence$archive_url == "",
  external_evidence$url,
  external_evidence$archive_url
)

event_summary_values <- setNames(
  event_summary$value,
  event_summary$metric
)
event_family_values <- setNames(
  event_family$paper_share,
  event_family$analysis_family
)
hindawi_2023_papers <- event_publisher$papers[
  event_publisher$publisher == "Hindawi"
]
if (length(hindawi_2023_papers) != 1L) {
  stop("Expected one Hindawi publisher row in the 2023 event table.")
}

external_timeline <- data.frame(
  date = external_evidence$claim_date,
  timeline_type = "external",
  organization = external_evidence$organization,
  event = external_evidence$claim_summary_zh,
  count = NA_integer_,
  evidence_id = external_evidence$claim_id,
  source_or_output = external_evidence$access_or_archive_url,
  notes = external_evidence$interpretation_limit,
  stringsAsFactors = FALSE
)

local_monthly_timeline <- data.frame(
  date = as.Date(paste0(event_monthly$month, "-01")),
  timeline_type = "local_month",
  organization = "OpenAlex mainland analysis sample",
  event = "Monthly retraction papers",
  count = event_monthly$papers,
  evidence_id = paste0("local_month_", event_monthly$month),
  source_or_output = "data/outputs/audits/tables/event_2023_monthly.csv",
  notes = "Notification month, not original publication month.",
  stringsAsFactors = FALSE
)

top_batches <- same_day_batches[
  order(
    -same_day_batches$notification_records,
    -same_day_batches$papers,
    same_day_batches$retraction_date,
    same_day_batches$publisher
  ),
  ,
  drop = FALSE
]
top_batches <- head(top_batches, 10L)
local_batch_timeline <- data.frame(
  date = as.Date(top_batches$retraction_date),
  timeline_type = "local_same_day_batch",
  organization = top_batches$publisher,
  event = "Same-day publisher retraction batch",
  count = top_batches$papers,
  evidence_id = paste0(
    "local_batch_",
    top_batches$retraction_date,
    "_",
    seq_len(nrow(top_batches))
  ),
  source_or_output = "data/outputs/audits/tables/event_2023_same_day_batches.csv",
  notes = paste0(
    top_batches$journals,
    " journals in the batch"
  ),
  stringsAsFactors = FALSE
)

timeline <- rbind(
  external_timeline,
  local_monthly_timeline,
  local_batch_timeline
)
timeline <- timeline[order(timeline$date, timeline$timeline_type), , drop = FALSE]

mechanism_map <- data.frame(
  mechanism_category = c(
    "peer_review_manipulation",
    "paper_mill_special_issue_infiltration",
    "journal_closure",
    "index_curation",
    "publisher_financial_and_portfolio_response",
    "large_scale_retraction_reporting",
    "global_event_context"
  ),
  supporting_claim_ids = c(
    "C10",
    "C02;C04;C08",
    "C01;C02",
    "C03;C05",
    "C06;C07;C11",
    "C04;C09;C13",
    "C12"
  ),
  supports = c(
    "Publisher identified compromised peer review in special issues.",
    "Publisher described large-scale paper-mill infiltration of special issues.",
    "Four heavily compromised journals were closed in May 2023.",
    "External index and publisher sources document journal-quality actions.",
    "Wiley reported financial impact, brand integration and tightened processes.",
    "Publisher and independent sources report thousands of retractions.",
    "2023 was a global retraction-record year."
  ),
  does_not_support = c(
    "Does not identify authors or estimate misconduct prevalence.",
    "Does not imply all special-issue papers were manipulated.",
    "Does not prove that closure caused later notification batches.",
    "Does not estimate China-specific incidence.",
    "Does not convert revenue loss into a risk score.",
    "Does not replace DOI-level local counts.",
    "Does not identify China-specific cause or rate."
  ),
  stringsAsFactors = FALSE
)

counterfactual_boundaries <- data.frame(
  boundary_id = paste0("B", sprintf("%02d", seq_len(6L))),
  boundary = c(
    "No national incidence estimate",
    "No China-specific causal attribution",
    "No causal effect of journal closure on batch timing",
    "No direct count reconciliation across sources",
    "Notification date is not problem date",
    "Publisher concentration is not responsibility"
  ),
  statement = c(
    "The 2023 peak is a retraction-notice and publisher-cleanup event, not a population incidence estimate.",
    "External sources describe a global publisher problem; they do not measure China's misconduct rate.",
    "Temporal ordering alone cannot identify whether closures changed later notification counts.",
    "The 8,036 local Hindawi main-analysis count, 8,000+ external count and 10,028 event sample use different scopes.",
    "The original paper year and retraction notification year must be reported separately.",
    "Hindawi concentration identifies governance exposure, not author or institution responsibility."
  ),
  stringsAsFactors = FALSE
)

h4_evidence <- data.frame(
  hypothesis = "H4",
  status = "supported_as_publisher_cleanup_event_not_national_incidence",
  evidence = paste0(
    "Officially documented Hindawi special-issue and peer-review actions precede ",
    "the largest local batches. The local 2023 event sample contains 8,036 ",
    "Hindawi papers out of 10,028 (80.14%), and publication-process labels ",
    "cover 71.02%. External sources do not support interpreting the peak as a ",
    "China-specific misconduct rate."
  ),
  stringsAsFactors = FALSE
)

claim_quality <- data.frame(
  claim_id = external_evidence$claim_id,
  has_quote = nzchar(external_evidence$quote_original),
  has_local_alignment = nzchar(external_evidence$local_alignment),
  has_boundary = nzchar(external_evidence$interpretation_limit),
  source_id_valid = external_evidence$source_id %in% sources$source_id,
  url_present = nzchar(external_evidence$url),
  access_recorded = nzchar(external_evidence$access_status),
  archive_recorded = nzchar(external_evidence$archive_url),
  stringsAsFactors = FALSE
)

local_top_batch_count <- max(top_batches$papers, na.rm = TRUE)
validation <- data.frame(
  metric = c(
    "sources",
    "claims",
    "primary_sources",
    "secondary_sources",
    "sources_with_archive",
    "claims_with_quote",
    "claims_with_local_alignment",
    "mechanism_categories",
    "counterfactual_boundaries",
    "external_date_min",
    "external_date_max",
    "local_2023_papers",
    "local_hindawi_2023_papers",
    "local_hindawi_share",
    "local_publication_process_share",
    "largest_same_day_batch"
  ),
  value = c(
    nrow(sources),
    nrow(claims),
    sum(sources$trust_tier == "tier1_primary"),
    sum(startsWith(sources$trust_tier, "tier2")),
    sum(!is.na(sources$archive_url) & sources$archive_url != ""),
    sum(nzchar(claims$quote_original)),
    sum(nzchar(claims$local_alignment)),
    nrow(mechanism_map),
    nrow(counterfactual_boundaries),
    as.character(min(claims$claim_date)),
    as.character(max(claims$claim_date)),
    as.integer(event_summary_values[["accepted_mainland_2023_papers"]]),
    as.integer(hindawi_2023_papers),
    as.numeric(hindawi_2023_papers) /
      as.numeric(event_summary_values[["accepted_mainland_2023_papers"]]),
    as.numeric(event_family_values[["family_publication_process"]]),
    local_top_batch_count
  ),
  stringsAsFactors = FALSE
)

write_csv_utf8(
  external_evidence,
  file.path(audit_table_dir, "event_2023_external_evidence.csv")
)
write_csv_utf8(
  timeline,
  file.path(audit_table_dir, "event_2023_external_timeline.csv")
)
write_csv_utf8(
  mechanism_map,
  file.path(audit_table_dir, "event_2023_mechanism_map.csv")
)
write_csv_utf8(
  counterfactual_boundaries,
  file.path(audit_table_dir, "event_2023_counterfactual_boundaries.csv")
)
write_csv_utf8(
  h4_evidence,
  file.path(audit_table_dir, "event_2023_hypothesis_evidence.csv")
)
write_csv_utf8(
  claim_quality,
  file.path(audit_table_dir, "event_2023_external_claim_quality.csv")
)
write_csv_utf8(
  validation,
  file.path(audit_table_dir, "event_2023_external_validation.csv")
)

snapshot_manifest_path <- file.path(
  project_dir,
  "data",
  "external",
  "snapshots",
  "event_2023",
  "manifest.json"
)
snapshot_files <- c(
  file.path(
    project_dir,
    "data",
    "reference",
    "event_2023_external_sources.csv"
  ),
  file.path(
    project_dir,
    "data",
    "reference",
    "event_2023_external_claims.csv"
  ),
  file.path(
    audit_table_dir,
    "event_2023_external_evidence.csv"
  ),
  file.path(
    audit_table_dir,
    "event_2023_external_timeline.csv"
  ),
  file.path(
    audit_table_dir,
    "event_2023_mechanism_map.csv"
  ),
  file.path(
    audit_table_dir,
    "event_2023_counterfactual_boundaries.csv"
  ),
  file.path(
    audit_table_dir,
    "event_2023_hypothesis_evidence.csv"
  )
)
jsonlite::write_json(
  list(
    contract_version = "1.0",
    artifact = "event-2023-external-evidence",
    accessed_on = "2026-11-21",
    files = lapply(snapshot_files, function(path) {
      list(
        path = project_relative_path(path),
        sha256 = sha256_canonical_file(path)
      )
    })
  ),
  snapshot_manifest_path,
  auto_unbox = TRUE,
  pretty = TRUE
)

write_audit_manifest()
message("2023 external evidence and counterfactual boundaries completed.")
