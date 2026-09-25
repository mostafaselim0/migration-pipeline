# ARCRTRN_ST - حركات عملاء دائنة - أنظمة أخرى / Other Systems Credit Transactions

- Registry: system 4 serial 15 (FILES_MENU.ARCRTRN_ST, `open_form('arcrtrn_st')`). APEX pages 30020 / 30021 / 30022.
- **Deliverable: (a) screen correction + business rules**: `app\legacy\overrides\ARCRTRN_ST.json` = explicit `MASTER_DETAIL` (AR_MAINTRNS +
  payment lines AR_SUBTRNS) because the generated payment grid had no BILL_ID2 (unlabelled item) - for stock invoices BILL_ID1 is the series and
  BILL_ID2 the invoice number, so a payment line cannot be matched without it. Rules in `APP_RULES_AR`.
- **Confidence: medium** (.fmx + labels only; LINK_FLAG value inferred as for ARDBTRN_ST).

## What the screen is

Older variant of ARCRTRN for credit transactions coming from other systems: WHERE (fmx)
`TRNS_ID IN (SELECT ID FROM AR_TRNSTYPE WHERE EFFECT = 1) AND TRNS_SERIAL_TOT IS NULL AND AR_MAINTRNS.LINK_FLAG = :PARAMETER.LINK_FLAG` + group
filters; today 265 sales returns 301-303 (LINK_FLAG 1, from the stock posting, all posted). Payment lines reference invoices through BILL_LOV
(`... AR_MAINTRNS.CUSTOMER_ID = :AR_MAINTRNS.CUSTOMER_ID AND NVL(AR_SUBTRNS.RESIDUAL_VALUE,0) != 0 ...`).

## Rules implemented

| Kind | Rule | Evidence (.fmx) | APEX |
|------|------|-----------------|------|
| where | `TRNS_ID in (EFFECT = 1) and TRNS_SERIAL_TOT is null and LINK_FLAG = 1` + group filters | default WHERE | `where` |
| type default / validation | TRNSTYPE LOV `effect = 1` + AR_TRNSTYPE_PASSWORD | record group | default `default_type('ARCRTRN_ST')` (201); `check_header` |
| numbering | TRNS_SERIAL max+1 (fmx has the per-TRNS_ID query; the shared APEX rule numbers credit types per TRNS_ID + area + branch like ARCRTRN - both unique); TRNS_SERIAL_TOTAL max+1 (`SELECT NVL(MAX(TRNS_SERIAL_TOTAL),0)+1 FROM AR_MAINTRNS`); DOC_NO typed | fmx SQL | key_expr, `after_save_credit('ARCRTRN_ST')` |
| derived | category / salesman of the customer (`SELECT MIN(CTGRY_CODE), MIN(SALESMAN_CODE) FROM AR_CUST_SALESMAN WHERE CUSTOMER_CODE = :b1`), areas, LINK_FLAG 1 on new documents, PAY_METHOD 2, CASH_FLAG 2, RESIDUAL = TOTAL - allocated, NET / DISC | fmx SQL | key_expr + after_save |
| payment lines typed in the grid | BILL_ID1 / BILL_ID2 must be an invoice of the same customer ('ارقام الفواتير التى تم إدخالها لا تخص العميل هذا العميل'); value > 0; discount <= value; value <= open value of the invoice ('القيمة المتبقية بالفاتورة أصغر من القيمة المدخلة للسداد'); total of lines <= payment ('قيمة الفواتير المسددة يجب أن تكون أقل من القيمة الكلية للسداد'); the line gets the invoice keys (INV_*), store, net, pay date, description 'سداد كامل/باقى/جزء من الفاتورة (...) بسند قبض رقم(...)'; invoice residual refreshed | fmx SQL / texts (PRE-INSERT of AR_SUBTRNS) | `after_save_credit` |
| payment lines deleted | invoice residual restored | fmx `UPDATE AR_SUBTRNS SET RESIDUAL_VALUE = NVL(RESIDUAL_VALUE,0) + NVL(:b1,0)` | `snapshot_alloc` + `after_save_credit` |
| validations | customer / dates / rate as ARCRTRN; posted / paid documents read-only ('الحركة الحالية مرحلة و لا يمكن حذفها') | fmx texts | `check_header`, `check_posted` |

