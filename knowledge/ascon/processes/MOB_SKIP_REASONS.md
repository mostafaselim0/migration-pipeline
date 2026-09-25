# MOB_SKIP_REASONS - ملف اسباب التخطي / Skip Reasons File

- Registry: system 4 serial 44 (no menu). Legacy `ASCON\AR\FMB\Mob_Skip_Reasons.fmx` (no .fmb, no labels). Table empty.
- APEX: generated grid on `MOB_SKIP_REASONS` (page 30340) kept; rules in `APP_RULES3_AR`.
- What it is: reasons a mobile salesman can give for skipping an operation at a customer (collection, sales, return, sales order, stock count).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| `SKIP_CODE = NVL(MAX(TO_NUMBER(SKIP_CODE)),0)+1` (character key) | embedded SQL | `key_expr` `next_skip_code` (the generator fills numeric keys only) | high |
| operation list `OP_CODE`: التحصيل = COL, المبيعات = SLSI, المرتجع = SLSR, امر البيع = SLSO, الجرد = STCNT (block ordered by OP_CODE, SKIP_CODE) | list elements in the .fmx | row rule `skip_reason_row` (value must be one of them) + label listing the codes | high |
| labels (الأسم عربى / الأسم لاتينى / الارتباط) | .fmx texts | `add_columns` | high |

## Tests (rolled back)

Code = max+1 as text; unknown operation refused (batch 1).

## Coverage

- Reproduced: numbering, operation values, labels.
- Not reproduced: the operation as a drop-down list (generator has no static-list override; the value is validated instead).
