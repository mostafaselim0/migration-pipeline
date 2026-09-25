# ARCUSTGROUPS - خطوط سير المناديب / Customer Routes

- Registry: system 4 serial 37 (no menu name / order). Legacy `ASCON\AR\FMB\ArCustGroups.fmx` (no .fmb, no GN_FORM_ITEM labels).
- APEX: `overrides\ARCUSTGROUPS.json`, pattern `MASTER_DETAIL`, master `AR_CUSTOMER_GROUP_MAST`, detail `AR_CUSTOMER_GROUP_DET` on `GROUP_ID`
  (wave 1); wave 3 added the rules (`APP_RULES3_AR`). Confidence: high for the structure and rules, medium for `DAY_VISIT`.

## What the screen is

"خط سير عملاء مندوب": a salesman's route - customers with visiting order and weekday. The routes feed `AR_CREATE_DAY_SCHEDUAL` and the
"خط السير" button of AR_SLSMAN_SCHEDUAL (`VISIT_DAY = TO_CHAR(date, 'Dy')` in English).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| `GROUP_ID = NVL(MAX(GROUP_ID),0)+1` | embedded SQL | generated max+1 key | high |
| `CUSTOMER_ORDER = NVL(MAX(CUSTOMER_ORDER),0)+1 WHERE GROUP_ID` (default) | embedded SQL | row rule `route_det_row` (when empty) | high |
| salesman: `SALESMAN` with `NVL(STOP_FLAG,0) = 0`; routes of the user's salesmen only (`AR_SALESMAN_PASSWORD`) | LOV / block WHERE | row rule `route_mast_row` + `where` group filter | high |
| customer: active leaf customer of the route salesman (`NVL(STOPFLAG,0) <> 1 AND NVL(CUSTOMER_STATUS,0) = 1 AND CODE IN AR_CUST_SALESMAN of the salesman`) | customer LOV | row rule; `key_expr` makes the customer mandatory (the generated key would put max+1 in `CUSTOMER_ID`) | high |
| visit day stored as `Sat .. Fri` (read by the scheduling procedures), shown in Arabic (السبت .. الجمعة) | list texts, `AR_CREATE_DAY_SCHEDUAL`, CUSTOMER POST-QUERY mapping | row rule normalises `VISIT_DAY` and derives `DAY_VISIT` (read-only) | medium |

## Tests (rolled back)

Customer required; visit order 1; `sat` -> `Sat` / السبت; wrong day refused; unknown salesman refused (batch 1).

## Coverage

- Reproduced: numbering, order default, salesman / customer filters, visit-day values.
- Not reproduced: lists of values on `SALESMAN_ID` / `VISIT_DAY` (generator has no per-column LOV / static list override: the values are
  validated instead). `DAY_VISIT` = Arabic day name is our reading of the unexplained second day column (question for the key user).
