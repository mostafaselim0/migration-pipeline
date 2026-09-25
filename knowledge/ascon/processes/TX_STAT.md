# TX_STAT - اصدار الاقرار الضريبي / Issue Taxes Statement (VAT return)

- Registry: system 88 (Taxes) serial 11, order 1001. APEX list page 70010, document page 70011, print 70012.
- Legacy module: `ASCON\TX\FMB\TX_STAT.fmb` (source available: `TX\FMB\TX_STAT_fmb.xml`; the Arabic prompts, lost in the XML, were
  recovered from the `.fmb` binary).
- **Deliverable: (a) generated screen kept (`"pattern": "AUTO"`) + rules, info values and one action button** (Stage C wave 3).
  - Override: `app\legacy\overrides\TX_STAT.json` (key_expr, row_rules, validation, defaults, readonly, add_columns, info, actions).
  - PL/SQL: package `APP_RULES3_TX` in `app\db\25_rules3_tx.sql` (+ compound delete trigger `APP_RULES3_TX_MAST_BD`).
- **Confidence: high** for the statement build (the button's SQL is in the `.fmb`; re-running it reproduced the four legacy statements,
  see Tests), numbering, period derivation, delete rule and totals; **medium** for the English labels of the boxes.

## What the screen is

The quarterly VAT return. Header `TX_TRNS_MAST` (company, tax type, serial, statement date, period from / to, corrections, carried tax,
approval flag). The button **تكوين** fills `TX_TRNS_DET` with one line per source document of the period (GL entries on the tax
accounts, customer and supplier transactions, sales / purchase invoices and returns); the user reviews each line's **tax indicator**
(`T_TAX_FLAG`, the box of the return) and the form adds everything up into the boxes of the Saudi VAT return.
Tabs of the legacy form: الاقرار (totals), المبيعات (`SLS`), المشتريات (`PUR`), العملاء (`CUST`), الموردين (`SUPP`),
الحسابات (`ENTRY`), اجمالي حسابات (the GL movements of the two tax accounts, read-only). Each tab had one block for invoices
(`TAX_SIGN = 1`) and one for returns (`TAX_SIGN = -1`).

Approval (`AUTH_FLAG = 1`, معتمد) has its effect in the database: the existing triggers `AC_YRLY_TRN_TAX`, `AC_YRLY_TRN_DET_TAX`,
`AR_MAINTRNS_TAX`, `AR_SUBTRNS_TAX`, `VN_MAINTRNS_TAX`, `VN_SUBTRNS_TAX`, `ST_TRNS_MAST_TAX`, `ST_TRNS_DET_TAX` refuse any change
to a document dated inside an approved statement's period ("Taxes Already calculated"). They stay active and are not duplicated.

## Rules and buttons

