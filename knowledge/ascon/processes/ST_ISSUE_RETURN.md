# ST_ISSUE_RETURN: sales returns (مرتجعات المبيعات), registry 31/8 (without invoice) and 31/9 (with invoice)

**Deliverable:** screen rules (pattern AUTO), `app\legacy\overrides\ST_ISSUE_RETURN.json`, package `APP_RULES_SA`
(`trns_mast_row`, `trns_det_row` / `trns_det_row2`, `trns_srv_row` kind SR, `sr_validate`, `sr_after_save`) and, since wave 3,
package `APP_ACT_ST` (`sr_delete_check`, `sr_can_decompose`, `sr_decompose`, `sr_can_old_lot`, `sr_old_lot`, `sr_validate_extra`, `sr_info`).
**Confidence:** high for numbering, links, return quantity, cost of the original sale, posted / soft delete, loading the invoice items and the
old-lot formation (reproduces the 318 historical 904/901 lines); medium for the "without invoice" price / cost-date rules and the tax of returns.

## Purpose and tables
Customer returns, stock IN (`ST_TRNS_TYPE.EFFECT = 4, TRNS_TYPE = 4`: 10401, 20401, 30401). Same tables as invoices (ST_TRNS_MAST /
ST_TRNS_DET / ST_TRNS_SERVICES). The legacy form runs in two modes (menu parameter RETURN_TYPE 0 / 1, stored in RETURN_TYPE_FLAG);
81 % of the 281 returns are "with invoice". **One APEX page covers both modes:** typing the original invoice as `TYPE\SERIAL` (e.g.
`10301\608`, the legacy LOV value) in INVOICE_NO makes a return against that invoice; leaving it empty makes a return without invoice.
Installation code: NULL (CUSTOMER_PAR empty), so the `SDI` / `MAR` / `ZED` / `SAN` branches (maximum return value OPEN_BAL_TYPE, CHANGE_DATE,
prints) do not apply.

