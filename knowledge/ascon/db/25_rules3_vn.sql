-- =====================================================================================================
-- APP_RULES3_VN : business rules of the payables (system 5) setup, master-data and process screens (Stage C wave 3).
-- Evidence and rule lists: app\legacy\processes\<FORM>.md.  Wired by app\legacy\overrides\<FORM>.json.
--
-- How the rules are wired (STAGE_C_WAVE3.md):
--   * key_expr / row_rules of the overrides call the functions and procedures below from the generated APPX_<TABLE>
--     triggers (APEX sessions only).  Tables written by other screens too (SUPPLIER, VN_TRNSTYPE, VN_MAINTRNS, VN_SUBTRNS)
--     are guarded with is_form(<form of the current APEX page>) in the override;
--   * page validations / after-save processes / info / actions call the functions of this package;
--   * delete hooks (the rules mechanism has none) are the triggers at the end of this file, APEX sessions only.
--     A delete coming from the "delete document" cascade of a document page (REQUEST = DELETE) is how the legacy
--     "cannot delete a master record while details exist" rules are reproduced.
--   * VN_INVOICE_ADJESTMENT is a process page calling invoice_adjust.
-- Row triggers never query their own table on UPDATE / DELETE (ORA-04091): such checks run in compound triggers after the
-- statement or in the after-save process of the document page (single-row INSERT ... VALUES may read the table).
-- No COMMIT (APEX commits).  Errors: raise_application_error(-20100..-20199), legacy Arabic text, English when G_LANG = en.
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_rules3_vn authid definer as

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
  function chg (p_new in number, p_old in number) return number;   -- 1 when the value changed
  function chg (p_new in varchar2, p_old in varchar2) return number;
  function chg (p_new in date, p_old in date) return number;
  function last_message return varchar2;                           -- text of the last action (success message)
  function busy return number;                                     -- 1 while this package updates rows itself (row rules skip)

  -- ------------------------------------------------------------------ shared legacy checks
  -- CHECK_DATE (library TRANSLATE, system 5): not after today; not before MIN(VN_BASIC.MIN_DATE)
  function check_date_msg (p_date in date, p_future in number default 0) return varchar2;
  -- telephone / fax WHEN-VALIDATE-ITEM of SUPPLIER (p_kind 'T' telephone, 'F' fax)
  function phone_msg (p_value in varchar2, p_kind in varchar2 default 'T') return varchar2;
  function account_exists (p_account in number) return number;     -- AC_MASTER, ACCOUNT_STATUS = 1
  procedure need (p_value in varchar2, p_a in varchar2, p_e in varchar2);   -- raise when p_value is null
  function need_num (p_a in varchar2, p_e in varchar2) return number;      -- key_expr of a key the user must enter
  procedure positive_code (p_code in number, p_a in varchar2, p_e in varchar2);
  function supp_allowed (p_code in number) return number;          -- supplier inside the group's range (VN_SUPPLIER_PASSWORD)

  -- ------------------------------------------------------------------ VN_BASIC
  procedure basic_row (p_min in date, p_max in date, p_srv_year in number, p_srv_entry in number, p_srv_acc in number,
                       p_pay_type in number);
  -- ------------------------------------------------------------------ LC_SETTEL (LC_SETTEL_TYPE)
  function next_settel_code return number;
  procedure settel_row (p_code in number, p_account in number, p_disc in number, p_cost1 in number, p_cost2 in number);
  procedure settel_del (p_code in number);
  -- ------------------------------------------------------------------ VNAREA
  procedure mainarea_row (p_id in number, p_account in number, p_disc in number);
  procedure subarea_row (p_id in number, p_account in number, p_disc in number);
  procedure subarea_uniq (p_main in number, p_id in number);         -- after the statement (compound trigger)
  procedure subarea_del;
  -- ------------------------------------------------------------------ VN_SUPP_STRUCT (VN_CHART_STRUCTURE, CHR_TYPE 1)
  function next_struct_level return number;
  procedure struct_row (p_ins in boolean, p_type in out number, p_start in out number, p_end in number, p_length in out number,
                        p_old_start in number, p_old_end in number, p_old_length in number);
  procedure struct_del (p_type in number, p_level in number);
  -- ------------------------------------------------------------------ VNTRNSTYPE
  procedure trnstype_row (p_id in number, p_effect in number, p_trns_type in number, p_joint in number, p_entry_type in number,
                          p_acc_type in number, p_supp_acc_type in number, p_disc_acc_type in number,
                          p_account in number, p_supp_account in number, p_disc_account in number, p_currency_account in number,
                          p_cost1 in number, p_cost2 in number);
  procedure trnstype_locked (p_id in number);                       -- type with posted transactions: definition locked
  -- ------------------------------------------------------------------ SUPPLIER (suppliers file)
  function supp_level (p_code in number) return number;             -- DETECT_SUPP_LEVEL
  function supp_parent (p_code in number, p_level in number) return number;   -- GET_SUPP_PARENT
  procedure supplier_row (p_ins in boolean, p_code in out number, p_level in out number, p_status in out number,
                          p_tel1 in varchar2, p_tel2 in varchar2, p_tel3 in varchar2, p_fax in varchar2,
                          p_debit_limit in number, p_due_days in number, p_stop in number, p_stop_reason in out varchar2,
                          p_account in number, p_disc in number, p_cost1 in number, p_cost2 in number,
                          p_currency in number, p_old_currency in number, p_act in number, p_old_act in number);
  procedure supplier_del (p_status in number);
  procedure supplier_after (p_request in varchar2, p_rowid in varchar2, p_code in varchar2, p_level in varchar2);
  procedure supp_child_del;                                          -- VN_SUPP_RESP / VN_SUPP_KIND: document delete
  procedure pay_acc_row (p_settel in number, p_account in number, p_disc in number, p_cost1 in number, p_cost2 in number);
  procedure stat_row (p_ins in boolean, p_supplier in number, p_year in out number, p_date in date, p_sttm_bal in out number,
                      p_old_date in date);
  function supp_info (p_code in varchar2, p_what in varchar2) return varchar2;
  function next_child_code (p_code in varchar2) return varchar2;    -- button "إدخال سجل جديد" (child of the current supplier)

  -- ------------------------------------------------------------------ VNTRN_OP (supplier opening balances)
  function op_default_type return number;
  procedure op_mast_row (p_ins in boolean, p_trns_id in number, p_serial in number, p_date in date, p_doc_no in number,
                         p_desc_a in out varchar2, p_desc_e in out varchar2, p_old_trns_id in number, p_old_serial in number);
  procedure op_line_row (p_ins in boolean, p_trns_id in number, p_trns_serial in number, p_bill_seq in number,
                         p_supplier in number, p_bill_id1 in number, p_bill_id2 in out number, p_value in number,
                         p_currency in out number, p_rate in out number, p_sales_man in number, p_pay_type in out number,
                         p_r_serial in out number,
                         p_old_supplier in number, p_old_bill_id1 in number, p_old_bill_id2 in number, p_old_value in number,
                         p_old_currency in number, p_old_rate in number, p_old_pay_type in number, p_old_r_serial in number);
  procedure op_line_upd_check (p_trns_id in number, p_trns_serial in number, p_bill_seq in number);   -- after the UPDATE statement
  procedure op_line_del (p_trns_id in number, p_trns_serial in number, p_r_serial in number, p_supplier in number,
                         p_value in number, p_bill_id1 in number, p_bill_id2 in number);
  procedure op_after_save (p_rowid in varchar2);

  -- ------------------------------------------------------------------ VN_INVOICE_ADJESTMENT (process page)
  function inv_paid (p_supplier in number, p_trns_id in number, p_trns_serial in number, p_bill_seq in number,
                     p_bill_id1 in varchar2, p_bill_id2 in varchar2) return number;
  function supp_balance (p_supplier in number) return number;      -- POST-QUERY VN_BAL
  function supp_open_invoices (p_supplier in number) return number; -- POST-QUERY VN_INV_TOTAL
  function supp_open_payments (p_supplier in number) return number;
  procedure invoice_adjust (p_action in number, p_supplier in number default null,
                            p_company_code in number default null, p_user_code in number default null,
                            p_password_number in number default null);

