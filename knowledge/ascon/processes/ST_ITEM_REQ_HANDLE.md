# ST_ITEM_REQ_HANDLE: material request processing (معالجة طلبات النواقص), registry 30/31

**Deliverable:** screen rules (pattern AUTO), `app\legacy\overrides\ST_ITEM_REQ_HANDLE.json` — same tables and same save rules as
ST_ITEM_REQ (package `APP_RULES_SA` `req_*`, identical row-rule strings so the generated trigger contains them once), list limited to
requests with at least one unconverted line (legacy "open requests" list FILL_REQ_LIST); actions **TO_TRANSFER_REQ** and
**TO_PURCHASE_REQ** (package `APP_CONV`, `app\db\22_conv.sql`: `can_req_to_transfer`, `req_to_transfer`, `can_req_to_purchase`,
`req_to_purchase`, `first_target_type`); wave 3: outstanding-PO warning, delete rule and displays in `APP_ACT_ST` (`rq_*`).
**Confidence:** medium for the save rules and the conversions (compiled .fmx only; never used here: tables empty, no request / purchase
request types, so the conversions were tested with temporary types).

## Which screen had the buttons
Only the handle screen: the INSERT statements into ST_TRNS_MAST_REQUEST / PR_ORDER_REQUEST (program units REQUEST_TRANSFER and
REQUEST_ORDER) are in `ST_ITEM_REQ_HANDLE.fmx`; `ST_ITEM_REQ.fmx` has the button labels in GN_FORM_ITEM but no conversion SQL.
Legacy flow: button TRANS_GRAND_STORE ("عمل طلب تحويل") or PUSH_BUTTON281 ("عمل طلب شراء") → window with the target type
(CTRL.TAR_TRNS_TYPE_CODE, list REQ_TRNS_TYPE_RG) and the date (TRNS_DATE2) → OK → REQUEST_TRANSFER / REQUEST_ORDER, then COMMIT and
FILL_REQ_LIST.

## Action TO_TRANSFER_REQ ("عمل طلب تحويل") — REQUEST_TRANSFER
| # | Rule | Evidence |
|---|---|---|
| T1 | Target type required: EFFECT 7 / TRNS_TYPE 9 with a store, the store = the supplying store (ST_ITEM_REQ.FROM_STORE_CODE) unless ST_BASIC.RLTD_TRNS_STR_FLAG = 0 (0 here), group rights (ST_TRNSTYPE_PASSWORD) — parameter list of values, default = first such type | REQ_TRNS_TYPE_RG, "لابد من إدخال رقم حركة التحويل" |
| T2 | Supplying store required | button trigger: "لابد من إدخال رقم المستودع الذي سيتم التحويل منه أولا" |
| T3 | Date required, not before the request date, CHECK_DATE (not future, ≥ ST_BASIC.MIN_DATE) | TRNS_DATE2 WHEN-VALIDATE-ITEM: "يجب ان يكون تاريخ التحويل اكبر من تاريخ الطلب"; "يجب ادخال التاريخ" |
| T4 | Lines: the chosen lines (legacy check box CHOOSE, not stored — parameter LINES = item codes or line serials, empty = all) that are not converted yet (PR_FLAG = 0 and no ST_TRNS_DET_REQUEST / PR_ORDER_DET_REQUEST line points to them) | REQUEST_TRANSFER symbols :CHOOSE, :REQ_TRNS_TYPE_CODE, :PRUCHASE_TRNS_TYPE_CODE |
| T5 | Project-estimate approval: with ST_BASIC.EST_FLAG = 1 a chosen line with NEED_APPROVE = 1 is refused (EST_FLAG = 0 here: inactive) | symbols :NEED_APPROVE, :PARAMETER.EST_FLAG; "لا يمكن ترحيل طلبات غير معتمدة" |
| T6 | Header ST_TRNS_MAST_REQUEST: TRNS_SERIAL max + 1 per type, DATE_SERIAL max + 1 per date, STORE_CODE = supplying store, TRNSFER_TO_STORE = requesting store, CURRENCY 1 / rate 1, POST_FLAG / DELETE_FLAG 0, INVOICE_NO = request type ‖ LPAD(serial, 3, '0'), DESC_A ' حركة طلب تحويل آلي من طلبية نواقص رقم t/s  ' ‖ request DESC_A (DESC_E ' Automated Trns. Req. From Material Req. No.…'); TO_TRANSFER_FLAG 0 (new: the transfer-request screen default) | .fmx INSERT |
| T7 | Descriptions longer than the column (100) refused | "لقد تجاوزت الحد الاقصى لطول الوصف" |
| T8 | Lines ST_TRNS_DET_REQUEST: ITEM_SERIAL = request line serial, QUANTITY, BASIC_QTY, UNIT_COST / UNIT_PRICE empty, COST_FLAG 0, unit, group, item, colour, size, REQ_TRNS_TYPE_CODE / SERIAL / ITEM_SERIAL = request line; PR_FLAG = 2 on the request lines | .fmx INSERT, :PR_FLAG |
| T9 | Confirmation "تم عمل طلب تحويل لعدد N صنف" (`app_conv.last_message`); opens the new transfer request | .fmx text |

