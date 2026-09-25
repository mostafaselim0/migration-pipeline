# ST_TRNS_TYPE_SL — أنواع الحركات (المبيعات) / Transaction Types of sales (system 31, serial 18)

Deliverable: **screen correction + business rules** — `overrides/ST_TRNS_TYPE_SL.json` (MASTER_DETAIL ST_TRNS_TYPE +
STACLNK; `where`, legacy labels with real lists since wave 3b, defaults, validation, after-save, info, copy action), shared helpers of
`APP_RULES3_PR` (`trns_type_check` with `p_form = 'ST_TRNS_TYPE_SL'`, `staclnk_after_save`, `trns_type_delete`,
`copy_trns_type`). Pages 60070 / 60071. Confidence: **medium-high**.

## Why a screen correction
The generated page used **ST_TRNS_MAST (documents) as the detail** of the type — wrong. The legacy form edits the type and its
posting lines `STACLNK`, like the purchasing screen.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Only sales effects: `EFFECT IN (2, 4, 7)` + type rights (`ST_TRNSTYPE_PASSWORD`, FLAG 1) | `rules.where` | block WHERE, radio group صادر / مردود صادر / بدون تأثير | high |
| 2 | Code required, > 0 — "أدخل كود للحركة", "المسلسل يجب ان يكون اكبر من الصفر"; no duplicate "هذا الكود موجود من قبل" | validation `trns_type_check` (CREATE) | .fmx messages / SQL | high |
| 3 | Effect / kind of a type with documents cannot change | validation (SAVE) | documents counted in ST_TRNS_MAST / ST_SALES_ORDER / ST_PROPOSAL_MAST / PR_ORDER | medium |
| 4 | Basic store, link type 1..4, posting type 1..2, GL / AR / AP / cash box / bank transactions from their lists | validation | LOVs / radio groups | high |
| 5 | Linked types: sales invoice (EFFECT 2) of the same store, sales order (7/30), goods reservation (2/17, same store), delivery note (7/31, same store), issue transfer (5/9), transfer receipt (6/9); department from `ST_CATEGORY_TYPE` | validation | LOVs "أرقام حركات المبيعات", "أرقام حركات اوامر المبيعات", "أرقام حركات حجوزات المبيعات", "حركات مذكرات التسليم", "أرقام حركات الاستلام", "إختيار القسم" | medium-high |
| 6 | Posting lines: detail accounts, active cost centres | after-save `staclnk_after_save` | LOVs | high |
| 7 | Delete refused while sales documents exist (ST_TRNS_MAST or ST_SALES_ORDER) — "لا يمكن حذف السجل حيث توجد حركات معتمدة عليه بالنظام" | trigger `APP_R3_ST_TRNS_TYPE_BD` (page-aware) | SQL + message | high |
| 8 | Defaults: effect 2, kind 2, link 1, posting 1; last serial shown | `defaults`, `info` LAST | radio initial values, display item | medium |

## Buttons
| Button | Implementation | Evidence |
|--------|----------------|----------|
| نسخ الحركة (new number "رقم الحركة الجديد"; "يجب إدخال رقم الحركة الجديدة", "رقم الحركة الجديد موجود بالفعل", "تم نقل الحركة") | action COPY_TYPE → `copy_trns_type('ST_TRNS_TYPE_SL', ...)` (names kept, no suffix — as the legacy INSERT) | `INSERT INTO ST_TRNS_TYPE (...) SELECT :b1, DESC_A, DESC_E, ...`, `INSERT INTO STACLNK ... SELECT` |

## Open questions
* The .fmx also counts posted sales documents of the type (`... POST_FLAG = 1`); where it is used (probably to lock the
  accounting fields of a type with posted documents) is not visible. Not reproduced.
* Price handling "تعاملات الاسعار" (retail / wholesale / cut price: SALES_PRICE_FLAG) is a radio group, but its values are
  not in the evidence (no form source uses the column; data 1 or empty): still a number field. Which values are retail /
  wholesale / cut price (probably 1 / 2 / 3 in the order of the buttons)?
* The legacy AP transaction lists (SUPPLIER_TRNS_CODE / _PAY_CODE) filter `VN_TRNSTYPE.EFFECT = DECODE(:EFFECT, 1, 1, 3, 0)`,
  a copy of the purchasing form, which is empty for the sales effects 2 / 4 / 7; reproduced as it is (no sales type has one in
  the data). Should sales types link to AP transactions at all?

## Tests (`tmp\w3_prsa\t_w3prsa.py`)
TT9 purchasing effect refused · TT10 sales invoice type of another store refused · TT11 valid sales-order type ·
TT12 code ≤ 0 refused · TT14 delete refused on the sales page · TT21 sales copy keeps the names. All PASS.

