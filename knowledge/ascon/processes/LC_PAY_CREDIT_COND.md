# LC_PAY_CREDIT_COND — أرقام شروط الدفع / Payment Conditions (system 30, serial 17)

Deliverable: **screen correction (column order) + business rules** — `overrides/LC_PAY_CREDIT_COND.json` (GRID on the same
table, legacy column order COND_NO, COND_DESCA, COND_DESCE + row rule), `APP_RULES3_PR`, delete hook
`APP_R3_LC_PAY_CREDIT_COND_BD`. Page 50070. Confidence: **high**.

## Purpose and tables
Code table `LC_PAY_CREDIT_COND` (payment conditions of letters of credit), used by `LC_CREDIT_PAY_COND` (conditions of a
letter of credit; empty in the build copy).

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Number > 0 — "رقم طريقة شرط الدفع يجب ان يكون اكبر من الصفر" | row rule `credit_cond_row` | .fmx message | high |
| 2 | No duplicate — "لا يمكن تكرار رقم شرط الدفع" | row rule (INSERT) | `SELECT COUNT(1) FROM LC_PAY_CREDIT_COND WHERE COND_NO = :b1` | high |
| 3 | Delete refused while a letter of credit uses the condition — "لا يمكن حذف السجل التالى لوجود ارتباط مع شروط الدفع فى ملف الاعتماد الرئيسي" | trigger `APP_R3_LC_PAY_CREDIT_COND_BD` → `credit_cond_delete` | `SELECT COUNT(1) FROM LC_CREDIT_PAY_COND WHERE COND_NO = :b1` + message | high |

## Tests (`tmp\w3_prsa\t_w3prsa.py`)
CC1 number ≤ 0 refused · CC2 duplicate refused · CC3 delete refused while LC_CREDIT_PAY_COND uses it. All PASS.

## Wave 3b
Swept for the wave-3b keys: the legacy form has only three text items (number, Arabic / English description); no radio group, list item, check box, display item,
LOV, update-after-insert restriction, block restriction or button to another form (GN_FORM_ITEM types and .fmx texts). Nothing
to apply; the page is unchanged.

## Coverage
Reproduced: number, duplicate and delete rules with the legacy messages; legacy column order.
Not reproduced: delete confirmation alert and Forms toolbar / translation library code (Forms mechanics).
