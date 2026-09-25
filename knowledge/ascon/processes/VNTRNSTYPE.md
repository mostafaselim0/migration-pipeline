# VNTRNSTYPE - ملف أرقام الحركات / AP Transaction Codes File

- Registry: system 5 serial 25 (menu `CODES_MENU.ARTRNSTYPE`, order 207). APEX report page 40120, form page 40121.
- **Deliverable: generated report + form kept (`"pattern": "AUTO"`) + rules** - `app\legacy\overrides\VNTRNSTYPE.json`, package
  `APP_RULES3_VN` (trnstype_row, trnstype_locked).
- **Confidence: medium** - compiled form only (SQL, texts, item names); the list values are deduced from the texts and the 11 existing types
  (101/102 purchases 0-credit, 103 credit settlement 4, 201/206 payments 1-debit, 202/207/208 debit settlements 4, 205 returns 3-debit,
  901/902 opening balances 5).

## Evidence (`evidence\VNTRNSTYPE.md`, compiled `VN\FMB\vntrnstype.fmx`)

- ID: `CHK_UNIQ` / `TEST_DUPLICATE` ("كود مكرر من قبل", "لقد تم إدخال هذا الكود من قبل"), "يجب إدخال حقل", "رقم الحركة يجب ان يكون اكبر
  من الصفر".
- Lists: EFFECT مدين / دائن; TRNS_TYPE مشتريات / دفعات / مردودات / تسوية / أخرى; DESC_FLAG (إظهار شرح الحركة / رقم المستند، إظهار شرح
  الحركة فقط، إخفاء شرح الحركة - VNDBTRN.fmb: 1 = description - doc no, 2 = description, 3 = none); account directions (لا يوجد رقم حساب،
  رقم حساب المنطقة الرئيسية / الفرعية، رقم حساب المورد، رقم حساب نوع الحركة، رقم حساب الحركة); cost-centre directions; COST_FLAG (8 texts,
  data 8 = "بدون"); POST_TYPE قيد لكل حركة / قيد لكل نوع حركة; SUPPLIER_TYPE مورد / مقاول; check boxes DOC_FLAG, SUM_TRNS, DISC_TRNS,
  ACCOUNT_JOINT.
- TRNS_TYPE WHEN-VALIDATE-ITEM and PRE-INSERT / PRE-UPDATE: "نوع الحركة غير متوافق مع تأثير الحركة على المورد"; PRE-INSERT / PRE-UPDATE with
  ACCOUNT_JOINT: "يجب إدخال التوجية المحاسبى للحركة و المورد و الخصم", "يجب إدخال نوع الحساب" (entry type), "يجب إدخال حساب نوع الحركة",
  "يجب إدخال حساب العميل" (supplier account; text copied from AR), "يجب إدخال حساب الخصم".
- Account WHEN-VALIDATE-ITEM: "لا يمكن تكرار رقم حساب نوع الحركة / المورد / الخصم مع الحسابات الاخرى"; ENTRY_TYPE: "يجب إدخال رقم نوع حركة
  فى الحسابات صحيح و لك صلاحيات إستخدامه".
- WHEN-NEW-RECORD-INSTANCE: `SELECT COUNT(1) FROM VN_MAINTRNS WHERE TRNS_ID = :ID AND POST_FLAG = 1` then SET_ITEM_PROPERTY on the items
  EFFECT, DESC_FLAG, TRNS_TYPE, DESCRIPTION_A, DESCRIPTION_E, ID, DOC_FLAG, ACCOUNT_NO, SUPPLIER_ACCOUNT, DISC_ACCOUNT, COST_NO, COST_NO2
  (non-updatable once posted transactions exist; the directions are read by the block, not locked).
- Block WHERE: `(ID IN (SELECT TRNS_ID FROM VN_TRNSTYPE_PASSWORD WHERE FLAG = 1 AND PASSWORD_NUMBER = :1) OR :2 = 0)`.

## Rules

| Rule | APEX |
|---|---|
| Group filter | `where` (VN_TRNSTYPE_PASSWORD) |
| Code required (no numbering) and > 0 | `key_expr` `need_num('يجب إدخال حقل كود نوع الحركة')`, `trnstype_row` |
| Purchases (0) credit the supplier (effect 1); payments (1) and returns (3) debit him (effect 0) | `trnstype_row` (legacy text) |
| GL link: directions, voucher type, type / supplier / discount account for direction 4 | `trnstype_row` (legacy texts) |
| Voucher type exists; accounts distinct; accounts and cost centres active | `trnstype_row` |
| Effect, type, description flag / texts, document flag, accounts and cost centres locked once posted transactions exist | row rule on update -> `trnstype_locked` (own text; legacy made the items non-updatable) |
| VN_TRNSTYPE updated by other screens (VNCRTRN / VNDBTRN numbering LAST_SERIAL) | rules guarded by `is_form('VNTRNSTYPE')` |
| Labels of the list columns with their values; missing items POST_TYPE, SUPPLIER_TYPE, SUM_TRNS, DISC_TRNS | `add_columns` |

Tests (t_vn1): code required / -3 refused; effect 0 with purchases and effect 1 with payments refused; GL link without directions, without
voucher type, unknown voucher type, direction 4 without type / supplier / discount account refused; repeated accounts refused; unknown
account refused; valid linked type accepted; change of a type without posted transactions accepted; unchanged re-save of 201 accepted;
description change of 201 (posted transactions) refused; update from the VNCRTRN page not checked. 18/18 passed.

## Open questions

1. Values of the list items are deduced (EFFECT 0/1, TRNS_TYPE 0/1/3/4/5, directions 0-5, cost directions 0/4/5, COST_FLAG 1-8 with 8 =
   none): please confirm, especially COST_FLAG / COST_FLAG2.
2. The effect / type compatibility is the AR rule mirrored for suppliers (checked on all 11 types); confirm that "settlement" (4) and "other"
   (5) may have both effects.

## Coverage

Reproduced: all validations, the lock after posting, the group filter. Not reproduced: the "تعامل الحركة" button (canvas navigation of the
legacy form, no logic), description / account name display items, HIDE_DISC_ACCOUNT (display), print (vntrnstype_REP), toolbar. Generator
gaps: list items render as number fields (no per-column static list), the direction columns are labelled with their values instead.
