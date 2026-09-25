# PR_INCOME_LOT — الرسائل الواردة / Incoming lots (system 30, serials 3 "lots" and 4 "lot costs")

Deliverable: **screen correction + business rules** — `overrides/PR_INCOME_LOT.json` (MASTER_DETAIL + `rules`),
`APP_RULES_PR` (`app/db/21_rules_pr.sql`). Confidence: **medium** (.fmb source; the "transfer to stores" posting that creates the
purchase invoice and the supplier transaction is a process, not part of this screen).

## Purpose and tables
Receipt of a shipment against a confirmed purchase order: `PR_INCOME_LOT` + `PR_INCOME_LOT_DET` (items with lot parameters),
`PR_INCOME_DET_EXPENS` (supplier expenses), `PR_INCOME_LOT_SRVC` (services), `PR_INCOME_LOT_ASST` (assets),
`AS_ASSET_ACCT_TOT`. Types `EFFECT = 7 AND TRNS_TYPE = 15` (10701-10704, PU_TRNS_TYPE → 10801-10804). The ST_POSTING button
(CREATE_TRNS / INSERT_SUPPLIER_TRNS) turns the lot into a purchase invoice (ST_TRNS_MAST, INCOME_TRNS_*) and a supplier
transaction (VN_MAINTRNS / VN_SUBTRNS) and sets POST_FLAG / PU_TRNS_* / VN_TRNS_* — **not reconstructed here** (process).
Both menu entries (lots / lot costs, `:PARAMETER.FORM_FLAG`) open the same page (costs visible).

## Why a screen correction
Generated screen blocked header update / delete (design-time); the form opens the blocks at runtime (`DEF_USR_SEC`) unless the
lot is transferred. Override = generated columns, DML enabled, item lines first.

## Rules implemented
| # | Rule | Where | Evidence |
|---|------|-------|----------|
| 1 | List: `NVL(ST_SRV_ASST_FLAG,0) != 4` (system 30), supplier password range | `rules.where` | block WHERE |
| 2 | Defaults: lowest lot type, its store, arrival date today, ST_SRV_ASST_FLAG 1 (items) | `defaults` | TRNS_TYPE_RG, WHEN-CREATE-RECORD |
| 3 | Type valid (EFFECT 7 / TRNS_TYPE 15), linked to a purchase type (PU_TRNS_TYPE), not changed after save; ST_SRV_ASST_FLAG in 1-3; arrival date mandatory and ≤ today; store mandatory; rate > 0, < 99999999.99, 1 for local currency; supplier fixed once lines exist | validation `check_lot_header` | PRE-INSERT, ARRIVAL_DATE / CURRENCY_RATE WVI, SUPPLIER_CODE PRE-TEXT-ITEM |
| 4 | Purchase order (when given): exists, confirmed, not closed, same supplier, order date − 1 ≤ arrival, not used by another lot, still outstanding (GET_PR_ORDER_STATUS > 0) | same | PR_ORDER_MAST_RG |
| 5 | Numbering TRNS_SERIAL max+1 per type (APPX); LOT_SERIAL max+1 per type; DOC_NO = max(numeric DOC_NO)+1; store from the type; currency / rate from the supplier; POST_FLAG 0 | PR_INCOME_LOT row rule | PRE-INSERT, TRNS_TYPE_CODE / SUPPLIER_CODE WVI |
| 6 | Transferred lot (POST_FLAG = 1 or PU_TRNS_* set) is read-only: header (validation, SAVE) and all detail tables (row rules) | `check_lot_locked`, `lot_line_guard` | WHEN-NEW-RECORD-INSTANCE (header and lines) |
| 7 | Item line: group from item, basic unit, PO of the line = PO of the lot (copied when empty), PO exists, lot parameters mandatory (production date, sales price, sales discount, lot number, expiry date, unit), received quantity + free quantity > 0, free quantity ≥ 0, cascading DISC1-3 on VN_PRICE, INCOME_BASIC_QTY = (qty + bonus) × factor, arrival date and store copied | PR_INCOME_LOT_DET row rule | PR_INCOME_LOT_DET PRE-INSERT / PRE-UPDATE / WHEN-CREATE-RECORD, INCOME_BONUS WVI |
| 8 | Lines required (SAVE); supplier expense lines freight ≤ lot freight | after-save `lot_after_save` | PRE-INSERT (NULL_DET alert), CHECK_DET_EXP |
| 9 | Delete: refused when transferred (committed row); services, assets, asset lines, asset accounts, items and expenses removed | after-save DELETE `lot_after_delete` | KEY-DELREC, PRE-DELETE |

