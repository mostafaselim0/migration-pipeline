# VNACCUPDT - إلغاء الترحيل للحسابات العامة (الموردين) / Cancel AP Posting to GL

- Registry: system 5 serial 12 (menu `FILES_MENU.ARACCUPDT`, order 405). APEX page 40180.
- **Deliverable: (b) process screen**
  - PL/SQL: `app_proc_vn.cancel_gl_posting` in `app\db\20_proc_vn.sql` (package `APP_PROC_VN`, VALID).
  - Override: `app\legacy\overrides\VNACCUPDT.json` (preview = posted supplier transactions of the filter with voucher and sharing count).
- **Confidence: medium-high** - compiled form only; every statement is in its embedded SQL, the order is inferred. The posting side
  (VN_ACUPDT.fmb, DB procedure `VN_CREATE_ENTRY_EVERY_ONE`, 416 posted transactions whose VN_TRNS_ENTRY link equals ACC_*) confirms what has to be undone.

## Evidence (`evidence\VNACCUPDT.md`)

- `SELECT CLOSE_DATE FROM AC_BASIC WHERE COMPANY_CODE = :company`.
- Cursor `SELECT TRNS_ID, TRNS_SERIAL, ACC_YEAR, ACC_TYPE, ACC_NO, TRNS_DATE FROM VN_MAINTRNS WHERE TRNS_DATE BETWEEN .. AND TRNS_ID BETWEEN .. AND
  TRNS_SERIAL BETWEEN .. AND LINK_FLAG = 0 AND (PAY_METHOD NOT IN (2,4) OR (:system = 15 AND PAY_METHOD IN (2,4)) OR (PAY_METHOD = 2 AND no cash-box
  system) OR (PAY_METHOD = 4 AND no cheque system)) AND POST_FLAG = 1 AND SERIAL IS NULL AND TRNS_ID IN (VN_TRNSTYPE TRNS_TYPE != 5 AND EFFECT IN (0,1))
  ORDER BY TRNS_DATE, TRNS_ID, TRNS_SERIAL`.
- `UPDATE VN_MAINTRNS SET POST_FLAG = 0 WHERE TRNS_ID, TRNS_SERIAL`; `SELECT COUNT(1) ... WHERE ACC_YEAR/TYPE/NO AND POST_FLAG = 1`;
  `UPDATE VN_MAINTRNS SET POST_FLAG = 0, ACC_YEAR = NULL, ACC_TYPE = NULL, ACC_NO = NULL WHERE ACC_YEAR/TYPE/NO`;
  `DELETE VN_TRNS_ENTRY_DET / VN_TRNS_ENTRY WHERE TRNS_ID, TRNS_SERIAL`; `DELETE AC_YEARLY_TRN_DET / AC_YEARLY_TRN WHERE ENTRY_*`.
- Texts: "لا يمكن إلغاء ترحيل الحركة رقم ... لأنها تقع فى فترة مقفلة", "لا توجد حركات يمكن الغاء  ترحيلها", "تمت عملية إلغاءالترحيل",
  counters "عدد الحركات المفترض / التي تم إلغاء ترحيلها", range messages "لابد ان يكون ...".
- No group-security filter in the legacy SQL (unlike AR); none added.

## Rules

1. Ranges: from <= to for dates (required), transaction types and serials (legacy WHEN-VALIDATE-ITEM messages, ORA-20141..20143); empty type /
   serial bounds = open (the legacy cursor used BETWEEN on all four bounds, filled by LOVs).
2. Nothing to cancel -> ORA-20144; transaction date on/before AC_BASIC.CLOSE_DATE -> ORA-20145.
3. Per transaction: POST_FLAG = 0; if it has a voucher: all transactions of that voucher get POST_FLAG = 0 and ACC_* = NULL, the VN_TRNS_ENTRY(_DET)
   link of the transaction and the voucher (AC_YEARLY_TRN_DET, AC_YEARLY_TRN) are deleted. The COUNT is used for the "cancelled" counter.
4. Stock-generated supplier transactions (LINK_FLAG = 1: purchase invoices / returns) are excluded; they are cancelled from ST_CPOSTING.

## Tests (all rolled back)

- Payment 201/277 (2026-06-15): voucher 2026/102/60012 (3 lines) deleted, VN_MAINTRNS POST_FLAG 0 and ACC_* NULL, VN_TRNS_ENTRY(_DET) deleted.
- Whole 2026: 142 transactions cancelled, none left; the 173 stock-generated (LINK_FLAG 1) transactions untouched.
- December 2025 (closed) -> ORA-20145.

## Open questions

1. VN_INVO_SERVS / VN_TRNS are counted by the legacy form (counters) but never updated in its SQL; both tables are empty here. Confirm nothing
   else must be cancelled for service invoices.
2. Should a group-security filter (VN_TRNSTYPE_PASSWORD, as in the other AP screens) be added? The legacy cancel screen had none.
