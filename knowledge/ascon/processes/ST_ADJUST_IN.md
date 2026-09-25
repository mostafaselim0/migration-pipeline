# ST_ADJUST_IN — stocktaking adjustment, receipt (حركة تسوية جرد وارد)

System 3 serial 113 (TAKINK_ADJ_IN_MENU.TAKINK_ADJ_IN). Source: **.fmb** (`ST\FMB\ST_adjust_IN_fmb.xml`, triggers in
`_pipeline\catalog.json`). Deliverable: **(a) AUTO + rules** (`overrides\ST_ADJUST_IN.json`, `APP_RULES_ST`).

## Purpose and data

Manual stock increase of a store (found quantities, lot changes "تغيير باتشات", bonus goods). Header ST_TRNS_MAST (store,
counter account ACCOUNT_NUMBER1), lines ST_TRNS_DET with lot parameters.

Types: block WHERE `TRNS_TYPE_CODE IN (SELECT .. WHERE (T.EFFECT = 1) AND (T.TRNS_TYPE = 7)) AND DELETE_FLAG=0 AND
(:GLOBAL.PASSWORD_NUMBER = 0 OR ..)`; LOV adds `NVL(AUTO_TRNS,0) = 0`. Data: 11401 (14), 12401 (10), 13401 (5), 11601 (4,
mostly from ST_AUTO_ADJ), 904/905/906 (AUTO_TRNS = 1, one each); 12501 / 13501 / 9999999 unused.

## Rules implemented

| # | Rule | Where | Evidence (.fmb) |
|---|------|-------|-----------------|
| 1 | List filter EFFECT 1 / TRNS_TYPE 7 + group; new documents only with manual types (AUTO_TRNS = 0) | `rules.where`, `val_trns` (`type_in_screen(..., p_new => 1)`) | block WHERE, TRNS_TYPE record group |
| 2 | Defaults: type 11401, store = type store, flags 0, DESC_A = type description, **ACCOUNT_NUMBER1 = ST_STORE.ACCOUNT_NUMBER1** when the type posts to the document account | `rules.defaults`, `mast_row` | TRNS_TYPE_CODE WHEN-VALIDATE-ITEM |
| 3 | Account required when STACLNK has ACCOUNT_NO_TYPE = 6 for the type (11401/12401/13401) and no store default; must exist and be active in AC_MASTER | `val_trns` | SHOW_HIDE_ACC (account shown only for ACCOUNT_NO_TYPE 6), ACCOUNT_RG (ACCOUNT_STATUS = 1) |
| 4 | TRNS_SERIAL MAX + 1 per type; DATE_SERIAL ST_TRNS_MAST_IN; **DOC_NO = GET_NEXT_DOC_NO**: MAX(DOC_NO) + 1 per type and store (not deleted), first document = SUBSTR(store,1,2) ‖ SUBSTR(store,4,2) ‖ '000001' | APPX key, `next_doc_no` | PRE-INSERT, program unit GET_NEXT_DOC_NO; data 1001000001… |
| 5 | CHECK_DATE + AC_BASIC open period; store active / allowed | `val_trns` | TRNS_DATE WHEN-VALIDATE-ITEM |
| 6 | Posted → read-only (header, lines, delete) | `val_trns`, triggers | CLOSE_POSTED, KEY-DELREC "لا يمكن حذف حركات مرحلة" |
| 7 | Lines: group from the item (NVL(STOP_FLAG,0)=0 else "صنف غير موجود" / "صنف مكرر"), basic unit, BASIC_QTY, quantity > 0 | `det_row` | ITEM_CODE / UNIT_CODE WHEN-VALIDATE-ITEM |
| 8 | Lot: chosen lot must belong to the item; empty → lot with the same LOT_NUMBER, else created with GET_CONFG_ID (supplier = ST_ITEM.SUPPLIER, UNIT_PRICE, LOT_NUMBER, EXPIRY_DATE when EXPIRE_FLAG, DISC1_RATIO) | `det_row` | PRE-INSERT: "يجب إدخال محددات الشحنات" + GET_THE_CONFIG |
| 9 | UNIT_PRICE default = lot price; UNIT_COST default = lot average cost at the position, else ST_ITEM.UNIT_COST, else UNIT_PRICE / factor; COST_FLAG 0 | `det_row` | ITEM_CONFG_ID WHEN-VALIDATE-ITEM (GET_BALANCE_COST_CONFG → :unit_cost), UNIT_CODE WHEN-VALIDATE-ITEM (`:UNIT_COST := :UNIT_PRICE / factor`); data |
| 10 | SINGLE_ITEM / TRNS_MAX_ITEMS | `det_row` | WHEN-NEW-ITEM-INSTANCE |
| 11 | Deleting / reducing a receipt line must not make a later transaction negative | `det_row`, `APP_RULES_ST_DET_BD` | detail KEY-DELREC (GET_BALANCE_CONFG + UPDATE_NEXT_TRNS_CONFG, "الرصيد لا يسمح، توجد حركة تالية ...") |
| 12 | Lines required at SAVE; document delete = **soft delete** (wave 3, W1) | `after_trns`, `rules.soft_delete` | PRE-INSERT / POST-DELETE "لا يمكن حفظ الحركة بدون تفاصيل", KEY-DELREC |
| 13 | Type / store cannot change once lines exist | `val_trns` | safety (lines carry the store; PK) |

