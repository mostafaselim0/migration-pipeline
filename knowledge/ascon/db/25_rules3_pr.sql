-- =====================================================================================================
-- APP_RULES3_PR : legacy business rules of the purchasing screens (system 30) that were generated from
-- structure only (Stage C, wave 3).  Evidence and rule lists: app\legacy\processes\<FORM>.md, overrides in
-- app\legacy\overrides\<FORM>.json.
--   LC_PAY_COND, LC_PAY_CREDIT_COND, ST_TERM_SHIP, LC_PORT, ST_CNTRCT_TYPES, ST_PR_ORDER_TYPES, ST_PERIODS  code tables
--   ST_PU_SERVICES          purchase services chart (tree over the ST_CHART_SERVICES levels)
--   ST_TRNS_TYPE            transaction types of purchasing (+ STACLNK posting lines); the type helpers are shared
--                           with ST_TRNS_TYPE_SL (APP_RULES3_SA)
--   ST_PROJ_EST             material request estimates           ST_PROJ_EST_MAST / ST_PROJ_EST_DET
--   ST_SUPPLIER_AGREEMENT   supplier agreements                  ST_SUPP_AGRMNT / _SUPP / _DET
--   ST_PO_ITEM_SUPP         preparing purchase orders            ST_PO_ITEM_SUPP / _DET  -> PR_ORDER / PR_ORDER_DET
--   ST_RETURN_AUTH_COST2    approval of purchase returns w/o inv ST_TRNS_AUTH_MAST / _DET -> ST_TRNS_MAST / ST_TRNS_DET
-- Wiring
--   * row rules of the overrides call the *_row procedures from the generated APPX_<TABLE> triggers (APEX only);
--   * page validations return an error text, after-save procedures and actions raise -20150 .. -20179;
--   * cross-row checks of grid tables (an Interactive Grid saves row by row and a row trigger cannot read its own
--     table on UPDATE) and the legacy delete refusals are the triggers at the end of this file (APEX sessions only);
--   * ST_TRNS_TYPE is shared with the stock screen ST_TRNS_TYPE_ST: every hook here first checks the legacy form of
--     the current APEX page (APP_PAGE_MAP) and leaves other screens alone.
-- Existing legacy DB triggers are not duplicated.  No COMMIT: APEX commits the page submit.
-- Messages: legacy Arabic text where one exists, English when G_LANG = 'en'.
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_rules3_pr authid definer as

  -- ------------------------------------------------------------------ common helpers
  function m (p_a in varchar2, p_e in varchar2 default null) return varchar2;
  procedure err (p_code in pls_integer, p_a in varchar2, p_e in varchar2 default null);
  function cur_form return varchar2;                          -- legacy form of the current APEX page
  function pw return number;                                  -- G_PASSWORD_NUMBER (0 = unrestricted)
  function usr return number;                                 -- G_USER_CODE
  function to_d (p in varchar2) return date;                  -- page item (DD/MM/YYYY) -> date
  function to_n (p in varchar2) return number;
  function chg (p_new in number, p_old in number) return number;
  function chg (p_new in varchar2, p_old in varchar2) return number;
  function chg (p_new in date, p_old in date) return number;
  function user_flag (p_col in varchar2) return number;       -- USERS.<p_col> of the current user
  function st_min_date return date;                           -- CHECK_DATE (systems 3/30/31): MIN(ST_BASIC.MIN_DATE)
  function date_error (p_date in date) return varchar2;       -- CHECK_DATE: not after today, not before the minimum
  function type_is (p_type in number, p_effect in number, p_trns_type in number) return number;
  function store_ok (p_store in number) return number;        -- active, not stopped, allowed for the group
  function in_list (p_label_a in varchar2, p_label_e in varchar2) return varchar2;   -- "value not in the list" text
  -- (true while an action of this package re-writes rows itself: the row rules stand aside)
  procedure set_action (p_on in boolean);
  function in_action return boolean;

  -- ------------------------------------------------------------------ code tables (grid row rules, delete hooks)
  procedure pay_cond_row (p_inserting in boolean, p_code in number);
  procedure pay_cond_delete (p_code in number);
  procedure credit_cond_row (p_inserting in boolean, p_code in number);
  procedure credit_cond_delete (p_code in number);
  procedure term_ship_row (p_inserting in boolean, p_code in number);
  procedure term_ship_delete (p_code in number);
  procedure port_row (p_inserting in boolean, p_code in number);
  procedure port_delete (p_code in number);
  procedure cntrct_row (p_inserting in boolean, p_code in number, p_name_a in varchar2, p_name_e in varchar2);
  procedure cntrct_delete (p_code in number);
  procedure pr_order_type_row (p_inserting in boolean, p_serial in number, p_name_a in varchar2, p_name_e in varchar2,
                               p_trns_type in number);
  function  next_period_code return number;
  procedure period_row (p_inserting in boolean, p_code in number, p_from in date, p_till in date);
  procedure period_overlap (p_code in number);                -- after statement (compound trigger)

  -- ------------------------------------------------------------------ ST_PU_SERVICES (services chart)
  function  service_level (p_code in number) return number;  -- level of a 12-digit code in ST_CHART_SERVICES
  function  service_parent (p_code in number, p_level in number) return number;
  procedure service_row (p_inserting in boolean, p_code in number, p_level in out number, p_leaf in out number,
                         p_account in number);
  procedure service_after_insert (p_code in number, p_level in number);
  procedure service_before_delete (p_code in number);
  procedure service_after_delete (p_code in number, p_level in number);

  -- ------------------------------------------------------------------ ST_TRNS_TYPE (+ ST_TRNS_TYPE_SL)
  function  trns_type_check (
    p_form      in varchar2, p_request   in varchar2, p_rowid     in varchar2,
    p_code      in varchar2, p_effect    in varchar2, p_trns_type in varchar2, p_store   in varchar2,
    p_join      in varchar2, p_post      in varchar2, p_entry     in varchar2,
    p_cust      in varchar2, p_cust_pay  in varchar2, p_supp      in varchar2, p_supp_pay in varchar2,
    p_rp        in varchar2, p_pc        in varchar2,
    p_pr        in varchar2 default null, p_pu      in varchar2 default null, p_quot    in varchar2 default null,
    p_supp_disc in varchar2 default null,
    p_sales     in varchar2 default null, p_sales_order in varchar2 default null, p_reserve in varchar2 default null,
    p_delivery  in varchar2 default null, p_tfrom   in varchar2 default null, p_tto     in varchar2 default null,
    p_ctgry     in varchar2 default null) return varchar2;
  procedure staclnk_after_save (p_request in varchar2, p_code in varchar2);
  procedure trns_type_delete (p_code in number);              -- BEFORE DELETE trigger on ST_TRNS_TYPE
  function  copy_trns_type (p_form in varchar2, p_rowid in varchar2, p_new_code in number) return varchar2;
  function  last_message return varchar2;

  -- ------------------------------------------------------------------ ST_PROJ_EST (material request estimates)
  function  next_est_serial (p_store in number) return number;
  procedure est_mast_row (p_inserting in boolean, p_store in number, p_date in out date, p_date_serial in out number);
  function  est_validate (p_request in varchar2, p_rowid in varchar2, p_store in varchar2, p_date in varchar2) return varchar2;
  procedure est_det_row (p_inserting in boolean, p_serial in number, p_store in number,
                         p_group in out number, p_item in varchar2, p_unit in out number,
                         p_qty in number, p_basic_qty in out number, p_color in number, p_size in number,
                         p_date_serial in out number);
  procedure est_after_save (p_request in varchar2, p_rowid in varchar2);
  procedure est_mast_delete (p_store in number);             -- BEFORE DELETE triggers
  procedure est_det_delete (p_store in number, p_group in number, p_item in varchar2, p_color in number, p_size in number);
  function  est_copy_last (p_rowid in varchar2) return varchar2;

  -- ------------------------------------------------------------------ ST_SUPPLIER_AGREEMENT
  function  year_end return date;
  procedure agrmnt_row (p_inserting in boolean, p_approve in out number, p_old_approve in number,
                        p_end in date, p_old_end in date, p_stop in out number);
  function  agrmnt_validate (p_request in varchar2, p_rowid in varchar2, p_kind in varchar2, p_cntrct in varchar2,
                             p_start in varchar2, p_end in varchar2) return varchar2;
  procedure agrmnt_supp_row (p_serial in number, p_supplier in number);
  procedure agrmnt_det_row (p_inserting in boolean, p_serial in number,
                            p_group in out number, p_item in varchar2, p_unit in out number, p_supplier in out number,
                            p_qty in number, p_old_qty in number, p_basic_qty in out number,
                            p_price in out number, p_old_price in number,
                            p_bonus_ratio in out number, p_old_bonus_ratio in number, p_bonus in out number, p_old_bonus in number,
                            p_xratio in out number, p_old_xratio in number, p_xbonus in out number, p_old_xbonus in number,
                            p_d1r in out number, p_o_d1r in number, p_d1v in out number, p_o_d1v in number,
                            p_d2r in out number, p_o_d2r in number, p_d2v in out number, p_o_d2v in number,
                            p_d3r in out number, p_o_d3r in number, p_d3v in out number, p_o_d3v in number,
                            p_mr in number, p_mv in out number, p_name in out varchar2);
  function  agrmnt_can (p_rowid in varchar2, p_what in varchar2) return varchar2;   -- APPROVE | UNAPPROVE -> Y/N
  function  agrmnt_approve (p_rowid in varchar2) return varchar2;
  function  agrmnt_unapprove (p_rowid in varchar2) return varchar2;
  function  agrmnt_copy (p_rowid in varchar2, p_kind in number, p_cntrct in number, p_end in date) return varchar2;
  function  agrmnt_load_items (p_rowid in varchar2) return varchar2;

  -- ------------------------------------------------------------------ ST_PO_ITEM_SUPP (preparing purchase orders)
  procedure prep_det_row (p_inserting in boolean, p_serial in number,
                          p_group in out number, p_item in varchar2, p_supp in out number, p_kind in out number,
                          p_qty in number, p_old_qty in number, p_chk in out number,
                          p_price in out number, p_old_price in number,
                          p_pct in out number, p_old_pct in number, p_bonus in out number, p_old_bonus in number,
                          p_xpct in out number, p_old_xpct in number, p_xbonus in out number, p_old_xbonus in number,
                          p_d1r in out number, p_o_d1r in number, p_d1v in out number, p_o_d1v in number,
                          p_d2r in out number, p_o_d2r in number, p_d2v in out number, p_o_d2v in number,
                          p_mr in number, p_mv in out number, p_por in number, p_pov in out number);
  function  prep_validate (p_request in varchar2, p_rowid in varchar2, p_from in varchar2, p_to in varchar2,
                           p_po_supp in varchar2, p_po_store in varchar2, p_pr_order_type in varchar2) return varchar2;
  function  prep_get_items (p_rowid in varchar2) return varchar2;
  function  prep_mark (p_rowid in varchar2, p_what in varchar2) return varchar2;     -- ALL | NONE | ZERO
  function  prep_load_excel (p_rowid in varchar2, p_file in varchar2) return varchar2;
  function  prep_load_blob (p_rowid in varchar2, p_blob in blob, p_name in varchar2) return varchar2;
  function  prep_can_order (p_rowid in varchar2) return varchar2;
  function  prep_make_order (p_rowid in varchar2, p_order_type in number, p_date in date) return varchar2;

  -- ------------------------------------------------------------------ ST_RETURN_AUTH_COST2
  procedure auth_mast_row (p_inserting in boolean, p_type in number, p_date in out date, p_date_serial in out number,
                           p_store in out number, p_supplier in number, p_currency in out number, p_rate in out number,
                           p_delete_flag in out number, p_post_flag in out number, p_old_post_flag in number,
                           p_approve in out number, p_old_approve in number, p_approve_date in out date, p_approve_user in out number,
                           p_approve2 in out number, p_old_approve2 in number, p_approve2_date in out date, p_approve2_user in out number,
                           p_invoice_no in out varchar2, p_serial in number);
  procedure auth_det_row (p_inserting in boolean, p_type in number, p_serial in number,
                          p_group in out number, p_item in varchar2, p_unit in out number, p_confg in number,
                          p_qty in number, p_old_qty in number,
                          p_bonus_ratio in out number, p_old_bonus_ratio in number, p_bonus in out number, p_old_bonus in number,
                          p_xratio in out number, p_old_xratio in number, p_xbonus in out number, p_old_xbonus in number,
                          p_price_curr in out number, p_old_price_curr in number, p_price in out number,
                          p_d1r in out number, p_o_d1r in number, p_d1v in out number, p_o_d1v in number,
                          p_d2r in out number, p_o_d2r in number, p_d2v in out number, p_o_d2v in number,
                          p_d3r in out number, p_o_d3r in number, p_d3v in out number, p_o_d3v in number,
                          p_basic_qty in out number, p_store in out number, p_date in out date, p_date_serial in out number,
                          p_delete_flag in out number, p_cost_flag in out number);
  function  auth_validate (p_request in varchar2, p_rowid in varchar2, p_type in varchar2, p_date in varchar2,
                           p_store in varchar2, p_currency in varchar2, p_rate in varchar2, p_doc_no in varchar2,
                           p_acc1 in varchar2, p_acc2 in varchar2, p_acc3 in varchar2, p_acc4 in varchar2,
                           p_values in varchar2) return varchar2;
  function  auth_warning (p_supplier in varchar2) return varchar2;
  procedure auth_after_save (p_request in varchar2, p_rowid in varchar2);
  procedure auth_after_delete (p_type in varchar2, p_serial in varchar2);
  function  auth_can (p_rowid in varchar2, p_what in varchar2) return varchar2;      -- CONVERT | CANCEL -> Y/N
  function  auth_convert (p_rowid in varchar2) return varchar2;
  function  auth_cancel (p_rowid in varchar2) return varchar2;

end app_rules3_pr;
/
show errors package app_rules3_pr

