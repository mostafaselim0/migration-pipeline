-- =====================================================================================================
-- APP_RULES_GL : legacy business rules of the GL data-entry screens (Stage C waves 2 and 3).
--   ACDLYTR  daily GL entries AC_DAILY_TRN / AC_DAILY_TRN_DET
-- Evidence and rule list: app\legacy\processes\ACDLYTR.md. Wired by app\legacy\overrides\ACDLYTR.json:
--   key_expr   AC_DAILY_TRN.ENTRY_NO  -> next_entry_no   (CALC_SERIAL, legacy PRE-INSERT)
--              AC_DAILY_TRN_DET.SEQ   -> next_line_seq   (NEXT_DET_SEQ / GET_NEXT_SEQUENCE_NUMBER)
--   row_rules  AC_DAILY_TRN_DET       -> line_row        (line_defaults + VAT customer of AC_BENF_TAX + VAT memo)
--   validations                       -> check_header, check_user_rights
--   warnings                          -> warn_doc_repeat (AC_BASIC.DOC_REPEAT = 3, legacy DOC_NO_ASK)
--   after_save                        -> after_save_entry (lines, cost centres, balance, budget)
--   info                              -> entry_totals (DEBIT_TOTAL / CREDIT_TOTAL / DIFF), account_balances (CURRENT_LOC_F)
--   delete hook                       -> trigger APP_RULES_GL_DAILY_BD (PRE-DELETE: closed period, user rights)
-- Errors: raise_application_error(-20100..-20199) / returned Arabic text. No COMMIT anywhere (APEX commits).
-- Posting (TEST_AND_UPDATE / POST_VOUCHER) is APP_PROC_GL (post_voucher); the buttons are in APP_ACT_AR (23_act_ar.sql).
-- =====================================================================================================
set define off

create or replace package app_rules_gl authid definer as

  -- context (APEX application items; set_context overrides them for tests / callers outside APEX)
  procedure set_context (p_company_code in number, p_user_code in number, p_password_number in number);
  procedure clear_context;

  -- entry number: DB function CALC_SERIAL (max ENTRY_NO of AC_DAILY_TRN / AC_YEARLY_TRN + 1, or month-based
  -- MM||nnnn when AC_TRN_CODES.SERIAL_FLAG = 1). The AC_TRN_CODES row is locked to serialise concurrent saves.
  function next_entry_no (p_entry_year in number, p_entry_type in number, p_entry_date in date) return number;

  -- line number inside the entry (legacy NEXT_DET_SEQ = max(SEQ) + 1)
  function next_line_seq (p_entry_year in number, p_entry_type in number, p_entry_no in number) return number;

  -- row rule of AC_DAILY_TRN_DET (APEX sessions): values the legacy form derived for the user
  procedure line_defaults (
    p_inserting    in boolean,
    p_old_account  in number,
    p_entry_year   in number,
    p_entry_type   in number,
    p_entry_no     in number,
    p_account      in out number,
    p_cost_code    in out number,
    p_cost_code2   in out number,
    p_desc         in out varchar2,
    p_desc_e       in out varchar2,
    p_memo         in out varchar2,
    p_memo_e       in out varchar2,
    p_cust_code    in number,
    p_cust_tax_no  in varchar2,
    p_cust_name    in varchar2,
    p_cust_inv_val in out number);

  -- row rule of AC_DAILY_TRN_DET (wave 3): line_defaults, plus the VAT customer of CUST_CODE (legacy LOV on AC_BENF_TAX
  -- returns CUST_NAME / CUST_TAX_NO) and the VAT memo of CUST_CODE / CUST_NAME / CUST_INV_NO / CUST_INV_VAL WHEN-VALIDATE-ITEM
  procedure line_row (
    p_inserting        in boolean,
    p_old_account      in number,
    p_old_cust_code    in number,
    p_old_cust_name    in varchar2,
    p_old_cust_inv_no  in varchar2,
    p_old_cust_inv_val in number,
    p_entry_year       in number,
    p_entry_type       in number,
    p_entry_no         in number,
    p_account          in out number,
    p_cost_code        in out number,
    p_cost_code2       in out number,
    p_desc             in out varchar2,
    p_desc_e           in out varchar2,
    p_memo             in out varchar2,
    p_memo_e           in out varchar2,
    p_cust_code        in number,
    p_cust_tax_no      in out varchar2,
    p_cust_name        in out varchar2,
    p_cust_inv_no      in varchar2,
    p_cust_notes       in varchar2,
    p_cust_inv_val     in out number);

  -- page validation (CREATE, SAVE): header rules; returns the Arabic error text or null
  function check_header (
    p_rowid         in varchar2,
    p_entry_year    in number,
    p_entry_type    in number,
    p_entry_no      in number,
    p_entry_date    in date,
    p_doc_no        in number,
    p_currency_code in number,
    p_rate          in number) return varchar2;

  -- page validation (SAVE): USERS.ALLOW_UPDATE_ENTRIES = 0 -> only the entries the user created may be changed
  function check_user_rights (p_rowid in varchar2) return varchar2;

  -- SET_COST: 1 when the cost centre (p_which = 1 | 2) is mandatory for the account, else 0
  function cost_required (p_account in number, p_which in pls_integer) return number;

  -- TEST_ESTIMATE_PERIOD: estimated-budget balance of account/cost centres for the period of p_date
  -- (null when no estimate period or no budget exists; < 0 = budget exceeded)
  function budget_balance (p_account in number, p_cost_code in number, p_cost_code2 in number, p_date in date) return number;

  -- after-save process (CREATE, SAVE): line checks, balance, budget. Raises -201xx on errors (rolls the save back);
  -- returns a warning text (unbalanced entry when AC_BASIC.BALANCE_ENTRY_FLAG = 0, budget warning) or null.
  function after_save_entry (p_rowid in varchar2, p_request in varchar2) return varchar2;

  -- warning (DOC_NO WHEN-VALIDATE-ITEM, AC_BASIC.DOC_REPEAT = 3): document number already used -> "continue?"
  function warn_doc_repeat (p_rowid in varchar2, p_doc_no in number) return varchar2;

  -- info panel: DEBIT_TOTAL / CREDIT_TOTAL / DIFF of the entry (p_what 'D' / 'C' / 'X'), and CURRENT_LOC_F of each
  -- account of the entry (GET_ACCOUNT_BAL_LEVEL, 'مـديـن' / 'دائــن'), one line per account
  function entry_totals (p_rowid in varchar2, p_what in varchar2) return varchar2;
  function account_balances (p_rowid in varchar2) return varchar2;

  -- legacy form of the current APEX page (APP_PAGE_MAP); delete hook of the header (trigger at the end of this file)
  function cur_form return varchar2;
  procedure daily_before_delete (p_entry_date in date, p_create_user in number);

