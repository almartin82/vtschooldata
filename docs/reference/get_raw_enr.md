# Download raw enrollment data from Vermont AOE

Downloads the Vermont Education Dashboard enrollment dataset Excel file.
This file contains all available years of enrollment data.

## Usage

``` r
get_raw_enr(end_year = NULL)
```

## Arguments

- end_year:

  School year end (e.g., 2024 for 2023-24). If NULL, returns all
  available years.

## Value

Data frame with raw enrollment data

## Details

The VED file contains multiple DataCollectionName types per year. For
consistent enrollment counts, this function filters to use
DC#06_FALL_ADM_Official (October 1 enrollment) as the primary source,
supplementing with DC#04_YearEndCollection_Official for schools not
covered by DC#06.
