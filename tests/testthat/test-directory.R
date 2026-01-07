# ==============================================================================
# Tests for fetch_directory() function
# ==============================================================================

library(testthat)

# Skip if no network connectivity
skip_if_offline <- function() {
  tryCatch({
    response <- httr::HEAD("https://www.google.com", httr::timeout(5))
    if (httr::http_error(response)) {
      skip("No network connectivity")
    }
  }, error = function(e) {
    skip("No network connectivity")
  })
}

# ==============================================================================
# Basic Function Tests
# ==============================================================================

test_that("get_available_directory_years returns expected range", {
  years <- get_available_directory_years()

  expect_true(is.integer(years) || is.numeric(years))
  expect_true(all(years >= 2001))
  expect_true(all(years <= 2025))
  expect_true(2022 %in% years)  # Known valid year
})

test_that("fetch_directory works with default parameters", {
  skip_on_cran()
  skip_if_offline()

  result <- fetch_directory(use_cache = TRUE)

  expect_s3_class(result, "data.frame")
  expect_gt(nrow(result), 0)

  # Check for required columns
  required_cols <- c(
    "state_school_id", "state_district_id", "school_name", "district_name",
    "address", "city", "state", "zip", "end_year"
  )
  expect_true(all(required_cols %in% names(result)))
})

test_that("fetch_directory works with specific year", {
  skip_on_cran()
  skip_if_offline()

  result <- fetch_directory(end_year = 2022, use_cache = TRUE)

  expect_s3_class(result, "data.frame")
  expect_gt(nrow(result), 200)  # Vermont has ~300 schools
  expect_true(all(result$end_year == 2022))
})

test_that("fetch_directory tidy=FALSE returns raw format", {
  skip_on_cran()
  skip_if_offline()

  result <- fetch_directory(end_year = 2022, tidy = FALSE, use_cache = TRUE)

  expect_s3_class(result, "data.frame")
  expect_gt(nrow(result), 0)

  # Raw format should have original AOE column names
  expect_true(any(grepl("School", names(result), ignore.case = TRUE)))
})

# ==============================================================================
# Data Quality Tests
# ==============================================================================

test_that("Directory data has valid structure", {
  skip_on_cran()
  skip_if_offline()

  result <- fetch_directory(end_year = 2022, use_cache = TRUE)

  # State should be "VT" or "NH" (for border schools)
  expect_true(all(result$state %in% c("VT", "NH") | is.na(result$state)))

  # IDs should be character type
  expect_true(is.character(result$state_school_id))
  expect_true(is.character(result$state_district_id))

  # Year should be numeric
  expect_true(is.numeric(result$end_year) || is.integer(result$end_year))

  # Coordinates should be numeric (if present)
  if ("latitude" %in% names(result)) {
    expect_true(is.numeric(result$latitude))
    expect_true(is.numeric(result$longitude))
  }
})

test_that("Directory data has reasonable values", {
  skip_on_cran()
  skip_if_offline()

  result <- fetch_directory(end_year = 2022, use_cache = TRUE)

  # Vermont/NH border coordinates roughly: lat 42.7-45.1, lon -73.5 to -71
  if ("latitude" %in% names(result)) {
    valid_lats <- result$latitude[!is.na(result$latitude)]
    if (length(valid_lats) > 0) {
      expect_true(all(valid_lats >= 42.5 & valid_lats <= 45.1))
    }

    valid_lons <- result$longitude[!is.na(result$longitude)]
    if (length(valid_lons) > 0) {
      expect_true(all(valid_lons >= -74 & valid_lons <= -71))
    }
  }

  # School names should not be empty
  expect_true(all(nchar(result$school_name) > 0))

  # State school IDs should follow pattern (PS###, SU###, etc.)
  expect_true(all(grepl("^[A-Z]{2}[0-9]+$", result$state_school_id)))
})

test_that("Directory includes administrator information when available", {
  skip_on_cran()
  skip_if_offline()

  result <- fetch_directory(end_year = 2022, use_cache = TRUE)

  # Check for principal/superintendent columns
  expect_true("principal_name" %in% names(result))
  expect_true("superintendent_name" %in% names(result))

  # At least some records should have principal names
  # (not all schools may have data in the directory)
  if ("principal_name" %in% names(result)) {
    n_principals <- sum(!is.na(result$principal_name))
    expect_gt(n_principals, 0,
              label = "At least some schools should have principal names")
  }

  # At least some records should have superintendent names
  if ("superintendent_name" %in% names(result)) {
    n_supts <- sum(!is.na(result$superintendent_name))
    expect_gt(n_supts, 0,
              label = "At least some schools should have superintendent names")
  }
})

