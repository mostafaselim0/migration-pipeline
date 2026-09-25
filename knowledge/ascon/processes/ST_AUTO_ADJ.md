# ST_AUTO_ADJ - التسوية الآلية للجرد / Auto Stocktaking Adjustment

- Registry: system 3 serial 112. APEX page 20070.
- **Deliverable: (b) process screen**
  - PL/SQL: `app_proc_st.auto_adjust` + pipelined `app_proc_st.auto_adj_lines` (the lines of the legacy block DET_BLK) in `app\db\20_proc_st.sql`.
  - Override: `app\legacy\overrides\ST_AUTO_ADJ.json` (preview = items whose book balance differs from the count, with the error flag of the last run).
- **Confidence: high** (port of the .fmb program unit MAKE_ADJUST and of the trigger that fills DET_BLK; numbering and texts confirmed by the
  five legacy auto-adjustment vouchers in the data).

## Evidence

- `_pipeline\catalog.json` form `ST_AUTO_ADJ` (`ST\FMB\ST_AUTO_ADJ_fmb.xml`): MAST_BLK.WHEN-NEW-ITEM-INSTANCE (population of DET_BLK),
  WHEN-VALIDATE-ITEM of ST_TAKING_DATE / STORE_CODE, program unit MAKE_ADJUST (301 lines), LOVs ST_STORE_RG / TRNS_TYPE_ISSUE / TRNS_TYPE_REC,
  alert UPDATE_ERROR "توجد بعض الحركات يوجد لها حركات تالية تتعارض معها", report ST_AUTO_ADJ_ERR.RDF.
- DB: ST_STOCK_TAKING / ST_STOCK_TAKING_DET (the count), ST_AUTO_ADJ_ERR, `GET_BALANCE_COST_CONFG`, `UPDATE_NEXT_TRNS`, triggers ST_TRNS_MAST_IN
  (DATE_SERIAL from the sequence), ST_TRNS_DET_C_IN (cost rows).
- Data: legacy vouchers with TAKING_FLAG = 1 (11701/1-3 issue, 11601/1-2 receipt, 2025-03-05 and 2025-03-08): INVOICE_NO `117010000001`
  (= type || LPAD(serial,7,'0')), receipt DOC_NO `117012` (= issue type || issue serial), descriptions identical to the port.

## Rules

1. Master: stocktaking date + store (the stocktaking must exist in ST_STOCK_TAKING); store security `ST_ALL_STORE_PASSWORD` (group 0 = all);
   issue adjustment type (EFFECT 2, TRNS_TYPE 7) and receipt adjustment type (EFFECT 1, TRNS_TYPE 7), both for the store or for all stores and
   allowed by ST_TRNSTYPE_PASSWORD; missing codes -> "يجب ادخال كود وارد وصادر التسوية الالية".
2. Lines (DET_BLK): every item / batch (ITEM_CONFG_ID) that ever moved in the store (ST_TRNS_DET) or is in the count, whose book balance at the
   stocktaking date (`GET_BALANCE_COST_CONFG`) differs from the counted basic quantity (sum of ST_STOCK_TAKING_DET.BASIC_QTY). Cost = average
   count cost, else the average book cost; unit = the basic unit (missing basic unit -> "خطأ بوحدة الصنف", stop). **Items not counted are taken
   as counted zero.**
3. Pass 1 for each ticked line (APEX: all lines, or the given group / item):
   - book balance > 0: if later transactions exist and the count is lower than the book, `UPDATE_NEXT_TRNS` checks that the later movements stay
     non-negative with the counted quantity; if not, the line goes to ST_AUTO_ADJ_ERR and is skipped. Otherwise the book balance is issued on
     one issue voucher (TRNS_SERIAL max+1, INVOICE_NO type||serial(7), TAKING_FLAG 1, "تسوية الية للجرد بتاريخ  dd-mm-yyyy");
   - book balance < 0: the negative balance is received on a receipt voucher (DOC_NO = issue type || issue serial).
4. Pass 2: the counted quantity of each ticked line not in ST_AUTO_ADJ_ERR is received on a (new) receipt voucher at the count cost
   (unit price = cost x factor). ST_AUTO_ADJ_ERR is emptied at the start (legacy TRUNCATE).
5. Costs and balances of the new lines and of the following transactions are maintained by the ST_TRNS_DET triggers.

## APEX implementation

`auto_adjust(p_taking_date, p_store_code, p_issue_type, p_rec_type, p_group_code, p_item_code, p_company_code, p_user_code, p_password_number)`:
validations above (ORA-20151..20156), `delete from st_auto_adj_err` instead of TRUNCATE (no implicit commit), the two passes as in MAKE_ADJUST,
no COMMIT; counter of refused lines in `last_gl_count` (legacy alert UPDATE_ERROR). The preview is `table(app_proc_st.auto_adj_lines(store, date))`
with column "خطأ تسوية" = 1 for items refused by the last run (replaces the report ST_AUTO_ADJ_ERR.RDF).
Deviation: the legacy user could untick individual lines (DET_BLK.AUTO, "اختيار الكل" / "استبعاد الكل"); APEX adjusts all lines or one group / item.

## Tests (all rolled back)

- Store 101010101001, count of 2025-11-01: 403 differing lines (preview 0.1 s); run -> one issue voucher 11701/5 with 9 lines (1 377 units),
  229 items refused into ST_AUTO_ADJ_ERR (later issues would become negative), no receipt (all counted items refused).
- Count of 2025-03-05 (already adjusted in 2025 by the legacy form): 414 lines, one new issue voucher; numbering identical to the legacy vouchers.
- Wrong issue type for the store -> ORA-20155; LOV / preview queries validated.

## Open questions

1. The test counts in ST_STOCK_TAKING_DET contain one line each: running the adjustment would issue the whole book stock of every uncounted item.
   Is "not counted = zero" the intended rule (legacy behaviour), or should only counted items be adjusted?
2. Should individual line selection (DET_BLK.AUTO) be restored (e.g. an interactive grid with a check box) instead of the group / item filter?
