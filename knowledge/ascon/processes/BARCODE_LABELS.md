# BARCODE_LABELS - طباعة باركود صنف / Barcode Printing Item

- Registry: system 3 serial 540, menu `SYSMEM_MENU.BARCODE_LABELS`. Legacy module `ASCON\ST\FMB\BARCODE_LABELS.fmx` (no .fmb),
  control block `BLOCK2` (no base table).
- Purpose: print barcode stickers for one item lot ("مسلسل النظام").
- APEX: `PROCESS` page 20500 (override `BARCODE_LABELS.json`, replaces the earlier read-only lot grid): parameters store, group, item,
  unit, lot (all required), number of labels (default 1), price (optional); button "تجهيز الملصقات" runs
  `APP_RULES3_ST.prepare_barcode_labels`, which prepares the work table `PRINT_TRNS_BARCODE` exactly as the legacy print button did;
  the preview shows the prepared labels. The label layout (report `ST_BARCODE_LABEL`) is the main session's.
- Schema addition: `PRINT_TRNS_BARCODE (ITEM_SERIAL, ITEM_NAME, BARCODE, ITEM_CODE, SALES_PRICE, USER_CODE)` did not exist in SMART;
  `25_rules3_st.sql` creates it when missing (columns from the RDF query and the form's INSERT).
- Confidence: high for the data prepared, medium for the price rule and the one-row-per-label layout (see questions).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| store list: `ST_STORE` with `STORE_STATUS = 1`, `STOP_FLAG = 0`; group list `ST_ITEM_GROUP`; item list `ST_ITEM` with `STOP_FLAG = 0` and the group password filter; unit list `ST_ITEM_UNIT` + `ST_UNIT`; lot list `ST_ITEM_CONFG` of the item with its balance `GET_BALANCE_CONFG(store, group, item, confg)` | LOV SQL | parameter lists of values | high |
| "يجب إدخال مسلسل النظام أولاً" | message | `prepare_barcode_labels` (lot required) | high |
| "لايوجد صنف للطباعة" | message | lot not of the item, item missing, count <= 0 | high |
| "يوجد أكثر من صنف بهذا الكود" | message on TOO_MANY_ROWS of `SELECT NAME_E, ITEM_GROUP_CODE, PEICE_NO FROM ST_ITEM WHERE ITEM_CODE AND ITEM_GROUP_CODE` | same | high |
| price: `SELECT REDUCTION_PRICE, WIDE_SALE_PRICE, RETAIL_SALE_PRICE FROM ST_ITEM_UNIT ..` and `SELECT DEAL_TYPE FROM ST_STORE`; "خطأ فى سعر الصنف" when none | SQL + message | `label_price`: reduction price when set, else wholesale for `DEAL_TYPE = 1`, else retail (the rule of the sales screens); a typed price wins | medium |
| barcode value: item code or `PEICE_NO` (`COMPANY.CHAR_ITEM_CODE` read) | `SELECT NVL(C.CHAR_ITEM_CODE,0) FROM COMPANY`, `PEICE_NO` selected | `NVL(PEICE_NO, item code)` | medium |
| output for report `ST_BARCODE_LABEL`: `DELETE FROM PRINT_TRNS_BARCODE`, `INSERT INTO PRINT_TRNS_BARCODE (ITEM_NAME, BARCODE, ITEM_CODE, SALES_PRICE, USER_CODE)` | embedded SQL | same, one row per label (`ITEM_SERIAL` 1..count), item English name, user `G_USER_CODE` | medium |

Tested (rolled back, `t_rules3_st.py` L1): lot required; three labels for item 101010001 with the English name, barcode and the store price
63.35 and user 2.

## Printing

- `ST_BARCODE_LABEL.RDF`: no user parameters, `SELECT ITEM_SERIAL, ITEM_NAME, BARCODE, ITEM_CODE, SALES_PRICE FROM PRINT_TRNS_BARCODE`.
- Alternative legacy output: an Eltron EPL2 stream written to a client file (`N`, `Q160,24`, `A20,10,..,"WASFAT Pharmacies"` - header of
  another customer, `A20,30,..,"PRICE <price> SR"`, `A20,50,..,"<item name>"`, barcode `B20,70,0,1,2,2,50,B,"<code>"`, `P<count>`).
  Not reproduced (thermal printer output from the browser is out of scope; printer selection excluded by the wave-3 goal).

## Open questions

- Price column by `ST_STORE.DEAL_TYPE`: the mapping of DEAL_TYPE to reduction / wholesale / retail is not visible in the .fmx; APEX uses
  the sales-screen rule.
- Barcode = `PEICE_NO` or item code depending on `COMPANY.CHAR_ITEM_CODE`: the exact condition is not visible; APEX prints `PEICE_NO`
  when present.
- One `PRINT_TRNS_BARCODE` row per sticker (APEX) vs. one row with the count used by `P<count>` (EPL): confirm with the report.
- `DELETE FROM PRINT_TRNS_BARCODE` without a user filter (legacy): two users preparing labels at the same time overwrite each other;
  suggestion: filter by `USER_CODE`.

## Coverage

- Reproduced: inputs, lists, checks, price and barcode choice, preparation of the report table.
- Not reproduced: the EPL thermal stream and the "عنوان الملصق" (`COMPANY_NAME`) header text of that stream; expiry date on the sticker
  (only in the EPL variant's inputs); the report layout itself (main session).
