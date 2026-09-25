# ST_RETURN_AUTH_COST2 — اعتماد مرتجعات المشتريات بدون فاتورة / Purchase Returns without Invoice, Approval (system 30, serial 47)

Deliverable: **screen correction (columns) + business rules + 2 buttons** — `overrides/ST_RETURN_AUTH_COST2.json`
(MASTER_DETAIL on the generated tables ST_TRNS_AUTH_MAST + ST_TRNS_AUTH_DET; top-level `columns` so that the expense fields
are editable — the generated page had made them read-only display items; `where`, labels, defaults, read-only / hidden /
optional items, row rules, validation, warning, after-save incl. DELETE, actions), `APP_RULES3_PR` (`auth_*`).
Pages 50250 / 50251. Confidence: **medium** (.fmx only; the AUTH tables are empty in the build copy).

## Purpose and tables
A purchase return without an original invoice is first recorded as an authorisation (`ST_TRNS_AUTH_MAST` / `_DET` /
`ST_TRNS_AUTH_SERVICES`), approved twice (first approval, management approval) and then **converted** ("ترحيل السند" /
"تحويل الفاتورة") into a real purchase return in `ST_TRNS_MAST` / `ST_TRNS_DET` / `ST_TRNS_SERVICES` of the same type,
linked by `AUTH_TRNS_TYPE_CODE` / `AUTH_TRNS_SERIAL`.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | List: purchase-return types (EFFECT 3, TRNS_TYPE 3 or 5), not deleted, type rights, returns without invoice (`RET_TRNS_TYPE_CODE IS NULL`) | `rules.where` | block WHERE | high |
| 2 | Defaults: first return type of the user and its store, flags 0 | `defaults` (APP_RULES_PR helpers) | WHEN-CREATE-RECORD | medium |
| 3 | Serial per type (generated key); date serial = max + 1 per date; store of the type; supplier currency and rate when left local; INVOICE_NO = type ‖ LPAD(serial, 7, 0) | row rule `auth_mast_row` | PRE-INSERT SQL | medium-high |
| 4 | Type from the list and the user's rights; store required "يجب ربط الحركة بالمخزن" and allowed; date (CHECK_DATE) and not in the closed period (`AC_BASIC.CLOSE_DATE`) | validation `auth_validate` | SQL; closed-period message is ours (legacy text not in the .fmx strings) | medium-high |
| 5 | Rate required "يجب ادخال معامل التحويل"; local currency rate 1 "معامل تحويل الريال يجب ان يكون ب 1" | validation | messages | high |
| 6 | Document number unique per type when `ST_BASIC.DOC_REPEAT = 0` — "رقم المستند مكرر" | validation | `DOC_REPEAT` SQL + messages | high |
| 7 | Accounts 1-4 not repeated — "رقم الحساب مكرر"; expenses / discounts ≥ 0 — "القيمة لا يمكن أقل من صفر" | validation | messages | high |
| 8 | Warning "الحركة بدون مورد" (save continues on confirmation) | `warnings` | message | high |
| 9 | Approvals: APPROVE needs `USERS.RT_ALLOW_APPROVE`, APPROVE2 needs `RT_ALLOW_APPROVE2` ("ليس لديك صلاحية الإعتماد"); management approval after the first one; stamped with user and date | row rule | `SELECT ... RT_ALLOW_APPROVE, RT_ALLOW_APPROVE2 FROM USERS` | medium |
| 10 | Converted document (POST_FLAG 1) is read-only, header and lines — "لا يمكن تعديل هذه الحركة" | row rules | message | high |
| 11 | Line: item, group, basic unit, lot of the item (price of the lot when the price is empty), quantity + bonus > 0 "يجب إدخال كمية أكبر من الصفر", price ≥ 0 "قيم الاصناف أقل من صفر", bonus / discount pairs, basic quantity, riyal price = price × rate, store / date / date serial of the header | row rule `auth_det_row` | line triggers, CONFG LOV | medium-high |
| 12 | Lines required; not more than `ST_BASIC.TRNS_MAX_ITEMS`; no repeated item when `SINGLE_ITEM = 1`; returned quantity of a lot ≤ its balance in the store — "رصيــد هذه الشحنة لهذا صنف فى هذا التاريخ لا يسمــح" | after-save `auth_after_save` | `SELECT NVL(SINGLE_ITEM,0), TRNS_MAX_ITEMS ... FROM ST_BASIC`, balance messages | medium-high |
| 13 | Delete refused once converted | after-save DELETE `auth_after_delete` | legacy delete check | high |

