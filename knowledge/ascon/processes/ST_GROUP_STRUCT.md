# ST_GROUP_STRUCT - تعريف هيكل مجموعات الأصناف / Item Groups Structure

- Registry: system 3 serial 503 (also system 30 serial 25), menu `SYSTEM_MENU.ST_GROUP_STRUCT`. Legacy `ASCON\ST\FMB\ST_GROUP_STRUCT.fmx`
  (no .fmb).
- The item-group code is 12 digits split into levels: rows of `ST_CHART_STRUCTURE` with `CHR_TYPE = 2` (shared table with the store
  structure, `CHR_TYPE = 1`). Current data: 5 group levels (1 | 2-3 | 4-5 | 6-8 | 9-12), 14 item groups.
- APEX: page 20280, `GRID` on `ST_CHART_STRUCTURE`, override `overrides\ST_GROUP_STRUCT.json`: same mechanism as ST_STORE_STRUCT
  (`where CHR_TYPE = 2`, `key_expr` `struct_type` / `next_struct_level`, row rule `struct_row`, hidden / read-only / optional columns),
  delete trigger `APP_RULES3_ST_CHART_BD`. See `ST_STORE_STRUCT.md` for the shared rules.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| level = last level + 1; start = previous end + 1 ("إدخل حقل البداية"); end between start and 12 ("برجاء التأكد من إدخال --حقل النهاية-- ..."); length = end - start + 1 | `MAX(CHR_STRU_LEVEL)`, `NVL(MAX(CHR_STRU_END),0)` with `CHR_TYPE = 2`, messages | `key_expr` + row rule `struct_row` | high |
| no level can be deleted while item groups exist: "لا يمكن حذف المستويات حيث أنه توجد ممجموعات أصناف معرفة بناء على هذه المستويات" | `SELECT COUNT(1) FROM ST_ITEM_GROUP` | delete trigger `APP_RULES3_ST_CHART_BD` (-20176) | high |
| delete from the last level upwards: "يجب حذف السجلات من أسفل إلي أعلي" | `MAX(CHR_STRU_LEVEL)` | delete trigger | high |
| deleting a level deletes its lookup codes | `DELETE FROM ST_LOCKUPS S WHERE S.TAB_PARENT = :b1` | `struct_delete` (type 2) | high |

## Tests (rolled back)

B1 structure type 2 on page 20280; B2 next group level = 6; B3 (shared row rule) start / end / length; B4 deleting group level 5 refused
(groups exist); B5 bottom-up deletion (shared procedure).

## Open questions

- Same as ST_STORE_STRUCT: whether the structure must be read-only once item groups exist (only deletes are known to be blocked), and
  whether the level names were required ("إدخل إسم المستوى العربى" / "لاتيني").

## Wave 3b (new generator keys)

Reviewed, no override change: the level-name texts are item hints (see `ST_STORE_STRUCT.md`), the digit totals are one value for the
whole structure, and the `ST_LOCKUPS` block stays off (`GROUP_PRE_CODE` = 0). A second grid on `ST_LOCKUPS` would now be possible
(`blocks.where` / `TABLE#2`) but the table is not a detail of `ST_CHART_STRUCTURE` rows in this page and the feature is switched off.

## Coverage

- Reproduced: all rules above.
- Not reproduced:
  - The `ST_LOCKUPS` block (per level lookup codes "الرمز / الاسم العربي / الاسم الانجليزي", `TAB_PARENT` = level) and its check
    "يجب ان يكون طول التكويد مساوي لطول المستوى": the generator did not place this unrelated block. The feature belongs to the group
    pre-coding switch `ST_BASIC.GROUP_PRE_CODE` (read by this form), which is **0** in the data, and `ST_LOCKUPS` is empty - switched off.
    If it is ever switched on, a separate grid on `ST_LOCKUPS` with a length check is needed.
  - "برجاء استكمال هيكل مجموعات الأصنـــاف" (commit-time completeness check): not possible in a background-saving grid (see ST_STORE_STRUCT).
  - used / remaining digit totals (display only), the delete confirmation, "تغير اللغة" (Forms language button).
  - toolbar print `ST_GROUP_STRUCT.rdf` (list of levels).
