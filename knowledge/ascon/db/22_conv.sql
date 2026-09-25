-- =====================================================================================================
-- APP_CONV : document conversion buttons of the legacy screens (Stage C, actions addendum
--            app\legacy\STAGE_C_ACTIONS_ADDENDUM.md). Each function creates the next document of the business
--            flow and returns the ROWID of the created (or reused) target header; the generator opens it.
--
--   ST_PRICE_PROPOSAL   quotation          -> sales order            quote_to_order     (MAKE_ORDER / INSERT_ORDER_TRNS /
--                                                                                       DEVIDE_CONFGS / GET_ACT_DOC_NO_INV)
--   ST_ITEM_REQ_HANDLE  material request   -> transfer request       req_to_transfer    (REQUEST_TRANSFER)
--                                          -> purchase request       req_to_purchase    (REQUEST_ORDER)
--   ST_PRUCHASE_REQUEST purchase request   -> purchase order(s)      prq_to_order       (GEN_PUR_ORDER anonymous block)
--                                          -> request for quotation  prq_to_rfq         (PR_QUOT anonymous block)
--   ST_TRANSFER_REQUEST transfer request   -> issue transfer         trq_to_transfer    (ST_TRANSFER_FROM REQ_TRNS_* copy)
--   ST_PRICE_PROPOSAL   quotation          -> other quotation        quote_to_proposal  (MAKE_PROPOSAL / INSERT_ANOTHER_PROPOSAL)
--                                          -> transfer request       quote_to_trq       (MAKE_TRANSFER_REQ / INSERT_TRANSFER_REQ)
--                                          -> issue + receipt        quote_to_transfer  (MAKE_TRNSFER_FROM / INSERT_TRNSFR_FROM_TRNS /
--                                                                                       DEVIDE_CONFGS_TRNSFER / INSERT_TRNSFR_FROM_DET)
--   Evidence, rules and decisions: app\legacy\processes\<SOURCE FORM>.md.
--
-- Conventions
--   * Called from the APEX page submit (action region button): no COMMIT / ROLLBACK here; a refusal raises
--     raise_application_error(-20171..-20176, message) and APEX rolls the whole action back. Legacy message texts,
--     English when app_sec.lang = 'en'.
--   * The procedures write complete rows themselves (keys, serials, audit columns, derived values) exactly as the
--     legacy program units did, so the result is the same inside and outside APEX. While they write, the row rules of
--     APP_RULES_SA stand aside (app_rules_sa.set_bypass); the generated APPX_<table> triggers then only fill what is
--     still empty. APP_RULES_ST hooks are page-scoped and do not act on the source pages used here.
--   * Legacy DB triggers stay in charge of: ST_TRNS_MAST DATE_SERIAL (ST_TRNS_MAST_IN), stock cost / balance rows
--     (ST_TRNS_DET_C_IN), ALT_KEY, closed period (CLOSE_ST_TRNS_MAST).
--   * can_* functions return 'Y' / 'N' for the display condition of the action regions (never raise).
--   * last_message returns the legacy confirmation text of the last conversion ("تم عمل أمر البيع رقم ...").
--   * set_test / reset_test: switches for the regression tests only (history comparison of quotation -> order).
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_conv authid definer as

  -- ------------------------------------------------------------------ display conditions ('Y' / 'N')
  function can_quote_to_order  (p_rowid in varchar2) return varchar2;   -- ST_PRICE_PROPOSAL
  function can_req_to_transfer (p_rowid in varchar2) return varchar2;   -- ST_ITEM_REQ_HANDLE
  function can_req_to_purchase (p_rowid in varchar2) return varchar2;   -- ST_ITEM_REQ_HANDLE
  function can_prq_to_order    (p_rowid in varchar2) return varchar2;   -- ST_PRUCHASE_REQUEST
  function can_prq_to_rfq      (p_rowid in varchar2) return varchar2;   -- ST_PRUCHASE_REQUEST
  function can_trq_to_transfer (p_rowid in varchar2) return varchar2;   -- ST_TRANSFER_REQUEST
  function can_quote_to_proposal (p_rowid in varchar2) return varchar2; -- ST_PRICE_PROPOSAL (TO_PROPOSAL_BTN)
  function can_quote_to_trq      (p_rowid in varchar2) return varchar2; -- ST_PRICE_PROPOSAL (TO_TRANSFER_REQ)
  function can_quote_to_transfer (p_rowid in varchar2) return varchar2; -- ST_PRICE_PROPOSAL (TRNSFER_FROM_BTN)

  -- default target transaction type of an action (parameter default):
  --   REQ_TRANSFER (7/9 types of the supplying store), REQ_PURCHASE (7/13 types of the requesting store),
  --   TRQ_TRANSFER (5/9 issue-transfer types, the one of the request's store first),
  --   QT_PROPOSAL (7/16 quotation types of another store), QT_TRQ (7/9 transfer-request types of another store),
  --   QT_TRF_FROM / QT_TRF_TO (ST_TRNS_TYPE.TRNSFER_FROM_TRNS_TYPE / TRNSFER_TO_TRNS_TYPE of the quotation type)
  function first_target_type (p_what in varchar2, p_rowid in varchar2) return number;

  -- ------------------------------------------------------------------ conversions (return the target header ROWID)
  function quote_to_order (p_rowid in varchar2, p_order_date in date) return varchar2;
  -- p_lines: the chosen lines as item codes or line serials ("101012262, 101013048"); null = every line not converted
  -- yet (legacy CHOOSE check box of the detail block, not a table column)
  function req_to_transfer (p_rowid in varchar2, p_target_type in number, p_date in date, p_lines in varchar2 default null) return varchar2;
  function req_to_purchase (p_rowid in varchar2, p_target_type in number, p_date in date, p_lines in varchar2 default null) return varchar2;
  -- one purchase order per supplier (appended to the open, unconfirmed order of the same type and supplier when one
  -- exists, as the legacy did); returns the first order, last_message lists all of them
  function prq_to_order    (p_rowid in varchar2, p_date in date, p_lines in varchar2 default null) return varchar2;
  function prq_to_rfq      (p_rowid in varchar2, p_date in date, p_lines in varchar2 default null) return varchar2;
  function trq_to_transfer (p_rowid in varchar2, p_trns_type in number, p_date in date) return varchar2;
  -- quotation: the unavailable lines (CHOICE 0, UNAVAILABLE 1) to another quotation of another store (MAKE_PROPOSAL /
  -- INSERT_ANOTHER_PROPOSAL) or to a transfer request (MAKE_TRANSFER_REQ / INSERT_TRANSFER_REQ); the chosen lines to an issue
  -- transfer with its automatic receipt (MAKE_TRNSFER_FROM / INSERT_TRNSFR_FROM_TRNS). p_store: store of the new document when
  -- its type has no active store (legacy PROPOSAL_STORE_CODE / TRANSFER_REQ_STORE); p_to_store: destination of the transfer.
  function quote_to_proposal (p_rowid in varchar2, p_type in number, p_store in number, p_date in date) return varchar2;
  function quote_to_trq      (p_rowid in varchar2, p_type in number, p_store in number, p_date in date) return varchar2;
  function quote_to_transfer (p_rowid in varchar2, p_from_type in number, p_to_type in number, p_to_store in number,
                              p_date in date) return varchar2;

  -- legacy confirmation text of the last conversion of this session (session language)
  function last_message return varchar2;

  -- ------------------------------------------------------------------ regression tests only
  --   p_skip_converted : do not refuse an already converted quotation (and skip the DOC_NO duplicate check)
  --   p_skip_credit    : skip the credit-limit check (balances have changed since)
  --   p_asof           : lot balances / expiry evaluated as of this timestamp (documents inserted after it ignored),
  --                      INSERT_DATE / approval dates = this timestamp
  --   p_user           : user code outside APEX
  --   p_doc_no         : DOC_NO used instead of DOC_NO_SEQ.NEXTVAL (keeps the sequence untouched in tests)
  procedure set_test (p_skip_converted in boolean default false, p_skip_credit in boolean default false,
                      p_asof in date default null, p_user in number default null, p_doc_no in number default null);
  procedure reset_test;

end app_conv;
/
show errors package app_conv

create or replace package body app_conv as

  g_msg           varchar2(4000);
  g_t_skip_conv   boolean := false;
  g_t_skip_credit boolean := false;
  g_t_asof        date;
  g_t_cut         number;
  g_t_user        number;
  g_t_doc_no      number;

  type t_lot is record (confg number, avail number);
  type t_lots is table of t_lot index by pls_integer;

  -- =================================================================================== helpers
  function m (p_a in varchar2, p_e in varchar2) return varchar2 is
  begin
    return case when app_sec.lang = 'en' and p_e is not null then p_e else p_a end;
  end m;

  procedure err (p_code in pls_integer, p_a in varchar2, p_e in varchar2) is
  begin
    raise_application_error(p_code, m(p_a, p_e));
  end err;

  function num (p in varchar2) return number is
  begin
    return to_number(p default null on conversion error);
  end num;

  function usr return number is
  begin
    return nvl(num(v('G_USER_CODE')), g_t_user);
  end usr;

  function pw return number is
  begin
    return nvl(num(v('G_PASSWORD_NUMBER')), 0);
  end pw;

  function now_ return date is
  begin
    return nvl(g_t_asof, sysdate);
  end now_;

  function last_message return varchar2 is
  begin
    return g_msg;
  end last_message;

  procedure set_test (p_skip_converted in boolean default false, p_skip_credit in boolean default false,
                      p_asof in date default null, p_user in number default null, p_doc_no in number default null) is
  begin
    g_t_skip_conv := nvl(p_skip_converted, false);
    g_t_skip_credit := nvl(p_skip_credit, false);
    g_t_asof := p_asof;
    g_t_user := p_user;
    g_t_doc_no := p_doc_no;
    g_t_cut := null;
    if p_asof is not null then
      select nvl(min(date_serial), 1e18) into g_t_cut from st_trns_mast
       where insert_date > p_asof and insert_date <> trunc(insert_date);
    end if;
  end set_test;

  procedure reset_test is
  begin
    set_test;
  end reset_test;

  function rid (p_rowid in varchar2) return rowid is
  begin
    return chartorowid(p_rowid);
  exception when others then
    return null;
  end rid;

  -- transaction type granted to the user's group (legacy LOVs: :GLOBAL.PASSWORD_NUMBER = 0 OR ST_TRNSTYPE_PASSWORD)
  function type_ok (p_type in number, p_flag in number default 0) return boolean is
    l_n  number;
    l_pw number := pw;
  begin
    if l_pw = 0 then return true; end if;
    select count(*) into l_n from st_trnstype_password
     where password_number = l_pw and trns_type_code = p_type and (p_flag = 0 or flag = 1);
    return l_n > 0;
  end type_ok;

  -- store active and granted to the user's group (legacy STORE LOVs)
  function store_ok (p_store in number, p_rights in boolean default true) return boolean is
    l_n  number;
    l_pw number := pw;
  begin
    select count(*) into l_n from st_store where store_code = p_store and store_status = 1 and nvl(stop_flag, 0) = 0;
    if l_n = 0 then return false; end if;
    if p_rights and l_pw <> 0 then
      select count(*) into l_n from st_store_password where store_code = p_store and password_number = l_pw;
      return l_n > 0;
    end if;
    return true;
  end store_ok;

  -- library CHECK_DATE (TRANSLATE.pll): no future date, not before ST_BASIC.MIN_DATE
  procedure check_date (p_code in pls_integer, p_date in date) is
    l_min date;
  begin
    if trunc(p_date) > trunc(now_) then
      err(p_code, 'تاريخ الحركة أكبر من تاريخ اليوم', 'Transaction Date is greater than today''s date');
    end if;
    select min(min_date) into l_min from st_basic;
    l_min := nvl(l_min, to_date('01-01-' || to_char(to_number(to_char(sysdate, 'YYYY')) - 1), 'DD-MM-YYYY'));
    if trunc(p_date) < trunc(l_min) then
      err(p_code, 'الحد الأدنى لتاريخ الحركة هو ' || to_char(l_min, 'DD/MM/YYYY'),
          'The least value accepted for Transaction Date is ' || to_char(l_min, 'DD/MM/YYYY'));
    end if;
  end check_date;

  -- the chosen lines of a request (legacy CHOOSE check box of the detail block): p_lines = list of item codes or line
  -- serials (any separators), null = all lines
  function chosen (p_lines in varchar2, p_serial in number, p_item in varchar2) return boolean is
    l varchar2(4000);
  begin
    if p_lines is null or trim(p_lines) is null then return true; end if;
    l := ',' || upper(trim(both ',' from regexp_replace(p_lines, '[^0-9A-Za-z]+', ','))) || ',';
    return instr(l, ',' || to_char(p_serial) || ',') > 0 or instr(l, ',' || upper(p_item) || ',') > 0;
  end chosen;

  function factor_of (p_group in number, p_item in varchar2, p_unit in number) return number is
    l number;
  begin
    select max(factor) into l from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit;
    return nvl(l, 1);
  end factor_of;

  -- lot balance in a store (GET_BALANCE_CONFG without position); as of g_t_asof in the regression tests
  function lot_bal (p_store in number, p_group in number, p_item in varchar2, p_confg in number) return number is
    l number;
  begin
    if g_t_asof is null then
      return nvl(get_balance_confg(p_store, p_group, p_item, p_confg), 0);
    end if;
    -- documents inserted before the timestamp: ST_TRNS_MAST.DATE_SERIAL comes from a sequence in insertion order
    -- (trigger ST_TRNS_MAST_IN), so the cut is the first DATE_SERIAL of a document inserted after the timestamp
    select nvl(sum(case when t.effect in (1, 4, 6) then 1 when t.effect in (2, 3, 5) then -1 else 0 end * nvl(c.basic_qty, 0)), 0)
      into l
      from st_trns_det_cost c, st_trns_type t
     where t.trns_type_code = c.trns_type_code
       and c.store_code = p_store and c.item_confg_id = p_confg and nvl(c.delete_flag, 0) = 0
       and c.date_serial < g_t_cut;
    return l;
  end lot_bal;

  function tax_per (p_tax in number, p_group in number, p_item in varchar2) return number is
    l number;
  begin
    select tax_per into l from tx_taxes_items where tax_code = p_tax and item_code = p_item and group_code = p_group;
    return l;
  exception when others then
    return 0;
  end tax_per;

  -- =================================================================================== ST_PRICE_PROPOSAL -> ST_SALES_ORDER
  function qt_order_exists (p_type in number, p_serial in number) return boolean is
    l_n number;
  begin
    -- POST-QUERY: ORDER_TRNS_TYPE_CODE / ORDER_TRNS_SERIAL = live sales order with DEMO_TRNS = the quotation
    select count(*) into l_n from st_sales_order
     where demo_trns_type_code = p_type and demo_trns_serial = p_serial and delete_date is null;
    return l_n > 0;
  end qt_order_exists;

  -- TO_SALES_ORDER_BTN is hidden on the entry menu of the form (PARAMETER.AUTH = 1) and shown on the approval menu entry
  -- FILES_MENU.ST_PRO_APPROV (31/2 "اعتماد عروض الأسعار"): only users with that entry (FILE_PASSWORD) may convert
  function qt_approval_entry_ok return boolean is
    l_user number := usr;
    l_e    number;
    l_n    number;
  begin
    if nvl(l_user, -1) = 0 then return true; end if;
    select count(*) into l_e from sys_files where upper(file_name_a) = 'ST_PRICE_PROPOSAL' and menu_name = 'FILES_MENU.ST_PRO_APPROV';
    if l_e = 0 then return true; end if;
    select count(*) into l_n
      from file_password f, sys_files s
     where upper(s.file_name_a) = 'ST_PRICE_PROPOSAL' and s.menu_name = 'FILES_MENU.ST_PRO_APPROV'
       and f.system_number = s.system_number and f.file_serial = s.file_serial and f.users_code = l_user and f.query_flag = 1;
    return l_n > 0;
  end qt_approval_entry_ok;

  function can_quote_to_order (p_rowid in varchar2) return varchar2 is
    q     st_proposal_mast%rowtype;
    l_ord number;
    l_rid rowid := rid(p_rowid);
  begin
    select * into q from st_proposal_mast where rowid = l_rid;
    if not qt_approval_entry_ok then
      return 'N';
    end if;
    if nvl(q.delete_flag, 0) = 1 or nvl(q.salesman_done, 0) <> 1 or nvl(q.approve, 0) <> 1 or nvl(q.approve2, 0) <> 1
       or nvl(q.cust_accept_flag, 0) <> 1 or qt_order_exists(q.trns_type_code, q.trns_serial) then
      return 'N';
    end if;
    select max(sales_order_trns_type) into l_ord from st_trns_type where trns_type_code = q.trns_type_code;
    return case when l_ord is null then 'N' else 'Y' end;
  exception when others then
    return 'N';
  end can_quote_to_order;

  -- TO_SALES_ORDER_BTN credit check: CREDIT_LIMIT (NVL 0) < CRN_BAL_TOTAL (GET_CUSTOMER_BAL_ALL), or before APPROVE
  -- CREDIT_LIMIT < balance + quotation net value
  procedure qt_credit (q in st_proposal_mast%rowtype) is
    l_limit number; l_bal number; l_tot number; l_tax number;
  begin
    if q.customer_code is null or g_t_skip_credit then return; end if;
    select nvl(max(credit_limit), 0) into l_limit from customer where code = q.customer_code;
    l_bal := get_customer_bal_all(q.customer_code);
    if l_limit < l_bal then
      err(-20171, 'تعديت حد الائتمان', 'Over Credit Limit');
    end if;
    if nvl(q.approve, 0) = 0 then
      select nvl(sum((nvl(unit_price, 0) - (nvl(disc1_value, 0) + nvl(disc2_value, 0) + nvl(disc3_value, 0))) * nvl(quantity, 0)), 0),
             nvl(sum(tax_value1), 0)
        into l_tot, l_tax from st_proposal_det where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial;
      if l_limit < l_bal + (l_tot - nvl(q.disc_val, 0) - nvl(q.tot_disc1_value, 0) - nvl(q.tot_disc2_value, 0) - nvl(q.tot_disc3_value, 0)
                            + nvl(q.trnsport_val, 0) + l_tax + nvl(q.tax_value1, 0)) / nvl(q.currency_rate, 1) then
        err(-20171, 'تعديت حد الائتمان', 'Over Credit Limit');
      end if;
    end if;
  end qt_credit;

  -- INSERT_ORDER_DET: next SERIAL of the order, BASIC_QTY = factor x (qty + bonus + extra bonus)
  procedure insert_order_det (o in st_sales_order_det%rowtype) is
    l_serial number;
    l_bq     number;
  begin
    select nvl(max(serial), 0) + 1 into l_serial from st_sales_order_det
     where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    begin
      select nvl(factor, 1) * (nvl(o.quantity, 0) + nvl(o.bonus, 0) + nvl(o.extra_bonus, 0)) into l_bq
        from st_item_unit where item_code = o.item_code and group_code = o.item_group_code and unit_code = o.unit_code;
    exception when others then
      l_bq := nvl(o.quantity, 0) + nvl(o.bonus, 0) + nvl(o.extra_bonus, 0);
    end;
    insert into st_sales_order_det
      (trns_type_code, trns_serial, serial, item_group_code, item_code, item_confg_id, quantity, bonus, basic_qty, unit_code,
       unit_price, unit_price_curr, disc1_ratio, disc2_ratio, disc1_value, disc2_value, remark, tax_value1, tax_code1,
       tax_value2, tax_code2, disc3_ratio, disc3_value, bonus_ratio, extra_bonus_ratio, extra_bonus, auto_disc,
       org_class_code, org_disc1_ratio, org_disc2_ratio, org_disc3_ratio, org_bonus_ratio, org_extra_bonus_ratio,
       org_unit_price_curr, last_expire_date, temp_quantity, store_code)
    values
      (o.trns_type_code, o.trns_serial, l_serial, o.item_group_code, o.item_code, o.item_confg_id, o.quantity, o.bonus, l_bq, o.unit_code,
       o.unit_price, o.unit_price_curr, o.disc1_ratio, o.disc2_ratio, o.disc1_value, o.disc2_value, o.remark, o.tax_value1, o.tax_code1,
       o.tax_value2, o.tax_code2, o.disc3_ratio, o.disc3_value, o.bonus_ratio, o.extra_bonus_ratio, o.extra_bonus, o.auto_disc,
       o.org_class_code, o.org_disc1_ratio, o.org_disc2_ratio, o.org_disc3_ratio, o.org_bonus_ratio, o.org_extra_bonus_ratio,
       o.org_unit_price_curr, o.last_expire_date, o.temp_quantity, o.store_code);
  end insert_order_det;

  -- DEVIDE_CONFGS: one quotation line -> order lines over the lots with stock (the quotation lot first, then the other
  -- lots by earliest expiry, expired lots skipped): quantity first, then bonus, then extra bonus; discount values
  -- recomputed from the ratios, VAT = tax % x BASIC_QTY x net price. Faithful port, including the legacy arithmetic
  -- (the record keeps its values from one lot to the next, BASIC_QTY of the partial branches is not multiplied by the
  -- unit factor - every quotation line of the data has factor 1).
  procedure devide_confgs (c in st_proposal_det%rowtype, p_type in number, p_serial in number, p_factor in number) is
    o      st_sales_order_det%rowtype;
    f      number := p_factor;
    rq     number; rb number; reb number;
    bal    number;
    l_tax1 number := tax_per(c.tax_code1, c.group_code, c.item_code);
    l_tax2 number := tax_per(c.tax_code2, c.group_code, c.item_code);
    l_now  date := now_;
    lots   t_lots;
    k      pls_integer := 0;

    procedure tax is
    begin
      o.tax_value1 := l_tax1 * (o.basic_qty * (o.unit_price_curr - (o.disc1_value + o.disc2_value + o.disc3_value))) / 100;
      o.tax_value2 := l_tax2 * (o.basic_qty * (o.unit_price_curr - (o.disc1_value + o.disc2_value + o.disc3_value))) / 100;
    end tax;

    function ratio (p_val in number) return number is
    begin
      return case when nvl(o.quantity, 0) <> 0 then (nvl(p_val, 0) / o.quantity) * 100 else 0 end;
    end ratio;
  begin
    o.trns_type_code := p_type;
    o.trns_serial := p_serial;
    o.store_code := c.store_code;
    o.item_code := c.item_code;
    o.serial := nvl(c.item_serial, 1);
    o.item_confg_id := c.item_confg_id;
    o.item_group_code := c.group_code;
    o.unit_code := c.unit_code;
    o.quantity := nvl(c.quantity, 0);
    o.bonus := nvl(c.bonus, 0);
    o.unit_price := c.unit_price;
    o.unit_price_curr := c.unit_price_curr;
    o.disc1_ratio := c.disc1_ratio;
    o.disc2_ratio := c.disc2_ratio;
    o.disc1_value := c.disc1_value;
    o.disc2_value := c.disc2_value;
    o.remark := c.remark;
    o.tax_value1 := c.tax_value1;
    o.tax_code1 := c.tax_code1;
    o.tax_value2 := c.tax_value2;
    o.tax_code2 := c.tax_code2;
    o.disc3_ratio := c.disc3_ratio;
    o.disc3_value := c.disc3_value;
    o.bonus_ratio := nvl(c.bonus_ratio, 0);
    o.extra_bonus_ratio := nvl(c.extra_bonus_ratio, 0);
    o.extra_bonus := nvl(c.extra_bonus, 0);
    o.auto_disc := c.auto_disc;
    o.det_disc := c.det_disc;
    o.org_class_code := c.org_class_code;
    o.org_disc1_ratio := c.org_disc1_ratio;
    o.org_disc2_ratio := c.org_disc2_ratio;
    o.org_disc3_ratio := c.org_disc3_ratio;
    o.org_bonus_ratio := c.org_bonus_ratio;
    o.org_extra_bonus_ratio := c.org_extra_bonus_ratio;
    o.org_unit_price_curr := c.org_unit_price_curr;
    o.last_expire_date := c.last_expire_date;
    o.temp_quantity := c.temp_quantity;

    rq := nvl(c.quantity, 0) * f;
    rb := nvl(c.bonus, 0) * f;
    reb := nvl(c.extra_bonus, 0) * f;

    -- lots: the quotation lot (not expired, with stock), then the other lots with stock by expiry
    if c.item_confg_id is not null then
      for r in (select item_confg_id from st_item_confg
                 where group_code = c.group_code and item_code = c.item_code and item_confg_id = c.item_confg_id
                   and expire_date > l_now) loop
        bal := lot_bal(c.store_code, c.group_code, c.item_code, r.item_confg_id);
        if bal > 0 then k := k + 1; lots(k).confg := r.item_confg_id; lots(k).avail := bal; end if;
      end loop;
    end if;
    -- legacy "ORDER BY 4" (expiry) was answered through the index ST_ITEM_CONFG_U01 (GROUP_CODE, ITEM_CODE, EXPIRE_DATE,
    -- LOT_NUMBER, UNIT_PRICE, SUPPLIER_CODE, DISC_RATIO): lots with the same expiry come in that key order (history: 20 of 21)
    for r in (select item_confg_id from st_item_confg
               where group_code = c.group_code and item_code = c.item_code and expire_date > l_now
                 and (item_confg_id <> c.item_confg_id or c.item_confg_id is null)
               order by expire_date, lot_number, unit_price, supplier_code, disc_ratio, item_confg_id) loop
      bal := lot_bal(c.store_code, c.group_code, c.item_code, r.item_confg_id);
      if bal > 0 then k := k + 1; lots(k).confg := r.item_confg_id; lots(k).avail := bal; end if;
    end loop;

    for i in 1 .. lots.count loop
      bal := nvl(lots(i).avail, 0);
      bal := trunc(bal / f) * f;
      if bal <> 0 then
        if bal > 0 and (rq <> 0 or rb <> 0 or reb <> 0) then
          o.item_confg_id := lots(i).confg;
          o.det_disc := c.det_disc;
          if o.disc1_ratio is not null and o.unit_price_curr != 0 then
            o.disc1_value := o.disc1_ratio * o.unit_price_curr / 100;
          else
            o.disc1_value := 0;
          end if;
          if o.disc2_ratio is not null and o.unit_price_curr != 0 then
            o.disc2_value := o.disc2_ratio * (o.unit_price_curr - o.disc1_value) / 100;
          else
            o.disc2_value := 0;
          end if;
          if o.disc3_ratio is not null and o.unit_price_curr != 0 then
            o.disc3_value := o.disc3_ratio * (o.unit_price_curr - o.disc1_value - o.disc2_value) / 100;
          else
            o.disc3_value := 0;
          end if;

          if bal >= rq + rb + reb then
            o.quantity := rq / f;
            o.bonus := 0;
            o.bonus_ratio := 0;
            o.basic_qty := rq;
            tax;
            bal := bal - rq;
            rq := 0;
            if rb <> 0 then
              if bal >= rb then
                o.bonus := rb / f;
                o.bonus_ratio := ratio(o.bonus);
                o.basic_qty := o.basic_qty + rb;
                tax;
                bal := bal - rb;
                rb := 0;
              else
                o.bonus := bal / f;
                o.bonus_ratio := ratio(o.bonus);
                o.basic_qty := o.basic_qty + bal;
                tax;
                rb := rb - bal;
                bal := 0;
              end if;
            end if;
            if reb <> 0 then
              if bal >= reb then
                o.extra_bonus := reb / f;
                o.extra_bonus_ratio := ratio(o.extra_bonus);
                o.basic_qty := o.basic_qty + reb;
                tax;
                bal := bal - reb;
                reb := 0;
              else
                o.extra_bonus := bal / f;
                o.extra_bonus_ratio := ratio(o.extra_bonus);
                o.basic_qty := o.basic_qty + bal;
                tax;
                reb := reb - bal;
                bal := 0;
              end if;
            end if;
          else
            if bal <= rq then
              o.quantity := bal / f;
              o.bonus := 0;
              o.bonus_ratio := 0;
              o.extra_bonus := 0;
              o.extra_bonus_ratio := 0;
              o.basic_qty := o.quantity;
              tax;
              rq := rq - bal;
              bal := 0;
            else
              o.quantity := rq / f;
              if bal - rq <= rb then
                o.bonus := (bal - rq) / f;
                o.bonus_ratio := ratio(o.bonus);
                o.extra_bonus := 0;
                o.extra_bonus_ratio := 0;
                o.basic_qty := o.quantity + o.bonus;
                tax;
                rq := rq - o.quantity;
                rb := rb - o.bonus;
                bal := 0;
              else
                o.quantity := rq / f;
                o.bonus := rb / f;
                o.bonus_ratio := ratio(o.bonus);
                if bal - rq - rb <= reb then
                  o.extra_bonus := (bal - rq - rb) / f;
                  o.extra_bonus_ratio := ratio(o.extra_bonus);
                  o.basic_qty := o.quantity + o.bonus + o.extra_bonus;
                  tax;
                  rq := rq - o.quantity;
                  rb := rb - o.bonus;
                  reb := reb - o.extra_bonus;
                  bal := 0;
                end if;
              end if;
            end if;
          end if;
          insert_order_det(o);
        end if;
        if rq = 0 and rb = 0 and reb = 0 then
          exit;
        end if;
      end if;
    end loop;

    if rq <> 0 or rb <> 0 or reb <> 0 then
      err(-20171, 'أقصى كمية يمكن إخراجها حتى لا تتعارض مع الحركات التالية = ' || rb || ' + ' || reb || ' للصنف ' || c.item_code,
          'Maximum Amount Can Be Sold Without Conflicting With Next Transactions = ' || rb || ' + ' || reb || ' For item ' || c.item_code);
    end if;
  end devide_confgs;

  function quote_to_order (p_rowid in varchar2, p_order_date in date) return varchar2 is
    q          st_proposal_mast%rowtype;
    l_rid      rowid := rid(p_rowid);
    l_type     number;
    l_sales    number;
    l_serial   number;
    l_n        number;
    l_date     date := trunc(p_order_date);
    l_user     number := usr;
    l_now      date := now_;
    l_doc      number;
    l_desc_a   varchar2(4000);
    l_desc_e   varchar2(4000);
    l_out      rowid;
    l_factor   number;
  begin
    g_msg := null;
    begin
      select * into q from st_proposal_mast where rowid = l_rid for update wait 10;
    exception when no_data_found then
      err(-20171, 'عرض السعر غير موجود (ربما حذف من مستخدم آخر)', 'The quotation no longer exists');
    end;
    if nvl(q.delete_flag, 0) = 1 then
      err(-20171, 'عرض السعر ملغي', 'The quotation is deleted');
    end if;
    if not qt_approval_entry_ok then
      err(-20171, 'ليس لديك صلاحية على شاشة اعتماد عروض الأسعار', 'You have no right on the quotation approval screen');
    end if;
    -- TO_SALES_ORDER_BTN
    qt_credit(q);
    if q.doc_no is not null and not g_t_skip_conv then
      select count(*) into l_n
        from st_trns_mast mm
       where mm.doc_no = q.doc_no and nvl(mm.delete_flag, 0) = 0
         and mm.trns_type_code in (select trns_type_code from st_trns_type where effect = 2 and trns_type = 2)
         and get_customer_ctgry(mm.customer_code, mm.salesman_code) = get_customer_ctgry(q.customer_code, q.salesman_code);
      if l_n > 0 then
        err(-20171, 'رقم المستند مكرر لنفس رقم القسم', 'Doc No Repeated for Same Ctgry');
      end if;
    end if;
    if nvl(q.approve, 0) <> 1 then
      err(-20171, 'يجب إعتماد الإدارة أولا', 'Must Management Approval First');
    end if;
    if nvl(q.approve2, 0) <> 1 then
      err(-20171, 'يجب إعتماد الإدارة 2 أولا', 'Must Management Approval 2 First');
    end if;
    if nvl(q.cust_accept_flag, 0) = 0 then
      err(-20171, 'يجب إعتماد العميل أولا', 'Must Customer Approval First');
    end if;
    -- MAKE_ORDER: the four flags re-read from the table, not already converted
    if nvl(q.salesman_done, 0) <> 1 or nvl(q.approve2, 0) <> 1 or nvl(q.approve, 0) <> 1 or nvl(q.cust_accept_flag, 0) <> 1 then
      err(-20171, 'يجب الإعتماد أولا', 'Must Approve First');
    end if;
    if not g_t_skip_conv and qt_order_exists(q.trns_type_code, q.trns_serial) then
      err(-20171, 'عرض السعر تم ترحيلة إلي أمر بيع', 'Price Proposal Posted To Sales Order');
    end if;
    -- order type = ST_TRNS_TYPE.SALES_ORDER_TRNS_TYPE of the quotation type, order date
    select max(sales_order_trns_type) into l_type from st_trns_type where trns_type_code = q.trns_type_code;
    if l_type is null or l_date is null then
      err(-20171, 'يجب تعريف رقم حركة أمر البيع و تاريخ أمر البيع', 'Sales Order Trns and Sales Order Date Must Be Entered');
    end if;
    -- ORDER_DATE WHEN-VALIDATE-ITEM
    if l_date < q.trns_date then
      err(-20171, 'تاريخ أمر البيع يجب أن يكون أكبر من يساوى تارخ عرض السعر', 'Sales Order Date Must Be Greater Than Or Equal Proposal Date');
    end if;
    check_date(-20171, l_date);
    -- INSERT_ORDER_TRNS requires the invoice type of the order type (:SALES_TRNS_TYPE)
    select max(sales_trns_type_code) into l_sales from st_trns_type where trns_type_code = l_type;
    if l_sales is null then
      err(-20171, 'يجب إدخال رقم حركة فاتورة المبيعات و تاريخ الفاتورة', 'Sales Invoice Trns And Invoice Date Must Be Entered');
    end if;
    select count(*) into l_n from st_proposal_det
     where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial
       and nvl(choice_flag, 0) = 1 and nvl(unavailable_flag, 0) = 0;
    if l_n = 0 then
      err(-20171, 'لايمكن التحويل الي امر بيع بدون اختيار الأصناف', 'There is no Choice Items to Make Order');
    end if;

    -- INSERT_ORDER_TRNS: header
    select nvl(max(trns_serial), 0) + 1 into l_serial from st_sales_order where trns_type_code = l_type;
    l_desc_a := 'أمر بيع رقم ' || l_type || '/' || l_serial || ' من عرض أسعار رقم  ' || q.trns_type_code || '/' || q.trns_serial;
    l_desc_e := 'Sales Order No. ' || l_type || '/' || l_serial || ' From Price Proposal No.  ' || q.trns_type_code || '/' || q.trns_serial;
    app_rules_sa.set_bypass(true);
    insert into st_sales_order
      (trns_type_code, trns_serial, order_serial, order_date, loading_date, store_code, invoice_number, desc_a, desc_e, doc_no,
       currency_code, currency_rate, customer_code, salesman_code, supplier_code, so_type, trnsport_val, pay_term, delivery_terms,
       offer_expiry, demo_trns_type_code, demo_trns_serial, insert_user, insert_date, update_user, update_date,
       rfq, offer_expire_date, tax_value1, tax_code1, tax_value2, tax_code2,
       tot_disc1_ratio, tot_disc2_ratio, tot_disc3_ratio, tot_disc1_value, tot_disc2_value, tot_disc3_value, payment_type,
       approved, approved2, approved_users_code, approved_date, approved2_users_code, approved2_date, class_code)
    values
      (l_type, l_serial, to_number(to_char(l_type) || to_char(l_serial)), l_date, l_date, q.store_code, q.invoice_no, l_desc_a, l_desc_e, q.doc_no,
       nvl(q.currency_code, 1), nvl(q.currency_rate, 1), q.customer_code, q.salesman_code, q.supplier_code, 0, q.trnsport_val, q.pay_term, q.other_terms,
       q.offer_expiry, q.trns_type_code, q.trns_serial, l_user, trunc(l_now), l_user, l_now,
       q.rfq, q.proposal_expire, q.tax_value1, q.tax_code1, q.tax_value2, q.tax_code2,
       q.tot_disc1_ratio, q.tot_disc2_ratio, q.tot_disc3_ratio, q.tot_disc1_value, q.tot_disc2_value, q.tot_disc3_value, q.payment_type,
       1, 1, l_user, l_now, l_user, l_now, q.class_code)
    returning rowid into l_out;

    -- lines: chosen and available, split over the lots with stock
    for c in (select * from st_proposal_det
               where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial
                 and nvl(choice_flag, 0) = 1 and nvl(unavailable_flag, 0) = 0
               order by item_serial) loop
      begin
        select iu.factor into l_factor from st_item_unit iu, st_unit un
         where iu.unit_code = un.unit_code and iu.group_code = c.group_code and iu.item_code = c.item_code and iu.unit_code = c.unit_code;
      exception when no_data_found then
        l_factor := 1;
      end;
      devide_confgs(c, l_type, l_serial, nvl(l_factor, 1));
    end loop;

    -- MAKE_ORDER after the commit: GET_ACT_DOC_NO_INV when the quotation has no DOC_NO (DOC_NO_SEQ on quotation and order)
    if q.doc_no is null then
      if g_t_doc_no is not null then
        l_doc := g_t_doc_no;
      else
        l_doc := get_act_doc_no_proposal(q.trns_type_code);
      end if;
      update st_sales_order set doc_no = l_doc where rowid = l_out;
      update st_proposal_mast set doc_no = l_doc where rowid = l_rid;
    end if;
    app_rules_sa.set_bypass(false);
    g_msg := m('تم عمل أمر البيع رقم ' || l_type || '/' || l_serial, 'Sales Order Inserted No. ' || l_type || '/' || l_serial);
    return rowidtochar(l_out);
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end quote_to_order;

  -- =================================================================================== ST_ITEM_REQ_HANDLE
  -- a request line is converted when PR_FLAG > 0 or a transfer / purchase request line points to it
  function req_line_open (p_type in number, p_serial in number, p_line in number, p_pr_flag in number) return boolean is
    l_n number;
  begin
    if nvl(p_pr_flag, 0) > 0 then return false; end if;
    select (select count(*) from st_trns_det_request where req_trns_type_code = p_type and req_trns_serial = p_serial and req_item_serial = p_line)
         + (select count(*) from pr_order_det_request where req_trns_type_code = p_type and req_trns_serial = p_serial and req_item_serial = p_line)
      into l_n from dual;
    return l_n = 0;
  end req_line_open;

  function req_open_lines (p_type in number, p_serial in number) return number is
    l_n number := 0;
  begin
    for d in (select item_serial, pr_flag from st_item_req_det where trns_type_code = p_type and trns_serial = p_serial) loop
      if req_line_open(p_type, p_serial, d.item_serial, d.pr_flag) then l_n := l_n + 1; end if;
    end loop;
    return l_n;
  end req_open_lines;

  function can_req_to_transfer (p_rowid in varchar2) return varchar2 is
    r     st_item_req%rowtype;
    l_rid rowid := rid(p_rowid);
  begin
    select * into r from st_item_req where rowid = l_rid;
    return case when req_open_lines(r.trns_type_code, r.trns_serial) > 0 then 'Y' else 'N' end;
  exception when others then
    return 'N';
  end can_req_to_transfer;

  function can_req_to_purchase (p_rowid in varchar2) return varchar2 is
  begin
    return can_req_to_transfer(p_rowid);
  end can_req_to_purchase;

  -- REQ_TRNS_TYPE_RG of the handle screen: EFFECT 7, TRNS_TYPE 9 (transfer) / 13 (purchase), with a store that is the
  -- supplying store (transfer) / the requesting store (purchase) unless ST_BASIC.RLTD_TRNS_STR_FLAG = 0; group rights
  function req_type_ok (r in st_item_req%rowtype, p_type in number, p_transfer in boolean) return boolean is
    l_rltd  number;
    l_n     number;
    l_kind  number := case when p_transfer then 9 else 13 end;
    l_store number := case when p_transfer then r.from_store_code else r.store_code end;
  begin
    select min(nvl(rltd_trns_str_flag, 1)) into l_rltd from st_basic;
    select count(*) into l_n from st_trns_type t
     where t.trns_type_code = p_type and t.effect = 7 and t.store_code is not null and t.trns_type = l_kind
       and (nvl(l_rltd, 1) = 0 or t.store_code = l_store);
    return l_n > 0 and type_ok(p_type);
  end req_type_ok;

  procedure req_checks (r in st_item_req%rowtype, p_type in number, p_date in date, p_transfer in boolean,
                        p_code in pls_integer, p_lines in varchar2, o_count out number) is
    l_est number;
    l_n   number := 0;
  begin
    if p_type is null then
      if p_transfer then err(p_code, 'لابد من إدخال رقم حركة التحويل', 'Enter transfer transaction type');
      else err(p_code, 'لابد من إدخال رقم حركة طلب الشراء', 'Enter order request transaction type'); end if;
    end if;
    if p_transfer and r.from_store_code is null then
      err(p_code, 'لابد من إدخال رقم المستودع الذي سيتم التحويل منه أولا', 'The Store Code that will transfer from must be entered first');
    end if;
    if not req_type_ok(r, p_type, p_transfer) then
      err(p_code, 'نوع الحركة غير مسموح به فى هذه الشاشة: ' || p_type, 'Transaction type not allowed here: ' || p_type);
    end if;
    if p_date is null then
      err(p_code, 'يجب ادخال التاريخ', 'YOU MUST Enter Date');
    end if;
    -- TRNS_DATE2 WHEN-VALIDATE-ITEM
    if trunc(p_date) < trunc(r.req_date) then
      err(p_code, 'يجب ان يكون تاريخ التحويل اكبر من تاريخ الطلب', 'Transfer Date Must Be Greater Than Request Date');
    end if;
    check_date(p_code, p_date);
    -- project-estimate approval (SET_APPROVE / NEED_APPROVE, only with ST_BASIC.EST_FLAG = 1)
    select count(*) into l_est from st_basic where est_flag = 1;
    for d in (select item_serial, item_code, pr_flag, need_approve from st_item_req_det
               where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial) loop
      if chosen(p_lines, d.item_serial, d.item_code) and req_line_open(r.trns_type_code, r.trns_serial, d.item_serial, d.pr_flag) then
        if l_est > 0 and nvl(d.need_approve, 0) = 1 then
          err(p_code, 'لا يمكن ترحيل طلبات غير معتمدة', 'You can''t post non approved order');
        end if;
        l_n := l_n + 1;
      end if;
    end loop;
    if l_n = 0 then
      err(p_code, 'لا توجد أصناف مختارة لم يتم تحويلها', 'There are no chosen items that were not converted yet');
    end if;
    o_count := l_n;
  end req_checks;

  -- REQUEST_TRANSFER: automated transfer request from the chosen unconverted lines, PR_FLAG = 2
  function req_to_transfer (p_rowid in varchar2, p_target_type in number, p_date in date, p_lines in varchar2 default null) return varchar2 is
    r        st_item_req%rowtype;
    l_rid    rowid := rid(p_rowid);
    l_date   date := trunc(p_date);
    l_serial number;
    l_dser   number;
    l_desc_a varchar2(4000);
    l_desc_e varchar2(4000);
    l_count  number;
    l_n      number := 0;
    l_out    rowid;
  begin
    g_msg := null;
    begin
      select * into r from st_item_req where rowid = l_rid for update wait 10;
    exception when no_data_found then
      err(-20172, 'طلب النواقص غير موجود', 'The material request no longer exists');
    end;
    req_checks(r, p_target_type, l_date, true, -20172, p_lines, l_count);
    select nvl(max(trns_serial), 0) + 1 into l_serial from st_trns_mast_request where trns_type_code = p_target_type;
    select nvl(max(date_serial), 0) + 1 into l_dser from st_trns_mast_request where trns_date = l_date;
    l_desc_a := ' حركة طلب تحويل آلي من طلبية نواقص رقم ' || r.trns_type_code || '/' || r.trns_serial || '  ' || r.desc_a;
    l_desc_e := ' Automated Trns. Req. From Material Req. No.' || r.trns_type_code || '/' || r.trns_serial || '  ' || r.desc_e;
    if length(l_desc_a) > 100 or length(l_desc_e) > 100 then
      err(-20172, 'لقد تجاوزت الحد الاقصى لطول الوصف', 'You have exceeded the maximum description length allowed');
    end if;
    app_rules_sa.set_bypass(true);
    insert into st_trns_mast_request
      (trns_serial, trns_date, date_serial, desc_a, desc_e, currency_rate, post_flag, delete_flag, trns_type_code, currency_code,
       store_code, trnsfer_to_store, invoice_no, to_transfer_flag)
    values
      (l_serial, l_date, l_dser, l_desc_a, l_desc_e, 1, 0, 0, p_target_type, 1,
       r.from_store_code, r.store_code, r.trns_type_code || lpad(r.trns_serial, 3, '0'), 0)
    returning rowid into l_out;
    for d in (select * from st_item_req_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial order by item_serial) loop
      if chosen(p_lines, d.item_serial, d.item_code) and req_line_open(r.trns_type_code, r.trns_serial, d.item_serial, d.pr_flag) then
        insert into st_trns_det_request
          (item_serial, quantity, unit_cost, unit_price, basic_qty, cost_flag, trns_type_code, trns_serial, unit_code, group_code,
           item_code, req_trns_type_code, req_trns_serial, req_item_serial, color_code, size_code)
        values
          (d.item_serial, d.quantity, null, null, d.basic_qty, 0, p_target_type, l_serial, d.unit_code, d.group_code,
           d.item_code, d.trns_type_code, d.trns_serial, d.item_serial, d.color_code, d.size_code);
        update st_item_req_det set pr_flag = 2
         where trns_type_code = d.trns_type_code and trns_serial = d.trns_serial and item_serial = d.item_serial;
        l_n := l_n + 1;
      end if;
    end loop;
    app_rules_sa.set_bypass(false);
    g_msg := m(' تم عمل طلب تحويل لعدد ' || l_n || ' صنف ' || '(' || p_target_type || '/' || l_serial || ')',
               'Transfer Request Done For ' || l_n || ' Item ' || '(' || p_target_type || '/' || l_serial || ')');
    return rowidtochar(l_out);
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end req_to_transfer;

  -- REQUEST_ORDER: automated purchase request from the chosen unconverted lines, PR_FLAG = 1
  function req_to_purchase (p_rowid in varchar2, p_target_type in number, p_date in date, p_lines in varchar2 default null) return varchar2 is
    r        st_item_req%rowtype;
    l_rid    rowid := rid(p_rowid);
    l_date   date := trunc(p_date);
    l_serial number;
    l_dser   number;
    l_store  number;
    l_count  number;
    l_n      number := 0;
    l_supp   number;
    l_out    rowid;
    l_user   number := usr;
  begin
    g_msg := null;
    begin
      select * into r from st_item_req where rowid = l_rid for update wait 10;
    exception when no_data_found then
      err(-20173, 'طلب النواقص غير موجود', 'The material request no longer exists');
    end;
    req_checks(r, p_target_type, l_date, false, -20173, p_lines, l_count);
    l_store := r.store_code;
    select nvl(max(trns_serial), 0) + 1 into l_serial from pr_order_request where trns_type_code = p_target_type;
    -- DATE_SERIAL as the purchase-request screen numbers it (per store and request date); the legacy handle screen
    -- read ST_TRNS_MAST_REQUEST here (copy / paste defect)
    select nvl(max(date_serial), 0) + 1 into l_dser from pr_order_request where store_code = l_store and req_date = l_date;
    app_rules_sa.set_bypass(true);
    insert into pr_order_request
      (trns_type_code, trns_serial, store_code, doc_no, req_date, date_serial, desc_a, desc_e,
       insert_user, update_user, delete_user, from_store_code)
    values
      (p_target_type, l_serial, l_store, r.doc_no, l_date, l_dser,
       substr('طلب شراء آلى من طلب نواقص رقم' || r.trns_type_code || '/' || r.trns_serial || r.desc_a, 1, 300),
       substr('Automated PR From Material Req. No. ' || r.trns_type_code || '/' || r.trns_serial || r.desc_e, 1, 300),
       nvl(r.insert_user, l_user), nvl(r.update_user, l_user), r.delete_user, r.from_store_code)
    returning rowid into l_out;
    for d in (select * from st_item_req_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial order by item_serial) loop
      if chosen(p_lines, d.item_serial, d.item_code) and req_line_open(r.trns_type_code, r.trns_serial, d.item_serial, d.pr_flag) then
        -- supplier of the item (ST_PRUCHASE_REQUEST line rule), needed later by "عمل أمر شراء"
        select max(supplier) into l_supp from st_item where item_group_code = d.group_code and item_code = d.item_code;
        insert into pr_order_det_request
          (trns_type_code, trns_serial, item_serial, quantity, basic_qty, req_date, date_serial, item_code, group_code, unit_code,
           req_trns_type_code, req_trns_serial, req_item_serial, color_code, size_code, supp_code)
        values
          (p_target_type, l_serial, d.item_serial, d.quantity, d.basic_qty, l_date, l_dser, d.item_code, d.group_code, d.unit_code,
           d.trns_type_code, d.trns_serial, d.item_serial, d.color_code, d.size_code, l_supp);
        update st_item_req_det set pr_flag = 1
         where trns_type_code = d.trns_type_code and trns_serial = d.trns_serial and item_serial = d.item_serial;
        l_n := l_n + 1;
      end if;
    end loop;
    app_rules_sa.set_bypass(false);
    g_msg := m(' تم عمل طلب شراء لعدد ' || l_n || ' صنف ' || '(' || p_target_type || '/' || l_serial || ')',
               'Purchase Request Done For ' || l_n || ' Item ' || '(' || p_target_type || '/' || l_serial || ')');
    return rowidtochar(l_out);
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end req_to_purchase;

  -- =================================================================================== ST_PRUCHASE_REQUEST
  function prq_line_has_po (p_type in number, p_serial in number, p_line in number) return boolean is
    l_n number;
  begin
    select count(*) into l_n from pr_order_det
     where req_trns_type_code = p_type and req_trns_serial = p_serial and req_item_serial = p_line;
    return l_n > 0;
  end prq_line_has_po;

  function prq_line_has_rfq (p_type in number, p_serial in number, p_line in number) return boolean is
    l_n number;
  begin
    select count(*) into l_n from pr_req_det
     where pr_trns_type_code = p_type and pr_trns_serial = p_serial and pr_item_serial = p_line;
    return l_n > 0;
  end prq_line_has_rfq;

  function can_prq_to_order (p_rowid in varchar2) return varchar2 is
    r     pr_order_request%rowtype;
    l_rid rowid := rid(p_rowid);
  begin
    select * into r from pr_order_request where rowid = l_rid;
    for d in (select item_serial from pr_order_det_request where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial) loop
      if not prq_line_has_po(r.trns_type_code, r.trns_serial, d.item_serial) then return 'Y'; end if;
    end loop;
    return 'N';
  exception when others then
    return 'N';
  end can_prq_to_order;

  function can_prq_to_rfq (p_rowid in varchar2) return varchar2 is
    r     pr_order_request%rowtype;
    l_rid rowid := rid(p_rowid);
  begin
    select * into r from pr_order_request where rowid = l_rid;
    for d in (select item_serial from pr_order_det_request where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial) loop
      if not prq_line_has_rfq(r.trns_type_code, r.trns_serial, d.item_serial) then return 'Y'; end if;
    end loop;
    return 'N';
  exception when others then
    return 'N';
  end can_prq_to_rfq;

  procedure prq_date_checks (r in pr_order_request%rowtype, p_date in date, p_code in pls_integer) is
  begin
    if p_date is null then
      err(p_code, 'يجب ادخال التاريخ', 'YOU MUST Enter Date');
    end if;
    if trunc(p_date) < trunc(r.req_date) then
      err(p_code, 'يجب ان يكون تاريخ التحويل اكبر من تاريخ الطلب', 'Transfer Date Must Be Greater Than Request Date');
    end if;
    check_date(p_code, p_date);
  end prq_date_checks;

  -- "عمل أمر شراء": chosen lines without a purchase order, grouped by supplier: the open (unconfirmed, not closed) order of
  -- the PR_TRNS_TYPE and supplier is reused, else a new order is created; VN_PRICE = retail price of the basic unit x factor
  function prq_to_order (p_rowid in varchar2, p_date in date, p_lines in varchar2 default null) return varchar2 is
    r        pr_order_request%rowtype;
    l_rid    rowid := rid(p_rowid);
    l_date   date := trunc(p_date);
    l_po     number;
    l_ser    number;
    l_curr   number;
    l_rate   number;
    l_price  number;
    l_line   number;
    l_n      number := 0;
    l_first  rowid;
    l_rowid  rowid;
    l_list   varchar2(4000);
    l_new    number := 0;
    l_user   number := usr;
    l_now    date := now_;
    l_group  number;
    l_unit   number;
  begin
    g_msg := null;
    begin
      select * into r from pr_order_request where rowid = l_rid for update wait 10;
    exception when no_data_found then
      err(-20174, 'طلب الشراء غير موجود', 'The purchase request no longer exists');
    end;
    prq_date_checks(r, l_date, -20174);
    select max(pr_trns_type) into l_po from st_trns_type where trns_type_code = r.trns_type_code;
    if l_po is null then
      err(-20174, 'رقم نوع حركة المشتريات غير موجود', 'The PR Trns. Type is not found');
    end if;
    app_rules_sa.set_bypass(true);
    for d in (select * from pr_order_det_request where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial
               order by item_serial) loop
      if chosen(p_lines, d.item_serial, d.item_code) and not prq_line_has_po(r.trns_type_code, r.trns_serial, d.item_serial) then
        if d.supp_code is null then
          err(-20174, 'لا يوجد مورد للصنف  ' || d.item_code, 'NO SUPPLIER FOR ITEM NO ' || d.item_code);
        end if;
        l_group := nvl(d.group_code, app_rules_pr.item_group(d.item_code));
        l_unit := nvl(d.unit_code, app_rules_pr.basic_unit(l_group, d.item_code));
        select max(retail_sale_price) into l_price
          from st_item_unit where item_code = d.item_code and group_code = l_group and basic_unit = 1;
        l_price := l_price * factor_of(l_group, d.item_code, l_unit);
        if nvl(l_price, 0) = 0 then           -- PR_ORDER_DET rule of the purchase-order screen
          err(-20174, 'لابد من ادخال سعر الوحدة - الصنف ' || d.item_code, 'The unit price is required - item ' || d.item_code);
        end if;
        if nvl(d.quantity, 0) <= 0 then
          err(-20174, 'الكمية لا بد أن تكون أكبر من الصفر - الصنف ' || d.item_code, 'The quantity must be greater than zero - item ' || d.item_code);
        end if;
        -- open order of the same type and supplier
        select nvl(max(trns_serial), 0) into l_ser from pr_order
         where trns_type_code = l_po and nvl(confirm_flag, 0) = 0 and nvl(close_flag, 0) = 0 and supplier_code = d.supp_code;
        if l_ser = 0 then
          select nvl(max(nvl(trns_serial, 0)), 0) + 1 into l_ser from pr_order where trns_type_code = l_po;
          select nvl(max(currency_code), 1) into l_curr from supplier where code = d.supp_code;
          select nvl(max(rate), 1) into l_rate from ac_currency where currency_code = l_curr;
          insert into pr_order
            (trns_type_code, trns_serial, pr_order_date, currency_code, currency_rate, supplier_code, confirm_flag, requisition_type,
             close_flag, st_srv_asst_flag, doc_no, store_code, insert_user, insert_date, update_user, update_date)
          values
            (l_po, l_ser, l_date, l_curr, case when l_curr = 1 then 1 else l_rate end, d.supp_code, 0, r.requisition_type,
             0, 1, app_rules_pr.next_order_doc_no, nvl(app_rules_pr.type_store(l_po), r.store_code), l_user, l_now, l_user, l_now)
          returning rowid into l_rowid;
          l_new := l_new + 1;
        else
          select rowid into l_rowid from pr_order where trns_type_code = l_po and trns_serial = l_ser;
        end if;
        if l_first is null then l_first := l_rowid; end if;
        if instr(',' || l_list || ',', ',' || l_po || '/' || l_ser || ',') = 0 then
          l_list := l_list || case when l_list is not null then ',' end || l_po || '/' || l_ser;
        end if;
        select nvl(max(serial), 0) + 1 into l_line from pr_order_det where trns_type_code = l_po and trns_serial = l_ser;
        insert into pr_order_det
          (trns_type_code, trns_serial, pr_order_date, serial, group_code, item_code, unit_code, quantity, qty_status, req_serial,
           req_date, vn_price, req_trns_type_code, req_trns_serial, req_item_serial, size_code, color_code,
           insert_user_det, insert_det_date, update_det_date)
        values
          (l_po, l_ser, l_date, l_line, l_group, d.item_code, l_unit, d.quantity, 1, d.item_serial,
           l_date, l_price, r.trns_type_code, r.trns_serial, d.item_serial, d.size_code, d.color_code,
           l_user, l_now, l_now);
        l_n := l_n + 1;
      end if;
    end loop;
    app_rules_sa.set_bypass(false);
    if l_n = 0 then
      err(-20174, 'لم يتم عمل امر شراء', 'The operation were canceled');
    end if;
    g_msg := m(' تم عمل أمر شراء لعدد ' || l_n || ' صنف ' || '(أوامر الشراء: ' || replace(l_list, ',', ', ') || ')',
               'Purchase Order Done For ' || l_n || ' Item ' || '(purchase orders: ' || replace(l_list, ',', ', ') || ')');
    return rowidtochar(l_first);
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end prq_to_order;

  -- "عمل طلب عرض أسعار": one RFQ (ST_TRNS_TYPE.QUOT_TRNS_TYPE) with the chosen lines not yet on an RFQ
  function prq_to_rfq (p_rowid in varchar2, p_date in date, p_lines in varchar2 default null) return varchar2 is
    r        pr_order_request%rowtype;
    l_rid    rowid := rid(p_rowid);
    l_date   date := trunc(p_date);
    l_rfq    number;
    l_ser    number;
    l_n      number := 0;
    l_out    rowid;
    l_user   number := usr;
  begin
    g_msg := null;
    begin
      select * into r from pr_order_request where rowid = l_rid for update wait 10;
    exception when no_data_found then
      err(-20175, 'طلب الشراء غير موجود', 'The purchase request no longer exists');
    end;
    prq_date_checks(r, l_date, -20175);
    select max(quot_trns_type) into l_rfq from st_trns_type where trns_type_code = r.trns_type_code;
    if l_rfq is null then
      err(-20175, 'يجب ربط حركة طلب الشراء بحركة طلب عرض أسعار فى شاشة الحركات!!!',
          'Purchase Request Must Be Joined With Proposal Trns. In Trns. Screen');
    end if;
    app_rules_sa.set_bypass(true);
    for d in (select * from pr_order_det_request where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial
               order by item_serial) loop
      if chosen(p_lines, d.item_serial, d.item_code) and not prq_line_has_rfq(r.trns_type_code, r.trns_serial, d.item_serial) then
        if l_out is null then
          select nvl(max(trns_serial), 0) + 1 into l_ser from pr_req_mast where trns_type_code = l_rfq;
          insert into pr_req_mast
            (trns_type_code, trns_serial, req_status, pr_trns_type_code, pr_trns_serial, req_date, req_desc, store_code,
             insert_user, update_user)
          values
            (l_rfq, l_ser, 1, r.trns_type_code, r.trns_serial, l_date,
             ' طلب عرض أسعار آلى محول من طلب مشتريات برقم' || r.trns_type_code || '/' || r.trns_serial, r.store_code,
             l_user, l_user)
          returning rowid into l_out;
        end if;
        insert into pr_req_det
          (trns_type_code, trns_serial, req_det_serial, item_code, item_group_code, quantity, unit_code,
           pr_trns_type_code, pr_trns_serial, pr_item_serial, size_code, color_code)
        values
          (l_rfq, l_ser, d.item_serial, d.item_code, nvl(d.group_code, app_rules_pr.item_group(d.item_code)), d.quantity, d.unit_code,
           r.trns_type_code, r.trns_serial, d.item_serial, d.size_code, d.color_code);
        l_n := l_n + 1;
      end if;
    end loop;
    app_rules_sa.set_bypass(false);
    if l_n = 0 then
      err(-20175, 'لم يتم عمل عرض اسعار', 'The operation were canceled');
    end if;
    g_msg := m(' تم عمل عرض أسعار لعدد ' || l_n || ' صنف ' || '(' || l_rfq || '/' || l_ser || ')',
               'Price Proposel Done For ' || l_n || ' Item ' || '(' || l_rfq || '/' || l_ser || ')');
    return rowidtochar(l_out);
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end prq_to_rfq;

  -- =================================================================================== ST_TRANSFER_REQUEST -> ST_TRANSFER_FROM
  function trq_issued (p_type in number, p_serial in number) return boolean is
    l_n number;
  begin
    select count(*) into l_n from st_trns_mast
     where req_trns_type_code = p_type and req_trns_serial = p_serial and nvl(delete_flag, 0) = 0;
    return l_n > 0;
  end trq_issued;

  function can_trq_to_transfer (p_rowid in varchar2) return varchar2 is
    r     st_trns_mast_request%rowtype;
    l_n   number;
    l_rid rowid := rid(p_rowid);
  begin
    select * into r from st_trns_mast_request where rowid = l_rid;
    if nvl(r.delete_flag, 0) = 1 or nvl(r.to_transfer_flag, 0) = 1 or trq_issued(r.trns_type_code, r.trns_serial) then
      return 'N';
    end if;
    select count(*) into l_n from st_trns_det_request where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    return case when l_n > 0 then 'Y' else 'N' end;
  exception when others then
    return 'N';
  end can_trq_to_transfer;

  -- quantity of a lot that an issue line may take at a position without making the lot negative there or later
  -- (GET_BALANCE_CONFG at the position + UPDATE_NEXT_TRNS_CONFG of the transfer screen; APP_RULES_ST.RUN_BALANCE)
  function lot_avail (p_store in number, p_confg in number, p_date in date, p_dser in number, p_iser in number,
                      p_type in number, p_serial in number) return number is
    l_first number;
    l_min   number;
    l_neg   number;
  begin
    app_rules_st.run_balance(p_store, p_confg, p_date, p_dser, p_iser, p_type, p_serial, p_iser, 0, l_first, l_min);
    select nvl(max(neg_sale_balance), 0) into l_neg from st_basic;
    return greatest(case when l_neg = 1 then l_first else least(l_first, l_min) end, 0);
  end lot_avail;

  -- the transfer screen with the request selected (REQ_TRNS_TYPE_CODE / REQ_TRNS_SERIAL): header copied from the request,
  -- ST_TRNSFER row, request lines with lots (earliest expiry with enough stock, split over lots when no single lot has
  -- enough), unit cost of the lot, lot price; the request is marked TO_TRANSFER_FLAG = 1
  function trq_to_transfer (p_rowid in varchar2, p_trns_type in number, p_date in date) return varchar2 is
    r        st_trns_mast_request%rowtype;
    l_rid    rowid := rid(p_rowid);
    l_date   date := trunc(p_date);
    l_serial number;
    l_tser   number;
    l_doc    number;
    l_dser   number;
    l_acc    number;
    l_n      number;
    l_amin   date;
    l_amax   date;
    l_out    rowid;
    l_user   number := usr;
    l_now    date := now_;
    l_iser   number := 0;
    l_group  number;
    l_unit   number;
    l_factor number;
    l_need   number;
    l_take   number;
    l_total  number;
    l_price  number;
    l_desc_a st_trns_mast.desc_a%type;
    lots     t_lots;
    k        pls_integer;
    l_single pls_integer;
    l_lines  number := 0;
  begin
    g_msg := null;
    begin
      select * into r from st_trns_mast_request where rowid = l_rid for update wait 10;
    exception when no_data_found then
      err(-20176, 'طلب التحويل غير موجود', 'The transfer request no longer exists');
    end;
    if nvl(r.delete_flag, 0) = 1 then
      err(-20176, 'طلب التحويل ملغي', 'The transfer request is deleted');
    end if;
    if nvl(r.to_transfer_flag, 0) = 1 or trq_issued(r.trns_type_code, r.trns_serial) then
      err(-20176, 'تم عمل حركة التحويل لهذا الطلب', 'A transfer was already issued for this request');
    end if;
    -- TRNS_TYPE LOV of the transfer screen: EFFECT 5 / TRNS_TYPE 9, ST_TRNSTYPE_PASSWORD.FLAG = 1
    select count(*) into l_n from st_trns_type where trns_type_code = p_trns_type and effect = 5 and trns_type = 9;
    if p_trns_type is null or l_n = 0 or not type_ok(p_trns_type, 1) then
      err(-20176, 'نوع الحركة غير مسموح به فى هذه الشاشة: ' || p_trns_type, 'Transaction type not allowed on this screen: ' || p_trns_type);
    end if;
    if l_date is null then
      err(-20176, 'يجب إدخال تاريخ الحركة', 'Enter the transaction date');
    end if;
    -- REQ_TRNS_TYPE LOV: request date <= transfer date
    if l_date < trunc(r.trns_date) then
      err(-20176, 'تاريخ التحويل يجب ألا يسبق تاريخ طلب التحويل (' || to_char(r.trns_date, 'DD/MM/YYYY') || ')',
          'The transfer date cannot be before the request date (' || to_char(r.trns_date, 'DD/MM/YYYY') || ')');
    end if;
    check_date(-20176, l_date);
    select min(min_date), min(max_date) into l_amin, l_amax from ac_basic;
    if l_amin is not null and l_amax is not null and l_date not between l_amin and l_amax then
      err(-20176, 'تاريخ الحركة خارج الفترة المفتوحة (' || to_char(l_amin, 'DD/MM/YYYY') || ' - ' || to_char(l_amax, 'DD/MM/YYYY') || ')',
          'The transaction date is outside the open period (' || to_char(l_amin, 'DD/MM/YYYY') || ' - ' || to_char(l_amax, 'DD/MM/YYYY') || ')');
    end if;
    -- stores: the request's store issues (REQ LOV: request STORE_CODE = transfer STORE_CODE), destination different
    if r.store_code is null or not store_ok(r.store_code) then
      err(-20176, 'رقم المخزن غير صحيح أو موقوف أو غير مصرح لك به: ' || r.store_code, 'Invalid, stopped or not allowed store: ' || r.store_code);
    end if;
    if r.trnsfer_to_store is null or not store_ok(r.trnsfer_to_store, false) then
      err(-20176, 'يجب إدخال المخزن المحول إليه (مخزن نشط)', 'Enter an active destination store');
    end if;
    if r.trnsfer_to_store = r.store_code then
      err(-20176, 'لا يمكن التحويل إلى نفس المخزن', 'The destination store must differ from the source store');
    end if;
    select count(*) into l_n from st_trns_det_request where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    if l_n = 0 then
      err(-20176, 'لا يمكن حفظ الحركة بدون تفاصيل', 'You can''t save the master without details');
    end if;

    -- header (TRNS_DATE, descriptions, currency, cost centre, account and stores copied from the request)
    select nvl(max(trns_serial), 0) + 1 into l_serial from st_trns_mast where trns_type_code = p_trns_type;
    l_doc := app_rules_st.next_doc_no('ST_TRANSFER_FROM', p_trns_type, r.store_code);
    l_desc_a := nvl(r.desc_a, app_rules_st.type_desc(p_trns_type));
    l_acc := r.account_number1;
    if l_acc is null then
      select count(*) into l_n from staclnk where trns_type_code = p_trns_type and account_no_type = 6;
      if l_n > 0 then
        select max(account_number1) into l_acc from st_store where store_code = r.store_code;
      end if;
    end if;
    select nvl(max(trnsfer_serial), 0) + 1 into l_tser from st_trnsfer where trnsfer_from_store = r.store_code;
    insert into st_trnsfer (trnsfer_serial, trnsfer_date, trnsfer_from_store, trnsfer_to_store, delete_flag, post_flag,
                            approve_flag, trnsfer_doc_no, trnsfer_desc_a, trnsfer_desc_e)
    values (l_tser, l_date, r.store_code, r.trnsfer_to_store, 0, 0, 1, l_doc, l_desc_a, r.desc_e);
    app_rules_sa.set_bypass(true);
    insert into st_trns_mast
      (trns_type_code, trns_serial, trns_date, doc_no, desc_a, desc_e, currency_code, currency_rate, post_flag, delete_flag,
       cost_code, account_number1, store_code, trnsfer_type, trnsfer_serial, trnsfer_from_store, trnsfer_to_store,
       req_trns_type_code, req_trns_serial, insert_user, insert_date, update_user, update_date)
    values
      (p_trns_type, l_serial, l_date, l_doc, l_desc_a, r.desc_e, nvl(r.currency_code, 1), nvl(r.currency_rate, 1), 0, 0,
       r.cost_code, l_acc, r.store_code, 0, l_tser, r.store_code, r.trnsfer_to_store,
       r.trns_type_code, r.trns_serial, l_user, l_now, l_user, l_now)
    returning rowid, date_serial into l_out, l_dser;

    -- lines
    for d in (select * from st_trns_det_request where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial
               order by item_serial) loop
      l_group := nvl(d.group_code, app_rules_pr.item_group(d.item_code));
      l_unit := nvl(d.unit_code, app_rules_pr.basic_unit(l_group, d.item_code));
      l_factor := factor_of(l_group, d.item_code, l_unit);
      l_need := nvl(d.quantity, 0) * l_factor;
      if l_need <= 0 then
        err(-20176, 'الكمية يجب ان تكون أكبر من صفر - الصنف ' || d.item_code, 'The quantity must be greater than zero - item ' || d.item_code);
      end if;
      lots.delete;
      k := 0;
      l_total := 0;
      l_single := null;
      for c in (select item_confg_id from st_item_confg where group_code = l_group and item_code = d.item_code
                 order by expire_date nulls last, item_confg_id) loop
        l_take := lot_avail(r.store_code, c.item_confg_id, l_date, l_dser, l_iser + 1, p_trns_type, l_serial);
        l_take := trunc(l_take / l_factor) * l_factor;
        if l_take > 0 then
          k := k + 1;
          lots(k).confg := c.item_confg_id;
          lots(k).avail := l_take;
          l_total := l_total + l_take;
          if l_single is null and l_take >= l_need then l_single := k; end if;
        end if;
      end loop;
      if l_total < l_need then
        err(-20176, 'رصيد الصنف فى هذا التاريخ لا يسمح، الصنف = ' || d.item_code || '، الرصيد المتاح = ' || l_total / l_factor,
            'Item balance at this date does not allow, item = ' || d.item_code || ', available = ' || l_total / l_factor);
      end if;
      for i in 1 .. lots.count loop
        exit when l_need <= 0;
        if l_single is null or i = l_single then
          l_take := least(lots(i).avail, l_need);
          l_iser := l_iser + 1;
          select nvl(d.unit_price, max(unit_price)) into l_price from st_item_confg where item_confg_id = lots(i).confg;
          insert into st_trns_det
            (trns_type_code, trns_serial, item_serial, group_code, item_code, unit_code, item_confg_id, quantity, basic_qty,
             unit_cost, unit_price, cost_flag, trnsfer_serial, trnsfer_from_store, trnsfer_to_store,
             freight, customs, transport, insurance, commission, others)
          values
            (p_trns_type, l_serial, l_iser, l_group, d.item_code, l_unit, lots(i).confg, l_take / l_factor, l_take,
             get_unit_cost_confg(r.store_code, l_group, d.item_code, lots(i).confg, l_date, l_dser, l_iser), l_price, 1,
             l_tser, r.store_code, r.trnsfer_to_store, 0, 0, 0, 0, 0, 0);
          l_need := l_need - l_take;
          l_lines := l_lines + 1;
        end if;
      end loop;
    end loop;
    update st_trns_mast_request set to_transfer_flag = 1 where rowid = l_rid;
    app_rules_sa.set_bypass(false);
    g_msg := m('تم عمل حركة التحويل رقم ' || p_trns_type || '/' || l_serial, 'Transfer Inserted No. ' || p_trns_type || '/' || l_serial);
    return rowidtochar(l_out);
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end trq_to_transfer;

  -- =================================================================================== ST_PRICE_PROPOSAL -> quotation / transfer request / transfer
  -- live documents made from a quotation: another quotation (PROPOSAL_TRNS_*), a transfer request (PROPOSAL_TRNS_*), an issue
  -- transfer (ST_TRNS_MAST.PRO_TRNS_*; legacy POST-QUERY: DELETE_DATE IS NULL)
  function qt_split_exists (p_type in number, p_serial in number) return boolean is
    l_n number;
  begin
    select count(*) into l_n from st_proposal_mast
     where proposal_trns_type_code = p_type and proposal_trns_serial = p_serial and nvl(delete_flag, 0) = 0;
    return l_n > 0;
  end qt_split_exists;

  function qt_trq_exists (p_type in number, p_serial in number) return boolean is
    l_n number;
  begin
    select count(*) into l_n from st_trns_mast_request
     where proposal_trns_type_code = p_type and proposal_trns_serial = p_serial and nvl(delete_flag, 0) = 0;
    return l_n > 0;
  end qt_trq_exists;

  function qt_transfer_exists (p_type in number, p_serial in number) return boolean is
    l_n number;
  begin
    select count(*) into l_n from st_trns_mast
     where pro_trns_type_code = p_type and pro_trns_serial = p_serial and delete_date is null;
    return l_n > 0;
  end qt_transfer_exists;

  -- PROPOSAL_TRNS_TYPE / TRANSFER_REQ_TRNS WHEN-VALIDATE-ITEM: the store of the type when it is active (the store item is then
  -- disabled), otherwise the store the user entered (ST_STORE list: active, allowed for the group)
  function qt_target_store (p_type in number, p_store in number) return number is
    l number;
  begin
    select max(t.store_code) into l from st_trns_type t
     where t.trns_type_code = p_type
       and t.store_code in (select s.store_code from st_store s where s.store_status = 1 and s.stop_flag = 0);
    return nvl(l, p_store);
  end qt_target_store;

  -- the approval checks of the conversion buttons
  procedure qt_flags (q in st_proposal_mast%rowtype, p_code in pls_integer, p_accept in boolean default true) is
  begin
    if nvl(q.approve, 0) <> 1 then
      err(p_code, 'يجب إعتماد الإدارة أولا', 'Must Management Approval First');
    end if;
    if nvl(q.approve2, 0) <> 1 then
      err(p_code, 'يجب إعتماد الإدارة 2 أولا', 'Must Management Approval 2 First');
    end if;
    if p_accept and nvl(q.cust_accept_flag, 0) = 0 then
      err(p_code, 'يجب إعتماد العميل أولا', 'Must Customer Approval First');
    end if;
  end qt_flags;

  function qt_lock (p_rowid in varchar2, p_code in pls_integer) return st_proposal_mast%rowtype is
    q     st_proposal_mast%rowtype;
    l_rid rowid := rid(p_rowid);
  begin
    begin
      select * into q from st_proposal_mast where rowid = l_rid for update wait 10;
    exception when no_data_found then
      err(p_code, 'عرض السعر غير موجود (ربما حذف من مستخدم آخر)', 'The quotation no longer exists');
    end;
    if nvl(q.delete_flag, 0) = 1 then
      err(p_code, 'عرض السعر ملغي', 'The quotation is deleted');
    end if;
    return q;
  end qt_lock;

  -- TO_PROPOSAL_BTN / TO_TRANSFER_REQ / TRNSFER_FROM_BTN: the buttons worked on an approved (1 and 2), customer-accepted
  -- quotation that was not converted that way yet
  function can_quote_to_proposal (p_rowid in varchar2) return varchar2 is
    q     st_proposal_mast%rowtype;
    l_rid rowid := rid(p_rowid);
  begin
    select * into q from st_proposal_mast where rowid = l_rid;
    if nvl(q.delete_flag, 0) = 1 or nvl(q.approve, 0) <> 1 or nvl(q.approve2, 0) <> 1 or nvl(q.cust_accept_flag, 0) <> 1
       or qt_split_exists(q.trns_type_code, q.trns_serial) then
      return 'N';
    end if;
    return 'Y';
  exception when others then
    return 'N';
  end can_quote_to_proposal;

  function can_quote_to_trq (p_rowid in varchar2) return varchar2 is
    q     st_proposal_mast%rowtype;
    l_rid rowid := rid(p_rowid);
  begin
    select * into q from st_proposal_mast where rowid = l_rid;
    if nvl(q.delete_flag, 0) = 1 or nvl(q.approve, 0) <> 1 or nvl(q.approve2, 0) <> 1 or nvl(q.cust_accept_flag, 0) <> 1
       or qt_trq_exists(q.trns_type_code, q.trns_serial) then
      return 'N';
    end if;
    return 'Y';
  exception when others then
    return 'N';
  end can_quote_to_trq;

  function can_quote_to_transfer (p_rowid in varchar2) return varchar2 is
    q     st_proposal_mast%rowtype;
    l_rid rowid := rid(p_rowid);
  begin
    select * into q from st_proposal_mast where rowid = l_rid;
    if nvl(q.delete_flag, 0) = 1 or nvl(q.salesman_done, 0) <> 1 or nvl(q.approve, 0) <> 1 or nvl(q.approve2, 0) <> 1
       or nvl(q.cust_accept_flag, 0) <> 1 or qt_order_exists(q.trns_type_code, q.trns_serial)
       or qt_transfer_exists(q.trns_type_code, q.trns_serial) then
      return 'N';
    end if;
    return 'Y';
  exception when others then
    return 'N';
  end can_quote_to_transfer;

  -- TO_PROPOSAL_BTN + MAKE_PROPOSAL + INSERT_ANOTHER_PROPOSAL / INSERT_PROPOSAL_DET: the lines marked unavailable (CHOICE_FLAG 0,
  -- UNAVAILABLE_FLAG 1) are copied into a new quotation of another quotation type (another store)
  function quote_to_proposal (p_rowid in varchar2, p_type in number, p_store in number, p_date in date) return varchar2 is
    q        st_proposal_mast%rowtype;
    l_date   date := trunc(p_date);
    l_store  number;
    l_serial number;
    l_dser   number;
    l_inv    varchar2(100);
    l_doc    number;
    l_n      number;
    l_total  number;
    l_line   number;
    l_bq     number;
    l_desc_a varchar2(4000);
    l_desc_e varchar2(4000);
    l_out    rowid;
    l_user   number := usr;
    l_now    date := now_;
  begin
    g_msg := null;
    q := qt_lock(p_rowid, -20177);
    -- TO_PROPOSAL_BTN
    qt_flags(q, -20177);
    if qt_split_exists(q.trns_type_code, q.trns_serial) then
      err(-20177, 'عرض السعر تم ترحيلة إلي عرض السعر', 'Price Proposal Posted To Price Proposal');
    end if;
    -- PROPOSAL_TRNS_TYPE_RG: quotation types of another store, not this type, group rights (FLAG 1)
    if p_type is not null then
      select count(*) into l_n from st_trns_type
       where trns_type_code = p_type and effect = 7 and nvl(trns_type, 0) = 16 and nvl(join_type, 0) in (3, 4)
         and trns_type_code <> q.trns_type_code and store_code <> q.store_code;
      if l_n = 0 or not type_ok(p_type, 1) then
        err(-20177, 'نوع الحركة غير مسموح به فى هذه الشاشة: ' || p_type, 'Transaction type not allowed on this screen: ' || p_type);
      end if;
    end if;
    -- MAKE_PROPOSAL
    l_store := qt_target_store(p_type, p_store);
    if l_store is null then
      err(-20177, 'يجب ادخال المخزن أولا', 'Must Insert Store First');
    end if;
    if not store_ok(l_store) then
      err(-20177, 'رقم المخزن غير صحيح أو موقوف أو غير مصرح لك به: ' || l_store, 'Invalid, stopped or not allowed store: ' || l_store);
    end if;
    if p_type is null or l_date is null then
      err(-20177, 'يجب تعريف رقم حركة عرض سعر البيع و تاريخ عرض سعر البيع', 'Price Proposal Trns and Price Proposal Date Must Be Entered');
    end if;
    -- INSERT_ANOTHER_PROPOSAL (the total keeps the legacy operator precedence: price - discounts x rate x quantity)
    select count(*), sum(nvl(d.unit_price_curr, 0) - ((nvl(d.disc1_value, 0) + nvl(d.disc2_value, 0) + nvl(d.disc3_value, 0))
                                                        * nvl(q.currency_rate, 1)) * nvl(d.quantity, 0))
      into l_n, l_total
      from st_proposal_det d
     where d.trns_type_code = q.trns_type_code and d.trns_serial = q.trns_serial
       and nvl(d.choice_flag, 0) = 0 and nvl(d.unavailable_flag, 0) = 1;
    if l_n = 0 then
      err(-20177, 'لايمكن التحويل الي عرض سعر بدون اختيار الأصناف', 'There is no Choice Items to Make another Proposal Price');
    end if;
    select nvl(max(nvl(date_serial, 0)) + 1, 1) into l_dser from st_proposal_mast where trns_date = l_date;
    select nvl(max(trns_serial), 0) + 1 into l_serial from st_proposal_mast where trns_type_code = p_type;
    l_desc_a := 'عرض سعر رقم ' || p_type || '/' || l_serial || ' من عرض أسعار رقم  ' || q.trns_type_code || '/' || q.trns_serial;
    l_desc_e := 'Price Proposal No. ' || p_type || '/' || l_serial || ' From Price Proposal No.  ' || q.trns_type_code || '/' || q.trns_serial;
    select to_char(nvl(max(nvl(invoice_no, 0)) + 1, 1)) into l_inv from st_proposal_mast;
    -- GET_NEXT_DOC_NO(:ST_PROPOSAL_MAST.TRNS_TYPE_CODE): next DOC_NO of the source quotation's type
    select nvl(max(tm.doc_no), 0) + 1 into l_doc
      from st_proposal_mast tm, st_trns_type tt
     where tm.trns_type_code = tt.trns_type_code and tm.trns_type_code = q.trns_type_code
       and nvl(tt.effect, 0) = 7 and nvl(tt.trns_type, 0) = 16;
    app_rules_sa.set_bypass(true);
    insert into st_proposal_mast
      (trns_type_code, trns_serial, trns_date, date_serial, store_code, doc_no, invoice_no, desc_a, desc_e, currency_code,
       currency_rate, trnsport_val, customer_code, salesman_code, delete_flag, cust_accept_flag, pay_term, other_terms,
       proposal_expire, insert_user, insert_date, offer_expiry, rfq, tax_code1, tax_value1, tot_disc1_ratio, tot_disc2_ratio,
       tot_disc3_ratio, tot_disc1_value, tot_disc2_value, tot_disc3_value, proposal_trns_type_code, proposal_trns_serial)
    values
      (p_type, l_serial, l_date, l_dser, l_store, l_doc, l_inv, l_desc_a, l_desc_e, q.currency_code,
       q.currency_rate, 0, q.customer_code, q.salesman_code, q.delete_flag, q.cust_accept_flag, q.pay_term, q.other_terms,
       q.proposal_expire, l_user, l_now, q.offer_expiry, null, q.tax_code1, q.tax_value1, q.tot_disc1_ratio, q.tot_disc2_ratio,
       q.tot_disc3_ratio, (q.tot_disc1_ratio * l_total) / 100,
       (q.tot_disc2_ratio * (l_total - ((q.tot_disc1_ratio * l_total) / 100)) / 100),
       (q.tot_disc3_ratio * (l_total - ((q.tot_disc1_ratio * l_total) / 100) - ((q.tot_disc2_ratio * l_total) / 100)) / 100),
       q.trns_type_code, q.trns_serial)
    returning rowid into l_out;
    for c in (select * from st_proposal_det
               where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial
                 and nvl(choice_flag, 0) = 0 and nvl(unavailable_flag, 0) = 1
               order by item_serial) loop
      select nvl(max(item_serial), 0) + 1 into l_line from st_proposal_det where trns_type_code = p_type and trns_serial = l_serial;
      begin
        select nvl(factor, 1) * (nvl(c.quantity, 0) + nvl(c.bonus, 0) + nvl(c.extra_bonus, 0)) into l_bq
          from st_item_unit where item_code = c.item_code and group_code = c.group_code and unit_code = c.unit_code;
      exception when others then
        l_bq := nvl(c.quantity, 0) + nvl(c.bonus, 0) + nvl(c.extra_bonus, 0);
      end;
      insert into st_proposal_det
        (trns_type_code, trns_serial, store_code, date_serial, item_serial, group_code, item_code, item_confg_id, quantity,
         temp_quantity, bonus, basic_qty, cost_flag, unit_code, unit_price, unit_price_curr, disc1_ratio, disc2_ratio, disc1_value,
         disc2_value, delete_flag, disc, det_disc, trns_date, remark, tax_value1, tax_code1, tax_value2, tax_code2, disc3_ratio,
         disc3_value, bonus_ratio, extra_bonus_ratio, extra_bonus, auto_disc, choice_flag, unavailable_flag,
         proposal_trns_type_code, proposal_trns_serial, proposal_item_serial, org_class_code, org_disc1_ratio, org_disc2_ratio,
         org_disc3_ratio, org_bonus_ratio, org_extra_bonus_ratio, org_unit_price_curr, last_expire_date)
      values
        (p_type, l_serial, l_store, l_dser, l_line, c.group_code, c.item_code, c.item_confg_id, c.quantity,
         c.temp_quantity, c.bonus, l_bq, c.cost_flag, c.unit_code, c.unit_price, c.unit_price_curr, c.disc1_ratio, c.disc2_ratio, c.disc1_value,
         c.disc2_value, c.delete_flag, c.disc, c.det_disc, l_date, c.remark, c.tax_value1, c.tax_code1, c.tax_value2, c.tax_code2, c.disc3_ratio,
         c.disc3_value, c.bonus_ratio, c.extra_bonus_ratio, c.extra_bonus, c.auto_disc, 0, 0,
         q.trns_type_code, q.trns_serial, c.item_serial, c.org_class_code, c.org_disc1_ratio, c.org_disc2_ratio,
         c.org_disc3_ratio, c.org_bonus_ratio, c.org_extra_bonus_ratio, c.org_unit_price_curr, c.last_expire_date);
    end loop;
    app_rules_sa.set_bypass(false);
    g_msg := m('تم عمل سعر بيع رقم ' || p_type || '/' || l_serial, 'Proposal Price Inserted No. ' || p_type || '/' || l_serial);
    return rowidtochar(l_out);
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end quote_to_proposal;

  -- TO_TRANSFER_REQ + MAKE_TRANSFER_REQ + INSERT_TRANSFER_REQ / INSERT_TRANSFER_REQ_DET: the unavailable lines are requested from
  -- another store (the store of the transfer-request type) to the quotation's store
  function quote_to_trq (p_rowid in varchar2, p_type in number, p_store in number, p_date in date) return varchar2 is
    q        st_proposal_mast%rowtype;
    l_date   date := trunc(p_date);
    l_store  number;
    l_serial number;
    l_dser   number;
    l_doc    number;
    l_n      number;
    l_line   number;
    l_bq     number;
    l_desc_a varchar2(4000);
    l_desc_e varchar2(4000);
    l_out    rowid;
  begin
    g_msg := null;
    q := qt_lock(p_rowid, -20178);
    -- TO_TRANSFER_REQ (an existing quotation split was only reported)
    qt_flags(q, -20178);
    if p_type is not null then
      -- TRANSFER_TRNS_RG: transfer-request types of another store, group rights (FLAG 1)
      select count(*) into l_n from st_trns_type
       where trns_type_code = p_type and effect = 7 and nvl(trns_type, 0) = 9
         and trns_type_code <> q.trns_type_code and store_code <> q.store_code;
      if l_n = 0 or not type_ok(p_type, 1) then
        err(-20178, 'نوع الحركة غير مسموح به فى هذه الشاشة: ' || p_type, 'Transaction type not allowed on this screen: ' || p_type);
      end if;
    end if;
    -- TRANSFER_REQ_DATE WHEN-VALIDATE-ITEM
    if l_date is not null then
      if l_date < trunc(q.trns_date) then
        err(-20178, 'تاريخ طلب التحويل يجب أن يكون أكبر من يساوى تارخ عرض السعر', 'Transfer Request Date Must Be Greater Than Or Equal Proposal Date ');
      end if;
      check_date(-20178, l_date);
    end if;
    -- MAKE_TRANSFER_REQ: the transfer request exists already -> nothing is made
    if qt_trq_exists(q.trns_type_code, q.trns_serial) then
      err(-20178, 'عرض السعر تم ترحيلة إلي طلب تحويل', 'Price Proposal Posted To Transfer Request');
    end if;
    if p_type is null or l_date is null then
      err(-20178, 'يجب تعريف رقم حركة طلب تحويل و تاريخ طلب التحويل', 'Transfer Trns and Transfer Date Must Be Entered');
    end if;
    l_store := qt_target_store(p_type, p_store);
    if l_store is null or not store_ok(l_store) then
      err(-20178, 'يجب إدخال مخزن طلب التحويل (مخزن نشط مصرح به)', 'Enter an active, allowed store for the transfer request');
    end if;
    -- INSERT_TRANSFER_REQ
    select count(*) into l_n from st_proposal_det
     where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial
       and nvl(choice_flag, 0) = 0 and nvl(unavailable_flag, 0) = 1;
    if l_n = 0 then
      err(-20178, 'لايمكن التحويل الي طلب تحويل بدون اختيار الأصناف', 'There is no Choice Items to Make Transfer Request');
    end if;
    select nvl(max(nvl(date_serial, 0)) + 1, 1) into l_dser from st_trns_mast_request where trns_date = l_date;
    select nvl(max(trns_serial), 0) + 1 into l_serial from st_trns_mast_request where trns_type_code = p_type;
    l_desc_a := 'طلب تحويل رقم ' || p_type || '/' || l_serial || ' من عرض أسعار رقم  ' || q.trns_type_code || '/' || q.trns_serial;
    l_desc_e := 'Transfer Request No. ' || p_type || '/' || l_serial || ' From Price Proposal No.  ' || q.trns_type_code || '/' || q.trns_serial;
    select nvl(max(doc_no), 0) + 1 into l_doc from st_trns_mast_request where trns_type_code = p_type;
    insert into st_trns_mast_request
      (trns_serial, doc_no, trns_date, date_serial, desc_a, desc_e, currency_rate, post_flag, delete_flag, trns_type_code,
       currency_code, store_code, trnsfer_from_store, trnsfer_to_store, to_transfer_flag, close_flag,
       proposal_trns_type_code, proposal_trns_serial)
    values
      (l_serial, l_doc, l_date, l_dser, l_desc_a, l_desc_e, q.currency_rate, 0, 0, p_type,
       q.currency_code, l_store, l_store, q.store_code, 0, 0,
       q.trns_type_code, q.trns_serial)
    returning rowid into l_out;
    for c in (select * from st_proposal_det
               where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial
                 and nvl(choice_flag, 0) = 0 and nvl(unavailable_flag, 0) = 1
               order by item_serial) loop
      select nvl(max(item_serial), 0) + 1 into l_line from st_trns_det_request where trns_type_code = p_type and trns_serial = l_serial;
      -- INSERT_TRANSFER_REQ_DET: BASIC_QTY = factor x the quotation line's BASIC_QTY (legacy arithmetic)
      begin
        select nvl(factor, 1) * nvl(c.basic_qty, 0) into l_bq
          from st_item_unit where item_code = c.item_code and group_code = c.group_code and unit_code = c.unit_code;
      exception when others then
        l_bq := nvl(c.basic_qty, 0);
      end;
      -- DET_REC.STORE_CODE := :PROPOSAL_STORE_CODE, an item of the other window (empty in this flow)
      insert into st_trns_det_request
        (item_serial, quantity, basic_qty, cost_flag, trns_type_code, trns_serial, unit_code, group_code, item_code, store_code,
         proposal_trns_type_code, proposal_trns_serial, proposal_item_serial)
      values
        (l_line, nvl(c.transfer_qty, nvl(c.quantity, 0) + nvl(c.bonus, 0) + nvl(c.extra_bonus, 0)), l_bq, c.cost_flag, p_type,
         l_serial, c.unit_code, c.group_code, c.item_code, null,
         c.trns_type_code, c.trns_serial, c.item_serial);
    end loop;
    g_msg := m('تم عمل طلب تحويل رقم ' || p_type || '/' || l_serial, 'Transfer Request Inserted No. ' || p_type || '/' || l_serial);
    return rowidtochar(l_out);
  end quote_to_trq;

  -- TRNSFER_FROM_BTN + MAKE_TRNSFER_FROM + INSERT_TRNSFR_FROM_TRNS / DEVIDE_CONFGS_TRNSFER / INSERT_TRNSFR_FROM_DET: the chosen and
  -- available lines leave the quotation's store on an issue transfer (lots: the quotation lot first, then by expiry), and the
  -- receipt of the transfer in the destination store is written at once (ST_TRNSFER received)
  function quote_to_transfer (p_rowid in varchar2, p_from_type in number, p_to_type in number, p_to_store in number,
                              p_date in date) return varchar2 is
    q         st_proposal_mast%rowtype;
    l_date    date := trunc(p_date);
    l_serial  number;
    l_serial2 number;
    l_tser    number;
    l_doc     number;
    l_n       number;
    l_dser    number;
    l_iser    number := 0;
    l_factor  number;
    l_rest    number;
    l_take    number;
    l_bal     number;
    l_avail   number;
    l_has     number;
    l_price   number;
    l_price_c number;
    l_desc_a  varchar2(4000);
    l_desc_e  varchar2(4000);
    l_out     rowid;
    l_user    number := usr;
    l_now     date := now_;
    lots      t_lots;
    k         pls_integer;
  begin
    g_msg := null;
    q := qt_lock(p_rowid, -20179);
    -- TRNSFER_FROM_BTN (the count of lines not chosen and a total differing from the chosen total were only reported)
    if qt_order_exists(q.trns_type_code, q.trns_serial) then
      err(-20179, 'عرض السعر تم ترحيلة إلي أمر بيع', 'Price Proposal Posted To Sales Order');
    end if;
    qt_credit(q);
    qt_flags(q, -20179);
    -- MAKE_TRNSFER_FROM: the four flags re-read
    if nvl(q.salesman_done, 0) <> 1 or nvl(q.approve2, 0) <> 1 or nvl(q.approve, 0) <> 1 or nvl(q.cust_accept_flag, 0) <> 1 then
      err(-20179, 'يجب الإعتماد أولا', 'Must Approve First');
    end if;
    if p_from_type is null or p_to_type is null or l_date is null or p_to_store is null then
      err(-20179, 'يجب إدخال رقم حركة التحويل و تاريخ التحويل', 'Transfer Trns And Transfer Date Must Be Entered ');
    end if;
    -- TRNSFR_FROM / TRNSFR_TO lists: issue (5/9) and receipt (6/9) transfer types, group rights (FLAG 1); ST_STORE list
    select count(*) into l_n from st_trns_type where trns_type_code = p_from_type and nvl(effect, 0) = 5 and nvl(trns_type, 0) = 9;
    if l_n = 0 or not type_ok(p_from_type, 1) then
      err(-20179, 'نوع الحركة غير مسموح به فى هذه الشاشة: ' || p_from_type, 'Transaction type not allowed on this screen: ' || p_from_type);
    end if;
    select count(*) into l_n from st_trns_type where trns_type_code = p_to_type and nvl(effect, 0) = 6 and nvl(trns_type, 0) = 9;
    if l_n = 0 or not type_ok(p_to_type, 1) then
      err(-20179, 'نوع الحركة غير مسموح به فى هذه الشاشة: ' || p_to_type, 'Transaction type not allowed on this screen: ' || p_to_type);
    end if;
    if not store_ok(p_to_store) then
      err(-20179, 'رقم المخزن غير صحيح أو موقوف أو غير مصرح لك به: ' || p_to_store, 'Invalid, stopped or not allowed store: ' || p_to_store);
    end if;
    -- a transfer made already: the legacy button then did nothing
    if qt_transfer_exists(q.trns_type_code, q.trns_serial) then
      err(-20179, 'تم عمل حركة تحويل من عرض السعر من قبل', 'A transfer was already made from this quotation');
    end if;
    -- INSERT_TRNSFR_FROM_TRNS
    select count(*) into l_n from st_proposal_det
     where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial
       and nvl(choice_flag, 0) = 1 and nvl(unavailable_flag, 0) = 0;
    if l_n = 0 then
      err(-20179, 'لايمكن التحويل بدون اختيار الأصناف', 'There is no Choice Items');
    end if;
    select nvl(max(trns_serial), 0) + 1 into l_serial from st_trns_mast where trns_type_code = p_from_type;
    l_desc_a := 'بموجب سند تحويل اتوماتيك رقم ' || p_from_type || '/' || l_serial || ' من عرض أسعار رقم  ' || q.trns_type_code || '/' || q.trns_serial;
    l_desc_e := 'Automatic Transfer Number ' || p_from_type || '/' || l_serial || ' From Price Proposal No.  ' || q.trns_type_code || '/' || q.trns_serial;
    l_doc := to_number(to_char(q.trns_type_code) || lpad(to_char(q.trns_serial), 6, '0'));
    select nvl(max(trnsfer_serial), 0) + 1 into l_tser from st_trnsfer where trnsfer_from_store = q.store_code;
    insert into st_trnsfer (trnsfer_serial, trnsfer_date, trnsfer_from_store, trnsfer_to_store, delete_flag, post_flag,
                            approve_flag, trnsfer_doc_no, trnsfer_desc_a, trnsfer_desc_e)
    values (l_tser, l_date, q.store_code, p_to_store, 0, 0, 1, l_doc, l_desc_a, l_desc_e);
    app_rules_sa.set_bypass(true);
    insert into st_trns_mast
      (trns_serial, doc_no, trns_date, date_serial, desc_a, desc_e, currency_rate, post_flag, delete_flag, trns_type_code,
       currency_code, store_code, trnsfer_type, trnsfer_serial, trnsfer_from_store, trnsfer_to_store, insert_user,
       pro_trns_type_code, pro_trns_serial)
    values
      (l_serial, l_doc, l_date, 999999999, l_desc_a, l_desc_e, nvl(q.currency_rate, 1), 0, 0, p_from_type,
       nvl(q.currency_code, 1), q.store_code, 0, l_tser, q.store_code, p_to_store, l_user,
       q.trns_type_code, q.trns_serial)
    returning rowid, date_serial into l_out, l_dser;
    select nvl(max(has_sales_price), 0) into l_has from st_trns_type where trns_type_code = q.trns_type_code;
    for c in (select * from st_proposal_det
               where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial
                 and nvl(choice_flag, 0) = 1 and nvl(unavailable_flag, 0) = 0
               order by item_serial) loop
      begin
        select nvl(iu.factor, 1) into l_factor from st_item_unit iu, st_unit un
         where iu.unit_code = un.unit_code and iu.group_code = c.group_code and iu.item_code = c.item_code and iu.unit_code = c.unit_code;
      exception when no_data_found then
        l_factor := 1;
      end;
      -- DEVIDE_CONFGS_TRNSFER: the quotation lot (not expired, with stock) first, then the other lots with stock by expiry
      lots.delete;
      k := 0;
      for r in (select item_confg_id, 0 ord, expire_date, lot_number, unit_price, supplier_code, disc_ratio from st_item_confg
                 where group_code = c.group_code and item_code = c.item_code and item_confg_id = c.item_confg_id and expire_date > l_now
                union all
                select item_confg_id, 1 ord, expire_date, lot_number, unit_price, supplier_code, disc_ratio from st_item_confg
                 where group_code = c.group_code and item_code = c.item_code and expire_date > l_now
                   and (item_confg_id <> c.item_confg_id or c.item_confg_id is null)
                 order by 2, 3, 4, 5, 6, 7, 1) loop
        l_bal := lot_bal(q.store_code, c.group_code, c.item_code, r.item_confg_id);
        if l_bal > 0 then k := k + 1; lots(k).confg := r.item_confg_id; lots(k).avail := l_bal; end if;
      end loop;
      -- quantity, bonus and extra bonus travel together: the issue line carries QUANTITY = qty + bonus + extra
      l_rest := (nvl(c.quantity, 0) + nvl(c.bonus, 0) + nvl(c.extra_bonus, 0)) * l_factor;
      for i in 1 .. lots.count loop
        exit when l_rest <= 0;
        l_bal := trunc(lots(i).avail / l_factor) * l_factor;
        if l_bal > 0 then
          l_take := least(l_bal, l_rest);
          l_iser := l_iser + 1;
          -- INSERT_TRNSFR_FROM_DET: lot balance at the document position and no later movement negative. UNIT_COST: the legacy
          -- inserted NULL, which the receipt copied (a zero-cost receipt in the destination store); the issue line takes the
          -- lot's average cost as on the transfer screen (ST_TRANSFER_FROM) so that the receipt carries the cost
          l_avail := lot_avail(q.store_code, lots(i).confg, l_date, l_dser, l_iser, p_from_type, l_serial);
          if l_avail < l_take then
            err(-20179, 'رصيــد هذه الشحنة لهذا صنف فى هذا التاريخ لا يسمــح  .... !!! الصنف = ' || c.item_code,
                'Lot Balance For This Item in This Date Can''t Allow....!!! Item = ' || c.item_code);
          end if;
          if l_has <> 1 then
            select unit_price, unit_price into l_price, l_price_c from st_item_confg where item_confg_id = lots(i).confg;
          else
            l_price := c.unit_price; l_price_c := c.unit_price_curr;
          end if;
          insert into st_trns_det
            (item_serial, quantity, unit_cost, unit_price, unit_price_curr, basic_qty, cost_flag, trns_type_code, trns_serial,
             unit_code, group_code, item_code, store_code, item_confg_id, trns_date, date_serial, delete_flag,
             trnsfer_serial, trnsfer_from_store, trnsfer_to_store)
          values
            (l_iser, l_take / l_factor,
             get_unit_cost_confg(q.store_code, c.group_code, c.item_code, lots(i).confg, l_date, l_dser, l_iser),
             l_price, l_price_c, l_take, 1, p_from_type, l_serial,
             c.unit_code, c.group_code, c.item_code, q.store_code, lots(i).confg, l_date, l_dser, 0,
             l_tser, q.store_code, p_to_store);
          l_rest := l_rest - l_take;
        end if;
      end loop;
      if l_rest > 0 then
        err(-20179, 'أقصى كمية يمكن إخراجها حتى لا تتعارض مع الحركات التالية = ' || l_rest / l_factor || ' للصنف ' || c.item_code,
            'Maximum Amount Can Be Sold Without Conflicting With Next Transactions = ' || l_rest / l_factor || ' For item ' || c.item_code);
      end if;
    end loop;
    -- the receipt in the destination store (TRNSFER_TO_TRNS_TYPE), the transfer received
    select nvl(max(trns_serial), 0) + 1 into l_serial2 from st_trns_mast where trns_type_code = p_to_type;
    insert into st_trns_mast
      (trns_serial, doc_no, trns_date, date_serial, desc_a, currency_rate, freight_val, customs_val, trnsport_val, insurance_val,
       commission_val, others_val, post_flag, delete_flag, trns_type_code, currency_code, store_code, trnsfer_type, trnsfer_serial,
       trnsfer_from_store, trnsfer_to_store, insert_user, insert_date, taking_flag)
    values
      (l_serial2, l_doc, l_date, 999999999,
       'بموجب سند تحويل اتوماتيك رقم ' || p_to_type || '/' || l_serial2 || ' من عرض أسعار رقم  ' || q.trns_type_code || '/' || q.trns_serial,
       nvl(q.currency_rate, 1), 0, 0, 0, 0, 0, 0, 0, 0, p_to_type, nvl(q.currency_code, 1), p_to_store, 1, l_tser,
       q.store_code, p_to_store, l_user, l_now, 0);
    insert into st_trns_det
      (item_serial, quantity, unit_cost, unit_price, basic_qty, cost_flag, trns_type_code, trns_serial, unit_code, group_code,
       item_code, freight, customs, transport, store_code, item_confg_id, others, insurance, commission, trns_date, date_serial,
       delete_flag, trnsfer_serial, trnsfer_from_store, trnsfer_to_store)
    select item_serial, quantity, unit_cost, unit_price, basic_qty, 1, p_to_type, l_serial2, unit_code, group_code,
           item_code, 0, 0, 0, p_to_store, item_confg_id, 0, 0, 0, l_date, 999999999,
           0, l_tser, q.store_code, p_to_store
      from st_trns_det
     where trns_type_code = p_from_type and trns_serial = l_serial
     order by item_serial;
    update st_trnsfer set trnsfer_receiving_date = l_date where trnsfer_serial = l_tser and trnsfer_from_store = q.store_code;
    if q.doc_no is null then
      update st_proposal_mast set doc_no = l_doc where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial;
    end if;
    app_rules_sa.set_bypass(false);
    g_msg := m('تم عمل حركة التحويل رقم ' || p_from_type || '/' || l_serial, 'Transfer Inserted No. ' || p_from_type || '/' || l_serial);
    return rowidtochar(l_out);
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end quote_to_transfer;

  -- =================================================================================== parameter defaults
  function first_target_type (p_what in varchar2, p_rowid in varchar2) return number is
    r     st_item_req%rowtype;
    t     st_trns_mast_request%rowtype;
    q     st_proposal_mast%rowtype;
    l     number;
    l_rid rowid := rid(p_rowid);
  begin
    if p_what in ('QT_PROPOSAL', 'QT_TRQ', 'QT_TRF_FROM', 'QT_TRF_TO') then
      select * into q from st_proposal_mast where rowid = l_rid;
      if p_what = 'QT_TRF_FROM' then
        select max(trnsfer_from_trns_type) into l from st_trns_type where trns_type_code = q.trns_type_code;
        return l;
      elsif p_what = 'QT_TRF_TO' then
        select max(trnsfer_to_trns_type) into l from st_trns_type where trns_type_code = q.trns_type_code;
        return l;
      end if;
      for c in (select trns_type_code from st_trns_type
                 where effect = 7 and nvl(trns_type, 0) = case when p_what = 'QT_PROPOSAL' then 16 else 9 end
                   and (p_what = 'QT_TRQ' or nvl(join_type, 0) in (3, 4))
                   and trns_type_code <> q.trns_type_code and store_code <> q.store_code
                 order by trns_type_code) loop
        if type_ok(c.trns_type_code, 1) then return c.trns_type_code; end if;
      end loop;
      return null;
    end if;
    if p_what in ('REQ_TRANSFER', 'REQ_PURCHASE') then
      select * into r from st_item_req where rowid = l_rid;
      for c in (select trns_type_code from st_trns_type
                 where effect = 7 and trns_type = case when p_what = 'REQ_TRANSFER' then 9 else 13 end and store_code is not null
                 order by trns_type_code) loop
        if req_type_ok(r, c.trns_type_code, p_what = 'REQ_TRANSFER') then return c.trns_type_code; end if;
      end loop;
    elsif p_what = 'TRQ_TRANSFER' then
      select * into t from st_trns_mast_request where rowid = l_rid;
      for c in (select trns_type_code from st_trns_type where effect = 5 and trns_type = 9
                 order by case when store_code = t.store_code then 0 else 1 end, trns_type_code) loop
        if type_ok(c.trns_type_code, 1) then return c.trns_type_code; end if;
      end loop;
    end if;
    return null;
  exception when others then
    return null;
  end first_target_type;

end app_conv;
/
show errors package body app_conv
