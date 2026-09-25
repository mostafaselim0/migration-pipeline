# ST_RETURN_COST — مرتجع المشتريات / Purchase returns per invoice (system 30, serial 6)

Deliverable: **screen correction + business rules** — `overrides/ST_RETURN_COST.json` (MASTER_DETAIL + `rules`),
`APP_RULES_PR` (`app/db/21_rules_pr.sql`). Confidence: **medium** (.fmx only: rules rebuilt from the compiled SQL, the Arabic
messages and the data; prices-from-invoice and quantity / expense limits verified on the data).

## Purpose and tables
Return of goods to the supplier against a purchase invoice: `ST_TRNS_MAST` (RET_TRNS_TYPE_CODE / RET_TRNS_SERIAL = the invoice)
+ `ST_TRNS_DET`. Types `EFFECT = 3 AND TRNS_TYPE IN (3,5)` (10901, 10904, 30901, 222; SUPPLIER_TRNS_CODE 205).
Posting to GL / AP is the separate ST_POSTING process.

## Why a screen correction
The generated screen (labels + .fmx) had the right tables but no way to enter the invoice serial (RET_TRNS_SERIAL has no
GN_FORM_ITEM label) and forced the trigger-filled DATE_SERIAL / DELETE_FLAG as mandatory fields. The override keeps the same
columns (reordered header), adds RET_TRNS_SERIAL, hides DATE_SERIAL / DELETE_FLAG / BASIC_QTY / COST_FLAG.

## Rules implemented
| # | Rule | Where | Evidence |
|---|------|-------|----------|
| 1 | List: return types, `DELETE_FLAG = 0`, `RET_TRNS_TYPE_CODE IS NOT NULL`, type password filter | `rules.where` | .fmx block WHERE (`... AND DELETE_FLAG=0 ... AND RET_TRNS_TYPE_CODE IS NOT NULL`) |
| 2 | Default type = lowest return type (222), store = the type's store, entry date today | `defaults` | TRNS_TYPE LOV (ORDER BY TRNS_TYPE_CODE) |
| 3 | Type / store / date (ST_BASIC.MIN_DATE, AC_BASIC.CLOSE_DATE) / rate / supplier (active, not stopped) / doc-no repeat (DOC_REPEAT = 2) / fixed fields once lines exist | validation `check_st_header('RETURN')` | .fmx SQL + messages ("الحد الأدنى لتاريخ الحركة", "يجب ان يكون تاريخ القيد بعد تاريخ اخر اقفال", "معامل تحويل الريال يجب ان يكون ب 1", "لا يمكن تكرار المستند") |
| 4 | Invoice mandatory, must be a non-deleted purchase invoice of the same store, not dated after the return, same supplier; cannot change once lines exist | same | RETURN_INV_RG (`... AND ST_TRNS_MAST.STORE_CODE = :STORE_CODE AND TRNS_DATE <= :TRNS_DATE`) |
| 5 | Posted / cancelled / closed-period return is read-only | validation `check_st_locked` (SAVE) | .fmx `SELECT COUNT(1) ... POST_FLAG / SUPP_POST_FLAG / CUST_POST_FLAG = 1`, "لا يمكن تعديل هذه الحركة" |
| 6 | Numbering max+1 per type (generated APPX key); DOC_NO = next number per type and store (GET_NEXT_DOC_NO: store digits ‖ 000001 first) when empty; INVOICE_NO = the invoice's INVOICE_NO; DELETE_FLAG 0; supplier derivations as ST_RECEIVE_COST | ST_TRNS_MAST row rule | .fmx SQL (`SELECT NVL(MAX(DOC_NO),0)+1 ... STORE_CODE`), data (DOC_NO 1001000001…, INVOICE_NO of the invoice on all rows) |
| 7 | Line derivations: group, unit, bonus / extra bonus ratios, discount chain, BASIC_QTY, UNIT_PRICE, COST_FLAG; quantity + bonus > 0 | ST_TRNS_DET row rule | .fmx FACTOR / BASIC_QTY SQL |
| 8 | The returned lot (group, item, ITEM_CONFG_ID) must be on the invoice; price and discounts copied from the invoice line when empty | after-save `return_after_save` | RETURN LOV (`... FROM ST_ITEM I, ST_TRNS_DET D, ST_ITEM_CONFG C WHERE D.TRNS_TYPE_CODE = :RET_TRNS_TYPE_CODE ...`) — data: 71/71 lines carry the invoice price and discount |
| 9 | Quantities returned by all returns of the invoice ≤ purchased (quantity and free quantity, per item and lot) | same | .fmx SQL + "إجمالى الكمية المرتجعة اكبر من اجمالى الكمية المشتراه - الكمية =" |
| 10 | Expenses and discount of all returns of the invoice ≤ the invoice's | same | .fmx SQL `SUM(NVL(FREIGHT_VAL,0)) ... RET_TRNS_*` + the ten "... أكبر من ... فاتورة المشتريات!!!" messages |
| 11 | Lines required (SAVE), max lines, lot stock not negative | same → `check_stock` | "لا يمكن الحفظ بدون تفاصيل" (ST_RETURN_COST2 texts), UPDATE_NEXT_TRNS_CONFG |
| 12 | Delete: refused when posted / closed period; lines removed (cost reversal) | after-save DELETE `st_after_delete` | ON-CHECK-DELETE-MASTER pattern of the sibling form |

