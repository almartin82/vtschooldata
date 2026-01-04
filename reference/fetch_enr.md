# Fetch Vermont enrollment data

Downloads and processes enrollment data from the Vermont Agency of
Education via the Vermont Education Dashboard (VED).

## Usage

``` r
fetch_enr(end_year, tidy = TRUE, use_cache = TRUE)
```

## Arguments

- end_year:

  A school year end. Year is the end of the academic year - eg 2023-24
  school year is year '2024'. Valid values are 2004-2025 (2003-04
  through 2024-25 school years). Data is collected on October 1 of each
  school year.

- tidy:

  If TRUE (default), returns data in long (tidy) format with subgroup
  column. If FALSE, returns wide format.

- use_cache:

  If TRUE (default), uses locally cached data when available. Set to
  FALSE to force re-download from Vermont AOE.

## Value

Data frame with enrollment data. Wide format includes columns for
district_id, campus_id, names, and enrollment counts by grade. Tidy
format pivots these counts into subgroup and grade_level columns.

## Note

The 2017-18 (end_year = 2018) data appears to have quality issues in the
source file, with significantly lower enrollment than expected.

## Examples

``` r
if (FALSE) { # \dontrun{
# Get 2024 enrollment data (2023-24 school year)
enr_2024 <- fetch_enr(2024)

# Get wide format
enr_wide <- fetch_enr(2024, tidy = FALSE)

# Force fresh download (ignore cache)
enr_fresh <- fetch_enr(2024, use_cache = FALSE)

# Get state-level totals
state_total <- enr_2024 |>
  dplyr::filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL")
} # }
```
