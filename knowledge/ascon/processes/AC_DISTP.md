# AC_DISTP - توزيع مراكز التكلفة / Cost Centers Distributions

- Registry: system 1 serial 74 (SYSTEM_MENU.ITEM205, order 4006). APEX list 10240, distribution page 10241, print 10242.
- Legacy module: `ASCON\AC\FMB\AC_DISTP.fmb` (source available): header AC_DISTP, source cost centres AC_DISTP_FROM, target cost
  centres AC_DISTP_DET.
- **Deliverable: generated master-detail kept (`AUTO`) + rules + 3 buttons**, override `app\legacy\overrides\AC_DISTP.json`, PL/SQL
  `APP_RULES3_GL`, delete hooks `APP_RULES3_GL_DISTP_BD` / `APP_RULES3_GL_DISTPD_BD`.
- **Confidence: high** (trigger source).

## Rules and buttons

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | Numbering: DIS_SERIAL = MAX + 1; source / target lines DET_SERIAL = MAX + 1 per distribution | PRE-INSERT of the three blocks | generated max+1 (header, source); key_expr `next_distp_det_serial` (target: its PK ends with COST_CODE) |
| 2 | Account type: "اختيار" (0, an account) or "مصروف" (1: every expense sub account, account cleared) | ACCOUNT_TYPE(_LIST) WHEN-VALIDATE-ITEM | column added (default 0); row rule clears the account for type 1 |
| 3 | Source line balance = posted lines + opening balance of the account and the cost centre up to the distribution date (type 1: all sub accounts whose first digit equals AC_BASIC.OUTCOME1_ACCT); zero refused ("رصيد مركذ التكلفة لهذا الحساب صفر") | GET_BAL, COST_CODE WHEN-VALIDATE-ITEM | row rule `distp_from_row` (insert or cost centre change); ACC_VALUE read-only |
| 4 | Target line value = total source balance x percentage / 100, percentage = value x 100 / total (the item changed drives the other) | DET_PRCNT / DET_VAL WHEN-VALIDATE-ITEM | row rule `distp_det_row` |
| 5 | Target values must total the source balances ("لا بد ان يكون مجموع مبالغ المراكز الخدمية مساوي لمبلغ مركز التكلفة الإيرادية"); percentages must total 100 ("لا بد ان يكون مجموع النسب مساوي 100") | PRE-INSERT / PRE-UPDATE / PRE-DELETE of the lines | after_save `distp_after_save`; the percentage message only when every line has a percentage and the values do not match (DET_PRCNT is NUMBER(6,0): stored percentages are whole numbers) |
| 6 | "نسب ثابتة": 100 / number of target lines on each (the last takes the rest), value = total / number ("لا بد من إدخال مراكز التكلفة الإيرادية أولا") | DIST_BUT | action EQUAL |
| 7 | "ترحيل السجل": needs source and target lines ("لا بد من إدخال مراكز التكلفة المصدر أولا" / "... التي سيوزع عليها أولا"), AC_BASIC.DISTP_ENTRY ("لا بد من تعريف رقم حركة التوزيع في مؤشرات النظام"), date after CLOSE_DATE ("لا يمكن ترحيل الحركة لأنها تقع فى فترة مقفلة"); writes a posted entry (AC_YEARLY_TRN, year of the date, number GET_SERIAL: yearly journal LAST_SERIAL + 1, monthly journal MM + next number of the month, LAST_SERIAL updated) with one line per source cost centre (-balance) and one per target (share, sign of the balance), all on the distribution account; POST_FLAG = 1 and the entry key on the header ("تم ترحيل حركة التوزيع بنجاح") | POST WHEN-BUTTON-PRESSED, GET_SERIAL | action POST (`distp_post`) |
| 8 | "إلغاء الترحيل": date after CLOSE_DATE ("لا يمكن إلغاء ترحيل الحركة لأنها تقع فى فترة مقفلة"); deletes the entry from the daily and posted tables; header reset ("تم إلغاء ترحيل حركة التوزيع بنجاح") | UNPOST WHEN-BUTTON-PRESSED | action UNPOST (`distp_unpost`) |
| 9 | A posted distribution cannot be deleted and its target lines cannot be changed | WHEN-NEW-RECORD-INSTANCE / SHOW_HIDE (delete / insert / update off) | delete hooks and the target-line row rule (new texts) |

## Tests (section M of `tmp\w3_gl\gl\t_gl.py`, 23 checks)

Existing distribution 2 (6000 = 3 x 2000) passes; changed value refused; percentage 50 -> value 3000; percentage message when all
lines have percentages totalling 110; equal ratios (33 each stored, 2000 each); posting of distribution 2 refused (closed period);
new distribution 3 (320101001001, 15/06/2026): zero-balance cost centre refused, source balance = independent sum, target lines
numbered 1, 2 with 40 % / 60 % values, posting creates entry 2026/101/06nnnn (monthly number, LAST_SERIAL updated), balanced, source
reversed; posted header / target lines locked; cancel posting removes the entry; expense type clears the account; posting without an
account refused. Passed.

## Wave 3b (evidence `AC\FMB\AC_DISTP_fmb.xml` item properties)

| Legacy | Evidence | APEX |
|--------|----------|------|
| ACCOUNT_TYPE shown as the list ACCOUNT_TYPE_LIST (0 اختيار حساب / 1 مصروف), not updatable | List Item (values 0 / 1), UpdateAllowed = false | static select list + `readonly_after_insert` |
| DIS_DATE, ACC_NUMBER, DESC_A, DESC_E not updatable after insert | UpdateAllowed = false | `readonly_after_insert` |
| Account currency and its name (CURRENCY / CURRENCY_NAME display items) | Display Items, POST-QUERY | computed master column "عملة الحساب" |

Checked: detail blocks allow insert / update / delete (as generated); COST_CODE required (already); the cost-centre names come from the
column lists; DIST_BUT / POST only navigate between blocks (POST is the action). SQL run on the build copy (`tmp\w3b_gl\check.py`).

## Coverage

- Reproduced: rules 1-9; the wave 3b items below.
- Kept as in the legacy: the entry header has no POST_SYSTEM and GET_SERIAL (not CALC_SERIAL) numbers it; type "مصروف" compares the
  first digit of the account with the whole OUTCOME1_ACCT number (300000000000), so it never finds an account (balance 0) - the legacy
  posting also failed for it (null line account); APEX refuses posting without an account with a message.
- Not reproduced: "طباعة القيد" (report ACJRNL2 with the entry range: reports menu); debit / credit toggle label; header COST_CODE
  column (not an item of the form).
