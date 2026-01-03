# ==============================================================================
# Utility Functions
# ==============================================================================

#' @importFrom rlang .data
NULL


#' Convert to numeric, handling suppression markers
#'
#' Vermont AOE uses various markers for suppressed data (*, ***, blank, etc.)
#' and may use commas in large numbers.
#'
#' @param x Vector to convert
#' @return Numeric vector with NA for non-numeric values
#' @keywords internal
safe_numeric <- function(x) {
  # Remove commas and whitespace
  x <- gsub(",", "", x)
  x <- trimws(x)

  # Handle common suppression markers used by Vermont AOE
  # *** is used for suppressed small counts
  x[x %in% c("*", "***", ".", "-", "-1", "<5", "N/A", "NA", "", "NULL")] <- NA_character_

  suppressWarnings(as.numeric(x))
}


#' Get available years of Vermont enrollment data
#'
#' Returns a vector of school year ends for which Vermont enrollment data
#' is available through the Vermont Education Dashboard.
#'
#' @return Integer vector of available school years (end years)
#' @export
#' @examples
#' get_available_years()
get_available_years <- function() {


  # Vermont Education Dashboard enrollment data includes historical data
  # going back to the 2003-04 school year (end_year = 2004)
  # Data is measured on October 1 of each school year
  2004:2024
}


#' Build Vermont AOE enrollment data URL
#'
#' Constructs the URL to download the Vermont Education Dashboard enrollment
#' dataset. Vermont AOE provides a single Excel file containing all years
#' of data.
#'
#' @return URL string for the enrollment dataset
#' @keywords internal
build_ved_url <- function() {
  # The Vermont Education Dashboard enrollment dataset is a single file

  # that contains all years of data. The file is updated periodically
  # and the date suffix changes.
  #
  # We need to scrape the document page to find the current file name
  # because the date suffix changes with each update.

  # Try to get the current download URL from the document page
  doc_url <- "https://education.vermont.gov/document/vermont-education-dashboard-dataset-enrollment"

  tryCatch({
    response <- httr::GET(
      doc_url,
      httr::user_agent("Mozilla/5.0 (compatible; R vtschooldata package)"),
      httr::timeout(30)
    )

    if (httr::http_error(response)) {
      stop("Failed to access Vermont AOE document page")
    }

    content <- httr::content(response, "text", encoding = "UTF-8")

    # Extract the xlsx file URL from the page
    xlsx_match <- regmatches(
      content,
      regexpr('href="(/sites/aoe/files/documents/edu-ved-enrollment-dataset-[0-9]+\\.xlsx)"', content)
    )

    if (length(xlsx_match) == 0 || xlsx_match == "") {
      stop("Could not find enrollment dataset download link")
    }

    # Extract just the path
    file_path <- gsub('href="([^"]+)"', "\\1", xlsx_match)

    paste0("https://education.vermont.gov", file_path)

  }, error = function(e) {
    # Fallback to known recent URL if scraping fails
    message("Note: Using fallback URL. If download fails, Vermont AOE may have updated the file.")
    "https://education.vermont.gov/sites/aoe/files/documents/edu-ved-enrollment-dataset-20251125.xlsx"
  })
}


#' Parse Vermont school year string
#'
#' Converts Vermont school year format (e.g., "2023-2024" or "SY 2023-24")
#' to an end year integer (2024).
#'
#' @param sy School year string
#' @return Integer end year
#' @keywords internal
parse_school_year <- function(sy) {
  # Handle various formats:
  # "2023-2024" -> 2024
  # "SY 2023-24" -> 2024
  # "2023-24" -> 2024
  # "2024" -> 2024

  sy <- trimws(as.character(sy))

  # Remove "SY " prefix if present
  sy <- gsub("^SY\\s*", "", sy, ignore.case = TRUE)

  # Check for range format
  if (grepl("-", sy)) {
    # Extract the end year
    parts <- strsplit(sy, "-")[[1]]
    end_part <- parts[2]

    # Handle 2-digit year (e.g., "24" -> 2024)
    if (nchar(end_part) == 2) {
      start_year <- as.integer(parts[1])
      century <- floor(start_year / 100) * 100
      end_year <- century + as.integer(end_part)
    } else {
      end_year <- as.integer(end_part)
    }
  } else {
    # Single year
    end_year <- as.integer(sy)
  }

  end_year
}


#' Format school year for display
#'
#' Converts an end year integer to a display format (e.g., 2024 -> "2023-24").
#'
#' @param end_year Integer end year
#' @return Character string in "YYYY-YY" format
#' @keywords internal
format_school_year <- function(end_year) {
  start_year <- end_year - 1
  end_short <- end_year %% 100
  paste0(start_year, "-", sprintf("%02d", end_short))
}
