# SE_USERS_AUTH - اعتمادات المستخدمين / Users system Auth.

- Registry: system 99 serial 63 (SYS_MENU, order 6003). APEX list page 80230, form page 80231.
- Legacy module: `ASCON\SE\SE_USERS_AUTH.fmx` (no labels in GN_FORM_ITEM).
- **Deliverable: (c) cannot reconstruct the workflow** - `app\legacy\overrides\SE_USERS_AUTH.json` makes the generated screen a **read-only**
  list / form of SE_USERS_AUTH (it was a free insert / update / delete form on the approval log, whose insert trigger changes payroll orders).
- **Confidence: high** that the screen is an approval inbox; **low** for its exact rules (below).

## What the legacy screen does (evidence: embedded SQL + texts)

An approval inbox: for the chosen transaction kind (SYS_FILES of system 63 with AUTH_TABLE_NAME) it lists the documents waiting for the current
user's approval level (SE_AUTH chain, PREV_SER), with "اعتماد" (approve), "رفض / الغاء" (reject), "الغاء اعتماد" / "الغاء الرفض", notes, earlier
approvals ("اعتمادات سابقة") and search filters. Approve = `INSERT INTO SE_USERS_AUTH (..., USERS_DESC 'تم الاعتماد', AUTH_DATE SYSDATE,
AUTH_FLAG 1)` or UPDATE; reject = AUTH_FLAG -1; cancel = `AUTH_DATE NULL, AUTH_FLAG 0`; "يجب الغاء اخر اعتماد اولا"; "تم ارتباط الحركة بحركات
اخرى". The approver of a level is resolved through USERS.USERS_MNGR / TOP_USERS_MNGR / USERS_APPR, the employee's manager (PY_PRSNL_H.MNGR_CODE),
replacement orders (PY_ORDER_VCNC_H / PY_REP_ORDER_H) and roles (SE_USERS_ROLES). The DB trigger SE_USERS_AUTH_IN applies the result to payroll
vacation orders (PY_ORDER_VCNC_H.AGREE_FLAG). The documents are selected with dynamic SQL built from SYS_FILES.AUTH_* columns (DBMS_SQL).

## Why it is not reconstructed

SE_AUTH, SE_USERS_AUTH, SE_ROLES, SE_USERS_ROLES and the payroll tables are empty in this database, SYS_FILES has no system 63 rows, and the
approval workflows are listed as not built (README, "six-level cheque approval"). The dynamic document queries (AUTH_SEC_TABLE / AUTH_SEC_COLn)
cannot be verified without data.

Questions for the key user / vendor: is the approval inbox used (which transaction kinds)? If yes, the SE_AUTH chains of the documents and one
real approval history are needed to rebuild it as a process page.


## Wave 3b

Checked, nothing to change: read-only history of approvals; the approval workflow itself is not part of the application (see above).

## Coverage

- Reproduced: read-only view of SE_USERS_AUTH (history of approvals).
- Not reproduced: the whole approve / reject workflow (above).
