-- =====================================================================================
-- ASCON ERP on APEX 24.2 : core objects in schema SMART (run as SMART).  Idempotent.
--   APP_USER_AUTH  hashed credentials replacing plaintext USERS.PASSWORD after first login
--   APP_PAGE_MAP   APEX page  <->  legacy form / report registry row (security + menu)
--   APP_MENU       navigation tree generated from SYS_SYSTEMS / SYS_FILES / SYS_REPORTS
--   APP_SEC        authentication, post-authentication, authorization, password change
-- =====================================================================================
set define off
whenever sqlerror continue

create table app_user_auth (
  users_code    number        constraint app_user_auth_pk primary key,
  pwd_hash      varchar2(200),
  salt          varchar2(64),
  must_change   char(1)       default 'Y' not null,
  failed_count  number        default 0   not null,
  locked        char(1)       default 'N' not null,
  last_login    date,
  changed_on    date
);

create table app_page_map (
  page_id        number        constraint app_page_map_pk primary key,
  kind           varchar2(10)  not null,          -- FORM | FORMPAGE | REPORT | PROCESS
  form_name      varchar2(100),
  system_number  number,
  file_serial    number,                          -- FORM: SYS_FILES.FILE_SERIAL, REPORT: SYS_REPORTS.REPORT_SERIAL
  pattern        varchar2(20),                    -- GRID | REPORT_FORM | MASTER_DETAIL | PROCESS | REPORT
  title_a        varchar2(400),
  title_e        varchar2(400),
  parent_page_id number,
  status         varchar2(20)  default 'GENERATED',
  notes          varchar2(4000)
);

-- every registry row (system, serial) that opens a page; a legacy form can sit under several menu entries
create table app_page_serials (
  page_id        number not null,
  system_number  number not null,
  file_serial    number not null,
  constraint app_page_serials_pk primary key (page_id, system_number, file_serial)
);

create table app_menu (
  id             number        constraint app_menu_pk primary key,
  parent_id      number,
  seq            number,
  label_a        varchar2(400),
  label_e        varchar2(400),
  kind           varchar2(10),                    -- SYSTEM | GROUP | FORM | REPORT
  page_id        number,
  item_values    varchar2(400),                   -- extra URL item values, e.g. P10010_MODE:5
  system_number  number,
  file_serial    number,
  icon           varchar2(100)
);
create index app_menu_parent_ix on app_menu(parent_id);

create or replace package app_sec authid definer as
  function  authenticate (p_username in varchar2, p_password in varchar2) return boolean;
  procedure post_auth;
  function  must_change return boolean;
  procedure change_password (p_old in varchar2, p_new in varchar2);
  -- p_op : Q query/open, I insert, U update, D delete
  function  can_page (p_page_id in number, p_op in varchar2 default 'Q') return boolean;
  function  can_page_yn (p_page_id in number, p_op in varchar2 default 'Q') return varchar2;
  function  is_admin return boolean;
  function  lang return varchar2;
  function  hash_pwd (p_user in number, p_pwd in varchar2, p_salt in varchar2) return varchar2;
end app_sec;
/

