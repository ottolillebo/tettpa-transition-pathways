suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readxl)
  library(readr)
  library(stringr)
  library(lubridate)
  library(forcats)
  library(survival)
  library(splines)
  library(broom)
})

# Shared data-preparation helpers, also used by article_analysis.R. Run from the
# package root:
#   Rscript scripts/appendix_robustness_analysis.R
source("scripts/shared_functions.R")


# ---- Setup: paths and parameters ----
options(stringsAsFactors = FALSE, width = 160)

data_file <- Sys.getenv(
  "TETTPA_DATA_FILE",
  file.path("data", "restricted", "StatisticsCaseDetailsList.xlsm")
)
if (!file.exists(data_file)) {
  stop(
    "Restricted source data not found. Set TETTPA_DATA_FILE to the approved ",
    "local extract before running this script. See docs/DATA_ACCESS.md.",
    call. = FALSE
  )
}
output_dir <- Sys.getenv("TETTPA_APPENDIX_OUTPUT_DIR", "outputs/appendix_robustness")
table_dir <- file.path(output_dir, "tables")
diagnostic_dir <- file.path(output_dir, "diagnostics")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostic_dir, recursive = TRUE, showWarnings = FALSE)

administrative_end <- as.Date("2025-05-31")
education_act_start <- as.Date("2024-08-01")


# ---- Helpers used only in this script ----
ascii_label <- function(x) {
  x |>
    str_replace_all("å", "a") |>
    str_replace_all("Å", "A") |>
    str_replace_all("ø", "o") |>
    str_replace_all("Ø", "O") |>
    str_replace_all("æ", "ae") |>
    str_replace_all("Æ", "Ae") |>
    str_replace_all("/", "_")
}

aj_cif <- function(data, time_col, status_col, event_status, time_days = 365) {
  d <- data |>
    transmute(
      time = .data[[time_col]],
      status = .data[[status_col]]
    ) |>
    filter(!is.na(time), time >= 0) |>
    arrange(time)

  survival_prob <- 1
  cif <- 0
  for (t in sort(unique(d$time[d$time <= time_days]))) {
    at_risk <- sum(d$time >= t)
    event_count <- sum(d$time == t & d$status == event_status)
    all_events <- sum(d$time == t & d$status != "censored")
    if (at_risk > 0 && event_count > 0) {
      cif <- cif + survival_prob * event_count / at_risk
    }
    if (at_risk > 0 && all_events > 0) {
      survival_prob <- survival_prob * (1 - all_events / at_risk)
    }
  }
  cif
}


# ---- Load raw data and derive variables ----
raw <- read_excel(data_file, sheet = 1) |>
  transmute(
    case_id = as.character(Saksnummer),
    person_id = as.character(Id),
    case_type = str_squish(as.character(Sakstype)),
    main_category_original = str_squish(as.character(Hovedkategori)),
    sex_original = str_squish(as.character(Kjønn)),
    birth_year = suppressWarnings(as.numeric(Fødselsår)),
    district_original = str_squish(as.character(Tilhørighet)),
    organization = str_squish(as.character(`Klient organisasjon`)),
    date_new = as.Date(`Status ny`),
    date_closed = as.Date(`Status avsluttet`)
  ) |>
  mutate(
    district = str_remove(district_original, regex("^PPT\\s+", ignore_case = TRUE)),
    district_ascii = ascii_label(district),
    tett_pa = factor(district %in% c("Heimdal", "Midtbyen"), levels = c(FALSE, TRUE), labels = c("Other", "Tett pa")),
    sex = factor(recode(sex_original, "Mann" = "Boy", "Kvinne" = "Girl", .default = sex_original), levels = c("Boy", "Girl")),
    age_at_index_candidate = year(date_new) - birth_year,
    service_tier = classify_service_tier(organization),
    service_tier_main = replace_na(service_tier, "Unknown"),
    presentation_group = classify_presentation(main_category_original),
    presentation_ascii = factor(
      ascii_label(presentation_group),
      levels = ascii_label(c(
        "Not clarified", "Attention/neurodevelopment", "Language/speech/communication",
        "Learning/academic", "Social/emotional/interaction", "Complex/medical/other", "Missing"
      ))
    ),
    district_ascii = factor(district_ascii, levels = ascii_label(c("Lerkendal", "Heimdal", "Midtbyen", "Østbyen")))
  )


