# Addendum: business rules for data-entry screens (Stage C, wave 2)

Data-entry screens are generated automatically (tables, columns, labels, lists of values, master-detail, grids). What the
generator cannot know are the legacy form's rules: document numbering, validations, derived values, cross-checks at save time.
The legacy numbering, for example, is often not max+1 (e.g. GL vouchers use CALC_SERIAL / AC_TRN_CODES.LAST_SERIAL).

Deliver rules for a form as `app\legacy\overrides\<FORM>.json` with `"pattern": "AUTO"` (keep the generated screen) — or keep
the pattern of an existing override — plus a `"rules"` block. PL/SQL goes into a package `APP_RULES_<MODULE>` in
`app\db\21_rules_<module>.sql` (module = gl, st, ar, vn, pr, sa), compiled into SMART without errors.

```json
{"pattern": "AUTO", "notes": "one line",
 "rules": {
   "key_expr":   {"TABLE.COLUMN": "PL/SQL expression using :new.<col>, e.g. app_rules_gl.next_entry_no(:new.entry_year, :new.entry_type, :new.entry_date)"},
   "row_rules":  {"TABLE": "PL/SQL statements run in the generated BEFORE INSERT OR UPDATE row trigger (APEX sessions only); may use inserting / updating / :new / :old; raise_application_error(-20100..-20199, '<Arabic message>') to reject"},
   "validations": [{"name": "...", "plsql": "function body returning error text or null; page items as :PAGE_<COLUMN> (header/master items of the document page)", "when": "CREATE,SAVE"}],
   "after_save":  [{"name": "...", "plsql": "PL/SQL block run after the header and all detail lines are saved (same transaction; raising an error rolls the whole save back). Page items as :PAGE_<COLUMN>", "when": "CREATE,SAVE"}],
   "defaults":   {"TABLE.COLUMN": {"type": "STATIC|ITEM|EXPRESSION|SQL_QUERY", "value": "..."}},
   "readonly":   ["TABLE.COLUMN"], "hidden": ["TABLE.COLUMN"], "optional": ["TABLE.COLUMN"],
   "where":      "filter on the master table for the list page and grids, e.g. TRNS_TYPE_CODE in (select trns_type_code from st_trns_type where ...) — REQUIRED when several screens share one table (ST_TRNS_MAST, AR_MAINTRNS, VN_MAINTRNS ...); no :bind variables except :G_* application items"
 }}
```
Screens sharing a table: set `where` so each screen shows only its own document types, and a `defaults` entry
(and usually a validation) for the type column so new documents get a valid type for that screen.

Conventions and facts:
- The document page (master-detail) has a header form and detail grids; the page item for header column X is `:PAGE_X`
  (the generator rewrites it to the real page item). The header ROWID is `:PAGE_ROWID`.
- Application items: `:G_USER_CODE`, `:G_COMPANY_CODE`, `:G_PASSWORD_NUMBER`, `:G_LANG` (in PL/SQL also `v('G_...')`).
- Generated triggers `APPX_<TABLE>` already fill CREATE_*/UPDATE_* audit columns and, when no key_expr is given, a max+1 key on
  the last numeric PK column (not for FK / YEAR / FLAG / TYPE-like columns). `key_expr` replaces that for the named column.
- Existing legacy DB triggers stay active (e.g. stock cost/balance triggers on ST_TRNS_DET). Do not duplicate them.
- Detail lines of GL vouchers use DEBIT_VALUE / CREDIT_VALUE columns in the grid, stored as signed VALUE.
- Drop Forms-only mechanics (dongle/protection checks such as CUSTOMER_ACCOUNT_BALANCE-based checks, WEBUTIL, alerts navigation,
  SET_IP). Keep business behaviour: numbering, mandatory checks, cross-field checks, closed-period checks, balance checks,
  derived values the user does not type (totals, names are handled by LOVs).
- Test every rule on the build copy and ROLLBACK. You may preview the generated page code without building by importing
  `C:\Smart Transformation\app\gen\specs.py` / `apexgen.py` in Python in memory; do not run build.py.
- Write `app\legacy\processes\<FORM>.md` with the rules, evidence and confidence, as in the main contract.
