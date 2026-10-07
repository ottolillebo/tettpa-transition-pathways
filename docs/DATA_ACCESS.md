# Data access

The source data are restricted administrative case-management records from Trondheim Educational Psychological Service (PPT). They include child-level case registrations and cannot be deposited in a public repository.

Researchers who want to reproduce the full analysis must request access through the responsible data controller and the project team. Access is conditional on:

- documented research purpose and institutional affiliation;
- approval from the relevant data controller;
- valid legal basis for processing personal data;
- data processing agreement;
- secure storage and processing environment;
- use of a de-identified or pseudonymised extract where approved;
- prohibition on re-identification and onward sharing.

After approval, place the approved local extract outside the Git repository and point the analysis script to it:

```powershell
$env:TETTPA_DATA_FILE="C:\secure\StatisticsCaseDetailsList.xlsm"
Rscript scripts/article_analysis.R
```

Do not commit raw extracts, derived child-level files, case identifiers, local data paths, or data provenance files containing file hashes.

