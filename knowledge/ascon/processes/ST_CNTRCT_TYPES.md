# ST_CNTRCT_TYPES — أنواع التعاقد / Contract Types (system 30, serial 38)

Deliverable: **business rules + labels** — `overrides/ST_CNTRCT_TYPES.json` (AUTO, row rule, legacy labels, CNTRCT_ORDER
hidden: not on the legacy screen), `APP_RULES3_PR`, delete hook `APP_R3_ST_CNTRCT_TYPES_BD`. Page 50120.
Confidence: **high**.

## Purpose and tables
Code table `ST_CNTRCT_TYPES` (3 rows) of the supplier agreements (`ST_SUPP_AGRMNT.CNTRCT_CODE`).

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Number = max + 1 | generated APPX key | `SELECT NVL(MAX(CNTRCT_CODE),0)+1 FROM ST_CNTRCT_TYPES` | high |
| 2 | Arabic or English name required — "يجب ادخال الأسم عربى أو لاتينى" | row rule `cntrct_row` | .fmx message (twice: WVR / PRE-INSERT) | high |
| 3 | No duplicate — "هذا السجل تم ادخاله من قبل ... رقم مكرر" | row rule (INSERT) | `SELECT COUNT(1) FROM ST_CNTRCT_TYPES WHERE CNTRCT_CODE = :b1` | high |
| 4 | Delete refused while an agreement uses the type — "تم استخدام هذه الماركة فى النظام / لا يمكن حذفه حالياً." | trigger `APP_R3_ST_CNTRCT_TYPES_BD` → `cntrct_delete` | `SELECT COUNT(CNTRCT_CODE) FROM ST_SUPP_AGRMNT WHERE CNTRCT_CODE = :b1` | high |

## Tests (`tmp\w3_prsa\t_w3prsa.py`)
CT1 name required · CT2 numbered max + 1 · CT3 duplicate refused · CT4 delete refused while an agreement uses the type. All PASS.

## Wave 3b
Swept for the wave-3b keys: the legacy form has only number, names and a hidden order column; no radio group, list item, check box, display item,
LOV, update-after-insert restriction, block restriction or button to another form (GN_FORM_ITEM types and .fmx texts). Nothing
to apply; the page is unchanged.

## Coverage
Reproduced: all rules (the legacy message says "الماركة" — copied from the brands form — and is kept verbatim).
Not reproduced: delete confirmation alert, toolbar / translation library code.