end app_rules_gl;
/

create or replace package body app_rules_gl as

  g_ctx       boolean := false;
  g_company   number;
  g_user      number;
  g_password  number;

  c_closing_memo   constant varchar2(100) := 'قــيــــد الاقـفـــــــال';
  c_closing_memo_e constant varchar2(100) := 'Closing Entry';

  procedure set_context (p_company_code in number, p_user_code in number, p_password_number in number) is
  begin
    g_ctx := true; g_company := p_company_code; g_user := p_user_code; g_password := p_password_number;
  end set_context;

  procedure clear_context is
  begin
    g_ctx := false; g_company := null; g_user := null; g_password := null;
  end clear_context;

  function num (p in varchar2) return number is
  begin
    return to_number(p);
  exception when value_error or invalid_number then return null;
  end num;

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

  function ctx_password return number is
  begin
    return nvl(case when g_ctx then g_password else num(v('G_PASSWORD_NUMBER')) end, 0);
  end ctx_password;

  function basic return ac_basic%rowtype is
    b ac_basic%rowtype;
    l_comp number := ctx_company;
  begin
    select * into b from ac_basic where company_code = l_comp;
    return b;
  exception when no_data_found then
    return b;
  end basic;

  procedure fail (p_code in pls_integer, p_msg in varchar2) is
  begin
    raise_application_error(p_code, p_msg);
  end fail;

  -- RPAD(to_char(n), len, '0') as in the WHEN-VALIDATE-ITEM triggers (short codes typed by the user are padded)
  function pad (p in number, p_len in pls_integer) return number is
  begin
    if p is null or p < 0 or p <> trunc(p) or length(to_char(p)) >= p_len then
      return p;
    end if;
    return to_number(rpad(to_char(p), p_len, '0'));
  end pad;

  -- ===================================================================================== numbering
  function next_entry_no (p_entry_year in number, p_entry_type in number, p_entry_date in date) return number is
    l_dummy number;
  begin
    begin
      select 1 into l_dummy
        from ac_trn_codes
       where entry_year = p_entry_year and entry_type = p_entry_type
         for update;
    exception when no_data_found then
      null;                                    -- CALC_SERIAL inserts the journal row itself (legacy behaviour)
    end;
    return calc_serial(p_entry_year, p_entry_type, nvl(p_entry_date, trunc(sysdate)));
  end next_entry_no;

  function next_line_seq (p_entry_year in number, p_entry_type in number, p_entry_no in number) return number is
    l number;
  begin
    select nvl(max(seq), 0) + 1 into l
      from ac_daily_trn_det
     where entry_year = p_entry_year and entry_type = p_entry_type and entry_no = p_entry_no;
    return l;
  end next_line_seq;

  -- ===================================================================================== row rule
  procedure line_defaults (
    p_inserting    in boolean,
    p_old_account  in number,
    p_entry_year   in number,
    p_entry_type   in number,
    p_entry_no     in number,
    p_account      in out number,
    p_cost_code    in out number,
    p_cost_code2   in out number,
    p_desc         in out varchar2,
    p_desc_e       in out varchar2,
    p_memo         in out varchar2,
    p_memo_e       in out varchar2,
    p_cust_code    in number,
    p_cust_tax_no  in varchar2,
    p_cust_name    in varchar2,
    p_cust_inv_val in out number)
  is
    l_name   ac_master.account_name%type;
    l_name_e ac_master.account_name_e%type;
    l_hdesc  ac_daily_trn.entry_desc%type;
    l_hdesc_e ac_daily_trn.entry_desc_e%type;
    l_changed boolean;
  begin
    -- ACCOUNT_NUMBER / COST_CODE / COST_CODE2 WHEN-VALIDATE-ITEM: RPAD to 12 / 9 digits
    p_account    := pad(p_account, 12);
    p_cost_code  := pad(p_cost_code, 9);
    p_cost_code2 := pad(p_cost_code2, 9);

    -- ACCOUNT_NUMBER WHEN-VALIDATE-ITEM: the line description is the account name (ENTRY_DESC validates from the account LOV)
    l_changed := (not p_inserting) and p_old_account is not null and p_account <> p_old_account;
    if p_account is not null and (l_changed or p_desc is null or p_desc_e is null) then
      begin
        select account_name, account_name_e into l_name, l_name_e from ac_master where account_number = p_account;
        if l_changed or p_desc is null then p_desc := l_name; end if;
        if l_changed or p_desc_e is null then p_desc_e := l_name_e; end if;
      exception when no_data_found then
        null;                                   -- FK AC_DAILY_TRN_DET_FK2 reports the unknown account
      end;
    end if;

    -- ACCOUNT_NUMBER / ENTRY_DESC / COST_CODE WHEN-VALIDATE-ITEM: MEMO := header ENTRY_DESC (the user may overwrite it)
    if p_memo is null or p_memo_e is null then
      begin
        select entry_desc, entry_desc_e into l_hdesc, l_hdesc_e
          from ac_daily_trn
         where entry_year = p_entry_year and entry_type = p_entry_type and entry_no = p_entry_no;
        if p_memo is null then p_memo := l_hdesc; end if;
        if p_memo_e is null then p_memo_e := l_hdesc_e; end if;
      exception when no_data_found then
        null;
      end;
    end if;

    -- PRE-INSERT / PRE-UPDATE: no VAT customer data -> CUST_INV_VAL := 0
    if p_cust_code is null and p_cust_tax_no is null and p_cust_name is null then
      p_cust_inv_val := 0;
    end if;
  end line_defaults;

  procedure line_row (
    p_inserting        in boolean,
    p_old_account      in number,
    p_old_cust_code    in number,
    p_old_cust_name    in varchar2,
    p_old_cust_inv_no  in varchar2,
    p_old_cust_inv_val in number,
    p_entry_year       in number,
    p_entry_type       in number,
    p_entry_no         in number,
    p_account          in out number,
    p_cost_code        in out number,
    p_cost_code2       in out number,
    p_desc             in out varchar2,
    p_desc_e           in out varchar2,
    p_memo             in out varchar2,
    p_memo_e           in out varchar2,
    p_cust_code        in number,
    p_cust_tax_no      in out varchar2,
    p_cust_name        in out varchar2,
    p_cust_inv_no      in varchar2,
    p_cust_notes       in varchar2,
    p_cust_inv_val     in out number)
  is
    l_name   ac_benf_tax.benf_name%type;
    l_tax_no ac_benf_tax.tax_no%type;
    l_code_changed boolean := p_cust_code is not null
                              and (p_inserting or nvl(p_old_cust_code, -1) <> p_cust_code);
    l_vat_changed  boolean;
  begin
    -- CUST_CODE LOV (record group on AC_BENF_TAX): returns BENF_NAME -> CUST_NAME and TAX_NO -> CUST_TAX_NO
    if l_code_changed then
      begin
        select benf_name, tax_no into l_name, l_tax_no from ac_benf_tax where benf_code = p_cust_code;
        p_cust_name := l_name;
        p_cust_tax_no := l_tax_no;
      exception when no_data_found then
        null;                                   -- a code outside AC_BENF_TAX keeps the typed name / tax number
      end;
    end if;

    line_defaults(p_inserting, p_old_account, p_entry_year, p_entry_type, p_entry_no, p_account, p_cost_code, p_cost_code2,
                  p_desc, p_desc_e, p_memo, p_memo_e, p_cust_code, p_cust_tax_no, p_cust_name, p_cust_inv_val);

    -- CUST_CODE / CUST_NAME / CUST_INV_NO / CUST_INV_VAL WHEN-VALIDATE-ITEM: VAT memo (fires when one of them is entered
    -- or changed; the texts keep the legacy "5%")
    l_vat_changed := p_inserting
                     or nvl(p_old_cust_code, -1) <> nvl(p_cust_code, -1)
                     or nvl(p_old_cust_name, chr(0)) <> nvl(p_cust_name, chr(0))
                     or nvl(p_old_cust_inv_no, chr(0)) <> nvl(p_cust_inv_no, chr(0))
                     or nvl(p_old_cust_inv_val, -1) <> nvl(p_cust_inv_val, -1);
    if l_vat_changed and p_cust_code is not null and p_cust_name is not null and p_cust_inv_no is not null then
      p_memo := substr('ضريبة 5% على الفاتورة رقم : ' || p_cust_inv_no || ' للعميل : ' || p_cust_name || ' - ' || p_cust_notes, 1, 2000);
      p_memo_e := substr('VAT 5% on Invoice No : ' || p_cust_inv_no || ' for Customer : ' || p_cust_name || ' - ' || p_cust_notes, 1, 2000);
    end if;
  end line_row;

  -- ===================================================================================== header
  function type_allowed (p_year in number, p_type in number) return varchar2 is
    l_flag number;
    l_n    number;
    l_pw   number := ctx_password;
    l_comp number := ctx_company;
  begin
    begin
      select nvl(ac_flag, 0) into l_flag from ac_trn_codes where entry_year = p_year and entry_type = p_type;
    exception when no_data_found then
      return 'نوع القيد ' || p_type || ' غير معرف لسنة ' || p_year || ' فى ملف أنواع القيود';
    end;
    -- ENTRY_TYPE_RG (validate from list): NVL(AC_FLAG,0) = 0 and AC_PASSWORD_ENTRY of the user group
    if l_flag <> 0 then
      return 'نوع القيد ' || p_type || ' خاص بقيود الأنظمة الأخرى ولا يستخدم فى القيود اليومية';
    end if;
    if l_pw <> 0 then
      select count(*) into l_n
        from ac_password_entry
       where password_number = l_pw and company_code = l_comp and entry_year = p_year and entry_type = p_type;
      if l_n = 0 then
        return 'غير مسموح لمجموعتك باستخدام نوع القيد ' || p_type;
      end if;
    end if;
    return null;
  end type_allowed;

  function check_header (
    p_rowid         in varchar2,
    p_entry_year    in number,
    p_entry_type    in number,
    p_entry_no      in number,
    p_entry_date    in date,
    p_doc_no        in number,
    p_currency_code in number,
    p_rate          in number) return varchar2
  is
    b        ac_basic%rowtype := basic;
    l_old    ac_daily_trn%rowtype;
    l_new    boolean := p_rowid is null;
    l_msg    varchar2(4000);
    l_close  date;
    l_n      number;
    l_comp   number := ctx_company;
  begin
    if not l_new then
      begin
        select * into l_old from ac_daily_trn where rowid = chartorowid(p_rowid);
      exception when no_data_found or value_error then
        l_new := true;
      end;
    end if;

    if p_entry_year is null or p_entry_type is null or p_entry_date is null then
      return 'يجب إدخال سنة ونوع وتاريخ القيد';
    end if;

    if not l_new and (l_old.entry_year <> p_entry_year or l_old.entry_type <> p_entry_type
                      or (p_entry_no is not null and l_old.entry_no <> p_entry_no)) then
      return 'لا يمكن تغيير سنة أو نوع أو رقم قيد محفوظ';
    end if;

    -- ENTRY_TYPE: validate from ENTRY_TYPE_RG (new entries; a saved entry keeps its journal)
    if l_new then
      l_msg := type_allowed(p_entry_year, p_entry_type);
      if l_msg is not null then return l_msg; end if;
    end if;

    -- ENTRY_YEAR / ENTRY_DATE WHEN-VALIDATE-ITEM
    if to_number(to_char(p_entry_date, 'YYYY')) <> p_entry_year then
      return 'سنة القيد يجب ان تساوى سنة تاريخ القيد';
    end if;

    -- CHECK_CLOSE_DATE (AC_BASIC.CLOSE_DATE)
    if b.close_date is not null and p_entry_date <= b.close_date then
      return 'تاريخ القيد يقع فى فترة مقفلة (تاريخ الإقفال ' || to_char(b.close_date, 'DD/MM/YYYY') || ')';
    end if;

    -- PRE-INSERT / PRE-UPDATE / ENTRY_DATE: after the last closing entry of AC_YEARLY_TRN
    select max(entry_date) into l_close
      from ac_yearly_trn
     where memo = c_closing_memo and memo_e = c_closing_memo_e;
    if l_close is not null and l_close >= p_entry_date then
      return 'يجب أن يكون تاريخ القيد أكبر من تاريخ الأقفال (' || to_char(l_close, 'DD/MM/YYYY') || ')';
    end if;

    -- ENTRY_DATE: AC_BASIC.ALLOW_FUTURE_ENTRY, MIN_DATE / MAX_DATE
    if nvl(b.allow_future_entry, 0) = 0 and trunc(p_entry_date) > trunc(sysdate) then
      return 'تاريخ القيد لا يمكن ان يكون اكبر من تاريخ اليوم';
    end if;
    if (b.min_date is not null and p_entry_date < b.min_date) or (b.max_date is not null and p_entry_date > b.max_date) then
      return 'تاريخ القيد لايقع ضمن فترة مؤشرات النظام';
    end if;

    -- CURRENCY_CODE / RATE (CONTROL.CURRENCY_CODE = 1 when AC_BASIC.CURRENCY_STTS = 0)
    if p_currency_code is null then
      return 'يجب إدخال العملة';
    end if;
    if nvl(b.currency_stts, 0) = 0 and p_currency_code <> 1 then
      return 'العملة يجب أن تكون العملة المحلية (1) طبقاً لمؤشرات النظام';
    end if;
    select count(*) into l_n from ac_currency where currency_code = p_currency_code;
    if l_n = 0 then
      return 'رقم العملة غير موجود';
    end if;
    if nvl(p_rate, 0) <= 0 then
      return 'يجب ادخال معامل تحويل أكبر من الصفر';
    end if;
    if p_currency_code = 1 and p_rate <> 1 then
      return 'معامل تحويل الريال يجب ان يكون 1';
    end if;

    -- DOC_NO: AC_BASIC.DOC_REPEAT = 2 -> no repeated document number in AC_DAILY_TRN / AC_YEARLY_TRN (3 = legacy asked, allowed)
    if p_doc_no is not null and nvl(b.doc_repeat, 0) = 2
       and (l_new or nvl(l_old.doc_no, -1) <> p_doc_no) then
      select count(*) into l_n
        from ac_daily_trn
       where doc_no = p_doc_no and create_company_code = l_comp
         and (p_rowid is null or rowid <> chartorowid(p_rowid));
      if l_n = 0 then
        select count(*) into l_n from ac_yearly_trn where doc_no = p_doc_no;
      end if;
      if l_n > 0 then
        return 'غير مسموح بتكرار رقم المستند ' || p_doc_no;
      end if;
    end if;
    return null;
  end check_header;

  function check_user_rights (p_rowid in varchar2) return varchar2 is
    l_user   number := ctx_user;
    l_upd    number;
    l_owner  number;
  begin
    if p_rowid is null or nvl(l_user, 0) = 0 then
      return null;
    end if;
    begin
      select create_user_code into l_owner from ac_daily_trn where rowid = chartorowid(p_rowid);
    exception when no_data_found or value_error then
      return null;
    end;
    select nvl(max(allow_update_entries), 0) into l_upd from users where users_code = l_user;
    if l_upd = 0 and nvl(l_owner, 0) <> l_user then
      return 'ليس لديك صلاحية تعديل قيد أدخله مستخدم آخر';
    end if;
    return null;
  end check_user_rights;

  -- ===================================================================================== lines
  function cost_required (p_account in number, p_which in pls_integer) return number is
    b      ac_basic%rowtype := basic;
    l_c1   number := 0;
    l_c2   number := 0;
    l_req  boolean := false;
    l_dig  varchar2(1) := substr(to_char(p_account), 1, 1);
  begin
    begin
      select nvl(acc_cost1_flag, 0), nvl(acc_cost2_flag, 0) into l_c1, l_c2 from ac_master where account_number = p_account;
    exception when no_data_found then null;
    end;
    -- SET_COST: income accounts (first digit of INCOME1_ACCT) / expense accounts (OUTCOME1_ACCT) / others
    if l_dig = substr(to_char(b.income1_acct), 1, 1) then
      l_req := case p_which when 1 then b.enter_cost_center1 = 1 or l_c1 = 1 else b.enter_cost_center2 = 1 or l_c2 = 1 end;
    elsif l_dig = substr(to_char(b.outcome1_acct), 1, 1) then
      l_req := case p_which when 1 then b.expend_cost1 = 1 or l_c1 = 1 else b.expend_cost2 = 1 or l_c2 = 1 end;
    else
      l_req := case p_which when 1 then l_c1 = 1 else l_c2 = 1 end;
    end if;
    -- ALL_COST1_FLAG / ALL_COST2_FLAG and the account flags keep the requirement
    if p_which = 1 and (b.all_cost1_flag = 1 or l_c1 = 1) then l_req := true; end if;
    if p_which = 2 and (b.all_cost2_flag = 1 or l_c2 = 1) then l_req := true; end if;
    return case when nvl(l_req, false) then 1 else 0 end;
  end cost_required;

  function budget_balance (p_account in number, p_cost_code in number, p_cost_code2 in number, p_date in date) return number is
    l_period   number;
    l_from     date;
    l_till     date;
    l_debit    number := 0;           -- actual debits of the period (legacy "actual_credit_value")
    l_credit   number := 0;           -- actual credits (legacy "actual_debit_value")
    l_est_pos  number;
    l_est_neg  number;
    l_est_code number := basic().est_code;
    l_bal      number;
  begin
    begin
      select period_code, from_date, till_date into l_period, l_from, l_till
        from ac_estimate_periods
       where p_date between from_date and till_date
         and rownum = 1;
    exception when no_data_found then
      return null;
    end;
    for s in (select d.value
                from ac_daily_trn_det d, ac_daily_trn m
               where d.account_number = p_account
                 and m.entry_year = d.entry_year and m.entry_type = d.entry_type and m.entry_no = d.entry_no
                 and m.entry_date between l_from and l_till
                 and nvl(d.cost_code, 0) = nvl(p_cost_code, 0) and nvl(d.cost_code2, 0) = nvl(p_cost_code2, 0)
              union all
              select d.value
                from ac_yearly_trn_det d, ac_yearly_trn m
               where d.account_number = p_account
                 and m.entry_year = d.entry_year and m.entry_type = d.entry_type and m.entry_no = d.entry_no
                 and m.entry_date between l_from and l_till
                 and nvl(d.cost_code, 0) = nvl(p_cost_code, 0) and nvl(d.cost_code2, 0) = nvl(p_cost_code2, 0))
    loop
      if s.value > 0 then l_debit := l_debit + s.value;
      elsif s.value < 0 then l_credit := l_credit - s.value;
      end if;
    end loop;
    select sum(case when d.value < 0 then d.value end), sum(case when d.value > 0 then d.value end)
      into l_est_neg, l_est_pos
      from ac_estimate_mast m, ac_estimate_det d
     where m.serial = d.mast_serial and m.est_code = d.est_code
       and m.est_code = l_est_code
       and m.account_number = p_account and d.period_code = l_period
       and nvl(m.cost_code, 0) = nvl(p_cost_code, 0) and nvl(m.cost_code2, 0) = nvl(p_cost_code2, 0);
    if l_est_neg is null and l_est_pos is null then
      return null;                              -- no budget line: legacy EST_PERIOD_BAL := 0, no check
    end if;
    l_bal := (abs(nvl(l_est_pos, 0)) - abs(nvl(l_est_neg, 0))) + (l_credit - l_debit);
    if nvl(l_est_neg, 0) < 0 then
      l_bal := -l_bal;                          -- credit budget (V_CREDIT_FLAG)
    end if;
    return l_bal;
  end budget_balance;

  function after_save_entry (p_rowid in varchar2, p_request in varchar2) return varchar2 is
    b        ac_basic%rowtype := basic;
    h        ac_daily_trn%rowtype;
    l_pw     number := ctx_password;
    l_comp   number := ctx_company;
    l_n      number := 0;
    l_sum    number;
    l_bal    number;
    l_warn   varchar2(4000);
    l_acc    ac_master%rowtype;
    l_line   varchar2(200);
  begin
    if p_rowid is null then
      return null;
    end if;
    begin
      select * into h from ac_daily_trn where rowid = chartorowid(p_rowid);
    exception when no_data_found or value_error then
      return null;                               -- entry deleted in the same request
    end;

    for d in (select * from ac_daily_trn_det
               where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no
               order by seq)
    loop
      l_n := l_n + 1;
      l_line := 'السطر ' || d.seq || ' (الحساب ' || d.account_number || '): ';
      -- ACCOUNT_NUMBER validates from ACCOUNT_NUMBER_RG: sub account (ACCOUNT_STATUS = 1), NVL(AC_FLAG,0) = 0,
      -- currency of the entry (or AC_BASIC.CURRENCY_ACCT), account allowed for the user group
      begin
        select * into l_acc from ac_master where account_number = d.account_number;
      exception when no_data_found then
        fail(-20111, l_line || 'رقم الحساب غير موجود');
      end;
      if nvl(l_acc.account_status, 0) <> 1 then
        fail(-20112, l_line || 'رقم الحساب ليس حساب فرعى');
      end if;
      if nvl(l_acc.ac_flag, 0) <> 0 then
        fail(-20113, l_line || 'الحساب غير مسموح به فى القيود اليومية');
      end if;
      if nvl(l_acc.currency_code, -1) <> nvl(h.currency_code, -1) and d.account_number <> nvl(b.currency_acct, -1) then
        fail(-20114, l_line || 'عملة الحساب تختلف عن عملة القيد');
      end if;
      if l_pw <> 0 then
        select count(*) into l_sum
          from ac_password_master
         where password_number = l_pw and company_code = l_comp and account_number = d.account_number;
        if l_sum = 0 then
          fail(-20115, l_line || 'غير مسموح لمجموعتك باستخدام هذا الحساب');
        end if;
      end if;
      -- COST_CODE / COST_CODE2 validate from COST_CENTERS1_RG / COST_CENTERS2_RG (active, allowed for the group)
      if d.cost_code is not null then
        select count(*) into l_sum from ac_cost_centers where cost_code = d.cost_code and cost_status = 1;
        if l_sum = 0 then
          fail(-20116, l_line || 'مركز التكلفة 1 (' || d.cost_code || ') غير موجود أو موقوف');
        end if;
        if l_pw <> 0 then
          select count(*) into l_sum from ac_password_cost1
           where password_number = l_pw and company_code = l_comp and cost_code = d.cost_code;
          if l_sum = 0 then
            fail(-20117, l_line || 'غير مسموح لمجموعتك باستخدام مركز التكلفة 1 (' || d.cost_code || ')');
          end if;
        end if;
      end if;
      if d.cost_code2 is not null then
        select count(*) into l_sum from ac_cost_centers2 where cost_code = d.cost_code2 and cost_status = 1;
        if l_sum = 0 then
          fail(-20118, l_line || 'مركز التكلفة 2 (' || d.cost_code2 || ') غير موجود أو موقوف');
        end if;
        if l_pw <> 0 then
          select count(*) into l_sum from ac_password_cost2
           where password_number = l_pw and company_code = l_comp and cost_code = d.cost_code2;
          if l_sum = 0 then
            fail(-20119, l_line || 'غير مسموح لمجموعتك باستخدام مركز التكلفة 2 (' || d.cost_code2 || ')');
          end if;
        end if;
      end if;
      -- SET_COST: mandatory cost centres
      if d.cost_code is null and cost_required(d.account_number, 1) = 1 then
        fail(-20120, l_line || 'يجب إدخال مركز التكلفة 1 لهذا الحساب');
      end if;
      if d.cost_code2 is null and cost_required(d.account_number, 2) = 1 then
        fail(-20121, l_line || 'يجب إدخال مركز التكلفة 2 لهذا الحساب');
      end if;
      -- CUST_TAX_NO WHEN-VALIDATE-ITEM
      if d.cust_tax_no is not null and length(d.cust_tax_no) <> 15 then
        fail(-20122, l_line || 'خطأ برقم الضريبة .. لابد ان يكون مكون من 15 رقم');
      end if;
    end loop;

    -- PRE-INSERT EMPTY_ALERT / detail POST-DELETE: an entry must keep at least one line.
    -- The APEX document is created header-first (lines are entered after CREATE), so the check applies to SAVE.
    if l_n = 0 and upper(nvl(p_request, 'SAVE')) <> 'CREATE' then
      fail(-20123, 'القيد لا يحتوى على تفاصيل');
    end if;

    -- KEY-COMMIT: debit total = credit total; AC_BASIC.BALANCE_ENTRY_FLAG = 1 refuses, 0 = legacy asked (BAL_ALERT) -> warning
    select nvl(sum(value), 0) into l_sum
      from ac_daily_trn_det
     where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
    if l_sum <> 0 then
      if nvl(b.balance_entry_flag, 0) <> 0 then
        fail(-20124, 'لايمكن حفظ قيد غير متزن (الفرق بين المدين والدائن = ' || to_char(l_sum, 'FM999,999,999,990.00') || ')');
      end if;
      l_warn := 'تنبيه: القيد غير متزن - الفرق بين المدين والدائن = ' || to_char(l_sum, 'FM999,999,999,990.00');
    end if;

    -- TEST_ESTIMATE_PERIOD(1) when AC_BASIC.ESTIMATE_TEST = 1; STOP_ESTIMATE_TEST = 1 refuses, else warning
    if nvl(b.estimate_test, 0) = 1 then
      for a in (select distinct account_number, cost_code, cost_code2
                  from ac_daily_trn_det
                 where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no)
      loop
        l_bal := budget_balance(a.account_number, a.cost_code, a.cost_code2, h.entry_date);
        if l_bal < 0 then
          if nvl(b.stop_estimate_test, 0) = 1 then
            fail(-20125, 'الحساب ' || a.account_number || ': لقد تم تعدى الميزانية التقديرية');
          end if;
          l_warn := l_warn || case when l_warn is not null then ' - ' end
                    || 'الحساب ' || a.account_number || ': تم تعدى الميزانية التقديرية';
        end if;
      end loop;
    end if;
    return l_warn;
  end after_save_entry;

  -- ===================================================================================== wave 3
  function is_en return boolean is
  begin
    return lower(nvl(v('G_LANG'), 'ar')) like 'en%';
  end is_en;

  function lt (p_a in varchar2, p_e in varchar2) return varchar2 is
  begin
    return case when is_en and p_e is not null then p_e else p_a end;
  end lt;

  function header_row (p_rowid in varchar2) return ac_daily_trn%rowtype is
    h ac_daily_trn%rowtype;
  begin
    if p_rowid is not null then
      select * into h from ac_daily_trn where rowid = chartorowid(p_rowid);
    end if;
    return h;
  exception when no_data_found or value_error then
    return h;
  end header_row;

  function warn_doc_repeat (p_rowid in varchar2, p_doc_no in number) return varchar2 is
    b    ac_basic%rowtype := basic;
    h    ac_daily_trn%rowtype := header_row(p_rowid);
    l_n  number;
    l_comp number := ctx_company;
  begin
    -- DOC_NO WHEN-VALIDATE-ITEM (fires when the number is entered or changed); DOC_REPEAT = 2 refuses (check_header)
    if p_doc_no is null or nvl(b.doc_repeat, 0) <> 3 or (h.entry_no is not null and nvl(h.doc_no, -1) = p_doc_no) then
      return null;
    end if;
    select count(entry_no) into l_n
      from ac_daily_trn
     where doc_no = p_doc_no and create_company_code = l_comp
       and (p_rowid is null or rowid <> chartorowid(p_rowid));
    if l_n = 0 then
      select count(entry_no) into l_n from ac_yearly_trn where doc_no = p_doc_no;
    end if;
    if l_n > 0 then
      return lt('رقم المستند مكرر', 'Doc Code Repeted') || ' (' || p_doc_no || ')';
    end if;
    return null;
  end warn_doc_repeat;

  function entry_totals (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    h     ac_daily_trn%rowtype := header_row(p_rowid);
    l_d   number;
    l_c   number;
  begin
    if h.entry_no is null then
      return null;
    end if;
    select nvl(sum(case when value > 0 then value end), 0), nvl(sum(case when value < 0 then -value end), 0)
      into l_d, l_c
      from ac_daily_trn_det
     where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
    return to_char(case upper(p_what) when 'D' then l_d when 'C' then l_c else l_d - l_c end, 'FM999,999,999,990.00');
  end entry_totals;

  function account_balances (p_rowid in varchar2) return varchar2 is
    h     ac_daily_trn%rowtype := header_row(p_rowid);
    l_txt varchar2(4000);
    l_bal number;
    l_comp number := ctx_company;
    l_en   pls_integer := case when is_en then 1 else 0 end;
  begin
    if h.entry_no is null then
      return null;
    end if;
    for a in (select d.account_number, min(d.seq) seq,
                     max(case when l_en = 1 then nvl(m.account_name_e, m.account_name) else m.account_name end) name
                from ac_daily_trn_det d, ac_master m
               where d.entry_year = h.entry_year and d.entry_type = h.entry_type and d.entry_no = h.entry_no
                 and m.account_number (+) = d.account_number
               group by d.account_number
               order by 2)
    loop
      -- POST-QUERY of AC_DAILY_TRN_DET: CURRENT_LOC_F := GET_ACCOUNT_BAL_LEVEL(company, account), DBCR1 debit / credit
      l_bal := get_account_bal_level(l_comp, a.account_number);
      l_txt := substr(l_txt || case when l_txt is not null then chr(10) end
                      || a.account_number || ' ' || a.name || ': '
                      || case when nvl(l_bal, 0) = 0 then '0'
                              else to_char(abs(l_bal), 'FM999,999,999,990.00') || ' '
                                   || case when l_bal > 0 then lt('مـديـن', 'Debit') else lt('دائــن', 'Credit') end
                         end, 1, 4000);
    end loop;
    return l_txt;
  end account_balances;

  function cur_form return varchar2 is
    l_page number;
    l_form varchar2(128);
  begin
    begin l_page := to_number(v('APP_PAGE_ID')); exception when others then l_page := null; end;
    if l_page is null then
      return null;
    end if;
    select max(form_name) into l_form from app_page_map where page_id = l_page;
    return l_form;
  end cur_form;

  procedure daily_before_delete (p_entry_date in date, p_create_user in number) is
    b      ac_basic%rowtype := basic;
    l_user number := ctx_user;
    l_upd  number;
    l_del  number;
  begin
    if upper(nvl(v('REQUEST'), 'x')) <> 'DELETE' or nvl(cur_form, 'x') <> 'ACDLYTR' then
      return;
    end if;
    -- AC_DAILY_TRN PRE-DELETE: IF CLOSE_DATE < ENTRY_DATE delete ELSE alert DEL_ERROR (an empty CLOSE_DATE refuses too)
    if b.close_date is null or p_entry_date is null or b.close_date >= p_entry_date then
      raise_application_error(-20126, lt('تاريخ القيد أقل من تاريخ قيد الإقفال لا يمكن إلغاء القيد',
                                         'The entry date is before the closing entry date, the entry cannot be deleted'));
    end if;
    -- WHEN-NEW-RECORD-INSTANCE (GET_USER_SEC): ALLOW_UPDATE_ENTRIES = 0 and ALLOW_DELETE_ENTRIES = 0 -> only the
    -- creator may delete the entry (user 0 unrestricted)
    if nvl(l_user, 0) <> 0 then
      select nvl(max(allow_update_entries), 0), nvl(max(allow_delete_entries), 0) into l_upd, l_del
        from users where users_code = l_user;
      if l_upd = 0 and l_del = 0 and nvl(p_create_user, 0) <> l_user then
        raise_application_error(-20127, lt('ليس لديك صلاحية حذف قيد أدخله مستخدم آخر',
                                           'You may not delete an entry created by another user'));
      end if;
    end if;
  end daily_before_delete;

end app_rules_gl;
/
show errors package body app_rules_gl

-- ---------------------------------------------------------------------------------------------------
-- Delete hook of the daily-entry page (ACDLYTR, request DELETE): the page deletes the lines first (cascade process),
-- then the header; a refusal here rolls both back.
-- ---------------------------------------------------------------------------------------------------
create or replace trigger app_rules_gl_daily_bd
before delete on ac_daily_trn for each row
begin
  if v('APP_ID') is not null then
    app_rules_gl.daily_before_delete(:old.entry_date, :old.create_user_code);
  end if;
end;
/
show errors trigger app_rules_gl_daily_bd
