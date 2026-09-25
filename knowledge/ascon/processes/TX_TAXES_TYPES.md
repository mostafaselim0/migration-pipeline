# TX_TAXES_TYPES - أنواع الضرائب / Tax types

- Registry: system 88 (Taxes) serial 1, order 2001. APEX list page 70020, form page 70021 (report + modal form).
- Legacy module: `ASCON\TX\FMB\TX_Taxes_Types.fmx` (no `.fmb`, no GN_FORM_ITEM labels; evidence = embedded SQL and Arabic texts).
- **Deliverable: (a) generated screen kept (`"pattern": "AUTO"`) + validation + one action button**; PL/SQL in `APP_RULES3_TX`
  (`app\db\25_rules3_tx.sql`), override `app\legacy\overrides\TX_TAXES_TYPES.json`.
- **Confidence: high** for the checks, **medium** for the copy button (which percentage the copied rows get, see question 1).

## Rules and buttons

| # | Rule / button | Legacy evidence | APEX |
|---|---|---|---|
| 1 | `TAX_CODE` = max + 1 | `SELECT NVL(MAX(TAX_CODE),0)+1 FROM TX_TAXES_TYPES` | generated APPX key (same rule, when left empty) |
| 2 | Duplicate tax number refused "رقم مكرر تم إدخالة من قبل" | `SELECT TAX_CODE FROM TX_TAXES_TYPES WHERE TAX_CODE = :b1`, message | validation `types_check` (CREATE) |
| 3 | Name required "يجب إدخال الإسم" | message | validation `types_check` |
| 4 | Account items (debit / credit / customs / tax expense / assets tax / advance payment account) from the account LOV: posting accounts (`ACCOUNT_STATUS = 1`) allowed for the user's group (`AC_PASSWORD_MASTER` with the company, group 0 = all) | LOV query of the form | validation `types_check` (the generator has no LOV for these columns) |
| 5 | **نسخ بيانات نوع ضريبة سابقة**: choose a previous tax type ("كود الضريبة", "اختر رقم ضريبة مناسب"); needs the saved record ("يجب الحفظ أولا") and the tax percentage (`INIT_TAX_PRCN`, "أدخل نسبة الضريبة أولا"); copies the obligations of the chosen tax to this one: items, suppliers (with tax no. and external flag), customers (with tax no.), accounts (with cost centres, `ACC_SERIAL` = max + 1 within the new tax), areas, asset categories, services, activities with a percentage > 0 get the new percentage; items with 0 % are copied with 0; exempt customers (`TX_TAXES_ES_CUSTOMER`) copied as they are; transport percentage (`TX_TAXES_FIXED_SRV`) when > 0; "تم نسخ بيانات الضريبة" | embedded SQL (cursors per `TX_TAXES_*` table with `NVL(TAX_PER,0) > 0` / `= 0`, the inserts) and messages | action **COPY** on the form page -> `app_rules3_tx.copy_tax` (in the page transaction; a row that already exists for the target tax refuses the whole copy with "رقم مكرر تم إدخالة من قبل") |
| 6 | Delete: the template's message "لا يجوز حذف السجل لإرتباطة بجداول اخري" is the ON-ERROR text for a foreign-key error; there is no foreign key on the `TX_TAXES_*` tables, so the legacy deleted the tax type | ON-ERROR template text | generated delete (same behaviour) |

The other Arabic texts of the module ("كود الوحدة مكرر", "تم تخصيص هذه الوحدة مع صنف أو أكثر" ...) belong to the unit-code template the
form was copied from and are not used.

## Tests (build copy, simulated APEX session, rolled back)

Name required, duplicate number, non-posting account refused, posting accounts accepted; new tax type gets code 3; copy refused without
percentage / from itself / from an unknown tax; copy from tax 2 with 5 %: 13,139 items (7,684 at 5 %, 5,455 at 0 %), 5 suppliers, 94
customers, 90 accounts (serials 1..90), 1 service; second copy refused as duplicate. Script `tmp\w3_gl\tx\t_tx.py`.

## Wave 3b

The six account items (DB_ACCOUNT_NO, CR_ACCOUNT_NO, CUSTOM_ACCOUNT_NO, EXP_ACCOUNT_NO, TRNSIT_ACCOUNT_NO, ADV_ACCOUNT_NO) get the legacy
account list (record group of `evidence\TX_TAXES_TYPES.md`: `ACCOUNT_STATUS = 1` accounts allowed for the group by AC_PASSWORD_MASTER)
as pop-up lists "number - name", which also show the account names the legacy displayed. SQL run on the build copy.

## Coverage

- Reproduced: rules 1-6; account lists with names (wave 3b).
- Not reproduced: prompts, navigation, the template's unused unit-code alerts.

## Open questions

1. Copy: the copied rows get the new tax's percentage (`INIT_TAX_PRCN`) - inferred from the separate `> 0` / `= 0` cursors and the
   message "أدخل نسبة الضريبة أولا". Confirm, or should they keep the source percentage?