## Wave 3 additions (evidence: compiled `ASCON\AR\FMB\ARCRTRN_ST.fmx` SQL, bind lists and texts)

| Kind | Rule | Evidence (.fmx) | APEX |
|------|------|-----------------|------|
| pay method | PAY_METHOD required, 1 / 2 / 4 (list PAY_METHOD_LIST); CREATE_AUTH_RECORD builds the list from AR_PAYTYP_PASSWORD of the group (OLDER_NEW -> 1, SELECTED -> 2, PAY_WITHOUT_ADJUST -> 4): a method not granted is refused ('طريقة الدفع غير مسموحة لمجموعتك'); method 1 spreads the payment over the open invoices of the customer **and category** (stored RESIDUAL_VALUE <> 0), method 4 keeps no allocation, method 2 needs pay details ('يجب ادخال تفاصيل سداد') | `SELECT NVL(OLDER_NEW,0), NVL(SELECTED,0), NVL(PAY_WITHOUT_ADJUST,0), NVL(PRE_PAY,0) FROM AR_PAYTYP_PASSWORD WHERE PASSWORD_NUMBER = :b1`, CUST_INV cursor with CTGRY_CODE, texts | PAY_METHOD column (default 2), `check_pay_method('ARCRTRN_ST')`, `after_save_credit` |
| invoice picker | BILL LOV: invoices of the customer and category with stored RESIDUAL_VALUE <> 0; PRE-INSERT checks: exactly one invoice of customer + category with the bill pair and open residual, invoice date not after the payment ('تاريخ الفاتورة لا يمكن ان يكون اكبر من تاريخ الحركة'), stored residual >= value, nets <= payment | BILL record group, PRE-INSERT SQL / texts | action **ALLOC_INVOICE** (screen `ARCRTRN_ST`), typed lines in `after_save_credit` |
| discount periods | CALCULATE_DISCOUNT (customer / class / type / category periods) on the **invoice total** (`:INV_TOTAL_VALUE` in the bind list), capped by DSCNT_VALUE; typed discount kept | CALCULATE_DISCOUNT binds and cursors | `calc_discount` (base = invoice total) |
| running balances | CUSTOMER.CRN_BAL_TOTAL and AR_CUST_SALESMAN.CRN_BAL_TOTAL (customer, salesman, category): - TOTAL_VALUE when the payment is inserted (POST-INSERT); - DISC_VALUE of each allocation (AR_SUBTRNS PRE-INSERT); + DISC_VALUE of a deleted allocation (DELETE_DETAIL_EFFECT); + TOTAL_VALUE when the payment is deleted (KEY-DELREC) | `UPDATE CUSTOMER SET CRN_BAL_TOTAL = NVL(CRN_BAL_TOTAL,0) - (NVL(:b1,0))` ... | `after_save_credit`, `insert_alloc`, delete hooks |
| history copies | INSERT_AR_OLD_TRNS: before a payment is deleted (and after one of its lines is deleted), the payment and its lines are copied to AR_MAINTRNS_OLD / AR_SUBTRNS_OLD with SERIAL = max+1, once (count on keys, date, category, salesman, customer) | INSERT_AR_OLD_TRNS SQL | delete hook (before the lines of the document are deleted; after a single line delete) |
| PLUS_INV_NO_FLAG | ' ف(b2/b1)' / ' Bill(b2/b1)' appended to the description for each allocated invoice | PRE-INSERT | `insert_alloc` / typed lines |
| header checks | DOC_NO > 0 ('رقم المستند يجب ان يكون اكبر من الصفر'); rate <> 0 ('معامل التحويل لا يمكن ان يساوي الصفر') and not changed once lines exist ('لا يمكن تغير معامل التحويل ويوجد بيانات بالفاتورة'); POST_SYSTEM from SYS_SYSTEMS except 0 / 99 (POST_SYSTEM_LIST) | texts, record group | `check_header_st` |
| delete | lines of a posted payment not deletable ('الحركة الحالية مرحلة و لا يمكن حذفها'); deleted allocations give the invoice its value back | PRE-DELETE, DELETE_DETAIL_EFFECT | delete hooks |
| info | customer balance, system name, allocated total / discount / open value | display items | `info` |

## Tests

