# ST_PO_ITEM_SUPP — تحضير أوامر الشراء / Preparing Purchase Orders (system 30, serial 41)

Deliverable: **screen correction (columns) + business rules + 6 buttons** — `overrides/ST_PO_ITEM_SUPP.json` (MASTER_DETAIL on
the generated tables ST_PO_ITEM_SUPP + ST_PO_ITEM_SUPP_DET, legacy column order, display columns read-only, row rule,
validation, actions), `APP_RULES3_PR` (`prep_*`). Pages 50240 / 50241. Confidence: **medium** (.fmx only; 1 header with 31
test lines in the data).

## Purpose and tables
The buyer lists the items of a supplier / manufacturer / class / agreement (`ST_PO_ITEM_SUPP_DET`), fills quantities and bonus,
chooses lines (CHK) and turns the chosen lines into a **confirmed purchase order** (`PR_ORDER` / `PR_ORDER_DET`) for the order
supplier, store and order type of the header. The header keeps the order number (PR_ORDER_TRNS_TYPE_CODE / SERIAL).

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Header: from date ≤ to date; order supplier active; order store active; order type from ST_PR_ORDER_TYPES | validation `prep_validate` | LOVs, dates | medium-high |
| 2 | Line: item required "إختر صنف لهذا السجل أولاً", active item, group / supplier / manufacturer of the item | row rule `prep_det_row` | line triggers | high |
| 3 | Price: retail price of the basic unit and discount 1 = MOH discount when the price is empty and the line is entered, has a quantity or is chosen | row rule | line SQL (`ST_ITEM_UNIT.RETAIL_SALE_PRICE`, `ST_ITEM.MOH_DISC`) | medium-high |
| 4 | Ratios 0 ≤ r < 100, values ≥ 0 (legacy messages) | row rule | messages | high |
| 5 | Bonus ↔ bonus %; extra bonus = TRUNC(quantity × extra %) ↔ extra %; discount chain; M_DISC / PO_M_DISC values from their ratios | row rule | WVI triggers; data (80 × 4 % = 3) | medium-high |
| 6 | Chosen line: quantity + bonus > 0 — "الكمية و البونص يجب أن يكون مجموعهما أكبر من صفر"; price required — "لابد من ادخال سعر الوحدة" | row rule | messages | high |

## Buttons
| Button | Implementation | Evidence |
|--------|----------------|----------|
| انزال الاصناف (load items) | action GET_ITEMS → `prep_get_items`: active items of the supplier / manufacturer / class (and of the agreement for the order supplier), zero quantities; refused while lines exist "يجب حذف البيانات المسجلة" | button + messages + SQL |
| اختيار الكل / استبعاد الكل | actions SELECT_ALL / DESELECT_ALL → `prep_mark('ALL' / 'NONE')` | buttons |
| حذف الصفر | action DELETE_ZERO → `prep_mark('ZERO')`: lines without quantity and bonus deleted | button |
| تحميل EXCEL | action LOAD_EXCEL (file parameter) → `prep_load_excel` / `prep_load_blob`: columns item, quantity, bonus (quantities of repeated items added, like the legacy ST_ITEM_EXCEL sums), existing line updated or new line added, chosen; unknown / stopped items reported; "يجب إدخال مسار الملف", "خطأ فى إسم الملف" | WEBUTIL → `INSERT INTO ST_ITEM_EXCEL (ITEM_CODE, QUANTITY, BONUS)`, `SELECT SUM(QUANTITY), SUM(BONUS) FROM ST_ITEM_EXCEL WHERE ITEM_CODE = :b1` |
| تحويل لأمر شراء / أمر الشراء (make purchase order) | action MAKE_ORDER (order type, date) → `prep_make_order`: PR_ORDER numbered per type, supplier currency and rate, the five fixed footer memos, lines of the chosen rows (quantity, bonus, %, price, discounts, M_* values, link ST_PO_SERIAL / GROUP / ITEM), confirmed; header linked; offered once only (`prep_can_order`); "إستكمل البيانات" | `INSERT INTO PR_ORDER (..., CONFIRM_FLAG, ..., FOTTER1_MEMO ...) VALUES (..., 1, ...)` of the .fmx |

The order is inserted unconfirmed and then confirmed, so the purchase-order rules of wave 2 (`APP_RULES_PR`: lines exist,
quantity + bonus > 0, price > 0) check it exactly as a manual confirmation.

## Not reproduced / generator limits
* **Statistics per line** — wave 3b reproduces the ones whose formula is in the .fmx (see Wave 3b). Still missing: average
  monthly sales "متوسط بيع شهرى", months / days of cover, real balance "الرصيد الفعلى", suggested quantity "الكمية المقترحة", store
  cover "تغطية المستودع", lot quantity "كمية الرسائل" (the AVG_FACTOR / ORDER_FACTOR formulas are compiled p-code, not visible),
  and the copy of the statistics into `PR_ORDER_DET_PREPARE`.
