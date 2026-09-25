# ST_ITEM_REQ: branch material requests (طلبيات النواقص), registry 30/30

**Deliverable:** screen rules (pattern AUTO), `app\legacy\overrides\ST_ITEM_REQ.json`, package `APP_RULES_SA`
(`req_mast_row`, `req_det_row`, `req_validate`, `req_after_save`; shared with ST_ITEM_REQ_HANDLE); wave 3: fill actions, warnings,
delete rule and displays in `APP_ACT_ST` (`rq_*`, `app\db\23_act_st.sql`).
**Confidence:** medium (compiled .fmx strings only; never used: tables empty, no request types `EFFECT 7 / TRNS_TYPE 12` exist).

## Rules implemented
| # | Rule | Where | Evidence (ST_ITEM_REQ.md) |
|---|---|---|---|
| F1 | List: request types (7/12 with a store) and group type rights (no FLAG condition, as legacy) | `where` | type record group |
| N1 | TRNS_SERIAL / ITEM_SERIAL max + 1 (APPX, identical); DATE_SERIAL max + 1 per (store, request date) | row rule | pre-insert SQL |
| D1 | Requesting store = store of the type; APPROVE_FLAG / CLOSE_FLAG 0; request date today | row rule / defaults | type WVI SQL |
| V1 | Offline-branch store (ST_STORE.COMM_FLAG = 1) refused; supplying store ≠ requesting store, active and allowed; date not future / ≥ MIN_DATE | row rule, `req_validate` | R1-R3 |
| L1 | Line: header date / date serial copied; QUANTITY (approved) defaults to REQ_QTY and vice versa; BASIC_QTY = QUANTITY × factor; basic unit; item active; qty > 0; expected price > 0 when given | row rule | R5, R6, BASIC_QTY SQL |
| L2 | Once a request is converted (a line with PR_FLAG > 0, or links in PR_ORDER_DET_REQUEST / ST_TRNS_DET_REQUEST): no new lines ("لا يمكن انشاء سجل جديد بسبب ارتباط السجل الرئيسى بمرحلة تالية"), converted lines locked | row rule | R10 |
| A1 | Items required (from the first save); line count ≤ TRNS_MAX_ITEMS; no repeated item when ST_BASIC.SINGLE_ITEM = 1 | `req_after_save` | R4, R7, R8 |

## Conversion buttons
"عمل طلب تحويل" / "عمل طلب شراء" (and "عمل أمر شراء" labels) appear in GN_FORM_ITEM for this form, but the conversion SQL is only in
ST_ITEM_REQ_HANDLE.fmx: the actions are on that screen (TO_TRANSFER_REQ / TO_PURCHASE_REQ, see ST_ITEM_REQ_HANDLE.md). Converted lines
get PR_FLAG 2 (transfer request) / 1 (purchase request) and are then locked here (rule L2).

## Wave 3: buttons, warnings, delete rule and displays (APP_ACT_ST `rq_*`)

