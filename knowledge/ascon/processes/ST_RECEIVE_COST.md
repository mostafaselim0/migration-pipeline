# ST_RECEIVE_COST — فاتورة المشتريات / Purchase invoices (system 30, serial 5)

Deliverable: **screen correction + business rules** — `overrides/ST_RECEIVE_COST.json` (pattern MASTER_DETAIL + `rules`),
package `APP_RULES_PR` in `app/db/21_rules_pr.sql`. Confidence: **medium** (numbering, lot configuration, costs, dues and
locks are well evidenced and verified against the data; supplier-total formula, VAT and several Forms-only mechanics are not).

## Purpose and tables
Purchase invoice of goods into a store: header `ST_TRNS_MAST`, lines `ST_TRNS_DET`, supplier expense lines `ST_TRNS_DET_EXPENS`,
due-date instalments `ST_TRNS_DET_DUES`. Types: `ST_TRNS_TYPE.EFFECT = 1 AND TRNS_TYPE IN (1,5) AND NVL(NO_COST,0) = 0`
(10801-10804, SUPPLIER_TRNS_CODE 101). About 60 % of the invoices are generated from incoming lots (PR_INCOME_LOT
"transfer to stores", `INCOME_TRNS_TYPE_CODE/SERIAL`), the rest are typed here. GL / AP / AR posting is a separate process
(ST_POSTING, APP_PROC_ST) that reads the lines and `ST_TRNS_DET_DUES` (one VN_SUBTRNS bill per instalment).

## Why a screen correction
The generated screen was fully read-only: the .fmb blocks have insert/update/delete = false at design time and the form opens
them at runtime from the user's rights (`WHEN-NEW-FORM-INSTANCE` → `APPLY_SEC`, `DEF_USR_SEC`, `CLOSE_ACC`, `CLOSE_POSTED`).
In APEX the page authorisations do that job, so the override is MASTER_DETAIL with DML enabled. Columns = the generated
screen's visible columns, plus `ST_TRNS_DET.EXPIRY_DATE` (the lot's expiry date: the legacy item EXPIRE_DATE was a non-database
item). Details: lines, supplier expenses, due dates. Side effect of the override: check boxes show as 0/1 number fields.

