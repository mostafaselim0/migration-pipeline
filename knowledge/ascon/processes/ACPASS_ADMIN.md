# ACPASS_ADMIN - صلاحيات المجموعات--الحسابات / Group Privilege (Accounts)

- Registry: system 99 serial 9 (PRIVILIAGE_MENU.ACGROUP_ACCOUNTS, order 3002). APEX list page 80080, document page 80081.
- Legacy module: `ASCON\SE\FMB\Acpass_admin.fmx` (no .fmb). Blocks PASSWORD (group) -> GROUP_COMPANY (companies of the group, "يرحل ام لا")
  -> per company: AC_PASSWORD_ENTRY (journals), AC_PASSWORD_MASTER (accounts), AC_PASSWORD_COST1 / COST2 (cost centres), AC_PASSWORD_EST_PERIOD.
- **Deliverable: (b) rules + buttons on the generated screen** - `app\legacy\overrides\ACPASS_ADMIN.json` (pattern AUTO: the generator flattens
  the three levels, every grant grid carries COMPANY_CODE), package `APP_RULES3_SE` + three compound delete triggers.
- **Confidence: high** for derivations, buttons and sub-account deletion; medium for the relation check of rule 6.

These grants restrict the GL screens and posting of the APEX application (APP_RULES_GL.check_header / after_save_entry, APP_PROC_GL, APP_RULES_AR).

## Rules and buttons

| # | Legacy rule / button | Evidence | APEX |
|---|---|---|---|
| 1 | ACCOUNT_LEVEL = AC_MASTER.ACCOUNT_LEVEL, ACCOUNT_END_POS = AC_CHART_STRUCTURES.CHR_STRU_END of the level (cost centres: AC_COST_CENTERS(2).COST_LEVEL, AC_COST_STRCTURES.COST_STR_END with COST_CENTER_NUMBER 1 / 2) | `SELECT ACCOUNT_LEVEL FROM AC_MASTER`, `SELECT CHR_STRU_LEVEL, CHR_STRU_END ...`, same for cost centres; all 62 AC_PASSWORD_MASTER rows follow it | row rules `account_row` / `cost_row`; the four columns read-only and optional in the grids |
| 2 | "جميع الحركات / الحسابات / مركز التكلفة 1 / 2 / جميع الفترات": the group's grants of the company are replaced by everything the company has | ALL_*_BUT: `DELETE FROM AC_PASSWORD_x WHERE PASSWORD_NUMBER AND COMPANY_CODE` + `SELECT ... WHERE ... IN (SELECT FROM AC_COMPANY_x WHERE COMPANY_CODE)` | action GRANT_ALL (params company of the group, kind) -> `ac_grant_all` |
| 3 | "إضافة الحسابات الرئيسيه للحسابات الفرعيه المضافه" / "إضافة مراكز التكلفة الرئيسيه ...": for every granted account above level 1, each parent `RPAD(SUBSTR(acc, 1, end of level - i), 12, 0)` (cost centres 9) is added to AC_COMPANY_* and to the group when missing | PUSH_BUTTON138 / ITEM149 SQL | action ADD_PARENTS (company, kind) -> `ac_add_parents` |
| 4 | Deleting a main account: "انت على وشك حذف حساب رئيسى -سوف يتم حذف كل الحسابات الفرعيه التابعه له" -> `DELETE FROM AC_PASSWORD_MASTER WHERE SUBSTR(ACCOUNT_NUMBER,1,end) = SUBSTR(:acc,1,end) AND COMPANY_CODE AND PASSWORD_NUMBER` (same for cost centres) | alert texts + SQL | compound delete triggers `APP_RULES3_SE_PWM_CD / _PWC1_CD / _PWC2_CD` (ACPASS_ADMIN only): after the grid delete the sub accounts of the same company and group are deleted (no extra confirmation: the grid delete is the confirmation) |
| 5 | Lists: only accounts / journals / centres / periods of the company (AC_COMPANY_*) | record groups | declared composite FKs AC_PASSWORD_* -> AC_COMPANY_* refuse the others |
| 6 | A company cannot leave the group while the group has GL grants of it | `SELECT 1 FROM AC_PASSWORD_ENTRY / MASTER / COST1 / COST2 / EST_PERIOD WHERE COMPANY_CODE = :b1` (relation check) | delete hook `APP_RULES3_SE_GRPCOMP_BD` -> `group_company_delete` (same group) |
| 7 | A group with grants cannot be deleted here | `SELECT 1 FROM AC_PASSWORD_* / GROUP_COMPANY WHERE PASSWORD_NUMBER` | groups are deleted only in ACGROUP_COMPANY (`password_delete`) |

## Tests (t_se.py, rolled back)

P0-P9: derived level 6 / end 12 on insert; add main accounts gives the chain of levels 1-6; deleting the level-3 parent leaves levels 1-2;
grant all accounts = 328 (company 1), all journals = 10; company outside the group refused; cost centres 2: level / end derived, parents 1-3 added;
company with grants cannot leave the group; group delete refused on this page.

## Open questions

1. Rule 6: the legacy relation query has only `COMPANY_CODE = :b1` (grants of any group would block). APEX checks the grants of the same group.
2. The .fmx also counts the remaining sub accounts of the parent after a delete (`SELECT COUNT(1) ... AND ACCOUNT_NUMBER != :b2`, levels `:b1 - :b2`)
   and deletes a single account afterwards; this looks like removing a parent left without sub accounts, but the evidence is not conclusive - not
   reproduced. Confirm with the vendor.

## Wave 3b (lists of the legacy record groups)

Each grant grid now has the legacy list of its block, limited to what the row's company has (AC_COMPANY_*; `:PAGE_COMPANY_CODE` with
`cascade: COMPANY_CODE`), shown as "code - name" (the legacy name display items ENTRY_DESC / ACCOUNT_NAME / COST_DESC / PERIOD_DESC):

| Grid | List (evidence: record groups of `evidence\ACPASS_ADMIN.md`) |
|------|------|
| AC_PASSWORD_ENTRY.ENTRY_TYPE | AC_TRN_CODES of the row's year granted to the company (AC_COMPANY_ENTRY); `cascade: [ENTRY_YEAR, COMPANY_CODE]` |
| AC_PASSWORD_MASTER.ACCOUNT_NUMBER | AC_MASTER accounts of AC_COMPANY_MASTER |
| AC_PASSWORD_COST1.COST_CODE | AC_COST_CENTERS of AC_COMPANY_COST1 |
| AC_PASSWORD_COST2.COST_CODE | **AC_COST_CENTERS2** of AC_COMPANY_COST2 (the generator had given the cost-centre-1 list) |
| AC_PASSWORD_EST_PERIOD.PERIOD_CODE | **AC_ESTIMATE_PERIODS** of AC_COMPANY_EST_PERIOD (the generator had given the ST_PERIODS list) |

The legacy lists also hid what the group already has (`NOT IN (... AC_PASSWORD_* WHERE PASSWORD_NUMBER)`); that part is left out so that the
saved rows keep showing their names (the primary keys refuse a duplicate). Checked with company 1 on the build copy (journals 101 / 102 /
104, accounts, cost centres 1; AC_COMPANY_COST2 is empty). Label of the cost-centre-2 level corrected.

## Coverage

- Reproduced: rules 1-7, buttons ALL_TRNS / ALL_ACC / ALL_COST1 / ALL_COST2 / ALL_PERIOD (one action with a kind list) and the two "add main" buttons;
  the grant lists with names (wave 3b).
- Not reproduced / limits: the three-level layout (flattened, COMPANY_CODE per row), the parent pruning of question 2.
