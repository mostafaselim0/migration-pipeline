-- =====================================================================================================
-- APP_ACT_PR : legacy buttons, warnings, displays and delete rules of the purchasing and payables screens (Stage C, wave 3,
--              app\legacy\STAGE_C_WAVE3.md): what the data-entry rules of wave 2 (APP_RULES_PR / APP_RULES_VN) and the
--              conversions of APP_CONV did not reproduce yet.
--
--   Screens: VNCHECKPAY, VNCRTRN, VNDBTRN, VNCRTRN_ST, VNDBTRN_ST, PR_ORDER, PR_INCOME_LOT, PR_QUOT_TRNS, PR_MR,
--            ST_RECEIVE_COST, ST_RETURN_COST, ST_RETURN_COST2, ST_PRUCHASE_REQUEST.
--            Evidence, rules and decisions: app\legacy\processes\<FORM>.md (section "Wave 3" and "Coverage").
--
-- Conventions
--   * Called from the APEX page (action buttons, warnings, info displays, after-save / soft-delete hooks): no COMMIT /
--     ROLLBACK; a refusal raises raise_application_error(-20100..-20199) and APEX rolls the whole request back.
--     Legacy message texts, English when app_sec.lang = 'en'.
--   * Installation code (:GLOBAL.CUSTOMER_CODE = SELECT CUSTOMER_CODE FROM CUSTOMER_PAR, Sysmenu.fmx ENTER_LOGIN): CUSTOMER_PAR
--     is empty, the code is NULL. "= 'SDI'" / "= 'RSD'" branches never apply; "!= 'RSD'" / "NOT IN (...)" tests are NULL,
--     so their THEN branch is skipped too (legacy PL/SQL semantics), e.g. the supplier check of BUT_OK.
--   * Buttons that write whole documents (lot -> purchase invoice, quotation -> purchase order, imports) write the rows
--     as the legacy program units did; meanwhile the row rules of the purchasing overrides stand aside
--     (app_rules_pr.set_bypass); the generated APPX_<table> triggers only fill audit columns and empty keys.
--   * can_* functions return 'Y' / 'N' (display conditions of the action regions, never raise).
--   * last_message returns the legacy confirmation of the last action.
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_act_pr authid definer as

  -- ------------------------------------------------------------------ common
  function last_message return varchar2;
  function usr return number;                                                                    -- G_USER_CODE (test user outside APEX)
  function pw return number;                                                                     -- G_PASSWORD_NUMBER
  procedure set_test (p_user in number default null, p_password in number default null);   -- tests only (outside APEX)
  procedure reset_test;

  -- ------------------------------------------------------------------ VNDBTRN / VNCRTRN / VNCRTRN_ST / VNDBTRN_ST
  function vn_doc_warning (p_rowid in varchar2, p_trns_id in varchar2, p_doc_no in varchar2) return varchar2;   -- DOC_NO_VALIDATION
  function vn_supplier_balance (p_supplier in varchar2) return varchar2;                         -- CRN_BAL + DB_CR_FLAG
  function vn_supplier_balance_at (p_supplier in varchar2, p_date in varchar2) return varchar2;   -- _ST forms (GET_SUPPLIER_BAL)
  function vn_invoice_payments (p_rowid in varchar2) return varchar2;                            -- block VN_SUBTRNS1
  function vn_can (p_rowid in varchar2, p_what in varchar2) return varchar2;                     -- POST / UNPOST / FILL_BILLS
  function vn_post (p_rowid in varchar2) return varchar2;                                        -- POSTING -> VNACUPDT
  function vn_unpost (p_rowid in varchar2) return varchar2;                                      -- UNPOSTING -> VNACCUPDT
  function vn_fill_bills (p_rowid in varchar2) return varchar2;                                  -- FILL_BILLS

  -- ------------------------------------------------------------------ VNCHECKPAY (approval levels 1..6)
  function checkpay_level_right (p_level in number) return number;                               -- USERS.VN_PAY_AUTHn = 1
  function checkpay_can (p_rowid in varchar2) return varchar2;
  function checkpay_decide (p_rowid in varchar2, p_level in number, p_decision in number, p_memo in varchar2) return varchar2;
  function checkpay_memo (p_rowid in varchar2, p_level in number, p_memo in varchar2) return varchar2;
  function checkpay_level_text (p_rowid in varchar2, p_level in number) return varchar2;

  -- ------------------------------------------------------------------ PR_ORDER
  function order_can (p_rowid in varchar2, p_what in varchar2) return varchar2;                  -- CONFIRM / UNCONFIRM / CLOSE / OPEN / IMPORT
  function order_confirm (p_rowid in varchar2) return varchar2;                                  -- AUTH
  function order_unconfirm (p_rowid in varchar2) return varchar2;                                -- NOT_AUTH
  function order_close (p_rowid in varchar2) return varchar2;                                    -- CLOSE_FLAG_B
  function order_open (p_rowid in varchar2) return varchar2;                                     -- UNCLOSE_FLAG_B
  function order_get_items (p_rowid in varchar2, p_from_group in number, p_to_group in number) return varchar2;   -- PARA1
  function order_get_req_items (p_rowid in varchar2, p_from_date in date, p_to_date in date,
                                p_from_group in number, p_to_group in number) return varchar2;    -- PARA2
  function order_outstanding (p_rowid in varchar2) return varchar2;                              -- CHK_OUTSTANDING_QTY

  -- ------------------------------------------------------------------ PR_INCOME_LOT
  function lot_can (p_rowid in varchar2, p_what in varchar2) return varchar2;                    -- TRANSFER / UNPOST / IMPORT
  function lot_to_stores (p_rowid in varchar2, p_date in date) return varchar2;                  -- ST_POSTING + BUT_OK
  function lot_unpost (p_rowid in varchar2) return varchar2;                                     -- ST_UNPOSTING
  function lot_import_items (p_rowid in varchar2) return varchar2;                               -- ITEM_INSERT

  -- ------------------------------------------------------------------ ST_RECEIVE_COST / ST_RETURN_COST / ST_RETURN_COST2
  function st_delete_check (p_rowid in varchar2) return varchar2;                                -- KEY-DELREC (soft delete)
  procedure st_after_soft_delete (p_rowid in varchar2);                                          -- KEY-DELREC: release the lot
  function st_date_warning (p_rowid in varchar2, p_date in varchar2) return varchar2;
  function st_supplier_warning (p_rowid in varchar2, p_supplier in varchar2) return varchar2;
  function st_doc_warning (p_form in varchar2, p_rowid in varchar2, p_type in varchar2, p_doc_no in varchar2) return varchar2;
  function st_max_limit_info (p_rowid in varchar2) return varchar2;
  function st_can (p_rowid in varchar2, p_what in varchar2) return varchar2;                     -- POST / UNPOST
  function st_post (p_rowid in varchar2, p_gl in number, p_ap in number) return varchar2;        -- POST_BUT (filter 1)
  function st_unpost (p_rowid in varchar2, p_gl in number, p_ap in number, p_grouped in number) return varchar2;   -- (filter 2)

  -- ------------------------------------------------------------------ PR_QUOT_TRNS / PR_MR
  function quot_can (p_rowid in varchar2, p_what in varchar2) return varchar2;                   -- LOWEST / MAKE_PO / DELETE_PO
  function quot_lowest_price (p_rowid in varchar2) return varchar2;                              -- GET_LOWEST_PRICE
  function quot_make_po (p_rowid in varchar2) return varchar2;                                   -- GEN_PURCHASE_ORDER
  function quot_delete_po (p_rowid in varchar2, p_supplier in number) return varchar2;           -- delete PO
  procedure rfq_after_delete (p_type in varchar2, p_serial in varchar2);                         -- PR_MR KEY-DELREC

  -- ------------------------------------------------------------------ ST_PRUCHASE_REQUEST
  function prq_outstanding (p_rowid in varchar2) return varchar2;                                -- CHK_OUTSTANDING_QTY
  procedure prq_line_delete (p_type in number, p_serial in number, p_item_serial in number);     -- KEY-DELREC messages

end app_act_pr;
/
show errors package app_act_pr

