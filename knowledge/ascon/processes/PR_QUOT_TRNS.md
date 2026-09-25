# PR_QUOT_TRNS: supplier quotations (إستلام عروض أسعار الموردين), registry 30/35

**Deliverable:** screen rules (pattern AUTO), `app\legacy\overrides\PR_QUOT_TRNS.json`, package `APP_RULES_SA`
(`quot_mast_row`, `quot_det_row`, `rfq_validate`, `quot_after_save`).
**Confidence:** medium for the rules (compiled .fmx strings; never used); **low usability of the generated page**: the price grid
PR_QUOT_DET has no item column (its link REQ_DET_SERIAL is hidden) and is placed directly under the RFQ header (all suppliers' lines
together). A human should decide on a screen correction (e.g. MASTER_DETAIL on PR_QUOT_MAST → PR_QUOT_DET joined on type, serial,
supplier, plus a view with the item of PR_REQ_DET).

## Rules implemented
| # | Rule | Where | Evidence (PR_QUOT_TRNS.md) |
|---|---|---|---|
| F1 | List: RFQ types, group rights (FLAG 1), RFQs that have at least one supplier (legacy worklist) | `where` | block WHERE / FILL_REQ_LIST |
| S1 | Supplier quotation header rules as in PR_MR (QUOT_SERIAL, currency, discount ≥ 0, DATE_SEND on accept, not before the request date and not in the future, locked once a PO exists) | row rule PR_QUOT_MAST | Q1, Q3 |
| L1 | Price line must match an RFQ line and a supplier of the RFQ (users cannot add lines: the generated max+1 serial is refused); prices only when the supplier's reply flag is ticked; price > 0; line discount ≤ qty × price; arrival date ≥ request date and ≥ PO date; colour / size by group flags; no change once a PO exists | row rule PR_QUOT_DET | Q5-Q9, line lock |
| A1 | Price lines generated for replying suppliers; prices cleared when the reply flag is removed (legacy with a confirmation); only one accepted supplier ("هناك عرض تم إختياره بالفعل"); header discount ≤ quotation total; arrival dates ≥ DATE_SEND; REQ_STATUS 1 ↔ 2 by replies, 3 when a supplier is accepted, back to 2 when un-accepted | `quot_after_save` | reply sync, accept / un-accept SQL, Q2, Q4 |

## Not reproduced (process buttons) - wave 2
> Wave 3: the three buttons are implemented now (APP_ACT_PR), see "Wave 3" at the end of this file.
Lowest-price automatic choice (GET_LOWEST_PRICE), create purchase order from the accepted quotation, delete PO — they write the
purchasing team's documents. Legacy SQL (compiled .fmx) for a future process page:
```sql
-- create PO ("تكوين أمر الشراء"): checks = saved, supplier accepted, no PO yet, ST_TRNS_TYPE.PR_TRNS_TYPE of the RFQ type set
-- ('يجب ربط طلب عروض الأسعار بحركة أمر شراء في ملف الحركات!!!'), DATE_SEND set, at least one priced line
SELECT NVL(MAX(NVL(TRNS_SERIAL,0)),0)+1 FROM PR_ORDER WHERE TRNS_TYPE_CODE = :po_type
INSERT INTO PR_ORDER (TRNS_TYPE_CODE, TRNS_SERIAL, PR_ORDER_DATE, CURRENCY_CODE, CURRENCY_RATE, SUPPLIER_CODE, SUPP_QUOT_NO, DISC_VAL, REQUISITION_TYPE)
VALUES (:po_type, :serial, :date_send, :currency, :rate, :supplier, :quot_no, :disc_val, :requisition_type_of_the_request)
INSERT INTO PR_ORDER_DET (TRNS_TYPE_CODE, TRNS_SERIAL, SERIAL, PR_ORDER_DATE, GROUP_CODE, ITEM_CODE, UNIT_CODE, QUANTITY, VN_PRICE, QTY_STATUS,
       REQ_SERIAL, REQ_DATE, EXPCT_ARRIVAL_DT, QUOT_TRNS_TYPE_CODE, QUOT_TRNS_SERIAL, QUOT_ITEM_SERIAL, QUOT_SUPPLIER_ID, BONUS, DET_DISC, DISC)
SELECT :po_type, :serial, RD.REQ_DET_SERIAL + NVL(:max_serial,0), :date_send, RD.ITEM_GROUP_CODE, RD.ITEM_CODE, RD.UNIT_CODE, RD.QUANTITY,
       QD.UNIT_PRICE, 1, RD.REQ_DET_SERIAL, :date_send, QD.EXP_ARRV_DATE, QD.TRNS_TYPE_CODE, QD.TRNS_SERIAL, QD.REQ_DET_SERIAL,
       QD.SUPPLIER_ID, QD.BONUS, QD.DET_DISC, QD.DISC
  FROM PR_QUOT_DET QD, PR_REQ_DET RD
 WHERE <join on TRNS_TYPE_CODE, TRNS_SERIAL, REQ_DET_SERIAL> AND QD.SUPPLIER_ID = :supplier AND QD.UNIT_PRICE IS NOT NULL
UPDATE PR_ORDER SET ARRIVAL_DATE = (SELECT MAX(EXPCT_ARRIVAL_DT) FROM PR_ORDER_DET WHERE <po key>) WHERE <po key>
UPDATE PR_REQ_MAST SET REQ_STATUS = 4 WHERE <rfq key>      -- 'تم تحويل عرض الاسعار إلى أمر شراء'
-- delete PO: refused when PR_ORDER.CONFIRM_FLAG = 1 ('لا يمكن حذف أمر الشراء حيث أنه معتمد'); else delete PR_ORDER_DET by the QUOT link,
-- PR_ORDER when empty, ACCEPT_FLAG / DATE_SEND cleared, REQ_STATUS 2
```
Before the insert the legacy spreads DISC_VAL over the lines (DISTRIBUTE_DISC, `UPDATE PR_QUOT_DET SET DISC = ...`).

