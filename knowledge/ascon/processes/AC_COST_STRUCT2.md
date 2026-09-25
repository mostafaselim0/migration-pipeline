# AC_COST_STRUCT2 - هيكل مركز التكلفة 2 / Structure of Cost Center 2

- Registry: system 1 serial 78. APEX grid page 10130.
- Legacy module: `ASCON\AC\FMB\ac_cost_Struct2.fmx` (no .fmb; GN_FORM_ITEM labels on block COST_STRCTURES).
- **Deliverable: generated grid kept (`AUTO`) + rules**, override `app\legacy\overrides\AC_COST_STRUCT2.json`, PL/SQL `APP_RULES3_GL`.
- **Confidence: high.**

## What the screen is

Same form as AC_COST_STRUCT1 for cost centres 2: `AC_COST_STRCTURES` rows with `COST_CENTER_NUMBER = 2`, locked while
`AC_COST_CENTERS2` has rows (`SELECT COUNT(COST_CODE) FROM AC_COST_CENTERS2`). All rules of AC_COST_STRUCT1.md apply with
number 2 (where `COST_CENTER_NUMBER = 2`, key_expr `cost_struct_no` gives 2 on page 10130, level / start / length derived, end <= 9,
bottom-up delete, same messages). Both screens share the table trigger; the rules use the row's own structure number.

## Tests

Section A of `tmp\w3_gl\gl\t_gl.py`: on page 10130 a fifth level (start 10 > 9) is refused; level 4 deleted and re-entered got
number 2, start 7, length 3. Passed.


## Wave 3b

Checked: as AC_COST_STRUCT1 (no check box / list / radio item; SUM_STR / REST_STR are grid totals, not per-row values).

## Coverage

As AC_COST_STRUCT1.md (running totals and the exit warning not reproduced; grid limits).
