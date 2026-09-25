# ST_TAKING — stocktaking count entry (إدخال أرصدة الجرد)

System 3 serial 111 (FILES_MENU.ST_TAKING). Deliverable: **(a) AUTO + rules** (`overrides\ST_TAKING.json`, `APP_RULES_ST`) and,
from wave 3, buttons / displays in `APP_ACT_ST` (`tk_*`).

**Source.** Wave 2 worked from labels only (the evidence pack has no .fmb / .fmx) and mirrored the rules of ST_TAKING2.fmx. Wave 3
found the Forms source of this exact form: `C:\Smart Transformation\ST\FMB\ST_TAKING_fmb.xml` (module ST_TAKING1, from
`ASCON\ST\FMB\ST_TAKING.fmb` of 2025-03-13; the compiled `_ARCHIVE\ASCON\ST\FMB\ST_TAKING.fmx` has the same date). Triggers and
program units were extracted with `tmp\w3_sales\f5\x1.py` (`taking_src.txt`); the rules below cite them.

## Purpose and data

Counted quantities per store, date and lot: header ST_STOCK_TAKING (PK STORE_CODE + ST_TAKING_DATE), lines
ST_STOCK_TAKING_DET (PK + TAKING_NUMBER, FK to the header). ST_AUTO_ADJ compares BASIC_QTY / UNIT_COST of these lines with the
book balance per lot and creates the adjustment documents (types 11601 / 11701 …, DESC_E "Automatic adjustment for stocktaking in
date DD-MM-YYYY"). Data: 4 counts, 4 lines; SALES_PRICE = the lot price (ST_ITEM_CONFG.UNIT_PRICE: line of item 301040001 has 340
while the retail price is 299), DISC1_RATIO = the lot DISC_RATIO (40), UNIT_PRICE = UNIT_COST = book cost.

Not a shared-table screen: no transaction type filter.

## Rules implemented in wave 2 (APP_RULES_ST)

| # | Rule | Where | Evidence |
|---|------|-------|----------|
| 1 | List limited to the stores of the user's group (`:G_PASSWORD_NUMBER = 0 OR STORE_CODE IN ST_STORE_PASSWORD`) | `rules.where` | block WHERE of ST_STOCK_TAKING (source) |
| 2 | Store required, active, allowed; date required and not in the future; one count per store and date | `val_taking` | STORE_CODE / ST_TAKING_DATE WHEN-VALIDATE-ITEM ("تم جرد هذا المخزن من قبل في نفس التاريخ"), CHECK_DATE |
| 3 | TAKING_NUMBER = MAX + 1 per store and date | generic APPX key | line PRE-INSERT `SELECT NVL(MAX(NVL(TAKING_NUMBER,0)),0)+1 .. WHERE ST_TAKING_DATE .. AND STORE_CODE ..` |
| 4 | Line: item exists / not stopped, group derived, basic unit default, quantity required and ≥ 0, BASIC_QTY = QUANTITY × factor | `taking_det_row` | ITEM_CODE / UNIT_CODE / QUANTITY WHEN-VALIDATE-ITEM |
| 5 | Lot must belong to the item; required for expiry-tracked groups | `taking_det_row` | PRE-INSERT "يجب إدخال محددات الشحنات" (see differences) |
| 6 | UNIT_PRICE (label "تكلفة الوحدة") default = book average cost of the lot at the count date; UNIT_COST = UNIT_PRICE / factor | `taking_det_row` | CALC_COST, PRE-INSERT |
| 7 | Lines required at SAVE | `after_taking` | master PRE-INSERT / detail POST-DELETE (NONE_ALERT) |

## Wave 3: buttons, displays and line values (APP_ACT_ST)

