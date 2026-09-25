# ACUSERS_SYSTEMS - صلاحية المستخدمين---الأنظمة / Users Privilege -- Systems

- Registry: system 99 serial 20 (PRIVILIAGE_MENU, order 3009). APEX list page 80150, document page 80151.
- Legacy module: `ASCON\SE\FMB\AcUsers_Systems.fmx` (no .fmb). Blocks USERS (code, names - display) and SYS_SYSTEMS_USERS (system, note).
- **Deliverable: (a) screen correction + rule + button** - `app\legacy\overrides\ACUSERS_SYSTEMS.json`: MASTER_DETAIL USERS -> SYS_SYSTEMS_USERS
  (the generator had produced an editable grid of USERS including the password column), package `APP_RULES3_SE`.
- **Confidence: high.**

## Rules and buttons

| # | Legacy rule / button | Evidence | APEX |
|---|---|---|---|
| 1 | Systems of a user; system list = SYS_SYSTEMS not yet assigned (`SYSTEM_NUMBER = :GLOBAL.SYSTEM_NUMBER OR :GLOBAL.PASSWORD_NUMBER = 0`) | AC_SYSTEM_NUMBER_RG | row rule `sys_systems_users_row`: the system must exist; duplicates refused by the PK |
| 2 | "جميع الأنظمة": the user's systems are replaced by all systems | ALL_COMP_BUT: `DELETE FROM SYS_SYSTEMS_USERS WHERE USERS_CODE`, SYS_SYSTEM_CUR | action ALL_SYSTEMS -> `all_systems` |
| 3 | Master shows only code and names | labels USERS.USERS_CODE / NAME / NAME_E | `columns` of the master; PASSWORD hidden and optional; users are deleted only in the users screen |

SYS_SYSTEMS_USERS is not read by the APEX application (menus and page rights come from FILE_PASSWORD / REPORT_PASSWORD); it is kept for the
legacy Forms menu and for "copy rights" of the users screen.

## Tests (t_se.py, rolled back)

Y1 all systems (9 rows); Y2 unknown system 77 refused.


## Wave 3b

SYS_SYSTEMS_USERS.SYSTEM_NUMBER (SYSTEM_DESC display item): list of SYS_SYSTEMS "number - name" (legacy record group `SELECT SYSTEM_NUMBER, SYSTEM_DESC FROM SYS_SYSTEMS ...`; the "not yet granted" part is left out so saved rows keep their names).

## Coverage

- Reproduced: rules 1-3.
- Not reproduced: the `:GLOBAL.SYSTEM_NUMBER` restriction of the list for groups other than 0 (a login global of the Forms menu, meaningless in
  APEX), print (USER_SYSTEM report) and translation buttons.
