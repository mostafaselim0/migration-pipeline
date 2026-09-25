# How the Migration Pipeline works

The pipeline turns one client's legacy Oracle Forms / Reports installation (ASCON ERP, Arabic / English) into an Oracle
APEX 24.2 application on this server.  It is a chain of plain Python scripts.  Every stage is deterministic: the same
input gives the same application, byte for byte.  A language model is never needed; it is an optional helper for
the few screens whose legacy logic the knowledge base has not seen yet (see [LLM.md](LLM.md)).

```
 client's dump (.dmp / .zip)          client's Forms/Reports folder (optional)
          │                                      │  legacy-server/Convert-*.ps1 on their Forms server
          ▼                                      ▼
 ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
 │ restore  │──▶│ catalog  │──▶│ generate │──▶│  delta   │──▶│  build   │──▶│  verify  │──▶│  report  │
 └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
  schema, data   dictionary,    one spec per   what differs   DB code,      Edge opens     REPORT.md
  CHAR text,     labels, forms  screen and     from the       APEX export,  every page     DELTA.md
  workspace      & reports      report         knowledge      install, EN   as a legacy
                 catalog                                      translation   user
                                     ▲                             ▲
                                     └──── knowledge/<product> ────┘  reviewed rules of the product
                                           clients/<c>/overlay        reviewed rules of this client (wins)
```

## Folders

| folder | what | in git |
|---|---|---|
| `pipeline.py` | the orchestrator: stages, logs, status | yes |
| `engine/mp.py` | the client context every script imports: `client.json`, paths, knowledge lookup | yes |
| `engine/gen/` | the generator: `meta`, `labels`, `catalog`, `specs`, `reports`, `apexgen`, `build`, `translate`, `rdfprint`, `evidence`, `degrade` | yes |
| `engine/stages/` | pipeline stages that are not generator steps: `restore`, `delta` + `fingerprint`, `verify`, `report`, `learn`, `promote`, `llm`, `init_server` | yes |
| `engine/db/` | the runtime every client gets: `01_app_core` (sign-in on legacy users, rights, menu), `02_app_ui`, `03_app_print`, `04_app_rdf` (legacy report engine) | yes |
| `engine/export/f100/` | the reference APEX export (theme, icons, login page); retargeted to each client's workspace and app id | yes |
| `engine/static/rdfprint.js` | renderer that draws legacy report layouts in the browser | yes |
| `engine/tools/` | DB helper, SQL*Plus / SQLcl runners, Playwright test driver | yes |
| `knowledge/<product>/` | what was reviewed once for the product (below) | yes |
| `clients/<client>/client.json` | the client's settings | yes |
| `clients/<client>/overlay/` | reviewed rules that only this client has | yes |
| `clients/<client>/dump/`, `sources/`, `work/` | the client's data and everything derived from it | **no** |
| `legacy-server/` | scripts to run on the client's Forms / Reports 11g server to convert `.fmb` / `.rdf` to XML | yes |

## The stages

### restore (`engine/stages/restore.py`)
1. Finds the dump (`client.json` `dump`, or the newest file in `clients/<c>/dump`), unzips it if needed, and reads its
   header: classic `exp` (owner and mode are in the header) or Data Pump (schemas read with `SQLFILE`).
2. Creates the client schema with a generated password (Windows User env `<SCHEMA>_PWD` + the operator's password
   file) and the direct grants the legacy code needs (no DBA role).
3. **Pass 1, structure only.** The PDB job queue is stopped for the whole restore; imported jobs are removed and DB
   links dropped, because they point at the client's live systems.  Classic `imp` does not rewrite schema names written
   inside DDL (`create trigger ... on LEGACY_OWNER.ST_TRNS_MAST`): those statements are rebuilt from the imp log and re-run
   for the new schema.
4. Every `VARCHAR2` / `CHAR` column is switched to CHAR length semantics: the legacy databases are AR8MSWIN1256 (one byte
   per Arabic letter), this one AL32UTF8 (two bytes); without this, Arabic text would be cut or rejected.
