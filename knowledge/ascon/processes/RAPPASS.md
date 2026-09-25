# RAPPASS - صلاحيات المجموعات - المقبوضات والمدفوعات / Group Privilege (Cashier systems)

- Registry: system 99 serial 36 (PRIVILIAGE_MENU, order 3006). APEX list page 80120, document page 80121.
- Legacy module: `ASCON\SE\FMB\RAPPASS.fmx`. Master PASSWORD, tabs RP_BOXS_PASSWORD (سرية الصناديق), RAP_TRNS_PASSWORD (سرية الحركات, FLAG "اساسي").
- **Deliverable: (b) rules + buttons on the generated screen** - `app\legacy\overrides\RAPPASS.json` (AUTO), package `APP_RULES3_SE`.
- **Confidence: high** for the rules; the cashier system is not installed in this database (RP_BOXS, RP_TRNS_TYPE are empty; no system in SYS_SYSTEMS).

## Rules and buttons

| # | Legacy rule / button | Evidence | APEX |
|---|---|---|---|
| 1 | "تم إدخال هذا الصندوق لهذا المستخدم من قبل" | `SELECT COUNT(1) FROM RP_BOXS_PASSWORD WHERE PASSWORD_NUMBER AND BOX_CODE` + message | row rule `dup_row` (inserting) |
| 2 | Box number must be typed | BOX_CODE item, PK column | key_expr `required` |
| 3 | "كل الصناديق": every box not yet granted | ALL_BOX, `SELECT BOX_CODE, NAME_A, NAME_E FROM RP_BOXS ORDER BY BOX_CODE` | action ALL_BOXES -> `rap_all_boxes` |
| 4 | "كل الحركات": `DELETE FROM RAP_TRNS_PASSWORD WHERE PASSWORD_NUMBER` + every RP_TRNS_TYPE | SQL | action ALL_TRNS -> `rap_all_trns` (FLAG left empty: the value set by the legacy loop is not visible) |
| 5 | "إختيار الكل" / "استبعاد الكل" | CHOOSE_ALL_RP / CHOOSE_NONE_RP | action FLAGS -> `set_flags('RAP_TRNS_PASSWORD')` |
| 6 | A group with boxes cannot be deleted here | `SELECT 1 FROM RP_BOXS_PASSWORD R WHERE R.PASSWORD_NUMBER` | groups are deleted only in ACGROUP_COMPANY |

## Tests (t_se.py, rolled back)

R1 duplicate box message, R2 box required, R3 the two "all" buttons run (0 rows: no boxes / types defined).

## Open questions

1. Which FLAG ("اساسي") did "كل الحركات" give the new rows?


## Wave 3b

RAP_TRNS_PASSWORD.TRNS_TYPE_CODE (RAP_TRNS_DESC display): list of the legacy record group `SELECT TRNS_TYPE_CODE, DESC_A ... FROM RP_TRNS_TYPE` (empty on the build copy; SQL run). The box column already had its list.

## Coverage

- Reproduced: rules 1-6. Not reproduced: print / translation buttons. (Wave 3b: transaction list with names; boxes had their list.)
