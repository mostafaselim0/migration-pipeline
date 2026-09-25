# VNCHECKPAY - اذونات صرف شيكات الموردين / Supplier Cheque Payment Requests

- Registry: system 5 serial 6 (menu `FILES_MENU.VNCHECKPAY`). APEX list page 40190, document page 40191.
- **Deliverable: data-entry screen, `"pattern": "AUTO"` + rules** (`app\legacy\overrides\VNCHECKPAY.json`); PL/SQL in `APP_RULES_VN`
  (`app\db\21_rules_vn.sql`).
- Tables: VN_MAINTRNS_CHECK (request header, own table - no screen filter needed), VN_SUBTRNS_CHECK (invoices to pay).
- **Confidence: medium-low** - compiled form only and both tables are empty on this site (feature not used, nothing to verify the rules
  against). Clear parts: numbering, supplier/currency/date checks, invoice-line checks and the "authorised -> locked" rule (explicit SQL and
  messages). The balance-analysis fields (EXP / RET / RECALL / HOLD / BONUS amounts and their discount amounts, DUE_AMOUNT) cannot be
  rebuilt from the .fmx SQL alone.

## Evidence (`evidence\VNCHECKPAY.md`)

- Numbering `SELECT NVL(MAX(SERIAL),0)+1 FROM VN_MAINTRNS_CHECK` (whole table) and `NVL(MAX(BILL_SEQ),0)+1 ... WHERE SERIAL = :b1` - both equal
  to the generic max+1 of the generated APPX triggers, so no key_expr.
- Supplier: `NVL(STOPFLAG,0)` ("هذا المورد متوقف"), START_DATE ("تاريخ الاستحقاق لا يمكن ان يكون اقل من تاريخ فتح المورد"), supplier record group
  (not stopped, SUPPLIER_STATUS = 1, VN_SUPPLIER_PASSWORD range), currency and rate from the supplier, balance = credit invoice lines - debit
  transactions (DUM_SUM / DUM_SUM_1), cheques not yet paid (`PAY_FLAG = 0 AND PAY_METHOD IN (2,4)` payments), VN_SUPP_RESP.
- Invoice lines: BILL record group (open credit-invoice lines, residual = total - VN_SUBTRNS_PAYED_VALUE - VN_SUBTRNS_CHECK_PAYED_VALUE,
  same currency, not stopped), messages "القيمة يجب أن تكون أكبر من الصفر", "قيمة الخصم لابد أن تكون أقل من القيمة المدخلة للفاتورة",
  "القيمة المتبقية بالفاتورة أصغر من القيمة المدخلة للسداد", "لا يجب ادخال قيمة في حالة العملة ريال", "السداد يحتوي على اكثر من فاتوره بالفعل",
  "خطأ في اجمالي مبالغ الفواتير".
- Header: "رقم المستند يجب ان يكون اكبر من الصفر", "يجب ان يكون معامل التحويل 1 / أكبر من 0", "أدخل رقم بقيمة تبدأ من الصفر و أقل من المئة"
  (DUE_DISC %), "يجب حذف التفاصيل قبل تغيير المورد".
- Authorisation: `SELECT NVL(VN_PAY_AUTH1..6,0) FROM USERS`, ACCEPT/REFUSE_AUTH_BTN1..6, `SELECT AUTH_FLAG FROM VN_MAINTRNS_CHECK`,
  "الحركة الحالية تم اعتمادها و لا يمكن حذفها"; delete removes VN_SUBTRNS_CHECK lines.

## Rules implemented

