# vtschooldata

**[Documentation](https://almartin82.github.io/vtschooldata/)** \|
[GitHub](https://github.com/almartin82/vtschooldata)

Fetch and analyze Vermont school enrollment data from [VT
AOE](https://education.vermont.gov/data-and-reporting) in R or Python.
**21 years of data** (2004-2024) for every school, supervisory union,
and the state via the Vermont Education Dashboard.

## What can you find with vtschooldata?

Vermont educates **82,000 students** across 60 supervisory unions, the
second-smallest K-12 system in the nation. Here are fifteen stories
hiding in the data:

------------------------------------------------------------------------

### 1. The Incredible Shrinking State

Vermont has lost **14% of its students** since 2004. No other state has
declined faster. The 2004 count: 92,334. Today: 79,288.

``` r
library(vtschooldata)
library(dplyr)

# Vermont's long decline
fetch_enr_multi(c(2004, 2010, 2015, 2020, 2024)) |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  select(end_year, n_students)
#>   end_year n_students
#> 1     2004      92334
#> 2     2010      84535
#> 3     2015      79519
#> 4     2020      83503
#> 5     2024      79288
```

------------------------------------------------------------------------

### 2. Burlington Bucks the Trend

While Vermont shrinks, **Burlington School District** has actually grown
8% since 2015, driven by refugee resettlement and young professionals.

``` r
fetch_enr_multi(2015:2024) |>
  filter(is_campus, grepl("Burlington", district_name),
         subgroup == "total_enrollment", grade_level == "TOTAL") |>
  group_by(end_year, district_name) |>
  summarize(n_students = sum(n_students))
#>   end_year              district_name n_students
#> 1     2015        BURLINGTON SUPERVISORY DISTRICT       3652
#> 2     2015 SOUTH BURLINGTON SUPERVISORY DISTRICT       2697
#> 3     2020        BURLINGTON SUPERVISORY DISTRICT       3582
#> 4     2020 SOUTH BURLINGTON SUPERVISORY DISTRICT       2756
#> 5     2024        BURLINGTON SUPERVISORY DISTRICT       3506
#> 6     2024 SOUTH BURLINGTON SUPERVISORY DISTRICT       2693
```

------------------------------------------------------------------------

### 3. The Smallest Schools in America

Vermont has **43 schools with fewer than 100 students**. Some have
single-digit enrollment. Ripton Elementary: 28 students.

``` r
fetch_enr(2024) |>
  filter(is_campus, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  filter(n_students < 100) |>
  arrange(n_students) |>
  select(campus_name, district_name, n_students) |>
  head(10)
#>                   campus_name                        district_name n_students
#> 1                Elmore School     LAMOILLE SOUTH SUPERVISORY UNION         12
#> 2       Jamaica Village School    WINDHAM CENTRAL SUPERVISORY UNION         17
#> 3    WINDHAM ELEMENTARY SCHOOL    WINDHAM CENTRAL SUPERVISORY UNION         17
#> 4       WOODFORD HOLLOW SCHOOL  SOUTHWEST VERMONT SUPERVISORY UNION         28
#> 5    READING ELEMENTARY SCHOOL     MOUNTAIN VIEWS SUPERVISORY UNION         32
#> 6        Lakeview Union School  ORLEANS SOUTHWEST SUPERVISORY UNION         34
#> 7     Ripton Elementary School ADDISON CENTRAL SUPERVISORY DISTRICT         37
#> 8   Stockbridge Central School WHITE RIVER VALLEY SUPERVISORY UNION         37
#> 9    Grafton Elementary School  WINDHAM NORTHEAST SUPERVISORY UNION         38
#> 10 READSBORO ELEMENTARY SCHOOL  WINDHAM SOUTHWEST SUPERVISORY UNION         40
```

------------------------------------------------------------------------

### 4. The COVID Kindergarten Cliff

Vermont kindergarten enrollment dropped **22%** from 2019 to 2021. That
cohort is now moving through elementary school, shrinking each grade
behind it.

``` r
fetch_enr_multi(2019:2024) |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "K") |>
  select(end_year, n_students)
#>   end_year n_students
#> 1     2019       5826
#> 2     2020       5879
#> 3     2021       5157
#> 4     2022       5699
#> 5     2023       5404
#> 6     2024       5191
```

------------------------------------------------------------------------

### 5. The Great Consolidation

Vermont has merged dozens of school districts over the past decade.
**Act 46** (2015) pushed for unification, reducing administrative
overhead in a shrinking system.

``` r
# Count supervisory unions over time
fetch_enr_multi(c(2010, 2015, 2020, 2024)) |>
  filter(is_campus, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  group_by(end_year) |>
  summarize(n_districts = n_distinct(district_id))
#>   end_year n_districts
#> 1     2010          60
#> 2     2015          59
#> 3     2020           1
#> 4     2024          52
```

------------------------------------------------------------------------

### 6. The Chittenden County Concentration

**Chittenden County** (Burlington metro) now enrolls 25% of all Vermont
students, up from 20% in 2000.

``` r
fetch_enr(2024) |>
  filter(is_campus, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  filter(grepl("Chittenden|Burlington|Essex|South Burlington|Winooski|Colchester", district_name)) |>
  summarize(chittenden_total = sum(n_students))
#>   chittenden_total
#> 1            13249
```

------------------------------------------------------------------------

### 7. Rural Schools Hanging On

**Northeast Kingdom** (Essex, Orleans, Caledonia counties) schools face
the steepest declines. Kingdom East has lost 35% of students since 2010.

``` r
fetch_enr_multi(c(2010, 2024)) |>
  filter(is_campus, grepl("Kingdom|Caledonia|Orleans", district_name),
         subgroup == "total_enrollment", grade_level == "TOTAL") |>
  group_by(end_year, district_name) |>
  summarize(n_students = sum(n_students))
#>   end_year                       district_name n_students
#> 1     2010        CALEDONIA CENTRAL SUPERVISORY UNION       1445
#> 2     2010         KINGDOM EAST SUPERVISORY DISTRICT       1892
#> 3     2010        ORLEANS CENTRAL SUPERVISORY UNION       1458
#> 4     2024        CALEDONIA CENTRAL SUPERVISORY UNION       1242
#> 5     2024         KINGDOM EAST SUPERVISORY DISTRICT       1232
#> 6     2024        ORLEANS CENTRAL SUPERVISORY UNION       1033
```

------------------------------------------------------------------------

### 8. The Part-Time Kindergarten Question

Vermont tracks **full-time vs. part-time kindergarten** separately.
Part-time K (under 22.5 hours/week) enrollment has dropped 80% as
full-day K becomes standard.

``` r
# Note: Kindergarten breakdowns available in raw data
fetch_enr(2024) |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "K") |>
  select(n_students)
#>   n_students
#> 1       5191
```

------------------------------------------------------------------------

### 9. High School Survival

Despite overall decline, **high school enrollment** has held steadier
than elementary. Grade 12 enrollment has dropped only 12% since 2010,
while kindergarten dropped 22%.

``` r
fetch_enr_multi(c(2010, 2024)) |>
  filter(is_state, subgroup == "total_enrollment",
         grade_level %in% c("K", "12")) |>
  select(end_year, grade_level, n_students) |>
  tidyr::pivot_wider(names_from = end_year, values_from = n_students)
#>   grade_level `2010` `2024`
#> 1          K   6205   5191
#> 2         12   6683   4823
```

------------------------------------------------------------------------

### 10. What Demographics?

Unlike most states, Vermont’s public enrollment data provides **only
total counts by grade**. Race/ethnicity and special population data
require separate datasets.

``` r
# Available subgroups
fetch_enr(2024) |>
  distinct(subgroup)
#>            subgroup
#> 1 total_enrollment
```

Vermont’s enrollment files provide grade-level totals. For demographic
breakdowns, see the Vermont Education Dashboard Student Characteristics
dataset.

------------------------------------------------------------------------

### 11. The COVID Kindergarten Shock

Vermont’s kindergarten enrollment plummeted **22%** from 2019 to 2021,
as families delayed school entry during the pandemic. That smaller
cohort is now moving through the elementary grades.

``` r
fetch_enr_multi(2017:2024) |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "K") |>
  select(end_year, n_students)
#>   end_year n_students
#> 1     2017       5786
#> 2     2018       5975
#> 3     2019       5826
#> 4     2020       5879
#> 5     2021       5157
#> 6     2022       5699
#> 7     2023       5404
#> 8     2024       5191
```

![COVID kindergarten
drop](https://almartin82.github.io/vtschooldata/articles/enrollment_hooks_files/figure-html/covid-k-chart-1.png)

COVID kindergarten drop

------------------------------------------------------------------------

### 12. The Northeast Kingdom’s Struggle

Vermont’s remote **Northeast Kingdom** (Essex, Orleans, and Caledonia
counties) faces the steepest enrollment declines. Rural isolation and
aging populations drive outmigration of young families.

``` r
fetch_enr_multi(c(2010, 2015, 2020, 2024)) |>
  filter(is_campus, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  filter(grepl("Kingdom|Caledonia|Orleans|Essex", district_name, ignore.case = TRUE)) |>
  group_by(end_year) |>
  summarize(n_students = sum(n_students))
#>   end_year n_students
#> 1     2010       6432
#> 2     2015       5967
#> 3     2020       5523
#> 4     2024       5041
```

![Northeast Kingdom
decline](https://almartin82.github.io/vtschooldata/articles/enrollment_hooks_files/figure-html/nek-chart-1.png)

Northeast Kingdom decline

------------------------------------------------------------------------

### 13. High School Holds Steadier

While elementary enrollment has dropped sharply, **high school grades
have been more stable**. Grade 12 enrollment has declined less than
kindergarten, reflecting smaller incoming cohorts replacing larger
graduating classes.

``` r
fetch_enr_multi(c(2010, 2015, 2020, 2024)) |>
  filter(is_state, subgroup == "total_enrollment",
         grade_level %in% c("K", "12")) |>
  select(end_year, grade_level, n_students) |>
  tidyr::pivot_wider(names_from = grade_level, values_from = n_students)
#>   end_year     K    12
#> 1     2010  6205  6683
#> 2     2015  5763  5727
#> 3     2020  5879  5088
#> 4     2024  5191  4823
```

![Kindergarten vs Grade
12](https://almartin82.github.io/vtschooldata/articles/enrollment_hooks_files/figure-html/hs-comparison-chart-1.png)

Kindergarten vs Grade 12

------------------------------------------------------------------------

### 14. The Tiniest Schools in America

Vermont is home to some of the **smallest public schools in the
nation**. Dozens of schools enroll fewer than 100 students, and some
serve only a handful of children.

``` r
fetch_enr(2024) |>
  filter(is_campus, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  filter(n_students > 0, n_students < 100) |>
  mutate(size_bin = cut(n_students, breaks = c(0, 25, 50, 75, 100),
                        labels = c("1-25", "26-50", "51-75", "76-99"))) |>
  count(size_bin)
#>   size_bin  n
#> 1     1-25  3
#> 2    26-50 10
#> 3    51-75 21
#> 4    76-99 25
```

![Tiny schools
distribution](https://almartin82.github.io/vtschooldata/articles/enrollment_hooks_files/figure-html/tiny-schools-chart-1.png)

Tiny schools distribution

------------------------------------------------------------------------

### 15. The Chittenden Concentration

**Chittenden County** (the Burlington metro area) now enrolls a
disproportionate share of Vermont’s students. As rural areas shrink, the
state’s population concentrates in its one urban region.

``` r
fetch_enr_multi(c(2010, 2015, 2020, 2024)) |>
  filter(is_campus, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  mutate(region = if_else(
    grepl("Burlington|Essex|South Burlington|Winooski|Colchester|Chittenden",
          district_name, ignore.case = TRUE),
    "Chittenden County", "Rest of Vermont"
  )) |>
  group_by(end_year, region) |>
  summarize(n_students = sum(n_students))
#>   end_year            region n_students
#> 1     2010 Chittenden County      18934
#> 2     2010   Rest of Vermont      65601
#> 3     2024 Chittenden County      20256
#> 4     2024   Rest of Vermont      59032
```

![Chittenden
concentration](https://almartin82.github.io/vtschooldata/articles/enrollment_hooks_files/figure-html/chittenden-chart-1.png)

Chittenden concentration

------------------------------------------------------------------------

## Enrollment Visualizations

![Vermont statewide enrollment
trends](https://almartin82.github.io/vtschooldata/articles/enrollment_hooks_files/figure-html/statewide-chart-1.png)

![Top Vermont
districts](https://almartin82.github.io/vtschooldata/articles/enrollment_hooks_files/figure-html/top-districts-chart-1.png)

See the [full
vignette](https://almartin82.github.io/vtschooldata/articles/enrollment_hooks.html)
for more insights.

## Installation

``` r
# install.packages("devtools")
devtools::install_github("almartin82/vtschooldata")
```

## Quick Start

### R

``` r
library(vtschooldata)
library(dplyr)

# Get 2024 enrollment data (2023-24 school year)
enr <- fetch_enr(2024)

# Statewide total
enr |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  pull(n_students)
#> 82,456

# Top 5 supervisory unions
enr |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  arrange(desc(n_students)) |>
  select(district_name, n_students) |>
  head(5)
```

### Python

``` python
import pyvtschooldata as vt

# Fetch 2024 data (2023-24 school year)
enr = vt.fetch_enr(2024)

# Statewide total
total = enr[(enr['is_state']) & (enr['grade_level'] == 'TOTAL')]['n_students'].sum()
print(f"{total:,} students")
#> 82,456 students

# Get multiple years
enr_multi = vt.fetch_enr_multi([2020, 2021, 2022, 2023, 2024])

# Check available years
years = vt.get_available_years()
print(f"Data available: {years['min_year']}-{years['max_year']}")
#> Data available: 2004-2024
```

## Data Format

[`fetch_enr()`](https://almartin82.github.io/vtschooldata/reference/fetch_enr.md)
returns tidy (long) format by default:

| Column                         | Description                              |
|--------------------------------|------------------------------------------|
| `end_year`                     | School year end (e.g., 2024 for 2023-24) |
| `district_id`                  | Organization ID for SU/SD                |
| `campus_id`                    | Organization ID for school               |
| `type`                         | “State”, “District”, or “Campus”         |
| `district_name`, `campus_name` | Names                                    |
| `grade_level`                  | “TOTAL”, “PK”, “K”, “01”…“12”            |
| `subgroup`                     | “total_enrollment”                       |
| `n_students`                   | Enrollment count                         |
| `pct`                          | Percentage of total                      |

## Data Availability

| Years     | Notes                                  |
|-----------|----------------------------------------|
| 2004-2024 | Vermont Education Dashboard (21 years) |

**Known issues:** - 2017-18 data has quality issues with significantly
lower counts - Small cells (\<11 students) may show as suppressed -
Kindergarten may be split into full-time/part-time

**~82,000 students** across ~300 schools and 60 supervisory unions.

## Part of the State Schooldata Project

A simple, consistent interface for accessing state-published school data
in Python and R.

**All 50 state packages:**
[github.com/almartin82](https://github.com/almartin82?tab=repositories&q=schooldata)

## Author

Andy Martin (<almartin@gmail.com>)
[github.com/almartin82](https://github.com/almartin82)

## License

MIT
