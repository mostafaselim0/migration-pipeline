# ST_SALES_ORDER: sales orders (أوامر البيع), registry 31/3, 31/4 and 31/5

**Deliverable:** screen rules (pattern AUTO), `app\legacy\overrides\ST_SALES_ORDER.json`, package `APP_RULES_SA`
(`so_mast_row`, `so_det_row`, `sales_line`, `so_validate`, `so_after_save`); the make-invoice action is reproduced from the invoice page
(`si_after_save`, see ST_ISSUE_IO.md A1). Wave 3: package `APP_ACT_ST` (`so_*`: close / reopen / cancel / activate actions, DEVIDE_CONFGS
lot split, delete check, warnings, displays) — see "Wave 3" below.
**Confidence:** high for numbering, defaults, header checks, lock after invoicing, line derivations; medium for the approval policy
gate (legacy query is broken, the intended rule is implemented) and lot defaulting.

## Purpose and tables
`ST_SALES_ORDER` / `ST_SALES_ORDER_DET`, types `EFFECT 7, TRNS_TYPE 30` (10201, 20201, 30201 → invoice types 10301, 20301, 30301).
1,305 of 1,306 orders were created from quotations (ST_PRICE_PROPOSAL, approved at both levels on creation — in APEX the action TO_ORDER
of the quotation page, `APP_CONV.quote_to_order`, see ST_PRICE_PROPOSAL.md; the order row rules stand aside while it writes the copied
lines) and 1,301 are invoiced. The
three menu entries run the same form (mode parameter overwritten at start-up); one APEX page covers them.

## Rules implemented
| # | Rule | Where | Legacy evidence (ST_SALES_ORDER.md) |
|---|---|---|---|
| F1 | List: order types, group type rights (FLAG 1), `GET_SALES_PRIV` (customer / salesman rights), not cancelled (`DELETE_DATE IS NULL`), own orders only for `USERS.OWNER_SALES_ORDER_ONLY = 1` outside group 0 | `where` | block WHERE l.417 + WHEN-NEW-FORM-INSTANCE |
| N1 | TRNS_SERIAL max + 1 per type (APPX), line SERIAL max + 1 (APPX) | generated | PRE-INSERT l.919, 2574 |
| N2 | INVOICE_NUMBER ("S.O #") = legacy text `MAX(NVL(INVOICE_NUMBER,0)) + 1` over the table (gives '10', faithful) | row rule | PRE-INSERT l.929 |
| D1 | ORDER_DATE today; store of the type (active); currency from the customer, rate from AC_CURRENCY; salesman `GET_LAST_SALESMAN_INDATE`; APPROVED / APPROVED2 / CLOSED 0; AUTO_DISC_INIT 1; OFFER_EXPIRE_DATE = date + 10 when a payment term is given | `defaults` + row rule | TRNS_TYPE / CUSTOMER / PAY_TERM WVI, XML initial values |
| V1 | Type SO allowed; customer required ("يجب إدخال رقم العميل ") and in the customer list; store active / allowed; salesman required (HAS_SALESMAN) and of the customer | `so_validate` | PRE-INSERT l.912, CUSTOMER_RG, SALESMAN_RG |
| V2 | Currency 1 ⇒ rate 1 ("معامل التحويل يجب أن يكون 1 !!!") | `so_validate` | l.1702 |
| V3 | ORDER_DATE = day of entry (item disabled); not future, ≥ ST_BASIC.MIN_DATE; not before the customer's last salesman transfer | `so_validate` | VALIDATE_DATE l.5929-5981 |
| V4 | Class only with ENABLE_CHANGE_CLASS / group 0 and not once lines exist | `so_validate` | CLASS_CODE WVI l.1407 |
| V5 | On insert: RFQ unique ("RFQ Repeated -"), customer PO / DOC_NO unique in orders ("Cust Po. Repeated -") and among invoices of the same category ("رقم المستند مكرر لنفس رقم القسم") | `so_validate` | PRE-INSERT l.856-906 |
| V6 | Approvals (APPROVED / APPROVED2 check boxes replace the buttons): level 2 needs level 1; approving an order outside the price policy (discount or bonus above the policy values, quantity above ST_ITEM_UNIT.SALES_LIMIT) needs USERS.ALLOW_APPROVE / ALLOW_APPROVE2 (group 0 always may); un-approving refused when a live invoice or a purchase order exists, or level 2 is set; closed orders cannot change approval; header discounts frozen after approval | `so_validate`; approver / date stamped by `so_mast_row` | AUTH_SALES_ORDER l.1831-2151, CALC_TOT_DISC l.4909, ENABLE_DISABLE_BUTTONS l.4046 |
| L1 | Line: group / basic unit; lot required, earliest-expiry lot with stock when empty, lot of the item with stock at the order date; policy values `ORG_*` by `CALC_SALES_DISC` on new item / unit / lot; AUTO_DISC (from AUTO_DISC_INIT) = 1 → policy price, discounts, bonus ratios, quantity rounded to a bonus multiple, bonus = ROUND, extra = TRUNC; otherwise empty fields from the policy and ratios from values; TEMP_QUANTITY ↔ QUANTITY; BASIC_QTY, UNIT_PRICE, discount values; qty + bonus > 0, non-negative values, discounts < price; LAST_EXPIRE_DATE | row rule (`so_det_row`, `sales_line`) | ITEM_CODE WVI l.2874-2991, CALC_SALES_DISC_TOT l.5067, DEVIDE_CONFGS, PRE-INSERT l.2523 |
| L2 | VAT on ROUND(BASIC_QTY × net price) (TAX_LIB GET_TAX_VALUE) | row rule | GET_TAX_DET |
| L3 | Invoiced order (live ST_TRNS_MAST with ORDER_TRNS_* = order): lines read-only (insert / update in the row rule, deletes in after-save) | row rule + `so_after_save` | ENABLE_DISABLE_BUTTONS |
| A1 | The last line cannot be deleted ("غير مسموح بحفظ  امر البيع بدون أصنــــــاف !!! ") | `so_after_save` (snapshot) | detail POST-DELETE l.2786 |
| A2 | Header TOT_DISC1..3 cascade from ratios / values | `so_after_save` | VALIDATE_TOT_DISC1..3 |
| I1 | Make invoice: done on the invoice page by creating an invoice with the order reference (lines copied, order linked, DOC_NO shared) | ST_ISSUE_IO A1 | INV_TRNS / MAKE_INV / INSERT_ISSUE_TRNS |

