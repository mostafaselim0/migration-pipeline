# ST_STORE_LOCATIONS - أرقام الأماكن بالمخازن / Item Locations in Stores

- Registry: system 3 serial 208, menu `CODES_MENU.ITEMS_LOCATIONS`. Legacy `ASCON\ST\FMB\st_store_locations.fmx` (no .fmb; evidence =
  35 embedded SQL statements, texts and GN_FORM_ITEM labels).
- Purpose: the transaction stores (same store data and rules as ST_STORE), the locations (shelves) of each store, and the items placed
  in each location with their order.
- APEX: pages 20170 / 20171, `MASTER_DETAIL`: master `ST_STORE`, details `ST_STORE_LOCATIONS` (الأماكن: `LOCATION_LABEL`, `DESC_A`,
  `DESC_E`) and `ST_ITEM_STORE_LOCATIONS` (أماكن تواجد الأصناف: `ITEM_CODE`, `GROUP_CODE`, `LOCATION_LABEL`, `SERIAL`), both joined on
  `STORE_CODE`. Override `overrides\ST_STORE_LOCATIONS.json`; package `APP_RULES3_ST`; triggers `APP_RULES3_ST_STORE_DEL` (stores) and
  `APP_RULES3_ST_LOCATIONS_BD` (locations).
- Data: 7 transaction stores, `ST_STORE_LOCATIONS` empty, 4 `ST_ITEM_STORE_LOCATIONS` rows (store 101010101001, labels '1' / '2')
  whose locations do not exist - editing them will require creating the locations first (rule below); 3 of them have no order.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| only transaction stores, restricted by the store passwords | block WHERE `STORE_STATUS=1 AND (:1=0 OR STORE_CODE IN (... ST_STORE_PASSWORD ... FLAG=1 ...))` | `where STORE_STATUS = 1 and app_rules3_st.store_allowed(STORE_CODE) = 1` | high |
| store code rules (typed, padded, level, parent exists / without transactions, duplicate: "خطأ فى رقم المخزن", "لا يوجد مخزن رئيسى لهذا الرقم", "تم عمل حركات على المخزن الرئيسى", "يوجد مخزن بنفس الرقم بالملف"), new store = leaf, parent -> classification, stop date | same SQL and texts as ST_STORE.fmb | same `key_expr`, row rule, validation `val_store` and after-save `store_after` as ST_STORE (see `ST_STORE.md`) | high |
| propagation to the sub-stores of accounts 2-4, cost centre and stop flag - **no** `ACCOUNT_NUMBER1` propagation, and the stopped sub-stores get `STOP_DATE` | `UPDATE ST_STORE SET ACCOUNT_NUMBER2/3/4 / COST_CODE ...`, `UPDATE ST_STORE SET STOP_FLAG = 1, STOP_DATE = :b1, STOP_REASON = :b2 || '(المخزن الرئيسى ' ...` (no ACCOUNT_NUMBER1 update in this module) | `store_after` checks `cur_form = 'ST_STORE_LOCATIONS'` | high |
| store delete refused with items / sub-stores; parent back to leaf | same texts and SQL as ST_STORE | `APP_RULES3_ST_STORE_DEL` | high |
| a store with locations cannot be deleted; a location holding items cannot be deleted ("لا يمكن إلغاء سجل رئيسي في وجود سجلات تابعة له" - the Forms master-detail relation) | relation queries `SELECT 1 FROM ST_STORE_LOCATIONS S WHERE S.STORE_CODE = :b1`, `SELECT 1 FROM ST_ITEM_STORE_LOCATIONS WHERE STORE_CODE = :b1 AND LOCATION_LABEL = :b2` | `APP_RULES3_ST_LOCATIONS_BD` -> `location_delete` (page Delete of the store on this screen, or a location with items) (-20185) | high |
| duplicate location label: "هذا الرقم موجود من قبل" | text | primary key `(STORE_CODE, LOCATION_LABEL)` | high |
| item of a location: the item must exist ("هذا الصنف غير موجود بملف الاصناف"); its group is taken from the item | `SELECT ITEM_GROUP_CODE, NAME_E, NAME_A FROM ST_ITEM WHERE ITEM_CODE = :b1` | row rule `item_loc_row` on `ST_ITEM_STORE_LOCATIONS` (group derived when empty; `GROUP_CODE` optional) | high |
| order required: "يجب إدخال الترتيب" | text | `item_loc_row` | high |
| the location must exist in the store: "يجب إدخال رقم المكان" | `SELECT COUNT(1) FROM ST_STORE_LOCATIONS WHERE STORE_CODE = :b1 AND LOCATION_LABEL = :b2` | `item_loc_row` | high |
| total cost of the store "تكلفة كلية" (button "حساب التكلفة الكلية") | `SELECT GROUP_CODE, ITEM_CODE FROM ST_STORE_ITEM WHERE STORE_CODE = :b1` + balance cost | info panel `TOTAL_COST` = `store_total_cost` (computed on page load instead of on a button) | high |

