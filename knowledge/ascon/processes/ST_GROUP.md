# ST_GROUP - أرقام مجموعات الأصناف / Item Groups Numbers

- Registry: system 3 serial 209 (also system 30 serial 14, system 31 serial 16), menu `CODES_MENU.ST_GROUP`. Legacy module
  `ASCON\ST\FMB\ST_GROUP.fmx` (no .fmb: evidence is the embedded SQL and texts of the .fmx).
- APEX: pages 20180 / 20181. Override `overrides\ST_GROUP.json` turns the generated report + form into `MASTER_DETAIL`:
  master `ST_ITEM_GROUP`, detail `ST_ITEM_GROUP_COV` "نسب التغطية" (join `GROUP_CODE = ITEM_GROUP_CODE`, the legacy second tab);
  adds `GROUP_LEVEL` / `GROUP_STATUS` read-only; group-permission filter; total cost panel; button "إضافة مجموعة فرعية".
- Rules in package `APP_RULES3_ST` (`app\db\25_rules3_st.sql`): `code_required`, `group_row`, `val_group`, `group_after`,
  `group_cov_row`, `group_total_cost`, `add_child_group`, `group_allowed`; delete hook = compound trigger `APP_RULES3_ST_GROUP_DEL`
  (`group_delete` per row, `group_delete_done` after the statement). Row rules become active in `APPX_ST_ITEM_GROUP` /
  `APPX_ST_ITEM_GROUP_COV` at the next build (build.py was not run).
- Data: 14 groups on 3 levels of the 5-level group structure (`ST_CHART_STRUCTURE` type 2: 1 / 2-3 / 4-5 / 6-8 / 9-12);
  `ST_ITEM_GROUP_COV` and `ST_GROUP_PASSWORD` are empty.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| The group code is typed: "يجب إدخال رقم المجموعة" | code item required | `key_expr` `code_required(2)` (raises when empty) | high |
| Code padded to 12 digits, level found from the structure; "خطأ فى رقم مجموعة الأصنـــاف" when a level is zero while a lower one is not; "لابد من إدخال هيكل مجموعــات الأصنـــاف أولا" without structure | `SELECT CHR_STRU_START / LENGTH / CHR_STRU_END FROM ST_CHART_STRUCTURE WHERE CHR_TYPE = 2 ...`, program unit DETECT_GROUP_LEVEL, messages | `group_row` (insert: `pad12`, `detect_level`) | high |
| Parent must exist: "لا يوجد مجموعة أصنــاف رئيسية لهذا الرقم" | `SELECT COUNT(1) FROM ST_ITEM_GROUP WHERE ITEM_GROUP_CODE = :parent`, message | validation `val_group` | high |
| Parent must not hold items: "تم عمل حركات على المجموعة الرئيسية" | `SELECT COUNT(1) FROM ST_ITEM WHERE ITEM_GROUP_CODE = :b1`, message | `val_group` | high |
| Duplicate: "يوجد مجموعة أصنـــاف بنفس الرقم بالملف" | `SELECT COUNT(1) FROM ST_ITEM_GROUP WHERE ITEM_GROUP_CODE`, message | `val_group` (+ primary key) | high |
| A new group is a transaction group (`GROUP_STATUS = 1`) and its parent becomes a classification group (`GROUP_STATUS = 0`) | `UPDATE ST_ITEM_GROUP SET GROUP_STATUS = 0 WHERE ITEM_GROUP_CODE = :b1` | `group_row` (status 1) + after-save `group_after` (CREATE) | high |
| Expiry / colour / size flags default from `ST_BASIC` | `SELECT NVL(EXPIRE_FLAG,0), NVL(COLOR_FLAG,0), NVL(SIZE_FLAG,0) FROM ST_BASIC` | `defaults` (SQL) | high |
| Account / cost centre changes are copied to all sub-groups (both cost-centre items update `COST_CODE`, as in the legacy) | `UPDATE ST_ITEM_GROUP SET ACCOUNT_NUMBER / COST_CODE = :b1 WHERE SUBSTR(ITEM_GROUP_CODE,1,:end) = :prefix` | `group_row` records the change, `group_after` (SAVE) propagates | high |
| Stop flag copied to the sub-groups with reason "<reason>(المجموعة الرئيسية <code>)"; un-stopping clears flag, date and reason of the sub-groups; the items of the group get the same flag and reason | `UPDATE ST_ITEM_GROUP SET STOP_FLAG = 1, STOP_REASON = :b1 || DECODE(:lang,'A','(المجموعة الرئيسية ','(Parent Group ') || :code || ')' ...`, `... SET STOP_FLAG = 0, STOP_DATE = NULL, STOP_REASON = NULL ...`, `UPDATE ST_ITEM SET STOP_FLAG = :b1, STOP_REASON = :b2 WHERE ITEM_GROUP_CODE = :b3` | `group_after` | high |
| Stop reason cleared when the group is not stopped | not visible in the .fmx SQL; same rule as ST_ITEM PRE-UPDATE and ST_STORE (and the un-stop UPDATE above clears the reason of the sub-groups) | `group_row` | medium |
| Delete refused while items exist: "لايمكنك حذف هذا السجل حيث أنه تم إجراء حركات عليه" | `SELECT DISTINCT 'x' FROM ST_ITEM WHERE ITEM_GROUP_CODE = :b1`, message | `APP_RULES3_ST_GROUP_DEL` / `group_delete` | high |
| Delete refused for a classification group: "يوجد مجموعات فرعية لهذه المجموعة لذلك لايمكنك الحذف" | message, `GROUP_STATUS` | same | high |
| After deleting the last sub-group the parent becomes a transaction group again | `UPDATE ST_ITEM_GROUP SET GROUP_STATUS = 1 WHERE ITEM_GROUP_CODE = :b1` | `group_delete_done` (after statement) | high |
| List restricted to the groups of the user's permission group (`ST_GROUP_PASSWORD`, `FLAG = 1`, by structure prefix) | block WHERE `(:1=0 OR ITEM_GROUP_CODE IN (SELECT ... ST_GROUP_PASSWORD GP ... GP.FLAG=1 AND CHR_TYPE=2 AND SUBSTR(GP.GROUP_CODE,1,CHR_STRU_END) = SUBSTR(IG.ITEM_GROUP_CODE,1,CHR_STRU_END)))` | `where` `group_allowed(ITEM_GROUP_CODE, 0) = 1` | high |
| تكلفة كلية = sum of `GET_BALANCE_COST` over the group's store rows | CALC_COST, `SELECT STORE_CODE, ITEM_CODE FROM ST_STORE_ITEM WHERE GROUP_CODE = :b1` | `info` CURRENT_COST (`group_total_cost`) | high |
| Coverage ratios: "قيمة النهاية لا يمكن ان تكون اقل من قيمة البداية"; serial max+1 per group | message, `SELECT NVL(MAX(NVL(SERIAL,0)),0)+1 FROM ST_ITEM_GROUP_COV WHERE GROUP_CODE` | row rule `group_cov_row`; serial by the generated key numbering (max+1 within the group) | high |

