# ST_ITEM_DOSAGE_FORM - أرقام شكل الجرعات / Item Dosage Form

- Registry: system 3 serial 29, menu `CODES_MENU.ST_ITEM_DOSAGE_FORM`. Legacy `ASCON\ST\FMB\ST_ITEM_DOSAGE_FORM.fmx` (no .fmb).
- APEX: page 20210, `GRID` on `ST_ITEM_DOSAGE_FORM` (`DOSAGE_FORM_CODE`, `DESC_A`, `DESC_E`). Override `overrides\ST_ITEM_DOSAGE_FORM.json`
  (row rule), package `APP_RULES3_ST.class_row`.
- Data: 1 dosage form; `ST_ITEM.DOSAGE_FORM_CODE` filled on all 4035 items (no FK).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| code greater than zero: "قم بادخال رقم اكبر من الصفر" | message | row rule `class_row('ST_ITEM_DOSAGE_FORM', ...)` | high |
| Arabic or English name: "يجب ادخال الأسم عربى أو لاتينى" | message | same | high |
| duplicate code: "هذا السجل تم ادخاله من قبل ... رقم مكرر" | `SELECT COUNT(1) FROM ST_ITEM_DOSAGE_FORM WHERE DOSAGE_FORM_CODE = :b1` | same (insert) + primary key | high |
| empty code filled with max+1 | not in the legacy | generic max+1 of `APPX_ST_ITEM_DOSAGE_FORM` | - |

## Tests (rolled back)

A3 (shared `class_row`): code 0, missing names and duplicates refused; a new dosage form code 77 accepted.

## Open questions

- Delete protection: only the template text "تم استخدام هذه النوع مع مخزن أو أكثر" exists, no query on `ST_ITEM.DOSAGE_FORM_CODE`
  (the `SELECT COUNT(1) FROM ST_ITEM_DOSAGE_FORM` is the record counter). Not reproduced - should used dosage forms be protected?

## Coverage

- Reproduced: all checks above. Not reproduced: record counter, delete message (question), toolbar print (no RDF on disk).
- The row rule is active in `APPX_ST_ITEM_DOSAGE_FORM` after the next build.
