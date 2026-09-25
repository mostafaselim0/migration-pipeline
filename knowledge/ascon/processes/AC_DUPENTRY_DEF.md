# AC_DUPENTRY_DEF - قائمة القيود الدورية / Periodical Entry Numbers

- Registry: system 1 serial 25 (القيود_الدورية_MENU.AC_DUPENTRY_DEF, order 1101). APEX grid page 10030.
- Legacy module: `ASCON\AC\FMB\Ac_dupentry_def.fmx` (no .fmb): the list of posted entries that the process AC_DUPENTRY
  (APP_PROC_GL.create_periodical_entry) copies into new daily entries.
- **Deliverable: generated grid kept (`AUTO`) + rules**, override `app\legacy\overrides\AC_DUPENTRY_DEF.json`, PL/SQL `APP_RULES3_GL`.
- **Confidence: high.**

## Rules

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | List: entries of the session company (posted or daily) | block WHERE `(ENTRY_YEAR,ENTRY_TYPE,ENTRY_NO) IN (SELECT ... FROM AC_YEARLY_TRN WHERE CREATE_COMPANY_CODE = :1) OR ... AC_DAILY_TRN ...` | `where` |
| 2 | SERIAL = NVL(MAX(NVL(SERIAL,1)),1) + 1 (the first serial is 2; data 3 .. 23) | PRE-INSERT SQL | key_expr `next_periodical_serial` (replaces the generic max+1) |
| 3 | The entry is chosen from the posted entries of the company, of a journal granted to the group | ENTRY_NO LOV (AC_YEARLY_TRN, company), ENTRY_TYPE LOV (AC_PASSWORD_ENTRY) | row rule `periodical_row` on insert or when the entry changes (new texts "رقم القيد غير موجود فى القيود المرحلة", "لا توجد صلاحية على نوع الحركة") |
| 4 | An entry is listed once ("هذا القيد موجود فى القيود الدوريه بالفعل") | PRE-INSERT `COUNT(1) ... WHERE ENTRY_YEAR, ENTRY_TYPE, ENTRY_NO` | row rule (insert) |
| 5 | Description taken from the entry | ENTRY_NO LOV returns ENTRY_DESC | row rule fills empty ENTRY_DESC / _E |

## Tests (section J of `tmp\w3_gl\gl\t_gl.py`, 5 checks)

New row serial 24 with the entry's description; duplicate, non-posted entry and journal not granted to group 101 refused; editing a
description does not re-check the entry. Passed.

## Wave 3b

Journal-type name display item TYPE_ENTRY_DESC / _E (POST-QUERY from AC_TRN_CODES by year and type): computed grid column "اسم نوع
الحركة" (`rules.computed`, English name when the language is English). SQL run on the build copy ("يومية عامة").

## Coverage

- Reproduced: rules 1-5; the journal-type name (wave 3b). The copy itself is the AC_DUPENTRY process page (wave 1).
