# Process raw school directory data to standard schema

Takes raw school directory data from Vermont AOE and standardizes column
names, types, and joins administrator information.

## Usage

``` r
process_directory(raw_data, end_year)
```

## Arguments

- raw_data:

  List with organizations, principals, and superintendents data

- end_year:

  School year for labeling

## Value

Processed data frame with standard schema
