# ST_PRICE_PROPOSAL: customer quotations (عروض أسعار المبيعات), registry 31/1 (entry) and 31/2 (approval)

**Deliverable:** screen rules (pattern AUTO), `app\legacy\overrides\ST_PRICE_PROPOSAL.json`, package `APP_RULES_SA`
(`qt_mast_row`, `qt_det_row`, `sales_line`, `qt_validate`, `qt_after_save`); action **TO_ORDER** (conversion to a sales order,
package `APP_CONV` in `app\db\22_conv.sql`: `can_quote_to_order`, `quote_to_order`). Wave 3: actions **TO_PROPOSAL / TO_TRQ /
TO_TRANSFER** (`APP_CONV.quote_to_proposal / quote_to_trq / quote_to_transfer`), **CHOICE_ALL / UNAV_ALL / LOAD_EXCEL** and the soft-delete
check and displays (`APP_ACT_ST.qt_*`), see "Wave 3" below.
**Confidence:** high for numbering, defaults, header checks, approval order / permissions, read-only states, line derivations
and the conversion to a sales order (re-run on all 1,303 historical conversions); medium for the default price / discount of
lines and the credit check.

## Purpose and tables
`ST_PROPOSAL_MAST` / `ST_PROPOSAL_DET`, types `EFFECT 7, TRNS_TYPE 16, JOIN_TYPE 3/4` (10101, 20101, 30101; each maps to an order type).
1,671 quotations, 1,303 fully approved and converted to sales orders. Workflow: salesman done → supervisor (APPROVE) → purchasing
(APPROVE2) → sales (CUST_ACCEPT_FLAG) → convert to sales order. One APEX page covers both menu entries.

