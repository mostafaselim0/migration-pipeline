# ST_ADJUST_OUT — stocktaking adjustment, issue (تسوية جرد صادر - سند صرف)

System 3 serial 114 (TAKINK_ADJ_IN_MENU.TAKINK_ADJ_OUT). Source: compiled form only (`ST\FMB\ST_adjust_out.fmx`, evidence
`app\legacy\evidence\ST_ADJUST_OUT.md`). Deliverable: **(a) AUTO + rules** (`overrides\ST_ADJUST_OUT.json`, `APP_RULES_ST`).

## Purpose and data

Manual stock decrease (samples, damaged goods, lot changes). Header ST_TRNS_MAST with counter account ACCOUNT_NUMBER1, lines
ST_TRNS_DET per lot.

Types (block WHERE of the .fmx): `TRNS_TYPE_CODE IN (SELECT .. WHERE T.EFFECT IN (2, 7) AND T.TRNS_TYPE IN (7, 40)) AND
NVL(DELETE_FLAG,0) = 0 AND (:1 = 0 OR ..ST_TRNSTYPE_PASSWORD..)`. Existing types: EFFECT 2 / TRNS_TYPE 7 only (EFFECT 7 or
TRNS_TYPE 40 not defined). Data: 11301 (68), 11302 (18), 11303 (4), 11701 (4, three from ST_AUTO_ADJ), 901/902/903
(AUTO_TRNS = 1: lot formation); 12601 / 13601 / 8888888 unused.

## Rules implemented

| # | Rule | Where | Evidence |
|---|------|-------|----------|
| 1 | List and type filter EFFECT (2,7) / TRNS_TYPE (7,40) + group (the LOV has no AUTO_TRNS condition; the default prefers manual types → 11301) | `rules.where`, `val_trns`, `default_type` | block WHERE, TRNS_TYPE LOV |
| 2 | Defaults: store = type store, flags 0, DESC_A = type description, ACCOUNT_NUMBER1 = ST_STORE.ACCOUNT_NUMBER1 | `rules.defaults`, `mast_row` | `SELECT STORE_CODE FROM ST_TRNS_TYPE ..`, `SELECT ACCOUNT_NUMBER1 FROM ST_STORE ..` |
| 3 | Account required for types with STACLNK ACCOUNT_NO_TYPE = 6 (11301/11302/11303), active in AC_MASTER | `val_trns` | `SELECT COUNT(1) FROM STACLNK WHERE TRNS_TYPE_CODE = :b1 AND ACCOUNT_NO_TYPE = 6`; data: all recent 113xx documents have an account |
| 4 | TRNS_SERIAL MAX + 1 per type; DOC_NO = MAX(DOC_NO) + 1 per type and store (not deleted), first = store prefix ‖ 000001 | APPX key, `next_doc_no` | `SELECT NVL(MAX(DOC_NO),0)+1 FROM ST_TRNS_MAST TM WHERE TM.TRNS_TYPE_CODE = :b1 AND TM.STORE_CODE = :b2 AND NVL(DELETE_FLAG,0) = 0`; data 1001000001… |
| 5 | CHECK_DATE + AC_BASIC open period; store active / allowed; posted read-only | `val_trns`, triggers | CHECK_DATE, "لا يمكن حذف حركات مرحلة" |
| 6 | Lines: item exists and not stopped ("صنف غير موجود"), group derived, basic unit, BASIC_QTY, quantity > 0 | `det_row` | `SELECT DECODE(PEICE_NO ..) , IU.UNIT_CODE FROM ST_ITEM IT, ST_ITEM_UNIT IU WHERE NVL(IT.STOP_FLAG,0) = 0 ..` |
| 7 | Lot: must belong to the item; empty → earliest-expiry lot with balance ("هذا الصنف ليس له رصيد" when none) | `det_row` → `fefo_lot` | `.. AND EXPIRE_DATE = (SELECT MIN(EXPIRE_DATE) ..) AND GET_BALANCE_CONFG(..) / :b8 > 0` |
| 8 | Lot balance at the position ≥ quantity and no later transaction negative (unless NEG_SALE_BALANCE = 1); re-checked for the whole document at SAVE (date changes) | `det_row`, `after_trns` | "رصيــد الصنف فى هذا التاريخ لا يسمــح", "راجع مجموع الكميات المصروفة من هذا الصنف داخل هذه الحركة", "الرصيد لا يسمح / توجد حركة تالية لهذه الحركة تتعارض معها" |
| 9 | UNIT_COST = lot average cost (GET_UNIT_COST_CONFG), UNIT_PRICE = cost × factor when empty, COST_FLAG 1 | `det_row` | LOV column `GET_UNIT_COST_CONFG(..) * :NDB_FACTOR T_COST`; data 901 lines UNIT_PRICE = UNIT_COST |
| 10 | SINGLE_ITEM / TRNS_MAX_ITEMS | `det_row` | messages |
| 11 | Lines required at SAVE; document delete = **soft delete** (wave 3, W1); type / store fixed once lines exist | `after_trns`, `rules.soft_delete`, `val_trns` | "لا يمكن حفظ الحركة بدون تفاصيل", "لا يمكن إلغاء السجل الحالى إلا بعد إلغاء التفاصيل التابعة له" |

