# AR_SALESMAN_MSG - ملف الرسائل / Message File (messages to salesmen)

- Registry: system 4 serial 43 (no menu). Legacy `ASCON\AR\FMB\AR_SALESMAN_MSG.fmx` (no .fmb, no labels). Tables empty.
- APEX: corrected from a form on `SALESMAN` to `MASTER_DETAIL` on the tables the legacy form writes: `MOB_MSG_MAST` (مسلسل، تاريخ الرسالة،
  عنوان، الرسالة، sender = user) and `MOB_MSG_DET` (المندوب، تم الاطلاع، اخفاء). Rules and button in `APP_RULES3_AR`.

## Rules and buttons

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| `MAST_SER = NVL(MAX(MAST_SER),0)+1` | SQL | generated key | high |
| sender = the user (`USERS` LOV), date today | USERS LOV, texts | defaults | medium |
| recipients are salesmen; "تم الاطلاع" / read date come from the mobile application | texts, `SALESMAN` lookup | row rule `msg_det_row`, recipient mandatory (`key_expr`), read columns read-only | high |
| deleting a message deletes its recipients (`DELETE FROM MOB_MSG_DET WHERE MAST_SER`) | SQL | document delete cascade | high |
| "اختيار" (choose salesmen from a check list) | texts اختيار / الاختيار / إلغاء | document action `ADD_SALESMEN` adds every active salesman (optionally of one department) not yet a recipient; single recipients are added in the grid | medium |

## Tests (rolled back)

Serial; recipient required; unknown salesman refused; button adds every active salesman once and again without duplicates (batch 5).

## Coverage

- Reproduced: the message, its recipients and the selection.
- Adapted: the check-list selection became "all (of a department)" + the grid.
