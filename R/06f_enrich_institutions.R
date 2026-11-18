#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

institutions <- readRDS(file.path(
  processed_dir,
  "p1",
  "openalex_institutions.rds"
))
authorships <- readRDS(file.path(
  processed_dir,
  "p0",
  "mainland_authorships_long.rds"
))
mainland_panel <- readRDS(file.path(
  processed_dir,
  "p0",
  "openalex_mainland_accepted_paper_panel.rds"
))
institution_complete_panel <- readRDS(file.path(
  processed_dir,
  "p0",
  "openalex_mainland_institution_complete_paper_panel.rds"
))

tier_registry <- data.table::fread(
  file.path(
    project_dir,
    "data",
    "reference",
    "mappings",
    "institution_tier_registry_v1.csv"
  ),
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)
region_registry <- data.table::fread(
  file.path(
    project_dir,
    "data",
    "reference",
    "mappings",
    "china_region_codes_v1.csv"
  ),
  colClasses = "character",
  encoding = "UTF-8",
  data.table = FALSE
)

institutions$region[
  is.na(institutions$region) & institutions$city == "Hong Kong"
] <- "Hong Kong"
institutions$region[
  is.na(institutions$region) & institutions$city %in% c("Macau", "Macao")
] <- "Macau"

region_match <- match(institutions$region, region_registry$region_label)
institutions$region_code <- region_registry$region_code[region_match]
institutions$province_name_zh <- region_registry$region_name_zh[region_match]
institutions$region_type <- region_registry$region_type[region_match]
institutions$effective_country_code <- institutions$country_code
institutions$effective_country_code[
  institutions$region %in% c("Hong Kong")
] <- "HK"
institutions$effective_country_code[
  institutions$region %in% c("Macau", "Macao")
] <- "MO"
institutions$region_code[
  is.na(institutions$region_code) &
    institutions$effective_country_code == "HK"
] <- "HK-HK"
institutions$region_code[
  is.na(institutions$region_code) &
    institutions$effective_country_code == "MO"
] <- "MO-MO"
institutions$region_code[
  is.na(institutions$region_code) &
    institutions$effective_country_code == "TW"
] <- "TW-TW"
institutions$province_name_zh[
  is.na(institutions$province_name_zh) &
    institutions$effective_country_code == "HK"
] <- "\u9999\u6e2f"
institutions$province_name_zh[
  is.na(institutions$province_name_zh) &
    institutions$effective_country_code == "MO"
] <- "\u6fb3\u95e8"
institutions$province_name_zh[
  is.na(institutions$province_name_zh) &
    institutions$effective_country_code == "TW"
] <- "\u53f0\u6e7e"
institutions$region_type[
  is.na(institutions$region_type) &
    institutions$effective_country_code == "HK"
] <- "special_administrative_region"
institutions$region_type[
  is.na(institutions$region_type) &
    institutions$effective_country_code == "MO"
] <- "special_administrative_region"
institutions$region_type[
  is.na(institutions$region_type) &
    institutions$effective_country_code == "TW"
] <- "separate_region"

institutions$tier_985 <- institutions$institution_id %in% tier_registry$
  openalex_institution_id[tier_registry$tier_name == "985"]
institutions$tier_211 <- institutions$institution_id %in% tier_registry$
  openalex_institution_id[tier_registry$tier_name == "211"]
institutions$tier_double_first_class_2017 <-
  institutions$institution_id %in% tier_registry$openalex_institution_id[
    tier_registry$tier_name == "double_first_class_2017"
  ]
institutions$tier_double_first_class_2022 <-
  institutions$institution_id %in% tier_registry$openalex_institution_id[
    tier_registry$tier_name == "double_first_class_2022"
  ]
institutions$is_mainland_institution <-
  institutions$effective_country_code == "CN"
institutions$is_hmt_institution <-
  institutions$effective_country_code %in% c("HK", "MO", "TW")
institutions$is_foreign_institution <-
  !institutions$is_mainland_institution &
  !institutions$is_hmt_institution

saveRDS(
  institutions,
  file.path(processed_dir, "p1", "institutions_enriched.rds")
)

