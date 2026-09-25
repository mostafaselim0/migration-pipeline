# ST_COUNTRY - أرقام بلد المنشأ / Origin Country Codes

- Registry: system 3 serial 204, menu `CODES_MENU.ST_ORG_COUNTRY` (also system 30 serial 20, `CODES_MENU.CONTY`).
  Legacy `ASCON\ST\FMB\ST_COUNTRY.fmx` (no .fmb).
- APEX: page 20130, `GRID` on `ST_ORG_COUNTRY` (`COUNTRY_CODE`, `NAME_A`, `NAME_E`). Override `overrides\ST_COUNTRY.json` (wave 3b).
- Data: 15 countries; `ST_ITEM.COUNTRY_CODE` (VARCHAR2, no foreign key) is filled on 198 items.

## Rules

**No business rules beyond the table.** Evidence checked (.fmx embedded SQL and texts):

| Legacy element | Evidence | APEX | Confidence |
|---|---|---|---|
| code = `NVL(MAX(COUNTRY_CODE),0)+1` | the only embedded SQL | generic max+1 of `APPX_ST_ORG_COUNTRY` | high |
| "رقم مكرر تم إدخالة من قبل", "لا يجوز حذف السجل لإرتباطة بجداول اخري", "كود السجل المعدل مشترك فى جدول أخر" | generic ON-ERROR texts of the code-table template | primary key / database errors | high |
| "تم تخصيص هذه الوحدة مع صنف أو أكثر", "كود الوحدة مكرر" | texts copied from the ST_UNIT template; **no query** behind them | none (no delete check existed) | high |

## Wave 3b (new generator keys)

New override `overrides\ST_COUNTRY.json` (AUTO) with one key: `columns.ST_ORG_COUNTRY.COUNTRY_CODE.lov = null` removes the wrong
automatic list (`Z_COUNTRY`, own-key fallback); the code is numbered `NVL(MAX(COUNTRY_CODE),0)+1` as in the legacy. The countries
are now the list of `ST_ITEM.COUNTRY_CODE` (legacy COUNTRY_RG, see `ST_ITEM.md`).

## Coverage

- Reproduced: numbering and uniqueness (generated page).
- Not reproduced: toolbar print (`ST_ORG_COUNTRY.rdf`, code list; layout is the main session's job).
- Wave 3b: the wrong automatic list on `COUNTRY_CODE` is removed (`lov: null`).
