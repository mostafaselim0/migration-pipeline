-- =====================================================================================================
-- APP_RULES3_SE : business rules and buttons of the security / company / registry screens (Stage C wave 3).
--   COMPANY           companies + communication ways + licences      COMPANY / COMPANY_COMM / COMPANY_LICENCE
--   COMM_WAY, LICENCE code tables (duplicate-code messages)
--   ACGROUP_COMPANY   groups and their companies                     PASSWORD / GROUP_COMPANY
--   ACGROUP_USERS     users, their groups, roles, notifications      USERS / GROUP_USERS / SE_USERS_ROLES / SE_USERS_NOTIFICATION
--   ACUSERS_SYSTEMS   systems of a user                              USERS / SYS_SYSTEMS_USERS
--   SYSPASS           screen and report rights of a user             USERS / FILE_PASSWORD / REPORT_PASSWORD
--   ACCOMPANY_ACCOUNT GL data of a company                           COMPANY / AC_COMPANY_ENTRY, _MASTER, _COST1, _COST2, _EST_PERIOD
--   ACPASS_ADMIN      GL data grants of a group                      PASSWORD / GROUP_COMPANY / AC_PASSWORD_ENTRY, _MASTER, _COST1, _COST2, _EST_PERIOD
--   SEPASS_TRN        stock grants of a group                        PASSWORD / ST_STORE_PASSWORD, ST_TRNSTYPE_PASSWORD, ST_GROUP_PASSWORD
--   ARPASS            receivable grants of a group                   PASSWORD / AR_TRNSTYPE_PASSWORD, AR_CUSTOMER_PASSWORD, AR_CUST_PASSWORD, AR_SALESMAN_PASSWORD
--   VNPASS            payable grants of a group                      PASSWORD / VN_TRNSTYPE_PASSWORD, VN_SUPPLIER_PASSWORD
--   RAPPASS, CHECKPASS, PYPASS  cashier / cheque / HR grants of a group
--   SE_ROLES          role numbers (NVL(MAX,10)+1)
-- Evidence and decisions: app\legacy\processes\<FORM>.md.  Wiring: app\legacy\overrides\<FORM>.json
--   key_expr   -> next_role_id, required (key columns the generated max+1 must not fill)
--   row_rules  -> users_row, group_users_row, group_company_row, derived levels (pwd_master_row, ...), dup checks
--   after_save -> fix_default_group, fix_default_company, vn_ranges_check, company_created
--   actions    -> copy_user_rights, all_groups, zero_password, grant_all_forms/reports, all_systems, all_companies,
--                 copy_group_rights, ac_grant_all, ac_add_parents, ac_company_all, st_all, set_flags, ar_all_*, vn_all_trns,
--                 rap_all_*, check_all_*, py_all_dept, load_logo
--   triggers at the end of this file (the rules mechanism has no delete hook):
--     APP_RULES3_SE_USERS_BD (user 0, rights and APEX credentials of a deleted user), APP_RULES3_SE_PASSWORD_BD (group grants),
--     APP_RULES3_SE_COMPANY_BD (AC_BASIC), APP_RULES3_SE_SYSSYS_BD (system with screens), APP_RULES3_SE_GRPCOMP_BD (ACPASS_ADMIN),
--     APP_RULES3_SE_PWM_CD / _PWC1_CD / _PWC2_CD (ACPASS_ADMIN: deleting a main account / cost centre deletes its sub accounts).
-- Security consistency with APP_SEC (01_app_core.sql): a password typed in the users screen is stored as the legacy did
-- (ENCODE_PASSWORD in USERS.PASSWORD, for the Forms application) and as the salted hash of APP_USER_AUTH with MUST_CHANGE = 'Y'
-- (so the next APEX login accepts it once and asks for a new one); deleting a user removes its APP_USER_AUTH row.
-- Errors: raise_application_error(-20100..-20199), legacy Arabic text where one exists (English when app_sec.lang = 'en').
-- No COMMIT anywhere (APEX commits the page).
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_rules3_se authid definer as

  -- ------------------------------------------------------------------ context
  function cur_form return varchar2;                                   -- legacy form of the current APEX page (APP_PAGE_MAP)
  function lang_en return boolean;
  function m (p_a in varchar2, p_e in varchar2) return varchar2;       -- Arabic / English message
  procedure set_bypass (p_on in boolean);                              -- tests: fixtures without row rules
  function bypass return boolean;
  function in_cascade return boolean;                                  -- subtree deletes of ACPASS_ADMIN in progress

  -- key_expr helper: a key column the user must type (the generated max+1 would otherwise invent one)
  function required (p_what_a in varchar2, p_what_e in varchar2) return number;

  -- ------------------------------------------------------------------ SE_ROLES
  function next_role_id return number;                                 -- SELECT NVL(MAX(ROLE_ID),10)+1 FROM SE_ROLES

  -- ------------------------------------------------------------------ users (ACGROUP_USERS)
  procedure users_row (p_inserting in boolean, p_users_code in number, p_old_password in varchar2,
                       p_password in out varchar2, p_lang_flag in varchar2);
  procedure users_delete (p_users_code in number);                     -- delete hook
  procedure group_users_row (p_inserting in boolean, p_users_code in number, p_password_number in number, p_isdefault in varchar2);
  procedure fix_default_group (p_users_code in number);                -- after_save: one default group per user
  function copy_user_rights (p_rowid in varchar2, p_from_user in number) return varchar2;
  function all_groups (p_rowid in varchar2) return varchar2;
  function zero_password (p_rowid in varchar2) return varchar2;
  function last_message return varchar2;

  -- ------------------------------------------------------------------ SYSPASS / ACUSERS_SYSTEMS
  function grant_all_forms (p_rowid in varchar2, p_system in number) return varchar2;
  function grant_all_reports (p_rowid in varchar2, p_system in number) return varchar2;
  procedure file_password_row (p_system in number, p_file_serial in number);
  procedure report_password_row (p_system in number, p_report_serial in number);
  procedure sys_systems_users_row (p_system in number);
  function all_systems (p_rowid in varchar2) return varchar2;

  -- ------------------------------------------------------------------ groups (ACGROUP_COMPANY) and group data grants
  procedure group_company_row (p_inserting in boolean, p_company in number, p_password_number in number, p_isdefault in varchar2);
  procedure fix_default_company (p_password_number in number);
  function all_companies (p_rowid in varchar2) return varchar2;
  function copy_group_rights (p_rowid in varchar2, p_from_group in number) return varchar2;
  procedure password_delete (p_password_number in number);             -- delete hook: group grant tables

  -- ------------------------------------------------------------------ GL grants (ACCOMPANY_ACCOUNT, ACPASS_ADMIN)
  function acc_level (p_account in number) return number;
  function acc_end_pos (p_level in number) return number;
  function cost_level (p_which in pls_integer, p_cost in number) return number;
  function cost_end_pos (p_which in pls_integer, p_level in number) return number;
  procedure account_row (p_account in number, p_level in out number, p_end_pos in out number);
  procedure cost_row (p_which in pls_integer, p_cost in number, p_level in out number, p_end_pos in out number);
  function ac_company_all (p_rowid in varchar2, p_kind in varchar2) return varchar2;          -- ACCOMPANY_ACCOUNT buttons
  function ac_grant_all (p_rowid in varchar2, p_company in number, p_kind in varchar2) return varchar2;   -- ACPASS_ADMIN buttons
  function ac_add_parents (p_rowid in varchar2, p_company in number, p_kind in varchar2) return varchar2; -- main accounts / centres
  procedure ac_subtree_delete (p_kind in varchar2, p_code in number, p_company in number, p_password in number, p_level in number);
  procedure group_company_delete (p_company in number, p_password_number in number);

  -- ------------------------------------------------------------------ other group grant screens
  function st_all (p_rowid in varchar2, p_kind in varchar2) return varchar2;                 -- SEPASS_TRN: STORE / TRNS / GROUP
  function set_flags (p_rowid in varchar2, p_table in varchar2, p_flag in number) return varchar2;   -- select all / none
  function ar_all_trns (p_rowid in varchar2) return varchar2;
  function ar_all_customers (p_rowid in varchar2, p_mainarea in number, p_subarea in number, p_ctgry in number,
                             p_salesman in number) return varchar2;
  function ar_all_salesmen (p_rowid in varchar2, p_subarea in number, p_ctgry in number) return varchar2;
  function vn_all_trns (p_rowid in varchar2) return varchar2;
  procedure vn_range_row (p_from in number, p_to in number);
  procedure vn_ranges_check (p_password_number in number);             -- after_save: overlapping supplier ranges
  function rap_all_boxes (p_rowid in varchar2) return varchar2;
  function rap_all_trns (p_rowid in varchar2) return varchar2;
  function check_all_banks (p_rowid in varchar2) return varchar2;
  function check_all_trns (p_rowid in varchar2) return varchar2;
  function py_all_dept (p_rowid in varchar2) return varchar2;
  procedure dup_row (p_table in varchar2, p_password_number in number, p_code in number, p_code2 in number default null);

  -- ------------------------------------------------------------------ companies (COMPANY) and code tables
  procedure company_row (p_inserting in boolean, p_company in number);
  procedure company_created (p_company in number);                     -- after_save CREATE: AC_BASIC / PY_BASIC_H
  procedure company_delete (p_company in number);                      -- delete hook: AC_BASIC
  procedure licence_dates (p_start in date, p_end in date, p_renewal in date);
  function load_logo (p_rowid in varchar2, p_file in varchar2) return varchar2;
  procedure code_row (p_table in varchar2, p_inserting in boolean, p_code in number);    -- COMM_WAY / LICENCE duplicate code
  procedure sys_systems_delete (p_system in number);                   -- delete hook: system with screens / reports

