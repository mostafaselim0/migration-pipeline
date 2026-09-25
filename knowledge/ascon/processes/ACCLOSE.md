# ACCLOSE: Closing entries / year-end closing (قيود الإقفال)

- Registry: system 1, serial 73, menu `SYSTEM_MENU.ACCLOSE`. APEX page 10220.
- Deliverable: **(b) process screen**. `app_proc_gl.create_closing_entry` (preview: `app_proc_gl.closing_preview`) in `app\db\20_proc_gl.sql`, override `app\legacy\overrides\ACCLOSE.json`.
- Confidence: **high** for local-currency accounts. The existing legacy closing entry 2025/101/120084 was deleted and recreated line for line: 515 lines with identical account, cost centre 1, cost centre 2, VALUE, CLOSE_VALUE and text. It is **medium** on the points under "Open questions".

## Purpose

Creates a closing entry (`CLOSE_FLAG = 1`) dated on the closing date. The entry:
- zeroes every income and expense leaf account, per (COST_CODE, COST_CODE2) pair, up to that date;
- puts the net result on the profit and loss account;
- then moves `AC_BASIC.CLOSE_DATE` to that date.

After that the DB triggers `AC_CLOSE_ACYR`, `AC_CLOSE_ACYR_DET` and `CLOSE_AC_DAILY_TRN` refuse any change dated on or before it.

## Inputs (legacy BLOCK1; APEX `P10220_<NAME>`)

- **ENTRY_YEAR**: default `AC_BASIC.CURRENT_YEAR`.
- **ENTRY_TYPE**: LOV `AC_TRN_CODES` filtered by `AC_PASSWORD_ENTRY`.
- **CLOSE_DATE**: required.
- `ENTRY_NO` was a display item holding the created number; APEX shows it in the result message.

## Parameters (AC_BASIC, company = G_COMPANY_CODE)

- `INCOME1_ACCT` (400000000000), `OUTCOME1_ACCT` (300000000000), `PROFIT_ACCT` (220102001001 "الارباح والخسائر للفترة").
- If any is NULL: `مؤشرات النظام غير مكتملة`.
- The prefix length of the income and expense groups is `AC_CHART_STRUCTURES.CHR_STRU_END` of the account's `ACCOUNT_LEVEL` (level 1 gives 1 digit, so the groups are `4…` and `3…`).

## Validations (.fmx, CHECK_DATE from TRANSLATE.pll, CLOSE_DATE item validation)

- Date not in the future: `تاريخ الحركة أكبر من تاريخ اليوم`.
- Date not before `AC_BASIC.MIN_DATE`: `الحد الأدنى لتاريخ الحركة هو …`.
- Date after the last closing date: `يجب إدخال تاريخ أكبر من آخر تاريخ إقفال`.
- Closing date year not before the entry year: `تاريخ الإقفال يقع فى سنة أقل من سنة قيد الإقفال المطلوب!!!`.
- *(added)* The journal (year, type) must exist and be granted to the group.
- **Blocking** (CLOSE_ENTRY_PROC): unposted daily entries dated after the last closing date and up to the new date on an income or expense account (security: AC_PASSWORD_MASTER of the group) give `لا يمكن عمل قيد اقفال بسبب وجود قيود بها حسابات مصروفات أو إيرادات غير مرحلة`.
- **Warnings only** (CHECK_CLOSE_DATE, CHECK_CLOSE_STORES; msg_alert). These are appended to the result message:
  - unposted AC_DAILY_TRN up to the date: `توجد قيود غير مرحلة قبل هذا التاريخ`
  - `AR_MAINTRNS`, `VN_MAINTRNS`, `ST_TRNS_MAST` with `POST_FLAG = 0` up to the date: `…فى نظام العملاء/الموردين/المخازن…`
  - **Evidence that these did not block:** ST_TRNS_MAST has 80 unposted 2025 documents, yet the 2025 closing was made.

## Lines (GET_BALANCE program unit and TEMP_CLOSE)

1. Loop over income leaf accounts (`ACCOUNT_STATUS = 1`, prefix of INCOME1_ACCT), then expense leaf accounts.
   - Non-admin groups are limited to accounts that match (by `ACCOUNT_END_POS` prefix) any `AC_PASSWORD_MASTER` row of the company. This is the legacy cursor, which filters on the company only.
2. For each account: `SUM(D.VALUE * Y.RATE)` from `AC_YEARLY_TRN` / `_DET` with `ENTRY_DATE <= close date` and `D.VALUE != 0`, grouped by `COST_CODE, COST_CODE2`.
   - Earlier closing entries are included, so the balance is the one since the previous closing.
   - Non-admin groups count only entries of their company.
   - Each non-zero group gives a line with `VALUE = CLOSE_VALUE = -balance`.
3. `BEGIN_PERIOD_LOC` is subtracted from the account's line without cost centres (legacy `UPDATE TEMP_CLOSE`). It is 0 for every account on this copy.
4. The profit line is `PROFIT_ACCT`, with `VALUE = CLOSE_VALUE = TOTAL_CREDIT - TOTAL_DEBIT`, no cost centres, and the profit account's name as the text.
5. Line order: `VALUE > 0` lines first, then `VALUE < 0`, SEQ 1..n. This matches the existing entry: debits are seq 1–23, credits 24–515.

## Writes

