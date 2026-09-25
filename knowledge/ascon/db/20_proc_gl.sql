-- =====================================================================================================
-- 20_proc_gl.sql : General Ledger (system 1) process screens of the ASCON ERP, reconstructed for APEX
-- (Stage C). Package APP_PROC_GL. If another GL process screen is added later, append a new section with
-- its own package name; do not rewrite this one.
--
--   ACUPDT           (1/71)  ترحيل القيود اليومية        -> app_proc_gl.post_entries
--   ACCUPDT          (1/72)  إلغاء ترحيل القيود          -> app_proc_gl.cancel_posting
--   ACCLOSE          (1/73)  قيد الإقفال                  -> app_proc_gl.create_closing_entry
--   AC_DELETECCLOSE  (1/79)  إلغاء قيد الإقفال            -> app_proc_gl.cancel_closing_entry
--   AC_DUPENTRY      (1/84)  إنشاء القيد الدورى           -> app_proc_gl.create_periodical_entry
--
-- Evidence: the SQL strings inside ASCON\AC\FMB\{Acupdt,ACCUPDT,Acclose,AC_deletecclose,ac_dupentry}.fmx,
-- the DB triggers on AC_* tables, CALC_SERIAL, and the live data (see app\legacy\processes\<FORM>.md).
--
-- Rules kept from the legacy system:
--   * AC_MASTER balance columns (CURRENT_*, BEGIN_*) are NOT touched: on this schema they are 0/NULL for
--     every account and every balance (GET_BALANCE .pll, ACCLOSE) is summed from AC_YEARLY_TRN_DET.
--   * Security: group (PASSWORD_NUMBER) 0 = unrestricted; any other group only sees entry types granted in
--     AC_PASSWORD_ENTRY for its company. Deviation: a NULL group or company is treated as restricted
--     (legacy treated NULL like group 0).
--   * GLOBAL.USR_ENTRY_YEAR / USR_ENTRY_TYPE have no APEX equivalent (not set by app_sec.post_auth): ignored.
--   * No COMMIT, except the autonomous write of posting errors to AC_UPDT_TBL (the legacy committed that
--     work table before running the ACPSTERR error report in a separate Reports session).
--   * Business errors: raise_application_error(-20100..-20199), Arabic text (English when G_LANG = 'en').
--   * Result text is put into apex_application.g_print_success_message (and last_message for tests).
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_proc_gl authid definer as

  -- ACUPDT: test the daily entries (AC_DAILY_TRN/_DET) of the voucher range and, unless p_test_only = 1,
  -- move them to the posted tables (AC_YEARLY_TRN/_DET). All-or-nothing: if any entry has an error nothing
  -- is posted and the errors are written to AC_UPDT_TBL.
  procedure post_entries (
    p_from_year       in number,
    p_to_year         in number,
    p_from_type       in number,
    p_to_type         in number,
    p_from_no         in number default null,
    p_to_no           in number default null,
    p_from_doc_no     in number default null,
    p_to_doc_no       in number default null,
    p_from_date       in date   default null,
    p_to_date         in date   default null,
    p_test_only       in number default 0,
    p_company_code    in number,
    p_user_code       in number,
    p_password_number in number);

  -- ACCUPDT: move posted GL entries (POST_SYSTEM = 1, not closing entries) of the range back to the daily
  -- tables. Entries in a closed period (or refused by a DB trigger) are skipped and reported.
  procedure cancel_posting (
    p_from_year       in number,
    p_to_year         in number,
    p_from_type       in number,
    p_to_type         in number,
    p_from_no         in number default null,
    p_to_no           in number default null,
    p_from_doc_no     in number default null,
    p_to_doc_no       in number default null,
    p_from_date       in date   default null,
    p_to_date         in date   default null,
    p_company_code    in number,
    p_user_code       in number,
    p_password_number in number);

  -- ACCLOSE: closing entry (CLOSE_FLAG = 1) that zeroes every income/expense leaf account per cost centre
  -- pair up to p_close_date against AC_BASIC.PROFIT_ACCT, then AC_BASIC.CLOSE_DATE := p_close_date.
  procedure create_closing_entry (
    p_entry_year      in number,
    p_entry_type      in number,
    p_close_date      in date,
    p_company_code    in number,
    p_user_code       in number,
    p_password_number in number);

  -- AC_DELETECCLOSE: delete the last closing entry and set AC_BASIC.CLOSE_DATE to the previous one.
  -- p_close_date must equal the date of that last closing entry (guards against a double submit).
  procedure cancel_closing_entry (
    p_close_date      in date,
    p_company_code    in number,
    p_user_code       in number,
    p_password_number in number);

  -- AC_DUPENTRY: copy the entry referenced by AC_PERIODICAL_VOC.SERIAL into a new daily entry
  -- (journal p_new_type, date p_new_date or the source date), numbered with CALC_SERIAL.
  procedure create_periodical_entry (
    p_serial          in number,
    p_new_type        in number,
    p_new_date        in date,
    p_company_code    in number,
    p_user_code       in number,
    p_password_number in number);

  -- ACDLYTR button POST_VOUCHER (ترحيل القيد): TEST_AND_UPDATE of the daily-entry form for one entry - the button checks
  -- (closed period, balance, last closing entry), TEST_PROC (errors to AC_UPDT_TBL, nothing posted) and UPDATE_PROC
  -- (AC_YEARLY_TRN / _DET, currency-difference line 999, delete the daily entry).
  procedure post_voucher (
    p_entry_year      in number,
    p_entry_type      in number,
    p_entry_no        in number,
    p_company_code    in number,
    p_user_code       in number,
    p_password_number in number);

  -- WHEN-NEW-FORM-INSTANCE of ACDLYTR: POST_VOUCHER enabled for group 0, else GROUP_COMPANY.POST_FLAG = 1 and the user's
  -- FILE_PASSWORD row of ACUPDT (system 1, file 71) with all four flags; 1 = allowed
  function voucher_post_allowed (p_company_code in number, p_user_code in number, p_password_number in number) return number;

  -- ---- helpers used by the page LOVs / defaults / previews (must be public to be callable from SQL) ----
  function current_year (p_company_code in number) return number;
  function type_allowed (p_entry_year in number, p_entry_type in number,
                         p_company_code in number, p_password_number in number) return number;
  function voucher_key (p_year in number, p_type in number, p_no in number) return varchar2;
  function in_range (p_year in number, p_type in number, p_no in number,
                     p_from_year in number, p_from_type in number, p_from_no in number,
                     p_to_year in number, p_to_type in number, p_to_no in number) return number;
  function daily_type_bound (p_year in number, p_company_code in number, p_password_number in number,
                             p_max in number default 0) return number;
  function last_closing_date (p_company_code in number, p_password_number in number) return date;

  type t_close_line is record (
    seq            number,
    account_number number,
    entry_desc     varchar2(2000),
    entry_desc_e   varchar2(2000),
    value          number,
    close_value    number,
    cost_code      number,
    cost_code2     number);
  type t_close_lines is table of t_close_line;

  -- the lines create_closing_entry would write for this date (empty when not computable)
  function closing_preview (p_close_date in date, p_company_code in number, p_password_number in number)
    return t_close_lines pipelined;

  -- text of the last result message (also set into apex_application.g_print_success_message)
  function last_message return varchar2;

end app_proc_gl;
/

