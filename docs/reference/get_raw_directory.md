# Get raw school directory data from Vermont AOE

Downloads the raw school directory data files from the Vermont Agency of
Education website.

## Usage

``` r
get_raw_directory(end_year)
```

## Arguments

- end_year:

  School year end to filter to (from organizations dataset)

## Value

List containing raw data frames:

- `organizations`: Organization location data

- `principals`: Principal contact data (current year only)

- `superintendents`: Superintendent contact data (current year only)
