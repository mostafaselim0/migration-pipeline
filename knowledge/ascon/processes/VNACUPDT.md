# VNACUPDT - الترحيل للحسابات العامة (الموردين) / Post AP Transactions to the General Ledger

- Registry: system 5 serial 11 (menu `FILES_MENU.ARACUPDT`, order 404). APEX page 40170.
- **Deliverable: (b) process screen**
  - PL/SQL: `app_proc_vn.post_to_gl` in `app\db\20_proc_vn.sql` (package `APP_PROC_VN`, VALID).
  - Override: `app\legacy\overrides\VNACUPDT.json` (preview = the transactions the run will post, with the supplier account and a
    "note" column that predicts why a transaction would block the run).
- **Confidence: high.** The form source exists, the voucher code is the legacy code itself, and cancelling then re-posting all 416
  historical AP postings reproduced every voucher (405 identical to the byte, 11 differ only by a supplier renamed after posting).

## Evidence

- Source: `ASCON\VN\FMB\vnacupdt.fmb`, converted as `VN\FMB\vnacupdt_fmb.xml` (form module `VN_ACUPDT`). The compiled `vnacupdt.fmx` is
  only in `_ARCHIVE\ASCON\VN\FMB` and was compiled 2 min after the .fmb was saved (2025-11-03). `vnacupdt_e.fmx` (2004) and
  `vnacupdt_tot.fmx` (2014) are older variants.
- Button `EXECUTE_REP`: counters `GET_TRNS_COUNT_AC/PC/RP`; nothing -> "لا يوجد حركات يمكن ترحيلها"; `DELETE VN_POST_MSG WHERE USER_CODE`;
  `VN_SET_EVERY_ENTRY_AC(company, password, user, 5, dates, types, serials, V_ENTRY_YEAR, V_ENTRY_TYPE, V_ENTRY_NO, 2, 1, '', '')`;
  VN_POST_MSG rows -> shown in block VN_POST_MSG (no commit); otherwise `SUM(AC_YEARLY_TRN_DET.VALUE)` of the last voucher <> 0 ->
  `ROLLBACK` + "!!!القيد غير متوازن"; else `COMMIT_FORM` + "تمت عملية الترحيل".
