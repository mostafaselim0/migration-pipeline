# AR_CUSTOMER_DUES_PAY - صرف مستحقات العملاء / Payment of the customers' dues

- Registry: system 4 (no menu entry found). Legacy `ASCON\AR\FMB\AR_CUSTOMER_DUES_PAY.fmx` (no .fmb, no labels; evidence from the
  compiled strings). Tables empty (unused so far).
- APEX: corrected from a single form on `AR_CUSTOMER_DUES_PAY` to `MASTER_DETAIL` with its lines `AR_CUSTOMER_DUES_PAY_DET`
  (`MAST_ID, MAST_SERIAL`, as the form's `DELETE FROM AR_CUSTOMER_DUES_PAY_DET WHERE MAST_ID AND MAST_SERIAL`). Rules and buttons in
  `APP_RULES3_AR`. It pays the dues registered with AR_CUSTOMER_DUES.

## Rules and buttons

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| header serial `NVL(MAX(MAST_SERIAL),0)+1 WHERE MAST_ID`; line `NVL(MAX(DUE_SERIAL),0)+1` per document | SQL (twice) | generated keys | high |
| transaction type = credit opening-balance types (`EFFECT = 1 AND TRNS_TYPE = 6`) of the user's group (`AR_TRNSTYPE_PASSWORD`) | LOV TRNSTYPE | list `where`, row rule "رقم الحركة غير صحيح", default the first type | high |
| payment type 1 حوافز / 2 ايجار; area, branch of the area, department, salesman valid | radio texts, LOV SQL | row rule `pay_mast_row` | high |
| "لا يمكن تغيير الرئيسي ويوجد بيانات" (header item changed while lines with a customer exist) | two item triggers reading `:CUSTOMER_CODE` | row rule (area, branch, salesman, department, payment type) | medium (the two items are not named in the binary) |
| "الحركة مرحلة للحسابات": a posted document, its lines and its delete are refused; "تنفيذ" refused | message in the execute button, POST_FLAG block property trigger | row rules, delete triggers `APP_RULES3_AR_PAY_BD / _PAYDET_BD` | high |
| PAY_AMOUNT "قيمة غير صالحة" using `:PAY_AMOUNT, :TOT_DUE, :TOT_PAY` (TOT_DUE = all dues of the customer / salesman / type, TOT_PAY = what the other documents paid, POST-QUERY SQL) | item trigger, POST-QUERY SQL | compound trigger `APP_RULES3_AR_PAYDET_AIU` -> `pay_det_amount`: amount > TOT_DUE - TOT_PAY refused | medium (condition reconstructed from the three items) |
| button "تنفيذ": dues (`AR_CUSTOMER_DUES / _DET`) of the type, department and area (branch / salesman when given) due up to the payment date, grouped by customer and salesman, less what was paid up to that date | the two cursors (verbatim) | action `FILL` -> `pay_fill`: one line per customer / salesman with a remaining amount, PAY_AMOUNT = remaining | medium (see below) |
| button "ترحيل": voucher `AC_YEARLY_TRN` (voucher type and debit account of the transaction type `AR_TRNSTYPE.ENTRY_TYPE / ACCOUNT_NO`, year of the payment date, CALC_SERIAL number, description " صرف حوافز وايجارات العملاء يوم " + month); per paid line debit type account + amount and credit customer account - amount, cost centres of the customer (1) and salesman (2) on 4xxx / 5xxx accounts, legacy memos; "حساب العميل غير موجود"; then INSERT_CUSTOMER_TRNS: customer credit transaction `AR_MAINTRNS` (type = document type, serial per type / area / branch, LINK_FLAG 1, POST_FLAG 1, residual = amount, voucher fields, POST_SYSTEM 4) + `AR_SUBTRNS` line, linked back on the line (`AR_TRNS_*`); POST_FLAG 1; "القيد مرحل" | INSERT / UPDATE statements, messages | action `POST` -> `pay_post` | high (voucher number: GL numbering `APP_RULES_GL.NEXT_ENTRY_NO` = CALC_SERIAL) |
| button "الغاء ترحيل": "القيد غر مرحل"; closed period "تم إقفال هذه الفترة" + "تاريخ الاقفال" (`AC_BASIC.CLOSE_DATE`); deletes the voucher and the customers' transactions; POST_FLAG 0 | DELETE statements, messages | action `UNPOST` -> `pay_unpost` | high |
| due / paid / paid now totals and the voucher | TOT_DUE / TOT_PAY display items | `info` panel (document totals) | - |

## Tests (rolled back, 28 checks passed)

Type / payment type / branch refused; serial; execute brings the 3 customers with dues (100 each) and, run again, nothing; more than
the due refused, partial 60 accepted; header locked with lines; a second document gets only the remaining 40 of the partly paid
customer and refuses 50; posting without the type account / with a customer without account refused; posting creates a balanced
6-line voucher 2026/103/n with the legacy description and 3 linked credit transactions of type 902 (AR_MAINTRNS + AR_SUBTRNS);
posted document / lines / new line / delete / execute / second posting refused; cancel posting deletes the voucher and the
transactions and clears the links; cancel of an unposted document refused; unposted document deletable.

## Coverage

- Reproduced: the document, its checks and the three buttons. Lists (wave-3b): transaction types of the group (fixed after insert),
  payment type as a radio (حوافز / ايجار), salesmen of the group range (`AR_CUSTOMER_PASSWORD` FROM / TO_SALESMAN, MIN / MAX used so
  that several ranges do not fail).
- Not reproduced: button "طباعة القيد" (report ACJRNL2: use the GL voucher print); the per-line TOT_DUE / TOT_PAY display columns
  (shown as document totals in the info panel; per-line computed columns are not a generator feature); the names of the customer /
  salesman (LOV display).
- Differences (documented): the legacy "الغاء ترحيل" deletes `AR_MAINTRNS` only; `AR_SUBTRNS_FK` would refuse it, so the lines
  `AR_SUBTRNS` are deleted first and the line links are cleared. "تنفيذ" skips customers already in the document (the legacy form
  appends records in the block; a second run in APEX would otherwise duplicate lines). A posting without paid lines is refused
  ("لا توجد مبالغ منصرفة للترحيل"; the legacy deletes the empty voucher header).
- Questions:
  - "تنفيذ": the legacy sets PAY_AMOUNT from TOT_DUE / TOT_PAY (display items); APEX proposes the remaining amount (due - paid) and
    loads only customers with a remaining amount. Confirm.
  - PAY_AMOUNT check: reconstructed as "amount > TOT_DUE - TOT_PAY". Confirm (a negative amount is not refused).
  - INSERT_CUSTOMER_TRNS: the salesman of the customer transaction is read from `AR_CUST_SALESMAN` by customer only in the legacy;
    APEX takes the customer's salesman in the type's department, else the line salesman; DOC_NO = document serial; BILL_ID1 / 2 empty
    (their legacy values are not visible). Confirm.
  - The legacy "ترحيل" has no closed-period check (only "الغاء ترحيل" has). Kept.
