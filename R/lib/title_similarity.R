token_jaccard <- function(left, right) {
  left_tokens <- strsplit(
    normalize_title(left),
    " ",
    fixed = TRUE
  )
  right_tokens <- strsplit(
    normalize_title(right),
    " ",
    fixed = TRUE
  )
  mapply(
    function(left_values, right_values) {
      left_values <- left_values[
        !is.na(left_values) & nzchar(left_values)
      ]
      right_values <- right_values[
        !is.na(right_values) & nzchar(right_values)
      ]
      if (length(left_values) == 0L || length(right_values) == 0L) {
        return(NA_real_)
      }
      length(intersect(left_values, right_values)) /
        length(union(left_values, right_values))
    },
    left_tokens,
    right_tokens,
    USE.NAMES = FALSE
  )
}

token_containment <- function(left, right) {
  left_tokens <- strsplit(
    normalize_title(left),
    " ",
    fixed = TRUE
  )
  right_tokens <- strsplit(
    normalize_title(right),
    " ",
    fixed = TRUE
  )
  mapply(
    function(left_values, right_values) {
      left_values <- left_values[
        !is.na(left_values) & nzchar(left_values)
      ]
      right_values <- right_values[
        !is.na(right_values) & nzchar(right_values)
      ]
      if (length(left_values) == 0L || length(right_values) == 0L) {
        return(NA_real_)
      }
      length(intersect(left_values, right_values)) /
        length(unique(left_values))
    },
    left_tokens,
    right_tokens,
    USE.NAMES = FALSE
  )
}
