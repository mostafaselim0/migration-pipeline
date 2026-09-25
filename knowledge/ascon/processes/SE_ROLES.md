# SE_ROLES - ارقام ادوار المستخدمين / Users Roles

- Registry: system 99 serial 64 (SYS_MENU, order 3027). APEX grid page 80170.
- Legacy module: `ASCON\SE\FMB\Se_Roles.fmx`. One block SE_ROLES (رقم دور المستخدم، الأسم عربى / انجليزى).
- **Deliverable: code table + numbering** - `app\legacy\overrides\SE_ROLES.json` (key_expr), `APP_RULES3_SE.next_role_id`.
- **Confidence: high.**

## Rules

| # | Legacy rule | Evidence | APEX |
|---|---|---|---|
| 1 | New role number = `NVL(MAX(ROLE_ID), 10) + 1` (roles start at 11: 1-10 are the built-in approval roles of SE_AUTH - 1 user, 2 user manager, 3 project manager, 4 department manager, 5 created user) | embedded SQL; SYS_FORMS / SE_USERS_AUTH decode PREV_INDEX 1-5 | key_expr `next_role_id` (the generated max+1 would start at 1) |
| 2 | Arabic and English names required | NOT NULL columns | generated |

Roles are used by the approval chains (SE_AUTH, SE_USERS_ROLES, SE_USERS_AUTH) - see SE_USERS_AUTH.md; SE_ROLES is empty in this database.

## Tests (t_se.py, rolled back)

W3 first role number 11.


## Wave 3b

Checked, nothing to change: a plain code table (role number, Arabic / English name).

## Coverage

Reproduced: rules 1-2. Not reproduced: WEBUTIL / translation / print buttons.