## Rules implemented
| # | Rule | Where | Evidence |
|---|------|-------|----------|
| 1 | List filter: purchase types, `DELETE_FLAG = 0` (or moved documents), password filters on store / type / supplier / posting supplier (`:G_PASSWORD_NUMBER`) | `rules.where` | block ST_TRNS_MAST WHERE; `:PARAMETER.COST_EXIST` resolved to 'Y' (this menu entry is the costed invoice) |
| 2 | Default type = lowest allowed purchase type, default store = the type's store (active, not stopped), entry date today | `defaults` | record group TRNS_TYPE; TRNS_TYPE_CODE WVI; ENTRY_DATE PRE-TEXT-ITEM |
| 3 | Type must be a purchase type the user may use; type cannot change after saving | validation `check_st_header` | TRNS_TYPE record group, PRE-TEXT-ITEM |
| 4 | Store mandatory, active and not stopped (on create / change) | same | PRE-INSERT "يجب إدخال رقم المخزن", "المخزن الحالى متوقف" |
| 5 | Date ≥ ST_BASIC.MIN_DATE and > AC_BASIC.CLOSE_DATE (on create / change). The AC_BASIC MIN/MAX window is **not** duplicated (DB trigger CLOSE_ST_TRNS_MAST) | same | TRNS_DATE WVI |
| 6 | Rate > 0, local currency rate = 1 | same | CURRENCY_RATE WVI |
| 7 | Date / currency / rate / store fixed once lines exist | same | PRE-TEXT-ITEM of TRNS_DATE, CURRENCY_RATE (store: safeguard, see deviations) |
| 8 | Supplier (if given) active (SUPPLIER_STATUS = 1) | same | SUPPLIER_RG |
| 9 | Due date ≥ transaction date; DUE_DAYS ↔ DUE_DATE | validation + ST_TRNS_MAST row rule | DUE_DATE / DUE_DAYS WVI |
| 10 | Document number not repeated when ST_BASIC.DOC_REPEAT = 2 (3 = confirm → allowed) | validation | CHECK_DOC_NO |
| 11 | Posted (POST_FLAG / SUPP_POST_FLAG / CUST_POST_FLAG), cancelled or closed-period invoice is read-only (header + lines) | validation `check_st_locked` (SAVE) | ENABLE_DISABLE_UPDATE, CLOSE_POSTED, CLOSE_ACC |
| 12 | Numbering TRNS_SERIAL = max+1 per type | generated APPX key (no key_expr: table shared) | PRE-INSERT |
| 13 | INVOICE_NO = type ‖ LPAD(serial,7,'0') when empty; POSTING_SUPPLIER_CODE = supplier; PURCH_CODE (VN_SUPP_RESP), GLN (RSD_SUPPLIER_GLN), currency/rate from the supplier when left at local currency; DELETE_FLAG 0 | ST_TRNS_MAST row rule | PRE-INSERT, SUPPLIER_CODE WVI (data: INVOICE_NO format on all typed invoices) |
| 14 | Line: group from item (ITEM_CODE unique), basic unit, BONUS ↔ BONUS_RATIO, EXTRA_BONUS ↔ ratio, cascading DISC1-3 ratio/value on UNIT_PRICE_CURR, BASIC_QTY = (qty+bonus+extra) × factor, UNIT_PRICE = UNIT_PRICE_CURR × rate, COST_FLAG = 1 | ST_TRNS_DET row rule | ITEM_CODE / UNIT_CODE / QUANTITY / BONUS* / DISC* / UNIT_PRICE_CURR WVI — formulas verified on all 1 949 purchase lines |
| 15 | Line quantity + bonus > 0, price not null / not negative | same | PRE-INSERT, QUANTITY / UNIT_PRICE_CURR WVI |
| 16 | Lot configuration: LOT_NUMBER, EXPIRY_DATE (when the item group has EXPIRE_FLAG), PRODUCTION_DATE, SALES_PRICE, SALES_DISC_RATIO, unit mandatory; ITEM_CONFG_ID = GET_CONFG_ID(..., create) with the invoice supplier and store | same → `receive_line_confg` | PRE-INSERT "يجب إدخال محددات الشحنات", GET_THE_CONFIG |
| 17 | Item may not have a posted non-receipt movement dated after the invoice | same → `check_next_posted` | CHECK_NEXT_POSTED_TRANS |
| 18 | Unit cost: line value in riyal / basic qty + master expenses (freight, customs, transport, commission, insurance, others, supplier freight/insurance/others) spread by value − invoice discount; then one average cost per item and lot price | after-save `receive_after_save` (+ first value in the row rule so ST_TRNS_DET_C_IN gets a cost) | KEY-COMMIT → CALC_UNIT_COST, GET_NDB_*, UPDATE_COST — formula reproduces 98 % of stored UNIT_COST |
| 19 | At least one line (SAVE), at most ST_BASIC.TRNS_MAX_ITEMS lines | after-save | PRE-INSERT "لا يمكن حفظ الفاتورة بدون أصناف", MAX_ITEMS_ALERT |
| 20 | Supplier expense lines ≤ invoice expenses | after-save | CHECK_DET_EXP |
| 21 | Items after discounts ≥ 0; paid (PAYMENT + ATM) ≤ supplier total | after-save | KEY-COMMIT, PRE-INSERT |
| 22 | Due instalments always add up to the supplier total: first instalment created (date = invoice date) or the first one adjusted; none negative; due dates ≥ invoice date; POSTING_SUPP_DUE_DATE = SUPP_DUE_DATE, AMOUNT = AMOUNT_CURR × rate | after-save + ST_TRNS_DET_DUES row rule | KEY-COMMIT, CHECK_NEW_DUE, dues PRE-INSERT / WVI — total formula matches all 550 invoices |
| 23 | Stock of every lot of the invoice may not go negative from the invoice date on | after-save / delete → `check_stock` | KEY-DELREC (UPDATE_NEXT_TRNS_CONFG "الرصيد لا يسمح") |
| 24 | Delete: refused for posted / closed-period invoices (committed row read by flashback query); lines (cost reversal by ST_TRNS_DET_C_DL), dues and expenses removed; the incoming lot of a lot-generated invoice released (POST_FLAG 0, PU_TRNS_* null) | after-save when DELETE `st_after_delete` | KEY-DELREC, PRE-DELETE |
| 25 | Expense lines: local currency rate 1, rate > 0 | ST_TRNS_DET_EXPENS row rule | CURRENCY_RATE WVI |

