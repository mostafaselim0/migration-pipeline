# ST_RETURN_COST2 — مرتجعات المشتريات بدون فاتورة / Purchase returns without invoice (system 30, serial 7)

Deliverable: **screen correction + business rules** — `overrides/ST_RETURN_COST2.json` (MASTER_DETAIL + `rules`),
`APP_RULES_PR` (`app/db/21_rules_pr.sql`). Confidence: **medium-low** (.fmx only; the source of the line price is unknown).

## Purpose and tables
Return of goods to a supplier that is not tied to a purchase invoice: `ST_TRNS_MAST` (RET_TRNS_* empty) + `ST_TRNS_DET`, same
return types as ST_RETURN_COST (EFFECT 3, TRNS_TYPE 3/5). The lot (ITEM_CONFG_ID) is chosen among the lots with a positive
balance in the store (legacy LOV `... GET_BALANCE_CONFG(...) > 0`).

## Why a screen correction
The generated screen took ST_ITEM_UNIT as master and ST_TRNS_DET as its detail (wrong). Corrected to ST_TRNS_MAST +
ST_TRNS_DET with the same header / line columns as ST_RETURN_COST (without the invoice fields).

## Rules implemented
| # | Rule | Where | Evidence |
|---|------|-------|----------|
| 1 | List: return types, `NVL(DELETE_FLAG,0) = 0`, `RET_TRNS_TYPE_CODE IS NULL`, type password filter | `rules.where` | .fmx block WHERE |
| 2 | Defaults: lowest return type, its store, entry date | `defaults` | TRNS_TYPE LOV |
| 3 | Header checks as ST_RETURN_COST, and no invoice may be entered | validation `check_st_header('RETURN2')` | .fmx SQL / messages |
| 4 | Posted / cancelled / closed-period return read-only | validation `check_st_locked` | .fmx POST_FLAG count |
| 5 | Numbering (APPX max+1), DOC_NO per type and store, DELETE_FLAG 0, supplier derivations | ST_TRNS_MAST row rule (shared) | GET_NEXT_DOC_NO SQL |
| 6 | Line derivations (group, unit, ratios, discounts, basic qty, riyal price, cost flag), quantity > 0 | ST_TRNS_DET row rule (shared) | FACTOR / BASIC_QTY SQL |
| 7 | Lot must belong to the item; lot balance may not go negative (replaces the positive-balance LOV) | after-save `return_after_save('RETURN2')` → `check_stock` | CONFG LOV with GET_BALANCE_CONFG, "الرصيد" |
| 8 | Lines required (SAVE), max lines | after-save | "لا يمكن الحفظ بدون تفاصيل" |
| 9 | Delete refused when posted / closed; lines removed | after-save DELETE | as ST_RETURN_COST |

## Dropped
> Wave 3: several items below are implemented now - see the sections "Wave 3" and "Coverage" at the end of this file.
Dongle check, alerts, SET_IP, WEBUTIL, printing, GTIN capture, customer-specific code.

