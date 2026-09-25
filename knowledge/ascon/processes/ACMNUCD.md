# ACMNUCD - إعداد القوائم المالية / Financial Reports Preparation

- Registry: system 1 serial 81 (FILES_MENU.REPORT_GEN, order 1203). APEX list 10070, statement page 10071, print 10072.
- Legacy module: `ASCON\AC\FMB\Acmnucd.fmx` (no .fmb): statement header AC_MENUS and lines AC_FINAL_ACCOUNT (financial statements
  generator: ACTION indicator from AC_MENUCD_IND, account, cost centres, description, totals position, sign, numerator / denominator).
- **Deliverable: generated master-detail kept (`AUTO`) + rules**, override `app\legacy\overrides\ACMNUCD.json`, PL/SQL `APP_RULES3_GL`,
  statement trigger `APP_RULES3_GL_FINACC_AS`.
- **Confidence: high** for the duplicate and numerator / denominator rules (SQL + messages).

## Rules

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | Statement number MAX + 1 | `SELECT NVL(MAX(MENU_CODE)+1,1) FROM AC_MENUS` | generated max+1 (read-only item) |
| 2 | Account + cost centres not repeated in a statement ("رقم الحساب و مركزى التكلفة لا يمكن ان يتم تكرارهم") | four COUNT(1) cases on AC_FINAL_ACCOUNT (null-safe cost centres) | after_save `final_account_after_save` |
| 3 | Numerator / denominator: an earlier line (SER < this SER) with totals position 0, not the other one of the pair | NOM_LOV / DENOM_LOV record groups | after_save (new text "البسط والمقام يجب أن يكونا من السطور السابقة ذات الاجماليات صفر") |
| 4 | A line used as numerator or denominator cannot be deleted or renumbered ("لايمكن التعديل او الحذف لاشتراكها في باسط او مقام") | `COUNT(1) ... WHERE MENU_CODE AND (NOM = :b2 OR DENOM = :b2)` + text | after-statement trigger (dangling NOM / DENOM refused) |
| 5 | Deleting a statement deletes its lines | PRE-DELETE `DELETE FROM AC_FINAL_ACCOUNT WHERE MENU_CODE` | generated line delete |

## Tests (section I of `tmp\w3_gl\gl\t_gl.py`, 6 checks)

Existing statements 1 and 2 pass; repeated account refused; denominator on a partial line refused; valid numerator accepted; the
referenced line cannot be deleted or renumbered. Passed.

## Wave 3b

- ACTION "مميز": list from the legacy record group `SELECT IND, DESC_A, DESC_E FROM AC_MENUCD_IND ORDER BY IND` (22 indicators,
  "0 - إنزال الرصيد الجارى" ...), `lov` (select list).
- POSITION (الاجماليات) and SIGN_FLAG (الاشارة) are list items ([LS] POSITION_LIST / SIGN_FLAG_LIST) whose labels appear in the .fmx
  texts (جزئي; موجب / سالب) but whose values do not; the data holds POSITION 0 / 1 and SIGN_FLAG 0 / 1 / 2. Not changed (question 1).

## Coverage

- Reproduced: rules 1-5; ACTION list (wave 3b).
- Not reproduced: the static lists POSITION and SIGN_FLAG (values of the list elements unknown - question 1); the names of accounts /
  cost centres come from the column lists of values. Template leftovers in the .fmx (exchange-rate and entry-date texts) are not part of this screen.

## Open questions

1. Which values do the legacy lists use: POSITION (الاجماليات: جزئي = 0, كلي = 1?) and SIGN_FLAG (الاشارة: موجب = 1, سالب = 2? - the
   data also holds 0)? With the values the two columns can become select lists.
