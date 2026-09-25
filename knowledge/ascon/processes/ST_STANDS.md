# ST_STANDS - ملف الاصناف المجمعة / Stands Items File

- Registry: system 3 serial 423, menu `WRKSHP_SUPRVSN.COMP_ITEM`. Legacy module `ASCON\ST\FMB\ST_STANDS.fmx` (no .fmb: evidence is
  the embedded SQL, the texts and the GN_FORM_ITEM labels).
- APEX: pages 20450 / 20451 (+ print 20452), `MASTER_DETAIL`: master `ST_ITEM` (assembled items), details `ST_ITEM_UNIT` "وحدات المنتج",
  `ST_STAND_ITEMS` "مكونات المنتج", `ST_STAND_SERVICES` "الخدمات". Override `overrides\ST_STANDS.json` (AUTO) adds the filter, rules and
  the total-cost panel.
- Package `APP_RULES3_ST`: `item_row` / `unit_item_row` (same row-rule strings as ST_ITEM, so one shared `APPX_ST_ITEM` /
  `APPX_ST_ITEM_UNIT` trigger), `val_item('ST_STANDS', ...)`, `item_after('ST_STANDS', ...)`, `stand_item_row`, `stand_service_row`,
  `stand_cost`, `item_delete` / `unit_item_delete` (ST_STANDS branches via `cur_form`); delete hooks `APP_RULES3_ST_ITEM_BD`,
  `APP_RULES3_ST_ITEM_UNIT_BD`. Row rules become active at the next build.
- Data: no assembled items (`STAND_FLAG = 1`: 0 rows), `ST_STAND_ITEMS`, `ST_STAND_SERVICES`, `ST_TRNS_STAND_DET` empty; 1 service.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| Only assembled items (`NVL(STAND_FLAG,0) = 1`) of transaction groups allowed for the user | block WHERE `NVL(STAND_FLAG,0) = 1 AND (:1=0 OR ITEM_GROUP_CODE IN (... ST_GROUP_PASSWORD ... GROUP_STATUS=1 AND GP.FLAG=1 ...))` | `where` | high |
| New rows are assembled items (`STAND_FLAG = 1`) | block WHERE (a new row must match it) | `item_row` on insert when the page is ST_STANDS | high |
| Group = transaction group of the user (LOV `GROUP_STATUS=1`, permission) | LOV SQL | `val_item` "لا يوجد سجل مناظر فى الجداول الأخرى." | high |
| Item code typed, not duplicated: "رقم الصنف مكرر"; numeric unless `COMPANY.CHAR_ITEM_CODE` = 1: "خطأ في رقم الصنف !!!" | `SELECT COUNT(1) FROM ST_ITEM WHERE ITEM_CODE AND ITEM_GROUP_CODE`, `SELECT NVL(CHAR_ITEM_CODE,0) FROM COMPANY`, `SELECT TO_NUMBER(:b1) FROM SYS.DUAL`, messages | `val_item` (duplicate), `item_row` (numeric; inactive in the data) | high |
| Arabic name required | label / required item | `val_item` "يجب إدخال الإسم العربى" | medium |
| Items of a stopped group are stopped; min <= max ("الحد الأدنى أكبر من الحد الأقصى") | shared ST_ITEM rules, message present in the .fmx | `item_row` | medium |
| Exactly one basic unit ("لا توجد وحدة أساسية", "يوجد أكثر من وحدة أساسية إستبعد الوحدة الأساسية أولاُ"), basic factor 1 ("معامل التحويل للوحدة الأساسية يجب أن يساوى واحد") | `SELECT COUNT(1) FROM ST_ITEM_UNIT WHERE ... AND BASIC_UNIT = 1`, messages | `item_after` (save), `unit_item_row` | high |
| A unit used in transactions cannot be deleted / changed ("لا يمكن حذف أو تغير الوحدة الأساسية لإشتراك الصنف فى أحد الحركات", "لا يمكن حذف هذه الوحدة لإشتراكها فى أحد الحركات") | `SELECT COUNT(UNIT_CODE) FROM ST_TRNS_DET WHERE (GROUP_CODE = :b1 ...) AND (UNIT_CODE = :b3 ...)`, messages | `unit_item_row`, `unit_item_delete` | high |
| Save refused without components: "غير مسموح بحفظ الصنف بدون اصناف مركبة !!!" | `SELECT COUNT(1) FROM ST_STAND_ITEMS WHERE STAND_ITEM_GROUP_CODE AND STAND_ITEM_CODE`, message | `item_after('ST_STANDS')` | high |
| Component quantity > 0: "يجب ان تكون القيمة اكبر من صفر" | message | row rule `stand_item_row` | high |
| Component unit must be a unit of the component (LOV `ST_ITEM_UNIT, ST_UNIT WHERE GROUP_CODE, ITEM_CODE`) | LOV SQL, "لا يوجد سجل مناظر فى الجداول الأخرى." | `stand_item_row` | high |
| Same component twice: "خطأ تكرار بيانات" | message | `stand_item_row` (+ primary key) | medium |
| Same service twice: "لا يمكن إدخال نفس الخدمة" | `SELECT COUNT(1) FROM ST_STAND_SERVICES WHERE ... AND SERVICE_CODE = :b3`, message | row rule `stand_service_row` (+ primary key) | high |
| Delete refused with movements: "توجد حركات على الصنف لا يمكن حذف الصنف" | `SELECT COUNT(STAND_SERIAL) FROM ST_TRNS_STAND_DET WHERE STAND_ITEM_CODE ...`, `ST_TRNS_DET` count, message | `item_delete` / `unit_item_delete` (ST_STANDS branch) | high |
| Delete removes services, components and units | `DELETE FROM ST_STAND_SERVICES / ST_STAND_ITEMS / ST_ITEM_UNIT WHERE ...` | detail rows deleted by the page before the master | high |
| تكلفة كلية = components (average receipt cost x unit factor x quantity) + services (units x service unit cost); shown only with `USERS.ALLOW_VIEW_COST` ("اظهار التكلفة") | `SELECT AVG(NVL(D.UNIT_COST,0)) FROM ST_TRNS_MAST M, ST_TRNS_DET D, ST_TRNS_TYPE T WHERE ... T.EFFECT = 1 AND D.ITEM_CODE ...`, `SELECT FACTOR FROM ST_ITEM_UNIT ...`, `SELECT NAME_A, NAME_E, UNIT_COST FROM ST_PD_SERVICES`, `SELECT ALLOW_VIEW_COST FROM USERS` | `info` TOTAL_COST (`stand_cost`) | medium (formula assembled from the SQL fragments; no trigger text) |

