suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readxl)
  library(readr)
  library(stringr)
  library(lubridate)
  library(forcats)
  library(ggplot2)
  library(survival)
  library(splines)
  library(broom)
})

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
output_dir <- Sys.getenv("TETTPA_OUTPUT_DIR", "output/article_analysis")
figure_dir <- file.path(output_dir, "figures")
table_dir <- file.path(output_dir, "tables")
diagnostic_dir <- file.path(output_dir, "diagnostics")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostic_dir, recursive = TRUE, showWarnings = FALSE)

analysis_start <- as.Date("2023-01-01")
administrative_end <- as.Date("2025-05-31")
education_act_start <- as.Date("2024-08-01")
bootstrap_reps <- as.integer(Sys.getenv("TETTPA_BOOT_REPS", "1000"))
bootstrap_seed <- 20260609

figure_notes <- tibble::tribble(
  ~figure_file, ~suggested_caption, ~note,
  "figure1_quarterly_new_cases.png",
  "Quarterly registration context for early-intervention and formal expert-assessment cases.",
  "Counts describe administrative registrations over time. Dashed vertical line marks the start of the analytical sample period, 1 January 2023.",
  "figure2_observed_pathways_12m.png",
  "Directly observed pathways among children with 12 months of potential follow-up.",
  "Expert assessment is prioritised in the classification: children with any such registration within 12 months are shown in the first category.",
  "figure3_cumulative_transition.png",
  "Kaplan-Meier estimated cumulative probability of a registered transition, with 95% confidence intervals and numbers at risk.",
  "Numbers below the x-axis show how many children remained under observation without a registered transition.",
  "supplement_unadjusted_service_tier_curves.png",
  "Unadjusted cumulative transition curves by derived service tier.",
  "Small multiples use a common scale and are descriptive; service tier is manually derived and partly structured by age.",
  "figure4_crude_12m_probabilities.png",
  "Unadjusted 12-month transition probabilities by presenting concern and derived service tier.",
  "Dashed line: overall 12-month estimate for all 1,468 children. Group labels show baseline size. The 39 children with missing presenting concern are omitted from the concern panel because their follow-up did not support a separate 12-month estimate.",
  "figure5_adjusted_12m_probabilities.png",
  "Marginally standardised 12-month transition probabilities from the primary Cox model.",
  "Lines are cluster-bootstrap 95% intervals. Dashed line: overall unadjusted 12-month estimate. Estimates are associational, not causal effects.",
  "figure3_standardized_probabilities.png",
  "Marginally standardised 12-month transition probabilities from the primary Cox model.",
  "Duplicate export of figure5_adjusted_12m_probabilities.png retained for earlier manuscript numbering."
)

write_csv(figure_notes, file.path(table_dir, "figure_notes_for_word.csv"))
write_lines(
  purrr::pmap_chr(
    figure_notes,
    function(figure_file, suggested_caption, note) {
      paste0(
        figure_file, "\n",
        suggested_caption, "\n",
        "Note. ", note, "\n"
      )
    }
  ),
  file.path(output_dir, "figure_notes_for_word.txt")
)

min_date_or_na <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) as.Date(NA) else min(x)
}

classify_service_tier <- function(organization) {
  lower_secondary <- c(
    "Blussuvoll", "Charlottenlund ungdomsskole", "Hoeggen",
    "Huseby ungdomsskole", "Klæbu", "Markaplassen", "Rosenborg",
    "Selsbakk", "Sunnland", "Sverresborg", "Ugla", "Åsheim ungdomsskole"
  )
  combined <- c("Flatåsen", "Lade", "Rosten", "Sjetne", "Spongdal", "Tonstad")
  org <- str_squish(as.character(organization))
  case_when(
    is.na(org) | org == "" ~ NA_character_,
    str_detect(org, regex("barne- og familietjenest|skolehelsetjenest|trondheimshjelpa|ikke\\s*i\\s*bruk|ikkeibruk", ignore_case = TRUE)) ~ NA_character_,
    str_detect(org, regex("barnehage|\\bbhg\\b|familiebarnehage|læringsverkstedet", ignore_case = TRUE)) ~ "Kindergarten",
    str_detect(org, regex("ungdomsskole", ignore_case = TRUE)) ~ "Lower secondary",
    str_detect(org, regex(paste(lower_secondary, collapse = "|"), ignore_case = TRUE)) ~ "Lower secondary",
    str_detect(org, regex(paste(combined, collapse = "|"), ignore_case = TRUE)) ~ "Combined school",
    TRUE ~ "Primary school"
  )
}

classify_presentation <- function(x) {
  case_when(
    is.na(x) | x == "" ~ "Missing",
    x %in% c("Ikke avklart", "Z- Ikke tildelt") ~ "Not clarified",
    x %in% c("Konsentrasjon og oppmerksomhet", "Nevroutviklingsforstyrrelser/syndrom") ~
      "Attention/neurodevelopment",
    x %in% c("Språk-/kommunikasjonsvansker", "Talevansker", "Hørsel/Koda", "KODA") ~
      "Language/speech/communication",
    x %in% c("Lærevansker/Fagvansker", "Lese- /skrivevansker", "Matematikkvansker",
             "Forsinket utvikling", "V-Generelle lærevansker") ~
      "Learning/academic",
    x %in% c("Sosiale/emosjonelle vansker", "Samspill-/Sosial spekter vansker",
             "Samspillvansker", "Skolefravær", "Traume", "V-Psykisk lidelse") ~
      "Social/emotional/interaction",
    TRUE ~ "Complex/medical/other"
  )
}

semester <- function(x) paste0(year(x), "H", if_else(month(x) <= 6, "1", "2"))

article_theme <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title.position = "plot",
      plot.caption.position = "plot",
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color = "grey88", linewidth = 0.35),
      panel.grid.major.x = element_line(color = "grey92", linewidth = 0.3),
      strip.text = element_text(face = "bold", hjust = 0),
      legend.position = "none"
    )
}

