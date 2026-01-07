# Vermont School Data Package - Expansion Research

## Graduation Rate Data

### Data Source Location

**Primary Data Source**: Vermont Education Dashboard (VED) - Student Information Dataset

- **Document Page**: https://education.vermont.gov/documents/ved-student-information-dataset
- **Direct Download URL**: https://education.vermont.gov/sites/aoe/files/documents/edu-student-information-9-5-2025.xlsx
- **HTTP Status**: 200 (Verified 2026-01-04)

Note: The filename contains a date suffix that changes with updates (similar to enrollment dataset pattern).

### Alternative Data Source (Interactive Only)

The School Snapshot site at https://schoolsnapshot.vermont.gov provides graduation rate data through an interactive dashboard, but does NOT provide bulk downloadable datasets. The VED Student Information dataset is the correct source for programmatic access.

### Data Structure

The VED Student Information dataset is a single Excel file containing multiple data types filtered by `StudentInformationGroup`:
- "Graduation Rate" - cohort graduation rates
- "Student Information" - other student metrics

#### Column Schema

| Column | Type | Description |
|--------|------|-------------|
| SchoolYear | numeric | End year of school year (e.g., 2024 for 2023-24) |
| OrganizationIdentifier | character | Organization ID (PS###, SU###, PI###, VT###) |
| NameOfInstitution | character | Organization name (may contain "NULL" for SUs) |
| StudentInformationGroup | character | "Graduation Rate" or "Student Information" |
| StudentInformationLabel | character | Rate type (see below) |
| SchoolPercentage | character | School-level rate (as decimal, e.g., 0.85 = 85%) |
| SupervisoryUnionPercentage | character | SU-level rate (as decimal) |
| StatePercentage | numeric | State-level rate (as decimal) |

#### Organization ID Patterns

| Prefix | Count | Description |
|--------|-------|-------------|
| PS | 327 | Public schools |
| SU | 46 | Supervisory Unions/School Districts |
| PI | 1 | Independent school (Rivendell Academy) |
| VT | 1 | State-level aggregate (2023-2024 only) |

### Schema Changes Over Time

#### StudentInformationLabel Evolution

| Years | Labels Available |
|-------|------------------|
| 2004-2017 | Five-year; Four-year; Six-year |
| 2018-2020 | Four-year; Six-year |
| 2021 | Five-year; Four-year; Six-year |
| 2022 | 4-year Graduation Rate; 6-year Graduation Rate |
| 2023-2024 | Four-year; Six-year |

**Implementation Note**: Label parsing must normalize variations:
- "Four-year", "4-year Graduation Rate" -> 4-year
- "Six-year", "6-year Graduation Rate" -> 6-year
- "Five-year" -> 5-year

#### StatePercentage Data Availability

State-level graduation rates only available from 2008 onwards:
- 2004-2007: StatePercentage = 0 for all records
- 2008+: Valid state-level percentages populated

#### Organization Count Changes

| Era | Schools | Notes |
|-----|---------|-------|
| 2004-2007 | 308-311 | Full coverage |
| 2008-2017 | 295-309 | Gradual decline |
| 2018 | 295 | But only 2 labels |
| 2019-2020 | 57 | Major reduction (COVID era?) |
| 2021 | 290 | Recovery with 3 labels |
| 2022 | 56 | Reduced again |
| 2023-2024 | 103 | Partial recovery |

### Suppression and Special Values

| Value | Meaning |
|-------|---------|
| "NULL" | Suppressed/unavailable |
| "0" | Zero graduation rate (may be legitimate or suppressed) |
| 0.0-1.0 | Valid percentage as decimal |

### Time Series Heuristics

#### State 4-Year Graduation Rate

| Year | Rate | Notes |
|------|------|-------|
| 2008 | 85.9% | First year with state data |
| 2010 | 87.2% | |
| 2017 | 89.1% | Peak |
| 2020 | 83.0% | COVID impact |
| 2024 | 82.0% | Most recent |

**Expected Range**: 80-90%
**YoY Change Threshold**: <3% normal, >5% investigate

#### State 6-Year Graduation Rate

| Year | Rate | Notes |
|------|------|-------|
| 2010 | 89.3% | First year with data |
| 2016 | 91.5% | Peak |
| 2020 | 88.3% | COVID impact |
| 2024 | 85.0% | Most recent |

**Expected Range**: 85-92%
**6-year should exceed 4-year**: Yes, typically by 3-5 percentage points

#### School-Level Rates (2024)

- Minimum: 59%
- Median: 81%
- Maximum: 98%
- Valid records: 56 of 103

### Implementation Recommendations

1. **Use Student Information dataset** - Same download pattern as enrollment, but filter for StudentInformationGroup == "Graduation Rate"

2. **Normalize labels** - Handle "Four-year" vs "4-year Graduation Rate" variations

3. **Handle suppression** - Convert "NULL" and possibly "0" to NA

4. **Percentage format** - Values are decimals (0.85 = 85%), may need conversion to percentage format

5. **Limited state history** - State-level data only from 2008; 2004-2007 only has school-level

6. **Organization coverage varies** - Some years (2019-2020, 2022) have dramatically fewer organizations

7. **VT001 org ID** - State-level aggregate appears as organization only in 2023-2024

### Required Functions

```r
# Proposed function signature
fetch_grad_rate <- function(
  end_year,
  rate_type = c("4-year", "6-year", "5-year"),  # 5-year only some years
  tidy = TRUE,
  use_cache = TRUE
)
```

### Test Cases

1. **State total for 2024**: 4-year = 82%, 6-year = 85%
2. **State total for 2010**: 4-year = 87.2%, 6-year = 89.3%
3. **Suppressed values**: Verify "NULL" converted to NA
4. **Label normalization**: "4-year Graduation Rate" (2022) returns same structure as "Four-year" (2024)
5. **Organization count**: 103 unique orgs in 2024 with graduation data

### URL Construction

The dataset URL follows the VED pattern:
```r
build_ved_student_info_url <- function() {
  # Scrape document page for current filename
  # Pattern: edu-student-information-{date}.xlsx
  doc_url <- "https://education.vermont.gov/documents/ved-student-information-dataset"
  # Extract and return full URL
}
```

---

## Research Date

2026-01-04

## Status

SCOPING COMPLETE - Ready for implementation when prioritized.
