# COMM_WAY - الشركات - وسائل الاتصال / Communication Ways

- Registry: system 99 serial 1 (COMPANY_MENU.COMM_WAY, order 1002). APEX grid page 80020.
- Legacy module: `ASCON\SE\FMB\COMM_WAY.fmx`. One block COMM_WAY (الرقم، الاسم عربى / لاتينى، ملاحظات).
- **Deliverable: code table + one rule** - `app\legacy\overrides\COMM_WAY.json` (AUTO + row rule), package `APP_RULES3_SE.code_row`.
- **Confidence: high.**

## Rules

| # | Legacy rule | Evidence | APEX |
|---|---|---|---|
| 1 | "رقم نوع وسيلة الاتصال موجود من قبل" | `SELECT COUNT(1) FROM COMM_WAY WHERE COMM_CODE = :b1` (twice) + message | row rule `code_row` on insert (the PK alone would give the generic message) |
| 2 | Code typed by the user | COMM_CODE item | typed; empty -> generated max+1 |

Evidence checked: embedded SQL (2), Arabic texts, identifiers (standard toolbar only), table COMM_WAY (0 rows, PK COMM_CODE).

## Tests (t_se.py, rolled back)

W1 duplicate code message.


## Wave 3b

Checked, nothing to change: a plain code table (code, Arabic / English name, remarks); no check box / list item / display item.

## Coverage

Reproduced: rules 1-2. Not reproduced: the "خطأ صلاحية" template check (page rights), print (comm_way report) and translation buttons.
