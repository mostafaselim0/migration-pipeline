# VNDBTRN - حركة الموردين المدينة / Supplier Debit Transactions (payments, settlements)

- Registry: system 5 serial 3 (menu `FILES_MENU.ARDBTRNS`, order 104). APEX list page 40040, document page 40041.
- **Deliverable: data-entry screen, `"pattern": "AUTO"` + rules** (`app\legacy\overrides\VNDBTRN.json`; the generated .fmb screen is right).
  PL/SQL: package `APP_RULES_VN` in `app\db\21_rules_vn.sql` (VALID).
- Tables: VN_MAINTRNS (header), VN_SUBTRNS (payment lines against credit invoices), VN_MAINTRNS_ACC / VN_MAINTRNS_SUPP_ACC (other
  accounts), VN_SUBTRNS_ITEMS (item discounts, TAB5), VN_SUBTRNS_BAND (contract bands, TAB4).
- **Confidence: medium-high** - .fmb source (all triggers read); every derivation below was checked against the 349 existing debit documents
  (GL-link balance holds for 100 %, header DISC/CURRENCY_DIFF = line sums 100 %, DESCRIPTION_E suffix on 274/275 payments).

## Evidence (`evidence\VNDBTRN.md`)

- Block VN_MAINTRNS WHERE: `TRNS_ID IN (VN_TRNSTYPE EFFECT = 0 AND TRNS_TYPE <> 5 AND NVL(SUM_TRNS,0) = 0) AND MAIN_TRNS_ID/SERIAL IS NULL AND
  NVL(LINK_FLAG,0) = 0 AND SERIAL IS NULL` + group security (VN_TRNSTYPE_PASSWORD, VN_SUPPLIER_PASSWORD range).
- `VN_MAINTRNS PRE-INSERT`: dongle check (dropped), PO remaining value (`GET_PR_ORDER_VAL`), DOC_NO_VALIDATION, CHECK_SUPP_INFO,
  CHECK_OPEN_BAL, contract bands, stopped supplier ("هذا المورد متوقف"), **numbering `NVL(MAX(TRNS_SERIAL),0)+1` per TRNS_ID and
  `UPDATE VN_TRNSTYPE SET LAST_SERIAL`**, Check_GL_Link, DESCRIPTION_E suffix for payments, CREATE_USER_CODE.
- `PRE-UPDATE`: POST_FLAG = 1 -> alert POST_ALR2; invoices paid <= payment total (unless BILL_PAY_METHOD 3); Check_GL_Link.
- `PRE-DELETE`: posted -> "الحركة الحالية تم ترحليها و لا يمكن حذفها"; deletes the detail blocks. `WHEN-NEW-RECORD-INSTANCE` / `CLOSE_POSTED`:
  POST_FLAG = 1 or PAY_FLAG = 1 -> header and lines read-only; LINK_FLAG != 0 -> read-only.
- Item triggers: TRNS_ID (DOC_FLAG makes DOC_NO required), SUPPLIER_ID (currency and rate from the supplier, VN_SUPP_RESP -> RESP_CODE,
  "يجب حذف التفاصيل قبل تغيير المورد"), TRNS_DATE / ACC_POST_DATE (TRANSLATE.CHECK_DATE: not after today, not before VN_BASIC.MIN_DATE),
  INV_VALUE (TAX_LIB_NEW.GET_TAX_VALUE, TOTAL = INV + TAX1 + TAX2 unless payment / tax-exempt, total > 0, USERS.MAX_PAYMENT),
  CURRENCY_RATE (> 0, = 1 for SAR), DOC_NO (> 0).
- VN_SUBTRNS: PRE-INSERT (value > 0, paid <= payment total, SUPPLIER.SINGLE_PAY), BILL record group (open invoice lines of the supplier,
  same currency, not stopped, residual via `VN_SUBTRNS_PAYED_VALUE`), TOTAL_VALUE / DISC_VALUE / CURRENCY_DIFF_VALUE WVI.
- VN_MAINTRNS_ACC / _SUPP_ACC: PRE-INSERT ACC_SER max+1, ACC_VAL > 0 (VAL_ALR), SET_COST/SET_COST2 (cost-centre requirement), memo prefix
  (supplier id - name) on supplier-account lines.
- `WHEN-CREATE-RECORD`: PAY_METHOD 5 ("حسابات"), BILL_PAY_METHOD 1.

## Rules implemented

