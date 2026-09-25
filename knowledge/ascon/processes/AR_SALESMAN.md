# AR_SALESMAN - ملف أرقام مندوبي مبيعات الاقسام / Department Salesmen File

- Registry: system 4 serial 27 (`CODES_MENU.SALESMAN`). Legacy `ASCON\AR\FMB\ar_salesman.fmx` (no .fmb).
- APEX: corrected to `MASTER_DETAIL` with the blocks of the compiled form (identifiers and relation names `SALESMAN_AR_*`): `SALESMAN`
  (all fields of the salesman and mobile settings), `AR_CTGRY_SALESMAN` (اقسام المندوب), `AR_CUST_SALESMAN` (عملاء المندوب),
  `AR_SALESMAN_STORES`, `AR_SALESMAN_ACCOUNT` (حسابات ومراكز تكلفة المندوب), `AR_SALESMAN_BOOKS` (دفاتر سداد العملاء) and
  `AR_SALESMAN_BOOKS_DET`. The generated page showed `AR_SLSMAN_TARGETS`, which is not part of the current form (labels of an older
  version). Rules in `APP_RULES3_AR`. Data: 9 salesmen, 14 department links, 7 receipt books; mobile settings unused.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| group filter: salesman range of `AR_CUSTOMER_PASSWORD` | block WHERE | `where` | high |
| "رقم المندوب يجب ان يكون اكبر من الصفر"; duplicate "كود مكرر من قبل" | messages, SQL | row rule `salesman_row`; primary key | high |
| discount ratio "النسبة يجب ان تكون اكبر من الصفر و اقل من 100" | message | row rule | high |
| store active (`STOP_FLAG 0, STORE_STATUS 1`); customer code = leaf customer without salesman; user exists; account / cost centres exist; supervisor is a salesman | LOVs | row rule | high |
| transaction types: sales `EFFECT 2 / TYPE 2`, return `4/4`, sales order `7/30`, transfer out `5/9`, transfer in `6/9`, payments AR types `EFFECT 1, TRNS_TYPE <> 6, MOBILE_TRNS = 1` | LOV SQL | row rule | high |
| department assigned twice "هذا القسم تم تخصيصه للمندوب من قبل" | message | row rule `ctgry_salesman_row` | high |
| salesman with departments / customers cannot be deleted (`SELECT 1 FROM AR_CTGRY_SALESMAN / AR_CUST_SALESMAN WHERE SALESMAN_CODE`); stores, accounts, books deleted with him | SQL | delete triggers on the document delete; cascade of the other grids | high |
| customer of the salesman: not linked to another salesman "العميل مرتبط بمندوب اخر"; salesman of the department; credit >= 0; no change when the customer has transactions "لا يمكن تعديل ملف العميل بينما هناك حركات تم إدخالها من قبل" | customer LOV, messages | row rule `cust_salesman_row` (shared with CUSTOMER) | high |
| account and cost centres entered twice "تم ادخال الحساب ومراكز التكلفة من قبل"; used by cash-box transactions "لا يمكن حذف ملف الحركة بينما هناك حركات من الصناديق تم إدخالها من قبل" | SQL, messages | row rule / delete trigger | high |
| receipt book number = global `NVL(MAX(BOOK_SERIAL),0)+1`, unique; overlapping numbers of type-1 books "أرقام السندات تتقاطع مع سندات مدخلة"; book with registered numbers not deletable | SQL, messages | `key_expr`, row rule `book_row`, delete trigger | high |
| registered receipt number: inside the book "هذا السند غير موجود بالدفتر", once "رقم السند مسجل بالفعل بالسندات المدخلة", not used by AR "السند مربوط بنظام العملاء" or cheques "السند مربوط بنظام الشيكات" | SQL, messages | row rule `book_det_row` | high |

## Tests (rolled back)

Code / ratio / type checks; department twice; customer of another salesman; free customer linked; book serial; overlap; receipt outside the
book, twice, used by AR; book with numbers not deletable; salesman with departments not deletable; books deleted with the salesman
(batch 2, 51 checks with CUSTOMER).

## Coverage

- Reproduced: all rules above.
- Not reproduced: "تم عمل حركة صرف علي هذا السند" - its SQL tests `AR_TRNSTYPE.EFFECT = 2`, which never exists (dead check); the overlap
  check on changed books (insert only: the grid saves row by row and the table cannot be read from its own row trigger on update);
  drop-down lists (salesman type, account type) - values listed in the labels; the receipt-book reminder is data only (`AR_BOOKS_NOTIF`).
