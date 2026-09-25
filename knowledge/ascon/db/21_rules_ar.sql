-- =====================================================================================================
-- APP_RULES_AR : legacy business rules of the AR transaction screens on AR_MAINTRNS (Stage C waves 2 and 3).
--   ARDBTRN     customer debit transactions            (effect 0, AR_TRNSTYPE.TRNS_TYPE in (3,4), LINK_FLAG = 0)
--   ARCRTRN     customer credit transactions/payments  (effect 1, TRNS_TYPE in (3,4), TOT_TRNS_FLAG = 0, LINK_FLAG = 0)
--   ARDBTRN_ST  debit transactions of other systems    (effect 0, LINK_FLAG = 1)
--   ARCRTRN_ST  credit transactions of other systems   (effect 1, LINK_FLAG = 1)
-- Evidence and rule lists: app\legacy\processes\<FORM>.md. Wired by app\legacy\overrides\<FORM>.json:
--   key_expr  AR_MAINTRNS.MAINAREA_ID / SUBAREA_ID  <- customer (items disabled in the legacy forms)
--             AR_MAINTRNS.CTGRY_CODE / SALESMAN_ID  <- transaction type / customer (APEX data-entry requests only)
--             AR_MAINTRNS.TRNS_SERIAL               <- max+1 per TRNS_ID (debit) or per TRNS_ID+area+branch (credit)
--             AR_MAINTRNS_ACCOUNT_DET.SEQ           <- max+1 over the whole table (legacy PRE-INSERT)
--   validations  check_header, check_dates, check_pay_method, check_book, check_header_st, check_posted,
--                check_posted_debit, snapshot_alloc / snapshot_debit
--   warnings     warn_book, warn_cheque (legacy MSG(...,0) alerts)
--   after_save   after_save_debit / after_save_credit (screen-specific derivations, allocation, residuals, balances)
--   info         cust_balance, alloc_info, book_range, system_name, user_name
--   delete hooks triggers APP_RULES_AR_SUB_BD (AR_SUBTRNS) and APP_RULES_AR_MAST_BD (AR_MAINTRNS) at the end of this
--                file: KEY-DELREC / POST-DELETE effects of the four screens (APEX pages of these forms only).
-- Installation: CUSTOMER_PAR is empty (production and build copy), so :GLOBAL.CUSTOMER_CODE is NULL and every
--   installation branch ('ZEB') is false: "= 'ZEB'" and "<> 'ZEB'" both skip their THEN part (see ARDBTRN.md).
-- Errors: raise_application_error(-20100..-20199) / returned Arabic text. No COMMIT (APEX commits).
-- Posting to GL / cancel posting stay in APP_PROC_AR; the document buttons that call them are in APP_ACT_AR.
-- =====================================================================================================
set define off

create or replace package app_rules_ar authid definer as

  procedure set_context (p_company_code in number, p_user_code in number, p_password_number in number);
  procedure clear_context;

  -- legacy form of the current APEX page (APP_PAGE_MAP), null outside APEX / tests (set_form overrides it)
  function cur_form return varchar2;
  procedure set_form (p_form in varchar2);

  -- derived keys and defaults (key_expr)
  function cust_mainarea (p_customer_id in number) return number;
  function cust_subarea (p_customer_id in number) return number;
  function default_ctgry (p_trns_id in number, p_customer_id in number) return number;
  function default_salesman (p_trns_id in number, p_customer_id in number, p_ctgry_code in number) return number;
  function next_trns_serial (p_trns_id in number, p_mainarea_id in number, p_subarea_id in number, p_customer_id in number) return number;
  function next_acc_det_seq return number;
  function next_serial_total return number;
  function next_doc_no (p_trns_id in number) return number;

  -- transaction types of a screen (list filter / default / validation)
  function type_check (p_screen in varchar2, p_trns_id in number) return varchar2;
  function default_type (p_screen in varchar2) return number;

  -- page validations (CREATE, SAVE)
  function check_header (
    p_screen        in varchar2,
    p_rowid         in varchar2,
    p_trns_id       in number,
    p_customer_id   in number,
    p_trns_date     in date,
    p_ctgry_code    in number,
    p_salesman_id   in number,
    p_currency_code in number,
    p_rate          in number) return varchar2;
  -- CHECK_DATE (TRANSLATE.pll): no future date, not before MIN(AC_BASIC.MIN_DATE) (TRNS_DATE, ACC_POST_DATE)
  function check_dates (p_screen in varchar2, p_trns_date in date, p_acc_post_date in date default null) return varchar2;
  -- PAY_METHOD: required, 1 / 2 / 4, AR_PAYTYP_PASSWORD (ARCRTRN_ST), INV_VALUE locked for saved payments of method 1 / 2
  function check_pay_method (p_screen in varchar2, p_rowid in varchar2, p_trns_id in number, p_pay_method in number,
                             p_inv_value in number) return varchar2;
  -- receipt books (ARCRTRN): BOOK_SERIAL / BOOK_NO of the salesman for collections of salesman types
  function check_book (p_rowid in varchar2, p_trns_id in number, p_customer_id in number, p_salesman_id in number,
                       p_book_serial in number, p_book_no in number) return varchar2;
  -- "other systems" screens: DOC_NO > 0 (ARCRTRN_ST), rate not changed while lines exist (ARCRTRN_ST), POST_SYSTEM of SYS_SYSTEMS
  function check_header_st (p_screen in varchar2, p_rowid in varchar2, p_doc_no in number, p_rate in number,
                            p_post_system in number) return varchar2;
  -- SAVE: CLOSE_POSTED / CLOSE_MAIN_POSTED - a posted (POST_FLAG = 1) or paid (PAY_FLAG = 1) transaction is read-only
  function check_posted (p_rowid in varchar2) return varchar2;
  -- SAVE (ARDBTRN): CLOSE_POSTED as it runs with :GLOBAL.CUSTOMER_CODE NULL (its "ZEB" branch): a posted / paid debit
  -- transaction keeps SALESMAN_ID, the accounts, BILL_ID2 and due dates editable; the listed header items are locked
  function check_posted_debit (p_rowid in varchar2, p_customer_id in number, p_ctgry_code in number, p_desc_a in varchar2,
                               p_desc_e in varchar2, p_band_no in varchar2, p_trns_date in date, p_cost_code1 in number,
                               p_cost_code2 in number, p_rate in number) return varchar2;
  -- SAVE of a credit transaction: remembers its allocation lines before the grid DML (returns null)
  function snapshot_alloc (p_rowid in varchar2) return varchar2;
  -- SAVE of a debit transaction: remembers its invoice / account lines before the grid DML (returns null)
  function snapshot_debit (p_rowid in varchar2) return varchar2;

  -- warnings (legacy MSG(...,0) alerts; the page asks "continue?")
  function warn_book (p_rowid in varchar2, p_trns_id in number, p_salesman_id in number, p_book_serial in number,
                      p_book_no in number) return varchar2;
  function warn_cheque (p_rowid in varchar2, p_trns_id in number, p_cheque_number in number) return varchar2;

  -- after-save processes (raise -201xx to roll the save back)
  procedure after_save_debit (p_screen in varchar2, p_rowid in varchar2, p_request in varchar2);
  procedure after_save_credit (p_screen in varchar2, p_rowid in varchar2, p_request in varchar2);

  -- CALCULATE_DISCOUNT: early-payment discount of an allocation (AR_CUST_DSCNT -> AR_CUST_CLASS_DSCNT -> AR_TRNSTYPE_DSCNT
  -- -> AR_CTGRY_DSCNT, period by the days between the payment and the invoice). p_total is the base of the percentage:
  -- ARCRTRN the allocated TOTAL_VALUE, ARCRTRN_ST and AR_INVOICE_ADJESTMENT_MAN the invoice bill total (INV_TOTAL_VALUE).
  -- p_class_period = 0: the class cursor of AR_INVOICE_ADJESTMENT_MAN, which has no AR_PERIOD.SERIAL join.
  procedure calc_discount (p_customer_id in number, p_trns_id in number, p_ctgry_code in number, p_days in number,
                           p_total in number, o_disc out number, o_period out number, o_source out number,
                           p_class_period in number default 1);
  -- BILL_LOV + AR_SUBTRNS PRE-INSERT: allocate p_amount (null = legacy default) of the payment p_rowid to the invoice bill
  -- p_invoice ('TRNS_ID:MAINAREA_ID:SUBAREA_ID:TRNS_SERIAL:BILL_SEQ'); p_disc null = CALCULATE_DISCOUNT / header ratio
  procedure add_allocation (p_rowid in varchar2, p_invoice in varchar2, p_amount in number default null,
                            p_disc in number default null, p_screen in varchar2 default 'ARCRTRN');
  -- open value of a payment that is not allocated yet (TRNS_TOTAL_DIFF) and of an invoice bill (AR_SUBTRNS_PAYED_VALUE)
  function payment_open (p_rowid in varchar2) return number;

  -- info panel values
  function dc_text (p_amount in number) return varchar2;                 -- "1,234.00 مدين / دائن"
  function cust_balance (p_customer_id in number) return varchar2;       -- CRN_BAL / CRN_BAL_TOTAL (GET_CUSTOMER_BAL, today)
  function alloc_info (p_rowid in varchar2, p_what in varchar2) return varchar2;   -- TOTAL/DISC/NET/DIFF/TOTAL_DIFF/ACCOUNTS/SUBTAX
  function book_range (p_salesman_id in number, p_book_serial in number) return varchar2;
  function system_name (p_post_system in number) return varchar2;
  function user_name (p_user in number) return varchar2;

  -- delete hooks (called by the triggers at the end of this file; APEX pages of the four screens only)
  procedure sub_before_statement;
  procedure sub_before_delete (p_trns_id number, p_mainarea_id number, p_subarea_id number, p_trns_serial number,
                               p_bill_seq number, p_bill_id1 number, p_bill_id2 number, p_store_code number,
                               p_total_value number, p_disc_value number, p_inv_trns_id number, p_inv_mainarea_id number,
                               p_inv_subarea_id number, p_inv_trns_serial number, p_inv_bill_seq number);
  procedure sub_after_delete;
  procedure mast_before_delete (p_trns_id number, p_mainarea_id number, p_subarea_id number, p_trns_serial number,
                                p_customer_id number, p_salesman_id number, p_ctgry_code number, p_total_value number,
                                p_post_flag number, p_pay_flag number);

end app_rules_ar;
/

