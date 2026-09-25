# SEPASS_TRN - صلاحيات المجموعات--مراقبة المخازن والمستودعات / Group Privilege (Stocks)

- Registry: system 99 serial 33 (PRIVILIAGE_MENU, order 3003). APEX list page 80090, document page 80091.
- Legacy module: `ASCON\SE\FMB\SEPASS_TRN.fmx`. Master PASSWORD (group names display, SHOW_COST "إظهار التكلفة والربح بالتقارير"), tabs
  ST_STORE_PASSWORD (المخازن), ST_TRNSTYPE_PASSWORD (الحركات), ST_GROUP_PASSWORD (المجموعات).
- **Deliverable: (b) rules + buttons on the generated screen** - `app\legacy\overrides\SEPASS_TRN.json` (AUTO + add_columns + actions).
- **Confidence: high.**

These grants are read by APP_RULES_ST / SA / PR, APP_PROC_ST and APP_CONV (type_allowed, store checks).

## Rules and buttons

| # | Legacy rule / button | Evidence | APEX |
|---|---|---|---|
| 1 | Store rights carry three more rights: "صلاحية سعر البيع", "صلاحية الخصم", "صلاحية المجاني" | prompts; columns SALES_PRICE_FLAG, DISC_PRICE_FLAG, BONUS_FLAG | `add_columns` |
| 2 | Group flag "إظهار التكلفة والربح بالتقارير" | label SHOW_COST | `add_columns` PASSWORD.SHOW_COST |
| 3 | "كل المخازن": `DELETE FROM ST_STORE_PASSWORD WHERE PASSWORD_NUMBER; INSERT INTO ST_STORE_PASSWORD SELECT STORE_CODE, :pw, 1, 0, 0, 0 FROM ST_STORE` | SQL | action ALL_ROWS kind STORE -> `st_all` |
| 4 | "كل الحركات": DELETE + `INSERT ... SELECT :pw, TRNS_TYPE_CODE, 1 FROM ST_TRNS_TYPE` | SQL | kind TRNS |
| 5 | "كل المجموعات": DELETE + `INSERT ... SELECT :pw, ITEM_GROUP_CODE, 1 FROM ST_ITEM_GROUP WHERE NVL(GROUP_STATUS,0) = 1` | SQL | kind GROUP |
| 6 | "إختيار الكل" / "استبعاد الكل" (per tab): FLAG of every row 1 / 0 | CHOOSE_ALL / CHOOSE_NONE buttons | action FLAGS (tab, 1 / 0) -> `set_flags` |
| 7 | Lists exclude rows already granted; item groups only active ones | record groups | PK refuses duplicates; the generated item-group list shows all groups |
| 8 | A group with grants cannot be deleted here | `SELECT 1 FROM ST_STORE_PASSWORD / ST_TRNSTYPE_PASSWORD / ST_GROUP_PASSWORD WHERE PASSWORD_NUMBER` | groups are deleted only in ACGROUP_COMPANY |

## Tests (t_se.py, rolled back)

T1 all stores (FLAG 1, other rights 0), T2 all types / active item groups, T3 deselect all types (57 rows).


## Wave 3b

The item-group list of the group grid is now the legacy record group `SELECT ITEM_GROUP_CODE, NAME_A ... FROM ST_ITEM_GROUP WHERE NVL(GROUP_STATUS,0) = 1` (active groups only; `lov` on ST_GROUP_PASSWORD.GROUP_CODE). No grant row points to an inactive group today. The FLAG columns already are check boxes; SHOW_COST / SALES_PRICE_FLAG / DISC_PRICE_FLAG / BONUS_FLAG have no item type in the evidence and stay numbers.

## Coverage

- Reproduced: rules 1-6, 8; the "active groups only" item-group list (wave 3b).
- Not reproduced: FROM_ITEM_CODE / TO_ITEM_CODE items labelled on the store block (no such columns in ST_STORE_PASSWORD), print / translation
  buttons.
