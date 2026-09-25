# ACCUPDT: Cancel posting (إلغاء ترحيل القيود)

- Registry: system 1, serial 72, menu `SYSTEM_MENU.POSTING_CANCLE`. APEX page 10210.
- Deliverable: **(b) process screen**. `app_proc_gl.cancel_posting` in `app\db\20_proc_gl.sql`, override `app\legacy\overrides\ACCUPDT.json`.
- Confidence: **high**. The full SQL is in `ASCON\AC\FMB\ACCUPDT.fmx`, and posted entries were unposted then reposted on real data.

## Purpose

Moves posted GL entries back from `AC_YEARLY_TRN/_DET` to the daily tables `AC_DAILY_TRN/_DET` so they can be edited, then reposted with ACUPDT.

## Inputs

Same range items as ACUPDT: FROM/TO_YEAR, FROM/TO_TYPE, FROM/TO_NO, FROM/TO_DOC_NO, FROM/TO_ENTRY_DATE. Years and types are required, with the same legacy message and the same concatenated voucher-key range. The years default to `AC_BASIC.CURRENT_YEAR`.

## Selection (legacy cursor MAS, reproduced exactly)

`AC_YEARLY_TRN` in the voucher range, the DOC_NO range and the date range, and:
- `NVL(CLOSE_FLAG,0) != 1`: closing entries are never unposted. They are cancelled with AC_DELETECCLOSE.
- `NVL(POST_SYSTEM,0) = 1`: only entries posted by the GL.
  - Subsystem entries (3 stores, 4 customers, 5 vendors, 30 purchases, 31 sales) are excluded; they are cancelled in their own systems.
  - The legacy LOVs excluded `POST_SYSTEM IN (2,5)`.
  - The legacy form asked `نوع القيود المراد إلغاء ترحيلها وارد من أنظمة أخري !! هل تريد الإستمرار` when a type has `AC_TRN_CODES.AC_FLAG = 1`. Because of the POST_SYSTEM filter such entries are never processed anyway, so APEX only has the general confirmation.

## Security

- **Deviation:** the legacy main cursor had no security filter; security came only through the type LOV (AC_PASSWORD_ENTRY) and the entry-number LOV (creator group).
- APEX applies the same `AC_PASSWORD_ENTRY` type filter as ACUPDT inside the cursor, so a range cannot reach types the group may not use.
- A NULL group is restricted.

## Processing

1. `COST_BAL_FLAG_PROC`: if `AC_BASIC.COST_CODE1_BAL = 1` and `COST_CODE_ACCT1` is NULL, raise `رقم حساب جارى مراكز التكلفة 1 غير موجود فى مؤشرات النظام !!`. The same applies to cost centre 2.
2. The entries of the range are locked (`FOR UPDATE NOWAIT`) and processed in key order.
   - `ENTRY_DATE <= AC_BASIC.CLOSE_DATE`: skipped and reported with `لا يمكن إلغاء ترحيل الحركة رقم … لأنها تقع فى فترة مقفلة`.
   - *(added)* key already in AC_DAILY_TRN: skipped with `القيد مكرر فى ملف القيود اليومية و الفورية` (legacy: a DUP_VAL_ON_INDEX error).
   - Otherwise:
     - `INSERT AC_DAILY_TRN` (header columns, incl. CREATE_* / UPDATE_*)
     - `INSERT AC_DAILY_TRN_DET` per line
     - `DELETE AC_YEARLY_TRN_DET`, then `DELETE AC_YEARLY_TRN`
     - if `AC_BASIC.DEL_BAL_SIDES = 1`, delete the automatic cost-centre balancing lines. These are identified by the legacy literals: account `COST_CODE_ACCT1/2`, ENTRY_DESC `'حساب جارى مراكز التكلفة 1'` / `'حساب جارى مراكز التكلفة 2 '` (with the trailing space), MEMO `'طرف آلى لكى يتوازن القيد على مستوى مركز التكلفة 1/2'`.