## Wave 3: soft delete, question, displays (APP_ACT_ST `ado_*`)

Installation code: `:GLOBAL.CUSTOMER_CODE` = `SELECT CUSTOMER_CODE FROM CUSTOMER_PAR` (Sysmenu.fmx) is NULL here (CUSTOMER_PAR empty in
production, `_discovery\05_tables_rows.csv`).

| # | Legacy behaviour | APEX | Evidence | Confidence |
|---|---|---|---|---|
| W1 | Master KEY-DELREC: posted → "لا يمكن حذف حركات مرحلة"; delete right of FILE_PASSWORD ("لا توجد صلاحية للإلغاء لهذا المستخدم" = the APEX delete authorisation); lines cleared, `:ST_TRNS_MAST.DELETE_FLAG := 1`, commit (an issue can always be removed: later balances only rise) | `rules.soft_delete` (lines keep, check `ado_delete_check`) | trigger symbols `:POST_FLAG`, `:global.delete_flag`, `:PARAMETER.MASTER_DELETE`, `:ST_TRNS_MAST.DELETE_FLAG`; data: 9 deleted 11301 / 11302 / 11701 documents kept their 12 lines with DELETE_FLAG 1 | high |
| W2 | DOC_NO: `SELECT COUNT(1) FROM ST_TRNS_MAST WHERE TRNS_TYPE_CODE = :b1 AND DOC_NO = :b2` with ST_BASIC.DOC_REPEAT → continue question | `warnings` → `ado_doc_warn` (DOC_REPEAT = 0: the page validation refuses) | .fmx SQL, identifiers DOC_REP / DOC_REPEAT | medium |
| W3 | COST_CODE displays "حد اقصى" (AC_COST_CENTERS.MAX_LIMIT) and "رصيد" (GET_COST_BAL = `SELECT NVL(SUM(VALUE),0) FROM AC_YEARLY_TRN_DET WHERE COST_CODE = :b1 AND (ENTRY_DATE <= :b2 OR :b2 IS NULL)`, date = TRNS_DATE) | `info` COST_LIMIT / COST_BAL → `ado_cost_center` | COST_CODE trigger (symbols `:COST_BAL`, `:ST_TRNS_MAST.COST_MAX_LIMIT`), program unit GET_COST_BAL, labels | high |
| W4 | "لقد تجاوز مركز التكلفة الحد الاقصى": inside the same COST_CODE trigger, guarded by `:GLOBAL.CUSTOMER_CODE` and the literal 'ZED' right before the message (fmx offsets 96481 / 98271-98279) — an installation-specific branch; the code is NULL here, so the legacy never showed it. Also no cost centre has MAX_LIMIT in the data | **not reproduced** (other installation) | fmx strings | high |
| W5 | Per-line REORDER_LIMIT "حد الطلب" (`SELECT REORDER_LIMIT FROM ST_ITEM ..`) | `info` REORDER → `ado_reorder` ("item: limit" for the lines whose item has a reorder limit; none set in the data today) | .fmx SQL, label | medium (one list instead of a column per line) |
| W6 | SUM_LINE_TOTAL "الاجمالى" (LINE_TOTAL from QUANTITY and UNIT_PRICE) | `info` TOTAL → `ado_total` (Σ QUANTITY × UNIT_PRICE) | fmx trigger symbols `:ST_TRNS_DET.LINE_TOTAL":QUANTITY":UNIT_PRICE"` | medium |

