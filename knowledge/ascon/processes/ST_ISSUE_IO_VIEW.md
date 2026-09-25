# ST_ISSUE_IO_VIEW — متابعة حالة الفواتير / Invoices Transaction Status (system 31, serial 37)

- Registry: system 31 (Sales) serial 37, menu `FILES_MENU.ST_ISSUE_IO_VIEW`.
- Legacy module: `ASCON\ST\FMB\ST_ISSUE_IO_VIEW.fmx` (no .fmb, no GN_FORM_ITEM labels). Sister forms: ST_ISSUE_IO_PRINT (same
  query, print button), ST_ISSUE_IO_DLVR_TOUCH (sets the stages; reconstructed by the ST batch as `app_proc_st.invoice_stage`).
- **Deliverable (wave 3): read-only screen correction** — `overrides/ST_ISSUE_IO_VIEW.json` replaces the wave-1 REPORT_FORM with a
  read-only MASTER_DETAIL on `ST_TRNS_MAST` (insert / update / delete false, no details): the legacy filter in `where`, the 23
  columns of the monitor (identity, customer, payment terms, the seven stage flags and their dates, store, salesman, document
  number), legacy labels, the computed values are `rules.computed` columns (wave 3b; `info` in wave 3); `APP_RULES3_SA.invoice_total`,
  `invoice_status`. Pages 60170 (list) / 60171 (document). Confidence: **high** for the content, **medium** for the layout.

## What the screen is
A monitor of the sales invoices and their workflow stage: printed (حالة الطباعة), prepared (التحضير), reviewed (مراجعة), at the
delivery area (منطقة التسليم), delivered by driver / driver 2 (تسليم - السائق / السائق 2), received by the customer (تسليم -
العميل). No data is changed (no INSERT / UPDATE / DELETE in the .fmx).

## Query (evidence: embedded SQL) and how it is reproduced
| Legacy | APEX |
|--------|------|
| `TRNS_TYPE_CODE IN (SELECT TRNS_TYPE_CODE FROM ST_TRNS_TYPE WHERE TRNS_TYPE = 2 AND EFFECT = 2) AND NVL(DELETE_FLAG,0) = 0` | `rules.where` (same) |
| type / customer / store rights (`ST_TRNSTYPE_PASSWORD` FLAG 1, `AR_CUST_PASSWORD`, `ST_STORE_PASSWORD` FLAG 1) | `rules.where` with `:G_PASSWORD_NUMBER` |
| date parameter `R_DATE` (default today, previous / next day buttons) and store `FROM_STORE` | interactive-report filters on TRNS_DATE and STORE_CODE (the generator has no page parameters or default IR filter for a list page) |
| invoice total `SUM(QTY*(PRICE-(DISC1+DISC2+DISC3)) - DET_DISC + D.TAX_VALUE1) - DISC_VAL + M.TAX_VALUE1 + TRNSPORT_VAL - (TOT_DISC1+2+3)` | info TOTAL → `invoice_total` (checked equal to the legacy formula) |
| time of the invoice | info TIME (`INSERT_DATE`, HH24:MI) |
| customer old code, name, area / sub-area; salesman; payment terms (`ST_PAYMENT_TERMS.SERIAL = PAYMENT_TYPE`) | info CUST, SLSMAN, TERMS |
| stage flags + colour per stage | columns PRINT_FLAG ... CUST_AUTH_FLAG with their dates; info STATUS = last stage reached (`invoice_status`) |

Data in the build copy: 1318 live sales invoices (types 10301, 20301, 30301); 1311 printed; the other stage flags are 0 (only the
print stage is used).

## Not reproduced / limits
* The date / store parameter block and previous / next-day buttons: replaced by the interactive-report filters (no page
  parameters in the generator; a default IR filter "today" is a missing generator feature).
* Auto refresh (`RELOAD` timer) and the colour coding per stage (IR highlight rules can be added by hand).
* Wave 3: the computed values were on the document page only (`info`); wave 3b moved them to computed columns, see below.

## Tests (`tmp\w3_prsa\t_w3prsa.py`)
IV1 invoice total equals the legacy formula (invoice 10301/626: 8479.63) · IV2 last stage computed. `check_sql.py`: the list
query with the `where` and the six info queries parse and run. All PASS.

## Wave 3b
* `rules.computed` on ST_TRNS_MAST replaces the six `info` values, so the list page shows them too (and the document page, read-only):
  INV_TOTAL "اجمالى الفاتورة" (`APP_RULES3_SA.invoice_total`, the legacy formula), INV_STAGE "اخر حالة للفاتورة"
  (`invoice_status`), INV_TIME "وقت الفاتورة" (INSERT_DATE HH24:MI), CUST_NAME (old code, name, area / sub-area), SLSMAN_NAME,
  TERMS_NAME (ST_PAYMENT_TERMS). Run over the 1318 invoices of the build copy in 0.15 s; invoice 10301/626: 8479.63, "مطبوع".
* The generated list shows its first 10 visible columns by default; the computed columns come after the 23 table columns, so the
  user adds them once with the report's column menu (Actions > Columns) — the generator has no key for the default column set.
* Still no key for the parameter block (date with previous / next day, store) or a default report filter on a list page.
* Stage flags: no evidence of check boxes (no labels, .fmx only; the legacy shows them with colours) — kept as values.

## Coverage
Reproduced: the legacy invoice selection and rights, all stage flags and dates, invoice total, last stage, time, customer / area,
salesman, payment terms — on the list and the document since wave 3b; read-only.
Not reproduced: parameter block / day buttons (IR filters instead; no generator key for page parameters or a default filter on a
list page), auto refresh, colours, the computed columns in the default column set (added by the user, see above).