end app_rules3_vn;
/
show errors package app_rules3_vn

create or replace package body app_rules3_vn as

  g_page  number := -1;
  g_form  varchar2(128);
  g_msg   varchar2(4000);
  g_grp   number;                      -- process pages: group passed as argument
  g_busy  number := 0;

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
    return coalesce(g_grp, to_number(v('G_PASSWORD_NUMBER')));
  exception when others then return g_grp;
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

  function last_message return varchar2 is
  begin
    return g_msg;
  end last_message;

  function busy return number is
  begin
    return g_busy;
  end busy;

  -- =================================================================================== shared legacy checks
  function check_date_msg (p_date in date, p_future in number default 0) return varchar2 is
    l_min date;
    l_max date := add_months(sysdate, 24);   -- system 5 reads no MAX_DATE: the library default
  begin
    if p_date is null then return null; end if;
    if nvl(p_future, 0) = 0 and trunc(p_date) > trunc(sysdate) then
      return msg('تاريخ الحركة أكبر من تاريخ اليوم', 'Transaction Date is greater than today''s date');
    end if;
    begin
      select min(min_date) into l_min from vn_basic;
    exception when others then l_min := null;
    end;
    l_min := nvl(l_min, to_date('01-01-' || to_char(to_number(to_char(sysdate, 'YYYY')) - 1), 'DD-MM-YYYY'));
    if trunc(p_date) < trunc(l_min) then
      return msg('الحد الأدنى لتاريخ الحركة هو ' || to_char(l_min, 'DD/MM/YYYY'),
                 'The least value accepted for Transaction Date is ' || to_char(l_min, 'DD/MM/YYYY'));
    end if;
    if nvl(p_future, 0) = 1 and trunc(p_date) > trunc(l_max) then
      return msg('الحد الأقصى لتاريخ الحركة هو ' || to_char(l_max, 'DD/MM/YYYY'),
                 'The Most value accepted for Transaction Date is ' || to_char(l_max, 'DD/MM/YYYY'));
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
      -- "SELECT TO_NUMBER(:b1) FROM DUAL" failed: "must be without characters"
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

  procedure positive_code (p_code in number, p_a in varchar2, p_e in varchar2) is
  begin
    if p_code is not null and p_code <= 0 then err(p_a, p_e); end if;
  end positive_code;

  procedure check_account (p_account in number) is
  begin
    if account_exists(p_account) = 0 then
      err('رقم الحساب غير موجود بدليل الحسابات: ' || p_account, 'Account number not found in the chart of accounts: ' || p_account);
    end if;
  end check_account;

  procedure check_cost (p_kind in number, p_cost in number) is
    l_n number;
  begin
    if p_cost is null then return; end if;
    if p_kind = 1 then
      select count(*) into l_n from ac_cost_centers where cost_code = p_cost and nvl(cost_status, 0) = 1;
    else
      select count(*) into l_n from ac_cost_centers2 where cost_code = p_cost and nvl(cost_status, 0) = 1;
    end if;
    if l_n = 0 then
      err('مركز تكلفة ' || p_kind || ' غير موجود: ' || p_cost, 'Cost centre ' || p_kind || ' not found: ' || p_cost);
    end if;
  end check_cost;

  procedure master_has_details is
  begin
    err('لا يمكن إلغاء سجل رئيسي في و جود سجلات تابعة له', 'Cannot delete master record when matching detail records exist.');
  end master_has_details;

  function supp_allowed (p_code in number) return number is
    l_from number;
    l_to   number;
  begin
    if nvl(grp, 0) = 0 or p_code is null then return 1; end if;
    select min(from_supplier_code), max(to_supplier_code) into l_from, l_to from vn_supplier_password where password_number = grp;
    return case when p_code between l_from and l_to then 1 else 0 end;
  end supp_allowed;

  -- =================================================================================== VN_BASIC
  -- MIN_DATE / MAX_DATE WHEN-VALIDATE-ITEM: "أصغر تاريخ لا يمكن ان يكون اكبر من اقصى تاريخ"; LOVs: active accounts,
  -- AC_TRN_CODES (year + type), LC_SETTEL_TYPE
  procedure basic_row (p_min in date, p_max in date, p_srv_year in number, p_srv_entry in number, p_srv_acc in number,
                       p_pay_type in number) is
    l_n number;
  begin
    if p_min > p_max then
      err('أصغر تاريخ لا يمكن ان يكون اكبر من اقصى تاريخ', 'The minimum date can''t be over than the maximum date');
    end if;
    if p_srv_entry is not null or p_srv_year is not null then
      select count(*) into l_n from ac_trn_codes where entry_year = p_srv_year and entry_type = p_srv_entry;
      if l_n = 0 then
        err('سنة و قيد الترحيل غير موجودين في أنواع قيود الحسابات', 'The posting year and voucher type do not exist in the voucher types');
      end if;
    end if;
    check_account(p_srv_acc);
    if p_pay_type is not null then
      select count(*) into l_n from lc_settel_type where settel_type_code = p_pay_type;
      if l_n = 0 then err('رقم الدفعة غير موجود', 'Payment type not found'); end if;
    end if;
  end basic_row;

  -- =================================================================================== LC_SETTEL
  -- WHEN-CREATE-RECORD: SELECT NVL(MAX(SETTEL_TYPE_CODE),0)+1 FROM LC_SETTEL_TYPE (the generator does not number *_TYPE_CODE keys)
  function next_settel_code return number is
    l_n number;
  begin
    select nvl(max(settel_type_code), 0) + 1 into l_n from lc_settel_type;
    return l_n;
  end next_settel_code;

  procedure settel_row (p_code in number, p_account in number, p_disc in number, p_cost1 in number, p_cost2 in number) is
  begin
    positive_code(p_code, 'رقم طريقة السداد يجب ان يكون اكبر من الصفر', 'the payment condition number should be over than zero');
    check_account(p_account); check_account(p_disc);
    check_cost(1, p_cost1); check_cost(2, p_cost2);
  end settel_row;

  -- KEY-DELREC: the payment type cannot be deleted while letters of credit or supplier transactions use it
  procedure settel_del (p_code in number) is
    l_n number;
  begin
    select count(1) into l_n from lc_credit where settel_type_code = p_code;
    if l_n > 0 then
      err('لا يمكن حذف السجل التالى لوجود ارتباط مع ملف الاعتماد الرئيسي', 'The current record have a relation with main credit letter file');
    end if;
    select count(1) into l_n from lc_credit_open where settel_type_code = p_code;
    if l_n > 0 then
      err('لا يمكن حذف السجل التالى لوجود ارتباط مع ملف فتح الاعتماد', 'The current record have a relation with open credit letter file');
    end if;
    select count(1) into l_n from dual
     where exists (select 1 from vn_maintrns where pay_type_code = p_code)
        or exists (select 1 from vn_subtrns where pay_type_code = p_code);
    if l_n > 0 then
      err('لايمكن مسح السجل لوجود ارتباطات بملف الموردين', 'The current record have a relation with Supplier');
    end if;
  end settel_del;

  -- =================================================================================== VNAREA
  procedure mainarea_row (p_id in number, p_account in number, p_disc in number) is
  begin
    positive_code(p_id, 'رقم المنطقة يجب ان يكون اكبر من الصفر', 'the area number should be over than zero');
    if p_account = p_disc then
      err('رقم حساب الخصم يجب ان يختلف عن رقم حساب المنطقة الارئيسية', 'The discount account can''t be equal the main area acccount');
    end if;
    check_account(p_account); check_account(p_disc);
  end mainarea_row;

  procedure subarea_row (p_id in number, p_account in number, p_disc in number) is
  begin
    positive_code(p_id, 'رقم المنطقة الفرعية يجب ان يكون اكبر من الصفر', 'the sub area number should be over than zero');
    if p_account = p_disc then
      err('رقم حساب الخصم يجب ان يختلف عن رقم حساب المنطقة الفرعية', 'The discount account can''t be equal the main area acccount');
    end if;
    check_account(p_account); check_account(p_disc);
  end subarea_row;

  -- PRE-INSERT / PRE-UPDATE of VN_SUBAREA: account and discount account not repeated inside the main area
  procedure subarea_uniq (p_main in number, p_id in number) is
    l_acc  number;
    l_disc number;
    l_n    number;
  begin
    begin
      select account_no, disc_account into l_acc, l_disc from vn_subarea where main_id = p_main and id = p_id;
    exception when no_data_found then return;
    end;
    if l_acc is not null then
      select count(1) into l_n from vn_subarea where main_id = p_main and account_no = l_acc and id != p_id;
      if l_n > 0 then err('رقم حساب المنطقة الفرعية لا يمكن تكراره', 'The sub-area account number can''t be repeated'); end if;
    end if;
    if l_disc is not null then
      select count(1) into l_n from vn_subarea where main_id = p_main and disc_account = l_disc and id != p_id;
      if l_n > 0 then err('رقم حساب الخصم للمنطقة الفرعية لا يمكن تكراره', 'The sub-area discount account number can''t be repeated'); end if;
    end if;
  end subarea_uniq;

  -- KEY-DELREC of VN_MAINAREA: "لايمكنك حذف هذه المنطقة لأن لها مناطق فرعية" (document delete cascade of the area page)
  procedure subarea_del is
  begin
    if doc_delete('VNAREA') then
      err('لايمكنك حذف هذه المنطقة لأن لها مناطق فرعية', 'You Can not Delete This Area Becouse It Has Sub Areas');
    end if;
  end subarea_del;

  -- =================================================================================== VN_SUPP_STRUCT
  function struct_locked return boolean is
    l_n number;
  begin
    select count(*) into l_n from supplier where rownum = 1;       -- SELECT COUNT(*) FROM SUPPLIER (form start / KEY-DELREC)
    return l_n > 0;
  end struct_locked;

  function next_struct_level return number is
    l_n number;
  begin
    select nvl(max(chr_stru_level), 0) + 1 into l_n from vn_chart_structure where chr_type = 1;
    return l_n;
  end next_struct_level;

  procedure struct_row (p_ins in boolean, p_type in out number, p_start in out number, p_end in number, p_length in out number,
                        p_old_start in number, p_old_end in number, p_old_length in number) is
  begin
    p_type := nvl(p_type, 1);
    if p_type != 1 then err('هيكل أرقام الموردين هو النوع 1 فقط', 'The supplier code structure is type 1 only'); end if;
    if struct_locked and (p_ins or chg(p_start, p_old_start) + chg(p_end, p_old_end) + chg(p_length, p_old_length) > 0) then
      err('لا يمكن تعديل هيكل أرقام الموردين أثناء وجود موردين؛ يمكن تعديل أسماء المستويات فقط',
          'The supplier code structure cannot be changed while suppliers exist; only the level names can be changed');
    end if;
    if p_ins then
      select nvl(max(chr_stru_end), 0) + 1 into p_start from vn_chart_structure where chr_type = 1;
    end if;
    if p_end is null or p_end < p_start or p_end > 12 then
      err('برجاء التأكد من إدخال حقل النهاية و كونه أكبر من حقل البداية و كذلك كونه أقل من 12',
          'Please ensure that you entered value of End Field, and it is greater than start field and it is less than 12');
    end if;
    p_length := p_end - p_start + 1;
  end struct_row;

  -- KEY-DELREC: no delete while suppliers exist; the levels are deleted from the bottom up
  procedure struct_del (p_type in number, p_level in number) is
    l_n number;
  begin
    if nvl(p_type, 1) != 1 then return; end if;
    if struct_locked then
      err('لا يمكن حذف المستويات حيث أنه توجد ممجموعات أصناف معرفة بناء على هذه المستويات',
          'Cannot delete this levels as there exist item groups defined based on this chart');
    end if;
    select count(*) into l_n from vn_chart_structure where chr_type = 1 and chr_stru_level > p_level;
    if l_n > 0 then err('يجب حذف السجلات من أسفل إلي أعلي', 'Records should be deleted from down to top'); end if;
  end struct_del;

  -- =================================================================================== VNTRNSTYPE
  procedure trnstype_row (p_id in number, p_effect in number, p_trns_type in number, p_joint in number, p_entry_type in number,
                          p_acc_type in number, p_supp_acc_type in number, p_disc_acc_type in number,
                          p_account in number, p_supp_account in number, p_disc_account in number, p_currency_account in number,
                          p_cost1 in number, p_cost2 in number) is
    l_n number;
  begin
    positive_code(p_id, 'رقم الحركة يجب ان يكون اكبر من الصفر', 'the transaction number should be over than zero');
    -- purchases (0) credit the supplier (effect 1); payments (1) and returns (3) debit him (effect 0)
    if (p_trns_type = 0 and nvl(p_effect, -1) != 1) or (p_trns_type in (1, 3) and nvl(p_effect, -1) != 0) then
      err('نوع الحركة غير متوافق مع تأثير الحركة على المورد', 'Transaction type not matching the transaction effect');
    end if;
    if nvl(p_joint, 0) = 1 then
      if p_acc_type is null or p_supp_acc_type is null or p_disc_acc_type is null then
        err('يجب إدخال التوجية المحاسبى للحركة و المورد و الخصم',
            'You have to define the Transaction , Supplier And Discount accounts for the current type');
      end if;
      if p_entry_type is null then err('يجب إدخال نوع الحساب', 'The entry type must be entered'); end if;
      if p_acc_type = 4 and p_account is null then err('يجب إدخال حساب نوع الحركة', 'The transaction account must be entered'); end if;
      if p_supp_acc_type = 4 and p_supp_account is null then err('يجب إدخال حساب العميل', 'The customer account must be entered'); end if;
      if p_disc_acc_type = 4 and p_disc_account is null then err('يجب إدخال حساب الخصم', 'The discount account must be entered'); end if;
    end if;
    if p_entry_type is not null then
      select count(*) into l_n from ac_trn_codes where entry_type = p_entry_type;
      if l_n = 0 then
        err('يجب إدخال رقم نوع حركة فى الحسابات صحيح و لك صلاحيات إستخدامه', 'Enter a valid voucher type you are allowed to use');
      end if;
    end if;
    if p_account in (p_supp_account, p_disc_account) then
      err('لا يمكن تكرار رقم حساب نوع الحركة مع الحسابات الاخرى', 'The transaction account can''t be repeated with other accounts');
    end if;
    if p_supp_account = p_disc_account then
      err('لا يمكن تكرار رقم حساب المورد مع الحسابات الاخرى', 'The supplier account can''t be repeated with other accounts');
    end if;
    check_account(p_account); check_account(p_supp_account); check_account(p_disc_account); check_account(p_currency_account);
    check_cost(1, p_cost1); check_cost(2, p_cost2);
  end trnstype_row;

  -- WHEN-NEW-RECORD-INSTANCE: "SELECT COUNT(1) FROM VN_MAINTRNS WHERE TRNS_ID = :ID AND POST_FLAG = 1" makes the effect, type,
  -- descriptions, flags, directions, accounts and cost centres of a type with posted transactions non-updatable
  procedure trnstype_locked (p_id in number) is
    l_n number;
  begin
    select count(1) into l_n from vn_maintrns where trns_id = p_id and post_flag = 1;
    if l_n > 0 then
      err('لا يمكن تعديل بيانات نوع الحركة لوجود حركات مرحلة عليه', 'The transaction type has posted transactions and cannot be changed');
    end if;
  end trnstype_locked;

  -- =================================================================================== SUPPLIER
  -- DETECT_SUPP_LEVEL: the level is the last structure level whose part of the 12-digit code is not zero; a non-zero part
  -- after a zero part is refused (DISPLAY_ERROR_MESSAGE in the legacy form, MESSAGES table empty)
  function supp_level (p_code in number) return number is
    l_code  varchar2(40) := to_char(p_code);
    l_level number := 0;
    l_seg   number;
    l_rest  number;
    l_n     number;
  begin
    select count(*) into l_n from vn_chart_structure where chr_type = 1;
    if l_n = 0 then err('يجب ادخال هيكل أرقام الموردين', 'Enter the supplier code structure first'); end if;
    for s in (select chr_stru_level lvl, chr_stru_start st, length len from vn_chart_structure where chr_type = 1
               order by chr_stru_level) loop
      l_seg := to_number(nvl(substr(l_code, s.st, s.len), '0'));
      if l_seg = 0 then
        l_rest := to_number(nvl(substr(l_code, s.st + s.len), '0'));
        if l_rest > 0 then
          err('رقم المورد غير متوافق مع هيكل أرقام الموردين', 'The supplier code does not match the supplier code structure');
        end if;
        exit;
      end if;
      l_level := s.lvl;
    end loop;
    return l_level;
  end supp_level;

  function supp_parent (p_code in number, p_level in number) return number is
    l_end number;
  begin
    if nvl(p_level, 0) <= 1 then return null; end if;
    select chr_stru_end into l_end from vn_chart_structure where chr_type = 1 and chr_stru_level = p_level - 1;
    return to_number(rpad(substr(to_char(p_code), 1, l_end), 12, '0'));
  end supp_parent;

  procedure supplier_row (p_ins in boolean, p_code in out number, p_level in out number, p_status in out number,
                          p_tel1 in varchar2, p_tel2 in varchar2, p_tel3 in varchar2, p_fax in varchar2,
                          p_debit_limit in number, p_due_days in number, p_stop in number, p_stop_reason in out varchar2,
                          p_account in number, p_disc in number, p_cost1 in number, p_cost2 in number,
                          p_currency in number, p_old_currency in number, p_act in number, p_old_act in number) is
    l_n      number;
    l_parent number;
    l_msg    varchar2(4000);
  begin
    if p_ins then
      -- CODE WHEN-VALIDATE-ITEM: > 0, 12 digits, level of the structure, parent must exist, not repeated, a new supplier is a leaf
      if p_code <= 0 then err('رقم المورد يجب ان يكون اكبر من الصفر', 'the supplier number should be over than zero'); end if;
      p_code := to_number(rpad(to_char(p_code), 12, '0'));
      p_level := supp_level(p_code);
      if p_level > 1 then
        l_parent := supp_parent(p_code, p_level);
        select count(*) into l_n from supplier where code = l_parent;
        if l_n = 0 then err(' لا يمكن تكوين  أبن بلا  أب ', 'You cant add children SUPPLIER Without A Parent SUPPLIER'); end if;
      end if;
      select count(*) into l_n from supplier where code = p_code;
      if l_n > 0 then err('رقم المورد تم إدخاله من قبل .....', 'Supplier No. has Been Entered Before ...!'); end if;
      p_status := 1;
      if supp_allowed(p_code) = 0 then err('خطأ صلاحية', 'You don''t have permission'); end if;
    elsif chg(p_currency, p_old_currency) + chg(p_act, p_old_act) > 0 then
      -- CURRENCY('CLOSE'): currency and activity are closed once the supplier has transactions, opening balances or stock documents
      select count(*) into l_n from dual
       where exists (select 1 from vn_maintrns where supplier_id = p_code)
          or exists (select 1 from vn_subtrns_op where supplier_id = p_code)
          or exists (select 1 from st_trns_mast where supplier_code = p_code);
      if l_n > 0 then
        err('لا يمكن تغيير عملة المورد أو نوع النشاط لوجود حركات على المورد',
            'The currency and the activity cannot change while the supplier has transactions');
      end if;
    end if;
    l_msg := coalesce(phone_msg(p_tel1), phone_msg(p_tel2), phone_msg(p_tel3), phone_msg(p_fax, 'F'));
    if l_msg is not null then err(l_msg, l_msg); end if;
    if nvl(p_debit_limit, 0) < 0 then err('حد الائتمان  يجب ان يكون اكبر من الصفر', 'the debit limit should be over than zero'); end if;
    if nvl(p_due_days, 0) < 0 then err('ايام الاستحقاق يجب ان يكون اكبر من الصفر', 'the due days should be over than zero'); end if;
    if nvl(p_stop, 0) = 0 then p_stop_reason := null; end if;       -- STOPFLAG: the reason belongs to a stopped supplier
    check_account(p_account); check_account(p_disc);
    check_cost(1, p_cost1); check_cost(2, p_cost2);
  end supplier_row;

  -- KEY-DELREC: a parent supplier (SUPPLIER_STATUS 0) cannot be deleted
  procedure supplier_del (p_status in number) is
  begin
    if p_status = 0 then
      err('لا يمكن حذف مورد رئيسي له موردين فرعيين', 'A parent supplier with sub-suppliers cannot be deleted');
    end if;
  end supplier_del;

  -- POST-INSERT: the parent is no longer a leaf (SUPPLIER_STATUS 0); POST-DELETE: it becomes a leaf again without children
  procedure supplier_after (p_request in varchar2, p_rowid in varchar2, p_code in varchar2, p_level in varchar2) is
    l_code   number := num(p_code);
    l_level  number := num(p_level);
    l_parent number;
    l_n      number;
  begin
    g_busy := 1;
    if p_request = 'DELETE' then
      if l_level > 1 then
        l_parent := supp_parent(l_code, l_level);
        select count(*) into l_n from supplier
         where code != l_code and code != l_parent and supplier_level = l_level and supp_parent(code, supplier_level) = l_parent;
        if l_n = 0 then update supplier set supplier_status = 1 where code = l_parent; end if;
      end if;
    elsif p_request = 'CREATE' then
      select code, supplier_level into l_code, l_level from supplier where rowid = chartorowid(p_rowid);
      if l_level > 1 then
        update supplier set supplier_status = 0 where code = supp_parent(l_code, l_level) and nvl(supplier_status, 1) != 0;
      end if;
    end if;
    g_busy := 0;
  exception when others then
    g_busy := 0;
    raise;
  end supplier_after;

  -- ON-CHECK-DELETE-MASTER of SUPPLIER (VN_SUPP_RESP, VN_SUPP_KIND); VN_PAY_METHODE_ACC / SUPPLIER_SHIPPING_TYPE are deleted with it
  procedure supp_child_del is
  begin
    if doc_delete('SUPPLIER') then master_has_details; end if;
  end supp_child_del;

  procedure pay_acc_row (p_settel in number, p_account in number, p_disc in number, p_cost1 in number, p_cost2 in number) is
    l_n number;
  begin
    select count(*) into l_n from lc_settel_type where settel_type_code = p_settel;
    if l_n = 0 then err('نوع الدفع غير موجود', 'Payment type not found'); end if;
    check_account(p_account); check_account(p_disc);
    check_cost(1, p_cost1); check_cost(2, p_cost2);
  end pay_acc_row;

  -- SUPPLIER_STAT (المطابقات): the statement balance at the date is GET_SUPPLIER_BAL(supplier, date); year of the reconciliation
  procedure stat_row (p_ins in boolean, p_supplier in number, p_year in out number, p_date in date, p_sttm_bal in out number,
                      p_old_date in date) is
  begin
    need(p_date, 'يجب إدخال تاريخ المطابقة', 'Enter the reconciliation date');
    p_year := nvl(p_year, to_number(to_char(p_date, 'YYYY')));
    if p_ins or chg(p_date, p_old_date) = 1 or p_sttm_bal is null then
      p_sttm_bal := get_supplier_bal(p_supplier, p_date);
    end if;
  end stat_row;

  function supp_info (p_code in varchar2, p_what in varchar2) return varchar2 is
    l_code number := num(p_code);
    l_bal  number;
    l_n    number;
    function f (n in number) return varchar2 is
    begin
      return to_char(n, 'FM999G999G999G990D00');
    end f;
  begin
    if p_what = 'LAST' then
      select max(code) into l_n from supplier;
      return to_char(l_n);
    end if;
    if l_code is null then return null; end if;
    if p_what = 'BAL' then
      l_bal := get_supplier_bal(l_code);
      return f(abs(nvl(l_bal, 0))) || ' ' || case when nvl(l_bal, 0) >= 0 then msg('دائــن', 'CREDIT') else msg('مديــن', 'DEBIT') end;
    elsif p_what = 'BEG' then
      select max(beg_bal) into l_bal from supplier where code = l_code;
      return f(abs(nvl(l_bal, 0))) || ' ' || case when nvl(l_bal, 0) <= 0 then msg('دائــن', 'CREDIT') else msg('مديــن', 'DEBIT') end;
    elsif p_what = 'LEVEL' then
      select max(supplier_level), max(supplier_status) into l_n, l_bal from supplier where code = l_code;
      return l_n || ' - ' || case l_bal when 0 then msg('مورد رئيسي', 'Parent supplier') when 1 then msg('مورد فرعي', 'Leaf supplier') end;
    end if;
    return null;
  end supp_info;

  -- button "إدخال سجل جديد" of the tree screen: next child code of the current supplier (GET_NEXT_SUPP)
  function next_child_code (p_code in varchar2) return varchar2 is
    l_code   number := num(p_code);
    l_level  number;
    l_max    number;
    l_endp   number;
    l_endc   number;
    l_next   number;
  begin
    if l_code is null then err(' لا يمكن تكوين  أبن بلا  أب ', 'You cant add children SUPPLIER Without A Parent SUPPLIER'); end if;
    l_level := supp_level(l_code);
    select max(chr_stru_level) into l_max from vn_chart_structure where chr_type = 1;
    if l_level >= l_max then
      err('المورد في المستوى الأخير من الهيكل ولا يمكن إضافة موردين فرعيين له', 'The supplier is on the last level of the structure');
    end if;
    select chr_stru_end into l_endp from vn_chart_structure where chr_type = 1 and chr_stru_level = l_level;
    select chr_stru_end into l_endc from vn_chart_structure where chr_type = 1 and chr_stru_level = l_level + 1;
    select to_number(rpad(to_char(to_number(substr(to_char(max(code)), 1, l_endc)) + 1), 12, '0')) into l_next
      from supplier where substr(to_char(code), 1, l_endp) = substr(to_char(l_code), 1, l_endp);
    g_msg := msg('رقم المورد الفرعي التالي: ', 'Next sub-supplier code: ') || l_next;
    return null;
  end next_child_code;

  -- =================================================================================== VNTRN_OP (supplier opening balances)
  function op_default_type return number is
    l_id number;
  begin
    select min(id) into l_id from vn_trnstype where trns_type = 5 and effect = 1
       and (nvl(grp, 0) = 0 or id in (select trns_id from vn_trnstype_password where flag = 1 and password_number = grp));
    return l_id;
  end op_default_type;

  procedure op_mast_row (p_ins in boolean, p_trns_id in number, p_serial in number, p_date in date, p_doc_no in number,
                         p_desc_a in out varchar2, p_desc_e in out varchar2, p_old_trns_id in number, p_old_serial in number) is
    l_t   vn_trnstype%rowtype;
    l_n   number;
    l_msg varchar2(4000);
  begin
    -- TRNSTYPE LOV: TRNS_TYPE 5 of the effect of the menu entry, VN_TRNSTYPE_PASSWORD
    begin
      select * into l_t from vn_trnstype where id = p_trns_id and trns_type = 5;
    exception when no_data_found then
      err('رقم الحركة ليس من حركات الأرصدة الافتتاحية', 'Not an opening balance transaction type');
    end;
    if nvl(grp, 0) != 0 then
      select count(*) into l_n from vn_trnstype_password where flag = 1 and password_number = grp and trns_id = p_trns_id;
      if l_n = 0 then err('خطأ صلاحية', 'Permission error'); end if;
    end if;
    if not p_ins and (p_trns_id != p_old_trns_id or p_serial != p_old_serial) then
      select count(*) into l_n from vn_subtrns_op where trns_id = p_old_trns_id and trns_serial = p_old_serial;
      if l_n > 0 then master_has_details; end if;
    end if;
    l_msg := check_date_msg(p_date);                                 -- TRNS_DATE WHEN-VALIDATE-ITEM: CHECK_DATE
    if l_msg is not null then err(l_msg, l_msg); end if;
    if p_doc_no <= 0 then
      err('رقم المستند يجب ان يكون اكبر من الصفر', 'the document number should be over than zero');
    end if;
    -- TRNS_ID / DOC_NO WHEN-VALIDATE-ITEM: description of the type (DESC_FLAG 1 description - doc no, 2 description, 3 none)
    if p_desc_a is null and nvl(l_t.desc_flag, 0) in (1, 2) then
      p_desc_a := l_t.description_a; p_desc_e := nvl(p_desc_e, l_t.description_e);
    end if;
    if nvl(l_t.desc_flag, 0) = 1 and p_doc_no is not null and p_desc_a = l_t.description_a then
      p_desc_a := l_t.description_a || ' - ' || to_char(p_doc_no);
      if p_desc_e is null or p_desc_e = l_t.description_e then p_desc_e := l_t.description_e || ' - ' || to_char(p_doc_no); end if;
    end if;
  end op_mast_row;

  -- SUPPLIER.CRN_BAL_TOTAL / BEG_BAL maintained by the legacy form:
  --   insert: CRN_BAL_TOTAL + DECODE(effect, 1, -v, 0, v), BEG_BAL = DECODE(effect, 1, -v, 0, v); delete: CRN_BAL_TOTAL - ..., BEG_BAL = 0
  procedure op_balances (p_effect in number, p_value in number, p_supplier in number, p_sign in number) is
    l_v number := case p_effect when 1 then -p_value when 0 then p_value end;
  begin
    if p_sign = 1 then
      update supplier set crn_bal_total = nvl(crn_bal_total, 0) + l_v, beg_bal = l_v where code = p_supplier;
    else
      update supplier set crn_bal_total = nvl(crn_bal_total, 0) - l_v, beg_bal = 0 where code = p_supplier;
    end if;
  end op_balances;

  -- the generated supplier transaction may be changed / removed only while nothing was allocated on it
  -- (credit balance = invoice: no payment line on it; debit balance = payment: no allocation line of its own)
  procedure op_check_alloc (p_effect in number, p_trns_id in number, p_r_serial in number, p_supplier in number,
                            p_bill_id1 in number, p_bill_id2 in number) is
    l_n number;
  begin
    if p_r_serial is null then return; end if;
    if p_effect = 1 then
      select count(*) into l_n from vn_subtrns s
       where s.trns_id in (select id from vn_trnstype where effect = 0)
         and ((s.inv_trns_id = p_trns_id and s.inv_trns_serial = p_r_serial)
              or (s.inv_trns_id is null and s.bill_id1 = to_char(p_bill_id1) and s.bill_id2 = to_char(p_bill_id2)
                  and get_supplier(s.trns_id, s.trns_serial) = p_supplier));
    else
      select count(*) into l_n from vn_subtrns where trns_id = p_trns_id and trns_serial = p_r_serial;
    end if;
    if l_n > 0 then
      err('لا يمكن تعديل أو حذف الرصيد الافتتاحي للمورد لأنه تم السداد أو التسوية عليه',
          'The supplier opening balance was already paid or allocated and cannot be changed');
    end if;
  end op_check_alloc;

  procedure op_line_row (p_ins in boolean, p_trns_id in number, p_trns_serial in number, p_bill_seq in number,
                         p_supplier in number, p_bill_id1 in number, p_bill_id2 in out number, p_value in number,
                         p_currency in out number, p_rate in out number, p_sales_man in number, p_pay_type in out number,
                         p_r_serial in out number,
                         p_old_supplier in number, p_old_bill_id1 in number, p_old_bill_id2 in number, p_old_value in number,
                         p_old_currency in number, p_old_rate in number, p_old_pay_type in number, p_old_r_serial in number) is
    l_h      vn_maintrns_op%rowtype;
    l_effect number;
    l_s      supplier%rowtype;
    l_rate   number;
    l_n      number;
    l_regen  boolean;
  begin
    select * into l_h from vn_maintrns_op where trns_id = p_trns_id and trns_serial = p_trns_serial;
    select effect into l_effect from vn_trnstype where id = p_trns_id;
    need(p_supplier, 'خطأ فى المورد', 'Error In Supplier');
    begin
      select * into l_s from supplier where code = p_supplier;
    exception when no_data_found then err('خطأ فى المورد', 'Error In Supplier');
    end;
    if supp_allowed(p_supplier) = 0 then err('خطأ صلاحية', 'You don''t have permission'); end if;
    -- SUPPLIER_ID WHEN-VALIDATE-ITEM: currency and rate of the supplier (AC_CURRENCY.RATE)
    begin
      select c.rate into l_rate from ac_currency c where c.currency_code = l_s.currency_code;
    exception when no_data_found then err('خطأ فى عملة المورد', 'Error In Supplier Currency');
    end;
    p_currency := l_s.currency_code;
    if p_currency = 1 then
      if p_rate is not null and p_rate != 1 then err('معامل تحويل الريال لابد أن يكون 1', 'The rating of the SR has to be 1'); end if;
      p_rate := 1;
    elsif p_rate is null or (p_rate = 1 and nvl(l_rate, 1) != 1) then
      p_rate := l_rate;
    end if;
    if nvl(p_rate, 0) <= 0 then err('يجب ان يكون معامل التحويل أكبر من 0', 'The Rate must Bigger Than 0'); end if;
    if nvl(p_value, 0) <= 0 then err('القيمة يجب أن تكون أكبر من الصفر', 'Value Should Be Greater Than Zero'); end if;
    p_bill_id2 := nvl(p_bill_id2, p_bill_id1);                       -- BILL_ID1 WHEN-VALIDATE-ITEM
    if l_effect = 1 and p_bill_id1 is null then
      err('يجب ادخال رقم فاتوره حتى يمكن السداد عليها', 'you have to enter invoice number');
    end if;
    if p_sales_man is not null then
      select count(*) into l_n from vn_resp where code = p_sales_man;
      if l_n = 0 then err('رقم مسئول المورد غير موجود', 'Supplier responsible not found'); end if;
    end if;
    if p_pay_type is null then
      select min(pay_type_code) into p_pay_type from vn_basic;
    end if;
    if p_pay_type is not null then
      select count(*) into l_n from lc_settel_type where settel_type_code = p_pay_type;
      if l_n = 0 then err('رقم الدفعة غير موجود', 'Payment type not found'); end if;
    end if;
    if p_ins then
      -- PRE-INSERT: one opening balance per supplier; no transaction or payment note on or before the opening balance date
      select count(1) into l_n from vn_subtrns_op where supplier_id = p_supplier;
      if l_n > 0 then err('المورد الحالي له رصيد افتتاحي', 'The current supplier have open balance transaction'); end if;
      select count(1) into l_n from vn_maintrns where supplier_id = p_supplier and trns_date <= l_h.trns_date;
      if l_n > 0 then
        err('المورد الحالي له حركات فى الملف الرئيسى قبل تاريخ الرصيد الافتتاحي',
            'The current supplier have transaction entered before the opening balance date');
      end if;
      select count(1) into l_n from vn_paytrns where supplier_id = p_supplier and trns_date <= l_h.trns_date;
      if l_n > 0 then
        err('المورد الحالي له حركات فى مذكرة السداد قبل تاريخ الرصيد الافتتاحي',
            'The current supplier have transaction entered in payment note before the opening balance date');
      end if;
      l_regen := true;
    else
      -- PRE-UPDATE (same date / earlier transactions: after the statement, op_line_upd_check); the generated transaction follows
      -- a changed line as long as nothing was allocated on it
      l_regen := chg(p_supplier, p_old_supplier) + chg(p_value, p_old_value) + chg(p_bill_id1, p_old_bill_id1)
                 + chg(p_bill_id2, p_old_bill_id2) + chg(p_currency, p_old_currency) + chg(p_rate, p_old_rate)
                 + chg(p_pay_type, p_old_pay_type) > 0 or p_old_r_serial is null;
      if l_regen then
        op_check_alloc(l_effect, p_trns_id, p_old_r_serial, p_old_supplier, p_old_bill_id1, p_old_bill_id2);
        if p_old_r_serial is not null then
          delete from vn_subtrns where trns_id = p_trns_id and trns_serial = p_old_r_serial;
          delete from vn_maintrns where trns_id = p_trns_id and trns_serial = p_old_r_serial;
          op_balances(l_effect, p_old_value, p_old_supplier, -1);
        end if;
      end if;
    end if;
    if l_regen then
      -- INSERT_DBCR_TRN: the supplier transaction (VN_MAINTRNS, posted flag 1, pay method 5) and, for a credit balance,
      -- its invoice line (VN_SUBTRNS BILL_SEQ 1) that payments are allocated to
      select nvl(max(trns_serial), 0) + 1 into p_r_serial from vn_maintrns where trns_id = p_trns_id;
      insert into vn_maintrns (trns_id, trns_serial, trns_date, doc_no, total_value, disc_value, net_value, description_a,
                               description_e, supplier_id, link_flag, post_flag, residual_value, pay_method, currency_code,
                               currency_rate, pay_type_code)
      values (p_trns_id, p_r_serial, l_h.trns_date, l_h.doc_no, p_value, 0, p_value, l_h.description_a,
              l_h.description_e, p_supplier, 0, 1, p_value, 5, p_currency, p_rate, p_pay_type);
      if l_effect = 1 then
        insert into vn_subtrns (trns_id, trns_serial, bill_seq, bill_id1, bill_id2, total_value, disc_value, net_value,
                                residual_value, pay_type_code)
        values (p_trns_id, p_r_serial, 1, to_char(p_bill_id1), to_char(p_bill_id2), p_value, 0, p_value, p_value, p_pay_type);
      end if;
      op_balances(l_effect, p_value, p_supplier, 1);
    end if;
  end op_line_row;

  -- PRE-UPDATE of a line: the supplier has no other opening balance line on the same date, and no transaction / payment note
  -- on or before the date (other than the opening balance transactions themselves)
  procedure op_line_upd_check (p_trns_id in number, p_trns_serial in number, p_bill_seq in number) is
    l_d vn_subtrns_op%rowtype;
    l_h vn_maintrns_op%rowtype;
    l_n number;
  begin
    begin
      select * into l_d from vn_subtrns_op where trns_id = p_trns_id and trns_serial = p_trns_serial and bill_seq = p_bill_seq;
      select * into l_h from vn_maintrns_op where trns_id = p_trns_id and trns_serial = p_trns_serial;
    exception when no_data_found then return;
    end;
    select count(1) into l_n from vn_maintrns_op m, vn_subtrns_op d
     where m.trns_id = d.trns_id and m.trns_serial = d.trns_serial and m.trns_date = l_h.trns_date and d.supplier_id = l_d.supplier_id
       and not (d.trns_id = l_d.trns_id and d.trns_serial = l_d.trns_serial and d.bill_seq = l_d.bill_seq);
    if l_n > 0 then
      err('المورد الحالي له رصيد افتتاحي فى نفس تاريخ', 'The current supplier have open balance transaction in the same opening balance date');
    end if;
    select count(1) into l_n from vn_maintrns
     where supplier_id = l_d.supplier_id and trns_date <= l_h.trns_date
       and trns_id not in (select id from vn_trnstype where trns_type = 5);
    if l_n > 0 then
      err('المورد الحالي له حركات فى الملف الرئيسى قبل تاريخ الرصيد الافتتاحي',
          'The current supplier have transaction entered before the opening balance date');
    end if;
    select count(1) into l_n from vn_paytrns where supplier_id = l_d.supplier_id and trns_date <= l_h.trns_date;
    if l_n > 0 then
      err('المورد الحالي له حركات فى مذكرة السداد قبل تاريخ الرصيد الافتتاحي',
          'The current supplier have transaction entered in payment note before the opening balance date');
    end if;
  end op_line_upd_check;

  -- PRE-DELETE of a line: ON-CHECK-DELETE-MASTER of the header, DELETE_DBCR_TRN, supplier balance back
  procedure op_line_del (p_trns_id in number, p_trns_serial in number, p_r_serial in number, p_supplier in number,
                         p_value in number, p_bill_id1 in number, p_bill_id2 in number) is
    l_effect number;
  begin
    if doc_delete('VNTRN_OP') then master_has_details; end if;
    select effect into l_effect from vn_trnstype where id = p_trns_id;
    op_check_alloc(l_effect, p_trns_id, p_r_serial, p_supplier, p_bill_id1, p_bill_id2);
    if p_r_serial is not null then
      delete from vn_subtrns where trns_id = p_trns_id and trns_serial = p_r_serial;
      delete from vn_maintrns where trns_id = p_trns_id and trns_serial = p_r_serial;
    end if;
    op_balances(l_effect, p_value, p_supplier, -1);
  end op_line_del;

  -- "يجب ادخال تفاصيل سداد": a saved opening balance needs its lines
  procedure op_after_save (p_rowid in varchar2) is
    l_n number;
  begin
    select count(*) into l_n from vn_maintrns_op h, vn_subtrns_op d
     where h.rowid = chartorowid(p_rowid) and d.trns_id = h.trns_id and d.trns_serial = h.trns_serial;
    if l_n = 0 then err('يجب ادخال تفاصيل سداد', 'You have to enter pay details'); end if;
  end op_after_save;

  -- =================================================================================== VN_INVOICE_ADJESTMENT
  -- paid part of an invoice line: payment lines (effect 0 documents) linked to it (INV_TRNS_ID / SERIAL / BILL_SEQ), or - the
  -- legacy rule - unlinked payment lines of the same supplier with the same BILL_ID1 / BILL_ID2
  function inv_paid (p_supplier in number, p_trns_id in number, p_trns_serial in number, p_bill_seq in number,
                     p_bill_id1 in varchar2, p_bill_id2 in varchar2) return number is
    l_v number;
  begin
    select nvl(sum(s.total_value), 0) into l_v
      from vn_subtrns s join vn_maintrns m on m.trns_id = s.trns_id and m.trns_serial = s.trns_serial
     where m.trns_id in (select id from vn_trnstype where effect = 0)
       and ((s.inv_trns_id = p_trns_id and s.inv_trns_serial = p_trns_serial and s.inv_bill_seq = p_bill_seq)
            or (s.inv_trns_id is null and m.supplier_id = p_supplier and s.bill_id1 = p_bill_id1 and s.bill_id2 = p_bill_id2));
    return l_v;
  end inv_paid;

  -- POST-QUERY: credit transactions - debit transactions (cheques not yet paid excluded)
  function supp_balance (p_supplier in number) return number is
    l_db number;
    l_cr number;
  begin
    select nvl(sum(nvl(mn.total_value, 0)), 0) into l_db from vn_maintrns mn, vn_trnstype typ
     where mn.trns_id = typ.id and typ.effect = 0 and mn.supplier_id = p_supplier
       and (nvl(mn.pay_method, 0) not in (2, 3, 4) or (nvl(mn.pay_method, 0) in (2, 3, 4) and nvl(mn.pay_flag, 0) = 1));
    select nvl(sum(nvl(mn.total_value, 0)), 0) into l_cr from vn_maintrns mn, vn_trnstype typ
     where mn.trns_id = typ.id and typ.effect = 1 and mn.supplier_id = p_supplier;
    return l_cr - l_db;
  end supp_balance;

  function supp_open_invoices (p_supplier in number) return number is
    l_v number;
  begin
    select nvl(sum(greatest(nvl(s.total_value, 0) - inv_paid(p_supplier, s.trns_id, s.trns_serial, s.bill_seq, s.bill_id1, s.bill_id2), 0)), 0)
      into l_v
      from vn_subtrns s join vn_maintrns m on m.trns_id = s.trns_id and m.trns_serial = s.trns_serial
     where m.trns_id in (select id from vn_trnstype where effect = 1) and m.supplier_id = p_supplier;
    return l_v;
  end supp_open_invoices;

  function supp_open_payments (p_supplier in number) return number is
    l_v number;
  begin
    select nvl(sum(greatest(nvl(m.total_value, 0)
                            - (select nvl(sum(nvl(s.total_value, 0)), 0) from vn_subtrns s
                                where s.trns_id = m.trns_id and s.trns_serial = m.trns_serial), 0)), 0)
      into l_v
      from vn_maintrns m where m.trns_id in (select id from vn_trnstype where effect = 0) and m.supplier_id = p_supplier;
    return l_v;
  end supp_open_payments;

  -- MAKE_ADJUST for one supplier: every debit document with an unallocated value (TOTAL - its lines) pays the supplier's
  -- open invoice lines of the same currency and payment type, oldest first (TRNS_DATE, BILL_ID1, BILL_ID2)
  procedure adjust_one (p_supplier in number, p_count in out number) is
    l_net  number;
    l_open number;
    l_amt  number;
    l_seq  number;
  begin
    -- legacy: only suppliers whose balance differs from their open invoices
    if round(supp_balance(p_supplier), 2) = round(supp_open_invoices(p_supplier), 2) then return; end if;
    for c_s in (select mn.trns_id, mn.trns_serial, mn.currency_code, nvl(mn.total_value, 0) mn_total, mn.pay_type_code,
                       (select nvl(sum(nvl(sb.total_value, 0)), 0) from vn_subtrns sb
                         where sb.trns_id = mn.trns_id and sb.trns_serial = mn.trns_serial) sb_total
                  from vn_maintrns mn, vn_trnstype typ
                 where mn.trns_id = typ.id and typ.effect = 0 and mn.supplier_id = p_supplier
                 order by mn.trns_date, mn.trns_id, mn.trns_serial
                   for update of mn.residual_value) loop
      if c_s.mn_total > c_s.sb_total then
        l_net := c_s.mn_total - c_s.sb_total;
        for c_b in (select s.trns_id, s.trns_serial, s.bill_seq, s.bill_id1, s.bill_id2, nvl(s.total_value, 0) total_value,
                           m.trns_date
                      from vn_subtrns s, vn_maintrns m
                     where m.trns_id in (select id from vn_trnstype where effect = 1)
                       and m.trns_id = s.trns_id and m.trns_serial = s.trns_serial
                       and m.supplier_id = p_supplier and m.currency_code = c_s.currency_code
                       and s.pay_type_code = c_s.pay_type_code
                     order by m.trns_date, s.bill_id1, s.bill_id2) loop
          l_open := c_b.total_value - inv_paid(p_supplier, c_b.trns_id, c_b.trns_serial, c_b.bill_seq, c_b.bill_id1, c_b.bill_id2);
          if l_open > 0 then
            select nvl(max(nvl(bill_seq, 0)), 0) + 1 into l_seq from vn_subtrns
             where trns_id = c_s.trns_id and trns_serial = c_s.trns_serial;
            l_amt := least(l_net, l_open);
            insert into vn_subtrns (trns_id, trns_serial, bill_seq, bill_id1, bill_id2, total_value, disc_value, net_value,
                                    residual_value, inv_trns_id, inv_trns_serial, inv_bill_seq, inv_date)
            values (c_s.trns_id, c_s.trns_serial, l_seq, c_b.bill_id1, c_b.bill_id2, l_amt, 0, l_amt, 0,
                    c_b.trns_id, c_b.trns_serial, c_b.bill_seq, c_b.trns_date);
            update vn_subtrns set residual_value = l_open - l_amt
             where trns_id = c_b.trns_id and trns_serial = c_b.trns_serial and bill_seq = c_b.bill_seq;
            l_net := l_net - l_amt;
            p_count := p_count + 1;
          end if;
          exit when l_net = 0;
        end loop;
        update vn_maintrns set residual_value = l_net where trns_id = c_s.trns_id and trns_serial = c_s.trns_serial;
      end if;
    end loop;
  end adjust_one;

  -- KEY-DELREC of the supplier row: all allocation lines of the supplier's debit documents are deleted
  -- ("تم الانتهاء من حذف الفواتير"); invoice totals / residuals and payment residuals are recalculated
  procedure remove_one (p_supplier in number, p_count in out number) is
    l_paid number;
  begin
    for s in (select s.rowid rid from vn_subtrns s
               where s.trns_id in (select t.id from vn_trnstype t where t.effect = 0)
                 and get_supplier(s.trns_id, s.trns_serial) = p_supplier) loop
      delete from vn_subtrns where rowid = s.rid;
      p_count := p_count + 1;
    end loop;
    -- UPDATE VN_MAINTRNS SET TOTAL_VALUE = sum of the lines for credit documents whose total differs (the legacy statement had no
    -- supplier filter; limited here to the supplier of the action)
    for m in (select m.trns_id, m.trns_serial,
                     (select nvl(sum(total_value), 0) from vn_subtrns s where s.trns_id = m.trns_id and s.trns_serial = m.trns_serial) tot
                from vn_maintrns m
               where m.trns_id in (select id from vn_trnstype where effect = 1) and m.supplier_id = p_supplier) loop
      update vn_maintrns set total_value = m.tot
       where trns_id = m.trns_id and trns_serial = m.trns_serial and decode(total_value, m.tot, 0, 1) = 1;
    end loop;
    for i in (select s.trns_id, s.trns_serial, s.bill_seq, s.bill_id1, s.bill_id2, s.total_value, s.residual_value
                from vn_subtrns s join vn_maintrns m on m.trns_id = s.trns_id and m.trns_serial = s.trns_serial
               where m.trns_id in (select id from vn_trnstype where effect = 1) and m.supplier_id = p_supplier) loop
      l_paid := inv_paid(p_supplier, i.trns_id, i.trns_serial, i.bill_seq, i.bill_id1, i.bill_id2);
      if chg(i.residual_value, nvl(i.total_value, 0) - l_paid) = 1 then
        update vn_subtrns set residual_value = nvl(total_value, 0) - l_paid
         where trns_id = i.trns_id and trns_serial = i.trns_serial and bill_seq = i.bill_seq;
      end if;
    end loop;
    update vn_maintrns m set residual_value = nvl(total_value, 0)
     where m.trns_id in (select id from vn_trnstype where effect = 0) and m.supplier_id = p_supplier
       and decode(residual_value, nvl(total_value, 0), 0, 1) = 1;
  end remove_one;

  procedure invoice_adjust (p_action in number, p_supplier in number default null,
                            p_company_code in number default null, p_user_code in number default null,
                            p_password_number in number default null) is
    l_cnt number := 0;
    l_n   number;
  begin
    g_grp := p_password_number;
    if p_supplier is not null then
      -- block SUPPLIER: NVL(SUPPLIER_STATUS,0) = 1 (leaf suppliers) inside the group's range
      select count(*) into l_n from supplier where code = p_supplier and nvl(supplier_status, 0) = 1;
      if l_n = 0 then g_grp := null; err('المورد غير موجود أو ليس موردا فرعيا', 'Supplier not found or not a leaf supplier'); end if;
      if supp_allowed(p_supplier) = 0 then g_grp := null; err('خطأ صلاحية', 'You don''t have permission'); end if;
    end if;
    if p_action = 1 then
      -- MAKE_ADJUST over the selected suppliers ("اختيار الكل" = all suppliers of the list when none is chosen)
      for s in (select code from supplier
                 where nvl(supplier_status, 0) = 1 and (p_supplier is null or code = p_supplier)
                   and supp_allowed(code) = 1
                 order by code) loop
        adjust_one(s.code, l_cnt);
      end loop;
      g_msg := msg('تمت التسوية بنجاح - عدد سطور السداد: ', 'Adjust Finished Successfully - payment lines: ') || l_cnt;
    elsif p_action = 2 then
      if p_supplier is null then g_grp := null; err('اختر المورد', 'Choose the supplier'); end if;
      remove_one(p_supplier, l_cnt);
      g_msg := msg('تم الانتهاء من حذف الفواتير - عدد السطور المحذوفة: ', 'The allocations were deleted - lines: ') || l_cnt;
    else
      g_grp := null;
      err('اختر العملية', 'Choose the action');
    end if;
    g_grp := null;
  exception when others then
    g_grp := null;
    raise;
  end invoice_adjust;