region_audit <- as.data.frame(
  table(
    region_label = institutions$region[
      institutions$effective_country_code %in% c("CN", "HK", "MO", "TW")
    ],
    useNA = "ifany"
  ),
  stringsAsFactors = FALSE
)
names(region_audit)[[2]] <- "institutions"
region_audit$region_code <- region_registry$region_code[
  match(region_audit$region_label, region_registry$region_label)
]
region_audit <- merge(
  region_audit[, c("region_label", "institutions"), drop = FALSE],
  unique(institutions[
    ,
    c(
      "region",
      "region_code",
      "effective_country_code"
    ),
    drop = FALSE
  ]),
  by.x = "region_label",
  by.y = "region",
  all.x = TRUE,
  sort = FALSE
)
region_audit$mapped <- !is.na(region_audit$region_code)
write_csv_utf8(
  region_audit,
  file.path(audit_table_dir, "p1_region_mapping_audit.csv")
)

authorship_dt <- data.table::as.data.table(authorships)
authorship_dt[, authorship_row_id := seq_len(.N)]
institution_long <- authorship_dt[
  ,
  {
    ids <- institution_ids[[1]]
    if (length(ids) == 0L) {
      list(
        institution_id = character(),
        institution_order = integer()
      )
    } else {
      list(
        institution_id = ids,
        institution_order = seq_along(ids)
      )
    }
  },
  by = .(
    authorship_row_id,
    paper_key,
    author_order,
    author_id,
    author_name,
    is_corresponding
  )
]

institution_columns <- c(
  "institution_id",
  "institution_name",
  "ror_id",
  "country_code",
  "effective_country_code",
  "region",
  "region_code",
  "province_name_zh",
  "region_type",
  "city",
  "latitude",
  "longitude",
  "is_mainland_institution",
  "is_hmt_institution",
  "is_foreign_institution",
  "tier_985",
  "tier_211",
  "tier_double_first_class_2017",
  "tier_double_first_class_2022"
)
institution_long <- merge(
  institution_long,
  institutions[, institution_columns, drop = FALSE],
  by = "institution_id",
  all.x = TRUE,
  sort = FALSE
)

year_lookup <- mainland_panel[
  ,
  c("paper_key", "original_paper_year_first", "retraction_year_first"),
  drop = FALSE
]
institution_long <- merge(
  institution_long,
  year_lookup,
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)

institution_long$tier_rule <- ifelse(
  is.na(institution_long$original_paper_year_first),
  "unknown",
  ifelse(
    institution_long$original_paper_year_first <= 2016,
    "985_211_2016",
    ifelse(
      institution_long$original_paper_year_first <= 2021,
      "double_first_class_2017_2021",
      "double_first_class_2022_2025"
    )
  )
)
institution_long$national_key_institution <- ifelse(
  institution_long$tier_rule == "985_211_2016",
  institution_long$tier_985 | institution_long$tier_211,
  ifelse(
    institution_long$tier_rule == "double_first_class_2017_2021",
    institution_long$tier_double_first_class_2017,
    ifelse(
      institution_long$tier_rule == "double_first_class_2022_2025",
      institution_long$tier_double_first_class_2022,
      FALSE
    )
  )
)
institution_long$national_key_institution[
  !institution_long$is_mainland_institution
] <- FALSE
institution_long$legacy_985_211_institution <-
  institution_long$is_mainland_institution &
  (institution_long$tier_985 | institution_long$tier_211)
institution_long$tier_level <- ifelse(
  !institution_long$is_mainland_institution,
  ifelse(
    institution_long$is_hmt_institution,
    "hmt",
    "foreign"
  ),
  ifelse(
    institution_long$tier_rule == "985_211_2016",
    ifelse(
      institution_long$tier_985,
      "985",
      ifelse(institution_long$tier_211, "211", "non_national")
    ),
    ifelse(
      institution_long$national_key_institution,
      "double_first_class",
      "non_national"
    )
  )
)

saveRDS(
  institution_long,
  file.path(processed_dir, "p1", "author_institution_long.rds")
)