5. **Pass 2, data** with every trigger and foreign key disabled: legacy triggers must not re-run on historical rows
   (numbering, postings, audit), and load order must not matter.  Then foreign keys are enabled again (`NOVALIDATE`
   where the legacy data breaks them, listed in the report), triggers re-enabled, all PL/SQL recompiled with CHAR
   semantics, statistics gathered.
6. The client's own APEX workspace is (re)created on the schema.  Result: `work/restore.json`.

### catalog (`meta.py`, `labels.py`, `catalog.py`)
Reads the client's data dictionary (tables, keys, foreign keys, comments), the legacy label table `GN_FORM_ITEM`
(Arabic / English prompts per form item) and parses the converted Forms XML, Reports XML and compiled `.fmx` files
into `work/cache/`.  When the client delivered only its dump, the product's reference sources are used
(`knowledge/<product>/product.json` `reference_sources`).

### generate (`specs.py`, `reports.py`)
One spec per screen of the legacy registry `SYS_FILES`: pattern (grid, master-detail, report form, process), tables,
columns, lists of values, labels, pages; reviewed rules are merged from the overlay, else from the knowledge
(`overrides/<FORM>.json`).  One report page per registry report `SYS_REPORTS`, with the RDF's query translated to SQL.

### delta (`engine/stages/delta.py`, `fingerprint.py`)
Compares hashes of the client's system with the knowledge's reference installation: screens (form layout, form logic,
compiled form, labels), reports (queries, parameters, PL/SQL), tables (columns) and stored PL/SQL.  Each screen is
**SAME** (the reviewed rules apply as they are), **CHANGED** (layout or logic differs), **NEW** (the knowledge has never
seen it) or **UNVERIFIED** (nothing comparable).  Modules the knowledge has not seen are listed.  Screens with new or
changed logic and legacy code to read go to `work/llm/worklist.json`.  Output: `work/DELTA.md`.

### build (`build.py db | apex | install | translate`)
* **db**: runs the engine runtime, then the knowledge's DB packages (processes, rules, conversions), then the client's
  overlay packages; compiles every legacy report named in `prints.json` and every report page's RDF into a PL/SQL
  package (exact legacy print layouts); fills the page map and the menu; generates `APPX_<table>` triggers (audit
  columns, keys, reviewed row rules).
* **degradation** (`degrade.py`): when the knowledge does not fit this database (another product version, fewer
  columns), the build does not fail and does not hide it: rule lines that use missing columns are left out, and a
  knowledge package that does not compile keeps working with only its failing procedures replaced by a stub that raises
  *"needs review for this installation"*.  All of it is listed in `work/build/degraded.json` and the report.
* **apex**: writes the APEX split export (`work/build/app`), retargeted to the client's workspace, application id,
  parsing schema, name and alias.  **install** imports it with SQLcl under an id offset of its own (APEX component ids
  are unique in the whole instance).  **translate** publishes the English application.

### verify (`engine/stages/verify.py`, `tools/apptest.py`)
Microsoft Edge (Playwright) signs in as a legacy user of the client (first sign-in forces a new password, which is
saved), opens every generated page and every document page on its first real record, and records APEX / ORA errors.

### report (`engine/stages/report.py`)
`work/REPORT.md`: data restored, differences from the knowledge, what was generated, what was switched off, what the
browser found, and the next steps.

## Knowledge and overlay

`mp.kpath()` looks for a reviewed file in `clients/<c>/overlay/` first and then in `knowledge/<product>/`; JSON files
(`prints.json`, `translations_manual.json`, `product.json`) are merged key by key with the overlay winning.  A client
with other business logic therefore gets its own rules without touching the product's; `promote` moves reviewed
client rules into the product when they are product behaviour.  See [KNOWLEDGE.md](KNOWLEDGE.md).

## Why deterministic

* Page numbers come from the legacy system number (`product.json` `system_pages`); unknown systems (a module the product
  knowledge has not seen) get their own range, so they appear without any code change.
* Component ids are hashes of the component's meaning, so a rebuild changes only what changed.
* Checked against the first client: the pipeline's output for SMART is identical to the hand-driven build of
  the `smart-transformation` repository (specs, reports and 802 of 806 export files byte-identical; the other 4
  differed only by an ordering bug that the pipeline fixed).
