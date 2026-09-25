# SUPPLIER - ملف الموردين الرئيسي / Suppliers Main Information

- Registry: system 5 serial 24 (menu `CODES_MENU.ARMAST`, order 206) and system 30 serial 13 "أرقام الموردين" (the same form).
  APEX list page 40110, document page 40111.
- **Deliverable: screen correction + rules** - `app\legacy\overrides\SUPPLIER.json` (`"pattern": "MASTER_DETAIL"`), package
  `APP_RULES3_VN` (supp_level, supp_parent, supplier_row, supplier_del, supplier_after, supp_child_del, pay_acc_row, stat_row, supp_info,
  next_child_code + delete triggers `APP_RULES3_VN_SUPPLIER_BD`, `_SUPPRESP_BD`, `_SUPPKIND_BD`).
- **Confidence: medium** - compiled forms only. Two versions exist: `ST\FMB\SUPPLIER.fmx` (2017, used by the evidence pack) and
  `VN\FMB\supplier.fmx` (2020). The **2020 version is the live one**: it numbers suppliers with the code structure (VN_CHART_STRUCTURE,
  SUPPLIER_LEVEL, SUPPLIER_STATUS, tree view) and has the blocks VN_SUPP_KIND / SUPPLIER_SHIPPING_TYPE / SUPPLIER_STAT; the data follows
  it (515 suppliers on levels 1-3, 12-digit structured codes, SUPPLIER_STATUS 0 = parent / 1 = leaf, 5 manufacturer links, 1 reconciliation).
  The form is a clone of the customer form (CUSTOMER.fmb, where the same program units exist in source).

## Why a correction

The generated screen was a report + form on SUPPLIER only ("unrelated blocks not placed: VN_SUPP_RESP") from the 2017 labels. The live
form has a master and five detail blocks:

| Legacy block (tab) | Table | Join |
|---|---|---|
| SUPPLIER (بيانات المورد، الربط بالحسابات) | SUPPLIER | master (block WHERE `NVL(SPPLIER_STATUS,1) = 1` + group supplier range) |
| VN_pay_methode_Acc (حسابات طرق الدفع) | VN_PAY_METHODE_ACC (69 rows) | SUPPLIER_CODE = CODE |
| VN_SUPP_RESP (المسئولين عن المورد) | VN_SUPP_RESP (6) | SUPP_CODE = CODE |
| VN_SUPP_KIND (ارقام المصنعين) | VN_SUPP_KIND (5) | SUPP_CODE = CODE |
| SUPPLIER_SHIPPING_TYPE (طرق شحن المورد) | SUPPLIER_SHIPPING_TYPE (0) | SUPPLIER_CODE = CODE |
| SUPPLIER_STAT (المطابقات) | SUPPLIER_STAT (1) | SUPPLIER_ID = CODE (legacy block WHERE also `STAT_YEAR = :ST_YEAR`) |

Master columns = the items of the 2020 form (+ START_DATE, SINGLE_PAY, STOPDATE of the generated screen, used by the AP rules of wave 2);
SPPLIER_STATUS is not shown (all 515 rows = 1, it is the list filter). Labels corrected / added with `add_columns`.

## Evidence (`VN\FMB\supplier.fmx` strings; `evidence\SUPPLIER.md` for the 2017 version)

- CODE WHEN-VALIDATE-ITEM (DETECT_SUPP_LEVEL, GET_SUPP_PARENT, SUPP_FOUND, `SELECT LENGTH FROM VN_CHART_STRUCTURE`, `SELECT COUNT(1) FROM
  SUPPLIER WHERE CODE`): "رقم المورد يجب ان يكون اكبر من الصفر", "رقم المورد تم إدخاله من قبل .....", DISPLAY_ERROR_MESSAGE (table
  MESSAGES is empty, so the legacy showed only a code). CUSTOMER.fmb shows the same unit in source: code RPAD to 12, level, parent must exist,
  SUPPLIER_STATUS := 1.
- Button "إدخال سجل جديد" (block of GET_NEXT_SUPP): `SELECT RPAD(SUBSTR(MAX(CODE),1,:end_child)+1,12,0) FROM SUPPLIER WHERE <same parent
  prefix>`, "لا يمكن تكوين أبن بلا أب" / "You cant add children SUPPLIER Without A Parent SUPPLIER".
- POST-INSERT `UPDATE SUPPLIER SET SUPPLIER_STATUS = 0 WHERE CODE = parent`; POST-DELETE (SUPP_HAS_BROTHERS) `... = 1`; KEY-DELREC with
  :SUPPLIER_STATUS (parent cannot be deleted); ON-CHECK-DELETE-MASTER (VN_SUPP_RESP, VN_SUPP_KIND): "Cannot delete master record when
  matching detail records exist."; PRE-DELETE `DELETE FROM VN_PAY_METHODE_ACC / SUPPLIER_SHIPPING_TYPE WHERE SUPPLIER_CODE`.
- CURRENCY('OPEN'/'CLOSE') on CURRENCY_CODE and ACT_CODE with `COUNT(*) FROM VN_MAINTRNS / VN_SUBTRNS_OP / ST_TRNS_MAST WHERE supplier`.
- TELEPHONE1-3 / FAX WHEN-VALIDATE-ITEM (`SELECT TO_NUMBER(:b1) FROM DUAL`): "... يجب ان يكون بدون حروف", "... يجب ان يكون اكبر من الصفر",
  "... لا يمكن ان يقل عن 7 أرقام او يزيد عن 17"; DEBIT_LIMIT "حد الائتمان يجب ان يكون اكبر من الصفر"; DUE_DAYS "ايام الاستحقاق يجب ان يكون
  اكبر من الصفر"; STOPFLAG / STOPREASON.
