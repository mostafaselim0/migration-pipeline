# AR_ST_ITEM_CLASSES — ملف خصومات الفئات / Class Discounts (system 31, serial 21)

Deliverable: **screen correction (columns) + business rules + Excel button** — `overrides/AR_ST_ITEM_CLASSES.json`
(MASTER_DETAIL on the generated tables AR_ST_ITEM_CLASSES + AR_ST_ITEMS_DISC, legacy column order, general-class flag added,
row rule, validation, action), `APP_RULES3_SA` (`class_validate`, `disc_line_row`, `class_load_excel` / `class_load_blob`).
Pages 60080 / 60081. Confidence: **medium-high**.

## Purpose and tables
Discount classes (`AR_ST_ITEM_CLASSES`: CLASS_CODE, names, DEFAULT_FLAG; 2 rows) with their item lines ("شرائح الخصم",
`AR_ST_ITEMS_DISC`: item, unit, sales price, MOH discount, discounts 2-3, bonus %, extra bonus %; empty). Customers get the
lines of a class through ST_CUST_ITEMS.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Class number = max + 1 (read-only) | generated key | serial item "مسلسل" | medium |
| 2 | Arabic or English name — "يجب ادخال الأسم عربى أو لاتينى" | validation `class_validate` | message | high |
| 3 | Only one general class (DEFAULT_FLAG) — "يوجد فئة عامة أخري مسجلة" | validation | check box "فئة عامة" + message | high |
| 4 | Line: class exists "لابد من أدخال الفئة أولا"; group of the item (active); item of the group; unit of the item (basic by default); price = retail price of the unit; discount 1 = MOH discount (on insert) | row rule `disc_line_row('AR_ST_ITEMS_DISC', ...)` | line triggers / labels "خصم وزارة الصحة (%)" | high |
| 5 | Price 0..99999.99 — "قيمة سعر البيع لا يمكن ان تكون اقل من الصفر او اكبر من 99999.99"; discounts ≥ 0 — "قيمة الخصم لا يمكن ان تكون اقل من الصفر"; bonus ≥ 0 — "قيمة الاضافي لا يمكن ان تكون اقل من الصفر" | row rule | messages | high |
| 6 | No repeated item in the class — "شريحة الخصم مكررة لنفس الصنف" | row rule (INSERT) | message | high |

## Buttons
| Button | Implementation | Evidence |
|--------|----------------|----------|
| تحميل EXCEL | action LOAD_EXCEL (file parameter) → `class_load_excel` / `class_load_blob`: columns item, unit, price, discount 1-3, bonus %, extra bonus %; empty unit / price / discount 1 from the item; items already in the class skipped; unknown items reported; "تم تحميل ملف الأكسل", "يجب إدخال مسار الملف", "خطأ فى إسم الملف" | WEBUTIL button + messages |

## Open questions
* Excel column layout assumed (A item, B unit, C price, D-F discounts 1-3, G bonus %, H extra bonus %), first sheet; confirm with
  a legacy sample file.

## Tests (`tmp\w3_prsa\t_w3prsa.py`, page 60081)
CL1 name required · CL2 second general class refused · CL2b the general class itself passes · CL3 line derivations ·
CL4 repeated item · CL5 price > 99999.99 · CL6 negative discount · CL7 negative bonus · CL8 unknown class · CL9 Excel load
(values given / defaults, invalid row reported). All PASS.

## Wave 3b
* **Wrong list removed**: the generator had attached `AS_CLASS` (asset classes) to CLASS_CODE, so the list page and the form
  showed asset-class names for the discount classes. `lov: null` on AR_ST_ITEM_CLASSES.CLASS_CODE (read-only serial) and on the
  lines' join column.
* DEFAULT_FLAG: check box 1/0 "فئة عامة" (legacy check box, rule 3; was a number with the legend "(1)").
* Lines: item list from the legacy LOV (active items with their basic unit), units of the item (`ST_ITEM_UNIT`, basic unit
  marked; cascade ITEM_CODE / ITEM_GROUP_CODE); computed ITEM_NAME "إســم الصنـــف" and NDB_FACTOR "معامل التحويل" (factor of
  the line's unit in ST_ITEM_UNIT), the legacy display items.
* Check: `check_forms.py AR_ST_ITEM_CLASSES` (2 lists, 2 computed columns).

## Coverage
Reproduced: name, general class (check box), line rules, Excel load; the class number without the wrong asset-class list; item /
unit lists, item name and unit factor (wave 3b).
Not reproduced: the class report ("طباعة السند", "يجب إدخال قيمة الفئة لتنفيذ التقرير": printing is outside Stage C), save-first
messages (Forms mechanics), toolbar / translation code.
