# Tests for enrollment functions
# Note: Most tests are marked as skip_on_cran since they require network access

test_that("safe_numeric handles various inputs", {
  # Normal numbers
  expect_equal(safe_numeric("100"), 100)
  expect_equal(safe_numeric("1,234"), 1234)

  # Suppressed values (Vermont uses ***)
  expect_true(is.na(safe_numeric("*")))
  expect_true(is.na(safe_numeric("***")))
  expect_true(is.na(safe_numeric("-1")))
  expect_true(is.na(safe_numeric("<5")))
  expect_true(is.na(safe_numeric("")))
  expect_true(is.na(safe_numeric("NULL")))

  # Whitespace handling
  expect_equal(safe_numeric("  100  "), 100)
})


test_that("get_available_years returns valid years", {
  years <- get_available_years()

  expect_true(is.integer(years) || is.numeric(years))
  expect_true(length(years) > 0)
  expect_true(min(years) >= 2017)  # VED data starts 2017
  expect_true(max(years) <= 2030)  # Reasonable upper bound
})


test_that("fetch_enr validates year parameter", {
  expect_error(fetch_enr(2010), "end_year must be between")
  expect_error(fetch_enr(2030), "end_year must be between")
})


test_that("parse_school_year handles various formats", {
  # Standard format
  expect_equal(parse_school_year("2023-2024"), 2024)
  expect_equal(parse_school_year("2022-2023"), 2023)

  # Short format
  expect_equal(parse_school_year("2023-24"), 2024)
  expect_equal(parse_school_year("2022-23"), 2023)

  # With SY prefix
  expect_equal(parse_school_year("SY 2023-24"), 2024)
  expect_equal(parse_school_year("SY 2022-2023"), 2023)

  # Single year
  expect_equal(parse_school_year("2024"), 2024)
})


test_that("format_school_year creates correct display format", {
  expect_equal(format_school_year(2024), "2023-24")
  expect_equal(format_school_year(2023), "2022-23")
  expect_equal(format_school_year(2000), "1999-00")
})


test_that("get_cache_dir returns valid path", {
  cache_dir <- get_cache_dir()
  expect_true(is.character(cache_dir))
  expect_true(grepl("vtschooldata", cache_dir))
})


test_that("cache functions work correctly", {
  # Test cache path generation
  path <- get_cache_path(2024, "tidy")
  expect_true(grepl("enr_tidy_2024.rds", path))

  # Test cache_exists returns FALSE for non-existent cache
  # (Assuming no cache exists for year 9999)
  expect_false(cache_exists(9999, "tidy"))
})


# Integration tests (require network access)
test_that("fetch_enr downloads and processes data", {
  skip_on_cran()
  skip_if_offline()

  # Use a recent year
  result <- fetch_enr(2024, tidy = FALSE, use_cache = FALSE)

  # Check structure
  expect_true(is.data.frame(result))
  expect_true("district_id" %in% names(result) || "type" %in% names(result))
  expect_true("row_total" %in% names(result))
  expect_true("type" %in% names(result))

  # Check we have state level
  expect_true("State" %in% result$type)

  # Check we have some data
  expect_true(nrow(result) > 0)
})


test_that("tidy_enr produces correct long format", {
  skip_on_cran()
  skip_if_offline()

  # Get wide data
  wide <- fetch_enr(2024, tidy = FALSE, use_cache = TRUE)

  # Tidy it
  tidy_result <- tidy_enr(wide)

  # Check structure
  expect_true("grade_level" %in% names(tidy_result))
  expect_true("subgroup" %in% names(tidy_result))
  expect_true("n_students" %in% names(tidy_result))
  expect_true("pct" %in% names(tidy_result))

  # Check subgroups include expected values
  subgroups <- unique(tidy_result$subgroup)
  expect_true("total_enrollment" %in% subgroups)
})


test_that("id_enr_aggs adds correct flags", {
  skip_on_cran()
  skip_if_offline()

  # Get tidy data with aggregation flags
  result <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)

  # Check flags exist
  expect_true("is_state" %in% names(result))
  expect_true("is_district" %in% names(result))
  expect_true("is_campus" %in% names(result))

  # Check flags are boolean
  expect_true(is.logical(result$is_state))
  expect_true(is.logical(result$is_district))
  expect_true(is.logical(result$is_campus))

  # Check mutual exclusivity (each row is only one type)
  type_sums <- result$is_state + result$is_district + result$is_campus
  expect_true(all(type_sums == 1))
})


test_that("enr_grade_aggs creates correct aggregates", {
  skip_on_cran()
  skip_if_offline()

  # Get tidy data
  tidy_data <- fetch_enr(2024, tidy = TRUE, use_cache = TRUE)

  # Create grade aggregates
  grade_aggs <- enr_grade_aggs(tidy_data)

  # Check we have the expected grade levels
  expect_true("K8" %in% grade_aggs$grade_level)
  expect_true("HS" %in% grade_aggs$grade_level)
  expect_true("K12" %in% grade_aggs$grade_level)

  # Check n_students is populated
  expect_true(all(!is.na(grade_aggs$n_students)))
})


test_that("fetch_enr_multi works for multiple years", {
  skip_on_cran()
  skip_if_offline()

  # Fetch 2 years
  result <- fetch_enr_multi(c(2023, 2024), tidy = TRUE, use_cache = TRUE)

  # Check we have both years
  expect_true(all(c(2023, 2024) %in% unique(result$end_year)))

  # Check structure
  expect_true("grade_level" %in% names(result))
  expect_true("n_students" %in% names(result))
})
