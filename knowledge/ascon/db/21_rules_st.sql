-- =====================================================================================================
-- APP_RULES_ST : business rules of the inventory movement data-entry screens (Stage C wave 2).
--   ST_TRANSFER_FROM    issue transfer               ST_TRNS_MAST / ST_TRNS_DET, types EFFECT 5 / TRNS_TYPE 9
--   ST_TRANSFER_TO      receive transfer             ST_TRNS_MAST / ST_TRNS_DET, types EFFECT 6 / TRNS_TYPE 9
--   ST_TRANSFER_REQUEST transfer request             ST_TRNS_MAST_REQUEST / ST_TRNS_DET_REQUEST (EFFECT 7 / TYPE 9)
--   ST_OPEN_BALANCE     opening balance entry        ST_TRNS_MAST / ST_TRNS_DET, types EFFECT 1 / TRNS_TYPE 8
--   ST_ADJUST_IN        stocktaking adjustment in    ST_TRNS_MAST / ST_TRNS_DET, types EFFECT 1 / TRNS_TYPE 7
--   ST_ADJUST_OUT       stocktaking adjustment out   ST_TRNS_MAST / ST_TRNS_DET, types EFFECT 2,7 / TRNS_TYPE 7,40
--   ST_RESERVATION      quantity reservation         ST_TRNS_MAST / ST_TRNS_DET (+services), EFFECT 2 / TRNS_TYPE 17
--   ST_TAKING           stocktaking count entry      ST_STOCK_TAKING / ST_STOCK_TAKING_DET
--   ST_TAKING2          revaluation count entry      ST_STOCK_TAKING_TEMP / ST_STOCK_TAKING_TEMP_DET
-- Evidence and decisions: app\legacy\processes\<FORM>.md.  Overrides: app\legacy\overrides\<FORM>.json.
--
-- How the rules are wired (see STAGE_C_RULES_ADDENDUM.md):
--   * row_rules of the overrides call mast_row / det_row / req_mast_row / req_det_row / taking_det_row[2]
--     from the generated APPX_<TABLE> triggers (APEX sessions only);
--   * page validations call val_trns / val_req / val_taking, after-save processes call after_trns /
--     after_req / after_taking;
--   * delete triggers at the end of this file (the rules mechanism has no delete hook):
--     APP_RULES_ST_MAST_BD (ST_TRNS_MAST), APP_RULES_ST_DET_BD (ST_TRNS_DET), APP_RULES_ST_REQ_BD / _REQDET_BD
--     (ST_TRNS_MAST_REQUEST / ST_TRNS_DET_REQUEST, wave 3).  The documents of ST_TRANSFER_FROM / _TO, ST_OPEN_BALANCE,
--     ST_ADJUST_IN / _OUT are soft-deleted by the page since wave 3 (rules.soft_delete, APP_ACT_ST), as the legacy did.
--   * wave 3: the hooks only judge rows whose transaction type belongs to the screen (screen_type), so documents of other
--     types written by a button of the page (automatic transfer receipt, APP_ACT_ST) are left to that code.
-- Every hook first checks the legacy form of the current APEX page (APP_PAGE_MAP.FORM_NAME of APP_PAGE_ID):
-- rows written by other screens (sales, purchasing, posting, ST_AUTO_ADJ ...) are left untouched.
-- The existing legacy triggers (ST_TRNS_MAST_IN date serial, ST_TRNS_DET_C_IN/_C_UP/_C_DL cost & balance,
-- CLOSE_ST_TRNS_MAST closed period, *_ALTKEY, *_TAX) are not duplicated.
-- Stock balances are read from ST_TRNS_DET_COST (the table GET_BALANCE_COST_CONFG reads), never from
-- ST_TRNS_DET itself, so the row triggers do not hit ORA-04091 (mutating table).
-- No COMMIT: APEX commits the page.  Errors: raise_application_error(-20100..-20199), Arabic (English when G_LANG=en).
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_rules_st authid definer as

  -- ------------------------------------------------------------------ context / reference data
  function cur_form return varchar2;                                   -- legacy form of the current APEX page
  function type_allowed (p_type in number, p_flag in number default 0) return number;   -- ST_TRNSTYPE_PASSWORD
  function type_in_screen (p_form in varchar2, p_type in number, p_new in number default 0) return number;
  function default_type (p_form in varchar2) return number;            -- first transaction type of the screen
  function type_store (p_type in number) return number;                -- ST_TRNS_TYPE.STORE_CODE when active
  function type_desc (p_type in number) return varchar2;
  function unit_factor (p_group in number, p_item in varchar2, p_unit in number) return number;

  -- ------------------------------------------------------------------ numbering
  function next_doc_no (p_form in varchar2, p_type in number, p_store in number, p_serial in number default null) return number;
  function next_req_date_serial (p_date in date) return number;        -- ST_TRNS_MAST_REQUEST.DATE_SERIAL (key_expr)
  function next_temp_taking_no (p_date in date, p_store in number, p_serial in number) return number;   -- key_expr

  -- ------------------------------------------------------------------ stock
  -- lowest running balance of a lot from a position onwards (ST_TRNS_DET_COST), the given line replaced by p_contrib
  procedure run_balance (p_store in number, p_confg in number, p_date in date, p_dser in number, p_iser in number,
                         p_x_type in number, p_x_serial in number, p_x_item in number, p_contrib in number,
                         p_first out number, p_min out number);
  function fefo_lot (p_store in number, p_group in number, p_item in varchar2, p_date in date, p_dser in number,
                     p_iser in number, p_qty in number) return number;

  -- ------------------------------------------------------------------ page validations (return error text or null)
  function val_trns (p_form in varchar2, p_rowid in varchar2, p_request in varchar2, p_type in varchar2, p_date in varchar2,
                     p_store in varchar2, p_doc_no in varchar2, p_account in varchar2 default null,
                     p_to_store in varchar2 default null, p_from_store in varchar2 default null,
                     p_trnsfer_serial in varchar2 default null, p_currency in varchar2 default null,
                     p_rate in varchar2 default null) return varchar2;
  function val_req (p_rowid in varchar2, p_request in varchar2, p_type in varchar2, p_date in varchar2, p_store in varchar2,
                    p_to_store in varchar2, p_doc_no in varchar2) return varchar2;
  function val_taking (p_form in varchar2, p_rowid in varchar2, p_request in varchar2, p_store in varchar2,
                       p_date in varchar2) return varchar2;

  -- ------------------------------------------------------------------ after save (same transaction as the page DML)
  procedure after_trns (p_form in varchar2, p_request in varchar2, p_rowid in varchar2);
  procedure after_req (p_request in varchar2, p_rowid in varchar2);
  procedure after_taking (p_form in varchar2, p_request in varchar2, p_rowid in varchar2, p_store in varchar2 default null,
                          p_date in varchar2 default null, p_serial in varchar2 default null);

  -- ------------------------------------------------------------------ trigger hooks
  procedure mast_row (p_inserting in boolean, p_updating in boolean,
                      p_type in number, p_serial in number, p_date in date, p_store in number,
                      p_doc_no in out number, p_desc_a in out varchar2, p_desc_e in varchar2,
                      p_delete_flag in out number, p_post_flag in out number, p_account1 in out number,
                      p_trnsfer_type in out number, p_trnsfer_serial in out number,
                      p_from_store in out number, p_to_store in out number,
                      p_old_date in date, p_old_trnsfer_serial in number, p_old_from_store in number, p_old_store in number);
  procedure mast_delete (p_type in number, p_serial in number, p_store in number, p_post_flag in number,
                         p_trnsfer_serial in number, p_from_store in number,
                         p_req_type in number default null, p_req_serial in number default null);
  procedure det_row (p_inserting in boolean, p_updating in boolean,
                     p_type in number, p_serial in number, p_item_serial in number,
                     p_group in out number, p_item in varchar2, p_unit in out number, p_confg in out number,
                     p_qty in number, p_bonus in number, p_basic_qty in out number,
                     p_unit_price in out number, p_unit_cost in out number, p_cost_flag in out number,
                     p_lot_number in number, p_expiry in date, p_disc1_ratio in number,
                     p_old_group in number, p_old_item in varchar2, p_old_unit in number, p_old_confg in number,
                     p_old_qty in number, p_old_basic_qty in number, p_old_unit_price in number, p_old_unit_cost in number,
                     p_trnsfer_serial in out number, p_trnsfer_from in out number, p_trnsfer_to in out number);
  procedure det_delete (p_type in number, p_serial in number, p_item_serial in number, p_store in number,
                        p_date in date, p_dser in number, p_confg in number, p_basic_qty in number);
  procedure req_mast_row (p_inserting in boolean, p_type in number, p_desc_a in out varchar2, p_delete_flag in out number,
                          p_post_flag in out number, p_to_transfer_flag in out number);
  procedure req_det_row (p_type in number, p_serial in number, p_group in out number, p_item in varchar2,
                         p_unit in out number, p_qty in number, p_basic_qty in out number, p_cost_flag in out number);
  procedure taking_det_row (p_store in number, p_date in date, p_group in out number, p_item in varchar2,
                            p_unit in out number, p_confg in number, p_qty in number, p_basic_qty in out number,
                            p_unit_price in out number, p_unit_cost in out number, p_sales_price in out number);
  -- wave 3 (ST_TAKING source ST\FMB\ST_TAKING_fmb.xml): the same with the line PRE-INSERT rules (row rule passes inserting)
  procedure taking_det_row (p_inserting in boolean, p_store in number, p_date in date, p_group in out number, p_item in varchar2,
                            p_unit in out number, p_confg in number, p_qty in number, p_basic_qty in out number,
                            p_unit_price in out number, p_unit_cost in out number, p_sales_price in out number);
  procedure taking_det_row2 (p_store in number, p_date in date, p_group in out number, p_item in varchar2,
                             p_unit in out number, p_confg in number, p_qty in number, p_basic_qty in out number,
                             p_unit_price in out number, p_unit_cost in out number);
end app_rules_st;
/
show errors package app_rules_st

