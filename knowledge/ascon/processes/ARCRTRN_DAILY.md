# ARCRTRN_DAILY - متابعة شيكات وحوالات العملاء الخارجية / External customers' cheques and transfers

- Registry: system 4. Legacy `ASCON\AR\FMB\ARCRTRN_DAILY.fmx` (2019 version, no .fmb, no labels; evidence from the compiled strings).
  Table `AR_MAINTRNS_DAILY` (cheques / transfers collected by the salesmen, mobile application) is empty on the build copy. The DB
  trigger `AR_DAILY_TRNS_IN` (kept) creates the customer's `AR_MAINTRNS` credit transaction when a record is approved (TRNS_STATUS 1).
- APEX: the generated report + form on `AC_DAILY_TRN` (name match) was corrected to `AR_MAINTRNS_DAILY` with the legacy block WHERE;
  field rules in `APP_RULES3_AR`. The four buttons are NOT reproduced (see Coverage).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| block WHERE: credit types except opening balances (`EFFECT = 1 AND TRNS_TYPE <> 6`), for groups other than 0 the group's types (`AR_TRNSTYPE_PASSWORD FLAG 1`), customers (`AR_CUST_PASSWORD`) and salesmen (`AR_SALESMAN_PASSWORD`) | DEFAULT_WHERE text | list `where`; row rule `daily_row` for new rows | high |
| serial `NVL(MAX(TRNS_SERIAL),0)+1` per type / area / branch | as the DB trigger and the AR screens | generated key | high |
| "يجب إدخال نوع الحركة" (CASH_FLAG: شيكات / تحويل) | CASH_FLAG_LIST trigger | row rule | high |
| approval date: "يجب ان يكون تاريخ الاعتماد اكبر من او يساوى تاريخ الحركة" / "... اصغر من او يساوى تاريخ اليوم" | AUTH_TRNS_DATE trigger | row rule | high |
| REF_DOC: "هذا الايداع مكرر لنفس المندوب بنفس البنك" (same salesman / bank / value / reference approved) | WHEN-VALIDATE-ITEM SQL | compound trigger `APP_RULES3_AR_DAILY_AIU` -> `daily_ref_check` | high |
| CLOSE_MAIN_POSTED: approved / refused records closed ("تم عمل اجراء على هذه الحركة من قبل"), not deletable | program unit on TRNS_STATUS | row rule, delete trigger `APP_RULES3_AR_DAILY_BD` | medium |
| a posted record (POST_FLAG 1) cannot be deleted: "يجب الغاء الترحيل اولا" | legacy message of the deposit screens; the voucher would be orphaned | delete trigger | low (safety addition, documented) |

## Tests (rolled back, 10 checks in batch 9 passed)

Opening-balance type refused; payment type required; serial per type / area / branch; approval date before the transaction / after
today refused; bank reference of an approved deposit refused, another accepted; approved record locked and not deletable; posted
record not deletable.

## Coverage

- Reproduced: the screen, its WHERE and the field checks. Lists (wave-3b): transaction types and salesmen of the group, active accounts
  on the deposit / credit accounts, status list (تحت الاجراء / معتمدة / مرفوضة). CASH_FLAG stays a number: the values behind the
  legacy list (شيكات / تحويل) are not visible.
- Cannot reconstruct (buttons "الترحيل", "الغاء الترحيل", "اعتماد", "رفض"): the posting voucher uses the type account
  (`AR_TRNSTYPE.ACCOUNT_NO`, "خطا بحساب رقم الحركة") and the salesman's custody account (`AR_SALESMAN_ACCOUNT` type 2 or 3,
  "خطا بحساب عهدة المندوب"), the approval voucher (DO_ENTRY, AUTH_ENTRY_*) the deposit bank account (`BANK_ACCOUNT_NUMBER`), the
  cheques credit account (`CR_ACCOUNT_NUMBER`) and the custody account; the compiled form does not show which account is debited and
  which credited, nor which of types 2 / 3 goes with cheques or transfers, nor what the refusal (which also references DO_ENTRY)
  writes. Approval requires the posting first ("يجب ترحيل الحركة اولا"), so it cannot be offered without the posting.
  Known messages for when they are built: "القيد مرحل", "يجب الحفظ أولا", "لا يمكن ترحيل حركة بقيمة صفر", "يجب إدخال رقم نوع قيد
  الترحيل في ملف ارقام الحركات", "تمت عملية الترحيل", "تم عمل اجراء على الحركة لايمكن الغاء الترحيل", "القيد غر مرحل",
  "تم إقفال هذه الفترة", "يجب ادخال تاريخ اعتماد الحركة", "يجب ادخال حساب بنك الايداع", "يجب ادخال حساب الدائن",
  "يجب ادخال مرجع البنك", "يجب استكمال البيانات الاساسية", "تم التنفيذ".
- Not reproduced: "طباعة القيد" (two voucher prints), "مستندات" (attachments), the display names.
- Questions (to build the buttons): for the posting voucher, is the debit the salesman's custody account (type 2 = cheques,
  type 3 = transfers?) and the credit the transaction type's account? For the approval voucher, debit the deposit bank account and
  credit the custody account (or `CR_ACCOUNT_NUMBER` for cheques)? What does the refusal write (reverse of the posting)?
  The description words are "اشعار سداد رقم / حوالة ... من عميل ... كود ... بتاريخ ... برقم ... من المندوب".