## Tests (page 20091, rolled back)

Wave 2: A1 account required; A2 valid header; A3 other screen's type refused; A4 future date; A5 outside AC_BASIC period; A5b inactive
store; A6 DOC_NO / DESC_A / flags; A7 line fully derived (group, unit, FEFO lot 126, basic qty, cost, price, cost flag) and cost
row written by ST_TRNS_DET_C_IN; A8/A9 above lot balance refused (insert/update); A10 wrong lot, unknown item, zero quantity;
A12 type/store change with lines refused; A13 posted document read-only (validation, new line, line delete, document delete);
A14 delete cascades lines and cost rows. Wave 3 (`tmp\w3_sales\f4\t_f4.py`): F1 total; F2 cost centre balance and max limit; F3 reorder
limit; F4 duplicate DOC_NO question; F5 soft delete (lines kept, DELETE_FLAG 1), posted refused.

## Confidence: **medium-high** (compiled form: rule conditions from the SQL and messages; trigger order inferred)

## Human verification

1. Are the AUTO_TRNS types 901-903 still entered manually here (they appear in the list)?
2. The cost-centre maximum message exists only for installation ZED; confirm it is not wanted here.

## Wave 3b (new generator keys)

| Change | Key | Evidence |
|---|---|---|
| Per line: item name, alternative number "الرقم البديل", lot expiry, "رصيد المخزن قبل الحركة" (lot balance before the line / factor), "بعد الحركة" (before - quantity), "تكلفة الصنف ( الريال )" (lot average cost x factor), "حد الطلب" (item reorder limit), "الاجمالى" (qty x price) | `computed.ST_TRNS_DET.*` | display items and labels (STORE_BALANCE, STORE_BALANCE_AFTER, STORE_COST, REORDER_LIMIT, PEICE_NO, LINE_TOTAL); formulas as ST_ADJUST_IN.fmb (same template) |
| The wave-3 workaround `info` REORDER (a list "item: limit" above the lines) is replaced by the per-line column | `info` entry removed | - |
| Lot list of the line's item (lot id - lot number - expiry), refreshed when the item changes | `ITEM_CONFG_ID` `lov` + `cascade: ITEM_CODE` | legacy lot LOV (ITEM_CONFG_LOV / CONFG); the row rule still checks the lot and its balance |
| Button "ترحيل السند" opens the posting screen ST_POSTING_CPOSTING with the document's type, serial and date filled in (from / to) | `links` | POST_BUT: `CALL_FORM(... 'ST_POSTING_CPOSTING' ...)` with TRN_CODE / TRN_SER / TRN_DATE |

Costs are empty unless (USERS.ALLOW_VIEW_COST = 1 and ST_BASIC.SHOW_COST = 1) or the user's group is 0 (legacy GET_USER_SEC); the column itself stays visible (the generator cannot hide a column per user right). The legacy button chose post (FILTER 1) or cancel (FILTER 2) from POST_FLAG; the link cannot set a value that depends on the record, so the operation stays the posting page's default (post) and the user switches it to cancel when needed. Tested on the build copy: every list query and computed expression runs (`tmp\w3b_st\sqlcheck.py`, lot list with item 101010006); the cost / balance gates checked in an APEX session (`t_gates.py`, rolled back, session removed). Confidence of the before / after formulas: medium (the .fmx shows the items and GET_BALANCE_CONFG, not
the exact assignment).

## Coverage

Reproduced: rules 1-11 and W1-W3, W5-W6 (types, account, numbering, FEFO lot and balance checks, cost / price, soft delete, duplicate
DOC_NO question, cost-centre limit and balance, reorder limit and total displays).

Not reproduced, on purpose:
- W4 cost-centre maximum message: branch of installation ZED (the installation code is NULL here).
- INSERT_SALE_CNFG (ST_BASIC = 1: manual lot choice in the legacy LOV); the page keeps proposing the earliest-expiry lot with stock when
  the lot is left empty (wave 2 decision, same as the sales invoice).
- Store-unit LOV variants; printing (prints agent); alerts. Wave 3b added the per-line displays and the posting button.
