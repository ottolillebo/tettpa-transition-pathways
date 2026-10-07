# Variables

The primary script expects an approved source extract with the following administrative fields:

- `Saksnummer`
- `Id`
- `Sakstype`
- `Hovedkategori`
- `Kjonn`
- `Fodselsar`
- `Alder`
- `Tilhorighet`
- `Klient organisasjon`
- `Klient status`
- `Status`
- `Status ny`
- `Status under arbeid`
- `Status avsluttet`

Norwegian source extracts may use the original Norwegian characters in field names. The analysis script normalises selected fields internally.

Key derived analytic variables include:

- first early-intervention case date;
- later PPT case registration within follow-up;
- later expert-assessment registration within follow-up;
- months since first early-intervention case;
- presenting-concern group;
- derived service tier;
- entry cohort and follow-up availability.

The manuscript uses child-level time-to-event analyses, but only aggregate outputs are included in this repository.