create or replace package body app_act_pr as

  g_msg     varchar2(4000);
  g_t_user  number;
  g_t_pw    number;

  -- =================================================================================== common helpers
  function m (p_a in varchar2, p_e in varchar2 default null) return varchar2 is
  begin
    return case when app_sec.lang = 'en' and p_e is not null then p_e else p_a end;
  end m;

  procedure err (p_code in pls_integer, p_a in varchar2, p_e in varchar2 default null) is
  begin
    raise_application_error(p_code, m(p_a, p_e));
  end err;

  function num (p in varchar2) return number is
  begin
    return to_number(replace(trim(p), ',', '') default null on conversion error);
  end num;

  function dat (p in varchar2) return date is
  begin
    if p is null then return null; end if;
    return coalesce(to_date(p default null on conversion error, 'DD/MM/YYYY'),
                    to_date(substr(p, 1, 10) default null on conversion error, 'YYYY-MM-DD'));
  end dat;

  function usr return number is
  begin
    return nvl(num(v('G_USER_CODE')), g_t_user);
  end usr;

  function pw return number is
  begin
    return nvl(num(v('G_PASSWORD_NUMBER')), nvl(g_t_pw, 0));
  end pw;

  function comp return number is
    l number := num(v('G_COMPANY_CODE'));
  begin
    if l is null then select min(company_code) into l from ac_basic; end if;
    return l;
  end comp;

  function yn (p in boolean) return varchar2 is
  begin
    return case when p then 'Y' else 'N' end;
  end yn;

  function right_ (p_system in number, p_serial in number) return boolean is
  begin
    return app_rules_pr.file_right(p_system, p_serial, usr) = 1;
  end right_;

  -- update right on one of the menu entries of a form (legacy :GLOBAL.UPDATE_FLAG of the entry used)
  function update_right (p_system in number, p_serial1 in number, p_serial2 in number default null) return boolean is
    l number;
  begin
    if usr = 0 then return true; end if;
    select count(*) into l from file_password
     where users_code = usr and system_number = p_system and file_serial in (p_serial1, nvl(p_serial2, p_serial1))
       and nvl(update_flag, 0) = 1;
    return l > 0;
  end update_right;

  function fmt (p in number) return varchar2 is
  begin
    return to_char(p, 'FM999G999G999G990D00');
  end fmt;

  function last_message return varchar2 is
  begin
    return g_msg;
  end last_message;

  procedure set_test (p_user in number default null, p_password in number default null) is
  begin
    g_t_user := p_user; g_t_pw := p_password;
  end set_test;

  procedure reset_test is
  begin
    g_t_user := null; g_t_pw := null; g_msg := null;
  end reset_test;

  -- =================================================================================== VN
  function vn_row (p_rowid in varchar2) return vn_maintrns%rowtype is
    r vn_maintrns%rowtype;
  begin
    select * into r from vn_maintrns where rowid = chartorowid(p_rowid);
    return r;
  exception when others then
    return r;
  end vn_row;

  -- DOC_NO WHEN-VALIDATE-ITEM / PRE-INSERT -> DOC_NO_VALIDATION: same document number on the same transaction type ->
  -- alert DOC_NO_ASK (continue or stop)
  function vn_doc_warning (p_rowid in varchar2, p_trns_id in varchar2, p_doc_no in varchar2) return varchar2 is
    l_doc  number := num(p_doc_no);
    l_type number := num(p_trns_id);
    o      vn_maintrns%rowtype;
    l      number;
  begin
    if l_doc is null or l_type is null then return null; end if;
    if p_rowid is not null then
      o := vn_row(p_rowid);
      if o.doc_no = l_doc and o.trns_id = l_type then return null; end if;     -- item not changed: no validation
    end if;
    select count(*) into l from vn_maintrns
     where doc_no = l_doc and trns_id = l_type and (p_rowid is null or rowid <> chartorowid(p_rowid));
    if l > 0 then
      return m('رقم المستند مكرر', 'The document number is repeated');
    end if;
    return null;
  end vn_doc_warning;

  -- SUPPLIER_ID WHEN-VALIDATE-ITEM / POST-QUERY: CRN_BAL = credit invoice lines - debit documents (total + discount),
  -- shown as an absolute value with DB_CR_FLAG 'د' (credit, > 0) or 'م'
  function vn_supplier_balance (p_supplier in varchar2) return varchar2 is
    l_supp number := num(p_supplier);
    l_db   number;
    l_cr   number;
    l_bal  number;
  begin
    if l_supp is null then return null; end if;
    select nvl(sum(nvl(total_value, 0) + nvl(disc_value, 0)), 0) into l_db
      from vn_maintrns mn, vn_trnstype typ where mn.trns_id = typ.id and typ.effect = 0 and mn.supplier_id = l_supp;
    select nvl(sum(nvl(s.total_value, 0) + nvl(s.disc_value, 0)), 0) into l_cr
      from vn_maintrns mn, vn_trnstype typ, vn_subtrns s
     where mn.trns_id = typ.id and mn.trns_id = s.trns_id and mn.trns_serial = s.trns_serial
       and typ.effect = 1 and mn.supplier_id = l_supp;
    l_bal := l_cr - l_db;
    return fmt(abs(l_bal)) || ' ' || case when l_bal > 0 then m('د', 'C') else m('م', 'D') end;
  end vn_supplier_balance;

  function vn_supplier_balance_at (p_supplier in varchar2, p_date in varchar2) return varchar2 is
    l_supp number := num(p_supplier);
    l_bal  number;
  begin
    if l_supp is null then return null; end if;
    l_bal := nvl(get_supplier_bal(l_supp, dat(p_date)), 0);
    return fmt(abs(l_bal)) || ' ' || case when l_bal > 0 then m('د', 'C') else m('م', 'D') end;
  end vn_supplier_balance_at;

  -- detail block VN_SUBTRNS1 (payments of each invoice line: TRNS_ID in the debit types) shown as one text
  function vn_invoice_payments (p_rowid in varchar2) return varchar2 is
    h   vn_maintrns%rowtype := vn_row(p_rowid);
    l   varchar2(4000);
    n   pls_integer := 0;
  begin
    if h.trns_id is null then return null; end if;
    for p in (select i.bill_id1, p.trns_id, p.trns_serial, pm.trns_date, p.total_value, p.disc_value
                from vn_subtrns i
                join vn_subtrns p on p.inv_trns_id = i.trns_id and p.inv_trns_serial = i.trns_serial and p.inv_bill_seq = i.bill_seq
                join vn_maintrns pm on pm.trns_id = p.trns_id and pm.trns_serial = p.trns_serial
               where i.trns_id = h.trns_id and i.trns_serial = h.trns_serial
                 and p.trns_id in (select id from vn_trnstype where effect = 0)
               order by i.bill_seq, pm.trns_date, p.trns_id, p.trns_serial) loop
      n := n + 1;
      exit when n > 30;
      l := l || case when l is not null then chr(10) end
           || m('فاتورة ', 'Invoice ') || p.bill_id1 || ': ' || p.trns_id || '/' || p.trns_serial || ' '
           || to_char(p.trns_date, 'DD/MM/YYYY') || ' ' || fmt(p.total_value)
           || case when nvl(p.disc_value, 0) <> 0 then ' (' || m('خصم ', 'discount ') || fmt(p.disc_value) || ')' end;
    end loop;
    return nvl(l, m('لا توجد سدادات', 'No payments'));
  end vn_invoice_payments;

  function has_rap_chk return boolean is
    l number;
  begin
    select count(*) into l from sys_systems where system_number in (13, 15);
    return l > 0;
  end has_rap_chk;

  function vn_can (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    h vn_maintrns%rowtype := vn_row(p_rowid);
    l number;
    l_type number;
    l_effect number;
  begin
    if h.trns_id is null or nvl(h.link_flag, 0) <> 0 then return 'N'; end if;
    if p_what = 'POST' then
      -- POSTING: record saved, not posted, CHECK_FILE_PREV(11) (VNACUPDT)
      return yn(nvl(h.post_flag, 0) = 0 and right_(5, 11));
    elsif p_what = 'UNPOST' then
      -- UNPOSTING: posted, CHECK_FILE_PREV(12) (VNACCUPDT); cash / cheque payments are cancelled from their systems
      return yn(nvl(h.post_flag, 0) = 1 and (nvl(h.pay_method, 5) = 5 or not has_rap_chk) and right_(5, 12));
    elsif p_what = 'FILL_BILLS' then
      -- BILL_PAY_METHOD_DUMMY WHEN-LIST-CHANGED: method 1 ("تنازلي") on an empty payment of an unposted debit document
      select max(effect) into l_effect from vn_trnstype where id = h.trns_id;
      select count(*) into l from vn_subtrns where trns_id = h.trns_id and trns_serial = h.trns_serial;
      return yn(l_effect = 0 and nvl(h.post_flag, 0) = 0 and nvl(h.pay_flag, 0) = 0 and nvl(h.bill_pay_method, 1) = 1
                and l = 0 and nvl(h.total_value, 0) > 0);
    end if;
    return 'N';
  exception when others then
    return 'N';
  end vn_can;

  function vn_post (p_rowid in varchar2) return varchar2 is
    h vn_maintrns%rowtype := vn_row(p_rowid);
  begin
    g_msg := null;
    if h.trns_id is null then err(-20150, 'يجب حفظ السجل اولا', 'You must save record first'); end if;
    if nvl(h.post_flag, 0) = 1 then err(-20150, 'السجل مرحل بالفعل', 'Record Already Posted'); end if;
    if not right_(5, 11) then err(-20150, 'غير مسموح لك بالدخول على هذه الشاشة', 'YOU ARE NOT ALLOWED TO ENTER THIS SCREEN'); end if;
    -- VNACUPDT opened with TRANS_ID / SERIAL / DATE = ACC_POST_DATE: the posting of this one transaction
    app_proc_vn.post_to_gl(p_from_date => nvl(h.acc_post_date, h.trns_date), p_to_date => nvl(h.acc_post_date, h.trns_date),
                           p_from_trns_id => h.trns_id, p_to_trns_id => h.trns_id,
                           p_from_serial => h.trns_serial, p_to_serial => h.trns_serial,
                           p_company_code => comp, p_user_code => usr, p_password_number => pw);
    g_msg := m('تمت عملية الترحيل', 'Posting completed');
    return null;
  end vn_post;

  function vn_unpost (p_rowid in varchar2) return varchar2 is
    h vn_maintrns%rowtype := vn_row(p_rowid);
  begin
    g_msg := null;
    if h.trns_id is null then err(-20150, 'يجب حفظ السجل اولا', 'You must save record first'); end if;
    if nvl(h.post_flag, 0) = 0 then err(-20150, 'السجل غير مرحل', 'Record Not Posted'); end if;
    if not right_(5, 12) then err(-20150, 'غير مسموح لك بالدخول على هذه الشاشة', 'YOU ARE NOT ALLOWED TO ENTER THIS SCREEN'); end if;
    -- VNACCUPDT opened with TRANS_ID / SERIAL / DATE = TRNS_DATE
    app_proc_vn.cancel_gl_posting(p_from_date => h.trns_date, p_to_date => h.trns_date,
                                  p_from_trns_id => h.trns_id, p_to_trns_id => h.trns_id,
                                  p_from_serial => h.trns_serial, p_to_serial => h.trns_serial,
                                  p_company_code => comp, p_user_code => usr, p_password_number => pw);
    g_msg := m('تمت عملية إلغاء الترحيل', 'Cancel posting completed');
    return null;
  end vn_unpost;

  -- FILL_BILLS: open invoice lines of the supplier (same currency, same payment type, not stopped), oldest first, each paid
  -- with its residual until the payment total is used up
  function vn_fill_bills (p_rowid in varchar2) return varchar2 is
    h       vn_maintrns%rowtype := vn_row(p_rowid);
    l_rem   number;
    l_seq   number;
    l_total number;
    l_n     number := 0;
  begin
    g_msg := null;
    if vn_can(p_rowid, 'FILL_BILLS') = 'N' then
      err(-20151, 'لا يمكن توزيع السداد على الفواتير لهذه الحركة', 'The payment cannot be allocated to invoices');
    end if;
    select h.total_value - nvl(sum(net_value), 0), nvl(max(bill_seq), 0) into l_rem, l_seq
      from vn_subtrns where trns_id = h.trns_id and trns_serial = h.trns_serial;
    for c in (select s.bill_id1, s.bill_id2,
                     s.total_value - vn_subtrns_payed_value(s.trns_id, s.trns_serial, s.bill_seq) residual_value,
                     s.total_value, s.trns_id, s.trns_serial, s.bill_seq, m.trns_date, s.pay_type_code, m.supplier_ref
                from vn_subtrns s, vn_maintrns m
               where m.trns_id in (select id from vn_trnstype where effect = 1)
                 and nvl(s.total_value - vn_subtrns_payed_value(s.trns_id, s.trns_serial, s.bill_seq), 0) > 0
                 and m.trns_id = s.trns_id and m.trns_serial = s.trns_serial
                 and m.supplier_id = h.supplier_id
                 and m.currency_code = h.currency_code
                 and nvl(s.stop_flag, 0) = 0
                 and s.pay_type_code = h.pay_type_code
               order by m.trns_date, s.bill_id1, s.bill_id2) loop
      exit when l_rem <= 0;
      l_total := c.residual_value;
      if l_total >= l_rem then
        l_total := l_rem;
        l_rem := 0;
      else
        l_rem := l_rem - l_total;
      end if;
      l_seq := l_seq + 1;
      insert into vn_subtrns (trns_id, trns_serial, bill_seq, pay_type_code, inv_trns_id, inv_trns_serial, inv_bill_seq,
                              inv_date, inv_supplier_ref, bill_id1, bill_id2, disc_value, total_value, net_value)
      values (h.trns_id, h.trns_serial, l_seq, c.pay_type_code, c.trns_id, c.trns_serial, c.bill_seq,
              c.trns_date, c.supplier_ref, c.bill_id1, c.bill_id2, 0, l_total, l_total);
      l_n := l_n + 1;
    end loop;
    if l_n = 0 then
      err(-20151, 'لا توجد فواتير مفتوحة للمورد بنفس العملة ونوع الدفعة', 'The supplier has no open invoices in this currency and payment type');
    end if;
    -- the PRE-INSERT effects of the lines (net / currency difference, header discount and residual, invoice residuals)
    app_rules_vn.after_save('VNDBTRN', p_rowid, 'CREATE');
    g_msg := m('تم توزيع السداد على ' || l_n || ' فاتورة', 'The payment was allocated to ' || l_n || ' invoice(s)');
    return null;
  end vn_fill_bills;

  -- =================================================================================== VNCHECKPAY
  function checkpay_level_right (p_level in number) return number is
    l number;
  begin
    select count(*) into l from users
     where users_code = usr
       and 1 = case p_level when 1 then nvl(vn_pay_auth1, 0) when 2 then nvl(vn_pay_auth2, 0) when 3 then nvl(vn_pay_auth3, 0)
                            when 4 then nvl(vn_pay_auth4, 0) when 5 then nvl(vn_pay_auth5, 0) when 6 then nvl(vn_pay_auth6, 0) end;
    return case when l > 0 then 1 else 0 end;
  end checkpay_level_right;

  function ck_row (p_rowid in varchar2) return vn_maintrns_check%rowtype is
    r vn_maintrns_check%rowtype;
  begin
    select * into r from vn_maintrns_check where rowid = chartorowid(p_rowid);
    return r;
  exception when others then
    return r;
  end ck_row;

  -- WHEN-NEW-FORM-INSTANCE: the ACCEPT / REFUSE / memo buttons of level n are enabled when USERS.VN_PAY_AUTHn = 1;
  -- PRE-UPDATE (AUTH_ALR2): an authorised request (AUTH_FLAG = 1) cannot be changed
  function checkpay_can (p_rowid in varchar2) return varchar2 is
    r vn_maintrns_check%rowtype := ck_row(p_rowid);
    l number := 0;
  begin
    if r.serial is null or nvl(r.auth_flag, 0) = 1 then return 'N'; end if;
    for i in 1 .. 6 loop
      l := l + checkpay_level_right(i);
    end loop;
    return yn(l > 0);
  end checkpay_can;

  procedure ck_level_checks (r vn_maintrns_check%rowtype, p_level in number) is
  begin
    if r.serial is null then err(-20152, 'يجب حفظ السجل اولا', 'You must save record first'); end if;
    if nvl(r.auth_flag, 0) = 1 then
      err(-20152, 'الحركة الحالية تم اعتمادها و لا يمكن تعديلها', 'The current request is authorised and cannot be changed');
    end if;
    if p_level is null or p_level not between 1 and 6 then
      err(-20152, 'يجب اختيار مستوى الاعتماد', 'Choose the approval level');
    end if;
    if checkpay_level_right(p_level) = 0 then
      err(-20152, 'ليس لديك صلاحية على مستوى الاعتماد ' || p_level, 'You have no right on approval level ' || p_level);
    end if;
  end ck_level_checks;

  -- ACCEPT_AUTH_BTNn: VN_PAY_AUTHn := 1, REFUSE_AUTH_BTNn: VN_PAY_AUTHn := -1, then COMMIT_FORM (memo of the level optional)
  function checkpay_decide (p_rowid in varchar2, p_level in number, p_decision in number, p_memo in varchar2) return varchar2 is
    r vn_maintrns_check%rowtype := ck_row(p_rowid);
  begin
    g_msg := null;
    ck_level_checks(r, p_level);
    if p_decision not in (1, -1) then err(-20152, 'قرار غير صحيح', 'Invalid decision'); end if;
    update vn_maintrns_check
       set vn_pay_auth1 = case when p_level = 1 then p_decision else vn_pay_auth1 end,
           vn_pay_auth2 = case when p_level = 2 then p_decision else vn_pay_auth2 end,
           vn_pay_auth3 = case when p_level = 3 then p_decision else vn_pay_auth3 end,
           vn_pay_auth4 = case when p_level = 4 then p_decision else vn_pay_auth4 end,
           vn_pay_auth5 = case when p_level = 5 then p_decision else vn_pay_auth5 end,
           vn_pay_auth6 = case when p_level = 6 then p_decision else vn_pay_auth6 end,
           vn_pay_auth1_memo = case when p_level = 1 and p_memo is not null then p_memo else vn_pay_auth1_memo end,
           vn_pay_auth2_memo = case when p_level = 2 and p_memo is not null then p_memo else vn_pay_auth2_memo end,
           vn_pay_auth3_memo = case when p_level = 3 and p_memo is not null then p_memo else vn_pay_auth3_memo end,
           vn_pay_auth4_memo = case when p_level = 4 and p_memo is not null then p_memo else vn_pay_auth4_memo end,
           vn_pay_auth5_memo = case when p_level = 5 and p_memo is not null then p_memo else vn_pay_auth5_memo end,
           vn_pay_auth6_memo = case when p_level = 6 and p_memo is not null then p_memo else vn_pay_auth6_memo end
     where rowid = chartorowid(p_rowid);
    g_msg := case when p_decision = 1 then m('تمت الموافقة على المستوى ' || p_level, 'Level ' || p_level || ' approved')
                  else m('تم رفض المستوى ' || p_level, 'Level ' || p_level || ' refused') end;
    return null;
  end checkpay_decide;

  -- VN_PAY_AUTHn_MEMO_BTN: EDIT_TEXTITEM on the memo of the level
  function checkpay_memo (p_rowid in varchar2, p_level in number, p_memo in varchar2) return varchar2 is
    r vn_maintrns_check%rowtype := ck_row(p_rowid);
  begin
    g_msg := null;
    ck_level_checks(r, p_level);
    update vn_maintrns_check
       set vn_pay_auth1_memo = case when p_level = 1 then p_memo else vn_pay_auth1_memo end,
           vn_pay_auth2_memo = case when p_level = 2 then p_memo else vn_pay_auth2_memo end,
           vn_pay_auth3_memo = case when p_level = 3 then p_memo else vn_pay_auth3_memo end,
           vn_pay_auth4_memo = case when p_level = 4 then p_memo else vn_pay_auth4_memo end,
           vn_pay_auth5_memo = case when p_level = 5 then p_memo else vn_pay_auth5_memo end,
           vn_pay_auth6_memo = case when p_level = 6 then p_memo else vn_pay_auth6_memo end
     where rowid = chartorowid(p_rowid);
    g_msg := m('تم حفظ ملاحظة المستوى ' || p_level, 'Memo of level ' || p_level || ' saved');
    return null;
  end checkpay_memo;

  -- SET_BACKGROUD: green = approved (1), red = refused (-1), white = no decision
  function checkpay_level_text (p_rowid in varchar2, p_level in number) return varchar2 is
    r vn_maintrns_check%rowtype := ck_row(p_rowid);
    l_v number; l_m varchar2(4000);
  begin
    if r.serial is null then return null; end if;
    case p_level
      when 1 then l_v := r.vn_pay_auth1; l_m := r.vn_pay_auth1_memo;
      when 2 then l_v := r.vn_pay_auth2; l_m := r.vn_pay_auth2_memo;
      when 3 then l_v := r.vn_pay_auth3; l_m := r.vn_pay_auth3_memo;
      when 4 then l_v := r.vn_pay_auth4; l_m := r.vn_pay_auth4_memo;
      when 5 then l_v := r.vn_pay_auth5; l_m := r.vn_pay_auth5_memo;
      when 6 then l_v := r.vn_pay_auth6; l_m := r.vn_pay_auth6_memo;
      else return null;
    end case;
    return case l_v when 1 then m('موافق', 'Approved') when -1 then m('مرفوض', 'Refused') else '-' end
           || case when l_m is not null then ' - ' || l_m end;
  end checkpay_level_text;

  -- =================================================================================== PR_ORDER
  function po_row (p_rowid in varchar2) return pr_order%rowtype is
    r pr_order%rowtype;
  begin
    select * into r from pr_order where rowid = chartorowid(p_rowid);
    return r;
  exception when others then
    return r;
  end po_row;

  -- CHECK_CLOSE (menu entry "confirm purchase orders", :PARAMETER.CONFIRM = 'Y', registry 30/2):
  --   closed -> UNCLOSE only; confirmed -> NOT_AUTH + CLOSE; else AUTH + CLOSE. Imports (PARA1 / PARA2) need an open order.
  function order_can (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    o pr_order%rowtype := po_row(p_rowid);
  begin
    if o.trns_type_code is null then return 'N'; end if;
    if p_what = 'IMPORT' then
      return yn(nvl(o.confirm_flag, 0) = 0 and nvl(o.close_flag, 0) = 0);
    end if;
    if not right_(30, 2) then return 'N'; end if;
    return yn(case p_what
                when 'CONFIRM'   then nvl(o.close_flag, 0) = 0 and nvl(o.confirm_flag, 0) = 0
                when 'UNCONFIRM' then nvl(o.close_flag, 0) = 0 and nvl(o.confirm_flag, 0) = 1
                when 'CLOSE'     then nvl(o.close_flag, 0) = 0
                when 'OPEN'      then nvl(o.close_flag, 0) = 1
                else false end);
  end order_can;

  function order_confirm (p_rowid in varchar2) return varchar2 is
    o pr_order%rowtype := po_row(p_rowid);
    l number;
  begin
    g_msg := null;
    if o.trns_type_code is null then err(-20153, ' يجب حفظ السجل أولا ', ' You Must Save Record'); end if;
    select count(1) into l from pr_order_det
     where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial
       and (nvl(quantity, 0) + nvl(bonus, 0) + nvl(extra_bonus, 0) <= 0 or nvl(vn_price, 0) <= 0);
    if l = 0 then
      select count(1) into l from pr_order_srvc
       where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial and (nvl(quantity, 0) <= 0 or nvl(unit_cost, 0) <= 0);
    end if;
    if l = 0 then
      select count(1) into l from pr_order_asst
       where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial and nvl(quantity, 0) <= 0;
    end if;
    if l >= 1 then err(-20153, ' بعض الاصناف ليس لها كمية أو سعر ', ' Some Items Have Quantity Or Price Zero'); end if;
    select count(1) into l from pr_order_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    if l = 0 then err(-20153, ' يجب إدخال أصناف ', ' There Is No Items'); end if;
    update pr_order set confirm_flag = 1 where rowid = chartorowid(p_rowid);
    g_msg := m(' تم إعتماد أمر الشراء ', ' Purchase Has Autherd ');
    return null;
  end order_confirm;

  function order_unconfirm (p_rowid in varchar2) return varchar2 is
    o pr_order%rowtype := po_row(p_rowid);
    l number;
  begin
    g_msg := null;
    select count(1) into l from pr_income_lot where order_trns_type_code = o.trns_type_code and order_trns_serial = o.trns_serial;
    if l > 0 then                                       -- ":GLOBAL.CUSTOMER_CODE = 'SDI'" is NULL here
      err(-20153, 'لا يمكن الغاء الاعتماد', 'Cannot Cancel Posting.');
    end if;
    update pr_order set confirm_flag = 0 where rowid = chartorowid(p_rowid);
    g_msg := m(' تم إلغاء إعتماد أمر الشراء ', ' Purchase Has Not Autherd ');
    return null;
  end order_unconfirm;

  function order_close (p_rowid in varchar2) return varchar2 is
  begin
    g_msg := null;
    update pr_order set close_flag = 1 where rowid = chartorowid(p_rowid);
    g_msg := m('تم اقفال أمر الشراء', 'Purchase Order Closed');
    return null;
  end order_close;

  function order_open (p_rowid in varchar2) return varchar2 is
  begin
    g_msg := null;
    update pr_order set close_flag = 0 where rowid = chartorowid(p_rowid);
    g_msg := m('تم ا الغاء قفال أمر الشراء', 'Purchase Order Open');
    return null;
  end order_open;

  procedure po_import_check (o pr_order%rowtype) is
    l number;
  begin
    if o.trns_type_code is null then err(-20154, ' يجب حفظ السجل أولا ', ' You Must Save Record'); end if;
    if nvl(o.confirm_flag, 0) = 1 or nvl(o.close_flag, 0) = 1 then
      err(-20154, 'أمر الشراء معتمد أو مقفل ولا يمكن تعديل أصنافه', 'The purchase order is confirmed or closed');
    end if;
    select count(*) into l from pr_order_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    if l > 0 then
      err(-20154, 'لا يمكن انزال اصناف مع وجود اصناف موجودة من قبل', 'You can''t drop item while old item exists');
    end if;
  end po_import_check;

  procedure po_add_line (o pr_order%rowtype, p_group number, p_item varchar2, p_unit number) is
    l_serial number;
  begin
    select nvl(max(serial), 0) + 1 into l_serial from pr_order_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    insert into pr_order_det (trns_type_code, trns_serial, serial, pr_order_date, group_code, item_code, unit_code, quantity)
    values (o.trns_type_code, o.trns_serial, l_serial, o.pr_order_date, p_group, p_item, p_unit, 1);
  end po_add_line;

  -- PARA1.GET_ITEMS_ACTUAL: every active item (basic unit) of the group range, quantity 1; prices are typed before saving
  function order_get_items (p_rowid in varchar2, p_from_group in number, p_to_group in number) return varchar2 is
    o pr_order%rowtype := po_row(p_rowid);
    l_n number := 0;
  begin
    g_msg := null;
    po_import_check(o);
    app_rules_pr.set_bypass(true);
    for r in (select distinct i.item_code, u.unit_code, i.item_group_code
                from st_item i, st_item_unit u
               where i.stop_flag = 0
                 and i.item_code = u.item_code and i.item_group_code = u.group_code and u.basic_unit = 1
                 and (i.item_group_code, i.item_code) not in
                     (select group_code, item_code from pr_order_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial)
                 and (pw = 0 or i.item_group_code in (select group_code from st_group_password where password_number = pw))
                 and (p_from_group is null or u.group_code >= p_from_group)
                 and (p_to_group is null or u.group_code <= p_to_group)
               order by i.item_code) loop
      po_add_line(o, r.item_group_code, r.item_code, r.unit_code);
      l_n := l_n + 1;
    end loop;
    app_rules_pr.set_bypass(false);
    g_msg := m('تم انزال ' || l_n || ' صنف - يجب إدخال الأسعار قبل الحفظ', l_n || ' items added - enter the prices before saving');
    return null;
  exception when others then
    app_rules_pr.set_bypass(false);
    raise;
  end order_get_items;

  -- PARA2.GET_REQ_ITEMS: items sold (TRNS_TYPE 2 / EFFECT 2) in the period whose sales x 20 % exceed the balance of all stores
  -- the day before the period, quantity 1
  function order_get_req_items (p_rowid in varchar2, p_from_date in date, p_to_date in date,
                                p_from_group in number, p_to_group in number) return varchar2 is
    o     pr_order%rowtype := po_row(p_rowid);
    l_n   number := 0;
    l_min date;
  begin
    g_msg := null;
    select min(min_date) into l_min from st_basic;
    for d in (select p_from_date dd from dual union all select p_to_date from dual) loop      -- CHECK_DATE
      if d.dd is not null and trunc(d.dd) > trunc(sysdate) then
        err(-20154, 'التاريخ أكبر من تاريخ اليوم', 'The date is after today');
      end if;
      if d.dd is not null and l_min is not null and trunc(d.dd) < trunc(l_min) then
        err(-20154, 'الحد الأدنى للتاريخ هو ' || to_char(l_min, 'DD/MM/YYYY'), 'The least date accepted is ' || to_char(l_min, 'DD/MM/YYYY'));
      end if;
    end loop;
    po_import_check(o);
    if p_from_date is null or p_to_date is null then err(-20154, 'يجب ادخال التواريخ', 'You Must Enter The Dates'); end if;
    if p_to_date < p_from_date then
      err(-20154, 'التاريخ الثانى يجب ان يكون اكبر من التاريخ الاول', 'The second date should be over then the first date');
    end if;
    app_rules_pr.set_bypass(true);
    for r in (select it.item_group_code, it.item_code, iu.unit_code
                from st_item it, st_item_unit iu, st_unit u, st_trns_mast tm, st_trns_det td, st_trns_type tt
               where it.item_code = iu.item_code and iu.basic_unit = 1 and nvl(it.stop_flag, 0) = 0
                 and iu.unit_code = u.unit_code
                 and tm.trns_type_code = td.trns_type_code and tm.trns_serial = td.trns_serial
                 and tm.trns_date >= p_from_date and tm.trns_date <= p_to_date
                 and (p_from_group is null or td.group_code >= p_from_group)
                 and (p_to_group is null or td.group_code <= p_to_group)
                 and td.trns_type_code = tt.trns_type_code
                 and td.group_code = it.item_group_code and td.item_code = it.item_code
                 and tt.trns_type = 2 and tt.effect = 2
                 and (it.item_group_code, it.item_code) not in
                     (select group_code, item_code from pr_order_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial)
                 and (pw = 0 or it.item_group_code in (select group_code from st_group_password where password_number = pw))
               group by it.item_group_code, it.item_code, it.name_a, it.name_e, iu.unit_code, u.name_a, u.name_e, it.unit_cost
              having sum(basic_qty) * 0.2 > get_all_stores_balance(it.item_group_code, it.item_code, p_from_date - 1)
               order by it.item_code) loop
      po_add_line(o, r.item_group_code, r.item_code, r.unit_code);
      l_n := l_n + 1;
    end loop;
    app_rules_pr.set_bypass(false);
    g_msg := m('تم انزال ' || l_n || ' صنف - يجب إدخال الأسعار قبل الحفظ', l_n || ' items added - enter the prices before saving');
    return null;
  exception when others then
    app_rules_pr.set_bypass(false);
    raise;
  end order_get_req_items;

  -- PR_ORDER_DET PRE-INSERT -> CHK_OUTSTANDING_QTY: quantity of the order not received yet in incoming lots, per item and unit
  function order_outstanding (p_rowid in varchar2) return varchar2 is
    o pr_order%rowtype := po_row(p_rowid);
    l varchar2(4000);
    n pls_integer := 0;
  begin
    if o.trns_type_code is null then return null; end if;
    for r in (select d.group_code, d.item_code, d.unit_code, sum(nvl(d.quantity, 0)) demand,
                     (select nvl(sum(nvl(ld.income_quantity, 0)), 0) from pr_income_lot_det ld, pr_income_lot lm
                       where ld.trns_type_code = lm.trns_type_code and ld.trns_serial = lm.trns_serial
                         and lm.order_trns_type_code = o.trns_type_code and lm.order_trns_serial = o.trns_serial
                         and ld.group_code = d.group_code and ld.item_code = d.item_code and ld.unit_code = d.unit_code) received
                from pr_order_det d
               where d.trns_type_code = o.trns_type_code and d.trns_serial = o.trns_serial
               group by d.group_code, d.item_code, d.unit_code
               order by d.item_code) loop
      if r.received < r.demand then
        n := n + 1;
        exit when n > 30;
        l := l || case when l is not null then chr(10) end
             || m(' هناك كمية ' || (r.demand - r.received) || ' من الصنف ' || r.item_code || ' لم يتم إستلامها',
                  ' The quantity ' || (r.demand - r.received) || ' from item No. ' || r.item_code || ' is outstanding');
      end if;
    end loop;
    return l;
  end order_outstanding;

  -- =================================================================================== PR_INCOME_LOT
  function lot_row (p_rowid in varchar2) return pr_income_lot%rowtype is
    r pr_income_lot%rowtype;
  begin
    select * into r from pr_income_lot where rowid = chartorowid(p_rowid);
    return r;
  exception when others then
    return r;
  end lot_row;

  function lot_invoices (l pr_income_lot%rowtype, p_active in number) return number is
    n number;
  begin
    select count(1) into n from st_trns_mast
     where income_trns_type_code = l.trns_type_code and income_trns_serial = l.trns_serial
       and (p_active = 0 or nvl(delete_flag, 0) = 0);
    return n;
  end lot_invoices;

  -- ST_POSTING / ST_UNPOSTING: enabled with the update right of the screen (DEF_USR_SEC / :GLOBAL.UPDATE_FLAG)
  function lot_can (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    l pr_income_lot%rowtype := lot_row(p_rowid);
  begin
    if l.trns_type_code is null or nvl(l.st_srv_asst_flag, 1) = 4 then return 'N'; end if;
    if p_what = 'TRANSFER' then
      return yn(nvl(l.post_flag, 0) <> 1 and lot_invoices(l, 1) = 0 and update_right(30, 3, 4));
    elsif p_what = 'UNPOST' then
      return yn(nvl(l.post_flag, 0) = 1 and update_right(30, 3, 4));
    elsif p_what = 'IMPORT' then
      return yn(nvl(l.post_flag, 0) <> 1 and l.pu_trns_serial is null and l.order_trns_serial is not null);
    end if;
    return 'N';
  exception when others then
    return 'N';
  end lot_can;

  -- ST_POSTING: CALC_UNIT_COST for every line (freight and header discount spread by value), UPDATE_COST (average per item,
  -- group and sales price)
  procedure lot_calc_costs (l pr_income_lot%rowtype) is
    l_rate  number := nvl(l.currency_rate, 1);
    l_stvr  number;
    l_tibq  number;
    l_tvr   number;
    l_vr    number;
    l_fr    number;
    l_disc  number;
  begin
    select sum(((nvl(income_quantity, 0) * (nvl(vn_price, 0) - (nvl(disc1_value, 0) + nvl(disc2_value, 0) + nvl(disc3_value, 0))))
                - nvl(det_disc, 0)) * l_rate),
           sum(income_basic_qty)
      into l_stvr, l_tibq
      from pr_income_lot_det where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial;
    for d in (select rowid rd, x.* from pr_income_lot_det x where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial
               order by serial) loop
      continue when d.item_code is null;
      l_vr  := ((nvl(d.income_quantity, 0) * (nvl(d.vn_price, 0) - (nvl(d.disc1_value, 0) + nvl(d.disc2_value, 0) + nvl(d.disc3_value, 0)
                 + nvl(d.supp_disc_value, 0)))) - nvl(d.det_disc, 0)) * l_rate;
      l_tvr := ((nvl(d.income_quantity, 0) * (nvl(d.vn_price, 0) - (nvl(d.disc1_value, 0) + nvl(d.disc2_value, 0) + nvl(d.disc3_value, 0))))
                 - nvl(d.det_disc, 0)) * l_rate;
      if nvl(l_tibq, 0) = 0 or l_stvr = 0 then
        l_fr := 0;
        l_disc := 0;
      else
        l_fr   := round(nvl(l.freight_val, 0) * (nvl(l_tvr, 0) / nvl(l_stvr, 1)) / nvl(d.income_basic_qty, 1), 2);
        l_disc := nvl(l.disc_val, 0) * (nvl(l_tvr, 0) / nvl(l_stvr, 1)) / nvl(d.income_basic_qty, 1);
        if d.income_quantity is null or l.disc_val is null or d.vn_price is null or d.group_code is null or nvl(l_tvr, 0) = 0 then
          l_disc := 0;                                   -- earlier IFs of CALC_UNIT_COST, overwritten for FREIGHT only
        end if;
      end if;
      update pr_income_lot_det
         set freight = l_fr, disc = l_disc,
             unit_cost = case when nvl(d.income_basic_qty, 0) = 0 then round(nvl(l_vr, 0) + nvl(l_fr, 0) - nvl(l_disc, 0), 10)
                              else round((nvl(l_vr, 0) / nvl(d.income_basic_qty, 1)) + nvl(l_fr, 0) - nvl(l_disc, 0), 10) end
       where rowid = d.rd;
    end loop;
    for a in (select sum(unit_cost * income_basic_qty) total_cost, sum(income_basic_qty) qty, item_code, group_code, sales_price
                from pr_income_lot_det where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial
               group by item_code, group_code, sales_price) loop
      update pr_income_lot_det set unit_cost = a.total_cost / a.qty
       where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial
         and item_code = a.item_code and group_code = a.group_code and sales_price = a.sales_price;
    end loop;
  end lot_calc_costs;

  -- CREATE_TRNS: purchase invoice of the lot (header, dues, lines with their lot configuration, services, supplier expenses)
  function lot_create_trns (l pr_income_lot%rowtype, p_type number, p_date date) return varchar2 is
    l_serial  number;
    l_dser    number;
    l_doc     number;
    l_total   number;
    l_srvc    number;
    l_tax     number;
    l_factor  number;
    l_confg   number;
    l_br      number;
    l_ebr     number;
    l_ndb     number;
    l_snr     number;
    l_nr      number;
  begin
    select nvl(max(trns_serial), 0) + 1 into l_serial from st_trns_mast where trns_type_code = p_type;
    select nvl(max(date_serial), 0) + 1 into l_dser from st_trns_mast where trns_date = p_date;   -- replaced by ST_TRNS_MAST_IN
    -- GET_NEXT_DOC_NO_STR (":GLOBAL.CUSTOMER_CODE = 'SDI'" -> lot DOC_NO is not taken)
    select nvl(max(doc_no), 0) + 1 into l_doc from st_trns_mast
     where trns_type_code = p_type and store_code = l.store_code and nvl(delete_flag, 0) = 0;
    if l_doc = 1 then
      l_doc := to_number(substr(to_char(l.store_code), 1, 2) || substr(to_char(l.store_code), 4, 2) || lpad(1, 6, 0));
    end if;
    insert into st_trns_mast
      (trns_type_code, trns_serial, trns_date, date_serial, doc_no, desc_a, desc_e, currency_code, currency_rate, supplier_code,
       account_number2, cost_code, cost_code2, store_code, post_flag, delete_flag, income_trns_type_code, income_trns_serial,
       cntrct_serial, pr_trns_type_code, pr_trns_serial, invoice_no, posting_supplier_code, disc_val, order_trns_type_code,
       order_trns_serial, vessel_name, supplier_ref, wieght, atm_desc, check_date, freight_val)
    values
      (p_type, l_serial, p_date, l_dser, l_doc,
       'استلام رقم  ' || l.trns_type_code || ' / ' || l.trns_serial || '  بتاريخ  ' || to_char(l.arrival_date, 'DD-MM-YYYY') || ' ',
       l.desc_e, nvl(l.currency_code, 1), nvl(l.currency_rate, 1), l.supplier_code,
       l.account_number, l.cost_code, l.cost_code2, l.store_code, 0, 0, l.trns_type_code, l.trns_serial,
       get_cntrct_serial(l.order_trns_type_code, l.order_trns_serial), l.order_trns_type_code, l.order_trns_serial,
       to_char(l.trns_type_code) || lpad(to_char(l.trns_serial), 7, '0'), l.supplier_code, l.disc_val, l.order_trns_type_code,
       l.order_trns_serial, l.vessel_name, l.supplier_ref, l.wieght, l.atm_desc, l.check_date, l.freight_val);
    if l.supplier_code is not null then
      select nvl(sum((nvl(income_quantity, 0) * (nvl(vn_price, 0) - (nvl(disc1_value, 0) + nvl(disc2_value, 0) + nvl(disc3_value, 0))))
                     - nvl(det_disc, 0)), 0) - nvl(l.disc_val, 0) / nvl(l.currency_rate, 1),
             nvl(sum(tax_value1), 0)
        into l_total, l_tax
        from pr_income_lot_det where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial;
      select nvl(sum(unit_cost * income_quantity_srvc), 0) into l_srvc
        from pr_income_lot_srvc where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial;
      insert into st_trns_det_dues (trns_type_code, trns_serial, due_serial, supp_due_date, posting_supp_due_date, amount, amount_curr, payed_flag)
      values (p_type, l_serial, 1, p_date, p_date,
              (l_total * nvl(l.currency_rate, 1)) + (l_srvc * nvl(l.currency_rate, 1)) + l_tax,
              l_total + l_srvc + l_tax, 0);
    end if;
    select sum(((nvl(income_quantity, 0) * nvl(vn_price, 0)) - nvl(det_disc, 0)) * nvl(l.currency_rate, 1)) into l_snr
      from pr_income_lot_det where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial;
    for x in (select * from pr_income_lot_det where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial order by serial) loop
      begin
        select factor into l_factor from st_item_unit where group_code = x.group_code and item_code = x.item_code and unit_code = x.unit_code;
      exception when no_data_found then
        l_factor := 1;
      end;
      l_confg := get_confg_id(x.item_code, x.group_code, l.supplier_code, x.sales_price, x.lot_number, x.expire_date,
                              nvl(x.sales_disc_ratio, 0), l.store_code, true, null, null);
      update pr_income_lot_det set item_confg_id = l_confg
       where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial and serial = x.serial;
      l_br  := case when nvl(x.income_quantity, 0) <> 0 then (nvl(x.income_bonus, 0) / nvl(x.income_quantity, 0)) * 100 else 0 end;
      l_ebr := case when nvl(x.income_quantity, 0) <> 0 then (nvl(x.income_extra_bonus, 0) / nvl(x.income_quantity, 0)) * 100 else 0 end;
      -- :NDB_DISC = GET_NDB_DISC (header discount DISC_VAL spread by value per basic unit)
      l_nr := ((nvl(x.income_quantity, 0) * nvl(x.vn_price, 0)) - nvl(x.det_disc, 0)) * nvl(l.currency_rate, 1);
      if nvl(l_nr, 0) = 0 or x.income_quantity is null or l.disc_val is null or x.vn_price is null or x.group_code is null
         or nvl(l_snr, 0) = 0 then
        l_ndb := 0;
      else
        l_ndb := nvl(l.disc_val, 0) * (nvl(l_nr, 0) / nvl(l_snr, 1)) / nvl(x.income_basic_qty, 1);
      end if;
      insert into st_trns_det
        (trns_type_code, trns_serial, item_serial, production_date, group_code, item_code, unit_code, quantity, unit_price,
         unit_price_curr, basic_qty, unit_cost, cost_flag, item_confg_id, store_code, bonus, extra_bonus, disc1_value, disc2_value,
         disc3_value, supp_disc_value, disc1_ratio, disc2_ratio, disc3_ratio, supp_disc_ratio, bonus_ratio, extra_bonus_ratio,
         trns_date, date_serial, delete_flag, det_disc, disc, tax_code1, tax_value1, tax_code2, tax_value2)
      values
        (p_type, l_serial, x.serial, x.production_date, x.group_code, x.item_code, x.unit_code, nvl(x.income_quantity, 0),
         nvl(x.vn_price * l.currency_rate, 0), nvl(x.vn_price, 0),
         nvl(x.income_quantity, 0) * nvl(l_factor, 1) + nvl(x.income_bonus, 0) * nvl(l_factor, 1) + nvl(x.income_extra_bonus, 0) * nvl(l_factor, 1),
         x.unit_cost, 1, l_confg, l.store_code, nvl(x.income_bonus, 0), nvl(x.income_extra_bonus, 0), nvl(x.disc1_value, 0),
         nvl(x.disc2_value, 0), nvl(x.disc3_value, 0), nvl(x.supp_disc_value, 0), nvl(x.disc1_ratio, 0), nvl(x.disc2_ratio, 0),
         nvl(x.disc3_ratio, 0), nvl(x.supp_disc_ratio, 0), l_br, l_ebr,
         p_date, l_dser, 0, nvl(x.det_disc, 0) * nvl(l.currency_rate, 1), l_ndb, x.tax_code1, x.tax_value1, x.tax_code2, x.tax_value2);
      begin
        insert into st_store_item (store_code, group_code, item_code, reorder_limit, max_limit, min_limit, reserved_qty)
        values (l.store_code, x.group_code, x.item_code, 0, 0, 0, 0);
      exception when others then
        null;
      end;
    end loop;
    for s in (select * from pr_income_lot_srvc where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial) loop
      insert into st_trns_services (trns_type_code, trns_serial, service_serial, service_code, service_cost, units_no,
                                    pr_trns_type_code, pr_trns_serial)
      values (p_type, l_serial, s.det_serial, s.service_code, s.unit_cost, s.income_quantity_srvc,
              l.order_trns_type_code, l.order_trns_serial);
    end loop;
    for e in (select * from pr_income_det_expens where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial) loop
      insert into st_trns_det_expens (trns_type_code, trns_serial, expens_serial, supplier_code, freight_val, customs_val, trnsport_val,
                                      insurance_val, commission_val, others_val, supp_trns_id, supp_trns_serial, doc_no, currency_rate, currency_code)
      values (p_type, l_serial, e.expens_serial, e.supplier_code, e.freight_val, e.customs_val, e.trnsport_val,
              e.insurance_val, e.commission_val, e.others_val, e.supp_trns_id, e.supp_trns_serial, e.doc_no, e.currency_rate, e.currency_code);
    end loop;
    update pr_income_lot set pu_trns_type_code = p_type, pu_trns_serial = l_serial, post_flag = 1
     where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial;
    return p_type || '/' || l_serial;
  end lot_create_trns;

  procedure lot_transfer_checks (l pr_income_lot%rowtype, p_pu_type out number) is
    n number;
  begin
    if lot_invoices(l, 1) > 0 or nvl(l.post_flag, 0) = 1 then
      err(-20155, 'الرسالة تم إستلامها بالفعل', 'The lot is already received');
    end if;
    if nvl(l.st_srv_asst_flag, 1) = 4 then
      err(-20155, 'رسائل الأصول تستلم من نظام الأصول', 'Asset lots are received by the fixed-assets system');
    end if;
    select max(pu_trns_type) into p_pu_type from st_trns_type where trns_type_code = l.trns_type_code;
    if p_pu_type is null then
      err(-20155, 'يجب التاكد من ربط الحركة مع حركة مشتريات', 'The transaction should be joined with purchase trans. type');
    end if;
    if l.arrival_date is null then err(-20155, 'يجب إدخال تاريخ الوصول الفعلى', 'The arrival date should be entered'); end if;
    if l.store_code is null then err(-20155, '!رقم المخزن غير موجود بالرسالة', 'Store code not found in lo'); end if;
    -- SUM_NET_VALUE (items) / SUM_QUANTITY_SRVC (services) are empty when the lot has no such lines
    if nvl(l.st_srv_asst_flag, 1) in (1, 2) then
      select count(*) into n from pr_income_lot_det where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial;
      if n = 0 then err(-20155, 'يجب إدخال أسعار البضاعة', 'you have to enter the transaction cost'); end if;
    end if;
    if nvl(l.st_srv_asst_flag, 1) in (2, 3) then
      select count(income_quantity_srvc) into n from pr_income_lot_srvc where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial;
      if n = 0 then err(-20155, 'يجب إدخال أسعار البضاعة', 'you have to enter the transaction cost'); end if;
    end if;
  end lot_transfer_checks;

  -- CHECK_TRNS
  procedure lot_check_trns (l pr_income_lot%rowtype) is
    n number;
  begin
    if nvl(l.st_srv_asst_flag, 1) in (1, 2) then
      select count(*) into n from pr_income_lot_det
       where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial and nvl(vn_price, 0) = 0 and nvl(income_quantity, 0) <> 0;
      if n > 0 then err(-20155, 'يجب ادخال السعر', 'Must Enter Price'); end if;
    end if;
    if nvl(l.st_srv_asst_flag, 1) = 2 then
      select count(*) into n from pr_income_lot_srvc
       where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial and nvl(unit_cost, 0) = 0;
      if n > 0 then err(-20155, 'يجب ادخال السعر', 'Must Enter Price'); end if;
    end if;
  end lot_check_trns;

  -- ST_POSTING (checks, CALC_UNIT_COST, UPDATE_COST, CHECK_TRNS) followed by the transfer-date window and BUT_OK (CREATE_TRNS)
  function lot_to_stores (p_rowid in varchar2, p_date in date) return varchar2 is
    l     pr_income_lot%rowtype;
    l_pu  number;
    l_doc varchar2(100);
  begin
    g_msg := null;
    begin
      select * into l from pr_income_lot where rowid = chartorowid(p_rowid) for update wait 10;
    exception when no_data_found then
      err(-20155, 'يجب حفظ السجلات اولا', 'YOU MUST SAVE THE CHANGES FIRST');
    end;
    if not update_right(30, 3, 4) then
      err(-20155, 'لا توجد صلاحية تعديل على الرسائل الواردة', 'No update right on incoming lots');
    end if;
    lot_transfer_checks(l, l_pu);
    if p_date is null then err(-20155, 'يجب إدخال تاريخ التحويل', 'The transfer date is required'); end if;
    if p_date < l.arrival_date then
      err(-20155, 'يجب ان يكون تاريخ التحويل اكبر من تاريخ الرسالة', 'Transfer Date Must Be Greater Than Lot Date');
    end if;
    app_rules_pr.set_bypass(true);
    lot_calc_costs(l);
    lot_check_trns(l);
    select * into l from pr_income_lot where rowid = chartorowid(p_rowid);
    l_doc := lot_create_trns(l, l_pu, p_date);
    app_rules_pr.set_bypass(false);
    g_msg := m('تم عمل حركة وارد لهذة الرسالة (' || l_doc || ')', 'An incoming trans. has been made for this lot (' || l_doc || ')');
    return null;
  exception when others then
    app_rules_pr.set_bypass(false);
    raise;
  end lot_to_stores;

  -- ST_UNPOSTING -> UN_CREATE_TRNS (legacy note: "this code have big error and neet to check")
  function lot_unpost (p_rowid in varchar2) return varchar2 is
    l      pr_income_lot%rowtype;
    l_n    number;
    l_fail number := 0;
    l_neg  number;
    l_bal  number;
    l_cnt  number;
  begin
    g_msg := null;
    begin
      select * into l from pr_income_lot where rowid = chartorowid(p_rowid) for update wait 10;
    exception when no_data_found then
      err(-20156, 'يجب حفظ السجلات اولا', 'YOU MUST SAVE THE CHANGES FIRST');
    end;
    if not update_right(30, 3, 4) then
      err(-20156, 'لا توجد صلاحية تعديل على الرسائل الواردة', 'No update right on incoming lots');
    end if;
    if nvl(l.post_flag, 0) <> 1 then err(-20156, 'الرسالة لم يتم إستلامها ', 'The lot is not received'); end if;
    if nvl(l.tot_trns, 0) = 1 then
      err(-20156, 'لايمكن الغاء ترحيل رسالة مجمعة من هذه الشاشة', 'Cannot Un Posting Collecting Trns');
    end if;
    if nvl(l.st_srv_asst_flag, 1) not in (1, 2, 3) then
      err(-20156, 'رسائل الأصول تلغى من نظام الأصول', 'Asset lots are cancelled by the fixed-assets system');
    end if;
    -- "SELECT DECODE(POST_FLAG, 1, 1, SUPP_POST_FLAG) INTO FAIL_DELETE FROM ST_TRNS_MAST WHERE INCOME_TRNS_* = the lot":
    -- ORA-01403 without invoice, ORA-01422 with more than one (also deleted ones) - the legacy stopped with that error
    l_n := lot_invoices(l, 0);
    if l_n = 0 then
      err(-20156, 'لا يمكن الغاء الترحيل: لا توجد حركة وارد لهذه الرسالة', 'Cannot cancel: no incoming transaction for this lot');
    elsif l_n > 1 then
      err(-20156, 'لا يمكن الغاء الترحيل: توجد أكثر من حركة وارد لهذه الرسالة', 'Cannot cancel: several incoming transactions for this lot');
    end if;
    select decode(nvl(post_flag, 0), 1, nvl(post_flag, 0), nvl(supp_post_flag, 0)) into l_fail
      from st_trns_mast where income_trns_type_code = l.trns_type_code and income_trns_serial = l.trns_serial;
    if nvl(l.st_srv_asst_flag, 1) in (1, 2) then
      for c in (select d.* from st_trns_det d
                 where (d.trns_type_code, d.trns_serial) in
                       (select trns_type_code, trns_serial from st_trns_mast
                         where income_trns_type_code = l.trns_type_code and income_trns_serial = l.trns_serial
                           and nvl(delete_flag, 0) = 0 and nvl(post_flag, 0) = 0 and nvl(supp_post_flag, 0) = 0)) loop
        -- legacy: FAIL_DELETE := 0 at the top of every line (only the last line counted); here every line counts
        select count(d.item_serial) into l_cnt
          from st_trns_det d, st_trns_mast mm
         where mm.trns_type_code = d.trns_type_code and mm.trns_serial = d.trns_serial
           and mm.store_code = c.store_code and d.group_code = c.group_code and d.item_code = c.item_code
           and nvl(mm.delete_flag, 0) = 0
           and ((mm.trns_date > c.trns_date) or (mm.trns_date = c.trns_date and mm.date_serial > c.date_serial)
                or (mm.trns_date = c.trns_date and mm.date_serial = c.date_serial and d.item_serial > c.item_serial));
        if l_cnt > 0 then
          l_bal := get_balance_confg(c.store_code, c.group_code, c.item_code, c.item_confg_id, c.trns_date, c.date_serial, c.item_serial);
          if update_next_trns_confg(c.store_code, c.group_code, c.item_code, c.item_confg_id, c.trns_date, c.date_serial,
                                    c.item_serial, l_bal) != 0 then
            l_fail := 1;
          end if;
        end if;
      end loop;
      select nvl(max(neg_sale_balance), 0) into l_neg from st_basic;
      if l_fail = 1 and l_neg = 0 then
        err(-20156, 'لا يمكن الغاء الترحيل للمخازن لوجود حركة صرف تمت على هذه الحركة او تم ترحيلها للحسابات والموردين',
            'Can''t unpost because of fail balance or posting to GL');
      end if;
    end if;
    app_rules_pr.set_bypass(true);
    delete st_trns_det_expens where (trns_type_code, trns_serial) in
      (select trns_type_code, trns_serial from st_trns_mast where income_trns_type_code = l.trns_type_code and income_trns_serial = l.trns_serial);
    delete st_trns_det_dues where (trns_type_code, trns_serial) in
      (select trns_type_code, trns_serial from st_trns_mast where income_trns_type_code = l.trns_type_code and income_trns_serial = l.trns_serial);
    delete st_trns_det where (trns_type_code, trns_serial) in
      (select trns_type_code, trns_serial from st_trns_mast where income_trns_type_code = l.trns_type_code and income_trns_serial = l.trns_serial);
    delete st_trns_services where (trns_type_code, trns_serial) in
      (select trns_type_code, trns_serial from st_trns_mast where income_trns_type_code = l.trns_type_code and income_trns_serial = l.trns_serial);
    delete st_trns_mast where income_trns_type_code = l.trns_type_code and income_trns_serial = l.trns_serial;
    update pr_income_lot set pu_trns_type_code = null, pu_trns_serial = null, vn_trns_id = null, vn_trns_serial = null, post_flag = 0
     where rowid = chartorowid(p_rowid);
    app_rules_pr.set_bypass(false);
    g_msg := m('تم إلغاء حركة الوارد لهذة الرسالة', 'The incoming trans. has been Deleted for this lot');
    return null;
  exception when others then
    app_rules_pr.set_bypass(false);
    raise;
  end lot_unpost;

  -- ITEM_INSERT: items of the purchase order still to be received (INSERT_ITEMS for item lots, INSERT_ITEMS2 + services for
  -- items + services lots, INSERT_ITEMS3 for service lots). "سيتم انزال جميع اصناف أمر الشراء يجب مراجعه الكميات قبل الحفظ"
  function lot_import_items (p_rowid in varchar2) return varchar2 is
    l       pr_income_lot%rowtype := lot_row(p_rowid);
    l_flag  number := nvl(l.st_srv_asst_flag, 1);
    l_n     number := 0;
    l_s     number := 0;
    l_cnt   number;
    l_qty_r number; l_bonus number; l_x3 number; l_x4 number;
    l_act   number; l_exp number; l_factor number; l_sales number; l_sdr number;
    l_rec   number; l_bon number; l_ext number;
    l_iq    number; l_ib number; l_ie number; l_dd number;
    l_serial number;
  begin
    g_msg := null;
    if lot_can(p_rowid, 'IMPORT') = 'N' then
      err(-20157, 'لا يمكن انزال الأصناف لهذه الرسالة', 'Items cannot be imported into this lot');
    end if;
    app_rules_pr.set_bypass(true);
    if l_flag in (1, 2) then
      select count(*) into l_cnt from pr_income_lot_det where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial;
      if l_flag = 1 or l_cnt = 0 then                 -- INSERT_ITEMS appends, INSERT_ITEMS2 only fills an empty block
        for r in (select d.serial, d.group_code, d.item_code, d.vn_price,
                         decode(nvl(st_d.store_serial, 0), 0, d.quantity, st_d.store_quantity) quantity,
                         d.unit_code, decode(nvl(st_d.store_serial, 0), 0, d.bonus, st_d.store_bonus) bonus,
                         decode(nvl(st_d.store_serial, 0), 0, d.extra_bonus, st_d.store_extra_bonus) extra_bonus,
                         d.det_disc, d.exp_unit_code, d.sl_trns_type_code, d.sl_trns_serial, d.notes,
                         d.disc1_value, d.disc2_value, d.disc3_value, d.disc1_ratio, d.disc2_ratio, d.disc3_ratio
                    from pr_order_det d, pr_order_store_det st_d
                   where d.trns_type_code = l.order_trns_type_code and d.trns_serial = l.order_trns_serial
                     and d.trns_type_code = st_d.trns_type_code(+) and d.trns_serial = st_d.trns_serial(+) and d.serial = st_d.serial(+)
                     and st_d.store_code(+) = l.store_code
                     and (d.trns_type_code, d.trns_serial, d.serial) not in
                         (select trns_type_code, trns_serial, serial from pr_order_store_det st_dd
                           where st_dd.trns_type_code = l.order_trns_type_code and st_dd.trns_serial = l.order_trns_serial
                             and st_dd.store_code != l.store_code
                          minus
                          select trns_type_code, trns_serial, serial from pr_order_store_det st_dd
                           where st_dd.trns_type_code = l.order_trns_type_code and st_dd.trns_serial = l.order_trns_serial
                             and st_dd.store_code = l.store_code)
                   order by d.serial) loop
          -- quantities already received in the lots of the order (INSERT_ITEMS selects INCOME_EXTRA_BONUS into V_DET_DISC and
          -- DET_DISC into V_EXTRA_BONUS: the legacy INTO list is in another order than the SELECT list - kept)
          select nvl(sum(nvl(d.income_quantity, 0)), 0), nvl(sum(nvl(d.income_bonus, 0)), 0),
                 nvl(sum(nvl(d.income_extra_bonus, 0)), 0), nvl(sum(nvl(d.det_disc, 0)), 0)
            into l_qty_r, l_bonus, l_x3, l_x4
            from pr_income_lot_det d, pr_income_lot mm
           where mm.trns_type_code = d.trns_type_code and mm.trns_serial = d.trns_serial
             and mm.order_trns_type_code = l.order_trns_type_code and mm.order_trns_serial = l.order_trns_serial
             and d.order_serial = r.serial;
          select count(*) into l_cnt from pr_income_lot_det
           where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial and serial = r.serial;
          if l_cnt > 0 then
            err(-20157, 'سطر أمر الشراء ' || r.serial || ' (الصنف ' || r.item_code || ') موجود بالرسالة',
                'Purchase-order line ' || r.serial || ' (item ' || r.item_code || ') is already in the lot');
          end if;
          begin
            select factor, retail_sale_price into l_factor, l_sales
              from st_item_unit where group_code = r.group_code and item_code = r.item_code and unit_code = r.unit_code;
          exception when no_data_found then
            l_factor := null; l_sales := null;
          end;
          begin
            select disc_ratio into l_sdr from st_item_confg
             where item_confg_id = (select max(item_confg_id) from st_item_confg where item_code = r.item_code and group_code = r.group_code);
          exception when others then
            l_sdr := nvl(r.disc1_ratio, 0);
          end;
          l_act := nvl(l_factor, 1);                   -- ACT_UNIT_CODE = UNIT_CODE = the order unit: both factors are equal
          l_exp := nvl(l_factor, 1);
          if nvl(r.exp_unit_code, 0) != 0 then
            l_rec := round(((nvl(r.quantity, 0) * l_act) / nvl(l_exp, 0)), 4);
            l_bon := round(((nvl(r.bonus, 0) * l_act) / nvl(l_exp, 0)), 4);
            l_ext := round(((nvl(r.extra_bonus, 0) * l_act) / nvl(l_exp, 0)), 4);
          else
            l_rec := r.quantity; l_bon := r.bonus; l_ext := r.extra_bonus;
          end if;
          l_iq := case when nvl(r.quantity, 0) - nvl(l_qty_r, 0) > 0 then l_rec - nvl(l_qty_r, 0) else 0 end;
          l_ib := case when nvl(r.bonus, 0) - nvl(l_bonus, 0) > 0 then l_bon - nvl(l_bonus, 0) else 0 end;
          if l_flag = 1 then
            l_ie := case when nvl(r.extra_bonus, 0) - nvl(l_x4, 0) > 0 then l_ext - nvl(l_x4, 0) else 0 end;
            l_dd := 0;                                 -- DET_DISC := order - received, then "IF NVL(:DET_DISC,0) != 0 THEN := 0"
          else
            l_ie := null;
            l_dd := r.det_disc - nvl(l_x4, 0);          -- INSERT_ITEMS2: the zeroing IF comes before the assignment
          end if;
          insert into pr_income_lot_det
            (trns_type_code, trns_serial, serial, order_serial, order_trns_type_code_det, order_trns_serial_det, group_code, item_code,
             unit_code, disc1_value, disc2_value, disc3_value, disc1_ratio, disc2_ratio, disc3_ratio, sales_price, sales_disc_ratio,
             vn_price, received_quantity, bonus, extra_bonus, income_quantity, income_bonus, income_extra_bonus, det_disc,
             sl_trns_type_code, sl_trns_serial, notes, arrival_date, store_code, income_basic_qty)
          values
            (l.trns_type_code, l.trns_serial, r.serial, r.serial, l.order_trns_type_code, l.order_trns_serial, r.group_code, r.item_code,
             r.unit_code,
             case when l_flag = 1 then r.disc1_value end, case when l_flag = 1 then r.disc2_value end, case when l_flag = 1 then r.disc3_value end,
             case when l_flag = 1 then r.disc1_ratio end, case when l_flag = 1 then r.disc2_ratio end, case when l_flag = 1 then r.disc3_ratio end,
             l_sales, case when l_flag = 1 then l_sdr end,
             case when l_flag = 1 then (r.vn_price / l_act) * l_exp else round((r.vn_price / l_act) * l_exp, 2) end,
             l_rec, l_bon, case when l_flag = 1 then l_ext end, l_iq, l_ib, l_ie, l_dd,
             r.sl_trns_type_code, r.sl_trns_serial, r.notes, l.arrival_date, l.store_code,
             (nvl(l_iq, 0) + nvl(l_ib, 0)) * nvl(l_factor, 1));
          l_n := l_n + 1;
        end loop;
      end if;
    end if;
    if l_flag in (2, 3) then
      select count(*) into l_cnt from pr_income_lot_srvc where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial;
      if l_cnt = 0 then                                -- INSERT_ITEMS3 / services part of INSERT_ITEMS2: empty block only
        for s in (select * from pr_order_srvc
                   where trns_type_code = l.order_trns_type_code and trns_serial = l.order_trns_serial
                     and get_income_service_qty(l.order_trns_type_code, l.order_trns_serial, det_serial) > 0
                   order by det_serial) loop
          select nvl(max(det_serial), 0) + 1 into l_serial from pr_income_lot_srvc
           where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial;
          insert into pr_income_lot_srvc (trns_type_code, trns_serial, det_serial, service_code, unit_code_srvc, received_quantity_srvc,
                                          unit_cost, income_quantity_srvc, order_det_serial, prcn_flag)
          values (l.trns_type_code, l.trns_serial, l_serial, s.service_code, s.unit_code_srvc, s.quantity, s.unit_cost,
                  get_income_service_qty(l.order_trns_type_code, l.order_trns_serial, s.det_serial), s.det_serial, nvl(s.prcn_flag, 0));
          l_s := l_s + 1;
        end loop;
      end if;
    end if;
    app_rules_pr.set_bypass(false);
    g_msg := m('سيتم انزال جميع اصناف أمر الشراء يجب مراجعه الكميات قبل الحفظ', 'All purchese order item will drag...check recive quantity')
             || ' (' || l_n || case when l_s > 0 then ' + ' || l_s end || ')';
    return null;
  exception when others then
    app_rules_pr.set_bypass(false);
    raise;
  end lot_import_items;

  -- =================================================================================== ST_RECEIVE_COST / ST_RETURN_COST(2)
  function st_row (p_rowid in varchar2) return st_trns_mast%rowtype is
    r st_trns_mast%rowtype;
  begin
    select * into r from st_trns_mast where rowid = chartorowid(p_rowid);
    return r;
  exception when others then
    return r;
  end st_row;

  -- ST_TRNS_MAST.KEY-DELREC: posted -> refused; every line: when a later movement of the item exists in the store, the running
  -- balance of the lot configuration without this line (GET_BALANCE_CONFG + UPDATE_NEXT_TRNS_CONFG) may not become negative;
  -- then DELETE_FLAG := 1 (lines flagged by ST_TRNS_MAST_UP). CLOSE_POSTED / CLOSE_ACC disable the delete of posted,
  -- cancelled and closed-period documents.
  function st_delete_check (p_rowid in varchar2) return varchar2 is
    h       st_trns_mast%rowtype := st_row(p_rowid);
    l_close date;
    l_cnt   number;
    l_bal   number;
    l_comp  number;
  begin
    if h.trns_type_code is null then return null; end if;
    if nvl(h.post_flag, 0) = 1 or nvl(h.supp_post_flag, 0) = 1 or nvl(h.cust_post_flag, 0) = 1 then
      return m('لا يمكن حذف حركات مرحلة', 'You cann''t delete Posted transactions');
    end if;
    if nvl(h.delete_flag, 0) = 1 then
      return m('لا يمكن تعديل حركة ملغاة', 'The transaction is already cancelled');
    end if;
    l_comp := comp;
    select max(close_date) into l_close from ac_basic where company_code = l_comp;
    if l_close is not null and h.trns_date <= l_close then
      return m('لا يمكن حذف حركة في فترة مقفلة', 'The transaction lies in a closed period');
    end if;
    for c in (select * from st_trns_det where trns_type_code = h.trns_type_code and trns_serial = h.trns_serial order by item_serial desc) loop
      select count(d.item_serial) into l_cnt
        from st_trns_det d, st_trns_mast mm
       where mm.trns_type_code = d.trns_type_code and mm.trns_serial = d.trns_serial
         and mm.store_code = h.store_code and d.group_code = c.group_code and d.item_code = c.item_code
         and nvl(mm.delete_flag, 0) = 0
         and ((mm.trns_date > h.trns_date) or (mm.trns_date = h.trns_date and mm.date_serial > h.date_serial)
              or (mm.trns_date = h.trns_date and mm.date_serial = h.date_serial and d.item_serial > c.item_serial));
      if l_cnt > 0 then
        l_bal := get_balance_confg(h.store_code, c.group_code, c.item_code, c.item_confg_id, h.trns_date, h.date_serial, c.item_serial);
        if update_next_trns_confg(h.store_code, c.group_code, c.item_code, c.item_confg_id, h.trns_date, h.date_serial,
                                  c.item_serial, l_bal) != 0 then
          return m('الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها.',
                   'Balance Not Enough, There Exist Next Trans. Conflicts With This Trans.') || ' (' || c.item_code || ')';
        end if;
      end if;
    end loop;
    return null;
  end st_delete_check;

  procedure st_after_soft_delete (p_rowid in varchar2) is
    h st_trns_mast%rowtype := st_row(p_rowid);
  begin
    if h.trns_type_code is null or nvl(h.delete_flag, 0) <> 1 then return; end if;
    if h.income_trns_type_code is not null and h.income_trns_serial is not null then
      app_rules_pr.set_bypass(true);
      update pr_income_lot set post_flag = 0, pu_trns_type_code = null, pu_trns_serial = null
       where trns_type_code = h.income_trns_type_code and trns_serial = h.income_trns_serial;
      app_rules_pr.set_bypass(false);
    end if;
  exception when others then
    app_rules_pr.set_bypass(false);
    raise;
  end st_after_soft_delete;

  -- TRNS_DATE WHEN-VALIDATE-ITEM: CUSTOM2_ALERT "تاريخ الحركة أكبر من تاريخ اليوم" (continue / cancel)
  function st_date_warning (p_rowid in varchar2, p_date in varchar2) return varchar2 is
    l_date date := dat(p_date);
    h st_trns_mast%rowtype;
  begin
    if l_date is null or trunc(l_date) <= trunc(sysdate) then return null; end if;
    if p_rowid is not null then
      h := st_row(p_rowid);
      if h.trns_date = l_date then return null; end if;
    end if;
    return m('تاريخ الحركة أكبر من تاريخ اليوم', 'Transaction Date is greater than today''s date');
  end st_date_warning;

  -- SUPPLIER_CODE WHEN-VALIDATE-ITEM: CUSTOM2_ALERT "الحركة بدون مورد" (continue / cancel)
  function st_supplier_warning (p_rowid in varchar2, p_supplier in varchar2) return varchar2 is
    h st_trns_mast%rowtype;
  begin
    if p_supplier is not null then return null; end if;
    if p_rowid is not null then
      h := st_row(p_rowid);
      if h.trns_type_code is not null and h.supplier_code is null then return null; end if;   -- not changed
    end if;
    return m('الحركة بدون مورد', 'Transaction Without Supplier');
  end st_supplier_warning;

  -- DOC_NO WHEN-VALIDATE-ITEM -> CHECK_DOC_NO, ST_BASIC.DOC_REPEAT = 3: "رقم المستند مكرر، هل تريد الإستمرار؟"
  -- (2 refuses: page validation of APP_RULES_PR). Invoices: types EFFECT 1 / TRNS_TYPE 1; returns: EFFECT 3.
  function st_doc_warning (p_form in varchar2, p_rowid in varchar2, p_type in varchar2, p_doc_no in varchar2) return varchar2 is
    l_doc  number := num(p_doc_no);
    l_type number := num(p_type);
    l_rep  number;
    l      number;
    h      st_trns_mast%rowtype;
  begin
    if l_doc is null then return null; end if;
    select max(nvl(doc_repeat, 0)) into l_rep from st_basic;
    if nvl(l_rep, 0) <> 3 then return null; end if;
    if p_rowid is not null then
      h := st_row(p_rowid);
      if h.doc_no = l_doc then return null; end if;
    end if;
    select count(1) into l
      from st_trns_mast tm, st_trns_type tt
     where tm.trns_type_code = tt.trns_type_code and tm.trns_type_code = l_type
       and ((p_form = 'RECEIVE' and nvl(tt.effect, 0) = 1 and nvl(tt.trns_type, 0) = 1)
            or (p_form in ('RETURN', 'RETURN2') and nvl(tt.effect, 0) = 3))
       and tm.doc_no = l_doc and nvl(tm.delete_flag, 0) = 0
       and (p_rowid is null or tm.rowid <> chartorowid(p_rowid));
    if l > 0 then
      return m('رقم المستند مكرر', 'The Document Number Is Repeated');
    end if;
    return null;
  end st_doc_warning;

  -- ST_TRNS_DET QUANTITY / BONUS / EXTRA_BONUS WHEN-VALIDATE-ITEM (message level 0): quantity above ST_STORE_ITEM.MAX_LIMIT
  function st_max_limit_info (p_rowid in varchar2) return varchar2 is
    h st_trns_mast%rowtype := st_row(p_rowid);
    l varchar2(4000);
    n pls_integer := 0;
  begin
    if h.trns_type_code is null then return null; end if;
    for r in (select d.item_code, d.quantity, d.bonus, d.extra_bonus, si.max_limit,
                     (select decode(app_sec.lang, 'en', nvl(u.name_e, u.name_a), u.name_a) from st_unit u where u.unit_code = d.unit_code) unit_name
                from st_trns_det d, st_store_item si
               where d.trns_type_code = h.trns_type_code and d.trns_serial = h.trns_serial
                 and si.store_code = h.store_code and si.group_code = d.group_code and si.item_code = d.item_code
                 and nvl(si.max_limit, 0) <> 0
                 and nvl(d.bonus, 0) + nvl(d.quantity, 0) + nvl(d.extra_bonus, 0) > si.max_limit
               order by d.item_serial) loop
      n := n + 1;
      exit when n > 20;
      l := l || case when l is not null then chr(10) end || r.item_code || ': '
           || m('!!رصيد الصنف سوف يزيد عن الحـد الأقصي', 'Item Balance Will Be More Than Max Limit!!') || ' - '
           || m('الحد الأقصى هو  = ', 'Max Limit is = ') || r.max_limit || ' ' || r.unit_name;
    end loop;
    return l;
  end st_max_limit_info;

  -- POST_BUT: ST_POSTING_CPOSTING opened for this document (POST_ON_LINE, FILTER 1 post / 2 cancel), CHECK_FILE_PREV(45, 2)
  function st_can (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    h st_trns_mast%rowtype := st_row(p_rowid);
    l_posted boolean;
  begin
    if h.trns_type_code is null or nvl(h.delete_flag, 0) = 1 or not right_(30, 45) then return 'N'; end if;
    l_posted := nvl(h.post_flag, 0) = 1 or nvl(h.cust_post_flag, 0) = 1 or nvl(h.supp_post_flag, 0) = 1;
    return yn((p_what = 'POST' and not l_posted) or (p_what = 'UNPOST' and l_posted));
  end st_can;

  function st_post (p_rowid in varchar2, p_gl in number, p_ap in number) return varchar2 is
    h st_trns_mast%rowtype := st_row(p_rowid);
  begin
    g_msg := null;
    if h.trns_type_code is null then err(-20158, 'لابد من حفظ السجل أولاً', 'THE DATA MUST BE SAVED BEFORE RUN THR Authorize'); end if;
    if not right_(30, 45) then err(-20158, 'غـيـر مسـمـوح لك بالدخــول على هذه الـشـاشــة', 'YOU ARE NOT ALLOWED TO ENTER THIS SCREEN'); end if;
    app_proc_st.post_cancel(p_mode => 1, p_from_date => h.trns_date, p_to_date => h.trns_date,
                            p_from_type => h.trns_type_code, p_to_type => h.trns_type_code,
                            p_from_serial => h.trns_serial, p_to_serial => h.trns_serial,
                            p_gl => nvl(p_gl, 0), p_ar => 0, p_ap => nvl(p_ap, 0),
                            p_company_code => comp, p_user_code => usr, p_password_number => pw);
    g_msg := m('تمت عملية الترحيل', 'Posting completed') || ' (' || m('الحسابات ', 'GL ') || app_proc_st.last_gl_count
             || ' - ' || m('الموردين ', 'AP ') || app_proc_st.last_ap_count || ')';
    return null;
  end st_post;

  function st_unpost (p_rowid in varchar2, p_gl in number, p_ap in number, p_grouped in number) return varchar2 is
    h st_trns_mast%rowtype := st_row(p_rowid);
  begin
    g_msg := null;
    if h.trns_type_code is null then err(-20158, 'لابد من حفظ السجل أولاً', 'THE DATA MUST BE SAVED BEFORE RUN THR Authorize'); end if;
    if not right_(30, 45) then err(-20158, 'غـيـر مسـمـوح لك بالدخــول على هذه الـشـاشــة', 'YOU ARE NOT ALLOWED TO ENTER THIS SCREEN'); end if;
    app_proc_st.post_cancel(p_mode => 2, p_from_date => h.trns_date, p_to_date => h.trns_date,
                            p_from_type => h.trns_type_code, p_to_type => h.trns_type_code,
                            p_from_serial => h.trns_serial, p_to_serial => h.trns_serial,
                            p_gl => nvl(p_gl, 0), p_ar => 0, p_ap => nvl(p_ap, 0), p_allow_grouped => nvl(p_grouped, 0),
                            p_company_code => comp, p_user_code => usr, p_password_number => pw);
    g_msg := m('تمت عملية إلغاء الترحيل', 'Cancel posting completed') || ' (' || m('الحسابات ', 'GL ') || app_proc_st.last_gl_count
             || ' - ' || m('الموردين ', 'AP ') || app_proc_st.last_ap_count || ')';
    return null;
  end st_unpost;

  -- =================================================================================== PR_QUOT_TRNS / PR_MR
  function rfq_row (p_rowid in varchar2) return pr_req_mast%rowtype is
    r pr_req_mast%rowtype;
  begin
    select * into r from pr_req_mast where rowid = chartorowid(p_rowid);
    return r;
  exception when others then
    return r;
  end rfq_row;

  function quot_on_po (r pr_req_mast%rowtype, p_supplier number) return boolean is
    l number;
  begin
    select count(*) into l from pr_order_det
     where quot_trns_type_code = r.trns_type_code and quot_trns_serial = r.trns_serial and quot_supplier_id = p_supplier;
    return l > 0;
  end quot_on_po;

  function quot_can (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    r   pr_req_mast%rowtype := rfq_row(p_rowid);
    l_a number; l_q number; l_free number := 0;
  begin
    if r.trns_type_code is null then return 'N'; end if;
    select count(case when nvl(accept_flag, 0) = 1 then 1 end), count(case when nvl(quot_flag, 0) = 1 then 1 end)
      into l_a, l_q from pr_quot_mast where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    for s in (select supplier_id from pr_quot_mast where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial
                 and nvl(accept_flag, 0) = 1) loop
      if not quot_on_po(r, s.supplier_id) then l_free := l_free + 1; end if;
    end loop;
    return yn(case p_what when 'LOWEST' then l_a = 0 and l_q > 0
                          when 'MAKE_PO' then l_free > 0
                          when 'DELETE_PO' then l_a > 0
                          else false end);
  end quot_can;

  -- GET_LOWEST_PRICE: total per replying, not accepted supplier = SUM(price x rate x RFQ quantity - line discount x rate)
  -- - supplier discount x rate (work table PR_TEMP); exactly one lowest -> accepted, DATE_SEND, request status 3
  function quot_lowest_price (p_rowid in varchar2) return varchar2 is
    r      pr_req_mast%rowtype := rfq_row(p_rowid);
    l_n    number;
    l_min  number;
    l_cnt  number := 0;
    l_supp number;
    l_name varchar2(400);
    type t_val is table of number index by pls_integer;
    l_vals t_val;
    l_ids  t_val;
    l_k    pls_integer := 0;
  begin
    g_msg := null;
    if r.trns_type_code is null then err(-20159, 'يجب حفظ السجلات اولا', 'You must save the changes first'); end if;
    select count(1) into l_n from pr_quot_mast qm
     where qm.trns_type_code = r.trns_type_code and qm.trns_serial = r.trns_serial and nvl(qm.accept_flag, 0) = 1;
    if l_n > 0 then err(-20159, 'هناك عرض تم الموافقة علية من قبل', 'The were an quotation is already accepted '); end if;
    select count(1) into l_n from pr_quot_mast qm
     where qm.trns_type_code = r.trns_type_code and qm.trns_serial = r.trns_serial and nvl(qm.quot_flag, 0) = 1;
    if l_n = 0 then err(-20159, ' لم يتم الرد ', 'No Supplier Replay '); end if;
    for s in (select sp.code, qm.disc_val, qm.currency_rate
                from pr_quot_mast qm, supplier sp
               where qm.trns_type_code = r.trns_type_code and qm.trns_serial = r.trns_serial and qm.supplier_id = sp.code
                 and nvl(qm.quot_flag, 0) = 1 and nvl(qm.accept_flag, 0) = 0
               order by sp.code) loop
      l_k := l_k + 1;
      l_ids(l_k) := s.code;
      select sum((qd.unit_price * s.currency_rate) * nvl(rd.quantity, 0) - nvl(qd.det_disc * s.currency_rate, 0))
             - nvl(s.disc_val * s.currency_rate, 0)
        into l_vals(l_k)
        from pr_quot_det qd, pr_req_det rd
       where rd.trns_type_code = qd.trns_type_code and rd.trns_serial = qd.trns_serial and rd.req_det_serial = qd.req_det_serial
         and qd.trns_type_code = r.trns_type_code and qd.trns_serial = r.trns_serial and qd.supplier_id = s.code;
    end loop;
    for i in 1 .. l_k loop
      if l_vals(i) is not null and (l_min is null or l_vals(i) < l_min) then l_min := l_vals(i); end if;
    end loop;
    for i in 1 .. l_k loop
      if l_vals(i) = l_min then l_cnt := l_cnt + 1; l_supp := l_ids(i); end if;
    end loop;
    if l_cnt > 1 then
      err(-20159, 'هناك اكثر من عرض لديهم اقل سعر لا يمكن الاختيار الآلى فى هذه الحالة ',
          'There were more than quotation have the lowest price you have to choose which one is suitable');
    end if;
    if l_cnt = 0 then err(-20159, ' لم يتم الرد ', 'No Supplier Replay '); end if;
    select decode(app_sec.lang, 'en', nvl(name_e, name_a), name_a) into l_name from supplier where code = l_supp;
    update pr_quot_mast set accept_flag = 1, date_send = nvl(date_send, sysdate)
     where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and supplier_id = l_supp;
    update pr_req_mast set req_status = 3 where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    g_msg := m(' أقل عرض سعر مقدم بقيمة ' || fmt(l_min) || ' للمورد ' || l_name,
               ' the lowest price Coming With Value ' || fmt(l_min) || ' To Supplier ' || l_name);
    return null;
  end quot_lowest_price;

  -- DISTRIBUTE_DISC (PR_QUOT_TRNS): the supplier discount spread over the priced lines by value (DISC per unit)
  procedure quot_distribute_disc (p_type number, p_serial number, p_supplier number, p_disc number) is
    l_sum number;
  begin
    if nvl(p_disc, 0) = 0 then return; end if;
    select sum((rd.quantity * qd.unit_price) - qd.det_disc) into l_sum
      from pr_quot_det qd, pr_req_det rd
     where qd.trns_type_code = rd.trns_type_code and qd.trns_serial = rd.trns_serial and qd.req_det_serial = rd.req_det_serial
       and qd.trns_type_code = p_type and qd.trns_serial = p_serial and qd.supplier_id = p_supplier and qd.unit_price is not null;
    if nvl(l_sum, 0) = 0 then return; end if;
    for r in (select ((rd.quantity * qd.unit_price) - qd.det_disc) tot_line, qd.req_det_serial, rd.quantity
                from pr_quot_det qd, pr_req_det rd
               where qd.trns_type_code = rd.trns_type_code and qd.trns_serial = rd.trns_serial and qd.req_det_serial = rd.req_det_serial
                 and qd.trns_type_code = p_type and qd.trns_serial = p_serial and qd.supplier_id = p_supplier
                 and qd.unit_price is not null) loop
      update pr_quot_det set disc = p_disc * r.tot_line / (l_sum * nvl(nullif(r.quantity, 0), 1))
       where trns_type_code = p_type and trns_serial = p_serial and supplier_id = p_supplier and req_det_serial = r.req_det_serial;
    end loop;
  end quot_distribute_disc;

  -- "تكوين أمر الشراء": one purchase order per accepted supplier with the priced lines of the quotation
  function quot_make_po (p_rowid in varchar2) return varchar2 is
    r      pr_req_mast%rowtype := rfq_row(p_rowid);
    l_po   number;
    l_ser  number;
    l_req  number;
    l_max  number;
    l_n    number;
    l_done number := 0;
    l_list varchar2(4000);
  begin
    g_msg := null;
    if r.trns_type_code is null then err(-20160, 'يجب حفظ السجلات اولا', 'You must save the changes first'); end if;
    select count(1) into l_n from pr_quot_mast where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and nvl(accept_flag, 0) = 1;
    if l_n = 0 then
      err(-20160, 'لم يتم الموافقة على العرض - يجب الموافقة اولا ثم حفظ السجل', 'There are no accepted Quotation');
    end if;
    select max(pr_trns_type) into l_po from st_trns_type where trns_type_code = r.trns_type_code;
    if l_po is null then
      err(-20160, 'يجب ربط طلب عروض الأسعار بحركة أمر شراء في ملف الحركات!!!', 'You Must Join Price Proposal Request With Purch. Order!!!');
    end if;
    select max(requisition_type) into l_req from pr_order_request where trns_type_code = r.pr_trns_type_code and trns_serial = r.pr_trns_serial;
    app_rules_pr.set_bypass(true);
    for pq in (select * from pr_quot_mast where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial
                  and nvl(accept_flag, 0) = 1 order by supplier_id) loop
      if quot_on_po(r, pq.supplier_id) then
        err(-20160, ' الحركة الحالية تم عمل أمر شراء لها بالفعل ', 'The current quotation have related purchase order ');
      end if;
      if pq.date_send is null then
        err(-20160, ' يجب إدخال تاريخ أمر الشراء الخاصة بالعرض المقبول', 'Purchase Order date must be entered first');
      end if;
      select count(1) into l_n from pr_quot_det
       where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and supplier_id = pq.supplier_id and unit_price is not null;
      if l_n = 0 then err(-20160, 'لم يتم تحديد اي سعر للأصناف تم إيقاف أمر الشراء', 'No Price For Any Item'); end if;
      quot_distribute_disc(r.trns_type_code, r.trns_serial, pq.supplier_id, pq.disc_val);
      select nvl(max(nvl(trns_serial, 0)), 0) + 1 into l_ser from pr_order where trns_type_code = l_po;
      insert into pr_order (trns_type_code, trns_serial, pr_order_date, currency_code, currency_rate, supplier_code, supp_quot_no,
                            disc_val, requisition_type)
      values (l_po, l_ser, pq.date_send, pq.currency_code, pq.currency_rate, pq.supplier_id, pq.quot_no, pq.disc_val, l_req);
      select nvl(max(nvl(serial, 0)), 0) into l_max from pr_order_det where trns_type_code = l_po and trns_serial = l_ser;
      insert into pr_order_det (trns_type_code, trns_serial, serial, pr_order_date, group_code, item_code, unit_code, quantity, vn_price,
                                qty_status, req_serial, req_date, expct_arrival_dt, quot_trns_type_code, quot_trns_serial, quot_item_serial,
                                quot_supplier_id, bonus, det_disc, disc)
      select l_po, l_ser, rd.req_det_serial + nvl(l_max, 0), pq.date_send, rd.item_group_code, rd.item_code, rd.unit_code, rd.quantity,
             qd.unit_price, 1, rd.req_det_serial, pq.date_send, qd.exp_arrv_date, qd.trns_type_code, qd.trns_serial, qd.req_det_serial,
             qd.supplier_id, qd.bonus, qd.det_disc, qd.disc
        from pr_quot_det qd, pr_req_det rd
       where qd.trns_type_code = rd.trns_type_code and qd.trns_serial = rd.trns_serial and qd.req_det_serial = rd.req_det_serial
         and qd.trns_type_code = r.trns_type_code and qd.trns_serial = r.trns_serial and qd.supplier_id = pq.supplier_id
         and qd.unit_price is not null;
      update pr_order set arrival_date = (select max(expct_arrival_dt) from pr_order_det where trns_type_code = l_po and trns_serial = l_ser)
       where trns_type_code = l_po and trns_serial = l_ser;
      update pr_req_mast set req_status = 4 where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      l_done := l_done + 1;
      l_list := l_list || case when l_list is not null then ', ' end || l_po || '/' || l_ser;
    end loop;
    app_rules_pr.set_bypass(false);
    g_msg := m('تم تحويل عرض الاسعار إلى أمر شراء', 'Price List has been transfered to a parchase order') || ' (' || l_list || ')';
    return null;
  exception when others then
    app_rules_pr.set_bypass(false);
    raise;
  end quot_make_po;

  -- delete-PO button: accepted supplier -> purchase order found by the quotation link; confirmed order refused; its quotation
  -- lines deleted, the order deleted when empty, the acceptance withdrawn (ACCEPT_FLAG, DATE_SEND) and the request back to 2
  function quot_delete_po (p_rowid in varchar2, p_supplier in number) return varchar2 is
    r      pr_req_mast%rowtype := rfq_row(p_rowid);
    l_n    number;
    l_type number;
    l_ser  number;
    l_conf number;
  begin
    g_msg := null;
    if r.trns_type_code is null then err(-20161, 'يجب حفظ السجلات اولا', 'You must save the changes first'); end if;
    select count(*) into l_n from pr_quot_mast
     where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and supplier_id = p_supplier and nvl(accept_flag, 0) = 1;
    if l_n = 0 then err(-20161, 'لم يتم الموافقة على العرض - يجب الموافقة اولا ثم حفظ السجل', 'There are no accepted Quotation'); end if;
    select max(trns_type_code), max(trns_serial) into l_type, l_ser from pr_order_det
     where quot_trns_type_code = r.trns_type_code and quot_trns_serial = r.trns_serial and quot_supplier_id = p_supplier;
    if l_type is null then
      update pr_quot_mast set accept_flag = null
       where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and supplier_id = p_supplier and nvl(accept_flag, 0) = 1;
      update pr_req_mast set req_status = 2 where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      g_msg := m('الحركة لم يتم عمل لها أمر شراء - تم الغاء الموافقة', 'The current quotation have No related purchase order ');
      return null;
    end if;
    select nvl(max(confirm_flag), 0) into l_conf from pr_order where trns_type_code = l_type and trns_serial = l_ser;
    if l_conf = 1 then err(-20161, 'لا يمكن حذف أمر الشراء حيث أنه معتمد', 'You can''t delete the current purchase order due to relation when others transaction'); end if;
    app_rules_pr.set_bypass(true);
    begin
      delete from pr_order_det where quot_trns_type_code = r.trns_type_code and quot_trns_serial = r.trns_serial and quot_supplier_id = p_supplier;
      select count(1) into l_n from pr_order_det where trns_type_code = l_type and trns_serial = l_ser;
      if l_n = 0 then
        delete from pr_order where trns_type_code = l_type and trns_serial = l_ser;
      end if;
    exception when others then
      if sqlcode between -20199 and -20100 then raise; end if;
      err(-20161, 'لا يمكن حذف امر الشراء لوجود حركات معتمده عليه لا يمكن حذفها',
          'You can''t delete the current purchase order due to relation when others transaction');
    end;
    update pr_quot_mast set accept_flag = null, date_send = null
     where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and supplier_id = p_supplier and nvl(accept_flag, 0) = 1;
    update pr_req_mast set req_status = 2 where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    app_rules_pr.set_bypass(false);
    g_msg := m(' تم حذف أمر الشراء ', 'Materials request has been Delete ');
    return null;
  exception when others then
    app_rules_pr.set_bypass(false);
    raise;
  end quot_delete_po;

  -- PR_MR KEY-DELREC: an RFQ with suppliers cannot be deleted ("توجد موردين مرتبطة بالعرض يجب حذف الموردين أولا").  Runs after the
  -- generated delete (DELETE request): the committed state is read with a flashback query.
  procedure rfq_after_delete (p_type in varchar2, p_serial in varchar2) is
    l   number;
    l_t number := num(p_type);
    l_s number := num(p_serial);
  begin
    begin
      select count(*) into l from pr_quot_mast as of timestamp systimestamp
       where trns_type_code = l_t and trns_serial = l_s;
    exception when others then
      l := 0;
    end;
    if l > 0 then
      err(-20162, 'توجد موردين مرتبطة بالعرض يجب حذف الموردين أولا', 'Suppliers are linked to the request: delete the suppliers first');
    end if;
  end rfq_after_delete;

  -- =================================================================================== ST_PRUCHASE_REQUEST
  -- CHK_OUTSTANDING_QTY: ordered in all purchase orders - received in all incoming lots, per item of the request
  function prq_outstanding (p_rowid in varchar2) return varchar2 is
    l   varchar2(4000);
    n   pls_integer := 0;
    q   number;
  begin
    for r in (select distinct d.group_code, d.item_code from pr_order_request h, pr_order_det_request d
               where h.rowid = chartorowid(p_rowid) and d.trns_type_code = h.trns_type_code and d.trns_serial = h.trns_serial
               order by d.item_code) loop
      select (select nvl(sum(quantity), 0) from pr_order_det where group_code = r.group_code and item_code = r.item_code)
             - (select nvl(sum(nvl(d.income_quantity, 0)), 0) from pr_income_lot_det d, pr_income_lot mm
                 where d.trns_type_code = mm.trns_type_code and d.trns_serial = mm.trns_serial
                   and d.group_code = r.group_code and d.item_code = r.item_code)
        into q from dual;
      if q > 0 then
        n := n + 1;
        exit when n > 30;
        l := l || case when l is not null then chr(10) end
             || m(' هناك كمية ' || q || ' من الصنف ' || r.item_code || ' لم يتم إستلامها',
                  ' The quantity ' || q || ' from item No. ' || r.item_code || ' is outstanding');
      end if;
    end loop;
    return l;
  end prq_outstanding;

  -- line KEY-DELREC of ST_PRUCHASE_REQUEST: lines on a purchase order / an RFQ cannot be deleted (legacy messages instead of
  -- the FK error)
  procedure prq_line_delete (p_type in number, p_serial in number, p_item_serial in number) is
    l number;
  begin
    select count(*) into l from pr_order_det
     where req_trns_type_code = p_type and req_trns_serial = p_serial and req_item_serial = p_item_serial;
    if l > 0 then
      err(-20163, 'الحركة الحالية مرتبطة بحركة أمر شراء و لا يمكن الحذف', 'The current line is linked to a purchase order and cannot be deleted');
    end if;
    select count(*) into l from pr_req_det
     where pr_trns_type_code = p_type and pr_trns_serial = p_serial and pr_item_serial = p_item_serial;
    if l > 0 then
      err(-20163, 'الحركة الحالية مرتبطة بحركة طلب عرض أسعار و لا يمكن الحذف', 'The current line is linked to a request for quotation and cannot be deleted');
    end if;
  end prq_line_delete;

end app_act_pr;
/
show errors package body app_act_pr

-- ---------------------------------------------------------------------------------------------------
-- Delete hook (the rules mechanism has row rules for INSERT / UPDATE only): APEX sessions only.
-- ---------------------------------------------------------------------------------------------------
create or replace trigger app_act_pr_prq_det_bd
before delete on pr_order_det_request for each row
begin
  if v('APP_ID') is not null then
    app_act_pr.prq_line_delete(:old.trns_type_code, :old.trns_serial, :old.item_serial);
  end if;
end;
/
show errors trigger app_act_pr_prq_det_bd
