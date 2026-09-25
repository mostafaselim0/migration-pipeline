# ACGROUP_COMPANY - المجموعات / Groups

- Registry: system 99 serial 4 (USERS_MENU.GROUPS, order 2001). APEX list page 80040, document page 80041, print 80042.
- Legacy module: `ASCON\SE\FMB\AcGroup_company.fmx` (no .fmb). Blocks GROUPS (base view on PASSWORD) and GROUP_COMPANY, CONTROL buttons.
- **Deliverable: (a) screen correction + rules + buttons** - `app\legacy\overrides\ACGROUP_COMPANY.json` (MASTER_DETAIL PASSWORD -> GROUP_COMPANY;
  the generator had produced a read-only grid on the GROUPS view), package `APP_RULES3_SE`.
- **Confidence: high** (group delete list, copy, all companies, default company); medium for the copy tables list (see question 1).

## Rules and buttons

| # | Legacy rule / button | Evidence | APEX |
|---|---|---|---|
| 1 | The group is edited through the GROUPS view (PASSWORD_NUMBER, names, CHANGE_DATE "تغير تاريخ الحركة في المقبوضات") | labels GROUPS.*; view text `SELECT ... FROM PASSWORD` | master = table PASSWORD (same columns) |
| 2 | Deleting a group deletes its data grants in every system (29 tables: VN_, AS_, AR_, ST_, RP_, RAP_, PY_, PD_, MN_, CSTD_, CHECK_, BANK_, AC_PASSWORD_*) | PRE-DELETE SQL list | delete hook `APP_RULES3_SE_PASSWORD_BD` -> `password_delete` (companies are removed by the page cascade first; GROUP_USERS rows still block the delete through their FK, as in the legacy) |
| 3 | Groups are deleted only here | the privilege screens (ACPASS_ADMIN, SEPASS_TRN, ARPASS, ...) refuse a group with grants ("Cannot delete master record ...") | `password_delete` refuses on the other screens (their cascade would have removed that screen's grants first) |
| 4 | "جميع الشركات": all companies not in the group; a group other than 0 only the session company | ALL_COMP_BUT, AC_COMPANY_CODE_RG `(COMPANY_CODE = :GLOBAL.COMPANY_CODE OR :GLOBAL.PASSWORD_NUMBER = 0)` | action ALL_COMPANIES -> `all_companies` (ISDEFAULT 'N') |
| 5 | Company list restriction for groups other than 0 | AC_COMPANY_CODE_RG | row rule `group_company_row` (ACGROUP_COMPANY only) |
| 6 | One default company per group ("أساسى") | VAR1 / VAR2 identifiers (same ISDEFAULT trigger as the users screen) | row rule + after-save `fix_default_company` (APP_SEC.post_auth takes the default company of the default group) |
| 7 | "نسخ صلاحيات" من مجموعة: COPY_TABLE builds `INSERT INTO <t> (cols) SELECT cols FROM <t> WHERE PASSWORD_NUMBER = :from` from USER_TAB_COLUMNS; "تم نسخ صلاحية المجموعة" | `SELECT COLUMN_NAME FROM USER_TAB_COLUMNS WHERE TABLE_NAME = :b1`, `INSERT INTO`, `SELECT`, FROM_GROUP, message | action COPY_GROUP (param FROM_GROUP) -> `copy_group_rights`: for each grant table of rule 2 the group's rows are replaced by the other group's |
| 8 | "يجب الحفظ اولا ثم ادخال رقم المستخدم" | message | action regions appear only on a saved group |

## Tests (t_se.py, rolled back)

G1 all companies; G2 group 101 / company 5 may not add company 1; G3 default company; G4 copy of group 0 (62 account and 2 cost-centre grants,
all tables equal); G5 deleting the group on this screen removes its grants in every system; P9 the same delete on ACPASS_ADMIN is refused.

## Open questions

1. The copy tables are not listed in the .fmx (dynamic SQL): APEX copies the 29 grant tables of the delete list and replaces the target rows
   first (otherwise the primary keys would refuse the copy). Confirm that the legacy also replaced (not merged) the grants.


## Wave 3b

The five buttons نظام العملاء / نظام الموردين / نظام المخزون / نظام شئون الموظفين / نظام الحسابات only opened the privilege screen of the system for the group (.fmx identifiers ARPASS, VNPASS, SEPASS_TRN, PYPASS, ACPASS_ADMIN and the texts): `links` to the document page of that screen on the same group (all use the PASSWORD table: the ROWID of the group is passed). Shown for a saved group; the target page applies its own rights.

## Coverage

- Reproduced: rules 1-8; the buttons that open the privilege screens of each system (links, wave 3b).
- Not reproduced: print buttons (GROUP_COMPANY reports), WEBUTIL / translation buttons.
