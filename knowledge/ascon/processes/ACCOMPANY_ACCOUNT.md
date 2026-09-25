# ACCOMPANY_ACCOUNT - صلاحيات الشركات - الحسابات / Company Privilege -- Accounts

- Registry: system 99 serial 8 (PRIVILIAGE_MENU.AC_COMPANY, order 3001). APEX list page 80070, document page 80071.
- Legacy module: `ASCON\SE\FMB\AcCompany_Account.fmx`. Master COMPANY, tabs AC_COMPANY_ENTRY (ارقام الحركات), AC_COMPANY_MASTER (ارقام الحسابات),
  AC_COMPANY_COST1 / COST2 (مراكز التكلفة), AC_COMPANY_EST_PERIOD (الفترات التقديرية).
- **Deliverable: (b) rules + button on the generated screen** - `app\legacy\overrides\ACCOMPANY_ACCOUNT.json` (AUTO), package `APP_RULES3_SE`.
- **Confidence: high.**

The company-level lists are the pool from which ACPASS_ADMIN grants groups (composite FKs AC_PASSWORD_* -> AC_COMPANY_*).

## Rules and buttons

| # | Legacy rule / button | Evidence | APEX |
|---|---|---|---|
| 1 | ACCOUNT_LEVEL / ACCOUNT_END_POS (COST_LEVEL / COST_END_POS) derived from the chart and its structure | `SELECT ACCOUNT_LEVEL FROM AC_MASTER`, `SELECT CHR_STRU_LEVEL, CHR_STRU_END ...`, `SELECT COST_STR_LEVEL, COST_STR_END ... COST_CENTER_NUMBER = 1 / 2`; 328 / 328 rows follow it | row rules `account_row` / `cost_row` (the columns are not on the page, as in the legacy) |
| 2 | "جميع الحركات / الحسابات / مركز التكلفة 1 / 2 / فترات تقديريه": every journal / account / centre / period not yet in the company | ALL_*_BUT, record groups `... NOT IN (SELECT ... FROM AC_COMPANY_x WHERE COMPANY_CODE = :b2)` | action ALL_OF_KIND (param kind) -> `ac_company_all` |
| 3 | Lists exclude rows already in the company | record groups | PK refuses duplicates |
| 4 | Company-level rows still granted to a group cannot be removed | relation checks `SELECT 1 FROM AC_PASSWORD_* WHERE COMPANY_CODE` | FKs AC_PASSWORD_* -> AC_COMPANY_* refuse the delete |
| 5 | Companies are maintained in the companies screen | - | company delete refused here (`company_delete`, owner screen COMPANY) |

## Tests (t_se.py, rolled back)

C6 all journals 15, accounts 328, cost centres 9 / 28 for company 1 after clearing it; C7 levels / end positions correct; C8 row rule on a
typed account; C9 company delete refused on this page.


## Wave 3b

AC_COMPANY_ENTRY.ENTRY_TYPE (ENTRY_DESC display): list of the legacy record group (AC_TRN_CODES with the serial kind 'مسلسل سنوي' / 'مسلسل شهري'), limited to the row's year (`:PAGE_ENTRY_YEAR`, `cascade: ENTRY_YEAR`). Checked for 2026 (101 يومية عامة (مسلسل شهري) ...). The other grids already had their lists.

## Coverage

- Reproduced: rules 1-5 and the five buttons (one action with a kind list).
- Not reproduced: print / translation buttons. (Wave 3b: journal list per year with the SERIAL_DESC text; accounts, cost centres and periods
  had their lists.)
