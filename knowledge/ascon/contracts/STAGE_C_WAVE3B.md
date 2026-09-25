# Stage C, wave 3b: new generator keys

Wave 3 agents asked for generator features. They now exist, and every one is tested in APEX: pages imported and opened
in Edge. This addendum describes them. Read `STAGE_C_WAVE3.md` first. The house rules there still apply: evidence first,
tests end with ROLLBACK, no `build.py`, no commits.

## Per column: `rules.columns`

The key is `"TABLE.COLUMN"`, or `"COLUMN"` for a column of the master block. A column the generator did not place is added.

```json
"columns": {
  "ST_ITEM.ITEM_STATUS":     {"static": [["نشط", "1"], ["موقوف", "0"]]},
  "ST_ITEM.ITEM_TYPE":       {"static": [["مخزني", "1"], ["خدمي", "2"]], "widget": "RADIO"},
  "AC_DAILY_TRN_DET.CUST_CODE": {"lov": "select benf_name d, benf_code r from ac_benf_tax order by 1", "widget": "POPUP"},
  "ST_UNIT.UNIT_CODE":       {"lov": null},
  "ST_ITEM.STOP_FLAG":       {"widget": "CHECK", "values": ["1", "0"]},
  "ST_ITEM.ITEM_GROUP_CODE": {"readonly_after_insert": true},
  "ST_ITEM.NAME_E":          {"required": true},
  "ST_TRNS_DET.EXPIRY_DATE": {"default": {"type": "EXPRESSION", "value": "sysdate + 365"}}
}
```

| Option | Effect |
|---|---|
| `lov: null` | Removes a wrong automatic list. The field becomes a plain text, number or date field. |
| `lov: "select display, return from ..."` | A list from SQL. `widget` is `POPUP` (default, searchable) or `SELECT`. Page items can be referenced as `:P<page>_<COL>`, but the page number differs per screen, so prefer self-contained SQL. |
| `lov` + `cascade: "COL"` or `["COL", ...]` | A list that depends on other fields of the same record. In the SQL, write `:PAGE_<COL>` (for example `where bank_code = :PAGE_BANK_CODE`). On a form it becomes the page item; in a grid, the row's column. The list refreshes when those fields change. |
| `static: [[label, value], ...]` | A fixed list: a select list, or a radio group with `"widget": "RADIO"` (in a grid it is shown as a select list). Use the legacy radio or list values. An optional third element is the English label: `[label_a, value, label_e]`. |
| `widget: "CHECK"`, `values: [on, off]` | A check box with the legacy values. The default is 1/0 for numbers and Y/N for text. |
| `required`, `readonly`, `hidden` | true or false. |
| `readonly_after_insert: true` | Editable on a new record or line only. |
| `default: {type, value}` | `STATIC`, `ITEM` (for example `G_COMPANY_CODE`), `EXPRESSION` (PL/SQL expression) or `SQL_QUERY`. All four now also work on grid columns and on hidden columns. |
| `label_a`, `label_e` | Labels. |
| `link: {"form": ..., "doc": true, "items": {"TARGET_ITEM": "COLUMN"}}` | Grid column shown as a link that opens another screen for its row (the legacy drill-down on a line), passing the row's values. Works with computed columns too. The column becomes read-only. |

## Display-only computed columns: `rules.computed`

```json
"computed": {
  "ST_TRNS_DET.ITEM_NAME": {"sql": "(select max(i.name_a) from st_item i where i.item_code = t.item_code)", "label_a": "اسم الصنف"},
  "ST_TRNS_MAST.LINES":    {"sql": "(select count(*) from st_trns_det d where d.trns_type_code = t.trns_type_code and d.trns_serial = t.trns_serial)",
                            "label_a": "عدد السطور", "type": "NUMBER"}
}
```

`sql` is an expression over the row, which has the alias **`t`**. On a grid or detail the column is read-only and is not
saved. The grid then reads a query, and its save process is generated PL/SQL. On a master or single-record form the
value is shown for the saved record, and the list page shows it too. `type` is `NUMBER`, `DATE` or text (the default).

## Blocks

* `rules.blocks`: `{"ST_TRNS_DET": {"insert": false, "update": true, "delete": false}}` sets insert, update and delete
  per detail grid (or per master).
  * `"where"` adds a filter to a detail grid, on top of the master link. It may use `:PAGE_<COL>` of the document.
    Examples: two grids on one table with different filters, or a month filter.
  * `"TABLE#2"` addresses the second detail block of the same table. Declare the second block in the override's `details`
    list with its own `title_a`.
