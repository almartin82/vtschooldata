# ==============================================================================
# School Directory Data Fetching Functions
# ==============================================================================
#
# This file contains functions for downloading school directory data from the
# Vermont Agency of Education website.
#
# Data sources:
# - Organizations dataset: https://education.vermont.gov/documents/ved-organizations-dataset
# - Principals directory: https://education.vermont.gov/documents/directory-principals-by-school
# - Superintendents directory: https://education.vermont.gov/documents/directory-superintendents-by-supervisory-union
#
# ==============================================================================

#' Fetch Vermont school directory data
#'
#' Downloads and processes school directory data from the Vermont Agency of
#' Education. Combines organization data (addresses, coordinates) with
#' principal and superintendent contact information.
#'
#' @param end_year Optional school year end. If NULL (default), returns the most
#'   recent year available. The organizations dataset has historical data from
#'   2001-2022.
#' @param tidy If TRUE (default), returns data in a standardized format with
#'   consistent column names. If FALSE, returns raw column names from AOE.
#' @param use_cache If TRUE (default), uses locally cached data when available.
#'   Set to FALSE to force re-download from Vermont AOE.
#' @return A tibble with school directory data. Columns include:
#'   \itemize{
#'     \item \code{state_school_id}: Vermont school organization ID
#'     \item \code{state_district_id}: Vermont supervisory union ID
#'     \item \code{school_name}: School name
#'     \item \code{district_name}: Supervisory union name
#'     \item \code{address}: Street address
#'     \item \code{city}: City
#'     \item \code{state}: State (always "VT")
#'     \item \code{zip}: ZIP code
#'     \item \code{phone}: Phone number (from principals directory)
#'     \item \code{principal_name}: Principal name (from principals directory)
#'     \item \code{superintendent_name}: Superintendent name (from SU directory)
#'     \item \code{latitude}: Geographic latitude
#'     \item \code{longitude}: Geographic longitude
#'     \item \code{end_year}: School year end
#'   }
#' @details
#' Vermont organizes schools under Supervisory Unions (SUs) rather than
#' traditional districts. The organizations dataset provides school locations
#' and coordinates, while the principals and superintendents directories
#' provide administrator contact information.
#'
#' Note: The principals/superintendents directories are updated annually and
#' only contain current year data. Administrator information is joined by
#' organization ID when available.
#'
#' @export
#' @examples
#' \dontrun{
#' # Get current school directory data
#' dir_data <- fetch_directory()
#'
#' # Get raw format (original AOE column names)
#' dir_raw <- fetch_directory(tidy = FALSE)
#'
#' # Get historical data for a specific year
#' dir_2020 <- fetch_directory(end_year = 2020)
#'
#' # Force fresh download (ignore cache)
#' dir_fresh <- fetch_directory(use_cache = FALSE)
#'
#' # Filter to schools with coordinates
#' library(dplyr)
#' schools_with_coords <- dir_data |>
#'   filter(!is.na(latitude), !is.na(longitude))
#' }
fetch_directory <- function(end_year = NULL, tidy = TRUE, use_cache = TRUE) {

  # If no year specified, use the most recent available
  if (is.null(end_year)) {
    end_year <- max(get_available_directory_years())
  }

  # Validate year
  available_years <- get_available_directory_years()
  if (!end_year %in% available_years) {
    stop(paste0(
      "end_year must be one of: ", paste(available_years, collapse = ", "),
      ". Use get_available_directory_years() to see all available years."
    ))
  }

  # Determine cache type based on tidy parameter
  cache_type <- if (tidy) "directory_tidy" else "directory_raw"

  # Check cache first
  if (use_cache && cache_exists_directory(end_year, cache_type)) {
    message(paste("Using cached directory data for", format_school_year(end_year)))
    return(read_cache_directory(end_year, cache_type))
  }

  # Get raw data from Vermont AOE
  raw <- get_raw_directory(end_year)

  # Process to standard schema
  if (tidy) {
    result <- process_directory(raw, end_year)
  } else {
    result <- raw$organizations
  }

  # Cache the result
  if (use_cache) {
    write_cache_directory(result, end_year, cache_type)
  }

  result
}


#' Get available years of Vermont directory data
#'
#' Returns a vector of school year ends for which Vermont school directory
#' data is available through the Vermont Education Dashboard.
#'
#' @return Integer vector of available school years (end years)
#' @export
#' @examples
#' get_available_directory_years()
get_available_directory_years <- function() {
  # Vermont Education Dashboard organizations data includes historical data
  # going back to 2001. Note: This is calendar year, not school year end.
  # The organizations file uses calendar year format (2001 = 2000-01 school year)
  2001:2022
}