| # | Legacy (ST_ITEM_REQ.fmx) | APEX | Evidence | Confidence |
|---|---|---|---|---|
| W1 | "تزويد عام" (GENERAL_REQ / AUTO_FILL → window QUAN_LIMIT, button QUAN_BUTTON): limit "أدخل الحد الأدنى للكمية الذي سيتم الطلب إذا انخفض رصيد الصنف عنه" (> 0, "الكمية يجب أن تكون أكبر من الصفر"), optional group / item ranges; items (basic unit, item and group not stopped) whose GET_BALANCE in the requesting store is below the limit, by item code; requested quantity = `SELECT NVL(MIN_LIMIT,0) QTY FROM ST_STORE_ITEM` (requesting store); lines REQ_QTY, QUANTITY, BASIC_QTY | action **GENERAL_REQ** (`rq_fill_general`): parameters QUAN_LIMIT, FROM/TO group (LOV), FROM/TO item (LOV); lines appended with ITEM_SERIAL max + 1, request date / date serial; items whose quantity is 0 are **skipped** and counted in the message (a 0 line cannot be saved: "الكمية يجب أن تكون أكبر من الصفر") | fmx SQL `.. AND GET_BALANCE(:b5 , IT.ITEM_GROUP_CODE , IT.ITEM_CODE ) < NVL(:b6 , 0 ) .. ORDER BY IT.ITEM_CODE` + `SELECT NVL(MIN_LIMIT , 0 ) QTY FROM ST_STORE_ITEM WHERE STORE_CODE = :b1 ..` in the same trigger, symbols :ST_ITEM_REQ.STORE_CODE, REQ_QTY, BASIC_QTY, ndb_factor | medium-low: the assignment of the quantity is compiled p-code (QTY = MIN_LIMIT is the only quantity the trigger reads) |
| W2 | "أصناف حد الطلب" (REC_LIMIT): items of the requesting store (ST_STORE_ITEM) whose balance is below REORDER_LIMIT, quantity = NVL(MIN_LIMIT, 0) | action **REC_LIMIT** (`rq_fill_reorder`), same ranges, zero quantities skipped | fmx SQL `.. NVL(SGS.MIN_LIMIT , 0 ) QTY FROM .. ST_STORE_ITEM SGS WHERE .. NVL(GET_BALANCE(:b1 ..) , 0 ) < NVL(SGS.REORDER_LIMIT , 0 ) ..` | medium |
| W3 | Line PRE-INSERT → CHK_OUTSTANDING_QTY: ordered quantity (PR_ORDER_DET) minus received (PR_INCOME_LOT_DET of the orders) of the item / unit / colour / size > 0 → "هناك كمية N من الصنف X لم يتم إستلامها هل تريد الاستمرار" | `warnings` on SAVE (`rq_warn_outstanding(.., 'ST_ITEM_REQ')`), over the saved lines, legacy query as is: the binds are the **request's own** TRNS_TYPE_CODE / TRNS_SERIAL and COLOR_CODE / SIZE_CODE are compared with "=" (NULL here) — it can never fire on this data (as in the legacy) | CHK_OUTSTANDING_QTY symbols `:ST_ITEM_REQ.TRNS_TYPE_CODE`, `:ST_ITEM_REQ.TRNS_SERIAL`, parameters P_GROUP_CODE … P_SIZE_CODE; its two SQL statements; caller = detail PRE-INSERT | high (query), the check is dead in the legacy |
| W4 | CHECK_EST (ST_BASIC.EST_FLAG = 1): requested quantity of the store above the latest project estimate (ST_PROJ_EST_DET) → "هناك أصناف تعدت الكمية المحددة فى تقدير المشروع هل تريد الاستمرار" | `warnings` on SAVE (`rq_warn_estimate`), gated by EST_FLAG (0 here: inactive); colour / size compared with "=" as the legacy | fmx SQL (ST_PROJ_EST_DET MAX(TRNS_SERIAL), SUM of ST_ITEM_REQ_DET of the store), `SELECT COUNT (1) FROM ST_BASIC WHERE EST_FLAG = 1` | medium |
| W5 | Header KEY-DELREC: a request with links in PR_ORDER_DET_REQUEST or ST_TRNS_DET_REQUEST → "طلب النواقص الحالي له طلب شراء او عروض أسعار مرتبطة و لا يمكن الحذف"; otherwise the lines are deleted with the header | after-save on DELETE (`rq_delete_check`, page items TRNS_TYPE_CODE / TRNS_SERIAL; raising rolls the page delete back); the generated page deletes the lines first | fmx SQL `SELECT COUNT (1) FROM PR_ORDER_DET_REQUEST D WHERE REQ_TRNS_TYPE_CODE = :b1 ..`, `DELETE FROM ST_ITEM_REQ_DET ..`, message | high |
| W6 | ITEM_COUNT "عدد الأصناف", PROJ_REF "المسمى المرجعى للمشروع" (latest ST_PROJ_EST_MAST of the requesting store) | `info` ITEM_COUNT / PROJ_REF | labels, fmx SQL `SELECT PROJ_REF FROM ST_PROJ_EST_MAST WHERE STORE_CODE = :b1 AND TRNS_SERIAL IN (SELECT MAX (TRNS_SERIAL) ..)` | high |

