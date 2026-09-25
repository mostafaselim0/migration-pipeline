# ST_TRANSFER_TO — receive transfer (شاشة استلام التحويلات)

System 3 serial 102 (FILES_MENU.ST_TRANSFER_TO). Source: compiled form only (`ST\FMB\ST_TRANSFER_TO.fmx`, evidence
`app\legacy\evidence\ST_TRANSFER_TO.md`). Deliverable: **(a) screen kept (AUTO) + rules** (`overrides\ST_TRANSFER_TO.json`,
`APP_RULES_ST`).

## Purpose and data

Receives into STORE_CODE (the destination) a transfer issued by ST_TRANSFER_FROM: the header references the ST_TRNSFER row
(TRNSFER_SERIAL + TRNSFER_FROM_STORE, FK TRNS_MAST_ST_TRNSFER_FK); the lines are the issued lines (lot, quantity, cost).

Types (block WHERE of the .fmx): `TRNS_TYPE_CODE IN (SELECT .. WHERE (T.EFFECT = 6) AND (T.TRNS_TYPE IN (9))) AND DELETE_FLAG=0
AND (:1=0 OR (TRNS_TYPE_CODE IN (SELECT .. FROM ST_TRNSTYPE_PASSWORD ..)))` → 11201 / 11202 / 11203. Data: 11201 = 32 documents
(most created by the automatic receipt of ST_TRANSFER_FROM, some manual with the transfer's DOC_NO), one active receipt per
transfer.

## Rules implemented

| # | Rule | Where | Evidence |
|---|------|-------|----------|
| 1 | List filter EFFECT 6 / TRNS_TYPE 9, DELETE_FLAG = 0, group types | `rules.where` | block WHERE |
| 2 | Type of the screen for new documents (TRNS_TYPE LOV, no FLAG condition) | `val_trns` | LOV `WHERE EFFECT = 6 AND TRNS_TYPE = 9 AND (...)` |
| 3 | Defaults: type 11201, store = type store, flags 0 | `rules.defaults` | as ST_TRANSFER_FROM |
| 4 | TRNSFER_SERIAL + TRNSFER_FROM_STORE required; the transfer must exist, not deleted, APPROVE_FLAG = 1, addressed to this store (TRNSFER_TO_STORE = STORE_CODE), dated on/before the receiving date, and not received yet | `val_trns` | LOV `FROM ST_TRNSFER WHERE TRNSFER_RECEIVING_DATE IS NULL AND NVL(DELETE_FLAG,0)=0 AND APPROVE_FLAG = 1 AND TRNSFER_TO_STORE = :STORE_CODE AND TRNSFER_DATE <= :TRNS_DATE`; messages "مسلسل التحويل غير موجود", "تم استلام هذا التحويل من قبل", "تاريخ الاستلام أصغر من تاريخ التحويل" |
| 5 | Source store ≠ receiving store | `val_trns` | LOVs |
| 6 | Transfer cannot be changed once lines exist | `val_trns` | "لا يمكن تغيير رقم التحويل ويوجد تفاصيل" |
| 7 | On insert: TRNSFER_TYPE 1, TRNSFER_TO_STORE := STORE_CODE, DOC_NO := ST_TRNSFER.TRNSFER_DOC_NO and DESC_A := TRNSFER_DESC_A when empty; ST_TRNSFER.TRNSFER_RECEIVING_DATE := TRNS_DATE | `mast_row` | `UPDATE ST_TRNSFER SET TRNSFER_RECEIVING_DATE = :b1 WHERE ...`; data (manual receipts carry the issue DOC_NO, TRNSFER_TYPE 1) |
| 8 | Date change → receiving date follows; transfer change (no lines) → old transfer released, new one stamped | `mast_row` (update) | same UPDATE statements |
| 9 | CREATE: the issued lines are copied into the receipt (lot, unit, quantity, basic quantity, UNIT_COST of the issue, UNIT_PRICE = cost × factor, COST_FLAG 1) | `after_trns` → `copy_transfer_lines` | detail load `SELECT GROUP_CODE, ITEM_CODE, UNIT_CODE, DOC_NO, DESC_A, QUANTITY, UNIT_COST, ITEM_CONFG_ID, ITEM_SERIAL, BASIC_QTY FROM ST_TRNS_MAST MT, ST_TRNS_DET DET WHERE .. TRNSFER_SERIAL = :b1 AND TRNSFER_FROM_STORE = :b2 AND .. EFFECT = 5`; auto-receipt INSERT; data 387/408 lines UNIT_PRICE = cost |
| 10 | Received lot must be part of the transfer; received quantity per lot ≤ transferred quantity (partial receipt allowed); empty lot → first lot of the item still to receive | `det_row` | `SELECT SUM(QUANTITY) .. EFFECT IN (5) .. ITEM_CONFG_ID = :b5`; "تم إستلام التحويل وتوجد أصناف غير مطابقة" |
| 11 | Quantity > 0, group / unit / BASIC_QTY derived, item not stopped | `det_row` | "الكمية يجب ان تكون أكبر من صفر" |
| 12 | Deleting / reducing a receipt line must not make a later transaction of the lot negative | `det_row`, `APP_RULES_ST_DET_BD` | UPDATE_NEXT_TRNS_CONFG in the detail delete logic |
| 13 | Posted document read-only; CHECK_DATE; store allowed; account when STACLNK type 6 (not the case for 112xx) | `val_trns`, triggers | as ST_TRANSFER_FROM |
| 14 | Lines required at SAVE | `after_trns` | "لا يمكن حفظ الحركة بدون تفاصيل" (library pattern) |
| 15 | Delete (wave 3: **soft delete**, see W1): ST_TRNSFER.TRNSFER_RECEIVING_DATE cleared (the transfer is pending again); a physical delete outside the page still goes through `APP_RULES_ST_MAST_BD` | `rules.soft_delete` + `trt_after_delete` | `UPDATE ST_TRNSFER SET TRNSFER_RECEIVING_DATE = NULL WHERE ...` |
| 16 | DOC_NO duplicate check only when ST_BASIC.DOC_REPEAT = 0 | `val_doc_no` | `.. EFFECT = 6 AND TRNS_TYPE = 9 AND TM.DOC_NO = :b2 AND TRNSFER_FROM_STORE = :b3 ..` |

## Wave 3: delete, questions and displays (APP_ACT_ST, `trt_*` / `trf_status`)

| # | Legacy behaviour | APEX | Evidence | Confidence |
|---|---|---|---|---|
| W1 | Master KEY-DELREC is a **soft delete** (`:ST_TRNS_MAST.DELETE_FLAG := 1`, lines kept and flagged by ST_TRNS_MAST_UP); each line first passes the detail KEY-DELREC check: removing the received quantity must not make a later movement of the lot negative (GET_BALANCE_CONFG + UPDATE_NEXT_TRNS_CONFG) → "الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها."; posted → refused | `rules.soft_delete` (lines keep, check `trt_delete_check`: posted, then the running balance of every lot without this receipt) | trigger symbols `:PARAMETER.MASTER_DELETE`, `:ST_TRNS_MAST.DELETE_FLAG`, `TRNSFER_SERIAL / TRNSFER_FROM_STORE`; detail trigger `V_BALANCE`, `UPDATE_NEXT_TRNS_CONFG`; data: 6 deleted 11201 receipts kept 87 lines with DELETE_FLAG 1 | high |
| W2 | After the delete: `UPDATE ST_TRNSFER SET TRNSFER_RECEIVING_DATE = NULL WHERE TRNSFER_SERIAL = .. AND TRNSFER_FROM_STORE = ..` | `after_save` DELETE → `trt_after_delete` | .fmx SQL; data: receiving date empty for the transfers whose receipts were deleted | high |
| W3 | DOC_NO: DOC_REPEAT = 1 → "رقم المستند مكرر" / "هل تريد الإستمرار" (same type, EFFECT 6 / TYPE 9, same TRNSFER_FROM_STORE, not deleted) | `warnings` → `trt_doc_warn` | .fmx SQL `.. AND TM.DOC_NO = :b2 AND TRNSFER_FROM_STORE = :b3 ..`, texts | high |
| W4 | Displays QTY_TOTAL "اجمالى الكمية", TOTAL_LINE "الإجمالى"; receipt against the transfer (matching / not matching) | `info` QTY / TOTAL (`trt_totals`), STATUS (`trf_status`, the same text as on the issue screen) | labels; DEF_QUANTITY SQL of the issue screen | medium (TOTAL = Σ QUANTITY × UNIT_PRICE) |

Automatic receipts (ST_BASIC.AUTO_TRANSFER) are created from the issue screen (ST_TRANSFER_FROM action AUTO_REC) and open on this page.

## Tests (build copy, all rolled back; `tmp\w3_sales\f4\t_f4.py`)

B1 soft delete of a receipt (header / lines / cost rows flagged, transfer pending again, issue deletable afterwards); B2 duplicate DOC_NO
question per source store; B3 totals; B4 posted receipt refused; B5 receipt whose lot was issued afterwards refused; R2 manual receipt on
page 20021 (transfer DOC_NO, TRNSFER_TYPE 1, receiving date, lines copied); R3 received quantity above the transferred quantity; wave-2
tests D1-D7 above.

## Confidence: **medium-high**

The .fmx SQL gives the conditions exactly; copying the lines at CREATE reproduces the legacy detail load (the user then
adjusts the received quantities in the grid).

## Human verification

1. (done in wave 3b) TRNSFER_SERIAL / TRNSFER_FROM_STORE have the legacy lists of pending transfers (was:
   `select trnsfer_serial r, trnsfer_serial || ' - ' || s.name_a || ' - ' || to_char(trnsfer_date,'DD/MM/YYYY') d from st_trnsfer t, st_store s
    where t.trnsfer_receiving_date is null and nvl(t.delete_flag,0) = 0 and t.approve_flag = 1 and t.trnsfer_from_store = s.store_code`).
2. Confirm that partial receipts are acceptable (legacy displayed "توجد أصناف غير مطابقة" but did not block).

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Transfer list: pending approved transfers addressed to the receiving store (serial - issuing store - date), refreshed with the store | `TRNSFER_SERIAL` `lov` + `cascade: STORE_CODE` | legacy LOV `FROM ST_TRNSFER WHERE TRNSFER_RECEIVING_DATE IS NULL AND NVL(DELETE_FLAG,0)=0 AND APPROVE_FLAG = 1 AND TRNSFER_TO_STORE = :STORE_CODE ...` (question 1) |
| Issuing store list of the chosen transfer | `TRNSFER_FROM_STORE` `lov` + `cascade: [TRNSFER_SERIAL, STORE_CODE]` | same LOV (it returned serial and store) |
| Per line: item name, lot expiry, lot balance in the receiving store before the line "رصيد المخزن", lot average cost "متوسط تكلفة الصنف" | `computed.ST_TRNS_DET.*` | display items and labels |
| Lot list of the line's item (lot id - lot number - expiry), refreshed when the item changes | `ITEM_CONFG_ID` `lov` + `cascade: ITEM_CODE` | legacy lot LOV (ITEM_CONFG_LOV / CONFG); the row rule still checks the lot and its balance |
| Button "ترحيل السند" opens the posting screen ST_POSTING_CPOSTING with the document's type, serial and date filled in (from / to) | `links` | POST_BUT: `CALL_FORM(... 'ST_POSTING_CPOSTING' ...)` with TRN_CODE / TRN_SER / TRN_DATE |

Costs are empty unless (USERS.ALLOW_VIEW_COST = 1 and ST_BASIC.SHOW_COST = 1) or the user's group is 0 (legacy GET_USER_SEC); the column itself stays visible (the generator cannot hide a column per user right). The legacy button chose post (FILTER 1) or cancel (FILTER 2) from POST_FLAG; the link cannot set a value that depends on the record, so the operation stays the posting page's default (post) and the user switches it to cancel when needed. The date condition of the transfer LOV (`TRNSFER_DATE <= :TRNS_DATE`) is left to the validation `val_trns` (a list
cannot depend on a date typed on the page without the page number). Tested on the build copy: every list query and computed expression runs (`tmp\w3b_st\sqlcheck.py`, lot list with item 101010006); the cost / balance gates checked in an APEX session (`t_gates.py`, rolled back, session removed).

## Coverage

Reproduced: rules 1-16 and W1-W4 (transfer link and receiving date, copy of the issued lines, received ≤ transferred per lot, balance
of later movements, soft delete, duplicate DOC_NO question, totals and receipt status).

Not reproduced, on purpose:
- Cost-sharing fields (FREIGHT_VAL, CUSTOMS_VAL, TRNSPORT_VAL, INSURANCE_VAL, COMMISSION_VAL, OTHERS_VAL and the per-line NDB_* shares,
  tab "تكــاليف الحـركــة"): the form only shows / hides them by ST_TRNS_TYPE.HAS_* (all 0 for 11201-11203) and computes display-only
  shares; no allocation SQL exists in the .fmx; the stored allocation is the separate process ST_DIST_COST
  (`APP_PROC_ST.dist_transfer_cost`). Data: no transfer document has a cost value. The header fields stay plain fields.
- TOTAL_AFTER "الصافي": formula not recoverable from the compiled form (no cost values are ever set, so it equals the total).
- Forms-only mechanics: alerts, IDENTICAL_RECEIVING / UNIT_NAME2 per-line displays, print buttons (prints agent), navigation. Wave 3b
  added the per-line balance / cost / names and the posting button.
