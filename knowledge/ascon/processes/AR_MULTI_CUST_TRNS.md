# AR_MULTI_CUST_TRNS - حركات مدفوعات العملاء مجمعه / Grouped customers' payments

- Registry: system 4. Legacy `ASCON\AR\FMB\AR_MULTI_CUST_TRNS.fmx` (2012 with 2016-2021 changes, no .fmb, no labels; evidence from
  the compiled strings). Blocks: AR_TRNS (header: one collection, cash box / bank / accounts), AR_MAINTRNS (one payment line per
  customer, `SERIAL` = header), AR_SUBTRNS (invoice allocation of each customer line), AR_TRNS_ACCOUNT (debit accounts), AR_SUBACC
  (credit accounts). Data: AR_TRNS / AR_TRNS_ACCOUNT / AR_SUBACC empty and no transaction type has `TOT_TRNS_FLAG = 1` ("تحصيلات
  خارجية" on ARTRNSTYPE), so the screen is not in use.
- APEX: corrected from a grid on `AR_CUST_PASSWORD` (name match) to `MASTER_DETAIL`: AR_TRNS with AR_MAINTRNS, AR_TRNS_ACCOUNT and
  AR_SUBACC (joined on `SERIAL`, as the form's delete `WHERE SERIAL = :AR_TRNS.SERIAL`). Rules in `APP_RULES3_AR`; wave-3b keys used:
  type list, payment-type radio (شيكات 0 / نقدية 1 / حسابات 2 / تحويل 3, the ARACUPDT codes), cash box / bank / branch / account
  lists, customer name column.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| list and type: `EFFECT = 1 AND TRNS_TYPE <> 6 AND TOT_TRNS_FLAG = 1` of the group | block WHERE, LOV | `where`, type list, row rule "رقم الحركة غير صحيح" | high |
| header `SERIAL = NVL(MAX(SERIAL),0)+1` (whole table) | SQL | generated key | high |
| category from the type; description from the type (`INITIAL_DESC`, `PLUS_DOC_NO_FLAG` adds the document number); `ACC_POST_DATE` = `TRNS_DATE` | type SQL, TRNS_DATE trigger | row rule `multi_mast_row` | medium (DESC_FLAG use not visible) |
| payment type required "يجب إدخال نوع الحركة"; cheques / transfers need the cheques system 13 ("نوع الحركة خطا") | CASH_FLAG triggers (`SYS_SYSTEMS 13`) | row rule | high |
| cash: "يجب ادخال رقم الصندوق"; the box gives the transaction account and cost centre ("الصندوق لايحتوى على رقم حساب"); bank branch the same ("فرع البنك لايحتوى على رقم حساب"); account must exist | BOX_CODE / BRANCH triggers, SQL | row rule | high |
| customer line: type, date, deposit date, post flag, cash flag of the header; area / branch / currency of the customer and its rate; category = `NVL(MIN(CTGRY_CODE), header category)` of the customer, salesman = `MIN(SALESMAN_CODE)` of that category; `TRNS_SERIAL = MAX+1` per type, `TRNS_SERIAL_TOTAL = MAX+1` | CUSTOMER_ID / PRE-INSERT SQL | row rule `multi_line_row` (this screen only) | high |
| "تاريخ الحركة لا يمكن ان يقل عن تاريخ فتح العميل", "تاريخ الحركة لا يمكن ان يقل عن تاريخ الرصيد الافتتاحي العميل" | messages, SQL | row rule | high |
| "قيمة الخصم لابد أن تكون أقل من القيمة المدخلة للفاتورة" | DISC_VAL trigger | row rule | high |
| "لا يمكن تكرار رقم المستند" (DOC_NO in AR_MAINTRNS) | SQL | compound trigger `APP_RULES3_AR_MULTI_AIU` | high |
| account lines: `ACC_SERIAL = MAX+1` per document; active accounts and cost centres | SQL, LOVs | generated key, row rule `multi_acc_row` | high |
| "القيمة المدفوعة من العملاء لا تساوي إجمالي الحركة" (total = customers + credit accounts: `TOTAL_VALUE`, `TOT_AMOUNT`, `AR_SUBACC.ACC_TOT`); per customer "اجمالى حركة العميل يجب ان تكون مساوية لتفاصيل الفواتير" | commit triggers | `after_save` `multi_after_save` | medium (sum formula from the three items) |
| posted document closed (SET_CLOSE), "لابد من إلغاء الترحيل اولا" for changes and deletes | SET_CLOSE, message | row rules, delete triggers `APP_RULES3_AR_MULTI_BD / _TRNS_BD / _TRNSACC_BD / _SUBACC_BD` | high |
| totals (customers, credit, debit, difference) | summary items | `info` panel | - |

## Tests (rolled back, 24 checks passed)

Type 203 marked as grouped type and a test cash box inside the transaction. Wrong type, missing payment type, cheques without the
cheques system, cash without box refused; box account copied; unknown account refused; serial, category, deposit date; customer
line derivations (type, date, area / branch, serials, category / salesman); discount, repeated document number and open date
refused; total check and missing invoice details refused, balanced document with an allocation line accepted; posted document:
header, new line, account lines and deletes refused.

## Coverage

- Reproduced: the document, its accounts, the checks above.
- Cannot reconstruct in this wave: the invoice allocation of each customer line (AR_SUBTRNS as a third level: payment methods
  "تنازلي على الفواتير", "شاشة مساعدة للفواتير", "مبلغ دائن لعميل", "مبلغ دون خصمه" from `AR_PAYTYP_PASSWORD`, residual / discount
  checks, descriptions "سداد كامل / جزء / باقى الفاتورة", and the customer balances `CRN_BAL_TOTAL` kept with them). A one-level
  master-detail cannot hold it; because the legacy check "اجمالى حركة العميل يجب ان تكون مساوية لتفاصيل الفواتير" is kept, customer
  lines with a value cannot be saved until the allocation exists. Suggestion: reuse the ARCRTRN allocation of `APP_RULES_AR`
  (`add_allocation`, `after_save_credit`) per customer line, or a separate allocation page.
- Not reproduced: posting / cancel posting (the buttons run the external posting programs ARACUPDT_MULTI / AR_CPOSTING_MULTI with
  a default WHERE; not in the form), the treasury buttons "حركة الصناديق" / "حركة البنوك" (open the RP / cheques documents of
  systems 15 / 13, not installed), voucher print, the book / receipt number checks of the salesman books (see ARCRTRN), the
  cheque-number check against `VN_MAINTRNS` (reads the AP table with an AR type: legacy defect).
- Questions: the payment-method codes of `PAY_METHOD` (the labels are known, not the values); confirm the total formula.
