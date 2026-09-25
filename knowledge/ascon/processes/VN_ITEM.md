# VN_ITEM - الاصناف الغير مخزنية / Non Stock Items (AP)

- Registry: system 5 serial 35 (menu `CODES_MENU.NON_STOCK`, order 205). APEX grid page 40100.
- **Deliverable: generated grid kept (`"pattern": "AUTO"`) + key / row rule** - `app\legacy\overrides\VN_ITEM.json`, package `APP_RULES3_VN`.
- **Confidence: high** - plain code table (CODE, NAME_A, NAME_E), empty on the build copy; no table references it.

## Evidence (`evidence\VN_ITEM.md`, compiled `VN\FMB\vn_ITEM.fmx`)

- `CHK_UNIQ` (`SELECT COUNT(1) FROM VN_ITEM WHERE CODE = :b1`, "كود مكرر", called from WHEN-VALIDATE-ITEM and PRE-INSERT); CODE
  WHEN-VALIDATE-ITEM with the text copied from the class form: "رقم تصنيف المورد يجب ان يكون اكبر من الصفر". No numbering statement.

## Rules

| Rule | APEX |
|---|---|
| Code typed by the user | `key_expr` VN_ITEM.CODE = `need_num('يجب إدخال كود الصنف')` |
| Code > 0 (legacy text kept as is) | row rule `positive_code` |
| Duplicate | PK + `app_ui.handle_error` |

Tests (t_vn1): empty code refused, code 0 refused with the legacy text, code 77 accepted. 3/3 passed.

## Coverage

Reproduced: all rules of the form. Not reproduced: print, toolbar / translate (Forms-only).