| Rule | Where | Detail |
|---|---|---|
| Numbering | `key_expr` VN_MAINTRNS.TRNS_SERIAL = `app_rules_vn.next_trns_serial(:new.trns_id)` | max+1 per type, row lock on VN_TRNSTYPE, LAST_SERIAL := serial (same as legacy). Shared by VNCRTRN (identical text). |
| List filter | `where` | legacy block WHERE, `:GLOBAL.PASSWORD_NUMBER` -> `:G_PASSWORD_NUMBER`. |
| Type default | `defaults` TRNS_ID | `default_trns_id('VNDBTRN')` = 201 (first payment type); PAY_TYPE_CODE = VN_BASIC.PAY_TYPE_CODE. |
| Header validation (CREATE, SAVE) | `check_header('VNDBTRN', ...)` | type belongs to the screen (+ VN_TRNSTYPE_PASSWORD); on SAVE: stored row posted / paid / generated -> read-only (ORA text "الحركة الحالية تم ترحيلها و لا يمكن تعديلها"), type cannot change, supplier cannot change while lines exist; supplier required, exists, on CREATE/change: not stopped, SUPPLIER_STATUS = 1, inside the group's supplier range; currency = supplier currency, rate > 0, SAR rate = 1; TRNS_DATE / ACC_POST_DATE not after today, not before VN_BASIC.MIN_DATE, supplier START_DATE, opening-balance date; DOC_NO > 0 and required when DOC_FLAG = 1; INV_VALUE > 0. |
| Derived header values | `row_rules` VN_MAINTRNS (manual rows only: LINK_FLAG 0, POST_SYSTEM null) | on insert PAY_METHOD 5, BILL_PAY_METHOD 1, PAY_TYPE_CODE, RESP_CODE (min VN_SUPP_RESP), DESCRIPTION_E + " رقم سند المورد <doc>" for payments; TAX_CODE1/TAX_VALUE1 (supplier VAT %) and TOTAL_VALUE = INV_VALUE + TAX1 + TAX2 (payments / exempt suppliers: INV_VALUE) when INV_VALUE, TAX_VALUE2, supplier or date change; ALT_KEY re-computed after the serial (see note). |
| Payment lines (CREATE, SAVE) | `after_save('VNDBTRN', ...)` | each line resolved to one open invoice line of the supplier (by BILL_ID1/BILL_ID2 and/or INV_TRNS_ID/SERIAL): value > 0, discount 0..value, value <= invoice residual (total - other payments), no currency difference in SAR; fills INV_*, BILL_ID1/2, INV_DATE, INV_SUPPLIER_REF, PAY_TYPE_CODE, NET_VALUE = value - discount, CURRENCY_DIFF_VALUE = value * (rate - invoice rate). Header: DISC_VALUE, CURRENCY_DIFF_VALUE = line sums, RESIDUAL_VALUE = total - net lines; net lines <= total (BILL_PAY_METHOD <> 3); single-pay supplier -> 1 line; PO remaining value >= 0; USERS.MAX_PAYMENT; bands only when VN_BASIC.CONTRACT_FLAG = 1 (and then = total); item discounts only for debit settlements (EFFECT 0, TRNS_TYPE 4), ratio 0..100, value >= 0, no duplicate bill/item, sum <= total. |
| GL link (SAVE) | `check_gl_link` | Check_GL_Link with the VN_TRNSTYPE ACCOUNT_JOINT / ACCOUNT_TYPE / SUPP_ACCOUNT_TYPE branches; for the configured types: sum(VN_MAINTRNS_ACC) = round(INV_VALUE * rate, 2) + sum(VN_MAINTRNS_SUPP_ACC). Only on SAVE because the grids appear after CREATE. |
| Account lines | `row_rules` VN_MAINTRNS_ACC / _SUPP_ACC | ACC_VAL > 0; cost centre 1/2 required when AC_BASIC.ALL_COSTn_FLAG = 1 or AC_MASTER.ACC_COSTn_FLAG = 1 (effective result of SET_COST/SET_COST2); supplier lines: ACC_MEMO := "supplier - name - memo". ACC_SER numbering = generic max+1 (legacy identical). |
| Bands | `row_rules` VN_SUBTRNS_BAND | SUPPLIER_ID (hidden PK column) taken from the header. |
| Read-only columns | `readonly` | TRNS_SERIAL, TOTAL_VALUE, TAX_VALUE1, POST_FLAG, PAY_FLAG, ACC_*, RP_*/CHECK_* links, line INV_DATE / INV_SUPPLIER_REF / NET_VALUE / BILL_ID2. |
| Delete (DELETE) | `on_delete` | posted / paid / generated -> error (whole request rolled back). The flags are read from the committed row with a flashback query (`AS OF TIMESTAMP SYSTIMESTAMP`, the header is already deleted in the transaction), page values as fallback; orphan VN_MAINTRNS_SUPP_ACC lines (no FK) removed. |

