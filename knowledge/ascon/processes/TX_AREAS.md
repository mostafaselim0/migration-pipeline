# TX_AREAS - التطبيق على مناطق التوريد / Areas obligation

- Registry: system 88 (Taxes) serial 6, order 2014. APEX grid page 70080.
- Legacy module: `ASCON\TX\FMB\TX_Areas.fmx` (no `.fmb`, no labels). Master "انواع الضرائب", detail "التطيبق على المناطق"
  (`TX_TAXES_AREAS`: رقم المنطقة / إسم المنطقة / النسبة), range panel (من منطقة / إلى منطقة / النسبة / تطبيق).
- **Deliverable: (a) generated grid kept (`"pattern": "AUTO"`) + row rule + key fix + range action**; `APP_RULES3_TX`,
  override `TX_AREAS.json`. **Confidence: high** (table empty in the build copy).

## Rules and buttons

| # | Rule / button | Legacy evidence | APEX |
|---|---|---|---|
| 1 | Area from `AR_MAINAREA` (no foreign key, no generated list) | LOV `SELECT ID, NAME_A ... FROM AR_MAINAREA`, name lookup | row rule `oblig_row('AREA')`: area must exist ("رقم المنطقة غير موجود") |
| 2 | No automatic area number | generated max+1 trap on `MAINAREA_ID` | `key_expr` `null` |
| 3 | Percentage > 0 (range panel and detail block) | "النسبة يجب أن تكون أكبر من الصفر" (twice) | row rule on insert / percentage change |
| 4 | **تطبيق**: every area between the two ids gets the percentage (update or insert) | `SELECT * FROM AR_MAINAREA WHERE ID BETWEEN`, `SELECT COUNT(1) ... UPDATE TX_TAXES_AREAS SET TAX_PER` | grid action **APPLY** -> `app_rules3_tx.apply_areas` |

The area percentage is the first thing `GET_TAX_VALUE_DB` looks at (before customer and item percentages).

## Tests

Unknown area refused, empty area refused, area 11 accepted, apply areas 11..12 at 5 % (one update, one insert). `tmp\w3_gl\tx\t_tx.py`.

## Wave 3b

`MAINAREA_ID` gets the legacy area list (`SELECT ID, NAME_A MAINAREA_NAME ... FROM AR_MAINAREA ORDER BY 1`): select list "id - name",
which shows the area name the legacy displayed. SQL run on the build copy.

## Coverage

Reproduced: 1-4 and the area name (wave 3b). Not reproduced: master tax-type block (own screen).
