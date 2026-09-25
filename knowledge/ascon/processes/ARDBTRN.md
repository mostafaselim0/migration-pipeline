# ARDBTRN - حركات العملاء المدينة / Debit Customer's Transactions

- Registry: system 4 (FILES_MENU, menu `open_form('ardbtrn')`). APEX list page 30030, document page 30031, print 30032.
- **Deliverable: (a) generated screen kept (`"pattern": "AUTO"`) + business rules**
  - Override: `app\legacy\overrides\ARDBTRN.json`; PL/SQL: package `APP_RULES_AR` in `app\db\21_rules_ar.sql` (VALID).
- **Confidence: medium-high** - numbering, filters, derivations and checks are in the .fmb and match the 17 existing debit settlements
  (DOC_NO, TRNS_SERIAL, TRNS_SERIAL_TOTAL, STORE_CODE, due dates). Wave 3 added the posted-document rules, the deletion of payment lines of a
  deleted invoice, CHECK_DATE, the posting buttons and the balance display (APP_RULES_AR / APP_ACT_AR).

## What the screen is

Own debit transactions of AR_MAINTRNS (debit settlements 1001-1003, AR_TRNSTYPE.EFFECT = 0, TRNS_TYPE 4) with invoice lines AR_SUBTRNS
and the account link AR_MAINTRNS_ACCOUNT_DET. AR_MAINTRNS is shared with ARCRTRN, ARDBTRN_ST, ARCRTRN_ST and the stock posting
(LINK_FLAG = 1).

## Rules implemented

| Kind | Rule | Evidence | APEX |
|------|------|----------|------|
| where | `TRNS_ID in (EFFECT = 0 and TRNS_TYPE <> 6) and LINK_FLAG = 0` + group filters (AR_TRNSTYPE_PASSWORD FLAG=1, AR_CUST_PASSWORD, AR_SALESMAN_PASSWORD) | block WHERE | `where` (NVL(LINK_FLAG,0); :G_PASSWORD_NUMBER) |
| type default / validation | TRNSTYPE LOV (validate from list): EFFECT = 0 and TRNS_TYPE in (3,4) + AR_TRNSTYPE_PASSWORD; TRNS_ID not updatable | record group TRNSTYPE, item UpdateAllowed=false | default `app_rules_ar.default_type('ARDBTRN')` (1001); `check_header` |
| numbering | TRNS_SERIAL = max+1 **per TRNS_ID** (area/branch filter commented out); TRNS_SERIAL_TOTAL = global max+1; DOC_NO = max+1 of own documents (NVL(LINK_FLAG,0)=0) of the same AR_TRNSTYPE.TRNS_TYPE (shared with credit settlements 401-403) | PRE-INSERT, TRNS_ID WVI | key_expr `TRNS_SERIAL` (`next_trns_serial`), after_save (`next_serial_total`, `next_doc_no`); TRNS_SERIAL / DOC_NO read-only |
| derived | MAINAREA_ID / SUBAREA_ID = customer's (items disabled); CTGRY_CODE = type category; SALESMAN_ID = first salesman of customer + category; currency of the customer | CUSTOMER_ID / TRNS_ID WVI | key_expr (areas always; category / salesman only for APEX CREATE/SAVE requests when empty); areas read-only + optional |
| derived | LINK_FLAG 0, CASH_FLAG 2, POST_FLAG / PAY_FLAG 0 (initial values); TRNS_ACCOUNT = 1 when account-link lines exist; header TOTAL_VALUE = sum of invoice totals, NET_VALUE = sum(total - discount), DISC_VALUE = 0 (VALIDATE_DETAIL_SUM); SUPERVISOR_SLSMAN when AR_MAINTRNS_IN fired before the salesman was derived | PRE-INSERT, item initial values, VALIDATE_DETAIL_SUM | after_save `after_save_debit` |
| lines derived | TOTAL_VALUE = INV_VALUE (+ taxes only for sales invoices TRNS_TYPE 0, not enterable here); RESIDUAL_VALUE = TOTAL_VALUE on new lines; DISC_VALUE 0; STORE_CODE 999999999999 (initial value, used to match payments); due date INVOICE_CLASS = INV_DATE + CUSTOMER.DAY_NO; INV_DATE = TRNS_DATE (existing trigger AR_SUBTRNS_INV_DATE) | INV_VALUE / INV_DATE WVI, WHEN-CREATE-RECORD | `after_save_debit`; TOTAL / RESIDUAL / TAX read-only in the grid |
| validations | customer required, active (STOPFLAG 0, CUSTOMER_STATUS 1), allowed for the group, linked to the category (CUSTOMER_LOV); TRNS_DATE >= customer OPEN_DATE (CHECK_CUST_INFO) and >= opening balance date (CHECK_OPEN_BAL); salesman of customer/category when AR_BASIC.SALESMAN_CUST_FLAG = 1; rate > 0, = 1 for currency 1; customer not changeable once lines exist | CUSTOMER_ID / TRNS_DATE / SALESMAN_ID / CURRENCY_RATE WVI, PRE-INSERT / PRE-UPDATE | validation `check_header` |
| validations | posted (POST_FLAG = 1) or paid (PAY_FLAG = 1) transaction: CLOSE_POSTED (wave 2: read-only; wave 3: the item-level rules of the branch that applies here, see below) | CLOSE_POSTED | validations `check_posted_debit` + `snapshot_debit` (SAVE) |
| after-save checks | at least one invoice ('لابد من إدخال فواتير الحركة', SAVE); invoice value > 0; BILL_ID1 required and not used by any other AR_SUBTRNS row ('رقم عقد مكرر', BILL_ID1 WVI) nor the pair BILL_ID1/BILL_ID2 among debit lines ('توجد فاتورة بنفس الرقم'); INV_DATE <= TRNS_DATE, >= customer open date / opening balance; due date >= invoice and transaction dates | AR_SUBTRNS PRE-INSERT, BILL_ID1/2, INV_DATE, INVOICE_CLASS WVI | `after_save_debit` |
| after-save checks | account link (AR_TRNSTYPE.ACCOUNT_TYPE = 5): each line has account + value > 0 (account status 1, group), total = sum(INV_VALUE) * CURRENCY_RATE ('اجمالى قيم ارقام الحركات لا يساوى اجمالى تفاصيل الحركة') | VALIDATE_DETAIL_SUM, AR_MAINTRNS_ACCOUNT_DET PRE-INSERT/UPDATE, VALUE WVI | `after_save_debit` (SAVE) |
| after-save checks | credit limit: GET_CUSTOMER_BAL(customer, TRNS_DATE) <= CUSTOMER.CREDIT_LIMIT when new invoice lines were added | VALIDATE_CR_LIMIT | `after_save_debit` |
| numbering (detail) | AR_MAINTRNS_ACCOUNT_DET.SEQ = max+1 of the whole table (670 distinct SEQ over 661 documents); BILL_SEQ max+1 per document (generated) | account-det PRE-INSERT | key_expr `next_acc_det_seq` |