create or replace package body app_rules_ar as

  g_ctx       boolean := false;
  g_company   number;
  g_user      number;
  g_password  number;
  g_form      varchar2(128);
  g_form_set  boolean := false;
  g_page      number := -1;
  g_page_form varchar2(128);

  type t_alloc is record (bill_seq number, inv_trns_id number, inv_mainarea_id number, inv_subarea_id number,
                          inv_trns_serial number, inv_bill_seq number, total_value number);
  type t_alloc_tab is table of t_alloc index by pls_integer;
  g_snap_rowid varchar2(100);
  g_snap       t_alloc_tab;

  -- snapshot of a debit transaction (posted-document rules of ARDBTRN)
  type t_dline is record (bill_seq number, bill_id1 number, inv_date date, inv_value number, total_value number);
  type t_dline_tab is table of t_dline index by pls_integer;
  type t_aline is record (seq number, trns_account number, value number, cost_code1 number, cost_code2 number);
  type t_aline_tab is table of t_aline index by pls_integer;
  g_dsnap_rowid varchar2(100);
  g_dsnap       t_dline_tab;
  g_asnap       t_aline_tab;

  -- delete hooks
  type t_sub is record (trns_id number, mainarea_id number, subarea_id number, trns_serial number, bill_seq number,
                        bill_id1 number, bill_id2 number, store_code number, total_value number, disc_value number,
                        inv_trns_id number, inv_mainarea_id number, inv_subarea_id number, inv_trns_serial number,
                        inv_bill_seq number, effect number, form varchar2(30));
  type t_sub_tab is table of t_sub index by pls_integer;
  g_del     t_sub_tab;
  g_in_hook boolean := false;

  c_default_store constant number := 999999999999;   -- AR_SUBTRNS.STORE_CODE initial value in ARDBTRN

  procedure set_context (p_company_code in number, p_user_code in number, p_password_number in number) is
  begin
    g_ctx := true; g_company := p_company_code; g_user := p_user_code; g_password := p_password_number;
  end set_context;

  procedure clear_context is
  begin
    g_ctx := false; g_company := null; g_user := null; g_password := null;
    g_form := null; g_form_set := false;
  end clear_context;

  procedure set_form (p_form in varchar2) is
  begin
    g_form := upper(p_form); g_form_set := p_form is not null;
  end set_form;

  function cur_form return varchar2 is
    l_page number;
  begin
    if g_form_set then
      return g_form;
    end if;
    begin l_page := to_number(v('APP_PAGE_ID')); exception when others then l_page := null; end;
    if l_page is null then
      return null;
    end if;
    if l_page <> g_page then
      begin
        select form_name into g_page_form from app_page_map where page_id = l_page;
      exception when no_data_found then g_page_form := null;
      end;
      g_page := l_page;
    end if;
    return g_page_form;
  end cur_form;

  function num (p in varchar2) return number is
  begin
    return to_number(p);
  exception when value_error or invalid_number then return null;
  end num;

  function is_en return boolean is
  begin
    return lower(nvl(v('G_LANG'), 'ar')) like 'en%';
  end is_en;

  function lt (p_a in varchar2, p_e in varchar2) return varchar2 is
  begin
    return case when is_en and p_e is not null then p_e else p_a end;
  end lt;

  function ctx_password return number is
  begin
    return nvl(case when g_ctx then g_password else num(v('G_PASSWORD_NUMBER')) end, 0);
  end ctx_password;

  function ctx_user return number is
  begin
    return case when g_ctx then g_user else num(v('G_USER_CODE')) end;
  end ctx_user;

  function ctx_company return number is
    l number;
  begin
    l := case when g_ctx then g_company else num(v('G_COMPANY_CODE')) end;
    if l is null then
      select min(company_code) into l from ac_basic;
    end if;
    return l;
  end ctx_company;

  function request return varchar2 is
  begin
    return upper(nvl(v('REQUEST'), 'SAVE'));
  end request;

  procedure fail (p_code in pls_integer, p_msg in varchar2) is
  begin
    raise_application_error(p_code, p_msg);
  end fail;

  function fmt (p in number) return varchar2 is
  begin
    return to_char(p, 'FM999,999,999,990.00');
  end fmt;

  function trnstype (p_id in number) return ar_trnstype%rowtype is
    t ar_trnstype%rowtype;
  begin
    select * into t from ar_trnstype where id = p_id;
    return t;
  exception when no_data_found then
    return t;
  end trnstype;

  function customer_row (p_code in number) return customer%rowtype is
    c customer%rowtype;
  begin
    select * into c from customer where code = p_code;
    return c;
  exception when no_data_found then
    return c;
  end customer_row;

  function header_row (p_rowid in varchar2) return ar_maintrns%rowtype is
    h ar_maintrns%rowtype;
  begin
    if p_rowid is null then
      return h;
    end if;
    select * into h from ar_maintrns where rowid = chartorowid(p_rowid);
    return h;
  exception when no_data_found or value_error then
    return h;
  end header_row;

  function key_text (p_trns_id number, p_serial number) return varchar2 is
  begin
    return p_trns_id || '/' || p_serial;
  end key_text;

  -- ===================================================================================== keys and defaults
  function cust_mainarea (p_customer_id in number) return number is
    l number;
  begin
    select mainarea_id into l from customer where code = p_customer_id;
    return l;
  exception when no_data_found then return null;
  end cust_mainarea;

  function cust_subarea (p_customer_id in number) return number is
    l number;
  begin
    select subarea_id into l from customer where code = p_customer_id;
    return l;
  exception when no_data_found then return null;
  end cust_subarea;

  -- ARDBTRN TRNS_ID WHEN-VALIDATE-ITEM: CTGRY_CODE := AR_TRNSTYPE.CTGRY_CODE;
  -- ARCRTRN / ARCRTRN_ST CUSTOMER_ID WHEN-VALIDATE-ITEM: NVL(MIN(AR_CUST_SALESMAN.CTGRY_CODE), type category)
  function default_ctgry (p_trns_id in number, p_customer_id in number) return number is
    t     ar_trnstype%rowtype := trnstype(p_trns_id);
    l_min number;
  begin
    select min(ctgry_code) into l_min from ar_cust_salesman where customer_code = p_customer_id;
    if nvl(t.effect, 0) = 1 then
      return nvl(l_min, t.ctgry_code);
    end if;
    return nvl(t.ctgry_code, l_min);
  end default_ctgry;

  -- CUSTOMER_ID WHEN-VALIDATE-ITEM: MIN(SALESMAN_CODE) of AR_CUST_SALESMAN for the customer and category
  function default_salesman (p_trns_id in number, p_customer_id in number, p_ctgry_code in number) return number is
    l number;
  begin
    select min(salesman_code) into l
      from ar_cust_salesman
     where customer_code = p_customer_id and (ctgry_code = p_ctgry_code or p_ctgry_code is null);
    if l is null then
      select min(salesman_code) into l from ar_cust_salesman where customer_code = p_customer_id;
    end if;
    return l;
  end default_salesman;

  -- PRE-INSERT: ARDBTRN max(TRNS_SERIAL)+1 per TRNS_ID (area filter commented out in the legacy code);
  -- ARCRTRN max+1 per TRNS_ID, MAINAREA_ID, SUBAREA_ID ("= 'ZEB'" branch false: CUSTOMER_CODE is NULL here)
  function next_trns_serial (p_trns_id in number, p_mainarea_id in number, p_subarea_id in number, p_customer_id in number) return number is
    t      ar_trnstype%rowtype := trnstype(p_trns_id);
    l_main number := nvl(p_mainarea_id, cust_mainarea(p_customer_id));
    l_sub  number := nvl(p_subarea_id, cust_subarea(p_customer_id));
    l      number;
  begin
    if nvl(t.effect, 0) = 1 then
      select nvl(max(trns_serial), 0) + 1 into l
        from ar_maintrns
       where trns_id = p_trns_id and mainarea_id = l_main and subarea_id = l_sub;
    else
      select nvl(max(trns_serial), 0) + 1 into l from ar_maintrns where trns_id = p_trns_id;
    end if;
    return l;
  end next_trns_serial;

  -- AR_MAINTRNS_ACCOUNT_DET PRE-INSERT: SELECT NVL(MAX(SEQ),0)+1 FROM AR_MAINTRNS_ACCOUNT_DET (whole table)
  function next_acc_det_seq return number is
    l number;
  begin
    select nvl(max(seq), 0) + 1 into l from ar_maintrns_account_det;
    return l;
  end next_acc_det_seq;

  function next_serial_total return number is
    l number;
  begin
    select nvl(max(trns_serial_total), 0) + 1 into l from ar_maintrns;
    return l;
  end next_serial_total;

  -- PRE-INSERT: DOC_NO := max(DOC_NO) + 1 over the own transactions (NVL(LINK_FLAG,0) = 0) of the same AR_TRNSTYPE.TRNS_TYPE
  function next_doc_no (p_trns_id in number) return number is
    t ar_trnstype%rowtype := trnstype(p_trns_id);
    l number;
  begin
    select nvl(max(nvl(m.doc_no, 0)), 0) + 1 into l
      from ar_maintrns m
     where nvl(m.link_flag, 0) = 0
       and m.trns_id in (select x.id from ar_trnstype x where x.trns_type = t.trns_type);
    return l;
  end next_doc_no;

  -- ===================================================================================== types of a screen
  function type_in_screen (p_screen in varchar2, t in ar_trnstype%rowtype) return boolean is
  begin
    return case upper(p_screen)
      when 'ARDBTRN'    then t.effect = 0 and t.trns_type in (3, 4)
      when 'ARCRTRN'    then t.effect = 1 and nvl(t.tot_trns_flag, 0) = 0 and t.trns_type in (3, 4)
      when 'ARDBTRN_ST' then t.effect = 0
      when 'ARCRTRN_ST' then t.effect = 1
      else false end;
  end type_in_screen;

  function type_check (p_screen in varchar2, p_trns_id in number) return varchar2 is
    t    ar_trnstype%rowtype := trnstype(p_trns_id);
    l_pw number := ctx_password;
    l_n  number;
  begin
    if p_trns_id is null then
      return 'يجب إدخال نوع الحركة';
    end if;
    if t.id is null then
      return 'نوع الحركة ' || p_trns_id || ' غير موجود';
    end if;
    -- TRNSTYPE record group (validate from list)
    if not nvl(type_in_screen(p_screen, t), false) then
      return 'نوع الحركة ' || p_trns_id || ' (' || t.description_a || ') لا يخص هذه الشاشة';
    end if;
    if l_pw <> 0 and upper(p_screen) <> 'ARDBTRN_ST' then
      select count(*) into l_n from ar_trnstype_password where flag = 1 and password_number = l_pw and trns_id = p_trns_id;
      if l_n = 0 then
        return 'غير مسموح لمجموعتك باستخدام نوع الحركة ' || p_trns_id;
      end if;
    end if;
    return null;
  end type_check;

  function default_type (p_screen in varchar2) return number is
    l_min number;
  begin
    for t in (select * from ar_trnstype order by id) loop
      if type_check(p_screen, t.id) is null then
        return t.id;
      end if;
    end loop;
    return l_min;
  end default_type;

  -- ===================================================================================== validations
  function check_header (
    p_screen        in varchar2,
    p_rowid         in varchar2,
    p_trns_id       in number,
    p_customer_id   in number,
    p_trns_date     in date,
    p_ctgry_code    in number,
    p_salesman_id   in number,
    p_currency_code in number,
    p_rate          in number) return varchar2
  is
    l_old  ar_maintrns%rowtype;
    l_new  boolean := p_rowid is null;
    l_msg  varchar2(4000);
    c      customer%rowtype;
    l_pw   number := ctx_password;
    l_n    number;
    l_date date;
    l_flag number;
    l_ctg  number;
    t      ar_trnstype%rowtype := trnstype(p_trns_id);
    l_sm   number;
    l_book number;
  begin
    if not l_new then
      begin
        select * into l_old from ar_maintrns where rowid = chartorowid(p_rowid);
      exception when no_data_found or value_error then
        l_new := true;
      end;
    end if;

    -- TRNS_ID: validate from TRNSTYPE (new transactions); UpdateAllowed = false afterwards
    if l_new then
      l_msg := type_check(p_screen, p_trns_id);
      if l_msg is not null then return l_msg; end if;
    elsif p_trns_id <> l_old.trns_id then
      return 'لا يمكن تغيير نوع الحركة بعد الحفظ';
    end if;

    -- CUSTOMER_ID: mandatory, validate from CUSTOMER_LOV (active, allowed for the group, linked to the category)
    if p_customer_id is null then
      return 'يجب تحديد عميل الحركة';
    end if;
    c := customer_row(p_customer_id);
    if c.code is null then
      return 'رقم العميل ' || p_customer_id || ' غير موجود';
    end if;
    if l_new or p_customer_id <> nvl(l_old.customer_id, -1) then
      if not l_new then
        select count(*) into l_n
          from ar_subtrns
         where trns_id = l_old.trns_id and mainarea_id = l_old.mainarea_id and subarea_id = l_old.subarea_id
           and trns_serial = l_old.trns_serial;
        if l_n > 0 then
          return 'لا يمكن تغيير العميل ويوجد تفاصيل';
        end if;
      end if;
      if nvl(c.stopflag, 0) <> 0 or nvl(c.customer_status, 0) <> 1 then
        return 'العميل ' || p_customer_id || ' موقوف أو غير نشط';
      end if;
      if l_pw <> 0 then
        select count(*) into l_n from ar_cust_password where password_number = l_pw and customer_code = p_customer_id;
        if l_n = 0 then
          return 'غير مسموح لمجموعتك بالتعامل مع العميل ' || p_customer_id;
        end if;
      end if;
      -- CUSTOMER_LOV: customer of the category (the category is the type's one when the item is empty - TRNS_ID WVI)
      l_ctg := nvl(p_ctgry_code, t.ctgry_code);
      if l_ctg is not null and upper(p_screen) in ('ARDBTRN', 'ARCRTRN') then
        select count(*) into l_n from ar_cust_salesman where customer_code = p_customer_id and ctgry_code = l_ctg;
        if l_n = 0 then
          return 'العميل ' || p_customer_id || ' غير مرتبط بالقسم ' || l_ctg;
        end if;
      end if;
      if c.mainarea_id is null or c.subarea_id is null then
        return 'العميل ' || p_customer_id || ' غير مرتبط بمنطقة وفرع';
      end if;
      -- ARCRTRN CUSTOMER_ID WHEN-VALIDATE-ITEM -> GET_BOOK_NO / GET_DOC_NO for collections (TRNS_TYPE 3) when the customer
      -- has a salesman: the salesman must own an open receipt book ('لا يتم ربط اي دفاتر علي هذا المندوب')
      if upper(p_screen) = 'ARCRTRN' and t.trns_type = 3 then
        l_sm := default_salesman(p_trns_id, p_customer_id, nvl(p_ctgry_code, default_ctgry(p_trns_id, p_customer_id)));
        if l_sm is not null then
          select min(b.book_serial) into l_book
            from ar_salesman_books b
           where b.salesman_code = l_sm and nvl(b.stop_flag, 0) = 0 and nvl(b.book_finsh, 0) = 0 and nvl(b.book_type, 0) = 1
             and nvl(b.to_serial, 0) - nvl(b.from_serial, 0)
                 <> (select count(1) from ar_maintrns m where m.salesman_id = b.salesman_code and m.book_serial = b.book_serial);
          if l_book is null then
            return lt('لا يتم ربط اي دفاتر علي هذا المندوب', 'No Book For This Box') || ' (' || l_sm || ')';
          end if;
        end if;
      end if;
    end if;

    -- TRNS_DATE: CHECK_CUST_INFO (customer OPEN_DATE) and CHECK_OPEN_BAL (opening balance of the customer)
    if p_trns_date is null then
      return 'يجب إدخال تاريخ الحركة';
    end if;
    if c.open_date is not null and trunc(p_trns_date) < trunc(c.open_date) then
      return 'تاريخ الحركة لا يمكن ان يقل عن تاريخ فتح العميل (' || to_char(c.open_date, 'DD/MM/YYYY') || ')';
    end if;
    select max(m.trns_date) into l_date
      from ar_maintrns_op m, ar_subtrns_op d, ar_trnstype t
     where m.trns_id = d.trns_id and m.trns_serial = d.trns_serial and m.trns_id = t.id
       and d.customer_id = p_customer_id and t.trns_type = 6;
    if l_date is not null and trunc(p_trns_date) < trunc(l_date) then
      return 'تاريخ الحركة لا يمكن ان يقل عن تاريخ الرصيد الافتتاحي للعميل (' || to_char(l_date, 'DD/MM/YYYY') || ')';
    end if;

    -- SALESMAN_ID: AR_BASIC.SALESMAN_CUST_FLAG = 1 -> salesman of the customer in the category
    if p_salesman_id is not null and p_ctgry_code is not null then
      select nvl(max(salesman_cust_flag), 0) into l_flag from ar_basic;
      if l_flag = 1 then
        select count(*) into l_n
          from ar_cust_salesman
         where customer_code = p_customer_id and ctgry_code = p_ctgry_code and salesman_code = p_salesman_id;
        if l_n = 0 then
          return 'مندوب العميل لا يقع فى قسم أو فرع الحركة';
        end if;
      end if;
    end if;

    -- CURRENCY_RATE WHEN-VALIDATE-ITEM
    if p_rate is not null and p_rate <= 0 then
      return 'يجب ان يكون معامل التحويل أكبر من 0';
    end if;
    if nvl(p_currency_code, 1) = 1 and p_rate is not null and p_rate <> 1 then
      return 'يجب ان يكون معامل التحويل للعملة المحلية 1';
    end if;
    return null;
  end check_header;

  function check_dates (p_screen in varchar2, p_trns_date in date, p_acc_post_date in date default null) return varchar2 is
    l_min date;
    function one (p_date in date) return varchar2 is
    begin
      if p_date is null then
        return null;
      end if;
      if trunc(p_date) > trunc(sysdate) then
        return lt('تاريخ الحركة أكبر من تاريخ اليوم', 'Transaction Date is greater than today''s date');
      end if;
      if trunc(p_date) < trunc(l_min) then
        return lt('الحد الأدنى لتاريخ الحركة هو ', 'The least value accepted for Transaction Date is ') || to_char(l_min, 'DD/MM/YYYY');
      end if;
      return null;
    end one;
  begin
    -- CHECK_DATE(V_DATE, IS_CHECK => 0) with :GLOBAL.SYSTEM_NUMBER = 4: MIN(AC_BASIC.MIN_DATE), else 01-01 of last year
    select min(min_date) into l_min from ac_basic;
    if l_min is null then
      l_min := to_date('01-01-' || (to_number(to_char(sysdate, 'YYYY')) - 1), 'DD-MM-YYYY');
    end if;
    return nvl(one(p_trns_date), one(p_acc_post_date));
  end check_dates;

  function check_pay_method (p_screen in varchar2, p_rowid in varchar2, p_trns_id in number, p_pay_method in number,
                             p_inv_value in number) return varchar2
  is
    h     ar_maintrns%rowtype := header_row(p_rowid);
    l_pw  number := ctx_password;
    l_ok  number;
    r     ar_paytyp_password%rowtype;
  begin
    -- AR_MAINTRNS PRE-INSERT: 'يجب ادخال طريقة سداد'
    if p_pay_method is null then
      return lt('يجب ادخال طريقة سداد', 'You have to enter pay method');
    end if;
    -- PAY_METHOD_LIST elements: 1 descending on invoices, 2 invoice help screen, 4 credit amount for the customer
    if p_pay_method not in (1, 2, 4) then
      return lt('طريقة الدفع يجب أن تكون 1 (تنازلي على الفواتير) أو 2 (شاشة مساعدة للفواتير) أو 4 (مبلغ دائن لعميل)',
               'Pay method must be 1 (descending on invoices), 2 (helping invoice screen) or 4 (Debit Sum For Client)');
    end if;
    -- ARCRTRN_ST / AR_INVOICE_ADJESTMENT_MAN CREATE_AUTH_RECORD: the list shows only the methods of the group's
    -- AR_PAYTYP_PASSWORD row (OLDER_NEW = 1, SELECTED = 2, PAY_WITHOUT_ADJUST = 4)
    if upper(p_screen) = 'ARCRTRN_ST' and l_pw <> 0 then
      begin
        select * into r from ar_paytyp_password where password_number = l_pw;
        l_ok := case p_pay_method when 1 then nvl(r.older_new, 0) when 2 then nvl(r.selected, 0)
                                   when 4 then nvl(r.pay_without_adjust, 0) end;
        if l_ok <> 1 then
          return lt('طريقة الدفع غير مسموحة لمجموعتك', 'This pay method is not allowed for your group');
        end if;
      exception when no_data_found then
        null;                                   -- no row for the group: the list content is unknown (question in the .md)
      end;
    end if;
    -- WHEN-NEW-RECORD-INSTANCE: a saved payment of method 1 / 2 keeps its value (INV_VALUE UPDATE_ALLOWED = false)
    if h.trns_id is not null and upper(p_screen) = 'ARCRTRN' and nvl(h.pay_method, 0) in (1, 2)
       and nvl(p_inv_value, -1) <> nvl(h.inv_value, -1) then
      return lt('لا يمكن تعديل قيمة حركة سداد موزعة على الفواتير (طريقة الدفع 1 أو 2)',
               'The value of a payment allocated to invoices (pay method 1 or 2) cannot be changed');
    end if;
    return null;
  end check_pay_method;

  -- books of the salesman used by a number (CHECK_MAST salesman cheques of type 2 + collections of TRNS_TYPE 3)
  function book_no_used (p_book_no in number, p_salesman_id in number, p_rowid in varchar2) return number is
    l_n1 number;
    l_n2 number;
  begin
    select count(1) into l_n1
      from check_mast
     where salesman_book_no = p_book_no and salesman_code = p_salesman_id
       and trns_type_code in (select trns_type_code from check_trns_type where trns_type = 2);
    select count(1) into l_n2
      from ar_maintrns
     where book_no = p_book_no and salesman_id = p_salesman_id
       and trns_id in (select id from ar_trnstype where trns_type = 3)
       and (p_rowid is null or rowid <> chartorowid(p_rowid));
    return l_n1 + l_n2;
  end book_no_used;

  function check_book (p_rowid in varchar2, p_trns_id in number, p_customer_id in number, p_salesman_id in number,
                       p_book_serial in number, p_book_no in number) return varchar2
  is
    t      ar_trnstype%rowtype := trnstype(p_trns_id);
    h      ar_maintrns%rowtype := header_row(p_rowid);
    l_sm   number := nvl(p_salesman_id, h.salesman_id);
    l_from number;
    l_to   number;
    l_n    number;
  begin
    if p_salesman_id is null and p_rowid is null then
      l_sm := default_salesman(p_trns_id, p_customer_id, default_ctgry(p_trns_id, p_customer_id));
    end if;
    -- ENABLE_BOOK_NO: collections (TRNS_TYPE 3) of salesman types show BOOK_SERIAL (required) and BOOK_NO;
    -- PRE-INSERT / PRE-UPDATE: 'لايمكن الحفظ بدون سند'
    if t.trns_type = 3 and nvl(t.salesman_flag, 0) = 1 then
      if p_book_serial is null then
        return lt('يجب إدخال دفتر السندات', 'The receipt book must be entered');
      end if;
      if p_book_no is null then
        return lt('لايمكن الحفظ بدون سند', 'You Cant Save without book no');
      end if;
    end if;
    if p_book_no is null then
      return null;
    end if;
    -- BOOK_NO WHEN-VALIDATE-ITEM: inside the range of the book (FROM_SERIAL / TO_SERIAL of BOOK_LOV)
    begin
      select from_serial, to_serial into l_from, l_to
        from ar_salesman_books where salesman_code = l_sm and book_serial = p_book_serial;
      if p_book_no not between l_from and l_to then
        return lt(' رقم المستند خارج النطاق ', 'Document number out of the book range') || ' (' || l_from || ' - ' || l_to || ')';
      end if;
    exception when no_data_found then
      null;                                     -- legacy: FROM/TO empty -> NOT BETWEEN NULL AND NULL -> no error
    end;
    -- PRE-INSERT / BOOK_NO WVI: cancelled number (AR_SALESMAN_BOOKS_DET)
    select count(1) into l_n
      from ar_salesman_books_det
     where book_no = p_book_no and salesman_code = l_sm and book_serial = p_book_serial;
    if l_n > 0 then
      return lt('رقم السند ملغي', 'Please Select Valid Document Number');
    end if;
    -- PRE-INSERT / PRE-UPDATE: number already used by the salesman ('رقم السند مكرر'; PRE-UPDATE excludes the record itself)
    if book_no_used(p_book_no, l_sm, p_rowid) > 0 then
      return lt('رقم السند مكرر', 'Repeated Document Number');
    end if;
    return null;
  end check_book;

  function check_header_st (p_screen in varchar2, p_rowid in varchar2, p_doc_no in number, p_rate in number,
                            p_post_system in number) return varchar2
  is
    h   ar_maintrns%rowtype := header_row(p_rowid);
    l_n number;
  begin
    -- DOC_NO WHEN-VALIDATE-ITEM (ARCRTRN_ST text)
    if upper(p_screen) = 'ARCRTRN_ST' and p_doc_no is not null and p_doc_no <= 0 then
      return lt('رقم المستند يجب ان يكون اكبر من الصفر', 'the document number should be over than zero');
    end if;
    -- CURRENCY_RATE WHEN-VALIDATE-ITEM (ARCRTRN_ST): 'معامل التحويل لا يمكن ان يساوي الصفر' and no change while lines exist
    if upper(p_screen) = 'ARCRTRN_ST' then
      if p_rate = 0 then
        return lt('معامل التحويل لا يمكن ان يساوي الصفر', 'Currency Rate Cannot Be Zero');
      end if;
      if h.trns_id is not null and nvl(p_rate, -1) <> nvl(h.currency_rate, -1) then
        select count(*) into l_n
          from ar_subtrns
         where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
        if l_n > 0 then
          return lt('لا يمكن تغير معامل التحويل ويوجد بيانات بالفاتورة', 'The rate cannot be changed while the transaction has lines');
        end if;
      end if;
    end if;
    -- POST_SYSTEM_LIST: SYS_SYSTEMS except 0 and 99
    if p_post_system is not null then
      select count(*) into l_n from sys_systems where system_number = p_post_system and system_number not in (0, 99);
      if l_n = 0 then
        return lt('النظام ' || p_post_system || ' غير موجود', 'System ' || p_post_system || ' does not exist');
      end if;
    end if;
    return null;
  end check_header_st;

  function check_posted (p_rowid in varchar2) return varchar2 is
    l_post number;
    l_pay  number;
  begin
    if p_rowid is null then
      return null;
    end if;
    select nvl(post_flag, 0), nvl(pay_flag, 0) into l_post, l_pay from ar_maintrns where rowid = chartorowid(p_rowid);
    if l_post = 1 then
      return 'الحركة مرحلة للحسابات ولا يمكن تعديلها (يجب إلغاء الترحيل أولاً)';
    elsif l_pay = 1 then
      return 'الحركة مسددة ولا يمكن تعديلها';
    end if;
    return null;
  exception when no_data_found or value_error then
    return null;
  end check_posted;

  function check_posted_debit (p_rowid in varchar2, p_customer_id in number, p_ctgry_code in number, p_desc_a in varchar2,
                               p_desc_e in varchar2, p_band_no in varchar2, p_trns_date in date, p_cost_code1 in number,
                               p_cost_code2 in number, p_rate in number) return varchar2
  is
    h ar_maintrns%rowtype := header_row(p_rowid);
    function diff (a varchar2, b varchar2) return boolean is
    begin
      return nvl(a, chr(0)) <> nvl(b, chr(0));
    end diff;
  begin
    if h.trns_id is null or (nvl(h.post_flag, 0) <> 1 and nvl(h.pay_flag, 0) <> 1) then
      return null;
    end if;
    -- CLOSE_POSTED ("ZEB" branch): TRNS_ID, CUSTOMER_ID, DOC_NO, CTGRY_CODE, DESCRIPTION_A/E, BAND_NO, TRNS_DATE,
    -- COST_CODE1/2, CURRENCY_RATE are not updatable once the transaction is posted or paid
    if diff(p_customer_id, h.customer_id) or diff(p_ctgry_code, h.ctgry_code) or diff(p_desc_a, h.description_a)
       or diff(p_desc_e, h.description_e) or diff(p_band_no, h.band_no)
       or diff(to_char(p_trns_date, 'YYYYMMDD'), to_char(h.trns_date, 'YYYYMMDD'))
       or diff(p_cost_code1, h.cost_code1) or diff(p_cost_code2, h.cost_code2) or diff(p_rate, h.currency_rate) then
      if nvl(h.post_flag, 0) = 1 then
        return 'الحركة مرحلة للحسابات: يمكن تعديل المندوب والحسابات وتاريخ الاستحقاق فقط (يجب إلغاء الترحيل أولاً)';
      end if;
      return 'الحركة مسددة: يمكن تعديل المندوب والحسابات وتاريخ الاستحقاق فقط';
    end if;
    return null;
  end check_posted_debit;

  function snapshot_alloc (p_rowid in varchar2) return varchar2 is
    h ar_maintrns%rowtype;
  begin
    g_snap.delete;
    g_snap_rowid := p_rowid;
    if p_rowid is null then
      return null;
    end if;
    select * into h from ar_maintrns where rowid = chartorowid(p_rowid);
    select bill_seq, inv_trns_id, inv_mainarea_id, inv_subarea_id, inv_trns_serial, inv_bill_seq, total_value
      bulk collect into g_snap
      from ar_subtrns
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
    return null;
  exception when no_data_found or value_error then
    g_snap.delete;
    return null;
  end snapshot_alloc;

  function snapshot_debit (p_rowid in varchar2) return varchar2 is
    h ar_maintrns%rowtype;
  begin
    g_dsnap.delete; g_asnap.delete;
    g_dsnap_rowid := p_rowid;
    if p_rowid is null then
      return null;
    end if;
    select * into h from ar_maintrns where rowid = chartorowid(p_rowid);
    select bill_seq, bill_id1, inv_date, inv_value, total_value
      bulk collect into g_dsnap
      from ar_subtrns
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial
     order by bill_seq;
    select seq, trns_account, value, cost_code1, cost_code2
      bulk collect into g_asnap
      from ar_maintrns_account_det
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial
     order by seq;
    return null;
  exception when no_data_found or value_error then
    g_dsnap.delete; g_asnap.delete;
    return null;
  end snapshot_debit;

  -- ===================================================================================== warnings
  function warn_book (p_rowid in varchar2, p_trns_id in number, p_salesman_id in number, p_book_serial in number,
                      p_book_no in number) return varchar2
  is
    h       ar_maintrns%rowtype := header_row(p_rowid);
    l_sm    number := nvl(p_salesman_id, h.salesman_id);
    l_from  number;
    l_to    number;
    l_used1 number;
    l_used2 number;
    l_notif number;
    l_ava   number;
  begin
    -- BOOK_NO WHEN-VALIDATE-ITEM (fires when the number is entered / changed)
    if p_book_no is null or p_book_serial is null or l_sm is null
       or (h.trns_id is not null and nvl(h.book_no, -1) = p_book_no and nvl(h.book_serial, -1) = p_book_serial) then
      return null;
    end if;
    begin
      select from_serial, to_serial into l_from, l_to from ar_salesman_books where salesman_code = l_sm and book_serial = p_book_serial;
    exception when no_data_found then
      l_from := null; l_to := null;
    end;
    select count(1) into l_used1
      from check_mast
     where salesman_book_serial = p_book_serial and salesman_code = l_sm
       and trns_type_code in (select trns_type_code from check_trns_type where trns_type = 2);
    select count(1) into l_used2
      from ar_maintrns
     where book_serial = p_book_serial and salesman_id = l_sm and trns_id in (select id from ar_trnstype where trns_type = 3);
    select max(ar_books_notif) into l_notif from salesman where code = l_sm;
    -- the number entered is not counted yet (legacy counted the saved documents only)
    l_ava := (nvl(l_to, 0) - nvl(l_from, 0) + 1) - (case when l_used1 = l_used2 then l_used1 else l_used1 + l_used2 end);
    if nvl(l_notif, 0) >= nvl(l_ava, 0) and nvl(l_notif, 0) <> 0 then
      return lt('تذكير بعدد ارقام المستندات المتبقية بالدفتر = ' || nvl(l_ava, 0),
               'Avaliable Count of Document Number in this book = ' || nvl(l_ava, 0));
    end if;
    return null;
  end warn_book;

  function warn_cheque (p_rowid in varchar2, p_trns_id in number, p_cheque_number in number) return varchar2 is
    h   ar_maintrns%rowtype := header_row(p_rowid);
    l_n number;
  begin
    -- CHEQUE_NUMBER WHEN-VALIDATE-ITEM: MSG('رقم الشيك مكرر', ..., 0) - an alert only
    if p_cheque_number is null or (h.trns_id is not null and nvl(h.cheque_number, -1) = p_cheque_number) then
      return null;
    end if;
    select count(1) into l_n
      from ar_maintrns
     where cheque_number = p_cheque_number and trns_id = p_trns_id
       and (p_rowid is null or rowid <> chartorowid(p_rowid));
    if l_n > 0 then
      return lt('رقم الشيك مكرر', 'Cheque Number Repeted');
    end if;
    return null;
  end warn_cheque;

  -- ===================================================================================== shared detail checks
  function account_ok (p_account in number) return boolean is
    l_n  number;
    l_pw number := ctx_password;
    l_comp number := ctx_company;
  begin
    select count(*) into l_n from ac_master where account_number = p_account and account_status = 1;
    if l_n = 0 then
      return false;
    end if;
    if l_pw <> 0 then
      -- ACCOUNT record group: AC_PASSWORD_MASTER of the group
      select count(*) into l_n
        from ac_password_master p2
       where p2.password_number = l_pw and p2.company_code = l_comp and p2.account_number = p_account;
      return l_n > 0;
    end if;
    return true;
  end account_ok;

  -- AR_MAINTRNS_ACCOUNT_DET: value > 0, account of ACCOUNT_LOV, total = invoices * rate when AR_TRNSTYPE.ACCOUNT_TYPE = 5
  procedure check_account_det (h in ar_maintrns%rowtype, t in ar_trnstype%rowtype, p_base in number) is
    l_sum number := 0;
    l_n   number := 0;
  begin
    for a in (select * from ar_maintrns_account_det
               where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id
                 and trns_serial = h.trns_serial
               order by seq)
    loop
      l_n := l_n + 1;
      if a.trns_account is null or a.value is null then
        fail(-20150, 'يجب إدخال رقم الحساب و القيمة الموجهة');
      end if;
      if a.value <= 0 then
        fail(-20151, 'الربط بالحسابات: القيمة يجب أن تكون أكبر من الصفر (الحساب ' || a.trns_account || ')');
      end if;
      if not account_ok(a.trns_account) then
        fail(-20152, 'الربط بالحسابات: الحساب ' || a.trns_account || ' غير موجود أو ليس حساب فرعى أو غير مسموح لمجموعتك');
      end if;
      l_sum := l_sum + a.value;
    end loop;
    if nvl(t.account_type, 0) = 5 and round(l_sum, 2) <> round(nvl(p_base, 0) * nvl(h.currency_rate, 1), 2) then
      fail(-20153, 'اجمالى قيم ارقام الحركات (' || fmt(l_sum)
                   || ') لا يساوى اجمالى تفاصيل الحركة (' || fmt(nvl(p_base, 0) * nvl(h.currency_rate, 1)) || ')');
    end if;
  end check_account_det;

  -- invoice bill residual = total - allocations (AR_SUBTRNS_PAYED_VALUE), as APP_PROC_AR.MANUAL_ADJUST refreshes it
  -- (the legacy RESIDUAL_VALUE +/- value gives the same result when the stored residual is right)
  procedure refresh_invoice (p_trns_id number, p_mainarea number, p_subarea number, p_serial number, p_bill_seq number) is
    l_paid number;
  begin
    l_paid := ar_subtrns_payed_value(p_trns_id, p_serial, p_mainarea, p_subarea, p_bill_seq);
    update ar_subtrns
       set residual_value = total_value - l_paid
     where trns_id = p_trns_id and mainarea_id = p_mainarea and subarea_id = p_subarea and trns_serial = p_serial
       and bill_seq = p_bill_seq;
  end refresh_invoice;

  -- PRE-INSERT / DELETE_DETAIL_EFFECT of AR_SUBTRNS: payment residual = total - allocated nets, header discount = allocated
  -- totals - nets, header net = allocated nets (the net value of the payment when nothing is allocated)
  procedure refresh_payment (p_trns_id number, p_mainarea number, p_subarea number, p_serial number) is
  begin
    update ar_maintrns m
       set (residual_value, disc_value, net_value) =
           (select m.total_value - nvl(sum(nvl(s.net_value, s.total_value - nvl(s.disc_value, 0))), 0),
                   nvl(sum(s.total_value), 0) - nvl(sum(nvl(s.net_value, s.total_value - nvl(s.disc_value, 0))), 0),
                   case when count(s.bill_seq) > 0 then nvl(sum(nvl(s.net_value, s.total_value - nvl(s.disc_value, 0))), 0)
                        else m.total_value end
              from ar_subtrns s
             where s.trns_id = m.trns_id and s.mainarea_id = m.mainarea_id and s.subarea_id = m.subarea_id
               and s.trns_serial = m.trns_serial)
     where trns_id = p_trns_id and mainarea_id = p_mainarea and subarea_id = p_subarea and trns_serial = p_serial;
  end refresh_payment;

  procedure refresh_salesman_links (p_rowid in varchar2, h in ar_maintrns%rowtype) is
    l_sup number;
  begin
    -- AR_MAINTRNS_IN (BEFORE INSERT) may fire before APPX_AR_MAINTRNS derived SALESMAN_ID: fill SUPERVISOR_SLSMAN the same way
    if h.salesman_id is not null and h.supervisor_slsman is null then
      select max(supervisor_slsman) into l_sup from salesman where code = h.salesman_id;
      if l_sup is not null then
        update ar_maintrns set supervisor_slsman = l_sup where rowid = chartorowid(p_rowid);
      end if;
    end if;
  end refresh_salesman_links;

  -- ARCRTRN_ST / ARDBTRN_ST: running balances CUSTOMER.CRN_BAL_TOTAL and AR_CUST_SALESMAN.CRN_BAL_TOTAL kept by the forms
  procedure add_balance (p_customer_id number, p_salesman_id number, p_ctgry_code number, p_value number,
                         p_with_salesman boolean default true) is
  begin
    if nvl(p_value, 0) = 0 or p_customer_id is null then
      return;
    end if;
    update customer set crn_bal_total = nvl(crn_bal_total, 0) + nvl(p_value, 0) where code = p_customer_id;
    if p_with_salesman then
      update ar_cust_salesman set crn_bal_total = nvl(crn_bal_total, 0) + nvl(p_value, 0)
       where customer_code = p_customer_id and salesman_code = p_salesman_id and ctgry_code = p_ctgry_code;
    end if;
  end add_balance;

  -- ARCRTRN_ST INSERT_AR_OLD_TRNS: history copy of a payment (header + current lines) before it or its lines are deleted
  procedure copy_history (h in ar_maintrns%rowtype) is
    l_n      number;
    l_serial number;
  begin
    -- legacy: copied once (same keys, date, category, salesman and customer already in AR_MAINTRNS_OLD -> nothing)
    select count(*) into l_n
      from ar_maintrns_old
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial
       and trns_date = h.trns_date and ctgry_code = h.ctgry_code and salesman_id = h.salesman_id and customer_id = h.customer_id;
    if l_n > 0 or h.ctgry_code is null then
      return;
    end if;
    select nvl(max(serial), 0) + 1 into l_serial from ar_maintrns_old;
    insert into ar_maintrns_old (serial, trns_id, mainarea_id, subarea_id, trns_serial, trns_date, doc_no, ctgry_code, salesman_id,
                                 total_value, disc_value, net_value, description_a, description_e, customer_id, trns_account,
                                 customer_account, disc_account, post_flag, cost_no, cost_no2, acc_year, acc_date, acc_acc_seq,
                                 acc_disc_seq, acc_cust_seq, currency_code, currency_rate)
    values (l_serial, h.trns_id, h.mainarea_id, h.subarea_id, h.trns_serial, h.trns_date, h.doc_no, h.ctgry_code, h.salesman_id,
            h.total_value, h.disc_value, h.net_value, h.description_a, h.description_e, h.customer_id, h.trns_account,
            h.customer_account, h.disc_account, h.post_flag, h.cost_code1, h.cost_code2, h.acc_year, h.acc_date, h.acc_acc_seq,
            h.acc_disc_seq, h.acc_cust_seq, h.currency_code, h.currency_rate);
    insert into ar_subtrns_old (serial, trns_id, mainarea_id, subarea_id, trns_serial, bill_seq, bill_id1, bill_id2,
                                total_value, disc_value, net_value, residual_value)
    select l_serial, trns_id, mainarea_id, subarea_id, trns_serial, bill_seq, bill_id1, bill_id2,
           total_value, disc_value, net_value, residual_value
      from ar_subtrns
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
  end copy_history;

  -- ===================================================================================== discounts
  procedure calc_discount (p_customer_id in number, p_trns_id in number, p_ctgry_code in number, p_days in number,
                           p_total in number, o_disc out number, o_period out number, o_source out number,
                           p_class_period in number default 1)
  is
    l_days number := p_days;                         -- null (invoice without date): no period matches -> no discount
    l_prc  number;
    l_cap  number;
    l_per  number;
    l_src  number;
  begin
    if l_days < 0 then
      l_days := 1;                                   -- legacy: DIFFERANCE_DAYS < 0 -> 1
    end if;
    -- first matching row of each source (legacy FETCH of the cursor, no ORDER BY)
    begin
      select dscnt_prcnt, dscnt_value, period_serial into l_prc, l_cap, l_per
        from (select d.dscnt_prcnt, d.dscnt_value, d.period_serial
                from ar_cust_dscnt d, ar_period p
               where d.customer_code = p_customer_id
                 and ((l_days between p.from_p and p.to_p) or (l_days > p.from_p and p.to_p is null))
                 and d.period_serial = p.serial)
       where rownum = 1;
      l_src := 1;
    exception when no_data_found then
      begin
        select dscnt_prcnt, dscnt_value, period_serial into l_prc, l_cap, l_per
          from (select d.dscnt_prcnt, d.dscnt_value, d.period_serial
                  from customer c, ar_cust_class k, ar_cust_class_dscnt d, ar_period p
                 where c.code = p_customer_id
                   and ((l_days between p.from_p and p.to_p) or (l_days > p.from_p and p.to_p is null))
                   and c.cust_class = k.serial and k.serial = d.serial
                   and (p.serial = d.period_serial or p_class_period = 0)
                   and nvl(k.dscnt_stop_flag, 0) = 0)
         where rownum = 1;
        l_src := 2;
      exception when no_data_found then
        begin
          select dscnt_prcnt, dscnt_value, period_serial into l_prc, l_cap, l_per
            from (select d.dscnt_prcnt, d.dscnt_value, d.period_serial
                    from ar_trnstype_dscnt d, ar_period p
                   where d.id = p_trns_id
                     and ((l_days between p.from_p and p.to_p) or (l_days > p.from_p and p.to_p is null))
                     and d.period_serial = p.serial)
           where rownum = 1;
          l_src := 3;
        exception when no_data_found then
          begin
            select dscnt_prcnt, dscnt_value, period_serial into l_prc, l_cap, l_per
              from (select d.dscnt_prcnt, d.dscnt_value, d.period_serial
                      from ar_ctgry_dscnt d, ar_period p
                     where d.ctgry_code = p_ctgry_code
                       and ((l_days between p.from_p and p.to_p) or (l_days > p.from_p and p.to_p is null))
                       and d.period_serial = p.serial)
             where rownum = 1;
            l_src := 4;
          exception when no_data_found then
            l_src := null;
          end;
        end;
      end;
    end;
    o_source := l_src;
    o_period := l_per;
    if l_src is null then
      o_disc := 0;
    elsif nvl(l_cap, 0) = 0 then
      o_disc := (l_prc * p_total) / 100;
    else
      o_disc := least((l_prc * p_total) / 100, l_cap);   -- ACTUAL_DISC_VALUE > DSCNT_VALUE -> DSCNT_VALUE
    end if;
  end calc_discount;

  -- ===================================================================================== allocation of payments
  -- AR_SUBTRNS WHEN-NEW-BLOCK-INSTANCE / BILL_ID1 WVI: the detail description of an allocation line
  procedure alloc_desc (p_total number, p_inv_total number, p_inv_open number, p_bill_id1 number, p_bill_id2 number,
                        p_doc_no number, p_disc number, o_a out varchar2, o_e out varchar2) is
  begin
    if nvl(p_total, 0) = p_inv_total then
      o_a := 'سداد كامل الفاتورة (' || p_bill_id2 || '/' || p_bill_id1 || ')' || ' بسند قبض رقم(' || p_doc_no || ')'
             || ' بقيمة خصم(' || p_disc || ')';
      o_e := 'Pay total invoice value (' || p_bill_id2 || '/' || p_bill_id1 || ')' || ' with doc no(' || p_doc_no || ')'
             || ' with discount value(' || p_disc || ')';
    elsif nvl(p_total, 0) = p_inv_open then
      o_a := 'سداد باقى الفاتورة (' || p_bill_id2 || '/' || p_bill_id1 || ')' || ' بسند قبض رقم(' || p_doc_no || ')'
             || ' بقيمة خصم(' || p_disc || ')';
      o_e := 'Pay remain invoice value (' || p_bill_id2 || '/' || p_bill_id1 || ')' || ' with doc no(' || p_doc_no || ')'
             || ' with discount value(' || p_disc || ')';
    else
      o_a := 'سداد جزء من الفاتورة (' || p_bill_id2 || '/' || p_bill_id1 || ')' || ' بسند قبض رقم(' || p_doc_no || ')';
      o_e := 'Pay part of invoice value (' || p_bill_id2 || '/' || p_bill_id1 || ')' || ' with doc no(' || p_doc_no || ')';
    end if;
    o_a := substr(o_a, 1, 150);
    o_e := substr(o_e, 1, 150);
  end alloc_desc;

  -- header discount ratio (DISC_VAL WHEN-VALIDATE-ITEM) of a payment
  function disc_ratio (h in ar_maintrns%rowtype, p_total in number) return number is
  begin
    if nvl(h.disc_val, 0) <> 0 and nvl(p_total, 0) + nvl(h.disc_val, 0) <> 0 then
      return round(nvl(h.disc_val, 0) * (100 / (p_total + nvl(h.disc_val, 0))), 4);
    end if;
    return nvl(h.disc_val_ratio, 0);
  end disc_ratio;

  -- the payment's value not allocated yet: TRNS_TOTAL_DIFF = (TOTAL - allocated nets) + (DISC_VAL - allocated discounts)
  function payment_open (p_rowid in varchar2) return number is
    h     ar_maintrns%rowtype := header_row(p_rowid);
    l_net number;
    l_dsc number;
  begin
    if h.trns_id is null then
      return null;
    end if;
    select nvl(sum(nvl(net_value, total_value - nvl(disc_value, 0))), 0), nvl(sum(nvl(disc_value, 0)), 0)
      into l_net, l_dsc
      from ar_subtrns
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
    return (nvl(h.total_value, 0) - l_net) + (nvl(h.disc_val, 0) - l_dsc);
  end payment_open;

  -- one allocation line (AR_SUBTRNS PRE-INSERT of ARCRTRN / ARCRTRN_ST); the caller has checked the payment itself
  procedure insert_alloc (h in ar_maintrns%rowtype, p_screen in varchar2, p_inv in ar_subtrns%rowtype, p_inv_date in date,
                          p_inv_open in number, p_total in number, p_disc in number, p_period in number, p_source in number,
                          p_doc_no in number) is
    l_st      boolean := upper(p_screen) = 'ARCRTRN_ST';
    l_stn     pls_integer := case when upper(p_screen) = 'ARCRTRN_ST' then 1 else 0 end;
    l_n       number;
    l_seq     number;
    l_a       varchar2(150);
    l_e       varchar2(150);
    l_net     number := p_total - nvl(p_disc, 0);
    l_line    varchar2(300) := 'الفاتورة ' || p_inv.bill_id2 || '/' || p_inv.bill_id1 || ': ';
    l_plus    number;
    l_nets    number;
  begin
    -- AR_SUBTRNS PRE-INSERT: the bill numbers must identify exactly one invoice of the customer (ARCRTRN_ST: and category)
    select count(1) into l_n
      from ar_subtrns s, ar_maintrns m
     where m.trns_id in (select id from ar_trnstype where effect = 0)
       and m.trns_id = s.trns_id and m.mainarea_id = s.mainarea_id and m.subarea_id = s.subarea_id and m.trns_serial = s.trns_serial
       and m.customer_id = h.customer_id
       and s.bill_id1 = p_inv.bill_id1
       and ((l_stn = 0 and nvl(s.bill_id2, 0) = nvl(p_inv.bill_id2, 0))
            or (l_stn = 1 and s.bill_id2 = p_inv.bill_id2 and m.ctgry_code = h.ctgry_code and nvl(s.residual_value, 0) != 0));
    if l_n <> 1 then
      fail(-20145, l_line || lt('ارقام الفواتير التى تم إدخالها لا تخص العميل هذا العميل',
                               'The bill code you have entered is not belong to the customer you have selected'));
    end if;
    -- ARCRTRN_ST PRE-INSERT: the invoice date cannot be after the payment date
    if l_st and trunc(p_inv_date) > trunc(h.trns_date) then
      fail(-20163, l_line || lt('تاريخ الفاتورة لا يمكن ان يكون اكبر من تاريخ الحركة',
                               'The invoice date can''t be over than the transaction date '));
    end if;
    -- CHECK_REPEAT: the invoice is already in this payment ('فاتورة مكررة')
    select count(1) into l_n
      from ar_subtrns
     where trns_id = h.trns_id and trns_serial = h.trns_serial and subarea_id = h.subarea_id and mainarea_id = h.mainarea_id
       and bill_id1 = p_inv.bill_id1 and bill_id2 = p_inv.bill_id2;
    if l_n > 0 then
      fail(-20147, l_line || lt('فاتورة مكررة', 'Invoice Repeated'));
    end if;
    if nvl(p_disc, 0) > p_total then
      fail(-20144, l_line || lt('قيمة الخصم لابد أن تكون أقل من القيمة المدخلة للفاتورة',
                               'Discount value has to be less than the total value of the invoice'));
    end if;
    if p_inv_open < p_total then
      fail(-20146, l_line || lt('القيمة المتبقية بالفاتورة أصغر من القيمة المدخلة للسداد',
                               'The residual value for the invoice is less than the entered value'));
    end if;
    select nvl(sum(nvl(net_value, total_value - nvl(disc_value, 0))), 0) into l_nets
      from ar_subtrns
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
    if h.total_value < l_nets + l_net then
      fail(-20142, lt('قيمة الفواتير المسددة يجب أن تكون أقل من القيمة الكلية للسداد',
                     'Invoices value has to be less than total value of the transaction'));
    end if;

    select nvl(max(bill_seq), 0) + 1 into l_seq
      from ar_subtrns
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
    alloc_desc(p_total, p_inv.total_value, p_inv_open, p_inv.bill_id1, p_inv.bill_id2, p_doc_no, nvl(p_disc, 0), l_a, l_e);
    insert into ar_subtrns (trns_id, mainarea_id, subarea_id, trns_serial, bill_seq, bill_id1, bill_id2, store_code,
                            total_value, disc_value, net_value, det_desc, det_desc_e, inv_pay_date, dscnt_period, dscnt_source,
                            post_flag, inv_trns_id, inv_trns_serial, inv_mainarea_id, inv_subarea_id, inv_bill_seq,
                            without_comm_flag)
    values (h.trns_id, h.mainarea_id, h.subarea_id, h.trns_serial, l_seq, p_inv.bill_id1, p_inv.bill_id2, p_inv.store_code,
            p_total, nvl(p_disc, 0), l_net, l_a, l_e,
            case when p_inv_date > h.trns_date then p_inv_date else h.trns_date end, p_period, p_source,
            nvl(h.post_flag, 0), p_inv.trns_id, p_inv.trns_serial, p_inv.mainarea_id, p_inv.subarea_id, p_inv.bill_seq, 0);

    -- UPDATE AR_SUBTRNS SET RESIDUAL_VALUE = RESIDUAL_VALUE - :total (invoice) / UPDATE AR_MAINTRNS SET RESIDUAL_VALUE -
    -- :net, DISC_VALUE = TRNS_TOTAL - TRNS_NET, NET_VALUE = TRNS_NET (payment)
    refresh_invoice(p_inv.trns_id, p_inv.mainarea_id, p_inv.subarea_id, p_inv.trns_serial, p_inv.bill_seq);
    refresh_payment(h.trns_id, h.mainarea_id, h.subarea_id, h.trns_serial);
    -- ARCRTRN_ST: CUSTOMER / AR_CUST_SALESMAN.CRN_BAL_TOTAL - discount of the line
    if l_st then
      add_balance(h.customer_id, h.salesman_id, h.ctgry_code, -nvl(p_disc, 0));
    end if;
    -- AR_TRNSTYPE.PLUS_INV_NO_FLAG: the invoice number is appended to the payment description
    select nvl(max(plus_inv_no_flag), 0) into l_plus from ar_trnstype where id = h.trns_id;
    if l_plus = 1 then
      begin
        update ar_maintrns
           set description_a = description_a || ' ' || 'ف(' || p_inv.bill_id2 || '/' || p_inv.bill_id1 || ')',
               description_e = description_e || ' ' || 'Bill(' || p_inv.bill_id2 || '/' || p_inv.bill_id1 || ')'
         where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
      exception when others then
        if sqlcode in (-12899, -1401) then
          fail(-20148, lt('الوصف المدخل اكبر من الحد المسموح به', 'The description you have entered is too long'));
        end if;
        raise;
      end;
    end if;
  end insert_alloc;

  procedure add_allocation (p_rowid in varchar2, p_invoice in varchar2, p_amount in number default null,
                            p_disc in number default null, p_screen in varchar2 default 'ARCRTRN')
  is
    h        ar_maintrns%rowtype := header_row(p_rowid);
    l_st     boolean := upper(p_screen) = 'ARCRTRN_ST';
    l_inv    ar_subtrns%rowtype;
    l_date   date;
    l_open   number;
    l_diff   number;
    l_total  number;
    l_disc   number;
    l_period number;
    l_source number;
    l_ratio  number;
    l_cust   number;
    l_ctg    number;
    k1 number; k2 number; k3 number; k4 number; k5 number;
    function part (p_n pls_integer) return number is
    begin
      return to_number(regexp_substr(p_invoice, '[^:]+', 1, p_n));
    end part;
  begin
    if h.trns_id is null then
      fail(-20149, lt('حركة السداد غير موجودة', 'Payment transaction not found'));
    end if;
    -- PAY_METHOD_LIST WHEN-VALIDATE-ITEM: method 4 closes the allocation lines (INSERT_ALLOWED false)
    if nvl(h.pay_method, 2) = 4 then
      fail(-20164, lt('طريقة الدفع 4 (مبلغ دائن لعميل) لا تسمح بتفاصيل سداد',
                      'Pay method 4 (Debit Sum For Client) has no pay details'));
    end if;
    begin
      k1 := part(1); k2 := part(2); k3 := part(3); k4 := part(4); k5 := part(5);
      select * into l_inv
        from ar_subtrns
       where trns_id = k1 and mainarea_id = k2 and subarea_id = k3 and trns_serial = k4 and bill_seq = k5;
      select customer_id, ctgry_code, trns_date into l_cust, l_ctg, l_date
        from ar_maintrns
       where trns_id = l_inv.trns_id and mainarea_id = l_inv.mainarea_id and subarea_id = l_inv.subarea_id
         and trns_serial = l_inv.trns_serial and trns_id in (select id from ar_trnstype where effect = 0);
    exception when no_data_found or value_error or invalid_number then
      fail(-20145, lt('ارقام الفواتير التى تم إدخالها لا تخص العميل هذا العميل',
                     'The bill code you have entered is not belong to the customer you have selected'));
    end;
    if l_cust <> h.customer_id or (l_st and nvl(l_ctg, -1) <> nvl(h.ctgry_code, -1)) then
      fail(-20145, lt('ارقام الفواتير التى تم إدخالها لا تخص العميل هذا العميل',
                     'The bill code you have entered is not belong to the customer you have selected'));
    end if;
    -- BILL_LOV residual: TOTAL - AR_SUBTRNS_PAYED_VALUE (ARCRTRN_ST: the stored RESIDUAL_VALUE)
    if l_st then
      l_open := nvl(l_inv.residual_value, 0);
    else
      l_open := l_inv.total_value - ar_subtrns_payed_value(l_inv.trns_id, l_inv.trns_serial, l_inv.mainarea_id,
                                                           l_inv.subarea_id, l_inv.bill_seq);
    end if;
    -- BILL_ID1 WHEN-VALIDATE-ITEM: TOTAL_VALUE := least(TRNS_TOTAL_DIFF, INV_RESIDUAL_VALUE); CALCULATE_DISCOUNT with
    -- INV_TRNS_DATE = the bill's INV_DATE (BILL_LOV); an invoice without INV_DATE gets no period discount
    l_diff := payment_open(p_rowid);
    l_total := nvl(p_amount, case when nvl(l_diff, 0) < nvl(l_open, 0) then l_diff else l_open end);
    if nvl(l_total, 0) <= 0 then
      fail(-20143, lt('القيمة يجب أن تكون أكبر من الصفر', 'The value should be over than zero'));
    end if;
    calc_discount(h.customer_id, h.trns_id, h.ctgry_code, trunc(h.trns_date) - trunc(l_inv.inv_date),
                  case when l_st then l_inv.total_value else l_total end, l_disc, l_period, l_source);
    -- DISC_VALUE_PREC := header DISC_VAL_RATIO; TOTAL_VALUE / DISC_VALUE_PREC WHEN-VALIDATE-ITEM: a header ratio replaces
    -- the period discount
    l_ratio := disc_ratio(h, h.total_value);
    if nvl(l_ratio, 0) <> 0 then
      l_disc := round(l_ratio * l_total / 100, 2);
    end if;
    -- DISC_VALUE typed by the user
    if p_disc is not null then
      l_disc := p_disc;
    end if;
    l_disc := round(nvl(l_disc, 0), 2);
    insert_alloc(h, p_screen, l_inv, l_inv.inv_date, l_open, l_total, l_disc, l_period, l_source, h.doc_no);
  end add_allocation;

  -- PAY_METHOD 1 (AR_SUBTRNS WHEN-NEW-BLOCK-INSTANCE with EXPAND_FLAG): the payment and the header discount are spread
  -- over the open invoices of the customer, oldest first, with the header discount ratio
  procedure auto_allocate (h in ar_maintrns%rowtype, p_screen in varchar2, p_total in number, p_ratio in number,
                           p_doc_no in number) is
    l_stn        pls_integer := case when upper(p_screen) = 'ARCRTRN_ST' then 1 else 0 end;
    l_remain_pay number := nvl(p_total, 0) + nvl(h.disc_val, 0);    -- TOTAL_TRNS_VALUE
    l_remain_dsc number := nvl(h.disc_val, 0);
    l_total      number;
    l_disc       number;
    l_net        number;
    l_inv        ar_subtrns%rowtype;
  begin
    for c in (select s.trns_id, s.mainarea_id, s.subarea_id, s.trns_serial, s.bill_seq, s.bill_id1, s.bill_id2, s.store_code,
                     s.total_value, m.trns_date,
                     case when l_stn = 1 then nvl(s.residual_value, 0)
                          else s.total_value - ar_subtrns_payed_value(s.trns_id, s.trns_serial, s.mainarea_id, s.subarea_id, s.bill_seq)
                     end residual
                from ar_subtrns s, ar_maintrns m
               where m.trns_id in (select id from ar_trnstype where effect = 0)
                 and m.trns_id = s.trns_id and m.mainarea_id = s.mainarea_id and m.subarea_id = s.subarea_id
                 and m.trns_serial = s.trns_serial
                 and m.customer_id = h.customer_id
                 and (l_stn = 0 or m.ctgry_code = h.ctgry_code)
                 and case when l_stn = 1 then nvl(s.residual_value, 0)
                          else s.total_value - ar_subtrns_payed_value(s.trns_id, s.trns_serial, s.mainarea_id, s.subarea_id, s.bill_seq)
                     end != 0
               order by m.trns_date, s.bill_id1, s.bill_id2)
    loop
      exit when l_remain_pay = 0;
      -- the new record's DISC_VALUE_PREC is still empty when TOTAL_VALUE is computed
      if c.residual > l_remain_pay then
        l_total := l_remain_pay;
      else
        l_total := c.residual;
      end if;
      l_disc := case when nvl(p_ratio, 0) <> 0 then round(nvl(p_ratio, 0) * (nvl(l_total, 0) / 100), 2) else 0 end;
      l_net := l_total - nvl(l_disc, 0);
      if l_net > l_remain_pay then
        l_total := l_remain_pay;
        l_remain_pay := 0;
        l_disc := case when nvl(p_ratio, 0) <> 0 then round(nvl(p_ratio, 0) * (nvl(l_total, 0) / 100), 2) else 0 end;
        l_remain_dsc := l_remain_dsc - l_disc;
        if l_remain_dsc <> 0 then
          l_disc := l_disc + l_remain_dsc;
        end if;
      else
        l_remain_pay := l_remain_pay - l_net - l_disc;
        l_remain_dsc := l_remain_dsc - l_disc;
        if l_remain_dsc < 0 then
          l_disc := l_disc + l_remain_dsc;
        end if;
      end if;
      l_inv.trns_id := c.trns_id; l_inv.mainarea_id := c.mainarea_id; l_inv.subarea_id := c.subarea_id;
      l_inv.trns_serial := c.trns_serial; l_inv.bill_seq := c.bill_seq; l_inv.bill_id1 := c.bill_id1;
      l_inv.bill_id2 := c.bill_id2; l_inv.store_code := c.store_code; l_inv.total_value := c.total_value;
      insert_alloc(h, p_screen, l_inv, c.trns_date, c.residual, l_total, l_disc, null, null, p_doc_no);
    end loop;
  end auto_allocate;

  -- lines removed by this package (PAY_METHOD 4): the delete hook stands aside, the effects are applied here
  procedure remove_allocations (h in ar_maintrns%rowtype, p_screen in varchar2) is
  begin
    g_in_hook := true;
    for d in (select * from ar_subtrns
               where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id
                 and trns_serial = h.trns_serial)
    loop
      delete from ar_subtrns
       where trns_id = d.trns_id and mainarea_id = d.mainarea_id and subarea_id = d.subarea_id
         and trns_serial = d.trns_serial and bill_seq = d.bill_seq;
      if d.inv_trns_id is not null then
        refresh_invoice(d.inv_trns_id, d.inv_mainarea_id, d.inv_subarea_id, d.inv_trns_serial, d.inv_bill_seq);
      end if;
      if upper(p_screen) = 'ARCRTRN_ST' then
        add_balance(h.customer_id, h.salesman_id, h.ctgry_code, nvl(d.disc_value, 0));
      end if;
    end loop;
    g_in_hook := false;
  exception when others then
    g_in_hook := false;
    raise;
  end remove_allocations;

  -- ===================================================================================== debit transactions
  procedure after_save_debit (p_screen in varchar2, p_rowid in varchar2, p_request in varchar2) is
    h        ar_maintrns%rowtype;
    t        ar_trnstype%rowtype;
    c        customer%rowtype;
    l_st     boolean := upper(p_screen) = 'ARDBTRN_ST';
    l_stn    pls_integer := case when upper(p_screen) = 'ARDBTRN_ST' then 1 else 0 end;
    l_open   date;
    l_total  number;
    l_res    number;
    l_due    date;
    l_store  number;
    l_n      number;
    l_new    number := 0;
    l_tot    number;
    l_net    number;
    l_inv    number;
    l_acc    number;
    l_doc    number;
    l_stot   number;
    l_limit  number;
    l_bal    number;
    l_line   varchar2(300);
    l_msg    varchar2(400);
    l_posted boolean;
    l_found  boolean;
  begin
    if p_rowid is null then
      return;
    end if;
    begin
      select * into h from ar_maintrns where rowid = chartorowid(p_rowid);
    exception when no_data_found or value_error then
      return;
    end;
    t := trnstype(h.trns_id);
    c := customer_row(h.customer_id);
    l_posted := nvl(h.post_flag, 0) = 1 or nvl(h.pay_flag, 0) = 1;
    select max(m.trns_date) into l_open
      from ar_maintrns_op m, ar_subtrns_op d, ar_trnstype x
     where m.trns_id = d.trns_id and m.trns_serial = d.trns_serial and m.trns_id = x.id
       and d.customer_id = h.customer_id and x.trns_type = 6;

    -- ARDBTRN, posted / paid transaction (CLOSE_POSTED "ZEB" branch): no invoice line added or removed, INV_DATE /
    -- BILL_ID1 / INV_VALUE of the lines and the account lines locked
    if l_posted and not l_st and g_dsnap_rowid = p_rowid then
      for s in (select * from ar_subtrns
                 where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id
                   and trns_serial = h.trns_serial)
      loop
        l_found := false;
        for i in 1 .. g_dsnap.count loop
          if g_dsnap(i).bill_seq = s.bill_seq then
            l_found := true;
            if nvl(g_dsnap(i).bill_id1, -1) <> nvl(s.bill_id1, -1)
               or nvl(to_char(g_dsnap(i).inv_date, 'YYYYMMDD'), '-') <> nvl(to_char(s.inv_date, 'YYYYMMDD'), '-')
               or nvl(g_dsnap(i).inv_value, -1) <> nvl(s.inv_value, -1) then
              fail(-20154, 'الحركة مرحلة أو مسددة: لا يمكن تعديل رقم وتاريخ وقيمة الفاتورة (يمكن تعديل رقم الفاتورة الثاني وتاريخ الاستحقاق فقط)');
            end if;
          end if;
        end loop;
        if not l_found then
          fail(-20155, 'لا يجوز الإضافة علي الحركة الحالية لكونها مرحلة');
        end if;
      end loop;
      select count(*) into l_n
        from ar_maintrns_account_det
       where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
      l_found := l_n = g_asnap.count;
      if l_found then
        for i in 1 .. g_asnap.count loop
          select count(*) into l_n
            from ar_maintrns_account_det
           where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial
             and seq = g_asnap(i).seq and nvl(trns_account, -1) = nvl(g_asnap(i).trns_account, -1)
             and nvl(value, -1) = nvl(g_asnap(i).value, -1) and nvl(cost_code1, -1) = nvl(g_asnap(i).cost_code1, -1)
             and nvl(cost_code2, -1) = nvl(g_asnap(i).cost_code2, -1);
          if l_n = 0 then l_found := false; end if;
        end loop;
      end if;
      if not l_found then
        fail(-20156, 'الحركة مرحلة أو مسددة: لا يمكن تعديل الربط بالحسابات');
      end if;
    end if;

    -- invoice lines (AR_SUBTRNS)
    for s in (select rowid rid, s.* from ar_subtrns s
               where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id
                 and trns_serial = h.trns_serial
               order by bill_seq)
    loop
      l_line := 'الفاتورة ' || s.bill_id1 || case when s.bill_id2 is not null then '/' || s.bill_id2 end || ': ';
      -- INV_VALUE WHEN-VALIDATE-ITEM: TOTAL_VALUE = INV_VALUE (+ taxes for sales invoices, TRNS_TYPE = 0)
      l_total := case when s.inv_value is not null
                      then s.inv_value + case when t.trns_type = 0 then nvl(s.tax_value1, 0) + nvl(s.tax_value2, 0) else 0 end
                      else s.total_value end;
      if nvl(l_total, 0) <= 0 then
        fail(-20130, l_line || 'القيمة يجب أن تكون أكبر من الصفر');
      end if;
      if s.bill_id1 is null then
        fail(-20131, 'يجب إدخال رقم الفاتورة');
      end if;
      -- INV_DATE / INVOICE_CLASS WHEN-VALIDATE-ITEM
      if trunc(s.inv_date) > trunc(h.trns_date) then
        fail(-20132, l_line || 'تاريخ الفاتورة لا يمكن ان يكون اكبر من تاريخ الحركة');
      end if;
      if c.open_date is not null and trunc(s.inv_date) < trunc(c.open_date) then
        fail(-20133, l_line || 'تاريخ الفاتورة لا يمكن ان يكون اقل من تاريخ فتح العميل');
      end if;
      if l_open is not null and trunc(s.inv_date) < trunc(l_open) then
        fail(-20134, l_line || 'تاريخ الفاتورة لا يمكن ان يقل عن تاريخ الرصيد الافتتاحي للعميل');
      end if;
      -- INV_DATE WHEN-VALIDATE-ITEM of ARDBTRN: CHECK_DATE(:AR_SUBTRNS.INV_DATE)
      if not l_st then
        l_msg := check_dates(p_screen, s.inv_date);
        if l_msg is not null then
          fail(-20157, l_line || l_msg);
        end if;
      end if;
      l_due := s.invoice_class;
      l_store := s.store_code;
      if s.residual_value is null then
        -- new line (the grid does not carry RESIDUAL_VALUE): legacy PRE-INSERT / WHEN-VALIDATE-ITEM values
        l_new := l_new + 1;
        l_res := l_total;                                        -- RESIDUAL_VALUE := TOTAL_VALUE
        if not l_st then
          if l_due is null and c.day_no is not null then
            l_due := s.inv_date + c.day_no;                      -- INVOICE_CLASS := INV_DATE + CUSTOMER.DAY_NO
          end if;
          l_store := nvl(l_store, c_default_store);              -- STORE_CODE initial value
          -- BILL_ID1 WHEN-VALIDATE-ITEM: 'رقم عقد مكرر'
          select count(*) into l_n from ar_subtrns where bill_id1 = s.bill_id1 and rowid <> s.rid;
          if l_n > 0 then
            fail(-20135, l_line || 'رقم الفاتورة مكرر (رقم عقد مكرر)');
          end if;
        else
          -- ARDBTRN_ST AR_SUBTRNS PRE-INSERT: CUSTOMER.CRN_BAL_TOTAL + TOTAL_VALUE of the invoice
          add_balance(h.customer_id, null, null, l_total, false);
        end if;
        -- PRE-INSERT / BILL_ID2 WHEN-VALIDATE-ITEM: 'توجد فاتورة بنفس الرقم'
        select count(*) into l_n
          from ar_subtrns
         where bill_id1 = nvl(s.bill_id1, 0) and bill_id2 = nvl(s.bill_id2, 0) and rowid <> s.rid
           and trns_id in (select id from ar_trnstype where effect = 0);
        if l_n > 0 then
          fail(-20136, l_line || 'توجد فاتورة بنفس الرقم');
        end if;
      elsif l_total <> nvl(s.total_value, -1) then
        -- value changed on a saved line: residual = new total - what is already allocated (AR_SUBTRNS_PAYED_VALUE)
        l_res := l_total - ar_subtrns_payed_value(s.trns_id, s.trns_serial, s.mainarea_id, s.subarea_id, s.bill_seq);
      else
        l_res := s.residual_value;
      end if;
      if l_res < 0 then
        fail(-20129, l_line || 'قيمة الفاتورة أقل من المسدد منها');
      end if;
      if l_due is not null and (trunc(l_due) < trunc(s.inv_date) or trunc(l_due) < trunc(h.trns_date)) then
        fail(-20137, l_line || 'تاريخ الإستحقاق لا يمكن أن يكون أقل من تاريخ الفاتورة أو تاريخ الحركة');
      end if;
      if l_total <> nvl(s.total_value, -1) or l_res <> nvl(s.residual_value, -1) or nvl(s.disc_value, -1) <> 0
         or nvl(l_due, date '1000-01-01') <> nvl(s.invoice_class, date '1000-01-01') or nvl(l_store, -1) <> nvl(s.store_code, -1) then
        update ar_subtrns
           set total_value = l_total, residual_value = l_res, disc_value = 0, invoice_class = l_due, store_code = l_store
         where rowid = s.rid;
      end if;
    end loop;

    -- VALIDATE_DETAIL_SUM: header totals from the invoices
    select nvl(sum(total_value), 0), nvl(sum(total_value - nvl(disc_value, 0)), 0), nvl(sum(inv_value), 0), count(*)
      into l_tot, l_net, l_inv, l_n
      from ar_subtrns
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
    if l_n = 0 and upper(nvl(p_request, 'SAVE')) <> 'CREATE' then
      fail(-20138, 'لابد من إدخال فواتير الحركة');
    end if;
    select nvl(sum(value), 0) into l_acc
      from ar_maintrns_account_det
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;

    -- screen-specific derivations of a new transaction (PRE-INSERT of ARDBTRN; LINK_FLAG of the "other systems" screen)
    l_doc  := h.doc_no;
    l_stot := h.trns_serial_total;
    if not l_st then
      if l_doc is null then l_doc := next_doc_no(h.trns_id); end if;
      if l_stot is null then l_stot := next_serial_total; end if;
    end if;
    update ar_maintrns
       set total_value       = l_tot,
           net_value         = l_net,
           disc_value        = 0,
           doc_no            = l_doc,
           trns_serial_total = l_stot,
           link_flag         = nvl(link_flag, case when l_stn = 1 then 1 else 0 end),
           post_flag         = nvl(post_flag, 0),
           pay_flag          = nvl(pay_flag, 0),
           cash_flag         = case when l_stn = 1 then cash_flag else nvl(cash_flag, 2) end,
           currency_code     = nvl(currency_code, c.currency_code),
           currency_rate     = nvl(currency_rate, 1),
           trns_account      = case when l_stn = 0 and l_acc <> 0 then 1 else trns_account end
     where rowid = chartorowid(p_rowid);
    refresh_salesman_links(p_rowid, h);

    if upper(nvl(p_request, 'SAVE')) <> 'CREATE' and not l_st then
      -- VALIDATE_DETAIL_SUM / AR_MAINTRNS_ACCOUNT_DET PRE-INSERT: accounts total = invoices (INV_VALUE) * rate
      select * into h from ar_maintrns where rowid = chartorowid(p_rowid);
      check_account_det(h, t, l_inv);
    end if;

    -- VALIDATE_CR_LIMIT (ARDBTRN, new invoice lines): balance at the transaction date must not exceed CUSTOMER.CREDIT_LIMIT
    -- (the "other systems" form has no credit-limit check)
    if l_new > 0 and not l_st then
      l_limit := get_customer_crdt_lmt(h.customer_id);
      if nvl(l_limit, 0) <> 0 then
        l_bal := get_customer_bal(h.customer_id, nvl(h.trns_date, sysdate));
        if l_limit < l_bal then
          fail(-20139, 'لقد تعديت حد الإئتمان ' || fmt(l_limit) || ' للعميل (الرصيد بعد الحركة ' || fmt(l_bal) || ')');
        end if;
      end if;
    end if;
    g_dsnap.delete; g_asnap.delete; g_dsnap_rowid := null;
  end after_save_debit;

  -- ===================================================================================== credit transactions
  procedure after_save_credit (p_screen in varchar2, p_rowid in varchar2, p_request in varchar2) is
    h        ar_maintrns%rowtype;
    t        ar_trnstype%rowtype;
    c        customer%rowtype;
    l_st     boolean := upper(p_screen) = 'ARCRTRN_ST';
    l_stn    pls_integer := case when upper(p_screen) = 'ARCRTRN_ST' then 1 else 0 end;
    l_create boolean := upper(nvl(p_request, 'SAVE')) = 'CREATE';
    l_total  number;
    l_tot    number;
    l_net    number;
    l_n      number;
    l_doc    number;
    l_stot   number;
    l_ratio  number;
    l_pm     number;
    l_line   varchar2(300);
    l_inv    ar_subtrns%rowtype;
    l_inv_date date;
    l_open   number;
    l_disc   number;
    l_period number;
    l_source number;
    l_a      varchar2(150);
    l_e      varchar2(150);
    l_desc_a varchar2(2000);
    l_desc_e varchar2(2000);
  begin
    if p_rowid is null then
      return;
    end if;
    begin
      select * into h from ar_maintrns where rowid = chartorowid(p_rowid);
    exception when no_data_found or value_error then
      return;
    end;
    t := trnstype(h.trns_id);
    c := customer_row(h.customer_id);
    l_pm := nvl(h.pay_method, 2);                                     -- TRNS_ID WHEN-VALIDATE-ITEM: PAY_METHOD := 2

    -- GET_TAX: TOTAL_VALUE = INV_VALUE (+ TAX_VALUE1 when T_TAX_FLAG1 in (1,3)); the "other systems" screen enters TOTAL_VALUE
    l_total := case when h.inv_value is not null
                    then h.inv_value + case when nvl(h.t_tax_flag1, 0) in (1, 3) then nvl(h.tax_value1, 0) else 0 end
                    else h.total_value end;
    if nvl(l_total, 0) <= 0 then
      fail(-20140, 'القيمة يجب ان تكون اكبر من الصفر');
    end if;
    -- SET_DISC_ENABLED: pay method 4 has no header discount
    if l_pm = 4 then
      h.disc_val := 0; h.disc_val_ratio := 0;
    end if;
    if nvl(h.disc_val, 0) > l_total then
      fail(-20141, 'قيمة الخصم لابد أن تكون أقل من القيمة المدخلة للفاتورة');
    end if;
    if nvl(h.disc_val, 0) <> 0 then
      l_ratio := round(nvl(h.disc_val, 0) * (100 / (l_total + nvl(h.disc_val, 0))), 4);     -- DISC_VAL WHEN-VALIDATE-ITEM
    else
      l_ratio := nvl(h.disc_val_ratio, 0);
    end if;
    -- CUSTOMER_ID WHEN-VALIDATE-ITEM (ARCRTRN): DESCRIPTION := type description || ' - ' || customer name
    if not l_st and h.description_a is null then
      l_desc_a := substr(t.description_a || ' - ' || c.name_a, 1, 2000);
      l_desc_e := substr(t.description_e || ' - ' || c.name_e, 1, 2000);
    end if;
    update ar_maintrns
       set total_value = l_total, disc_val = nvl(h.disc_val, 0), disc_val_ratio = l_ratio, pay_method = l_pm,
           description_a = nvl(description_a, l_desc_a), description_e = nvl(description_e, l_desc_e)
     where rowid = chartorowid(p_rowid);
    select * into h from ar_maintrns where rowid = chartorowid(p_rowid);

    -- allocation lines removed in the grid: give the paid value back to the invoice (DELETE_DETAIL_EFFECT)
    if g_snap_rowid = p_rowid then
      for i in 1 .. g_snap.count loop
        select count(*) into l_n
          from ar_subtrns
         where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id
           and trns_serial = h.trns_serial and bill_seq = g_snap(i).bill_seq;
        if l_n = 0 and g_snap(i).inv_trns_id is not null then
          refresh_invoice(g_snap(i).inv_trns_id, g_snap(i).inv_mainarea_id, g_snap(i).inv_subarea_id,
                          g_snap(i).inv_trns_serial, g_snap(i).inv_bill_seq);
        end if;
      end loop;
    end if;
    g_snap.delete;
    g_snap_rowid := null;

    -- allocation lines typed in the grid (ARCRTRN_ST; BILL_LOV + AR_SUBTRNS PRE-INSERT): link the customer's invoice,
    -- reduce its residual, CALCULATE_DISCOUNT when no discount was typed
    for s in (select rowid rid, s.* from ar_subtrns s
               where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id
                 and trns_serial = h.trns_serial and inv_trns_id is null
               order by bill_seq)
    loop
      l_line := 'الفاتورة ' || s.bill_id1 || case when s.bill_id2 is not null then '/' || s.bill_id2 end || ': ';
      if nvl(s.total_value, 0) <= 0 then
        fail(-20143, l_line || 'القيمة يجب أن تكون أكبر من الصفر');
      end if;
      -- AR_SUBTRNS PRE-INSERT: one invoice of the customer with these bill numbers (ARCRTRN_ST: of the category, still open)
      begin
        select i.trns_id, i.mainarea_id, i.subarea_id, i.trns_serial, i.bill_seq, i.total_value, i.store_code,
               i.residual_value, i.inv_date
          into l_inv.trns_id, l_inv.mainarea_id, l_inv.subarea_id, l_inv.trns_serial, l_inv.bill_seq,
               l_inv.total_value, l_inv.store_code, l_inv.residual_value, l_inv_date
          from ar_subtrns i, ar_maintrns m
         where m.trns_id = i.trns_id and m.mainarea_id = i.mainarea_id and m.subarea_id = i.subarea_id
           and m.trns_serial = i.trns_serial
           and m.trns_id in (select id from ar_trnstype where effect = 0)
           and m.customer_id = h.customer_id
           and i.bill_id1 = s.bill_id1
           and ((l_stn = 0 and nvl(i.bill_id2, 0) = nvl(s.bill_id2, 0))
                or (l_stn = 1 and i.bill_id2 = s.bill_id2 and m.ctgry_code = h.ctgry_code and nvl(i.residual_value, 0) != 0));
      exception when no_data_found or too_many_rows then
        fail(-20145, l_line || 'ارقام الفواتير التى تم إدخالها لا تخص العميل هذا العميل');
      end;
      if l_st and trunc(l_inv_date) > trunc(h.trns_date) then
        fail(-20163, l_line || lt('تاريخ الفاتورة لا يمكن ان يكون اكبر من تاريخ الحركة',
                                  'The invoice date can''t be over than the transaction date '));
      end if;
      -- residual of the invoice: ARCRTRN TOTAL - AR_SUBTRNS_PAYED_VALUE (the typed line is not linked yet),
      -- ARCRTRN_ST the stored RESIDUAL_VALUE
      if l_st then
        l_open := nvl(l_inv.residual_value, 0);
      else
        l_open := l_inv.total_value - ar_subtrns_payed_value(l_inv.trns_id, l_inv.trns_serial, l_inv.mainarea_id,
                                                             l_inv.subarea_id, l_inv.bill_seq);
      end if;
      if round(s.total_value, 2) > round(l_open, 2) then
        fail(-20146, l_line || 'القيمة المتبقية بالفاتورة أصغر من القيمة المدخلة للسداد');
      end if;
      l_disc := s.disc_value; l_period := s.dscnt_period; l_source := s.dscnt_source;
      if l_disc is null then
        calc_discount(h.customer_id, h.trns_id, h.ctgry_code, trunc(h.trns_date) - trunc(l_inv_date),
                      case when l_st then l_inv.total_value else s.total_value end, l_disc, l_period, l_source);
        if nvl(l_ratio, 0) <> 0 then
          l_disc := round(l_ratio * s.total_value / 100, 2);
        end if;
        l_disc := round(nvl(l_disc, 0), 2);
      end if;
      if nvl(l_disc, 0) > s.total_value then
        fail(-20144, l_line || 'قيمة الخصم لابد أن تكون أقل من القيمة المدخلة للفاتورة');
      end if;
      alloc_desc(s.total_value, l_inv.total_value, l_open, s.bill_id1, s.bill_id2, h.doc_no, nvl(l_disc, 0), l_a, l_e);
      update ar_subtrns
         set inv_trns_id = l_inv.trns_id, inv_mainarea_id = l_inv.mainarea_id, inv_subarea_id = l_inv.subarea_id,
             inv_trns_serial = l_inv.trns_serial, inv_bill_seq = l_inv.bill_seq,
             store_code = nvl(store_code, l_inv.store_code),
             disc_value = nvl(l_disc, 0),
             net_value = total_value - nvl(l_disc, 0),
             dscnt_period = l_period, dscnt_source = l_source,
             inv_pay_date = greatest(nvl(l_inv_date, h.trns_date), h.trns_date),
             post_flag = nvl(post_flag, h.post_flag),
             without_comm_flag = nvl(without_comm_flag, 0),
             det_desc = nvl(det_desc, l_a),
             det_desc_e = nvl(det_desc_e, l_e)
       where rowid = s.rid;
      refresh_invoice(l_inv.trns_id, l_inv.mainarea_id, l_inv.subarea_id, l_inv.trns_serial, l_inv.bill_seq);
      if l_st then
        add_balance(h.customer_id, h.salesman_id, h.ctgry_code, -nvl(l_disc, 0));        -- CRN_BAL_TOTAL - discount
        -- PLUS_INV_NO_FLAG (ARCRTRN_ST PRE-INSERT)
        if nvl(t.plus_inv_no_flag, 0) = 1 then
          update ar_maintrns
             set description_a = description_a || ' ' || 'ف(' || s.bill_id2 || '/' || s.bill_id1 || ')',
                 description_e = description_e || ' ' || 'Bill(' || s.bill_id2 || '/' || s.bill_id1 || ')'
           where rowid = chartorowid(p_rowid);
        end if;
      end if;
    end loop;

    -- PAY_METHOD (legacy list PAY_METHOD_LIST)
    select count(*) into l_n
      from ar_subtrns
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
    if l_pm = 4 and l_n > 0 then
      -- KEY-COMMIT: "credit amount for the customer" keeps no allocation (DELETE_DETAIL_EFFECT + DELETE AR_SUBTRNS)
      remove_allocations(h, p_screen);
    elsif l_pm = 1 and l_n = 0 then
      -- EXPAND_FLAG: the payment is spread over the open invoices when its lines are still empty
      auto_allocate(h, p_screen, l_total, l_ratio, h.doc_no);
    end if;

    select nvl(sum(total_value), 0), nvl(sum(nvl(net_value, total_value - nvl(disc_value, 0))), 0), count(*)
      into l_tot, l_net, l_n
      from ar_subtrns
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
    -- AR_SUBTRNS PRE-INSERT: allocated invoices cannot exceed the payment
    if l_net > l_total then
      fail(-20142, 'قيمة الفواتير المسددة يجب أن تكون أقل من القيمة الكلية للسداد');
    end if;
    -- AR_MAINTRNS PRE-INSERT / PRE-UPDATE: 'يجب ادخال تفاصيل سداد' (method 2 without lines). The APEX document is
    -- created header-first, so the invoices of method 2 are picked after CREATE: the check applies to SAVE.
    if l_pm = 2 and l_n = 0 and not l_create then
      fail(-20158, lt('يجب ادخال تفاصيل سداد', 'You have to enter pay details'));
    end if;
    -- ARCRTRN KEY-COMMIT: methods 1 and 2 must allocate the whole payment (ROUND(TRNS_DIFF) = 0)
    if not l_st and l_pm in (1, 2) and (l_pm = 1 or not l_create) and round(l_total - l_net) <> 0 then
      fail(-20159, lt('إجمالي السداد لا يساوي إجمالي الحركة', 'Total payment not Equal Total Invoice')
                   || ' (' || fmt(l_net) || ' / ' || fmt(l_total) || ')');
    end if;

    l_doc  := h.doc_no;
    l_stot := h.trns_serial_total;
    if not l_st and l_doc is null then l_doc := next_doc_no(h.trns_id); end if;
    if l_stot is null then l_stot := next_serial_total; end if;
    update ar_maintrns
       set total_value       = l_total,
           residual_value    = l_total - l_net,                        -- PRE-INSERT RESIDUAL := TOTAL, each line - NET_VALUE
           net_value         = case when l_n > 0 then l_net else l_total end,
           disc_value        = l_tot - l_net,
           disc_val_ratio    = l_ratio,
           doc_no            = l_doc,
           trns_serial_total = l_stot,
           link_flag         = case when l_stn = 1 then nvl(link_flag, 1) else link_flag end,
           pay_method        = l_pm,
           cash_flag         = nvl(cash_flag, 2),                       -- WHEN-CREATE-RECORD: CASH_FLAG := 2
           post_flag         = nvl(post_flag, 0),
           pay_flag          = nvl(pay_flag, 0),
           currency_code     = nvl(currency_code, c.currency_code),
           currency_rate     = nvl(currency_rate, 1)
     where rowid = chartorowid(p_rowid);
    refresh_salesman_links(p_rowid, h);

    -- ARCRTRN_ST POST-INSERT of AR_MAINTRNS: CUSTOMER / AR_CUST_SALESMAN.CRN_BAL_TOTAL - TOTAL_VALUE
    if l_st and l_create then
      add_balance(h.customer_id, h.salesman_id, h.ctgry_code, -l_total);
    end if;

    if not l_create and not l_st then
      select * into h from ar_maintrns where rowid = chartorowid(p_rowid);
      check_account_det(h, t, nvl(h.inv_value, h.total_value));     -- PRE-COMMIT: TRNS_SUM_VALUE = INV_VALUE * CURRENCY_RATE
    end if;
  end after_save_credit;

  -- ===================================================================================== info panel
  function dc_text (p_amount in number) return varchar2 is
  begin
    if p_amount is null or p_amount = 0 then
      return fmt(nvl(p_amount, 0));
    end if;
    return fmt(abs(p_amount)) || ' ' || case when p_amount > 0 then lt('مدين', 'Debit') else lt('دائن', 'Credit') end;
  end dc_text;

  function cust_balance (p_customer_id in number) return varchar2 is
  begin
    if p_customer_id is null then
      return null;
    end if;
    return dc_text(get_customer_bal(p_customer_id, sysdate));        -- LKP_MASTER: GET_CUSTOMER_BAL(:CUSTOMER_ID, SYSDATE)
  end cust_balance;

  function alloc_info (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    h     ar_maintrns%rowtype := header_row(p_rowid);
    l_tot number;
    l_dsc number;
    l_net number;
    l_tax number;
    l_acc number;
  begin
    if h.trns_id is null then
      return null;
    end if;
    select nvl(sum(total_value), 0), nvl(sum(nvl(disc_value, 0)), 0), nvl(sum(nvl(net_value, total_value - nvl(disc_value, 0))), 0),
           nvl(sum(tax_value1), 0)
      into l_tot, l_dsc, l_net, l_tax
      from ar_subtrns
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
    select nvl(sum(value), 0) into l_acc
      from ar_maintrns_account_det
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
    return case upper(p_what)
      when 'TOTAL'      then fmt(l_tot)                                             -- TRNS_TOTAL
      when 'DISC'       then fmt(l_dsc)                                             -- TRNS_DISC
      when 'NET'        then fmt(l_net)                                             -- TRNS_NET
      when 'DIFF'       then fmt(nvl(h.total_value, 0) - l_net)                     -- TRNS_DIFF
      when 'TOTAL_DIFF' then fmt((nvl(h.total_value, 0) - l_net) + (nvl(h.disc_val, 0) - l_dsc))   -- TRNS_TOTAL_DIFF
      when 'ACCOUNTS'   then fmt(l_acc)                                             -- TRNS_SUM_VALUE
      when 'SUBTAX'     then fmt(l_tax)                                             -- TOT_SUBTAX
      when 'LOCAL'      then fmt(nvl(h.currency_rate, 0) * nvl(h.total_value, 0))   -- TOTAL_VALUE_RIYALH
      when 'RES_LOCAL'  then fmt(nvl(h.currency_rate, 0) * nvl(h.residual_value, 0))   -- RESIDUAL_VALUE_RIAL
      end;
  end alloc_info;

  function book_range (p_salesman_id in number, p_book_serial in number) return varchar2 is
    l_from number;
    l_to   number;
  begin
    select from_serial, to_serial into l_from, l_to
      from ar_salesman_books where salesman_code = p_salesman_id and book_serial = p_book_serial;
    return l_from || ' - ' || l_to;
  exception when no_data_found then
    return null;
  end book_range;

  function system_name (p_post_system in number) return varchar2 is
    l_a varchar2(400);
    l_e varchar2(400);
  begin
    select system_desc_a, system_desc_e into l_a, l_e from sys_systems where system_number = p_post_system;
    return lt(l_a, l_e);
  exception when no_data_found then
    return null;
  end system_name;

  function user_name (p_user in number) return varchar2 is
    l_a varchar2(400);
    l_e varchar2(400);
  begin
    select users_name, users_name_e into l_a, l_e from users where users_code = p_user;
    return p_user || ' - ' || lt(l_a, l_e);
  exception when no_data_found then
    return p_user;
  end user_name;

  -- ===================================================================================== delete hooks
  function hook_active return boolean is
    l_form varchar2(128);
  begin
    if g_in_hook or v('APP_ID') is null and not g_form_set then
      return false;
    end if;
    l_form := cur_form;
    return l_form in ('ARCRTRN', 'ARCRTRN_ST', 'ARDBTRN', 'ARDBTRN_ST');
  end hook_active;

  procedure sub_before_statement is
    h ar_maintrns%rowtype;
  begin
    if g_in_hook then
      return;
    end if;
    g_del.delete;                        -- rows of an earlier statement that failed
    -- ARCRTRN_ST KEY-DELREC: INSERT_AR_OLD_TRNS copies the payment with all its lines before they are deleted (the page
    -- deletes the lines of the document first, then the header; the document is the page's P<page>_ROWID)
    if hook_active and cur_form = 'ARCRTRN_ST' and request = 'DELETE' then
      h := header_row(v('P' || v('APP_PAGE_ID') || '_ROWID'));
      if h.trns_id is not null and trnstype(h.trns_id).effect = 1
         and nvl(h.post_flag, 0) = 0 and nvl(h.pay_flag, 0) = 0 then
        copy_history(h);
      end if;
    end if;
  end sub_before_statement;

  procedure sub_before_delete (p_trns_id number, p_mainarea_id number, p_subarea_id number, p_trns_serial number,
                               p_bill_seq number, p_bill_id1 number, p_bill_id2 number, p_store_code number,
                               p_total_value number, p_disc_value number, p_inv_trns_id number, p_inv_mainarea_id number,
                               p_inv_subarea_id number, p_inv_trns_serial number, p_inv_bill_seq number)
  is
    h   ar_maintrns%rowtype;
    r   t_sub;
    l_i pls_integer;
  begin
    if not hook_active then
      return;
    end if;
    begin
      select * into h from ar_maintrns
       where trns_id = p_trns_id and mainarea_id = p_mainarea_id and subarea_id = p_subarea_id and trns_serial = p_trns_serial;
    exception when no_data_found then
      return;
    end;
    r.effect := trnstype(h.trns_id).effect;
    r.form := cur_form;
    -- AR_SUBTRNS PRE-DELETE (ARCRTRN, ARCRTRN_ST): 'الحركة الحالية مرحلة و لا يمكن حذفها'; CLOSE_MAIN_POSTED / CLOSE_POSTED:
    -- no line of a posted or paid transaction can be deleted
    if nvl(h.post_flag, 0) = 1 then
      fail(-20160, lt('الحركة الحالية مرحلة و لا يمكن حذفها', 'You can''t delete current transaction due to posting'));
    elsif nvl(h.pay_flag, 0) = 1 then
      fail(-20161, lt('الحركة مسددة ولا يمكن حذفها', 'The transaction is paid and cannot be deleted'));
    end if;
    r.trns_id := p_trns_id; r.mainarea_id := p_mainarea_id; r.subarea_id := p_subarea_id; r.trns_serial := p_trns_serial;
    r.bill_seq := p_bill_seq; r.bill_id1 := p_bill_id1; r.bill_id2 := p_bill_id2; r.store_code := p_store_code;
    r.total_value := p_total_value; r.disc_value := p_disc_value; r.inv_trns_id := p_inv_trns_id;
    r.inv_mainarea_id := p_inv_mainarea_id; r.inv_subarea_id := p_inv_subarea_id; r.inv_trns_serial := p_inv_trns_serial;
    r.inv_bill_seq := p_inv_bill_seq;
    l_i := g_del.count + 1;
    g_del(l_i) := r;
  end sub_before_delete;

  procedure sub_after_delete is
    l_rows t_sub_tab;
    h      ar_maintrns%rowtype;
    l_n    number;
  begin
    if g_in_hook or g_del.count = 0 then
      return;
    end if;
    l_rows := g_del;
    g_del.delete;
    g_in_hook := true;
    for i in 1 .. l_rows.count loop
      begin
        select * into h from ar_maintrns
         where trns_id = l_rows(i).trns_id and mainarea_id = l_rows(i).mainarea_id and subarea_id = l_rows(i).subarea_id
           and trns_serial = l_rows(i).trns_serial;
      exception when no_data_found then
        h := null;
      end;
      if l_rows(i).effect = 1 then
        -- a payment line: DELETE_DETAIL_EFFECT gives the value back to the invoice bill
        if l_rows(i).inv_trns_id is not null then
          refresh_invoice(l_rows(i).inv_trns_id, l_rows(i).inv_mainarea_id, l_rows(i).inv_subarea_id,
                          l_rows(i).inv_trns_serial, l_rows(i).inv_bill_seq);
        end if;
        if l_rows(i).form = 'ARCRTRN_ST' and h.trns_id is not null then
          add_balance(h.customer_id, h.salesman_id, h.ctgry_code, nvl(l_rows(i).disc_value, 0));   -- CRN_BAL_TOTAL + discount
          copy_history(h);                  -- AR_SUBTRNS POST-DELETE: INSERT_AR_OLD_TRNS (once per payment)
        end if;
      elsif l_rows(i).effect = 0 then
        -- an invoice line: DELETE_PAY_ENTRIES removes the payment lines of the invoice (same bill numbers and store)
        if l_rows(i).form = 'ARDBTRN_ST' and h.trns_id is not null then
          add_balance(h.customer_id, null, null, -nvl(l_rows(i).total_value, 0), false);          -- CRN_BAL_TOTAL - invoice
        end if;
        for p in (select s.trns_id, s.mainarea_id, s.subarea_id, s.trns_serial, s.bill_seq, s.total_value,
                         nvl(s.disc_value, 0) disc_value, nvl(m.post_flag, 0) post_flag
                    from ar_subtrns s, ar_maintrns m
                   where s.trns_id in (select id from ar_trnstype where effect = 1)
                     and s.bill_id1 = l_rows(i).bill_id1 and s.bill_id2 = l_rows(i).bill_id2
                     and s.store_code = l_rows(i).store_code
                     and m.trns_id = s.trns_id and m.mainarea_id = s.mainarea_id and m.subarea_id = s.subarea_id
                     and m.trns_serial = s.trns_serial)
        loop
          if l_rows(i).form = 'ARDBTRN' then
            if p.post_flag = 1 then
              fail(-20162, 'لا يمكن حذف الحركة رقم ' || p.trns_id || '/' || p.trns_serial
                           || '     لكونها مرحلة الى الحسابات يجب إلغاء الترحيل أولا ');
            end if;
            update ar_maintrns
               set residual_value = residual_value + (p.total_value - p.disc_value),
                   disc_value = disc_value - p.disc_value,
                   net_value = net_value - (p.total_value - p.disc_value)
             where trns_id = p.trns_id and mainarea_id = p.mainarea_id and subarea_id = p.subarea_id and trns_serial = p.trns_serial;
          else
            update ar_maintrns
               set residual_value = residual_value + p.total_value
             where trns_id = p.trns_id and mainarea_id = p.mainarea_id and subarea_id = p.subarea_id and trns_serial = p.trns_serial;
          end if;
          delete from ar_subtrns
           where trns_id = p.trns_id and mainarea_id = p.mainarea_id and subarea_id = p.subarea_id
             and trns_serial = p.trns_serial and bill_seq = p.bill_seq;
        end loop;
      end if;
    end loop;
    g_in_hook := false;
  exception when others then
    g_in_hook := false;
    g_del.delete;
    raise;
  end sub_after_delete;

  procedure mast_before_delete (p_trns_id number, p_mainarea_id number, p_subarea_id number, p_trns_serial number,
                                p_customer_id number, p_salesman_id number, p_ctgry_code number, p_total_value number,
                                p_post_flag number, p_pay_flag number)
  is
    l_form varchar2(128);
    l_eff  number;
  begin
    if not hook_active or request <> 'DELETE' then
      return;
    end if;
    l_form := cur_form;
    -- CLOSE_MAIN_POSTED / CLOSE_POSTED: a posted or paid transaction cannot be deleted
    if nvl(p_post_flag, 0) = 1 then
      fail(-20160, lt('الحركة الحالية مرحلة و لا يمكن حذفها', 'You can''t delete current transaction due to posting'));
    elsif nvl(p_pay_flag, 0) = 1 then
      fail(-20161, lt('الحركة مسددة ولا يمكن حذفها', 'The transaction is paid and cannot be deleted'));
    end if;
    l_eff := trnstype(p_trns_id).effect;
    -- ARCRTRN_ST KEY-DELREC: CRN_BAL_TOTAL + TOTAL (the history copy was made before the lines were deleted)
    if l_form = 'ARCRTRN_ST' and l_eff = 1 then
      add_balance(p_customer_id, p_salesman_id, p_ctgry_code, nvl(p_total_value, 0));
    end if;
  end mast_before_delete;

end app_rules_ar;
/
show errors package body app_rules_ar

-- ---------------------------------------------------------------------------------------------------
-- Delete hooks (the Stage C rules mechanism has row rules for INSERT / UPDATE only). APEX pages of ARCRTRN, ARCRTRN_ST,
-- ARDBTRN, ARDBTRN_ST only (app_rules_ar.cur_form). AR_SUBTRNS rows are collected per row and processed after the
-- statement, because the effects update other AR_SUBTRNS rows (invoice residuals, payment lines of a deleted invoice).
-- ---------------------------------------------------------------------------------------------------
create or replace trigger app_rules_ar_sub_bd
for delete on ar_subtrns
compound trigger
  before statement is
  begin
    if v('APP_ID') is not null then
      app_rules_ar.sub_before_statement;
    end if;
  end before statement;
  before each row is
  begin
    if v('APP_ID') is not null then
      app_rules_ar.sub_before_delete(:old.trns_id, :old.mainarea_id, :old.subarea_id, :old.trns_serial, :old.bill_seq,
                                     :old.bill_id1, :old.bill_id2, :old.store_code, :old.total_value, :old.disc_value,
                                     :old.inv_trns_id, :old.inv_mainarea_id, :old.inv_subarea_id, :old.inv_trns_serial,
                                     :old.inv_bill_seq);
    end if;
  end before each row;
  after statement is
  begin
    if v('APP_ID') is not null then
      app_rules_ar.sub_after_delete;
    end if;
  end after statement;
end app_rules_ar_sub_bd;
/
show errors trigger app_rules_ar_sub_bd

create or replace trigger app_rules_ar_mast_bd
before delete on ar_maintrns for each row
begin
  if v('APP_ID') is not null then
    app_rules_ar.mast_before_delete(:old.trns_id, :old.mainarea_id, :old.subarea_id, :old.trns_serial, :old.customer_id,
                                    :old.salesman_id, :old.ctgry_code, :old.total_value, :old.post_flag, :old.pay_flag);
  end if;
end;
/
show errors trigger app_rules_ar_mast_bd
