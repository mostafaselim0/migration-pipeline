# ST_ITEM - أرقام الأصناف / Item Numbers

- Registry: system 3 serial 212 (also system 30 serial 15, system 31 serial 17), menu `CODES_MENU.ST_ITEM`. Legacy module
  `ST\FMB\ST_ITEM.fmb` (source available: triggers, program units, record groups; `ST_ITEM_fmb.xml` for item properties).
- APEX: pages 20190 / 20191 (+ print page 20192), `MASTER_DETAIL` generated from the .fmb: master `ST_ITEM`, details `ST_ITEM_PIECES`,
  `ST_ITEM_UNIT`, `ST_ITEM_STORE_LOCATIONS`, `ST_SUB_ITEM`, `ST_STORE_ITEM`, `ST_ITEM_BARCODE`, `RSD_ST_ITEM_GTIN`. Override
  `overrides\ST_ITEM.json` (pattern AUTO) adds the rules below, the group-permission filter and the balance / cost panel.
- Package `APP_RULES3_ST`: `next_item_code`, `item_row`, `val_item`, `item_after`, `item_delete`, `item_info`, `unit_item_row`,
  `unit_item_delete`, `barcode_row`, `sub_item_row`, `item_group`, `group_allowed`; delete hooks `APP_RULES3_ST_ITEM_BD` (ST_ITEM) and
  `APP_RULES3_ST_ITEM_UNIT_BD` (ST_ITEM_UNIT). The `ST_ITEM` / `ST_ITEM_UNIT` row rules are the same strings in ST_STANDS, so both
  screens share one `APPX_ST_ITEM` / `APPX_ST_ITEM_UNIT` trigger; screen-specific parts check `app_rules_st.cur_form`. Row rules and
  key rules become active at the next build (build.py was not run).
- Data: 4 035 items (948 with VAT), 1 unit, 1 current tax type (`TX_TAXES_TYPES` code 2 from 2025-01-01), `COMPANY.CHAR_ITEM_CODE` = 1,
  `ST_BASIC.AUTO_ITEM_SER` = 0, `MIN_PROFIT` = 0; `ST_ITEM_PIECES`, `ST_SUB_ITEM`, `ST_ITEM_BARCODE`, `AR_ST_ITEMS_DISC`,
  `ST_STORE_UNIT`, `ST_STORE_ITEM_UNIT` empty, `ST_CUST_ITEMS` 2 rows.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| Item code = `NVL(MAX(ITEM_CODE),0)+1` within the group; first item of a group `SUBSTR(group,1,5) || '0001'` | PRE-INSERT and ITEM_GROUP_CODE WHEN-VALIDATE-ITEM (the customer-specific variants are commented out) | `key_expr` `next_item_code(:new.item_group_code)` | high |
