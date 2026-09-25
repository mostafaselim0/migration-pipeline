# ST_TRANSFER_FROM — issue transfer between stores (شاشة تحويل الأصناف)

System 3 serial 101 (FILES_MENU.ST_TRANSFER_FROM). Source: compiled form only (`ST\FMB\st_trAnsfer_FROM.fmx`,
evidence `app\legacy\evidence\ST_TRANSFER_FROM.md`), no .fmb. Deliverable: **(a) screen kept (`"pattern": "AUTO"`) + rules**
(`app\legacy\overrides\ST_TRANSFER_FROM.json`, package `APP_RULES_ST` in `app\db\21_rules_st.sql`).

## Purpose and data

Issues items from a store to another store. Header `ST_TRNS_MAST` (STORE_CODE = source store, TRNSFER_TO_STORE =
destination), lines `ST_TRNS_DET` (lot = ITEM_CONFG_ID). Every document owns a row of `ST_TRNSFER`
(TRNSFER_SERIAL, TRNSFER_FROM_STORE) — `ST_TRNS_MAST` has the FK `TRNS_MAST_ST_TRNSFER_FK` on these two columns — that the
receive screen (ST_TRANSFER_TO) closes by stamping TRNSFER_RECEIVING_DATE.

Transaction types (block WHERE in the .fmx, confirmed with the data):
`TRNS_TYPE_CODE IN (SELECT .. FROM ST_TRNS_TYPE T WHERE T.EFFECT = 5 AND T.TRNS_TYPE IN (9)) AND DELETE_FLAG = 0
AND (:1=0 OR TRNS_TYPE_CODE IN (SELECT .. FROM ST_TRNSTYPE_PASSWORD WHERE PASSWORD_NUMBER=:2))`.
Types 11101 / 11102 / 11103 (تحويل صادر per department). Data: 11101 = 30 documents, 11102 = 2, 11103 = 0; no other type
has TRNSFER_* filled except the receipts 11201.

## Rules implemented

