# VNTRN_OP - الأرصدة الافتتاحية للموردين / Supplier Opening Balances

- Registry: system 5 serial 10 "الأرصدة الافتتاحية الدائنة للموردين" (menu `SYSTEMS_MENU.VNTRN_OP`, order 402) and serial 31 "الأرصدة
  الافتتاحية المدينة للموردين" (`VNTRN_OP_d`, order 403) - one form, the menu entry passes PARAMETER.EFFECT (1 credit / 0 debit).
  APEX list page 40160, document page 40161 (both effects on one screen: the type decides).
- **Deliverable: generated master-detail kept (`"pattern": "AUTO"`: VN_MAINTRNS_OP + VN_SUBTRNS_OP) + rules** -
  `app\legacy\overrides\VNTRN_OP.json`, package `APP_RULES3_VN` (op_default_type, op_mast_row, op_line_row, op_line_upd_check, op_line_del,
  op_after_save + triggers `APP_RULES3_VN_OPLINE_BD`, `APP_RULES3_VN_OPLINE_AU`). Same design as ARTRN_OP (APP_RULES3_AR.op_*), checked
  against the VN evidence.
- **Confidence: medium-high** - compiled form (all SQL and texts), confirmed on the data: 7 headers (901 credit, 902 debit, 2021 and 2024),
  45 lines; every 2024 line has its generated VN_MAINTRNS row (TRNS_SERIAL = R_TRNS_SERIAL, POST_FLAG 1, LINK_FLAG 0, PAY_METHOD 5,
  RESIDUAL = TOTAL, PAY_TYPE_CODE 1, description of the header) and the 901 lines their VN_SUBTRNS invoice line (BILL_SEQ 1,
  BILL_ID1 = BILL_ID2 = 9999); SUPPLIER.BEG_BAL = -value (credit) / +value (debit); no supplier has two opening balances.

## Evidence (`evidence\VNTRN_OP.md`, compiled `VN\FMB\VnTrn_op.fmx`)

- Header block WHERE: group filter on TRNS_ID + effect of the menu entry; TRNSTYPE LOV `TRNS_TYPE IN (5)` + VN_TRNSTYPE_PASSWORD.
- Header: TRNS_SERIAL = `NVL(MAX(TRNS_SERIAL),0)+1 FROM VN_MAINTRNS_OP WHERE TRNS_ID`; TRNS_ID WHEN-VALIDATE-ITEM reads DESCRIPTION_A/E,
  DESC_FLAG, DOC_FLAG ... of VN_TRNSTYPE (description of the type); DOC_NO WHEN-VALIDATE-ITEM "رقم المستند يجب ان يكون اكبر من الصفر" +
  DESC_FLAG (VNDBTRN.fmb: flag 1 = description || ' - ' || doc no); TRNS_DATE: CHECK_DATE (library TRANSLATE, system 5: not after today,
  not before MIN(VN_BASIC.MIN_DATE)); "يجب ادخال تفاصيل سداد" when the header has no lines; ON-CHECK-DELETE-MASTER.