Not duplicated (existing DB triggers): CLOSE_VN_MAINTRNS (closed period, AC_BASIC), VN_MAINTRNS_TAX / VN_SUBTRNS_TAX (authorised tax
period), VN_MAINTRNS_ALTKEY (ALT_KEY, ACC_POST_DATE := TRNS_DATE). Note: VAT is *not* computed by any DB trigger (the *_TAX triggers only lock
authorised tax periods), so the legacy GET_TAX_VALUE supplier path is reproduced in `calc_tax`.

> Wave 3: several items below are implemented now - see the sections "Wave 3" and "Coverage" at the end of this file.

Dropped Forms-only mechanics: CUSTOMER_ACCOUNT_BALANCE dongle block, alerts/hilight/navigation, SET_ITEM_PROMPT, report printing, FILL_BILLS
button (automatic allocation over open invoices - a helper, not a rule), cash-box / cheque (RP / CK systems 13/15 are not installed:
HAS_RAP_CHK_SYS = 0, PAY_METHOD always 5 in the data), the DOC_NO duplicate *confirmation* (DOC_NO_ASK let the user continue),
maintenance of VN_SUBTRNS.RESIDUAL_VALUE on the paid invoice (stale in the data: 346/641 correct; residuals are computed with
VN_SUBTRNS_PAYED_VALUE everywhere) and of SUPPLIER.CRN_BAL_TOTAL (stale).

## Tests (build copy, all rolled back)

- `next_trns_serial(201)` = 280, VN_TRNSTYPE.LAST_SERIAL 279 -> 280 (back to 279 after rollback).
- check_header: valid -> null; type 103 / stopped / inactive / missing supplier, USD supplier with SAR, SAR rate 2, rate 0, future date,
  date before VN_BASIC.MIN_DATE, future ACC_POST_DATE, DOC_NO -5, type 206 without DOC_NO, INV_VALUE 0, SAVE of a posted payment,
  supplier change with lines -> the legacy messages.
- Synthetic payment 201/280 (supplier 101790100000, 6000): CREATE ok; SAVE without account lines -> ORA-20133; balanced -> ok, line resolved
  to invoice 101/547/1 (BILL 10803213/1, INV_DATE 02/06/2026, NET 4900), header DISC 100, RESIDUAL 1100; line > residual -> ORA-20147;
  lines > total -> ORA-20151; unbalanced -> ORA-20133; unknown bill -> ORA-20145; by invoice transaction id/serial -> ok; discount > value
  -> ORA-20143; on_delete posted -> ORA-20171; posted 202 deleted inside the transaction with page flags 0 -> still ORA-20171 (flashback).
- `check_gl_link` over all 416 existing manual AP documents (103, 201, 202, 207, 208): 0 failures.
- Generated APPX triggers compiled on scratch copies and exercised in an APEX session (`apex_session.create_session`, app 100): taxed supplier
  202 -> serial 63, TAX 2/150, TOTAL 1160 (1000 + 150 + 10), PAY_METHOD 5, BILL_PAY_METHOD 1; payment 201 -> DESCRIPTION_E suffix, no VAT;
  stock-generated row (LINK_FLAG 1, explicit serial) untouched and its TOTAL update not re-derived; POST_FLAG-only update keeps the totals;
  ACC_VAL 0 / flagged account without cost centre rejected; supplier memo prefixed; band supplier defaulted. Scratch objects dropped.
- Page code rendered in memory (apexgen): all `:PAGE_*` references resolve to page items.

## Notes / open questions

1. ~~Deleting a document that still has lines fails with the FK error~~ — solved by the generator (wave 3b): the Delete button now deletes
   the lines of every detail grid first, which is the legacy PRE-DELETE cascade ("deletes the detail blocks"); `delete_lines` stays at its
   default (no refusal in the legacy).
2. The generated APPX trigger and the legacy VN_MAINTRNS_ALTKEY trigger have no FOLLOWS clause (on this database the later-created APPX
   trigger fires first, but Oracle does not guarantee it); the row rule re-computes ALT_KEY with the legacy formula so the value is right in
   either order. Adding `FOLLOWS APPX_VN_MAINTRNS` to VN_MAINTRNS_ALTKEY would make it explicit.
3. ~~BILL_PAY_METHOD hidden~~ — wave 3b shows it as the legacy list "طريقة الدفع" (see Wave 3b); the save rule already honours method 3.
4. ~~SUPPLIER_ID without the legacy LOV~~ — wave 3b: legacy supplier list.
5. ~~No invoice LOV on the payment lines~~ — wave 3b: the legacy BILL_LOV as a popup list on BILL_ID1 (the save still resolves and checks it).
6. Users of groups 101/102 see no transactions unless VN_TRNSTYPE_PASSWORD is filled (empty today) - same as the legacy filter.

