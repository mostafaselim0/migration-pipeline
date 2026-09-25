# SYSPASS - صلاحية المستخدمين (شاشات وتقارير) / User Privileges (screens and reports)

- Registry: system 99, 16 serials (21 GL, 22 assets, 23 AR, 24 AP, 25 cashier, 26 cheque printing, 27 stock, 28 purchasing, 29 sales, 30 HR,
  31 payroll, 49 security, 53 self service, 87 taxes, 98 auditing, 99 attendance) - one form, `:CONTROL.SYSTEM_NUMBER` set per menu entry.
  APEX list page 80160, document page 80161 (one page for all systems: the rows carry SYSTEM_NUMBER).
- Legacy module: `ASCON\SE\FMB\SYSpass.fmx`. Blocks USERS (POS / invoice flags of the user), FILE_PASSWORD (screens), REPORT_PASSWORD (reports).
- **Deliverable: (b) rules + buttons on the generated screen** - `app\legacy\overrides\SYSPASS.json` (pattern AUTO), package `APP_RULES3_SE`.
- **Confidence: high.**

FILE_PASSWORD (insert / update / delete / query per user and SYS_FILES serial) and REPORT_PASSWORD (REPORT_FLAG per report serial) are exactly
what `APP_SEC.can_page` and `APP_MENU_V` read: a grant saved here opens the page and the menu entry at the user's next request.

## Rules and buttons

| # | Legacy rule / button | Evidence | APEX |
|---|---|---|---|
| 1 | "جميع الشــاشات": the user's screen rights of the system are replaced by every screen of the system | ALL_FORMS_BUT (P12): `DELETE FROM FILE_PASSWORD WHERE USERS_CODE AND SYSTEM_NUMBER`, loop `SELECT FILE_SERIAL ... FROM SYS_FILES WHERE SYSTEM_NUMBER` | action ALL_FORMS (param system) -> `grant_all_forms`, all four flags 1 (1445 of 1493 legacy rows have 1/1/1/1; many users hold exactly all screens of a system) |
| 2 | "جميع التقـــارير": same for reports | ALL_REPORTS_BUT (P13) | action ALL_REPORTS -> `grant_all_reports`, REPORT_FLAG 1 |
| 3 | A screen / report is chosen from the system's registry (FILES_S / REP_S lists, minus SYS_NVSBL_* and already granted) | record group SQL | row rules `file_password_row` / `report_password_row`: must exist in SYS_FILES / SYS_REPORTS of the system; duplicates refused by the PK |
| 4 | Screen / report number is typed | FILE_SERIAL / REPORT_SERIAL items | key_expr `required`: the generated max+1 would otherwise invent a serial |
| 5 | A user with rights cannot be deleted here ("Cannot delete master record when matching detail records exist.") | `SELECT 1 FROM FILE_PASSWORD / REPORT_PASSWORD WHERE USERS_CODE` | delete hook refuses user deletion outside the users screen (the page cascade would remove the rights first) |
| 6 | The password is not part of this form | USERS items of the fmx | USERS.PASSWORD hidden / optional |

## Tests (t_se.py, rolled back)

S1 all screens of GL (32 rows, all flags 1); S2 all reports of GL; S3 `app_sec.can_page(10010,'I')` becomes true for the test user;
S4 / S6 unknown screen / report refused; S5 screen number required; U12 user delete refused on this page.


## Wave 3b

- FILE_SERIAL / REPORT_SERIAL (the file / report name display items FILE_NAME / REPORT_NAME): lists of the legacy record groups `select file_serial, file_desc_a ... from sys_files where system_number = ...` (reports: sys_reports), limited to the row's system (`:PAGE_SYSTEM_NUMBER`, `cascade: SYSTEM_NUMBER`). The legacy also hid what the user already has and the invisible entries (SYS_NVSBL_FILES / _REPORTS); left out so that saved rows keep their names.
- SYSTEM_NUMBER of both grids: list of SYS_SYSTEMS (the legacy took it from CONTROL.SYSTEM_NUMBER).
- USERS.MAIN_STORE_CODE (MAIN_STORE_NAME display): list `SELECT STORE_CODE, NAME_A ... FROM ST_STORE WHERE STORE_STATUS = 1`.
Checked on the build copy (system 1: screens 1 القيود اليومية, 2 القيود المرحلة ...).

## Coverage

- Reproduced: rules 1-6; the USERS flags of the form (POS manager, max payment, discounts, invoice print counts, main store, ...) are the
  generated master columns.
- Not reproduced: the per-menu system filter (one APEX page shows the rights of every system, filterable by SYSTEM_NUMBER; the menu registry maps
  all 16 serials to it), SYS_NVSBL_FILES / _REPORTS exclusion and the "not yet granted" filter of the lists (tables empty; saved rows must keep their names), print /
  translation buttons. (Wave 3b: screen / report names, system and store lists.)
