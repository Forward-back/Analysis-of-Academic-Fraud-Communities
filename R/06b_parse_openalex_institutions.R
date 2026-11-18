#!/usr/bin/env Rscript

source("R/00_setup.R", encoding = "UTF-8")

cache_root <- file.path(
  project_dir,
  project_config$paths$cache,
  "openalex",
  "p1",
  "institutions-batches"
)
response_files <- list.files(
  cache_root,
  pattern = "^batch_[0-9]+\\.json$",
  full.names = TRUE,
  recursive = FALSE
)
if (length(response_files) == 0) {
  stop("No institution response files found in: ", cache_root)
}

rows <- list()
for (file_index in seq_along(response_files)) {
  response <- jsonlite::read_json(
    response_files[[file_index]],
    simplifyVector = FALSE
  )
  results <- response$results
  if (is.null(results) || length(results) == 0) {
    next
  }
  for (result_index in seq_along(results)) {
    result <- results[[result_index]]
    associated <- result$associated_institutions
    associated_count <- if (is.null(associated)) 0L else length(associated)
    lineage <- unique(unlist(result$lineage, use.names = FALSE))

    rows[[length(rows) + 1L]] <- data.frame(
      institution_id = if (is.null(result$id)) NA_character_ else result$id,
      ror_id = if (is.null(result$ror)) NA_character_ else result$ror,
      institution_name = if (is.null(result$display_name)) {
        NA_character_
      } else {
        result$display_name
      },
      country_code = if (is.null(result$country_code)) {
        NA_character_
      } else {
        result$country_code
      },
      institution_type = if (is.null(result$type)) {
        NA_character_
      } else {
        result$type
      },
      homepage_url = if (is.null(result$homepage_url)) {
        NA_character_
      } else {
        result$homepage_url
      },
      works_count = if (is.null(result$works_count)) {
        NA_integer_
      } else {
        as.integer(result$works_count)
      },
      cited_by_count = if (is.null(result$cited_by_count)) {
        NA_integer_
      } else {
        as.integer(result$cited_by_count)
      },
      city = if (is.null(result$geo$city)) {
        NA_character_
      } else {
        result$geo$city
      },
      region = if (is.null(result$geo$region)) {
        NA_character_
      } else {
        result$geo$region
      },
      geo_country_code = if (is.null(result$geo$country_code)) {
        NA_character_
      } else {
        result$geo$country_code
      },
      geo_country = if (is.null(result$geo$country)) {
        NA_character_
      } else {
        result$geo$country
      },
      latitude = if (is.null(result$geo$latitude)) {
        NA_real_
      } else {
        as.numeric(result$geo$latitude)
      },
      longitude = if (is.null(result$geo$longitude)) {
        NA_real_
      } else {
        as.numeric(result$geo$longitude)
      },
      geonames_city_id = if (is.null(result$geo$geonames_city_id)) {
        NA_character_
      } else {
        result$geo$geonames_city_id
      },
      lineage_length = length(lineage),
      associated_institution_count = associated_count,
      updated_date = if (is.null(result$updated_date)) {
        NA_character_
      } else {
        result$updated_date
      },
      lineage_ids = I(list(lineage)),
      stringsAsFactors = FALSE
    )
  }
  message(
    "parsed ",
    basename(response_files[[file_index]]),
    " (",
    file_index,
    "/",
    length(response_files),
    ")"
  )
}

institutions <- do.call(rbind, rows)
rownames(institutions) <- NULL
if (anyDuplicated(institutions$institution_id) > 0) {
  duplicates <- institutions$institution_id[
    duplicated(institutions$institution_id)
  ]
  stop(
    "Duplicate institution IDs in cache: ",
    paste(head(unique(duplicates), 10), collapse = "; ")
  )
}

processed_p1_dir <- file.path(processed_dir, "p1")
ensure_dir(processed_p1_dir)
saveRDS(
  institutions,
  file.path(processed_p1_dir, "openalex_institutions.rds")
)

coverage <- data.frame(
  metric = c(
    "unique_institutions",
    "with_ror",
    "with_country_code",
    "with_city",
    "with_region",
    "with_geo_country",
    "with_coordinates",
    "with_lineage",
    "with_associated_institutions"
  ),
  value = c(
    nrow(institutions),
    sum(!is.na(institutions$ror_id) & institutions$ror_id != ""),
    sum(!is.na(institutions$country_code) & institutions$country_code != ""),
    sum(!is.na(institutions$city) & institutions$city != ""),
    sum(!is.na(institutions$region) & institutions$region != ""),
    sum(
      !is.na(institutions$geo_country_code) &
        institutions$geo_country_code != ""
    ),
    sum(
      !is.na(institutions$latitude) &
        !is.na(institutions$longitude)
    ),
    sum(institutions$lineage_length > 0),
    sum(institutions$associated_institution_count > 0)
  ),
  stringsAsFactors = FALSE
)
coverage$share <- coverage$value / nrow(institutions)
write_csv_utf8(
  coverage,
  file.path(audit_table_dir, "p1_institution_metadata_coverage.csv")
)

country_counts <- as.data.frame(
  table(country_code = institutions$country_code, useNA = "ifany"),
  stringsAsFactors = FALSE
)
names(country_counts)[[2]] <- "institutions"
country_counts <- country_counts[order(-country_counts$institutions), ]
write_csv_utf8(
  country_counts,
  file.path(audit_table_dir, "p1_institution_country_counts.csv")
)

cn_institutions <- institutions[
  which(institutions$country_code == "CN"),
  ,
  drop = FALSE
]
region_counts <- as.data.frame(
  table(
    region = cn_institutions$region,
    useNA = "ifany"
  ),
  stringsAsFactors = FALSE
)
names(region_counts)[[2]] <- "institutions"
region_counts <- region_counts[order(-region_counts$institutions), ]
write_csv_utf8(
  region_counts,
  file.path(audit_table_dir, "p1_cn_institution_region_counts.csv")
)

missing_cn_geo <- cn_institutions[
  which(
    is.na(cn_institutions$city) |
      is.na(cn_institutions$region) |
      cn_institutions$city == "" |
      cn_institutions$region == ""
  ),
  c(
    "institution_id",
    "ror_id",
    "institution_name",
    "city",
    "region",
    "latitude",
    "longitude"
  ),
  drop = FALSE
]
write_csv_utf8(
  missing_cn_geo,
  file.path(audit_table_dir, "p1_cn_institution_missing_geo.csv")
)

write_audit_manifest()
message("Institution parse completed.")
