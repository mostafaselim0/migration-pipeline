# ARDBTRN_ST - حركات عملاء مدينة - أنظمة أخرى / Debit Customer's Transactions - Other Systems

- Registry: system 4 serial 1 (FILES_MENU.INVFROMSTORES, menu `open_form('ardbtrn_st')`, no parameters). APEX pages 30010 / 30011 / 30012.
- **Deliverable: (a) screen correction + business rules**: `app\legacy\overrides\ARDBTRN_ST.json` changes the pattern from AUTO to an explicit
  `MASTER_DETAIL` (AR_MAINTRNS + invoice lines AR_SUBTRNS) because the generated master had taken the columns of the payments block
  AR_SUBTRNS1 (no customer, no category, no description). Rules in `APP_RULES_AR` (`app\db\21_rules_ar.sql`).
- **Confidence: medium** - only the compiled .fmx and labels exist; the rules are those of ARDBTRN found in the .fmx SQL / texts, and the
  LINK_FLAG value (form parameter) is inferred from the data.

## What the screen is

The debit AR transactions that come from other systems: the block WHERE (fmx) is
`AR_MAINTRNS.LINK_FLAG = :PARAMETER.LINK_FLAG AND TRNS_ID IN (SELECT ID FROM AR_TRNSTYPE WHERE EFFECT = 0)` + the group filters. The menu
passes no parameter; LINK_FLAG = 1 is what the stock posting writes (1 318 sales invoices 101-103, POST_SYSTEM 31, all posted), and the window
title text "فواتير مدينة واردة من ..." matches. ARDBTRN shows LINK_FLAG = 0.

## Rules implemented

| Kind | Rule | Evidence (.fmx SQL / texts) | APEX |
|------|------|-----------------------------|------|
| where | `TRNS_ID in (EFFECT = 0) and LINK_FLAG = 1` + group filters | default WHERE with :PARAMETER.LINK_FLAG | `where` |
| type default / validation | TRNSTYPE LOV `select id ... from ar_trnstype WHERE effect = 0` (no group filter in this LOV) | fmx record group | default `default_type('ARDBTRN_ST')` (101); `check_header` |
| numbering | TRNS_SERIAL max+1 per TRNS_ID (`SELECT NVL(MAX(TRNS_SERIAL),0)+1 FROM AR_MAINTRNS WHERE TRNS_ID = :b1`); BILL_SEQ max+1 per document; DOC_NO typed by the user (no numbering SQL in the fmx) | fmx SQL | shared key_expr (`next_trns_serial`, debit branch); generated BILL_SEQ |
| derived | areas / category / salesman of the customer (`SELECT SALESMAN_CODE ... FROM AR_CUST_SALESMAN, SALESMAN WHERE CUSTOMER_CODE = :b1 AND CTGRY_CODE = :b2`); LINK_FLAG = 1 on new documents (so they stay in this screen); header TOTAL / NET from the invoices (VALIDATE_DETAIL_SUM in the fmx); RESIDUAL = TOTAL on new lines | fmx identifiers / SQL | key_expr + `after_save_debit('ARDBTRN_ST')` |
| validations | customer required / active / group; dates vs customer open date and opening balance (texts in the fmx); rate rules; invoice pair not repeated among debit lines (`SELECT 'x' FROM AR_SUBTRNS WHERE BILL_ID1 = NVL(:b1,0) AND BILL_ID2 = NVL(:b2,0) ...`, 'توجد فاتورة بنفس الرقم'); value > 0 ('القيمة يجب أن تكون أكبر من الصفر'); at least one invoice ('لابد من إدخال فواتير الحركة'); posted / paid documents read-only | fmx SQL / texts | `check_header`, `check_posted`, `after_save_debit` |

Not in this form (so not applied): credit limit, BILL_ID1-only uniqueness, account link block, STORE_CODE / due-date defaults.

## Wave 3 additions (compiled `ardbtrn_st.fmx`)

