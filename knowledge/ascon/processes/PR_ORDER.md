# PR_ORDER — أوامر الشراء / Purchase orders (system 30, serials 1 "prepare" and 2 "confirm")

Deliverable: **screen correction + business rules** — `overrides/PR_ORDER.json` (MASTER_DETAIL + `rules`), `APP_RULES_PR`
(`app/db/21_rules_pr.sql`). Confidence: **medium-high** (.fmb source; confirm / close logic and derivations verified).

## Purpose and tables
Purchase order to a supplier: `PR_ORDER` + lines `PR_ORDER_DET` (items), `PR_ORDER_SRVC` (services), `PR_ORDER_ASST`
(assets, Assets system only). Types `ST_TRNS_TYPE.EFFECT = 7 AND TRNS_TYPE = 14` (10601-10604). A confirmed order is the source
of incoming lots (PR_INCOME_LOT). Both menu entries open the same page; the "confirm" entry's `:PARAMETER.CONFIRM = 'Y'`
behaviour (all orders listed, confirm / close available) is used for both.

## Why a screen correction
The generated screen blocked header update / delete and line inserts (design-time block properties); the form opens them
at runtime (`CHECK_CLOSE` → `DEF_USR_SEC`) unless the order is confirmed or closed. The override keeps the generated columns and
enables DML; the confirm / close rules are enforced below. Check boxes (CONFIRM_FLAG, CLOSE_FLAG, BONUS_WITH_VAT) show as 0/1
number fields in the override.