| # | Rule | Where | Evidence |
|---|------|-------|----------|
| 1 | List shows only EFFECT 5 / TRNS_TYPE 9 types, DELETE_FLAG = 0, and types granted to the user's group (`:G_PASSWORD_NUMBER = 0` or ST_TRNSTYPE_PASSWORD) | `rules.where` | block WHERE string in the .fmx |
| 2 | New document type must be an issue-transfer type granted with ST_TRNSTYPE_PASSWORD.FLAG = 1 (TRNS_TYPE LOV) | validation `val_trns` | LOV record group `... WHERE EFFECT = 5 AND TRNS_TYPE = 9 AND (.. TP.FLAG=1 ..)` |
| 3 | Defaults: type = first allowed type (11101), store = ST_TRNS_TYPE.STORE_CODE of that type when the store is active, DELETE_FLAG 0, POST_FLAG 0; DESC_A = type description when empty (trigger) | `rules.defaults`, `mast_row` | `SELECT STORE_CODE FROM ST_TRNS_TYPE WHERE TRNS_TYPE_CODE = :b1 AND STORE_CODE IN (active stores)` |
| 4 | TRNS_SERIAL = MAX + 1 per type | generic APPX key (unchanged) | `SELECT NVL(MAX(TRNS_SERIAL),0)+1 FROM ST_TRNS_MAST WHERE TRNS_TYPE_CODE = :b1` |
| 5 | DATE_SERIAL from the existing DB trigger ST_TRNS_MAST_IN (sequence) — item hidden / optional | `rules.hidden/optional` | trigger source |
| 6 | DOC_NO default = type code ‖ 5-digit sequence per type and store (1110100013 …), user may overwrite | `mast_row` → `next_doc_no` | `SELECT NVL(MAX(SUBSTR(DOC_NO, :b1+1, LENGTH(DOC_NO))),0)+1 FROM ST_TRNS_MAST WHERE TRNS_TYPE_CODE=:b2 AND STORE_CODE=:b3`; data 1110100001..1110100012 |
| 7 | ST_TRNSFER row: TRNSFER_SERIAL = MAX + 1 per source store; inserted with date, from/to store, DELETE_FLAG 0, POST_FLAG 0, APPROVE_FLAG 1, DOC_NO, descriptions; TRNSFER_FROM_STORE := STORE_CODE, TRNSFER_TYPE := 0 on the document; TRNSFER_SERIAL read-only on the page | `mast_row` (insert) | `SELECT NVL(MAX(TRNSFER_SERIAL),0)+1 FROM ST_TRNSFER WHERE TRNSFER_FROM_STORE = :b1`, `INSERT INTO ST_TRNSFER (... 0, 0, 1, ...)`; data TRNSFER_TYPE 0 on issues |
| 8 | Header changes are copied to ST_TRNSFER (destination, date, doc no, description) | `mast_row` (update) | `UPDATE ST_TRNSFER SET TRNSFER_TO_STORE = :b1 WHERE ...` |
| 9 | Destination store required, active, and different from the source store | `val_trns` | STORE_LOV / TO_STORE_LOV exclude each other (`STORE_CODE <> :ST_TRNS_MAST.TRNSFER_TO_STORE`) |
| 10 | Source store: active and allowed for the group (ST_STORE_PASSWORD) | `val_trns` | STORE_LOV |
| 11 | CHECK_DATE: no future date, not before ST_BASIC.MIN_DATE; plus the AC_BASIC open period of the DB trigger CLOSE_ST_TRNS_MAST (Arabic message first) | `val_trns` | TRANSLATE.pll CHECK_DATE; trigger CLOSE_ST_TRNS_MAST |
| 12 | Posted document (POST_FLAG = 1) read-only; POST_FLAG / AC_ENTRY_* read-only on the page | `val_trns`, `det_row`, `det_delete`, `mast_delete`, `rules.readonly` | CLOSE_POSTED pattern, message "لا يمكن حذف حركات مرحلة" |
| 13 | Once received (ST_TRNSFER.TRNSFER_RECEIVING_DATE or a receipt document exists) the transfer cannot be changed or deleted | `val_trns`, `det_row`, `det_delete`, `mast_delete` | .fmx: status queries on ST_TRNSFER.TRNSFER_RECEIVING_DATE / receipts ("تم إستلام التحويل ..."), "لا يمكن تغيير رقم طلب التحويل ويوجد تفاصيل" |
| 14 | Type / source store cannot change once lines exist (the ST_TRNSFER key depends on the store) | `val_trns` | safety rule (legacy: TRNSFER key built at insert) |
| 15 | Lines: group derived from the item (item must exist and not be stopped), unit = basic unit when empty, BASIC_QTY = QUANTITY × factor, quantity > 0 | `det_row` | ITEM_CODE / UNIT_CODE WHEN-VALIDATE-ITEM SQL in the .fmx |
| 16 | Lot: chosen lot must belong to the item; empty → first lot with enough balance (earliest expiry, lowest id) | `det_row` → `fefo_lot` | `SELECT MIN(ITEM_CONFG_ID) FROM ST_ITEM_CONFG WHERE .. GET_BALANCE_CONFG(..) >= :qty`; CONFG LOV shows lots with balance > 0 |
| 17 | Lot balance: the issued quantity must be available at the document position and no later transaction may become negative (unless ST_BASIC.NEG_SALE_BALANCE = 1) | `det_row` → `check_balance`, `after_trns` (SAVE re-check) | messages "رصيــد الصنف فى هذا التاريخ لا يسمــح", "أقصى كمية يمكن إخراجها للصنف", UPDATE_NEXT_TRNS_CONFG |
| 18 | UNIT_COST = average cost of the lot at the position (GET_UNIT_COST_CONFG), UNIT_PRICE = lot price (ST_ITEM_CONFG.UNIT_PRICE) when empty, COST_FLAG 1 | `det_row` | data: 333/333 lines UNIT_PRICE = lot price, UNIT_COST = cost table |
| 19 | SINGLE_ITEM / TRNS_MAX_ITEMS of ST_BASIC | `det_row` (insert) | "غير مسموح بتكرار الصنف", "لقد تم إدخال .. صنف" |
| 20 | Document cannot be saved without lines (checked at SAVE; the grid only appears after CREATE) | `after_trns` | "لا يمكن حفظ الحركة بدون تفاصيل" |
| 21 | Delete (wave 3: **soft delete**, see W1): ST_TRNSFER.DELETE_FLAG = 1; the transfer request it was issued from (REQ_TRNS_*) is open again (TO_TRANSFER_FLAG = 0). A physical delete outside the page still goes through `APP_RULES_ST_MAST_BD` → `mast_delete` | `rules.soft_delete` + `trf_after_delete` | `UPDATE ST_TRNSFER SET DELETE_FLAG = 1 WHERE ...`, `UPDATE ST_TRNS_MAST_REQUEST SET TO_TRANSFER_FLAG = 0 ..` |
| 22 | DOC_NO duplicate refused only when ST_BASIC.DOC_REPEAT = 0 (current value 1: legacy only asked "هل تريد الإستمرار") | `val_doc_no` | `SELECT NVL(DOC_REPEAT,0) FROM ST_BASIC`, messages |