## Wave 3 (buttons, warnings, displays)

Installation code: `:GLOBAL.CUSTOMER_CODE` comes from `SELECT CUSTOMER_PAR.CUSTOMER_CODE FROM CUSTOMER_PAR` (Sysmenu.fmx ENTER_LOGIN); CUSTOMER_PAR has 0 rows on the build copy (and in the production discovery), so the code is NULL: `= 'SDI' / 'RSD' / ...` branches never run and `!= 'RSD'` / `NOT IN (...)` tests are NULL, i.e. skipped too, exactly as in the legacy PL/SQL.

| Legacy | APEX | Evidence / notes |
|---|---|---|
| DOC_NO WHEN-VALIDATE-ITEM / PRE-INSERT -> DOC_NO_VALIDATION, alert DOC_NO_ASK (continue / stop) | `warnings` DOC_NO_ASK -> `app_act_pr.vn_doc_warning` ("رقم المستند مكرر" + "هل تريد الاستمرار؟") | `SELECT COUNT(1) FROM VN_MAINTRNS WHERE DOC_NO = :DOC_NO AND TRNS_ID = :TRNS_ID`; only for a new document or a changed number |
| POSTING button (CALL_FORM vnacupdt, CHECK_FILE_PREV(11), "السجل مرحل بالفعل") | action POST -> `app_act_pr.vn_post` -> `app_proc_vn.post_to_gl` for this transaction (date = ACC_POST_DATE) | shown when saved, LINK_FLAG 0, not posted and the user has a right on 5/11 |
| UNPOSTING button (CALL_FORM vnaccupdt, CHECK_FILE_PREV(12), "السجل غير مرحل") | action UNPOST -> `app_act_pr.vn_unpost` -> `app_proc_vn.cancel_gl_posting` (date = TRNS_DATE) | shown when posted (PAY_METHOD 5 or no cash-box / cheque system) and right on 5/12 |
| BILL_PAY_METHOD list "1" on an empty payment -> FILL_BILLS | action FILL_BILLS -> `app_act_pr.vn_fill_bills` | open invoice lines of the supplier, same currency and payment type, not stopped, ORDER BY TRNS_DATE, BILL_ID1, BILL_ID2; each paid with its residual (total - VN_SUBTRNS_PAYED_VALUE) until the payment total is used; then the PRE-INSERT effects (after_save CREATE) |
| CRN_BAL + DB_CR_FLAG (SUPPLIER_ID WVI / POST-QUERY: credit invoice lines - debit documents, total + discount) | `info` BAL -> `app_act_pr.vn_supplier_balance` ("379,869.00 د") | formula equal to GET_SUPPLIER_BAL on the data |
| VN_SUBTRNS PRE-INSERT / DELETE_DETAIL_EFFECT: RESIDUAL_VALUE of the paid invoice line -/+ the payment | `app_rules_vn.after_save` (refresh_invoice_residuals): residual = invoice total - all payments, for the invoices paid now and before the save (flashback) | same value as the legacy increments when the stored residual was right; the data had stale residuals (176 of 306 paid lines right) |

Tests (build copy, all rolled back, plain and inside a simulated APEX session of app 100 with the regenerated APPX_ triggers; scripts in the job folder `tmp\w3_purch`: t_vn.py, t_po.py, t_lot.py, t_st.py, t_quot.py, t_reg.py; static check chk.py): doc warning (used number, unchanged document, unused number); balance = DUM_SUM formula; unpost + post of 201/278
(voucher removed, then the same 2 voucher lines re-created, POST_FLAG back to 1); user 102 without 5/12 gets no button; FILL_BILLS on a
new 30 000 payment of supplier 101790100000 -> 101/481 (2 403.71 residual) and 101/482 (27 596.29), header residual 0, invoice
residual of 101/481 refreshed to 0; removal of a committed payment line of 101/514 recomputes that invoice residual (flashback).

## Wave 3b
Evidence: `VN\FMB\VnDbTrn_fmb.xml` (item properties, LOVs / record groups, TRANSLATE trigger with the runtime list values).
* `readonly_after_insert` on TRNS_ID and SUPPLIER_ID: UpdateAllowed = false in the .fmb, no trigger re-enables update (SUPPLIER_ID's
  PRE-TEXT-ITEM only toggles INSERT_ALLOWED).
