# Tett pa transition pathways reproducibility package

This repository contains the reproducibility materials for the manuscript on transitions from early-intervention PPT cases to later expert-assessment cases in Trondheim.

The repository is designed for transparent review of the analysis workflow. It does not contain the underlying individual-level administrative case data.

## Contents

- `scripts/article_analysis.R`: primary analysis script. Requires approved local access to the restricted source extract.
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
```

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