| # | Rule / button | Legacy evidence | APEX |
|---|---|---|---|
| 1 | `TAX_SERIAL` = max + 1 per company and tax type | `TX_TRNS_MAST.PRE-INSERT` | generated APPX key (same rule); item read-only |
| 2 | `TAX_NO`, `LEGAL_ADDRESS` copied from `COMPANY` when the company is chosen (display items) | LOV `COMP_LOV` mappings, items `Enabled=false` | row rule `stat_mast_row` on insert; items read-only |
| 3 | `FROM_DATE` = day after the last statement of the company / tax, else `TX_TAXES_TYPES.START_DATE`; `TILL_DATE` = `ADD_MONTHS(FROM_DATE, COMPANY.TAX_STAT_PERIOD) - 1` (both display items) | `TAX_CODE` / `COMPANY_CODE` WHEN-VALIDATE-ITEM | row rule `stat_mast_row` on insert; items read-only |
| 4 | Company, tax type, statement date required; statement date defaults to today | items `Required`, `TRNS_DATE` InitializeValue `$$DBDATE$$` | generated required + `defaults` + validation `stat_check` |
| 5 | Company, tax type and statement date cannot be updated once saved | items `UpdateAllowed=false` | validation `stat_check` (SAVE) |
| 6 | The period can be derived only with `COMPANY.TAX_STAT_PERIOD` (and a start date for the first statement): otherwise the required `TILL_DATE` stayed empty and the form refused the save | rule 3 + `Required` | validation `stat_check` (CREATE) with an explicit message |
| 7 | `TAX_CORR`, `PRE_TAX` default 0 | InitializeValue `0.00` | `defaults` |
| 8 | **تكوين** (PUSH_BUTTON55): "يجب الحفظ اولا" for an unsaved statement, "توجد بيانات" when it already has lines; then inserts (sequence `TX_TRNS_DET_SEQ` via trigger `TX_TRNS_DET_IN`): GL lines of the tax debit account (sign 1) and credit account (sign -1, value negated) of entries not posted from other systems (`POST_SYSTEM` not 31, 30, 4, 5, 3), base = tax * 100 / 15, indicator 6; AR transactions not linked to stock (`LINK_FLAG = 0`), `EFFECT` 0 as sign 1 (lines), `EFFECT` 1 as sign -1 (headers, `INV_VALUE <> 0`), indicator 1 or 3 (no tax); VN transactions (`EFFECT` 1 sign 1 lines, `EFFECT` 0 sign -1 headers, and the tax-account lines of `VN_MAINTRNS_SUPP_ACC` with base = tax * 100 / 5) of suppliers registered in `TX_TAXES_SUPPLIERS` for the tax, indicator 6 / 7 (external supplier) / 9 (no tax); sales invoices (`EFFECT 2 / TRNS_TYPE 2`) and returns (`4 / 4`), one line per invoice and tax bucket, header transport / discounts spread by line value, service tax / value added (`GET_SERVICE_TAX` / `GET_SERVICE_VALUE`), indicator 1 / 3; purchases (`1 / 1`) and returns (`3 / 3`), indicator 6 / 7 / 9; lines with value 0 and tax 0 deleted | `TX_TRNS_MAST.PUSH_BUTTON55` WHEN-BUTTON-PRESSED (full SQL in the `.fmb`) | action **BUILD** on the document page -> `app_rules3_tx.build_statement`: the same statements, in the page transaction (no COMMIT), `DET_SERIAL` from `TX_TRNS_DET_SEQ` (key_expr too, so the generated trigger never runs its max+1 query on `TX_TRNS_DET`, which would be a mutating-table error in a multi-row insert) |
| 9 | Tax indicator per line: list item of each tab - sales tabs (SLS, CUST, ENTRY credit) 1 نسبة اساسية, 2 مجلس التعاون, 3 بدون (صفر بالمائة), 4 صادرات (صفر بالمائة), 5 معفاه, 0 معالج حسابات (ENTRY credit also 6); purchase tabs (PUR, SUPP, ENTRY debit) 6 نسبة اساسية, 7 الاستيرادات التي تدفع في الجمارك, 8 الاستيرادات مطبقة عليها الاحتساب العكسي, 9 بدون (صفر بالمائة), 10 معفاه, 0 معالج حسابات; required | list elements of `T_TAX_FLAG` in each block (values in the XML, labels in the `.fmb`) | row rule `stat_det_row`: required and one of the values of the line's tab |
| 10 | Only the indicator, the remarks and (GL tabs) the 5 % checkbox are editable on a line; invoice no., values, date and keys are not | items `InsertAllowed/UpdateAllowed=false`, `Enabled=false` | `readonly` on the grid columns |
| 11 | `AC_5` (GL tabs): checked -> `TRNS_VALUE = TAX_VALUE * 20` (5 % rate), unchecked -> `TAX_VALUE * 100 / 15` | `TX_TRNS_DET_ENTRY_P/N.AC_5` WHEN-CHECKBOX-CHANGED | row rule `stat_det_row` (ENTRY lines, when AC_5 changes) |
| 12 | Lines cannot be deleted one by one | detail blocks `DeleteAllowed=false` | generated (detail grid without delete) |
| 13 | Delete: only the **last** statement of the company / tax ("يجب حذف اخر اقرار اولا"); its lines are deleted with it | `TX_TRNS_MAST.PRE-DELETE` | compound trigger `APP_RULES3_TX_MAST_BD` (APEX sessions): deletes the lines per row, checks "no later statement" after the statement (a row trigger cannot read `TX_TRNS_MAST`), the error rolls the whole delete back |
| 14 | Totals and boxes (display items): box n value / tax = sum of the lines with indicator n, invoices minus returns (+ the GL lines of that side); total sales (tax = box 1 only), total purchases (tax = boxes 6 + 7), مستحق ضرائب الفترة = sales tax - purchases tax, صافي الضريبة المستحقة = that + `TAX_CORR` + `PRE_TAX`; per tab tax totals; قيمة الاقرار تفصيلي = CUST - SUPP + SLS - PUR + ENTRY; قيمة الاقرار حسابات = GL movement of the two tax accounts in the period (credit account negated minus debit account) | formula / summary items of `TX_TRNS_MAST` and the tab blocks (`TOTAL_TRNS1..10`, `TOTAL_TAX1..10`, `TOTAL_TAX`, `ITEM206`, `TOTAL_DET_TAX`, `TOTAL_TAX_GL` ...) | 33 `info` values (panel of the saved statement) computed by `app_rules3_tx.stat_info` |
| 15 | **إظهار البيانات** (EXECUT): sales / purchases and their returns split by rate bucket 0 % (tax 0), 5 % (tax / value between 0.1 % and 10 %), 15 % (above 10 % or value 0) | `TX_TRNS_MAST.EXECUT` WHEN-BUTTON-PRESSED | 12 `info` values (S0/S5/S15, RS.., P.., RP..), always shown |

