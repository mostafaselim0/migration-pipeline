# ACUPDT: Posting daily entries (ترحيل القيود اليومية)

- Registry: system 1, serial 71, menu `SYSTEM_MENU.POSTING`. APEX page 10200.
- Deliverable: **(b) process screen**. `app_proc_gl.post_entries` in `app\db\20_proc_gl.sql`, override `app\legacy\overrides\ACUPDT.json`.
- Confidence: **high** for the test and move logic, which comes from the full SQL in the .fmx. It is **medium** on three points listed under "Open questions".

## Purpose

Daily entries (`AC_DAILY_TRN` / `AC_DAILY_TRN_DET`, entered in the daily-entry screen) are tested and moved to the posted entries (`AC_YEARLY_TRN` / `AC_YEARLY_TRN_DET`). All reports and balances read the posted tables only.

## Inputs (legacy BLOCK2 items; APEX items `P10200_<NAME>`)

| Item | Meaning | Rule |
|---|---|---|
| FROM_YEAR, FROM_TYPE, FROM_NO | first voucher (year / entry type / entry no.) | year and type required (`من فضلك تأكد من إدخال نوع القيد من و إلى و إدخال سنة القيد من و إلى`) |
| TO_YEAR, TO_TYPE, TO_NO | last voucher | same |
| FROM_DOC_NO, TO_DOC_NO | DOC_NO range, optional | |
| FROM_ENTRY_DATE, TO_ENTRY_DATE | ENTRY_DATE range, optional | |
| ACTION (radio TEST_ONLY / TEST_POST) | `إخـتبـار فقــــط` / `اخـتبـار و ترحـيـل` | APEX: list TEST_ONLY (1 test only, default / 0 test and post) |

**Range semantics** (from the .fmx SQL): the range is on the concatenated key `LPAD(year,4)||LPAD(type,4)||LPAD(no,6)`, between `from_year/from_type/NVL(from_no,0)` and `to_year/to_type/NVL(to_no,999999)`. It is a voucher range, not three independent ranges. This is reproduced in `app_proc_gl.voucher_key` / `in_range`.

**Defaults** (from the .fmx SQL): years = `AC_BASIC.CURRENT_YEAR`. Types = MIN/MAX(ENTRY_TYPE) of the year's daily entries that the user may see (`daily_type_bound`). The legacy form also defaulted the numbers and dates to MIN/MAX. These are not reproduced, because empty values mean "open".

## Security

The main cursor filters `(ENTRY_YEAR, ENTRY_TYPE) IN AC_PASSWORD_ENTRY (PASSWORD_NUMBER = group, COMPANY_CODE = company)` unless the group is 0. This is reproduced in `type_allowed`, and the same function drives the type LOVs.

- **Deviation:** the legacy treated a NULL group or company like group 0 (unrestricted). APEX treats NULL as restricted.
- `GLOBAL.USR_ENTRY_YEAR` / `USR_ENTRY_TYPE` have no APEX equivalent (`app_sec.post_auth` does not set them), so they are ignored.
- On this copy `AC_PASSWORD_ENTRY` is empty. Groups 101 and 102 therefore can post nothing (faithful). Test T3 covers this.

## Processing (TEST_AND_UPDATE = TEST_PROC + UPDATE_PROC)

1. `DELETE FROM AC_UPDT_TBL` (work table), then the cursor over the daily entries of the range. APEX locks them `FOR UPDATE NOWAIT`.
2. **TEST_PROC**: one `AC_UPDT_TBL` row per problem, in Arabic or English according to the language. The texts are the legacy literals, cut to the 50-character column.
   - For each line, the first failing check wins (the PK is year/type/no/seq):
     - account missing in AC_MASTER: `رقم الحساب غير موجود`
     - `ACCOUNT_STATUS <> 1`: `الحســاب ليس على أدنى مستــوى`
     - `AC_MASTER.CURRENCY_CODE <> entry CURRENCY_CODE` (NULL on either side = no error, as in PL/SQL): `العملة المحددة للحسـاب غير تلك المستخدمة فى القيد`
     - *(added)* unknown cost centre 1 / 2. `AC_YEARLY_TRN_DET` has FKs to AC_COST_CENTERS / AC_COST_CENTERS2 and the daily table has none, so the legacy would have hit a raw FK error.
   - For each entry:
     - `ENTRY_DATE <= AC_BASIC.CLOSE_DATE`: `يجب أن يكون تاريخ القيد أكبر من تاريخ الأقفال` (seq -1)
     - debit ≠ credit (`ROUND(SUM(VALUE),2) <> 0`): `الجانب المدين لا يساوى الجانب الدائن` (seq -2)
     - key already in AC_YEARLY_TRN: `القيد مكرر فى ملف القيود اليومية و الفورية` (seq -3). The legacy text is in the .fmx; the APEX version pre-checks it to refuse double posting.
