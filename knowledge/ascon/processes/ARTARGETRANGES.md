# ARTARGETRANGES - مدى المستهدف والعمولات المناظرة / Target and Commissions

- Registry: system 4 serial 25 (`CODES_MENU.AR_TARGET_RANGES`). Legacy `ASCON\AR\FMB\ArTargetRanges.fmx` (no .fmb).
- APEX: generated grid on `AR_TARGET_RANGES` (page 30240) kept; rules in `APP_RULES3_AR`. Table empty in the build copy.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| `SERIAL = NVL(MAX(SERIAL),0)+1 WHERE T_YEAR AND T_QURT` | embedded SQL | generated max+1 key per year and period | high |
| `FROM_T = MAX(TO_T)+1` of the year / period (0 for the first range) | embedded SQL | row rule `trange_row`; FROM read-only | medium (first value 0 inferred) |
| "الفترة الى يجب أن يكون أكبر من الفترة من" | .fmx message | row rule | high |
| "يجب التعديل فى أخر سجل فقط" / "يجب حذف أخر سجل أولا" | .fmx messages | compound trigger `APP_RULES3_AR_TRANGE_BUD` | high |
| period required | "لا بد من وجود رقم فترة لكي تتم طباعة التقرير", S_QURT navigation | row rule (`T_QURT` required) | high |
| labels: "نسبة العمولة 100%" (`PRCNT`), "نسبة العمولة 110%" (`PRCNT2`), year, period | .fmx texts | `add_columns` (PRCNT2 was not placed by the generator) | high |

## Tests (rolled back)

Serials 1/2 with FROM 0 / 81; TO <= FROM refused; update and delete of the middle range refused.

## Coverage

- Reproduced: numbering, continuity, last-record update / delete, both commission percentages.
- Not reproduced: year / quarter navigation buttons (grid filters), print button. `ALL_CTGRY` has no label in the form and stays hidden.