create or replace package body app_rules_st as

  g_page      number := -1;
  g_form      varchar2(128);
  g_mast_del  boolean := false;        -- APP_RULES_ST_MAST_BD is deleting the lines of a deleted document

  c_trns_forms constant varchar2(200) := ',ST_TRANSFER_FROM,ST_TRANSFER_TO,ST_OPEN_BALANCE,ST_ADJUST_IN,ST_ADJUST_OUT,ST_RESERVATION,';

  -- =================================================================================== small helpers
  function lang return varchar2 is
  begin
    return case when lower(nvl(v('G_LANG'), 'ar')) like 'en%' then 'E' else 'A' end;
  end lang;

  function msg (p_a in varchar2, p_e in varchar2) return varchar2 is
  begin
    return case when lang = 'E' then p_e else p_a end;
  end msg;

  procedure err (p_code in pls_integer, p_a in varchar2, p_e in varchar2) is
  begin
    raise_application_error(p_code, msg(p_a, p_e));
  end err;

  function to_num (p in varchar2) return number is
  begin
    return to_number(trim(replace(p, ',', '')));
  exception when others then return null;
  end to_num;

  function to_dt (p in varchar2) return date is
  begin
    if p is null then return null; end if;
    begin return to_date(p, 'DD/MM/YYYY'); exception when others then null; end;
    begin return to_date(p, 'YYYY-MM-DD'); exception when others then null; end;
    begin return to_date(substr(p, 1, 10), 'DD/MM/YYYY'); exception when others then null; end;
    return to_date(p);
  exception when others then return null;
  end to_dt;

  function fmt (p in date) return varchar2 is
  begin
    return to_char(p, 'DD/MM/YYYY');
  end fmt;

  function is_trns_form (p_form in varchar2) return boolean is
  begin
    return p_form is not null and instr(c_trns_forms, ',' || p_form || ',') > 0;
  end is_trns_form;

  -- the transaction type belongs to the screen (block WHERE of the legacy form, without the group rights): the hooks of a
  -- screen only judge the documents of that screen.  Rows of other types written by a button of the page (e.g. the
  -- automatic receipt 11201 created from the issue-transfer page, APP_ACT_ST) are left to the code that writes them.
  function screen_type (p_form in varchar2, p_type in number) return boolean is
    l_n number;
  begin
    select count(*) into l_n from st_trns_type t
     where t.trns_type_code = p_type
       and (   (p_form = 'ST_TRANSFER_FROM' and t.effect = 5 and t.trns_type = 9)
            or (p_form = 'ST_TRANSFER_TO'   and t.effect = 6 and t.trns_type = 9)
            or (p_form = 'ST_OPEN_BALANCE'  and t.effect = 1 and t.trns_type = 8)
            or (p_form = 'ST_ADJUST_IN'     and t.effect = 1 and t.trns_type = 7)
            or (p_form = 'ST_ADJUST_OUT'    and t.effect in (2, 7) and t.trns_type in (7, 40))
            or (p_form = 'ST_RESERVATION'   and t.effect = 2 and t.trns_type = 17));
    return l_n > 0;
  end screen_type;

  -- user group (legacy :GLOBAL.PASSWORD_NUMBER); 0 = unrestricted.  Outside APEX (SQL tests, batch) unrestricted.
  function grp return number is
  begin
    if v('APP_ID') is null then return 0; end if;
    if nvl(to_num(v('G_USER_CODE')), -1) = 0 then return 0; end if;
    return to_num(v('G_PASSWORD_NUMBER'));
  end grp;

  function neg_allowed return boolean is
    l_n number;
  begin
    select nvl(max(neg_sale_balance), 0) into l_n from st_basic;
    return l_n = 1;
  end neg_allowed;

  function type_effect (p_type in number) return number is
    l_e number;
  begin
    select effect into l_e from st_trns_type where trns_type_code = p_type;
    return l_e;
  exception when no_data_found then return null;
  end type_effect;

  function sgn (p_effect in number) return number is
  begin
    return case when p_effect in (1, 4, 6) then 1 when p_effect in (2, 3, 5) then -1 else 0 end;
  end sgn;

  -- =================================================================================== context
  function cur_form return varchar2 is
    l_page number;
  begin
    begin l_page := to_number(v('APP_PAGE_ID')); exception when others then l_page := null; end;
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

  -- legacy LOVs / block WHERE: (:GLOBAL.PASSWORD_NUMBER = 0 OR TRNS_TYPE_CODE IN (SELECT .. FROM ST_TRNSTYPE_PASSWORD ..))
  function type_allowed (p_type in number, p_flag in number default 0) return number is
    l_g number := grp;
    l_n number;
  begin
    if l_g = 0 then return 1; end if;
    if l_g is null then return 0; end if;
    select count(*) into l_n from st_trnstype_password tp
     where tp.password_number = l_g and tp.trns_type_code = p_type and (p_flag = 0 or tp.flag = 1);
    return case when l_n > 0 then 1 else 0 end;
  end type_allowed;

  -- transaction types of each screen (legacy block WHERE / TRNS_TYPE LOV record groups)
  function type_in_screen (p_form in varchar2, p_type in number, p_new in number default 0) return number is
    l_n number;
  begin
    select count(*) into l_n from st_trns_type t
     where t.trns_type_code = p_type
       and (   (p_form = 'ST_TRANSFER_FROM'    and t.effect = 5 and t.trns_type = 9)
            or (p_form = 'ST_TRANSFER_TO'      and t.effect = 6 and t.trns_type = 9)
            or (p_form = 'ST_TRANSFER_REQUEST' and t.effect = 7 and t.trns_type = 9)
            or (p_form = 'ST_OPEN_BALANCE'     and t.effect = 1 and t.trns_type = 8)
            or (p_form = 'ST_ADJUST_IN'        and t.effect = 1 and t.trns_type = 7 and (p_new = 0 or nvl(t.auto_trns, 0) = 0))
            or (p_form = 'ST_ADJUST_OUT'       and t.effect in (2, 7) and t.trns_type in (7, 40))
            or (p_form = 'ST_RESERVATION'      and t.effect = 2 and t.trns_type = 17));
    if l_n = 0 then return 0; end if;
    -- the TRNS_TYPE LOVs of these three forms also require ST_TRNSTYPE_PASSWORD.FLAG = 1
    return type_allowed(p_type, case when p_new = 1 and p_form in ('ST_TRANSFER_FROM', 'ST_TRANSFER_REQUEST', 'ST_RESERVATION') then 1 else 0 end);
  end type_in_screen;

  function default_type (p_form in varchar2) return number is
  begin
    -- manual types first (AUTO_TRNS = 1 types such as 901-906 are generated by other screens), then by code
    for r in (select trns_type_code from st_trns_type order by nvl(auto_trns, 0), trns_type_code) loop
      if type_in_screen(p_form, r.trns_type_code, 1) = 1 then
        return r.trns_type_code;
      end if;
    end loop;
    return null;
  end default_type;

  -- TRNS_TYPE_CODE WHEN-VALIDATE-ITEM: SELECT STORE_CODE FROM ST_TRNS_TYPE WHERE .. AND STORE_CODE IN (active stores)
  function type_store (p_type in number) return number is
    l_s number;
  begin
    select t.store_code into l_s from st_trns_type t
     where t.trns_type_code = p_type
       and t.store_code in (select s.store_code from st_store s where s.store_status = 1 and nvl(s.stop_flag, 0) = 0);
    return l_s;
  exception when no_data_found then return null;
  end type_store;

  function type_desc (p_type in number) return varchar2 is
    l_d st_trns_type.desc_a%type;
  begin
    select desc_a into l_d from st_trns_type where trns_type_code = p_type;
    return l_d;
  exception when no_data_found then return null;
  end type_desc;

  function unit_factor (p_group in number, p_item in varchar2, p_unit in number) return number is
    l_f number;
  begin
    select factor into l_f from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit;
    return l_f;
  exception when no_data_found then return null;
  end unit_factor;

  function basic_unit (p_group in number, p_item in varchar2) return number is
    l_u number;
  begin
    select min(unit_code) into l_u from st_item_unit where group_code = p_group and item_code = p_item and nvl(basic_unit, 0) = 1;
    return l_u;
  end basic_unit;

  -- ITEM_CODE WHEN-VALIDATE-ITEM: the group is taken from ST_ITEM (NVL(STOP_FLAG,0)=0), "صنف غير موجود" / "صنف مكرر"
  procedure check_item (p_group in out number, p_item in varchar2) is
    l_stop number;
    l_n    number;
  begin
    if p_item is null then
      err(-20108, 'يجب إدخال رقم الصنف', 'Enter the item code');
    end if;
    if p_group is null then
      select count(*), min(item_group_code) into l_n, p_group from st_item where item_code = p_item;
      if l_n = 0 then
        err(-20108, 'صنف غير موجود: ' || p_item, 'Item does not exist: ' || p_item);
      elsif l_n > 1 then
        err(-20108, 'صنف مكرر، يجب إدخال رقم المجموعة: ' || p_item, 'Repeated item code, enter the group: ' || p_item);
      end if;
    end if;
    begin
      select nvl(stop_flag, 0) into l_stop from st_item where item_group_code = p_group and item_code = p_item;
    exception when no_data_found then
      err(-20108, 'صنف غير موجود: ' || p_item, 'Item does not exist: ' || p_item);
    end;
    if l_stop = 1 then
      err(-20108, 'الصنف موقوف: ' || p_item, 'The item is stopped: ' || p_item);
    end if;
  end check_item;

  -- unit: default = basic unit of the item; returns the conversion factor
  function check_unit (p_group in number, p_item in varchar2, p_unit in out number) return number is
    l_f number;
  begin
    if p_unit is null then
      p_unit := basic_unit(p_group, p_item);
    end if;
    l_f := unit_factor(p_group, p_item, p_unit);
    if l_f is null then
      err(-20108, 'الوحدة غير معرفة لهذا الصنف', 'The unit is not defined for this item');
    end if;
    return l_f;
  end check_unit;

  function lot_of_item (p_confg in number, p_group in number, p_item in varchar2) return boolean is
    l_n number;
  begin
    select count(*) into l_n from st_item_confg where item_confg_id = p_confg and group_code = p_group and item_code = p_item;
    return l_n > 0;
  end lot_of_item;

  function group_expire_flag (p_group in number) return number is
    l_f number;
    l_b number;
  begin
    select nvl(max(expire_flag), 0) into l_b from st_basic;
    select nvl(expire_flag, 0) into l_f from st_item_group where item_group_code = p_group;
    return case when l_b = 1 and l_f = 1 then 1 else 0 end;
  exception when no_data_found then return 0;
  end group_expire_flag;

  -- =================================================================================== numbering
  function next_doc_no (p_form in varchar2, p_type in number, p_store in number, p_serial in number default null) return number is
    l_n   number;
    l_len pls_integer := length(to_char(p_type));
  begin
    if p_form = 'ST_TRANSFER_FROM' then
      -- .fmx: SELECT NVL(MAX(SUBSTR(DOC_NO, :len + 1, LENGTH(DOC_NO))),0)+1 FROM ST_TRNS_MAST WHERE TRNS_TYPE_CODE=:t AND STORE_CODE=:s
      -- data: 1110100001, 1110100002 ... = type code || 5-digit sequence per type and store
      select nvl(max(to_number(substr(to_char(doc_no), l_len + 1))), 0) + 1 into l_n
        from st_trns_mast
       where trns_type_code = p_type and store_code = p_store and nvl(delete_flag, 0) = 0
         and to_char(doc_no) like to_char(p_type) || '_%';
      return to_number(to_char(p_type) || lpad(to_char(l_n), 5, '0'));
    elsif p_form in ('ST_ADJUST_IN', 'ST_ADJUST_OUT') then
      -- program unit GET_NEXT_DOC_NO (ST_adjust_IN.fmb, same SQL in ST_adjust_out.fmx)
      select nvl(max(doc_no), 0) + 1 into l_n
        from st_trns_mast
       where trns_type_code = p_type and store_code = p_store and nvl(delete_flag, 0) = 0;
      if l_n = 1 and p_store is not null then
        return to_number(substr(to_char(p_store), 1, 2) || substr(to_char(p_store), 4, 2) || lpad('1', 6, '0'));
      end if;
      return l_n;
    elsif p_form = 'ST_OPEN_BALANCE' then
      return p_serial;                                    -- PRE-INSERT: IF :DOC_NO IS NULL THEN :DOC_NO := :TRNS_SERIAL
    elsif p_form = 'ST_RESERVATION' then
      select nvl(max(doc_no), 0) + 1 into l_n from st_trns_mast where trns_type_code = p_type;
      return l_n;
    end if;
    return null;
  end next_doc_no;

  function next_req_date_serial (p_date in date) return number is
    l_n number;
  begin
    select nvl(max(date_serial), 0) + 1 into l_n from st_trns_mast_request where trns_date = p_date;
    return l_n;
  end next_req_date_serial;

  function next_temp_taking_no (p_date in date, p_store in number, p_serial in number) return number is
    l_n number;
  begin
    select nvl(max(nvl(taking_number, 0)), 0) + 1 into l_n
      from st_stock_taking_temp_det
     where st_taking_date = p_date and store_code = p_store and serial = p_serial;
    return l_n;
  end next_temp_taking_no;

  -- =================================================================================== stock balance
  procedure run_balance (p_store in number, p_confg in number, p_date in date, p_dser in number, p_iser in number,
                         p_x_type in number, p_x_serial in number, p_x_item in number, p_contrib in number,
                         p_first out number, p_min out number) is
    l_run number;
  begin
    select nvl(sum(case when t.effect in (1, 4, 6) then 1 when t.effect in (2, 3, 5) then -1 else 0 end * nvl(c.basic_qty, 0)), 0)
      into l_run
      from st_trns_det_cost c, st_trns_type t
     where t.trns_type_code = c.trns_type_code
       and c.store_code = p_store and c.item_confg_id = p_confg and nvl(c.delete_flag, 0) = 0
       and not (c.trns_type_code = p_x_type and c.trns_serial = p_x_serial and c.item_serial = p_x_item)
       and (   c.trns_date < p_date
            or (c.trns_date = p_date and c.date_serial < p_dser)
            or (c.trns_date = p_date and c.date_serial = p_dser and c.item_serial < p_iser));
    l_run := l_run + nvl(p_contrib, 0);
    p_first := l_run;
    p_min := l_run;
    for r in (select case when t.effect in (1, 4, 6) then 1 when t.effect in (2, 3, 5) then -1 else 0 end * nvl(c.basic_qty, 0) q
                from st_trns_det_cost c, st_trns_type t
               where t.trns_type_code = c.trns_type_code
                 and c.store_code = p_store and c.item_confg_id = p_confg and nvl(c.delete_flag, 0) = 0
                 and not (c.trns_type_code = p_x_type and c.trns_serial = p_x_serial and c.item_serial = p_x_item)
                 and (   c.trns_date > p_date
                      or (c.trns_date = p_date and c.date_serial > p_dser)
                      or (c.trns_date = p_date and c.date_serial = p_dser and c.item_serial > p_iser))
               order by c.trns_date, c.date_serial, c.item_serial)
    loop
      l_run := l_run + r.q;
      if l_run < p_min then p_min := l_run; end if;
    end loop;
  end run_balance;

  -- legacy: GET_BALANCE_CONFG(..) < qty -> "رصيد الصنف فى هذا التاريخ لا يسمح";
  --         UPDATE_NEXT_TRNS_CONFG(..) != 0 -> "الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها"
  procedure check_balance (p_store in number, p_confg in number, p_date in date, p_dser in number, p_iser in number,
                           p_x_type in number, p_x_serial in number, p_x_item in number, p_contrib in number) is
    l_first number;
    l_min   number;
  begin
    if neg_allowed then return; end if;             -- ST_BASIC.NEG_SALE_BALANCE = 1 allows negative balances
    run_balance(p_store, p_confg, p_date, p_dser, p_iser, p_x_type, p_x_serial, p_x_item, p_contrib, l_first, l_min);
    if nvl(p_contrib, 0) < 0 and l_first < 0 then
      err(-20106, 'رصيد الشحنة فى هذا التاريخ لا يسمح، الرصيد المتاح = ' || to_char(l_first - p_contrib),
                  'The lot balance at this date does not allow this quantity, available = ' || to_char(l_first - p_contrib));
    elsif l_min < 0 then
      err(-20106, 'الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها',
                  'Balance not enough: a later transaction conflicts with this one');
    end if;
  end check_balance;

  -- default lot for an issue line (legacy: first lot with balance, earliest expiry / lowest id)
  function fefo_lot (p_store in number, p_group in number, p_item in varchar2, p_date in date, p_dser in number,
                     p_iser in number, p_qty in number) return number is
    l_any number;
  begin
    for r in (select item_confg_id,
                     get_balance_confg(p_store, p_group, p_item, item_confg_id, p_date, p_dser, p_iser) bal
                from st_item_confg
               where group_code = p_group and item_code = p_item
               order by expire_date nulls last, item_confg_id)
    loop
      if r.bal >= nvl(p_qty, 0) and r.bal > 0 then
        return r.item_confg_id;
      end if;
      if r.bal > 0 and l_any is null then
        l_any := r.item_confg_id;
      end if;
    end loop;
    return l_any;
  end fefo_lot;

  -- =================================================================================== transfers
  function trnsfer_receipts (p_trnsfer_serial in number, p_from_store in number,
                             p_x_type in number default null, p_x_serial in number default null) return number is
    l_n number;
  begin
    select count(*) into l_n
      from st_trns_mast m, st_trns_type t
     where t.trns_type_code = m.trns_type_code and t.effect = 6 and t.trns_type = 9
       and m.trnsfer_serial = p_trnsfer_serial and m.trnsfer_from_store = p_from_store and nvl(m.delete_flag, 0) = 0
       and not (m.trns_type_code = nvl(p_x_type, -1) and m.trns_serial = nvl(p_x_serial, -1));
    return l_n;
  end trnsfer_receipts;

  function trnsfer_received (p_trnsfer_serial in number, p_from_store in number) return boolean is
    l_d date;
  begin
    if p_trnsfer_serial is null then return false; end if;
    select max(trnsfer_receiving_date) into l_d
      from st_trnsfer where trnsfer_serial = p_trnsfer_serial and trnsfer_from_store = p_from_store and nvl(delete_flag, 0) = 0;
    return l_d is not null or trnsfer_receipts(p_trnsfer_serial, p_from_store) > 0;
  end trnsfer_received;

  -- quantities (basic units) of a lot moved by the issue (effect 5) or the receipts (effect 6) of one transfer
  function trnsfer_qty (p_effect in number, p_trnsfer_serial in number, p_from_store in number, p_group in number,
                        p_item in varchar2, p_confg in number, p_x_type in number default null,
                        p_x_serial in number default null, p_x_item in number default null) return number is
    l_q number;
  begin
    select nvl(sum(c.basic_qty), 0) into l_q
      from st_trns_det_cost c, st_trns_mast m, st_trns_type t
     where m.trns_type_code = c.trns_type_code and m.trns_serial = c.trns_serial
       and t.trns_type_code = m.trns_type_code and t.effect = p_effect and t.trns_type = 9
       and m.trnsfer_serial = p_trnsfer_serial and m.trnsfer_from_store = p_from_store and nvl(m.delete_flag, 0) = 0
       and c.group_code = p_group and c.item_code = p_item and c.item_confg_id = p_confg
       and not (c.trns_type_code = nvl(p_x_type, -1) and c.trns_serial = nvl(p_x_serial, -1) and c.item_serial = nvl(p_x_item, -1));
    return l_q;
  end trnsfer_qty;

  function trnsfer_cost (p_trnsfer_serial in number, p_from_store in number, p_group in number, p_item in varchar2,
                         p_confg in number) return number is
    l_c number;
  begin
    select max(c.unit_cost) into l_c
      from st_trns_det_cost c, st_trns_mast m, st_trns_type t
     where m.trns_type_code = c.trns_type_code and m.trns_serial = c.trns_serial
       and t.trns_type_code = m.trns_type_code and t.effect = 5 and t.trns_type = 9
       and m.trnsfer_serial = p_trnsfer_serial and m.trnsfer_from_store = p_from_store and nvl(m.delete_flag, 0) = 0
       and c.group_code = p_group and c.item_code = p_item and c.item_confg_id = p_confg;
    return l_c;
  end trnsfer_cost;

  -- receive screen: copy the lines of the issue transfer (legacy loads them into the detail block; the auto-receive
  -- INSERT of ST_TRANSFER_FROM.fmx copies QUANTITY, UNIT_COST, BASIC_QTY, UNIT_CODE, GROUP_CODE, ITEM_CODE, ITEM_CONFG_ID)
  procedure copy_transfer_lines (r in st_trns_mast%rowtype) is
    l_n    number;
    l_item number := 0;
  begin
    select count(*) into l_n from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    if l_n > 0 or r.trnsfer_serial is null then return; end if;
    for d in (select d.group_code, d.item_code, d.unit_code, d.item_confg_id, d.quantity, d.basic_qty, d.unit_cost,
                     nvl(iu.factor, 1) factor
                from st_trns_det d, st_trns_mast m, st_trns_type t, st_item_unit iu
               where m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial
                 and t.trns_type_code = m.trns_type_code and t.effect = 5 and t.trns_type = 9
                 and m.trnsfer_serial = r.trnsfer_serial and m.trnsfer_from_store = r.trnsfer_from_store
                 and nvl(m.delete_flag, 0) = 0
                 and iu.group_code (+) = d.group_code and iu.item_code (+) = d.item_code and iu.unit_code (+) = d.unit_code
               order by m.trns_serial, d.item_serial)
    loop
      l_item := l_item + 1;
      insert into st_trns_det (trns_type_code, trns_serial, item_serial, group_code, item_code, unit_code, item_confg_id,
                               quantity, basic_qty, unit_cost, unit_price, cost_flag,
                               trnsfer_serial, trnsfer_from_store, trnsfer_to_store)
      values (r.trns_type_code, r.trns_serial, l_item, d.group_code, d.item_code, d.unit_code, d.item_confg_id,
              d.quantity, d.basic_qty, d.unit_cost, d.unit_cost * d.factor, 1,
              r.trnsfer_serial, r.trnsfer_from_store, r.store_code);
    end loop;
  end copy_transfer_lines;

  -- =================================================================================== page validations
  function val_date (p_form in varchar2, p_date in date) return varchar2 is
    l_min  date;
    l_amin date;
    l_amax date;
    l_close date;
  begin
    if p_date is null then
      return msg('يجب إدخال تاريخ الحركة', 'Enter the transaction date');
    end if;
    -- library CHECK_DATE (TRANSLATE.pll): no future date, not before ST_BASIC.MIN_DATE (systems 3/30/31)
    if trunc(p_date) > trunc(sysdate) then
      return msg('تاريخ الحركة أكبر من تاريخ اليوم', 'Transaction date is greater than today''s date');
    end if;
    select min(min_date) into l_min from st_basic;
    l_min := nvl(l_min, to_date('01-01-' || to_char(to_number(to_char(sysdate, 'YYYY')) - 1), 'DD-MM-YYYY'));
    if trunc(p_date) < trunc(l_min) then
      return msg('الحد الأدنى لتاريخ الحركة هو ' || fmt(l_min), 'The least value accepted for Transaction Date is ' || fmt(l_min));
    end if;
    -- DB trigger CLOSE_ST_TRNS_MAST (AC_BASIC MIN_DATE / MAX_DATE) - checked here to give an Arabic message first
    if p_form != 'ST_TRANSFER_REQUEST' then
      select min(min_date), min(max_date), max(close_date) into l_amin, l_amax, l_close from ac_basic;
      if l_amin is not null and l_amax is not null and p_date not between l_amin and l_amax then
        return msg('تاريخ الحركة خارج الفترة المفتوحة (' || fmt(l_amin) || ' - ' || fmt(l_amax) || ')',
                   'The transaction date is outside the open period (' || fmt(l_amin) || ' - ' || fmt(l_amax) || ')');
      end if;
      -- ST_RESERVATION.fmx: SELECT CLOSE_DATE FROM AC_BASIC -> "يجب ان يكون تاريخ القيد بعد تاريخ اخر اقفال"
      if p_form = 'ST_RESERVATION' and l_close is not null and trunc(p_date) <= trunc(l_close) then
        return msg('يجب ان يكون تاريخ القيد بعد تاريخ اخر اقفال (' || fmt(l_close) || ')',
                   'The date must be after the last closing date (' || fmt(l_close) || ')');
      end if;
    end if;
    return null;
  end val_date;

  -- store LOVs: STORE_STATUS = 1, STOP_FLAG = 0, (:GLOBAL.PASSWORD_NUMBER = 0 OR STORE_CODE IN ST_STORE_PASSWORD)
  function val_store (p_store in number, p_what in varchar2 default null) return varchar2 is
    l_n number;
    l_g number := grp;
  begin
    if p_store is null then
      return case when p_what = 'TO' then msg('يجب إدخال المخزن المحول إليه', 'Enter the destination store')
                  else msg('يجب إدخال رقم المخزن', 'Enter the store') end;
    end if;
    select count(*) into l_n from st_store where store_code = p_store and store_status = 1 and nvl(stop_flag, 0) = 0;
    if l_n = 0 then
      return msg('رقم المخزن غير صحيح أو موقوف: ', 'Invalid or stopped store: ') || p_store;
    end if;
    -- wave 3: also the destination store (TO_STORE_LOV of ST_TRANSFER_FROM / ST_TRANSFER_REQUEST: (:GLOBAL.PASSWORD_NUMBER = 0
    -- [OR :GLOBAL.CUSTOMER_CODE = 'SDI'] OR STORE_CODE IN ST_STORE_PASSWORD); the installation code is not SDI here)
    if nvl(l_g, -1) != 0 then
      select count(*) into l_n from st_store_password where store_code = p_store and password_number = l_g;
      if l_n = 0 then
        return msg('ليس لديك صلاحية على هذا المخزن', 'You have no permission on this store');
      end if;
    end if;
    return null;
  end val_store;

  function val_doc_no (p_table in varchar2, p_type in number, p_doc_no in number, p_rowid in varchar2) return varchar2 is
    l_rep number;
    l_n   number;
  begin
    if p_doc_no is null then return null; end if;
    select nvl(max(doc_repeat), 0) into l_rep from st_basic;
    if l_rep != 0 then return null; end if;       -- DOC_REPEAT = 1: the legacy only asked "رقم المستند مكرر هل تريد الإستمرار"
    if p_table = 'REQ' then
      select count(*) into l_n from st_trns_mast_request
       where trns_type_code = p_type and doc_no = p_doc_no and nvl(delete_flag, 0) = 0
         and (p_rowid is null or rowid != chartorowid(p_rowid));
    else
      select count(*) into l_n from st_trns_mast
       where trns_type_code = p_type and doc_no = p_doc_no and nvl(delete_flag, 0) = 0
         and (p_rowid is null or rowid != chartorowid(p_rowid));
    end if;
    if l_n > 0 then
      return msg('لا يمكن تكرار المستند، رقم المستند مكرر', 'Document number already used');
    end if;
    return null;
  end val_doc_no;

  function val_trns (p_form in varchar2, p_rowid in varchar2, p_request in varchar2, p_type in varchar2, p_date in varchar2,
                     p_store in varchar2, p_doc_no in varchar2, p_account in varchar2 default null,
                     p_to_store in varchar2 default null, p_from_store in varchar2 default null,
                     p_trnsfer_serial in varchar2 default null, p_currency in varchar2 default null,
                     p_rate in varchar2 default null) return varchar2 is
    l_type    number := to_num(p_type);
    l_date    date := to_dt(p_date);
    l_store   number := to_num(p_store);
    l_to      number := to_num(p_to_store);
    l_from    number := to_num(p_from_store);
    l_tser    number := to_num(p_trnsfer_serial);
    l_new     boolean := p_rowid is null;
    r         st_trns_mast%rowtype;
    l_lines   number := 0;
    l_msg     varchar2(4000);
    l_n       number;
    l_acc     number;
    l_rdate   date;
    t         st_trnsfer%rowtype;
  begin
    if not l_new then
      begin
        select * into r from st_trns_mast where rowid = chartorowid(p_rowid);
      exception when no_data_found then
        return msg('الحركة غير موجودة، أعد تحميل الصفحة', 'The document no longer exists, reload the page');
      end;
      -- CLOSE_POSTED: a posted document is read-only
      if nvl(r.post_flag, 0) = 1 then
        return msg('لا يمكن تعديل حركة مرحلة', 'A posted transaction cannot be changed');
      end if;
      select count(*) into l_lines from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      if l_lines > 0 and l_type != r.trns_type_code then
        return msg('لا يمكن تغيير نوع الحركة بعد إدخال التفاصيل', 'The transaction type cannot be changed once lines exist');
      end if;
      if l_lines > 0 and l_store != r.store_code then
        return msg('لا يمكن تغيير المخزن بعد إدخال التفاصيل', 'The store cannot be changed once lines exist');
      end if;
    end if;

    -- transaction type of the screen
    if l_type is null then
      return msg('يجب إدخال رقم الحركة', 'Enter the transaction type');
    end if;
    if type_in_screen(p_form, l_type, case when l_new then 1 else 0 end) = 0 then
      return msg('نوع الحركة غير مسموح به فى هذه الشاشة: ', 'Transaction type not allowed on this screen: ') || l_type;
    end if;

    l_msg := val_date(p_form, l_date);
    if l_msg is not null then return l_msg; end if;
    l_msg := val_store(l_store);
    if l_msg is not null then return l_msg; end if;

    -- account: shown and used by the posting when STACLNK has ACCOUNT_NO_TYPE = 6 for the type (SHOW_HIDE_ACC)
    if p_form in ('ST_TRANSFER_FROM', 'ST_TRANSFER_TO', 'ST_ADJUST_IN', 'ST_ADJUST_OUT', 'ST_RESERVATION') then
      select count(*) into l_n from staclnk where trns_type_code = l_type and account_no_type = 6;
      if l_n > 0 then
        select max(account_number1) into l_acc from st_store where store_code = l_store;
        if to_num(p_account) is null and l_acc is null then
          return msg('يجب إدخال رقم الحساب', 'Enter the account number');
        end if;
      end if;
      l_acc := to_num(p_account);
      if l_acc is not null then
        select count(*) into l_n from ac_master where account_number = l_acc and account_status = 1;
        if l_n = 0 then
          return msg('رقم الحساب غير صحيح', 'Invalid account number');
        end if;
      end if;
    end if;

    if p_form = 'ST_TRANSFER_FROM' then
      l_msg := val_store(l_to, 'TO');
      if l_msg is not null then return l_msg; end if;
      if l_to = l_store then                         -- STORE_LOV / TO_STORE_LOV exclude each other
        return msg('لا يمكن التحويل إلى نفس المخزن', 'The destination store must differ from the source store');
      end if;
      if not l_new then
        if l_store != r.store_code and r.trnsfer_serial is not null then
          return msg('لا يمكن تغيير المخزن المحول منه بعد حفظ التحويل', 'The source store cannot be changed after saving the transfer');
        end if;
        if trnsfer_received(r.trnsfer_serial, r.store_code) then
          return msg('تم استلام التحويل ولا يمكن التعديل', 'The transfer has been received and cannot be changed');
        end if;
        -- transfer issued from a request (REQ_TRNS_*, APP_CONV.trq_to_transfer): TRNS_DATE WHEN-VALIDATE-ITEM
        if r.req_trns_type_code is not null and r.req_trns_serial is not null then
          select max(trns_date) into l_rdate from st_trns_mast_request
           where trns_type_code = r.req_trns_type_code and trns_serial = r.req_trns_serial;
          if trunc(l_date) < trunc(l_rdate) then
            return msg('لا يمكن ان يكون تاريخ التحويل اصغر من تاريخ طلب التحويل', 'The transfer date cannot be before the transfer request date');
          end if;
        end if;
      end if;
    elsif p_form = 'ST_TRANSFER_TO' then
      if l_tser is null or l_from is null then
        return msg('يجب إدخال مسلسل التحويل والمخزن المحول منه', 'Enter the transfer serial and the source store');
      end if;
      if l_from = l_store then
        return msg('لا يمكن الاستلام من نفس المخزن', 'The source store must differ from the receiving store');
      end if;
      if not l_new and l_lines > 0 and (l_tser != r.trnsfer_serial or l_from != r.trnsfer_from_store) then
        return msg('لا يمكن تغيير رقم التحويل ويوجد تفاصيل', 'The transfer cannot be changed once lines exist');
      end if;
      -- TRNSFER_SERIAL LOV: TRNSFER_RECEIVING_DATE IS NULL, DELETE_FLAG = 0, APPROVE_FLAG = 1,
      --                     TRNSFER_TO_STORE = :STORE_CODE, TRNSFER_DATE <= :TRNS_DATE
      begin
        select * into t from st_trnsfer where trnsfer_serial = l_tser and trnsfer_from_store = l_from and nvl(delete_flag, 0) = 0;
      exception when no_data_found then
        return msg('مسلسل التحويل غير موجود', 'Transfer serial not found');
      end;
      if nvl(t.approve_flag, 0) != 1 then
        return msg('مسلسل التحويل غير موجود (التحويل غير معتمد)', 'Transfer serial not found (not approved)');
      end if;
      if t.trnsfer_to_store != l_store then
        return msg('هذا التحويل ليس لهذا المخزن، المخزن المحول إليه = ', 'This transfer is for another store: ') || t.trnsfer_to_store;
      end if;
      if trnsfer_receipts(l_tser, l_from, r.trns_type_code, r.trns_serial) > 0
         or (l_new and t.trnsfer_receiving_date is not null) then
        return msg('تم استلام هذا التحويل من قبل', 'This transfer has already been received');
      end if;
      if trunc(l_date) < trunc(t.trnsfer_date) then
        return msg('تاريخ الاستلام أصغر من تاريخ التحويل (' || fmt(t.trnsfer_date) || ')',
                   'The receiving date is before the transfer date (' || fmt(t.trnsfer_date) || ')');
      end if;
    elsif p_form = 'ST_RESERVATION' then
      if to_num(p_rate) is null then
        return msg('يجب ادخال معامل التحويل', 'Enter the currency rate');
      end if;
      if nvl(to_num(p_currency), 1) = 1 and to_num(p_rate) != 1 then
        return msg('معامل تحويل الريال يجب ان يكون ب 1', 'The rate of the local currency must be 1');
      end if;
    end if;

    return val_doc_no('MAST', l_type, to_num(p_doc_no), p_rowid);
  end val_trns;

  function val_req (p_rowid in varchar2, p_request in varchar2, p_type in varchar2, p_date in varchar2, p_store in varchar2,
                    p_to_store in varchar2, p_doc_no in varchar2) return varchar2 is
    l_type  number := to_num(p_type);
    l_store number := to_num(p_store);
    l_to    number := to_num(p_to_store);
    l_new   boolean := p_rowid is null;
    r       st_trns_mast_request%rowtype;
    l_n     number;
    l_msg   varchar2(4000);
  begin
    if not l_new then
      begin
        select * into r from st_trns_mast_request where rowid = chartorowid(p_rowid);
      exception when no_data_found then
        return msg('الحركة غير موجودة، أعد تحميل الصفحة', 'The document no longer exists, reload the page');
      end;
      select count(*) into l_n from st_trns_mast
       where req_trns_type_code = r.trns_type_code and req_trns_serial = r.trns_serial and nvl(delete_flag, 0) = 0;
      if l_n > 0 or nvl(r.to_transfer_flag, 0) = 1 then
        return msg('تم عمل حركة التحويل لهذا الطلب ولا يمكن التعديل', 'A transfer was issued for this request, it cannot be changed');
      end if;
      select count(*) into l_n from st_trns_det_request where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      if l_n > 0 and l_type != r.trns_type_code then
        return msg('لا يمكن تغيير نوع الحركة بعد إدخال التفاصيل', 'The transaction type cannot be changed once lines exist');
      end if;
    end if;
    if l_type is null then
      return msg('يجب إدخال رقم الحركة', 'Enter the transaction type');
    end if;
    if type_in_screen('ST_TRANSFER_REQUEST', l_type, case when l_new then 1 else 0 end) = 0 then
      return msg('نوع الحركة غير مسموح به فى هذه الشاشة: ', 'Transaction type not allowed on this screen: ') || l_type;
    end if;
    l_msg := val_date('ST_TRANSFER_REQUEST', to_dt(p_date));
    if l_msg is not null then return l_msg; end if;
    l_msg := val_store(l_store);
    if l_msg is not null then return l_msg; end if;
    l_msg := val_store(l_to, 'TO');
    if l_msg is not null then return l_msg; end if;
    if l_to = l_store then
      return msg('لا يمكن التحويل إلى نفس المخزن', 'The destination store must differ from the source store');
    end if;
    return val_doc_no('REQ', l_type, to_num(p_doc_no), p_rowid);
  end val_req;

  function val_taking (p_form in varchar2, p_rowid in varchar2, p_request in varchar2, p_store in varchar2,
                       p_date in varchar2) return varchar2 is
    l_store number := to_num(p_store);
    l_date  date := to_dt(p_date);
    l_msg   varchar2(4000);
    l_n     number;
  begin
    l_msg := val_store(l_store);
    if l_msg is not null then return l_msg; end if;
    if l_date is null then
      return msg('يجب إدخال تاريخ الجرد', 'Enter the stocktaking date');
    end if;
    -- ST_TAKING_DATE WHEN-VALIDATE-ITEM: CHECK_DATE (TRANSLATE.pll): no future date, not before ST_BASIC.MIN_DATE (wave 3: the
    -- legacy texts and the minimum date; no AC_BASIC period here, ST_STOCK_TAKING has no closed-period trigger)
    if trunc(l_date) > trunc(sysdate) then
      return msg('تاريخ الحركة أكبر من تاريخ اليوم', 'Transaction date is greater than today''s date');
    end if;
    declare
      l_min date;
    begin
      select min(min_date) into l_min from st_basic;
      l_min := nvl(l_min, to_date('01-01-' || to_char(to_number(to_char(sysdate, 'YYYY')) - 1), 'DD-MM-YYYY'));
      if trunc(l_date) < trunc(l_min) then
        return msg('الحد الأدنى لتاريخ الحركة هو ' || fmt(l_min), 'The least value accepted for Transaction Date is ' || fmt(l_min));
      end if;
    end;
    if p_form = 'ST_TAKING' and p_rowid is null then
      -- STORE_CODE / ST_TAKING_DATE WHEN-VALIDATE-ITEM (ST_TAKING_fmb.xml)
      select count(*) into l_n from st_stock_taking where store_code = l_store and st_taking_date = trunc(l_date);
      if l_n > 0 then
        return msg('تم جرد هذا المخزن من قبل في نفس التاريخ', 'Repeated date for the same store');
      end if;
    end if;
    return null;
  end val_taking;

  -- =================================================================================== after save
  procedure recheck_doc (r in st_trns_mast%rowtype) is
    l_s number := sgn(type_effect(r.trns_type_code));
  begin
    -- document level re-check at SAVE (the header date may have moved all lines): every issue line of the
    -- document must still be covered by the lot balance at its position, and no later transaction may become
    -- negative (receipt lines can only raise later balances, they are checked when reduced / deleted)
    if l_s >= 0 or nvl(r.delete_flag, 0) != 0 then return; end if;
    for d in (select item_serial, item_confg_id, basic_qty, store_code, trns_date, date_serial
                from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial)
    loop
      check_balance(nvl(d.store_code, r.store_code), d.item_confg_id, nvl(d.trns_date, r.trns_date), nvl(d.date_serial, r.date_serial),
                    d.item_serial, r.trns_type_code, r.trns_serial, d.item_serial, l_s * nvl(d.basic_qty, 0));
    end loop;
  end recheck_doc;

  procedure after_trns (p_form in varchar2, p_request in varchar2, p_rowid in varchar2) is
    r   st_trns_mast%rowtype;
    l_n number;
  begin
    if p_rowid is null then return; end if;
    begin
      select * into r from st_trns_mast where rowid = chartorowid(p_rowid);
    exception when no_data_found then return;
    end;
    if p_request = 'CREATE' and p_form = 'ST_TRANSFER_TO' then
      copy_transfer_lines(r);
    elsif p_request = 'SAVE' then
      select count(*) into l_n from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      if p_form = 'ST_RESERVATION' then
        select l_n + count(*) into l_n from st_trns_services where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
        select l_n + count(*) into l_n from st_trns_stand_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
        if l_n = 0 then
          err(-20111, 'غير مسموح بحفظ الفاتورة بدون أصناف أو خدمات', 'The document cannot be saved without items or services');
        end if;
        select count(*) into l_n from st_trns_services
         where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and nvl(service_cost, 0) <= 0;
        if l_n > 0 then
          err(-20115, 'سعر بيع الخدمة يجب أن يكون أكبر من صفر', 'The service price must be greater than zero');
        end if;
      elsif l_n = 0 then
        err(-20111, 'لا يمكن حفظ الحركة بدون تفاصيل', 'You can''t save the master without details');
      end if;
      recheck_doc(r);
    end if;
  end after_trns;

  procedure after_req (p_request in varchar2, p_rowid in varchar2) is
    r   st_trns_mast_request%rowtype;
    l_n number;
  begin
    if p_rowid is null or p_request != 'SAVE' then return; end if;
    begin
      select * into r from st_trns_mast_request where rowid = chartorowid(p_rowid);
    exception when no_data_found then return;
    end;
    select count(*) into l_n from st_trns_det_request where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    if l_n = 0 then
      err(-20111, 'لا يمكن حفظ الحركة بدون تفاصيل', 'You can''t save the master without details');
    end if;
  end after_req;

  procedure after_taking (p_form in varchar2, p_request in varchar2, p_rowid in varchar2, p_store in varchar2 default null,
                          p_date in varchar2 default null, p_serial in varchar2 default null) is
    l_n     number;
    l_store number;
    l_date  date;
    l_ser   number;
  begin
    if p_form = 'ST_TAKING2' and p_request = 'DELETE' then
      -- ST_STOCK_TAKING_TEMP_DET has no foreign key to its master: remove the lines of the deleted count
      -- (ST_TAKING2.fmx: DELETE FROM ST_STOCK_TAKING_TEMP_DET WHERE STORE_CODE = .. AND ST_TAKING_DATE = .. AND SERIAL = ..)
      l_store := to_num(p_store);
      l_date := to_dt(p_date);
      l_ser := to_num(p_serial);
      delete from st_stock_taking_temp_det where store_code = l_store and st_taking_date = l_date and serial = l_ser;
      return;
    end if;
    if p_request != 'SAVE' or p_rowid is null then return; end if;
    if p_form = 'ST_TAKING2' then
      begin
        select store_code, st_taking_date, serial into l_store, l_date, l_ser from st_stock_taking_temp where rowid = chartorowid(p_rowid);
      exception when no_data_found then return;
      end;
      select count(*) into l_n from st_stock_taking_temp_det where store_code = l_store and st_taking_date = l_date and serial = l_ser;
    else
      begin
        select store_code, st_taking_date into l_store, l_date from st_stock_taking where rowid = chartorowid(p_rowid);
      exception when no_data_found then return;
      end;
      select count(*) into l_n from st_stock_taking_det where store_code = l_store and st_taking_date = l_date;
    end if;
    if l_n = 0 then
      err(-20111, 'لا يمكن الحفظ بدون تفاصيل', 'You can''t save without details');
    end if;
  end after_taking;

  -- =================================================================================== trigger hooks
  procedure mast_row (p_inserting in boolean, p_updating in boolean,
                      p_type in number, p_serial in number, p_date in date, p_store in number,
                      p_doc_no in out number, p_desc_a in out varchar2, p_desc_e in varchar2,
                      p_delete_flag in out number, p_post_flag in out number, p_account1 in out number,
                      p_trnsfer_type in out number, p_trnsfer_serial in out number,
                      p_from_store in out number, p_to_store in out number,
                      p_old_date in date, p_old_trnsfer_serial in number, p_old_from_store in number, p_old_store in number) is
    l_form varchar2(128) := cur_form;
    l_n    number;
    t      st_trnsfer%rowtype;
  begin
    if not is_trns_form(l_form) or not screen_type(l_form, p_type) then return; end if;
    if p_inserting then
      p_delete_flag := nvl(p_delete_flag, 0);
      p_post_flag := nvl(p_post_flag, 0);
      -- account default: TRNS_TYPE_CODE WHEN-VALIDATE-ITEM -> ST_STORE.ACCOUNT_NUMBER1 when the type uses ACCOUNT_NO_TYPE 6
      if p_account1 is null then
        select count(*) into l_n from staclnk where trns_type_code = p_type and account_no_type = 6;
        if l_n > 0 then
          select max(account_number1) into p_account1 from st_store where store_code = p_store;
        end if;
      end if;
      if l_form = 'ST_TRANSFER_TO' then
        -- receive: the document takes the number / description of the issued transfer and marks it received
        p_trnsfer_type := 1;
        p_to_store := p_store;
        begin
          select * into t from st_trnsfer where trnsfer_serial = p_trnsfer_serial and trnsfer_from_store = p_from_store;
          if p_doc_no is null then p_doc_no := t.trnsfer_doc_no; end if;
          if p_desc_a is null then p_desc_a := t.trnsfer_desc_a; end if;
          update st_trnsfer set trnsfer_receiving_date = p_date
           where trnsfer_serial = p_trnsfer_serial and trnsfer_from_store = p_from_store;
        exception when no_data_found then null;          -- the FK TRNS_MAST_ST_TRNSFER_FK reports it
        end;
      else
        if p_desc_a is null then p_desc_a := type_desc(p_type); end if;
        if p_doc_no is null then p_doc_no := next_doc_no(l_form, p_type, p_store, p_serial); end if;
      end if;
      if l_form = 'ST_TRANSFER_FROM' then
        -- issue: a new ST_TRNSFER row (serial = MAX + 1 per source store), then the document points to it
        p_trnsfer_type := 0;
        p_from_store := p_store;
        if p_trnsfer_serial is null then
          select nvl(max(trnsfer_serial), 0) + 1 into p_trnsfer_serial from st_trnsfer where trnsfer_from_store = p_store;
        end if;
        begin
          insert into st_trnsfer (trnsfer_serial, trnsfer_date, trnsfer_from_store, trnsfer_to_store, delete_flag, post_flag,
                                  approve_flag, trnsfer_doc_no, trnsfer_desc_a, trnsfer_desc_e)
          values (p_trnsfer_serial, p_date, p_store, p_to_store, 0, 0, 1, p_doc_no, p_desc_a, p_desc_e);
        exception when dup_val_on_index then
          err(-20105, 'مسلسل التحويل مستخدم من قبل: ' || p_trnsfer_serial, 'Transfer serial already used: ' || p_trnsfer_serial);
        end;
      end if;
    elsif p_updating then
      if l_form = 'ST_TRANSFER_FROM' then
        p_from_store := p_store;
        if p_trnsfer_serial is not null then
          update st_trnsfer
             set trnsfer_to_store = p_to_store, trnsfer_date = p_date, trnsfer_doc_no = p_doc_no, trnsfer_desc_a = p_desc_a
           where trnsfer_serial = p_trnsfer_serial and trnsfer_from_store = p_store;
        end if;
      elsif l_form = 'ST_TRANSFER_TO' then
        p_to_store := p_store;
        if nvl(p_trnsfer_serial, -1) != nvl(p_old_trnsfer_serial, -1) or nvl(p_from_store, -1) != nvl(p_old_from_store, -1) then
          update st_trnsfer set trnsfer_receiving_date = null
           where trnsfer_serial = p_old_trnsfer_serial and trnsfer_from_store = p_old_from_store;
          update st_trnsfer set trnsfer_receiving_date = p_date
           where trnsfer_serial = p_trnsfer_serial and trnsfer_from_store = p_from_store;
        elsif p_date != p_old_date then
          update st_trnsfer set trnsfer_receiving_date = p_date
           where trnsfer_serial = p_trnsfer_serial and trnsfer_from_store = p_from_store;
        end if;
      end if;
    end if;
  end mast_row;

  -- APP_RULES_ST_MAST_BD: legacy KEY-DELREC (ST_TRNS_MAST): posted documents cannot be deleted; the lines are
  -- deleted with the document (the legacy deleted them one by one, each with the next-transaction balance check)
  procedure mast_delete (p_type in number, p_serial in number, p_store in number, p_post_flag in number,
                         p_trnsfer_serial in number, p_from_store in number,
                         p_req_type in number default null, p_req_serial in number default null) is
    l_form varchar2(128) := cur_form;
    l_n    number;
  begin
    if not is_trns_form(l_form) or not screen_type(l_form, p_type) then return; end if;
    if nvl(p_post_flag, 0) = 1 then
      err(-20101, 'لا يمكن حذف حركات مرحلة', 'You cann''t delete Posted transactions');
    end if;
    -- ST_TRNS_MAST is mutating here: only ST_TRNSFER is read (a receipt always stamps TRNSFER_RECEIVING_DATE and
    -- val_trns allows one receipt per transfer)
    if l_form = 'ST_TRANSFER_FROM' and p_trnsfer_serial is not null then
      select count(*) into l_n from st_trnsfer
       where trnsfer_serial = p_trnsfer_serial and trnsfer_from_store = p_store and trnsfer_receiving_date is not null;
      if l_n > 0 then
        err(-20105, 'تم استلام التحويل ولا يمكن الحذف', 'The transfer has been received and cannot be deleted');
      end if;
      update st_trnsfer set delete_flag = 1 where trnsfer_serial = p_trnsfer_serial and trnsfer_from_store = p_store;
    elsif l_form = 'ST_TRANSFER_TO' and p_trnsfer_serial is not null then
      update st_trnsfer set trnsfer_receiving_date = null
       where trnsfer_serial = p_trnsfer_serial and trnsfer_from_store = p_from_store;
    end if;
    -- ST_TRANSFER_FROM.fmx: UPDATE ST_TRNS_MAST_REQUEST SET TO_TRANSFER_FLAG = 0 .. (the transfer request the deleted
    -- transfer was issued from - e.g. by APP_CONV.trq_to_transfer - is open again)
    if l_form = 'ST_TRANSFER_FROM' and p_req_type is not null and p_req_serial is not null then
      update st_trns_mast_request set to_transfer_flag = 0 where trns_type_code = p_req_type and trns_serial = p_req_serial;
    end if;
    g_mast_del := true;
    begin
      delete from st_trns_det where trns_type_code = p_type and trns_serial = p_serial;
      if l_form = 'ST_RESERVATION' then
        delete from st_trns_services where trns_type_code = p_type and trns_serial = p_serial;
        delete from st_trns_stand_det where trns_type_code = p_type and trns_serial = p_serial;
      end if;
    exception when others then
      g_mast_del := false;
      raise;
    end;
    g_mast_del := false;
  end mast_delete;

  -- ST_RESERVATION ITEM_CODE / UNIT_CODE WHEN-VALIDATE-ITEM (.fmx SQL, wave 3): UNIT_PRICE_CURR := ROUND(REDUCTION_PRICE / rate, 2),
  -- else the wide price (ST_STORE.DEAL_TYPE = 1) or the retail price / rate, the store prices of ST_STORE_ITEM_UNIT replacing the
  -- item's; UNIT_PRICE := UNIT_PRICE_CURR * rate (the page line price is in riyal; APP_ACT_ST.rsv_after_save derives UNIT_PRICE_CURR)
  function rsv_price (p_store in number, p_group in number, p_item in varchar2, p_unit in number, p_rate in number) return number is
    l_rate number := nvl(nullif(p_rate, 0), 1);
    l_red  number;
    l_wide number;
    l_ret  number;
    l_deal number;
  begin
    select max(round(reduction_price / l_rate, 2)), max(round(wide_sale_price / l_rate, 2)), max(round(retail_sale_price / l_rate, 2))
      into l_red, l_wide, l_ret
      from st_item_unit where unit_code = p_unit and item_code = p_item and group_code = p_group;
    for s in (select round(wide_sale_price / l_rate, 2) w, round(retail_sale_price / l_rate, 2) r from st_store_item_unit
               where unit_code = p_unit and item_code = p_item and group_code = p_group and store_code = p_store) loop
      l_wide := s.w; l_ret := s.r;
    end loop;
    select max(deal_type) into l_deal from st_store where store_code = p_store;
    return nvl(l_red, case when l_deal = 1 then l_wide else l_ret end) * l_rate;
  end rsv_price;

  procedure det_row (p_inserting in boolean, p_updating in boolean,
                     p_type in number, p_serial in number, p_item_serial in number,
                     p_group in out number, p_item in varchar2, p_unit in out number, p_confg in out number,
                     p_qty in number, p_bonus in number, p_basic_qty in out number,
                     p_unit_price in out number, p_unit_cost in out number, p_cost_flag in out number,
                     p_lot_number in number, p_expiry in date, p_disc1_ratio in number,
                     p_old_group in number, p_old_item in varchar2, p_old_unit in number, p_old_confg in number,
                     p_old_qty in number, p_old_basic_qty in number, p_old_unit_price in number, p_old_unit_cost in number,
                     p_trnsfer_serial in out number, p_trnsfer_from in out number, p_trnsfer_to in out number) is
    l_form    varchar2(128) := cur_form;
    m         st_trns_mast%rowtype;
    l_effect  number;
    l_s       number;
    l_factor  number;
    l_n       number;
    l_max     number;
    l_single  number;
    l_expflag number;
    l_supp    number;
    l_lot     varchar2(200);
    l_new_lot boolean := false;
    l_price   number;
    l_iss     number;
    l_rec     number;
  begin
    if not is_trns_form(l_form) or not screen_type(l_form, p_type) then return; end if;
    if p_updating
       and nvl(p_group, -1) = nvl(p_old_group, -1) and nvl(p_item, '#') = nvl(p_old_item, '#')
       and nvl(p_unit, -1) = nvl(p_old_unit, -1) and nvl(p_confg, -1) = nvl(p_old_confg, -1)
       and nvl(p_qty, -1) = nvl(p_old_qty, -1) and nvl(p_basic_qty, -1) = nvl(p_old_basic_qty, -1)
       and nvl(p_unit_price, -1) = nvl(p_old_unit_price, -1) and nvl(p_unit_cost, -1) = nvl(p_old_unit_cost, -1) then
      return;       -- dates / delete flag / transfer stores cascaded by ST_TRNS_MAST_UP: nothing to check (and no ST_TRNS_MAST read)
    end if;
    begin
      select * into m from st_trns_mast where trns_type_code = p_type and trns_serial = p_serial;
    exception when no_data_found then return;
    end;
    if nvl(m.post_flag, 0) = 1 then
      err(-20101, 'لا يمكن تعديل حركة مرحلة', 'A posted transaction cannot be changed');
    end if;
    l_effect := type_effect(p_type);
    l_s := sgn(l_effect);
    if l_form in ('ST_TRANSFER_FROM', 'ST_TRANSFER_TO') then
      -- the legacy transfer lines carry the transfer key and stores of the header (all 11101 / 11201 lines in the data)
      p_trnsfer_serial := m.trnsfer_serial;
      p_trnsfer_from := m.trnsfer_from_store;
      p_trnsfer_to := m.trnsfer_to_store;
    end if;

    -- item, unit, quantity -> BASIC_QTY (UNIT_CODE / QUANTITY WHEN-VALIDATE-ITEM: BASIC_QTY := QUANTITY * NDB_FACTOR)
    check_item(p_group, p_item);
    l_factor := check_unit(p_group, p_item, p_unit);
    if l_form = 'ST_OPEN_BALANCE' then
      if p_qty is null or p_qty < 0 then
        err(-20109, 'القيمة يجب أن تكون أكبر من الصفر', 'Value must be greater than Zero');
      end if;
    elsif l_form = 'ST_RESERVATION' then
      if nvl(p_qty, 0) + nvl(p_bonus, 0) <= 0 or nvl(p_qty, 0) < 0 then
        err(-20109, 'الكمية و البونص يجب أن يكون مجموعهما أكبر من صفر', 'Quantity plus bonus must be greater than zero');
      end if;
    elsif nvl(p_qty, 0) <= 0 then
      err(-20109, 'الكمية يجب ان تكون أكبر من صفر', 'The quantity must be greater than zero');
    end if;
    p_basic_qty := nvl(p_qty, 0) * l_factor;

    if p_inserting then
      -- ST_BASIC.SINGLE_ITEM / TRNS_MAX_ITEMS (WHEN-NEW-ITEM-INSTANCE of the detail block)
      select nvl(max(single_item), 0), max(trns_max_items) into l_single, l_max from st_basic;
      if l_single = 1 or l_max is not null then
        select count(*), sum(case when group_code = p_group and item_code = p_item then 1 else 0 end) into l_n, l_iss
          from st_trns_det where trns_type_code = p_type and trns_serial = p_serial;
        if l_max is not null and l_n + 1 > l_max then
          err(-20109, 'لقد تم إدخال ' || l_n || ' صنف فى هذه الحركة، غير مسموح بالمزيد من الأصناف',
                      l_n || ' items were entered in this transaction, no more items are allowed');
        end if;
        if l_single = 1 and nvl(l_iss, 0) > 0 then
          err(-20109, 'غير مسموح بتكرار الصنف', 'Repeating an item is not allowed');
        end if;
      end if;
    end if;

    if l_form in ('ST_TRANSFER_FROM', 'ST_ADJUST_OUT', 'ST_RESERVATION') then
      -- issue lines: lot = the one chosen, else the first lot with balance (ITEM_CONFG LOV shows lots with balance > 0)
      if l_form = 'ST_TRANSFER_FROM' and trnsfer_received(m.trnsfer_serial, m.store_code) then
        err(-20105, 'تم استلام التحويل ولا يمكن التعديل', 'The transfer has been received and cannot be changed');
      end if;
      if p_confg is null then
        p_confg := fefo_lot(m.store_code, p_group, p_item, m.trns_date, m.date_serial, p_item_serial, p_basic_qty);
        if p_confg is null then
          err(-20106, 'هذا الصنف ليس له رصيد: ' || p_item, 'This item has no balance: ' || p_item);
        end if;
      elsif not lot_of_item(p_confg, p_group, p_item) then
        err(-20107, 'الشحنة لا تخص هذا الصنف', 'The lot does not belong to this item');
      end if;
      -- unit cost = average cost of the lot at this position (ITEM_CONFG_ID WHEN-VALIDATE-ITEM, GET_UNIT_COST_CONFG)
      if p_unit_cost is null or nvl(p_confg, -1) != nvl(p_old_confg, -1) then
        p_unit_cost := get_unit_cost_confg(m.store_code, p_group, p_item, p_confg, m.trns_date, m.date_serial, p_item_serial);
      end if;
      if p_unit_price is null then
        if l_form = 'ST_TRANSFER_FROM' then
          select max(unit_price) into p_unit_price from st_item_confg where item_confg_id = p_confg;   -- lot price
        elsif l_form = 'ST_ADJUST_OUT' then
          p_unit_price := p_unit_cost * l_factor;
        end if;
      end if;
      if l_form = 'ST_RESERVATION' and p_unit_price is null then
        p_unit_price := rsv_price(m.store_code, p_group, p_item, p_unit, m.currency_rate);    -- wave 3: legacy default price
      end if;
      if l_form = 'ST_RESERVATION' and nvl(p_unit_price, 0) <= 0 then
        err(-20115, 'سعر الصنف يجب أن يكون أكبر من صفر', 'The item price must be greater than zero');
      end if;
      p_cost_flag := nvl(p_cost_flag, 1);

    elsif l_form = 'ST_TRANSFER_TO' then
      -- receive lines: only lots of the issued transfer, received quantity <= transferred quantity
      if p_confg is null then
        for lc in (select distinct dc.item_confg_id
                     from st_trns_det_cost dc, st_trns_mast mm, st_trns_type tt
                    where mm.trns_type_code = dc.trns_type_code and mm.trns_serial = dc.trns_serial
                      and tt.trns_type_code = mm.trns_type_code and tt.effect = 5 and tt.trns_type = 9
                      and mm.trnsfer_serial = m.trnsfer_serial and mm.trnsfer_from_store = m.trnsfer_from_store
                      and nvl(mm.delete_flag, 0) = 0 and dc.group_code = p_group and dc.item_code = p_item
                    order by 1)
        loop
          if trnsfer_qty(5, m.trnsfer_serial, m.trnsfer_from_store, p_group, p_item, lc.item_confg_id)
             > trnsfer_qty(6, m.trnsfer_serial, m.trnsfer_from_store, p_group, p_item, lc.item_confg_id, p_type, p_serial, p_item_serial) then
            p_confg := lc.item_confg_id;
            exit;
          end if;
        end loop;
      end if;
      l_iss := trnsfer_qty(5, m.trnsfer_serial, m.trnsfer_from_store, p_group, p_item, p_confg);
      if p_confg is null or l_iss = 0 then
        err(-20105, 'الصنف / الشحنة غير موجودة فى التحويل', 'The item / lot is not part of the transfer');
      end if;
      l_rec := trnsfer_qty(6, m.trnsfer_serial, m.trnsfer_from_store, p_group, p_item, p_confg, p_type, p_serial, p_item_serial);
      if l_rec + p_basic_qty > l_iss then
        err(-20105, 'الكمية المستلمة أكبر من الكمية المحولة، المتبقى = ' || to_char(l_iss - l_rec),
                    'Received quantity exceeds the transferred quantity, remaining = ' || to_char(l_iss - l_rec));
      end if;
      if p_unit_cost is null or nvl(p_confg, -1) != nvl(p_old_confg, -1) then
        p_unit_cost := trnsfer_cost(m.trnsfer_serial, m.trnsfer_from_store, p_group, p_item, p_confg);
      end if;
      p_unit_price := nvl(p_unit_price, p_unit_cost * l_factor);
      p_cost_flag := nvl(p_cost_flag, 1);

    elsif l_form in ('ST_OPEN_BALANCE', 'ST_ADJUST_IN') then
      -- receipt lines with lot parameters: GET_THE_CONFIG -> GET_CONFG_ID(.., create if not exist)
      if p_confg is null then
        if p_lot_number is null then
          err(-20107, 'يجب إدخال محددات الشحنات (الشحنة أو رقم التشغيلة)', 'Must Enter Parameter For Config (lot or lot number)');
        end if;
        l_expflag := group_expire_flag(p_group);
        if l_form = 'ST_OPEN_BALANCE' and l_expflag = 1 and p_expiry is null then
          -- ST_OPEN_BALANCE line PRE-INSERT: IF :LOT_NUMBER IS NULL OR :EXPIRE_DATE IS NULL .. -> MSG(.., 1); the lot is always
          -- found or created from the lot number AND the expiry date (no lookup by the lot number alone)
          err(-20107, 'يجب إدخال محددات الشحنات (رقم التشغيلة وتاريخ الصلاحية)', 'Must Enter Parameter For Config (lot number and expiry date)');
        end if;
        if l_form = 'ST_ADJUST_IN' and p_expiry is not null and trunc(p_expiry) <= trunc(m.trns_date) then
          -- ST_adjust_IN EXPIRE_DATE WHEN-VALIDATE-ITEM: IF :TRNS_DATE >= :EXPIRE_DATE THEN MSG(.., 1)
          err(-20107, 'تاريخ الصلاحية يجب أن يكون أكبر من تاريخ الحركة', 'Expire Date Must Be More Than Tranaction Date');
        end if;
        if p_expiry is null then
          -- existing lot with this lot number (ST_TRANSFER_FROM.fmx: SELECT MAX(ITEM_CONFG_ID) .. WHERE LOT_NUMBER = ..)
          select max(item_confg_id) into p_confg from st_item_confg
           where group_code = p_group and item_code = p_item and lot_number = to_char(p_lot_number);
          if p_confg is null and l_expflag = 1 then
            err(-20107, 'يجب إدخال تاريخ الصلاحية للشحنة الجديدة ' || p_lot_number, 'Enter the expiry date of the new lot ' || p_lot_number);
          end if;
        end if;
        if p_confg is null then
          if l_form = 'ST_OPEN_BALANCE' then l_supp := m.supplier_code; end if;
          if l_supp is null then
            select max(supplier) into l_supp from st_item where item_group_code = p_group and item_code = p_item;
          end if;
          l_lot := to_char(p_lot_number);
          p_confg := get_confg_id(p_item, p_group, l_supp, p_unit_price, l_lot,
                                  case when l_expflag = 1 then p_expiry end, nvl(p_disc1_ratio, 0), m.store_code, true);
          if nvl(p_confg, -1) < 0 then
            err(-20107, 'تعذر إنشاء الشحنة', 'The lot could not be created');
          end if;
          l_new_lot := true;
        end if;
      elsif not lot_of_item(p_confg, p_group, p_item) then
        err(-20107, 'الشحنة لا تخص هذا الصنف', 'The lot does not belong to this item');
      end if;
      if p_unit_price is null then
        select max(unit_price) into p_unit_price from st_item_confg where item_confg_id = p_confg;
      end if;
      if p_unit_cost is null then
        -- ST_ADJUST_IN: ITEM_CONFG_ID WHEN-VALIDATE-ITEM takes the average cost of the lot; UNIT_CODE WHEN-VALIDATE-ITEM
        -- falls back to UNIT_PRICE / factor.  ST_OPEN_BALANCE: the cost is typed (that fallback is commented out in
        -- the .fmb), so only the lot average / ST_ITEM.UNIT_COST are proposed, otherwise the cost is required.
        if not l_new_lot then
          l_price := get_unit_cost_confg(m.store_code, p_group, p_item, p_confg, m.trns_date, m.date_serial, p_item_serial);
        end if;
        if nvl(l_price, 0) = 0 then
          select max(unit_cost) into l_price from st_item where item_group_code = p_group and item_code = p_item;
        end if;
        if nvl(l_price, 0) = 0 then
          if l_form = 'ST_ADJUST_IN' then
            l_price := p_unit_price / l_factor;
          else
            err(-20109, 'يجب إدخال تكلفة الوحدة', 'Enter the unit cost');
          end if;
        end if;
        p_unit_cost := l_price;
      end if;
      p_cost_flag := nvl(p_cost_flag, 0);
      if l_form = 'ST_OPEN_BALANCE' and p_inserting then
        -- CHECK_NEXT_POSTED_TRANS: no opening balance before a posted transaction of the item in this store
        select count(*) into l_n
          from st_trns_det_cost c, st_trns_mast mm
         where mm.trns_type_code = c.trns_type_code and mm.trns_serial = c.trns_serial and nvl(mm.post_flag, 0) = 1
           and c.group_code = p_group and c.item_code = p_item and mm.trns_date > m.trns_date and mm.store_code = m.store_code
           and rownum = 1;
        if l_n > 0 then
          err(-20106, 'الصنف ' || p_item || ' له حركة مرحلة بتاريخ لاحق', 'The item ' || p_item || ' has posted transaction with a leading date');
        end if;
      end if;
    end if;

    -- stock balance of the lot (issues, and receipts reduced / moved to another lot)
    if p_inserting then
      if l_s < 0 then
        check_balance(m.store_code, p_confg, m.trns_date, m.date_serial, p_item_serial, p_type, p_serial, p_item_serial, -p_basic_qty);
      end if;
    elsif p_updating then
      if nvl(p_confg, -1) = nvl(p_old_confg, -1) then
        if l_s * (p_basic_qty - nvl(p_old_basic_qty, 0)) < 0 then
          check_balance(m.store_code, p_confg, m.trns_date, m.date_serial, p_item_serial, p_type, p_serial, p_item_serial, l_s * p_basic_qty);
        end if;
      else
        if l_s > 0 and p_old_confg is not null then
          check_balance(m.store_code, p_old_confg, m.trns_date, m.date_serial, p_item_serial, p_type, p_serial, p_item_serial, 0);
        elsif l_s < 0 then
          check_balance(m.store_code, p_confg, m.trns_date, m.date_serial, p_item_serial, p_type, p_serial, p_item_serial, -p_basic_qty);
        end if;
      end if;
    end if;
  end det_row;

  -- APP_RULES_ST_DET_BD: legacy detail KEY-DELREC: no deletion in a posted document; deleting a receipt line must not
  -- make a later transaction negative (UPDATE_NEXT_TRNS_CONFG); lines of a received issue transfer are locked
  procedure det_delete (p_type in number, p_serial in number, p_item_serial in number, p_store in number,
                        p_date in date, p_dser in number, p_confg in number, p_basic_qty in number) is
    l_form varchar2(128) := cur_form;
    m      st_trns_mast%rowtype;
    l_s    number;
  begin
    if not is_trns_form(l_form) or not screen_type(l_form, p_type) then return; end if;
    if not g_mast_del then                           -- ST_TRNS_MAST is mutating while APP_RULES_ST_MAST_BD cascades
      begin
        select * into m from st_trns_mast where trns_type_code = p_type and trns_serial = p_serial;
        if nvl(m.post_flag, 0) = 1 then
          err(-20101, 'لا يمكن حذف حركات مرحلة', 'You cann''t delete Posted transactions');
        end if;
        if l_form = 'ST_TRANSFER_FROM' and trnsfer_received(m.trnsfer_serial, m.store_code) then
          err(-20105, 'تم استلام التحويل ولا يمكن التعديل', 'The transfer has been received and cannot be changed');
        end if;
      exception when no_data_found then null;
      end;
    end if;
    l_s := sgn(type_effect(p_type));
    if l_s > 0 and p_confg is not null then
      check_balance(p_store, p_confg, p_date, p_dser, p_item_serial, p_type, p_serial, p_item_serial, 0);
    end if;
  end det_delete;

  procedure req_mast_row (p_inserting in boolean, p_type in number, p_desc_a in out varchar2, p_delete_flag in out number,
                          p_post_flag in out number, p_to_transfer_flag in out number) is
  begin
    if nvl(cur_form, '#') != 'ST_TRANSFER_REQUEST' or not p_inserting then return; end if;
    p_delete_flag := nvl(p_delete_flag, 0);
    p_post_flag := nvl(p_post_flag, 0);
    p_to_transfer_flag := nvl(p_to_transfer_flag, 0);
    if p_desc_a is null then p_desc_a := type_desc(p_type); end if;
  end req_mast_row;

  procedure req_det_row (p_type in number, p_serial in number, p_group in out number, p_item in varchar2,
                         p_unit in out number, p_qty in number, p_basic_qty in out number, p_cost_flag in out number) is
    l_factor number;
    l_n      number;
    l_flag   number;
  begin
    if nvl(cur_form, '#') != 'ST_TRANSFER_REQUEST' then return; end if;
    select nvl(max(to_transfer_flag), 0) into l_flag from st_trns_mast_request where trns_type_code = p_type and trns_serial = p_serial;
    select count(*) into l_n from st_trns_mast
     where req_trns_type_code = p_type and req_trns_serial = p_serial and nvl(delete_flag, 0) = 0;
    if l_n > 0 or l_flag = 1 then
      err(-20112, 'تم عمل حركة التحويل لهذا الطلب ولا يمكن التعديل', 'A transfer was issued for this request, it cannot be changed');
    end if;
    check_item(p_group, p_item);
    l_factor := check_unit(p_group, p_item, p_unit);
    if nvl(p_qty, 0) <= 0 then
      err(-20109, 'القيمة يجب أن تكون أكبر من صفر', 'The value must be greater than zero');
    end if;
    p_basic_qty := p_qty * l_factor;
    p_cost_flag := nvl(p_cost_flag, 0);
  end req_det_row;

  procedure taking_line (p_store in number, p_date in date, p_group in out number, p_item in varchar2,
                         p_unit in out number, p_confg in number, p_qty in number, p_basic_qty in out number,
                         p_unit_price in out number, p_unit_cost in out number, p_factor out number) is
    l_cost number;
  begin
    check_item(p_group, p_item);
    p_factor := check_unit(p_group, p_item, p_unit);
    if p_qty is null then
      err(-20113, 'يجب إدخال الكمية', 'Enter the quantity');
    elsif p_qty < 0 then
      err(-20113, 'الكمية يجب ألا تكون سالبة', 'The quantity cannot be negative');
    end if;
    p_basic_qty := p_qty * p_factor;
    if p_confg is not null then
      if not lot_of_item(p_confg, p_group, p_item) then
        err(-20107, 'الشحنة لا تخص هذا الصنف', 'The lot does not belong to this item');
      end if;
    elsif group_expire_flag(p_group) = 1 then
      err(-20107, 'يجب ادخال الشحنة (تاريخ الصلاحية) للصنف ' || p_item, 'Enter the lot (expiry date) of item ' || p_item);
    end if;
    -- "إنزال تكلفة أصناف الجرد": unit cost = book average cost of the lot at the stocktaking date
    if p_unit_price is null then
      if p_confg is not null then
        l_cost := get_unit_cost_confg(p_store, p_group, p_item, p_confg, p_date);
      end if;
      if nvl(l_cost, 0) = 0 then
        select max(unit_cost) into l_cost from st_item where item_group_code = p_group and item_code = p_item;
      end if;
      p_unit_price := l_cost * p_factor;
    end if;
    p_unit_cost := p_unit_price / p_factor;
  end taking_line;

  -- ST_TAKING (wave 3, source ST\FMB\ST_TAKING_fmb.xml, module ST_TAKING1):
  --   * line PRE-INSERT: IF :EXPIRE_DATE IS NULL OR :UNIT_CODE IS NULL THEN MSG('يجب إدخال محددات الشحنات', .., 1) -- the expiry date
  --     (and lot number) come from the chosen lot (ITEM_CONFG_LOV), so every new line needs a lot with an expiry date;
  --     :UNIT_COST := GET_UNIT_COST_CONFG(store, group, item, lot, count date, :UNIT_CODE) (sic: the unit code lands in the
  --     DT_SERIAL argument) and :UNIT_PRICE := :UNIT_COST * FACTOR -- a cost typed on a new line is replaced;
  --   * SALES_PRICE = the lot price (ITEM_CONFG_LOV returns ST_ITEM_CONFG.UNIT_PRICE; data: 340 for item 301040001 whose
  --     retail price is 299).  Saved lines keep their cost (CALC_COST / the loads set it explicitly).
  procedure taking_det_row (p_inserting in boolean, p_store in number, p_date in date, p_group in out number, p_item in varchar2,
                            p_unit in out number, p_confg in number, p_qty in number, p_basic_qty in out number,
                            p_unit_price in out number, p_unit_cost in out number, p_sales_price in out number) is
    l_factor number;
    l_exp    date;
  begin
    if nvl(cur_form, '#') != 'ST_TAKING' then return; end if;
    if p_inserting then
      if p_confg is not null then
        select max(expire_date) into l_exp from st_item_confg where item_confg_id = p_confg;
      end if;
      if p_confg is null or l_exp is null then
        err(-20107, 'يجب إدخال محددات الشحنات', 'Must Enter Parameter For Config');
      end if;
      p_unit_price := null;          -- recomputed below from the book cost of the lot
    end if;
    taking_line(p_store, p_date, p_group, p_item, p_unit, p_confg, p_qty, p_basic_qty, p_unit_price, p_unit_cost, l_factor);
    if p_inserting then
      p_unit_cost := get_unit_cost_confg(p_store, p_group, p_item, p_confg, p_date, p_unit);
      p_unit_price := p_unit_cost * l_factor;
    end if;
    if p_sales_price is null and p_confg is not null then
      select max(unit_price) into p_sales_price from st_item_confg where item_confg_id = p_confg;
    end if;
    if p_sales_price is null then
      select max(retail_sale_price) into p_sales_price from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit;
    end if;
  end taking_det_row;

  -- wave-2 row rule string (active until the triggers are regenerated): no insert / update distinction
  procedure taking_det_row (p_store in number, p_date in date, p_group in out number, p_item in varchar2,
                            p_unit in out number, p_confg in number, p_qty in number, p_basic_qty in out number,
                            p_unit_price in out number, p_unit_cost in out number, p_sales_price in out number) is
  begin
    taking_det_row(false, p_store, p_date, p_group, p_item, p_unit, p_confg, p_qty, p_basic_qty, p_unit_price, p_unit_cost, p_sales_price);
  end taking_det_row;

  procedure taking_det_row2 (p_store in number, p_date in date, p_group in out number, p_item in varchar2,
                             p_unit in out number, p_confg in number, p_qty in number, p_basic_qty in out number,
                             p_unit_price in out number, p_unit_cost in out number) is
    l_factor number;
  begin
    if nvl(cur_form, '#') != 'ST_TAKING2' then return; end if;
    taking_line(p_store, p_date, p_group, p_item, p_unit, p_confg, p_qty, p_basic_qty, p_unit_price, p_unit_cost, l_factor);
  end taking_det_row2;

