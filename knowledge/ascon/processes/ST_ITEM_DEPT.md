# ST_ITEM_DEPT - أرقام أقسام الأصناف / Items Department

- Registry: system 3 serial 394, **menu None**.
- Legacy module: **none on disk** (no `ST_ITEM_DEPT.fmx` / `.fmb` under `ASCON`); only GN_FORM_ITEM labels (block `ITEM_DEPT`:
  `DEPT_ID` رقم القسم, `DEPT_NAME` الأسم عربى, `DEPT_NAME_E` الأسم لاتينى).
- APEX: page 20440, `GRID` on `ITEM_DEPT`. No override.
- Data: `ITEM_DEPT` empty; `ST_ITEM.DEPT_ID` empty on all items.

## Rules

**No business rules beyond the table** (no module, no menu entry, empty table). An empty `DEPT_ID` is filled with max+1 by
`APPX_ITEM_DEPT`. Confidence: high that nothing more can be reconstructed.

## Coverage

- Reproduced: the table maintenance with the legacy labels.
- Not reproduced: nothing identifiable (no module).