## Buttons
| Button | Implementation | Evidence |
|--------|----------------|----------|
| ترحيل السند / تحويل الفاتورة (convert) | action CONVERT → `auth_convert`: requires both approvals "يجب إعتماد الإدارة أولا"; inserts the purchase return (serial max + 1 per type, date today, DATE_SERIAL 999999999999, INVOICE_NO, all header values), its lines and services, runs the stock check (`APP_RULES_PR.check_stock`), marks the authorisation POST_FLAG 1; "تم التحويل" | `SELECT NVL(MAX(TRNS_SERIAL),0)+1 FROM ST_TRNS_MAST ...`, `INSERT INTO ST_TRNS_MAST (...)` of the .fmx |
| إلغاء الترحيل (cancel the conversion) | action CANCEL_CONVERT → `auth_cancel`: refused when the return is posted to GL or to the suppliers "لا يمكن الغاء الترحيل للمخازن لوجود حركة صرف تمت على هذه الحركة او تم ترحيلها للحسابات والموردين"; deletes the return, POST_FLAG 0 | message |

## Open questions / deviations
* Conversion requires both approvals (legacy message "يجب إعتماد الإدارة أولا"); is the first approval alone ever enough?
* Lot balance: checked against the current balance of the lot in the store; the legacy date-based checks ("رصيــد الصنف فى هذا
  التاريخ=", "توجد حركة تالية لهذه الحركة تتعارض معها") are not reproduced.
* "تاريخ التسليم أكبر من تاريخ الحركة": DELIVERY_DATE is not on the page; not reproduced.
* "تعديل التاريخ" (edit date button) not reproduced: the date is an ordinary field until the document is converted.

## Tests (`tmp\w3_prsa\t_w3prsa.py`, page 50251; one full convert / cancel cycle)
AU1 header numbering / derivations · AU2 line derivations (lot price, basic qty) · AU3 lot of another item · AU4 quantity 0 ·
AU5 lines and balance pass · AU6 lot balance exceeded · AU6b basic quantity follows · AU7-AU12 header validation (type,
rate, repeated accounts, negative expense, repeated document with DOC_REPEAT 0) · AU13 warning · AU14 management approval
before the first · AU15 approval without right · AU16 convert before approvals · AU17 approvals stamped · AU18-AU21 convert
(return, lines, lot balance −5, flags) · AU22-AU24 converted document read-only / not deleted · AU25 cancel refused after posting
to the suppliers · AU26 cancel (return removed, balance restored). All PASS.
The legacy trigger `ST_TRNS_MAST_IN` takes `ST_TRNS_MAST_DATE_SERIAL.NEXTVAL` for the created return: one sequence number per
test run is consumed (a gap, no data).

## Wave 3b
* Check boxes: APPROVE "الإعتماد الأول" and APPROVE2 "إعتماد الإدارة" (were numbers with the legend "(1)"; 1 = approved as in
  the row rule and the conversion check), POST_FLAG read-only check box (GN_FORM_ITEM check box).
* Legacy LOVs of the .fmx as lists: return types (EFFECT 3, TRNS_TYPE 3 / 5, ST_TRNSTYPE_PASSWORD), stores (active, not stopped,
  ST_STORE_PASSWORD nodes of the store chart), suppliers (active, not stopped, VN_SUPPLIER_PASSWORD range), cost centre 1
  (active, AC_PASSWORD_COST1 prefix ranges), accounts 1-4 (detail accounts, AC_PASSWORD_MASTER prefix ranges), items (active with
  a basic unit, ST_GROUP_PASSWORD), units of the item (cascade ITEM_CODE / GROUP_CODE), lots of the item with a positive balance
  in the document's store before the line (`GET_BALANCE_CONFG(store, group, item, lot, date, date serial, item serial) > 0`,
  ordered by lot; cascade ITEM_CODE / GROUP_CODE / TRNS_TYPE_CODE / TRNS_SERIAL / ITEM_SERIAL). This replaces the typed lot id.
* `rules.computed` on the lines: ITEM_NAME "إســم الصنـــف", EXPIRE_DATE "تاريخ الصلاحية", LOT_NUMBER "رقم التشغيلة" (legacy
  display items, from ST_ITEM / ST_ITEM_CONFG).
* Check: `check_forms.py ST_RETURN_AUTH_COST2` (13 lists run unrestricted and restricted, 3 computed columns); the lot list run
  on a real purchase line (item 101011543: 0 lots before the line, 2 lots with balance 26 / 678 for a new line).
* Not covered: line totals / expense shares / store balance display items (formulas not in the .fmx), DELIVERY_DATE check.

## Coverage
Reproduced: filter, numbering, header / line rules, approvals (check boxes), lock after conversion, lines / max / single item /
lot balance, delete guard, convert and cancel; legacy lists incl. lots with balance, item name and lot expiry / number (wave 3b).
Not reproduced: date-based balance messages, delivery-date check, edit-date button (questions above), line totals and expense
shares display items and the expense distribution / cost screens ("تكاليف الحركة" tab: values are stored, not distributed),
printing, Forms alerts / toolbar code.