3. If any error exists, **nothing is posted** (all-or-nothing). The legacy showed `يوجد خطأ ببعض القيود فى النطاق المحدد، راجع أخطاء الترحيل` and ran the ACPSTERR error report. APEX raises -20110 with the count and the first 5 errors. The page preview lists every daily entry of the range with its debit, credit and `AC_UPDT_TBL` messages.
4. Test only, with no errors: message `لا توجد أخطاء في قيود الترحيل`.
5. **UPDATE_PROC**, per entry:
   - `INSERT INTO AC_YEARLY_TRN … SELECT … FROM AC_DAILY_TRN` with `CLOSE_FLAG = 0`, `POST_SYSTEM = 1`, `POST_USER = GLOBAL.USER_CODE`.
   - `INSERT INTO AC_YEARLY_TRN_DET` per line, with `ENTRY_DATE = header date` and `CLOSE_VALUE = 0`.
   - `DELETE AC_DAILY_TRN_DET`, then `DELETE AC_DAILY_TRN`.
   - Success message: `لقد تم ترحيل القيود فى النطاق المحدد بنجـــاح`.

DB triggers that still apply on insert:
- `AC_CLOSE_ACYR` / `AC_CLOSE_ACYR_DET`: close date.
- `AC_YRLY_TRN_TAX` / `AC_YRLY_TRN_DET_TAX`: authorised tax period.
- `REV_AC_YEARLY_DET`.

A trigger refusal aborts the whole run with -20112, and APEX rolls back.

## Balances: AC_MASTER is not updated

Checked on real data:
- All 328 accounts have `CURRENT_LOC`, `CURRENT_FOR`, `BEGIN_PERIOD_*` and `BEGIN_YEAR_*` = 0/NULL, while 153 accounts have posted movements.
- No DB code (384 units) references `CURRENT_LOC` or `BEGIN_PERIOD_LOC`.
- The subsystem posting procedures (`AR_CREATE_ENTRY_EVERY_ONE`, `VN_CREATE_ENTRY_EVERY_ONE`) insert into `AC_YEARLY_TRN` directly and never touch AC_MASTER.
- `GET_BALANCE` (GET_BAL .pll) computes balances as `BEGIN_PERIOD_LOC/BEGIN_YEAR_LOC + SUM(AC_YEARLY_TRN_DET.VALUE * RATE)`.
- The ACUPDT .fmx has no AC_MASTER update statement.

Posting therefore only moves rows. Opening balances are carried as the opening entry 2024/100/1.

## Deviations (deliberate, to verify)

1. **All common columns are copied.** The legacy INSERT list copied only TAX_FLAG / TAX_ACCOUNT, not the VAT invoice columns: CUST_NAME, CUST_TAX_NO, CUST_INV_NO, CUST_INV_VAL, CUST_NOTES, CUST_INV_DATE, T_TAX_FLAG1, CUST_CODE, TAX_TRNS_DATE, TAX_INVOICE_NO, and AUTO_TRNS_FLAG / UPDATE_*. Posted GL entries on this copy carry T_TAX_FLAG1 on 3,853 lines and CUST_* on 7 lines. Dropping them on posting would lose VAT data, so they are copied.
2. `AC_UPDT_TBL` is no longer emptied completely. Only the rows of the entries in this run are replaced, plus rows of entries that no longer wait in AC_DAILY_TRN. This keeps multi-user runs from wiping each other's errors. The table is written in an **autonomous transaction** (committed), because the legacy also committed it for the Reports-server error report and APEX rolls back on error.
3. The legacy inserted all headers of the range with one `INSERT … SELECT` without the security filter. The APEX version inserts per locked, tested entry.
4. POSTING_ERRORS.pll `CHECK_POSTING` is **not** the balance check. It is an ON-ERROR handler that maps DB errors -1235 / -1236 / -1237 (date before close date, account not allowed, cost centre not allowed). None of the five GL forms attach it, and no trigger on this copy raises those codes. The debit = credit rejection comes from ACUPDT's own TEST_PROC and is reproduced there.