create or replace package body app_proc_gl as

  g_msg varchar2(4000);

  e_busy exception;
  pragma exception_init(e_busy, -54);

  type t_key is record (entry_year number, entry_type number, entry_no number, entry_date date,
                        currency_code number, doc_no number);
  type t_keys is table of t_key;
  type t_errs is table of ac_updt_tbl%rowtype;

  -- ---------------------------------------------------------------------------------------------------
  -- small utilities
  -- ---------------------------------------------------------------------------------------------------
  function is_en return boolean is
  begin
    return lower(nvl(v('G_LANG'), 'ar')) = 'en';
  end is_en;

  function msg (p_a in varchar2, p_e in varchar2 default null) return varchar2 is
  begin
    return case when is_en and p_e is not null then p_e else p_a end;
  end msg;

  procedure fail (p_code in pls_integer, p_a in varchar2, p_e in varchar2 default null) is
  begin
    raise_application_error(p_code, substrb(msg(p_a, p_e), 1, 2000));
  end fail;

  -- the page's static success text (if any) is appended by APEX after this one; the message travels in the
  -- branch URL, so it is kept short
  procedure set_message (p_text in varchar2) is
  begin
    g_msg := substr(p_text, 1, 4000);
    if v('APP_ID') is not null then
      apex_application.g_print_success_message := substr(g_msg, 1, 700) || ' ';
    end if;
  end set_message;

  function last_message return varchar2 is
  begin
    return g_msg;
  end last_message;

  function key_text (p_year in number, p_type in number, p_no in number) return varchar2 is
  begin
    return p_year || '/' || p_type || '/' || p_no;
  end key_text;

  -- ORA-20xxx text without the "ORA-nnnnn: " prefix and the error stack
  function clean_sqlerrm return varchar2 is
    l varchar2(4000) := sqlerrm;
  begin
    l := regexp_replace(l, '^ORA-[0-9]+: ', '');
    l := regexp_replace(l, chr(10) || 'ORA-.*$', '', 1, 0, 'n');
    return substr(l, 1, 300);
  end clean_sqlerrm;

  procedure require (p_value in varchar2, p_a in varchar2, p_e in varchar2) is
  begin
    if p_value is null then
      fail(-20101, p_a, p_e);
    end if;
  end require;

  procedure require_session (p_company_code in number, p_user_code in number) is
  begin
    require(p_company_code, 'لم يتم تحديد الشركة', 'Company is not set');
    require(p_user_code, 'لم يتم تحديد المستخدم', 'User is not set');
  end require_session;

  function basic_row (p_company_code in number, p_lock in boolean default false) return ac_basic%rowtype is
    b ac_basic%rowtype;
  begin
    if p_lock then
      select * into b from ac_basic where company_code = p_company_code for update;
    else
      select * into b from ac_basic where company_code = p_company_code;
    end if;
    return b;
  exception
    when no_data_found then
      fail(-20102, 'بيانات النظام (AC_BASIC) غير معرفة لهذه الشركة', 'GL system parameters (AC_BASIC) are missing for this company');
  end basic_row;

  -- ---------------------------------------------------------------------------------------------------
  -- public helpers
  -- ---------------------------------------------------------------------------------------------------
  function current_year (p_company_code in number) return number is
    l number;
  begin
    select current_year into l from ac_basic where company_code = p_company_code;
    return nvl(l, to_number(to_char(sysdate, 'YYYY')));
  exception
    when no_data_found then
      return to_number(to_char(sysdate, 'YYYY'));
  end current_year;

  function type_allowed (p_entry_year in number, p_entry_type in number,
                         p_company_code in number, p_password_number in number) return number is
    l_n number;
  begin
    if p_password_number = 0 then
      return 1;
    end if;
    if p_password_number is null or p_company_code is null then
      return 0;
    end if;
    select count(*) into l_n
      from ac_password_entry
     where company_code = p_company_code
       and entry_year = p_entry_year
       and entry_type = p_entry_type
       and password_number = p_password_number;
    return case when l_n > 0 then 1 else 0 end;
  end type_allowed;

  -- legacy voucher key: LPAD(year,4)||LPAD(type,4)||LPAD(no,6)
  function voucher_key (p_year in number, p_type in number, p_no in number) return varchar2 is
  begin
    return lpad(to_char(p_year), 4, '0') || lpad(to_char(p_type), 4, '0') || lpad(to_char(p_no), 6, '0');
  end voucher_key;

  function in_range (p_year in number, p_type in number, p_no in number,
                     p_from_year in number, p_from_type in number, p_from_no in number,
                     p_to_year in number, p_to_type in number, p_to_no in number) return number is
    l_k varchar2(20) := voucher_key(p_year, p_type, p_no);
  begin
    if l_k >= voucher_key(nvl(p_from_year, 0), nvl(p_from_type, 0), nvl(p_from_no, 0))
       and l_k <= voucher_key(nvl(p_to_year, 9999), nvl(p_to_type, 9999), nvl(p_to_no, 999999)) then
      return 1;
    end if;
    return 0;
  end in_range;

  -- legacy default of FROM_TYPE / TO_TYPE: MIN/MAX(ENTRY_TYPE) of the daily entries of the year
  function daily_type_bound (p_year in number, p_company_code in number, p_password_number in number,
                             p_max in number default 0) return number is
    l number;
  begin
    select case when p_max = 1 then max(entry_type) else min(entry_type) end
      into l
      from ac_daily_trn
     where entry_year = p_year
       and type_allowed(entry_year, entry_type, p_company_code, p_password_number) = 1;
    return l;
  end daily_type_bound;

  function last_closing_date (p_company_code in number, p_password_number in number) return date is
    l date;
  begin
    select max(entry_date) into l
      from ac_yearly_trn
     where close_flag = 1
       and (p_password_number = 0
            or (create_company_code = p_company_code and create_password_number = p_password_number));
    return l;
  end last_closing_date;

  -- CHR_STRU_END of the chart level of an account (prefix length used by ACCLOSE)
  function end_pos (p_account in number) return number is
    l number;
  begin
    select c.chr_stru_end into l
      from ac_master m
      join ac_chart_structures c on c.chr_stru_level = m.account_level
     where m.account_number = p_account;
    return l;
  exception
    when no_data_found then
      fail(-20130, 'مؤشرات النظام غير مكتملة', 'The system parameter is not completed');
  end end_pos;

  -- ---------------------------------------------------------------------------------------------------
  -- ACUPDT : posting
  -- ---------------------------------------------------------------------------------------------------
  procedure save_post_errors (p_keys in t_keys, p_errs in t_errs) is
    pragma autonomous_transaction;
  begin
    -- results of this run replace the previous results of the same entries; results of entries that are
    -- no longer waiting in AC_DAILY_TRN are dropped (legacy: DELETE FROM AC_UPDT_TBL, whole table)
    for i in 1 .. p_keys.count loop
      delete from ac_updt_tbl
       where entry_year = p_keys(i).entry_year and entry_type = p_keys(i).entry_type and entry_no = p_keys(i).entry_no;
    end loop;
    delete from ac_updt_tbl u
     where not exists (select 1 from ac_daily_trn t
                        where t.entry_year = u.entry_year and t.entry_type = u.entry_type and t.entry_no = u.entry_no);
    for i in 1 .. p_errs.count loop
      insert into ac_updt_tbl values p_errs(i);
    end loop;
    commit;
  end save_post_errors;

  -- UPDATE_PROC (ACUPDT and ACDLYTR): currency-difference line of a foreign-currency entry. The legacy summed the
  -- lines (ROUND(VALUE,2) * RATE) into NUMBER(14,2) debit / credit totals and, when CURRENCY_CODE <> 1 and the totals
  -- differ, wrote line SEQ 999 on AC_BASIC.CURRENCY_ACCT with VALUE = -debit + credit and BALANCE_FLAG = 1.
  -- Reads the daily lines, so it runs before they are deleted.
  procedure currency_diff_line (p_year in number, p_type in number, p_no in number, p_company_code in number,
                                p_msg_a in varchar2) is
    h        ac_daily_trn%rowtype;
    l_debit  number(14,2) := 0;
    l_credit number(14,2) := 0;
    l_acct   ac_master.account_number%type;
    l_name   ac_master.account_name%type;
    l_name_e ac_master.account_name_e%type;
  begin
    select * into h from ac_daily_trn where entry_year = p_year and entry_type = p_type and entry_no = p_no;
    for d in (select value from ac_daily_trn_det
               where entry_year = p_year and entry_type = p_type and entry_no = p_no order by seq)
    loop
      if d.value > 0 then
        l_debit := l_debit + (round(d.value, 2) * h.rate);
      else
        l_credit := l_credit - (round(d.value, 2) * h.rate);
      end if;
    end loop;
    if h.currency_code != 1 and l_debit != l_credit then
      begin
        select currency_acct into l_acct from ac_basic where company_code = p_company_code;
        select account_name, account_name_e into l_name, l_name_e from ac_master where account_number = l_acct;
      exception when no_data_found then
        fail(-20113, p_msg_a, 'Currency differences account is not set in system parameters');
      end;
      insert into ac_yearly_trn_det
        (entry_year, entry_type, entry_no, seq, account_number, entry_date, entry_desc, entry_desc_e, value, cost_code,
         cost_code2, close_value, balance_flag, memo, memo_e, create_company_code, create_password_number, create_user_code,
         create_date, update_company_code, update_user_code, update_password_number, update_date)
      values
        (h.entry_year, h.entry_type, h.entry_no, 999, l_acct, h.entry_date, l_name, l_name_e, (-l_debit + l_credit), null,
         null, 0, 1, null, null, h.create_company_code, h.create_password_number, h.create_user_code,
         h.create_date, h.update_company_code, h.update_user_code, h.update_password_number, h.update_date);
    end if;
  end currency_diff_line;

  procedure post_entries (
    p_from_year       in number,
    p_to_year         in number,
    p_from_type       in number,
    p_to_type         in number,
    p_from_no         in number default null,
    p_to_no           in number default null,
    p_from_doc_no     in number default null,
    p_to_doc_no       in number default null,
    p_from_date       in date   default null,
    p_to_date         in date   default null,
    p_test_only       in number default 0,
    p_company_code    in number,
    p_user_code       in number,
    p_password_number in number)
  is
    l_from  varchar2(20);
    l_to    varchar2(20);
    l_keys  t_keys;
    l_errs  t_errs := t_errs();
    b       ac_basic%rowtype;
    l_sum   number;
    l_n     number;
    l_txt   varchar2(4000);

    procedure add_err (p_k in t_key, p_seq in number, p_acct in number, p_a in varchar2, p_e in varchar2) is
    begin
      l_errs.extend;
      l_errs(l_errs.count).entry_year := p_k.entry_year;
      l_errs(l_errs.count).entry_type := p_k.entry_type;
      l_errs(l_errs.count).entry_no   := p_k.entry_no;
      l_errs(l_errs.count).seq        := p_seq;
      l_errs(l_errs.count).account_no := p_acct;
      l_errs(l_errs.count).message    := substr(msg(p_a, p_e), 1, 50);
    end add_err;
  begin
    if p_from_year is null or p_to_year is null or p_from_type is null or p_to_type is null then
      fail(-20101, 'من فضلك تأكد من إدخال نوع القيد من و إلى و إدخال سنة القيد من و إلى',
                   'You must enter from year, to year, from type and to type');
    end if;
    require_session(p_company_code, p_user_code);
    b := basic_row(p_company_code);

    l_from := voucher_key(p_from_year, p_from_type, nvl(p_from_no, 0));
    l_to   := voucher_key(p_to_year, p_to_type, nvl(p_to_no, 999999));

    -- the daily entries of the range, locked while they are tested and moved
    begin
      select t.entry_year, t.entry_type, t.entry_no, t.entry_date, t.currency_code, t.doc_no
        bulk collect into l_keys
        from ac_daily_trn t
       where voucher_key(t.entry_year, t.entry_type, t.entry_no) >= l_from
         and voucher_key(t.entry_year, t.entry_type, t.entry_no) <= l_to
         and (t.doc_no >= p_from_doc_no or p_from_doc_no is null)
         and (t.doc_no <= p_to_doc_no or p_to_doc_no is null)
         and (t.entry_date >= p_from_date or p_from_date is null)
         and (t.entry_date <= p_to_date or p_to_date is null)
         and type_allowed(t.entry_year, t.entry_type, p_company_code, p_password_number) = 1
       order by t.entry_year, t.entry_type, t.entry_no
         for update nowait;
    exception
      when e_busy then
        fail(-20103, 'بعض القيود فى النطاق المحدد مفتوحة للتعديل من مستخدم آخر، حاول لاحقاً',
                     'Some entries of the range are being edited by another user, try again later');
    end;
    if l_keys.count = 0 then
      fail(-20111, 'لا توجد قيود يومية غير مرحلة فى النطاق المحدد', 'There are no daily entries in the specified range');
    end if;

    -- TEST_PROC: one message per wrong line / entry (legacy AC_UPDT_TBL texts)
    for i in 1 .. l_keys.count loop
      l_sum := 0;
      for d in (select d.seq, d.account_number, d.value, d.cost_code, d.cost_code2,
                       m.account_number m_acct, m.account_status, m.currency_code m_curr,
                       (select count(*) from ac_cost_centers c where c.cost_code = d.cost_code) cc1,
                       (select count(*) from ac_cost_centers2 c where c.cost_code = d.cost_code2) cc2
                  from ac_daily_trn_det d
                  left join ac_master m on m.account_number = d.account_number
                 where d.entry_year = l_keys(i).entry_year
                   and d.entry_type = l_keys(i).entry_type
                   and d.entry_no = l_keys(i).entry_no
                 order by d.seq)
      loop
        if d.m_acct is null then
          add_err(l_keys(i), d.seq, d.account_number, 'رقم الحساب غير موجود', 'Account does not exist');
        elsif d.account_status <> 1 then
          add_err(l_keys(i), d.seq, d.account_number, 'الحســاب ليس على أدنى مستــوى', 'Account not a less level');
        elsif d.m_curr <> l_keys(i).currency_code then
          add_err(l_keys(i), d.seq, d.account_number, 'العملة المحددة للحسـاب غير تلك المستخدمة فى القيد',
                  'Account currency not similar to entry currency');
        elsif d.cost_code is not null and d.cc1 = 0 then
          -- AC_YEARLY_TRN_DET.COST_CODE has a FK to AC_COST_CENTERS (AC_DAILY_TRN_DET has none)
          add_err(l_keys(i), d.seq, d.account_number, 'مركز التكلفة 1 غير موجود', 'Cost center 1 does not exist');
        elsif d.cost_code2 is not null and d.cc2 = 0 then
          add_err(l_keys(i), d.seq, d.account_number, 'مركز التكلفة 2 غير موجود', 'Cost center 2 does not exist');
        end if;
        l_sum := l_sum + nvl(d.value, 0);
      end loop;

      if l_keys(i).entry_date <= b.close_date then
        add_err(l_keys(i), -1, null, 'يجب أن يكون تاريخ القيد أكبر من تاريخ الأقفال',
                'Entry date must be after the last closing date');
      end if;
      if round(l_sum, 2) <> 0 then
        add_err(l_keys(i), -2, null, 'الجانب المدين لا يساوى الجانب الدائن', 'Debit Side is not Equal to Credit Side.');
      end if;
      select count(*) into l_n
        from ac_yearly_trn y
       where y.entry_year = l_keys(i).entry_year and y.entry_type = l_keys(i).entry_type and y.entry_no = l_keys(i).entry_no;
      if l_n > 0 then
        add_err(l_keys(i), -3, null, 'القيد مكرر فى ملف القيود اليومية و الفورية', 'Voucher number duplicated in Instant and Daily Voucher Books');
      end if;
    end loop;

    save_post_errors(l_keys, l_errs);

    if l_errs.count > 0 then
      for i in 1 .. least(l_errs.count, 5) loop
        l_txt := l_txt || ' | ' || key_text(l_errs(i).entry_year, l_errs(i).entry_type, l_errs(i).entry_no)
                 || case when l_errs(i).seq > 0 then ' #' || l_errs(i).seq end
                 || case when l_errs(i).account_no is not null then ' (' || l_errs(i).account_no || ')' end
                 || ': ' || l_errs(i).message;
      end loop;
      if l_errs.count > 5 then
        l_txt := l_txt || ' | ...';
      end if;
      fail(-20110, 'يوجد خطأ ببعض القيود فى النطاق المحدد، راجع أخطاء الترحيل (' || l_errs.count || ')' || l_txt,
                   'There is an error in some vouchers in the specified range, review the posting errors (' || l_errs.count || ')' || l_txt);
    end if;

    if p_test_only = 1 then
      set_message(msg('لا توجد أخطاء في قيود الترحيل (' || l_keys.count || ' قيد). لم يتم الترحيل (اختبار فقط).',
                      'No errors in the ' || l_keys.count || ' vouchers. Nothing posted (test only).'));
      return;
    end if;

    -- UPDATE_PROC: move header + lines, then delete the daily entry
    for i in 1 .. l_keys.count loop
      begin
        insert into ac_yearly_trn
          (entry_year, entry_type, entry_no, doc_no, entry_date, entry_desc, entry_desc_e, currency_code, rate,
           entry_total, close_flag, memo, memo_e, create_company_code, create_password_number, create_user_code,
           create_date, update_company_code, update_password_number, update_user_code, update_date, post_system, post_user)
        select entry_year, entry_type, entry_no, doc_no, entry_date, entry_desc, entry_desc_e, currency_code, rate,
               entry_total, 0, memo, memo_e, create_company_code, create_password_number, create_user_code,
               create_date, update_company_code, update_password_number, update_user_code, update_date, 1, p_user_code
          from ac_daily_trn
         where entry_year = l_keys(i).entry_year and entry_type = l_keys(i).entry_type and entry_no = l_keys(i).entry_no;

        insert into ac_yearly_trn_det
          (entry_year, entry_type, entry_no, seq, account_number, entry_date, entry_desc, entry_desc_e, value,
           cost_code, cost_code2, close_value, balance_flag, memo, memo_e, create_company_code, create_password_number,
           create_user_code, create_date, update_company_code, update_user_code, update_password_number, update_date,
           auto_trns_flag, tax_flag, tax_account, cust_name, cust_tax_no, cust_inv_no, cust_inv_val, cust_notes,
           cust_inv_date, t_tax_flag1, cust_code, tax_trns_date, tax_invoice_no)
        select entry_year, entry_type, entry_no, seq, account_number, l_keys(i).entry_date, entry_desc, entry_desc_e, value,
               cost_code, cost_code2, 0, balance_flag, memo, memo_e, create_company_code, create_password_number,
               create_user_code, create_date, update_company_code, update_user_code, update_password_number, update_date,
               auto_trns_flag, tax_flag, tax_account, cust_name, cust_tax_no, cust_inv_no, cust_inv_val, cust_notes,
               cust_inv_date, t_tax_flag1, cust_code, tax_trns_date, tax_invoice_no
          from ac_daily_trn_det
         where entry_year = l_keys(i).entry_year and entry_type = l_keys(i).entry_type and entry_no = l_keys(i).entry_no;

        -- currency-difference line (SEQ 999) of a foreign-currency entry
        currency_diff_line(l_keys(i).entry_year, l_keys(i).entry_type, l_keys(i).entry_no, p_company_code,
                           'لابد من تعريف حساب فروق العملة ببيانات النظام');

        delete from ac_daily_trn_det
         where entry_year = l_keys(i).entry_year and entry_type = l_keys(i).entry_type and entry_no = l_keys(i).entry_no;
        delete from ac_daily_trn
         where entry_year = l_keys(i).entry_year and entry_type = l_keys(i).entry_type and entry_no = l_keys(i).entry_no;
      exception
        when others then
          if sqlcode = -20113 then
            raise;
          end if;
          if sqlcode between -20999 and -20000 or sqlcode in (-1, -2291, -2292) then
            fail(-20112, 'تعذر ترحيل القيد ' || key_text(l_keys(i).entry_year, l_keys(i).entry_type, l_keys(i).entry_no)
                         || ' ولم يتم ترحيل أى قيد: ' || clean_sqlerrm,
                         'Voucher ' || key_text(l_keys(i).entry_year, l_keys(i).entry_type, l_keys(i).entry_no)
                         || ' could not be posted, nothing was posted: ' || clean_sqlerrm);
          end if;
          raise;
      end;
    end loop;

    set_message(msg('لقد تم ترحيل القيود فى النطاق المحدد بنجـــاح (' || l_keys.count || ' قيد).',
                    'The vouchers in the specified range are posted successfully (' || l_keys.count || ').'));
  end post_entries;

  -- ---------------------------------------------------------------------------------------------------
  -- ACCUPDT : cancel posting
  -- ---------------------------------------------------------------------------------------------------
  procedure cancel_posting (
    p_from_year       in number,
    p_to_year         in number,
    p_from_type       in number,
    p_to_type         in number,
    p_from_no         in number default null,
    p_to_no           in number default null,
    p_from_doc_no     in number default null,
    p_to_doc_no       in number default null,
    p_from_date       in date   default null,
    p_to_date         in date   default null,
    p_company_code    in number,
    p_user_code       in number,
    p_password_number in number)
  is
    b       ac_basic%rowtype;
    l_from  varchar2(20);
    l_to    varchar2(20);
    l_keys  t_keys;
    l_ok    pls_integer := 0;
    l_bad   pls_integer := 0;
    l_txt   varchar2(4000);
    l_n     number;

    procedure note (p_k in t_key, p_text in varchar2) is
    begin
      l_bad := l_bad + 1;
      if l_bad <= 8 then
        l_txt := substr(l_txt || ' | ' || key_text(p_k.entry_year, p_k.entry_type, p_k.entry_no) || ': ' || p_text, 1, 1500);
      elsif l_bad = 9 then
        l_txt := l_txt || ' | ...';
      end if;
    end note;
  begin
    if p_from_year is null or p_to_year is null or p_from_type is null or p_to_type is null then
      fail(-20101, 'من فضلك تأكد من إدخال نوع القيد من و إلى و إدخال سنة القيد من و إلى',
                   'You must enter from year, to year, from type and to type');
    end if;
    require_session(p_company_code, p_user_code);
    b := basic_row(p_company_code);

    -- COST_BAL_FLAG_PROC
    if nvl(b.cost_code1_bal, 0) = 1 and b.cost_code_acct1 is null then
      fail(-20120, 'رقم حساب جارى مراكز التكلفة 1 غير موجود فى مؤشرات النظام !!',
                   'Current Account Number Cost Centers 1 Not Found In The System Parameter!!');
    end if;
    if nvl(b.cost_code2_bal, 0) = 1 and b.cost_code_acct2 is null then
      fail(-20121, 'رقم حساب جارى مراكز التكلفة  2 غير موجود فى مؤشرات النظام !!',
                   'Current Account Number Cost Centers 2 Not Found In The System Parameter!!');
    end if;

    l_from := voucher_key(p_from_year, p_from_type, nvl(p_from_no, 0));
    l_to   := voucher_key(p_to_year, p_to_type, nvl(p_to_no, 999999));

    begin
      select y.entry_year, y.entry_type, y.entry_no, y.entry_date, y.currency_code, y.doc_no
        bulk collect into l_keys
        from ac_yearly_trn y
       where voucher_key(y.entry_year, y.entry_type, y.entry_no) >= l_from
         and voucher_key(y.entry_year, y.entry_type, y.entry_no) <= l_to
         and (y.doc_no >= p_from_doc_no or p_from_doc_no is null)
         and (y.doc_no <= p_to_doc_no or p_to_doc_no is null)
         and (y.entry_date >= p_from_date or p_from_date is null)
         and (y.entry_date <= p_to_date or p_to_date is null)
         and nvl(y.close_flag, 0) != 1
         and nvl(y.post_system, 0) = 1
         and type_allowed(y.entry_year, y.entry_type, p_company_code, p_password_number) = 1
       order by y.entry_year, y.entry_type, y.entry_no
         for update nowait;
    exception
      when e_busy then
        fail(-20103, 'بعض القيود فى النطاق المحدد مفتوحة للتعديل من مستخدم آخر، حاول لاحقاً',
                     'Some entries of the range are being edited by another user, try again later');
    end;
    if l_keys.count = 0 then
      fail(-20122, 'لا توجد قيود مرحلة من الحسابات العامة فى النطاق المحدد لإلغاء ترحيلها',
                   'There are no GL posted vouchers in the specified range');
    end if;

    for i in 1 .. l_keys.count loop
      if l_keys(i).entry_date <= b.close_date then
        note(l_keys(i), msg('لا يمكن إلغاء ترحيل الحركة لأنها تقع فى فترة مقفلة', 'cannot be unposted because it lies in a closed period'));
        continue;
      end if;
      select count(*) into l_n
        from ac_daily_trn t
       where t.entry_year = l_keys(i).entry_year and t.entry_type = l_keys(i).entry_type and t.entry_no = l_keys(i).entry_no;
      if l_n > 0 then
        note(l_keys(i), msg('القيد مكرر فى ملف القيود اليومية و الفورية', 'Voucher number duplicated in Instant and Daily Voucher Books'));
        continue;
      end if;

      savepoint sp_unpost;
      begin
        insert into ac_daily_trn
          (entry_year, entry_type, entry_no, doc_no, entry_date, entry_desc, entry_desc_e, currency_code, rate,
           entry_total, memo, memo_e, create_company_code, create_password_number, create_user_code, create_date,
           update_company_code, update_password_number, update_user_code, update_date)
        select entry_year, entry_type, entry_no, doc_no, entry_date, entry_desc, entry_desc_e, currency_code, rate,
               entry_total, memo, memo_e, create_company_code, create_password_number, create_user_code, create_date,
               update_company_code, update_password_number, update_user_code, update_date
          from ac_yearly_trn
         where entry_year = l_keys(i).entry_year and entry_type = l_keys(i).entry_type and entry_no = l_keys(i).entry_no;

        insert into ac_daily_trn_det
          (entry_year, entry_type, entry_no, seq, account_number, entry_desc, entry_desc_e, value, cost_code, cost_code2,
           balance_flag, memo, memo_e, create_company_code, create_password_number, create_user_code, create_date,
           update_company_code, update_user_code, update_password_number, update_date, auto_trns_flag, tax_flag,
           tax_account, cust_name, cust_tax_no, cust_inv_no, cust_inv_val, cust_notes, cust_inv_date, t_tax_flag1,
           cust_code, tax_trns_date, tax_invoice_no)
        select entry_year, entry_type, entry_no, seq, account_number, entry_desc, entry_desc_e, value, cost_code, cost_code2,
               balance_flag, memo, memo_e, create_company_code, create_password_number, create_user_code, create_date,
               update_company_code, update_user_code, update_password_number, update_date, auto_trns_flag, tax_flag,
               tax_account, cust_name, cust_tax_no, cust_inv_no, cust_inv_val, cust_notes, cust_inv_date, t_tax_flag1,
               cust_code, tax_trns_date, tax_invoice_no
          from ac_yearly_trn_det
         where entry_year = l_keys(i).entry_year and entry_type = l_keys(i).entry_type and entry_no = l_keys(i).entry_no;

        delete from ac_yearly_trn_det
         where entry_year = l_keys(i).entry_year and entry_type = l_keys(i).entry_type and entry_no = l_keys(i).entry_no;
        delete from ac_yearly_trn
         where entry_year = l_keys(i).entry_year and entry_type = l_keys(i).entry_type and entry_no = l_keys(i).entry_no;

        -- AC_BASIC.DEL_BAL_SIDES = 1: drop the automatic cost-centre balancing lines (legacy literal texts)
        if nvl(b.del_bal_sides, 0) = 1 then
          if b.cost_code_acct1 is not null then
            delete from ac_daily_trn_det
             where entry_year = l_keys(i).entry_year and entry_type = l_keys(i).entry_type and entry_no = l_keys(i).entry_no
               and account_number = b.cost_code_acct1
               and entry_desc in ('حساب جارى مراكز التكلفة 1')
               and memo in ('طرف آلى لكى يتوازن القيد على مستوى مركز التكلفة 1');
          end if;
          if b.cost_code_acct2 is not null then
            delete from ac_daily_trn_det
             where entry_year = l_keys(i).entry_year and entry_type = l_keys(i).entry_type and entry_no = l_keys(i).entry_no
               and account_number = b.cost_code_acct2
               and entry_desc in ('حساب جارى مراكز التكلفة 2 ')
               and memo in ('طرف آلى لكى يتوازن القيد على مستوى مركز التكلفة 2');
          end if;
        end if;
        l_ok := l_ok + 1;
      exception
        when others then
          -- refused by a DB trigger (tax period authorised, revision flag, zero value line, ...)
          rollback to sp_unpost;
          note(l_keys(i), clean_sqlerrm);
      end;
    end loop;

    if l_ok = 0 then
      fail(-20123, 'لم يتم إلغاء ترحيل أى قيد' || l_txt, 'No voucher was unposted' || l_txt);
    elsif l_bad > 0 then
      set_message(msg('تم إلغاء ترحيل ' || l_ok || ' من ' || l_keys.count || ' قيد. يوجد خطأ ببعض القيود فى النطاق المحدد' || l_txt,
                      l_ok || ' of ' || l_keys.count || ' vouchers unposted. There is an error in some vouchers' || l_txt));
    else
      set_message(msg('لقد تم إلغاء ترحيل القيود فى النطاق المحدد بنجـــاح (' || l_ok || ' قيد).',
                      'The vouchers in the specified range were unposted successfully (' || l_ok || ').'));
    end if;
  end cancel_posting;

  -- ---------------------------------------------------------------------------------------------------
  -- ACCLOSE : closing entry
  -- ---------------------------------------------------------------------------------------------------
  function closing_lines (p_close_date in date, p_company_code in number, p_password_number in number)
    return t_close_lines
  is
    b        ac_basic%rowtype := basic_row(p_company_code);
    l_raw    t_close_lines := t_close_lines();
    l_out    t_close_lines := t_close_lines();
    l_acct   number;
    l_end    number;
    l_first  pls_integer;
    l_done   boolean;
    l_debit  number := 0;
    l_credit number := 0;
    l_pa     ac_master%rowtype;

    procedure add_line (p_acct in number, p_a in varchar2, p_e in varchar2, p_value in number, p_close in number,
                        p_c1 in number, p_c2 in number) is
    begin
      l_raw.extend;
      l_raw(l_raw.count).account_number := p_acct;
      l_raw(l_raw.count).entry_desc     := p_a;
      l_raw(l_raw.count).entry_desc_e   := p_e;
      l_raw(l_raw.count).value          := p_value;
      l_raw(l_raw.count).close_value    := p_close;
      l_raw(l_raw.count).cost_code      := p_c1;
      l_raw(l_raw.count).cost_code2     := p_c2;
    end add_line;
  begin
    if b.income1_acct is null or b.outcome1_acct is null or b.profit_acct is null then
      fail(-20130, 'مؤشرات النظام غير مكتملة', 'The system parameter is not completed');
    end if;
    begin
      select * into l_pa from ac_master where account_number = b.profit_acct;
    exception
      when no_data_found then
        fail(-20130, 'مؤشرات النظام غير مكتملة', 'The system parameter is not completed');
    end;
    if nvl(l_pa.currency_code, 1) <> 1 then
      fail(-20139, 'حساب الأرباح والخسائر بعملة أجنبية، هذه الحالة غير مدعومة', 'The profit account is in a foreign currency (not supported)');
    end if;

    -- income accounts first, then expense accounts (legacy CLOSE_ENTRY_PROC order)
    for g in 1 .. 2 loop
      l_acct := case g when 1 then b.income1_acct else b.outcome1_acct end;
      l_end  := end_pos(l_acct);
      for x in (select m.account_number, m.account_name, m.account_name_e, m.currency_code, m.begin_period_loc
                  from ac_master m
                 where m.account_status = 1
                   and rpad(substr(to_char(m.account_number), 1, l_end), 12, '0') = to_char(l_acct)
                   and (p_password_number = 0
                        or m.account_number in (
                             select m2.account_number
                               from ac_master m2, ac_password_master p2
                              where p2.company_code = p_company_code
                                and rpad(substr(to_char(p2.account_number), 1, p2.account_end_pos), 12, '0')
                                  = rpad(substr(to_char(m2.account_number), 1, p2.account_end_pos), 12, '0')))
                 order by m.account_number)
      loop
        if nvl(x.currency_code, 1) <> 1 then
          -- legacy had a separate foreign-currency branch (CLOSE_VALUE in account currency) that could not be
          -- verified; refuse instead of guessing (no such account exists on this schema)
          fail(-20139, 'الحساب ' || x.account_number || ' بعملة أجنبية، إقفال الحسابات بعملة أجنبية غير مدعوم حالياً',
                       'Account ' || x.account_number || ' is in a foreign currency: closing it is not supported');
        end if;
        l_first := l_raw.count + 1;
        for s in (select sum(d.value * nvl(y.rate, 1)) val, d.cost_code, d.cost_code2
                    from ac_yearly_trn y
                    join ac_yearly_trn_det d
                      on d.entry_year = y.entry_year and d.entry_type = y.entry_type and d.entry_no = y.entry_no
                   where y.entry_date <= p_close_date
                     and (p_password_number = 0 or y.create_company_code = p_company_code)
                     and d.account_number = x.account_number
                     and d.value != 0
                   group by d.cost_code, d.cost_code2
                   order by d.cost_code nulls first, d.cost_code2 nulls first)
        loop
          if round(nvl(s.val, 0), 2) <> 0 then
            add_line(x.account_number, x.account_name, x.account_name_e, -round(s.val, 2), -round(s.val, 2), s.cost_code, s.cost_code2);
          end if;
        end loop;
        -- opening balance kept on AC_MASTER (legacy: UPDATE TEMP_CLOSE SET VALUE = VALUE - BEGIN_PERIOD_LOC
        -- on the line without cost centres); 0 for every account on this schema
        if nvl(x.begin_period_loc, 0) <> 0 then
          l_done := false;
          for i in l_first .. l_raw.count loop
            if l_raw(i).cost_code is null and l_raw(i).cost_code2 is null then
              l_raw(i).value := l_raw(i).value - x.begin_period_loc;
              l_done := true;
            end if;
          end loop;
          if not l_done then
            add_line(x.account_number, x.account_name, x.account_name_e, -x.begin_period_loc, -x.begin_period_loc, null, null);
          end if;
        end if;
      end loop;
    end loop;

    if l_raw.count = 0 then
      return l_out;
    end if;

    for i in 1 .. l_raw.count loop
      if l_raw(i).value > 0 then
        l_debit := l_debit + l_raw(i).value;
      else
        l_credit := l_credit - l_raw(i).value;
      end if;
    end loop;
    -- profit / loss line balances the entry: TOTAL_CREDIT - TOTAL_DEBIT
    if l_credit - l_debit <> 0 then
      add_line(b.profit_acct, l_pa.account_name, l_pa.account_name_e, l_credit - l_debit, l_credit - l_debit, null, null);
    end if;

    -- legacy wrote TEMP_CLOSE WHERE VALUE > 0 first, then WHERE VALUE < 0
    for pass in 1 .. 2 loop
      for i in 1 .. l_raw.count loop
        if (pass = 1 and l_raw(i).value > 0) or (pass = 2 and l_raw(i).value < 0) then
          l_out.extend;
          l_out(l_out.count) := l_raw(i);
          l_out(l_out.count).seq := l_out.count;
        end if;
      end loop;
    end loop;
    return l_out;
  end closing_lines;

  function closing_preview (p_close_date in date, p_company_code in number, p_password_number in number)
    return t_close_lines pipelined
  is
    l t_close_lines;
  begin
    if p_close_date is null or p_company_code is null then
      return;
    end if;
    l := closing_lines(trunc(p_close_date), p_company_code, p_password_number);
    for i in 1 .. l.count loop
      pipe row (l(i));
    end loop;
    return;
  exception
    when no_data_needed then
      raise;
    when others then
      if sqlcode between -20199 and -20100 then
        return;
      end if;
      raise;
  end closing_preview;

  procedure create_closing_entry (
    p_entry_year      in number,
    p_entry_type      in number,
    p_close_date      in date,
    p_company_code    in number,
    p_user_code       in number,
    p_password_number in number)
  is
    b          ac_basic%rowtype;
    l_date     date := trunc(p_close_date);
    l_lines    t_close_lines;
    l_no       number;
    l_total    number := 0;
    l_n        number;
    l_end_in   number;
    l_end_out  number;
    l_warn     varchar2(2000);
    l_dummy    number;
  begin
    require(p_entry_year, 'يجب إدخال سنة قيد الإقفال', 'Closing entry year is required');
    require(p_entry_type, 'يجب إدخال رقم الحركة (اليومية) لقيد الإقفال', 'Closing entry type is required');
    require(p_close_date, 'يجب إدخال تاريخ الإقفال', 'Closing date is required');
    require_session(p_company_code, p_user_code);

    -- one closing at a time (legacy: LOCK TABLE TEMP_CLOSE, AC_TRN_CODES IN EXCLUSIVE MODE)
    b := basic_row(p_company_code, p_lock => true);
    if b.income1_acct is null or b.outcome1_acct is null or b.profit_acct is null then
      fail(-20130, 'مؤشرات النظام غير مكتملة', 'The system parameter is not completed');
    end if;

    -- CHECK_DATE (TRANSLATE.pll, system 1): not in the future, not before AC_BASIC.MIN_DATE
    if l_date > trunc(sysdate) then
      fail(-20131, 'تاريخ الحركة أكبر من تاريخ اليوم', 'Transaction Date is greater than today''s date');
    end if;
    if b.min_date is not null and l_date < trunc(b.min_date) then
      fail(-20132, 'الحد الأدنى لتاريخ الحركة هو ' || to_char(b.min_date, 'DD/MM/YYYY'),
                   'The least value accepted for Transaction Date is ' || to_char(b.min_date, 'DD/MM/YYYY'));
    end if;
    -- CLOSE_DATE item validation
    if b.close_date is not null and l_date <= b.close_date then
      fail(-20133, 'يجب إدخال تاريخ أكبر من آخر تاريخ إقفال (' || to_char(b.close_date, 'DD/MM/YYYY') || ')',
                   'The closing date must be after the last closing date (' || to_char(b.close_date, 'DD/MM/YYYY') || ')');
    end if;
    if to_number(to_char(l_date, 'YYYY')) < p_entry_year then
      fail(-20134, 'تاريخ الإقفال يقع فى سنة أقل من سنة قيد الإقفال المطلوب!!!', 'Closing Date Less Than Entry Year Required');
    end if;

    -- journal of the closing entry (LOV: AC_TRN_CODES of the year, AC_PASSWORD_ENTRY)
    begin
      select 1 into l_dummy
        from ac_trn_codes
       where entry_year = p_entry_year and entry_type = p_entry_type
         for update;
    exception
      when no_data_found then
        fail(-20135, 'رقم الحركة ' || p_entry_type || ' غير معرف لسنة ' || p_entry_year,
                     'Entry type ' || p_entry_type || ' is not defined for year ' || p_entry_year);
    end;
    if type_allowed(p_entry_year, p_entry_type, p_company_code, p_password_number) = 0 then
      fail(-20136, 'غير مسموح لمجموعتك باستخدام هذا النوع من القيود', 'Your group is not allowed to use this entry type');
    end if;

    -- CLOSE_ENTRY_PROC: unposted daily entries on income / expense accounts in the period block the closing
    l_end_in  := end_pos(b.income1_acct);
    l_end_out := end_pos(b.outcome1_acct);
    select count(1) into l_n
      from ac_daily_trn_det det, ac_daily_trn mast
     where mast.entry_year = det.entry_year
       and mast.entry_type = det.entry_type
       and mast.entry_no = det.entry_no
       and mast.entry_date > nvl(b.close_date, date '0001-01-01')
       and mast.entry_date <= l_date
       and (   rpad(substr(to_char(det.account_number), 1, l_end_in), 12, '0') = to_char(b.income1_acct)
            or rpad(substr(to_char(det.account_number), 1, l_end_out), 12, '0') = to_char(b.outcome1_acct))
       and (p_password_number = 0
            or det.account_number in (select p2.account_number from ac_password_master p2
                                       where p2.password_number = p_password_number and p2.company_code = p_company_code));
    if l_n > 0 then
      fail(-20137, 'لا يمكن عمل قيد اقفال بسبب وجود قيود بها حسابات مصروفات أو إيرادات غير مرحلة',
                   'The closing entry cannot be created: there are unposted entries on income or expense accounts');
    end if;

    -- CHECK_CLOSE_DATE / CHECK_CLOSE_STORES: warnings only (the 2025 closing was made with unposted ST documents)
    select count(*) into l_n from ac_daily_trn where entry_date <= l_date and create_company_code = p_company_code;
    if l_n > 0 then
      l_warn := l_warn || ' ' || msg('تنبيه: توجد قيود غير مرحلة قبل هذا التاريخ (' || l_n || ').', 'Warning: unposted GL entries before this date (' || l_n || ').');
    end if;
    select count(1) into l_n from ar_maintrns where nvl(post_flag, 0) = 0 and trns_date <= l_date;
    if l_n > 0 then
      l_warn := l_warn || ' ' || msg('تنبيه: توجد قيود غير مرحلة فى نظام العملاء قبل هذا التاريخ (' || l_n || ').', 'Warning: unposted customer transactions before this date (' || l_n || ').');
    end if;
    select count(1) into l_n from vn_maintrns where nvl(post_flag, 0) = 0 and trns_date <= l_date;
    if l_n > 0 then
      l_warn := l_warn || ' ' || msg('تنبيه: توجد قيود غير مرحلة فى نظام الموردين قبل هذا التاريخ (' || l_n || ').', 'Warning: unposted vendor transactions before this date (' || l_n || ').');
    end if;
    select count(1) into l_n from st_trns_mast where nvl(post_flag, 0) = 0 and trns_date <= l_date;
    if l_n > 0 then
      l_warn := l_warn || ' ' || msg('تنبيه: توجد قيود غير مرحلة فى نظام المخازن قبل هذا التاريخ (' || l_n || ').', 'Warning: unposted inventory transactions before this date (' || l_n || ').');
    end if;

    l_lines := closing_lines(l_date, p_company_code, p_password_number);
    if l_lines.count = 0 then
      fail(-20138, 'لا توجد أرصدة لحساب الايرادات أو المصروفات .... لم يتم انشاء قيد إقفال',
                   'There are not balances from income or expense account .... closing entry was not created');
    end if;
    for i in 1 .. l_lines.count loop
      if l_lines(i).value > 0 then
        l_total := l_total + l_lines(i).value;
      end if;
    end loop;

    l_no := calc_serial(p_entry_year, p_entry_type, l_date);

    begin
      insert into ac_yearly_trn
        (entry_year, entry_type, entry_no, doc_no, entry_date, entry_desc, entry_desc_e, currency_code, rate,
         entry_total, close_flag, memo, memo_e, create_company_code, create_password_number, create_user_code,
         create_date, post_system)
      values
        (p_entry_year, p_entry_type, l_no, l_no, l_date, 'قــيــــد الاقـفـــــــال', 'Closing Entry', 1, 1,
         l_total, 1, null, null, p_company_code, p_password_number, p_user_code,
         sysdate, 1);

      for i in 1 .. l_lines.count loop
        insert into ac_yearly_trn_det
          (entry_year, entry_type, entry_no, seq, account_number, entry_date, entry_desc, entry_desc_e, value,
           cost_code, cost_code2, close_value, balance_flag, memo, memo_e, create_company_code,
           create_password_number, create_user_code, create_date)
        values
          (p_entry_year, p_entry_type, l_no, l_lines(i).seq, l_lines(i).account_number, l_date,
           l_lines(i).entry_desc, l_lines(i).entry_desc_e, l_lines(i).value, l_lines(i).cost_code, l_lines(i).cost_code2,
           l_lines(i).close_value, 0, null, null, p_company_code, p_password_number, p_user_code, sysdate);
      end loop;
    exception
      when others then
        if sqlcode between -20999 and -20000 or sqlcode in (-1, -2291) then
          fail(-20140, 'تعذر إنشاء قيد الإقفال: ' || clean_sqlerrm, 'The closing entry could not be created: ' || clean_sqlerrm);
        end if;
        raise;
    end;

    update ac_basic set close_date = l_date where company_code = p_company_code;

    set_message(msg('تـم عـمـل قـيــد الاقـفـال بالـرقــم ' || key_text(p_entry_year, p_entry_type, l_no)
                    || ' (' || l_lines.count || ' طرف، إجمالى ' || to_char(l_total, 'FM999G999G999G990D00')
                    || ') وأصبح تاريخ الإقفال ' || to_char(l_date, 'DD/MM/YYYY') || '.' || l_warn,
                    'Closing entry ' || key_text(p_entry_year, p_entry_type, l_no) || ' was created ('
                    || l_lines.count || ' lines, total ' || to_char(l_total, 'FM999G999G999G990D00')
                    || '); closing date is now ' || to_char(l_date, 'DD/MM/YYYY') || '.' || l_warn));
  end create_closing_entry;

  -- ---------------------------------------------------------------------------------------------------
  -- AC_DELETECCLOSE : cancel the last closing entry
  -- ---------------------------------------------------------------------------------------------------
  procedure cancel_closing_entry (
    p_close_date      in date,
    p_company_code    in number,
    p_user_code       in number,
    p_password_number in number)
  is
    l_keys t_keys;
    l_new  date;
  begin
    require(p_close_date, 'يجب تحديد تاريخ قيد الإقفال المراد إلغاؤه', 'The date of the closing entry to cancel is required');
    require_session(p_company_code, p_user_code);

    begin
      select entry_year, entry_type, entry_no, entry_date, currency_code, doc_no
        bulk collect into l_keys
        from ac_yearly_trn
       where close_flag = 1
         and (p_password_number = 0
              or (create_company_code = p_company_code and create_password_number = p_password_number))
         and entry_date in (select max(entry_date) from ac_yearly_trn where close_flag = 1)
         for update nowait;
    exception
      when e_busy then
        fail(-20103, 'قيد الإقفال مفتوح للتعديل من مستخدم آخر، حاول لاحقاً', 'The closing entry is locked by another user, try again later');
    end;
    if l_keys.count = 0 then
      fail(-20150, 'لا يوجد قيود اقفال لكى تلغى', 'There is no close entries to be deleted');
    end if;
    if l_keys.count > 1 then
      fail(-20151, 'يوجد أكثر من قيد إقفال بتاريخ ' || to_char(l_keys(1).entry_date, 'DD/MM/YYYY') || '، راجع قيود الإقفال',
                   'More than one closing entry is dated ' || to_char(l_keys(1).entry_date, 'DD/MM/YYYY'));
    end if;
    if trunc(p_close_date) <> l_keys(1).entry_date then
      fail(-20152, 'آخر قيد إقفال بتاريخ ' || to_char(l_keys(1).entry_date, 'DD/MM/YYYY') || ' وليس بالتاريخ المحدد، أعد فتح الصفحة',
                   'The last closing entry is dated ' || to_char(l_keys(1).entry_date, 'DD/MM/YYYY') || ', not the date given; reload the page');
    end if;

    begin
      delete from ac_yearly_trn_det
       where entry_year = l_keys(1).entry_year and entry_type = l_keys(1).entry_type and entry_no = l_keys(1).entry_no
         and (p_password_number = 0 or (create_company_code = p_company_code and create_password_number = p_password_number));
      delete from ac_yearly_trn
       where entry_year = l_keys(1).entry_year and entry_type = l_keys(1).entry_type and entry_no = l_keys(1).entry_no
         and (p_password_number = 0 or (create_company_code = p_company_code and create_password_number = p_password_number));
    exception
      when others then
        if sqlcode between -20999 and -20000 or sqlcode = -2292 then
          fail(-20153, 'تعذر إلغاء قيد الإقفال: ' || clean_sqlerrm, 'The closing entry could not be deleted: ' || clean_sqlerrm);
        end if;
        raise;
    end;

    select max(entry_date) into l_new
      from ac_yearly_trn
     where close_flag = 1
       and (p_password_number = 0 or (create_company_code = p_company_code and create_password_number = p_password_number));

    update ac_basic set close_date = l_new
     where (p_password_number = 0 or company_code = p_company_code);

    set_message(msg('تم إلغاء قيد الإقفال ' || key_text(l_keys(1).entry_year, l_keys(1).entry_type, l_keys(1).entry_no)
                    || ' بتاريخ ' || to_char(l_keys(1).entry_date, 'DD/MM/YYYY') || '، وأصبح تاريخ الإقفال '
                    || nvl(to_char(l_new, 'DD/MM/YYYY'), 'فارغاً (لا توجد فترة مقفلة)') || '.',
                    'Closing entry ' || key_text(l_keys(1).entry_year, l_keys(1).entry_type, l_keys(1).entry_no)
                    || ' dated ' || to_char(l_keys(1).entry_date, 'DD/MM/YYYY') || ' was deleted; the closing date is now '
                    || nvl(to_char(l_new, 'DD/MM/YYYY'), 'empty (no closed period)') || '.'));
  end cancel_closing_entry;

  -- ---------------------------------------------------------------------------------------------------
  -- AC_DUPENTRY : create a periodical entry
  -- ---------------------------------------------------------------------------------------------------
  procedure create_periodical_entry (
    p_serial          in number,
    p_new_type        in number,
    p_new_date        in date,
    p_company_code    in number,
    p_user_code       in number,
    p_password_number in number)
  is
    b          ac_basic%rowtype;
    l_voc      ac_periodical_voc%rowtype;
    l_src      ac_yearly_trn%rowtype;
    l_from_y   boolean := false;
    l_date     date;
    l_year     number;
    l_no       number;
    l_doc_no   number;
    l_n        number;
    l_dummy    number;
  begin
    require(p_serial, 'يجب اختيار القيد الدورى', 'Choose the periodical entry');
    require(p_new_type, 'لا بد من إدخال رقم اليومية المراد إنشاء القيد عليها', 'You Must Enter A New Entry Type Before Copy');
    require_session(p_company_code, p_user_code);
    b := basic_row(p_company_code);

    begin
      select * into l_voc from ac_periodical_voc where serial = p_serial;
    exception
      when no_data_found then
        fail(-20161, 'لايوجد قيد بهذا الرقم ...!', 'There is no entry with this number');
    end;
    if type_allowed(l_voc.entry_year, l_voc.entry_type, p_company_code, p_password_number) = 0 then
      fail(-20161, 'غير مسموح لمجموعتك بهذا القيد الدورى', 'Your group is not allowed to use this periodical entry');
    end if;

    -- source: posted entry (AC_YEARLY_TRN) first, else a daily entry (AC_DAILY_TRN), of the user's company
    begin
      select * into l_src
        from ac_yearly_trn
       where entry_year = l_voc.entry_year and entry_type = l_voc.entry_type and entry_no = l_voc.entry_no
         and create_company_code = p_company_code;
      l_from_y := true;
    exception
      when no_data_found then
        begin
          select entry_year, entry_type, entry_no, doc_no, entry_date, entry_desc, entry_desc_e, currency_code, rate,
                 entry_total, memo, memo_e
            into l_src.entry_year, l_src.entry_type, l_src.entry_no, l_src.doc_no, l_src.entry_date, l_src.entry_desc,
                 l_src.entry_desc_e, l_src.currency_code, l_src.rate, l_src.entry_total, l_src.memo, l_src.memo_e
            from ac_daily_trn
           where entry_year = l_voc.entry_year and entry_type = l_voc.entry_type and entry_no = l_voc.entry_no
             and create_company_code = p_company_code;
        exception
          when no_data_found then
            fail(-20162, 'لايوجد قيد بهذا الرقم ...!', 'There is no entry with this number');
        end;
    end;
    if l_from_y then
      select count(*) into l_n from ac_yearly_trn_det
       where entry_year = l_voc.entry_year and entry_type = l_voc.entry_type and entry_no = l_voc.entry_no
         and create_company_code = p_company_code;
    else
      select count(*) into l_n from ac_daily_trn_det
       where entry_year = l_voc.entry_year and entry_type = l_voc.entry_type and entry_no = l_voc.entry_no
         and create_company_code = p_company_code;
    end if;
    if l_n = 0 then
      fail(-20163, 'رقم القيد غير موجود بالحسابات', 'The entry no does''t exist in the GL');
    end if;

    -- empty new date: the copy keeps the source date (legacy ASK_ALERT)
    l_date := trunc(nvl(p_new_date, l_src.entry_date));
    if l_date <= b.close_date then
      fail(-20164, 'لا يمكن إنشاء الحركة لأنها تقع فى فترة مقفلة', 'You canot post the transaction  becouse it lies in a closed Period');
    end if;
    l_year := to_number(to_char(l_date, 'YYYY'));

    -- target journal: GL journal (AC_FLAG = 0) of the new year, allowed for the group; lock it for numbering
    begin
      select 1 into l_dummy
        from ac_trn_codes
       where entry_year = l_year and entry_type = p_new_type and nvl(ac_flag, 0) = 0
         for update;
    exception
      when no_data_found then
        fail(-20165, 'اليومية ' || p_new_type || ' غير معرفة (أو ليست يومية حسابات عامة) لسنة ' || l_year,
                     'Journal ' || p_new_type || ' is not defined as a GL journal for year ' || l_year);
    end;
    if type_allowed(l_year, p_new_type, p_company_code, p_password_number) = 0 then
      fail(-20166, 'غير مسموح لمجموعتك باستخدام هذه اليومية', 'Your group is not allowed to use this journal');
    end if;

    l_no := calc_serial(l_year, p_new_type, l_date);
    update ac_trn_codes set last_serial = l_no where entry_year = l_year and entry_type = p_new_type;
    -- DOC_NO: the new number when copying a posted entry, the source DOC_NO when copying a daily entry
    l_doc_no := case when l_from_y then l_no else l_src.doc_no end;

    begin
      insert into ac_daily_trn
        (entry_year, entry_type, entry_no, doc_no, entry_date, entry_desc, entry_desc_e, currency_code, rate,
         entry_total, memo, memo_e, create_company_code, create_password_number, create_user_code, create_date)
      values
        (l_year, p_new_type, l_no, l_doc_no, l_date,
         l_src.entry_desc, l_src.entry_desc_e, l_src.currency_code, l_src.rate, l_src.entry_total,
         l_src.memo, l_src.memo_e, p_company_code, p_password_number, p_user_code, sysdate);

      if l_from_y then
        insert into ac_daily_trn_det
          (entry_year, entry_type, entry_no, seq, account_number, entry_desc, entry_desc_e, value, cost_code, cost_code2,
           memo, memo_e, balance_flag, create_company_code, create_password_number, create_user_code, create_date)
        select l_year, p_new_type, l_no, seq, account_number, entry_desc, entry_desc_e, value, cost_code, cost_code2,
               memo, memo_e, balance_flag, p_company_code, p_password_number, p_user_code, sysdate
          from ac_yearly_trn_det
         where entry_year = l_voc.entry_year and entry_type = l_voc.entry_type and entry_no = l_voc.entry_no
           and create_company_code = p_company_code;
      else
        insert into ac_daily_trn_det
          (entry_year, entry_type, entry_no, seq, account_number, entry_desc, entry_desc_e, value, cost_code, cost_code2,
           memo, memo_e, balance_flag, create_company_code, create_password_number, create_user_code, create_date)
        select l_year, p_new_type, l_no, seq, account_number, entry_desc, entry_desc_e, value, cost_code, cost_code2,
               memo, memo_e, balance_flag, p_company_code, p_password_number, p_user_code, sysdate
          from ac_daily_trn_det
         where entry_year = l_voc.entry_year and entry_type = l_voc.entry_type and entry_no = l_voc.entry_no
           and create_company_code = p_company_code;
      end if;
    exception
      when others then
        if sqlcode between -20999 and -20000 or sqlcode in (-1, -2291) then
          fail(-20167, 'تعذر إنشاء القيد: ' || clean_sqlerrm, 'The entry could not be created: ' || clean_sqlerrm);
        end if;
        raise;
    end;

    set_message(msg('تم نسخ القيد برقم ' || key_text(l_year, p_new_type, l_no) || ' بتاريخ ' || to_char(l_date, 'DD/MM/YYYY')
                    || ' (قيد يومى غير مرحل، يرحل من شاشة الترحيل).',
                    'Voucher Copied With Number ' || key_text(l_year, p_new_type, l_no) || ' dated '
                    || to_char(l_date, 'DD/MM/YYYY') || ' (daily entry, post it with the posting screen).'));
  end create_periodical_entry;

  -- ---------------------------------------------------------------------------------------------------
  -- ACDLYTR : button POST_VOUCHER (one entry)
  -- ---------------------------------------------------------------------------------------------------
  function voucher_post_allowed (p_company_code in number, p_user_code in number, p_password_number in number) return number is
    l_files number;
    l_flag  number;
  begin
    if nvl(p_password_number, 0) = 0 then
      return 1;
    end if;
    select count(1) into l_files
      from file_password
     where system_number = 1 and file_serial = 71 and users_code = p_user_code
       and insert_flag = 1 and delete_flag = 1 and update_flag = 1 and query_flag = 1;
    begin
      select post_flag into l_flag from group_company where company_code = p_company_code and password_number = p_password_number;
    exception when others then
      l_flag := 0;
    end;
    return case when l_flag = 1 and l_files = 1 then 1 else 0 end;
  end voucher_post_allowed;

  procedure post_voucher (
    p_entry_year      in number,
    p_entry_type      in number,
    p_entry_no        in number,
    p_company_code    in number,
    p_user_code       in number,
    p_password_number in number)
  is
    h        ac_daily_trn%rowtype;
    b        ac_basic%rowtype;
    l_keys   t_keys := t_keys();
    l_errs   t_errs := t_errs();
    l_debit  number(14,2) := 0;
    l_credit number(14,2) := 0;
    l_close  date;
    l_n      number := 0;
    l_seq    number := 0;
    l_curr   ac_master.currency_code%type;
    l_status ac_master.account_status%type;
    l_txt    varchar2(4000);

    procedure add_err (p_acct in number, p_a in varchar2, p_e in varchar2) is
    begin
      l_seq := l_seq + 1;                         -- legacy LAST_SEQ counter, not the line number
      l_errs.extend;
      l_errs(l_errs.count).entry_year := h.entry_year;
      l_errs(l_errs.count).entry_type := h.entry_type;
      l_errs(l_errs.count).entry_no   := h.entry_no;
      l_errs(l_errs.count).seq        := l_seq;
      l_errs(l_errs.count).account_no := p_acct;
      l_errs(l_errs.count).message    := substr(msg(p_a, p_e), 1, 50);
    end add_err;
  begin
    require_session(p_company_code, p_user_code);
    b := basic_row(p_company_code);
    begin
      select * into h from ac_daily_trn
       where entry_year = p_entry_year and entry_type = p_entry_type and entry_no = p_entry_no
         for update nowait;
    exception
      when no_data_found then
        fail(-20111, 'يجب الحفظ أولا قبل الترحيل', 'Save First Before Posting');
      when e_busy then
        fail(-20103, 'القيد مفتوح للتعديل من مستخدم آخر، حاول لاحقاً', 'The entry is being edited by another user, try again later');
    end;
    if voucher_post_allowed(p_company_code, p_user_code, p_password_number) <> 1 then
      fail(-20114, 'ليس لديك صلاحية ترحيل القيود', 'You are not allowed to post entries');
    end if;

    -- POST_VOUCHER: AC_BASIC.CLOSE_DATE >= ENTRY_DATE -> alert DEL_ERROR
    if b.close_date >= h.entry_date then
      fail(-20115, 'تاريخ القيد أقل من تاريخ قيد الإقفال لا يمكن إلغاء القيد',
                   'The entry date is before the closing entry date');
    end if;
    -- DEBIT_TOTAL <> CREDIT_TOTAL: BALANCE_ENTRY_FLAG = 1 refuses; 0 asked BAL_ALERT and went on (TEST_PROC then fails)
    select nvl(sum(case when value > 0 then value end), 0), nvl(sum(case when value < 0 then -value end), 0), count(*)
      into l_debit, l_credit, l_n
      from ac_daily_trn_det
     where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
    if round(l_debit, 2) != round(l_credit, 2) and nvl(b.balance_entry_flag, 0) <> 0 then
      fail(-20116, 'لايمكن حفظ قيد غير متزن', 'Cannot Save Non Balance Entry');
    end if;
    if l_n = 0 then
      fail(-20117, 'القيد لا يحتوى على تفاصيل !!', 'Entry Contain No Details !!');
    end if;
    -- last closing entry (MEMO 'قــيــــد الاقـفـــــــال')
    select max(entry_date) into l_close
      from ac_yearly_trn
     where memo = 'قــيــــد الاقـفـــــــال' and memo_e = 'Closing Entry';
    if l_close is not null and l_close >= h.entry_date then
      fail(-20118, 'يجب أن يكون تاريخ القيد أكبر من تاريخ الأقفال', 'The date of the entry should be after the last closing entry');
    end if;

    -- TEST_PROC (ACDLYTR version)
    l_debit := 0; l_credit := 0;
    for d in (select seq, account_number, value from ac_daily_trn_det
               where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no
               order by seq)
    loop
      begin
        select currency_code, account_status into l_curr, l_status from ac_master where account_number = d.account_number;
        if l_status != 1 then
          add_err(d.account_number, 'الحساب ليس على المستوى الأدنى', 'Account not a less level');
        end if;
        if l_curr != h.currency_code and l_curr != 1 and h.currency_code != 1 then
          add_err(d.account_number, 'عملة الحساب ليست مماثلة لعملة القيد', 'Account currency not similar to entry currency');
        end if;
      exception when no_data_found then
        add_err(d.account_number, 'الحساب غير موجود', 'Account does not exist');
      end;
      if d.value > 0 then
        l_debit := round(l_debit, 2) + round(d.value, 2);
      else
        l_credit := round(l_credit, 2) - round(d.value, 2);
      end if;
    end loop;
    if round(l_debit, 2) != round(l_credit, 2) then
      add_err(null, 'الجانب المدين لا يساوى الجانب الدائن', 'Debit side not equal to credit side');
    end if;

    l_keys.extend;
    l_keys(1).entry_year := h.entry_year; l_keys(1).entry_type := h.entry_type; l_keys(1).entry_no := h.entry_no;
    l_keys(1).entry_date := h.entry_date; l_keys(1).currency_code := h.currency_code; l_keys(1).doc_no := h.doc_no;
    save_post_errors(l_keys, l_errs);
    if l_errs.count > 0 then
      for i in 1 .. least(l_errs.count, 5) loop
        l_txt := l_txt || ' | ' || case when l_errs(i).account_no is not null then l_errs(i).account_no || ': ' end
                 || l_errs(i).message;
      end loop;
      -- alert ERROR, errors in AC_UPDT_TBL (report ACPSTERR)
      fail(-20110, 'يوجد خطأ بالقيد، قد يكون غير متوازن !!' || l_txt, 'There''s Error in Entry, May Be Not Balanced!!' || l_txt);
    end if;

    -- UPDATE_PROC
    begin
      insert into ac_yearly_trn
        (entry_year, entry_type, entry_no, doc_no, entry_date, entry_desc, entry_desc_e, currency_code, rate, entry_total,
         close_flag, memo, memo_e, create_company_code, create_password_number, create_user_code, create_date, post_system,
         update_company_code, update_password_number, update_user_code, update_date, post_user)
      values
        (h.entry_year, h.entry_type, h.entry_no, h.doc_no, h.entry_date, h.entry_desc, h.entry_desc_e, h.currency_code, h.rate,
         h.entry_total, 0, h.memo, h.memo_e, h.create_company_code, h.create_password_number, h.create_user_code,
         h.create_date, 1, h.update_company_code, h.update_password_number, h.update_user_code, h.update_date, p_user_code);
    exception when dup_val_on_index then
      fail(-20119, 'القيد مكرر فى ملف القيود اليومية و الفورية', 'Entry number duplicated in Daily and yearly Entry File');
    end;
    begin
      -- lines: the legacy column list with the audit columns of the header; AUTO_TRNS_FLAG / TAX_TRNS_DATE /
      -- TAX_INVOICE_NO are copied as well (as ACUPDT does, so that no VAT data is lost)
      insert into ac_yearly_trn_det
        (entry_year, entry_type, entry_no, seq, account_number, entry_date, entry_desc, entry_desc_e, value, cost_code,
         cost_code2, close_value, balance_flag, memo, memo_e, create_company_code, create_password_number, create_user_code,
         create_date, update_company_code, update_password_number, update_user_code, update_date, tax_flag, tax_account,
         t_tax_flag1, cust_code, cust_name, cust_tax_no, cust_inv_no, cust_inv_val, cust_notes, cust_inv_date,
         auto_trns_flag, tax_trns_date, tax_invoice_no)
      select entry_year, entry_type, entry_no, seq, account_number, h.entry_date, entry_desc, entry_desc_e, value, cost_code,
             cost_code2, 0, balance_flag, memo, memo_e, h.create_company_code, h.create_password_number, h.create_user_code,
             h.create_date, h.update_company_code, h.update_password_number, h.update_user_code, h.update_date, tax_flag,
             tax_account, t_tax_flag1, cust_code, cust_name, cust_tax_no, cust_inv_no, cust_inv_val, cust_notes, cust_inv_date,
             auto_trns_flag, tax_trns_date, tax_invoice_no
        from ac_daily_trn_det
       where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
      currency_diff_line(h.entry_year, h.entry_type, h.entry_no, p_company_code,
                         'لابد من تعريف حساب فروق العملة بمؤشرات النظام');
      delete from ac_daily_trn_det where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
      delete from ac_daily_trn where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
    exception
      when others then
        if sqlcode = -20113 then
          raise;
        end if;
        if sqlcode between -20999 and -20000 or sqlcode in (-1, -2291, -2292) then
          fail(-20112, 'تعذر ترحيل القيد ' || key_text(h.entry_year, h.entry_type, h.entry_no) || ': ' || clean_sqlerrm,
                       'Voucher ' || key_text(h.entry_year, h.entry_type, h.entry_no) || ' could not be posted: ' || clean_sqlerrm);
        end if;
        raise;
    end;
    -- alert DONE
    set_message(msg('لقد تم ترحيل القيد بنجـــاح', 'Entry Posted Successfuly') || ' ('
                || key_text(h.entry_year, h.entry_type, h.entry_no) || ')');
  end post_voucher;

end app_proc_gl;
/

show errors package app_proc_gl
show errors package body app_proc_gl
