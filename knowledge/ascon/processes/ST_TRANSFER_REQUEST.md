# ST_TRANSFER_REQUEST — transfer request (حركة طلب تحويلات)

System 3 serial 32 and system 30 serial 32 (menu FILES_MENU.PR_ORDER). Source: compiled form only
(`ST\FMB\ST_TRANSFER_REQUEST.fmx`, evidence `app\legacy\evidence\ST_TRANSFER_REQUEST.md`). Deliverable: **(a) AUTO + rules**
(`overrides\ST_TRANSFER_REQUEST.json`, `APP_RULES_ST`) + action **TO_ISSUE** (`APP_CONV`, see below).

## Purpose and data

A store asks another store for items. Header `ST_TRNS_MAST_REQUEST` (STORE_CODE = requesting/source store as in the legacy
LOVs, TRNSFER_TO_STORE = other store), lines `ST_TRNS_DET_REQUEST` (no lot). The request does not move stock (EFFECT 7). A transfer
issued from it (ST_TRNS_MAST.REQ_TRNS_TYPE_CODE / REQ_TRNS_SERIAL, TO_TRANSFER_FLAG = 1) locks it.

Types (block WHERE): `TRNS_TYPE_CODE IN (SELECT .. WHERE T.EFFECT = 7 AND TRNS_TYPE = 9) AND (:1 = 0 OR ..ST_TRNSTYPE_PASSWORD..)`
→ type 11501 (طلب تحويل بضاعة). No DELETE_FLAG condition in the legacy WHERE. Data: ST_TRNS_MAST_REQUEST is empty (feature
not used in this company so far).

## Rules implemented

| # | Rule | Where | Evidence |
|---|------|-------|----------|
| 1 | List filter EFFECT 7 / TRNS_TYPE 9 + group types | `rules.where` | block WHERE |
| 2 | New request type: EFFECT 7 / TYPE 9, ST_TRNSTYPE_PASSWORD.FLAG = 1 | `val_req` | TRNS_TYPE LOV |
| 3 | Defaults: type 11501, store = type store, DELETE_FLAG / POST_FLAG / TO_TRANSFER_FLAG 0 (hidden or read-only), DESC_A = type description | `rules.defaults`, `req_mast_row` | TRNS_TYPE_CODE WHEN-VALIDATE-ITEM SQL |
| 4 | TRNS_SERIAL = MAX + 1 per type (generic APPX key); **DATE_SERIAL = MAX + 1 per date in ST_TRNS_MAST_REQUEST** (no DB trigger on this table) | `key_expr` → `next_req_date_serial` | `SELECT NVL(MAX(DATE_SERIAL)+1,1) FROM ST_TRNS_MAST_REQUEST WHERE TRNS_DATE = :b1` |
| 5 | CHECK_DATE (no future date, ≥ ST_BASIC.MIN_DATE); no AC_BASIC period check (no CLOSE trigger on this table) | `val_req` | CHECK_DATE in the identifiers |
| 6 | Store and other store required, active, different (source store also allowed for the group) | `val_req` | STORE_LOV / TO_STORE_LOV (`STORE_CODE <> :TRNSFER_TO_STORE`) |
| 7 | Request locked (no change, no new/changed line) once a transfer was issued from it or TO_TRANSFER_FLAG = 1 | `val_req`, `req_det_row` | `SELECT TRNS_TYPE_CODE, TRNS_SERIAL FROM ST_TRNS_MAST WHERE REQ_TRNS_TYPE_CODE = :b1 AND REQ_TRNS_SERIAL = :b2 AND NVL(DELETE_FLAG,0)=0`; "تم عمل حركة التحويل", "تم إستلام التحويل و لا يمكن الحذف" |
| 8 | Type cannot change once lines exist | `val_req` | safety (PK column) |
| 9 | Lines: group from the item, basic unit default, BASIC_QTY = QUANTITY × factor, quantity > 0, COST_FLAG 0; ITEM_SERIAL = MAX + 1 (generic key) | `req_det_row` | "القيمة يجب أن تكون أكبر من صفر", `SELECT NVL(MAX(ITEM_SERIAL),0)+1 FROM ST_TRNS_DET_REQUEST ..` |
| 10 | Lines required at SAVE | `after_req` | "لا يمكن حفظ الحركة بدون تفاصيل" |
| 11 | DOC_NO duplicate refused only when ST_BASIC.DOC_REPEAT = 0 | `val_doc_no` | `.. ST_TRNS_MAST_REQUEST TM .. EFFECT = 7 AND TRNS_TYPE = 9 AND TM.DOC_NO = :b2 ..` |

