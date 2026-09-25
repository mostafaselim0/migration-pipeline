# ST_BRAND - أرقام مـاركات الأصناف / Item Brand Numbers

- Registry: system 3 serial 24, menu `CODES_MENU.ST_BRAND`. Legacy `ASCON\ST\FMB\ST_BRAND.fmx` (no .fmb).
- APEX: page 20220, `GRID` on `ST_BRAND` (`BRAND_CODE`, `BRAND_NAME_A`, `BRAND_NAME_E`; `GROUP_CODE` has no legacy label and is not shown).
  Override `overrides\ST_BRAND.json`: `key_expr` + `optional` for `BRAND_CODE`, row rule; delete trigger `APP_RULES3_ST_BRAND_BD`.
- Data: 1 brand; `ST_ITEM.BRAND_CODE` (NUMBER, while `ST_BRAND.BRAND_CODE` is VARCHAR2) filled on 2 items; FK from `ST_ITEM_OPEN_REQ`.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| code = `NVL(MAX(BRAND_CODE),0)+1` | embedded SQL | `key_expr` `app_rules3_st.next_brand_code` (numeric max of the VARCHAR2 codes; the generic max+1 does not apply to a VARCHAR2 key) | high |
| duplicate code: "كود مكرر من قبل" | `SELECT COUNT(1) FROM ST_BRAND WHERE BRAND_CODE = :b1` (twice) | row rule `brand_row` (insert) + primary key | high |
| Arabic or English name: "يجب ادخال الأسم عربى أو لاتينى" | message | row rule `brand_row` | high |
| used brand cannot be deleted: "تم استخدام هذه الماركة فى النظام - لا يمكن حذفه حالياً." | `SELECT COUNT(BRAND_CODE) FROM ST_ITEM WHERE BRAND_CODE = :b1` | delete trigger `APP_RULES3_ST_BRAND_BD` (-20174) | high |

## Tests (rolled back)

A4 next code = max + 1 (2); duplicate code '1' refused; brand without names refused; A6 deleting brand '1' (used by 2 items) refused.

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| The wrong automatic list on `BRAND_CODE` (`ST_ITEM_BRAND`, own-key fallback) is removed | `columns.ST_BRAND.BRAND_CODE.lov = null` | the code is numbered `NVL(MAX(BRAND_CODE),0)+1` or typed |

Not changed: the names stay optional one by one (legacy rule "Arabic **or** English name", row rule `brand_row`).

## Coverage

- Reproduced: all rules above.
- Not reproduced: record counter "أخر سجل"; toolbar print (`ST_BRAND.RDF`, code list).
- Wave 3b: the wrong automatic list on `BRAND_CODE` is removed (`lov: null`). Row rule and key expression become active in the
  generated trigger at the next build.
