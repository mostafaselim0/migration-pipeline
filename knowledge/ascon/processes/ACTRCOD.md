# ACTRCOD - أرقام أنواع اليوميات / Entries Type Number

- Registry: system 1 serial 23 (CODES_MENU.ACTRCOD, order 2008). APEX grid page 10150.
- Legacy module: `ASCON\AC\FMB\ACTRCOD.fmx` (no .fmb; GN_FORM_ITEM labels of AC_TRN_CODES and the YEAR_CHOICE window).
- **Deliverable: generated grid kept (`AUTO`) + rules + button.** Override `app\legacy\overrides\ACTRCOD.json`, PL/SQL `APP_RULES3_GL`,
  delete hook `APP_RULES3_GL_TRNCOD_BD`.
- **Confidence: high** (SQL of the year copy and of the PRE-DELETE, messages).

## Rules and buttons

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | List: journal types granted to the group (AC_PASSWORD_ENTRY), group 0 all | block WHERE | `where` |
| 2 | "إنشاء سنة مالية جديدة" (من سنة / إلى سنة / تنفيذ): the to-year must not pass the year of AC_BASIC.MAX_DATE ("السنة المالية أكبر من المسموح بة فى مؤشرات النظام!!"), the from-year must exist ("السنة المالية غير موجودة من فضلك أدخل سنة أخرى"), the years must differ ("لا بد من إدخال قيمة مختلفة عن قيمة السنة المراد نسخها في السنة الجديدة"); every type of the from-year missing in the to-year is inserted (`INSERT INTO AC_TRN_CODES (..., LAST_SERIAL 0, AC_FLAG, SERIAL_FLAG)`), with its company grant (`INSERT INTO AC_COMPANY_ENTRY`) and the group grants of the company (`INSERT INTO AC_PASSWORD_ENTRY` from the from-year) | YEAR_CHOICE trigger SQL and texts | grid action NEW_YEAR (years; message "تم إنشاء السنة المالية ..." - new text); shown to users with insert right on the page |
| 3 | A type used by opening, daily or posted entries is not deleted; a type still in the company privileges is not deleted ("رقم الحركة موجود فى صلاحيات الشركات") | PRE-DELETE (PRIMARY_CUR over AC_OPENING_BALANCE / AC_DAILY_TRN / AC_YEARLY_TRN, COUNT on AC_COMPANY_ENTRY) | delete hook ("لا يمكن حذف نوع الحركة لوجود قيود عليه" - new text for the numbered legacy message) |

## Tests (section D of `tmp\w3_gl\gl\t_gl.py`, 10 checks)

2026 -> 2027: 7 types copied with AC_FLAG / SERIAL_FLAG, LAST_SERIAL 0, 7 company grants, message; a second run copies nothing;
2031 (beyond MAX_DATE 31/12/2030), unknown year 2019 and the same year refused; delete of 2026/101 (entries) and 2027/1301 (company
grant) refused; an unused type deleted. Passed.

## Wave 3b

- SERIAL_FLAG "مؤشر المسلسل" is a legacy list item ([LS]): static list سنوي 0 / شهري 1 (CALC_SERIAL numbers month-based when
  SERIAL_FLAG = 1; data 0 / 1).
- AC_FLAG "حركات أنظمة أخري" is a legacy check box ([C]): `widget: CHECK` 1 / 0 (data 0 / 1 / empty; ACDLYTR / ACUPDT test
  `NVL(AC_FLAG,0) = 0` for GL journals).

## Coverage

- Reproduced: rules 1-3; SERIAL_FLAG list and AC_FLAG check box (wave 3b).
- Not reproduced: print "حالة مسلسل القيود" (fills ENTRY_NO_TMP for a report: use the reports menu); Forms mechanics
  (ENTRY_TYPE WHEN-VALIDATE-ITEM error text is the generic trigger-failure message).
