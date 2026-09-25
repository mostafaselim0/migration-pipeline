# ST_STORE_ITEM - عرض أرصدة المخازن / Stores Balances Display

- Registry: system 3 serial 108 (`FILES_MENU.ST_STORE_ITEM`, order 1004); also system 30 serial 8 and system 31 serial 11.
- Legacy module: `ASCON\ST\FMB\ST_STORE_ITEM.fmx` (no .fmb). Blocks `ST_STORE` (master, transaction stores) -> `ST_STORE_ITEM`
  (items of the store) -> `ST_ITEM_CONFG` (lots of the item), control block with query / save / print buttons.
- APEX: `PROCESS` page 20030 (override `ST_STORE_ITEM.json`): parameters store (required), group, item and the three store limits;
  the preview (interactive report) lists the items of the store and, when an item is chosen, its lots. Procedure
  `APP_RULES3_ST.show_store_items`, pipelined function `APP_RULES3_ST.store_items` (package `app\db\25_rules3_st.sql`).
- Confidence: high for the displayed values (same SQL / functions as the form), medium for the limit editing (see below).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| stores: transaction stores (`STORE_STATUS = 1`) the user group may see: `(:1=0 OR STORE_CODE IN (SELECT DISTINCT ST.STORE_CODE FROM ST_STORE ST, ST_CHART_STRUCTURE CHRT, ST_STORE_PASSWORD SP WHERE ... SP.FLAG=1 AND SUBSTR(SP.STORE_CODE,1,CHR_STRU_END) = SUBSTR(ST.STORE_CODE,1,CHR_STRU_END)))` | block WHERE of `ST_STORE` | `store_allowed` in the store list of values and in `store_items`; "لا توجد صلاحية للمخزن" when a code is typed | high |
| items limited to the groups of the user group `(:1=0 OR GROUP_CODE IN (SELECT GROUP_CODE FROM ST_GROUP_PASSWORD WHERE PASSWORD_NUMBER=:2))` | block WHERE of `ST_STORE_ITEM` | `group_allowed` (the ST_ITEM form of the filter: chart-structure prefix and `FLAG = 1`; identical when groups are granted at leaf level with FLAG 1 - `ST_GROUP_PASSWORD` is empty here) | medium |
| item name, basic unit (`ST_ITEM_UNIT.BASIC_UNIT = 1` + `ST_UNIT`) | POST-QUERY SQL | `store_items` | high |
| current balance / total cost / average cost = `GET_BALANCE_COST(store, group, item)`; costs only when `USERS.ALLOW_VIEW_COST = 1` | `SELECT NVL(ALLOW_VIEW_COST,0) FROM USERS`, identifiers `GET_BALANCE_COST`, `SHOW_COST` | `store_items` (cost columns empty without the right) | high |
| received / issued / returned: `SUM(DECODE(EFFECT,1,1,2,0,4,0)*BASIC_QTY)` ... over purchase invoices (1/1), sales invoices (2/2), sales returns (4/4), not deleted | embedded SQL (quoted in the evidence) | `store_items` columns وارد / منصرف / مردود | high |
| lots of the item: `ST_ITEM_CONFG` (lot number, expiry, supplier name, lot price) with `GET_BALANCE_COST_CONFG` | block `ST_ITEM_CONFG`, `SELECT NAME_A FROM SUPPLIER WHERE CODE` | rows of kind "شحنة" when an item is chosen | high |
| store limits editable (`REORDER_LIMIT`, `MIN_LIMIT`, `MAX_LIMIT`): "الحد الاقصى يجب ان يكون اكبر من الحد الادنى" | message in the .fmx, SAVE_BTN / COMMIT_FORM identifiers, text items on the base-table block | optional page items حد الطلب / الحد الادنى / الحد الاقصى: typed together with an item, they update its `ST_STORE_ITEM` row (`for update`) | medium |
| "يجب تحديد المخزن المراد الجرد له" | message (count-sheet print without a store) | store required on the page | high |

Tested (rolled back, `tmp\w3_st\t_rules3_st.py` J1, J6): one preview row per `ST_STORE_ITEM` row of store 101010101001 (680);
balance and cost equal `GET_BALANCE_COST`; with an item: item row + one row per lot and the lot balances add up to the item balance;
user 1 (no `ALLOW_VIEW_COST`) sees balances but no costs; limits updated, max < min refused, limits without item refused,
unknown item refused.

## Printing (layout: main session, `prints.json`)

Three print buttons, each with `FROM_STORE_CODE = TO_STORE_CODE = :ST_STORE.STORE_CODE`, `COMP_CODE`, `LANG`:
`ST_STORE_ITEM.RDF` (store items: limits, balance), `ST_ITEM_REORDER_LIMIT.RDF` "إشعار حد الطلب" (items whose
`GET_BALANCE < NVL(REORDER_LIMIT,0)`, extra params FROM/TO_ITEM_GROUP_CODE, FROM/TO_ITEM_CODE, UNIT_P, P_ITEM_RANGE, Company_CODE)
and `ST_ITEM_UNIT_NEW.RDF` "كشف جرد المخزن". The generator currently skips these parameters on a PROCESS page
("column STORE_CODE not in dual"): the page item `STORE_CODE` should feed them.

## Wave 3b (new generator keys)

| Change | Key / code | Evidence |
|---|---|---|
| The display (button "عرض") needs only the query right of the page | `proc.run_right = "query"` | a display screen (legacy query block) |
| Changing the store limits still needs the update right: `show_store_items` refuses a limit change inside APEX when `app_sec.can_page(page, 'U')` is false, with the legacy alert title "خطأ صلاحية" | `app\db\25_rules3_st.sql` (`APP_RULES3_ST.show_store_items`, body only; compiled) | .fmx text "خطأ صلاحية"; limits are saved data |

Tested (`tmp\w3b_st\t_store_item_right.py`, APEX session, rolled back, session removed): a user without update right displays
the store (no error) and is refused a limit change ("خطأ صلاحية"); a user with the update right changes the limit.

## Coverage

- Reproduced: the store / group / item selection with the legacy permission filters, all displayed columns (balance, costs with the
  cost right, limits, reserved quantity, received / issued / returned, lots with lot balance and cost), the limit editing.
- Not reproduced: master-detail navigation (replaced by the parameters and one list); colour / size columns of the lots
  (`ST_BASIC.COLOR_FLAG` / `SIZE_FLAG` are 0 here, `ST_COLOR` / `ST_SIZE` empty); record insert / delete buttons of the
  toolbar (store rows are created by the transactions, not typed; no delete rule in the evidence).
- Wave 3b: the display needs only the query right (`run_right`); limit changes need the update right. Print parameters can now use
  the screen's fields (`@NAME` in `prints.json`, main session / prints agent).
- Open question: were the store limits really edited here (block properties not visible without the .fmb), and was it allowed
  only for `FILE_PASSWORD.UPDATE_FLAG = 1`?
