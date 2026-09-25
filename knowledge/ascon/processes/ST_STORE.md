# ST_STORE - أرقام المخازن / Store Numbers

- Registry: system 3 serial 207 (also system 30 serial 12 and system 31 serial 15), menu `CODES_MENU.ST_STORE`.
- Legacy module: `ASCON\ST\FMB\ST_STORE.fmb` (source available, XML `ST\FMB\ST_STORE_fmb.xml`): block `ST_STORE` (one record, block WHERE
  with the store passwords), a hierarchical tree `BLOCK2.TREE1`, buttons ADD_SON / CALC_COST / tree refresh / print.
- APEX: pages 20160 (report) / 20161 (form), `REPORT_FORM` on `ST_STORE`. Override `overrides\ST_STORE.json`: `where`, `key_expr`,
  row rule, page validation, after-save process, `add_columns` (`DEAL_TYPE`, `STORE_LEVEL`, `STORE_STATUS`), read-only
  (`STORE_LEVEL`, `STORE_STATUS`, `STOP_DATE`), hidden `OPEN_BAL_TYPE`, two actions. Package `APP_RULES3_ST` (`app\db\25_rules3_st.sql`);
  compound delete trigger `APP_RULES3_ST_STORE_DEL`.
- The store code is 12 digits split by the store structure (ST_STORE_STRUCT, 6 levels today). A store is either a classification store
  (`STORE_STATUS = 0`, has sub-stores) or a transaction store (`STORE_STATUS = 1`, leaf). Data: 15 stores, 7 leaves; `ST_STORE_PASSWORD` empty.
- The same row rules serve ST_STORE_LOCATIONS (same table, same `APPX_ST_STORE` trigger); the parts that differ check
  `app_rules_st.cur_form`.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| list restricted to the user's stores: password 0 sees all, otherwise stores under a `ST_STORE_PASSWORD` row with `FLAG = 1` (prefix by the level of the granted store) | block WHERE (the commented account-password part is dead code) | `where app_rules3_st.store_allowed(STORE_CODE) = 1` | high |
