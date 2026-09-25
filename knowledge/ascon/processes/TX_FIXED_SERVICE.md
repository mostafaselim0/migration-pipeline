# TX_FIXED_SERVICE - التطبيق على المصاريف الثابتة / Fixed service obligation

- Registry: system 88 (Taxes) serial 7, order 2015. APEX grid page 70090.
- Legacy module: `ASCON\TX\FMB\TX_Fixed_Service.fmx` (no `.fmb`, no labels). Master "انواع الضرائب" (رقم الضريبة / الأسم عربى /
  الأسم لاتينى) with one detail item "نسبة النقل" (`TX_TAXES_FIXED_SRV.TRANSPORT_TAX_PER`, one row per tax type).
- **Deliverable: plain code table, no business rules** - generated grid kept (`"pattern": "AUTO"`) with one key fix and labels
  (override `TX_FIXED_SERVICE.json`). **Confidence: high.**

## Evidence checked

- Embedded SQL: only `SELECT 1 FROM TX_TAXES_FIXED_SRV T WHERE T.TAX_CODE = :b1` (the Forms master-detail delete check of the tax-type
  master block, which is not on this page).
- Arabic texts: template messages only (no percentage check in this module, unlike the other obligation screens); "يجب إدخال الإسم" is
  the tax-type master block's name check (tax types are maintained in TX_TAXES_TYPES).
- Table `TX_TAXES_FIXED_SRV (TAX_CODE PK, TRANSPORT_TAX_PER)`, empty; copied by the TX_TAXES_TYPES copy button.

## APEX

- `key_expr` `TX_TAXES_FIXED_SRV.TAX_CODE = null`: the generated trigger would otherwise give an empty tax number max + 1 (the key is the
  table's only column); the tax type must be chosen from the list.
- Labels: رقم الضريبة / نسبة النقل.

## Tests

Empty tax number refused (ORA-01400), a transport percentage for tax 2 accepted. `tmp\w3_gl\tx\t_tx.py`.


## Wave 3b

Checked, nothing to change: two columns (tax type with its list, transport percentage); no legacy check box / list item / display item.

## Coverage

Everything of the legacy screen except the master tax-type block (own screen).