## Tests (rolled back)

C4b on this screen: account 1 not propagated, sub-store stop date set; C9 group derived from item 101010001, unknown item refused,
missing order refused, unknown location refused; C10 a location holding items cannot be deleted, a store with locations cannot be
deleted from the page, an empty location can be deleted from the grid. Store rules: see the ST_STORE tests (C1-C8, shared code).

## Open questions

- The block WHERE ends with `AND ((:3 <> 77) OR ((:4 = 77) AND (STORE_CODE = :5)))`: a caller-supplied mode (77) that restricts the
  screen to one store. The binds are not identifiable from the .fmx (a global / parameter set by another module); dropped. Which module
  opened this screen in mode 77?
- "الكمية الحالية" (current quantity) is a label of this module; which quantity it showed (item balance in the store?) is not visible. Not reproduced.

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Store code read-only after insert and required | `columns.ST_STORE.STORE_CODE` | same store rules as ST_STORE.fmb (`UpdateAllowed="false"`), medium |
| Dealing-type list and status texts | `DEAL_TYPE.static`, `STORE_STATUS.static` | .fmx texts جملة / مفرق / تكلفة, مخزن حركــات / مخزن تصنيـف |
| Account 1-4 and cost-centre lists with the permission filters | `ACCOUNT_NUMBER1..4`, `COST_CODE` `lov` | .fmx SQL `AC_MASTER M2, AC_PASSWORD_MASTER P2`, `AC_COST_CENTERS M2, AC_PASSWORD_COST1 P2` |
| Location list of the store on the item-location lines | `ST_ITEM_STORE_LOCATIONS.LOCATION_LABEL` (`lov`, `cascade: STORE_CODE`) | `SELECT COUNT(1) FROM ST_STORE_LOCATIONS WHERE STORE_CODE = :b1 AND LOCATION_LABEL = :b2` |
| Item and group names per item-location line | `computed.ST_ITEM_STORE_LOCATIONS.ITEM_NAME / GROUP_NAME` | `SELECT NAME_A, NAME_E FROM ST_ITEM ...`, `... FROM ST_ITEM_GROUP ...`, labels |

The second block `ST_ITEM_STORE_LOCATIONS2` (locations of the current item line) is a detail of a detail row; `TABLE#2` does not
help (its link is the item of the selected line, not the store), so it stays not reproduced.

## Coverage

- Reproduced: all rules above (store rules shared with ST_STORE).
- Not reproduced:
  - the second item-location block `ST_ITEM_STORE_LOCATIONS2` (the locations of the current item - the same table seen per item;
    the generator placed the table once);
  - the item list restricted to items not stopped / of the group passwords (the generic item list is used; the row rule validates);
  - the level name (the level number is shown); account / cost-centre / item / group / location names are now shown (wave 3b);
  - the "الكمية الحالية" display and the mode-77 restriction (questions above).
- Row rules become active in `APPX_ST_STORE` / `APPX_ST_ITEM_STORE_LOCATIONS` at the next build; the delete triggers are active now.
