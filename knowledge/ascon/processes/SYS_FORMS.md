# SYS_FORMS - شاشات و تقارير الأنظمة / Module Screens and Forms

- Registry: system 99 serial 61 (SYSTEM_MENU.SYS_FORMS, order 6001). APEX list page 80210, document page 80211.
- Legacy module: `ASCON\SE\FMB\SYS_forms.fmx`. Master SYS_SYSTEMS, tabs SYS_FILES (الشاشات) and SYS_REPORTS (التقارير), plus an approval-chain
  tree per screen (SE_AUTH: levels PREV_SER, role / user of each level).
- **Deliverable: (a) screen correction + rule** - `app\legacy\overrides\SYS_FORMS.json` (MASTER_DETAIL SYS_SYSTEMS -> SYS_FILES, SYS_REPORTS;
  the generator had produced a grid of SYS_FILES), delete rule in `APP_RULES3_SE`.
- **Confidence: high** for the registry part; the approval chain is not reconstructed (see below).

## Rules

| # | Legacy rule | Evidence | APEX |
|---|---|---|---|
| 1 | Screens and reports of a system (name A / E, name in the menu, form / report file name, type "تصنيف / شاشة", level, parent) | labels SYS_FILES.* / SYS_REPORTS.*, texts | details; MENU_NAME, FILE_NAME_E / REPORT_FILE_NAME_E, PARENT added (`add_columns`) |
| 2 | A system with screens or reports cannot be deleted | `SELECT 1 FROM SYS_FILES S WHERE S.SYSTEM_NUMBER`, `SELECT 1 FROM SYS_REPORTS S ...` | `sys_systems_delete`: on this page the master delete is refused (the generated cascade removes the lines first) |
| 3 | Invisible screens / reports are not listed | block WHERE `(SYSTEM_NUMBER, FILE_SERIAL) NOT IN (SELECT ... FROM SYS_NVSBL_FILES)` (reports alike) | wave 3b: `rules.blocks` `where` on both grids (the legacy NOT IN clauses; the tables are empty today; the generic print page ignores it) |
| 4 | Screen serial typed | FILE_SERIAL item | typed; empty -> generated max+1 per system |

Registry changes reach the APEX menu and page rights only at the next build (the generator reads SYS_FILES / SYS_REPORTS).

## Not reconstructed: approval chains (SE_AUTH)

The tree window "توقيع" defines, per screen, approval levels: `PREV_SER` numbering (`NVL(MAX(PREV_SER),0)+1` for level 1, parent || next digit
below), the approver (user, "مدير" user manager, "مدير مشروع", "مدير قسم", "المستخدم المنشئ" or a role of SE_ROLES), "يجب حذف اخر مستوى اولا"
(only the last level can be removed), `DELETE FROM SE_AUTH WHERE SYSTEM_NUMBER AND FILE_SERIAL`. SE_AUTH, SE_USERS_AUTH and SE_ROLES are empty and
the approval workflow (SE_USERS_AUTH, used by payroll vacation orders PY_ORDER_VCNC_H) is not part of the APEX application ("approval workflows"
are listed as not built in the README). Question: are approval chains used by this customer at all?

## Tests (t_se.py, rolled back)

W6 master delete refused on this page.


## Wave 3b

FILE_STATUS "نوع الشاشة" and REPORT_STATUS "نوع التقرير" are legacy list items ([LS]); the .fmx texts after each prompt are تصنيف and شاشة. Static lists 0 تصنيف (menu folder) / 1 شاشة (screen or report): the generator and the menu use status 1 as the usable entries, and the 1 file / 38 reports with status 0 are the menu folders. Medium confidence on the value order (question in the report).
Rule 3: the two grids now carry the legacy block filters `(SYSTEM_NUMBER, FILE_SERIAL) NOT IN (SELECT ... FROM SYS_NVSBL_FILES)` and the
report equivalent (`rules.blocks.<TABLE>.where`); SQL run (280 screens / 302 reports listed, the invisible tables are empty).

## Coverage

- Reproduced: rules 1-4 (wave 3b: rule 3 as the grid filters, type lists).
- Not reproduced: the SE_AUTH approval-chain tree (above), the GN_FORM_ITEM copy
  statements of the module (`SELECT * FROM GN_FORM_ITEM WHERE SYSTEM_NUMBER AND FORM_CODE`, purpose not identifiable), print / translation buttons.