- **Entry number:** `CALC_SERIAL(entry_year, entry_type, close_date)`, the DB function the legacy form called as `FALAH_RNT.CALC_SERIAL`. With SERIAL_FLAG = 1 it is month-based (for example 120084, 60023). `AC_TRN_CODES.LAST_SERIAL` is not updated, as in the legacy.
- **`AC_YEARLY_TRN`:**
  - ENTRY_NO = DOC_NO = number, ENTRY_DATE = close date
  - `ENTRY_DESC = 'قــيــــد الاقـفـــــــال'`, `ENTRY_DESC_E = 'Closing Entry'`
  - currency 1, rate 1, `CLOSE_FLAG = 1`, `POST_SYSTEM = 1`
  - ENTRY_TOTAL = debit total, CREATE_* from the session
- **`AC_YEARLY_TRN_DET`:** per line, ENTRY_DATE = close date, `BALANCE_FLAG = 0`, MEMO NULL.
- **`UPDATE AC_BASIC SET CLOSE_DATE = close date WHERE COMPANY_CODE = company`.**
- **Result message:** `تـم عـمـل قـيــد الاقـفـال بالـرقــم y/t/n (lines, total) …` plus any warnings.
- **Concurrency:** the legacy locked TEMP_CLOSE and AC_TRN_CODES with `LOCK TABLE … IN EXCLUSIVE MODE`. APEX locks the AC_BASIC row and the AC_TRN_CODES row `FOR UPDATE` and builds the lines in memory instead of the shared TEMP_CLOSE table (TEMP_CLOSE has no session key).

AC_MASTER balance columns are not touched. They are 0/NULL for every account on this copy, and all balances are summed from AC_YEARLY_TRN_DET (see ACUPDT.md).

## Deviations

- The blocking check uses `NVL(last close date, 0001-01-01)`. The legacy `ENTRY_DATE > NULL` silently skipped the check when no closing existed.
- `NVL(Y.RATE,1)` (as in GET_BALANCE) instead of `Y.RATE`. There is no difference on this copy.
- The profit line is omitted when the result is exactly 0. The legacy would have written a 0-value line.
- If `BEGIN_PERIOD_LOC <> 0` and the account has no line without cost centres, a line is added. The legacy UPDATE would have lost the amount.
- `CREATE_DATE = sysdate` (the legacy left it NULL).

## Open questions (for the key user or vendor)

1. **Foreign-currency accounts.** The legacy had a second branch for accounts whose AC_MASTER.CURRENCY_CODE is not local:
   - balance = `SUM(DECODE(Y.CURRENCY_CODE, acct currency, D.VALUE, DECODE(Y.CLOSE_FLAG, 1, CLOSE_VALUE, 0)))`
   - `VALUE = -bal * AC_CURRENCY.RATE`, `CLOSE_VALUE = -bal`
   - the SQL binds the same value to COST_CODE and COST_CODE2, which looks like a bug

   Every account on this copy is currency 1, so the APEX version **refuses** a foreign-currency income, expense or profit account (-20139) instead of guessing. The rule is needed before foreign-currency P&L accounts are used.
2. **ENTRY_TOTAL.** The legacy stored 30,849,439.37 on the 2025 entry, while its debit lines sum to 30,849,439.38. APEX stores the debit total. Which figure did the legacy use?
3. **Warnings.** Confirm that the unposted GL, AR, VN and ST checks were warnings. The data shows the 2025 closing was made with unposted ST documents.
4. **CHECK_DATE.** Confirm it was called with IS_CHECK = 0, meaning no maximum-date check but no future dates.

## Tests run (ROLLBACK after each; fingerprints unchanged)

- **T5:** cancel the 2025 closing (AC_DELETECCLOSE), then recreate it with 2025, 101, 2025-12-31.
  - Same number 2025/101/120084 and DOC_NO.
  - The 515 lines are identical to the legacy entry (account, cost centres, VALUE, CLOSE_VALUE, text), debits first.
  - `closing_preview` returns the same 515 lines, and CLOSE_DATE is back to 2025-12-31.
  - The only difference is ENTRY_TOTAL, .38 against the legacy .37.
- **T6:** new closing at 2026-06-30.
  - Entry 2026/101/60023, 380 lines, balanced, ENTRY_TOTAL = debit total.
  - After it, every income/expense account x cost-centre balance is 0 at that date, and CLOSE_DATE = 2026-06-30.
  - A second run is refused. Cancelling returns CLOSE_DATE to 2025-12-31.
  - Refusals checked: date not after the last closing, future date, year mismatch, unknown journal, group without a grant, and an unposted daily entry on an income account (blocking).
  - The warnings for 114 unposted AR and 161 unposted ST documents appear in the message.

## What a human must verify

- The four questions above.
- The accountant should compare the preview for the next real closing date with the legacy system before the first production closing.


## Wave 3b

Checked, nothing to change: ENTRY_NO (قيـد الأقفـــال) is a display of the created entry, reported in the success message; the journal type has its list; the screen writes data (insert right kept); EXECUTE / EXIT are the only buttons.

## Coverage

Wave 3 review (AR and GL buttons): the only legacy branch not reproduced is the **foreign-currency account** balance (open question 1): every
account is currency 1 on this copy and the legacy SQL binds the same value to COST_CODE and COST_CODE2 (apparent bug), so the APEX version
refuses such an account (-20139) instead of guessing. Everything else (lines per account and cost-centre pair, profit line, CLOSE_DATE,
warnings for unposted documents, CHECK_DATE) is reproduced. Not reproduced: printing, SET_IP.
