-- ASCON ERP on APEX: UI helpers (run as the client's schema)
set define off
-- every error the application shows is also recorded with its technical cause (the browser only says "contact the
-- administrator" for rendering errors); the verify stage and the review read it
declare
  n pls_integer;
begin
  select count(*) into n from user_tables where table_name = 'APP_ERROR_LOG';
  if n = 0 then
    execute immediate q'[create table app_error_log (
      id             number generated always as identity primary key,
      logged_on      date default sysdate not null,
      app_user       varchar2(255),
      page_id        number,
      request        varchar2(255),
      component_type varchar2(255),
      component_name varchar2(255),
      is_internal    varchar2(1),
      message        varchar2(4000),
      ora_sqlcode    number,
      ora_sqlerrm    varchar2(4000),
      backtrace      varchar2(4000))]';
    execute immediate 'create index app_error_log_i1 on app_error_log (logged_on, page_id)';
  end if;
end;
/
create or replace package app_ui authid definer as
  procedure home_cards;      -- system cards on the home page (PL/SQL dynamic content region)
  -- application error handling function: business errors (ORA-20000..20999) without the ORA prefix,
  -- constraint violations translated into readable Arabic / English messages
  function handle_error (p_error in apex_error.t_error) return apex_error.t_error_result;
  -- expiry date of a lot, for display columns.  A function on purpose: the same scalar subquery inside the query APEX builds
  -- around a grid (ST_ADJUST_IN lines) hits an optimizer bug in 19c (ORA-00600 [qcsvsci1] then ORA-07445 in pfrdis)
  function lot_expiry (p_confg_id in number) return date;
  -- legacy display rights (GET_USER_SEC) for columns shown only to some users (generator "show_if": "right:<NAME>"):
  --   VIEW_COST     admin group (password number 0), or ST_BASIC.SHOW_COST = 1 and USERS.ALLOW_VIEW_COST = 1
  --   VIEW_BALANCE  user 0, or USERS.ALLOW_VIEW_BALANCE = 1
  -- 1 = may see.  An installation without the right's columns sees the value (1).
  function has_right (p_right in varchar2) return number;
