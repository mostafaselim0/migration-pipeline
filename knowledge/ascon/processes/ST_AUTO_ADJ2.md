# ST_AUTO_ADJ2 - تسوية اعادة تقييم تكلفة المخزون / Auto Stocktaking Adjustment (revaluation)

- Registry: system 3 serial 523 (`FILES_MENU.AUTO_ADJ`). Legacy module `ASCON\ST\FMB\ST_AUTO_ADJ2.fmx` (no .fmb); twin of
  `ST_AUTO_ADJ` (ported in wave 2 as `APP_PROC_ST.auto_adjust`), working on the revaluation count `ST_STOCK_TAKING_TEMP` /
  `ST_STOCK_TAKING_TEMP_DET` (entered in ST_TAKING2) instead of `ST_STOCK_TAKING`.
- APEX: `PROCESS` page 20490 (override `ST_AUTO_ADJ2.json`), button "عمل التسوية" with a confirmation; procedure
  `APP_RULES3_ST.auto_adjust2`, preview `APP_RULES3_ST.auto_adj2_lines` (lines still to adjust, with book balance, counted quantity,
  difference, cost and the error flag).
- Confidence: high (all DML statements are in the .fmx and copied), except the points under "Open questions".

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| store: active transaction stores of the user group; block WHERE `(:1=0 OR STORE_CODE IN (SELECT DISTINCT STORE_CODE FROM ST_ALL_STORE_PASSWORD WHERE PASSWORD_NUMBER=:2))` | LOV + block WHERE | store list of values; "ليس لديك صلاحية على هذا المخزن" in `auto_adjust2` | high |
| count serial of the store and date: `select t.serial, t.desc_a from st_stock_taking_temp t where t.st_taking_date = :date and t.store_code = :store` | LOV SQL | SERIAL list of values; "لا يوجد جرد لهذا المخزن فى هذا التاريخ" | high |
| issue type: `EFFECT = 2 AND TRNS_TYPE = 7 AND (STORE_CODE = :store OR STORE_CODE IS NULL)` + user types; receipt type: `EFFECT = 1 AND TRNS_TYPE = 7 ...` | LOV SQL | lists of values; "حركة الصادر للتسوية الأليه غير صحيحة" / "حركة الوارد للتسوية الأليه غير صحيحة" (same texts as ST_AUTO_ADJ) | high |
| "يجب ادخال كود وارد وصادر التسوية الالية" | message | `auto_adjust2` | high |
| lines = `SELECT DISTINCT GROUP_CODE, ITEM_CODE, ITEM_CONFG_ID, SERIAL FROM ST_STOCK_TAKING_TEMP_DET WHERE STORE_CODE, ST_TAKING_DATE, SERIAL MINUS SELECT GROUP_CODE, ITEM_CODE, ITEM_CONFG_ID, M.SERIAL_TAKING_TEMP FROM ST_TRNS_MAST M, ST_TRNS_DET D WHERE .. NVL(M.DELETE_FLAG,0) = 0` | embedded SQL | `build_adj2` (same MINUS, same columns - no store / date condition, as the legacy) | high |
| counted cost / quantity `AVG(UNIT_COST), SUM(BASIC_QTY)` per lot; basic unit and factor ("خطأ بوحدة الصنف"); book balance at the count date (`GET_BALANCE_COST_CONFG`) | embedded SQL, message | `build_adj2` | high |
| issue the book balance: one issue document (`TRNS_SERIAL` / `DATE_SERIAL` = max + 1, `INVOICE_NO` = type || serial, description ' إعادة تقييم للجرد اليا بتاريخ ' date, `SERIAL_TAKING_TEMP`), lines at the counted cost; a negative book balance is received instead (`ABS(..)`) | INSERT statements | `auto_adjust2` | high |
| a line whose issue makes a later transaction negative (`SELECT COUNT(D.ITEM_SERIAL) .. later documents`, `UPDATE_NEXT_TRNS`) goes to `ST_AUTO_ADJ_ERR2` and is skipped; message "توجد بعض الحركات يوجد لها حركات تالية تتعارض معها." | SQL + message | `auto_adjust2` (same check as ST_AUTO_ADJ), `adj_error` column | high |
| receive the counted quantity at the counted cost (`UNIT_PRICE = cost * factor`), receipt `DOC_NO` = issue type || issue serial, skipping the error lines | INSERT statements | `auto_adjust2` | high |

Tested (rolled back, `t_rules3_st.py` K1-K4, with a revaluation count built on store 101010101001): the preview lists the two counted
lots with book balance - 1; receipt type check and "no count" refused; "عمل التسوية" creates issue 11301 + receipt 11401 linked by
`SERIAL_TAKING_TEMP`, the lot balances become the counted quantities, the receipt is at the counted cost 7.5, and the lines are no
longer listed. The test consumes values of `ST_TRNS_MAST_DATE_SERIAL` (taken by the legacy trigger `ST_TRNS_MAST_IN`, not rolled back).

## Printing

"عرض أخطاء التسوية الالية" runs `ST_AUTO_ADJ_ERR2.RDF` (parameter LANG only; `SELECT STORE_CODE, TRNS_DATE, SERIAL, GROUP_CODE, ITEM_CODE,
UNIT_CODE, QUANTITY, BASIC_QTY FROM ST_AUTO_ADJ_ERR2`). In APEX the error lines are the rows with "خطأ تسوية" = 1 in the preview; the
report layout is the main session's.

## Open questions

- The .fmx binds the issue header's `CURRENCY_RATE` to the same variable as `DATE_SERIAL` (`VALUES (:b1, :b2, :b3, .., :b3, ..)`);
  APEX uses 1 (as ST_AUTO_ADJ). Confirm.
- The legacy MINUS ignores store and date: a lot adjusted once under count serial N (any store / date) is hidden from every later count
  with the same serial N (serials restart per store and date). Reproduced as is; suggestion: also match store and date.

## Coverage

- Reproduced: selection lists and checks, the list of lines, the issue / receipt documents with all legacy columns, the conflict check
  and the error table, the message.
- Not reproduced: per-line selection "تسوية اليه" with "اختيار الكل / استبعاد الكل" (a preview has no check boxes: replaced by the
  optional group / item filter; generator gap); colour / size columns (`ST_BASIC` flags 0); the error report layout (main session).
