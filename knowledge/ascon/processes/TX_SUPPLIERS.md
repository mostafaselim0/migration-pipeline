# TX_SUPPLIERS - التطبيق على الموردين / Suppliers obligation

- Registry: system 88 (Taxes) serial 5, order 2013. APEX grid page 70070.
- Legacy module: `ASCON\TX\FMB\TX_Suppliers.fmx` (no `.fmb`, no labels). Master "انواع الضرائب", detail "الموردين المطبق عليهم الضريبة"
  (`TX_TAXES_SUPPLIERS`: رقم المورد / إسم المورد / النسبة / الرقم الضريبي / مورد خارجي), range panel (من مورد / إلى مورد / النسبة / تطبيق).
- **Deliverable: (a) generated grid kept (`"pattern": "AUTO"`) + row rule + key fix + range action**; `APP_RULES3_TX`,
  override `TX_SUPPLIERS.json`. **Confidence: high.**

## Rules and buttons

| # | Rule / button | Legacy evidence | APEX |
|---|---|---|---|
| 1 | Supplier from the supplier list | LOV `SELECT CODE, NAME_A ... FROM SUPPLIER` | generated list of values |
| 2 | No automatic supplier number | generated max+1 trap on the last key column | `key_expr` `null` |
| 3 | Percentage > 0 (range panel and detail block) | "النسبة يجب أن تكون أكبر من الصفر" (twice) | row rule `oblig_row('SUPP')` on insert and when the percentage changes (the 485 existing 0 % rows, loaded from elsewhere, stay editable) |
| 4 | **تطبيق**: every supplier of the range gets the percentage (update or insert) | `SELECT * FROM SUPPLIER WHERE CODE BETWEEN`, `INSERT INTO TX_TAXES_SUPPLIERS (TAX_CODE, SUPPLIER_CODE, TAX_PER)` / `UPDATE` | grid action **APPLY** -> `app_rules3_tx.apply_suppliers` |
| 5 | Duplicate supplier for the tax updated the existing row | `SELECT COUNT(1) ... UPDATE` | primary key refuses; edit the existing row |
| 6 | "مورد خارجي" (`EXT_SUPP_FLAG`, checkbox) - used by the tax statement: purchases of an external supplier go to box 7 (imports paid at customs) | TX_STAT build SQL `DECODE(NVL(EXT_SUPP_FLAG,0),0,6,7)` | column shown (1 = yes) |

Only suppliers registered here for the tax enter the supplier (VN) part of the tax statement (TX_STAT).

## Tests

No automatic supplier code, an existing 0 % row stays editable, changing a percentage to 0 refused, apply to all suppliers at 15 %.
`tmp\w3_gl\tx\t_tx.py`.

## Wave 3b

`EXT_SUPP_FLAG` "مورد خارجي" is the legacy check box again (`widget: CHECK`, 1 / 0; TX_STAT reads `DECODE(NVL(EXT_SUPP_FLAG,0),0,6,7)`).
The supplier names are shown by the supplier list of the code column.

## Coverage

Reproduced: 1-4, 6 (with the check box, wave 3b); 5 as described. Not reproduced: the master tax-type block (tax types have their own
screen).
