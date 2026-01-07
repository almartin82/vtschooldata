# vtschooldata: Fetch and Process Vermont School Data

Downloads and processes school data from the Vermont Agency of
Education. Provides functions for fetching enrollment data from the
Vermont Education Dashboard (VED) and transforming it into tidy format
for analysis.

## Main functions

- [`fetch_enr`](https://almartin82.github.io/vtschooldata/reference/fetch_enr.md):

  Fetch enrollment data for a school year

- [`fetch_enr_multi`](https://almartin82.github.io/vtschooldata/reference/fetch_enr_multi.md):

  Fetch enrollment for multiple years

- [`tidy_enr`](https://almartin82.github.io/vtschooldata/reference/tidy_enr.md):

  Transform wide data to tidy (long) format

- [`id_enr_aggs`](https://almartin82.github.io/vtschooldata/reference/id_enr_aggs.md):

  Add aggregation level flags

- [`enr_grade_aggs`](https://almartin82.github.io/vtschooldata/reference/enr_grade_aggs.md):

  Create grade-level aggregations

- [`get_available_years`](https://almartin82.github.io/vtschooldata/reference/get_available_years.md):

  Get available data years

## Cache functions

- [`cache_status`](https://almartin82.github.io/vtschooldata/reference/cache_status.md):

  View cached data files

- [`clear_cache`](https://almartin82.github.io/vtschooldata/reference/clear_cache.md):

  Remove cached data files

## ID System

Vermont uses organization IDs (ORG_ID) that identify:

- Supervisory Unions (SU): Administrative units

- School Districts (SD): Individual school districts

- Schools: Individual school buildings

Vermont has approximately 60 supervisory unions/districts and 300+
schools.

## Data Sources

Data is sourced from the Vermont Education Dashboard (VED):

- VED Enrollment data page on education.vermont.gov

- Data Portal: education.vermont.gov/data-and-reporting

## Data Characteristics

- Enrollment is measured on October 1 of each school year

- Data available from 2016-17 school year (end_year = 2017) to present

- Includes PreK through Grade 12 and adult education

- Kindergarten may be split into full-time and part-time counts

- Small cell sizes (\< 11 students) may be suppressed with "\*\*\*"

## See also

Useful links:

- <https://almartin82.github.io/vtschooldata>

- <https://github.com/almartin82/vtschooldata>

- Report bugs at <https://github.com/almartin82/vtschooldata/issues>

## Author

**Maintainer**: Al Martin <almartin@example.com>
