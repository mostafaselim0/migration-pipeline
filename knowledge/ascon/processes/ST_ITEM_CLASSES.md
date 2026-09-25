# ST_ITEM_CLASSES - أرقام فئــات الأصنـاف / Items Category Numbers

- Registry: system 3 serial 28, menu `CODES_MENU.ST_ITEM_CTGRY`. Legacy `ASCON\ST\FMB\ST_ITEM_CLASSES.fmx` (no .fmb).
- APEX: page 20200, `GRID` on `ST_ITEM_CLASSES` (`CLASS_CODE`, `DESC_A`, `DESC_E`). Override `overrides\ST_ITEM_CLASSES.json` (row rule),
  package `APP_RULES3_ST.class_row`.
- Data: 2 classes; `ST_ITEM.CLASS_CODE` is filled on all 4035 items (no FK).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| code greater than zero: "قم بادخال رقم اكبر من الصفر" | message | row rule `class_row('ST_ITEM_CLASSES', ...)` (-20173) | high |
| Arabic or English name: "يجب ادخال الأسم عربى أو لاتينى" | message | same row rule | high |
| duplicate code: "هذا السجل تم ادخاله من قبل ... رقم مكرر" | `SELECT COUNT(1) FROM ST_ITEM_CLASSES WHERE CLASS_CODE = :b1`, message | same row rule (on insert; primary key as backstop) | high |
| empty code filled with max+1 | none in the legacy (the user typed it) | generic max+1 of `APPX_ST_ITEM_CLASSES` (harmless addition) | - |

## Tests (rolled back)

A3 code 0 refused, class without names refused, duplicate code 1 refused.

## Open questions

- Delete protection: the .fmx contains the text "تم استخدام هذه النوع مع مخزن أو أكثر - لا يمكن حذفه حالياً." but its only other query is
  `SELECT COUNT(1) FROM ST_STORE_TYPE` (no WHERE - apparently the record counter copied from ST_STORE_TYPE), and nothing reads
  `ST_ITEM.CLASS_CODE`. Not reproduced. Should a class used by items be protected against deletion?

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| The wrong automatic list on `CLASS_CODE` (`AS_CLASS`, fixed-asset classes) is removed | `columns.ST_ITEM_CLASSES.CLASS_CODE.lov = null` | the user types the class code ("قم بادخال رقم اكبر من الصفر") |

The classes are now the list of `ST_ITEM.CLASS_CODE` on the item screen (see `ST_ITEM.md`).

## Coverage

- Reproduced: all checks above.
- Not reproduced: the delete message (see question); toolbar print (no class RDF on disk).
- Wave 3b: the wrong automatic list on `CLASS_CODE` is removed (`lov: null`). The row rule is active in `APPX_ST_ITEM_CLASSES` after
  the next build.
