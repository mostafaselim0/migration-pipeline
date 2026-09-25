# ST_UNIT - أرقام وحدات القياس / Measuring Units Numbers

- Registry: system 3 serial 201 (also system 30 serial 10), menu `CODES_MENU.ST_UNIT`. Legacy `ASCON\ST\FMB\st_unit.fmx` (no .fmb).
- APEX: page 20120, `GRID` on `ST_UNIT` (`UNIT_CODE`, `NAME_A`, `NAME_E`, `UNIT_FACTOR`, `BASIC_UNIT_CODE`). Override `overrides\ST_UNIT.json`
  adds one row rule; package `APP_RULES3_ST` (`app\db\25_rules3_st.sql`), delete trigger `APP_RULES3_ST_UNIT_BD`.
- Data: 1 unit; `ST_ITEM_UNIT` (4035 rows) references it (FK `ITM_UNT_UNT_FK`, also stock-taking and request tables).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| unit code = `NVL(MAX(UNIT_CODE),0)+1` when not typed | `SELECT NVL(MAX(UNIT_CODE),0)+1 FROM ST_UNIT` | generic max+1 of the generated `APPX_ST_UNIT` trigger | high |
| Arabic name required: "يجب إدخال الإسم" | message | row rule `unit_row` (-20173) | high |
| duplicate code: "رقم مكرر تم إدخالة من قبل" / "كود الوحدة مكرر" | messages (template ON-ERROR) | primary key | high |
| a unit used by items cannot be deleted: "تم تخصيص هذه الوحدة مع صنف أو أكثر - لا يمكن حذفها حالياً." | `SELECT COUNT(UNIT_CODE) FROM ST_ITEM_UNIT WHERE UNIT_CODE = :b1`, message | delete trigger `APP_RULES3_ST_UNIT_BD` -> `code_delete('ST_UNIT')` (-20174) | high |
| "لا يجوز حذف السجل لإرتباطة بجداول اخري" / "كود السجل المعدل مشترك فى جدول أخر توقف التعديل" | generic ON-ERROR texts of the code-table template | database foreign keys (error shown by APEX) | high |

## Tests (rolled back, `tmp\w3_st\t_rules3_st.py`, 188/188 passed in the final run)

A1 name required (Arabic, and English text with `G_LANG = en`), name given accepted; A6 deleting unit 1 (used by items) refused;
A7 an unused unit is deleted.

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| The wrong automatic list on `UNIT_CODE` (`LC_UNIT`, own-key fallback) is removed: the code is a plain number field | `columns.ST_UNIT.UNIT_CODE.lov = null` | the legacy code item is a text item filled by `NVL(MAX(UNIT_CODE),0)+1` |
| Arabic name required on the page (the row rule `unit_row` stays as the backstop) | `columns.ST_UNIT.NAME_A.required` | message "يجب إدخال الإسم" |

Checked, nothing else to change: `BASIC_UNIT_CODE` is already a check box (GN_FORM_ITEM type C, data value 1 = checked, 1 / 0).
Checks: `specs.py` + in-memory generation (0 failures); no new SQL.

## Coverage

- Reproduced: numbering, name required, delete protection, duplicates.
- Not reproduced: the record counter "أخر سجل" (`SELECT COUNT(1) FROM ST_UNIT`, display only; the grid shows its own count); the toolbar
  print (`ST_UNIT.rdf`, a code list; printing layout is the main session's job).
- Wave 3b: the wrong automatic list on `UNIT_CODE` is removed (`lov: null`); the Arabic name is a required field on the page.
- The row rule becomes active in `APPX_ST_UNIT` at the next build (build.py not run in this wave).
