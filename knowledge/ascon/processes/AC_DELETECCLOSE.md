# AC_DELETECCLOSE: Cancel closing entry (إلغاء قيد الإقفال)

- Registry: system 1, serial 79, menu `SYSTEM_MENU.ACCLOSE_CANCLE`. APEX page 10230. The .fmx module is named `AC_DELETECLOSE`.
- Deliverable: **(b) process screen**. `app_proc_gl.cancel_closing_entry` in `app\db\20_proc_gl.sql`, override `app\legacy\overrides\AC_DELETECCLOSE.json`.
- Confidence: **high**. The complete SQL (4 statements) is in `ASCON\AC\FMB\AC_deletecclose.fmx`, and the cancel was tested on the real 2025 closing entry.

## Legacy behaviour

1. **On open** (the display items are the last closing entry and its date):
   `SELECT ENTRY_YEAR, ENTRY_TYPE, ENTRY_NO, ENTRY_DATE FROM AC_YEARLY_TRN WHERE CLOSE_FLAG = 1 AND (group 0 OR (CREATE_COMPANY_CODE = company AND CREATE_PASSWORD_NUMBER = group)) AND ENTRY_DATE IN (SELECT MAX(ENTRY_DATE) FROM AC_YEARLY_TRN WHERE CLOSE_FLAG = 1)`.
   If there is none: `لا يوجد قيود اقفال لكى تلغى`.
2. **Execute:**
   - `DELETE AC_YEARLY_TRN_DET`, then `DELETE AC_YEARLY_TRN` for that key, with the same group filter.
   - `SELECT MAX(ENTRY_DATE) FROM AC_YEARLY_TRN WHERE CLOSE_FLAG = 1` (group filter) into DATE_TEMP.
   - `UPDATE AC_BASIC SET CLOSE_DATE = DATE_TEMP WHERE (group 0 OR COMPANY_CODE = company)`. Group 0 updates every company.

The DB trigger `AC_CLOSE_ACYR` / `_DET` allows deleting a closing entry dated exactly on CLOSE_DATE (it only refuses `< CLOSE_DATE`), so the closing entries must be cancelled newest first. `AC_YRLY_TRN_TAX` still refuses the delete if the tax period is authorised.

## APEX version

- It reproduces the steps above in one call. The previous closing date may be NULL: when no closing entry remains, CLOSE_DATE becomes NULL and every period is open. This is faithful to `UPDATE … = DATE_TEMP`.
- **Added double-submit guard:** parameter `CLOSE_DATE`, which defaults to the date of the last closing entry and is required, must equal the date of the entry about to be deleted (-20152). A replayed submit cannot cancel a second, older closing.
- More than one closing entry on the same last date: the legacy `SELECT INTO` would fail with TOO_MANY_ROWS. APEX raises -20151.
- The rows are locked `FOR UPDATE NOWAIT`. Trigger refusals return -20153.
- Result message: `تم إلغاء قيد الإقفال y/t/n بتاريخ … وأصبح تاريخ الإقفال …` (or `فارغاً`).
- The preview lists every closing entry, flags the last one and shows the current `AC_BASIC.CLOSE_DATE`.

## Open questions

- When the last closing entry is cancelled and no older one exists, CLOSE_DATE becomes **NULL**, which reopens 2024 and earlier too. The legacy did the same. Should it instead fall back to a fixed date, such as the opening-entry date 2024-12-31? That is a key-user decision.

## Tests run (ROLLBACK after each; fingerprints unchanged)

- **T5a:** a wrong confirmation date (2025-06-30) is refused.
- **T5b:** group 101 cannot cancel the closing created by group 0, and gets the legacy "no closing entries" message.
- **T5c:** cancelling 2025/101/120084 deletes its 515 lines and sets CLOSE_DATE to NULL. T5d then recreates it identically with ACCLOSE.
- **T6j:** after a test closing at 2026-06-30, cancelling it returns CLOSE_DATE to 2025-12-31.

## What a human must verify

- The NULL close-date behaviour (question above).
- That only group 0 (or the creating group) should be able to cancel closings. Page access is also controlled by FILE_PASSWORD.

## Wave 3b

Checked, nothing to change: one date parameter, no list / radio / check item, no button that only opened another form; the screen writes data (insert right kept).

## Coverage

- Reproduced: the legacy cancel (steps 1-2 above) with the group filter, the new closing date and the preview of the closing entries.
- Added: the double-submit guard (-20152) and the explicit error for two closing entries on the same last date (-20151).
- Not reproduced: nothing of the business logic; Forms-only mechanics (SET_IP, prompts).
