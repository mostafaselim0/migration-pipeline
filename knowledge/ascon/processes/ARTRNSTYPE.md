# ARTRNSTYPE - ملف أرقام الحركات / Transactions Codes File (AR transaction types)

- Registry: system 4 serial 29 (`CODES_MENU.ARTRNSTYPE`). Legacy `ASCON\AR\FMB\artrnstype.fmx` (no .fmb). 20 types.
- APEX: generated master-detail `AR_TRNSTYPE` / `AR_TRNSTYPE_DSCNT` (pages 30160-30162) kept; rules in `APP_RULES3_AR`.
- Value meanings used below come from the data and from the AR posting procedure (`processes\ARACUPDT.md`: account directions
  0 none, 1 area, 2 branch, 3 customer, 4 the type's account, 5 the transaction's account; cost directions 4 type, 5 transaction,
  6 salesman).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| list of types restricted by `AR_TRNSTYPE_PASSWORD` (FLAG = 1) for groups | block WHERE | `where` | high |
| duplicate id "كود مكرر" | `SELECT COUNT(1) FROM AR_TRNSTYPE WHERE ID` | primary key | high |
| "نوع الحركة غير متوافق مع تأثير الحركة على العميل": sales (0) must be debit (EFFECT 0), returns (1) and payments (3) credit (EFFECT 1) | message, list texts, data | row rule `trnstype_row` | medium (value mapping inferred from the data) |
| GL-linked type (`ACCOUNT_JOINT = 1`): "يجب إدخال نوع القيد المحاسبى", "يجب إدخال كل انوع التوجيهات المحاسبية" | messages | row rule | high |
| direction 4 needs the account: "يجب إدخال حساب نوع الحركة", "يجب إدخال حساب العميل", "يجب إدخال حساب الخصم" | messages | row rule | medium |
| accounts distinct: "لا يمكن تكرار رقم حساب نوع الحركة مع الحسابات الاخرى", "لا يمكن تكرار رقم حساب العميل مع الحسابات الاخرى" | messages | row rule | high |
| accounts / voucher type exist (`AC_MASTER` status 1, `AC_TRN_CODES`) | LOVs | row rule | high |
| discount periods: "شريحة الخصم مكررة لنفس نوع الحركة", period exists | SQL, message | row rule `trnstype_dscnt_row` | high |
| deleting a type deletes its periods (`DELETE FROM AR_TRNSTYPE_DSCNT WHERE ID`) | SQL | document delete cascade | high |
| missing columns / labels: posting type (قيد لكل حركة / لكل نوع), area, branch, last serial (read-only), external collections (`TOT_TRNS_FLAG`) | .fmx texts | `add_columns`; the list values are written into the labels | medium |

## Tests (rolled back)

Sales type with credit effect refused; payments with debit effect refused; GL link without voucher type / directions refused;
direction 4 without account refused; equal accounts refused; valid type accepted; repeated period refused; existing type 201 updatable
(batch 1).

## Coverage

- Reproduced: the checks above.
- Not reproduced: drop-down lists of the direction / type columns (generator: no static-list override - labels carry the values);
  `SELECT COUNT(1) FROM AR_MAINTRNS WHERE TRNS_ID AND POST_FLAG = 1` has no message in the form: its effect (probably blocking changes
  of a type with posted transactions) is unknown - question for the key user.
