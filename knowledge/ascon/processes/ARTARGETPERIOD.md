# ARTARGETPERIOD - تقسيم فترات السنه / Year Division File

- Registry: system 4 serial 26 (`CODES_MENU.AR_TARGET_PERIODS`). Legacy `ASCON\AR\FMB\ArTargetPeriod.fmx` (no .fmb).
- APEX: generated grid on `AR_TARGET_PERIODS` (page 30250) kept; rules and the button in `APP_RULES3_AR`. Table empty in the build copy.

## Rules and buttons

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| `SERIAL = NVL(MAX(SERIAL),0)+1 WHERE T_YEAR = :year` | embedded SQL | generated max+1 key per year | high |
| `FROM_P = MAX(TO_P)+1` of the year, 1 January for the first period (`COUNT ... TO_P = 01/01/year`) | embedded SQL | row rule `tperiod_row`; FROM read-only | medium (first-period default inferred) |
| "الفترة الى يجب أن يكون أكبر من الفترة من" | .fmx message | row rule | high |
| "يجب التعديل فى أخر سجل فقط" (only the last period may be changed) | .fmx message | compound trigger `APP_RULES3_AR_TPERIOD_BUD` (after the UPDATE statement) | high |
| "يجب حذف أخر سجل أولا" | .fmx message | same compound trigger (DELETE) | high |
| button "انزال شهور السنه" (`INSERT_MONTHS`) | button label / item name | grid action `INSERT_MONTHS` -> `app_rules3_ar.insert_months(year)`: the 12 months (1st .. last day), refused when the year already has periods | medium |

The month names written by the button (`DESC_A` / `DESC_E`, Oracle month names in Arabic / English) are our choice: the compiled
button code is not readable. Question for the key user: which descriptions did "انزال شهور السنه" write?

## Tests (rolled back)

Serial 1/2, FROM 01/01 then 01/02; TO <= FROM refused; update of a middle period refused, of the last accepted; delete middle refused,
last deleted; button creates 12 months 01/01 .. 31/12 (February 28/02) and is refused for a year with periods.

## Coverage

- Reproduced: numbering, derived FROM, TO > FROM, last-record update / delete, the months button.
- Not reproduced: year navigation (`S_YEAR` item: the grid filters by year instead), print button.
