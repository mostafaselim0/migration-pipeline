# ST_RESERVATION — quantity reservation (عمل حجز بضاعة)

System 31 serial 10 (FILES_MENU.ST_RESERVATION). Source: compiled form only (`ST\FMB\ST_RESERVATION.fmx`, evidence
`app\legacy\evidence\ST_RESERVATION.md`; wave 3 also read the string pool, literal pool and symbol table of every program unit
of the .fmx). Deliverable: **(a) AUTO + rules** (`overrides\ST_RESERVATION.json`, `APP_RULES_ST` for the stock rules of wave 2,
`APP_ACT_ST` (section `rsv_`) for the wave-3 rules and the button).

## Purpose and data

Reserves goods for a customer: an issue-type document (the reserved quantity leaves the available balance) that is later turned
into a sales invoice ("صرف الفاتورة": the document is moved to ST_TRNS_TYPE.SALES_TRNS_TYPE_CODE) and a delivery note
(ST_DELIVERY_MAST/DET). Lines ST_TRNS_DET, services ST_TRNS_SERVICES, composite items ST_TRNS_STAND_DET.

Types (block WHERE): `(TRNS_TYPE_CODE IN (SELECT .. WHERE (T.EFFECT = 2) AND (T.TRNS_TYPE in (17))) AND NVL(DELETE_FLAG,0) = 0
AND (:1 = 0 or :2 != 0 and TRNS_TYPE_CODE IN (SELECT .. FROM ST_TRNSTYPE_PASSWORD WHERE FLAG=1 AND PASSWORD_NUMBER=:3)))`.
**No transaction type EFFECT 2 / TRNS_TYPE 17 exists in ST_TRNS_TYPE and there are no reservation documents**: the screen is
dormant in this company (the type default is empty and every save is refused with "نوع الحركة غير مسموح"). All wave-3 rules were
tested with a temporary reservation type inside the test transaction.

Installation code (`:GLOBAL.CUSTOMER_CODE`, `SELECT CUSTOMER_CODE FROM CUSTOMER_PAR` in Sysmenu.fmx): CUSTOMER_PAR is empty on this
database (production discovery `_discovery\05_tables_rows.csv`), so the code is NULL. This form has no installation branch.

## Rules implemented (wave 2, APP_RULES_ST)

| # | Rule | Where | Evidence |
|---|------|-------|----------|
| 1 | List filter EFFECT 2 / TRNS_TYPE 17, DELETE_FLAG 0, group types with FLAG = 1 | `rules.where` | block WHERE |
| 2 | Type of the screen (FLAG = 1 for new documents); defaults: type (none), store = type store, flags 0 | `val_trns`, `rules.defaults` | TRNS_TYPE LOV |
| 3 | Date: CHECK_DATE, AC_BASIC open period, and **after the last closing date AC_BASIC.CLOSE_DATE** | `val_trns` | `SELECT CLOSE_DATE FROM AC_BASIC WHERE COMPANY_CODE = :b1`, "يجب ان يكون تاريخ القيد بعد تاريخ اخر اقفال" |
| 4 | Currency rate required; rate of the local currency (1) must be 1 | `val_trns` | "يجب ادخال معامل التحويل", "معامل تحويل الريال يجب ان يكون ب 1" |
| 5 | DOC_NO = MAX(DOC_NO) + 1 per type when empty | `next_doc_no` | `SELECT NVL(MAX(DOC_NO),0)+1 FROM ST_TRNS_MAST TM, ST_TRNS_TYPE TT WHERE .. TM.TRNS_TYPE_CODE = :b1 ..` (the legacy query also filters TRNS_TYPE = 2, a copy from the sales form that always returns 1 for type 17) |
| 6 | Lines: item / group / unit / BASIC_QTY, quantity + bonus > 0, price > 0, lot of the item or first lot with balance, lot balance checks (issue type) | `det_row` | "الكمية و البونص يجب أن يكون مجموعهما أكبر من صفر", "سعر الصنف يجب أن يكون أكبر من صفر", "رصيــد هذه الشحنة لهذا صنف فى هذا التاريخ لا يسمــح", "الرصيد لا يسمح / توجد حركة تالية" |
| 7 | At SAVE: items or services required; service price > 0 | `after_trns` | "غير مسموح بحفظ الفاتورة بدون أصنــــــاف أو خدمات", "سعر بيع الخدمة يجب أن يكون أكبر من صفر" |
| 8 | Posted read-only, type/store fixed once lines exist, delete removes lines, services and composite lines (legacy physical delete, KEY-DELREC / PRE-DELETE) | `val_trns`, triggers | `DELETE FROM ST_TRNS_SERVICES / ST_TRNS_STAND_DET / ST_TRNS_DET ..` |