## Wave 3: buttons, lot split, warnings, displays, delete (package APP_ACT_ST, `app\db\23_act_st.sql`)
| # | Legacy | APEX | Evidence (ST_SALES_ORDER.md evidence pack) | Confidence |
|---|---|---|---|---|
| B1 | CLOSE_SALES_ORDER "إقفال": refused when closed ("امر البيع مقفل بالفعل"), confirmation "هل انت متاكد من إقفال الحركة؟", CLOSED := 1, commit, "تم اقفال أمر البيع" | action CLOSE (`so_close`), shown while open and not cancelled (ENABLE_DISABLE_BUTTONS) and the user may update the page (DEF_USR_SEC); CLOSED is read only on the page | l.2222-2271, ENABLE_DISABLE_BUTTONS l.4153 | high |
| B2 | CANCEL_CLOSE "إلغاء الاقفال": refused when open ("امر البيع مفتوح بالفعل"), CLOSED := 0, "تم فتح أمر البيع" | action REOPEN (`so_reopen`), shown while closed | l.2273-2320 | high |
| B3 | CANCEL "إلغاء/تنشيط أمر البيع" (toggle): refused when a live ST_TRNS_MAST has ORDER_TRNS = the order ("تم عمل فاتورة مبيعات"), when PR_ORDER_DET has SL_TRNS = the order ("تم عمل امر شراء"), for approved or closed orders ("لا يمكن إلغاء أمر بيع معتمد أو مغلق"); DELETE_DATE / DELETE_USER set ("تم إلغاء أمر البيع") or cleared ("تم تنشيط أمر البيع") | actions CANCEL_ORDER / ACTIVATE_ORDER (`so_cancel(p_activate)`), one per state so a stale page cannot toggle the wrong way; cancelled orders leave the list (block WHERE `DELETE_DATE IS NULL`), the document page keeps showing the order so it can be activated | l.2322-2380 | high |
| B4 | DEVIDE_CONFGS: a line entered without a lot (AUTO_DISC 1 with a quantity, or AUTO_DISC 0 with bonus only) is spread over the lots by expiry: the first lot with GET_MIN_BALANCE_CONFG_AFTER > 0 keeps the line (quantity first, bonus zeroed when the lot cannot hold the quantity), new lines take the rest with the policy values of their lot (CALC_SALES_DISC), LAST_EXPIRE_DATE, the line's discounts; not enough stock over all lots → "أقصى كمية يمكن إخراجها حتى لا تتعارض مع الحركات التالية = item qty unit" (NEG_SALE_BALANCE = 0) | row-rule hook `so_mark_auto_lot` (marks the lines saved without a lot, before APP_RULES_SA.SO_DET_ROW picks the earliest lot) + after-save `so_split_lots` (bypasses the line rules while it rewrites the lines; BASIC_QTY, UNIT_PRICE and VAT as PRE-INSERT / GET_TAX_DET). The hook is a new row-rule string: active after the next build | l.5985-6265, TEMP_QUANTITY / BONUS KEY-NEXT-ITEM l.3210, 3335 | medium-high |
| B5 | Physical delete (DEL_BTN + PRE-DELETE removes the lines); DELETE_ALLOWED false once a live sales invoice refers to the order | the page deletes the lines, then the order; after-save DELETE `so_after_delete` refuses (rolls back) when a live invoice has ORDER_TRNS = the order ("امر البيع تم تحويلها إلي فاتورة مبيعات") | PRE-DELETE l.1151, ENABLE_DISABLE_BUTTONS l.4092 | high |
| W1 | TEMP_QUANTITY / QUANTITY WHEN-VALIDATE-ITEM: MSG('تعديت حد الائتمان', 0) when CREDIT_LIMIT < CRN_BAL_TOTAL, or < CRN_BAL_TOTAL + NET_VALUE_CURR while not approved | warning on SAVE `so_warn_credit` (net value of the saved lines) | l.3194, 3247 | medium (timing: at save instead of at each quantity) |
| W2 | PO_CUST_DATE WHEN-VALIDATE-ITEM: order date before the customer PO date → OK / Cancel alert (legacy text "تاريخ الحركة أكبر من تاريخ اليوم  ") | warning on CREATE / SAVE `so_warn_po_date` | l.1510-1537 | high |
| I1 | POST-QUERY / CHECK_MAST_STATUS displays: CREDIT_LIMIT, CRN_BAL_TOTAL (GET_CUSTOMER_BAL_ALL), CRN_DAY_TOTAL (GET_CUSTOMER_DAYS_ALL), DAY_NO, red / green state | info CREDIT_LIMIT, BALANCE, DAYS, DAY_NO, CREDIT_STATE ("تعديت حد الائتمان", "العميل متعدي فترة السماح" instead of the colours) | l.1093-1106, 6308-6325 | high |
| I2 | NET_VALUE_CURR / TAX_VALUE1_NET | info NET (lines net − header discounts + transport + VAT, in the order currency), TAX | labels | medium (Forms summary formula not in the evidence) |
| I3 | GET_PROPOSAL_INFO counters: items (item / lot), available (Σ basic qty ≤ lot balance today) minus over the sales limit, unavailable, over policy (discount ratios above the policy or bonus / extra bonus above the policy ratios per item; an error such as a zero quantity resets it to 0, as legacy), over ST_ITEM_UNIT.SALES_LIMIT | info ITEMS, AVAILABLE, UNAVAILABLE, DIFF_POLICY, SALES_LIMIT (the double-click filters VIEW_DETAIL_BLOCK are the grid filters) | l.5138-5284 | high |
| I4 | Line PRE-INSERT: MSG('سعر الصنف أقل من سعر الجملة', 0) when the price is below ST_ITEM_UNIT.WIDE_SALE_PRICE (ST_BASIC.LESS_WIDE_SALE_PRICE = 1 on this database; the other setting shows "يجب ان لا يقل سعر الصنف عن سعر الجملة", also without blocking) | info WIDE_PRICE: the item codes priced below the wholesale price, after each save | l.2531-2572 | high |
| I5 | SL_TRNS / INV display (invoice made from the order) | info INVOICE | ENABLE_DISABLE_BUTTONS | high |

