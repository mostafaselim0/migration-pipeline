# ST_STORE_STRUCT - تعريف هيكل المخازن / Stores Structure

- Registry: system 3 serial 502 (also system 30 serial 24), menu `SYSTEM_MENU.ST_STORE_STRUCT`. Legacy `ASCON\ST\FMB\ST_STORE_STRUCT.fmx`
  (no .fmb; evidence = embedded SQL and texts).
- The store code is 12 digits split into levels; each level is a row of `ST_CHART_STRUCTURE` with `CHR_TYPE = 1` (the item-group
  structure, ST_GROUP_STRUCT, shares the table with `CHR_TYPE = 2`). Current data: 6 store levels (1 | 2-3 | 4-5 | 6-7 | 8-9 | 10-12), 15 stores.
- APEX: page 20270, `GRID` on `ST_CHART_STRUCTURE`. Override `overrides\ST_STORE_STRUCT.json`: `where CHR_TYPE = 1`; `key_expr`
  `CHR_TYPE = app_rules3_st.struct_type` (1 on this page, 2 on ST_GROUP_STRUCT, via `app_rules_st.cur_form`) and
  `CHR_STRU_LEVEL = app_rules3_st.next_struct_level(:new.chr_type)`; row rule `struct_row`; `CHR_TYPE` hidden; `LENGTH` read-only;
  `CHR_TYPE`, `CHR_STRU_LEVEL`, `CHR_STRU_START`, `LENGTH` optional (derived). Delete trigger `APP_RULES3_ST_CHART_BD` -> `struct_delete`.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| level number = last level + 1 | `SELECT MAX(CHR_STRU_LEVEL) FROM ST_CHART_STRUCTURE WHERE CHR_TYPE = 1` | `key_expr` `next_struct_level` | high |
| start field = end of the previous level + 1; "إدخل حقل البداية" when missing | `SELECT NVL(MAX(CHR_STRU_END),0) FROM ST_CHART_STRUCTURE WHERE CHR_TYPE = 1`, message | row rule `struct_row` (start derived on insert when empty; required otherwise, -20175) | high |
| end field >= start and <= 12: "برجاء التأكد من إدخال --حقل النهاية-- و كونه أكبر من حقل البداية و كذلك كونه أقل من 12" | message, `SELECT MAX(CHR_STRU_END)` | row rule `struct_row` | high |
| length = end - start + 1 ("طول المستوى") | label, derived item | row rule `struct_row` sets `LENGTH` (read-only column) | high |
| levels cannot be deleted while stores exist: "لا يمكن حذف المستويات حيث أنه توجد مخازن معرفة بناء على هذه المستويات" | `SELECT COUNT(*) FROM ST_STORE` + `MAX(CHR_STRU_LEVEL)` | delete trigger (-20176) | high |
| delete from the last level upwards: "يجب حذف السجلات من أسفل إلي أعلي" | `SELECT MAX(CHR_STRU_LEVEL) ...` in the delete path | delete trigger (reads the max level; autonomous read only if the table is mutating) | high |

## Tests (rolled back)

B1 structure type 1 on page 20270 (2 on 20280); B2 next store level = 7; B3 start required on update, length = 3 for 10..12, end 13
refused, first level of a new structure starts at 1 (length 2); B4 deleting store level 6 refused (stores exist); B5 on a test structure
(type 9) the first of two levels cannot be deleted, the last one can.

## Open questions

- The .fmx also runs a stand-alone `SELECT COUNT(*) FROM ST_STORE` (besides the delete path) and has the text "لا يمكن حذف السجلات".
  Its trigger is unknown: it may make the whole structure read-only once stores exist. The APEX grid still allows editing the start /
  end of existing levels while stores exist (which would invalidate the store codes). Confirm whether updates must be blocked too.
- (answered in wave 3b) "إدخل رقم المستوى" / "إدخل إسم المستوى العربى" / "إدخل إسم المستوى لاتيني" are item hints, not required-item
  messages; the names stay optional.

## Wave 3b (new generator keys)

Reviewed, no override change. The open question on the level names is answered by the evidence: "إدخل إسم المستوى العربى" /
"إدخل إسم المستوى لاتيني" / "إدخل رقم المستوى" are the **hint texts** of the items (each follows or precedes the item prompt in the
.fmx text list: "رقم المستوى / إدخل رقم المستوى", "إدخل إسم المستوى العربى / إسم المستوى عربى"), not error messages; nothing shows
that the names were required, so they stay optional. "عدد الحقول التي تم تخصيصها / المتبقية" are totals of the whole structure (one
value, not per row); a computed column would repeat it on every row, so they stay not reproduced.

## Coverage

- Reproduced: numbering of levels, start / end / length rules, delete restrictions.
- Not reproduced:
  - "برجاء استكمال هيكل المخازن" - the commit-time check that the levels reach digit 12 (`SELECT MAX(NVL(CHR_STRU_END,0))`): a grid
    saves its rows in the background, one row at a time, so there is no point where the whole structure can be checked.
  - "عدد الحقول التي تم تخصيصها" / "عدد الحقول المتبقية" (used / remaining digits): display totals; grid pages have no info panel.
  - "سيتم حذف هذا المستوى" confirmation: replaced by the grid's save.
  - toolbar print `ST_STORE_STRUCT.rdf` (list of levels; layout is the main session's job).
- The key expressions and the row rule become active in `APPX_ST_CHART_STRUCTURE` at the next build; they are shared with
  ST_GROUP_STRUCT (identical strings, merged once).