## Rules implemented
| # | Rule | Where | Legacy evidence (ST_PRICE_PROPOSAL.md) |
|---|---|---|---|
| F1 | List: not deleted, quotation types, group rights on type (FLAG 1), salesman and customer (AR_SALESMAN_PASSWORD / AR_CUST_PASSWORD), own documents for OWNER_SALES_ORDER_ONLY outside group 0 | `where` | block WHERE l.431, WNFI l.785-834 |
| N1 | TRNS_SERIAL max + 1 per type (APPX); **DATE_SERIAL = max + 1 per TRNS_DATE** (NOT NULL, missing in the generated trigger); ITEM_SERIAL max + 1 (APPX) | row rule | PRE-INSERT l.1059-1077, l.4022 |
| N2 | INVOICE_NO ("Qtn #") = legacy text MAX + 1 (gives '10', faithful); DOC_NO left empty (assigned at conversion) | row rule | TRNS_TYPE WVI l.1616 |
| D1 | TRNS_DATE today; store of the type; currency / rate from the customer; salesman `GET_LAST_SALESMAN_INDATE`; OFFER_EXPIRY '45'; PROPOSAL_EXPIRE = date + OFFER_EXPIRY; flags 0; POSTING_SUPPLIER_CODE = SUPPLIER_CODE; PAY_TERM / OTHER_TERMS defaults ('Days Credit 90' / '90 Days After Confirmed Order', data-derived) | `defaults` + row rule | §3 of the research; PRE-INSERT / PRE-UPDATE |
| V1 | Type QT (JOIN_TYPE 3/4) allowed; customer or supplier required ("يجب إدخال رقم العميل أو رقم المورد فى عرض السعر"); customer in the list **of the type's category** (AR_CUST_SALESMAN.CTGRY_CODE = type CTGRY_CODE); store; salesman of the customer; currency 1 ⇒ rate 1; class rights | `qt_validate` | PRE-INSERT H2, CUSTOMER_RG, H10 |
| V2 | TRNS_DATE = day of entry; not future, ≥ ST_BASIC.MIN_DATE, > AC_BASIC.CLOSE_DATE, salesman-transfer date | `qt_validate` | VALIDATE_DATE l.8101-8157 |
| V3 | RFQ unique on insert; customer / supplier / rate / class frozen once lines exist | `qt_validate` | H3, H11-H12 |
| W1 | Approvals by check box (the buttons): SALESMAN_DONE needs a chosen available line; un-doing it refused after APPROVE or without ALLOW_APPROVE; APPROVE needs ALLOW_APPROVE, APPROVE2 needs ALLOW_APPROVE2 and APPROVE, CUST_ACCEPT_FLAG needs ALLOW_APPROVE3 (group 0 has rights 1 and 2 only, as GET_USER_SEC); un-approve 1 refused while 2 is set; each approval runs the credit check (`limit < balance` or, before APPROVE, `limit < balance + quotation net`) → "تعديت حد الائتمان"; approvals cannot be given at creation | `qt_validate`; user / date stamped by `qt_mast_row` (APPROVE_*, APPROVE2_*, APPROVE3_*) | SALESMAN_BTN … SALES_BTN l.3509-3725 |
| W2 | Read-only states (CLOSE_UPDATE): converted (live sales order / invoice with DEMO_TRNS = quotation, or split quotation) → no change; salesman-done without any approval right → no change; APPROVE = 1 → only approvers; CUST_ACCEPT_FLAG = 1 → lines, description, terms and dates locked | `qt_validate`, `qt_det_row`, `qt_after_save` | CLOSE_UPDATE l.6411-6535 |
| L1 | Line copies of the header (store, date, date serial, delete flag), COST_FLAG 1, UNIT_COST null, ITEM_NAME_DUMMY; basic unit; lot of the item and not expired; default price = lot price (users without CHANGE_SALES_PRICE) or retail price, default DISC1 = lot DISC_RATIO or ST_ITEM.MOH_DISC; policy values by CALC_SALES_DISC; AUTO_DISC rules as in orders; BASIC_QTY, UNIT_PRICE, discounts | row rule | ITEM_CODE / ITEM_CONFG_ID WVI, LOV mappings, PRE-INSERT l.3949-4033 |
| L2 | Errors: price ≤ 0, qty + bonus ≤ 0, discount ratios 0-100, discounts < price, manual price change only with USERS.CHANGE_SALES_PRICE and ST_TRNS_TYPE.HAS_SALES_PRICE and not below retail, CHOICE and UNAVAILABLE together, transfer qty 0..BASIC_QTY; CHOICE reset to 0 when the store has no stock (legacy warning + reset) | row rule | D1-D14 |
| L3 | VAT = tax rate × net price × BASIC_QTY (bonus included, as legacy) | row rule | GET_TAX_VALUE on NET_LINE_TOTAL_BASIC |
| A1 | A quotation needs items (from the first save after the header); header TOT_DISC cascade | `qt_after_save` | PRE-INSERT H1, VALIDATE_TOT_DISC |

## Wave 3: buttons, delete, displays (APP_CONV `quote_to_*`, APP_ACT_ST `qt_*`)
None of these buttons was used on this database (no quotation has PROPOSAL_TRNS_*, no transfer request / transfer points to a
quotation, the quotation types have no TRNSFER_FROM_TRNS_TYPE / TRNSFER_TO_TRNS_TYPE); they are reproduced from the .fmb code.

