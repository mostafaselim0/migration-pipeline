# AC_QUERYBEFORE - إستعلام عن رصيد حساب قبل الترحيل / Query for Account Balance before Posting

- Registry: system 1 serial 51 (QUERY_MENU.AC_QUERYBEFORE, order 3001). APEX page 10170.
- Legacy module: `ASCON\AC\FMB\ac_queryBefore.fmx` (no .fmb): one non-database block (account, cost centres 1 / 2, date, balance,
  مدين / دائن, account currency).
- **Deliverable: screen correction to a query page.** The generator made an editable grid on AC_YEARLY_TRN_DET (posted lines could be
  changed there). Override `app\legacy\overrides\AC_QUERYBEFORE.json`: pattern `PROCESS` with the query fields as parameters, the
  "استعلام" button (APP_RULES3_GL.query_balance checks the fields) and the result below.
- **Confidence: high** (GET_BAL SQL of the .fmx).

## Rules

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | Balance = posted lines (AC_YEARLY_TRN_DET, entry date <= date) + daily lines (AC_DAILY_TRN_DET, entry date <= date) + opening balance (AC_OPENING_BALANCE_DET), for the account and the cost centres given (a cost centre left empty = all) | GET_BAL: the three SUMs with `(NVL(COST_CODE,0) = NVL(:b2,0) OR :b2 IS NULL)` | `app_rules3_gl.account_balance(..., p_unposted => 1)` in the result query |
| 2 | Shown as absolute value with مدين (>= 0) / دائن (< 0) and the account currency | GET_BAL texts, currency SQL | result columns |
| 3 | Account list: sub accounts granted to the group; cost centre lists: active cost centres granted to the group | ACCOUNT_LOV, COST_CENTERS_LOV, COST_CODE2 LOV | parameter lists of values; `query_balance` refuses a main account ("الحساب ليس حساب فرعى") or an account of another group |

## Tests (section K of `tmp\w3_gl\gl\t_gl.py`)

Balance with the daily lines = balance after posting + a temporary daily line (123.45); account required, main account refused,
debit / credit text. Passed.

## Wave 3b

`proc.run_right: "query"`: the query button now needs only the page (query) right, as the legacy query screen (no data is written).
Checked: the account / cost-centre name display items are shown by the parameter lists; the TRANSFER / EXIT buttons are Forms-only.

## Coverage

- Reproduced: rules 1-3; query button with the query right (wave 3b).
- Not reproduced: the name display items as separate fields (the lists of values show the names).
