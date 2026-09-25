# ST_STORE_TYPE - أنواع المخازن / Store Types

- Registry: system 3 serial 206 (also system 30 serial 11), menu `CODES_MENU.ST_STORE_TYPE`. Legacy `ASCON\ST\FMB\ST_STORE_TYPE.fmx` (no .fmb).
- APEX: page 20150, `GRID` on `ST_STORE_TYPE` (`STORE_TYPE`, `DESC_A`, `DESC_E`). Override `overrides\ST_STORE_TYPE.json` (key_expr,
  optional key, row rule); package `APP_RULES3_ST`, delete trigger `APP_RULES3_ST_STORE_TYPE_BD`.
- Data: 4 types; `ST_STORE.STORE_TYPE` is NOT NULL with FK `STORE_STORE_TYPE_FK`.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| type number between 1 and 999999: "رقم نوع المخزن يجب ان يكون فى المدي من 1 و 999999" | message, `FM999999` format | row rule `store_type_row` (-20173) | high |
| type number = `NVL(MAX(STORE_TYPE),0)+1` when not typed | `SELECT NVL(MAX(STORE_TYPE),0)+1 FROM ST_STORE_TYPE` | `key_expr` `app_rules3_st.next_code('ST_STORE_TYPE')`, column optional (the generator no longer numbers keys named `*TYPE*`) | high |
| a type used by stores cannot be deleted: "تم تخصيص هذا النوع مع مخزن أو أكثر - لا يمكن حذفه حالياً." | `SELECT COUNT(STORE_TYPE) FROM ST_STORE WHERE STORE_TYPE = :b1`, message | delete trigger `APP_RULES3_ST_STORE_TYPE_BD` (-20174) | high |
| duplicate number | "رقم مكرر تم إدخالة من قبل" | primary key | high |

## Tests (rolled back)

A2 type 0 and 1000000 refused, 5 accepted, next number = max + 1; A6 deleting type 1 (used by stores) refused.

## Coverage

- Reproduced: numbering, range check, delete protection, uniqueness.
- Not reproduced: record counter "أخر سجل" (`SELECT COUNT(1) FROM ST_STORE_TYPE`, display); toolbar print (`ST_STORE_TYPE.rdf`, code list,
  layout is the main session's).
- The key_expr and the row rule become active in `APPX_ST_STORE_TYPE` at the next build.