| Item code not typed (`AUTO_ITEM_SER` = 0 disables it) | WHEN-NEW-FORM-INSTANCE `SET_ITEM_PROPERTY('ST_ITEM.ITEM_CODE',ENABLED,...)`, fmb `Enabled="false"` | `readonly` + `optional` ITEM_CODE (static, see questions) | high |
| Duplicate code refused (alert ITEM_CODE_REPT) | PRE-INSERT, ITEM_CODE WVI | validation `val_item` "رقم الصنف مكرر" + primary key | high |
| Numeric item code when `COMPANY.CHAR_ITEM_CODE` = 0: "خطأ في رقم الصنف !!!" | ITEM_CODE WVI | `item_row` (insert) | high (inactive in the data) |
| Group: a transaction group (`GROUP_STATUS = 1`) allowed for the user's permission group | LOV ITEM_GROUP_RG | `val_item` "لا يوجد سجل مناظر فى الجداول الأخرى." | high |
| Arabic name required | fmb `NAME_A Required="true"` | `val_item` "يجب إدخال الإسم العربى" (CREATE) | high |
| Items of a stopped group are stopped | SET_STOP_FLAG (PRE-INSERT / PRE-UPDATE) | `item_row` | high |
| Not stopped -> stop reason cleared | PRE-UPDATE | `item_row` | high |
| Alternative number / Lemon code / SMC code unique: "الرقم البديل تم إدخاله من قبل", "رقم ليمون تم إدخاله من قبل", "الرقم تم إدخاله من قبل" | PEICE_NO / LEMON_CODE / SMC_CODE WVI | `val_item` (own row excluded) | high |
| Max limit not below min limit (alert MAX_LESS_MIN) | MIN_LIMIT / MAX_LIMIT WVI | `item_row` "الحد الأدنى أكبر من الحد الأقصى" | high |
| M.O.H flag makes the M.O.H discount required | MOH_FLAG WVI (`SET_ITEM_PROPERTY(...REQUIRED...)`) | `item_row` "يجب إدخال نسبة خصم وزارة الصحة" | high |
| VAT 0 or 15: "خطأ بالقيمة" | VAT_VALUE WVI | `item_row` (only when the value changes) | high |
| VAT copied to `TX_TAXES_ITEMS` for every tax type of the latest start date (insert, or update on duplicate) | PRE-UPDATE `FOR REC IN (SELECT TAX_CODE ... FROM TX_TAXES_TYPES WHERE START_DATE = (SELECT MAX(START_DATE) ...))` | after-save `item_after` (SAVE) | high |
| Save needs a basic unit: "لا يمكن الحفظ بدون وحدة اساسية"; more than one refused | KEY-COMMIT loop; BASIC_UNIT WHEN-CHECKBOX-CHANGED (keeps one) | `item_after` (also "يوجد أكثر من وحدة أساسية إستبعد الوحدة الأساسية أولاُ") | high |
| Basic unit factor = 1 (alert CONV_FACT_ALERT) | FACTOR WVI, BASIC_UNIT triggers | `unit_item_row` "معامل التحويل للوحدة الأساسية يجب أن يساوى واحد" | high |
| No two units with the same factor: "معامل تحويل مكرر" | FACTOR WVI, ST_ITEM_UNIT PRE-INSERT / PRE-UPDATE / POST-UPDATE | `item_after` (whole item checked after save; a row trigger cannot read its own table) | high |
| Duplicate unit: "وحدة مكررة" | ST_ITEM_UNIT PRE-INSERT | primary key | high |
| A unit used in transactions keeps its factor and basic flag and cannot be deleted; the basic unit of an item with transactions cannot be deleted or changed | WHEN-NEW-RECORD-INSTANCE (`DELETE_ALLOWED`, `UPDATE_ALLOWED` off), KEY-DELREC (alerts BU_IN_TRANS, U_IN_TRNS) | `unit_item_row` (update), `unit_item_delete` (delete hook) | high |
| Deleting a unit removes its class discounts, store units, store unit prices and customer items | ST_ITEM_UNIT PRE-DELETE | `unit_item_delete` | high |
| Delete refused when the item has lines in `ST_TRNS_DET`, `ST_DELIVERY_DET` or `ST_SALES_ORDER_DET`: "هذا الصنف تم عمل حركات عليه ولا يمكن حذفة" | ST_ITEM KEY-DELREC | `item_delete` (hook on ST_ITEM) and `unit_item_delete` with request DELETE (the page deletes the units first) | high |
| Deleting an item removes its lots, locations, store rows, pieces, alternative items, GTINs and barcodes | KEY-DELREC (`DELETE FROM ST_ITEM_CONFG`), PRE-DELETE | `item_delete` | high |
| A barcode belongs to one item: "Barcode Exist item code <item>" | CHECK_BARCODE (ITEM_BARCODE WVI) | row rule `barcode_row` (the item's own row excluded; same item twice = primary key) | high |
| Alternative item must exist and differ from the item: "رقم الصنف البديل لا يمكن تكراره"; its group comes from the item code | ST_SUB_ITEM PRE-INSERT, LOV ITEM_CODE | `key_expr` SUB_ITEM_GROUP_CODE = `item_group(:new.sub_item_code)`, row rule `sub_item_row` | high |
| Pieces tab shows only rows with `NVL(DELETE_FLAG,0) = 0` | block WHERE of ST_ITEM_PIECES | `key_expr` DELETE_FLAG = 0 on insert (generator has no detail WHERE) | medium |
| List restricted to transaction groups of the user's permission group | ST_ITEM block WHERE (`ST_GROUP_PASSWORD`, `GROUP_STATUS = 1`, `FLAG = 1`) | `where` `group_allowed(ITEM_GROUP_CODE) = 1` | high |
| Balance, whole cost, average cost, cost with other costs (`MIN_PROFIT` %), last purchase price, balance per store | GET_SUM_BAL_COST, GET_DATA (`GET_BALANCE_COST` per `ST_STORE_ITEM` row), `GET_LAST_PURCH_PRICE` | `info` BAL, COST, AVG, MIN_PROFIT, LAST_PUR, STORES (`item_info`) | high |

## Buttons

| Legacy | APEX |
|---|---|
| CALC_COST / GET_DATA | info panel (values refresh on every load) |
| INSERT_CLASSES (fill the class discounts `AR_ST_ITEMS_DISC` of the current unit from `AR_ST_ITEM_CLASSES`, price = unit retail price, discount 1 = M.O.H discount) | **cannot reconstruct**: `AR_ST_ITEMS_DISC` is a detail of `ST_ITEM_UNIT` (third level); the generator places one detail level only |
| PUSH_BUTTON210 "تم إدراج المخازن" (store units of a unit for the stores under a parent store) | not reproduced: `ST_STORE_UNIT` tab is shown only for customer `SDI` (WHEN-NEW-FORM-INSTANCE) - not this customer |
| Barcode search window (CONFG_SEARCH: barcode / GTIN / QR) | not reproduced: it queries `INTER_CODE`, `NUPCO_ITEM_CODE`, `OLD_PROD_CODE`, which do not exist in SMART; QR / GTIN is RSD (deferred); the list's search covers the codes |
| IMAGE_BUTTON (WebUtil photo) | `PHOTO_PATH` shown as text; no upload |
| Barcode / GTIN tabs ("يجب حفظ السجل اولا") | tabs are regions of the saved item |
| Print buttons | see Printing |

## Printing (report and parameters; layout is the main session's job)

- `CTRL.PRINT_BTN2` -> `st_item_card_basic_qty_mod.RDF` with `FROM_ITEM_GROUP_CODE` = `TO_ITEM_GROUP_CODE` = current group,
  `FROM_ITEM_CODE` = `TO_ITEM_CODE` = current item, `LANG`; `PARAMFORM=NO`, PDF via the report server.
- `CTRL.PRINT_BTN` -> `ST_STOCK_CONTROL_COMP.RDF` with the same four parameters + `P_COMPANY_CODE` (= `:GLOBAL.COMPANY_CODE`), `LANG`.

## Tests (rolled back, `tmp\w3_st\t_rules3_st.py`, 188/188 passed in the final run)

E1 next code 101013085 / 301040003 (first code of a new group `...0001`: D2 in ST_GROUP); E2 stopped group, stop reason cleared,
VAT 0/15 (only on change), max < min, M.O.H discount, numeric code with `CHAR_ITEM_CODE` = 0; E3 group must be a transaction group,
Arabic name, duplicate alternative / Lemon / SMC codes, own codes accepted; E4 one basic unit, VAT copied to `TX_TAXES_ITEMS` (tax 2),
two basic units / duplicate factor / no basic unit refused; E5 basic factor 1, locked unit of an item in transactions; E6 unit delete
(grid) and item delete (page and direct) refused with transactions; E7 barcode of another item; E8 alternative item; E9 info values
(balance 4,635, average 6.2060, balance per store). Positive delete case: a fixture item without transactions (item, basic unit, lot,
store row) deleted through the page delete - its lots and store rows are removed.

## Open questions

- (wave 3b) `ITEM_GROUP_CODE` (`UpdateAllowed = No`) is now read-only after insert.
- `ITEM_CODE` is made read-only statically because `AUTO_ITEM_SER` = 0; with `AUTO_ITEM_SER` = 1 the legacy let the user type it.
- The legacy wrote `TX_TAXES_ITEMS` in PRE-UPDATE (existing items only); APEX does it after every save, i.e. also for new items.
  Confirm this is acceptable (it avoids a missing tax row for new items).
- (wave 3b) `CLASS_CODE`, `ACTIVE_MATERIAL_CODE` and the other `Required` items are required; `VAT_VALUE` / `INITIAL_SALES_PRICE`
  only for new items (imported items without VAT stay editable) - confirm.
- The legacy `IN_TRANS` flag (item has balance rows) is approximated by "item has `ST_TRNS_DET` lines".

## Wave 3b (new generator keys)

Evidence: `ST\FMB\ST_ITEM_fmb.xml` (item properties, record groups, program unit FILL_LIST), data of the build copy.

| Change | Key | Evidence |
|---|---|---|
| `ITEM_STATUS` list نشط 1 / غير نشط 2 (default 1) | `columns.ST_ITEM.ITEM_STATUS.static` | list item ITEM_STATUS_DUMMY, FILL_LIST `ADD_LIST_ELEMENT` (Active / Inactive), InitializeValue 1 |
| `ITEM_TYPE` shown as "نوع الصنف" with the list وصفية 1 / غير وصفية 2 (default 1) | `columns.ST_ITEM.ITEM_TYPE` (static, hidden false, label) | list item ITEM_TYPE_DUMMY, FILL_LIST (Prescriped / Non-Prescriped), GN_FORM_ITEM label |
| Group: read-only after insert; list = transaction groups (`GROUP_STATUS = 1`) allowed for the user | `ITEM_GROUP_CODE` `readonly_after_insert`, `lov` | `UpdateAllowed="false"`; ITEM_GROUP_RG |
| Class list from `ST_ITEM_CLASSES` (was the fixed-asset classes `AS_CLASS`) | `CLASS_CODE.lov` | LOV CLASS: `SELECT CLASS_CODE, DESC_A, DESC_E FROM ST_ITEM_CLASSES` |
| Country list from `ST_ORG_COUNTRY` (was `Z_COUNTRY`) | `COUNTRY_CODE.lov` (returns the code as text, the column is VARCHAR2) | COUNTRY_RG |
| Active-material list from `ST_ACTIVE_MATERIAL` (was none) | `ACTIVE_MATERIAL_CODE.lov` | ACTIVE_MATERIAL_RG |
| Required: Arabic and English name, GTIN (`MODEL_NO`), supplier, class, dosage form, active material, HS code | `columns.*.required` | `Required="true"` in the .fmb; all 4 035 items have these values |
| VAT % and initial sales price required **for a new item only** ("يجب إدخال نسبة الضريبة" / "يجب إدخال سعر البيع المبدئي", new texts; the Forms message was the generic FRM-40202) | validation (CREATE) | `Required="true"`, but 3 087 / 132 imported items have none: Forms enforced required items on new records only |
| Defaults: M.O.H flag 1, stop flag 0 | `default` | `InitializeValue` 1 / 0 |
| Unit code of a saved unit line read-only (factor stays editable, the row rule locks units used in transactions) | `ST_ITEM_UNIT.UNIT_CODE.readonly_after_insert` | `UNIT_CODE UpdateAllowed="false"`; FACTOR is re-enabled by WHEN-NEW-RECORD-INSTANCE |
| Location list of the line's store | `ST_ITEM_STORE_LOCATIONS.LOCATION_LABEL` (`lov`, `cascade: STORE_CODE`) | STAND_REG `... WHERE STORE_CODE = :st_item_store_locations.store_code` |
| Stand description per location line | `computed.ST_ITEM_STORE_LOCATIONS.STAND_NAME` | display item STAND_NAME "وصف الاستاند" |
| Alternative item: list of items, read-only after insert, item and group names | `ST_SUB_ITEM.SUB_ITEM_CODE` (`lov`, `readonly_after_insert`), `computed` SUB_ITEM_NAME / SUB_GROUP_NAME | `SUB_ITEM_CODE UpdateAllowed="false"`, LOV ITEM_CODE_RG, display items |
| Balance, whole cost and average cost per store row | `computed.ST_STORE_ITEM.CURRENT_BAL / CURRENT_COST / AVG_COST` (`GET_BALANCE` / `GET_COST` / `GET_UNIT_COST`) | GET_DATA: `GET_BALANCE_COST(... store, group, item)` per `ST_STORE_ITEM` row; labels |
| Pieces tab: no insert / update (delete kept), rows with `NVL(DELETE_FLAG,0) = 0` only | `blocks.ST_ITEM_PIECES` (`insert`, `update`, `where`) | `PIECE_NO` / `PIECE_DESC` `InsertAllowed` and `UpdateAllowed` false; block WHERE |

Tested on the build copy: every list query and computed expression runs (`tmp\w3b_st\sqlcheck.py`, fake-row evaluation for the empty
`ST_SUB_ITEM`); the new-item validation returns the two texts and null when both values are given (`plsqlcheck.py`).
Not changed: the English labels of `IN_PACK`, `SHELF_LIFE`, `INITIAL_SALES_PRICE`, `HS_CODE`, `ITEM_BARCODE`, `GTIN` (no legacy text:
Forms2XML dropped the Arabic boilerplate, GN_FORM_ITEM has no row).

## Coverage

- Reproduced: numbering, all item checks, stop flag from the group, VAT to tax table, unit rules (basic unit, factors, locks, deletes
  and their cascades), item delete checks and cascades, barcode and alternative-item checks, permission filter, balance / cost panel.
- Not reproduced (with reason):
  - INSERT_CLASSES, class discounts, customer items, store units / store unit prices (third-level blocks; store units are `SDI` only);
  - ST_ITEM_UNIT PRE-INSERT licence check (`CUSTOMER_ACCOUNT_BALANCE` random test) - Forms licence mechanics;
  - POST-UPDATE `CHANGE_BASIC_QTY_TRN` (recomputes `BASIC_QTY` of the item's lines when the basic flag moves): units used in
    transactions cannot change factor, so the recomputation gives the same values;
  - "سعر الجملة أكبر من سعر التجزئة" (information only, level 0) - no warning mechanism for grid rows;
  - ST_ITEM POST-INSERT (create an empty lot) - customer `SDI` only;
  - PRE-DELETE deletion of lines of deleted documents in `ST_TRNS_DET` - dead code: KEY-DELREC refuses the delete whenever such lines
    exist;
  - GTIN length check "GTIN MUST BE 14 CHARACTER" and QR parsing - RSD (deferred);
  - tree / code-composition helper (`GROUP_PRE_CODE` = 0), barcode search window (columns missing in SMART), photo upload.
- Wave 3b reproduced: legacy lists (status, type, group, class, country, active material, locations, alternative items), required
  items, read-only-after-insert group / unit / alternative item, per-row names and store balances / costs, the pieces tab flags and filter.
- Remaining generator limits: one detail level only; no legacy label text for `ACTIVE_MATERIAL_CODE`, `IN_PACK`, `SHELF_LIFE`,
  `INITIAL_SALES_PRICE`, `HS_CODE`, `ST_ITEM_BARCODE.ITEM_BARCODE`, `RSD_ST_ITEM_GTIN.GTIN` (English column names shown).

Update 2026-09-25: INSERT_CLASSES "إدراج الفئات" is reproduced: a fill button on the class discounts of the selected unit (price = the unit's RETAIL_SALE_PRICE, discount 1 = ST_ITEM.MOH_DISC, classes not yet on the item); the user completes and saves.