case_type_group <- function(x) {
  case_when(
    x == "Sakkyndig vurdering" ~ "Expert assessment",
    x == "Tidlig innsats personsak" ~ "New early-intervention case",
    str_detect(x, regex("oppfølging", ignore_case = TRUE)) ~ "Follow-up case",
    str_detect(x, regex("utredning", ignore_case = TRUE)) ~ "Other assessment case",
    TRUE ~ "Other PPT case"
  )
}

classify_organization_arena <- function(organization) {
  org <- str_squish(as.character(organization))
  lower <- str_to_lower(org)
  case_when(
    is.na(org) | org == "" ~ "Not registered / other",
    grepl("barnehage|\\bbhg\\b|familiebarnehage|læringsverkstedet", lower) ~ "Kindergarten",
    grepl("skole|ungdomsskole|barneskole|oppvekstsenter|\\bschool\\b", lower) ~ "School",
    TRUE ~ "Not registered / other"
  )
}

raw <- read_excel(data_file, sheet = 1) |>
  transmute(
    case_id = as.character(Saksnummer),
    person_id = as.character(Id),
    case_type = str_squish(as.character(Sakstype)),
    # Correct a known data-entry typo in the raw administrative label
    # ("Erververvet hjerneskade" -> "Ervervet hjerneskade", acquired brain injury).
    # Grouping is unaffected (Complex/medical/other catch-all); this only cleans the
    # displayed original label in the presenting-concern mapping.
    main_category_original = str_replace(str_squish(as.character(Hovedkategori)),
                                         "^Erververvet hjerneskade$", "Ervervet hjerneskade"),
    sex_original = str_squish(as.character(Kjønn)),
    birth_year = suppressWarnings(as.numeric(Fødselsår)),
    recorded_age = suppressWarnings(as.numeric(Alder)),
    district_original = str_squish(as.character(Tilhørighet)),
    organization = str_squish(as.character(`Klient organisasjon`)),
    client_status = str_squish(as.character(`Klient status`)),
    case_status = str_squish(as.character(Status)),
    date_new = as.Date(`Status ny`),
    date_work = as.Date(`Status under arbeid`),
    date_closed = as.Date(`Status avsluttet`)
  ) |>
  mutate(
    district = str_remove(district_original, regex("^PPT\\s+", ignore_case = TRUE)),
    tett_pa = district %in% c("Heimdal", "Midtbyen"),
    sex = recode(sex_original, "Mann" = "Boy", "Kvinne" = "Girl", .default = sex_original),
    age_at_index_candidate = year(date_new) - birth_year,
    service_tier = classify_service_tier(organization),
    presentation_group = classify_presentation(main_category_original)
  )

stopifnot(nrow(raw) == n_distinct(raw$case_id))
stopifnot(all(is.na(raw$date_work) | raw$date_work >= raw$date_new))
stopifnot(all(is.na(raw$date_closed) | raw$date_closed >= raw$date_new))

provenance <- tibble(
  data_file = data_file,
  md5 = unname(tools::md5sum(data_file)),
  rows = nrow(raw),
  unique_persons = n_distinct(raw$person_id),
  unique_cases = n_distinct(raw$case_id),
  min_date_new = min(raw$date_new),
  max_date_new = max(raw$date_new),
  analysis_start = analysis_start,
  administrative_end = administrative_end,
  generated_at = Sys.time(),
  r_version = R.version.string
)
write_csv(provenance, file.path(diagnostic_dir, "data_provenance.csv"))

registration_coverage <- raw |>
  mutate(
    registration_year = year(date_new),
    display_period = case_when(
      date_new < as.Date("2020-05-01") ~ "Before context-figure period",
      date_new < analysis_start ~ "Context period before analytical sample",
      TRUE ~ "Analytical-sample calendar period"
    )
  ) |>
  count(display_period, registration_year, case_type, name = "cases") |>
  arrange(registration_year, case_type)
write_csv(registration_coverage, file.path(table_dir, "registration_coverage_by_year.csv"))

person_history <- raw |>
  arrange(person_id, date_new, case_id) |>
  group_by(person_id) |>
  summarise(
    first_observed_date = min_date_or_na(date_new),
    first_observed_type = first(case_type),
    first_ti_date = min_date_or_na(date_new[case_type == "Tidlig innsats personsak"]),
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
    first_case_is_ti = first_observed_type == "Tidlig innsats personsak",
    age_at_index = age_at_index_candidate,
    valid_age = !is.na(age_at_index) & age_at_index >= 0 & age_at_index <= 16
  )

flow <- tibble(
  step = c(
    "Persons with any early-intervention case",
    "First observed early-intervention case in analysis period",
    "Excluded: prior observed expert assessment",
    "Excluded: same-day expert assessment",
    "Excluded: age outside 0-16 or unavailable",
    "Main analytical sample",
    "Main sample: earlier observed PPT case on an earlier date",
    "Main sample: another case type precedes index TI on the same first observed date",
    "Strict sample: early intervention is first observed PPT case"
  ),
  n = c(
    nrow(baseline_all),
    sum(baseline_all$first_ti_in_period),
    sum(baseline_all$first_ti_in_period & baseline_all$prior_sv),
    sum(baseline_all$first_ti_in_period & !baseline_all$prior_sv & baseline_all$same_day_sv),
    sum(baseline_all$first_ti_in_period & !baseline_all$prior_sv & !baseline_all$same_day_sv & !baseline_all$valid_age),
    sum(baseline_all$first_ti_in_period & !baseline_all$prior_sv & !baseline_all$same_day_sv & baseline_all$valid_age),
    sum(baseline_all$first_ti_in_period & !baseline_all$prior_sv & !baseline_all$same_day_sv & baseline_all$valid_age & baseline_all$first_observed_date < baseline_all$date_new),
    sum(baseline_all$first_ti_in_period & !baseline_all$prior_sv & !baseline_all$same_day_sv & baseline_all$valid_age & baseline_all$first_observed_date == baseline_all$date_new & !baseline_all$first_case_is_ti),
    sum(baseline_all$first_ti_in_period & !baseline_all$prior_sv & !baseline_all$same_day_sv & baseline_all$valid_age & baseline_all$first_case_is_ti)
  )
)
write_csv(flow, file.path(table_dir, "sample_flow.csv"))

