# VNCRTRN_ST - حركات موردين دائنة - انظمة أخرى / Credit Transactions from Other Systems

- Registry: system 5 serial 1 (menu `FILES_MENU.ARCRTRNS_ST`, order 101). APEX list page 40010, document page 40011.
- **Deliverable: screen correction + rules** - `app\legacy\overrides\VNCRTRN_ST.json` (`MASTER_DETAIL`, insert/delete off, update on);
  validation function `APP_RULES_VN.check_st` (`app\db\21_rules_vn.sql`).
- Purpose: view the supplier credit transactions created by other systems (POST_SYSTEM set: purchase invoices 101 posted from
  purchasing/stock, LINK_FLAG 1, POST_FLAG 1) and adjust their non-financial data (invoice due dates, stop-payment flag, descriptions).
- **Confidence: medium** - compiled form only; the block WHERE and the absence of any numbering / insert SQL are clear, the exact set of
  editable items is inferred (GN_FORM_ITEM text items, "تعديل التاريخ" / "حتي تاريخ" edit-date window, STOP_FLAG "توقف السداد").

## Evidence (`evidence\VNCRTRN_ST.md`)

- Block WHERE (fmx): `TRNS_ID IN (SELECT ID FROM VN_TRNSTYPE WHERE EFFECT = 1) AND <VN_TRNSTYPE_PASSWORD> AND <VN_SUPPLIER_PASSWORD range>
  AND SERIAL IS NULL AND POST_SYSTEM IS NOT NULL`; detail VN_SUBTRNS1 `TRNS_ID in (select ID from VN_trnstype where EFFECT = 0)` (payments of
  each invoice - a read-only sub-grid, VN_SUBTRNS_PAYED_VALUE for the residual).
- Only SELECTs in the embedded SQL (no MAX(TRNS_SERIAL), no LAST_SERIAL update, no delete cascade) -> the form does not create documents.
- Texts: "فواتير دائنة واردة من المقبوضات", "تعديل التاريخ", "حتي تاريخ", "توقف السداد", "رقم المستند مكرر / هل تريد الإستمرار".

## Rules implemented

| Rule | Where | Detail |
|---|---|---|
| List filter | `where` | legacy WHERE with `:G_PASSWORD_NUMBER` (548 rows, all type 101, none shared with VNCRTRN / VNDBTRN / VNDBTRN_ST). |
| No create / delete | override `insert: false, delete: false` | legacy screen has no numbering or insert logic; deleting a stock-generated, GL-posted invoice would desynchronise purchasing and GL (they are cancelled from ST_CPOSTING). |
| Posted financial data read-only | `readonly` | type, serial, date, supplier, currency, rate, total, accounts, POST_FLAG, ACC_NO/ACC_DATE; invoice number, invoice date and value on the lines. Editable: DOC_NO, RESP_CODE, DUE_DATE, descriptions, LOT_NO; line DUE_DATE and STOP_FLAG. |
| Save check (SAVE) | `check_st('VNCRTRN_ST', ...)` | the row must be a generated credit transaction of the screen (POST_SYSTEM set, type allowed); DOC_NO > 0. |

> Wave 3: several items below are implemented now - see the sections "Wave 3" and "Coverage" at the end of this file.

Dropped: the payments sub-grid (VN_SUBTRNS1, read-only view of payment lines) and the bulk "edit due date up to date" helper; supplier
balance display; printing.

## Tests (rolled back)

- Filter: 548 rows (type 101) for group 0, 0 rows for group 102 (VN_TRNSTYPE_PASSWORD empty - same as legacy).
- `check_st`: 101 document -> ok; a manual 201 document -> "هذه الحركة لا تخص هذه الشاشة"; no rowid -> "لا يمكن إضافة حركات من هذه الشاشة";
  DOC_NO -1 -> "رقم المستند يجب ان يكون اكبر من الصفر".
- Page code rendered in memory: no Create/Delete buttons, validation references resolve.

## Open questions

1. Confirm which header fields AP may change on generated invoices (assumed: descriptions, document number, purchasing rep, due dates,
   stop-payment flag).
2. STOP_FLAG shows as a number (0/1) instead of a checkbox (override screens lose the GN_FORM_ITEM checkbox type).
3. The legacy "duplicate document number - continue?" confirmation is not reproduced: the .fmx has the text but no duplicate query (see Coverage).

## Wave 3 (displays)

| Legacy | APEX | Evidence / notes |
|---|---|---|
| CRN_BAL_TOTAL "رصيد المورد" | `info` BAL -> `app_act_pr.vn_supplier_balance_at(supplier, TRNS_DATE)` (GET_SUPPLIER_BAL up to the document date, 'د' / 'م') | GET_SUPPLIER_BAL in the .fmx symbol list; medium confidence on the date argument |
| detail VN_SUBTRNS1 (payments of each invoice line) | `info` PAYMENTS -> `app_act_pr.vn_invoice_payments` | block WHERE `TRNS_ID in (select ID from VN_trnstype where EFFECT = 0)` |

Tests (build copy, all rolled back, plain and inside a simulated APEX session of app 100 with the regenerated APPX_ triggers; scripts in the job folder `tmp\w3_purch`: t_vn.py, t_po.py, t_lot.py, t_st.py, t_quot.py, t_reg.py; static check chk.py): balance at a date equals GET_SUPPLIER_BAL; payments text (t_vn.py).

## Wave 3b
* The originating system is shown: POST_SYSTEM as the legacy list "النظام" (POST_SYSTEM_LIST, `SELECT SYSTEM_DESC_A, SYSTEM_NUMBER FROM
  SYS_SYSTEMS WHERE SYSTEM_NUMBER NOT IN (0, 99)`), read-only; the documents of this screen all come from system 30.
* Lists (read-only fields show names): TRNS_ID from the credit types with type rights, SUPPLIER_ID from the suppliers in the user's
  range (legacy LOVs of the .fmx).
* VN_SUBTRNS.STOP_FLAG "توقف السداد": check box 1/0 (GN_FORM_ITEM check box).
* Block settings unchanged (header / lines update only: generated documents).
* Check: `check_forms.py VNCRTRN_ST`.

## Coverage
Reproduced: list filter, read-only financial data, save check (wave 2); balance and payments displays (wave 3); originating system,
legacy type / supplier lists, stop-payment check box (wave 3b).

Not reproduced, with the reason:
* "رقم المستند مكرر / هل تريد الإستمرار" alert: the .fmx has the alert text but no duplicate query (only SELECTs of names, rates and
  DOC_NO by key) - the condition is unknown, so no warning is invented.
* Bulk "تعديل التاريخ ... حتي تاريخ" due-date helper: only the prompts exist in the .fmx, no SQL - the rule cannot be rebuilt; users edit
  DUE_DATE per line (editable in the grid).
* Printing, alerts: Forms-only / printing out of scope.
