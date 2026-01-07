# Clear school directory cache

Removes cached school directory data files.

## Usage

``` r
clear_directory_cache(end_year = NULL)
```

## Arguments

- end_year:

  Optional school year to clear. If NULL, clears all years.

## Value

Invisibly returns the number of files removed

## Examples

``` r
if (FALSE) { # \dontrun{
# Clear all cached directory data
clear_directory_cache()

# Clear only 2022 directory data
clear_directory_cache(2022)
} # }
```