# ---- Risk set as a function of analysis start (used for alternative entry windows) ----
build_risk <- function(analysis_start) {
  person_history <- raw |>
    arrange(person_id, date_new, case_id) |>
    group_by(person_id) |>
    summarise(
      first_observed_date = min_date_or_na(date_new),
      first_date_has_other_case = any(
        date_new == min_date_or_na(date_new) & case_type != "Tidlig innsats personsak",
        na.rm = TRUE
      ),
      first_sv_date = min_date_or_na(date_new[case_type == "Sakkyndig vurdering"]),
      .groups = "drop"
    )

  baseline_all <- raw |>
    filter(case_type == "Tidlig innsats personsak") |>
    arrange(person_id, date_new, case_id) |>
    group_by(person_id) |>
    slice_head(n = 1) |>
    ungroup() |>
    left_join(person_history, by = "person_id") |>
    mutate(
      first_ti_in_period = date_new >= analysis_start & date_new <= administrative_end,
      prior_sv = !is.na(first_sv_date) & first_sv_date < date_new,
      same_day_sv = !is.na(first_sv_date) & first_sv_date == date_new,
      first_case_is_ti = first_observed_date == date_new & !first_date_has_other_case,
      age_at_index = age_at_index_candidate,
      valid_age = !is.na(age_at_index) & age_at_index >= 0 & age_at_index <= 16,
      cohort_half = entry_semester(date_new),
      organization_cluster_singleton = if_else(
        is.na(organization) | organization == "",
        paste0("missing-person-", person_id),
        organization
      ),
      organization_cluster_missing_shared = if_else(
        is.na(organization) | organization == "",
        "missing-organization",
        organization
      )
    )

  baseline <- baseline_all |>
    filter(first_ti_in_period, !prior_sv, !same_day_sv, valid_age) |>
    rename(t0 = date_new, baseline_case_id = case_id)

  event_dates <- raw |>
    inner_join(baseline |> select(person_id, t0), by = "person_id") |>
    filter(case_type == "Sakkyndig vurdering", date_new > t0, date_new <= administrative_end) |>
    group_by(person_id) |>
    summarise(event_date = min(date_new), .groups = "drop")

  baseline |>
    left_join(event_dates, by = "person_id") |>
    mutate(
      event_any = as.integer(!is.na(event_date)),
      end_date = coalesce(event_date, administrative_end),
      followup_days_raw = as.numeric(end_date - t0),
      event = as.integer(event_any == 1 & event_date <= t0 + 365),
      followup_days = pmin(followup_days_raw, 365),
      potential_followup_days = as.numeric(administrative_end - t0),
      eligible_12m = t0 <= administrative_end - 365,
      cohort_half = factor(cohort_half),
      organization_cluster_singleton = factor(organization_cluster_singleton),
      organization_cluster_missing_shared = factor(organization_cluster_missing_shared),
      district_ascii = factor(district_ascii, levels = ascii_label(c("Lerkendal", "Heimdal", "Midtbyen", "Østbyen"))),
      presentation_ascii = factor(
        presentation_ascii,
        levels = ascii_label(c(
          "Not clarified", "Attention/neurodevelopment", "Language/speech/communication",
          "Learning/academic", "Social/emotional/interaction", "Complex/medical/other", "Missing"
        ))
      )
    )
}


# ---- Primary risk set: entry from 1 January 2023 ----
risk <- build_risk(as.Date("2023-01-01"))


# ---- Follow-up balance between proximity-model and comparison districts ----
eligibility_balance <- map_dfr(
  c("cohort_half", "tett_pa", "district_ascii", "presentation_group", "sex", "service_tier_main"),
  function(variable) {
    risk |>
      group_by(level = .data[[variable]]) |>
      summarise(
        variable = variable,
        n = n(),
        eligible_12m_n = sum(eligible_12m),
        eligible_12m_percent = 100 * mean(eligible_12m),
        events_12m = sum(event),
        event_12m_percent_of_group = 100 * mean(event),
        .groups = "drop"
      ) |>
      select(variable, level, everything())
  }
)
write_csv(eligibility_balance, file.path(table_dir, "followup_eligibility_balance.csv"))


# ---- Organisation arena by district ----
organization_arena_by_district <- risk |>
  mutate(
    organization_arena = classify_organization_arena(organization),
    district = factor(district, levels = c("Heimdal", "Lerkendal", "Midtbyen", "Østbyen")),
    organization_arena = factor(organization_arena, levels = c("Kindergarten", "School", "Not registered / other"))
  ) |>
  count(district, organization_arena, name = "children", .drop = FALSE) |>
  group_by(district) |>
  mutate(percent_within_district = 100 * children / sum(children)) |>
  ungroup()
