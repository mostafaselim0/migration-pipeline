# ACMAST - دليل الحسابات / Chart of Account

- Registry: system 1 serial 3 (CODES_MENU.GL_STRUCT_BUILD, order 2003). APEX list 10100, account page 10101, print 10102.
- Legacy module: `ASCON\AC\FMB\Acmast.fmx` (no .fmb; GN_FORM_ITEM labels of block AC_MASTER). Tree view (Forms FTREE) + one-record form.
- **Deliverable: screen correction + rules (wave 3).** Override `app\legacy\overrides\ACMAST.json`: pattern `MASTER_DETAIL` on
  `AC_MASTER` with no detail, so that the account has its own page with the balance panel and the "add sub-account" button of
  the tree. PL/SQL `APP_RULES3_GL` (`25_rules3_gl.sql`), delete hook `APP_RULES3_GL_ACMAST_DEL`.
- **Confidence: high** for level / parent / grants / status / delete (SQL + data: every account of the build copy has its
  AC_COMPANY_MASTER row; the 62 AC_PASSWORD_MASTER rows are group 0 grants of accounts created by the administrator);
  **medium** for the messages of the numbered legacy errors (MESSAGES is empty) and for padding short numbers.

## How the legacy identified the program units (strings of the .fmx)

DETECT_ACCOUNT_LEVEL, GET_ACCOUNT_PARENT (RPAD(SUBSTR(acc,1,END(level-1)),12,'0')), ACCOUNT_FOUND, TRANSACTIONS_FOUND_FOR
(COUNT in AC_OPENING_BALANCE_DET / AC_DAILY_TRN_DET / AC_YEARLY_TRN_DET), ACCOUNT_HAS_BROTHERS, GET_NEXT_ACCOUNT, GET_END_POS,
SET_BLOCK_SELECTION (tree node -> query), GET_ACCOUNT_BAL_LEVEL (DB function). DB functions GET_ACC_LEVEL / GET_ACC_PARENT exist
with the same logic.

## Rules

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | Level of an account = last non-zero segment of the 12-digit number (AC_CHART_STRUCTURES); a number that does not fit (zero segment followed by digits, more than 12 digits) is refused | DETECT_ACCOUNT_LEVEL (shows an error message) | row rule `account_row` sets ACCOUNT_LEVEL; validation `check_account` ("رقم الحساب لا يتفق مع هيكل دليل الحسابات" - new text) |
| 2 | A child needs its parent ("لا يمكن تكوين حساب أبن بلا حساب أب") | GET_ACCOUNT_PARENT + ACCOUNT_FOUND in the ACCOUNT_NUMBER validation and the create-child trigger | validation `check_account` |
| 3 | No child under an account that has transactions (it would become a main account) | TRANSACTIONS_FOUND_FOR(parent) | validation + `add_child_account` ("لا يمكن إضافة حساب فرعي لحساب عليه حركات" - new text) |
| 4 | Currency required ("يجب ادخال العملة" / "Must Insert Currency"); default local currency 1 when AC_BASIC.CURRENCY_STTS = 0 | PRE-INSERT/record validation; PRE-FORM `DECODE(CURRENCY_STTS,0,1,NULL)` | validation; generated default 1 |
| 5 | A new account is a sub (postable) account: ACCOUNT_STATUS = 1 | tree query `DECODE(ACCOUNT_STATUS,0,-1,0)`; data (all level-6 = 1) | row rule; ACCOUNT_STATUS hidden (not an item of the form) |
| 6 | After insert: the parent becomes a main account (`UPDATE AC_MASTER SET ACCOUNT_STATUS = 0 WHERE ACCOUNT_NUMBER = parent`); the account is granted to the company (`INSERT INTO AC_COMPANY_MASTER VALUES (acc, company, level, end_pos)`) and to the user's group (`INSERT INTO AC_PASSWORD_MASTER VALUES (acc, company, group, level, end_pos)`), error "لم يم ادراج رقم الحساب في السرية" | POST-INSERT SQL + text | after_save `account_created` (CREATE) and inside `add_child_account` |
| 7 | "Add sub-account" from the selected tree node: next child number `RPAD(SUBSTR(MAX(acc),1,end_child)+1,12,0)` over the parent's subtree, level + 1, currency of the parent | create-child trigger (V_ACC_CHILD_NO, GET_NEXT_ACCOUNT SQL) | action CHILD "إضافة حساب فرعي" (name, English name), opens the new account; shown only while the level is not the last one. Improvement: refuses when the level is full instead of carrying into the parent segment |
| 8 | Delete refused when the account has transactions (daily, posted, opening, estimate) | PRE-DELETE (PRIMARY_CUR over AC_DAILY_TRN_DET, AC_YEARLY_TRN_DET, AC_ESTIMATE, AC_OPENING_BALANCE_DET) | delete hook ("لا يمكن حذف الحساب لوجود حركات عليه" - new text, legacy numbered message was empty) |
| 9 | Delete removes the account's grants (`DELETE FROM AC_PASSWORD_MASTER / AC_COMPANY_MASTER`) and, when it was the parent's last child, the parent becomes a sub account again (`UPDATE ... ACCOUNT_STATUS = 1`, ACCOUNT_HAS_BROTHERS) | PRE-DELETE / POST-DELETE SQL | delete hook (row + after statement, the parent is updated after the statement to avoid a mutating table) |
| 10 | List restricted to the accounts of the group: granted accounts and everything under a granted main account (RPAD by ACCOUNT_END_POS); group 0 sees all | block WHERE | `where` with :G_PASSWORD_NUMBER / :G_COMPANY_CODE |
| 11 | Balance display: GET_ACCOUNT_BAL_LEVEL(company, account) as absolute value with مدين / دائن, and in the account currency for foreign accounts (/ AC_CURRENCY.RATE); level and level length display | POST-QUERY (P12, texts الرصيد الجارى، مدين، دائن، المستوي، طول المستوى) | info panel (BAL, LVL) |
| 12 | Account number cannot be changed on a saved account | improvement (the level, grants and transactions depend on it) | validation (SAVE) |
| 13 | A number typed with fewer than 12 digits is completed with zeros | system convention (all codes RPAD(...,12,'0'); ACDLYTR pads typed accounts) | row rule (medium) |

