# ST_ACTIVE_MATERIAL - أرقام المواد الفعالة / Items Materials Numbers

- Registry: system 3 serial 26, menu `CODES_MENU.ST_MATERIAL`. Legacy `ASCON\ST\FMB\st_active_material.fmx` (no .fmb, no GN_FORM_ITEM
  labels - the generator took the columns from the .fmx).
- APEX: page 20240, `GRID` on `ST_ACTIVE_MATERIAL` (`SERIAL`, `NAME_A`, `NAME_E`). Override `overrides\ST_ACTIVE_MATERIAL.json` (row rule),
  package `APP_RULES3_ST`, delete trigger `APP_RULES3_ST_MATERIAL_BD`.
- Data: 1 material; `ST_ITEM.ACTIVE_MATERIAL_CODE` = 1 on all 4035 items (no FK).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| serial = `MAX(SERIAL)+1` | `SELECT MAX(SERIAL) FROM ST_ACTIVE_MATERIAL` (twice) | generic max+1 of `APPX_ST_ACTIVE_MATERIAL` | high |
| serial greater than zero: "قم بادخال رقم اكبر من الصفر" | message | row rule `class_row('ST_ACTIVE_MATERIAL', ...)` | high |
| Arabic or English name: "يجب ادخال الأسم عربى أو لاتينى" | message | same | high |
| duplicate: "هذا الكود موجود من قبل" | `SELECT COUNT(1) / SELECT SERIAL FROM ST_ACTIVE_MATERIAL WHERE SERIAL = :b1` | same (insert) + primary key | high |
| material used by items cannot be deleted: "تم تخصيص هذه المادة الفعالة مع صنف أو أكثر - لا يمكن حذفها حالياً." | `SELECT COUNT(1) FROM ST_ITEM WHERE ACTIVE_MATERIAL_CODE = :b1` | delete trigger `APP_RULES3_ST_MATERIAL_BD` (-20174) | high |

## Tests (rolled back)

A3 duplicate serial 1 refused ("هذا الكود موجود من قبل"); A6 deleting material 1 (used by items) refused.

## Coverage

- Reproduced: all rules above.
- Not reproduced: toolbar print (no RDF for this form on disk).
- The row rule is active in `APPX_ST_ACTIVE_MATERIAL` after the next build; the delete trigger is active now.