## Wave 3b
* Real lists instead of the legends in the labels (clean labels): EFFECT radio صادر 2 / مردود صادر 4 / بدون تأثير 7; TRNS_TYPE list
  of the legacy kinds (مبيعات 2, مرتجعات بيع 4, حجز بضاعة 17, عرض سعر 16, أمر بيع 30, تسليم 31, أخرى 5) plus the kinds other screens
  give to types with these effects and that exist in the data (تسوية 7: 10 types with effect 2; تحويل 9, امر شراء 14, رسائل واردة
  15: types with effect 7) so that such types show and save unchanged; JOIN_TYPE radio 1-4; POST_TYPE radio 1-2. Evidence: .fmx
  radio texts, block WHERE, data. Check boxes 1/0: HAS_SALES_PRICE, HAS_SALESMAN, HAS_DISCOUNT, HAS_FREIGHT, HAS_TRANSPORT,
  HAS_CUSTOM, HAS_INSURANCE, HAS_COMMISSION, HAS_OTHERS, AUTO_TRNS (check boxes of the legacy type forms; data 0 / 1 / empty).
* Legacy LOVs of the .fmx as lists: store (active, ST_STORE_PASSWORD), department (ST_CATEGORY_TYPE), GL transaction, AR
  transaction `AR_TRNSTYPE.EFFECT = DECODE(:EFFECT, 2, 0, 4, 1)` and AR payment `DECODE(:EFFECT, 2, 1, 4, 0)` (data: the 3 invoice
  types use AR effect 0, the 3 return types AR effect 1), AP transactions (legacy list, see the question), cash box / bank
  `TRNS_TYPE = DECODE(:TRNS_TYPE, 2, 2, 4, 1)`, sales invoice (effect 2, same store), sales order (7/30), reservation (2/17, same
  store; the SDI branch does not apply, the installation is not SDI), delivery note (7/31, same store), issue transfer (5/9),
  transfer receipt (6/9). Lists that depend on the effect, kind or store are cascading lists.
* STACLNK lists: ACCOUNT_NO_TYPE (إدخال الرقم 1, ح/الصندوق 2, ح/المخزون 3, ح/تكلفة المبيعات 4, ح/المبيعات 5, التوجيه المحاسبي
  1-4 = 6-9, ملف العملاء 10, ملف الموردين 11, ح/المخزون المحول إليه 12, ح/مجموعات الأصناف 15, ح/البنـك 16, حساب الضرائب 66),
  COST_NO_TYPE 1-6, COST_NO2_TYPE 1-7 (7 = ملف مندوبي المبيعات), ACCOUNT_IND مدين / دائن; accounts and cost centres from their
  lists.
  Evidence for the codes: the posting procedure `MAKE_ENTRY` (ST_POSTING_CPOSTING.fmb) branches on ACCOUNT_NO_TYPE 1 (typed
  account), 2 / 3 / 4 / 5 / 12 (store accounts, `HANDLE_STORE`), 6-9 (document accounts 1-4), 10 (customer), 11 (supplier), 14
  (service suppliers, `HANDLE_VNDR_SRVS`), 15 (item group, `HANDLE_GROUP`), 16 (store `BANK_ACCOUNT`), 66 (tax account of
  `TX_TAXES_TYPES`), and on COST_NO_TYPE / COST_NO2_TYPE 1 (typed), 2 (store), 3 (document), 4 (item group), 5 (receiving store),
  6 (none), 7 (cost centre 2 of the salesman, COST_NO2 only); the labels are the .fmx list texts, and the mapping is the one the
  stock screen ST_TRNS_TYPE_ST uses. Data: every STACLNK value is in the lists (account source 1, 3, 6, 10, 11, 14, 66; cost
  centre 1, 2, 5, 6; cost centre 2 1, 6, 7).
* Check: `check_forms.py ST_TRNS_TYPE_SL` (20 lists run unrestricted and restricted); cascades run with parent values (AR list 8
  rows for effect 2, 12 for effect 4; sales invoice types of store 101010102001: 1).

## Coverage
Reproduced: corrected structure (type + posting lines), filter, code / effect rules, radio groups, check boxes and all legacy
lists as real lists incl. the posting-line indicators (wave 3b), delete restriction, copy, last serial.
Not reproduced: the price-handling radio values (question), the value-indicator list (VALUE_TYPE, see ST_TRNS_TYPE.md), the
posted-documents count of unknown use (question), Forms enabling of fields by kind, toolbar / translation code.
