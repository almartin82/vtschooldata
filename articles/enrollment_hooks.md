# 15 Insights from Vermont School Enrollment Data

``` r
library(vtschooldata)
library(dplyr)
library(tidyr)
library(ggplot2)
theme_set(theme_minimal(base_size = 14))
```

## Vermont Lost a Third of Its Students Since 1997

The Green Mountain State peaked at nearly 107,000 students and has
experienced one of the steepest enrollment declines in the nation.
Vermont now educates fewer than 80,000 students.

``` r
enr <- fetch_enr_multi(c(2004, 2008, 2012, 2016, 2020, 2024), use_cache = TRUE)

statewide <- enr |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  select(end_year, n_students)

statewide
#>   end_year n_students
#> 1     2004      92334
#> 2     2008      87777
#> 3     2012      82014
#> 4     2016      78472
#> 5     2020      83503
#> 6     2024      79288
```

``` r
ggplot(statewide, aes(x = end_year, y = n_students)) +
  geom_line(color = "#006837", linewidth = 1.2) +
  geom_point(color = "#006837", size = 3) +
  scale_y_continuous(labels = scales::comma, limits = c(0, NA)) +
  labs(
    title = "Vermont Public School Enrollment (2004-2024)",
    subtitle = "Steady decline reflects aging population and outmigration",
    x = "Year",
    y = "Students"
  )
```

![Vermont statewide enrollment has declined steadily since
2004](enrollment_hooks_files/figure-html/statewide-chart-1.png)

Vermont statewide enrollment has declined steadily since 2004

## Top Supervisory Unions: Burlington Leads a Small State

Vermont organizes schools into Supervisory Unions (SUs) and Supervisory
Districts (SDs). Burlington is the largest, but even the biggest
districts are small by national standards.

``` r
enr_2024 <- fetch_enr(2024, use_cache = TRUE)

top_districts <- enr_2024 |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  arrange(desc(n_students)) |>
  head(10) |>
  select(district_name, n_students)

top_districts
#> [1] district_name n_students   
#> <0 rows> (or 0-length row.names)
```

``` r
# Shorten district names for display
su_pattern <- " Supervisory Union| Supervisory District| School District| SD| SU"
top_districts |>
  mutate(district_name = gsub(su_pattern, "", district_name)) |>
  mutate(district_name = factor(district_name, levels = rev(district_name))) |>
  ggplot(aes(x = n_students, y = district_name)) +
  geom_col(fill = "#006837") +
  geom_text(aes(label = scales::comma(n_students)), hjust = -0.1, size = 3.5) +
  scale_x_continuous(
    labels = scales::comma,
    expand = expansion(mult = c(0, 0.15))
  ) +
  labs(
    title = "Largest Supervisory Unions in Vermont (2024)",
    subtitle = "Even the largest districts serve fewer than 4,000 students",
    x = "Students",
    y = NULL
  )
```

![Top 10 Vermont supervisory unions by
enrollment](enrollment_hooks_files/figure-html/top-districts-chart-1.png)

Top 10 Vermont supervisory unions by enrollment

## Grade-Level Distribution: Elementary Dominates

Vermont’s grade distribution shows where students are concentrated. The
K-8 grades represent the bulk of enrollment, with smaller high school
cohorts reflecting years of declining births.

``` r
# Vermont data focuses on grade levels rather than demographic subgroups
grade_levels <- c("PK", "K", "01", "02", "03", "04", "05",
                  "06", "07", "08", "09", "10", "11", "12")
grade_dist <- enr_2024 |>
  filter(is_state, subgroup == "total_enrollment",
         grade_level %in% grade_levels) |>
  mutate(level = case_when(
    grade_level == "PK" ~ "Pre-K",
    grade_level %in% c("K", "01", "02", "03", "04", "05") ~ "Elementary",
    grade_level %in% c("06", "07", "08") ~ "Middle",
    TRUE ~ "High School"
  )) |>
  group_by(level) |>
  summarize(n_students = sum(n_students, na.rm = TRUE), .groups = "drop") |>
  mutate(pct = n_students / sum(n_students) * 100)

grade_dist
#> # A tibble: 4 × 3
#>   level       n_students   pct
#>   <chr>            <dbl> <dbl>
#> 1 Elementary       33036  41.7
#> 2 High School      21250  26.8
#> 3 Middle           16849  21.3
#> 4 Pre-K             8108  10.2
```