## Tests (rolled back, `tmp\w3_st\t_rules3_st.py`, 188/188 passed in the final run)

E2 insert on the ST_STANDS page sets `STAND_FLAG = 1` (ST_ITEM leaves it); E10 component quantity 0 refused, component unit not of the
component refused, same service twice refused, stand cost = component + service cost (292.3 on the fixture), save without components
refused. The shared unit rules are covered by E4-E6 (ST_ITEM).

## Open questions

- (wave 3b) Line costs of the legacy tabs (`COST_VALUE`, `TOTAL_ITEM_COST`, `LINE_TOTAL`) are now computed columns; confirm the
  formula (average receipt cost x unit factor x quantity). `SERVICE_TOTAL` (sum) is the TOTAL_COST panel.
- The stand-item code LOV of the legacy lists items with `NVL(HAS_PIECE_NO,0) = 0`; its purpose (search of existing items?) is unclear.

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Group list = transaction groups allowed for the user | `columns.ST_ITEM.ITEM_GROUP_CODE.lov` | LOV `GROUP_STATUS=1` + permission (see rules) |
| Arabic name required on the page | `columns.ST_ITEM.NAME_A.required` | required item (val_item already refused an empty name) |
| Component unit: list of the units of the component (group + item) | `ST_STAND_ITEMS.ITEM_UNIT` (`lov`, `cascade: [ITEM_GROUP_CODE, ITEM_CODE]`) | .fmx LOV `FROM ST_ITEM_UNIT, ST_UNIT WHERE GROUP_CODE = :ST_STAND_ITEMS.ITEM_GROUP_CODE ...` |
| Component name, unit name, cost ("التكلفة" = average receipt cost x unit factor) and line cost ("التكلفة الكلية" = cost x quantity) | `computed.ST_STAND_ITEMS.*` | .fmx SQL `SELECT AVG(NVL(D.UNIT_COST,0)) ... T.EFFECT = 1`, `SELECT FACTOR FROM ST_ITEM_UNIT`, labels |
| Service unit cost and line total (units x cost) | `computed.ST_STAND_SERVICES.UNIT_COST / LINE_TOTAL` | `SELECT NAME_A, NAME_E, UNIT_COST FROM ST_PD_SERVICES`, labels |

Costs follow the legacy right: empty unless `APP_RULES3_ST.can_view_cost` (USERS.ALLOW_VIEW_COST) is 1 (the columns stay visible:
the generator cannot hide a column per user right). Tested with fake rows (the stand tables are empty): cost 14.35 x 2 = 28.70,
service 146.15 x 3 = 438.45. Confidence of the cost formula: medium (assembled from the SQL fragments, as the TOTAL_COST panel).

## Coverage

- Reproduced: filter, `STAND_FLAG` on insert, code / group / unit / component / service checks, save check for components,
  delete checks, total cost with the view-cost right.
- Wave 3b: per-line names and costs of components and services, component unit list. Not reproduced: "سعر الجملة أكبر من سعر التجزئة"
  (information only); the relation message "توجد وحدات قياس مخصصة للإستخدام من قبل هذا الصنف ..احذف تخصيص الوحدات أولا." (the page
  deletes the units with the item, as the .fmx DELETE statements do); leftover texts "كود القسم تم إدخاله من قبل....!" / "كود مكرر من
  قبل" (no SQL uses them). The item delete hook shared with ST_ITEM also removes lots / locations / store rows of the item; assembled
  items normally have none.
- Remaining generator limit: cost columns are emptied, not hidden, for users without the cost right.