baseline <- baseline_all |>
  filter(first_ti_in_period, !prior_sv, !same_day_sv, valid_age) |>
  transmute(
    person_id,
    baseline_case_id = case_id,
    t0 = date_new,
    age_at_index,
    recorded_age,
    sex,
    district,
    tett_pa,
    organization,
    service_tier,
    presentation_group,
    main_category_original,
    cohort_half = semester(t0),
    cohort_quarter = paste0(year(t0), "Q", quarter(t0)),
    first_case_is_ti,
    prior_other_case = first_observed_date < t0
  )

event_dates <- raw |>
  inner_join(baseline |> select(person_id, t0), by = "person_id") |>
  filter(case_type == "Sakkyndig vurdering", date_new > t0, date_new <= administrative_end) |>
  group_by(person_id) |>
  summarise(event_date = min(date_new), .groups = "drop")

risk <- baseline |>
  left_join(event_dates, by = "person_id") |>
  mutate(
    event = as.integer(!is.na(event_date)),
    end_date = coalesce(event_date, administrative_end),
    followup_days = as.numeric(end_date - t0),
    followup_months = followup_days / 30.4375,
    service_tier_main = replace_na(service_tier, "Unknown"),
    organization_cluster = if_else(
      is.na(organization) | organization == "",
      paste0("missing-person-", person_id),
      organization
    )
  ) |>
  mutate(
    sex = factor(sex, levels = c("Boy", "Girl")),
    service_tier_main = factor(service_tier_main,
      levels = c("Kindergarten", "Primary school", "Lower secondary", "Combined school", "Unknown")),
    presentation_group = factor(presentation_group,
      levels = c("Not clarified", "Attention/neurodevelopment", "Language/speech/communication",
                 "Learning/academic", "Social/emotional/interaction", "Complex/medical/other", "Missing")),
    tett_pa = factor(tett_pa, levels = c(FALSE, TRUE), labels = c("Other PPT districts", "Tett på districts")),
    cohort_half = factor(cohort_half),
    cohort_quarter = factor(cohort_quarter),
    organization_cluster = factor(organization_cluster)
  )

write_csv(tibble(
  n = nrow(risk), events = sum(risk$event), raw_event_share = mean(risk$event),
  median_followup_months = median(risk$followup_months),
  n_12m_eligible = sum(risk$t0 <= administrative_end - 365),
  n_missing_organization = sum(is.na(risk$organization) | risk$organization == ""),
  n_unknown_service_tier = sum(is.na(risk$service_tier)),
  n_organizations = n_distinct(risk$organization[!is.na(risk$organization) & risk$organization != ""])
), file.path(table_dir, "sample_summary.csv"))

write_csv(tibble(
  earliest_observed_registration = min(raw$date_new, na.rm = TRUE),
  latest_observed_registration = max(raw$date_new, na.rm = TRUE),
  analysis_start = analysis_start,
  administrative_end = administrative_end,
  education_act_start = education_act_start
), file.path(diagnostic_dir, "observation_windows.csv"))

baseline_completeness <- tibble(
  variable = c(
    "Person identifier", "Index date", "Birth year", "Age at index date",
    "Administratively recorded sex", "PPT district", "Baseline organisation",
    "Service tier", "Original presenting concern", "Grouped presenting concern"
  ),
  missing_n = c(
    sum(is.na(risk$person_id) | risk$person_id == ""),
    sum(is.na(risk$t0)),
    sum(is.na(baseline_all$birth_year[match(risk$person_id, baseline_all$person_id)])),
    sum(is.na(risk$age_at_index)),
    sum(is.na(risk$sex) | as.character(risk$sex) == ""),
    sum(is.na(risk$district) | risk$district == ""),
    sum(is.na(risk$organization) | risk$organization == ""),
    sum(is.na(risk$service_tier)),
    sum(is.na(risk$main_category_original) | risk$main_category_original == ""),
    sum(as.character(risk$presentation_group) == "Missing")
  )
) |>
  mutate(total_n = nrow(risk), missing_percent = 100 * missing_n / total_n)
write_csv(baseline_completeness, file.path(table_dir, "baseline_data_completeness.csv"))

category_mapping <- risk |>
  mutate(
    original_category = replace_na(main_category_original, "[Missing]"),
    grouped_category = as.character(presentation_group)
  ) |>
  count(original_category, grouped_category, name = "n") |>
  arrange(grouped_category, desc(n), original_category)
write_csv(category_mapping, file.path(table_dir, "presenting_concern_mapping.csv"))

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

followup_by_cohort <- risk |>
  group_by(cohort_half) |>
  summarise(
    n = n(),
    observed_transitions = sum(event),
    median_followup_months = median(followup_months),
    q1_followup_months = quantile(followup_months, 0.25),
    q3_followup_months = quantile(followup_months, 0.75),
    eligible_6m = sum(t0 <= administrative_end - 180),
    eligible_12m = sum(t0 <= administrative_end - 365),
    eligible_18m = sum(t0 <= administrative_end - 548),
    eligible_24m = sum(t0 <= administrative_end - 730),
    .groups = "drop"
  )
write_csv(followup_by_cohort, file.path(table_dir, "followup_by_entry_cohort.csv"))

eligible_12m <- risk |>
  filter(t0 <= administrative_end - 365) |>
  select(person_id, t0, event_date)

later_cases_12m <- raw |>
  inner_join(eligible_12m |> select(person_id, t0), by = "person_id") |>
  filter(date_new > t0, date_new <= t0 + 365) |>
  arrange(person_id, date_new, case_id)

first_later_case_12m <- later_cases_12m |>
  group_by(person_id) |>
  slice_head(n = 1) |>
  ungroup() |>
  transmute(
    person_id,
    first_later_case_type = case_type_group(case_type),
    days_to_first_later_case = as.numeric(date_new - t0)
  )

