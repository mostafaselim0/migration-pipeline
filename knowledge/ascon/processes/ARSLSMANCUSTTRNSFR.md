# ARSLSMANCUSTTRNSFR - تحويل العملاء من المندوبين / Transfer Customers between Salesmen

- Registry: system 4 serial 4 (`SYSTEM_MENU.TRNSLEGATE`). Legacy `ASCON\AR\FMB\ArSlsmanCustTrnsfr.fmx` (no .fmb).
- Data: 3 transfer headers, no lines; no AR transaction type with `TRNS_TYPE = 5` exists on this database (the transfer types must be
  created before the screen can be used).
- APEX: generated master-detail `AR_SLSMAN_TRNSFR` / `AR_SLSMAN_TRNSFR_DET` (pages 30210-30212) kept - the legacy screen is a transfer
  document whose lines execute the transfer when saved; the process is reproduced as row rules, a delete hook and a document action
  (`APP_RULES3_AR`).

## Rules and buttons

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| salesmen of the user's group; date >= `AC_BASIC.MIN_DATE` "التاريخ أقل من الحد الأدنى المسموح به" | LOV, SQL | `where`, row rule `trnsfr_mast_row` | high |
| header serial `NVL(MAX(DATE_SERIAL),0)+1 WHERE FROM_SLSMAN`; "تم نقل هذا المندوب فى نفس التاريخ من قبل" | SQL, message | `key_expr`, row rule | high |
| line serial `NVL(MAX(SERIAL),0)+1 WHERE FROM_SLSMAN AND TRNSFR_DATE AND DATE_SERIAL` | SQL | `key_expr` | high |
| line checks: customer of the old salesman in the department, active; new salesman of the department (not the old one); credit / debit transfer types (`EFFECT 1 / 0, TRNS_TYPE 5`) "يجب تحديد الحركات الدائنة والمدينة"; "تم نقل هذا العميل فى نفس التاريخ من قبل"; later transfer "توجد حركة نقل سابقة لهذا المندوب بتاريخ اكبر من التاريخ المدخل"; open date / opening balance date; later AR transactions "يوجد حركة للعميل رقم ... مع المندوب رقم ... بنظام العملاء لها تاريخ لاحق"; stock sales / returns later or not posted "... بالمخازن لها تاريخ لاحق أو لم ترحل" | LOVs, SQL, messages | row rule `trnsfr_line_row` | high |
| transfer: customer balance (all AR transactions, currency and local); debit transfer (`DB_TRNS_CODE`, |balance|, `POST_FLAG 1`, pay method 0, residual 0, bill `BILL_ID1 = type||area`, `BILL_ID2 = branch||serial`) and credit transfer (`CR_TRNS_CODE`, pay method 2, residual 0) allocated to it (`INV_TRNS_*`); salesman of each by the sign of the balance; serials max+1 per type / area / branch; `AR_CUST_SALESMAN` moved to the new salesman | INSERT / UPDATE statements | row rule | medium (assignment of old / new salesman by sign inferred from `DECODE(SIGN(bal), -1, ...)`) |
| delete of a line: only the customer's last transfer "يجب حذف اخر حركات النقل اولا", no later AR transactions "توجد حركات بعد تاريخ النقل", both transactions deleted, customer back to the old salesman; header with lines not deletable | SQL, messages | compound delete trigger `APP_RULES3_AR_TRNSFR_BD` | high |
| "يجب تحديد العملاء المنقولة" | message | after-save (SAVE) | high |
| button "إنزال عملاء المندوب": the old salesman's customers (department optional) without later AR transactions become lines | SQL of the button | document action `LOAD_CUSTOMERS` (new salesman and transfer types asked once for all lines; lines can be removed afterwards) | medium |

## Tests (rolled back, 22 checks passed; temporary transfer types 9501 / 9502)

Minimum date; header serial; same salesman / date twice; save without customers; wrong types; new salesman outside the department;
transfer pair values, flags, salesmen by sign, allocation link; customer balance unchanged; department moved; same customer / date twice;
line not changeable; document delete refused; delete reverses; button transfers 79 customers.

## Coverage

- Reproduced: the full transfer with its checks, reversal and the load button.
- Adapted: the button asks the new salesman and the transfer types once (legacy lines were filled row by row after loading).
- Not reproduced: balance shown in the loader LOV (the lines store it: `BALANCE`, `BALANCE_RIYAL`). The description of the generated
  transactions is ours (legacy passes a bind not visible in the compiled SQL). Question: confirm the salesman of each transfer transaction
  (debit to the new salesman for a debit balance).
