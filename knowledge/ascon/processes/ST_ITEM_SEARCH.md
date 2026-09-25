# ST_ITEM_SEARCH - شاشة بحث عن صنف / Item Search

- Registry: system 3 serial 214. Legacy module: `ASCON\ST\FMB\ST_ITEM_SEARCH.fmx` (no .fmb).
- Legacy screen: block `ST_ITEM` in query mode with a search value, "محدد البحث" (اسم الصنف / رقم الصنف / رقم المجموعة) and
  "طريقة البحث" (يحتوي على / يبدأ بـ / ينتهي بـ / يساوى), optional group; per item its units (`ST_ITEM_UNIT`: unit, factor,
  retail price, basic flag), its stores (`ST_STORE_ITEM` with store balance and store sales, total "الكمية في المخازن كلها") and
  its locations (`ST_ITEM_STORE_LOCATIONS`).
- APEX: `PROCESS` page 20380 (override `ST_ITEM_SEARCH.json`), button "بحث"; procedure `APP_RULES3_ST.show_item_search`
  (checks), search condition `APP_RULES3_ST.item_search_match`. The preview has one row per item and store with the item data.
- Confidence: high for the search and the balances, medium for the codes of the two lists (UI-defined values).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| search criterion 1 item name (Arabic or English) / 2 item code / 3 group code; type 1 contains / 2 starts with / 3 ends with / 4 equals | list texts "اسم الصنف / رقم الصنف / رقم المجموعة", "يحتوي على / يبدأ بـ / ينتهي بـ / يساوى" | `item_search_match` (case-insensitive LIKE) | medium (list values not visible) |
| group filter: items under the chosen group = same code prefix up to the end of the group's level | `SELECT GROUP_LEVEL FROM ST_ITEM_GROUP WHERE ITEM_GROUP_CODE`, `SELECT CHR_STRU_END FROM ST_CHART_STRUCTURE WHERE CHR_TYPE = 2 AND CHR_STRU_LEVEL` | `item_search_match(.., p_filter_group)` | high |
| groups list: `ST_ITEM_GROUP WHERE STOP_FLAG <> 1` | LOV SQL | parameter list of values | high |
| store balance / store sales per store: `SUM(DECODE(EFFECT,1,1,2,-1,3,-1,4,1,5,-1,6,1) * BASIC_QTY)`, `SUM(DECODE(TRNS_TYPE,2,1,0) * BASIC_QTY)`, not deleted, `EFFECT <> 7`, grouped by store / group / item | embedded SQL (twice) | CTE `bal` of the preview | high |
| total quantity in all stores | label "الكمية في المخازن كلها" / "الإجمالى" | analytic sum per item | high |
| basic unit name and retail price (`ST_ITEM_UNIT.BASIC_UNIT = 1`) | `SELECT RETAIL_SALE_PRICE FROM ST_ITEM_UNIT WHERE .. BASIC_UNIT = 1 ..` | preview columns | high |
| item location `SELECT A.LOCATION_LABEL FROM ST_ITEM_STORE_LOCATIONS A, ST_STORE_LOCATIONS B WHERE .. ROWNUM = 1` | embedded SQL | preview column رقم الموقع | high |

Tested (rolled back, `t_rules3_st.py` J5, J6): name contains, code starts with, code equals (no match), group prefix filter;
preview for code starting with 1010100 (99 rows, all matching) and the total balance equals the sum of the store balances.

## Printing

The form has a print button; `ST_ITEM_SEARCH.RDF` (params from_date, to_date, COMP_CODE, LANG) reads the work table `ST_ITEM_SEARCH`
(sales, coverage, purchase-order columns; 0 rows here). No statement of the form or of the database fills that table, so the print
cannot be reconstructed. Open question: which process filled `ST_ITEM_SEARCH` and did this screen print it?

## Coverage

- Reproduced: the search, the group filter, store balances / sales, total, basic unit, retail price, location.
- Not reproduced:
  - the full unit list per item (factor and price of every unit) - shown in the item screen `ST_ITEM`; only the basic unit here;
  - adding a location to an item from this screen (`SELECT NVL(MAX(SERIAL),0)+1 FROM ST_ITEM_STORE_LOCATIONS WHERE LOCATION_LABEL`):
    item locations are kept on `ST_STORE_LOCATIONS` (same table, rules `item_loc_row`, order typed there);
  - book-shop fields (المؤلف / التخصص / المترجم / إسم الكتاب, lists on `ST_AUTHOR`, `ST_SPECIALIZATION`): the tables do not exist in SMART
    (another customer's version);
  - a second list text containing "اسم المورد / رقم المورد" (supplier criteria): not on the labelled items; open question whether a
    supplier search existed;
  - the unit messages "الكمية لا يمكن أن تقل عن صفر", "معامل التحويل للوحدة الأساسية يجب أن يساوى واحد" (template of ST_ITEM; the units
    are not edited here);
  - the print (see above).
- Generator gap: RUN on a PROCESS page needs the page insert right.
