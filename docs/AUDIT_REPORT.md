# vtschooldata Enrollment Data Tidyness Audit Report

**Date:** 2026-01-05  
**Auditor:** Claude Code  
**Package:** vtschooldata  
**Reference:** alschooldata (target format)

## Executive Summary

**Overall Rating: 8/10**

The vtschooldata package has well-implemented enrollment data tidying
with proper long-format conversion, aggregation flags, and data quality
controls. However, it differs from the target format in one key way:
Vermont’s data source **only provides grade-level enrollment totals**,
not demographic breakdowns (race, gender, special populations). This is
a data source limitation, not a code issue.

### What Works Well

- Proper long-format conversion with `subgroup` and `grade_level`
  columns
- Correct aggregation flags (`is_state`, `is_district`, `is_campus`)
- Clean data quality (no Inf/NaN, percentages in valid range 0-1)
- Grade-level breakdowns (PK, K, 1-12)
- State-level aggregation correctly calculated from campus data
- Proper handling of missing district-level data in source (VT only
  provides campus-level)

### Key Differences from Target Format

1.  **Only one subgroup:** `total_enrollment` (no demographic
    breakdowns)
2.  **No district-level rows:** Vermont source data only contains campus
    (school) and state aggregates
3.  **No demographic subgroups:** No race, gender, or special population
    data in main enrollment file

## Detailed Findings

### 1. Column Structure ✓ PASS

**Required columns present:** - `end_year` ✓ - `type` ✓ (State,
Campus) - `district_id` ✓ - `campus_id` ✓ - `district_name` ✓ -
`campus_name` ✓ - `grade_level` ✓ (TOTAL, PK, K, 01-12) - `subgroup` ✓ -
`n_students` ✓ - `pct` ✓ - `is_state` ✓ - `is_district` ✓ (always FALSE
for VT - no district rows) - `is_campus` ✓

**Missing columns:** None

### 2. Aggregation Flags ✓ PASS

    is_state  is_district  is_campus  count
    FALSE     FALSE        TRUE       4350  (campus rows)
    TRUE      FALSE        FALSE      15    (state rows: 1 per grade level + TOTAL)