- Program unit `VN_SET_EVERY_ENTRY_AC` (the posting loop) calls the DB procedure `VN_GET_TRNS_DATA` and `VN_CREATE_ENTRY_EVERY_ONE`. The form
  carries its own copy of VN_CREATE_ENTRY_EVERY_ONE; after removing comments and its debugging `MSG(n,1,0)` alerts it is identical to the DB
  procedure (normalised diff: only the first line's layout). DB helpers: `CALC_SERIAL`, `MAX_ENTRY_NO`, `INSERT_TRNS_ENTRY(_DET)`.
- The DB procedure `VN_SET_EVERY_ENTRY` is an older variant (LINK_FLAG / pay-method rules of the cancel screen, rounding, AC_TRN_CODES check);
  the form does not call it.
- List item `TRNS` (حركة سداد مجمعة / حركات أخرى / حركات تسوية فواتير موردي الخامات) only drives the LOVs of the form; it is not passed
  to the posting and is not reproduced.
- Data: `SYS_SYSTEMS` has neither 13 nor 15; all 416 posted non-stock AP transactions with a voucher have `PAY_METHOD = 5`,
  ACCOUNT_JOINT 1, one voucher each, linked in `VN_TRNS_ENTRY`; entry types 102 / 103 (`VN_TRNSTYPE.ENTRY_TYPE`), `POST_SYSTEM = 5`.
  The 40 opening balances (types 901/902, ACCOUNT_JOINT 0) are flagged posted without a voucher.

## Rules

1. Selection (cursor of VN_SET_EVERY_ENTRY_AC): `VN_MAINTRNS` joined to `VN_TRNSTYPE`, `NVL(ACC_POST_DATE, TRNS_DATE)` in the date range,
   optional type and serial ranges, `POST_FLAG = 0`, `PAY_FLAG = 0`, `ACCOUNT_JOINT = 1`, pay-method rule `PAY_METHOD = 5 OR
   (PAY_METHOD = 2 AND system 15) OR (PAY_METHOD IN (4,6) AND system 13)`, group security `VN_TRNSTYPE_PASSWORD (FLAG = 1)` unless group 0,
   order `TRNS_ID, TRNS_SERIAL`. No LINK_FLAG test (stock-linked purchases / returns have no PAY_METHOD).
2. Accounts (VN_GET_TRNS_DATA by the type's *_ACCOUNT_TYPE): 0 none, 1 `VN_MAINAREA`, 2 `VN_SUBAREA`, 3 `SUPPLIER.ACCOUNT_NO` /
   `DISC_ACCOUNT`, 4 the type's account, 5 the transaction's account; currency-difference account = `VN_TRNSTYPE.CURRENCY_ACCOUNT`.
   Cost centres type 4 / 5 as in AR; type 6 assigns the never-filled VCOST_CODE variables of the form, i.e. NULL (reproduced).
3. Refusals (legacy VN_POST_MSG texts): `CLOSE_DATE ` (posting date on/before AC_BASIC.CLOSE_DATE), `NOT ACCOUNT_JOINT = 1`,
   `SUPP ACCOUNT NULL`. Silently skipped: EFFECT not 0/1, discount without discount account.
4. Voucher (VN_CREATE_ENTRY_EVERY_ONE, one per transaction): the IN OUT key of the previous transaction is offered again, but its header
   already exists, so every transaction gets `CALC_SERIAL(year, ENTRY_TYPE, date)` (2026/102 SERIAL_FLAG 1 = month prefix, e.g. 60015;
   2026/103 flag 0 = sequential). `AC_TRN_CODES` must exist for the year / entry type (read without a handler). Date = posting date, values
   x CURRENCY_RATE. `VN_TRNS_ENTRY` links the transaction to the voucher, `VN_TRNS_ENTRY_DET` each line.
   - Effect 1 (credit adjustments 103): header description || '  type/serial', ENTRY_TOTAL total; lines VN_MAINTRNS_SUPP_ACC -value,
     VN_MAINTRNS_ACC +value, transaction account +total, one line per VN_SUBTRNS row on the supplier's VN_PAY_METHODE_ACC account for its
     PAY_TYPE_CODE -ROUND(value, 2), supplier account -(total - those lines), VAT from VN_SUBTRNS.TAX_VALUE1.
   - Effect 0 (payments 201/206, debit adjustments 202, earned discounts 207/208): header description, ENTRY_TOTAL total + discount,
     lines start at SEQ 2: transaction account -total, currency difference, VN_MAINTRNS_ACC -value (bank), VN_MAINTRNS_SUPP_ACC +value,
     VN_PAY_METHODE_ACC line for the transaction's PAY_TYPE_CODE +(ROUND(total, 2) - currency difference) with the supplier cost centres
     (and -discount on its discount account), supplier account +remainder, discount account -(discount + pay-method discounts) when the
     discount exceeds the pay-method discounts (legacy formula), VAT from VN_MAINTRNS.TAX_VALUE1.
   - Line MEMO = description || '  type/serial' (|| supplier name on supplier / pay-method lines), ENTRY_DESC = account name,
     CREATE_DATE = SYSDATE. Then `VN_MAINTRNS.POST_FLAG = 1`, ACC_YEAR/TYPE/NO/DATE, ACC_ACC_SEQ = next free SEQ.
5. Cash-box / cheque payments with the treasury systems installed additionally created RP_TRNS_MAST / CHECK_MAST documents (INSERT_RP_PC_TRNS).

## APEX implementation

`post_to_gl(p_from_date, p_to_date, p_from_trns_id, p_to_trns_id, p_from_serial, p_to_serial, p_company_code, p_user_code,
p_password_number)`; posted count in `app_proc_vn.last_count`; no COMMIT.

- Line-by-line port of VN_SET_EVERY_ENTRY_AC with the same IN OUT voucher key; `VN_GET_TRNS_DATA` is called in the schema;
  `VN_CREATE_ENTRY_EVERY_ONE` is a verbatim copy inside the package, only its 13 local VARCHAR2(n) declarations became VARCHAR2(n CHAR).
  Reason (proved): the standalone procedure was compiled at 14:47:55 on import, VN_MAINTRNS_SUPP_ACC was converted to CHAR semantics at
  14:51:58; the procedure stayed VALID with 200-byte cursor buffers and fails on 201/29 (ACC_MEMO 137 characters = 227 bytes) with
  "ORA-06502: Bulk Bind: Truncated Bind" at its `FOR C_REC IN C2` loop. The package copy, compiled now, posts it correctly.
- Errors: ORA-20141 / 20142 / 20143 ranges (legacy WHEN-VALIDATE-ITEM texts), ORA-20146 nothing to post (with the security filter),
  ORA-20147 transactions that cannot be posted (list, nothing posted), ORA-20148 unbalanced voucher (nothing posted), ORA-20149 unexpected
  error of one transaction (e.g. missing AC_TRN_CODES row, ORA-20011 of the closed-period / tax-period triggers).
- Deviations: (1) all or nothing on VN_POST_MSG (the legacy showed the block without committing; its exit rolled back). (2) the balance test
  covers every voucher of the run, the legacy tested only the last one (no historical voucher was unbalanced, so no visible difference).
  (3) rows locked `FOR UPDATE`, already-posted rows skipped. (4) cash / cheque branch not ported (refused with a message; only selectable
  with SYS_SYSTEMS 13 / 15). (5) In APEX sessions the APPX_* triggers also fill UPDATE_* audit columns of the voucher.

## Tests (all rolled back)

- Strong test, 2026 (real close date): `app_proc_vn.cancel_gl_posting` of the 142 posted 2026 transactions, `post_to_gl` of 2026: 142 posted,
  142 vouchers, all balanced; compared with the originals (header, every line, VN_MAINTRNS posting columns, VN_TRNS_ENTRY and the
  VN_TRNS_ENTRY_DET sequence of the voucher; ignoring ENTRY_NO, CREATE_USER_CODE, CREATE_DATE, audit): **135 identical**, 7 differ only in line
  MEMO (supplier 101860100000 renamed "شركة أجياد الصحة للأدوية" -> "شركة بدور المدينه للادويه").
- Strong test, 2025-2026 (close date moved to 2024-12-31 inside the test transaction): 416 cancelled and re-posted, 416 vouchers, all
  balanced: **405 identical**, 11 MEMO-only (same renamed supplier). Before the package copy this run stopped at 201/29 (ORA-06502 above).
- 215 VN_TRNS_ENTRY_DET rows of 106 transactions in the data point to older, deleted vouchers (legacy leftovers); the cancel screen removes
  them and the re-post creates only the lines of the new voucher.
- Single transaction 201/277: voucher 2026/102/60015 (original 60012; monthly numbering), 3 lines, VN_TRNS_ENTRY + 3 VN_TRNS_ENTRY_DET;
  second run -> ORA-20146. Close date 2026-12-31 -> ORA-20147 "تقع فى فترة مقفلة"; SUPPLIER.ACCOUNT_NO NULL -> ORA-20147 "حساب المورد غير معرف";
  one VN_MAINTRNS_ACC value +1 -> ORA-20148 "!!!القيد غير متوازن (2026/102/60015)"; reversed dates / types -> ORA-20141 / ORA-20142.
- Override: LOV and preview SQL executed; after cancelling 2026 the preview lists 142 rows with no note and the run posts exactly 142.

## Open questions / to verify

1. All or nothing: confirm users never committed a partial run while VN_POST_MSG was shown.
2. Balance test on every voucher instead of the last one only: confirm (safer; identical on all historical data).
3. VAT: TX_TAXES_TYPES has only TAX_CODE 2 while the posting reads TAX_CODE 1 (no AP transaction carries TAX_VALUE1 today); a taxed
   transaction would fail as in the legacy.
4. `AC_TRN_CODES` has no 2027 rows: the first AP posting of a new year fails until the GL journal types of the year exist (AR posting
   creates them through CALC_SERIAL; AP reads SERIAL_FLAG first). Legacy behaviour, reproduced.
5. Cash-box / cheque systems not installed; port INSERT_RP_PC_TRNS before installing them.
6. The legacy form could be opened from another screen (FROM_SCREEN / POST_ON_LINE) for one transaction; an APEX page can call
   `post_to_gl` with from = to on date, type and serial.
7. Environment: recompile the legacy PL/SQL of SMART after the CHAR-semantics conversion (341 of 487 units predate the last DDL of a table
   they use); the standalone VN_CREATE_ENTRY_EVERY_ONE (also used by DB VN_SET_EVERY_ENTRY) still fails on 201/29-like data.
