# ST_TRNS_TYPE — أنواع الحركات (المشتريات) / Transaction Types of purchasing (system 30, serial 22)

Deliverable: **business rules + filter + copy button on the generated master-detail** — `overrides/ST_TRNS_TYPE.json`
(AUTO: generated page ST_TRNS_TYPE + posting lines STACLNK kept; `where`, radio groups and lists as real lists since wave 3b, defaults, validation,
after-save, info, action), `APP_RULES3_PR` (`trns_type_check`, `staclnk_after_save`, `trns_type_delete`, `copy_trns_type`),
delete hook `APP_R3_ST_TRNS_TYPE_BD`. Pages 50110 / 50111. Confidence: **medium-high**.

## Purpose and tables
`ST_TRNS_TYPE` is shared by several screens (stock ST_TRNS_TYPE_ST, sales ST_TRNS_TYPE_SL, purchasing ST_TRNS_TYPE); each shows
and edits only its own kinds. This screen: purchasing kinds and their posting lines `STACLNK` (entry, serial, account /
cost-centre source, debit / credit, value).

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Only purchasing kinds: `(TRNS_TYPE IN (1,3,12,9,13,14,15,25,5) AND EFFECT IN (3,7)) OR (TRNS_TYPE = 1 AND EFFECT = 1)`, plus the user's type rights (`ST_TRNSTYPE_PASSWORD`, FLAG 1) | `rules.where` | block WHERE of the .fmx, radio groups وارد / مردود وارد / بدون تأثير and the 9 kinds | high |
| 2 | Code required, 1..999999 — "أدخل كود للحركة", "رقم نوع الحركة يجب ان يكون فى المدي من 1 و 999999" | validation `trns_type_check` (CREATE) | .fmx messages | high |
| 3 | No duplicate — "هذا الكود موجود من قبل" | validation | `SELECT COUNT(1) FROM ST_TRNS_TYPE WHERE TRNS_TYPE_CODE = :b1` | high |
| 4 | Effect / kind within this screen's values (rule 1) | validation | radio groups | high |
| 5 | Effect or kind of a type with documents cannot change | validation (SAVE) | existing documents counted in ST_TRNS_MAST / ST_SALES_ORDER / ST_PROPOSAL_MAST / PR_ORDER | medium (message is ours: the legacy disabled the radio groups after query) |
| 6 | Basic store from the store list (active, allowed); link type 1..4 (غير مرتبط / بالحسابات / بالعملاء+الحسابات / بالموردين+الحسابات); posting type 1..2 (قيد لكل حركة / قيد لكل نوع حركة) | validation | LOVs / radio groups | high |
| 7 | GL / AR / AP transaction numbers from `AC_TRN_CODES`, `AR_TRNSTYPE`, `VN_TRNSTYPE`; cash box `RP_TRNS_TYPE`, bank `CHECK_TRNS_TYPE` (not stopped); supplier-discount transaction `VN_TRNSTYPE` (EFFECT 0, TRNS_TYPE 4) | validation | LOV SQL of the .fmx | high |
| 8 | Linked types from their lists: purchase order (7/14), purchase (1/1), request for quotation (7/25) | validation | LOV SQL | high |
| 9 | Posting lines: detail accounts (`ACCOUNT_STATUS = 1`) and active cost centres | after-save `staclnk_after_save` | account / cost-centre LOVs | high |
| 10 | Delete refused while transactions exist — "لا يمكن حذف السجل حيث توجد حركات معتمدة عليه بالنظام" (page-aware: only for this screen's page) | trigger `APP_R3_ST_TRNS_TYPE_BD` → `trns_type_delete` | `SELECT COUNT(1) FROM ST_TRNS_MAST WHERE TRNS_TYPE_CODE = :b1` + message | high |
| 11 | Defaults: effect 1, kind 1, link 1, posting 1 | `defaults` | radio initial values | medium |
| 12 | Last serial of the type shown on the document page | `info` LAST | display item "آخر مسلسل للحركة" | medium |

## Buttons
| Button | Implementation | Evidence |
|--------|----------------|----------|
| نسخ الحركة (copy the type under a new number, with its posting lines; names suffixed " - منسوخ" / " - Copied"; "تم نقل الحركة") | action COPY_TYPE (parameter NEW_TRNS_TYPE_CODE) → `copy_trns_type`, opens the copy | `INSERT INTO ST_TRNS_TYPE (...) SELECT :b1, DESC_A || ' - ' || 'منسوخ', ...` and `INSERT INTO STACLNK ... SELECT` of the .fmx |

## Generator limits met
* Wave 3: EFFECT / TRNS_TYPE / JOIN_TYPE / POST_TYPE had their values written into the labels and the STACLNK lists were
  numbers (no static-list override then). Wave 3b replaced this with real lists (see below).
* STACLNK VALUE_TYPE stays a number field: the .fmx holds its 24 labels but not their values, and several posting codes
  (33, 34, 35, 60) cannot be tied to one label with certainty.
* LAST_SERIAL column hidden (the displayed last serial is computed, rule 12).

## Tests (`tmp\w3_prsa\t_w3prsa.py`, page 50111)
TT1 code range · TT2 duplicate · TT3 sales effect refused · TT4 valid purchase type · TT5 wrong linked purchase type ·
TT6 unknown GL transaction · TT7 effect change with documents refused · TT8 unchanged type passes · TT13 delete refused
(documents) · TT15-TT17 copy (names, posting lines, message) · TT18 copy to an existing code refused · TT19 copy without a
code refused · TT20 new type deleted · TT22 posting line with a summary account refused. All PASS.

## Wave 3b
* Real lists instead of the value legends in the labels (`rules.columns`, clean legacy labels):
  EFFECT radio وارد 1 / مردود وارد 3 / بدون تأثير 7; TRNS_TYPE list of the nine kinds (مشتريات 1, مرتجعات شراء 3, طلب نواقص 12,
  تحويل 9, طلب شراء 13, امر شراء 14, رسائل واردة 15, طلب عرض سعر 25, أخرى 5); JOIN_TYPE radio 1-4; POST_TYPE radio 1-2;
  NO_COST check box 1/0. Evidence: .fmx radio / list labels in the order of the block WHERE `TRNS_TYPE IN (1,3,12,9,13,14,15,25,5)
  AND EFFECT IN (3,7) OR (TRNS_TYPE = 1 AND EFFECT = 1)`, the check-box help text "حركة مشتريات بدون تكاليف", data (JOIN_TYPE 1-4,
  POST_TYPE 1, NO_COST 0 / null).
* STACLNK lists: ACCOUNT_IND مدين 1 / دائن 2; ACCOUNT_NO_TYPE (15 entries: إدخال الرقم 1, ح/الصندوق بالمخازن 2, ح/المخزون 3,
  ح/تكلفة المبيعات 4, ح/المبيعات 5, التوجيه المحاسبي 1-4 = 6-9, ملف العملاء 10, ملف الموردين 11, ح/المخزون المحول إليه 12, ملف
  موردي الخدمات 14, ملف المجموعات 15, حساب الضرائب 66); COST_NO_TYPE and COST_NO2_TYPE (إدخال الرقم 1, أرقام المخازن 2, ملف
  الحركات 3, ملف المجموعات 4, المخزن المحول إليه 5, بدون 6).
  Evidence for the codes: the posting procedure `MAKE_ENTRY` (ST_POSTING_CPOSTING.fmb) branches on ACCOUNT_NO_TYPE 1 (typed
  account), 2 / 3 / 4 / 5 / 12 (store accounts, `HANDLE_STORE`), 6-9 (document accounts 1-4), 10 (customer), 11 (supplier), 14
  (service suppliers, `HANDLE_VNDR_SRVS`), 15 (item group, `HANDLE_GROUP`), 16 (store `BANK_ACCOUNT`), 66 (tax account of
  `TX_TAXES_TYPES`), and on COST_NO_TYPE / COST_NO2_TYPE 1 (typed), 2 (store), 3 (document), 4 (item group), 5 (receiving store),
  6 (none), 7 (cost centre 2 of the salesman, COST_NO2 only); the labels are the .fmx list texts, and the mapping is the one the
  stock screen ST_TRNS_TYPE_ST uses. Data: every STACLNK value is in the lists (account source 1, 3, 6, 10, 11, 14, 66; cost
  centre 1, 2, 5, 6; cost centre 2 1, 6, 7).
* STACLNK ACCOUNT_NO popup (detail accounts + password), COST_NO /
  COST_NO2 lists (active centres + AC_PASSWORD_COST1 / 2).
* Legacy LOVs of the .fmx on the header: store (active, ST_STORE_PASSWORD), GL transaction (AC_TRN_CODES + AC_PASSWORD_ENTRY),
  AR / AP transaction (AR_TRNSTYPE / VN_TRNSTYPE with `EFFECT = DECODE(:EFFECT, 1, 1, 3, 0)`: cascading list on EFFECT, as the
  legacy LOV), supplier-discount transaction (VN_TRNSTYPE 0/4), purchase order 7/14, purchase 1/1, RFQ 7/25
  (ST_TRNSTYPE_PASSWORD), cash box / bank transaction (RP_TRNS_TYPE / CHECK_TRNS_TYPE not stopped, `TRNS_TYPE = DECODE(:TRNS_TYPE, 1, 1, 3, 2)`: cascading
  on TRNS_TYPE; password tables).
* Cascades run with parent values: AR list 12 rows for effect 1 / 8 for effect 3, AP list 4 / 7; cash box and bank lists run
  (tables empty in the build copy).
* Check: `check_forms.py ST_TRNS_TYPE`: 13 list queries run unrestricted and as a restricted user, page generated.

## Coverage
Reproduced: screen filter, code / duplicate / effect / kind rules, radio groups and lists as real lists (wave 3b), lists of
stores, accounting transactions and linked types (cascading on effect / kind as in the legacy LOVs), posting-line account
source, cost-centre and debit / credit lists, accounts and cost centres, delete restriction, copy button, last serial.
Not reproduced: the STACLNK value-indicator list (VALUE_TYPE: values not recoverable, see above; number field), help texts of
the check boxes, Forms enable / disable of fields by kind, toolbar / translation code.