## Dropped
> Wave 3: several items below are implemented now - see the sections "Wave 3" and "Coverage" at the end of this file.
Dongle check, alerts, SET_IP, WEBUTIL, printing, requisition list (FILL_REQ_LIST), item import buttons (INSERT_ITEMS*),
DISTRIBUTE_DISC / RE_DISTRIBUTE_DISC / UPDATE_DISC / UPDATE_COST (discount and cost spreading used by the transfer process),
the supplier-voucher repeat warning (level 0 message), customer-specific branches (RSD, TOK, SDI).

## Open questions
1. ~~ST_POSTING / ST_UNPOSTING need a process page~~ - wave 3: document buttons (transfer to the stores, cancel), verified on 330 lots.
2. The header discount check (DISC_VAL_CURR ≤ lines) is not implemented: DISC_VAL is not on the generated screen.
3. The received-vs-ordered quantity check is commented out in the legacy form; not implemented.
4. Alphanumeric lot numbers are fine here (VARCHAR2), unlike ST_RECEIVE_COST.

## Tests
Scratch-table trigger tests (lot insert derivations, line without lot parameters, line with another PO, line derivations,
line / service line on a transferred lot refused) and package tests (header checks with a free / used PO, future arrival,
posted lot locked, delete of a posted lot refused). All rolled back.

## Wave 3 (transfer to the stores, cancel, import, derivations)

Installation code: `:GLOBAL.CUSTOMER_CODE` comes from `SELECT CUSTOMER_PAR.CUSTOMER_CODE FROM CUSTOMER_PAR` (Sysmenu.fmx ENTER_LOGIN); CUSTOMER_PAR has 0 rows on the build copy (and in the production discovery), so the code is NULL: `= 'SDI' / 'RSD' / ...` branches never run and `!= 'RSD'` / `NOT IN (...)` tests are NULL, i.e. skipped too, exactly as in the legacy PL/SQL.