# ==============================================================================
# Error Handling Tests
# ==============================================================================

test_that("fetch_directory errors on invalid year", {
  expect_error(
    fetch_directory(end_year = 1999),
    "end_year must be one of"
  )

  expect_error(
    fetch_directory(end_year = 2030),
    "end_year must be one of"
  )
})

# ==============================================================================
# Cache Tests
# ==============================================================================

test_that("Directory caching works", {
  skip_on_cran()
  skip_if_offline()

  # Clear cache first
  clear_directory_cache(2022)

  # First call should download
  result1 <- fetch_directory(end_year = 2022, use_cache = TRUE)

  # Second call should use cache (faster)
  start_time <- Sys.time()
  result2 <- fetch_directory(end_year = 2022, use_cache = TRUE)
  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  # Cached call should be fast (< 1 second)
  expect_lt(elapsed, 1)

  # Results should be identical
  expect_equal(nrow(result1), nrow(result2))
})

test_that("clear_directory_cache works", {
  skip_on_cran()
  skip_if_offline()

  # Fetch some data to populate cache
  fetch_directory(end_year = 2022, use_cache = TRUE)

  # Clear specific year
  n_removed <- clear_directory_cache(2022)
  expect_true(n_removed >= 0)

  # Clear all
  n_removed_all <- clear_directory_cache()
  expect_true(n_removed_all >= 0)
})

# ==============================================================================
# LIVE Pipeline Tests for Directory Data
# ==============================================================================

test_that("LIVE: Vermont AOE organizations document page is accessible", {
  skip_on_cran()
  skip_if_offline()

  doc_url <- "https://education.vermont.gov/documents/ved-organizations-dataset"

  response <- httr::HEAD(
    doc_url,
    httr::user_agent("Mozilla/5.0 (compatible; R vtschooldata package)"),
    httr::timeout(30)
  )

  expect_equal(httr::status_code(response), 200,
               label = "Organizations document page should return HTTP 200")
})

test_that("LIVE: Vermont AOE principals document page is accessible", {
  skip_on_cran()
  skip_if_offline()

  doc_url <- "https://education.vermont.gov/documents/directory-principals-by-school"

  response <- httr::HEAD(
    doc_url,
    httr::user_agent("Mozilla/5.0 (compatible; R vtschooldata package)"),
    httr::timeout(30)
  )

  expect_equal(httr::status_code(response), 200,
               label = "Principals document page should return HTTP 200")
})

test_that("LIVE: Vermont AOE superintendents document page is accessible", {
  skip_on_cran()
  skip_if_offline()

  doc_url <- "https://education.vermont.gov/documents/directory-superintendents-by-supervisory-union"

  response <- httr::HEAD(
    doc_url,
    httr::user_agent("Mozilla/5.0 (compatible; R vtschooldata package)"),
    httr::timeout(30)
  )

  expect_equal(httr::status_code(response), 200,
               label = "Superintendents document page should return HTTP 200")
})

test_that("LIVE: Can download and parse organizations dataset", {
  skip_on_cran()
  skip_if_offline()

  # This tests the internal download function
  orgs <- tryCatch({
    vtschooldata:::download_organizations_data()
  }, error = function(e) {
    skip(paste("Could not download organizations data:", e$message))
  })

  expect_s3_class(orgs, "data.frame")
  expect_gt(nrow(orgs), 1000)  # Multiple years of data
  expect_true("SchoolYear" %in% names(orgs))
})

test_that("LIVE: Full directory pipeline produces valid output", {
  skip_on_cran()
  skip_if_offline()

  # Test the full pipeline with fresh download
  result <- fetch_directory(end_year = 2022, use_cache = FALSE)

  # Verify complete schema
  expected_cols <- c(
    "state_school_id", "state_district_id", "school_name", "district_name",
    "address", "city", "state", "zip", "phone", "principal_name",
    "superintendent_name", "latitude", "longitude", "end_year"
  )

  expect_true(all(expected_cols %in% names(result)))

  # Verify data quality
  expect_gt(nrow(result), 250)  # Vermont has ~300 schools
  expect_lt(nrow(result), 350)

  # Check for non-empty required fields
  expect_true(all(!is.na(result$state_school_id)))
  expect_true(all(!is.na(result$school_name)))
  expect_true(all(result$state %in% c("VT", "NH") | is.na(result$state)))
})