Tests (`w3_sales\f2\t_f2.py`, ROLLBACK, plain and simulated APEX session of pages 60021 / 60011): S1-S17 — display conditions per state, close /
reopen and their refusals and texts (UPDATE_USER stamped by the page trigger in APEX), cancel refused when invoiced / with a purchase order
(plain only: the purchase row rules refuse the fixture in APEX) / approved, cancel and activate and their refusals, delete of an invoiced
order refused and of a free one accepted, credit warning (limit below balance; below balance + net when not approved; none when approved),
PO-date warning, counters against the legacy queries, invoice link, wholesale price, lot split (quantity over two lots, bonus split, line
that fits its lot, AUTO_DISC 0 not split, not enough stock refused, marks consumed, bypass released) and in APEX the page flow (row rule
picks the earliest lot, the split keeps the totals).

## Wave 3b (new generator keys)

Evidence: `ST\FMB\ST_SALES_ORDER_fmb.xml`.

| Change | Key | Evidence |
|---|---|---|
| Transaction type and store read-only after insert; store required | `TRNS_TYPE_CODE` / `STORE_CODE` `readonly_after_insert`, `STORE_CODE.required` | `UpdateAllowed="false"`, `STORE_CODE Required="true"` |
| Customer required | `CUSTOMER_CODE.required` | `Required="true"`; every document has them |
| Price-class list from `AR_ST_ITEM_CLASSES` (was the fixed-asset classes `AS_CLASS`, a wrong automatic list) | `CLASS_CODE.lov` | LOV AR_ST_CLASS_DET → RG AR_ST_CLASS `SELECT CLASS_CODE, DESC_A, DESC_E FROM AR_ST_ITEM_CLASSES` |
| Payment-terms list from `ST_PAYMENT_TERMS` | `PAYMENT_TYPE.lov` | LOV PAYMENT_LOV → `SELECT SERIAL, TYPE_NAME, TYPE_NAME_E FROM ST_PAYMENT_TERMS` |
| Per line: item name, lot number and lot expiry | `computed.ST_SALES_ORDER_DET.*` | display items ITEM_NAME / LOT_NUMBER / EXPIRE_DATE |
| Lot list of the line's item (lot id - lot number - expiry), refreshed when the item changes | `ITEM_CONFG_ID` `lov` + `cascade: ITEM_CODE` | legacy lot LOV (ITEM_CONFG_LOV / CONFG); the row rule still checks the lot and its balance |
| Button "ملف العملاء" opens the customers screen (CUSTOMER) | `links` | DET_C: `CALL_FORM(... 'CUSTOMER' ...)` with P_CODE = the customer; the APEX link opens the customers list (a link can fill page items only, not select a record by its key), so the customer is searched there |

