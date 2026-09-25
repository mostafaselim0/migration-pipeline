# ST_STORE_GRP - تكلفة المخازن على مستوى المجموعة / Stores Cost on Group Level

- Registry: system 3 serial 109 (`FILES_MENU.ST_STORE_GRP`, order 1005); also system 30 serial 9.
- Legacy module: `ASCON\ST\FMB\ST_STORE_GRP.fmx` (no .fmb, no GN_FORM_ITEM labels). Blocks `ST_STORE` (transaction stores) ->
  `ST_STORE_GROUP` over `(SELECT DISTINCT STORE_CODE, GROUP_CODE FROM ST_STORE_ITEM)` with group name and "التكلفة الكلية",
  a total "إجمالى التكلفة". A query screen: nothing is written.
- APEX: `PROCESS` page 20040 (override `ST_STORE_GRP.json`): optional store; the preview lists store / group / total cost.
  Procedure `APP_RULES3_ST.show_store_groups` (permission check), cost function `APP_RULES3_ST.store_group_cost`.
- Confidence: high.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| transaction stores the user group may see (chart-structure prefix, `ST_STORE_PASSWORD.FLAG = 1`) | block WHERE `(:1=0 OR STORE_CODE IN (SELECT DISTINCT ST.STORE_CODE FROM ST_STORE ST, ST_CHART_STRUCTURE CHRT, ST_STORE_PASSWORD SP ...))` | `store_allowed` in the preview and in the store list of values; "لا توجد صلاحية للمخزن" when a store is typed | high |
| groups the user group may see (`ST_GROUP_PASSWORD`, prefix, `GROUP_STATUS = 1`, `FLAG = 1`) | detail block WHERE (quoted in the evidence) | `group_allowed` in the preview | high |
| group cost = sum over the items of the store and group (`SELECT ITEM_CODE FROM ST_STORE_ITEM WHERE STORE_CODE AND GROUP_CODE`) of the cost of their lots (`SELECT ITEM_CONFG_ID FROM ST_ITEM_CONFG ...`, `GET_BALANCE_COST_CONFG`) | embedded SQL, identifiers `GET_SUM_BAL_COST`, `TEMP_CURRENT_COST` | `store_group_cost` = sum of `GET_BALANCE_COST` per item (the item cost is the sum of its lot costs) | high |
| grand total "إجمالى التكلفة" | text | sum of the cost column in the interactive report | high |

Tested (rolled back, `t_rules3_st.py` J2, J6): the group costs of store 101010101001 add up to the store total of ST_STORE's CALC_COST
(3,985,811.10); the preview returns one row per (transaction store, group) pair of `ST_STORE_ITEM` (18).

## Printing (layout: main session, `prints.json`)

`ST_Store_GROUP_COST.RDF` with `FROM_STORE_CODE = TO_STORE_CODE = :ST_STORE.STORE_CODE`, `COMP_CODE`, `LANG` (PARAMFORM).
On the PROCESS page the parameters must come from the page item `STORE_CODE` (generator gap, as for ST_STORE_ITEM).

## Coverage

- Reproduced: the store / group list with the permission filters, the group cost and the total.
- Not reproduced: toolbar insert / delete / save buttons (the blocks are query-only: no DML in the .fmx SQL; the texts
  "كود الوحدة مكرر" / "تم تخصيص هذه الوحدة مع صنف أو أكثر" are template leftovers of the unit screen).
- Generator gap: RUN on a PROCESS page needs the page insert right.
