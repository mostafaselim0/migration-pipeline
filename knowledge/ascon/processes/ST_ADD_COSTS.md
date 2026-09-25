# ST_ADD_COSTS - أرقام التكاليف الإضافية / Additional Cost Numbers

- Registry: system 3 serial 217, menu `CODES_MENU.ST_PLUS_COST`. Legacy `ASCON\ST\FMB\ST_ADD_COSTS.fmx` (no .fmb).
- APEX: page 20390, `GRID` on `ST_ADD_COSTS` (`COST_CODE`, `NAME_A`, `NAME_E`, `COST_VALUE`; `ACCOUNT_NO` has no legacy label).
  Override `overrides\ST_ADD_COSTS.json` (row rule), package `APP_RULES3_ST.add_cost_row`.
- Data: table empty; FK from `ITEMS_TRNSFORM_ADD_COSTS`.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| code = `NVL(MAX(COST_CODE),0)+1` | embedded SQL | generic max+1 of `APPX_ST_ADD_COSTS` | high |
| code greater than zero: "أدخل قيمة صحيحة لرقم التكلفة الإضافية - أكبر من الصفر" | message | row rule `add_cost_row` (-20173) | high |
| cost value greater than zero: "أدخل قيمة صحيحة للتكلفة الإضافية - أكبر من الصفر" | message | row rule `add_cost_row` | high |
| duplicates / FK | template ON-ERROR texts | primary key, FK | high |

## Tests (rolled back)

A5 code 0 refused, value 0 refused.

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| The wrong automatic list on `COST_CODE` (`AC_COST_CENTERS`, the cost centres) is removed | `columns.ST_ADD_COSTS.COST_CODE.lov = null` | the code is `NVL(MAX(COST_CODE),0)+1` of this table |

The names and the cost value are already required (NOT NULL columns).

## Coverage

- Reproduced: all checks above.
- Not reproduced: record counter; toolbar print (`ST_ADD_COSTS.rdf`, code list).
- Wave 3b: the wrong automatic list on `COST_CODE` is removed (`lov: null`). The row rule is active in `APPX_ST_ADD_COSTS` after the
  next build.