## Rules implemented
| # | Rule | Where | Evidence |
|---|------|-------|----------|
| 1 | List: `NVL(ST_SRV_ASST_FLAG,0) != 4` (not asset orders: system 30), supplier password range | `rules.where` | block WHERE (`:GLOBAL.SYSTEM_NUMBER != 2`; CONFIRM part dropped, see above) |
| 2 | Defaults: lowest order type, its store, order date today, flags 0 | `defaults` | TRNS_TYPE_RG, WHEN-CREATE-RECORD |
| 3 | Type valid (EFFECT 7 / TRNS_TYPE 14, user's types), not changed after save; store mandatory; rate > 0 and 1 for local currency; supplier exists and cannot change once lines exist | validation `check_order_header` | PRE-INSERT "يجب ربط الحركة بالمخزن", CURRENCY_RATE WVI, SUPPLIER_CODE PRE-TEXT-ITEM |
| 4 | Numbering TRNS_SERIAL max+1 per type (generated APPX key); DOC_NO = max+1 over all orders when empty; ST_SRV_ASST_FLAG 1; store from the type; currency and rate from the supplier (AC_CURRENCY_SRV_RATE for the date, else AC_CURRENCY.RATE) when left at local currency | PR_ORDER row rule | PRE-INSERT, TRNS_TYPE_CODE WVI, SUPPLIER_CODE WVI |
| 5 | A new order cannot be created confirmed | PR_ORDER row rule | AUTH: "يجب حفظ السجل أولا" |
| 6 | Confirm (CONFIRM_FLAG 0→1): the saved order must have lines and every line quantity + bonus > 0 and price > 0 (services: quantity and cost > 0, assets: quantity > 0) | row rule → `order_update_check` | AUTH button |
| 7 | Un-confirm (1→0) refused when an incoming lot refers to the order | same | NOT_AUTH button |
| 8 | Confirmed or closed order is read-only: header (only CONFIRM_FLAG / CLOSE_FLAG may change) and lines (insert / update) | validation `check_order_locked` (SAVE) + PR_ORDER row rule + line row rules `order_line_guard` | CHECK_CLOSE, line WHEN-NEW-RECORD-INSTANCE |
| 9 | Line: group from item, basic unit, order date copied, price mandatory, quantity + bonus between 0 and 999999999999, BONUS ↔ PERCENTAGE, EXTRA_BONUS ↔ EXTRA_PERCENTAGE, cascading DISC1-3 ratio/value on VN_PRICE | PR_ORDER_DET row rule | PR_ORDER_DET PRE-INSERT, QUANTITY / BONUS* / DISC* WVI (verified on 1 242 lines) |
| 10 | Service line COST_PRCN between 0 and 100 | PR_ORDER_SRVC row rule | COST_PRCN WVI |
| 11 | Lines required (SAVE); header discount (DISC_VAL) ≤ Σ(qty × price − line discount); max lines | after-save `order_after_save` | PRE-INSERT, POST-QUERY V_TOT |
| 12 | Delete: refused when confirmed / closed (committed row); cascade delete of lines, delivery lines (PR_ORDER_DET_D, PR_ORDER_STORE_DET), services, assets; ST_PO_ITEM_SUPP link cleared | after-save DELETE `order_after_delete` | PRE-DELETE, POST-DELETE, CHECK_CLOSE |

## Dropped
> Wave 3: several items below are implemented now - see the sections "Wave 3" and "Coverage" at the end of this file.
Alerts / confirmation dialogs (outstanding quantity warning CHK_OUTSTANDING_QTY, delete confirmation), SET_IP, WEBUTIL,
printing, request / quotation import buttons (PARA1/PARA2, FILL_REQ_LIST), footer-memo navigation, agreement validation
(VALIDATE_AGRMNT: ST_SUPP_AGRMNT is empty), sales-order link buttons, tax recalculation (SET_TAX_DET / SET_TAX_MAST).

## Deviations / open questions
* DOC_NO: legacy `NVL(MAX(DOC_NO),0)+1` on a VARCHAR2 column (string maximum: repeats "10"); APEX uses the numeric maximum.
* ~~Confirming by setting CONFIRM_FLAG on the page~~ - wave 3: legacy buttons AUTH / NOT_AUTH / CLOSE / UNCLOSE are the actions CONFIRM / UNCONFIRM / CLOSE / OPEN, flags read-only.
* ~~VAT not computed~~ - wave 3: SET_TAX_DET / SET_TAX_MAST reproduced; 3-level order discounts (TOT_DISC*) not recalculated.
* Line PERCENTAGE / EXTRA_PERCENTAGE labels are "%" (legacy item names BONUS_RATIO / EXTRA_BONUS_RATIO).

## Tests
Scratch-table trigger tests (insert, confirmed insert refused, confirm without lines refused, confirmed order edit refused,
close allowed, un-confirm with lots refused, line on confirmed order refused, line without price refused, line derivations) and
package tests (header checks, lock validation, lines required, discount > total, delete of a confirmed order refused). All
rolled back.

## Wave 3 (buttons, taxes, displays)

Installation code: `:GLOBAL.CUSTOMER_CODE` comes from `SELECT CUSTOMER_PAR.CUSTOMER_CODE FROM CUSTOMER_PAR` (Sysmenu.fmx ENTER_LOGIN); CUSTOMER_PAR has 0 rows on the build copy (and in the production discovery), so the code is NULL: `= 'SDI' / 'RSD' / ...` branches never run and `!= 'RSD'` / `NOT IN (...)` tests are NULL, i.e. skipped too, exactly as in the legacy PL/SQL.

| Legacy | APEX | Evidence / notes |
|---|---|---|
| AUTH "إعتماد أمر الشراء": lines with quantity + bonus <= 0 or price <= 0 (items), quantity / cost <= 0 (services), quantity <= 0 (assets) -> " بعض الاصناف ليس لها كمية أو سعر "; no PR_ORDER_DET line -> " يجب إدخال أصناف "; CONFIRM_FLAG := 1 | action CONFIRM -> `app_act_pr.order_confirm` | po .fmb AUTH trigger |
| NOT_AUTH "الغاء الاعتماد": refused when an incoming lot uses the order ("لا يمكن الغاء الاعتماد"; `OR CUSTOMER_CODE = 'SDI'` is NULL) | action UNCONFIRM -> `order_unconfirm` | NOT_AUTH trigger |
| CLOSE_FLAG_B "اقفال" / UNCLOSE_FLAG_B "الغاء اقفال" | actions CLOSE / OPEN -> `order_close` / `order_open` ("تم اقفال أمر الشراء" / "تم ا الغاء قفال أمر الشراء") | |
| CHECK_CLOSE visibility (confirm entry :PARAMETER.CONFIRM = 'Y'): closed -> UNCLOSE; confirmed -> NOT_AUTH + CLOSE; open -> AUTH + CLOSE | `app_act_pr.order_can`, requires a right on the confirm entry 30/2; CONFIRM_FLAG / CLOSE_FLAG read-only on the page (Enabled = false in the .fmb) | |
| PARA1.GET_ITEMS_ACTUAL "إنزال الأصناف" (group range, every active item with its basic unit, quantity 1) | action GET_ITEMS (from / to group) -> `order_get_items` | refused when lines exist ("لا يمكن انزال اصناف مع وجود اصناف موجودة من قبل"); prices are typed before saving (PR_ORDER_DET PRE-INSERT "لابد من ادخال سعر الوحدة" now also checked on SAVE) |
| PARA2.GET_REQ_ITEMS "الأصناف التي وصلت حد الطلب" (items sold, TRNS_TYPE 2 / EFFECT 2, in the period with 20 % of the sales > GET_ALL_STORES_BALANCE the day before) | action GET_REQ_ITEMS (from / to date, from / to group) -> `order_get_req_items` | CHECK_DATE and the date-order message |
| CHK_OUTSTANDING_QTY (PR_ORDER_DET PRE-INSERT, "هناك كمية X من الصنف Y لم يتم إستلامها هل تريد الاستمرار ؟") | `info` OUTSTANDING -> `order_outstanding` (ordered - received in lots, per item / unit) | line-level confirmation not expressible (page warnings do not see grid rows) |
| SET_TAX_DET (VN_PRICE / QUANTITY / BONUS* / EXTRA_BONUS* / DISC* WVI, BONUS_WITH_VAT): TAX_LIB_NEW.GET_TAX_VALUE | `app_rules_pr.order_after_save` -> `order_taxes`: changed or new lines (committed row by flashback), all lines when BONUS_WITH_VAT changes | value = (VN_PRICE - DISC1..3) x rate x quantity (+ bonus + extra with BONUS_WITH_VAT); rate = DECODE(supplier %, 0, 0, item %) when the supplier has a row, else the item row; verified on 1 163 / 1 170 and 64 / 67 lines |
| SET_TAX_MAST: GET_TAX_VALUE_MAST | header TAX_CODE1 (supplier row) / TAX_VALUE1 = 0 | with a discount the library reads ST_TRNS_DET items that the PR_ORDER form does not have (FRM-40105, value 0): header VAT is always 0 - data: 0 of 370 orders have a header VAT |
| DISTRIBUTE_DISC (PR_ORDER_DET PRE-INSERT): DISC = DISC_VAL x NET_PRICE2 / (TOTAL_PRICE2 x QUANTITY) | same, new lines only | legacy used the totals of the lines entered so far (order-dependent); here the saved totals |

Tests (build copy, all rolled back, plain and inside a simulated APEX session of app 100 with the regenerated APPX_ triggers; scripts in the job folder `tmp\w3_purch`: t_vn.py, t_po.py, t_lot.py, t_st.py, t_quot.py, t_reg.py; static check chk.py): availability per state and user; confirm / unconfirm / close / open with messages; zero price and no-items refusals;
unconfirm with lots refused; PARA1 (23 items of group 301020000000, quantity 1, no price, save refused until priced); PARA2 date checks
and 209 items for 01/01-30/06/2026 (same count as the legacy query); outstanding display; VAT of a changed line 15 % (424.71), unchanged
lines untouched, BONUS_WITH_VAT recalculation of all lines, header 0; DISTRIBUTE_DISC on a new line only - t_po.py; 60 existing orders
saved unchanged keep VAT / DISC - t_reg.py.

## Wave 3b
Evidence: `ST\FMB\pr_order_fmb.xml` (item / block properties, record groups, triggers).
* Block settings: not changed. The .fmb design flags (header no update / delete, lines no insert) are opened or closed at run time by
  DEF_USR_SEC (user rights) and CHECK_CLOSE / WHEN-NEW-RECORD-INSTANCE (confirmed or closed orders are locked); the APEX page keeps
  its rights check and the wave-2 row rules for the confirmed / closed state.
* `readonly_after_insert` on TRNS_TYPE_CODE (UpdateAllowed = false, never re-enabled). SUPPLIER_CODE is editable only while the order has
  no lines (PRE-TEXT-ITEM) — not expressible with the keys, left editable; ITEM_CODE / UNIT_CODE are re-enabled for unconfirmed orders, so
  they stay editable.
* Check boxes 1/0: CONFIRM_FLAG and CLOSE_FLAG (read-only, set by the buttons), BONUS_WITH_VAT (default 0), PR_ORDER_SRVC.PRCN_FLAG
  (default 0) — CheckedValue 1 / UncheckedValue 0 in the .fmb.
* Legacy LOVs as lists: TRNS_TYPE_LOV (purchase-order types 7/14 with type rights), SUPPLIER_LOV (active, not stopped, VN_SUPPLIER_PASSWORD
  range), SUPP_CNTRCT (agreements of the order's supplier: cascade SUPPLIER_CODE), STORE_MAST_LOV, PR_ORDER_TYPE on REQUISITION_TYPE
  ("نوع أمر الشراء", ST_PR_ORDER_TYPES 1-4 = the data), PAYMENT_METHOD (LC_PAY_COND), PAYMENT_CONDITION_LOV (LC_PAY_CREDIT_COND),
  ITEM (active items and groups with a basic unit), UNIT_LOV (units of the item: cascade), SRVC_LOV (leaf services), ASST_CTGRY_LOV (leaf
  asset types).
* `rules.computed`: line ITEM_NAME_A "إسم الصنف", RECEIVED_QTY "الكمية المستلمة" and OUTSTANDING_QTY "كمية لم يتم إستلامها" (per item /
  unit of the order, the formula of `order_outstanding` / CHK_OUTSTANDING_QTY: ordered - received in the order's lots; order 10601/5
  gives the same 10 outstanding as the document text), SERVICE_NAME, asset-type DESC_A_ASCT.
* Check: `check_forms.py PR_ORDER` (13 lists, 5 computed columns).

## Coverage
Reproduced: all rules of wave 2 plus the confirm / close buttons, both imports, outstanding display, line / header VAT and the header
discount distribution (wave 3); legacy lists, check boxes, type fixed after insert, item / service / asset names and
received / outstanding quantity per line (wave 3b).

Not reproduced, with the reason:
* VALIDATE_AGRMNT (supplier agreement bonuses, DISC2, ON_SPOT, NET_COST, PO_M_DISC from ST_SUPP_AGRMNT_DET): the order needs CNTRCT_SERIAL;
  ST_SUPP_AGRMNT is empty and no order has an agreement - nothing to apply or verify (question: are agreements used?).
* BUT_SL / CAN_TEMP (import of a sales order): BUT_SL is Visible = false in the .fmb and never made visible - dead button.
* FILL_REQ_LIST / REQ_LIST (list of unconfirmed orders to jump to): Forms navigation; the APEX list page does it.
* CHK_OUTSTANDING_QTY as a per-line "continue?": needs a generator feature (warnings evaluated on the grid rows); shown as the document
  display and, since wave 3b, as the columns "الكمية المستلمة" / "كمية لم يتم إستلامها" of each line.
* SHIPMENT_TYPE list (values 1-4): the Arabic labels are lost in the .fmb (empty ListItemElement names) and not in the .fmx strings; data
  only uses 1 — still a number field (question: which shipment methods are 1-4?).
* Footer-memo buttons (navigation), printing, SET_IP, WEBUTIL.
