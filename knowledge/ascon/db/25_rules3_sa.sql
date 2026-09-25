-- =====================================================================================================
-- APP_RULES3_SA : legacy business rules of the sales screens (system 31) that were generated from structure
-- only (Stage C, wave 3).  Evidence and rule lists: app\legacy\processes\<FORM>.md, overrides in
-- app\legacy\overrides\<FORM>.json.  Common helpers (messages, form of the page, dates) come from APP_RULES3_PR.
--   ST_PAYMENT_TERMS, RET_INV_CODES, ST_BROKER            code tables
--   ST_TRNS_TYPE_SL          transaction types of sales: uses APP_RULES3_PR.trns_type_check / copy_trns_type
--   AR_ST_ITEM_CLASSES       discount classes and their items      AR_ST_ITEM_CLASSES / AR_ST_ITEMS_DISC
--   ST_CUST_ITEMS            customer item discounts               CUSTOMER / ST_CUST_ITEMS
--   ST_ITEM_CLASS            item discounts per class / customer   ST_ITEM / AR_ST_ITEMS_DISC / ST_CUST_ITEMS
--   ST_SALES_PLAN            sales plan per period                 ST_SALES_PLAN / ST_SALES_PLAN_DET
--   ST_CUST_GROUP_PRICE      customer pricing                      ST_CUST_GROUP_PRICE / ST_CUST_GROUP_PRICE_DET
--   ST_ISSUE_IO_VIEW         invoice status monitor (read only)    ST_TRNS_MAST
--   ST_CUSTOMER_REPLACE      replace the customer of unposted documents (process page, legacy ST_REPLACE_SALES_CUST)
-- Row rules run in the generated APPX_<TABLE> triggers (APEX sessions only); page validations return an error text;
-- after-save procedures, actions and processes raise -20180 .. -20199.  No COMMIT: APEX commits the page submit.
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_rules3_sa authid definer as

  -- ------------------------------------------------------------------ code tables
  procedure pay_term_row (p_inserting in boolean, p_serial in number, p_days in number);
  procedure ret_code_row (p_inserting in boolean, p_code in number);
  procedure broker_row (p_inserting in boolean, p_code in number, p_account in number, p_cost in number, p_cost2 in number);
  procedure broker_delete (p_code in number);

  -- ------------------------------------------------------------------ discount classes / customer item discounts
  function  class_validate (p_request in varchar2, p_rowid in varchar2, p_desc_a in varchar2, p_desc_e in varchar2,
                            p_default in varchar2) return varchar2;
  procedure disc_line_row (p_table in varchar2, p_inserting in boolean, p_key in number, p_class in number,
                           p_group in out number, p_item in varchar2, p_unit in out number, p_price in out number,
                           p_d1 in out number, p_d2 in number, p_d3 in number, p_bonus in number, p_xbonus in number);
  function  class_load_excel (p_rowid in varchar2, p_file in varchar2) return varchar2;
  function  class_load_blob (p_rowid in varchar2, p_blob in blob, p_name in varchar2) return varchar2;
  function  cust_load_class (p_cust in number, p_class in number, p_from_supp in number, p_to_supp in number,
                             p_from_kind in number, p_to_kind in number, p_mode in number) return varchar2;
  function  item_load_classes (p_item in varchar2, p_mode in number) return varchar2;
  function  last_message return varchar2;

  -- ------------------------------------------------------------------ sales plan
  function  plan_validate (p_request in varchar2, p_period in varchar2, p_store in varchar2, p_type in varchar2) return varchar2;
  procedure plan_det_row (p_item in varchar2, p_qty in number, p_price in out number);

  -- ------------------------------------------------------------------ customer pricing
  procedure cgp_det_row (p_inserting in boolean, p_cust in number, p_group in out number, p_item in varchar2,
                         p_unit in out number, p_price in out number, p_pct in out number, p_old_pct in number,
                         p_val in out number, p_old_val in number, p_from_qty in number, p_to_qty in number);
  procedure cgp_after_save (p_request in varchar2, p_rowid in varchar2);
  function  cgp_get_items (p_rowid in varchar2) return varchar2;
  function  cgp_copy (p_rowid in varchar2, p_to_cust in number, p_copy_ratio in number) return varchar2;

  -- ------------------------------------------------------------------ invoice status monitor
  function  invoice_total (p_type in number, p_serial in number) return number;
  function  invoice_status (p_type in number, p_serial in number) return varchar2;

  -- ------------------------------------------------------------------ replace the customer of unposted documents
  procedure replace_customer (p_old in number, p_new in number, p_kind in number, p_doc in varchar2 default null);

end app_rules3_sa;
/
show errors package app_rules3_sa

