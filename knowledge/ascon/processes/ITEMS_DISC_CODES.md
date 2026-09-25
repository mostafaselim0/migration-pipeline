# ITEMS_DISC_CODES - أرقام خصومات الأصناف / Items Discounts Code

- Registry: system 3 serial 391, **menu None**.
- Legacy module: **none on disk** (no `ITEMS_DISC_CODES.fmx` / `.fmb` under `ASCON`); only GN_FORM_ITEM labels (block `ITEM_DISC_TYPE`:
  `DISC_TYPE_ID` رقم الخصم, `DISC_TYPE_NAME` الأسم عربى, `DISC_TYPE_NAME_E` الأسم لاتينى).
- APEX: page 20410, `GRID` on `ITEM_DISC_TYPE`. No override.
- Data: `ITEM_DISC_TYPE` empty; `ST_ITEM.DISC_TYPE_ID` empty on all items.

## Rules

**No business rules beyond the table** (no module, no menu entry, empty table). Confidence: high that nothing more can be reconstructed.

## Coverage

- Reproduced: the table maintenance with the legacy labels.
- Note: the `APPX_ITEM_DISC_TYPE` trigger of the last build fills an empty `DISC_TYPE_ID` with max+1; the current generator skips
  `*TYPE*` columns, so after the next build the number must be typed. No legacy evidence either way.
