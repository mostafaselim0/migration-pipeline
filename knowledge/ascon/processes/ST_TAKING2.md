# ST_TAKING2 — revaluation count entry (اعادة تقييم تكلفة المخزون)

System 3 serial 522 (menu FILES_MENU.ST_TAKING). Source: compiled form only (`ST\FMB\ST_TAKING2.fmx`, evidence
`app\legacy\evidence\ST_TAKING2.md`). Deliverable: **(a) screen correction + rules** — `overrides\ST_TAKING2.json` is
`"pattern": "MASTER_DETAIL"` on **ST_STOCK_TAKING_TEMP / ST_STOCK_TAKING_TEMP_DET** instead of the generated ST_STOCK_TAKING.

## Why the tables change

The generated screen was mapped from the GN_FORM_ITEM labels (block names ST_STOCK_TAKING / ST_STOCK_TAKING_DET, copied from
ST_TAKING). The compiled form references only ST_STOCK_TAKING_TEMP, ST_STOCK_TAKING_TEMP_DET and ST_STOCK_TAKING_DET (the
latter only as the block name inside LOV binds): `SELECT NVL(MAX(SERIAL),0)+1 FROM ST_STOCK_TAKING_TEMP WHERE STORE_CODE = :b1
AND ST_TAKING_DATE = :b2`, `SELECT NVL(MAX(NVL(TAKING_NUMBER,0)),0)+1 FROM ST_STOCK_TAKING_TEMP_DET WHERE ..`, `DELETE FROM
ST_STOCK_TAKING_TEMP_DET ..`, the unit LOV bound to `:ST_STOCK_TAKING_TEMP_DET.GROUP_CODE`, and the adjustment status queries
on ST_TRNS_MAST.SERIAL_TAKING_TEMP. Its companion process ST_AUTO_ADJ2 (serial 523) reads the same TEMP tables
(catalog: ST_AUTO_ADJ2 tables = ST_AUTO_ADJ_ERR2, ST_STOCK_TAKING_TEMP, ST_STOCK_TAKING_TEMP_DET). Several counts per store and
date are possible (SERIAL). Both TEMP tables are empty in the data.

## Rules implemented

| # | Rule | Where | Evidence |
|---|------|-------|----------|
| 1 | Master ST_STOCK_TAKING_TEMP, detail ST_STOCK_TAKING_TEMP_DET joined on ST_TAKING_DATE + STORE_CODE + SERIAL | override | PKs of the two tables, SQL above |
| 2 | List limited to the group's stores | `rules.where` | DEFAULT_WHERE `(:1=0 OR STORE_CODE IN (SELECT DISTINCT STORE_CODE FROM ST_STORE_PASSWORD ..))` |
| 3 | SERIAL = MAX + 1 per store and date (generic key of the last PK column, read-only on the page) | APPX key | `SELECT NVL(MAX(SERIAL),0)+1 FROM ST_STOCK_TAKING_TEMP WHERE STORE_CODE = :b1 AND ST_TAKING_DATE = :b2` |
| 4 | TAKING_NUMBER = MAX + 1 per date, store and serial (hidden) | `key_expr` → `next_temp_taking_no` | `SELECT NVL(MAX(NVL(TAKING_NUMBER,0)),0)+1 FROM ST_STOCK_TAKING_TEMP_DET WHERE ST_TAKING_DATE = :b1 AND STORE_CODE = :b2 AND SERIAL = :b3` |
| 5 | Store required / active / allowed, date required and not in the future | `val_taking` | store LOV, CHECK_DATE |
| 6 | Lines as ST_TAKING: item / group / unit, quantity ≥ 0, BASIC_QTY, lot of the item (required for expiry groups), UNIT_PRICE = book cost at the date, UNIT_COST = UNIT_PRICE / factor | `taking_det_row2` | "إنزال تكلفة أصناف الجرد" (GET_UNIT_COST_CONFG), "يجب ادخال التاريخ", unit LOV / FACTOR |
| 7 | Lines required at SAVE; deleting a count deletes its lines (TEMP_DET has no FK to the header) | `after_taking` (SAVE, DELETE) | "لا يمكن الحفظ بدون تفاصيل", `DELETE FROM ST_STOCK_TAKING_TEMP_DET S WHERE S.STORE_CODE = :b1 AND S.ST_TAKING_DATE = :b2 AND S.SERIAL = :b3` |

## Wave 3: buttons and displays (APP_ACT_ST)