* Legacy LOVs as lists: TRNSTYPE_LOV (debit types: effect 0, not 5, not summary, VN_TRNSTYPE_PASSWORD), SUPPLIER_LOV (active, not stopped,
  VN_SUPPLIER_PASSWORD range), COST_NO_LOV, DISC_LOV, MAINAREA_PAY_LOV / SUBAREA_PAY_LOV (LC_SETTEL_TYPE; lines without NON_PAY_FLAG),
  ACC_LOV / COST_CENTER_LOV / COST_CENTER2_LOV on both account grids, CONTRACT_LOV and BAND_LOV on the band lines (contracts of the header's
  supplier, bands of the contract with `CHECK_BAND_STATUS(...) = 0`; cascade CONTRACT_ID), and BILL_LOV on the payment lines: open invoices
  of the header's supplier in the same currency and payment type, residual > 0, not stopped, ordered by date / BILL_ID1 / BILL_ID2, with the
  residual in the display (cascade TRNS_ID / TRNS_SERIAL: the grid reads the header through the line's keys).
* BILL_PAY_METHOD shown as the legacy list "طريقة الدفع": تنازلي علي الفاتورة 1 / مساعدة الفواتير 2 / مبلغ مدين 3 (ADD_LIST_ELEMENT in
  CTRL.TRANSLATE), default 1 as WHEN-CREATE-RECORD; the row rule keeps a chosen value, FILL_BILLS runs for 1, the save allows a payment
  above the invoices for 3. PAY_METHOD stays hidden (runtime list 2 نقدى / 4 شيك / 5 حسابات / 6 تحويل; cash box / cheque systems not
  installed, every document uses 5).
* Blocks: VN_SUBTRNS and VN_SUBTRNS_ITEMS stay insert / delete only (UpdateAllowed = false; the list trigger that re-opens update runs
  only when the user changes the payment method, never after a query).
* `rules.computed` on the payment lines: INV_RESIDUAL "المتبقي من الفاتورة" (residual of the paid invoice: TOTAL_VALUE -
  VN_SUBTRNS_PAYED_VALUE, as the BILL_LOV column) and NET_VALUE_CURR "صافى الفاتورة ( الريال )" (net × header rate).
* Delete: the generator now deletes the lines first (legacy PRE-DELETE cascade), so open question 1 is solved. The legacy line delete
  (DELETE_DETAIL_EFFECT) also gave the paid invoices their residual back; the page's cascade deletes the lines directly, so
  `app_rules_vn.on_delete` (21_rules_vn.sql, after-save DELETE) now calls `refresh_invoice_residuals` for VNDBTRN: residual = total -
  payments, for the invoices of the committed (flashback) lines. Test (rolled back): lines of payment 201/9 deleted -> invoices 901/33
  and 101/141 back to residual 141 200 and 8 800 (were 0). Posted / paid / generated documents are still refused first (-20171).
* Check: `check_forms.py VNDBTRN` (all lists and computed columns run); BILL_LOV run for payment 201/15 (supplier 101340100000): 2 open
  invoices with their residuals.

## Coverage
Reproduced: numbering, list filter, header / line / account / band rules and GL-link check (wave 2); DOC_NO_ASK confirmation,
posting / cancel posting, FILL_BILLS allocation, supplier balance display, invoice residual maintenance (wave 3); legacy lists incl. the
open invoices of the supplier, payment-method list, type / supplier fixed after insert, invoice residual and riyal net value on the
payment lines, delete of a document with its lines (wave 3b).

Not reproduced, with the reason:
* GET_ITEMS (item-discount lines from a stock invoice, VN_SUBTRNS_ITEMS): the legacy button only fills new block records that the user
  completes before COMMIT; the APEX grid of VN_SUBTRNS_ITEMS is insert/delete-only (legacy UPDATE_ALLOWED = false), so rows inserted by a
  button could never get their discount. Needs a generator feature ("fill grid rows client-side before save"). The table is empty
  (0 rows, no debit settlement uses item discounts).
* PRINT_PAY_DOC / ITEM196 / PRINT_V (printing), CUSTOMER_ACCOUNT_BALANCE dongle, SET_IP, alerts, hilight / navigation: Forms-only or out of
  scope (printing).
* Cash-box / cheque links (PAY_METHOD 2 / 4 / 6, systems 13 / 15): not installed (HAS_RAP_CHK_SYS = 0); all documents use method 5.
* SUPPLIER.CRN_BAL_TOTAL maintenance: stale column, never read; the balance display is computed.
* ~~BILL_PAY_METHOD 2 / 3 choice~~: shown since wave 3b. Method 2 ("مساعدة الفواتير") has no separate logic in the evidence beyond not
  running the descending fill; the user picks the invoices on the lines.