pathways_12m <- eligible_12m |>
  left_join(first_later_case_12m, by = "person_id") |>
  mutate(
    expert_assessment_12m = !is.na(event_date) & event_date <= t0 + 365,
    observed_pathway = case_when(
      expert_assessment_12m ~ "Expert assessment registered",
      !is.na(first_later_case_type) ~ "Other later PPT case, no expert assessment",
      TRUE ~ "No later PPT case registered"
    ),
    observed_pathway = factor(
      observed_pathway,
      levels = c(
        "Expert assessment registered",
        "Other later PPT case, no expert assessment",
        "No later PPT case registered"
      )
    )
  )

pathway_summary_12m <- pathways_12m |>
  count(observed_pathway, name = "n") |>
  mutate(percent = 100 * n / sum(n), denominator = sum(n))
write_csv(pathway_summary_12m, file.path(table_dir, "observed_pathways_12m.csv"))

first_next_case_summary_12m <- pathways_12m |>
  mutate(first_later_case_type = replace_na(first_later_case_type, "No later PPT case")) |>
  count(first_later_case_type, name = "n") |>
  mutate(percent = 100 * n / sum(n), denominator = sum(n)) |>
  arrange(desc(n))
write_csv(first_next_case_summary_12m, file.path(table_dir, "first_later_case_type_12m.csv"))

monthly_cases <- raw |>
  filter(case_type %in% c("Tidlig innsats personsak", "Sakkyndig vurdering"),
         date_new >= as.Date("2020-05-01"), date_new <= administrative_end) |>
  mutate(quarter = floor_date(date_new, "quarter"),
         case_type_en = recode(case_type,
           "Tidlig innsats personsak" = "Early-intervention case",
           "Sakkyndig vurdering" = "Expert assessment")) |>
  count(quarter, case_type_en, name = "new_cases")
write_csv(monthly_cases, file.path(table_dir, "quarterly_new_cases.csv"))

p1 <- monthly_cases |>
  mutate(
    case_type_en = factor(case_type_en, levels = c("Expert assessment", "Early-intervention case")),
    series_color = if_else(case_type_en == "Early-intervention case", "Early intervention", "Expert assessment")
  ) |>
  ggplot(aes(quarter, new_cases, color = series_color)) +
  geom_line(linewidth = 0.85) +
  geom_point(size = 1.5) +
  geom_vline(xintercept = analysis_start, linetype = 2, color = "grey45", linewidth = 0.45) +
  facet_wrap(~case_type_en, ncol = 1) +
  scale_color_manual(values = c("Early intervention" = "#0072B2", "Expert assessment" = "grey35")) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = expansion(mult = c(0.01, 0.02))) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
  labs(
    x = NULL,
    y = "Unique new cases per quarter"
  ) +
  article_theme()
ggsave(file.path(figure_dir, "figure1_quarterly_new_cases.png"), p1, width = 8, height = 4.8, dpi = 300)

p_pathways <- pathway_summary_12m |>
  mutate(
    label = sprintf("%.1f%%  (n = %s)", percent, n),
    label_weight = if_else(observed_pathway == "Expert assessment registered", "bold", "plain")
  ) |>
  ggplot(aes(percent, fct_rev(observed_pathway))) +
  geom_col(width = 0.62, fill = "grey80") +
  geom_col(
    data = ~ filter(.x, observed_pathway == "Expert assessment registered"),
    width = 0.62,
    fill = "#0072B2"
  ) +
  geom_text(aes(label = label, fontface = label_weight), hjust = -0.08, size = 3.6) +
  scale_x_continuous(
    labels = scales::label_percent(scale = 1, accuracy = 1),
    limits = c(0, 90),
    breaks = seq(0, 80, 20),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    x = "Share of children (n = 905)",
    y = NULL
  ) +
  article_theme() +
  theme(panel.grid.major.y = element_blank())
ggsave(file.path(figure_dir, "figure2_observed_pathways_12m.png"), p_pathways, width = 8, height = 4.2, dpi = 300)

table1_categorical <- bind_rows(
  risk |> count(variable = "Administratively recorded sex", level = as.character(sex), name = "n"),
  risk |> count(variable = "Service tier", level = as.character(service_tier_main), name = "n"),
  risk |> count(variable = "Presenting-concern group", level = as.character(presentation_group), name = "n"),
  risk |> count(variable = "District context", level = as.character(tett_pa), name = "n"),
  risk |> count(variable = "PPT district", level = district, name = "n"),
  risk |> count(variable = "Half-year entry cohort", level = as.character(cohort_half), name = "n"),
  risk |> count(variable = "Prior observed non-SV PPT case", level = if_else(prior_other_case, "Yes", "No"), name = "n")
) |>
  group_by(variable) |>
  mutate(percent = 100 * n / sum(n)) |>
  ungroup()

table1_continuous <- tibble(
  variable = c("Age at index date", "Follow-up, months", "Observed transitions to expert assessment"),
  statistic = c(
    sprintf("%.1f (%.1f-%.1f)", median(risk$age_at_index), quantile(risk$age_at_index, .25), quantile(risk$age_at_index, .75)),
    sprintf("%.1f (%.1f-%.1f)", median(risk$followup_months), quantile(risk$followup_months, .25), quantile(risk$followup_months, .75)),
    sprintf("%d (%.1f%%)", sum(risk$event), 100 * mean(risk$event))
  )
)
write_csv(table1_categorical, file.path(table_dir, "table1_categorical.csv"))
write_csv(table1_continuous, file.path(table_dir, "table1_continuous.csv"))

km_overall <- survfit(Surv(followup_days, event) ~ 1, data = risk)
km_times <- c(180, 365, 548, 730)
km_s <- summary(km_overall, times = km_times, extend = FALSE)
km_table <- tibble(
  days = km_s$time, months = round(km_s$time / 30.4375, 1), n_risk = km_s$n.risk,
  n_event = km_s$n.event, cumulative_transition = 1 - km_s$surv,
  lower = 1 - km_s$upper, upper = 1 - km_s$lower
)
write_csv(km_table, file.path(table_dir, "km_transition_times.csv"))