## Rules implemented
| # | Rule | Where | Legacy evidence (evidence file lines) |
|---|---|---|---|
| F1 | List: sales-return types, not deleted, group type rights (both modes) | `where` | block WHERE l.343 (the mode filter is replaced by one page) |
| D1 | Type default = first return type of the user; PRINT_FLAG 0 | `defaults` | |
| N1 | TRNS_SERIAL max + 1 per type (APPX); DATE_SERIAL by `ST_TRNS_MAST_IN` | generated / DB | PRE-INSERT l.959 |
| N2 | DOC_NO = `GET_ACT_DOC_NO_RET_INV` (sequence `DOC_NO_SEQ_RET`), drawn only when no number is given (wave 3: no NVL) | row rule | PRE-INSERT l.989 |
| N3 | Without invoice: INVOICE_NO = type + serial (7); with invoice: INVOICE_REF = type + serial, INVOICE_NO = `TYPE\SERIAL`; `RETURN_TYPE_FLAG` = 1 when linked | row rule | PRE-INSERT l.980, l.913 |
| N4 | DESC_A = `' م مبيعات رقم' || DOC_NO || ' / ' || INVOICE_NO (or INVOICE_REF)`, DESC_E = `'Return Invoice No ' ...` | row rule | PRE-INSERT l.991 |
| D2 | With invoice: RET_TRNS_TYPE_CODE / SERIAL parsed, customer, salesman, sales-order link, transport from the invoice; without invoice: salesman = `GET_LAST_SALESMAN_INDATE`; store from the type | row rule | INVOICE_LOV mapping, CUSTOMER WHEN-VALIDATE-ITEM |
| V1 | Type SR allowed for the group; not changeable | `sr_validate` | LOV TRNS_TYPE l.7470 |
| V2 | Original invoice: a sales invoice (EFFECT 2 / TRNS_TYPE 2) of the same JOIN_TYPE, not deleted, dated on or before the return, same customer, type / store allowed for the group | `sr_validate` | INVOICE_RGP l.7658 |
| V3 | Date = day of entry (legacy item disabled); CHECK_DATE (future, ST_BASIC.MIN_DATE), after AC_BASIC.CLOSE_DATE, salesman transfer date | `sr_validate` | TRNS_DATE WVI l.1547-1596 |
| V4 | Customer required and in the customer list; salesman required when HAS_SALESMAN = 1 (without invoice); rate rules; return reason `RET_INV_CODE` required and in `RET_INV_CODES` | `sr_validate` | H7-H10 |
| V5 | Store / customer / currency / rate / original invoice frozen once lines exist | `sr_validate` | PRE-TEXT-ITEMs |
| V6 | (wave 3) PRINT_FLAG can only be changed by user 0 (the item is enabled only for `:GLOBAL.USER_CODE = 0`) | validation `sr_validate_extra` | WHEN-NEW-FORM-INSTANCE l.740 |
| L1 | With invoice: item and lot must be on the invoice; unit = the invoice's unit; price and discounts = the invoice line's (average per lot); **ITEM_SERIAL = the invoice line serial** (legacy key convention); the same lot twice is refused | row rule | ITEM2_RG / CONFG_RG, ITEM_CONFG_ID WVI l.3538 |
| L2 | Return quantity: returned so far on all returns of the invoice for this lot + this line ≤ sold (qty + bonus + extra) → "إجمالى الكمية المرتجعة اكبر من اجمالى الكمية المباعة" | row rule + safety net in `sr_after_save` | CHECK_RETURN_QTY l.6130 |
| L3 | Without invoice: lot required and of the item; default price REDUCTION_PRICE, else WIDE_SALE_PRICE when ST_STORE.DEAL_TYPE = 1, else RETAIL_SALE_PRICE (/ rate); DISC1 default ST_ITEM.MOH_DISC; a lot "-1" typed in the grid points to the action O1 below | row rule | ITEM_CODE WVI l.3312 |
| L4 | UNIT_COST (drives the stock cost layer of an IN movement): with invoice = `GET_UNIT_COST_CONFG` at the invoice's store/date/date-serial (cost of the original sale); without invoice = at the return date, date serial 99999999; 0 → `ST_ITEM_UNIT.IU_UNIT_COST`; COST_FLAG 1 | row rule | line PRE-INSERT l.2900-2936 |
| L5 | qty + bonus + extra > 0; price ≥ 0; discount checks; BASIC_QTY, UNIT_PRICE; DET_DISC / DISC = 0 | row rule | l.2872-2897 |
| L6 | VAT: with invoice at the invoice's rate (`GET_ACT_TAX_PRC`) × BASIC_QTY × net price; without invoice by the tax tables on BASIC_QTY × net price | row rule | SET_TAX_DET l.6910 |
| L7 | Saved lines: item / unit / lot / quantity / price cannot be updated (delete and re-enter); discounts can | row rule (update) | XML UpdateAllowed = false |
| A1 | A return must have items or services (from the first save after the header) | `sr_after_save` | PRE-INSERT l.915, POST-DELETE l.2660 |
| A2 | Line count ≤ ST_BASIC.TRNS_MAX_ITEMS | `sr_after_save` | WNII l.2729 |
| A3 | Deleted lines: later issues of the lot must not go negative (`UPDATE_NEXT_TRNS_CONFG` from the balance before the line) | `sr_after_save` (snapshot) | line KEY-DELREC l.2434 |
| P1 | Posted returns read-only and not deletable ("الفاتورة تم ترحيلها للأنظمة الأخري") | `sr_validate`, `sr_delete_check` | CLOSE_POSTED, header KEY-DELREC l.1137 |
| S1 | Services: with invoice only services of the invoice; price > 0; tax | row rule | SERVICE_RG l.7627 |