| the store code must be typed | STORE_CODE WHEN-VALIDATE-ITEM (no numbering) | `key_expr` `code_required(1)`: "يجب إدخال رقم المخزن" | high |
| code right-padded to 12 digits; level from the structure; "خطأ فى رقم المخزن" when a level is empty but a lower one is not; "لابد من إدخال هيكل المخازن أولا" without structure | WHEN-VALIDATE-ITEM, DETECT_STORE_LEVEL | row rule `store_row` (insert: `pad12`, `detect_level`) | high |
| parent must exist: "لا يوجد مخزن رئيسى لهذا الرقم" (PRE-INSERT: "لايوجد مخزن رئيسى لهذا المخزن") | GET_STORE_PARENT, STORE_FOUND | page validation `val_store` | high |
| parent without transactions: "تم عمل حركات على المخزن الرئيسى" | TRANSACTIONS_FOUND_FOR (`ST_TRNS_MAST.STORE_CODE`) | `val_store` | high |
| duplicate: "يوجد مخزن بنفس الرقم بالملف" | STORE_FOUND | `val_store` (code padded before the check) | high |
| a new store is a transaction store (`STORE_STATUS = 1`); its parent becomes a classification store (`STORE_STATUS = 0`) | WHEN-VALIDATE-ITEM, POST-INSERT | row rule (status) + after-save `store_after` (CREATE) | high |
| stop date = SYSDATE when stopped, else empty; unticking the stop flag clears the reason | PRE-INSERT / PRE-UPDATE, STOP_FLAG WHEN-CHECKBOX-CHANGED | row rule `store_row`; `STOP_DATE` read-only | high |
| a change of cash / stores / cost / sales account (`ACCOUNT_NUMBER1..4`) or cost centre is copied to all sub-stores (same code prefix up to the store's level) | POST-CHANGE of each item: `UPDATE ST_STORE SET ... WHERE SUBSTR(STORE_CODE,1,end_pos(level)) = prefix` | row rule records the changes, `store_after` (SAVE) updates the sub-stores | high |
| a change of `COST_CODE2` copies `COST_CODE` (not `COST_CODE2`) to the sub-stores | COST_CODE2 POST-CHANGE (`SET COST_CODE = :COST_CODE`) - legacy bug, reproduced as is | `store_after` | high |
| stopping a store stops all sub-stores with reason "<reason>(المخزن الرئيسى <code>)"; un-stopping clears flag, date and reason of the sub-stores | STOP_FLAG POST-CHANGE | `store_after`; on this screen the sub-stores' `STOP_DATE` is not set (ST_STORE_LOCATIONS sets it) | high |
| delete refused when the store has items: "لايمكنك حذف هذا السجل حيث أنه تم إجراء حركات عليه" | KEY-DELREC (`ST_STORE_ITEM`) | `APP_RULES3_ST_STORE_DEL` before each row (-20177) | high |
| delete refused for a classification store: "يوجد مخازن فرعية لهذا المخزن لذلك لايمكنك الحذف" | KEY-DELREC (`STORE_STATUS = 0`) | same trigger | high |
| after deleting the last sub-store the parent becomes a transaction store again | POST-DELETE, STORE_HAS_BROTHERS | same trigger, after statement (`store_delete_done`) | high |
| dealing type list 1 جملة / 2 مفرق / 3 تكلفة | WHEN-NEW-FORM-INSTANCE list elements | `DEAL_TYPE` shown as a number with the values in its label (no static-list override) | high |
| `OPEN_BAL_TYPE` and button `PUSH_BUTTON111` only for customer `SDI` ("هذه القيمه خاصه بمخازن الحركات") | `:global.customer_code <> 'SDI'` hides them | `OPEN_BAL_TYPE` hidden | high |

## Buttons

| Legacy button | Evidence | APEX | Confidence |
|---|---|---|---|
| ADD_SON "إضافة مخزن فرعي": refused without a store (" لا يمكن تكوين مخازن أبن بلا مخزن أب ") or when the store has transactions ("لا يمكن إضافة مخازن فرعية بينما هناك حركات مسجلة"); next child code by GET_NEXT_ACCOUNT (highest existing code at the next level under the store + 1, padded to 12) | trigger text | action `ADD_SON` -> `add_child_store(:PAGE_ROWID, NAME_A, NAME_E, STORE_TYPE)`: creates the child with the next code, level + 1, leaf, the parent's deal type and the chosen type (default the parent's), sets the parent to classification, message "تم إضافة المخزن الفرعي رقم ..." | high (difference: the legacy opened a new record with the code and let the user type the rest; APEX asks for the names / type first, the other fields are edited afterwards) |
| CALC_COST "حساب التكلفة الكلية": sum of `GET_BALANCE_COST` of all items of a transaction store; 0 for a classification store | CALC_COST, GET_SUM_BAL_COST | action `CALC_COST` -> `store_cost_action`: message "التكلفة الكلية للمخزن: ..." | high |
| Print (toolbar) | `PRINT_BTN`: report `ST_STORE.RDF`, parameters `FROM_STORE_CODE` = `TO_STORE_CODE` = current store, `comp_CODE` = `:global.company_code`, `Lang` = `:global.lang`; report query: `STORE_CODE`, `DECODE(:LANG,'A',NAME_A,NAME_E)` from `ST_STORE` between the two codes, order by code, plus `company_logo` from `COMPANY` | not wired - the print layout is the main session's job | high |
| tree refresh `PUSH_BUTTON65`, tree navigation | Forms hierarchical tree | not reproduced (navigation only; the report page lists stores by code) | - |

## Tests (rolled back, `tmp\w3_st\t_rules3_st.py`, 188/188 passed in the final run)

