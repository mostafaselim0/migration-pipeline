# ARCRTRN - حركات العملاء الدائنة / Credit Customer's Transactions (collections, credit settlements)

- Registry: system 4. APEX list page 30040, document page 30041, print 30042.
- **Deliverable: (a) generated screen kept (`"pattern": "AUTO"`) + business rules + action buttons**
  - Override: `app\legacy\overrides\ARCRTRN.json`; PL/SQL: `APP_RULES_AR` (`app\db\21_rules_ar.sql`), buttons `APP_ACT_AR`
    (`app\db\23_act_ar.sql`), posting `APP_PROC_AR` (`20_proc_ar.sql`). All VALID.
- **Confidence: medium-high** - header rules, numbering, totals, pay methods, receipt books and the allocation algorithm come from the .fmb
  (`AR\FMB\arcrtrn_fmb.xml`) and match the 404 existing collections (descriptions, pay dates, residuals, book numbers).
- Installation branch: `CUSTOMER_PAR` is empty, so `:GLOBAL.CUSTOMER_CODE` is NULL and every `= 'ZEB'` / `<> 'ZEB'` test is false.

## Rules implemented (waves 2 and 3)

| Kind | Rule | Evidence | APEX |
|------|------|----------|------|
| where | `TRNS_ID in (EFFECT = 1 and TRNS_TYPE not in (5,6) and NVL(TOT_TRNS_FLAG,0) = 0) and TRNS_SERIAL_TOT is null and NVL(LINK_FLAG,0) = 0` + group filters | block WHERE | `where` |
| type default / validation | TRNSTYPE LOV: EFFECT = 1, NVL(TOT_TRNS_FLAG,0) = 0, TRNS_TYPE in (3,4) + AR_TRNSTYPE_PASSWORD; not updatable | record group TRNSTYPE | default `default_type('ARCRTRN')`; `check_header` |
| numbering | TRNS_SERIAL = max+1 per TRNS_ID + MAINAREA_ID + SUBAREA_ID; TRNS_SERIAL_TOTAL global max+1; DOC_NO = max+1 of own documents of the same TRNS_TYPE | PRE-INSERT | key_expr, after_save |
| derived | areas, CTGRY_CODE, SALESMAN_ID of the customer | CUSTOMER_ID WVI | key_expr |
| derived | TOTAL_VALUE = INV_VALUE (+ TAX_VALUE1 when T_TAX_FLAG1 in (1,3)); DISC_VAL_RATIO = DISC_VAL * 100 / (TOTAL + DISC_VAL); CASH_FLAG 2, POST/PAY_FLAG 0 | GET_TAX, DISC_VAL WVI, WHEN-CREATE-RECORD | `after_save_credit` |
| derived (w3) | DESCRIPTION_A/E = type description `' - '` customer name when left empty (legacy: set on every customer validation; 384 of 404 collections carry it) | CUSTOMER_ID WVI | `after_save_credit` |
| derived (w3) | RESIDUAL_VALUE = TOTAL - sum of the allocated nets (PRE-INSERT: RESIDUAL := TOTAL, each allocation `RESIDUAL - NET_VALUE`); DISC_VALUE = allocated totals - nets; NET_VALUE = allocated nets (TOTAL without lines) | AR_MAINTRNS / AR_SUBTRNS PRE-INSERT | `after_save_credit` |
| validations | customer / dates / salesman / rate rules; type and customer (with lines) not changeable | CUSTOMER_ID, TRNS_DATE, SALESMAN_ID, CURRENCY_RATE WVI | `check_header` |
| validations (w3) | CHECK_DATE (TRANSLATE.pll) on TRNS_DATE and ACC_POST_DATE: not after today ('تاريخ الحركة أكبر من تاريخ اليوم'), not before MIN(AC_BASIC.MIN_DATE) ('الحد الأدنى لتاريخ الحركة هو dd/mm/yyyy') | TRNS_DATE / ACC_POST_DATE WVI | `check_dates` |
| validations (w3) | PAY_METHOD required ('يجب ادخال طريقة سداد'), one of 1 تنازلي على الفواتير / 2 شاشة مساعدة للفواتير / 4 مبلغ دائن لعميل (default 2, TRNS_ID WVI); INV_VALUE not updatable on a saved payment of method 1 / 2 | PRE-INSERT, PAY_METHOD_LIST WVI, CREATE_AUTH_RECORD labels | `check_pay_method`; PAY_METHOD shown (add_columns) |
| validations (w3) | receipt books (collections TRNS_TYPE 3 of types with SALESMAN_FLAG = 1): BOOK_SERIAL required (ENABLE_BOOK_NO), 'لايمكن الحفظ بدون سند', number inside the book range (' رقم المستند خارج النطاق '), not cancelled in AR_SALESMAN_BOOKS_DET ('رقم السند ملغي'), not used by another collection or salesman cheque of the salesman ('رقم السند مكرر'; PRE-UPDATE excludes the document itself) | PRE-INSERT / PRE-UPDATE, BOOK_NO WVI, BOOK_LOV | `check_book`; BOOK_SERIAL / BOOK_NO shown |
| validations (w3) | collections: the customer's salesman must have an open receipt book (GET_BOOK_NO: STOP_FLAG 0, BOOK_FINSH 0, BOOK_TYPE 1, numbers left) - 'لا يتم ربط اي دفاتر علي هذا المندوب' | CUSTOMER_ID WVI -> GET_BOOK_NO / GET_DOC_NO | `check_header` |
| warnings (w3) | remaining numbers of the book <= SALESMAN.AR_BOOKS_NOTIF (<> 0): 'تذكير بعدد ارقام المستندات المتبقية بالدفتر = n'; cheque number already used by the same type: 'رقم الشيك مكرر' | BOOK_NO / CHEQUE_NUMBER WVI (MSG ...,0) | `warn_book`, `warn_cheque` |
| validations | posted / paid transaction read-only | CLOSE_MAIN_POSTED | `check_posted` (SAVE) |
| allocation (w3) | **PAY_METHOD 1**: when the payment has no lines, TOTAL + DISC_VAL (TOTAL_TRNS_VALUE) is spread over the customer's open invoices (TOTAL - AR_SUBTRNS_PAYED_VALUE <> 0) ordered by invoice date, BILL_ID1, BILL_ID2; line value = min(open, remaining), discount = ROUND(DISC_VAL_RATIO * value / 100, 2) with the remaining-discount correction; descriptions 'سداد كامل / باقى / جزء من الفاتورة (b2/b1) بسند قبض رقم(doc) بقيمة خصم(d)' (+ English); INV_PAY_DATE = later of invoice and payment dates | AR_SUBTRNS WHEN-NEW-BLOCK-INSTANCE (EXPAND_FLAG) | `after_save_credit` -> `auto_allocate` |
| allocation (w3) | **PAY_METHOD 2**: invoice picker BILL_LOV (open bills of the customer not yet in the payment): default value = min(TRNS_TOTAL_DIFF, invoice open value); discount = CALCULATE_DISCOUNT (customer -> customer class -> type -> category period discount, % of the value, capped by DSCNT_VALUE; days = payment date - INV_DATE, negative = 1), replaced by the header ratio when DISC_VAL <> 0, or typed; checks: one invoice of the customer ('ارقام الفواتير التى تم إدخالها لا تخص العميل هذا العميل'), 'فاتورة مكررة', discount <= value, value <= invoice open value, nets <= payment; PLUS_INV_NO_FLAG appends ' ف(b2/b1)' / ' Bill(b2/b1)' to the description | BILL_ID1 / TOTAL_VALUE / DISC_VALUE WVI, CALCULATE_DISCOUNT, AR_SUBTRNS PRE-INSERT, CHECK_REPEAT | action **ALLOC_INVOICE** -> `app_act_ar.alloc_invoice` -> `add_allocation` |
| allocation (w3) | KEY-COMMIT: methods 1 / 2 must allocate the whole payment (ROUND(TOTAL - allocated nets) = 0, 'إجمالي السداد لا يساوي إجمالي الحركة'); method 2 needs pay details ('يجب ادخال تفاصيل سداد'); **PAY_METHOD 4** keeps no allocation (lines deleted, invoices restored) and no header discount | KEY-COMMIT, PRE-INSERT / PRE-UPDATE, SET_DISC_ENABLED | `after_save_credit` (method 1 on CREATE and SAVE, method 2 on SAVE because APEX creates the header first) |
| allocation lines deleted | the invoice gets the value back (DELETE_DETAIL_EFFECT); posted payment: 'الحركة الحالية مرحلة و لا يمكن حذفها' | AR_SUBTRNS PRE/POST-DELETE | delete hook `APP_RULES_AR_SUB_BD` (+ `snapshot_alloc` / `after_save_credit`) |
| document delete (w3) | posted / paid payment not deletable; lines deleted first give the invoices their value back | KEY-DELREC, CLOSE_MAIN_POSTED | hooks `APP_RULES_AR_SUB_BD` / `APP_RULES_AR_MAST_BD` (request DELETE of page 30041) |
| button ACTIVE (w3) | toggles AR_SUBTRNS.WITHOUT_COMM_FLAG of a line, also on posted payments | AR_SUBTRNS.ACTIVE | action **TOGGLE_COMM**; WITHOUT_COMM_FLAG shown read-only in the grid |
| buttons POST / CANCEL_POST (w3) | POST (visible when not posted): ARACUPDT with POST_ON_LINE for this transaction ('لابد من إلغاء الترحيل اولا'); CANCEL_POST (visible when posted and CASH_FLAG = 2 or systems 13/15 absent): AR_CPOSTING for this transaction ('هذه الحركة غير مرحلة') | POST / CANCEL_POST WHEN-BUTTON-PRESSED, SET_PAY_METHOD | actions **POST** / **CANCEL_POST** -> `app_proc_ar.post_to_gl` / `cancel_gl_posting` with from = to |
| info (w3) | CRN_BAL (GET_CUSTOMER_BAL today, debit / credit), TRNS_TOTAL / DISC / NET / DIFF / TOTAL_DIFF, TRNS_SUM_VALUE (account lines), total and residual in local currency, book range, creator | display items | `info` |
| numbering (detail) | AR_MAINTRNS_ACCOUNT_DET.SEQ global max+1 | PRE-INSERT | key_expr |

