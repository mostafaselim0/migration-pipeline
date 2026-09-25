# AR_SALESMAN_COLL_PAY - ربط حركات التحصيلات الخارجية بالصناديق / Salesmen collections linked to cash boxes and bank deposits

- Registry: system 4 ("تسكين سدادات العملاء بالصناديق"). Legacy `ASCON\AR\FMB\AR_SALESMAN_COLL_PAY.fmx` (no .fmb, no labels; evidence
  from the compiled strings, 2019 version). Tables `AR_SLS_COLL_MAST / _DET / _TRNSFER` empty (unused so far).
- APEX: corrected from a grid on `AR_SALESMAN_PASSWORD` (name match) to `MASTER_DETAIL`: header `AR_SLS_COLL_MAST` with
  `AR_SLS_COLL_DET` (the legacy has two blocks on it: `AR_SLS_COLL_DET` with `NVL(AR_FLAG,0) = 1` = customers' payments and
  `AR_SLS_COLL_DET2` with `NVL(AR_FLAG,0) = 0` = cash-box receipts; APEX shows one grid with the AR_FLAG column, see Coverage) and
  `AR_SLS_COLL_TRNSFER` (bank deposits), joined on `SERIAL, SALESMAN_ID` (the form deletes both detail tables with the header).
  Rules and buttons in `APP_RULES3_AR`.

## Rules and buttons

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| list: salesmen of the user's group (`AR_SALESMAN_PASSWORD`); salesman LOV restricted the same way | block WHERE, LOV SQL | list `where`, row rule `coll_mast_row` | high |
| header `SERIAL = NVL(MAX(SERIAL),0)+1 WHERE SALESMAN_ID`; `DOC_NO = NVL(MAX(TO_NUMBER(DOC_NO)),0)+1 WHERE SALESMAN_ID`; NOTES "توجيه سندات تحصيل من مناديب على سندات القبض من امناء الصناديق برقم مستند -" + DOC_NO; date defaults to today | SQL, strings | key_expr `next_coll_serial`, row rule, default | high |
| CHECK_DATE on the date (not after today, not before the minimum date) | trigger calling CHECK_DATE | row rule | high |
| the date can be changed only when the group has `PASSWORD.CHANGE_DATE = 1` (the form disables `AR_SLS_COLL_MAST.TRNS_DATE` otherwise) | PRE-FORM SQL + item name | row rule: "غير مسموح لمجموعتك بتغيير تاريخ الحركة" | medium (the legacy disables the item; APEX refuses another date) |
| customers' payments (AR_FLAG 1): LOV AR_LOV = the salesman's `AR_MAINTRNS` of types `EFFECT = 1 AND MOBILE_TRNS = 1`, `LINK_FLAG 0`, `PAY_FLAG 0`, `CASH_FLAG = 2`, up to the document date; value / document no. from the payment (LKP_DET) | LOV SQL, LKP_DET SQL | row rule `coll_det_row` | high |
| "تم ادخال الحركة من قبل": a payment chosen in another line (`CHOOSE_FLAG = 1`); line `DET_SERIAL = NVL(MAX)+1` per salesman / serial / AR_FLAG | PRE-INSERT SQL | compound trigger `APP_RULES3_AR_COLLDET_AIU` -> `coll_det_check`; generated key | high |
| choosing a payment sets `AR_MAINTRNS.PAY_FLAG` | DB trigger `AR_SLS_COLL_DET_TRG` (kept) | database | high |
| cash-box receipts (AR_FLAG 0): LOV RP_LOV = the salesman's `RP_TRNS_MAST` of types `EFFECT = 1 AND CASH_COL_FLAG = 1`, box code starting with 1, not deleted, not used by other documents (`GET_RP_USED_OTHERS_COUNT = 0`), up to the document date; "لقد تعديت المبلغ المتبقى لهذا السند" (`GET_RESIDUAL_RP_TRNS`); "القيمة اقل من او تساوى الصفر" | LOV SQL, item / PRE-INSERT triggers | row rule + compound trigger | high |
| bank deposits: LOV MOB_LOV = the salesman's approved (`TRNS_STATUS = 1`) `MOB_DEPOSITE_TRNS` up to the date with a remaining amount; date / bank / branch / pay type from the deposit; "لقد تعديت المبلغ المتبقى لهذا السند" (`GET_RESIDUAL_MOB_TRNS`); "القيمة اقل من او تساوى الصفر"; `DET_SERIAL` per document | LOV SQL, triggers | row rule `coll_trf_row`, compound trigger `APP_RULES3_AR_COLLTRF_AIU`; generated key | high |
| "الحركة غير متوازنة": chosen payments = receipts + deposits (CHECK_DB_BALANCE: `V_TOTAL_AR`, `V_TOTAL_RP`, `V_TOTAL_TRNSFER`) | the three SUM statements, message | `after_save` `coll_balance` | medium (formula reconstructed from the three totals) |
| button "انزال سدادات العملاء" / "انزال سندات القبض" / "انزال الايداعات البنكية": the LOV rows (receipts / deposits with their remaining amount); refused with "تم حفظ الحركة لايمكن التعديل" when saved lines of that kind exist | the three button triggers (cursor + count SQL) | actions `LOAD_AR` / `LOAD_RP` / `LOAD_MOB` | high |
| totals "إجمالى قيمة الحركات المختارة", "إجمالى عدد الحركات المختارة", receipts, deposits | display items | `info` panel | - |

## Tests (rolled back, 25 checks passed)

Test data inside the transaction (type 201 as mobile type, a collection receipt type / receipt, an approved deposit of salesman
100). Salesman / future date refused; group 102 (no CHANGE_DATE) refused another date, today accepted; serial, DOC_NO and NOTES;
loading brings the 43 payments (not chosen) and refuses a second load; choosing marks the payment paid; a payment of another
salesman refused; the same payment in a second document refused; receipt / deposit loads with remaining amounts, second loads
refused, over-residual and zero / negative values refused; unbalanced document refused, balanced accepted; deleting a chosen line
frees the payment (PAY_FLAG 0), which can then be chosen in the second document.

## Coverage

- Reproduced: the document, the LOV restrictions, the checks, the three load buttons and the balance check.
- Not reproduced: button "choose all" (P17: toggles CHOOSE_FLAG of every loaded payment; tick the lines in the grid); the customer /
  area / branch / bank names (display items; LOV display); print (none found besides the generic report procedure).
- Lists (wave-3b): salesmen of the group on the header (fixed after insert); AR_FLAG as a list (سداد عميل / سند قبض), CHOOSE_FLAG as a
  check box.
- Differences (documented): one grid for both kinds of lines (AR_FLAG column) because the generator has no per-detail WHERE (two
  grids on the same table); loaded payments start not chosen (`CHOOSE_FLAG 0`: the button does not set the flag); the delete of a
  chosen line frees the payment (`PAY_FLAG 0`): the DB trigger `AR_SLS_COLL_DET_TRG` intends this but uses `:NEW` in its DELETING
  branch; "تم ادخال الحركة من قبل" is also checked when an existing line is ticked (the legacy checks on insert only).
- Questions: confirm the balance formula (payments = receipts + deposits) and whether the loaded payments should start chosen.
