# Tests for cache functions

test_that("get_cache_dir creates directory if needed", {
  cache_dir <- get_cache_dir()

  expect_true(is.character(cache_dir))
  expect_true(dir.exists(cache_dir))
  expect_true(grepl("vtschooldata", cache_dir))
})


test_that("get_cache_path generates correct paths", {
  path_tidy <- get_cache_path(2024, "tidy")
  path_wide <- get_cache_path(2024, "wide")

  expect_true(grepl("enr_tidy_2024\\.rds$", path_tidy))
  expect_true(grepl("enr_wide_2024\\.rds$", path_wide))

  # Different years should have different paths
  path_2023 <- get_cache_path(2023, "tidy")
  expect_false(path_tidy == path_2023)
})


test_that("cache_exists returns FALSE for non-existent files", {
  # Year 9999 should never exist

  expect_false(cache_exists(9999, "tidy"))
  expect_false(cache_exists(9999, "wide"))
})


test_that("write_cache and read_cache roundtrip works", {
  # Create test data
  test_df <- data.frame(
    end_year = 9998,
    test_col = c("a", "b", "c"),
    stringsAsFactors = FALSE
  )

  # Write to cache
  write_cache(test_df, 9998, "test")

  # Check it exists
  cache_path <- get_cache_path(9998, "test")
  expect_true(file.exists(cache_path))

  # Read it back
  read_df <- read_cache(9998, "test")

  # Verify data matches
  expect_equal(test_df$end_year, read_df$end_year)
  expect_equal(test_df$test_col, read_df$test_col)

  # Clean up
  file.remove(cache_path)
})


test_that("clear_cache removes files", {
  # Create test cache files
  test_df <- data.frame(x = 1:3)

  write_cache(test_df, 9997, "tidy")
  write_cache(test_df, 9997, "wide")
  write_cache(test_df, 9996, "tidy")

  # Clear specific year/type
  expect_message(clear_cache(9997, "tidy"), "Removed 1")

  # Clear remaining for year
  expect_message(clear_cache(9997), "Removed 1")

  # Clear by type
  expect_message(clear_cache(type = "tidy"), "Removed")

  # Clear non-existent
  expect_message(clear_cache(8888), "No cached files")
})


test_that("cache_status handles empty cache gracefully", {
  # This test just ensures no errors on empty cache
  # The actual output depends on cache state
  expect_no_error(cache_status())
})
