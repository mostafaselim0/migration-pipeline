# ST_COLOR - أرقام الألوان / Color Codes

- Registry: system 3 serial 202, menu `CODES_MENU.ST_COLOR`. Legacy `ASCON\ST\FMB\ST_Color.fmx` (no .fmb).
- APEX: page 20360, `GRID` on `ST_COLOR` (`COLOR_CODE`, `NAME_A`, `NAME_E`). Override `overrides\ST_COLOR.json` (wave 3b).
- Data: table empty; `ST_ITEM.COLOR_CODE` is empty on all items (colours are switched off: `ST_BASIC.COLOR_FLAG`).

## Rules

**No business rules beyond the table.** Evidence checked: the only embedded SQL is `SELECT NVL(MAX(COLOR_CODE),0)+1 FROM ST_COLOR`
(numbering -> generic max+1 of `APPX_ST_COLOR`); the texts are the template ON-ERROR messages ("رقم مكرر تم إدخالة من قبل",
"لا يجوز حذف السجل لإرتباطة بجداول اخري") -> primary key / database errors; "تم تخصيص هذه الوحدة مع صنف أو أكثر" is a leftover of the
ST_UNIT template with no query behind it. Confidence: high.

## Wave 3b (new generator keys)

New override `overrides\ST_COLOR.json` (AUTO): `columns.ST_COLOR.COLOR_CODE.lov = null` removes the wrong automatic list
(`MN_COLORS`, own-key fallback); the code stays numbered `NVL(MAX(COLOR_CODE),0)+1`.

## Coverage

- Reproduced: numbering, uniqueness.
- Not reproduced: toolbar print (`st_color.rdf`, code list).
- Wave 3b: the wrong automatic list on `COLOR_CODE` is removed (`lov: null`).
