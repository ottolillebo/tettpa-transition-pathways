# Publication checklist

Steps for releasing this reproducibility package. The repository is content-ready
and disclosure-clean; the remaining items are deliberate decisions about **timing
and identity**, which should be the author's.

## Status (2026-07-01, updated 2026-11-10)

- [x] Analysis + figure scripts staged (`article_analysis.R`, `render_manuscript_figures.R`).
- [x] **2026-11-10:** `appendix_robustness_analysis.R` and `shared_functions.R` added;
      strict-risk-set rule corrected; figure labels aligned with the manuscript
      (PPT to EPS, proximity-model districts). See 'Correction history' in README.md.
- [x] Aggregate outputs staged (`outputs/tables/`, `outputs/diagnostics/`, `outputs/figures/`).
- [x] Docs staged (`README.md`, `docs/DATA_ACCESS.md`, `docs/VARIABLES.md`, `docs/OUTPUTS.md`).
- [x] Disclosure scan clean: no raw data, no real local paths, no data hash values, no author name. `data/` holds only a README.
- [x] Data-entry typo corrected in code + aggregate output ("Erververvet" -> "Ervervet hjerneskade").
- [x] Initial commit (author-owned): `6ee6fba`, 2026-10-07,
      Otto Sevaldson Lillebø <otto.lillebo@nifu.no>. 55 files; staging verified
      clean (no restricted data, no ignored-file leakage).
- [x] **2026-11-25:** Cell suppression applied to the support diagnostics (threshold 5)
      and exact registration dates reduced to months; `CITATION.cff` completed with the
      author. Disclosure scan re-run over all 40 output CSVs — the only remaining counts
      below five are those already published in the article appendix.
- [ ] Public release — unblocked at acceptance; remaining steps under 'At acceptance'.

## During peer review (double-anonymous) — do NOT publish publicly

A public GitHub repo can be found by a reviewer, and commit metadata (git identity)
would de-anonymize you even though `CITATION.cff` is a placeholder.

- Keep the repository local, or
- If reviewers need to inspect the code, share an **anonymized** view-only link
  (OSF anonymized link / Zenodo restricted) — not GitHub.

## First commit (run when you choose — this should be your commit)

`safe.directory` is already configured for this path.

```powershell
cd <local clone of this repository>
# confirm your git identity is the one you want on a public academic repo:
git config user.name  ; git config user.email
git add -A
git status                     # verify only intended files; no data, no local paths
git commit -m "Reproducibility package for the EJSNE transition-pathways manuscript"
```

## At acceptance — release

1. ~~Fill in the author in `CITATION.cff`~~ (done 2026-11-25).
2. Create the GitHub repository and push:
   ```powershell
   git remote add origin https://github.com/<user>/tettpa-transition-pathways.git
   git push -u origin master
   ```
3. Mint a permanent identifier (OSF or Zenodo DOI); OSF can reference the exact Git commit.
4. Record the exact commit hash / OSF version.
5. Add the public citation + permanent identifier to the manuscript's
   **Data and code availability** statement.
6. Re-run `Rscript scripts/article_analysis.R` against the approved local extract to
   confirm the deposited aggregate outputs match (the environment used on 2026-07-01
   had no R; the outputs were carried over from the locked 2026-06-15 run).

## Disclosure controls (verified — keep true on any future update)

- No raw / person-level data in the repo (`.gitignore` blocks `*.xlsm/xlsx/rds/...`).
- No real local file paths or data hash values in tracked files.
- `organization_service_tier_mapping.csv` and `data_provenance.csv` stay git-ignored
  (disclosure risk).
- Small-cell aggregate counts are limited to what already appears in the published
  article/appendix.


## Verification run, 2026-11-10

Run against the approved local extract with R 4.4.2, the version recorded in
`outputs/diagnostics/session_info.txt`.

| Check | Result |
|---|---|
| Package before the correction | Reproduced its own stored `sample_flow.csv` exactly (13 excluded, 1,358) |
| Package after the correction | 17 excluded, 1,354 — matches the revised manuscript |
| `article_analysis.R` tables vs the working pipeline | 21 of 23 byte-identical; the two differences are a column label only (`Age at index date` vs the manuscript's `Age at early-intervention registration`), identical values |
| `appendix_robustness_analysis.R` | All 8 outputs byte-identical to the working pipeline |
| Table 5 values | Separate district indicators 1.17 / 1.07 / 1.16 and entry windows 1.09 / 1.02 reproduce exactly |

**Still to do before public release:** rerun both scripts once on the author's own
machine and refresh `outputs/` from that run, so the staged aggregates come from the
corrected code rather than the July run.
