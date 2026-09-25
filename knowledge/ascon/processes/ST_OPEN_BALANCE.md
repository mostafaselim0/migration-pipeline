# ST_OPEN_BALANCE — opening balance entry (ادخال رصيد الافتتاحى)

System 3 serial 110. Source: **.fmb** (`ST\FMB\ST_OPEN_BALANCE_fmb.xml`, full triggers in `_pipeline\catalog.json`).
Deliverable: **(a) AUTO + rules** (`overrides\ST_OPEN_BALANCE.json`, `APP_RULES_ST`).

## Purpose and data

Receipt of the opening stock per store and lot. Header ST_TRNS_MAST (+ SUPPLIER_CODE used for the lot), lines ST_TRNS_DET
with lot parameters (LOT_NUMBER, expiry, unit price = lot sale price, DISC1_RATIO) from which the lot is found or created.

Types: block WHERE `TRNS_TYPE_CODE IN (SELECT .. WHERE T.EFFECT = 1 AND T.TRNS_TYPE IN (8)) AND DELETE_FLAG=0 AND
(:GLOBAL.PASSWORD_NUMBER=0 OR ..ST_TRNSTYPE_PASSWORD..)` → 88888 (حكومة, 7 documents) and 99999 (مستودع قسم المستودعات,
38 documents), all dated 31/12/2024.

## Rules implemented

| # | Rule | Where | Evidence (.fmb) |
|---|------|-------|-----------------|
| 1 | List / type filter EFFECT 1 / TRNS_TYPE 8 + group | `rules.where`, `val_trns` | block WHERE, TRNS_TYPE LOV |
| 2 | Defaults: type (88888), store = ST_TRNS_TYPE.STORE_CODE (active), flags 0, DESC_A = type description | `rules.defaults`, `mast_row` | TRNS_TYPE_CODE WHEN-VALIDATE-ITEM (`:desc_A := :trns_type_desc`) |
| 3 | TRNS_SERIAL MAX + 1 per type (generic key); DATE_SERIAL by ST_TRNS_MAST_IN; **DOC_NO := TRNS_SERIAL when empty** | APPX key, `mast_row` → `next_doc_no` | ST_TRNS_MAST PRE-INSERT |
| 4 | CHECK_DATE + AC_BASIC open period; store active / allowed | `val_trns` | TRNS_DATE WHEN-VALIDATE-ITEM `CHECK_DATE(:TRNS_DATE)` |
| 5 | Posted documents read-only; delete of posted refused | triggers, `val_trns` | KEY-DELREC pattern |
| 6 | Line: group / basic unit / BASIC_QTY = QUANTITY × factor; **quantity ≥ 0** | `det_row` | QUANTITY WHEN-VALIDATE-ITEM (`IF :QUANTITY < 0 .. 'القيمة يجب أن تكون أكبر من الصفر'`), UNIT_CODE WHEN-VALIDATE-ITEM |
| 7 | Lot: found or created with GET_CONFG_ID(item, group, supplier = header SUPPLIER_CODE or ST_ITEM.SUPPLIER, UNIT_PRICE, LOT_NUMBER, EXPIRY_DATE (when the group has EXPIRE_FLAG), DISC1_RATIO, store, create = TRUE); wave 3: lot number **and expiry date** required for expiry groups (PRE-INSERT; no lookup by the lot number alone) — "يجب إدخال محددات الشحنات" | `det_row` | PRE-INSERT → program unit GET_THE_CONFIG → DB function GET_CONFG_ID |
| 8 | Unit price default = lot price; unit cost typed, else the lot average / ST_ITEM.UNIT_COST, else required | `det_row` | data: all 553 lines UNIT_PRICE = lot price; the UNIT_COST fallback to UNIT_PRICE is commented out in the .fmb |
| 9 | COST_FLAG 0 | `det_row` | data (all opening lines COST_FLAG 0) |
| 10 | **No opening balance before a posted transaction of the item in the store** | `det_row` (insert) | ST_TRNS_DET PRE-INSERT → CHECK_NEXT_POSTED_TRANS "الصنف .. له حركة مرحلة بتاريخ لاحق" |
| 11 | Deleting / reducing a line must not make a later transaction negative | `det_row`, `APP_RULES_ST_DET_BD` | ST_TRNS_DET KEY-DELREC (UPDATE_NEXT_TRNS_CONFG) |
| 12 | Lines required at SAVE; delete = **soft delete** (wave 3, W1) | `after_trns`, `rules.soft_delete` | KEY-DELREC (details checked and cleared, master DELETE_FLAG := 1) |

