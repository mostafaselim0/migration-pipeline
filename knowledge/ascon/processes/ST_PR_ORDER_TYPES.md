# ST_PR_ORDER_TYPES — أرقام أنواع أوامر الشراء / Purchase Order Types (system 30, serial 42)

Deliverable: **business rules on the generated screen** — `overrides/ST_PR_ORDER_TYPES.json` (AUTO + row rule),
`APP_RULES3_PR.pr_order_type_row`. Page 50130. Confidence: **high**.

## Purpose and tables
Code table `ST_PR_ORDER_TYPES` (SERIAL, names, TRNS_TYPE_CODE = purchase transaction linked to the order type), used by
`PR_ORDER.PR_ORDER_TYPE` and `ST_PO_ITEM_SUPP.PR_ORDER_TYPE`.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Number > 0 — "قم بادخال رقم اكبر من الصفر"; next number when empty | row rule `pr_order_type_row`; generated key | `SELECT MAX(SERIAL) FROM ST_PR_ORDER_TYPES`, message | high |
| 2 | No duplicate — "هذا الكود موجود من قبل" | row rule (INSERT) | `SELECT COUNT(1) FROM ST_PR_ORDER_TYPES WHERE SERIAL = :b1` | high |
| 3 | Arabic or English name — "يجب ادخال الأسم عربى أو لاتينى" | row rule | message | high |
| 4 | Purchase transaction from the legacy list (EFFECT 1 / TRNS_TYPE 1) | row rule (`type_is`) | LOV `SELECT TRNS_TYPE_CODE,DESC_A,DESC_E FROM ST_TRNS_TYPE WHERE EFFECT=1 AND TRNS_TYPE=1` | high |

## Tests (`tmp\w3_prsa\t_w3prsa.py`)
OT1 number 0 refused · OT2 name required · OT3 sales type refused as purchase transaction · OT4 valid type saved ·
OT5 duplicate refused. All PASS.

## Wave 3b
* `rules.columns` `ST_PR_ORDER_TYPES.TRNS_TYPE_CODE`: select list from the legacy LOV
  `SELECT TRNS_TYPE_CODE, DESC_A, DESC_E FROM ST_TRNS_TYPE WHERE EFFECT = 1 AND TRNS_TYPE = 1 ORDER BY 1`; it shows the name of
  the purchase transaction, which the legacy form displayed in TRNS_TYPE_NAME ("بيان الحركة"). The row rule stays.
* Sweep: no other list / check box / call-form button in the .fmx.
* Check: `check_forms.py ST_PR_ORDER_TYPES` (list returns the 4 purchase types of the build copy).

## Coverage
Reproduced: all rules; purchase transaction chosen from the legacy list with its name (wave 3b).
Not reproduced: texts of the copied active-ingredient / unit template ("تم تخصيص هذه المادة الفعالة
مع صنف" — dead code, no SQL behind it), delete confirmation alert, toolbar / translation library code. No delete
restriction exists in the legacy form (no SQL); the database foreign keys, if any, still apply.
