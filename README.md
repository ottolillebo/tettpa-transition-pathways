# Tett pa transition pathways reproducibility package

This repository contains the reproducibility materials for the manuscript on transitions from early-intervention PPT cases to later expert-assessment cases in Trondheim.

The repository is designed for transparent review of the analysis workflow. It does not contain the underlying individual-level administrative case data.

## Contents

- `scripts/article_analysis.R`: primary analysis script. Requires approved local access to the restricted source extract.
- `scripts/appendix_robustness_analysis.R`: robustness analyses reported in Table 5 and the Discussion (separate district indicators, alternative entry windows, follow-up eligibility balance, competing first events). Also requires the restricted extract.
- `scripts/shared_functions.R`: data-preparation helpers used by both analysis scripts. Kept in one file so a classification cannot be corrected in one script and missed in the other.
- `scripts/render_manuscript_figures.R`: R-only publication figure rendering from aggregate CSV outputs. The exported figures are title-free because titles are supplied in manuscript captions.
- `outputs/tables/`: aggregate CSV tables used by the manuscript.
- `outputs/diagnostics/`: non-identifying model diagnostics and session information.
- `outputs/figures/`: title-free publication figures rendered from the aggregate outputs.
- `docs/DATA_ACCESS.md`: how eligible researchers can request access to the restricted source data.
- `docs/VARIABLES.md`: expected fields in the restricted source extract and derived analytic variables.
- `docs/OUTPUTS.md`: notes on included and excluded outputs.

## Reproduce the analysis

The full analysis requires an approved local copy of the restricted Trondheim PPT administrative case extract.

```powershell
$env:TETTPA_DATA_FILE="C:\secure\StatisticsCaseDetailsList.xlsm"
$env:TETTPA_OUTPUT_DIR="outputs"
$env:TETTPA_BOOT_REPS="1000"
Rscript scripts/article_analysis.R
Rscript scripts/appendix_robustness_analysis.R
```

Run both from the repository root, in that order. They are independent — the robustness
script reads the restricted extract directly rather than the primary script's output —
but the primary script writes the tables the figure layer expects.

The figure layer can be rerun from the aggregate CSV files included here without access to the restricted source data:

```powershell
$env:TETTPA_OUTPUT_DIR="outputs"
Rscript scripts/render_manuscript_figures.R
```

## Software

The analysis and figure rendering were run in R with `dplyr`, `tidyr`, `purrr`, `readxl`, `readr`, `stringr`, `lubridate`, `forcats`, `ggplot2`, `survival`, `splines`, and `broom`.

## Data availability

The source data are child-level administrative records from Trondheim PPT and cannot be shared publicly. Access requires formal approval, a valid legal basis, data processing agreement, and secure processing environment. See `docs/DATA_ACCESS.md`.

## Disclosure controls

The package excludes raw data, local file paths, data hashes, and organization-level mapping files that could increase disclosure risk.


## Correction history

**2026-11-10 — strict risk set.** The strict risk set is the sensitivity sample in which
the early-intervention case is unambiguously the child's first observed PPT case. An
earlier version of `article_analysis.R` decided, for children with several case types
recorded on the same earliest date, which case came first by sorting on the case number
(`arrange(person_id, date_new, case_id)` followed by `first(case_type)`). The records
carry dates, not timestamps: the order of cases within a day is not observable, and the
case number is an assignment identifier that carries no chronology. Four children were
therefore kept in the strict risk set on a basis that does not exist.

The rule now excludes any child with another case type on that date, and claims nothing
about within-day order. Effect: 13 to 17 children excluded, strict risk set 1,358 to
1,354, district estimate unchanged at HR 0.97 (95% CI 0.70-1.35). The primary analysis
does not use the strict risk set and is unaffected.

The error and its consequences are reported to the journal in the response to reviewers
accompanying the revised manuscript.

**2026-11-25 — cell suppression before public release.** The support diagnostics added on
2026-11-10 contained cells covering a single child, and `observation_windows.csv` carried
two exact registration dates. Both were staged but never published. Cells below five
children are now blanked at write time, and the observed span is reported to the month.
See `docs/OUTPUTS.md`. Estimates are unaffected; only the diagnostic files change.