Not duplicated: cost / balance records (ST_TRNS_DET_C_IN/_UP/_DL), ST_STORE_ITEM insert (C_IN), ALT_KEY, TAX triggers,
DATE_SERIAL (ST_TRNS_MAST_IN), propagation of dates / transfer stores to the lines (ST_TRNS_MAST_UP).

## Wave 3: legacy buttons, questions, displays and delete (APP_ACT_ST, `trf_*`)

Installation code: `:GLOBAL.CUSTOMER_CODE` comes from `SELECT CUSTOMER_CODE FROM CUSTOMER_PAR` (Sysmenu.fmx); CUSTOMER_PAR is empty in
production (`_discovery\05_tables_rows.csv`), so the code is NULL: the `= 'SDI'` branch of TO_STORE_LOV does not apply.

| # | Legacy behaviour | APEX | Evidence | Confidence |
|---|---|---|---|---|
| W1 | Master KEY-DELREC is a **soft delete**: the lines are checked and cleared, `:ST_TRNS_MAST.DELETE_FLAG := 1`, commit (the lines follow through ST_TRNS_MAST_UP). Posted → "لا يمكن حذف حركات مرحلة"; a received transfer cannot be deleted | `rules.soft_delete` (lines keep, check `trf_delete_check`) | P7 trigger symbols `:PARAMETER.MASTER_DELETE`, `:ST_TRNS_MAST.DELETE_FLAG`, TRNSFER / REQ items; data: the 6 deleted 11101 documents kept their 17 lines with DELETE_FLAG 1, DELETE_USER empty | high |
| W2 | After the delete: `UPDATE ST_TRNSFER SET DELETE_FLAG = 1 ..`, `UPDATE ST_TRNS_MAST_REQUEST SET TO_TRANSFER_FLAG = 0 ..` | `after_save` DELETE → `trf_after_delete` | same trigger SQL; data: ST_TRNSFER 1-3 of store 101010101001 DELETE_FLAG 1 | high |
| W3 | DOC_NO WHEN-VALIDATE-ITEM: DOC_REPEAT = 0 → "لا يمكن تكرار المستند"; DOC_REPEAT = 1 (this database) → "رقم المستند مكرر" + "هل تريد الإستمرار" (count over TM.STORE_CODE = TT.STORE_CODE, EFFECT 5 / TYPE 9, not deleted) | `warnings` → `trf_doc_warn` (question); refusal stays `val_doc_no` | .fmx SQL `SELECT NVL(DOC_REPEAT,0) ..`, `SELECT COUNT(1) FROM ST_TRNS_MAST TM, ST_TRNS_TYPE TT ..`, texts | high |
| W4 | Receipt status display: "تم إستلام التحويل مطابق / تم إستلام التحويل وتوجد أصناف غير مطابقة" + "بتاريخ" + "برقم حركة" + "برقم مستند", or "التحويل لم يستلم" (DEF_QUANTITY = Σ issue − Σ receipt BASIC_QTY) | `info` STATUS → `trf_status` | .fmx texts and SQL `SELECT SUM(DECODE(T.EFFECT, 5, BASIC_QTY, 6, -BASIC_QTY)) DEF_QUANTITY ..`, receipt query | high |
| W5 | Displays ITEM_COUNT "عدد الاصناف", TOTAL_COST "إجمالى بالتكلفة" (only with ST_BASIC.SHOW_COST and USERS.ALLOW_VIEW_COST), TOTAL_PRICE "إجمالى بسعر البيع", window "الكميات الاجمالية" (Σ BASIC_QTY / FACTOR per unit) | `info` ITEMS / TCOST / TPRICE / UNITS → `trf_totals` | labels; SQL `SELECT ST_ITEM_UNIT.UNIT_CODE, SUM(BASIC_QTY / FACTOR) QTY ..`; `SELECT NVL(SHOW_COST,0) ..`, `ALLOW_VIEW_COST` | medium (total formulas: Σ BASIC_QTY × UNIT_COST, Σ QUANTITY × UNIT_PRICE) |
| W6 | **Automatic receipt**: after saving, with ST_BASIC.AUTO_TRANSFER = 1 and ST_TRNS_TYPE.REC_TRANSFER_TRNS (11201 for 11101-11103) the form asked "هل تريد استلام التحويل تلقائي" and inserted the receipt: TRNS_SERIAL max + 1, **DOC_NO 1110100001 (a literal)**, TRNS_DATE = issue date, DESC_A 'حركة استلام تحويل اتوماتيك بموجب سند تحويل يدوي رقم ' ‖ TRNSFER_SERIAL, currency 1 / rate 1, cost fields 0, STORE_CODE = TRNSFER_TO_STORE = destination, TRNSFER_TYPE 1, TRNSFER_FROM_STORE = source, flags 0; lines = the issue lines (ITEM_SERIAL, QUANTITY, UNIT_COST, UNIT_PRICE, BASIC_QTY, lot, unit, COST_FLAG 1, destination store); ST_TRNSFER.TRNSFER_RECEIVING_DATE stamped | action **AUTO_REC** "استلام التحويل تلقائي" (confirm = the legacy question, shown while the transfer is not received and not deleted) → `trf_auto_receive`, opens the receipt on ST_TRANSFER_TO | .fmx INSERT statements (evidence l.185), alert text / "Do you want to Receive Transfer Automatically ?"; data: 24 automatic receipts 11201 with exactly this shape (DOC_NO 1110100001, date = issue date, lines = issue lines 195/195 serials; UNIT_PRICE = issue price since 2026-01, earlier = cost) | high |
| W7 | Excel import (button "تحميل EXCEL", LOAD_EXCEL_FILE, template `ASCON\ST\old\TRANSFER.xlsx`): from row 2 until the first empty item code, columns Item Code, Unit Code, Qty, Ascon Confg, Lot No., Expire Date; lot = the given lot (" Item Confg NOT EXIST-"), else MAX(ITEM_CONFG_ID) by lot number + expiry, else MIN(ITEM_CONFG_ID) with GET_BALANCE_CONFG(store, .., date, NULL, NULL) ≥ quantity; rejected rows written to C:\ITEMS_LOAD_ERROR.TXT | action **LOAD_EXCEL** (file parameter, .xlsx / .csv) → `trf_load_excel`: every row inserted through the normal line rules (lot, balance, cost, price); rejected rows listed in the message (" ITEM CODE= .. GROUP CODE= .. <error>") | .fmx LOAD_EXCEL_FILE symbols (V_ITEM_CODE, V_UNIT_CODE, V_QTY, V_ITEM_CONFG_ID, V_LOT_NO, V_EXPIRE_DATE), its SQL and texts; the template file | medium-high (column order from the template) |
| W8 | Transfer issued from a request: TRNS_DATE ≥ request date ("لا يمكن ان يكون تاريخ التحويل اصغر من تاريخ طلب التحويل"); REQ_TRNS_* not changeable ("لا يمكن تغيير رقم طلب التحويل ويوجد تفاصيل") | `val_trns` (date); REQ_TRNS_TYPE_CODE / REQ_TRNS_SERIAL read-only (`add_columns` shows the serial) — the link is written by action TO_ISSUE of ST_TRANSFER_REQUEST | .fmx texts, `SELECT TRNS_DATE FROM ST_TRNS_MAST_REQUEST ..` | high |
| W9 | TO_STORE_LOV: `(:GLOBAL.PASSWORD_NUMBER = 0 OR :GLOBAL.CUSTOMER_CODE = 'SDI' OR STORE_CODE IN ST_STORE_PASSWORD)` → the destination store must be granted to the group | `val_store` also for the destination (APP_RULES_ST) | .fmx LOV SQL | high |
| W10 | The page hooks only judge documents of the screen's types (the automatic receipt 11201 written from this page is not treated as an issue) | `APP_RULES_ST.screen_type` in mast_row / det_row / mast_delete / det_delete | — | — |

