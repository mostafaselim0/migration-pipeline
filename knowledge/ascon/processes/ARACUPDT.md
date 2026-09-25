# ARACUPDT - الترحيل للحسابات العامة (العملاء) / Post AR Transactions to the General Ledger

- Registry: system 4 serial 6 (menu `SYSTEM_MENU.ARACUPDT`, order 4005). APEX page 30220.
- **Deliverable: (b) process screen**
  - PL/SQL: `app_proc_ar.post_to_gl` in `app\db\20_proc_ar.sql` (package `APP_PROC_AR`, VALID; `APP_PROC_AR_CREDIT` in the same file untouched).
  - Override: `app\legacy\overrides\ARACUPDT.json` (preview = the transactions the run will post, with the customer account and a
    "note" column that predicts why a transaction would block the run).
- **Confidence: high.** The form source exists (not only a compiled form), the posting SQL is the legacy code itself, and cancelling then
  re-posting all 661 historical AR postings reproduced every voucher (570 identical to the byte; the rest differ only by data changed
  after the original posting - see Tests).

## Evidence

- Source: `ASCON\AR\FMB\aracupdt.fmb`, converted as `AR\FMB\aracupdt_fmb.xml` (form module `AR_ACUPDT`; `AR\aracupdt_fmb.xml` is the same
  version except comments). The compiled `aracupdt.fmx` is only in `_ARCHIVE\ASCON\AR\FMB` and was compiled 4 s after the .fmb was saved.
  Old variants `aracupdt1/_PACKAGE/_tot/02092026.fmx`, `ARACUPDT_MULTI.fmx` are not the menu form.
- Button `EXECUTE_REP` (WHEN-BUTTON-PRESSED): counters `GET_TRNS_COUNT_AC/PC/RP`; nothing -> alert `NO_TRNS` "لا يوجد حركات يمكن ترحيلها";
  `DELETE AR_POST_MSG WHERE USER_CODE`; `AR_SET_EVERY_ENTRY_AC(company, password, user, 4, dates, types, serials, areas, subareas, NULL, NULL, NULL)`;
  AR_POST_MSG rows -> shown in block AR_POST_MSG (no commit); otherwise `COMMIT_FORM` + "تمت عملية الترحيل".
- Program unit `AR_SET_EVERY_ENTRY_AC` (form-local, the real posting loop) calls the DB procedures `AR_GET_TRNS_DATA` and
  `AR_CREATE_ENTRY_EVERY_ONE` (schema SMART, VALID). `INSERT_RP_PC_TRNS` / `GET_DOC_NO` / `POST_AC_DET` (cash-box and cheque documents) are
  only reached for cash / cheque transactions when the treasury systems are installed.
- The DB procedures `AR_SET_EVERY_ENTRY` and `AR_CREATE_ENTRY_EVERY_TYPE` are older variants (other cash-flag rule, grouped vouchers); the form
  does not call them.
- Data: `SYS_SYSTEMS` has neither 13 (cheques) nor 15 (cash boxes); all 661 posted non-stock AR transactions have `CASH_FLAG = 2`,
  `ACCOUNT_JOINT = 1`, one voucher each (`ACC_YEAR/TYPE/NO`), entry type 103 (`AR_TRNSTYPE.ENTRY_TYPE`), `POST_SYSTEM = 4`.

## Rules

1. Selection (cursor of AR_SET_EVERY_ENTRY_AC): `AR_MAINTRNS` joined to `AR_TRNSTYPE`, `NVL(ACC_POST_DATE, TRNS_DATE)` in the date range
   (posting date wins), optional ranges of type, area, branch (sub area) and serial, `POST_FLAG = 0`, `PAY_FLAG = 0`,
   `AR_TRNSTYPE.ACCOUNT_JOINT = 1`, `TRNS_SERIAL_TOT IS NULL`, cash rule `CASH_FLAG = 2 OR (CASH_FLAG = 1 AND system 15) OR
   (CASH_FLAG IN (0,3) AND system 13)`, group security `PASSWORD_NUMBER = 0 OR TRNS_ID IN AR_TRNSTYPE_PASSWORD (FLAG = 1)`,
   order `TRNS_ID, TRNS_SERIAL`. No LINK_FLAG test (stock-linked sales / returns have ACCOUNT_JOINT = 0 types).
