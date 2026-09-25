# AR_SALESMAN_COMM_REV - مراجعة عمولات المناديب / Salesmen commissions review

- Registry: system 4. Legacy `ASCON\AR\FMB\AR_SALESMAN_COMM_REV.fmx` (2020-2021 version, no .fmb, no labels; evidence from the
  compiled strings). Blocks: CTRL_BLK (month, year, from / to date), SALESMAN (navigation), AR_CTGRY_SALESMAN (per department, computed
  totals), AR_COMM_PAY / AR_COMM_SALES / AR_COMM_AGES (month's commission lines, written by the DB procedure `GET_SALESMAN_COMM`),
  AR_COMM_PAY_ITEMS / AR_COMM_SALES_ITEMS. Data: salesman 103, February 2023 (182 payment lines, 61 ages lines).
- APEX: corrected from a grid on `AR_SALESMAN_COMM` to `MASTER_DETAIL`: master `SALESMAN` (read-only, the group's salesmen) with
  `AR_COMM_PAY`, `AR_COMM_SALES`, `AR_COMM_AGES` (joined on the salesman); no insert / delete on the page (lines come from the
  calculation, removed by the delete button); the commission percent / value are editable. Rules in `APP_RULES3_AR`.

## Rules and buttons

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| salesmen of the user's group | SALESMAN_LOV SQL | list `where` | high |
| salesman data not changed here | navigation block | row rule `readonly_master` | high |
| ACT_COMM_PRC -> ACT_COMM_VALUE = NET_VALUE x % / 100 and ACT_COMM_VALUE -> ACT_COMM_PRC (same for the sales ACT_S_*), highlighted when different from the original | item triggers with `:NET_VALUE`, SET_HIGHLIGHT | row rule `comm_value_row` (only for the user's saves on this page) | medium (formula from the three items) |
| button "إحتساب العمولة": "لم يتم اختيار مندوب لإحتساب العمولة", "تم احتساب العمولة للمندوب سابقا" (lines exist for the month), `GET_SALESMAN_COMM(code, month, year, first day, last day)` with the from date `TO_DATE('01' || LPAD(month,2,'0') || year)` | SQL, messages | action `CALC` (month / year parameters) -> `comm_calc` | high |
| button "حذف العمولة" (confirmation): "لم يتم اختيار مندوب لحذف العمولة"; deletes the month's AR_COMM_PAY_ITEMS, AR_COMM_PAY, AR_COMM_SALES_ITEMS, AR_COMM_SALES, AR_COMM_AGES | DELETE statements (verbatim) | action `DELETE_COMM` -> `comm_delete` | high |
| collected total (SUM(NET_VALUE) of AR_COMM_PAY), supervisor name | SQL | `info` panel (for the last calculated month), plus the payment / sales commission totals | medium |

## Tests (rolled back, 9 checks in batch 9 passed)

Percent -> value and value -> percent on a February 2023 line (column scale 2); requests of the calculation are left alone; salesman
read-only; calculation of an already calculated month refused; calculation / delete without salesman refused; info month and total;
delete removes the month's lines. The calculation itself (`GET_SALESMAN_COMM`) was not executed: the legacy procedure COMMITs after
each step, which a rolled-back test cannot allow.

## Coverage

- Reproduced: the review grids, the percent / value rule and the two buttons.
- Not reproduced: the department block `AR_CTGRY_SALESMAN` with its computed targets, age periods, penalties, bonus and the
  "إجمالي العمولة المستحقة للمندوب" (P40, COMPUTE_SALESMAN_DUE, AR_SALESMAN_COMM, SALESMAN_VIEW: a one-level master-detail cannot
  show a second level nor computed columns); the item lines (AR_COMM_PAY_ITEMS / AR_COMM_SALES_ITEMS, third level); the month filter
  of the detail blocks (no per-detail WHERE: filter the grids on COMM_MONTH / COMM_YEAR); the two prints
  (AR_SALESMAN_COMM.RDF, AR_SALESMAN_COMM_TOT.RDF: use the reports); the colours of SET_HIGHLIGHT.
- Note: `GET_SALESMAN_COMM` commits inside (legacy), so a calculation cannot be rolled back by the page.
- Questions: were the other line columns (WITHOUT_COMM_FLAG, OUT_COMM) editable in the review? APEX keeps them read-only.