Lines cannot be updated (the .fmb detail block has UPDATE_ALLOWED = false; the generated grid keeps insert/delete only).

## Wave 3: expiry date, lot lines, Excel load, soft delete, totals (APP_ACT_ST `obl_*`, APP_RULES_ST)

The legacy LOT_NUMBER (Char 200) and EXPIRE_DATE items of the detail block are **non-database items** (catalog: database_item =
false); they only feed GET_THE_CONFIG. The data never stores ST_TRNS_DET.LOT_NUMBER / EXPIRY_DATE (0 of 11,563 lines).

| # | Legacy behaviour | APEX | Evidence | Confidence |
|---|---|---|---|---|
| W1 | Master KEY-DELREC: every line runs the detail KEY-DELREC check (removing the opening stock must not make a later movement of the lot negative: GET_BALANCE_CONFG + UPDATE_NEXT_TRNS_CONFG → "الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها."), the lines are cleared (CLEAR_RECORD, not deleted), then `:ST_TRNS_MAST.DELETE_FLAG := 1` and commit | `rules.soft_delete` (lines keep, check `obl_delete_check`: posted, then the running balance of every lot without this document) | KEY-DELREC of both blocks (.fmb); data: deleted 88888/1, 99999/32 | high |
| W2 | EXPIRE_DATE of a new lot (ENABLE_DISABLE_CONFIG pre-fills ADD_MONTHS(SYSDATE, 12) for expiry groups; "يجب ادخال التاريخ"); PRE-INSERT: IF :LOT_NUMBER IS NULL OR :EXPIRE_DATE IS NULL .. → "يجب إدخال محددات الشحنات" | `add_columns` ST_TRNS_DET.EXPIRY_DATE on the grid; `det_row`: expiry required for expiry groups | .fmb triggers | high |
| W3 | Lot numbers are text (e.g. 5HO131D); the grid column ST_TRNS_DET.LOT_NUMBER is NUMBER | action **LOT_LINE** "إضافة صنف بمحددات الشحنة" (item, unit, quantity, lot number, expiry, production date, sales price, discount ratio, unit cost) → `obl_add_line`: the legacy line checks (lot parameters, quantity ≥ 0, posted later transaction), lot by GET_CONFG_ID, line with DISC1_VALUE = ratio × price / 100, COST_FLAG 0 | GET_THE_CONFIG, PRE-INSERT, QUANTITY / DISC1 WHEN-VALIDATE-ITEM | high (the grid remains usable for numeric lot numbers and existing lots) |
| W4 | Button LOAD_EXCEL (LOAD_EXCEL_FILE, template `ASCON\ST\old\Opening_balance.xlsx`): from row 2 until the first empty item code; columns 1 group (empty = MIN group of the item), 2 item, 3 unit, 4 quantity, 5 lot no, 6 expiry (DD/MM/YYYY), 7 sales price, 8 cost price, 9 manufacturing date, 10 discount ratio; per row the checks " GROUP NOT EXIST-", " ITEM EXIST-" (SINGLE_ITEM), " SALES PRICE IS NULL-", " DISC RATIO IS NULL-", " COST PRICE IS NULL-", " QUANTITY IS NULL-", " EXPIRE DATE IS NULL-", " LOT NO IS NULL-", " UNIT NOT EXIST-", " Item Code NOT EXIST UNDER Item Group-", CHECK_NEXT_POSTED_TRANS; errors to <file>.TXT (" ITEM CODE= .. GROUP CODE= .. <errors>"); valid rows inserted: ITEM_SERIAL max + 1, UNIT_COST = cost price (not divided by the factor), UNIT_PRICE = sales price, COST_FLAG 0, lot = GET_THE_CONFIG, PRODUCTION_DATE = manufacturing date; "تم تحميل ملف الأكسل" | action **LOAD_EXCEL** (file parameter) → `obl_load_excel` (same checks and texts, errors listed in the message; rows also pass the line rules) | .fmb LOAD_EXCEL_FILE (evidence l.2700-2981), `Opening_balance.xlsx` and its `Opening_balance.TXT` error file | high |
| W5 | SUM_QTY "اجمالى" (Σ QUANTITY), TOTAL_VALUE_RYAL "اجمالى التكلفة" (Σ LINE_TOTAL_RYAL = UNIT_COST × QUANTITY) | `info` QTY / COST → `obl_totals` | .fmb summary items | high |

