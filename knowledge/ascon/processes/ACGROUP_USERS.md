# ACGROUP_USERS - المستخدمين / Users

- Registry: system 99 serial 5 (USERS_MENU, order 2002). APEX list page 80050, document page 80051, print 80052.
- Legacy module: `ASCON\SE\FMB\AcGroup_Users.fmx` (no .fmb). Blocks USERS (two tabs of flags), GROUP_USERS (المجموعات), SE_USERS_ROLES
  (الادوار), USERS_PRINTER (الطابعات), SE_USERS_NOTIFICATION (التنبيهات), CONTROL buttons.
- **Deliverable: (a) screen correction + rules + buttons** - `app\legacy\overrides\ACGROUP_USERS.json` (MASTER_DETAIL USERS with details
  GROUP_USERS, SE_USERS_ROLES, SE_USERS_NOTIFICATION), package `APP_RULES3_SE` (`app\db\25_rules3_se.sql`).
- **Confidence: high** for the password encoding, zero password, copy rights, all groups, default group, user 0 and the delete cleanup;
  **medium** for the Arabic labels mapped to the ~50 flag columns (prompts and columns are stored separately in the .fmx, the mapping is by meaning).

## The password (security consistency with APP_SEC)

The legacy form stores the typed password through its program unit `ENCODE_PASSWORD(IN_PASSWORD)` (same algorithm as the DB function
`ENCODE_PASSWORD`, wrapped: the ASCII codes of the characters, `'0'` -> `'48'`, `'12'` -> `'4950'`); USER_PASSWORD compares encoded values.
Evidence: .fmx identifiers `ENCODE_PASSWORD`, `TEMP_PASSWORD`, `IN_PASSWORD` and the `:PASSWORD` triggers; all 17 `USERS.PASSWORD` values of the
build copy are ASCII-code strings of digits and 12 of them equal `ENCODE_PASSWORD('0')` (the "zero password" value).

APEX (row rule `users_row`, every APEX write to USERS):
- a password typed in the users screen (new user, or a changed value) is stored as the legacy did (`ENCODE_PASSWORD`, Forms keeps working), and
- becomes the user's **one-time APEX password**: `APP_USER_AUTH` gets the salted hash (`app_sec.hash_pwd`), `MUST_CHANGE = 'Y'`, the account is
  unlocked and the failure counter reset. The next APEX login accepts it once and asks for a new password (page 9998).
- deleting a user removes its `APP_USER_AUTH` row (a later user with the same code must not inherit the credentials).

