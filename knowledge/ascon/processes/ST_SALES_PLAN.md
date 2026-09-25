# ST_SALES_PLAN — خطة المبيعات على فترات / Sales Plan in Periods (system 31, serial 13)

Deliverable: **business rules + labels on the generated master-detail** — `overrides/ST_SALES_PLAN.json` (AUTO: ST_SALES_PLAN +
ST_SALES_PLAN_DET kept; labels, default sales type, row rule, validation), `APP_RULES3_SA` (`plan_validate`, `plan_det_row`).
Pages 60140 / 60141. Confidence: **medium-low** (the compiled form does not match this database, see below).

## Purpose and tables
Planned quantities and prices of items per period (`ST_PERIODS`), store and sales transaction type: header `ST_SALES_PLAN`
(PK PERIOD_CODE, STORE_CODE, TRNS_TYPE_CODE), lines `ST_SALES_PLAN_DET` (ITEM_CODE, QTY, PRICE). Both tables are empty.

## Form / database mismatch
The .fmx queries area and branch columns (`MAINAREA_ID`, `SUBAREA_ID`, AR_MAINAREA / AR_SUBAREA lists "المنطقة", "الفرع") and a
group column that **do not exist** in ST_SALES_PLAN / ST_SALES_PLAN_DET here, and `ST_SALES_PLAN_DET` has **ITEM_CODE alone as
primary key** (an item can be planned only once in the whole table). The form was compiled against another version of the tables;
only the parts that fit the existing columns are reproduced.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Period from ST_PERIODS; store from the store list; sales transaction EFFECT 2 / TRNS_TYPE 2 within the user's type rights (CREATE) | validation `plan_validate` | LOVs "الفترة", "المستودع", "حركة المبيعات" | medium |
| 2 | Default sales type: the user's first sales-invoice type | `defaults` (`app_rules_sa.first_type('SI')`) | WHEN-CREATE-RECORD | medium |
| 3 | Line: active item with a basic unit; price = retail price when empty; quantity and price required — "لابد من ادخال الكمية والسعر" | row rule `plan_det_row` | message, item LOV | medium |

PRICE is NUMBER(12,0) in the table: a retail price of 64.4 is stored as 64 (as in the legacy table).

## Not reproduced (cannot reconstruct)
* "نسخ فترة" / "نسخ أصناف الفترة" (copy a period's lines to another period): impossible with ITEM_CODE as the only key of the lines.
* "إنزال الاصناف" (load items) and the area / branch selection: built on the missing columns; the fill rule is not visible.
* Messages about customers ("تم الانتهاء من نسخ اصناف العميل", "لا بد من ادخال رقم عميل ...") are dead code copied from the
  customer-pricing form.

## Open questions
* Is this screen still used? If yes, which table version is right (area / branch / group columns, line key with period, store and
  type)? A table change would be needed before the copy / load buttons can be built.

## Tests (`tmp\w3_prsa\t_w3prsa.py`, page 60141; period and header fixtures)
SP1 unknown period · SP2 valid header · SP3 purchase type refused as sales type · SP4 retail price by default ·
SP5 quantity required. All PASS.

## Wave 3b
* Legacy LOVs as lists: store (active, not stopped, ST_STORE_PASSWORD), sales transaction (EFFECT 2 / TRNS_TYPE 2, type rights),
  line item (active items with a basic unit, group rights). The period list stays the generated ST_PERIODS list (legacy LOV).
* Check: `check_forms.py ST_SALES_PLAN` (3 lists).

## Coverage
Reproduced: header lists (legacy store / type / item lists since wave 3b), default type, line rules.
Not reproduced: copy period, load items, area / branch selection (tables do not match the form — question above), printing,
toolbar code.