## Wave 3 additions
| # | Legacy behaviour | APEX | Evidence |
|---|---|---|---|
| X1 | **Delete = soft delete** (DELETE_FLAG / DELETE_USER / DELETE_DATE; the lines stay, flagged by `ST_TRNS_MAST_UP`; data: all 16 deleted returns kept their lines) after the header check (posted → "الفاتورة تم ترحيلها للأنظمة الأخري") and the line check of the detail KEY-DELREC run with MASTER_DELETE = 1, last line first: removing each stock-in must not make a later movement of its lot negative ("الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها.", skipped with NEG_SALE_BALANCE = 1) | `rules.soft_delete` (lines keep, check `sr_delete_check`) | header KEY-DELREC l.1137, detail KEY-DELREC l.2434 |
| D1 | **"إنزال أصناف الفاتورة"** (PUSH_BUTTON401, return with invoice, only while the return has no items): every invoice lot still to return (sold − returned on all live returns of the invoice, quantity / bonus / extra bonus separately) becomes a return line through the return row rule (unit, price, discounts, line serial, cost of the original sale, VAT of the invoice); then the invoice services (DECOMPOSE_INVOICE_SERVICE, SERVICE_COST = invoice cost / rate) | action `LOAD_INV` (`sr_decompose`), message "تم إنزال N صنف من الفاتورة t\s" | PUSH_BUTTON401 l.2135, DECOMPOSE_INVOICE_DET l.5303, DECOMPOSE_INVOICE_SERVICE l.5447 |
| O1 | **"شحنة قديمة" (-1) of a return without invoice** (CONFG_RG row -1, SET_LOT_REQ(1): lot number, expiry and unit cost required): GET_THE_CONFIG finds or creates the lot with `GET_CONFG_ID` (item, group, supplier = ST_ITEM.SUPPLIER, UNIT_PRICE of the line, lot number, expiry when the group has EXPIRE_FLAG, DISC1 of the line, store, create) and writes one lot-formation IN line (quantity 1, COST_FLAG 0, UNIT_COST = typed cost or IU_UNIT_COST, UNIT_PRICE = line price, SALES_PRICE = retail price) in the first live header of the first AUTO_TRNS type EFFECT 1 / TRNS_TYPE 7 of the store (904/1) and one OUT line (COST_FLAG 1, UNIT_PRICE = cost) in the first header of the first AUTO_TRNS type EFFECT 2 / TRNS_TYPE 7 (901/1); then the return line on that lot. Messages "خطأ بمؤشرات النظام" / "وارد خطأ بمؤشرات النظام" / "صادر خطأ بمؤشرات النظام" / "خطأ بمحددات الشحنة" | action `OLD_LOT` "صنف بشحنة قديمة" (params item, unit, quantity, bonus, lot number, expiry, unit cost, price, discount 1; `sr_old_lot`) | ITEM_CONFG_ID WVI l.3588, PRE-INSERT l.2834, GET_THE_CONFIG l.7051, SET_LOT_REQ l.7363; data: 318 lines each in 904/1 and 901/1 (e.g. 904/1 line 315 ↔ return 10401/198 line 27, lot 2598: cost 20.86, price 43.45, lot DISC_RATIO = line DISC1) |
| I1 | Displays: remaining credit (CREDIT_LIMIT − AR balance of AR_MAINTRNS), original invoice date, net of the lines, and the notices of the line triggers (MSG level 0): balance above the store maximum ST_STORE_ITEM.MAX_LIMIT ("!!رصيد الصنف سوف يزيد عن الحـد الأقصي - الحد الأقصى هو = …", with the lot balance when the user has ALLOW_VIEW_BALANCE) and, without invoice, a price below the wholesale price ("يجب ان لا يقل سعر الصنف عن سعر الجملة") | `rules.info` (`sr_info`) | POST-QUERY l.1121, QUANTITY / BONUS / EXTRA_BONUS WVI l.3650-3741, UNIT_PRICE_CURR WVI l.3783 |

The legacy did the old-lot formation in the line PRE-INSERT from non-database items (LOT_NUMBER_DUMMY / EXPIRE_DATE_DUMMY) and a unit cost
that is a display column on the generated grid; the generator cannot make those enterable, so the formation is a button with the same
inputs (the lot "-1" typed in the grid is refused with a pointer to it). The notices of the max limit / wholesale price were non-blocking
messages at entry: the `warnings` mechanism cannot see grid lines that are not saved yet, so they are shown in the info panel after the save.
MAX_LIMIT and WIDE_SALE_PRICE are not set in this data, so today they never appear.

## Wave 3b (new generator keys)

Evidence: `ASCON\ST\FMB\ST_ISSUE_return_fmb.xml`.

| Change | Key | Evidence |
|---|---|---|
| Transaction type and store read-only after insert; store required | `TRNS_TYPE_CODE` / `STORE_CODE` `readonly_after_insert`, `STORE_CODE.required` | `UpdateAllowed="false"`, `STORE_CODE Required="true"` |
| Return reason "السبب" required, list `RET_INV_CODES` | `RET_INV_CODE` (`required`, `lov`, label) | `Required="true"`, LOV RET_INV_LOV → `SELECT COMPLAINT_CODE, COMPLAINT_NAME ... FROM RET_INV_CODES`; all 281 returns have it |
| Tax code "رقم الضريبة" list `TX_TAXES_TYPES`, read-only after insert | `TAX_CODE_MAST` | LOV TAX_LOV, `UpdateAllowed="false"` |
| Per line: item name, lot number and expiry, "الرصيد قبل الحركة" (ALLOW_VIEW_BALANCE), "التكلفة المتوسطة" | `computed.ST_TRNS_DET.*` | display items STORE_BALANCE / STORE_COST, labels |
| The always-empty `LOT_NUMBER` / `PRODUCTION_DATE` columns hidden (non-database items in the .fmb) | `columns.*.hidden` | `DatabaseItem="false"` |
| Lot list of the line's item (lot id - lot number - expiry), refreshed when the item changes | `ITEM_CONFG_ID` `lov` + `cascade: ITEM_CODE` | legacy lot LOV (ITEM_CONFG_LOV / CONFG); the row rule still checks the lot and its balance |
| Button "ترحيل السند" opens the posting screen ST_POSTING_CPOSTING with the document's type, serial and date filled in (from / to) | `links` | POST_BUT: `CALL_FORM(... 'ST_POSTING_CPOSTING' ...)` with TRN_CODE / TRN_SER / TRN_DATE |

