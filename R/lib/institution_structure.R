haversine_km <- function(lat1, lon1, lat2, lon2) {
  to_radians <- pi / 180
  delta_lat <- (lat2 - lat1) * to_radians
  delta_lon <- (lon2 - lon1) * to_radians
  lat1_radians <- lat1 * to_radians
  lat2_radians <- lat2 * to_radians
  a <- sin(delta_lat / 2)^2 +
    cos(lat1_radians) * cos(lat2_radians) * sin(delta_lon / 2)^2
  6371.0088 * 2 * asin(pmin(1, sqrt(a)))
}

pairwise_distance_summary <- function(latitude, longitude) {
  valid <- is.finite(latitude) & is.finite(longitude)
  coordinates <- unique(data.frame(
    latitude = latitude[valid],
    longitude = longitude[valid]
  ))
  if (nrow(coordinates) < 2L) {
    return(c(median = 0, maximum = 0))
  }
  pairs <- utils::combn(seq_len(nrow(coordinates)), 2L)
  distances <- haversine_km(
    coordinates$latitude[pairs[1L, ]],
    coordinates$longitude[pairs[1L, ]],
    coordinates$latitude[pairs[2L, ]],
    coordinates$longitude[pairs[2L, ]]
  )
  c(median = stats::median(distances), maximum = max(distances))
}

institution_add_year_tier <- function(data, year_column) {
  if (!year_column %in% names(data)) {
    stop("Missing publication year column: ", year_column)
  }
  required <- c(
    "is_mainland_institution",
    "is_hmt_institution",
    "is_foreign_institution",
    "tier_985",
    "tier_211",
    "tier_double_first_class_2017",
    "tier_double_first_class_2022"
  )
  missing <- setdiff(required, names(data))
  if (length(missing) > 0L) {
    stop("Missing institution columns: ", paste(missing, collapse = ", "))
  }

  publication_year <- data[[year_column]]
  data$tier_rule <- ifelse(
    is.na(publication_year),
    "unknown",
    ifelse(
      publication_year <= 2016L,
      "985_211_2016",
      ifelse(
        publication_year <= 2021L,
        "double_first_class_2017_2021",
        "double_first_class_2022_2025"
      )
    )
  )
  data$national_key_institution <- ifelse(
    data$tier_rule == "985_211_2016",
    data$tier_985 | data$tier_211,
    ifelse(
      data$tier_rule == "double_first_class_2017_2021",
      data$tier_double_first_class_2017,
      ifelse(
        data$tier_rule == "double_first_class_2022_2025",
        data$tier_double_first_class_2022,
        FALSE
      )
    )
  )
  data$national_key_institution[
    !data$is_mainland_institution %in% TRUE
  ] <- FALSE
  data$legacy_985_211_institution <-
    data$is_mainland_institution %in% TRUE &
    (data$tier_985 %in% TRUE | data$tier_211 %in% TRUE)
  data$tier_level <- ifelse(
    !data$is_mainland_institution %in% TRUE,
    ifelse(
      data$is_hmt_institution %in% TRUE,
      "hmt",
      "foreign"
    ),
    ifelse(
      data$tier_rule == "985_211_2016",
      ifelse(
        data$tier_985 %in% TRUE,
        "985",
        ifelse(data$tier_211 %in% TRUE, "211", "non_national")
      ),
      ifelse(
        data$national_key_institution,
        "double_first_class",
        "non_national"
      )
    )
  )
  data
}

summarize_institution_structure <- function(data, paper_column) {
  if (!paper_column %in% names(data)) {
    stop("Missing paper identifier column: ", paper_column)
  }
  institution_rows <- data.table::as.data.table(data)
  result <- institution_rows[
    ,
    {
      mainland_rows <- .SD[is_mainland_institution %in% TRUE]
      hmt_rows <- .SD[is_hmt_institution %in% TRUE]
      foreign_rows <- .SD[is_foreign_institution %in% TRUE]
      city_count <- data.table::uniqueN(mainland_rows$city[
        !is.na(mainland_rows$city)
      ])
      region_count <- data.table::uniqueN(mainland_rows$region_code[
        !is.na(mainland_rows$region_code)
      ])
      geo_level <- if (nrow(foreign_rows) > 0L) {
        "international"
      } else if (nrow(hmt_rows) > 0L) {
        "hmt_involved"
      } else if (nrow(mainland_rows) == 0L) {
        "unknown"
      } else if (city_count <= 1L) {
        "single_city"
      } else if (region_count <= 1L) {
        "same_province_multi_city"
      } else {
        "domestic_cross_province"
      }
      national_key_count <- data.table::uniqueN(
        mainland_rows$institution_id[
          mainland_rows$national_key_institution %in% TRUE
        ]
      )
      non_national_count <- data.table::uniqueN(
        mainland_rows$institution_id[
          !mainland_rows$national_key_institution %in% TRUE
        ]
      )
      domestic_distance <- pairwise_distance_summary(
        mainland_rows$latitude,
        mainland_rows$longitude
      )
      all_distance <- pairwise_distance_summary(
        .SD$latitude,
        .SD$longitude
      )
      list(
        n_institution_links = .N,
        n_unique_institutions = data.table::uniqueN(institution_id),
        n_mainland_institutions = data.table::uniqueN(
          mainland_rows$institution_id
        ),
        n_hmt_institutions = data.table::uniqueN(hmt_rows$institution_id),
        n_foreign_institutions = data.table::uniqueN(
          foreign_rows$institution_id
        ),
        national_key_institution_count = national_key_count,
        non_national_mainland_institution_count = non_national_count,
        national_key_present = national_key_count > 0L,
        non_national_mainland_present = non_national_count > 0L,
        cross_tier = national_key_count > 0L && non_national_count > 0L,
        legacy_985_211_cross_tier = any(
          mainland_rows$legacy_985_211_institution %in% TRUE
        ) && any(
          !mainland_rows$legacy_985_211_institution %in% TRUE
        ),
        institution_hmt_present = nrow(hmt_rows) > 0L,
        institution_foreign_present = nrow(foreign_rows) > 0L,
        geo_level = geo_level,
        main_city_count = city_count,
        main_region_count = region_count,
        median_domestic_geo_distance_km = domestic_distance[["median"]],
        max_domestic_geo_distance_km = domestic_distance[["maximum"]],
        median_all_geo_distance_km = all_distance[["median"]],
        max_all_geo_distance_km = all_distance[["maximum"]],
        tier_rule = unique(.SD$tier_rule)[[
          min(1L, length(unique(.SD$tier_rule)))
        ]]
      )
    },
    by = c(paper_column)
  ]
  as.data.frame(result)
}
