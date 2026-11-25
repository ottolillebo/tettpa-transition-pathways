# =============================================================================
# shared_functions.R - shared data-preparation helpers
# =============================================================================
#
# Why this file exists:
#   These helpers used to be duplicated verbatim in both 10_article_analysis.R
#   and 11_appendix_robustness_analysis.R. That is a correctness risk, not just
#   untidiness: fix a classification in one script and forget the other, and the
#   primary model and the robustness checks diverge silently on exactly the
#   variables that carry the paper's main finding. It happened once already (the
#   raw-label typo fix for acquired brain injury had to be applied twice).
#
# Sourced by:
#   article_analysis.R, appendix_robustness_analysis.R
#
# Dependencies:
#   Loads no packages of its own. The calling script must already have dplyr
#   (case_when, if_else), stringr (str_detect, str_squish, str_to_lower) and
#   lubridate (year, month) attached.
#
# Note on scope: four of these encode Trondheim- and EPS-specific domain
# knowledge that no package can supply. They do not reimplement dplyr; they use
# dplyr to put a study-specific decision in one reviewable place.
#
# Changing anything here affects BOTH analyses. Re-run both and diff against the
# frozen output before treating the change as done (see _verify_refactor.py).
# =============================================================================


# Smallest non-missing date, or NA when every value is missing.
# Why: min(x, na.rm = TRUE) returns Inf with a warning on an all-NA vector. Here
# we want NA, because "no observed case of this type" is not a date. Used inside
# grouped summarise(), where repeating the guard inline would be noisy.
min_date_or_na <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) as.Date(NA) else min(x)
}

# Half-year entry cohort as a label, e.g. "2023H1".
# Why: used as strata in the primary Cox model to absorb the phase-in of the
# early-intervention registration category, calendar practice, and the differing
# follow-up structure between cohorts. Cohort is never interpreted as an effect.
#
# NOTE ON THE NAME: lubridate also exports semester(), which returns 1/2 (or
# 2023.1 with with_year = TRUE). This function is deliberately NOT called
# semester, because masking the lubridate one would be dangerous: if this
# definition were ever removed, lubridate's would silently take over and the
# strata would lose the year, merging 2023H1, 2024H1 and 2025H1 into one stratum.
# The model would run without error and return different numbers.
entry_semester <- function(x) paste0(year(x), "H", if_else(month(x) <= 6, "1", "2"))

# Derives service tier (five levels) from the kindergarten/school name.
# Why: the organisation field is free text with no level code. The lists of lower
# secondary and combined schools are manually curated for Trondheim.
# NOTE: this variable overlaps heavily with age and is therefore used only
# descriptively (Figure 3) and in a secondary model - never in the primary model.
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

# Groups the recorded Hovedkategori into the six analytical presenting-concern
# groups used in all models.
# Why: the raw labels are too fine-grained and partly overlapping to model. The
# grouping is substantively predefined, not data-driven.
# NOTE: "Missing" (no label recorded) is kept separate from the substantive
# category "Not clarified". See Table 1 in the manuscript.
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

# Collapses case types into the groups the article reports.
# Why: the register holds many case types, but the analysis only needs the
# distinction between expert assessment, early intervention and "other".
case_type_group <- function(x) {
  case_when(
    x == "Sakkyndig vurdering" ~ "Expert assessment",
    x == "Tidlig innsats personsak" ~ "New early-intervention case",
    str_detect(x, regex("oppfølging", ignore_case = TRUE)) ~ "Follow-up case",
    str_detect(x, regex("utredning", ignore_case = TRUE)) ~ "Other assessment case",
    TRUE ~ "Other PPT case"
  )
}

# Broad three-level arena from the organisation name: kindergarten / school /
# not registered.
# Why: used for the aggregated description by district (Table 2) without naming
# individual schools or kindergartens.
# NOTE: this is NOT the same variable as service_tier. See CONTEXT.md on the
# three organisation constructs (baseline organisation / organisation arena /
# service tier).
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

# Blanks out aggregate cells covering fewer than `threshold` children, for files
# that leave the secure environment.
# Why: the support diagnostics cross-tabulate age, service tier, presenting
# concern and entry cohort, and several cells hold a single child. A row reading
# n = 1, events = 1 discloses that child's outcome to anyone who knows they were
# registered. Five is the conventional floor in Norwegian statistical disclosure
# practice, and REPRODUCIBILITY.md forbids anything finer in this repository.
# Masked rows are kept, not dropped: these files exist to document WHERE model
# support is thin, and a missing row would read as "no children here" rather
# than "too few children to publish".
suppress_small_cells <- function(df, threshold = 5, count_cols = c("n", "events")) {
  small <- df$n < threshold
  df |>
    mutate(
      across(all_of(count_cols), ~ if_else(small, NA_integer_, as.integer(.x))),
      suppressed = small
    )
}
