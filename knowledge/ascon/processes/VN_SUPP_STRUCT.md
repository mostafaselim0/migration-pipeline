# VN_SUPP_STRUCT - هيكل أرقام الموردين / Suppliers' Codes Structure

- Registry: system 5 serial 40 (menu `CODES_MENU.VN_SUPP_STRUCT`, order 209). APEX grid page 40140.
- **Deliverable: generated grid kept (`"pattern": "AUTO"`) + rules** - `app\legacy\overrides\VN_SUPP_STRUCT.json`, package `APP_RULES3_VN`
  (next_struct_level, struct_row, struct_del + compound trigger `APP_RULES3_VN_STRUCT_BD`).
- **Confidence: medium-high** - the form is a clone of the item-group structure form (texts still say "مجموعات الأصناف"); the table
  VN_CHART_STRUCTURE holds only CHR_TYPE 1 rows (4 levels: 1-1, 2-5, 6-7, 8-12) and every SQL of the form filters CHR_TYPE = 1.
  The structure is used by the supplier file (DETECT_SUPP_LEVEL / GET_SUPP_PARENT, see SUPPLIER.md): 515 suppliers exist, so the
  structure is locked on the live data.

## Evidence (`evidence\VN_SUPP_STRUCT.md`, compiled `VN\FMB\VN_SUPP_STRUCT.fmx`)

- Form start: `SELECT COUNT(*) FROM SUPPLIER` (the structure cannot change once suppliers exist).
- New level: `SELECT MAX(CHR_STRU_LEVEL)`, `SELECT NVL(MAX(CHR_STRU_END),0)` ... `WHERE CHR_TYPE = 1` (level max+1, start = last end + 1).
- CHR_STRU_END WHEN-VALIDATE-ITEM: "برجاء التأكد من إدخال حقل النهاية و كونه أكبر من حقل البداية و كذلك كونه أقل من 12"; LENGTH =
  end - start + 1 ("طول المستوى").
- KEY-DELREC: `SELECT COUNT(*) FROM SUPPLIER` -> "لا يمكن حذف المستويات حيث أنه توجد ممجموعات أصناف معرفة بناء على هذه المستويات";
  `SELECT MAX(CHR_STRU_LEVEL)` -> "يجب حذف السجلات من أسفل إلي أعلي"; confirmation "سيتم حذف هذا المستوى".
- KEY-COMMIT: `SELECT MAX(NVL(CHR_STRU_END,0))` -> "برجاء استكمال هيكل مجموعات الأصنـــاف" (structure must reach position 12).

## Rules

| Rule | APEX |
|---|---|
| Only structure type 1 is shown and created | `where` CHR_TYPE = 1, default 1, column hidden; `struct_row` refuses another type |
| Level = max+1 | `key_expr` `next_struct_level` (column optional) |
| Start = previous end + 1, end >= start and <= 12, length = end - start + 1 | row rule `struct_row` (start / length read-only) |
| Locked while suppliers exist: no new level, no start / end / length change (names may change) | `struct_row` (own text; the legacy disabled the block silently) |
| Delete: refused while suppliers exist; bottom-up only | compound trigger (after the statement) -> `struct_del`, legacy texts |

Tests: with the live suppliers (t_vn1) next level 5; new level refused; end change refused; name change accepted; delete refused - 5/5.
Without suppliers (t_vn5: all suppliers removed inside the rolled-back transaction) delete of level 3 refused (bottom-up), level 4 deleted,
end 7 < start 8 and end 13 refused, new level -> 4 / type 1 / start 8 / end 12 / length 5, end 11 -> length 4, type 2 refused - 7/7.

## Coverage

Reproduced: numbering, start / end / length derivation and checks, the supplier lock, bottom-up delete. Not reproduced: the KEY-COMMIT
check "برجاء استكمال هيكل مجموعات الأصنـــاف" - a grid saves its rows one by one in the background, so a "structure complete up to 12"
check cannot run after all rows and a confirmation is not available on grid pages (generator gap: warnings only on document / pop-up form
pages); the delete confirmation (APEX asks itself), print, toolbar (Forms-only).
