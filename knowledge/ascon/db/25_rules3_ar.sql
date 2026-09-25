-- =====================================================================================================
-- APP_RULES3_AR : business rules of the receivables (system 4) setup, master-data and mobile screens (Stage C wave 3).
-- Evidence and rule lists: app\legacy\processes\<FORM>.md.  Wired by app\legacy\overrides\<FORM>.json.
--
-- How the rules are wired (STAGE_C_WAVE3.md):
--   * key_expr / row_rules of the overrides call the functions and procedures below from the generated APPX_<TABLE>
--     triggers (APEX sessions only).  Every hook first checks the legacy form of the current APEX page
--     (APP_PAGE_MAP.FORM_NAME of APP_PAGE_ID) when the table is shared with other screens;
--   * page validations / after-save processes / warnings / info call the functions of this package;
--   * delete hooks (the rules mechanism has none) are the triggers at the end of this file, APEX sessions only.
--     A delete coming from the "delete document" cascade of a document page (REQUEST = DELETE) is how the legacy
--     "cannot delete a master record while details exist" rules are reproduced.
-- Row triggers never query their own table on UPDATE / DELETE (ORA-04091): such checks run in compound triggers (after
-- statement, keys collected per row) at the end of this file, or in the after-save process of the document page; the
-- structure screens read the committed structure through one autonomous read-only function (struct_max_c).
-- No COMMIT (APEX commits); the only exception is the legacy procedure GET_SALESMAN_COMM (commission calculation button),
-- which commits its steps itself.  Errors: raise_application_error(-20100..-20199), legacy Arabic text, English when G_LANG = en.
-- Screens (31): COMPLAINT_CUSTOMER, ARPERIOD, AR_DEPT_DISC, ARCUST_CLASS, ARAREA, ARTARGETRANGESCAT, AR_SALESMAN, CUSTOMER,
-- AR_CUST_STRUCT, AR_ITEM, ARTRNSTYPE, COMPLAINT_CODES (no code), AR_AGES (no code), AR_BASIC, ARTRN_OP, ARSLSMANCUSTTRNSFR,
-- ARTARGETRANGES, ARTARGETPERIOD, AR_TARGET, ARCUSTGROUPS, AR_SLSMAN_SCHEDUAL, AR_CUSTOMER_DUES, AR_CUSTOMER_DUES_PAY,
-- AR_MULTI_CUST_TRNS, AR_SALESMAN_MSG, MOB_SKIP_REASONS, AR_SALESMAN_COLL_PAY, ARCRTRN_DAILY, AR_MOB_DEPOSITE_TRNS,
-- AR_CUSTOMER_ATTR_STRUCT, AR_SALESMAN_COMM_REV.
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_rules3_ar authid definer as

  g_test boolean := false;             -- set by the test scripts only (see tmp test harness); never used by the rules

  -- ------------------------------------------------------------------ context helpers
  function lang return varchar2;                                   -- 'A' / 'E'
  function msg (p_a in varchar2, p_e in varchar2) return varchar2;
  procedure err (p_a in varchar2, p_e in varchar2, p_code in pls_integer default -20100);
  function cur_form return varchar2;                               -- legacy form of the current APEX page
  function is_form (p_form in varchar2) return boolean;
  function doc_delete (p_form in varchar2) return boolean;         -- "delete document" request of that form's page
  function grp return number;                                      -- G_PASSWORD_NUMBER
  function num (p in varchar2) return number;                      -- page item string -> number
  function dt (p in varchar2) return date;                         -- page item string -> date

  -- ------------------------------------------------------------------ shared legacy checks
  -- CHECK_DATE (library TRANSLATE, system 4): not after today; not before the AR minimum date (AC_BASIC.MIN_DATE)
  function check_date_msg (p_date in date, p_future in number default 0) return varchar2;
  -- telephone / fax WHEN-VALIDATE-ITEM of CUSTOMER / SUPPLIER (p_kind 'T' telephone, 'F' fax)
  function phone_msg (p_value in varchar2, p_kind in varchar2 default 'T') return varchar2;
  function account_exists (p_account in number) return number;     -- AC_MASTER, ACCOUNT_STATUS = 1
  procedure need (p_value in varchar2, p_a in varchar2, p_e in varchar2);   -- raise when p_value is null
  function need_num (p_a in varchar2, p_e in varchar2) return number;      -- key_expr of a key the user must choose

  -- ------------------------------------------------------------------ ARPERIOD (AR_PERIOD)
  procedure period_row (p_ins in boolean, p_serial in number, p_from in out number, p_to in number);
  procedure period_del (p_serial in number);
  -- ------------------------------------------------------------------ ARTARGETPERIOD (AR_TARGET_PERIODS)
  procedure tperiod_row (p_ins in boolean, p_year in number, p_serial in number, p_from in out date, p_to in date);
  procedure tperiod_last (p_year in number, p_serial in number, p_op in varchar2);    -- after UPDATE / DELETE statement
  function insert_months (p_year in number) return varchar2;        -- button "انزال شهور السنه"
  -- ------------------------------------------------------------------ ARTARGETRANGES (AR_TARGET_RANGES)
  procedure trange_row (p_ins in boolean, p_year in number, p_qurt in number, p_serial in number,
                        p_from in out number, p_to in number);
  procedure trange_last (p_year in number, p_qurt in number, p_serial in number, p_op in varchar2);
  function next_trange_serial (p_year in number, p_qurt in number) return number;
  -- ------------------------------------------------------------------ ARTARGETRANGESCAT (department commission ranges)
  function next_comm_serial (p_tab in varchar2, p_ctgry in number, p_flag in number) return number;   -- 'COMM' / 'MNGR' / 'PRC'
  procedure comm_row (p_tab in varchar2, p_ins in boolean, p_ctgry in number, p_flag in number, p_serial in number,
                      p_from in out number, p_to in number, p_code in number default null);
  procedure comm_del (p_tab in varchar2, p_ctgry in number, p_flag in number, p_serial in number, p_code in number default null);
  procedure comm_items_row (p_ctgry in number, p_serial in number, p_flag in number, p_group in out number, p_item in varchar2);
  procedure salesman_comm_row (p_code in number, p_ctgry in number);
  function load_comm_items (p_ctgry in number, p_serial in number, p_flag in number,
                            p_from_group in number, p_to_group in number, p_from_item in varchar2, p_to_item in varchar2,
                            p_from_supp in number, p_to_supp in number, p_from_kind in number, p_to_kind in number) return varchar2;
  -- ------------------------------------------------------------------ ARCUSTGROUPS (routes)
  procedure route_mast_row (p_salesman in number);
  procedure route_det_row (p_ins in boolean, p_group in number, p_customer in number, p_order in out number,
                           p_day in out varchar2, p_day_text in out varchar2);
  -- ------------------------------------------------------------------ AR_CUST_STRUCT / AR_CUSTOMER_ATTR_STRUCT (code structures)
  procedure struct_row (p_kind in varchar2, p_ins in boolean, p_level in number, p_start in out number, p_end in number,
                        p_length in out number, p_old_start in number, p_old_end in number, p_old_length in number);
  procedure struct_del (p_kind in varchar2, p_level in number);
  procedure lockup_row (p_kind in varchar2, p_parent in number, p_tab_no in varchar2);
  function struct_warning (p_kind in varchar2, p_level in varchar2, p_end in varchar2) return varchar2;
  -- ------------------------------------------------------------------ code tables
  function next_skip_code return varchar2;                          -- MOB_SKIP_REASONS.SKIP_CODE
  procedure skip_reason_row (p_op_code in varchar2);
  procedure positive_code (p_code in number, p_a in varchar2, p_e in varchar2);
  -- ------------------------------------------------------------------ ARAREA (areas, branches, branch stores and departments)
  procedure mainarea_row (p_id in number, p_account in number, p_disc in number, p_entry_type in number);
  procedure subarea_row (p_id in number, p_account in number, p_disc in number, p_sales_mngr in number, p_br_mngr in number);
  procedure subarea_del (p_main in number, p_id in number);
  procedure subarea_store_row (p_ins in boolean, p_main in number, p_sub in number, p_store in number);
  procedure ctgry_subarea_row (p_main in number, p_sub in number, p_ctgry in number, p_mngr in number, p_account in number);
  -- ------------------------------------------------------------------ ARCUST_CLASS / AR_DEPT_DISC / discount periods
  procedure cust_class_row (p_credit in number);
  procedure dscnt_row (p_kind in varchar2, p_ins in boolean, p_owner in number, p_period in number, p_prcnt in number, p_value in number);
  procedure ctgry_type_row (p_code in number);
  procedure ctgry_type_child_del (p_form in varchar2);
  -- ------------------------------------------------------------------ COMPLAINT_CUSTOMER
  procedure complaint_mast_row (p_customer in number);
  procedure complaint_det_row (p_code in number);
  -- ------------------------------------------------------------------ ARTRNSTYPE
  procedure trnstype_row (p_id in number, p_effect in number, p_trns_type in number, p_joint in number, p_entry_type in number,
                          p_acc_type in number, p_cust_acc_type in number, p_disc_acc_type in number,
                          p_account in number, p_cust_account in number, p_disc_account in number,
                          p_cost_type in number, p_cost2_type in number);
  procedure trnstype_dscnt_row (p_ins in boolean, p_id in number, p_period in number, p_prcnt in number, p_value in number);

  -- ------------------------------------------------------------------ CUSTOMER (customers file)
  function cust_level (p_code in number) return number;             -- DETECT_CUST_LEVEL
  function cust_parent (p_code in number, p_level in number) return number;   -- GET_CUST_PARENT
  procedure customer_row (p_ins in boolean, p_code in out number, p_old_code in number, p_level in out number,
                          p_status in out number, p_type in number, p_customer_id in number, p_company_id in number,
                          p_registry_id in number, p_tel1 in varchar2, p_tel2 in varchar2, p_tel3 in varchar2, p_fax in varchar2,
                          p_day_no in number, p_credit in number, p_stop in number, p_stop_date in out date, p_stop_reason in out varchar2,
                          p_main in number, p_old_main in number, p_sub in number, p_old_sub in number, p_class in number,
                          p_account in number, p_disc in number, p_cost1 in number, p_cost2 in number,
                          p_currency in number, p_old_currency in number, p_open_date in date,
                          p_old_open_date in date default null, p_old_stop_date in date default null);
  procedure customer_del (p_code in number, p_status in number);
  function customer_snapshot (p_rowid in varchar2) return varchar2;   -- validation before the DML (returns null)
  procedure customer_after (p_request in varchar2, p_rowid in varchar2, p_code in varchar2, p_level in varchar2);
  function cust_info (p_code in varchar2, p_what in varchar2) return varchar2;
  -- AR_CUST_SALESMAN (CUSTOMER and AR_SALESMAN screens), AR_CUST_RESP, AR_CUST_DSCNT
  function need_salesman_code return number;
  procedure cust_salesman_row (p_ins in boolean, p_customer in number, p_ctgry in number, p_salesman in number, p_credit in number,
                               p_old_salesman in number, p_old_ctgry in number, p_mngr1 in number, p_mngr2 in number, p_mrch in number);
  procedure cust_salesman_del (p_customer in number, p_ctgry in number, p_salesman in number);
  function next_cust_resp_code return number;
  procedure cust_dscnt_del (p_customer in number);
  procedure cust_child_del;                                         -- AR_CUST_RESP: document delete of the customer

  -- ------------------------------------------------------------------ AR_SALESMAN (salesmen file)
  procedure salesman_row (p_code in number, p_disc_ratio in number, p_store in number, p_customer in number, p_old_customer in number,
                          p_users in number, p_account in number, p_cost1 in number, p_cost2 in number, p_supervisor in number,
                          p_issue in number, p_return in number, p_order in number, p_trnsfr in number, p_trnsfr_to in number,
                          p_pay1 in number, p_pay2 in number, p_pay3 in number, p_main in number, p_sub in number, p_ctgry in number);
  procedure ctgry_salesman_row (p_ins in boolean, p_salesman in number, p_ctgry in number);
  procedure ctgry_salesman_del (p_salesman in number, p_ctgry in number);
  procedure salesman_store_row (p_ins in boolean, p_salesman in number, p_store in number);
  procedure salesman_account_row (p_ins in boolean, p_salesman in number, p_account in number, p_cost1 in number, p_cost2 in number);
  procedure salesman_account_del (p_salesman in number, p_account in number, p_cost1 in number, p_cost2 in number);
  function next_book_serial return number;
  procedure book_row (p_ins in boolean, p_salesman in number, p_serial in number, p_from in number, p_to in number, p_type in number);
  procedure book_del (p_salesman in number, p_serial in number);
  procedure book_det_row (p_ins in boolean, p_salesman in number, p_serial in number, p_book_no in number);

  -- ------------------------------------------------------------------ ARTRN_OP (customer opening balances)
  function op_default_type return number;
  procedure op_mast_row (p_ins in boolean, p_trns_id in number, p_serial in number, p_date in date, p_doc_no in number,
                         p_desc_a in out varchar2, p_desc_e in out varchar2, p_old_trns_id in number, p_old_serial in number);
  procedure op_line_row (p_ins in boolean, p_trns_id in number, p_trns_serial in number, p_customer in number, p_ctgry in number,
                         p_main in out number, p_sub in out number, p_salesman in out number, p_currency in out number,
                         p_rate in out number, p_value in number, p_bill_id1 in number, p_bill_id2 in out number,
                         p_r_serial in out number,
                         p_old_customer in number, p_old_ctgry in number, p_old_salesman in number, p_old_value in number,
                         p_old_r_serial in number);
  procedure op_line_del (p_trns_id in number, p_trns_serial in number, p_r_serial in number, p_customer in number,
                         p_salesman in number, p_ctgry in number, p_value in number);
  procedure op_after_save (p_rowid in varchar2);

  -- ------------------------------------------------------------------ ARSLSMANCUSTTRNSFR (transfer customers between salesmen)
  function next_trnsfr_date_serial (p_from in number) return number;
  function next_trnsfr_serial (p_from in number, p_date in date, p_date_serial in number) return number;
  procedure trnsfr_mast_row (p_ins in boolean, p_from in number, p_date in date);
  procedure cust_balance (p_customer in number, p_bal out number, p_bal_loc out number);
  procedure trnsfr_line_row (p_ins in boolean, p_from in number, p_date in date, p_customer in number, p_to in number,
                             p_ctgry in number, p_cr in number, p_db in number, p_bal in out number, p_bal_loc in out number,
                             p_cr_serial in out number, p_db_serial in out number);
  procedure trnsfr_line_del (p_from in number, p_date in date, p_customer in number, p_to in number, p_ctgry in number,
                             p_cr in number, p_cr_serial in number, p_db in number, p_db_serial in number);
  procedure trnsfr_after_save (p_rowid in varchar2);
  function load_trnsfr_customers (p_rowid in varchar2, p_ctgry in number, p_to in number, p_cr in number, p_db in number) return varchar2;

  -- ------------------------------------------------------------------ AR_TARGET / AR_SLSMAN_SCHEDUAL / AR_SALESMAN_MSG
  procedure target_row (p_year in number, p_customer in number, p_salesman in number, p_serial in number,
                        p_group in out number, p_item in varchar2);
  procedure target_dup (p_serial in number);
  procedure readonly_master;
  procedure schedule_row (p_ins in boolean, p_salesman in number, p_customer in number, p_date in date, p_order in out number);
  procedure visit_row (p_salesman in number, p_customer in number, p_start in date, p_end in date);
  function load_route (p_rowid in varchar2, p_group in number, p_date in date) return varchar2;
  procedure msg_det_row (p_ins in boolean, p_to in number);
  function msg_add_salesmen (p_rowid in varchar2, p_ctgry in number) return varchar2;

  -- ------------------------------------------------------------------ AR_BASIC
  function basic_warning (p_rowid in varchar2, p_auto in varchar2, p_calc in varchar2, p_slsm in varchar2, p_stop in varchar2) return varchar2;

  -- ------------------------------------------------------------------ AR_CUSTOMER_DUES
  procedure check_close (p_date in date);
  procedure dues_mast_row (p_ins in boolean, p_main in number, p_serial in number, p_sub in number, p_salesman in number,
                           p_ctgry in number, p_date in date, p_type in number, p_f in date, p_t in date,
                           p_d_acc in number, p_c_acc in number, p_post in number, p_old_post in number,
                           p_old_sub in number, p_old_salesman in number, p_old_ctgry in number, p_old_date in date, p_old_type in number);
  procedure dues_det_check (p_main in number, p_serial in number);
  function dues_fill (p_rowid in varchar2) return varchar2;
  function dues_post (p_rowid in varchar2) return varchar2;
  function dues_unpost (p_rowid in varchar2) return varchar2;

  -- ------------------------------------------------------------------ AR_CUSTOMER_DUES_PAY
  procedure pay_mast_row (p_ins in boolean, p_id in number, p_serial in number, p_main in number, p_sub in number, p_salesman in number,
                          p_ctgry in number, p_type in number, p_post in number, p_old_post in number,
                          p_old_main in number, p_old_sub in number, p_old_salesman in number, p_old_ctgry in number, p_old_type in number);
  procedure pay_det_row (p_id in number, p_serial in number, p_link in number, p_old_link in number);
  procedure pay_det_amount (p_id in number, p_serial in number, p_due_serial in number);   -- after statement (reads its own table)
  procedure pay_det_check (p_id in number, p_serial in number);
  function pay_due (p_id in number, p_serial in number, p_customer in number, p_salesman in number, p_what in varchar2) return number;
  function pay_fill (p_rowid in varchar2) return varchar2;
  function pay_post (p_rowid in varchar2) return varchar2;
  function pay_unpost (p_rowid in varchar2) return varchar2;

  -- ------------------------------------------------------------------ AR_SALESMAN_COLL_PAY
  function next_coll_serial (p_salesman in number) return number;
  procedure coll_mast_row (p_ins in boolean, p_salesman in number, p_date in date, p_old_date in date,
                           p_doc_no in out varchar2, p_notes in out varchar2);
  procedure coll_det_row (p_ins in boolean, p_salesman in number, p_serial in number, p_ar_flag in number,
                          p_ar_id in number, p_ar_main in number, p_ar_sub in number, p_ar_serial in number,
                          p_rp_id in number, p_rp_serial in number, p_choose in number, p_old_choose in number,
                          p_value in out number, p_ar_doc in out number, p_rp_doc in out number);
  procedure coll_det_check (p_salesman in number, p_serial in number, p_ar_flag in number, p_det_serial in number);
  procedure coll_det_del (p_ar_flag in number, p_choose in number, p_ar_id in number, p_ar_main in number, p_ar_sub in number,
                          p_ar_serial in number);
  procedure coll_trf_row (p_ins in boolean, p_salesman in number, p_serial in number, p_seq in number, p_value in number,
                          p_date in out date, p_bank in out number, p_branch in out number, p_pay_type in out number);
  procedure coll_trf_check (p_seq in number);
  function coll_total (p_salesman in number, p_serial in number, p_what in varchar2) return number;
  procedure coll_balance (p_rowid in varchar2);
  function coll_load_ar (p_rowid in varchar2) return varchar2;
  function coll_load_rp (p_rowid in varchar2) return varchar2;
  function coll_load_mob (p_rowid in varchar2) return varchar2;

  -- ------------------------------------------------------------------ AR_MOB_DEPOSITE_TRNS
  procedure mob_row (p_ins in boolean, p_salesman in number, p_date in date, p_total in number, p_bank in number, p_branch in number,
                     p_pay_type in number, p_ref in varchar2, p_posted_date in date, p_status in number, p_post in number,
                     p_old_salesman in number, p_old_date in date, p_old_total in number, p_old_bank in number, p_old_branch in number,
                     p_old_pay_type in number, p_old_ref in varchar2, p_old_posted_date in date, p_old_status in number, p_old_post in number);
  procedure mob_del (p_status in number);
  function mob_auth (p_rowid in varchar2) return varchar2;
  function mob_refuse (p_rowid in varchar2) return varchar2;
  function mob_post (p_rowid in varchar2) return varchar2;
  function mob_unpost (p_rowid in varchar2) return varchar2;

  -- ------------------------------------------------------------------ ARCRTRN_DAILY
  procedure daily_row (p_ins in boolean, p_trns_id in number, p_customer in number, p_salesman in number, p_date in date,
                       p_cash_flag in number, p_auth_date in date, p_old_auth_date in date, p_status in number, p_old_status in number);
  procedure daily_ref_check (p_trns_id in number, p_main in number, p_sub in number, p_serial in number);
  procedure daily_del (p_status in number, p_post in number);

  -- ------------------------------------------------------------------ AR_SALESMAN_COMM_REV
  procedure comm_value_row (p_net in number, p_prc in out number, p_value in out number, p_old_prc in number, p_old_value in number);
  function comm_calc (p_rowid in varchar2, p_month in number, p_year in number) return varchar2;
  function comm_delete (p_rowid in varchar2, p_month in number, p_year in number) return varchar2;
  function comm_last (p_salesman in number, p_what in varchar2) return varchar2;

  -- ------------------------------------------------------------------ AR_MULTI_CUST_TRNS
  procedure multi_mast_row (p_ins in boolean, p_trns_id in number, p_cash_flag in number, p_box in number, p_bank in number,
                            p_branch in number, p_doc_no in number, p_date in date, p_post in number, p_old_post in number,
                            p_ctgry in out number, p_acc_post_date in out date, p_account in out number, p_cost in out number,
                            p_desc_a in out varchar2);
  procedure multi_line_row (p_ins in boolean, p_serial in number, p_customer in number, p_total in number, p_disc in number,
                            p_trns_id in out number, p_ctgry in out number, p_trns_date in out date, p_acc_post_date in out date,
                            p_post in out number, p_cash_flag in out number, p_main in out number, p_sub in out number,
                            p_currency in out number, p_rate in out number, p_salesman in out number, p_trns_serial in out number,
                            p_serial_total in out number);
  procedure multi_doc_check (p_doc_no in number);
  procedure multi_acc_row (p_serial in number, p_account in number, p_cost in number, p_cost2 in number);
  procedure multi_del (p_serial in number);
  procedure multi_after_save (p_rowid in varchar2);
  function multi_total (p_serial in number, p_what in varchar2) return number;

end app_rules3_ar;
/
show errors package app_rules3_ar

