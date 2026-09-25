# ST_SIZE - أرقام المقاسات / Size Codes

- Registry: system 3 serial 203, menu `CODES_MENU.ST_SIZE`. Legacy `ASCON\ST\FMB\ST_Size.fmx` (no .fmb).
- APEX: page 20370, `GRID` on `ST_SIZE` (`SIZE_CODE`, `NAME_A`, `NAME_E`). No override.
- Data: table empty; `ST_ITEM.SIZE_CODE` empty on all items (sizes switched off: `ST_BASIC.SIZE_FLAG`).

## Rules

**No business rules beyond the table.** Evidence checked: the only embedded SQL is the duplicate check
`SELECT COUNT(1) FROM ST_SIZE WHERE SIZE_CODE = :b1` ("رقم مكرر تم إدخالة من قبل") -> primary key; the other texts are the template
ON-ERROR messages and ST_UNIT leftovers without a query. The legacy had no numbering (the user typed the code); the generated
`APPX_ST_SIZE` fills an empty code with max+1 (harmless addition). Confidence: high.

## Coverage

- Reproduced: uniqueness. Not reproduced: toolbar print (`st_SIZE.rdf`, code list).