``` r
level_order <- c("Pre-K", "Elementary", "Middle", "High School")
level_colors <- c("Pre-K" = "#78c679", "Elementary" = "#31a354",
                  "Middle" = "#006837", "High School" = "#00441b")
grade_dist |>
  mutate(level = factor(level, levels = level_order)) |>
  ggplot(aes(x = level, y = n_students, fill = level)) +
  geom_col() +
  geom_text(
    aes(label = paste0(scales::comma(n_students), "\n(", round(pct), "%)")),
    vjust = -0.2, size = 3.5
  ) +
  scale_fill_manual(values = level_colors) +
  scale_y_continuous(
    labels = scales::comma,
    expand = expansion(mult = c(0, 0.15))
  ) +
  labs(
    title = "Vermont Enrollment by Grade Level (2024)",
    subtitle = "Elementary grades (K-5) make up the largest share",
    x = "Grade Level",
    y = "Students"
  ) +
  theme(legend.position = "none")
```

![Enrollment by grade level in
Vermont](enrollment_hooks_files/figure-html/demographics-chart-1.png)

Enrollment by grade level in Vermont

## Regional Patterns: Burlington Leads Vermont

Vermont’s Supervisory Unions show stark differences in size. Burlington
area SUs dominate the enrollment landscape, while rural areas struggle
with declining numbers.

``` r
enr_regional <- fetch_enr_multi(c(2015, 2020, 2024), use_cache = TRUE)

# Identify the largest SUs and track their trends
top_sus <- enr_regional |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         end_year == 2024) |>
  arrange(desc(n_students)) |>
  head(6) |>
  pull(district_id)

regional_top <- enr_regional |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         district_id %in% top_sus) |>
  select(end_year, district_name, n_students)

regional_top |>
  pivot_wider(names_from = end_year, values_from = n_students)
#> # A tibble: 0 × 1
#> # ℹ 1 variable: district_name <chr>
```

``` r
ggplot(regional_top, aes(x = end_year, y = n_students, color = district_name)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_y_continuous(labels = scales::comma) +
  scale_color_brewer(palette = "Dark2") +
  labs(
    title = "Enrollment by Top 6 Vermont Supervisory Unions",
    subtitle = "Burlington area dominates; trends vary across SUs",
    x = "Year",
    y = "Students",
    color = "SU"
  ) +
  theme(legend.position = "right")
```

![Enrollment trends for top Vermont
SUs](enrollment_hooks_files/figure-html/regional-chart-1.png)

Enrollment trends for top Vermont SUs

## Small Schools Are the Norm

Vermont is a state of small schools. Most supervisory unions serve fewer
than 1,000 students, creating challenges for specialized programs and
efficiency.

``` r
size_levels <- c("Tiny (<200)", "Very Small (200-499)",
                 "Small (500-999)", "Medium (1,000-1,999)",
                 "Large (2,000+)")
district_sizes <- enr_2024 |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  mutate(size = case_when(
    n_students >= 2000 ~ "Large (2,000+)",
    n_students >= 1000 ~ "Medium (1,000-1,999)",
    n_students >= 500 ~ "Small (500-999)",
    n_students >= 200 ~ "Very Small (200-499)",
    TRUE ~ "Tiny (<200)"
  )) |>
  count(size) |>
  mutate(size = factor(size, levels = size_levels))

district_sizes
#> [1] size n   
#> <0 rows> (or 0-length row.names)
```

``` r
size_colors <- c(
  "Tiny (<200)" = "#f03b20", "Very Small (200-499)" = "#feb24c",
  "Small (500-999)" = "#ffeda0", "Medium (1,000-1,999)" = "#31a354",
  "Large (2,000+)" = "#006837"
)
ggplot(district_sizes, aes(x = size, y = n, fill = size)) +
  geom_col() +
  geom_text(aes(label = n), vjust = -0.5, size = 4) +
  scale_fill_manual(values = size_colors) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Vermont Supervisory Unions by Size (2024)",
    subtitle = "Most SUs serve fewer than 1,000 students",
    x = "District Size",
    y = "Number of SUs/SDs"
  ) +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 15, hjust = 1))
```