Lines are insert/delete only (detail block UPDATE_ALLOWED = false in the .fmb).

## Wave 3: expiry date, lot lines, soft delete, question, total (APP_ACT_ST `adi_*`, APP_RULES_ST)

The legacy LOT_NUMBER (Char 200), EXPIRE_DATE and PRODUCTION_DATE items of the detail block are **non-database items** (catalog:
database_item = false; data: no 11401/12401/13401 line stores them); ITEM_CONFG_ID WHEN-VALIDATE-ITEM fills them from the chosen lot
(PRODUCTION_DATE = ADD_MONTHS(expiry, -36)), GET_THE_CONFIG uses them for a new lot.

| # | Legacy behaviour | APEX | Evidence | Confidence |
|---|---|---|---|---|
| W1 | Master KEY-DELREC: posted → "لا يمكن حذف حركات مرحلة"; every line runs the detail KEY-DELREC check (GET_BALANCE_CONFG + UPDATE_NEXT_TRNS_CONFG → "الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها.", NEG_SALE_BALANCE test commented out), lines cleared, `:ST_TRNS_MAST.DELETE_FLAG := 1`, commit | `rules.soft_delete` (lines keep, check `adi_delete_check`) | .fmb KEY-DELREC (evidence l.394-448, l.1234-1360); data: 8 deleted 11401 / 11601 / 12401 / 13401 documents kept their 10 lines with DELETE_FLAG 1 | high |
| W2 | EXPIRE_DATE of a new lot; EXPIRE_DATE WHEN-VALIDATE-ITEM: `IF :TRNS_DATE >= :EXPIRE_DATE` → "تاريخ الصلاحية يجب أن يكون أكبر من تاريخ الحركة"; production date < expiry and < transaction date | `add_columns` ST_TRNS_DET.EXPIRY_DATE; `det_row` (expiry after the transaction date for a new lot); action LOT_LINE (all three checks) | .fmb l.1608-1630 | high |
| W3 | PRE-INSERT: `IF :LOT_NUMBER IS NULL OR :EXPIRE_DATE IS NULL OR :PRODUCTION_DATE IS NULL OR :UNIT_CODE IS NULL OR :DISC1_RATIO IS NULL` → "يجب إدخال محددات الشحنات"; lots are text (the grid column ST_TRNS_DET.LOT_NUMBER is NUMBER) | action **LOT_LINE** "إضافة صنف بمحددات الشحنة" → `adi_add_line` (lot parameters required, lot by GET_CONFG_ID with ST_ITEM.SUPPLIER, unit cost = lot average / ST_ITEM.UNIT_COST / price ÷ factor, COST_FLAG 0) | .fmb PRE-INSERT, GET_THE_CONFIG | high |
| W4 | DOC_NO WHEN-VALIDATE-ITEM: another document of the type with the same DOC_NO → alert DOC_REPEAT (continue or stop) | `warnings` → `adi_doc_warn` (with ST_BASIC.DOC_REPEAT = 0 the page validation refuses instead) | .fmb l.757-777 | medium (alert text not in the evidence; "رقم المستند مكرر" used) |
| W5 | SUM_LINE_TOTAL "الاجمالى" = Σ NVL(QUANTITY,0) × (NVL(UNIT_PRICE,0) − NVL(DISC1_VALUE,0)) | `info` TOTAL → `adi_total` | .fmb item formula | high |

