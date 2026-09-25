# ST_CPOSTING - إلغاء ترحيل حركات المخازن / Cancel Posting Stores Transactions (GL, AR, AP)

- Registry: system 3 serial 509 (menu `SYSTEM_MENU.UNPOSTING`), system 30 serial 28 "الغاء الترحيل", system 31 serial 27. APEX page 20470.
- **Deliverable: (b) process screen**
  - PL/SQL: `app_proc_st.cancel_trns` in `app\db\20_proc_st.sql` (package `APP_PROC_ST`, VALID).
  - Override: `app\legacy\overrides\ST_CPOSTING.json` (preview = posted transactions, voucher sharing count, cancel messages).
- **Confidence: high** (verbatim port of MAKE_REVERSE_ACC / MAKE_REVERSE_CUSTOMER / MAKE_REVERSE_SUPP; exercised on 234 real transactions).

## Evidence

`evidence\ST_CPOSTING.md` (labels only: CUST_CAN / SUPP_CAN / AC_CAN buttons "إلغاء ترحيل الحسابات / العملاء / الموردين") and the source of
`ST_POSTING_CPOSTING.fmb` (FILTER = 2 branch of AC_BTN / AR_BTN / VN_BTN) - see ST_POSTING.md.

## Rules (legacy units)

Block query as for posting but with FILTER 2 (posted to GL, or JOIN_TYPE 3 posted to AR, or JOIN_TYPE 4 posted to AP), same type security.

**GL - MAKE_REVERSE_ACC** (per posted, not deleted transaction):
1. If the voucher (AC_ENTRY_YEAR / TYPE / NO) is shared by more than one posted transaction: alert MULT_ALET "انت بصدد إلغاء قيد مجمع هل تريد
   الإستمرا؟" (OK / Cancel = stop).
2. `CHECK_VALID_CPOSTING` (legacy returns TRUE at its first line: the check "a later sale / transfer / return is already posted" is disabled).
3. Transaction date on/before AC_BASIC.CLOSE_DATE -> stop ("لا يمكن ترحيل الحركة رقم ... لأنها تقع فى فترة مقفلة").
4. Delete AC_YEARLY_TRN_DET and AC_YEARLY_TRN of the voucher; for every transaction of that voucher: POST_FLAG = 0, PC_/RP_TRNS_TYPE_CODE / SERIAL =
   NULL and delete its CHECK_MAST / RP_TRNS_MAST documents. **AC_ENTRY_YEAR / TYPE / NO are kept**, so a re-post reuses the voucher number.
   AR_MAINTRNS / VN_MAINTRNS created from the transaction keep their ACC_* values.

**AR - MAKE_REVERSE_CUSTOMER** (CUST_POST_FLAG = 1):
1. AR_TRNSTYPE.EFFECT of CUST_TRNS_ID must exist, the customer must have an area / sub-area, else warning and skip.
2. For an invoice (effect 0) whose bill is partly paid / returned (TOTAL <> TOTAL - AR_SUBTRNS_PAYED_VALUE) -> warning
   "تم سداد/مرتجع جزء من الفاتورة type/serial - سند رقم <payment doc> لا يمكن الغاء الترحيل" and skip.
3. CUSTOMER.CRN_BAL_TOTAL and AR_CUST_SALESMAN.CRN_BAL_TOTAL minus the bill total; delete AR_SUBTRNS and AR_MAINTRNS of CUST_TRNS_ID / SERIAL;
   ST_TRNS_MAST: CUST_POST_FLAG 0, CUST_TRNS_* and CUST_TRNS_PAY_* = NULL.

**AP - MAKE_REVERSE_SUPP** (SUPP_POST_FLAG = 1, not deleted):
1. Shared AP transaction (several stock transactions in one VN transaction, installation BEN) -> MULT_ALET as above.
2. Per VN_SUBTRNS line: effect of SUPP_TRNS_ID must exist; paid invoice check (see question 1); SUPPLIER.CRN_BAL_TOTAL minus the line total.
3. Expense lines (ST_TRNS_DET_EXPENS): refuse when the service-vendor transaction is paid, else delete it and clear SUPP_TRNS_* on the expense.
4. Delete the supplier-discount transaction (VN_SUBTRNS_ITEMS, VN_SUBTRNS, VN_MAINTRNS of SUPP_DISC_TRNS_*), then VN_SUBTRNS / VN_MAINTRNS of
   SUPP_TRNS_*; ST_TRNS_MAST: SUPP_POST_FLAG 0, SUPP_TRNS_* and SUPP_DISC_TRNS_* = NULL (also for the other stock transactions of the same VN transaction).

## APEX implementation

`cancel_trns(p_from_date, p_to_date, p_from_type, p_to_type, [serials, customers, salesmen], p_cancel_gl, p_cancel_ar, p_cancel_ap,
p_allow_grouped, p_company_code, p_user_code, p_password_number)` = `post_cancel(2, ...)`:
- the MULT_ALET question becomes the check box "إلغاء القيود المجمعة" (p_allow_grouped): unchecked + shared voucher -> ORA-20102, nothing is changed;
- the CUSTOM_ALERT warnings that skipped a transaction are written to ST_POST_MSG and shown in the preview (the transaction stays posted);
- closed period -> ORA-20101 (whole run rolled back); DB triggers additionally protect closed periods, authorised tax periods and revised vouchers;
- rows locked before processing; GL -> AR -> AP order; no COMMIT.

## Tests (all rolled back)

- 234 cancel + re-post cycles (see ST_POSTING.md): vouchers deleted, flags reset, AR / AP documents deleted, re-post identical.
- Group without transaction-type rights cancels nothing; cancel + re-post through `post_cancel` (combined screen) on 11301/52 works.

## Open questions / risks found in the legacy logic (reproduced as is)

1. **AP paid-invoice check never fires for stock postings**: MAKE_REVERSE_SUPP reads the invoice with `NVL(V.LINK_FLAG,0) <> 1`, but the VN
   transactions created by the stock posting have LINK_FLAG = 1, so a paid purchase invoice can be cancelled and re-posted with its full residual
   (seen on 19 of 36 sampled purchase invoices of types 10801-10803: after cancel + re-post VN_SUBTRNS.RESIDUAL_VALUE is back to the invoice
   total although payments exist; the payments still reference the bill by BILL_ID1 / BILL_ID2).
   Should cancellation be refused when VN_SUBTRNS_PAYED_VALUE > 0? (suggested improvement, not applied)
2. AR cancel of a cash sale does not delete the AR payment transaction created for PAYMENT > 0 (only its reference is cleared). Confirm or delete it too.
3. AR cancel lowers CUSTOMER.CRN_BAL_TOTAL although the AR posting never raised it (column is not maintained consistently). Keep?
4. MAKE_REVERSE_SUPP restores residuals with `trns_id IN (SELECT ID FROM AR_TRNSTYPE WHERE EFFECT = 0)` (AR table in the AP routine) - no effect today.
5. Re-enable CHECK_VALID_CPOSTING (refuse cancelling an incoming transaction when later issues are posted)? It is disabled in the legacy code.
