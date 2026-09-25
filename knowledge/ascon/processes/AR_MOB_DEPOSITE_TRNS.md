# AR_MOB_DEPOSITE_TRNS - صرف من صناديق المناديب / Salesmen bank deposits

- Registry: system 4. Legacy `ASCON\AR\FMB\AR_MOB_DEPOSITE_TRNS.fmx` (2019 version, no .fmb, no labels; evidence from the compiled
  strings). Table `MOB_DEPOSITE_TRNS` (written by the salesmen's mobile application) is empty on the build copy.
- APEX: the generated report + form on `MOB_DEPOSITE_TRNS` is kept (right table); rules, delete hook and the four buttons in
  `APP_RULES3_AR` (actions on the form page).

## Rules and buttons

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| list: salesmen of the user's group (`AR_SALESMAN_PASSWORD`); bank LOV of the group (`BANK_PASSWORD`), branch LOV of the bank | block WHERE, LOV SQL | list `where`, row rule `mob_row` | high |
| "يجب إدخال نوع الحركة" (pay type) | PAY_TYPE_LIST trigger | row rule | high |
| posting date: "يجب ان يكون تاريخ الترحيل اكبر من او يساوى تاريخ الحركة" / "... اصغر من او يساوى تاريخ اليوم" | POSTED_TRNS_DATE triggers | row rule | high |
| CLOSE_MAIN_POSTED: an approved / refused deposit is closed ("تم عمل اجراء على هذه الحركة من قبل"); only the posting date stays editable; a posted deposit keeps its posting date ("القيد مرحل") | program unit on TRNS_STATUS, messages | row rule, delete trigger `APP_RULES3_AR_MOB_BD` | medium (the legacy disables the block; APEX refuses the change) |
| button "اعتماد": "تم عمل اجراء على هذه الحركة من قبل" (not pending), "يجب ادخال مرجع البنك", "هذا الايداع مكرر لنفس المندوب بنفس البنك" (same salesman / bank / value / reference already approved); status 1 | SQL, messages | action `AUTH` -> `mob_auth` | high |
| button "رفض": "تم عمل اجراء على هذه الحركة من قبل" (already refused), "يجب الغاء الترحيل اولا" (posted); status 2 | messages | action `REFUSE` -> `mob_refuse` | medium (see questions) |
| button "الترحيل": "الحركة غير معتمدة", "القيد مرحل", "يجب ادخال تاريخ الترحيل", "خطا بحساب الفرع" (`BANK_BRANCHS.BRNCH_ACC_CHRT_NO`), account type `DECODE(PAY_TYPE,0,1,1,2,2,3)` and "خطا بحساب المندوب" (`AR_SALESMAN_ACCOUNT`), cost centres of the salesman, voucher type of the salesman's area (`AR_MAINAREA.ENTRY_TYPE`, "يجب إدخال رقم نوع قيد الترحيل في ملف المناطق"), "لا يمكن ترحيل حركة بقيمة صفر"; voucher `AC_YEARLY_TRN` on the posting date (CALC_SERIAL number, DOC_NO = deposit serial, total), debit bank branch account, credit salesman account, description "صرف من صندوق نقدى/حوالات للمندوب ... بإيداع بنكى بحساب ... بتاريخ ... مسلسل # ..."; POST_FLAG 1 | SQL (verbatim), messages, description words | action `POST` -> `mob_post` | medium (direction from the description "paid out of the salesman's box by bank deposit"; word order of the description reconstructed) |
| button "الغاء الترحيل": "القيد غر مرحل", "يجب إدخال رقم نوع قيد الترحيل في مؤشرات النظام", closed period "تم إقفال هذه الفترة" (`AC_BASIC.CLOSE_DATE` against the transaction date); deletes the voucher | SQL, messages | action `UNPOST` -> `mob_unpost` | high |

## Tests (rolled back, 27 checks in batch 9 passed)

Test bank / branch / salesman account inside the transaction. Salesman / pay type / branch refused; serial; posting date before the
transaction and after today refused; post before approval refused; approval without reference refused, approval, approved deposit
locked and not deletable, second approval refused, duplicate deposit refused; post without posting date / branch account / salesman
account / area voucher type refused; posting creates voucher 2026/103 debit branch account 5000, credit salesman account, legacy
description; posted: date locked, refuse needs cancel posting, second post refused; cancel posting deletes the voucher; refuse.

## Coverage

- Reproduced: the checks and the four buttons.
- Not reproduced: "طباعة القيد" (report, "لابد من الترحيل اولا": use the GL voucher print); "مستندات" (attachments `SYS_DOCS`);
  RUN_ERR_REPORT; the display names (salesman, area, branch, bank).
- Lists (wave-3b `rules.columns`): the wrong automatic list of `BRANCH_CODE` (`BRANCH`, company branches) is replaced by the bank
  branches (`BANK_BRANCHS`, shown as bank/branch; not filtered by the chosen bank, the row rule checks the pair); banks of the group;
  salesmen of the group; status as a list (تحت الاجراء / معتمدة / مرفوضة).
- Questions:
  - "رفض": may an approved (not posted) deposit be refused? APEX allows it (the legacy message "يجب الغاء الترحيل اولا" implies it).
    "اعتماد" of a refused deposit is refused.
  - The cost centres of the salesman are written on both voucher lines (the legacy INSERTs bind the same variables); confirm.
  - The closed-period check of "الغاء الترحيل" uses the transaction date as in the legacy (not the posting date).