create or replace package body app_rules3_pr as

  g_page    number := -1;
  g_form    varchar2(100);
  g_action  boolean := false;
  g_msg     varchar2(4000);

  -- ================================================================== common helpers
  function m (p_a in varchar2, p_e in varchar2 default null) return varchar2 is
  begin
    return case when v('G_LANG') = 'en' and p_e is not null then p_e else p_a end;
  end m;

  procedure err (p_code in pls_integer, p_a in varchar2, p_e in varchar2 default null) is
  begin
    raise_application_error(p_code, m(p_a, p_e));
  end err;

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

  function to_d (p in varchar2) return date is
  begin
    if p is null then return null; end if;
    return nvl(to_date(p default null on conversion error, 'DD/MM/YYYY'),
               to_date(p default null on conversion error, 'YYYY-MM-DD'));
  end to_d;

  function to_n (p in varchar2) return number is
  begin
    if p is null then return null; end if;
    return to_number(replace(p, ',') default null on conversion error);
  end to_n;

  function pw return number is begin return nvl(to_n(v('G_PASSWORD_NUMBER')), 0); end;
  function usr return number is begin return to_n(v('G_USER_CODE')); end;

  function chg (p_new in number, p_old in number) return number is
  begin
    return case when (p_new is null and p_old is null) or p_new = p_old then 0 else 1 end;
  end chg;
  function chg (p_new in varchar2, p_old in varchar2) return number is
  begin
    return case when (p_new is null and p_old is null) or p_new = p_old then 0 else 1 end;
  end chg;
  function chg (p_new in date, p_old in date) return number is
  begin
    return case when (p_new is null and p_old is null) or p_new = p_old then 0 else 1 end;
  end chg;

  function user_flag (p_col in varchar2) return number is
    l number;
  begin
    execute immediate 'select nvl(max(' || dbms_assert.simple_sql_name(p_col) || '), 0) from users where users_code = :u'
      into l using usr;
    return l;
  end user_flag;

  function st_min_date return date is
    l date;
  begin
    select min(min_date) into l from st_basic;
    return nvl(l, to_date('01-01-' || (to_number(to_char(sysdate, 'YYYY')) - 1), 'DD-MM-YYYY'));
  end st_min_date;

  function date_error (p_date in date) return varchar2 is
  begin
    if p_date is null then return null; end if;
    if trunc(p_date) > trunc(sysdate) then
      return m('تاريخ الحركة أكبر من تاريخ اليوم', 'Transaction Date is greater than today''s date');
    end if;
    if trunc(p_date) < trunc(st_min_date) then
      return m('الحد الأدنى لتاريخ الحركة هو ' || to_char(st_min_date, 'DD/MM/YYYY'),
               'The least value accepted for Transaction Date is ' || to_char(st_min_date, 'DD/MM/YYYY'));
    end if;
    return null;
  end date_error;

  function type_is (p_type in number, p_effect in number, p_trns_type in number) return number is
    l number;
  begin
    select count(*) into l from st_trns_type
     where trns_type_code = p_type and effect = p_effect and (p_trns_type is null or trns_type = p_trns_type);
    return case when l > 0 then 1 else 0 end;
  end type_is;

  function store_ok (p_store in number) return number is
    l number;
  begin
    select count(*) into l from st_store s
     where s.store_code = p_store and nvl(s.store_status, 0) = 1 and nvl(s.stop_flag, 0) = 0
       and (pw = 0 or s.store_code in (select p.store_code from st_store_password p where p.password_number = pw));
    return case when l > 0 then 1 else 0 end;
  end store_ok;

  function in_list (p_label_a in varchar2, p_label_e in varchar2) return varchar2 is
  begin
    return m('القيمة غير موجودة فى القائمة: ' || p_label_a, 'The value is not in the list: ' || p_label_e);
  end in_list;

  procedure set_action (p_on in boolean) is begin g_action := p_on; end;
  function in_action return boolean is begin return g_action; end;

  function last_message return varchar2 is begin return g_msg; end;

  -- ================================================================== code tables
  -- LC_PAY_COND (30/16): number > 0, no duplicate, no delete while LC_CREDIT / LC_CREDIT_OPEN use it
  procedure pay_cond_row (p_inserting in boolean, p_code in number) is
    l number;
  begin
    if nvl(p_code, 0) <= 0 then
      err(-20150, 'رقم طريقة الدفع يجب ان يكون اكبر من الصفر', 'The payment method number must be greater than zero');
    end if;
    if p_inserting then
      select count(1) into l from lc_pay_cond where pay_cond_code = p_code;
      if l > 0 then err(-20151, 'رقم مكرر تم إدخالة من قبل', 'Duplicate number, it was entered before'); end if;
    end if;
  end pay_cond_row;

  procedure pay_cond_delete (p_code in number) is
    l number;
  begin
    select count(1) into l from lc_credit where pay_cond_code = p_code;
    if l > 0 then
      err(-20152, 'لا يمكن حذف السجل التالى لوجود ارتباط مع ملف الاعتماد الرئيسي',
          'The record cannot be deleted: it is used by the letters of credit file');
    end if;
    select count(1) into l from lc_credit_open where pay_cond_code = p_code;
    if l > 0 then
      err(-20152, 'لا يمكن حذف السجل التالى لوجود ارتباط مع ملف فتح الاعتماد',
          'The record cannot be deleted: it is used by the letter of credit opening file');
    end if;
  end pay_cond_delete;

  -- LC_PAY_CREDIT_COND (30/17)
  procedure credit_cond_row (p_inserting in boolean, p_code in number) is
    l number;
  begin
    if nvl(p_code, 0) <= 0 then
      err(-20150, 'رقم طريقة شرط الدفع يجب ان يكون اكبر من الصفر', 'The payment condition number must be greater than zero');
    end if;
    if p_inserting then
      select count(1) into l from lc_pay_credit_cond where cond_no = p_code;
      if l > 0 then err(-20151, 'لا يمكن تكرار رقم شرط الدفع', 'The payment condition number cannot be repeated'); end if;
    end if;
  end credit_cond_row;

  procedure credit_cond_delete (p_code in number) is
    l number;
  begin
    select count(1) into l from lc_credit_pay_cond where cond_no = p_code;
    if l > 0 then
      err(-20152, 'لا يمكن حذف السجل التالى لوجود ارتباط مع شروط الدفع فى ملف الاعتماد الرئيسي',
          'The record cannot be deleted: it is used by the payment conditions of a letter of credit');
    end if;
  end credit_cond_delete;

  -- ST_TERM_SHIP (30/18): numbering max + 1 (generated key), no delete while a purchase order uses it
  procedure term_ship_row (p_inserting in boolean, p_code in number) is
    l number;
  begin
    if p_inserting then
      select count(1) into l from st_term_ship where term_ship_code = p_code;
      if l > 0 then err(-20151, 'رقم مكرر تم إدخالة من قبل', 'Duplicate number, it was entered before'); end if;
    end if;
  end term_ship_row;

  procedure term_ship_delete (p_code in number) is
    l number;
  begin
    select count(1) into l from pr_order where term_ship_code = p_code;
    if l > 0 then
      err(-20152, 'تم تخصيص هذا الرقم  مع أمر شراء  أو أكثر' || chr(10) || 'لا يمكن حذفها حالياً.',
          'This number is used by one or more purchase orders; it cannot be deleted.');
    end if;
  end term_ship_delete;

  -- LC_PORT (30/19)
  procedure port_row (p_inserting in boolean, p_code in number) is
    l number;
  begin
    if nvl(p_code, 0) <= 0 then
      err(-20150, 'رقم الميناء يجب ان يكون اكبر من الصفر', 'The port number must be greater than zero');
    end if;
    if p_inserting then
      select count(1) into l from lc_port where port_code = p_code;
      if l > 0 then err(-20151, 'رقم مكرر تم إدخالة من قبل', 'Duplicate number, it was entered before'); end if;
    end if;
  end port_row;

  procedure port_delete (p_code in number) is
    l number;
  begin
    select count(1) into l from lc_credit where port_code = p_code;
    if l > 0 then
      err(-20152, 'لا يمكن حذف الميناء التالى لوجود ارتباط مع ملف الاعتماد الرئيسى',
          'The port cannot be deleted: it is used by the letters of credit file');
    end if;
    select count(1) into l from lc_credit_open where port_code = p_code;
    if l > 0 then
      err(-20152, 'لا يمكن حذف الميناء التالى لوجود ارتباط مع ملف فتح الاعتماد',
          'The port cannot be deleted: it is used by the letter of credit opening file');
    end if;
  end port_delete;

  -- ST_CNTRCT_TYPES (30/38): numbering max + 1 (generated key), a name is required, no duplicate,
  -- no delete while a supplier agreement uses the type
  procedure cntrct_row (p_inserting in boolean, p_code in number, p_name_a in varchar2, p_name_e in varchar2) is
    l number;
  begin
    if p_name_a is null and p_name_e is null then
      err(-20153, 'يجب ادخال الأسم عربى أو لاتينى', 'The Arabic or the English name must be entered');
    end if;
    if p_inserting then
      select count(1) into l from st_cntrct_types where cntrct_code = p_code;
      if l > 0 then err(-20151, 'هذا السجل تم ادخاله من قبل ... رقم مكرر', 'This record was entered before (duplicate number)'); end if;
    end if;
  end cntrct_row;

  procedure cntrct_delete (p_code in number) is
    l number;
  begin
    select count(cntrct_code) into l from st_supp_agrmnt where cntrct_code = p_code;
    if l > 0 then
      err(-20152, 'تم استخدام هذه  الماركة فى النظام' || chr(10) || 'لا يمكن حذفه حالياً.',
          'This contract type is used by a supplier agreement; it cannot be deleted.');
    end if;
  end cntrct_delete;

  -- ST_PR_ORDER_TYPES (30/42): number > 0, no duplicate, a name is required, the purchase transaction must be a
  -- purchase-invoice type (legacy LOV: EFFECT = 1 AND TRNS_TYPE = 1)
  procedure pr_order_type_row (p_inserting in boolean, p_serial in number, p_name_a in varchar2, p_name_e in varchar2,
                               p_trns_type in number) is
    l number;
  begin
    if nvl(p_serial, 0) <= 0 then
      err(-20150, 'قم بادخال رقم اكبر من الصفر', 'Enter a number greater than zero');
    end if;
    if p_inserting then
      select count(1) into l from st_pr_order_types where serial = p_serial;
      if l > 0 then err(-20151, 'هذا الكود موجود من قبل', 'This code already exists'); end if;
    end if;
    if p_name_a is null and p_name_e is null then
      err(-20153, 'يجب ادخال الأسم عربى أو لاتينى', 'The Arabic or the English name must be entered');
    end if;
    if p_trns_type is not null and type_is(p_trns_type, 1, 1) = 0 then
      err(-20154, in_list('كود حركة المشتريات', 'purchase transaction code'));
    end if;
  end pr_order_type_row;

  -- ST_PERIODS (30/27, 31/12)
  function next_period_code return number is
    l number;
  begin
    select nvl(max(period_code), 0) + 1 into l from st_periods;
    return l;
  end next_period_code;

  procedure period_row (p_inserting in boolean, p_code in number, p_from in date, p_till in date) is
    l number;
  begin
    if p_code < 0 then
      err(-20150, 'رقم الفترة لا يمكن أن يكون أقل من الصفر', 'The period number cannot be less than zero');
    end if;
    if p_inserting then
      select count(1) into l from st_periods where period_code = p_code;
      if l > 0 then err(-20151, 'كود مكرر', 'Duplicate code'); end if;
    end if;
    if p_from is not null and p_till is not null and trunc(p_from) >= trunc(p_till) then
      err(-20155, 'يجب ان يكون من تاريخ اصغر من الى تاريخ', 'The from date must be earlier than the to date');
    end if;
    if (p_from is not null and trunc(p_from) < trunc(st_min_date)) or (p_till is not null and trunc(p_till) < trunc(st_min_date)) then
      err(-20155, 'التاريخ أقل من الحد الأدنى المسموح به', 'The date is before the minimum allowed date');
    end if;
    if (p_from is not null and p_from > add_months(sysdate, 24)) or (p_till is not null and p_till > add_months(sysdate, 24)) then
      err(-20155, 'تاريخ الفترة أكبر من المسموح بة', 'The period date is later than allowed');
    end if;
  end period_row;

  procedure period_overlap (p_code in number) is
    l_from date;
    l_till date;
    l      number;
  begin
    begin
      select from_date, till_date into l_from, l_till from st_periods where period_code = p_code;
    exception when no_data_found then return;
    end;
    -- legacy: SELECT COUNT(1) FROM ST_PERIODS WHERE (:from BETWEEN FROM_DATE AND TILL_DATE OR :to BETWEEN FROM_DATE AND TILL_DATE)
    -- (a new period that encloses an existing one is not caught by the legacy check; kept as is)
    select count(1) into l from st_periods
     where period_code <> p_code
       and (l_from between from_date and till_date or l_till between from_date and till_date);
    if l > 0 then
      err(-20156, 'يوجد تقاطع فى نطاق التواريخ مع نطاق أخر', 'The date range overlaps another period');
    end if;
  end period_overlap;

  -- ================================================================== ST_PU_SERVICES (30/39): services chart
  -- A service code has 12 digits; its level is the first ST_CHART_SERVICES level after whose last position
  -- (CHR_STRU_END) the code only has zeros; the parent is the code cut after the previous level's last position
  -- (legacy SELECT SERVICE_CODE ... WHERE RPAD(SUBSTR(SERVICE_CODE,1,:end),12,'0') = :parent AND SERVICE_LEVEL = :lvl).
  function service_level (p_code in number) return number is
    l_code varchar2(40) := to_char(p_code);
  begin
    if p_code is null or p_code <= 0 or length(l_code) <> 12 or p_code <> trunc(p_code) then
      err(-20157, 'خطأ فى رقم الخدمة', 'Invalid service number');
    end if;
    for r in (select chr_stru_level lvl, chr_stru_end e from st_chart_services order by chr_stru_level) loop
      if r.e >= 12 or rtrim(substr(l_code, r.e + 1), '0') is null then
        return r.lvl;
      end if;
    end loop;
    err(-20157, 'مستوى الخدمة غير معروف', 'Unknown service level');
    return null;
  end service_level;

  function service_parent (p_code in number, p_level in number) return number is
    l_end number;
  begin
    select max(chr_stru_end) into l_end from st_chart_services
     where chr_stru_level = (select max(chr_stru_level) from st_chart_services where chr_stru_level < p_level);
    if l_end is null then return null; end if;
    return to_number(rpad(substr(to_char(p_code), 1, l_end), 12, '0'));
  end service_parent;

  function service_used (p_code in number) return number is
    l number;
  begin
    select (select count(1) from st_item_req_srvc where service_code = p_code)
         + (select count(1) from pr_order_srvc_request where service_code = p_code)
         + (select count(1) from st_trns_srvc_request where service_code = p_code)
         + (select count(1) from pr_order_srvc where service_code = p_code)
         + (select count(1) from pr_req_srvc where service_code = p_code)
         + (select count(1) from pr_income_lot_srvc where service_code = p_code)
      into l from dual;
    return l;
  end service_used;

  procedure service_row (p_inserting in boolean, p_code in number, p_level in out number, p_leaf in out number,
                         p_account in number) is
    l      number;
    l_par  number;
    l_plvl number;
    l_min  number;
  begin
    if p_account is not null then
      select count(1) into l from ac_master where account_number = p_account and account_status = 1;
      if l = 0 then err(-20154, in_list('رقم الحساب', 'account number')); end if;
    end if;
    if not p_inserting then return; end if;
    select count(1), min(chr_stru_level) into l, l_min from st_chart_services;
    if l = 0 then
      err(-20157, 'لابد من إدخال هيكل الخدمات أولا', 'The services chart structure must be entered first');
    end if;
    p_level := service_level(p_code);
    p_leaf  := 1;
    select count(1) into l from st_pu_services where service_code = p_code;
    if l > 0 then err(-20151, 'يوجد خدمة بنفس الرقم بالملف', 'A service with the same number already exists'); end if;
    if p_level > l_min then
      l_par := service_parent(p_code, p_level);
      select max(service_level) into l_plvl from st_pu_services where service_code = l_par;
      if l_plvl is null then
        err(-20157, 'لا يوجد خدمة رئيسى لهذا الرقم', 'There is no parent service for this number');
      end if;
      if service_used(l_par) > 0 then
        err(-20157, 'تم عمل حركات على الخدمة الرئيسى', 'The parent service is already used in transactions');
      end if;
    end if;
  end service_row;

  procedure service_after_insert (p_code in number, p_level in number) is
    l_par number;
  begin
    if p_level is null then return; end if;
    l_par := service_parent(p_code, p_level);
    if l_par is not null then
      update st_pu_services set leaf = 0 where service_code = l_par and nvl(leaf, 1) <> 0;
    end if;
  end service_after_insert;

  procedure service_before_delete (p_code in number) is
  begin
    if service_used(p_code) > 0 then
      err(-20152, 'لايمكن حذف خدمه تم عمل حركات عليها', 'A service used in transactions cannot be deleted');
    end if;
  end service_before_delete;

  procedure service_after_delete (p_code in number, p_level in number) is
    l_end number;
    l     number;
    l_par number;
  begin
    if p_level is null then return; end if;
    select max(chr_stru_end) into l_end from st_chart_services where chr_stru_level = p_level;
    if l_end is not null and l_end < 12 then
      select count(1) into l from st_pu_services
       where service_code <> p_code and service_level > p_level
         and substr(to_char(service_code), 1, l_end) = substr(to_char(p_code), 1, l_end);
      if l > 0 then
        err(-20152, 'يوجد خدمات فرعية لهذه الخدمة لذلك لايمكنك الحذف', 'The service has sub-services and cannot be deleted');
      end if;
    end if;
    l_par := service_parent(p_code, p_level);
    if l_par is not null then
      select max(chr_stru_end) into l_end from st_chart_services
       where chr_stru_level = (select max(chr_stru_level) from st_chart_services where chr_stru_level < p_level);
      select count(1) into l from st_pu_services
       where service_code <> l_par and substr(to_char(service_code), 1, l_end) = substr(to_char(l_par), 1, l_end)
         and service_level > (select service_level from st_pu_services where service_code = l_par);
      if l = 0 then
        update st_pu_services set leaf = 1 where service_code = l_par and nvl(leaf, 0) <> 1;
      end if;
    end if;
  end service_after_delete;

  -- ================================================================== ST_TRNS_TYPE (30/22) and ST_TRNS_TYPE_SL (31/18)
  function trns_type_check (
    p_form      in varchar2, p_request   in varchar2, p_rowid     in varchar2,
    p_code      in varchar2, p_effect    in varchar2, p_trns_type in varchar2, p_store   in varchar2,
    p_join      in varchar2, p_post      in varchar2, p_entry     in varchar2,
    p_cust      in varchar2, p_cust_pay  in varchar2, p_supp      in varchar2, p_supp_pay in varchar2,
    p_rp        in varchar2, p_pc        in varchar2,
    p_pr        in varchar2 default null, p_pu      in varchar2 default null, p_quot    in varchar2 default null,
    p_supp_disc in varchar2 default null,
    p_sales     in varchar2 default null, p_sales_order in varchar2 default null, p_reserve in varchar2 default null,
    p_delivery  in varchar2 default null, p_tfrom   in varchar2 default null, p_tto     in varchar2 default null,
    p_ctgry     in varchar2 default null) return varchar2 is
    l_code   number := to_n(p_code);
    l_effect number := to_n(p_effect);
    l_type   number := to_n(p_trns_type);
    l_store  number := to_n(p_store);
    l        number;
    l_old_e  number;
    l_old_t  number;
    function linked (p_val in varchar2, p_eff in number, p_tt in number, p_same_store in boolean) return boolean is
      l_n    number;
      l_same number := case when p_same_store then 1 else 0 end;
    begin
      if p_val is null then return true; end if;
      select count(1) into l_n from st_trns_type
       where trns_type_code = to_n(p_val) and effect = p_eff and (p_tt is null or trns_type = p_tt)
         and (l_same = 0 or l_store is null or store_code = l_store);
      return l_n > 0;
    end linked;
  begin
    if l_code is null then
      return m('أدخل كود للحركة', 'Enter a transaction code');
    end if;
    if p_request = 'CREATE' then
      if p_form = 'ST_TRNS_TYPE' and (l_code < 1 or l_code > 999999) then
        return m('رقم نوع الحركة يجب ان يكون فى المدي من 1 و 999999', 'The transaction type number must be between 1 and 999999');
      elsif l_code <= 0 then
        return m('المسلسل يجب ان يكون اكبر من الصفر', 'The number must be greater than zero');
      end if;
      select count(1) into l from st_trns_type where trns_type_code = l_code;
      if l > 0 then return m('هذا الكود موجود من قبل', 'This code already exists'); end if;
    end if;
    -- stock effect / transaction kind of this screen (legacy radio groups and block WHERE clause)
    if l_effect is null or l_type is null
       or (p_form = 'ST_TRNS_TYPE'
           and not ((l_type in (1, 3, 12, 9, 13, 14, 15, 25, 5) and l_effect in (3, 7)) or (l_type = 1 and l_effect = 1)))
       or (p_form = 'ST_TRNS_TYPE_SL' and l_effect not in (2, 4, 7)) then
      return m('التأثير على المخزون / نوع الحركة غير مسموح به فى هذه الشاشة',
               'The stock effect / transaction kind is not allowed on this screen');
    end if;
    if p_request = 'SAVE' and p_rowid is not null then
      select effect, trns_type into l_old_e, l_old_t from st_trns_type where rowid = chartorowid(p_rowid);
      if chg(l_old_e, l_effect) + chg(l_old_t, l_type) > 0 then
        select (select count(1) from st_trns_mast where trns_type_code = l_code)
             + (select count(1) from st_sales_order where trns_type_code = l_code)
             + (select count(1) from st_proposal_mast where trns_type_code = l_code)
             + (select count(1) from pr_order where trns_type_code = l_code)
          into l from dual;
        if l > 0 then
          return m('لا يمكن تعديل التأثير على المخزون أو نوع الحركة لوجود حركات مسجلة على هذا النوع',
                   'The stock effect or kind cannot change: documents of this type exist');
        end if;
      end if;
    end if;
    if l_store is not null and store_ok(l_store) = 0 then
      return in_list('المخزن الأساسى للحركة', 'basic store of the transaction');
    end if;
    if to_n(p_join) not in (1, 2, 3, 4) then
      return in_list('الربط بالأنظمة الأخرى', 'link to the other systems');
    end if;
    if to_n(p_post) not in (1, 2) then
      return in_list('نوع الترحيل', 'posting type');
    end if;
    if p_entry is not null then
      select count(1) into l from ac_trn_codes where entry_type = to_n(p_entry);
      if l = 0 then return in_list('رقم الحركة ببرنامج الحسابات', 'transaction number in the GL system'); end if;
    end if;
    if p_cust is not null then
      select count(1) into l from ar_trnstype where id = to_n(p_cust);
      if l = 0 then return in_list('رقم الحركة ببرنامج العملاء', 'transaction number in the AR system'); end if;
    end if;
    if p_cust_pay is not null then
      select count(1) into l from ar_trnstype where id = to_n(p_cust_pay);
      if l = 0 then return in_list('حركة السداد ببرنامج العملاء', 'payment transaction in the AR system'); end if;
    end if;
    if p_supp is not null then
      select count(1) into l from vn_trnstype where id = to_n(p_supp);
      if l = 0 then return in_list('رقم الحركة ببرنامج الموردين', 'transaction number in the AP system'); end if;
    end if;
    if p_supp_pay is not null then
      select count(1) into l from vn_trnstype where id = to_n(p_supp_pay);
      if l = 0 then return in_list('حركة السداد ببرنامج الموردين', 'payment transaction in the AP system'); end if;
    end if;
    if p_supp_disc is not null then
      select count(1) into l from vn_trnstype where id = to_n(p_supp_disc) and effect = 0 and trns_type = 4;
      if l = 0 then return in_list('حركة الحسابات لخصم المورد', 'supplier discount transaction'); end if;
    end if;
    if p_rp is not null then
      select count(1) into l from rp_trns_type where trns_type_code = to_n(p_rp) and nvl(stop_flag, 0) = 0;
      if l = 0 then return in_list('حركة الصندوق', 'cash box transaction'); end if;
    end if;
    if p_pc is not null then
      select count(1) into l from check_trns_type where trns_type_code = to_n(p_pc) and nvl(stop_flag, 0) = 0;
      if l = 0 then return in_list('حركة البنك', 'bank transaction'); end if;
    end if;
    if not linked(p_pr, 7, 14, false) then return in_list('حركة أمر الشراء', 'purchase order transaction'); end if;
    if not linked(p_pu, 1, 1, false) then return in_list('رقم حركة المشتريات', 'purchase transaction'); end if;
    if not linked(p_quot, 7, 25, false) then return in_list('حركة طلب عرض الاسعار', 'request for quotation transaction'); end if;
    if not linked(p_sales, 2, null, true) then return in_list('رقم حركة فاتورة المبيعات', 'sales invoice transaction'); end if;
    if not linked(p_sales_order, 7, 30, false) then return in_list('حركة أمر البيع', 'sales order transaction'); end if;
    if not linked(p_reserve, 2, 17, true) then return in_list('حركة حجز البضاعة', 'goods reservation transaction'); end if;
    if not linked(p_delivery, 7, 31, true) then return in_list('حركة مذكرة التسليم', 'delivery note transaction'); end if;
    if not linked(p_tfrom, 5, 9, false) then return in_list('حركة التحويل الصادر', 'issue transfer transaction'); end if;
    if not linked(p_tto, 6, 9, false) then return in_list('حركة استلام التحويل', 'transfer receipt transaction'); end if;
    if p_ctgry is not null then
      select count(1) into l from st_category_type where category_type_code = to_n(p_ctgry);
      if l = 0 then return in_list('القسم', 'department'); end if;
    end if;
    return null;
  end trns_type_check;

  -- STACLNK posting lines of a type: the legacy LOVs only offer detail accounts (ACCOUNT_STATUS = 1) and active cost
  -- centres (COST_STATUS = 1)
  procedure staclnk_after_save (p_request in varchar2, p_code in varchar2) is
  begin
    if p_request not in ('CREATE', 'SAVE') then return; end if;
    for r in (select l.entry_no, l.entry_serial_no, l.account_no, l.cost_no, l.cost_no2,
                     (select count(1) from ac_master a where a.account_number = l.account_no and a.account_status = 1) acc_ok,
                     (select count(1) from ac_cost_centers c where c.cost_code = l.cost_no and c.cost_status = 1) c1_ok,
                     (select count(1) from ac_cost_centers2 c where c.cost_code = l.cost_no2 and c.cost_status = 1) c2_ok
                from staclnk l where l.trns_type_code = to_n(p_code)) loop
      if r.account_no is not null and r.acc_ok = 0 then
        err(-20158, 'رقم الحساب ' || r.account_no || ' غير موجود أو ليس على أدنى مستوى (القيد ' || r.entry_no || '/' || r.entry_serial_no || ')',
            'Account ' || r.account_no || ' does not exist or is not a detail account (entry ' || r.entry_no || '/' || r.entry_serial_no || ')');
      end if;
      if r.cost_no is not null and r.c1_ok = 0 then
        err(-20158, in_list('مركز التكلفة 1 (' || r.cost_no || ')', 'cost centre 1 (' || r.cost_no || ')'));
      end if;
      if r.cost_no2 is not null and r.c2_ok = 0 then
        err(-20158, in_list('مركز التكلفة 2 (' || r.cost_no2 || ')', 'cost centre 2 (' || r.cost_no2 || ')'));
      end if;
    end loop;
  end staclnk_after_save;

  procedure trns_type_delete (p_code in number) is
    l      number;
    l_form varchar2(100) := cur_form;
  begin
    if nvl(l_form, '#') not in ('ST_TRNS_TYPE', 'ST_TRNS_TYPE_SL') then return; end if;
    select count(1) into l from st_trns_mast where trns_type_code = p_code;
    if l = 0 and l_form = 'ST_TRNS_TYPE_SL' then
      select count(1) into l from st_sales_order where trns_type_code = p_code;
    end if;
    if l > 0 then
      err(-20152, 'لا يمكن حذف السجل حيث توجد حركات معتمدة عليه بالنظام',
          'The record cannot be deleted: transactions depend on it');
    end if;
  end trns_type_delete;

  -- legacy copy button (CTRL.NEW_TRNS_TYPE_CODE + PUSH_BUTTON419): the type and its STACLNK lines under a new number
  function copy_trns_type (p_form in varchar2, p_rowid in varchar2, p_new_code in number) return varchar2 is
    l_src   st_trns_type%rowtype;
    l       number;
    l_rowid rowid;
    l_sfx_a varchar2(30) := case when p_form = 'ST_TRNS_TYPE' then ' - ' || 'منسوخ' end;
    l_sfx_e varchar2(30) := case when p_form = 'ST_TRNS_TYPE' then ' - ' || 'Copied' end;
  begin
    if p_new_code is null then
      err(-20159, 'يجب إدخال رقم الحركة الجديدة', 'The new transaction number must be entered');
    end if;
    select count(1) into l from st_trns_type where trns_type_code = p_new_code;
    if l > 0 then
      err(-20159, case when p_form = 'ST_TRNS_TYPE' then 'هذا الكود موجود من قبل' else 'رقم الحركة الجديد موجود بالفعل' end,
          'The new transaction number already exists');
    end if;
    select * into l_src from st_trns_type where rowid = chartorowid(p_rowid);
    insert into st_trns_type (trns_type_code, desc_a, desc_e, last_serial, effect, trns_type, join_type, has_salesman,
                              has_discount, has_freight, has_transport, has_custom, has_insurance, has_commission, has_others,
                              customer_trns_code, supplier_trns_code, entry_type, store_code, post_type,
                              customer_trns_pay_code, supplier_trns_pay_code)
    values (p_new_code, l_src.desc_a || l_sfx_a, l_src.desc_e || l_sfx_e, l_src.last_serial, l_src.effect, l_src.trns_type,
            l_src.join_type, l_src.has_salesman, l_src.has_discount, l_src.has_freight, l_src.has_transport, l_src.has_custom,
            l_src.has_insurance, l_src.has_commission, l_src.has_others, l_src.customer_trns_code, l_src.supplier_trns_code,
            l_src.entry_type, l_src.store_code, l_src.post_type, l_src.customer_trns_pay_code, l_src.supplier_trns_pay_code)
    returning rowid into l_rowid;
    insert into staclnk (entry_no, entry_serial_no, account_no_type, account_no, cost_no_type, cost_no, account_ind,
                         value_type, trns_type_code, cost_no2_type, cost_no2)
    select entry_no, entry_serial_no, account_no_type, account_no, cost_no_type, cost_no, account_ind,
           value_type, p_new_code, cost_no2_type, cost_no2
      from staclnk where trns_type_code = l_src.trns_type_code;
    g_msg := m('تم نقل الحركة', 'The transaction type was copied') || ' (' || p_new_code || ')';
    return rowidtochar(l_rowid);
  end copy_trns_type;

  -- ================================================================== ST_PROJ_EST (30/29)
  function next_est_serial (p_store in number) return number is
    l number;
  begin
    select nvl(max(trns_serial), 0) + 1 into l from st_proj_est_mast where store_code = p_store;
    return l;
  end next_est_serial;

  procedure est_mast_row (p_inserting in boolean, p_store in number, p_date in out date, p_date_serial in out number) is
  begin
    p_date := trunc(p_date);
    if p_inserting and p_date_serial is null then
      select nvl(max(date_serial), 0) + 1 into p_date_serial from st_proj_est_mast
       where store_code = p_store and est_date = p_date;
    end if;
  end est_mast_row;

  function est_validate (p_request in varchar2, p_rowid in varchar2, p_store in varchar2, p_date in varchar2) return varchar2 is
    l_store number := to_n(p_store);
    l_date  date := trunc(to_d(p_date));
    l       number;
  begin
    if p_request not in ('CREATE', 'SAVE') then return null; end if;
    if l_store is null then return m('ادخل رقم المخزن', 'Enter the store number'); end if;
    if p_request = 'CREATE' and store_ok(l_store) = 0 then
      return in_list('جهة / مخزن التقدير', 'estimation store');
    end if;
    if date_error(l_date) is not null then return date_error(l_date); end if;
    select count(1) into l from st_proj_est_mast
     where store_code = l_store and trunc(est_date) = l_date and (p_rowid is null or rowid <> chartorowid(p_rowid));
    if l > 0 then return m('المخزن الحالى موجود فى نفسي التاريخ', 'This store already has an estimate on this date'); end if;
    select count(1) into l from st_proj_est_mast
     where store_code = l_store and trunc(est_date) > l_date and (p_rowid is null or rowid <> chartorowid(p_rowid));
    if l > 0 then return m('تم عمل تقدير فى تاريخ أكبر من التاريخ الحالى', 'An estimate with a later date already exists'); end if;
    return null;
  end est_validate;

  procedure est_det_row (p_inserting in boolean, p_serial in number, p_store in number,
                         p_group in out number, p_item in varchar2, p_unit in out number,
                         p_qty in number, p_basic_qty in out number, p_color in number, p_size in number,
                         p_date_serial in out number) is
    l       number;
    l_req   number;
    l_cflag number;
    l_sflag number;
  begin
    if p_item is null then err(-20160, 'يجب إدخال الاصناف', 'The items must be entered'); end if;
    p_group := nvl(p_group, app_rules_pr.item_group(p_item));
    select count(1) into l from st_item where item_group_code = p_group and item_code = p_item and nvl(stop_flag, 0) = 0;
    if l = 0 then err(-20154, in_list('رقم الصنف ' || p_item, 'item ' || p_item)); end if;
    p_unit := nvl(p_unit, app_rules_pr.basic_unit(p_group, p_item));
    select count(1) into l from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit;
    if l = 0 then err(-20154, in_list('الوحدة', 'unit')); end if;
    if nvl(p_qty, 0) <= 0 then
      err(-20160, 'الكمية يجب أن تكون أكبر من الصفر', 'The quantity must be greater than zero');
    end if;
    p_basic_qty := p_qty * nvl(app_rules_pr.unit_factor(p_group, p_item, p_unit), 1);
    select nvl(max(b.color_flag), 0), nvl(max(b.size_flag), 0) into l_cflag, l_sflag from st_basic b;
    if l_cflag = 1 then
      select nvl(max(color_flag), 0) into l_cflag from st_item_group where item_group_code = p_group;
      if l_cflag = 1 and p_color is null then err(-20160, 'يجب ادخال اللون', 'The colour must be entered'); end if;
    end if;
    if l_sflag = 1 then
      select nvl(max(size_flag), 0) into l_sflag from st_item_group where item_group_code = p_group;
      if l_sflag = 1 and p_size is null then err(-20160, 'يجب ادخال المقاس', 'The size must be entered'); end if;
    end if;
    if p_inserting then
      select max(date_serial) into p_date_serial from st_proj_est_mast where trns_serial = p_serial and store_code = p_store;
    end if;
    -- legacy: the estimated quantity may not be below what the store already requested (ST_ITEM_REQ_DET)
    select nvl(sum(d.quantity), 0) into l_req
      from st_item_req_det d, st_item_req m
     where d.trns_type_code = m.trns_type_code and d.trns_serial = m.trns_serial and m.store_code = p_store
       and d.item_code = p_item and d.group_code = p_group and d.unit_code = p_unit
       and (p_color is null or d.color_code = p_color) and (p_size is null or d.size_code = p_size);
    if l_req > p_qty then
      err(-20160, 'إجمالى الكمية المطلوبة = ' || l_req || ' و لا يمكن ان يكون أكبر من الكمية المقدرة',
          'Total requested quantity = ' || l_req || ' and it cannot be greater than the estimated quantity');
    end if;
  end est_det_row;

  procedure est_after_save (p_request in varchar2, p_rowid in varchar2) is
    l_serial number;
    l_store  number;
    l        number;
    l_single number;
  begin
    if p_request not in ('CREATE', 'SAVE') or p_rowid is null then return; end if;
    select trns_serial, store_code into l_serial, l_store from st_proj_est_mast where rowid = chartorowid(p_rowid);
    select count(1) into l from st_proj_est_det where trns_serial = l_serial and store_code = l_store;
    if l = 0 then err(-20160, 'يجب إدخال الاصناف', 'The items must be entered'); end if;
    select nvl(max(single_item), 0) into l_single from st_basic;
    if l_single = 1 then
      select count(1) into l from (
        select group_code, item_code, color_code, size_code from st_proj_est_det
         where trns_serial = l_serial and store_code = l_store
         group by group_code, item_code, color_code, size_code having count(*) > 1);
      if l > 0 then err(-20160, 'هناك صنف مكرر', 'An item is repeated'); end if;
    end if;
  end est_after_save;

  procedure est_mast_delete (p_store in number) is
    l number;
  begin
    if nvl(cur_form, '#') <> 'ST_PROJ_EST' then return; end if;
    select count(1) into l from st_item_req where store_code = p_store;
    if l > 0 then
      err(-20152, 'طلب النواقص الحالي له طلب شراء او عروض أسعار مرتبطة و لا يمكن الحذف',
          'The store has material requests linked to this estimate; it cannot be deleted');
    end if;
    select count(1) into l from st_trns_mast_request where store_code = p_store;
    if l > 0 then
      err(-20152, 'طلب النواقص الحالي له طلب تحويل مرتبطة و لا يمكن الحذف',
          'The store has transfer requests linked to this estimate; it cannot be deleted');
    end if;
  end est_mast_delete;

  procedure est_det_delete (p_store in number, p_group in number, p_item in varchar2, p_color in number, p_size in number) is
    l number;
  begin
    if nvl(cur_form, '#') <> 'ST_PROJ_EST' then return; end if;
    select count(1) into l from st_item_req_det
     where group_code = p_group and item_code = p_item and (p_color is null or color_code = p_color)
       and (p_size is null or size_code = p_size)
       and (trns_type_code, trns_serial) in (select trns_type_code, trns_serial from st_item_req where store_code = p_store);
    if l > 0 then
      err(-20152, 'طلب النواقص الحالي له طلب شراء او عروض أسعار مرتبطة و لا يمكن الحذف',
          'The item was already requested by the store; it cannot be deleted');
    end if;
    select count(1) into l from st_trns_det_request
     where group_code = p_group and item_code = p_item and (p_color is null or color_code = p_color)
       and (p_size is null or size_code = p_size)
       and (trns_type_code, trns_serial) in (select trns_type_code, trns_serial from st_trns_mast_request where store_code = p_store);
    if l > 0 then
      err(-20152, 'طلب النواقص الحالي له طلب تحويل مرتبطة و لا يمكن الحذف',
          'The item already has transfer requests of the store; it cannot be deleted');
    end if;
  end est_det_delete;

  -- legacy button DROP_PRE_ITEM "إنزال أصناف اخر تقدير على المخزن": the lines of the store's latest earlier estimate
  function est_copy_last (p_rowid in varchar2) return varchar2 is
    l_m     st_proj_est_mast%rowtype;
    l_prev  number;
    l_n     number := 0;
    l_ser   number;
  begin
    select * into l_m from st_proj_est_mast where rowid = chartorowid(p_rowid);
    select max(trns_serial) into l_prev from st_proj_est_det
     where store_code = l_m.store_code and nvl(delete_flag, 0) = 0 and trns_serial < l_m.trns_serial;
    if l_prev is null then
      err(-20161, 'لا يوجد تقدير سابق لهذا المخزن', 'There is no earlier estimate for this store');
    end if;
    select nvl(max(item_serial), 0) into l_ser from st_proj_est_det where trns_serial = l_m.trns_serial and store_code = l_m.store_code;
    for r in (select d.* from st_proj_est_det d
               where d.store_code = l_m.store_code and d.trns_serial = l_prev and nvl(d.delete_flag, 0) = 0
                 and not exists (select 1 from st_proj_est_det x
                                  where x.store_code = l_m.store_code and x.trns_serial = l_m.trns_serial
                                    and x.group_code = d.group_code and x.item_code = d.item_code
                                    and nvl(x.color_code, -1) = nvl(d.color_code, -1) and nvl(x.size_code, -1) = nvl(d.size_code, -1))
               order by d.item_serial) loop
      l_ser := l_ser + 1;
      insert into st_proj_est_det (trns_serial, item_serial, quantity, basic_qty, delete_flag, date_serial, item_code,
                                   group_code, unit_code, store_code, size_code, color_code)
      values (l_m.trns_serial, l_ser, r.quantity, r.basic_qty, 0, l_m.date_serial, r.item_code,
              r.group_code, r.unit_code, l_m.store_code, r.size_code, r.color_code);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تم إنزال ' || l_n || ' صنف من التقدير رقم ' || l_prev, l_n || ' items copied from estimate ' || l_prev);
    return p_rowid;
  end est_copy_last;

  -- ================================================================== ST_SUPPLIER_AGREEMENT (30/37)
  function year_end return date is
  begin
    return to_date('31-12-' || to_char(sysdate, 'YYYY'), 'DD-MM-YYYY');
  end year_end;

  procedure agrmnt_row (p_inserting in boolean, p_approve in out number, p_old_approve in number,
                        p_end in date, p_old_end in date, p_stop in out number) is
  begin
    if g_action then return; end if;
    p_stop := nvl(p_stop, 0);
    if p_inserting then
      p_approve := 0;
      return;
    end if;
    -- the approval level only changes with the approve / cancel-approval buttons (actions of this page)
    p_approve := p_old_approve;
    if chg(p_end, p_old_end) = 1 and user_flag('EDIT_AGRMNT_DATE') <> 1 then
      err(-20162, 'لايوجد لديك صلاحية تعديل التاريخ', 'You are not allowed to change the date');
    end if;
  end agrmnt_row;

  function agrmnt_validate (p_request in varchar2, p_rowid in varchar2, p_kind in varchar2, p_cntrct in varchar2,
                            p_start in varchar2, p_end in varchar2) return varchar2 is
    l_start date := to_d(p_start);
    l_end   date := to_d(p_end);
    l       number;
  begin
    if p_request not in ('CREATE', 'SAVE') then return null; end if;
    if p_kind is null or p_cntrct is null or l_start is null or l_end is null then
      return m('يجب ادخال البيانات', 'The data must be entered') || ' (' || m('المصنع، نوع التعاقد، تاريخ التعاقد، حتي تاريخ', 'manufacturer, contract type, dates') || ')';
    end if;
    if l_end <= l_start then
      return m('يجب أن يكون توقيت الإنتهاء أكبر من توقيت البدء', 'The end date must be later than the start date');
    end if;
    select count(1) into l from st_supp_agrmnt
     where kind_code = to_n(p_kind) and cntrct_code = to_n(p_cntrct) and end_date >= l_start
       and (p_rowid is null or rowid <> chartorowid(p_rowid));
    if l > 0 then
      return m('يوجد تعاقد اخر لنفس المصنع مسجل علي نفس الفترة', 'Another agreement of the same manufacturer covers the same period');
    end if;
    return null;
  end agrmnt_validate;

  procedure agrmnt_supp_row (p_serial in number, p_supplier in number) is
    l number;
  begin
    if g_action or p_supplier is null then return; end if;
    select count(1) into l from supplier s
     where s.code = p_supplier and nvl(s.supplier_status, 0) = 1
       and (s.code in (select v.supp_code from vn_supp_kind v
                        where v.kind_code = (select a.kind_code from st_supp_agrmnt a where a.serial = p_serial))
            or not exists (select 1 from vn_supp_kind v
                            where v.kind_code = (select a.kind_code from st_supp_agrmnt a where a.serial = p_serial)));
    if l = 0 then err(-20154, in_list('المورد', 'supplier')); end if;
  end agrmnt_supp_row;

  procedure ratio_check (p_ratio in number) is
  begin
    if p_ratio is not null and (p_ratio < 0 or p_ratio >= 100) then
      err(-20163, 'أدخل رقم بقيمة تبدأ من الصفر و أقل من المئة', 'Enter a number from zero and less than one hundred');
    end if;
  end ratio_check;

  procedure value_check (p_value in number) is
  begin
    if p_value < 0 then
      err(-20163, 'ادخل قيمة اكبر من او تساوى صفر', 'Enter a value greater than or equal to zero');
    end if;
  end value_check;

  procedure agrmnt_det_row (p_inserting in boolean, p_serial in number,
                            p_group in out number, p_item in varchar2, p_unit in out number, p_supplier in out number,
                            p_qty in number, p_old_qty in number, p_basic_qty in out number,
                            p_price in out number, p_old_price in number,
                            p_bonus_ratio in out number, p_old_bonus_ratio in number, p_bonus in out number, p_old_bonus in number,
                            p_xratio in out number, p_old_xratio in number, p_xbonus in out number, p_old_xbonus in number,
                            p_d1r in out number, p_o_d1r in number, p_d1v in out number, p_o_d1v in number,
                            p_d2r in out number, p_o_d2r in number, p_d2v in out number, p_o_d2v in number,
                            p_d3r in out number, p_o_d3r in number, p_d3v in out number, p_o_d3v in number,
                            p_mr in number, p_mv in out number, p_name in out varchar2) is
    l      number;
    l_d3r  number := p_d3r;
    l_d3v  number := p_d3v;
    l_nm   varchar2(4000);
  begin
    if g_action then return; end if;
    if p_item is null then
      err(-20164, 'إختر صنف لهذا السجل أولاً', 'Select an item for this record first');
    end if;
    p_group := nvl(p_group, app_rules_pr.item_group(p_item));
    select count(1) into l from st_item i, st_item_unit u
     where i.item_group_code = p_group and i.item_code = p_item and nvl(i.stop_flag, 0) = 0
       and u.group_code = i.item_group_code and u.item_code = i.item_code and nvl(u.basic_unit, 0) = 1;
    if l = 0 then err(-20154, in_list('رقم الصنف ' || p_item, 'item ' || p_item)); end if;
    if p_inserting then
      select count(1) into l from st_supp_agrmnt_det where serial = p_serial and group_code = p_group and item_code = p_item;
      if l > 0 then err(-20151, 'صنف مكرر', 'The item is repeated'); end if;
      select max(i.name_e), max(i.supplier) into l_nm, l from st_item i where i.item_group_code = p_group and i.item_code = p_item;
      p_name := nvl(p_name, l_nm);
      p_supplier := nvl(p_supplier, l);
    end if;
    p_unit := nvl(p_unit, app_rules_pr.basic_unit(p_group, p_item));
    if p_price is null then
      select max(retail_sale_price) into p_price from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit;
    end if;
    if p_inserting and p_d1r is null and p_d1v is null then
      select max(moh_disc) into p_d1r from st_item where item_group_code = p_group and item_code = p_item;
    end if;
    value_check(p_qty); value_check(p_price); value_check(p_bonus); value_check(p_xbonus);
    ratio_check(p_bonus_ratio); ratio_check(p_xratio); ratio_check(p_d1r); ratio_check(p_d2r); ratio_check(p_d3r); ratio_check(p_mr);
    app_rules_pr.pair_ratio(p_inserting, p_qty, p_old_qty, p_bonus_ratio, p_old_bonus_ratio, p_bonus, p_old_bonus);
    app_rules_pr.pair_ratio(p_inserting, p_qty, p_old_qty, p_xratio, p_old_xratio, p_xbonus, p_old_xbonus);
    app_rules_pr.disc_chain(p_inserting, p_price, p_old_price, p_d1r, p_o_d1r, p_d1v, p_o_d1v,
                            p_d2r, p_o_d2r, p_d2v, p_o_d2v, l_d3r, p_o_d3r, l_d3v, p_o_d3v);
    p_d3r := l_d3r; p_d3v := l_d3v;
    if p_mr is not null then
      p_mv := round((nvl(p_price, 0) - nvl(p_d1v, 0) - nvl(p_d2v, 0)) * p_mr / 100, 4);
    end if;
    p_basic_qty := nvl(p_qty, 0) * nvl(app_rules_pr.unit_factor(p_group, p_item, p_unit), 1);
  end agrmnt_det_row;

  function agrmnt_can (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    l_a   st_supp_agrmnt%rowtype;
    l_lvl number := user_flag('SUPP_AGRMNT_APPROVAL');
    l     number;
  begin
    select * into l_a from st_supp_agrmnt where rowid = chartorowid(p_rowid);
    if p_what = 'APPROVE' then
      select count(1) into l from st_supp_agrmnt_det where serial = l_a.serial;
      return case when l > 0 and nvl(l_a.stop_flag, 0) = 0 and l_lvl between 1 and 3 and nvl(l_a.approve, 0) = l_lvl - 1
                  then 'Y' else 'N' end;
    else
      return case when nvl(l_a.approve, 0) > 0 and l_lvl > 0 then 'Y' else 'N' end;
    end if;
  exception when no_data_found then return 'N';
  end agrmnt_can;

  -- legacy "إعتماد": the users of approval level n (USERS.SUPP_AGRMNT_APPROVAL) approve the agreements at level n - 1
  function agrmnt_approve (p_rowid in varchar2) return varchar2 is
    l_a   st_supp_agrmnt%rowtype;
    l_lvl number := user_flag('SUPP_AGRMNT_APPROVAL');
  begin
    select * into l_a from st_supp_agrmnt where rowid = chartorowid(p_rowid) for update;
    if agrmnt_can(p_rowid, 'APPROVE') = 'N' then
      err(-20166, 'لا يمكنك إعتماد هذه الإتفاقية فى مستوى إعتمادها الحالى', 'You cannot approve this agreement at its current approval level');
    end if;
    g_action := true;
    update st_supp_agrmnt set approve = l_lvl where rowid = chartorowid(p_rowid);
    g_action := false;
    g_msg := m('تم الإعتماد', 'Approved') || ' (' || l_lvl || ')';
    return p_rowid;
  exception when others then g_action := false; raise;
  end agrmnt_approve;

  -- legacy "الغاء إعتماد": needs a level at least equal to the agreement's; refused once a purchase order used it
  function agrmnt_unapprove (p_rowid in varchar2) return varchar2 is
    l_a   st_supp_agrmnt%rowtype;
    l_lvl number := user_flag('SUPP_AGRMNT_APPROVAL');
    l     number;
  begin
    select * into l_a from st_supp_agrmnt where rowid = chartorowid(p_rowid) for update;
    if l_lvl < nvl(l_a.approve, 0) or l_lvl = 0 then
      err(-20166, 'تحتاج صلاحية أكبر لإلغاء هذا الإعتماد', 'You need a higher permission to cancel this approval');
    end if;
    select nvl(count(1), 0) into l from pr_order where agrmnt_no = l_a.serial;
    if l > 0 then
      err(-20166, 'لقد تم إستخدام هذه الإتفاقية فى أمر شراء', 'This agreement was used in a purchase order');
    end if;
    g_action := true;
    update st_supp_agrmnt set approve = 0 where rowid = chartorowid(p_rowid);
    g_action := false;
    g_msg := m('تم إلغاء الإعتماد', 'The approval was cancelled');
    return p_rowid;
  exception when others then g_action := false; raise;
  end agrmnt_unapprove;

  -- legacy "نسخ اتفاقية مورد": new serial, today as start date, new end date, contract type and manufacturer, not approved
  function agrmnt_copy (p_rowid in varchar2, p_kind in number, p_cntrct in number, p_end in date) return varchar2 is
    l_a     st_supp_agrmnt%rowtype;
    l_new   number;
    l       number;
    l_rowid rowid;
  begin
    select * into l_a from st_supp_agrmnt where rowid = chartorowid(p_rowid);
    if p_kind is null or p_cntrct is null or p_end is null then
      err(-20167, 'يجب ادخال البيانات', 'The data must be entered');
    end if;
    if p_end <= trunc(sysdate) then
      err(-20167, 'يجب أن يكون توقيت الإنتهاء أكبر من توقيت البدء', 'The end date must be later than the start date');
    end if;
    select count(1) into l from st_supp_agrmnt where kind_code = p_kind and cntrct_code = p_cntrct and end_date >= trunc(sysdate);
    if l > 0 then
      err(-20167, 'يوجد تعاقد اخر لنفس المصنع مسجل علي نفس الفترة', 'Another agreement of the same manufacturer covers the same period');
    end if;
    select nvl(max(serial), 0) + 1 into l_new from st_supp_agrmnt;
    g_action := true;
    insert into st_supp_agrmnt (serial, kind_code, start_date, end_date, contract_value, quarter_year_disc, end_year_disc, notes,
                                stop_flag, showrooms, approve, insert_user, half_year_disc, brand_code, cntrct_code, org_serial)
    values (l_new, p_kind, trunc(sysdate), p_end, l_a.contract_value, l_a.quarter_year_disc, l_a.end_year_disc,
            l_a.notes || ' - نسخ من مسلسل تعاقد ' || l_a.serial, l_a.stop_flag, l_a.showrooms, 0, usr, l_a.half_year_disc,
            l_a.brand_code, p_cntrct, l_a.serial)
    returning rowid into l_rowid;
    insert into st_supp_agrmnt_supp (serial, supplier_code) select l_new, supplier_code from st_supp_agrmnt_supp where serial = l_a.serial;
    insert into st_supp_agrmnt_det (serial, group_code, item_code, sales_price, disc_quarter, disc_end_year, ph_comm, prch_q_comm,
                                    prch_q_b_comm, sales_comm, rtrn_lmt, disc_half, purch_price, unit_code, quantity, bonus, basic_qty,
                                    disc1_ratio, disc2_ratio, disc1_value, disc2_value, bonus_ratio, extra_bonus_ratio, extra_bonus,
                                    p1_value, p2_value, p3_value, p4_value, p5_value, m_disc_ratio, m_disc_value, unit_cost_cstd,
                                    air_ship_price, lc_sea_price, lc_land_price, sea_ship_price, land_ship_price, org_serial,
                                    org_group_code, org_item_code, supplier_code, item_name_dummy)
    select l_new, group_code, item_code, sales_price, disc_quarter, disc_end_year, ph_comm, prch_q_comm, prch_q_b_comm, sales_comm,
           rtrn_lmt, disc_half, purch_price, unit_code, quantity, bonus, basic_qty, disc1_ratio, disc2_ratio, disc1_value, disc2_value,
           bonus_ratio, extra_bonus_ratio, extra_bonus, p1_value, p2_value, p3_value, p4_value, p5_value, m_disc_ratio, m_disc_value,
           unit_cost_cstd, air_ship_price, lc_sea_price, lc_land_price, sea_ship_price, land_ship_price, serial, group_code, item_code,
           supplier_code, item_name_dummy
      from st_supp_agrmnt_det where serial = l_a.serial;
    g_action := false;
    g_msg := m('تم اضافة مسلسل تعاقد ' || l_new, 'Agreement serial ' || l_new || ' was added');
    return rowidtochar(l_rowid);
  exception when others then g_action := false; raise;
  end agrmnt_copy;

  -- legacy "إنزال أصناف المورد/المصنع": the manufacturer's active items of the agreement's suppliers, not yet listed
  function agrmnt_load_items (p_rowid in varchar2) return varchar2 is
    l_a st_supp_agrmnt%rowtype;
    l_n number := 0;
  begin
    select * into l_a from st_supp_agrmnt where rowid = chartorowid(p_rowid);
    for r in (select st.item_group_code, st.item_code, st.name_e, st.supplier, st.moh_disc,
                     u.unit_code, u.retail_sale_price
                from st_item st, st_item_unit u
               where st.kind_code = l_a.kind_code
                 and st.supplier in (select supplier_code from st_supp_agrmnt_supp where serial = l_a.serial)
                 and nvl(st.stop_flag, 0) = 0
                 and (st.item_group_code, st.item_code) not in (select group_code, item_code from st_supp_agrmnt_det where serial = l_a.serial)
                 and u.group_code = st.item_group_code and u.item_code = st.item_code and nvl(u.basic_unit, 0) = 1
               order by st.name_e, st.item_group_code, st.item_code) loop
      insert into st_supp_agrmnt_det (serial, group_code, item_code, unit_code, sales_price, disc1_ratio, disc1_value,
                                      supplier_code, item_name_dummy, basic_qty)
      values (l_a.serial, r.item_group_code, r.item_code, r.unit_code, r.retail_sale_price, r.moh_disc,
              round(nvl(r.retail_sale_price, 0) * nvl(r.moh_disc, 0) / 100, 4), r.supplier, r.name_e, 0);
      l_n := l_n + 1;
    end loop;
    g_msg := m('تم إنزال ' || l_n || ' صنف', l_n || ' items were added');
    return p_rowid;
  end agrmnt_load_items;

  -- ================================================================== ST_PO_ITEM_SUPP (30/41)
  procedure prep_det_row (p_inserting in boolean, p_serial in number,
                          p_group in out number, p_item in varchar2, p_supp in out number, p_kind in out number,
                          p_qty in number, p_old_qty in number, p_chk in out number,
                          p_price in out number, p_old_price in number,
                          p_pct in out number, p_old_pct in number, p_bonus in out number, p_old_bonus in number,
                          p_xpct in out number, p_old_xpct in number, p_xbonus in out number, p_old_xbonus in number,
                          p_d1r in out number, p_o_d1r in number, p_d1v in out number, p_o_d1v in number,
                          p_d2r in out number, p_o_d2r in number, p_d2v in out number, p_o_d2v in number,
                          p_mr in number, p_mv in out number, p_por in number, p_pov in out number) is
    l     number;
    l_d3r number;
    l_d3v number;
  begin
    if g_action then return; end if;
    if p_item is null then err(-20164, 'إختر صنف لهذا السجل أولاً', 'Select an item for this record first'); end if;
    p_group := nvl(p_group, app_rules_pr.item_group(p_item));
    select count(1) into l from st_item where item_group_code = p_group and item_code = p_item and nvl(stop_flag, 0) = 0;
    if l = 0 then err(-20154, in_list('الصنف ' || p_item, 'item ' || p_item)); end if;
    if p_supp is null or p_kind is null then
      select nvl(p_supp, max(supplier)), nvl(p_kind, max(kind_code)) into p_supp, p_kind
        from st_item where item_group_code = p_group and item_code = p_item;
    end if;
    -- the legacy line took the retail price of the basic unit and the item's MOH discount (ST_ITEM_UNIT / ST_ITEM.MOH_DISC)
    -- when the item was entered or the loaded line was taken into the order
    if nvl(p_price, 0) = 0 and (p_inserting or nvl(p_qty, 0) > 0 or nvl(p_chk, 0) = 1) then
      select max(u.retail_sale_price), max(i.moh_disc) into p_price, l
        from st_item_unit u, st_item i
       where u.group_code = p_group and u.item_code = p_item and nvl(u.basic_unit, 0) = 1
         and i.item_group_code = u.group_code and i.item_code = u.item_code;
      if nvl(p_d1r, 0) = 0 and nvl(p_d1v, 0) = 0 and nvl(l, 0) <> 0 then
        p_d1r := l;
        p_d1v := nvl(p_price, 0) * l / 100;
      end if;
    end if;
    p_chk := nvl(p_chk, 0);
    value_check(p_qty); value_check(p_price); value_check(p_bonus); value_check(p_xbonus);
    ratio_check(p_pct); ratio_check(p_xpct); ratio_check(p_d1r); ratio_check(p_d2r); ratio_check(p_por);
    app_rules_pr.pair_ratio(p_inserting, p_qty, p_old_qty, p_pct, p_old_pct, p_bonus, p_old_bonus);
    -- the extra bonus of the legacy lines is truncated (80 x 4 % = 3)
    if nvl(p_qty, 0) <> 0 and nvl(p_xpct, 0) <> 0
       and ((p_inserting and p_xbonus is null) or chg(p_xpct, p_old_xpct) = 1 or chg(p_qty, p_old_qty) = 1)
       and chg(p_xbonus, p_old_xbonus) = 0 then
      p_xbonus := trunc(p_qty * p_xpct / 100);
    elsif nvl(p_qty, 0) <> 0 and chg(p_xbonus, p_old_xbonus) = 1 then
      p_xpct := case when p_xbonus is null then null else round(p_xbonus * 100 / p_qty, 2) end;
    end if;
    app_rules_pr.disc_chain(p_inserting, p_price, p_old_price, p_d1r, p_o_d1r, p_d1v, p_o_d1v,
                            p_d2r, p_o_d2r, p_d2v, p_o_d2v, l_d3r, null, l_d3v, null);
    if p_mr is not null then
      p_mv := round((nvl(p_price, 0) - nvl(p_d1v, 0) - nvl(p_d2v, 0)) * p_mr / 100, 4);
    end if;
    if p_por is not null then
      p_pov := round((nvl(p_price, 0) - nvl(p_d1v, 0) - nvl(p_d2v, 0)) * p_por / 100, 4);
    end if;
    if p_chk = 1 then
      if nvl(p_qty, 0) + nvl(p_bonus, 0) <= 0 then
        err(-20168, 'الكمية و البونص يجب أن يكون مجموعهما أكبر من صفر - الصنف ' || p_item,
            'Quantity plus bonus must be greater than zero - item ' || p_item);
      end if;
      if nvl(p_price, 0) = 0 then
        err(-20168, 'لابد من ادخال سعر الوحدة - الصنف ' || p_item, 'The unit price must be entered - item ' || p_item);
      end if;
    end if;
  end prep_det_row;

  function prep_validate (p_request in varchar2, p_rowid in varchar2, p_from in varchar2, p_to in varchar2,
                          p_po_supp in varchar2, p_po_store in varchar2, p_pr_order_type in varchar2) return varchar2 is
    l number;
  begin
    if p_request not in ('CREATE', 'SAVE') then return null; end if;
    if to_d(p_from) > to_d(p_to) then
      return m('يجب ان يكون من تاريخ اصغر من الى تاريخ', 'The from date must be earlier than the to date');
    end if;
    if p_po_supp is not null then
      select count(1) into l from supplier where code = to_n(p_po_supp) and supplier_status = 1;
      if l = 0 then return in_list('مورد أمر الشراء', 'purchase order supplier'); end if;
    end if;
    if p_po_store is not null then
      select count(1) into l from st_store where store_code = to_n(p_po_store) and store_status = 1 and nvl(stop_flag, 0) = 0;
      if l = 0 then return in_list('مستودع أمر الشراء', 'purchase order store'); end if;
    end if;
    if p_pr_order_type is not null then
      select count(1) into l from st_pr_order_types where serial = to_n(p_pr_order_type);
      if l = 0 then return in_list('نوع أمر الشراء', 'purchase order type'); end if;
    end if;
    return null;
  end prep_validate;

  -- legacy GET_ITEM "انزال الاصناف": the active items of the supplier / manufacturer / class (and of the agreement)
  function prep_get_items (p_rowid in varchar2) return varchar2 is
    l_h st_po_item_supp%rowtype;
    l   number;
    l_n number := 0;
  begin
    select * into l_h from st_po_item_supp where rowid = chartorowid(p_rowid);
    select count(1) into l from st_po_item_supp_det where serial = l_h.serial;
    if l > 0 then err(-20169, 'يجب حذف البيانات المسجلة', 'The recorded lines must be deleted first'); end if;
    g_action := true;
    for r in (select item_group_code, item_code, supplier, kind_code
                from st_item
               where (l_h.supp_code is null or supplier = l_h.supp_code)
                 and (l_h.from_kind is null or kind_code = l_h.from_kind)
                 and (l_h.from_class is null or class_code = l_h.from_class)
                 and (l_h.cntrct_serial is null
                      or (item_group_code, item_code) in (select group_code, item_code from st_supp_agrmnt_det
                                                           where serial = l_h.cntrct_serial and supplier_code = l_h.po_supp))
                 and nvl(stop_flag, 0) = 0
               order by name_e, item_group_code, item_code) loop
      insert into st_po_item_supp_det (serial, supp_code, item_group_code, item_code, quantity, bonus, extra_bonus, chk, kind_code,
                                       unit_price, disc1_ratio)
      values (l_h.serial, r.supplier, r.item_group_code, r.item_code, 0, 0, 0, 0, r.kind_code, 0, 0);
      l_n := l_n + 1;
    end loop;
    g_action := false;
    g_msg := m('تم إنزال ' || l_n || ' صنف', l_n || ' items were loaded');
    return p_rowid;
  exception when others then g_action := false; raise;
  end prep_get_items;

  -- legacy SELECT_ALL "اختيار الكل" / DESELECT_ALL "استبعاد الكل" / "حذف الصفر" (lines without quantity and bonus)
  function prep_mark (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    l_serial number;
    l_n      number;
  begin
    select serial into l_serial from st_po_item_supp where rowid = chartorowid(p_rowid);
    g_action := true;
    if p_what = 'ALL' then
      update st_po_item_supp_det set chk = 1 where serial = l_serial and nvl(chk, 0) <> 1;
    elsif p_what = 'NONE' then
      update st_po_item_supp_det set chk = 0 where serial = l_serial and nvl(chk, 0) <> 0;
    else
      delete from st_po_item_supp_det where serial = l_serial and nvl(quantity, 0) = 0 and nvl(bonus, 0) = 0;
    end if;
    l_n := sql%rowcount;
    g_action := false;
    g_msg := m('عدد الأصناف: ' || l_n, 'Lines: ' || l_n);
    return p_rowid;
  exception when others then g_action := false; raise;
  end prep_mark;

  -- legacy LOAD_EXCEL "تحميل EXCEL" (WEBUTIL -> ST_ITEM_EXCEL): columns item code, quantity, bonus; one line per item
  function prep_load_excel (p_rowid in varchar2, p_file in varchar2) return varchar2 is
    l_blob blob;
    l_name varchar2(400);
  begin
    if p_file is null then err(-20170, 'يجب إدخال مسار الملف', 'The file must be chosen'); end if;
    begin
      select blob_content, filename into l_blob, l_name from apex_application_temp_files where name = p_file;
    exception when no_data_found then err(-20170, 'خطأ فى إسم الملف', 'Wrong file name');
    end;
    return prep_load_blob(p_rowid, l_blob, l_name);
  end prep_load_excel;

  function prep_load_blob (p_rowid in varchar2, p_blob in blob, p_name in varchar2) return varchar2 is
    l_h    st_po_item_supp%rowtype;
    l_item varchar2(100);
    l_grp  number;
    l_supp number;
    l_kind number;
    l_moh  number;
    l_price number;
    l_n    number := 0;
    l_bad  varchar2(4000);
    type t_q is table of number index by varchar2(100);
    l_qty   t_q;
    l_bonus t_q;
    k       varchar2(100);
  begin
    select * into l_h from st_po_item_supp where rowid = chartorowid(p_rowid);
    for r in (select col001, col002, col003 from table(apex_data_parser.parse(p_content => p_blob, p_file_name => p_name))) loop
      l_item := trim(r.col001);
      if instr(l_item, '.') > 0 then l_item := substr(l_item, 1, instr(l_item, '.') - 1); end if;   -- 101011544.0
      continue when l_item is null or to_n(l_item) is null;
      l_qty(l_item)   := case when l_qty.exists(l_item) then l_qty(l_item) else 0 end + nvl(to_n(r.col002), 0);
      l_bonus(l_item) := case when l_bonus.exists(l_item) then l_bonus(l_item) else 0 end + nvl(to_n(r.col003), 0);
    end loop;
    g_action := true;
    k := l_qty.first;
    while k is not null loop
      select max(i.item_group_code), max(i.supplier), max(i.kind_code), max(i.moh_disc), max(u.retail_sale_price)
        into l_grp, l_supp, l_kind, l_moh, l_price
        from st_item i, st_item_unit u
       where i.item_code = k and nvl(i.stop_flag, 0) = 0 and u.item_code = i.item_code and u.group_code = i.item_group_code
         and nvl(u.basic_unit, 0) = 1;
      if l_grp is null then
        l_bad := l_bad || k || ' ';
      else
        -- a loaded (zero) line taken into the order gets the retail price and MOH discount, as in the line rule
        update st_po_item_supp_det
           set quantity = l_qty(k), bonus = l_bonus(k), chk = 1,
               disc1_ratio = case when nvl(unit_price, 0) = 0 and nvl(disc1_ratio, 0) = 0 and nvl(disc1_value, 0) = 0
                                  then l_moh else disc1_ratio end,
               disc1_value = case when nvl(unit_price, 0) = 0 and nvl(disc1_ratio, 0) = 0 and nvl(disc1_value, 0) = 0
                                  then round(nvl(l_price, 0) * nvl(l_moh, 0) / 100, 4) else disc1_value end,
               unit_price  = case when nvl(unit_price, 0) = 0 then l_price else unit_price end
         where serial = l_h.serial and item_group_code = l_grp and item_code = k;
        if sql%rowcount = 0 then
          insert into st_po_item_supp_det (serial, item_group_code, item_code, supp_code, kind_code, quantity, bonus,
                                           extra_bonus, chk, unit_price, disc1_ratio, disc1_value)
          values (l_h.serial, l_grp, k, l_supp, l_kind, l_qty(k), l_bonus(k), 0, 1, l_price, l_moh,
                  round(nvl(l_price, 0) * nvl(l_moh, 0) / 100, 4));
        end if;
        l_n := l_n + 1;
      end if;
      k := l_qty.next(k);
    end loop;
    g_action := false;
    g_msg := m('تم تحميل ' || l_n || ' صنف', l_n || ' items were loaded')
             || case when l_bad is not null then m(' - أصناف غير موجودة أو متوقفة: ', ' - unknown or stopped items: ') || l_bad end;
    return p_rowid;
  exception when others then g_action := false; raise;
  end prep_load_blob;

  function prep_can_order (p_rowid in varchar2) return varchar2 is
    l_h st_po_item_supp%rowtype;
    l   number;
  begin
    select * into l_h from st_po_item_supp where rowid = chartorowid(p_rowid);
    select count(1) into l from st_po_item_supp_det where serial = l_h.serial and chk = 1;
    return case when l > 0 and l_h.pr_order_trns_serial is null then 'Y' else 'N' end;
  exception when no_data_found then return 'N';
  end prep_can_order;

  -- legacy POB "عمل أمر شراء": one purchase order (confirmed) to the order supplier / store with the chosen lines
  function prep_make_order (p_rowid in varchar2, p_order_type in number, p_date in date) return varchar2 is
    l_h     st_po_item_supp%rowtype;
    l_ser   number;
    l_cur   number;
    l_rate  number;
    l_line  number := 0;
    l_rowid rowid;
  begin
    select * into l_h from st_po_item_supp where rowid = chartorowid(p_rowid) for update;
    if l_h.po_supp is null or l_h.po_store is null or p_order_type is null or p_date is null then
      err(-20171, 'إستكمل البيانات', 'Complete the data (order supplier, store, order type and date)');
    end if;
    if l_h.pr_order_trns_serial is not null then
      err(-20171, 'تم عمل أمر الشراء رقم ' || l_h.pr_order_trns_type_code || '/' || l_h.pr_order_trns_serial || ' من قبل',
          'Purchase order ' || l_h.pr_order_trns_type_code || '/' || l_h.pr_order_trns_serial || ' was already made');
    end if;
    if app_rules_pr.is_order_type(p_order_type) = 0 then
      err(-20171, in_list('حركة أمر الشراء', 'purchase order transaction'));
    end if;
    if date_error(p_date) is not null then err(-20171, date_error(p_date)); end if;
    select nvl(max(trns_serial), 0) + 1 into l_ser from pr_order where trns_type_code = p_order_type;
    select max(s.currency_code), max(a.rate) into l_cur, l_rate
      from supplier s, ac_currency a where s.code = l_h.po_supp and s.currency_code = a.currency_code;
    insert into pr_order (trns_type_code, trns_serial, pr_order_date, supplier_code, store_code, currency_code, currency_rate,
                          desc_a, pr_order_type, arrival_date, insert_user, update_date, update_user, cntrct_serial,
                          requisition_type, confirm_flag, tax_value1, tot_disc1_ratio, tot_disc1_value, tot_disc2_ratio,
                          tot_disc2_value, tot_disc3_ratio, tot_disc3_value,
                          fotter1_memo, fotter2_memo, fotter3_memo, fotter4_memo, fotter5_memo)
    values (p_order_type, l_ser, p_date, l_h.po_supp, l_h.po_store, nvl(l_cur, 1), nvl(l_rate, 1),
            l_h.notes, l_h.pr_order_type, p_date, usr, sysdate, usr, l_h.cntrct_serial,
            null, 0, 0, 0, 0, 0, 0, 0, 0,
            '1- PO COPY MUST FOR DELIVARY', '2- ITEMS EXPIRY DATE NOT LESS THAN 1 YEAR AT DELIVARY DATE',
            '3- ALL PURCHASE PRICE IN INVOICE MUST MATCH PO PURCHAE PRICE', '4- PO VALIDITY 30 DAYS FROM DATE OF ISSUE',
            '5- PO WILL BE AVAILBLE ON SYSTEM FOR PARTIAL DELIVARY FOR ONE WEEK FROM 1ST DELIVARY')
    returning rowid into l_rowid;
    for r in (select d.*, (select u.unit_code from st_item_unit u where u.group_code = d.item_group_code
                              and u.item_code = d.item_code and u.basic_unit = 1 and rownum = 1) unit_code,
                     (select u.retail_sale_price from st_item_unit u where u.group_code = d.item_group_code
                              and u.item_code = d.item_code and u.basic_unit = 1 and rownum = 1) retail
                from st_po_item_supp_det d
               where d.serial = l_h.serial and d.chk = 1 and nvl(d.quantity, 0) + nvl(d.bonus, 0) > 0
               order by d.item_group_code, d.item_code) loop
      l_line := l_line + 1;
      insert into pr_order_det (trns_type_code, trns_serial, serial, group_code, item_code, unit_code, quantity, vn_price,
                                qty_status, bonus, percentage, extra_bonus, extra_percentage, disc1_ratio, disc1_value,
                                disc2_ratio, disc2_value, on_spot, net_cost, m_disc_value, m_disc_ratio,
                                m_extra_bonus_ratio, m_extra_bonus_value, po_m_disc_ratio, po_m_disc_value,
                                sales_price, pr_order_date, st_po_serial, st_po_group_code, st_po_item_code, store_code)
      values (p_order_type, l_ser, l_line, r.item_group_code, r.item_code, r.unit_code, nvl(r.quantity, 0), r.unit_price,
              1, nvl(r.bonus, 0), nvl(r.percentage, 0), nvl(r.extra_bonus, 0), nvl(r.extra_percentage, 0),
              nvl(r.disc1_ratio, 0), nvl(r.disc1_value, 0), nvl(r.disc2_ratio, 0), nvl(r.disc2_value, 0),
              r.on_spot, r.net_cost, r.m_disc_value, r.m_disc_ratio, nvl(r.m_extra_bonus_ratio, 0), nvl(r.m_extra_bonus_value, 0),
              nvl(r.po_m_disc_ratio, 0), nvl(r.po_m_disc_value, 0), r.retail, p_date, l_h.serial, r.item_group_code, r.item_code,
              l_h.po_store);
    end loop;
    if l_line = 0 then
      err(-20171, 'لا توجد أصناف مختارة بكمية', 'There are no chosen lines with a quantity');
    end if;
    -- the legacy order is created confirmed; the order rules (APP_RULES_PR) confirm it once its lines exist
    update pr_order set confirm_flag = 1 where rowid = l_rowid;
    g_action := true;
    update st_po_item_supp set pr_order_trns_type_code = p_order_type, pr_order_trns_serial = l_ser where rowid = chartorowid(p_rowid);
    g_action := false;
    g_msg := m('تم عمل أمر الشراء رقم ' || p_order_type || '/' || l_ser || ' (' || l_line || ' صنف)',
               'Purchase order ' || p_order_type || '/' || l_ser || ' was made (' || l_line || ' lines)');
    return rowidtochar(l_rowid);
  exception when others then g_action := false; raise;
  end prep_make_order;

  -- ================================================================== ST_RETURN_AUTH_COST2 (30/47)
  procedure auth_mast_row (p_inserting in boolean, p_type in number, p_date in out date, p_date_serial in out number,
                           p_store in out number, p_supplier in number, p_currency in out number, p_rate in out number,
                           p_delete_flag in out number, p_post_flag in out number, p_old_post_flag in number,
                           p_approve in out number, p_old_approve in number, p_approve_date in out date, p_approve_user in out number,
                           p_approve2 in out number, p_old_approve2 in number, p_approve2_date in out date, p_approve2_user in out number,
                           p_invoice_no in out varchar2, p_serial in number) is
  begin
    if g_action then return; end if;
    p_approve  := nvl(p_approve, 0);
    p_approve2 := nvl(p_approve2, 0);
    if p_inserting then
      p_date := trunc(nvl(p_date, sysdate));
      if p_date_serial is null then
        select nvl(max(nvl(date_serial, 0)) + 1, 1) into p_date_serial from st_trns_auth_mast where trns_date = p_date;
      end if;
      p_delete_flag := nvl(p_delete_flag, 0);
      p_post_flag   := 0;
      p_store := nvl(p_store, app_rules_pr.type_store(p_type));
      if p_supplier is not null and nvl(p_currency, 1) = 1 and app_rules_pr.supplier_currency(p_supplier) <> 1 then
        p_currency := app_rules_pr.supplier_currency(p_supplier);
        p_rate     := app_rules_pr.currency_rate(p_currency, p_date);
      end if;
      p_invoice_no := nvl(p_invoice_no, to_char(p_type) || lpad(to_char(p_serial), 7, '0'));
    else
      -- converted (POST_FLAG = 1, legacy "ترحيل السند") documents are read-only; the flag only changes with the actions
      p_post_flag := p_old_post_flag;
      if nvl(p_old_post_flag, 0) = 1 then
        err(-20172, 'لا يمكن تعديل هذه الحركة', 'This transaction cannot be modified');
      end if;
    end if;
    -- approvals (USERS.RT_ALLOW_APPROVE / RT_ALLOW_APPROVE2), level 2 after level 1, stamped with user and date
    if chg(p_approve, nvl(p_old_approve, 0)) = 1 then
      if user_flag('RT_ALLOW_APPROVE') <> 1 and nvl(usr, -1) <> 0 then
        err(-20172, 'ليس لديك صلاحية الإعتماد', 'You are not allowed to approve');
      end if;
      if p_approve = 0 and p_approve2 = 1 then
        err(-20172, 'يجب إلغاء إعتماد الإدارة أولا', 'The management approval must be cancelled first');
      end if;
      p_approve_date := case when p_approve = 1 then sysdate end;
      p_approve_user := case when p_approve = 1 then usr end;
    end if;
    if chg(p_approve2, nvl(p_old_approve2, 0)) = 1 then
      if user_flag('RT_ALLOW_APPROVE2') <> 1 and nvl(usr, -1) <> 0 then
        err(-20172, 'ليس لديك صلاحية الإعتماد', 'You are not allowed to approve');
      end if;
      if p_approve2 = 1 and p_approve <> 1 then
        err(-20172, 'يجب الإعتماد الأول أولا', 'The first approval is required first');
      end if;
      p_approve2_date := case when p_approve2 = 1 then sysdate end;
      p_approve2_user := case when p_approve2 = 1 then usr end;
    end if;
  end auth_mast_row;

  procedure auth_det_row (p_inserting in boolean, p_type in number, p_serial in number,
                          p_group in out number, p_item in varchar2, p_unit in out number, p_confg in number,
                          p_qty in number, p_old_qty in number,
                          p_bonus_ratio in out number, p_old_bonus_ratio in number, p_bonus in out number, p_old_bonus in number,
                          p_xratio in out number, p_old_xratio in number, p_xbonus in out number, p_old_xbonus in number,
                          p_price_curr in out number, p_old_price_curr in number, p_price in out number,
                          p_d1r in out number, p_o_d1r in number, p_d1v in out number, p_o_d1v in number,
                          p_d2r in out number, p_o_d2r in number, p_d2v in out number, p_o_d2v in number,
                          p_d3r in out number, p_o_d3r in number, p_d3v in out number, p_o_d3v in number,
                          p_basic_qty in out number, p_store in out number, p_date in out date, p_date_serial in out number,
                          p_delete_flag in out number, p_cost_flag in out number) is
    l_m st_trns_auth_mast%rowtype;
    l   number;
  begin
    if g_action then return; end if;
    begin
      select * into l_m from st_trns_auth_mast where trns_type_code = p_type and trns_serial = p_serial;
    exception when no_data_found then l_m := null;
    end;
    if nvl(l_m.post_flag, 0) = 1 then
      err(-20172, 'لا يمكن تعديل هذه الحركة', 'This transaction cannot be modified');
    end if;
    if p_item is null then err(-20164, 'إختر صنف لهذا السجل أولاً', 'Select an item for this record first'); end if;
    p_group := nvl(p_group, app_rules_pr.item_group(p_item));
    select count(1) into l from st_item where item_group_code = p_group and item_code = p_item and nvl(stop_flag, 0) = 0;
    if l = 0 then err(-20154, in_list('رقم الصنف ' || p_item, 'item ' || p_item)); end if;
    p_unit := nvl(p_unit, app_rules_pr.basic_unit(p_group, p_item));
    if p_confg is not null then
      select count(1) into l from st_item_confg where item_confg_id = p_confg and group_code = p_group and item_code = p_item;
      if l = 0 then err(-20154, in_list('الشحنة', 'lot')); end if;
      -- the legacy lot LOV (CONFG_LOV) returned the lot's UNIT_PRICE into the display-only price of the line
      if p_price_curr is null then
        select max(unit_price) into p_price_curr from st_item_confg where item_confg_id = p_confg;
      end if;
    end if;
    if (p_inserting or chg(p_qty, p_old_qty) + chg(p_bonus, p_old_bonus) + chg(p_xbonus, p_old_xbonus) > 0)
       and (nvl(p_qty, 0) < 0 or nvl(p_qty, 0) + nvl(p_bonus, 0) + nvl(p_xbonus, 0) <= 0) then
      err(-20173, 'يجب إدخال كمية أكبر من الصفر - الصنف ' || p_item, 'Enter a quantity greater than zero - item ' || p_item);
    end if;
    if p_price_curr < 0 then
      err(-20173, 'قيم الاصناف أقل من صفر', 'The item values are below zero');
    end if;
    app_rules_pr.pair_ratio(p_inserting, p_qty, p_old_qty, p_bonus_ratio, p_old_bonus_ratio, p_bonus, p_old_bonus);
    app_rules_pr.pair_ratio(p_inserting, p_qty, p_old_qty, p_xratio, p_old_xratio, p_xbonus, p_old_xbonus);
    app_rules_pr.disc_chain(p_inserting, p_price_curr, p_old_price_curr, p_d1r, p_o_d1r, p_d1v, p_o_d1v,
                            p_d2r, p_o_d2r, p_d2v, p_o_d2v, p_d3r, p_o_d3r, p_d3v, p_o_d3v);
    p_basic_qty := (nvl(p_qty, 0) + nvl(p_bonus, 0) + nvl(p_xbonus, 0)) * nvl(app_rules_pr.unit_factor(p_group, p_item, p_unit), 1);
    if p_price_curr is not null then
      p_price := p_price_curr * nvl(l_m.currency_rate, 1);
    end if;
    p_store       := nvl(l_m.store_code, p_store);
    p_date        := nvl(l_m.trns_date, p_date);
    p_date_serial := nvl(l_m.date_serial, p_date_serial);
    p_delete_flag := nvl(p_delete_flag, 0);
    p_cost_flag   := nvl(p_cost_flag, 1);
  end auth_det_row;

  function auth_validate (p_request in varchar2, p_rowid in varchar2, p_type in varchar2, p_date in varchar2,
                          p_store in varchar2, p_currency in varchar2, p_rate in varchar2, p_doc_no in varchar2,
                          p_acc1 in varchar2, p_acc2 in varchar2, p_acc3 in varchar2, p_acc4 in varchar2,
                          p_values in varchar2) return varchar2 is
    l_type  number := to_n(p_type);
    l_date  date := to_d(p_date);
    l       number;
    l_close date;
    l_doc   number := to_n(p_doc_no);
  begin
    if p_request not in ('CREATE', 'SAVE') then return null; end if;
    if l_type is null or app_rules_pr.is_return_type(l_type) = 0 then
      return in_list('الحركة', 'transaction type');
    end if;
    if pw <> 0 then
      select count(1) into l from st_trnstype_password where trns_type_code = l_type and password_number = pw and flag = 1;
      if l = 0 then return in_list('الحركة', 'transaction type'); end if;
    end if;
    if p_store is null then return m('يجب ربط الحركة بالمخزن', 'The transaction must be linked to a store'); end if;
    if store_ok(to_n(p_store)) = 0 then return in_list('المخزن', 'store'); end if;
    if date_error(l_date) is not null then return date_error(l_date); end if;
    select max(close_date) into l_close from ac_basic where company_code = to_n(v('G_COMPANY_CODE'));
    if l_close is not null and l_date <= l_close then
      return m('الفترة مقفلة: تاريخ الحركة قبل تاريخ الإقفال ' || to_char(l_close, 'DD/MM/YYYY'),
               'Closed period: the date is not after the closing date ' || to_char(l_close, 'DD/MM/YYYY'));
    end if;
    if to_n(p_rate) is null then return m('يجب ادخال معامل التحويل', 'The exchange rate must be entered'); end if;
    if to_n(p_currency) = 1 and to_n(p_rate) <> 1 then
      return m('معامل تحويل الريال يجب ان يكون ب 1', 'The riyal exchange rate must be 1');
    end if;
    if l_doc is not null then
      select nvl(max(doc_repeat), 0) into l from st_basic;
      if l = 0 then
        select (select count(1) from st_trns_mast tm where tm.trns_type_code = l_type and tm.doc_no = l_doc and nvl(tm.delete_flag, 0) = 0
                  and (tm.auth_trns_type_code is null or (tm.auth_trns_type_code, tm.auth_trns_serial) not in
                       (select a.trns_type_code, a.trns_serial from st_trns_auth_mast a where p_rowid is not null and a.rowid = chartorowid(p_rowid))))
             + (select count(1) from st_trns_auth_mast ta where ta.trns_type_code = l_type and ta.doc_no = l_doc and nvl(ta.delete_flag, 0) = 0
                  and (p_rowid is null or ta.rowid <> chartorowid(p_rowid)))
          into l from dual;
        if l > 0 then return m('رقم المستند مكرر', 'The document number is repeated'); end if;
      end if;
    end if;
    if (p_acc1 is not null and p_acc1 in (nvl(p_acc2, '#'), nvl(p_acc3, '#'), nvl(p_acc4, '#')))
       or (p_acc2 is not null and p_acc2 in (nvl(p_acc3, '#'), nvl(p_acc4, '#')))
       or (p_acc3 is not null and p_acc3 = p_acc4) then
      return m('رقم الحساب مكرر', 'The account number is repeated');
    end if;
    -- expenses and discounts (colon separated list of the header values) may not be negative
    for r in (select regexp_substr(p_values, '[^:]+', 1, level) val from dual
               connect by level <= regexp_count(nvl(p_values, ''), ':') + 1) loop
      if to_n(r.val) < 0 then return m('القيمة لا يمكن أقل من صفر', 'The value cannot be below zero'); end if;
    end loop;
    return null;
  end auth_validate;

  function auth_warning (p_supplier in varchar2) return varchar2 is
  begin
    return case when p_supplier is null then m('الحركة بدون مورد', 'The transaction has no supplier') end;
  end auth_warning;

  procedure auth_after_save (p_request in varchar2, p_rowid in varchar2) is
    l_m   st_trns_auth_mast%rowtype;
    l     number;
    l_max number;
    l_one number;
  begin
    if p_request not in ('CREATE', 'SAVE') or p_rowid is null then return; end if;
    select * into l_m from st_trns_auth_mast where rowid = chartorowid(p_rowid);
    select count(1) into l from st_trns_auth_det where trns_type_code = l_m.trns_type_code and trns_serial = l_m.trns_serial
       and nvl(delete_flag, 0) = 0;
    if l = 0 then err(-20174, 'لا يمكن الحفظ بدون تفاصيل', 'The document cannot be saved without lines'); end if;
    select nvl(max(trns_max_items), 999999), nvl(max(single_item), 0) into l_max, l_one from st_basic;
    if l > l_max then
      err(-20174, 'عدد الأصناف أكبر من الحد الأقصى ' || l_max, 'The number of lines exceeds the maximum ' || l_max);
    end if;
    if l_one = 1 then
      select count(1) into l from (select group_code, item_code from st_trns_auth_det
                                    where trns_type_code = l_m.trns_type_code and trns_serial = l_m.trns_serial
                                    group by group_code, item_code having count(*) > 1);
      if l > 0 then err(-20174, 'صنف مكرر', 'The item is repeated'); end if;
    end if;
    -- the returned quantity of a lot may not exceed its balance in the store (legacy CONFG LOV and "الرصيد لا يسمح")
    for r in (select d.group_code, d.item_code, d.item_confg_id, sum(d.basic_qty) q
                from st_trns_auth_det d
               where d.trns_type_code = l_m.trns_type_code and d.trns_serial = l_m.trns_serial and nvl(d.delete_flag, 0) = 0
                 and d.item_confg_id is not null
               group by d.group_code, d.item_code, d.item_confg_id) loop
      if r.q > nvl(get_balance_confg(l_m.store_code, r.group_code, r.item_code, r.item_confg_id, null, null, null), 0) then
        err(-20174, 'رصيــد هذه الشحنة لهذا صنف فى هذا التاريخ لا يسمــح  .... ' || r.item_code || ' / ' || r.item_confg_id,
            'The balance of this lot does not allow the quantity - item ' || r.item_code || ' lot ' || r.item_confg_id);
      end if;
    end loop;
  end auth_after_save;

  procedure auth_after_delete (p_type in varchar2, p_serial in varchar2) is
    l number;
  begin
    select count(1) into l from st_trns_mast
     where auth_trns_type_code = to_n(p_type) and auth_trns_serial = to_n(p_serial) and nvl(delete_flag, 0) = 0;
    if l > 0 then
      err(-20172, 'لا يمكن حذف هذه الحركة: تم ترحيلها إلى مرتجع مشتريات', 'The document cannot be deleted: it was converted to a purchase return');
    end if;
  end auth_after_delete;

  function auth_can (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    l_m st_trns_auth_mast%rowtype;
    l   number;
  begin
    select * into l_m from st_trns_auth_mast where rowid = chartorowid(p_rowid);
    select count(1) into l from st_trns_mast
     where auth_trns_type_code = l_m.trns_type_code and auth_trns_serial = l_m.trns_serial and nvl(delete_flag, 0) = 0;
    if p_what = 'CONVERT' then
      return case when l = 0 and nvl(l_m.post_flag, 0) = 0 and nvl(l_m.delete_flag, 0) = 0 then 'Y' else 'N' end;
    end if;
    return case when l > 0 or nvl(l_m.post_flag, 0) = 1 then 'Y' else 'N' end;
  exception when no_data_found then return 'N';
  end auth_can;

  -- legacy "ترحيل السند" / "تحويل الفاتورة": the approved authorisation becomes a purchase return (ST_TRNS_MAST / DET /
  -- SERVICES) of the same type, linked by AUTH_TRNS_TYPE_CODE / AUTH_TRNS_SERIAL
  function auth_convert (p_rowid in varchar2) return varchar2 is
    l_m     st_trns_auth_mast%rowtype;
    l_ser   number;
    l_rowid rowid;
    l_line  number := 0;
    l_inv   varchar2(40);
  begin
    select * into l_m from st_trns_auth_mast where rowid = chartorowid(p_rowid) for update;
    if nvl(l_m.approve2, 0) <> 1 or nvl(l_m.approve, 0) <> 1 then
      err(-20175, 'يجب إعتماد الإدارة أولا', 'The management approval is required first');
    end if;
    if auth_can(p_rowid, 'CONVERT') = 'N' then
      err(-20175, 'تم التحويل', 'Already converted');
    end if;
    select nvl(max(trns_serial), 0) + 1 into l_ser from st_trns_mast where trns_type_code = l_m.trns_type_code;
    l_inv := to_char(l_m.trns_type_code) || lpad(to_char(l_ser), 7, '0');
    insert into st_trns_mast (trns_serial, trns_date, date_serial, currency_rate, delete_flag, trns_type_code, currency_code,
                              doc_no, desc_a, desc_e, disc_val, freight_val, customs_val, trnsport_val, insurance_val,
                              commission_val, others_val, supplier_code, customer_code, cost_code, account_number1,
                              account_number2, account_number3, account_number4, store_code, cost_code2, posting_supplier_code,
                              insert_user, special_disc, insert_date, others2_val, insurance2_val, customs2_val, trnsport2_val,
                              tax_code1, tax_value1, tax_code2, tax_value2, supplier_ref, vessel_name, t_tax_flag1, t_tax_value1,
                              delivery_date, tot_disc1_ratio, tot_disc2_ratio, tot_disc3_ratio, tot_disc1_value, tot_disc2_value,
                              tot_disc3_value, tax_code_mast, disc4_value, disc5_value, tot_disc4_value, tot_disc5_value, purch_code,
                              supp_others_val, supp_insurance_val, supp_freight_val, auth_trns_type_code, auth_trns_serial,
                              invoice_no, post_flag)
    values (l_ser, trunc(sysdate), 999999999999, l_m.currency_rate, 0, l_m.trns_type_code, l_m.currency_code,
            l_m.doc_no, l_m.desc_a || ' ' || l_inv, l_m.desc_e || ' ' || l_inv, l_m.disc_val, l_m.freight_val,
            l_m.customs_val, l_m.trnsport_val, l_m.insurance_val, l_m.commission_val, l_m.others_val, l_m.supplier_code,
            l_m.customer_code, l_m.cost_code, l_m.account_number1, l_m.account_number2, l_m.account_number3, l_m.account_number4,
            l_m.store_code, l_m.cost_code2, l_m.posting_supplier_code, usr, l_m.special_disc, sysdate, l_m.others2_val,
            l_m.insurance2_val, l_m.customs2_val, l_m.trnsport2_val, l_m.tax_code1, l_m.tax_value1, l_m.tax_code2, l_m.tax_value2,
            l_m.supplier_ref, l_m.vessel_name, l_m.t_tax_flag1, l_m.t_tax_value1, l_m.delivery_date, l_m.tot_disc1_ratio,
            l_m.tot_disc2_ratio, l_m.tot_disc3_ratio, l_m.tot_disc1_value, l_m.tot_disc2_value, l_m.tot_disc3_value,
            l_m.tax_code_mast, l_m.disc4_value, l_m.disc5_value, l_m.tot_disc4_value, l_m.tot_disc5_value, l_m.purch_code,
            l_m.supp_others_val, l_m.supp_insurance_val, l_m.supp_freight_val, l_m.trns_type_code, l_m.trns_serial, l_inv, 0)
    returning rowid into l_rowid;
    for r in (select * from st_trns_auth_det
               where trns_type_code = l_m.trns_type_code and trns_serial = l_m.trns_serial and nvl(delete_flag, 0) = 0
               order by item_serial) loop
      l_line := l_line + 1;
      insert into st_trns_det (trns_type_code, trns_serial, item_serial, production_date, group_code, item_code, unit_code,
                               quantity, unit_price, unit_price_curr, basic_qty, unit_cost, cost_flag, item_confg_id, store_code,
                               bonus, extra_bonus, disc1_value, disc2_value, disc3_value, disc1_ratio, disc2_ratio, disc3_ratio,
                               bonus_ratio, extra_bonus_ratio, trns_date, date_serial, delete_flag, det_disc, disc,
                               tax_code1, tax_value1, tax_code2, tax_value2)
      values (l_m.trns_type_code, l_ser, l_line, r.production_date, r.group_code, r.item_code, r.unit_code,
              nvl(r.quantity, 0), nvl(r.unit_price, 0), nvl(r.unit_price_curr, 0), r.basic_qty, r.unit_cost, 1,
              r.item_confg_id, l_m.store_code, nvl(r.bonus, 0), nvl(r.extra_bonus, 0), nvl(r.disc1_value, 0),
              nvl(r.disc2_value, 0), nvl(r.disc3_value, 0), nvl(r.disc1_ratio, 0), nvl(r.disc2_ratio, 0), nvl(r.disc3_ratio, 0),
              nvl(r.bonus_ratio, 0), nvl(r.extra_bonus_ratio, 0), trunc(sysdate), 999999999999, 0, nvl(r.det_disc, 0),
              nvl(r.disc, 0), r.tax_code1, r.tax_value1, r.tax_code2, r.tax_value2);
    end loop;
    for r in (select * from st_trns_auth_services where trns_type_code = l_m.trns_type_code and trns_serial = l_m.trns_serial) loop
      insert into st_trns_services (trns_type_code, trns_serial, service_serial, service_code, service_cost, units_no)
      values (l_m.trns_type_code, l_ser, r.service_serial, r.service_code, r.service_cost, r.units_no);
    end loop;
    app_rules_pr.check_stock(l_m.trns_type_code, l_ser);
    g_action := true;
    update st_trns_auth_mast set post_flag = 1 where rowid = chartorowid(p_rowid);
    g_action := false;
    g_msg := m('تم التحويل', 'Converted') || ' (' || l_m.trns_type_code || '/' || l_ser || ')';
    return p_rowid;
  exception when others then g_action := false; raise;
  end auth_convert;

  -- legacy cancel: allowed while the created return is neither posted to stock/GL nor to the suppliers
  function auth_cancel (p_rowid in varchar2) return varchar2 is
    l_m   st_trns_auth_mast%rowtype;
    l     number;
  begin
    select * into l_m from st_trns_auth_mast where rowid = chartorowid(p_rowid) for update;
    select nvl(max(decode(nvl(post_flag, 0), 1, 1, nvl(supp_post_flag, 0))), 0) into l
      from st_trns_mast
     where auth_trns_type_code = l_m.trns_type_code and auth_trns_serial = l_m.trns_serial and nvl(delete_flag, 0) = 0;
    if l = 1 then
      err(-20176, 'لا يمكن الغاء الترحيل للمخازن لوجود حركة صرف تمت على هذه الحركة او تم ترحيلها للحسابات والموردين',
          'The conversion cannot be cancelled: the return was already posted to GL or to the suppliers');
    end if;
    delete from st_trns_det where (trns_type_code, trns_serial) in
      (select trns_type_code, trns_serial from st_trns_mast where auth_trns_type_code = l_m.trns_type_code and auth_trns_serial = l_m.trns_serial);
    delete from st_trns_services where (trns_type_code, trns_serial) in
      (select trns_type_code, trns_serial from st_trns_mast where auth_trns_type_code = l_m.trns_type_code and auth_trns_serial = l_m.trns_serial);
    delete from st_trns_mast where auth_trns_type_code = l_m.trns_type_code and auth_trns_serial = l_m.trns_serial;
    g_action := true;
    update st_trns_auth_mast set post_flag = 0 where rowid = chartorowid(p_rowid);
    g_action := false;
    g_msg := m('تم إلغاء الترحيل', 'The conversion was cancelled');
    return p_rowid;
  exception when others then g_action := false; raise;
  end auth_cancel;

end app_rules3_pr;
/
show errors package body app_rules3_pr

-- -----------------------------------------------------------------------------------------------------
-- Delete hooks and statement-level checks (the generated APPX_<table> triggers only cover INSERT / UPDATE).
-- APEX sessions only: the legacy Forms application keeps its own checks.
-- -----------------------------------------------------------------------------------------------------
create or replace trigger app_r3_lc_pay_cond_bd before delete on lc_pay_cond for each row
begin
  if v('APP_ID') is not null then app_rules3_pr.pay_cond_delete(:old.pay_cond_code); end if;
end;
/
create or replace trigger app_r3_lc_pay_credit_cond_bd before delete on lc_pay_credit_cond for each row
begin
  if v('APP_ID') is not null then app_rules3_pr.credit_cond_delete(:old.cond_no); end if;
end;
/
create or replace trigger app_r3_st_term_ship_bd before delete on st_term_ship for each row
begin
  if v('APP_ID') is not null then app_rules3_pr.term_ship_delete(:old.term_ship_code); end if;
end;
/
create or replace trigger app_r3_lc_port_bd before delete on lc_port for each row
begin
  if v('APP_ID') is not null then app_rules3_pr.port_delete(:old.port_code); end if;
end;
/
create or replace trigger app_r3_st_cntrct_types_bd before delete on st_cntrct_types for each row
begin
  if v('APP_ID') is not null then app_rules3_pr.cntrct_delete(:old.cntrct_code); end if;
end;
/
create or replace trigger app_r3_st_trns_type_bd before delete on st_trns_type for each row
begin
  if v('APP_ID') is not null then app_rules3_pr.trns_type_delete(:old.trns_type_code); end if;
end;
/
create or replace trigger app_r3_st_proj_est_mast_bd before delete on st_proj_est_mast for each row
begin
  if v('APP_ID') is not null then app_rules3_pr.est_mast_delete(:old.store_code); end if;
end;
/
create or replace trigger app_r3_st_proj_est_det_bd before delete on st_proj_est_det for each row
begin
  if v('APP_ID') is not null then
    app_rules3_pr.est_det_delete(:old.store_code, :old.group_code, :old.item_code, :old.color_code, :old.size_code);
  end if;
end;
/
-- ST_PERIODS: date ranges may not overlap (checked after each statement: the grid saves row by row)
create or replace trigger app_r3_st_periods_ct
for insert or update on st_periods compound trigger
  type t_codes is table of number index by pls_integer;
  g_codes t_codes;
  after each row is
  begin
    if v('APP_ID') is not null then g_codes(g_codes.count + 1) := :new.period_code; end if;
  end after each row;
  after statement is
    l_codes t_codes := g_codes;
  begin
    g_codes.delete;
    for i in 1 .. l_codes.count loop app_rules3_pr.period_overlap(l_codes(i)); end loop;
  end after statement;
end app_r3_st_periods_ct;
/
-- ST_PU_SERVICES: parent LEAF flag, sub-services and use in transactions on delete
create or replace trigger app_r3_st_pu_services_ct
for insert or delete on st_pu_services compound trigger
  type t_codes is table of number index by pls_integer;
  g_ins t_codes; g_ins_lvl t_codes; g_del t_codes; g_del_lvl t_codes;
  before each row is
  begin
    if v('APP_ID') is not null and deleting then app_rules3_pr.service_before_delete(:old.service_code); end if;
  end before each row;
  after each row is
  begin
    if v('APP_ID') is not null then
      if inserting then
        g_ins(g_ins.count + 1) := :new.service_code; g_ins_lvl(g_ins_lvl.count + 1) := :new.service_level;
      else
        g_del(g_del.count + 1) := :old.service_code; g_del_lvl(g_del_lvl.count + 1) := :old.service_level;
      end if;
    end if;
  end after each row;
  after statement is
    l_ins t_codes := g_ins; l_ins_lvl t_codes := g_ins_lvl; l_del t_codes := g_del; l_del_lvl t_codes := g_del_lvl;
  begin
    g_ins.delete; g_ins_lvl.delete; g_del.delete; g_del_lvl.delete;
    for i in 1 .. l_ins.count loop app_rules3_pr.service_after_insert(l_ins(i), l_ins_lvl(i)); end loop;
    for i in 1 .. l_del.count loop app_rules3_pr.service_after_delete(l_del(i), l_del_lvl(i)); end loop;
  end after statement;
end app_r3_st_pu_services_ct;
/
show errors trigger app_r3_st_pu_services_ct