tidy_survfit <- function(fit, panel) {
  s <- summary(fit)
  strata <- if (is.null(s$strata)) "Overall" else str_remove(as.character(s$strata), "^[^=]+=")
  tibble(time = s$time, estimate = 1 - s$surv, lower = 1 - s$upper, upper = 1 - s$lower,
         group = strata, panel = panel)
}

km_plot_data <- tidy_survfit(km_overall, "Overall") |>
  bind_rows(tibble(time = 0, estimate = 0, lower = 0, upper = 0, group = "Overall", panel = "Overall")) |>
  arrange(time)
write_csv(km_plot_data, file.path(table_dir, "km_plot_data.csv"))

risk_axis <- tibble(
  month = c(0, 6, 12, 18, 24),
  n_risk = c(nrow(risk), km_table$n_risk)
)

km_label_data <- km_table |>
  mutate(
    label = scales::percent(cumulative_transition, accuracy = 0.1),
    label_x = months,
    label_y = cumulative_transition + case_when(
      months <= 6 ~ 0.022,
      months <= 12 ~ 0.024,
      months <= 18 ~ 0.022,
      TRUE ~ 0.021
    ),
    hjust = if_else(months >= 24, 1, 0.5)
  )

p2 <- ggplot(km_plot_data, aes(time / 30.4375, estimate)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = "#0072B2", alpha = 0.14) +
  geom_step(color = "#0072B2", linewidth = 1) +
  geom_segment(
    data = km_table,
    aes(x = months, xend = months, y = 0, yend = cumulative_transition),
    inherit.aes = FALSE,
    linewidth = 0.35,
    linetype = "dotted",
    color = "grey75"
  ) +
  geom_point(
    data = km_table,
    aes(months, cumulative_transition),
    inherit.aes = FALSE,
    color = "#0072B2",
    size = 2
  ) +
  geom_label(
    data = km_label_data,
    aes(label_x, label_y, label = label, hjust = hjust),
    inherit.aes = FALSE,
    linewidth = 0,
    label.padding = grid::unit(0.08, "lines"),
    size = 3.3,
    fontface = "bold",
    fill = "white",
    alpha = 0.92,
    color = "#005A8D"
  ) +
  coord_cartesian(xlim = c(0, 24.7), ylim = c(0, 0.32), clip = "off") +
  scale_x_continuous(
    breaks = risk_axis$month,
    labels = risk_axis$month
  ) +
  scale_y_continuous(labels = scales::label_percent(accuracy = 1), breaks = seq(0, 0.30, 0.05)) +
  labs(
    x = "Months since first early-intervention case",
    y = "Cumulative transition probability"
  ) +
  article_theme() +
  annotate(
    "text",
    x = risk_axis$month,
    y = -0.055,
    label = scales::comma(risk_axis$n_risk),
    size = 3,
    color = "grey40"
  ) +
  annotate("text", x = -1.05, y = -0.055, label = "At risk", hjust = 1, size = 3, color = "grey40") +
  theme(
    axis.text.x = element_text(size = 8.5),
    plot.margin = margin(5.5, 8, 36, 28)
  )
ggsave(file.path(figure_dir, "figure3_cumulative_transition.png"), p2, width = 8.5, height = 4.8, dpi = 300)

km_service_data <- tidy_survfit(
  survfit(Surv(followup_days, event) ~ service_tier_main, data = risk),
  "Service tier"
)
write_csv(km_service_data, file.path(table_dir, "km_service_tier_plot_data.csv"))

p2_service <- ggplot(km_service_data, aes(time / 30.4375, estimate)) +
  geom_step(color = "#0072B2", linewidth = 0.8) +
  facet_wrap(~group, ncol = 3) +
  coord_cartesian(xlim = c(0, 24), ylim = c(0, 0.38)) +
  scale_x_continuous(breaks = c(0, 6, 12, 18, 24)) +
  scale_y_continuous(labels = scales::label_percent(accuracy = 1)) +
  labs(
    x = "Months since first early-intervention case",
    y = "Cumulative transition probability"
  ) +
  article_theme()
ggsave(file.path(figure_dir, "supplement_unadjusted_service_tier_curves.png"), p2_service, width = 9, height = 6, dpi = 300)

crude_km_at <- function(data, variable, time_days = 365) {
  values <- unique(as.character(data[[variable]]))
  map_dfr(values, function(value) {
    d <- data |> filter(as.character(.data[[variable]]) == value)
    if (max(d$followup_days) < time_days) {
      return(tibble(
        variable = variable, level = value, n = nrow(d), events = sum(d$event),
        n_risk = NA_integer_, estimate = NA_real_, lower = NA_real_, upper = NA_real_
      ))
    }
    s <- summary(survfit(Surv(followup_days, event) ~ 1, data = d), times = time_days, extend = FALSE)
    tibble(
      variable = variable,
      level = value,
      n = nrow(d),
      events = sum(d$event),
      n_risk = s$n.risk,
      estimate = 1 - s$surv,
      lower = 1 - s$upper,
      upper = 1 - s$lower
    )
  })
}

crude_12m <- bind_rows(
  crude_km_at(risk, "service_tier_main"),
  crude_km_at(risk, "presentation_group"),
  crude_km_at(risk, "tett_pa"),
  crude_km_at(risk, "sex")
)
write_csv(crude_12m, file.path(table_dir, "crude_12m_transition_probabilities.csv"))

crude_figure_data <- crude_12m |>
  filter(variable %in% c("service_tier_main", "presentation_group"), !is.na(estimate)) |>
  mutate(
    panel = recode(
      variable,
      service_tier_main = "Derived service tier",
      presentation_group = "Presenting concern"
    ),
    panel = factor(panel, levels = c("Presenting concern", "Derived service tier"))
  )

