# ST_PERIODS — فترات السنة / Year Periods (system 30 serial 27 and system 31 serial 12)

Deliverable: **business rules + labels** — `overrides/ST_PERIODS.json` (AUTO, key_expr `next_period_code`, PERIOD_CODE
optional "empty = next number", legacy labels, row rule), `APP_RULES3_PR` (`period_row`, `period_overlap`), compound
trigger `APP_R3_ST_PERIODS_CT` (overlap check after the statement: a row trigger cannot read ST_PERIODS on UPDATE).
Page 50150 (both menu entries open the same form). Confidence: **high**.

## Purpose and tables
`ST_PERIODS` (PERIOD_CODE, names, FROM_DATE, TILL_DATE; empty in the build copy): the periods of the sales plan
(`ST_SALES_PLAN.PERIOD_CODE`).

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Number ≥ 0 — "رقم الفترة لا يمكن أن يكون أقل من الصفر"; empty → max + 1 | row rule `period_row`; key_expr | .fmx message | high |
| 2 | No duplicate — "كود مكرر" | row rule (INSERT) | `SELECT COUNT(1) FROM ST_PERIODS WHERE PERIOD_CODE = :b1` | high |
| 3 | From date < to date — "يجب ان يكون من تاريخ اصغر من الى تاريخ" | row rule | messages (also "تاريخ النهاية يجب ان يكون أكبر من البداية") | high |
| 4 | Dates not before the minimum (MIN(ST_BASIC.MIN_DATE), systems 3/30/31) — "التاريخ أقل من الحد الأدنى المسموح به" | row rule (`st_min_date`) | library CHECK_DATE / CHECK_MAX_MIN_DATE | high |
| 5 | Dates not after today + 24 months (ST_BASIC has no MAX_DATE → library default ADD_MONTHS(SYSDATE,24)) — "تاريخ الفترة أكبر من المسموح بة" | row rule | CHECK_DATE (IS_CHECK = 1 branch) | high |
| 6 | Periods may not overlap — "يوجد تقاطع فى نطاق التواريخ مع نطاق أخر" (legacy test: the new from or to date lies inside another period) | compound trigger → `period_overlap` (own row excluded) | `SELECT COUNT(1) FROM ST_PERIODS WHERE (:b1 BETWEEN FROM_DATE AND TILL_DATE OR :b2 BETWEEN FROM_DATE AND TILL_DATE)` (3×) | high |

## Generator issue
Wave 2/3: the generator attached the list `AC_ESTIMATE_PERIODS` (empty) to PERIOD_CODE; the field was relabelled
"(فارغ = الرقم التالي)" as a workaround. Solved in wave 3b (see below).

## Open questions
* "لا يمكن مسحل السجل الحالى" (the current record cannot be deleted): the .fmx has no SQL for it; probably periods used by a
  sales plan. Not reproduced, and no foreign key references ST_PERIODS, so a period used by a sales plan can be deleted.
  Which condition applies?
* Suggestion (not implemented, not legacy): the overlap test does not catch a new period that encloses an existing one.

## Tests (`tmp\w3_prsa\t_w3prsa.py`)
PE1 negative number · PE2 from ≥ to · PE3 before the minimum date · PE4 after the maximum · PE5 empty number → next number ·
PE6 overlapping insert refused · PE7 overlapping update refused (statement-level check) · PE8 duplicate number. All PASS.

## Wave 3b
* `rules.columns` `ST_PERIODS.PERIOD_CODE`: `lov: null` removes the wrong automatic list `AC_ESTIMATE_PERIODS` (0 rows);
  plain number field with the label "رقم الفترة" / "Period No". The field stays optional and an empty number still gets the
  next number (`key_expr next_period_code`, rule 1).
* Sweep: no radio group / list / check box / display item / button to another form in the .fmx (texts are messages only).
* Check: `tmp\w3b_prsa\check_forms.py ST_PERIODS`.

## Coverage
Reproduced: number (plain field since wave 3b), duplicate, date order, minimum / maximum date, overlap.
Not reproduced: the delete message of unknown condition (question above), the print button "طباعة السند" (report, outside
Stage C), delete confirmation alert, toolbar / translation library code.
