-- =====================================================================================================
-- APP_RULES3_ST : business rules of the stock setup / master-data / query screens (Stage C, wave 3).
--   Code tables     ST_UNIT, ST_STORE_TYPE, ST_ITEM_CLASSES, ST_ITEM_DOSAGE_FORM, ST_BRAND, ST_PD_SERVICES,
--                   ST_ACTIVE_MATERIAL, ST_ADD_COSTS (row rules + delete hooks with the legacy messages)
--   Structures      ST_STORE_STRUCT / ST_GROUP_STRUCT (ST_CHART_STRUCTURE, CHR_TYPE 1 / 2)
--   Hierarchies     ST_STORE, ST_STORE_LOCATIONS (stores), ST_GROUP (item groups): code by chart structure,
--                   level, parent status, propagation of accounts / stop flag to the sub-levels
--   Items           ST_ITEM, ST_STANDS: item numbering, basic unit rules, uniqueness, VAT, delete restrictions
--   Types / params  ST_TRNS_TYPE_ST (copy type), ST_BASIC (system parameters)
--   Lots            ST_CHANG_CONFG_SALES_PRICE, ST_STOCK_DEF (stocktaking preparation file)
--   Query screens   ST_STORE_ITEM, ST_STORE_GRP, ST_TRNS_SLS_PU_STAT, ST_SALES_ORDER_STAT, ST_ITEM_SEARCH
--   Processes       ST_AUTO_ADJ2 (revaluation stocktaking adjustment)
--   Print prep.     BARCODE_LABELS, BARCODE_LABELS_TRNS (work table PRINT_TRNS_BARCODE read by the RDFs)
-- Evidence and decisions: app\legacy\processes\<FORM>.md.  Overrides: app\legacy\overrides\<FORM>.json.
--
-- Wiring (STAGE_C_WAVE3.md):
--   * row_rules / key_expr of the overrides call the *_row / next_* functions from the generated APPX_<TABLE>
--     triggers (APEX sessions only); rules that belong to one screen check app_rules_st.cur_form;
--   * page validations call val_*; after-save processes call *_after; info items call the *_info functions;
--   * delete hooks: the triggers at the end of this file (APEX sessions only);
--   * process pages call the procedures of the "process pages" section; their previews read the pipelined
--     functions / the helper functions below.
-- Functions called from row triggers never read the table the trigger fires on while it is mutating (ORA-04091
-- is caught where a single-row insert may read its own table).
-- No COMMIT: APEX commits the page.  Errors: raise_application_error(-20170..-20199), Arabic (English when G_LANG=en).
-- =====================================================================================================
set define off
set sqlblanklines on

-- work table of the barcode label reports ST_BARCODE_LABEL / ST_BARCODE_TRNS (the legacy forms fill it before
-- printing; it is missing in this customer database).  Created once, never dropped.
declare
  l_n number;
begin
  select count(*) into l_n from user_tables where table_name = 'PRINT_TRNS_BARCODE';
  if l_n = 0 then
    execute immediate 'create table print_trns_barcode (item_serial number, item_name varchar2(400), barcode varchar2(100), '
                   || 'item_code varchar2(40), sales_price number, user_code number)';
  end if;
end;
/

create or replace package app_rules3_st authid definer as

  -- ------------------------------------------------------------------ context
  function lang return varchar2;                                         -- 'A' / 'E'
  function to_num (p in varchar2) return number;                         -- tolerant number conversion (also in SQL)
  function pw return number;                                             -- G_PASSWORD_NUMBER, 0 = unrestricted
  function store_allowed (p_store in number) return number;              -- ST_STORE block WHERE (chart structure)
  function group_allowed (p_group in number, p_leaf in number default 1) return number;  -- ST_ITEM / ST_GROUP block WHERE
  function trns_type_allowed (p_type in number) return number;           -- ST_TRNSTYPE_PASSWORD FLAG = 1
  function can_view_cost return number;                                  -- USERS.ALLOW_VIEW_COST
  function item_group (p_item in varchar2) return number;               -- group of an item code (unique)
  function item_name (p_group in number, p_item in varchar2) return varchar2;

  -- ------------------------------------------------------------------ chart structure (1 = stores, 2 = groups)
  function chr_end (p_type in number, p_level in number) return number;
  function detect_level (p_type in number, p_code in number) return number;
  function parent_code (p_type in number, p_code in number, p_level in number) return number;
  function pad12 (p_code in number) return number;
  function code_required (p_type in number) return number;               -- key_expr: the hierarchical code is typed

  -- ------------------------------------------------------------------ code tables (row rules / key_expr)
  procedure unit_row (p_name_a in varchar2);
  procedure store_type_row (p_type in number);
  procedure class_row (p_table in varchar2, p_inserting in boolean, p_code in number, p_name_a in varchar2, p_name_e in varchar2);
  function next_brand_code return varchar2;
  function next_code (p_table in varchar2) return number;                -- ST_STORE_TYPE / ST_GOOD_KIND: max + 1
  procedure brand_row (p_inserting in boolean, p_code in varchar2, p_name_a in varchar2, p_name_e in varchar2);
  procedure add_cost_row (p_code in number, p_value in number);
  procedure code_delete (p_table in varchar2, p_code in varchar2);       -- delete hooks of the code tables

  -- ------------------------------------------------------------------ structures (ST_CHART_STRUCTURE)
  function struct_type return number;                                    -- 1 / 2 from the screen
  function next_struct_level (p_type in number) return number;
  procedure struct_row (p_inserting in boolean, p_type in number, p_level in number,
                        p_start in out number, p_end in number, p_length in out number);
  procedure struct_delete (p_type in number, p_level in number);

  -- ------------------------------------------------------------------ stores and item groups (hierarchies)
  procedure store_row (p_inserting in boolean, p_updating in boolean,
                       p_code in out number, p_level in out number, p_status in out number,
                       p_stop_flag in number, p_stop_date in out date, p_stop_reason in out varchar2,
                       p_acc1 in number, p_acc2 in number, p_acc3 in number, p_acc4 in number,
                       p_cost1 in number, p_cost2 in number,
                       p_old_acc1 in number, p_old_acc2 in number, p_old_acc3 in number, p_old_acc4 in number,
                       p_old_cost1 in number, p_old_cost2 in number, p_old_stop_flag in number);
  function val_store (p_rowid in varchar2, p_request in varchar2, p_code in varchar2) return varchar2;
  procedure store_after (p_rowid in varchar2, p_request in varchar2);
  procedure store_delete (p_code in number, p_status in number, p_level in number);
  procedure store_delete_done;
  function store_total_cost (p_store in number) return number;
  function store_cost_action (p_rowid in varchar2) return varchar2;      -- CALC_COST button: message, no document
  function add_child_store (p_rowid in varchar2, p_name_a in varchar2, p_name_e in varchar2, p_store_type in number) return varchar2;
  function last_message return varchar2;

  procedure group_row (p_inserting in boolean, p_updating in boolean,
                       p_code in out number, p_level in out number, p_status in out number,
                       p_stop_flag in number, p_stop_reason in out varchar2,
                       p_acc in number, p_cost1 in number, p_cost2 in number,
                       p_old_acc in number, p_old_cost1 in number, p_old_cost2 in number, p_old_stop_flag in number);
  function val_group (p_rowid in varchar2, p_request in varchar2, p_code in varchar2) return varchar2;
  procedure group_after (p_rowid in varchar2, p_request in varchar2);
  procedure group_delete (p_code in number, p_status in number, p_level in number);
  procedure group_delete_done;
  function group_total_cost (p_group in number) return number;
  function add_child_group (p_rowid in varchar2, p_name_a in varchar2, p_name_e in varchar2) return varchar2;
  procedure group_cov_row (p_from in number, p_to in number);

  -- ------------------------------------------------------------------ items (ST_ITEM, ST_STANDS)
  function next_item_code (p_group in number) return varchar2;
  procedure item_row (p_inserting in boolean, p_updating in boolean, p_group in number, p_item in varchar2,
                      p_stop_flag in out number, p_stop_reason in out varchar2, p_stand_flag in out number,
                      p_vat in number, p_min in number, p_max in number, p_moh_flag in number, p_moh_disc in number,
                      p_old_vat in number, p_old_min in number, p_old_max in number, p_old_moh_flag in number, p_old_moh_disc in number);
  function val_item (p_form in varchar2, p_rowid in varchar2, p_request in varchar2, p_group in varchar2, p_item in varchar2,
                     p_name_a in varchar2, p_peice in varchar2, p_lemon in varchar2, p_smc in varchar2) return varchar2;
  procedure item_after (p_form in varchar2, p_rowid in varchar2, p_request in varchar2);
  procedure item_delete (p_group in number, p_item in varchar2);
  function item_info (p_what in varchar2, p_group in varchar2, p_item in varchar2) return varchar2;
  procedure unit_item_row (p_inserting in boolean, p_updating in boolean, p_group in number, p_item in varchar2,
                           p_unit in number, p_factor in number, p_basic in number,
                           p_old_unit in number, p_old_factor in number, p_old_basic in number);
  procedure unit_item_delete (p_group in number, p_item in varchar2, p_unit in number, p_basic in number);
  procedure barcode_row (p_barcode in varchar2, p_group in number, p_item in varchar2);
  procedure sub_item_row (p_item in varchar2, p_group in number, p_sub_item in varchar2, p_sub_group in number);
  procedure item_loc_row (p_store in number, p_group in out number, p_item in varchar2, p_location in varchar2, p_serial in number);
  procedure location_delete (p_store in number, p_location in varchar2);
  procedure stand_item_row (p_inserting in boolean, p_stand_group in number, p_stand_item in varchar2,
                            p_group in number, p_item in varchar2, p_unit in number, p_qty in number);
  procedure stand_service_row (p_inserting in boolean, p_stand_group in number, p_stand_item in varchar2, p_service in number);
  function stand_cost (p_group in varchar2, p_item in varchar2) return number;

  -- ------------------------------------------------------------------ transaction types, system parameters, lots
  function val_trns_type (p_rowid in varchar2, p_request in varchar2, p_code in varchar2, p_effect in varchar2,
                          p_trns_type in varchar2, p_store in varchar2) return varchar2;
  procedure trns_type_delete (p_code in number);
  procedure staclnk_delete;
  function trns_type_last_serial (p_code in varchar2) return number;
  function copy_trns_type (p_rowid in varchar2, p_new_code in number) return varchar2;
  function val_basic (p_rowid in varchar2, p_request in varchar2, p_max_items in varchar2) return varchar2;
  function basic_warning (p_rowid in varchar2, p_what in varchar2, p_new in varchar2) return varchar2;
  procedure confg_price_row (p_disc in number, p_old_disc in number, p_price in number, p_old_price in number);
  procedure stock_def_det_row (p_inserting in boolean, p_code in varchar2, p_group in out number, p_item in out varchar2,
                               p_confg in out number, p_lot in varchar2, p_expire in date, p_sales_price in out number);

  -- ------------------------------------------------------------------ query screens (process pages with preview)
  type t_store_item is record (
    row_kind     varchar2(20),  store_code  number,        group_code   number,        item_code    varchar2(40),
    item_name    varchar2(400), unit_name   varchar2(200),  item_confg_id number,       lot_number   varchar2(100),
    expire_date  date,          supplier    varchar2(400),  balance      number,        total_cost   number,
    avg_cost     number,        sales_price number,         reorder_limit number,       min_limit    number,
    max_limit    number,        reserved_qty number,        received     number,        issued       number,
    returned     number);
  type t_store_items is table of t_store_item;
  function store_items (p_store in number, p_group in number, p_item in varchar2) return t_store_items pipelined;
  procedure show_store_items (p_store in number, p_group in number default null, p_item in varchar2 default null,
                              p_reorder in number default null, p_min in number default null, p_max in number default null);
  function store_group_cost (p_store in number, p_group in number) return number;
  procedure show_store_groups (p_store in number default null);
  procedure show_item_trns (p_item in varchar2, p_from_date in date, p_to_date in date,
                            p_from_store in number, p_to_store in number);
  function item_open_balance (p_group in number, p_item in varchar2, p_from_date in date,
                              p_from_store in number, p_to_store in number) return number;
  procedure show_docs (p_from_store in number, p_to_store in number, p_from_date in date, p_to_date in date,
                       p_trns_filter in number default null, p_next_filter in number default null,
                       p_from_code in number default null);
  function doc_total (p_tree in number, p_type in number, p_serial in number, p_what in varchar2) return number;
  procedure show_item_search (p_text in varchar2, p_criteria in number, p_search_type in number, p_group in number);
  function item_search_match (p_group in number, p_item in varchar2, p_name_a in varchar2, p_name_e in varchar2,
                              p_text in varchar2, p_criteria in number, p_search_type in number, p_filter_group in number) return number;

  -- ------------------------------------------------------------------ processes
  type t_adj2_line is record (
    group_code number, item_code varchar2(40), item_name varchar2(400), item_confg_id number, lot_number varchar2(100),
    expire_date date, unit_code number, unit_name varchar2(200), factor number, book_basic_qty number, book_qty number,
    taking_basic_qty number, taking_qty number, unit_cost number, adj_error number);
  type t_adj2_lines is table of t_adj2_line;
  function auto_adj2_lines (p_store in number, p_taking_date in date, p_serial in number) return t_adj2_lines pipelined;
  procedure auto_adjust2 (p_taking_date in date, p_store in number, p_serial in number,
                          p_issue_type in number, p_rec_type in number,
                          p_group in number default null, p_item in varchar2 default null);
  procedure prepare_barcode_labels (p_store in number, p_group in number, p_item in varchar2, p_unit in number,
                                    p_confg in number, p_count in number, p_price in number default null);
  procedure prepare_barcode_trns (p_type in number, p_serial in number, p_from_item in varchar2, p_to_item in varchar2,
                                  p_qty in number default null);
  function label_price (p_store in number, p_group in number, p_item in varchar2, p_unit in number) return number;

  -- tests: bypass of the row rules while fixtures are prepared (never used by the application)
  procedure set_bypass (p_on in boolean);
end app_rules3_st;
/
show errors package app_rules3_st

