# SYS_SYSTEMS - الأنظمة / Modules

- Registry: system 99 serial 60 (SYSTEM_MENU.SYS_SYSTEMS, order 5001). APEX grid page 80200.
- Legacy module: `ASCON\SE\FMB\SYS_systems.fmx` (grid SYS_SYSTEMS: رقم النظام، الأسم عربى / انجليزى، اسم القائمة). The evidence pack quotes
  `ASCON\SYS_SYSTEMS.fmx`, a different module (a read-only tree of systems / screens / reports).
- **Deliverable: code table, no override; one delete rule in the package** (from the SYS_FORMS relation check).
- **Confidence: high.**

## Rules

| # | Legacy rule | Evidence | APEX |
|---|---|---|---|
| 1 | Maintain SYSTEM_NUMBER, names and menu name | labels, SE module strings (no SQL besides the toolbar) | generated grid |
| 2 | A system with screens or reports cannot be deleted | SYS_FORMS: `SELECT 1 FROM SYS_FILES S WHERE S.SYSTEM_NUMBER = :b1`, `SELECT 1 FROM SYS_REPORTS ...` (relation check "Cannot delete master record ...") | delete hook `APP_RULES3_SE_SYSSYS_BD` -> `sys_systems_delete` |

SYS_SYSTEMS, SYS_FILES and SYS_REPORTS are the registry the generator reads: changes here reach the APEX menu (APP_MENU) and the page map
only at the next build (`specs.py` / `build.py`).

## Tests (t_se.py, rolled back)

W4 system 88 (with screens) cannot be deleted; W5 an empty system can.


## Wave 3b

Checked, nothing to change (no override needed): the systems registry grid; no check box / list item / display item.

## Coverage

Reproduced: rules 1-2. Not reproduced: the tree view of the other SYS_SYSTEMS module (the APEX side menu shows the same hierarchy), print /
translation buttons.
