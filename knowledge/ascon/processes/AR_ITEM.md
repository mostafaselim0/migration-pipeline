# AR_ITEM - الأصناف الغير مخزنية / Non Stock Items (AR)

- Registry: system 4 serial 100 (`Codes_menu.NON_STOCK`). Legacy `ASCON\AR\FMB\AR_ITEM.fmx` (no .fmb). 1 row.
- APEX: generated grid on `AR_ITEM` (page 30150) kept; one row rule in `APP_RULES3_AR`.

## Evidence checked

- Embedded SQL: `SELECT COUNT(1) FROM AR_ITEM WHERE CODE = :b1` (duplicate check -> primary key, message "كود مكرر").
- Messages: "كود مكرر", "رقم تصنيف المورد يجب ان يكون اكبر من الصفر" (copied from the supplier-class form, used for the code),
  "هل تريد حذف هذا السجل".

## Rules

| Rule | APEX | Confidence |
|---|---|---|
| code must be greater than zero (legacy message kept verbatim) | row rule `positive_code` | high |
| code unique | primary key | high |

## Coverage

- Reproduced: the code check and uniqueness. The code is typed in the legacy form; the generated grid fills max+1 when left empty (a
  convenience, no business effect).
- Nothing else in the form (print button only).
