# ST_BASIC - بيانات خاصة بالنظام / System Parameters

- Registry: system 3 serial 501 (also system 30 serial 23, system 31 serial 25), menu `SYSTEM_MENU.STBASIC`. Legacy module
  `ASCON\ST\FMB\ST_BASIC.fmx` (no .fmb: evidence is the embedded SQL, the texts and the GN_FORM_ITEM labels).
- APEX: pages 20260 / 20261, `REPORT_FORM` on `ST_BASIC` (one row). Override `overrides\ST_BASIC.json` (AUTO) adds the validation, the
  "continue?" warnings and the flags that have no GN_FORM_ITEM prompt (labels taken from the .fmx texts).
- Package `APP_RULES3_ST`: `val_basic`, `basic_warning`.
- Data: one row (`SERIAL` 1): `SINGLE_ITEM` 0, `POST_TYPE` 4, `DOC_REPEAT` 1, `TRNS_MAX_ITEMS` 999, `EXPIRE_FLAG` 1, `COLOR_FLAG` 0,
  `SIZE_FLAG` 0, `GROUP_PRE_CODE` 0, `AUTO_ITEM_SER` 0, `STOCK_STAND_ITEM` 0, `INSERT_SALE_CNFG` 1, `MIN_PROFIT` 0.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| One record only: "لا يمكن إنشاء سجلات إخرى" | `SELECT COUNT(1) FROM ST_BASIC`, message | validation `val_basic` (CREATE) | high |
| Maximum items per document > 0 or empty: "القيمة يجب أن تكون أكبر من صفر أو خالية." | message next to الحد الأقصى للأصناف فى الحركات | `val_basic` on `TRNS_MAX_ITEMS` | medium (the item the message belongs to is inferred) |
| Changing a document flag while documents exist asks "توجد حركات بالفعل بالنظام - هل تريد تغيير المؤشر الآن" | `SELECT COUNT(*) FROM ST_TRNS_MAST WHERE DELETE_FLAG != 1` (three times), texts "توجد حركات بالفعل بالنظام", "هل تريد تغيير المؤشر الآن", alert "سؤال المستخــدم" | `warnings` SINGLE_ITEM, POST_TYPE, DOC_REPEAT (`basic_warning`) | medium (which three flags is inferred) |
| Changing the assembled-items flag while assembled items have movements: "يوجد بعض الاصناف المجمعة عليها حركات" | `SELECT COUNT(1) FROM ST_TRNS_DET WHERE (GROUP_CODE, ITEM_CODE) IN (SELECT ... FROM ST_ITEM WHERE NVL(STAND_FLAG,0) = 1)` | warning STOCK_STAND_ITEM | high |
| Switching off expiry / size / colour while groups use it: "يوجد بعض المجموعات عليها تاريخ صلاحية" / "... مقاس" / "... لون" | `SELECT COUNT(1) FROM ST_ITEM_GROUP WHERE NVL(EXPIRE_FLAG / SIZE_FLAG / COLOR_FLAG, 0) = 1`, messages | warnings EXPIRE_FLAG, SIZE_FLAG, COLOR_FLAG (only when the new value is 0) | medium |
| Flags without prompts are editable in the legacy (radio groups) | GN_FORM_ITEM `[R]` items with empty prompts, .fmx texts | `add_columns` with the .fmx texts as labels | high (labels), medium for the store-type trio (see questions) |

## Tests (rolled back, `tmp\w3_st\t_rules3_st.py`, 188/188 passed in the final run)

G1 second record refused, `TRNS_MAX_ITEMS` 0 refused, valid save; G2 warning when `SINGLE_ITEM` changes with documents, none when
unchanged, warning when expiry is switched off while groups use it, none for the assembled-item flag without movements.

## Open questions

- Which three flags asked "توجد حركات بالفعل بالنظام" (assumed `SINGLE_ITEM` / تكرار الصنف, `POST_TYPE` / نوع الترحيل, `DOC_REPEAT` /
  تكرار رقم المستند - the flags whose texts sit next to the message).
- `TRNS_MAX_ITEMS` as the target of "القيمة يجب أن تكون أكبر من صفر أو خالية." (only numeric parameter whose wording fits).
- Labels of `GNRLZ_STORE` / `DISTRB_STORE` / `DMG_STORE` ("نوع مستودع الاستلام" / "نوع مستودع التوزيعات" / "نوع مستودع منتهى الصلاحية")
  are matched by order of the .fmx texts; the list of values is `ST_STORE_TYPE` ("أنواع المخازن").
- (fixed in wave 3b with `label_a`) The GN_FORM_ITEM label of `AUTO_ITEM_SER` is garbage ("يبيب / dffdf"); the .fmx text is "مسلسل آلى للصنف" (was a translation fix,
  outside this agent's files).

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| `AUTO_ITEM_SER` label "مسلسل آلى للصنف" (GN_FORM_ITEM label was garbage) | `columns.ST_BASIC.AUTO_ITEM_SER.label_a` | .fmx text / label AUTO_TXT |
| `POST_TYPE` radio قيد لكل حركة 1 / قيد لكل نوع حركة 2 / قيد واحد مجمع 3 / كما هو محدد فى ملف الحركات 4 | `POST_TYPE.static` (RADIO) | .fmx texts in this order; posting code values 1-3; data 4 |
| Expiry / size / colour flags as check boxes (1 / 0) | `widget: CHECK` | SIZE_FLAG_B / COLOR_FLAG_B are check boxes (GN type C); expiry by analogy (same flags are check boxes on ST_GROUP) |
| Basic store: leaf stores not stopped | `BASIC_STORE_CODE.lov` | .fmx SQL `... FROM ST_STORE WHERE STORE_STATUS =1 and NVL(STOP_FLAG,0) = 0` |
| Receiving / distribution / expired store types: store-type list | `GNRLZ_STORE`, `DISTRB_STORE`, `DMG_STORE` `lov` | .fmx SQL `SELECT STORE_TYPE, DESC_A, DESC_E FROM ST_STORE_TYPE` (three LOVs "أنواع المخازن") |

Not changed: the other radio groups (`SINGLE_ITEM`, `SKIP_MAST`, `SHOW_COST`, `RLTD_TRNS_STR_FLAG`, `EST_FLAG`, `UPDATE_SALE_PRICE`,
`AUTO_ITEM_SER`): the .fmx has no button texts for them (values 0 / 1 in the data, labels unknown), they stay number fields.

## Coverage

- Reproduced: single record, maximum items check, all "continue?" alerts as page warnings, the unlabelled flags.
- Not reproduced:
  - `SRV_SUPP_CODE` (مورد الخدمات) and `GRAND_STORE_CODE` (المخزن الرئيسي) prompts - no such columns in SMART's `ST_BASIC`;
  - radio lists of `SINGLE_ITEM`, `SKIP_MAST`, `SHOW_COST`, `RLTD_TRNS_STR_FLAG`, `EST_FLAG`, `UPDATE_SALE_PRICE`, `AUTO_ITEM_SER`: no
    button texts in the .fmx (number fields). Wave 3b added the store / store-type lists, the `POST_TYPE` radio and the flag check boxes.