## Dropped
> Wave 3: several items below are implemented now - see the sections "Wave 3" and "Coverage" at the end of this file.
Dongle check, alerts / confirmations, SET_IP, WEBUTIL, printing (PU_INVOICE_RET_SDI), GTIN serial capture (RSD_TRNS_DET),
customer-specific code.

## Deviations / open questions
* ~~Physical delete~~ - wave 3: logical delete (DELETE_FLAG), lines flagged by ST_TRNS_MAST_UP.
* Currency / rate of the return are not forced to the invoice's (not evidenced).
* RET_TRNS_SERIAL shows with a generated English label (no GN_FORM_ITEM entry).
* ~~No LOV on the invoice / lot fields~~ — wave 3b: cascading lists (see Wave 3b).
* ~~VAT not computed~~ - wave 3: line / header VAT (TAX_LIB_NEW). Header supplier expenses entered in riyal directly.

## Tests
Header checks (valid invoice, missing invoice, other store), return of 4 of 10 accepted with the invoice price copied, 12 of 10
refused (quantity message), freight above the invoice's refused, negative-stock refusal (all rolled back).

## Wave 3 (soft delete, warnings, posting, VAT)

Installation code: `:GLOBAL.CUSTOMER_CODE` comes from `SELECT CUSTOMER_PAR.CUSTOMER_CODE FROM CUSTOMER_PAR` (Sysmenu.fmx ENTER_LOGIN); CUSTOMER_PAR has 0 rows on the build copy (and in the production discovery), so the code is NULL: `= 'SDI' / 'RSD' / ...` branches never run and `!= 'RSD'` / `NOT IN (...)` tests are NULL, i.e. skipped too, exactly as in the legacy PL/SQL.

| Legacy | APEX | Evidence / notes |
|---|---|---|
| KEY-DELREC: posted -> "لا يمكن حذف حركات مرحلة"; each line: running balance of the lot configuration without the line (GET_BALANCE_CONFG + UPDATE_NEXT_TRNS_CONFG) -> "الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها."; DELETE_FLAG := 1 (lines flagged by ST_TRNS_MAST_UP); lot of a lot-generated invoice released | `soft_delete` (check `app_act_pr.st_delete_check`, lines kept) + after-save DELETE `st_after_soft_delete` | data: 39 cancelled purchase documents, 179 / 179 lines flagged, no DELETE_USER / DATE; CLOSE_POSTED / CLOSE_ACC: posted, cancelled or closed-period documents cannot be deleted |
| TRNS_DATE WHEN-VALIDATE-ITEM CUSTOM2_ALERT "تاريخ الحركة أكبر من تاريخ اليوم" (continue / cancel) | `warnings` FUTURE_DATE -> `st_date_warning` | new document or changed date |
| SUPPLIER_CODE WHEN-VALIDATE-ITEM CUSTOM2_ALERT "الحركة بدون مورد" | `warnings` NO_SUPPLIER -> `st_supplier_warning` | new document without supplier or supplier removed (WVI of a never-touched item did not fire in Forms: small difference on new documents) |
| CHECK_DOC_NO, ST_BASIC.DOC_REPEAT = 3: "رقم المستند مكرر، هل تريد الإستمرار؟" | `warnings` DOC_REPEAT -> `st_doc_warning('RETURN')` | types EFFECT 3; DOC_REPEAT is 1 on this site (warning inactive, = 2 refuses: wave-2 validation) |
| POST_BUT "ترحيل السند" / "إلغاء الترحيل" (ST_POSTING_CPOSTING for this document, POST_ON_LINE, FILTER 1 / 2, CHECK_FILE_PREV(45, 2)) | actions POST (GL, AP) / UNPOST (GL, AP, collected vouchers) -> `app_proc_st.post_cancel` for the document | the posting page's check boxes are the action parameters |
| GET_TAX_VALUE on the line WVIs (value LINE_TOTAL_RYAL), GET_TAX_VALUE_MAST on the header (discount share, transport tax) | `app_rules_pr.return_after_save` -> `st_lines_derive` (changed lines by flashback) | line formula verified on 517 / 517 return lines; header VAT 0 on all documents (no discount / transport) |