| # | Legacy | APEX | Evidence (ST_TAKING_fmb.xml) | Confidence |
|---|---|---|---|---|
| B1 | "من ملف" (UPLOAD_EXCEL → LOAD_EXCEL_FILE): refused when the count has lines ("يوجد تفاصيل"); from the 2nd row ITEM_CODE, UNIT_CODE, EXPIRE_DATE (DD/MM/RRRR), LOT_NO, QTY, SALES_PRICE, DISC_RATIO until the first empty item code; group from ST_ITEM ("خطأ بالصنف …" stops the load); factor of the unit (else 1); lot = GET_THE_CONFIG (GET_CONFG_ID_SUPP: lot of the item with that lot number, price and expiry, **created when missing**, also inserts ST_STORE_ITEM); cost / price as the line PRE-INSERT (B7); "تم تحميل ملف الأكسل" | action **LOAD_FILE** (file parameter, `tk_load_file`; XLSX or CSV through apex_data_parser, XLSX dates arrive as YYYY-MM-DD); rows without expiry date or unit are refused as the legacy PRE-INSERT did at commit ("يجب إدخال محددات الشحنات") | UPLOAD_EXCEL trigger, LOAD_EXCEL_FILE, GET_THE_CONFIG, item tooltip "Excel load from 2nd row ITEM_CODE, UNIT_CODE, EXPIRE_DATE ,LOT_NO , QTY, SALES_PRICE ,DISC_RATIO" | high |
| B2 | "CSV" (UPLOAD_CSV → LOAD_CSV_FILE): from the 2nd row "ITEM_CONFG_ID,QTY"; item, basic unit, expiry, lot number, lot price (SALES_PRICE) and DISC_RATIO from the lot; errors (unknown lot / item) written to C:\ITEMS_LOAD_ERROR.TXT and the row passed over | action **LOAD_LOTS** (`tk_load_lots`): two columns or the legacy single cell "lot,qty"; bad rows skipped and listed in the success message (replaces the client error file); lots without expiry refused (PRE-INSERT) | UPLOAD_CSV trigger, LOAD_CSV_FILE | high (layout), medium (error handling: the legacy kept the previous row's values for a bad row — not reproduced) |
| B3 | "إنزال تكلفة أصناف الجرد" (CALC_COST): every line UNIT_COST := GET_UNIT_COST_CONFG(store, group, item, lot, count date, NULL, NULL), UNIT_PRICE := NVL(UNIT_COST,0) × FACTOR | action **CALC_COST** (`tk_calc_cost`) on the saved lines | CALC_COST trigger | high |
| B4 | STATUS display: adjustment documents of ST_AUTO_ADJ for the store and date (EFFECT 1/2, TRNS_TYPE 7, not deleted, DESC_E 'Automatic adjustment for stocktaking in date DD-MM-YYYY') → "لم يتم تسوية الجرد" / "تم عمل تسوية جرد حركة وارد رقم r/s حركة صادر i/s" (MIN type and MIN serial, legacy) | `info` STATUS (`tk_status`); English text: "Adjustment Trns With No r/s Issue Trns i/s" (the legacy English text contained the Arabic words "حركة صادر") | ST_STOCK_TAKING POST-QUERY; data: count 08-03-2025 → 11601/2 and 11701/3 | high |
| B5 | TOTAL_QTY "اجمالى الكمية" (summary item, Sum of QUANTITY) | `info` TOTAL_QTY (`tk_total_qty`) | item TOTAL_QTY (SummaryFunction Sum) | high |
| B6 | Line SALES_PRICE "سعر البيع" and DISC1_RATIO come from the lot (ITEM_CONFG_LOV); DISC1_VALUE = DISC1_RATIO × UNIT_PRICE / 100 (0 without ratio); ratio / value must not be negative ("أدخل رقم بقيمة تبدأ من الصفر") | columns added (`add_columns`: SALES_PRICE read-only, DISC1_RATIO, DISC1_VALUE read-only); after-save `tk_after_save` sets the lot price, the lot discount when empty and the value, and refuses negatives | LOV return items, DISC1_RATIO / DISC1_VALUE / UNIT_PRICE WHEN-VALIDATE-ITEM; data | high |
| B7 | Line PRE-INSERT cost: UNIT_COST := GET_UNIT_COST_CONFG(store, group, item, lot, date, **UNIT_CODE**) (the unit code lands in the DT_SERIAL argument), UNIT_PRICE := UNIT_COST × FACTOR | used by the loads (B1, B2) | line PRE-INSERT | high (formula) — see differences for manual lines |
| B8 | Delete: PRE-DELETE removes the lines, no other restriction | the generated page deletes the lines before the header | ST_STOCK_TAKING PRE-DELETE | high |

## Confidence: **high** for the wave-3 items (full trigger text), **medium** for the wave-2 rules that differ (see above)

## Questions for the key user

1. Should "إنزال أصناف المخزن" (hidden in the legacy ST_TAKING) be offered on this page? It lists every lot of every store item,
   also lots with zero balance (store 101010101001: 1,993 lines).
2. Keep the legacy cost at insert (book cost at date serial = unit code, typed cost discarded) or the wave-2 behaviour (typed cost kept)?
3. Should an adjusted count (STATUS "تم عمل تسوية جرد …") be locked?

## Wave 3b (new generator keys)

Evidence: `ST\FMB\ST_TAKING_fmb.xml` (the 2025 source).

| Change | Key | Evidence |
|---|---|---|
| Saved count lines cannot be changed (insert and delete only) | `blocks.ST_STOCK_TAKING_DET.update = false` | block `UpdateAllowed="false"` (difference 4 below) |
| Count date and store read-only after insert | `columns.ST_STOCK_TAKING.ST_TAKING_DATE / STORE_CODE.readonly_after_insert` | `UpdateAllowed="false"` |
| Unit cost column read-only (always the book cost) | `columns.ST_STOCK_TAKING_DET.UNIT_PRICE.readonly` | `UNIT_PRICE Enabled="false"` |
| Per line: item name, lot number, lot expiry, book balance "الرصيد الدفترى" = GET_BALANCE(store, group, item, count date) / factor | `computed.ST_STOCK_TAKING_DET.*` | display items; `GET_BALANCE_COST(..., :ST_STOCK_TAKING.ST_TAKING_DATE); :bal_qty := NVL(TEMP_BAL,0) / FACTOR` |
| Lot list of the line's item (lot id - lot number - expiry), refreshed when the item changes | `ITEM_CONFG_ID` `lov` + `cascade: ITEM_CODE` | legacy lot LOV (ITEM_CONFG_LOV / CONFG); the row rule still checks the lot and its balance |

CALC_COST, the loads and the after-save still change saved lines (server side; the grid flag only stops typing). Tested: expressions
and list run on the build copy. Still not reproduced: hiding UNIT_PRICE / DISC1_RATIO for users without ALLOW_VIEW_COST (the generator
cannot hide a column per user right; the values are shown).

## Coverage

Reproduced: rules 1-7 (wave 2), B1-B8 above. Tests: wave 2 G1-G4 (page 20061: duplicate count, derived line, lot of an expiry
group, save with lines); wave 3 `tmp\w3_sales\f5\t_f5.py` checks T1-T10 (XLSX load with an existing and a new lot, cost / price /
discount values, second load refused, total quantity, CALC_COST, after-save lot price / discount and negative refusal, file errors, CSV
load with a bad lot, decompose, status texts in Arabic and English), plain and simulated APEX session of page 20061, all rolled back.

Deliberately not reproduced:
- **"إنزال أصناف المخزن" (DECOMPOSE)**: the button is `Visible = false` in the 2025 source of this form, so users could not press it.
  The procedure exists (`tk_decompose`, used on ST_TAKING2 and tested here as shared code); offering it on this page is a one-line
  override change if the business wants it (question 1).
- "بيـانات الجرد" / "أرصدة المخزن" (PUSH_BUTTON55 / 56): width 0, disabled and without a trigger in the source (and without code in
  ST_TAKING2.fmx) — dead buttons.
- Forms-only mechanics: CHANGE_LANG, alerts, navigation (KEY-NEXT-ITEM, KEY-DUP-ITEM units window), ENABLE_DISABLE_CONFIG /
  SHOW_HIDE_CONFIG (colour / size / expiry item enabling: ST_BASIC.COLOR_FLAG = SIZE_FLAG = 0), SET_IP, dongle
  (CUSTOMER_ACCOUNT_BALANCE in PRE-INSERT), printing (st_taking_diff.RDF), WEBUTIL client error file.
- ADD_COST (hidden item, `Visible = false`): not used.
- AUTH_FLAG ("مؤشر إعتماد"): not an item of the 2025 source; no effect, left editable.
- USERS.ALLOW_VIEW_COST hides UNIT_PRICE / DISC1_RATIO for users without the right: no per-user column visibility in the generator
  (generator gap, still open). BAL_QTY per line: reproduced in wave 3b.

Differences found with the wave-2 row rule, applied by the coordinator in `APP_RULES_ST` (wave 3, tests `tmp\w3_sales\t_coord.py`
K1-K10, simulated APEX session of page 20061, rolled back):
1. **Applied.** The legacy line PRE-INSERT always recomputes UNIT_COST / UNIT_PRICE (B7): new overload
   `taking_det_row(inserting, ...)` — on insert UNIT_COST := GET_UNIT_COST_CONFG(store, group, item, lot, count date, UNIT_CODE) and
   UNIT_PRICE := UNIT_COST × factor (a typed cost is replaced); saved lines keep their cost (CALC_COST and the loads set it). The
   override's row rule now passes `inserting`; it becomes active when the APPX triggers are regenerated (until then the wave-2 string
   calls the old signature, which now behaves like an update: typed / defaulted cost kept).
2. **Applied.** SALES_PRICE defaults to the lot price (ST_ITEM_CONFG.UNIT_PRICE), retail price only without a lot.
3. **Applied** (new overload, insert): every new line needs a lot with an expiry date, else "يجب إدخال محددات الشحنات".
4. **Applied in wave 3b** (`blocks.update = false`): the detail block has UPDATE_ALLOWED = false (saved lines cannot be changed,
   only deleted and re-entered); CALC_COST / loads still update the lines server side.
5. **Applied** in `val_taking`: legacy text of the duplicate check "تم جرد هذا المخزن من قبل في نفس التاريخ", CHECK_DATE texts, and
   dates before ST_BASIC.MIN_DATE refused (also on ST_TAKING2, which calls CHECK_DATE too).

Update 2026-09-25: UNIT_PRICE and DISC1_RATIO are now hidden for users without USERS.ALLOW_VIEW_COST (show_if app_rules3_st.can_view_cost).
