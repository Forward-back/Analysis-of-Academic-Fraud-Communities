#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

snapshot_dir <- file.path(
  project_dir,
  "data",
  "external",
  "snapshots",
  "institution_tiers"
)
latest_snapshot <- function(prefix) {
  files <- list.files(
    snapshot_dir,
    pattern = paste0("^", prefix, "_.*\\.wikitext$"),
    full.names = TRUE
  )
  if (length(files) == 0) {
    stop("Missing snapshot for ", prefix)
  }
  files[order(file.mtime(files), decreasing = TRUE)][[1]]
}

read_snapshot <- function(prefix) {
  readLines(
    latest_snapshot(prefix),
    warn = FALSE,
    encoding = "UTF-8"
  )
}

extract_wiki_link <- function(text) {
  matches <- regmatches(
    text,
    gregexpr("\\[\\[([^\\]]+)\\]\\]", text, perl = TRUE)
  )[[1]]
  if (length(matches) == 0L || identical(matches, character(0))) {
    return(character())
  }
  values <- sub("^\\[\\[", "", matches)
  values <- sub("\\]\\]$", "", values)
  targets <- sub("\\|.*$", "", values)
  displays <- ifelse(
    grepl("\\|", values),
    sub("^.*\\|", "", values),
    targets
  )
  unique(c(displays, targets))
}

