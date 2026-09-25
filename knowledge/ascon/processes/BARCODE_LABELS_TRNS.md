# BARCODE_LABELS_TRNS - طباعة الباركود للحركات / Barcode Print Transaction

- Registry: system 3 serial 550, menu `SYSTEM_MENU.ITEM286`. Legacy module `ASCON\ST\FMB\BARCODE_LABELS_TRNS.fmx` (no .fmb),
  control block `BLOCK2`.
- Purpose: barcode stickers for the lines of a stock transaction (typically a purchase receipt).
- APEX: `PROCESS` page 20510 (override `BARCODE_LABELS_TRNS.json`, replaces the earlier read-only transaction view): parameters
  transaction type and serial (required), from / to item, quantity; button "تجهيز الملصقات" runs `APP_RULES3_ST.prepare_barcode_trns`,
  which fills the work table `PRINT_TRNS_BARCODE` as the legacy print button did; the preview shows the prepared labels. Label layout
  (report `ST_BARCODE_TRNS`) is the main session's. `PRINT_TRNS_BARCODE` is created by `25_rules3_st.sql` (missing in SMART, see
  BARCODE_LABELS.md).
- Confidence: high.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| transaction type list (all types); serial list "قائمة بحركات الإذن": `SELECT TRNS_SERIAL, DESC_A, DESC_E, TO_CHAR(TRNS_DATE,'dd-mm-yyyy') FROM ST_TRNS_MAST WHERE TRNS_TYPE_CODE = :type ORDER BY TRNS_DATE, DATE_SERIAL` | LOV SQL | type list of values; serial typed (the generator cannot make a list depending on another parameter) | high |
| lines: `SELECT GROUP_CODE, ITEM_CODE, ITEM_SERIAL, NVL(:qty, NVL(QUANTITY,0) + NVL(BONUS,0)) QTY, UNIT_CODE FROM ST_TRNS_DET WHERE TRNS_TYPE_CODE AND TRNS_SERIAL AND (ITEM_CODE >= :from OR :from IS NULL) AND (ITEM_CODE <= :to OR :to IS NULL) ORDER BY ITEM_CODE` | embedded SQL | `prepare_barcode_trns` | high |
| name `SELECT NAME_A FROM ST_ITEM WHERE ITEM_CODE, ITEM_GROUP_CODE`; price `SELECT RETAIL_SALE_PRICE FROM ST_ITEM_UNIT WHERE GROUP_CODE, ITEM_CODE, UNIT_CODE` | embedded SQL | same | high |
| `INSERT INTO PRINT_TRNS_BARCODE (ITEM_SERIAL, ITEM_NAME, BARCODE, ITEM_CODE, SALES_PRICE) VALUES (:serial, :name, '*' || :code || '*', :code, :price)` - one sticker per unit (quantity + bonus) or the typed quantity | embedded SQL | same, one row per sticker, plus `USER_CODE`; the table is emptied first | high / medium (rows per sticker) |
| "لايوجد صنف للطباعة" | message | nothing to print | high |

Tested (rolled back, `t_rules3_st.py` L2): transaction 10803/9 (2 lines, 6 units) gives 6 labels with barcode `*code*`; with a fixed
quantity 1, one label per line; an unknown serial gives "لايوجد صنف للطباعة".

## Printing

`ST_BARCODE_TRNS.RDF` (reads `PRINT_TRNS_BARCODE`; declares V_ITEM_CODE, V_ITEM_CONFG_ID as user parameters) or the same Eltron EPL2
stream as BARCODE_LABELS (`P<qty>`, header "WASFAT Pharmacies" of another customer), sent with a timer delay. EPL not reproduced
(thermal printer output / printer selection out of scope).

## Coverage

- Reproduced: inputs, item range, quantity override, preparation of the report table with name, `*code*` barcode and retail price.
- Not reproduced: the serial list of values depending on the type (typed instead); the EPL stream; the report layout (main session).
- Open questions: one row per sticker vs. one row per line with a count (report to confirm); global `DELETE FROM PRINT_TRNS_BARCODE`
  shared by all users (suggestion: filter by `USER_CODE`).
