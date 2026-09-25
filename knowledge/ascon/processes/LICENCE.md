# LICENCE - الشركات - أنواع تصاريح الشركات / Licence Types

- Registry: system 99 serial 2 (COMPANY_MENU.COMPANY_AUTH, order 1003). APEX grid page 80030.
- Legacy module: `ASCON\SE\FMB\Licence.fmx`. One block LICENCE (الرقم، الاسم عربى / لاتينى، ملاحظات).
- **Deliverable: code table + one rule** - `app\legacy\overrides\LICENCE.json` (AUTO + row rule), package `APP_RULES3_SE.code_row`.
- **Confidence: high.**

## Rules

| # | Legacy rule | Evidence | APEX |
|---|---|---|---|
| 1 | "رقم نوع التصريح موجود من قبل" | `SELECT COUNT(1) FROM LICENCE WHERE LICENCE_CODE = :b1` (twice) + message | row rule `code_row` on insert |
| 2 | Code typed by the user | LICENCE_CODE item | typed; empty -> generated max+1 |

Evidence checked: embedded SQL (2), Arabic texts, identifiers (standard toolbar), table LICENCE (0 rows, PK LICENCE_CODE).

## Tests (t_se.py, rolled back)

W2 duplicate code message.


## Wave 3b

Checked, nothing to change: a plain code table (code, Arabic / English name, remarks); no check box / list item / display item.

## Coverage

Reproduced: rules 1-2. Not reproduced: the "خطأ صلاحية" template check (page rights), print and translation buttons.
