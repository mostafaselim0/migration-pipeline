# RET_INV_CODES — أرقام سبب المرتجعات / Return Reason Codes (system 31, serial 36)

Deliverable: **business rule + labels** — `overrides/RET_INV_CODES.json` (AUTO, row rule, legacy labels, number
"empty = next number"), `APP_RULES3_SA.ret_code_row`. Page 60060. Confidence: **high**.

## Purpose and tables
Code table `RET_INV_CODES` (COMPLAINT_CODE, COMPLAINT_NAME, COMPLAINT_NAME_E): reasons of sales returns.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Number = max + 1 | generated APPX key | `SELECT NVL(MAX(COMPLAINT_CODE),0)+1 FROM RET_INV_CODES` | high |
| 2 | No duplicate — "رقم مكرر تم إدخالة من قبل" | row rule (INSERT) | .fmx message | high |

## Generator issue
Wave 2/3: the generator attached the list `COMPLAINT_CODES` (empty table) to COMPLAINT_CODE; the field was relabelled
"(فارغ = الرقم التالي)" as a workaround. Solved in wave 3b (see below).

## Tests (`tmp\w3_prsa\t_w3prsa.py`)
RI1 duplicate refused · RI2 new reason numbered. All PASS.

## Wave 3b
* `rules.columns` `RET_INV_CODES.COMPLAINT_CODE`: `lov: null` removes the wrong automatic list `COMPLAINT_CODES` (empty
  table); plain number field "رقم السبب" / "Reason No". The generated key still numbers a new reason max + 1 (rule 1).
* Sweep: no other list, check box, display item or call-form button in the .fmx.
* Check: `tmp\w3b_prsa\check_forms.py RET_INV_CODES`.

## Coverage
Reproduced: numbering and duplicate check; the number is a plain field again (wave 3b).
Not reproduced: texts of the copied unit-form template ("كود الوحدة مكرر", "تم تخصيص هذه الوحدة مع صنف" — dead code without
SQL), delete confirmation alert, toolbar / translation code. No delete restriction exists in the legacy form.