## Wave 3: currency-difference line (implemented)

- The ACUPDT .fmx inserts `VALUES (..., 999, CURRENCY_ACCT, date, name, name_e, (-:total_debit + :total_credit), NULL, 0, 1, NULL, NULL, audit)`
  after `SELECT CURRENCY_ACCT FROM AC_BASIC WHERE COMPANY_CODE = :b1`, with the message `لابد من تعريف حساب فروق العملة ببيانات النظام`. The
  condition and the totals are those of the identical UPDATE_PROC of ACDLYTR (readable in its .fmb): NUMBER(14,2) running totals of
  `ROUND(VALUE,2) * RATE` (debit lines / credit lines), line written when `CURRENCY_CODE <> 1` and the totals differ; the VALUE is in local
  currency (rate applied).
- APEX: `app_proc_gl.currency_diff_line`, called by `post_entries` for each entry before the daily lines are deleted (ORA-20113 when the account
  is missing). Test (t_gl.py Y3): a currency-2 entry at 3.75 (3 x 0.01 against 0.03, accounts temporarily in currency 2) -> line 999 = -0.01;
  regression T1 (2026/101/60001-60022 unposted and reposted) identical, no 999 line for currency 1.

## Wave 3b

The legacy radio group ACTION (TEST_ONLY 'إخـتبـار فقــــط' / TEST_POST 'اخـتبـار و ترحـيـل', GN_FORM_ITEM_RAD) was a check box on the
page; the TEST_ONLY parameter is now a list with the two legacy choices (1 = test only, default as before; 0 = test and post). The run
button keeps the insert right (the screen posts). SQL of the list run on the build copy.

## Coverage

Reproduced: selection, security, TEST_PROC, all-or-nothing, UPDATE_PROC with the currency-difference line (wave 3), the action radio as a
list (wave 3b). Not reproduced, with reason:

- **Suspended accounts (STOP_FLAG)**: the ON-ERROR text `الحساب متوقف بالحسابات` is the mapping of ORA-20011, which on this schema is raised
  by the close-date / tax-period / revision triggers (AC_CLOSE_ACYR, AC_YRLY_TRN_TAX, CLOSE_AC_DAILY_TRN, REV_AC_YEARLY_DET), not by a
  stopped-account rule; no code tests AC_MASTER.STOP_FLAG. Decision: no STOP_FLAG check (those trigger errors are reported with their text).
- Cost-centre balancing lines (COST_CODE1_BAL / COST_CODE2_BAL = 0 on this company; commented out in ACDLYTR).
- ACPSTERR error report (errors are listed in the message and kept in AC_UPDT_TBL), SET_IP.

## Open questions

- **Currency rule.** Is "account currency ≠ entry currency" the exact rule, or only for foreign-currency accounts (ACDLYTR's TEST_PROC accepts
  local-currency accounts in a foreign entry)? It has no effect on this copy, where every account is currency 1.
- The 999 line needs AC_BASIC.CURRENCY_ACCT, which is NULL today: set it before foreign-currency entries are used.

## Tests run (all ended with ROLLBACK; table fingerprints identical before and after)

- **T1:** unpost 2026/101/60001–60022 (22 entries, 127 lines), test only (no errors), then post back. Headers and all lines are identical, including the VAT columns. POST_SYSTEM = 1, CLOSE_FLAG = 0, POST_USER = user, entries balanced.
- **T2:** injected errors (unbalanced, non-leaf account, date before close date, duplicate key). Refused with -20110, the four AC_UPDT_TBL rows are correct, nothing posted, in both test-only and post mode.
- **T3:** group 101 without a grant sees nothing. A NULL group is restricted. With a temporary AC_PASSWORD_ENTRY grant, group 101 can post and unpost type 101 but not type 102.
- **T7d:** an entry created by AC_DUPENTRY passes the posting test.
- **T8:** inside an APEX session (APPX_* triggers active), the round trip leaves the business columns identical, the success message is set in `apex_application.g_print_success_message`, and `G_LANG = en` gives the English texts. The generated APPX_* triggers fill NULL UPDATE_* audit columns in an APEX session; that behaviour belongs to the generator, not to this package.

## What a human must verify

- Whether the VAT columns should travel with posting (deviation 1). Recommended: yes.
- The currency rule and CURRENCY_ACCT (questions above), before any foreign-currency entry is used.
- That nobody depends on the legacy "empty the whole AC_UPDT_TBL" behaviour.
