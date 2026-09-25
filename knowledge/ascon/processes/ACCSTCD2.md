# ACCSTCD2 - أرقام مراكز التكلفة 2 / Cost Centers Number 2

- Registry: system 1 serial 22. APEX grid page 10140.
- Legacy module: `ASCON\AC\FMB\ACCSTCD2.fmx` (no .fmb). Tree + block AC_COST_CENTERS2.
- **Deliverable: screen correction + rules**, override `app\legacy\overrides\ACCSTCD2.json` (pattern `GRID`, insert through the button),
  PL/SQL `APP_RULES3_GL`, delete hook `APP_RULES3_GL_COST2_DEL`.
- **Confidence: high.**

## Rules

As ACCSTCD.md for the cost-centre-2 tree (`AC_COST_STRCTURES` number 2, 9 digits), with these differences found in the .fmx:

- no grant tables: ACCSTCD2 has no INSERT / DELETE on AC_COMPANY_COST2 / AC_PASSWORD_COST2 (only the status updates), so none are written;
- transactions are looked up by `COST_CODE2` (AC_OPENING_BALANCE_DET, AC_DAILY_TRN_DET, AC_ESTIMATE, AC_YEARLY_TRN_DET);
- no MAX_LIMIT / project columns.

Button ADD "إضافة مركز تكلفة 2" (parent or typed code), parent status 0 / 1 on insert / last-child delete, delete refused with
transactions, list filtered by AC_PASSWORD_COST2. The generated list of values on COST_CODE points to AC_COST_CENTERS (same
generator issue as ACCSTCD), so COST_CODE is read-only and the grid does not insert.

## Tests

Section C of `tmp\w3_gl\gl\t_gl.py`: next child under 101000000 = last level-3 code + 1000, no grant row written; a cost centre 2
used in posted lines cannot be deleted. Passed.

## Wave 3b

`rules.columns` `AC_COST_CENTERS2.COST_CODE: {"lov": null}` removes the wrong AC_COST_CENTERS list (the code is a plain read-only number).
Insert stays on the ADD button (the tree-insert rules are in `add_cost_center`). No legacy check box / list / radio item on this block.

## Coverage

As ACCSTCD.md: reproduced rules and the code column without the wrong list; tree, print, TRANSLATE not reproduced.