3. An entry refused by a DB trigger is rolled back to a savepoint and reported; the others continue. Refusing triggers include tax period authorised (`AC_YRLY_TRN_TAX`), revision flag with `AC_BASIC.REV_FLAG = 1` (`REV_AC_YEARLY`), and a zero-value line (`TRIG0001` on the daily detail).
4. Result, following the legacy counters V_ALL_COUNTER / V_POST_COUNTER:
   - All succeeded: `لقد تم إلغاء ترحيل القيود فى النطاق المحدد بنجـــاح`.
   - Some succeeded: those are kept (committed by APEX, as the legacy committed them) and the message is `تم إلغاء ترحيل n من m قيد. يوجد خطأ ببعض القيود فى النطاق المحدد | …` with up to 8 reasons.
   - None succeeded: raise -20123 with the reasons.

AC_MASTER balances are not touched (see ACUPDT.md, "Balances").

## Deviations

1. **All common columns are copied back**, including the VAT columns (CUST_*, T_TAX_FLAG1, CUST_CODE, TAX_TRNS_DATE, TAX_INVOICE_NO, AUTO_TRNS_FLAG). The legacy list copied only TAX_FLAG / TAX_ACCOUNT, so a cancel and repost lost VAT invoice data.
2. Posted-only columns are lost in the daily table, as in the legacy: POST_USER, REV1–REV4, CLOSE_VALUE. A repost sets POST_USER to the new poster.
3. The security filter is applied in the cursor (see above).

## Open questions

- Should the AC_FLAG = 1 confirmation also be kept for GL-posted entries in subsystem journals? None exist today.
- Should entries with `REV1 = 1` (revised) be blocked even when `AC_BASIC.REV_FLAG = 0`? The legacy blocked them only through the trigger with REV_FLAG = 1.

## Tests run (ROLLBACK after each; fingerprints unchanged)

- **T1a:** 2026/101/60001–60022, 22 entries and 127 lines, moved to daily. The later repost was identical.
- **T4a:** a 2025 range, all in the closed period. Refused (-20123) with the per-entry reason.
- **T4b:** the closing entry 2025/101/120084 is never selected.
- **T4c:** type 106 (POST_SYSTEM 31) is never selected.
- **T4d:** the year/type range is required.
- **T4e:** a mixed range 2025/101/120080 to 2026/101/10003. The 3 open-period entries were unposted and the 3 closed ones reported, with the partial-success message.
- **T3:** group 101 without a grant sees nothing; with a temporary grant it can unpost. A NULL group is restricted.
- **T8a:** inside an APEX session, the result message reaches `apex_application.g_print_success_message`.

## What a human must verify

- The VAT-column deviation.
- Whether partial success (committing the good entries) is still wanted. It is the legacy behaviour.


## Wave 3b

Checked, nothing to change: the parameters already have their lists (journal types); the screen writes data, so the run button keeps the insert right; no radio / check box / list item and no button that only opened another form in the legacy screen (EXECUTE / EXIT only). The per-entry cancel posting of ACYRTR now reuses this logic (APP_RULES3_GL.cancel_entry).

## Coverage

Wave 3 review (AR and GL buttons): no legacy rule of this screen is missing. Reproduced: selection (cursor MAS: no closing entries, GL-posted
only), security, cost-centre account parameters (COST_BAL_FLAG_PROC), closed-period skip, move back to the daily tables, removal of the
automatic cost-centre balancing lines when DEL_BAL_SIDES = 1, trigger refusals per entry, partial success and messages. Not reproduced, with
reason: the AC_FLAG = 1 confirmation (never reached because of the POST_SYSTEM = 1 filter), SET_IP, printing. The currency-difference line
999 now written by ACUPDT / ACDLYTR is an ordinary line of the posted entry and moves back with the other lines.
