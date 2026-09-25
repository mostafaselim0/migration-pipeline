# CUSTOMER_CREDIT_LIMIT - تعديل الحد الأئتماني للعميل / Update Credit Limit for Customer

- Registry: system 31 (Sales) serial 29, menu `SYSTEM_MENU.CUSTOMER_CREDIT_LIMIT`, order 4004.
- Legacy module: `ASCON\ST\FMB\CUSTOMER_CREDIT_LIMIT.fmx` (no .fmb, no GN_FORM_ITEM labels).
- **Deliverable: (b) process screen**
  - PL/SQL: package `APP_PROC_AR_CREDIT`, procedure `apply_credit_limit(p_customer_code, p_credit_limit, p_user_code)`
    in `app\db\20_proc_ar.sql` (compiled VALID in SMART; `20_proc_st.sql` belongs to another batch, so this package lives in the AR file under its own name).
  - Override: `app\legacy\overrides\CUSTOMER_CREDIT_LIMIT.json`, pattern `PROCESS`, parameters customer (LOV) + new limit, preview = change history.
- **Confidence: high** for the tables, the update and the validation; medium for the one-step flow (see "Deviation").

## Purpose

Controlled change of a customer's credit limit with an audit log. Each change is a row of `CUSTOMER_CREDIT_LIMIT`; pressing
"تطبيق" (Apply) writes the new limit into `CUSTOMER.CREDIT_LIMIT` and marks the row as applied.

## What the legacy form reads / writes

| Object | Use |
|---|---|
| `CUSTOMER_CREDIT_LIMIT` (no PK, 168 rows) | log block: `CODE` (العميل), `CREDIT_LIMIT` (الحد الأئتماني), `OLD_CREDIT_LIMIT` (الحد الأئتماني السابق), `UPDATE_USER` (معدل بواسطة), `UPDATE_DATE` (التاريخ), `UPDATE_TIME` (الوقت), `UPDATE_FLAG` (تم التطبيق) |
| `CUSTOMER` | LOV `SELECT OLD_CODE, CODE, NAME_A, NAME_E, CREDIT_LIMIT FROM CUSTOMER WHERE NVL(CUSTOMER_STATUS,0)=1 AND NVL(STOPFLAG,0)=0`; **write** `UPDATE CUSTOMER SET CREDIT_LIMIT = :b1 WHERE CODE = :b2` |
| `USERS` | display name of `UPDATE_USER` |
| `GET_CUSTOMER_BAL_ALL(code)` | display of the current balance (الرصيد الجارى) |

## Rules

1. New limit must be greater than zero or empty: "القيمة يجب أن تكون أكبر من صفر أو خالية." (empty = no limit; the UPDATE writes NULL).
2. Only active, not stopped customers (LOV filter).
3. Apply: `UPDATE CUSTOMER SET CREDIT_LIMIT = new WHERE CODE = code`; the log row gets `UPDATE_FLAG = 1`, `UPDATE_USER` = current user,
   `UPDATE_DATE` = day (time part 00:00 in all 147 applied rows), `UPDATE_TIME` = 'HH24:MI' text (data: '11:55', '12:22', ...).
4. `OLD_CREDIT_LIMIT` = the customer's limit before the change (data: 1550 -> 1665 -> 1670 chains for customer 100400000003).
5. Applying an already applied row is refused: "تم التطبيق من قبل".

## APEX implementation (`app_proc_ar_credit.apply_credit_limit`)

1. Validates: customer given (-20101), limit > 0 or null (-20102, legacy text), user given (-20103).
2. Locks the customer row (`SELECT ... FOR UPDATE`) among active/not stopped customers, else -20104.
3. Refuses a call that changes nothing (new = current, both null included) with -20105: this is the double-submit guard that replaces rule 5.
4. Inserts the log row `(CODE, CREDIT_LIMIT, OLD_CREDIT_LIMIT = current limit, UPDATE_USER, UPDATE_DATE = TRUNC(SYSDATE), UPDATE_TIME = TO_CHAR(SYSDATE,'HH24:MI'), UPDATE_FLAG = 1)`.
5. `UPDATE CUSTOMER SET CREDIT_LIMIT = p_credit_limit`. No COMMIT (APEX commits the page process).

Page: parameters العميل (popup LOV of active customers with the current limit in the display) and الحد الائتماني الجديد; button "تطبيق" with confirmation;
preview = the log (customer, previous limit, limit, current limit in the customer file, current balance, applied flag, date, time, user),
filtered by the chosen customer. The preview uses `v('P' || :APP_PAGE_ID || '_CUSTOMER_CODE')`, so it does not depend on the page number.

Tests (all rolled back): apply 50000 -> 51000 wrote one applied log row with old 50000 and updated the customer; repeating it -> ORA-20105;
-5 and 0 -> ORA-20102; null customer -> ORA-20101; null user -> ORA-20103; null limit removed the limit; stopped/unknown customer -> ORA-20104;
row counts back to 168 after rollback. Preview query: 168 rows in 0.09 s.

## Deviation from the legacy (to confirm)

- Legacy was two steps (save a log row, then press Apply on that row); APEX does entry + apply in one step. The 21 legacy rows with
  `UPDATE_FLAG = 0` (entered, never applied; one of them with limit 0) are shown in the preview as "غير مطبق" but cannot be applied from this page.
  Key user: were these rejected requests (keep) or forgotten ones (apply manually / delete)? Was the two-step flow a maker/checker control?
  If yes, the procedure can be split into `request` (flag 0) and `apply` (flag 1, different user) - the package is ready to extend.
- The legacy also showed "توجد حركات بالفعل بالنظام / هل تريد تغيير المؤشر الآن" - template text with no visible use here; ignored.

## Wave 3b
Swept for the wave-3b keys: a process page whose customer parameter is already a list; the run button changes data, so it keeps
the insert right (`run_right` not set). Nothing to apply. This file had no Coverage section; added below.

## Coverage
Reproduced: the credit-limit change with its log row (previous / new limit, user, date, time), the validations, the history
preview filtered by customer.
Not reproduced: the legacy two-step flow (log first, then "Apply" on the row) — one step in APEX (question above); the template
text "توجد حركات بالفعل بالنظام / هل تريد تغيير المؤشر الآن" (no use in this form).
