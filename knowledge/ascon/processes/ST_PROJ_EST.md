# ST_PROJ_EST — تقدير طلبات المواد / Material Request Estimates (system 30, serial 29)

Deliverable: **business rules + button on the generated master-detail** — `overrides/ST_PROJ_EST.json` (AUTO: generated
ST_PROJ_EST_MAST + ST_PROJ_EST_DET kept; key_expr, row rules, defaults, read-only / hidden / optional items, validation,
after-save, action), `APP_RULES3_PR` (`next_est_serial`, `est_*`), delete hooks `APP_R3_ST_PROJ_EST_MAST_BD`,
`APP_R3_ST_PROJ_EST_DET_BD`. Pages 50160 / 50161. Confidence: **medium** (.fmx only; both tables empty).

## Purpose and tables
A store (or project, "المخزن الطالب - المشروع") estimates the quantities of items it will need (`ST_PROJ_EST_MAST` per store and
date, lines `ST_PROJ_EST_DET`: item, unit, quantity, basic quantity, colour, size). The material requests of the store
(`ST_ITEM_REQ` / `ST_ITEM_REQ_DET`, transfer requests `ST_TRNS_MAST_REQUEST` / `ST_TRNS_DET_REQUEST`) may not exceed the
estimate. **No approval exists in the evidence** (the task mentioned one): the .fmx has no approval flag, button or message.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Serial = max + 1 per store | key_expr `next_est_serial(:new.store_code)` | PK (TRNS_SERIAL, STORE_CODE), max query of the .fmx | high |
| 2 | Date serial = max + 1 per store and date | row rule `est_mast_row` | .fmx SQL | medium |
| 3 | Store required and allowed — "ادخل رقم المخزن"; store list (active, rights) | validation `est_validate` | message, store LOV | high |
| 4 | Date not after today / not before the minimum (library CHECK_DATE) | validation (`date_error`) | CHECK_DATE | high |
| 5 | One estimate per store and date — "المخزن الحالى موجود فى نفسي التاريخ" | validation | .fmx SQL + message | high |
| 6 | No new estimate before a later one of the store — "تم عمل تقدير فى تاريخ أكبر من التاريخ الحالى" | validation | .fmx SQL + message | high |
| 7 | Line: item active, group from the item, unit of the item (basic by default), quantity > 0 "الكمية يجب أن تكون أكبر من الصفر", basic quantity = quantity × factor, colour / size required when the group uses them "يجب ادخال اللون" / "يجب ادخال المقاس", date serial of the header | row rule `est_det_row` | line triggers / messages | high |
| 8 | Estimated quantity not below what the store already requested — "إجمالى الكمية المطلوبة = n و لا يمكن ان يكون أكبر من الكمية المقدرة" | row rule | .fmx SQL on ST_ITEM_REQ_DET + message | high |
| 9 | Lines required — "يجب إدخال الاصناف"; repeated item refused when ST_BASIC.SINGLE_ITEM = 1 — "هناك صنف مكرر" | after-save `est_after_save` | messages | high |
| 10 | Estimate delete refused while the store has material / transfer requests — "طلب النواقص الحالي له طلب شراء او عروض أسعار مرتبطة و لا يمكن الحذف", "... له طلب تحويل مرتبطة ..." | trigger `APP_R3_ST_PROJ_EST_MAST_BD` → `est_mast_delete` (page-aware) | .fmx SQL + messages | high |
| 11 | Line delete refused while the item was requested by the store (same messages) | trigger `APP_R3_ST_PROJ_EST_DET_BD` → `est_det_delete` | .fmx SQL | high |

## Buttons
| Button | Implementation | Evidence |
|--------|----------------|----------|
| إنزال أصناف اخر تقدير على المخزن (copy the lines of the store's last earlier estimate) | action COPY_LAST → `est_copy_last` (items not yet on the estimate; message with the count) | button label + SQL |
| تزويد عام (general supply: group / item range and minimum quantity "أدخل الحد الأدنى للكمية الذي سيتم الطلب إذا انخفض رصيد الصنف عنه") | **not reproduced** | the quantity rule of the fill is not visible (question) |
| عرض أرصدة المخازن (store balances) | not reproduced: display only (GET_BALANCE library) | label |

## Open questions
* "تزويد عام": which quantity is written for each item of the range (minimum − balance? the minimum itself?) and which balance
  (store / date)? Needed to reproduce the button.
* "المشروع الحالى مسجل من قبل" (project already registered): appears to be the same check as rule 5 for project stores;
  implemented only as rule 5.

## Tests (`tmp\w3_prsa\t_w3prsa.py`, page 50161, material request fixture for the store)
EP1 serial / date serial · EP2 line derivations · EP3 quantity 0 refused · EP4 same store and date · EP5 later estimate exists ·
EP6 future date · EP7 unknown store · EP7b valid header · EP8 lines required · EP9 copy last estimate · EP10 quantity below the
requested quantity refused · EP10b higher quantity accepted · EP11 requested item line not deleted · EP11b other line deleted ·
EP12 estimate of a store with requests not deleted. All PASS.

## Wave 3b
* Legacy LOVs of the .fmx as lists: store (active, not stopped, ST_STORE_PASSWORD), items (active, ST_GROUP_PASSWORD, ordered by
  number) and units of the line's item (`ST_ITEM_UNIT`, basic unit marked; cascade ITEM_CODE / GROUP_CODE).
* `rules.computed` ST_PROJ_EST_DET.ITEM_NAME "إســم الصنـــف" (legacy display item ITEM_NAME).
* The legacy store list also hid stores that already have an estimate on the record's date; that rule stays a validation
  (`est_validate`, "one estimate per store and date") because a list filtered on the record's own date would drop the saved
  record's store.
* Check: `check_forms.py ST_PROJ_EST` (3 lists, 1 computed column run).

## Coverage
Reproduced: numbering, header checks, line rules, requested-quantity limit, lines required, delete restrictions, copy of the
last estimate; legacy store / item / unit lists and item name (wave 3b).
Not reproduced: "تزويد عام" (question), balance display, language switch, Forms alerts / toolbar code.
