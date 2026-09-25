# Addendum: document action buttons (conversions)

Some legacy documents have buttons that create the next document in the business flow: quotation → sales order, material
request → transfer request / purchase request, purchase request → purchase order / request for quotation, transfer request →
transfer. The generator adds these as **action regions** on the document page of the source form (below the header form, shown
only for a saved document), each with its own parameter items and one button.

Declare actions in `app\legacy\overrides\<FORM>.json` next to `rules` (top level of the override):

```json
{"pattern": "AUTO",
 "rules": {...},
 "actions": [{
   "name": "TO_ORDER",
   "label_a": "تحويل إلى أمر بيع", "label_e": "Convert to sales order",
   "confirm_a": "هل تريد تحويل عرض السعر إلى أمر بيع؟", "confirm_e": "Convert this quotation to a sales order?",
   "condition": "app_conv.can_quote_to_order(:PAGE_ROWID) = 'Y'",
   "params": [{"name": "ORDER_DATE", "label_a": "تاريخ أمر البيع", "label_e": "Order date", "type": "date", "required": true,
               "default": "to_char(sysdate, 'DD/MM/YYYY')", "default_type": "EXPRESSION"}],
   "call": "app_conv.quote_to_order(p_rowid => :PAGE_ROWID, p_order_date => :ORDER_DATE)",
   "target_form": "ST_SALES_ORDER",
   "success_a": "تم إنشاء أمر البيع", "success_e": "Sales order created"
 }]}
```

* `name`: A-Z, 0-9, _ (short, unique within the form).
* `condition` (optional): PL/SQL boolean expression deciding whether the action region is shown. The generator adds
  "document saved" and "user may insert on the target page" itself.
* `params` (optional): `type` is `date` (format DD/MM/YYYY), `number` or `text`; `default_type` is `STATIC`, `EXPRESSION` (PL/SQL
  expression) or `SQL_QUERY`; `lov_sql` (optional) is a two-column query `select display_value d, return_value r from ...`.
* `call`: PL/SQL **expression** returning the ROWID (varchar2) of the created (or reused) target header, or null. In `call`,
  `condition`, `default` and `lov_sql`: `:PAGE_<COLUMN>` / `:PAGE_ROWID` are the header items of the document page, and
  `:<PARAM NAME>` is the parameter, already converted to its type (date → DATE, number → NUMBER).
* `target_form`: legacy form whose document page opens the returned ROWID after success (omit to stay on the source document).
* `message` (optional): PL/SQL expression evaluated after `call`, shown as the success message instead of `success_a`
  (e.g. `app_conv.last_message`, the legacy confirmation with the numbers of the created documents).
* The call runs inside the page submit transaction: **no COMMIT / ROLLBACK** in the procedures; raise
  `raise_application_error(-20100..-20199, message)` to refuse (the whole action is rolled back). Messages in Arabic, English when
  `app_sec.lang = 'en'`, with the legacy text where one exists.
* The generated `APPX_<table>` triggers are active for the target tables when called from APEX (audit columns, keys, reviewed
  row rules). Procedures may set keys explicitly, as the legacy did.

PL/SQL goes into package `APP_CONV` in `app\db\22_conv.sql` (compiled into SMART by `build.py db`; run it yourself with
`app\tools\runsql.ps1` while developing). Evidence and rules per action go into the source form's `app\legacy\processes\<FORM>.md`.
