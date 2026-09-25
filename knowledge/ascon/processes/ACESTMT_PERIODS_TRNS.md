# ACESTMT_PERIODS_TRNS - إعداد الموازنة التقديرية / Estimated Budget Preparation

- Registry: system 1 serial 9 (order 1202). APEX list 10060, budget page 10061, print 10062.
- Legacy module: `ASCON\AC\FMB\acestmt_periods_trns.fmx` (no .fmb): budget header AC_ESTIMATE_CODES, tab "حسابات الموازنة"
  (AC_ESTIMATE_MAST: account + cost centres) and tab "فترات الموازنة" (AC_ESTIMATE_DET: period values of the selected account line).
- **Deliverable: generated master-detail kept (`AUTO`) + rules + 2 buttons**, override `app\legacy\overrides\ACESTMT_PERIODS_TRNS.json`,
  PL/SQL `APP_RULES3_GL`, delete hook `APP_RULES3_GL_ESTM_BD`.
- **Confidence: high** for the copy SQL (embedded INSERT ... SELECT), medium for the account / cost-centre checks (LOV based).
  The budget tables are empty on the build copy (1 budget code, no lines).

## Structure

The legacy nests three levels (budget -> account line -> period values). The generator shows one level of detail, so the period
values are a second grid of the budget linked to the account line by MAST_SERIAL (the account line number is now shown in the
account grid, read-only). Generator request: a detail of a detail.

## Rules and buttons

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | Budget code = MAX + 1, not negative ("كود الميزانية لا يمكن أن يكون أقل من الصفر"), unique ("لا يمكنك إدخال كود ميزانية مكرر") | `SELECT NVL(MAX(EST_CODE),0)+1`, `COUNT(1) ... WHERE EST_CODE` | generated max+1 + PK; validation `check_budget` |
| 2 | Account line: sub account granted to the group, active cost centres | ACCOUNT_LOV (ACCOUNT_STATUS = 1, AC_PASSWORD_MASTER), COST_CENTERS(2)_LOV (COST_STATUS = 1), `SELECT NULL FROM AC_COST_CENTERS WHERE ... COST_STATUS = 1` | row rule `budget_mast_row` ("الحساب ليس حساب فرعى", "لا توجد صلاحية للحساب", new texts for the cost centres); cost centre 2 is checked against AC_COST_CENTERS2 (the legacy query read AC_COST_CENTERS twice) |
| 3 | Account line not repeated for the same account and cost centres ("سجل مكرر"); account line number MAX + 1 per budget | `COUNT(1) FROM AC_ESTIMATE_MAST WHERE EST_CODE, ACCOUNT_NUMBER, COST_CODE(2)` (null-safe), `NVL(MAX(SERIAL),0)+1` | after_save `budget_after_save`; generated max+1 |
| 4 | Period values: period code not negative ("كود الفترة لا يمكن أن يكون أقل من الصفر"), one value per period and account line ("رقم الحساب مكرر مع الفتره"), value line number MAX + 1; debit / credit not both ("لا يمكن ادخال مدين ودائن معاً") | `COUNT(1) FROM AC_ESTIMATE_DET WHERE EST_CODE, MAST_SERIAL, PERIOD_CODE`, `NVL(MAX(SERIAL),0)+1` | row rule `budget_det_row`, after_save, generated max+1; debit / credit columns of the generator store debit - credit |
| 5 | "نسخ الموازنة": new budget MAX + 1 with the same name, account lines and period values ("تم نسخ الميزانية برقم") | INSERT ... SELECT of AC_ESTIMATE_CODES / MAST / DET | action COPY, opens the new budget |
| 6 | "عمل موازنة جديده مقارنة مع الفعلي": new budget whose period values are (budget + actual) / 2, actual = SUM(VALUE * RATE) of the posted lines of the account and cost centres in the period dates ("تم عمل الميزانية برقم") | embedded SQL (SUM(VALUE*RATE) ... BETWEEN FROM_DATE AND TILL_DATE ..., INSERT ... (NVL(VALUE,0)+NVL(:actual,0))/2) | action ACTUAL, opens the new budget |
| 7 | Deleting a budget deletes its lines | master-detail relation | generated line delete; the delete hook removes the period values of each account line first when the whole budget is deleted (REQUEST DELETE); a single account line with values is still refused (FK) |

## Tests (section H of `tmp\w3_gl\gl\t_gl.py`, 13 checks)

Negative code; main account, main cost centre 1 / 2 refused; account line numbered 1; negative period refused; duplicate account
line and duplicate period refused by the save check; copy (code + 1, same lines / value, message); budget from actual = (1000 +
actual of 310101001001 / 102002000 in Q1 2026) / 2; whole-budget delete; single line with values refused. Passed.

## Wave 3b

- Period grid: MAST_SERIAL (the account line the period values belong to - the legacy nested the period block under the account line)
  is now a select list of the account lines of this budget ("serial - account name", `:PAGE_EST_CODE` with `cascade: EST_CODE`), so the
  line is chosen instead of typed.
- Period dates FROM_DATE / TILL_DATE (display items of the period tab): computed grid columns from AC_ESTIMATE_PERIODS.
- The SQL was run on the build copy (the budget tables are empty, so the lists return no rows).

## Coverage

- Reproduced: rules 1-7; account-line list and period dates of the period grid (wave 3b).
- Not reproduced: the both-debit-and-credit refusal (the generated debit / credit grid stores one signed value); the SUM_DEBIT /
  SUM_CREDIT totals of the period tab (not per row); the third nesting level itself (the period grid is a second detail of the budget).
