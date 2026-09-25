-- =====================================================================================================
-- APP_RULES3_TX : business rules and buttons of the tax screens (system 88), Stage C wave 3.
--   TX_STAT           tax statement (VAT return)       TX_TRNS_MAST / TX_TRNS_DET
--   TX_TAXES_TYPES    tax types                        TX_TAXES_TYPES (+ copy button over all TX_TAXES_* tables)
--   TX_ACCOUNTS       obligation per GL account        TX_TAXES_ACCOUNTS
--   TX_AS_CTGRY       obligation per asset category    TX_TAXES_AS_CTGRY
--   TX_ITEMS          obligation per item              TX_TAXES_ITEMS
--   TX_CUSTOMERS      obligation per customer          TX_TAXES_CUSTOMERS
--   TX_SUPPLIERS      obligation per supplier          TX_TAXES_SUPPLIERS
--   TX_AREAS          obligation per sales area        TX_TAXES_AREAS
--   TX_SERVICE        obligation per service           TX_TAXES_SERVICES
--   TX_FIXED_SERVICE, TX_BASIC: no PL/SQL (see their .md)
-- Evidence and decisions: app\legacy\processes\<FORM>.md.  Wiring: app\legacy\overrides\<FORM>.json:
--   row_rules    TX_TRNS_MAST -> stat_mast_row      TX_TRNS_DET -> stat_det_row
--                TX_TAXES_ITEMS -> items_row        TX_TAXES_ACCOUNTS -> accounts_row
--                TX_TAXES_CUSTOMERS / _SUPPLIERS / _AREAS / _AS_CTGRY / _SERVICES -> oblig_row
--   key_expr     TX_TRNS_DET.DET_SERIAL -> tx_trns_det_seq.nextval (as DB trigger TX_TRNS_DET_IN)
--                TX_TAXES_ACCOUNTS.ACC_SERIAL -> next_acc_serial (legacy: max + 1 over the table)
--   validations  stat_check (TX_STAT), types_check (TX_TAXES_TYPES)
--   actions      build_statement (TX_STAT "تكوين"), copy_tax (TX_TAXES_TYPES "نسخ بيانات نوع ضريبة سابقة"),
--                apply_accounts / apply_items / apply_customers / apply_suppliers / apply_areas /
--                apply_as_ctgry / apply_services (the "تطبيق" range buttons of the obligation screens)
--   info         stat_info (the totals and boxes of the statement)
--   delete hook  trigger APP_RULES3_TX_MAST_BD at the end of this file (legacy PRE-DELETE of TX_STAT).
-- Row rules check the legacy form of the current APEX page (APP_PAGE_MAP) so that other screens writing
-- the same tables (ST_ITEM, CUSTOMER ...) are not affected; the batch procedures set a bypass while they write.
-- No COMMIT (APEX commits the page).  Errors: raise_application_error(-20100..-20199), Arabic / English.
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_rules3_tx authid definer as

  -- ------------------------------------------------------------------ context
  function cur_form return varchar2;                                    -- legacy form of the current APEX page
  function msg (p_a in varchar2, p_e in varchar2) return varchar2;      -- Arabic / English by app_sec.lang
  procedure set_bypass (p_on in boolean);                               -- tests / batch writers

  -- ------------------------------------------------------------------ TX_STAT (tax statement)
  -- row rule TX_TRNS_MAST (inserting): TAX_NO / LEGAL_ADDRESS from COMPANY, FROM_DATE / TILL_DATE derived
  procedure stat_mast_row (p_company in number, p_tax in number, p_tax_no in out varchar2, p_legal in out varchar2,
                           p_from in out date, p_till in out date);
  -- page validation (CREATE, SAVE): returns the error text or null
  function stat_check (p_rowid in varchar2, p_request in varchar2, p_company in varchar2, p_tax in varchar2,
                       p_trns_date in varchar2) return varchar2;
  -- row rule TX_TRNS_DET: T_TAX_FLAG list of the legacy tab, AC_5 recomputes TRNS_VALUE (ENTRY lines)
  procedure stat_det_row (p_inserting in boolean, p_source in varchar2, p_sign in number, p_old_flag in number,
                          p_new_flag in number, p_old_ac5 in number, p_new_ac5 in number, p_tax_value in number,
                          p_trns_value in out number);
  -- action "تكوين": fills TX_TRNS_DET from GL entries, customer / supplier transactions, sales and purchases
  function build_statement (p_rowid in varchar2) return varchar2;
  -- info panel: one value of the statement (see the codes in the body)
  function stat_info (p_rowid in varchar2, p_code in varchar2) return varchar2;
  -- delete hook helpers (trigger APP_RULES3_TX_MAST_BD)
  procedure stat_delete_lines (p_company in number, p_tax in number, p_serial in number);
  procedure stat_check_last (p_company in number, p_tax in number, p_serial in number);

  -- ------------------------------------------------------------------ TX_TAXES_TYPES
  function types_check (p_rowid in varchar2, p_request in varchar2, p_tax_code in varchar2, p_name_a in varchar2,
                        p_db in varchar2, p_cr in varchar2, p_custom in varchar2, p_exp in varchar2,
                        p_trnsit in varchar2, p_adv in varchar2) return varchar2;
  function copy_tax (p_rowid in varchar2, p_src in number) return varchar2;

  -- ------------------------------------------------------------------ obligation screens
  function next_acc_serial return number;                              -- key_expr TX_TAXES_ACCOUNTS.ACC_SERIAL
  procedure items_row (p_inserting in boolean, p_group in number, p_item in varchar2, p_old_per in number,
                       p_per in out number);
  procedure accounts_row (p_account in number, p_cost1 in number, p_cost2 in number);
  -- p_kind: CUST | SUPP | AREA | ASCT | SRV; p_code2 = CTGRY_TYPE_ASCT for ASCT
  procedure oblig_row (p_kind in varchar2, p_inserting in boolean, p_code in number, p_code2 in number,
                       p_old_per in number, p_new_per in number);
  function apply_accounts (p_tax in number, p_from in number, p_to in number, p_cost1 in number, p_cost2 in number,
                           p_per in number) return varchar2;
  function apply_items (p_tax in number, p_from in number, p_to in number, p_per in number) return varchar2;
  function apply_customers (p_tax in number, p_from in number, p_to in number, p_per in number) return varchar2;
  function apply_suppliers (p_tax in number, p_from in number, p_to in number, p_per in number) return varchar2;
  function apply_areas (p_tax in number, p_from in number, p_to in number, p_per in number) return varchar2;
  function apply_as_ctgry (p_tax in number, p_from in number, p_to in number, p_per in number) return varchar2;
  function apply_services (p_tax in number, p_from in number, p_to in number, p_per in number) return varchar2;
  function last_message return varchar2;

end app_rules3_tx;
/
show errors package app_rules3_tx

