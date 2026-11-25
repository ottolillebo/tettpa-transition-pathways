# Data access

The source data are restricted administrative case-management records from Trondheim Educational Psychological Service (PPT). They include child-level case registrations and cannot be deposited in a public repository.

## Who to contact

The data controller is the City of Trondheim (Trondheim kommune), Department of Childhood and Education (Oppvekst og utdanning). Research enquiries are handled by a standing resource group: a research-and-innovation coordinator at the city government department, together with research contacts for the Schools, Kindergartens, and Mastery and Inclusion service areas. Current routing and submission requirements are published here:

<https://www.trondheim.kommune.no/aktuelt/vare-satsingsomrader/forskning-utvikling-og-naring/forskningshenvendelser-til-oppvekst-og-utdanning-gjelder-ikke-studentoppgaver-som-master-bachelor-og-liknende/>

Note that this is the municipality's general intake route for research collaboration, not a data-request portal. The published requirements include a project outline, a budget, documented dialogue with the units concerned, and a draft letter of intent. If the page has moved, search trondheim.kommune.no for "forskningshenvendelser oppvekst og utdanning".

## Conditions for access

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