## Tests (build copy, all rolled back; `tmp\w3_sales\f4\t_f4.py`, plain 82 checks, simulated APEX session 96 checks)

A0-A2 issue created (ST_TRNSFER by the page hook), automatic receipt header / lines / cost rows / receiving date / message, no extra
ST_TRNSFER row; A3 second receipt refused, action hidden; A4/A5 status identical / not matching (also on the receipt); A6 received transfer
not deletable; A7 soft delete (lines kept and flagged, ST_TRNSFER.DELETE_FLAG 1) once the receipt is deleted; A8 posted refused; A9
request reopened; A9b date before the request; A9c destination store rights (APEX); A10 duplicate DOC_NO question (DOC_REPEAT 1 / 0, own
number); A11 totals and cost visibility per user; A12 Excel load CSV and XLSX (explicit lot, lot by number + expiry, FEFO lot, stop at the
first empty row, unknown item, lot of another item, stock shortage by the line rules in APEX); A13 load refused on a received / posted
transfer; R1 regression of the line derivations; wave-2 tests C1-C4, D6, D8 above.

## Confidence: **medium-high**

High for type filter, ST_TRNSFER handling, balance checks, soft delete and the automatic receipt (data shape reproduced). Medium for
the DOC_NO format (users overwrite it), the totals formulas and the Excel column order (taken from the legacy template).