write_csv(organization_arena_by_district, file.path(table_dir, "organization_arena_by_district.csv"))


# ---- Censoring: potential follow-up among non-events ----
no_sv <- risk |> filter(event_any == 0)
censoring_boundary <- no_sv |>
  mutate(
    potential_followup_bucket = cut(
      potential_followup_days,
      breaks = c(-Inf, 180, 365, 548, 730, Inf),
      labels = c("<6 months", "6-<12 months", "12-<18 months", "18-<24 months", ">=24 months"),
      right = FALSE
    )
  ) |>
  count(potential_followup_bucket, name = "n") |>
  mutate(
    percent_of_no_sv = 100 * n / nrow(no_sv),
    percent_of_sample = 100 * n / nrow(risk)
  )
write_csv(censoring_boundary, file.path(table_dir, "censoring_by_potential_followup.csv"))


# ---- Competing first events ----
later_cases <- raw |>
  inner_join(risk |> select(person_id, t0), by = "person_id") |>
  filter(date_new > t0, date_new <= administrative_end) |>
  arrange(person_id, date_new, case_id)

first_later <- later_cases |>
  group_by(person_id) |>
  slice_head(n = 1) |>
  ungroup() |>
  transmute(
    person_id,
    first_later_case_type_raw = case_type,
    first_later_case_type = case_type_group(case_type),
    first_later_case_date = date_new,
    first_later_status = case_when(
      case_type == "Sakkyndig vurdering" ~ "expert_assessment",
      TRUE ~ "competing_other_ppt_case"
    )
  )

risk_first <- risk |>
  left_join(first_later, by = "person_id") |>
  mutate(
    first_later_status = replace_na(first_later_status, "censored"),
    first_later_time_days = as.numeric(coalesce(first_later_case_date, administrative_end) - t0)
  )

eligible_first <- risk_first |> filter(eligible_12m)
first_event_sensitivity <- tibble(
  measure = c(
    "Any expert assessment within 12 months",
    "Expert assessment is first later PPT case within 12 months",
    "Other PPT case is first later case within 12 months",
    "Other PPT case before later expert assessment within 12 months"
  ),
  n = c(
    sum(!is.na(eligible_first$event_date) & eligible_first$event_date <= eligible_first$t0 + 365),
    sum(eligible_first$first_later_case_type_raw == "Sakkyndig vurdering" & eligible_first$first_later_time_days <= 365, na.rm = TRUE),
    sum(!is.na(eligible_first$first_later_case_type_raw) & eligible_first$first_later_case_type_raw != "Sakkyndig vurdering" & eligible_first$first_later_time_days <= 365, na.rm = TRUE),
    sum(!is.na(eligible_first$event_date) & eligible_first$event_date <= eligible_first$t0 + 365 &
          !is.na(eligible_first$first_later_case_type_raw) & eligible_first$first_later_case_type_raw != "Sakkyndig vurdering" &
          eligible_first$first_later_time_days <= 365, na.rm = TRUE)
  ),
  denominator = nrow(eligible_first)
) |>
  mutate(percent = 100 * n / denominator)
write_csv(first_event_sensitivity, file.path(table_dir, "first_event_competing_sensitivity_12m.csv"))


# ---- Kaplan-Meier vs Aalen-Johansen at 12 months ----
km_12m <- summary(survfit(Surv(followup_days, event) ~ 1, data = risk), times = 365, extend = FALSE)
aj_12m <- aj_cif(risk_first, "first_later_time_days", "first_later_status", "expert_assessment", 365)
km_vs_aj <- tibble(
  estimate = c(
    "Kaplan-Meier: later expert assessment, censoring only at extract date",
    "Aalen-Johansen sensitivity: expert assessment before any other later PPT case",
    "Absolute difference, AJ minus KM"
  ),
  value = c(1 - km_12m$surv, aj_12m, aj_12m - (1 - km_12m$surv)),
  percent = 100 * value
)
write_csv(km_vs_aj, file.path(table_dir, "km_vs_aj_12m_sensitivity.csv"))


# ---- Cox models: separate district indicators and alternative specifications ----
fit_terms <- function(data, label, formula, cluster_var = "organization_cluster_singleton") {
  fit <- coxph(formula, data = data, x = TRUE, model = TRUE)
  tidy(fit, exponentiate = TRUE, conf.int = TRUE) |>
    filter(!str_detect(term, "^ns\\(age_at_index")) |>
    mutate(model = label, n = nrow(data), events = sum(data$event), .before = 1)
}

