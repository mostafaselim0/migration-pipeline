# ST_PAYMENT_TERMS — أرقام شروط الدفع / Payment Terms (system 31, serial 31)

Deliverable: **screen correction (column order) + business rules** — `overrides/ST_PAYMENT_TERMS.json` (GRID on the same
table: SERIAL, TYPE_NAME, TYPE_NAME_E, NO_OF_DAYS + row rule), `APP_RULES3_SA.pay_term_row`. Page 60050.
Confidence: **high** for the rules below, **low** for the update restriction (question).

## Purpose and tables
`ST_PAYMENT_TERMS` (SERIAL, names, NO_OF_DAYS): payment terms of the sales documents (`ST_TRNS_MAST.PAYMENT_TYPE`,
`ST_SALES_ORDER`).

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Serial > 0 — "المسلسل يجب ان يكون اكبر من الصفر"; empty → next number | row rule; generated key | .fmx message | high |
| 2 | Number of days > 0 — "عدد الايام يجب ان يكون اكبر من الصفر" | row rule | .fmx message | high |
| 3 | No duplicate — "رقم مكرر تم إدخالة من قبل" | row rule (INSERT) | .fmx message | high |
| 4 | Delete of a used term | database foreign key of `ST_SALES_ORDER` (existing) | generic message "لا يجوز حذف السجل لإرتباطة بجداول اخري" (ORA-02292 handler) | medium |

## Open questions
* "لايمكن تعديل شرط الدفع" (the payment term cannot be changed): the only SQL of the form is `SELECT COUNT(1) FROM
  ST_PAYMENT_TERMS`, so the condition is unknown (perhaps: no change of the number of days once documents use the term).
  Not reproduced. Which condition did the legacy use?

## Tests (`tmp\w3_prsa\t_w3prsa.py`)
PY1 serial 0 refused · PY2 days 0 refused · PY3 duplicate refused · PY4 valid term numbered. All PASS.

## Wave 3b
Swept for the wave-3b keys: four text items (serial, Arabic / English name, days); no list, check box, display item, call-form
button or block restriction in the evidence. The update restriction stays a question (its condition is not visible). Nothing to apply.

## Coverage
Reproduced: serial, days and duplicate rules; legacy column order; delete guard by the foreign key.
Not reproduced: the update restriction of unknown condition (question), delete confirmation alert, toolbar / translation code.
