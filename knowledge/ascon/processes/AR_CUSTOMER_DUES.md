# AR_CUSTOMER_DUES - تسجيل مستحقات العملاء / Customer's Dues (incentives and rents)

- Registry: system 4 serial 39 (no menu). Legacy `ASCON\AR\FMB\AR_CUSTOMER_DUES.fmx` (no .fmb, no labels). Tables empty (unused so far).
- APEX: corrected from a single form on `AR_CUSTOMER_DUES` to `MASTER_DETAIL` with its lines `AR_CUSTOMER_DUES_DET`
  (`MAINAREA_ID, MAST_SERIAL`), as in the form (`DELETE FROM AR_CUSTOMER_DUES_DET WHERE MAINAREA_ID AND MAST_SERIAL`). Rules and buttons in
  `APP_RULES3_AR`. The dues are shown read-only on the CUSTOMER screen and paid with AR_CUSTOMER_DUES_PAY.

## Rules and buttons

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| header serial `NVL(MAX(MAST_SERIAL),0)+1 WHERE MAINAREA_ID`; line `NVL(MAX(DUE_SERIAL),0)+1` | SQL | generated keys | high |
| due type 1 حوافز / 2 ايجار | list texts, CUSTOMER POST-QUERY (`DUE_TYPE = 1` reads the target) | row rule; label lists the values | high |
| area / branch / department / salesman / accounts valid (LOVs) | LOV SQL | row rule `dues_mast_row` | high |
| "تم إقفال هذه الفترة" / "تاريخ الاقفال" (`AC_BASIC.CLOSE_DATE`) | SQL, messages | row rule and the buttons | high |
| "لا يمكن تغيير الرئيسي ويوجد بيانات" | message | row rule (area-independent header fields with lines) | high |
| "الحركة مرحلة للحسابات": a posted document, its lines and its delete are refused | message | row rules and delete triggers `APP_RULES3_AR_DUES_BD / _DUESDET_BD` | high |
| button "تنفيذ": incentives = net sales (issues - returns, `QUANTITY * UNIT_PRICE`) of the department's customers of the area / branch / salesman between the dates, grouped by customer and invoice salesman; rents = customers with a contract (`CUSTOMER_CNTRCT`) covering the due date; customers already in dues of the same month and type skipped; the due amount is entered by the user | the two cursors (verbatim) | action `FILL` -> `dues_fill` | high |
| button "ترحيل": voucher `AC_YEARLY_TRN` (year / type of the document, description " اثبات حوافز وايجارات العملاء لشهر " + month, currency 1) with, per line with a due amount, debit account +amount and credit account -amount, cost centres of the customer (1) and salesman (2) on 4xxx / 5xxx accounts, memo "... عميل رقم" + customer; `POST_FLAG = 1`; "القيد مرحل" when already posted; "تمت عملية الترحيل" | INSERT statements, messages | action `POST` -> `dues_post` | medium (voucher number: see below) |
| button "الغاء ترحيل": deletes the voucher, `POST_FLAG = 0`; "القيد غر مرحل"; "تمت عملية الغاء الترحيل" | DELETE statements, messages | action `UNPOST` -> `dues_unpost` | high |
| totals and voucher shown | - | `info` panel | - |

## Tests (rolled back, 15 checks passed)

Type / closed period; serial; execute loads 44 lines (2025 sales, area 11, department 1) and, run again, only brings back the customer with
two department salesmen (legacy quirk below); header locked with lines; posting creates a balanced 4-line voucher 2026/101/n with the legacy
description; posted document / lines / delete refused; posting twice refused; cancel posting deletes the voucher; cancel of an unposted
document refused.

## Coverage

- Reproduced: the document, its checks and the three buttons. Lists (wave-3b): due type as a radio (حوافز / ايجار), salesmen of the
  group range (SALESMAN_GRP), active accounts on the debit / credit accounts.
- Not reproduced: button "طباعة القيد" (print the voucher: use the GL voucher print / reports); the per-line display of the customer's
  monthly target and 100% / 110% percentages (`AR_ALL_TARGET`, display items; the user enters the due amount as in the legacy).
- Questions / suggestions:
  - voucher number: the compiled form passes a value for `ENTRY_NO` whose source is not visible; the APEX version uses the GL numbering
    rule (`APP_RULES_GL.NEXT_ENTRY_NO`, CALC_SERIAL). Confirm.
  - legacy quirks kept: the sales cursor joins `AR_CUST_SALESMAN`, so a customer with two salesmen in the department gets its sales counted
    twice, and "تنفيذ" run again brings that customer back (the NOT IN compares the department salesman, the line stores the invoice
    salesman). Suggest joining on the invoice salesman.
