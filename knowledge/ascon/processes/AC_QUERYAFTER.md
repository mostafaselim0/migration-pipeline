# AC_QUERYAFTER - إستعلام عن رصيد حساب بعد الترحيل / Query for Account Balance after Posting

- Registry: system 1 serial 52 (QUERY_MENU.AC_QUERYAFTER, order 3002). APEX page 10180.
- Legacy module: `ASCON\AC\FMB\ac_queryAfter.fmx` (no .fmb), same layout as AC_QUERYBEFORE.
- **Deliverable: screen correction to a query page** (the generated editable grid on AC_YEARLY_TRN_DET was wrong). Override
  `app\legacy\overrides\AC_QUERYAFTER.json`: pattern `PROCESS`, parameters account / cost centres / date, result below.
- **Confidence: high.**

## Rules

As AC_QUERYBEFORE.md without the daily lines: balance = posted lines up to the date + opening balance (GET_BAL of this form has
only the AC_YEARLY_TRN_DET and AC_OPENING_BALANCE_DET sums), `app_rules3_gl.account_balance(..., p_unposted => 0)`. The account and
cost-centre lists of this form also accept everything under a granted main account (RPAD by ACCOUNT_END_POS / COST_END_POS).

## Tests

Section K of `tmp\w3_gl\gl\t_gl.py`: after-posting balance of 310101001001 at 30/06/2026 = posted + opening computed independently;
with cost centre 102002000. Passed.

## Wave 3b

`proc.run_right: "query"`: the query button needs only the page (query) right (a display screen, nothing is written).

## Coverage

As AC_QUERYBEFORE.md: rules reproduced, query button with the query right; the names are shown by the parameter lists.
