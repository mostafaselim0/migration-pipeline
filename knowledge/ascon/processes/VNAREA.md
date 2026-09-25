# VNAREA - ملف المناطق والفروع / AP Areas File

- Registry: system 5 serial 21 (menu `CODES_MENU.MAINAREA`, order 201). APEX list page 40060, document page 40061.
- **Deliverable: generated master-detail kept (`"pattern": "AUTO"`: VN_MAINAREA + VN_SUBAREA) + rules** -
  `app\legacy\overrides\VNAREA.json`, package `APP_RULES3_VN` (mainarea_row, subarea_row, subarea_uniq, subarea_del + compound trigger
  `APP_RULES3_VN_SUBAREA_BIUD`).
- **Confidence: high** (all SQL and texts of the .fmx; 2 areas, 3 branches; SUPPLIER references the branch with FK SUPPLIER_FK1).

## Evidence (`evidence\VNAREA.md`, compiled `VN\FMB\vnarea.fmx`)

- VN_MAINAREA.ID: `CHK_MASTER_UNIQ` ("رقم مكرر"), "رقم المنطقة يجب ان يكون اكبر من الصفر"; ACCOUNT_NO / DISC_ACCOUNT WHEN-VALIDATE-ITEM
  "رقم حساب الخصم يجب ان يختلف عن رقم حساب المنطقة الارئيسية" + account name from AC_MASTER (LOV: ACCOUNT_STATUS = 1, group accounts).
- KEY-DELREC of the area: `SELECT 'x' FROM VN_SUBAREA WHERE MAIN_ID` -> "لايمكنك حذف هذه المنطقة لأن لها مناطق فرعية".
- VN_SUBAREA.ID: `CHK_DET_UNIQ`, "رقم المنطقة الفرعية يجب ان يكون اكبر من الصفر"; ACCOUNT_NO / DISC_ACCOUNT: `SELECT 'x' FROM AC_MASTER`,
  "رقم حساب الخصم يجب ان يختلف عن رقم حساب المنطقة الفرعية".
- PRE-INSERT / PRE-UPDATE of VN_SUBAREA: `COUNT(1) ... WHERE MAIN_ID AND ACCOUNT_NO (AND ID != :ID)` -> "رقم حساب المنطقة الفرعية لا يمكن
  تكراره"; same for DISC_ACCOUNT -> "رقم حساب الخصم للمنطقة الفرعية لا يمكن تكراره".
- No numbering statement: area and branch numbers are typed.
- `DELETE FROM AR_SUBAREA WHERE MAIN_ID = :b1` (master-detail cascade copied from the AR areas form).

## Rules

| Rule | APEX |
|---|---|
| Area / branch number typed by the user (the generator would fill max+1) | `key_expr` `need_num` for VN_MAINAREA.ID and VN_SUBAREA.ID |
| Numbers > 0 | row rules `mainarea_row` / `subarea_row` (legacy texts) |
| Discount account differs from the account (area, branch) | row rules (legacy texts) |
| Accounts active in the chart of accounts | row rules (`check_account`) |
| Branch account / discount account not repeated inside the area (insert and update) | compound trigger after the statement -> `subarea_uniq` |
| An area with branches cannot be deleted | delete of a branch by the "delete document" cascade (REQUEST = DELETE) -> legacy text |
| Duplicate numbers, delete of a branch used by suppliers | PK / FK SUPPLIER_FK1 + `app_ui.handle_error` |

Tests (t_vn1): area number required / -1 refused; discount = area account refused; unknown account refused; branch number required / 0
refused; discount = branch account refused; repeated branch account refused (insert); repeated discount account refused (update, after
the statement); document delete of an area with branches refused; branch delete in the grid accepted. 11/11 passed.

## Coverage

Reproduced: every validation and the delete rule. Deliberately not reproduced: `DELETE FROM AR_SUBAREA WHERE MAIN_ID` (a legacy bug: it
would delete the customer branches of the AR area with the same number; the VN branches are protected by the rule above); account-name
display items (the LOVs show the names); print (Vnarea_REP), toolbar (Forms-only). Generator gap: the account columns are plain numbers
(no FK -> no LOV); the row rule checks them at save.
