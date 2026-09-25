# VNCRTRN - حركات الموردين الدائنة / Supplier Credit Transactions (manual invoices, settlements)

- Registry: system 5 serial 2 (menu `FILES_MENU.ARCRTRNS`, order 103). APEX list page 40030, document page 40031.
- **Deliverable: screen correction + rules** - `app\legacy\overrides\VNCRTRN.json` (`"pattern": "MASTER_DETAIL"` with explicit columns and
  a `rules` block); PL/SQL in package `APP_RULES_VN` (`app\db\21_rules_vn.sql`, VALID).
- Why a correction and not AUTO: the generated screen (.fmx + labels) put VN_SUBSUBTRNS and VN_SUBTRNS_COST as children of the header,
  but both are children of VN_SUBTRNS (their BILL_SEQ is a required, typed key there); both tables are empty and their features are off
  (VN_BASIC.COST_CODE_FLAG = 0). The invoice grid also lacked INV_VALUE, the value the legacy tax logic works on. The override keeps the
  AUTO header columns (minus ITEM_DISC_VAL / NET_VALUE, never stored: 0 rows in the data) and shows three grids: invoices (VN_SUBTRNS),
  other debit accounts (VN_MAINTRNS_ACC), other credit accounts (VN_MAINTRNS_SUPP_ACC).
- **Confidence: medium** - compiled form only (.fmx SQL + texts, no trigger source); rules are the VNDBTRN .fmb logic that the embedded SQL
  shows to be shared, confirmed on the 67 existing credit settlements (103): header TOTAL = sum of invoice lines 67/67, GL-link balance
  67/67, line TOTAL = INV_VALUE + VAT 66/66, BILL_ID2 = supplier with BILL_ID1 a running number per supplier, DUE_DATE = INV_DATE + DUE_DAYS 64/66.

## Evidence (`evidence\VNCRTRN.md`)

- Block WHERE (fmx): `TRNS_ID IN (VN_TRNSTYPE EFFECT = 1 AND TRNS_TYPE <> 5 AND NVL(SUM_TRNS,0) = 0) AND NVL(LINK_FLAG,0) = 0 AND SERIAL IS NULL`
  + VN_TRNSTYPE_PASSWORD / VN_SUPPLIER_PASSWORD security. TRNSTYPE record group: EFFECT = 1, TRNS_TYPE <> 5.
- Numbering: `SELECT NVL(MAX(TRNS_SERIAL),0)+1 FROM VN_MAINTRNS WHERE TRNS_ID = :b1`, `UPDATE VN_TRNSTYPE SET LAST_SERIAL = :b1` (as VNDBTRN).
- Invoice lines: `SELECT NVL(MAX(BILL_ID1),0) FROM VN_SUBTRNS WHERE BILL_ID2 = :b1`, duplicate check `... BILL_ID1 = :b1 AND BILL_ID2 = :b2 AND
  GET_SUPPLIER(..) = :b5`, `SELECT NVL(DUE_DAYS,0) FROM SUPPLIER`, VN_BASIC MIN/MAX_DATE, `SELECT TRNS_TYPE FROM VN_TRNSTYPE` + `EXT_SUPP_FLAG`
  (TAX_LIB_NEW.GET_TAX_VALUE referenced), line ITEM_SEQ/BILL_SEQ numbering.
- Texts: "لابد من إدخال فواتير الحركة", the Check_GL_Link messages, "تاريخ الحركة / الاستحقاق لا يمكن ان يكون اقل من تاريخ فتح المورد /
  الرصيد الافتتاحى", "يجب ان يكون معامل التحويل ب 1", "يجب ان يكون معامل التحويل أكبر من 0", "يجب حذف تفاصيل الحركة اولا",
  "لا يجوز مسح الحركة الحالية لكونها مرحلة", "يجب ادخال مركز تكلفة المورد" (COST_CODE_FLAG, off).
- Delete: `SELECT COUNT(1) FROM PR_INCOME_LOT WHERE VN_TRNS_ID/SERIAL` (lot-linked invoices), payment lines of a deleted invoice deleted
  (DELETE_PAY_ENTRIES), SUPPLIER.CRN_BAL_TOTAL +/- (stale column, dropped).

## Rules implemented

