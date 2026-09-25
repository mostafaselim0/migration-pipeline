# ST_PRUCHASE_REQUEST: purchase requests (حركة طلب الشراء), registry 30/33

**Deliverable:** screen rules (pattern AUTO), `app\legacy\overrides\ST_PRUCHASE_REQUEST.json`, package `APP_RULES_SA`
(`prq_mast_row`, `prq_det_row`, `prq_validate`, `prq_after_save`); actions **TO_PO** and **TO_RFQ** (package `APP_CONV`,
`app\db\22_conv.sql`: `can_prq_to_order`, `prq_to_order`, `can_prq_to_rfq`, `prq_to_rfq`).
**Confidence:** medium (compiled .fmx strings; never used: tables empty, no types `EFFECT 7 / TRNS_TYPE 13` exist). The rules fix
two save blockers of the generated page (DATE_SERIAL and BASIC_QTY are NOT NULL and nothing filled them).

## Rules implemented
| # | Rule | Where | Evidence (ST_PRUCHASE_REQUEST.md) |
|---|---|---|---|
| F1 | List: purchase-request types (7/13) and group type rights (no FLAG condition); keeps asset requests of other types out | `where` | TRNS_TYPE LOV |
| N1 | TRNS_SERIAL / ITEM_SERIAL max + 1 (APPX, identical); **DATE_SERIAL = max + 1 per (store, request date)** | row rule | pre-insert SQL |
| D1 | Store of the type ("ادخل رقم المخزن" when none); request date today | row rule | type WVI |
| V1 | Offline-branch store refused (COMM_FLAG); date not future / ≥ ST_BASIC.MIN_DATE; store active / allowed | row rule, `prq_validate` | V1-V4 |
| L1 | Line: qty > 0; item active; basic unit; **BASIC_QTY = qty × factor**; supplier default ST_ITEM.SUPPLIER; header date / date serial copied | row rule | V6, V7, BASIC_QTY SQL |
| L2 | Lines linked to a purchase order (PR_ORDER_DET.REQ_*) or an RFQ (PR_REQ_DET.PR_*) cannot be changed (legacy messages) | row rule | line lock, KEY-DELREC messages |
| A1 | Items required (from the first save); line count ≤ TRNS_MAX_ITEMS; no repeated item when SINGLE_ITEM = 1 | `prq_after_save` | V5, V8-V10 |

## Conversion actions (implemented)
Legacy: buttons GEN_PUR_ORDER / PUSH_BUTTON268 ("عمل أمر شراء") and PR_QUOT ("عمل طلب عرض أسعار"), a date window (TRNS_DATE2) and two
anonymous blocks of the compiled form (symbol lists and SQL recovered from `ST_PRUCHASE_REQUEST.fmx`). APEX: action regions on the saved
purchase request with the parameters date (default today) and LINES (item codes or line serials of the chosen lines; the legacy
check box CHOOSE is not stored — empty = all lines). Shown when a line without a purchase order / without an RFQ exists.

**TO_PO ("عمل أمر شراء")**
| # | Rule | Evidence |
|---|---|---|
| O1 | Date required ("يجب ادخال التاريخ"), not before the request date ("يجب ان يكون تاريخ التحويل اكبر من تاريخ الطلب"), CHECK_DATE | TRNS_DATE2 WHEN-VALIDATE-ITEM |
| O2 | Order type = ST_TRNS_TYPE.PR_TRNS_TYPE of the request type, else "رقم نوع حركة المشتريات غير موجود" | `SELECT PR_TRNS_TYPE FROM ST_TRNS_TYPE ..` |
| O3 | Lines: chosen and not on a purchase order yet (no PR_ORDER_DET with REQ_* = the line); a line without supplier stops the conversion ("لا يوجد مورد للصنف") | symbols :CHOOSE, :PR_TRNS_TYPE, :SUPP_CODE |
| O4 | Per line: the open order of that type and supplier (CONFIRM_FLAG = 0 — and not closed, new: a closed order refuses lines) is reused, else a new PR_ORDER: TRNS_SERIAL max + 1, PR_ORDER_DATE = the date, currency of the supplier, AC_CURRENCY rate, CONFIRM_FLAG 0, REQUISITION_TYPE of the request; plus what the purchase-order screen fills for a new order: DOC_NO (next number), STORE_CODE (type store), CLOSE_FLAG 0, ST_SRV_ASST_FLAG 1, audit columns | `SELECT NVL(MAX(TRNS_SERIAL),0) FROM PR_ORDER WHERE .. CONFIRM_FLAG .. SUPPLIER_CODE`, INSERT PR_ORDER |
| O5 | PR_ORDER_DET: SERIAL max + 1, PR_ORDER_DATE = REQ_DATE = the date, item / group / unit / quantity, QTY_STATUS 1, REQ_SERIAL = REQ_ITEM_SERIAL = line serial, REQ_TRNS_TYPE_CODE / SERIAL, size, colour, VN_PRICE = retail price of the basic unit × unit factor (a price is required by the purchase-order line rule: "لابد من ادخال سعر الوحدة") | INSERT PR_ORDER_DET, `SELECT RETAIL_SALE_PRICE * NVL(:factor,1) FROM ST_ITEM_UNIT .. BASIC_UNIT = 1` |
| O6 | Nothing converted → "لم يتم عمل امر شراء"; else "تم عمل أمر شراء لعدد N صنف" (+ the list of orders in `app_conv.last_message`); the action opens the **first** order touched — several suppliers give several orders | .fmx texts |