create or replace package body app_rules3_st as

  e_mutating exception;
  pragma exception_init(e_mutating, -4091);

  g_bypass     boolean := false;
  g_propagate  boolean := false;              -- store_after / group_after are updating the sub-levels
  g_msg        varchar2(4000);

  -- change set of the last store / group written by the page (row trigger -> after-save propagation)
  type t_chg is record (code number, acc1 boolean, acc2 boolean, acc3 boolean, acc4 boolean, cost boolean, stop boolean);
  g_store_chg  t_chg;
  g_group_chg  t_chg;

  -- stores / groups deleted in the current statement (compound delete triggers)
  type t_num_tab is table of number index by pls_integer;
  g_del_codes  t_num_tab;
  g_del_levels t_num_tab;

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
    return to_date(p);
  exception when others then return null;
  end to_dt;

  function cur_form return varchar2 is
  begin
    return app_rules_st.cur_form;
  end cur_form;

  procedure set_bypass (p_on in boolean) is
  begin
    g_bypass := p_on;
  end set_bypass;

  function last_message return varchar2 is
  begin
    return g_msg;
  end last_message;

  -- =================================================================================== context
  function pw return number is
  begin
    return nvl(to_num(v('G_PASSWORD_NUMBER')), 0);
  end pw;

  -- legacy ST_STORE block WHERE: (:GLOBAL.PASSWORD_NUMBER=0 OR STORE_CODE IN (SELECT .. ST_STORE_PASSWORD SP ..
  -- CHRT.CHR_STRU_LEVEL = level of SP.STORE_CODE AND SP.FLAG=1 AND CHR_TYPE=1 AND SUBSTR(SP.STORE_CODE,1,CHR_STRU_END)
  -- = SUBSTR(ST.STORE_CODE,1,CHR_STRU_END)))
  function store_allowed (p_store in number) return number is
    l_g number := pw;
    l_n number;
  begin
    if l_g = 0 then return 1; end if;
    select count(*) into l_n
      from st_store_password sp, st_store st2, st_chart_structure c
     where sp.password_number = l_g and sp.flag = 1
       and st2.store_code = sp.store_code
       and c.chr_type = 1 and c.chr_stru_level = st2.store_level
       and substr(to_char(sp.store_code), 1, c.chr_stru_end) = substr(to_char(p_store), 1, c.chr_stru_end);
    return case when l_n > 0 then 1 else 0 end;
  end store_allowed;

  -- legacy ST_ITEM block WHERE (same shape on ST_GROUP_PASSWORD / CHR_TYPE 2, GROUP_STATUS = 1); the ST_GROUP block
  -- WHERE has no GROUP_STATUS condition (p_leaf = 0)
  function group_allowed (p_group in number, p_leaf in number default 1) return number is
    l_g number := pw;
    l_n number;
  begin
    if l_g = 0 then return 1; end if;
    select count(*) into l_n
      from st_group_password gp, st_item_group ig2, st_chart_structure c, st_item_group ig
     where gp.password_number = l_g and gp.flag = 1
       and ig2.item_group_code = gp.group_code
       and c.chr_type = 2 and c.chr_stru_level = ig2.group_level
       and ig.item_group_code = p_group and (p_leaf = 0 or ig.group_status = 1)
       and substr(to_char(gp.group_code), 1, c.chr_stru_end) = substr(to_char(ig.item_group_code), 1, c.chr_stru_end);
    return case when l_n > 0 then 1 else 0 end;
  end group_allowed;

  function trns_type_allowed (p_type in number) return number is
    l_g number := pw;
    l_n number;
  begin
    if l_g = 0 then return 1; end if;
    select count(*) into l_n from st_trnstype_password tp
     where tp.password_number = l_g and tp.trns_type_code = p_type and tp.flag = 1;
    return case when l_n > 0 then 1 else 0 end;
  end trns_type_allowed;

  function can_view_cost return number is
    l_n number;
  begin
    if v('APP_ID') is null then return 1; end if;
    select nvl(max(allow_view_cost), 0) into l_n from users where users_code = to_num(v('G_USER_CODE'));
    return l_n;
  end can_view_cost;

  function item_group (p_item in varchar2) return number is
    l_g number;
  begin
    select max(item_group_code) into l_g from st_item where item_code = p_item;
    return l_g;
  end item_group;

  function item_name (p_group in number, p_item in varchar2) return varchar2 is
    l_a st_item.name_a%type;
    l_e st_item.name_e%type;
  begin
    select max(name_a), max(name_e) into l_a, l_e from st_item where item_group_code = p_group and item_code = p_item;
    return case when lang = 'E' then nvl(l_e, l_a) else nvl(l_a, l_e) end;
  end item_name;

  -- =================================================================================== chart structure
  function chr_end (p_type in number, p_level in number) return number is
    l_end number;
  begin
    select chr_stru_end into l_end from st_chart_structure where chr_type = p_type and chr_stru_level = p_level;
    return l_end;
  exception when no_data_found then
    if p_type = 1 then
      err(-20170, 'لابد من إدخال هيكل المخازن أولا', 'Store Structure Must Be Entered');
    else
      err(-20170, 'لابد من إدخال هيكل مجموعــات الأصنـــاف أولا', 'Item Group Structure Must Be Entered');
    end if;
  end chr_end;

  function pad12 (p_code in number) return number is
  begin
    if p_code is null then return null; end if;
    return to_number(rpad(to_char(p_code), 12, '0'));
  end pad12;

  -- legacy DETECT_STORE_LEVEL (ST_STORE.fmb) / the group variant of ST_GROUP.fmx
  function detect_level (p_type in number, p_code in number) return number is
    l_levels number;
    l_level  number := 0;
    l_cur    number;
    l_next   number;
    l_code   varchar2(40) := to_char(p_code);
  begin
    select count(*) into l_levels from st_chart_structure where chr_type = p_type;
    if l_levels = 0 then
      if p_type = 1 then
        err(-20170, 'لابد من إدخال هيكل المخازن أولا', 'Store Structure Must Be Entered');
      else
        err(-20170, 'لابد من إدخال هيكل مجموعـات الأصنــاف أولا', 'Item Group Structure Must Be Entered');
      end if;
    end if;
    for r in (select chr_stru_level lvl, chr_stru_start st, length len from st_chart_structure
               where chr_type = p_type order by chr_stru_level) loop
      l_cur := to_number(nvl(substr(l_code, r.st, r.len), '0'));
      if l_cur = 0 then
        l_level := r.lvl - 1;
        if r.lvl < l_levels then
          l_next := to_number(nvl(substr(l_code, r.st + r.len), '0'));
          if l_next > 0 then
            if p_type = 1 then
              err(-20171, 'خطأ فى رقم المخزن', 'Illegal Stock Code');
            else
              err(-20171, 'خطأ فى رقم مجموعة الأصنـــاف', 'Illegal Item Group Code');
            end if;
          end if;
        end if;
        exit;
      else
        l_level := r.lvl;
      end if;
    end loop;
    return l_level;
  end detect_level;

  -- legacy GET_STORE_PARENT: RPAD(SUBSTR(code, 1, end_pos(level - 1)), 12, '0')
  function parent_code (p_type in number, p_code in number, p_level in number) return number is
  begin
    if nvl(p_level, 0) <= 1 then return null; end if;
    return pad12(to_number(substr(to_char(p_code), 1, chr_end(p_type, p_level - 1))));
  end parent_code;

  function code_required (p_type in number) return number is
  begin
    if p_type = 1 then
      err(-20172, 'يجب إدخال رقم المخزن', 'Enter the store code');
    else
      err(-20172, 'يجب إدخال رقم المجموعة', 'Enter the group code');
    end if;
    return null;
  end code_required;

  -- =================================================================================== code tables
  -- ST_UNIT .fmx: 'يجب إدخال الإسم'
  procedure unit_row (p_name_a in varchar2) is
  begin
    if g_bypass then return; end if;
    if p_name_a is null then
      err(-20173, 'يجب إدخال الإسم', 'Enter the name');
    end if;
  end unit_row;

  -- ST_STORE_TYPE .fmx: 'رقم نوع المخزن يجب ان يكون فى المدي من 1 و 999999'
  procedure store_type_row (p_type in number) is
  begin
    if g_bypass then return; end if;
    if p_type is not null and (p_type < 1 or p_type > 999999) then
      err(-20173, 'رقم نوع المخزن يجب ان يكون فى المدي من 1 و 999999', 'The store type number must be between 1 and 999999');
    end if;
  end store_type_row;

  -- ST_ITEM_CLASSES / ST_ITEM_DOSAGE_FORM / ST_ACTIVE_MATERIAL .fmx: code > 0, Arabic or English name, duplicate code
  procedure class_row (p_table in varchar2, p_inserting in boolean, p_code in number, p_name_a in varchar2, p_name_e in varchar2) is
    l_n number;
  begin
    if g_bypass then return; end if;
    if p_code is not null and p_code <= 0 then
      err(-20173, 'قم بادخال رقم اكبر من الصفر', 'Enter a number greater than zero');
    end if;
    if p_name_a is null and p_name_e is null then
      err(-20173, 'يجب ادخال الأسم عربى أو لاتينى', 'Enter the Arabic or the English name');
    end if;
    if p_inserting and p_code is not null then
      begin
        if p_table = 'ST_ITEM_CLASSES' then
          select count(*) into l_n from st_item_classes where class_code = p_code;
        elsif p_table = 'ST_ITEM_DOSAGE_FORM' then
          select count(*) into l_n from st_item_dosage_form where dosage_form_code = p_code;
        else
          select count(*) into l_n from st_active_material where serial = p_code;
        end if;
      exception when e_mutating then l_n := 0;
      end;
      if l_n > 0 then
        if p_table = 'ST_ACTIVE_MATERIAL' then
          err(-20173, 'هذا الكود موجود من قبل', 'This code already exists');
        else
          err(-20173, 'هذا السجل تم ادخاله من قبل ... رقم مكرر', 'This record was entered before ... duplicate number');
        end if;
      end if;
    end if;
  end class_row;

  -- ST_BRAND .fmx: SELECT NVL(MAX(BRAND_CODE),0)+1 FROM ST_BRAND (BRAND_CODE is VARCHAR2)
  function next_brand_code return varchar2 is
    l_n number;
  begin
    select nvl(max(to_number(brand_code default null on conversion error)), 0) + 1 into l_n from st_brand;
    return to_char(l_n);
  exception when e_mutating then return null;
  end next_brand_code;

  -- 'SELECT NVL(MAX(KIND_CODE),0)+1 FROM ST_GOOD_KIND' (st_good_kind.fmx) and the same for the store types (st_store_type.fmx)
  function next_code (p_table in varchar2) return number is
    l_n number;
  begin
    if p_table = 'ST_STORE_TYPE' then
      select nvl(max(store_type), 0) + 1 into l_n from st_store_type;
    elsif p_table = 'ST_GOOD_KIND' then
      select nvl(max(kind_code), 0) + 1 into l_n from st_good_kind;
    end if;
    return l_n;
  exception when e_mutating then return null;
  end next_code;

  procedure brand_row (p_inserting in boolean, p_code in varchar2, p_name_a in varchar2, p_name_e in varchar2) is
    l_n number;
  begin
    if g_bypass then return; end if;
    if p_name_a is null and p_name_e is null then
      err(-20173, 'يجب ادخال الأسم عربى أو لاتينى', 'Enter the Arabic or the English name');
    end if;
    if p_inserting then
      begin
        select count(1) into l_n from st_brand where brand_code = p_code;
      exception when e_mutating then l_n := 0;
      end;
      if l_n > 0 then
        err(-20173, 'كود مكرر من قبل', 'Duplicate code');
      end if;
    end if;
  end brand_row;

  -- ST_ADD_COSTS .fmx
  procedure add_cost_row (p_code in number, p_value in number) is
  begin
    if g_bypass then return; end if;
    if p_code is not null and p_code <= 0 then
      err(-20173, 'أدخل قيمة صحيحة لرقم التكلفة الإضافية - أكبر من الصفر', 'Enter a valid additional cost number (greater than zero)');
    end if;
    if nvl(p_value, 0) <= 0 then
      err(-20173, 'أدخل قيمة صحيحة للتكلفة الإضافية - أكبر من الصفر', 'Enter a valid additional cost value (greater than zero)');
    end if;
  end add_cost_row;

  -- delete checks of the code tables (legacy KEY-DELREC counts)
  procedure code_delete (p_table in varchar2, p_code in varchar2) is
    l_n number := 0;
    l_m number := 0;
  begin
    if g_bypass then return; end if;
    if p_table = 'ST_UNIT' then
      select count(unit_code) into l_n from st_item_unit where unit_code = to_num(p_code);
      if l_n > 0 then
        err(-20174, 'تم تخصيص هذه الوحدة مع صنف أو أكثر - لا يمكن حذفها حالياً.', 'This unit is assigned to one or more items - it cannot be deleted.');
      end if;
    elsif p_table = 'ST_STORE_TYPE' then
      select count(store_type) into l_n from st_store where store_type = to_num(p_code);
      if l_n > 0 then
        err(-20174, 'تم تخصيص هذا النوع مع مخزن أو أكثر - لا يمكن حذفه حالياً.', 'This type is assigned to one or more stores - it cannot be deleted.');
      end if;
    elsif p_table = 'ST_BRAND' then
      select count(brand_code) into l_n from st_item where to_char(brand_code) = p_code;
      if l_n > 0 then
        err(-20174, 'تم استخدام هذه الماركة فى النظام - لا يمكن حذفه حالياً.', 'This brand is used - it cannot be deleted.');
      end if;
    elsif p_table = 'ST_PD_SERVICES' then
      select count(1) into l_n from st_pd_det_srvc where service_code = to_num(p_code);
      select count(1) into l_m from st_stand_services where service_code = to_num(p_code);
      l_n := l_n + l_m;
      select count(1) into l_m from st_trns_services where service_code = to_num(p_code);
      l_n := l_n + l_m;
      if l_n > 0 then
        err(-20174, 'تم تخصيص هذه الخدمة مع صنف أو أكثر - لا يمكن حذفها حالياً.', 'This service is used by one or more items - it cannot be deleted.');
      end if;
    elsif p_table = 'ST_ACTIVE_MATERIAL' then
      select count(1) into l_n from st_item where active_material_code = to_num(p_code);
      if l_n > 0 then
        err(-20174, 'تم تخصيص هذه المادة الفعالة مع صنف أو أكثر - لا يمكن حذفها حالياً.', 'This active material is assigned to one or more items - it cannot be deleted.');
      end if;
    end if;
  end code_delete;

  -- =================================================================================== structures
  function struct_type return number is
  begin
    return case cur_form when 'ST_STORE_STRUCT' then 1 when 'ST_GROUP_STRUCT' then 2 end;
  end struct_type;

  -- legacy: SELECT MAX(CHR_STRU_LEVEL) FROM ST_CHART_STRUCTURE WHERE CHR_TYPE = :type
  function next_struct_level (p_type in number) return number is
    l_n number;
  begin
    select nvl(max(chr_stru_level), 0) + 1 into l_n from st_chart_structure where chr_type = p_type;
    return l_n;
  exception when e_mutating then return null;
  end next_struct_level;

  -- start field = end of the previous level + 1, end must be >= start and <= 12, length = end - start + 1
  procedure struct_row (p_inserting in boolean, p_type in number, p_level in number,
                        p_start in out number, p_end in number, p_length in out number) is
  begin
    if g_bypass then return; end if;
    if p_type is null then
      err(-20175, 'نوع الهيكل غير معروف', 'Unknown structure type');
    end if;
    if p_inserting and p_start is null then
      begin
        select nvl(max(chr_stru_end), 0) + 1 into p_start from st_chart_structure
         where chr_type = p_type and chr_stru_level < p_level;
      exception when e_mutating then null;
      end;
    end if;
    if p_start is null then
      err(-20175, 'إدخل حقل البداية', 'Enter the start field');
    end if;
    if p_end is null or p_end < p_start or p_end > 12 then
      err(-20175, 'برجاء التأكد من إدخال --حقل النهاية-- و كونه أكبر من حقل البداية و كذلك كونه أقل من 12',
                  'Enter the end field: it must not be less than the start field and not greater than 12');
    end if;
    p_length := p_end - p_start + 1;
  end struct_row;

  -- delete: no level while stores / groups exist, and from the last level upwards; ST_LOCKUPS of a group level
  procedure struct_delete (p_type in number, p_level in number) is
    l_n   number;
    l_max number;
    function max_level_committed return number is
      pragma autonomous_transaction;              -- ST_CHART_STRUCTURE is mutating in its own delete trigger
      l number;
    begin
      select max(chr_stru_level) into l from st_chart_structure where chr_type = p_type;
      commit;
      return l;
    end max_level_committed;
    function max_level return number is
      l number;
    begin
      select max(chr_stru_level) into l from st_chart_structure where chr_type = p_type;
      return l;
    exception when e_mutating then
      return max_level_committed;
    end max_level;
  begin
    if g_bypass then return; end if;
    if p_type = 1 then
      select count(*) into l_n from st_store;
      if l_n > 0 then
        err(-20176, 'لا يمكن حذف المستويات حيث أنه توجد مخازن معرفة بناء على هذه المستويات',
                    'Levels cannot be deleted: stores are defined on this structure');
      end if;
    elsif p_type = 2 then
      select count(*) into l_n from st_item_group;
      if l_n > 0 then
        err(-20176, 'لا يمكن حذف المستويات حيث أنه توجد ممجموعات أصناف معرفة بناء على هذه المستويات',
                    'Levels cannot be deleted: item groups are defined on this structure');
      end if;
    end if;
    l_max := max_level;
    if p_level < nvl(l_max, p_level) then
      err(-20176, 'يجب حذف السجلات من أسفل إلي أعلي', 'Delete the levels from the last one upwards');
    end if;
    if p_type = 2 then
      delete from st_lockups s where s.tab_parent = p_level;
    end if;
  end struct_delete;

  -- =================================================================================== stores
  function transactions_found (p_store in number) return boolean is
    l_n number;
  begin
    select count(1) into l_n from st_trns_mast where store_code = p_store;
    return l_n > 0;
  end transactions_found;

  procedure store_row (p_inserting in boolean, p_updating in boolean,
                       p_code in out number, p_level in out number, p_status in out number,
                       p_stop_flag in number, p_stop_date in out date, p_stop_reason in out varchar2,
                       p_acc1 in number, p_acc2 in number, p_acc3 in number, p_acc4 in number,
                       p_cost1 in number, p_cost2 in number,
                       p_old_acc1 in number, p_old_acc2 in number, p_old_acc3 in number, p_old_acc4 in number,
                       p_old_cost1 in number, p_old_cost2 in number, p_old_stop_flag in number) is
    function chg (a number, b number) return boolean is
    begin
      return (a is null and b is not null) or (a is not null and b is null) or a <> b;
    end;
  begin
    if g_bypass or g_propagate then return; end if;
    if p_inserting then
      -- STORE_CODE WHEN-VALIDATE-ITEM: 12 digits, level from the store structure, new stores are leaves
      p_code   := pad12(p_code);
      p_level  := detect_level(1, p_code);
      p_status := 1;
    end if;
    -- PRE-INSERT / PRE-UPDATE: STOP_DATE := SYSDATE when stopped, else NULL; STOP_FLAG unchecked -> no reason
    if nvl(p_stop_flag, 0) = 1 then
      p_stop_date := sysdate;
    else
      p_stop_date := null;
      p_stop_reason := null;
    end if;
    if p_updating then
      g_store_chg := null;
      g_store_chg.code := p_code;
      g_store_chg.acc1 := chg(p_old_acc1, p_acc1);
      g_store_chg.acc2 := chg(p_old_acc2, p_acc2);
      g_store_chg.acc3 := chg(p_old_acc3, p_acc3);
      g_store_chg.acc4 := chg(p_old_acc4, p_acc4);
      g_store_chg.cost := chg(p_old_cost1, p_cost1) or chg(p_old_cost2, p_cost2);   -- COST_CODE2 POST-CHANGE copies COST_CODE
      g_store_chg.stop := chg(nvl(p_old_stop_flag, 0), nvl(p_stop_flag, 0));
    end if;
  end store_row;

  -- STORE_CODE WHEN-VALIDATE-ITEM / PRE-INSERT (page validation, before the DML)
  function val_store (p_rowid in varchar2, p_request in varchar2, p_code in varchar2) return varchar2 is
    l_code   number := pad12(to_num(p_code));
    l_old    number;
    l_level  number;
    l_parent number;
    l_n      number;
  begin
    if p_request not in ('CREATE', 'SAVE') or l_code is null then return null; end if;
    if p_rowid is not null then
      select store_code into l_old from st_store where rowid = chartorowid(p_rowid);
      if l_old = l_code then return null; end if;
    end if;
    l_level := detect_level(1, l_code);
    if l_level > 1 then
      l_parent := parent_code(1, l_code, l_level);
      select count(1) into l_n from st_store where store_code = l_parent;
      if l_n = 0 then
        return msg('لا يوجد مخزن رئيسى لهذا الرقم', 'Parent Store Not Found');
      end if;
      if transactions_found(l_parent) then
        return msg('تم عمل حركات على المخزن الرئيسى', 'Transaction Found On Parent Store');
      end if;
    end if;
    select count(1) into l_n from st_store where store_code = l_code;
    if l_n > 0 then
      return msg('يوجد مخزن بنفس الرقم بالملف', 'Store already Exist');
    end if;
    return null;
  exception when others then
    if sqlcode between -20199 and -20100 then
      return regexp_replace(sqlerrm, '^ORA-[0-9]+: ', '');
    end if;
    raise;
  end val_store;

  -- POST-INSERT (parent becomes a classification store) and the POST-CHANGE propagation to the sub-stores
  procedure store_after (p_rowid in varchar2, p_request in varchar2) is
    r      st_store%rowtype;
    l_end  number;
    l_pref varchar2(20);
    l_form varchar2(128) := cur_form;
    l_sfx  varchar2(200);
  begin
    if p_rowid is null then return; end if;
    select * into r from st_store where rowid = chartorowid(p_rowid);
    l_sfx := msg('(المخزن الرئيسى ', '(Parent Store ') || r.store_code || ')';
    g_propagate := true;
    if p_request = 'CREATE' and nvl(r.store_level, 0) > 1 then
      update st_store set store_status = 0 where store_code = parent_code(1, r.store_code, r.store_level);
    end if;
    if p_request = 'SAVE' and g_store_chg.code = r.store_code then
      l_end  := chr_end(1, r.store_level);
      l_pref := substr(to_char(r.store_code), 1, l_end);
      -- ST_STORE.fmb POST-CHANGE of ACCOUNT_NUMBER1..4 / COST_CODE / COST_CODE2 (the latter copies COST_CODE);
      -- st_store_locations.fmx has no ACCOUNT_NUMBER1 propagation
      if g_store_chg.acc1 and l_form = 'ST_STORE' then
        update st_store set account_number1 = r.account_number1 where substr(to_char(store_code), 1, l_end) = l_pref and rowid <> chartorowid(p_rowid);
      end if;
      if g_store_chg.acc2 then
        update st_store set account_number2 = r.account_number2 where substr(to_char(store_code), 1, l_end) = l_pref and rowid <> chartorowid(p_rowid);
      end if;
      if g_store_chg.acc3 then
        update st_store set account_number3 = r.account_number3 where substr(to_char(store_code), 1, l_end) = l_pref and rowid <> chartorowid(p_rowid);
      end if;
      if g_store_chg.acc4 then
        update st_store set account_number4 = r.account_number4 where substr(to_char(store_code), 1, l_end) = l_pref and rowid <> chartorowid(p_rowid);
      end if;
      if g_store_chg.cost then
        update st_store set cost_code = r.cost_code where substr(to_char(store_code), 1, l_end) = l_pref and rowid <> chartorowid(p_rowid);
      end if;
      if g_store_chg.stop then
        if nvl(r.stop_flag, 0) = 1 then
          update st_store
             set stop_flag = 1,
                 stop_date = case when l_form = 'ST_STORE_LOCATIONS' then sysdate else stop_date end,
                 stop_reason = r.stop_reason || l_sfx
           where substr(to_char(store_code), 1, l_end) = l_pref and rowid <> chartorowid(p_rowid);
        else
          update st_store set stop_flag = 0, stop_date = null, stop_reason = null
           where substr(to_char(store_code), 1, l_end) = l_pref and rowid <> chartorowid(p_rowid);
        end if;
      end if;
    end if;
    g_propagate := false;
    g_store_chg := null;
  exception when others then
    g_propagate := false;
    raise;
  end store_after;

  -- KEY-DELREC of ST_STORE.fmb (before each deleted row)
  procedure store_delete (p_code in number, p_status in number, p_level in number) is
    l_n number;
  begin
    if g_bypass then return; end if;
    select count(*) into l_n from st_store_item where store_code = p_code and rownum = 1;
    if l_n > 0 then
      err(-20177, 'لايمكنك حذف هذا السجل حيث أنه تم إجراء حركات عليه', 'Store has a transactions You can''t delete it');
    end if;
    if nvl(p_status, 1) = 0 then
      err(-20177, 'يوجد مخازن فرعية لهذا المخزن لذلك لايمكنك الحذف', 'There exist child stores for this Store');
    end if;
    l_n := g_del_codes.count + 1;
    g_del_codes(l_n) := p_code;
    g_del_levels(l_n) := p_level;
  end store_delete;

  -- POST-DELETE: the parent becomes a leaf again when it has no other sub-store (after the statement)
  procedure store_delete_done is
    l_parent number;
    l_end    number;
    l_n      number;
  begin
    g_propagate := true;
    for i in 1 .. g_del_codes.count loop
      if nvl(g_del_levels(i), 0) > 1 then
        l_parent := parent_code(1, g_del_codes(i), g_del_levels(i));
        l_end := chr_end(1, g_del_levels(i) - 1);
        select count(*) into l_n from st_store
         where store_code <> l_parent and substr(to_char(store_code), 1, l_end) = substr(to_char(l_parent), 1, l_end);
        if l_n = 0 then
          update st_store set store_status = 1 where store_code = l_parent;
        end if;
      end if;
    end loop;
    g_propagate := false;
    g_del_codes.delete;
    g_del_levels.delete;
  exception when others then
    g_propagate := false;
    g_del_codes.delete;
    g_del_levels.delete;
    raise;
  end store_delete_done;

  -- CALC_COST (GET_SUM_BAL_COST of ST_STORE.fmb): cost of all items of a transaction store
  function store_total_cost (p_store in number) return number is
    l_bal  number;
    l_cost number;
    l_unit number;
    l_tot  number := 0;
    l_status number;
  begin
    select max(store_status) into l_status from st_store where store_code = p_store;
    if nvl(l_status, 0) <> 1 then return 0; end if;
    for r in (select group_code, item_code from st_store_item where store_code = p_store) loop
      get_balance_cost(l_bal, l_cost, l_unit, p_store, r.group_code, r.item_code);
      if l_bal is not null and l_cost is not null then
        l_tot := l_tot + l_cost;
      end if;
    end loop;
    return l_tot;
  end store_total_cost;

  function store_cost_action (p_rowid in varchar2) return varchar2 is
    l_store number;
  begin
    select store_code into l_store from st_store where rowid = chartorowid(p_rowid);
    g_msg := msg('التكلفة الكلية للمخزن: ', 'Total cost of the store: ') || to_char(store_total_cost(l_store), 'FM999G999G999G990D00');
    return null;
  end store_cost_action;

  -- ADD_SON of ST_STORE.fmb: the next sub-store code under the current store (GET_NEXT_ACCOUNT), created with the
  -- names and type given on the page (the legacy button opened a new record with that code)
  function add_child_store (p_rowid in varchar2, p_name_a in varchar2, p_name_e in varchar2, p_store_type in number) return varchar2 is
    r        st_store%rowtype;
    l_levels number;
    l_end_c  number;
    l_end_p  number;
    l_child  number;
    l_rowid  rowid;
  begin
    if p_rowid is null then
      err(-20178, ' لا يمكن تكوين مخازن أبن بلا مخزن أب ', 'You cant add children store without a parent store');
    end if;
    select * into r from st_store where rowid = chartorowid(p_rowid);
    if transactions_found(r.store_code) then
      err(-20178, 'لا يمكن إضافة مخازن فرعية بينما هناك حركات مسجلة', 'You can''t add more level while transaction exist');
    end if;
    select count(*) into l_levels from st_chart_structure where chr_type = 1;
    if r.store_level >= l_levels then
      err(-20178, 'خطأ فى رقم المخزن', 'Illegal Stock Code');
    end if;
    l_end_c := chr_end(1, r.store_level + 1);
    l_end_p := chr_end(1, r.store_level);
    select to_number(rpad(to_char(to_number(substr(to_char(max(store_code)), 1, l_end_c)) + 1), 12, '0'))
      into l_child
      from st_store
     where rpad(to_char(to_number(substr(to_char(store_code), 1, l_end_p))), 12, '0')
         = rpad(to_char(to_number(substr(to_char(r.store_code), 1, l_end_p))), 12, '0')
       and nvl(to_number(substr(to_char(store_code), case when l_end_c = 12 then l_end_c else l_end_c + 1 end, 12)), 0) = 0;
    if l_child is null or detect_level(1, l_child) <> r.store_level + 1 then
      err(-20178, 'خطأ فى رقم المخزن', 'Illegal Stock Code');
    end if;
    insert into st_store (store_code, name_a, name_e, store_type, store_level, store_status, stop_flag, deal_type)
    values (l_child, p_name_a, p_name_e, nvl(p_store_type, r.store_type), r.store_level + 1, 1, 0, r.deal_type)
    returning rowid into l_rowid;
    g_propagate := true;
    update st_store set store_status = 0 where store_code = r.store_code;
    g_propagate := false;
    g_msg := msg('تم إضافة المخزن الفرعي رقم ', 'Sub-store created: ') || l_child;
    return rowidtochar(l_rowid);
  end add_child_store;

  -- =================================================================================== item groups
  procedure group_row (p_inserting in boolean, p_updating in boolean,
                       p_code in out number, p_level in out number, p_status in out number,
                       p_stop_flag in number, p_stop_reason in out varchar2,
                       p_acc in number, p_cost1 in number, p_cost2 in number,
                       p_old_acc in number, p_old_cost1 in number, p_old_cost2 in number, p_old_stop_flag in number) is
    function chg (a number, b number) return boolean is
    begin
      return (a is null and b is not null) or (a is not null and b is null) or a <> b;
    end;
  begin
    if g_bypass or g_propagate then return; end if;
    if p_inserting then
      p_code   := pad12(p_code);
      p_level  := detect_level(2, p_code);
      p_status := 1;
    end if;
    if nvl(p_stop_flag, 0) = 0 then
      p_stop_reason := null;
    end if;
    if p_updating then
      g_group_chg := null;
      g_group_chg.code := p_code;
      g_group_chg.acc1 := chg(p_old_acc, p_acc);
      g_group_chg.cost := chg(p_old_cost1, p_cost1) or chg(p_old_cost2, p_cost2);
      g_group_chg.stop := chg(nvl(p_old_stop_flag, 0), nvl(p_stop_flag, 0));
    end if;
  end group_row;

  function val_group (p_rowid in varchar2, p_request in varchar2, p_code in varchar2) return varchar2 is
    l_code   number := pad12(to_num(p_code));
    l_old    number;
    l_level  number;
    l_parent number;
    l_n      number;
  begin
    if p_request not in ('CREATE', 'SAVE') or l_code is null then return null; end if;
    if p_rowid is not null then
      select item_group_code into l_old from st_item_group where rowid = chartorowid(p_rowid);
      if l_old = l_code then return null; end if;
    end if;
    l_level := detect_level(2, l_code);
    if l_level > 1 then
      l_parent := parent_code(2, l_code, l_level);
      select count(1) into l_n from st_item_group where item_group_code = l_parent;
      if l_n = 0 then
        return msg('لا يوجد مجموعة أصنــاف رئيسية لهذا الرقم', 'Parent group not found');
      end if;
      select count(1) into l_n from st_item where item_group_code = l_parent;
      if l_n > 0 then
        return msg('تم عمل حركات على المجموعة الرئيسية', 'Items exist on the parent group');
      end if;
    end if;
    select count(1) into l_n from st_item_group where item_group_code = l_code;
    if l_n > 0 then
      return msg('يوجد مجموعة أصنـــاف بنفس الرقم بالملف', 'Item group already exists');
    end if;
    return null;
  exception when others then
    if sqlcode between -20199 and -20100 then
      return regexp_replace(sqlerrm, '^ORA-[0-9]+: ', '');
    end if;
    raise;
  end val_group;

  procedure group_after (p_rowid in varchar2, p_request in varchar2) is
    r      st_item_group%rowtype;
    l_end  number;
    l_pref varchar2(20);
    l_sfx  varchar2(200);
  begin
    if p_rowid is null then return; end if;
    select * into r from st_item_group where rowid = chartorowid(p_rowid);
    l_sfx := msg('(المجموعة الرئيسية ', '(Parent Group ') || r.item_group_code || ')';
    g_propagate := true;
    if p_request = 'CREATE' and nvl(r.group_level, 0) > 1 then
      update st_item_group set group_status = 0 where item_group_code = parent_code(2, r.item_group_code, r.group_level);
    end if;
    if p_request = 'SAVE' and g_group_chg.code = r.item_group_code then
      l_end  := chr_end(2, r.group_level);
      l_pref := substr(to_char(r.item_group_code), 1, l_end);
      if g_group_chg.acc1 then
        update st_item_group set account_number = r.account_number
         where substr(to_char(item_group_code), 1, l_end) = l_pref and rowid <> chartorowid(p_rowid);
      end if;
      if g_group_chg.cost then        -- both POST-CHANGE triggers (COST_CODE / COST_CODE2) update COST_CODE
        update st_item_group set cost_code = r.cost_code
         where substr(to_char(item_group_code), 1, l_end) = l_pref and rowid <> chartorowid(p_rowid);
      end if;
      if g_group_chg.stop then
        if nvl(r.stop_flag, 0) = 1 then
          update st_item_group
             set stop_flag = 1,
                 stop_reason = r.stop_reason || l_sfx
           where substr(to_char(item_group_code), 1, l_end) = l_pref and rowid <> chartorowid(p_rowid);
        else
          update st_item_group set stop_flag = 0, stop_date = null, stop_reason = null
           where substr(to_char(item_group_code), 1, l_end) = l_pref and rowid <> chartorowid(p_rowid);
        end if;
        -- UPDATE ST_ITEM SET STOP_FLAG = :b1, STOP_REASON = :b2 WHERE ITEM_GROUP_CODE = :b3
        update st_item set stop_flag = nvl(r.stop_flag, 0), stop_reason = r.stop_reason where item_group_code = r.item_group_code;
      end if;
    end if;
    g_propagate := false;
    g_group_chg := null;
  exception when others then
    g_propagate := false;
    raise;
  end group_after;

  procedure group_delete (p_code in number, p_status in number, p_level in number) is
    l_n number;
  begin
    if g_bypass then return; end if;
    select count(*) into l_n from st_item where item_group_code = p_code and rownum = 1;
    if l_n > 0 then
      err(-20177, 'لايمكنك حذف هذا السجل حيث أنه تم إجراء حركات عليه', 'Items exist in this group - it cannot be deleted');
    end if;
    if nvl(p_status, 1) = 0 then
      err(-20177, 'يوجد مجموعات فرعية لهذه المجموعة لذلك لايمكنك الحذف', 'Sub-groups exist for this group - it cannot be deleted');
    end if;
    l_n := g_del_codes.count + 1;
    g_del_codes(l_n) := p_code;
    g_del_levels(l_n) := p_level;
  end group_delete;

  procedure group_delete_done is
    l_parent number;
    l_end    number;
    l_n      number;
  begin
    g_propagate := true;
    for i in 1 .. g_del_codes.count loop
      if nvl(g_del_levels(i), 0) > 1 then
        l_parent := parent_code(2, g_del_codes(i), g_del_levels(i));
        l_end := chr_end(2, g_del_levels(i) - 1);
        select count(*) into l_n from st_item_group
         where item_group_code <> l_parent
           and substr(to_char(item_group_code), 1, l_end) = substr(to_char(l_parent), 1, l_end);
        if l_n = 0 then
          update st_item_group set group_status = 1 where item_group_code = l_parent;
        end if;
      end if;
    end loop;
    g_propagate := false;
    g_del_codes.delete;
    g_del_levels.delete;
  exception when others then
    g_propagate := false;
    g_del_codes.delete;
    g_del_levels.delete;
    raise;
  end group_delete_done;

  -- CALC_COST of ST_GROUP.fmx: SELECT STORE_CODE, ITEM_CODE FROM ST_STORE_ITEM WHERE GROUP_CODE = :b1
  function group_total_cost (p_group in number) return number is
    l_bal  number;
    l_cost number;
    l_unit number;
    l_tot  number := 0;
  begin
    for r in (select store_code, item_code from st_store_item where group_code = p_group) loop
      get_balance_cost(l_bal, l_cost, l_unit, r.store_code, p_group, r.item_code);
      l_tot := l_tot + nvl(l_cost, 0);
    end loop;
    return l_tot;
  end group_total_cost;

  -- "إضافة مجموعة فرعية" (ST_GROUP.fmx): RPAD(SUBSTR(MAX(ITEM_GROUP_CODE),1,end_child)+1,12,0) under the parent
  function add_child_group (p_rowid in varchar2, p_name_a in varchar2, p_name_e in varchar2) return varchar2 is
    r        st_item_group%rowtype;
    l_levels number;
    l_end_c  number;
    l_end_p  number;
    l_child  number;
    l_n      number;
    l_rowid  rowid;
    l_exp    number;
    l_col    number;
    l_size   number;
  begin
    if p_rowid is null then
      err(-20178, 'لا يمكن تكوين مجموعة أبن بلا مجموعة أب', 'You cannot add a sub-group without a parent group');
    end if;
    select * into r from st_item_group where rowid = chartorowid(p_rowid);
    select count(1) into l_n from st_item where item_group_code = r.item_group_code;
    if l_n > 0 then
      err(-20178, 'لا يمكن إضافة مجموعة فرعية بينما هناك أصناف مرتبطة بالمجموعة', 'You cannot add a sub-group while items are linked to the group');
    end if;
    select count(*) into l_levels from st_chart_structure where chr_type = 2;
    if r.group_level >= l_levels then
      err(-20178, 'خطأ فى رقم مجموعة الأصنـــاف', 'Illegal Item Group Code');
    end if;
    l_end_c := chr_end(2, r.group_level + 1);
    l_end_p := chr_end(2, r.group_level);
    select to_number(rpad(to_char(to_number(substr(to_char(max(item_group_code)), 1, l_end_c)) + 1), 12, '0'))
      into l_child
      from st_item_group
     where rpad(to_char(to_number(substr(to_char(item_group_code), 1, l_end_p))), 12, '0')
         = rpad(to_char(to_number(substr(to_char(r.item_group_code), 1, l_end_p))), 12, '0');
    if l_child is null or detect_level(2, l_child) <> r.group_level + 1 then
      err(-20178, 'خطأ فى رقم مجموعة الأصنـــاف', 'Illegal Item Group Code');
    end if;
    select nvl(max(expire_flag), 0), nvl(max(color_flag), 0), nvl(max(size_flag), 0) into l_exp, l_col, l_size from st_basic;
    insert into st_item_group (item_group_code, name_a, name_e, group_level, group_status, stop_flag, expire_flag, color_flag, size_flag,
                               account_number, cost_code, cost_code2)
    values (l_child, p_name_a, p_name_e, r.group_level + 1, 1, 0, l_exp, l_col, l_size, r.account_number, r.cost_code, r.cost_code2)
    returning rowid into l_rowid;
    g_propagate := true;
    update st_item_group set group_status = 0 where item_group_code = r.item_group_code;
    g_propagate := false;
    g_msg := msg('تم إضافة المجموعة الفرعية رقم ', 'Sub-group created: ') || l_child;
    return rowidtochar(l_rowid);
  end add_child_group;

  -- نسب التغطية (ST_ITEM_GROUP_COV): 'قيمة النهاية لا يمكن ان تكون اقل من قيمة البداية'
  procedure group_cov_row (p_from in number, p_to in number) is
  begin
    if g_bypass then return; end if;
    if p_from is not null and p_to is not null and p_to < p_from then
      err(-20179, 'قيمة النهاية لا يمكن ان تكون اقل من قيمة البداية', 'The end value cannot be less than the start value');
    end if;
  end group_cov_row;

  -- =================================================================================== items
  function item_has_trns (p_group in number, p_item in varchar2) return boolean is
    l_n number;
  begin
    select count(*) into l_n from st_trns_det where group_code = p_group and item_code = p_item and rownum = 1;
    return l_n > 0;
  end item_has_trns;

  -- PRE-INSERT of ST_ITEM.fmb: NVL(MAX(ITEM_CODE),0)+1 per group, first item = SUBSTR(group,1,5) || '0001'
  function next_item_code (p_group in number) return varchar2 is
    l_n   number;
    l_max varchar2(40);
  begin
    select count(*), max(item_code) into l_n, l_max from st_item where item_group_code = p_group;
    if l_n > 0 then
      return to_char(nvl(to_number(l_max default null on conversion error), 0) + 1);
    end if;
    return substr(to_char(p_group), 1, 5) || '0001';
  exception when e_mutating then return null;
  end next_item_code;

  procedure item_row (p_inserting in boolean, p_updating in boolean, p_group in number, p_item in varchar2,
                      p_stop_flag in out number, p_stop_reason in out varchar2, p_stand_flag in out number,
                      p_vat in number, p_min in number, p_max in number, p_moh_flag in number, p_moh_disc in number,
                      p_old_vat in number, p_old_min in number, p_old_max in number, p_old_moh_flag in number, p_old_moh_disc in number) is
    l_n     number;
    l_char  number;
    l_form  varchar2(128) := cur_form;
    function chg (a number, b number) return boolean is
    begin
      return p_inserting or (a is null and b is not null) or (a is not null and b is null) or a <> b;
    end;
  begin
    if g_bypass or g_propagate then return; end if;
    if p_inserting and l_form = 'ST_STANDS' then
      p_stand_flag := 1;                                  -- block WHERE NVL(STAND_FLAG,0) = 1
    end if;
    -- SET_STOP_FLAG (PRE-INSERT / PRE-UPDATE): the items of a stopped group are stopped
    select count(1) into l_n from st_item_group where item_group_code = p_group and nvl(stop_flag, 0) = 1;
    if l_n > 0 then
      p_stop_flag := 1;
    end if;
    if p_updating and p_stop_flag = 0 then
      p_stop_reason := null;                              -- PRE-UPDATE
    end if;
    if chg(p_old_vat, p_vat) and p_vat not in (0, 15) then
      err(-20180, 'خطأ بالقيمة', 'Error in VAT Value');
    end if;
    if (chg(p_old_min, p_min) or chg(p_old_max, p_max)) and p_max < p_min then
      err(-20180, 'الحد الأدنى أكبر من الحد الأقصى', 'Min Limit is Greater than Max');
    end if;
    if nvl(p_moh_flag, 0) = 1 and p_moh_disc is null and (chg(p_old_moh_flag, p_moh_flag) or chg(p_old_moh_disc, p_moh_disc)) then
      err(-20180, 'يجب إدخال نسبة خصم وزارة الصحة', 'Enter the M.O.H discount');
    end if;
    if p_inserting then
      -- ITEM_CODE WHEN-VALIDATE-ITEM: numeric item codes unless COMPANY.CHAR_ITEM_CODE = 1
      select nvl(max(char_item_code), 0) into l_char from company where company_code = nvl(to_num(v('G_COMPANY_CODE')), company_code);
      if l_char = 0 and to_number(p_item default null on conversion error) is null then
        err(-20180, 'خطأ في رقم الصنف !!!', 'Error In Item Code');
      end if;
    end if;
  end item_row;

  function val_item (p_form in varchar2, p_rowid in varchar2, p_request in varchar2, p_group in varchar2, p_item in varchar2,
                     p_name_a in varchar2, p_peice in varchar2, p_lemon in varchar2, p_smc in varchar2) return varchar2 is
    l_group number := to_num(p_group);
    l_n     number;
    r       st_item%rowtype;
  begin
    if p_request not in ('CREATE', 'SAVE') then return null; end if;
    if p_rowid is not null then
      select * into r from st_item where rowid = chartorowid(p_rowid);
    end if;
    -- ITEM_GROUP_CODE LOV (ITEM_GROUP_RG): transaction groups (GROUP_STATUS = 1) allowed for the user group
    if p_rowid is null or r.item_group_code <> l_group then
      select count(*) into l_n from st_item_group where item_group_code = l_group and group_status = 1;
      if l_n = 0 or group_allowed(l_group) = 0 then
        return msg('لا يوجد سجل مناظر فى الجداول الأخرى.', 'There is No Similar Record in other Tables');
      end if;
    end if;
    if p_request = 'CREATE' and p_name_a is null then
      return msg('يجب إدخال الإسم العربى', 'Enter the Arabic name');
    end if;
    if p_request = 'CREATE' and p_item is not null then
      select count(1) into l_n from st_item where item_code = p_item and item_group_code = l_group;
      if l_n > 0 then
        return msg('رقم الصنف مكرر', 'Duplicate item code');
      end if;
    end if;
    if p_peice is not null and (p_rowid is null or nvl(r.peice_no, '#') <> p_peice) then
      select count(*) into l_n from st_item where peice_no = p_peice and (p_rowid is null or rowid <> chartorowid(p_rowid));
      if l_n > 0 then
        return msg('الرقم البديل تم إدخاله من قبل', 'Cannot Dupplicate Peice No');
      end if;
    end if;
    if p_lemon is not null and (p_rowid is null or nvl(r.lemon_code, '#') <> p_lemon) then
      select count(*) into l_n from st_item where lemon_code = p_lemon and (p_rowid is null or rowid <> chartorowid(p_rowid));
      if l_n > 0 then
        return msg('رقم ليمون تم إدخاله من قبل', 'Cannot Dupplicate Lemon Code');
      end if;
    end if;
    if p_smc is not null and (p_rowid is null or nvl(r.smc_code, '#') <> p_smc) then
      select count(*) into l_n from st_item where smc_code = p_smc and (p_rowid is null or rowid <> chartorowid(p_rowid));
      if l_n > 0 then
        return msg('الرقم تم إدخاله من قبل', 'Cannot Dupplicate SMC Code');
      end if;
    end if;
    return null;
  end val_item;

  -- KEY-COMMIT (one basic unit), unit PRE-INSERT / PRE-UPDATE (factor), PRE-UPDATE (VAT -> TX_TAXES_ITEMS),
  -- ST_STANDS: no stand item without components
  procedure item_after (p_form in varchar2, p_rowid in varchar2, p_request in varchar2) is
    r    st_item%rowtype;
    l_n  number;
  begin
    if p_rowid is null or p_request <> 'SAVE' then return; end if;
    select * into r from st_item where rowid = chartorowid(p_rowid);
    select count(*) into l_n from st_item_unit where group_code = r.item_group_code and item_code = r.item_code and nvl(basic_unit, 0) = 1;
    if l_n = 0 then
      if p_form = 'ST_STANDS' then
        err(-20181, 'لا توجد وحدة أساسية', 'There is no Basic Unit');
      else
        err(-20181, 'لا يمكن الحفظ بدون وحدة اساسية', 'Can not save without basic unit');
      end if;
    elsif l_n > 1 then
      err(-20181, 'يوجد أكثر من وحدة أساسية إستبعد الوحدة الأساسية أولاُ', 'There is more than one Basic Unit, Exclude The Basic Unit First');
    end if;
    select count(*) into l_n from (
      select factor from st_item_unit where group_code = r.item_group_code and item_code = r.item_code
       group by factor having count(*) > 1);
    if l_n > 0 then
      err(-20181, 'معامل تحويل مكرر', 'Repeated Factor');
    end if;
    if p_form = 'ST_STANDS' then
      select count(1) into l_n from st_stand_items where stand_item_group_code = r.item_group_code and stand_item_code = r.item_code;
      if l_n = 0 then
        err(-20181, 'غير مسموح بحفظ الصنف بدون اصناف مركبة !!!', 'Saving the item without component items is not allowed');
      end if;
    end if;
    if p_form = 'ST_ITEM' and r.vat_value is not null then
      for t in (select tax_code from tx_taxes_types
                 where start_date = (select max(start_date) from tx_taxes_types where start_date <= sysdate)
                 order by tax_code) loop
        begin
          insert into tx_taxes_items (tax_code, group_code, item_code, tax_per) values (t.tax_code, r.item_group_code, r.item_code, r.vat_value);
        exception when dup_val_on_index then
          update tx_taxes_items set tax_per = r.vat_value
           where tax_code = t.tax_code and item_code = r.item_code and group_code = r.item_group_code;
        end;
      end loop;
    end if;
  end item_after;

  -- ST_ITEM KEY-DELREC / ST_STANDS delete: no item with transactions; PRE-DELETE removes the lots of the item
  procedure item_delete (p_group in number, p_item in varchar2) is
    l_n  number;
    l_m  number;
  begin
    if g_bypass then return; end if;
    if cur_form = 'ST_STANDS' then
      select count(stand_serial) into l_n from st_trns_stand_det where stand_item_code = p_item and stand_item_group_code = p_group;
      select count(1) into l_m from st_trns_det where group_code = p_group and item_code = p_item;
      if l_n + l_m > 0 then
        err(-20182, 'توجد حركات على الصنف لا يمكن حذف الصنف', 'The item has transactions - it cannot be deleted');
      end if;
    else
      select count(1) into l_n from st_trns_det where group_code = p_group and item_code = p_item;
      select count(1) into l_m from st_delivery_det where item_group_code = p_group and item_code = p_item;
      l_n := l_n + l_m;
      select count(1) into l_m from st_sales_order_det where item_group_code = p_group and item_code = p_item;
      l_n := l_n + l_m;
      if l_n > 0 then
        err(-20182, 'هذا الصنف تم عمل حركات عليه ولا يمكن حذفة', 'This Item Have Transaction...Can''t DELETE');
      end if;
    end if;
    delete from st_item_confg where group_code = p_group and item_code = p_item;
    delete from st_item_store_locations where group_code = p_group and item_code = p_item;
    delete from st_store_item where group_code = p_group and item_code = p_item;
    delete from st_item_pieces where group_code = p_group and item_code = p_item;
    delete from st_sub_item where item_code = p_item and item_group_code = p_group;
    delete from rsd_st_item_gtin where group_code = p_group and item_code = p_item;
    delete from st_item_barcode where group_code = p_group and item_code = p_item;
  end item_delete;

  -- CALC_COST (GET_SUM_BAL_COST) and GET_DATA of ST_ITEM.fmb
  function item_info (p_what in varchar2, p_group in varchar2, p_item in varchar2) return varchar2 is
    l_group  number := to_num(p_group);
    l_bal    number;
    l_cost   number;
    l_unit   number;
    l_tbal   number := 0;
    l_tcost  number := 0;
    l_avg    number;
    l_profit number;
    l_txt    varchar2(4000);
  begin
    if l_group is null or p_item is null then return null; end if;
    if p_what = 'STORES' then
      for r in (select si.store_code, s.name_a, s.name_e from st_store_item si, st_store s
                 where s.store_code = si.store_code and si.group_code = l_group and si.item_code = p_item order by si.store_code) loop
        get_balance_cost(l_bal, l_cost, l_unit, r.store_code, l_group, p_item);
        l_txt := l_txt || case when l_txt is not null then ' ، ' end
                 || case when lang = 'E' then nvl(r.name_e, r.name_a) else r.name_a end || ': ' || rtrim(to_char(nvl(l_bal, 0), 'FM999G999G990D999'), '.,');
      end loop;
      return l_txt;
    end if;
    if p_what = 'LAST_PUR' then
      return to_char(get_last_purch_price(l_group, p_item), 'FM999G999G990D0000');
    end if;
    for r in (select store_code from st_store_item where group_code = l_group and item_code = p_item) loop
      get_balance_cost(l_bal, l_cost, l_unit, r.store_code, l_group, p_item);
      if l_bal is not null and l_cost is not null then
        l_tbal  := l_tbal + nvl(l_bal, 0);
        l_tcost := l_tcost + nvl(l_cost, 0);
      end if;
    end loop;
    l_avg := case when l_tbal <> 0 then l_tcost / l_tbal else 0 end;
    if p_what = 'BAL' then
      return rtrim(to_char(l_tbal, 'FM999G999G990D999'), '.,');
    elsif p_what = 'COST' then
      return to_char(l_tcost, 'FM999G999G990D00');
    elsif p_what = 'AVG' then
      return to_char(l_avg, 'FM999G999G990D0000');
    elsif p_what = 'MIN_PROFIT' then
      select nvl(max(min_profit), 0) into l_profit from st_basic;
      if l_profit = 0 then return null; end if;
      return to_char((l_profit / 100) * l_avg + l_avg, 'FM999G999G990D0000');
    end if;
    return null;
  end item_info;

  -- ST_ITEM_UNIT: basic unit factor 1; a unit used in transactions keeps its code, factor and basic flag
  procedure unit_item_row (p_inserting in boolean, p_updating in boolean, p_group in number, p_item in varchar2,
                           p_unit in number, p_factor in number, p_basic in number,
                           p_old_unit in number, p_old_factor in number, p_old_basic in number) is
    l_n number;
  begin
    if g_bypass then return; end if;
    if nvl(p_basic, 0) = 1 and p_factor <> 1 then
      err(-20183, 'معامل التحويل للوحدة الأساسية يجب أن يساوى واحد', 'Basic Unit Transfer Factor must Equal One');
    end if;
    if p_updating and (p_unit <> p_old_unit or p_factor <> p_old_factor or nvl(p_basic, 0) <> nvl(p_old_basic, 0)) then
      select count(unit_code) into l_n from st_trns_det
       where item_code = p_item and group_code = p_group and unit_code = p_old_unit and rownum = 1;
      if l_n > 0 or (nvl(p_old_basic, 0) = 1 and p_unit <> p_old_unit and item_has_trns(p_group, p_item)) then
        if nvl(p_old_basic, 0) = 1 or nvl(p_basic, 0) = 1 then
          err(-20183, 'لا يمكن حذف أو تغير الوحدة الأساسية لإشتراك الصنف فى أحد الحركات',
                      'You can''t delete or change the Basic Unit, Item exists in Transaction');
        else
          err(-20183, 'لا يمكن تغيير هذه الوحدة لإشتراكها فى أحد الحركات', 'You can''t change this Unit, it exists in Transaction');
        end if;
      end if;
    end if;
  end unit_item_row;

  -- ST_ITEM_UNIT KEY-DELREC + PRE-DELETE (class discounts, store units and customer items of the unit)
  procedure unit_item_delete (p_group in number, p_item in varchar2, p_unit in number, p_basic in number) is
    l_n    number;
    l_form varchar2(128) := cur_form;
  begin
    if g_bypass then return; end if;
    if v('REQUEST') = 'DELETE' and l_form in ('ST_ITEM', 'ST_STANDS') then
      -- the whole item is deleted: the item message comes first (checked again by ST_ITEM's delete hook)
      if l_form = 'ST_STANDS' then
        select count(1) into l_n from st_trns_stand_det where stand_item_code = p_item and stand_item_group_code = p_group;
        if l_n > 0 or item_has_trns(p_group, p_item) then
          err(-20182, 'توجد حركات على الصنف لا يمكن حذف الصنف', 'The item has transactions - it cannot be deleted');
        end if;
      else
        select count(1) into l_n from st_delivery_det where item_group_code = p_group and item_code = p_item and rownum = 1;
        if l_n = 0 then
          select count(1) into l_n from st_sales_order_det where item_group_code = p_group and item_code = p_item and rownum = 1;
        end if;
        if l_n > 0 or item_has_trns(p_group, p_item) then
          err(-20182, 'هذا الصنف تم عمل حركات عليه ولا يمكن حذفة', 'This Item Have Transaction...Can''t DELETE');
        end if;
      end if;
    elsif item_has_trns(p_group, p_item) then
      if nvl(p_basic, 0) = 1 then
        err(-20183, 'لا يمكن حذف أو تغير الوحدة الأساسية لإشتراك الصنف فى أحد الحركات',
                    'You can''t delete or change the Basic Unit, Item exists in Transaction');
      end if;
      select count(1) into l_n from st_trns_det where unit_code = p_unit and group_code = p_group and item_code = p_item and rownum = 1;
      if l_n > 0 then
        err(-20183, 'لا يمكن حذف هذه الوحدة لإشتراكها فى أحد الحركات', 'You can''t delete this Unit, it exists in Transaction');
      end if;
    end if;
    delete from ar_st_items_disc a where a.item_code = p_item and a.item_group_code = p_group and a.unit_code = p_unit;
    delete from st_store_unit s where s.item_code = p_item and s.group_code = p_group and s.unit_code = p_unit;
    delete from st_store_item_unit s where s.item_code = p_item and s.group_code = p_group and s.unit_code = p_unit;
    delete from st_cust_items s where s.item_code = p_item and s.item_group_code = p_group and s.unit_code = p_unit;
  end unit_item_delete;

  -- ST_ITEM_BARCODE.ITEM_BARCODE WHEN-VALIDATE-ITEM (CHECK_BARCODE): a barcode belongs to one item
  procedure barcode_row (p_barcode in varchar2, p_group in number, p_item in varchar2) is
    l_item varchar2(40);
  begin
    if g_bypass or p_barcode is null then return; end if;
    begin
      select min(item_code) into l_item from st_item_barcode
       where item_barcode = p_barcode and not (group_code = p_group and item_code = p_item);
    exception when e_mutating then l_item := null;
    end;
    if l_item is not null then
      err(-20184, 'Barcode Exist item code ' || l_item, 'Barcode exists for item ' || l_item);
    end if;
  end barcode_row;

  -- ST_SUB_ITEM: the alternative item exists and is another item (LOV ITEM_CODE_RG)
  procedure sub_item_row (p_item in varchar2, p_group in number, p_sub_item in varchar2, p_sub_group in number) is
    l_n number;
  begin
    if g_bypass then return; end if;
    select count(*) into l_n from st_item where item_code = p_sub_item and item_group_code = p_sub_group;
    if l_n = 0 then
      err(-20184, 'لا يوجد سجل مناظر فى الجداول الأخرى.', 'There is No Similar Record in other Tables');
    end if;
    if p_sub_item = p_item and p_sub_group = p_group then
      err(-20184, 'رقم الصنف البديل لا يمكن تكراره', 'The item code can''t be repeated');
    end if;
  end sub_item_row;

  -- st_store_locations.fmx, items of a location: the item exists (group from the item), order entered, known location
  procedure item_loc_row (p_store in number, p_group in out number, p_item in varchar2, p_location in varchar2, p_serial in number) is
    l_n number;
  begin
    if g_bypass or nvl(cur_form, '#') <> 'ST_STORE_LOCATIONS' then return; end if;
    if p_group is null then
      p_group := item_group(p_item);
    end if;
    select count(*) into l_n from st_item where item_code = p_item and item_group_code = p_group;
    if l_n = 0 then
      err(-20185, 'هذا الصنف غير موجود بملف الاصناف', 'This item does not exist in the items file');
    end if;
    if p_serial is null then
      err(-20185, 'يجب إدخال الترتيب', 'Enter the order');
    end if;
    select count(1) into l_n from st_store_locations where store_code = p_store and location_label = p_location;
    if l_n = 0 then
      err(-20185, 'يجب إدخال رقم المكان', 'Enter a location of the store');
    end if;
  end item_loc_row;

  -- deleting a location that holds items / the store of the locations screen with its locations (relations)
  procedure location_delete (p_store in number, p_location in varchar2) is
    l_n number;
  begin
    if g_bypass then return; end if;
    if v('REQUEST') = 'DELETE' and cur_form = 'ST_STORE_LOCATIONS' then
      err(-20185, 'لا يمكن إلغاء سجل رئيسي في وجود سجلات تابعة له', 'Cannot delete master record when matching detail records exist');
    end if;
    select count(*) into l_n from st_item_store_locations where store_code = p_store and location_label = p_location and rownum = 1;
    if l_n > 0 then
      err(-20185, 'لا يمكن إلغاء سجل رئيسي في وجود سجلات تابعة له', 'Cannot delete master record when matching detail records exist');
    end if;
  end location_delete;

  -- ST_STANDS components: quantity > 0, unit of the component, no duplicate component
  procedure stand_item_row (p_inserting in boolean, p_stand_group in number, p_stand_item in varchar2,
                            p_group in number, p_item in varchar2, p_unit in number, p_qty in number) is
    l_n number;
  begin
    if g_bypass then return; end if;
    if nvl(p_qty, 0) <= 0 then
      err(-20186, 'يجب ان تكون القيمة اكبر من صفر', 'The value must be greater than zero');
    end if;
    select count(*) into l_n from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit;
    if l_n = 0 then
      err(-20186, 'لا يوجد سجل مناظر فى الجداول الأخرى.', 'There is No Similar Record in other Tables');
    end if;
    if p_inserting then
      begin
        select count(*) into l_n from st_stand_items
         where stand_item_group_code = p_stand_group and stand_item_code = p_stand_item
           and item_group_code = p_group and item_code = p_item;
      exception when e_mutating then l_n := 0;
      end;
      if l_n > 0 then
        err(-20186, 'خطأ تكرار بيانات', 'Duplicate data');
      end if;
    end if;
  end stand_item_row;

  procedure stand_service_row (p_inserting in boolean, p_stand_group in number, p_stand_item in varchar2, p_service in number) is
    l_n number;
  begin
    if g_bypass or not p_inserting then return; end if;
    begin
      select count(1) into l_n from st_stand_services
       where stand_item_group_code = p_stand_group and stand_item_code = p_stand_item and service_code = p_service;
    exception when e_mutating then l_n := 0;
    end;
    if l_n > 0 then
      err(-20186, 'لا يمكن إدخال نفس الخدمة', 'The same service cannot be entered twice');
    end if;
  end stand_service_row;

  -- تكلفة كلية of ST_STANDS: components (average receipt cost x factor x quantity) + services (units x cost),
  -- shown only with USERS.ALLOW_VIEW_COST
  function stand_cost (p_group in varchar2, p_item in varchar2) return number is
    l_group number := to_num(p_group);
    l_tot   number := 0;
    l_avg   number;
    l_fac   number;
  begin
    if can_view_cost = 0 or l_group is null then return null; end if;
    for c in (select item_group_code, item_code, item_unit, item_qty from st_stand_items
               where stand_item_group_code = l_group and stand_item_code = p_item) loop
      select avg(nvl(d.unit_cost, 0)) into l_avg
        from st_trns_mast m, st_trns_det d, st_trns_type t
       where m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial and d.trns_type_code = t.trns_type_code
         and t.effect = 1 and d.item_code = c.item_code and d.group_code = c.item_group_code;
      select max(factor) into l_fac from st_item_unit where group_code = c.item_group_code and item_code = c.item_code and unit_code = c.item_unit;
      l_tot := l_tot + nvl(l_avg, 0) * nvl(l_fac, 1) * nvl(c.item_qty, 0);
    end loop;
    for s in (select ss.units_no, ps.unit_cost from st_stand_services ss, st_pd_services ps
               where ps.service_code = ss.service_code and ss.stand_item_group_code = l_group and ss.stand_item_code = p_item) loop
      l_tot := l_tot + nvl(s.units_no, 0) * nvl(s.unit_cost, 0);
    end loop;
    return l_tot;
  end stand_cost;

  -- =================================================================================== transaction types
  function val_trns_type (p_rowid in varchar2, p_request in varchar2, p_code in varchar2, p_effect in varchar2,
                          p_trns_type in varchar2, p_store in varchar2) return varchar2 is
    l_code   number := to_num(p_code);
    l_effect number := to_num(p_effect);
    l_type   number := to_num(p_trns_type);
    l_n      number;
    r        st_trns_type%rowtype;
  begin
    if p_request not in ('CREATE', 'SAVE') then return null; end if;
    if p_request = 'CREATE' then
      select count(1) into l_n from st_trns_type where trns_type_code = l_code;
      if l_n > 0 then
        return msg('هذا الكود موجود من قبل', 'This code already exists');
      end if;
    end if;
    -- the radio groups of the screen: effect وارد / صادر / تحويل من / تحويل إلى / بدون تأثير,
    -- type تسوية / رصيد افتتاحى / تحويل / ... (block WHERE of st_trns_type_st.fmx)
    if l_effect not in (1, 2, 5, 6, 7) or l_type not in (7, 8, 9, 12, 15, 40) then
      return msg('نوع الحركة غير مسموح به', 'Transaction type not allowed');
    end if;
    if l_type = 9 and l_effect in (5, 6) and p_store is null then
      return msg('لا يمكن الحفظ بدون مخزن في حركات التحويل و استلام التحويل', 'A store is required for transfer and transfer receipt types');
    end if;
    if p_rowid is not null then
      select * into r from st_trns_type where rowid = chartorowid(p_rowid);
      if r.effect <> l_effect or r.trns_type <> l_type or r.trns_type_code <> l_code then
        select count(1) into l_n from st_trns_mast where trns_type_code = r.trns_type_code and rownum = 1;
        if l_n > 0 then
          return msg('لا يمكن تعديل الحركة لأنة لها حركات مرتبطة و مرحلة', 'The type cannot be changed: transactions exist');
        end if;
      end if;
    end if;
    return null;
  end val_trns_type;

  procedure trns_type_delete (p_code in number) is
    l_n number;
  begin
    if g_bypass or nvl(cur_form, '#') <> 'ST_TRNS_TYPE_ST' then return; end if;
    select count(1) into l_n from st_trns_mast where trns_type_code = p_code and rownum = 1;
    if l_n > 0 then
      err(-20187, 'لا يمكن حذف السجل حيث توجد حركات معتمدة عليه بالنظام', 'The record cannot be deleted: transactions depend on it');
    end if;
  end trns_type_delete;

  -- deleting a type that still has its entry lines (relation ST_TRNS_TYPE -> STACLNK, non isolated)
  procedure staclnk_delete is
  begin
    if g_bypass then return; end if;
    if v('REQUEST') = 'DELETE' and cur_form = 'ST_TRNS_TYPE_ST' then
      err(-20187, 'لا يمكن إلغاء سجل رئيسي في و جود سجلات تابعة له', 'Cannot delete master record when matching detail records exist');
    end if;
  end staclnk_delete;

  -- آخر مسلسل للحركة: SELECT NVL(MAX(TRNS_SERIAL),0) FROM ST_TRNS_MAST WHERE TRNS_TYPE_CODE = :b1 AND NVL(DELETE_FLAG,0) = 0
  function trns_type_last_serial (p_code in varchar2) return number is
    l_n number;
  begin
    select nvl(max(trns_serial), 0) into l_n from st_trns_mast where trns_type_code = to_num(p_code) and nvl(delete_flag, 0) = 0;
    return l_n;
  end trns_type_last_serial;

  -- نسخ الحركة: the type and its entry lines under a new code
  function copy_trns_type (p_rowid in varchar2, p_new_code in number) return varchar2 is
    l_old   number;
    l_n     number;
    l_rowid rowid;
  begin
    if p_new_code is null then
      err(-20188, 'يجب إدخال رقم الحركة الجديدة', 'Enter the new transaction code');
    end if;
    select trns_type_code into l_old from st_trns_type where rowid = chartorowid(p_rowid);
    select count(1) into l_n from st_trns_type where trns_type_code = p_new_code;
    if l_n > 0 then
      err(-20188, 'رقم الحركة الجديد موجود بالفعل', 'The new transaction code already exists');
    end if;
    insert into st_trns_type (trns_type_code, desc_a, desc_e, last_serial, effect, trns_type, join_type, has_salesman, has_discount,
                              has_freight, has_transport, has_custom, has_insurance, has_commission, has_others, customer_trns_code,
                              supplier_trns_code, entry_type, store_code, post_type, customer_trns_pay_code, supplier_trns_pay_code)
    select p_new_code, desc_a, desc_e, last_serial, effect, trns_type, join_type, has_salesman, has_discount,
           has_freight, has_transport, has_custom, has_insurance, has_commission, has_others, customer_trns_code,
           supplier_trns_code, entry_type, store_code, post_type, customer_trns_pay_code, supplier_trns_pay_code
      from st_trns_type where trns_type_code = l_old;
    insert into staclnk (entry_no, entry_serial_no, account_no_type, account_no, cost_no_type, cost_no, account_ind, value_type,
                         trns_type_code, cost_no2_type, cost_no2)
    select entry_no, entry_serial_no, account_no_type, account_no, cost_no_type, cost_no, account_ind, value_type,
           p_new_code, cost_no2_type, cost_no2
      from staclnk where trns_type_code = l_old;
    select rowid into l_rowid from st_trns_type where trns_type_code = p_new_code;
    g_msg := msg('تم نقل الحركة', 'The transaction type was copied') || ' ' || p_new_code;
    return rowidtochar(l_rowid);
  end copy_trns_type;

  -- =================================================================================== system parameters
  function val_basic (p_rowid in varchar2, p_request in varchar2, p_max_items in varchar2) return varchar2 is
    l_n number;
  begin
    if p_request = 'CREATE' then
      select count(1) into l_n from st_basic;
      if l_n > 0 then
        return msg('لا يمكن إنشاء سجلات إخرى', 'No further records can be created');
      end if;
    end if;
    if p_max_items is not null and nvl(to_num(p_max_items), 0) <= 0 then
      return msg('القيمة يجب أن تكون أكبر من صفر أو خالية.', 'The value must be greater than zero or empty.');
    end if;
    return null;
  end val_basic;

  -- "continue?" alerts of ST_BASIC.fmx when a flag changes
  function basic_warning (p_rowid in varchar2, p_what in varchar2, p_new in varchar2) return varchar2 is
    r    st_basic%rowtype;
    l_n  number;
    l_new number := to_num(p_new);
    function chg (a number) return boolean is
    begin
      return nvl(a, -1) <> nvl(l_new, -1);
    end;
  begin
    if p_rowid is null then return null; end if;
    select * into r from st_basic where rowid = chartorowid(p_rowid);
    if p_what in ('SINGLE_ITEM', 'POST_TYPE', 'DOC_REPEAT') then
      if (p_what = 'SINGLE_ITEM' and chg(r.single_item)) or (p_what = 'POST_TYPE' and chg(r.post_type))
         or (p_what = 'DOC_REPEAT' and chg(r.doc_repeat)) then
        select count(*) into l_n from st_trns_mast where delete_flag != 1 and rownum = 1;
        if l_n > 0 then
          return msg('توجد حركات بالفعل بالنظام - هل تريد تغيير المؤشر الآن', 'Transactions already exist - change the flag now');
        end if;
      end if;
    elsif p_what = 'STOCK_STAND_ITEM' and chg(r.stock_stand_item) then
      select count(1) into l_n from st_trns_det
       where (group_code, item_code) in (select item_group_code, item_code from st_item where nvl(stand_flag, 0) = 1) and rownum = 1;
      if l_n > 0 then
        return msg('يوجد بعض الاصناف المجمعة عليها حركات', 'Some assembled items have transactions');
      end if;
    elsif p_what = 'EXPIRE_FLAG' and chg(r.expire_flag) and nvl(l_new, 0) = 0 then
      select count(1) into l_n from st_item_group where nvl(expire_flag, 0) = 1;
      if l_n > 0 then return msg('يوجد بعض المجموعات عليها تاريخ صلاحية', 'Some groups use the expiry date'); end if;
    elsif p_what = 'SIZE_FLAG' and chg(r.size_flag) and nvl(l_new, 0) = 0 then
      select count(1) into l_n from st_item_group where nvl(size_flag, 0) = 1;
      if l_n > 0 then return msg('يوجد بعض المجموعات عليها مقاس', 'Some groups use the size'); end if;
    elsif p_what = 'COLOR_FLAG' and chg(r.color_flag) and nvl(l_new, 0) = 0 then
      select count(1) into l_n from st_item_group where nvl(color_flag, 0) = 1;
      if l_n > 0 then return msg('يوجد بعض المجموعات عليها لون', 'Some groups use the colour'); end if;
    end if;
    return null;
  end basic_warning;

  -- ST_CHANG_CONFG_SALES_PRICE: UNIT_PRICE is not updatable (UpdateAllowed = No in the .fmb); DISC_RATIO only for users
  -- with USERS.CHANGE_CONFG_SALES_PRICE = 1 (WHEN-NEW-FORM-INSTANCE disables both items otherwise)
  procedure confg_price_row (p_disc in number, p_old_disc in number, p_price in number, p_old_price in number) is
    l_right number;
  begin
    if g_bypass or nvl(cur_form, '#') <> 'ST_CHANG_CONFG_SALES_PRICE' then return; end if;
    if nvl(p_price, -1) <> nvl(p_old_price, -1) then
      err(-20189, 'لا يمكن تعديل سعر الوحدة للشحنة من هذه الشاشة', 'The lot unit price cannot be changed on this screen');
    end if;
    if nvl(p_disc, -1) <> nvl(p_old_disc, -1) then
      select nvl(max(change_confg_sales_price), 0) into l_right from users where users_code = to_num(v('G_USER_CODE'));
      if l_right = 0 then
        err(-20189, 'ليس لك صلاحية تعديل خصم الشحنة', 'You are not allowed to change the lot discount');
      end if;
    end if;
  end confg_price_row;

  -- ST_STOCK_DEF_DET: the scanned code is a lot barcode, a GTIN, an item barcode or an item code; lot by lot number /
  -- expiry month; lot price
  procedure stock_def_det_row (p_inserting in boolean, p_code in varchar2, p_group in out number, p_item in out varchar2,
                               p_confg in out number, p_lot in varchar2, p_expire in date, p_sales_price in out number) is
    l_n number;
  begin
    if g_bypass then return; end if;
    if p_item is null and p_code is not null then
      select max(item_confg_id), max(group_code), max(item_code), count(*) into p_confg, p_group, p_item, l_n
        from st_item_confg where bar_code = p_code;
      if l_n = 0 then
        select max(item_group_code), max(item_code), count(*) into p_group, p_item, l_n
          from st_item where (item_group_code, item_code) in (select group_code, item_code from rsd_st_item_gtin where gtin = p_code);
      end if;
      if l_n = 0 then
        select max(group_code), max(item_code), count(*) into p_group, p_item, l_n
          from (select distinct group_code, item_code from st_item_barcode where item_barcode = p_code);
      end if;
      if l_n = 0 then
        select max(item_group_code), max(item_code), count(*) into p_group, p_item, l_n from st_item where item_code = p_code;
      end if;
      if l_n = 0 then
        err(-20190, 'لا يوجد هذا الباركود', 'This barcode does not exist');
      elsif l_n > 1 then
        err(-20190, 'الكود الدولى متكرر فى أصناف عدة', 'The international code is repeated in several items');
      end if;
    end if;
    if p_item is not null and p_group is null then
      p_group := item_group(p_item);
    end if;
    if p_item is not null and p_confg is null then
      if p_lot is not null and p_expire is not null then
        select max(item_confg_id) into p_confg from st_item_confg
         where group_code = p_group and item_code = p_item and upper(lot_number) = upper(p_lot) and last_day(expire_date) = last_day(p_expire);
      end if;
      if p_confg is null and p_lot is not null then
        select max(item_confg_id) into p_confg from st_item_confg where group_code = p_group and item_code = p_item and upper(lot_number) = upper(p_lot);
      end if;
      if p_confg is null and p_expire is not null then
        select max(item_confg_id) into p_confg from st_item_confg where group_code = p_group and item_code = p_item and last_day(expire_date) = last_day(p_expire);
      end if;
    end if;
    if p_confg is not null and p_sales_price is null then
      select max(unit_price) into p_sales_price from st_item_confg where item_confg_id = p_confg;
    end if;
  end stock_def_det_row;

  -- =================================================================================== query screens
  -- ST_STORE_ITEM (عرض أرصدة المخازن): items of a store with balance / cost / movements; lots of one item
  function store_items (p_store in number, p_group in number, p_item in varchar2) return t_store_items pipelined is
    o      t_store_item;
    l_bal  number;
    l_cost number;
    l_unit number;
    l_view number := can_view_cost;
  begin
    if p_store is null or store_allowed(p_store) = 0 then return; end if;
    for r in (select si.*, it.name_a, it.name_e,
                     (select case when lang = 'E' then nvl(u.name_e, u.name_a) else u.name_a end
                        from st_item_unit iu, st_unit u
                       where iu.group_code = si.group_code and iu.item_code = si.item_code and iu.basic_unit = 1
                         and u.unit_code = iu.unit_code and rownum = 1) unit_name
                from st_store_item si, st_item it
               where si.store_code = p_store and it.item_group_code = si.group_code and it.item_code = si.item_code
                 and (p_group is null or si.group_code = p_group)
                 and (p_item is null or si.item_code = p_item)
                 and group_allowed(si.group_code) = 1
               order by si.group_code, to_number(si.item_code default null on conversion error), si.item_code) loop
      o := null;
      o.row_kind := msg('صنف', 'Item');
      o.store_code := p_store; o.group_code := r.group_code; o.item_code := r.item_code;
      o.item_name := case when lang = 'E' then nvl(r.name_e, r.name_a) else r.name_a end;
      o.unit_name := r.unit_name;
      get_balance_cost(l_bal, l_cost, l_unit, p_store, r.group_code, r.item_code);
      o.balance := nvl(l_bal, 0);
      if l_view = 1 then
        o.total_cost := nvl(l_cost, 0);
        o.avg_cost := case when nvl(l_bal, 0) <> 0 then l_cost / l_bal else 0 end;
      end if;
      o.reorder_limit := r.reorder_limit; o.min_limit := r.min_limit; o.max_limit := r.max_limit; o.reserved_qty := r.reserved_qty;
      select sum(decode(t.effect, 1, 1, 2, 0, 4, 0) * nvl(d.basic_qty, 0)),
             sum(decode(t.effect, 1, 0, 2, 1, 4, 0) * nvl(d.basic_qty, 0)),
             sum(decode(t.effect, 1, 0, 2, 0, 4, 1) * nvl(d.basic_qty, 0))
        into o.received, o.issued, o.returned
        from st_trns_det d, st_trns_mast m, st_trns_type t
       where m.store_code = p_store and d.group_code = r.group_code and d.item_code = r.item_code and m.delete_flag = 0
         and ((t.effect = 2 and t.trns_type = 2) or (t.effect = 4 and t.trns_type = 4) or (t.effect = 1 and t.trns_type = 1))
         and d.trns_type_code = m.trns_type_code and d.trns_serial = m.trns_serial and d.trns_type_code = t.trns_type_code;
      pipe row (o);
      if p_item is not null then
        for c in (select ic.*, (select case when lang = 'E' then nvl(s.name_e, s.name_a) else s.name_a end from supplier s where s.code = ic.supplier_code) supp
                    from st_item_confg ic where ic.group_code = r.group_code and ic.item_code = r.item_code order by ic.item_confg_id) loop
          o := null;
          o.row_kind := msg('شحنة', 'Lot');
          o.store_code := p_store; o.group_code := r.group_code; o.item_code := r.item_code;
          o.item_name := case when lang = 'E' then nvl(r.name_e, r.name_a) else r.name_a end;
          o.unit_name := r.unit_name;
          o.item_confg_id := c.item_confg_id; o.lot_number := c.lot_number; o.expire_date := c.expire_date; o.supplier := c.supp;
          o.sales_price := c.unit_price;
          get_balance_cost_confg(l_bal, l_cost, l_unit, p_store, r.group_code, r.item_code, c.item_confg_id);
          o.balance := nvl(l_bal, 0);
          if l_view = 1 then
            o.total_cost := nvl(l_cost, 0);
            o.avg_cost := l_unit;
          end if;
          pipe row (o);
        end loop;
      end if;
    end loop;
    return;
  end store_items;

  -- the legacy ST_STORE_ITEM block let the user change the store limits of an item (REORDER / MIN / MAX_LIMIT, message
  -- 'الحد الاقصى يجب ان يكون اكبر من الحد الادنى'); here: limits typed together with an item update its store row
  procedure show_store_items (p_store in number, p_group in number default null, p_item in varchar2 default null,
                              p_reorder in number default null, p_min in number default null, p_max in number default null) is
    l_n number;
  begin
    if p_store is null then
      err(-20191, 'يجب تحديد المخزن المراد الجرد له', 'Choose the store');
    end if;
    if store_allowed(p_store) = 0 then
      err(-20191, 'لا توجد صلاحية للمخزن', 'You don''t have permission on this store');
    end if;
    g_msg := null;
    if p_reorder is null and p_min is null and p_max is null then return; end if;
    -- wave 3b: displaying needs only the query right (run_right = query); changing the limits needs the update right
    if v('APP_ID') is not null and not app_sec.can_page(to_number(v('APP_PAGE_ID')), 'U') then
      err(-20191, 'خطأ صلاحية', 'Permission error: you may not change the limits');
    end if;
    if p_item is null then
      err(-20191, 'يجب تحديد الصنف لتعديل حدود الطلب', 'Choose the item to change its limits');
    end if;
    for r in (select rowid rid, si.* from st_store_item si
               where si.store_code = p_store and si.item_code = p_item and (p_group is null or si.group_code = p_group)
                 and group_allowed(si.group_code) = 1
               for update) loop
      if nvl(p_max, r.max_limit) < nvl(p_min, r.min_limit) then
        err(-20191, 'الحد الاقصى يجب ان يكون اكبر من الحد الادنى', 'The maximum limit must be greater than the minimum limit');
      end if;
      update st_store_item
         set reorder_limit = nvl(p_reorder, reorder_limit), min_limit = nvl(p_min, min_limit), max_limit = nvl(p_max, max_limit)
       where rowid = r.rid;
      l_n := nvl(l_n, 0) + 1;
    end loop;
    if l_n is null then
      err(-20191, 'الصنف غير موجود بالمخزن', 'The item is not in this store');
    end if;
    g_msg := msg('تم تعديل حدود الطلب', 'The limits were changed');
  end show_store_items;

  -- ST_STORE_GRP: total cost of a store and a group (items of ST_STORE_ITEM x their lots)
  function store_group_cost (p_store in number, p_group in number) return number is
    l_bal  number;
    l_cost number;
    l_unit number;
    l_tot  number := 0;
  begin
    for r in (select item_code from st_store_item where store_code = p_store and group_code = p_group) loop
      get_balance_cost(l_bal, l_cost, l_unit, p_store, p_group, r.item_code);
      l_tot := l_tot + nvl(l_cost, 0);
    end loop;
    return l_tot;
  end store_group_cost;

  procedure show_store_groups (p_store in number default null) is
  begin
    if p_store is not null and store_allowed(p_store) = 0 then
      err(-20191, 'لا توجد صلاحية للمخزن', 'You don''t have permission on this store');
    end if;
  end show_store_groups;

  -- ST_TRNS_SLS_PU_STAT: all search criteria required, ranges ordered
  procedure show_item_trns (p_item in varchar2, p_from_date in date, p_to_date in date,
                            p_from_store in number, p_to_store in number) is
  begin
    if p_item is null or p_from_date is null or p_to_date is null or p_from_store is null or p_to_store is null then
      err(-20191, 'لابد من ادخال محددات البحث جميعها', 'Enter all the search criteria');
    end if;
    if p_to_store < p_from_store then
      err(-20191, 'يجب أن يكون الي رقم مخزن > من رقم مخزن', 'To store must be greater than from store');
    end if;
    if p_to_date < p_from_date then
      err(-20191, 'يجب أن يكون الي تاريخ> من تاريخ', 'To date must be greater than from date');
    end if;
  end show_item_trns;

  -- رصيد أول المدة للصنف: movements of the item before the first date in the store range (view ST_TRNS_DET_SLS_PU)
  function item_open_balance (p_group in number, p_item in varchar2, p_from_date in date,
                              p_from_store in number, p_to_store in number) return number is
    l_n number;
  begin
    select nvl(sum(case when effect in (1, 4, 6) then 1 when effect in (2, 3, 5) then -1 else 0 end * total_qty), 0)
      into l_n
      from st_trns_det_sls_pu t
     where t.item_code = p_item and (p_group is null or t.group_code = p_group) and t.trns_date < p_from_date
       and t.store_code between nvl(p_from_store, 0) and nvl(p_to_store, 999999999999)
       and trns_type_allowed(t.trns_type_code) = 1;
    return l_n;
  end item_open_balance;

  -- ST_SALES_ORDER_STAT: stores and dates required
  procedure show_docs (p_from_store in number, p_to_store in number, p_from_date in date, p_to_date in date,
                       p_trns_filter in number default null, p_next_filter in number default null,
                       p_from_code in number default null) is
  begin
    if p_from_store is null or p_to_store is null or p_from_date is null or p_to_date is null then
      err(-20191, 'لابد من ادخال محددات البحث جميعها', 'Enter all the search criteria');
    end if;
    if p_to_store < p_from_store then
      err(-20191, 'يجب أن يكون الي رقم مخزن > من رقم مخزن', 'To store must be greater than from store');
    end if;
    if p_to_date < p_from_date then
      err(-20191, 'يجب أن يكون الي تاريخ> من تاريخ', 'To date must be greater than from date');
    end if;
  end show_docs;

  -- totals of a document of ST_TRNS_ALL (TREE_ORDER 1 quotation, 2 sales order, 3.. ST_TRNS_MAST documents):
  -- TOTAL = SUM(QTY*(PRICE-(DISC1+DISC2+DISC3)) - DET_DISC + D.TAX) - DISC_VAL + M.TAX + TRNSPORT - (TOT_DISC1+2+3)
  -- DISC = SUM(QTY*(DISC1+DISC2+DISC3+DET_DISC)) + TOT_DISC1+2+3 + DISC_VAL (DET_DISC times the quantity, as in the legacy query)
  -- ITEMS (اجمالى الأصناف) = TOTAL - TAX + DISC (not in the evidence: derived)
  function doc_total (p_tree in number, p_type in number, p_serial in number, p_what in varchar2) return number is
    l_tot  number;
    l_tax  number;
    l_disc number;
  begin
    if p_tree = 1 then
      select sum(nvl(d.quantity, 0) * (nvl(d.unit_price, 0) - (nvl(d.disc1_value, 0) + nvl(d.disc2_value, 0) + nvl(d.disc3_value, 0)))
                 - nvl(d.det_disc, 0) + nvl(d.tax_value1, 0))
             - max(nvl(m.disc_val, 0)) + max(nvl(m.tax_value1, 0)) + max(nvl(m.trnsport_val, 0))
             - max(nvl(m.tot_disc1_value, 0) + nvl(m.tot_disc2_value, 0) + nvl(m.tot_disc3_value, 0)),
             sum(nvl(d.tax_value1, 0)) + max(nvl(m.tax_value1, 0)),
             sum(nvl(d.quantity, 0) * (nvl(d.disc1_value, 0) + nvl(d.disc2_value, 0) + nvl(d.disc3_value, 0) + nvl(d.det_disc, 0)))
             + max(nvl(m.tot_disc1_value, 0) + nvl(m.tot_disc2_value, 0) + nvl(m.tot_disc3_value, 0) + nvl(m.disc_val, 0))
        into l_tot, l_tax, l_disc
        from st_proposal_mast m, st_proposal_det d
       where m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial and m.trns_type_code = p_type and m.trns_serial = p_serial;
    elsif p_tree = 2 then
      select sum(nvl(d.quantity, 0) * (nvl(d.unit_price, 0) - (nvl(d.disc1_value, 0) + nvl(d.disc2_value, 0) + nvl(d.disc3_value, 0)))
                 - nvl(d.det_disc, 0) + nvl(d.tax_value1, 0))
             - max(nvl(m.disc_val, 0)) + max(nvl(m.tax_value1, 0)) + max(nvl(m.trnsport_val, 0))
             - max(nvl(m.tot_disc1_value, 0) + nvl(m.tot_disc2_value, 0) + nvl(m.tot_disc3_value, 0)),
             sum(nvl(d.tax_value1, 0)) + max(nvl(m.tax_value1, 0)),
             sum(nvl(d.quantity, 0) * (nvl(d.disc1_value, 0) + nvl(d.disc2_value, 0) + nvl(d.disc3_value, 0) + nvl(d.det_disc, 0)))
             + max(nvl(m.tot_disc1_value, 0) + nvl(m.tot_disc2_value, 0) + nvl(m.tot_disc3_value, 0) + nvl(m.disc_val, 0))
        into l_tot, l_tax, l_disc
        from st_sales_order m, st_sales_order_det d
       where m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial and m.trns_type_code = p_type and m.trns_serial = p_serial;
    elsif p_tree in (3, 4, 7, 8, 9, 10) then
      select sum(nvl(d.quantity, 0) * (nvl(d.unit_price, 0) - (nvl(d.disc1_value, 0) + nvl(d.disc2_value, 0) + nvl(d.disc3_value, 0)))
                 - nvl(d.det_disc, 0) + nvl(d.tax_value1, 0))
             - max(nvl(m.disc_val, 0)) + max(nvl(m.tax_value1, 0)) + max(nvl(m.trnsport_val, 0))
             - max(nvl(m.tot_disc1_value, 0) + nvl(m.tot_disc2_value, 0) + nvl(m.tot_disc3_value, 0)),
             sum(nvl(d.tax_value1, 0)) + max(nvl(m.tax_value1, 0)),
             sum(nvl(d.quantity, 0) * (nvl(d.disc1_value, 0) + nvl(d.disc2_value, 0) + nvl(d.disc3_value, 0) + nvl(d.det_disc, 0)))
             + max(nvl(m.tot_disc1_value, 0) + nvl(m.tot_disc2_value, 0) + nvl(m.tot_disc3_value, 0) + nvl(m.disc_val, 0))
        into l_tot, l_tax, l_disc
        from st_trns_mast m, st_trns_det d
       where m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial and m.trns_type_code = p_type and m.trns_serial = p_serial;
    else
      return null;                              -- purchase orders / incoming lots: formula not in the evidence
    end if;
    return case p_what when 'TOTAL' then l_tot when 'TAX' then l_tax when 'DISC' then l_disc
                       when 'ITEMS' then nvl(l_tot, 0) - nvl(l_tax, 0) + nvl(l_disc, 0) end;
  end doc_total;

  -- ST_ITEM_SEARCH: criteria 1 item name / 2 item code / 3 group code, search type 1 contains / 2 starts / 3 ends / 4 equals
  procedure show_item_search (p_text in varchar2, p_criteria in number, p_search_type in number, p_group in number) is
  begin
    if p_text is not null and (p_criteria is null or p_search_type is null) then
      err(-20191, 'لابد من ادخال محددات البحث جميعها', 'Enter all the search criteria');
    end if;
  end show_item_search;

  -- search condition of ST_ITEM_SEARCH: criteria 1 item name (Arabic or English) / 2 item code / 3 group code, search
  -- type 1 contains / 2 starts with / 3 ends with / 4 equals; the group filter keeps the items under the chosen group
  -- (prefix of its level, SELECT GROUP_LEVEL .. / CHR_STRU_END ..)
  function item_search_match (p_group in number, p_item in varchar2, p_name_a in varchar2, p_name_e in varchar2,
                              p_text in varchar2, p_criteria in number, p_search_type in number, p_filter_group in number) return number is
    l_pat  varchar2(4000);
    l_end  number;
    function hit (p_val in varchar2) return boolean is
    begin
      return upper(p_val) like l_pat;
    end;
  begin
    if p_filter_group is not null then
      begin
        select c.chr_stru_end into l_end
          from st_item_group g, st_chart_structure c
         where g.item_group_code = p_filter_group and c.chr_type = 2 and c.chr_stru_level = g.group_level;
      exception when no_data_found then l_end := 12;
      end;
      if substr(to_char(p_group), 1, l_end) <> substr(to_char(p_filter_group), 1, l_end) then
        return 0;
      end if;
    end if;
    if p_text is null then return 1; end if;
    l_pat := case nvl(p_search_type, 1) when 1 then '%' || upper(p_text) || '%' when 2 then upper(p_text) || '%'
                                         when 3 then '%' || upper(p_text) else upper(p_text) end;
    if nvl(p_criteria, 1) = 1 then
      return case when hit(p_name_a) or hit(p_name_e) then 1 else 0 end;
    elsif p_criteria = 2 then
      return case when hit(p_item) then 1 else 0 end;
    else
      return case when hit(to_char(p_group)) then 1 else 0 end;
    end if;
  end item_search_match;

  -- =================================================================================== ST_AUTO_ADJ2
  -- lines of a revaluation count (ST_STOCK_TAKING_TEMP, SERIAL) not yet adjusted (SERIAL_TAKING_TEMP), with the book
  -- balance at the stocktaking date and the counted quantity / cost (MINUS query of ST_AUTO_ADJ2.fmx)
  function build_adj2 (p_store in number, p_date in date, p_serial in number) return t_adj2_lines is
    l_lines t_adj2_lines := t_adj2_lines();
    l       t_adj2_line;
    l_bal   number;
    l_cost  number;
    l_avg   number;
  begin
    for c in (select distinct group_code grp, item_code itm, item_confg_id cfg
                from st_stock_taking_temp_det
               where store_code = p_store and st_taking_date = p_date and serial = p_serial
              minus
              select d.group_code, d.item_code, d.item_confg_id
                from st_trns_mast m, st_trns_det d
               where m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial and nvl(m.delete_flag, 0) = 0
                 and m.serial_taking_temp = p_serial      -- as the legacy MINUS: no store / date condition (see the .md)
              order by 1, 2) loop
      l := null;
      l.group_code := c.grp; l.item_code := c.itm; l.item_confg_id := c.cfg;
      l.item_name := item_name(c.grp, c.itm);
      get_balance_cost_confg(l_bal, l_cost, l_avg, p_store, c.grp, c.itm, c.cfg, p_date, null, null);
      select avg(unit_cost), sum(basic_qty) into l.unit_cost, l.taking_basic_qty
        from st_stock_taking_temp_det
       where store_code = p_store and st_taking_date = p_date and serial = p_serial
         and group_code = c.grp and item_code = c.itm and item_confg_id = c.cfg;
      l.unit_cost := nvl(l.unit_cost, l_avg);
      l.book_basic_qty := nvl(l_bal, 0);
      l.taking_basic_qty := nvl(l.taking_basic_qty, 0);
      begin
        select iu.unit_code, case when lang = 'E' then nvl(u.name_e, u.name_a) else u.name_a end, iu.factor
          into l.unit_code, l.unit_name, l.factor
          from st_item_unit iu, st_unit u
         where nvl(iu.basic_unit, 0) = 1 and iu.group_code = c.grp and iu.item_code = c.itm and iu.unit_code = u.unit_code;
      exception when no_data_found then
        err(-20192, 'خطأ بوحدة الصنف ' || c.grp || '/' || c.itm, 'Error in item unit ' || c.grp || '/' || c.itm);
      end;
      l.book_qty := l.book_basic_qty / nvl(l.factor, 1);
      l.taking_qty := l.taking_basic_qty / nvl(l.factor, 1);
      if c.cfg is not null then
        select max(lot_number), max(expire_date) into l.lot_number, l.expire_date from st_item_confg where item_confg_id = c.cfg;
      end if;
      select count(1) into l.adj_error from st_auto_adj_err2 e
       where e.store_code = p_store and e.serial = p_serial and e.group_code = c.grp and e.item_code = c.itm and rownum = 1;
      l_lines.extend; l_lines(l_lines.count) := l;
    end loop;
    return l_lines;
  end build_adj2;

  function auto_adj2_lines (p_store in number, p_taking_date in date, p_serial in number) return t_adj2_lines pipelined is
    l_lines t_adj2_lines;
  begin
    if p_store is null or p_taking_date is null or p_serial is null then return; end if;
    l_lines := build_adj2(p_store, trunc(p_taking_date), p_serial);
    for i in 1 .. l_lines.count loop
      pipe row (l_lines(i));
    end loop;
    return;
  end auto_adj2_lines;

  -- "عمل التسوية" of ST_AUTO_ADJ2.fmx: issue the book balance (or receive a negative one), then receive the counted
  -- quantity at the count cost, dated on the stocktaking date and linked by SERIAL_TAKING_TEMP; lines whose issue makes a
  -- later transaction negative go to ST_AUTO_ADJ_ERR2 (same algorithm as ST_AUTO_ADJ / APP_PROC_ST.auto_adjust)
  procedure auto_adjust2 (p_taking_date in date, p_store in number, p_serial in number,
                          p_issue_type in number, p_rec_type in number,
                          p_group in number default null, p_item in varchar2 default null) is
    l_date         date := trunc(p_taking_date);
    l_lines        t_adj2_lines;
    l_n            number;
    l_issue_serial number;
    l_issue_dser   number;
    l_issue_item   number;
    l_rec_serial   number;
    l_rec_dser     number;
    l_rec_item     number;
    l_invoice_no   varchar2(25);
    l_rec_doc_no   number;
    l_mast_issue   number := 0;
    l_mast_rec     number := 0;
    l_err_flag     number := 0;
    l_dummy        number;
    l_pw           number := pw;

    function chosen (i pls_integer) return boolean is
    begin
      return (p_group is null or l_lines(i).group_code = p_group) and (p_item is null or l_lines(i).item_code = p_item);
    end;

    procedure new_rec_master is
    begin
      select nvl(max(nvl(trns_serial, 0)), 0) + 1 into l_rec_serial from st_trns_mast where trns_type_code = p_rec_type;
      select nvl(max(nvl(date_serial, 0)), 0) + 1 into l_rec_dser from st_trns_mast where trns_date = l_date;
      l_rec_doc_no := to_number(to_char(p_issue_type) || to_char(l_issue_serial));
      insert into st_trns_mast (trns_type_code, trns_serial, trns_date, date_serial, doc_no, desc_a, desc_e,
                                currency_code, currency_rate, store_code, post_flag, delete_flag, serial_taking_temp)
      values (p_rec_type, l_rec_serial, l_date, l_rec_dser, l_rec_doc_no,
              ' إعادة تقييم للجرد اليا بتاريخ ' || to_char(l_date, 'DD-MM-YYYY'),
              'Automatic adjustment for stocktaking in date ' || to_char(l_date, 'DD-MM-YYYY'),
              1, 1, p_store, 0, 0, p_serial);
      l_rec_item := 1;
    end new_rec_master;
  begin
    if l_date is null or p_store is null or p_serial is null then
      err(-20193, 'يجب ادخال تاريخ الجرد ورقم المخزن ومسلسل الجرد', 'Enter the stocktaking date, the store and the count serial');
    end if;
    if l_pw <> 0 then
      select count(1) into l_n from st_all_store_password where store_code = p_store and password_number = l_pw;
      if l_n = 0 then
        err(-20193, 'ليس لديك صلاحية على هذا المخزن', 'You have no permission on this store');
      end if;
    end if;
    select count(1) into l_n from st_stock_taking_temp where st_taking_date = l_date and store_code = p_store and serial = p_serial;
    if l_n = 0 then
      err(-20193, 'لا يوجد جرد لهذا المخزن فى هذا التاريخ', 'No stocktaking for this store on this date');
    end if;
    if p_issue_type is null or p_rec_type is null then
      err(-20193, 'يجب ادخال كود وارد وصادر التسوية الالية', 'Missing codes for issue and receive automatic adjustment');
    end if;
    select count(1) into l_n from st_trns_type
     where trns_type_code = p_issue_type and effect = 2 and trns_type = 7 and (store_code = p_store or store_code is null)
       and (l_pw = 0 or trns_type_code in (select tp.trns_type_code from st_trnstype_password tp where tp.password_number = l_pw));
    if l_n = 0 then
      err(-20193, 'حركة الصادر للتسوية الأليه غير صحيحة', 'Invalid issue adjustment transaction');
    end if;
    select count(1) into l_n from st_trns_type
     where trns_type_code = p_rec_type and effect = 1 and trns_type = 7 and (store_code = p_store or store_code is null)
       and (l_pw = 0 or trns_type_code in (select tp.trns_type_code from st_trnstype_password tp where tp.password_number = l_pw));
    if l_n = 0 then
      err(-20193, 'حركة الوارد للتسوية الأليه غير صحيحة', 'Invalid receive adjustment transaction');
    end if;

    delete from st_auto_adj_err2 where store_code = p_store and serial = p_serial;
    l_lines := build_adj2(p_store, l_date, p_serial);

    for i in 1 .. l_lines.count loop
      if chosen(i) then
        if nvl(l_lines(i).book_basic_qty, 0) > 0 then
          select count(d.item_serial) into l_dummy
            from st_trns_det d, st_trns_mast m
           where d.group_code = l_lines(i).group_code and d.item_code = l_lines(i).item_code
             and m.store_code = p_store and nvl(m.delete_flag, 0) = 0
             and (   (m.trns_date > l_date)
                  or (m.trns_date = l_date and m.date_serial > l_issue_dser)
                  or (m.trns_date = l_date and m.date_serial = l_issue_dser and d.item_serial > l_issue_item))
             and m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial;
          if l_dummy > 0 and nvl(l_lines(i).taking_basic_qty, 0) < nvl(l_lines(i).book_basic_qty, 0) then
            l_dummy := update_next_trns(p_store, l_lines(i).group_code, l_lines(i).item_code, l_date,
                                        l_issue_dser, l_issue_item, nvl(l_lines(i).taking_basic_qty, 0));
            if l_dummy != 0 then
              l_err_flag := 1;
              begin
                insert into st_auto_adj_err2 values (p_store, l_date, p_serial, l_lines(i).group_code, l_lines(i).item_code,
                                                     l_lines(i).unit_code, nvl(l_lines(i).taking_qty, 0), nvl(l_lines(i).taking_basic_qty, 0));
              exception when others then null;
              end;
              goto skip_insert;
            end if;
          end if;
          if l_mast_issue = 0 then
            l_mast_issue := 1;
            select nvl(max(nvl(trns_serial, 0)), 0) + 1 into l_issue_serial from st_trns_mast where trns_type_code = p_issue_type;
            select nvl(max(nvl(date_serial, 0)), 0) + 1 into l_issue_dser from st_trns_mast where trns_date = l_date;
            l_invoice_no := to_char(p_issue_type) || lpad(to_char(l_issue_serial), 7, '0');
            insert into st_trns_mast (trns_serial, trns_date, date_serial, desc_a, desc_e, currency_rate, post_flag, delete_flag,
                                      trns_type_code, currency_code, store_code, invoice_no, serial_taking_temp)
            values (l_issue_serial, l_date, l_issue_dser,
                    ' إعادة تقييم للجرد اليا بتاريخ ' || to_char(l_date, 'DD-MM-YYYY'),
                    'Automatic adjustment for stocktaking in date ' || to_char(l_date, 'DD-MM-YYYY'),
                    1, 0, 0, p_issue_type, 1, p_store, l_invoice_no, p_serial);
            l_issue_item := 1;
          end if;
          insert into st_trns_det (item_serial, quantity, unit_cost, unit_price, basic_qty, cost_flag, trns_type_code,
                                   trns_serial, unit_code, group_code, item_code, item_confg_id, store_code, serial_taking_temp)
          values (l_issue_item, nvl(l_lines(i).book_qty, 0), l_lines(i).unit_cost, l_lines(i).unit_cost,
                  nvl(l_lines(i).book_basic_qty, 0), 1, p_issue_type, l_issue_serial, l_lines(i).unit_code,
                  l_lines(i).group_code, l_lines(i).item_code, l_lines(i).item_confg_id, p_store, p_serial);
          l_issue_item := l_issue_item + 1;
        elsif nvl(l_lines(i).book_basic_qty, 0) < 0 then
          if l_mast_rec = 0 then
            l_mast_rec := 1;
            new_rec_master;
          end if;
          insert into st_trns_det (trns_type_code, trns_serial, item_serial, group_code, item_code, unit_code, quantity,
                                   unit_price, basic_qty, unit_cost, cost_flag, item_confg_id, store_code, serial_taking_temp)
          values (p_rec_type, l_rec_serial, l_rec_item, l_lines(i).group_code, l_lines(i).item_code, l_lines(i).unit_code,
                  abs(l_lines(i).book_basic_qty), abs(l_lines(i).unit_cost * l_lines(i).factor),
                  abs(nvl(l_lines(i).book_basic_qty, 0)), abs(l_lines(i).unit_cost), 1, l_lines(i).item_confg_id, p_store, p_serial);
          l_rec_item := l_rec_item + 1;
        end if;
      end if;
      <<skip_insert>>
      null;
    end loop;

    l_mast_issue := 0;
    l_mast_rec   := 0;
    for i in 1 .. l_lines.count loop
      if chosen(i) and nvl(l_lines(i).taking_basic_qty, 0) != 0 then
        select count(1) into l_dummy from st_auto_adj_err2
         where group_code = l_lines(i).group_code and item_code = l_lines(i).item_code and store_code = p_store and serial = p_serial;
        if l_dummy = 0 then
          if l_mast_rec = 0 then
            l_mast_rec := 1;
            new_rec_master;
          end if;
          insert into st_trns_det (trns_type_code, trns_serial, item_serial, group_code, item_code, unit_code, quantity,
                                   unit_price, basic_qty, unit_cost, cost_flag, item_confg_id, store_code, serial_taking_temp)
          values (p_rec_type, l_rec_serial, l_rec_item, l_lines(i).group_code, l_lines(i).item_code, l_lines(i).unit_code,
                  nvl(l_lines(i).taking_qty, 0), l_lines(i).unit_cost * l_lines(i).factor,
                  nvl(l_lines(i).taking_basic_qty, 0), l_lines(i).unit_cost, 1, l_lines(i).item_confg_id, p_store, p_serial);
          l_rec_item := l_rec_item + 1;
        end if;
      end if;
    end loop;
    g_msg := case when l_err_flag = 1
                  then msg('توجد بعض الحركات يوجد لها حركات تالية تتعارض معها.', 'Some lines have later transactions that conflict with them.')
             end;
  end auto_adjust2;

  -- =================================================================================== barcode labels
  -- price of the label by the store deal type (same rule as the sales screens: reduction price, else wholesale for
  -- DEAL_TYPE = 1, else retail); 'خطأ فى سعر الصنف' when none
  function label_price (p_store in number, p_group in number, p_item in varchar2, p_unit in number) return number is
    l_price number;
  begin
    select max(case when iu.reduction_price is not null then iu.reduction_price
                    when s.deal_type = 1 then iu.wide_sale_price
                    else iu.retail_sale_price end)
      into l_price
      from st_item_unit iu, st_store s
     where iu.group_code = p_group and iu.item_code = p_item and iu.unit_code = p_unit and s.store_code = p_store;
    return l_price;
  end label_price;

  -- BARCODE_LABELS.fmx print button (report ST_BARCODE_LABEL): DELETE FROM PRINT_TRNS_BARCODE, then one row per sticker
  procedure prepare_barcode_labels (p_store in number, p_group in number, p_item in varchar2, p_unit in number,
                                    p_confg in number, p_count in number, p_price in number default null) is
    l_name  st_item.name_e%type;
    l_piece st_item.peice_no%type;
    l_price number := p_price;
    l_n     number;
  begin
    if p_confg is null then
      err(-20194, 'يجب إدخال مسلسل النظام أولاً', 'Enter the system serial (lot) first');
    end if;
    select count(*) into l_n from st_item_confg where item_confg_id = p_confg and group_code = p_group and item_code = p_item;
    if l_n = 0 then
      err(-20194, 'لايوجد صنف للطباعة', 'No item to print');
    end if;
    begin
      select name_e, peice_no into l_name, l_piece from st_item where item_code = p_item and item_group_code = p_group;
    exception
      when no_data_found then err(-20194, 'لايوجد صنف للطباعة', 'No item to print');
      when too_many_rows then err(-20194, 'يوجد أكثر من صنف بهذا الكود', 'More than one item with this code');
    end;
    if l_price is null then
      l_price := label_price(p_store, p_group, p_item, p_unit);
    end if;
    if l_price is null then
      err(-20194, 'خطأ فى سعر الصنف', 'Error in the item price');
    end if;
    if nvl(p_count, 0) <= 0 then
      err(-20194, 'لايوجد صنف للطباعة', 'No item to print');
    end if;
    delete from print_trns_barcode;
    for i in 1 .. p_count loop
      insert into print_trns_barcode (item_serial, item_name, barcode, item_code, sales_price, user_code)
      values (i, l_name, nvl(l_piece, p_item), p_item, l_price, to_num(v('G_USER_CODE')));
    end loop;
    g_msg := msg('تم تجهيز ملصقات الباركود: ', 'Barcode labels prepared: ') || p_count;
  end prepare_barcode_labels;

  -- BARCODE_LABELS_TRNS.fmx (report ST_BARCODE_TRNS): lines of a transaction in an item range, one sticker per unit
  -- (quantity + bonus, or the quantity typed), barcode '*' || item code || '*', retail price of the line unit
  procedure prepare_barcode_trns (p_type in number, p_serial in number, p_from_item in varchar2, p_to_item in varchar2,
                                  p_qty in number default null) is
    l_n     number := 0;
    l_name  st_item.name_a%type;
    l_price number;
  begin
    if p_type is null or p_serial is null then
      err(-20194, 'يجب إدخال رقم ومسلسل الحركة', 'Enter the transaction type and serial');
    end if;
    delete from print_trns_barcode;
    for r in (select group_code, item_code, item_serial, nvl(p_qty, nvl(quantity, 0) + nvl(bonus, 0)) qty, unit_code
                from st_trns_det
               where trns_type_code = p_type and trns_serial = p_serial
                 and (item_code >= p_from_item or p_from_item is null) and (item_code <= p_to_item or p_to_item is null)
               order by item_code) loop
      select max(name_a) into l_name from st_item where item_code = r.item_code and item_group_code = r.group_code;
      select max(retail_sale_price) into l_price from st_item_unit
       where group_code = r.group_code and item_code = r.item_code and unit_code = r.unit_code;
      for i in 1 .. greatest(nvl(r.qty, 0), 0) loop
        insert into print_trns_barcode (item_serial, item_name, barcode, item_code, sales_price, user_code)
        values (r.item_serial, l_name, '*' || r.item_code || '*', r.item_code, l_price, to_num(v('G_USER_CODE')));
        l_n := l_n + 1;
      end loop;
    end loop;
    if l_n = 0 then
      err(-20194, 'لايوجد صنف للطباعة', 'No item to print');
    end if;
    g_msg := msg('تم تجهيز ملصقات الباركود: ', 'Barcode labels prepared: ') || l_n;
  end prepare_barcode_trns;

end app_rules3_st;
/
show errors package body app_rules3_st

-- =====================================================================================================
-- delete hooks (the rules mechanism has no delete hook; APEX sessions only)
-- =====================================================================================================
create or replace trigger app_rules3_st_unit_bd
before delete on st_unit for each row
begin
  if v('APP_ID') is not null then app_rules3_st.code_delete('ST_UNIT', to_char(:old.unit_code)); end if;
end;
/
create or replace trigger app_rules3_st_store_type_bd
before delete on st_store_type for each row
begin
  if v('APP_ID') is not null then app_rules3_st.code_delete('ST_STORE_TYPE', to_char(:old.store_type)); end if;
end;
/
create or replace trigger app_rules3_st_brand_bd
before delete on st_brand for each row
begin
  if v('APP_ID') is not null then app_rules3_st.code_delete('ST_BRAND', :old.brand_code); end if;
end;
/
create or replace trigger app_rules3_st_pd_services_bd
before delete on st_pd_services for each row
begin
  if v('APP_ID') is not null then app_rules3_st.code_delete('ST_PD_SERVICES', to_char(:old.service_code)); end if;
end;
/
create or replace trigger app_rules3_st_material_bd
before delete on st_active_material for each row
begin
  if v('APP_ID') is not null then app_rules3_st.code_delete('ST_ACTIVE_MATERIAL', to_char(:old.serial)); end if;
end;
/
create or replace trigger app_rules3_st_chart_bd
before delete on st_chart_structure for each row
begin
  if v('APP_ID') is not null then app_rules3_st.struct_delete(:old.chr_type, :old.chr_stru_level); end if;
end;
/
create or replace trigger app_rules3_st_store_del
for delete on st_store compound trigger
  before each row is
  begin
    if v('APP_ID') is not null then
      app_rules3_st.store_delete(:old.store_code, :old.store_status, :old.store_level);
    end if;
  end before each row;
  after statement is
  begin
    if v('APP_ID') is not null then
      app_rules3_st.store_delete_done;
    end if;
  end after statement;
end app_rules3_st_store_del;
/
create or replace trigger app_rules3_st_group_del
for delete on st_item_group compound trigger
  before each row is
  begin
    if v('APP_ID') is not null then
      app_rules3_st.group_delete(:old.item_group_code, :old.group_status, :old.group_level);
    end if;
  end before each row;
  after statement is
  begin
    if v('APP_ID') is not null then
      app_rules3_st.group_delete_done;
    end if;
  end after statement;
end app_rules3_st_group_del;
/
create or replace trigger app_rules3_st_locations_bd
before delete on st_store_locations for each row
begin
  if v('APP_ID') is not null then app_rules3_st.location_delete(:old.store_code, :old.location_label); end if;
end;
/
create or replace trigger app_rules3_st_item_bd
before delete on st_item for each row
begin
  if v('APP_ID') is not null then app_rules3_st.item_delete(:old.item_group_code, :old.item_code); end if;
end;
/
create or replace trigger app_rules3_st_item_unit_bd
before delete on st_item_unit for each row
begin
  if v('APP_ID') is not null then
    app_rules3_st.unit_item_delete(:old.group_code, :old.item_code, :old.unit_code, :old.basic_unit);
  end if;
end;
/
create or replace trigger app_rules3_st_trns_type_bd
before delete on st_trns_type for each row
begin
  if v('APP_ID') is not null then app_rules3_st.trns_type_delete(:old.trns_type_code); end if;
end;
/
create or replace trigger app_rules3_st_staclnk_bd
before delete on staclnk for each row
begin
  if v('APP_ID') is not null then app_rules3_st.staclnk_delete; end if;
end;
/
show errors trigger app_rules3_st_store_del
show errors trigger app_rules3_st_group_del
