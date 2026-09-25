# ST_POSTING - ترحيل حركات المخازن / Posting Stores Transactions (to GL, AR, AP)

- Registry: system 3 serial 508 "ترحيل حركات المخازن" (menu `SYSTEM_MENU.POST_TRANSFER`), system 30 serial 26 "ترحيل المشتريات للأنظمة الأخري",
  system 31 serial 26 "الترحيل للحسابات العامة". APEX page 20460 (one page for the three menu entries).
- **Deliverable: (b) process screen**
  - PL/SQL: `app_proc_st.post_trns` in `app\db\20_proc_st.sql` (package `APP_PROC_ST`, compiled VALID in SMART).
  - Override: `app\legacy\overrides\ST_POSTING.json` (pattern PROCESS; preview = transactions still to post + their posting messages).
- **Confidence: high for GL posting** (port of the real source, regression-tested on production data, see Tests), **medium-high for AR / AP**
  (same code path, validated on the same sample; differences found are data edited after the original posting).

## Evidence

| Source | What it gives |
|---|---|
| `evidence\ST_POSTING.md` | registry rows and GN_FORM_ITEM labels only (FROM/TO_DATE, FROM/TO_TYPE, FROM/TO_TRNS_SERIAL, ACCT/CUST/SUPP_TRNS counters, button PUSH_BUTTON75 "ترحيل حركات المخازن للأنظمة الآخرى ( حسابات - عملاء - موردين )"). No compiled SQL. |
| `_pipeline\catalog.json` form `ST_POSTING_CPOSTING` (`ST\FMB\ST_POSTING_CPOSTING_fmb.xml`) | full trigger and program-unit source (≈8 000 lines): the same items (PUSH_BUTTON75/76/77 are still in the form, without triggers) plus the buttons AC_BTN / AR_BTN / VN_BTN and a FILTER list (1 post, 2 cancel). This is the evolved version of ST_POSTING / ST_CPOSTING and is the source of the port. |
| SMART data | ST_TRNS_TYPE (JOIN_TYPE, ENTRY_TYPE, POST_TYPE, CUSTOMER_TRNS_CODE, SUPPLIER_TRNS_CODE), STACLNK (99 link rows), ST_BASIC.POST_TYPE = 4, 2 361 posted transactions with their AC_YEARLY_TRN vouchers, AR_MAINTRNS (LINK_FLAG 1) and VN_MAINTRNS (LINK_FLAG 1). |
| DB objects used as-is | `CALC_SERIAL`, `GET_JOIN_TYPE`, `GET_BALANCE_COST_CONFG`, `GET_CUSTOMER_CTGRY`, triggers on ST_TRNS_MAST / ST_TRNS_DET (cost, DATE_SERIAL), AC_YEARLY_TRN(_DET) (closed period AC_CLOSE_ACYR, tax lock *_TAX, revision REV_*). |

## What the legacy screen does

The block ST_TRNS_MAST lists the transactions of the filter (DEFAULT_WHERE, kept as the cursor `c_block`):
`NVL(DELETE_FLAG,0)=0`, type between FROM_TYPE / TO_TYPE, date between FROM_DATE / TO_DATE, optional serial / customer (C1..C2) /
salesman ranges, `GET_JOIN_TYPE(type) IN (2,3,4)` and not yet posted to GL, or JOIN_TYPE 3 and not posted to AR, or JOIN_TYPE 4 and not
posted to AP; security `:GLOBAL.PASSWORD_NUMBER = 0 OR TRNS_TYPE_CODE IN (ST_TRNSTYPE_PASSWORD, FLAG = 1)`. Each ticked record is then posted:

### 1. GL (AC_BTN -> SET_POST_ENTRIES per transaction)

1. `AC_BASIC.CLOSE_DATE` of the company: a transaction dated on/before it stops the whole run (MSG ... "لأنها تقع فى فترة مقفلة").
2. Posting type = `ST_TRNS_TYPE.POST_TYPE` (or `ST_BASIC.POST_TYPE` when < 4). 1 = one voucher per transaction (used by all types of this
   installation), 2 = one voucher per transaction type, 3 = one collected voucher.
