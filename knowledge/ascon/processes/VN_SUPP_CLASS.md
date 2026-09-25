# VN_SUPP_CLASS - ملف تصنيف الموردين / Suppliers Classification

- Registry: system 5 serial 22 (menu `CODES_MENU.VN_SUPP_CLASS`, order 202). APEX grid page 40070.
- **Deliverable: generated grid kept (`"pattern": "AUTO"`) + one row rule** - `app\legacy\overrides\VN_SUPP_CLASS.json`,
  package `APP_RULES3_VN`.
- **Confidence: high** - plain code table (ID, NAME_A, NAME_E; 2 rows), referenced by SUPPLIER.SUPP_CLASS (FK SUPPLIER_FK4).

## Evidence (`evidence\VN_SUPP_CLASS.md`, compiled `VN\FMB\vn_supp_class.fmx`)

- `CHK_UNIQ` (`SELECT COUNT(1) FROM VN_SUPP_CLASS WHERE ID = :b1`, "كود مكرر"), ID WHEN-VALIDATE-ITEM "رقم تصنيف المورد يجب ان يكون
  اكبر من الصفر", WHEN-CREATE-RECORD `SELECT NVL(MAX(ID),0)+1 FROM VN_SUPP_CLASS`, ON-ERROR texts for FK / duplicate.

## Rules

| Rule | APEX |
|---|---|
| ID = max+1 when empty | generated key (identical) |
| ID > 0 (legacy message) | row rule `positive_code` |
| Duplicate / delete of a class in use | PK / FK SUPPLIER_FK4 + `app_ui.handle_error` |

Tests (t_vn1): empty id -> max+1; id 0 -> legacy message. 2/2 passed.

## Coverage

Reproduced: numbering, id > 0, uniqueness, delete protection. Not reproduced: print (VN_SUPP_CLASS_REP report), toolbar and
translate buttons (Forms-only).