## Tests (build copy, simulated APEX session, all rolled back) - `tmp\w3_argl\t_ar.py` 92/92

Dates (future, before 31/12/2020, ACC_POST_DATE); pay method required / invalid / INV_VALUE locked on a saved method-1 payment; books: serial
required, no number, out of range, repeated (385), own number on update, cancelled (temporary AR_SALESMAN_BOOKS_DET row), reminder with
AR_BOOKS_NOTIF, cheque repeated, salesman without an open book; method 1: payment 7 045.98 of customer 100100000009 allocated to 8131 (remaining
640.95) and 8142 (full 6 405.03) with the legacy descriptions, residual 0, invoice residuals 0; grid delete of a line restores the invoice,
KEY-COMMIT refused; method 1 with DISC_VAL 100 (ratio, discounts 9.03 / 90.21 / 0.76, nets = 7 000); method 2: CREATE without lines, SAVE
refused ('يجب ادخال تفاصيل سداد'), picker with a customer period discount (1 % capped 5), CHECK_REPEAT, discount above value, invoice of another
customer, value above residual, partial SAVE refused, default = TRNS_TOTAL_DIFF, full SAVE passes; method 4 removes the lines; category discount
(10 % capped 2 000 for 0-1 day); ACTIVE on a posted payment; POST of a new credit settlement 401 (voucher 2026/103/224) and CANCEL_POST.
Page generation checked in memory (page 30041: PAY_METHOD / BOOK_* items, 4 action regions, info panel, WARN_CHECK).

