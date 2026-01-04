# Get Vermont enrollment data for a specific year with caching

Internal function that handles caching of raw data. This is used by the
main download function to avoid repeated downloads of the same source
file.

## Usage

``` r
get_raw_enr_cached()
```

## Value

Data frame with all available enrollment data
