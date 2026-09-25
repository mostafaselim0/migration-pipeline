# ST_CUST_ITEMS — ملف خصومات اصناف العملاء / Customer Item Discounts (system 31, serial 20)

Deliverable: **screen correction + business rules + button** — `overrides/ST_CUST_ITEMS.json` (GRID on ST_CUST_ITEMS with the
customer as a column, row rule, page action LOAD_CLASS with parameters), `APP_RULES3_SA` (`disc_line_row('ST_CUST_ITEMS',
...)`, `cust_load_class`). Page 60090. Confidence: **medium-high**.

## Purpose and tables
Per customer, the discounted items (`ST_CUST_ITEMS`: customer, item, unit, sales price, MOH discount, discounts 2-3, bonus,
extra bonus, CLASS_CODE of origin; 2 rows). The legacy form had the `CUSTOMER` block as master (query only) and the lines as
detail.

## Why a grid
A master-detail override would put CUSTOMER in an editable master block (the insert / update / delete flags of an override apply
to every block), letting users create customers here. The grid shows the lines with the customer column (search by customer);
the class-load button takes the customer as a parameter.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Line: active group of the item, unit (basic by default), retail price, MOH discount on insert | row rule `disc_line_row` | line triggers | high |
| 2 | Price 0..99999.99, discounts ≥ 0, bonus ≥ 0 (legacy messages as AR_ST_ITEM_CLASSES) | row rule | messages | high |
| 3 | No repeated item for the customer — "شريحة الخصم مكررة لنفس الصنف" | row rule (INSERT) | message | high |
| 4 | A line with a class must be an item of that class — "هذا الصنف غير مسجل لنفس الفئة ... رقم الصنف :" | row rule | message | high |

## Buttons
| Button | Implementation | Evidence |
|--------|----------------|----------|
| إنزال أصناف الفئة (load a class's items for the customer; ranges of main supplier "من / الي المورد الرئيسى" and manufacturer "من / الي المصنع"; mode "أضافة بدون حذف" / "حذف الكل والأضافة") | action LOAD_CLASS (CUST, CLASS, FROM_SUPP, TO_SUPP, FROM_KIND, TO_KIND, LOAD_MODE) → `cust_load_class`: active items of the class within the ranges, not yet on the customer; mode 2 deletes the customer's lines first; "يجب ادخال البيانات", "لا يوجد فئة لكي يتم أضافة اصنافها", "تم الانتهاء من اضافة اصناف العميل" | dialog labels + messages |

## Tests (`tmp\w3_prsa\t_w3prsa.py`, page 60090)
CI1 item not in the line's class · CI2 repeated item · CI3 class items added without delete · CI4 delete all and add within a
manufacturer range · CI5 class required. All PASS. (A first run found that a multi-row INSERT … SELECT mutates the table read
by the row rule; `cust_load_class` now inserts line by line.)

## Wave 3b
* Legacy LOVs as lists: customer (active, not stopped, old code / code / name — the legacy customer LOV of the load button),
  item (active items with their basic unit), units of the item (cascade ITEM_CODE / ITEM_GROUP_CODE).
* `rules.computed`: ITEM_NAME "إســم الصنـــف" and NDB_FACTOR "معامل التحويل" (legacy display items).
* Check: `check_forms.py ST_CUST_ITEMS` (3 lists, 2 computed columns on the 2 lines of the build copy).

## Coverage
Reproduced: line rules, class check, load-class button with both modes and ranges; customer / item / unit lists, item name and
unit factor (wave 3b).
Not reproduced: the customer master block (grid instead, reason above), the report "طباعة السند", the "إنزال أصناف
المورد/المصنع" caption (same dialog), Forms alerts / toolbar code.
