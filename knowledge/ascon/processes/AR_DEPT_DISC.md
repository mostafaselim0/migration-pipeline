# AR_DEPT_DISC - ملف شرائح الخصم للأقسام / Discount Level for Departments

- Registry: system 4 serial 22 (`CODES_MENU.DISCLEVEL`). Legacy `ASCON\AR\FMB\ar_dept_disc.fmx` (no .fmb).
- APEX: corrected from a grid on `AR_CTGRY_DSCNT` to `MASTER_DETAIL`: department block `ST_CATEGORY_TYPE` (رقم القسم، البيان، عموله القسم)
  with its discount levels `AR_CTGRY_DSCNT` (`CTGRY_CODE = CATEGORY_TYPE_CODE`), as in the legacy form. Rules in `APP_RULES3_AR`.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| "رقم القسم لا يمكن ان يكون صفر او اقل" | message | row rule `ctgry_type_row` (only when the page is AR_DEPT_DISC) | high |
| duplicate department / level "سجل تم إدخاله من قبل." | `SELECT COUNT(1) ...`, message | primary key; row rule on insert of a level | high |
| discount period from `AR_PERIOD` | PERIOD_LOV | row rule `dscnt_row('CTGRY')` | high |
| "نسبة الخصم لا يمكن ان تكون اكبر من او تساوى 100", "قيمة الخصم لا يمكن ان تكون اقل من الصفر او اكبر من 99999.99" | messages | row rule | high |
| "لا يمكن إلغاء سجل رئيسي في و جود سجلات تابعة له" (`SELECT 1 FROM AR_CTGRY_DSCNT WHERE CTGRY_CODE`) | SQL, message | delete trigger `APP_RULES3_AR_CTGDSCNT_BD` on the document delete | high |

## Tests (rolled back)

Department 0 refused; repeated level refused; department with levels not deletable (batch 1).

## Coverage

- Reproduced: all of the above. `ST_CATEGORY_TYPE` is shared with ARTARGETRANGESCAT; the department-number rule applies only here.
- Not reproduced: FROM / TO of the period next to the serial (display only), print.
