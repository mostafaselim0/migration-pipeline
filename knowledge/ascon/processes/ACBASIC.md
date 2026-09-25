# ACBASIC - مؤشرات النظام / System Parameters (GL)

- Registry: system 1 serial 75 (SYSTEM_MENU.ACBASIC, order 4001). APEX list 10190, form 10191.
- Legacy module: `ASCON\AC\FMB\Acbasic.fmx` (no .fmb; three tab pages مؤشرات الحسابات / مؤشرات النظام / مؤشرات مراكز التكلفة).
- **Deliverable: generated report + form kept (`AUTO`) + rules**, override `app\legacy\overrides\ACBASIC.json`, PL/SQL `APP_RULES3_GL`.
- **Confidence: high** for the closing-date and date checks, medium for the account checks (see question 1).

## Screen correction

The generated form missed the radio groups and the check boxes without GN_FORM_ITEM prompts. Added with `add_columns` and the
prompts of the .fmx: CURRENCY_STTS (عمـلـة واحـدة / عمــلات مخـتـلـفـة), DOC_REPEAT (تكـرار رقـم المستنـــد; 1 / 2 / 3 as used by
APP_RULES_GL), COST_CODE1_ENTER / COST_CODE2_ENTER (إدخال مركز التكلفة 1 / 2 فى شاشة القيود: إجبارى / إختيارى), FX_USR_ENTRY /
FX_USR_COST1 / FX_USR_COST2 (تثبيت ... كما هو معرف للمستخدم), BALANCE_ENTRY_FLAG (عدم السماح بادخال قيود غير متزنة - read by the
ACDLYTR rules), STOP_ESTIMATE_TEST (ايقاف الحساب اذا تعدى الموازنة), REV_FLAG (مراجعة القيود - read by AC_YEARLY_REV), BANK_ACCT (حساب البنك).
List and form show the row of the session company (`COMPANY_CODE = :G_COMPANY_CODE`, read-only, default the session company).

## Rules

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | Closing date: no unposted GL entry of the company on or before it ("توجد قيود غير مرحلة قبل هذا التاريخ"), no unposted customer / stock / supplier document ("توجد قيود غير مرحلة فى نظام العملاء / المخازن / الموردين قبل هذا التاريخ") | CHECK_CLOSE_DATE (AC_DAILY_TRN), CHECK_CLOSE_STORES (AR_MAINTRNS, ST_TRNS_MAST, VN_MAINTRNS POST_FLAG = 0) | validation `check_basic` when the date is new or changed |
| 2 | Maximum date after the minimum date ("يجب إدخال تاريخ أكبر منالحد الأدني للحركات!!") | MIN_DATE / MAX_DATE validation | validation |
| 3 | P&L, currency-difference and cost-centre current accounts must be sub accounts ("الحساب ليس حساب فرعى") | `SELECT COUNT(1) FROM AC_MASTER WHERE ACCOUNT_NUMBER = :b1 AND ACCOUNT_STATUS = 1` per item | validation |
| 4 | Revenue / expense accounts: main accounts of the structure (prompts "رقم حساب الإيرادات / المصروفات الرئيسى فى الهيكل المحاسبى") | prompts; data 400000000000 / 300000000000 are level-1 accounts | validation: the account must exist ("رقم الحساب غير موجود فى دليل الحسابات" - new text) |
| 5 | Single currency cannot be chosen while entries in other currencies exist | PRE-FORM: `COUNT(1) FROM AC_YEARLY_TRN / AC_OPENING_BALANCE WHERE CURRENCY_CODE != 1` | validation (new text; the legacy disabled the choice) |
| 6 | One parameter row per company | PRE-FORM `SELECT COUNT(1) FROM AC_BASIC WHERE COMPANY_CODE` | PK + `where` |

## Tests (section F of `tmp\w3_gl\gl\t_gl.py`, 6 checks)

Current parameters valid; closing date 31/12/2026 refused (114 unposted customer transactions); max <= min refused; main account
as P&L account refused; unknown revenue account refused; single currency accepted (no foreign-currency entries). Passed.

## Open questions

1. The revenue-account check of the legacy (`... AND NVL(:b2,0) = 1`) and the expense-account check (`ACCOUNT_STATUS = 1`) would
   refuse the stored main accounts 400000000000 / 300000000000; APEX only checks that they exist. Confirm.
2. FX_USR_ENTRY / FX_USR_COST1 / FX_USR_COST2: the login menu treats 2 as "no" and every other value as "yes"; APEX shows 1 = نعم,
   2 = لا, 3 = سؤال المستخدم (the order of DOC_REPEAT). Confirm the value of "سؤال المستخدم".

## Wave 3b (radio groups, check boxes, lists)

| Item | Legacy | Evidence | APEX |
|------|--------|----------|------|
| CURRENCY_STTS | radio عملة واحدة (ONE) / عملات مختلفة (MORE) | GN_FORM_ITEM_RAD; values: CURRENCY_STTS = 0 allows only the local currency (ACDLYTR PRE-FORM / CONTROL.CURRENCY_CODE) | `static` + `RADIO`: 0 / 1 |
| DOC_REPEAT | radio نعم / لا / سؤال المستخدم | GN_FORM_ITEM_RAD; ACDLYTR: 2 refuses a repeated number, 3 asks, 1 no check | 1 / 2 / 3 |
| COST_CODE1_ENTER, COST_CODE2_ENTER | radio اجباري / اختياري | GN_FORM_ITEM_RAD; ACDLYTR COST_CODE WVI: `COST_CODE1_ENTER = 0` -> 'إدخاال مركز التكلفة 1 إجبارى' | 0 = mandatory / 1 = optional |
| FX_USR_ENTRY, FX_USR_COST1, FX_USR_COST2 | radio نعم / لا / سؤال المستخدم | GN_FORM_ITEM_RAD; Sysmenu2.fmx `DECODE(FX_USR_ENTRY, 2, 0, 1)` (2 = off) | 1 / 2 / 3 (YES / NO / ASK as DOC_REPEAT; data 1) - medium confidence, question 2 |
| BALANCE_ENTRY_FLAG, STOP_ESTIMATE_TEST, REV_FLAG | check boxes without GN_FORM_ITEM prompts | .fmx prompts; ACDLYTR reads BALANCE_ENTRY_FLAG / STOP_ESTIMATE_TEST = 1; data 0 / 1 | `widget: CHECK` 1 / 0 |
| INCOME1_ACCT, OUTCOME1_ACCT, PROFIT_ACCT, CURRENCY_ACCT, COST_CODE_ACCT1 / 2 | account lists (INCOME_LOV, OUTCOME_LOV, PROFIT_LOV ...; names INCOME_DESC ... shown) | record group `select account_number, account_name ... from ac_master` + AC_PASSWORD_MASTER | `lov` (pop-up "number - name") |
| DISTP_ENTRY | list ENTRY (journals `NVL(AC_FLAG,0) = 0` of the group), name DISTP_NAME | record group | `lov` (select list "type - name") |

The labels no longer carry the meaning in brackets (the lists show it). The radio / list labels are in Arabic and English (third element).

## Coverage

- Reproduced: rules 1-6, the missing parameter items, the radio groups, check boxes and lists (wave 3b).
- Not reproduced: enabling / disabling items (EST_CODE with ESTIMATE_TEST, balancing flags) - Forms UI.
