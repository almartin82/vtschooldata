# Convert to numeric, handling suppression markers

Vermont AOE uses various markers for suppressed data (\*, \*\*\*, blank,
etc.) and may use commas in large numbers.

## Usage

``` r
safe_numeric(x)
```

## Arguments

- x:

  Vector to convert

## Value

Numeric vector with NA for non-numeric values
