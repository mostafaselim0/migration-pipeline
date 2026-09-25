# ST_ISSUE_IO: sales invoices (فواتير المبيعات), registry 31/7

**Deliverable:** screen rules (pattern AUTO), `app\legacy\overrides\ST_ISSUE_IO.json`, package `APP_RULES_SA`
(`app\db\21_rules_sa.sql`: `trns_mast_row`, `trns_det_row` / `trns_det_row2`, `trns_srv_row`, `si_validate`, `si_after_save`) and,
since wave 3, package `APP_ACT_ST` (`app\db\23_act_st.sql`: `si_delete_check`, `si_after_delete`, `si_can_delete_order`,
`si_delete_with_order`, `si_info`).
**Confidence:** high for numbering, filters, derivations, stock / price / order checks, soft delete, lot split; medium for the credit-limit
timing, the header discount fields and the TOT_VAL formula.

## Purpose and tables
The most important document of the business: a customer invoice that issues stock. Master `ST_TRNS_MAST`, lines `ST_TRNS_DET`, services
`ST_TRNS_SERVICES`. ST_TRNS_MAST / ST_TRNS_DET are shared with the stock and purchasing screens; every rule below only acts on the
sales-invoice kind (`doc_kind` = SI: `ST_TRNS_TYPE.EFFECT = 2 AND TRNS_TYPE IN (2,5)`, today types 10301, 20301, 30301, one per
department / store). Data: 1,335 invoices, 1,318 live, 1,301 created from sales orders; all live invoices are posted.

Installation code (`:GLOBAL.CUSTOMER_CODE`, read by the ASCON menu from `CUSTOMER_PAR`): the table is empty in production
(`_discovery\05_tables_rows.csv`), so the code is NULL and none of the `'MAR'` / `'SDI'` / `'ZED'` / `'SAN'` branches of the form applies
(`!= 'SDI'` tests are NULL too, i.e. their ELSE branch runs).

