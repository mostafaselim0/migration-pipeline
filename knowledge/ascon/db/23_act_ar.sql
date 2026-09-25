-- =====================================================================================================
-- APP_ACT_AR : document buttons (action regions) of the AR and GL entry screens (Stage C wave 3).
--   ARCRTRN / ARCRTRN_ST  ALLOC_INVOICE  BILL_LOV picker of the allocation lines (PAY_METHOD 2 "invoice help screen")
--   ARCRTRN               TOGGLE_COMM    button ACTIVE of AR_SUBTRNS (WITHOUT_COMM_FLAG 0 <-> 1)
--   ARCRTRN / ARDBTRN     POST           button POST       -> ARACUPDT with POST_ON_LINE = 1 (app_proc_ar.post_to_gl)
--                         CANCEL_POST    button CANCEL_POST -> AR_CPOSTING with POST_ON_LINE = 1 (app_proc_ar.cancel_gl_posting)
--   ACDLYTR               TAX_IN         button TAX_IN of AC_DAILY_TRN_DET (tax lines from TX_TAXES_ACCOUNTS)
--                         TAX_NOTES      button TAX_NOTES of AC_DAILY_TRN_DET (CUST_INV_VAL of a VAT line)
--                         POST_VOUCHER   button POST_VOUCHER (app_proc_gl.post_voucher)
-- Evidence: app\legacy\processes\{ARCRTRN,ARCRTRN_ST,ARDBTRN,ACDLYTR}.md. Wired by the "actions" of the overrides.
-- Contract (STAGE_C_ACTIONS_ADDENDUM.md): each call returns the ROWID to open (null = stay), raises -201xx to refuse,
-- never commits; can_* return 'Y' / 'N' for the action conditions; last_message is the success text.
-- =====================================================================================================
set define off

create or replace package app_act_ar authid definer as

  function last_message return varchar2;

  -- open value of an invoice bill as the legacy BILL_LOV showed it (ARCRTRN: TOTAL - AR_SUBTRNS_PAYED_VALUE,
  -- ARCRTRN_ST: stored RESIDUAL_VALUE) and "bill already allocated in this payment" (1 / 0) - used by the LOVs
  function bill_open (p_screen in varchar2, p_trns_id in number, p_mainarea_id in number, p_subarea_id in number,
                      p_trns_serial in number, p_bill_seq in number) return number;
  function in_payment (p_rowid in varchar2, p_bill_id1 in number, p_bill_id2 in number) return number;

  -- ALLOC_INVOICE
  function can_alloc (p_rowid in varchar2) return varchar2;
  function alloc_invoice (p_rowid in varchar2, p_invoice in varchar2, p_amount in number default null,
                          p_disc in number default null, p_screen in varchar2 default 'ARCRTRN') return varchar2;

  -- TOGGLE_COMM (ACTIVE)
  function can_toggle_comm (p_rowid in varchar2) return varchar2;
  function toggle_comm (p_rowid in varchar2, p_bill_seq in number) return varchar2;

  -- POST / CANCEL_POST
  function can_post (p_rowid in varchar2) return varchar2;
  function post_trns (p_rowid in varchar2) return varchar2;
  function can_cancel_post (p_rowid in varchar2) return varchar2;
  function cancel_post_trns (p_rowid in varchar2, p_allow_grouped in number default 0) return varchar2;

  -- ACDLYTR
  function can_tax_line (p_rowid in varchar2) return varchar2;
  function tax_in (p_rowid in varchar2, p_seq in number) return varchar2;
  function tax_notes (p_rowid in varchar2, p_seq in number) return varchar2;
  function can_post_voucher (p_rowid in varchar2) return varchar2;
  function post_voucher (p_rowid in varchar2) return varchar2;

end app_act_ar;
/