Costs are empty unless (USERS.ALLOW_VIEW_COST = 1 and ST_BASIC.SHOW_COST = 1) or the user's group is 0 (legacy GET_USER_SEC); the column itself stays visible (the generator cannot hide a column per user right). The legacy button chose post (FILTER 1) or cancel (FILTER 2) from POST_FLAG; the link cannot set a value that depends on the record, so the operation stays the posting page's default (post) and the user switches it to cancel when needed. Tested on the build copy: every list query and computed expression runs (`tmp\w3b_st\sqlcheck.py`, lot list with item 101010006); the cost / balance gates checked in an APEX session (`t_gates.py`, rolled back, session removed).

Second wave-3b sweep (purchasing / sales agent): no further key applies. The list item "نوع الفاتورة" (INV_TYPE / INV_TYPEL) is in
GN_FORM_ITEM but not in the .fmb source, its values are not in the evidence and ST_TRNS_MAST.INV_TYPE is empty on all 1 715 sales
invoices and returns (probably the later e-invoice type; ZATCA is deferred) — not placed, question for the business.

## Differences from the legacy form (for review)
- "إنزال أصناف الفاتورة" writes the lines at once (legacy: filled the block, the user corrected quantities and deleted lines before the
  save); a partial quantity is then entered by deleting the line and entering it again (saved lines are not updatable, L7). Invoice lines of
  the same lot (7 invoices) become one return line per lot (the row rule treats the lot as the unit; legacy: one line per invoice line).
- The OUT formation header is checked ("صادر خطأ بمؤشرات النظام"); the legacy tested the IN count twice and then failed on the insert.
- The old-lot formation lines are dated with their header (2024-10-01), as the legacy wrote them.

## Open questions
1. Keep the old-lot formation (904/1, 901/1 of store 101010101001 only; the other stores have no formation header and get "وارد خطأ
   بمؤشرات النظام", as in the legacy)?
2. Should returns be allowed against invoices of another department's type (4 historical cases) — the legacy list allows same JOIN_TYPE.
3. Cost date for returns without invoice: legacy "end of the return date" (99999999) kept.
4. Discounts of "with invoice" lines are editable (legacy); lock them?
5. Group 102 users see nothing (ST_TRNSTYPE_PASSWORD empty).

## Tests (ROLLBACK)
Wave 2: `t_sr.py`: 34 checks.
Wave 3: `tmp\w3_sales\f1\t_f1.py` (plain 59 / APEX 66 checks, both passing): load invoice items (one line per lot still to return, remaining
quantities, invoice line serial, price / discounts, cost; not offered / refused when lines exist; the return then passes the save rules; also
inside APEX), displays (remaining credit, invoice date, total) and notices (store maximum, wholesale price), soft delete (unposted accepted, lines
kept and flagged, posted refused, refused when a later issue of the returned lot would go negative), old lot (unit cost required when the item
has none, lot created with lot number / expiry / price / MOH_DISC / supplier, 904/1 and 901/1 lines as in the history, return line on the
new lot with its cost, same parameters reuse the lot, lot number / expiry / quantity / item errors, store without formation header, refused
on a return with invoice, grid "-1" refused with a pointer, inside APEX), print flag only for user 0.

## Coverage
Reproduced: all rules of the two tables above.

Deliberately not reproduced, with the reason:
- **Forms-only mechanics**: SHOW_HIDE_* / ENABLE_DISABLE_CONFIG / SET_LOT_REQ as properties, visual attributes, navigation and window
  handling, KEY-CREREC / KEY-DOWN "open record without items" (the page saves the header first), DO_SUM / DO_SUM_NEW / DO_SUM_TEMP (unit
  totals window, KEY-HELP), ST_STORE_ITEM / ST_ITEM_UNIT look-up windows, the delete confirmation alert, the zero-cost notice "تكلفة الصنف
  بصفر سوف يتم اخذ التكلفة من ملف الاصناف" (the cost is taken from the item file as the legacy did).
- **Printing** (PRINT_BTN*, ITEM151, ENTRY_PRINT): prints agent. **Posting** button (POST_BUT): a link to ST_POSTING_CPOSTING since
  wave 3b.
- **ZATCA** (ZATCA button, EI_SEND_INVOICE): out of scope.
- **Inactive in this installation / data**: the SDI maximum return value (ST_STORE.OPEN_BAL_TYPE) and the other `CUSTOMER_CODE` branches
  (code NULL); cash-box sync INSERT_RP_PC_TRNS / PAYMENT updates (no RP / PC types, payment columns hidden); CHECK_DOC_NO (DOC_REPEAT = 1,
  DOC_NO not typed); the old-invoice reference list OLD_INV_RG of INVOICE_REF in the "without invoice" mode (never used: 0 of 53 returns
  without invoice have INVOICE_REF; INVOICE_REF is read-only on the page); colour / size of an old lot (ST_BASIC.COLOR_FLAG = SIZE_FLAG = 0).