end app_rules3_se;
/

create or replace package body app_rules3_se as

  g_page      number := -1;
  g_form      varchar2(100);
  g_bypass    boolean := false;
  g_cascade   boolean := false;
  g_msg       varchar2(4000);

  -- defaults set in this transaction (row rules -> after_save): key = users_code / password_number, value = group / company
  type t_map is table of number index by varchar2(40);
  g_def_user  t_map;
  g_def_comp  t_map;
  g_txn       varchar2(100);

  -- tables holding the data grants of a group (legacy ACGROUP_COMPANY PRE-DELETE list, also used by the copy button)
  type t_names is table of varchar2(30);
  c_group_tables constant t_names := t_names(
    'VN_TRNSTYPE_PASSWORD', 'AS_TRNSTYPE_PASSWORD', 'AR_PAYTYP_PASSWORD', 'AR_TRNSTYPE_PASSWORD', 'AR_CUST_PASSWORD',
    'AR_CUSTOMER_PASSWORD', 'VN_SUPPLIER_PASSWORD', 'ST_TRNSTYPE_PASSWORD', 'ST_STORE_PASSWORD', 'ST_GROUP_PASSWORD',
    'RP_BOXS_PASSWORD', 'RAP_TRNS_PASSWORD', 'PY_EMPLOYEE_PASSWORD', 'PY_DEPT_PASSWORD', 'PY_DEPT_HIER_PASSWORD',
    'PD_TRNSTYPE_PASSWORD', 'MN_TRNS_PASSWORD', 'MN_TRNSTYPE_PASSWORD', 'CSTD_TRNS_PASSWORD', 'CSTD_CODES_PASSWORD',
    'CHECK_TRNS_PASSWORD', 'BANK_PASSWORD', 'AS_CTGRY_PASSWORD', 'AC_PASSWORD_MASTER', 'AC_PASSWORD_EST_PERIOD',
    'AC_PASSWORD_ENTRY', 'AC_PASSWORD_COST2', 'AC_PASSWORD_COST1', 'AR_SALESMAN_PASSWORD');

  -- ------------------------------------------------------------------ helpers
  function num (p in varchar2) return number is
  begin
    return to_number(p);
  exception when value_error or invalid_number then return null;
  end num;

  function cur_form return varchar2 is
    l_page number;
  begin
    l_page := num(v('APP_PAGE_ID'));
    if l_page is null then return null; end if;
    if l_page != g_page then
      begin
        select form_name into g_form from app_page_map where page_id = l_page;
      exception when no_data_found then g_form := null;
      end;
      g_page := l_page;
    end if;
    return g_form;
  end cur_form;

  function lang_en return boolean is
  begin
    return app_sec.lang = 'en';
  end lang_en;

  function m (p_a in varchar2, p_e in varchar2) return varchar2 is
  begin
    return case when lang_en then nvl(p_e, p_a) else p_a end;
  end m;

  procedure err (p_code in pls_integer, p_a in varchar2, p_e in varchar2) is
  begin
    raise_application_error(p_code, m(p_a, p_e));
  end err;

  procedure set_bypass (p_on in boolean) is
  begin
    g_bypass := nvl(p_on, false);
  end set_bypass;

  function bypass return boolean is
  begin
    return g_bypass;
  end bypass;

  function in_cascade return boolean is
  begin
    return g_cascade;
  end in_cascade;

  function grp return number is
  begin
    return nvl(num(v('G_PASSWORD_NUMBER')), 0);
  end grp;

  function comp return number is
  begin
    return num(v('G_COMPANY_CODE'));
  end comp;

  -- rows typed by the user (form / grid save), not rows written by an action button of these screens (request ACT_<name>)
  function page_request return boolean is
  begin
    return nvl(v('REQUEST'), '-') not like 'ACT\_%' escape '\';
  end page_request;

  -- master records are deleted only from the screen that owns them: on the other screens the generated document delete
  -- removes the detail rows of the page first, so the legacy relation check ("Cannot delete master record when matching
  -- detail records exist") can only be kept by refusing the master delete there (the whole request is rolled back)
  procedure owner_only (p_owner in varchar2, p_a in varchar2) is
    l_form varchar2(100) := cur_form;
  begin
    if l_form is not null and l_form <> p_owner then
      err(-20132, p_a, 'Cannot delete master record when matching detail records exist.');
    end if;
  end owner_only;

  procedure check_txn is
    l varchar2(100) := dbms_transaction.local_transaction_id;
  begin
    if g_txn is null or l is null or g_txn <> l then
      g_def_user.delete; g_def_comp.delete; g_txn := l;
    end if;
  end check_txn;

  function row_value (p_table in varchar2, p_col in varchar2, p_rowid in varchar2) return number is
    l number;
  begin
    execute immediate 'select ' || dbms_assert.simple_sql_name(p_col) || ' from ' || dbms_assert.simple_sql_name(p_table)
                      || ' where rowid = chartorowid(:r)' into l using p_rowid;
    return l;
  exception when no_data_found then
    err(-20100, 'يجب الحفظ اولا', 'Save the record first');
  end row_value;

  function users_of (p_rowid in varchar2) return number is
  begin
    return row_value('USERS', 'USERS_CODE', p_rowid);
  end users_of;

  function group_of (p_rowid in varchar2) return number is
  begin
    return row_value('PASSWORD', 'PASSWORD_NUMBER', p_rowid);
  end group_of;

  function company_of (p_rowid in varchar2) return number is
  begin
    return row_value('COMPANY', 'COMPANY_CODE', p_rowid);
  end company_of;

  function last_message return varchar2 is
  begin
    return g_msg;
  end last_message;

  function required (p_what_a in varchar2, p_what_e in varchar2) return number is
  begin
    err(-20101, 'يجب إدخال ' || p_what_a, p_what_e || ' is required');
    return null;
  end required;

  -- ------------------------------------------------------------------ SE_ROLES
  function next_role_id return number is
    l number;
  begin
    select nvl(max(role_id), 10) + 1 into l from se_roles;
    return l;
  end next_role_id;

  -- ------------------------------------------------------------------ users
  -- Legacy ACGROUP_USERS: the typed password is stored encoded (form program unit ENCODE_PASSWORD = the DB function
  -- ENCODE_PASSWORD, ASCII codes of the characters: '0' -> '48'); the password check of USER_PASSWORD compares encoded values.
  -- APEX: the same value goes to USERS.PASSWORD (Forms keeps working) and the typed password becomes the one-time APEX
  -- password (APP_USER_AUTH hash, MUST_CHANGE = 'Y', unlocked), because APP_SEC hashes the credentials after the first login.
  procedure users_row (p_inserting in boolean, p_users_code in number, p_old_password in varchar2,
                       p_password in out varchar2, p_lang_flag in varchar2) is
    l_plain varchar2(4000);
    l_salt  varchar2(64);
  begin
    if g_bypass then return; end if;
    if p_lang_flag is not null and p_lang_flag not in ('A', 'B', 'E') then
      err(-20102, 'مؤشر اللغة: A عربى، B عربى - انجليزى، E انجليزى', 'Language flag: A Arabic, B Arabic - English, E English');
    end if;
    if p_password is null then return; end if;
    if not p_inserting and p_old_password is not null and p_password = p_old_password then return; end if;
    l_plain := p_password;
    p_password := encode_password(l_plain);
    l_salt := rawtohex(sys.dbms_crypto.randombytes(16));
    merge into app_user_auth a using (select p_users_code c from dual) s on (a.users_code = s.c)
    when matched then update set pwd_hash = app_sec.hash_pwd(p_users_code, l_plain, l_salt), salt = l_salt, must_change = 'Y',
                                 failed_count = 0, locked = 'N', changed_on = sysdate
    when not matched then insert (users_code, pwd_hash, salt, must_change, failed_count, locked, changed_on)
                          values (p_users_code, app_sec.hash_pwd(p_users_code, l_plain, l_salt), l_salt, 'Y', 0, 'N', sysdate);
  end users_row;

  -- Legacy PRE-DELETE of USERS: user 0 cannot be removed; the user's screen / report rights and roles go with it.
  -- Relation checks: printers (USERS_PRINTER) block the delete (groups / notifications are details of the APEX page and are
  -- removed with the document).  The APEX credentials of the user are removed too (a new user with the same code must not
  -- inherit them).
  procedure users_delete (p_users_code in number) is
    l number;
  begin
    if g_bypass then return; end if;
    owner_only('ACGROUP_USERS', 'يحذف المستخدم من شاشة المستخدمين فقط (توجد صلاحيات مرتبطة به)');
    if p_users_code = 0 then
      err(-20103, 'لا يمكن مسح المستخدم رقم 0', 'You can''t remove user no 0');
    end if;
    select count(*) into l from users_printer where users_code = p_users_code;
    if l > 0 then
      err(-20104, 'لا يمكن حذف المستخدم لوجود طابعات مسجلة له', 'Cannot delete master record when matching detail records exist.');
    end if;
    delete from file_password where users_code = p_users_code;
    delete from report_password where users_code = p_users_code;
    delete from se_users_roles s where s.users_code = p_users_code;
    delete from app_user_auth where users_code = p_users_code;
  end users_delete;

  -- GROUP_USERS: the group list offered to a group other than 0 is its own group only (AC_GROUP_CODE_RG); a group ticked
  -- "default" becomes the only default of the user (ISDEFAULT trigger: the other records are unticked).
  procedure group_users_row (p_inserting in boolean, p_users_code in number, p_password_number in number, p_isdefault in varchar2) is
  begin
    if g_bypass then return; end if;
    if p_inserting and page_request and grp <> 0 and p_password_number <> grp then
      err(-20105, 'غير مسموح لمجموعتك بإضافة المجموعة ' || p_password_number,
          'Your group may not assign group ' || p_password_number);
    end if;
    if p_isdefault = 'Y' then
      check_txn;
      g_def_user(to_char(p_users_code)) := p_password_number;
    end if;
  end group_users_row;

  procedure fix_default_group (p_users_code in number) is
    l_key varchar2(40) := to_char(p_users_code);
  begin
    check_txn;
    if g_def_user.exists(l_key) then
      update group_users set isdefault = 'N'
       where users_code = p_users_code and password_number <> g_def_user(l_key) and isdefault = 'Y';
      g_def_user.delete(l_key);
    end if;
  end fix_default_group;

  -- "نسخ صلاحيات" من مستخدم: groups, systems, screen and report rights of another user replace the current user's.
  function copy_user_rights (p_rowid in varchar2, p_from_user in number) return varchar2 is
    l_to number := users_of(p_rowid);
    l    number;
  begin
    if p_from_user is null then
      err(-20106, 'يجب ادخال رقم المستخدم', 'Enter the user to copy from');
    end if;
    select count(*) into l from users where users_code = p_from_user;
    if l = 0 or p_from_user = l_to then
      err(-20107, 'رقم المستخدم غير صحيح', 'Invalid user');
    end if;
    delete from group_users where users_code = l_to;
    for r in (select * from group_users where users_code = p_from_user) loop
      insert into group_users (users_code, password_number, isdefault) values (l_to, r.password_number, r.isdefault);
    end loop;
    delete from sys_systems_users where users_code = l_to;
    for r in (select * from sys_systems_users where users_code = p_from_user) loop
      insert into sys_systems_users (system_number, users_code, note) values (r.system_number, l_to, r.note);
    end loop;
    delete from file_password where users_code = l_to;
    for r in (select * from file_password where users_code = p_from_user) loop
      insert into file_password (system_number, file_serial, insert_flag, delete_flag, update_flag, query_flag, users_code)
      values (r.system_number, r.file_serial, r.insert_flag, r.delete_flag, r.update_flag, r.query_flag, l_to);
    end loop;
    delete from report_password where users_code = l_to;
    for r in (select * from report_password where users_code = p_from_user) loop
      insert into report_password (system_number, report_serial, report_flag, users_code)
      values (r.system_number, r.report_serial, r.report_flag, l_to);
    end loop;
    g_msg := m('التم نسخ صلاحية المستخدم', 'Users Previlage Copy Complete');
    return p_rowid;
  end copy_user_rights;

  -- "جميع المجموعات": every group not yet assigned (a group other than 0 only its own group), not default.
  function all_groups (p_rowid in varchar2) return varchar2 is
    l_user number := users_of(p_rowid);
    l_n    number := 0;
    l_grp  number := grp;
  begin
    for r in (select password_number from password p
               where p.password_number not in (select g.password_number from group_users g where g.users_code = l_user)
                 and (p.password_number = l_grp or l_grp = 0)
               order by p.password_number) loop
      insert into group_users (users_code, password_number, isdefault) values (l_user, r.password_number, 'N');
      l_n := l_n + 1;
    end loop;
    g_msg := m('تمت إضافة ' || l_n || ' مجموعة', l_n || ' group(s) added');
    return p_rowid;
  end all_groups;

  -- "تصفير كلمة السر": password 0 (stored ENCODE_PASSWORD('0') = '48' by users_row; 12 of the 17 users of the build copy have it)
  function zero_password (p_rowid in varchar2) return varchar2 is
    l_user number := users_of(p_rowid);
  begin
    update users set password = '0' where users_code = l_user;
    g_msg := m('تم تصفير كلمة السر للمستخدم ' || l_user || ' (كلمة السر 0، يجب تغييرها عند الدخول)',
               'Password of user ' || l_user || ' reset to 0 (to be changed at the next sign-in)');
    return p_rowid;
  end zero_password;

  -- ------------------------------------------------------------------ SYSPASS
  -- "جميع الشــاشات" / "جميع التقـــارير": the rights of the system are replaced by every screen / report of the system
  -- (all four flags / REPORT_FLAG = 1).
  function grant_all_forms (p_rowid in varchar2, p_system in number) return varchar2 is
    l_user number := users_of(p_rowid);
    l_n    number := 0;
  begin
    if p_system is null then err(-20108, 'يجب ادخال رقم النظام', 'Enter the system'); end if;
    delete from file_password where users_code = l_user and system_number = p_system;
    for r in (select file_serial from sys_files where system_number = p_system order by file_serial) loop
      insert into file_password (system_number, file_serial, insert_flag, delete_flag, update_flag, query_flag, users_code)
      values (p_system, r.file_serial, 1, 1, 1, 1, l_user);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تم منح صلاحية ' || l_n || ' شاشة من النظام ' || p_system, l_n || ' screen(s) of system ' || p_system || ' granted');
    return p_rowid;
  end grant_all_forms;

  function grant_all_reports (p_rowid in varchar2, p_system in number) return varchar2 is
    l_user number := users_of(p_rowid);
    l_n    number := 0;
  begin
    if p_system is null then err(-20108, 'يجب ادخال رقم النظام', 'Enter the system'); end if;
    delete from report_password where users_code = l_user and system_number = p_system;
    for r in (select report_serial from sys_reports where system_number = p_system order by report_serial) loop
      insert into report_password (system_number, report_serial, report_flag, users_code) values (p_system, r.report_serial, 1, l_user);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تم منح صلاحية ' || l_n || ' تقرير من النظام ' || p_system, l_n || ' report(s) of system ' || p_system || ' granted');
    return p_rowid;
  end grant_all_reports;

  -- the screen / report must exist in the registry of the system (FILES_S / REP_S lists)
  procedure file_password_row (p_system in number, p_file_serial in number) is
    l number;
  begin
    if g_bypass or not page_request then return; end if;
    select count(*) into l from sys_files where system_number = p_system and file_serial = p_file_serial;
    if l = 0 then
      err(-20109, 'الشاشة ' || p_file_serial || ' غير موجودة فى النظام ' || p_system,
          'Screen ' || p_file_serial || ' does not exist in system ' || p_system);
    end if;
  end file_password_row;

  procedure report_password_row (p_system in number, p_report_serial in number) is
    l number;
  begin
    if g_bypass or not page_request then return; end if;
    select count(*) into l from sys_reports where system_number = p_system and report_serial = p_report_serial;
    if l = 0 then
      err(-20110, 'التقرير ' || p_report_serial || ' غير موجود فى النظام ' || p_system,
          'Report ' || p_report_serial || ' does not exist in system ' || p_system);
    end if;
  end report_password_row;

  -- ------------------------------------------------------------------ ACUSERS_SYSTEMS
  procedure sys_systems_users_row (p_system in number) is
    l number;
  begin
    if g_bypass or not page_request then return; end if;
    select count(*) into l from sys_systems where system_number = p_system;
    if l = 0 then
      err(-20111, 'رقم النظام ' || p_system || ' غير موجود', 'System ' || p_system || ' does not exist');
    end if;
  end sys_systems_users_row;

  -- "جميع الأنظمة": the systems of the user are replaced by every system
  function all_systems (p_rowid in varchar2) return varchar2 is
    l_user number := users_of(p_rowid);
    l_n    number := 0;
  begin
    delete from sys_systems_users where users_code = l_user;
    for r in (select distinct system_number from sys_systems order by system_number) loop
      insert into sys_systems_users (system_number, users_code) values (r.system_number, l_user);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تمت إضافة ' || l_n || ' نظام', l_n || ' system(s) added');
    return p_rowid;
  end all_systems;

  -- ------------------------------------------------------------------ groups
  procedure group_company_row (p_inserting in boolean, p_company in number, p_password_number in number, p_isdefault in varchar2) is
  begin
    if g_bypass then return; end if;
    if p_inserting and page_request and cur_form = 'ACGROUP_COMPANY' and grp <> 0 and p_company <> nvl(comp, -1) then
      err(-20112, 'غير مسموح لمجموعتك بإضافة الشركة ' || p_company, 'Your group may not assign company ' || p_company);
    end if;
    if p_isdefault = 'Y' then
      check_txn;
      g_def_comp(to_char(p_password_number)) := p_company;
    end if;
  end group_company_row;

  procedure fix_default_company (p_password_number in number) is
    l_key varchar2(40) := to_char(p_password_number);
  begin
    check_txn;
    if g_def_comp.exists(l_key) then
      update group_company set isdefault = 'N'
       where password_number = p_password_number and company_code <> g_def_comp(l_key) and isdefault = 'Y';
      g_def_comp.delete(l_key);
    end if;
  end fix_default_company;

  -- "جميع الشركات": every company not yet in the group (a group other than 0: the session company only)
  function all_companies (p_rowid in varchar2) return varchar2 is
    l_pw   number := group_of(p_rowid);
    l_n    number := 0;
    l_grp  number := grp;
    l_comp number := comp;
  begin
    for r in (select company_code from company c
               where c.company_code not in (select g.company_code from group_company g where g.password_number = l_pw)
                 and (c.company_code = l_comp or l_grp = 0)
               order by c.company_code) loop
      insert into group_company (company_code, password_number, isdefault) values (r.company_code, l_pw, 'N');
      l_n := l_n + 1;
    end loop;
    g_msg := m('تمت إضافة ' || l_n || ' شركة', l_n || ' company(ies) added');
    return p_rowid;
  end all_companies;

  -- "نسخ صلاحيات" من مجموعة (COPY_TABLE over USER_TAB_COLUMNS): every data grant table of the other group is copied to this
  -- group (the group's own rows of those tables are replaced).
  function copy_group_rights (p_rowid in varchar2, p_from_group in number) return varchar2 is
    l_to   number := group_of(p_rowid);
    l_cols varchar2(4000);
    l_sel  varchar2(4000);
    l      number;
  begin
    if p_from_group is null then
      err(-20113, 'يجب ادخال رقم المجموعة', 'Enter the group to copy from');
    end if;
    select count(*) into l from password where password_number = p_from_group;
    if l = 0 or p_from_group = l_to then
      err(-20114, 'رقم المجموعة غير صحيح', 'Invalid group');
    end if;
    for i in 1 .. c_group_tables.count loop
      select count(*) into l from user_tables where table_name = c_group_tables(i);
      if l = 1 then
        select listagg(column_name, ', ') within group (order by column_id),
               listagg(case when column_name = 'PASSWORD_NUMBER' then ':p_to' else column_name end, ', ') within group (order by column_id)
          into l_cols, l_sel
          from user_tab_columns where table_name = c_group_tables(i);
        execute immediate 'delete from ' || c_group_tables(i) || ' where password_number = :p_to' using l_to;
        execute immediate 'insert into ' || c_group_tables(i) || ' (' || l_cols || ') select ' || l_sel || ' from '
                          || c_group_tables(i) || ' where password_number = :p_from' using l_to, p_from_group;
      end if;
    end loop;
    g_msg := m('تم نسخ صلاحية المجموعة', 'Group privileges copied');
    return p_rowid;
  end copy_group_rights;

  -- legacy PRE-DELETE of the group: its data grants in every system are removed
  procedure password_delete (p_password_number in number) is
    l number;
  begin
    if g_bypass then return; end if;
    owner_only('ACGROUP_COMPANY', 'تحذف المجموعة من شاشة المجموعات فقط (توجد صلاحيات مرتبطة بها)');
    for i in 1 .. c_group_tables.count loop
      select count(*) into l from user_tables where table_name = c_group_tables(i);
      if l = 1 then
        execute immediate 'delete from ' || c_group_tables(i) || ' where password_number = :p' using p_password_number;
      end if;
    end loop;
  end password_delete;

  -- ------------------------------------------------------------------ GL grants
  function acc_level (p_account in number) return number is
    l number;
  begin
    select account_level into l from ac_master where account_number = p_account;
    return l;
  exception when no_data_found then return null;
  end acc_level;

  function acc_end_pos (p_level in number) return number is
    l number;
  begin
    select chr_stru_end into l from ac_chart_structures where chr_stru_level = p_level;
    return l;
  exception when no_data_found then return null;
  end acc_end_pos;

  function cost_level (p_which in pls_integer, p_cost in number) return number is
    l number;
  begin
    if p_which = 1 then
      select cost_level into l from ac_cost_centers where cost_code = p_cost;
    else
      select cost_level into l from ac_cost_centers2 where cost_code = p_cost;
    end if;
    return l;
  exception when no_data_found then return null;
  end cost_level;

  function cost_end_pos (p_which in pls_integer, p_level in number) return number is
    l number;
  begin
    select cost_str_end into l from ac_cost_strctures where cost_str_level = p_level and cost_center_number = p_which;
    return l;
  exception when no_data_found then return null;
  end cost_end_pos;

  -- ACCOUNT_LEVEL = AC_MASTER.ACCOUNT_LEVEL, ACCOUNT_END_POS = AC_CHART_STRUCTURES.CHR_STRU_END of that level
  -- (all 328 AC_COMPANY_MASTER and 62 AC_PASSWORD_MASTER rows of the build copy follow it)
  procedure account_row (p_account in number, p_level in out number, p_end_pos in out number) is
    l number;
  begin
    if g_bypass then return; end if;
    l := acc_level(p_account);
    if l is not null then
      p_level := l;
      p_end_pos := nvl(acc_end_pos(l), p_end_pos);
    end if;
  end account_row;

  procedure cost_row (p_which in pls_integer, p_cost in number, p_level in out number, p_end_pos in out number) is
    l number;
  begin
    if g_bypass then return; end if;
    l := cost_level(p_which, p_cost);
    if l is not null then
      p_level := l;
      p_end_pos := nvl(cost_end_pos(p_which, l), p_end_pos);
    end if;
  end cost_row;

  -- ACCOMPANY_ACCOUNT buttons: every journal / account / cost centre / estimate period not yet in the company
  function ac_company_all (p_rowid in varchar2, p_kind in varchar2) return varchar2 is
    l_c number := company_of(p_rowid);
    l_n number := 0;
  begin
    case upper(p_kind)
    when 'ENTRY' then
      for r in (select entry_year, entry_type from ac_trn_codes t
                 where (entry_year, entry_type) not in (select p.entry_year, p.entry_type from ac_company_entry p where p.company_code = l_c)
                 order by entry_year, entry_type) loop
        insert into ac_company_entry (entry_year, entry_type, company_code) values (r.entry_year, r.entry_type, l_c);
        l_n := l_n + 1;
      end loop;
    when 'MASTER' then
      for r in (select account_number, account_level from ac_master a
                 where account_number not in (select p.account_number from ac_company_master p where p.company_code = l_c)
                 order by account_number) loop
        insert into ac_company_master (account_number, company_code, account_level, account_end_pos)
        values (r.account_number, l_c, r.account_level, acc_end_pos(r.account_level));
        l_n := l_n + 1;
      end loop;
    when 'COST1' then
      for r in (select cost_code, cost_level from ac_cost_centers a
                 where cost_code not in (select p.cost_code from ac_company_cost1 p where p.company_code = l_c)
                 order by cost_code) loop
        insert into ac_company_cost1 (cost_code, company_code, cost_level, cost_end_pos)
        values (r.cost_code, l_c, r.cost_level, cost_end_pos(1, r.cost_level));
        l_n := l_n + 1;
      end loop;
    when 'COST2' then
      for r in (select cost_code, cost_level from ac_cost_centers2 a
                 where cost_code not in (select p.cost_code from ac_company_cost2 p where p.company_code = l_c)
                 order by cost_code) loop
        insert into ac_company_cost2 (cost_code, company_code, cost_level, cost_end_pos)
        values (r.cost_code, l_c, r.cost_level, cost_end_pos(2, r.cost_level));
        l_n := l_n + 1;
      end loop;
    when 'PERIOD' then
      for r in (select period_code from ac_estimate_periods a
                 where period_code not in (select p.period_code from ac_company_est_period p where p.company_code = l_c)
                 order by period_code) loop
        insert into ac_company_est_period (company_code, period_code) values (l_c, r.period_code);
        l_n := l_n + 1;
      end loop;
    end case;
    g_msg := m('تمت إضافة ' || l_n || ' سجل', l_n || ' row(s) added');
    return p_rowid;
  end ac_company_all;

  -- ACPASS_ADMIN buttons (per company of the group): the group's grants of that company are replaced by everything the
  -- company has (AC_COMPANY_ENTRY / _MASTER / _COST1 / _COST2 / _EST_PERIOD).
  function ac_grant_all (p_rowid in varchar2, p_company in number, p_kind in varchar2) return varchar2 is
    l_pw number := group_of(p_rowid);
    l_n  number := 0;
  begin
    if p_company is null then err(-20115, 'يجب ادخال رقم الشركة', 'Enter the company'); end if;
    select count(*) into l_n from group_company where password_number = l_pw and company_code = p_company;
    if l_n = 0 then
      err(-20116, 'الشركة ' || p_company || ' ليست من شركات المجموعة', 'Company ' || p_company || ' is not a company of the group');
    end if;
    l_n := 0;
    g_cascade := true;                    -- no subtree deletes while the grants are replaced
    begin
      case upper(p_kind)
      when 'ENTRY' then
        delete from ac_password_entry where password_number = l_pw and company_code = p_company;
        for r in (select entry_year, entry_type from ac_company_entry where company_code = p_company order by entry_year, entry_type) loop
          insert into ac_password_entry (company_code, entry_year, entry_type, password_number) values (p_company, r.entry_year, r.entry_type, l_pw);
          l_n := l_n + 1;
        end loop;
      when 'MASTER' then
        delete from ac_password_master where password_number = l_pw and company_code = p_company;
        for r in (select c.account_number, a.account_level from ac_company_master c join ac_master a on a.account_number = c.account_number
                   where c.company_code = p_company order by c.account_number) loop
          insert into ac_password_master (account_number, company_code, password_number, account_level, account_end_pos)
          values (r.account_number, p_company, l_pw, r.account_level, acc_end_pos(r.account_level));
          l_n := l_n + 1;
        end loop;
      when 'COST1' then
        delete from ac_password_cost1 where password_number = l_pw and company_code = p_company;
        for r in (select c.cost_code, a.cost_level from ac_company_cost1 c join ac_cost_centers a on a.cost_code = c.cost_code
                   where c.company_code = p_company order by c.cost_code) loop
          insert into ac_password_cost1 (cost_code, company_code, password_number, cost_level, cost_end_pos)
          values (r.cost_code, p_company, l_pw, r.cost_level, cost_end_pos(1, r.cost_level));
          l_n := l_n + 1;
        end loop;
      when 'COST2' then
        delete from ac_password_cost2 where password_number = l_pw and company_code = p_company;
        for r in (select c.cost_code, a.cost_level from ac_company_cost2 c join ac_cost_centers2 a on a.cost_code = c.cost_code
                   where c.company_code = p_company order by c.cost_code) loop
          insert into ac_password_cost2 (cost_code, company_code, password_number, cost_level, cost_end_pos)
          values (r.cost_code, p_company, l_pw, r.cost_level, cost_end_pos(2, r.cost_level));
          l_n := l_n + 1;
        end loop;
      when 'PERIOD' then
        delete from ac_password_est_period where password_number = l_pw and company_code = p_company;
        for r in (select period_code from ac_company_est_period where company_code = p_company order by period_code) loop
          insert into ac_password_est_period (company_code, period_code, password_number) values (p_company, r.period_code, l_pw);
          l_n := l_n + 1;
        end loop;
      end case;
      g_cascade := false;
    exception when others then
      g_cascade := false; raise;
    end;
    g_msg := m('تمت إضافة ' || l_n || ' سجل للمجموعة', l_n || ' grant(s) added to the group');
    return p_rowid;
  end ac_grant_all;

  -- "إضافة الحسابات الرئيسيه للحسابات الفرعيه المضافه" (PUSH_BUTTON138) / "إضافة مراكز التكلفة الرئيسيه ..." (ITEM149):
  -- for every granted account (cost centre) below level 1, each parent (RPAD(SUBSTR(code, 1, end of level - i), 12 | 9, 0))
  -- that exists in the chart is added to the company (AC_COMPANY_*) and to the group (AC_PASSWORD_*) when missing.
  function ac_add_parents (p_rowid in varchar2, p_company in number, p_kind in varchar2) return varchar2 is
    l_pw    number := group_of(p_rowid);
    l_n     number := 0;
    l_len   pls_integer;
    l_end   number;
    l_par   number;
    l_lvl   number;
    l_cnt   number;
    l_which pls_integer;
    type t_rows is table of number;
    l_codes t_rows;
    l_lvls  t_rows;
  begin
    if p_company is null then err(-20115, 'يجب ادخال رقم الشركة', 'Enter the company'); end if;
    if upper(p_kind) = 'MASTER' then
      select account_number, account_level bulk collect into l_codes, l_lvls
        from ac_password_master where account_level > 1 and company_code = p_company and password_number = l_pw;
      l_len := 12;
    else
      l_which := case upper(p_kind) when 'COST1' then 1 else 2 end;
      if l_which = 1 then
        select cost_code, cost_level bulk collect into l_codes, l_lvls
          from ac_password_cost1 where cost_level > 1 and company_code = p_company and password_number = l_pw;
      else
        select cost_code, cost_level bulk collect into l_codes, l_lvls
          from ac_password_cost2 where cost_level > 1 and company_code = p_company and password_number = l_pw;
      end if;
      l_len := 9;
    end if;
    for i in 1 .. l_codes.count loop
      for k in 1 .. l_lvls(i) - 1 loop
        l_end := case when l_len = 12 then acc_end_pos(l_lvls(i) - k) else cost_end_pos(l_which, l_lvls(i) - k) end;
        continue when l_end is null;
        l_par := to_number(rpad(substr(to_char(l_codes(i)), 1, l_end), l_len, '0'));
        if l_len = 12 then
          l_lvl := acc_level(l_par);
          continue when l_lvl is null;
          select count(*) into l_cnt from ac_company_master where account_number = l_par and company_code = p_company;
          if l_cnt = 0 then
            insert into ac_company_master (account_number, company_code, account_level, account_end_pos) values (l_par, p_company, l_lvl, l_end);
          end if;
          select count(*) into l_cnt from ac_password_master where account_number = l_par and company_code = p_company and password_number = l_pw;
          if l_cnt = 0 then
            insert into ac_password_master (account_number, company_code, password_number, account_level, account_end_pos)
            values (l_par, p_company, l_pw, l_lvl, l_end);
            l_n := l_n + 1;
          end if;
        else
          l_lvl := cost_level(l_which, l_par);
          continue when l_lvl is null;
          if l_which = 1 then
            select count(*) into l_cnt from ac_company_cost1 where cost_code = l_par and company_code = p_company;
            if l_cnt = 0 then
              insert into ac_company_cost1 (cost_code, company_code, cost_level, cost_end_pos) values (l_par, p_company, l_lvl, l_end);
            end if;
            select count(*) into l_cnt from ac_password_cost1 where cost_code = l_par and company_code = p_company and password_number = l_pw;
            if l_cnt = 0 then
              insert into ac_password_cost1 (cost_code, company_code, password_number, cost_level, cost_end_pos)
              values (l_par, p_company, l_pw, l_lvl, l_end);
              l_n := l_n + 1;
            end if;
          else
            select count(*) into l_cnt from ac_company_cost2 where cost_code = l_par and company_code = p_company;
            if l_cnt = 0 then
              insert into ac_company_cost2 (cost_code, company_code, cost_level, cost_end_pos) values (l_par, p_company, l_lvl, l_end);
            end if;
            select count(*) into l_cnt from ac_password_cost2 where cost_code = l_par and company_code = p_company and password_number = l_pw;
            if l_cnt = 0 then
              insert into ac_password_cost2 (cost_code, company_code, password_number, cost_level, cost_end_pos)
              values (l_par, p_company, l_pw, l_lvl, l_end);
              l_n := l_n + 1;
            end if;
          end if;
        end if;
      end loop;
    end loop;
    g_msg := m('تمت إضافة ' || l_n || ' سجل رئيسى', l_n || ' parent(s) added');
    return p_rowid;
  end ac_add_parents;

  -- deleting a granted main account / cost centre of ACPASS_ADMIN deletes its sub accounts of the same company and group
  -- ("انت على وشك حذف حساب رئيسى -سوف يتم حذف كل الحسابات الفرعيه التابعه له"); called from the compound delete triggers
  -- after the statement (the rows of the same table cannot be deleted from a row trigger).
  procedure ac_subtree_delete (p_kind in varchar2, p_code in number, p_company in number, p_password in number, p_level in number) is
    l_end number;
  begin
    if p_level is null then return; end if;
    l_end := case upper(p_kind) when 'MASTER' then acc_end_pos(p_level) when 'COST1' then cost_end_pos(1, p_level) else cost_end_pos(2, p_level) end;
    if l_end is null then return; end if;
    g_cascade := true;
    begin
      if upper(p_kind) = 'MASTER' then
        delete from ac_password_master
         where substr(to_char(account_number), 1, l_end) = substr(to_char(p_code), 1, l_end)
           and company_code = p_company and password_number = p_password;
      elsif upper(p_kind) = 'COST1' then
        delete from ac_password_cost1
         where substr(to_char(cost_code), 1, l_end) = substr(to_char(p_code), 1, l_end)
           and company_code = p_company and password_number = p_password;
      else
        delete from ac_password_cost2
         where substr(to_char(cost_code), 1, l_end) = substr(to_char(p_code), 1, l_end)
           and company_code = p_company and password_number = p_password;
      end if;
      g_cascade := false;
    exception when others then
      g_cascade := false; raise;
    end;
  end ac_subtree_delete;

  -- relation checks of ACPASS_ADMIN (GROUP_COMPANY -> grants): a company cannot leave the group while the group has
  -- GL grants of that company
  procedure group_company_delete (p_company in number, p_password_number in number) is
    l number;
  begin
    if g_bypass or g_cascade or nvl(cur_form, '-') <> 'ACPASS_ADMIN' then return; end if;
    select count(*) into l from (
      select 1 from ac_password_entry where company_code = p_company and password_number = p_password_number
      union all select 1 from ac_password_master where company_code = p_company and password_number = p_password_number
      union all select 1 from ac_password_cost1 where company_code = p_company and password_number = p_password_number
      union all select 1 from ac_password_cost2 where company_code = p_company and password_number = p_password_number
      union all select 1 from ac_password_est_period where company_code = p_company and password_number = p_password_number);
    if l > 0 then
      err(-20117, 'لا يمكن حذف الشركة من المجموعة لوجود صلاحيات حسابات لها', 'Cannot delete master record when matching detail records exist.');
    end if;
  end group_company_delete;

  -- ------------------------------------------------------------------ SEPASS_TRN
  -- "كل المخازن" / "كل الحركات" / "كل المجموعات": DELETE + INSERT ... SELECT of the legacy (stores: FLAG 1, price / discount /
  -- bonus rights 0; item groups: active groups only)
  function st_all (p_rowid in varchar2, p_kind in varchar2) return varchar2 is
    l_pw number := group_of(p_rowid);
    l_n  number := 0;
  begin
    case upper(p_kind)
    when 'STORE' then
      delete from st_store_password where password_number = l_pw;
      for r in (select store_code from st_store order by store_code) loop
        insert into st_store_password (store_code, password_number, flag, sales_price_flag, disc_price_flag, bonus_flag)
        values (r.store_code, l_pw, 1, 0, 0, 0);
        l_n := l_n + 1;
      end loop;
    when 'TRNS' then
      delete from st_trnstype_password where password_number = l_pw;
      for r in (select trns_type_code from st_trns_type order by trns_type_code) loop
        insert into st_trnstype_password (password_number, trns_type_code, flag) values (l_pw, r.trns_type_code, 1);
        l_n := l_n + 1;
      end loop;
    when 'GROUP' then
      delete from st_group_password where password_number = l_pw;
      for r in (select item_group_code from st_item_group where nvl(group_status, 0) = 1 order by item_group_code) loop
        insert into st_group_password (password_number, group_code, flag) values (l_pw, r.item_group_code, 1);
        l_n := l_n + 1;
      end loop;
    end case;
    g_msg := m('تمت إضافة ' || l_n || ' سجل', l_n || ' row(s) added');
    return p_rowid;
  end st_all;

  -- "إختيار الكل" / "استبعاد الكل": FLAG of every row of the group
  function set_flags (p_rowid in varchar2, p_table in varchar2, p_flag in number) return varchar2 is
    l_pw number := group_of(p_rowid);
    l_t  varchar2(30) := upper(p_table);
    l_n  number;
  begin
    if l_t not in ('ST_STORE_PASSWORD', 'ST_TRNSTYPE_PASSWORD', 'ST_GROUP_PASSWORD', 'AR_TRNSTYPE_PASSWORD', 'VN_TRNSTYPE_PASSWORD',
                   'RAP_TRNS_PASSWORD', 'CHECK_TRNS_PASSWORD') then
      err(-20118, 'جدول غير معروف', 'Unknown table');
    end if;
    execute immediate 'update ' || l_t || ' set flag = :f where password_number = :p' using p_flag, l_pw;
    l_n := sql%rowcount;
    g_msg := m('تم تعديل ' || l_n || ' سجل', l_n || ' row(s) updated');
    return p_rowid;
  end set_flags;

  -- ------------------------------------------------------------------ ARPASS
  function ar_all_trns (p_rowid in varchar2) return varchar2 is
    l_pw number := group_of(p_rowid);
    l_n  number := 0;
  begin
    for r in (select id from ar_trnstype where id not in (select trns_id from ar_trnstype_password where password_number = l_pw)
               order by to_number(id)) loop
      insert into ar_trnstype_password (password_number, trns_id, flag) values (l_pw, r.id, 1);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تمت إضافة ' || l_n || ' حركة', l_n || ' type(s) added');
    return p_rowid;
  end ar_all_trns;

  -- ALL_CUST_PUSH: active customers of the main area / sub area / category / salesman filters not yet granted
  function ar_all_customers (p_rowid in varchar2, p_mainarea in number, p_subarea in number, p_ctgry in number,
                             p_salesman in number) return varchar2 is
    l_pw number := group_of(p_rowid);
    l_n  number := 0;
  begin
    for r in (select code from customer
               where customer_status = 1
                 and (p_mainarea is null or mainarea_id = p_mainarea)
                 and (p_subarea is null or subarea_id = p_subarea)
                 and (p_ctgry is null or code in (select customer_code from ar_cust_salesman where ctgry_code = p_ctgry))
                 and (p_salesman is null or code in (select customer_code from ar_cust_salesman where salesman_code = p_salesman))
                 and code not in (select customer_code from ar_cust_password where password_number = l_pw)
               order by to_number(code)) loop
      insert into ar_cust_password (password_number, customer_code) values (l_pw, r.code);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تمت إضافة ' || l_n || ' عميل', l_n || ' customer(s) added');
    return p_rowid;
  end ar_all_customers;

  -- ALL_SALESMAN_PUSH: salesmen of the sub area / category filters not yet granted
  function ar_all_salesmen (p_rowid in varchar2, p_subarea in number, p_ctgry in number) return varchar2 is
    l_pw number := group_of(p_rowid);
    l_n  number := 0;
  begin
    for r in (select code from salesman
               where (p_subarea is null or subarea_id = p_subarea)
                 and (p_ctgry is null or ctgry_code = p_ctgry)
                 and code not in (select salesman_code from ar_salesman_password where password_number = l_pw)
               order by to_number(code)) loop
      insert into ar_salesman_password (password_number, salesman_code) values (l_pw, r.code);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تمت إضافة ' || l_n || ' مندوب', l_n || ' salesman(men) added');
    return p_rowid;
  end ar_all_salesmen;

  -- ------------------------------------------------------------------ VNPASS
  function vn_all_trns (p_rowid in varchar2) return varchar2 is
    l_pw number := group_of(p_rowid);
    l_n  number := 0;
  begin
    for r in (select id from vn_trnstype where id not in (select trns_id from vn_trnstype_password where password_number = l_pw)
               order by to_number(id)) loop
      insert into vn_trnstype_password (password_number, trns_id, flag) values (l_pw, r.id, 1);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تمت إضافة ' || l_n || ' حركة', l_n || ' type(s) added');
    return p_rowid;
  end vn_all_trns;

  procedure vn_range_row (p_from in number, p_to in number) is
  begin
    if g_bypass then return; end if;
    if p_to < p_from then
      err(-20119, 'يجب ان يكون كود الى مورد اكبر من او مساوى لكود من مورد', 'To supplier must be greater than or equal to from supplier');
    end if;
  end vn_range_row;

  procedure vn_ranges_check (p_password_number in number) is
  begin
    for r in (select a.from_supplier_code f from vn_supplier_password a, vn_supplier_password b
               where a.password_number = p_password_number and b.password_number = p_password_number and a.rowid <> b.rowid
                 and a.from_supplier_code <= b.to_supplier_code and b.from_supplier_code <= a.to_supplier_code
                 and rownum = 1) loop
      err(-20120, 'هذا المورد موجود فى مدى قبل ذلك', 'This supplier is already inside another range');
    end loop;
  end vn_ranges_check;

  -- ------------------------------------------------------------------ RAPPASS / CHECKPASS / PYPASS
  function rap_all_boxes (p_rowid in varchar2) return varchar2 is
    l_pw number := group_of(p_rowid);
    l_n  number := 0;
  begin
    for r in (select box_code from rp_boxs where box_code not in (select box_code from rp_boxs_password where password_number = l_pw)
               order by box_code) loop
      insert into rp_boxs_password (password_number, box_code) values (l_pw, r.box_code);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تمت إضافة ' || l_n || ' صندوق', l_n || ' box(es) added');
    return p_rowid;
  end rap_all_boxes;

  function rap_all_trns (p_rowid in varchar2) return varchar2 is
    l_pw number := group_of(p_rowid);
    l_n  number := 0;
  begin
    delete from rap_trns_password r where r.password_number = l_pw;
    for r in (select trns_type_code from rp_trns_type order by trns_type_code) loop
      insert into rap_trns_password (password_number, trns_type_code) values (l_pw, r.trns_type_code);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تمت إضافة ' || l_n || ' حركة', l_n || ' type(s) added');
    return p_rowid;
  end rap_all_trns;

  function check_all_banks (p_rowid in varchar2) return varchar2 is
    l_pw number := group_of(p_rowid);
    l_n  number := 0;
  begin
    for r in (select code from bank where code not in (select bank_code from bank_password where password_number = l_pw) order by code) loop
      insert into bank_password (password_number, bank_code) values (l_pw, r.code);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تمت إضافة ' || l_n || ' بنك', l_n || ' bank(s) added');
    return p_rowid;
  end check_all_banks;

  function check_all_trns (p_rowid in varchar2) return varchar2 is
    l_pw number := group_of(p_rowid);
    l_n  number := 0;
  begin
    delete from check_trns_password where password_number = l_pw;
    for r in (select trns_type_code from check_trns_type order by trns_type_code) loop
      insert into check_trns_password (password_number, trns_type_code) values (l_pw, r.trns_type_code);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تمت إضافة ' || l_n || ' حركة', l_n || ' type(s) added');
    return p_rowid;
  end check_all_trns;

  function py_all_dept (p_rowid in varchar2) return varchar2 is
    l_pw number := group_of(p_rowid);
    l_n  number := 0;
  begin
    for r in (select company_code, d_code from py_dept_hier
               where (d_code, company_code) not in (select d_code, company_code from py_dept_hier_password where password_number = l_pw)
               order by company_code, d_code) loop
      insert into py_dept_hier_password (company_code, d_code, password_number) values (r.company_code, r.d_code, l_pw);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تمت إضافة ' || l_n || ' هيكل', l_n || ' structure(s) added');
    return p_rowid;
  end py_all_dept;

  -- duplicate grants with the legacy messages (single-row INSERT of the grid; the PK would give a generic message)
  procedure dup_row (p_table in varchar2, p_password_number in number, p_code in number, p_code2 in number default null) is
    l number;
  begin
    if g_bypass or not page_request then return; end if;
    case upper(p_table)
    when 'RP_BOXS_PASSWORD' then
      select count(1) into l from rp_boxs_password where password_number = p_password_number and box_code = p_code;
      if l > 0 then err(-20121, 'تم إدخال هذا الصندوق لهذا المستخدم من قبل', 'This box was already entered'); end if;
    when 'BANK_PASSWORD' then
      select count(1) into l from bank_password where password_number = p_password_number and bank_code = p_code;
      if l > 0 then err(-20122, 'تم إدخال هذا البنك لهذا المستخدم من قبل', 'This bank was already entered'); end if;
    when 'PY_DEPT_HIER_PASSWORD' then
      select count(1) into l from py_dept_hier_password where password_number = p_password_number and company_code = p_code and d_code = p_code2;
      if l > 0 then err(-20123, 'تم إدخال هذا الهيكل من قبل', 'This structure was already entered'); end if;
    end case;
  end dup_row;

  -- ------------------------------------------------------------------ COMPANY, COMM_WAY, LICENCE
  procedure company_row (p_inserting in boolean, p_company in number) is
    l number;
  begin
    if g_bypass or not p_inserting or not page_request then return; end if;
    select count(1) into l from company where company_code = p_company;
    if l > 0 then
      err(-20124, 'رقم الشركة موجود من قبل', 'Company code already exists');
    end if;
  end company_row;

  -- legacy POST-INSERT: per installed system the company gets its parameter row (GL AC_BASIC with the legacy literal values,
  -- payroll PY_BASIC_H for systems 60 / 61)
  procedure company_created (p_company in number) is
    l number;
  begin
    if p_company is null then return; end if;
    for s in (select distinct system_number from sys_systems) loop
      if s.system_number = 1 then
        select count(*) into l from ac_basic where company_code = p_company;
        if l = 0 then
          insert into ac_basic (company_code, current_year, currency_stts, estimate_test, cost_code1_bal, cost_code2_bal, del_bal_sides,
                                doc_repeat, fx_usr_entry, fx_usr_cost1, fx_usr_cost2)
          values (p_company, 2001, 0, 0, 0, 0, 0, 3, 2, 2, 2);
        end if;
      elsif s.system_number in (60, 61) then
        select count(*) into l from py_basic_h where company_code = p_company;
        if l = 0 then
          insert into py_basic_h (company_code, vcsn_end_srvc_year_days, renew_mode, dscn_auth, loan_auth, deduction_auth, incrs_auth,
                                  overtime_auth, pys_auth, vcnc_auth, end_srvc_auth, move_auth, house_incrs_flag)
          values (p_company, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1);
        end if;
      end if;
    end loop;
  end company_created;

  procedure company_delete (p_company in number) is
    l number;
  begin
    if g_bypass then return; end if;
    owner_only('COMPANY', 'تحذف الشركة من شاشة بيانات الشركات فقط (توجد بيانات مرتبطة بها)');
    select count(*) into l from sys_systems where system_number = 1;
    if l > 0 then
      delete from ac_basic where company_code = p_company;
    end if;
  end company_delete;

  procedure licence_dates (p_start in date, p_end in date, p_renewal in date) is
  begin
    if g_bypass then return; end if;
    if p_end < p_start then
      err(-20125, 'تاريخ الانتهاء اقل من تاريخ الاصدار', 'Expiry date is before the issue date');
    end if;
    if p_renewal < p_end then
      err(-20126, 'تاريخ التجديد اقل من تاريخ الانتهاء', 'Renewal date is before the expiry date');
    end if;
  end licence_dates;

  -- company logo (legacy image item COMPANY_LOGO loaded from a file with WEBUTIL / READ_IMAGE_FILE)
  function load_logo (p_rowid in varchar2, p_file in varchar2) return varchar2 is
    l_blob blob;
    l_mime varchar2(255);
  begin
    begin
      select blob_content, mime_type into l_blob, l_mime from apex_application_temp_files where name = p_file;
    exception when no_data_found then
      err(-20127, 'يجب اختيار ملف الصورة', 'Choose the image file');
    end;
    if lower(nvl(l_mime, 'image/')) not like 'image/%' then
      err(-20128, 'الملف ليس صورة', 'The file is not an image');
    end if;
    update company set company_logo = l_blob where rowid = chartorowid(p_rowid);
    g_msg := m('تم تحميل الشعار', 'Logo loaded');
    return p_rowid;
  end load_logo;

  procedure code_row (p_table in varchar2, p_inserting in boolean, p_code in number) is
    l number;
  begin
    if g_bypass or not p_inserting or not page_request then return; end if;
    if upper(p_table) = 'COMM_WAY' then
      select count(1) into l from comm_way where comm_code = p_code;
      if l > 0 then err(-20129, 'رقم نوع وسيلة الاتصال موجود من قبل', 'Communication way code already exists'); end if;
    elsif upper(p_table) = 'LICENCE' then
      select count(1) into l from licence where licence_code = p_code;
      if l > 0 then err(-20130, 'رقم نوع التصريح موجود من قبل', 'Licence type code already exists'); end if;
    end if;
  end code_row;

  -- SYS_FORMS relation check: a system with screens or reports cannot be deleted
  procedure sys_systems_delete (p_system in number) is
    l number;
  begin
    if g_bypass then return; end if;
    select count(*) into l from (select 1 from sys_files s where s.system_number = p_system
                                 union all select 1 from sys_reports s where s.system_number = p_system);
    if l > 0 or nvl(cur_form, '-') = 'SYS_FORMS' then     -- SYS_FORMS: its screens / reports were removed by the page first
      err(-20131, 'لا يمكن حذف النظام لوجود شاشات أو تقارير له', 'Cannot delete master record when matching detail records exist.');
    end if;
  end sys_systems_delete;

end app_rules3_se;
/
show errors package body app_rules3_se

-- ---------------------------------------------------------------------------------------------------
-- Delete hooks (the Stage C rules mechanism has row rules for INSERT / UPDATE only).  APEX sessions only.
-- ---------------------------------------------------------------------------------------------------
create or replace trigger app_rules3_se_users_bd
before delete on users for each row
begin
  if v('APP_ID') is not null then
    app_rules3_se.users_delete(:old.users_code);
  end if;
end;
/
show errors trigger app_rules3_se_users_bd

create or replace trigger app_rules3_se_password_bd
before delete on password for each row
begin
  if v('APP_ID') is not null then
    app_rules3_se.password_delete(:old.password_number);
  end if;
end;
/
show errors trigger app_rules3_se_password_bd

create or replace trigger app_rules3_se_company_bd
before delete on company for each row
begin
  if v('APP_ID') is not null then
    app_rules3_se.company_delete(:old.company_code);
  end if;
end;
/
show errors trigger app_rules3_se_company_bd

create or replace trigger app_rules3_se_syssys_bd
before delete on sys_systems for each row
begin
  if v('APP_ID') is not null then
    app_rules3_se.sys_systems_delete(:old.system_number);
  end if;
end;
/
show errors trigger app_rules3_se_syssys_bd

create or replace trigger app_rules3_se_grpcomp_bd
before delete on group_company for each row
begin
  if v('APP_ID') is not null then
    app_rules3_se.group_company_delete(:old.company_code, :old.password_number);
  end if;
end;
/
show errors trigger app_rules3_se_grpcomp_bd

-- ACPASS_ADMIN: a deleted main account / cost centre takes its sub accounts along (after the statement: same table)
create or replace trigger app_rules3_se_pwm_cd
for delete on ac_password_master compound trigger
  type t_rec is record (code number, comp number, pw number, lvl number);
  type t_tab is table of t_rec index by pls_integer;
  g t_tab;
  before each row is
  begin
    if v('APP_ID') is not null and not app_rules3_se.bypass and not app_rules3_se.in_cascade
       and app_rules3_se.cur_form = 'ACPASS_ADMIN' then
      g(g.count + 1).code := :old.account_number;
      g(g.count).comp := :old.company_code; g(g.count).pw := :old.password_number; g(g.count).lvl := :old.account_level;
    end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. g.count loop
      app_rules3_se.ac_subtree_delete('MASTER', g(i).code, g(i).comp, g(i).pw, g(i).lvl);
    end loop;
    g.delete;
  end after statement;
end app_rules3_se_pwm_cd;
/
show errors trigger app_rules3_se_pwm_cd

create or replace trigger app_rules3_se_pwc1_cd
for delete on ac_password_cost1 compound trigger
  type t_rec is record (code number, comp number, pw number, lvl number);
  type t_tab is table of t_rec index by pls_integer;
  g t_tab;
  before each row is
  begin
    if v('APP_ID') is not null and not app_rules3_se.bypass and not app_rules3_se.in_cascade
       and app_rules3_se.cur_form = 'ACPASS_ADMIN' then
      g(g.count + 1).code := :old.cost_code;
      g(g.count).comp := :old.company_code; g(g.count).pw := :old.password_number; g(g.count).lvl := :old.cost_level;
    end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. g.count loop
      app_rules3_se.ac_subtree_delete('COST1', g(i).code, g(i).comp, g(i).pw, g(i).lvl);
    end loop;
    g.delete;
  end after statement;
end app_rules3_se_pwc1_cd;
/
show errors trigger app_rules3_se_pwc1_cd

create or replace trigger app_rules3_se_pwc2_cd
for delete on ac_password_cost2 compound trigger
  type t_rec is record (code number, comp number, pw number, lvl number);
  type t_tab is table of t_rec index by pls_integer;
  g t_tab;
  before each row is
  begin
    if v('APP_ID') is not null and not app_rules3_se.bypass and not app_rules3_se.in_cascade
       and app_rules3_se.cur_form = 'ACPASS_ADMIN' then
      g(g.count + 1).code := :old.cost_code;
      g(g.count).comp := :old.company_code; g(g.count).pw := :old.password_number; g(g.count).lvl := :old.cost_level;
    end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. g.count loop
      app_rules3_se.ac_subtree_delete('COST2', g(i).code, g(i).comp, g(i).pw, g(i).lvl);
    end loop;
    g.delete;
  end after statement;
end app_rules3_se_pwc2_cd;
/
show errors trigger app_rules3_se_pwc2_cd
