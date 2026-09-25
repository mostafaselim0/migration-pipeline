# ACCSTCD - أرقام مراكز التكلفة 1 / Cost Centers Number 1

- Registry: system 1 serial 21 (CODES_MENU.ACCSTCD1, order 2005). APEX grid page 10120.
- Legacy module: `ASCON\AC\FMB\ACCSTCD.fmx` (no .fmb). Tree + multi-record block AC_COST_CENTERS, project info sub-window.
- **Deliverable: screen correction + rules (wave 3).** Override `app\legacy\overrides\ACCSTCD.json` (pattern `GRID`, insert through the
  button only), PL/SQL `APP_RULES3_GL`, delete hook `APP_RULES3_GL_COST1_DEL`.
- **Confidence: high** (same program units as ACMAST for 9-digit codes: DETECT_COST_LEVEL(_NEW), GET_COST_PARENT, COST_FOUND,
  TRANSACTIONS_FOUND_FOR, COST_HAS_BROTHERS, GET_NEXT_COST; data: the two newest cost centres have AC_COMPANY_COST1 / AC_PASSWORD_COST1
  group 0 rows).

## Why the grid does not insert

The generator gave `COST_CODE` (the table's own key) the list of values of `AC_COST_CENTERS2` (same column name), so a new cost
centre could only get a cost-centre-2 number. New cost centres are created with the button, which is also how the legacy tree
created them (next child of the selected node). COST_CODE and COST_LEVEL are read-only in the grid. (Wave 3b: the wrong list is
removed, see below.)

## Rules

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | New cost centre under the selected node: next child `RPAD(SUBSTR(MAX(COST_CODE),1,end_child)+1,9,0)`, level + 1, status 1; or a typed code checked against the structure (level, parent exists "لا يمكن تكوين مركز تكلفة إبن بلا مركز تكلفة أب") | create-child trigger, COST_CODE validation | action ADD "إضافة مركز تكلفة" (parent or code, names) |
| 2 | No child under a cost centre with transactions | TRANSACTIONS_FOUND_FOR | action ("لا يمكن إضافة مركز تكلفة فرعي لمركز عليه حركات" - new text) |
| 3 | After insert: parent status 0; grants `INSERT INTO AC_COMPANY_COST1 / AC_PASSWORD_COST1` ("لم يم ادراج رقم مركز التكلفة في السرية") | POST-INSERT SQL | inside `add_cost_center` |
| 4 | MAX_LIMIT > 0 ("يجب ان تكون القيمة  اكبر من صفر") | MAX_LIMIT validation | row rule `cost_center_row` |
| 5 | Delete refused with transactions (daily, posted, opening, estimate by COST_CODE); grants deleted; parent status 1 when its last child goes | PRE-DELETE / POST-DELETE SQL | delete hook (row + after statement) |
| 6 | List restricted by AC_PASSWORD_COST1 (prefix by COST_END_POS), group 0 all | block WHERE | `where` |

## Tests (section C of `tmp\w3_gl\gl\t_gl.py`)

Next child 102006000 (level 3, status 1) with company and group grants; typed 103 -> 103000000 level 2; missing parent, non-fitting
code, neither parent nor code, parent with transactions, duplicate code refused; MAX_LIMIT 0 refused / 5 accepted; delete with
transactions refused; child 103001000 made its parent main, deleting it restored the parent and removed the grants. Passed.

## Wave 3b

- `rules.columns` `AC_COST_CENTERS.COST_CODE: {"lov": null}`: the wrong AC_COST_CENTERS2 list is gone; the code is a plain (read-only)
  number, so codes that exist in both tables no longer show the cost-centre-2 name.
- Insert stays on the ADD button: the legacy insert rules (next child of the tree node or a typed code checked against the structure,
  parent status, AC_COMPANY_COST1 / AC_PASSWORD_COST1 grants) live in `add_cost_center`; a grid insert would bypass them.
- Checked: no legacy check box / list item / radio group on this block; the only displays are the tree; PUSH_BUTTON65 (tree) is Forms-only.

## Coverage

- Reproduced: rules 1-6, project data columns (PROJECT_VALUE / OWNER / DATE / PERIOD) editable in the grid, cost-centre code without the
  wrong list (wave 3b).
- Not reproduced: the tree (FTREE) and its buttons, print (report AC_COST_CENTER_PRM, reports menu), TRANSLATE / WEBUTIL.