create or replace package body app_sec as

  c_iterations constant pls_integer := 2000;

  function hash_pwd (p_user in number, p_pwd in varchar2, p_salt in varchar2) return varchar2 is
    l raw(64);
  begin
    l := sys.dbms_crypto.hash(utl_raw.cast_to_raw(p_salt || ':' || p_user || ':' || p_pwd), sys.dbms_crypto.hash_sh512);
    for i in 1 .. c_iterations loop
      l := sys.dbms_crypto.hash(utl_raw.concat(l, utl_raw.cast_to_raw(p_salt)), sys.dbms_crypto.hash_sh512);
    end loop;
    return rawtohex(l);
  end hash_pwd;

  function user_code (p_username in varchar2) return number is
  begin
    return to_number(trim(p_username));
  exception when value_error then
    return null;
  end user_code;

  -- the legacy login's password encoding (schema function ENCODE_PASSWORD, wrapped); null when it is not installed
  function legacy_encode (p in varchar2) return varchar2 is
    r varchar2(4000);
  begin
    execute immediate 'begin :r := encode_password(:p); end;' using out r, in p;
    return r;
  exception when others then
    return null;
  end legacy_encode;

  function authenticate (p_username in varchar2, p_password in varchar2) return boolean is
    l_code  number := user_code(p_username);
    l_usr   users%rowtype;
    l_auth  app_user_auth%rowtype;
    l_ok    boolean := false;
    l_salt  varchar2(64);
  begin
    if l_code is null or p_password is null then return false; end if;
    begin
      select * into l_usr from users where users_code = l_code;
    exception when no_data_found then return false;
    end;
    if nvl(l_usr.stop_flag, 0) = 1 then return false; end if;

    begin
      select * into l_auth from app_user_auth where users_code = l_code for update;
    exception when no_data_found then l_auth.users_code := null;
    end;

    if l_auth.users_code is not null and l_auth.locked = 'Y' then
      return false;
    end if;

    if l_auth.users_code is not null and l_auth.pwd_hash is not null then
      l_ok := hash_pwd(l_code, p_password, l_auth.salt) = l_auth.pwd_hash;
    else
      -- first login in the new system: accept the legacy password once (USERS.PASSWORD holds it as typed or, for most users,
      -- as ENCODE_PASSWORD(typed) - the legacy login encoded it: "0" is stored as "48"), then store it hashed
      l_ok := l_usr.password is not null and (l_usr.password = p_password or l_usr.password = legacy_encode(p_password));
      if l_ok then
        l_salt := rawtohex(sys.dbms_crypto.randombytes(16));
        merge into app_user_auth a using (select l_code c from dual) s on (a.users_code = s.c)
        when matched then update set pwd_hash = hash_pwd(l_code, p_password, l_salt), salt = l_salt, must_change = 'Y', failed_count = 0
        when not matched then insert (users_code, pwd_hash, salt, must_change, failed_count, locked)
                              values (l_code, hash_pwd(l_code, p_password, l_salt), l_salt, 'Y', 0, 'N');
      end if;
    end if;

    if l_ok then
      update app_user_auth set failed_count = 0, last_login = sysdate where users_code = l_code;
    elsif l_auth.users_code is not null then
      update app_user_auth set failed_count = failed_count + 1,
                               locked = case when failed_count + 1 >= 6 then 'Y' else locked end
       where users_code = l_code;
    end if;
    commit;
    return l_ok;
  end authenticate;

  procedure post_auth is
    l_code  number := user_code(v('APP_USER'));
    l_name  users.users_name%type;
    l_name_e users.users_name_e%type;
    l_lang  users.lang_flag%type;
    l_grp   number;
    l_comp  number;
  begin
    select users_name, users_name_e, lang_flag into l_name, l_name_e, l_lang from users where users_code = l_code;
    begin
      select password_number into l_grp from (
        select password_number from group_users where users_code = l_code order by case when isdefault = 'Y' then 0 else 1 end)
       where rownum = 1;
    exception when no_data_found then l_grp := null;
    end;
    begin
      select company_code into l_comp from (
        select company_code from group_company where password_number = l_grp order by case when isdefault = 'Y' then 0 else 1 end)
       where rownum = 1;
    exception when no_data_found then
      select min(company_code) into l_comp from company;
    end;
    apex_util.set_session_state('G_USER_CODE', l_code);
    apex_util.set_session_state('G_USER_NAME', nvl(l_name, l_name_e));
    apex_util.set_session_state('G_USER_NAME_E', nvl(l_name_e, l_name));
    apex_util.set_session_state('G_PASSWORD_NUMBER', l_grp);
    apex_util.set_session_state('G_COMPANY_CODE', l_comp);
    apex_util.set_session_state('G_LANG', case when upper(l_lang) = 'E' then 'en' else 'ar' end);
    apex_util.set_session_lang(case when upper(l_lang) = 'E' then 'en' else 'ar' end);
  end post_auth;

  function must_change return boolean is
    l_flag char(1);
    l_code number := user_code(v('APP_USER'));
  begin
    select must_change into l_flag from app_user_auth where users_code = l_code;
    return l_flag = 'Y';
  exception when no_data_found then return false;
  end must_change;

  procedure change_password (p_old in varchar2, p_new in varchar2) is
    l_code number := user_code(v('APP_USER'));
    l_auth app_user_auth%rowtype;
    l_salt varchar2(64) := rawtohex(sys.dbms_crypto.randombytes(16));
  begin
    select * into l_auth from app_user_auth where users_code = l_code for update;
    if hash_pwd(l_code, p_old, l_auth.salt) <> l_auth.pwd_hash then
      raise_application_error(-20010, case when lang = 'en' then 'Current password is not correct.' else 'كلمة المرور الحالية غير صحيحة' end);
    end if;
    if length(p_new) < 6 then
      raise_application_error(-20011, case when lang = 'en' then 'New password must be at least 6 characters.' else 'يجب ألا تقل كلمة المرور الجديدة عن 6 أحرف' end);
    end if;
    if p_new = p_old then
      raise_application_error(-20012, case when lang = 'en' then 'New password must differ from the current one.' else 'يجب أن تختلف كلمة المرور الجديدة عن الحالية' end);
    end if;
    update app_user_auth set pwd_hash = hash_pwd(l_code, p_new, l_salt), salt = l_salt, must_change = 'N', changed_on = sysdate
     where users_code = l_code;
  end change_password;

  function is_admin return boolean is
  begin
    return nvl(v('G_USER_CODE'), -1) = 0;
  end is_admin;

  function lang return varchar2 is
  begin
    return nvl(v('G_LANG'), 'ar');
  end lang;

  function can_page (p_page_id in number, p_op in varchar2 default 'Q') return boolean is
    l_map  app_page_map%rowtype;
    l_user number := v('G_USER_CODE');
    l_n    number;
  begin
    if is_admin then return true; end if;
    begin
      select * into l_map from app_page_map where page_id = p_page_id;
    exception when no_data_found then
      return true;                         -- pages outside the registry (home, profile) are open to every signed-in user
    end;
    if l_map.kind = 'FORMPAGE' and l_map.parent_page_id is not null then
      select * into l_map from app_page_map where page_id = l_map.parent_page_id;
    end if;
    if l_map.system_number is null then return true; end if;
    if l_map.kind = 'REPORT' then
      select count(*) into l_n from report_password
       where users_code = l_user and system_number = l_map.system_number and report_serial = l_map.file_serial
         and nvl(report_flag, 1) = 1;
      return l_n > 0;
    end if;
    select count(*) into l_n
      from file_password f
      join app_page_serials s on s.system_number = f.system_number and s.file_serial = f.file_serial
     where s.page_id = l_map.page_id and f.users_code = l_user
       and 1 = case upper(p_op) when 'I' then f.insert_flag when 'U' then f.update_flag when 'D' then f.delete_flag else f.query_flag end;
    return l_n > 0;
  end can_page;

  function can_page_yn (p_page_id in number, p_op in varchar2 default 'Q') return varchar2 is
  begin
    return case when can_page(p_page_id, p_op) then 'Y' else 'N' end;
  end can_page_yn;

end app_sec;
/
show errors package body app_sec

-- navigation tree for the APEX dynamic list, filtered by the signed-in user's rights
create or replace view app_menu_v as
with leaf as (
  select m.id
    from app_menu m
   where m.kind in ('FORM', 'REPORT')
     and m.page_id is not null
     and (   nvl(v('G_USER_CODE'), -1) = 0
          or (m.kind = 'FORM'   and exists (select 1 from file_password f
                                             where f.users_code = v('G_USER_CODE') and f.system_number = m.system_number
                                               and f.file_serial = m.file_serial and f.query_flag = 1))
          or (m.kind = 'REPORT' and exists (select 1 from report_password r
                                             where r.users_code = v('G_USER_CODE') and r.system_number = m.system_number
                                               and r.report_serial = m.file_serial and nvl(r.report_flag, 1) = 1)))
), vis as (
  select distinct id from app_menu start with id in (select id from leaf) connect by id = prior parent_id
)
select m.* from app_menu m where m.id in (select id from vis);