**APP_SEC needs a change (not in this agent's files):** `app_sec.authenticate` compares the typed password with `USERS.PASSWORD` in plain
text on the first login. Because the stored value is encoded, a legacy user can only sign in by typing the encoded digits (user 0 did so).
Suggested fix in `01_app_core.sql`: accept `l_usr.password in (p_password, encode_password(p_password))`; and `change_password` should also
write `USERS.PASSWORD := encode_password(p_new)` while Forms runs in parallel. Passwords reset in this screen work already (hash above).

## Rules and buttons

| # | Legacy rule / button | Evidence | APEX |
|---|---|---|---|
| 1 | Password stored encoded; the typed value is the user's password | P6/P7 triggers with `:PASSWORD` + `ENCODE_PASSWORD`; data | row rule `users_row` (+ APEX one-time password, see above) |
| 2 | "تصفير كلمة السر" sets the password to 0 | button ZERO_PASSWORD, trigger P13 on `:PASSWORD`; 12 users hold `ENCODE_PASSWORD('0')` | action ZERO_PASSWORD -> `zero_password` (USERS.PASSWORD '48', APEX password 0, must change, unlocked) |
| 3 | "نسخ صلاحيات" من مستخدم: groups, systems, screen and report rights of another user replace this user's | SQL `DELETE FROM GROUP_USERS / SYS_SYSTEMS_USERS / FILE_PASSWORD / REPORT_PASSWORD ... INSERT ...`, message "التم نسخ صلاحية المستخدم", LOV USERS_RG (other users) | action COPY_RIGHTS (param FROM_USER) -> `copy_user_rights`, legacy message |
| 4 | "جميع المجموعات": every group not assigned yet; a group other than 0 sees only its own group | ALL_GROUP_BUT, cursor AC_GROUP_CUR = AC_GROUP_CODE_RG | action ALL_GROUPS -> `all_groups` (ISDEFAULT 'N') |
| 5 | Group list: `PASSWORD_NUMBER = :GLOBAL.PASSWORD_NUMBER OR :GLOBAL.PASSWORD_NUMBER = 0`, not already assigned | AC_GROUP_CODE_RG | row rule `group_users_row` refuses another group for a non-0 group (PK refuses duplicates) |
| 6 | Only one default group ("أساسي"): ticking one unticks the others | ISDEFAULT trigger (VAR1 / VAR2 loop over the records) | row rule records the ticked group, after-save `fix_default_group` unticks the others (APP_SEC.post_auth picks the default group) |
| 7 | User 0 cannot be deleted: "لا يمكن مسح المستخدم رقم 0" / "You can't remove user no 0" | PRE-DELETE (P5) | delete hook `APP_RULES3_SE_USERS_BD` -> `users_delete` |
| 8 | Deleting a user deletes its FILE_PASSWORD, REPORT_PASSWORD, SE_USERS_ROLES rows | PRE-DELETE SQL | `users_delete` (+ APP_USER_AUTH) |
| 9 | Relation checks: a user with groups / printers / notifications cannot be deleted | `SELECT 1 FROM GROUP_USERS / USERS_PRINTER / SE_USERS_NOTIFICATION` ("Cannot delete master record when matching detail records exist.") | printers: refused in `users_delete`; groups / notifications are details of the APEX page and are removed with the document (generated cascade) |
| 10 | List of users: `USERS_CODE = :GLOBAL.USER_CODE OR :GLOBAL.PASSWORD_NUMBER = 0 ...` | block WHERE `( USERS_CODE = :1 OR :2=0 OR :3 IS NULL OR :4 IS NULL)` | `where` (non-admin groups see only themselves) |
| 11 | Language flag list: عربى / عربى - انجليزى / انجليزى | LANG_FLAG list item; data 'B' | row rule: A / B / E only (APP_SEC.post_auth: 'E' = English); wave 3b: static list |
| 12 | Users are deleted only here | other screens (SYSPASS, ACUSERS_SYSTEMS) show USERS as master with rights as details | `users_delete` refuses on other screens (their generated cascade would remove the rights first) |
| 13 | Flags of the second tab (approvals, invoice preparation, payment-order approvals, attendance, ...) | 70 USERS columns among the .fmx identifiers, prompts among the .fmx texts | `add_columns` with the legacy prompts (number fields 0/1; the labelled ones of GN_FORM_ITEM are check boxes) |
| 14 | Roles and notifications of the user | tabs الادوار / التنبيهات, LOVs ROLE_RG, NOTIFICATION_RG | details SE_USERS_ROLES, SE_USERS_NOTIFICATION; ROLE_ID / NOTIF_ID must be typed (key_expr `required`, the generated max+1 would invent one) |

Flag labels whose column is not certain (same prompt order, mapping by meaning): ALLOW_RP_CHECK_PAY / _C ("تاريخ تسليم السندات / الشيكات"),
HAS_PERMISSION_BONUS ("مسموح بتعديل السياسة"), ALLOW_SALES_ORDER_FLAG ("اعتماد اوامر البيع", SALES_ORDER_APPROVE is not among the identifiers),
USERS_APPR / USERS_MNGR (English prompts only). The columns read by the APEX rules are labelled with certainty (ALLOW_APPROVE 1-3, VN_PAY_AUTH1-6,
CHANGE_SALES_PRICE, ENABLE_CHANGE_CLASS, DELETE_AR_ADJESTMENT, PRINT_INV_FLAG, ALLOW_UPDATE_ENTRIES).

## Tests (build copy, simulated APEX session, generated triggers installed, rolled back) - `tmp\w3_gl\se\t_se.py`

U1-U14 passed: new user 99901 with password 12 -> USERS.PASSWORD 4950 and APEX hash of 12 (must change); update without a new password keeps it;
admin password 7 -> 55 + new hash; zero password -> 48, hash of 0, unlocked; language flag X refused; group 101 may not add group 102, may add 101;
default group moved from 0 to 101; all groups adds 102 as non-default; copy rights of user 3 (groups, systems, 1 file / report set identical);
copy from itself refused; user 0 delete refused; printer blocks the delete; delete from the SYSPASS page refused; delete removes rights, roles and
APP_USER_AUTH; role number required. APP_USER_AUTH identical before / after the run.

## Open questions

1. APP_SEC first login with encoded passwords (see above) - to be fixed in `01_app_core.sql`.
2. P6 (PRE-INSERT) also assigns `:ALLOW_APPROVE` (value not visible in the .fmx) - is a default approval right expected for new users?
3. Should the uncertain flag labels above be confirmed by the key user?
4. Were the flags of the second tab check boxes in the legacy screen (APEX shows them as check boxes since wave 3b)?


## Wave 3b

- LANG_FLAG (list item "مؤشر اللغة"): static list عربى A / عربى - انجليزى B / انجليزى E (labels of the .fmx texts; values as the row rule and APP_SEC.post_auth use them; data 'B').
- The 0 / 1 flags of the second tab (MOBILE_USER, CHANGE_SALES_PRICE, PRINT_INV_FLAG, C_PRINT_INV_FLAG, VN_PAY_AUTH1-6, ALLOW_RP_CHECK_PAY(_C), ALLOW_CLOSE_PR, ALLOW_OVER_DUES_FLAG, ALLOW_SALES_ORDER_FLAG, ALLOW_APPROVE(2/3), OWNER_SALES_ORDER_ONLY, HAS_PERMISSION_BONUS, CHANGE_CONFG_SALES_PRICE, DELETE_AR_ADJESTMENT, EDIT_AGRMNT_DATE, RT_ALLOW_APPROVE(2), ENABLE_CHANGE_CLASS, EDIT_RP_DATE, ALLOW_SUPP_DISC, the (C_)INV_* preparation flags, LATE_SEC, ERLY_SEC) are check boxes 1 / 0, like the flags of the first tab that GN_FORM_ITEM lists as check boxes: every value in USERS is 0 or 1 and the prompts are "مسموح ب..." rights. Medium confidence (the .fmx does not show the item type) - question 4. SUPP_AGRMNT_APPROVAL stays a number (values 0 / 3), REV1-4 (empty) and USERS_MNGR (a user number) too.

## Coverage

- Reproduced: rules 1-14, buttons ZERO_PASSWORD, COPY_RIGHTS (نسخ صلاحيات), ALL_GROUP_BUT (جميع المجموعات).
- Not reproduced: printers tab (USERS_PRINTER, printer selection is out of scope), the "الصلاحيات" window (P2_2016: opens the rights form with the
  user's flags - the rights are the SYSPASS page), print buttons (ALL_USERS_PRV / user reports - reports are separate pages), employee LOVs on
  PY_PRSNL_H (payroll not installed, table empty; EMP_CODE keeps its FK list), CUSTOMER_ACCOUNT_BALANCE / DBMS_RANDOM dongle check in PRE-INSERT,
  WEBUTIL / SET_IP / translation buttons. (Wave 3b: LANG_FLAG is a list and the 0 / 1 flags are check boxes; SUPP_AGRMNT_APPROVAL, REV1-4 and
  USERS_MNGR stay number fields.)