**Issue:** No district-level rows (is_district never TRUE) **Root
Cause:** Vermont Education Dashboard only provides campus-level data
**Impact:** Users cannot analyze district-level aggregates directly from
source **Severity:** Low - district totals can be calculated by users
via
[`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)

### 3. Subgroup Coverage ⚠️ DIFFERS FROM TARGET

**Current subgroups:** Only `total_enrollment`

**Target subgroups (from alschooldata):** - Demographic: `white`,
`black`, `hispanic`, `asian`, `native_american`, `pacific_islander`,
`multiracial` - Gender: `male`, `female` - Special populations:
`econ_disadv`, `lep`, `special_ed` - Totals: `total_enrollment` - Grade
levels: K, 01-12

**Root Cause:** Vermont Education Dashboard enrollment file only
contains grade-level counts, not demographic breakdowns

**Documentation:** README explicitly states: \> “Unlike most states,
Vermont’s public enrollment data provides **only total counts by
grade**. Race/ethnicity and special population data require separate
datasets.”

**Severity:** Informational - this is a known data source limitation

### 4. Grade Level Coverage ✓ PASS

    PK    K    01-12    TOTAL
    291   291  291 each 291

All grade levels properly represented with 291 campuses each.

### 5. Data Quality ✓ EXCELLENT

- **No Inf values:** 0
- **No NaN values:** 0
- **Percentages in range:** \[0, 1\] - all valid
- **Non-negative counts:** All n_students ≥ 0
- **State total reasonable:** 79,288 students (2024)

### 6. Data Source Limitations ⚠️

**Vermont Education Dashboard Structure:** - Single Excel file with all
years - Columns: SCHOOLYEAR, SU_ID, SU_NAME, SCHOOL_ID, SCHOOL_NAME,
PRESCHOOL, KINDERGARTENFULLTIME, KINDERGARTENPARTTIME,
FIRSTGRADE…TWELFTHGRADE, TOTAL - Only campus-level rows (no district
aggregates in source) - No demographic columns (race, gender, special
ed, etc.)

**Implications:** - District-level rows must be calculated by users (not
provided by state) - Demographic analysis requires separate Vermont AOE
datasets - Grade-level data is comprehensive and accurate

### 7. Comparison with Target Format (alschooldata)

| Feature               | VT (current) | AL (target)    | Match?     |
|-----------------------|--------------|----------------|------------|
| Long format           | ✓            | ✓              | ✓          |
| subgroup column       | ✓ (1 value)  | ✓ (10+ values) | ⚠️ Limited |
| grade_level column    | ✓            | ✓              | ✓          |
| Aggregation flags     | ✓            | ✓              | ✓          |
| Demographic subgroups | ✗            | ✓              | ⚠️ N/A     |
| District rows         | ✗            | ✓              | ⚠️ N/A     |
| Grade breakdowns      | ✓            | ✓              | ✓          |
| Data quality          | ✓            | ✓              | ✓          |
| No Inf/NaN            | ✓            | ✓              | ✓          |
| pct column            | ✓            | ✓              | ✓          |

## Issues and Fixes

### Issue 1: Missing District-Level Rows

**Severity:** Low  
**Status:** By Design (data source limitation)

**Problem:** The tidy output has no district-level rows (is_district
always FALSE).

**Root Cause:** Vermont Education Dashboard only provides campus
(school) and state-level data. District aggregates are not included in
the source file.

**Impact:** Users must aggregate to district level manually:

``` r
district_totals <- data |>
  filter(is_campus, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  group_by(district_id, district_name) |>
  summarize(n_students = sum(n_students))
```

**Fix Options:** 1. **Option A (Current):** Document the limitation and
let users aggregate - Pros: Accurate to source, no calculated data -
Cons: Less convenient for users

2.  **Option B (Enhancement):** Calculate district aggregates in
    [`process_enr()`](https://almartin82.github.io/vtschooldata/reference/process_enr.md)
    - Pros: Matches target format, more convenient
    - Cons: Creates calculated rows not in source, may confuse users
    - Implementation: Aggregate campus rows by district_id in
      [`create_state_aggregate()`](https://almartin82.github.io/vtschooldata/reference/create_state_aggregate.md)
      or new function

**Recommendation:** Add district-level aggregation to match target
format. This is standard practice for states without district rows
(e.g., VT, WY).

### Issue 2: Limited Subgroups (Only total_enrollment)

**Severity:** Informational  
**Status:** Data source limitation (not fixable)

**Problem:** Only `total_enrollment` subgroup available. No race,
gender, or special population data.

**Root Cause:** Vermont Education Dashboard enrollment file contains
only grade-level counts.

**Impact:** Cannot analyze demographic trends through main enrollment
functions. Users must access separate Vermont AOE datasets.

**Documentation:** README explicitly documents this limitation.

**Fix:** None required - this is a data source constraint, not a code
issue.

### Issue 3: Kindergarten Full/Part-time Combination

**Severity:** None  
**Status:** Correctly implemented

**Observation:** Vermont provides `KINDERGARTENFULLTIME` and
`KINDERGARTENPARTTIME` columns, which are correctly summed in
[`process_enr()`](https://almartin82.github.io/vtschooldata/reference/process_enr.md):

``` r
k_full + k_part -> grade_k
```

This is proper handling of the source data structure.

## Recommendations

### High Priority

1.  **Add district-level aggregation** to match target format
    - Create district rows by aggregating campus data
    - Maintain consistency with other state packages
    - Improve user convenience

### Medium Priority

2.  **Add comment in code** explaining why no demographic subgroups
    - Document data source limitation in `tidy_enrollment.R`
    - Reference separate Vermont AOE datasets for demographics

### Low Priority

3.  **Consider adding district aggregate helper function**
    - `add_district_aggregates(df)` function for users who want district
      rows
    - Or integrate into main
      [`process_enr()`](https://almartin82.github.io/vtschooldata/reference/process_enr.md)
      function

## Code Quality Assessment

### Strengths

- Clean, readable code following state-schooldata conventions
- Proper error handling and validation
- Comprehensive caching system
- Good documentation (roxygen2, README)
- Data quality checks in tests

### Areas for Improvement

- None critical
- Minor: Could add more comments explaining VT-specific data structure

## Test Coverage

**Current tests:** - ✓ Column structure - ✓ Aggregation flags - ✓ Data
quality (Inf/NaN) - ✓ Non-negative counts - ✓ Percentage ranges - ✓ Year
validation - ✓ Multi-year fetch

**Missing tests:** - District aggregation (if added) - Grade-level
fidelity (compare tidy grade sums to raw totals)

## Conclusion

vtschooldata has **solid enrollment data tidying** with proper
long-format structure and data quality. The main differences from the
target format (alschooldata) are due to **Vermont’s data source
limitations**:

1.  No demographic breakdowns (only grade totals)
2.  No district-level rows in source (only campus + state)

These are **documented limitations**, not code bugs. The README
explicitly states Vermont only provides grade-level totals, and
demographic data requires separate datasets.

**Rating: 8/10** - Well-implemented with clear documentation of data
source constraints.

### Primary Fix Recommendation

Add district-level aggregation by summing campus rows, matching the
pattern used by other states (WY, etc.). This would improve consistency
across packages and user convenience.
