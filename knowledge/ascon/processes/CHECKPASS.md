# CHECKPASS - صلاحيات المجموعات ( متابعة الشيكات ) / Group Privilege (Checks Management)

- Registry: system 99 serial 14 (PRIVILIAGE_MENU.CHECKPASS, order 3007). APEX list page 80130, document page 80131.
- Legacy module: `ASCON\SE\FMB\CHECKPASS.fmx` (a copy of RAPPASS for banks and cheque transactions). Master PASSWORD, tabs BANK_PASSWORD
  (سرية البنوك), CHECK_TRNS_PASSWORD (سرية الحركات, FLAG "اساسي").
- **Deliverable: (b) rules + buttons on the generated screen** - `app\legacy\overrides\CHECKPASS.json` (AUTO), package `APP_RULES3_SE`.
- **Confidence: high** for the rules; BANK and CHECK_TRNS_TYPE are empty in this database.

## Rules and buttons

| # | Legacy rule / button | Evidence | APEX |
|---|---|---|---|
| 1 | "تم إدخال هذا البنك لهذا المستخدم من قبل" | `SELECT COUNT(1) FROM BANK_PASSWORD WHERE PASSWORD_NUMBER AND BANK_CODE` + message | row rule `dup_row` |
| 2 | Bank number must be typed | BANK_CODE, PK column | key_expr `required` |
| 3 | "كل البنوك": every bank not yet granted | ALL_BOX (button name copied from RAPPASS), `SELECT CODE, NAME_A, NAME_E FROM BANK ORDER BY CODE` | action ALL_BANKS -> `check_all_banks` |
| 4 | "كل الحركات": `DELETE FROM CHECK_TRNS_PASSWORD WHERE PASSWORD_NUMBER` + every CHECK_TRNS_TYPE | SQL | action ALL_TRNS -> `check_all_trns` (FLAG left empty) |
| 5 | "إختيار الكل" / "استبعاد الكل" | CHOOSE_ALL_CH / CHOOSE_NONE_CH | action FLAGS -> `set_flags('CHECK_TRNS_PASSWORD')` |
| 6 | A group with grants cannot be deleted here | `SELECT 1 FROM CHECK_TRNS_PASSWORD / BANK_PASSWORD WHERE PASSWORD_NUMBER` | groups are deleted only in ACGROUP_COMPANY |

The .fmx also contains `DELETE FROM RAP_TRNS_PASSWORD R WHERE R.PASSWORD_NUMBER = :b1` (text copied from RAPPASS; it would clear the cashier
grants of the group) - treated as a copy / paste defect and not reproduced.

## Tests (t_se.py, rolled back)

K1 duplicate bank message.


## Wave 3b

BANK_PASSWORD.BANK_CODE (NAME_A display) and CHECK_TRNS_PASSWORD.TRNS_TYPE_CODE (RAP_TRNS_DESC display): lists of the legacy record groups (`SELECT CODE, NAME_A ... FROM BANK`, `SELECT TRNS_TYPE_CODE, DESC_A ... FROM CHECK_TRNS_TYPE`). Both tables are empty on the build copy (cheque system not installed); the SQL was run.

## Coverage

- Reproduced: rules 1-6. Not reproduced: the RAP_TRNS_PASSWORD delete above, print / translation buttons. (Wave 3b: bank / transaction lists with names.)
