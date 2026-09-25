# ST_SALES_ORDER_STAT - متابعة حركات المخازن / Stores Transaction Status

- Registry: system 3 serial 17 (`FILES_MENU.ST_SALES_ORDER_STAT`); also system 31 serial 22 and system 30 serial 44.
- Legacy module: `ASCON\ST\FMB\ST_SALES_ORDER_STAT.fmx` (no .fmb). Control block (from / to store, from / to date, "نوع الحركات",
  "نوع البيانات", customer / supplier) and a query block on the view `ST_TRNS_ALL` with per-document totals. Query only.
- APEX: `PROCESS` page 20330 (override `ST_SALES_ORDER_STAT.json`), button "تنفيذ الاستعلام"; procedure
  `APP_RULES3_ST.show_docs` (checks), totals by `APP_RULES3_ST.doc_total`.
- Confidence: high for the filters and the total / tax / discount formulas, medium for "اجمالى الأصناف" (derived).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| store range defaults to the first / last active transaction store of the user group | `SELECT MIN(STORE_CODE) / MAX(STORE_CODE) FROM ST_STORE WHERE NVL(STORE_STATUS,0)=1 AND NVL(STOP_FLAG,0)=0 AND (:b1=0 OR STORE_CODE IN (SELECT .. ST_STORE_PASSWORD ..))` | parameter defaults (SQL) | high |
| "لابد من ادخال محددات البحث جميعها", "يجب أن يكون الي رقم مخزن > من رقم مخزن", "يجب أن يكون الي تاريخ> من تاريخ" | messages (same library as ST_TRNS_SLS_PU_STAT) | `show_docs` | high |
| نوع الحركات: عروض أسعار المبيعات / أوامر البيع / فواتير المبيعات / مرتجع المبيعات / أوامر الشراء / الرسائل الواردة / فواتير المشتريات / مرتجع المشتريات / تحويلات المخازن / استلام تحويلات المخازن | list texts; RDF `TRNS_FILTER` 0..7 = (16/7), (30/7), (2/2), (4/4), (14/7), (15/7), (1/1), (3/3), 10 = all | list value n = `TREE_ORDER` n + 1 of `ST_TRNS_ALL`; empty = all | high |
| نوع البيانات: غير محول للحركة التالية / محول للحركة التالية / الكل | list texts; RDF `(:FILTER = 0 AND NEXT_TRNS IS NULL) OR (:FILTER = 1 AND NEXT_TRNS IS NOT NULL) OR :FILTER = 2` | NEXT_FILTER 1 / 2 / empty | high |
| customer (sales kinds 0-3) or supplier (purchase kinds 4-7) | CUST_SUPP_LOV with `NVL(:TRNS_FILTER,10) IN (0,1,2,3)` / `(4,5,6,7)` | parameter FROM_CODE (typed code, no list of values: the generator has no union list for a number parameter that depends on another one) | medium |
| types of the user group `(:1 = 0 OR TRNS_TYPE_CODE IN (SELECT .. ST_TRNSTYPE_PASSWORD TP WHERE TP.FLAG=1 ..))` | block WHERE | `trns_type_allowed` in the preview | high |
| اجمالى الحركة = `SUM(QTY*(PRICE-(D1+D2+D3)) - DET_DISC + D.TAX) - DISC_VAL + M.TAX + TRNSPORT - (TOT_DISC1+2+3)`; اجمالى الضريبة = `SUM(D.TAX) + M.TAX`; اجمالى الخصومات = `SUM(QTY*(D1+D2+D3+DET_DISC)) + TOT_DISC1+2+3 + DISC_VAL` over ST_PROPOSAL_* (quotations), ST_SALES_ORDER* (orders), ST_TRNS_* (the other kinds) | three SQL statements of the .fmx | `doc_total(tree, type, serial, 'TOTAL' / 'TAX' / 'DISC')` | high |
| اجمالى الأصناف | label only | `TOTAL - TAX + DISC` | medium |
| customer / supplier / store names | `SELECT NAME_A, NAME_E, OLD_CODE FROM CUSTOMER`, `... VENDOR_CODE FROM SUPPLIER`, `... FROM ST_STORE` | preview column الاسم | high |

Tested (rolled back, `t_rules3_st.py` J4, J6): missing criteria / reversed dates refused; total and discounts of a sales invoice equal the
legacy formulas; preview of sales invoices (1318 rows, all `TREE_ORDER` 3 with a total) and of quotations not transferred (218 rows, no
`NEXT_TRNS`).

## Printing (layout: main session)

`ST_SALES_ORDER_STAT.RDF` over `ST_TRNS_ALL` with LANG, FROM_DATE, TO_DATE, P_PASSWORD_NUMBER, COMP_CODE, FROM_STORE, TO_STORE,
TRNS_FILTER, FILTER (0 not transferred / 1 transferred / 2 all), FROM_SC_CODE, TO_SC_CODE; not in `prints.json`. Note the RDF
also filters the stores of the user group (`ST_STORE_PASSWORD`), the form does not.

## Coverage

- Reproduced: all criteria, defaults and checks; the document list with names, "الحركة المحول عليها" and the four totals.
- Not reproduced:
  - the counts of lines whose discount ratios exceed the original ratios (`DISC1_RATIO > ORG_DISC1_RATIO ...`) and of items whose
    bonus ratio exceeds `ORG_BONUS_RATIO` / `ORG_EXTRA_BONUS_RATIO`, and `RETURN_TYPE_FLAG` (`DECODE(NVL(RET_TRNS_SERIAL,0),0,1,0)`):
    computed per document in the .fmx but no label shows them - presumably a row colour; open question;
  - totals of purchase orders and incoming lots (no formula in the evidence: the columns stay empty);
  - the `FILE_PASSWORD` reads for the document screens (presumably rights to open a document from the list);
  - the print (see above).
- Suggestion (not done): the view `ST_TRNS_ALL` of the build copy has '???' literal type descriptions; the preview uses its own labels.
