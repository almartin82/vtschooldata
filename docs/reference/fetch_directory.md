# Fetch Vermont school directory data

Downloads and processes school directory data from the Vermont Agency of
Education. Combines organization data (addresses, coordinates) with
principal and superintendent contact information.

## Usage

``` r
fetch_directory(end_year = NULL, tidy = TRUE, use_cache = TRUE)
```

## Arguments

- end_year:

  Optional school year end. If NULL (default), returns the most recent
  year available. The organizations dataset has historical data from
  2001-2022.

- tidy:

  If TRUE (default), returns data in a standardized format with
  consistent column names. If FALSE, returns raw column names from AOE.

- use_cache:

  If TRUE (default), uses locally cached data when available. Set to
  FALSE to force re-download from Vermont AOE.

## Value

A tibble with school directory data. Columns include:

- `state_school_id`: Vermont school organization ID

- `state_district_id`: Vermont supervisory union ID

- `school_name`: School name

- `district_name`: Supervisory union name

- `address`: Street address

- `city`: City

- `state`: State (always "VT")

- `zip`: ZIP code

- `phone`: Phone number (from principals directory)

- `principal_name`: Principal name (from principals directory)

- `superintendent_name`: Superintendent name (from SU directory)

- `latitude`: Geographic latitude

- `longitude`: Geographic longitude

- `end_year`: School year end

## Details

Vermont organizes schools under Supervisory Unions (SUs) rather than
traditional districts. The organizations dataset provides school
locations and coordinates, while the principals and superintendents
directories provide administrator contact information.

Note: The principals/superintendents directories are updated annually
and only contain current year data. Administrator information is joined
by organization ID when available.

## Examples

``` r
if (FALSE) { # \dontrun{
# Get current school directory data
dir_data <- fetch_directory()

# Get raw format (original AOE column names)
dir_raw <- fetch_directory(tidy = FALSE)

# Get historical data for a specific year
dir_2020 <- fetch_directory(end_year = 2020)

# Force fresh download (ignore cache)
dir_fresh <- fetch_directory(use_cache = FALSE)

# Filter to schools with coordinates
library(dplyr)
schools_with_coords <- dir_data |>
  filter(!is.na(latitude), !is.na(longitude))
} # }
```