## Tests (page 20051, rolled back; `tmp\w3_sales\f4\t_f4.py`)

Wave 2: E1 DOC_NO = TRNS_SERIAL; E2 opening line refused when the item has a later posted transaction; E3 line on an existing lot: lot
price, cost = lot average, BASIC_QTY; E3b typed cost kept. Wave 3: D1 (APEX) grid line without expiry refused, lot created from lot number
+ expiry and reused; D2 totals; D3 delete refused when the opening stock was issued afterwards; D4 soft delete (lines kept, DELETE_FLAG 1),
posted refused; D5 Excel (.xlsx, dates as text and as date cells): 2 rows loaded, stop at the first empty row, lot created with supplier /
price / discount, cost = cost price, production date, the legacy error texts for 4 rejected rows; D6 load refused on a posted document;
D7 action LOT_LINE with a text lot number: lot created and reused, line values.

## Confidence: **high** for the rules above (full trigger text), **medium** for the unit-cost default.

## Human verification

1. The current legacy Excel code requires column 10 (discount ratio); the template `Opening_balance.xlsx` has 9 columns — confirm the
   template (a missing ratio is reported " DISC RATIO IS NULL-", as the legacy did).
2. Is opening balance entry still needed after go-live (all existing documents are dated 31/12/2024)?

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Expiry date of a new line pre-filled with today + 12 months | `columns.ST_TRNS_DET.EXPIRY_DATE.default` (EXPRESSION) | ENABLE_DISABLE_CONFIG `:EXPIRE_DATE := nvl(:EXPIRE_DATE, ADD_MONTHS(SYSDATE, 12))` (expiry groups; ST_BASIC.EXPIRE_FLAG = 1) |
| Per line: item name, "الإجمالي ( الريال )" = unit cost x quantity | `computed.ST_TRNS_DET.ITEM_NAME / LINE_TOTAL_RYAL` | display items; QUANTITY WHEN-VALIDATE `:LINE_TOTAL_RYAL := :UNIT_COST * :QUANTITY` |

The default applies to every new line (the page cannot know the item's group before the line is typed); the line rule still requires
the expiry only for expiry groups. Not added: SALE_ITEM_PRICE (`Visible = false`). The lot id is a hidden column here (lots are found
or created from lot number + expiry), so no lot list. Tested: the default expression and the computed expressions run on the build copy.

## Coverage

Reproduced: rules 1-12 and W1-W5 (numbering, lot creation from lot number + expiry, next posted transaction check, soft delete with
the balance check, Excel load, totals).

Not reproduced, on purpose:
- PUR_COST "سعر الشراء" → ST_ITEM.UNIT_COST (POST-INSERT / POST-UPDATE): **dead code** — the item is invisible (Visible = false in the
  .fmb), filled only by POST-QUERY with ST_ITEM.UNIT_COST itself, never set for new lines, and the detail block does not allow updates.
- (wave 3b: reproduced) the pre-filled expiry date (today + 12 months) of new lines.
- Colour / size lot parameters (ST_BASIC.COLOR_FLAG = SIZE_FLAG = 0), PEICE_NO lookup, WEBUTIL client file dialog (file parameter),
  window / prompt code, printing.