create or replace package body app_rules3_tx as

  g_page    number := -1;
  g_form    varchar2(100);
  g_bypass  boolean := false;
  g_msg     varchar2(4000);

  -- ================================================================== helpers
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

  function msg (p_a in varchar2, p_e in varchar2) return varchar2 is
  begin
    return case when app_sec.lang = 'en' then nvl(p_e, p_a) else p_a end;
  end msg;

  procedure err (p_code in pls_integer, p_a in varchar2, p_e in varchar2) is
  begin
    raise_application_error(p_code, msg(p_a, p_e));
  end err;

  procedure set_bypass (p_on in boolean) is
  begin
    g_bypass := nvl(p_on, false);
  end set_bypass;

  function last_message return varchar2 is
  begin
    return g_msg;
  end last_message;

  function num (p in varchar2) return number is
  begin
    return to_number(p);
  exception when value_error or invalid_number then return null;
  end num;

  function dat (p in varchar2) return date is
  begin
    return to_date(p, 'DD/MM/YYYY');
  exception when others then return null;
  end dat;

  function grp return number is
  begin
    return nvl(num(v('G_PASSWORD_NUMBER')), 0);
  end grp;

  function comp return number is
  begin
    return num(v('G_COMPANY_CODE'));
  end comp;

  function fmt (p in number) return varchar2 is
  begin
    return to_char(nvl(p, 0), 'FM999G999G999G990D00');
  end fmt;

  -- "النسبة يجب أن تكون أكبر من الصفر" (TAX_PER / range percent of the obligation screens)
  procedure check_per (p_per in number) is
  begin
    if p_per is null or p_per <= 0 then
      err(-20110, 'النسبة يجب أن تكون أكبر من الصفر', 'The percentage must be greater than zero');
    end if;
  end check_per;

  procedure check_range (p_from in number, p_to in number, p_label_a in varchar2, p_label_e in varchar2) is
  begin
    if p_from is null or p_to is null then
      err(-20111, 'يجب إدخال ' || p_label_a, p_label_e || ' is required');
    end if;
  end check_range;

  procedure check_tax (p_tax in number) is
    l_n number;
  begin
    select count(*) into l_n from tx_taxes_types where tax_code = p_tax;
    if l_n = 0 then
      err(-20112, 'اختر رقم ضريبة مناسب', 'Choose a valid tax number');
    end if;
  end check_tax;

  -- ================================================================== TX_STAT
  procedure stat_mast_row (p_company in number, p_tax in number, p_tax_no in out varchar2, p_legal in out varchar2,
                           p_from in out date, p_till in out date) is
    l_period number;
  begin
    if g_bypass or nvl(cur_form, '#') != 'TX_STAT' then return; end if;
    -- COMP_LOV copied TAX_NO / LEGAL_ADDRESS from COMPANY (display items in the form)
    begin
      select tax_no, legal_address, tax_stat_period into p_tax_no, p_legal, l_period
        from company where company_code = p_company;
    exception when no_data_found then l_period := null;
    end;
    -- TAX_CODE WHEN-VALIDATE-ITEM: FROM = day after the last statement of the company / tax, else the tax start date;
    -- TILL = FROM + COMPANY.TAX_STAT_PERIOD months - 1 day (both display items in the form)
    select max(till_date) + 1 into p_from from tx_trns_mast where company_code = p_company and tax_code = p_tax;
    if p_from is null then
      select max(start_date) into p_from from tx_taxes_types where tax_code = p_tax;
    end if;
    p_till := case when p_from is not null and l_period is not null then add_months(p_from, l_period) - 1 end;
  end stat_mast_row;

  function stat_check (p_rowid in varchar2, p_request in varchar2, p_company in varchar2, p_tax in varchar2,
                       p_trns_date in varchar2) return varchar2 is
    l_m       tx_trns_mast%rowtype;
    l_period  number;
    l_start   date;
    l_prev    date;
    l_company number := num(p_company);
    l_tax     number := num(p_tax);
  begin
    if p_trns_date is null then
      return msg('يجب إدخال تاريخ الاقرار', 'The statement date is required');
    end if;
    if p_rowid is null then
      -- the derived period needs COMPANY.TAX_STAT_PERIOD and (first statement) TX_TAXES_TYPES.START_DATE
      begin
        select tax_stat_period into l_period from company where company_code = l_company;
      exception when no_data_found then l_period := null;
      end;
      if l_period is null then
        return msg('يجب تحديد فترة التقديم (بالشهور) للشركة في مؤشرات النظام', 'Define the statement period (months) of the company first');
      end if;
      select max(till_date) into l_prev from tx_trns_mast where company_code = l_company and tax_code = l_tax;
      select max(start_date) into l_start from tx_taxes_types where tax_code = l_tax;
      if l_prev is null and l_start is null then
        return msg('يجب تحديد بداية التطبيق لنوع الضريبة', 'Define the start date of the tax type first');
      end if;
      return null;
    end if;
    -- saved statement: company, tax and date are not updatable (UpdateAllowed = false in the form)
    begin
      select * into l_m from tx_trns_mast where rowid = chartorowid(p_rowid);
    exception when no_data_found then return null;
    end;
    if l_m.company_code != num(p_company) or l_m.tax_code != num(p_tax)
       or nvl(l_m.trns_date, date '1900-01-01') != nvl(dat(p_trns_date), date '1900-01-01') then
      return msg('لا يمكن تعديل الشركة أو الضريبة أو تاريخ الاقرار بعد الحفظ', 'Company, tax and statement date cannot be changed after saving');
    end if;
    return null;
  end stat_check;

  procedure stat_det_row (p_inserting in boolean, p_source in varchar2, p_sign in number, p_old_flag in number,
                          p_new_flag in number, p_old_ac5 in number, p_new_ac5 in number, p_tax_value in number,
                          p_trns_value in out number) is
    l_ok boolean;
  begin
    if g_bypass or nvl(cur_form, '#') != 'TX_STAT' then return; end if;
    -- T_TAX_FLAG: required list item; the values of each legacy tab
    if p_inserting or nvl(p_old_flag, -1) != nvl(p_new_flag, -1) then
      if p_new_flag is null then
        err(-20120, 'يجب إدخال مؤشر الضريبة', 'The tax indicator is required');
      end if;
      l_ok := case
                when p_source in ('CUST', 'SLS') then p_new_flag in (1, 2, 3, 4, 5, 0)
                when p_source in ('SUPP', 'PUR') then p_new_flag in (6, 7, 8, 9, 10, 0)
                when p_source = 'ENTRY' and p_sign = -1 then p_new_flag in (1, 2, 3, 4, 5, 0, 6)
                when p_source = 'ENTRY' then p_new_flag in (6, 7, 8, 9, 10, 0)
                else true
              end;
      if not l_ok then
        err(-20121, 'قيمة مؤشر الضريبة غير مسموحة لهذا النوع من السطور', 'This tax indicator is not allowed for this kind of line');
      end if;
    end if;
    -- AC_5 WHEN-CHECKBOX-CHANGED (ENTRY tabs): TRNS_VALUE = TAX_VALUE * 100 / 15, or TAX_VALUE * 20 when checked (5 %)
    if not p_inserting and p_source = 'ENTRY' and nvl(p_old_ac5, 0) != nvl(p_new_ac5, 0) then
      p_trns_value := case when nvl(p_new_ac5, 0) = 0 then p_tax_value * 100 / 15 else p_tax_value * 20 end;
    end if;
  end stat_det_row;

  function build_statement (p_rowid in varchar2) return varchar2 is
    m     tx_trns_mast%rowtype;
    l_db  number;
    l_cr  number;
    l_n   number;
  begin
    begin
      select * into m from tx_trns_mast where rowid = chartorowid(p_rowid);
    exception when others then
      err(-20130, 'يجب الحفظ اولا', 'Save the statement first');
    end;
    select count(1) into l_n from tx_trns_det
     where company_code = m.company_code and tax_code = m.tax_code and tax_serial = m.tax_serial;
    if l_n > 0 then
      err(-20131, 'توجد بيانات', 'Data Exist');
    end if;
    if m.from_date is null or m.till_date is null then
      -- legacy: nothing was done without the period
      err(-20132, 'يجب تحديد من تاريخ والى تاريخ للاقرار', 'The statement period (from / to date) is missing');
    end if;
    begin
      select db_account_no, cr_account_no into l_db, l_cr from tx_taxes_types where tax_code = m.tax_code;
    exception when no_data_found then null;
    end;
    g_bypass := true;
    -- ---------------------------------------------------------------- GL (tax accounts of other entries)
    insert into tx_trns_det (company_code, tax_code, tax_serial, det_serial, tax_value, trns_value, tax_source, tax_sign,
                             pk1, pk2, pk3, pk4, trns_date, t_tax_flag, invoice_no)
    select m.company_code, m.tax_code, m.tax_serial, tx_trns_det_seq.nextval, value, (value * 100) / 15, 'ENTRY', 1,
           mm.entry_year, mm.entry_type, mm.entry_no, s.seq, mm.entry_date, 6, s.cust_inv_no
      from ac_yearly_trn_det s, ac_yearly_trn mm
     where mm.entry_year = s.entry_year and mm.entry_type = s.entry_type and mm.entry_no = s.entry_no
       and nvl(mm.post_system, 0) not in (31, 30, 4, 5, 3)
       and s.account_number = l_db
       and mm.entry_date between m.from_date and m.till_date;

    insert into tx_trns_det (company_code, tax_code, tax_serial, det_serial, tax_value, trns_value, tax_source, tax_sign,
                             pk1, pk2, pk3, pk4, trns_date, t_tax_flag, invoice_no)
    select m.company_code, m.tax_code, m.tax_serial, tx_trns_det_seq.nextval, -1 * value, (-1 * value * 100) / 15, 'ENTRY', -1,
           mm.entry_year, mm.entry_type, mm.entry_no, s.seq, mm.entry_date, 6, s.cust_inv_no
      from ac_yearly_trn_det s, ac_yearly_trn mm
     where mm.entry_year = s.entry_year and mm.entry_type = s.entry_type and mm.entry_no = s.entry_no
       and nvl(mm.post_system, 0) not in (31, 30, 4, 5, 3)
       and s.account_number = l_cr
       and mm.entry_date between m.from_date and m.till_date;
    -- ---------------------------------------------------------------- AR (customer transactions not linked to stock)
    insert into tx_trns_det (company_code, tax_code, tax_serial, det_serial, tax_value, trns_value, tax_source, tax_sign,
                             pk1, pk2, pk3, pk4, trns_date, t_tax_flag, invoice_no)
    select m.company_code, m.tax_code, m.tax_serial, tx_trns_det_seq.nextval,
           nvl(s.tax_value1 * nvl(mm.currency_rate, 1), 0), nvl(s.inv_value * nvl(mm.currency_rate, 1), 0), 'CUST', 1,
           mm.trns_id, mm.trns_serial, mm.mainarea_id, mm.subarea_id, mm.trns_date,
           decode(nvl(s.tax_value1, 0), 0, 3, 1), s.bill_id2
      from ar_maintrns mm, ar_subtrns s
     where mm.trns_id = s.trns_id and mm.trns_serial = s.trns_serial
       and mm.mainarea_id = s.mainarea_id and mm.subarea_id = s.subarea_id
       and nvl(mm.link_flag, 0) = 0
       and mm.trns_id in (select id from ar_trnstype where effect = 0 and trns_type != 5 and trns_type != 4 and trns_type != 3)
       and mm.trns_date between m.from_date and m.till_date;

    insert into tx_trns_det (company_code, tax_code, tax_serial, det_serial, tax_value, trns_value, tax_source, tax_sign,
                             pk1, pk2, pk3, pk4, trns_date, t_tax_flag, invoice_no)
    select m.company_code, m.tax_code, m.tax_serial, tx_trns_det_seq.nextval,
           nvl(mm.tax_value1 * nvl(mm.currency_rate, 1), 0), nvl(mm.inv_value * nvl(mm.currency_rate, 1), 0), 'CUST', -1,
           mm.trns_id, mm.trns_serial, mm.mainarea_id, mm.subarea_id, mm.trns_date,
           decode(nvl(mm.tax_value1, 0), 0, 3, 1), mm.doc_no
      from ar_maintrns mm
     where nvl(mm.link_flag, 0) = 0
       and mm.trns_id in (select id from ar_trnstype where effect = 1 and trns_type != 5 and trns_type != 4 and trns_type != 3)
       and mm.trns_date between m.from_date and m.till_date
       and nvl(mm.inv_value, 0) != 0;
    -- ---------------------------------------------------------------- VN (supplier transactions not linked to stock)
    insert into tx_trns_det (company_code, tax_code, tax_serial, det_serial, tax_value, trns_value, tax_source, tax_sign,
                             pk1, pk2, trns_date, t_tax_flag, invoice_no)
    select m.company_code, m.tax_code, m.tax_serial, tx_trns_det_seq.nextval,
           nvl(s.tax_value1 * nvl(mm.currency_rate, 1), 0), nvl(s.inv_value * nvl(mm.currency_rate, 1), 0), 'SUPP', 1,
           mm.trns_id, mm.trns_serial, mm.trns_date,
           decode(nvl(s.tax_value1, 0), 0, 9, decode(nvl(tx.ext_supp_flag, 0), 0, 6, 7)), s.bill_id2
      from vn_maintrns mm, vn_subtrns s, tx_taxes_suppliers tx
     where mm.trns_id = s.trns_id and mm.trns_serial = s.trns_serial
       and nvl(mm.link_flag, 0) = 0
       and (nvl(s.tax_value1, 0) != 0 or nvl(mm.project_id, 0) != 0)
       and mm.trns_id in (select id from vn_trnstype where effect = 1)
       and mm.trns_date between m.from_date and m.till_date
       and nvl(s.inv_value, 0) != 0
       and mm.supplier_id = tx.supplier_code (+)
       and tx.tax_code = m.tax_code;

    insert into tx_trns_det (company_code, tax_code, tax_serial, det_serial, tax_value, trns_value, tax_source, tax_sign,
                             pk1, pk2, trns_date, t_tax_flag, invoice_no)
    select m.company_code, m.tax_code, m.tax_serial, tx_trns_det_seq.nextval,
           nvl(mm.tax_value1 * nvl(mm.currency_rate, 1), 0), nvl(mm.inv_value * nvl(mm.currency_rate, 1), 0), 'SUPP', -1,
           mm.trns_id, mm.trns_serial, mm.trns_date,
           decode(nvl(mm.tax_value1, 0), 0, 9, decode(nvl(tx.ext_supp_flag, 0), 0, 6, 7)), mm.doc_no
      from vn_maintrns mm, tx_taxes_suppliers tx
     where nvl(mm.link_flag, 0) = 0
       and (nvl(mm.tax_value1, 0) != 0 or nvl(mm.project_id, 0) != 0)
       and mm.trns_id in (select id from vn_trnstype where effect = 0)
       and mm.trns_date between m.from_date and m.till_date
       and nvl(mm.inv_value, 0) != 0
       and mm.supplier_id = tx.supplier_code (+)
       and tx.tax_code = m.tax_code;

    -- supplier debit notes: the tax account lines of VN_MAINTRNS_SUPP_ACC (legacy: base = tax * 100 / 5)
    insert into tx_trns_det (company_code, tax_code, tax_serial, det_serial, tax_value, trns_value, tax_source, tax_sign,
                             pk1, pk2, trns_date, t_tax_flag, invoice_no)
    select m.company_code, m.tax_code, m.tax_serial, tx_trns_det_seq.nextval,
           nvl(a.acc_val * nvl(mm.currency_rate, 1), 0), nvl(a.acc_val * 100 / 5 * nvl(mm.currency_rate, 1), 0), 'SUPP', -1,
           mm.trns_id, mm.trns_serial, mm.trns_date,
           decode(nvl(a.acc_val, 0), 0, 9, decode(nvl(tx.ext_supp_flag, 0), 0, 6, 7)), mm.doc_no
      from vn_maintrns mm, tx_taxes_suppliers tx, vn_maintrns_supp_acc a
     where nvl(mm.link_flag, 0) = 0
       and a.acc_number = (select db_account_no from tx_taxes_types where tax_code = m.tax_code)
       and mm.trns_id = a.trns_id and mm.trns_serial = a.trns_serial
       and mm.trns_id in (select id from vn_trnstype where effect = 0)
       and mm.trns_date between m.from_date and m.till_date
       and nvl(mm.inv_value, 0) != 0
       and mm.supplier_id = tx.supplier_code (+)
       and tx.tax_code = m.tax_code;
    -- ---------------------------------------------------------------- sales invoices (EFFECT 2 / TRNS_TYPE 2), per invoice and tax bucket
    insert into tx_trns_det (company_code, tax_code, tax_serial, det_serial, tax_value, trns_value, tax_source, tax_sign,
                             pk1, pk2, trns_date, t_tax_flag, invoice_no)
    select m.company_code, m.tax_code, m.tax_serial, tx_trns_det_seq.nextval,
           nvl(s.tax_value1 + decode(s.tax_value1, 0, 0, 1) * nvl(mm.tax_value1, 0) + nvl(get_service_tax(mm.trns_type_code, mm.trns_serial), 0), 0),
           nvl(s.items_total + (s.items_total / s_total.items_total) * (nvl(mm.trnsport_val, 0) - nvl(mm.tot_disc1_value, 0) - nvl(mm.tot_disc2_value, 0)
               - nvl(mm.tot_disc3_value, 0) - nvl(mm.tot_disc4_value, 0) - nvl(mm.tot_disc5_value, 0))
               + nvl(get_service_value(mm.trns_type_code, mm.trns_serial), 0), 0),
           'SLS', 1, mm.trns_type_code, mm.trns_serial, mm.trns_date, decode(s.tax_value1, 0, 3, 1), mm.doc_no
      from st_trns_mast mm,
           (select nvl(sum(d.tax_value1), 0) tax_value1,
                   nvl(sum((d.unit_price - nvl(d.disc1_value, 0) - nvl(d.disc2_value, 0) - nvl(d.disc3_value, 0) - nvl(d.disc4_value, 0)
                            - nvl(d.disc5_value, 0)) * d.quantity), 0) items_total,
                   d.trns_type_code, d.trns_serial
              from st_trns_det d, tx_taxes_items tx1
             where d.trns_type_code in (select trns_type_code from st_trns_type where effect = 2 and trns_type = 2)
               and d.trns_date between m.from_date and m.till_date
               and d.item_code = tx1.item_code (+) and d.group_code = tx1.group_code (+) and d.tax_code1 = tx1.tax_code (+)
             group by d.trns_type_code, d.trns_serial, decode(nvl(d.tax_value1, 0), 0, 0, 5)) s,
           (select nvl(sum((d.unit_price - nvl(d.disc1_value, 0) - nvl(d.disc2_value, 0) - nvl(d.disc3_value, 0) - nvl(d.disc4_value, 0)
                            - nvl(d.disc5_value, 0)) * d.quantity), 0) items_total,
                   d.trns_type_code, d.trns_serial
              from st_trns_det d
             where d.trns_type_code in (select trns_type_code from st_trns_type where effect = 2 and trns_type = 2)
               and d.trns_date between m.from_date and m.till_date
             group by d.trns_type_code, d.trns_serial
            having nvl(sum((d.unit_price - nvl(d.disc1_value, 0) - nvl(d.disc2_value, 0) - nvl(d.disc3_value, 0) - nvl(d.disc4_value, 0)
                            - nvl(d.disc5_value, 0)) * d.quantity), 0) != 0) s_total
     where mm.trns_type_code = s.trns_type_code and mm.trns_serial = s.trns_serial
       and mm.trns_type_code = s_total.trns_type_code and mm.trns_serial = s_total.trns_serial
       and nvl(mm.delete_flag, 0) = 0;
    -- ---------------------------------------------------------------- sales returns (EFFECT 4 / TRNS_TYPE 4)
    insert into tx_trns_det (company_code, tax_code, tax_serial, det_serial, tax_value, trns_value, tax_source, tax_sign,
                             pk1, pk2, trns_date, t_tax_flag, invoice_no)
    select m.company_code, m.tax_code, m.tax_serial, tx_trns_det_seq.nextval,
           nvl(s.tax_value1 + decode(s.tax_value1, 0, 0, 1) * nvl(mm.tax_value1, 0) + nvl(get_service_tax(mm.trns_type_code, mm.trns_serial), 0), 0),
           nvl(s.items_total + (s.items_total / s_total.items_total) * (nvl(mm.trnsport_val, 0) - nvl(mm.tot_disc1_value, 0) - nvl(mm.tot_disc2_value, 0)
               - nvl(mm.tot_disc3_value, 0) - nvl(mm.tot_disc4_value, 0) - nvl(mm.tot_disc5_value, 0))
               + nvl(get_service_value(mm.trns_type_code, mm.trns_serial), 0), 0),
           'SLS', -1, mm.trns_type_code, mm.trns_serial, mm.trns_date, decode(s.tax_value1, 0, 3, 1), mm.doc_no
      from st_trns_mast mm,
           (select nvl(sum(d.tax_value1), 0) tax_value1,
                   nvl(sum((d.unit_price - nvl(d.disc1_value, 0) - nvl(d.disc2_value, 0) - nvl(d.disc3_value, 0) - nvl(d.disc4_value, 0)
                            - nvl(d.disc5_value, 0)) * d.quantity), 0) items_total,
                   d.trns_type_code, d.trns_serial
              from st_trns_det d, tx_taxes_items tx1
             where d.trns_type_code in (select trns_type_code from st_trns_type where effect = 4 and trns_type = 4)
               and d.trns_date between m.from_date and m.till_date
               and d.item_code = tx1.item_code (+) and d.group_code = tx1.group_code (+) and d.tax_code1 = tx1.tax_code (+)
             group by d.trns_type_code, d.trns_serial, decode(nvl(d.tax_value1, 0), 0, 0, 5)) s,
           (select nvl(sum((d.unit_price - nvl(d.disc1_value, 0) - nvl(d.disc2_value, 0) - nvl(d.disc3_value, 0) - nvl(d.disc4_value, 0)
                            - nvl(d.disc5_value, 0)) * d.quantity), 0) items_total,
                   d.trns_type_code, d.trns_serial
              from st_trns_det d
             where d.trns_type_code in (select trns_type_code from st_trns_type where effect = 4 and trns_type = 4)
               and d.trns_date between m.from_date and m.till_date
             group by d.trns_type_code, d.trns_serial
            having nvl(sum((d.unit_price - nvl(d.disc1_value, 0) - nvl(d.disc2_value, 0) - nvl(d.disc3_value, 0) - nvl(d.disc4_value, 0)
                            - nvl(d.disc5_value, 0)) * d.quantity), 0) != 0) s_total
     where mm.trns_type_code = s.trns_type_code and mm.trns_serial = s.trns_serial
       and mm.trns_type_code = s_total.trns_type_code and mm.trns_serial = s_total.trns_serial
       and nvl(mm.delete_flag, 0) = 0;
    -- ---------------------------------------------------------------- purchases (EFFECT 1 / TRNS_TYPE 1)
    insert into tx_trns_det (company_code, tax_code, tax_serial, det_serial, tax_value, trns_value, tax_source, tax_sign,
                             pk1, pk2, trns_date, t_tax_flag, invoice_no)
    select m.company_code, m.tax_code, m.tax_serial, tx_trns_det_seq.nextval,
           nvl(s.tax_value1 + decode(s.tax_value1, 0, 0, 1) * nvl(mm.tax_value1, 0), 0),
           nvl(s.items_total + (s.items_total / decode(nvl(s_total.items_total, 0), 0, 1, nvl(s_total.items_total, 0)))
               * (nvl(mm.trnsport_val, 0) - nvl(mm.tot_disc1_value, 0) - nvl(mm.tot_disc2_value, 0) - nvl(mm.tot_disc3_value, 0)
                  - nvl(mm.tot_disc4_value, 0) - nvl(mm.tot_disc5_value, 0)), 0),
           'PUR', 1, mm.trns_type_code, mm.trns_serial, mm.trns_date,
           decode(s.tax_value1, 0, 9, decode(nvl(tx.ext_supp_flag, 0), 0, 6, 7)), mm.supplier_ref
      from st_trns_mast mm, tx_taxes_suppliers tx,
           (select nvl(sum(d.tax_value1), 0) tax_value1,
                   nvl(sum((d.unit_price - nvl(d.disc1_value, 0) - nvl(d.disc2_value, 0) - nvl(d.disc3_value, 0) - nvl(d.disc4_value, 0)
                            - nvl(d.disc5_value, 0)) * d.quantity), 0) items_total,
                   d.trns_type_code, d.trns_serial
              from st_trns_det d, tx_taxes_items tx1
             where d.trns_type_code in (select trns_type_code from st_trns_type where effect = 1 and trns_type = 1)
               and d.trns_date between m.from_date and m.till_date
               and d.item_code = tx1.item_code (+) and d.group_code = tx1.group_code (+) and d.tax_code1 = tx1.tax_code (+)
             group by d.trns_type_code, d.trns_serial, decode(nvl(d.tax_value1, 0), 0, 0, 5)) s,
           (select nvl(sum((d.unit_price - nvl(d.disc1_value, 0) - nvl(d.disc2_value, 0) - nvl(d.disc3_value, 0) - nvl(d.disc4_value, 0)
                            - nvl(d.disc5_value, 0)) * d.quantity), 0) items_total,
                   d.trns_type_code, d.trns_serial
              from st_trns_det d
             where d.trns_type_code in (select trns_type_code from st_trns_type where effect = 1 and trns_type = 1)
               and d.trns_date between m.from_date and m.till_date
             group by d.trns_type_code, d.trns_serial) s_total
     where mm.trns_type_code = s.trns_type_code and mm.trns_serial = s.trns_serial
       and mm.trns_type_code = s_total.trns_type_code and mm.trns_serial = s_total.trns_serial
       and nvl(mm.delete_flag, 0) = 0
       and mm.supplier_code = tx.supplier_code (+)
       and tx.tax_code (+) = m.tax_code;
    -- ---------------------------------------------------------------- purchase returns (EFFECT 3 / TRNS_TYPE 3)
    insert into tx_trns_det (company_code, tax_code, tax_serial, det_serial, tax_value, trns_value, tax_source, tax_sign,
                             pk1, pk2, trns_date, t_tax_flag, invoice_no)
    select m.company_code, m.tax_code, m.tax_serial, tx_trns_det_seq.nextval,
           nvl(s.tax_value1 + decode(s.tax_value1, 0, 0, 1) * nvl(mm.tax_value1, 0), 0),
           nvl(s.items_total + (s.items_total / decode(nvl(s_total.items_total, 0), 0, 1, nvl(s_total.items_total, 0)))
               * (nvl(mm.trnsport_val, 0) - nvl(mm.tot_disc1_value, 0) - nvl(mm.tot_disc2_value, 0) - nvl(mm.tot_disc3_value, 0)
                  - nvl(mm.tot_disc4_value, 0) - nvl(mm.tot_disc5_value, 0)), 0),
           'PUR', -1, mm.trns_type_code, mm.trns_serial, mm.trns_date,
           decode(s.tax_value1, 0, 9, decode(nvl(tx.ext_supp_flag, 0), 0, 6, 7)), mm.supplier_ref
      from st_trns_mast mm, tx_taxes_suppliers tx,
           (select nvl(sum(d.tax_value1), 0) tax_value1,
                   nvl(sum((d.unit_price - nvl(d.disc1_value, 0) - nvl(d.disc2_value, 0) - nvl(d.disc3_value, 0) - nvl(d.disc4_value, 0)
                            - nvl(d.disc5_value, 0)) * d.quantity), 0) items_total,
                   d.trns_type_code, d.trns_serial
              from st_trns_det d, tx_taxes_items tx1
             where d.trns_type_code in (select trns_type_code from st_trns_type where effect = 3 and trns_type = 3)
               and d.trns_date between m.from_date and m.till_date
               and d.item_code = tx1.item_code (+) and d.group_code = tx1.group_code (+) and d.tax_code1 = tx1.tax_code (+)
             group by d.trns_type_code, d.trns_serial, decode(nvl(d.tax_value1, 0), 0, 0, 5)) s,
           (select nvl(sum((d.unit_price - nvl(d.disc1_value, 0) - nvl(d.disc2_value, 0) - nvl(d.disc3_value, 0) - nvl(d.disc4_value, 0)
                            - nvl(d.disc5_value, 0)) * d.quantity), 0) items_total,
                   d.trns_type_code, d.trns_serial
              from st_trns_det d
             where d.trns_type_code in (select trns_type_code from st_trns_type where effect = 3 and trns_type = 3)
               and d.trns_date between m.from_date and m.till_date
             group by d.trns_type_code, d.trns_serial) s_total
     where mm.trns_type_code = s.trns_type_code and mm.trns_serial = s.trns_serial
       and mm.trns_type_code = s_total.trns_type_code and mm.trns_serial = s_total.trns_serial
       and nvl(mm.delete_flag, 0) = 0
       and mm.supplier_code = tx.supplier_code (+)
       and tx.tax_code (+) = m.tax_code;
    -- ---------------------------------------------------------------- lines without value are dropped
    delete tx_trns_det
     where trns_value = 0 and tax_value = 0
       and company_code = m.company_code and tax_code = m.tax_code and tax_serial = m.tax_serial;
    select count(*) into l_n from tx_trns_det
     where company_code = m.company_code and tax_code = m.tax_code and tax_serial = m.tax_serial;
    g_msg := msg('تم تكوين الاقرار: ' || l_n || ' سطر', 'Statement built: ' || l_n || ' lines');
    g_bypass := false;
    return p_rowid;
  exception when others then
    g_bypass := false;
    raise;
  end build_statement;

  function stat_info (p_rowid in varchar2, p_code in varchar2) return varchar2 is
    m       tx_trns_mast%rowtype;
    l_code  varchar2(30) := upper(p_code);
    l_b     number;
    l_t     number;
    l_x     number;
    l_db    number;
    l_cr    number;
    -- sales box b (1..5): SLS / CUST lines signed, plus the credit GL lines (ENTRY -1) of that indicator
    procedure box (p_box in number, p_trns out number, p_tax out number) is
    begin
      select nvl(sum(case when (p_box <= 5 and (tax_source in ('SLS', 'CUST') or (tax_source = 'ENTRY' and tax_sign = -1)))
                            or (p_box > 5 and (tax_source in ('PUR', 'SUPP') or (tax_source = 'ENTRY' and tax_sign = 1)))
                          then case when tax_source = 'ENTRY' then 1 else nvl(tax_sign, 1) end * trns_value end), 0),
             nvl(sum(case when (p_box <= 5 and (tax_source in ('SLS', 'CUST') or (tax_source = 'ENTRY' and tax_sign = -1)))
                            or (p_box > 5 and (tax_source in ('PUR', 'SUPP') or (tax_source = 'ENTRY' and tax_sign = 1)))
                          then case when tax_source = 'ENTRY' then 1 else nvl(tax_sign, 1) end * tax_value end), 0)
        into p_trns, p_tax
        from tx_trns_det
       where company_code = m.company_code and tax_code = m.tax_code and tax_serial = m.tax_serial and t_tax_flag = p_box;
    end box;
    function src_tax (p_src in varchar2) return number is
      l number;
    begin
      select nvl(sum(tax_value * case when tax_sign = -1 then -1 else 1 end), 0) into l
        from tx_trns_det
       where company_code = m.company_code and tax_code = m.tax_code and tax_serial = m.tax_serial and tax_source = p_src;
      return l;
    end src_tax;
    function sales_tax return number is
      a number; b number;
    begin
      box(1, a, b);
      return b;
    end sales_tax;
    function purch_tax return number is
      a number; b number; c number; d number;
    begin
      box(6, a, b); box(7, c, d);
      return b + d;
    end purch_tax;
    -- "إظهار البيانات": sales / purchases and their returns by rate bucket 0 / 5 / 15
    procedure bucket (p_side in varchar2, p_ret in boolean, p_rate in number, p_trns out number, p_tax out number) is
      l_ret number := case when p_ret then 1 else 0 end;
    begin
      select nvl(sum(trns_value * case when l_ret = 1 then case when tax_sign = 1 then 0 else tax_sign end
                                       else case when tax_sign = 1 then 1 else 0 end end), 0),
             nvl(sum(tax_value * case when l_ret = 1 then case when tax_sign = 1 then 0 else tax_sign end
                                      else case when tax_sign = 1 then 1 else 0 end end), 0)
        into p_trns, p_tax
        from tx_trns_det
       where company_code = m.company_code and tax_code = m.tax_code and tax_serial = m.tax_serial
         and ((p_side = 'S' and tax_source in ('SLS', 'CUST')) or (p_side = 'P' and tax_source in ('PUR', 'SUPP', 'ENTRY')))
         and case
               when p_rate = 0 then case when nvl(tax_value, 0) = 0 then 1 else 0 end
               when p_rate = 5 then case when 100 * nvl(tax_value, 0) / decode(nvl(trns_value, 0), 0, 1, nvl(trns_value, 0)) between 0.1 and 10 then 1 else 0 end
               else case when 100 * nvl(tax_value, 0) / decode(nvl(trns_value, 0), 0, 1, nvl(trns_value, 0)) > 10 or nvl(trns_value, 0) = 0 then 1 else 0 end
             end = 1;
    end bucket;
  begin
    begin
      select * into m from tx_trns_mast where rowid = chartorowid(p_rowid);
    exception when others then return null;
    end;
    if regexp_like(l_code, '^B([0-9]+)$') then                          -- box 1..10: value / tax
      box(to_number(substr(l_code, 2)), l_b, l_t);
      return fmt(l_b) || '  /  ' || fmt(l_t);
    elsif l_code = 'SALES' then                                          -- TOTAL_TRNS_SALES / TOTAL_TAX_SALES (= box 1 tax)
      l_x := 0;
      for i in 1 .. 5 loop box(i, l_b, l_t); l_x := l_x + l_b; end loop;
      return fmt(l_x) || '  /  ' || fmt(sales_tax);
    elsif l_code = 'PURCH' then                                          -- TOTAL_TRNS_PU / TOTAL_TAX_PU (= boxes 6 + 7 tax)
      l_x := 0;
      for i in 6 .. 10 loop box(i, l_b, l_t); l_x := l_x + l_b; end loop;
      return fmt(l_x) || '  /  ' || fmt(purch_tax);
    elsif l_code = 'DUE' then                                            -- TOTAL_TAX
      return fmt(sales_tax - purch_tax);
    elsif l_code = 'NET' then                                            -- ITEM206 = TOTAL_TAX + TAX_CORR + PRE_TAX
      return fmt(sales_tax - purch_tax + nvl(m.tax_corr, 0) + nvl(m.pre_tax, 0));
    elsif l_code in ('CUST', 'SUPP', 'SLS', 'PUR') then                  -- per-tab totals (P - N)
      return fmt(src_tax(l_code));
    elsif l_code = 'ENTRY' then                                          -- TOTAL_TAX_ENTRY = ENTRY_N - ENTRY_P
      return fmt(-src_tax('ENTRY'));
    elsif l_code = 'DET' then                                            -- TOTAL_DET_TAX
      return fmt(src_tax('CUST') - src_tax('SUPP') + src_tax('SLS') - src_tax('PUR') - src_tax('ENTRY'));
    elsif l_code = 'GL' then                                             -- TOTAL_TAX_GL: -(credits of CR account) - (DB account) in the period
      begin
        select db_account_no, cr_account_no into l_db, l_cr from tx_taxes_types where tax_code = m.tax_code;
      exception when no_data_found then null;
      end;
      select nvl(sum(case when account_number = l_cr then -value else 0 end), 0)
             - nvl(sum(case when account_number = l_db then value else 0 end), 0)
        into l_x
        from ac_yearly_trn_det
       where account_number in (l_db, l_cr) and entry_date between m.from_date and m.till_date;
      return fmt(l_x);
    elsif regexp_like(l_code, '^(S|RS|P|RP)(0|5|15)$') then             -- EXECUT buckets
      bucket(case when l_code like '%S%' then 'S' else 'P' end, l_code like 'R%',
             to_number(regexp_substr(l_code, '[0-9]+$')), l_b, l_t);
      return fmt(l_b) || '  /  ' || fmt(l_t);
    end if;
    return null;
  end stat_info;

  procedure stat_delete_lines (p_company in number, p_tax in number, p_serial in number) is
  begin
    delete from tx_trns_det where company_code = p_company and tax_code = p_tax and tax_serial = p_serial;
  end stat_delete_lines;

  procedure stat_check_last (p_company in number, p_tax in number, p_serial in number) is
    l_n number;
  begin
    -- PRE-DELETE: only the last statement of the company / tax may be deleted
    select count(*) into l_n from tx_trns_mast where company_code = p_company and tax_code = p_tax and tax_serial > p_serial;
    if l_n > 0 then
      err(-20133, 'يجب حذف اخر اقرار اولا', 'Delete the last statement first');
    end if;
  end stat_check_last;

  -- ================================================================== TX_TAXES_TYPES
  function account_ok (p_acc in number) return boolean is
    l_n number;
    l_g number := grp;
    l_c number := comp;
  begin
    -- account LOV of the form: posting accounts (ACCOUNT_STATUS = 1) allowed for the user group
    select count(*) into l_n from ac_master a
     where a.account_number = p_acc and a.account_status = 1
       and (l_g = 0 or l_c is null
            or a.account_number in (select p2.account_number from ac_password_master p2
                                     where p2.password_number = l_g and p2.company_code = l_c));
    return l_n > 0;
  end account_ok;

  function types_check (p_rowid in varchar2, p_request in varchar2, p_tax_code in varchar2, p_name_a in varchar2,
                        p_db in varchar2, p_cr in varchar2, p_custom in varchar2, p_exp in varchar2,
                        p_trnsit in varchar2, p_adv in varchar2) return varchar2 is
    l_n    number;
    l_code number := num(p_tax_code);
    type t_acc is table of varchar2(100);
    l_acc  t_acc := t_acc(p_db, p_cr, p_custom, p_exp, p_trnsit, p_adv);
  begin
    if trim(p_name_a) is null then
      return msg('يجب إدخال الإسم', 'The name is required');
    end if;
    if p_rowid is null and p_tax_code is not null then
      select count(*) into l_n from tx_taxes_types where tax_code = l_code;
      if l_n > 0 then
        return msg('رقم مكرر تم إدخالة من قبل', 'This number already exists');
      end if;
    end if;
    for i in 1 .. l_acc.count loop
      if l_acc(i) is not null and not account_ok(num(l_acc(i))) then
        return msg('رقم الحساب ' || l_acc(i) || ' غير موجود في أرقام الحسابات (حساب فرعي)',
                   'Account ' || l_acc(i) || ' is not a posting account of the chart of accounts');
      end if;
    end loop;
    return null;
  end types_check;

  function copy_tax (p_rowid in varchar2, p_src in number) return varchar2 is
    l_tax  number;
    l_per  number;
    l_n    number;
    l_ser  number;
  begin
    begin
      select tax_code, init_tax_prcn into l_tax, l_per from tx_taxes_types where rowid = chartorowid(p_rowid);
    exception when others then
      err(-20140, 'يجب الحفظ أولا', 'Save first');
    end;
    if p_src is null or p_src = l_tax then
      err(-20141, 'اختر رقم ضريبة مناسب', 'Choose a suitable tax number');
    end if;
    select count(*) into l_n from tx_taxes_types where tax_code = p_src;
    if l_n = 0 then
      err(-20141, 'اختر رقم ضريبة مناسب', 'Choose a suitable tax number');
    end if;
    if nvl(l_per, 0) = 0 then
      err(-20142, 'أدخل نسبة الضريبة أولا', 'Enter the tax percentage first');
    end if;
    g_bypass := true;
    -- rows with a percentage get the new percentage (INIT_TAX_PRCN); zero-rated items stay 0
    insert into tx_taxes_items (tax_code, tax_per, group_code, item_code)
    select l_tax, l_per, group_code, item_code from tx_taxes_items where tax_code = p_src and nvl(tax_per, 0) > 0;
    insert into tx_taxes_items (tax_code, tax_per, group_code, item_code)
    select l_tax, 0, group_code, item_code from tx_taxes_items where tax_code = p_src and nvl(tax_per, 0) = 0;
    insert into tx_taxes_suppliers (tax_code, tax_per, supplier_code, tax_no, ext_supp_flag)
    select l_tax, l_per, supplier_code, tax_no, ext_supp_flag from tx_taxes_suppliers where tax_code = p_src and nvl(tax_per, 0) > 0;
    insert into tx_taxes_customers (tax_code, tax_per, customer_code, tax_no)
    select l_tax, l_per, customer_code, tax_no from tx_taxes_customers where tax_code = p_src and nvl(tax_per, 0) > 0;
    for r in (select account_number, cost_code, cost_code2 from tx_taxes_accounts
               where tax_code = p_src and nvl(tax_per, 0) > 0 order by acc_serial) loop
      select nvl(max(acc_serial), 0) + 1 into l_ser from tx_taxes_accounts where tax_code = l_tax;
      insert into tx_taxes_accounts (tax_code, account_number, cost_code, cost_code2, tax_per, acc_serial)
      values (l_tax, r.account_number, r.cost_code, r.cost_code2, l_per, l_ser);
    end loop;
    insert into tx_taxes_areas (tax_code, mainarea_id, tax_per)
    select l_tax, mainarea_id, l_per from tx_taxes_areas where tax_code = p_src and nvl(tax_per, 0) > 0;
    insert into tx_taxes_as_ctgry (tax_code, tax_per, ctgry_type_asct, ctgry_cd_asct)
    select l_tax, l_per, ctgry_type_asct, ctgry_cd_asct from tx_taxes_as_ctgry where tax_code = p_src and nvl(tax_per, 0) > 0;
    insert into tx_taxes_services (tax_code, tax_per, service_code)
    select l_tax, l_per, service_code from tx_taxes_services where tax_code = p_src and nvl(tax_per, 0) > 0;
    insert into tx_taxes_es_actvts (tax_code, tax_per, activity_code)
    select l_tax, l_per, activity_code from tx_taxes_es_actvts where tax_code = p_src and nvl(tax_per, 0) > 0;
    insert into tx_taxes_es_customer (tax_code, tax_no, customer_code)
    select l_tax, tax_no, customer_code from tx_taxes_es_customer where tax_code = p_src;
    insert into tx_taxes_fixed_srv (tax_code, transport_tax_per)
    select l_tax, l_per from tx_taxes_fixed_srv where tax_code = p_src and nvl(transport_tax_per, 0) > 0;
    g_bypass := false;
    g_msg := msg('تم نسخ بيانات الضريبة', 'Tax data copied');
    return null;
  exception
    when dup_val_on_index then
      g_bypass := false;
      err(-20143, 'رقم مكرر تم إدخالة من قبل', 'Some of the copied rows already exist for this tax');
    when others then
      g_bypass := false;
      raise;
  end copy_tax;

  -- ================================================================== obligation screens
  function next_acc_serial return number is
    l number;
  begin
    select nvl(max(acc_serial), 0) + 1 into l from tx_taxes_accounts;
    return l;
  end next_acc_serial;

  procedure items_row (p_inserting in boolean, p_group in number, p_item in varchar2, p_old_per in number,
                       p_per in out number) is
    l_vat  number;
    l_n    number;
    l_g    number;
  begin
    if g_bypass or nvl(cur_form, '#') != 'TX_ITEMS' then return; end if;
    l_g := grp;
    -- item LOV: active item of the chosen group (ST_ITEM.STOP_FLAG = 0), group allowed for the user group
    select count(*), max(vat_value) into l_n, l_vat from st_item
     where item_group_code = p_group and item_code = p_item and nvl(stop_flag, 0) = 0
       and (l_g = 0 or item_group_code in (select group_code from st_group_password where password_number = l_g));
    if l_n = 0 then
      err(-20150, 'الصنف غير موجود في المجموعة أو موقوف', 'The item does not belong to the group or is stopped');
    end if;
    -- item validation filled the percentage from ST_ITEM.VAT_VALUE
    if p_inserting and p_per is null then
      p_per := l_vat;
    end if;
    if p_inserting or nvl(p_old_per, -1) != nvl(p_per, -1) then
      check_per(p_per);
    end if;
  end items_row;

  procedure accounts_row (p_account in number, p_cost1 in number, p_cost2 in number) is
    l_n number;
  begin
    if g_bypass or nvl(cur_form, '#') != 'TX_ACCOUNTS' then return; end if;
    -- LOVs of the form: ACCOUNT_STATUS = 1, COST_STATUS = 1
    select count(*) into l_n from ac_master where account_number = p_account and account_status = 1;
    if l_n = 0 then
      err(-20151, 'خطأ :رقم الحساب ليس حساب فرعى', 'The account is not a posting account');
    end if;
    if p_cost1 is not null then
      select count(*) into l_n from ac_cost_centers where cost_code = p_cost1 and cost_status = 1;
      if l_n = 0 then
        err(-20152, 'مركز التكلفة 1 غير موجود', 'Cost centre 1 does not exist or is not active');
      end if;
    end if;
    if p_cost2 is not null then
      select count(*) into l_n from ac_cost_centers2 where cost_code = p_cost2 and cost_status = 1;
      if l_n = 0 then
        err(-20153, 'مركز التكلفة 2 غير موجود', 'Cost centre 2 does not exist or is not active');
      end if;
    end if;
  end accounts_row;

  procedure oblig_row (p_kind in varchar2, p_inserting in boolean, p_code in number, p_code2 in number,
                       p_old_per in number, p_new_per in number) is
    l_n    number;
    l_form varchar2(30) := case p_kind when 'CUST' then 'TX_CUSTOMERS' when 'SUPP' then 'TX_SUPPLIERS' when 'AREA' then 'TX_AREAS'
                                       when 'ASCT' then 'TX_AS_CTGRY' when 'SRV' then 'TX_SERVICE' end;
  begin
    if g_bypass or nvl(cur_form, '#') != l_form then return; end if;
    -- the code comes from the form's list (no declared foreign key)
    if p_kind = 'AREA' then
      select count(*) into l_n from ar_mainarea where id = p_code;
      if l_n = 0 then err(-20154, 'رقم المنطقة غير موجود', 'The area does not exist'); end if;
    elsif p_kind = 'ASCT' then
      select count(*) into l_n from as_ctgry where ctgry_type_asct = p_code2 and ctgry_cd_asct = p_code and nvl(leaf, 0) = 1;
      if l_n = 0 then err(-20155, 'نوع الأصل غير موجود', 'The asset category does not exist'); end if;
    elsif p_kind = 'SRV' then
      select count(*) into l_n from st_pd_services where service_code = p_code;
      if l_n = 0 then err(-20156, 'رقم الخدمة غير موجود', 'The service does not exist'); end if;
    end if;
    if p_inserting or nvl(p_old_per, -1) != nvl(p_new_per, -1) then
      check_per(p_new_per);
    end if;
  end oblig_row;

  -- "تطبيق" of TX_ACCOUNTS: every posting account of the range, with the chosen cost centres, gets the percentage
  function apply_accounts (p_tax in number, p_from in number, p_to in number, p_cost1 in number, p_cost2 in number,
                           p_per in number) return varchar2 is
    l_n   number;
    l_cnt number := 0;
    l_ser number;
  begin
    check_tax(p_tax);
    check_range(p_from, p_to, 'من حساب / إلى حساب', 'From / to account');
    check_per(p_per);
    g_bypass := true;
    for a in (select account_number from ac_master where account_number between p_from and p_to and account_status = 1
               order by account_number) loop
      select count(1) into l_n from tx_taxes_accounts
       where account_number = a.account_number and nvl(cost_code, 0) = nvl(p_cost1, 0) and nvl(cost_code2, 0) = nvl(p_cost2, 0)
         and tax_code = p_tax;
      if l_n > 0 then
        update tx_taxes_accounts set tax_per = p_per
         where account_number = a.account_number and nvl(cost_code, 0) = nvl(p_cost1, 0) and nvl(cost_code2, 0) = nvl(p_cost2, 0)
           and tax_code = p_tax;
      else
        l_ser := next_acc_serial;
        insert into tx_taxes_accounts (tax_code, account_number, cost_code, cost_code2, tax_per, acc_serial)
        values (p_tax, a.account_number, p_cost1, p_cost2, p_per, l_ser);
      end if;
      l_cnt := l_cnt + 1;
    end loop;
    g_bypass := false;
    g_msg := msg('تم التطبيق على ' || l_cnt || ' حساب', 'Applied to ' || l_cnt || ' accounts');
    return null;
  exception when others then
    g_bypass := false;
    raise;
  end apply_accounts;

  -- "تطبيق" of TX_ITEMS: the items of the group range are replaced; the item's own VAT_VALUE wins over the percentage
  function apply_items (p_tax in number, p_from in number, p_to in number, p_per in number) return varchar2 is
    l_cnt number;
  begin
    check_tax(p_tax);
    check_range(p_from, p_to, 'من مجموعة / إلى مجموعة', 'From / to group');
    check_per(p_per);
    g_bypass := true;
    delete from tx_taxes_items where group_code between p_from and p_to and tax_code = p_tax;
    insert into tx_taxes_items (tax_code, group_code, item_code, tax_per)
    select p_tax, item_group_code, item_code, nvl(vat_value, p_per) from st_item where item_group_code between p_from and p_to;
    l_cnt := sql%rowcount;
    g_bypass := false;
    g_msg := msg('تم التطبيق على ' || l_cnt || ' صنف', 'Applied to ' || l_cnt || ' items');
    return null;
  exception when others then
    g_bypass := false;
    raise;
  end apply_items;

  -- customers / suppliers / areas: insert, or update the percentage of an existing row
  function apply_codes (p_kind in varchar2, p_tax in number, p_from in number, p_to in number, p_per in number) return varchar2 is
    l_cnt number := 0;
    type t_codes is table of number;
    l_codes t_codes;
  begin
    check_tax(p_tax);
    check_per(p_per);
    if p_kind = 'CUST' then
      check_range(p_from, p_to, 'من عميل / إلى عميل', 'From / to customer');
      select code bulk collect into l_codes from customer where code between p_from and p_to order by code;
    elsif p_kind = 'SUPP' then
      check_range(p_from, p_to, 'من مورد / إلى مورد', 'From / to supplier');
      select code bulk collect into l_codes from supplier where code between p_from and p_to order by code;
    else
      check_range(p_from, p_to, 'من منطقة / إلى منطقة', 'From / to area');
      select id bulk collect into l_codes from ar_mainarea where id between p_from and p_to order by id;
    end if;
    g_bypass := true;
    for i in 1 .. l_codes.count loop
      if p_kind = 'CUST' then
        update tx_taxes_customers set tax_per = p_per where tax_code = p_tax and customer_code = l_codes(i);
        if sql%rowcount = 0 then
          insert into tx_taxes_customers (tax_code, customer_code, tax_per) values (p_tax, l_codes(i), p_per);
        end if;
      elsif p_kind = 'SUPP' then
        update tx_taxes_suppliers set tax_per = p_per where tax_code = p_tax and supplier_code = l_codes(i);
        if sql%rowcount = 0 then
          insert into tx_taxes_suppliers (tax_code, supplier_code, tax_per) values (p_tax, l_codes(i), p_per);
        end if;
      else
        update tx_taxes_areas set tax_per = p_per where tax_code = p_tax and mainarea_id = l_codes(i);
        if sql%rowcount = 0 then
          insert into tx_taxes_areas (tax_code, mainarea_id, tax_per) values (p_tax, l_codes(i), p_per);
        end if;
      end if;
      l_cnt := l_cnt + 1;
    end loop;
    g_bypass := false;
    g_msg := msg('تم التطبيق على ' || l_cnt || ' سجل', 'Applied to ' || l_cnt || ' rows');
    return null;
  exception when others then
    g_bypass := false;
    raise;
  end apply_codes;

  function apply_customers (p_tax in number, p_from in number, p_to in number, p_per in number) return varchar2 is
  begin
    return apply_codes('CUST', p_tax, p_from, p_to, p_per);
  end apply_customers;

  function apply_suppliers (p_tax in number, p_from in number, p_to in number, p_per in number) return varchar2 is
  begin
    return apply_codes('SUPP', p_tax, p_from, p_to, p_per);
  end apply_suppliers;

  function apply_areas (p_tax in number, p_from in number, p_to in number, p_per in number) return varchar2 is
  begin
    return apply_codes('AREA', p_tax, p_from, p_to, p_per);
  end apply_areas;

  -- "تطبيق" of TX_AS_CTGRY: the asset categories of the range are replaced
  function apply_as_ctgry (p_tax in number, p_from in number, p_to in number, p_per in number) return varchar2 is
    l_cnt number;
  begin
    check_tax(p_tax);
    check_range(p_from, p_to, 'من نوع اصل / إلى نوع اصل', 'From / to asset category');
    check_per(p_per);
    g_bypass := true;
    delete from tx_taxes_as_ctgry where ctgry_cd_asct between p_from and p_to and tax_code = p_tax;
    insert into tx_taxes_as_ctgry (tax_code, ctgry_cd_asct, ctgry_type_asct, tax_per)
    select p_tax, ctgry_cd_asct, ctgry_type_asct, p_per from as_ctgry where ctgry_cd_asct between p_from and p_to;
    l_cnt := sql%rowcount;
    g_bypass := false;
    g_msg := msg('تم التطبيق على ' || l_cnt || ' سجل', 'Applied to ' || l_cnt || ' rows');
    return null;
  exception when others then
    g_bypass := false;
    raise;
  end apply_as_ctgry;

  -- "تطبيق" of TX_SERVICE: the services of the range are replaced
  function apply_services (p_tax in number, p_from in number, p_to in number, p_per in number) return varchar2 is
    l_cnt number;
  begin
    check_tax(p_tax);
    check_range(p_from, p_to, 'من خدمة / إلى خدمة', 'From / to service');
    check_per(p_per);
    g_bypass := true;
    delete from tx_taxes_services where service_code between p_from and p_to and tax_code = p_tax;
    insert into tx_taxes_services (tax_code, service_code, tax_per)
    select p_tax, service_code, p_per from st_pd_services where service_code between p_from and p_to;
    l_cnt := sql%rowcount;
    g_bypass := false;
    g_msg := msg('تم التطبيق على ' || l_cnt || ' خدمة', 'Applied to ' || l_cnt || ' services');
    return null;
  exception when others then
    g_bypass := false;
    raise;
  end apply_services;

