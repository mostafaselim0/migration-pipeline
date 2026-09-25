# ST_ITEM_TYPES - أرقام أنواع الأصناف / Items Types Code

- Registry: system 3 serial 393, **menu None**.
- Legacy module: **none on disk** (no `ST_ITEM_TYPES.fmx` / `.fmb` under `ASCON`); only GN_FORM_ITEM labels (block `ITEM_TYPE`:
  `TYPE_ID` رقم النوع, `TYPE_NAME` الأسم عربى, `TYPE_NAME_E` الأسم لاتينى).
- APEX: page 20430, `GRID` on `ITEM_TYPE`. No override.
- Data: `ITEM_TYPE` empty; `ST_ITEM.TYPE_ID` empty on all items.

## Rules

**No business rules beyond the table** (no module, no menu entry, empty table). Confidence: high that nothing more can be reconstructed.

## Coverage

- Reproduced: the table maintenance with the legacy labels.
- Note: `APPX_ITEM_TYPE` (last build) fills an empty `TYPE_ID` with max+1; the current generator skips `*TYPE*` columns, so after the
  next build the number must be typed. No legacy evidence either way.