paper_institution <- institution_long[
  ,
  {
    mainland_rows <- .SD[is_mainland_institution == TRUE]
    hmt_rows <- .SD[is_hmt_institution == TRUE]
    foreign_rows <- .SD[is_foreign_institution == TRUE]
    normal_mainland <- mainland_rows
    city_count <- length(unique(normal_mainland$city[
      !is.na(normal_mainland$city)
    ]))
    region_count <- length(unique(normal_mainland$region_code[
      !is.na(normal_mainland$region_code)
    ]))
    geo_level <- if (nrow(foreign_rows) > 0L) {
      "international"
    } else if (nrow(hmt_rows) > 0L) {
      "hmt_involved"
    } else if (city_count <= 1L) {
      "single_city"
    } else if (region_count <= 1L) {
      "same_province_multi_city"
    } else {
      "domestic_cross_province"
    }
    national_key_count <- length(unique(
      mainland_rows$institution_id[
        mainland_rows$national_key_institution
      ]
    ))
    non_national_mainland_count <- length(unique(
      mainland_rows$institution_id[
        !mainland_rows$national_key_institution
      ]
    ))
    list(
      n_institution_links = .N,
      n_unique_institutions = length(unique(institution_id)),
      n_mainland_institutions = length(unique(mainland_rows$institution_id)),
      n_hmt_institutions = length(unique(hmt_rows$institution_id)),
      n_foreign_institutions = length(unique(foreign_rows$institution_id)),
      national_key_institution_count = national_key_count,
      non_national_mainland_institution_count =
        non_national_mainland_count,
      national_key_present = national_key_count > 0L,
      non_national_mainland_present = non_national_mainland_count > 0L,
      cross_tier = national_key_count > 0L &&
        non_national_mainland_count > 0L,
      legacy_985_211_cross_tier = any(
        mainland_rows$legacy_985_211_institution
      ) && any(!mainland_rows$legacy_985_211_institution),
      institution_hmt_present = nrow(hmt_rows) > 0L,
      institution_foreign_present = nrow(foreign_rows) > 0L,
      geo_level = geo_level,
      main_city_count = city_count,
      main_region_count = region_count,
      tier_rule = tier_rule[[1]]
    )
  },
  by = paper_key
]

paper_institution <- as.data.frame(paper_institution)
enriched_panel <- merge(
  institution_complete_panel,
  paper_institution,
  by = "paper_key",
  all.x = TRUE,
  sort = FALSE
)
enriched_panel$cross_tier[is.na(enriched_panel$cross_tier)] <- FALSE
enriched_panel$national_key_present[
  is.na(enriched_panel$national_key_present)
] <- FALSE
enriched_panel$institution_hmt_present[
  is.na(enriched_panel$institution_hmt_present)
] <- FALSE
enriched_panel$institution_foreign_present[
  is.na(enriched_panel$institution_foreign_present)
] <- FALSE

saveRDS(
  enriched_panel,
  file.path(
    processed_dir,
    "p1",
    "institution_complete_paper_panel_enriched.rds"
  )
)

year_tier_audit <- as.data.frame(
  table(
    tier_rule = institution_long$tier_rule,
    tier_level = institution_long$tier_level
  ),
  stringsAsFactors = FALSE
)
names(year_tier_audit)[[3]] <- "author_institution_links"
write_csv_utf8(
  year_tier_audit,
  file.path(audit_table_dir, "p1_year_tier_link_audit.csv")
)

paper_tier_summary <- as.data.frame(
  table(
    tier_rule = enriched_panel$tier_rule,
    cross_tier = enriched_panel$cross_tier,
    useNA = "ifany"
  ),
  stringsAsFactors = FALSE
)
names(paper_tier_summary)[[3]] <- "papers"
write_csv_utf8(
  paper_tier_summary,
  file.path(audit_table_dir, "p1_cross_tier_by_rule.csv")
)

geo_summary <- as.data.frame(
  table(
    retraction_year = enriched_panel$retraction_year_first,
    geo_level = enriched_panel$geo_level,
    useNA = "ifany"
  ),
  stringsAsFactors = FALSE
)
names(geo_summary)[[3]] <- "papers"
write_csv_utf8(
  geo_summary,
  file.path(audit_table_dir, "p1_geo_level_by_retraction_year.csv")
)

write_audit_manifest()
message("Institution enrichment completed.")
