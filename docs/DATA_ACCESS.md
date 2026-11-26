# Data access

The source data are child-level administrative case records from Trondheim Educational Psychological Service. They cannot be deposited publicly and are not in this repository.

The data controller is the City of Trondheim, Department of Childhood and Education (Oppvekst og utdanning). Research enquiries go to a standing resource group: a research-and-innovation coordinator in the city government department, with research contacts for the Schools, Kindergartens, and Mastery and Inclusion service areas. The current route and what they require is published at:

<https://www.trondheim.kommune.no/aktuelt/vare-satsingsomrader/forskning-utvikling-og-naring/forskningshenvendelser-til-oppvekst-og-utdanning-gjelder-ikke-studentoppgaver-som-master-bachelor-og-liknende/>

If that page has moved, search trondheim.kommune.no for "forskningshenvendelser oppvekst og utdanning". This is the municipality's general intake for research collaboration rather than a data-request form, so expect to supply a project outline, a budget, documented contact with the units concerned, and a draft letter of intent.

Access also requires a legal basis for processing personal data, a data processing agreement, a secure processing environment, and an undertaking not to re-identify or pass on the records.

Once approved, keep the extract outside the repository and point the script at it:

```powershell
$env:TETTPA_DATA_FILE="C:\secure\StatisticsCaseDetailsList.xlsm"
Rscript scripts/article_analysis.R
```

Never commit raw extracts, derived child-level files, case identifiers, local data paths, or provenance files containing file hashes.