## Wave 3: rules and button added (APP_ACT_ST, section `rsv_`)

| # | Rule / button | Where | Evidence (.fmx program unit / trigger) | Confidence |
|---|---|---|---|---|
| W1 | Transaction date defaults to today | `defaults` TRNS_DATE | WHEN-CREATE-RECORD `SELECT TO_DATE(TO_CHAR(SYSDATE,'DD-MM-YYYY'),'DD-MM-YYYY') FROM SYS.DUAL` | high |
| W2 | Currency 1 / rate 1 by default; on the first save the currency of the customer (else the supplier) and its AC_CURRENCY rate replace them when they are not the local currency | `defaults`, `rsv_after_save` (CREATE) | CUSTOMER_CODE / SUPPLIER_CODE WHEN-VALIDATE-ITEM: `SELECT C.CURRENCY_CODE, .., RATE FROM AC_CURRENCY C, CUSTOMER S WHERE C.CURRENCY_CODE = NVL(S.CURRENCY_CODE,1) AND CODE = :b1` (same for SUPPLIER); data: all 126 customers use currency 1 | high / medium (timing) |
| W3 | Salesman default = `MIN(SALESMAN_CODE)` of AR_CUST_SALESMAN for the customer; required when the type has HAS_SALESMAN = 1 and none can be derived ("يجب إدخال رقم المندوب") | `rsv_after_save` | CUSTOMER_CODE WHEN-VALIDATE-ITEM: `COUNT(SALESMAN_CODE)`, `NVL(HAS_SALESMAN,0)`, `SELECT MIN(SALESMAN_CODE) FROM AR_CUST_SALESMAN WHERE CUSTOMER_CODE = :b1` | high / medium (required) |
| W4 | POSTING_SUPPLIER_CODE := SUPPLIER_CODE | `rsv_after_save` | SUPPLIER_CODE WHEN-VALIDATE-ITEM symbol `:POSTING_SUPPLIER_CODE` | medium |
| W5 | New document: INVOICE_NO = type ‖ LPAD(serial, 5, '0') when empty; DESC_A = type description ‖ ' مستند رقم ' ‖ DOC_NO, DESC_E = type description ‖ ' Doc No. ' ‖ DOC_NO | `rsv_after_save` (CREATE) | TRNS_TYPE_CODE WHEN-VALIDATE-ITEM literals ' مستند رقم ', ' Doc No. ', '0', number constant 5; symbols :INVOICE_NO, :DESC_A, :TRNS_TYPE_DESC | medium (length 5 from the constant pool) |
| W6 | Customer transactions (JOIN_TYPE 3) require the customer | `rsv_validate` | SHOW_HIDE_ITEMS `SELECT NVL(JOIN_TYPE,0), NVL(HAS_SALESMAN,0) FROM ST_TRNS_TYPE`; same rule as the sales invoice form it was copied from | medium |
| W7 | Lists of values by user group: customer not stopped (`NVL(STOPFLAG,0) <> 1`) and in the group's AR_CUSTOMER_PASSWORD range; supplier in VN_SUPPLIER_PASSWORD range; salesman one of the customer's (AR_CUST_SALESMAN) and in the group's FROM/TO_SALESMAN range; account granted in AC_PASSWORD_MASTER; type whose store is granted (ST_STORE_PASSWORD) | `rsv_validate` | CUSTOMER_RG, SUPPLIER_RG, SALESMAN_RG, ACCOUNT_RG, TRNS_TYPE record groups (evidence SQL) | high |
| W8 | Items of item groups granted to the group (ST_GROUP_PASSWORD) | `rsv_after_save` | ITEM2_RG / ITEM_RG `(:GLOBAL.PASSWORD_NUMBER=0 OR IT.ITEM_GROUP_CODE IN (SELECT GROUP_CODE FROM ST_GROUP_PASSWORD ..))` | high |
| W9 | Line discount below the line value ("قيمة الخصم يجب أن تكون أقل من مجموع الأصناف"); invoice discount below the items total ("قيمة الخصم يجب أن تكون أقل من قيمة الفاتورة"); cash + network paid not above the net value ("المدفوع نقدى اكبر من إجمالى الاصناف و الخدمات") | `rsv_after_save` (SAVE) | DET_DISC_CURR, DISC_VAL_CURR, PAYMENT_CURR, ATM_AMMOUNT_CURR WHEN-VALIDATE-ITEM, master PRE-INSERT | high |
| W10 | Invoice discount spread on the lines: `DISC = DISC_VAL × LINE_TOTAL / (TOTAL_VALUE × BASIC_QTY)` | `rsv_after_save` | GET_NDB_DISC (symbols; same function with source in ST_ISSUE_IO.fmb), detail PRE-INSERT `:DISC := :NDB_DISC` | high |
| W11 | Header fields DISC_VAL (مبلغ الخصـم), TRNSPORT_VAL (مبلغ النقل), PAYMENT (المدفوع نقدي) on the page (entered in riyal; the legacy _CURR items were document-currency copies) | `add_columns` | labels ST_TRNS_MAST.DISC_VAL_CURR / TRNSPORT_VAL_CURR / PAYMENT_CURR | high |
| W12 | Displays: items total, services total, net value (items + services − discount + transport), change (paid − net) | `info` (`rsv_info`) | TOTAL_VALUE, SERVICE_TOTAL, NET_VALUE, CHANGE_AMMOUNT formulas (POST-CHANGE triggers) | high |
| B1 | **Button "صرف الفاتورة"** (CONV_TO_INVOICE, confirmation "سوف يتم عمل الفاتورة !! هل تريد الإستمرار"): sales type = ST_TRNS_TYPE.SALES_TRNS_TYPE_CODE of the reservation type (else "يجب تعريف رقم حركة المبيعات فى شاشة أنواع الحركات"); **INSERT_DELIVERY_TRNS**: delivery type = DELIVERY_TRNS_TYPE_CODE (else "يجب ربط حركة الحجز برقم حركة مذكرة تسليم في شاشة أرقام الحركات!!!"), ST_DELIVERY_MAST (serial max + 1 per type, DELIVERY_SERIAL max + 1 per type and order, date = reservation date, store, customer, supplier, salesman, DELIVARY_STATE 3, order link, DISC_VAL, TRNSPORT_VAL, description 'أمر التسليم رقم t / s من أمر بيع رقم ot / os') and ST_DELIVERY_DET (serial 1..n, group, item, unit, DELIVERED_QTY = QUANTITY, prices, bonus, lot); then the reservation header, lines, composite lines and services get the sales type and serial max + 1 (the legacy dropped / re-added the child foreign keys with FORMS_DDL; they do not exist on this database, so plain updates); "تـم عمـل الفـاتـورة بنـجــاح"; the invoice page opens | action `TO_INVOICE` → `rsv_to_invoice` | P38 (CONV_TO_INVOICE): SQL lines 25-76, literals; program unit INSERT_DELIVERY_TRNS (SQL, symbol table, literals) | high for the SQL, medium for the delivery NOTE_NO |
| W13 | Default line price: ROUND(REDUCTION_PRICE / rate, 2), else the wide price (ST_STORE.DEAL_TYPE = 1) or the retail price / rate, the store prices of ST_STORE_ITEM_UNIT replacing the item's, × rate (the page line price is in riyal); UNIT_PRICE_CURR (read-only on the page) = UNIT_PRICE / rate after save. The legacy DET_DISC_CURR item is not a column (only DET_DISC exists) | `APP_RULES_ST.det_row` → `rsv_price` (row rule already active), `rsv_after_save` | ITEM_CODE / UNIT_CODE WHEN-VALIDATE-ITEM SQL `SELECT ROUND(REDUCTION_PRICE / :b1, 2), ROUND(WIDE_SALE_PRICE / :b1, 2), ROUND(RETAIL_SALE_PRICE / :b1, 2) FROM ST_ITEM_UNIT ..`, `.. FROM ST_STORE_ITEM_UNIT ..`, `SELECT DEAL_TYPE FROM ST_STORE ..`; data: REDUCTION_PRICE empty everywhere, ST_STORE_ITEM_UNIT empty | medium (precedence of the store prices read from the SQL order) |


## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Per line: item name, lot expiry, "الرصيد قبل الحركة" (lot balance before the line / factor, ALLOW_VIEW_BALANCE), "تكلفة الصنف" (lot average cost, cost right) | `computed.ST_TRNS_DET.*` | display items and labels (same template as the sales invoice) - medium |
| Lot list of the line's item (lot id - lot number - expiry), refreshed when the item changes | `ITEM_CONFG_ID` `lov` + `cascade: ITEM_CODE` | legacy lot LOV (ITEM_CONFG_LOV / CONFG); the row rule still checks the lot and its balance |

Costs are empty unless (USERS.ALLOW_VIEW_COST = 1 and ST_BASIC.SHOW_COST = 1) or the user's group is 0 (legacy GET_USER_SEC); the column itself stays visible (the generator cannot hide a column per user right). Tested on the build copy: every list query and computed expression runs (`tmp\w3b_st\sqlcheck.py`, lot list with item 101010006); the cost / balance gates checked in an APEX session (`t_gates.py`, rolled back, session removed). The cost / balance display permissions (GET_USER_SEC) are reproduced as empty values, not hidden columns.

## Coverage

Reproduced: everything in the two tables above (wave 2 + wave 3; W13 added by the coordinator, test `t_f3.py` R5b in the APEX run).