#' Get raw school directory data from Vermont AOE
#'
#' Downloads the raw school directory data files from the Vermont
#' Agency of Education website.
#'
#' @param end_year School year end to filter to (from organizations dataset)
#' @return List containing raw data frames:
#'   \itemize{
#'     \item \code{organizations}: Organization location data
#'     \item \code{principals}: Principal contact data (current year only)
#'     \item \code{superintendents}: Superintendent contact data (current year only)
#'   }
#' @keywords internal
get_raw_directory <- function(end_year) {

  message("Downloading school directory data from Vermont AOE...")

  # Download organizations dataset
  orgs <- download_organizations_data()

  # Filter to requested year
  orgs <- orgs[orgs$SchoolYear == end_year, ]

  if (nrow(orgs) == 0) {
    stop(paste("No organization data found for year", end_year))
  }

  message(paste("Found", nrow(orgs), "organization records for", end_year))

  # Download principals directory (current year only)
  principals <- tryCatch({
    download_principals_data()
  }, error = function(e) {
    message("Note: Could not download principals directory: ", e$message)
    NULL
  })

  # Download superintendents directory (current year only)
  superintendents <- tryCatch({
    download_superintendents_data()
  }, error = function(e) {
    message("Note: Could not download superintendents directory: ", e$message)
    NULL
  })

  list(
    organizations = orgs,
    principals = principals,
    superintendents = superintendents
  )
}


#' Download organizations dataset from Vermont AOE
#'
#' @return Data frame with organization data
#' @keywords internal
download_organizations_data <- function() {

  # First, scrape the document page to find the current file name
  doc_url <- "https://education.vermont.gov/documents/ved-organizations-dataset"

  response <- httr::GET(
    doc_url,
    httr::user_agent("Mozilla/5.0 (compatible; R vtschooldata package)"),
    httr::timeout(30)
  )

  if (httr::http_error(response)) {
    stop("Failed to access Vermont AOE organizations document page")
  }

  content <- httr::content(response, "text", encoding = "UTF-8")

  # Extract the xlsx file URL from the page
  xlsx_pattern <- 'href="(/sites/aoe/files/documents/[^"]+\\.xlsx)"'
  xlsx_match <- regmatches(content, regexpr(xlsx_pattern, content, perl = TRUE))

  if (length(xlsx_match) == 0 || xlsx_match == "") {
    stop("Could not find organizations dataset download link")
  }

  # Extract just the path
  file_path <- gsub('href="([^"]+)"', "\\1", xlsx_match)
  url <- paste0("https://education.vermont.gov", file_path)

  message("Downloading organizations dataset...")

  # Download file to temp location
  tname <- tempfile(pattern = "vt_orgs", tmpdir = tempdir(), fileext = ".xlsx")

  response <- httr::GET(
    url,
    httr::user_agent("Mozilla/5.0 (compatible; R vtschooldata package)"),
    httr::write_disk(tname, overwrite = TRUE),
    httr::timeout(120)
  )

  if (httr::http_error(response)) {
    stop("Failed to download organizations dataset")
  }

  # Check if download was successful
  file_info <- file.info(tname)
  if (file_info$size < 10000) {
    stop("Download failed - file too small, may be error page")
  }

  message(paste("Downloaded", round(file_info$size / 1024, 1), "KB file"))

  # Read Excel file
  df <- readxl::read_excel(
    tname,
    col_types = "text",  # Read all as text to preserve leading zeros
    .name_repair = "unique"
  )

  # Convert year to numeric for filtering
  df$SchoolYear <- as.integer(df$SchoolYear)

  dplyr::as_tibble(df)
}


#' Download principals directory from Vermont AOE
#'
#' @return Data frame with principal data
#' @keywords internal
download_principals_data <- function() {

  # Scrape the document page to find the current file name
  doc_url <- "https://education.vermont.gov/documents/directory-principals-by-school"

  response <- httr::GET(
    doc_url,
    httr::user_agent("Mozilla/5.0 (compatible; R vtschooldata package)"),
    httr::timeout(30)
  )

  if (httr::http_error(response)) {
    stop("Failed to access Vermont AOE principals directory page")
  }

  content <- httr::content(response, "text", encoding = "UTF-8")

  # Extract the xlsx file URL from the page
  xlsx_pattern <- 'href="(/sites/aoe/files/documents/[^"]+\\.xlsx)"'
  xlsx_match <- regmatches(content, regexpr(xlsx_pattern, content, perl = TRUE))

  if (length(xlsx_match) == 0 || xlsx_match == "") {
    stop("Could not find principals directory download link")
  }

  # Extract just the path
  file_path <- gsub('href="([^"]+)"', "\\1", xlsx_match)
  url <- paste0("https://education.vermont.gov", file_path)

  message("Downloading principals directory...")

  # Download file to temp location
  tname <- tempfile(pattern = "vt_principals", tmpdir = tempdir(), fileext = ".xlsx")

  response <- httr::GET(
    url,
    httr::user_agent("Mozilla/5.0 (compatible; R vtschooldata package)"),
    httr::write_disk(tname, overwrite = TRUE),
    httr::timeout(60)
  )

  if (httr::http_error(response)) {
    stop("Failed to download principals directory")
  }

  # Read Excel file
  df <- readxl::read_excel(
    tname,
    col_types = "text",
    .name_repair = "unique"
  )

  message(paste("Loaded", nrow(df), "principal records"))

  dplyr::as_tibble(df)
}