## Wave 3 additions

`:GLOBAL.CUSTOMER_CODE` is NULL on this installation (CUSTOMER_PAR is empty; `Sysmenu.fmx` ENTER_LOGIN reads it from there). In CLOSE_POSTED the
test `IF :GLOBAL.CUSTOMER_CODE <> 'ZEB'` is therefore false and the ELSE ("ZEEB") branch runs: that branch is the rule of this installation
(confirmed by the data: BILL_ID2 empty on 12 of 17 debit lines, i.e. the non-ZEB KEY-NEXT-ITEM copy of BILL_ID1 did not run either).

| Kind | Rule | Evidence | APEX |
|------|------|----------|------|
| validations | CHECK_DATE on TRNS_DATE and INV_DATE: not after today, not before MIN(AC_BASIC.MIN_DATE) | TRNS_DATE / INV_DATE WVI | `check_dates` (header), `after_save_debit` (lines) |
| posted / paid document (CLOSE_POSTED, ZEB branch) | not deletable; TRNS_ID, CUSTOMER_ID, CTGRY_CODE, DESCRIPTION_A/E, BAND_NO, TRNS_DATE, COST_CODE1/2, CURRENCY_RATE locked; SALESMAN_ID, accounts, BILL_ID2 and due dates stay editable; no invoice line added or deleted; INV_DATE / BILL_ID1 / INV_VALUE locked; account link locked | CLOSE_POSTED | validations `check_posted_debit` + `snapshot_debit` (replace the generic `check_posted`), `after_save_debit`, delete hooks |
| invoice line / document deleted | DELETE_PAY_ENTRIES: payment lines (EFFECT 1) with the same BILL_ID1 / BILL_ID2 / STORE_CODE are deleted, their payment gets RESIDUAL + (total - disc), DISC - disc, NET - (total - disc); a posted payment refuses: 'لا يمكن حذف الحركة رقم x/y     لكونها مرحلة الى الحسابات يجب إلغاء الترحيل أولا ' | KEY-DELREC, AR_SUBTRNS PRE-DELETE, DELETE_PAY_ENTRIES | delete hook `APP_RULES_AR_SUB_BD` (grid delete on SAVE and the document delete of page 30031) |
| buttons POST / CANCEL_POST | as ARCRTRN (ARACUPDT / AR_CPOSTING with POST_ON_LINE; POST passes TRNS_DATE) | POST / CANCEL_POST WHEN-BUTTON-PRESSED | actions **POST** / **CANCEL_POST** (`APP_ACT_AR`) |
| info | CRN_BAL_TOTAL 'الرصيد' (GET_CUSTOMER_BAL today), TOT_SUBTAX 'اجمالي الضريبة', TRNS_SUM_VALUE, total in local currency | POST-QUERY / display items | `info` |

## Tests

