# ST_DELIVERY: delivery notes (مذكرات التسليم), registry 31/6

**Deliverable:** screen rules (pattern AUTO), `app\legacy\overrides\ST_DELIVERY.json`, package `APP_RULES_SA`
(`dlv_mast_row`, `dlv_line_serial` (key_expr), `dlv_det_row`, `dlv_validate`, `dlv_after_save`) from wave 2 and package `APP_ACT_ST`
(section `dlv_`) for the wave-3 buttons, delete rules, NOTE_NO check and displays.
**Confidence:** medium (compiled .fmx only — wave 3 read the SQL, literal pools, number constants and symbol tables of each program
unit; the screen has never been used: all tables empty and no delivery types `EFFECT 7 / TRNS_TYPE 31` exist, so the page lists
nothing until types are configured; everything was tested with temporary types).

Installation code (`:GLOBAL.CUSTOMER_CODE` = `CUSTOMER_PAR.CUSTOMER_CODE`, Sysmenu.fmx): CUSTOMER_PAR is empty on this database
(production discovery `_discovery\05_tables_rows.csv`), so the code is NULL and every `= 'SDI'` branch of this form is inactive:
the automatic invoice after commit, the credit-limit refusal, the SDI note numbering and the SDI customer / salesman LOV opening
(evidence: the literal 'SDI' in the pools of the triggers P4, P7, P9, P18 and of GET_NEXT_DELIVERY_DOC_NO).

## Rules implemented (wave 2, APP_RULES_SA)
| # | Rule | Where | Evidence (ST_DELIVERY.md, fmx SQL) |
|---|---|---|---|
| F1 | List: delivery types (7/31) and group type rights (FLAG 1) | `where` | type record group, default WHERE |
| N1 | TRNS_SERIAL max + 1 per type (APPX); DELIVERY_SERIAL max + 1 per type; NOTE_NO max + 1 per type (variant of this installation of GET_NEXT_DELIVERY_DOC_NO; the per store / year variant is the `CUSTOMER_CODE = 'SDI'` branch) | row rule | numbering SQL, literal 'SDI' |
| N2 | **Line SERIAL = the sales-order line of the item** (never a running number) | `key_expr` → `dlv_line_serial` | CHECK_SALES_CLOSE, POP_DETAIL |
| D1 | Store of the type; customer / supplier / salesman from the order; DELETE_FLAG 0; DELIVARY_STATE 1 | row rule | order copy SQL |
| V1 | The type must be linked to an issue type (SALES_TRNS_TYPE_CODE) | row rule | "يجب ربط اذن التسليم بسند اخراج في شاشة انواع الحركات" |
| V2 | Order required, exists, not before the delivery date, still has undelivered quantity (`CHECK_VALID_ORD`); date not future / ≥ MIN_DATE; cancelled or converted notes read-only | `dlv_validate` | H2-H4, order LOV |
| L1 | Delivered qty > 0; item must match the order line; group / unit / lot / prices from the order line; store = header | row rule | L1, line lookups |
| A1 | Items required (from the first save); discount < note total; delivered ≤ ordered and bonus ≤ ordered bonus per order line over all non-cancelled notes; lot balance at the delivery date (NEG_SALE_BALANCE = 0) | `dlv_after_save` | H5, H6, L2, L3 |

