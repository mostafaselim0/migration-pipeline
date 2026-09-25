# Is "just dump the client's data" feasible?

**Yes for ASCON clients, with one condition and one honest limit.**

## What a dump alone gives, automatically

| part of the legacy system | where it lives | from a dump alone |
|---|---|---|
| All data | database | yes, with Arabic text kept whole (CHAR semantics) |
| Database business logic: triggers (numbering, tax, closing periods, stock cost), procedures, functions, views | database | yes, it is the client's own code, carried over as is |
| Users, passwords, rights per screen, companies | database (`USERS`, rights tables) | yes: the legacy users sign in with their legacy passwords and see only their screens |
| Menu, screen list, report list | database registry (`SYS_SYSTEMS`, `SYS_FILES`, `SYS_REPORTS`) | yes |
| Screen labels (Arabic and English) | database (`GN_FORM_ITEM`) | yes |
| Screen structure (tables, master-detail, lists of values) | Forms files + database | yes: derived from the dictionary and labels, corrected by the knowledge for known screens |
| Forms-level rules (validations and defaults written in Forms triggers) | Forms files | from the **knowledge**, for every screen that is the same as the product's |
| Report queries and exact print layouts | Reports files | from the **product's reference reports** |

**The condition:** the product must have been migrated once (the knowledge base).  For ASCON that is done (SMART).

**The limit:** whatever a client changed *inside* its Forms or Reports files (a customised screen trigger, a modified
report) is not in its dump.  With the dump alone those screens and reports behave like the product's standard ones.
The fix is cheap: the client's ASCON folder, converted to XML on its Forms server (`legacy-server/`), lets the delta
stage find those screens and the generator use the client's own reports.

## "Some clients have more modules and different business logic"

| difference | what the pipeline does |
|---|---|
| different database logic (their own triggers, procedures) | nothing to do: it comes with the dump and runs under the new screens; the delta lists it |
| more modules (systems the knowledge has not seen) | their screens and reports are generated from the registry, dictionary and labels like any other, in a page range of their own; they are listed as a new module in DELTA.md and their screens are NEW |
| another version of the product (columns missing or added) | tables and screens follow the client's dictionary; reviewed product rules that do not fit are switched off per procedure / rule line and listed |
| changed Forms logic on a known screen | the delta marks the screen CHANGED (needs the client's Forms folder); rules go to the client's overlay, drafted by hand or by the optional LLM step |
| installation-specific branches in shared code | `customer_code` in client.json feeds the knowledge packages that test it |

## What still needs people

1. **Key-user acceptance** of CHANGED / NEW screens and new modules (listed in DELTA.md), and of anything REPORT.md
   says was switched off.
2. **Rules for those screens**: an overlay file per screen, written by a person or drafted by the LLM step and reviewed.
3. **Integrations and devices** outside the database (e-invoicing, track-and-trace, printers, scanners) are per
   installation and not migrated by the pipeline.

## First full client: Areej

Areej (car rentals) is the first installation run through the pipeline with its own Forms/Reports folder: 22 legacy
systems against the 9 of the reference, 616 registered screens and 521 reports.  Its numbers are in
`clients/areej/work/REPORT.md` and `DELTA.md` after each run.