| # | Legacy (ST_TAKING2.fmx) | APEX | Evidence | Confidence |
|---|---|---|---|---|
| B1 | "إنزال أصناف المخزن" (DECOMPOSE): only on a count without lines; one line per item (basic unit, `ST_ITEM.STOP_FLAG = 0`, group rights ST_GROUP_PASSWORD) and **every** lot of the item held by the store (ST_STORE_ITEM), ordered by group and item; UNIT_COST := GET_UNIT_COST_CONFG(store, group, item, lot, date), BASIC_QTY := GET_BALANCE_CONFG(...) , QUANTITY := BASIC_QTY, UNIT_PRICE := UNIT_COST | action **DECOMPOSE** (`tk_decompose(.., 'ST_TAKING2')`): lines with TAKING_NUMBER 1..n, cost ABS(...) as in the ST_TAKING source, lots with zero balance included (the zero-balance CLEAR_RECORD is commented out in the ST_TAKING source) | fmx SQL `SELECT ST_ITEM.PEICE_NO , ST_ITEM.ITEM_GROUP_CODE .. FROM ST_ITEM , ST_UNIT , ST_ITEM_UNIT , ST_ITEM_CONFG , ST_STORE_ITEM WHERE .. ST_STORE_ITEM.STORE_CODE = :b1 AND ST_ITEM.STOP_FLAG = 0 AND NVL(BASIC_UNIT,0) = 1 ..`, followed by GET_UNIT_COST_CONFG / GET_BALANCE_CONFG in the same trigger; the trigger text of the same button in ST_TAKING_fmb.xml | medium-high (the fmx gives the query and the called functions, the assignments are taken from the ST_TAKING source) |
| B2 | "إنزال تكلفة أصناف الجرد" (CALC_COST): UNIT_COST := GET_UNIT_COST_CONFG(store, group, item, lot, date, NULL, NULL), UNIT_PRICE := cost × factor | action **CALC_COST** (`tk_calc_cost(.., 'ST_TAKING2')`) | label + identifiers CALC_COST / GET_UNIT_COST_CONFG; ST_TAKING source | medium-high |
| B3 | Status display: adjustment documents (EFFECT 1/2, TRNS_TYPE 7) of the store and date with ST_TRNS_MAST.SERIAL_TAKING_TEMP = the count serial → "لم يتم تسوية الجرد" / "تم عمل تسوية جرد حركة وارد رقم r/s حركة صادر i/s" | `info` STATUS (`tk_status(.., 'ST_TAKING2')`) | fmx SQL `SELECT COUNT (1) FROM ST_TRNS_MAST .. SERIAL_TAKING_TEMP = :b3` and the two MIN(TRNS_TYPE_CODE), MIN(TRNS_SERIAL) queries; texts "لم يتم تسوية الجرد", "تم عمل تسوية جرد حركة وارد رقم", "حركة صادر" | high |
| B4 | "اجمالى الكمية" (sum of QUANTITY) | `info` TOTAL_QTY | label | high |

## Confidence: **medium** (table correction well evidenced; tables empty so the workflow is not confirmed by data)

## Human verification

1. Confirm that "اعادة تقييم تكلفة المخزون" must use the TEMP tables (and that ST_AUTO_ADJ2 will be migrated as its process —
   without it the status display B3 can never show an adjustment).
2. What did "الفرق" / "إجمالى الفرق" compute on this revaluation screen (quantity difference × cost, or cost difference × quantity)?
3. The ST_STOCK_TAKING_TEMP APPX trigger (SERIAL numbering) is produced by the next build.py run from this override.

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Per line: item name, lot expiry, book balance "الرصيد الدفترى" = GET_BALANCE(store, group, item, count date) / factor | `computed.ST_STOCK_TAKING_TEMP_DET.*` | labels; formula of ST_TAKING.fmb (same template) - medium |
| Lot list of the line's item (lot id - lot number - expiry), refreshed when the item changes | `ITEM_CONFG_ID` `lov` + `cascade: ITEM_CODE` | legacy lot LOV (ITEM_CONFG_LOV / CONFG); the row rule still checks the lot and its balance |

Still not reproduced: book cost and "الفرق" / "إجمالى الفرق" (formula not in the compiled form, question 2). Tested with a fake row
(the TEMP tables are empty): balance 425, expiry and name returned.

## Coverage

Reproduced: rules 1-7 (wave 2) and B1-B4. Tests: wave 2 H1-H2 (page 20481); wave 3 `tmp\w3_sales\f5\t_f5.py` checks U1-U7 (decompose:
line count, quantity = book balance, cost, taking numbers, message; second decompose refused; CALC_COST; total; status with and
without adjustment), plain and simulated APEX session, all rolled back.

Deliberately not reproduced:
- Book cost ("تكلفة الدفترية"), DIFF ("الفرق") and their totals TOT_DIFF / TOT_DIFF_ST ("إجمالى الفرق"): the formulas are not in the
  compiled form (question 2). BAL_QTY per line: reproduced in wave 3b.
- "بيـانات الجرد" / "أرصدة المخزن" (PUSH_BUTTON55 / 56): no trigger in the compiled form (dead buttons).
- "من ملف" (READ_FROM_FILE): only a GN_FORM_ITEM label; the compiled ST_TAKING2.fmx has no such item or load code.
- Colour / size handling (ST_BASIC.COLOR_FLAG = SIZE_FLAG = 0), Forms-only mechanics (alerts, language switch, printing, SET_IP).
- Deleting a count now removes its lines in the generated page before the header (the wave-2 after-save delete is kept, harmless).
