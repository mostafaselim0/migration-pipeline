# ACCRNCY - أرقام العملات / Currency Numbers

- Registry: system 1 serial 24 (CODES_MENU.ACCRNCY, order 2001). APEX list 10080, document 10081 (currency + rate periods), print 10082.
- Legacy module: `ASCON\AC\FMB\accrncy.fmx` (no .fmb; labels AC_CURRENCY, AC_CURRENCY_SRV_RATE, AC_CURRENCY_RATE.PERIOD_RATE).
- **Deliverable: generated master-detail kept (`AUTO`) + rules**, override `app\legacy\overrides\ACCRNCY.json`, PL/SQL `APP_RULES3_GL`,
  delete hook `APP_RULES3_GL_CURR_BD`.
- **Confidence: high** for ranges, rate-period dates and delete checks; medium for "currency 1 has rate 1".

## Rules

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | Currency number required ("يجب إدخال رقم العملة") and 0 < number < 9999 ("رقم العملة يجب ان يكون اكبر من الصفر و اصغر من 9999") | CURRENCY_CODE validation texts | validation `check_currency` (CREATE, SAVE) |
| 2 | Rate 0 < rate < 999999999.99 ("معامل التحويل يجب ان يكون اكبر من الصفر و اقل من 999999999.99") | RATE validation | validation |
| 3 | Currency 1 is the local currency (hint "كود العملة - العملة رقم 1 هى العملة المحلية"): its rate is 1 | hint + CURRENCY_CODE trigger touching RATE | row rule `currency_row` |
| 4 | Rate periods: SERIAL = MAX + 1 per currency; a date entered twice is refused ("تم إدخال هذا التاريخ من قبل !!!") | `SELECT NVL(MAX(SERIAL),0)+1 ... WHERE CURRENCY_CODE`, `SELECT COUNT(1) ... WHERE CURRENCY_CODE AND FROM_DATE` | generated max+1; after_save `currency_after_save` |
| 5 | The local currency is not deleted ("لا يمكن مسح هذا السجل حيث أنه يستخدم بالبرنامج"); a currency used by accounts or entries is not deleted ("لا يمكن مسح هذة العملة , يوجد حركات علي هذة العملة!!") | KEY-DELREC / PRE-DELETE (COUNT on AC_MASTER, AC_DAILY_TRN, AC_OPENING_BALANCE, AC_YEARLY_TRN, AC_YEARLY_TRN_OLD) | delete hook |

## Tests (section E of `tmp\w3_gl\gl\t_gl.py`, 9 checks)

Number required / range, rate range, local currency keeps rate 1, duplicate rate-period date refused (serials 1, 2), delete of
currency 1 and of a currency used by an account refused, unused currency deleted. Passed.


## Wave 3b

Checked, nothing to change: GN_FORM_ITEM has no check box, list item, radio group or display item for this screen; the blocks allow insert / update / delete; no button that only opened another form.

## Coverage

- Reproduced: rules 1-5.
- Not reproduced: TO_DATE of the rate periods (prompt "إلي تاريخ" exists in the .fmx but not as a GN_FORM_ITEM item; how it was
  filled is not visible - left out of the grid); the default Arabic name 'ريال سعودي' near the currency-1 trigger (not certain); print.