## Buttons

| Legacy | APEX | Confidence |
|---|---|---|
| إضافة مجموعة فرعية (ADD_SON): next code `RPAD(SUBSTR(MAX(ITEM_GROUP_CODE),1,end_child)+1,12,0)` under the current group; "لا يمكن تكوين مجموعة أبن بلا مجموعة أب", "لا يمكن إضافة مجموعة فرعية بينما هناك أصناف مرتبطة بالمجموعة" | action `ADD_SON` (names typed in the dialog) -> `add_child_group`: creates the sub-group with the ST_BASIC flags, the parent's account / cost centres, level + 1, transaction group; parent becomes classification; opens the new group | high (the legacy button opened a new record with that code; the dialog asks for the names instead) |
| حساب التكلفة (CALC_COST) | info panel "تكلفة كلية" | high |
| عرض الشجره (tree of groups) | not reproduced (the list is ordered by code; level and status are shown) | - |

## Tests (rolled back, `tmp\w3_st\t_rules3_st.py`, 188/188 passed in the final run)

D1 level detection, valid / duplicate / missing parent / parent with items; D2 ADD_SON creates 101040000000 (level 3, transaction group,
ST_BASIC flags), refused under a group with items; D3 stop flag propagated with the parent suffix, items of a stopped leaf group stopped;
D4 delete refused with items / sub-groups, parent stays classification when other sub-groups remain; D5 coverage end < start refused;
D6 total cost.

## Open questions

- The group's own `STOP_DATE` is not set by any SQL of the .fmx (the store screen sets `SYSDATE`); left as typed. Should it be set?
- "لا توجد صلاحية للمجموعة" and "يجب ادخال مؤشرات النظام اولا" appear in the .fmx texts without the SQL that raises them; the permission
  filter and the ST_BASIC defaults cover the visible cases.

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Group code required on the page (the key expression `code_required(2)` stays) | `columns.ST_ITEM_GROUP.ITEM_GROUP_CODE.required` | message "يجب إدخال المجموعة" |

Reviewed, not changed: `GROUP_LEVEL` / `GROUP_STATUS` are not legacy items (added read-only by wave 3, no legacy list texts); the
`TAB_NO1..12` lists are off (`ST_LOCKUPS` empty, `GROUP_PRE_CODE` = 0); account / cost-centre lists: the legacy LOV SQL is not in the
evidence of this .fmx, the generic lists stay.

## Coverage

- Reproduced: code / level / parent / duplicate checks, status of new groups and parents, ST_BASIC flag defaults, propagation of
  account, cost centre and stop flag (sub-groups and items), delete checks and parent status after delete, permission filter,
  total cost, coverage ratios tab and its check, ADD_SON.
- Not reproduced:
  - tree view and the "تكوين الكود" code-composition helper (`ST_BASIC.GROUP_PRE_CODE` = 0 in the data, feature off);
  - the "تقسيم المجموعة" lists `TAB_NO1..12` (fed by `ST_LOCKUPS`, which is empty; not table columns) and the `GAIN_PRCNT` prompt
    (no such column in SMART);
  - lists of values on level / status (no legacy list) and the permission-filtered account / cost-centre lists (their SQL is not in
    the .fmx evidence; generic lists are used).