end app_rules3_tx;
/
show errors package body app_rules3_tx

-- ---------------------------------------------------------------------------------------------------
-- Delete hook of TX_STAT (the rules mechanism has row rules for INSERT / UPDATE only).  APEX sessions only.
-- Legacy PRE-DELETE: only the last statement of the company / tax may be deleted ('يجب حذف اخر اقرار اولا'),
-- and the lines are deleted with the header.  The check needs TX_TRNS_MAST itself, so it runs after the
-- statement (compound trigger: no ORA-04091); raising there rolls the whole delete back.
-- ---------------------------------------------------------------------------------------------------
create or replace trigger app_rules3_tx_mast_bd
for delete on tx_trns_mast
compound trigger
  type t_key is record (company number, tax number, serial number);
  type t_keys is table of t_key index by pls_integer;
  g_keys t_keys;

  before each row is
    k pls_integer;
  begin
    if v('APP_ID') is not null then
      k := g_keys.count + 1;
      g_keys(k).company := :old.company_code;
      g_keys(k).tax     := :old.tax_code;
      g_keys(k).serial  := :old.tax_serial;
      app_rules3_tx.stat_delete_lines(:old.company_code, :old.tax_code, :old.tax_serial);
    end if;
  end before each row;

  after statement is
  begin
    for i in 1 .. g_keys.count loop
      app_rules3_tx.stat_check_last(g_keys(i).company, g_keys(i).tax, g_keys(i).serial);
    end loop;
    g_keys.delete;
  end after statement;
end app_rules3_tx_mast_bd;
/
show errors trigger app_rules3_tx_mast_bd
