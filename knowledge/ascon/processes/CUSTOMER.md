# CUSTOMER - ملف أرقام العملاء / Customers File

- Registry: system 4 serial 28 (`CODES_MENU.ARMAST`). Legacy source `CUSTOMER.fmb` (full triggers in the evidence pack).
- APEX: generated master-detail (from the .fmb) kept (`"pattern": "AUTO"`): `CUSTOMER` with `AR_CUST_SALESMAN` (الأقسام و المندوبين),
  `AR_CUST_DSCNT` (شرائح الخصم), `AR_CUST_RESP`, and the read-only views of dues, dues payments and routes. Rules, info panel and hooks in
  `APP_RULES3_AR`. Data: 126 customers (3 levels), 138 department / salesman rows.

## Rules

| Rule | Evidence (trigger) | APEX | Confidence |
|---|---|---|---|
| group filter `CODE IN AR_CUST_PASSWORD` | block WHERE | `where` | high |
| code: padded to 12 digits, level from `AR_CHART_STRUCTURES` (non-zero part after a zero part refused), parent must exist "عميل غير موجود", duplicate "رقم مكرر", new customer is a leaf (`CUSTOMER_STATUS = 1`) | CODE WVI, DETECT_CUST_LEVEL, GET_CUST_PARENT, PRE-INSERT | row rule `customer_row`; code mandatory (`key_expr`; `AR_BASIC.AUTO_SERIAL` generation is commented out in the form) | high |
| parent becomes non-leaf after insert (`CUSTOMER_STATUS = 0`); becomes a leaf again when its last child is deleted | POST-INSERT, POST-DELETE, CUST_HAS_BROTHERS | after-save `customer_after` (CREATE / DELETE) | high |
| identity / membership repeated: "رقم هوية مكرر" (type 0 person) / "رقم عضوية مكرر" (type 1 company) | PRE-INSERT, list values 0 فرد / 1 شركة | row rule | high |
| telephones / fax: numeric, > 0, 7..17 digits (legacy texts) | TELEPHONE1-3 / FAX WVI | row rule (`phone_msg`) | high |
| days limit, credit limit >= 0; identity, membership, registry > 0 | WVIs | row rule | high |
| area, branch, class required ('Field Must Be Entered'); branch of the area; class not stopped (`DSCNT_STOP_FLAG = 0`) | WVIs, LOVs | row rule | high |
| account <> discount account "لا يمكن تكرار رقم الحساب"; accounts / cost centres exist | WVIs, LOVs | row rule | high |
| stop flag off -> stop date / reason cleared; on -> stop date defaults to today; CHECK_DATE on entered stop / open dates | STOPFLAG WVI, PRE-INSERT/UPDATE, CHECK_DATE | row rule (date check only for dates the user changed; 01-01-1000 is the column default) | high |
| code / area / branch / currency locked once AR transactions exist (currency also with opening balances or stock documents): "هذا العميل تم ادخال حركات عليه من قبل ..." | PRE-UPDATE, WHEN-NEW-RECORD-INSTANCE (CURRENCY CLOSE) | row rule | high |
| delete: parent "العميل رئيسي بالفعل"; transactions "لا يمكن ملف العميل بينما هناك حركات ..."; opening balances " توجد حركات أفتتاحية ..."; details "لا يمكن إلغاء سجل رئيسي في و جود سجلات تابعة له" | KEY-DELREC, ON-CHECK-DELETE-MASTER | delete triggers `APP_RULES3_AR_CUSTOMER_BD`, `_CUSTSLSM_BD`, `_CUSTDSCNT_BD`, `_CUSTRESP_BD` | high |
| department required "لابد من ادخال قسم للعميل" | PRE-INSERT | confirmation at CREATE (the grids appear after the first save) and refusal at SAVE when the customer still has none (after-save) | medium |
| salesman of the department `AR_CTGRY_SALESMAN`: "رقم المندوب المدخل غير موجود فى القسم المختار"; repeated "القسم ... و المندوب ... تم إدخالهم من قبل." | AR_CUST_SALESMAN PRE-INSERT/UPDATE, SALESMAN_CODE WVI | row rule `cust_salesman_row`; salesman mandatory (`key_expr`) | high |
| salesman credit limit >= 0; sum of salesman limits <= customer limit "مجموع حد الائتمان لابد أن يكون أقل من أو مساويا لحد ائتمان العميل" (checked when either was changed) | CREDIT_LIMIT WVI, PRE-INSERT | row rule + after-save with a pre-save snapshot | high |
| salesman linked to transactions / sales orders cannot be removed: "لايمكنك حذف هذا المندوب لأنه مرتبط مع العميل في إحدى الحركات" | KEY-DELREC, PRE-DELETE | delete trigger | high |
| customer account defaults from the branch department account (`AR_CTGRY_SUBAREA.ACCOUNT_NO`) | CTGRY_CODE WVI | after-save | high |
| discount periods: repeated "شريحة الخصم مكررة لنفس العميل", percent 0..<100, value >= 0; no change / delete once AR transactions exist | AR_CUST_DSCNT triggers | row rule / delete trigger | high |
| responsible code = global `NVL(MAX(RESP_CODE),0)+1` | AR_CUST_RESP PRE-INSERT | `key_expr` | high |
| balances and activity: current balance (`GET_CUSTOMER_BAL`), debit / credit, balance in local currency, opening balance, first / last invoice, dealing period, sales / returns to date, monthly and daily averages, collections and daily average, area / branch / class / account names | POST-QUERY, CALC_UPT_INFO | `info` panel | high |

## Tests (rolled back, 51 checks passed)

Code required / structure / parent / duplicate; area / class / branch; telephones / fax; credit; equal accounts; future stop date;
repeated identity; padding + level + leaf + stop fields; after-save CREATE / SAVE / DELETE; department salesman rules; credit-limit sum;
account default; discount periods; responsible code; document delete refusals; locked area of a customer with transactions; delete of a
customer with transactions / of a parent; salesman with transactions; info values = `GET_CUSTOMER_BAL`.

## Coverage

- Reproduced: all rules above.
- Not reproduced (with reason):
  - customer tree and its buttons (Forms hierarchical tree; the list page is searchable) and `ADD_CUSTOMER_CHILD` ("هل تريد انزال ابناء المستوي"
    - `AR_CHART_STRUCTURES_CHILD` is empty, feature unused);
  - opening requests: `REQ_CODE` (copy of an approved `CUSTOMER_OP_REQ`, taxes and salesman created at insert) - hidden (its wrong
    automatic list `EZN_REQ` is removed with wave-3b `rules.columns`; the copy logic is not reproduced); `CUSTOMER_OP_REQ` is empty;
  - year-filtered blocks `CUSTOMER_DOC`, `CUSTOMER_REM`, `CUSTOMER_STAT`, `CUSTOMER_CNTRCT` and their attachment buttons (`SYS_DOCS`
    form) - not placed by the generator (AUTO specs cannot add detail blocks and a MASTER_DETAIL override cannot keep the read-only flags
    of the other details); all four tables are empty or nearly so;
  - sales / target navigator (BLOCK148 year / month buttons) - covered by the sales and target reports;
  - customer attribute lists (`TAB_NO1..24` -> `ATTR_CODE`): the attribute structure is empty;
- Lists (wave-3b `rules.columns`): area, branch (area/branch), active classes, active accounts, first cost centre; the row rules still
  validate the values (branch of the area, class not stopped).