## Wave 3b (new generator keys; evidence `AR\FMB\arcrtrn_fmb.xml` item properties, list elements, LOV record groups)

| Legacy | Evidence | APEX |
|--------|----------|------|
| PAY_METHOD shown as the list PAY_METHOD_LIST (1 تنازلي على الفواتير / 2 شاشة مساعدة للفواتير / 4 مبلغ دائن لعميل), required | List Item (values 1/2/4; labels of CREATE_AUTH_RECORD), PRE-INSERT 'يجب ادخال طريقة سداد' | static select list, `required` (default 2 kept) |
| BOOK_SERIAL list BOOK_LOV (open receipt books: STOP_FLAG 0, BOOK_FINSH 0, BOOK_TYPE 1, with the number range) | LovName, record group | `lov` "book (from - to)" of the document's salesman (`:PAGE_SALESMAN_ID`, `cascade: SALESMAN_ID`) |
| T_TAX_FLAG1 list "مؤشر الضريبة" (بدون 0, اثبات الضريبة مع / بدون التأثير على حساب العميل 1 / 2, ارتداد الضريبة مع / بدون التأثير 3 / 4), required | ListItemElement, Required | static select list + `required` |
| CASH_FLAG shown as the list CASH_FLAG_LIST (شيكات 0 / نقدية 1 / حسابات 2), initial 2 | List Item | read-only static list, default 2 (0 / 1 need the cash-box / bank systems, not installed) |
| TRNS_ID list TRNSTYPE_LOV (EFFECT 1, TOT_TRNS_FLAG 0, TRNS_TYPE 3/4, group); TRNS_ID, CUSTOMER_ID, CTGRY_CODE, DISC_VAL not updatable | LovName, UpdateAllowed = false | `lov` + `readonly_after_insert` (CTGRY_CODE stays enterable on a new record: TRNS_ID WVI enables it when the type has no category) |
| SALESMAN_ID list SALESMAN_LOV; COST_CODE1 COST_LOV; TRNS_ACCOUNT / CUSTOMER_ACCOUNT / DISC_ACCOUNT account lists (names shown) | LovName | `lov`: salesmen of the customer and category (AR_CUST_SALESMAN, `cascade: [CUSTOMER_ID, CTGRY_CODE]`) and of the group; accounts / cost centres of the group |
| INV_VALUE ' القيمة قبل الضريبة' and DISC_VAL required; ACC_POST_DATE 'تاريخ الايداع' | Required, Prompt | `required`, labels |
| Displays: area / branch names, INV_VALUE_TAX 'القيمة بعد الضريبة', TOTAL_TRNS_VALUE 'اجمالى بعد الخصم' | display items, Formula | computed master columns |
| Allocation lines: INV_TRNS_DATE, INV_TOTAL_VALUE, INV_RESIDUAL_VALUE (invoice date, total, open value) and TOTAL_VALUE_RIYALH | BILL_LOV mapping, POST-QUERY, Formula | computed grid columns (open value = TOTAL - AR_SUBTRNS_PAYED_VALUE) |
| Account-link lines: TRNS_ACCOUNT / COST_CODE1 lists | LovName | `lov` |

