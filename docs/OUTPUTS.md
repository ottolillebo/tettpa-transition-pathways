# Outputs

Included outputs are aggregate tables, model summaries, non-identifying diagnostics, and title-free publication figures.

Excluded outputs:

- raw administrative records;
- child-level derived datasets;
- local data provenance with file paths or source file hashes;
- organization-to-service-tier mapping files;
- any file that directly identifies schools, kindergartens, children, staff, or case records.

The included tables are sufficient to inspect manuscript-level estimates and regenerate the public figures. They are not sufficient to re-fit the full models without approved access to the restricted source data.

## Cell suppression

`diagnostics/model_support_cells.csv` and `diagnostics/age_service_support.csv` cross-tabulate small subgroups, and some cells covered a single child. Cells with fewer than five children are therefore blanked and marked `suppressed = TRUE`; the rows are kept so that thin model support stays visible. Suppression is applied in `scripts/article_analysis.R` via `suppress_small_cells()` in `shared_functions.R`, so re-running the pipeline reproduces the published form. `diagnostics/model_support_summary.csv` counts how many cells are sparse and is computed before suppression.

`diagnostics/observation_windows.csv` reports the first and last observed registration to the month rather than the day, because the exact extremes are individual children's registration dates.

Small counts that remain in `tables/` (for example the rare presenting-concern categories in `presenting_concern_mapping.csv`) are those already published in the article and its appendix.