Not reproduced, with the reason:

- **Composite items (stands, "الأصناف المجمعة")**: DECOMPOSE_STAND (replaces a stand line by its components from ST_STAND_ITEMS and
  its services from ST_STAND_SERVICES, records the stand in ST_TRNS_STAND_DET, stops expired stands "هذا الاستاند قد تم انتهاء تاريخ
  عرضه سوف يتم ايقاف الاستاند") and the removal of the component lines when a stand row is deleted. The compiled form only shows the
  SQL (component prices `DECODE(DEAL_TYPE,1,WIDE_SALE_PRICE,RETAIL_SALE_PRICE)`, `SUM(.. * ITEM_QTY)`, service UNIT_COST) and variable
  names (TOTAL_SALE_PRICE, REDUCTION_AMOUNT, NET_PRICE, DSCNT): how the stand price / reduction is spread over the component lines
  cannot be recovered, and the feature is dormant (ST_STAND_ITEMS and ST_STAND_SERVICES are empty, no ST_ITEM has STAND_FLAG = 1,
  ST_BASIC.STOCK_STAND_ITEM = 0). The composite-lines grid stays a plain grid. Question 3.
- (Reproduced by the coordinator after the fork, W13 below.)
- DOC_NO repeat check (CHECK_DOC_NO): its query is restricted to TRNS_TYPE 2 types and can never match a reservation (dead code).
- Forms-only: item balance / alternate items / unit windows (WINDOW157, WINDOW_SUB, WINDOW498 — lookups), SHOW_HIDE_ITEMS /
  SHOW_HIDE_CONFIG / ENABLE_DISABLE_CONFIG (display), colour / size checks (ST_BASIC.COLOR_FLAG = SIZE_FLAG = 0), printing
  (ST_Invoice.RDF, ST_Invoice2.RDF, official receipt), WEBUTIL, SET_IP. Cost / balance permissions: values emptied (wave 3b).

## Tests (ROLLBACK, temporary types 91030 reservation / 91031 delivery note)

`tmp\w3_sales\f3\t_f3.py` (plain and simulated APEX session on page 60131 with the APPX triggers and APP_RULES_ST hooks active):
customer required, stopped customer, salesman of the customer, group rights (type store), salesman / invoice number / description /
currency derivations, invoice-discount, cash-paid and line-discount refusals, discount spread, displays, "صرف الفاتورة" refusals
(no sales type, no delivery type), conversion (same row moved to 10301/next with lines and services, delivery note with state 3 and
the lines, stock unchanged, legacy text, DOC_NO_SEQ untouched) — 23 checks (24 in the APEX run), all passed.

## Human verification / open questions

1. Is quantity reservation used at all? If yes, define a type (EFFECT 2, TRNS_TYPE 17, SALES_TRNS_TYPE_CODE, DELIVERY_TRNS_TYPE_CODE).
2. The delivery note made by "صرف الفاتورة" is not linked to the invoice (the legacy UPDATE only changes the keys): on the delivery
   screen it can be converted again. Should the invoice get DELIVERY_TRNS_TYPE_CODE / SERIAL of the note (suggested)? The ALT_KEY of
   the moved header / lines keeps the reservation key (legacy).
3. Composite items: how is the stand price spread over its components (discount per line)? Needed only if stands are defined.
4. Delivery NOTE_NO of the note made by "صرف الفاتورة": the compiled form computes V_NOTE_NO in a way that cannot be read; APEX uses
   the delivery screen's numbering (MAX + 1 per delivery type).

## Confidence: **medium** (dormant screen, compiled form only; the button follows the SQL of the form exactly)
