# Replication package for "From early intervention to formal expert assessment"

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24533464.svg)](https://doi.org/10.5281/zenodo.24533464)

Lillebø, O. S. (2026). From early intervention to formal expert assessment: administrative transition pathways in a Norwegian educational-psychological service. *European Journal of Special Needs Education*. https://doi.org/10.1080/08856257.2026.2769866

The code follows 1,468 children aged 0–16 from an early-intervention registration with Trondheim Educational Psychological Service to a later formal expert assessment, using Cox models and Kaplan-Meier estimates with a cluster bootstrap over organisations. Two scripts produce every number in the article. A third redraws the figures from the deposited aggregates, without the restricted data.

## Data availability

### Statement about rights

- [X] The author has legitimate access to and permission to use the data used in the manuscript.
- [ ] The author has permission to redistribute the person-level data. The records are not included here.

### Summary of availability

Some data cannot be made publicly available. The analysis code, aggregate tables, model diagnostics and figures are provided in full.

### Source

Individual-level case-management records for children registered with Trondheim Educational Psychological Service between 1 January 2023 and 31 May 2025, extracted from the service's case system and supplied to the research team de-identified. The expected fields are listed in [`docs/VARIABLES.md`](docs/VARIABLES.md). A data protection impact assessment was completed for the project.

Access requires approval from the data controller, the City of Trondheim, Department of Childhood and Education. Enquiries go to the municipality's standing resource group for research; the route, the documents they require and the fallback if their page moves are in [`docs/DATA_ACCESS.md`](docs/DATA_ACCESS.md).

### Licence

MIT for the code (`LICENSE`), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) for the outputs and documentation.

## Software

R 4.4.2 on Windows 11, with `dplyr`, `tidyr`, `purrr`, `readxl`, `readr`, `stringr`, `lubridate`, `forcats`, `ggplot2`, `survival`, `splines`, `broom`, `scales` and `tibble`. Exact versions are in `outputs/diagnostics/session_info.txt`.

`mice` and `rstpm2` are optional. `article_analysis.R` runs a multiple-imputation check and a Royston-Parmar model only if they are installed. Both were exploratory, neither is reported in the article, and neither ran for the deposited outputs.

## How to run

With an approved local copy of the extract, from the repository root:

```powershell
$env:TETTPA_DATA_FILE="<path to the approved extract>"
$env:TETTPA_OUTPUT_DIR="outputs"
$env:TETTPA_BOOT_REPS="1000"
Rscript scripts/article_analysis.R
Rscript scripts/appendix_robustness_analysis.R
```

The primary script takes about ten minutes at 1,000 bootstrap replications. Lower `TETTPA_BOOT_REPS` for a quick structural check. The seed is `20260609`, set in `article_analysis.R` and used for both the bootstrap and the imputation.

Without the extract, the figures redraw from the deposited aggregates:

```powershell
$env:TETTPA_OUTPUT_DIR="outputs"
Rscript scripts/render_manuscript_figures.R
```

That gives every figure except `figure1_quarterly_new_cases.png` and `supplement_unadjusted_service_tier_curves.png`, which need intermediate data that is not deposited.

## Scripts

| File | Does |
| --- | --- |
| `article_analysis.R` | Sample construction, descriptive tables, Kaplan-Meier, the primary Cox model, the cluster bootstrap, diagnostics, all figures |
| `appendix_robustness_analysis.R` | Table 5: separate district indicators, alternative entry windows, follow-up eligibility balance, competing first events. Reads the extract directly, so it does not depend on the primary script |
| `shared_functions.R` | Service-tier and presenting-concern classifications, shared by both analyses so a correction cannot land in one and miss the other |
| `render_manuscript_figures.R` | Figures from the aggregate CSVs |

## Where each result comes from

The figure file names keep an earlier draft's numbering and do not match the article's figure numbers.

| In the article | Script | Output |
| --- | --- | --- |
| Table 1. Presenting-concern mapping | `article_analysis.R` | `tables/presenting_concern_mapping.csv` |
| Table 2. Organisation arena by district | `article_analysis.R` | `tables/organization_arena_by_district.csv` |
| Table 3. Sample and data coverage | `article_analysis.R` | `tables/sample_flow.csv`, `table1_categorical.csv`, `table1_continuous.csv`, `sample_summary.csv` |
| Table 4. Primary Cox model | `article_analysis.R` | `tables/table2_cox_main.csv`, `main_model_summary.csv` |
| Table 5. Sensitivity analyses | `appendix_robustness_analysis.R` | `appendix_robustness/tables/appendix_robustness_matrix.csv`, `tables/cox_sensitivity_models.csv` |
| Figure 1. Quarterly registration context | `article_analysis.R` | `figures/figure1_quarterly_new_cases.png` |
| Figure 2A. Observed pathways | `render_manuscript_figures.R` | `figures/figure2_observed_pathways_12m.png` |
| Figure 2B. Kaplan-Meier | `render_manuscript_figures.R` | `figures/figure3_cumulative_transition.png` |
| Figure 3. Unadjusted probabilities | `render_manuscript_figures.R` | `figures/figure4_crude_12m_probabilities.png` |
| Figure 4. Standardised probabilities | `render_manuscript_figures.R` | `figures/figure5_adjusted_12m_probabilities.png` |

Five further figure files are duplicate exports under the old numbering. `supplement_unadjusted_service_tier_curves.png` belonged to an appendix withdrawn before publication. Captions are in `outputs/figure_notes_for_word.txt`.

## Suppressed cells

`diagnostics/model_support_cells.csv` and `diagnostics/age_service_support.csv` blank any cell covering fewer than five children and flag it `suppressed = TRUE`. `diagnostics/observation_windows.csv` gives months rather than exact dates. [`docs/adr/0001-cell-suppression-rule.md`](docs/adr/0001-cell-suppression-rule.md) states the rule and what it leaves exposed. Suppression happens at write time, so a replicator with data access sees the full values in their own run.

The package holds no raw data, no child-level files, no local paths, and no file naming individual schools or kindergartens.

## Changes

**2026-11-10.** The strict risk set, used only for sensitivity analysis, had been built by sorting same-day cases on the case number to decide which came first. Case numbers carry no chronology and the records have no timestamps, so four children were kept on a basis that does not exist. The rule now excludes any child with another case type on that date. Exclusions went from 13 to 17, the strict sample from 1,358 to 1,354, and the district estimate was unchanged at HR 0.97 (0.70–1.35). The primary analysis does not use this sample. Reported to the journal with the revised manuscript.

**2026-11-25.** Cell suppression applied before release, and nine figure files from a withdrawn appendix removed. Estimates unaffected.
