# ARAREA - ملف المناطق والفروع / Main Area and Sub Area File

- Registry: system 4 serial 24 (`CODES_MENU.MAINAREA`). Legacy `ASCON\AR\FMB\ararea.fmx` (no .fmb).
- APEX: corrected to `MASTER_DETAIL` with all four legacy blocks: `AR_MAINAREA` (master), `AR_SUBAREA` (`MAIN_ID = ID`),
  `AR_CTGRY_SUBAREA` "اقسام الفرع" and `AR_SUBAREA_STORES` "المخازن المرتبطة بالفرع" (third-level blocks joined on the main area, the branch
  typed in the row). The generated page had only the first two. Rules in `APP_RULES3_AR`. Data: 2 areas, 22 branches, 43 branch departments.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| "رقم المنطقة الرئيسية لا يمكن ان يقل عن 1" / "رقم المنطقة الفرعية لا يمكن ان يقل عن 1" | messages | row rules `mainarea_row`, `subarea_row` | high |
| duplicate code "كود مكرر من قبل" | `SELECT COUNT(1) FROM AR_MAINAREA / AR_SUBAREA WHERE ...` | primary keys | high |
| account and discount account must differ: "لا يمكن تكرار رقم الحساب" | message (same rule as CUSTOMER ACCOUNT_NO WVI) | row rules | medium |
| accounts from `AC_MASTER` (`ACCOUNT_STATUS = 1`, group grants) | ACCOUNT1/2_LOV, DISC1/2_LOV | row rules (account must exist and be active) | high |
| voucher type (`ENTRY_TYPE`) from `AC_TRN_CODES` | LOV | row rule | high |
| sales manager / branch manager are salesmen | SALESMAN LOV | row rule | high |
| a main area with branches cannot be deleted: "لايمكنك حذف هذه المنطقة لأن لها مناطق فرعية" | `SELECT 'x' FROM AR_SUBAREA WHERE MAIN_ID`, message | delete trigger `APP_RULES3_AR_SUBAREA_BD` on the document delete | high |
| a deleted branch takes its stores with it (`DELETE FROM AR_SUBAREA_STORES WHERE MAIN_ID AND SUB_ID`) and cannot be deleted while it has departments (`SELECT 1 FROM AR_CTGRY_SUBAREA ...`) | embedded SQL | same trigger | high / medium |
| branch department: branch of the area, department exists, manager is a salesman, account exists; "هذا القسم تم تخصيصه  من قبل" | SQL, message | row rule `ctgry_subarea_row`; primary key | high |
| branch store: active store (`STOP_FLAG = 0 AND STORE_STATUS = 1`), a store can be linked once: "تم ربط هذا المخزن من قبل" | STORE_LOV, `SELECT COUNT(1) FROM AR_SUBAREA_STORES WHERE STORE_CODE` | row rule `subarea_store_row` | high |

## Tests (rolled back)

Id < 1 refused; equal accounts refused; unknown account refused; store linked twice / inactive store refused; unknown branch refused;
branch with departments not deletable; branch delete removes its stores; area delete with branches refused (batch 1).

## Coverage

- Reproduced: all checks above, the two missing blocks, labels.
- Wave-3b lists (`rules.columns`): `CAR_NO` ("عدد سيارات الفرع") shown as a plain number (the generator had attached the `CARS` list of
  values to it; it is a count here); lists of active accounts on the account / discount-account columns, salesmen on the manager
  columns, voucher types (`AC_TRN_CODES`) on `ENTRY_TYPE`. The row rules still validate the values.
- Not reproduced: print buttons.
