# PYPASS - صلاحيات المجموعات--الموارد البشرية / Group Privilege (Payroll Systems)

- Registry: system 99 serial 37 (PRIVILIAGE_MENU, order 3008). APEX list page 80140, document page 80141.
- Legacy module: `ASCON\SE\FMB\PYPASS.fmx` (+ `PYPASS_dept.fmx`). Master PASSWORD, blocks PY_DEPT_HIER_PASSWORD (صلاحية الهيكل الادارى: company,
  structure), PY_DEPT_PASSWORD (من / إلى رقم قسم), PY_EMPLOYEE_PASSWORD (من / إلى رقم موظف).
- **Deliverable: (a) screen correction + rules + button** - `app\legacy\overrides\PYPASS.json` (MASTER_DETAIL PASSWORD with the three blocks; the
  generator had placed only the first), package `APP_RULES3_SE`.
- **Confidence: high** for the rules; the payroll system is not installed here (PY_DEPT_HIER is empty, no system 60 / 61).

## Rules and buttons

| # | Legacy rule / button | Evidence | APEX |
|---|---|---|---|
| 1 | "تم إدخال هذا الهيكل من قبل" | `SELECT COUNT(1) FROM PY_DEPT_HIER_PASSWORD WHERE PASSWORD_NUMBER AND COMPANY_CODE AND D_CODE` + message | row rule `dup_row` |
| 2 | Structure must be typed | D_CODE, PK column | key_expr `required` (and made visible) |
| 3 | Structure list: PY_DEPT_HIER of the company not yet granted | D_CODE_RG | PK refuses duplicates (no list: composite key) |
| 4 | "كل الهياكل": every structure of every company not yet granted | ALL_PY_DEPT_PUSH, `SELECT COMPANY_CODE, D_CODE, ... FROM PY_DEPT_HIER WHERE (D_CODE, COMPANY_CODE) NOT IN (...)` | action ALL_DEPT -> `py_all_dept` |
| 5 | A group with structures cannot be deleted here | `SELECT 1 FROM PY_DEPT_HIER_PASSWORD P WHERE P.PASSWORD_NUMBER` | groups are deleted only in ACGROUP_COMPANY |

## Tests (t_se.py, rolled back)

Y1 duplicate structure message, Y2 structure required.


## Wave 3b

PY_DEPT_HIER_PASSWORD.D_CODE (D_NAME display): list of the legacy record group `SELECT D_CODE, D_NAME ... FROM PY_DEPT_HIER WHERE COMPANY_CODE = :COMPANY_CODE`, limited to the row's company (`cascade: COMPANY_CODE`). PY_DEPT_HIER is empty on the build copy (payroll not installed); SQL run.

## Coverage

- Reproduced: rules 1-5; the department / employee range blocks as grids (one row per group, PK PASSWORD_NUMBER).
- Not reproduced: print / translation buttons. (Wave 3b: structure list with names per company; companies had their list.)
