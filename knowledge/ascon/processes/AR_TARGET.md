# AR_TARGET - ادخال المستهدف السنوي / Target Plan File

- Registry: system 4 serial 34 (no menu). Legacy `ASCON\AR\FMB\Ar_Target.fmx` (no .fmb, no labels).
- APEX: corrected from a grid on `AR_ALL_TARGET_CUST` (an unrelated empty table) to a grid on `AR_ALL_TARGET`, the table the legacy form
  writes (tabs مستهدف العملاء / المناديب / الاصناف / الفترات, months يناير .. ديسمبر). Rules in `APP_RULES3_AR`. 4 rows (customer targets
  of 2021/2022 incl. two monthly ones).
- The targets are read by the CUSTOMER screen (sales vs target), the customer dues (monthly target and percentages 100% / 110%) and reports.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| `ALL_SERIAL = NVL(MAX(ALL_SERIAL),0)+1` | SQL (in every tab) | generated key | high |
| "ادخال مكرر": one target per year and customer / salesman / item / period (and month) | `SELECT COUNT(1) FROM AR_ALL_TARGET WHERE T_YEAR AND CUSTOMER_ID ... IS NULL` (4 variants), message | compound trigger `APP_RULES3_AR_TARGET_AIU` (after insert / update) | high |
| a target is for one customer, one salesman or one item (the tabs) | the four SQL variants | row rule `target_row`; message is ours | high |
| customer: active leaf; salesman: not stopped; item: active, group derived | LOVs | row rule | high |
| period = month 1..12 | month texts | row rule | high |

## Tests (rolled back)

Serial; duplicate customer target; monthly target of the same customer accepted; month 13 refused; customer + salesman refused; stopped
salesman refused; item group derived; period target changed into a duplicate refused (batch 5, 23 checks with the next two screens).

## Coverage

- Reproduced: all rules; one grid instead of four tabs (the kind is given by the filled column).
- Not reproduced: the item LOV's supplier column (display only).