## Wave 3: buttons and rules added (APP_ACT_ST, section `dlv_`)
| # | Rule / button | Where | Evidence | Confidence |
|---|---|---|---|---|
| B1 | **"تحويل الي فاتورة بيع"** (INV_TRNS + MAKE_INV): parameters sales type (default ST_TRNS_TYPE.SALES_TRNS_TYPE_CODE of the note type; list SALES_TRNS_TYPE_RG = EFFECT 2 types of the note's store granted with FLAG 1) and invoice date. Checks in the legacy order: note in state 3 "مرحلة الشحن" ("لابد ان تكون حالة المذكرة في مرحلة الشحن لتحويلها الي فاتورة"), not converted yet ("مذكرة التسليم تم تحويلها إلي فاتورة مبيعات"), not cancelled, type and date given ("يجب إدخال رقم حركة فاتورة المبيعات و تاريخ الفاتورة"), date ≥ delivery date ("تاريخ الفاتورة يجب أن يكون أكبر من يساوى تارخ الإستلام"), CHECK_DATE, AC_BASIC open period | action `TO_INVOICE` → `dlv_can_invoice`, `dlv_first_sales_type`, `dlv_to_invoice` | triggers P25 / P27 / P26 (literals, symbols :DELIVARY_STATE, :SALES_TRNS_TYPE_CODE, :SALES_DATE), SALES_TRNS_TYPE_RG SQL | high (checks) |
| B1a | INSERT_ISSUE_TRNS: invoice header = serial max + 1 per sales type (GET_SALES_TRNS_SERIAL), DATE_SERIAL (DB trigger), store / customer / supplier / salesman / DISC_VAL / TRNSPORT_VAL of the note, currency and rate of the sales order, DESC 'فاتورة مبيعات رقم t/s من مذكرة التسليم  dt/ds' / 'Sales Invoice No. t/s From Delivery document.  dt/ds', DELIVERY_TRNS_* = the note, ORDER_TRNS_* = its order, DEMO_TRNS_* = the order's quotation, INSERT_USER / DATE, POST_FLAG 0, PO_NO = NOTE_NO, TOT_VAL = net value of the note / rate; DOC_NO = NOTE_NO, else GET_NEXT_SALES_DOC_NO (MAX(DOC_NO) + 1 of the sales invoices); INVOICE_NO = type ‖ LPAD(serial, 5, '0') | `dlv_to_invoice` | the INSERT statement of INSERT_ISSUE_TRNS (column list and binds in symbol order: :NOTE_NO, :CURRENCY_CODE .. :NET_VALUE_CURR), literals '0' and number 5, dependency on GET_NEXT_SALES_DOC_NO | high for the INSERT, low for DOC_NO / INVOICE_NO (question 2) |
| B1b | Lines: each note line with its lot → balance of the lot at the invoice position must cover (qty + bonus) × factor ("رصيــد الصنف .. فى هذا التاريخ لا يسمــح  .... !!!"), INSERT_DET (qty, bonus, basic qty, lot, prices, DET_DISC, COST_FLAG 1, UNIT_COST null, FREIGHT .. OTHERS 0); a line without lot → DEVIDE_CONFGS: lots by expiry, each giving at most GET_MIN_BALANCE_CONFG_AFTER (quantity first, then bonus); shortage → "أقصى كمية يمكن إخراجها حتى لا تتعارض مع الحركات التالية = …" | `dlv_to_invoice` | INSERT_ISSUE_TRNS balance messages, INSERT_DET and DEVIDE_CONFGS SQL / symbols | medium (branch order inferred) |
| B1c | UPDATE_DISC: the note discount per basic unit of each invoice line = DISC_VAL × QUANTITY × UNIT_PRICE / (Σ QUANTITY × UNIT_PRICE × BASIC_QTY) (as GET_NDB_DISC) | `dlv_to_invoice` | UPDATE_DISC SQL (SUM(BASIC_QTY), SUM(QUANTITY*UNIT_PRICE), UPDATE ST_TRNS_DET SET DISC) | medium |
| B1d | Success text "تم عمل اخراج رقم t/s"; the invoice page opens | action message | INSERT_ISSUE_TRNS literal | high |
| B2 | **"إلغاء مذكرة التسليم"** (DEL_BUTTON, confirmation "سيتم إلغاء مذكرة التسليم وحذف الصادر الخاص بها...هل تريد الإستمرار"): refused when already cancelled ("المذكرة ملغاه بالفعل") or merged into a merge invoice (ST_MERG_DET: "لا يمكن حذف مذكرة التسليم لوجود فاتورة مبيعات عليها"); deletes the generated issue (ST_TRNS_DET, ST_TRNS_MAST), sets DELETE_FLAG = 1, "تم إلغاء مذكرة التسليم"; shown to users with update right on the page | action `CANCEL_NOTE` → `dlv_can_cancel`, `dlv_cancel` | trigger P31 (SQL lines 10 / 38 / 42, literals) | high |
| X1 | Delete of a note with a live sales invoice refused ("يجب حذف فاتورة البيع اولا"); of a merged note ("لا يمكن حذف مذكرة التسليم لوجود فاتورة مبيعات عليها"; the FK ST_MERG_DET_DLVR refuses it first with the generic message) | `after_save` DELETE → `dlv_after_delete` | master PRE-DELETE P14, KEY-DELREC P5 | high |
| V1 | NOTE_NO repeated in the type (CHECK_DOC_NO): refused when ST_BASIC.DOC_REPEAT = 2 ("لا يمكن تكرار المستند"), confirmation when 3 ("رقم المستند مكرر" + continue?); DOC_REPEAT is 1 here, so no check today | `validations` `dlv_note_error`, `warnings` `dlv_note_warning` | CHECK_DOC_NO SQL, number constants 1/2/3 (same template as CHECK_DOC_NO of ST_ISSUE_IO.fmb: `IF VAR.DOC_REP IN (2,3)`) | high |
| I1 | Displays: generated sales invoice; note total Σ(UNIT_PRICE × DELIVERED_QTY − DET_DISC); net (total − discount + transport); customer credit limit, current balance `SUM(DECODE(ATT.EFFECT,0,TOTAL_VALUE*CURRENCY_RATE,1,-(TOTAL_VALUE+DISC_VALUE)*CURRENCY_RATE))` over AR_MAINTRNS and the remaining credit ("متبقى الإئتمان") — the last three only for users with USERS.ALLOW_VIEW_BALANCE = 1 | `info` → `dlv_info` | POST-QUERY P8 SQL, WHEN-NEW-FORM-INSTANCE (ALLOW_VIEW_BALANCE next to CREDIT_LIMIT / CRN_BAL_TOTAL) | high / medium (visibility) |

The converted invoice is found through ST_TRNS_MAST.DELIVERY_TRNS_TYPE_CODE / SERIAL (what INSERT_ISSUE_TRNS writes) or
ST_TRNS_DET.OPER_TRNS_TYPE_CODE / SERIAL (what the legacy POST-QUERY read back); the rows are written with the invoice row rules of
APP_RULES_SA standing aside (`set_bypass`), as the legacy INSERTs did not run the invoice screen's derivations (no VAT on the lines —
question 1).

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Payment-term list `ST_PAYMENT_TERMS`, delivery-term list `ST_DELIVERY_TERMS` | `PAYMENT_TERMS.lov`, `DELIVERY_TERMS.lov` | .fmx SQL `SELECT SERIAL, NO_OF_DAYS, TYPE_NAME, TYPE_NAME_E FROM ST_PAYMENT_TERMS`, `SELECT SERIAL, DELIVERY_TERM_NAME ... FROM ST_DELIVERY_TERMS` |
| Wrong automatic list on "اعد بواسطة" `EMP_CODE` (`PY_ENDSRV`, the end-of-service table) removed | `EMP_CODE.lov = null` | no employee LOV SQL in the .fmx (EMP_NAME display only) |
| Item name per line | `computed.ST_DELIVERY_DET.ITEM_NAME` | display item ITEM_NAME |