3. `CHECK_VALID_POSTING`: for incoming effects (1, 6) a line whose store balance (`GET_BALANCE_COST_CONFG`) is negative refuses the transaction
   ("يوجد صنف بالحركة رصيده سالب").
4. `MAKE_ENTRY` builds the voucher lines in the work table ST_LEDGER from the account links **STACLNK** of the transaction type
   (ENTRY_NO, ENTRY_SERIAL_NO, ACCOUNT_NO_TYPE, ACCOUNT_NO, ACCOUNT_IND 1 debit / 2 credit, VALUE_TYPE, COST_NO_TYPE, COST_NO2_TYPE):
   - ACCOUNT_NO_TYPE: 1 fixed account; 2/3/4/5/12 store accounts per detail store (`HANDLE_STORE`: ST_STORE.ACCOUNT_NUMBER1..4, 5 falls back to the
     customer's INCOME_ACCOUNT_NUMBER, 12 = stock account of the destination store); 6-9 ST_TRNS_MAST.ACCOUNT_NUMBER1-4; 10 customer account; 11 supplier
     account (or VN_PAY_METHODE_ACC / LC_SETTEL_TYPE for VN_BASIC.PAY_TYPE_CODE); 13 customer discount account; 14 service vendors (`HANDLE_VNDR_SRVS`);
     15 item-group accounts (`HANDLE_GROUP`); 16 bank account of the store; 60 broker (`HANDLE_BROKER_VALUES`); 66 VAT (`HANDLE_TAX_VALUES`,
     TX_TAXES_TYPES tax 2, reverse-charge line for EXT_SUPP_FLAG suppliers).
   - VALUE_TYPE: 1 items net of line discounts, 2 sales total - discounts + charges + tax, 3 cost (ST_TRNS_DET_COST.UNIT_COST x BASIC_QTY),
     5/36/37 discounts, 8 items + charges, 12 supplier net (incl. tax unless the supplier is exempt), 15 services, 34 net without tax, 35 gross
     sales, 4/6/7/9/10/16/30 individual charges, 11/17-21 payments by cash / network / visa / master / cheque / amex, 22 supplier discount,
     24 bank commissions, 60 broker share, 66 tax.
   - Cost centres: 1 fixed, 2 store, 3 transaction, 4 item group (`HANDLE_GROUP_1/2/3`), 5 destination store, 6 none; centre 2 also 7 = salesman.
     `CHECK_COST_CENTERS`: centre must exist and be a leaf.
   - Accounts must exist and be leaves (AC_MASTER.ACCOUNT_STATUS); any error inserts a message in ST_POST_MSG and skips the transaction.
   - Balance: a difference below 1 is absorbed by the first debit line (rounding), otherwise "القيد غير متوازن" and the transaction is skipped.
5. `INSERT_RP_PC_TRNS`: cash-box (RP_TRNS_MAST) / network (CHECK_MAST) documents for PAYMENT / card amounts - only when the treasury (15) or
   cheques (13) systems are installed (they are not in SYS_SYSTEMS here, so this is a no-op).
6. Voucher (post type 1): `AC_YEARLY_TRN` with entry year = year of the transaction date, entry type = previous AC_ENTRY_TYPE or
   ST_TRNS_TYPE.ENTRY_TYPE, entry number = the previous AC_ENTRY_NO when that voucher no longer exists (cancel + re-post keeps the number),
   else `CALC_SERIAL`; DOC_NO, ENTRY_DESC = transaction description (or type name), MEMO " حركة رقم type / serial", POST_SYSTEM 30 (purchases)
   / 31 (sales) / 3 (others), CREATE_* = company / group / user. Lines `AC_YEARLY_TRN_DET` ordered by value desc, ENTRY_DESC = account name,
   MEMO = line memo (e.g. "توريد مواد من المورد ... طبقا لفاتورة المورد رقم ...").
7. `ST_TRNS_MAST`: POST_FLAG = 1, AC_ENTRY_YEAR / TYPE / NO. Linked RP_TRNS_MAST / CHECK_MAST get POST_ENTRY_*; an AR_MAINTRNS / VN_MAINTRNS
   already created by the AR / AP posting gets ACC_YEAR / TYPE / NO.

### 2. AR (AR_BTN -> SET_POST_CUSTOMER, JOIN_TYPE 3)

For each transaction with a customer and ST_TRNS_TYPE.CUSTOMER_TRNS_CODE: AR department = AR_TRNSTYPE.CTGRY_CODE of that code (missing
department stops the run); `MAKE_CUSTOMER_ENTRY` computes the total (items / currency rate + services + charges - discounts + tax) and
`INSERT_CUSTOMER_TRNS` creates, in the customer's area (CUSTOMER.MAINAREA_ID / SUBAREA_ID):
- sales invoice (effect 2): AR_MAINTRNS (LINK_FLAG 1, POST_FLAG 1, ACC_* = the stock voucher, POST_SYSTEM 31, residual = total - payment) and one
  AR_SUBTRNS bill (BILL_ID1 = category `GET_CUSTOMER_CTGRY`, BILL_ID2 = DOC_NO, INVOICE_CLASS = due date); when PAYMENT > 0 also a payment
  transaction (ST_TRNS_TYPE.CUSTOMER_TRNS_PAY_CODE, PAY_METHOD 2);
- return (effect 4) or purchase from a customer (effect 1): linked to the posted invoice (RET_TRNS_TYPE_CODE / RET_TRNS_SERIAL, or INVOICE_REF on
  an opening-balance bill) -> PAY_METHOD 2 with an allocation line (INV_TRNS_* of the invoice bill); otherwise PAY_METHOD 4 (against the customer).
- ST_TRNS_MAST: CUST_POST_FLAG 1, CUST_TRNS_ID / SERIAL, CUST_TRNS_PAY_CODE / SERIAL_PAY, CUST_MAINAREA_ID / SUBAREA_ID.

### 3. AP (VN_BTN -> SET_POST_SUPPLIER, JOIN_TYPE 4)

For each transaction with a supplier and SUPPLIER_TRNS_CODE (else message "الحركة لا تحتوى على مورد"): VN_BASIC.PAY_TYPE_CODE must be set;
`MAKE_SUPPLIER_ENTRY` / `INSERT_SUPPLIER_TRNS` create VN_MAINTRNS (LINK_FLAG 1, POST_FLAG 1, ACC_* = stock voucher, POST_SYSTEM 30, total =
items - discounts - payment + tax unless the supplier is tax-exempt, in the transaction currency) and one VN_SUBTRNS per due instalment
(ST_TRNS_DET_DUES; BILL_ID1 = type || serial). A purchase return on a posted purchase invoice reduces the invoice bill residual and adds a line
pointing to it. Supplier discounts (ST_TRNS_DET.SUPP_DISC_VALUE) -> a separate VN transaction of ST_TRNS_TYPE.SUPP_DISC_TRNS_TYPE with
VN_SUBTRNS_ITEMS; expense lines (ST_TRNS_DET_EXPENS) -> service-vendor transactions. ST_TRNS_MAST: SUPP_POST_FLAG 1, SUPP_TRNS_ID / SERIAL
(+ SUPP_DISC_TRNS_*).

## APEX implementation

`post_trns(p_from_date, p_to_date, p_from_type, p_to_type, [serials, customers, salesmen], p_post_gl, p_post_ar, p_post_ap, p_company_code,
p_user_code, p_password_number)`:
- validations of the buttons (alert DATA_ERROR "خطأ فى إدخال البيانات....!", ORA-20103): dates and type range present and ordered, serial range ordered;
  a single serial / customer / salesman fills the other bound (WHEN-VALIDATE-ITEM behaviour); at least one system (ORA-20104);
- `c_block` = the legacy block query incl. the ST_TRNSTYPE_PASSWORD filter (group 0 = all);
- runs the three buttons in screen order GL -> AR -> AP over the queried records; each record is locked (`SELECT ... FOR UPDATE`) and its flags
  re-read before posting, so a transaction is never posted twice (also not by two sessions);
- all legacy program units are ported verbatim in the package body (banner "legacy program unit <NAME>"); no COMMIT.

Changes to the legacy code (all in the package, listed for review):
1. Forms globals -> package variables: `:GLOBAL.LANG` (from G_LANG; the GL memo language follows the user as in the legacy), COMPANY_CODE,
   PASSWORD_NUMBER, USER_CODE, `:PARAMETER.SYSTEM_POST_TYPE` (ST_BASIC.POST_TYPE), `:GLOBAL.SYSTEM_NUMBER` = 3.
   `:GLOBAL.CUSTOMER_CODE` (vendor installation code, set by the ASCON menu, not in the evidence) = 'SMART': only its tests `= 'AZZ'` / `NOT IN ('BEN')`
   matter, i.e. this installation is treated as neither BEN nor AZZ (see question 1).
2. `MSG(a, e, 1)` (alert + FORM_TRIGGER_FAILURE) -> `raise_application_error(-20101)`: the whole run is rolled back (legacy: the trigger stopped and the
   changes already made stayed pending until the next commit).
3. The error report `ST_post_msg.RDF` (PRINT_ERROR) is replaced by the preview region, which shows the ST_POST_MSG message of each transaction.
   ST_POST_MSG is cleared once per run (legacy SET_POST_ENTRIES cleared it before each transaction, so only the last transaction's errors survived).
4. ST_LEDGER rows of a transaction that failed are deleted before the next one (legacy left them; a balanced leftover could be posted with the
   next transaction's voucher number).
5. The per-record tick box (CHK / CHK_ALL) is replaced by the filter ranges (serial range for single transactions).

## Tests (all rolled back)

- Regression: for 234 randomly chosen posted 2026 transactions of all 22 posted types (sales, returns, purchases, purchase returns, transfers,
  adjustments), `cancel_trns` then `post_trns` in the same session and comparison with the original: GL voucher lines (account, value, cost
  centres) **identical in 234/234**, same voucher number, same header. AR/AP documents identical except where the data was edited after the
  original posting (return reference changed, AR allocation added manually) or payments had reduced the residual (see ST_CPOSTING.md).
- Never-posted purchase invoices 10803/221-222: GL voucher 2026/105/175-176 (stock account debit, supplier account credit with the supplier memo),
  VN_MAINTRNS 101/563-564 linked to the voucher; no messages, no ST_LEDGER leftovers.
- Closed period (opening balance 99999/1 of 2024-12-31) -> ORA-20101 "لا يمكن ترحيل الحركة رقم 99999/1 لأنها تقع فى فترة مقفلة".
- Bad range -> ORA-20103; no system -> ORA-20104; already posted transaction -> skipped (0 posted); group 7 without ST_TRNSTYPE_PASSWORD rows -> nothing.
- Two failing transactions in one run keep both messages in ST_POST_MSG.

## Open questions (key user / vendor)

1. What is `:GLOBAL.CUSTOMER_CODE` for this installation (ASCON menu)? The port assumes it is not 'BEN' / 'AZZ' (BEN merges expense vendors into one
   AP transaction; AZZ marks JOIN_TYPE 4 types without GL link as posted). ST_TRNS_DET_EXPENS is empty, so BEN logic has no effect today.
2. The old single button PUSH_BUTTON75 has no source; the APEX page posts GL -> AR -> AP in the order of the newer AC/AR/VN buttons. Confirm.
3. The three menu entries (systems 3, 30, 31) restricted the type LOV by system (30: purchases, 31: sales, 3: transfers / adjustments). APEX has one
   page with all linked types (still limited by ST_TRNSTYPE_PASSWORD). Should the purchase / sales menus open pre-filtered?
4. Posting rejects a transaction when any detail's balance is negative (incoming effects only). Keep?
