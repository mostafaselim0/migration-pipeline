# VN_RESP - ملف مندوبى المشتريات / Purchasing Representative File (supplier responsibles)

- Registry: system 5 serial 23 (menu `CODES_MENU.VN_RESP`, order 203) and system 30 serial 21 "ارقام المندوبين / Purchase Men"
  (the same form). APEX grid page 40080.
- **Deliverable: generated grid kept (`"pattern": "AUTO"`) + key / row rule** - `app\legacy\overrides\VN_RESP.json`, package `APP_RULES3_VN`.
- **Confidence: high** - plain code table (CODE, NAME_A, NAME_E; 5 rows), referenced by VN_SUPP_RESP (FK), VN_MAINTRNS.RESP_CODE (FK),
  VN_MAINTRNS_CHECK, VN_SUPP_RESP_REQ, and used as SALES_MAN of the supplier opening balances.

## Evidence (`evidence\VN_RESP.md`, compiled `ST\FMB\vn_resp.fmx`)

- `CHK_UNIQ` (`SELECT COUNT(1) FROM VN_RESP WHERE CODE = :b1`, "رقم مكرر"); CODE WHEN-VALIDATE-ITEM "رقم المسئول يجب ان يكون اكبر من
  الصفر"; ON-ERROR texts. **No numbering statement**: the code is typed by the user.

## Rules

| Rule | APEX |
|---|---|
| Code entered by the user (the generator would fill max+1) | `key_expr` VN_RESP.CODE = `need_num('يجب إدخال رقم المسئول')` |
| Code > 0 (legacy message) | row rule `positive_code` |
| Duplicate / delete of a responsible in use | PK / FKs + `app_ui.handle_error` |
| Label of CODE | `add_columns`: "رقم المسئول" (GN_FORM_ITEM had the system-30 label "رقم المندوب") |

Tests (t_vn1): empty code refused, code -5 refused, code 98765 accepted. 3/3 passed.

## Coverage

Reproduced: typed code, code > 0, uniqueness, delete protection. Not reproduced: print (VN_RESP_REP), toolbar / translate
(Forms-only).
