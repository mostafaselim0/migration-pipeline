# TX_CUSTOMERS - التطبيق على العملاء / Customers obligation

- Registry: system 88 (Taxes) serial 4, order 2012. APEX grid page 70060.
- Legacy module: `ASCON\TX\FMB\TX_Customers.fmx` (no `.fmb`, no labels). Master "انواع الضرائب", detail "العملاء المطبق عليها الضريبة"
  (`TX_TAXES_CUSTOMERS`: رقم العميل / إسم العميل / النسبة / الرقم الضريبي), range panel (من عميل / إلى عميل / النسبة / تطبيق).
- **Deliverable: (a) generated grid kept (`"pattern": "AUTO"`) + row rule + key fix + range action**; `APP_RULES3_TX`,
  override `TX_CUSTOMERS.json`. **Confidence: high.**

## Rules and buttons

| # | Rule / button | Legacy evidence | APEX |
|---|---|---|---|
| 1 | Customer from the customer list (all customers) | LOV `SELECT CODE, NAME_A ... FROM CUSTOMER` | generated list of values |
| 2 | The customer is chosen, never numbered automatically | the generated trigger would put max + 1 into an empty `CUSTOMER_CODE` (last key column) | `key_expr` `null` (disables the generated number; an empty code is refused by the database) |
| 3 | Percentage > 0 "النسبة يجب أن تكون أكبر من الصفر" (range panel and detail block) | messages | row rule `oblig_row('CUST')` on insert and when the percentage changes |
| 4 | **تطبيق**: every customer between the two codes gets the percentage (existing row updated, otherwise inserted); percentage > 0 | `SELECT * FROM CUSTOMER WHERE CODE BETWEEN :b1 AND :b2`, `INSERT INTO TX_TAXES_CUSTOMERS (TAX_CODE, CUSTOMER_CODE, TAX_PER)` / `UPDATE ... SET TAX_PER` | grid action **APPLY** -> `app_rules3_tx.apply_customers` |
| 5 | Entering a customer that already has a row for the tax updated its percentage | `SELECT COUNT(1) ... WHERE CUSTOMER_CODE = :b1 AND TAX_CODE = :b2` / `UPDATE ...` | the primary key refuses the duplicate; the user edits the existing row (same result, no silent update) |

The table is also read by `GET_TAX_VALUE_DB` (customer percentage for invoices) and written by the customer master screen (CUSTOMER);
those writes are not checked here.

## Tests

No automatic customer code (ORA-01400), 0 % refused, apply to all 126 customers at 10 %. `tmp\w3_gl\tx\t_tx.py`.


## Wave 3b

Checked, nothing to change: the customer column has the customer list (legacy `SELECT CODE, NAME_A ... FROM CUSTOMER`), which shows the name; no check box / list item / radio group; APPLY is an action.

## Coverage

Reproduced: 1-4; 5 differs as described. Not reproduced: name display items (LOV display), master tax-type block (tax types have their
own screen).