## Action TO_PURCHASE_REQ ("عمل طلب شراء") — REQUEST_ORDER
| # | Rule | Evidence |
|---|---|---|
| P1 | Target type required: EFFECT 7 / TRNS_TYPE 13 with a store, the store = the requesting store unless RLTD_TRNS_STR_FLAG = 0, group rights | REQ_TRNS_TYPE_RG, "لابد من إدخال رقم حركة طلب الشراء" |
| P2 | Date, lines, approval: as T3-T5 | |
| P3 | Header PR_ORDER_REQUEST: TRNS_SERIAL max + 1 per type, STORE_CODE = requesting store, DOC_NO / FROM_STORE_CODE / INSERT_USER / UPDATE_USER / DELETE_USER copied from the request, REQ_DATE = the date, DESC_A 'طلب شراء آلى من طلب نواقص رقم' ‖ t/s ‖ request DESC_A | .fmx INSERT, REQUEST_ORDER symbols |
| P4 | DATE_SERIAL = max + 1 per store and date **in PR_ORDER_REQUEST** (the purchase-request screen rule); the legacy handle screen read ST_TRNS_MAST_REQUEST here (copy / paste defect, the value only orders documents of a day) | .fmx SQL |
| P5 | Lines PR_ORDER_DET_REQUEST: ITEM_SERIAL = request line serial, QUANTITY, BASIC_QTY, REQ_DATE / DATE_SERIAL of the header, item, group, unit, colour, size, REQ_* links; SUPP_CODE = ST_ITEM.SUPPLIER (new, the purchase-request screen's line default — "عمل أمر شراء" needs it); PR_FLAG = 1 on the request lines | .fmx INSERT |
| P6 | Confirmation "تم عمل طلب شراء لعدد N صنف"; opens the new purchase request | .fmx text |

Both actions refuse when nothing is left ("لا توجد أصناف مختارة لم يتم تحويلها", new text: the legacy then only reported 0 items).
The APP_RULES_SA row rules stand aside while the documents are written, so the request lines can be flagged (PR_FLAG) although the
save rules lock converted lines.

## Tests (ROLLBACK, temporary types 90012 request / 90013 purchase request, `t_conv.py`, outside and inside a simulated APEX session)
Can-flags, default target types, no type, wrong kind of type, date before the request, no supplying store, description too long,
transfer request of the lines chosen by item code (header, lines, links, PR_FLAG 2, message), purchase request of the remaining line
(header copies, supplier, date serial, PR_FLAG 1), nothing left — 18 checks.

## Wave 3: warning, delete rule and displays (APP_ACT_ST `rq_*`, shared with ST_ITEM_REQ)

| # | Legacy (ST_ITEM_REQ_HANDLE.fmx) | APEX | Evidence | Confidence |
|---|---|---|---|---|
| W1 | Line PRE-INSERT → CHK_OUTSTANDING_QTY (without colour / size in this form): ordered minus received quantity of the item / unit > 0 → "هناك كمية N من الصنف X لم يتم إستلامها هل تريد الاستمرار" | `warnings` on SAVE (`rq_warn_outstanding(.., 'ST_ITEM_REQ_HANDLE')`), legacy query as is (binds = the request's own TRNS_TYPE_CODE / TRNS_SERIAL, so it never matches a real purchase order) | fmx SQL `SELECT NVL(SUM (QUANTITY) , 0 ) FROM PR_ORDER_DET WHERE TRNS_TYPE_CODE = :b1 AND TRNS_SERIAL = :b2 AND GROUP_CODE = :b3 AND ITEM_CODE = :b4 AND UNIT_CODE = :b5` and the PR_INCOME_LOT query; caller symbols (detail PRE-INSERT) | high (query), dead in the legacy |
| W2 | Header KEY-DELREC: links in PR_ORDER_DET_REQUEST / ST_TRNS_DET_REQUEST → "طلب النواقص الحالي له طلب شراء او عروض أسعار مرتبطة و لا يمكن الحذف" | after-save on DELETE (`rq_delete_check`) | fmx SQL (both COUNT queries), message | high |
| W3 | ITEM_COUNT "عدد الأصناف", PROJ_REF "المسمى المرجعى للمشروع" | `info` ITEM_COUNT / PROJ_REF | labels, fmx SQL `SELECT PROJ_REF FROM ST_PROJ_EST_MAST WHERE STORE_CODE = :b1` | high |

Tests: `tmp\w3_sales\f5\t_f5.py` checks R7-R13 (warning on this screen's variant fires with a purchase-order line carrying the
request keys; delete refused after a conversion; page delete rolled back in the APEX run), plain and simulated APEX session.

## Open questions
Approval gate before conversion (legacy only checks the project-estimate NEED_APPROVE, inactive)? Which quantity is converted
(QUANTITY, the approved quantity — as legacy)? Choosing lines by item code instead of the legacy check box — acceptable?
Wave 3: the handling screen's "تزويد عام" (QUAN_BUTTON with the BAL_CHECK "التشيك على الرصيد فى المخزن المحول منه" box) and
"أصناف حد الطلب" set the proposed QUANTITY from values computed in compiled p-code (no MIN_LIMIT is read here, unlike ST_ITEM_REQ):
which quantity did they propose (limit − requesting-store balance? limited by the supplying-store balance when BAL_CHECK is ticked)?

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Per line: item name, "رصيد مخزن الطلب" (requesting store), "رصيد المخزن المحول منه" (supplying store), current GET_BALANCE / factor, only with USERS.ALLOW_VIEW_BALANCE | `computed.ST_ITEM_REQ_DET.*` | display items TO_STORE_BAL / FROM_STORE_BAL, labels - medium |

Still not reproduced: UNIT_COST / ITEM_UNIT_COST (gated by ALLOW_VIEW_COST and SEE_PRICE; formula not readable), the linked documents
per line, the store-balance window; the warning sees only saved lines (not supported by the generator).

## Coverage

Reproduced: the save rules of ST_ITEM_REQ (wave 2), the actions TO_TRANSFER_REQ / TO_PURCHASE_REQ (T1-T9, P1-P6), and W1-W3 (wave 3).

Deliberately not reproduced:
- "تزويد عام" / "أصناف حد الطلب" of this screen (AUTO_FILL / QUAN_BUTTON with BAL_CHECK, REC_LIMIT): the queries are known (items
  below QUAN_LIMIT in the requesting store; items below ST_STORE_ITEM.REORDER_LIMIT) but the proposed quantity is computed in compiled
  p-code that cannot be read (question above). The same requests can be filled on ST_ITEM_REQ (actions GENERAL_REQ / REC_LIMIT, which
  write the requested and the approved quantity). MIN_LIMIT / REORDER_LIMIT are 0 for every item in this database.
- The open-requests list (SHOW.REQ_LIST / FILL_REQ_LIST): the list page is filtered to requests with an unconverted line.
- Per-line displays UNIT_COST / ITEM_UNIT_COST (gated by USERS.ALLOW_VIEW_COST and SEE_PRICE; formula not readable) and the linked
  transfer / purchase request per line, and the "عرض أرصدة المخازن" window with "عودة مع إنزال المخزن" (pick the supplying store from
  the balance list): no drill-down window in the generator; the supplying store is chosen with its list of values. FROM_STORE_BAL /
  TO_STORE_BAL are computed columns since wave 3b.
- Forms-only mechanics (alerts, windows, printing, SET_IP), colour / size (flags 0).
- The warning sees only lines saved before (generator limitation, see ST_ITEM_REQ.md).
