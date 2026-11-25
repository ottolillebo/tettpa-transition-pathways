# README for "From early intervention to formal expert assessment: administrative transition pathways in a Norwegian educational-psychological service"

Reproducibility package for:

> Lillebø, O. S. (2026). From early intervention to formal expert assessment: administrative transition pathways in a Norwegian educational-psychological service. *European Journal of Special Needs Education*. https://doi.org/10.1080/08856257.2026.2769866

This README follows the [Social Science Data Editors template](https://github.com/social-science-data-editors/template_README).

## Overview

The code in this package reconstructs the analysis from a single restricted source: an administrative case-management extract from Trondheim Educational Psychological Service (EPS). Two R scripts produce every number in the article — `scripts/article_analysis.R` for the primary analysis and all figures, `scripts/appendix_robustness_analysis.R` for the sensitivity analyses summarised in Table 5. A third script, `scripts/render_manuscript_figures.R`, re-renders most figures from the aggregate CSV files included here, so the figure layer can be inspected **without** access to the restricted data.

The primary script takes about ten minutes to run. See [Computational requirements](#computational-requirements).

## Data availability and provenance

The analysis uses one data source: individual-level case-management records for children aged 0–16 registered with Trondheim EPS, covering registrations from 1 January 2023 to 31 May 2025. The records were extracted from the service's case-management system and supplied to the research team in de-identified form under the municipality's data-protection procedures. A data protection impact assessment was completed for the project.

The fields expected in the extract, and the analytic variables derived from them, are documented in `docs/VARIABLES.md`.

### Statement about rights

The author has legitimate access to and permission to use the data in the manuscript. The author does **not** have permission to redistribute the person-level data, which is why the extract is not included here. All material that *is* included in this package — code, aggregate outputs, documentation — is the author's to distribute.

### Summary of availability

**Some data cannot be made publicly available.** The person-level case-management records are restricted; the analysis code, aggregate result tables, model diagnostics and figures are provided in full.

Eligible researchers can request access to the source records from the data controller, the City of Trondheim, Department of Childhood and Education. Routing, requirements and contact details are in `docs/DATA_ACCESS.md`. Access is conditional on a documented research purpose, approval from the data controller, a valid legal basis, a data processing agreement and a secure processing environment.

The restricted extract is retained by the data controller under the municipality's own archival rules, and by the research team for the period permitted by the project's data-protection approval. It is not preserved as part of this package.

### Licence

Code in `scripts/` is released under the MIT Licence (see `LICENSE`). The aggregate outputs in `outputs/` and the documentation in `docs/` are released under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Attribute reuse to the article above.

## Computational requirements

### Software

Run under R 4.4.2 on Windows 11. Exact package versions from the deposited run are recorded in `outputs/diagnostics/session_info.txt`; the versions used were:

`dplyr` 1.2.0, `tidyr` 1.3.2, `purrr` 1.0.2, `readxl` 1.4.3, `readr` 2.1.6, `stringr` 1.5.1, `lubridate` 1.9.4, `forcats` 1.0.0, `ggplot2` 4.0.0, `survival` 3.7-0, `broom` 1.0.7, plus `scales` and `tibble` (pulled in by `ggplot2` and `dplyr`) and the base package `splines`.

Two optional packages, `mice` and `rstpm2`, are listed in `R-packages.txt` but are not required. See [Optional, unreported analyses](#optional-unreported-analyses).

### Controlled randomness

The cluster bootstrap and the multiple-imputation block both use seed `20260609`, set in `scripts/article_analysis.R`. Results are reproducible given the same seed, package versions and source extract.

### Runtime and resources

The deposited primary run took approximately **10 minutes** with 1,000 bootstrap replications (read from the timestamps of that run, not formally benchmarked). The bootstrap dominates; set `TETTPA_BOOT_REPS` lower for a quick structural check. No special memory or storage requirements — the package is a few megabytes and the source extract is a single spreadsheet.

## Description of programs

- `scripts/article_analysis.R` — primary analysis: sample construction, descriptive tables, Kaplan-Meier estimates, the primary Cox model, the cluster bootstrap, model diagnostics and all figures. Requires the restricted extract.
- `scripts/appendix_robustness_analysis.R` — sensitivity analyses behind Table 5: separate district indicators, alternative entry windows, follow-up eligibility balance, competing first events. Reads the restricted extract directly rather than the primary script's output, so the two scripts are independent.
- `scripts/shared_functions.R` — data-preparation helpers used by both analysis scripts, including the service-tier and presenting-concern classifications and the disclosure-control helper. Kept in one file so a classification cannot be corrected in one script and missed in the other.
- `scripts/render_manuscript_figures.R` — re-renders the figures from the aggregate CSV outputs, without the restricted data.

### Optional, unreported analyses

`scripts/article_analysis.R` contains two blocks guarded by `requireNamespace()`: a multiple-imputation sensitivity analysis for service tier (`mice`) and a Royston-Parmar flexible parametric model (`rstpm2`). Both were exploratory, **neither is reported in the article**, and neither package was installed for the deposited run — so their outputs are not present in `outputs/`. The blocks skip silently when the packages are absent. They are retained to document that the checks were made.

## Instructions to replicators

With approved local access to the restricted extract, from the repository root:

```powershell
$env:TETTPA_DATA_FILE="<path to the approved local extract>"
$env:TETTPA_OUTPUT_DIR="outputs"
$env:TETTPA_BOOT_REPS="1000"
Rscript scripts/article_analysis.R
Rscript scripts/appendix_robustness_analysis.R
```

Without the restricted data, the figure layer alone can be regenerated from the deposited aggregates:

```powershell
$env:TETTPA_OUTPUT_DIR="outputs"
Rscript scripts/render_manuscript_figures.R
```

This reproduces every figure except `figure1_quarterly_new_cases.png` and `supplement_unadjusted_service_tier_curves.png`, which are drawn from intermediate data that is not deposited.

## List of tables and figures

**The figure file names are offset from the article's figure numbers.** The files keep the numbering of an earlier draft; the article was renumbered during revision. Use this table rather than the file names.

| In the article | Script | Output |
| --- | --- | --- |
| Table 1. Complete presenting-concern mapping | `article_analysis.R` | `outputs/tables/presenting_concern_mapping.csv` |
| Table 2. Organisation arena by district | `article_analysis.R` | `outputs/tables/organization_arena_by_district.csv` |
| Table 3. Analytical sample and data coverage | `article_analysis.R` | `outputs/tables/sample_flow.csv`, `table1_categorical.csv`, `table1_continuous.csv`, `sample_summary.csv` |
| Table 4. Primary 12-month Cox model | `article_analysis.R` | `outputs/tables/table2_cox_main.csv`, `main_model_summary.csv` |
| Table 5. Summary of sensitivity analyses | `appendix_robustness_analysis.R`, `article_analysis.R` | `outputs/appendix_robustness/tables/appendix_robustness_matrix.csv`, `outputs/tables/cox_sensitivity_models.csv` |
| Figure 1. Quarterly registration context | `article_analysis.R` | `outputs/figures/figure1_quarterly_new_cases.png` (data: `tables/quarterly_new_cases.csv`) |
| Figure 2A. Directly observed pathways | `render_manuscript_figures.R` | `outputs/figures/figure2_observed_pathways_12m.png` (data: `tables/observed_pathways_12m.csv`) |
| Figure 2B. Kaplan-Meier cumulative probability | `render_manuscript_figures.R` | `outputs/figures/figure3_cumulative_transition.png` (data: `tables/km_plot_data.csv`) |
| Figure 3. Unadjusted 12-month probabilities | `render_manuscript_figures.R` | `outputs/figures/figure4_crude_12m_probabilities.png` (data: `tables/crude_12m_transition_probabilities.csv`) |
| Figure 4. Standardised 12-month probabilities | `render_manuscript_figures.R` | `outputs/figures/figure5_adjusted_12m_probabilities.png` (data: `tables/standardized_12m_probabilities.csv`) |

Five further figure files (`figure2a_observed_pathways.png`, `figure2b_cumulative_transition.png`, `figure3_unadjusted_probabilities.png`, `figure3_standardized_probabilities.png`, `figure4_adjusted_probabilities.png`) are duplicate exports under the earlier numbering, written by the scripts and retained so that the deposited outputs match the code. `supplement_unadjusted_service_tier_curves.png` belonged to a supplementary appendix that was withdrawn before publication. Suggested captions for every figure are in `outputs/figure_notes_for_word.txt`.

Figures are exported without titles; titles are supplied in the manuscript captions.

## Disclosure controls

The package excludes raw data, child-level derived files, local file paths, data hashes, and organisation-level mapping files that would name individual schools and kindergartens.

Aggregate cells covering fewer than five children are suppressed in the model-support diagnostics, and the observed registration span is reported to the month rather than the day. The rule and its limits are recorded in `docs/adr/0001-cell-suppression-rule.md`; what it means for each file is in `docs/OUTPUTS.md`.

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
Estimates are unaffected; only the diagnostic files change.

**2026-11-25 — orphaned figure files removed.** Nine figure files dated 2026-06-22
(`figure1_registration_context.*`, `supplement_data_transparency.*`,
`supplement_service_tier_curves.*`) were produced by a seaborn pipeline that has since
been replaced by the R renderer, and belonged to a supplementary appendix withdrawn on
2026-07-03. No script in this package produced them. They have been deleted.