| Kind | Rule | Evidence (.fmx) | APEX |
|------|------|-----------------|------|
| running balance | AR_SUBTRNS PRE-INSERT: CUSTOMER.CRN_BAL_TOTAL + TOTAL_VALUE of the new invoice (only the customer row, not AR_CUST_SALESMAN) | `UPDATE CUSTOMER SET CRN_BAL_TOTAL = NVL(CRN_BAL_TOTAL,0) + ...` | `after_save_debit('ARDBTRN_ST')` (new lines) |
| invoice deleted | DELETE_PAY_ENTRIES variant: CUSTOMER.CRN_BAL_TOTAL - invoice total; payment lines (EFFECT 1) with the same BILL_ID1 / BILL_ID2 / STORE_CODE deleted, their payment RESIDUAL_VALUE + line total (no posted check in this variant) | DELETE_PAY_ENTRIES SQL | delete hook `APP_RULES_AR_SUB_BD` |
| POST_SYSTEM | value from SYS_SYSTEMS except 0 / 99 (POST_SYSTEM_LIST) | record group | `check_header_st('ARDBTRN_ST')`; system name in `info` |
| info | customer balance, system name | display items | `info` |

## Tests

Wave 2 (`app_rules_ar` suite 66/66, rolled back): default type 101, 101 accepted / credit types refused, debit after-save with the
"other systems" branch (LINK_FLAG 1, no document numbering, no credit limit).

Wave 3 (`tmp\w3_argl\t_ar.py`, APEX session on page 30011, rolled back): new document 101 with invoice 250 -> CUSTOMER.CRN_BAL_TOTAL + 250;
invoice deleted -> CRN_BAL_TOTAL back; posted-document refusal shared with ARDBTRN.

## Wave 3b (new generator keys; evidence: `.fmx` record groups / SQL and GN_FORM_ITEM item types of `evidence\ARDBTRN_ST.md`)

| Legacy | Evidence | APEX |
|--------|----------|------|
| POST_SYSTEM shown as the list POST_SYSTEM_LIST "النظام" (`SELECT SYSTEM_DESC_A, TO_CHAR(SYSTEM_NUMBER) FROM SYS_SYSTEMS WHERE SYSTEM_NUMBER NOT IN (0,99)`) | [LS] item, record group | `lov` (select list; English names when the language is English) |
| TRNS_ID list (`ar_trnstype WHERE effect = 0` + AR_TRNSTYPE_PASSWORD) | TRNSTYPE record group | `lov` |
| CTGRY_CODE, SALESMAN_ID, TRNS_ACCOUNT / CUSTOMER_ACCOUNT / DISC_ACCOUNT, COST_CODE1 with names (CATGRY_LOV, SALESMAN_LOV of the customer and category, CUST_ACC_LOV / DISC_ACC_LOV / ACCOUNT_LOV, COST_LOV) | [L] LOVs, name SQL of POST-QUERY | `lov` (salesman: `cascade` on CUSTOMER_ID / CTGRY_CODE) |
| MAINAREA_DESC / SUBAREA_DESC | [D] items, `SELECT NAME_A ... FROM AR_MAINAREA / AR_SUBAREA` | computed master columns |
| Line values in local currency TOTAL_VALUE_RIYALH / RESIDUAL_VALUE_RIYALH | [T]/[D] items "القيمة بالريال" / "القيمة المتبقية بالريال" | computed grid columns (rate * value) |

No UpdateAllowed / Required / block flags are readable from the .fmx: not changed. SQL of every list / computed column run on the build copy
(`tmp\w3b_gl\check.py`, problems 0).

## Coverage

Reproduced: tables above. Not reproduced, with reason:

- Posting from the screen (the fmx inserts AC_YEARLY_TRN directly): LINK_FLAG = 1 documents come from the stock posting already posted; the
  posting part of this form could not be isolated from the compiled form.
- VALIDATE_DATE (AC_BASIC.MIN_DATE): present in the .fmx, call site not identifiable.
- Printing (ardbtrn_st_rep.rdf - see prints), protection / SET_IP / prompts.
- Type-dependent visibility of the accounts / cost centres (AR_TRNSTYPE settings read by the form): the fields are always shown.
- (Resolved in wave 3b: POST_SYSTEM is now the legacy list.)

## Open questions

1. Confirm :PARAMETER.LINK_FLAG = 1 (default value of the form parameter is not readable from the .fmx).
2. Should documents be created here at all? A manual LINK_FLAG = 1 document is never posted by the APEX AR posting (legacy posted it from this
   screen). If not, set `"insert": false` in the override.