create or replace package body app_act_ar as

  g_msg varchar2(4000);

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

  procedure fail (p_code in pls_integer, p_a in varchar2, p_e in varchar2) is
  begin
    raise_application_error(p_code, substr(lt(p_a, p_e), 1, 2000));
  end fail;

  function last_message return varchar2 is
  begin
    return g_msg;
  end last_message;

  function company return number is
    l number := num(v('G_COMPANY_CODE'));
  begin
    if l is null then
      select min(company_code) into l from ac_basic;
    end if;
    return l;
  end company;

  function usr return number is
  begin
    return num(v('G_USER_CODE'));
  end usr;

  function grp return number is
  begin
    return nvl(num(v('G_PASSWORD_NUMBER')), 0);
  end grp;

  function ar_row (p_rowid in varchar2) return ar_maintrns%rowtype is
    h ar_maintrns%rowtype;
  begin
    if p_rowid is not null then
      select * into h from ar_maintrns where rowid = chartorowid(p_rowid);
    end if;
    return h;
  exception when no_data_found or value_error then
    return h;
  end ar_row;

  function gl_row (p_rowid in varchar2) return ac_daily_trn%rowtype is
    h ac_daily_trn%rowtype;
  begin
    if p_rowid is not null then
      select * into h from ac_daily_trn where rowid = chartorowid(p_rowid);
    end if;
    return h;
  exception when no_data_found or value_error then
    return h;
  end gl_row;

  function effect (p_trns_id in number) return number is
    l number;
  begin
    select effect into l from ar_trnstype where id = p_trns_id;
    return l;
  exception when no_data_found then
    return null;
  end effect;

  -- ===================================================================================== ALLOC_INVOICE
  function bill_open (p_screen in varchar2, p_trns_id in number, p_mainarea_id in number, p_subarea_id in number,
                      p_trns_serial in number, p_bill_seq in number) return number is
    l_total number;
    l_res   number;
  begin
    select total_value, residual_value into l_total, l_res
      from ar_subtrns
     where trns_id = p_trns_id and mainarea_id = p_mainarea_id and subarea_id = p_subarea_id
       and trns_serial = p_trns_serial and bill_seq = p_bill_seq;
    if upper(p_screen) = 'ARCRTRN_ST' then
      return nvl(l_res, 0);
    end if;
    return l_total - ar_subtrns_payed_value(p_trns_id, p_trns_serial, p_mainarea_id, p_subarea_id, p_bill_seq);
  exception when no_data_found then
    return null;
  end bill_open;

  function in_payment (p_rowid in varchar2, p_bill_id1 in number, p_bill_id2 in number) return number is
    h   ar_maintrns%rowtype := ar_row(p_rowid);
    l_n number;
  begin
    select count(*) into l_n
      from ar_subtrns
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial
       and bill_id1 = p_bill_id1 and bill_id2 = p_bill_id2;
    return case when l_n > 0 then 1 else 0 end;
  end in_payment;

  function can_alloc (p_rowid in varchar2) return varchar2 is
    h ar_maintrns%rowtype := ar_row(p_rowid);
  begin
    -- PAY_METHOD_LIST: AR_SUBTRNS insert allowed for methods 1 / 2; CLOSE_MAIN_POSTED: not on a posted transaction
    if h.trns_id is null or effect(h.trns_id) <> 1 or nvl(h.post_flag, 0) = 1 or nvl(h.pay_flag, 0) = 1
       or nvl(h.pay_method, 2) = 4 then
      return 'N';
    end if;
    return case when nvl(app_rules_ar.payment_open(p_rowid), 0) > 0 then 'Y' else 'N' end;
  end can_alloc;

  function alloc_invoice (p_rowid in varchar2, p_invoice in varchar2, p_amount in number default null,
                          p_disc in number default null, p_screen in varchar2 default 'ARCRTRN') return varchar2 is
    h ar_maintrns%rowtype := ar_row(p_rowid);
  begin
    g_msg := null;
    if h.trns_id is null then
      fail(-20170, 'لابد من حفظ السجل أولاً', 'THE DATA MUST BE SAVED FIRST');
    end if;
    if nvl(h.post_flag, 0) = 1 or nvl(h.pay_flag, 0) = 1 then
      fail(-20171, 'لا يجوز الإضافة علي الحركة الحالية لكونها مرحلة', 'Current Trans. Cannot Be Updated , It Is Posted.');
    end if;
    if p_invoice is null then
      fail(-20172, 'اختر الفاتورة', 'Choose the invoice');
    end if;
    app_rules_ar.add_allocation(p_rowid, p_invoice, p_amount, p_disc, p_screen);
    g_msg := lt('تم تسكين الفاتورة على السند - المتبقى من السند ', 'The invoice was allocated - open value of the payment ')
             || to_char(app_rules_ar.payment_open(p_rowid), 'FM999,999,999,990.00');
    return p_rowid;
  end alloc_invoice;

  -- ===================================================================================== TOGGLE_COMM
  function can_toggle_comm (p_rowid in varchar2) return varchar2 is
    h   ar_maintrns%rowtype := ar_row(p_rowid);
    l_n number;
  begin
    if h.trns_id is null then
      return 'N';
    end if;
    select count(*) into l_n
      from ar_subtrns
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial;
    return case when l_n > 0 then 'Y' else 'N' end;
  end can_toggle_comm;

  function toggle_comm (p_rowid in varchar2, p_bill_seq in number) return varchar2 is
    h     ar_maintrns%rowtype := ar_row(p_rowid);
    l_new number;
  begin
    g_msg := null;
    -- ACTIVE: the flag changes even when the lines are not updatable (posted transaction)
    update ar_subtrns
       set without_comm_flag = case when nvl(without_comm_flag, 0) = 0 then 1 else 0 end
     where trns_id = h.trns_id and mainarea_id = h.mainarea_id and subarea_id = h.subarea_id and trns_serial = h.trns_serial
       and bill_seq = p_bill_seq
    returning without_comm_flag into l_new;
    if sql%rowcount = 0 then
      fail(-20173, 'اختر سطر الفاتورة', 'Choose the invoice line');
    end if;
    g_msg := case when l_new = 1 then lt('السطر بدون عمولة', 'Line without commission')
                  else lt('السطر بعمولة', 'Line with commission') end;
    return p_rowid;
  end toggle_comm;

  -- ===================================================================================== POST / CANCEL_POST
  function can_post (p_rowid in varchar2) return varchar2 is
    h ar_maintrns%rowtype := ar_row(p_rowid);
  begin
    -- SET_PAY_METHOD: POST visible when POST_FLAG <> 1
    return case when h.trns_id is not null and nvl(h.post_flag, 0) <> 1 then 'Y' else 'N' end;
  end can_post;

  function post_trns (p_rowid in varchar2) return varchar2 is
    h      ar_maintrns%rowtype := ar_row(p_rowid);
    l_date date;
  begin
    g_msg := null;
    if h.trns_id is null then
      fail(-20170, 'لابد من حفظ السجل أولاً', 'THE DATA MUST BE SAVED BEFORE RUN THR Authorize');
    end if;
    if nvl(h.post_flag, 0) = 1 then
      fail(-20174, 'لابد من إلغاء الترحيل اولا', 'THE POSTED MUST BE DELETED BEFORE RUN THR Authorize');
    end if;
    -- ARACUPDT with POST_ON_LINE = 1 for this transaction (ARCRTRN passes ACC_POST_DATE, ARDBTRN TRNS_DATE; the posting
    -- cursor selects on NVL(ACC_POST_DATE, TRNS_DATE))
    l_date := trunc(nvl(h.acc_post_date, h.trns_date));
    app_proc_ar.post_to_gl(p_from_date => l_date, p_to_date => l_date,
                           p_from_trns_id => h.trns_id, p_to_trns_id => h.trns_id,
                           p_from_mainarea => h.mainarea_id, p_to_mainarea => h.mainarea_id,
                           p_from_subarea => h.subarea_id, p_to_subarea => h.subarea_id,
                           p_from_serial => h.trns_serial, p_to_serial => h.trns_serial,
                           p_company_code => company, p_user_code => usr, p_password_number => grp);
    if app_proc_ar.last_count = 0 then
      fail(-20175, 'لا يوجد حركات يمكن ترحيلها', 'No Transactions Exist for Posting');
    end if;
    g_msg := lt('تم ترحيل الحركة للحسابات', 'The transaction was posted to the GL') || ' (' || h.trns_id || '/' || h.trns_serial || ')';
    return p_rowid;
  end post_trns;

  function can_cancel_post (p_rowid in varchar2) return varchar2 is
    h       ar_maintrns%rowtype := ar_row(p_rowid);
    l_sys   number;
  begin
    -- SET_PAY_METHOD: CANCEL_POST visible when posted and (CASH_FLAG = 2 or no cash-box / cheque system 13 / 15)
    if h.trns_id is null or nvl(h.post_flag, 0) <> 1 then
      return 'N';
    end if;
    select count(*) into l_sys from sys_systems where system_number in (13, 15);
    return case when nvl(h.cash_flag, 0) = 2 or l_sys = 0 then 'Y' else 'N' end;
  end can_cancel_post;

  function cancel_post_trns (p_rowid in varchar2, p_allow_grouped in number default 0) return varchar2 is
    h      ar_maintrns%rowtype := ar_row(p_rowid);
    l_date date;
  begin
    g_msg := null;
    if h.trns_id is null or nvl(h.post_flag, 0) = 0 then
      fail(-20176, 'هذه الحركة غير مرحلة', 'This Transaction Not Posted');
    end if;
    l_date := trunc(nvl(h.acc_post_date, h.trns_date));
    app_proc_ar.cancel_gl_posting(p_from_date => l_date, p_to_date => l_date,
                                  p_from_trns_id => h.trns_id, p_to_trns_id => h.trns_id,
                                  p_from_mainarea => h.mainarea_id, p_to_mainarea => h.mainarea_id,
                                  p_from_subarea => h.subarea_id, p_to_subarea => h.subarea_id,
                                  p_from_serial => h.trns_serial, p_to_serial => h.trns_serial,
                                  p_allow_grouped => nvl(p_allow_grouped, 0),
                                  p_company_code => company, p_user_code => usr, p_password_number => grp);
    g_msg := lt('تم إلغاء ترحيل الحركة', 'The GL posting of the transaction was cancelled') || ' (' || h.trns_id || '/' || h.trns_serial || ')';
    return p_rowid;
  end cancel_post_trns;

  -- ===================================================================================== ACDLYTR
  function can_tax_line (p_rowid in varchar2) return varchar2 is
    h   ac_daily_trn%rowtype := gl_row(p_rowid);
    l_n number;
  begin
    if h.entry_no is null then
      return 'N';
    end if;
    select count(*) into l_n
      from ac_daily_trn_det where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no;
    return case when l_n > 0 then 'Y' else 'N' end;
  end can_tax_line;

  function gl_line (h in ac_daily_trn%rowtype, p_seq in number) return ac_daily_trn_det%rowtype is
    d ac_daily_trn_det%rowtype;
  begin
    select * into d from ac_daily_trn_det
     where entry_year = h.entry_year and entry_type = h.entry_type and entry_no = h.entry_no and seq = p_seq;
    return d;
  exception when no_data_found then
    fail(-20177, 'اختر سطر القيد', 'Choose the entry line');
    return d;
  end gl_line;

  procedure gl_rights (p_rowid in varchar2) is
    l_err varchar2(4000);
  begin
    -- the lines of an entry created by another user are not updatable without ALLOW_UPDATE_ENTRIES (WHEN-NEW-RECORD-INSTANCE)
    l_err := app_rules_gl.check_user_rights(p_rowid);
    if l_err is not null then
      raise_application_error(-20178, l_err);
    end if;
  end gl_rights;

  function tax_in (p_rowid in varchar2, p_seq in number) return varchar2 is
    h         ac_daily_trn%rowtype := gl_row(p_rowid);
    d         ac_daily_trn_det%rowtype;
    l_n       number := 0;
    l_acct    number;
    l_db      number;
    l_cr      number;
    l_seq     number;
    l_desc    ac_daily_trn_det.entry_desc%type;
    l_desc_e  ac_daily_trn_det.entry_desc_e%type;
    l_memo    ac_daily_trn_det.memo%type;
    l_memo_e  ac_daily_trn_det.memo_e%type;
    l_cc1     number;
    l_cc2     number;
    l_inv_val number;
    l_debit   number;
    l_credit  number;
    l_comp    number := company;
    l_grp     number := grp;
    l_usr     number := usr;
  begin
    g_msg := null;
    if h.entry_no is null then
      fail(-20170, 'يجب الحفظ أولا', 'Save First');
    end if;
    gl_rights(p_rowid);
    d := gl_line(h, p_seq);
    -- POST-QUERY: DEBIT_VALUE := VALUE when VALUE > 0, else CREDIT_VALUE := -VALUE
    if d.value > 0 then l_debit := d.value; else l_credit := -d.value; end if;
    for rec in (select tc.account_number, tt.name_a, tt.name_e, tc.cost_code, tc.cost_code2, tc.tax_code, tc.tax_per,
                       tt.db_account_no, tt.cr_account_no
                  from tx_taxes_accounts tc, tx_taxes_types tt
                 where tc.tax_code = tt.tax_code
                   and tc.account_number = d.account_number
                   and (nvl(tc.cost_code, 0) = nvl(d.cost_code, 0) or nvl(tc.cost_code, 0) = 0)
                   and (nvl(tc.cost_code2, 0) = nvl(d.cost_code2, 0) or nvl(tc.cost_code2, 0) = 0))
    loop
      l_n := l_n + 1;
      if nvl(d.t_tax_flag1, 0) between 1 and 5 then
        l_acct := rec.cr_account_no;
      elsif nvl(d.t_tax_flag1, 0) between 6 and 10 then
        l_acct := rec.db_account_no;
      end if;
      if nvl(l_debit, 0) > 0 then
        l_acct := rec.db_account_no;
        l_db := (nvl(l_debit, 0) * nvl(rec.tax_per, 0)) / 100;
      elsif nvl(l_credit, 0) > 0 then
        l_acct := rec.cr_account_no;
        l_cr := (nvl(l_credit, 0) * nvl(rec.tax_per, 0)) / 100;
      end if;
      l_inv_val := abs(nvl(l_debit, l_credit));
      -- CREATE_RECORD with the tax account, its names, the tax value on the same side, the cost centres of the tax row,
      -- TAX_ACCOUNT = the taxed account, TAX_FLAG 1, CUST_INV_VAL = taxed value, T_TAX_FLAG1 0; MEMO empty -> the account's
      -- WHEN-VALIDATE-ITEM puts the header description; PRE-INSERT: CUST_INV_VAL 0 without VAT customer data
      l_cc1 := rec.cost_code; l_cc2 := rec.cost_code2; l_desc := null; l_desc_e := null; l_memo := null; l_memo_e := null;
      l_seq := app_rules_gl.next_line_seq(h.entry_year, h.entry_type, h.entry_no);
      app_rules_gl.line_defaults(true, null, h.entry_year, h.entry_type, h.entry_no, l_acct, l_cc1, l_cc2,
                                 l_desc, l_desc_e, l_memo, l_memo_e, null, null, null, l_inv_val);
      insert into ac_daily_trn_det
        (entry_year, entry_type, entry_no, seq, account_number, entry_desc, entry_desc_e, value, cost_code, cost_code2,
         memo, memo_e, tax_flag, tax_account, cust_inv_val, t_tax_flag1, create_company_code, create_password_number,
         create_user_code, create_date)
      values
        (h.entry_year, h.entry_type, h.entry_no, l_seq, l_acct, l_desc, l_desc_e,
         case when nvl(l_debit, 0) > 0 then round(l_db, 2) else -round(l_cr, 2) end, l_cc1, l_cc2,
         l_memo, l_memo_e, 1, rec.account_number, l_inv_val, 0, l_comp, l_grp, l_usr, sysdate);
    end loop;
    if l_n = 0 then
      g_msg := lt('لا يوجد ضريبة مدرجة على هذا الحساب بمركز تكلفة 1 و مركز تكلفة 2 ان وجد',
                  'No tax installed for this account , cost center1 and cost centers');
    else
      g_msg := lt('تم إضافة سطر الضريبة', 'The tax line was added') || ' (' || l_n || ')';
    end if;
    return p_rowid;
  end tax_in;

  function tax_notes (p_rowid in varchar2, p_seq in number) return varchar2 is
    h     ac_daily_trn%rowtype := gl_row(p_rowid);
    d     ac_daily_trn_det%rowtype;
    l_val number;
  begin
    g_msg := null;
    if h.entry_no is null then
      fail(-20170, 'يجب الحفظ أولا', 'Save First');
    end if;
    gl_rights(p_rowid);
    d := gl_line(h, p_seq);
    if nvl(d.account_number, 0) = 0 then
      fail(-20179, 'لابد من ادخال حساب اولا', 'ERROR');
    end if;
    l_val := abs(d.value);
    if nvl(d.tax_flag, 0) = 1 then
      -- CUST_TAX_VAL := the line value (display only)
      g_msg := lt('قيمة الضريبة', 'Tax value') || ' = ' || to_char(l_val, 'FM999,999,999,990.00');
    else
      -- CUST_INV_VAL := value / 1.05 (legacy constant), CUST_TAX_VAL := value - CUST_INV_VAL
      if nvl(d.cust_inv_val, 0) <> l_val / 1.05 then
        update ac_daily_trn_det
           set cust_inv_val = l_val / 1.05
         where entry_year = d.entry_year and entry_type = d.entry_type and entry_no = d.entry_no and seq = d.seq;
      end if;
      select cust_inv_val into d.cust_inv_val
        from ac_daily_trn_det
       where entry_year = d.entry_year and entry_type = d.entry_type and entry_no = d.entry_no and seq = d.seq;
      g_msg := lt('قيمة الفاتورة', 'Invoice value') || ' = ' || to_char(d.cust_inv_val, 'FM999,999,999,990.00') || ' - '
               || lt('قيمة الضريبة', 'Tax value') || ' = ' || to_char(l_val - d.cust_inv_val, 'FM999,999,999,990.00');
    end if;
    return p_rowid;
  end tax_notes;

  function can_post_voucher (p_rowid in varchar2) return varchar2 is
    h ac_daily_trn%rowtype := gl_row(p_rowid);
  begin
    if h.entry_no is null then
      return 'N';
    end if;
    return case when app_proc_gl.voucher_post_allowed(company, usr, grp) = 1 then 'Y' else 'N' end;
  end can_post_voucher;

  function post_voucher (p_rowid in varchar2) return varchar2 is
    h ac_daily_trn%rowtype := gl_row(p_rowid);
  begin
    g_msg := null;
    if h.entry_no is null then
      fail(-20170, 'يجب الحفظ أولا قبل الترحيل', 'Save First Before Posting');
    end if;
    app_proc_gl.post_voucher(h.entry_year, h.entry_type, h.entry_no, company, usr, grp);
    g_msg := app_proc_gl.last_message;
    -- legacy CLEAR_RECORD: the posted entry left the daily tables, the page opens an empty entry
    if v('APP_ID') is not null and v('APP_PAGE_ID') is not null then
      apex_util.set_session_state('P' || v('APP_PAGE_ID') || '_ROWID', null);
    end if;
    return null;
  end post_voucher;

end app_act_ar;
/
show errors package body app_act_ar
