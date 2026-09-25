# ACDLYTR - القيود اليومية / Daily Entries (GL daily vouchers)

- Registry: system 1 serial 1 (FILES_MENU.ACDLYTR). APEX list page 10010, document page 10011, print 10012.
- **Deliverable: (a) generated screen kept (`"pattern": "AUTO"`) + business rules** (Stage C waves 2 and 3)
  - Override: `app\legacy\overrides\ACDLYTR.json` (where, key_expr, row_rules, validations, warnings, after_save, info, defaults, readonly,
    actions TAX_IN / TAX_NOTES / POST_VOUCHER).
  - PL/SQL: `APP_RULES_GL` (`app\db\21_rules_gl.sql`), buttons `APP_ACT_AR` (`app\db\23_act_ar.sql`), posting `APP_PROC_GL.post_voucher`
    (`app\db\20_proc_gl.sql`). All VALID.
- **Confidence: high** for numbering, dates/closed period, lines, cost centres, balance; **medium** for the budget check
  (AC_ESTIMATE_* tables are empty, tested with a temporary budget) and the user-rights rule (legacy code has a copy/paste bug, see below).
- Posting of the current entry (POST_VOUCHER / TEST_AND_UPDATE) is the action POST_VOUCHER (wave 3, rule 28).

## Tables

AC_DAILY_TRN (header, PK ENTRY_YEAR, ENTRY_TYPE, ENTRY_NO) and AC_DAILY_TRN_DET (lines, PK + SEQ, signed VALUE shown as debit / credit).
Reads AC_TRN_CODES, AC_BASIC, AC_MASTER, AC_COST_CENTERS(2), AC_PASSWORD_ENTRY / _MASTER / _COST1 / _COST2, AC_YEARLY_TRN(_DET),
AC_ESTIMATE_PERIODS / _MAST / _DET, USERS. Existing DB triggers kept: CLOSE_AC_DAILY_TRN (AC_BASIC MIN/MAX_DATE), TRIG0001 (VALUE <> 0).