**TO_RFQ ("عمل طلب عرض أسعار")**
| # | Rule | Evidence |
|---|---|---|
| Q1 | Date as O1; RFQ type = ST_TRNS_TYPE.QUOT_TRNS_TYPE, else "يجب ربط حركة طلب الشراء بحركة طلب عرض أسعار فى شاشة الحركات!!!" | `SELECT QUOT_TRNS_TYPE ..` |
| Q2 | Chosen lines not on an RFQ yet (no PR_REQ_DET with PR_* = the line); one PR_REQ_MAST for the run: TRNS_SERIAL max + 1, REQ_STATUS 1, PR_TRNS_* = the request, REQ_DATE = the date, REQ_DESC ' طلب عرض أسعار آلى محول من طلب مشتريات برقم' ‖ t/s, STORE_CODE of the request (+ audit users) | INSERT PR_REQ_MAST |
| Q3 | PR_REQ_DET: REQ_DET_SERIAL = PR_ITEM_SERIAL = line serial, item, group, quantity, unit, links, size, colour | INSERT PR_REQ_DET |
| Q4 | Nothing converted → "لم يتم عمل عرض اسعار"; else "تم عمل عرض أسعار لعدد N صنف"; opens the RFQ (PR_MR) | .fmx texts |

Also not reproduced in wave 2 (wave 3: display + delete messages, see the end of this file): the outstanding-PO confirm warning; services / assets tabs (no logic in the .fmx);
the Forms cascade that deleted ST_STORE_ITEM rows (a defect, must not be reproduced). Delete with links: handled in wave 3 by the line
delete trigger (legacy messages); the header delete now deletes the lines first (generator cascade) through the same trigger.

## Open questions
Migrate at all (0 rows, no types)? Approval before conversion (APPROVE_FLAG, USERS.MR_APPROVE)? REQUISITION_TYPE meaning? PO price
(legacy: retail sale price — rather the last purchase price?) Keep appending to the open order of the same supplier (legacy) or always a
new order? Should a line without supplier be skipped instead of stopping the conversion?

## Tests (ROLLBACK, temporary type 90013)
`t_misc.py` (purchase-request part): 6 checks + the RFQ-link lock.
`t_conv.py` (outside and inside a simulated APEX session, page 50191): can-flags, date before the request, request type without order /
RFQ type, line without supplier, two suppliers → two orders (header complete, line values, retail price, links, message with both
orders), nothing left on a second run, RFQ with the chosen line only, RFQ still possible for the other line — 14 checks.

## Wave 3 (delete messages, outstanding display)

| Legacy | APEX | Evidence / notes |
|---|---|---|
| line KEY-DELREC: "الحركة الحالية مرتبطة بحركة أمر شراء و لا يمكن الحذف" / "الحركة الحالية مرتبطة بحركة طلب عرض أسعار و لا يمكن الحذف" | BEFORE DELETE trigger `APP_ACT_PR_PRQ_DET_BD` on PR_ORDER_DET_REQUEST (APEX sessions) -> `app_act_pr.prq_line_delete` | replaces the FK errors (PR_ORDER_DET_ORDER_REQ_DET_FK4, PR_REQ_DET_PR_ORDER_REQ_DET_FK); header delete goes through the same hook (generated cascade) |
| CHK_OUTSTANDING_QTY "هناك كمية X من الصنف Y لم يتم إستلامها هل تريد الاستمرار" (all purchase orders of the item - all incoming lots) | `info` OUTSTANDING -> `app_act_pr.prq_outstanding` | .fmx SQL `SELECT NVL(SUM(QUANTITY),0) FROM PR_ORDER_DET WHERE GROUP_CODE / ITEM_CODE` and the lot sum |

Tests (build copy, all rolled back, plain and inside a simulated APEX session of app 100 with the regenerated APPX_ triggers; scripts in the job folder `tmp\w3_purch`: t_vn.py, t_po.py, t_lot.py, t_st.py, t_quot.py, t_reg.py; static check chk.py): outstanding 500 of item 101011226 shown, 0 for the others; deleting a line linked to a purchase order / an RFQ gives the legacy
messages in APEX (FK error outside APEX) - t_quot.py.

## Wave 3b
* Lists: TRNS_TYPE_CODE (purchase-request types 7/13 with type rights), REQUISITION_TYPE "نوع طلب الشراء" (list item
  REQUISITION_TYPE_DUMMY; the conversion copies it into PR_ORDER.REQUISITION_TYPE, whose legacy list is ST_PR_ORDER_TYPES), line units of
  the item (cascade), suppliers of the item / service / asset lines (active, VN_SUPPLIER_PASSWORD range).
* `rules.computed` on the item lines: ITEM_NAME_A and OUTSTANDING_QTY "كمية لم يتم إستلامها" = all purchase-order quantity of the item -
  all lot receipts (the .fmx CHK_OUTSTANDING_QTY SQL, same as `prq_outstanding`; item 101011226: 500 as in the wave-3 test).
* Delete: nothing to change — the line trigger gives the legacy messages and the generator now deletes the lines before the header.
* Check: `check_forms.py ST_PRUCHASE_REQUEST`.

## Coverage
Reproduced: request rules and conversions (wave 2), delete messages and outstanding display (wave 3); type /
order-type / supplier / unit lists, item name and outstanding quantity per line (wave 3b).

Not reproduced, with the reason: the per-line "continue?" of CHK_OUTSTANDING_QTY (grid-level warning needs a generator feature; shown
as a display and, since wave 3b, as the column "كمية لم يتم إستلامها" of each line); services / assets tabs (no logic in the .fmx); the Forms cascade that deleted ST_STORE_ITEM rows (defect).