interval_panel <- function(data, x_label, x_limit) {
  data |>
    mutate(
      level_label = paste0(level, "  (n = ", scales::comma(n), ")"),
      estimate_label = scales::percent(estimate, accuracy = 0.1),
      label_x = pmin(pmax(estimate + 0.028, upper + 0.015), x_limit - 0.006),
      label_hjust = if_else(label_x >= x_limit - 0.006, 1, 0)
    ) |>
    ggplot(aes(estimate, reorder(level_label, estimate))) +
    geom_vline(xintercept = km_table$cumulative_transition[km_table$days == 365], color = "grey60", linetype = 2) +
    geom_errorbar(aes(xmin = lower, xmax = upper), width = 0.12, orientation = "y", color = "grey35") +
    geom_point(size = 2.2, color = "#0072B2") +
    geom_text(
      aes(x = label_x, label = estimate_label, hjust = label_hjust),
      size = 3.1,
      fontface = "bold",
      color = "#005A8D"
    ) +
    facet_wrap(vars(panel), ncol = 1, scales = "free_y", strip.position = "top") +
    scale_x_continuous(labels = scales::label_percent(accuracy = 1), limits = c(0, x_limit)) +
    labs(x = x_label, y = NULL) +
    article_theme() +
    theme(
      panel.grid.major.y = element_blank(),
      strip.text = element_text(face = "bold", hjust = 0, size = 11),
      strip.background = element_blank(),
      axis.text.y = element_text(size = 9.5),
      plot.margin = margin(6, 16, 6, 6)
    )
}

p_crude <- interval_panel(
  crude_figure_data,
  x_label = "Unadjusted 12-month transition probability",
  x_limit = 0.68
)
ggsave(file.path(figure_dir, "figure4_crude_12m_probabilities.png"), p_crude, width = 8.5, height = 7.5, dpi = 300)
ggsave(file.path(figure_dir, "figure3_unadjusted_probabilities.png"), p_crude, width = 8.5, height = 7.5, dpi = 300)

risk_12m <- risk |>
  mutate(
    followup_days = pmin(followup_days, 365),
    event = as.integer(event == 1 & event_date <= t0 + 365)
  )

main_formula <- Surv(followup_days, event) ~ ns(age_at_index, df = 3) + sex + tett_pa +
  presentation_group + strata(cohort_half) + cluster(organization_cluster)

service_tier_formula <- Surv(followup_days, event) ~ sex + service_tier_main + tett_pa +
  presentation_group + strata(cohort_half) + cluster(organization_cluster)

cox_main <- coxph(main_formula, data = risk_12m, x = TRUE, model = TRUE)
cox_terms <- tidy(cox_main, exponentiate = TRUE, conf.int = TRUE) |>
  filter(!str_detect(term, "^ns\\(age_at_index"))
write_csv(cox_terms, file.path(table_dir, "table2_cox_main.csv"))
write_csv(tibble(
  analytical_n = nrow(risk_12m),
  transitions_within_12m = sum(risk_12m$event),
  clusters = n_distinct(risk_12m$organization_cluster),
  cohort_strata = n_distinct(risk_12m$cohort_half)
), file.path(table_dir, "main_model_summary.csv"))

cox_service_tier <- coxph(service_tier_formula, data = risk_12m, x = TRUE, model = TRUE)
write_csv(
  tidy(cox_service_tier, exponentiate = TRUE, conf.int = TRUE),
  file.path(table_dir, "secondary_service_tier_cox.csv")
)

ph <- cox.zph(cox_main)
ph_table <- as.data.frame(ph$table) |> tibble::rownames_to_column("term")
write_csv(ph_table, file.path(diagnostic_dir, "cox_ph_tests.csv"))

ph_service_tier <- cox.zph(cox_service_tier)
write_csv(
  as.data.frame(ph_service_tier$table) |> tibble::rownames_to_column("term"),
  file.path(diagnostic_dir, "secondary_service_tier_ph_tests.csv")
)

support <- risk_12m |>
  group_by(service_tier_main, presentation_group, cohort_half) |>
  summarise(n = n(), events = sum(event), .groups = "drop")
write_csv(support, file.path(diagnostic_dir, "model_support_cells.csv"))
write_csv(tibble(
  support_cells = nrow(support),
  cells_below_10_children = sum(support$n < 10),
  cells_without_events = sum(support$events == 0),
  children_in_cells_below_10 = sum(support$n[support$n < 10]),
  events_in_cells_below_10 = sum(support$events[support$n < 10])
), file.path(diagnostic_dir, "model_support_summary.csv"))
write_csv(
  risk |> group_by(age_at_index, service_tier_main) |>
    summarise(n = n(), events = sum(event), .groups = "drop"),
  file.path(diagnostic_dir, "age_service_support.csv")
)

baseline_hazard_at <- function(fit, time_days) {
  bh <- basehaz(fit, centered = FALSE) |>
    mutate(strata = str_remove(as.character(strata), "^cohort_half="))
  bh |>
    filter(time <= time_days) |>
    group_by(strata) |>
    slice_max(time, n = 1, with_ties = FALSE) |>
    ungroup() |>
    select(strata, hazard)
}

standardized_probability <- function(fit, data, variable, levels, time_days = 365) {
  eligible <- data |> filter(t0 <= administrative_end - time_days)
  h0 <- baseline_hazard_at(fit, time_days)
  map_dfr(levels, function(level_value) {
    nd <- eligible
    nd[[variable]] <- factor(level_value, levels = levels(data[[variable]]))
    lp <- as.numeric(predict(fit, newdata = nd, type = "lp", reference = "zero"))
    strata_label <- as.character(nd$cohort_half)
    h <- h0$hazard[match(strata_label, h0$strata)]
    tibble(level = level_value, estimate = mean(1 - exp(-h * exp(lp)), na.rm = TRUE), n_standardized = nrow(nd))
  }) |>
    mutate(variable = variable, time_days = time_days)
}

pred_point <- bind_rows(
  standardized_probability(cox_main, risk_12m, "presentation_group", levels(risk_12m$presentation_group)),
  standardized_probability(cox_main, risk_12m, "tett_pa", levels(risk_12m$tett_pa))
)

