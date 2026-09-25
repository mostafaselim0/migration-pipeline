# ST_CHANG_CONFG_SALES_PRICE - شاشة تغييرأسعار شحنة / Change Lot Price Screen

- Registry: system 3 serial 4, menu `FILES_MENU.ST_CHANGE_CONFG_PRICE`. Legacy module `ST\FMB\ST_chang_confg_SALES_PRICE.fmb`
  (source available; item properties checked in `ST_chang_confg_SALES_PRICE_fmb.xml`).
- APEX: page 20100, `GRID` on `ST_ITEM_CONFG` (lots), update only. Override `overrides\ST_CHANG_CONFG_SALES_PRICE.json` (AUTO): row
  rule on update, read-only item / group / lot id / unit price.
- Package `APP_RULES3_ST`: `confg_price_row` (acts only when `app_rules_st.cur_form` = ST_CHANG_CONFG_SALES_PRICE, because
  `APPX_ST_ITEM_CONFG` is shared with every screen that writes lots). Active at the next build.
- Data: 2 671 lots, none with `BAR_CODE`; 5 users have `USERS.CHANGE_CONFG_SALES_PRICE = 1`.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| Lots are edited, not created: lot number, expiry date and discount are the editable columns | fmb: `LOT_NUMBER`, `EXPIRE_DATE`, `DISC_RATIO` `UpdateAllowed="true" InsertAllowed="false"` | grid with update only | high |
| The lot unit price is not updatable | fmb `UNIT_PRICE UpdateAllowed="false" InsertAllowed="false"` | `readonly` UNIT_PRICE + row rule "لا يمكن تعديل سعر الوحدة للشحنة من هذه الشاشة" (**new text**, the Forms item simply refused input) | high |
| Discount (and price) only for users with `USERS.CHANGE_CONFG_SALES_PRICE = 1` | WHEN-NEW-FORM-INSTANCE `select nvl(CHANGE_CONFG_SALES_PRICE,0) ... if var = 0 then set_item_property('UNIT_price' / 'DISC_RATIO', enabled, property_false)` | row rule: a changed `DISC_RATIO` without the right -> "ليس لك صلاحية تعديل خصم الشحنة" (**new text**) | high |
| Insert / delete / update per the user's screen rights | WHEN-NEW-FORM-INSTANCE (`:global.insert_flag` ...) | APEX page authorisation (generic) | high |
| Lot selection: store, supplier, main group (`SUBSTR(GROUP_CODE,1,2)`), item, expiry range, "load items with zero balance" | GET_ITEM builds the block WHERE | grid search / filters (see Coverage) | high |
| Balance of the lot in the chosen store `GET_BALANCE_CONFG(store, group, item, lot)`; item name `NVL(NAME_E, NAME_A)` | POST-QUERY, LKP_ITEM | not shown (see Coverage) | high |

## Printing (report and parameters; layout is the main session's job)

- `CTRL.PRINT_BTN` -> `ST_STORE_ITEM_EXPIRE.RDF` with `P_STORE_CODE`, `FROM_EXPIRY_DATE` / `TO_EXPIRY_DATE` (`DD-MM-YYYY`),
  `P_GROUP_CODE`, `P_ITEM_CODE`, `P_SUPP_CODE`, `PASSWORD_NUMBER`, `P_ZERO_BAL`, `COMP_CODE`, `LANG` (PDF via the report server).
  The button is `Visible="false"` in the .fmb, so users could not start it from this screen.

## Tests (rolled back, `tmp\w3_st\t_rules3_st.py`, 188/188 passed in the final run)

H1 unit price change refused; discount change allowed for user 2 (right = 1) and refused for user 1 (right = 0); the rule is silent on
another page (ST_ITEM).

## Open questions

- The legacy filter "store" is `ITEM_CONFG_ID IN (SELECT ITEM_CONFG_ID FROM ST_STORE_ITEM WHERE store_code = :store ...)`, but
  `ST_STORE_ITEM` has no `ITEM_CONFG_ID`: the name resolves to the outer lot, so the filter only checks that the store has any item.
  With "zero balance" unticked and no store the generated `GET_BALANCE_CONFG(,GROUP_CODE, ...)` is invalid SQL. Should APEX filter the
  lots by balance in the chosen store (the evident intent)?
- The legacy `DEL_BTN` let users with the delete right delete a lot; the APEX grid offers no delete (lots used in lines are protected by
  the foreign keys anyway). Confirm.

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Item name per lot row "إسم الصنف" = `NVL(NAME_E, NAME_A)` | `computed.ST_ITEM_CONFG.ITEM_NAME` | program unit LKP_ITEM (POST-QUERY) |

Tested: the expression runs on the build copy (`select ... from st_item_confg t where rownum < 3`). The block flags (insert and delete
off, update on) already came from the .fmb.

Still not reproduced: the lot balance `BAL` = `GET_BALANCE_CONFG(:ST_STORE.STORE_CODE, ...)` needs the store chosen in the legacy
filter block (without a store the function returns 0 - checked); a grid page has no filter items, so a per-row balance cannot be
computed faithfully. `COST_CALC` is not on a canvas (never shown).

## Coverage

- Reproduced: update-only lot grid, read-only unit price, discount right, read-only keys.
- Not reproduced:
  - the page filter items (store / supplier / main group / expiry range / zero balance) and the lot balance `BAL` in the chosen store:
    a grid page has no filter items, and the balance needs the store (wave 3b); the grid's own search and filters cover the visible
    columns; the item name per row is shown (wave 3b computed column);
  - LOT_NUMBER KEY-HELP alert (supplier / unit price / discount of the lot) - display only;
  - hidden, never-finished "automatic settlement" items (`OUT_TRNS_TYPE_CODE`, `IN_TRNS_TYPE_CODE`, `DOC_NO`, `TRNS_DATE`, `QTY`,
    `CHK`, SELECT_ALL / DESELECT_ALL all `Visible="false"`; PUSH_BUTTON88 / 89 of size 0 without triggers) - dead code;
  - `CTRL.TRANSFER` (language toggle) - Forms mechanics.
