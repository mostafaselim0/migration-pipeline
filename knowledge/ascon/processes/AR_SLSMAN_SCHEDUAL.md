# AR_SLSMAN_SCHEDUAL - خطة زيارات المناديب / Salesman Visit Plan

- Registry: system 4 serial 38 (no menu). Legacy `ASCON\AR\FMB\Ar_Slsman_Schedual.fmx` (no .fmb). Tables empty (mobile flow unused).
- APEX: corrected from a grid on `AR_SALESMAN_SCHEDUAL` to `MASTER_DETAIL` as in the form (relations `SALESMAN_AR_SALESMAN_SCHEDUAL`,
  `SALESMAN_AR_SALESMAN_VISITS`): `SALESMAN` (navigation only, read-only), `AR_SALESMAN_SCHEDUAL` (المخطط) and `AR_SALESMAN_VISITS`
  (الفعلي). Rules and the button in `APP_RULES3_AR`.

## Rules and buttons

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| active salesmen of the user's group | LOV / block WHERE | `where` | high |
| salesman block is navigation only | form layout | row rule and delete trigger refuse changes from this page (the generator applies one insert/update/delete flag to all blocks) | high |
| planned customer: active leaf customer of the salesman | customer LOV | row rule `schedule_row` | high |
| "تم تعدي عدد 25 زيارة" (`COUNT(1) ... WHERE SALESMAN_ID AND SCHEDUAL_DATE`) | SQL, message | row rule (insert) | high |
| visit order default max+1 per salesman and day | ترتيب الزيارة | row rule | medium |
| "يجب ان يكون وقت الرجوع اكبر من وقت الخروخ" | message | row rule `visit_row` | high |
| button "خط السير": customers of a route of the salesman whose visit day is the day (`VISIT_DAY = TO_CHAR(SYSDATE + 1, 'Dy', english)`), in route order | SQL | document action `LOAD_ROUTE` (date parameter, default tomorrow as in the legacy) | high |

## Tests (rolled back)

Salesman read-only (update / delete); customer of another salesman refused; order 1, 2; 26th visit refused (when the salesman has > 25
customers); end before start refused; button schedules tomorrow's route customers in order; route of another salesman refused.

## Coverage

- Reproduced: the plan, the actual visits, their checks and the route button. The salesman block has no insert / delete
  (wave-3b `rules.blocks`); its fields are read-only and the row rule refuses changes.
- Not reproduced: the month calendar navigation (`FILL_DATES`, day buttons) - the grids filter by date; "اعادة جدولة" is the editable
  `R_SCHEDUAL_DATE` column (no further logic visible).
