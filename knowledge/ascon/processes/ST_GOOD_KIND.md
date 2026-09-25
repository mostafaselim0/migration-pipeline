# ST_GOOD_KIND - أرقام الشركات المصنعة / Production Company Codes

- Registry: system 3 serial 205, menu `CODES_MENU.ST_GOOD_KIND`. Legacy `ASCON\ST\FMB\ST_GOOD_KIND.fmx` (no .fmb; the compiled texts still say
  "رقم مادة الصنع / مادة الصنع" - the module was reused, the labels in GN_FORM_ITEM say manufacturer).
- APEX: page 20140, `GRID` on `ST_GOOD_KIND` (`KIND_CODE`, `NAME_A`, `NAME_E`). Override `overrides\ST_GOOD_KIND.json` (numbering only).
- Data: 561 manufacturers; `ST_ITEM.KIND_CODE` filled on 3366 items (no FK); FK `VN_SUPP_KIND_FK2` from `VN_SUPP_KIND`.

## Rules

No business rules beyond the table and its numbering. Evidence checked:

| Legacy element | Evidence | APEX | Confidence |
|---|---|---|---|
| code = `NVL(MAX(KIND_CODE),0)+1` when not typed | the only embedded SQL | `key_expr` `app_rules3_st.next_code('ST_GOOD_KIND')`, column optional (the generator no longer numbers keys named `*KIND*`) | high |
| duplicate / FK messages ("رقم مكرر تم إدخالة من قبل", "لا يجوز حذف السجل لإرتباطة بجداول اخري") | template ON-ERROR texts | primary key / FK errors | high |
| "تم تخصيص هذه الوحدة مع صنف أو أكثر" | text copied from the ST_UNIT template, **no query** | none | high |

## Tests (rolled back)

A2: next code = max + 1.

## Coverage

- Reproduced: numbering, uniqueness.
- Not reproduced: toolbar print (`ST_GOOD_KIND.rdf`, code list; layout is the main session's).
- Open question: deleting a manufacturer used by items is not blocked (no FK from `ST_ITEM.KIND_CODE`, no query in the .fmx) - as the legacy.
- The key_expr becomes active in `APPX_ST_GOOD_KIND` at the next build.