Not duplicated (existing DB triggers): CLOSE_ST_TRNS_MAST, ST_TRNS_MAST_TAX / ST_TRNS_DET_TAX (tax period locked),
ST_TRNS_MAST_IN (DATE_SERIAL), *_ALTKEY, ST_TRNS_DET_C_IN / C_UP / C_DL (ST_TRNS_DET_COST and cost propagation), ST_TRNS_MAST_UP.

## Dropped (Forms-only)
> Wave 3: several items below are implemented now - see the sections "Wave 3" and "Coverage" at the end of this file.
CUSTOMER_ACCOUNT_BALANCE dongle check, alerts / confirmations (future date, empty supplier, repeated document number when
DOC_REPEAT = 3, max-limit warnings), SET_IP, WEBUTIL, printing (PU_INVOICE_SDI), hilight triggers, POST_BUT / REVERT_BUT
(posting process), contract link buttons, customer-specific branches (SDI, AZZ, TOK).

## Deviations / notes
* ~~APEX DELETE is physical~~ - wave 3: logical delete as the legacy (DELETE_FLAG = 1, lines kept and flagged, lot released).
* The lot parameters are typed in `ST_TRNS_DET.LOT_NUMBER / EXPIRY_DATE / SALES_PRICE / SALES_DISC_RATIO` (legacy used non-database
  items), so these columns are now filled on typed lines. `LOT_NUMBER` is NUMBER in ST_TRNS_DET (ST_ITEM_CONFG.LOT_NUMBER is
  VARCHAR2): alphanumeric lot numbers cannot be typed here (lot-generated invoices are not affected).
* The riyal expense / discount columns (FREIGHT_VAL … DISC_VAL, SUPP_*_VAL, expense-line values) are entered directly (legacy
  entered the currency amounts in non-database items and converted).
* Store change after lines exist is refused (safeguard: ST_TRNS_MAST_UP does not move the lines).
* Trigger order: APPX_ST_TRNS_DET / APPX_ST_TRNS_MAST were created after the legacy triggers and fire first (tested on 19c:
  later-created BEFORE ROW triggers fire first), so ST_TRNS_DET_C_IN and the ALTKEY triggers see the derived ITEM_CONFG_ID /
  BASIC_QTY / UNIT_COST / TRNS_SERIAL. This is not guaranteed by Oracle: recommend `FOLLOWS APPX_<table>` on the legacy triggers.

## Open questions for the key user
1. Supplier total (SUPP_TOTAL_AFTER) was a Forms formula not in the evidence: implemented as items after line discounts −
   3-level invoice discounts + line VAT + header VAT − invoice discount + supplier expenses (verified only where these are 0).
2. ~~VAT not computed~~ - wave 3: GET_TAX_VALUE / GET_TAX_VALUE_MAST reproduced for changed lines, expense lines and the header.
3. 3-level invoice discounts (TOT_DISCn, DISC_ADJUST / GET_ACT_DISC) are not spread into the unit cost.
4. ~~Lot-generated invoices: adding / deleting lines not enforced~~ - wave 3: refused on save.
5. Header update was also blocked when later posted documents existed in the store (POST_TRNS) — not enforced (item-level
   CHECK_NEXT_POSTED_TRANS is).
6. 3 existing returns (10901/26, 40, 42, item 101010569 lot 64) already give a negative running balance: edits touching that
   lot will be refused by rule 23 until the data is corrected.

## Tests (build copy, all rolled back)
Header checks (type, closed period, rate, due date, store, supplier, date change with lines, type change), lock on a posted
invoice, lines required, 2-line invoice → unit costs with freight spread, one due of 150 created, supplier-expense excess,
payment excess, return exceeding the lot → negative stock refused, delete of a committed unposted invoice (10803/222: lines,
dues and cost rows removed), delete of a posted invoice refused. Row rules compiled and exercised on scratch copies of the tables.

## Wave 3 (soft delete, warnings, posting, VAT)