## Action TO_ISSUE — issue transfer from the request (implemented, `APP_CONV.trq_to_transfer`, `app\db\22_conv.sql`)

Legacy: on the issue screen ST_TRANSFER_FROM the user picked the request in REQ_TRNS_TYPE_CODE / REQ_TRNS_SERIAL (list: requests with
TO_TRANSFER_FLAG = 0, request store = issue store, request date ≤ issue date); the form copied the request header (TRNS_DATE, DESC_A/E,
currency, COST_CODE, ACCOUNT_NUMBER1, STORE_CODE, TRNSFER_*) and the request lines (`SELECT * FROM ST_TRNS_DET_REQUEST .. ORDER BY
ITEM_SERIAL`: item, unit, quantity, basic quantity, cost, price), the lots came from the issue-line rules, and the save set
`UPDATE ST_TRNS_MAST_REQUEST SET TO_TRANSFER_FLAG = 1` (0 again when the transfer is deleted) — evidence `ST_TRANSFER_FROM.md`. APEX:
action region on the saved request (parameters issue type — EFFECT 5 / TRNS_TYPE 9 with ST_TRNSTYPE_PASSWORD.FLAG = 1, default the type
of the request's store — and date, default today); shown while the request is not deleted, not transferred and has lines; opens the new
transfer on ST_TRANSFER_FROM.

| # | Rule |
|---|---|
| I1 | Refused when TO_TRANSFER_FLAG = 1 or a live transfer has REQ_TRNS_* = the request ("تم عمل حركة التحويل لهذا الطلب"), or the request is deleted |
| I2 | Date: not before the request date, CHECK_DATE, inside the AC_BASIC open period (trigger CLOSE_ST_TRNS_MAST) |
| I3 | Source store = request STORE_CODE (active, allowed for the group), destination = request TRNSFER_TO_STORE (active, different) |
| I4 | Header ST_TRNS_MAST as the issue screen writes it: TRNS_SERIAL max + 1, DOC_NO = type ‖ 5-digit number per store (`app_rules_st.next_doc_no`), DESC_A/E, currency, COST_CODE, ACCOUNT_NUMBER1 (store account when the type posts with ACCOUNT_NO_TYPE 6) from the request, TRNSFER_TYPE 0, TRNSFER_FROM_STORE = store, REQ_TRNS_TYPE_CODE / SERIAL = request, a new ST_TRNSFER row (serial max + 1 per source store, APPROVE_FLAG 1); DATE_SERIAL from the legacy trigger |
| I5 | Lines in request order: lot = the earliest-expiry lot that alone covers the quantity (issue-screen rule `fefo_lot`), otherwise the quantity is split over the lots by expiry; the quantity a lot may give is its balance at the document position without making any later movement negative (`app_rules_st.run_balance`, legacy GET_BALANCE_CONFG + UPDATE_NEXT_TRNS_CONFG); not enough stock → "رصيد الصنف فى هذا التاريخ لا يسمح، الصنف = …، الرصيد المتاح = …" |
| I6 | Line values: BASIC_QTY = qty × factor, UNIT_COST = average cost of the lot at the position (GET_UNIT_COST_CONFG), UNIT_PRICE = request price or the lot price, COST_FLAG 1, transfer keys / stores of the header |
| I7 | Request TO_TRANSFER_FLAG = 1; message "تم عمل حركة التحويل رقم t/s" (`app_conv.last_message`) |
| I8 | Deleting the issued transfer on the issue screen sets the request's TO_TRANSFER_FLAG back to 0 (legacy `UPDATE ST_TRNS_MAST_REQUEST SET TO_TRANSFER_FLAG = 0` of ST_TRANSFER_FROM.fmx) — added to the delete hook `app_rules_st.mast_delete` / trigger APP_RULES_ST_MAST_BD (new parameters REQ_TRNS_TYPE_CODE / SERIAL) |

Not reproduced: the automatic receipt of ST_BASIC.AUTO_TRANSFER (see ST_TRANSFER_FROM.md).
Tests (`t_conv.py`, ROLLBACK, outside and inside a simulated APEX session): request created from a material request, can-flag, default
type, receive type refused, date before the request, stock shortage, issue created (header, ST_TRNSFER row, request link, doc no,
date serial), item split over three lots in expiry order, line costs / prices / keys, no negative lot, flag set, second issue refused,
delete of the issued transfer on page 20011 reopens the request (APEX run) — 13 checks.

## Wave 3: delete rule, question and balance display (APEX: DB delete hooks in APP_RULES_ST, APP_ACT_ST `trq_*`)

| # | Legacy behaviour | APEX | Evidence | Confidence |
|---|---|---|---|---|
| W1 | Master and detail KEY-DELREC: `IF :TO_TRANSFER_FLAG = 1` → "تم إستلام التحويل و لا يمكن الحذف" ("The current transfer request have already received"), else "هل تريد حذف السجل الحالى" and DELETE_RECORD — a **physical** delete (no DELETE_FLAG in the block WHERE, no MASTER_DELETE loop) | triggers `APP_RULES_ST_REQ_BD` (ST_TRNS_MAST_REQUEST) and `APP_RULES_ST_REQDET_BD` (ST_TRNS_DET_REQUEST, reads the header flag): APEX sessions only; the page deletes the lines first, then the header | .fmx: two anonymous triggers with symbols `"I":TO_TRANSFER_FLAG":GLOBAL.LANG"` followed by the texts and the del_alert question | high |
| W2 | DOC_NO: DOC_REPEAT = 1 → "رقم المستند مكرر" / "هل تريد الإستمرار" (ST_TRNS_MAST_REQUEST, EFFECT 7 / TYPE 9, not deleted) | `warnings` → `trq_doc_warn` | .fmx SQL and texts | high |
| W3 | STORE_BALANCE "رصيد المستودع" of each line: program unit GET_CONFIG_BALANCE sums GET_BALANCE_CONFG(request STORE_CODE, .., TRNS_DATE) over the lots of the item / factor; shown only with USERS.ALLOW_VIEW_BALANCE = 1 | `info` STORE_BAL → `trq_store_balance` ("item: balance \| ..." for the lines) | GET_CONFIG_BALANCE symbols, `SELECT NVL(ALLOW_VIEW_BALANCE,0) FROM USERS ..` | medium (one list instead of a column per line) |

## Tests (page 20341 and `tmp\w3_sales\f4\t_f4.py`, rolled back)

F1 same store refused / valid header / issue type refused; F2 DATE_SERIAL 1, flags 0, description; F3 save without lines
refused; F4 line derived (group, unit, basic qty, cost flag, item serial 1); F5 save accepted. Wave 3: C1 duplicate DOC_NO question
(own number not questioned); C2 store balance per line and hidden for a user without ALLOW_VIEW_BALANCE; C3 (APEX) delete of a line /
of the request refused once TO_TRANSFER_FLAG = 1, open request deleted (lines, then header).

## Confidence: **medium** (clear SQL, but the table is empty so no data confirmation of the workflow)

## Human verification

1. Is the transfer-request workflow used? The issue is now made from the request (action TO_ISSUE); should deleting the issued transfer
   reopen the request (legacy: TO_TRANSFER_FLAG = 0)? Lot choice (one covering lot, else split by expiry) — confirm.
2. Which store is the requester (STORE_CODE) and which one ships (TRNSFER_TO_STORE)? The legacy LOV labels are "مـن مخـــزن /
   إلى مخزن"; the rules only require them to differ. The balance display uses STORE_CODE (the store the issue is made from).

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Per line "رصيد المستودع" = Σ GET_BALANCE_CONFG(request store, lot, request date) over the item's lots / factor, only with USERS.ALLOW_VIEW_BALANCE (user 0 always); item name | `computed.ST_TRNS_DET_REQUEST.STORE_BALANCE / ITEM_NAME` | GET_CONFIG_BALANCE (W3), labels |
| The wave-3 workaround `info` STORE_BAL (one list for all lines) is replaced by the per-line column | `info` entry removed | - |
| Destination store list (leaf stores not stopped, store permissions) | `TRNSFER_TO_STORE.lov` | TO_STORE_LOV (W9 of ST_TRANSFER_FROM) |

The balance column stays visible but empty without the right (the generator cannot hide a column per user right). Tested: the
expressions run (fake row; the request tables are empty) and the gate in an APEX session (`t_gates.py`).

## Coverage

Reproduced: rules 1-11, action TO_ISSUE (I1-I8), W1-W3 (delete refused once transferred, duplicate DOC_NO question, store balance -
per line since wave 3b).
The destination store must be granted to the user's group (TO_STORE_LOV, `val_store`, wave 3).

Not reproduced, on purpose:
- Colour / size mandatory checks ("يجب ادخال اللون / المقاس"): ST_BASIC.COLOR_FLAG = SIZE_FLAG = 0 in this company.
- The stock-shortage alert texts in the .fmx ("رصيــد الصنف فى هذا التاريخ لا يسمــح", "إجمالي قيمة الرصيد ...") are template alerts
  with no evidence of use in the request form (a request does not move stock); the issue checks them (TO_ISSUE).
- Print buttons ("طباعة فاتورة الخزانات"): prints agent. Forms-only mechanics (alerts, navigation, enabling).
