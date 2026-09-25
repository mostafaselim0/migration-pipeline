# TX_AS_CTGRY - التطبيق على الاصول / Fixed assets obligation

- Registry: system 88 (Taxes) serial 12, order 2004. APEX grid page 70040.
- Legacy module: `ASCON\TX\FMB\TX_As_Ctgry.fmx` (no `.fmb`, no labels). Master "انواع الضرائب", detail "انواع الاصول المطبق عليهم
  الضريبة" (`TX_TAXES_AS_CTGRY`), range panel (من نوع اصل / إلى نوع اصل / النسبة / تطبيق).
- **Deliverable: (a) generated grid kept (`"pattern": "AUTO"`) + row rule + key fix + range action**; `APP_RULES3_TX`,
  override `TX_AS_CTGRY.json`. **Confidence: high** for the rules; the fixed-assets tables (`AS_CTGRY`, `TX_TAXES_AS_CTGRY`) are empty
  in this database.

## Rules and buttons

| # | Rule / button | Legacy evidence | APEX |
|---|---|---|---|
| 1 | Asset category from the leaf categories of `AS_CTGRY` (`LEAF = 1`) | LOV `select ctgry_cd_asct, desc_a_asct ... from as_ctgry where nvl(leaf,0) = 1` | row rule `oblig_row('ASCT')`: type + code must be a leaf category ("نوع الأصل غير موجود") |
| 2 | No automatic category code | generated max+1 trap on `CTGRY_CD_ASCT` | `key_expr` `null` |
| 3 | Percentage > 0 (range panel and detail block) | "النسبة يجب أن تكون أكبر من الصفر" (twice) | row rule on insert / percentage change |
| 4 | **تطبيق**: the categories of the code range are deleted for the tax and re-inserted from `AS_CTGRY` (all categories of the range, as in the legacy statement) | `DELETE FROM TX_TAXES_AS_CTGRY WHERE CTGRY_CD_ASCT BETWEEN ... AND TAX_CODE = ...` / `INSERT ... SELECT :b1, CTGRY_CD_ASCT, CTGRY_TYPE_ASCT, :b2 FROM AS_CTGRY WHERE CTGRY_CD_ASCT BETWEEN ...` | grid action **APPLY** -> `app_rules3_tx.apply_as_ctgry` (with a confirmation) |

## Tests

Unknown category refused; apply runs (nothing to insert: `AS_CTGRY` is empty). `tmp\w3_gl\tx\t_tx.py`.

## Wave 3b

`CTGRY_CD_ASCT` gets the legacy category list (`select ctgry_cd_asct, desc_a_asct ... from as_ctgry where NVL(LEAF,0) = 1`), limited to
the row's category type (`:PAGE_CTGRY_TYPE_ASCT`, `cascade: CTGRY_TYPE_ASCT`; the legacy list returned the type with the code). It shows
the category name. AS_CTGRY is empty on the build copy; the SQL was run.

## Coverage

Reproduced: 1-4 and the category list / name (wave 3b). Not reproduced: master tax-type block.
