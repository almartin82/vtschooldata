# Filter VED data to avoid duplicate records

The VED enrollment file may contain multiple DataCollectionName types
for the same school/year. This function filters to use:
DC#06_FALL_ADM_Official (October 1 enrollment) as the primary source.

## Usage

``` r
filter_data_collections(df)
```

## Arguments

- df:

  Data frame with raw VED data for a single year

## Value

Filtered data frame with one record per school

## Details

Note: In some years (2018-2021), DC#06 and DC#04 have different school
identifiers but cover the same schools (verified by school name). Using
only DC#06 provides consistent October 1 enrollment counts.

Additionally, some early years (2004-2010) have duplicate entries for
the same school with slight name variations. This function deduplicates
by keeping only one record per unique SU+School ID combination.
