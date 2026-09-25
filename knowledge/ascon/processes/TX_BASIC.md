# TX_BASIC - مؤشرات النظام / System Parameters (Taxes)

- Registry: system 88 (Taxes) serial 21, order 4001. APEX grid page 70110.
- Legacy module: `ASCON\TX\FMB\TX_Basic.fmx` (no .fmb, no GN_FORM_ITEM labels, no embedded SQL - a pure base-table block).
- **Deliverable: (a) screen correction, no business rules** -> `app\legacy\overrides\TX_BASIC.json`, pattern `GRID` on `COMPANY`,
  **update only** (insert/delete false). Wave 3: visible columns limited to the legacy items, code and names read-only, Arabic labels.
- **Confidence: medium-high** (the table `TX_BASIC` does not exist; the block's items are the COMPANY tax columns).

## What the screen is

The tax system's parameters are kept on the company record. The form's only data block (prompt "الشركات") shows
رقم الشركة / الأسم عربى / الأسم لاتينى (`COMPANY_CODE`, `COMPANY_DESC`, `COMPANY_DESC_E`) and lets the user enter
الرقم الضريبي (`TAX_NO`), العنوان القانوني (`LEGAL_ADDRESS`) and فترة التقديم (بالشهور) (`TAX_STAT_PERIOD`, VAT return period in months).
Evidence: .fmx identifiers `COMPANY, COMPANY_CODE, COMPANY_DESC, COMPANY_DESC_E, TAX_NO, LEGAL_ADDRESS, TAX_STAT_PERIOD` and the Arabic
prompts; `TX_TAXES_TYPES` appears only as a template reference. Current data: company 1, TAX_NO 301232061500003, TAX_STAT_PERIOD 3.
`TAX_NO` and `LEGAL_ADDRESS` are copied into each new tax statement and `TAX_STAT_PERIOD` gives its period (TX_STAT).

## Rules

- None beyond the table: no embedded SQL, no own messages. "رقم مكرر تم إدخالة من قبل" (duplicate key) and "لا يجوز حذف السجل لإرتباطة
  بجداول اخري" (FK on delete) are the TX template's generic ON-ERROR texts; companies are created and deleted in the COMPANY screen
  (80010), so this screen is update-only in APEX.
- `COMPANY_TRIG` (existing DB trigger, insert/update on COMPANY) keeps working unchanged.

## APEX (override)

- `master.columns`: COMPANY_CODE, COMPANY_DESC, COMPANY_DESC_E, TAX_NO, LEGAL_ADDRESS, TAX_STAT_PERIOD (the wave-1 grid showed every
  COMPANY column); `readonly` code and names; labels from the legacy prompts.
- No PL/SQL, no row rule on `COMPANY` from this screen (the COMPANY table belongs to the security screens).


## Wave 3b

Checked, nothing to change: company tax data (tax number, legal address, statement period) on the company rows; update only, as the legacy; no check box / list item / display item beyond the company names already shown.

## Coverage

Everything of the legacy screen. A 15-digit check on `TAX_NO` (as in ACBENFTAX) is not in this legacy form - suggestion only.
