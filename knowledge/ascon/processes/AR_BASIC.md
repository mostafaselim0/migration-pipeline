# AR_BASIC - مؤشرات النظام / System Parameters (AR)

- Registry: system 4 serial 31 (`SYSTEM_MENU.AR_BASIC`). Legacy `ASCON\AR\FMB\AR_BASIC.fmx` (no .fmb). 1 row.
- APEX: corrected from a 3-column grid to a list + single-record form (`REPORT_FORM`) with the indicators of the legacy form; the
  confirmation in `APP_RULES3_AR`.

## Rules and buttons

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| fields: الحد الأدنى / الأقصى لتاريخ الحركة, تكوين رقم العميل آليا (`AUTO_SERIAL`), إحتساب عمولات المندوبين على المبيعات / على التحصيل (`CALC_COMM`), ربط المندوب والعميل بالقسم إجباري (`SALESMAN_CUST_FLAG`), ايقاف العملاء غير مستوفي الشروط (`STOP_CUST_FLAG`) | labels, .fmx texts, columns | columns + labels (`add_columns`; the generated grid showed three of them) | high |
| "توجد حركات بالفعل بالنظام" + "هل تريد تغيير المؤشر الآن" (`TRNS_EXIST`) | messages, identifiers | `warnings`: confirmation when an indicator changes while AR transactions exist | medium (which indicators trigger it is not visible) |
| company of the session | `COMPANY_CODE` key | default `G_COMPANY_CODE`, hidden | high |

## Coverage

- Reproduced: the parameters and the confirmation.
- Cannot reconstruct: button "إحتساب عمولات المندوبين" (`PUSH_BUTTON77`) - the compiled form shows no SQL or procedure for it (it probably
  opens the commission screen AR_SALESMAN_COMM_REV, which has its own menu entry); button `COMPARE`; message "القيمة يجب أن تكون أكبر من
  صفر أو خالية." (field unknown); the five `SELECT COUNT(*) FROM ST_BASIC` checks. Questions for the key user: what did the commission
  button run, and which field must be > 0?