## Tests (page 20081, rolled back; `tmp\w3_sales\f4\t_f4.py`)

Wave 2: B1 DOC_NO next per store; B2 existing lot: lot price, average cost, COST_FLAG 0; B3 lot found by LOT_NUMBER; B4 new lot
without expiry refused; B5 new lot created by GET_CONFG_ID; B7 delete of a receipt line with a later issue refused; B8 reducing
it refused; B9 increasing accepted. Wave 3: E1 (APEX) grid new lot with an expiry not after the date refused, created otherwise; E2 total;
E3 duplicate DOC_NO question; E4 soft delete (lines kept), posted refused; E5 action LOT_LINE: lot parameters required, expiry /
production date checks, lot created, unit cost.

## Confidence: **high** (full trigger text; data matches DOC_NO, prices, cost flag)

## Human verification

1. (done in wave 3b, lots of the line's item) ITEM_CONFG_ID was a plain number field; suggested LOV:
   `select item_confg_id r, lot_number || ' - ' || to_char(expire_date,'DD/MM/YYYY') d from st_item_confg`.
2. The DOC_REPEAT alert of this form ignored ST_BASIC.DOC_REPEAT; the page only asks when DOC_REPEAT = 1 (with 0 it refuses) — confirm.

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Per line: item name, lot expiry "تاريخ صلاحية الشحنة" (next to the typed expiry of a new lot), "رصيد المخزن قبل الحركة" = lot balance before the line / factor, "تكلفة الصنف" = lot average cost x factor, "الاجمالى" = qty x (price - disc 1) | `computed.ST_TRNS_DET.*` | .fmb detail POST-QUERY (`GET_BALANCE_COST_CONFG(... :ITEM_SERIAL)`, `STORE_COST := V_AVG_COST * NDB_FACTOR`), LINE_TOTAL formula |
| Lot list of the line's item (lot id - lot number - expiry), refreshed when the item changes | `ITEM_CONFG_ID` `lov` + `cascade: ITEM_CODE` | legacy lot LOV (ITEM_CONFG_LOV / CONFG); the row rule still checks the lot and its balance |
| Button "ترحيل السند" opens the posting screen ST_POSTING_CPOSTING with the document's type, serial and date filled in (from / to) | `links` | POST_BUT: `CALL_FORM(... 'ST_POSTING_CPOSTING' ...)` with TRN_CODE / TRN_SER / TRN_DATE |

Costs are empty unless (USERS.ALLOW_VIEW_COST = 1 and ST_BASIC.SHOW_COST = 1) or the user's group is 0 (legacy GET_USER_SEC); the column itself stays visible (the generator cannot hide a column per user right). (STORE_COST is hidden with VAR.SHOW_COST = 0 in the .fmb.) The legacy button chose post (FILTER 1) or cancel (FILTER 2) from POST_FLAG; the link cannot set a value that depends on the record, so the operation stays the posting page's default (post) and the user switches it to cancel when needed. Tested on the build copy: every list query and computed expression runs (`tmp\w3b_st\sqlcheck.py`, lot list with item 101010006); the cost / balance gates checked in an APEX session (`t_gates.py`, rolled back, session removed).

## Coverage

Reproduced: rules 1-13 and W1-W5 (numbering, account, lots and new lots, cost, balance of later movements, soft delete, duplicate DOC_NO
question, total).

Not reproduced, on purpose:
- ENTRY_PRINT / ITEM197 printing (prints agent), alerts, WEBUTIL, SET_IP, HILIGHT, button procedures, supplier id / name per line.
  Wave 3b added the per-line displays and POST_BUT (link to ST_POSTING_CPOSTING).
- ST_TRNS_PIECE_DET / ST_ITEM_PIECES handling in KEY-DELREC ("هذا الصنف مباع"): tables unused (0 rows).
- POST-INSERT ST_STORE_ITEM insert: done by ST_TRNS_DET_C_IN / GET_CONFG_ID.
- `:GLOBAL.CUSTOMER_CODE = 'SDI'` branches (yearly DOC_NO, GET_UNIT_RG): the installation code is NULL (CUSTOMER_PAR empty).
- No Excel load and no PUR_COST item exist in this form.
