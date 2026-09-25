# ST_TERM_SHIP — أرقام شروط الشحن / Shipment Conditions (system 30, serial 18)

Deliverable: **business rules on the generated code-table screen** — `overrides/ST_TERM_SHIP.json` (AUTO + row rule),
`APP_RULES3_PR`, delete hook `APP_R3_ST_TERM_SHIP_BD`. Page 50080. Confidence: **high**.

## Purpose and tables
Code table `ST_TERM_SHIP` (TERM_SHIP_CODE, NAME_A, NAME_E; 2 rows) referenced by `PR_ORDER.TERM_SHIP_CODE`.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Number = max + 1 | generated APPX key | `SELECT NVL(MAX(TERM_SHIP_CODE),0)+1 FROM ST_TERM_SHIP` | high |
| 2 | No duplicate number (typed number) — "رقم مكرر تم إدخالة من قبل" | row rule `term_ship_row` | .fmx message | high |
| 3 | Delete refused while a purchase order uses the term — "تم تخصيص هذا الرقم مع أمر شراء أو أكثر / لا يمكن حذفها حالياً." | trigger `APP_R3_ST_TERM_SHIP_BD` → `term_ship_delete` | `SELECT COUNT(1) FROM PR_ORDER WHERE TERM_SHIP_CODE = :b1` + message | high |

## Tests (`tmp\w3_prsa\t_w3prsa.py`)
TS1 new term numbered max + 1 · TS2 duplicate refused · TS3 delete refused while PR_ORDER uses it (fixture order) ·
TS4 unused term deleted. All PASS.

## Wave 3b
Swept for the wave-3b keys: the legacy form has only three text items (number, Arabic / English name); no radio group, list item, check box, display item,
LOV, update-after-insert restriction, block restriction or button to another form (GN_FORM_ITEM types and .fmx texts). Nothing
to apply; the page is unchanged.

## Coverage
Reproduced: numbering, duplicate, delete restriction.
Not reproduced: texts of the shared unit-form template left in the .fmx ("كود الوحدة مكرر", "تم تخصيص هذه الوحدة مع صنف"
— dead code copied from the units form), delete confirmation alert, toolbar / translation library code.