* Warning "البونص أقل من الإتفاقية" (bonus below the agreement) on unsaved lines: page warnings cannot see grid lines.
* "إستعلام عن أصناف مورد" (query the supplier's items: navigation) and the report "نوع التقرير" with amounts in words (printing).

## Open questions
* Excel layout assumed: column A item code, B quantity, C bonus, first sheet, optional header row (non-numeric item skipped).
* Order supplier / store LOV restrictions (store types of ST_BASIC DMG_STORE / RECALL_STORE appear in the .fmx) — only
  "active" is checked.

## Tests (`tmp\w3_prsa\t_w3prsa.py`, page 50241)
PO1 load refused while lines exist · PO2 load items with zero quantities · PO3 price / MOH discount / bonus / truncated extra
bonus · PO4 chosen line without quantity refused · PO5 ratio ≥ 100 · PO6 delete zero lines · PO7 / PO7b choose all / none ·
PO8 order offered · PO9 Excel load (new line, "101011545.0", unknown item reported) · PO9b Excel load onto a loaded zero line
(price and MOH discount set) · PO10 order created confirmed with footers · PO11 order lines · PO12 header linked, not offered
again · PO13 second order refused. All PASS (PO10-PO13 run through the wave-2 purchase-order row rules in the APEX session).

## Wave 3b
* `rules.computed` on the lines (display only, per row; alias t = the line, header by `SERIAL`), formulas of the .fmx
  (`INSERT INTO ST_TRNS_DET_INFO SELECT ... FROM ST_TRNS_DET_COST, ST_TRNS_TYPE, ST_ITEM_CONFG ...` and the order-count query),
  legacy labels of the display items:
  - NET_SALES "صافى بيع" / NET_PURCH "صافى شراء": basic quantity of sales (22) minus sales returns (44), purchases (11) minus
    purchase returns (33), opening-balance types excluded, dated between the header من تاريخ / إلى تاريخ;
  - GNRL_BAL / DMG_BAL / DISTRB_BAL: balance of the ST_BASIC stores GNRLZ_STORE / DMG_STORE / DISTRB_STORE; TOT_BAL "الرصيد
    التعميمات": balance of all stores (sign by EFFECT 1 +, 2 -, 3 -, 4 +, 5 -, 6 +);
  - LAST_PURCH_DATE "آخر تاريخ شراء": last purchase (11, not opening balance);
  - SUM_PR_OPEN / SUM_PR_CLOSE: confirmed, not closed purchase-order lines of the item with ORDER_STATUS 0 / not 0.
  The dates of the net sales / purchases are taken to be the header dates (the only date range of the screen; the .fmx binds
  them as :b1 / :b2) — medium confidence. Run on the build copy: 31 lines in 0.01 s; TOT_BAL / last purchase / open orders give
  real values for items with movements (e.g. 101011827: 4635, 11/05/2026, 3 open orders).
* `rules.columns`: CHK check box 1/0 "اختيار" (GN_FORM_ITEM check box; data 0 / 1; `prep_mark` writes 1 / 0) instead of the
  "(1)" legend; header LOVs of the .fmx: SUPP_CODE / PO_SUPP (active suppliers), PO_STORE (active, not stopped stores),
  PR_ORDER_TYPE (ST_PR_ORDER_TYPES), FROM_KIND (manufacturers of the supplier in VN_SUPP_KIND, all when no supplier: cascading list on
  SUPP_CODE, legacy LOV), FROM_CLASS (ST_ITEM_CLASSES), CNTRCT_SERIAL (agreements of the order supplier, active supplier:
  cascading list on PO_SUPP; legacy LOV without its non-database CNTRCT_CODE filter).
* Check: `check_forms.py ST_PO_ITEM_SUPP` — 7 lists and 9 computed columns run.

## Coverage
Reproduced: header / line rules, load items, choose / exclude all, delete zero lines, Excel load, make order; line statistics
net sales / purchases, store and total balances, last purchase date, open / closed orders (wave 3b); check box and header lists.
Not reproduced: average sales, cover, real balance, suggested quantity, store cover, lot quantity and PR_ORDER_DET_PREPARE
(formulas not visible), bonus-below-agreement warning (warnings on grid rows: generator), navigation / print buttons (reasons above), Forms alerts / toolbar code.
Question: ST_BASIC DMG_STORE / GNRLZ_STORE / DISTRB_STORE are 2 / 2 / 1 in the build copy, but the store codes of this site have
12 digits, so those three balances are always 0 — which stores should they be?
