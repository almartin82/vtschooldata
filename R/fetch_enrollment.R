# ==============================================================================
# Enrollment Data Fetching Functions
# ==============================================================================
#
# This file contains functions for downloading enrollment data from the
# Vermont Agency of Education website.
#
# ==============================================================================

#' Fetch Vermont enrollment data
#'
#' Downloads and processes enrollment data from the Vermont Agency of Education
#' via the Vermont Education Dashboard (VED).
#'
#' @param end_year A school year end. Year is the end of the academic year - eg 2023-24
#'   school year is year '2024'. Valid values are 2004-2025 (2003-04 through 2024-25
#'   school years). Data is collected on October 1 of each school year.
#'
#' @note The 2017-18 (end_year = 2018) data appears to have quality issues in the
#'   source file, with significantly lower enrollment than expected.
#' @param tidy If TRUE (default), returns data in long (tidy) format with subgroup
#'   column. If FALSE, returns wide format.
#' @param use_cache If TRUE (default), uses locally cached data when available.
#'   Set to FALSE to force re-download from Vermont AOE.
#' @return Data frame with enrollment data. Wide format includes columns for
#'   district_id, campus_id, names, and enrollment counts by grade.
#'   Tidy format pivots these counts into subgroup and grade_level columns.
#' @export
#' @examples
#' \dontrun{
#' # Get 2024 enrollment data (2023-24 school year)
#' enr_2024 <- fetch_enr(2024)
#'
#' # Get wide format
#' enr_wide <- fetch_enr(2024, tidy = FALSE)
#'
#' # Force fresh download (ignore cache)
#' enr_fresh <- fetch_enr(2024, use_cache = FALSE)
#'
#' # Get state-level totals
#' state_total <- enr_2024 |>
#'   dplyr::filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL")
#' }
fetch_enr <- function(end_year, tidy = TRUE, use_cache = TRUE) {

  # Validate year
  available_years <- get_available_years()
  if (end_year < min(available_years) || end_year > max(available_years)) {
    stop(paste0(
      "end_year must be between ", min(available_years), " and ", max(available_years),
      ". Use get_available_years() to see all available years."
    ))
  }

  # Determine cache type based on tidy parameter
  cache_type <- if (tidy) "tidy" else "wide"

  # Check cache first
  if (use_cache && cache_exists(end_year, cache_type)) {
    message(paste("Using cached data for", format_school_year(end_year)))
    return(read_cache(end_year, cache_type))
  }

  # Get raw data from Vermont AOE
  raw <- get_raw_enr(end_year)

  # Process to standard schema
  processed <- process_enr(raw, end_year)

  # Optionally tidy
  if (tidy) {
    processed <- tidy_enr(processed) |>
      id_enr_aggs()
  }

  # Cache the result
  if (use_cache) {
    write_cache(processed, end_year, cache_type)
  }

  processed
}


#' Fetch enrollment data for multiple years
#'
#' Downloads and combines enrollment data for multiple school years.
#'
#' @param end_years Vector of school year ends (e.g., c(2022, 2023, 2024))
#' @param tidy If TRUE (default), returns data in long (tidy) format.
#' @param use_cache If TRUE (default), uses locally cached data when available.
#' @return Combined data frame with enrollment data for all requested years
#' @export
#' @examples
#' \dontrun{
#' # Get 3 years of data
#' enr_multi <- fetch_enr_multi(2022:2024)
#'
#' # Track enrollment trends
#' enr_multi |>
#'   dplyr::filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
#'   dplyr::select(end_year, n_students)
#' }
fetch_enr_multi <- function(end_years, tidy = TRUE, use_cache = TRUE) {

  # Validate years
  available_years <- get_available_years()
  invalid_years <- end_years[end_years < min(available_years) | end_years > max(available_years)]

  if (length(invalid_years) > 0) {
    stop(paste0(
      "Invalid years: ", paste(invalid_years, collapse = ", "),
      "\nend_year must be between ", min(available_years), " and ", max(available_years)
    ))
  }

  # Fetch each year
  results <- purrr::map(
    end_years,
    function(yr) {
      message(paste("Fetching", format_school_year(yr), "..."))
      fetch_enr(yr, tidy = tidy, use_cache = use_cache)
    }
  )

  # Combine
  dplyr::bind_rows(results)
}
