# LC_PORT — أرقام الموانى / Ports (system 30, serial 19)

Deliverable: **business rules + label** — `overrides/LC_PORT.json` (AUTO + row rule, PORT_CODE label "empty = next
number"), `APP_RULES3_PR`, delete hook `APP_R3_LC_PORT_BD`. Page 50090. Confidence: **high**.

## Purpose and tables
Code table `LC_PORT` (port number, names, country) used by the letters of credit (`LC_CREDIT.PORT_CODE`,
`LC_CREDIT_OPEN.PORT_CODE`).

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Number > 0 — "رقم الميناء يجب ان يكون اكبر من الصفر" | row rule `port_row` | .fmx message | high |
| 2 | No duplicate — "رقم مكرر تم إدخالة من قبل" | row rule (INSERT) | `SELECT COUNT(1) FROM LC_PORT WHERE PORT_CODE = :b1` | high |
| 3 | Empty number → next number | generated APPX key | APEX convenience | medium |
| 4 | Delete refused (letters of credit) — "لا يمكن حذف الميناء التالى لوجود ارتباط مع ملف الاعتماد الرئيسى" | trigger `APP_R3_LC_PORT_BD` → `port_delete` | `SELECT COUNT(1) FROM LC_CREDIT WHERE PORT_CODE = :b1` | high |
| 5 | Delete refused (opening file) — "... مع ملف فتح الاعتماد" | same | `SELECT COUNT(1) FROM LC_CREDIT_OPEN WHERE PORT_CODE = :b1` | high |

## Generator issue
Wave 2/3: the generator attached the list `ST_SHIP_PORTS` (empty table) to PORT_CODE and the field was relabelled
"(فارغ = الرقم التالي)" as a workaround. Solved in wave 3b (see below).

## Tests (`tmp\w3_prsa\t_w3prsa.py`)
PT1 number 0 refused · PT2 empty number → next number · PT3 duplicate refused · PT4 delete refused (LC_CREDIT) ·
PT5 delete refused (LC_CREDIT_OPEN). All PASS.

## Wave 3b
* `rules.columns` `LC_PORT.PORT_CODE`: `lov: null` removes the wrong automatic list `ST_SHIP_PORTS` (0 rows); the field is a
  plain number field again with the legacy label "رقم الميناء" / "Port No" (GN_FORM_ITEM). The workaround label is gone; a
  new port left without a number still gets the next number (generated key, rule 3).
* Sweep: no radio group, list item, check box, display item, update / required restriction or call-form button in the
  legacy form (GN_FORM_ITEM: four text items; .fmx texts only messages).
* Check: `tmp\w3b_prsa\check_forms.py LC_PORT` (page generated, no list).

## Coverage
Reproduced: all rules; the number is a plain field as in the legacy form (wave 3b).
Not reproduced: delete confirmation alert, toolbar / translation library code (Forms mechanics).