main_formula <- Surv(followup_days, event) ~ ns(age_at_index, df = 3) + sex + tett_pa +
  presentation_ascii + strata(cohort_half) + cluster(organization_cluster_singleton)

shared_missing_formula <- Surv(followup_days, event) ~ ns(age_at_index, df = 3) + sex + tett_pa +
  presentation_ascii + strata(cohort_half) + cluster(organization_cluster_missing_shared)

district_formula <- Surv(followup_days, event) ~ ns(age_at_index, df = 3) + sex + district_ascii +
  presentation_ascii + strata(cohort_half) + cluster(organization_cluster_singleton)

# The entry-window models used to run with linear age, which made the window and the age
# specification vary together. Corrected while answering R2-10: they now use
# main_formula, so only the window changes. The linear-age formula that stood here is
# gone with it; linear age is tested on its own in 10_article_analysis.R.

additional_cox <- bind_rows(
  fit_terms(risk, "Main specification rerun", main_formula),
  fit_terms(risk, "Missing organisation as one shared cluster", shared_missing_formula),
  fit_terms(risk, "Separate district indicators", district_formula),
  fit_terms(build_risk(as.Date("2022-07-01")), "Entry-window sensitivity from 2022-07-01", main_formula),
  fit_terms(build_risk(as.Date("2023-07-01")), "Entry-window sensitivity from 2023-07-01", main_formula)
)
write_csv(additional_cox, file.path(table_dir, "additional_cox_robustness.csv"))


# ---- Alternative entry windows ----
entry_window_sample_counts <- map_dfr(
  as.Date(c("2022-07-01", "2023-01-01", "2023-07-01")),
  function(start_date) {
    d <- build_risk(start_date)
    tibble(
      analysis_start = start_date,
      n = nrow(d),
      events_12m = sum(d$event),
      eligible_12m = sum(d$eligible_12m),
      observed_12m_events_among_eligible = sum(d$eligible_12m & d$event == 1)
    )
  }
)
write_csv(entry_window_sample_counts, file.path(table_dir, "entry_window_sample_counts.csv"))


# ---- Summary matrix ----
appendix_robustness_matrix <- tribble(
  ~conclusion_tested, ~robustness_check, ~output_file, ~main_result, ~appendix_priority,
  "Absolute 12-month transition level", "Observed 12-month pathways among children with complete follow-up", "tables/observed_pathways_12m.csv", "198/905 = 21.9% had expert assessment within 12 months", "Core appendix",
  "Absolute 12-month transition level under unequal follow-up", "Kaplan-Meier estimates at 6, 12, 18 and 24 months", "tables/km_transition_times.csv", "12-month cumulative transition estimate = 21.7%", "Core appendix",
  "Absolute risk not inflated by intervening other PPT registrations", "Aalen-Johansen first-event sensitivity", "tables/km_vs_aj_12m_sensitivity.csv", "Aalen-Johansen 20.7% versus Kaplan-Meier 21.7%", "Core appendix",
  "Administrative censoring concentrated in late-entry cohorts", "Potential follow-up among children without registered expert assessment", "tables/censoring_by_potential_followup.csv", "501/1182 non-events had less than 12 months potential follow-up", "Core appendix",
  "Presenting concern is the strongest patterned association", "Strict first-recorded PPT-contact risk set", "article_analysis.R: cox_sensitivity_models.csv", "Learning/academic HR 3.13; social/emotional HR 2.12; attention/neurodevelopment HR 0.58", "Core appendix",
  "District-context null not driven by a single district", "Leave-one-district-out", "article_analysis.R: leave_one_district_out.csv", "District-context HR range 0.84 to 1.25", "Core appendix",
  "District-context null not hiding district-specific deviations", "Separate district indicators", "tables/additional_cox_robustness.csv", "District-specific point estimates are close to the reference district", "Secondary appendix",
  "District-context interpretation similar across entry-window definitions", "Alternative analysis starts: 2022-07-01 and 2023-07-01", "tables/additional_cox_robustness.csv", "Proximity-model HR 1.09 and 1.02", "Secondary appendix",
  "Proportional-hazards assumption is not clearly violated", "Schoenfeld residual tests", "article_analysis.R: cox_ph_tests.csv", "Global p = 0.145; age spline p = 0.058", "Core appendix"
)
write_csv(appendix_robustness_matrix, file.path(table_dir, "appendix_robustness_matrix.csv"))


# ---- Session info ----
session <- capture.output(sessionInfo())
write_lines(session, file.path(diagnostic_dir, "session_info.txt"))

message("Appendix robustness analysis complete: ", normalizePath(output_dir, winslash = "/", mustWork = TRUE))