| Legacy | APEX | Evidence / notes |
|---|---|---|
| ST_POSTING "ترحيل الرسالة الى المخازن" then the transfer-date window (TRNS_DATE2) and BUT_OK "تنفيذ التحويل" | action TO_STORES (TRNS_DATE2) -> `app_act_pr.lot_to_stores` | checks: already received (active invoice or POST_FLAG) "الرسالة تم إستلامها بالفعل"; PU_TRNS_TYPE "يجب التاكد من ربط الحركة مع حركة مشتريات"; supplier check `CUSTOMER_CODE != 'RSD'` = NULL -> skipped; arrival date; store; lines "يجب إدخال أسعار البضاعة"; CHECK_TRNS "يجب ادخال السعر"; TRNS_DATE2 >= arrival "يجب ان يكون تاريخ التحويل اكبر من تاريخ الرسالة" |
| CALC_UNIT_COST (per line: freight and header discount spread by value per basic unit) + UPDATE_COST (average per item, group, sales price) | `lot_calc_costs` | TOTAL_VALUE_RIYAL / SUM_TOTAL_VALUE_RIYAL / TOT_INCOME_BASIC_QTY summary items of the .fmb |
| CREATE_TRNS: ST_TRNS_MAST (DESC_A 'استلام رقم ...', DOC_NO = GET_NEXT_DOC_NO_STR, INVOICE_NO, links, VESSEL / SUPPLIER_REF / WIEGHT / ATM_DESC / CHECK_DATE / FREIGHT_VAL), ST_TRNS_DET_DUES (supplier), ST_TRNS_DET with GET_CONFG_ID (lot line ITEM_CONFG_ID updated), ST_STORE_ITEM, ST_TRNS_SERVICES, ST_TRNS_DET_EXPENS; lot PU_TRNS_* / POST_FLAG | `lot_create_trns` (row rules of the purchasing overrides bypassed: the legacy wrote plain rows) | .fmb CREATE_TRNS; DISC of the invoice lines = GET_NDB_DISC per line (legacy: :NDB_DISC of the current record - same value, 0, since DISC_VAL is not enterable) |
| ST_UNPOSTING -> UN_CREATE_TRNS ("this code have big error and neet to check") | action UNPOST -> `app_act_pr.lot_unpost` | not received "الرسالة لم يتم إستلامها "; collected lot "لايمكن الغاء ترحيل رسالة مجمعة من هذه الشاشة"; GL / AP posted invoice or a later issue of the received stock (GET_BALANCE_CONFG + UPDATE_NEXT_TRNS_CONFG, unless ST_BASIC.NEG_SALE_BALANCE = 1) "لا يمكن الغاء الترحيل للمخازن لوجود حركة صرف ..."; then all invoices of the lot deleted (also cancelled ones, as the legacy) and PU_TRNS_* / VN_TRNS_* / POST_FLAG reset |
| ITEM_INSERT "انزال اصناف امر الشراء" (INSERT_ITEMS / INSERT_ITEMS2 / INSERT_ITEMS3) | action IMPORT -> `app_act_pr.lot_import_items` | order lines (store part PR_ORDER_STORE_DET), remaining quantities after the lots of the order, prices / discounts, SALES_PRICE (RETAIL_SALE_PRICE), SALES_DISC_RATIO (last lot configuration); services with GET_INCOME_SERVICE_QTY; lot parameters typed before saving (PRE-INSERT "يجب إدخال محددات الشحنات" and the quantity check now also on SAVE) |
| GET_TAX_DET (line VAT on ITEM_CODE / INCOME_QUANTITY / VN_PRICE / DISC* / SUPP_DISC* / DET_DISC WVI) | `app_rules_pr.lot_after_save` -> `lot_lines_derive` (changed lines) | value = INCOME_BASIC_QTY x (VN_PRICE - DISC1..3) x rate; verified on 1 089 / 1 094 lines |
| KEY-COMMIT: DISTRIBUTE_DISC (flag 1, 2) then UPDATE_COST | same in `lot_lines_derive` | |

Legacy defects kept / noted: UN_CREATE_TRNS reset FAIL_DELETE on every line (only the last line counted): here any failing line refuses
(the line order of the legacy cursor is not defined); a lot with several invoices (a cancelled one plus the new one) could not be cancelled
(ORA-01422) - reproduced as a clear refusal "توجد أكثر من حركة وارد لهذه الرسالة"; for service-only lots the legacy skipped the posted
check (reproduced); INSERT_ITEMS selects the received extra bonus INTO V_DET_DISC and the received line discount INTO V_EXTRA_BONUS
(INTO list order) - kept; the item line SERIAL is the order line serial (a second import of the same line is refused instead of the
legacy duplicate-key error).