## Open questions
One or several accepted suppliers per RFQ? PO created unconfirmed and with the store? REQ_STATUS 5/6 never set by anything.

## Tests (ROLLBACK)
`t_misc.py` (quotation part): price without reply, price after reply, negative price, line not on the RFQ, accept → PO date,
status 3, two accepted suppliers refused.

## Wave 3 (buttons)

| Legacy | APEX | Evidence / notes |
|---|---|---|
| LOW_PRICE "اختيار آلي لأقل سعر" -> GET_LOWEST_PRICE | action LOWEST -> `app_act_pr.quot_lowest_price` | .fmx SQL: accepted offer exists "هناك عرض تم الموافقة علية من قبل"; no reply " لم يتم الرد "; total per replying, not accepted supplier = SUM(price x rate x RFQ quantity - line discount x rate) - supplier discount x rate (work table PR_TEMP, here a PL/SQL collection); several lowest "هناك اكثر من عرض لديهم اقل سعر لا يمكن الاختيار الآلى فى هذه الحالة "; else ACCEPT_FLAG 1, DATE_SEND = NVL(DATE_SEND, SYSDATE), REQ_STATUS 3, " أقل عرض سعر مقدم بقيمة X للمورد Y" |
| GEN_PURCHASE_ORDER "تكوين أمر الشراء" | action MAKE_PO -> `app_act_pr.quot_make_po` | .fmx SQL / texts: not accepted "لم يتم الموافقة على العرض - يجب الموافقة اولا ثم حفظ السجل"; already on a PO " الحركة الحالية تم عمل أمر شراء لها بالفعل "; no PO type "يجب ربط طلب عروض الأسعار بحركة أمر شراء في ملف الحركات!!!"; no DATE_SEND; no priced line "لم يتم تحديد اي سعر للأصناف تم إيقاف أمر الشراء"; per accepted supplier: DISTRIBUTE_DISC, PR_ORDER (date = DATE_SEND, currency / rate / supplier / SUPP_QUOT_NO / DISC_VAL of the offer, REQUISITION_TYPE of the purchase request), PR_ORDER_DET (serial = RFQ line serial, quoted price, bonus, discounts, quotation links), ARRIVAL_DATE = last expected arrival, REQ_STATUS 4, "تم تحويل عرض الاسعار إلى أمر شراء" |
| PUSH_BUTTON114 / REMOVE_PURCHASE_ORDER "حذف أمر الشراء" | action DELETE_PO (accepted supplier) -> `app_act_pr.quot_delete_po` | no order: acceptance withdrawn "الحركة لم يتم عمل لها أمر شراء - تم الغاء الموافقة"; confirmed order "لا يمكن حذف أمر الشراء حيث أنه معتمد"; else its lines deleted, the order when empty, ACCEPT_FLAG / DATE_SEND cleared, REQ_STATUS 2, " تم حذف أمر الشراء " |

Notes: the purchase order is written as the legacy did (no store, no DOC_NO; the purchase-order screen asks for the store at the next
save). DISTRIBUTE_DISC formula (DISC = discount x line value / (total x quantity)) follows the same-named unit of PR_INCOME_LOT - the
arithmetic of this form's unit is not visible in the .fmx (medium confidence).

Tests (build copy, all rolled back, plain and inside a simulated APEX session of app 100 with the regenerated APPX_ triggers; scripts in the job folder `tmp\w3_purch`: t_vn.py, t_po.py, t_lot.py, t_st.py, t_quot.py, t_reg.py; static check chk.py): temporary request type 90013 / RFQ type 90014 with three suppliers - tie refused, lowest (90 after its 10 discount) accepted
with status 3, repeated choice refused; purchase order 10601/149 with the quoted lines, DISC 0.4 / 0.6, arrival date, status 4; second
creation not offered; delete refused for a confirmed order, then order deleted and status 2; delete without an order withdraws the
acceptance - t_quot.py.

## Wave 3b
* `rules.computed` on the price lines PR_QUOT_DET: ITEM_NAME_A "الصنف" (item code and name) and RFQ_QUANTITY "الكمية المطلوبة" of
  the RFQ line the price belongs to (PR_REQ_DET by TRNS_TYPE_CODE / TRNS_SERIAL / REQ_DET_SERIAL) — this answers the wave-2 layout
  question "price grid without the item column".
* Supplier lists on the quotations and price lines (legacy supplier LOV: not stopped).
* Check: `check_forms.py PR_QUOT_TRNS` (tables empty in the build copy: the SQL runs, no rows).

## Coverage
Reproduced: quotation rules (wave 2, APP_RULES_SA) plus the three buttons (wave 3); supplier lists, item and requested quantity on
the price lines (wave 3b).

Not reproduced, with the reason: printing, alerts; the price grid has no item column in the table, but since wave 3b it shows the
item and the requested quantity of each line (computed through REQ_DET_SERIAL).
