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

  # Vermont VED structure:
 # - SUPERVISORYUNIONIDENTIFIER: SU/SD ID (e.g., "SU001")
  # - SUPERVISORYUNIONNAME: Name of SU/SD
  # - SCHOOLIDENTIFIER: School ID (e.g., "PS023") - present for school-level rows
  # - ORGANIZATIONNAME: Name of school (for school-level rows)

  # Get SU/SD identifier (district level)
  su_id_col <- find_col(c("SUPERVISORYUNIONIDENTIFIER", "SU_ID", "SUID"))
  su_name_col <- find_col(c("SUPERVISORYUNIONNAME", "SU_NAME", "SUNAME"))
  school_id_col <- find_col(c("SCHOOLIDENTIFIER", "SCHOOL_ID", "SCHOOLID"))
  org_name_col <- find_col(c("ORGANIZATIONNAME", "ORG_NAME", "ORGNAME", "ORGANIZATION_NAME", "NAME"))

  # Extract district info
  if (!is.null(su_id_col)) {
    result$district_id <- trimws(raw_data[[su_id_col]])
  }
  if (!is.null(su_name_col)) {
    result$district_name <- trimws(raw_data[[su_name_col]])
  }

  # Extract campus info - rows with school identifiers are campus level
  if (!is.null(school_id_col)) {
    result$campus_id <- trimws(raw_data[[school_id_col]])
    # Empty school IDs should be NA
    result$campus_id[result$campus_id == ""] <- NA_character_
  }
  if (!is.null(org_name_col)) {
    result$campus_name <- trimws(raw_data[[org_name_col]])
  }

  # Determine organization type based on presence of school identifier
  # If SCHOOLIDENTIFIER is present and non-empty, it's a campus row
  # Otherwise it's a district-level aggregate row
  if (!is.null(school_id_col)) {
    has_school_id <- !is.na(result$campus_id) & result$campus_id != ""
    result$type <- ifelse(has_school_id, "Campus", "District")
  } else {
    # Fallback: check for ORG_TYPE column
    org_type_col <- find_col(c("ORG_TYPE", "ORGTYPE", "TYPE", "ORGANIZATION_TYPE"))
    if (!is.null(org_type_col)) {
      org_types <- trimws(raw_data[[org_type_col]])
      result$type <- dplyr::case_when(
        grepl("^(SU|SD|District|Supervisory)", org_types, ignore.case = TRUE) ~ "District",
        grepl("^(School|Campus|Elementary|Middle|High)", org_types, ignore.case = TRUE) ~ "Campus",
        TRUE ~ "District"
      )
    } else {
      result$type <- rep("Campus", n_rows)
    }
  }

  # For district rows, campus_name should be NA
  result$campus_name[result$type == "District"] <- NA_character_

  # County - if available
  county_col <- find_col(c("COUNTY", "CNTY", "COUNTY_NAME"))
  if (!is.null(county_col)) {
    result$county <- trimws(raw_data[[county_col]])
  }

  # Grade-level enrollment
  # Vermont VED uses: PRESCHOOL, KINDERGARTENFULLTIME, KINDERGARTENPARTTIME,
  # FIRSTGRADE, SECONDGRADE, ..., TWELFTHGRADE

  # PreK (called "Preschool" in VED)
  pk_col <- find_col(c("PRESCHOOL", "PREK", "PRE_K", "PRE-K", "GRADE_PK", "PK"))
  if (!is.null(pk_col)) {
    result$grade_pk <- safe_numeric(raw_data[[pk_col]])
  }

  # Kindergarten - VED splits into full/part time
  k_full_col <- find_col(c("KINDERGARTENFULLTIME", "K_FULL", "KFULL", "K-FULL"))
  k_part_col <- find_col(c("KINDERGARTENPARTTIME", "K_PART", "KPART", "K-PART"))
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

  # Grades 1-12 - VED uses word names (FIRSTGRADE, SECONDGRADE, etc.)
  grade_word_names <- c(
    "FIRSTGRADE", "SECONDGRADE", "THIRDGRADE", "FOURTHGRADE",
    "FIFTHGRADE", "SIXTHGRADE", "SEVENTHGRADE", "EIGHTHGRADE",
    "NINTHGRADE", "TENTHGRADE", "ELEVENTHGRADE", "TWELFTHGRADE"
  )

  for (g in 1:12) {
    grade_str <- sprintf("%02d", g)
    # Try word name first, then numeric patterns
    patterns <- c(
      grade_word_names[g],
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