Tests (build copy, all rolled back, plain and inside a simulated APEX session of app 100 with the regenerated APPX_ triggers; scripts in the job folder `tmp\w3_purch`: t_vn.py, t_po.py, t_lot.py, t_st.py, t_quot.py, t_reg.py; static check chk.py): **history** - 330 posted lots (all single-invoice item lots): the generated invoice was removed inside a savepoint and the
lot transferred again with the original date: header fields 9 240 / 9 240 (16 differing fields are later edits of the invoice by users -
description, supplier - or a trailing blank lost on a later save), lines 1 025 with 32 800 / 32 800 identical fields (prices, quantities, basic quantity, unit cost, lot configuration,
discounts, VAT, dates), dues 330 / 330, lot unit costs 1 025 / 1 025; posted-lot refusals; cancel refused for a GL-posted invoice and for
stock issued afterwards, accepted with NEG_SALE_BALANCE = 1; several invoices refused; import of an order (quantities, prices, links),
second import refused, save refused until the lot parameters are typed; VAT of a changed lot line - t_lot.py; 60 lots saved unchanged keep
VAT / DISC / UNIT_COST - t_reg.py.

## Wave 3b
Evidence: `ST\FMB\pr_income_lot_fmb.xml` (item properties, radio buttons, record groups) and the compiled `pr_income_lot.fmx`
(radio labels stored next to the button names).
* ST_SRV_ASST_FLAG "نوع التوريد": radio group توريد مواد 1 / توريد مواد وخدمات 2 / توريد خدمات 3 (RadioButtonValue of ST / ST_SRV / SRV;
  labels from the .fmx string table), read-only after insert (UpdateAllowed = false). The fourth button "توريد اصول" (4) is not offered:
  asset lots belong to the fixed-assets system and the page filters them out (Coverage).
* `readonly_after_insert` on ARRIVAL_DATE, DOC_NO, ORDER_TRNS_TYPE_CODE (UpdateAllowed = false, no trigger re-enables them).
* Check boxes 1/0: POST_FLAG (read-only), PR_INCOME_LOT_SRVC.PRCN_FLAG (default 0).
* Legacy LOVs as lists: TRNS_TYPE_LOV (lot types 7/15 with type rights), STORE_LOV, SUPP_LOV (range), EXP_SUPPLIER_LOV on the expense lines,
  units of the item (cascade), ACCOUNT / COST_LOV_ACCT on the asset-account lines.
* `rules.computed`: ITEM_NAME_A "إسم الصنف" on the lines, SERVICE_NAME, asset-type DESC_A_ASCT.
* Check: `check_forms.py PR_INCOME_LOT`.

## Coverage
Reproduced: header / line rules, delete (wave 2); transfer to the stores with the cost calculation, cancel, item / service import,
line VAT, header-discount distribution and UPDATE_COST (wave 3); supply-kind radio group, header items fixed after insert,
check boxes, legacy lists, item / service / asset names (wave 3b).

Not reproduced, with the reason:
* DESC2 "رقم سند المورد مكرر" (level-0 message) and the DESC2 KEY-NEXT-ITEM hint: DESC2 is Visible = false in the .fmb and never made
  visible, 0 of 348 lots have a value - dead feature (the column is not on the page).
* DISC_VAL / DISC_VAL_CURR (header discount): Visible = false (hidden again when FORM_FLAG = 1), 0 lots use it; the distribution code is
  reproduced but stays inactive.
* REQ_LIST (list of lots not received yet, jump to one): Forms navigation; the APEX list page does it.
* Asset lots (ST_SRV_ASST_FLAG 4, INSERT_ASSET / INSERT_ITEMS4, AS_* tables): fixed-assets system (system 2), filtered out of this page.
* POST_TO_AC / UNPOST_TO_AC / ALL / REST_OF_ORDER / STORE_ONLY buttons: listed in the .fmx item list but without triggers in the .fmb -
  inactive.
* Lot lines not updatable after insert (.fmb UpdateAllowed = false on item, unit, quantities, expiry, prices, lot number): not applied,
  because the APEX order import saves the lines and the user then adjusts the received quantities (the legacy import filled unsaved
  records); posted lots are locked by the wave-2 rules.
* Order LOV on the header (PR_ORDER_MAST_LOV fills type and serial of the order together): a list returns one value; the order import
  action takes the order.
* Printing (PRINT_BUT, INV_PRINT_BTN), SET_IP, WEBUTIL, dongle, customer branches (SDI, RSD, TOK).