cluster_bootstrap <- function(data, reps, seed) {
  set.seed(seed)
  cluster_ids <- unique(as.character(data$organization_cluster))
  cluster_data <- split(data, as.character(data$organization_cluster))
  result <- vector("list", reps)
  log <- tibble(rep = seq_len(reps), success = FALSE, message = NA_character_)

  for (b in seq_len(reps)) {
    sampled <- sample(cluster_ids, length(cluster_ids), replace = TRUE)
    boot_data <- map2_dfr(sampled, seq_along(sampled), function(id, draw) {
      cluster_data[[id]] |>
        mutate(boot_cluster = factor(paste0("draw-", draw)))
    })
    boot_data <- boot_data |>
      mutate(
        sex = factor(sex, levels = levels(data$sex)),
        service_tier_main = factor(service_tier_main, levels = levels(data$service_tier_main)),
        presentation_group = factor(presentation_group, levels = levels(data$presentation_group)),
        tett_pa = factor(tett_pa, levels = levels(data$tett_pa)),
        cohort_half = factor(cohort_half, levels = levels(data$cohort_half))
      )
    fit <- try(coxph(
      Surv(followup_days, event) ~ ns(age_at_index, df = 3) + sex + tett_pa +
        presentation_group + strata(cohort_half) + cluster(boot_cluster),
      data = boot_data, x = TRUE
    ), silent = TRUE)
    if (inherits(fit, "try-error") || any(!is.finite(coef(fit)))) {
      log$message[b] <- if (inherits(fit, "try-error")) as.character(fit)[1] else "Non-finite coefficient"
      next
    }
    estimates <- try(bind_rows(
      standardized_probability(fit, boot_data, "presentation_group", levels(data$presentation_group)),
      standardized_probability(fit, boot_data, "tett_pa", levels(data$tett_pa))
    ), silent = TRUE)
    if (inherits(estimates, "try-error")) {
      log$message[b] <- "Prediction failed"
      next
    }
    result[[b]] <- estimates |> select(variable, level, estimate)
    log$success[b] <- TRUE
    if (b %% 50 == 0) message("Bootstrap ", b, "/", reps)
  }
  list(result = result, log = log)
}

boot <- cluster_bootstrap(risk_12m, bootstrap_reps, bootstrap_seed)
write_csv(boot$log, file.path(diagnostic_dir, "bootstrap_log.csv"))

boot_pred <- map_dfr(which(boot$log$success), function(i) boot$result[[i]] |> mutate(rep = i))

pred_ci <- boot_pred |>
  group_by(variable, level) |>
  summarise(lower = quantile(estimate, .025, na.rm = TRUE), upper = quantile(estimate, .975, na.rm = TRUE), .groups = "drop") |>
  right_join(pred_point, by = c("variable", "level"))
write_csv(pred_ci, file.path(table_dir, "standardized_12m_probabilities.csv"))

prediction_group_counts <- bind_rows(
  risk |> count(variable = "presentation_group", level = as.character(presentation_group), name = "group_n"),
  risk |> count(variable = "tett_pa", level = as.character(tett_pa), name = "group_n")
)

adjusted_figure_data <- pred_ci |>
  left_join(prediction_group_counts, by = c("variable", "level")) |>
  filter(level != "Missing") |>
  mutate(
    panel = recode(variable, presentation_group = "Presenting concern", tett_pa = "District context"),
    panel = factor(panel, levels = c("District context", "Presenting concern")),
    n = group_n
  )

p3a <- interval_panel(
  adjusted_figure_data,
  x_label = "Adjusted 12-month transition probability",
  x_limit = 0.68
)
ggsave(file.path(figure_dir, "figure5_adjusted_12m_probabilities.png"), p3a, width = 8.5, height = 7.5, dpi = 300)
ggsave(file.path(figure_dir, "figure3_standardized_probabilities.png"), p3a, width = 8.5, height = 7.5, dpi = 300)
ggsave(file.path(figure_dir, "figure4_adjusted_probabilities.png"), p3a, width = 8.5, height = 7.5, dpi = 300)

fit_sensitivity <- function(data, label, formula = main_formula) {
  fit <- try(coxph(formula, data = data, x = TRUE, model = TRUE), silent = TRUE)
  if (inherits(fit, "try-error")) return(tibble(model = label, n = nrow(data), events = sum(data$event), term = NA_character_, estimate = NA_real_, conf.low = NA_real_, conf.high = NA_real_))
  tidy(fit, exponentiate = TRUE, conf.int = TRUE) |>
    filter(!str_detect(term, "^ns\\(age_at_index")) |>
    mutate(model = label, n = nrow(data), events = sum(data$event), .before = 1)
}

strict_risk <- risk_12m |> filter(first_case_is_ti)
complete_service <- risk_12m |> filter(service_tier_main != "Unknown") |>
  mutate(service_tier_main = fct_drop(service_tier_main), organization_cluster = fct_drop(organization_cluster))
linear_formula <- Surv(followup_days, event) ~ age_at_index + sex + tett_pa +
  presentation_group + strata(cohort_half) + cluster(organization_cluster)
with_age_formula <- Surv(followup_days, event) ~ ns(age_at_index, df = 3) + sex + service_tier_main + tett_pa +
  presentation_group + strata(cohort_half) + cluster(organization_cluster)
quarter_formula <- Surv(followup_days, event) ~ ns(age_at_index, df = 3) + sex + tett_pa +
  presentation_group + strata(cohort_quarter) + cluster(organization_cluster)
risk_early <- risk_12m |>
  mutate(followup_days = pmin(followup_days, 180), event = as.integer(event == 1 & event_date <= t0 + 180))
risk_late <- risk_12m |>
  filter(followup_days > 180) |>
  mutate(tstart = 180)
late_formula <- Surv(tstart, followup_days, event) ~ ns(age_at_index, df = 3) + sex +
  tett_pa + presentation_group + strata(cohort_half) + cluster(organization_cluster)
complete_organization <- risk_12m |>
  filter(!is.na(organization), organization != "") |>
  mutate(organization_cluster = fct_drop(organization_cluster), cohort_half = fct_drop(cohort_half))
school_levels <- c("Primary school", "Lower secondary", "Combined school")
pre_reform_school <- risk_12m |>
  filter(service_tier_main %in% school_levels, t0 < education_act_start) |>
  mutate(
    days_to_reform = as.numeric(education_act_start - t0),
    followup_days = pmin(followup_days, days_to_reform),
    event = as.integer(event == 1 & !is.na(event_date) & event_date < education_act_start),
    organization_cluster = fct_drop(organization_cluster),
    cohort_half = fct_drop(cohort_half)
  )

