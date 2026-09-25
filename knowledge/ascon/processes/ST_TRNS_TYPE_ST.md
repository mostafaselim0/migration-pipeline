# ST_TRNS_TYPE_ST - أنواع الحركات / Transaction Types

- Registry: system 3 serial 218, menu `CODES_MENU.ST_TRNS_TYPE`. Legacy module `ASCON\ST\FMB\st_trns_type_st.fmx` (no .fmb: evidence
  is the embedded SQL, the texts and the GN_FORM_ITEM labels).
- APEX: pages 20250 / 20251 (+ print 20252), `MASTER_DETAIL` master `ST_TRNS_TYPE`, detail `STACLNK` "بيانات القيود المرتبطة بالحركة"
  (entry lines of the type). Override `overrides\ST_TRNS_TYPE_ST.json` (AUTO) adds the legacy block filter, the page validation, the
  last-serial panel and the button "نسخ الحركة".
- Package `APP_RULES3_ST`: `val_trns_type`, `trns_type_delete`, `staclnk_delete`, `trns_type_last_serial`, `copy_trns_type`,
  `trns_type_allowed`; delete hooks `APP_RULES3_ST_TRNS_TYPE_BD` (ST_TRNS_TYPE, only when the page is ST_TRNS_TYPE_ST) and
  `APP_RULES3_ST_STACLNK_BD` (STACLNK, only for the page's DELETE request).
- Data: 57 transaction types, 33 of them in this screen's range; 99 `STACLNK` lines; `ST_TRNSTYPE_PASSWORD` empty.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| The screen shows stock types only: `EFFECT IN (1,2,5,6,7) AND TRNS_TYPE IN (7,8,9,12,15,40)` and, for a permission group, types with `ST_TRNSTYPE_PASSWORD.FLAG = 1` | block WHERE `EFFECT IN (1,2,5,6 , 7 ) AND TRNS_TYPE IN (7,8,9,12,15 , 40) AND (:1 = 0 OR (TRNS_TYPE_CODE IN (SELECT TRNS_TYPE_CODE FROM ST_TRNSTYPE_PASSWORD WHERE FLAG=1 AND PASSWORD_NUMBER=:2)))` | `where` | high |
| New / changed types stay in that range (the legacy radio groups offered only these values) | radio groups وارد / صادر / تحويل من / تحويل إلى / بدون تأثير and تسوية / رصيد افتتاحى / تحويل / تجميع / تأثير على الكمية فقط / حركة تكوين شحنات | `val_trns_type` "نوع الحركة غير مسموح به" (**new text**: the legacy had no message, the radio groups made other values impossible) | medium |
| Duplicate code: "هذا الكود موجود من قبل" | `SELECT TRNS_TYPE_CODE FROM ST_TRNS_TYPE WHERE TRNS_TYPE_CODE = :b1`, message | `val_trns_type` (CREATE) + primary key | high |
| Store required for transfer and transfer-receipt types: "لا يمكن الحفظ بدون مخزن في حركات التحويل و استلام التحويل" | message | `val_trns_type` when `TRNS_TYPE = 9` and `EFFECT IN (5,6)` | medium (condition inferred from the message and the radio values) |
| A type with documents cannot change: "لا يمكن تعديل الحركة لأنة لها حركات مرتبطة و مرحلة" | `SELECT COUNT(1) FROM ST_TRNS_MAST WHERE TRNS_TYPE_CODE = :b1`, message | `val_trns_type`: code, `EFFECT` and `TRNS_TYPE` locked when documents exist | medium (which fields were locked is not visible) |
| Delete refused with documents: "لا يمكن حذف السجل حيث توجد حركات معتمدة عليه بالنظام" | `SELECT COUNT(1) FROM ST_TRNS_MAST WHERE TRNS_TYPE_CODE = :b1`, message | `APP_RULES3_ST_TRNS_TYPE_BD` / `trns_type_delete` | high |
| Delete refused while the type has entry lines: "لا يمكن إلغاء سجل رئيسي في و جود سجلات تابعة له" | `SELECT 1 FROM STACLNK WHERE TRNS_TYPE_CODE = :b1` (non-isolated relation), message | `APP_RULES3_ST_STACLNK_BD` / `staclnk_delete` (the page deletes the lines first; the hook refuses that when the request is the master DELETE) | high |
| آخر مسلسل للحركة | `SELECT NVL(MAX(TRNS_SERIAL),0) FROM ST_TRNS_MAST WHERE TRNS_TYPE_CODE = :b1 AND NVL(DELETE_FLAG,0) = 0` | `info` LAST_SERIAL | high |

## Buttons

| Legacy | APEX | Confidence |
|---|---|---|
| نسخ الحركة: new code `NEW_TRNS_TYPE_CODE`; "يجب إدخال رقم الحركة الجديدة", "رقم الحركة الجديد موجود بالفعل"; copies the type row and its `STACLNK` lines; "تم نقل الحركة" | action `COPY_TYPE` (number parameter) -> `copy_trns_type`: same checks, the same two `INSERT ... SELECT` statements (same column lists), opens the new type | high |

## Tests (rolled back, `tmp\w3_st\t_rules3_st.py`, 188/188 passed in the final run)

F1 duplicate code, effect / type outside the screen, store required for transfer types, valid new type, effect locked for a type with
documents, unchanged type saves; F2 copy 11101 -> 99902 (type and entry lines), copy to an existing code / without code refused;
F3 master delete with lines refused, type without documents deleted, type with documents refused; F4 last serial.

## Open questions

- Which fields the legacy locked with "لا يمكن تعديل الحركة لأنة لها حركات مرتبطة و مرحلة" (assumed: code, effect, type).
- (wave 3b, mostly answered) Value-to-label mapping: done for EFFECT, TRNS_TYPE, JOIN_TYPE, POST_TYPE, ACCOUNT_NO_TYPE, COST_NO_TYPE,
  ACCOUNT_IND; still open for `VALUE_TYPE`, `TRNSFR_COST_TYPE` and the "بدون" account indicator.

## Wave 3b (new generator keys)

Evidence: the .fmx radio texts and block WHERE, the posting code that reads the values (`app\db\20_proc_st.sql`: JOIN_TYPE 1 =
not linked, POST_TYPE 1 / 2 / 3, COST_NO_TYPE 1-6, ACCOUNT_IND 2 = credit, ACCOUNT_NO_TYPE 1-12 / 15), the embedded LOV SQL, the data
(effect 5 = "تحويل صادر", 6 = "تحويل وارد", 7 = requests / quantity-only receipts; type 7 = adjustments, 8 = opening balances, 9 =
transfers, 12 = item requests, 15 = incoming lots).

| Change | Key |
|---|---|
| `EFFECT` radio وارد 1 / صادر 2 / تحويل من 5 / تحويل إلى 6 / بدون تأثير 7, label "التأثير على المخزون" | `columns.ST_TRNS_TYPE.EFFECT` |
| `TRNS_TYPE` radio تسوية 7 / رصيد افتتاحى 8 / تحويل 9 / تجميع 12 / تأثير على الكمية فقط 15 / حركة تكوين شحنات 40 | `columns.ST_TRNS_TYPE.TRNS_TYPE` |
| `JOIN_TYPE` radio غير مرتبط 1 / بالحسابات 2 "الربط بالأنظمة الأخرى"; `POST_TYPE` radio قيد لكل حركة 1 / قيد لكل نوع حركة 2 "نوع الترحيل" (added to the page) | `columns` |
| `ENTRY_TYPE` "توصيف القيود" (entry types with AC_PASSWORD_ENTRY), `REC_TRANSFER_TRNS` "حركة الاستلام التلقائي" (types TRNS_TYPE 9 / EFFECT 6 with the type permissions), basic store (leaf stores with the store permissions) | `columns.*.lov` |
| Entry lines: account indicator list (1 إدخال الرقم, 2-5 store accounts 1-4, 6-9 التوجيه المحاسبى 1-4, 10 ملف العملاء, 11 ملف الموردين, 12 receiving store stock account, 15 ملف المجموعات), cost-centre 1 / 2 indicators (1 إدخال, 2 ملف المخازن, 3 ملف الحركات, 4 ملف المجموعات, 5 المخزن المحول إليه, 6 بدون), debit / credit (1 مدين, 2 دائن), permission-filtered account and cost-centre lists; labels "مؤشر رقم الحساب", "مؤشر القيمة", "المديونية" | `columns.STACLNK.*` |

Confidence: high for EFFECT / JOIN_TYPE / POST_TYPE / ACCOUNT_IND / COST_NO_TYPE (values read by the posting code), medium for
TRNS_TYPE 12 / 15 (by the data and the text order) and for ACCOUNT_NO_TYPE labels 6-11 (value meaning from the posting code, text from
the .fmx list). Not done: `VALUE_TYPE` list (values 1-16, 35-37, 60, 61 in the posting code; the .fmx texts cannot be matched to all of
them), `TRNSFR_COST_TYPE` (متوسط التكلفة / سعر البيع / اخر سعر شراء: the values are not visible), the "بدون" entry of the account
indicator (value unknown), `CUSTOMER_TRNS_CODE` / `SUPPLIER_TRNS_CODE` (no LOV SQL in this .fmx). All list queries run
(`sqlcheck.py`).

## Coverage

- Reproduced: filter, duplicate / range / store / lock checks, delete checks, last serial, copy button.
- Not reproduced / not shown:
  - `TRNSFR_COST_TYPE`, `CUSTOMER_TRNS_CODE`, `SUPPLIER_TRNS_CODE` (values / lists not visible in the evidence; the data has no
    customer / supplier link for these types) and the `VALUE_TYPE` list (see question);
  - wave 3b added `ENTRY_TYPE`, `JOIN_TYPE`, `POST_TYPE`, `REC_TRANSFER_TRNS`, the radio lists, the entry-line lists and the
    "التأثير على المخزون" label.