Installation code: `:GLOBAL.CUSTOMER_CODE` comes from `SELECT CUSTOMER_PAR.CUSTOMER_CODE FROM CUSTOMER_PAR` (Sysmenu.fmx ENTER_LOGIN); CUSTOMER_PAR has 0 rows on the build copy (and in the production discovery), so the code is NULL: `= 'SDI' / 'RSD' / ...` branches never run and `!= 'RSD'` / `NOT IN (...)` tests are NULL, i.e. skipped too, exactly as in the legacy PL/SQL.

| Legacy | APEX | Evidence / notes |
|---|---|---|
| KEY-DELREC: posted -> "لا يمكن حذف حركات مرحلة"; each line: running balance of the lot configuration without the line (GET_BALANCE_CONFG + UPDATE_NEXT_TRNS_CONFG) -> "الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها."; DELETE_FLAG := 1 (lines flagged by ST_TRNS_MAST_UP); lot of a lot-generated invoice released | `soft_delete` (check `app_act_pr.st_delete_check`, lines kept) + after-save DELETE `st_after_soft_delete` | data: 39 cancelled purchase documents, 179 / 179 lines flagged, no DELETE_USER / DATE; CLOSE_POSTED / CLOSE_ACC: posted, cancelled or closed-period documents cannot be deleted |
| TRNS_DATE WHEN-VALIDATE-ITEM CUSTOM2_ALERT "تاريخ الحركة أكبر من تاريخ اليوم" (continue / cancel) | `warnings` FUTURE_DATE -> `st_date_warning` | new document or changed date |
| SUPPLIER_CODE WHEN-VALIDATE-ITEM CUSTOM2_ALERT "الحركة بدون مورد" | `warnings` NO_SUPPLIER -> `st_supplier_warning` | new document without supplier or supplier removed (WVI of a never-touched item did not fire in Forms: small difference on new documents) |
| CHECK_DOC_NO, ST_BASIC.DOC_REPEAT = 3: "رقم المستند مكرر، هل تريد الإستمرار؟" | `warnings` DOC_REPEAT -> `st_doc_warning('RECEIVE')` | types EFFECT 1 / TRNS_TYPE 1; DOC_REPEAT is 1 on this site (warning inactive, = 2 refuses: wave-2 validation) |
| QUANTITY / BONUS / EXTRA_BONUS WVI (message level 0): "!!رصيد الصنف سوف يزيد عن الحـد الأقصي" + "الحد الأقصى هو  = " | `info` MAX_LIMIT -> `st_max_limit_info` (lines whose quantity + bonus + extra > ST_STORE_ITEM.MAX_LIMIT) | STORE_BALANCE of the legacy condition is never filled (NULL): only the line quantities count, as in the legacy |
| POST_BUT "ترحيل السند" / "إلغاء الترحيل" (ST_POSTING_CPOSTING for this document, POST_ON_LINE, FILTER 1 / 2, CHECK_FILE_PREV(45, 2)) | actions POST (GL, AP) / UNPOST (GL, AP, collected vouchers) -> `app_proc_st.post_cancel` for the document | the posting page's check boxes are the action parameters |
| GET_TAX_VALUE on the line WVIs (value LINE_TOTAL_RYAL), GET_TAX_VALUE_MAST on the header (discount share, transport tax), expense lines (TOTAL_SUPP_LINE, supplier of the line) | `app_rules_pr.receive_after_save` -> `st_lines_derive` (changed lines by flashback) | line formula verified on 1 829 / 1 839 typed and lot-generated invoice lines; header VAT 0 on all documents (no discount / transport) |
| CLOSE_POSTED: an invoice generated from an incoming lot allows line updates but no line insert / delete | `st_lines_derive`: added / removed lines refused ("فاتورة مولدة من رسالة واردة: لا يمكن إضافة أو حذف أصناف") | own message (the legacy disabled the actions) |

Tests (build copy, all rolled back, plain and inside a simulated APEX session of app 100 with the regenerated APPX_ triggers; scripts in the job folder `tmp\w3_purch`: t_vn.py, t_po.py, t_lot.py, t_st.py, t_quot.py, t_reg.py; static check chk.py): warnings (future date, no supplier, DOC_REPEAT 1 / 3); max-limit text; post (GL + AP) and cancel posting of 10803/221;
refusals for a posted invoice, a closed period (posting engine) and stock issued afterwards (10801/173); soft delete (header flagged, lines
flagged, second delete refused) and release of the lot of a lot-generated invoice; VAT 15 % of a changed line (512.38), other lines
untouched, header share of a discount; removed line of a lot-generated invoice refused - t_st.py; 80 existing purchase documents saved
unchanged keep VAT and prices - t_reg.py.

