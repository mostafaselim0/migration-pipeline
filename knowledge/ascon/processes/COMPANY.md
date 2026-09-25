# COMPANY - الشركات - بيانات الشركات / Companies Main Information

- Registry: system 99 serial 3 (COMPANY_MENU.COMPANY_INFO, order 1001). APEX list page 80010, document page 80011, print 80012.
- Legacy module: `ASCON\SE\FMB\COMPANY.fmx` (no .fmb). Master COMPANY (+ logo image), tabs COMPANY_COMM (أرقام وسائل الإتصال) and
  COMPANY_LICENCE (أرقام التصاريح).
- **Deliverable: (b) rules + button on the generated screen** - `app\legacy\overrides\COMPANY.json` (AUTO), package `APP_RULES3_SE`.
- **Confidence: high.**

## Rules and buttons

| # | Legacy rule / button | Evidence | APEX |
|---|---|---|---|
| 1 | "رقم الشركة موجود من قبل" | `SELECT COUNT(1) FROM COMPANY WHERE COMPANY_CODE = :b1` + message (twice) | row rule `company_row` (inserting); the generator's default "session company" for the code removed (`defaults`) |
| 2 | A new company gets its system parameter rows: `INSERT INTO AC_BASIC (COMPANY_CODE, CURRENT_YEAR, CURRENCY_STTS, ESTIMATE_TEST, COST_CODE1_BAL, COST_CODE2_BAL, DEL_BAL_SIDES, DOC_REPEAT, FX_USR_ENTRY, FX_USR_COST1, FX_USR_COST2) VALUES (:b1, 2001, 0, 0, 0, 0, 0, 3, 2, 2, 2)` and `INSERT INTO PY_BASIC_H (...) VALUES (:b1, 0, ..., 1)`, per installed system (`SELECT SYSTEM_NUMBER FROM SYS_SYSTEMS`) | POST-INSERT SQL; system numbers of CHECK_DATE (1 -> AC_BASIC, 60 / 61 -> PY_BASIC_H) | after-save (CREATE) `company_created`, legacy literal values (the GL parameters are then set in ACBASIC) |
| 3 | Deleting a company deletes its AC_BASIC row (system 1 installed) | PRE-DELETE `SELECT SYSTEM_NUMBER FROM SYS_SYSTEMS` + `DELETE FROM AC_BASIC WHERE COMPANY_CODE` | delete hook `APP_RULES3_SE_COMPANY_BD` -> `company_delete`; companies are deleted only on this screen |
| 4 | Licence: "تاريخ الانتهاء اقل من تاريخ الاصدار", "تاريخ التجديد اقل من تاريخ الانتهاء" | messages | row rule `licence_dates` |
| 5 | Communication / licence line serial = MAX + 1 per company and code | `SELECT NVL(MAX(NVL(SERIAL,0)),0)+1 FROM COMPANY_COMM / COMPANY_LICENCE WHERE COMPANY_CODE AND COMM_CODE / LICENCE_CODE` | generated key (same rule) |
| 6 | Company logo read from a file (image item, browse button) | COMPANY_LOGO, CLIENT_IMAGE, V_IMAGE_PATH, IMAGE_BUTTON, WEBUTIL | action LOGO with a file parameter -> `load_logo` (the print pages use COMPANY.COMPANY_LOGO) |
| 7 | A company with communication ways / licences: relation check | `SELECT 1 FROM COMPANY_COMM / COMPANY_LICENCE WHERE COMPANY_CODE` | the generated document delete removes the lines first (as in the other documents) |

**Licence trigger:** the legacy DB trigger `COMPANY_TRIG` (`BEFORE INSERT OR UPDATE OF SSA, MSA ON COMPANY`) raises "Contact your system administrator
for more info." on every INSERT (and on updates of SSA / MSA). A new company can therefore not be created in this database - in Forms nor in
APEX - until the vendor enables it; test C1b documents it. (Screens that update COMPANY must not send SSA / MSA: the TX_BASIC grid shows them.)

## Tests (t_se.py, rolled back)

C1 duplicate code; C1b insert refused by COMPANY_TRIG; C2 parameter row recreated with the legacy values; C3 / C4 licence dates; C5 logo without a
file; C9 company delete refused on ACCOMPANY_ACCOUNT; C10 company delete removes AC_BASIC.


## Wave 3b

Checked, nothing to change: the licence and communication grids have the lists of the legacy record groups (LICENCE / COMM_WAY), which show the names (COMM_DESC / LICENCE_DESC display items); no check box / list item / radio group; the logo button is an action.

## Coverage

- Reproduced: rules 1-7 (rule 2 cannot run while COMPANY_TRIG refuses new companies).
- Not reproduced: the "خطأ صلاحية" template check (the APEX page rights replace it), print / translation buttons; the logo upload was not run
  end-to-end (APEX temporary files need a browser upload; the error path is tested).
