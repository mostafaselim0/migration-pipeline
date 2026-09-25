# ARCUST_CLASS - ملف فئات العملاء / Customers Classes File

- Registry: system 4 serial 23 (`CODES_MENU.FACTION`). Legacy `ASCON\AR\FMB\arcust_class.fmx` (no .fmb).
- APEX: generated master-detail `AR_CUST_CLASS` / `AR_CUST_CLASS_DSCNT` (pages 30090-30092) kept; rules in `APP_RULES3_AR`. 5 classes.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| `SERIAL = NVL(MAX(SERIAL),0)+1` | SQL | generated key | high |
| "قيمة حد الإئتمان لا يمكن ان تكون اقل من الصفر او اكبر من 999999999990.99" | message | row rule `cust_class_row` | high |
| discount period from `AR_PERIOD` | PERIOD_LOV | row rule `dscnt_row('CLASS')` (+ foreign key) | high |
| "شريحة الخصم مكررة لنفس الفئة" | `SELECT COUNT(1) ... WHERE SERIAL AND PERIOD_SERIAL`, message | row rule on insert (+ primary key) | high |
| "نسبة الخصم لا يمكن ان تكون اكبر من او تساوى 100" | message | row rule | high |
| "قيمة الخصم لا يمكن ان تكون اقل من الصفر او اكبر من 99999.99" | message | row rule | high |
| deleting a class deletes its periods (`DELETE FROM AR_CUST_CLASS_DSCNT WHERE SERIAL`) | SQL | document delete cascade (generated) | high |

## Tests (rolled back)

Negative credit limit refused; repeated period refused; percent 100 refused; value 100000 refused; unknown period refused (batch 1).

## Coverage

- Reproduced: all of the above. The stop flag / date / reason of the class have no rule in the evidence (plain fields).
- Not reproduced: FROM / TO of the period shown next to the period serial (display items; the generator shows the serial only), print.
