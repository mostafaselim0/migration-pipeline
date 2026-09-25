# COMPLAINT_CODES - ملف أرقام شكاوي العملاء / Customer's Complaint Codes File

- Registry: system 4 serial 33 (`CODES_MENU.ITEM179`). Legacy `ASCON\AR\FMB\Complaint_codes.fmx` (no .fmb). Table empty.
- APEX: generated grid on `COMPLAINT_CODES` (page 30170) kept; a small override (`rules.columns`, wave 3b) only removes the wrong
  list of values on the key. No package code.

## Evidence checked

- Embedded SQL: `SELECT NVL(MAX(COMPLAINT_CODE),0)+1 FROM COMPLAINT_CODES` (= the generated max+1 key).
- Messages: generic code-table template texts only ("رقم مكرر تم إدخالة من قبل", "لا يجوز حذف السجل لإرتباطة بجداول اخري" - the ON-ERROR
  text for ORA-02292; `COMPLAINT_CUSTOMER_DETAIL` has no foreign key to this table, so the legacy did not refuse deleting a used code
  either), labels رقم الشكوي / البيان العربي / البيان الانجليزي.

## Coverage

- A plain code table: numbering (generated) and uniqueness (primary key); nothing else.
- Generator defect fixed with the wave-3b key `rules.columns` (`"lov": null`): the key column `COMPLAINT_CODE` had got the list of
  values of `RET_INV_CODES.COMPLAINT_CODE` (another table whose key has the same name); it is now a plain number filled by the
  generated max+1.
