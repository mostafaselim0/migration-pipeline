# TX_ITEMS - التطبيق على الاصناف / Item codes obligation

- Registry: system 88 (Taxes) serial 3, order 2011. APEX grid page 70050.
- Legacy module: `ASCON\TX\FMB\TX_Items.fmx` (no `.fmb`, no labels). Legacy layout: master "انواع الضرائب", detail "الاصناف المطبق
  عليها الضريبة" (`TX_TAXES_ITEMS`: المجموعة / رقم الصنف / إسم الصنف / النسبة / سعر البيع بعد النسبة), range panel (من مجموعة /
  إلى مجموعة / النسبة / تطبيق).
- **Deliverable: (a) generated grid kept (`"pattern": "AUTO"`) + row rule + range action**; `APP_RULES3_TX`, override `TX_ITEMS.json`.
- **Confidence: high** for the apply button and the item checks; **medium** for the row percentage check (see question).

## Rules and buttons

| # | Rule / button | Legacy evidence | APEX |
|---|---|---|---|
| 1 | Group from the active groups (`STOP_FLAG = 0`, `GROUP_STATUS = 1`) allowed for the user's group (`ST_GROUP_PASSWORD`, group 0 = all); item from the active items of that group | LOV queries of the form | row rule `items_row` (item must belong to the group, not stopped, group allowed) |
| 2 | The item's percentage is taken from `ST_ITEM.VAT_VALUE` when the item is chosen | `SELECT VAT_VALUE FROM ST_ITEM WHERE ITEM_GROUP_CODE = :b1 AND ITEM_CODE = :b2` | row rule: on insert, empty `TAX_PER` = `VAT_VALUE` |
| 3 | Percentage > 0 "النسبة يجب أن تكون أكبر من الصفر" (the message appears twice: range panel and detail block) | messages | row rule on insert and when the percentage changes (existing 0 % rows created by the apply button stay editable) |
| 4 | **تطبيق**: the items of the groups between the two groups are deleted for the tax and re-inserted from `ST_ITEM` with `NVL(VAT_VALUE, percentage)`; percentage > 0 | `DELETE FROM TX_TAXES_ITEMS WHERE GROUP_CODE BETWEEN ... AND TAX_CODE = ...` / `INSERT ... SELECT :b1, ITEM_GROUP_CODE, ITEM_CODE, NVL(VAT_VALUE, :b2) FROM ST_ITEM WHERE ITEM_GROUP_CODE BETWEEN ...` | grid action **APPLY** -> `app_rules3_tx.apply_items` (with a confirmation, since it replaces rows) |
| 5 | "سعر البيع بعد النسبة": retail price of the basic unit * (100 + percentage) / 100 (display) | `SELECT (RETAIL_SALE_PRICE * (100 + :b1)) / 100 FROM ST_ITEM_UNIT WHERE ... BASIC_UNIT = 1` | wave 3b: computed grid column PRICE_AFTER |

Rows written by other screens (e.g. the item master ST_ITEM, which also maintains `TX_TAXES_ITEMS`) are not checked by these rules
(the row rule only acts on this page).

## Tests

Percentage from `VAT_VALUE` (15); an item with `VAT_VALUE = 0` cannot be added manually; item of another group refused; changing a
percentage to 0 refused; an untouched 0 % row stays editable; apply with 0 % refused; apply groups 301010000000..301040000000 -> 97 items
with `NVL(VAT_VALUE, 15)`; rule inactive on other pages. `tmp\w3_gl\tx\t_tx.py`.

## Wave 3b

Rule 5 "سعر البيع بعد النسبة" is now a computed grid column: `(RETAIL_SALE_PRICE * (100 + TAX_PER)) / 100` of the item's basic unit
(`ST_ITEM_UNIT ... ITEM_CODE, GROUP_CODE, BASIC_UNIT = 1`, the legacy SQL). Checked on the build copy (e.g. 3,701.40).

## Coverage

Reproduced: 1-5 (5 as a computed column, wave 3b). Item / group names are shown by the lists of the code columns.

## Open question

1. The detail-block percentage check (rule 3) also refuses adding a zero-rated item by hand (its `VAT_VALUE` is 0), which the apply
   button can do. Is that the legacy behaviour the users know, or should 0 % be allowed on a row?
