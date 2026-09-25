# AC_DUPENTRY: Create periodical entry (إنشاء القيد الدورى)

- Registry: system 1, serial 84, menu `القيود_الدورية_MENU.AC_DUPENTRY`. APEX page 10040. The definitions (`AC_PERIODICAL_VOC`) are maintained in AC_DUPENTRY_DEF (page 10030, GRID, not in this scope).
- Deliverable: **(b) process screen**. `app_proc_gl.create_periodical_entry` in `app\db\20_proc_gl.sql`, override `app\legacy\overrides\AC_DUPENTRY.json`.
- Confidence: **medium-high**. All 11 SQL statements come from `ASCON\AC\FMB\ac_dupentry.fmx`. Which of two INSERT variants belongs to which source is inferred (see Open questions).

## Purpose

A periodical entry (monthly rent, insurance instalment, salaries…) is defined once as a reference to an existing entry (`AC_PERIODICAL_VOC`: SERIAL, ENTRY_YEAR, ENTRY_TYPE, ENTRY_NO, ENTRY_DESC). This screen copies that entry into a **new unposted daily entry**, which is then posted with ACUPDT. There are 12 definitions on this copy, all referencing posted 2025/2026 entries of journal 101.

## Inputs

- **DUPENTRY_LIST**: the definition.
  - The legacy list was `AC_PERIODICAL_VOC` whose entry exists in `AC_YEARLY_TRN` of the user's company.
  - It was filtered by `AC_PASSWORD_ENTRY` (group ≠ 0) and `USR_ENTRY_YEAR/TYPE`. The latter has no APEX equivalent.
- **NEW_TYPE**: the target journal. The legacy LOV was `AC_TRN_CODES` with `NVL(AC_FLAG,0) = 0` (GL journals only), filtered by `AC_PASSWORD_ENTRY`. Legacy message when empty: `لا بد من إدخال رقم اليومية المراد إنشاء القيد عليها`.
- **NEW_DATE**: the new entry date. When empty the legacy asked `تاريخ القيد المنسوخ سوف يساوى تاريخ القيد الاصلي` (Continue / Cancel) and used the source date. APEX: empty means the source date, as stated in the label.

## Processing (EXE_BTN trigger)

1. Definition, then source entry:
   - First `AC_YEARLY_TRN` (key and `CREATE_COMPANY_CODE = company`), else `AC_DAILY_TRN`, else `لايوجد قيد بهذا الرقم ...!`.
   - A source without lines gives `رقم القيد غير موجود بالحسابات`.
2. `NVL(NEW_DATE, source date) <= AC_BASIC.CLOSE_DATE`: `لا يمكن إنشاء الحركة لأنها تقع فى فترة مقفلة`.
3. The new year is `TO_CHAR(new date,'YYYY')`. The new number is `CALC_SERIAL(new year, NEW_TYPE, new date)`; with SERIAL_FLAG = 1 it is month-based, for example 07/2026 gives 70001.
4. `UPDATE AC_TRN_CODES SET LAST_SERIAL = new number WHERE ENTRY_YEAR = new year AND ENTRY_TYPE = NEW_TYPE`.
5. `INSERT AC_DAILY_TRN`:
   - new year / NEW_TYPE / new number
   - DOC_NO = new number when the source is posted, the source DOC_NO when the source is daily
   - ENTRY_DATE = new date
   - the source ENTRY_DESC(_E), CURRENCY_CODE, RATE, ENTRY_TOTAL, MEMO(_E)
   - CREATE_* = session, `CREATE_DATE = SYSDATE`
6. `INSERT AC_DAILY_TRN_DET` per source line (lines of the same company):
   - SEQ, ACCOUNT_NUMBER, ENTRY_DESC(_E), VALUE, COST_CODE, COST_CODE2, MEMO(_E), BALANCE_FLAG
   - CREATE_* = session, SYSDATE
   - **VAT fields (TAX_FLAG, TAX_ACCOUNT, T_TAX_FLAG1, CUST_*) are not copied, as in the legacy.** They belong to the original invoice and must be entered on the new entry if needed.
7. Message: `تم نسخ القيد برقم y/t/n`.

DB triggers on the daily tables still apply: `CLOSE_AC_DAILY_TRN` (date between AC_BASIC MIN_DATE and MAX_DATE) and `TRIG0001` (no zero-value line).

## Deviations

- The target journal must already exist for the **new** year as a GL journal (AC_FLAG = 0) granted to the group (-20165 / -20166). The legacy LOV only checked the source year, and `CALC_SERIAL` silently inserts a missing `AC_TRN_CODES` row. The APEX version refuses instead of creating journals implicitly.
- The `AC_TRN_CODES` row is locked `FOR UPDATE` before `CALC_SERIAL`, so two users cannot get the same number.

## Open questions

- **DOC_NO variant.** The .fmx has two header INSERTs, one with `DOC_NO = new number` and one with `DOC_NO = source DOC_NO`. By statement order the first belongs to the posted-source branch. Confirm.
- **VAT fields.** Should the VAT flag (TAX_FLAG / T_TAX_FLAG1 / TAX_ACCOUNT) be copied for recurring VAT-able expenses such as rent? The legacy did not copy them.
- **Double creation.** Running the screen twice creates two entries, as in the legacy. APEX's redirect after submit prevents accidental refresh resubmits. Is a "same definition, same month" guard wanted?

## Tests run (ROLLBACK after each; fingerprints unchanged)

- **T7a–c:** definition 23 (2026/101/30048, 73 lines) to journal 101 on 2026-07-01 gives daily entry 2026/101/70001 with DOC_NO 70001. All 73 lines are copied (sum 0), and LAST_SERIAL goes from 50066 to 70001.
- **T7d:** the new entry passes the ACUPDT posting test.
- **T7e–j:** refusals checked:
  - closed-period date
  - subsystem journal 102 (AC_FLAG = 1)
  - journal not defined for 2027
  - group without a grant
  - missing journal
  - empty date on a 2025 source (source date, closed period)

## What a human must verify

- The DOC_NO rule, the VAT-field rule and the stricter journal check (questions above).


## Wave 3b

Checked, nothing to change: the list item DUPENTRY_LIST and the journal type already are lists (the type list shows the NEW_TYPE_NAME display); the screen creates entries (insert right kept); EXE_BTN / EXIT_BTN only.

## Coverage

Wave 3 review (AR and GL buttons): no legacy rule of this screen is missing. Reproduced: both source branches (posted / daily), numbering with
CALC_SERIAL, new date / journal, closed-period checks. Not reproduced, with reason: the implicit creation of a missing AC_TRN_CODES row by
CALC_SERIAL (refused instead, see Deviations), printing, SET_IP. The VAT flags are not copied, as in the legacy (open question).