make_tier_rows <- function(lines, tier_name, pattern, phase2 = FALSE) {
  matched <- grep(pattern, lines, value = TRUE, perl = TRUE)
  rows <- lapply(matched, function(line) {
    values <- extract_wiki_link(line)
    if (length(values) == 0L) {
      return(NULL)
    }
    if (!grepl(
      "University|College|Academy|Institute|Conservatory",
      paste(values, collapse = " "),
      ignore.case = TRUE
    )) {
      return(NULL)
    }
    data.frame(
      tier_name = tier_name,
      university_name = values[[1]],
      aliases = paste(unique(values), collapse = ";"),
      phase2_addition = if (phase2) {
        grepl("\\{\\{efn\\|name=phase-2", line, fixed = TRUE)
      } else {
        FALSE
      },
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, Filter(Negate(is.null), rows))
  result <- result[!duplicated(result$university_name), , drop = FALSE]
  result
}

project_985_lines <- read_snapshot("project_985")
project_211_lines <- read_snapshot("project_211")
double_first_class_lines <- read_snapshot("double_first_class")

project_985 <- make_tier_rows(
  project_985_lines,
  "985",
  "^\\|\\[\\[[^\\]]+\\]\\][[:space:]]*$"
)
project_211 <- make_tier_rows(
  project_211_lines,
  "211",
  "^\\*\\*\\*?.*\\[\\["
)

phase2_chinese_names <- c(
  "\u5357\u4eac\u533b\u79d1\u5927\u5b66",
  "\u4e0a\u6d77\u79d1\u6280\u5927\u5b66",
  "\u5e7f\u5dde\u533b\u79d1\u5927\u5b66",
  "\u534e\u5357\u519c\u4e1a\u5927\u5b66",
  "\u5357\u65b9\u79d1\u6280\u5927\u5b66",
  "\u6e58\u6f6d\u5927\u5b66",
  "\u5c71\u897f\u5927\u5b66"
)

pdf_file <- list.files(
  snapshot_dir,
  pattern = "moe_double_first_class_2022_list.*\\.pdf$",
  full.names = TRUE
)
if (length(pdf_file) == 0L) {
  stop("Official 2022 Double First-Class PDF not found.")
}
pdf_text_path <- file.path(
  interim_dir,
  "p1",
  "moe_double_first_class_2022_list.txt"
)
ensure_dir(dirname(pdf_text_path))
system2(
  "pdftotext",
  c("-layout", "-enc", "UTF-8", pdf_file[[1]], pdf_text_path),
  stdout = FALSE,
  stderr = FALSE
)
pdf_text <- readLines(
  pdf_text_path,
  warn = FALSE,
  encoding = "UTF-8"
)
chinese_names <- vapply(
  pdf_text,
  function(line) {
    line <- gsub("[[:cntrl:]]+", "", line, perl = TRUE)
    values <- strsplit(
      trimws(line),
      intToUtf8(0xFF1A),
      fixed = TRUE
    )[[1]]
    if (length(values) >= 2L && nzchar(trimws(values[[1]]))) {
      trimws(values[[1]])
    } else {
      NA_character_
    }
  },
  character(1)
)
chinese_names <- sort(unique(chinese_names[
  !is.na(chinese_names) & nzchar(chinese_names)
]))
if (length(chinese_names) != 147L) {
  stop("Official Double First-Class PDF did not yield 147 university names.")
}

query_chinese_wiki <- function(titles) {
  response <- httr::RETRY(
    "GET",
    "https://zh.wikipedia.org/w/api.php",
    query = list(
      action = "query",
      prop = "langlinks",
      lllang = "en",
      titles = paste(titles, collapse = "|"),
      redirects = 1,
      converttitles = 1,
      format = "json",
      formatversion = 2
    ),
    times = 4,
    pause_base = 2,
    quiet = TRUE
  )
  if (httr::status_code(response) != 200L) {
    stop("Chinese Wikipedia title resolution failed.")
  }
  jsonlite::fromJSON(
    httr::content(response, as = "text", encoding = "UTF-8"),
    simplifyVector = FALSE
  )
}

chinese_to_english <- setNames(
  rep(NA_character_, length(chinese_names)),
  chinese_names
)
translation_path <- file.path(
  interim_dir,
  "mappings",
  "double_first_class_translation_v1.csv"
)
if (file.exists(translation_path)) {
  cached_translation <- data.table::fread(
    translation_path,
    colClasses = "character",
    encoding = "UTF-8",
    data.table = FALSE
  )
  cached_match <- match(
    chinese_names,
    cached_translation$source_chinese_name
  )
  cached_values <- cached_translation$english_name[cached_match]
  cached_values[is.na(cached_values) | cached_values == ""] <- NA_character_
  chinese_to_english[] <- cached_values
}

for (index in which(is.na(chinese_to_english))) {
  result <- query_chinese_wiki(chinese_names[[index]])
  page <- result$query$pages[[1]]
  links <- page$langlinks
  if (!is.null(links) && length(links) > 0L) {
    chinese_to_english[[index]] <- links[[1]]$title
  }
  Sys.sleep(0.05)
}
translation_table <- data.frame(
  source_chinese_name = chinese_names,
  english_name = unname(chinese_to_english),
  translated = !is.na(chinese_to_english),
  stringsAsFactors = FALSE
)
write_csv_utf8(
  translation_table,
  translation_path
)

dfc_2022 <- data.frame(
  tier_name = "double_first_class_2022",
  university_name = unname(chinese_to_english[chinese_names]),
  aliases = unname(chinese_to_english[chinese_names]),
  phase2_addition = chinese_names %in% phase2_chinese_names,
  stringsAsFactors = FALSE
)
names(dfc_2022)[[2]] <- "university_name"
names(dfc_2022)[[3]] <- "aliases"
dfc_2022$source_chinese_name <- chinese_names
dfc_2022$university_name[
  is.na(dfc_2022$university_name)
] <- dfc_2022$source_chinese_name[
  is.na(dfc_2022$university_name)
]
dfc_2022$aliases[
  is.na(dfc_2022$aliases)
] <- dfc_2022$source_chinese_name[
  is.na(dfc_2022$aliases)
]

dfc_2017 <- dfc_2022[!dfc_2022$phase2_addition, , drop = FALSE]
dfc_2017$tier_name <- "double_first_class_2017"
dfc_2017$phase2_addition <- FALSE

tier_lists <- data.table::rbindlist(
  list(project_985, project_211, dfc_2017, dfc_2022),
  fill = TRUE
)
tier_lists <- as.data.frame(tier_lists)

expected_counts <- c(
  `985` = 39L,
  `211` = 116L,
  double_first_class_2017 = 140L,
  double_first_class_2022 = 147L
)
observed_counts <- table(tier_lists$tier_name)
count_audit <- data.frame(
  tier_name = names(expected_counts),
  expected = as.integer(expected_counts),
  observed = as.integer(observed_counts[names(expected_counts)]),
  stringsAsFactors = FALSE
)
count_audit$pass <- count_audit$expected == count_audit$observed
write_csv_utf8(
  count_audit,
  file.path(audit_table_dir, "p1_tier_list_count_audit.csv")
)
if (!all(count_audit$pass)) {
  stop("Tier list extraction counts do not match the frozen expectations.")
}

institutions <- readRDS(file.path(
  processed_dir,
  "p1",
  "openalex_institutions.rds"
))
cn_institutions <- institutions[
  which(institutions$country_code == "CN"),
  ,
  drop = FALSE
]
alias_file <- file.path(
  project_dir,
  "data",
  "reference",
  "mappings",
  "institution_tier_aliases_v1.csv"
)
tier_aliases <- data.table::fread(
  alias_file,
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
invalid_alias_ids <- tier_aliases$openalex_institution_id[
  !is.na(tier_aliases$openalex_institution_id) &
    tier_aliases$openalex_institution_id != "" &
    !tier_aliases$openalex_institution_id %in% cn_institutions$institution_id
]
if (length(invalid_alias_ids) > 0L) {
  stop(
    "Manual tier aliases reference unknown institution IDs: ",
    paste(invalid_alias_ids, collapse = ", ")
  )
}

normalize_school <- function(value) {
  value <- tolower(value)
  value <- gsub("&", " and ", value, fixed = TRUE)
  value <- gsub("\\([^)]*\\)", " ", value, perl = TRUE)
  value <- gsub("[^[:alnum:]]+", " ", value, perl = TRUE)
  value <- gsub("\\b(the|of|and|at|in)\\b", " ", value, perl = TRUE)
  value <- gsub("\\buniversity\\b", " university ", value, perl = TRUE)
  value <- gsub("\\bcollege\\b", " college ", value, perl = TRUE)
  value <- gsub("\\s+", " ", value)
  trimws(value)
}

institution_norm <- normalize_school(cn_institutions$institution_name)
names(institution_norm) <- cn_institutions$institution_id

match_rows <- list()
for (index in seq_len(nrow(tier_lists))) {
  aliases <- unique(strsplit(tier_lists$aliases[[index]], ";", fixed = TRUE)[[1]])
  source_name <- tier_lists$source_chinese_name[[index]]
  alias_row <- tier_aliases[
    which(
      tier_aliases$list_university_name ==
        tier_lists$university_name[[index]] |
        (
          !is.na(source_name) &
            nzchar(source_name) &
            tier_aliases$source_chinese_name == source_name
        )
    ),
    ,
    drop = FALSE
  ]
  alias_row <- alias_row[
    !is.na(alias_row$status) & alias_row$status == "reviewed",
    ,
    drop = FALSE
  ]
  if (nrow(alias_row) > 0L) {
    alias_row <- alias_row[1, , drop = FALSE]
  }

  alias_norm <- unique(normalize_school(aliases))
  alias_norm <- alias_norm[nzchar(alias_norm)]
  if (length(alias_norm) == 0L) {
    zero_method <- "untranslated"
    zero_id <- NA_character_
    if (nrow(alias_row) > 0L) {
      if (
        !is.na(alias_row$openalex_institution_id[[1]]) &&
          alias_row$openalex_institution_id[[1]] != ""
      ) {
        zero_method <- "manual_alias"
        zero_id <- alias_row$openalex_institution_id[[1]]
      } else {
        zero_method <- "not_in_sample"
      }
    }
    match_rows[[length(match_rows) + 1L]] <- data.frame(
      tier_name = tier_lists$tier_name[[index]],
      university_name = tier_lists$university_name[[index]],
      aliases = tier_lists$aliases[[index]],
      source_chinese_name = if ("source_chinese_name" %in% names(tier_lists)) {
        tier_lists$source_chinese_name[[index]]
      } else {
        NA_character_
      },
      openalex_institution_id = zero_id,
      openalex_institution_name = if (is.na(zero_id)) {
        NA_character_
      } else {
        cn_institutions$institution_name[
          match(zero_id, cn_institutions$institution_id)
        ]
      },
      match_method = zero_method,
      match_score = NA_real_,
      stringsAsFactors = FALSE
    )
    next
  }

  exact_ids <- names(institution_norm)[institution_norm %in% alias_norm]

  method <- "exact"
  score <- 0
  best_id <- if (length(exact_ids) > 0L) exact_ids[[1]] else NA_character_
  if (is.na(best_id)) {
    if (nrow(alias_row) > 0L) {
      if (
        !is.na(alias_row$openalex_institution_id[[1]]) &&
          alias_row$openalex_institution_id[[1]] != ""
      ) {
        best_id <- alias_row$openalex_institution_id[[1]]
        method <- "manual_alias"
      } else {
        method <- "not_in_sample"
      }
    } else {
      method <- "unmatched"
    }
  }

  match_rows[[length(match_rows) + 1L]] <- data.frame(
    tier_name = tier_lists$tier_name[[index]],
    university_name = tier_lists$university_name[[index]],
    aliases = tier_lists$aliases[[index]],
    source_chinese_name = if ("source_chinese_name" %in% names(tier_lists)) {
      tier_lists$source_chinese_name[[index]]
    } else {
      NA_character_
    },
    openalex_institution_id = best_id,
    openalex_institution_name = if (is.na(best_id)) {
      NA_character_
    } else {
      cn_institutions$institution_name[
        match(best_id, cn_institutions$institution_id)
      ]
    },
    match_method = method,
    match_score = score,
    stringsAsFactors = FALSE
  )
}

tier_candidates <- do.call(rbind, match_rows)

interim_mapping_dir <- file.path(interim_dir, "mappings")
ensure_dir(interim_mapping_dir)
write_csv_utf8(
  tier_candidates,
  file.path(interim_mapping_dir, "institution_tier_candidates_v1.csv")
)

match_audit <- aggregate(
  tier_candidates$university_name,
  list(
    tier_name = tier_candidates$tier_name,
    match_method = tier_candidates$match_method
  ),
  length
)
names(match_audit)[[3]] <- "universities"
write_csv_utf8(
  match_audit,
  file.path(audit_table_dir, "p1_tier_name_match_audit.csv")
)
write_csv_utf8(
  tier_candidates[
    tier_candidates$match_method != "exact",
    ,
    drop = FALSE
  ],
  file.path(audit_table_dir, "p1_tier_name_review.csv")
)

write_audit_manifest()
message("Institution tier candidates built.")