Return currency: kept as in wave 2 (supplier currency, AC_CURRENCY rate when left at local currency). The only foreign-currency return
(222/2) has the same rate on the invoice and in AC_CURRENCY (4.5), so the data cannot tell whether the legacy copied the invoice rate -
question for the business.

Tests (build copy, all rolled back, plain and inside a simulated APEX session of app 100 with the regenerated APPX_ triggers; scripts in the job folder `tmp\w3_purch`: t_vn.py, t_po.py, t_lot.py, t_st.py, t_quot.py, t_reg.py; static check chk.py): DOC_REPEAT 3 warning on return types; posting / delete code shared with ST_RECEIVE_COST (t_st.py); 80 documents saved unchanged
(receipts and returns) keep VAT and prices (t_reg.py).

## Wave 3b
Evidence: the LOV queries of the .fmx (evidence pack): invoice LOV (`SELECT INVOICE_NO, SUPPLIER_REF, TRNS_DATE, TRNS_TYPE_CODE,
TRNS_SERIAL FROM ST_TRNS_MAST ... EFFECT 1 / TRNS_TYPE 1 ... STORE_CODE = :STORE_CODE ... SUPPLIER_CODE`) and RETURN LOV (items and lots of
`D.TRNS_TYPE_CODE = :RET_TRNS_TYPE_CODE AND D.TRNS_SERIAL = :RET_TRNS_SERIAL`).
* The invoice: a list returns one value, so the legacy invoice LOV is split — RET_TRNS_TYPE_CODE from the purchase-invoice types (1/1),
  RET_TRNS_SERIAL "مسلسل فاتورة المشتريات" from the invoices of that type in the return's store (and of its supplier when given), with
  invoice number, date and supplier reference in the display (cascade RET_TRNS_TYPE_CODE / STORE_CODE / SUPPLIER_CODE). The legacy
  "invoice date <= return date" filter is left to the header check (date format of the page item).
* Lines: ITEM_CODE from the items of the returned invoice, ITEM_CONFG_ID from that invoice's lots of the item (expiry, lot number,
  invoiced quantity in the display) — the grid reads the returned invoice through the line's keys (cascade TRNS_TYPE_CODE /
  TRNS_SERIAL / ITEM_CODE); UNIT_CODE from the units of the item.
* Legacy lists on the header: return types (3/3, 3/5, type rights), stores (store-chart rights), suppliers (range); check boxes
  POST_FLAG / SUPP_POST_FLAG / CUST_POST_FLAG (read-only); computed ITEM_NAME_A and LOT_EXPIRE on the lines.
* Check: `check_forms.py ST_RETURN_COST`; cascades run on return 10901/2 (invoice 10801/17): 69 invoices of the store / supplier incl.
  the returned one, 1 item, 2 lots of item 101011600.

## Coverage
Reproduced: wave-2 rules plus logical delete, continue? alerts, posting from the document and VAT (wave 3); invoice / item / lot
lists of the returned invoice, legacy lists, check boxes, item name and lot expiry (wave 3b).

Not reproduced, with the reason: GTIN serial capture (RSD_TRNS_DET, RSD installation only), CONV_FROM unit conversion window (Forms
helper), printing (ENTRY_PRINT, PU_INVOICE_RET_SDI), dongle, alerts, customer branches.