| Rule | Where | Detail |
|---|---|---|
| Header validation (CREATE, SAVE) | `check_checkpay(...)` | SAVE of an authorised request -> "الحركة الحالية تم اعتمادها و لا يمكن تعديلها"; supplier change with lines -> refused; supplier exists, not stopped / active / in range (CREATE or change); currency = supplier currency, rate > 0, SAR rate 1; FROM/TO/DUE dates not before VN_BASIC.MIN_DATE, supplier START_DATE, opening-balance date; DOC_NO > 0; DUE_DISC 0..<100; setting AUTH_FLAG requires a user with any USERS.VN_PAY_AUTHn = 1. |
| Supplier snapshot | `row_rules` VN_MAINTRNS_CHECK (insert / supplier change) | SUPPLIER_BAL (absolute) + DB_CR_FLAG(_E) ('د'/'C' credit, 'م'/'D' debit), CHECK_HOLD, currency / rate when empty, RESP_CODE. |
| Invoice lines (CREATE, SAVE) | `after_save_checkpay` | each line resolved to one open invoice line of the supplier (BILL_ID1/BILL_ID2 or invoice transaction), value > 0, discount 0..value, value <= residual (payments and other requests deducted), no currency difference in SAR; fills INV_*, BILL_ID2, INV_DATE, INV_SUPPLIER_REF, PAY_TYPE_CODE, RESIDUAL_VALUE, NET_VALUE; single-pay supplier -> one line; sum(net) <= CHECK_AMOUNT. |
| Delete (DELETE) | `on_delete_checkpay` | authorised (committed AUTH_FLAG read by flashback query, page value as fallback) -> error (rolled back). A request with invoice lines cannot be deleted until the lines are removed (FK VN_SUBTRNS_CHECK1_FK; legacy deleted them). |
| Read-only | `readonly` | SERIAL, SUPPLIER_BAL, CHECK_HOLD, line NET_VALUE, INV_DATE. |

