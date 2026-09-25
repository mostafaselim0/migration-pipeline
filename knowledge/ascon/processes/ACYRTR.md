# ACYRTR - القيود المرحلة / Posted Entries

- Registry: system 1 serial 2 (FILES_MENU.ACYRTR, order 1002). APEX list 10020, entry page 10021 (read-only), print 10022.
- Legacy module: `ASCON\AC\FMB\ACYRTR.fmb` (source available): blocks AC_YEARLY_TRN / AC_YEARLY_TRN_DET.
- **Deliverable: generated master-detail kept (`AUTO`, read-only) + group filter + displays**, override `app\legacy\overrides\ACYRTR.json`,
  PL/SQL `APP_RULES3_GL.entry_info`.
- **Confidence: high** (trigger source).

## What the screen is

Posted GL entries are only viewed: WHEN-NEW-RECORD-INSTANCE sets insert / update / delete off for both blocks on every record
(the PRE-INSERT numbering, POST-INSERT currency-difference line and PRE-DELETE of the source are dead code of the old editable
version). The one action is the "إلغاء الترحيل" button of an entry.

## Rules

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | Read-only entry and lines | WHEN-NEW-RECORD-INSTANCE (SET_BLOCK_PROPERTY ... PROPERTY_FALSE) | generated read-only page (block flags of the .fmb) |
| 2 | List: journals granted to the group (`:global.password_number = 0 or (ENTRY_YEAR, ENTRY_TYPE) in AC_PASSWORD_ENTRY`) | block WHERE | `where` |
| 3 | Displays: journal name, debit / credit totals and difference, posted document of the sub-system (stock ST_TRNS_MAST, customers AR_MAINTRNS, suppliers VN_MAINTRNS, receipts RP_TRNS_MAST by the entry key; system name), created / modified / posted by | POST-QUERY, DEBIT_TOTAL / CREDIT_TOTAL / DIFF, POST_TRNS / POST_SER | info panel (8 values, `entry_info`) |
| 4 | "إلغاء الترحيل": refused in a closed period ("لا يمكن ترحيل الحركة لأنها تقع فى فترة مقفلة") or for an entry posted by another system ("هذا القيد مرحل من نظام ... لا يمكن الغاء الترحيل"); allowed for group 0, or when GROUP_COMPANY.POST_FLAG = 1 and the user has all rights on the cancel-posting screen (1/72); then TEST_AND_UPDATE moves the entry back to the daily tables | POST_VOUCHER WHEN-BUTTON-PRESSED, WHEN-NEW-FORM-INSTANCE | wave 3b: action CANCEL_POST (rule 5 below); also the ACCUPDT process page (range of one entry) |

## Tests (section L of `tmp\w3_gl\gl\t_gl.py`)

Entry 2026/103/101 (posted by the customers system): source document = the AR transaction of the entry, debit total = sum of the
positive lines, journal name. Passed.

## Wave 3b (actions on read-only documents, column keys)

| # | Legacy | Evidence | APEX |
|---|--------|----------|------|
| 5 | Button POST_VOUCHER "إلغاء الترحيل" of the entry: enabled for group 0 (or none), else GROUP_COMPANY.POST_FLAG = 1 and FILE_PASSWORD system 1 / file 72 (شاشة الغاء الترحيل) with the four flags; pressed: AC_BASIC.CLOSE_DATE >= entry date refused ('لا يمكن ترحيل الحركة لأنها تقع فى فترة مقفلة'), POST_SYSTEM <> 1 refused (' هذا القيد مرحل من نظام X لا يمكن الغاء الترحيل '), ASK_CPOST confirmation, TEST_AND_UPDATE (entry back to the daily tables), CLEAR_FORM | POST_VOUCHER WHEN-BUTTON-PRESSED, WHEN-NEW-FORM-INSTANCE (`Acyrtr_fmb.xml`) | action **CANCEL_POST** on the read-only page: condition `app_rules3_gl.can_cancel_entry`, call `app_rules3_gl.cancel_entry` -> `app_proc_gl.cancel_posting` for this one entry (same code as ACCUPDT); the page then opens empty |
| 6 | POST_SYSTEM shown as the list POST_SYSTEM_LIST (record group SYSTEMS_A / SYSTEMS_E: SYS_SYSTEMS except 0 / 99) | WHEN-NEW-FORM-INSTANCE POPULATE_LIST | `lov` on POST_SYSTEM (shown, read-only page) |

The Arabic confirmation "هل تريد إلغاء ترحيل القيد الحالي ؟" is new (the ASK_CPOST alert has only the English text "Do you want to delete
current entry ?").

Tests (`tmp\w3b_gl\B1\t_acyrtr.py`, company 1, rolled back) 9/9: group 0 allowed; unknown ROWID -> N; group 101 without POST_FLAG
refused, with POST_FLAG and the 1/72 rights allowed, without the delete right refused; AR entry 2026/103/101 refused (-20175 with the
system name); entry dated before CLOSE_DATE 31/12/2025 refused (-20169); entry 2026/101/10053 moved to AC_DAILY_TRN with its 10 lines
("لقد تم إلغاء ترحيل القيود فى النطاق المحدد بنجـــاح (1 قيد)"). Data checked unchanged afterwards.

## Coverage

- Reproduced: rules 1-6 (rule 4 = the button of rule 5, also available as the ACCUPDT range screen).
- Not reproduced: memo pop-up buttons (MEMO / MEMO_E are shown), estimate-balance displays of the lines (budget tables empty),
  the P_ENTRY_NO call parameter (opening one entry from another screen), print buttons (print page 10022 / reports).