end app_ui;
/
create or replace package body app_ui as

  function esc(p in varchar2) return varchar2 is begin return apex_escape.html(p); end;

  procedure home_cards is
    l_en   boolean := app_sec.lang = 'en';
    l_url  varchar2(4000);
  begin
    htp.p('<ul class="t-Cards t-Cards--featured t-Cards--block force-fa-lg t-Cards--displayIcons t-Cards--3cols t-Cards--animColorFill">');
    for s in (
      with vis as (select * from app_menu_v)
      select m.id, m.label_a, m.label_e, m.icon,
             (select count(*) from vis x where x.kind = 'FORM'   start with x.id = m.id connect by prior x.id = x.parent_id) forms,
             (select count(*) from vis x where x.kind = 'REPORT' start with x.id = m.id connect by prior x.id = x.parent_id) reports,
             (select min(x.page_id) keep (dense_rank first order by x.seq) from vis x
               where x.page_id is not null start with x.id = m.id connect by prior x.id = x.parent_id) first_page
        from vis m
       where m.parent_id is null
       order by m.seq)
    loop
      l_url := case when s.first_page is not null then apex_page.get_url(p_page => s.first_page) else '#' end;
      htp.p('<li class="t-Cards-item"><div class="t-Card"><a href="' || l_url || '" class="t-Card-wrap">'
         || '<div class="t-Card-icon u-color"><span class="t-Icon fa ' || nvl(s.icon, 'fa-folder-o') || '"></span></div>'
         || '<div class="t-Card-titleWrap"><h3 class="t-Card-title">' || esc(case when l_en then nvl(s.label_e, s.label_a) else nvl(s.label_a, s.label_e) end) || '</h3></div>'
         || '<div class="t-Card-body"><div class="t-Card-desc">'
         || case when l_en then s.forms || ' screens, ' || s.reports || ' reports' else s.forms || ' شاشة، ' || s.reports || ' تقرير' end
         || '</div></div><span class="t-Card-colorFill u-color"></span></a></div></li>');
    end loop;
    htp.p('</ul>');
  end home_cards;

  procedure log_error (p_error in apex_error.t_error) is
    pragma autonomous_transaction;
    l_internal varchar2(1) := case when p_error.is_internal_error then 'Y' else 'N' end;   -- booleans cannot go into SQL
  begin
    insert into app_error_log (app_user, page_id, request, component_type, component_name, is_internal, message, ora_sqlcode, ora_sqlerrm, backtrace)
    values (v('APP_USER'), v('APP_PAGE_ID'), substr(v('REQUEST'), 1, 255), substr(p_error.component.type, 1, 255), substr(p_error.component.name, 1, 255),
            l_internal, substr(p_error.message, 1, 4000), p_error.ora_sqlcode,
            substr(p_error.ora_sqlerrm, 1, 4000), substr(p_error.error_backtrace, 1, 4000));
    commit;
  exception when others then
    rollback;
  end log_error;

  function handle_error (p_error in apex_error.t_error) return apex_error.t_error_result is
    r     apex_error.t_error_result;
    l_en  boolean := app_sec.lang = 'en';
    l_con varchar2(255);
  begin
    log_error(p_error);
    r := apex_error.init_error_result(p_error => p_error);
    if p_error.is_internal_error then
      -- rendering errors: the technical cause is shown to the administrators (everyone else sees APEX's generic text)
      if app_sec.is_admin and p_error.ora_sqlerrm is not null then
        r.additional_info := substr(p_error.component.type || ' ' || p_error.component.name || ': ' || p_error.ora_sqlerrm, 1, 4000);
      end if;
      return r;
    end if;
    if p_error.ora_sqlcode between -20999 and -20000 then
      r.message := apex_error.get_first_ora_error_text(p_error => p_error);
      r.additional_info := null;
    elsif p_error.ora_sqlcode in (-1, -2091, -2290, -2291, -2292, -1400, -1407) then
      l_con := apex_error.extract_constraint_name(p_error => p_error);
      r.message := case p_error.ora_sqlcode
        when -1    then case when l_en then 'This record already exists (duplicate key).' else 'هذا السجل موجود من قبل (قيمة مكررة).' end
        when -2291 then case when l_en then 'A referenced code does not exist.' else 'أحد الأكواد المدخلة غير موجود في الجدول المرتبط.' end
        when -2292 then case when l_en then 'This record is used by other records and cannot be deleted.' else 'لا يمكن الحذف لوجود حركات مرتبطة بهذا السجل.' end
        when -1400 then case when l_en then 'A required value is missing.' else 'يوجد حقل إلزامي لم يتم إدخاله.' end
        when -1407 then case when l_en then 'A required value is missing.' else 'يوجد حقل إلزامي لم يتم إدخاله.' end
        else case when l_en then 'The data does not satisfy a validation rule.' else 'البيانات لا تحقق أحد شروط التحقق.' end
      end || case when l_con is not null then ' (' || l_con || ')' end;
      r.additional_info := null;
    end if;
    if r.page_item_name is null and r.column_alias is null then
      apex_error.auto_set_associated_item(p_error => p_error, p_error_result => r);
    end if;
    return r;
  end handle_error;

  function lot_expiry (p_confg_id in number) return date is
    l_d date;
  begin
    if p_confg_id is null then return null; end if;
    select max(expire_date) into l_d from st_item_confg where item_confg_id = p_confg_id;
    return l_d;
  end lot_expiry;

  function has_right (p_right in varchar2) return number is
    l_user number := to_number(v('G_USER_CODE'));
    l_grp  number := to_number(v('G_PASSWORD_NUMBER'));
    l_n    number;
  begin
    case upper(p_right)
      when 'VIEW_COST' then
        if nvl(l_grp, 0) = 0 then return 1; end if;
        execute immediate 'select nvl(max(show_cost), 0) from st_basic' into l_n;
        if l_n <> 1 then return 0; end if;
        execute immediate 'select nvl(max(allow_view_cost), 0) from users where users_code = :u' into l_n using l_user;
      when 'VIEW_BALANCE' then
        if nvl(l_user, 0) = 0 then return 1; end if;
        execute immediate 'select nvl(max(allow_view_balance), 0) from users where users_code = :u' into l_n using l_user;
      else
        return 0;
    end case;
    return case when l_n = 1 then 1 else 0 end;
  exception
    when others then
      if sqlcode in (-904, -942) then return 1; end if;         -- this installation has no such right
      raise;
  end has_right;

end app_ui;
/
show errors package body app_ui