## Rules implemented
| # | Rule | Where (APEX) | Legacy evidence |
|---|---|---|---|
| F1 | List shows only sales-invoice types, not deleted (`DELETE_FLAG = 0`), and for users of a group other than 0 only types in `ST_TRNSTYPE_PASSWORD` (FLAG = 1) | `where` | block ST_TRNS_MAST WHERE (evidence l.494) |
| D1 | New invoice: transaction type defaults to the first sales-invoice type allowed to the user (the type of the user's `MAIN_STORE_CODE` first) | `defaults` + `first_type('SI')` | LOV TRNS_TYPE (l.7824); no legacy default: convenience |
| V1 | Type must be a sales-invoice type allowed for the user's group (types and their store: `ST_TRNSTYPE_PASSWORD`, `ST_STORE_PASSWORD`); cannot change after save | `si_validate` | LOV TRNS_TYPE (ValidateFromList), PRE-TEXT-ITEM |
| N1 | `TRNS_SERIAL` = max + 1 per type | generated APPX key (same as legacy) | PRE-INSERT l.1080 |
| N2 | `DOC_NO` = `GET_ACT_DOC_NO_INVOICE` (sequence `DOC_NO_SEQ`, shared with orders and quotations); from the sales order when the invoice is created from one (wave 3: the sequence is only drawn when no number is given — the former NVL drew a number for every invoice made from an order) | row rule | PRE-INSERT l.1188; ST_SALES_ORDER make-invoice |
| N3 | `INVOICE_NO` = `YYYY` of the date + serial left-padded to 7 | row rule | PRE-INSERT l.1104 |
| N4 | `DATE_SERIAL`: left to the DB trigger `ST_TRNS_MAST_IN` (sequence); page item made optional | `optional` | DB trigger |
| D2 | Store = store of the type (active store); currency 1 / rate from `AC_CURRENCY`; salesman = `GET_LAST_SALESMAN_INDATE(customer)`; `DUE_DAYS` = `CUSTOMER.DAY_NO`, `DUE_DATE` = date + days; `DESC_A/E` = type name + " حركة رقم type/serial"; `DELETE_FLAG` / `PRINT_FLAG` = 0 | row rule (insert) | TRNS_TYPE_CODE / CUSTOMER_CODE WHEN-VALIDATE-ITEM, DESC_A WHEN-NEW-ITEM-INSTANCE |
| V2 | Store active and allowed; date: only users with `USERS.CHANGE_INV_DATE_FLAG = 1` (or user 0) may use a date other than today / change it; no future date; date after `AC_BASIC.CLOSE_DATE`; not before the customer's last salesman transfer | `si_validate` | SET_DATE_PRV l.6522, CHECK_DATE l.7038 |
| V3 | Customer required (JOIN_TYPE 3) and as in the legacy customer list: not stopped, `CUSTOMER_STATUS = 1`, area set, has a salesman, allowed for the group | `si_validate` | CUSTOMER_RG l.7881 |
| V4 | Salesman required when the type has `HAS_SALESMAN = 1` and none can be derived; must be one of the customer's salesmen (SALESMAN_VIEW), not stopped | `si_validate` | SHOW_HIDE_ITEMS, SALESMAN_RG l.8142 |
| V5 | Rate > 0; rate 1 for currency 1 | `si_validate` | CURRENCY_RATE WHEN-VALIDATE-ITEM l.2116 |
| V6 | Class only for users with `ENABLE_CHANGE_CLASS = 1` or group 0; store / customer / salesman / currency / rate / class / sales order frozen once lines exist ("برجاء حذف الاصناف اولا") | `si_validate` | PRE-TEXT-ITEMs, CLASS_CODE WHEN-VALIDATE-ITEM l.1957 |
| V7 | Sales order reference (ORDER_TRNS_*): order exists, approved 1 and 2, not closed / cancelled, not already converted, same customer, dated on or before the invoice, remaining quantity, order type maps to this invoice type (`SALES_TRNS_TYPE_CODE`) | `si_validate` | RFQ record group l.8123; ST_SALES_ORDER INV_TRNS checks |
| A1 | Invoice created with an order reference: the order lines are copied into the invoice (all line rules run on each), the order gets `SL_TRNS_TYPE_CODE/SERIAL`, DOC_NO / customer / salesman / quotation link / transport / description come from the order | `si_after_save` (CREATE) + row rule | ST_SALES_ORDER.INSERT_ISSUE_TRNS / INSERT_DET (agent report); data: invoice lines are exact copies of order lines |
| L1 | Line derivations: group from `ST_ITEM`; unit = basic unit when empty; `BASIC_QTY = (QTY + BONUS + EXTRA_BONUS) × FACTOR`; `UNIT_PRICE = UNIT_PRICE_CURR × rate`; discount values from ratios (level n on the price left by levels < n; a value alone gives the ratio); `EXTRA_BONUS` from its ratio; `COST_FLAG = 1`, `UNIT_COST = NULL`; line store = header store | row rule | ITEM_CODE / UNIT_CODE / QUANTITY / DISCn WHEN-VALIDATE-ITEM, PRE-INSERT l.3237 |
| L2 | Policy values `ORG_*` from `CALC_SALES_DISC` (customer / class / lot); with `AUTO_DISC = 1` price, discounts **and (wave 3) bonus / extra bonus of a manual line** are the policy values (`BONUS := ROUND(ratio × qty / 100)`, `EXTRA := TRUNC(...)`, the quantity rounded to the bonus steps); new lines start with `AUTO_DISC = 1` (legacy initial value) | row rule, `defaults` | CALC_SALES_DISC_TOT l.7158, AUTO_DISC InitializeValue = 1 (ST_ISSUE_IO_fmb.xml) |
| L3 | Lot (ITEM_CONFG_ID): the site setting `ST_BASIC.INSERT_SALE_CNFG = 1` (manual lot) applies — (wave 3) a line **without lot and with `AUTO_DISC = 1` is split over the lots by expiry** (DEVIDE_CONFGS: each lot gives its minimum balance from the line's position on, `GET_MIN_BALANCE_CONFG_AFTER`; this line keeps the first lot, the other parts become new lines with the price / discounts of the first part and the policy values of their lot; not enough stock → "أقصى كمية يمكن إخراجها حتى لا تتعارض مع الحركات التالية = …"); **without lot and `AUTO_DISC = 0` → "يجب إدخال رقم الشحنة"** (PRE-INSERT); with `INSERT_SALE_CNFG = 0` the earliest-expiry lot with stock (automatic mode) | row rule (`trns_det_row2` + `si_after_save`) | QUANTITY KEY-NEXT-ITEM l.4044, DEVIDE_CONFGS l.7260, PRE-INSERT l.3239, ITEM_CODE WHEN-VALIDATE-ITEM l.3589 |
| L4 | Errors: item stopped / unknown, unit not of the item, price required, price below the basic unit's retail price ("السعر يجب ان يكون اكبر من سعر التجزئة"), qty + bonus ≤ 0, negative discounts, discounts ≥ price, lump discount > line, item not on the sales order, quantity above the order balance (`GET_PROPOSAL_UNIT_RFQ`) | row rule | UNIT_PRICE_CURR l.3894, BONUS l.4091, DISCn, PRE-INSERT l.3244-3276 |
| L5 | Stock (ST_BASIC.NEG_SALE_BALANCE = 0, the current setting): lot balance before the line ≥ qty × factor, and later transactions of the lot must not go negative (`UPDATE_NEXT_TRNS_CONFG`) | row rule | PRE-INSERT l.3295, POST-INSERT l.3334 |
| L6 | VAT per line: port of `TAX_LIB(_NEW).GET_TAX_VALUE` (customer in TX_TAXES_CUSTOMERS → item rate, else TX_TAXES_ITEMS rate; area never passed) on LINE_TOTAL; `TAX_CODE1 / TAX_VALUE1` read-only | row rule, `line_tax` | GET_TAX_VALUE (pll TAX_LIB_NEW__1881 / TAX_LIB__3860); data: 15 % × line total |
| S1 | Services: default price from `ST_PD_SERVICES.UNIT_COST`, price > 0, units default 1, tax from `TX_TAXES_SERVICES` | row rule | ST_TRNS_SERVICES triggers l.4697-4758 |
| A2 | Invoice from a sales order: lines cannot be added / deleted later | `si_after_save` (snapshot) | CLOSE_POSTED l.5780 |
| A3 | Invoice discount (`DISC_VAL`, hidden on the page) below the invoice and within `USERS.MAX_DISC_RATIO`, spread per line into `DISC` (GET_NDB_DISC); header discounts `TOT_DISC1..3` cascade (ratio → value on the remaining total); `TOT_VAL` = lines net + line VAT + services − discounts (rounded) | `si_after_save` | DISC_PRC_CURR / DISC_VAL_CURR l.2164-2289, VALIDATE_TOT_DISC1..3, PRE-INSERT `:TOT_VAL := :NET_VALUE_CURR` |
| A4 | Credit limit: `NVL(CUSTOMER.CREDIT_LIMIT,0) < GET_CUSTOMER_BAL_ALL(customer)` (which already contains this unposted invoice) → "هذا العميل تخطى الحد الائتمانى"; checked on create and whenever the invoice total grows | `si_after_save` | master PRE-INSERT l.1128 |
| P1 | Posted documents (POST_FLAG / CUST_POST_FLAG / SUPP_POST_FLAG) and deleted ones are read-only | `si_validate` | CLOSE_POSTED |

## Wave 3 additions
| # | Legacy behaviour | APEX | Evidence |
|---|---|---|---|
| X1 | **Delete = soft delete**: DELETE_FLAG = 1, DELETE_USER, DELETE_DATE; the lines stay and are flagged by the DB trigger `ST_TRNS_MAST_UP` (data: 14 of the 17 deleted invoices have lines, all kept and flagged; the other 3 had none); refused for a printed invoice ("لايمكن حذف فاتورة مطبوعة") and a posted one ("لا يمكن حذف مستند مرحل": CLOSE_POSTED removes the delete right); then the sales order converted into the invoice is released (`SL_TRNS_* = NULL`) | `rules.soft_delete` (lines keep, check `si_delete_check`) + `after_save` DELETE `si_after_delete` | KEY-DELREC l.1368 (detail KEY-DELREC with MASTER_DELETE = 1 only clears the lines from the screen, l.3440), CTRL.DEL_BTN l.4886, POST-UPDATE l.1582 |
| X2 | **"نعم بحذف أمر البيع"** (third answer of the delete question): the sales order lines and header linked to the invoice are deleted (errors ignored), then the invoice is deleted as in X1 | action `DEL_ORDER` "حذف الفاتورة مع أمر البيع" (shown for an unposted, unprinted invoice with a linked order and a user with delete right), `si_delete_with_order`; message "تم حذف الفاتورة t/s وأمر البيع t/s" | CTRL.DEL_BTN alert button 3 l.4914 |
| I1 | Displays of the invoice: credit limit, customer balance (`GET_CUSTOMER_BAL_ALL`), allowed days (`CUSTOMER.DAY_NO`), oldest open debt in days (`GET_CUSTOMER_DAYS_ALL`), the credit / days status (red / green of CHECK_MAST_STATUS as text), the counters "الأصناف" / "مخالف" / "تعدي الحد" (GET_PROPOSAL_INFO) and the totals (items total, invoice net = TOT_VAL) | `rules.info` (`si_info`) | POST-QUERY l.1349, CHECK_MAST_STATUS l.7588, GET_PROPOSAL_INFO l.7610 |
| L3 | DEVIDE_CONFGS lot split and the manual-lot rule (see L3 above) | `trns_det_row2` (row rule string of the override; active with the next build, the current trigger calls `trns_det_row`, which keeps the earliest-lot stand-in for AUTO_DISC lines) | DEVIDE_CONFGS l.7260 |

**Why the delete mechanism changed:** the wave-2 delete (page DML deletes the row, `trns_soft_delete` restores it from its committed image)
lost the lines once the generator started deleting a document's lines before its header (process "حذف تفاصيل المستند", checked on the
in-memory page): the restored invoice had no lines. `rules.soft_delete` updates the header instead and keeps the lines, as the legacy did.
`trns_soft_delete` stays in the package but is no longer called. The line row rule no longer reads ST_TRNS_MAST for updates (the
header update of the soft delete reaches the lines through `ST_TRNS_MAST_UP`, where the header table is mutating).

## Wave 3b (new generator keys)

Evidence: `ASCON\ST\FMB\ST_ISSUE_IO_fmb.xml` (items, record groups, detail POST-QUERY).

| Change | Key | Evidence |
|---|---|---|
| Transaction type and store read-only after insert; store required | `TRNS_TYPE_CODE` / `STORE_CODE` `readonly_after_insert`, `STORE_CODE.required` | `UpdateAllowed="false"`, `STORE_CODE Required="true"` |
| Price-class list from `AR_ST_ITEM_CLASSES` (was the fixed-asset classes `AS_CLASS`, a wrong automatic list) | `CLASS_CODE.lov` | LOV AR_ST_CLASS_DET → RG AR_ST_CLASS `SELECT CLASS_CODE, DESC_A, DESC_E FROM AR_ST_ITEM_CLASSES` |
| Payment-terms list from `ST_PAYMENT_TERMS` | `PAYMENT_TYPE.lov` | LOV PAYMENT_LOV → `SELECT SERIAL, TYPE_NAME, TYPE_NAME_E FROM ST_PAYMENT_TERMS` |
| Per line: item name, lot number "Btch #" and lot expiry (from the lot), "الرصيد" = lot balance before the line / factor (ALLOW_VIEW_BALANCE), "تكلفة الصنف بالريال" = lot average cost, country of origin "CO.O", basic unit "Basic Unit" | `computed.ST_TRNS_DET.*` | display items; POST-QUERY `GET_BALANCE_COST_CONFG(... :ITEM_SERIAL)`, `IF VAR.SHOW_BAL = 1`, `SELECT C.NAME_E INTO :LOC_NAME_E FROM ST_ORG_COUNTRY C, ST_ITEM T ...`, basic-unit query |
| The always-empty table columns `LOT_NUMBER` / `PRODUCTION_DATE` of the lines are hidden (0 of 5 808 invoice lines have them; the legacy items were non-database displays of the lot) | `columns.ST_TRNS_DET.LOT_NUMBER / PRODUCTION_DATE.hidden` | `DatabaseItem="false"` in the .fmb |
| Lot list of the line's item (lot id - lot number - expiry), refreshed when the item changes | `ITEM_CONFG_ID` `lov` + `cascade: ITEM_CODE` | legacy lot LOV (ITEM_CONFG_LOV / CONFG); the row rule still checks the lot and its balance |
| Button "ترحيل السند" opens the posting screen ST_POSTING_CPOSTING with the document's type, serial and date filled in (from / to) | `links` | POST_BUT: `CALL_FORM(... 'ST_POSTING_CPOSTING' ...)` with TRN_CODE / TRN_SER / TRN_DATE |
| Button "ملف العملاء" opens the customers screen (CUSTOMER) | `links` | DET_C: `CALL_FORM(... 'CUSTOMER' ...)` with P_CODE = the customer; the APEX link opens the customers list (a link can fill page items only, not select a record by its key), so the customer is searched there |

Costs are empty unless (USERS.ALLOW_VIEW_COST = 1 and ST_BASIC.SHOW_COST = 1) or the user's group is 0 (legacy GET_USER_SEC); the column itself stays visible (the generator cannot hide a column per user right). The legacy button chose post (FILTER 1) or cancel (FILTER 2) from POST_FLAG; the link cannot set a value that depends on the record, so the operation stays the posting page's default (post) and the user switches it to cancel when needed. Tested on the build copy: every list query and computed expression runs (`tmp\w3b_st\sqlcheck.py`, lot list with item 101010006); the cost / balance gates checked in an APEX session (`t_gates.py`, rolled back, session removed).
Not changed: `ORDER_TRNS_TYPE_CODE / SERIAL` stay enterable (the order-to-invoice conversion types the order reference, wave 2);
`CURRENCY_CODE` / `ACCOUNT_NUMBER1` (disabled at design time, enabled by the form at run time). Still not reproduced: `LINE_TOTAL_CURR`
/ `NET_SALES_PRICE_WBONUS_CURR` per line (computed by program units whose text is not in the evidence; the document totals are the
info panel), `EXP_DAYS`, `AGENT_PERIOD` (production date of the lot is not stored), links to the view forms ST_TRNS_DET_VIEW /
ST_STORE_ITEM_VIEW / SYS_DOCS (not screens of the application).

Second wave-3b sweep (purchasing / sales agent): no further key applies. The list item "نوع الفاتورة" (INV_TYPE / INV_TYPEL) is in
GN_FORM_ITEM but not in the .fmb source, its values are not in the evidence and ST_TRNS_MAST.INV_TYPE is empty on all 1 715 sales
invoices and returns (probably the later e-invoice type; ZATCA is deferred) — not placed, question for the business. The line button
ITEM_BAL (CALL_FORM ST_STORE_ITEM_VIEW) cannot become a row link: that screen is not in the application menu.

## Differences from the legacy form (for review)
- Header first, lines second (APEX): the credit check of master PRE-INSERT is run after the save, and again when lines make the invoice grow.
- The legacy form used the lot price-policy only when `AUTO_DISC` was ticked; the APEX rule requires a price otherwise (legacy: item required).
- DEVIDE_CONFGS: the other parts are inserted after the lines of the grid (legacy: right after the split line), so their ITEM_SERIAL
  follows the last line; when a lot covers the quantity but only part of the bonus, the legacy put the rest of the lot into BONUS *and*
  EXTRA_BONUS (issuing it twice): here BONUS first, then EXTRA_BONUS. Until the next build the page trigger calls `trns_det_row`
  (quantity cannot change): an AUTO_DISC line without lot then takes the earliest lot with stock, as in wave 2.
- Like the legacy list, expired lots with stock are not excluded (lot 156 of item 101011663 is expired and still has 1,600 units).
- Close-date / future-date checks also apply when a user with date rights changes the date (legacy checked only the defaulted date).
- A posted invoice cannot use "delete with the sales order" (legacy deleted the order and left the posted invoice, pending until the next commit).

## Open questions for the key user
1. Should the page offer the order-to-invoice conversion only (as today) or also manual invoices? (21 of 1,335 invoices had no order.)
2. Should expired lots be blocked on invoices (suggested for pharma)?
3. `PRINT_FLAG = 1` blocks deletion (legacy delete button rule); keep?
4. Users of group 102 (e.g. 107) see no invoices because `ST_TRNSTYPE_PASSWORD` is empty in this copy: confirm production grants.
5. "Delete with the sales order" deletes the order physically (legacy): keep, or cancel the order (DELETE_DATE) instead?

## Tests (build copy, all ROLLBACK)
Wave 2: `t_si.py` + `t_so.py` (invoice-from-order part): 45 + 5 checks.
Wave 3: `tmp\w3_sales\f1\t_f1.py` (plain 59 / APEX 66 checks, both passing; ACT_PKG selects the package): delete checks (posted, printed,
deleted), soft delete keeps and flags the lines and cost rows and releases the order (also through the page triggers inside APEX), delete with
the sales order (order and lines gone, invoice flagged, message; refused when printed), displays (credit limit, balance, status, counters,
net), DEVIDE_CONFGS split (first lot and its balance, second part inserted by the after-save with the next lot, price / ratios / policy
values / VAT), the maximum message when all lots cannot give the quantity, manual line without lot refused (new and current row rule and the
real trigger), policy bonus with quantity rounding, deleted invoice's order invoiced again (lines identical, order linked, DOC_NO of the
order, DOC_NO_SEQ untouched).

