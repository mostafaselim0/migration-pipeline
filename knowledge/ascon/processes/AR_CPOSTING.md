# AR_CPOSTING - إلغاء الترحيل للحسابات العامة (العملاء) / Cancel AR Posting to General Ledger

- Registry: system 4 serial 8 (menu `SYSTEM_MENU.AR_CPOSTING`, order 4006). APEX page 30230.
- **Deliverable: (b) process screen**
  - PL/SQL: `app_proc_ar.cancel_gl_posting` in `app\db\20_proc_ar.sql` (package `APP_PROC_AR`, VALID).
  - Override: `app\legacy\overrides\AR_CPOSTING.json` (preview = posted AR transactions of the filter with their voucher and voucher sharing count).
- **Confidence: medium-high** - compiled form only, but its embedded SQL contains every statement of the cancellation; the order of the
  statements and the use of the counts are inferred. Posting side verified against ARACUPDT (`AR\FMB\aracupdt_fmb.xml`) and the DB procedure
  `AR_CREATE_ENTRY_EVERY_ONE` (what the posting writes).

## Evidence (`evidence\AR_CPOSTING.md`)

- Cursor: `SELECT ACC_YEAR, ACC_TYPE, ACC_NO, TRNS_ID, MAINAREA_ID, SUBAREA_ID, TRNS_SERIAL, TRNS_DATE, ACC_POST_DATE FROM AR_MAINTRNS WHERE
  ((ACC_POST_DATE IS NOT NULL AND ACC_POST_DATE BETWEEN :from AND :to) OR (ACC_POST_DATE IS NULL AND TRNS_DATE BETWEEN :from AND :to)) AND TRNS_ID,
  MAINAREA_ID, SUBAREA_ID, TRNS_SERIAL ranges AND TRNS_SERIAL_TOT IS NULL AND (cash-flag rule) AND POST_FLAG = 1 AND LINK_FLAG = 0 AND ACC_* NOT NULL
  AND (:pw = 0 OR TRNS_ID IN (AR_TRNSTYPE_PASSWORD FLAG = 1))`.
- Cash-flag rule: `CASH_FLAG NOT IN (0,1) OR (:system = 15 AND CASH_FLAG IN (0,1)) OR (CASH_FLAG = 1 AND <cash-box system 15 not installed>)
  OR (CASH_FLAG = 0 AND <cheque system 13 not installed>)` - cash / bank receipts belong to the treasury systems when they are installed
  (SYS_SYSTEMS has neither 13 nor 15 here).
- `SELECT CLOSE_DATE FROM AC_BASIC WHERE COMPANY_CODE = :company` + texts "لا يمكن إلغاء ترحيل الحركة رقم ... لأنها تقع فى فترة مقفلة".
- `SELECT COUNT(1) FROM AR_MAINTRNS WHERE ACC_YEAR/TYPE/NO = ... AND POST_FLAG = 1` + text "سوف يتم إلغاء قيد لحركة مجمعة ...هل تريد الإستمرار" (OK / إلغاء).
- `DELETE FROM AC_YEARLY_TRN_DET / AC_YEARLY_TRN WHERE ENTRY_YEAR/TYPE/NO`, `SELECT * FROM AR_MAINTRNS WHERE ACC_YEAR/TYPE/NO`,
  `UPDATE AR_MAINTRNS SET POST_FLAG = 0 WHERE key`, `UPDATE AR_SUBTRNS SET POST_FLAG = 0 WHERE key`.
- Texts "لا توجد قيود يمكن الغاء ترحيلها", "انتهت عملية الغاء الترحيل", "التاريخ الاول يجب ان يكون اقل من التاريخ الثانى".

## Rules

1. Filter as the cursor above (LINK_FLAG = 0: transactions created by the stock posting are cancelled from ST_CPOSTING, not here).
2. Nothing to cancel -> "لا توجد قيود يمكن الغاء ترحيلها" (ORA-20113).
3. Posting date (ACC_POST_DATE, else TRNS_DATE) on/before AC_BASIC.CLOSE_DATE -> refused (ORA-20114; DB trigger AC_CLOSE_ACYR also blocks).
4. Voucher shared by several posted AR transactions -> legacy question; APEX: check box "إلغاء القيود المجمعة" (unchecked -> ORA-20115, nothing done).
5. Delete the voucher lines and header; every AR transaction of that voucher gets POST_FLAG = 0 (master and AR_SUBTRNS lines). ACC_YEAR / TYPE / NO
   are kept (the AR re-posting creates a new number).

## APEX implementation

`cancel_gl_posting(p_from_date, p_to_date, p_from_trns_id, p_to_trns_id, p_from_mainarea, p_to_mainarea, p_from_subarea, p_to_subarea,
p_from_serial, p_to_serial, p_allow_grouped, p_company_code, p_user_code, p_password_number)`; rows locked; transactions already reset through
a shared voucher are skipped; count in `app_proc_ar.last_count`; no COMMIT.

## Tests (all rolled back)

- Collection 201/350 (2026-06-19): voucher 2026/103/221 (2 lines) deleted, AR_MAINTRNS and its 2 AR_SUBTRNS lines POST_FLAG 0.
- Whole 2026 (all types): 184 transactions cancelled, none left posted (LINK_FLAG 0).
- December 2025 (closed) -> ORA-20114; group 7 without AR_TRNSTYPE_PASSWORD rows -> ORA-20113 (nothing visible).

## Open questions

1. The legacy cursor compares `:system = 15` (treasury system calling the same form); from the AR menu it is always 4. Confirm the form is not
   also called from the treasury menu.
2. Confirm that ACC_YEAR / TYPE / NO must be kept after cancellation (VNACCUPDT clears them, AR_CPOSTING does not).
