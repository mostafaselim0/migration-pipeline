# ST_CUSTOMER_REPLACE — إستبدال عميل فاتورة مبيعات غير مرحلة / Replace the Customer of Unposted Sales Documents (system 31, serial 65)

Deliverable: **process page** — `overrides/ST_CUSTOMER_REPLACE.json` (pattern PROCESS: parameters, preview of the documents,
button), `APP_RULES3_SA.replace_customer` calling the existing database function `ST_REPLACE_SALES_CUST`. Page 60180.
Confidence: **high** (the legacy form is a thin shell around the database function).

## Why a process page
The generated page was a form on the CUSTOMER file — wrong: the legacy screen changes no customer data. It lists the chosen
customer's **unposted** documents of one kind and moves them to another customer.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Customer, kind and new customer required — "يجب إستكمال البيانات" | `replace_customer` | message | high |
| 2 | Kinds: 1 sales invoices (EFFECT 2 / TRNS_TYPE 2), 2 sales orders not yet invoiced (with a document number), 3 quotations, 4 sales returns without invoice (EFFECT 4 / TRNS_TYPE 4) — only unposted (POST_FLAG, CUST_POST_FLAG 0), not deleted, not already moved (OLD_CUSTOMER_CODE null); invoices that were returned are excluded | preview SQL + procedure cursor | radio labels "فاتورة مبيعات / أوامر بيع / عروض أسعار / مرتجع مبيعات بدون فواتير", block WHERE clauses | high |
| 3 | Each document is moved by `ST_REPLACE_SALES_CUST(type, serial, new customer, kind)`: it moves the linked quotation / order / invoice together, keeps OLD_CUSTOMER_CODE / OLD_SALESMAN_CODE and takes the new customer's last salesman | database function (legacy, unchanged) | form calls the function; function source | high |
| 4 | A result other than 1 stops with "خطأ فى البيانات" (all moves of the run rolled back); success "تم النقل بنجاح" | `replace_customer` | messages | high |
| 5 | New customer: active customer, different from the old one | procedure + LOV (`CUSTOMER_STATUS = 1`) | customer LOV | medium |
| 6 | Optional "one document only" (type/serial of a listed document); empty = all listed documents (legacy: the button moves the listed rows) | parameter ONE_DOC | block of documents | medium |

While the function writes the documents, the sales row rules of wave 2 stand aside (`app_rules_sa.set_bypass`), as the
legacy function bypassed the screens.

## Tests (`tmp\w3_prsa\t_w3prsa.py`, page 60180; invoice 10301/626 unposted as a fixture)
CR1 data required · CR1b same customer refused · CR2 invoice moved, old customer kept · CR3 success message · CR4 bypass
released · CR5 nothing left to move. All PASS. `check_sql.py`: preview and parameter lists parse and run.

## Open questions
* All sales invoices / returns in the build copy are posted, so the screen currently finds nothing to move — expected?

## Wave 3b
Swept for the wave-3b keys: a process page; its parameters are already lists and its preview reads the page items. No list,
computed column, block setting or link applies. (`run_right` stays the insert right: the button changes documents.)

## Coverage
Reproduced: selection of unposted documents per kind, move through the legacy function (linked documents, old customer /
salesman), messages.
Not reproduced: the range check "كود البداية أكبر من كود النهاية" (library text, no range on this screen), toolbar code.