#' Download superintendents directory from Vermont AOE
#'
#' @return Data frame with superintendent data
#' @keywords internal
download_superintendents_data <- function() {

  # Scrape the document page to find the current file name
  doc_url <- "https://education.vermont.gov/documents/directory-superintendents-by-supervisory-union"

  response <- httr::GET(
    doc_url,
    httr::user_agent("Mozilla/5.0 (compatible; R vtschooldata package)"),
    httr::timeout(30)
  )

  if (httr::http_error(response)) {
    stop("Failed to access Vermont AOE superintendents directory page")
  }

  content <- httr::content(response, "text", encoding = "UTF-8")

  # Extract the xlsx file URL from the page
  xlsx_pattern <- 'href="(/sites/aoe/files/documents/[^"]+\\.xlsx)"'
  xlsx_match <- regmatches(content, regexpr(xlsx_pattern, content, perl = TRUE))

  if (length(xlsx_match) == 0 || xlsx_match == "") {
    stop("Could not find superintendents directory download link")
  }

  # Extract just the path
  file_path <- gsub('href="([^"]+)"', "\\1", xlsx_match)
  url <- paste0("https://education.vermont.gov", file_path)

  message("Downloading superintendents directory...")

  # Download file to temp location
  tname <- tempfile(pattern = "vt_supts", tmpdir = tempdir(), fileext = ".xlsx")

  response <- httr::GET(
    url,
    httr::user_agent("Mozilla/5.0 (compatible; R vtschooldata package)"),
    httr::write_disk(tname, overwrite = TRUE),
    httr::timeout(60)
  )

  if (httr::http_error(response)) {
    stop("Failed to download superintendents directory")
  }

  # Read Excel file
  df <- readxl::read_excel(
    tname,
    col_types = "text",
    .name_repair = "unique"
  )

  message(paste("Loaded", nrow(df), "superintendent records"))

  dplyr::as_tibble(df)
}


#' Process raw school directory data to standard schema
#'
#' Takes raw school directory data from Vermont AOE and standardizes column
#' names, types, and joins administrator information.
#'
#' @param raw_data List with organizations, principals, and superintendents data
#' @param end_year School year for labeling
#' @return Processed data frame with standard schema
#' @keywords internal
process_directory <- function(raw_data, end_year) {

  orgs <- raw_data$organizations
  principals <- raw_data$principals
  superintendents <- raw_data$superintendents

  # Build standardized result from organizations data
  result <- dplyr::tibble(
    state_school_id = orgs$SchoolOrganizationIdentifier,
    state_district_id = orgs$SupervisoryUnionOrganizationIdentifier,
    school_name = orgs$SchoolOrganizationName,
    district_name = orgs$SupervisoryUnionOrganizationName,
    address = orgs$SchoolAddress,
    city = orgs$SchoolCity,
    state = orgs$SchoolState,
    zip = orgs$SchoolZipCode,
    latitude = safe_numeric(orgs$SchoolLatitude),
    longitude = safe_numeric(orgs$SchoolLongitude),
    end_year = as.integer(end_year)
  )

  # Clean up state field - should be "VT" or NA
  result$state <- ifelse(
    is.na(result$state) | result$state == "",
    "VT",
    result$state
  )

  # Join principal information if available
  if (!is.null(principals) && nrow(principals) > 0) {
    # Standardize principal data
    principal_info <- principals |>
      dplyr::transmute(
        state_school_id = .data$ORG_ID,
        principal_name = dplyr::case_when(
          !is.na(.data$`First Name`) & !is.na(.data$`Last Name`) ~
            paste(trimws(.data$`First Name`), trimws(.data$`Last Name`)),
          !is.na(.data$`Last Name`) ~ trimws(.data$`Last Name`),
          !is.na(.data$`First Name`) ~ trimws(.data$`First Name`),
          TRUE ~ NA_character_
        ),
        phone = trimws(.data$Phone)
      ) |>
      # Take first principal per school (some schools have multiple)
      dplyr::distinct(.data$state_school_id, .keep_all = TRUE)

    result <- result |>
      dplyr::left_join(principal_info, by = "state_school_id")
  } else {
    result$principal_name <- NA_character_
    result$phone <- NA_character_
  }

  # Join superintendent information if available
  if (!is.null(superintendents) && nrow(superintendents) > 0) {
    # Standardize superintendent data
    supt_info <- superintendents |>
      dplyr::transmute(
        state_district_id = .data$ORG_ID,
        superintendent_name = dplyr::case_when(
          !is.na(.data$`First Name`) & !is.na(.data$`Last Name`) ~
            paste(trimws(.data$`First Name`), trimws(.data$`Last Name`)),
          !is.na(.data$`Last Name`) ~ trimws(.data$`Last Name`),
          !is.na(.data$`First Name`) ~ trimws(.data$`First Name`),
          TRUE ~ NA_character_
        )
      ) |>
      dplyr::distinct(.data$state_district_id, .keep_all = TRUE)

    result <- result |>
      dplyr::left_join(supt_info, by = "state_district_id")
  } else {
    result$superintendent_name <- NA_character_
  }

  # Reorder columns
  result <- result |>
    dplyr::select(
      .data$state_school_id,
      .data$state_district_id,
      .data$school_name,
      .data$district_name,
      .data$address,
      .data$city,
      .data$state,
      .data$zip,
      .data$phone,
      .data$principal_name,
      .data$superintendent_name,
      .data$latitude,
      .data$longitude,
      .data$end_year
    )

  result
}