## Open questions for the key user
1. **Line price**: the legacy line price (UNIT_PRICE / UNIT_PRICE_CURR, display items) is filled by the form from a source not in
   the evidence (data: it equals the line cost in 60 % of the lines, never the lot's purchase price). In APEX UNIT_PRICE_CURR is
   left editable and UNIT_PRICE = UNIT_PRICE_CURR × rate. Confirm the rule (last cost? GET_UNIT_COST_CONFG? typed?).
   Wave 3: a line saved without price takes the cost of its lot configuration (see Wave 3).
2. ~~Physical delete~~ - wave 3: logical delete (DELETE_FLAG).
3. ~~No LOV of lots with balance~~ — wave 3b: the legacy lot list (see Wave 3b); the stock check still refuses a lot without enough balance.

## Wave 3 (soft delete, warnings, posting, VAT, price)

Installation code: `:GLOBAL.CUSTOMER_CODE` comes from `SELECT CUSTOMER_PAR.CUSTOMER_CODE FROM CUSTOMER_PAR` (Sysmenu.fmx ENTER_LOGIN); CUSTOMER_PAR has 0 rows on the build copy (and in the production discovery), so the code is NULL: `= 'SDI' / 'RSD' / ...` branches never run and `!= 'RSD'` / `NOT IN (...)` tests are NULL, i.e. skipped too, exactly as in the legacy PL/SQL.

| Legacy | APEX | Evidence / notes |
|---|---|---|
| KEY-DELREC: posted -> "لا يمكن حذف حركات مرحلة"; each line: running balance of the lot configuration without the line (GET_BALANCE_CONFG + UPDATE_NEXT_TRNS_CONFG) -> "الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها."; DELETE_FLAG := 1 (lines flagged by ST_TRNS_MAST_UP); lot of a lot-generated invoice released | `soft_delete` (check `app_act_pr.st_delete_check`, lines kept) + after-save DELETE `st_after_soft_delete` | data: 39 cancelled purchase documents, 179 / 179 lines flagged, no DELETE_USER / DATE; CLOSE_POSTED / CLOSE_ACC: posted, cancelled or closed-period documents cannot be deleted |
| SUPPLIER_CODE WHEN-VALIDATE-ITEM CUSTOM2_ALERT "الحركة بدون مورد" | `warnings` NO_SUPPLIER -> `st_supplier_warning` | new document without supplier or supplier removed (WVI of a never-touched item did not fire in Forms: small difference on new documents) |
| CHECK_DOC_NO, ST_BASIC.DOC_REPEAT = 3: "رقم المستند مكرر، هل تريد الإستمرار؟" | `warnings` DOC_REPEAT -> `st_doc_warning('RETURN2')` | types EFFECT 3; DOC_REPEAT is 1 on this site (warning inactive, = 2 refuses: wave-2 validation) |
| POST_BUT "ترحيل السند" / "إلغاء الترحيل" (ST_POSTING_CPOSTING for this document, POST_ON_LINE, FILTER 1 / 2, CHECK_FILE_PREV(45, 2)) | actions POST (GL, AP) / UNPOST (GL, AP, collected vouchers) -> `app_proc_st.post_cancel` for the document | the posting page's check boxes are the action parameters |
| GET_TAX_VALUE on the line WVIs (value LINE_TOTAL_RYAL), GET_TAX_VALUE_MAST on the header (discount share, transport tax) | `app_rules_pr.return_after_save` -> `st_lines_derive` (changed lines by flashback) | line formula verified on 517 / 517 return lines; header VAT 0 on all documents (no discount / transport) |
| line price of a return without invoice (display items UNIT_PRICE / UNIT_PRICE_CURR filled by the form) | a line saved without price takes its cost (UNIT_COST, else the average cost ST_TRNS_DET_C_IN recorded in ST_TRNS_DET_COST) x unit factor / rate, rounded 2 | medium confidence: data since 09/2025 mostly price = cost x factor (224 / 246 lines of 12/2025), earlier lines differ; typed prices are kept |

(No future-date alert: the text "تاريخ الحركة أكبر من تاريخ اليوم" is not in ST_RETURN_COST2.fmx.)

Tests (build copy, all rolled back, plain and inside a simulated APEX session of app 100 with the regenerated APPX_ triggers; scripts in the job folder `tmp\w3_purch`: t_vn.py, t_po.py, t_lot.py, t_st.py, t_quot.py, t_reg.py; static check chk.py): return without invoice saved without price -> price 1.93 = lot cost 1.9345 x factor 1 (t_st.py); shared delete / posting /
VAT code (t_st.py, t_reg.py).

## Wave 3b
Evidence: the CONFG LOV of the .fmx (`SELECT ITEM_CONFG_ID, GET_BALANCE_CONFG(store, group, item, lot, TRNS_DATE, DATE_SERIAL,
ITEM_SERIAL) BALANCE, EXPIRE_DATE, ..., LOT_NUMBER ... WHERE ... GET_BALANCE_CONFG(...) > 0 ORDER BY ITEM_CONFG_ID`).
* ITEM_CONFG_ID: that list — lots of the line's item with a positive balance in the return's store before the line, with expiry, lot
  number and balance in the display (cascade ITEM_CODE / GROUP_CODE / TRNS_TYPE_CODE / TRNS_SERIAL / ITEM_SERIAL). Run on a real
  purchase line: 0 lots before the first receipt line, 2 lots (26 / 678) for a new line.
* Legacy lists: return types (3/3, 3/5, rights), stores (store-chart rights), suppliers (range), items (active with a basic unit, group
  rights), units of the item; check boxes POST_FLAG / SUPP_POST_FLAG / CUST_POST_FLAG; computed ITEM_NAME_A and LOT_EXPIRE.
* Check: `check_forms.py ST_RETURN_COST2`.

## Coverage
Reproduced: wave-2 rules plus logical delete, continue? alerts, posting from the document, VAT and the default line price (wave 3); lots with
balance, legacy lists, check boxes, item name and lot expiry (wave 3b).

Not reproduced, with the reason: GTIN capture (RSD), CONV_FROM window (Forms helper), printing, dongle, alerts, customer branches.
Open: confirm the default price rule (cost of the lot configuration) with the key user.
