-- =====================================================================================================
-- APP_RULES3_GL : legacy business rules of the General Ledger setup / query screens (Stage C wave 3).
--   AC_MASTER_STRUCT  هيكل دليل الحسابات          AC_CHART_STRUCTURES      key_expr + row rule + delete hooks
--   AC_COST_STRUCT1/2 هيكل مراكز التكلفة 1 / 2     AC_COST_STRCTURES        key_expr + row rule + delete hooks
--   ACMAST            دليل الحسابات                 AC_MASTER (+ grants)     validation, row rule, after save, action, info, delete hook
--   ACCSTCD/ACCSTCD2  أرقام مراكز التكلفة 1 / 2     AC_COST_CENTERS(2)       grid action (create), row rule, delete hooks
--   ACTRCOD           أرقام أنواع اليوميات          AC_TRN_CODES             grid action (new financial year), delete hook
--   ACCRNCY           أرقام العملات                 AC_CURRENCY (+ rates)    validation, row rule, after save, delete hook
--   ACBASIC           مؤشرات النظام                 AC_BASIC                 validation
--   ACESTMT_PRIODS    فترات الموازنة التقديرية      AC_ESTIMATE_PERIODS      key_expr + row rule + statement hook (overlap)
--   ACESTMT_PERIODS_TRNS إعداد الموازنة التقديرية   AC_ESTIMATE_CODES/MAST/DET  validation, row rules, after save, actions
--   ACMNUCD           إعداد القوائم المالية         AC_MENUS / AC_FINAL_ACCOUNT after save + statement hook
--   AC_DUPENTRY_DEF   قائمة القيود الدورية          AC_PERIODICAL_VOC        key_expr + row rule
--   AC_QUERYBEFORE/AFTER إستعلام عن رصيد حساب       (process pages)          query_balance + account_balance
--   ACYRTR            القيود المرحلة                AC_YEARLY_TRN            info (totals, source document, users)
--   AC_DISTP          توزيع مراكز التكلفة           AC_DISTP / _FROM / _DET  key_expr, row rules, after save, actions (equal / post / unpost), delete hooks
--   ACBENFTAX         اضافة مورد الخدمات           AC_BENF_TAX              row rule + statement hook (unique VAT number)
--   SUB_LG_COMPARE    مراقبة الانظمة الفرعية        SUB_LG_COMPARE(_DET)     info (GL / supplier sub-ledger balances)
-- Evidence and decisions: app\legacy\processes\<FORM>.md.  Wiring: app\legacy\overrides\<FORM>.json.
--
-- How the rules are wired (STAGE_C_WAVE3.md):
--   * key_expr / row_rules of the overrides call this package from the generated APPX_<TABLE> triggers (APEX only);
--   * validations / after_save / info / actions of document and form pages call the functions below;
--   * the triggers at the end of this file are the hooks the rules mechanism does not have (delete checks,
--     after-statement checks that must read the table being changed).  They act only inside APEX sessions
--     (v('APP_ID') is not null), like the generated triggers, so the legacy Forms application is not affected.
-- No COMMIT.  Errors: raise_application_error(-20100..-20199) with the legacy Arabic text where one exists
-- (English when G_LANG = 'en').  The legacy MESSAGES table is empty on this schema, so the numbered legacy
-- messages (DISPLAY_ERROR_MESSAGE(n)) showed no text; those rules get a short new Arabic text (marked "new" in the .md).
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_rules3_gl authid definer as

  -- ------------------------------------------------------------------ context
  procedure set_context (p_company_code in number, p_user_code in number, p_password_number in number);
  procedure clear_context;
  -- regression tests only: treat the code tables as empty in the structure rules (the build copy has accounts)
  procedure set_test (p_structure_free in boolean);
  function ctx_company return number;                    -- G_COMPANY_CODE (or set_context)
  function ctx_user return number;                       -- G_USER_CODE
  function ctx_group return number;                      -- G_PASSWORD_NUMBER
  function cur_form return varchar2;                     -- legacy form of the current APEX page (APP_PAGE_MAP)
  function last_message return varchar2;                 -- text of the last action (shown as the success message)

  -- ------------------------------------------------------------------ code trees (chart of accounts, cost centres 1 / 2)
  -- p_tree: 'AC' = accounts (AC_CHART_STRUCTURES, 12 digits), 'C1' / 'C2' = cost centres (AC_COST_STRCTURES, 9 digits)
  function num (p in varchar2) return number;                                         -- safe to_number (null when invalid)
  function tree_no (p_tree in varchar2) return number;                                -- 'C1' -> 1, 'C2' -> 2
  function code_len (p_tree in varchar2) return number;
  function tree_levels (p_tree in varchar2) return number;
  function level_end (p_tree in varchar2, p_level in number) return number;
  function code_level (p_tree in varchar2, p_code in number) return number;          -- null when the code does not fit the structure
  function code_parent (p_tree in varchar2, p_code in number, p_level in number) return number;   -- null at level 1
  function has_transactions (p_tree in varchar2, p_code in number) return number;     -- 1 / 0

  -- ------------------------------------------------------------------ AC_MASTER_STRUCT / AC_COST_STRUCT1 / AC_COST_STRUCT2
  function next_chart_level return number;                                           -- key_expr CHR_STRU_LEVEL
  procedure chart_struct_row (p_inserting in boolean, p_old_level in number, p_old_start in number, p_old_end in number,
                              p_old_len in number, p_level in number, p_desc in varchar2,
                              p_start in out number, p_end in number, p_len in out number);
  function cost_struct_no (p_no in number) return number;                             -- key_expr COST_CENTER_NUMBER
  function next_cost_level (p_no in number) return number;                            -- key_expr COST_STR_LEVEL
  procedure cost_struct_row (p_inserting in boolean, p_no in number, p_old_level in number, p_old_start in number,
                             p_old_end in number, p_old_len in number, p_level in number, p_desc in varchar2,
                             p_start in out number, p_end in number, p_len in out number);
  procedure struct_before_delete (p_tree in varchar2);                               -- delete hooks (row)
  procedure struct_after_delete (p_tree in varchar2);                                -- delete hooks (statement)

  -- ------------------------------------------------------------------ ACMAST (chart of accounts)
  function check_account (p_rowid in varchar2, p_account in varchar2, p_currency in varchar2) return varchar2;
  procedure account_row (p_inserting in boolean, p_account in out number, p_level in out number, p_status in out number);
  procedure account_created (p_rowid in varchar2);                                  -- after save (CREATE)
  function can_add_child (p_rowid in varchar2) return varchar2;                      -- action condition
  function add_child_account (p_rowid in varchar2, p_name in varchar2, p_name_e in varchar2) return varchar2;   -- action
  function account_balance_text (p_account in number) return varchar2;              -- info
  function level_text (p_level in number) return varchar2;                          -- info

  -- ------------------------------------------------------------------ ACCSTCD / ACCSTCD2 (cost centres)
  function add_cost_center (p_which in number, p_parent in number, p_code in number, p_name in varchar2,
                            p_name_e in varchar2) return varchar2;                   -- grid action (legacy tree insert)
  procedure cost_center_row (p_max_limit in number);                                 -- row rule AC_COST_CENTERS

  -- delete hooks of AC_MASTER / AC_COST_CENTERS / AC_COST_CENTERS2
  procedure code_before_delete (p_tree in varchar2, p_code in number, p_level in number);
  procedure code_after_delete (p_tree in varchar2);
  procedure hook_reset (p_tree in varchar2);

  -- ------------------------------------------------------------------ ACTRCOD (journal types)
  function copy_journal_year (p_from_year in number, p_to_year in number) return varchar2;   -- grid action
  procedure journal_before_delete (p_year in number, p_type in number);

  -- ------------------------------------------------------------------ ACCRNCY (currencies)
  function check_currency (p_rowid in varchar2, p_code in varchar2, p_rate in varchar2) return varchar2;
  procedure currency_row (p_code in number, p_rate in out number);
  procedure currency_after_save (p_code in varchar2);
  procedure currency_before_delete (p_code in number);

  -- ------------------------------------------------------------------ ACBASIC (system parameters)
  function check_basic (p_rowid in varchar2, p_company in varchar2, p_close_date in varchar2, p_min_date in varchar2,
                        p_max_date in varchar2, p_currency_stts in varchar2, p_income in varchar2, p_outcome in varchar2,
                        p_profit in varchar2, p_currency_acct in varchar2, p_cost_acct1 in varchar2,
                        p_cost_acct2 in varchar2) return varchar2;

  -- ------------------------------------------------------------------ ACESTMT_PRIODS (budget periods)
  function next_est_period return number;                                            -- key_expr PERIOD_CODE
  procedure est_period_row (p_code in number, p_from in date, p_till in date);
  procedure est_period_overlap;                                                      -- statement hook

  -- ------------------------------------------------------------------ ACESTMT_PERIODS_TRNS (budget preparation)
  function check_budget (p_code in varchar2) return varchar2;
  procedure budget_mast_row (p_account in number, p_cost in number, p_cost2 in number);
  procedure budget_det_row (p_period in number);
  procedure budget_after_save (p_est_code in varchar2);
  procedure budget_mast_before_delete (p_est_code in number, p_serial in number);
  function copy_budget (p_rowid in varchar2, p_with_actual in number) return varchar2;   -- actions

  -- ------------------------------------------------------------------ ACMNUCD (financial statements)
  procedure final_account_after_save (p_menu in varchar2);
  procedure final_account_refs;                                                      -- statement hook

  -- ------------------------------------------------------------------ AC_DUPENTRY_DEF (periodical entries list)
  function next_periodical_serial return number;                                     -- key_expr SERIAL
  procedure periodical_row (p_inserting in boolean, p_old_year in number, p_old_type in number, p_old_no in number,
                            p_year in number, p_type in number, p_no in number,
                            p_desc in out varchar2, p_desc_e in out varchar2);

  -- ------------------------------------------------------------------ AC_QUERYBEFORE / AC_QUERYAFTER (balance queries)
  function account_balance (p_account in number, p_cost in number, p_cost2 in number, p_date in date,
                            p_unposted in number) return number;
  procedure query_balance (p_account in number, p_cost in number, p_cost2 in number, p_date in date);
  function side_text (p_value in number) return varchar2;                            -- مدين / دائن

  -- ------------------------------------------------------------------ ACYRTR (posted entries): info
  function entry_info (p_rowid in varchar2, p_what in varchar2) return varchar2;
  -- button POST_VOUCHER (إلغاء الترحيل), wave 3b: enabled for group 0, else GROUP_COMPANY.POST_FLAG = 1 and all four rights of the
  -- user on the cancel-posting screen (FILE_PASSWORD 1 / 72); 'Y' / 'N'
  function can_cancel_entry (p_rowid in varchar2) return varchar2;
  -- the button: closed period and entries of other systems refused, then APP_PROC_GL.cancel_posting for this one entry
  function cancel_entry (p_rowid in varchar2) return varchar2;

  -- ------------------------------------------------------------------ AC_DISTP (cost centre distribution)
  function next_distp_det_serial (p_dis_serial in number) return number;            -- key_expr DET_SERIAL
  procedure distp_from_row (p_dis_serial in number, p_cost_code in number, p_acc_value in out number);
  procedure distp_det_row (p_inserting in boolean, p_dis_serial in number, p_old_prcnt in number, p_old_val in number,
                           p_prcnt in out number, p_val in out number);
  procedure distp_after_save (p_rowid in varchar2);
  function distp_totals (p_dis_serial in number, p_what in varchar2) return number;
  function distp_equal (p_rowid in varchar2) return varchar2;                        -- action نسب ثابتة
  function distp_post (p_rowid in varchar2) return varchar2;                         -- action ترحيل السجل
  function distp_unpost (p_rowid in varchar2) return varchar2;                       -- action إلغاء الترحيل
  procedure distp_before_delete (p_post_flag in number);                             -- delete hooks
  procedure distp_det_before_delete (p_dis_serial in number);

  -- ------------------------------------------------------------------ ACBENFTAX
  procedure benf_tax_row (p_tax_no in varchar2);
  procedure benf_tax_unique;                                                         -- statement hook

  -- ------------------------------------------------------------------ SUB_LG_COMPARE
  function gl_balance (p_account in number) return number;
  function supp_balance (p_prefix in number) return number;
  function sub_ledger_text (p_rowid in varchar2, p_what in varchar2) return varchar2;

end app_rules3_gl;
/
show errors package app_rules3_gl

