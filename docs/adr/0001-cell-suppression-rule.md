# Cell suppression rule

The outputs describe children registered with one municipal service, so some tables have cells covering very few of them. Suppressing every count below five would have emptied the diagnostics while leaving other small numbers untouched for no gain, so the rule is narrower:

> Suppress a cell when it links a small group of children to a combination of personal characteristics. Publish counts of administrative records over time, and numbers that already appear in the article.

What that gives:

- `diagnostics/model_support_cells.csv` (tier × concern × cohort) and `diagnostics/age_service_support.csv` (age × tier) cross several quasi-identifiers and had cells holding one child with their outcome beside it. Cells below five children are blanked and flagged `suppressed = TRUE`. The rows stay, because the files exist to show where model support is thin and a deleted row would read as "no children here".
- `tables/registration_coverage_by_year.csv` and `tables/quarterly_new_cases.csv` count cases by type and period with no personal characteristics attached. Published as they are.
- `diagnostics/observation_windows.csv` gives months. The exact first and last registrations are two children's dates.
- Small counts in `sample_flow.csv`, `crude_12m_transition_probabilities.csv` and `presenting_concern_mapping.csv` are in the article already, so hiding them here achieves nothing.

## Limits

Zero-event cells are published. `n = 17, events = 0` tells you that none of those seventeen transitioned, which is attribute disclosure. Using it requires already knowing that a given child was registered with that concern in that half-year, the attribute disclosed is a non-event, and suppressing these cells would remove 24 of 88 — the ones that record where the model has no information. No cell has `events == n`.

No secondary suppression. Where one cell in a group is blanked, the article's totals can sometimes recover it by subtraction. Closing that would have meant blanking a second cell in each affected group. The recoverable values are counts of children in coarse administrative categories.

Suppression runs at write time via `suppress_small_cells()` in `scripts/shared_functions.R`, so re-running reproduces the published form. A replicator with data access sees the full values.
