# VN_BASIC - مؤشرات النظام / AP System Parameters

- Registry: system 5 serial 30 (menu `SYSTEMS_MENU.SYSTEM_PARAMETERS`, order 401). APEX grid page 40150.
- **Deliverable: generated grid kept (`"pattern": "AUTO"`) + rules** - `app\legacy\overrides\VN_BASIC.json`, package `APP_RULES3_VN.basic_row`.
- **Confidence: medium** - one parameter record (SERIAL 1: MIN_DATE 22/12/2021, MAX_DATE 01/01/2030, PAY_TYPE_CODE 1, CONTRACT_FLAG 0,
  COST_CODE_FLAG 0); the date-limit messages are clear, the use of two alerts is not (see questions).

## Evidence (`evidence\VN_BASIC.md`, compiled `VN\FMB\VN_BASIC.fmx`)

- Block WHERE `SERIAL = :1` (GLOBAL.COMPANY_CODE) and a trigger assigning `:SERIAL` from `:GLOBAL.COMPANY_CODE`: one record per company.
- MIN_DATE / MAX_DATE WHEN-VALIDATE-ITEM (locals V_MIN_DATE / V_MAX_DATE, library TRANSLATE): "التاريخ لا يمكن ان يكون اكبر من ",
  "التاريخ لا يمكن ان يكون أصغر من ", "أصغر تاريخ لا يمكن ان يكون اكبر من اقصى تاريخ".
- LOVs: active accounts (SRV_SUPP_ACC "رقم حساب فروق اسعار"), AC_TRN_CODES (SRV_YEAR + SRV_ENTRY "سنة و قيد الترحيل"), LC_SETTEL_TYPE
  (PAY_TYPE_CODE "رقم الدفعة العامة بالمشتريات"); check boxes CONTRACT_FLAG "تحتوي علي عقود موردين", COST_CODE_FLAG "ادخال مركز تكلفة 1
  للحركات".
- Five toolbar triggers run `SELECT COUNT(*) FROM ST_BASIC` (copied from the stock parameters form); alerts "توجد حركات بالفعل بالنظام" /
  "هل تريد تغيير المؤشر الآن" and the hint "القيمة يجب أن تكون أكبر من صفر أو خالية." exist in the module.
- The parameters are read by the AP rules of wave 2 (MIN_DATE / MAX_DATE, PAY_TYPE_CODE, CONTRACT_FLAG, COST_CODE_FLAG) and by CHECK_DATE
  (library TRANSLATE, system 5: MIN(VN_BASIC.MIN_DATE)).

## Rules

| Rule | APEX |
|---|---|
| One record per company | `where` SERIAL = G_COMPANY_CODE; `key_expr` SERIAL = company (a second record -> duplicate key) |
| Minimum date <= maximum date | row rule `basic_row`: "أصغر تاريخ لا يمكن ان يكون اكبر من اقصى تاريخ" |
| Posting year + voucher type exist (LOV) | `basic_row` |
| Price-difference account active (LOV) | `basic_row` |
| Payment type exists (LOV) | `basic_row` (+ FK VN_BASIC_FK) |
| Missing items | `add_columns`: SRV_YEAR, SRV_ENTRY (label), PAY_TYPE_CODE, COST_CODE_FLAG |

Tests (t_vn1): minimum after maximum refused; unknown posting voucher refused, existing one accepted; account 1 refused; a new record gets
SERIAL = company and is refused as duplicate. 5/5 passed.

## Open questions

1. The two other date messages ("التاريخ لا يمكن ان يكون اكبر من / أصغر من <date>") compare with V_MIN_DATE / V_MAX_DATE whose source is not
   visible in the .fmx (no SQL in that trigger): which bounds apply?
2. Is "توجد حركات بالفعل بالنظام - هل تريد تغيير المؤشر الآن" a confirmation when CONTRACT_FLAG / COST_CODE_FLAG change while transactions
   exist? (In a grid page a confirmation is not available; see generator gaps.)
3. Which item carries the hint "القيمة يجب أن تكون أكبر من صفر أو خالية."?

## Coverage

Reproduced: single record per company, date order, LOV validity, all legacy items. Not reproduced: the unclear confirmation / date-bound
alerts (questions above; warnings exist only on document and pop-up form pages), print (VN_BASIC.rdf), toolbar (Forms-only). AUTO_SERIAL
(supplier auto-numbering of the old supplier form) is not an item of this form and stays hidden.