| Rule | Where | Detail |
|---|---|---|
| Numbering | `key_expr` (same text as VNDBTRN) | max+1 per TRNS_ID + VN_TRNSTYPE.LAST_SERIAL. |
| List filter | `where` | legacy block WHERE with `:G_PASSWORD_NUMBER`. |
| Type default | `defaults` | `default_trns_id('VNCRTRN')` = 103 (the only type entered manually); PAY_TYPE_CODE = VN_BASIC.PAY_TYPE_CODE. |
| Header validation (CREATE, SAVE) | `check_header('VNCRTRN', ...)` | same as VNDBTRN (type of the screen, posted / paid / generated read-only, no type change, no supplier change with lines, supplier active / not stopped / in range, supplier currency, rate, dates, DOC_NO) - without the INV_VALUE check (the value comes from the lines). |
| Header derivations | `row_rules` VN_MAINTRNS (shared) | PAY_METHOD 5, PAY_TYPE_CODE, RESP_CODE, ALT_KEY. |
| Invoice lines (CREATE, SAVE) | `after_save('VNCRTRN', ...)` | BILL_ID2 := supplier, BILL_ID1 := next number of the supplier; INV_DATE := TRNS_DATE, DUE_DATE := INV_DATE + SUPPLIER.DUE_DAYS, PAY_TYPE_CODE; INV_DATE inside VN_BASIC MIN/MAX_DATE; DUE_DATE not before supplier start / opening-balance date; no duplicate invoice number for the supplier; value > 0; TAX_CODE1/TAX_VALUE1 = supplier VAT % * INV_VALUE (not for payment types), TOTAL_VALUE = INV_VALUE + TAX1 + TAX2 (exempt: INV_VALUE), RESIDUAL_VALUE = total - paid. Header TOTAL_VALUE = sum of lines. SAVE: at least one invoice ("لابد من إدخال فواتير الحركة"), GL link (Check_GL_Link, same branches as VNDBTRN, base = TOTAL_VALUE * rate). A deleted invoice line that still has payments -> error (legacy deleted the payments). |
| Account lines | `row_rules` (shared) | ACC_VAL > 0, cost centre requirement, supplier-line memo prefix. |
| Read-only / hidden | `readonly`, `hidden` | TRNS_SERIAL, TOTAL_VALUE, POST_FLAG, PAY_FLAG, ACC_NO, ACC_DATE, line TAX_VALUE1 / TOTAL_VALUE; LINK_FLAG, BILL_SEQ, line PAY_TYPE_CODE, ACC_SER hidden. |
| Delete | `on_delete('VNCRTRN', ...)` | posted / paid / generated (committed row read by flashback query, page values as fallback) -> error; invoice linked to an incoming lot (PR_INCOME_LOT.VN_TRNS_ID/SERIAL) -> error; orphan supplier-account lines removed. As in VNDBTRN, a document that still has invoice or account lines cannot be deleted (FK) until its grid lines are removed. |

Not duplicated: CLOSE_VN_MAINTRNS, VN_MAINTRNS_TAX, VN_SUBTRNS_TAX, VN_MAINTRNS_ALTKEY.
Dropped: installments generator (INSTALLMENT_*: splits an invoice into instalments - a data-entry helper), item details (VN_SUBSUBTRNS) and
cost distribution (VN_SUBTRNS_COST) grids (empty, COST_CODE_FLAG = 0), SUPPLIER.CRN_BAL_TOTAL maintenance (stale), print / alerts /
dongle / cash-box and cheque links (systems 13/15 not installed).

## Tests (all rolled back)

- Synthetic 103/68, supplier 101850100000 (last invoice number 5): CREATE -> ok; SAVE without lines -> ORA-20168; two lines (1000, 500) +
  balanced account line -> BILL_ID1 6 and 7, BILL_ID2 = supplier, INV_DATE today / as typed, DUE_DATE = INV_DATE (DUE_DAYS null), TAX 2/0,
  header total 1500; duplicate number -> ORA-20166; unbalanced accounts -> ORA-20133; deleting an invoice line that a payment points to ->
  ORA-20167. Taxed supplier (15 %): line 1000 -> TAX 150, TOTAL 1150, header 1150.
- `check_gl_link` passes for all 67 existing 103 documents.
- A mutating-table error (function reading VN_SUBTRNS inside UPDATE VN_SUBTRNS) was found by the test and fixed.

## Open questions

1. VNCRTRN is .fmx-only: confirm with the key user that invoice lines are entered as value before VAT (INV_VALUE) - the data (TOTAL =
   INV_VALUE + VAT on all 66 lines) says so, the GN_FORM_ITEM labels only list TOTAL_VALUE. The INV_VALUE column has no Arabic label in
   GN_FORM_ITEM (shows "Inv Value").
2. Legacy deleted payments of a deleted invoice line; the new rule refuses the save instead. Confirm.
3. Types 101/102 (stock/non-stock purchases) are allowed by the legacy LOV but are normally created by the purchasing posting (LINK_FLAG 1);
   only 103 was entered manually in 2025-2026.
