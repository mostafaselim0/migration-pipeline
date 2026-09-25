# ST_STOCK_DEF - تحضير ملف الجرد / Taking Def Balance Screen

- Registry: system 3 serial 80 (no menu entry in `SYS_FILES`). Legacy module `ASCON\ST\FMB\ST_STOCK_DEF.fmx` (no .fmb: evidence is the
  embedded SQL, the texts and the strings of the .fmx).
- APEX: pages 20350 / 20351. Override `overrides\ST_STOCK_DEF.json` makes it `MASTER_DETAIL`: master `ST_STOCK_DEF` (count header per
  date, store and serial), detail `ST_STOCK_DEF_DET` "الأصناف المجرودة" (join `ST_TAKING_DATE`, `STORE_CODE`, `MAST_SERIAL`); store
  permission filter; row rule of the lines; `CODE` shown as "الكود المدخل".
- Package `APP_RULES3_ST`: `stock_def_det_row` (row rule of `ST_STOCK_DEF_DET`, active at the next build).
- Data: `ST_STOCK_DEF` / `ST_STOCK_DEF_DET` empty; `RSD_ST_ITEM_GTIN` 2 980 rows; no lot has `BAR_CODE`; `ST_ITEM_BARCODE` empty.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| Stores: transaction stores, not stopped, of the user's permission group (`ST_STORE_PASSWORD.FLAG = 1`) | ST_STORE LOV SQL and block WHERE `(:1=0 OR STORE_CODE IN (SELECT DISTINCT SP.STORE_CODE FROM ST_STORE_PASSWORD SP WHERE SP.PASSWORD_NUMBER=:2 AND SP.FLAG=1))` | `where` (list filter) | high (filter) / the LOV restriction on new rows is generic |
| Header serial `NVL(MAX(MAST_SERIAL),0)+1` per store and date; line serial `NVL(MAX(ITEM_SERIAL),0)+1` per header | `SELECT NVL(MAX(MAST_SERIAL),0)+1 FROM ST_STOCK_DEF WHERE STORE_CODE AND ST_TAKING_DATE`, `SELECT NVL(MAX(ITEM_SERIAL),0)+1 FROM ST_STOCK_DEF_DET WHERE ST_TAKING_DATE AND STORE_CODE AND MAST_SERIAL` | generated key numbering (max + 1 of the last key column within the other key columns) | high |
| The scanned code is looked up as lot barcode (`ST_ITEM_CONFG.BAR_CODE`), then GTIN (`RSD_ST_ITEM_GTIN`), then item barcode (`ST_ITEM_BARCODE`), then item code; "لا يوجد هذا الباركود" when none; "الكود الدولى متكرر فى أصناف عدة" when several items | the SQL chain `SELECT ITEM_CONFG_ID, GROUP_CODE, ITEM_CODE FROM ST_ITEM_CONFG WHERE BAR_CODE = :b1`, `... WHERE (ITEM_GROUP_CODE, ITEM_CODE) IN (SELECT GROUP_CODE, ITEM_CODE FROM RSD_ST_ITEM_GTIN WHERE GTIN = :b1)`, `SELECT ITEM_CODE, GROUP_CODE FROM (SELECT ... FROM ST_ITEM_BARCODE WHERE ITEM_BARCODE = :b1 UNION SELECT ... FROM ST_ITEM WHERE INTER_CODE = :b1)`, `SELECT ITEM_CODE, ITEM_GROUP_CODE FROM ST_ITEM WHERE ITEM_CODE = :b1`, messages | `stock_def_det_row` (the `ST_ITEM.INTER_CODE` branch is left out: no such column in SMART) | high |
| Group from the item | `SELECT ITEM_GROUP_CODE FROM ST_ITEM WHERE ITEM_CODE = :b1` | `stock_def_det_row` | high |
| Lot by lot number and expiry month, else lot number, else expiry month | `SELECT MAX(ITEM_CONFG_ID) FROM ST_ITEM_CONFG WHERE GROUP_CODE AND ITEM_CODE AND UPPER(LOT_NUMBER) = :b3 AND LAST_DAY(EXPIRE_DATE) = LAST_DAY(:b4)` and the two single-criterion variants | `stock_def_det_row` | high |
| Price of the line = lot unit price | `SELECT UNIT_PRICE FROM ST_ITEM_CONFG WHERE ITEM_CONFG_ID = :b1` | `stock_def_det_row` (`SALES_PRICE` when empty) | high |
| Deleting a header deletes its lines | `DELETE FROM ST_STOCK_DEF_DET WHERE ST_TAKING_DATE AND STORE_CODE AND MAST_SERIAL`, `DELETE FROM ST_STOCK_DEF ...` | master-detail page deletes the lines with the header | high |

