# LC_SETTEL - ارقام الدفعات / Payment Types (طرق السداد)

- Registry: system 5 serial 39 (no menu name, order 208). APEX grid page 40130.
- **What the legacy screen edits:** table `LC_SETTEL_TYPE` only (payment types with their payment / allowed-discount accounts and cost
  centres). The .fmx references 13 tables because its LOVs read AC_MASTER / AC_COST_CENTERS(2) and its delete check reads LC_CREDIT,
  LC_CREDIT_OPEN, VN_MAINTRNS and VN_SUBTRNS; the generated grid on LC_SETTEL_TYPE is the right table.
- **Deliverable: generated grid kept (`"pattern": "AUTO"`) + rules** - `app\legacy\overrides\LC_SETTEL.json`, package `APP_RULES3_VN`
  (settel_row, next_settel_code, settel_del + trigger `APP_RULES3_VN_SETTEL_BD`).
- **Confidence: high** (SQL and texts of the .fmx; 1 row, code 1 used by all VN_MAINTRNS / VN_SUBTRNS rows and by VN_BASIC.PAY_TYPE_CODE).

## Evidence (`evidence\LC_SETTEL.md`, compiled `VN\FMB\lc_settel.fmx`)

- `CHK_MASTER_UNIQ` (`SELECT COUNT(1) FROM LC_SETTEL_TYPE WHERE SETTEL_TYPE_CODE = :b1`, "كود مكرر"); SETTEL_TYPE_CODE
  WHEN-VALIDATE-ITEM "رقم طريقة السداد يجب ان يكون اكبر من الصفر"; WHEN-CREATE-RECORD `SELECT NVL(MAX(SETTEL_TYPE_CODE),0)+1`.
- LOVs: active accounts (ACCOUNT_STATUS = 1, AC_PASSWORD_MASTER), active cost centres 1 / 2 (COST_STATUS = 1, group filters).
- Delete (KEY-DELREC): `SELECT COUNT(1) FROM LC_CREDIT / LC_CREDIT_OPEN WHERE SETTEL_TYPE_CODE`, `... FROM VN_MAINTRNS / VN_SUBTRNS WHERE
  PAY_TYPE_CODE` with "لا يمكن حذف السجل التالى لوجود ارتباط مع ملف الاعتماد الرئيسي", "... مع ملف فتح الاعتماد",
  "لايمكن مسح السجل لوجود ارتباطات بملف الموردين".
- Labels of the form: مسلسل، البيان عربى، البيان لاتينى، رقم الحساب، حساب الخصم المسموح بة، مركز تكلفة1، مركز تكلفة2. NON_PAY_FLAG is
  not an item of the form.

## Rules

| Rule | APEX |
|---|---|
| Code = max+1 (the generator does not number `*_TYPE_CODE` keys) | `key_expr` `next_settel_code`, column optional |
| Code > 0 | row rule `settel_row` |
| Payment / discount account active, cost centres active | `settel_row` (`check_account`, `check_cost`) |
| Delete refused while letters of credit or supplier transactions use the type | delete trigger `APP_RULES3_VN_SETTEL_BD` -> `settel_del` (legacy texts) |
| Labels | `add_columns` with the legacy prompts; NON_PAY_FLAG hidden (not on the form, default 0) |

Tests (t_vn1): empty code -> max+1; code -2 refused; account 1 refused, active account accepted; delete of type 1 refused
("لايمكن مسح السجل لوجود ارتباطات بملف الموردين"); delete of the new unused type accepted. 6/6 passed.

## Coverage

Reproduced: numbering, code > 0, account / cost-centre validity, delete protection with the legacy texts, labels. Not reproduced:
print (LC_SETTEL.rdf), "ترجمة" and toolbar buttons (Forms-only). Generator gap: the account columns are popup LOVs on all AC_MASTER
rows (no group filter / status filter on the LOV); the row rule refuses inactive accounts at save.
