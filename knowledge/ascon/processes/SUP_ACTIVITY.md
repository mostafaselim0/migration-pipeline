# SUP_ACTIVITY - ملف أنشطة الموردين / Supplier's Activities

- Registry: system 5 serial 26 (menu `CODES_MENU.SUP_ACTIVITY`, order 204). APEX grid page 40090.
- **Deliverable: generated grid kept (`"pattern": "AUTO"`) + one row rule** - `app\legacy\overrides\SUP_ACTIVITY.json`,
  package `APP_RULES3_VN` (`app\db\25_rules3_vn.sql`).
- **Confidence: high** - a plain code table (ACT_CODE, NAME_A, NAME_E; 3 rows), referenced by SUPPLIER.ACT_CODE (FK SUP_ACT_FK).

## Evidence (`evidence\SUP_ACTIVITY.md`, compiled `VN\FMB\SUP_ACTIVITY.fmx`, no .fmb)

- `CHK_UNIQ`: `SELECT COUNT(1) FROM SUP_ACTIVITY WHERE ACT_CODE = :b1` -> "كود مكرر".
- ACT_CODE WHEN-VALIDATE-ITEM: "رقم النشاط يجب ان يكون اكبر من الصفر" / "the activity number should be over than zero".
- WHEN-CREATE-RECORD: `SELECT NVL(MAX(ACT_CODE),0)+1 FROM SUP_ACTIVITY`.
- Form ON-ERROR: FK violation -> "لا يجوز حذف السجل لإرتباطة بجداول اخري", duplicate -> "رقم مكرر تم إدخالة من قبل".

## Rules

| Rule | APEX |
|---|---|
| Code = max+1 when left empty | generated APPX_SUP_ACTIVITY key (same statement) |
| Code > 0 (legacy message) | row rule `positive_code` |
| Repeated code / delete of an activity used by suppliers | primary key / FK SUP_ACT_FK; `app_ui.handle_error` shows the readable Arabic text |

Tests (build copy, rolled back, t_vn1): empty code -> max+1; code -4 -> legacy message. 2/2 passed.

## Coverage

Reproduced: numbering, code > 0, uniqueness, delete protection (DB constraints). Not reproduced: print button (report
SUP_ACTIVITY.rdf - reports are handled by the print stage), toolbar / translate buttons (Forms-only).
