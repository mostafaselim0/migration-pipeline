# AC_MASTER_STRUCT - هيكل دليل الحسابات / Structure of Accounts

- Registry: system 1 serial 76 (CODES_MENU.GL_STRUCT, order 2002). APEX grid page 10090.
- Legacy module: `ASCON\AC\FMB\ac_master_Struct.fmx` (no .fmb, no GN_FORM_ITEM labels).
- **Deliverable: screen correction + rules (Stage C wave 3).** Override `app\legacy\overrides\AC_MASTER_STRUCT.json`
  (pattern `GRID` on `AC_CHART_STRUCTURES`), PL/SQL `APP_RULES3_GL` in `app\db\25_rules3_gl.sql`.
- **Confidence: high** for the table and the lock / range rules (Arabic messages and SQL of the .fmx); medium for the
  length derivation (the END validation reads `:Length`, `:Chr_Stru_End`, `:Chr_Stru_Start`).

## Screen correction

The generator chose `AC_MASTER` because of the name ("fmx references 2 tables; used AC_MASTER (name match)"). The form edits
the levels of the 12-digit account number: `AC_CHART_STRUCTURES` (`CHR_STRU_LEVEL`, `CHR_STRU_DESCA/E`, `CHR_STRU_START`,
`CHR_STRU_END`, `LENGTH`; 6 rows: 1 / 1 / 2 / 2 / 3 / 3 digits). All its SQL reads that table, and its only other table reference is
`SELECT COUNT(ACCOUNT_NUMBER) FROM AC_MASTER` (the lock). Column prompts from the .fmx: المسلسل، مسمى الدرجه، حقل البداية،
حقل النهاية، الطول (set with `add_columns`).

## Rules

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | Structure is locked while the chart has accounts: no new level, no delete, only the level name may change ("لا يمكن تعديل بيانات هيكل دليل الحسابات أثناء وجود بيانات في الدليل ولكن يمكن تعديل اسم المستوي فقط" / "نظرا لوجود عدد من السجلات بدليل الحسابات لا يمكن تغيير أو إضافة أو حذف ...") | CHECK_VALIDITY_TO_ENTER: `SELECT COUNT(ACCOUNT_NUMBER) FROM AC_MASTER` + both texts | row rule `chart_struct_row` (insert / change of level, start, end, length refused); delete hook `APP_RULES3_GL_CHRSTR_DEL` |
| 2 | New level: level = MAX(level) + 1, start = MAX(end) + 1 | WHEN-NEW-RECORD-INSTANCE: `SELECT NVL(MAX(CHR_STRU_END),0)`, `SELECT MAX(CHR_STRU_LEVEL)` | key_expr `next_chart_level`; row rule fills the start; both optional in the grid |
| 3 | Level name required ("برجاء إدخال اسم المستوي"), start required ("برجاء إدخال رقم البداية") | item validations | row rule |
| 4 | End position entered, not before the start and within 12 ("برجاء التأكد من إدخال -- حقل النهاية -- و كونه اكبر من حقل البداية و كذلك كونه أقل من 12") | CHR_STRU_END validation | row rule (end >= start: levels 1 and 2 have start = end; end <= 12: level 6 ends at 12) |
| 5 | Length = end - start + 1 ("برجاء إدخال طول المستوي") | END validation sets `:Length` | row rule; LENGTH read-only |
| 6 | Delete from the bottom up, one saved delete at a time ("يجب حذف السجلات من إسفل إلي أعلي ... كما يجب تسجيل حذف سجل قبل البدء في حذف سجل أخر") | PRE-DELETE: `SELECT MAX(CHR_STRU_LEVEL)` | after-statement check in `APP_RULES3_GL_CHRSTR_DEL` (levels must stay 1..n) |

## Tests (build copy, rolled back; `tmp\w3_gl\gl\t_gl.py` section A)

Locked structure (insert / end change / delete refused, rename allowed); with the test switch `set_test(true)` (the build copy has
328 accounts): bottom-up delete, new level 6 gets start 10 and length 3, end 13 / end before start / missing name refused.
All passed (part of 179/179).


## Wave 3b

Checked: no check box / list / radio item. The displays إجمالى عدد الحقول التى تم تخصيصها / الحقول المتبقية are totals over all levels, not values of a row, so `rules.computed` (per row) does not fit them; still not reproduced.

## Coverage

- Reproduced: rules 1-6.
- Not reproduced: the displays "إجمالى عدد الحقول التى تم تخصيصها / الحقول المتبقية" (running totals of the grid: no computed
  column in grids) and the exit warnings "هيكل غير كامل. / برجاء استكمال هيكل دليل الحسابات حتي الخانة الثانية عشر" (a check of the whole
  structure on exit; grids save row by row, so it cannot be enforced while levels are being entered). The company check
  "برجاء التأكد من تسجيل الشركة" is not needed (every APEX session has a company). Print button (report ACCHART) is in the reports menu.