## Wave 3b
Evidence: `ST\FMB\ST_RECEIVE_COST_fmb.xml` (item properties, record groups, triggers).
* Block settings not changed: the .fmb blocks are opened / closed at run time (DEF_USR_SEC, CLOSE_POSTED, CLOSE_ACC); the wave-2 rules
  keep posted documents read-only.
* `readonly_after_insert` where the .fmb has UpdateAllowed = false and no trigger re-enables it: header TRNS_TYPE_CODE, STORE_CODE,
  CURRENCY_CODE, GLN, SUPPLIER_REF, ATM_DESC; lines ITEM_CODE, UNIT_CODE, UNIT_PRICE_CURR, QUANTITY, bonus / extra bonus and their
  ratios, DISC1-3 and supplier discount (ratio and value), EXPIRY_DATE, SALES_PRICE, SALES_DISC_RATIO, PRODUCTION_DATE, LOT_NUMBER;
  expense lines' CURRENCY_CODE. A saved line is corrected by deleting it and entering it again, as in the legacy form. Left editable
  because triggers re-enable them: ENTRY_DATE / TRNS_DATE / CURRENCY_RATE (PRE-TEXT-ITEM), DOC_NO (WHEN-NEW-RECORD-INSTANCE), SUPPLIER_CODE,
  CUSTOMER_CODE, PURCH_CODE, accounts, cost centres (HIDE_SHOW_ITEMS), expense values (SHOW_HIDE_COST).
* Check boxes 1/0: POST_FLAG, SUPP_POST_FLAG, CUST_POST_FLAG (read-only) and ST_TRNS_DET_DUES.PAYED_FLAG "مسدد" (default 0).
* Legacy LOVs as lists: TRNS_TYPE (purchase types 1/1 and 1/5 with costs, type rights), STORE_LOV (store-chart rights), SUPPLIER_LOV
  (active, range), ACCOUNT_LOV, SALESMAN_LOV (VN_RESP) on PURCH_CODE, CUSTOMER_LOV (not stopped, AR_CUSTOMER_PASSWORD range), SUPP_CNTRCT
  (agreements of the supplier: cascade), EXP_SUPPLIER_LOV on the expense lines, ITEM (items with their basic unit), UNIT (units of the
  item: cascade).
* `rules.computed` ITEM_NAME_A "إسم الصنف" on the lines.
* Check: `check_forms.py ST_RECEIVE_COST`.

## Coverage
Reproduced: wave-2 rules plus logical delete, the continue? alerts, max-limit message, posting from the document and the VAT
calculation (wave 3); legacy lists, check boxes, the .fmb update restrictions after insert, item name (wave 3b).

Not reproduced, with the reason:
* COLL_BUT "تجميع الاذون" / REVERT_BUT "استعادة اذون" (collecting receipt notes into one invoice, MOVE_TRNS): COLCT_FLAG and
  OLD_TRNS_TYPE_CODE are empty on all 662 purchase documents - feature unused (question for the business).
* Contract link buttons (CNTRCT_SERIAL): 0 documents with a contract.
* DISC_ADJUST "توزيع" / CALC_TOT_DISC (3-level invoice discounts spread into the unit cost): no invoice uses TOT_DISC1..3 (data), left
  as in wave 2.
* Header update block when later posted documents exist (POST_TRNS in ENABLE_DISABLE_UPDATE): item-level CHECK_NEXT_POSTED_TRANS is
  reproduced; the header-level rule needs the whole POST_TRNS unit (question).
* Posted lot-generated invoices kept their due dates editable (CLOSE_POSTED): APEX blocks the save of posted documents entirely.
* Printing (ENTRY_PRINT, PU_INVOICE_SDI), INSERT_SN (RSD GTIN serials), CONV_FROM (unit conversion window, Forms helper), dongle, SET_IP,
  WEBUTIL, customer branches.
