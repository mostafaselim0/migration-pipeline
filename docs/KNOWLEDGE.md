# The knowledge base

`knowledge/<product>/` holds everything that was reviewed once for a product and is reused for every client of it.
`knowledge/ascon/` comes from the first ASCON client migrated by hand (SMART, repository `smart-transformation`).

| file / folder | what | used by |
|---|---|---|
| `product.json` | page range per legacy system, report folder per system, reference sources on this server | specs, reports, mp |
| `overrides/<FORM>.json` | reviewed screen rules: pattern corrections, numbering, validations, defaults, lists, computed columns, links, actions, process pages (199) | specs |
| `report_overrides/<RDF>.sql` | hand-fixed SQL for reports whose RDF query does not translate (19) | reports |
| `processes/<FORM>.md` | the evidence and reasoning behind each reviewed screen (211) | people, `llm` |
| `db/2x_*.sql` | PL/SQL packages holding the reconstructed Forms logic: postings, conversions (quotation to order ...), rules (22 files) | build db |
| `prints.json` | which legacy report prints which document, with which parameters (75 screens, 110 buttons) | build, apexgen |
| `translations_manual.json` | English for Arabic texts the dictionary does not cover | translate |
| `contracts/*.md` | the rule format (generator keys) and the LLM brief | people, `llm` |
| `fingerprints.json` | hashes of the reference installation's screens, reports, tables and stored code (no source, no data) | delta |

## How it grows

1. **learn**: `python pipeline.py smart learn` recorded SMART as the reference (`fingerprints.json`).  Run it again
   only for the reference client.
2. **overlay**: a client's own rules live in `clients/<c>/overlay/` with the same file names; they win over the
   knowledge for that client only.
3. **promote**: when a client's reviewed rule is really product behaviour (a newer ASCON version, a module the first
   client did not have), `python pipeline.py <c> promote <FORM> ...` copies it into the knowledge and learns the screen's
   fingerprint from that client.  From then on every client with the same screen gets it as SAME.

Rules written for one version of the product may not fit another (a column that does not exist, a function another
version lacks).  The build never fails on that: such rules are switched off per procedure or per rule line and listed
in the client's report (`engine/gen/degrade.py`), so the knowledge can stay the most complete version.

## Adding a second product

A different Forms product works the same way with its own `knowledge/<product>/` (product.json with its registry
tables' page ranges, and its own reviewed rules, which start empty).  The engine assumes ASCON's registry tables
(`SYS_SYSTEMS`, `SYS_FILES`, `SYS_REPORTS`, `GN_FORM_ITEM`, `USERS`); another product needs those queries mapped in
`specs.py`, `labels.py`, `fingerprint.py` and `01_app_core.sql`.