end app_rules_st;
/
show errors package body app_rules_st

-- ---------------------------------------------------------------------------------------------------
-- Delete hooks (the Stage C rules mechanism has row rules for INSERT / UPDATE only).  APEX sessions only,
-- and inside the package only for the pages of the forms above.
-- ---------------------------------------------------------------------------------------------------
create or replace trigger app_rules_st_mast_bd
before delete on st_trns_mast for each row
begin
  if v('APP_ID') is not null then
    app_rules_st.mast_delete(:old.trns_type_code, :old.trns_serial, :old.store_code, :old.post_flag,
                             :old.trnsfer_serial, :old.trnsfer_from_store, :old.req_trns_type_code, :old.req_trns_serial);
  end if;
end;
/
show errors trigger app_rules_st_mast_bd

create or replace trigger app_rules_st_det_bd
before delete on st_trns_det for each row
begin
  if v('APP_ID') is not null then
    app_rules_st.det_delete(:old.trns_type_code, :old.trns_serial, :old.item_serial, :old.store_code,
                            :old.trns_date, :old.date_serial, :old.item_confg_id, :old.basic_qty);
  end if;
end;
/
show errors trigger app_rules_st_det_bd

-- ST_TRANSFER_REQUEST.fmx master and detail KEY-DELREC: IF :TO_TRANSFER_FLAG = 1 -> MSG('تم إستلام التحويل و لا يمكن الحذف',
-- 'The current transfer request have already received') else DELETE_RECORD (physical delete, no DELETE_FLAG).  The page
-- deletes the lines first (generated cascade process), so the line hook refuses first.
create or replace trigger app_rules_st_req_bd
before delete on st_trns_mast_request for each row
begin
  if v('APP_ID') is not null and nvl(:old.to_transfer_flag, 0) = 1 then
    raise_application_error(-20112, case when lower(nvl(v('G_LANG'), 'ar')) like 'en%'
                                         then 'The current transfer request have already received'
                                         else 'تم إستلام التحويل و لا يمكن الحذف' end);
  end if;
end;
/
show errors trigger app_rules_st_req_bd

create or replace trigger app_rules_st_reqdet_bd
before delete on st_trns_det_request for each row
declare
  l_flag number;
begin
  if v('APP_ID') is not null then
    select nvl(max(to_transfer_flag), 0) into l_flag
      from st_trns_mast_request where trns_type_code = :old.trns_type_code and trns_serial = :old.trns_serial;
    if l_flag = 1 then
      raise_application_error(-20112, case when lower(nvl(v('G_LANG'), 'ar')) like 'en%'
                                           then 'The current transfer request have already received'
                                           else 'تم إستلام التحويل و لا يمكن الحذف' end);
    end if;
  end if;
end;
/
show errors trigger app_rules_st_reqdet_bd
