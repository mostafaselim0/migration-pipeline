# TX_SERVICE - التطبيق على الخدمات / Service Obligation

- Registry: system 88 (Taxes) serial 10, order 2016. APEX grid page 70100.
- Legacy module: `ASCON\TX\FMB\TX_Service.fmx` (no .fmb, no GN_FORM_ITEM labels).
- **Deliverable**: wave 1 (a) screen correction -> `app\legacy\overrides\TX_SERVICE.json`, pattern `GRID` on `TX_TAXES_SERVICES`;
  **wave 3 adds the rules and the range button** (package `APP_RULES3_TX`, `app\db\25_rules3_tx.sql`).
- **Confidence: high.**

## What the screen is

Which services (`ST_PD_SERVICES`) a tax type (`TX_TAXES_TYPES`) applies to, and at what percentage - the service member of the
"obligation" family (TX_ITEMS, TX_CUSTOMERS, TX_SUPPLIERS, TX_AREAS, TX_ACCOUNTS, TX_AS_CTGRY). Legacy layout: master block tax types
(رقم الضريبة، الأسم عربى، الأسم لاتينى - "انواع الضرائب") and detail "الخدمات المطبق عليهم الضريبة" (رقم الخدمة، إسم الخدمة، النسبة),
relation `TX_TAXES_TYPES_TX_TAXES_SERVI` on `TAX_CODE`, plus a range panel (من خدمة / إلى خدمة / النسبة / تطبيق).
APEX: one grid with `TAX_CODE` as a column (list of values on `TX_TAXES_TYPES`); tax types are maintained in TX_TAXES_TYPES.

## Data

`TX_TAXES_SERVICES (TAX_CODE, SERVICE_CODE, TAX_PER)`, PK (`TAX_CODE`, `SERVICE_CODE`); build copy: one row (tax 2 "VAT 15%", service 1, 15).

## Rules and buttons

| # | Rule / button | Legacy evidence | APEX |
|---|---|---|---|
| 1 | Percentage > 0: "النسبة يجب أن تكون أكبر من الصفر" (range panel and detail block) | messages (twice) | row rule `oblig_row('SRV')` on insert and when the percentage changes |
| 2 | Service from `ST_PD_SERVICES` (name lookup `SELECT NAME_A, NAME_E FROM ST_PD_SERVICES WHERE SERVICE_CODE = :b1`) | embedded SQL | row rule: the service must exist ("رقم الخدمة غير موجود") - the generator has no list of values for `SERVICE_CODE` |
| 3 | No automatic service number (the generated trigger would put max + 1 into an empty `SERVICE_CODE`, the last key column) | wave-1 finding | `key_expr` `null` |
| 4 | Entering a service already present for the tax updates it: `SELECT COUNT(1) ... WHERE SERVICE_CODE = :s AND TAX_CODE = :t` then `UPDATE TX_TAXES_SERVICES SET TAX_PER` | embedded SQL | the primary key refuses the duplicate; the user edits the existing row |
| 5 | **تطبيق** (range apply): `DELETE FROM TX_TAXES_SERVICES WHERE SERVICE_CODE BETWEEN :from AND :to AND TAX_CODE = :tax; INSERT INTO TX_TAXES_SERVICES (TAX_CODE, SERVICE_CODE, TAX_PER) SELECT :tax, SERVICE_CODE, :per FROM ST_PD_SERVICES WHERE SERVICE_CODE BETWEEN :from AND :to` | embedded SQL | grid action **APPLY** -> `app_rules3_tx.apply_services` (tax number parameter, default the first tax type; confirmation) |
| 6 | `SELECT 1 FROM TX_TAXES_SERVICES WHERE TAX_CODE = :b1` - Forms master-detail check before deleting a tax type (master block) | embedded SQL | not applicable (no tax-type block on this page) |

Column headings: رقم الضريبة / رقم الخدمة / النسبة (`add_columns` labels).

## Tests

Unknown service refused, 0 % refused, apply services 1..1 at 12 %. `tmp\w3_gl\tx\t_tx.py`.

## Wave 3b

`SERVICE_CODE` gets the legacy service list (`SELECT SERVICE_CODE CODE, NAME_A NAME ... FROM ST_PD_SERVICES ORDER BY 1`): select list
"code - name" (the row rule still refuses an unknown service). SQL run on the build copy.

## Coverage

Reproduced: 1-3, 5; 4 as described; 6 not applicable; the service list with its name (wave 3b).