Checked: AR_SUBTRNS block InsertAllowed / UpdateAllowed = false (already so: lines come from the allocation); RP_BTN / PC_BTN open the
cash-box / cheque systems (not installed). SQL of every list / computed column run on the build copy (`tmp\w3b_gl\check.py`, problems 0).

## Coverage

Reproduced: everything in the tables above. Deliberately not reproduced:

- **Cash box / bank / cheque systems** (BOX_CODE, BANK_CODE, BRANCH, RP_BTN / PC_BTN, FROM_CHECK_TYPE / SERIAL, INSERT_RP_PC_TRNS): systems 13 and
  15 are not installed (SYS_SYSTEMS), CASH_FLAG stays 2 (accounts) as in all 404 collections.
- Printing, printer selection, ZATCA, SET_IP / dongle, prompts / tab visibility, AR_BILL_DUMMY (Forms session reservation of picked bills).
- Tax computation GET_TAX_VALUE for T_TAX_FLAG1 2..4 (TAX_VALUE1 read-only; all payments have T_TAX_FLAG1 0).
- The description is set only when left empty (the legacy rewrote it at every customer change).
- Immediate posting (AR_TRNSTYPE.IMMID_POST_TYPE = 0 for every type).
- DELETE_AC_EFFECT (GL effect of deleting a posted payment): posted payments cannot be deleted (cancel the posting first).
- **Generator limits**: the picker is an action region, not a grid LOV; the equality check of KEY-COMMIT for method 2 runs on SAVE (APEX
  creates the header before the lines). (Resolved in wave 3b: PAY_METHOD / BOOK_SERIAL lists.)
- Type-dependent visibility (FILTER_DATA / ENABLE_BOOK_NO: accounts, cost centres, receipt book shown per AR_TRNSTYPE): the fields are always
  shown.

## Open questions

1. The category discount AR_CTGRY_DSCNT (category 1: 10 % up to 2 000 when paid within 0-1 day) is applied by the invoice picker and the manual
   adjustment as in the legacy code (CALCULATE_DISCOUNT). No existing allocation carries a discount: confirm it is wanted.
2. Legacy Forms validation order may have replaced the period discount by the header ratio (DISC_VALUE_PREC) even when the ratio is 0; APEX keeps
   the period discount when the header ratio is 0.
3. POST uses NVL(ACC_POST_DATE, TRNS_DATE) as the posting date filter (legacy ARCRTRN passed ACC_POST_DATE, ARDBTRN TRNS_DATE).
4. POST / CANCEL_POST are available to every user of the screen (legacy CALL_FORM had no extra right check). Restrict to users of ARACUPDT /
   AR_CPOSTING?