## Coverage
Reproduced: every rule of the tables above (numbering, filters, header and line checks, derivations, VAT, policy prices / bonus, lot split,
stock checks, invoice from an order, totals, credit limit, posted read-only, soft delete, delete with the sales order, the displays).

Deliberately not reproduced, with the reason:
- **Forms-only mechanics**: dongle check `CUSTOMER_ACCOUNT_BALANCE` (PRE-INSERT), SET_IP, WEBUTIL, show / hide / enable / visual
  attributes (SHOW_HIDE_ITEMS, SHOW_HIDE_CONFIG, AUTO_DISC_VALIDATE, CLOSE_POSTED as properties, colours of CHECK_MAST_STATUS — shown as
  text), navigation keys, the delete confirmation alerts (the page asks), DO_SUM / DO_SUM_TEMP (unit totals window), the worklist of
  unprinted invoices (SHOW.REQ_LIST / FILL_REQ_LIST: navigation), buttons that open view forms which are not screens of the
  application (SALES_VIEW_BTN → ST_TRNS_DET_VIEW, ITEM_BAL → ST_STORE_ITEM_VIEW, DOCS → SYS_DOCS attachments), double-click price
  pickers (WIDE / RETAIL / REDUCTION price copied into the price field). DET_C and POST_BUT are links since wave 3b.