## Tests (build copy, rolled back; `tmp\w3_gl\gl\t_gl.py` section B, 26 checks)

Invalid / existing / non-fitting number, missing parent, parent with a (temporary) estimate line, missing currency, padding
1101010029 -> 110101002900 (level 6, status 1), grants company + group 0 with level 6 / end 12, new level-5 account status 1, two
sub-accounts 110101003001 / 002 via the action (parent -> status 0, message "تم إنشاء الحساب رقم 110101003002"), next child after
existing children, delete of an account with transactions refused, deleting the children restores the parent to status 1 and removes
their grants, balance text = GET_ACCOUNT_BAL_LEVEL, level text, English message. All passed.

## Open questions

1. Should an account that still has sub-accounts be deletable? The legacy only checked transactions (children were left without a
   parent); reproduced as it was.
2. The legacy CURRENCY_CODE validation also read the parent's currency (`SELECT CURRENCY_CODE FROM AC_MASTER WHERE ACCOUNT_NUMBER =
   parent`); what it enforced is not visible (probably child currency = parent currency). Not enforced.

## Wave 3b

- STOP_FLAG "توقف الترحيل" is a legacy check box ([C] in GN_FORM_ITEM) that the generated page showed as a number: now
  `widget: CHECK` with 1 / 0 (the .fmx does not show its checked value; 1 / 0 as the other check boxes of this block - AC_FLAG data 0 / 1;
  STOP_FLAG is empty on all 328 accounts and no posting code reads it).
- Checked: AC_FLAG, BANK_FLAG, CASH_MANAG, RAP_FLAG are already check boxes; the level / currency displays are the ACCOUNT_LEVEL column,
  the currency list and the info panel (rule 11); no button only opened another form.

## Coverage

- Reproduced: rules 1-13; the tree insert (rule 7) as a button on the account page; group filter; balance display; STOP_FLAG check box.
- Not reproduced: the Forms tree itself (FTREE expand / collapse / "عرض شجرة الحسابات", navigation by node) - the list page with
  search and the account page replace it; foreign-currency begin-of-period / begin-of-year balances (CURRENT_FOR / BEGIN_* columns are
  0 or null on this schema); print button (report ACCHART, reports menu); TRANSLATE / WEBUTIL / SET_IP (Forms-only).