The delivery tables are empty (feature unused); the SQL was run on the build copy (fake row for the name). Still not reproduced:
per-line balance / cost / totals (formulas not readable from the compiled form).

## Coverage

Reproduced: the two tables above.

Not reproduced, with the reason:
- `CUSTOMER_CODE = 'SDI'` branches (other installation): automatic invoice after each commit (P4), the credit-limit refusal "هذا
  العميل تخطى الحد الائتمانى" (P7 / P18), the note number per store and year, the customer / salesman lists opened to all groups.
- **Multi-note merge**: done by another form (ST_MERG_DLVR, table ST_MERG_DET); this screen only refuses to cancel / delete a merged
  note (implemented).
- Default description when choosing the order (ORDER_TRNS_SERIAL WHEN-VALIDATE-ITEM, literals 'أمر البيع رقم ', '  رقم '): the order of
  the pieces cannot be read from the compiled trigger; the description stays free text.
- Deleting a note line deleted the invoice lines of that item (detail KEY-DELREC P35): unreachable, a converted note is read-only
  (wave-2 rule V2).
- USERS.ALLOW_DLVR / SEE_PRICE and :PARAMETER.P_TYPE (menu parameter; with P_TYPE = 1 the list hid cancelled notes): read at start-up
  next to the price items and the two buttons (display properties); the exact effect cannot be read — the buttons follow the page
  rights, all notes are listed (question 4).
- Forms-only: SO_TYPE / DELIVARY_STATE lists as display, HILIGHT, SHOW_HIDE_ITEMS / CONFIG, unit LOV variants, colour / size checks
  (flags 0), printing, WEBUTIL, SET_IP.

## Open questions
1. Is the screen needed at all (orders are invoiced directly)? If yes: which delivery types, whether stock leaves at delivery or at
   invoicing. The 2012 conversion writes invoice lines without VAT and without the invoice screen's policy / tax rules — keep, or
   run the invoice rules on the created invoice?
2. DOC_NO / INVOICE_NO of the created invoice: the compiled form uses :NOTE_NO, GET_NEXT_SALES_DOC_NO and an LPAD(…, 5, '0'); the
   exact assignment is not readable (implemented: DOC_NO = NOTE_NO else MAX + 1, INVOICE_NO = type ‖ 5-digit serial). The sales
   invoice screen itself now uses DOC_NO_SEQ.
3. Cancelling a note deletes its generated invoice without checking whether that invoice was posted (legacy) — add a posted check
   (suggested)?
4. Should USERS.ALLOW_DLVR (0 for every user today) restrict the convert / cancel buttons?

## Tests (ROLLBACK, temporary types 91030 / 91031)
`tmp\w3_sales\f3\t_f3.py` (plain and simulated APEX session on page 60121): default sales type, state / type / date / future date /
wrong-store refusals, lot shortage, invoice header (links, DOC_NO, INVOICE_NO, currency, PO_NO, TOT_VAL), line, discount spread,
legacy text, second conversion refused, DOC_NO_SEQ untouched, delete refused with invoice / merge, cancel refused when merged, cancel
(invoice deleted, flag, text), second cancel refused, delete after cancel, lot split by expiry for a line without lot, DOC_NO from
GET_NEXT_SALES_DOC_NO, no negative lot, NOTE_NO repeat with DOC_REPEAT 1 / 2 / 3, credit / balance / totals displays and their
visibility — 32 checks, all passed in both modes (with the reservation part: 58 plain / 60 APEX).