- **Printing** (PRINT_BTN*, ITEM151, ENTRY_PRINT): mapped by the prints agent.
- **ZATCA** (EI_SEND_INVOICE) and **RSD** (INSERT_SN → RSD_TRNS_DET_QTY, GTIN colouring): out of scope.
- **Cash-box / bank vouchers** INSERT_RP_PC_TRNS / UPDATE_ / DELETE_RP_PC_TRNS and the cash-paid check "المدفوع نقدى اكبر من إجمالى
  الاصناف": inactive (SYS_SYSTEMS has no 13 / 15, the sales types have no RP / PC types, PAYMENT / ATM columns hidden and empty).
- **Dead or inactive code**: CHECK_CUSTOMER_STATUS (never called); the unpaid-invoices "continue?" alert (MIN_LIMIT) and the store
  balance "continue?" alert (CUSTOM3) are commented out in the .fmb; CHECK_DOC_NO acts only with ST_BASIC.DOC_REPEAT 2 / 3 (value 1) and
  DOC_NO is not typed; the duplicate DOC_NO per customer category check of PRE-INSERT runs on the typed DOC_NO, which is empty on a
  manual invoice (the invoice from an order is made by the order screen in the legacy); installation branches `MAR` / `SDI` / `ZED` /
  `SAN` (code NULL). No active legacy "continue?" alert remains, so the page has no `warnings`.
