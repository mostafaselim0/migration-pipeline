# ST_RECEIVE_CODES - أرقام دفعات الأصناف / Items Recieve Numbers

- Registry: system 3 serial 392 (no menu entry, no tree order). APEX page 20420, `PROCESS` placeholder generated from the registry
  (source "none").
- Evidence checked (wave 3b sweep): no `ST_RECEIVE_CODES.fmx` / `.fmb` under `ASCON` or `ST`, no GN_FORM_ITEM labels, no tables in
  the evidence pack (`evidence\ST_RECEIVE_CODES.md`).

## Rules

**None identifiable**: there is no compiled module, no labels and no menu entry, so there is nothing to reproduce. No override.

## Coverage

- Reproduced: nothing (no evidence of the screen's content).
- Not reproduced: the screen itself - question for the business: is "أرقام دفعات الأصناف" (item receipt batch numbers) still needed?
  Lots are maintained through the documents (`ST_ITEM_CONFG`) and the lot price screen ST_CHANG_CONFG_SALES_PRICE.
