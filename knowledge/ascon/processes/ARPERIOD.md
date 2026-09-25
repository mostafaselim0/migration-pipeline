# ARPERIOD - ملف فترات أيام الخصم / Discount Days Period File

- Registry: system 4 serial 21 (`CODES_MENU.DISDAY`). Legacy module `ASCON\AR\FMB\arperiod.fmx` (no .fmb).
- APEX: generated grid on `AR_PERIOD` (page 30070) kept (`"pattern": "AUTO"`); rules in `APP_RULES3_AR` (`app\db\25_rules3_ar.sql`).
- Data: 1 row (0 .. 1). The periods are referenced by the discount levels of classes, departments, customers and transaction types.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| `SERIAL = NVL(MAX(SERIAL),0)+1` | embedded SQL | generated max+1 key (same rule), read-only | high |
| `FROM_P = NVL(MAX(TO_P),-1)+1` (display item) | embedded SQL, item type D | row rule `period_row` on insert; read-only, not required | high |
| no new period while one is open (`COUNT(1) ... WHERE TO_P IS NULL`) | embedded SQL | row rule; message is ours (no legacy text found for this check) | medium |
| "الفترة الى يجب أن يكون أكبر من الفترة من" (TO > FROM) | .fmx message | row rule (insert and update) | high |
| "يجب حذف أخر مسلسل أولا" (only the last serial can be deleted) | .fmx message, `SELECT NVL(MAX(SERIAL),0)` | compound delete trigger `APP_RULES3_AR_PERIOD_BD` | high |

## Tests (rolled back)

New period gets serial 2 and FROM 2; TO <= FROM refused (insert and update); open period blocks a new one; middle serial delete refused,
last serial deleted.

## Coverage

- Reproduced: numbering, derived FROM, TO > FROM, open-period check, last-serial delete.
- Not reproduced: print button (report `PRINT_BTN`, covered by the report pages), Forms navigation / toolbar.