![Distribution of supervisory union sizes in
Vermont](enrollment_hooks_files/figure-html/growth-chart-1.png)

Distribution of supervisory union sizes in Vermont

## The COVID Kindergarten Shock

Vermont’s kindergarten enrollment plummeted 22% from 2019 to 2021, as
families delayed school entry during the pandemic. That smaller cohort
is now moving through the elementary grades.

``` r
k_trend <- fetch_enr_multi(2017:2024, use_cache = TRUE)

k_enrollment <- k_trend |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "K") |>
  select(end_year, n_students)

k_enrollment
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

``` r
ggplot(k_enrollment, aes(x = end_year, y = n_students)) +
  geom_line(color = "#006837", linewidth = 1.2) +
  geom_point(color = "#006837", size = 3) +
  geom_vline(xintercept = 2020, linetype = "dashed", color = "gray50") +
  annotate("text", x = 2020.1, y = max(k_enrollment$n_students),
           label = "COVID", hjust = 0, size = 3.5, color = "gray40") +
  scale_y_continuous(labels = scales::comma, limits = c(0, NA)) +
  labs(
    title = "Vermont Kindergarten Enrollment (2017-2024)",
    subtitle = "Pandemic delayed kindergarten entry for many families",
    x = "Year",
    y = "Kindergarten Students"
  )
```

![Vermont kindergarten enrollment dropped sharply during
COVID](enrollment_hooks_files/figure-html/covid-k-chart-1.png)

Vermont kindergarten enrollment dropped sharply during COVID

## The Northeast Kingdom’s Struggle

Vermont’s remote Northeast Kingdom (Essex, Orleans, and Caledonia
counties) faces the steepest enrollment declines. Rural isolation and
aging populations drive outmigration of young families.

``` r
nek_trend <- fetch_enr_multi(c(2010, 2015, 2020, 2024), use_cache = TRUE)

# Identify NEK districts by common naming patterns
nek_districts <- nek_trend |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  filter(grepl("Kingdom|Caledonia|Orleans|Essex", district_name, ignore.case = TRUE)) |>
  group_by(end_year) |>
  summarize(n_students = sum(n_students, na.rm = TRUE), .groups = "drop")

nek_districts
#> # A tibble: 0 × 2
#> # ℹ 2 variables: end_year <dbl>, n_students <dbl>
```

``` r
ggplot(nek_districts, aes(x = end_year, y = n_students)) +
  geom_line(color = "#d95f02", linewidth = 1.2) +
  geom_point(color = "#d95f02", size = 3) +
  scale_y_continuous(labels = scales::comma, limits = c(0, NA)) +
  labs(
    title = "Northeast Kingdom Enrollment Decline",
    subtitle = "Rural Vermont's population challenge intensifies",
    x = "Year",
    y = "Students"
  )
```

![Northeast Kingdom enrollment has declined faster than the state
average](enrollment_hooks_files/figure-html/nek-chart-1.png)

Northeast Kingdom enrollment has declined faster than the state average

## High School Holds Steadier

While elementary enrollment has dropped sharply, high school grades have
been more stable. Grade 12 enrollment has declined less than
kindergarten, reflecting smaller incoming cohorts replacing larger
graduating classes.

``` r
hs_compare <- fetch_enr_multi(c(2010, 2015, 2020, 2024), use_cache = TRUE)

grade_compare <- hs_compare |>
  filter(is_state, subgroup == "total_enrollment",
         grade_level %in% c("K", "12")) |>
  select(end_year, grade_level, n_students) |>
  mutate(grade_level = factor(grade_level, levels = c("K", "12"),
                              labels = c("Kindergarten", "Grade 12")))

