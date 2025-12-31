# ==============================================================================
# Enrollment Data Processing Functions
# ==============================================================================
#
# This file contains functions for processing raw Vermont enrollment data into
# a clean, standardized format consistent with other state schooldata packages.
#
# Vermont data comes from the Vermont Education Dashboard in a single file
# with all years. The data structure includes:
# - SY: School year
# - ORG_ID: Organization ID (SU/SD or school)
# - Grade columns: PREK through 12, plus adult education
# - K_FULL, K_PART: Full-time and part-time kindergarten
#
# ==============================================================================


#' Process raw Vermont enrollment data
#'
#' Transforms raw VED data into a standardized schema.
#'
#' @param raw_data Data frame from get_raw_enr
#' @param end_year School year end
#' @return Processed data frame with standardized columns
#' @keywords internal
process_enr <- function(raw_data, end_year) {

  # Get column names for mapping
  cols <- names(raw_data)

  # Helper to find column by pattern (case-insensitive)
  find_col <- function(patterns) {
    for (pattern in patterns) {
      matched <- grep(paste0("^", pattern, "$"), cols, value = TRUE, ignore.case = TRUE)
      if (length(matched) > 0) return(matched[1])
    }
    NULL
  }

  n_rows <- nrow(raw_data)

  # Build result dataframe
  result <- data.frame(
    end_year = rep(end_year, n_rows),
    stringsAsFactors = FALSE
  )

  # Organization ID - Vermont uses ORG_ID
  org_id_col <- find_col(c("ORG_ID", "ORGID", "ORGANIZATION_ID"))
  if (!is.null(org_id_col)) {
    result$org_id <- trimws(raw_data[[org_id_col]])
  }

  # Organization name
  org_name_col <- find_col(c("ORG_NAME", "ORGNAME", "ORGANIZATION_NAME", "NAME"))
  if (!is.null(org_name_col)) {
    result$org_name <- trimws(raw_data[[org_name_col]])
  }

  # Determine organization type (district vs school level)
  # Vermont structure: SU = Supervisory Union, SD = School District
  # Schools have longer IDs or different format
  org_type_col <- find_col(c("ORG_TYPE", "ORGTYPE", "TYPE", "ORGANIZATION_TYPE"))
  if (!is.null(org_type_col)) {
    org_types <- trimws(raw_data[[org_type_col]])
    result$type <- dplyr::case_when(
      grepl("^(SU|SD|District|Supervisory)", org_types, ignore.case = TRUE) ~ "District",
      grepl("^(School|Campus|Elementary|Middle|High)", org_types, ignore.case = TRUE) ~ "Campus",
      TRUE ~ "District"  # Default to district for SU/SD level
    )
  } else {
    # If no type column, default to district (aggregate level)
    result$type <- rep("District", n_rows)
  }

  # Map org_id to district_id and campus_id based on type
  # For districts: district_id = org_id, campus_id = NA
  # For campuses: need to extract district portion if possible
  result$district_id <- ifelse(result$type == "District", result$org_id, NA_character_)
  result$campus_id <- ifelse(result$type == "Campus", result$org_id, NA_character_)

  # District and campus names
  result$district_name <- ifelse(result$type == "District", result$org_name, NA_character_)
  result$campus_name <- ifelse(result$type == "Campus", result$org_name, NA_character_)

  # County - if available
  county_col <- find_col(c("COUNTY", "CNTY", "COUNTY_NAME"))
  if (!is.null(county_col)) {
    result$county <- trimws(raw_data[[county_col]])
  }

  # Grade-level enrollment
  # Vermont uses: PREK, K_FULL, K_PART, GR01, GR02, ..., GR12, ADULT
  # Or: PREK, K, 1, 2, ..., 12

  # PreK
  pk_col <- find_col(c("PREK", "PRE_K", "PRE-K", "GRADE_PK", "PK"))
  if (!is.null(pk_col)) {
    result$grade_pk <- safe_numeric(raw_data[[pk_col]])
  }

  # Kindergarten - may be split into full/part
  k_full_col <- find_col(c("K_FULL", "KFULL", "K-FULL"))
  k_part_col <- find_col(c("K_PART", "KPART", "K-PART"))
  k_col <- find_col(c("K", "KG", "KINDERGARTEN", "GRADE_K"))

  if (!is.null(k_full_col) && !is.null(k_part_col)) {
    # Combine full and part-time kindergarten
    k_full <- safe_numeric(raw_data[[k_full_col]])
    k_part <- safe_numeric(raw_data[[k_part_col]])
    # Sum, treating NA as 0
    k_full[is.na(k_full)] <- 0
    k_part[is.na(k_part)] <- 0
    result$grade_k <- k_full + k_part
  } else if (!is.null(k_col)) {
    result$grade_k <- safe_numeric(raw_data[[k_col]])
  }

  # Grades 1-12
  for (g in 1:12) {
    grade_str <- sprintf("%02d", g)
    # Try various column name formats
    patterns <- c(
      paste0("GR", grade_str),
      paste0("GRADE_", grade_str),
      paste0("GRADE", grade_str),
      as.character(g),
      paste0("G", g)
    )
    g_col <- find_col(patterns)
    if (!is.null(g_col)) {
      result[[paste0("grade_", grade_str)]] <- safe_numeric(raw_data[[g_col]])
    }
  }

  # Total enrollment - may need to calculate
  total_col <- find_col(c("TOTAL", "TOTAL_ENROLLMENT", "ENROLLMENT", "TOT", "ALL"))
  if (!is.null(total_col)) {
    result$row_total <- safe_numeric(raw_data[[total_col]])
  } else {
    # Calculate total from grade columns
    grade_cols <- grep("^grade_", names(result), value = TRUE)
    if (length(grade_cols) > 0) {
      grade_matrix <- as.matrix(result[, grade_cols, drop = FALSE])
      grade_matrix[is.na(grade_matrix)] <- 0
      result$row_total <- rowSums(grade_matrix)
    }
  }

  # Remove temporary columns
  result$org_id <- NULL
  result$org_name <- NULL

  # Create state aggregate
  state_aggregate <- create_state_aggregate(result, end_year)

  # Combine with state row at top
  result <- dplyr::bind_rows(state_aggregate, result)

  result
}


#' Create state-level aggregate from processed data
#'
#' @param df Processed data frame (district or campus level)
#' @param end_year School year end
#' @return Single-row data frame with state totals
#' @keywords internal
create_state_aggregate <- function(df, end_year) {

  # Only aggregate district-level data to avoid double-counting
  district_data <- df[df$type == "District", ]

  if (nrow(district_data) == 0) {
    district_data <- df  # Use all data if no district rows
  }

  # Columns to sum
  sum_cols <- c(
    "row_total",
    "grade_pk", "grade_k",
    "grade_01", "grade_02", "grade_03", "grade_04",
    "grade_05", "grade_06", "grade_07", "grade_08",
    "grade_09", "grade_10", "grade_11", "grade_12"
  )

  # Filter to columns that exist
  sum_cols <- sum_cols[sum_cols %in% names(district_data)]

  # Create state row
  state_row <- data.frame(
    end_year = end_year,
    type = "State",
    district_id = NA_character_,
    campus_id = NA_character_,
    district_name = NA_character_,
    campus_name = NA_character_,
    stringsAsFactors = FALSE
  )

  # Add county if present in data
  if ("county" %in% names(district_data)) {
    state_row$county <- NA_character_
  }

  # Sum each column
  for (col in sum_cols) {
    if (col %in% names(district_data)) {
      state_row[[col]] <- sum(district_data[[col]], na.rm = TRUE)
    }
  }

  state_row
}
