# vtschooldata

An R package for fetching and analyzing Vermont public school enrollment data from the Vermont Agency of Education (AOE).

## Installation

```r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("almartin82/vtschooldata")
```

## Quick Start

```r
library(vtschooldata)

# Get enrollment data for 2023-24 school year
enr_2024 <- fetch_enr(2024)

# View state-level totals
enr_2024 %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL")

# Get multiple years
enr_multi <- fetch_enr_multi(2020:2024)

# Track enrollment trends
enr_multi %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  select(end_year, n_students)
```

## Data Availability

### Years Available

| School Year | End Year | Status |
|-------------|----------|--------|
| 2016-17 | 2017 | Available |
| 2017-18 | 2018 | Available |
| 2018-19 | 2019 | Available |
| 2019-20 | 2020 | Available |
| 2020-21 | 2021 | Available |
| 2021-22 | 2022 | Available |
| 2022-23 | 2023 | Available |
| 2023-24 | 2024 | Available |
| 2024-25 | 2025 | Available (partial year) |

### Data Characteristics

- **Collection Date**: Enrollment is measured on October 1 of each school year
- **Geographic Levels**: State, Supervisory Union/School District, School
- **Grade Levels**: PreK, K (full-time and part-time), Grades 1-12, Adult Education
- **Update Frequency**: The Vermont Education Dashboard is updated periodically (typically annually in August)

### What's Available

- Total enrollment by grade level
- Enrollment at state, district, and school levels
- Historical data from 2016-17 school year to present
- Kindergarten broken down by full-time (22.5+ hours/week) and part-time

### What's NOT Available in This Dataset

The Vermont Education Dashboard enrollment dataset provides total enrollment counts by grade level. For demographic breakdowns (race/ethnicity, gender, special populations), see the Vermont Education Dashboard Student Characteristics dataset.

- Race/ethnicity breakdowns (available in separate Student Characteristics dataset)
- Gender breakdowns (available in separate Student Characteristics dataset)
- Special education counts (available in separate Student Characteristics dataset)
- Free/reduced lunch eligibility (available in separate Student Characteristics dataset)
- LEP/ELL counts (available in separate Student Characteristics dataset)

### Known Caveats

1. **Small Cell Suppression**: Values representing fewer than 11 students may be suppressed and shown as "***" to protect student privacy

2. **COVID-19 Impact (2020-21)**: No accountability determinations were made for the 2020-21 school year due to a federal waiver. Enrollment patterns may be affected by pandemic-related changes.

3. **Organization Structure**: Vermont uses Supervisory Unions (SU) and School Districts (SD) as administrative units. Some schools may report under different organizational structures in different years.

4. **Kindergarten Counts**: Kindergarten enrollment is split into:
   - K_Full: Students attending 22.5 or more hours per week
   - K_Part: Students attending fewer than 22.5 hours per week

## Data Source

Data is sourced from the Vermont Agency of Education's Vermont Education Dashboard:

- **Main Dashboard**: https://education.vermont.gov/data-and-reporting/vermont-education-dashboard
- **Enrollment Dashboard**: https://education.vermont.gov/data-and-reporting/vermont-education-dashboard/vermont-education-dashboard-enrollment
- **Dataset Download**: https://education.vermont.gov/documents/ved-enrollment-dataset

## Vermont Education System Overview

Vermont has approximately:
- 60 Supervisory Unions and School Districts
- 300+ public schools
- ~80,000 K-12 students

Vermont's education system is organized into Supervisory Unions (SUs) and Supervisory Districts (SDs), which oversee individual school districts and schools.

## Output Schema

### Wide Format (`tidy = FALSE`)

| Column | Type | Description |
|--------|------|-------------|
| end_year | integer | School year end (2024 = 2023-24 school year) |
| district_id | character | Organization ID for SU/SD |
| campus_id | character | Organization ID for school (NA for district rows) |
| district_name | character | SU/SD name |
| campus_name | character | School name (NA for district rows) |
| type | character | "State", "District", or "Campus" |
| row_total | integer | Total enrollment |
| grade_pk | integer | Pre-K enrollment |
| grade_k | integer | Kindergarten enrollment (full + part-time) |
| grade_01 through grade_12 | integer | Grade-level enrollment |

### Tidy Format (`tidy = TRUE`, default)

| Column | Type | Description |
|--------|------|-------------|
| end_year | integer | School year end |
| district_id | character | Organization ID |
| campus_id | character | Campus ID |
| district_name | character | District name |
| campus_name | character | Campus name |
| type | character | Aggregation level |
| grade_level | character | "TOTAL", "PK", "K", "01"-"12" |
| subgroup | character | "total_enrollment" |
| n_students | integer | Student count |
| pct | numeric | Percentage of total (0-1 scale) |
| is_state | logical | TRUE for state-level rows |
| is_district | logical | TRUE for district-level rows |
| is_campus | logical | TRUE for campus-level rows |

## Functions

### Data Fetching

- `fetch_enr(end_year, tidy = TRUE, use_cache = TRUE)` - Fetch enrollment for a single year
- `fetch_enr_multi(end_years, tidy = TRUE, use_cache = TRUE)` - Fetch multiple years
- `get_available_years()` - Get vector of available years

### Data Transformation

- `tidy_enr(df)` - Convert wide format to tidy (long) format
- `id_enr_aggs(df)` - Add aggregation level flags (is_state, is_district, is_campus)
- `enr_grade_aggs(df)` - Create grade-level aggregates (K8, HS, K12)

### Cache Management

- `cache_status()` - View cached data files
- `clear_cache(end_year = NULL, type = NULL)` - Remove cached files

## Examples

### State Enrollment Trend

```r
library(vtschooldata)
library(dplyr)
library(ggplot2)

# Get all available years
enr_all <- fetch_enr_multi(get_available_years())

# Plot state enrollment trend
enr_all %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  ggplot(aes(x = end_year, y = n_students)) +
  geom_line() +
  geom_point() +
  labs(
    title = "Vermont Public School Enrollment",
    x = "School Year (End)",
    y = "Total Students"
  ) +
  scale_y_continuous(labels = scales::comma)
```

### Grade-Level Analysis

```r
# Compare K-8 vs high school enrollment
enr_2024 <- fetch_enr(2024)
grade_aggs <- enr_grade_aggs(enr_2024)

grade_aggs %>%
  filter(is_state) %>%
  select(grade_level, n_students)
```

### District Comparison

```r
# Top 10 districts by enrollment
enr_2024 %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  arrange(desc(n_students)) %>%
  head(10) %>%
  select(district_name, n_students)
```

## License

MIT License

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Related Packages

This package is part of the state schooldata family:
- [caschooldata](https://github.com/almartin82/caschooldata) - California
- [ilschooldata](https://github.com/almartin82/ilschooldata) - Illinois
- [nyschooldata](https://github.com/almartin82/nyschooldata) - New York
- [ohschooldata](https://github.com/almartin82/ohschooldata) - Ohio
- [paschooldata](https://github.com/almartin82/paschooldata) - Pennsylvania
- [txschooldata](https://github.com/almartin82/txschooldata) - Texas