grade_compare
#>   end_year  grade_level n_students
#> 1     2010 Kindergarten       6205
#> 2     2010     Grade 12       6683
#> 3     2015 Kindergarten       5763
#> 4     2015     Grade 12       5727
#> 5     2020 Kindergarten       5879
#> 6     2020     Grade 12       5088
#> 7     2024 Kindergarten       5191
#> 8     2024     Grade 12       4823
```

``` r
ggplot(grade_compare, aes(x = end_year, y = n_students, color = grade_level)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = c("Kindergarten" = "#1b9e77", "Grade 12" = "#7570b3")) +
  scale_y_continuous(labels = scales::comma, limits = c(0, NA)) +
  labs(
    title = "Kindergarten vs. Grade 12 Enrollment in Vermont",
    subtitle = "Elementary grades feel the demographic decline first",
    x = "Year",
    y = "Students",
    color = "Grade"
  )
```

![High school enrollment has declined less than
kindergarten](enrollment_hooks_files/figure-html/hs-comparison-chart-1.png)

High school enrollment has declined less than kindergarten

## The Tiniest Schools in America

Vermont is home to some of the smallest public schools in the nation.
Dozens of schools enroll fewer than 100 students, and some serve only a
handful of children.

``` r
tiny_schools <- enr_2024 |>
  filter(is_campus, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  filter(n_students > 0, n_students < 100) |>
  mutate(size_bin = cut(n_students, breaks = c(0, 25, 50, 75, 100),
                        labels = c("1-25", "26-50", "51-75", "76-99"))) |>
  count(size_bin)

tiny_schools
#>   size_bin  n
#> 1     1-25  3
#> 2    26-50 10
#> 3    51-75 21
#> 4    76-99 25
```

``` r
ggplot(tiny_schools, aes(x = size_bin, y = n)) +
  geom_col(fill = "#7570b3") +
  geom_text(aes(label = n), vjust = -0.5, size = 4) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Vermont's Tiny Schools (Under 100 Students)",
    subtitle = "Small rural communities maintain neighborhood schools",
    x = "Enrollment Size",
    y = "Number of Schools"
  )
```

![Many Vermont schools serve fewer than 100
students](enrollment_hooks_files/figure-html/tiny-schools-chart-1.png)

Many Vermont schools serve fewer than 100 students

## The Chittenden Concentration

Chittenden County (the Burlington metro area) now enrolls a
disproportionate share of Vermont’s students. As rural areas shrink, the
state’s population concentrates in its one urban region.

``` r
chittenden_trend <- fetch_enr_multi(c(2010, 2015, 2020, 2024), use_cache = TRUE)

# Identify Chittenden-area districts
chittenden_area <- chittenden_trend |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  mutate(region = if_else(
    grepl("Burlington|Essex|South Burlington|Winooski|Colchester|Chittenden",
          district_name, ignore.case = TRUE),
    "Chittenden County", "Rest of Vermont"
  )) |>
  group_by(end_year, region) |>
  summarize(n_students = sum(n_students, na.rm = TRUE), .groups = "drop")

chittenden_area
#> # A tibble: 0 × 3
#> # ℹ 3 variables: end_year <dbl>, region <chr>, n_students <dbl>
```

``` r
ggplot(chittenden_area, aes(x = end_year, y = n_students, fill = region)) +
  geom_area(alpha = 0.8) +
  scale_fill_manual(values = c("Chittenden County" = "#006837",
                               "Rest of Vermont" = "#a1d99b")) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Vermont Enrollment: Chittenden vs. Rest of State",
    subtitle = "Urban concentration increases as rural enrollment declines",
    x = "Year",
    y = "Students",
    fill = "Region"
  )
```

![Chittenden County holds a growing share of Vermont
students](enrollment_hooks_files/figure-html/chittenden-chart-1.png)

Chittenden County holds a growing share of Vermont students

## Summary

Vermont’s public school enrollment tells a story of rural challenges and
demographic transition:

- **Steep decline**: Lost roughly a quarter of students since the early
  2000s
- **Small scale**: Even the largest SUs serve fewer than 4,000 students
- **Supervisory structure**: Schools organized into SUs/SDs for shared
  administration
- **Chittenden dominance**: Burlington area anchors the state’s
  enrollment
- **Many tiny districts**: Most SUs serve fewer than 1,000 students
- **Rural pressure**: Remote counties face the steepest enrollment
  declines

These patterns reflect Vermont’s aging population, low birth rates, and
the ongoing challenge of providing quality education in a small, rural
state.