# ==============================================================================
# Directory-specific cache functions
# ==============================================================================

#' Build cache file path for directory data
#'
#' @param end_year School year end
#' @param cache_type Type of cache ("directory_tidy" or "directory_raw")
#' @return File path string
#' @keywords internal
build_cache_path_directory <- function(end_year, cache_type) {
  cache_dir <- get_cache_dir()
  file.path(cache_dir, paste0(cache_type, "_", end_year, ".rds"))
}


#' Check if cached directory data exists
#'
#' @param end_year School year end
#' @param cache_type Type of cache ("directory_tidy" or "directory_raw")
#' @param max_age Maximum age in days (default 30). Set to Inf to ignore age.
#' @return Logical indicating if valid cache exists
#' @keywords internal
cache_exists_directory <- function(end_year, cache_type, max_age = 30) {
  cache_path <- build_cache_path_directory(end_year, cache_type)

  if (!file.exists(cache_path)) {
    return(FALSE)
  }

  # Check age
  file_info <- file.info(cache_path)
  age_days <- as.numeric(difftime(Sys.time(), file_info$mtime, units = "days"))

  age_days <= max_age
}


#' Read directory data from cache
#'
#' @param end_year School year end
#' @param cache_type Type of cache ("directory_tidy" or "directory_raw")
#' @return Cached data frame
#' @keywords internal
read_cache_directory <- function(end_year, cache_type) {
  cache_path <- build_cache_path_directory(end_year, cache_type)
  readRDS(cache_path)
}


#' Write directory data to cache
#'
#' @param data Data frame to cache
#' @param end_year School year end
#' @param cache_type Type of cache ("directory_tidy" or "directory_raw")
#' @return Invisibly returns the cache path
#' @keywords internal
write_cache_directory <- function(data, end_year, cache_type) {
  cache_path <- build_cache_path_directory(end_year, cache_type)
  cache_dir <- dirname(cache_path)

  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  saveRDS(data, cache_path)
  invisible(cache_path)
}


#' Clear school directory cache
#'
#' Removes cached school directory data files.
#'
#' @param end_year Optional school year to clear. If NULL, clears all years.
#' @return Invisibly returns the number of files removed
#' @export
#' @examples
#' \dontrun{
#' # Clear all cached directory data
#' clear_directory_cache()
#'
#' # Clear only 2022 directory data
#' clear_directory_cache(2022)
#' }
clear_directory_cache <- function(end_year = NULL) {
  cache_dir <- get_cache_dir()

  if (!dir.exists(cache_dir)) {
    message("Cache directory does not exist")
    return(invisible(0))
  }

  if (!is.null(end_year)) {
    # Clear specific year
    pattern <- paste0("^directory_.*_", end_year, "\\.rds$")
  } else {
    # Clear all directory files
    pattern <- "^directory_"
  }

  files <- list.files(cache_dir, pattern = pattern, full.names = TRUE)

  if (length(files) > 0) {
    file.remove(files)
    message(paste("Removed", length(files), "cached directory file(s)"))
  } else {
    message("No cached directory files to remove")
  }

  invisible(length(files))
}