end app_rules3_vn;
/
show errors package body app_rules3_vn

-- =====================================================================================================
-- Delete hooks and after-statement checks (the Stage C rules mechanism has row rules for INSERT / UPDATE only).
-- APEX sessions only.
-- =====================================================================================================
create or replace trigger app_rules3_vn_settel_bd
before delete on lc_settel_type for each row
begin
  if v('APP_ID') is not null then app_rules3_vn.settel_del(:old.settel_type_code); end if;
end;
/
show errors trigger app_rules3_vn_settel_bd

create or replace trigger app_rules3_vn_subarea_biud
for insert or update or delete on vn_subarea compound trigger
  type t_n is table of number index by pls_integer;
  l_main t_n; l_id t_n;
  before each row is
  begin
    if v('APP_ID') is not null then
      if deleting then
        app_rules3_vn.subarea_del;
      else
        l_main(l_main.count + 1) := :new.main_id; l_id(l_id.count + 1) := :new.id;
      end if;
    end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. l_id.count loop app_rules3_vn.subarea_uniq(l_main(i), l_id(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_vn_subarea_biud

create or replace trigger app_rules3_vn_struct_bd
for delete on vn_chart_structure compound trigger
  type t_n is table of number index by pls_integer;
  l_type t_n; l_lvl t_n;
  before each row is
  begin
    if v('APP_ID') is not null then l_type(l_type.count + 1) := :old.chr_type; l_lvl(l_lvl.count + 1) := :old.chr_stru_level; end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. l_lvl.count loop app_rules3_vn.struct_del(l_type(i), l_lvl(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_vn_struct_bd

create or replace trigger app_rules3_vn_supplier_bd
before delete on supplier for each row
begin
  if v('APP_ID') is not null and app_rules3_vn.is_form('SUPPLIER') then app_rules3_vn.supplier_del(:old.supplier_status); end if;
end;
/
show errors trigger app_rules3_vn_supplier_bd

create or replace trigger app_rules3_vn_suppresp_bd
before delete on vn_supp_resp for each row
begin
  if v('APP_ID') is not null then app_rules3_vn.supp_child_del; end if;
end;
/
show errors trigger app_rules3_vn_suppresp_bd

create or replace trigger app_rules3_vn_suppkind_bd
before delete on vn_supp_kind for each row
begin
  if v('APP_ID') is not null then app_rules3_vn.supp_child_del; end if;
end;
/
show errors trigger app_rules3_vn_suppkind_bd

create or replace trigger app_rules3_vn_opline_bd
before delete on vn_subtrns_op for each row
begin
  if v('APP_ID') is not null and app_rules3_vn.is_form('VNTRN_OP') then
    app_rules3_vn.op_line_del(:old.trns_id, :old.trns_serial, :old.r_trns_serial, :old.supplier_id, :old.total_value,
                              :old.bill_id1, :old.bill_id2);
  end if;
end;
/
show errors trigger app_rules3_vn_opline_bd

create or replace trigger app_rules3_vn_opline_au
for update on vn_subtrns_op compound trigger
  type t_n is table of number index by pls_integer;
  l_t t_n; l_s t_n; l_b t_n;
  before each row is
  begin
    if v('APP_ID') is not null and app_rules3_vn.is_form('VNTRN_OP') then
      l_t(l_t.count + 1) := :new.trns_id; l_s(l_s.count + 1) := :new.trns_serial; l_b(l_b.count + 1) := :new.bill_seq;
    end if;
  end before each row;
  after statement is
  begin
    for i in 1 .. l_t.count loop app_rules3_vn.op_line_upd_check(l_t(i), l_s(i), l_b(i)); end loop;
  end after statement;
end;
/
show errors trigger app_rules3_vn_opline_au
