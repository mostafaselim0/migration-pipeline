# ARTRN_OP - الأرصدة الإفتتاحية للعملاء المدينة / الدائنة (Customer opening balances)

- Registry: system 4 serial 7 (`SYSTEM_MENU.ARTRN_OP_DEBIT`) and serial 14 (`ARTRN_OP_CREDIT`), one form with parameter `P_CREDIT_DEBIT`.
- Legacy `ASCON\AR\FMB\artrn_op.fmx` (no .fmb). Data: 62 headers, 114 lines (types 901 debit / 902 credit, `TRNS_TYPE = 6`), 114 generated
  customer transactions.
- APEX: generated master-detail `AR_MAINTRNS_OP` / `AR_SUBTRNS_OP` (pages 30200-30202) kept; one page shows debit and credit types.
  Rules and hooks in `APP_RULES3_AR`.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| types `TRNS_TYPE = 6` of the user's group (debit or credit by menu entry) | block WHERE, TRNSTYPE_LOV | `where`, default = first debit type, row rule `op_mast_row` | high |
| header serial `NVL(MAX(TRNS_SERIAL),0)+1 WHERE TRNS_ID` | SQL | generated key | high |
| date: not before `AR_BASIC.MIN_DATE` "التاريخ أقل من الحد الأدنى المسموح به"; not after today | SQL, messages, CHECK_DATE | row rule | high |
| "رقم المستند لا يمكن ان يكون اقل من او يساوي الصفر" | message | row rule | high |
| description from the type (`DESC_FLAG`, `INITIAL_DESC`, `PLUS_DOC_NO_FLAG`) | SQL | row rule (when empty) | medium |
| line: active leaf customer of the department (customer LOV), group range; area / branch of the customer; salesman of the customer in the department; customer currency "خطأ في عملة العميل"; rate 1 for the local currency "يجب ان يكون معامل التحويل ب 1", > 0; value > 0 "القيمة يجب أن تكون أكبر من الصفر"; date >= customer open date "تاريخ الحركة لا يمكن ان يكون اقل من تاريخ فتح العميل"; debit needs an invoice number "يجب ادخال رقم فاتوره حتى يمكن السداد عليها" | LOVs, SQL, messages | row rule `op_line_row` | high |
| one opening balance per customer / department / salesman and effect "تم إدخال رصيد إفتتاحى للعميل التالي من قبل" | SQL, message | after-save of the document (covers changed lines) | high |
| line bill sequence `NVL(MAX(BILL_SEQ),0)+1` | SQL | generated key | high |
| POST-INSERT: customer transaction `AR_MAINTRNS` (serial max+1 per type, store 999999999999, pay method 4, residual = total, header date / doc / description) and for a debit balance its invoice bill `AR_SUBTRNS` (bill 1, `BILL_ID1` = invoice number, `BILL_ID2 = NVL(MAX(BILL_ID2),0)+1 WHERE BILL_ID1`); `CUSTOMER.CRN_BAL_TOTAL` +/- value and `BEG_BAL` = +/- value; `AR_CUST_SALESMAN.CRN_BAL_TOTAL` +/- value | INSERT / UPDATE statements | row rule (checked against the 114 existing lines: the 107 debit lines match their transaction and bill in every column; the 7 credit transactions differ only in `PAY_METHOD` = 1, most likely set later by their allocation) | high |
| delete of a line: the generated transaction and bill are deleted, balances reversed, `BEG_BAL = 0`; a header with lines cannot be deleted | DELETE / UPDATE statements, relation | delete trigger `APP_RULES3_AR_OPLINE_BD` | high |
| "لا يمكن تعديل رصيد افتتاحي للعميل بينما هناك حركات تم إدخالها من قبل" (`COUNT(1) FROM AR_MAINTRNS WHERE CUSTOMER_ID AND TRNS_DATE <= date`) | SQL, message | checked on insert, change and delete, other opening balances excluded; additionally refused when the generated transaction was allocated / posted (safety, see below) | medium |

## Tests (rolled back, 26 checks passed)

Type / date / document checks; header serial; invoice number, value, rate, department checks; derived area / salesman / currency;
generated AR_MAINTRNS and AR_SUBTRNS; customer and salesman balances; duplicate balance refused; change replaces the generated
transaction and follows the balances; allocated balance cannot be changed or deleted; header with lines not deletable; delete reverses
everything; credit balance has no invoice bill and BEG_BAL = -50.

## Coverage

- Reproduced: all rules above.
- Changed on purpose (suggestion, review): a changed line replaces its generated transaction (the legacy has no update statement - lines
  were probably deleted and re-entered); a line whose generated transaction was already allocated or posted cannot be changed or deleted
  (the legacy delete removed `AR_SUBTRNS` of the transaction, which would drop allocations).
- Not reproduced: `AC_BASIC.CLOSE_DATE` read at date entry (message not found; the DB trigger `CLOSE_AR_MAINTRNS` guards the generated
  transactions when enabled - it is disabled on the build copy); total in local currency per line (shown as totals in the info panel).
