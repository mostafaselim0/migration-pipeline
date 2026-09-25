# LC_PAY_COND — أرقام طرق الدفع / Payment Methods (system 30, serial 16)

Deliverable: **business rules on the generated code-table screen** — `overrides/LC_PAY_COND.json` (pattern AUTO + row rule),
`APP_RULES3_PR` (`app/db/25_rules3_pr.sql`), delete hook trigger `APP_R3_LC_PAY_COND_BD`. Page 50060.
Confidence: **high** (small form, every rule is an embedded SQL statement or message of the .fmx).

## Purpose and tables
Code table `LC_PAY_COND` (PAY_COND_CODE, PAY_COND_DESC, PAY_COND_DESC_E; 3 rows) used by the letters of credit
(`LC_CREDIT`, `LC_CREDIT_OPEN`, both empty in the build copy). The generated grid shows the right table and columns.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Number > 0 — "رقم طريقة الدفع يجب ان يكون اكبر من الصفر" | row rule `pay_cond_row` | .fmx message | high |
| 2 | No duplicate number — "رقم مكرر تم إدخالة من قبل" | row rule (INSERT) | `SELECT COUNT(1) FROM LC_PAY_COND WHERE PAY_COND_CODE = :b1` | high |
| 3 | Empty number → max + 1 | generated APPX key (numeric PK) | APEX convenience; legacy asked for the number | medium |
| 4 | Delete refused while `LC_CREDIT` uses the method — "لا يمكن حذف السجل التالى لوجود ارتباط مع ملف الاعتماد الرئيسي" | trigger `APP_R3_LC_PAY_COND_BD` → `pay_cond_delete` | `SELECT COUNT(1) FROM LC_CREDIT WHERE PAY_COND_CODE = :b1` + message | high |
| 5 | Delete refused while `LC_CREDIT_OPEN` uses it — "... مع ملف فتح الاعتماد" | same | `SELECT COUNT(1) FROM LC_CREDIT_OPEN WHERE PAY_COND_CODE = :b1` + message | high |

No buttons besides the standard toolbar.

## Tests (`tmp\w3_prsa\t_w3prsa.py`, simulated APEX session, rolled back)
PC1 number 0 refused · PC2 duplicate refused · PC3 empty number gets max + 1 · PC4 delete refused (LC_CREDIT) ·
PC5 delete refused (LC_CREDIT_OPEN) · PC6 unused method deleted. All PASS.

## Wave 3b
Swept for the wave-3b keys: the legacy form has only three text items (number, Arabic / English name); no radio group, list item, check box, display item,
LOV, update-after-insert restriction, block restriction or button to another form (GN_FORM_ITEM types and .fmx texts). Nothing
to apply; the page is unchanged.

## Coverage
Reproduced: all rules above (number, duplicate, delete restrictions with the legacy messages).
Not reproduced: the delete confirmation alert ("هل تريد مسح السجل الحالى") and the toolbar / translation / SET_IP library
code (Forms mechanics; APEX asks its own delete confirmation).