## Rules implemented

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | **Entry number** = DB function `CALC_SERIAL(year, type, date)`: max ENTRY_NO of AC_DAILY_TRN and AC_YEARLY_TRN + 1, or month-based `MM`+`nnnn` when AC_TRN_CODES.SERIAL_FLAG = 1 (journal 101 of 2025/2026). The form assigned it in PRE-INSERT (always) and on ENTRY_TYPE / ENTRY_DATE validation. | `AC_DAILY_TRN.PRE-INSERT`, `ENTRY_TYPE`/`ENTRY_DATE` WHEN-VALIDATE-ITEM; user_source CALC_SERIAL | key_expr `AC_DAILY_TRN.ENTRY_NO := app_rules_gl.next_entry_no(...)` (locks the AC_TRN_CODES row `FOR UPDATE` then calls CALC_SERIAL); ENTRY_NO read-only |
| 1b | **AC_TRN_CODES.LAST_SERIAL is not updated**: CALC_SERIAL reads it but never uses it; the only LAST_SERIAL reference in the form is the commented-out KEYCREREC trigger. (LAST_SERIAL 2026/101 = 50066 while the entries reach 60022 - it is stale in production too.) | same | nothing written |
| 2 | **Line SEQ** = max(SEQ)+1 of the entry (NEXT_DET_SEQ / GET_NEXT_SEQUENCE_NUMBER) | `PRE-INSERT` of both blocks, POST-QUERY | key_expr `AC_DAILY_TRN_DET.SEQ := app_rules_gl.next_line_seq(...)` |
| 3 | Journal type: must exist in AC_TRN_CODES for the year (WHEN-VALIDATE-RECORD), be a GL journal `NVL(AC_FLAG,0)=0` and be allowed for the user group (AC_PASSWORD_ENTRY) - ENTRY_TYPE validates from ENTRY_TYPE_RG | record group ENTRY_TYPE_RG (ValidateFromList = true in the .fmb XML) | validation `check_header` (new entries only; a saved entry keeps its journal) |
| 4 | **Entry year = year of the entry date** | ENTRY_YEAR / ENTRY_DATE WHEN-VALIDATE-ITEM | `check_header` |
| 5 | **Closed period**: ENTRY_DATE > AC_BASIC.CLOSE_DATE (CHECK_CLOSE_DATE) and > last closing entry of AC_YEARLY_TRN (MEMO 'قــيــــد الاقـفـــــــال' / 'Closing Entry') | CHECK_CLOSE_DATE, PRE-INSERT, PRE-UPDATE, ENTRY_DATE WVI | `check_header` (CREATE and SAVE) |
| 6 | No future date when AC_BASIC.ALLOW_FUTURE_ENTRY = 0; date inside AC_BASIC MIN_DATE..MAX_DATE (also enforced by trigger CLOSE_AC_DAILY_TRN with an English message) | ENTRY_DATE WVI | `check_header` |
| 7 | Currency: local currency 1 only when AC_BASIC.CURRENCY_STTS = 0 (CONTROL.CURRENCY_CODE); RATE > 0; RATE = 1 for currency 1 | PRE-FORM, CURRENCY_CODE / RATE WVI | `check_header` (legacy silently reset the rate to 1; APEX reports it) |
| 8 | DOC_NO not repeated in AC_DAILY_TRN (same company) / AC_YEARLY_TRN when AC_BASIC.DOC_REPEAT = 2; DOC_REPEAT = 3 only asked (kept as allowed); today DOC_REPEAT = 1 (no check) | PRE-INSERT, DOC_NO WVI | `check_header` |
| 9 | Saved entry: year / type / number cannot change (would break the lines' FK) | improvement | `check_header` |
| 10 | Users with USERS.ALLOW_UPDATE_ENTRIES = 0 cannot change entries created by another user (user 0 always can) | GET_USER_SEC + WHEN-NEW-RECORD-INSTANCE | validation `check_user_rights` (SAVE) |
| 11 | Line account: exists, **ACCOUNT_STATUS = 1** ('خطأ :رقم الحساب ليس حساب فرعى'), NVL(AC_FLAG,0) = 0, currency of the entry (or AC_BASIC.CURRENCY_ACCT), allowed for the group (AC_PASSWORD_MASTER) | ACCOUNT_NUMBER WVI + ACCOUNT_NUMBER_RG (validate from list) | after_save `after_save_entry` |
| 12 | Cost centres: COST_CODE / COST_CODE2 active (COST_STATUS = 1) and allowed for the group (AC_PASSWORD_COST1/2); **mandatory per SET_COST**: income accounts (1st digit of INCOME1_ACCT) need cost centre 1 when ENTER_COST_CENTER1 = 1 (2: ENTER_COST_CENTER2), expense accounts (OUTCOME1_ACCT) when EXPEND_COST1/2 = 1, any account when AC_MASTER.ACC_COST1/2_FLAG = 1 or AC_BASIC.ALL_COST1/2_FLAG = 1 | SET_COST, COST_CODE(2) WVI, COST_CENTERS1/2_RG | `after_save_entry`; function `cost_required` |
| 13 | VAT number (CUST_TAX_NO) of 15 characters | CUST_TAX_NO WVI | `after_save_entry` |
| 14 | An entry must keep at least one line (EMPTY_ALERT) | AC_DAILY_TRN PRE-INSERT, detail POST-DELETE | `after_save_entry` on SAVE (the APEX document is created header-first, so CREATE is allowed without lines) |
| 15 | **Balance**: debit total = credit total. AC_BASIC.BALANCE_ENTRY_FLAG = 1 refuses ('لايمكن حفظ قيد غير متزن'); 0 (today) = legacy BAL_ALERT "Entry Not Balanced !!" with continue/cancel -> saved with a warning | KEY-COMMIT | `after_save_entry` raises, or returns a warning appended to the success message (`apex_application.g_print_success_message`) |
| 16 | **Estimated budget** (AC_BASIC.ESTIMATE_TEST = 1, set today): period balance of account + cost centres (estimate - actual daily + yearly movements) must not go below 0; STOP_ESTIMATE_TEST = 1 (today) refuses, 0 warns | TEST_ESTIMATE_PERIOD(1) from DEBIT/CREDIT/COST WVI | `after_save_entry` + `budget_balance` (inactive in practice: AC_ESTIMATE_PERIODS is empty) |
| 17 | Derived line values: account / cost codes typed short are RPAD-ed to 12 / 9 digits; line description = account name (ENTRY_DESC validated from the account LOV); line memo = header description when empty; CUST_INV_VAL = 0 without VAT customer data | ACCOUNT_NUMBER / COST_CODE WVI, PRE-INSERT / PRE-UPDATE | row rule `line_row` -> `line_defaults` (APEX CREATE/SAVE requests only, so the unpost/copy processes keep their data); ENTRY_DESC / ENTRY_DESC_E read-only in the grid |
| 18 | List filter: `:GLOBAL.PASSWORD_NUMBER = 0 or (ENTRY_YEAR, ENTRY_TYPE) in AC_PASSWORD_ENTRY` | block WHERE | `where` with `:G_PASSWORD_NUMBER` |
| 19 | Defaults: ENTRY_YEAR = AC_BASIC.CURRENT_YEAR, ENTRY_DATE = today, currency 1 / rate 1 (generated); T_TAX_FLAG1 = 0 (required list item) | item initial values | generated + `defaults` |

## Wave 3 additions (evidence `AC\FMB\Acdlytr_fmb.xml`, compiled texts `_ARCHIVE\ASCON\AC\FMB\Acdlytr.fmx`)

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 20 | **VAT customer**: CUST_CODE LOV on AC_BENF_TAX returns BENF_NAME -> CUST_NAME and TAX_NO -> CUST_TAX_NO (the 7 posted VAT lines use AC_BENF_TAX codes and names) | LOV of CUST_CODE | row rule `line_row` (code entered / changed) |
| 21 | **VAT memo**: when CUST_CODE, CUST_NAME and CUST_INV_NO are filled and one of CUST_CODE / CUST_NAME / CUST_INV_NO / CUST_INV_VAL is entered or changed: MEMO = 'ضريبة 5% على الفاتورة رقم : ' + invoice + ' للعميل : ' + name + ' - ' + notes, MEMO_E = 'VAT 5% on Invoice No : ...' (legacy texts, used by the posted lines) | WHEN-VALIDATE-ITEM of the four items | row rule `line_row` |
| 22 | CUST_INV_DATE initial value today ($$DBDATE$$; 3 730 of 3 843 posted lines have the creation date) | item InitializeValue | row rule (new lines without a date) |
| 23 | TAX_FLAG not enterable (Enabled = false; set by TAX_IN) | item property | `readonly` |
| 24 | **DOC_REPEAT = 3**: repeated document number in AC_DAILY_TRN (company) or AC_YEARLY_TRN -> DOC_NO_ASK "continue?" | DOC_NO WHEN-VALIDATE-ITEM | warning `warn_doc_repeat` |
| 25 | **Running totals / balances**: DEBIT_TOTAL 'القيمة المدينة', CREDIT_TOTAL 'القيمة الدائنة', DIFF 'الفرق بين المدين والدائن'; CURRENT_LOC_F = GET_ACCOUNT_BAL_LEVEL(company, account) with 'مـديـن' / 'دائــن' for each line | summary items, POST-QUERY | `info` (`entry_totals`, `account_balances`: one line per account of the entry) |
| 26 | **TAX_IN** ('انزال الضريبة'): for the TX_TAXES_ACCOUNTS rows of the line's account (cost centres equal or 0) a new line on TX_TAXES_TYPES.DB_ACCOUNT_NO (debit line, + value * TAX_PER / 100) or CR_ACCOUNT_NO (credit line, - value * TAX_PER / 100), rounded to 2, cost centres of the tax row, TAX_ACCOUNT = taxed account, TAX_FLAG 1, T_TAX_FLAG1 0, CUST_INV_VAL = taxed value (0 after PRE-INSERT without VAT customer - 556 of the 699 posted tax lines), line name / memo derived; none: 'لا يوجد ضريبة مدرجة على هذا الحساب بمركز تكلفة 1 و مركز تكلفة 2 ان وجد' | TAX_IN WHEN-BUTTON-PRESSED | action **TAX_IN** (parameter: the line) -> `app_act_ar.tax_in` |
| 27 | **TAX_NOTES**: without TAX_FLAG, CUST_INV_VAL := ABS(value) / 1.05 (legacy constant) and CUST_TAX_VAL = value - CUST_INV_VAL (e.g. 228.1 -> 217.2381 on the posted data); tax lines only display the value; no account: 'لابد من ادخال حساب اولا' | TAX_NOTES WHEN-BUTTON-PRESSED, POST-QUERY | action **TAX_NOTES** -> `app_act_ar.tax_notes` |
| 28 | **POST_VOUCHER** ('ترحيل القيد', 'هل تريد ترحيل القيد الحالي ؟'): enabled for group 0 or GROUP_COMPANY.POST_FLAG = 1 with the user's FILE_PASSWORD row of ACUPDT (1/71, all flags); CLOSE_DATE >= entry date -> DEL_ERROR; unbalanced: BALANCE_ENTRY_FLAG 1 'لايمكن حفظ قيد غير متزن' (0: asked, then TEST_PROC refuses); after the last closing entry; TEST_PROC ('الحساب غير موجود', 'الحساب ليس على المستوى الأدنى', currency rule `acm <> entry and acm <> 1 and entry <> 1` 'عملة الحساب ليست مماثلة لعملة القيد', 'الجانب المدين لا يساوى الجانب الدائن' -> AC_UPDT_TBL, 'يوجد خطأ بالقيد، قد يكون غير متوازن !!'); UPDATE_PROC: AC_YEARLY_TRN (CLOSE_FLAG 0, POST_SYSTEM 1, POST_USER), lines with the header audit and the VAT columns, currency-difference line 999, delete the daily entry ('القيد مكرر فى ملف القيود اليومية و الفورية' on a duplicate); DONE 'لقد تم ترحيل القيد بنجـــاح'; CLEAR_RECORD | POST_VOUCHER WHEN-BUTTON-PRESSED, TEST_AND_UPDATE, WHEN-NEW-FORM-INSTANCE | action **POST_VOUCHER** -> `app_proc_gl.post_voucher`; the page then opens an empty entry |
| 29 | **Currency-difference line** (UPDATE_PROC): NUMBER(14,2) running totals of ROUND(VALUE,2) * RATE; when CURRENCY_CODE <> 1 and they differ, line SEQ 999 on AC_BASIC.CURRENCY_ACCT (names of the account), VALUE = -debit + credit, BALANCE_FLAG 1, header audit; no account: 'لابد من تعريف حساب فروق العملة بمؤشرات النظام' | UPDATE_PROC | `app_proc_gl.currency_diff_line` (also in ACUPDT) |
| 30 | **Delete** (PRE-DELETE): only when AC_BASIC.CLOSE_DATE < ENTRY_DATE (an empty CLOSE_DATE refuses too), else DEL_ERROR 'تاريخ القيد أقل من تاريخ قيد الإقفال لا يمكن إلغاء القيد'; a user with ALLOW_UPDATE_ENTRIES = 0 and ALLOW_DELETE_ENTRIES = 0 cannot delete an entry of another user (WHEN-NEW-RECORD-INSTANCE branch 4; the "update 1 / delete 0" combination has no branch and allows) | PRE-DELETE, WHEN-NEW-RECORD-INSTANCE, GET_USER_SEC | trigger `APP_RULES_GL_DAILY_BD` (request DELETE of page 10011) |

## Deviations / limits

- Checks 11-16 run after the save of header + lines (same transaction, rolled back on error) instead of field by field; they check all
  lines of the entry, not only the changed ones (an old line on a since-deactivated account blocks saving until corrected).
- Closed-period checks apply on every SAVE (legacy: when the date / header changed) - an entry dated in a closed period is frozen.
- Both debit and credit typed on one line: the grid stores VALUE = debit - credit (legacy cleared the other column).
- TAX_IN / TAX_NOTES work on saved lines (an action button per document with the line as parameter, legacy: button on the current line).
  TAX_NOTES stores CUST_INV_VAL at once; the legacy PRE-UPDATE would have reset it to 0 when no VAT customer was entered afterwards.
- POST_VOUCHER posts the saved entry: unsaved changes of the page are not part of it (legacy committed the form first).
- POST_VOUCHER copies AUTO_TRNS_FLAG / TAX_TRNS_DATE / TAX_INVOICE_NO as ACUPDT does (legacy list omitted them); line audit columns are those
  of the header, as in the legacy.

## Tests (wave 3, `tmp\w3_argl\t_gl.py`, simulated APEX session on page 10011, all rolled back) - 44/44

ACUPDT regression T1 (unpost / repost 2026/101/60001-60022, 22 entries / 127 lines identical, no 999 line); `line_row`: AC_BENF_TAX name /
tax number, VAT memo Arabic / English, unchanged VAT data keeps the user's memo, changed invoice number rewrites it, no VAT customer -> 0;
DOC_REPEAT 3 warning / new number / DOC_REPEAT 1; info totals and balances; TAX_IN on a debit line (110601002001, 150, TAX_ACCOUNT, flags,
CUST_INV_VAL 0), on a credit line (210103004001, -75), on an account without tax (message); TAX_NOTES (952.38095) and on a tax line (display);
POST_VOUCHER (group 0): posted with POST_SYSTEM 1, header audit, VAT columns, daily entry deleted, DONE message, page ROWID emptied;
unbalanced flag 0 (TEST_PROC error + AC_UPDT_TBL row) / flag 1; closed period; group 101 without GROUP_COMPANY.POST_FLAG refused;
foreign entry (currency 2, rate 3.75, 3 x 0.01 against 0.03): no CURRENCY_ACCT refused, with it line 999 = -0.01; same through ACUPDT;
delete hook: closed period, empty CLOSE_DATE, user 105 on another user's entry refused, own entry in the open period deleted.

## Wave 3b (new generator keys; evidence `AC\FMB\Acdlytr_fmb.xml` item properties, LOVs and POST-QUERY)

| # | Legacy | Evidence | APEX (`rules.columns` / `rules.computed`) |
|---|--------|----------|-------------------------------------------|
| 31 | CUST_CODE list = AC_BENF_TAX_LOV (`select BENF_CODE, BENF_NAME, TAX_NO from AC_BENF_TAX`), not the customer list | item LovName, LOV record group | `lov` on AC_BENF_TAX (code - name (VAT number)) |
| 32 | CUST_NAME, CUST_TAX_NO, CUST_INV_VAL not enterable (filled by the LOV / TAX_NOTES / TAX_IN) | Enabled = false | `readonly` |
| 33 | ENTRY_YEAR, ENTRY_TYPE cannot change after insert | UpdateAllowed = false | `readonly_after_insert` (rule 9 still checks) |
| 34 | ENTRY_YEAR list (distinct AC_TRN_CODES years), ENTRY_TYPE list ENTRY_TYPE_LOV (GL journals `NVL(AC_FLAG,0)=0` granted to the group); the name was shown next to the code (ENTRY_TYPE_NAME) | ENTRY_YEAR_LOV / ENTRY_TYPE_LOV, POST-QUERY | `lov` (select list of years; pop-up "type - name" of the entry's year: `:PAGE_ENTRY_YEAR` with `cascade: ENTRY_YEAR`) |
| 35 | T_TAX_FLAG1 is a required list item (values 0-11) | Required = true, ListItemElement | `required` (default 0 kept). The list elements have no labels in the source, so it stays a number field (question 4) |
| 36 | Created by / modified by (CREATE_USER_NAME / UPDATE_USER_NAME, CREATE_DATE / UPDATE_DATE display items) | POST-QUERY of AC_DAILY_TRN | computed master columns "مدخل السجل" / "معدل السجل" (name + date) |
| 37 | Per line: CUST_TAX_VAL (tax line: ABS(value), else ABS(value) - CUST_INV_VAL), CUST_TOT_VAL = CUST_INV_VAL + CUST_TAX_VAL, CURRENT_LOC_F = GET_ACCOUNT_BAL_LEVEL(company, account) with 'مـديـن' / 'دائــن' | POST-QUERY of AC_DAILY_TRN_DET, item Formula | computed grid columns CUST_TAX_VAL, CUST_TOT_VAL, CURRENT_LOC_F |
| 38 | Labels of the VAT fields (the DET_CANVAS items have no prompts in the source or GN_FORM_ITEM): رقم العميل (ضريبة), الرقم الضريبي, رقم الفاتورة, تاريخ الفاتورة, قيمة الفاتورة, ملاحظات, نوع الضريبة, سطر ضريبة; header MEMO_E label corrected (was "مذكرة الجرد") | new texts (from the legacy memo text "الفاتورة رقم") | `label_a` / `label_e` |

Tests (build copy, read-only): every list / computed SQL run by `tmp\w3b_gl\check.py`; computed values checked on posted lines
(`tmp\w3b_gl\A\t_acdlytr.sql`): 228.1 with CUST_INV_VAL 217.2381 -> tax 10.8619, total 228.1; account 110601002001 balance
"72,093.64 مـديـن"; users "عمار الشحات 14/02/2026". Page generation in memory: OK.

## Coverage

Reproduced: rules 1-38. Not reproduced, with reason:

- **:GLOBAL.USR_COST_CODE1/2, USR_ENTRY_YEAR/TYPE** (fixed cost centre / journal per session): set in `Sysmenu2` at login from the user's
  choice (AC_BASIC.FX_USR_* switches, all 1) and not stored in any table; the form only disables COST_CODE / COST_CODE2 when they are set and
  the KEYCREREC that used the journal is commented out. APEX has no such login choice.
- CUSTOMER_ACCOUNT_BALANCE protection, SET_IP / WEBUTIL, printing (DO_PRINT_REP, "نعم مع الطباعة"), prompts / navigation / currency item
  enabling, ERROR report ACPSTERR (the errors are listed in the message and in AC_UPDT_TBL).
- Cost-centre balancing lines of TEST_AND_UPDATE (commented out in the legacy).
- Cost-centre names (COST_NAME / COST_NAME2): the cost-centre columns are select lists that already show the names.
- Estimate displays EST_PERIOD_BAL / EST_BAL / EST_YEAR_BAL: the budget tables are empty.
- **Generator limits**: warnings cannot confirm a grid change. (CUST_INV_DATE keeps its row-rule default; resolved in wave 3b: the
  CUST_CODE list and the per-line displays.)

## Open questions

1. BALANCE_ENTRY_FLAG = 0 today, so unbalanced entries are saved with a warning (legacy asked). Should APEX refuse them (set the flag to 1)?
2. TAX_NOTES divides by 1.05 (5 % VAT) while TX_TAXES_TYPES has 15 %: keep the legacy constant?
3. POST_VOUCHER is refused for groups whose GROUP_COMPANY.POST_FLAG is empty (groups 101 / 102 today): confirm.
4. T_TAX_FLAG1 (values 0-11; TAX_IN uses 1-5 = credit tax account, 6-10 = debit tax account; posted data: 0, 6, 8) had no labels in the
   source: what are the names of the values? Then it can become a select list.

## Tests (build copy, all rolled back) - 47 checks passed

Numbering 2026/101 June -> 60023 (max 60022), July -> 70001, 2024/100 -> 2, LAST_SERIAL untouched, next number sees the daily entry (60024);
year/date mismatch, closed period (CLOSE_DATE 31/12/2025), unknown journal, AC_FLAG journal 102, future date, rate rules, foreign currency,
group without AC_PASSWORD_ENTRY, DOC_REPEAT = 2 duplicate; SET_COST (income 4xxx needs cost 1, expense 3xxx needs cost 1, ACC_COST2_FLAG);
padding 4101010 -> 410101000000 and 102001 -> 102001000, memo and names derived; empty entry on SAVE, missing / inactive cost centre,
non-postable account, 15-digit VAT number, unbalanced entry warning (flag 0) / refusal (flag 1), budget exceeded refusal / warning with a
temporary budget, ALLOW_UPDATE_ENTRIES (user 3 vs 101), saved-entry key change. Generated APPX triggers compiled on scratch copies (OK).