Wave 2 (suite 66/66): default 201; return 301 accepted; typed payment line linked to the invoice, residual 600 -> 350, description, LINK_FLAG 1;
value above the residual refused; unknown invoice pair refused.

Wave 3 (`tmp\w3_argl\t_ar.py`, APEX session on page 30021, rolled back): group 101 with a temporary AR_PAYTYP_PASSWORD row (1 and 4 granted):
method 2 refused, 1 accepted; new return 301 of 500 -> CUSTOMER and AR_CUST_SALESMAN CRN_BAL_TOTAL - 500; typed line 300 on invoice 8264
(category 1) linked, no period discount, payment residual 200; DOC_NO 0, rate change with lines, unknown system 13 refused, system 3 accepted;
document delete (request DELETE) -> one AR_MAINTRNS_OLD copy with its line, CRN_BAL_TOTAL back to its value, invoice residual back.

## Wave 3b (new generator keys; evidence: `.fmx` record groups / SQL and GN_FORM_ITEM item types of `evidence\ARCRTRN_ST.md`)

| Legacy | Evidence | APEX |
|--------|----------|------|
| PAY_METHOD shown as the list PAY_METHOD_LIST "طريقة الدفع" (1 تنازلي على الفواتير / 2 شاشة مساعدة للفواتير / 4 مبلغ دائن لعميل), required | [LS] item, CREATE_AUTH_RECORD, 'يجب ادخال طريقة سداد' | static select list + `required` (default 2 kept; `check_pay_method` still refuses a method not granted) |
| POST_SYSTEM shown as the list POST_SYSTEM_LIST "النظام" (SYS_SYSTEMS except 0 / 99) | [LS] item, record group | `lov` (select list) |
| TRNS_ID list (`ar_trnstype WHERE effect = 1` + group); CTGRY_CODE, SALESMAN_ID (of the customer and category), accounts, COST_CODE1 with names | TRNSTYPE / CATGRY / SALESMAN / CUST_ACC / DISC_ACC / COST LOVs | `lov` (salesman: `cascade` on CUSTOMER_ID / CTGRY_CODE) |
| Area / branch names | [D] MAINAREA_DESC / SUBAREA_DESC | computed master columns |
| Payment lines: invoice date, invoice total, open value of the invoice (stored RESIDUAL_VALUE, as this form used it), paid value in local currency | [D] INV_TRNS_DATE, INV_TOTAL_VALUE, INV_RESIDUAL_VALUE, TOTAL_VALUE_RIYALH | computed grid columns |
| AR_SUBTRNS.POST_FLAG check box "تم الترحيل" | [C] item | `widget: CHECK` (1 / 0, read-only) |

No UpdateAllowed / Required / block flags are readable from the .fmx: not changed. SQL of every list / computed column run on the build copy
(`tmp\w3b_gl\check.py`, problems 0).

## Coverage

Reproduced: tables above. Not reproduced, with reason:

- Posting from the screen (INSERT INTO AC_YEARLY_TRN ... POST_SYSTEM 4, AR_POST_MSG): LINK_FLAG = 1 documents are posted by the stock system;
  the call site in this form could not be identified from the compiled form - question 2.
- VALIDATE_DATE (AC_BASIC.MIN_DATE check): present in the .fmx, call site not identifiable - not applied.
- Account link block (not placed), printing, protection / prompts / SET_IP. No cheque-number warning (the text is not in this form).
- A group without any AR_PAYTYP_PASSWORD row keeps all methods (the list content in that case is not visible in the .fmx; the table is empty).
- Type-dependent visibility of the accounts / cost centres (AR_TRNSTYPE settings read by the form): the fields are always shown.
- (Resolved in wave 3b: PAY_METHOD and POST_SYSTEM are now the legacy lists.)

## Open questions

1. Confirm :PARAMETER.LINK_FLAG = 1; should new documents be created here (they are not posted by the APEX AR posting)?
2. Returns 301-303 are generated by the stock posting and posted: is this screen still needed for anything but viewing / allocating them?
3. AR_PAYTYP_PASSWORD is empty: which methods may a group without a row use?
4. CRN_BAL_TOTAL is also recalculated by MOB_DAILY_UPDATE and maintained by the stock posting; confirm this screen must still update it.
