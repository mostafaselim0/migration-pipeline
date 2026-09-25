# TX_ACCOUNTS - التطبيق على الحسابات العامة / Accounts obligation

- Registry: system 88 (Taxes) serial 8, order 2002. APEX grid page 70030.
- Legacy module: `ASCON\TX\FMB\TX_ACCOUNTS.fmx` (no `.fmb`, no labels). Legacy layout: master "انواع الضرائب" (tax types) and detail
  "أرقام الحسابات" (`TX_TAXES_ACCOUNTS`), plus a range panel (من حساب / إلى حساب / مركز تكلفة 1 / مركز تكلفة 2 / النسبة / تطبيق).
- **Deliverable: (a) generated grid kept (`"pattern": "AUTO"`) + rules + range action**; `APP_RULES3_TX`, override `TX_ACCOUNTS.json`.
  The grid shows the tax number as a column (tax types are maintained in TX_TAXES_TYPES), as for the other obligation screens.
- **Confidence: high.**

## Rules and buttons

| # | Rule / button | Legacy evidence | APEX |
|---|---|---|---|
| 1 | Account from the list of posting accounts (`ACCOUNT_STATUS = 1`); cost centres 1 / 2 from the active ones (`COST_STATUS = 1`) | LOV queries of the form | row rule `accounts_row` (legacy text "خطأ :رقم الحساب ليس حساب فرعى" of the GL screens for the account) |
| 2 | `ACC_SERIAL` = max + 1 over the **whole table** (not per tax / account) | `SELECT NVL(MAX(ACC_SERIAL),0)+1 FROM TX_TAXES_ACCOUNTS` | `key_expr` `app_rules3_tx.next_acc_serial` (replaces the generated max+1 within tax / account); column hidden |
| 3 | **تطبيق**: every posting account between the two accounts, with the chosen cost centres, gets the percentage: the existing row (same tax, account, cost centre 1 and 2) is updated, otherwise a row is added; percentage > 0 ("النسبة يجب أن تكون أكبر من الصفر") | `SELECT ... FROM AC_MASTER WHERE ACCOUNT_NUMBER BETWEEN :b1 AND :b2 AND ACCOUNT_STATUS = 1`, `SELECT COUNT(1) ... UPDATE TX_TAXES_ACCOUNTS SET TAX_PER ...`, message | grid action **APPLY** -> `app_rules3_tx.apply_accounts` (tax number as a parameter, default the first tax type) |
| 4 | Master-detail delete check `SELECT 1 FROM TX_TAXES_ACCOUNTS WHERE TAX_CODE = :b1` (tax type with accounts) | embedded SQL | not applicable: tax types are not deleted on this page |

The percentage check exists only once in this module (range panel); the rows themselves are not checked (unlike the other obligation
screens). Account / cost-centre names are shown by the lists of values.

## Tests

Non-posting account, inactive cost centre 1 / 2 refused; new row gets `ACC_SERIAL` = table max + 1; apply with 0 % refused; apply over
accounts 31xxxxxxxxxx at 14 %: 21 posting accounts, 17 existing rows updated and the others inserted. `tmp\w3_gl\tx\t_tx.py`.


## Wave 3b

Checked, nothing to change: the account and cost-centre columns already have the lists of the legacy record groups (active accounts, active cost centres 1 / 2), which show the names; no check box / list item / radio group; the APPLY button is an action; no button that only opened another form.

## Coverage

Reproduced: 1-3. Not reproduced: the master block of tax types on this page (rule 4, by design), name display items (LOV display).
The action button requires the insert right on the page (safeguard; the legacy button had no own check).