C1 levels (101010101001 -> 6, 101010000000 -> 3), illegal code 100010000000 refused; C2 duplicate with a short code, missing parent,
valid new code, unchanged code on save; C3 insert pads 1010103 -> 101010300000, level 4, leaf, no stop date; C4 account 2 and stop
flag of 101010101000 copied to its 4 sub-stores with "(المخزن الرئيسى 101010101000)", other stores untouched; C5 ADD_SON under
101010202000 -> 101010202001 (level 6, leaf, type / deal type of the parent), parent becomes classification, message; refusal on a
store with transactions; C6 delete of the new child restores the parent's leaf status; delete refused with items / with sub-stores;
C7 total cost of 101010101001 = sum of the item costs (3,985,811.10), 0 for a classification store, CALC_COST message; C8 empty code
refused; A1 English message with `G_LANG = en`.

## Open questions

- `PUSH_BUTTON111` (visible only for customer SDI) - its action is not in the evidence; irrelevant for this customer.
- The item-level "Field Must Be Entered" on `MAINAREA_ID` / `SUBAREA_ID` (English-only Forms message when the user clears the field)
  is not reproduced; all 15 stores have both values. Should they become required?

## Wave 3b (new generator keys)

Evidence: `ST\FMB\ST_STORE_fmb.xml` (items, record groups ACCOUNT, COST_CENTERS, COST_CENTERS2, MAINAREA, MAIN_SUB_AREA; the
WHEN-NEW-FORM-INSTANCE list elements and the POST-QUERY texts).

| Change | Key | Evidence |
|---|---|---|
| Store code read-only after insert and required | `STORE_CODE` | `UpdateAllowed="false"`, `Required="true"` |
| Arabic name required | `NAME_A.required` | `Required="true"` |
| Dealing type list جملة 1 / مفرق 2 / تكلفة 3 | `DEAL_TYPE.static` | `ADD_LIST_ELEMENT('ST_STORE.DEAL_TYPE_DUMMY', ...)` |
| Store status shown as مخزن حركــات (1) / مخزن تصنيـف (0) (read-only) | `STORE_STATUS.static` | POST-QUERY `:LEAF_DESC` |
| Accounts 1-4: active accounts of the user's account permissions | `ACCOUNT_NUMBER1..4.lov` | RG ACCOUNT (`ACCOUNT_STATUS=1`, `AC_PASSWORD_MASTER`) |
| Cost centres 1 / 2: active, permission-filtered | `COST_CODE`, `COST_CODE2` `lov` | RG COST_CENTERS / COST_CENTERS2 |
| Main area list and sub-area list of the chosen main area; both required | `MAINAREA_ID`, `SUBAREA_ID` (`lov`, `cascade: MAINAREA_ID`, `required`) | MAINAREA_LOV, MAIN_SUB_AREA `where d.main_id = :mainarea_id`; `Required="true"`; all 15 stores filled |
| Department required | `CATEGORY_TYPE_CODE.required` | `Required="true"`; all stores filled |

All list queries run on the build copy (`sqlcheck.py`, the sub-area list with main area 11).

## Coverage

- Reproduced: all rules and the ADD_SON / CALC_COST buttons above.
- Not reproduced:
  - the store tree and its refresh button, PRE-QUERY padding / LIKE search (Forms query mode; the report page has its own search);
  - POST-QUERY display lookups of the level name (the level number is shown); account / cost-centre / area names are shown by their
    lists (wave 3b), the status by its list ("مخزن حركــات / مخزن تصنيـف");
  - the print button (documented above, layout by the main session);
  - `GLN`, `RSD_USER`, `RSD_PASSWORD` are shown as plain columns (RSD is deferred); suggestion: hide `RSD_PASSWORD`.
- The row rule becomes active in `APPX_ST_STORE` at the next build; validation, after-save, actions and the delete trigger are in place.