Dropped (wave 2; wave 3 implements the approvals, see the end of this file): the six-level approval buttons (a workflow action - needs a process/button, see open questions), EXP / RET / RECALL / HOLD / BONUS
analysis amounts (damaged/recall store stock valuation of the supplier's items, returns not yet claimed, SUPPLIER_STAT statement matching) -
formulas not recoverable from the compiled form; alerts / printing.

## Tests (rolled back)

- Request for supplier 101790100000 with CHECK_AMOUNT 5000 and a 4000 line on invoice 10803213: resolved to 101/547/1, NET 4000,
  residual 10000.07; 6000 -> ORA-20190. Supplier snapshot: balance 379 869 'د'/'C' = GET_SUPPLIER_BAL, CHECK_HOLD 0.
- DUE_DISC 150 -> message; AUTH_FLAG 1 by a user without VN_PAY_AUTH -> "ليس لديك صلاحية اعتماد اذونات صرف الشيكات"; SAVE / DELETE of an
  authorised request -> refused.
- Row rule compiled on a scratch copy and exercised in an APEX session (serial 1, balance, flags).

## Open questions

1. Approval workflow: legacy approvals go level by level (VN_PAY_AUTH1..6 flags per user, ACCEPT/REFUSE buttons, memo per level). The generated
   page only has AUTH_FLAG (checkbox, allowed for approvers). A small process screen "approve / refuse request" is needed if the feature is used.
2. The analysis amounts (EXP_AMOUNT, RET_AMOUNT, RECALL_AMOUNT, HOLD_DISC, BONUS_AMOUNT, *_DISC_AMOUNT, DUE_AMOUNT, MATCH_STTM/MATCH_DATE) are
   left as typed fields; their formulas need the .fmb source or the key user.
3. AUTH_FLAG stays editable (for approvers only) until an approval process exists; the delete check reads the committed flag, so unticking it
   on the page does not allow deleting an authorised request.
4. Feature unused on this site (0 rows) - confirm whether the screen is needed at all.

## Wave 3 (approval levels)

| Legacy | APEX | Evidence / notes |
|---|---|---|
| ACCEPT_AUTH_BTN1..6 ("موافق"): VN_PAY_AUTHn := 1, COMMIT_FORM | action AUTH_ACCEPT (level + memo) -> `app_act_pr.checkpay_decide(.., 1, ..)` | p-code constant 1; buttons of level n enabled when USERS.VN_PAY_AUTHn = 1 (WHEN-NEW-FORM-INSTANCE) |
| REFUSE_AUTH_BTN1..6 ("مرفوض"): VN_PAY_AUTHn := -1 | action AUTH_REFUSE -> `checkpay_decide(.., -1, ..)` | p-code constant -1 (`3e 64 66`) |
| VN_PAY_AUTHn_MEMO_BTN (EDIT_TEXTITEM on VN_PAY_AUTHn_MEMO) | action AUTH_MEMO -> `app_act_pr.checkpay_memo` | same level right |
| SET_BACKGROUD colours (green approved, red refused, white none) | `info` AUTH1..AUTH6 -> `checkpay_level_text` ("موافق - memo", "مرفوض", "-") | |
| AUTH_FLAG = 1: request locked (CLOSE_POSTED, PRE-UPDATE AUTH_ALR2) | actions hidden and refused ("الحركة الحالية تم اعتمادها و لا يمكن تعديلها") | |

Who may approve which level: the user's own USERS.VN_PAY_AUTHn flags (LOV of the levels). Order of the levels: none in the evidence
(each level independent, a decision can be changed until the request is authorised). Un-approve: "مرفوض" on an approved level (no reset
button in the legacy). Effect on posting: none - no program unit or DB code reads VN_MAINTRNS_CHECK (the cheque systems RP / CK that
would use it are not installed); AUTH_FLAG stays the manual "authorised" flag of wave 2.

Tests (build copy, all rolled back, plain and inside a simulated APEX session of app 100 with the regenerated APPX_ triggers; scripts in the job folder `tmp\w3_purch`: t_vn.py, t_po.py, t_lot.py, t_st.py, t_quot.py, t_reg.py; static check chk.py): approve level 1 with memo, refuse level 2, re-approve, memo only, invalid level, user 102 without VN_PAY_AUTH (no buttons,
refused), authorised request (no buttons, refused) - t_vn.py.

## Wave 3b
Evidence: the LOV queries of the .fmx (evidence pack).
* Lists: SUPPLIER_ID (active, not stopped, VN_SUPPLIER_PASSWORD range), BOX_CODE (RP_BOXS with RP_BOXS_PASSWORD), BANK_CODE (BANK with
  BANK_PASSWORD), BRANCH (branches of the chosen bank: cascading list on BANK_CODE), and on the lines BILL_ID1 = the legacy invoice LOV:
  open invoices of the request's supplier in its currency and payment type (stored residual not 0, not stopped, not fully paid by
  payments nor by cheque requests: VN_SUBTRNS_PAYED_VALUE / VN_SUBTRNS_CHECK_PAYED_VALUE), with the residual in the display; the grid
  reads the header through the line's SERIAL (cascade SERIAL). Run with the values of supplier 102220100000: 4 open invoices.
* The payment-method list ("نوع السداد", PAY_METHOD_DUMMY) is not placed: no rule of the screen uses PAY_METHOD and the tables are empty
  (0 requests), so its role in the approval flow is not known (question below).
* Check: `check_forms.py VNCHECKPAY`.

Question: which payment methods may a cheque request use (the .fmx has the list texts نقدى / حسابات / تحويل), and should the screen show
it?

## Coverage
Reproduced: header / line rules, supplier snapshot, delete rule (wave 2); six approval levels with memos and their display (wave 3);
legacy supplier / cash box / bank / branch / open-invoice lists (wave 3b).

Not reproduced, with the reason:
* EXP / RET / RECALL / HOLD / BONUS analysis amounts, their discount amounts, DUE_AMOUNT (GET_DUE_AMOUNT) and MATCH_STTM: formulas not
  recoverable from the compiled form (no SQL in the .fmx for them) and no data (0 requests) - question for the business.
* Printing, alerts.
