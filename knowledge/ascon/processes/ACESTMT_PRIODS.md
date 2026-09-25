# ACESTMT_PRIODS - فترات الموازنة التقديرية / Estimated Budget Periods

- Registry: system 1 serial 8 (المـوازنـة_التقـديريـة_MENU.ACESTMITPRID, order 1201). APEX grid page 10050.
- Legacy module: `ASCON\AC\FMB\acestmt_priods.fmx` (no .fmb; labels of block AC_ESTIMATE_PERIODS).
- **Deliverable: generated grid kept (`AUTO`) + rules**, override `app\legacy\overrides\ACESTMT_PRIODS.json`, PL/SQL `APP_RULES3_GL`,
  statement trigger `APP_RULES3_GL_ESTP_AS`.
- **Confidence: high** (messages and SQL); the table is empty on the build copy.

## Rules

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | List restricted to the periods of the group | block WHERE `:1 = 0 OR PERIOD_CODE IN (SELECT PERIOD_CODE FROM AC_PASSWORD_EST_PERIOD WHERE PASSWORD_NUMBER = :2 AND COMPANY_CODE = :3)` | `where` |
| 2 | Period number unique ("كود مكرر") and not negative ("رقم الفترة لا يمكن أن يكون أقل من الصفر") | CHECK_UNIQ, PERIOD_CODE validation | PK + row rule `est_period_row`; number = MAX + 1 when left empty (key_expr) |
| 3 | From date not before AC_BASIC.MIN_DATE ("التاريخ أقل من الحد الأدنى المسموح به") | VALIDATE_DATE (PARAMETER.MIN_DATE from AC_BASIC) | row rule |
| 4 | From date before to date ("يجب ان يكون من تاريخ اصغر من الى تاريخ") | FROM_DATE / TILL_DATE validation | row rule |
| 5 | Periods do not overlap ("يوجد تقاطع فى نطاق التواريخ مع نطاق أخر") | `SELECT COUNT(1) FROM AC_ESTIMATE_PERIODS WHERE (:b1 BETWEEN FROM_DATE AND TILL_DATE OR :b2 BETWEEN ...)` | after-statement trigger (the check reads the whole table); the period itself is excluded (the legacy count did not exclude it and so refused any change of an existing period's dates) |

## Tests (section G of `tmp\w3_gl\gl\t_gl.py`, 8 checks)

Period 1 numbered automatically; overlap, from after till, before MIN_DATE, negative number refused; second period accepted; an
update into an overlap refused. Passed.

## Wave 3b

`rules.columns` `AC_ESTIMATE_PERIODS.PERIOD_CODE: {"lov": null}` removes the wrong ST_PERIODS list: the period number can be typed again, as in
the legacy (the labels show a plain text item [T]); when left empty it is still numbered MAX + 1. No check box / list / radio item on this block.

## Coverage

- Reproduced: rules 1-5; the typed period number (wave 3b).
- Not reproduced: "تاريخ الفترة أكبر من المسموح بة" (TILL_DATE validation compares with a value the .fmx does not show).
