# ST_ISSUE_IO_DLVR_TOUCH - تحضير فواتير المبيعات / Prepare Sales Invoices (invoice preparation and delivery stages)

- Registry: system 3 serial 14 and system 31 serial 14 (menu `FILES_MENU.ST_SALES_PREPARE`). APEX page 20310.
- **Deliverable: (c) not reconstructed** - only this document; no procedure and no override (the page keeps the generator's "process screen"
  placeholder). Reason: the stage rules (order, cancellation, driver assignment) are only inferable from message texts; there is no trigger source,
  the feature has never been used in this database, and objects it needs are missing (see "Why not implemented").
- **Confidence of the reconstruction below: low-medium.**

## What is known (compiled `ST\FMB\ST_ISSUE_IO_DLVR_TOUCH.fmx`, `evidence\ST_ISSUE_IO_DLVR_TOUCH.md`)

1. Block on ST_TRNS_MAST, touch-screen layout, auto refresh (`ST_BASIC.REFRESH_TIMER`, default 60 s). Query (DEFAULT_WHERE):
   `TRNS_DATE = NVL(:date, today)`, sales invoice types (`ST_TRNS_TYPE.TRNS_TYPE = 2 AND EFFECT = 2`), not deleted, **printed** (`PRINT_FLAG = 1`)
   and at least one stage open (`PREPARE_FLAG`, `REV_FLAG`, `DLVR_LOC_FLAG`, `DLVR_FLAG`, `DLVR2_FLAG`, `CUST_AUTH_FLAG` = 0) or no attached
   document (`SYS_DOCS` where `TBL_NM = 'ST_TRNS_MAST'`, PK1 = type, PK2 = serial); security on transaction type (ST_TRNSTYPE_PASSWORD),
   customer (AR_CUST_PASSWORD) and store (ST_STORE_PASSWORD).
2. Six stage buttons, in this order in the query, the USERS columns and the labels: BUT_PREPARE "تحضير", BUT_REV "مراجعة", BUT_DLVR_LOC
   "منطقة التسليم", BUT_DLVR "تسليم - السائق", BUT_DLVR2 "تسليم - السائق 2" (added later, 2020-2021 build stamps), BUT_CUST_AUTH "تسليم - العميل".
   Each stage has FLAG / DATE / TIME columns on ST_TRNS_MAST (e.g. PREPARE_FLAG, PREPARE_DATE, PREPARE_TIME; the format mask HH24 is in the form).
3. Permissions per user (USERS): `INV_<stage>_FLAG` to pass a stage, `C_INV_<stage>_FLAG` to cancel it (queried per button:
   `SELECT NVL(INV_PREPARE_FLAG,0), NVL(C_INV_PREPARE_FLAG,0) FROM USERS WHERE USERS_CODE = :user`, same for REV, DLVR_LOC, DLVR, DLVR2, CUST_AUTH).
4. Messages: "لابد من وجود صلاحية" (permission required), "يوجد مرحلة لم يتم مرور الفاتورة خلالها" (an earlier stage has not been passed),
   "يوجد مرحلة تم مرور الفاتورة خلالها يجب إلغائها" (a later stage was passed and must be cancelled first).
5. Driver windows DRIVER_WINDOW / DRIVER2_WINDOW (ACCEPT / EXIT) with LOVs EMP_LOV / EMP2_LOV:
   `PY_PRSNL_H` (not terminated) whose `JOB_CODE` is in `PY_JOBS_H` with `STORE_DLVR = 1` and `JOB_STATUS = 1`; they fill DRIVER_CODE / DRIVER2_CODE.
6. Attachments through the ASCON_DOCS / SYS_DOCS component (ATTACH / ATT_COUNT items).

## Why not implemented

- No trigger source: the stage transition rules (strict sequence? is "driver 2" optional? must the driver be chosen before "تسليم - السائق"?
  does cancelling reset DATE / TIME?) would be invented.
- The data shows the workflow was never used: all 1 318 sales invoices have every stage flag = 0 and no driver; PY_PRSNL_H and PY_JOBS_H are empty
  (no driver can be selected); `SYS_DOCS` does not exist in the SMART build copy (ORA-00942), so the legacy query itself cannot run here.

## Proposed rules (to confirm before implementing)

- Stage n can be set only when stages 1..n-1 are set ("يوجد مرحلة لم يتم مرور الفاتورة خلالها") and the user has INV_<stage>_FLAG = 1;
  it sets FLAG = 1, DATE = TRUNC(SYSDATE), TIME = TO_CHAR(SYSDATE,'HH24:MI:SS').
- Stage n can be cancelled only when stages n+1..6 are not set ("يوجد مرحلة تم مرور الفاتورة خلالها يجب إلغائها") and the user has
  C_INV_<stage>_FLAG = 1; it sets FLAG = 0 (DATE / TIME cleared?).
- "تسليم - السائق" / "تسليم - السائق 2" require DRIVER_CODE / DRIVER2_CODE from the delivery employees.
- Implementation would be `app_proc_st.invoice_stage(p_trns_type_code, p_trns_serial, p_stage, p_action, p_driver_code)` with a preview of the day's
  printed invoices and their stages.

## Questions for the key user / vendor

1. Is this screen used at all at this site (no stage has ever been recorded)? If not, drop it from the migration.
2. Exact order of the six stages; is "تسليم - السائق 2" optional (skippable) or always required between "تسليم - السائق" and "تسليم - العميل"?
3. On cancel, are the stage DATE / TIME cleared or kept?
4. Is the driver mandatory for the two driver stages, and where are drivers maintained (PY_PRSNL_H is empty in this database)?
5. Where is the attachment table SYS_DOCS (schema ASCON_DOCS?) and must "invoice has an attachment" remain a condition for leaving the list?