create or replace package body app_rules3_ar as

  g_page  number := -1;
  g_form  varchar2(128);
  g_cust_sum    number;                -- CUSTOMER: salesmen credit limits / customer limit before the page DML
  g_cust_limit  number;

  -- =================================================================================== context helpers
  function lang return varchar2 is
  begin
    return case when lower(nvl(v('G_LANG'), 'ar')) like 'en%' then 'E' else 'A' end;
  end lang;

  function msg (p_a in varchar2, p_e in varchar2) return varchar2 is
  begin
    return case when lang = 'E' then nvl(p_e, p_a) else p_a end;
  end msg;

  procedure err (p_a in varchar2, p_e in varchar2, p_code in pls_integer default -20100) is
  begin
    raise_application_error(p_code, msg(p_a, p_e));
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

  function is_form (p_form in varchar2) return boolean is
  begin
    return nvl(cur_form, '#') = upper(p_form);
  end is_form;

  function doc_delete (p_form in varchar2) return boolean is
  begin
    return v('APP_ID') is not null and is_form(p_form) and v('REQUEST') = 'DELETE';
  end doc_delete;

  function grp return number is
  begin
    return to_number(v('G_PASSWORD_NUMBER'));
  exception when others then return null;
  end grp;

  function num (p in varchar2) return number is
  begin
    return to_number(trim(replace(p, ',', '')));
  exception when others then return null;
  end num;

  function dt (p in varchar2) return date is
  begin
    if p is null then return null; end if;
    begin return to_date(p, 'DD/MM/YYYY'); exception when others then null; end;
    begin return to_date(p, 'YYYY-MM-DD'); exception when others then null; end;
    return to_date(substr(p, 1, 10), 'DD/MM/YYYY');
  exception when others then return null;
  end dt;

  -- =================================================================================== shared legacy checks
  function check_date_msg (p_date in date, p_future in number default 0) return varchar2 is
    l_min date;
  begin
    if p_date is null then return null; end if;
    if nvl(p_future, 0) = 0 and trunc(p_date) > trunc(sysdate) then
      return msg('تاريخ الحركة أكبر من تاريخ اليوم', 'Transaction Date is greater than today''s date');
    end if;
    begin
      select min(min_date) into l_min from ac_basic;
    exception when others then l_min := null;
    end;
    l_min := nvl(l_min, to_date('01-01-' || to_char(to_number(to_char(sysdate, 'YYYY')) - 1), 'DD-MM-YYYY'));
    if trunc(p_date) < trunc(l_min) then
      return msg('الحد الأدنى لتاريخ الحركة هو ' || to_char(l_min, 'DD/MM/YYYY'),
                 'The least value accepted for Transaction Date is ' || to_char(l_min, 'DD/MM/YYYY'));
    end if;
    return null;
  end check_date_msg;

  function phone_msg (p_value in varchar2, p_kind in varchar2 default 'T') return varchar2 is
    l_n number;
  begin
    if p_value is null then return null; end if;
    begin
      l_n := to_number(p_value);
    exception when others then
      -- ":TELEPHONE1 <= 0" on text raised VALUE_ERROR first: "must be without characters"
      return case when p_kind = 'F' then msg(' رقم الفاكس يجب ان يكون بدون حروف', 'The fax numbner should be without character ')
                  else msg('التليفون يجب ان يكون بدون حروف', 'The telephone should be without character ') end;
    end;
    if l_n <= 0 then
      return case when p_kind = 'F' then msg('رقم الفاكس يجب ان يكون اكبر من الصفر', 'the fax number should be over than zero')
                  else msg('رقم التليفون يجب ان يكون اكبر من الصفر', 'the telephnoe should be over than zero') end;
    end if;
    if length(p_value) < 7 or length(p_value) > 17 then
      return case when p_kind = 'F' then msg('رقم الفاكس لا يمكن ان يقل عن 7 أرقام او يزيد عن 17', 'the fax number should be over than 7 and not exceed 17')
                  else msg('رقم التليفون لا يمكن ان يقل عن 7 أرقام او يزيد عن 17', 'the telephnoe should be over than 7 and not exceed 17') end;
    end if;
    return null;
  end phone_msg;

  function account_exists (p_account in number) return number is
    l_n number;
  begin
    if p_account is null then return 1; end if;
    select count(*) into l_n from ac_master where account_number = p_account and account_status = 1;
    return case when l_n > 0 then 1 else 0 end;
  end account_exists;

  procedure need (p_value in varchar2, p_a in varchar2, p_e in varchar2) is
  begin
    if p_value is null then err(p_a, p_e); end if;
  end need;

  function need_num (p_a in varchar2, p_e in varchar2) return number is
  begin
    err(p_a, p_e);
    return null;
  end need_num;

  procedure check_account (p_account in number) is
  begin
    if account_exists(p_account) = 0 then
      err('رقم الحساب غير موجود بدليل الحسابات: ' || p_account, 'Account number not found in the chart of accounts: ' || p_account);
    end if;
  end check_account;

  procedure check_salesman (p_code in number) is
    l_n number;
  begin
    if p_code is null then return; end if;
    select count(*) into l_n from salesman where code = p_code;
    if l_n = 0 then err('رقم المندوب غير موجود: ' || p_code, 'Salesman not found: ' || p_code); end if;
  end check_salesman;

  procedure master_has_details is
  begin
    err('لا يمكن إلغاء سجل رئيسي في و جود سجلات تابعة له', 'Cannot delete master record when matching detail records exist.');
  end master_has_details;

  -- =================================================================================== ARPERIOD
  -- WHEN-CREATE-RECORD: SERIAL = NVL(MAX(SERIAL),0)+1 (generated key), FROM_P = NVL(MAX(TO_P),-1)+1, no new period while one is
  -- open (COUNT(1) ... TO_P IS NULL); "الفترة الى يجب أن يكون أكبر من الفترة من"; KEY-DELREC: "يجب حذف أخر مسلسل أولا"
  procedure period_row (p_ins in boolean, p_serial in number, p_from in out number, p_to in number) is
    l_open number;
  begin
    if p_ins then
      select count(*) into l_open from ar_period where to_p is null;
      if l_open > 0 then
        err('توجد فترة مفتوحة (الفترة إلى فارغة)؛ يجب إدخال نهايتها قبل إضافة فترة جديدة',
            'An open period (empty "to") exists; close it before adding a new period');
      end if;
      select nvl(max(to_p), -1) + 1 into p_from from ar_period;
    end if;
    if p_to is not null and p_to <= p_from then
      err('الفترة الى يجب أن يكون أكبر من الفترة من', 'Period "to" must be greater than period "from"');
    end if;
  end period_row;

  procedure period_del (p_serial in number) is
    l_n number;
  begin
    select count(*) into l_n from ar_period where serial > p_serial;
    if l_n > 0 then err('يجب حذف أخر مسلسل أولا', 'Delete the last serial first'); end if;
  end period_del;

  -- =================================================================================== ARTARGETPERIOD
  procedure tperiod_row (p_ins in boolean, p_year in number, p_serial in number, p_from in out date, p_to in date) is
  begin
    if p_ins then
      select max(to_p) + 1 into p_from from ar_target_periods where t_year = p_year;
      p_from := nvl(p_from, to_date('01/01/' || p_year, 'DD/MM/YYYY'));
    end if;
    if p_to is not null and p_to <= p_from then
      err('الفترة الى يجب أن يكون أكبر من الفترة من', 'Period "to" must be greater than period "from"');
    end if;
  end tperiod_row;

  -- "يجب التعديل فى أخر سجل فقط" / "يجب حذف أخر سجل أولا" (checked after the statement, compound trigger)
  procedure tperiod_last (p_year in number, p_serial in number, p_op in varchar2) is
    l_n number;
  begin
    select count(*) into l_n from ar_target_periods where t_year = p_year and serial > p_serial;
    if l_n > 0 then
      if p_op = 'U' then err('يجب التعديل فى أخر سجل فقط', 'Only the last record can be modified');
      else err('يجب حذف أخر سجل أولا', 'Delete the last record first'); end if;
    end if;
  end tperiod_last;

  -- button "انزال شهور السنه": the twelve months of the year as target periods (only for a year without periods)
  function insert_months (p_year in number) return varchar2 is
    l_n number;
    l_d date;
  begin
    if p_year is null or p_year < 1900 or p_year > 2999 then
      err('يجب إدخال السنة', 'Enter the year');
    end if;
    select count(*) into l_n from ar_target_periods where t_year = p_year;
    if l_n > 0 then
      err('تم إدخال فترات لهذه السنة من قبل', 'Periods already exist for this year');
    end if;
    for m in 1 .. 12 loop
      l_d := to_date('01/' || m || '/' || p_year, 'DD/MM/YYYY');
      insert into ar_target_periods (t_year, serial, from_p, to_p, desc_a, desc_e)
      values (p_year, m, l_d, last_day(l_d),
              to_char(l_d, 'Month', 'nls_date_language = arabic'), trim(to_char(l_d, 'Month', 'nls_date_language = american')));
    end loop;
    return null;
  end insert_months;

  -- =================================================================================== ARTARGETRANGES
  function next_trange_serial (p_year in number, p_qurt in number) return number is
    l_n number;
  begin
    select nvl(max(serial), 0) + 1 into l_n from ar_target_ranges where t_year = p_year and t_qurt = p_qurt;
    return l_n;
  end next_trange_serial;

  procedure trange_row (p_ins in boolean, p_year in number, p_qurt in number, p_serial in number,
                        p_from in out number, p_to in number) is
  begin
    need(p_qurt, 'يجب إدخال رقم الفترة', 'Enter the period');
    if p_ins then
      select max(to_t) + 1 into p_from from ar_target_ranges where t_year = p_year and t_qurt = p_qurt;
      p_from := nvl(p_from, 0);
    end if;
    if p_to is not null and p_to <= p_from then
      err('الفترة الى يجب أن يكون أكبر من الفترة من', 'Range "to" must be greater than range "from"');
    end if;
  end trange_row;

  procedure trange_last (p_year in number, p_qurt in number, p_serial in number, p_op in varchar2) is
    l_n number;
  begin
    select count(*) into l_n from ar_target_ranges where t_year = p_year and t_qurt = p_qurt and serial > p_serial;
    if l_n > 0 then
      if p_op = 'U' then err('يجب التعديل فى أخر سجل فقط', 'Only the last record can be modified');
      else err('يجب حذف أخر سجل أولا', 'Delete the last record first'); end if;
    end if;
  end trange_last;

  -- =================================================================================== ARTARGETRANGESCAT
  -- ranges of ST_CATEGORY_COMM / ST_CATEGORY_COMM_MNGR per department and DISC_FLAG, AR_SALESMAN_PRC_COMM per department
  function next_comm_serial (p_tab in varchar2, p_ctgry in number, p_flag in number) return number is
    l_n number;
  begin
    if p_tab = 'COMM' then
      select nvl(max(serial), 0) + 1 into l_n from st_category_comm where category_type_code = p_ctgry and nvl(disc_flag, 0) = nvl(p_flag, 0);
    elsif p_tab = 'MNGR' then
      select nvl(max(serial), 0) + 1 into l_n from st_category_comm_mngr where category_type_code = p_ctgry and nvl(disc_flag, 0) = nvl(p_flag, 0);
    else
      select nvl(max(serial), 0) + 1 into l_n from ar_salesman_prc_comm where ctgry_code = p_ctgry;
    end if;
    return l_n;
  end next_comm_serial;

  procedure comm_row (p_tab in varchar2, p_ins in boolean, p_ctgry in number, p_flag in number, p_serial in number,
                      p_from in out number, p_to in number, p_code in number default null) is
    l_open number;
    l_n    number;
  begin
    if p_tab in ('COMM', 'MNGR') and nvl(p_flag, -1) not in (0, 1) then
      err('حالة الخصم يجب أن تكون 0 (بدون الخصم) أو 1 (بالخصم)', 'Discount flag must be 0 (without discount) or 1 (with discount)');
    end if;
    if p_tab = 'PRC' then
      need(p_code, 'يجب إدخال كود المندوب', 'Enter the salesman');
      select count(*) into l_n from ar_ctgry_salesman where salesman_code = p_code and ctgry_code = p_ctgry;
      if l_n = 0 then
        err('رقم المندوب المدخل غير موجود فى القسم المختار', 'The sales man code is not located in the selected department');
      end if;
    end if;
    if p_ins then
      if p_tab = 'COMM' then
        select count(case when to_p is null then 1 end), nvl(max(to_p), -1) + 1 into l_open, p_from
          from st_category_comm where category_type_code = p_ctgry and nvl(disc_flag, 0) = nvl(p_flag, 0);
      elsif p_tab = 'MNGR' then
        select count(case when to_p is null then 1 end), nvl(max(to_p), -1) + 1 into l_open, p_from
          from st_category_comm_mngr where category_type_code = p_ctgry and nvl(disc_flag, 0) = nvl(p_flag, 0);
      else
        select count(case when to_p is null then 1 end), nvl(max(to_p), -1) + 1 into l_open, p_from
          from ar_salesman_prc_comm where ctgry_code = p_ctgry;
      end if;
      if l_open > 0 then
        err('توجد فترة مفتوحة (الفترة إلى فارغة)؛ يجب إدخال نهايتها قبل إضافة فترة جديدة',
            'An open range (empty "to") exists; close it before adding a new range');
      end if;
    end if;
    if p_to is not null and p_from is not null and p_to <= p_from then
      err('الفترة الى يجب أن يكون أكبر من الفترة من', 'Range "to" must be greater than range "from"');
    end if;
  end comm_row;

  procedure comm_del (p_tab in varchar2, p_ctgry in number, p_flag in number, p_serial in number, p_code in number default null) is
    l_n number;
  begin
    if p_tab in ('COMM', 'MNGR') and doc_delete('ARTARGETRANGESCAT') then
      master_has_details;                      -- ON-CHECK-DELETE-MASTER of ST_CATEGORY_TYPE (ST_CATEGORY_COMM / _MNGR)
    end if;
    if p_tab = 'COMM' then
      select count(*) into l_n from st_category_comm_items where category_type_code = p_ctgry and serial = p_serial and disc_flag = p_flag;
      if l_n > 0 then master_has_details; end if;
      select count(*) into l_n from st_category_comm where category_type_code = p_ctgry and nvl(disc_flag, 0) = nvl(p_flag, 0) and serial > p_serial;
    elsif p_tab = 'MNGR' then
      select count(*) into l_n from st_category_comm_mngr where category_type_code = p_ctgry and nvl(disc_flag, 0) = nvl(p_flag, 0) and serial > p_serial;
    else
      if doc_delete('ARTARGETRANGESCAT') then return; end if;
      select count(*) into l_n from ar_salesman_prc_comm where ctgry_code = p_ctgry and serial > p_serial;
    end if;
    if l_n > 0 then err('يجب حذف أخر مسلسل أولا', 'Delete the last serial first'); end if;
  end comm_del;

  procedure comm_items_row (p_ctgry in number, p_serial in number, p_flag in number, p_group in out number, p_item in varchar2) is
    l_n number;
  begin
    select count(*) into l_n from st_category_comm where category_type_code = p_ctgry and serial = p_serial and nvl(disc_flag, 0) = nvl(p_flag, 0);
    if l_n = 0 then
      err('لا يوجد مدى بهذا المسلسل وحالة الخصم للقسم', 'No target range with this serial and discount flag for the department');
    end if;
    if p_group is null then
      begin
        select item_group_code into p_group from st_item where item_code = p_item;
      exception when no_data_found or too_many_rows then null;
      end;
    end if;
    select count(*) into l_n from st_item where item_code = p_item and item_group_code = p_group and nvl(stop_flag, 0) = 0;
    if l_n = 0 then err('رقم الصنف غير موجود أو موقوف', 'Item not found or stopped'); end if;
  end comm_items_row;

  procedure salesman_comm_row (p_code in number, p_ctgry in number) is
    l_n number;
  begin
    need(p_code, 'يجب إدخال كود المندوب', 'Enter the salesman');
    select count(*) into l_n from ar_ctgry_salesman where salesman_code = p_code and ctgry_code = p_ctgry;
    if l_n = 0 then
      err('رقم المندوب المدخل غير موجود فى القسم المختار', 'The sales man code is not located in the selected department');
    end if;
  end salesman_comm_row;

  -- button "انزال الاصناف": items of the ranges (group / item / supplier / kind) not yet in the range, COMM left for the user
  function load_comm_items (p_ctgry in number, p_serial in number, p_flag in number,
                            p_from_group in number, p_to_group in number, p_from_item in varchar2, p_to_item in varchar2,
                            p_from_supp in number, p_to_supp in number, p_from_kind in number, p_to_kind in number) return varchar2 is
    l_n number;
  begin
    if p_from_group > p_to_group then
      err('''يجب أن يكون ''الي رقم المجموعة> من رقم المجموعة', 'To group must be greater than from group');
    end if;
    if p_from_item > p_to_item then
      err('"من رقم صنف" اكبر من "الي رقم  صنف"', '"From item" is greater than "to item"');
    end if;
    if p_from_supp > p_to_supp then
      err('''يجب أن يكون ''الي رقم المورد> من رقم المورد', 'To supplier must be greater than from supplier');
    end if;
    if p_from_kind > p_to_kind then
      err('''يجب أن يكون ''الي رقم المصنع> من رقم المصنع', 'To kind must be greater than from kind');
    end if;
    select count(*) into l_n from st_category_comm
     where category_type_code = p_ctgry and serial = p_serial and nvl(disc_flag, 0) = nvl(p_flag, 0);
    if l_n = 0 then
      err('لا يوجد مدى بهذا المسلسل وحالة الخصم للقسم', 'No target range with this serial and discount flag for the department');
    end if;
    insert into st_category_comm_items (category_type_code, serial, disc_flag, group_code, item_code)
    select p_ctgry, p_serial, nvl(p_flag, 0), i.item_group_code, i.item_code
      from st_item i
     where nvl(i.stop_flag, 0) = 0
       and (i.item_group_code >= p_from_group or p_from_group is null) and (i.item_group_code <= p_to_group or p_to_group is null)
       and (i.item_code >= p_from_item or p_from_item is null) and (i.item_code <= p_to_item or p_to_item is null)
       and (i.supplier >= p_from_supp or p_from_supp is null) and (i.supplier <= p_to_supp or p_to_supp is null)
       and (i.kind_code >= p_from_kind or p_from_kind is null) and (i.kind_code <= p_to_kind or p_to_kind is null)
       and (i.item_group_code, i.item_code) not in (select c.group_code, c.item_code from st_category_comm_items c
                                                     where c.serial = p_serial and c.category_type_code = p_ctgry
                                                       and c.disc_flag = nvl(p_flag, 0));
    return null;
  end load_comm_items;

  -- =================================================================================== ARCUSTGROUPS
  procedure route_mast_row (p_salesman in number) is
    l_n number;
  begin
    if p_salesman is null then return; end if;
    select count(*) into l_n from salesman where code = p_salesman and nvl(stop_flag, 0) = 0;
    if l_n = 0 then err('رقم المندوب غير موجود أو موقوف', 'Salesman not found or stopped'); end if;
    if nvl(grp, 0) != 0 then
      select count(*) into l_n from ar_salesman_password where password_number = grp and salesman_code = p_salesman;
      if l_n = 0 then err('خطأ صلاحية', 'Permission error'); end if;
    end if;
  end route_mast_row;

  procedure route_det_row (p_ins in boolean, p_group in number, p_customer in number, p_order in out number,
                           p_day in out varchar2, p_day_text in out varchar2) is
    l_n        number;
    l_salesman number;
  begin
    select max(salesman_id) into l_salesman from ar_customer_group_mast where group_id = p_group;
    select count(*) into l_n from customer c
     where c.code = p_customer and nvl(c.stopflag, 0) <> 1 and nvl(c.customer_status, 0) = 1
       and c.code in (select s.customer_code from ar_cust_salesman s where s.salesman_code = l_salesman);
    if l_n = 0 then
      err('العميل غير موجود أو موقوف أو غير مرتبط بمندوب خط السير', 'Customer not found, stopped or not a customer of the route salesman');
    end if;
    p_day := initcap(substr(trim(p_day), 1, 3));
    p_day_text := case p_day when 'Sat' then 'السبت' when 'Sun' then 'الاحد' when 'Mon' then 'الاثنين' when 'Tue' then 'الثلاثاء'
                             when 'Wed' then 'الاربعاء' when 'Thu' then 'الخميس' when 'Fri' then 'الجمعة' end;
    if p_day_text is null then
      err('يوم الزيارة يجب أن يكون أحد: Sat, Sun, Mon, Tue, Wed, Thu, Fri', 'Visit day must be one of Sat, Sun, Mon, Tue, Wed, Thu, Fri');
    end if;
    if p_ins and p_order is null then
      select nvl(max(customer_order), 0) + 1 into p_order from ar_customer_group_det where group_id = p_group;
    end if;
  end route_det_row;

  -- =================================================================================== code structures
  -- p_kind 'CUST' = AR_CHART_STRUCTURES (customer code, 12 positions, locked while CUSTOMER has rows)
  --        'ATTR' = AR_CUSTOMER_ATTR_STRUCT (customer attributes code, 24 positions, locked while customers have ATTR_CODE)
  function struct_locked (p_kind in varchar2) return boolean is
    l_n number;
  begin
    if p_kind = 'CUST' then
      select count(*) into l_n from customer where rownum = 1;
    else
      select count(*) into l_n from customer where attr_code is not null and rownum = 1;
    end if;
    return l_n > 0;
  end struct_locked;

  function struct_max_c (p_kind in varchar2, p_what in varchar2) return number is
    pragma autonomous_transaction;
    l_n number;
  begin
    if p_kind = 'CUST' then
      select case p_what when 'LEVEL' then max(chr_stru_level) else max(chr_stru_end) end into l_n from ar_chart_structures;
    else
      select case p_what when 'LEVEL' then max(chr_stru_level) else max(chr_stru_end) end into l_n from ar_customer_attr_struct;
    end if;
    commit;
    return l_n;
  end struct_max_c;

  procedure struct_row (p_kind in varchar2, p_ins in boolean, p_level in number, p_start in out number, p_end in number,
                        p_length in out number, p_old_start in number, p_old_end in number, p_old_length in number) is
    l_limit number := case when p_kind = 'CUST' then 12 else 24 end;
  begin
    if struct_locked(p_kind) and (p_ins or nvl(p_start, -1) != nvl(p_old_start, -1) or nvl(p_end, -1) != nvl(p_old_end, -1)
                                  or nvl(p_length, -1) != nvl(p_old_length, -1)) then
      if p_kind = 'CUST' then
        err('لا يمكن تعديل بيانات هيكل دليل العملاء أثناء وجود بيانات في الدليل ولكن يمكن تعديل اسم المستوي فقط',
            'The customer code structure cannot be changed while customers exist; only the level names can be changed');
      else
        err('لا يمكن حذف المستويات حيث أنه توجد ممجموعات أصناف معرفة بناء على هذه المستويات',
            'The structure cannot be changed while customers have attribute codes');
      end if;
    end if;
    if p_ins then
      if p_kind = 'CUST' then
        select nvl(max(chr_stru_end), 0) + 1 into p_start from ar_chart_structures;
      else
        select nvl(max(chr_stru_end), 0) + 1 into p_start from ar_customer_attr_struct;
      end if;
    end if;
    if p_end is null or p_end < p_start or p_end > l_limit then
      if p_kind = 'CUST' then
        err('برجاء التأكد من إدخال -- حقل النهاية -- و كونه اكبر من حقل البداية و كذلك كونه أقل من 12',
            'End position must be entered, not before the start position and at most 12');
      else
        err('برجاء التأكد من إدخال --حقل النهاية-- و كونه أكبر من حقل البداية و كذلك كونه أقل من 24',
            'End position must be entered, not before the start position and at most 24');
      end if;
    end if;
    p_length := p_end - p_start + 1;
  end struct_row;

  procedure struct_del (p_kind in varchar2, p_level in number) is
    l_n number;
  begin
    if struct_locked(p_kind) then
      if p_kind = 'CUST' then
        err('لا يمكن تعديل بيانات هيكل دليل العملاء أثناء وجود بيانات في الدليل ولكن يمكن تعديل اسم المستوي فقط',
            'The customer code structure cannot be changed while customers exist; only the level names can be changed');
      else
        err('لا يمكن حذف المستويات حيث أنه توجد ممجموعات أصناف معرفة بناء على هذه المستويات',
            'The levels cannot be deleted while customers have attribute codes');
      end if;
    end if;
    if p_kind = 'CUST' then
      select count(*) into l_n from ar_chart_structures where chr_stru_level > p_level;
    else
      select count(*) into l_n from ar_customer_attr_struct where chr_stru_level > p_level;
    end if;
    if l_n > 0 then err('يجب حذف السجلات من أسفل إلي أعلي', 'Delete the levels from the bottom up'); end if;
  end struct_del;

  procedure lockup_row (p_kind in varchar2, p_parent in number, p_tab_no in varchar2) is
    l_len number;
  begin
    if p_kind = 'CUST' then
      select max(length) into l_len from ar_chart_structures where chr_stru_level = p_parent;
    else
      select max(length) into l_len from ar_customer_attr_struct where chr_stru_level = p_parent;
    end if;
    if l_len is not null and nvl(length(p_tab_no), 0) != l_len then
      err('يجب ان يكون طول التكويد مساوي لطول المستوى', 'The code length must equal the level length (' || l_len || ')');
    end if;
  end lockup_row;

  -- KEY-COMMIT "برجاء استكمال هيكل دليل الحسابات حتي الخانة الثانية عشر": one level per document in APEX, so a confirmation
  function struct_warning (p_kind in varchar2, p_level in varchar2, p_end in varchar2) return varchar2 is
    l_end   number := num(p_end);
    l_max   number;
    l_limit number := case when p_kind = 'CUST' then 12 else 24 end;
  begin
    if p_kind = 'CUST' then
      select max(chr_stru_end) into l_max from ar_chart_structures where chr_stru_level != nvl(num(p_level), -1);
    else
      select max(chr_stru_end) into l_max from ar_customer_attr_struct where chr_stru_level != nvl(num(p_level), -1);
    end if;
    if greatest(nvl(l_max, 0), nvl(l_end, 0)) < l_limit then
      return case when p_kind = 'CUST' then msg('برجاء استكمال هيكل دليل الحسابات حتي الخانة الثانية عشر ....',
                                                  'Please complete the structure up to position 12')
                  else msg('برجاء استكمال هيكل مجموعات الأصنـــاف', 'Please complete the structure up to position 24') end;
    end if;
    return null;
  end struct_warning;

  -- =================================================================================== code tables
  function next_skip_code return varchar2 is
    l_n number;
  begin
    select nvl(max(to_number(skip_code)), 0) + 1 into l_n from mob_skip_reasons;
    return to_char(l_n);
  end next_skip_code;

  procedure skip_reason_row (p_op_code in varchar2) is
  begin
    if nvl(p_op_code, '#') not in ('COL', 'SLSI', 'SLSR', 'SLSO', 'STCNT') then
      err('الارتباط يجب أن يكون أحد: COL التحصيل، SLSI المبيعات، SLSR المرتجع، SLSO امر البيع، STCNT الجرد',
          'Operation must be one of: COL collection, SLSI sales, SLSR return, SLSO sales order, STCNT stock count');
    end if;
  end skip_reason_row;

  procedure positive_code (p_code in number, p_a in varchar2, p_e in varchar2) is
  begin
    if p_code is not null and p_code <= 0 then err(p_a, p_e); end if;
  end positive_code;

  -- =================================================================================== ARAREA
  procedure mainarea_row (p_id in number, p_account in number, p_disc in number, p_entry_type in number) is
    l_n number;
  begin
    if p_id < 1 then err('رقم المنطقة الرئيسية لا يمكن ان يقل عن 1', 'Main area number cannot be less than 1'); end if;
    if p_account = p_disc then err('لا يمكن تكرار رقم الحساب ', 'Can''t repeat account number'); end if;
    check_account(p_account); check_account(p_disc);
    if p_entry_type is not null then
      select count(*) into l_n from ac_trn_codes where entry_type = p_entry_type;
      if l_n = 0 then err('نوع قيد الحسابات غير موجود', 'Voucher type not found'); end if;
    end if;
  end mainarea_row;

  procedure subarea_row (p_id in number, p_account in number, p_disc in number, p_sales_mngr in number, p_br_mngr in number) is
  begin
    if p_id < 1 then err('رقم المنطقة الفرعية لا يمكن ان يقل عن 1', 'Sub area number cannot be less than 1'); end if;
    if p_account = p_disc then err('لا يمكن تكرار رقم الحساب ', 'Can''t repeat account number'); end if;
    check_account(p_account); check_account(p_disc);
    check_salesman(p_sales_mngr); check_salesman(p_br_mngr);
  end subarea_row;

  -- KEY-DELREC of AR_MAINAREA: "لايمكنك حذف هذه المنطقة لأن لها مناطق فرعية"; a deleted branch takes its stores with it
  -- (DELETE FROM AR_SUBAREA_STORES) and cannot be deleted while it has departments (AR_CTGRY_SUBAREA)
  procedure subarea_del (p_main in number, p_id in number) is
    l_n number;
  begin
    if doc_delete('ARAREA') then
      err('لايمكنك حذف هذه المنطقة لأن لها مناطق فرعية', 'You cannot delete this area because it has sub areas');
    end if;
    select count(*) into l_n from ar_ctgry_subarea where mainarea_id = p_main and subarea_id = p_id;
    if l_n > 0 then master_has_details; end if;
    delete from ar_subarea_stores where main_id = p_main and sub_id = p_id;
  end subarea_del;

  procedure subarea_store_row (p_ins in boolean, p_main in number, p_sub in number, p_store in number) is
    l_n number;
  begin
    select count(*) into l_n from st_store where store_code = p_store and nvl(stop_flag, 0) = 0 and store_status = 1;
    if l_n = 0 then err('كود المخزن غير موجود أو موقوف', 'Store not found or stopped'); end if;
    if p_ins then
      select count(*) into l_n from ar_subarea_stores where store_code = p_store;
      if l_n > 0 then err('تم ربط هذا المخزن من قبل', 'This store is already linked'); end if;
    end if;
  end subarea_store_row;

  procedure ctgry_subarea_row (p_main in number, p_sub in number, p_ctgry in number, p_mngr in number, p_account in number) is
    l_n number;
  begin
    select count(*) into l_n from ar_subarea where main_id = p_main and id = p_sub;
    if l_n = 0 then err('رقم الفرع غير موجود في المنطقة', 'Branch not found in this area'); end if;
    select count(*) into l_n from st_category_type where category_type_code = p_ctgry;
    if l_n = 0 then err('رقم القسم غير موجود', 'Department not found'); end if;
    check_salesman(p_mngr);
    check_account(p_account);
  end ctgry_subarea_row;

  -- =================================================================================== discount periods, classes, departments
  procedure cust_class_row (p_credit in number) is
  begin
    if p_credit < 0 or p_credit > 999999999990.99 then
      err('قيمة حد الإئتمان لا يمكن ان تكون اقل من الصفر او اكبر من 999999999990.99',
          'Credit limit cannot be less than zero or greater than 999999999990.99');
    end if;
  end cust_class_row;

  -- p_kind CLASS (AR_CUST_CLASS_DSCNT), CTGRY (AR_CTGRY_DSCNT), CUST (AR_CUST_DSCNT)
  procedure dscnt_row (p_kind in varchar2, p_ins in boolean, p_owner in number, p_period in number, p_prcnt in number, p_value in number) is
    l_n number;
  begin
    select count(*) into l_n from ar_period where serial = p_period;
    if l_n = 0 then err('مسلسل الفترة غير موجود في ملف فترات أيام الخصم', 'Period serial not found'); end if;
    if p_kind = 'CUST' then
      if nvl(p_prcnt, 0) < 0 or nvl(p_prcnt, 0) >= 100 then
        err('نسبة الخصم يجب ان تكون اكبر من الصفر و اقل من 100', 'The discount ratio should be over than zero and less than 100');
      end if;
      if nvl(p_value, 0) < 0 then
        err('قيمة الخصم يجب ان تكون اكبر من الصفر و اقل من 100', 'The discount value should be over than zero and less than 100');
      end if;
      select count(*) into l_n from ar_maintrns where customer_id = p_owner;
      if l_n > 0 then
        err('لا يمكن تعديل ملف العميل بينما هناك حركات تم إدخالها من قبل', 'You can''t change the customer file while transactions exist ');
      end if;
    else
      if p_prcnt >= 100 then
        err('نسبة الخصم لا يمكن ان تكون اكبر من او تساوى 100', 'Discount percent cannot be 100 or more');
      end if;
      if p_value < 0 or p_value > 99999.99 then
        err('قيمة الخصم لا يمكن ان تكون اقل من الصفر او اكبر من 99999.99', 'Discount value cannot be less than zero or greater than 99999.99');
      end if;
    end if;
    if p_ins then
      if p_kind = 'CLASS' then
        select count(*) into l_n from ar_cust_class_dscnt where serial = p_owner and period_serial = p_period;
        if l_n > 0 then err('شريحة الخصم مكررة لنفس الفئة', 'Discount period repeated for the same class'); end if;
      elsif p_kind = 'CTGRY' then
        select count(*) into l_n from ar_ctgry_dscnt where ctgry_code = p_owner and period_serial = p_period;
        if l_n > 0 then err('سجل تم إدخاله من قبل.', 'Record already entered.'); end if;
      elsif p_kind = 'CUST' then
        select count(*) into l_n from ar_cust_dscnt where customer_code = p_owner and period_serial = p_period;
        if l_n > 0 then err('شريحة الخصم مكررة لنفس العميل', 'Discount period is repeated for the same customer'); end if;
      end if;
    end if;
  end dscnt_row;

  procedure ctgry_type_row (p_code in number) is
  begin
    if is_form('AR_DEPT_DISC') and p_code <= 0 then
      err('رقم القسم لا يمكن ان يكون صفر او اقل', 'Department number cannot be zero or less');
    end if;
  end ctgry_type_row;

  -- delete of a department's detail row by the "delete document" cascade of that screen
  procedure ctgry_type_child_del (p_form in varchar2) is
  begin
    if doc_delete(p_form) then master_has_details; end if;
  end ctgry_type_child_del;

  -- =================================================================================== COMPLAINT_CUSTOMER
  procedure complaint_mast_row (p_customer in number) is
    l_n number;
  begin
    select count(*) into l_n from customer where code = p_customer and nvl(customer_status, 0) = 1 and nvl(stopflag, 0) <> 1;
    if l_n = 0 then err('خطء في رقم العميل', 'Invalid customer number'); end if;
  end complaint_mast_row;

  procedure complaint_det_row (p_code in number) is
    l_n number;
  begin
    select count(*) into l_n from complaint_codes where complaint_code = p_code;
    if l_n = 0 then err('خطء في رقم المشكلة', 'Invalid complaint code'); end if;
  end complaint_det_row;

  -- =================================================================================== ARTRNSTYPE
  procedure trnstype_row (p_id in number, p_effect in number, p_trns_type in number, p_joint in number, p_entry_type in number,
                          p_acc_type in number, p_cust_acc_type in number, p_disc_acc_type in number,
                          p_account in number, p_cust_account in number, p_disc_account in number,
                          p_cost_type in number, p_cost2_type in number) is
    l_n number;
  begin
    if (p_trns_type = 0 and nvl(p_effect, -1) != 0) or (p_trns_type in (1, 3) and nvl(p_effect, -1) != 1) then
      err('نوع الحركة غير متوافق مع تأثير الحركة على العميل', 'The transaction type does not match its effect on the customer');
    end if;
    if nvl(p_joint, 0) = 1 then
      if p_entry_type is null then err('يجب إدخال نوع القيد المحاسبى', 'Enter the voucher type'); end if;
      if p_acc_type is null or p_cust_acc_type is null or p_disc_acc_type is null or p_cost_type is null or p_cost2_type is null then
        err('يجب إدخال كل انوع التوجيهات المحاسبية', 'Enter all the accounting directions');
      end if;
    end if;
    if p_entry_type is not null then
      select count(*) into l_n from ac_trn_codes where entry_type = p_entry_type;
      if l_n = 0 then err('نوع قيد الحسابات غير موجود', 'Voucher type not found'); end if;
    end if;
    if p_acc_type = 4 and p_account is null then err('يجب إدخال حساب نوع الحركة', 'Enter the transaction type account'); end if;
    if p_cust_acc_type = 4 and p_cust_account is null then err('يجب إدخال حساب العميل', 'Enter the customer account'); end if;
    if p_disc_acc_type = 4 and p_disc_account is null then err('يجب إدخال حساب الخصم', 'Enter the discount account'); end if;
    if p_account in (p_cust_account, p_disc_account) then
      err('لا يمكن تكرار رقم حساب نوع الحركة مع الحسابات الاخرى', 'The type account cannot repeat another account');
    end if;
    if p_cust_account = p_disc_account then
      err('لا يمكن تكرار رقم حساب العميل مع الحسابات الاخرى', 'The customer account cannot repeat another account');
    end if;
    check_account(p_account); check_account(p_cust_account); check_account(p_disc_account);
  end trnstype_row;

  procedure trnstype_dscnt_row (p_ins in boolean, p_id in number, p_period in number, p_prcnt in number, p_value in number) is
    l_n number;
  begin
    select count(*) into l_n from ar_period where serial = p_period;
    if l_n = 0 then err('مسلسل الفترة غير موجود في ملف فترات أيام الخصم', 'Period serial not found'); end if;
    if p_ins then
      select count(*) into l_n from ar_trnstype_dscnt where id = p_id and period_serial = p_period;
      if l_n > 0 then err('شريحة الخصم مكررة لنفس نوع الحركة', 'Discount period repeated for the same transaction type'); end if;
    end if;
  end trnstype_dscnt_row;


  -- =================================================================================== CUSTOMER
  -- DETECT_CUST_LEVEL: the level is the last structure level whose part of the 12-digit code is not zero; a non-zero part
  -- after a zero part is refused (MSG in the legacy form)
  function cust_level (p_code in number) return number is
    l_code  varchar2(40) := to_char(p_code);
    l_level number := 0;
    l_seg   number;
    l_rest  number;
    l_n     number;
  begin
    select count(*) into l_n from ar_chart_structures;
    if l_n = 0 then err('يجب ادخال هيكل العملاء', 'Enter the customer code structure first'); end if;
    for s in (select chr_stru_level lvl, chr_stru_start st, length len from ar_chart_structures order by chr_stru_level) loop
      l_seg := to_number(nvl(substr(l_code, s.st, s.len), '0'));
      if l_seg = 0 then
        l_rest := to_number(nvl(substr(l_code, s.st + s.len), '0'));
        if l_rest > 0 then
          err('رقم العميل غير متوافق مع هيكل دليل العملاء', 'The customer code does not match the customer code structure');
        end if;
        exit;
      end if;
      l_level := s.lvl;
    end loop;
    return l_level;
  end cust_level;

  function cust_parent (p_code in number, p_level in number) return number is
    l_end number;
  begin
    if nvl(p_level, 0) <= 1 then return null; end if;
    select chr_stru_end into l_end from ar_chart_structures where chr_stru_level = p_level - 1;
    return to_number(rpad(substr(to_char(p_code), 1, l_end), 12, '0'));
  end cust_parent;

  procedure customer_row (p_ins in boolean, p_code in out number, p_old_code in number, p_level in out number,
                          p_status in out number, p_type in number, p_customer_id in number, p_company_id in number,
                          p_registry_id in number, p_tel1 in varchar2, p_tel2 in varchar2, p_tel3 in varchar2, p_fax in varchar2,
                          p_day_no in number, p_credit in number, p_stop in number, p_stop_date in out date, p_stop_reason in out varchar2,
                          p_main in number, p_old_main in number, p_sub in number, p_old_sub in number, p_class in number,
                          p_account in number, p_disc in number, p_cost1 in number, p_cost2 in number,
                          p_currency in number, p_old_currency in number, p_open_date in date,
                          p_old_open_date in date default null, p_old_stop_date in date default null) is
    l_n      number;
    l_parent number;
    l_msg    varchar2(4000);
  begin
    if p_ins then
      -- CODE WHEN-VALIDATE-ITEM: 12 digits, level, parent must exist, duplicate, leaf status
      p_code := to_number(rpad(to_char(p_code), 12, '0'));
      p_level := cust_level(p_code);
      if p_level > 1 then
        l_parent := cust_parent(p_code, p_level);
        select count(*) into l_n from customer where code = l_parent;
        if l_n = 0 then err('عميل غير موجود', 'Parent customer not found: ' || l_parent); end if;
      end if;
      select count(*) into l_n from customer where code = p_code;
      if l_n > 0 then err('رقم مكرر', 'Customer code already exists'); end if;
      p_status := 1;
      -- PRE-INSERT: identity / membership number repeated (CUSTOMER_TYPE 0 person, 1 company)
      if p_type = 0 and p_customer_id is not null then
        select count(*) into l_n from customer where customer_id = p_customer_id;
        if l_n > 0 then err('رقم هوية مكرر', 'Personal Id Repeated'); end if;
      elsif p_type = 1 and p_company_id is not null then
        select count(*) into l_n from customer where company_id = p_company_id;
        if l_n > 0 then err('رقم عضوية مكرر', 'Company Id Repeated'); end if;
      end if;
    else
      -- PRE-UPDATE: code / area / branch / currency cannot change once the customer has transactions; the currency is closed
      -- as soon as AR, opening balance or stock transactions exist (WHEN-NEW-RECORD-INSTANCE -> CURRENCY('CLOSE'))
      if nvl(p_code, -1) != nvl(p_old_code, -1) or nvl(p_main, -1) != nvl(p_old_main, -1) or nvl(p_sub, -1) != nvl(p_old_sub, -1)
         or nvl(p_currency, -1) != nvl(p_old_currency, -1) then
        select count(*) into l_n from ar_maintrns where customer_id = p_old_code;
        if l_n = 0 and nvl(p_currency, -1) != nvl(p_old_currency, -1) then
          select count(*) into l_n from dual
           where exists (select 1 from ar_subtrns_op where customer_id = p_old_code)
              or exists (select 1 from st_trns_mast where customer_code = p_old_code);
        end if;
        if l_n > 0 then
          err('هذا العميل تم ادخال حركات عليه من قبل و لذلك لا يمكن تغير هذه الحقول . كود العميل - المنطقة الرئيسية - المنطقة الفرعية - العملة- حساب العميل - حساب الخصم و مراكز التكلفة',
              'You can''t edit the customer file while transactions exist ');
        end if;
      end if;
    end if;
    -- WHEN-VALIDATE-ITEM checks
    l_msg := coalesce(phone_msg(p_tel1), phone_msg(p_tel2), phone_msg(p_tel3), phone_msg(p_fax, 'F'));
    if l_msg is not null then err(l_msg, l_msg); end if;
    if nvl(p_day_no, 0) < 0 then
      err('عدد أيام السماح لعميل يجب ان يكون اكبر من الصفر', 'The customer days limit should be over than zero');
    end if;
    if nvl(p_credit, 0) < 0 then
      err('حد الإئتمان لعميل يجب ان يكون اكبر من الصفر', 'The customer credit limit should be over than zero');
    end if;
    if p_company_id <= 0 then err('رقم العضوية يجب ان يكون اكبر من الصفر', 'The Company Id should be over than zero'); end if;
    if p_customer_id <= 0 then err('رقم الهوية يجب ان يكون اكبر من الصفر', 'The customer Id should be over than zero'); end if;
    if p_registry_id <= 0 then err('رقم السجل يجب ان يكون اكبر من الصفر', 'The Company Registry Id should be over than zero'); end if;
    if p_main is null then err('يجب إدخال المنطقة', 'Field Must Be Entered: area'); end if;
    if p_sub is null then err('يجب إدخال الفرع', 'Field Must Be Entered: branch'); end if;
    if p_class is null then err('يجب إدخال فئة العميل', 'Field Must Be Entered: customer class'); end if;
    select count(*) into l_n from ar_subarea where main_id = p_main and id = p_sub;
    if l_n = 0 then err('الفرع غير موجود في المنطقة', 'Branch not found in the area'); end if;
    select count(*) into l_n from ar_cust_class where serial = p_class and nvl(dscnt_stop_flag, 0) = 0;
    if l_n = 0 then err('فئة العميل غير موجودة أو موقوفة', 'Customer class not found or stopped'); end if;
    if p_account = p_disc then err('لا يمكن تكرار رقم الحساب ', '  Can''t repeat account number     '); end if;
    check_account(p_account); check_account(p_disc);
    if p_cost1 is not null then
      select count(*) into l_n from ac_cost_centers where cost_code = p_cost1 and cost_status = 1;
      if l_n = 0 then err('مركز تكلفة 1 غير موجود', 'Cost centre 1 not found'); end if;
    end if;
    if p_cost2 is not null then
      select count(*) into l_n from ac_cost_centers2 where cost_code = p_cost2 and cost_status = 1;
      if l_n = 0 then err('مركز تكلفة 2 غير موجود', 'Cost centre 2 not found'); end if;
    end if;
    -- STOPFLAG / PRE-INSERT / PRE-UPDATE: not stopped -> no stop date / reason; stopped -> stop date defaults to today
    if nvl(p_stop, 0) = 0 then
      p_stop_date := null; p_stop_reason := null;
    elsif p_stop_date is null then
      p_stop_date := sysdate;
    end if;
    -- CHECK_DATE ran in WHEN-VALIDATE-ITEM, i.e. only for a date the user entered (01-01-1000 is the column default)
    if p_stop_date >= date '1900-01-01' and (p_ins or trunc(p_stop_date) != nvl(trunc(p_old_stop_date), date '0001-01-01')) then
      l_msg := check_date_msg(p_stop_date);
    end if;
    if l_msg is null and p_open_date >= date '1900-01-01' and (p_ins or trunc(p_open_date) != nvl(trunc(p_old_open_date), date '0001-01-01')) then
      l_msg := check_date_msg(p_open_date);
    end if;
    if l_msg is not null then err(l_msg, l_msg); end if;
  end customer_row;

  -- KEY-DELREC: a parent customer (status 0) and a customer with transactions / opening balances cannot be deleted
  procedure customer_del (p_code in number, p_status in number) is
    l_n number;
  begin
    if p_status = 0 then err('العميل رئيسي بالفعل', 'This customer is a parent customer'); end if;
    select count(*) into l_n from ar_maintrns where customer_id = p_code;
    if l_n > 0 then
      err('لا يمكن ملف العميل بينما هناك حركات تم إدخالها من قبل', 'You can''t change the customer file while transactions exist ');
    end if;
    select count(*) into l_n from ar_subtrns_op where customer_id = p_code;
    if l_n > 0 then
      err(' توجد حركات أفتتاحية تم ادخالها من قبل ', 'You can''t change the customer file while transactions exist ');
    end if;
  end customer_del;

  function customer_snapshot (p_rowid in varchar2) return varchar2 is
  begin
    g_cust_sum := null; g_cust_limit := null;
    if p_rowid is not null then
      select c.credit_limit, (select sum(s.credit_limit) from ar_cust_salesman s where s.customer_code = c.code)
        into g_cust_limit, g_cust_sum
        from customer c where rowid = chartorowid(p_rowid);
    end if;
    return null;
  exception when no_data_found then return null;
  end customer_snapshot;

  -- after the customer and its detail grids are saved:
  --   CREATE: POST-INSERT - the parent customer is no longer a leaf (CUSTOMER_STATUS 0)
  --   SAVE  : PRE-INSERT "لابد من ادخال قسم للعميل"; credit limits of the salesmen (AR_CUST_SALESMAN.CREDIT_LIMIT WHEN-VALIDATE-ITEM,
  --           PRE-INSERT) must not exceed the customer's limit when either was changed; the customer account defaults to the
  --           account of the department in the branch (AR_CUST_SALESMAN.CTGRY_CODE WHEN-VALIDATE-ITEM -> AR_CTGRY_SUBAREA)
  --   DELETE: POST-DELETE - the parent becomes a leaf again when it has no other children
  procedure customer_after (p_request in varchar2, p_rowid in varchar2, p_code in varchar2, p_level in varchar2) is
    l_c      customer%rowtype;
    l_n      number;
    l_sum    number;
    l_parent number;
  begin
    if p_request = 'DELETE' then
      if num(p_level) > 1 then
        l_parent := cust_parent(num(p_code), num(p_level));
        select count(*) into l_n from customer where code != num(p_code)
           and code != l_parent and customer_level = num(p_level)
           and cust_parent(code, customer_level) = l_parent;
        if l_n = 0 then update customer set customer_status = 1 where code = l_parent; end if;
      end if;
      return;
    end if;
    select * into l_c from customer where rowid = chartorowid(p_rowid);
    if p_request = 'CREATE' then
      if l_c.customer_level > 1 then
        update customer set customer_status = 0 where code = cust_parent(l_c.code, l_c.customer_level);
      end if;
      return;
    end if;
    select count(*), sum(credit_limit) into l_n, l_sum from ar_cust_salesman where customer_code = l_c.code;
    if l_n = 0 then err('لابد من ادخال قسم للعميل', 'You Should Insert Dept. for Customer'); end if;
    if l_sum > l_c.credit_limit and (nvl(l_sum, -1) != nvl(g_cust_sum, -1) or nvl(l_c.credit_limit, -1) != nvl(g_cust_limit, -1)) then
      err('مجموع حد الائتمان لابد أن يكون أقل من أو مساويا لحد ائتمان العميل',
          'The sum of the credit limits must be less than or equal the customer credit limit');
    end if;
    if l_c.account_no is null then
      update customer c
         set account_no = (select min(a.account_no) keep (dense_rank first order by s.ctgry_code)
                             from ar_cust_salesman s, ar_ctgry_subarea a
                            where s.customer_code = c.code and a.mainarea_id = c.mainarea_id and a.subarea_id = c.subarea_id
                              and a.ctgry_code = s.ctgry_code and a.account_no is not null)
       where rowid = chartorowid(p_rowid);
    end if;
  end customer_after;

  -- values the legacy screen displayed (POST-QUERY, CALC_UPT_INFO)
  function cust_info (p_code in varchar2, p_what in varchar2) return varchar2 is
    l_code   number := num(p_code);
    l_bal    number;
    l_rate   number;
    l_f      date;
    l_e      date;
    l_sls    number;
    l_ret    number;
    l_col    number;
    function f (n in number) return varchar2 is
    begin
      return to_char(n, 'FM999G999G999G990D00');
    end f;
  begin
    if l_code is null then return null; end if;
    if p_what in ('BAL', 'BAL_LOC', 'IND') then
      l_bal := get_customer_bal(l_code);
      select max(nvl(cu.rate, 1)) into l_rate from customer c, ac_currency cu where cu.currency_code (+) = c.currency_code and c.code = l_code;
      if p_what = 'BAL' then return f(l_bal); end if;
      if p_what = 'BAL_LOC' then return f(l_bal * nvl(l_rate, 1)); end if;
      return case when l_bal < 0 then msg('دائــن', 'Credit') else msg('مديــن', 'Debit') end;
    end if;
    if p_what = 'BEG' then
      select max(beg_bal) into l_bal from customer where code = l_code;
      return f(l_bal) || ' ' || case when l_bal < 0 then msg('دائــن', 'Credit') else msg('مديــن', 'Debit') end;
    end if;
    select min(d.trns_date), max(d.trns_date),
           sum(decode(tt.effect, 2, 1, 0) * d.unit_price * d.quantity), sum(decode(tt.effect, 4, 1, 0) * d.unit_price * d.quantity)
      into l_f, l_e, l_sls, l_ret
      from st_trns_mast_det d, st_trns_type tt
     where d.trns_type_code = tt.trns_type_code
       and ((tt.effect = 2 and tt.trns_type = 2) or (tt.effect = 4 and tt.trns_type = 4))
       and d.customer_code = l_code;
    if p_what = 'FIRST' then return to_char(l_f, 'DD/MM/YYYY'); end if;
    if p_what = 'LAST' then return to_char(l_e, 'DD/MM/YYYY'); end if;
    if p_what = 'DAYS' then return to_char(l_e + 1 - l_f); end if;
    if p_what = 'SALES' then return f(l_sls); end if;
    if p_what = 'RETURNS' then return f(l_ret); end if;
    if l_f is null then return null; end if;
    if p_what = 'AVG_SALES_M' then return f(l_sls / nullif(months_between(l_e + 1, l_f), 0)); end if;
    if p_what = 'AVG_RET_M' then return f(l_ret / nullif(months_between(l_e + 1, l_f), 0)); end if;
    if p_what = 'AVG_SALES_D' then return f(l_sls / nullif(l_e + 1 - l_f, 0)); end if;
    if p_what = 'AVG_RET_D' then return f(l_ret / nullif(l_e + 1 - l_f, 0)); end if;
    select sum(m.total_value) into l_col from ar_maintrns m, ar_trnstype t
     where m.customer_id = l_code and m.trns_id = t.id and t.effect = 1 and t.trns_type = 3;
    if p_what = 'COLL' then return f(l_col); end if;
    if p_what = 'AVG_COLL_D' then return f(l_col / nullif(l_e + 1 - l_f, 0)); end if;
    return null;
  end cust_info;

  -- =================================================================================== AR_CUST_SALESMAN / AR_CUST_RESP / AR_CUST_DSCNT
  function need_salesman_code return number is
  begin
    err('رقم المندوب المدخل غير موجود فى القسم المختار', 'The sales man code is not located in the selected department');
    return null;
  end need_salesman_code;

  procedure cust_salesman_row (p_ins in boolean, p_customer in number, p_ctgry in number, p_salesman in number, p_credit in number,
                               p_old_salesman in number, p_old_ctgry in number, p_mngr1 in number, p_mngr2 in number, p_mrch in number) is
    l_n number;
  begin
    select count(*) into l_n from salesman sm, ar_ctgry_salesman cs
     where sm.code = cs.salesman_code and cs.ctgry_code = p_ctgry and sm.code = p_salesman;
    if l_n < 1 then
      err('رقم المندوب المدخل غير موجود فى القسم المختار', 'The sales man code is not located in the selected department');
    end if;
    if nvl(p_credit, 0) < 0 then err('حد الإئتمان يجب ان يكون اكبر من الصفر', 'The credit limit should be over than zero'); end if;
    check_salesman(p_mngr1); check_salesman(p_mngr2); check_salesman(p_mrch);
    if p_ins then
      select count(*) into l_n from ar_cust_salesman where ctgry_code = p_ctgry and customer_code = p_customer and salesman_code = p_salesman;
      if l_n > 0 then err('القسم و المندوب تم إدخالهم من قبل.', 'Division and Salesman has been entered before.'); end if;
      if is_form('AR_SALESMAN') then
        -- the salesman screen offers only customers that have no salesman yet (CUSTOMER_LOV: CODE NOT IN AR_CUST_SALESMAN)
        select count(*) into l_n from ar_cust_salesman where customer_code = p_customer;
        if l_n > 0 then err('العميل مرتبط بمندوب اخر', 'The customer is linked to another salesman'); end if;
        select count(*) into l_n from customer where code = p_customer and nvl(customer_status, 0) = 1;
        if l_n = 0 then err('رقم العميل غير موجود', 'Customer not found'); end if;
      end if;
    elsif is_form('AR_SALESMAN') and (p_salesman != p_old_salesman or p_ctgry != p_old_ctgry) then
      select count(*) into l_n from ar_maintrns where customer_id = p_customer;
      if l_n > 0 then
        err('لا يمكن تعديل ملف العميل بينما هناك حركات تم إدخالها من قبل', 'You can''t change the customer file while transactions exist ');
      end if;
    end if;
  end cust_salesman_row;

  -- KEY-DELREC / PRE-DELETE of AR_CUST_SALESMAN; ON-CHECK-DELETE-MASTER of the customer and of the salesman
  procedure cust_salesman_del (p_customer in number, p_ctgry in number, p_salesman in number) is
    l_n number;
  begin
    if doc_delete('CUSTOMER') or doc_delete('AR_SALESMAN') then master_has_details; end if;
    select count(*) into l_n from ar_maintrns where salesman_id = p_salesman and customer_id = p_customer;
    if l_n > 0 then
      err('لايمكنك حذف هذا المندوب لأنه مرتبط مع العميل في إحدى الحركات',
          'You cant delete this salesman because he is joined to a transaction with the customer');
    end if;
    select count(*) into l_n from st_sales_order where customer_code = p_customer and salesman_code = p_salesman;
    if l_n > 0 then
      err('لا يمكن تعديل ملف العميل بينما هناك حركات تم إدخالها من قبل', 'You can''t change the customer file while transactions exist ');
    end if;
  end cust_salesman_del;

  function next_cust_resp_code return number is
    l_n number;
  begin
    select nvl(max(resp_code), 0) + 1 into l_n from ar_cust_resp;
    return l_n;
  end next_cust_resp_code;

  procedure cust_dscnt_del (p_customer in number) is
    l_n number;
  begin
    if doc_delete('CUSTOMER') then master_has_details; end if;
    select count(*) into l_n from ar_maintrns where customer_id = p_customer;
    if l_n > 0 then
      err('لا يمكن تعديل ملف العميل بينما هناك حركات تم إدخالها من قبل', 'You can''t change the customer file while transactions exist ');
    end if;
  end cust_dscnt_del;

  procedure cust_child_del is
  begin
    if doc_delete('CUSTOMER') then master_has_details; end if;
  end cust_child_del;

  -- =================================================================================== AR_SALESMAN
  procedure check_st_type (p_type in number, p_effect in number, p_trns_type in number) is
    l_n number;
  begin
    if p_type is null then return; end if;
    select count(*) into l_n from st_trns_type where trns_type_code = p_type and nvl(effect, 0) = p_effect and trns_type = p_trns_type;
    if l_n = 0 then err('رقم الحركة غير صحيح: ' || p_type, 'Invalid transaction type: ' || p_type); end if;
  end check_st_type;

  procedure salesman_row (p_code in number, p_disc_ratio in number, p_store in number, p_customer in number, p_old_customer in number,
                          p_users in number, p_account in number, p_cost1 in number, p_cost2 in number, p_supervisor in number,
                          p_issue in number, p_return in number, p_order in number, p_trnsfr in number, p_trnsfr_to in number,
                          p_pay1 in number, p_pay2 in number, p_pay3 in number, p_main in number, p_sub in number, p_ctgry in number) is
    l_n number;
  begin
    if p_code <= 0 then err('رقم المندوب يجب ان يكون اكبر من الصفر', 'Salesman code must be greater than zero'); end if;
    if p_disc_ratio < 0 or p_disc_ratio >= 100 then
      err('النسبة يجب ان تكون اكبر من الصفر و اقل من 100', 'The ratio must be between zero and 100');
    end if;
    if p_store is not null then
      select count(*) into l_n from st_store where store_code = p_store and nvl(stop_flag, 0) = 0 and nvl(store_status, 0) = 1;
      if l_n = 0 then err('رقم المخزن غير موجود أو موقوف', 'Store not found or stopped'); end if;
    end if;
    if p_customer is not null and nvl(p_customer, -1) != nvl(p_old_customer, -1) then
      select count(*) into l_n from customer where code = p_customer and nvl(customer_status, 0) = 1
         and code not in (select ss.customer_code from ar_cust_salesman ss);
      if l_n = 0 then err('رقم العميل غير موجود أو مرتبط بمندوب', 'Customer not found or already linked to a salesman'); end if;
    end if;
    if p_users is not null then
      select count(*) into l_n from users where users_code = p_users;
      if l_n = 0 then err('رقم المستخدم غير موجود', 'User not found'); end if;
    end if;
    check_account(p_account);
    if p_cost1 is not null then
      select count(*) into l_n from ac_cost_centers where cost_code = p_cost1 and cost_status = 1;
      if l_n = 0 then err('مركز تكلفة 1 غير موجود', 'Cost centre 1 not found'); end if;
    end if;
    if p_cost2 is not null then
      select count(*) into l_n from ac_cost_centers2 where cost_code = p_cost2 and cost_status = 1;
      if l_n = 0 then err('مركز تكلفة 2 غير موجود', 'Cost centre 2 not found'); end if;
    end if;
    check_salesman(p_supervisor);
    check_st_type(p_issue, 2, 2); check_st_type(p_return, 4, 4); check_st_type(p_order, 7, 30);
    check_st_type(p_trnsfr, 5, 9); check_st_type(p_trnsfr_to, 6, 9);
    for r in (select column_value t from table(sys.odcinumberlist(p_pay1, p_pay2, p_pay3)) where column_value is not null) loop
      select count(*) into l_n from ar_trnstype where id = r.t and effect = 1 and trns_type <> 6 and nvl(mobile_trns, 0) = 1;
      if l_n = 0 then err('رقم حركة السداد غير صحيح: ' || r.t, 'Invalid payment transaction type: ' || r.t); end if;
    end loop;
    if p_main is not null or p_sub is not null then
      select count(*) into l_n from ar_subarea where main_id = p_main and id = p_sub;
      if l_n = 0 then err('الفرع غير موجود في المنطقة', 'Branch not found in the area'); end if;
    end if;
  end salesman_row;

  procedure ctgry_salesman_row (p_ins in boolean, p_salesman in number, p_ctgry in number) is
    l_n number;
  begin
    select count(*) into l_n from st_category_type where category_type_code = p_ctgry;
    if l_n = 0 then err('رقم القسم غير موجود', 'Department not found'); end if;
    if p_ins then
      select count(*) into l_n from ar_ctgry_salesman where salesman_code = p_salesman and ctgry_code = p_ctgry;
      if l_n > 0 then err('هذا القسم تم تخصيصه للمندوب من قبل', 'This department is already assigned to the salesman'); end if;
    end if;
  end ctgry_salesman_row;

  -- ON-CHECK-DELETE-MASTER of SALESMAN (AR_CTGRY_SALESMAN); a department still used by the salesman's customers stays
  procedure ctgry_salesman_del (p_salesman in number, p_ctgry in number) is
    l_n number;
  begin
    if doc_delete('AR_SALESMAN') then master_has_details; end if;
    select count(*) into l_n from ar_cust_salesman where salesman_code = p_salesman and ctgry_code = p_ctgry;
    if l_n > 0 then master_has_details; end if;
  end ctgry_salesman_del;

  procedure salesman_store_row (p_ins in boolean, p_salesman in number, p_store in number) is
    l_n number;
  begin
    select count(*) into l_n from st_store where store_code = p_store and nvl(stop_flag, 0) = 0 and nvl(store_status, 0) = 1
       and (nvl(grp, 0) = 0 or store_code in (select store_code from st_store_password where password_number = grp));
    if l_n = 0 then err('رقم المخزن غير موجود أو موقوف', 'Store not found or stopped'); end if;
  end salesman_store_row;

  procedure salesman_account_row (p_ins in boolean, p_salesman in number, p_account in number, p_cost1 in number, p_cost2 in number) is
    l_n number;
  begin
    check_account(p_account);
    if p_ins then
      select count(*) into l_n from ar_salesman_account
       where salesman_id = p_salesman and salesman_account_no = p_account and salesman_cost_code = p_cost1 and salesman_cost_code2 = p_cost2;
      if l_n > 0 then err('تم ادخال الحساب ومراكز التكلفة من قبل', 'The account and cost centres were entered before'); end if;
    end if;
  end salesman_account_row;

  procedure salesman_account_del (p_salesman in number, p_account in number, p_cost1 in number, p_cost2 in number) is
    l_n number;
  begin
    if doc_delete('AR_SALESMAN') then return; end if;          -- legacy: DELETE FROM AR_SALESMAN_ACCOUNT with the salesman
    select count(*) into l_n from rp_trns_det_ac d, rp_trns_mast m
     where m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial and m.salesman_code = p_salesman
       and d.account_no = p_account and d.cost_center1 = p_cost1 and d.cost_center2 = p_cost2;
    if l_n > 0 then
      err('لا يمكن حذف ملف الحركة بينما هناك حركات من الصناديق تم إدخالها من قبل', 'Cannot delete: cash box transactions exist');
    end if;
  end salesman_account_del;

  function next_book_serial return number is
    l_n number;
  begin
    select nvl(max(nvl(book_serial, 0)), 0) + 1 into l_n from ar_salesman_books;
    return l_n;
  end next_book_serial;

  procedure book_row (p_ins in boolean, p_salesman in number, p_serial in number, p_from in number, p_to in number, p_type in number) is
    l_n number;
  begin
    if p_from > p_to then err('من سند يجب أن يكون أقل من الي سند', 'From receipt must be less than to receipt'); end if;
    if p_ins then
      select count(*) into l_n from ar_salesman_books where book_serial = p_serial;
      if l_n > 0 then err('كود مكرر من قبل', 'Code already exists'); end if;
      select count(*) into l_n from ar_salesman_books
       where salesman_code = p_salesman and book_type = 1
         and (from_serial between p_from and p_to or to_serial between p_from and p_to
              or p_from between from_serial and to_serial or p_to between from_serial and to_serial);
      if l_n > 0 then err('أرقام السندات تتقاطع مع سندات مدخلة', 'The receipt numbers overlap another receipt book'); end if;
    end if;
  end book_row;

  procedure book_del (p_salesman in number, p_serial in number) is
    l_n number;
  begin
    if doc_delete('AR_SALESMAN') then return; end if;          -- legacy: DELETE FROM AR_SALESMAN_BOOKS with the salesman
    select count(*) into l_n from ar_salesman_books_det where salesman_code = p_salesman and book_serial = p_serial;
    if l_n > 0 then master_has_details; end if;
  end book_del;

  procedure book_det_row (p_ins in boolean, p_salesman in number, p_serial in number, p_book_no in number) is
    l_n number;
  begin
    select count(*) into l_n from ar_salesman_books
     where salesman_code = p_salesman and book_serial = p_serial and p_book_no between from_serial and to_serial;
    if l_n = 0 then err('هذا السند غير موجود بالدفتر', 'This receipt number is not in the book'); end if;
    if p_ins then
      select count(*) into l_n from ar_salesman_books_det where salesman_code = p_salesman and book_serial = p_serial and book_no = p_book_no;
      if l_n > 0 then err('رقم السند مسجل بالفعل بالسندات المدخلة', 'The receipt number is already registered'); end if;
    end if;
    select count(*) into l_n from ar_maintrns where book_no = p_book_no and salesman_id = p_salesman and book_serial = p_serial;
    if l_n > 0 then err('السند مربوط بنظام العملاء', 'The receipt is used by a customer transaction'); end if;
    select count(*) into l_n from check_mast
     where salesman_book_no = p_book_no and salesman_code = p_salesman and salesman_book_serial = p_serial and nvl(del_flag, 0) = 0;
    if l_n > 0 then err('السند مربوط بنظام الشيكات', 'The receipt is used by a cheque'); end if;
  end book_det_row;


  -- =================================================================================== ARTRN_OP (customer opening balances)
  function op_default_type return number is
    l_id number;
  begin
    select min(id) into l_id from ar_trnstype where trns_type = 6 and effect = 0
       and (nvl(grp, 0) = 0 or id in (select trns_id from ar_trnstype_password where flag = 1 and password_number = grp));
    return l_id;
  end op_default_type;

  procedure op_mast_row (p_ins in boolean, p_trns_id in number, p_serial in number, p_date in date, p_doc_no in number,
                         p_desc_a in out varchar2, p_desc_e in out varchar2, p_old_trns_id in number, p_old_serial in number) is
    l_n      number;
    l_min    date;
    l_t      ar_trnstype%rowtype;
    l_msg    varchar2(4000);
  begin
    begin
      select * into l_t from ar_trnstype where id = p_trns_id and trns_type = 6;
    exception when no_data_found then
      err('رقم الحركة ليس من حركات الأرصدة الإفتتاحية', 'Not an opening balance transaction type');
    end;
    if nvl(grp, 0) != 0 then
      select count(*) into l_n from ar_trnstype_password where flag = 1 and password_number = grp and trns_id = p_trns_id;
      if l_n = 0 then err('خطأ صلاحية', 'Permission error'); end if;
    end if;
    if not p_ins and (p_trns_id != p_old_trns_id or p_serial != p_old_serial) then
      select count(*) into l_n from ar_subtrns_op where trns_id = p_old_trns_id and trns_serial = p_old_serial;
      if l_n > 0 then err('لا يمكن إلغاء سجل رئيسي في و جود سجلات تابعة له', 'The type cannot change while lines exist'); end if;
    end if;
    -- TRNS_DATE: not before AR_BASIC.MIN_DATE, not after today
    select max(min_date) into l_min from ar_basic where company_code = nvl(to_number(v('G_COMPANY_CODE')), company_code);
    if l_min is not null and trunc(p_date) < trunc(l_min) then
      err('التاريخ أقل من الحد الأدنى المسموح به', 'The date is before the minimum allowed date');
    end if;
    l_msg := check_date_msg(p_date);
    if l_msg is not null then err(l_msg, l_msg); end if;
    if p_doc_no <= 0 then
      err('رقم المستند لا يمكن ان يكون اقل من او يساوي الصفر', 'Document number cannot be zero or less');
    end if;
    -- initial description of the type (DESC_FLAG / INITIAL_DESC / PLUS_DOC_NO_FLAG)
    if p_ins and p_desc_a is null and nvl(l_t.desc_flag, 0) = 1 and l_t.initial_desc is not null then
      p_desc_a := l_t.initial_desc || case when nvl(l_t.plus_doc_no_flag, 0) = 1 and p_doc_no is not null then ' ' || p_doc_no end;
    end if;
  end op_mast_row;

  -- customer balance fields maintained by the legacy form (CUSTOMER.CRN_BAL_TOTAL / BEG_BAL, AR_CUST_SALESMAN.CRN_BAL_TOTAL)
  procedure op_balances (p_effect in number, p_value in number, p_customer in number, p_salesman in number, p_ctgry in number,
                         p_sign in number) is
    l_v number := case when p_effect = 0 then p_value else -p_value end;
  begin
    if p_sign = 1 then
      update customer set crn_bal_total = nvl(crn_bal_total, 0) + l_v, beg_bal = l_v where code = p_customer;
    else
      update customer set crn_bal_total = nvl(crn_bal_total, 0) - l_v, beg_bal = 0 where code = p_customer;
    end if;
    update ar_cust_salesman set crn_bal_total = nvl(crn_bal_total, 0) + p_sign * l_v
     where customer_code = p_customer and salesman_code = p_salesman and ctgry_code = p_ctgry;
  end op_balances;

  -- the generated customer transaction (AR_MAINTRNS, plus the invoice bill AR_SUBTRNS of a debit balance) may be replaced
  -- only while nothing was allocated or posted on it, and "لا يمكن تعديل رصيد افتتاحي للعميل بينما هناك حركات تم إدخالها من قبل"
  procedure op_check_change (p_trns_id in number, p_r_serial in number, p_customer in number, p_date in date) is
    l_n number;
  begin
    select count(*) into l_n from ar_maintrns
     where customer_id = p_customer and trunc(trns_date) <= trunc(p_date)
       and trns_id not in (select id from ar_trnstype where trns_type = 6);      -- other opening balances do not count
    if l_n > 0 then
      err('لا يمكن تعديل رصيد افتتاحي للعميل بينما هناك حركات تم إدخالها من قبل',
          'You can''t change opening balance for the current customer while transactions exist ');
    end if;
    if p_r_serial is null then return; end if;
    select count(*) into l_n from ar_maintrns m
     where m.trns_id = p_trns_id and m.trns_serial = p_r_serial
       and (nvl(m.post_flag, 0) = 1 or nvl(m.pay_flag, 0) = 1 or nvl(m.residual_value, 0) != nvl(m.total_value, 0)
            or exists (select 1 from ar_subtrns s where s.trns_id = m.trns_id and s.trns_serial = m.trns_serial
                          and s.mainarea_id = m.mainarea_id and s.subarea_id = m.subarea_id
                          and (nvl(s.residual_value, 0) != nvl(s.total_value, 0) or nvl(s.post_flag, 0) = 1)));
    if l_n > 0 then
      err('لا يمكن تعديل رصيد افتتاحي للعميل بينما هناك حركات تم إدخالها من قبل (تم السداد أو الترحيل على الرصيد)',
          'The opening balance was already allocated or posted');
    end if;
  end op_check_change;

  procedure op_remove (p_trns_id in number, p_r_serial in number) is
  begin
    if p_r_serial is null then return; end if;
    delete from ar_subtrns where trns_id = p_trns_id and trns_serial = p_r_serial;
    delete from ar_maintrns where trns_id = p_trns_id and trns_serial = p_r_serial;
  end op_remove;

  procedure op_line_row (p_ins in boolean, p_trns_id in number, p_trns_serial in number, p_customer in number, p_ctgry in number,
                         p_main in out number, p_sub in out number, p_salesman in out number, p_currency in out number,
                         p_rate in out number, p_value in number, p_bill_id1 in number, p_bill_id2 in out number,
                         p_r_serial in out number,
                         p_old_customer in number, p_old_ctgry in number, p_old_salesman in number, p_old_value in number,
                         p_old_r_serial in number) is
    l_h      ar_maintrns_op%rowtype;
    l_effect number;
    l_c      customer%rowtype;
    l_n      number;
  begin
    select * into l_h from ar_maintrns_op where trns_id = p_trns_id and trns_serial = p_trns_serial;
    select effect into l_effect from ar_trnstype where id = p_trns_id;
    need(p_customer, 'يجب إدخال رقم العميل', 'Enter the customer');
    begin
      select * into l_c from customer where code = p_customer and nvl(stopflag, 0) <> 1 and nvl(customer_status, 0) = 1;
    exception when no_data_found then
      err('رقم العميل غير موجود أو موقوف أو ليس عميلا فرعيا', 'Customer not found, stopped or not a leaf customer');
    end;
    if nvl(grp, 0) != 0 then
      select count(*) into l_n from ar_customer_password
       where password_number = grp and p_customer between from_customer_code and to_customer_code;
      if l_n = 0 then err('خطأ صلاحية', 'Permission error'); end if;
    end if;
    select count(*) into l_n from ar_cust_salesman where customer_code = p_customer and ctgry_code = p_ctgry;
    if l_n = 0 then err('العميل غير مرتبط بالقسم', 'The customer is not linked to this department'); end if;
    if trunc(l_h.trns_date) < trunc(l_c.open_date) then
      err('تاريخ الحركة لا يمكن ان يكون اقل من تاريخ فتح العميل', 'The date cannot be before the customer open date');
    end if;
    p_main := l_c.mainarea_id; p_sub := l_c.subarea_id;
    if p_salesman is null then
      select min(salesman_code) into p_salesman from ar_cust_salesman where customer_code = p_customer and ctgry_code = p_ctgry;
    else
      select count(*) into l_n from ar_cust_salesman where customer_code = p_customer and ctgry_code = p_ctgry and salesman_code = p_salesman;
      if l_n = 0 then err('رقم المندوب غير مرتبط بالعميل في القسم', 'The salesman is not linked to the customer in this department'); end if;
    end if;
    p_currency := nvl(p_currency, l_c.currency_code);
    if nvl(p_currency, -1) != nvl(l_c.currency_code, nvl(p_currency, -1)) then
      err('خطأ في عملة العميل', 'The currency is not the customer currency');
    end if;
    if p_currency = 1 and nvl(p_rate, 1) != 1 then err('يجب ان يكون معامل التحويل ب 1', 'The exchange rate must be 1'); end if;
    p_rate := nvl(p_rate, 1);
    if p_rate <= 0 then err('يجب ان يكون معامل التحويل أكبر من 0', 'The exchange rate must be greater than 0'); end if;
    if nvl(p_value, 0) <= 0 then err('القيمة يجب أن تكون أكبر من الصفر', 'The value must be greater than zero'); end if;
    if l_effect = 0 and p_bill_id1 is null then
      err('يجب ادخال رقم فاتوره حتى يمكن السداد عليها', 'Enter an invoice number so it can be paid');
    end if;
    -- replace the generated transaction of a changed line (reverse the old balances first)
    if p_ins then
      op_check_change(p_trns_id, null, p_customer, l_h.trns_date);
    else
      op_check_change(p_trns_id, p_old_r_serial, p_old_customer, l_h.trns_date);
      op_remove(p_trns_id, p_old_r_serial);
      op_balances(l_effect, p_old_value, p_old_customer, p_old_salesman, p_old_ctgry, -1);
    end if;
    -- POST-INSERT of the legacy block: the customer transaction (AR_MAINTRNS) and, for a debit balance, its invoice bill
    select nvl(max(trns_serial), 0) + 1 into p_r_serial from ar_maintrns where trns_id = p_trns_id;
    if p_bill_id1 is not null then
      select nvl(max(bill_id2), 0) + 1 into p_bill_id2 from ar_subtrns where bill_id1 = p_bill_id1;
    end if;
    insert into ar_maintrns (trns_id, mainarea_id, subarea_id, trns_serial, ctgry_code, store_code, trns_date, doc_no,
                             total_value, disc_value, net_value, description_a, description_e, customer_id, salesman_id,
                             link_flag, post_flag, residual_value, pay_method, currency_code, currency_rate)
    values (p_trns_id, p_main, p_sub, p_r_serial, p_ctgry, 999999999999, l_h.trns_date, l_h.doc_no,
            p_value, 0, p_value, l_h.description_a, l_h.description_e, p_customer, p_salesman,
            0, 0, p_value, 4, p_currency, p_rate);
    if l_effect = 0 then
      insert into ar_subtrns (trns_id, mainarea_id, subarea_id, trns_serial, bill_seq, bill_id1, bill_id2, total_value,
                              disc_value, net_value, residual_value, store_code, inv_date, post_flag)
      values (p_trns_id, p_main, p_sub, p_r_serial, 1, p_bill_id1, p_bill_id2, p_value, 0, p_value, p_value,
              999999999999, l_h.trns_date, 0);
    end if;
    op_balances(l_effect, p_value, p_customer, p_salesman, p_ctgry, 1);
  end op_line_row;

  -- delete hook of AR_SUBTRNS_OP: ON-CHECK-DELETE-MASTER of the header, reverse the generated transaction and the balances
  procedure op_line_del (p_trns_id in number, p_trns_serial in number, p_r_serial in number, p_customer in number,
                         p_salesman in number, p_ctgry in number, p_value in number) is
    l_date   date;
    l_effect number;
  begin
    if doc_delete('ARTRN_OP') then master_has_details; end if;
    select max(trns_date) into l_date from ar_maintrns_op where trns_id = p_trns_id and trns_serial = p_trns_serial;
    select effect into l_effect from ar_trnstype where id = p_trns_id;
    op_check_change(p_trns_id, p_r_serial, p_customer, l_date);
    op_remove(p_trns_id, p_r_serial);
    op_balances(l_effect, p_value, p_customer, p_salesman, p_ctgry, -1);
  end op_line_del;

  -- the same customer / department / salesman cannot get two opening balances of the same effect
  procedure op_after_save (p_rowid in varchar2) is
    l_dup number;
    l_cust number;
  begin
    select max(o.customer_id), count(*) into l_cust, l_dup
      from ar_maintrns_op h, ar_subtrns_op o, ar_trnstype t
     where h.rowid = chartorowid(p_rowid) and o.trns_id = h.trns_id and o.trns_serial = h.trns_serial and t.id = o.trns_id
       and exists (select 1 from ar_subtrns_op o2, ar_trnstype t2
                    where t2.id = o2.trns_id and t2.effect = t.effect and o2.ctgry_code = o.ctgry_code
                      and o2.salesman_id = o.salesman_id and o2.customer_id = o.customer_id
                      and not (o2.trns_id = o.trns_id and o2.trns_serial = o.trns_serial and o2.bill_seq = o.bill_seq));
    if l_dup > 0 then
      err('تم إدخال رصيد إفتتاحى للعميل التالي من قبل ' || l_cust, 'An opening balance was already entered for customer ' || l_cust);
    end if;
  end op_after_save;


  -- =================================================================================== ARSLSMANCUSTTRNSFR (transfer customers)
  function next_trnsfr_date_serial (p_from in number) return number is
    l_n number;
  begin
    select nvl(max(date_serial), 0) + 1 into l_n from ar_slsman_trnsfr where from_slsman = p_from;
    return l_n;
  end next_trnsfr_date_serial;

  function next_trnsfr_serial (p_from in number, p_date in date, p_date_serial in number) return number is
    l_n number;
  begin
    select nvl(max(serial), 0) + 1 into l_n from ar_slsman_trnsfr_det
     where from_slsman = p_from and trnsfr_date = p_date and date_serial = p_date_serial;
    return l_n;
  end next_trnsfr_serial;

  procedure trnsfr_mast_row (p_ins in boolean, p_from in number, p_date in date) is
    l_n   number;
    l_min date;
  begin
    select count(*) into l_n from salesman where code = p_from
       and (nvl(grp, 0) = 0 or code in (select salesman_code from ar_salesman_password where password_number = grp));
    if l_n = 0 then err('رقم المندوب غير موجود', 'Salesman not found'); end if;
    select min(min_date) into l_min from ac_basic;
    if trunc(p_date) < trunc(l_min) then err('التاريخ أقل من الحد الأدنى المسموح به', 'The date is before the minimum allowed date'); end if;
    if p_ins then
      select count(*) into l_n from ar_slsman_trnsfr where from_slsman = p_from and trnsfr_date = p_date;
      if l_n > 0 then err('تم نقل هذا المندوب فى نفس التاريخ من قبل', 'This salesman was transferred on the same date before'); end if;
    end if;
  end trnsfr_mast_row;

  -- balance of the customer (all AR transactions, in currency and in local currency)
  procedure cust_balance (p_customer in number, p_bal out number, p_bal_loc out number) is
  begin
    select nvl(sum(decode(att.effect, 0, a.total_value, 1, -a.total_value)) + sum(decode(att.effect, 0, a.disc_value, 1, -a.disc_value)), 0),
           nvl(sum(decode(att.effect, 0, a.total_value, 1, -a.total_value) * currency_rate)
               + sum(decode(att.effect, 0, a.disc_value, 1, -a.disc_value) * currency_rate), 0)
      into p_bal, p_bal_loc
      from ar_maintrns a, ar_trnstype att where a.customer_id = p_customer and a.trns_id = att.id;
  end cust_balance;

  -- POST-INSERT of a transfer line: the balance moves from the old to the new salesman with a debit / credit transfer pair
  -- (the credit transaction settles the debit one: both residual 0) and the customer's salesman of the department changes
  procedure trnsfr_line_row (p_ins in boolean, p_from in number, p_date in date, p_customer in number, p_to in number,
                             p_ctgry in number, p_cr in number, p_db in number, p_bal in out number, p_bal_loc in out number,
                             p_cr_serial in out number, p_db_serial in out number) is
    l_c      customer%rowtype;
    l_n      number;
    l_d      date;
    l_rate   number;
    l_db_slm number;
    l_cr_slm number;
    l_desc   varchar2(400);
  begin
    if not p_ins then
      err('لا يمكن تعديل سطر النقل؛ يجب حذفه وإدخاله من جديد', 'A transfer line cannot be changed; delete it and enter it again');
    end if;
    if p_cr is null or p_db is null then err('يجب تحديد الحركات الدائنة والمدينة', 'Select the credit and debit transfer types'); end if;
    select count(*) into l_n from ar_trnstype where id = p_cr and effect = 1 and trns_type = 5;
    if l_n = 0 then err('حركة النقل الدائنة غير صحيحة', 'Invalid credit transfer type'); end if;
    select count(*) into l_n from ar_trnstype where id = p_db and effect = 0 and trns_type = 5;
    if l_n = 0 then err('حركة النقل المدينة غير صحيحة', 'Invalid debit transfer type'); end if;
    begin
      select * into l_c from customer where code = p_customer and nvl(stopflag, 0) <> 1 and nvl(customer_status, 0) = 1;
    exception when no_data_found then err('رقم العميل غير موجود أو موقوف', 'Customer not found or stopped');
    end;
    select count(*) into l_n from ar_slsman_trnsfr_det where from_slsman = p_from and trnsfr_date = p_date and customer_code = p_customer;
    if l_n > 0 then err('تم نقل هذا العميل فى نفس التاريخ من قبل', 'This customer was transferred on the same date before'); end if;
    select count(*) into l_n from ar_cust_salesman where customer_code = p_customer and salesman_code = p_from and ctgry_code = p_ctgry;
    if l_n = 0 then err('العميل غير مرتبط بالمندوب في القسم', 'The customer is not linked to the salesman in this department'); end if;
    select count(*) into l_n from ar_cust_salesman where customer_code = p_customer and salesman_code = p_to and ctgry_code = p_ctgry;
    if l_n > 0 then err('العميل مرتبط بالمندوب الجديد في نفس القسم', 'The customer is already linked to the new salesman in this department'); end if;
    if p_to = p_from then err('يجب اختيار مندوب آخر', 'Choose another salesman'); end if;
    select count(*) into l_n from ar_ctgry_salesman where salesman_code = p_to and ctgry_code = p_ctgry;
    if l_n = 0 then err('رقم المندوب المدخل غير موجود فى القسم المختار', 'The sales man code is not located in the selected department'); end if;
    select max(trnsfr_date) into l_d from ar_slsman_trnsfr_det where from_slsman = p_from and customer_code = p_customer;
    if l_d > p_date then
      err('توجد حركة نقل سابقة لهذا المندوب بتاريخ اكبر من التاريخ المدخل', 'A later transfer of this salesman exists');
    end if;
    if trunc(p_date) < trunc(l_c.open_date) then
      err('تاريخ الحركة لا يمكن ان يكون اقل من تاريخ فتح العميل', 'The date cannot be before the customer open date');
    end if;
    select max(m.trns_date) into l_d from ar_maintrns_op m, ar_subtrns_op d
     where m.trns_id = d.trns_id and m.trns_serial = d.trns_serial and d.customer_id = p_customer;
    if trunc(p_date) < trunc(l_d) then
      err('تاريخ الحركة لا يمكن ان يقل عن تاريخ الرصيد الافتتاحي العميل', 'The date cannot be before the customer opening balance date');
    end if;
    select count(*) into l_n from ar_maintrns where salesman_id = p_from and customer_id = p_customer and trns_date > p_date;
    if l_n > 0 then
      err('يوجد حركة للعميل رقم ' || p_customer || ' مع المندوب رقم ' || p_from || ' بنظام العملاء لها تاريخ لاحق',
          'Customer ' || p_customer || ' has AR transactions with salesman ' || p_from || ' after the transfer date');
    end if;
    select count(*) into l_n from st_trns_mast
     where salesman_code = p_from and customer_code = p_customer and (trns_date > p_date or nvl(cust_post_flag, 0) != 1)
       and nvl(delete_flag, 0) = 0
       and trns_type_code in (select trns_type_code from st_trns_type where effect in (2, 4) and trns_type in (2, 4));
    if l_n > 0 then
      err('يوجد حركة للعميل رقم ' || p_customer || ' مع المندوب رقم ' || p_from || ' بالمخازن لها تاريخ لاحق أو لم ترحل',
          'Customer ' || p_customer || ' has stock sales / returns with salesman ' || p_from || ' after the date or not posted');
    end if;
    cust_balance(p_customer, p_bal, p_bal_loc);
    l_rate := case when p_bal = 0 then 1 else round(p_bal_loc / p_bal, 4) end;
    -- debit transfer: under the new salesman for a debit balance (under the old one for a credit balance); credit transfer opposite
    l_db_slm := case when sign(p_bal) = -1 then p_from else p_to end;
    l_cr_slm := case when sign(p_bal) = -1 then p_to else p_from end;
    l_desc := substr(msg('نقل العميل من المندوب ', 'Customer transfer from salesman ') || p_from || msg(' الى المندوب ', ' to salesman ') || p_to, 1, 400);
    select nvl(max(trns_serial), 0) + 1 into p_db_serial from ar_maintrns
     where trns_id = p_db and mainarea_id = l_c.mainarea_id and subarea_id = l_c.subarea_id;
    insert into ar_maintrns (trns_id, mainarea_id, subarea_id, trns_serial, ctgry_code, store_code, trns_date, doc_no, total_value,
                             disc_value, net_value, description_a, description_e, customer_id, salesman_id, link_flag, post_flag,
                             pay_method, residual_value, currency_code, currency_rate)
    values (p_db, l_c.mainarea_id, l_c.subarea_id, p_db_serial, p_ctgry, 999999999999, p_date, null, round(abs(p_bal), 2),
            0, round(abs(p_bal), 2), l_desc, null, p_customer, l_db_slm, 0, 1, 0, 0, l_c.currency_code, l_rate);
    insert into ar_subtrns (trns_id, mainarea_id, subarea_id, trns_serial, bill_seq, bill_id1, bill_id2, total_value, disc_value,
                            net_value, residual_value, store_code, det_desc, inv_pay_date)
    values (p_db, l_c.mainarea_id, l_c.subarea_id, p_db_serial, 1, to_number(to_char(p_db) || to_char(l_c.mainarea_id)),
            to_number(to_char(l_c.subarea_id) || to_char(p_db_serial)), abs(p_bal), 0, abs(p_bal), 0, 999999999999, l_desc, p_date);
    select nvl(max(trns_serial), 0) + 1 into p_cr_serial from ar_maintrns
     where trns_id = p_cr and mainarea_id = l_c.mainarea_id and subarea_id = l_c.subarea_id;
    insert into ar_maintrns (trns_id, mainarea_id, subarea_id, trns_serial, ctgry_code, store_code, trns_date, doc_no, total_value,
                             disc_value, net_value, description_a, description_e, customer_id, salesman_id, link_flag, post_flag,
                             pay_method, residual_value, currency_code, currency_rate)
    values (p_cr, l_c.mainarea_id, l_c.subarea_id, p_cr_serial, p_ctgry, 999999999999, p_date, null, abs(p_bal),
            0, abs(p_bal), l_desc, null, p_customer, l_cr_slm, 0, 0, 2, 0, l_c.currency_code, l_rate);
    insert into ar_subtrns (trns_id, mainarea_id, subarea_id, trns_serial, bill_seq, bill_id1, bill_id2, total_value, disc_value,
                            net_value, residual_value, store_code, det_desc, inv_trns_id, inv_trns_serial, inv_mainarea_id,
                            inv_subarea_id, inv_bill_seq)
    values (p_cr, l_c.mainarea_id, l_c.subarea_id, p_cr_serial, 1, to_number(to_char(p_db) || to_char(l_c.mainarea_id)),
            to_number(to_char(l_c.subarea_id) || to_char(p_db_serial)), abs(p_bal), 0, abs(p_bal), 0, 999999999999, l_desc,
            p_db, p_db_serial, l_c.mainarea_id, l_c.subarea_id, 1);
    update ar_cust_salesman set salesman_code = p_to where customer_code = p_customer and salesman_code = p_from and ctgry_code = p_ctgry;
  end trnsfr_line_row;

  -- delete of a transfer line (after the statement): only the customer's last transfer, no later AR transactions; the two
  -- transfer transactions are removed and the customer goes back to the old salesman
  procedure trnsfr_line_del (p_from in number, p_date in date, p_customer in number, p_to in number, p_ctgry in number,
                             p_cr in number, p_cr_serial in number, p_db in number, p_db_serial in number) is
    l_d    date;
    l_n    number;
    l_c    customer%rowtype;
  begin
    if doc_delete('ARSLSMANCUSTTRNSFR') then master_has_details; end if;
    select max(trnsfr_date) into l_d from ar_slsman_trnsfr_det where customer_code = p_customer;
    if l_d > p_date then err('يجب حذف اخر حركات النقل اولا', 'Delete the last transfers first'); end if;
    select count(*) into l_n from ar_maintrns where customer_id = p_customer and trns_date > p_date;
    if l_n > 0 then err('توجد حركات بعد تاريخ النقل', 'Transactions exist after the transfer date'); end if;
    select * into l_c from customer where code = p_customer;
    delete from ar_subtrns where trns_id = p_cr and trns_serial = p_cr_serial and mainarea_id = l_c.mainarea_id and subarea_id = l_c.subarea_id;
    delete from ar_maintrns where trns_id = p_cr and trns_serial = p_cr_serial and mainarea_id = l_c.mainarea_id and subarea_id = l_c.subarea_id;
    delete from ar_subtrns where trns_id = p_db and trns_serial = p_db_serial and mainarea_id = l_c.mainarea_id and subarea_id = l_c.subarea_id;
    delete from ar_maintrns where trns_id = p_db and trns_serial = p_db_serial and mainarea_id = l_c.mainarea_id and subarea_id = l_c.subarea_id;
    update ar_cust_salesman set salesman_code = p_from where customer_code = p_customer and salesman_code = p_to and ctgry_code = p_ctgry;
  end trnsfr_line_del;

  -- KEY-COMMIT "يجب تحديد العملاء المنقولة": a saved transfer needs its customers
  procedure trnsfr_after_save (p_rowid in varchar2) is
    l_n number;
  begin
    select count(*) into l_n from ar_slsman_trnsfr h, ar_slsman_trnsfr_det d
     where h.rowid = chartorowid(p_rowid) and d.from_slsman = h.from_slsman and d.trnsfr_date = h.trnsfr_date
       and d.date_serial = h.date_serial;
    if l_n = 0 then err('يجب تحديد العملاء المنقولة', 'Select the customers to transfer'); end if;
  end trnsfr_after_save;

  -- button "إنزال عملاء المندوب": every customer of the old salesman without later AR transactions becomes a transfer line
  -- (to the chosen salesman with the chosen debit / credit transfer types; lines can then be removed one by one)
  function load_trnsfr_customers (p_rowid in varchar2, p_ctgry in number, p_to in number, p_cr in number, p_db in number) return varchar2 is
    l_h    ar_slsman_trnsfr%rowtype;
    l_ser  number;
    l_cnt  number := 0;
  begin
    select * into l_h from ar_slsman_trnsfr where rowid = chartorowid(p_rowid);
    for c in (select distinct cr.code, cs.ctgry_code
                from customer cr, ar_cust_salesman cs
               where cr.code = cs.customer_code and cs.salesman_code = l_h.from_slsman
                 and (p_ctgry is null or cs.ctgry_code = p_ctgry)
                 and nvl(cr.stopflag, 0) <> 1 and nvl(cr.customer_status, 0) = 1
                 and cr.code not in (select customer_id from ar_maintrns where trns_date > l_h.trnsfr_date and customer_id is not null)
                 and cr.code not in (select x.customer_code from ar_cust_salesman x where x.salesman_code = p_to and x.ctgry_code = cs.ctgry_code)
                 and cr.code not in (select customer_code from ar_slsman_trnsfr_det
                                      where from_slsman = l_h.from_slsman and trnsfr_date = l_h.trnsfr_date)
                 and (nvl(grp, 0) = 0 or cr.code in (select customer_code from ar_cust_password where password_number = grp))
               order by cs.ctgry_code, cr.code) loop
      l_ser := next_trnsfr_serial(l_h.from_slsman, l_h.trnsfr_date, l_h.date_serial);
      insert into ar_slsman_trnsfr_det (from_slsman, trnsfr_date, date_serial, serial, customer_code, ctgry_code, to_slsman,
                                        cr_trns_code, db_trns_code)
      values (l_h.from_slsman, l_h.trnsfr_date, l_h.date_serial, l_ser, c.code, c.ctgry_code, p_to, p_cr, p_db);
      l_cnt := l_cnt + 1;
    end loop;
    if l_cnt = 0 then err('لا يوجد عملاء للمندوب يمكن نقلهم', 'The salesman has no customers that can be transferred'); end if;
    return null;
  end load_trnsfr_customers;


  -- =================================================================================== AR_TARGET (annual target plan, AR_ALL_TARGET)
  procedure target_row (p_year in number, p_customer in number, p_salesman in number, p_serial in number,
                        p_group in out number, p_item in varchar2) is
    l_n number;
  begin
    need(p_year, 'يجب إدخال السنة', 'Enter the year');
    if (case when p_customer is not null then 1 else 0 end) + (case when p_salesman is not null then 1 else 0 end)
       + (case when p_item is not null then 1 else 0 end) > 1 then
      err('المستهدف يكون لعميل أو لمندوب أو لصنف (واحد فقط)', 'A target is for one customer, one salesman or one item');
    end if;
    if p_serial is not null and p_serial not between 1 and 12 then
      err('الفترة (الشهر) يجب أن تكون من 1 إلى 12', 'The period (month) must be 1 to 12');
    end if;
    if p_customer is not null then
      select count(*) into l_n from customer where code = p_customer and nvl(stopflag, 0) <> 1 and nvl(customer_status, 0) = 1;
      if l_n = 0 then err('رقم العميل غير موجود أو موقوف', 'Customer not found or stopped'); end if;
    end if;
    if p_salesman is not null then
      select count(*) into l_n from salesman where code = p_salesman and nvl(stop_flag, 0) = 0;
      if l_n = 0 then err('رقم المندوب غير موجود أو موقوف', 'Salesman not found or stopped'); end if;
    end if;
    if p_item is not null then
      select max(item_group_code), count(*) into p_group, l_n from st_item
       where item_code = p_item and nvl(stop_flag, 0) = 0 and (p_group is null or item_group_code = p_group);
      if l_n = 0 then err('رقم الصنف غير موجود أو موقوف', 'Item not found or stopped'); end if;
    end if;
  end target_row;

  -- "ادخال مكرر" (after the insert / update statement)
  procedure target_dup (p_serial in number) is
    l_n number;
  begin
    select count(*) into l_n from ar_all_target t, ar_all_target x
     where t.all_serial = p_serial and x.all_serial != t.all_serial and x.t_year = t.t_year
       and nvl(x.customer_id, -1) = nvl(t.customer_id, -1) and nvl(x.salesman_id, -1) = nvl(t.salesman_id, -1)
       and nvl(x.item_code, '#') = nvl(t.item_code, '#') and nvl(x.t_serial, -1) = nvl(t.t_serial, -1);
    if l_n > 0 then err('ادخال مكرر', 'Duplicate entry'); end if;
  end target_dup;

  -- =================================================================================== AR_SLSMAN_SCHEDUAL (visit plan)
  -- the salesman block is only the navigation of this screen
  procedure readonly_master is
  begin
    err('بيانات المندوب تعدل من ملف المندوبين', 'The salesman data is maintained in the salesmen file');
  end readonly_master;

  procedure schedule_row (p_ins in boolean, p_salesman in number, p_customer in number, p_date in date, p_order in out number) is
    l_n number;
  begin
    select count(*) into l_n from customer c
     where c.code = p_customer and nvl(c.stopflag, 0) <> 1 and nvl(c.customer_status, 0) = 1
       and c.code in (select customer_code from ar_cust_salesman where salesman_code = p_salesman);
    if l_n = 0 then err('العميل غير موجود أو موقوف أو ليس من عملاء المندوب', 'Customer not found, stopped or not a customer of the salesman'); end if;
    if p_ins then
      select count(*) into l_n from ar_salesman_schedual where salesman_id = p_salesman and schedual_date = p_date;
      if l_n >= 25 then err('تم تعدي عدد 25 زيارة', 'More than 25 visits'); end if;
      if p_order is null then
        select nvl(max(customer_order), 0) + 1 into p_order from ar_salesman_schedual where salesman_id = p_salesman and schedual_date = p_date;
      end if;
    end if;
  end schedule_row;

  procedure visit_row (p_salesman in number, p_customer in number, p_start in date, p_end in date) is
  begin
    if p_start is not null and p_end is not null and p_end <= p_start then
      err('يجب ان يكون وقت الرجوع اكبر من وقت الخروخ', 'The return time must be after the start time');
    end if;
  end visit_row;

  -- button "خط السير": the customers of a route whose visit day is the day of the date (legacy: tomorrow) in the route order
  function load_route (p_rowid in varchar2, p_group in number, p_date in date) return varchar2 is
    l_code  number;
    l_n     number := 0;
    l_group ar_customer_group_mast%rowtype;
  begin
    select code into l_code from salesman where rowid = chartorowid(p_rowid);
    begin
      select * into l_group from ar_customer_group_mast where group_id = p_group and salesman_id = l_code;
    exception when no_data_found then err('خط السير ليس لهذا المندوب', 'The route does not belong to the salesman');
    end;
    for c in (select customer_id, customer_order from ar_customer_group_det
               where group_id = p_group and visit_day = to_char(p_date, 'Dy', 'NLS_DATE_LANGUAGE = ENGLISH')
                 and customer_id not in (select customer_id from ar_salesman_schedual where salesman_id = l_code and schedual_date = trunc(p_date))
               order by customer_order) loop
      insert into ar_salesman_schedual (salesman_id, customer_id, customer_order, schedual_date, visit_done)
      values (l_code, c.customer_id, c.customer_order, trunc(p_date), 0);
      l_n := l_n + 1;
    end loop;
    if l_n = 0 then err('لا يوجد عملاء في خط السير لهذا اليوم', 'The route has no customers for this day'); end if;
    return null;
  end load_route;

  -- =================================================================================== AR_SALESMAN_MSG (messages to salesmen)
  procedure msg_det_row (p_ins in boolean, p_to in number) is
    l_n number;
  begin
    select count(*) into l_n from salesman where code = p_to;
    if l_n = 0 then err('رقم المندوب غير موجود', 'Salesman not found'); end if;
  end msg_det_row;

  -- button "اختيار": every salesman of the list (optionally one department) becomes a recipient of the message
  function msg_add_salesmen (p_rowid in varchar2, p_ctgry in number) return varchar2 is
    l_ser number;
  begin
    select mast_ser into l_ser from mob_msg_mast where rowid = chartorowid(p_rowid);
    insert into mob_msg_det (mast_ser, to_code, read_flag, hide_flag)
    select l_ser, s.code, 0, 0 from salesman s
     where nvl(s.stop_flag, 0) = 0
       and (p_ctgry is null or s.code in (select salesman_code from ar_ctgry_salesman where ctgry_code = p_ctgry))
       and s.code not in (select to_code from mob_msg_det where mast_ser = l_ser);
    return null;
  end msg_add_salesmen;


  -- =================================================================================== AR_BASIC (system parameters)
  -- "توجد حركات بالفعل بالنظام" + "هل تريد تغيير المؤشر الآن": changing an indicator while AR transactions exist asks first
  function basic_warning (p_rowid in varchar2, p_auto in varchar2, p_calc in varchar2, p_slsm in varchar2, p_stop in varchar2) return varchar2 is
    l_b ar_basic%rowtype;
    l_n number;
  begin
    if p_rowid is null then return null; end if;
    select * into l_b from ar_basic where rowid = chartorowid(p_rowid);
    if nvl(l_b.auto_serial, 0) = nvl(num(p_auto), 0) and nvl(l_b.calc_comm, -1) = nvl(num(p_calc), -1)
       and nvl(l_b.salesman_cust_flag, 0) = nvl(num(p_slsm), 0) and nvl(l_b.stop_cust_flag, 0) = nvl(num(p_stop), 0) then
      return null;
    end if;
    select count(*) into l_n from ar_maintrns where rownum = 1;
    if l_n = 0 then return null; end if;
    return msg('توجد حركات بالفعل بالنظام - هل تريد تغيير المؤشر الآن', 'Transactions already exist - change the indicator now?');
  exception when no_data_found then return null;
  end basic_warning;


  -- =================================================================================== AR_CUSTOMER_DUES (customer incentives / rents)
  procedure check_close (p_date in date) is
    l_close date;
  begin
    select max(close_date) into l_close from ac_basic where company_code = nvl(to_number(v('G_COMPANY_CODE')), company_code);
    if l_close is not null and trunc(p_date) <= trunc(l_close) then
      err('تم إقفال هذه الفترة - تاريخ الاقفال ' || to_char(l_close, 'DD/MM/YYYY'), 'This period is closed - closing date ' || to_char(l_close, 'DD/MM/YYYY'));
    end if;
  end check_close;

  procedure dues_mast_row (p_ins in boolean, p_main in number, p_serial in number, p_sub in number, p_salesman in number,
                           p_ctgry in number, p_date in date, p_type in number, p_f in date, p_t in date,
                           p_d_acc in number, p_c_acc in number, p_post in number, p_old_post in number,
                           p_old_sub in number, p_old_salesman in number, p_old_ctgry in number, p_old_date in date, p_old_type in number) is
    l_n number;
  begin
    if not p_ins and nvl(p_old_post, 0) = 1 and nvl(p_post, 0) = 1 then
      err('الحركة مرحلة للحسابات', 'The transaction is posted to the accounts');
    end if;
    if nvl(p_post, 0) = nvl(p_old_post, 0) then                  -- not the posting / cancelling action itself
      if p_type not in (1, 2) then err('نوع الاستحقاق: 1 حوافز / 2 ايجار', 'Due type: 1 incentives / 2 rent'); end if;
      if p_f > p_t then err('من تاريخ يجب أن يكون قبل الى تاريخ', 'From date must be before to date'); end if;
      select count(*) into l_n from ar_subarea where main_id = p_main and (p_sub is null or id = p_sub);
      if l_n = 0 then err('المنطقة / الفرع غير موجود', 'Area / branch not found'); end if;
      select count(*) into l_n from st_category_type where category_type_code = p_ctgry;
      if l_n = 0 then err('رقم القسم غير موجود', 'Department not found'); end if;
      check_salesman(p_salesman); check_account(p_d_acc); check_account(p_c_acc);
      check_close(p_date);
      if not p_ins and (nvl(p_sub, -1) != nvl(p_old_sub, -1) or nvl(p_salesman, -1) != nvl(p_old_salesman, -1)
                        or p_ctgry != p_old_ctgry or trunc(p_date) != trunc(p_old_date) or nvl(p_type, -1) != nvl(p_old_type, -1)) then
        select count(*) into l_n from ar_customer_dues_det where mainarea_id = p_main and mast_serial = p_serial;
        if l_n > 0 then err('لا يمكن تغيير الرئيسي ويوجد بيانات', 'The header cannot change while lines exist'); end if;
      end if;
    end if;
  end dues_mast_row;

  procedure dues_det_check (p_main in number, p_serial in number) is
    l_post number;
  begin
    select max(post_flag) into l_post from ar_customer_dues where mainarea_id = p_main and mast_serial = p_serial;
    if nvl(l_post, 0) = 1 then err('الحركة مرحلة للحسابات', 'The transaction is posted to the accounts'); end if;
  end dues_det_check;

  -- button "تنفيذ": incentives = net sales of the customers of the department (area / branch / salesman) in the period; rent = customers
  -- with a contract covering the due date; customers already in dues of the same month and type are skipped. DUE_AMOUNT is entered.
  function dues_fill (p_rowid in varchar2) return varchar2 is
    h     ar_customer_dues%rowtype;
    l_ser number;
    l_n   number := 0;
  begin
    select * into h from ar_customer_dues where rowid = chartorowid(p_rowid);
    dues_det_check(h.mainarea_id, h.mast_serial);
    select nvl(max(due_serial), 0) into l_ser from ar_customer_dues_det where mainarea_id = h.mainarea_id and mast_serial = h.mast_serial;
    if h.due_type = 1 then
      for r in (select m.customer_code, m.salesman_code, sum(decode(tt.effect, 2, 1, 4, -1) * d.quantity * d.unit_price) sls
                  from st_trns_mast m, st_trns_type tt, st_trns_det d, ar_cust_salesman cust_sls, customer c
                 where m.trns_type_code = tt.trns_type_code and m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial
                   and ((tt.effect = 2 and tt.trns_type = 2) or (tt.effect = 4 and tt.trns_type = 4)) and nvl(m.delete_flag, 0) = 0
                   and m.trns_date between h.f_date and h.t_date and cust_sls.ctgry_code = h.ctgry_code
                   and cust_sls.customer_code = m.customer_code and c.code = m.customer_code and c.mainarea_id = h.mainarea_id
                   and (h.subarea_id is null or c.subarea_id = h.subarea_id)
                   and (h.salesman_code is null or cust_sls.salesman_code = h.salesman_code)
                   and (nvl(m.customer_code, 0), nvl(cust_sls.salesman_code, 0)) not in
                       (select nvl(dd.customer_code, 0), nvl(dd.salesman_code, 0) from ar_customer_dues mm, ar_customer_dues_det dd
                         where to_char(mm.due_date, 'YYYYMM') = to_char(h.due_date, 'YYYYMM') and mm.due_type = h.due_type
                           and mm.mainarea_id = dd.mainarea_id and mm.mast_serial = dd.mast_serial)
                 group by m.customer_code, m.salesman_code order by m.customer_code) loop
        l_ser := l_ser + 1; l_n := l_n + 1;
        insert into ar_customer_dues_det (mainarea_id, mast_serial, due_serial, customer_code, salesman_code, sls_amount)
        values (h.mainarea_id, h.mast_serial, l_ser, r.customer_code, r.salesman_code, r.sls);
      end loop;
    else
      for r in (select m.customer_id customer_code, cust_sls.salesman_code
                  from customer_cntrct m, ar_cust_salesman cust_sls, customer c
                 where h.due_date between m.c_f_date and m.c_t_date and cust_sls.ctgry_code = h.ctgry_code
                   and cust_sls.customer_code = m.customer_id and c.code = m.customer_id and c.mainarea_id = h.mainarea_id
                   and (h.subarea_id is null or c.subarea_id = h.subarea_id)
                   and (h.salesman_code is null or cust_sls.salesman_code = h.salesman_code)
                   and (nvl(m.customer_id, 0), nvl(cust_sls.salesman_code, 0)) not in
                       (select nvl(dd.customer_code, 0), nvl(dd.salesman_code, 0) from ar_customer_dues mm, ar_customer_dues_det dd
                         where to_char(mm.due_date, 'YYYYMM') = to_char(h.due_date, 'YYYYMM') and mm.due_type = h.due_type
                           and mm.mainarea_id = dd.mainarea_id and mm.mast_serial = dd.mast_serial)
                 order by 1) loop
        l_ser := l_ser + 1; l_n := l_n + 1;
        insert into ar_customer_dues_det (mainarea_id, mast_serial, due_serial, customer_code, salesman_code)
        values (h.mainarea_id, h.mast_serial, l_ser, r.customer_code, r.salesman_code);
      end loop;
    end if;
    return null;
  end dues_fill;

  -- button "ترحيل": GL voucher (AC_YEARLY_TRN, type / year of the document) debit / credit per customer due
  function dues_post (p_rowid in varchar2) return varchar2 is
    h      ar_customer_dues%rowtype;
    l_no   number;
    l_seq  number := 0;
    l_desc varchar2(400);
    l_c1   number;
    l_c2   number;
    l_n    number := 0;
  begin
    select * into h from ar_customer_dues where rowid = chartorowid(p_rowid) for update;
    if nvl(h.post_flag, 0) = 1 then err('القيد مرحل', 'The voucher is already posted'); end if;
    check_close(h.due_date);
    need(h.entry_type, 'يجب إدخال نوع القيد المحاسبى', 'Enter the voucher type');
    need(h.d_account_number, 'يجب إدخال رقم الحساب المدين', 'Enter the debit account');
    need(h.c_account_number, 'يجب إدخال رقم الحساب الدائن', 'Enter the credit account');
    h.entry_year := nvl(h.entry_year, to_number(to_char(h.due_date, 'YYYY')));
    l_no := app_rules_gl.next_entry_no(h.entry_year, h.entry_type, h.due_date);
    l_desc := ' اثبات حوافز وايجارات العملاء لشهر ' || to_char(h.due_date, 'MONTH-YYYY');
    insert into ac_yearly_trn (entry_year, entry_type, entry_no, doc_no, entry_date, entry_desc, entry_desc_e, currency_code, rate,
                               entry_total, memo, post_system, create_company_code, create_password_number, create_user_code, create_date)
    values (h.entry_year, h.entry_type, l_no, l_no, h.due_date, l_desc, null, 1, 1, null, null, 4,
            to_number(v('G_COMPANY_CODE')), grp, to_number(v('G_USER_CODE')), sysdate);
    for d in (select * from ar_customer_dues_det where mainarea_id = h.mainarea_id and mast_serial = h.mast_serial
                 and nvl(due_amount, 0) != 0 order by due_serial) loop
      select max(cost_code1) into l_c1 from customer where code = d.customer_code;
      select max(cost_code2) into l_c2 from salesman where code = d.salesman_code;
      for s in (select h.d_account_number acc, d.due_amount val from dual
                union all select h.c_account_number, -d.due_amount from dual) loop
        l_seq := l_seq + 1;
        insert into ac_yearly_trn_det (entry_year, entry_type, entry_no, seq, entry_date, account_number, entry_desc, entry_desc_e,
                                       value, cost_code, cost_code2, balance_flag, memo, memo_e)
        values (h.entry_year, h.entry_type, l_no, l_seq, h.due_date, s.acc, l_desc, null, s.val,
                case when substr(s.acc, 1, 1) in ('4', '5') then l_c1 end, case when substr(s.acc, 1, 1) in ('4', '5') then l_c2 end,
                0, ' اثبات حوافز وايجارات العملاء عميل  رقم ' || d.customer_code, null);
      end loop;
      l_n := l_n + 1;
    end loop;
    if l_n = 0 then
      err('لا توجد مستحقات بقيمة للترحيل', 'There are no dues with a value to post');
    end if;
    update ar_customer_dues set post_flag = 1, entry_year = h.entry_year, entry_no = l_no where rowid = chartorowid(p_rowid);
    return null;
  end dues_post;

  -- button "الغاء ترحيل": deletes the voucher of the dues
  function dues_unpost (p_rowid in varchar2) return varchar2 is
    h ar_customer_dues%rowtype;
  begin
    select * into h from ar_customer_dues where rowid = chartorowid(p_rowid) for update;
    if nvl(h.post_flag, 0) = 0 then err('القيد غر مرحل', 'The voucher is not posted'); end if;
    check_close(h.due_date);
    delete from ac_yearly_trn_det where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
    delete from ac_yearly_trn where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
    update ar_customer_dues set post_flag = 0, entry_no = null where rowid = chartorowid(p_rowid);
    return null;
  end dues_unpost;


  -- =================================================================================== AR_CUSTOMER_DUES_PAY (payment of the customers' dues)
  procedure pay_check_post (p_id in number, p_serial in number) is
    l_post number;
  begin
    select max(post_flag) into l_post from ar_customer_dues_pay where mast_id = p_id and mast_serial = p_serial;
    if nvl(l_post, 0) = 1 then err('الحركة مرحلة للحسابات', 'Record Already Posted'); end if;
  end pay_check_post;

  procedure pay_mast_row (p_ins in boolean, p_id in number, p_serial in number, p_main in number, p_sub in number, p_salesman in number,
                          p_ctgry in number, p_type in number, p_post in number, p_old_post in number,
                          p_old_main in number, p_old_sub in number, p_old_salesman in number, p_old_ctgry in number, p_old_type in number) is
    l_n number;
  begin
    if not p_ins and nvl(p_old_post, 0) = 1 and nvl(p_post, 0) = 1 then
      err('الحركة مرحلة للحسابات', 'Record Already Posted');
    end if;
    if nvl(p_post, 0) != nvl(p_old_post, 0) and not p_ins then return; end if;   -- the posting / cancelling buttons themselves
    -- LOV TRNSTYPE: credit opening-balance types (EFFECT 1, TRNS_TYPE 6) of the user's group
    select count(*) into l_n from ar_trnstype
     where id = p_id and effect = 1 and trns_type = 6
       and (nvl(grp, 0) = 0 or id in (select trns_id from ar_trnstype_password where flag = 1 and password_number = grp));
    if l_n = 0 then err('رقم الحركة غير صحيح', 'Invalid transaction type'); end if;
    if nvl(p_type, 0) not in (1, 2) then err('نوع الصرف: 1 حوافز / 2 ايجار', 'Payment type: 1 incentives / 2 rent'); end if;
    select count(*) into l_n from ar_subarea where main_id = p_main and (p_sub is null or id = p_sub);
    if l_n = 0 then err('المنطقة / الفرع غير موجود', 'Area / branch not found'); end if;
    select count(*) into l_n from st_category_type where category_type_code = p_ctgry;
    if l_n = 0 then err('رقم القسم غير موجود', 'Department not found'); end if;
    check_salesman(p_salesman);
    if not p_ins and (p_main != p_old_main or nvl(p_sub, -1) != nvl(p_old_sub, -1) or nvl(p_salesman, -1) != nvl(p_old_salesman, -1)
                      or p_ctgry != p_old_ctgry or nvl(p_type, -1) != nvl(p_old_type, -1)) then
      select count(*) into l_n from ar_customer_dues_pay_det where mast_id = p_id and mast_serial = p_serial and customer_code is not null;
      if l_n > 0 then err('لا يمكن تغيير الرئيسي ويوجد بيانات', 'Can not change master with detail'); end if;
    end if;
  end pay_mast_row;

  -- TOT_DUE: all dues of the customer / salesman of the payment type; TOT_PAY: what the other payment documents paid (POST-QUERY)
  function pay_due (p_id in number, p_serial in number, p_customer in number, p_salesman in number, p_what in varchar2) return number is
    l_type number;
    l_v    number;
  begin
    select max(due_type) into l_type from ar_customer_dues_pay where mast_id = p_id and mast_serial = p_serial;
    if p_what = 'DUE' then
      select nvl(sum(d.due_amount), 0) into l_v from ar_customer_dues m, ar_customer_dues_det d
       where m.mainarea_id = d.mainarea_id and m.mast_serial = d.mast_serial and m.due_type = l_type
         and d.customer_code = p_customer and d.salesman_code = p_salesman;
    else
      select nvl(sum(d.pay_amount), 0) into l_v from ar_customer_dues_pay m, ar_customer_dues_pay_det d
       where m.mast_id = d.mast_id and m.mast_serial = d.mast_serial and (m.mast_id, m.mast_serial) not in ((p_id, p_serial))
         and m.due_type = l_type and d.customer_code = p_customer and d.salesman_code = p_salesman;
    end if;
    return l_v;
  end pay_due;

  procedure pay_det_row (p_id in number, p_serial in number, p_link in number, p_old_link in number) is
  begin
    if nvl(p_link, -1) != nvl(p_old_link, -1) then return; end if;             -- link written by the posting buttons
    pay_check_post(p_id, p_serial);
  end pay_det_row;

  -- PAY_AMOUNT WHEN-VALIDATE-ITEM: not more than TOT_DUE - TOT_PAY (dues less what the other documents paid)
  procedure pay_det_amount (p_id in number, p_serial in number, p_due_serial in number) is
    d ar_customer_dues_pay_det%rowtype;
  begin
    select * into d from ar_customer_dues_pay_det where mast_id = p_id and mast_serial = p_serial and due_serial = p_due_serial;
    if d.customer_code is not null and nvl(d.pay_amount, 0)
         > pay_due(p_id, p_serial, d.customer_code, d.salesman_code, 'DUE') - pay_due(p_id, p_serial, d.customer_code, d.salesman_code, 'PAID') then
      err('قيمة غير صالحة', 'Not Valide Value');
    end if;
  exception when no_data_found then null;
  end pay_det_amount;

  procedure pay_det_check (p_id in number, p_serial in number) is
  begin
    pay_check_post(p_id, p_serial);
  end pay_det_check;

  -- button "تنفيذ": the dues of the department / area (branch, salesman) due up to the payment date, less what was paid up to that date,
  -- one line per customer and salesman
  function pay_fill (p_rowid in varchar2) return varchar2 is
    h      ar_customer_dues_pay%rowtype;
    l_ser  number;
    l_paid number;
    l_n    number;
  begin
    select * into h from ar_customer_dues_pay where rowid = chartorowid(p_rowid);
    pay_check_post(h.mast_id, h.mast_serial);
    select nvl(max(due_serial), 0) into l_ser from ar_customer_dues_pay_det where mast_id = h.mast_id and mast_serial = h.mast_serial;
    for c in (select d.customer_code, d.salesman_code, nvl(sum(d.due_amount), 0) due_amount
                from ar_customer_dues m, ar_customer_dues_det d
               where m.due_type = h.due_type and m.mainarea_id = d.mainarea_id and m.mast_serial = d.mast_serial
                 and m.due_date <= h.pay_date and m.ctgry_code = h.ctgry_code and m.mainarea_id = h.mainarea_id
                 and (h.subarea_id is null or m.subarea_id = h.subarea_id)
                 and (h.salesman_code is null or m.salesman_code = h.salesman_code)
               group by d.customer_code, d.salesman_code order by d.customer_code) loop
      select nvl(sum(d.pay_amount), 0) into l_paid from ar_customer_dues_pay m, ar_customer_dues_pay_det d
       where m.mast_id = d.mast_id and m.mast_serial = d.mast_serial and m.pay_date <= h.pay_date
         and m.due_type = h.due_type and d.customer_code = c.customer_code and d.salesman_code = c.salesman_code;
      select count(*) into l_n from ar_customer_dues_pay_det
       where mast_id = h.mast_id and mast_serial = h.mast_serial and customer_code = c.customer_code and salesman_code = c.salesman_code;
      if c.due_amount - l_paid > 0 and l_n = 0 then
        l_ser := l_ser + 1;
        insert into ar_customer_dues_pay_det (mast_id, mast_serial, due_serial, customer_code, salesman_code, pay_amount)
        values (h.mast_id, h.mast_serial, l_ser, c.customer_code, c.salesman_code, c.due_amount - l_paid);
      end if;
    end loop;
    return null;
  end pay_fill;

  -- button "ترحيل": GL voucher (type / account of the transaction type) debit type account, credit customer account per paid line,
  -- plus the customer's credit transaction (INSERT_CUSTOMER_TRNS: AR_MAINTRNS / AR_SUBTRNS) linked back on the line
  function pay_post (p_rowid in varchar2) return varchar2 is
    h        ar_customer_dues_pay%rowtype;
    l_type   number;
    l_dacc   number;
    l_cacc   number;
    l_year   number;
    l_no     number;
    l_seq    number;
    l_desc   varchar2(400);
    l_c1     number;
    l_c2     number;
    l_n      number := 0;
    l_eff    number;
    l_ctgry  number;
    l_main   number;
    l_sub    number;
    l_tser   number;
    l_slm    number;
  begin
    select * into h from ar_customer_dues_pay where rowid = chartorowid(p_rowid) for update;
    if nvl(h.post_flag, 0) = 1 then err('القيد مرحل', 'The voucher is already posted'); end if;
    select entry_type, account_no, effect, ctgry_code into l_type, l_dacc, l_eff, l_ctgry from ar_trnstype where id = h.mast_id;
    need(l_type, 'يجب تحديد نوع القيد لنوع الحركة', 'The transaction type has no voucher type');
    need(l_dacc, 'يجب تحديد رقم الحساب لنوع الحركة', 'The transaction type has no account');
    l_year := to_number(to_char(h.pay_date, 'YYYY'));
    l_no := app_rules_gl.next_entry_no(l_year, l_type, h.pay_date);
    l_desc := ' صرف حوافز وايجارات العملاء يوم ' || to_char(h.pay_date, 'MONTH-YYYY');
    insert into ac_yearly_trn (entry_year, entry_type, entry_no, doc_no, entry_date, entry_desc, entry_desc_e, currency_code, rate,
                               entry_total, memo, post_system, create_company_code, create_password_number, create_user_code,
                               update_company_code, update_password_number, update_user_code, create_date, update_date)
    values (l_year, l_type, l_no, l_no, h.pay_date, l_desc, null, 1, 1, null, null, 4,
            to_number(v('G_COMPANY_CODE')), grp, to_number(v('G_USER_CODE')), null, null, null, sysdate, null);
    for d in (select * from ar_customer_dues_pay_det where mast_id = h.mast_id and mast_serial = h.mast_serial
                 and nvl(pay_amount, 0) != 0 order by due_serial) loop
      select max(cost_code1), max(account_no), max(mainarea_id), max(subarea_id) into l_c1, l_cacc, l_main, l_sub
        from customer where code = d.customer_code;
      select max(cost_code2) into l_c2 from salesman where code = d.salesman_code;
      if l_cacc is null then
        err('حساب العميل غير موجود' || ' ' || d.customer_code, 'The customer has no account' || ' ' || d.customer_code);
      end if;
      select count(1) + 1 into l_seq from ac_yearly_trn_det where entry_year = l_year and entry_type = l_type and entry_no = l_no;
      insert into ac_yearly_trn_det (entry_year, entry_type, entry_no, seq, entry_date, account_number, entry_desc, entry_desc_e, value,
                                     cost_code, cost_code2, balance_flag, memo, memo_e)
      values (l_year, l_type, l_no, l_seq, h.pay_date, l_dacc, l_desc, null, d.pay_amount,
              decode(substr(l_dacc, 1, 1), 5, l_c1, 4, l_c1, null), decode(substr(l_dacc, 1, 1), 5, l_c2, 4, l_c2, null),
              0, ' اثبات حوافز وايجارات العملاء عميل  رقم ' || d.customer_code, null);
      insert into ac_yearly_trn_det (entry_year, entry_type, entry_no, seq, entry_date, account_number, entry_desc, entry_desc_e, value,
                                     cost_code, cost_code2, balance_flag, memo, memo_e)
      values (l_year, l_type, l_no, l_seq + 1, h.pay_date, l_cacc, l_desc, null, -1 * d.pay_amount,
              decode(substr(l_cacc, 1, 1), 5, l_c1, 4, l_c1, null), decode(substr(l_cacc, 1, 1), 5, l_c2, 4, l_c2, null),
              0, ' صرف حوافز وايجارات العملاء عميل  رقم ' || d.customer_code, null);
      -- INSERT_CUSTOMER_TRNS: the customer's credit transaction of the document's type, linked to the voucher
      select nvl(max(trns_serial), 0) + 1 into l_tser from ar_maintrns where trns_id = h.mast_id and mainarea_id = l_main and subarea_id = l_sub;
      select min(salesman_code) into l_slm from ar_cust_salesman where customer_code = d.customer_code and ctgry_code = l_ctgry;
      insert into ar_maintrns (trns_id, mainarea_id, subarea_id, trns_serial, ctgry_code, trns_date, doc_no, total_value, disc_value, net_value,
                               description_a, description_e, customer_id, link_flag, post_flag, residual_value, currency_code, currency_rate,
                               acc_year, acc_type, acc_no, acc_date, post_system, salesman_id)
      values (h.mast_id, l_main, l_sub, l_tser, l_ctgry, h.pay_date, h.mast_serial, d.pay_amount, 0, d.pay_amount,
              'صرف حوافز وايجارات العملاء', null, d.customer_code, 1, 1, d.pay_amount, 1, 1,
              l_year, l_type, l_no, h.pay_date, 4, nvl(l_slm, d.salesman_code));
      insert into ar_subtrns (trns_id, mainarea_id, subarea_id, trns_serial, bill_seq, bill_id1, bill_id2, total_value, disc_value, net_value,
                              residual_value, inv_date)
      values (h.mast_id, l_main, l_sub, l_tser, 1, null, null, d.pay_amount, 0, d.pay_amount, d.pay_amount, h.pay_date);
      update ar_customer_dues_pay_det set ar_trns_id = h.mast_id, ar_trns_serial = l_tser, ar_mainarea_id = l_main, ar_subarea_id = l_sub
       where mast_id = d.mast_id and mast_serial = d.mast_serial and due_serial = d.due_serial;
      l_n := l_n + 1;
    end loop;
    if l_n = 0 then
      err('لا توجد مبالغ منصرفة للترحيل', 'There are no paid amounts to post');
    end if;
    update ar_customer_dues_pay set post_flag = 1, entry_year = l_year, entry_type = l_type, entry_no = l_no where rowid = chartorowid(p_rowid);
    return null;
  end pay_post;

  -- button "الغاء ترحيل": deletes the voucher and the customers' transactions of the document
  function pay_unpost (p_rowid in varchar2) return varchar2 is
    h ar_customer_dues_pay%rowtype;
  begin
    select * into h from ar_customer_dues_pay where rowid = chartorowid(p_rowid) for update;
    if nvl(h.post_flag, 0) = 0 then err('القيد غر مرحل', 'The voucher is not posted'); end if;
    check_close(h.pay_date);
    delete from ac_yearly_trn_det where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
    delete from ac_yearly_trn where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
    update ar_customer_dues_pay set post_flag = 0, entry_year = null, entry_type = null, entry_no = null where rowid = chartorowid(p_rowid);
    for d in (select * from ar_customer_dues_pay_det where mast_id = h.mast_id and mast_serial = h.mast_serial and ar_trns_id is not null) loop
      -- the legacy deletes AR_MAINTRNS only; its lines (AR_SUBTRNS, foreign key AR_SUBTRNS_FK) must go first
      delete from ar_subtrns where trns_id = d.ar_trns_id and trns_serial = d.ar_trns_serial
                               and mainarea_id = d.ar_mainarea_id and subarea_id = d.ar_subarea_id;
      delete from ar_maintrns where trns_id = d.ar_trns_id and trns_serial = d.ar_trns_serial
                                and mainarea_id = d.ar_mainarea_id and subarea_id = d.ar_subarea_id;
      update ar_customer_dues_pay_det set ar_trns_id = null, ar_trns_serial = null, ar_mainarea_id = null, ar_subarea_id = null
       where mast_id = d.mast_id and mast_serial = d.mast_serial and due_serial = d.due_serial;
    end loop;
    return null;
  end pay_unpost;


  -- =================================================================================== AR_SALESMAN_COLL_PAY (salesmen collections -> cash boxes / bank)
  function next_coll_serial (p_salesman in number) return number is
    l_n number;
  begin
    select nvl(max(serial), 0) + 1 into l_n from ar_sls_coll_mast where salesman_id = p_salesman;
    return l_n;
  end next_coll_serial;

  -- header: salesman of the group (LOV SALESMAN_LOV), CHECK_DATE, date locked unless the group may change dates (PASSWORD.CHANGE_DATE),
  -- DOC_NO NVL(MAX(TO_NUMBER(DOC_NO)),0)+1 per salesman and the legacy NOTES text
  procedure coll_mast_row (p_ins in boolean, p_salesman in number, p_date in date, p_old_date in date,
                           p_doc_no in out varchar2, p_notes in out varchar2) is
    l_n   number;
    l_chg number;
    l_msg varchar2(400);
  begin
    select count(*) into l_n from salesman
     where code = p_salesman and (nvl(grp, 0) = 0 or code in (select salesman_code from ar_salesman_password where password_number = grp));
    if l_n = 0 then err('المندوب غير موجود أو غير مسموح به للمجموعة', 'Salesman not found or not allowed for the group'); end if;
    need(to_char(p_date, 'DD/MM/YYYY'), 'يجب إدخال تاريخ الحركة', 'Enter the transaction date');
    if p_ins or trunc(p_date) != trunc(nvl(p_old_date, p_date - 1)) then
      l_msg := check_date_msg(p_date);
      if l_msg is not null then err(l_msg, l_msg); end if;
      select max(change_date) into l_chg from password where password_number = nvl(grp, 0);
      if nvl(l_chg, 0) != 1 and trunc(p_date) != trunc(case when p_ins then sysdate else p_old_date end) then
        err('غير مسموح لمجموعتك بتغيير تاريخ الحركة', 'Your group is not allowed to change the transaction date');
      end if;
    end if;
    if p_ins and p_doc_no is null then
      select nvl(max(to_number(doc_no)), 0) + 1 into p_doc_no from ar_sls_coll_mast where salesman_id = p_salesman;
    end if;
    if p_ins and p_notes is null then
      p_notes := 'توجيه سندات تحصيل من مناديب على سندات القبض من امناء الصناديق برقم مستند -' || p_doc_no;
    end if;
  end coll_mast_row;

  -- lines: AR_FLAG 1 = customers' payments collected by the salesman (LOV AR_LOV), AR_FLAG 0 = cash-box receipts (LOV RP_LOV)
  procedure coll_det_row (p_ins in boolean, p_salesman in number, p_serial in number, p_ar_flag in number,
                          p_ar_id in number, p_ar_main in number, p_ar_sub in number, p_ar_serial in number,
                          p_rp_id in number, p_rp_serial in number, p_choose in number, p_old_choose in number,
                          p_value in out number, p_ar_doc in out number, p_rp_doc in out number) is
    l_date date;
    l_doc  number;
    l_val  number;
  begin
    select max(trns_date) into l_date from ar_sls_coll_mast where salesman_id = p_salesman and serial = p_serial;
    if p_ar_flag = 1 then
      need(p_ar_serial, 'يجب اختيار حركة سداد العميل', 'Choose the customer payment');
      select max(m.doc_no), max(m.total_value) into l_doc, l_val
        from ar_maintrns m
       where m.trns_id = p_ar_id and m.mainarea_id = p_ar_main and m.subarea_id = p_ar_sub and m.trns_serial = p_ar_serial
         and nvl(m.link_flag, 0) = 0 and m.trns_id in (select id from ar_trnstype where effect = 1 and mobile_trns = 1)
         and m.salesman_id = p_salesman and m.trns_date <= l_date and nvl(m.cash_flag, 0) = 2;
      if l_val is null then
        err('الحركة ليست من سدادات العملاء النقدية للمندوب', 'Not a cash customer payment of the salesman');
      end if;
      p_ar_doc := l_doc; p_value := l_val;                                -- LKP_DET / AR_LOV values
    elsif p_ar_flag = 0 then
      need(p_rp_serial, 'يجب اختيار سند القبض', 'Choose the cash-box receipt');
      select count(*), max(m.doc_no) into l_val, l_doc from rp_trns_mast m
       where m.trns_type_code = p_rp_id and m.trns_serial = p_rp_serial
         and m.trns_type_code in (select trns_type_code from rp_trns_type where effect = 1 and cash_col_flag = 1)
         and m.salesman_code = p_salesman and substr(m.box_code, 1, 1) = '1' and m.trns_date <= l_date and nvl(m.del_flag, 0) = 0
         and get_rp_used_others_count(m.trns_type_code, m.trns_serial) = 0;
      if l_val = 0 then
        err('سند القبض ليس من سندات تحصيل المندوب', 'Not a collection receipt of the salesman');
      end if;
      p_rp_doc := l_doc;
      if nvl(p_value, 0) <= 0 then err('القيمة اقل من او تساوى الصفر', 'The value is less than or equal to zero'); end if;
    else
      err('نوع السطر: 1 سداد عميل / 0 سند قبض', 'Line type: 1 customer payment / 0 cash-box receipt');
    end if;
  end coll_det_row;

  -- after the statement (the checks read AR_SLS_COLL_DET): "تم ادخال الحركة من قبل" (payment chosen twice),
  -- "لقد تعديت المبلغ المتبقى لهذا السند" (GET_RESIDUAL_RP_TRNS)
  procedure coll_det_check (p_salesman in number, p_serial in number, p_ar_flag in number, p_det_serial in number) is
    d   ar_sls_coll_det%rowtype;
    l_n number;
  begin
    select * into d from ar_sls_coll_det where salesman_id = p_salesman and serial = p_serial and ar_flag = p_ar_flag and det_serial = p_det_serial;
    if d.ar_flag = 1 and nvl(d.choose_flag, 0) = 1 then
      select count(1) into l_n from ar_sls_coll_det
       where ar_trns_id = d.ar_trns_id and ar_trns_serial = d.ar_trns_serial and ar_mainarea_id = d.ar_mainarea_id
         and ar_subarea_id = d.ar_subarea_id and nvl(choose_flag, 0) = 1;
      if l_n > 1 then err('تم ادخال الحركة من قبل', 'The transaction was entered before'); end if;
    elsif d.ar_flag = 0 and get_residual_rp_trns(d.rp_trns_id, d.rp_trns_serial) < 0 then
      err('لقد تعديت المبلغ المتبقى لهذا السند', 'You exceeded the remaining amount of this receipt');
    end if;
  exception when no_data_found then null;
  end coll_det_check;

  -- deleting a chosen payment frees it again (intent of the DB trigger AR_SLS_COLL_DET_TRG, whose DELETING branch uses :NEW)
  procedure coll_det_del (p_ar_flag in number, p_choose in number, p_ar_id in number, p_ar_main in number, p_ar_sub in number,
                          p_ar_serial in number) is
  begin
    if p_ar_flag = 1 and nvl(p_choose, 0) = 1 then
      update ar_maintrns set pay_flag = 0
       where trns_id = p_ar_id and trns_serial = p_ar_serial and mainarea_id = p_ar_main and subarea_id = p_ar_sub;
    end if;
  end coll_det_del;

  -- bank deposits of the salesman (LOV MOB_LOV): approved (TRNS_STATUS 1) up to the document date; the value > 0
  procedure coll_trf_row (p_ins in boolean, p_salesman in number, p_serial in number, p_seq in number, p_value in number,
                          p_date in out date, p_bank in out number, p_branch in out number, p_pay_type in out number) is
    l_date date;
    r      mob_deposite_trns%rowtype;
  begin
    select max(trns_date) into l_date from ar_sls_coll_mast where salesman_id = p_salesman and serial = p_serial;
    need(p_seq, 'يجب اختيار الايداع البنكى', 'Choose the bank deposit');
    begin
      select * into r from mob_deposite_trns
       where mob_trns_seq = p_seq and salesman_id = p_salesman and trunc(trns_date) <= l_date and nvl(trns_status, 0) = 1;
    exception when no_data_found then
      err('الايداع ليس من الايداعات البنكية المعتمدة للمندوب', 'Not an approved bank deposit of the salesman');
    end;
    p_date := r.trns_date; p_bank := r.bank_code; p_branch := r.branch_code; p_pay_type := r.pay_type;
    if nvl(p_value, 0) <= 0 then err('القيمة اقل من او تساوى الصفر', 'The value is less than or equal to zero'); end if;
  end coll_trf_row;

  procedure coll_trf_check (p_seq in number) is
  begin
    if get_residual_mob_trns(p_seq) < 0 then
      err('لقد تعديت المبلغ المتبقى لهذا السند', 'You exceeded the remaining amount of this receipt');
    end if;
  end coll_trf_check;

  -- CHECK_DB_BALANCE totals: AR = chosen customers' payments, RP = cash-box receipts, TRF = bank deposits
  function coll_total (p_salesman in number, p_serial in number, p_what in varchar2) return number is
    l_v number;
  begin
    if p_what = 'AR' then
      select sum(trns_value) into l_v from ar_sls_coll_det
       where salesman_id = p_salesman and serial = p_serial and nvl(ar_flag, 0) = 1 and nvl(choose_flag, 0) = 1;
    elsif p_what = 'ARN' then
      select count(*) into l_v from ar_sls_coll_det
       where salesman_id = p_salesman and serial = p_serial and nvl(ar_flag, 0) = 1 and nvl(choose_flag, 0) = 1;
    elsif p_what = 'RP' then
      select sum(trns_value) into l_v from ar_sls_coll_det where salesman_id = p_salesman and serial = p_serial and nvl(ar_flag, 0) = 0;
    else
      select sum(mob_trns_value) into l_v from ar_sls_coll_trnsfer where salesman_id = p_salesman and serial = p_serial;
    end if;
    return nvl(l_v, 0);
  end coll_total;

  -- "الحركة غير متوازنة": chosen payments = cash-box receipts + bank deposits (after the document is saved)
  procedure coll_balance (p_rowid in varchar2) is
    h ar_sls_coll_mast%rowtype;
  begin
    if p_rowid is null then return; end if;
    select * into h from ar_sls_coll_mast where rowid = chartorowid(p_rowid);
    if coll_total(h.salesman_id, h.serial, 'AR') != coll_total(h.salesman_id, h.serial, 'RP') + coll_total(h.salesman_id, h.serial, 'TRF') then
      err('الحركة غير متوازنة', 'Unblanced entry');
    end if;
  exception when no_data_found then null;
  end coll_balance;

  -- button "انزال سدادات العملاء"
  function coll_load_ar (p_rowid in varchar2) return varchar2 is
    h     ar_sls_coll_mast%rowtype;
    l_n   number;
    l_ser number;
  begin
    select * into h from ar_sls_coll_mast where rowid = chartorowid(p_rowid);
    select count(1) into l_n from ar_sls_coll_det where salesman_id = h.salesman_id and serial = h.serial and nvl(ar_flag, 0) = 1;
    if l_n > 0 then err('تم حفظ الحركة لايمكن التعديل', 'The transaction is saved, it cannot be changed'); end if;
    l_ser := 0;
    for r in (select m.doc_no, m.total_value, m.trns_id, m.trns_serial, m.mainarea_id, m.subarea_id
                from ar_maintrns m, customer c
               where m.customer_id = c.code and nvl(m.link_flag, 0) = 0
                 and m.trns_id in (select id from ar_trnstype where effect = 1 and mobile_trns = 1)
                 and m.salesman_id = h.salesman_id and m.trns_date <= h.trns_date and nvl(m.pay_flag, 0) = 0 and nvl(m.cash_flag, 0) = 2
               order by m.trns_date, m.doc_no) loop
      l_ser := l_ser + 1;
      insert into ar_sls_coll_det (serial, salesman_id, ar_flag, det_serial, ar_trns_id, ar_trns_serial, ar_mainarea_id, ar_subarea_id,
                                   ar_doc_no, trns_value, choose_flag)
      values (h.serial, h.salesman_id, 1, l_ser, r.trns_id, r.trns_serial, r.mainarea_id, r.subarea_id, r.doc_no, r.total_value, 0);
    end loop;
    return null;
  end coll_load_ar;

  -- button "انزال سندات القبض": the salesman's collection receipts of the cash boxes with a remaining amount
  function coll_load_rp (p_rowid in varchar2) return varchar2 is
    h     ar_sls_coll_mast%rowtype;
    l_n   number;
    l_ser number := 0;
  begin
    select * into h from ar_sls_coll_mast where rowid = chartorowid(p_rowid);
    select count(1) into l_n from ar_sls_coll_det where salesman_id = h.salesman_id and serial = h.serial and nvl(ar_flag, 0) = 0;
    if l_n > 0 then err('تم حفظ الحركة لايمكن التعديل', 'The transaction is saved, it cannot be changed'); end if;
    for r in (select m.doc_no, get_residual_rp_trns(m.trns_type_code, m.trns_serial) res_value, m.trns_type_code, m.trns_serial
                from rp_trns_mast m
               where m.trns_type_code in (select trns_type_code from rp_trns_type where effect = 1 and cash_col_flag = 1)
                 and m.salesman_code = h.salesman_id and m.trns_date <= h.trns_date
                 and get_residual_rp_trns(m.trns_type_code, m.trns_serial) > 0 and substr(m.box_code, 1, 1) = '1'
                 and nvl(m.del_flag, 0) = 0 and get_rp_used_others_count(m.trns_type_code, m.trns_serial) = 0
               order by m.trns_date, m.doc_no) loop
      l_ser := l_ser + 1;
      insert into ar_sls_coll_det (serial, salesman_id, ar_flag, det_serial, rp_trns_id, rp_trns_serial, rp_doc_no, trns_value)
      values (h.serial, h.salesman_id, 0, l_ser, r.trns_type_code, r.trns_serial, r.doc_no, r.res_value);
    end loop;
    return null;
  end coll_load_rp;

  -- button "انزال الايداعات البنكية": the salesman's approved bank deposits with a remaining amount
  function coll_load_mob (p_rowid in varchar2) return varchar2 is
    h     ar_sls_coll_mast%rowtype;
    l_n   number;
    l_ser number := 0;
  begin
    select * into h from ar_sls_coll_mast where rowid = chartorowid(p_rowid);
    select count(1) into l_n from ar_sls_coll_trnsfer where salesman_id = h.salesman_id and serial = h.serial;
    if l_n > 0 then err('تم حفظ الحركة لايمكن التعديل', 'The transaction is saved, it cannot be changed'); end if;
    for r in (select m.mob_trns_seq, get_residual_mob_trns(m.mob_trns_seq) res_amount, m.pay_type, m.trns_date, m.bank_code, m.branch_code
                from mob_deposite_trns m
               where m.salesman_id = h.salesman_id and trunc(m.trns_date) <= h.trns_date
                 and get_residual_mob_trns(m.mob_trns_seq) > 0 and nvl(m.trns_status, 0) = 1
               order by m.mob_trns_seq) loop
      l_ser := l_ser + 1;
      insert into ar_sls_coll_trnsfer (serial, salesman_id, det_serial, mob_trns_seq, mob_trns_date, mob_trns_value, mob_bank_code,
                                       mob_branch_code, mob_pay_type)
      values (h.serial, h.salesman_id, l_ser, r.mob_trns_seq, r.trns_date, r.res_amount, r.bank_code, r.branch_code, r.pay_type);
    end loop;
    return null;
  end coll_load_mob;


  -- =================================================================================== AR_MOB_DEPOSITE_TRNS (salesmen bank deposits)
  procedure mob_row (p_ins in boolean, p_salesman in number, p_date in date, p_total in number, p_bank in number, p_branch in number,
                     p_pay_type in number, p_ref in varchar2, p_posted_date in date, p_status in number, p_post in number,
                     p_old_salesman in number, p_old_date in date, p_old_total in number, p_old_bank in number, p_old_branch in number,
                     p_old_pay_type in number, p_old_ref in varchar2, p_old_posted_date in date, p_old_status in number, p_old_post in number) is
    l_n    number;
    l_main boolean;
  begin
    l_main := p_ins or nvl(p_salesman, -1) != nvl(p_old_salesman, -1) or nvl(p_date, sysdate) != nvl(p_old_date, sysdate)
              or nvl(p_total, -1) != nvl(p_old_total, -1) or nvl(p_bank, -1) != nvl(p_old_bank, -1)
              or nvl(p_branch, -1) != nvl(p_old_branch, -1) or nvl(p_pay_type, -1) != nvl(p_old_pay_type, -1)
              or nvl(p_ref, '#') != nvl(p_old_ref, '#');
    -- CLOSE_MAIN_POSTED: an approved / refused deposit is closed
    if not p_ins and nvl(p_old_status, 0) != 0 and l_main then
      err('تم عمل اجراء على هذه الحركة من قبل', 'Trnsaction Done Before');
    end if;
    if not p_ins and nvl(p_old_post, 0) = 1 and nvl(p_post, 0) = 1
       and nvl(p_posted_date, sysdate) != nvl(p_old_posted_date, sysdate) then
      err('القيد مرحل', 'The voucher is already posted');
    end if;
    if l_main then
      need(p_pay_type, 'يجب إدخال نوع الحركة', 'You Must Enter Transaction Type');
      select count(*) into l_n from salesman
       where code = p_salesman and (nvl(grp, 0) = 0 or code in (select salesman_code from ar_salesman_password where password_number = grp));
      if l_n = 0 then err('المندوب غير موجود أو غير مسموح به للمجموعة', 'Salesman not found or not allowed for the group'); end if;
      if p_bank is not null then
        select count(*) into l_n from bank
         where code = p_bank and (nvl(grp, 0) = 0 or code in (select bank_code from bank_password where password_number = grp));
        if l_n = 0 then err('البنك غير موجود أو غير مسموح به للمجموعة', 'Bank not found or not allowed for the group'); end if;
      end if;
      if p_branch is not null then
        select count(*) into l_n from bank_branchs where bank_code = p_bank and code = p_branch;
        if l_n = 0 then err('الفرع غير موجود لهذا البنك', 'Branch not found for this bank'); end if;
      end if;
    end if;
    if p_posted_date is not null and (p_ins or nvl(p_posted_date, sysdate) != nvl(p_old_posted_date, sysdate) or l_main) then
      if trunc(p_posted_date) < trunc(p_date) then
        err('يجب ان يكون تاريخ الترحيل اكبر من او يساوى تاريخ الحركة', 'Posted Trns Date Must Be Greater Than Trns Date');
      end if;
      if trunc(p_posted_date) > trunc(sysdate) then
        err('يجب ان يكون تاريخ الترحيل اصغر من او يساوى تاريخ اليوم', 'Posted Trns Date Must Be Less Or Equal Than Current Date');
      end if;
    end if;
  end mob_row;

  procedure mob_del (p_status in number) is
  begin
    if nvl(p_status, 0) != 0 then err('تم عمل اجراء على هذه الحركة من قبل', 'Trnsaction Done Before'); end if;
  end mob_del;

  -- button "اعتماد"
  function mob_auth (p_rowid in varchar2) return varchar2 is
    r   mob_deposite_trns%rowtype;
    l_n number;
  begin
    select * into r from mob_deposite_trns where rowid = chartorowid(p_rowid) for update;
    if nvl(r.trns_status, 0) != 0 then err('تم عمل اجراء على هذه الحركة من قبل', 'Trnsaction Done Before'); end if;
    if r.ref_doc is null then err('يجب ادخال مرجع البنك', 'BANK DOC REF Must Enter'); end if;
    select count(1) into l_n from mob_deposite_trns
     where salesman_id = r.salesman_id and bank_code = r.bank_code and total_value = r.total_value and ref_doc = r.ref_doc
       and nvl(trns_status, 0) = 1;
    if l_n > 0 then err('هذا الايداع مكرر لنفس المندوب بنفس البنك', 'This deposit is repeated for the same salesman and bank'); end if;
    update mob_deposite_trns set trns_status = 1 where rowid = chartorowid(p_rowid);
    return null;
  end mob_auth;

  -- button "رفض"
  function mob_refuse (p_rowid in varchar2) return varchar2 is
    r mob_deposite_trns%rowtype;
  begin
    select * into r from mob_deposite_trns where rowid = chartorowid(p_rowid) for update;
    if nvl(r.trns_status, 0) = 2 then err('تم عمل اجراء على هذه الحركة من قبل', 'Trnsaction Done Before'); end if;
    if r.entry_no is not null then err('يجب الغاء الترحيل اولا', 'Trnsaction Posted Before'); end if;
    update mob_deposite_trns set trns_status = 2 where rowid = chartorowid(p_rowid);
    return null;
  end mob_refuse;

  -- button "الترحيل": voucher debit the bank branch account (BANK_BRANCHS.BRNCH_ACC_CHRT_NO), credit the salesman's account of the
  -- pay type (AR_SALESMAN_ACCOUNT, ACCOUNT_TYPE = DECODE(PAY_TYPE, 0, 1, 1, 2, 2, 3)), voucher type of the salesman's area
  function mob_post (p_rowid in varchar2) return varchar2 is
    r       mob_deposite_trns%rowtype;
    l_bacc  number;
    l_atype number;
    l_sacc  number;
    l_c1    number;
    l_c2    number;
    l_type  number;
    l_year  number;
    l_no    number;
    l_desc  varchar2(1000);
    l_sname varchar2(200);
    l_aname varchar2(200);
  begin
    select * into r from mob_deposite_trns where rowid = chartorowid(p_rowid) for update;
    if nvl(r.trns_status, 0) != 1 then err('الحركة غير معتمدة', 'Transaction Not Auth'); end if;
    if nvl(r.post_flag, 0) = 1 then err('القيد مرحل', 'The voucher is already posted'); end if;
    if r.posted_trns_date is null then err('يجب ادخال تاريخ الترحيل', 'Posted Trns Date Must Enter'); end if;
    select max(brnch_acc_chrt_no) into l_bacc from bank_branchs where bank_code = r.bank_code and code = r.branch_code;
    if l_bacc is null then err('خطا بحساب الفرع', 'Error In Account Branch'); end if;
    l_atype := case nvl(r.pay_type, 0) when 0 then 1 when 1 then 2 when 2 then 3 end;
    select max(salesman_account_no) into l_sacc from ar_salesman_account where salesman_id = r.salesman_id and account_type = l_atype;
    if l_sacc is null then err('خطا بحساب المندوب', 'Error In Salesman Account'); end if;
    select max(cost_code1), max(cost_code2), max(name_a) into l_c1, l_c2, l_sname from salesman where code = r.salesman_id;
    select max(a.entry_type) into l_type from ar_mainarea a, salesman s where s.code = r.salesman_id and a.id = s.mainarea_id;
    if l_type is null then err('يجب إدخال رقم نوع قيد الترحيل في ملف المناطق', 'Enter the posting voucher type in the areas file'); end if;
    if nvl(r.total_value, 0) = 0 then err('لا يمكن ترحيل حركة بقيمة صفر', 'Not Posted with Value 0'); end if;
    select max(account_name) into l_aname from ac_master where account_number = l_bacc;
    l_year := to_number(to_char(r.posted_trns_date, 'YYYY'));
    l_no := app_rules_gl.next_entry_no(l_year, l_type, r.posted_trns_date);
    l_desc := 'صرف من صندوق ' || case when nvl(r.pay_type, 0) = 0 then 'نقدى' else 'حوالات' end || ' للمندوب ' || l_sname
              || ' بإيداع بنكى بحساب ' || l_aname || ' بتاريخ ' || to_char(r.trns_date, 'DD-MM-YYYY') || ' مسلسل # ' || r.mob_trns_seq;
    insert into ac_yearly_trn (entry_year, entry_type, entry_no, doc_no, entry_date, entry_desc, entry_desc_e, currency_code, rate,
                               entry_total, memo, post_system, create_company_code, create_password_number, create_user_code,
                               update_company_code, update_password_number, update_user_code, create_date, update_date)
    values (l_year, l_type, l_no, r.mob_trns_seq, r.posted_trns_date, l_desc, l_desc, 1, 1, r.total_value, null, 4,
            to_number(v('G_COMPANY_CODE')), grp, to_number(v('G_USER_CODE')), null, null, null, sysdate, null);
    insert into ac_yearly_trn_det (entry_year, entry_type, entry_no, seq, entry_date, account_number, entry_desc, entry_desc_e, value,
                                   cost_code, cost_code2, balance_flag, memo, memo_e)
    values (l_year, l_type, l_no, 1, r.posted_trns_date, l_bacc, l_desc, l_desc, r.total_value, l_c1, l_c2, 0, l_desc, l_desc);
    insert into ac_yearly_trn_det (entry_year, entry_type, entry_no, seq, entry_date, account_number, entry_desc, entry_desc_e, value,
                                   cost_code, cost_code2, balance_flag, memo, memo_e)
    values (l_year, l_type, l_no, 2, r.posted_trns_date, l_sacc, l_desc, l_desc, -1 * r.total_value, l_c1, l_c2, 0, l_desc, l_desc);
    update mob_deposite_trns set post_flag = 1, entry_year = l_year, entry_type = l_type, entry_no = l_no where rowid = chartorowid(p_rowid);
    return null;
  end mob_post;

  -- button "الغاء الترحيل"
  function mob_unpost (p_rowid in varchar2) return varchar2 is
    r mob_deposite_trns%rowtype;
  begin
    select * into r from mob_deposite_trns where rowid = chartorowid(p_rowid) for update;
    if nvl(r.post_flag, 0) != 1 then err('القيد غر مرحل', 'The voucher is not posted'); end if;
    if r.entry_type is null then err('يجب إدخال رقم نوع قيد الترحيل في مؤشرات النظام', 'Enter the posting voucher type'); end if;
    check_close(r.trns_date);
    delete from ac_yearly_trn_det where entry_year = r.entry_year and entry_type = r.entry_type and entry_no = r.entry_no;
    delete from ac_yearly_trn where entry_year = r.entry_year and entry_type = r.entry_type and entry_no = r.entry_no;
    update mob_deposite_trns set post_flag = 0, entry_year = null, entry_type = null, entry_no = null where rowid = chartorowid(p_rowid);
    return null;
  end mob_unpost;


  -- =================================================================================== ARCRTRN_DAILY (external customers' cheques / transfers)
  -- row rule: the block WHERE (credit types except opening balances, the group's types / customers / salesmen), CASH_FLAG required,
  -- approval date not before the transaction nor after today, closed once approved / refused (CLOSE_MAIN_POSTED)
  procedure daily_row (p_ins in boolean, p_trns_id in number, p_customer in number, p_salesman in number, p_date in date,
                       p_cash_flag in number, p_auth_date in date, p_old_auth_date in date, p_status in number, p_old_status in number) is
    l_n number;
  begin
    if not p_ins and nvl(p_old_status, 0) != 0 and nvl(p_status, 0) = nvl(p_old_status, 0) then
      err('تم عمل اجراء على هذه الحركة من قبل', 'Trnsaction Done Before');
    end if;
    select count(*) into l_n from ar_trnstype
     where id = p_trns_id and effect = 1 and trns_type <> 6
       and (nvl(grp, 0) = 0 or id in (select trns_id from ar_trnstype_password where flag = 1 and password_number = grp));
    if l_n = 0 then err('رقم الحركة غير صحيح', 'Invalid transaction type'); end if;
    if nvl(grp, 0) != 0 then
      select count(*) into l_n from dual
       where p_customer in (select customer_code from ar_cust_password where password_number = grp)
         and p_salesman in (select salesman_code from ar_salesman_password where password_number = grp);
      if l_n = 0 then err('العميل أو المندوب غير مسموح به للمجموعة', 'Customer or salesman not allowed for the group'); end if;
    end if;
    need(p_cash_flag, 'يجب إدخال نوع الحركة', 'You Must Enter Transaction Type');
    if p_auth_date is not null and (p_ins or trunc(p_auth_date) != trunc(nvl(p_old_auth_date, p_auth_date - 1))) then
      if trunc(p_auth_date) < trunc(p_date) then
        err('يجب ان يكون تاريخ الاعتماد اكبر من او يساوى تاريخ الحركة', 'Auth Trns Date Must Be Greater Than Trns Date');
      end if;
      if trunc(p_auth_date) > trunc(sysdate) then
        err('يجب ان يكون تاريخ الاعتماد اصغر من او يساوى تاريخ اليوم', 'Auth Trns Date Must Be Less Or Equal Than Current Date');
      end if;
    end if;
  end daily_row;

  -- REF_DOC (WHEN-VALIDATE-ITEM): the same deposit (salesman, bank, value, bank reference) already approved
  procedure daily_ref_check (p_trns_id in number, p_main in number, p_sub in number, p_serial in number) is
    r   ar_maintrns_daily%rowtype;
    l_n number;
  begin
    select * into r from ar_maintrns_daily where trns_id = p_trns_id and mainarea_id = p_main and subarea_id = p_sub and trns_serial = p_serial;
    if r.ref_doc is null then return; end if;
    select count(1) into l_n from ar_maintrns_daily
     where salesman_id = r.salesman_id and bank_code = r.bank_code and total_value = r.total_value and ref_doc = r.ref_doc
       and nvl(trns_status, 0) = 1
       and not (trns_id = p_trns_id and mainarea_id = p_main and subarea_id = p_sub and trns_serial = p_serial);
    if l_n > 0 then err('هذا الايداع مكرر لنفس المندوب بنفس البنك', 'This deposit is repeated for the same salesman and bank'); end if;
  exception when no_data_found then null;
  end daily_ref_check;

  procedure daily_del (p_status in number, p_post in number) is
  begin
    if nvl(p_status, 0) != 0 then err('تم عمل اجراء على هذه الحركة من قبل', 'Trnsaction Done Before'); end if;
    if nvl(p_post, 0) = 1 then err('يجب الغاء الترحيل اولا', 'Trnsaction Posted Before'); end if;
  end daily_del;

  -- =================================================================================== AR_SALESMAN_COMM_REV (salesmen commissions review)
  -- ACT_COMM_PRC <-> ACT_COMM_VALUE (and the sales ACT_S_*): value = net * percent / 100, percent = value / net * 100 (item triggers);
  -- only for the user's grid changes on this screen (the calculation procedure writes both)
  procedure comm_value_row (p_net in number, p_prc in out number, p_value in out number, p_old_prc in number, p_old_value in number) is
  begin
    if not is_form('AR_SALESMAN_COMM_REV') or nvl(v('REQUEST'), '#') like 'ACT%' then return; end if;
    if nvl(p_prc, -1) != nvl(p_old_prc, -1) and nvl(p_value, -1) = nvl(p_old_value, -1) then
      p_value := p_net * p_prc / 100;
    elsif nvl(p_value, -1) != nvl(p_old_value, -1) and nvl(p_prc, -1) = nvl(p_old_prc, -1) and nvl(p_net, 0) != 0 then
      p_prc := p_value / p_net * 100;
    end if;
  end comm_value_row;

  -- button "إحتساب العمولة": GET_SALESMAN_COMM for the month (the legacy procedure commits its steps)
  function comm_calc (p_rowid in varchar2, p_month in number, p_year in number) return varchar2 is
    l_code number;
    l_n    number;
    l_from date;
  begin
    begin
      select code into l_code from salesman where rowid = chartorowid(p_rowid);
    exception when others then l_code := null;
    end;
    if l_code is null then err('لم يتم اختيار مندوب لإحتساب العمولة', 'There is no Salesman to calculate its Comm.'); end if;
    need(p_month, 'يجب إدخال الشهر', 'Enter the month');
    need(p_year, 'يجب إدخال السنة', 'Enter the year');
    select count(1) into l_n from ar_comm_pay where salesman_code = l_code and comm_month = p_month and comm_year = p_year;
    if l_n > 0 then err('تم احتساب العمولة للمندوب سابقا', 'Comm. has been calculated before'); end if;
    l_from := to_date('01' || lpad(p_month, 2, '0') || p_year, 'DDMMYYYY');
    get_salesman_comm(l_code, p_month, p_year, l_from, last_day(l_from));
    return null;
  end comm_calc;

  -- button "حذف العمولة": the month's commission lines of the salesman
  function comm_delete (p_rowid in varchar2, p_month in number, p_year in number) return varchar2 is
    l_code number;
  begin
    begin
      select code into l_code from salesman where rowid = chartorowid(p_rowid);
    exception when others then l_code := null;
    end;
    if l_code is null then err('لم يتم اختيار مندوب لحذف العمولة', 'There is no Salesman to delete its Comm.'); end if;
    delete from ar_comm_pay_items i
     where (trns_id, trns_serial, mainarea_id, subarea_id, bill_seq, comm_month, comm_year) in
           (select p.trns_id, p.trns_serial, p.mainarea_id, p.subarea_id, p.bill_seq, p.comm_month, p.comm_year
              from ar_comm_pay p where p.salesman_code = l_code and p.comm_month = p_month and p.comm_year = p_year);
    delete from ar_comm_pay where salesman_code = l_code and comm_month = p_month and comm_year = p_year;
    delete from ar_comm_sales_items i
     where (trns_id, trns_serial, mainarea_id, subarea_id, bill_seq, comm_month, comm_year) in
           (select p.trns_id, p.trns_serial, p.mainarea_id, p.subarea_id, p.bill_seq, p.comm_month, p.comm_year
              from ar_comm_sales p where p.salesman_code = l_code and p.comm_month = p_month and p.comm_year = p_year);
    delete from ar_comm_sales where salesman_code = l_code and comm_month = p_month and comm_year = p_year;
    delete from ar_comm_ages where salesman_code = l_code and comm_month = p_month and comm_year = p_year;
    return null;
  end comm_delete;

  -- info panel: last calculated month and its totals, supervisor
  function comm_last (p_salesman in number, p_what in varchar2) return varchar2 is
    l_ym  number;
    l_v   number;
    l_txt varchar2(200);
  begin
    if p_what = 'SUP' then
      select max(msg(s2.name_a, s2.name_e)) into l_txt from salesman s1, salesman s2 where s1.code = p_salesman and s2.code = s1.supervisor_slsman;
      return l_txt;
    end if;
    select max(comm_year * 100 + comm_month) into l_ym from ar_comm_pay where salesman_code = p_salesman;
    if l_ym is null then return null; end if;
    if p_what = 'MONTH' then return lpad(mod(l_ym, 100), 2, '0') || '/' || trunc(l_ym / 100); end if;
    if p_what = 'NET' then
      select sum(net_value) into l_v from ar_comm_pay where salesman_code = p_salesman and comm_year * 100 + comm_month = l_ym;
    elsif p_what = 'PAYC' then
      select sum(act_comm_value) into l_v from ar_comm_pay where salesman_code = p_salesman and comm_year * 100 + comm_month = l_ym;
    elsif p_what = 'SALC' then
      select sum(act_s_comm_value) into l_v from ar_comm_sales where salesman_code = p_salesman and comm_year * 100 + comm_month = l_ym;
    end if;
    return to_char(l_v, 'FM999G999G999G990D00');
  end comm_last;


  -- =================================================================================== AR_MULTI_CUST_TRNS (grouped customers' payments)
  -- header AR_TRNS: grouped-payment types (TOT_TRNS_FLAG 1) of the group, CASH_FLAG required (cheques / transfers need the cheques
  -- system 13), cash box / bank branch give the transaction account and cost centre, category and description from the type,
  -- ACC_POST_DATE = TRNS_DATE, posted documents closed (SET_CLOSE)
  procedure multi_mast_row (p_ins in boolean, p_trns_id in number, p_cash_flag in number, p_box in number, p_bank in number,
                            p_branch in number, p_doc_no in number, p_date in date, p_post in number, p_old_post in number,
                            p_ctgry in out number, p_acc_post_date in out date, p_account in out number, p_cost in out number,
                            p_desc_a in out varchar2) is
    t   ar_trnstype%rowtype;
    l_n number;
    l_a number;
    l_c number;
  begin
    if not p_ins and nvl(p_old_post, 0) = 1 and nvl(p_post, 0) = 1 then
      err('لابد من إلغاء الترحيل اولا', 'Cancel the posting first');
    end if;
    if not p_ins and nvl(p_post, 0) != nvl(p_old_post, 0) then return; end if;     -- posting program
    begin
      select * into t from ar_trnstype
       where id = p_trns_id and effect = 1 and trns_type <> 6 and nvl(tot_trns_flag, 0) = 1
         and (nvl(grp, 0) = 0 or id in (select trns_id from ar_trnstype_password where flag = 1 and password_number = grp));
    exception when no_data_found then
      err('رقم الحركة غير صحيح', 'Invalid transaction type');
    end;
    p_ctgry := nvl(p_ctgry, t.ctgry_code);
    if p_desc_a is null and t.initial_desc is not null then
      p_desc_a := t.initial_desc || case when nvl(t.plus_doc_no_flag, 0) = 1 and p_doc_no is not null then ' ' || p_doc_no end;
    end if;
    p_acc_post_date := nvl(p_acc_post_date, p_date);
    need(p_cash_flag, 'يجب إدخال نوع الحركة', 'You Must Enter Transaction Type');
    if p_cash_flag in (0, 3) then
      select count(1) into l_n from sys_systems where system_number = 13;
      if l_n = 0 then err('نوع الحركة خطا', 'Wrong transaction type'); end if;
    end if;
    if p_cash_flag = 1 then
      if p_box is null then err('يجب ادخال رقم الصندوق', 'Enter the cash box'); end if;
      select max(box_acc_chrt_no), max(cost_code) into l_a, l_c from rp_boxs where box_code = p_box;
      if l_a is null then err('الصندوق لايحتوى على رقم حساب', 'The cash box has no account'); end if;
      p_account := l_a; p_cost := l_c;
    elsif p_cash_flag in (0, 3) and p_branch is not null then
      select max(brnch_acc_chrt_no), max(cost_code) into l_a, l_c from bank_branchs where code = p_branch and bank_code = p_bank;
      if l_a is null then err('فرع البنك لايحتوى على رقم حساب', 'The bank branch has no account'); end if;
      p_account := l_a; p_cost := l_c;
    end if;
    check_account(p_account);
  end multi_mast_row;

  -- customers' lines (AR_MAINTRNS with SERIAL): header fields, customer's area / branch / currency, category / salesman of the
  -- customer, serials, customer open date and opening balance date, discount below the value
  procedure multi_line_row (p_ins in boolean, p_serial in number, p_customer in number, p_total in number, p_disc in number,
                            p_trns_id in out number, p_ctgry in out number, p_trns_date in out date, p_acc_post_date in out date,
                            p_post in out number, p_cash_flag in out number, p_main in out number, p_sub in out number,
                            p_currency in out number, p_rate in out number, p_salesman in out number, p_trns_serial in out number,
                            p_serial_total in out number) is
    h      ar_trns%rowtype;
    c      customer%rowtype;
    l_date date;
  begin
    if p_serial is null or not is_form('AR_MULTI_CUST_TRNS') then return; end if;
    select * into h from ar_trns where serial = p_serial;
    if nvl(h.post_flag, 0) = 1 then err('لابد من إلغاء الترحيل اولا', 'Cancel the posting first'); end if;
    begin
      select * into c from customer where code = p_customer;
    exception when no_data_found then
      err('العميل غير موجود', 'Customer not found');
    end;
    p_trns_id := h.trns_id; p_trns_date := h.trns_date; p_acc_post_date := h.acc_post_date;
    p_post := nvl(h.post_flag, 0); p_cash_flag := h.cash_flag;
    p_main := c.mainarea_id; p_sub := c.subarea_id; p_currency := c.currency_code;
    select max(rate) into p_rate from ac_currency where currency_code = c.currency_code;
    select nvl(min(ctgry_code), h.ctgry_code) into p_ctgry from ar_cust_salesman where customer_code = p_customer;
    if p_salesman is null then
      select min(salesman_code) into p_salesman from ar_cust_salesman where customer_code = p_customer and ctgry_code = p_ctgry;
    end if;
    if c.open_date >= date '1900-01-01' and trunc(p_trns_date) < trunc(c.open_date) then
      err('تاريخ الحركة لا يمكن ان يقل عن تاريخ فتح العميل', 'The date cannot be before the customer''s open date');
    end if;
    select max(m.trns_date) into l_date from ar_maintrns_op m, ar_subtrns_op d
     where m.trns_id = d.trns_id and m.trns_serial = d.trns_serial and d.customer_id = p_customer
       and m.trns_id in (select id from ar_trnstype where trns_type = 6);
    if l_date is not null and trunc(p_trns_date) < trunc(l_date) then
      err('تاريخ الحركة لا يمكن ان يقل عن تاريخ الرصيد الافتتاحي العميل', 'The date cannot be before the customer''s opening balance');
    end if;
    if nvl(p_disc, 0) > nvl(p_total, 0) then
      err('قيمة الخصم لابد أن تكون أقل من القيمة المدخلة للفاتورة', 'The discount must be less than the value');
    end if;
    if p_ins then
      select nvl(max(trns_serial), 0) + 1 into p_trns_serial from ar_maintrns where trns_id = p_trns_id;
      select nvl(max(trns_serial_total), 0) + 1 into p_serial_total from ar_maintrns;
    end if;
  end multi_line_row;

  -- DOC_NO WHEN-VALIDATE-ITEM: "لا يمكن تكرار رقم المستند" (after the statement: reads AR_MAINTRNS)
  procedure multi_doc_check (p_doc_no in number) is
    l_n number;
  begin
    if p_doc_no is null then return; end if;
    select count(1) into l_n from ar_maintrns where doc_no = p_doc_no;
    if l_n > 1 then err('لا يمكن تكرار رقم المستند', 'The document number cannot be repeated'); end if;
  end multi_doc_check;

  -- debit / credit account lines (AR_TRNS_ACCOUNT / AR_SUBACC): active account and cost centres (LOVs), document not posted
  procedure multi_acc_row (p_serial in number, p_account in number, p_cost in number, p_cost2 in number) is
    l_post number;
    l_n    number;
  begin
    select max(post_flag) into l_post from ar_trns where serial = p_serial;
    if nvl(l_post, 0) = 1 then err('لابد من إلغاء الترحيل اولا', 'Cancel the posting first'); end if;
    check_account(p_account);
    if p_cost is not null then
      select count(*) into l_n from ac_cost_centers where cost_code = p_cost and nvl(cost_status, 0) = 1;
      if l_n = 0 then err('مركز التكلفة غير موجود', 'Cost centre not found'); end if;
    end if;
    if p_cost2 is not null then
      select count(*) into l_n from ac_cost_centers2 where cost_code = p_cost2 and nvl(cost_status, 0) = 1;
      if l_n = 0 then err('مركز التكلفة 2 غير موجود', 'Cost centre 2 not found'); end if;
    end if;
  end multi_acc_row;

  procedure multi_del (p_serial in number) is
    l_post number;
  begin
    select max(post_flag) into l_post from ar_trns where serial = p_serial;
    if nvl(l_post, 0) = 1 then err('لابد من إلغاء الترحيل اولا', 'Cancel the posting first'); end if;
  end multi_del;

  function multi_total (p_serial in number, p_what in varchar2) return number is
    l_v number;
  begin
    if p_what = 'CUST' then
      select sum(total_value) into l_v from ar_maintrns where serial = p_serial;
    elsif p_what = 'CR' then
      select sum(account_val) into l_v from ar_subacc where serial = p_serial;
    elsif p_what = 'DB' then
      select sum(account_val) into l_v from ar_trns_account where serial = p_serial;
    end if;
    return nvl(l_v, 0);
  end multi_total;

  -- KEY-COMMIT / POST checks: "القيمة المدفوعة من العملاء لا تساوي إجمالي الحركة" (total = customers + credit accounts) and, per
  -- customer line, "اجمالى حركة العميل يجب ان تكون مساوية لتفاصيل الفواتير" (the line's invoice allocation, AR_SUBTRNS)
  procedure multi_after_save (p_rowid in varchar2) is
    h   ar_trns%rowtype;
    l_v number;
  begin
    if p_rowid is null then return; end if;
    select * into h from ar_trns where rowid = chartorowid(p_rowid);
    if nvl(h.total_value, 0) != multi_total(h.serial, 'CUST') + multi_total(h.serial, 'CR') then
      err('القيمة المدفوعة من العملاء لا تساوي إجمالي الحركة', 'The customers'' payments do not equal the transaction total');
    end if;
    for m in (select * from ar_maintrns where serial = h.serial) loop
      select nvl(sum(total_value), 0) into l_v from ar_subtrns
       where trns_id = m.trns_id and mainarea_id = m.mainarea_id and subarea_id = m.subarea_id and trns_serial = m.trns_serial;
      if l_v != nvl(m.total_value, 0) then
        err('اجمالى حركة العميل يجب ان تكون مساوية لتفاصيل الفواتير' || ' (' || m.customer_id || ')',
            'The customer''s total must equal its invoice details' || ' (' || m.customer_id || ')');
      end if;
    end loop;
  exception when no_data_found then null;
  end multi_after_save;

end app_rules3_ar;
/
show errors package body app_rules3_ar

-- =====================================================================================================
-- Delete hooks (the Stage C rules mechanism has row rules for INSERT / UPDATE only).  APEX sessions only.
-- Compound triggers collect the deleted (or updated) keys and check after the statement, when the table can be read
-- (the legacy "only the last record may be changed / deleted" rules of the range screens).
-- =====================================================================================================
create or replace trigger app_rules3_ar_period_bd
for delete on ar_period compound trigger
  type t_n is table of number index by pls_integer;
  l_serial t_n;
  before each row is
  begin
    if v('APP_ID') is not null then l_serial(l_serial.count + 1) := :old.serial; end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. l_serial.count loop app_rules3_ar.period_del(l_serial(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_period_bd

create or replace trigger app_rules3_ar_tperiod_bud
for update or delete on ar_target_periods compound trigger
  type t_n is table of number index by pls_integer;
  type t_v is table of varchar2(1) index by pls_integer;
  l_year t_n; l_serial t_n; l_op t_v;
  before each row is
  begin
    if v('APP_ID') is not null then
      l_year(l_year.count + 1) := :old.t_year; l_serial(l_serial.count + 1) := :old.serial;
      l_op(l_op.count + 1) := case when updating then 'U' else 'D' end;
    end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. l_serial.count loop app_rules3_ar.tperiod_last(l_year(i), l_serial(i), l_op(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_tperiod_bud

create or replace trigger app_rules3_ar_trange_bud
for update or delete on ar_target_ranges compound trigger
  type t_n is table of number index by pls_integer;
  type t_v is table of varchar2(1) index by pls_integer;
  l_year t_n; l_qurt t_n; l_serial t_n; l_op t_v;
  before each row is
  begin
    if v('APP_ID') is not null then
      l_year(l_year.count + 1) := :old.t_year; l_qurt(l_qurt.count + 1) := :old.t_qurt; l_serial(l_serial.count + 1) := :old.serial;
      l_op(l_op.count + 1) := case when updating then 'U' else 'D' end;
    end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. l_serial.count loop app_rules3_ar.trange_last(l_year(i), l_qurt(i), l_serial(i), l_op(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_trange_bud

create or replace trigger app_rules3_ar_ctgcomm_bd
for delete on st_category_comm compound trigger
  type t_n is table of number index by pls_integer;
  l_c t_n; l_f t_n; l_s t_n;
  before each row is
  begin
    if v('APP_ID') is not null then
      l_c(l_c.count + 1) := :old.category_type_code; l_f(l_f.count + 1) := :old.disc_flag; l_s(l_s.count + 1) := :old.serial;
    end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. l_s.count loop app_rules3_ar.comm_del('COMM', l_c(i), l_f(i), l_s(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_ctgcomm_bd

create or replace trigger app_rules3_ar_ctgmngr_bd
for delete on st_category_comm_mngr compound trigger
  type t_n is table of number index by pls_integer;
  l_c t_n; l_f t_n; l_s t_n;
  before each row is
  begin
    if v('APP_ID') is not null then
      l_c(l_c.count + 1) := :old.category_type_code; l_f(l_f.count + 1) := :old.disc_flag; l_s(l_s.count + 1) := :old.serial;
    end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. l_s.count loop app_rules3_ar.comm_del('MNGR', l_c(i), l_f(i), l_s(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_ctgmngr_bd

create or replace trigger app_rules3_ar_slsprc_bd
for delete on ar_salesman_prc_comm compound trigger
  type t_n is table of number index by pls_integer;
  l_c t_n; l_s t_n; l_k t_n;
  before each row is
  begin
    if v('APP_ID') is not null then
      l_c(l_c.count + 1) := :old.ctgry_code; l_s(l_s.count + 1) := :old.serial; l_k(l_k.count + 1) := :old.code;
    end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. l_s.count loop app_rules3_ar.comm_del('PRC', l_c(i), null, l_s(i), l_k(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_slsprc_bd

create or replace trigger app_rules3_ar_ctgdscnt_bd
before delete on ar_ctgry_dscnt for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.ctgry_type_child_del('AR_DEPT_DISC'); end if;
end;
/
show errors trigger app_rules3_ar_ctgdscnt_bd

create or replace trigger app_rules3_ar_subarea_bd
before delete on ar_subarea for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.subarea_del(:old.main_id, :old.id); end if;
end;
/
show errors trigger app_rules3_ar_subarea_bd

create or replace trigger app_rules3_ar_struct_bd
for delete on ar_chart_structures compound trigger
  type t_n is table of number index by pls_integer;
  l_lvl t_n;
  before each row is
  begin
    if v('APP_ID') is not null then l_lvl(l_lvl.count + 1) := :old.chr_stru_level; end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. l_lvl.count loop app_rules3_ar.struct_del('CUST', l_lvl(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_struct_bd

create or replace trigger app_rules3_ar_attrstruct_bd
for delete on ar_customer_attr_struct compound trigger
  type t_n is table of number index by pls_integer;
  l_lvl t_n;
  before each row is
  begin
    if v('APP_ID') is not null then l_lvl(l_lvl.count + 1) := :old.chr_stru_level; end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. l_lvl.count loop app_rules3_ar.struct_del('ATTR', l_lvl(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_attrstruct_bd

create or replace trigger app_rules3_ar_customer_bd
before delete on customer for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.customer_del(:old.code, :old.customer_status); end if;
end;
/
show errors trigger app_rules3_ar_customer_bd

create or replace trigger app_rules3_ar_custslsm_bd
before delete on ar_cust_salesman for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.cust_salesman_del(:old.customer_code, :old.ctgry_code, :old.salesman_code); end if;
end;
/
show errors trigger app_rules3_ar_custslsm_bd

create or replace trigger app_rules3_ar_custdscnt_bd
before delete on ar_cust_dscnt for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.cust_dscnt_del(:old.customer_code); end if;
end;
/
show errors trigger app_rules3_ar_custdscnt_bd

create or replace trigger app_rules3_ar_custresp_bd
before delete on ar_cust_resp for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.cust_child_del; end if;
end;
/
show errors trigger app_rules3_ar_custresp_bd

create or replace trigger app_rules3_ar_ctgslsm_bd
before delete on ar_ctgry_salesman for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.ctgry_salesman_del(:old.salesman_code, :old.ctgry_code); end if;
end;
/
show errors trigger app_rules3_ar_ctgslsm_bd

create or replace trigger app_rules3_ar_slsmacc_bd
before delete on ar_salesman_account for each row
begin
  if v('APP_ID') is not null then
    app_rules3_ar.salesman_account_del(:old.salesman_id, :old.salesman_account_no, :old.salesman_cost_code, :old.salesman_cost_code2);
  end if;
end;
/
show errors trigger app_rules3_ar_slsmacc_bd

create or replace trigger app_rules3_ar_book_bd
before delete on ar_salesman_books for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.book_del(:old.salesman_code, :old.book_serial); end if;
end;
/
show errors trigger app_rules3_ar_book_bd

create or replace trigger app_rules3_ar_opline_bd
before delete on ar_subtrns_op for each row
begin
  if v('APP_ID') is not null then
    app_rules3_ar.op_line_del(:old.trns_id, :old.trns_serial, :old.r_trns_serial, :old.customer_id, :old.salesman_id,
                              :old.ctgry_code, :old.total_value);
  end if;
end;
/
show errors trigger app_rules3_ar_opline_bd

create or replace trigger app_rules3_ar_trnsfr_bd
for delete on ar_slsman_trnsfr_det compound trigger
  type t_r is table of ar_slsman_trnsfr_det%rowtype index by pls_integer;
  l t_r;
  before each row is
    r ar_slsman_trnsfr_det%rowtype;
  begin
    if v('APP_ID') is not null then
      r.from_slsman := :old.from_slsman; r.trnsfr_date := :old.trnsfr_date; r.customer_code := :old.customer_code;
      r.to_slsman := :old.to_slsman; r.ctgry_code := :old.ctgry_code; r.cr_trns_code := :old.cr_trns_code;
      r.cr_trns_serial := :old.cr_trns_serial; r.db_trns_code := :old.db_trns_code; r.db_trns_serial := :old.db_trns_serial;
      l(l.count + 1) := r;
    end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. l.count loop
      app_rules3_ar.trnsfr_line_del(l(i).from_slsman, l(i).trnsfr_date, l(i).customer_code, l(i).to_slsman, l(i).ctgry_code,
                                    l(i).cr_trns_code, l(i).cr_trns_serial, l(i).db_trns_code, l(i).db_trns_serial);
    end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_trnsfr_bd

create or replace trigger app_rules3_ar_target_aiu
for insert or update on ar_all_target compound trigger
  type t_n is table of number index by pls_integer;
  l t_n;
  after each row is
  begin
    if v('APP_ID') is not null then l(l.count + 1) := :new.all_serial; end if;
  end after each row;
  after statement is
  begin
    for i in 1 .. l.count loop app_rules3_ar.target_dup(l(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_target_aiu

create or replace trigger app_rules3_ar_salesman_bd
before delete on salesman for each row
begin
  if v('APP_ID') is not null and app_rules3_ar.is_form('AR_SLSMAN_SCHEDUAL') then app_rules3_ar.readonly_master; end if;
end;
/
show errors trigger app_rules3_ar_salesman_bd

create or replace trigger app_rules3_ar_dues_bd
before delete on ar_customer_dues for each row
begin
  if v('APP_ID') is not null and nvl(:old.post_flag, 0) = 1 then
    app_rules3_ar.err('الحركة مرحلة للحسابات', 'The transaction is posted to the accounts');
  end if;
end;
/
show errors trigger app_rules3_ar_dues_bd

create or replace trigger app_rules3_ar_duesdet_bd
before delete on ar_customer_dues_det for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.dues_det_check(:old.mainarea_id, :old.mast_serial); end if;
end;
/
show errors trigger app_rules3_ar_duesdet_bd

create or replace trigger app_rules3_ar_pay_bd
before delete on ar_customer_dues_pay for each row
begin
  if v('APP_ID') is not null and nvl(:old.post_flag, 0) = 1 then
    app_rules3_ar.err('الحركة مرحلة للحسابات', 'Record Already Posted');
  end if;
end;
/
show errors trigger app_rules3_ar_pay_bd

create or replace trigger app_rules3_ar_paydet_bd
before delete on ar_customer_dues_pay_det for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.pay_det_check(:old.mast_id, :old.mast_serial); end if;
end;
/
show errors trigger app_rules3_ar_paydet_bd

create or replace trigger app_rules3_ar_paydet_aiu
for insert or update of pay_amount, customer_code, salesman_code on ar_customer_dues_pay_det compound trigger
  type t_n is table of number index by pls_integer;
  l_id t_n; l_ser t_n; l_due t_n;
  after each row is
  begin
    if v('APP_ID') is not null then
      l_id(l_id.count + 1) := :new.mast_id; l_ser(l_id.count) := :new.mast_serial; l_due(l_id.count) := :new.due_serial;
    end if;
  end after each row;
  after statement is
  begin
    for i in 1 .. l_id.count loop app_rules3_ar.pay_det_amount(l_id(i), l_ser(i), l_due(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_paydet_aiu

create or replace trigger app_rules3_ar_colldet_aiu
for insert or update on ar_sls_coll_det compound trigger
  type t_n is table of number index by pls_integer;
  l_slm t_n; l_ser t_n; l_flag t_n; l_det t_n;
  after each row is
  begin
    if v('APP_ID') is not null then
      l_slm(l_slm.count + 1) := :new.salesman_id; l_ser(l_slm.count) := :new.serial;
      l_flag(l_slm.count) := :new.ar_flag; l_det(l_slm.count) := :new.det_serial;
    end if;
  end after each row;
  after statement is
  begin
    for i in 1 .. l_slm.count loop app_rules3_ar.coll_det_check(l_slm(i), l_ser(i), l_flag(i), l_det(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_colldet_aiu

create or replace trigger app_rules3_ar_colldet_bd
before delete on ar_sls_coll_det for each row
begin
  if v('APP_ID') is not null then
    app_rules3_ar.coll_det_del(:old.ar_flag, :old.choose_flag, :old.ar_trns_id, :old.ar_mainarea_id, :old.ar_subarea_id, :old.ar_trns_serial);
  end if;
end;
/
show errors trigger app_rules3_ar_colldet_bd

create or replace trigger app_rules3_ar_colltrf_aiu
for insert or update on ar_sls_coll_trnsfer compound trigger
  type t_n is table of number index by pls_integer;
  l_seq t_n;
  after each row is
  begin
    if v('APP_ID') is not null then l_seq(l_seq.count + 1) := :new.mob_trns_seq; end if;
  end after each row;
  after statement is
  begin
    for i in 1 .. l_seq.count loop app_rules3_ar.coll_trf_check(l_seq(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_colltrf_aiu

create or replace trigger app_rules3_ar_mob_bd
before delete on mob_deposite_trns for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.mob_del(:old.trns_status); end if;
end;
/
show errors trigger app_rules3_ar_mob_bd

create or replace trigger app_rules3_ar_daily_aiu
for insert or update on ar_maintrns_daily compound trigger
  type t_n is table of number index by pls_integer;
  l_id t_n; l_main t_n; l_sub t_n; l_ser t_n;
  after each row is
  begin
    if v('APP_ID') is not null and :new.ref_doc is not null then
      l_id(l_id.count + 1) := :new.trns_id; l_main(l_id.count) := :new.mainarea_id;
      l_sub(l_id.count) := :new.subarea_id; l_ser(l_id.count) := :new.trns_serial;
    end if;
  end after each row;
  after statement is
  begin
    for i in 1 .. l_id.count loop app_rules3_ar.daily_ref_check(l_id(i), l_main(i), l_sub(i), l_ser(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_daily_aiu

create or replace trigger app_rules3_ar_daily_bd
before delete on ar_maintrns_daily for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.daily_del(:old.trns_status, :old.post_flag); end if;
end;
/
show errors trigger app_rules3_ar_daily_bd

create or replace trigger app_rules3_ar_multi_aiu
for insert or update of doc_no on ar_maintrns compound trigger
  type t_n is table of number index by pls_integer;
  l_doc t_n;
  after each row is
  begin
    if :new.serial is not null and :new.doc_no is not null and v('APP_ID') is not null
       and app_rules3_ar.is_form('AR_MULTI_CUST_TRNS') then
      l_doc(l_doc.count + 1) := :new.doc_no;
    end if;
  end after each row;
  after statement is
  begin
    for i in 1 .. l_doc.count loop app_rules3_ar.multi_doc_check(l_doc(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_ar_multi_aiu

create or replace trigger app_rules3_ar_multi_bd
before delete on ar_maintrns for each row
begin
  if :old.serial is not null and v('APP_ID') is not null then app_rules3_ar.multi_del(:old.serial); end if;
end;
/
show errors trigger app_rules3_ar_multi_bd

create or replace trigger app_rules3_ar_trns_bd
before delete on ar_trns for each row
begin
  if v('APP_ID') is not null and nvl(:old.post_flag, 0) = 1 then
    app_rules3_ar.err('لابد من إلغاء الترحيل اولا', 'Cancel the posting first');
  end if;
end;
/
show errors trigger app_rules3_ar_trns_bd

create or replace trigger app_rules3_ar_trnsacc_bd
before delete on ar_trns_account for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.multi_del(:old.serial); end if;
end;
/
show errors trigger app_rules3_ar_trnsacc_bd

create or replace trigger app_rules3_ar_subacc_bd
before delete on ar_subacc for each row
begin
  if v('APP_ID') is not null then app_rules3_ar.multi_del(:old.serial); end if;
end;
/
show errors trigger app_rules3_ar_subacc_bd
