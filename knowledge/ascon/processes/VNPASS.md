# VNPASS - صلاحيات المجموعات--متابعة الموردين / Group Privilege (Payable)

- Registry: system 99 serial 35 (PRIVILIAGE_MENU, order 3005). APEX list page 80110, document page 80111.
- Legacy module: `ASCON\SE\FMB\vnpass.fmx`. Master PASSWORD (PNAME display), tabs VN_TRNSTYPE_PASSWORD (الحركات), VN_SUPPLIER_PASSWORD (الموردين: ranges).
- **Deliverable: (b) rules + buttons on the generated screen** - `app\legacy\overrides\VNPASS.json` (AUTO), package `APP_RULES3_SE`.
- **Confidence: high.**

Read by APP_RULES_VN (supplier range of the group, transaction types) and APP_PROC_VN.

## Rules and buttons

| # | Legacy rule / button | Evidence | APEX |
|---|---|---|---|
| 1 | "يجب ان يكون كود الى مورد اكبر من او مساوى لكود من مورد" | message; TO_SUPPLIER LOV `CODE >= :FROM_SUPPLIER_CODE` | row rule `vn_range_row` |
| 2 | "هذا المورد موجود فى مدى قبل ذلك": a range may not overlap another range of the group | message, DUP_REC / record loop | after-save `vn_ranges_check` (the rows of the same table cannot be read in the row trigger on update) |
| 3 | Range end must be typed | TO_SUPPLIER_CODE item, PK column | key_expr `required` (the generated max+1 would invent it) |
| 4 | "كل الحركات": every VN_TRNSTYPE | ALL_TRNS_PUSH, `SELECT ID ... FROM VN_TRNSTYPE ORDER BY TO_NUMBER(ID)` | action ALL_TRNS -> `vn_all_trns` (missing types, FLAG 1) |
| 5 | "إختيار الكل" / "استبعاد الكل" | CHOOSE_ALL / CHOOSE_NONE | action FLAGS -> `set_flags('VN_TRNSTYPE_PASSWORD')` |
| 6 | A group with grants cannot be deleted here | `SELECT 1 FROM VN_SUPPLIER_PASSWORD / VN_TRNSTYPE_PASSWORD WHERE PASSWORD_NUMBER` | groups are deleted only in ACGROUP_COMPANY |

Note: APP_RULES_VN reads only the first range of a group (`rownum = 1`); several ranges are allowed here as in the legacy.

## Tests (t_se.py, rolled back)

V1 all AP types; V2 to < from refused; V3 separate ranges accepted; V4 overlapping range refused; V5 range end required.


## Wave 3b

Supplier range: FROM_SUPPLIER_CODE and TO_SUPPLIER_CODE get the legacy supplier lists (`SELECT CODE, NAME FROM SUPPLIER`; the "to" list only suppliers from the "from" code on, `cascade: FROM_SUPPLIER_CODE`, as the legacy record group `WHERE (:FROM_SUPPLIER_CODE IS NULL OR CODE >= :FROM_SUPPLIER_CODE)`).

## Coverage

- Reproduced: rules 1-6.
- Not reproduced: print / translation buttons. (Wave 3b: supplier range lists with names.)
