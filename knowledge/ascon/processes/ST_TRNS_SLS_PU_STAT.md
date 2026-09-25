# ST_TRNS_SLS_PU_STAT - متابعة حركات الصنف / Items Transaction Status

- Registry: system 3 serial 16 (`FILES_MENU.ST_TRNS_SLS_PU_STAT`, order 1013); also system 31 serial 24.
- Legacy module: `ASCON\ST\FMB\ST_TRNS_SLS_PU_STAT.fmx` (no .fmb). Control block (item, from / to date, from / to store) and a
  query block on the view `ST_TRNS_DET_SLS_PU` with in / out / running balance; a summary of totals; a query-only screen.
- APEX: `PROCESS` page 20110 (override `ST_TRNS_SLS_PU_STAT.json`): the five criteria (all required), button "تنفيذ الاستعلام";
  the preview starts with the opening balance row "رصيد أول المدة للصنف", then the movements with in / out / running balance.
  Procedure `APP_RULES3_ST.show_item_trns` (checks), function `APP_RULES3_ST.item_open_balance`.
- Confidence: high for the list and checks, medium for the opening balance (derived from the view, see below).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| "لابد من ادخال محددات البحث جميعها" | message | `show_item_trns` (item, both dates, both stores) | high |
| "يجب أن يكون الي رقم مخزن > من رقم مخزن", "يجب أن يكون الي تاريخ> من تاريخ" | messages | `show_item_trns` | high |
| movements: `ST_TRNS_DET_SLS_PU WHERE ITEM_CODE AND TRNS_DATE BETWEEN :from AND :to AND STORE_CODE BETWEEN NVL(:fs,0) AND NVL(:ts,999999999999)` and the types of the user group `(:pw = 0 OR TRNS_TYPE_CODE IN (SELECT .. FROM ST_TRNSTYPE_PASSWORD TP WHERE TP.FLAG = 1 ..))` | summary SQL and block WHERE | preview (`trns_type_allowed`) | high |
| in = `TOTAL_QTY` of EFFECT 1, 4, 6; out = EFFECT 2, 3, 5; balance after each movement from the opening balance | items IN_QTY / OUT_QTY / BALANCE_QTY, OP_BALANCE_QTY | preview (analytic running sum) | high |
| opening balance "رصيد أول المدة للصنف" = the same movements before the first date | text, item OP_BALANCE_QTY | `item_open_balance` | medium (formula of the .fmx not visible) |
| summary: purchases (1/1), sales (2/2), purchase returns (3/3), sales returns (4/4), opening balances (1/8), other receipts (1/7), other issues (2/7), each as total and as quantity / bonus / extra bonus | summary SQL (`SUM(DECODE(T.EFFECT,1,DECODE(T.TRNS_TYPE,1,TOTAL_QTY,0),0)) PU_INV ...`), texts "إجمالي أرصدة أفتتاحية", "مشتريات", "م مشريات", "مبيعات", "م مبيعات", "إجمالي صادر", "إجمالي وارد" | preview columns "نوع الإجمالي" (category), الكمية / البونص / بونص إضافي: the report totals them per category (control break / aggregate) | high |
| customer / supplier / receiving store name by `FROM_CODE` | `SELECT NAME_A, NAME_E, OLD_CODE FROM CUSTOMER`, `... FROM SUPPLIER`, `... FROM ST_STORE` | column الاسم | high |
| stores list: active transaction stores of the user group, descending for "الى مخزن" | LOV SQL | parameter lists of values | high |

Tested (rolled back, `t_rules3_st.py` J3, J6): missing criteria and reversed store range refused; preview for the busiest item of
store 101010101001 from 01/01/2025: opening row + 104 movements, the last running balance equals the opening balance plus the net movements.

## Printing

Checkbox "طباعة كميات فقط" and a print button exist in the .fmx; no RDF name is visible in the evidence and `prints.json` has no entry.
Open question: which report printed the item movements (quantities only / with values)?

## Coverage

- Reproduced: the criteria and their checks, the movements with in / out / balance, the opening balance, the category totals.
- Not reproduced: the reads of `FILE_PASSWORD` for the document screens (system 31 serials 2, 4, 7, 8; system 3 serials 101, 102;
  system 30 serials 2, 4, 5, 6) - presumably the rights to open the selected document from the list (no document link on a
  preview; open question); the print (report unknown).
- Generator gap: RUN on a PROCESS page needs the page insert right.
