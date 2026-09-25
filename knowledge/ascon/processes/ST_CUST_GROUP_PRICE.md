# ST_CUST_GROUP_PRICE — تسعير العملاء / Customer Pricing (system 31, serial 28)

Deliverable: **business rules + 2 buttons on the generated master-detail** — `overrides/ST_CUST_GROUP_PRICE.json` (AUTO:
ST_CUST_GROUP_PRICE + ST_CUST_GROUP_PRICE_DET kept; customer-rights `where`, DEAL_TYPE shown, unit price read-only, row rule,
validation, after-save, actions), `APP_RULES3_SA` (`cgp_*`). Pages 60160 / 60161. Confidence: **medium-high**.

## Purpose and tables
Per customer (`ST_CUST_GROUP_PRICE`, PK CUST_CODE: price basis DEAL_TYPE, group / item ranges, notes) the discounted items
(`ST_CUST_GROUP_PRICE_DET`: item, unit, discount % / value, quantity range FROM_QTY..TO_QTY, UNIT_PRICE shown). Both empty.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Customers within the user's customer ranges (`AR_CUSTOMER_PASSWORD`) | `rules.where` | customer LOV | medium-high |
| 2 | Customer required and existing | validation | LOV "ارقام العملاء" | high |
| 3 | Line: group of the item, unit (basic by default), UNIT_PRICE = retail price of the basic unit | row rule `cgp_det_row` | line SQL, labels "سعر البيع", "سعر التكلفة" | high |
| 4 | A discount needs an item price — "يجب إدخال سعر الصنف"; % between 0 and 100; value between 0 and the price | row rule | message | medium-high |
| 5 | Discount % ↔ value on the unit price | row rule | WVI triggers "خصم الأصناف", "قيمة الصنف" | medium-high |
| 6 | Quantity ranges of an item may not intersect — "الكميات لا يمكن ان تتقاطع" (FROM > TO on a line, overlapping lines of the same item) | row rule + after-save `cgp_after_save` | message | high |

DISC_PERCENT is NUMBER(4,2): values above 99.99 cannot be stored at all (ORA-01438 before any rule).

## Buttons
| Button | Implementation | Evidence |
|--------|----------------|----------|
| إنزال الأصناف (items of the header's group / item ranges not yet listed; basic unit; discount 0) | action GET_ITEMS → `cgp_get_items`; group rights of the user; "تم الانتهاء من اضافة اصناف العميل" | button + message |
| نسخ اصناف و مجموعات العميل الحالي الي عميل اخر (copy to another customer, "نسخ النسبة مع كل صنف" optional) | action COPY_TO (TO_CUST, COPY_RATIO) → `cgp_copy`: header created when missing, lines appended with or without the discount; "لا بد من ادخال رقم عميل لكي يتم نسخ الاصناف لة", "تم الانتهاء من نسخ اصناف العميل" | dialog labels "من عميل / إلي عميل / نسخ النسبة / نسخ الاصناف" + messages |

## Tests (`tmp\w3_prsa\t_w3prsa.py`, page 60161)
CG1 line derivations (price, value from %) · CG2 negative % · CG2b value above the price · CG3 intersecting ranges ·
CG4 load items · CG5 copy with the ratio · CG6 copy without the ratio · CG7 copy needs a customer. All PASS.

## Wave 3b
* Legacy LOVs of the .fmx as lists: header group range (active groups, ST_GROUP_PASSWORD), header item range (items inside the
  chosen group range, group rights; cascade FROM_GROUP_CODE / TO_GROUP_CODE); lines: group, item (of the line's group when given;
  cascade ITEM_GROUP_CODE), unit (units of the item; cascade ITEM_CODE / ITEM_GROUP_CODE).
* `rules.computed`: CUST_NAME "اسم العميل" on the header and ITEM_NAME "إسم الصنف" on the lines (legacy display items).
* DEAL_TYPE "سعر البيع المستخدم" was a list item (DEAL_TYPEL) but its values are not in the evidence and both tables are empty:
  still a number field (question).
* Check: `check_forms.py ST_CUST_GROUP_PRICE` (6 lists, 2 computed columns).

## Coverage
Reproduced: rights filter, customer, line rules, range intersection, load items, copy to another customer; group / item / unit
lists, customer and item names (wave 3b).
Not reproduced: the "from customer" field of the copy dialog (the copy always starts from the displayed customer), cost price
display "سعر التكلفة" (display only, formula not visible), the values of the price-basis list DEAL_TYPE (question), save-first
messages, Forms alerts / toolbar code.