* `rules.delete_lines: "refuse"`: deleting a document that still has lines is refused. The default is to delete the
  lines first. `rules.delete_lines_msg` holds the legacy message.

## Buttons that only open another screen: `links` (top level of the override, next to `actions`)

```json
"links": [{"label_a": "حركات الصنف", "label_e": "Item movements", "form": "ST_ITEM_MOVE", "items": {"ITEM_CODE": "ITEM_CODE"}}]
```

`form` is the target legacy screen, and its main page is opened. Add `"doc": true` to open its document page instead.
`items` maps target page items (`P<target>_<NAME>`) to a column of the current record, or to a `'literal'`.
With `"doc": true` and no `ROWID` among the items, the target document opens as a **new record with those values
prefilled**, like the legacy "new document from here" buttons (tested). Pass codes and numbers only. Values with spaces
or commas do not survive the URL: they fail the session checksum.

## Process and query screens (`proc` in the override)

* `"run_right": "query"`: the run button needs only the page (query) right, not the insert right. Use it for display
  and query screens.
* `"print_runs": true`: the print buttons also run the procedure first, as the legacy print buttons did (for example to
  prepare a work table).
* `"message"`: a PL/SQL expression evaluated after the run (for example `app_x.last_message`), shown as the success text.
  The default is `success_a`.
* A parameter of `"type": "multi"` with `lov_sql` shows check boxes. The procedure receives the chosen values as one
  colon-separated string, for example `1:4:7`.
* Print buttons on these screens now submit the page. In `prints.json`, a parameter written `"@NAME"` takes the value of
  the screen's own field `P<page>_NAME`, for example `"FROM_STORE_CODE": "@STORE_CODE"`.

## Actions on read-only documents

`actions` now also appear on read-only documents, for example a voucher shown read-only that has a post button.

## Added 2026-09-25: the four remaining gaps

All four were tested in Edge on app 100 (build copy, test data removed afterwards).

**Columns shown only with a right.** `rules.columns.<COL>.show_if` or `rules.computed.<COL>.show_if`: a SQL condition,
or a named legacy right, `"right:VIEW_COST"` (group 0, or `ST_BASIC.SHOW_COST = 1` and `USERS.ALLOW_VIEW_COST = 1`) or
`"right:VIEW_BALANCE"` (user 0, or `USERS.ALLOW_VIEW_BALANCE = 1`), evaluated by `app_ui.has_right`. Without the right,
the grid column, form field or list column is not rendered at all. Used on the 20 cost and balance columns of the stock
screens.

**Warnings about the lines.** `"lines": true` on a `rules.warnings` entry. The warning runs inside the save itself, after
the header and every grid line are written, so it also sees unsaved lines. If it fires, the whole save is rolled back.
The page keeps what the user typed and asks "لم يتم الحفظ بعد. هل تريد الحفظ رغم ذلك؟"; confirming saves.
Warnings that compare the typed value with the saved one (a changed flag, for example) must stay without `lines`. Used
on ST_ITEM_REQ, ST_ITEM_REQ_HANDLE and the credit limit of ST_SALES_ORDER.

**Buttons that fill lines.** Top-level `fills`:
`[{"label_a", "label_e", "table", "sql", "items": [{"name", "label_a", "lov", "cascade", "type"}], "confirm_a", "icon"}]`.
* The button sits on the grid of `table`.
* `sql` returns one row per new line, with columns named like the grid's (`COL__D` gives the text shown for a list
  column), and may use `:PAGE_<COL>` and the fill's own `items`, which are screen-only fields shown under the header.
* The rows are added as new, unsaved lines, and nothing is written before Save.

Used on VNDBTRN (*جلب أصناف الفاتورة*, the legacy GET_ITEMS).

**Detail of a detail.** `rules.sub_details`: `[{"table", "parent", "join": [[COL, PARENT_COL]], "title_a", "title_e",
"insert", "update", "delete", "order_by"}]`.
* A grid under the selected line of the grid on `parent`, using APEX master-detail grids: it follows the selected
  line, and new rows take its keys.
* `join` defaults to the foreign key. `rules.columns` may address the sub-grid's columns.
* Sub-grids are not printed and are not in the document delete cascade (their foreign key protects them).

Used on ST_ITEM (class discounts per unit), AR_SALESMAN_COMM_REV (item lines) and AR_MULTI_CUST_TRNS (invoice allocation).

**One save per document.** The grids of a document page no longer have their own Save button: **حفظ التعديلات** saves
the header and all lines in one transaction, so every rule and warning sees the whole document.