## Buttons not reproduced (and why)

| Legacy button | Why |
|---|---|
| طباعة اجمالي / طباعة تفصيلي (reports `TX_PRINT_TOT`, `TX_PRINT_DET`) | print designs belong to the document-print agent (`prints.json`); the generic print page 70012 prints header and lines. Suggest adding `TX_PRINT_TOT` to `prints.json`. |
| Percentage filter buttons of the tabs (`B5_SLS`, `PUR_QRY`, `TAX_CUST_B`, `SUPP_B`, `CTRL.B5`: show only lines whose tax / value ratio equals the typed percentage) | query helper only; the grid's own filters (source, sign, indicator, values) and the rate-bucket info values cover the use. A computed "percentage" grid column is not available in the generator. |
| Drill-down button on each line (`ITEM458`: opens `ARDBTRN` / `ARCRTRN` / `VNCRTRN` / `VNDBTRN` / `ST_ISSUE_IO` / `ST_ISSUE_RETURN` / `ST_RECEIVE_COST` / `ST_RETURN_COST` / `ACYRTR` in query mode on the source document) | navigation only; the generator has no per-row link to another form's document page. |
| Tab "اجمالي حسابات" (read-only list of the GL lines of the tax accounts in the period) | a detail region joined on a non-key value (account from the tax type, dates from the header) is not expressible; its total is info value "قيمة الاقرار حسابات". |

## Tests (build copy, simulated APEX session of app 100 on page 70011, generated triggers installed as the next build creates them; all rolled back, `TX_TRNS_DET_SEQ` restored)

- **Regression of the build button on the real statements**: the lines of each of the four legacy statements (2025 Q1-Q4, 1,923 lines)
  were deleted in the transaction and rebuilt: 1,920 lines identical (source, sign, document keys, values, invoice no., date) and the
  same tax indicators; the other differences are GL entries created or changed after the statement was issued (5 quarter-end
  settlement entries dated in the period but entered later, entry 2025/101/120072 changed 2026-05-21, one `CUST_INV_NO` filled later).
- Info values of statement 4 recomputed independently from the legacy formulas: boxes 1, 3, 6, 9, due, net, lines total (-7,386.76) =
  GL total (-7,386.76), rate buckets S15 and RP0 - equal.