## Human verification

1. The automatic receipt always wrote DOC_NO 1110100001 (a constant in the legacy INSERT; data confirms). Kept as is — should it take
   the transfer's DOC_NO instead?
2. DOC_NO default format (type code + 5 digits per store) — confirm with the store keepers.
3. (done in wave 3b) TRNSFER_TO_STORE has the list of leaf stores not stopped, filtered by the store permissions.
4. ST_TRNSTYPE_PASSWORD and ST_STORE_PASSWORD are empty: users whose group ≠ 0 see no transfer types / stores (same as legacy).

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Per line: item name, lot expiry, lot balance in the issuing store before the line "رصيد الشحنة", lot balance in the receiving store "رصيد المخزن المحول إلية", lot average cost "متوسط تكلفة الشحنة", "إجمالى بالتكلفة" (basic qty x unit cost), "إجمالى بسعر البيع" (qty x price) | `computed.ST_TRNS_DET.*` | display items and labels; GET_BALANCE_CONFG(store, group, item, lot, date, date serial, item serial) / factor as in the lot LOV |
| Destination store list (leaf stores not stopped, store permissions) | `columns.ST_TRNS_MAST.TRNSFER_TO_STORE.lov` | TO_STORE_LOV (question 3 below) |
| Lot list of the line's item (lot id - lot number - expiry), refreshed when the item changes | `ITEM_CONFG_ID` `lov` + `cascade: ITEM_CODE` | legacy lot LOV (ITEM_CONFG_LOV / CONFG); the row rule still checks the lot and its balance |
| Button "ترحيل السند" opens the posting screen ST_POSTING_CPOSTING with the document's type, serial and date filled in (from / to) | `links` | POST_BUT: `CALL_FORM(... 'ST_POSTING_CPOSTING' ...)` with TRN_CODE / TRN_SER / TRN_DATE |

Costs are empty unless (USERS.ALLOW_VIEW_COST = 1 and ST_BASIC.SHOW_COST = 1) or the user's group is 0 (legacy GET_USER_SEC); the column itself stays visible (the generator cannot hide a column per user right). The legacy button chose post (FILTER 1) or cancel (FILTER 2) from POST_FLAG; the link cannot set a value that depends on the record, so the operation stays the posting page's default (post) and the user switches it to cancel when needed. Tested on the build copy: every list query and computed expression runs (`tmp\w3b_st\sqlcheck.py`, lot list with item 101010006); the cost / balance gates checked in an APEX session (`t_gates.py`, rolled back, session removed).
Not reproduced: IDENTICAL_RECEIVING per line (a check box computed from the receipt; the document status W4 shows it), supplier id /
colour / size per line.

## Coverage

Reproduced: every business rule of the legacy screen listed above (rules 1-22, W1-W10): numbering, ST_TRNSFER row, lot and balance
checks, soft delete with its side effects, duplicate DOC_NO question, receipt status and totals, automatic receipt, Excel import,
request date check, store rights.

Not reproduced, on purpose:
- Forms-only mechanics: alerts as UI, button enabling / HILIGHT / SET_ITEM_PROMPT, navigation keys, WEBUTIL (replaced by the file
  parameter), SET_IP, IDENTICAL_RECEIVING per line (the document-level status W4 covers the receipt comparison). Wave 3b added the
  per-line displays and the posting button (link to ST_POSTING_CPOSTING).
- Printing (STOCK_ISSUANCE_FORM / PRINT_BTN reports): handled by the prints agent.
- Unit prices by store DEAL_TYPE (REDUCTION / WIDE / RETAIL): the data shows the lot price is what was stored.
- Excel rejected-row file C:\ITEMS_LOAD_ERROR.TXT: listed in the success message instead.