sensitivity <- bind_rows(
  fit_sensitivity(strict_risk, "Strict risk set"),
  fit_sensitivity(risk_12m, "Linear age", linear_formula),
  fit_sensitivity(risk_12m, "Quarter-cohort strata", quarter_formula),
  fit_sensitivity(risk, "Full available follow-up"),
  fit_sensitivity(risk_early, "Transitions during 0-6 months"),
  fit_sensitivity(risk_late, "Transitions after 6 months", late_formula),
  fit_sensitivity(complete_organization, "Complete baseline organisation"),
  fit_sensitivity(pre_reform_school, "School pathways censored at 2024 Education Act"),
  fit_sensitivity(risk_12m, "Secondary service-tier model without age", service_tier_formula),
  fit_sensitivity(complete_service, "Secondary complete service-tier cases", service_tier_formula),
  fit_sensitivity(risk_12m, "Secondary model with age and service tier", with_age_formula)
)
write_csv(sensitivity, file.path(table_dir, "cox_sensitivity_models.csv"))

district_loo <- map_dfr(unique(risk$district), function(drop_district) {
  d <- risk_12m |> filter(district != drop_district) |> mutate(organization_cluster = fct_drop(organization_cluster))
  fit <- coxph(main_formula, data = d)
  tidy(fit, exponentiate = TRUE, conf.int = TRUE) |>
    filter(term == "tett_paTett på districts") |>
    mutate(excluded_district = drop_district, .before = 1)
})
write_csv(district_loo, file.path(diagnostic_dir, "leave_one_district_out.csv"))

if (requireNamespace("mice", quietly = TRUE)) {
  mi_data <- risk_12m |>
    transmute(
      followup_days, event, age_at_index, sex,
      service_tier = factor(service_tier, levels = c("Kindergarten", "Primary school", "Lower secondary", "Combined school")),
      tett_pa,
      presentation_group, cohort_half, organization_cluster
    )
  mi_data$nelson_aalen <- mice::nelsonaalen(mi_data, "followup_days", "event")
  method <- rep("", ncol(mi_data)); names(method) <- names(mi_data); method["service_tier"] <- "polyreg"
  pred <- mice::make.predictorMatrix(mi_data); pred[,] <- 0
  pred["service_tier", c("age_at_index", "sex", "tett_pa", "presentation_group", "cohort_half", "event", "nelson_aalen")] <- 1
  imp <- mice::mice(mi_data, m = 20, maxit = 10, method = method, predictorMatrix = pred,
                    printFlag = FALSE, seed = 20260609)
  mi_fits <- with(imp, coxph(
    Surv(followup_days, event) ~ sex + service_tier + tett_pa +
      presentation_group + strata(cohort_half) + cluster(organization_cluster)
  ))
  mi_pool <- mice::pool(mi_fits)
  mi_table <- summary(mi_pool, conf.int = TRUE, exponentiate = TRUE)
  write_csv(mi_table, file.path(table_dir, "cox_multiple_imputation_sensitivity.csv"))
}

if (requireNamespace("rstpm2", quietly = TRUE)) {
  suppressPackageStartupMessages(library(rstpm2))
  rp_data <- risk_12m |>
    mutate(cohort_half_covariate = cohort_half)
  rp_fits <- map_dfr(3:4, function(df_baseline) {
    fit <- try(rstpm2::stpm2(
      Surv(followup_days, event) ~ ns(age_at_index, df = 3) + sex +
        tett_pa + presentation_group + cohort_half_covariate,
      data = rp_data, df = df_baseline
    ), silent = TRUE)
    if (inherits(fit, "try-error")) return(tibble(
      df_baseline = df_baseline, AIC = NA_real_, converged = FALSE,
      message = str_squish(as.character(fit)[1])
    ))
    rp_coef <- tibble(
      term = names(coef(fit)), estimate = unname(coef(fit)),
      std.error = sqrt(diag(vcov(fit)))
    ) |>
      mutate(conf.low = estimate - 1.96 * std.error, conf.high = estimate + 1.96 * std.error)
    write_csv(rp_coef, file.path(table_dir, paste0("royston_parmar_df", df_baseline, ".csv")))
    tibble(df_baseline = df_baseline, AIC = AIC(fit), converged = TRUE, message = NA_character_)
  })
  write_csv(rp_fits, file.path(diagnostic_dir, "royston_parmar_comparison.csv"))
}

closure <- raw |>
  filter(case_type == "Tidlig innsats personsak") |>
  mutate(closed = !is.na(date_closed), duration_days = as.numeric(date_closed - date_new))

closure_return <- closure |>
  filter(closed) |>
  select(person_id, ti_case = case_id, date_closed) |>
  left_join(raw |> select(person_id, later_case = case_id, later_type = case_type, later_date = date_new),
            by = "person_id", relationship = "many-to-many") |>
  group_by(person_id, ti_case, date_closed) |>
  summarise(
    later_any = any(later_date > date_closed),
    later_ti = any(later_date > date_closed & later_type == "Tidlig innsats personsak"),
    later_sv = any(later_date > date_closed & later_type == "Sakkyndig vurdering"),
    .groups = "drop"
  )

write_csv(tibble(
  ti_cases = nrow(closure),
  closed_cases = sum(closure$closed),
  closed_share = mean(closure$closed),
  median_days_to_closure = median(closure$duration_days[closure$closed]),
  closed_with_later_any_case = sum(closure_return$later_any),
  closed_with_later_ti = sum(closure_return$later_ti),
  closed_with_later_sv = sum(closure_return$later_sv)
), file.path(table_dir, "ti_closure_diagnostics.csv"))

session <- capture.output(sessionInfo())
write_lines(session, file.path(diagnostic_dir, "session_info.txt"))

message("Analysis complete: ", normalizePath(output_dir, winslash = "/", mustWork = TRUE))