Wave 2 (`app_rules_ar` suite 66/66): default type 1001; 201 / 101 refused; group without AR_TRNSTYPE_PASSWORD refused; serial 1001 -> 18, DOC_NO
-> 114, TRNS_SERIAL_TOTAL -> 677, account-det SEQ global; CREATE header-only OK; SAVE without invoices refused; missing account link refused;
line 500 -> total/residual 500, STORE_CODE 999999999999, due date +1 day; header totals; value change 600; repeated BILL_ID1; invoice date after
transaction; due date before invoice; credit limit; posted read-only; type / customer change refused.

Wave 3 (`tmp\w3_argl\t_ar.py`, simulated APEX session, rolled back, 92/92 with the other AR screens): posted document - unchanged header passes,
description change refused, INV_VALUE change refused (-20154), unchanged lines pass, line delete and document delete refused; new settlement
1001 with invoice 300 (store 999999999999, due date), allocated by a new credit settlement 401, invoice line deleted -> payment line deleted and
payment residual back to 300; payment line of a posted payment (201/41) -> refused with the legacy text; POST / CANCEL_POST see ARCRTRN.

## Wave 3b (new generator keys; evidence `AR\FMB\ArDBTrn_fmb.xml` item properties, LOV record groups, FILTER_DATA)

| Legacy | Evidence | APEX |
|--------|----------|------|
| TRNS_ID list TRNSTYPE_LOV (EFFECT 0, TRNS_TYPE 3/4, group), not updatable | LovName, UpdateAllowed = false | `lov` (select list "id - name") + `readonly_after_insert` |
| CTGRY_CODE list CATGRY_LOV (ST_CATEGORY_TYPE), not updatable | LovName, UpdateAllowed = false | `lov` + `readonly_after_insert` |
| SALESMAN_ID never enterable (Enabled = false; the enabling lines of FILTER_DATA are commented out), name shown | item property, FILTER_DATA | `readonly` + `lov` for the name (derived by key_expr as before) |
| COST_CODE1 list COST_LOV (active cost centres 1 of the group); CUSTOMER_ACCOUNT list CUST_ACC_LOV (active accounts of the group) | LovName | `lov` (the generator had no list on them) |
| CASH_FLAG shown as the list CASH_FLAG_LIST "نوع السداد" (شيكات 0 / نقدية 1 / حسابات 2), disabled, 2 on a new record | List Item, WHEN-CREATE-RECORD | CASH_FLAG shown as a read-only static list, default 2 |
| Area / branch names (MAINAREA_DESC / SUBAREA_DESC) | display items, MAINAREA_LOV / SUBAREA_LOV | computed master columns اسم المنطقة / اسم الفرع |
| BILL_ID1 required | Required = true | `required` |
| Line values in local currency TOTAL_VALUE_RIYALH / RESIDUAL_VALUE_RIYALH = CURRENCY_RATE * value | item Formula | computed grid columns |
| Account-link lines: TRNS_ACCOUNT list ACCOUNT_LOV, COST_CODE1 list COST_LOV_DET (names shown) | LovName | `lov` |
| INV_VALUE label 'القيمة بالعملة' | Prompt | `label_a` |

Checked, nothing to change: block insert / update / delete flags (all allowed on the placed blocks); no CALL_FORM-only button except RP_BTN /
PC_BTN (systems 13 / 15 not installed); POST / CANCEL_POST are actions already. SQL of every list / computed column run on the build copy
(`tmp\w3b_gl\check.py`, problems 0).

## Coverage

Reproduced: the tables above. Not reproduced, with reason:

- Confirmation 'سوف يتم حذف حركات السداد المرتبطة بالفواتير آليا هل تريد الاستمرار ؟' before deleting invoices: the generator's warnings run only
  before SAVE / CREATE and cannot see grid deletions (the APEX delete confirmation of the button is generic).
- TAX_PAYED display (DB function GET_PAYED_TAX exists in production, not on the build copy).
- CUSTOMER_ACCOUNT_BALANCE protection, SET_IP, prompts / tab visibility, printing, RP / PC buttons (systems 13 / 15 not installed), immediate
  posting (IMMID_POST_TYPE = 0), AR_SUBSUBTRNS item lines (table empty, block not placed), GET_TAX_VALUE (sales invoices are not entered here).
- Delete of a posted transaction with its GL effect: refused (cancel the posting first), as the legacy CLOSE_POSTED did.
- Checks run on all lines of the document (legacy: new / changed lines only); the document is created header-first.
- Type-dependent visibility of FILTER_DATA (CUSTOMER_ACCOUNT, COST_CODE1 / 2, DOC_NO, salesman shown or hidden by the AR_TRNSTYPE
  settings): the fields are always shown (the generator has no per-record visibility). With today's types 1001-1003 the legacy hid
  CUSTOMER_ACCOUNT (CUSTOMER_ACCOUNT_TYPE 3) and COST_CODE1 (COST_NO_TYPE 4).

## Open questions

1. BILL_ID1 alone must be unique over all AR_SUBTRNS rows (WHEN-VALIDATE-ITEM added for 'ZEB' contracts but not conditioned): confirm it applies
   to this installation (the existing 17 settlements respect it).
2. Confirm that CUSTOMER_PAR stays empty in production (the posted-document rules follow the "ZEB" branch because of it).