4. ~~Checkbox columns render as numbers~~ — POST_FLAG / PAY_FLAG were already check boxes; STOP_FLAG is one since wave 3b.

## Wave 3 (buttons, warnings, displays)

Installation code: `:GLOBAL.CUSTOMER_CODE` comes from `SELECT CUSTOMER_PAR.CUSTOMER_CODE FROM CUSTOMER_PAR` (Sysmenu.fmx ENTER_LOGIN); CUSTOMER_PAR has 0 rows on the build copy (and in the production discovery), so the code is NULL: `= 'SDI' / 'RSD' / ...` branches never run and `!= 'RSD'` / `NOT IN (...)` tests are NULL, i.e. skipped too, exactly as in the legacy PL/SQL.

| Legacy | APEX | Evidence / notes |
|---|---|---|
| DOC_NO_ASK / DOC_NO_ASK_E alert (duplicate document number of the type, continue?) | `warnings` DOC_NO_ASK -> `app_act_pr.vn_doc_warning` | same DOC_NO_VALIDATION SQL as VNDBTRN (.fmx strings DOC_NO_ASK) |
| POSTING / UNPOSTING buttons (الترحيل / إلغاء الترحيل للحسابات العامة) | actions POST / UNPOST -> `app_proc_vn.post_to_gl` / `cancel_gl_posting` for the document | .fmx items VN_MAINTRNS.POSTING / UNPOSTING, same code as VNDBTRN (CHECK_FILE_PREV 11 / 12) |
| CRN_BAL_TOTAL "رصيد المورد" | `info` BAL -> `app_act_pr.vn_supplier_balance` | as VNDBTRN |
| detail block VN_SUBTRNS1 (payments of each invoice, EFFECT 0 types) | `info` PAYMENTS -> `app_act_pr.vn_invoice_payments` (invoice number: payment type/serial, date, value, discount) | read-only in the legacy; a grid under the invoice grid needs a nested detail the generator does not have, so a text display is used |

Tests (build copy, all rolled back, plain and inside a simulated APEX session of app 100 with the regenerated APPX_ triggers; scripts in the job folder `tmp\w3_purch`: t_vn.py, t_po.py, t_lot.py, t_st.py, t_quot.py, t_reg.py; static check chk.py): doc warning; payments of invoice 101/481 (2 payments listed); posting round trip in t_vn.py (shared code).

## Wave 3b
Evidence: the LOV queries of the .fmx (evidence pack).
* Lists: TRNS_ID from the credit types (`VN_TRNSTYPE` effect 1, not 5, not summary, VN_TRNSTYPE_PASSWORD) and read-only after insert
  (`check_header` already refuses a type change, the legacy "no type change"); SUPPLIER_ID from active, not stopped suppliers in the user's
  VN_SUPPLIER_PASSWORD range (the supplier stays editable: it may change while the document has no lines); PAY_TYPE_CODE from the
  supplier's payment types (`LC_SETTEL_TYPE` joined `VN_PAY_METHODE_ACC` on the supplier: cascading list on SUPPLIER_ID; all 67 manual
  credit documents of the data fit it); COST_NO / COST_NO2 (active, AC_PASSWORD_COST1 / 2), TRNS_ACCOUNT and the account lines' ACC_NUMBER
  (detail accounts, AC_PASSWORD_MASTER), the lines' cost centres.
* VN_SUBTRNS.STOP_FLAG "متوقف": check box 1/0 (GN_FORM_ITEM check box "توقف السداد"; data 0 / empty) — open question 4 answered.
* Not covered: the installments generator (no formula), the invoice-payments grid under each invoice (nested detail grid: still an
  `info` text, generator limit).
* Check: `check_forms.py VNCRTRN`.

## Coverage
Reproduced: numbering, filter, header and invoice-line rules, GL link, delete rules (wave 2); duplicate-number confirmation, posting /
cancel posting, supplier balance and payments display (wave 3); legacy
lists (types, suppliers, payment types of the supplier, cost centres, accounts), type fixed after insert, stop-payment check box (wave 3b).

Not reproduced, with the reason:
* Installments generator (INSTALLMENT_*: splits an invoice into instalments): .fmx only, the split formula is not in the evidence (no SQL,
  only item names) and no document of the data uses instalments - question for the business.
* VN_SUBSUBTRNS (item details) and VN_SUBTRNS_COST (cost distribution): tables empty, VN_BASIC.COST_CODE_FLAG = 0.
* SUPPLIER.CRN_BAL_TOTAL maintenance (stale), printing, dongle, alerts, cash-box / cheque links (systems 13 / 15 not installed).