2. Accounts (AR_GET_TRNS_DATA by the type's *_ACCOUNT_TYPE): 0 none, 1 area (`AR_MAINAREA`), 2 sub area (`AR_SUBAREA`), 3 customer
   (`CUSTOMER.ACCOUNT_NO` / `DISC_ACCOUNT`), 4 the type's account, 5 the transaction's account. ACCOUNT_TYPE 5 = the lines of
   `AR_MAINTRNS_ACCOUNT_DET` (bank / other account per line with its cost centres).
3. Cost centres: COST_NO(2)_TYPE 4 = type's cost centre, 5 = transaction's, 6 = salesman's (`SALESMAN.COST_CODE1/2`); `COST_FLAG` says
   which side gets it (1,4,5,7 transaction; 2,4,6,7 customer; 3,5,6,7 discount). With COST_NO_TYPE 4 the customer side uses the
   transaction cost centres.
4. Refusals (legacy AR_POST_MSG texts): posting date on/before `AC_BASIC.CLOSE_DATE` (NULL -> 01-01-2000) -> `CLOSE_DATE`;
   ACCOUNT_JOINT <> 1 -> `NOT ACCOUNT_JOINT = 1`; customer account not found -> `CUST ACCOUNT NULL`. Silently skipped (no message, stays
   unposted): EFFECT not 0/1, or a discount without a discount account.
5. Voucher (AR_CREATE_ENTRY_EVERY_ONE, one per transaction, `P_ENTRY_* = NULL`): number `CALC_SERIAL(year, ENTRY_TYPE, date)` (AC_TRN_CODES
   SERIAL_FLAG 0 = max(AC_DAILY_TRN, AC_YEARLY_TRN)+1, 1 = month prefix MM + 4 digits); date = posting date; values x CURRENCY_RATE.
   - Header `AC_YEARLY_TRN`: DOC_NO, ENTRY_DESC(_E) = description || ' ' || type/area/branch/serial, currency 1 rate 1, POST_SYSTEM 4,
     CREATE_COMPANY/PASSWORD/USER; ENTRY_TOTAL = total (effect 0, MEMO = description#customer#) or total + discount (effect 1, MEMO NULL).
   - Effect 0 (debit adjustments 1001-1003): customer +(total - discount) [with the transaction cost centres, as in the legacy], discount
     +discount, VAT line (sum AR_SUBTRNS.TAX_VALUE1, TX_TAXES_TYPES code 1 CR account), then ACCOUNT_DET lines -value or transaction
     account -(total - tax). ACC_CUST_SEQ 1, ACC_DISC_SEQ 2, ACC_ACC_SEQ 3.
   - Effect 1 (receipts 201-204, credit adjustments 401-403): VAT lines (AR_MAINTRNS.TAX_VALUE1 by T_TAX_FLAG1 1-4, CR / ADV accounts),
     ACCOUNT_DET lines +value or transaction account +total (+/- VAT by T_TAX_FLAG1), discount +discount, customer -(total + discount)
     with the customer cost centres.
     ACC_ACC_SEQ 1, ACC_DISC_SEQ 2, ACC_CUST_SEQ 3.
   - Lines: ENTRY_DESC(_E) = account names, MEMO = description#customer# (ACCOUNT_DET and customer lines: description||customer name||#customer#),
     BALANCE_FLAG 0. Then `AR_MAINTRNS.POST_FLAG = 1`, ACC_YEAR/TYPE/NO/DATE, and `AR_SUBTRNS.POST_FLAG = 1` for every line.
6. Cash / cheque transactions with the treasury systems installed additionally created RP_TRNS_MAST / CHECK_MAST documents (INSERT_RP_PC_TRNS).

## APEX implementation

`post_to_gl(p_from_date, p_to_date, p_from_trns_id, p_to_trns_id, p_from_mainarea, p_to_mainarea, p_from_subarea, p_to_subarea, p_from_serial,
p_to_serial, p_company_code, p_user_code, p_password_number)`; count of posted transactions in `app_proc_ar.last_count`; no COMMIT.

- The loop is a line-by-line port of AR_SET_EVERY_ENTRY_AC; `AR_GET_TRNS_DATA` is called in the schema; `AR_CREATE_ENTRY_EVERY_ONE` is a
  verbatim copy inside the package (only its local VARCHAR2(n) became VARCHAR2(n CHAR)). Reason: this AL32UTF8 build converted the columns to
  CHAR semantics after the legacy PL/SQL was compiled; the standalone copies keep 1-byte-per-character buffers and fail with ORA-06502 on long
  Arabic texts (proved on the AP twin, see VNACUPDT.md). Port check: USER_SOURCE of the standalone procedure vs the package copy differ in the
  9 declaration lines only.
- Errors: ORA-20111 date range, ORA-20112 serial range (legacy WHEN-VALIDATE-ITEM), ORA-20116 nothing to post (the security filter is
  applied, the legacy counter ignored it), ORA-20117 transactions that cannot be posted (list of up to 12 with the reason; nothing is
  posted), ORA-20118 unexpected error of one transaction (e.g. ORA-20011 closed-period / tax-period triggers).
- Deviations: (1) all or nothing - the legacy showed AR_POST_MSG without committing and the form exit rolled the run back; APEX raises the
  list instead. (2) each row is locked (`FOR UPDATE`) and skipped if already posted by a concurrent run. (3) the cash / cheque branch is not
  ported: such a transaction (only selectable with SYS_SYSTEMS 13 / 15) is refused with "الترحيل مع نظام الخزينة أو البنوك غير منفذ".
  (4) Audit: the legacy left AC_YEARLY_TRN(_DET).CREATE_DATE NULL; in APEX sessions the generated APPX_* triggers fill CREATE_DATE and UPDATE_*.

## Tests (all rolled back)

- Strong test, 2026 (real close date 2025-12-31): `cancel_gl_posting` of the 184 posted 2026 transactions, then `post_to_gl` of 2026:
  184 posted, 184 new vouchers, all balanced; compared with the originals (header + every line + AR_MAINTRNS/AR_SUBTRNS posting columns,
  ignoring ENTRY_NO, CREATE_USER_CODE and audit columns): 168 identical, 16 with data drift only.
- Strong test, 2025-2026 (close date moved to 2024-12-31 inside the test transaction): 661 cancelled and re-posted, 661 vouchers, all
  balanced: **570 identical**, 90 drift only (78 line MEMOs carry the current name of 2 renamed customers, e.g. 100100000008
  "شركه اقوي عنايه الطبيه (كرم الصحه )" -> "كرم الصحه"; 53 transactions whose AR_SUBTRNS allocation lines were added after the original
  posting and now also get POST_FLAG 1), 1 other: 403/11/1101/5 customer line COST_CODE2 NULL originally vs 101006000 now (salesman 301's
  cost centre 2; that voucher 2025/103/20039 was posted before serials 1-4 of the same type and month, whose vouchers 20084-20100 already
  carry 101006000 - the salesman cost centre was set in between).
- Single transaction 201/11/1101/350: voucher 2026/103/224 = CALC_SERIAL max+1 (original 221); second run -> ORA-20116 (no double posting).
- Group without AR_TRNSTYPE_PASSWORD rows -> ORA-20116; close date moved to 2026-12-31 -> ORA-20117 "تقع فى فترة مقفلة"; customer account
  NULL on 201/349 (range 349-350) -> ORA-20117, neither 349 nor 350 posted; system 13 inserted + close date 2023 -> the 7 unposted 902 opening
  balances (CASH_FLAG NULL) refused as treasury; reversed dates / serials -> ORA-20111 / ORA-20112.
- Override: LOV and preview SQL executed; after cancelling 2026 the preview lists 184 rows with no note and the run posts exactly 184.

## Open questions / to verify

1. All or nothing: confirm that users never committed a partial run when AR_POST_MSG was displayed (e.g. with the Save key).
2. Transactions silently skipped by the legacy (effect not 0/1, discount without discount account) stay unposted without a message; the
   preview shows "خصم بدون حساب: لن ترحل" for the discount case. Keep silent?
3. VAT: TX_TAXES_TYPES has only TAX_CODE 2, the posting reads TAX_CODE 1. No AR transaction carries TAX_VALUE1 today; a taxed transaction
   would fail (ORA-20118, as in the legacy). Confirm VAT is never recorded on AR transactions or add code 1.
4. Effect-0 vouchers put the transaction cost centres on the customer line (legacy AR_CREATE_ENTRY_EVERY_ONE); reproduced as is.
5. Cash-box / cheque systems (13, 15) are not installed; if they ever are, INSERT_RP_PC_TRNS must be ported first.
6. The legacy form could be opened from the entry screens with POST_ON_LINE = 1 to post one transaction; an APEX entry page can call
   `post_to_gl` with from = to on date, type, area, branch and serial.
7. Environment: 341 of 487 legacy PL/SQL units in SMART were compiled before the last DDL of a table they use (CHAR-semantics conversion);
   recompile the schema (`utl_recomp` / `dbms_utility.compile_schema(compile_all => true)`) before relying on legacy DB code, and review
   VARCHAR2(n BYTE) buffers that hold Arabic text.

## Coverage

Wave 3 review (AR and GL buttons): no legacy rule of this screen is missing.

- Reproduced: selection, security filter, AR_GET_TRNS_DATA / AR_CREATE_ENTRY_EVERY_ONE per transaction, closed period, messages
  (AR_POST_MSG texts), all-or-nothing run.
- **POST_ON_LINE** (question 6) is now used: the POST buttons of ARCRTRN and ARDBTRN (action POST, `app_act_ar.post_trns`) call `post_to_gl`
  with from = to on NVL(ACC_POST_DATE, TRNS_DATE), type, area, branch and serial (tested: credit settlement 401 posted as voucher 2026/103/224).
- Not reproduced, with reason: the cash / cheque branch INSERT_RP_PC_TRNS (systems 13 / 15 are not installed), printing, SET_IP.
