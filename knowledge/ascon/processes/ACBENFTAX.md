# ACBENFTAX - اضافة مورد الخدمات / Add service provider

- Registry: system 1 (General Ledger) serial 53, menu `QUERY_MENU.ACBENFTAX`, order 2009. APEX grid page 10160.
- Legacy module: `ASCON\AC\FMB\ACBENFTAX.fmx` (no .fmb source, no GN_FORM_ITEM labels).
- **Deliverable: screen correction (wave 1) + rules (wave 3)** -> `app\legacy\overrides\ACBENFTAX.json`, pattern `GRID` on `AC_BENF_TAX`,
  insert/update/delete allowed; PL/SQL `APP_RULES3_GL` (row rule) and statement trigger `APP_RULES3_GL_BENF_AS`.
- **Confidence: high** (one table, the only one the form writes; the embedded SQL and the prompts match its three columns).

## What the screen is

A small setup list of service providers (beneficiaries) and their VAT registration number, used by GL
vouchers/cheques that need the provider's tax number. It is an ordinary multi-record data-entry block, not a process.
The generator missed it only because the table name does not resemble the form name.

## Data

| Table | Columns | Access |
|---|---|---|
| `AC_BENF_TAX` (PK `BENF_CODE`, 5 rows) | `BENF_CODE` (كود المنشأة), `BENF_NAME` (أسم المنشأة), `TAX_NO` (الرقم الضريبي) | read / insert / update / delete |

`AC_TRN_CODES` is only referenced by leftover template items ("سنة القيد للحركة", "بيان الحركة"), which the provider list does not use.

## Rules (evidence: embedded SQL + Arabic messages of the .fmx)

| # | Rule | Evidence | APEX |
|---|------|----------|------|
| 1 | New `BENF_CODE` = `SELECT NVL(MAX(NVL(BENF_CODE,0)),0) + 1 FROM AC_BENF_TAX` | embedded SQL | generated max+1 trigger (same rule); column read-only |
| 2 | `TAX_NO` of exactly 15 digits ("خطأ برقم الضريبة .. لابد انيكون مكون من 15 رقم") | message | row rule `benf_tax_row` (when a number is entered) |
| 3 | `TAX_NO` unique: `SELECT COUNT(1) FROM AC_BENF_TAX WHERE TAX_NO = :b1 AND BENF_CODE != :b2` -> "الرقم الضريبي مكرر" | embedded SQL + message | after-statement trigger (the check reads the table itself) |
| 4 | Delete asks for confirmation ("هل تريد حذف هذا السجل") | message | standard grid delete |

Column headings (no labels in GN_FORM_ITEM): كود المنشأة / أسم المنشأة / الرقم الضريبي (`add_columns`).

## Tests (section N of `tmp\w3_gl\gl\t_gl.py`)

A 3-digit number refused, the number of provider 1 refused as duplicate, a new provider numbered 6. Existing data complies (five
distinct 15-digit numbers). Passed.

## Wave 3b

`rules.columns` `AC_BENF_TAX.BENF_CODE: {"lov": null}` removes the wrong list of the empty table CHECK_BENEFICIARY: the code is a plain
read-only number (filled by the trigger). No check box / list item / display item on this block.

## Coverage

- Reproduced: rules 1-4; the code column without the wrong list (wave 3b).
