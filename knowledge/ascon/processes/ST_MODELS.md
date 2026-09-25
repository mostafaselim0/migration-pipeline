# ST_MODELS - أرقام الموديلات / Items Model Codes

- Registry: system 3 serial 290, **menu None** (not reachable from the legacy menu).
- Legacy module: **none on disk** (no `ST_MODELS.fmx` / `.fmb` under `ASCON`); only GN_FORM_ITEM labels exist (block `ITEM_MODEL`:
  `MODEL_ID` رقم الموديل, `MODEL_NAME` الأسم عربى, `MODEL_NAME_E` الأسم لاتينى).
- APEX: page 20400, `GRID` on `ITEM_MODEL` (`MODEL_ID`, `MODEL_NAME`, `MODEL_NAME_E`). No override.
- Data: `ITEM_MODEL` empty; `ST_ITEM.MODEL_ID` empty on all items.

## Rules

**No business rules beyond the table** - there is no compiled module to take rules from, and the feature is unused (no menu entry,
empty table). The generated grid keeps the primary key; an empty `MODEL_ID` is filled with max+1 by `APPX_ITEM_MODEL`. Confidence: high
that nothing more can be reconstructed.

## Coverage

- Reproduced: the table maintenance with the legacy labels.
- Not reproduced: nothing identifiable (no module).