- LOVs: active accounts, active cost centres, LC_SETTEL_TYPE, VN_RESP, ST_GOOD_KIND, LC_PORT. SUPPLIER_STAT.STAT_DATE ->
  `:STTM_BAL := GET_SUPPLIER_BAL(:SUPPLIER.CODE, :STAT_DATE)`. POST-QUERY balances (CRN_BAL_TOTAL / BEG_BAL with دائن / مدين), "آخر سجل".

## Rules

| Rule | APEX |
|---|---|
| List filter | `where`: `NVL(SPPLIER_STATUS,1) = 1` + VN_SUPPLIER_PASSWORD range of the group |
| Code typed (structured), no max+1 | `key_expr` `need_num('يجب إدخال رقم المورد')` |
| Insert: code > 0, RPAD to 12 digits, level by the structure (non-zero part after a zero part refused), parent must exist, not repeated, new supplier = leaf (status 1), inside the group range | row rule `supplier_row` |
| After create: parent becomes a parent (status 0); after delete: parent becomes a leaf again when it has no other children | after-save `supplier_after` (CREATE / DELETE) |
| Parent supplier cannot be deleted | delete trigger -> `supplier_del` (own text; legacy DISPLAY_ERROR_MESSAGE was empty) |
| Currency and activity locked once the supplier has AP transactions, opening balances or stock documents | `supplier_row` on update (own text; legacy disabled the items) |
| Telephones / fax, debit limit >= 0, due days >= 0 (when entered or changed) | `supplier_row` (legacy texts) |
| Not stopped -> no stop reason | `supplier_row` |
| Accounts and cost centres active (when entered or changed) | `supplier_row` |
| Responsibles / manufacturers block the "delete document"; payment-method accounts and shipping methods are deleted with the supplier | delete triggers on VN_SUPP_RESP / VN_SUPP_KIND (`supp_child_del`), none on the others |
| Payment-method account line: payment type exists, accounts / cost centres active | row rule `pay_acc_row` |
| Reconciliation line: year of the date, statement balance = GET_SUPPLIER_BAL(supplier, date) | row rule `stat_row` (STTM_BAL read-only, STAT_YEAR optional) |
| Balances panel (current balance with دائن / مدين, opening balance, level / status, last record) | `info` -> `supp_info` |
| Button "إدخال سجل جديد" (next child code of the current supplier) | action NEXT_CHILD -> `next_child_code`, the code is shown in the message |
| Other screens writing SUPPLIER (opening balances update BEG_BAL / CRN_BAL_TOTAL) | rules guarded by `is_form('SUPPLIER')` and `busy` (own status updates) |

Tests (build copy, rolled back, t_vn2): code required / -1 / structure mismatch / child without parent / repeated code refused; next child of
102340000000 = 102340100000 and of a level-3 supplier = ...0001; short code 1023401 padded, level 3, leaf; parent status 0 after create;
parent delete refused; telephone with characters / short / negative and fax with characters refused, valid telephone accepted; debit limit and
due days < 0 refused; stop reason cleared / kept; unknown account and cost centre refused; currency change without transactions accepted,
currency and activity change with transactions refused, other changes accepted; rules silent from the VNTRN_OP page; payment-method line
checks; reconciliation year and statement balance; document delete refused with responsibles / manufacturers, payment-method accounts
deleted; leaf deleted and the parent back to leaf; info values. 39/39 passed.

## Open questions

1. The PRE-INSERT of the 2020 form still contains `SELECT NVL(MAX(CODE),0)+1 FROM SUPPLIER WHERE SUPPLIER_TYPE = :b1 AND NVL(EMP_FLAG,0) =
   0` (auto-numbering of the old form, probably when the code is empty, and GLOBAL.CUSTOMER_CODE from CUSTOMER_PAR, empty table). All codes
   are structured, so the APEX screen requires the code. Confirm that auto-numbering is not used.
2. A supplier with transactions can be deleted in the legacy form (no check besides the parent status; VN_MAINTRNS has no FK to SUPPLIER).
   Suggestion: refuse like the customer file.
3. List values of SUPPLIER_TYPE (1 مورد / 2 مقاول) and SHIPPING_TYPE (only "بحرى" visible) - please confirm the values.
4. Legacy STAT_YEAR of a reconciliation is the year chosen on the screen (ST_YEAR); APEX takes the year of the date when empty.

## Coverage

Reproduced: the code structure rules, parent / leaf maintenance, delete rules, field checks, currency / activity lock, the five detail blocks
with their checks, balances panel, the "new record" child-code helper. Not reproduced: the tree view (عرض الشجرة, Expand / Collapse -
Forms-only navigation; the list shows level and status), SET_BLOCK_SELECTION (tree-node permission, covered by the list filter), the
CURRENCY rate display, the "آخر سجل" per supplier type (replaced by the last code overall), print (SUPPLIER_REP), toolbar / translate.
Generator gaps: no per-column LOV / static list (SUPPLIER_TYPE, SHIPPING_TYPE are numbers; area / branch without LOV because of the composite
FK); the action cannot open a new record with a prefilled code, so the next child code is shown as a message; MASTER_DETAIL overrides apply
one insert / update / delete flag to all six blocks.
