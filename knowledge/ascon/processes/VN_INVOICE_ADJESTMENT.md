# VN_INVOICE_ADJESTMENT - تسوية فواتير الموردين / Supplier's Invoices Adjustment

- Registry: system 5 serial 8 (menu `FILES_MENU.SUPPLIER_ADJUST`, order 106). APEX page 40050.
- **Deliverable: (b) process screen** - `app\legacy\overrides\VN_INVOICE_ADJESTMENT.json` (`"pattern": "PROCESS"`), procedure
  `app_rules3_vn.invoice_adjust(p_action, p_supplier, ...)` in `app\db\25_rules3_vn.sql`. The generated screen (an editable grid on SUPPLIER
  with CODE / NAME_A) was wrong: the legacy form does not edit suppliers, it allocates their payments.
- **Confidence: medium-high** - SQL and texts of the compiled `VN\FMB\VN_INVOICE_ADJESTMENT.fmx`; the logic is identical to the source of
  its AR twin `AR\FMB\AR_INVOICE_ADJESTMENT_fmb.xml` (module PR_INVOICE_ADJESTMENT, alert title "تسوية فواتير الموردين"), which was checked
  trigger by trigger. Tested on the build copy.

## What the legacy screen is

A query-only grid of leaf suppliers (`NVL(SUPPLIER_STATUS,0) = 1` + the group's supplier range) with CODE, NAME_A, CURRENCY_CODE, VN_BAL
"رصيد المورد" and VN_INV_TOTAL "إجمالي المتبقي من الفواتير" (POST-QUERY) and a check box ADJ_FLAG "تسوية"; buttons "اختيار الكل" / "ازالة
الكل" (tick / untick every row), "تسكين السدادات للمورد" (MAKE_ADJUST), "اعادة احتساب الرصيد" / "اعادة احتساب إجمالي الفواتير" (recompute the
two display columns) and the toolbar delete key on a supplier row (removes the supplier's allocations).

## Evidence

- POST-QUERY: VN_BAL = credit documents - debit documents (`SUM(TOTAL_VALUE) ... EFFECT = 0 AND (PAY_METHOD NOT IN (2,3,4) OR PAY_FLAG = 1)`,
  `... EFFECT = 1`); VN_INV_TOTAL = `SUM(RESIDUAL_VALUE)` of the credit invoice lines.
- MAKE_ADJUST (cursor C_S over the supplier's EFFECT 0 documents with `SUM(SB.TOTAL_VALUE)` of their lines; C_B over the open EFFECT 1
  invoice lines of the same supplier, currency and `VN_SUBTRNS.PAY_TYPE_CODE`, `ORDER BY TRNS_DATE, BILL_ID1, BILL_ID2`): for a payment with
  TOTAL > lines, `MAX(NVL(BILL_SEQ,0))+1`, `INSERT INTO VN_SUBTRNS (TRNS_ID, TRNS_SERIAL, BILL_SEQ, BILL_ID1, BILL_ID2, TOTAL_VALUE, DISC_VALUE,
  NET_VALUE, RESIDUAL_VALUE) VALUES (payment, seq, invoice bill ids, amount, 0, amount, 0)`, invoice line `RESIDUAL_VALUE = 0` or `= residual -
  amount`, `UPDATE VN_MAINTRNS SET RESIDUAL_VALUE = :rest` on the payment; then COMMIT_FORM and "تمت التسوية بنجاح". The AR source adds the
  condition `ADJ_FLAG = 'Y' AND balance != open invoices` per supplier.
- Delete key (block with "تم الانتهاء من حذف الفواتير"): `DELETE FROM VN_SUBTRNS WHERE TRNS_ID IN (EFFECT 0) AND GET_SUPPLIER(TRNS_ID,
  TRNS_SERIAL) = :code`; `UPDATE VN_MAINTRNS SET TOTAL_VALUE = sum of lines` for EFFECT 1 documents whose total differs; invoice line
  `RESIDUAL_VALUE = TOTAL_VALUE - NVL(paid,0)` with paid = `SUM(VN_SUB.TOTAL_VALUE)` of EFFECT 0 lines of the same supplier with the same
  BILL_ID1 / BILL_ID2 (also `ASCON\VN\FMB\correct_supp_residual.txt`).

## Rules implemented (`invoice_adjust`)

- Parameters: ACTION (1 "تسكين السدادات للمورد", 2 "حذف تسكينات المورد (ازالة السدادات)") and SUPPLIER (LOV = the legacy list: leaf
  suppliers of the group range; empty = all suppliers of the list, the legacy "اختيار الكل"). A chosen supplier must be a leaf in the group's
  range ("خطأ صلاحية").
- Action 1 per supplier, skipped when the balance equals the open invoices (legacy condition): every debit document (payment, debit
  settlement, return, debit opening balance), oldest first, with TOTAL > its lines spreads the rest over the open invoice lines of the same
  currency and payment type, oldest first; inserts the payment line (value, NET = value, DISC 0, RESIDUAL 0, invoice BILL_ID1 / BILL_ID2),
  sets the invoice line residual and the payment residual to the unallocated rest.
- Action 2 (delete key): deletes all allocation lines of the supplier's debit documents, sets the credit documents' TOTAL_VALUE to the sum of
  their lines, recomputes the invoice-line residuals (value - paid) and the payment residuals (= total).
- Preview (the legacy grid, recomputed at each page load = the two "اعادة احتساب" buttons): code, name, currency, balance (legacy
  formula), open invoices, unallocated payments; filtered to the chosen supplier.
- No COMMIT (APEX commits); errors ORA-20100 with the texts "اختر المورد", "اختر العملية", "المورد غير موجود أو ليس موردا فرعيا", "خطأ صلاحية".

## Deviations (deliberate)

1. **Open value of an invoice line** = value - paid, paid = payment lines linked to it (INV_TRNS_ID / SERIAL / BILL_SEQ) + unlinked payment
   lines of the supplier with the same BILL_ID1 / BILL_ID2 (the legacy "remove" formula), instead of the stored RESIDUAL_VALUE (different
   from that formula on 146 of 641 invoice lines today). The stored residual is refreshed for every invoice line paid.
2. The new payment lines also get INV_TRNS_ID / INV_TRNS_SERIAL / INV_BILL_SEQ / INV_DATE of the invoice line: the wave-2 AP screens and
   VN_SUBTRNS_PAYED_VALUE find the paid invoice through these columns (518 of 863 existing lines have them).
3. Invoice lines with a negative residual (overpaid) are not "open" (the legacy `RESIDUAL_VALUE != 0` would allocate a negative amount).
4. The legacy TOTAL_VALUE repair of credit documents in the delete action had no supplier filter; APEX limits it to the chosen supplier.
5. Payment residuals are also reset by the delete action (the legacy left them until the next adjustment).
6. Payments are processed oldest first (the VN cursor had no ORDER BY; the AR twin orders by TRNS_DATE).

## Tests (t_vn4, build copy, rolled back)

Remove without supplier, unknown action, parent supplier, supplier outside the group range refused. Supplier 101860100000: open payments
1 078.70 allocated to its oldest open invoice (1 line, linked, NET = value, residual 0), open invoices reduced by the same amount, payment
residual = total - lines, invoice residual refreshed, no overpaid invoice / over-allocated payment, second run adds nothing. Supplier
102270100000: 22 320.04 over 3 lines, same checks. Remove for 101860100000: all its allocation lines deleted, invoice residuals = value,
payment residuals = value, credit totals = sum of lines. Group 102 (range to 102320100000): supplier 200012100000 untouched; all suppliers:
no new overpaid invoice or over-allocated payment, message with the line count. 24/24 passed.

## Open questions

1. The legacy removal deletes also the payment lines entered by hand in VNDBTRN (all EFFECT 0 lines of the supplier) and leaves the payment
   headers' DISC_VALUE / CURRENCY_DIFF_VALUE (line sums in VNDBTRN) as they were - confirm that this is the intended "ازالة".
2. Payments and invoices of different PAY_TYPE_CODE / currency are never matched (legacy); all data today has payment type 1.

## Coverage

Reproduced: MAKE_ADJUST, select all / one supplier, the delete-key removal, the balance and open-invoice columns (preview), the recalc
buttons (the preview is recomputed on every load). Not reproduced: ticking several (but not all) suppliers - the process page takes one
supplier or all (generator gap: no multi-select parameter); the dynamic success text (process pages show a fixed text; the count is in
`last_message`); COMMIT per supplier (one transaction); print, exit button (Forms-only).