Action regions are shown while the request can take new lines (`rq_can_fill`: not converted, the legacy "لا يمكن انشاء سجل جديد
بسبب ارتباط السجل الرئيسى بمرحلة تالية"). ST_STORE_ITEM.MIN_LIMIT and REORDER_LIMIT are 0 for every item in this database, so W1 / W2
add nothing today.

## Open questions
Needed at all? Which request types per store? Who approves (APPROVE_FLAG, USERS.MR_APPROVE)? BASIC_QTY on requested or approved qty?
Wave 3: (1) "تزويد عام": is the requested quantity the store minimum limit (MIN_LIMIT, as read by the legacy trigger) or "limit −
balance"? (2) The outstanding-PO warning compares the purchase orders of the request's own type / serial (a copy defect: it never
fires); should it rather use the orders linked to the item (PR_ORDER_DET.REQ_TRNS_*)? (3) Items with a zero requested quantity:
skipped (APEX) or added for the user to type the quantity (legacy, unsaved lines)?

## Tests (ROLLBACK, temporary type 90012)
`t_misc.py` (request part): 9 checks. Wave 3: `tmp\w3_sales\f5\t_f5.py` checks R1-R13 (temporary type 91050; fills with ranges,
zero quantity skipped, reorder items, serials / dates, info, both warnings incl. the EST_FLAG gate, delete accepted / refused after a
conversion by APP_CONV, fills refused once converted, page delete rolled back in the APEX run), plain and simulated APEX session.

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Per line: item name, "رصيد مخزن الطلب" (balance in the requesting store), "رصيد المخزن المحول منه" (balance in the supplying store), current GET_BALANCE / factor, only with USERS.ALLOW_VIEW_BALANCE | `computed.ST_ITEM_REQ_DET.*` | display items CURR_BAL / FROM_STORE_BAL, labels, GET_BALANCE in the fill queries - medium (current balance; the legacy formula is not readable) |

Still not reproduced: FROM_REQ_BAL (total transfer requests of the item), the linked documents per line, the "عرض أرصدة المخازن"
window; the warnings still see only saved lines (the generator's warnings run before the page submit, unsaved grid rows are not in
the database - not supported).

## Coverage

Reproduced: F1, N1, D1, V1, L1, L2, A1 (wave 2); W1-W6 (wave 3).

Deliberately not reproduced:
- "تزويد سريع" (SPEEDY_REQ, window DATE_LIMIT with a date range), "عمل أمر شراء" (GEN_PUR_ORDER / TRANSFER / PUSH_BUTTON268), "عمل
  طلب عرض أسعار" (PR_QUOT): GN_FORM_ITEM labels only — the compiled ST_ITEM_REQ.fmx has no such items or code (older layout). The
  conversions of this workflow are on ST_ITEM_REQ_HANDLE (APP_CONV).
- Per-line displays TO_STORE_BAL ("رصيد المخزن المحول إليه"), FROM_REQ_BAL ("إجمالي طلبات التحويل للصنف"), the linked documents per
  line (TRANSFER_NO, PR_ORDER_NO, REQ_ID …) and the "عرض أرصدة المخازن" window (balance and sales per store of the current item): the
  formulas are not readable from the compiled form, and the generator has no drill-down window. CURR_BAL / FROM_STORE_BAL are computed
  columns since wave 3b (ALLOW_VIEW_BALANCE).
- "الإجمالى" (EX_PRICE_TOTAL): formula not in the compiled form.
- Colour / size / model handling (ST_BASIC.COLOR_FLAG = SIZE_FLAG = 0), Forms-only mechanics (alerts, windows, printing, SET_IP).
- The warnings see only lines saved before (a warning runs before the page submit, the new grid rows are not in the database yet),
  while the legacy checked each new line in its PRE-INSERT (generator limitation; no effect here since W3 cannot fire and W4 is off).
