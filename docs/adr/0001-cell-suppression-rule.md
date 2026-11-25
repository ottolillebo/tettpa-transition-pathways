# Cell suppression rule for the public package

The aggregate outputs deposited here describe a small population of children
registered with one municipal service, so some tables have cells covering very
few children. We needed a rule for which of those cells can be published, and
the obvious rule — "suppress every count below five" — turns out to be both too
strict and too loose in different places.

The rule we apply:

> Suppress a cell when it lets a reader link a small group of children to a
> **combination of personal characteristics**. Do not suppress counts of
> administrative records over time, and do not suppress numbers that already
> appear in the published article.

In practice:

- `diagnostics/model_support_cells.csv` (service tier × presenting concern ×
  entry cohort) and `diagnostics/age_service_support.csv` (age × service tier)
  cross several quasi-identifiers at once, and had cells holding a single child
  whose outcome was shown alongside. Cells below five children are blanked and
  flagged `suppressed = TRUE`. Rows are kept, not dropped, because these files
  exist to document *where model support is thin*, and a missing row would read
  as "no children here" rather than "too few children to publish".
- `tables/registration_coverage_by_year.csv` and `tables/quarterly_new_cases.csv`
  count administrative cases by type and calendar period, with no personal
  characteristics attached. They are published as they are. Knowing that one
  speech-therapy case was registered in 2012 identifies nobody unless you
  already know the sensitive fact, which is not in the file.
- `diagnostics/observation_windows.csv` reports the first and last observed
  registration to the month. The exact extremes are individual children's
  registration dates.
- Small counts in `tables/sample_flow.csv`,
  `tables/crude_12m_transition_probabilities.csv` and
  `tables/presenting_concern_mapping.csv` are published, because the same
  numbers appear in the article. Suppressing them here would hide nothing.

## Two limits worth stating plainly

**Zero-event cells are published.** A cell reading `n = 17, events = 0` reveals
that none of those seventeen children transitioned within twelve months, which
is attribute disclosure in the strict sense. We publish it anyway: the attribute
disclosed is a *non-event*, exploiting it requires already knowing that a given
child was registered with that concern in that half-year, and suppressing these
cells would remove 24 of 88 — precisely the cells that document where the model
has no information. No cell has `events == n`, so no group has every outcome
revealed.

**We did not apply secondary suppression.** Where a single cell in a group is
blanked, a reader with the article's group totals can sometimes recover it by
differencing. Closing that off would have required suppressing a second cell in
each affected group, which would have emptied the diagnostics. We accepted the
residual risk because the recoverable values are counts of children in coarse
administrative categories, not sensitive attributes.

## Consequences

The suppression is applied at write time by `suppress_small_cells()` in
`scripts/shared_functions.R`, so re-running the pipeline reproduces the
published form rather than the raw form. A replicator with approved data access
sees the unsuppressed values in their own run; only the deposited copy is
masked.

This decision is effectively irreversible once the package is public, which is
why the reasoning is recorded rather than left implicit.
