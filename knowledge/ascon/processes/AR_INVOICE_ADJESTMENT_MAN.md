# AR_INVOICE_ADJESTMENT_MAN - تسوية فواتير العملاء يدوي / Customer Invoices Manual Adjustment

- Registry: system 4 serial 42 (no menu entry). APEX page 30320.
- **Deliverable: (b) process screen**
  - PL/SQL: `app_proc_ar.manual_adjust(p_action, p_payment, p_invoice, p_amount, ...)` in `app\db\20_proc_ar.sql` (package `APP_PROC_AR`, VALID).
  - Override: `app\legacy\overrides\AR_INVOICE_ADJESTMENT_MAN.json` (payment LOV = open payments; invoice LOV = open invoice bills;
    preview = open invoices of the payment's customer + allocation lines of the payment).
- **Confidence: medium** - allocation rules, texts and permissions are in the compiled form and confirmed by 1 030 existing allocation lines;
  wave 3 added the discount part (CALCULATE_DISCOUNT, typed discount, header DISC_VALUE / NET_VALUE); the customer-balance update is a no-op here
  (see Coverage).

## What the legacy screen is

A master-detail entry screen: master AR_MAINTRNS = payment / credit transactions (AR_TRNSTYPE.EFFECT = 1) that still have an unallocated value
(`TOTAL_VALUE - AR_RESIDUAL_VALUE_DATE(..., SYSDATE) > 0`), with the group filters on transaction type, customer and salesman
(AR_TRNSTYPE_PASSWORD, AR_CUST_PASSWORD, AR_SALESMAN_PASSWORD); detail AR_SUBTRNS = allocation lines of that payment to invoice bills
(INV_TRNS_ID / INV_TRNS_SERIAL / INV_MAINAREA_ID / INV_SUBAREA_ID / INV_BILL_SEQ), invoice chosen from BILL_LOV = open bills (EFFECT 0) of the
customer with residual `TOTAL_VALUE - AR_SUBTRNS_PAYED_VALUE(...)`. It is kept as a process because saving a line has side effects (residuals,
payment description) and validations that a generated grid would not reproduce.

## Evidence (`evidence\AR_INVOICE_ADJESTMENT_MAN.md`, compiled `AR\FMB\AR_INVOICE_ADJESTMENT_MAN.fmx`)

- Master WHERE, BILL_LOV query, `SELECT NVL(MAX(BILL_SEQ),0)+1 FROM AR_SUBTRNS WHERE payment key`, residual query per bill.
- `UPDATE AR_SUBTRNS SET RESIDUAL_VALUE = RESIDUAL_VALUE + :v WHERE invoice bill key`,
  `UPDATE AR_MAINTRNS SET RESIDUAL_VALUE = RESIDUAL_VALUE + :v, DISC_VALUE = NVL(:total,0) - NVL(:net,0), NET_VALUE = NVL(:net,0) WHERE payment key`,
  `SELECT PLUS_INV_NO_FLAG FROM AR_TRNSTYPE` + `UPDATE AR_MAINTRNS SET DESCRIPTION_A = DESCRIPTION_A || ' ' || 'ف(' || :inv || ')'`.
- Delete: `SELECT NVL(DELETE_AR_ADJESTMENT,0) FROM USERS` + `DELETE FROM AR_SUBTRNS WHERE payment key`; texts "ليس لديك صلاحية",
  "لا يمكن حذف حركة سداد لها خصم".
- Validation texts: "القيمة يجب أن تكون أكبر من الصفر", "القيمة المتبقية بالفاتورة أصغر من القيمة المدخلة للسداد",
  "قيمة الفواتير المسددة يجب أن تكون مساوية القيمة الكلية للسداد", "قيمة الخصم لابد أن تكون أقل من القيمة المدخلة للفاتورة".
- Line descriptions "سداد كامل الفاتورة (", "سداد باقى الفاتورة (", "سداد جزء من الفاتورة (", "بسند قبض رقم(", "بقيمة خصم(" - existing lines:
  `سداد جزء من الفاتورة (7871/1) بسند قبض رقم()`, `سداد باقى الفاتورة (7802/1) بسند قبض رقم() بقيمة خصم(0)` with DET_DESC_E
  `Pay part of invoice value (7871/1) with doc no()`, INV_PAY_DATE = payment date, POST_FLAG = payment's POST_FLAG, WITHOUT_COMM_FLAG 0.
- Discount lookups (AR_CUST_DSCNT / AR_CUST_CLASS_DSCNT / AR_TRNSTYPE_DSCNT / AR_CTGRY_DSCNT by AR_PERIOD) - see question 1.
- DB procedure `AR_ADJUST_RESIDUAL(customer)` (vendor): recomputes payment residual = total - own lines, invoice total = sum of lines,
  bill residual = total - allocations, then COMMITs.

## Rules implemented

- Action 1 (allocate): payment must exist, be of EFFECT 1, pass the group filters and have an open value; invoice bill of EFFECT 0 of the same
  customer with an open value; amount default = min(open payment, open invoice); amount > 0 (ORA-20133), <= open invoice (ORA-20134),
  <= open payment (ORA-20135 - the legacy "total of the allocated invoices must equal the payment" check at commit).
  Inserts the AR_SUBTRNS line (next BILL_SEQ; BILL_ID1 / BILL_ID2 / STORE_CODE of the invoice bill; DISC_VALUE 0; description full / remaining /
  part as above, Arabic and English), then refreshes the residuals of the invoice bill and of the payment, and appends " ف(docno/category)" to
  the payment description when AR_TRNSTYPE.PLUS_INV_NO_FLAG = 1 (as in the 39 existing descriptions).
- Action 2 (remove, legacy DEL_BTN): USERS.DELETE_AR_ADJESTMENT = 1 (ORA-20125), no line with a discount (ORA-20126); deletes all lines of the
  payment and refreshes the residuals. **Deviation:** removal is allowed on any payment (the payment LOV lists all payments, open ones first);
  the legacy block only showed payments with an open value, but a user could still delete the lines of a payment he had just allocated in full.
- Residual refresh: instead of the legacy `RESIDUAL_VALUE = RESIDUAL_VALUE +/- value`, the residuals are recomputed from the lines with the
  formulas of `AR_ADJUST_RESIDUAL` / `AR_SUBTRNS_PAYED_VALUE` (same result when the stored value is right; 327 of 1 442 stored bill residuals are
  stale today, the increment would carry the error). No COMMIT (AR_ADJUST_RESIDUAL itself commits, so it is not called).

## Tests (all rolled back)

- Credit adjustment 401/67 (73.95 open) to invoice 101/457 (13 151.58 open): line "سداد جزء من الفاتورة (7934/1) بسند قبض رقم()" 73.95, payment open 0,
  invoice open 13 077.63 (stored residual refreshed); negative amount -> ORA-20133; amount above the invoice residual -> ORA-20134.
- Remove by user 0 (DELETE_AR_ADJESTMENT = 1) right after the full allocation: lines deleted, payment residual back to 73.95; user 5 -> ORA-20125;
  allocating on a fully allocated payment (201/350) -> ORA-20128. LOV / preview queries validated (payment LOV 916 rows).

## Wave 3: discount

- Parameter **DISC** (`p_disc`) added to the process page. Empty = the form's CALCULATE_DISCOUNT: days = payment date - INV_DATE of the bill
  (negative = 1), first matching period of AR_CUST_DSCNT -> AR_CUST_CLASS_DSCNT -> AR_TRNSTYPE_DSCNT -> AR_CTGRY_DSCNT, percentage of the
  **invoice total** (`:INV_TOTAL_VALUE` in the bind list) capped by DSCNT_VALUE; the class cursor of this form has no AR_PERIOD.SERIAL join
  (reproduced: `calc_discount(..., p_class_period => 0)`). DSCNT_PERIOD / DSCNT_SOURCE stored on the line.
- Discount must not exceed the allocated value ('قيمة الخصم لابد أن تكون أقل من القيمة المدخلة للفاتورة', ORA-20136); the payment is consumed by
  the net (value - discount) (ORA-20135).
- Line NET_VALUE = value - discount, description ' بقيمة خصم(d)' with the real discount; payment header: RESIDUAL = TOTAL - allocated nets,
  DISC_VALUE = allocated totals - nets, NET_VALUE = allocated nets (legacy `UPDATE AR_MAINTRNS SET RESIDUAL_VALUE = ..., DISC_VALUE =
  NVL(:total,0) - NVL(:net,0), NET_VALUE = NVL(:net,0)`); the AR posting credits the customer with TOTAL + DISC_VALUE.
- Tests (`tmp\w3_argl\t_ar.py` M1-M4 and the wave-1 scenarios `t_man.py` 6/6, rolled back): typed discount 1 on 20 -> net 19, header disc 1 /
  residual from nets; discount 5 on 2 refused; computed customer-period discount 0.01 % of the invoice total (1.17); wave-1 allocation of
  401/67 to 101/457 unchanged (no period applies), removal, rights and fully-allocated refusals unchanged.

## Wave 3b

Checked, nothing to change: the parameters already have lists (action, payment, invoice); the screen changes data, so the run button keeps
the insert right (no `run_right: "query"`); the legacy form had no button that only opened another form and no print that prepared a work
table (`print_runs`); the page is a process page, so the column / block keys do not apply.

## Coverage

Reproduced: allocation (action 1) with discount, removal (DEL_BTN), permissions, residuals, descriptions, PLUS_INV_NO_FLAG. Not reproduced:

- CUSTOMER / AR_CUST_SALESMAN.CRN_BAL_TOTAL: the form only adds the discount back in DELETE_DETAIL_EFFECT (never subtracts it on insert) and the
  removal refuses payments with a discount, so the update never changes anything - not ported.
- KEY-COMMIT equality ('قيمة الفواتير المسددة يجب أن تكون مساوية القيمة الكلية للسداد'): one allocation per run; the check is kept as "not above
  the open payment" (deviation from wave 1).
- AR_BILL_DUMMY reservation of picked bills (Forms multi-user helper), printing, prompts.

## Open questions

1. **Discount**: no existing allocation line has a discount, but AR_CTGRY_DSCNT gives 10 % (up to 2 000) to category 1 for payment within 0-1
   day, and the manual form computed it from the **invoice total**. APEX now computes it when DISC is left empty - confirm, or type 0.
2. The automatic version (AR_INVOICE_ADJESTMENT.fmb) sets the payment's PAY_METHOD = 1 after allocation; should the manual one do the same?
3. Should `AR_ADJUST_RESIDUAL` be offered as a separate "recalculate the residuals of a customer" action (it would also fix the 327 stale bills)?