create or replace package body app_rules3_sa as

  g_msg varchar2(4000);

  function m (p_a in varchar2, p_e in varchar2 default null) return varchar2 is
  begin
    return app_rules3_pr.m(p_a, p_e);
  end m;

  procedure err (p_code in pls_integer, p_a in varchar2, p_e in varchar2 default null) is
  begin
    raise_application_error(p_code, m(p_a, p_e));
  end err;

  function to_n (p in varchar2) return number is begin return app_rules3_pr.to_n(p); end;
  function pw return number is begin return app_rules3_pr.pw; end;
  function usr return number is begin return app_rules3_pr.usr; end;
  function last_message return varchar2 is begin return g_msg; end;

  -- ================================================================== code tables
  -- ST_PAYMENT_TERMS (31/31)
  procedure pay_term_row (p_inserting in boolean, p_serial in number, p_days in number) is
    l number;
  begin
    if nvl(p_serial, 0) <= 0 then
      err(-20180, 'المسلسل يجب ان يكون اكبر من الصفر', 'The serial must be greater than zero');
    end if;
    if nvl(p_days, 0) <= 0 then
      err(-20180, 'عدد الايام يجب ان يكون اكبر من الصفر', 'The number of days must be greater than zero');
    end if;
    if p_inserting then
      select count(1) into l from st_payment_terms where serial = p_serial;
      if l > 0 then err(-20181, 'رقم مكرر تم إدخالة من قبل', 'Duplicate number, it was entered before'); end if;
    end if;
  end pay_term_row;

  -- RET_INV_CODES (31/36): numbering max + 1 (generated key), no duplicate
  procedure ret_code_row (p_inserting in boolean, p_code in number) is
    l number;
  begin
    if p_inserting then
      select count(1) into l from ret_inv_codes where complaint_code = p_code;
      if l > 0 then err(-20181, 'رقم مكرر تم إدخالة من قبل', 'Duplicate number, it was entered before'); end if;
    end if;
  end ret_code_row;

  -- ST_BROKER (31/19): numbering max + 1 (generated key), account / cost centres from the legacy LOVs, delete refused
  -- while sales documents use the broker
  procedure broker_row (p_inserting in boolean, p_code in number, p_account in number, p_cost in number, p_cost2 in number) is
    l    number;
    l_pw number := pw;
  begin
    if p_inserting then
      select count(1) into l from st_broker where broker_code = p_code;
      if l > 0 then err(-20181, 'رقم مكرر تم إدخالة من قبل', 'Duplicate number, it was entered before'); end if;
    end if;
    if p_account is not null then
      select count(1) into l from ac_master where account_number = p_account and account_status = 1;
      if l = 0 then err(-20182, app_rules3_pr.in_list('رقم الحساب', 'account number')); end if;
    end if;
    -- legacy LOVs: every cost centre for an unrestricted user (password 0), active ones (COST_STATUS = 1) otherwise
    -- (the password ranges of AC_PASSWORD_COST1 / 2 are not repeated here)
    if p_cost is not null then
      select count(1) into l from ac_cost_centers where cost_code = p_cost and (l_pw = 0 or cost_status = 1);
      if l = 0 then err(-20182, app_rules3_pr.in_list('مركز تكلفة 1', 'cost centre 1')); end if;
    end if;
    if p_cost2 is not null then
      select count(1) into l from ac_cost_centers2 where cost_code = p_cost2 and (l_pw = 0 or cost_status = 1);
      if l = 0 then err(-20182, app_rules3_pr.in_list('مركز تكلفة 2', 'cost centre 2')); end if;
    end if;
  end broker_row;

  procedure broker_delete (p_code in number) is
    l number;
  begin
    select count(1) into l from st_trns_mast where broker_code = p_code;
    if l > 0 then
      err(-20183, 'لايمكن مسح السجل لوجود ارتباطات', 'The record cannot be deleted: it is used by sales documents');
    end if;
  end broker_delete;

  -- ================================================================== AR_ST_ITEM_CLASSES / ST_CUST_ITEMS / ST_ITEM_CLASS
  -- AR_ST_ITEM_CLASSES (31/21): a name, one general class (DEFAULT_FLAG) only
  function class_validate (p_request in varchar2, p_rowid in varchar2, p_desc_a in varchar2, p_desc_e in varchar2,
                           p_default in varchar2) return varchar2 is
    l number;
  begin
    if p_request not in ('CREATE', 'SAVE') then return null; end if;
    if p_desc_a is null and p_desc_e is null then
      return m('يجب ادخال الأسم عربى أو لاتينى', 'The Arabic or the English name must be entered');
    end if;
    if nvl(to_n(p_default), 0) = 1 then
      select count(1) into l from ar_st_item_classes
       where nvl(default_flag, 0) = 1 and (p_rowid is null or rowid <> chartorowid(p_rowid));
      if l > 0 then return m('يوجد فئة عامة أخري مسجلة', 'Another general class already exists'); end if;
    end if;
    return null;
  end class_validate;

  -- lines of AR_ST_ITEMS_DISC (key = class) and ST_CUST_ITEMS (key = customer, p_class = the line's class)
  procedure disc_line_row (p_table in varchar2, p_inserting in boolean, p_key in number, p_class in number,
                           p_group in out number, p_item in varchar2, p_unit in out number, p_price in out number,
                           p_d1 in out number, p_d2 in number, p_d3 in number, p_bonus in number, p_xbonus in number) is
    l number;
  begin
    if p_item is null then return; end if;
    if p_table = 'AR_ST_ITEMS_DISC' then
      select count(1) into l from ar_st_item_classes where class_code = p_key;
      if l = 0 then err(-20182, app_rules3_pr.in_list('الفئة', 'class')); end if;
    end if;
    if p_group is null then
      select min(item_group_code) into p_group from st_item where item_code = p_item;
    end if;
    select count(1) into l from st_item_group where item_group_code = p_group and nvl(group_status, 0) = 1;
    if l = 0 then err(-20182, app_rules3_pr.in_list('مجموعة الصنف', 'item group')); end if;
    select count(1) into l from st_item where item_code = p_item and item_group_code = p_group;
    if l = 0 then err(-20182, app_rules3_pr.in_list('رقم الصنف ' || p_item, 'item ' || p_item)); end if;
    p_unit := nvl(p_unit, app_rules_pr.basic_unit(p_group, p_item));
    select count(1) into l from st_item_unit where unit_code = p_unit and item_code = p_item and group_code = p_group;
    if l = 0 then err(-20182, app_rules3_pr.in_list('الوحدة', 'unit')); end if;
    if p_price is null then
      select min(retail_sale_price) into p_price from st_item_unit where item_code = p_item and group_code = p_group and unit_code = p_unit;
    end if;
    if p_inserting and p_d1 is null then
      select min(moh_disc) into p_d1 from st_item where item_code = p_item and item_group_code = p_group;
    end if;
    if p_price < 0 or p_price > 99999.99 then
      err(-20184, 'قيمة سعر البيع لا يمكن ان تكون اقل من الصفر او اكبر من 99999.99', 'The sales price must be between 0 and 99999.99');
    end if;
    if p_d1 < 0 or p_d2 < 0 or p_d3 < 0 then
      err(-20184, 'قيمة الخصم لا يمكن ان تكون اقل من الصفر', 'The discount cannot be below zero');
    end if;
    if p_bonus < 0 or p_xbonus < 0 then
      err(-20184, 'قيمة الاضافي لا يمكن ان تكون اقل من الصفر', 'The bonus cannot be below zero');
    end if;
    if p_inserting then
      if p_table = 'AR_ST_ITEMS_DISC' then
        select count(1) into l from ar_st_items_disc where class_code = p_key and item_group_code = p_group and item_code = p_item;
      else
        select count(1) into l from st_cust_items where customer_code = p_key and item_group_code = p_group and item_code = p_item;
      end if;
      if l > 0 then err(-20185, 'شريحة الخصم مكررة لنفس الصنف', 'The discount line is repeated for the same item'); end if;
    end if;
    if p_table = 'ST_CUST_ITEMS' and p_class is not null then
      select count(1) into l from ar_st_items_disc where class_code = p_class and item_group_code = p_group and item_code = p_item;
      if l = 0 then
        err(-20185, 'هذا الصنف غير مسجل لنفس الفئة ... رقم الصنف : ' || p_item, 'This item is not registered in the class - item ' || p_item);
      end if;
    end if;
  end disc_line_row;

  -- legacy "تحميل EXCEL" of AR_ST_ITEM_CLASSES (WEBUTIL): item, unit, sales price, discounts 1-3, bonus %, extra bonus %
  function class_load_excel (p_rowid in varchar2, p_file in varchar2) return varchar2 is
    l_blob  blob;
    l_name  varchar2(400);
  begin
    if p_file is null then err(-20186, 'يجب إدخال مسار الملف', 'The file must be chosen'); end if;
    begin
      select blob_content, filename into l_blob, l_name from apex_application_temp_files where name = p_file;
    exception when no_data_found then err(-20186, 'خطأ فى إسم الملف', 'Wrong file name');
    end;
    return class_load_blob(p_rowid, l_blob, l_name);
  end class_load_excel;

  function class_load_blob (p_rowid in varchar2, p_blob in blob, p_name in varchar2) return varchar2 is
    l_class number;
    l_item  varchar2(100);
    l_grp   number;
    l_unit  number;
    l       number;
    l_n     number := 0;
    l_skip  number := 0;
    l_bad   varchar2(2000);
    l_price number; l_d1 number; l_d2 number; l_d3 number; l_b number; l_xb number;
  begin
    select class_code into l_class from ar_st_item_classes where rowid = chartorowid(p_rowid);
    for r in (select col001, col002, col003, col004, col005, col006, col007, col008
                from table(apex_data_parser.parse(p_content => p_blob, p_file_name => p_name))) loop
      l_item := trim(r.col001);
      if instr(l_item, '.') > 0 then l_item := substr(l_item, 1, instr(l_item, '.') - 1); end if;
      continue when l_item is null or to_n(l_item) is null;
      select min(item_group_code) into l_grp from st_item where item_code = l_item;
      select count(1) into l from st_item_group where item_group_code = l_grp and nvl(group_status, 0) = 1;
      if l_grp is null or l = 0 then
        l_bad := substr(l_bad || l_item || ' ', 1, 1900);
        continue;
      end if;
      select count(1) into l from ar_st_items_disc where item_code = l_item and item_group_code = l_grp and class_code = l_class;
      if l > 0 then l_skip := l_skip + 1; continue; end if;
      l_unit := nvl(to_n(r.col002), app_rules_pr.basic_unit(l_grp, l_item));
      select count(1) into l from st_item_unit where unit_code = l_unit and item_code = l_item and group_code = l_grp;
      if l = 0 then l_bad := substr(l_bad || l_item || ' ', 1, 1900); continue; end if;
      l_price := to_n(r.col003);
      l_d1    := to_n(r.col004);
      if l_price is null then
        select min(retail_sale_price) into l_price from st_item_unit where item_code = l_item and group_code = l_grp and unit_code = l_unit;
      end if;
      if l_d1 is null then
        select min(moh_disc) into l_d1 from st_item where item_code = l_item and item_group_code = l_grp;
      end if;
      l_d2 := to_n(r.col005); l_d3 := to_n(r.col006); l_b := to_n(r.col007); l_xb := to_n(r.col008);
      insert into ar_st_items_disc (class_code, item_group_code, item_code, unit_code, sales_price, disc_ratio1, disc_ratio2,
                                    disc_ratio3, bonus_ratio, extra_bonus_ratio)
      values (l_class, l_grp, l_item, l_unit, l_price, l_d1, l_d2, l_d3, l_b, l_xb);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تم تحميل ملف الأكسل', 'The Excel file was loaded') || ': ' || l_n
             || case when l_skip > 0 then m(' - مكرر: ', ' - repeated: ') || l_skip end
             || case when l_bad is not null then m(' - أصناف غير صحيحة: ', ' - invalid items: ') || l_bad end;
    return p_rowid;
  end class_load_blob;

  -- legacy "إنزال أصناف الفئة" of ST_CUST_ITEMS: the class items (manufacturer / main supplier ranges) for the customer;
  -- mode 1 "أضافة بدون حذف", mode 2 "حذف الكل والأضافة"
  function cust_load_class (p_cust in number, p_class in number, p_from_supp in number, p_to_supp in number,
                            p_from_kind in number, p_to_kind in number, p_mode in number) return varchar2 is
    l_cust number;
    l_n    number;
    l_del  number := 0;
  begin
    if p_cust is null then err(-20187, 'يجب ادخال البيانات', 'The customer must be entered'); end if;
    if p_class is null then err(-20187, 'لا يوجد فئة لكي يتم أضافة اصنافها', 'There is no class to add its items'); end if;
    select max(code) into l_cust from customer where code = p_cust;
    if l_cust is null then err(-20187, app_rules3_pr.in_list('العميل', 'customer')); end if;
    if nvl(p_mode, 1) = 2 then
      delete from st_cust_items where customer_code = l_cust;
      l_del := sql%rowcount;
    end if;
    -- one INSERT ... VALUES per line: the row rules of ST_CUST_ITEMS read the table (a multi-row insert would mutate)
    l_n := 0;
    for r in (select d.item_group_code, d.item_code, d.unit_code, d.sales_price, d.disc_ratio1, d.disc_ratio2, d.disc_ratio3,
                     d.bonus_ratio, d.extra_bonus_ratio, d.class_code
                from ar_st_items_disc d
               where d.class_code = p_class
                 and (d.item_group_code, d.item_code) not in (select item_group_code, item_code from st_cust_items where customer_code = l_cust)
                 and (d.item_group_code, d.item_code) in (select item_group_code, item_code from st_item st
                                                            where st.kind_code between nvl(p_from_kind, (select min(kind_code) from st_good_kind))
                                                                                   and nvl(p_to_kind, (select max(kind_code) from st_good_kind))
                                                              and st.supplier between nvl(p_from_supp, (select min(code) from supplier))
                                                                                  and nvl(p_to_supp, (select max(code) from supplier))
                                                              and nvl(st.stop_flag, 0) = 0)
               order by d.item_group_code, d.item_code) loop
      insert into st_cust_items (customer_code, item_group_code, item_code, unit_code, sales_price, disc_ratio1, disc_ratio2,
                                 disc_ratio3, bonus_ratio, extra_bonus_ratio, class_code)
      values (l_cust, r.item_group_code, r.item_code, r.unit_code, r.sales_price, r.disc_ratio1, r.disc_ratio2, r.disc_ratio3,
              r.bonus_ratio, r.extra_bonus_ratio, r.class_code);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تم الانتهاء من اضافة اصناف العميل', 'The customer items were added') || ': ' || l_n
             || case when l_del > 0 then m(' - تم حذف ', ' - deleted ') || l_del end;
    return null;
  end cust_load_class;

  -- legacy "إنزال كل الفئات" of ST_ITEM_CLASS: a discount line of the item in every class that does not have it yet
  -- (retail price of the basic unit, MOH discount); mode 2 first deletes the item's class lines
  function item_load_classes (p_item in varchar2, p_mode in number) return varchar2 is
    l_grp  number;
    l_item varchar2(100) := p_item;
    l_unit number;
    l_n    number;
    l_price number;
    l_moh  number;
  begin
    select min(item_group_code) into l_grp from st_item where item_code = p_item and nvl(stop_flag, 0) = 0;
    if l_grp is null then err(-20187, app_rules3_pr.in_list('الصنف', 'item')); end if;
    if nvl(p_mode, 1) = 2 then
      delete from ar_st_items_disc where item_group_code = l_grp and item_code = l_item;
    end if;
    l_unit := app_rules_pr.basic_unit(l_grp, l_item);
    select max(u.retail_sale_price) into l_price from st_item_unit u where u.unit_code = l_unit and u.item_code = l_item and u.group_code = l_grp;
    select max(i.moh_disc) into l_moh from st_item i where i.item_code = l_item and i.item_group_code = l_grp;
    -- one INSERT ... VALUES per class: the row rules of AR_ST_ITEMS_DISC read the table (a multi-row insert would mutate)
    l_n := 0;
    for r in (select c.class_code from ar_st_item_classes c
               where c.class_code not in (select class_code from ar_st_items_disc where item_code = l_item and item_group_code = l_grp)
               order by c.class_code) loop
      insert into ar_st_items_disc (class_code, item_group_code, item_code, unit_code, sales_price, disc_ratio1)
      values (r.class_code, l_grp, l_item, l_unit, l_price, l_moh);
      l_n := l_n + 1;
    end loop;
    if l_n = 0 then err(-20187, 'لا يوجد فئة لكي يتم أضافتها', 'There is no class to add'); end if;
    g_msg := m('تم إضافة ' || l_n || ' فئة للصنف ' || p_item, l_n || ' classes were added to item ' || p_item);
    return null;
  end item_load_classes;

  -- ================================================================== ST_SALES_PLAN (31/13)
  function plan_validate (p_request in varchar2, p_period in varchar2, p_store in varchar2, p_type in varchar2) return varchar2 is
    l      number;
    l_per  number := to_n(p_period);
    l_type number := to_n(p_type);
    l_pw   number := pw;
  begin
    if p_request <> 'CREATE' then return null; end if;
    select count(1) into l from st_periods where period_code = l_per;
    if l = 0 then return app_rules3_pr.in_list('الفترة', 'period'); end if;
    if app_rules3_pr.store_ok(to_n(p_store)) = 0 then return app_rules3_pr.in_list('المستودع', 'store'); end if;
    select count(1) into l from st_trns_type t
     where t.trns_type_code = l_type and t.effect = 2 and t.trns_type = 2
       and (l_pw = 0 or t.trns_type_code in (select tp.trns_type_code from st_trnstype_password tp where tp.flag = 1 and tp.password_number = l_pw));
    if l = 0 then return app_rules3_pr.in_list('حركة المبيعات', 'sales transaction'); end if;
    return null;
  end plan_validate;

  procedure plan_det_row (p_item in varchar2, p_qty in number, p_price in out number) is
    l number;
  begin
    select count(1) into l from st_item it, st_item_unit iu
     where it.item_code = p_item and nvl(it.stop_flag, 0) = 0 and iu.item_code = it.item_code and iu.group_code = it.item_group_code
       and nvl(iu.basic_unit, 0) = 1;
    if l = 0 then err(-20182, app_rules3_pr.in_list('رقم الصنف ' || p_item, 'item ' || p_item)); end if;
    if p_price is null then
      select max(iu.retail_sale_price) into p_price from st_item it, st_item_unit iu
       where it.item_code = p_item and iu.item_code = it.item_code and iu.group_code = it.item_group_code and nvl(iu.basic_unit, 0) = 1;
    end if;
    if p_qty is null or p_price is null then
      err(-20188, 'لابد من ادخال الكمية والسعر', 'The quantity and the price must be entered');
    end if;
  end plan_det_row;

  -- ================================================================== ST_CUST_GROUP_PRICE (31/28)
  procedure cgp_det_row (p_inserting in boolean, p_cust in number, p_group in out number, p_item in varchar2,
                         p_unit in out number, p_price in out number, p_pct in out number, p_old_pct in number,
                         p_val in out number, p_old_val in number, p_from_qty in number, p_to_qty in number) is
    l number;
  begin
    if p_item is null then return; end if;
    p_group := nvl(p_group, app_rules_pr.item_group(p_item));
    select count(1) into l from st_item where item_group_code = p_group and item_code = p_item;
    if l = 0 then err(-20182, app_rules3_pr.in_list('رقم الصنف ' || p_item, 'item ' || p_item)); end if;
    p_unit := nvl(p_unit, app_rules_pr.basic_unit(p_group, p_item));
    select count(1) into l from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit;
    if l = 0 then err(-20182, app_rules3_pr.in_list('رقم الوحدة', 'unit')); end if;
    -- legacy: sales price (and cost) of the item's basic unit, displayed on the line
    select nvl(max(c.retail_sale_price), 0) into p_price
      from st_item a, st_item_unit c
     where c.basic_unit = 1 and c.item_code = a.item_code and c.group_code = a.item_group_code
       and a.item_group_code = p_group and a.item_code = p_item;
    if nvl(p_price, 0) = 0 and (p_pct is not null or p_val is not null) then
      err(-20189, 'يجب إدخال سعر الصنف', 'The item has no sales price');
    end if;
    if p_pct < 0 or p_pct > 100 then
      err(-20189, 'نسبة الخصم يجب ان تكون بين 0 و 100', 'The discount percent must be between 0 and 100');
    end if;
    if p_val < 0 or p_val > nvl(p_price, 0) then
      err(-20189, 'قيمة الخصم غير صحيحة', 'Invalid discount value');
    end if;
    if nvl(p_price, 0) <> 0 then
      if (p_inserting and p_val is null and p_pct is not null) or (not p_inserting and app_rules3_pr.chg(p_pct, p_old_pct) = 1
                                                                  and app_rules3_pr.chg(p_val, p_old_val) = 0) then
        p_val := round(p_price * p_pct / 100, 4);
      elsif (p_inserting and p_pct is null and p_val is not null) or (not p_inserting and app_rules3_pr.chg(p_val, p_old_val) = 1) then
        p_pct := case when p_val is null then null else round(p_val * 100 / p_price, 4) end;
      end if;
    end if;
    if p_from_qty > p_to_qty then
      err(-20189, 'الكميات لا يمكن ان تتقاطع', 'The quantity ranges cannot intersect');
    end if;
  end cgp_det_row;

  procedure cgp_after_save (p_request in varchar2, p_rowid in varchar2) is
    l_cust number;
    l      number;
  begin
    if p_request not in ('CREATE', 'SAVE') or p_rowid is null then return; end if;
    select cust_code into l_cust from st_cust_group_price where rowid = chartorowid(p_rowid);
    select count(1) into l
      from st_cust_group_price_det a, st_cust_group_price_det b
     where a.cust_code = l_cust and b.cust_code = l_cust and a.det_ser < b.det_ser
       and a.item_group_code = b.item_group_code and a.item_code = b.item_code
       and (b.from_qty between a.from_qty and a.to_qty or b.to_qty between a.from_qty and a.to_qty
            or a.from_qty between b.from_qty and b.to_qty);
    if l > 0 then err(-20189, 'الكميات لا يمكن ان تتقاطع', 'The quantity ranges cannot intersect'); end if;
  end cgp_after_save;

  -- legacy GET_ITEMS "إنزال الأصناف": the items of the header's group / item ranges not listed yet
  function cgp_get_items (p_rowid in varchar2) return varchar2 is
    l_h   st_cust_group_price%rowtype;
    l_ser number;
    l_n   number := 0;
    l_pw  number := pw;
  begin
    select * into l_h from st_cust_group_price where rowid = chartorowid(p_rowid);
    select nvl(max(det_ser), 0) into l_ser from st_cust_group_price_det where cust_code = l_h.cust_code;
    for r in (select a.item_group_code, a.item_code, c.unit_code
                from st_item a, st_item_group b, st_item_unit c
               where a.item_group_code = b.item_group_code and c.basic_unit = 1 and c.item_code = a.item_code
                 and c.group_code = a.item_group_code
                 and (l_pw = 0 or b.item_group_code in (select group_code from st_group_password where password_number = l_pw))
                 and a.item_group_code between nvl(l_h.from_group_code, a.item_group_code) and nvl(l_h.to_group_code, a.item_group_code)
                 and a.item_code between nvl(l_h.from_item_code, a.item_code) and nvl(l_h.to_item_code, a.item_code)
                 and not exists (select 1 from st_cust_group_price_det d
                                  where d.cust_code = l_h.cust_code and d.item_group_code = a.item_group_code and d.item_code = a.item_code)
               order by a.item_group_code, a.item_code) loop
      l_ser := l_ser + 1;
      insert into st_cust_group_price_det (cust_code, item_group_code, item_code, disc_percent, disc_val, unit_code, det_ser)
      values (l_h.cust_code, r.item_group_code, r.item_code, 0, 0, r.unit_code, l_ser);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تم الانتهاء من اضافة اصناف العميل', 'The customer items were added') || ': ' || l_n;
    return p_rowid;
  end cgp_get_items;

  -- legacy COPY_ITEMS "نسخ اصناف و مجموعات العميل الحالي الي عميل اخر" (with or without the discount "نسخ النسبة")
  function cgp_copy (p_rowid in varchar2, p_to_cust in number, p_copy_ratio in number) return varchar2 is
    l_h   st_cust_group_price%rowtype;
    l_ser number;
    l     number;
    l_n   number := 0;
  begin
    if p_to_cust is null then
      err(-20190, 'لا بد من ادخال رقم عميل لكي يتم نسخ الاصناف لة', 'Enter the customer to copy the items to');
    end if;
    select * into l_h from st_cust_group_price where rowid = chartorowid(p_rowid);
    select count(1) into l from customer where code = p_to_cust;
    if l = 0 then err(-20190, app_rules3_pr.in_list('إلي عميل', 'to customer')); end if;
    select count(1) into l from st_cust_group_price where cust_code = p_to_cust;
    if l = 0 then
      insert into st_cust_group_price (cust_code, deal_type, notes, from_group_code, to_group_code, from_item_code, to_item_code)
      values (p_to_cust, l_h.deal_type, l_h.notes, l_h.from_group_code, l_h.to_group_code, l_h.from_item_code, l_h.to_item_code);
    end if;
    select nvl(max(det_ser), 0) into l_ser from st_cust_group_price_det where cust_code = p_to_cust;
    for r in (select * from st_cust_group_price_det where cust_code = l_h.cust_code order by item_group_code, item_code) loop
      l_ser := l_ser + 1;
      insert into st_cust_group_price_det (cust_code, item_group_code, item_code, disc_percent, disc_val, from_qty, to_qty,
                                           unit_code, det_ser)
      values (p_to_cust, r.item_group_code, r.item_code,
              case when nvl(p_copy_ratio, 0) = 1 then r.disc_percent else 0 end,
              case when nvl(p_copy_ratio, 0) = 1 then r.disc_val else 0 end,
              r.from_qty, r.to_qty, r.unit_code, l_ser);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تم الانتهاء من نسخ اصناف العميل', 'The customer items were copied') || ': ' || l_n;
    return p_rowid;
  end cgp_copy;

  -- ================================================================== ST_ISSUE_IO_VIEW (31/37)
  -- legacy invoice total: sum(qty x (price - discounts)) - line discount + line VAT - header discount + VAT + transport
  -- - total discounts 1..3
  function invoice_total (p_type in number, p_serial in number) return number is
    l number;
  begin
    select sum((nvl(d.quantity, 0) * (nvl(d.unit_price, 0) - (nvl(d.disc1_value, 0) + nvl(d.disc2_value, 0) + nvl(d.disc3_value, 0))))
               - nvl(d.det_disc, 0) + nvl(d.tax_value1, 0))
           - nvl(m.disc_val, 0) + nvl(m.tax_value1, 0) + nvl(m.trnsport_val, 0)
           - (nvl(m.tot_disc1_value, 0) + nvl(m.tot_disc2_value, 0) + nvl(m.tot_disc3_value, 0))
      into l
      from st_trns_mast m, st_trns_det d
     where m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial
       and m.trns_type_code = p_type and m.trns_serial = p_serial
     group by m.disc_val, m.tax_value1, m.trnsport_val, m.tot_disc1_value, m.tot_disc2_value, m.tot_disc3_value;
    return l;
  exception when no_data_found then return null;
  end invoice_total;

  -- legacy "اخر حالة للفاتورة": the last stage reached (print, preparation, review, delivery area, driver, driver 2, customer)
  function invoice_status (p_type in number, p_serial in number) return varchar2 is
    l st_trns_mast%rowtype;
  begin
    select * into l from st_trns_mast where trns_type_code = p_type and trns_serial = p_serial;
    return case
             when nvl(l.cust_auth_flag, 0) = 1 then m('تسليم - العميل', 'Delivered - customer')
             when nvl(l.dlvr2_flag, 0) = 1 then m('تسليم - السائق 2', 'Delivered - driver 2')
             when nvl(l.dlvr_flag, 0) = 1 then m('تسليم - السائق', 'Delivered - driver')
             when nvl(l.dlvr_loc_flag, 0) = 1 then m('منطقة التسليم', 'Delivery area')
             when nvl(l.rev_flag, 0) = 1 then m('مراجعة', 'Reviewed')
             when nvl(l.prepare_flag, 0) = 1 then m('تحضير', 'Prepared')
             when nvl(l.print_flag, 0) = 1 then m('مطبوع', 'Printed')
             else m('غير مطبوع', 'Not printed')
           end;
  exception when no_data_found then return null;
  end invoice_status;

  -- ================================================================== ST_CUSTOMER_REPLACE (31/65)
  -- legacy: list the old customer's unposted documents of one kind (1 sales invoices, 2 sales orders, 3 quotations,
  -- 4 sales returns without invoice) and move each to the new customer with the DB function ST_REPLACE_SALES_CUST
  -- (it moves the linked quotation / order / invoice together, keeps OLD_CUSTOMER_CODE / OLD_SALESMAN_CODE and takes the
  -- new customer's last salesman).  p_doc: optional "type/serial" to move one listed document only.
  procedure replace_customer (p_old in number, p_new in number, p_kind in number, p_doc in varchar2 default null) is
    l_res  number;
    l_n    number := 0;
    l_type number := to_n(regexp_substr(p_doc, '^[0-9]+'));
    l_ser  number := to_n(regexp_substr(p_doc, '[0-9]+$'));
    l      number;
  begin
    if p_old is null or p_new is null or p_kind is null then
      err(-20191, 'يجب إستكمال البيانات', 'The data must be completed');
    end if;
    if p_old = p_new then
      err(-20191, 'خطأ فى البيانات', 'Data error') ;
    end if;
    select count(1) into l from customer where code = p_new and nvl(customer_status, 0) = 1;
    if l = 0 then err(-20191, app_rules3_pr.in_list('إلى عميل', 'to customer')); end if;
    app_rules_sa.set_bypass(true);   -- the legacy function writes the documents itself: the screen row rules stand aside
    for r in (select m.trns_type_code, m.trns_serial
                from st_trns_mast m, st_trns_type t
               where p_kind = 1 and m.trns_type_code = t.trns_type_code and t.effect = 2 and t.trns_type = 2
                 and nvl(m.delete_flag, 0) = 0 and nvl(m.cust_post_flag, 0) = 0 and nvl(m.post_flag, 0) = 0
                 and m.customer_code = p_old and m.old_customer_code is null
                 and (m.trns_type_code, m.trns_serial) not in (select ret_trns_type_code, ret_trns_serial from st_trns_mast
                                                                where ret_trns_type_code is not null and ret_trns_serial is not null
                                                                  and delete_flag = 0)
              union all
              select o.trns_type_code, o.trns_serial
                from st_sales_order o
               where p_kind = 2 and o.sl_trns_type_code is null and o.sl_trns_serial is null and o.doc_no is not null
                 and o.customer_code = p_old and o.old_customer_code is null and o.delete_date is null
              union all
              select q.trns_type_code, q.trns_serial
                from st_proposal_mast q
               where p_kind = 3 and q.customer_code = p_old and q.old_customer_code is null and nvl(q.delete_flag, 0) = 0
              union all
              select m.trns_type_code, m.trns_serial
                from st_trns_mast m, st_trns_type t
               where p_kind = 4 and m.trns_type_code = t.trns_type_code and t.effect = 4 and t.trns_type = 4
                 and m.ret_trns_type_code is null and nvl(m.delete_flag, 0) = 0 and nvl(m.cust_post_flag, 0) = 0
                 and nvl(m.post_flag, 0) = 0 and m.customer_code = p_old and m.old_customer_code is null
              order by 1, 2) loop
      continue when l_type is not null and (r.trns_type_code <> l_type or r.trns_serial <> l_ser);
      l_res := st_replace_sales_cust(r.trns_type_code, r.trns_serial, p_new, p_kind);
      if nvl(l_res, 0) <> 1 then
        err(-20192, 'خطأ فى البيانات' || ' (' || r.trns_type_code || '/' || r.trns_serial || ')',
            'Data error (' || r.trns_type_code || '/' || r.trns_serial || ')');
      end if;
      l_n := l_n + 1;
    end loop;
    app_rules_sa.set_bypass(false);
    if l_n = 0 then
      err(-20193, 'لا توجد مستندات غير مرحلة لهذا العميل', 'The customer has no unposted documents of this kind');
    end if;
    g_msg := m('تم النقل بنجاح', 'Moved successfully') || ' (' || l_n || ')';
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end replace_customer;

end app_rules3_sa;
/
show errors package body app_rules3_sa

create or replace trigger app_r3_st_broker_bd before delete on st_broker for each row
begin
  if v('APP_ID') is not null then app_rules3_sa.broker_delete(:old.broker_code); end if;
end;
/