## Buttons / files

| Legacy | APEX |
|---|---|
| Load a count file ("Select Taking File", WebUtil `CLIENT_GET_FILE_NAME`, `CLIENT_OLE2` / `READ_EXCEL_CELL`, fields `T_BARCODE`, `T_CONFIG`, `T_QUANTITY`); errors written to `<file>_OUT.TXT` ("; CONFIG NOT EXIST", "; GTIN NOT EXIST", "; International code Exist Many times"); end message "تم الانتهاء من الجرد" / "Upload done" | **cannot reconstruct**: the column layout of the file is not in the evidence (the `file` action parameter would fit once the layout is known) |
| Summary query `SELECT SUM(ACTUAL_QUANTITY) QUANTITY, ITEM_CONFG_ID FROM ST_STOCK_DEF_DET WHERE ST_TAKING_DATE AND STORE_CODE AND ITEM_CONFG_ID IS NOT NULL GROUP BY ITEM_CONFG_ID` (download / `TXT_DNLD`, `WRITE_EXCEL_CELL`) | **cannot reconstruct**: the target (file layout or table) is not visible |
| Print `ST_STOCK_DEF.RDF` (`P_STORE_CODE`, `P_TAKING_DATE` dd-mm-yyyy, `P_MAST_SERIAL`, `COMPANY_CODE`, `LANG`) | report + parameters documented; layout is the main session's job |
| Print "طباعة الأصناف على الشحنات" `ST_TAKING_barcode_cnfg.RDF` (`STOCK_W` store, `DATE_W` dd-mm-yyyy, `COMPANY_CODE`, `LANG`; the screen also has "من مجموعة رئيسية / إلى مجموعة رئيسية" with `SELECT CHR_STRU_START, LENGTH FROM ST_CHART_STRUCTURE WHERE CHR_TYPE = 2 AND CHR_STRU_LEVEL = 1`) | report + parameters documented; how the main-group range reaches the report is not visible |

## Tests (rolled back, `tmp\w3_st\t_rules3_st.py`, 188/188 passed in the final run)

I1 item code scanned: group, item, lot by lot number and price of the lot filled; unknown code refused ("لا يوجد هذا الباركود");
I2 a lot barcode (fixture) resolves to the lot and its item.

## Open questions

- Layout of the count file (column order of barcode / lot / quantity, Excel or text) and what the summary download produces.
- The .fmx also has `SELECT MAX(ITEM_CONFG_ID) FROM ST_ITEM_CONFG WHERE GROUP_CODE = :b1 AND ITEM_CODE = :b2` (latest lot of the item)
  and reads `ST_ITEM.INITIAL_SALES_PRICE` on the GTIN path; when these apply (fallback lot / price without lot?) is not visible, so they
  are not reproduced.
- "خطأ في ادخال تاريخ الجرد": the date check that raises it is not visible.
- `ACTUAL_QUANTITY` vs `QUANTITY` (المجرود / الكمية) and `DIRECTED_STORE`, `COST_PRICE`, `MOH_DISC`: how they are filled.

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Store list: leaf stores, not stopped, of the user's store permissions | `columns.ST_STOCK_DEF.STORE_CODE.lov` | .fmx LOV SQL `FROM ST_STORE WHERE STORE_STATUS=1 AND NVL(STOP_FLAG,0)=0 AND (:GLOBAL.PASSWORD_NUMBER=0 OR ... ST_STORE_PASSWORD ...)` |
| Item name per line | `computed.ST_STOCK_DEF_DET.ITEM_NAME` | identifiers ITEM_NAME / ITEM_NAME_E, RG `name_a ITEM_NAME` |

Tested: the list and the expression run on the build copy (fake row for the empty line table).

## Coverage

- Reproduced: header and line numbering, store permission filter, code resolution (lot barcode / GTIN / item barcode / item code),
  lot by lot number / expiry, lot price, header delete with lines.
- Wave 3b: store list with the legacy filter, item name per line.
- Not reproduced: file upload and download (layout unknown), QR parsing `ST_QR_READ` of the scanned code (RSD, deferred), the two
  reports (documented above), the questions above.