- New statement 5: serial 5, period 01/01/2026-31/03/2026, tax no. / legal address from COMPANY; build -> 478 lines.
- Messages: "توجد بيانات", "يجب الحفظ اولا", English "Data Exist", statement date required, missing statement period, company / tax /
  date not updatable; indicator required / not allowed for the line's tab / accepted; AC_5 recomputes the base both ways; rules inactive
  on other pages; delete of statement 4 while 5 exists refused with its lines kept; delete of the last statement removes its lines.
- Script: `tmp\w3_gl\tx\t_tx.py` (99/99 checks, TX part and the other tax screens).

## Wave 3b (item properties of `TX\FMB\TX_STAT_fmb.xml`)

| # | Legacy | Evidence | APEX |
|---|--------|----------|------|
| 16 | Tax indicator list per tab (rule 9): sales side 1-5 / 0, purchase side 6-10 / 0, GL credit side also 6 | ListItemElement of T_TAX_FLAG in each block, labels of the `.fmb` | T_TAX_FLAG is a select list whose values depend on the line (`:PAGE_TAX_SOURCE` / `:PAGE_TAX_SIGN`, `cascade: [TAX_SOURCE, TAX_SIGN]`): exactly the values `stat_det_row` accepts; required |
| 17 | Percentage of each line PER = ROUND(NVL(TAX_VALUE,0) / NVL(TRNS_VALUE,1) * 100, 0) (the percentage filter buttons compared it) | Formula of PER | computed grid column "نسبة الضريبة %" (empty when the value is 0 instead of a division error) |
| 18 | AC_5 check box (1 / 0) | Check Box | `widget: CHECK` |
| 19 | Source and sign readable: the tabs المبيعات / المشتريات / العملاء / الموردين / الحسابات and invoices / returns | block WHERE of the tab blocks | static lists on TAX_SOURCE (tab names) and TAX_SIGN (فاتورة / مرتجع) |
| 20 | Company, tax type and statement date not updatable (rule 5) | UpdateAllowed = false | `readonly_after_insert` (the validation stays) |
| 21 | No manual lines: TAX_SOURCE is required but on no canvas, so a line could not be entered by hand; lines come from تكوين; no line delete | block / item properties | `rules.blocks` TX_TRNS_DET insert false, delete false (update: indicator, remarks, AC_5) |

**Tabs:** `rules.blocks.<TABLE>#n.where` can now show one grid per legacy tab. Not done: the generic print page (70012, used because
prints.json has no TX_STAT layout) prints every detail region with the master link only, so ten tab regions would print every line
ten times. Generator request: apply the per-block `where` in the print (then the ten tab grids can be declared). The single grid with the
source / sign lists and the grid filters covers the use meanwhile.

Tests: the indicator list SQL run for SLS / 1, PUR / -1, ENTRY / -1 and ENTRY / 1 (`tmp\w3b_gl\C\t_txflag.sql`: the same values as
`stat_det_row`), PER on the posted lines, page generation in memory (cascade parents TAX_SOURCE, TAX_SIGN; grid operations "u").

## Coverage

- Reproduced: rules 1-21 above.
- Not reproduced: the print buttons (print agent), the percentage filter buttons (query helper; the PER column and the grid filters),
  the drill-down buttons (links per row are not supported), the separate tab grids (print issue above), the read-only GL tab (a detail
  joined on non-key header values), prompts / visual attributes / navigation, `SET_IP`, WEBUTIL.
- Deviations: the build refuses with a message when the period is missing (the legacy button then silently did nothing); the build and the
  line changes are saved with the page (legacy `COMMIT` inside the button). The detail grid shows all lines of the statement in one grid
  with the source and sign columns (the legacy showed them in 10 tabs); the tab totals are info values.
- Generator features that would make the page closer to the legacy: the per-block `where` in the generic print (then the tab grids),
  row links to another document page, a detail joined on non-key header expressions.

## Open questions

1. Should an approved statement (`AUTH_FLAG = 1`) still be editable / deletable in APEX? The legacy form did not check it (only the
   document triggers lock the period).
2. The GL lines use a fixed 15 % base (tax * 100 / 15) and the supplier tax-account lines a 5 % base (tax * 100 / 5), as in the legacy
   button - confirm that this is still wanted.
