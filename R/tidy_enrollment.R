# ==============================================================================
# Enrollment Data Tidying Functions
# ==============================================================================
#
# This file contains functions for transforming enrollment data from wide
# format to long (tidy) format and identifying aggregation levels.
#
# ==============================================================================

# Declare NSE variables used in dplyr operations
utils::globalVariables(c(
  "row_total", "n_students", "subgroup", "grade_level", "type", "aggregation_flag"
))

#' Tidy enrollment data
#'
#' Transforms wide enrollment data to long format with subgroup column.
#'
#' @param df A wide data.frame of processed enrollment data
#' @return A long data.frame of tidied enrollment data
#' @export
#' @examples
#' \dontrun{
#' wide_data <- fetch_enr(2024, tidy = FALSE)
#' tidy_data <- tidy_enr(wide_data)
#' }
tidy_enr <- function(df) {

  # Invariant columns (identifiers that stay the same)
  invariants <- c(
    "end_year", "type",
    "district_id", "campus_id",
    "district_name", "campus_name",
    "county"
  )
  invariants <- invariants[invariants %in% names(df)]

  # Vermont data primarily has grade-level data, not demographic breakdowns
  # in the main enrollment dashboard

  # Grade-level columns
  grade_cols <- grep("^grade_", names(df), value = TRUE)

  # Extract total enrollment as a "subgroup"
  if ("row_total" %in% names(df)) {
    tidy_total <- df |>
      dplyr::select(dplyr::all_of(c(invariants, "row_total"))) |>
      dplyr::mutate(
        n_students = row_total,
        subgroup = "total_enrollment",
        pct = 1.0,
        grade_level = "TOTAL"
      ) |>
      dplyr::select(dplyr::all_of(c(invariants, "grade_level", "subgroup", "n_students", "pct")))
  } else {
    tidy_total <- NULL
  }

  # Transform grade-level enrollment to long format
  if (length(grade_cols) > 0) {
    grade_level_map <- c(
      "grade_pk" = "PK",
      "grade_k" = "K",
      "grade_01" = "01",
      "grade_02" = "02",
      "grade_03" = "03",
      "grade_04" = "04",
      "grade_05" = "05",
      "grade_06" = "06",
      "grade_07" = "07",
      "grade_08" = "08",
      "grade_09" = "09",
      "grade_10" = "10",
      "grade_11" = "11",
      "grade_12" = "12"
    )

    tidy_grades <- purrr::map_df(
      grade_cols,
      function(.x) {
        gl <- grade_level_map[.x]
        if (is.na(gl)) gl <- .x

        result_df <- df |>
          dplyr::select(dplyr::all_of(c(invariants, .x)))

        # Rename the grade column to n_students
        names(result_df)[names(result_df) == .x] <- "n_students"

        # Add row_total if available for percentage calculation
        if ("row_total" %in% names(df)) {
          result_df$row_total <- df$row_total
          result_df <- result_df |>
            dplyr::mutate(
              pct = dplyr::case_when(
                row_total > 0 ~ pmin(n_students / row_total, 1.0),
                TRUE ~ 0.0
              ),
              subgroup = "total_enrollment",
              grade_level = gl
            ) |>
            dplyr::select(dplyr::all_of(c(invariants, "grade_level", "subgroup", "n_students", "pct")))
        } else {
          result_df <- result_df |>
            dplyr::mutate(
              pct = NA_real_,
              subgroup = "total_enrollment",
              grade_level = gl
            ) |>
            dplyr::select(dplyr::all_of(c(invariants, "grade_level", "subgroup", "n_students", "pct")))
        }

        result_df
      }
    )
  } else {
    tidy_grades <- NULL
  }

  # Combine all tidy data
  dplyr::bind_rows(tidy_total, tidy_grades) |>
    dplyr::filter(!is.na(n_students))
}


#' Identify enrollment aggregation levels
#'
#' Adds boolean flags to identify state, district, and campus level records.
#'
#' @param df Enrollment dataframe, output of tidy_enr
#' @return data.frame with boolean aggregation flags
#' @export
#' @examples
#' \dontrun{
#' tidy_data <- fetch_enr(2024)
#' # Data already has aggregation flags via id_enr_aggs
#' table(tidy_data$is_state, tidy_data$is_district, tidy_data$is_campus)
#' }
id_enr_aggs <- function(df) {
  df |>
    dplyr::mutate(
      # State level: Type == "State"
      is_state = type == "State",

      # District level: Type == "District"
      is_district = type == "District",

      # Campus level: Type == "Campus"
      is_campus = type == "Campus",

      # Aggregation flag: single column indicating level
      aggregation_flag = dplyr::case_when(
        type == "Campus" ~ "campus",
        type == "District" ~ "district",
        type == "State" ~ "state",
        TRUE ~ "state"
      )
    )
}


#' Custom Enrollment Grade Level Aggregates
#'
#' Creates aggregations for common grade groupings: K-8, 9-12 (HS), K-12.
#'
#' @param df A tidy enrollment df
#' @return df of aggregated enrollment data
#' @export
#' @examples
#' \dontrun{
#' tidy_data <- fetch_enr(2024)
#' grade_aggs <- enr_grade_aggs(tidy_data)
#' }
enr_grade_aggs <- function(df) {

  # Group by invariants (everything except grade_level and counts)
  group_vars <- c(
    "end_year", "type",
    "district_id", "campus_id",
    "district_name", "campus_name",
    "county",
    "subgroup",
    "is_state", "is_district", "is_campus"
  )
  group_vars <- group_vars[group_vars %in% names(df)]

  # K-8 aggregate
  k8_agg <- df |>
    dplyr::filter(
      subgroup == "total_enrollment",
      grade_level %in% c("K", "01", "02", "03", "04", "05", "06", "07", "08")
    ) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_vars))) |>
    dplyr::summarize(
      n_students = sum(n_students, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      grade_level = "K8",
      pct = NA_real_
    )

  # High school (9-12) aggregate
  hs_agg <- df |>
    dplyr::filter(
      subgroup == "total_enrollment",
      grade_level %in% c("09", "10", "11", "12")
    ) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_vars))) |>
    dplyr::summarize(
      n_students = sum(n_students, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      grade_level = "HS",
      pct = NA_real_
    )

  # K-12 aggregate (excludes PK)
  k12_agg <- df |>
    dplyr::filter(
      subgroup == "total_enrollment",
      grade_level %in% c("K", "01", "02", "03", "04", "05", "06", "07", "08",
                         "09", "10", "11", "12")
    ) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_vars))) |>
    dplyr::summarize(
      n_students = sum(n_students, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      grade_level = "K12",
      pct = NA_real_
    )

  dplyr::bind_rows(k8_agg, hs_agg, k12_agg)
}
