# ==============================================================================
# Raw Enrollment Data Download Functions
# ==============================================================================
#
# This file contains functions for downloading raw enrollment data from
# the Vermont Agency of Education's Vermont Education Dashboard.
#
# Vermont AOE provides enrollment data as a single Excel file containing
# all years of data. The file is updated periodically with new data.
#
# Data structure:
# - Single Excel file with enrollment by organization and grade level
# - ORG_ID: Organization identifier (supervisory union/school district or school)
# - SY: School year in format "YYYY-YYYY"
# - Grade columns: PreK through 12 plus adult education
#
# ==============================================================================

#' Download raw enrollment data from Vermont AOE
#'
#' Downloads the Vermont Education Dashboard enrollment dataset Excel file.
#' This file contains all available years of enrollment data.
#'
#' The VED file contains multiple DataCollectionName types per year.
#' For consistent enrollment counts, this function filters to use
#' DC#06_FALL_ADM_Official (October 1 enrollment) as the primary source,
#' supplementing with DC#04_YearEndCollection_Official for schools not
#' covered by DC#06.
#'
#' @param end_year School year end (e.g., 2024 for 2023-24). If NULL, returns
#'   all available years.
#' @return Data frame with raw enrollment data
#' @keywords internal
get_raw_enr <- function(end_year = NULL) {

  # Validate year if provided
  available_years <- get_available_years()
  if (!is.null(end_year)) {
    if (end_year < min(available_years) || end_year > max(available_years)) {
      stop(paste0(
        "end_year must be between ", min(available_years), " and ", max(available_years),
        ". Available years: ", paste(available_years, collapse = ", ")
      ))
    }
  }

  message("Downloading Vermont Education Dashboard enrollment data...")

  # Get the current download URL
  url <- build_ved_url()

  # Download the file
  df <- download_ved_enrollment(url)

  # Filter to requested year if specified
  if (!is.null(end_year)) {
    # The VED file uses SCHOOLYEAR column with end year as integer (e.g., "2024")
    df <- df[df$SCHOOLYEAR == as.character(end_year), ]

    if (nrow(df) == 0) {
      stop(paste0(
        "No data found for school year ", format_school_year(end_year),
        ". Check if this year is available in the Vermont Education Dashboard."
      ))
    }

    # Filter to avoid duplicate counting from multiple data collection types
    # Primary source: DC#06_FALL_ADM_Official (October 1 count)
    # Secondary source: DC#04_YearEndCollection_Official (for schools not in DC#06)
    df <- filter_data_collections(df)

    message(paste("  Found", nrow(df), "records for", format_school_year(end_year)))
  } else {
    message(paste("  Downloaded", nrow(df), "total records"))
  }

  df
}


#' Filter VED data to avoid duplicate records
#'
#' The VED enrollment file may contain multiple DataCollectionName types
#' for the same school/year. This function filters to use:
#' DC#06_FALL_ADM_Official (October 1 enrollment) as the primary source.
#'
#' Note: In some years (2018-2021), DC#06 and DC#04 have different school
#' identifiers but cover the same schools (verified by school name). Using
#' only DC#06 provides consistent October 1 enrollment counts.
#'
#' Additionally, some early years (2004-2010) have duplicate entries for the
#' same school with slight name variations. This function deduplicates by
#' keeping only one record per unique SU+School ID combination.
#'
#' @param df Data frame with raw VED data for a single year
#' @return Filtered data frame with one record per school
#' @keywords internal
filter_data_collections <- function(df) {

  # Check if DATACOLLECTIONNAME column exists
  if (!"DATACOLLECTIONNAME" %in% names(df)) {
    result <- df
  } else {
    # Get DC#06 records (October 1 enrollment - primary source)
    dc06 <- df[df$DATACOLLECTIONNAME == "DC#06_FALL_ADM_Official", ]

    if (nrow(dc06) > 0) {
      # DC#06 is available - use it as the authoritative October 1 count
      result <- dc06
    } else {
      # No DC#06 data - fall back to DC#04
      dc04 <- df[df$DATACOLLECTIONNAME == "DC#04_YearEndCollection_Official", ]

      if (nrow(dc04) > 0) {
        result <- dc04
      } else {
        # Neither standard collection exists, return as-is
        result <- df
      }
    }
  }

  # Deduplicate by SU + School ID to handle early years with duplicate entries
  if ("SUPERVISORYUNIONIDENTIFIER" %in% names(result) && "SCHOOLIDENTIFIER" %in% names(result)) {
    result$dedup_key <- paste0(result$SUPERVISORYUNIONIDENTIFIER, "|", result$SCHOOLIDENTIFIER)
    result <- result[!duplicated(result$dedup_key), ]
    result$dedup_key <- NULL
  }

  result
}


#' Download Vermont Education Dashboard enrollment file
#'
#' Downloads and reads the VED enrollment Excel file.
#'
#' @param url URL to the enrollment dataset
#' @return Data frame with enrollment data
#' @keywords internal
download_ved_enrollment <- function(url) {

  # Create temp file for download
  tname <- tempfile(
    pattern = "vt_ved_enrollment_",
    tmpdir = tempdir(),
    fileext = ".xlsx"
  )

  # Download with user agent to avoid bot blocking
  tryCatch({
    response <- httr::GET(
      url,
      httr::user_agent("Mozilla/5.0 (compatible; R vtschooldata package)"),
      httr::write_disk(tname, overwrite = TRUE),
      httr::timeout(120)
    )

    # Check for HTTP errors
    if (httr::http_error(response)) {
      stop(paste("HTTP error:", httr::status_code(response)))
    }

    # Check file size (small files likely error pages)
    file_info <- file.info(tname)
    if (file_info$size < 1000) {
      content <- readLines(tname, n = 10, warn = FALSE)
      if (any(grepl("error|not found|404|403", content, ignore.case = TRUE))) {
        stop("Vermont AOE returned an error page. The data may be temporarily unavailable.")
      }
    }

  }, error = function(e) {
    stop(paste("Failed to download Vermont enrollment data.",
               "\nError:", e$message,
               "\nPlease check your internet connection or try again later."))
  })

  # Read the Excel file
  message("  Reading enrollment data...")

  df <- tryCatch({
    readxl::read_excel(
      tname,
      col_types = "text"  # Read all as text for consistent handling
    )
  }, error = function(e) {
    stop(paste("Failed to read Vermont enrollment Excel file.",
               "\nError:", e$message))
  })

  # Clean up temp file
  unlink(tname)

  # Standardize column names
  names(df) <- toupper(names(df))

  df
}


#' Get Vermont enrollment data for a specific year with caching
#'
#' Internal function that handles caching of raw data. This is used by
#' the main download function to avoid repeated downloads of the same
#' source file.
#'
#' @return Data frame with all available enrollment data
#' @keywords internal
get_raw_enr_cached <- function() {
  # Check for cached raw data
  cache_dir <- get_cache_dir()
  raw_cache_path <- file.path(cache_dir, "ved_raw_enrollment.rds")

  # Use cache if less than 1 day old
  if (file.exists(raw_cache_path)) {
    file_info <- file.info(raw_cache_path)
    age_days <- as.numeric(difftime(Sys.time(), file_info$mtime, units = "days"))

    if (age_days <= 1) {
      message("Using cached raw data (less than 1 day old)")
      return(readRDS(raw_cache_path))
    }
  }

  # Download fresh data
  df <- get_raw_enr(end_year = NULL)

  # Cache it
  saveRDS(df, raw_cache_path)

  df
}
