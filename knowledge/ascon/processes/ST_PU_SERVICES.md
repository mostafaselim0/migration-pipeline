# ST_PU_SERVICES — ارقام خدمات الشراء / Purchase Service Codes (system 30, serial 39)

Deliverable: **business rules on the generated screen** — `overrides/ST_PU_SERVICES.json` (AUTO, row rule, SERVICE_LEVEL
shown read-only), `APP_RULES3_PR` (`service_*`), compound trigger `APP_R3_ST_PU_SERVICES_CT` (parent LEAF flag and
delete checks, which a row trigger cannot do on its own table). Page 50100. Confidence: **medium-high**.

## Purpose and tables
Chart of purchase services `ST_PU_SERVICES` (12-digit SERVICE_CODE, names, unit, unit cost, account, SERVICE_LEVEL, LEAF),
structured by the levels of `ST_CHART_SERVICES` (CHR_STRU_LEVEL / START / END / LENGTH). Services are used by the request,
order and lot service lines (`ST_ITEM_REQ_SRVC`, `PR_ORDER_SRVC_REQUEST`, `ST_TRNS_SRVC_REQUEST`, `PR_ORDER_SRVC`,
`PR_REQ_SRVC`, `PR_INCOME_LOT_SRVC`). **Data: `ST_CHART_SERVICES` and `ST_PU_SERVICES` are empty** — the legacy form
refuses every insert until the structure exists, and so does APEX (rule 1).

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Structure required — "لابد من إدخال هيكل الخدمات أولا" | row rule `service_row` | `SELECT COUNT(1) FROM ST_CHART_SERVICES` + message | high |
| 2 | Code of 12 digits, level derived from the structure (first level after whose CHR_STRU_END the code has only zeros) — "خطأ فى رقم الخدمة", "مستوى الخدمة غير معروف" | row rule → `service_level` | `SELECT CHR_STRU_END FROM ST_CHART_SERVICES WHERE CHR_STRU_LEVEL = :b1`, messages | medium |
| 3 | No duplicate — "يوجد خدمة بنفس الرقم بالملف" | row rule | `SELECT COUNT(1) FROM ST_PU_SERVICES WHERE SERVICE_CODE = :b1` | high |
| 4 | Parent (code cut after the previous level) must exist — "لا يوجد خدمة رئيسى لهذا الرقم" | row rule → `service_parent` | `SELECT SERVICE_CODE FROM ST_PU_SERVICES WHERE RPAD(SUBSTR(TO_CHAR(SERVICE_CODE),1,:b1),12,'0') = :b2 AND SERVICE_LEVEL = :b3` | high |
| 5 | No child under a parent used in transactions — "تم عمل حركات على الخدمة الرئيسى" | row rule → `service_used` | usage SELECTs on the six service tables + message | high |
| 6 | New service is a leaf; its parent becomes LEAF = 0 | compound trigger (after statement) | `UPDATE ST_PU_SERVICES SET LEAF = 0 WHERE SERVICE_CODE = :b1` | high |
| 7 | Delete refused for a used service — "لايمكن حذف خدمه تم عمل حركات عليها" | compound trigger (before row) | usage SELECTs + message | high |
| 8 | Delete refused while sub-services exist — "يوجد خدمات فرعية لهذه الخدمة لذلك لايمكنك الحذف" | compound trigger (after statement) | message; tree query | high |
| 9 | Parent LEAF = 1 again when its last child is deleted | compound trigger | `UPDATE ST_PU_SERVICES SET LEAF = 1 WHERE SERVICE_CODE = :b1` | high |
| 10 | Account from the detail accounts (legacy LOV `ACCOUNT_STATUS = 1`) | row rule | account LOV SQL | high |

## Buttons / features
* "عرض الشجرة" (tree view of the chart) and "اضافة ابن" (add child: proposes `RPAD(SUBSTR(MAX(SERVICE_CODE),1,end)+1,12,0)`)
  — **not reproduced**: Forms hierarchical-tree navigation; the APEX grid is searched / sorted by code. The proposed child code
  would need a page button that fills the code field (no mechanism for a "fill item" button; users type the code).

## Open questions
* "لا توجد صلاحية للخدمة" (no permission for the service): the condition is not visible in the .fmx strings; not reproduced.

## Tests (`tmp\w3_prsa\t_w3prsa.py`, structure written as a fixture inside the rolled-back transaction)
SV1 structure required · SV2 level 1 service, leaf · SV3 level 2 · SV4 parent LEAF 0 · SV5 no parent · SV6 wrong length ·
SV7 duplicate · SV8 parent with children not deleted · SV9 used service not deleted · SV10 no child under a used parent ·
SV11 parent LEAF 1 again · SV12 non-detail account refused. All PASS.

## Wave 3b
* `rules.columns` `ST_PU_SERVICES.ACCOUNT_NO`: the legacy account LOV as a popup list (detail accounts `ACCOUNT_STATUS = 1`,
  limited to `AC_PASSWORD_MASTER` for a restricted user; .fmx SQL). The row rule still refuses other accounts.
* `rules.computed` `ST_PU_SERVICES.SERVICE_LEVEL_DESC` "بيان المستوى": the legacy display item SERVICE_LEVEL_DESC =
  `ST_CHART_SERVICES.CHR_STRU_DESCA` of the service level (.fmx: `SELECT DECODE(:b1,'A',CHR_STRU_DESCA,CHR_STRU_DESCE) FROM
  ST_CHART_SERVICES WHERE CHR_STRU_LEVEL = :b2`).
* Not covered by the new keys: the tree view and the "add child" proposal (a button that fills the code field).
* Check: `check_forms.py ST_PU_SERVICES` (list run as an unrestricted and as a restricted user; computed column run).

## Coverage
Reproduced: structure / level / parent / duplicate / usage rules, LEAF maintenance, delete restrictions, account list (legacy
LOV since wave 3b), level description.
Not reproduced: tree view and "add child" proposal (Forms navigation; no generator mechanism fills a field from a button), the
permission message of unknown condition (question), delete confirmation alert, toolbar / translation library code.
