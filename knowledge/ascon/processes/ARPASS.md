# ARPASS - صلاحيات المجموعات - نظام العملاء / Group Privilege (Receivable)

- Registry: system 99 serial 34 (PRIVILIAGE_MENU, order 3004). APEX list page 80100, document page 80101.
- Legacy module: `ASCON\SE\FMB\Arpass.fmx` (the evidence pack quotes an older `ASCON\AR\FMB\Arpass.fmx` about screen rights of system 6; the SE
  module was string-mined for wave 3). Master PASSWORD (PNAME display), tabs AR_TRNSTYPE_PASSWORD (الحركات), AR_CUSTOMER_PASSWORD (customer /
  salesman ranges), AR_CUST_PASSWORD (صلاحيات العملاء), AR_SALESMAN_PASSWORD (صلاحية المناديب).
- **Deliverable: (a) screen correction + buttons** - `app\legacy\overrides\ARPASS.json` (MASTER_DETAIL PASSWORD with the four grant tables; the
  generator had only the first two), package `APP_RULES3_SE`.
- **Confidence: high** for the tables and buttons.

AR_TRNSTYPE_PASSWORD, AR_CUST_PASSWORD and AR_SALESMAN_PASSWORD are read by APP_RULES_AR, APP_RULES_SA and APP_PROC_AR.

## Rules and buttons

| # | Legacy rule / button | Evidence | APEX |
|---|---|---|---|
| 1 | "كل الحركات": a record for every AR_TRNSTYPE (loop CREC, FLAG set) | ALL_TRNS_PUSH, `SELECT ID, DESCRIPTION FROM AR_TRNSTYPE ORDER BY TO_NUMBER(ID)` | action ALL_TRNS -> `ar_all_trns` (missing types, FLAG 1) |
| 2 | "إختيار الكل" / "استبعاد الكل" | CHOOSE_ALL / CHOOSE_NONE | action FLAGS -> `set_flags('AR_TRNSTYPE_PASSWORD')` |
| 3 | ALL_CUST_PUSH: active customers of the chosen main area / sub area / category (AR_CUST_SALESMAN) / salesman not yet granted | `SELECT CODE ... FROM CUSTOMER WHERE CUSTOMER_STATUS = 1 AND (:b2 IS NULL OR MAINAREA_ID = :b2) ... AND CODE NOT IN (SELECT CUSTOMER_CODE FROM AR_CUST_PASSWORD ...)` | action ALL_CUST (4 optional filters) -> `ar_all_customers` |
| 4 | ALL_SALESMAN_PUSH: salesmen of the chosen sub area / category not yet granted | `SELECT CODE ... FROM SALESMAN WHERE (:b2 IS NULL OR SUBAREA_ID = :b2) AND (:b3 IS NULL OR CTGRY_CODE = :b3) AND CODE NOT IN (...)` | action ALL_SALESMEN -> `ar_all_salesmen` |
| 5 | Customer range "من / إلى رقم عميل", salesman range | labels | grid AR_CUSTOMER_PASSWORD; TO_CUSTOMER_CODE must be typed (key_expr `required`: the generated max+1 would invent it) |
| 6 | A group with grants cannot be deleted here | relation check `SELECT 1 FROM AR_TRNSTYPE_PASSWORD / AR_CUSTOMER_PASSWORD` | groups are deleted only in ACGROUP_COMPANY |

## Tests (t_se.py, rolled back)

A1 all AR types; A2 all active customers of the largest sub area (114); A3 all salesmen; A4 range end required.

## Open questions

1. The SE module deletes `AR_CUST_PASSWORD` and `AR_SALESMAN_PASSWORD` of the group in one trigger (probably a "remove all" button or the group
   PRE-DELETE); not reproduced as a button (the grids delete rows; the group delete of ACGROUP_COMPANY removes them).
2. Range checks of AR_CUSTOMER_PASSWORD (triggers with `:FROM_CUSTOMER_CODE / :TO_CUSTOMER_CODE` loops, texts "خطا" / "تحذير") - no message text
   identifies the rule; not reproduced (the VNPASS equivalent is).


## Wave 3b

Checked: the transaction, customer and salesman grids already have their lists with names, FLAG is a check box. The customer / salesman range columns of AR_CUSTOMER_PASSWORD keep plain numbers: the evidence pack shows no record group for them.

## Coverage

- Reproduced: rules 1-6.
- Not reproduced: questions 1-2, customer / salesman name columns (list of values display), print / translation buttons.