create or replace package body app_rules3_gl as

  g_ctx       boolean := false;
  g_company   number;
  g_user      number;
  g_password  number;
  g_msg       varchar2(4000);
  g_page      number := -1;
  g_form      varchar2(100);
  g_test_free boolean := false;
  g_no_derive boolean := false;

  type t_num_tab is table of number index by pls_integer;
  g_parents_ac t_num_tab;
  g_parents_c1 t_num_tab;
  g_parents_c2 t_num_tab;

  c_struct_locked_a constant varchar2(1000) :=
    'نظرا لوجود عدد من السجلات بدليل الحسابات لا يمكن تغيير أو إضافة أو حذف أي من البيانات المدخلة سابقا بهيكل دليل الحسابات. ولعمل ذلك يجب حذف جميع السجلات من دليل الحسابات ثم العودة لتعديل هيكل دليل الحسابات';

  -- ================================================================== helpers
  procedure set_context (p_company_code in number, p_user_code in number, p_password_number in number) is
  begin
    g_ctx := true; g_company := p_company_code; g_user := p_user_code; g_password := p_password_number;
  end set_context;

  procedure clear_context is
  begin
    g_ctx := false; g_company := null; g_user := null; g_password := null;
  end clear_context;

  procedure set_test (p_structure_free in boolean) is
  begin
    g_test_free := nvl(p_structure_free, false);
  end set_test;

  function num (p in varchar2) return number is
  begin
    return to_number(p);
  exception when value_error or invalid_number then return null;
  end num;

  function dt (p in varchar2) return date is
  begin
    return to_date(p, 'DD/MM/YYYY');
  exception when others then return null;
  end dt;

  function is_en return boolean is
  begin
    return app_sec.lang = 'en';
  end is_en;

  function msg (p_a in varchar2, p_e in varchar2) return varchar2 is
  begin
    return case when is_en then nvl(p_e, p_a) else p_a end;
  end msg;

  procedure fail (p_code in pls_integer, p_a in varchar2, p_e in varchar2) is
  begin
    raise_application_error(p_code, msg(p_a, p_e));
  end fail;

  function ctx_company return number is
    l number;
  begin
    l := case when g_ctx then g_company else num(v('G_COMPANY_CODE')) end;
    if l is null then
      select min(company_code) into l from ac_basic;
    end if;
    return l;
  end ctx_company;

  function ctx_user return number is
  begin
    return case when g_ctx then g_user else num(v('G_USER_CODE')) end;
  end ctx_user;

  function ctx_group return number is
  begin
    return case when g_ctx then g_password else num(v('G_PASSWORD_NUMBER')) end;
  end ctx_group;

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

  function last_message return varchar2 is
  begin
    return g_msg;
  end last_message;

  function fmt (p in number) return varchar2 is
  begin
    return to_char(p, 'FM999G999G999G990D00');
  end fmt;

  function side_text (p_value in number) return varchar2 is
  begin
    -- legacy GET_BAL / GET_BALANCE: a balance that is not negative is shown as debit
    return case when sign(nvl(p_value, 0)) = -1 then msg('دائن', 'Credit') else msg('مدين', 'Debit') end;
  end side_text;

  -- ================================================================== code trees
  function code_len (p_tree in varchar2) return number is
  begin
    return case p_tree when 'AC' then 12 else 9 end;
  end code_len;

  function tree_no (p_tree in varchar2) return number is
  begin
    return case p_tree when 'C1' then 1 when 'C2' then 2 end;
  end tree_no;

  function tree_levels (p_tree in varchar2) return number is
    l number;
  begin
    if p_tree = 'AC' then
      select count(*) into l from ac_chart_structures;
    else
      select count(*) into l from ac_cost_strctures where cost_center_number = tree_no(p_tree);
    end if;
    return l;
  end tree_levels;

  function level_end (p_tree in varchar2, p_level in number) return number is
    l number;
  begin
    if p_level is null or p_level < 1 then return 0; end if;
    if p_tree = 'AC' then
      select chr_stru_end into l from ac_chart_structures where chr_stru_level = p_level;
    else
      select cost_str_end into l from ac_cost_strctures where cost_str_level = p_level and cost_center_number = tree_no(p_tree);
    end if;
    return l;
  exception when no_data_found then return null;
  end level_end;

  function level_start (p_tree in varchar2, p_level in number) return number is
    l number;
  begin
    if p_tree = 'AC' then
      select chr_stru_start into l from ac_chart_structures where chr_stru_level = p_level;
    else
      select cost_str_start into l from ac_cost_strctures where cost_str_level = p_level and cost_center_number = tree_no(p_tree);
    end if;
    return l;
  exception when no_data_found then return null;
  end level_start;

  -- DETECT_ACCOUNT_LEVEL / DETECT_COST_LEVEL(_NEW): the level is the last structure segment that is not zero;
  -- a zero segment followed by a non-zero one, a code longer than the structure or a missing structure is refused
  -- (the legacy procedure showed an error there).
  function code_level (p_tree in varchar2, p_code in number) return number is
    l_txt   varchar2(40) := to_char(p_code);
    l_len   number := code_len(p_tree);
    l_lvls  number := tree_levels(p_tree);
    l_level number := 0;
    l_zero  boolean := false;
    l_seg   varchar2(40);
  begin
    if p_code is null or p_code <= 0 or p_code != trunc(p_code) or length(l_txt) != l_len or l_lvls = 0 then
      return null;
    end if;
    for i in 1 .. l_lvls loop
      l_seg := substr(l_txt, level_start(p_tree, i), level_end(p_tree, i) - level_start(p_tree, i) + 1);
      if l_seg is null then return null; end if;
      if to_number(l_seg) = 0 then
        l_zero := true;
      elsif l_zero then
        return null;                              -- non-zero segment below a zero one
      else
        l_level := i;
      end if;
    end loop;
    if l_level = 0 then return null; end if;
    if level_end(p_tree, l_lvls) < l_len and to_number(substr(l_txt, level_end(p_tree, l_lvls) + 1)) != 0 then
      return null;
    end if;
    return l_level;
  end code_level;

  -- GET_ACCOUNT_PARENT / GET_COST_PARENT: RPAD(SUBSTR(code, 1, end_pos(level - 1)), len, '0')
  function code_parent (p_tree in varchar2, p_code in number, p_level in number) return number is
  begin
    if p_level is null or p_level <= 1 then return null; end if;
    return to_number(rpad(substr(to_char(p_code), 1, level_end(p_tree, p_level - 1)), code_len(p_tree), '0'));
  end code_parent;

  function code_exists (p_tree in varchar2, p_code in number) return boolean is
    l number;
  begin
    if p_tree = 'AC' then
      select count(*) into l from ac_master where account_number = p_code;
    elsif p_tree = 'C1' then
      select count(*) into l from ac_cost_centers where cost_code = p_code;
    else
      select count(*) into l from ac_cost_centers2 where cost_code = p_code;
    end if;
    return l > 0;
  end code_exists;

  -- TRANSACTIONS_FOUND_FOR (ACMAST / ACCSTCD / ACCSTCD2) and the PRE-DELETE checks: opening balances, daily and
  -- posted entries, estimates.
  function has_transactions (p_tree in varchar2, p_code in number) return number is
    l number;
  begin
    if p_tree = 'AC' then
      select count(*) into l from dual where exists (select 1 from ac_daily_trn_det where account_number = p_code)
          or exists (select 1 from ac_yearly_trn_det where account_number = p_code)
          or exists (select 1 from ac_opening_balance_det where account_number = p_code)
          or exists (select 1 from ac_estimate where account_number = p_code);
    elsif p_tree = 'C1' then
      select count(*) into l from dual where exists (select 1 from ac_daily_trn_det where cost_code = p_code)
          or exists (select 1 from ac_yearly_trn_det where cost_code = p_code)
          or exists (select 1 from ac_opening_balance_det where cost_code = p_code)
          or exists (select 1 from ac_estimate where cost_code = p_code);
    else
      select count(*) into l from dual where exists (select 1 from ac_daily_trn_det where cost_code2 = p_code)
          or exists (select 1 from ac_yearly_trn_det where cost_code2 = p_code)
          or exists (select 1 from ac_opening_balance_det where cost_code2 = p_code)
          or exists (select 1 from ac_estimate where cost_code2 = p_code);
    end if;
    return l;
  end has_transactions;

  -- the parent becomes a main (non postable) code once it has a child (UPDATE ... SET ..._STATUS = 0)
  procedure set_status (p_tree in varchar2, p_code in number, p_status in number) is
  begin
    if p_code is null then return; end if;
    if p_tree = 'AC' then
      update ac_master set account_status = p_status where account_number = p_code;
    elsif p_tree = 'C1' then
      update ac_cost_centers set cost_status = p_status where cost_code = p_code;
    else
      update ac_cost_centers2 set cost_status = p_status where cost_code = p_code;
    end if;
  end set_status;

  -- ACCOUNT_HAS_BROTHERS / COST_HAS_BROTHERS: children of p_parent still present
  function child_count (p_tree in varchar2, p_parent in number) return number is
    l_lvl number;
    l_end number;
    l_len number := code_len(p_tree);
    l     number;
  begin
    if p_tree = 'AC' then
      select max(account_level) into l_lvl from ac_master where account_number = p_parent;
    elsif p_tree = 'C1' then
      select max(cost_level) into l_lvl from ac_cost_centers where cost_code = p_parent;
    else
      select max(cost_level) into l_lvl from ac_cost_centers2 where cost_code = p_parent;
    end if;
    if l_lvl is null then return 0; end if;
    l_end := level_end(p_tree, l_lvl);
    if p_tree = 'AC' then
      select count(*) into l from ac_master
       where account_level = l_lvl + 1 and rpad(substr(to_char(account_number), 1, l_end), l_len, '0') = to_char(p_parent);
    elsif p_tree = 'C1' then
      select count(*) into l from ac_cost_centers
       where cost_level = l_lvl + 1 and rpad(substr(to_char(cost_code), 1, l_end), l_len, '0') = to_char(p_parent);
    else
      select count(*) into l from ac_cost_centers2
       where cost_level = l_lvl + 1 and rpad(substr(to_char(cost_code), 1, l_end), l_len, '0') = to_char(p_parent);
    end if;
    return l;
  end child_count;

  -- GET_NEXT_ACCOUNT / GET_NEXT_COST:
  --   SELECT RPAD(SUBSTR(MAX(code), 1, end_child) + 1, len, 0) FROM table
  --    WHERE RPAD(TO_NUMBER(SUBSTR(code, 1, end_parent)), len, 0) = RPAD(TO_NUMBER(SUBSTR(parent, 1, end_parent)), len, 0)
  function next_child (p_tree in varchar2, p_parent in number, p_parent_level in number) return number is
    l_len  number := code_len(p_tree);
    l_endp number := level_end(p_tree, p_parent_level);
    l_endc number := level_end(p_tree, p_parent_level + 1);
    l_max  number;
    l_new  number;
  begin
    if l_endc is null then
      fail(-20120, 'لا يوجد مستوى أدنى في الهيكل لهذا الرقم', 'The structure has no lower level for this code');
    end if;
    if p_tree = 'AC' then
      select max(account_number) into l_max from ac_master
       where rpad(to_number(substr(account_number, 1, l_endp)), l_len, 0) = rpad(to_number(substr(p_parent, 1, l_endp)), l_len, 0);
    elsif p_tree = 'C1' then
      select max(cost_code) into l_max from ac_cost_centers
       where rpad(to_number(substr(cost_code, 1, l_endp)), l_len, 0) = rpad(to_number(substr(p_parent, 1, l_endp)), l_len, 0);
    else
      select max(cost_code) into l_max from ac_cost_centers2
       where rpad(to_number(substr(cost_code, 1, l_endp)), l_len, 0) = rpad(to_number(substr(p_parent, 1, l_endp)), l_len, 0);
    end if;
    l_new := to_number(rpad(to_char(to_number(substr(to_char(nvl(l_max, p_parent)), 1, l_endc)) + 1), l_len, '0'));
    -- improvement: the legacy formula carries into the parent segment when the level is full
    if code_parent(p_tree, l_new, p_parent_level + 1) != p_parent then
      fail(-20121, 'لا توجد أرقام متاحة في هذا المستوى', 'No free number is left at this level');
    end if;
    return l_new;
  end next_child;

  -- the grants a new code gets (ACMAST / ACCSTCD POST-INSERT): company + the creating user's group
  procedure grant_code (p_tree in varchar2, p_code in number, p_level in number) is
    l_company number := ctx_company;
    l_group   number := ctx_group;
    l_end     number := level_end(p_tree, p_level);
  begin
    if p_tree = 'AC' then
      insert into ac_company_master (account_number, company_code, account_level, account_end_pos)
      select p_code, l_company, p_level, l_end from dual
       where not exists (select 1 from ac_company_master where account_number = p_code and company_code = l_company);
      if l_group is not null then
        insert into ac_password_master (account_number, company_code, password_number, account_level, account_end_pos)
        select p_code, l_company, l_group, p_level, l_end from dual
         where not exists (select 1 from ac_password_master
                            where account_number = p_code and company_code = l_company and password_number = l_group);
      end if;
    elsif p_tree = 'C1' then
      insert into ac_company_cost1 (cost_code, company_code, cost_level, cost_end_pos)
      select p_code, l_company, p_level, l_end from dual
       where not exists (select 1 from ac_company_cost1 where cost_code = p_code and company_code = l_company);
      if l_group is not null then
        insert into ac_password_cost1 (cost_code, company_code, password_number, cost_level, cost_end_pos)
        select p_code, l_company, l_group, p_level, l_end from dual
         where not exists (select 1 from ac_password_cost1
                            where cost_code = p_code and company_code = l_company and password_number = l_group);
      end if;
    end if;                                       -- cost centres 2: the legacy ACCSTCD2 inserts no grants
  exception
    when others then
      if sqlcode between -20999 and -20000 then raise; end if;
      if p_tree = 'AC' then
        fail(-20122, 'لم يم ادراج رقم الحساب في السرية', 'The account number was not added to the privileges');
      else
        fail(-20122, 'لم يم ادراج رقم مركز التكلفة في السرية', 'The cost centre was not added to the privileges');
      end if;
  end grant_code;

  -- ================================================================== structures
  function next_chart_level return number is
    l number;
  begin
    select nvl(max(chr_stru_level), 0) + 1 into l from ac_chart_structures;
    return l;
  end next_chart_level;

  procedure struct_common (p_tree in varchar2, p_inserting in boolean, p_old_level in number, p_old_start in number,
                           p_old_end in number, p_old_len in number, p_level in number, p_desc in varchar2,
                           p_start in out number, p_end in number, p_len in out number) is
    l_codes number;
    l_max   number := code_len(p_tree);
  begin
    if p_tree = 'AC' then
      select count(*) into l_codes from ac_master where rownum = 1;
    elsif p_tree = 'C1' then
      select count(*) into l_codes from ac_cost_centers where rownum = 1;
    else
      select count(*) into l_codes from ac_cost_centers2 where rownum = 1;
    end if;
    if g_test_free then l_codes := 0; end if;
    if l_codes > 0 then
      if p_inserting then
        if p_tree = 'AC' then
          fail(-20100, c_struct_locked_a, 'The chart of accounts already has accounts: its structure cannot be changed');
        else
          fail(-20100, 'لا يمكن تعديل بيانات هيكل مراكز التكلفة أثناء وجود بعض الحركات ولكن يمكن تعديل اسم المركز فقط',
               'Cost centres exist: only the level names of the structure can be changed');
        end if;
      elsif p_level != p_old_level or p_start != p_old_start or p_end != p_old_end
            or nvl(p_len, p_old_len) != p_old_len then
        if p_tree = 'AC' then
          fail(-20101, 'لا يمكن تعديل بيانات هيكل دليل الحسابات أثناء وجود بيانات في الدليل ولكن يمكن تعديل اسم المستوي فقط',
               'The chart of accounts has accounts: only the level name can be changed');
        else
          fail(-20101, 'لا يمكن تعديل بيانات هيكل مراكز التكلفة أثناء وجود بعض الحركات ولكن يمكن تعديل اسم المركز فقط',
               'Cost centres exist: only the level names of the structure can be changed');
        end if;
      end if;
    end if;
    if p_desc is null then
      fail(-20102, 'برجاء إدخال اسم المستوي', 'Please enter the level name');
    end if;
    if p_inserting and p_start is null then
      -- WHEN-NEW-RECORD-INSTANCE: start = last end + 1 (SELECT NVL(MAX(..._END), 0) ...)
      if p_tree = 'AC' then
        select nvl(max(chr_stru_end), 0) + 1 into p_start from ac_chart_structures;
      else
        select nvl(max(cost_str_end), 0) + 1 into p_start from ac_cost_strctures where cost_center_number = tree_no(p_tree);
      end if;
    end if;
    if p_start is null then
      fail(-20103, 'برجاء إدخال رقم البداية', 'Please enter the start position');
    end if;
    if p_end is null or p_end < p_start or p_end > l_max then
      fail(-20104, 'برجاء التأكد من إدخال -- حقل النهاية -- و كونه اكبر من حقل البداية و كذلك كونه أقل من ' || l_max,
           'The end position must be entered, not smaller than the start and not greater than ' || l_max);
    end if;
    p_len := p_end - p_start + 1;
  end struct_common;

  procedure chart_struct_row (p_inserting in boolean, p_old_level in number, p_old_start in number, p_old_end in number,
                              p_old_len in number, p_level in number, p_desc in varchar2,
                              p_start in out number, p_end in number, p_len in out number) is
  begin
    struct_common('AC', p_inserting, p_old_level, p_old_start, p_old_end, p_old_len, p_level, p_desc, p_start, p_end, p_len);
  end chart_struct_row;

  function cost_struct_no (p_no in number) return number is
  begin
    return coalesce(p_no, case cur_form when 'AC_COST_STRUCT1' then 1 when 'AC_COST_STRUCT2' then 2 end);
  end cost_struct_no;

  function next_cost_level (p_no in number) return number is
    l number;
  begin
    select nvl(max(cost_str_level), 0) + 1 into l from ac_cost_strctures where cost_center_number = p_no;
    return l;
  end next_cost_level;

  procedure cost_struct_row (p_inserting in boolean, p_no in number, p_old_level in number, p_old_start in number,
                             p_old_end in number, p_old_len in number, p_level in number, p_desc in varchar2,
                             p_start in out number, p_end in number, p_len in out number) is
  begin
    if p_no not in (1, 2) or p_no is null then
      fail(-20105, 'رقم هيكل مراكز التكلفة يجب أن يكون 1 أو 2', 'The cost centre structure number must be 1 or 2');
    end if;
    struct_common(case p_no when 1 then 'C1' else 'C2' end, p_inserting, p_old_level, p_old_start, p_old_end, p_old_len,
                  p_level, p_desc, p_start, p_end, p_len);
  end cost_struct_row;

  procedure struct_before_delete (p_tree in varchar2) is
    l number;
  begin
    if g_test_free then return; end if;
    if p_tree = 'AC' then
      select count(*) into l from ac_master where rownum = 1;
      if l > 0 then
        fail(-20106, c_struct_locked_a, 'The chart of accounts has accounts: the structure cannot be deleted');
      end if;
    else
      if p_tree = 'C1' then
        select count(*) into l from ac_cost_centers where rownum = 1;
      else
        select count(*) into l from ac_cost_centers2 where rownum = 1;
      end if;
      if l > 0 then
        fail(-20106, 'لا يمكن حذف السجلات', 'The records cannot be deleted: cost centres exist');
      end if;
    end if;
  end struct_before_delete;

  -- "يجب حذف السجلات من إسفل إلي أعلي": after a delete the levels must still be 1..n
  procedure struct_after_delete (p_tree in varchar2) is
    l_cnt number;
    l_max number;
  begin
    if p_tree = 'AC' then
      select count(*), nvl(max(chr_stru_level), 0) into l_cnt, l_max from ac_chart_structures;
    else
      select count(*), nvl(max(cost_str_level), 0) into l_cnt, l_max from ac_cost_strctures where cost_center_number = tree_no(p_tree);
    end if;
    if l_cnt != l_max then
      fail(-20107, 'يجب حذف السجلات من إسفل إلي أعلي ... كما يجب تسجيل حذف سجل قبل البدء في حذف سجل أخر',
           'Levels must be deleted from the bottom up, one saved delete at a time');
    end if;
  end struct_after_delete;

  -- ================================================================== ACMAST
  function pad_account (p in number) return number is
  begin
    if p is null then return null; end if;
    if length(to_char(p)) < 12 then
      return to_number(rpad(to_char(p), 12, '0'));
    end if;
    return p;
  end pad_account;

  function check_account (p_rowid in varchar2, p_account in varchar2, p_currency in varchar2) return varchar2 is
    l_acc    number := num(p_account);
    l_level  number;
    l_parent number;
    l_old    number;
  begin
    if p_account is null then
      return msg('يجب إدخال رقم الحساب', 'The account number is required');
    end if;
    if l_acc is null or l_acc <= 0 or l_acc != trunc(l_acc) or length(to_char(l_acc)) > 12 then
      return msg('رقم الحساب غير صحيح', 'Invalid account number');
    end if;
    l_acc := pad_account(l_acc);
    if p_rowid is null then
      if code_exists('AC', l_acc) then
        return msg('رقم الحساب موجود من قبل', 'The account number already exists');
      end if;
      l_level := code_level('AC', l_acc);
      if l_level is null then
        return msg('رقم الحساب لا يتفق مع هيكل دليل الحسابات', 'The account number does not fit the chart structure');
      end if;
      l_parent := code_parent('AC', l_acc, l_level);
      if l_parent is not null then
        if not code_exists('AC', l_parent) then
          return msg('لا يمكن تكوين حساب أبن بلا حساب أب', 'You cant add children Account without a parent Acccount');
        end if;
        if has_transactions('AC', l_parent) = 1 then
          return msg('لا يمكن إضافة حساب فرعي لحساب عليه حركات', 'A sub-account cannot be added under an account that has transactions');
        end if;
      end if;
    else
      begin
        select account_number into l_old from ac_master where rowid = chartorowid(p_rowid);
      exception when no_data_found then l_old := null;
      end;
      if l_old is not null and l_old != l_acc then
        return msg('لا يمكن تعديل رقم الحساب', 'The account number cannot be changed');
      end if;
    end if;
    if p_currency is null then
      return msg('يجب ادخال العملة', 'Must Insert Currency');
    end if;
    return null;
  end check_account;

  procedure account_row (p_inserting in boolean, p_account in out number, p_level in out number, p_status in out number) is
  begin
    if p_inserting then
      p_account := pad_account(p_account);
      p_level := code_level('AC', p_account);
      if p_level is null then
        fail(-20108, 'رقم الحساب لا يتفق مع هيكل دليل الحسابات', 'The account number does not fit the chart structure');
      end if;
      p_status := nvl(p_status, 1);
    end if;
  end account_row;

  procedure code_created (p_tree in varchar2, p_code in number, p_level in number) is
    l_parent number := code_parent(p_tree, p_code, p_level);
  begin
    if l_parent is not null then
      set_status(p_tree, l_parent, 0);
    end if;
    grant_code(p_tree, p_code, p_level);
  end code_created;

  procedure account_created (p_rowid in varchar2) is
    l_acc   number;
    l_level number;
  begin
    select account_number, account_level into l_acc, l_level from ac_master where rowid = chartorowid(p_rowid);
    code_created('AC', l_acc, l_level);
  exception when no_data_found then null;
  end account_created;

  function can_add_child (p_rowid in varchar2) return varchar2 is
    l_level number;
  begin
    select account_level into l_level from ac_master where rowid = chartorowid(p_rowid);
    return case when l_level < tree_levels('AC') then 'Y' else 'N' end;
  exception when others then return 'N';
  end can_add_child;

  function add_child_account (p_rowid in varchar2, p_name in varchar2, p_name_e in varchar2) return varchar2 is
    l_par   ac_master%rowtype;
    l_new   number;
    l_rowid rowid;
  begin
    begin
      select * into l_par from ac_master where rowid = chartorowid(p_rowid) for update;
    exception when no_data_found then
      fail(-20109, 'لا يمكن تكوين حساب أبن بلا حساب أب', 'You cant add children Account without a parent Acccount');
    end;
    if p_name is null then
      fail(-20110, 'يجب إدخال اسم الحساب', 'The account name is required');
    end if;
    if has_transactions('AC', l_par.account_number) = 1 then
      fail(-20111, 'لا يمكن إضافة حساب فرعي لحساب عليه حركات', 'A sub-account cannot be added under an account that has transactions');
    end if;
    l_new := next_child('AC', l_par.account_number, l_par.account_level);
    insert into ac_master (account_number, account_name, account_name_e, currency_code, account_level, account_status)
    values (l_new, p_name, p_name_e, l_par.currency_code, l_par.account_level + 1, 1)
    returning rowid into l_rowid;
    code_created('AC', l_new, l_par.account_level + 1);
    g_msg := msg('تم إنشاء الحساب رقم ', 'Account created: ') || l_new;
    return rowidtochar(l_rowid);
  end add_child_account;

  -- POST-QUERY of ACMAST: GET_ACCOUNT_BAL_LEVEL (posted lines of the account and its sub-accounts, this company),
  -- shown as an absolute value with debit / credit; foreign-currency accounts also in their currency (/ AC_CURRENCY.RATE)
  function account_balance_text (p_account in number) return varchar2 is
    l_bal  number;
    l_cur  number;
    l_rate number;
    l_txt  varchar2(400);
  begin
    if p_account is null then return null; end if;
    l_bal := nvl(get_account_bal_level(ctx_company, p_account), 0);
    l_txt := fmt(abs(l_bal)) || ' ' || side_text(l_bal);
    select max(m.currency_code), max(c.rate) into l_cur, l_rate
      from ac_master m left join ac_currency c on c.currency_code = m.currency_code
     where m.account_number = p_account;
    if nvl(l_cur, 1) != 1 and nvl(l_rate, 0) != 0 then
      l_txt := l_txt || ' / ' || fmt(abs(l_bal) / l_rate) || ' ' || msg('بعملة الحساب', 'in account currency');
    end if;
    return l_txt;
  end account_balance_text;

  function level_text (p_level in number) return varchar2 is
    l_desc varchar2(400);
    l_len  number;
    l_en   varchar2(1) := case when is_en then 'Y' else 'N' end;
  begin
    select nvl(case when l_en = 'Y' then chr_stru_desce end, chr_stru_desca), length into l_desc, l_len
      from ac_chart_structures where chr_stru_level = p_level;
    return p_level || ' - ' || l_desc || ' (' || msg('طول المستوى ', 'level length ') || l_len || ')';
  exception when no_data_found then return to_char(p_level);
  end level_text;

  -- ================================================================== ACCSTCD / ACCSTCD2
  function add_cost_center (p_which in number, p_parent in number, p_code in number, p_name in varchar2,
                            p_name_e in varchar2) return varchar2 is
    l_tree   varchar2(2) := case p_which when 1 then 'C1' when 2 then 'C2' end;
    l_code   number;
    l_level  number;
    l_parent number;
    l_plevel number;
    l_rowid  rowid;
  begin
    if l_tree is null then
      fail(-20112, 'رقم مركز التكلفة يجب أن يكون 1 أو 2', 'Cost centre number must be 1 or 2');
    end if;
    if p_name is null then
      fail(-20113, 'يجب إدخال اسم مركز التكلفة', 'The cost centre name is required');
    end if;
    if p_code is not null then
      -- typed code (COST_CODE WHEN-VALIDATE-ITEM: DETECT_COST_LEVEL, COST_FOUND of the parent)
      if p_code <= 0 or p_code != trunc(p_code) or length(to_char(p_code)) > 9 then
        fail(-20114, 'رقم مركز التكلفة غير صحيح', 'Invalid cost centre number');
      end if;
      l_code := p_code;
      if length(to_char(l_code)) < 9 then
        l_code := to_number(rpad(to_char(l_code), 9, '0'));
      end if;
      if code_exists(l_tree, l_code) then
        fail(-20115, 'رقم مركز التكلفة موجود من قبل', 'The cost centre already exists');
      end if;
      l_level := code_level(l_tree, l_code);
      if l_level is null then
        fail(-20116, 'رقم مركز التكلفة لا يتفق مع هيكل مراكز التكلفة', 'The cost centre number does not fit the structure');
      end if;
      l_parent := code_parent(l_tree, l_code, l_level);
      if l_parent is not null and not code_exists(l_tree, l_parent) then
        fail(-20117, 'لا يمكن تكوين مركز تكلفة إبن بلا مركز تكلفة أب', 'A child cost centre needs its parent cost centre');
      end if;
    elsif p_parent is not null then
      -- new record under the selected node of the tree (GET_NEXT_COST)
      if p_which = 1 then
        select max(cost_level) into l_plevel from ac_cost_centers where cost_code = p_parent;
      else
        select max(cost_level) into l_plevel from ac_cost_centers2 where cost_code = p_parent;
      end if;
      if l_plevel is null then
        fail(-20117, 'لا يمكن تكوين مركز تكلفة إبن بلا مركز تكلفة أب', 'A child cost centre needs its parent cost centre');
      end if;
      l_parent := p_parent;
      l_level := l_plevel + 1;
      l_code := next_child(l_tree, p_parent, l_plevel);
    else
      fail(-20118, 'يجب إدخال رقم مركز التكلفة أو اختيار المركز الأب', 'Enter the cost centre number or choose its parent');
    end if;
    if l_parent is not null and has_transactions(l_tree, l_parent) = 1 then
      fail(-20119, 'لا يمكن إضافة مركز تكلفة فرعي لمركز عليه حركات', 'A child cannot be added under a cost centre that has transactions');
    end if;
    if p_which = 1 then
      insert into ac_cost_centers (cost_code, cost_desc, cost_desc_e, cost_level, cost_status)
      values (l_code, p_name, p_name_e, l_level, 1) returning rowid into l_rowid;
    else
      insert into ac_cost_centers2 (cost_code, cost_desc, cost_desc_e, cost_level, cost_status)
      values (l_code, p_name, p_name_e, l_level, 1) returning rowid into l_rowid;
    end if;
    code_created(l_tree, l_code, l_level);
    g_msg := msg('تم إنشاء مركز التكلفة رقم ', 'Cost centre created: ') || l_code;
    return rowidtochar(l_rowid);
  end add_cost_center;

  procedure cost_center_row (p_max_limit in number) is
  begin
    if p_max_limit is not null and p_max_limit <= 0 then
      fail(-20123, 'يجب ان تكون القيمة  اكبر من صفر', 'The value must be greater than zero');
    end if;
  end cost_center_row;

  -- ================================================================== delete hooks of the code trees
  procedure hook_reset (p_tree in varchar2) is
  begin
    if p_tree = 'AC' then g_parents_ac.delete;
    elsif p_tree = 'C1' then g_parents_c1.delete;
    else g_parents_c2.delete;
    end if;
  end hook_reset;

  procedure code_before_delete (p_tree in varchar2, p_code in number, p_level in number) is
    l_parent number := code_parent(p_tree, p_code, p_level);
  begin
    if has_transactions(p_tree, p_code) = 1 then
      if p_tree = 'AC' then
        fail(-20124, 'لا يمكن حذف الحساب لوجود حركات عليه', 'The account has transactions and cannot be deleted');
      else
        fail(-20124, 'لا يمكن حذف مركز التكلفة لوجود حركات عليه', 'The cost centre has transactions and cannot be deleted');
      end if;
    end if;
    if p_tree = 'AC' then
      delete from ac_password_master where account_number = p_code;
      delete from ac_company_master where account_number = p_code;
    elsif p_tree = 'C1' then
      delete from ac_password_cost1 where cost_code = p_code;
      delete from ac_company_cost1 where cost_code = p_code;
    end if;
    if l_parent is not null then
      if p_tree = 'AC' then g_parents_ac(g_parents_ac.count + 1) := l_parent;
      elsif p_tree = 'C1' then g_parents_c1(g_parents_c1.count + 1) := l_parent;
      else g_parents_c2(g_parents_c2.count + 1) := l_parent;
      end if;
    end if;
  end code_before_delete;

  -- POST-DELETE: the parent becomes a sub (postable) code again when its last child is gone
  procedure code_after_delete (p_tree in varchar2) is
    l_list t_num_tab;
  begin
    if p_tree = 'AC' then l_list := g_parents_ac;
    elsif p_tree = 'C1' then l_list := g_parents_c1;
    else l_list := g_parents_c2;
    end if;
    hook_reset(p_tree);
    for i in 1 .. l_list.count loop
      if child_count(p_tree, l_list(i)) = 0 then
        set_status(p_tree, l_list(i), 1);
      end if;
    end loop;
  end code_after_delete;

  -- ================================================================== ACTRCOD
  function copy_journal_year (p_from_year in number, p_to_year in number) return varchar2 is
    l_max_date date;
    l_n        number;
    l_company  number := ctx_company;
    l_copied   number := 0;
  begin
    if p_from_year is null or p_to_year is null then
      fail(-20125, 'إدخال ''من سنة'' و ''إلى سنة''', 'Enter the from year and the to year');
    end if;
    select max(max_date) into l_max_date from ac_basic where company_code = l_company;
    if l_max_date is not null and p_to_year > to_number(to_char(l_max_date, 'YYYY')) then
      fail(-20126, 'السنة المالية أكبر من المسموح بة فى مؤشرات النظام!!', 'The financial year is beyond the maximum date of the system parameters');
    end if;
    select count(*) into l_n from ac_trn_codes where entry_year = p_from_year;
    if l_n = 0 then
      fail(-20127, 'السنة المالية غير موجودة من فضلك أدخل سنة أخرى', 'The financial year does not exist, enter another year');
    end if;
    if p_to_year = p_from_year then
      fail(-20128, 'لا بد من إدخال قيمة مختلفة عن قيمة السنة المراد نسخها في السنة الجديدة',
           'The new year must differ from the year being copied');
    end if;
    for r in (select * from ac_trn_codes where entry_year = p_from_year order by entry_type) loop
      select count(*) into l_n from ac_trn_codes where entry_year = p_to_year and entry_type = r.entry_type;
      if l_n = 0 then
        insert into ac_trn_codes (entry_year, entry_type, entry_desc, entry_desc_e, last_serial, ac_flag, serial_flag)
        values (p_to_year, r.entry_type, r.entry_desc, r.entry_desc_e, 0, r.ac_flag, r.serial_flag);
        l_copied := l_copied + 1;
      end if;
      insert into ac_company_entry (entry_year, entry_type, company_code)
      select p_to_year, r.entry_type, l_company from dual
       where not exists (select 1 from ac_company_entry where entry_year = p_to_year and entry_type = r.entry_type and company_code = l_company);
      for g in (select password_number from ac_password_entry
                 where company_code = l_company and entry_year = p_from_year and entry_type = r.entry_type) loop
        insert into ac_password_entry (company_code, entry_year, entry_type, password_number)
        select l_company, p_to_year, r.entry_type, g.password_number from dual
         where not exists (select 1 from ac_password_entry where company_code = l_company and entry_year = p_to_year
                              and entry_type = r.entry_type and password_number = g.password_number);
      end loop;
    end loop;
    g_msg := msg('تم إنشاء السنة المالية ' || p_to_year || ' (' || l_copied || ' نوع حركة)',
                 'Financial year ' || p_to_year || ' created (' || l_copied || ' journal types)');
    return null;
  end copy_journal_year;

  procedure journal_before_delete (p_year in number, p_type in number) is
    l number;
  begin
    select count(*) into l from dual
     where exists (select 1 from ac_opening_balance where entry_year = p_year and entry_type = p_type)
        or exists (select 1 from ac_daily_trn where entry_year = p_year and entry_type = p_type)
        or exists (select 1 from ac_yearly_trn where entry_year = p_year and entry_type = p_type);
    if l > 0 then
      fail(-20129, 'لا يمكن حذف نوع الحركة لوجود قيود عليه', 'The journal type has entries and cannot be deleted');
    end if;
    select count(*) into l from ac_company_entry where entry_year = p_year and entry_type = p_type;
    if l > 0 then
      fail(-20130, 'رقم الحركة موجود فى صلاحيات الشركات', 'The journal type is used in the company privileges');
    end if;
  end journal_before_delete;

  -- ================================================================== ACCRNCY
  function check_currency (p_rowid in varchar2, p_code in varchar2, p_rate in varchar2) return varchar2 is
    l_code number := num(p_code);
    l_rate number := num(p_rate);
  begin
    if p_code is null then
      return msg('يجب إدخال رقم العملة', 'The currency number is required');
    end if;
    if l_code is null or l_code <= 0 or l_code >= 9999 then
      return msg('رقم العملة يجب ان يكون اكبر من الصفر و اصغر من 9999', 'The currency number must be between 1 and 9998');
    end if;
    if p_rate is not null and (l_rate is null or l_rate <= 0 or l_rate >= 999999999.99) then
      return msg('معامل التحويل يجب ان يكون اكبر من الصفر و اقل من 999999999.99',
                 'The exchange rate must be greater than zero and less than 999999999.99');
    end if;
    return null;
  end check_currency;

  procedure currency_row (p_code in number, p_rate in out number) is
  begin
    if p_code = 1 then
      p_rate := 1;                                 -- currency 1 is the local currency (hint of CURRENCY_CODE)
    end if;
  end currency_row;

  procedure currency_after_save (p_code in varchar2) is
    l number;
  begin
    select count(*) into l from (
      select from_date from ac_currency_srv_rate where currency_code = num(p_code) and from_date is not null
       group by from_date having count(*) > 1);
    if l > 0 then
      fail(-20131, 'تم إدخال هذا التاريخ من قبل !!!', 'This Date Inserted Befor');
    end if;
  end currency_after_save;

  procedure currency_before_delete (p_code in number) is
    l number;
  begin
    if p_code = 1 then
      fail(-20132, 'لا يمكن مسح هذا السجل حيث أنه يستخدم بالبرنامج', 'Can''t delete this record because it is used by program');
    end if;
    select count(*) into l from dual
     where exists (select 1 from ac_master where currency_code = p_code)
        or exists (select 1 from ac_daily_trn where currency_code = p_code)
        or exists (select 1 from ac_opening_balance where currency_code = p_code)
        or exists (select 1 from ac_yearly_trn where currency_code = p_code)
        or exists (select 1 from ac_yearly_trn_old where currency_code = p_code);
    if l > 0 then
      fail(-20133, 'لا يمكن مسح هذة العملة , يوجد حركات علي هذة العملة!!', 'Cant Delete Currency!! Trns. Found On This Currency');
    end if;
  end currency_before_delete;

  -- ================================================================== ACBASIC
  function sub_account_ok (p_account in number) return boolean is
    l number;
  begin
    if p_account is null then return true; end if;
    select count(*) into l from ac_master where account_number = p_account and account_status = 1;
    return l > 0;
  end sub_account_ok;

  function check_basic (p_rowid in varchar2, p_company in varchar2, p_close_date in varchar2, p_min_date in varchar2,
                        p_max_date in varchar2, p_currency_stts in varchar2, p_income in varchar2, p_outcome in varchar2,
                        p_profit in varchar2, p_currency_acct in varchar2, p_cost_acct1 in varchar2,
                        p_cost_acct2 in varchar2) return varchar2 is
    l_close   date := dt(p_close_date);
    l_old     date;
    l_company number := nvl(num(p_company), ctx_company);
    l         number;
  begin
    -- CLOSE_DATE (CHECK_CLOSE_DATE / CHECK_CLOSE_STORES): no unposted document up to the new closing date
    if p_rowid is not null then
      select max(close_date) into l_old from ac_basic where rowid = chartorowid(p_rowid);
    end if;
    if l_close is not null and (l_old is null or l_close != l_old) then
      select count(*) into l from ac_daily_trn where entry_date <= l_close and create_company_code = l_company;
      if l > 0 then return msg('توجد قيود غير مرحلة قبل هذا التاريخ', 'Unposted entries exist before this date'); end if;
      select count(*) into l from ar_maintrns where post_flag = 0 and trns_date <= l_close;
      if l > 0 then return msg('توجد قيود غير مرحلة فى نظام العملاء قبل هذا التاريخ', 'Unposted customer transactions exist before this date'); end if;
      select count(*) into l from st_trns_mast where post_flag = 0 and trns_date <= l_close;
      if l > 0 then return msg('توجد قيود غير مرحلة فى نظام المخازن قبل هذا التاريخ', 'Unposted stock transactions exist before this date'); end if;
      select count(*) into l from vn_maintrns where post_flag = 0 and trns_date <= l_close;
      if l > 0 then return msg('توجد قيود غير مرحلة فى نظام الموردين قبل هذا التاريخ', 'Unposted supplier transactions exist before this date'); end if;
    end if;
    if dt(p_min_date) is not null and dt(p_max_date) is not null and dt(p_max_date) <= dt(p_min_date) then
      return msg('يجب إدخال تاريخ أكبر منالحد الأدني للحركات!!', 'The maximum date must be greater than the minimum date');
    end if;
    -- single currency cannot be chosen while foreign-currency entries exist (PRE-FORM counts them)
    if num(p_currency_stts) = 0 then
      select count(*) into l from dual
       where exists (select 1 from ac_yearly_trn where currency_code != 1)
          or exists (select 1 from ac_opening_balance where currency_code != 1);
      if l > 0 then
        return msg('لا يمكن اختيار عملة واحدة لوجود قيود بعملات أخرى', 'Single currency cannot be chosen: entries in other currencies exist');
      end if;
    end if;
    -- accounts of the parameters
    for r in (select column_value a from table(sys.odcinumberlist(num(p_income), num(p_outcome)))) loop
      if r.a is not null and not code_exists('AC', r.a) then
        return msg('رقم الحساب غير موجود فى دليل الحسابات', 'The account does not exist in the chart of accounts') || ': ' || r.a;
      end if;
    end loop;
    for r in (select column_value a from table(sys.odcinumberlist(num(p_profit), num(p_currency_acct), num(p_cost_acct1), num(p_cost_acct2)))) loop
      if not sub_account_ok(r.a) then
        return msg('الحساب ليس حساب فرعى', 'The account is not a sub account') || ': ' || r.a;
      end if;
    end loop;
    return null;
  end check_basic;

  -- ================================================================== ACESTMT_PRIODS
  function next_est_period return number is
    l number;
  begin
    select nvl(max(period_code), 0) + 1 into l from ac_estimate_periods;
    return l;
  end next_est_period;

  procedure est_period_row (p_code in number, p_from in date, p_till in date) is
    l_min date;
  begin
    if p_code < 0 then
      fail(-20134, 'رقم الفترة لا يمكن أن يكون أقل من الصفر', 'The period number cannot be negative');
    end if;
    select max(min_date) into l_min from ac_basic where company_code = ctx_company;
    if p_from is not null and l_min is not null and p_from < l_min then
      fail(-20135, 'التاريخ أقل من الحد الأدنى المسموح به', 'The date is before the minimum allowed date');
    end if;
    if p_from is not null and p_till is not null and p_from >= p_till then
      fail(-20136, 'يجب ان يكون من تاريخ اصغر من الى تاريخ', 'The from date must be before the to date');
    end if;
  end est_period_row;

  procedure est_period_overlap is
    l number;
  begin
    select count(*) into l from ac_estimate_periods a, ac_estimate_periods b
     where a.period_code != b.period_code
       and (a.from_date between b.from_date and b.till_date or a.till_date between b.from_date and b.till_date);
    if l > 0 then
      fail(-20137, 'يوجد تقاطع فى نطاق التواريخ مع نطاق أخر', 'The date range overlaps another period');
    end if;
  end est_period_overlap;

  -- ================================================================== ACESTMT_PERIODS_TRNS
  function check_budget (p_code in varchar2) return varchar2 is
  begin
    if num(p_code) < 0 then
      return msg('كود الميزانية لا يمكن أن يكون أقل من الصفر', 'The budget code cannot be negative');
    end if;
    return null;
  end check_budget;

  procedure budget_mast_row (p_account in number, p_cost in number, p_cost2 in number) is
    l number;
    l_group number := nvl(ctx_group, 0);
  begin
    -- ACCOUNT_LOV: sub accounts (ACCOUNT_STATUS = 1) granted to the group; COST_CENTERS(2)_LOV: active cost centres
    select count(*) into l from ac_master where account_number = p_account and nvl(account_status, 0) = 1;
    if l = 0 then
      fail(-20138, 'الحساب ليس حساب فرعى', 'The account is not a sub account');
    end if;
    if l_group != 0 then
      select count(*) into l from ac_password_master
       where account_number = p_account and password_number = l_group and company_code = ctx_company;
      if l = 0 then
        fail(-20139, 'لا توجد صلاحية للحساب', 'You don''t have permission on this account');
      end if;
    end if;
    if p_cost is not null then
      select count(*) into l from ac_cost_centers where cost_code = p_cost and cost_status = 1;
      if l = 0 then fail(-20140, 'مركز التكلفة 1 ليس مركز فرعى', 'Cost centre 1 is not a sub cost centre'); end if;
    end if;
    if p_cost2 is not null then
      select count(*) into l from ac_cost_centers2 where cost_code = p_cost2 and cost_status = 1;
      if l = 0 then fail(-20141, 'مركز التكلفة 2 ليس مركز فرعى', 'Cost centre 2 is not a sub cost centre'); end if;
    end if;
  end budget_mast_row;

  procedure budget_det_row (p_period in number) is
  begin
    if p_period < 0 then
      fail(-20142, 'كود الفترة لا يمكن أن يكون أقل من الصفر', 'The period code cannot be negative');
    end if;
  end budget_det_row;

  procedure budget_after_save (p_est_code in varchar2) is
    l number;
    l_code number := num(p_est_code);
  begin
    select count(*) into l from (
      select account_number from ac_estimate_mast where est_code = l_code
       group by account_number, nvl(cost_code, -1), nvl(cost_code2, -1) having count(*) > 1);
    if l > 0 then
      fail(-20143, 'سجل مكرر', 'Duplicate record');
    end if;
    select count(*) into l from (
      select mast_serial from ac_estimate_det where est_code = l_code
       group by mast_serial, period_code having count(*) > 1);
    if l > 0 then
      fail(-20144, 'رقم الحساب مكرر مع الفتره', 'The account is repeated for the same period');
    end if;
  end budget_after_save;

  -- deleting a whole budget (document DELETE) removes the period values of each account line first
  procedure budget_mast_before_delete (p_est_code in number, p_serial in number) is
  begin
    if v('REQUEST') = 'DELETE' then
      delete from ac_estimate_det where est_code = p_est_code and mast_serial = p_serial;
    end if;
  end budget_mast_before_delete;

  -- COPY_BUDGET (p_with_actual = 0) and ITEM88 "عمل موازنة جديده مقارنة مع الفعلي" (p_with_actual = 1)
  function copy_budget (p_rowid in varchar2, p_with_actual in number) return varchar2 is
    l_old    number;
    l_new    number;
    l_actual number;
    l_rowid  rowid;
    l_name   ac_estimate_codes.est_name%type;
    l_name_e ac_estimate_codes.est_name_e%type;
  begin
    begin
      select est_code into l_old from ac_estimate_codes where rowid = chartorowid(p_rowid);
    exception when no_data_found then
      fail(-20145, 'يجب حفظ السجل اولا', 'Save the record first');
    end;
    select nvl(max(est_code), 0) + 1 into l_new from ac_estimate_codes;
    select est_name, est_name_e into l_name, l_name_e from ac_estimate_codes where est_code = l_old;
    insert into ac_estimate_codes (est_code, est_name, est_name_e, create_company_code, create_password_number, create_user_code,
                                   create_date, update_company_code, update_password_number, update_user_code, update_date)
    values (l_new, l_name, l_name_e, ctx_company, ctx_group, ctx_user, sysdate, ctx_company, ctx_group, ctx_user, sysdate)
    returning rowid into l_rowid;
    if nvl(p_with_actual, 0) = 0 then
      insert into ac_estimate_mast (est_code, serial, account_number, cost_code, cost_code2)
      select l_new, serial, account_number, cost_code, cost_code2 from ac_estimate_mast where est_code = l_old;
      insert into ac_estimate_det (est_code, mast_serial, serial, period_code, value)
      select l_new, mast_serial, serial, period_code, value from ac_estimate_det where est_code = l_old;
      g_msg := msg('تم نسخ الميزانية برقم ', 'Budget copied as number ') || l_new;
    else
      for m in (select * from ac_estimate_mast where est_code = l_old order by serial) loop
        insert into ac_estimate_mast (est_code, serial, account_number, cost_code, cost_code2)
        values (l_new, m.serial, m.account_number, m.cost_code, m.cost_code2);
        for d in (select * from ac_estimate_det where est_code = l_old and mast_serial = m.serial order by serial) loop
          select sum(dd.value * mm.rate) into l_actual
            from ac_yearly_trn_det dd, ac_yearly_trn mm, ac_estimate_periods p
           where mm.entry_year = dd.entry_year and mm.entry_type = dd.entry_type and mm.entry_no = dd.entry_no
             and dd.entry_date between p.from_date and p.till_date and p.period_code = d.period_code
             and dd.account_number = m.account_number
             and nvl(dd.cost_code, 0) = nvl(m.cost_code, 0) and nvl(dd.cost_code2, 0) = nvl(m.cost_code2, 0);
          insert into ac_estimate_det (est_code, mast_serial, serial, period_code, value)
          values (l_new, m.serial, d.serial, d.period_code, (nvl(d.value, 0) + nvl(l_actual, 0)) / 2);
        end loop;
      end loop;
      g_msg := msg('تم عمل الميزانية برقم ', 'Budget created as number ') || l_new;
    end if;
    return rowidtochar(l_rowid);
  end copy_budget;

  -- ================================================================== ACMNUCD
  procedure final_account_after_save (p_menu in varchar2) is
    l_menu number := num(p_menu);
    l      number;
  begin
    -- "رقم الحساب و مركزى التكلفة لا يمكن ان يتم تكرارهم" (the four COUNT(1) cases of the form: null-safe)
    select count(*) into l from (
      select account_number from ac_final_account where menu_code = l_menu and account_number is not null
       group by account_number, nvl(cost_code, -1), nvl(cost_code2, -1) having count(*) > 1);
    if l > 0 then
      fail(-20146, 'رقم الحساب و مركزى التكلفة لا يمكن ان يتم تكرارهم', 'The account and cost centres cannot be repeated');
    end if;
    -- NOM_LOV / DENOM_LOV: a previous line (SER < this SER) of the same statement with POSITION = 0, not the other one
    select count(*) into l from ac_final_account f
     where f.menu_code = l_menu
       and ((f.nom is not null and (f.nom = nvl(f.denom, -1) or not exists (
              select 1 from ac_final_account r where r.menu_code = f.menu_code and r.ser = f.nom and r.position = 0 and r.ser < f.ser)))
         or (f.denom is not null and not exists (
              select 1 from ac_final_account r where r.menu_code = f.menu_code and r.ser = f.denom and r.position = 0 and r.ser < f.ser)));
    if l > 0 then
      fail(-20147, 'البسط والمقام يجب أن يكونا من السطور السابقة ذات الاجماليات صفر', 'Numerator / denominator must be earlier lines with totals 0');
    end if;
  end final_account_after_save;

  procedure final_account_refs is
    l number;
  begin
    select count(*) into l from ac_final_account f
     where (f.nom is not null and not exists (select 1 from ac_final_account r where r.menu_code = f.menu_code and r.ser = f.nom))
        or (f.denom is not null and not exists (select 1 from ac_final_account r where r.menu_code = f.menu_code and r.ser = f.denom));
    if l > 0 then
      fail(-20148, 'لايمكن التعديل او الحذف لاشتراكها في باسط او مقام', 'The line is used as a numerator or denominator');
    end if;
  end final_account_refs;

  -- ================================================================== AC_DUPENTRY_DEF
  function next_periodical_serial return number is
    l number;
  begin
    select nvl(max(nvl(serial, 1)), 1) + 1 into l from ac_periodical_voc;
    return l;
  end next_periodical_serial;

  procedure periodical_row (p_inserting in boolean, p_old_year in number, p_old_type in number, p_old_no in number,
                            p_year in number, p_type in number, p_no in number,
                            p_desc in out varchar2, p_desc_e in out varchar2) is
    l       number;
    l_desc  varchar2(4000);
    l_desce varchar2(4000);
    l_group number := nvl(ctx_group, 0);
  begin
    -- the entry is chosen from the lists of values when the record is created or the entry is changed
    if not p_inserting and p_year = p_old_year and p_type = p_old_type and p_no = p_old_no then
      return;
    end if;
    -- ENTRY_NO LOV: posted entries of the company
    select count(*), max(entry_desc), max(entry_desc_e) into l, l_desc, l_desce from ac_yearly_trn
     where entry_year = p_year and entry_type = p_type and entry_no = p_no and create_company_code = ctx_company;
    if l = 0 then
      fail(-20149, 'رقم القيد غير موجود فى القيود المرحلة', 'The entry is not a posted entry of this company');
    end if;
    -- ENTRY_TYPE LOV: journal types of the group (AC_PASSWORD_ENTRY), all for group 0
    if l_group != 0 then
      select count(*) into l from ac_password_entry
       where entry_year = p_year and entry_type = p_type and password_number = l_group and company_code = ctx_company;
      if l = 0 then
        fail(-20150, 'لا توجد صلاحية على نوع الحركة', 'You don''t have permission on this journal type');
      end if;
    end if;
    if p_inserting then
      select count(*) into l from ac_periodical_voc where entry_year = p_year and entry_type = p_type and entry_no = p_no;
      if l > 0 then
        fail(-20151, 'هذا القيد موجود فى القيود الدوريه بالفعل', 'This entry is already in the periodical entries');
      end if;
    end if;
    p_desc := nvl(p_desc, l_desc);
    p_desc_e := nvl(p_desc_e, l_desce);
  end periodical_row;

  -- ================================================================== AC_QUERYBEFORE / AC_QUERYAFTER (GET_BAL)
  function account_balance (p_account in number, p_cost in number, p_cost2 in number, p_date in date,
                            p_unposted in number) return number is
    l1 number; l2 number := 0; l3 number;
  begin
    select nvl(sum(nvl(a.value, 0)), 0) into l1
      from ac_yearly_trn_det a, ac_yearly_trn b
     where a.entry_year = b.entry_year and a.entry_type = b.entry_type and a.entry_no = b.entry_no
       and a.account_number = p_account
       and (nvl(a.cost_code, 0) = nvl(p_cost, 0) or p_cost is null)
       and (nvl(a.cost_code2, 0) = nvl(p_cost2, 0) or p_cost2 is null)
       and b.entry_date <= p_date;
    if nvl(p_unposted, 0) = 1 then
      select nvl(sum(nvl(a.value, 0)), 0) into l2
        from ac_daily_trn_det a, ac_daily_trn b
       where a.entry_year = b.entry_year and a.entry_type = b.entry_type and a.entry_no = b.entry_no
         and a.account_number = p_account
         and (nvl(a.cost_code, 0) = nvl(p_cost, 0) or p_cost is null)
         and (nvl(a.cost_code2, 0) = nvl(p_cost2, 0) or p_cost2 is null)
         and b.entry_date <= p_date;
    end if;
    select nvl(sum(nvl(value, 0)), 0) into l3
      from ac_opening_balance_det
     where account_number = p_account
       and (nvl(cost_code, 0) = nvl(p_cost, 0) or p_cost is null)
       and (nvl(cost_code2, 0) = nvl(p_cost2, 0) or p_cost2 is null);
    return l1 + l2 + l3;
  end account_balance;

  procedure query_balance (p_account in number, p_cost in number, p_cost2 in number, p_date in date) is
    l number;
    l_group number := nvl(ctx_group, 0);
  begin
    if p_account is null then
      fail(-20152, 'يجب إدخال رقم الحساب', 'The account number is required');
    end if;
    if p_date is null then
      fail(-20153, 'يجب إدخال التاريخ', 'The date is required');
    end if;
    -- ACCOUNT_LOV: sub accounts granted to the group (directly or under a granted main account)
    select count(*) into l from ac_master where account_number = p_account and account_status = 1;
    if l = 0 then
      fail(-20154, 'الحساب ليس حساب فرعى', 'The account is not a sub account');
    end if;
    if l_group != 0 then
      select count(*) into l from ac_password_master p2
       where p2.password_number = l_group and p2.company_code = ctx_company
         and rpad(substr(to_char(p2.account_number), 1, p2.account_end_pos), 12, '0')
           = rpad(substr(to_char(p_account), 1, p2.account_end_pos), 12, '0');
      if l = 0 then
        fail(-20155, 'لا توجد صلاحية للحساب', 'You don''t have permission on this account');
      end if;
    end if;
    g_msg := null;
  end query_balance;

  -- ================================================================== ACYRTR
  function user_name (p_user in number) return varchar2 is
    l    varchar2(400);
    l_en varchar2(1) := case when is_en then 'Y' else 'N' end;
  begin
    if p_user is null then return null; end if;
    select nvl(case when l_en = 'Y' then users_name_e end, users_name) into l from users where users_code = p_user;
    return p_user || ' - ' || l;
  exception when no_data_found then return to_char(p_user);
  end user_name;

  -- POST-QUERY of ACYRTR: journal name, debit / credit totals, the posted document of the sub-system, users
  function entry_info (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    h ac_yearly_trn%rowtype;
    l_d number; l_c number;
    l_t number; l_s number;
    l_txt varchar2(400);
    l_en  varchar2(1) := case when is_en then 'Y' else 'N' end;
  begin
    select * into h from ac_yearly_trn where rowid = chartorowid(p_rowid);
    if p_what = 'TYPE' then
      select max(nvl(case when l_en = 'Y' then entry_desc_e end, entry_desc)) into l_txt
        from ac_trn_codes where entry_year = h.entry_year and entry_type = h.entry_type;
      return h.entry_type || ' - ' || l_txt;
    elsif p_what in ('DEBIT', 'CREDIT', 'DIFF') then
      select nvl(sum(case when value > 0 then value end), 0), nvl(sum(case when value < 0 then -value end), 0)
        into l_d, l_c from ac_yearly_trn_det
       where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
      return fmt(case p_what when 'DEBIT' then l_d when 'CREDIT' then l_c else l_d - l_c end);
    elsif p_what = 'SOURCE' then
      if h.post_system = 3 then
        select max(trns_type_code), max(trns_serial) into l_t, l_s from st_trns_mast
         where post_flag = 1 and ac_entry_year = h.entry_year and ac_entry_type = h.entry_type and ac_entry_no = h.entry_no;
      elsif h.post_system = 4 then
        select max(trns_id), max(trns_serial) into l_t, l_s from ar_maintrns
         where post_flag = 1 and acc_year = h.entry_year and acc_type = h.entry_type and acc_no = h.entry_no;
      elsif h.post_system = 5 then
        select max(trns_id), max(trns_serial) into l_t, l_s from vn_maintrns
         where post_flag = 1 and acc_year = h.entry_year and acc_type = h.entry_type and acc_no = h.entry_no;
      elsif h.post_system = 15 then
        select max(trns_type_code), max(trns_serial) into l_t, l_s from rp_trns_mast
         where post_flag = 1 and post_entry_year = h.entry_year and post_entry_type = h.entry_type and post_entry_no = h.entry_no;
      end if;
      select max(nvl(case when l_en = 'Y' then system_desc_e end, system_desc_a)) into l_txt
        from sys_systems where system_number = h.post_system;
      return l_txt || case when l_t is not null then ' : ' || l_t || ' / ' || l_s end;
    elsif p_what = 'CREATED' then
      return user_name(h.create_user_code) || ' ' || to_char(h.create_date, 'DD/MM/YYYY');
    elsif p_what = 'UPDATED' then
      return user_name(h.update_user_code) || ' ' || to_char(h.update_date, 'DD/MM/YYYY');
    elsif p_what = 'POSTED' then
      return user_name(h.post_user);
    end if;
    return null;
  exception when no_data_found then return null;
  end entry_info;

  -- WHEN-NEW-FORM-INSTANCE of ACYRTR: POST_VOUCHER enabled for group 0 (or none), else GROUP_COMPANY.POST_FLAG = 1 and
  -- FILE_PASSWORD system 1 / file 72 (شاشة الغاء الترحيل) with INSERT, DELETE, UPDATE and QUERY flags = 1
  function can_cancel_entry (p_rowid in varchar2) return varchar2 is
    l_n    number;
    l_flag number;
  begin
    select count(*) into l_n from ac_yearly_trn where rowid = chartorowid(p_rowid);
    if l_n = 0 then
      return 'N';
    end if;
    if nvl(ctx_group, 0) = 0 then
      return 'Y';
    end if;
    select count(*) into l_n from file_password
     where system_number = 1 and file_serial = 72 and users_code = ctx_user
       and insert_flag = 1 and delete_flag = 1 and update_flag = 1 and query_flag = 1;
    select nvl(max(post_flag), 0) into l_flag from group_company
     where company_code = ctx_company and password_number = ctx_group;
    return case when l_flag = 1 and l_n >= 1 then 'Y' else 'N' end;
  exception
    when others then
      return 'N';
  end can_cancel_entry;

  -- POST_VOUCHER WHEN-BUTTON-PRESSED: entry in a closed period (AC_BASIC.CLOSE_DATE >= entry date) refused; an entry posted by
  -- another system refused ('هذا القيد مرحل من نظام ... لا يمكن الغاء الترحيل'); then TEST_AND_UPDATE moves the entry back to the
  -- daily tables (the ACCUPDT logic, APP_PROC_GL.cancel_posting for this one entry) and the form is cleared
  function cancel_entry (p_rowid in varchar2) return varchar2 is
    h       ac_yearly_trn%rowtype;
    l_close date;
    l_sys   varchar2(400);
    l_en    varchar2(1) := case when is_en then 'Y' else 'N' end;
  begin
    g_msg := null;
    begin
      select * into h from ac_yearly_trn where rowid = chartorowid(p_rowid);
    exception
      when no_data_found or sys_invalid_rowid or value_error then
        fail(-20173, 'القيد غير موجود', 'The entry does not exist');
    end;
    if can_cancel_entry(p_rowid) = 'N' then
      fail(-20174, 'ليس لديك صلاحية إلغاء الترحيل', 'You have no permission to cancel the posting');
    end if;
    select max(close_date) into l_close from ac_basic where company_code = ctx_company;
    if h.entry_date <= l_close then
      fail(-20169, 'لا يمكن ترحيل الحركة لأنها تقع فى فترة مقفلة', 'You canot post the transaction  becouse it lies in a closed Period ');
    end if;
    if nvl(h.post_system, 0) != 1 then
      select max(case when l_en = 'Y' then system_desc_e else system_desc_a end) into l_sys
        from sys_systems where system_number = h.post_system;
      fail(-20175, ' هذا القيد مرحل من نظام ' || l_sys || ' لا يمكن الغاء الترحيل ',
                   'This Voucher Form System ' || l_sys || ' Can Delete from Here');
    end if;
    app_proc_gl.cancel_posting(p_from_year => h.entry_year, p_to_year => h.entry_year,
                               p_from_type => h.entry_type, p_to_type => h.entry_type,
                               p_from_no => h.entry_no, p_to_no => h.entry_no,
                               p_company_code => ctx_company, p_user_code => ctx_user, p_password_number => ctx_group);
    g_msg := app_proc_gl.last_message;
    -- legacy CLEAR_FORM: the entry left the posted tables, the page opens empty
    if v('APP_ID') is not null and v('APP_PAGE_ID') is not null then
      apex_util.set_session_state('P' || v('APP_PAGE_ID') || '_ROWID', null);
    end if;
    return null;
  end cancel_entry;

  -- ================================================================== AC_DISTP
  function next_distp_det_serial (p_dis_serial in number) return number is
    l number;
  begin
    select nvl(max(det_serial), 0) + 1 into l from ac_distp_det where dis_serial = p_dis_serial;
    return l;
  end next_distp_det_serial;

  function distp_posted (p_dis_serial in number) return boolean is
    l number;
  begin
    select nvl(max(post_flag), 0) into l from ac_distp where dis_serial = p_dis_serial;
    return l = 1;
  end distp_posted;

  -- GET_BAL: balance of the account (or of every expense sub account when "مصروف" is chosen) for the source cost
  -- centre up to the distribution date (posted lines + opening balances)
  function distp_balance (p_dis_serial in number, p_cost_code in number) return number is
    h       ac_distp%rowtype;
    l_out   number;
    l_total number := 0;
    l1 number; l3 number;
  begin
    select * into h from ac_distp where dis_serial = p_dis_serial;
    if h.acc_number is not null then
      select nvl(sum(nvl(a.value, 0)), 0) into l1
        from ac_yearly_trn_det a, ac_yearly_trn b
       where a.entry_year = b.entry_year and a.entry_type = b.entry_type and a.entry_no = b.entry_no
         and a.account_number = h.acc_number and nvl(a.cost_code, 0) = nvl(p_cost_code, 0) and b.entry_date <= h.dis_date;
      select nvl(sum(nvl(value, 0)), 0) into l3 from ac_opening_balance_det
       where account_number = h.acc_number and nvl(cost_code, 0) = nvl(p_cost_code, 0);
      return l1 + l3;
    end if;
    -- legacy: TO_NUMBER(SUBSTR(ACCOUNT_NUMBER, 1, 1)) = AC_BASIC.OUTCOME1_ACCT (kept as it was)
    select max(outcome1_acct) into l_out from ac_basic where company_code = ctx_company;
    for r in (select account_number from ac_master where account_status = 1 and to_number(substr(account_number, 1, 1)) = l_out) loop
      select nvl(sum(nvl(a.value, 0)), 0) into l1
        from ac_yearly_trn_det a, ac_yearly_trn b
       where a.entry_year = b.entry_year and a.entry_type = b.entry_type and a.entry_no = b.entry_no
         and a.account_number = r.account_number and nvl(a.cost_code, 0) = nvl(p_cost_code, 0) and b.entry_date <= h.dis_date;
      select nvl(sum(nvl(value, 0)), 0) into l3 from ac_opening_balance_det
       where account_number = r.account_number and nvl(cost_code, 0) = nvl(p_cost_code, 0);
      l_total := l_total + l1 + l3;
    end loop;
    return l_total;
  end distp_balance;

  procedure distp_from_row (p_dis_serial in number, p_cost_code in number, p_acc_value in out number) is
  begin
    p_acc_value := distp_balance(p_dis_serial, p_cost_code);
    if nvl(p_acc_value, 0) = 0 then
      fail(-20156, 'رصيد مركذ التكلفة لهذا الحساب صفر', 'Cost Center balance for this account is zero');
    end if;
  end distp_from_row;

  function distp_totals (p_dis_serial in number, p_what in varchar2) return number is
    l number;
  begin
    if p_what = 'FROM' then
      select nvl(sum(acc_value), 0) into l from ac_distp_from where dis_serial = p_dis_serial;
    elsif p_what = 'DET' then
      select nvl(sum(det_val), 0) into l from ac_distp_det where dis_serial = p_dis_serial;
    else
      select sum(det_prcnt) into l from ac_distp_det where dis_serial = p_dis_serial;
    end if;
    return l;
  end distp_totals;

  -- DET_PRCNT / DET_VAL WHEN-VALIDATE-ITEM: the value follows the percentage of the source total and vice versa
  procedure distp_det_row (p_inserting in boolean, p_dis_serial in number, p_old_prcnt in number, p_old_val in number,
                           p_prcnt in out number, p_val in out number) is
    l_tot number;
  begin
    if distp_posted(p_dis_serial) then
      fail(-20157, 'لا يمكن تعديل حركة توزيع مرحلة', 'A posted distribution cannot be changed');
    end if;
    if g_no_derive then return; end if;            -- نسب ثابتة sets both items itself
    l_tot := distp_totals(p_dis_serial, 'FROM');
    if p_inserting then
      if p_val is null and p_prcnt is not null then
        p_val := l_tot * p_prcnt / 100;
      elsif p_prcnt is null and p_val is not null and l_tot != 0 then
        p_prcnt := p_val * 100 / l_tot;
      end if;
    else
      -- the item the user changed drives the other one; both changed together (نسب ثابتة) are kept as given
      if nvl(p_prcnt, -1) != nvl(p_old_prcnt, -1) and nvl(p_val, -1) = nvl(p_old_val, -1) and p_prcnt is not null then
        p_val := l_tot * p_prcnt / 100;
      elsif nvl(p_val, -1) != nvl(p_old_val, -1) and nvl(p_prcnt, -1) = nvl(p_old_prcnt, -1) and p_val is not null and l_tot != 0 then
        p_prcnt := p_val * 100 / l_tot;
      end if;
    end if;
  end distp_det_row;

  procedure distp_after_save (p_rowid in varchar2) is
    l_ser number;
    l_nf  number;
    l_nd  number;
    l_np  number;
    l_pct number;
  begin
    select dis_serial into l_ser from ac_distp where rowid = chartorowid(p_rowid);
    select count(*) into l_nf from ac_distp_from where dis_serial = l_ser;
    select count(*) into l_nd from ac_distp_det where dis_serial = l_ser;
    if l_nf + l_nd = 0 then return; end if;
    -- PRE-INSERT also checked the percentage total of the form items (decimals); DET_PRCNT is stored as an integer
    -- (NUMBER(6,0)), so the stored percentages are only checked when every line has one and the values do not match
    l_pct := distp_totals(l_ser, 'PRCNT');
    select count(det_prcnt) into l_np from ac_distp_det where dis_serial = l_ser;
    if round(distp_totals(l_ser, 'DET'), 2) != round(distp_totals(l_ser, 'FROM'), 2) and l_pct is not null
       and l_pct != 100 and l_nd = l_np then
      fail(-20158, 'لا بد ان يكون مجموع النسب مساوي 100', 'Prcnt Must Be Equal 1OO');
    end if;
    if round(distp_totals(l_ser, 'DET'), 2) != round(distp_totals(l_ser, 'FROM'), 2) then
      fail(-20159, 'لا بد ان يكون مجموع مبالغ المراكز الخدمية مساوي لمبلغ مركز التكلفة الإيرادية', 'Detail Values Must Be Equal Tha Master Value');
    end if;
  exception when no_data_found then null;
  end distp_after_save;

  -- DIST_BUT "نسب ثابتة": equal shares over the target cost centres (the last one takes the rest of 100 %)
  function distp_equal (p_rowid in varchar2) return varchar2 is
    l_ser number;
    l_x   number;
    l_tot number;
    l_sum number := 0;
    l_i   number := 0;
    l_fx  number;
  begin
    select dis_serial into l_ser from ac_distp where rowid = chartorowid(p_rowid);
    if distp_posted(l_ser) then
      fail(-20157, 'لا يمكن تعديل حركة توزيع مرحلة', 'A posted distribution cannot be changed');
    end if;
    select count(*) into l_x from ac_distp_det where dis_serial = l_ser;
    if l_x = 0 then
      fail(-20160, 'لا بد من إدخال مراكز التكلفة الإيرادية أولا', 'You Must Inter Data In The Detail Cost Centers First');
    end if;
    l_tot := distp_totals(l_ser, 'FROM');
    l_fx := 100 / l_x;
    g_no_derive := true;
    for r in (select rowid rid from ac_distp_det where dis_serial = l_ser order by det_serial) loop
      l_i := l_i + 1;
      if l_i < l_x then
        update ac_distp_det set det_prcnt = l_fx, det_val = l_tot / l_x where rowid = r.rid;
        l_sum := l_sum + l_fx;
      else
        update ac_distp_det set det_prcnt = 100 - l_sum, det_val = l_tot / l_x where rowid = r.rid;
      end if;
    end loop;
    g_no_derive := false;
    g_msg := msg('تم توزيع النسب بالتساوي', 'Equal ratios applied');
    return p_rowid;
  exception
    when no_data_found then
      g_no_derive := false;
      fail(-20145, 'يجب حفظ السجل اولا', 'Save the record first');
    when others then
      g_no_derive := false;
      raise;
  end distp_equal;

  -- GET_SERIAL of AC_DISTP: yearly journals take AC_TRN_CODES.LAST_SERIAL + 1 (and store it), monthly journals
  -- MM + next 4-digit number of the month (max of daily and posted entries) and store it as LAST_SERIAL
  function distp_serial (p_year in number, p_type in number, p_date in date) return number is
    l_serial number;
    l_flag   number;
    l_month  number := to_number(to_char(p_date, 'MM'));
    l_d      number;
    l_y      number;
    l_new    number;
  begin
    begin
      select last_serial, nvl(serial_flag, 0) into l_serial, l_flag from ac_trn_codes
       where entry_year = p_year and entry_type = p_type for update;
    exception when no_data_found then
      fail(-20161, 'نوع حركة التوزيع غير معرف في سنة القيد', 'The distribution journal type is not defined for the entry year');
    end;
    if l_flag = 0 then
      l_new := nvl(l_serial, 0) + 1;
    else
      select nvl(max(entry_no), 0) into l_d from ac_daily_trn
       where entry_year = p_year and entry_type = p_type and substr(lpad(to_char(entry_no), 6, '0'), 1, 2) = lpad(to_char(l_month), 2, '0');
      select nvl(max(entry_no), 0) into l_y from ac_yearly_trn
       where entry_year = p_year and entry_type = p_type and substr(lpad(to_char(entry_no), 6, '0'), 1, 2) = lpad(to_char(l_month), 2, '0');
      l_serial := greatest(l_d, l_y);
      l_new := to_number(lpad(to_char(l_month), 2, '0') || substr(lpad(to_char(l_serial + 1), 6, '0'), 3, 4));
    end if;
    update ac_trn_codes set last_serial = l_new where entry_year = p_year and entry_type = p_type;
    return l_new;
  end distp_serial;

  function distp_post (p_rowid in varchar2) return varchar2 is
    h        ac_distp%rowtype;
    l_type   number;
    l_close  date;
    l_year   number;
    l_no     number;
    l_seq    number := 1;
    l_total  number;
    l_name   varchar2(4000);
    l_name_e varchar2(4000);
    l        number;
  begin
    begin
      select * into h from ac_distp where rowid = chartorowid(p_rowid) for update;
    exception when no_data_found then
      fail(-20145, 'يجب حفظ السجل اولا', 'Save the record first');
    end;
    if nvl(h.post_flag, 0) = 1 then
      fail(-20162, 'حركة التوزيع مرحلة بالفعل', 'The distribution is already posted');
    end if;
    select count(*) into l from ac_distp_from where dis_serial = h.dis_serial;
    if l = 0 then
      fail(-20163, 'لا بد من إدخال مراكز التكلفة المصدر أولا', 'You Must Inter Data In The Detail Cost Centers First');
    end if;
    select count(*) into l from ac_distp_det where dis_serial = h.dis_serial;
    if l = 0 then
      fail(-20164, 'لا بد من إدخال مراكز التكلفة التي سيوزع عليها أولا', 'You Must Inter Data In The Detail Cost Centers First');
    end if;
    select max(distp_entry), max(close_date) into l_type, l_close from ac_basic where company_code = ctx_company;
    if l_type is null then
      fail(-20165, 'لا بد من تعريف رقم حركة التوزيع في مؤشرات النظام', 'You Must Define Un Entry Number In System Parameters');
    end if;
    if h.dis_date <= l_close then
      fail(-20166, 'لا يمكن ترحيل الحركة لأنها تقع فى فترة مقفلة', 'You canot post the transaction  becouse it lies in a closed Period ');
    end if;
    if h.acc_number is null then
      fail(-20167, 'يجب إدخال رقم الحساب قبل الترحيل', 'Enter the account number before posting');   -- legacy failed on the NOT NULL line account
    end if;
    select account_name, account_name_e into l_name, l_name_e from ac_master where account_number = h.acc_number;
    l_year := to_number(to_char(h.dis_date, 'YYYY'));
    l_no := distp_serial(l_year, l_type, h.dis_date);
    l_total := distp_totals(h.dis_serial, 'FROM');
    insert into ac_yearly_trn (entry_year, entry_type, entry_no, doc_no, entry_date, entry_desc, entry_desc_e, currency_code, rate,
                               entry_total, memo, memo_e, create_company_code, create_password_number, create_user_code, create_date)
    values (l_year, l_type, l_no, null, h.dis_date, h.desc_a, h.desc_e, 1, 1, l_total, null, null,
            ctx_company, ctx_group, ctx_user, sysdate);
    -- the source cost centres are credited / debited back ...
    for f in (select * from ac_distp_from where dis_serial = h.dis_serial order by det_serial) loop
      insert into ac_yearly_trn_det (entry_year, entry_type, entry_no, seq, account_number, entry_date, entry_desc, entry_desc_e,
                                     value, cost_code, create_company_code, create_password_number, create_user_code, create_date,
                                     auto_trns_flag)
      values (l_year, l_type, l_no, l_seq, h.acc_number, h.dis_date, l_name, l_name_e,
              case sign(f.acc_value) when 1 then -1 * abs(f.acc_value) when -1 then abs(f.acc_value) end, f.cost_code,
              ctx_company, ctx_group, ctx_user, sysdate, 0);
      l_seq := l_seq + 1;
    end loop;
    -- ... and the target cost centres take their shares with the sign of the balance
    for d in (select * from ac_distp_det where dis_serial = h.dis_serial order by det_serial) loop
      insert into ac_yearly_trn_det (entry_year, entry_type, entry_no, seq, account_number, entry_date, entry_desc, entry_desc_e,
                                     value, cost_code, create_company_code, create_password_number, create_user_code, create_date,
                                     auto_trns_flag)
      values (l_year, l_type, l_no, l_seq, h.acc_number, h.dis_date, l_name, l_name_e,
              case sign(l_total) when -1 then -1 * abs(d.det_val) when 1 then abs(d.det_val) end, d.cost_code,
              ctx_company, ctx_group, ctx_user, sysdate, 0);
      l_seq := l_seq + 1;
    end loop;
    update ac_distp set post_flag = 1, entry_year = l_year, entry_type = l_type, entry_no = l_no where rowid = chartorowid(p_rowid);
    g_msg := msg('تم ترحيل حركة التوزيع بنجاح', 'The Trns Is Posted') || ' (' || l_year || '/' || l_type || '/' || l_no || ')';
    return p_rowid;
  end distp_post;

  function distp_unpost (p_rowid in varchar2) return varchar2 is
    h       ac_distp%rowtype;
    l_close date;
  begin
    begin
      select * into h from ac_distp where rowid = chartorowid(p_rowid) for update;
    exception when no_data_found then
      fail(-20145, 'يجب حفظ السجل اولا', 'Save the record first');
    end;
    if nvl(h.post_flag, 0) != 1 then
      fail(-20168, 'حركة التوزيع غير مرحلة', 'The distribution is not posted');
    end if;
    select max(close_date) into l_close from ac_basic where company_code = ctx_company;
    if h.dis_date <= l_close then
      fail(-20169, 'لا يمكن إلغاء ترحيل الحركة لأنها تقع فى فترة مقفلة', 'You canot UNpost the transaction  becouse it lies in a closed Period ');
    end if;
    delete from ac_daily_trn_det where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
    delete from ac_daily_trn where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
    delete from ac_yearly_trn_det where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
    delete from ac_yearly_trn where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
    update ac_distp set post_flag = 0, entry_year = null, entry_type = null, entry_no = null where rowid = chartorowid(p_rowid);
    g_msg := msg('تم إلغاء ترحيل حركة التوزيع بنجاح', 'The Trns Is Canceled Posted');
    return p_rowid;
  end distp_unpost;

  procedure distp_before_delete (p_post_flag in number) is
  begin
    if nvl(p_post_flag, 0) = 1 then                -- :old value: AC_DISTP cannot be read in its own row trigger
      fail(-20170, 'لا يمكن حذف حركة توزيع مرحلة', 'A posted distribution cannot be deleted');
    end if;
  end distp_before_delete;

  procedure distp_det_before_delete (p_dis_serial in number) is
  begin
    if distp_posted(p_dis_serial) then
      fail(-20157, 'لا يمكن تعديل حركة توزيع مرحلة', 'A posted distribution cannot be changed');
    end if;
  end distp_det_before_delete;

  -- ================================================================== ACBENFTAX
  procedure benf_tax_row (p_tax_no in varchar2) is
  begin
    if p_tax_no is not null and not regexp_like(p_tax_no, '^[0-9]{15}$') then
      fail(-20171, 'خطأ برقم الضريبة .. لابد انيكون مكون من 15 رقم', 'The VAT number must have 15 digits');
    end if;
  end benf_tax_row;

  procedure benf_tax_unique is
    l number;
  begin
    select count(*) into l from (select tax_no from ac_benf_tax where tax_no is not null group by tax_no having count(*) > 1);
    if l > 0 then
      fail(-20172, 'الرقم الضريبي مكرر', 'Duplicate VAT number');
    end if;
  end benf_tax_unique;

  -- ================================================================== SUB_LG_COMPARE
  -- GET_ACCOUNT_BALANCE: posted lines of the account without the closing entries
  function gl_balance (p_account in number) return number is
    l number;
  begin
    select sum(value) into l from ac_yearly_trn_det
     where account_number = p_account
       and (entry_type, entry_year, entry_no) not in (select entry_type, entry_year, entry_no from ac_yearly_trn where nvl(close_flag, 0) = 1);
    return nvl(l, 0);
  end gl_balance;

  -- GET_SUPP_BALANCE: suppliers whose number starts with SUPP_BEGIN, signed by VN_TRNSTYPE.EFFECT, in local currency
  function supp_balance (p_prefix in number) return number is
    l number;
  begin
    select sum(decode(t.effect, 0, -1, 1) * nvl(m.total_value, 0) * m.currency_rate) into l
      from vn_maintrns m, vn_trnstype t
     where substr(m.supplier_id, 1, length(p_prefix)) = to_char(p_prefix) and m.trns_id = t.id;
    return nvl(l, 0);
  end supp_balance;

  function sub_ledger_text (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    s   sub_lg_compare%rowtype;
    l_g number;
    l_s number;
  begin
    select * into s from sub_lg_compare where rowid = chartorowid(p_rowid);
    l_g := gl_balance(s.account_number);
    if s.post_system = 5 and s.supp_begin is not null then
      l_s := supp_balance(s.supp_begin);
    end if;
    if p_what = 'GL' then
      return fmt(abs(l_g)) || ' ' || side_text(l_g);
    elsif p_what = 'SUB' then
      return case when l_s is null then msg('غير موجود', 'not available') else fmt(abs(l_s)) || ' ' || side_text(l_s) end;
    elsif p_what = 'DIFF' then
      return case when l_s is not null then fmt(l_g - l_s) end;
    end if;
    return null;
  exception when no_data_found then return null;
  end sub_ledger_text;

end app_rules3_gl;
/
show errors package body app_rules3_gl

-- =====================================================================================================
-- Hooks the rules mechanism does not have (APEX sessions only, like the generated APPX_ triggers)
-- =====================================================================================================

-- AC_MASTER_STRUCT: structure locked while accounts exist; levels deleted from the bottom up
create or replace trigger app_rules3_gl_chrstr_del
for delete on ac_chart_structures
compound trigger
  before each row is
  begin
    if v('APP_ID') is not null then
      app_rules3_gl.struct_before_delete('AC');
    end if;
  end before each row;
  after statement is
  begin
    if v('APP_ID') is not null then
      app_rules3_gl.struct_after_delete('AC');
    end if;
  end after statement;
end app_rules3_gl_chrstr_del;
/
show errors trigger app_rules3_gl_chrstr_del

-- AC_COST_STRUCT1 / AC_COST_STRUCT2
create or replace trigger app_rules3_gl_coststr_del
for delete on ac_cost_strctures
compound trigger
  type t_nos is table of number index by pls_integer;
  g_nos t_nos;
  before statement is
  begin
    g_nos.delete;
  end before statement;
  before each row is
  begin
    if v('APP_ID') is not null then
      app_rules3_gl.struct_before_delete(case :old.cost_center_number when 1 then 'C1' else 'C2' end);
      g_nos(:old.cost_center_number) := :old.cost_center_number;
    end if;
  end before each row;
  after statement is
    i pls_integer;
  begin
    if v('APP_ID') is not null then
      i := g_nos.first;
      while i is not null loop
        app_rules3_gl.struct_after_delete(case i when 1 then 'C1' else 'C2' end);
        i := g_nos.next(i);
      end loop;
    end if;
  end after statement;
end app_rules3_gl_coststr_del;
/
show errors trigger app_rules3_gl_coststr_del

-- ACMAST: no delete of an account with transactions; its privileges go with it; the parent becomes postable again
create or replace trigger app_rules3_gl_acmast_del
for delete on ac_master
compound trigger
  before statement is
  begin
    if v('APP_ID') is not null then app_rules3_gl.hook_reset('AC'); end if;
  end before statement;
  before each row is
  begin
    if v('APP_ID') is not null then
      app_rules3_gl.code_before_delete('AC', :old.account_number, :old.account_level);
    end if;
  end before each row;
  after statement is
  begin
    if v('APP_ID') is not null then app_rules3_gl.code_after_delete('AC'); end if;
  end after statement;
end app_rules3_gl_acmast_del;
/
show errors trigger app_rules3_gl_acmast_del

-- ACCSTCD
create or replace trigger app_rules3_gl_cost1_del
for delete on ac_cost_centers
compound trigger
  before statement is
  begin
    if v('APP_ID') is not null then app_rules3_gl.hook_reset('C1'); end if;
  end before statement;
  before each row is
  begin
    if v('APP_ID') is not null then
      app_rules3_gl.code_before_delete('C1', :old.cost_code, :old.cost_level);
    end if;
  end before each row;
  after statement is
  begin
    if v('APP_ID') is not null then app_rules3_gl.code_after_delete('C1'); end if;
  end after statement;
end app_rules3_gl_cost1_del;
/
show errors trigger app_rules3_gl_cost1_del

-- ACCSTCD2
create or replace trigger app_rules3_gl_cost2_del
for delete on ac_cost_centers2
compound trigger
  before statement is
  begin
    if v('APP_ID') is not null then app_rules3_gl.hook_reset('C2'); end if;
  end before statement;
  before each row is
  begin
    if v('APP_ID') is not null then
      app_rules3_gl.code_before_delete('C2', :old.cost_code, :old.cost_level);
    end if;
  end before each row;
  after statement is
  begin
    if v('APP_ID') is not null then app_rules3_gl.code_after_delete('C2'); end if;
  end after statement;
end app_rules3_gl_cost2_del;
/
show errors trigger app_rules3_gl_cost2_del

-- ACTRCOD: journal types with entries or company privileges are not deleted
create or replace trigger app_rules3_gl_trncod_bd
before delete on ac_trn_codes for each row
begin
  if v('APP_ID') is not null then
    app_rules3_gl.journal_before_delete(:old.entry_year, :old.entry_type);
  end if;
end;
/
show errors trigger app_rules3_gl_trncod_bd

-- ACCRNCY: the local currency and used currencies are not deleted
create or replace trigger app_rules3_gl_curr_bd
before delete on ac_currency for each row
begin
  if v('APP_ID') is not null then
    app_rules3_gl.currency_before_delete(:old.currency_code);
  end if;
end;
/
show errors trigger app_rules3_gl_curr_bd

-- ACESTMT_PRIODS: periods must not overlap (reads the whole table: statement level)
create or replace trigger app_rules3_gl_estp_as
after insert or update on ac_estimate_periods
begin
  if v('APP_ID') is not null then
    app_rules3_gl.est_period_overlap;
  end if;
end;
/
show errors trigger app_rules3_gl_estp_as

-- ACESTMT_PERIODS_TRNS: deleting the whole budget removes the period values of each account line
create or replace trigger app_rules3_gl_estm_bd
before delete on ac_estimate_mast for each row
begin
  if v('APP_ID') is not null then
    app_rules3_gl.budget_mast_before_delete(:old.est_code, :old.serial);
  end if;
end;
/
show errors trigger app_rules3_gl_estm_bd

-- ACMNUCD: lines used as numerator / denominator cannot be changed away or deleted
create or replace trigger app_rules3_gl_finacc_as
after update or delete on ac_final_account
begin
  if v('APP_ID') is not null then
    app_rules3_gl.final_account_refs;
  end if;
end;
/
show errors trigger app_rules3_gl_finacc_as

-- AC_DISTP: posted distributions are not deleted, their target lines not changed
create or replace trigger app_rules3_gl_distp_bd
before delete on ac_distp for each row
begin
  if v('APP_ID') is not null then
    app_rules3_gl.distp_before_delete(:old.post_flag);
  end if;
end;
/
show errors trigger app_rules3_gl_distp_bd

create or replace trigger app_rules3_gl_distpd_bd
before delete on ac_distp_det for each row
begin
  if v('APP_ID') is not null then
    app_rules3_gl.distp_det_before_delete(:old.dis_serial);
  end if;
end;
/
show errors trigger app_rules3_gl_distpd_bd

-- ACBENFTAX: the VAT number is unique
create or replace trigger app_rules3_gl_benf_as
after insert or update on ac_benf_tax
begin
  if v('APP_ID') is not null then
    app_rules3_gl.benf_tax_unique;
  end if;
end;
/
show errors trigger app_rules3_gl_benf_as
