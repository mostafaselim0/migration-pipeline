# ST_DIST_COST_N - اعادة توزيع التكلفة على التحويل / Redistribute Cost on Transfers

- Registry: system 3 serial 521 (no menu entry, order 4007). APEX page 20300.
- **Deliverable: (b) process screen**
  - PL/SQL: `app_proc_st.dist_transfer_cost(p_from_date, p_to_date, ...)` in `app\db\20_proc_st.sql`.
  - Override: `app\legacy\overrides\ST_DIST_COST_N.json` (preview = transfer lines of the period with out / in cost and status).
- **Confidence: medium-high** - only the compiled form exists, but its embedded SQL contains the complete processing (two cursors, two UPDATE
  statements); the day loop and the messages come from its identifiers and texts.

## Evidence (`evidence\ST_DIST_COST_N.md`, compiled `ST\FMB\ST_DIST_COST_N.fmx`)

- Cursor 1 ("حركات تحويل يوم"): transfer-out lines (TRNS_TYPE EFFECT 5, TRNSFER_SERIAL and TRNSFER_FROM_STORE not null) of `TRNS_DATE = :b1`,
  with `GET_UNIT_COST_CONFG(store, group, item, confg, trns_date, date_serial, item_serial) ITEM_COST`
  -> `UPDATE ST_TRNS_DET SET UNIT_COST = :item_cost WHERE key AND ROUND(NVL(UNIT_COST,0),4) != ROUND(NVL(:item_cost,0),4)`.
- Cursor 2 ("حركات أستلام يوم"): the same transfer-out lines with their (new) UNIT_COST
  -> `UPDATE ST_TRNS_DET SET UNIT_PRICE = FACTOR * cost, UNIT_COST = cost WHERE (type, serial) IN (transfer-in, EFFECT 6, with TRNSFER_SERIAL =
  out.TRNSFER_SERIAL, STORE_CODE = out.TRNSFER_TO_STORE, TRNSFER_FROM_STORE = out.STORE_CODE) AND same GROUP / ITEM / BASIC_QTY / ITEM_CONFG_ID /
  ITEM_SERIAL AND cost differs`.
- Identifiers FROM_DATE, TILL_DATE, THE_DATE, VAR_LOOP; texts "من تاريخ", "الى تاريخ", "يجب ادخال من تاريخ والى تاريخ", "تم الانتهاء من التوزيع".
- Data: 26 transfer-out transactions, each with its transfer-in (same TRNSFER_SERIAL, stores swapped), item serials aligned.

## Rules

For each day from FROM_DATE to TO_DATE: (1) re-cost the transfer-out lines of the day at the average cost at the moment of the line;
(2) copy that cost to the matching transfer-in lines (unit price = cost x unit factor). The ST_TRNS_DET_C_UP trigger rebuilds ST_TRNS_DET_COST and
the cost of the following transactions of the item (UPDATE_NEXT_TRNS_CONFG_COST), which is why the loop goes day by day.
Both dates are required ("يجب ادخال من تاريخ والى تاريخ", ORA-20161); from <= to (ORA-20162). No COMMIT (see question 1).

## Tests (all rolled back)

- 2026-01-01..2026-06-30: 104 transfer lines, nothing to change (costs already consistent).
- 2025-01-01..2025-12-31: out lines already at GET_UNIT_COST_CONFG; 33 transfer-in lines re-costed, out / in mismatches 35 -> 2 (the 2 remaining
  lines do not match on the legacy key: different item serial / quantity / batch between out and in).

## Open questions

1. Did the legacy form commit per day (long periods)? The APEX process runs in one transaction; for a year of transfers it takes < 1 s here.
2. GL vouchers of already posted transfers are not re-posted after a cost change (legacy behaviour). Should the user be told to cancel and re-post
   the transfers (ST_CPOSTING / ST_POSTING) of the period?
