# SUB_LG_COMPARE - مراقبة الانظمة الفرعية / Sub Ledger Monitor

- Registry: system 1 serial 88 (no menu entry, no order: the form is not reachable from the legacy menus). APEX list 10260,
  account page 10261, print 10262.
- Legacy module: `ASCON\AC\FMB\SUB_LG_COMPARE.fmx` (2016, no .fmb): "مراقبة الحسابات" with a setup part (الاعداد) and a comparison part.
- **Deliverable: screen correction + balances; the detailed comparison cannot be reconstructed.** Override
  `app\legacy\overrides\SUB_LG_COMPARE.json`: pattern `MASTER_DETAIL` SUB_LG_COMPARE -> SUB_LG_COMPARE_DET (joined on ACCOUNT_NUMBER,
  POST_SYSTEM), info panel with the balances; PL/SQL `APP_RULES3_GL.gl_balance / supp_balance / sub_ledger_text`.
- **Confidence: medium** (setup tables and the two balance queries are clear; the other sub-systems are not). Both tables are
  empty on the build copy and the asset (AS_*) and payroll (PY_*) modules have no data.

## What the screen is

For each monitored GL account (SUB_LG_COMPARE: account, linked system POST_SYSTEM, supplier / customer number prefix SUPP_BEGIN,
asset flags ASST_DPRCT_COLL (asset / depreciation / accumulated depreciation), payroll flags LOANS / TOTAL_DUES / EMP_TRNS /
PYS_FLAG, bank / branch / box / store / cost centre) and asset categories (SUB_LG_COMPARE_DET), "حساب الرصيد" shows the GL balance
next to the sub-ledger balance, "انزال البيانات" lists supplier transactions against their GL entries for a date range, and there
are account-statement / comparison reports and per-transaction post / cancel-post calls.

## Rules

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | GL balance = posted lines of the account without the closing entries | GET_ACCOUNT_BALANCE: `SUM(VALUE) ... NOT IN (... NVL(CLOSE_FLAG,0) = 1)` | info "الرصيد" (`gl_balance`) |
| 2 | Supplier sub-ledger balance (linked system 5) = SUM(±TOTAL_VALUE x CURRENCY_RATE) by VN_TRNSTYPE.EFFECT of the suppliers whose number starts with SUPP_BEGIN | GET_SUPP_BALANCE SQL | info "رصيد النظام الفرعي" (`supp_balance`) and the difference |
| 3 | Asset categories of an account: leaf categories not yet used for the account / system | CTGRY_LOV SQL | detail grid (list of values not generated) |
| 4 | Changing the linked system deletes the account's categories | `DELETE FROM SUB_LG_COMPARE_DET WHERE ACCOUNT_NUMBER AND POST_SYSTEM` | not reproduced (the detail follows the master key) |

## Cannot reconstruct (questions)

- Asset balance (GET_ASST_BALANCE) and payroll balance (GET_PY_BALANCE): the SQL pieces are visible (purchases, additions,
  exclusions, depreciation history, loans and salary slips) but not how they are combined per flag. Are these comparisons used?
  (no data in AS_* / PY_* on this database.)
- The supplier difference listing (GET_SUPP_DIFF into block VN_AC_COMPARE, with per-line post / cancel-post calls of VNACUPDT /
  VNACCUPDT) needs a report region with parameters on the account page (generator request) and the key user's confirmation that the
  screen is used at all (it has no menu entry).

## Wave 3b (record groups of `evidence\SUB_LG_COMPARE.md`)

| Item | Legacy | APEX |
|------|--------|------|
| POST_SYSTEM | list from `SELECT SYSTEM_DESC_A, TO_CHAR(SYSTEM_NUMBER) FROM SYS_SYSTEMS ORDER BY SYSTEM_NUMBER` | `lov` (select list) |
| BANK_CODE / BRANCH_CODE | `SELECT CODE, NAME_A FROM BANK`; `SELECT CODE, DESC_A FROM BANK_BRANCHS WHERE BANK_CODE = :BANK_CODE` | `lov`; branches of the chosen bank (`cascade: BANK_CODE`) - the generator had given BRANCH_CODE the company-branch list |
| ASST_DPRCT_COLL | 1 asset / 2 depreciation / 3 accumulated depreciation (DECODE(ASST_DPRCT_COLL, ...) in GET_ASST_BALANCE) | static list حساب الاصل / اهلاك الاصل / مجمع الاهلاك |
| LOANS, TOTAL_DUES, EMP_TRNS, PYS_FLAG | on / off flags (`WHERE 1 = (SELECT NVL(LOANS,0) ...)`) | `widget: CHECK` 1 / 0 (the item type is not visible in the .fmx; the SQL only tests = 1) |
| Categories grid CTGRY_CD_ASCT | CTGRY_LOV: leaf categories of AS_CTGRY of the row's category type | `lov` with `cascade: CTGRY_TYPE_ASCT` (the legacy also hid categories already used for the account; not reproduced, a saved code would not display) |

Bank, branch and asset tables are empty on the build copy; the SQL was run (no rows).

## Coverage

- Reproduced: setup (master + categories), rules 1-2 as displays, rule 3 as the category list (wave 3b).
- Not reproduced: rule 3's "not yet used" filter, rule 4, asset / payroll balances, the difference listing, reports "كشف حساب" / "تقرير المقارنة", post / cancel
  post calls (other screens: VNACUPDT / VNACCUPDT).