| # | Legacy | APEX | Evidence | Confidence |
|---|---|---|---|---|
| X1 | TO_PROPOSAL_BTN + MAKE_PROPOSAL + INSERT_ANOTHER_PROPOSAL / INSERT_PROPOSAL_DET "تحويل إلي عرض سعر": checks APPROVE ("يجب إعتماد الإدارة أولا"), APPROVE2, CUST_ACCEPT_FLAG, not split already ("عرض السعر تم ترحيلة إلي عرض السعر"), store ("يجب ادخال المخزن أولا"), type and date; lines CHOICE 0 / UNAVAILABLE 1 required ("لايمكن التحويل الي عرض سعر بدون اختيار الأصناف"). New quotation of the chosen type (PROPOSAL_TRNS_TYPE_RG: quotation types of another store, group rights FLAG 1): serial max + 1, DATE_SERIAL per date, store = type store (else entered), DOC_NO = next DOC_NO of the **source** type (GET_NEXT_DOC_NO), INVOICE_NO text MAX + 1, description "عرض سعر رقم t/s من عرض أسعار رقم  q/s", currency, customer, salesman, DELETE_FLAG and CUST_ACCEPT_FLAG copied (APPROVE flags not), terms, expiry, header VAT, TOT_DISC ratios with values recomputed on the moved lines (legacy arithmetic kept), PROPOSAL_TRNS_* link; lines copied with new serials, CHOICE / UNAVAILABLE 0, PROPOSAL_* links, BASIC_QTY = factor × (qty + bonus + extra); "تم عمل سعر بيع رقم t/s" | action TO_PROPOSAL (`app_conv.quote_to_proposal`), params type / store / date (default the quotation date), opens the new quotation; the source quotation is read only afterwards (APP_RULES_SA `qt_converted`) | l.2591-2638, 2937-2989, 7751-8099, record group l.10793 | medium-high |
| X2 | TO_TRANSFER_REQ + MAKE_TRANSFER_REQ + INSERT_TRANSFER_REQ / _DET "طلب تحويل": APPROVE, APPROVE2, CUST_ACCEPT_FLAG; date ≥ quotation date ("تاريخ طلب التحويل يجب أن يكون أكبر من يساوى تارخ عرض السعر") and CHECK_DATE; an existing request → nothing ("عرض السعر تم ترحيلة إلي طلب تحويل"); unavailable lines required. ST_TRNS_MAST_REQUEST of the chosen type (TRANSFER_TRNS_RG: 7/9 types of another store): serial, DATE_SERIAL per date, DOC_NO max + 1 per type, STORE_CODE = TRNSFER_FROM_STORE = type store (else entered), TRNSFER_TO_STORE = quotation store, flags 0, PROPOSAL_TRNS_* link; lines: QUANTITY = TRANSFER_QTY else qty + bonus + extra, BASIC_QTY = factor × quotation BASIC_QTY, COST_FLAG, links, STORE_CODE empty (legacy took an item of another window); "تم عمل طلب تحويل رقم t/s" | action TO_TRQ (`app_conv.quote_to_trq`), opens the request on ST_TRANSFER_REQUEST | l.2640-2701, 3086-3206, 8661-8857, l.10811 | medium-high |
| X3 | TRNSFER_FROM_BTN + MAKE_TRNSFER_FROM + INSERT_TRNSFR_FROM_TRNS / DEVIDE_CONFGS_TRNSFER / INSERT_TRNSFR_FROM_DET "تحويل": refused when converted to an order, credit check ("تعديت حد الائتمان"), APPROVE / APPROVE2 / CUST_ACCEPT, the four flags re-read ("يجب الإعتماد أولا"), issue and receipt types (TRNSFR_FROM 5/9, TRNSFR_TO 6/9, group FLAG 1; defaults ST_TRNS_TYPE.TRNSFER_FROM/TO_TRNS_TYPE of the quotation type), destination store, date; chosen lines required ("لايمكن التحويل بدون اختيار الأصناف"). ST_TRNSFER row (serial per quotation store, approved), issue header (DOC_NO = quotation type ‖ LPAD(serial, 6), "بموجب سند تحويل اتوماتيك رقم …", PRO_TRNS_* link), lines: the quotation lot first then lots by expiry, a lot takes min(balance, rest), QUANTITY = qty + bonus + extra, lot price when the quotation type has no HAS_SALES_PRICE, lot balance at the position and later movements checked; rest → "أقصى كمية يمكن إخراجها حتى لا تتعارض مع الحركات التالية = …" and nothing is written. Receipt header in the destination store (TRNSFER_TYPE 1) with the same lines, ST_TRNSFER received, quotation DOC_NO = the transfer number when empty; "تم عمل حركة التحويل رقم t/s" | action TO_TRANSFER (`app_conv.quote_to_transfer`), opens the issue transfer (ST_TRANSFER_FROM) | l.2394-2465, 2999-3076, 9860-10677, l.10700-10726 | medium |
| X4 | CHOICE_FLAG_ALL check box: tick → each line (not unavailable, basic qty ≠ 0) chosen when the store balance of the item (GET_BALANCE today) ≥ Σ BASIC_QTY of the item / unit on the quotation (and, CHOICE_FLAG WHEN-VALIDATE-ITEM, ≥ the line's qty + bonus + extra); untick → chosen lines (price ≠ 0) un-chosen; with CUST_ACCEPT_FLAG = 1 only "تم اعتماد المبيعات" | action CHOICE_ALL (`qt_choice_all`, param تحديد / إلغاء), refused on read-only quotations (CLOSE_UPDATE: converted, split, salesman-done without rights, approved without ALLOW_APPROVE) | l.3272-3356, 5305 | high |
| X5 | UNAVAILABLE_FLAG_ALL: tick → lines not chosen (item, price, quantity) unavailable; untick → flag cleared | action UNAV_ALL (`qt_unavailable_all`) | l.3358-3414 | high |
| X6 | LOAD_EXCEL + LOAD_EXCEL_FILE (WEBUTIL OLE): only on a quotation with a type, customer and date and no lines ("لابد من أدخال البيانات أولا" / "لابد من حذف البيانات أولا"); sheet 1 from row 2 to the first empty item: group (empty → the item's group), item, unit, price (empty → retail price), lot id (empty → lot found by lot number + expiry), lot number, expiry DD/MM/YYYY, quantity, discount 1-3 as fractions (× 100; discount 1 empty → ST_ITEM.MOH_DISC), bonus, extra bonus; row checks (group active, lot of the item, price, discounts, bonus, unit, item of the group) → the row is skipped and reported ("ITEM CODE= … GROUP CODE= … UNIT NOT EXIST-" …, legacy: a .TXT file next to the Excel file); inserted lines: discount values, BASIC_QTY = qty + ROUND(bonus ratio × qty) + ROUND(extra ratio × qty), VAT (GET_EXCEL_TAX_VALUE), policy values (CALC_SALES_DISC), LAST_EXPIRE_DATE, CHOICE / UNAVAILABLE / AUTO_DISC 0; "تم تحميل ملف الأكسل" | action LOAD_EXCEL (`qt_load_excel`, file parameter, `.xlsx` or `.csv` through APEX_DATA_PARSER); the skipped rows are listed in the success message | l.3473-3501, 9351-9811 | high |
| X7 | KEY-DELREC: refused when APPROVE or CUST_ACCEPT_FLAG ≠ 0 ("الحركة الحالية معتمدة و لا يمكن الحذف"), when converted to a sales order ("عرض السعر تم تحويلة إلى أمر بيع"); the lines are deleted, the header gets DELETE_FLAG 1 / DELETE_USER / DELETE_DATE (data: 150 deleted quotations, most without lines) | `rules.soft_delete` (lines delete, check `qt_delete_check`, which also refuses the CLOSE_UPDATE read-only states: invoice / split / salesman-done without rights) | l.1349-1438, 1552-1570, CLOSE_UPDATE | high |
| I1 | POST-QUERY / CHECK_MAST_STATUS / GET_TOTAL_A / GET_PROPOSAL_INFO displays: credit limit, balance, invoice age, allowed days, state, net value, VAT, chosen items' net (NET_VALUE_A; the legacy compared it with the net before a conversion), items not chosen (the "يوجد عدد أصناف N غير مختارة" message of the conversion buttons), counters (items, available, unavailable, unavailable in all stores GET_BALANCE_ALL_STORES, over policy, over sales limit), the documents made from the quotation (order and its invoice, transfer, split quotation, transfer request) | `info` (16 values, `qt_info`) | l.1096-1347, 7200-7384, 8859-8916 | high (counters), medium (net formula) |

Tests (`w3_sales\f2\t_f2.py`, ROLLBACK, plain and APEX): Q1-Q7 (delete check per state, soft-delete block, choose all against the
legacy balance rule, unavailable all, untick, accepted quotation message, converted quotation locked, display conditions, CSV load with
error rows and stop at the empty row, second load refused, .xlsx load with lot lookup by lot number + expiry date and a percent cell,
displays) and C0-C7 (display conditions / default types; split: no line, same type, no store, header and lines, text, second split refused,
source read only (APEX); transfer request: wrong store type, unapproved, date, header / lines, second request refused; transfer: order
exists, types missing / wrong, header, lot order (quotation lot first, then by expiry), receipt lines and costs, ST_TRNSFER received,
stock moved between the stores, second transfer refused, not enough stock refused, DOC_NO given to the quotation). APP_CONV regression
`tmp\conv\t_conv.py` still 72/72 in both modes.

## Conversion to a sales order — action TO_ORDER (implemented)
Legacy: button TO_SALES_ORDER_BTN ("تحويل إلي أمر بيع") opened the order-date field, button MAKE_ORDER ("موافق") ran INSERT_ORDER_TRNS /
DEVIDE_CONFGS / INSERT_ORDER_DET, then GET_ACT_DOC_NO_INV (evidence pack: TO_SALES_ORDER_BTN, MAKE_ORDER, ORDER_DATE WHEN-VALIDATE-ITEM,
program units INSERT_ORDER_TRNS, DEVIDE_CONFGS, INSERT_ORDER_DET, GET_ORDER_TRNS_SERIAL, GET_ACT_DOC_NO_INV; DB function
GET_ACT_DOC_NO_PROPOSAL). APEX: action region on the saved quotation, parameter ORDER_DATE (default today), shown when
`app_conv.can_quote_to_order` = 'Y' (approval entry right, not deleted, the four flags set, no live order, the type has an order
type); opens the new order.

| # | Rule (legacy order of the checks) | Message |
|---|---|---|
| C0 | The button existed only on the approval menu entry (FILES_MENU.ST_PRO_APPROV, 31/2; hidden when PARAMETER.AUTH = 1): the user needs that entry in FILE_PASSWORD (user 0 always) — the action region is hidden otherwise | ليس لديك صلاحية على شاشة اعتماد عروض الأسعار |
| C1 | Credit check: CREDIT_LIMIT (NVL 0) < GET_CUSTOMER_BAL_ALL (before APPROVE also + quotation net) | تعديت حد الائتمان |
| C2 | DOC_NO of the quotation already on a live sales invoice (EFFECT 2 / TRNS_TYPE 2) of the same customer category | رقم المستند مكرر لنفس رقم القسم |
| C3 | APPROVE, APPROVE2, CUST_ACCEPT_FLAG, then all four flags re-read (SALESMAN_DONE too) | يجب إعتماد الإدارة أولا / يجب إعتماد الإدارة 2 أولا / يجب إعتماد العميل أولا / يجب الإعتماد أولا |
| C4 | No live order with DEMO_TRNS = the quotation (legacy: silently nothing) | عرض السعر تم ترحيلة إلي أمر بيع |
| C5 | Order type = ST_TRNS_TYPE.SALES_ORDER_TRNS_TYPE of the quotation type (10101→10201, 20101→20201, 30101→30201); date given | يجب تعريف رقم حركة أمر البيع و تاريخ أمر البيع |
| C6 | Order date ≥ quotation date; CHECK_DATE (not future, ≥ ST_BASIC.MIN_DATE) | تاريخ أمر البيع يجب أن يكون أكبر من يساوى تارخ عرض السعر … |
| C7 | The order type has an invoice type (SALES_TRNS_TYPE_CODE; INSERT_ORDER_TRNS refused otherwise) | يجب إدخال رقم حركة فاتورة المبيعات و تاريخ الفاتورة |
| C8 | At least one line CHOICE_FLAG = 1 and UNAVAILABLE_FLAG = 0 | لايمكن التحويل الي امر بيع بدون اختيار الأصناف |
| H1 | Header: TRNS_SERIAL max + 1 per order type, ORDER_SERIAL = type ‖ serial, ORDER_DATE = LOADING_DATE = the date; copies store, INVOICE_NO → INVOICE_NUMBER, DOC_NO, currency / rate, customer, salesman, supplier, TRNSPORT_VAL, PAY_TERM, OTHER_TERMS → DELIVERY_TERMS, OFFER_EXPIRY, PROPOSAL_EXPIRE → OFFER_EXPIRE_DATE, RFQ, header taxes, TOT_DISC*, PAYMENT_TYPE, CLASS_CODE; SO_TYPE 0; APPROVED = APPROVED2 = 1 by the converting user now; DEMO_TRNS_* = quotation; DESC 'أمر بيع رقم t/s من عرض أسعار رقم  q/s'; INSERT_DATE = today (date only) | |
| L1 | Lines (chosen and available, in line order): split over the lots of the store — the quotation lot first, then the other lots by expiry (ties in the order of index ST_ITEM_CONFG_U01: lot number, price, supplier, discount), expired lots and lots without stock skipped; quantity first, then bonus, then extra bonus; discount values recomputed from the ratios on UNIT_PRICE_CURR; VAT = TX_TAXES_ITEMS % × (qty + bonus + extra) × net price (not rounded, the column keeps 2 decimals); prices, ratios, ORG_* policy values, remark, LAST_EXPIRE_DATE, TEMP_QUANTITY copied; SERIAL max + 1; BASIC_QTY = factor × (qty + bonus + extra) | |
| L2 | Not enough stock for a line → whole conversion refused | أقصى كمية يمكن إخراجها حتى لا تتعارض مع الحركات التالية = … للصنف … |
| D1 | Quotation without DOC_NO: DOC_NO_SEQ.NEXTVAL (GET_ACT_DOC_NO_PROPOSAL) on the order and the quotation | |

Not written by the legacy either: DET_DISC (computed but not in the INSERT), CLOSED, AUTO_DISC_INIT. The row rules of the sales-order
screen stand aside while the order is written (`app_rules_sa.set_bypass`), so the copied values are not re-derived. Success text:
static text of the action; `app_conv.last_message` holds the legacy text "تم عمل أمر البيع رقم 10201/…".

**History check (all rolled back):** every live order created from a quotation (1,303) was re-created from its quotation with the
order date and user of the legacy order and the stock as it was at the conversion time (test switch `app_conv.set_test`: documents
inserted after the legacy APPROVED_DATE ignored through the ST_TRNS_MAST.DATE_SERIAL sequence order; "already converted" and credit
checks skipped) and compared field by field with the legacy order:
- **1,203 identical** (all header fields the conversion writes, all line fields including the lots / lot split, SERIAL, VAT);
- **95 identical except TAX_VALUE1 on 138 lines**: the VAT % of those items in TX_TAXES_ITEMS changed after the conversion (0 ↔ 15; e.g.
  item 101020118 has 15 % today but 0 on every quotation, order and invoice of 2025-2026);
- **5 different, explained**: 10201/485 (a line deleted and re-entered on the order screen after the conversion), 10201/604 (order line quantity
  100 against 128 on the quotation: the order was edited after the conversion, UPDATE_DATE set; the quotation is locked once converted), 20201/1 and 20201/2 (18 Jan 2025: the program then took the lot price 28.126 instead of the
  quotation price — the "YEHIA" block is commented out in the .fmb we have), 30201/1 (6 Jan 2025, first order of the type: no DOC_NO,
  approvals stamped by user 0 on the order screen, description replaced);
- fields typed on the order screen after the conversion (not compared): CUST_SALES_DOC_NO (593 orders), description (9), CLOSED (2),
  AUTO_DISC_INIT (3), header TAX_VALUE2 0 instead of empty (3); line order differs from the quotation line order in 2 orders
  (10201/485, 30201/248: the legacy cursor had no line order).
With today's stock instead of the historical stock, 1,053 of the 1,303 quotations would be refused (lots sold or expired since) — the
reason for the as-of test mode.

## Open questions
1. Conversion: should the order still be born approved at both levels (legacy)? The order VAT uses the item tax table only (customer
   exemptions used on the quotation are not applied) — legacy behaviour, confirm. Lots near expiry are not excluded (only expired ones).
2. INVOICE_NO always '10' — keep / renumber / drop?
3. Default PAYMENT_TYPE (data: mostly 3)? PAY_TERM / OTHER_TERMS defaults confirmed?
4. Duplicate items across lots in one quotation are allowed (349 documents) — keep?
5. Credit check at each approval and again at conversion (legacy) — keep?
6. The quotation → quotation / transfer request / transfer buttons were never used here and the quotation types have no transfer
   types: are they needed? If yes, which transfer types should the quotation types carry (TRNSFER_FROM_TRNS_TYPE / TRNSFER_TO_TRNS_TYPE)?
7. Transfer from a quotation: the legacy issue lines had no UNIT_COST, so the automatic receipt carried no cost (zero-cost stock in the
   destination); APEX takes the lot's average cost as the transfer screen does — confirm.
8. The split quotation copies CUST_ACCEPT_FLAG but not the approvals (legacy): the new quotation is accepted but not approved — confirm.

## Wave 3b (new generator keys)

Evidence: `ST\FMB\ST_PRICE_PROPOSAL_fmb.xml`.

| Change | Key | Evidence |
|---|---|---|
| Transaction type and store read-only after insert; store required | `TRNS_TYPE_CODE` / `STORE_CODE` `readonly_after_insert`, `STORE_CODE.required` | `UpdateAllowed="false"`, `STORE_CODE Required="true"` |
| Customer required and payment terms required | `CUSTOMER_CODE.required`, `PAYMENT_TYPE.required` | `Required="true"`; every document has them |
| Price-class list from `AR_ST_ITEM_CLASSES` (was the fixed-asset classes `AS_CLASS`, a wrong automatic list) | `CLASS_CODE.lov` | LOV AR_ST_CLASS_DET → RG AR_ST_CLASS `SELECT CLASS_CODE, DESC_A, DESC_E FROM AR_ST_ITEM_CLASSES` |
| Payment-terms list from `ST_PAYMENT_TERMS` | `PAYMENT_TYPE.lov` | LOV PAYMENT_LOV → `SELECT SERIAL, TYPE_NAME, TYPE_NAME_E FROM ST_PAYMENT_TERMS` |
| Per line: item name, lot number and lot expiry | `computed.ST_PROPOSAL_DET.*` | display items ITEM_NAME / LOT_NUMBER / EXPIRE_DATE |
| Lot list of the line's item (lot id - lot number - expiry), refreshed when the item changes | `ITEM_CONFG_ID` `lov` + `cascade: ITEM_CODE` | legacy lot LOV (ITEM_CONFG_LOV / CONFG); the row rule still checks the lot and its balance |
| Button "ملف العملاء" opens the customers screen (CUSTOMER) | `links` | DET_C: `CALL_FORM(... 'CUSTOMER' ...)` with P_CODE = the customer; the APEX link opens the customers list (a link can fill page items only, not select a record by its key), so the customer is searched there |

Tested on the build copy: every list query and computed expression runs (`tmp\w3b_st\sqlcheck.py`, lot list with item 101010006); the cost / balance gates checked in an APEX session (`t_gates.py`, rolled back, session removed).
Still not reproduced: the balance / cost / totals per line (STORE_BALANCE, STORE_COST, LINE_TOTAL_CURR, NET_SALES_PRICE ...): their
program units are not in the evidence in a readable form for these lines; the document totals are in the info panel. Links to
ST_STORE_ITEM_VIEW / ST_PROPOSAL_VIEW / SYS_DOCS: not screens of the application.

## Coverage
Reproduced: numbering, defaults, validations, approvals, read-only states, line derivations (wave 2, APP_RULES_SA); conversion to a sales
order (TO_ORDER, APP_CONV); wave 3 X1-X7 and I1 above.

Deliberately not reproduced:
- Forms-only mechanics: CLOSE_UPDATE as item / block properties (reproduced as refusals), highlighting, KEY-CREREC / KEY-UP / KEY-DOWN
  "open record without details" navigation checks (the page saves the header first and requires lines from the next save), per-line
  auto-commit, the approval worklist REQ_LIST / FILL_REQ_LIST (list page filters), CHANGE_LANG, RESET_BTN / REFRESH (re-query).
- Buttons that only open other screens: PROPOSAL_VIEW_BTN (class ratios view), ITEM_BAL (store item view) - view forms that are not
  screens of the application (DET_C is a link since wave 3b),
  PROPOSAL_TERMS / TAX_SHOW / TAX_EXIT / EXIT buttons (navigation); the double-click filters of the counters (VIEW_DETAIL_BLOCK: grid filters).
- TO_SALES_INV_BTN / INSERT_ISSUE_TRNS: disabled in the legacy (the program unit starts with `RETURN;`).
- MAKE_ORDER running INSERT_ANOTHER_PROPOSAL when a split type was left in the other window: an accidental combination of two windows;
  APEX keeps the two actions separate.
- Legacy non-blocking messages before a conversion ("يوجد عدد أصناف N غير مختارة", "إجمالي سعر الإصناف المحولة لا تساوي …"): shown as
  displays (NOT_CHOSEN, CHOSEN_NET next to NET) instead of a message box.
- Printing (another agent), WEBUTIL error file (the skipped rows are in the message), dongle, SET_IP, ZATCA / RSD.

Deviations (for review): UNIT_COST of the transfer issue lines (question 7); the transfer lines take min(lot balance, rest) in basic units
(the legacy bookkeeping mixed units and basic units, identical for factor 1, which every quotation line has); a transfer made already makes
the button refuse with "تم عمل حركة تحويل من عرض السعر من قبل" (legacy: silently nothing). As in the legacy, the dates of the split
quotation and of the transfer are not checked (their WHEN-VALIDATE-ITEM tested ORDER_DATE, another item; the transfer is still subject to
the closed-period trigger CLOSE_ST_TRNS_MAST); the transfer-request date is checked (≥ quotation date, CHECK_DATE).

## Tests (ROLLBACK)
`t_so.py` (quotation part): 15 checks — header validations incl. department category, DATE_SERIAL / expiry / store / salesman,
expired lot, default price and header copies, choice + unavailable, price right, approval order, credit, stamps, approval 3 right,
converted quotation read-only, after-save.
Conversion (`t_conv.py`, run outside APEX and inside a simulated APEX session of page 60011 with the generated triggers active):
credit first, unapproved, converted (DOC_NO on the invoice / live order), cancelled order makes it convertible again, date before the
quotation / in the future, stock shortage with today's stock, order 10201/546 re-created identical (9 lines, lot split 1564 / 916 / 729),
approvals and audit, bypass released, DOC_NO from the sequence when empty (test number instead of the sequence), no chosen line, credit
limit, missing order / invoice type, user without the approval entry 31/2 — 23 checks. History comparison: `hist_qt.py` (1,303
orders, see above).