Tested on the build copy: every list query and computed expression runs (`tmp\w3b_st\sqlcheck.py`, lot list with item 101010006); the cost / balance gates checked in an APEX session (`t_gates.py`, rolled back, session removed).
Still not reproduced: the balance / cost / totals per line (STORE_BALANCE, STORE_COST, LINE_TOTAL_CURR, NET_SALES_PRICE ...): their
program units are not in the evidence in a readable form for these lines; the document totals are in the info panel. Links to
ST_STORE_ITEM_VIEW / ST_SALES_ORDER_VIEW / SYS_DOCS: not screens of the application.

## Coverage
Reproduced: numbering, defaults, header / line rules and approvals (wave 2, APP_RULES_SA); make-invoice through the invoice page (I1,
ST_ISSUE_IO A1); B1-B5, W1-W2, I1-I5 above.

Deliberately not reproduced:
- Forms-only mechanics: enable / disable / visual attributes (colours of the credit fields → CREDIT_STATE text), per-line auto-commit,
  navigation keys, the approval worklist REQ_LIST / FILL_REQ_LIST (the list page filters), CHANGE_LANG, RESET_BTN / REFRESH (re-query).
- Buttons that only open other screens: ITEM_BAL (ST_STORE_ITEM_VIEW), SALES_VIEW_BTN (class ratios ST_SALES_ORDER_VIEW) - view forms
  that are not screens of the application; PROPOSAL_TERMS / TAX_SHOW / TAX_EXIT (go to an item). DET_C is a link since wave 3b.
- INV_TRNS / MAKE_INV on the order screen: the conversion is reproduced on the invoice page (typing the order reference creates the
  invoice with the order lines, wave 2); an order-page button would duplicate APP_RULES_SA logic owned by the invoice screen.
- Printing (another agent), SET_IP, WEBUTIL, dongle.
- `CHECK_CUSTOMER_STATUS` (stopped customer, document expiry within 60 days): never called in the form (dead code).
- Code for other installations: the `:GLOBAL.CUSTOMER_CODE = 'SDI'` rounding of LINE_TOTAL in DEVIDE_CONFGS (CUSTOMER_PAR is empty here).

Deviations (for review):
- DEVIDE_CONFGS, first lot holding the quantity but not all the bonus: the legacy put the same rest `(lot balance − quantity)` in BONUS and
  in EXTRA_BONUS (a copy / paste defect that creates an extra bonus and a negative extra bonus on the next line); APEX gives the rest to the
  bonus, then to the extra bonus. A new line with quantity 0 (bonus only) gets ratio 0 (the legacy divided by zero).
- The split runs after the save (the lines are visible once the page reloads) instead of while the quantity is typed.

## Open questions
1. Approval policy gate: the legacy query only fires in narrow cases (exception path); the intended rule is implemented — confirm.
2. Should approval / closing lock the order (legacy locks only after invoicing)?
3. INVOICE_NUMBER is always '10' (text MAX) — keep, number properly, or drop?
4. Close / cancel are now the legacy buttons (CLOSED read only). Confirm that the approval check boxes may stay editable (legacy buttons).
5. Should closed or cancelled orders be excluded from invoicing (implemented: yes, via the invoice validation)?
6. DEVIDE_CONFGS bonus split (see deviations) — confirm the corrected distribution.

## Tests (ROLLBACK)
`t_so.py` (sales-order part): 22 checks — header validations, defaults, auto-disc / manual lines, line errors, approval order and
stamps, frozen header discounts, last-line deletion, invoiced order (unapprove refused, lines locked).