- Lines: BILL_SEQ max+1 (LKP_MASTER); SUPPLIER_ID WHEN-VALIDATE-ITEM (name, currency and rate of the supplier, "خطأ فى المورد", "خطأ فى عملة
  المورد"); CURRENCY_RATE ("يجب ان يكون معامل التحويل أكبر من 0", "معامل تحويل الريال لابد أن يكون 1"); values "يجب ان يكون القيمة أكبر من
  0", "القيمة يجب أن تكون أكبر من الصفر"; BILL_ID1 -> BILL_ID2; SALES_MAN (VN_RESP LOV), PAY_TYPE_CODE (LC_SETTEL_TYPE LOV).
- PRE-INSERT of a line: "المورد الحالي له رصيد افتتاحي" (`COUNT(1) FROM VN_MAINTRNS_OP M, VN_SUBTRNS_OP D ... D.SUPPLIER_ID`), "المورد الحالي
  له حركات فى الملف الرئيسى قبل تاريخ الرصيد الافتتاحي" (`VN_MAINTRNS ... TRNS_DATE <= :date`), "... فى مذكرة السداد ..." (VN_PAYTRNS),
  "يجب ادخال رقم فاتوره حتى يمكن السداد عليها" (credit), INSERT_DBCR_TRN (`NVL(MAX(TRNS_SERIAL),0)+1 FROM VN_MAINTRNS WHERE TRNS_ID`,
  `INSERT INTO VN_MAINTRNS (... LINK_FLAG 0, POST_FLAG 1, RESIDUAL = value, PAY_METHOD 5 ...)`, for a credit balance `INSERT INTO VN_SUBTRNS
  (... BILL_SEQ 1 ...)`), `UPDATE SUPPLIER SET CRN_BAL_TOTAL = NVL(CRN_BAL_TOTAL,0) + DECODE(effect,1,-v,0,v), BEG_BAL = DECODE(...)`.
- PRE-UPDATE of a line: "المورد الحالي له رصيد افتتاحي فى نفس تاريخ" + the two "before the date" checks.
- PRE-DELETE of a line: DELETE_DBCR_TRN (`DELETE FROM VN_SUBTRNS / VN_MAINTRNS WHERE TRNS_ID AND TRNS_SERIAL = R_TRNS_SERIAL`),
  `UPDATE SUPPLIER SET CRN_BAL_TOTAL = CRN_BAL_TOTAL - DECODE(...), BEG_BAL = 0`.
- VALIDATE_DATE (AC_BASIC.MIN_DATE, "التاريخ أقل من الحد الأدنى المسموح به") is a program unit that nothing calls (no /NSPC reference).

## Rules

| Rule | APEX |
|---|---|
| List: opening-balance types (TRNS_TYPE 5) of the group | `where` |
| Default type | `defaults` TRNS_ID = `op_default_type` (first credit type of the group, 901) |
| Header: type TRNS_TYPE 5 + group permission; CHECK_DATE; DOC_NO > 0; description of the type (DESC_FLAG 1 with " - doc no", 2 without) | row rule `op_mast_row` |
| Header type / serial cannot change while lines exist; header with lines cannot be deleted | `op_mast_row`; delete trigger on the lines with REQUEST = DELETE |
| Saved header needs lines ("يجب ادخال تفاصيل سداد") | after-save (SAVE) `op_after_save` |
| Line: supplier exists and in the group range; currency = supplier currency, rate from AC_CURRENCY (SAR = 1, > 0); value > 0; credit balance needs BILL_ID1; BILL_ID2 := BILL_ID1; responsible exists; payment type exists (default VN_BASIC.PAY_TYPE_CODE) | row rule `op_line_row` |
| Line insert: one opening balance per supplier; no main-file transaction / payment note on or before the date | `op_line_row` (single-row insert reads its table) |
| Generated supplier transaction (VN_MAINTRNS; + VN_SUBTRNS invoice line for a credit balance) and SUPPLIER.CRN_BAL_TOTAL / BEG_BAL | `op_line_row` (R_TRNS_SERIAL read-only) |
| Line update: no other opening balance of the supplier on the same date, no earlier transactions (after the statement) | compound trigger -> `op_line_upd_check` |
| Line update of supplier / value / bill / currency / rate / payment type: generated transaction replaced, balances moved | `op_line_row` |
| Line delete: generated transaction removed, balances back | delete trigger -> `op_line_del` |
| Allocated opening balance (payments on the credit invoice line / allocation lines on the debit transaction) cannot be changed or deleted | `op_check_alloc` (own text) |
| Info panel: total in currency and in SAR, effect | `info` |

Tests (t_vn3, rolled back): type 101, tomorrow, 01/01/2021 and DOC_NO -1 refused; default type 901; serial max+1 and description "ارصدة
افتتاحية دائنة - 55"; save without lines refused; supplier missing / unknown, value 0, credit without invoice number, SAR rate 2, unknown
responsible, supplier with earlier transactions refused; valid credit line -> VN_MAINTRNS 901/42 (posted flag 1, pay method 5, residual,
description, doc no) + VN_SUBTRNS invoice line + BEG_BAL -1234.5 / CRN_BAL_TOTAL -1234.5; second line of the supplier refused; value change
regenerates the transaction and the balances; responsible-only change keeps it; allocated balance cannot change / be deleted; document delete
and header serial change with lines refused; line delete removes the transaction and resets the balances; debit balance (902) with a USD
supplier -> currency 2, rate 3.756, no invoice line, BEG_BAL +500; supplier change to a supplier with an opening balance on the same date
refused (after the statement), to a free supplier accepted and moved. 37/37 passed.

## Deviations (deliberate) and open questions

1. The legacy PRE-UPDATE did not replace the generated transaction, and its "transactions before the date" count included the line's own
   generated VN_MAINTRNS row (so a line could practically not be changed). APEX excludes the opening-balance transactions from that count and
   replaces the generated transaction when the line changes - as ARTRN_OP does. Confirm.
2. The legacy "same date" and "has an opening balance" SQL join VN_MAINTRNS_OP to itself (`M.TRNS_ID = M.TRNS_ID`); APEX applies the intended
   check per supplier (no supplier has two opening balances today).
3. An allocated opening balance cannot be changed or deleted in APEX (the legacy deleted the invoice line / allocation lines without looking).
4. The shared VN_MAINTRNS row rule of VNDBTRN / VNCRTRN (owned by the AP buttons agent) also fills BILL_PAY_METHOD 1 and RESP_CODE (first
   responsible of the supplier) on the generated rows; the legacy left both empty. Harmless; the owner may exclude TRNS_TYPE 5 if wanted.
5. Changing the header date or document number does not update the already generated transactions (legacy behaviour).

## Coverage

Reproduced: numbering, type / date / document checks, description, line checks and derivations, the generated supplier transaction and
invoice line, supplier balance fields, insert / update / delete rules. Not reproduced: the menu parameter EFFECT (one screen for both
effects; the type decides - the type LOV shows all types, generator gap: no per-column LOV), TOTAL_VALUE_CURR / SUM_TOTAL_VALUE display items
(info panel), VALIDATE_DATE (dead code), print (VnTrn_op_REP), toolbar.
