#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

snapshot_dir <- file.path(
  project_dir,
  "data",
  "external",
  "snapshots",
  "institution_tiers"
)
ensure_dir(snapshot_dir)

fetch_text <- function(url, output_path, headers = list()) {
  response <- httr::RETRY(
    "GET",
    url,
    headers,
    times = 4,
    pause_base = 2,
    pause_cap = 30,
    quiet = TRUE
  )
  status <- httr::status_code(response)
  if (status < 200L || status >= 300L) {
    return(list(
      url = url,
      path = "",
      status = status,
      ok = FALSE,
      sha256 = "",
      bytes = 0
    ))
  }
  body <- httr::content(response, as = "raw")
  writeBin(body, output_path)
  list(
    url = url,
    path = project_relative_path(output_path),
    status = status,
    ok = TRUE,
    sha256 = sha256_file(output_path),
    bytes = file.info(output_path)$size
  )
}

wiki_pages <- c(
  project_985 = "Project_985",
  project_211 = "Project_211",
  double_first_class = "Double_First-Class_Construction"
)

source_rows <- list()
for (name in names(wiki_pages)) {
  url <- httr::modify_url(
    "https://en.wikipedia.org/w/api.php",
    query = list(
      action = "parse",
      page = wiki_pages[[name]],
      prop = "wikitext",
      format = "json",
      formatversion = 2
    )
  )
  response <- httr::RETRY(
    "GET",
    url,
    times = 4,
    pause_base = 2,
    pause_cap = 30,
    quiet = TRUE
  )
  status <- httr::status_code(response)
  output_path <- file.path(
    snapshot_dir,
    paste0(name, "_", Sys.Date(), ".wikitext")
  )
  if (status == 200L) {
    parsed <- jsonlite::fromJSON(
      httr::content(response, as = "text", encoding = "UTF-8"),
      simplifyVector = FALSE
    )
    writeLines(
      parsed$parse$wikitext,
      output_path,
      useBytes = TRUE
    )
    source_rows[[length(source_rows) + 1L]] <- list(
      source_name = name,
      source_type = "wikipedia_api_wikitext",
      url = sub("&api_key=.*$", "", url),
      path = project_relative_path(output_path),
      status = status,
      ok = TRUE,
      sha256 = sha256_file(output_path),
      bytes = file.info(output_path)$size
    )
  } else {
    source_rows[[length(source_rows) + 1L]] <- list(
      source_name = name,
      source_type = "wikipedia_api_wikitext",
      url = url,
      path = "",
      status = status,
      ok = FALSE,
      sha256 = "",
      bytes = 0
    )
  }
}

official_sources <- list(
  list(
    name = "moe_double_first_class_2017",
    url = paste0(
      "https://www.moe.gov.cn/srcsite/A22/moe_843/",
      "201709/t20170921_314942.html"
    ),
    filename = "moe_double_first_class_2017.html"
  ),
  list(
    name = "moe_double_first_class_2022",
    url = paste0(
      "https://www.moe.gov.cn/srcsite/A22/s7065/",
      "202202/t20220211_598710.html"
    ),
    filename = "moe_double_first_class_2022.html"
  ),
  list(
    name = "moe_double_first_class_2022_pdf",
    url = paste0(
      "https://www.moe.gov.cn/srcsite/A22/s7065/",
      "202202/W020220214318455516037.pdf"
    ),
    filename = "moe_double_first_class_2022_list.pdf"
  )
)

for (source in official_sources) {
  output_path <- file.path(
    snapshot_dir,
    paste0(source$name, "_", Sys.Date(), "_", source$filename)
  )
  result <- fetch_text(source$url, output_path)
  source_rows[[length(source_rows) + 1L]] <- c(
    list(
      source_name = source$name,
      source_type = "official_moe"
    ),
    result
  )
}

manifest <- list(
  contract_version = "1.0",
  source_path_type = "project-relative",
  fetched_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  sources = source_rows
)
jsonlite::write_json(
  manifest,
  file.path(snapshot_dir, "manifest.json"),
  auto_unbox = TRUE,
  pretty = TRUE
)

write_csv_utf8(
  data.frame(
    source_name = vapply(
      source_rows,
      function(item) item$source_name,
      character(1)
    ),
    source_type = vapply(
      source_rows,
      function(item) item$source_type,
      character(1)
    ),
    status = vapply(
      source_rows,
      function(item) as.integer(item$status),
      integer(1)
    ),
    ok = vapply(source_rows, function(item) isTRUE(item$ok), logical(1)),
    bytes = vapply(
      source_rows,
      function(item) as.numeric(item$bytes),
      numeric(1)
    ),
    sha256 = vapply(
      source_rows,
      function(item) item$sha256,
      character(1)
    ),
    stringsAsFactors = FALSE
  ),
  file.path(audit_table_dir, "p1_tier_source_manifest.csv")
)

write_audit_manifest()
message("Institution tier sources fetched.")
