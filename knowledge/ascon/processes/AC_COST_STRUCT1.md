# AC_COST_STRUCT1 - هيكل مركز التكلفة 1 / Structure of Cost Center 1

- Registry: system 1 serial 77 (CODES_MENU.AC_COST_STRUCT1, order 2004). APEX grid page 10110.
- Legacy module: `ASCON\AC\FMB\ac_Cost_Struct1.fmx` (no .fmb; GN_FORM_ITEM labels on block COST_STRCTURES).
- **Deliverable: generated grid kept (`AUTO`) + rules.** Override `app\legacy\overrides\AC_COST_STRUCT1.json`, PL/SQL `APP_RULES3_GL`.
- **Confidence: high** (same form family as AC_MASTER_STRUCT, SQL restricted to `COST_CENTER_NUMBER = 1`).

## What the screen is

The levels of the 9-digit code of cost centres 1: `AC_COST_STRCTURES` rows with `COST_CENTER_NUMBER = 1` (4 levels: 1 / 2 / 3 / 3
digits). The same table holds structure 2 (AC_COST_STRUCT2), so the page filters `COST_CENTER_NUMBER = 1` and new rows get the
number from the screen they are entered on.

## Rules

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | Structure locked while cost centres 1 exist, only the names may change ("لا يمكن تعديل بيانات هيكل مراكز التكلفة أثناء وجود بعض الحركات ولكن يمكن تعديل اسم المركز فقط"; delete: "لا يمكن حذف السجلات") | `SELECT COUNT(COST_CODE) FROM AC_COST_CENTERS` + texts | row rule `cost_struct_row`; delete hook `APP_RULES3_GL_COSTSTR_DEL` |
| 2 | Structure number of the screen (1) | all SQL `WHERE COST_CENTER_NUMBER = 1` | `where` + key_expr `cost_struct_no` (1 on this page, from APP_PAGE_MAP) |
| 3 | Level = MAX + 1, start = MAX(end) + 1 of this structure | `SELECT NVL(MAX(COST_STR_END),0) / MAX(COST_STR_LEVEL) ... WHERE COST_CENTER_NUMBER = 1` | key_expr `next_cost_level`, row rule |
| 4 | Name required ("برجاء إدخال اسم المستوي"), end >= start and <= 9 ("... و كذلك كونه أقل من 9"), length = end - start + 1 | item validations | row rule; LENGTH read-only |
| 5 | Delete from the bottom up ("يجب حذف السجلات من أسفل إلي أعلي") | PRE-DELETE `SELECT MAX(COST_STR_LEVEL)` | after-statement check of the delete hook |

## Tests (section A of `tmp\w3_gl\gl\t_gl.py`)

Locked structure 1 refused a new level; with the test switch: level 4 deleted and re-entered from page 10110 got number 1,
level 4, start 7, length 3; end 10 refused. Passed.


## Wave 3b

Checked: no check box / list / radio item. SUM_STR / REST_STR (إجمالي عدد الحقول التي تم تخصيصها / عدد الحقول المتبقية) are totals over all levels, not per-row values, so `rules.computed` does not fit them; still not reproduced.

## Coverage

- Reproduced: rules 1-5.
- Not reproduced: "إجمالي عدد الحقول التي تم تخصيصها / عدد الحقول المتبقية" displays and the "structure incomplete" exit warning
  (grid limits, see AC_MASTER_STRUCT.md); TRANSLATE button (Forms prompt translation).
