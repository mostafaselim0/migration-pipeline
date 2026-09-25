# ST_ITEM_CLASS — تعديل خصومات الأصناف / Update Item Discounts (system 31, serial 23)

Deliverable: **screen correction + business rules + button** — `overrides/ST_ITEM_CLASS.json` (GRID on AR_ST_ITEMS_DISC:
the class-discount lines per item, no insert, update / delete; same row rule text as AR_ST_ITEM_CLASSES; action
LOAD_CLASSES), `APP_RULES3_SA` (`disc_line_row`, `item_load_classes`). Page 60100. Confidence: **medium**.

## Why a screen correction
The generated grid showed `ST_ITEM_CLASSES` (item class codes) — wrong. The legacy form is a copy of the item card (ST_ITEM with
groups, units, suppliers ...) whose purpose here is the tabs "فئات خصومات الاصناف" (the item's lines in every discount class,
`AR_ST_ITEMS_DISC`) and "فئات خصومات العملاء" (the item's customer lines, `ST_CUST_ITEMS`). The item card itself is maintained by
the item screen; the customer lines by ST_CUST_ITEMS.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Class line rules (group, unit, price 0..99999.99, discounts / bonus ≥ 0, no repeated item) | row rule (identical text to AR_ST_ITEM_CLASSES, generated once per table) | messages of this .fmx ("قيمة سعر البيع لا يمكن ...", "قيمة الخصم ...", "تم إدخال هذا السجل من قبل") | high |
| 2 | New lines only through the button (legacy: the class tab was filled by "إنزال كل الفئات") | grid insert = false | button | medium |

## Buttons
| Button | Implementation | Evidence |
|--------|----------------|----------|
| إنزال كل الفئات (add the item to every class that does not have it; modes "أضافة بدون حذف" / "حذف الكل والأضافة") | action LOAD_CLASSES (ITEM, LOAD_MODE) → `item_load_classes`: basic unit, retail price, MOH discount; "لا يوجد فئة لكي يتم أضافتها"; confirmation "هل تريد أضافة كل الفئات الحالية" | button + messages |

## Tests (`tmp\w3_prsa\t_w3prsa.py`, page 60100)
CI6 item added to all classes · CI7 nothing left to add · CI8 class line update on the grid. All PASS.

## Wave 3b
* **Wrong list replaced**: CLASS_CODE had the automatic list `AS_CLASS` (asset classes); it now shows the discount classes of
  `AR_ST_ITEM_CLASSES` (legacy LOV `SELECT CLASS_CODE, DESC_A, DESC_E FROM AR_ST_ITEM_CLASSES ORDER BY CLASS_CODE`), read-only as before.
* UNIT_CODE: units of the line's item (cascade ITEM_CODE / ITEM_GROUP_CODE); computed ITEM_NAME (the legacy item block showed
  the item's name).
* Check: `check_forms.py ST_ITEM_CLASS`.

## Coverage
Reproduced: class lines of an item (edit / delete), load-all-classes button, line rules; class names instead of the wrong asset
list, units of the item, item name (wave 3b).
Not reproduced: the item-card blocks copied into this form (item, units, suppliers, dosage, brands, barcodes: maintained by the item
screen; their messages "لا يمكن الحفظ بدون وحدة اساسية", "معامل التحويل للوحدة الأساسية يجب أن يساوى واحد" ... belong to it), the
customer tab (ST_CUST_ITEMS screen), language switch, toolbar code.
