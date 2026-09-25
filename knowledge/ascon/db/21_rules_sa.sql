-- =====================================================================================================
-- APP_RULES_SA : business rules of the sales / internal-request data-entry screens (Stage C, wave 2).
--   Legacy Oracle Forms rules reconstructed for the generated APEX pages (pattern AUTO + "rules" block in
--   app\legacy\overrides\<FORM>.json). Evidence and rule lists: app\legacy\processes\<FORM>.md.
--
--   ST_ISSUE_IO          sales invoices          ST_TRNS_MAST / ST_TRNS_DET / ST_TRNS_SERVICES  (EFFECT 2, TRNS_TYPE 2,5)
--   ST_ISSUE_RETURN      sales returns           ST_TRNS_MAST / ST_TRNS_DET / ST_TRNS_SERVICES  (EFFECT 4, TRNS_TYPE 4)
--   ST_SALES_ORDER       sales orders            ST_SALES_ORDER / ST_SALES_ORDER_DET            (EFFECT 7, TRNS_TYPE 30)
--   ST_PRICE_PROPOSAL    customer quotations     ST_PROPOSAL_MAST / ST_PROPOSAL_DET             (EFFECT 7, TRNS_TYPE 16)
--   ST_DELIVERY          delivery notes          ST_DELIVERY_MAST / ST_DELIVERY_DET             (EFFECT 7, TRNS_TYPE 31)
--   ST_ITEM_REQ(_HANDLE) branch material requests ST_ITEM_REQ / ST_ITEM_REQ_DET                 (EFFECT 7, TRNS_TYPE 12)
--   ST_PRUCHASE_REQUEST  purchase requests       PR_ORDER_REQUEST / PR_ORDER_DET_REQUEST        (EFFECT 7, TRNS_TYPE 13)
--   PR_MR                supplier RFQ            PR_REQ_MAST / PR_REQ_DET / PR_QUOT_MAST        (QUOT_TRNS_TYPE of the 13 types)
--   PR_QUOT_TRNS         supplier quotations     PR_REQ_MAST / PR_QUOT_MAST / PR_QUOT_DET
--
-- Conventions
--   * Row rules (the generated APPX_<table> BEFORE INSERT OR UPDATE triggers, APEX sessions only) call the *_row
--     procedures below. On the shared tables ST_TRNS_MAST / ST_TRNS_DET / ST_TRNS_SERVICES they only act on the
--     kinds SI / SR (doc_kind), so the stock and purchasing screens that share those tables are not affected.
--   * Page validations return an error text (Arabic, English when G_LANG = 'en'); after-save procedures and row
--     rules raise_application_error(-20100..-20199), which makes APEX roll the whole page submit back.
--   * Legacy DB triggers stay in charge of: ST_TRNS_MAST DATE_SERIAL (ST_TRNS_MAST_IN, sequence) and salesman
--     managers, closing-period window (CLOSE_ST_TRNS_MAST), ALT_KEY, tax-period lock (*_TAX), stock cost /
--     balance rows (ST_TRNS_DET_C_IN/UP/DL), ST_DELIVERY_M_SLSMAN_MNGR, PR_ORDER_REQUEST_UP. Not duplicated here.
--   * The snapshot taken by a page validation (before any DML) is read by the after-save process of the same
--     page submit (same database call).
--   * No COMMIT anywhere: APEX commits the page submit.
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_rules_sa authid definer as

  -- ================================================================== common helpers
  -- document kind of an ST_TRNS_TYPE code: SI sales invoice (EFFECT 2, TRNS_TYPE 2/5), SR sales return (4/4),
  -- SO sales order (7/30), QT quotation (7/16), DLV delivery note (7/31), REQ material request (7/12),
  -- PRQ purchase request (7/13), RFQ request for quotation (QUOT_TRNS_TYPE of a PRQ type); null otherwise
  function doc_kind (p_trns_type_code in number) return varchar2;
  -- true while this package re-writes rows itself (soft delete / generated lines): row rules stand aside
  function bypass return boolean;
  -- APP_CONV (document conversions, app\db\22_conv.sql) writes complete rows itself: row rules stand aside meanwhile
  procedure set_bypass (p_on in boolean);
  -- message in the session language (legacy MSG(arabic, english))
  function m (p_a in varchar2, p_e in varchar2 default null) return varchar2;
  -- page item (string, application date format DD/MM/YYYY) -> date / number
  function to_d (p in varchar2) return date;
  function to_n (p in varchar2) return number;
  -- current user's group (G_PASSWORD_NUMBER, 0 = unrestricted) and user code (G_USER_CODE)
  function pw return number;
  function usr return number;
  -- transaction type allowed for this kind and for the user's group (ST_TRNSTYPE_PASSWORD [FLAG=1], ST_STORE_PASSWORD)
  function type_error (p_type in number, p_kind in varchar2, p_flag_required in boolean default true) return varchar2;
  -- default transaction type of a kind for the current user (type of the user's main store first)
  function first_type (p_kind in varchar2) return number;
  -- VAT of a line: port of TAX_LIB(_NEW).GET_TAX_VALUE (customer / supplier / item tax tables; area never passed)
  procedure line_tax (p_group in number, p_item in varchar2, p_customer in number, p_supplier in number,
                      p_date in date, p_value in number, o_tax_code out number, o_tax_value out number);

  -- ================================================================== ST_TRNS_MAST / ST_TRNS_DET / ST_TRNS_SERVICES (SI, SR)
  procedure trns_mast_row (
    p_inserting   in boolean,
    p_type        in number,   p_serial      in number,   p_date        in date,
    p_doc_no      in out number,   p_invoice_no  in out varchar2, p_invoice_ref in out varchar2,
    p_desc_a      in out varchar2, p_desc_e      in out varchar2,
    p_store       in out number,   p_customer    in out number,   p_salesman    in out number,
    p_currency    in out number,   p_rate        in out number,
    p_due_days    in out number,   p_due_date    in out date,
    p_delete_flag in out number,   p_print_flag  in out number,   p_return_type_flag in out number,
    p_ret_type    in out number,   p_ret_serial  in out number,
    p_order_type  in out number,   p_order_serial in out number,
    p_demo_type   in out number,   p_demo_serial in out number,   p_trnsport_val in out number);

  procedure trns_det_row (
    p_inserting   in boolean,
    p_type        in number,   p_serial      in number,   p_item_serial in out number,
    p_group       in out number,   p_item        in varchar2, p_unit        in out number,
    p_confg       in out number,
    p_qty         in number,       p_bonus       in out number,
    p_extra_bonus in out number,   p_extra_ratio in out number,
    p_basic_qty   in out number,
    p_price_curr  in out number,   p_price       in out number,
    p_d1_ratio    in out number,   p_d1_value    in out number,
    p_d2_ratio    in out number,   p_d2_value    in out number,
    p_d3_ratio    in out number,   p_d3_value    in out number,
    p_det_disc    in out number,   p_disc        in out number,
    p_cost_flag   in out number,   p_unit_cost   in out number,
    p_store       in out number,
    p_tax_code    in out number,   p_tax_value   in out number,
    p_auto_disc   in out number,
    p_org_d1      in out number,   p_org_d2      in out number,   p_org_d3      in out number,
    p_org_bonus   in out number,   p_org_price   in out number,   p_org_extra   in out number,
    p_org_class   in out number,
    p_old_item    in varchar2,     p_old_unit    in number,       p_old_confg   in number,
    p_old_qty     in number,       p_old_bonus   in number,       p_old_extra   in number,
    p_old_price_curr in number);
  -- same rule with QUANTITY in out (wave 3): a sales-invoice line without lot and AUTO_DISC = 1 is split over the lots of
  -- the store by expiry (legacy DEVIDE_CONFGS, ST_BASIC.INSERT_SALE_CNFG = 1): this row keeps the first lot, the other
  -- parts are queued and inserted by si_after_save; the quantity is rounded to the bonus policy (CALC_SALES_DISC_TOT)
  procedure trns_det_row2 (
    p_inserting   in boolean,
    p_type        in number,   p_serial      in number,   p_item_serial in out number,
    p_group       in out number,   p_item        in varchar2, p_unit        in out number,
    p_confg       in out number,
    p_qty         in out number,   p_bonus       in out number,
    p_extra_bonus in out number,   p_extra_ratio in out number,
    p_basic_qty   in out number,
    p_price_curr  in out number,   p_price       in out number,
    p_d1_ratio    in out number,   p_d1_value    in out number,
    p_d2_ratio    in out number,   p_d2_value    in out number,
    p_d3_ratio    in out number,   p_d3_value    in out number,
    p_det_disc    in out number,   p_disc        in out number,
    p_cost_flag   in out number,   p_unit_cost   in out number,
    p_store       in out number,
    p_tax_code    in out number,   p_tax_value   in out number,
    p_auto_disc   in out number,
    p_org_d1      in out number,   p_org_d2      in out number,   p_org_d3      in out number,
    p_org_bonus   in out number,   p_org_price   in out number,   p_org_extra   in out number,
    p_org_class   in out number,
    p_old_item    in varchar2,     p_old_unit    in number,       p_old_confg   in number,
    p_old_qty     in number,       p_old_bonus   in number,       p_old_extra   in number,
    p_old_price_curr in number);

  procedure trns_srv_row (
    p_inserting   in boolean,
    p_type        in number,   p_serial      in number,   p_service     in number,
    p_cost        in out number,   p_units       in out number,
    p_tax_code    in out number,   p_tax_value   in out number);

  -- ================================================================== ST_ISSUE_IO (sales invoice)
  function si_validate (
    p_request   in varchar2, p_rowid     in varchar2,
    p_type      in varchar2, p_date      in varchar2, p_store     in varchar2,
    p_customer  in varchar2, p_salesman  in varchar2,
    p_currency  in varchar2, p_rate      in varchar2, p_class     in varchar2,
    p_order_type in varchar2, p_order_serial in varchar2) return varchar2;
  procedure si_after_save (p_request in varchar2, p_rowid in varchar2);

  -- ================================================================== ST_ISSUE_RETURN (sales return)
  function sr_validate (
    p_request   in varchar2, p_rowid     in varchar2,
    p_type      in varchar2, p_date      in varchar2, p_store     in varchar2,
    p_customer  in varchar2, p_salesman  in varchar2,
    p_currency  in varchar2, p_rate      in varchar2,
    p_ret_inv_code in varchar2, p_invoice_no in varchar2) return varchar2;
  procedure sr_after_save (p_request in varchar2, p_rowid in varchar2);

  -- DELETE of an ST_TRNS_MAST document (SI / SR) from the page = legacy soft delete (KEY-DELREC): the row deleted by
  -- the page DML is restored from its committed image and flagged DELETE_FLAG = 1 / DELETE_USER / DELETE_DATE (the
  -- lines follow through the legacy trigger ST_TRNS_MAST_UP). Posted (and printed invoice) documents cannot be deleted.
  -- Wave 3: no longer called by the pages (the generator now deletes the lines before the header): the invoice and return
  -- pages use rules.soft_delete with app_act_st.si_delete_check / sr_delete_check.
  procedure trns_soft_delete (p_rowid in varchar2);

  -- ================================================================== ST_SALES_ORDER (sales order)
  procedure so_mast_row (
    p_inserting in boolean,
    p_type in number, p_serial in number, p_order_date in out date,
    p_store in out number, p_customer in number, p_salesman in out number,
    p_currency in out number, p_rate in out number, p_invoice_number in out varchar2,
    p_approved in out number, p_old_approved in number, p_approved_user in out number, p_approved_date in out date,
    p_approved2 in out number, p_old_approved2 in number, p_approved2_user in out number, p_approved2_date in out date,
    p_closed in out number, p_auto_disc_init in out number, p_pay_term in varchar2, p_offer_expire_date in out date);

  procedure so_det_row (
    p_inserting in boolean,
    p_type in number, p_serial in number, p_line in number,
    p_group in out number, p_item in varchar2, p_old_item in varchar2,
    p_unit in out number, p_old_unit in number, p_confg in out number, p_old_confg in number,
    p_temp_qty in out number, p_qty in out number,
    p_bonus in out number, p_bonus_ratio in out number, p_extra_bonus in out number, p_extra_ratio in out number,
    p_basic_qty in out number, p_price_curr in out number, p_price in out number,
    p_d1_ratio in out number, p_d1_value in out number, p_d2_ratio in out number, p_d2_value in out number,
    p_d3_ratio in out number, p_d3_value in out number, p_auto_disc in out number,
    p_org_d1 in out number, p_org_d2 in out number, p_org_d3 in out number, p_org_bonus in out number,
    p_org_price in out number, p_org_extra in out number, p_org_class in out number,
    p_tax_code in out number, p_tax_value in out number, p_last_expire in out date);

  function so_validate (
    p_request in varchar2, p_rowid in varchar2,
    p_type in varchar2, p_date in varchar2, p_store in varchar2, p_customer in varchar2, p_salesman in varchar2,
    p_currency in varchar2, p_rate in varchar2, p_class in varchar2, p_rfq in varchar2, p_doc_no in varchar2,
    p_approved in varchar2, p_approved2 in varchar2, p_closed in varchar2,
    p_td1r in varchar2, p_td1v in varchar2, p_td2r in varchar2, p_td2v in varchar2, p_td3r in varchar2, p_td3v in varchar2)
    return varchar2;
  procedure so_after_save (p_request in varchar2, p_rowid in varchar2);

  -- ================================================================== ST_PRICE_PROPOSAL (customer quotation)
  procedure qt_mast_row (
    p_inserting in boolean,
    p_type in number, p_serial in number, p_date in out date, p_date_serial in out number,
    p_store in out number, p_customer in number, p_supplier in number, p_posting_supplier in out number,
    p_salesman in out number, p_currency in out number, p_rate in out number, p_invoice_no in out varchar2,
    p_offer_expiry in out varchar2, p_proposal_expire in out date, p_delete_flag in out number,
    p_salesman_done in out number,
    p_approve in out number, p_old_approve in number, p_approve_user in out number, p_approve_date in out date,
    p_approve2 in out number, p_old_approve2 in number, p_approve2_user in out number, p_approve2_date in out date,
    p_accept in out number, p_old_accept in number, p_approve3_user in out number, p_approve3_date in out date,
    p_auto_disc_init in out number);

  procedure qt_det_row (
    p_inserting in boolean,
    p_type in number, p_serial in number,
    p_date in out date, p_date_serial in out number, p_store in out number, p_delete_flag in out number,
    p_group in out number, p_item in varchar2, p_old_item in varchar2,
    p_unit in out number, p_old_unit in number, p_confg in number, p_old_confg in number,
    p_temp_qty in out number, p_qty in out number,
    p_bonus in out number, p_bonus_ratio in out number, p_extra_bonus in out number, p_extra_ratio in out number,
    p_basic_qty in out number, p_price_curr in out number, p_old_price_curr in number, p_price in out number,
    p_d1_ratio in out number, p_d1_value in out number, p_d2_ratio in out number, p_d2_value in out number,
    p_d3_ratio in out number, p_d3_value in out number, p_auto_disc in out number,
    p_org_d1 in out number, p_org_d2 in out number, p_org_d3 in out number, p_org_bonus in out number,
    p_org_price in out number, p_org_extra in out number, p_org_class in out number,
    p_tax_code in out number, p_tax_value in out number,
    p_choice in out number, p_unavailable in out number, p_transfer_qty in number,
    p_cost_flag in out number, p_unit_cost in out number, p_item_name in out varchar2, p_last_expire in out date);

  function qt_validate (
    p_request in varchar2, p_rowid in varchar2,
    p_type in varchar2, p_date in varchar2, p_store in varchar2, p_customer in varchar2, p_supplier in varchar2,
    p_salesman in varchar2, p_currency in varchar2, p_rate in varchar2, p_class in varchar2, p_rfq in varchar2,
    p_salesman_done in varchar2, p_approve in varchar2, p_approve2 in varchar2, p_accept in varchar2,
    p_desc_a in varchar2, p_desc_e in varchar2, p_pay_term in varchar2, p_offer_expiry in varchar2,
    p_other_terms in varchar2, p_proposal_expire in varchar2) return varchar2;
  procedure qt_after_save (p_request in varchar2, p_rowid in varchar2);

  -- ================================================================== ST_DELIVERY (delivery notes)
  procedure dlv_mast_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_date in out date,
    p_delivery_serial in out number, p_note_no in out number, p_store in out number,
    p_order_type in number, p_order_serial in number,
    p_customer in out number, p_supplier in out number, p_salesman in out number,
    p_delete_flag in out number, p_state in out number);
  -- line SERIAL = the sales-order line of the item (never a running number)
  function dlv_line_serial (p_type in number, p_serial in number, p_group in number, p_item in varchar2) return number;
  procedure dlv_det_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_line in number,
    p_group in out number, p_item in varchar2, p_unit in out number, p_confg in out number,
    p_qty in number, p_bonus in out number, p_price in out number, p_price_curr in out number, p_store in out number);
  function dlv_validate (
    p_request in varchar2, p_rowid in varchar2, p_type in varchar2, p_date in varchar2,
    p_order_type in varchar2, p_order_serial in varchar2) return varchar2;
  procedure dlv_after_save (p_request in varchar2, p_rowid in varchar2);

  -- ================================================================== ST_ITEM_REQ / ST_ITEM_REQ_HANDLE (material requests)
  procedure req_mast_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_date in out date, p_date_serial in out number,
    p_store in out number, p_from_store in number, p_approve in out number, p_close in out number);
  procedure req_det_row (
    p_inserting in boolean, p_type in number, p_serial in number,
    p_group in out number, p_item in varchar2, p_unit in out number,
    p_req_qty in out number, p_qty in out number, p_basic_qty in out number, p_price in number,
    p_date in out date, p_date_serial in out number, p_old_pr_flag in number);
  function req_validate (
    p_request in varchar2, p_rowid in varchar2, p_type in varchar2, p_date in varchar2,
    p_store in varchar2, p_from_store in varchar2) return varchar2;
  procedure req_after_save (p_request in varchar2, p_rowid in varchar2);

  -- ================================================================== ST_PRUCHASE_REQUEST (purchase requests)
  procedure prq_mast_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_date in out date, p_date_serial in out number,
    p_store in out number);
  procedure prq_det_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_line in number,
    p_group in out number, p_item in varchar2, p_unit in out number, p_qty in number, p_basic_qty in out number,
    p_supplier in out number, p_date in out date, p_date_serial in out number,
    p_old_group in number, p_old_item in varchar2, p_old_unit in number, p_old_qty in number);
  function prq_validate (
    p_request in varchar2, p_rowid in varchar2, p_type in varchar2, p_date in varchar2, p_store in varchar2) return varchar2;
  procedure prq_after_save (p_request in varchar2, p_rowid in varchar2);

  -- ================================================================== PR_MR (RFQ) / PR_QUOT_TRNS (supplier quotations)
  procedure rfq_det_row (p_group in number, p_color in number, p_size in number);
  procedure quot_mast_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_supplier in number,
    p_quot_serial in out number, p_currency in out number, p_rate in out number, p_disc_val in number,
    p_date_send in out date, p_accept in number, p_old_accept in number,
    p_quot_flag in number, p_old_quot_flag in number, p_old_disc_val in number);
  procedure quot_det_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_supplier in number, p_line in number,
    p_price in number, p_old_price in number, p_det_disc in number, p_arrival in date, p_color in number, p_size in number);
  function rfq_validate (p_request in varchar2, p_rowid in varchar2) return varchar2;
  procedure rfq_after_save (p_request in varchar2, p_rowid in varchar2);
  procedure quot_after_save (p_request in varchar2, p_rowid in varchar2);

end app_rules_sa;
/

create or replace package body app_rules_sa as

  type t_kind is table of varchar2(4) index by pls_integer;
  g_kind      t_kind;
  g_bypass    boolean := false;

  -- snapshot taken by the page validation (before DML) and read by the after-save process of the same request
  type t_snap_line is record (line number, grp number, item varchar2(30), confg number, store number,
                              tdate date, dserial number, qty number, flag number);
  type t_snap_lines is table of t_snap_line index by pls_integer;
  g_snap_rowid varchar2(40);
  g_snap_lines number;
  g_snap_net   number;
  g_snap_det   t_snap_lines;

  -- parts of sales-invoice lines split over lots by the row rule (DEVIDE_CONFGS), inserted by si_after_save
  type t_split is record (ttype number, tserial number, grp number, item varchar2(30), unit number, confg number,
                          qty number, bonus number, extra number, price_curr number,
                          d1r number, d1v number, d2r number, d2v number, d3r number, d3v number);
  type t_splits is table of t_split index by pls_integer;
  g_split      t_splits;

  -- ================================================================== helpers
  function doc_kind (p_trns_type_code in number) return varchar2 is
    t    st_trns_type%rowtype;
    l_kind varchar2(4);
    l_n  number;
  begin
    if p_trns_type_code is null then return null; end if;
    if p_trns_type_code between -2147483647 and 2147483647 and g_kind.exists(p_trns_type_code) then
      return nullif(g_kind(p_trns_type_code), '-');
    end if;
    begin
      select * into t from st_trns_type where trns_type_code = p_trns_type_code;
      l_kind := case when t.effect = 2 and t.trns_type in (2, 5) then 'SI'
                     when t.effect = 4 and t.trns_type = 4        then 'SR'
                     when t.effect = 7 and t.trns_type = 30       then 'SO'
                     when t.effect = 7 and t.trns_type = 16       then 'QT'
                     when t.effect = 7 and t.trns_type = 31       then 'DLV'
                     when t.effect = 7 and t.trns_type = 12       then 'REQ'
                     when t.effect = 7 and t.trns_type = 13       then 'PRQ' end;
    exception when no_data_found then l_kind := null;
    end;
    if l_kind is null then
      select count(*) into l_n from st_trns_type where effect = 7 and trns_type = 13 and quot_trns_type = p_trns_type_code;
      if l_n > 0 then l_kind := 'RFQ'; end if;
    end if;
    if p_trns_type_code between -2147483647 and 2147483647 then
      g_kind(p_trns_type_code) := nvl(l_kind, '-');
    end if;
    return l_kind;
  end doc_kind;

  function bypass return boolean is begin return g_bypass; end;
  procedure set_bypass (p_on in boolean) is begin g_bypass := nvl(p_on, false); end;

  function m (p_a in varchar2, p_e in varchar2 default null) return varchar2 is
  begin
    return case when v('G_LANG') = 'en' and p_e is not null then p_e else p_a end;
  end m;

  function to_d (p in varchar2) return date is
  begin
    if p is null then return null; end if;
    return nvl(to_date(p default null on conversion error, 'DD/MM/YYYY'),
               to_date(p default null on conversion error, 'YYYY-MM-DD'));
  end to_d;

  function to_n (p in varchar2) return number is
  begin
    if p is null then return null; end if;
    return to_number(replace(p, ',') default null on conversion error);
  end to_n;

  function pw return number is begin return nvl(to_n(v('G_PASSWORD_NUMBER')), 0); end;
  function usr return number is begin return nvl(to_n(v('G_USER_CODE')), 0); end;

  procedure err (p_code in pls_integer, p_a in varchar2, p_e in varchar2 default null) is
  begin
    raise_application_error(p_code, m(p_a, p_e));
  end err;

  function user_flag (p_col in varchar2) return number is
    l number;
  begin
    execute immediate 'select nvl(max(' || dbms_assert.simple_sql_name(p_col) || '), 0) from users where users_code = :u'
      into l using usr;
    return l;
  end user_flag;

  function changed (a in number, b in number) return boolean is
  begin
    return nvl(a, -999999999) <> nvl(b, -999999999);
  end changed;

  function changed_s (a in varchar2, b in varchar2) return boolean is
  begin
    return nvl(a, chr(0)) <> nvl(b, chr(0));
  end changed_s;

  function changed_d (a in date, b in date) return boolean is
  begin
    return nvl(a, date '1000-01-01') <> nvl(b, date '1000-01-01');
  end changed_d;

  function type_error (p_type in number, p_kind in varchar2, p_flag_required in boolean default true) return varchar2 is
    l_store number;
    l_n     number;
    l_flag  number := case when p_flag_required then 1 else 0 end;
  begin
    if p_type is null then
      return m('يجب إدخال نوع الحركة', 'Transaction type is required');
    end if;
    if nvl(doc_kind(p_type), '-') <> p_kind then
      return m('نوع الحركة ' || p_type || ' لا يخص هذه الشاشة', 'Transaction type ' || p_type || ' does not belong to this screen');
    end if;
    if pw <> 0 then
      select count(*) into l_n from st_trnstype_password
       where trns_type_code = p_type and password_number = pw and (l_flag = 0 or flag = 1);
      if l_n = 0 then
        return m('غير مسموح لك بهذا النوع من الحركات', 'You are not allowed to use this transaction type');
      end if;
      select max(store_code) into l_store from st_trns_type where trns_type_code = p_type;
      if l_store is not null then
        select count(*) into l_n from st_store_password where store_code = l_store and password_number = pw;
        if l_n = 0 then
          return m('غير مسموح لك بمخزن هذا النوع من الحركات', 'You are not allowed to use the store of this transaction type');
        end if;
      end if;
    end if;
    return null;
  end type_error;

  function first_type (p_kind in varchar2) return number is
    l_main number;
    l_type number;
  begin
    select max(main_store_code) into l_main from users where users_code = usr;
    select min(trns_type_code) keep (dense_rank first order by case when store_code = l_main then 0 else 1 end, trns_type_code)
      into l_type
      from st_trns_type t
     where ((p_kind = 'SI' and effect = 2 and trns_type in (2, 5))
         or (p_kind = 'SR' and effect = 4 and trns_type = 4)
         or (p_kind = 'SO' and effect = 7 and trns_type = 30)
         or (p_kind = 'QT' and effect = 7 and trns_type = 16 and nvl(join_type, 0) in (3, 4))
         or (p_kind = 'DLV' and effect = 7 and trns_type = 31 and join_type = 1)
         or (p_kind = 'REQ' and effect = 7 and trns_type = 12 and store_code is not null)
         or (p_kind = 'PRQ' and effect = 7 and trns_type = 13 and store_code is not null))
       and (pw = 0 or trns_type_code in (select trns_type_code from st_trnstype_password
                                          where password_number = pw and (p_kind in ('REQ', 'PRQ') or flag = 1)))
       and (store_code is null or pw = 0 or store_code in (select store_code from st_store_password where password_number = pw));
    return l_type;
  end first_type;

  procedure line_tax (p_group in number, p_item in varchar2, p_customer in number, p_supplier in number,
                      p_date in date, p_value in number, o_tax_code out number, o_tax_value out number) is
    l_item_per number;
    l_n        number;
  begin
    o_tax_code := null; o_tax_value := null;
    for t in (select tax_code from tx_taxes_types
               where start_date = (select max(start_date) from tx_taxes_types where start_date <= nvl(p_date, sysdate))
               order by tax_code) loop
      l_item_per := null;
      if p_group is not null and p_item is not null then
        select nvl(min(tax_per), 0) into l_item_per
          from tx_taxes_items where group_code = p_group and item_code = p_item and tax_code = t.tax_code;
      end if;
      select count(*) into l_n from tx_taxes_customers where customer_code = p_customer and tax_code = t.tax_code;
      if l_n <> 0 then
        for c in (select tax_code, decode(tax_per, 0, 0, nvl(l_item_per, tax_per)) tax_per
                    from tx_taxes_customers where customer_code = p_customer and tax_code = t.tax_code) loop
          o_tax_code := c.tax_code; o_tax_value := round(c.tax_per * nvl(p_value, 0) / 100, 2);
        end loop;
      else
        select count(*) into l_n from tx_taxes_suppliers where supplier_code = p_supplier and tax_code = t.tax_code;
        if l_n <> 0 then
          for c in (select tax_code, decode(tax_per, 0, 0, nvl(l_item_per, tax_per)) tax_per
                      from tx_taxes_suppliers where supplier_code = p_supplier and tax_code = t.tax_code) loop
            o_tax_code := c.tax_code; o_tax_value := round(c.tax_per * nvl(p_value, 0) / 100, 2);
          end loop;
        else
          for c in (select tax_code, tax_per from tx_taxes_items
                     where group_code = p_group and item_code = p_item and tax_code = t.tax_code) loop
            o_tax_code := c.tax_code; o_tax_value := round(c.tax_per * nvl(p_value, 0) / 100, 2);
          end loop;
        end if;
      end if;
    end loop;
  end line_tax;

  -- CHECK_DATE (.pll TRANSLATE) + VALIDATE_DATE of the sales forms: not in the future, not before ST_BASIC.MIN_DATE,
  -- optionally after AC_BASIC.CLOSE_DATE, not before the last salesman transfer of the customer
  function date_error (p_date in date, p_customer in number, p_close in boolean default true) return varchar2 is
    l_close date;
    l_min   date;
    l_max   date;
  begin
    if p_date is null then
      return m('يجب إدخال تاريخ الحركة', 'Transaction date is required');
    end if;
    if trunc(p_date) > trunc(sysdate) then
      return m('تاريخ الحركة أكبر من تاريخ اليوم', 'Transaction Date is greater than today''s date');
    end if;
    select min(min_date) into l_min from st_basic;
    if l_min is not null and p_date < l_min then
      return m('الحد الأدنى لتاريخ الحركة هو ' || to_char(l_min, 'DD/MM/YYYY'), 'The minimum transaction date is ' || to_char(l_min, 'DD/MM/YYYY'));
    end if;
    if p_close then
      select max(close_date) into l_close from ac_basic where company_code = nvl(to_n(v('G_COMPANY_CODE')), company_code);
      if l_close is not null and p_date <= l_close then
        return m('يجب ان يكون تاريخ القيد بعد تاريخ اخر اقفال', 'Voucher Date Must Be More Than Last Close');
      end if;
    end if;
    if p_customer is not null then
      select max(trnsfr_date) into l_max from ar_slsman_trnsfr_det where customer_code = p_customer;
      if l_max is not null and l_max > p_date then
        return m('لا يمكن عمل حركة للعميل فى تاريخ سابق لتاريخ اخر حركة نقل', 'ERROR IN SALES MAN DATE');
      end if;
    end if;
    return null;
  end date_error;

  -- customer as offered by the legacy CUSTOMER_RG lists (optionally restricted to the category of a type)
  function customer_error (p_customer in number, p_ctgry_type in number default null) return varchar2 is
    l_n number;
  begin
    select count(*) into l_n
      from customer c
     where c.code = p_customer
       and nvl(c.stopflag, 0) <> 1
       and nvl(c.customer_status, 0) = 1
       and c.mainarea_id is not null and c.subarea_id is not null
       and c.code in (select a.customer_code from ar_cust_salesman a
                       where p_ctgry_type is null
                          or a.ctgry_code in (select ctgry_code from st_trns_type where trns_type_code = p_ctgry_type))
       and (pw = 0 or c.code in (select customer_code from ar_cust_password where password_number = pw));
    if l_n = 0 then
      return m('العميل ' || p_customer || ' غير متاح: موقوف أو غير نشط أو بدون منطقة / مندوب أو غير مصرح لك به',
               'Customer ' || p_customer || ' is stopped, inactive, without area / salesman or not allowed');
    end if;
    return null;
  end customer_error;

  -- salesman as offered by the legacy SALESMAN_RG lists
  function salesman_error (p_salesman in number, p_customer in number) return varchar2 is
    l_n number;
  begin
    select count(*) into l_n
      from salesman_view v, salesman s
     where v.code = s.code
       and s.code = p_salesman
       and (p_customer is null or v.customer_code = p_customer)
       and (pw = 0 or v.code in (select salesman_code from ar_salesman_password where password_number = pw))
       and nvl(s.stop_flag, 0) = 0;
    if l_n = 0 then
      return m('المندوب ' || p_salesman || ' غير مرتبط بهذا العميل أو متوقف أو غير مصرح لك به',
               'Salesman ' || p_salesman || ' is not linked to this customer, stopped or not allowed');
    end if;
    return null;
  end salesman_error;

  function store_error (p_store in number) return varchar2 is
    l_n number;
  begin
    select count(*) into l_n from st_store
     where store_code = p_store and store_status = 1 and nvl(stop_flag, 0) = 0
       and (pw = 0 or store_code in (select store_code from st_store_password where password_number = pw));
    if l_n = 0 then
      return m('المخزن ' || p_store || ' متوقف أو غير مصرح لك به', 'Store ' || p_store || ' is stopped or not allowed');
    end if;
    return null;
  end store_error;

  function type_store (p_type in number) return number is
    l number;
  begin
    select max(s.store_code) into l from st_trns_type t, st_store s
     where t.trns_type_code = p_type and s.store_code = t.store_code and s.store_status = 1 and nvl(s.stop_flag, 0) = 0;
    return l;
  end type_store;

  function unit_factor (p_group in number, p_item in varchar2, p_unit in number) return number is
    l number;
  begin
    select nvl(factor, 1) into l from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit;
    return l;
  exception when no_data_found then
    err(-20112, 'الوحدة ' || p_unit || ' غير معرفة للصنف ' || p_item, 'Unit ' || p_unit || ' is not defined for item ' || p_item);
    return null;
  end unit_factor;

  function basic_unit (p_group in number, p_item in varchar2) return number is
    l number;
  begin
    select min(unit_code) keep (dense_rank first order by case when nvl(basic_unit, 0) = 1 then 0 else 1 end, unit_code)
      into l from st_item_unit where group_code = p_group and item_code = p_item;
    return l;
  end basic_unit;

  procedure item_check (p_group in out number, p_item in varchar2) is
    l_n number;
  begin
    if p_group is null then
      select min(item_group_code) into p_group from st_item where item_code = p_item;
    end if;
    select count(*) into l_n from st_item where item_group_code = p_group and item_code = p_item and nvl(stop_flag, 0) = 0;
    if l_n = 0 then
      err(-20111, 'الصنف ' || p_item || ' غير موجود أو متوقف', 'Item ' || p_item || ' does not exist or is stopped');
    end if;
  end item_check;

  -- line discounts DISCn_RATIO / DISCn_VALUE (WHEN-VALIDATE-ITEM of the sales forms): the ratio wins, a value alone
  -- gives the ratio; each level is taken on the price left by the previous ones
  procedure line_discounts (p_price in number,
                            p_d1_ratio in out number, p_d1_value in out number,
                            p_d2_ratio in out number, p_d2_value in out number,
                            p_d3_ratio in out number, p_d3_value in out number, p_qty in number, p_item in varchar2) is
    l_base number;
  begin
    l_base := p_price;
    if p_d1_ratio is not null then p_d1_value := p_d1_ratio * l_base / 100;
    elsif p_d1_value is not null and l_base <> 0 then p_d1_ratio := p_d1_value / l_base * 100; end if;
    l_base := p_price - nvl(p_d1_value, 0);
    if p_d2_ratio is not null then p_d2_value := p_d2_ratio * l_base / 100;
    elsif p_d2_value is not null and l_base <> 0 then p_d2_ratio := p_d2_value / l_base * 100; end if;
    l_base := p_price - nvl(p_d1_value, 0) - nvl(p_d2_value, 0);
    if p_d3_ratio is not null then p_d3_value := p_d3_ratio * l_base / 100;
    elsif p_d3_value is not null and l_base <> 0 then p_d3_ratio := p_d3_value / l_base * 100; end if;
    if nvl(p_d1_ratio, 0) < 0 or nvl(p_d2_ratio, 0) < 0 or nvl(p_d3_ratio, 0) < 0 then
      err(-20119, 'أدخل رقم بقيمة تبدأ من الصفر', 'Enter Value From Zero');
    end if;
    if nvl(p_d1_value, 0) < 0 or nvl(p_d2_value, 0) < 0 or nvl(p_d3_value, 0) < 0 then
      err(-20119, 'ادخل قيمة اكبر من او تساوى صفر', 'enter value greater than zero');
    end if;
    if nvl(p_d1_value, 0) + nvl(p_d2_value, 0) + nvl(p_d3_value, 0) >= nvl(p_price, 0) and nvl(p_qty, 0) > 0 then
      err(-20119, 'مجموع الخصومات أكبر من أو يساوى سعر الوحدة للصنف ' || p_item,
          'Sum of Disc is larger than or equal the unit price of item ' || p_item);
    end if;
  end line_discounts;

  -- header total discounts TOT_DISC1..3 (VALIDATE_TOT_DISC1..3 and the value triggers): cascade on the remaining
  -- total; a level is reset when the previous one is empty
  procedure tot_discounts (p_net in number, r1 in out number, v1 in out number, r2 in out number, v2 in out number,
                           r3 in out number, v3 in out number) is
  begin
    if nvl(r1, 0) <> 0 then v1 := r1 * p_net / 100;
    elsif nvl(v1, 0) <> 0 and p_net <> 0 then r1 := v1 / p_net * 100;
    elsif r1 is not null or v1 is not null then r1 := 0; v1 := 0; end if;
    if nvl(v1, 0) = 0 then
      if r2 is not null or v2 is not null then r2 := 0; v2 := 0; end if;
    elsif nvl(r2, 0) <> 0 then v2 := r2 * (p_net - v1) / 100;
    elsif nvl(v2, 0) <> 0 and p_net - v1 <> 0 then r2 := v2 / (p_net - v1) * 100; end if;
    if nvl(v2, 0) = 0 then
      if r3 is not null or v3 is not null then r3 := 0; v3 := 0; end if;
    elsif nvl(r3, 0) <> 0 then v3 := r3 * (p_net - v1 - v2) / 100;
    elsif nvl(v3, 0) <> 0 and p_net - v1 - v2 <> 0 then r3 := v3 / (p_net - v1 - v2) * 100; end if;
    if nvl(v1, 0) + nvl(v2, 0) + nvl(v3, 0) > p_net then
      err(-20132, 'قيمة الخصم يجب أن تكون أقل من قيمة الفاتورة', 'Desc Value Must Be Less Than Invoice Value');
    end if;
  end tot_discounts;

  -- balance of later movements of a batch still positive without a stock-in line (legacy KEY-DELREC of lines)
  function next_trns_error (p_store in number, p_group in number, p_item in varchar2, p_confg in number,
                            p_date in date, p_date_serial in number, p_line in number) return varchar2 is
    l_bal number;
  begin
    select nvl(max(neg_sale_balance), 0) into l_bal from st_basic;
    if l_bal <> 0 then return null; end if;
    l_bal := get_balance_confg(p_store, p_group, p_item, p_confg, p_date, p_date_serial, p_line);
    if update_next_trns_confg(p_store, p_group, p_item, p_confg, p_date, p_date_serial, p_line, nvl(l_bal, 0)) <> 0 then
      return m('الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها. (الصنف ' || p_item || ' الشحنة ' || p_confg || ')',
               'Balance Not Enough, There Exist Next Trans. Conflicts With This Trans. (item ' || p_item || ')');
    end if;
    return null;
  end next_trns_error;

  -- ================================================================== ST_TRNS_MAST row rule (SI, SR)
  procedure trns_mast_row (
    p_inserting   in boolean,
    p_type        in number,   p_serial      in number,   p_date        in date,
    p_doc_no      in out number,   p_invoice_no  in out varchar2, p_invoice_ref in out varchar2,
    p_desc_a      in out varchar2, p_desc_e      in out varchar2,
    p_store       in out number,   p_customer    in out number,   p_salesman    in out number,
    p_currency    in out number,   p_rate        in out number,
    p_due_days    in out number,   p_due_date    in out date,
    p_delete_flag in out number,   p_print_flag  in out number,   p_return_type_flag in out number,
    p_ret_type    in out number,   p_ret_serial  in out number,
    p_order_type  in out number,   p_order_serial in out number,
    p_demo_type   in out number,   p_demo_serial in out number,   p_trnsport_val in out number) is
    l_kind varchar2(4) := doc_kind(p_type);
    t      st_trns_type%rowtype;
    so     st_sales_order%rowtype;
    inv    st_trns_mast%rowtype;
    l_own  varchar2(30);
  begin
    if g_bypass or nvl(l_kind, '-') not in ('SI', 'SR') or not p_inserting then
      return;
    end if;
    select * into t from st_trns_type where trns_type_code = p_type;
    p_delete_flag := nvl(p_delete_flag, 0);
    p_print_flag  := nvl(p_print_flag, 0);
    if p_store is null then p_store := type_store(p_type); end if;                -- TRNS_TYPE_CODE WHEN-VALIDATE-ITEM
    p_currency := nvl(p_currency, 1);
    if p_rate is null then
      select nvl(max(rate), 1) into p_rate from ac_currency where currency_code = p_currency;
    end if;
    l_own := to_char(p_type) || lpad(to_char(p_serial), 7, '0');

    if l_kind = 'SI' then
      -- invoice from a sales order (ST_SALES_ORDER make-invoice: INSERT_ISSUE_TRNS)
      if p_order_type is not null and p_order_serial is not null then
        begin
          select * into so from st_sales_order where trns_type_code = p_order_type and trns_serial = p_order_serial;
          p_customer := nvl(p_customer, so.customer_code);
          p_salesman := nvl(p_salesman, so.salesman_code);
          p_doc_no   := nvl(p_doc_no, so.doc_no);
          p_demo_type := nvl(p_demo_type, so.demo_trns_type_code);
          p_demo_serial := nvl(p_demo_serial, so.demo_trns_serial);
          p_trnsport_val := nvl(p_trnsport_val, so.trnsport_val);
          p_desc_a := nvl(p_desc_a, 'فاتورة مبيعات رقم ' || p_type || '/' || p_serial || ' من امر بيع  ' || p_order_type || '/' || p_order_serial);
        exception when no_data_found then null;
        end;
      end if;
      if p_customer is not null then
        if p_salesman is null then p_salesman := get_last_salesman_indate(p_customer); end if;   -- CUSTOMER WHEN-VALIDATE-ITEM
        if p_due_days is null and p_due_date is null then
          select max(day_no) into p_due_days from customer where code = p_customer;
        end if;
      end if;
      if p_due_date is null and p_due_days is not null then p_due_date := p_date + p_due_days;
      elsif p_due_days is null and p_due_date is not null then p_due_days := p_due_date - p_date; end if;
      if p_doc_no is null then                  -- PRE-INSERT (DOC_NO_SEQ); not NVL: it would draw a number for every invoice
        p_doc_no := get_act_doc_no_invoice(p_type);
      end if;
      p_invoice_no := nvl(p_invoice_no, to_char(p_date, 'YYYY') || lpad(to_char(p_serial), 7, '0'));
      p_desc_a := nvl(p_desc_a, t.desc_a || ' حركة رقم ' || p_type || '/' || p_serial);
      p_desc_e := nvl(p_desc_e, t.desc_e || ' Trans No ' || p_type || '/' || p_serial);
    else
      -- sales return: "with invoice" when the original invoice is given (INVOICE_NO 'TYPE\SERIAL' or RET_TRNS_*)
      if p_ret_serial is null and p_invoice_no is not null and regexp_like(p_invoice_no, '^\s*\d+\s*[\/-]\s*\d+\s*$') then
        p_ret_type   := to_number(regexp_substr(p_invoice_no, '\d+', 1, 1));
        p_ret_serial := to_number(regexp_substr(p_invoice_no, '\d+', 1, 2));
      end if;
      p_return_type_flag := case when p_ret_serial is not null then 1 else 0 end;
      if p_return_type_flag = 1 then
        begin
          select * into inv from st_trns_mast where trns_type_code = p_ret_type and trns_serial = p_ret_serial;
          p_customer := nvl(p_customer, inv.customer_code);                       -- INVOICE_LOV returns
          p_salesman := nvl(p_salesman, inv.salesman_code);
          p_order_type := nvl(p_order_type, inv.order_trns_type_code);
          p_order_serial := nvl(p_order_serial, inv.order_trns_serial);
          p_trnsport_val := nvl(p_trnsport_val, inv.trnsport_val);
        exception when no_data_found then null;
        end;
        p_invoice_no  := p_ret_type || '\' || p_ret_serial;
        p_invoice_ref := nvl(p_invoice_ref, l_own);
      else
        if p_customer is not null and p_salesman is null then
          p_salesman := get_last_salesman_indate(p_customer);
        end if;
        p_invoice_no := nvl(p_invoice_no, l_own);
      end if;
      if p_doc_no is null then                                                                  -- DOC_NO_SEQ_RET
        p_doc_no := get_act_doc_no_ret_inv(p_type);
      end if;
      p_desc_a := nvl(p_desc_a, ' م مبيعات رقم' || p_doc_no || ' / '
                                || case when p_return_type_flag = 1 then p_invoice_no else p_invoice_ref end);
      p_desc_e := nvl(p_desc_e, 'Return Invoice No ' || p_doc_no || ' / '
                                || case when p_return_type_flag = 1 then p_invoice_no else p_invoice_ref end);
    end if;
  end trns_mast_row;

  -- ================================================================== ST_TRNS_DET row rule (SI, SR)
  -- DEVIDE_CONFGS (ST_ISSUE_IO program unit, QUANTITY KEY-NEXT-ITEM with AUTO_DISC = 1 and no lot): the lots of the item by
  -- expiry, each giving its minimum balance from the line's position on (GET_MIN_BALANCE_CONFG_AFTER); the first lot with
  -- stock stays on this row, the other parts are queued (price and discounts of this row, policy values of their lot).
  -- Legacy defect not reproduced: when a lot covers the quantity but not all the bonus, the legacy put the rest of the
  -- lot into BONUS and again into EXTRA_BONUS (issuing it twice); here it goes to BONUS first, then to EXTRA_BONUS.
  procedure si_devide (mst in st_trns_mast%rowtype, p_group in number, p_item in varchar2, p_unit in number,
                       p_factor in number, p_item_serial in number, p_confg out number,
                       p_qty in out number, p_bonus in out number, p_extra in out number,
                       p_price_curr in number, p_d1r in number, p_d1v in number, p_d2r in number, p_d2v in number,
                       p_d3r in number, p_d3v in number) is
    l_all   number := nvl(p_qty, 0) * p_factor;
    l_bon   number := nvl(p_bonus, 0) * p_factor;
    l_ext   number := nvl(p_extra, 0) * p_factor;
    l_begin number := l_all + l_bon + l_ext;
    l_tot   number := 0;
    l_bal   number;
    l_b     number; l_e number; l_q number;
    l_i     pls_integer := 1;
    l_neg   number;
    l_unit_name varchar2(200);
    s       t_split;
    l_parts t_splits;                                        -- queued only when the whole split succeeds
  begin
    p_confg := null;
    for d in (select item_confg_id from st_item_confg where group_code = p_group and item_code = p_item
               order by expire_date, item_confg_id) loop
      l_bal := nvl(get_min_balance_confg_after(mst.store_code, p_group, p_item, d.item_confg_id, mst.trns_date, mst.date_serial,
                                               p_item_serial), 0);
      if l_bal > 0 then
        if l_bal >= l_all + l_bon + l_ext then               -- this lot is enough for the rest
          l_q := l_all; l_b := l_bon; l_e := l_ext;
        elsif l_bal < l_all then                             -- part of the quantity, no bonus
          l_q := l_bal; l_b := 0; l_e := 0;
        else                                                 -- the whole quantity and part of the bonus
          l_q := l_all; l_b := least(l_bon, l_bal - l_all); l_e := least(l_ext, l_bal - l_all - l_b);
        end if;
        l_all := l_all - l_q; l_bon := l_bon - l_b; l_ext := l_ext - l_e;
        l_tot := l_tot + l_q + l_b + l_e;
        if l_i = 1 then
          p_confg := d.item_confg_id;
          p_qty := l_q / p_factor; p_bonus := l_b / p_factor; p_extra := l_e / p_factor;
        else
          s.ttype := mst.trns_type_code; s.tserial := mst.trns_serial; s.grp := p_group; s.item := p_item; s.unit := p_unit;
          s.confg := d.item_confg_id; s.qty := l_q / p_factor; s.bonus := l_b / p_factor; s.extra := l_e / p_factor;
          s.price_curr := p_price_curr; s.d1r := p_d1r; s.d1v := p_d1v; s.d2r := p_d2r; s.d2v := p_d2v; s.d3r := p_d3r; s.d3v := p_d3v;
          l_parts(l_parts.count + 1) := s;
        end if;
        l_i := l_i + 1;
        exit when l_all + l_bon + l_ext <= 0;
      end if;
    end loop;
    if l_tot <> l_begin then
      select nvl(max(neg_sale_balance), 0) into l_neg from st_basic;
      if l_neg = 0 then
        select max(decode(v('G_LANG'), 'en', name_e, name_a)) into l_unit_name from st_unit where unit_code = p_unit;
        err(-20129, 'أقصى كمية يمكن إخراجها حتى لا تتعارض مع الحركات التالية = ' || l_tot || ' ' || l_unit_name || ' (الصنف ' || p_item || ')',
            'Maximum Amount Can Be Sold Without Conflicting With Next Transactions = ' || l_tot || ' ' || l_unit_name || ' (item ' || p_item || ')');
      elsif p_confg is not null then
        -- negative stock allowed: the rest stays on the last part (legacy adds it to the current record)
        if l_parts.count > 0 then
          l_parts(l_parts.count).qty := l_parts(l_parts.count).qty + l_all / p_factor;
          l_parts(l_parts.count).bonus := l_parts(l_parts.count).bonus + l_bon / p_factor;
          l_parts(l_parts.count).extra := l_parts(l_parts.count).extra + l_ext / p_factor;
        else
          p_qty := p_qty + l_all / p_factor; p_bonus := p_bonus + l_bon / p_factor; p_extra := p_extra + l_ext / p_factor;
        end if;
      end if;
    end if;
    for i in 1 .. l_parts.count loop
      g_split(g_split.count + 1) := l_parts(i);
    end loop;
  end si_devide;

  procedure det_core (
    p_inserting   in boolean,
    p_type        in number,   p_serial      in number,   p_item_serial in out number,
    p_group       in out number,   p_item        in varchar2, p_unit        in out number,
    p_confg       in out number,
    p_qty         in out number,   p_bonus       in out number,
    p_extra_bonus in out number,   p_extra_ratio in out number,
    p_basic_qty   in out number,
    p_price_curr  in out number,   p_price       in out number,
    p_d1_ratio    in out number,   p_d1_value    in out number,
    p_d2_ratio    in out number,   p_d2_value    in out number,
    p_d3_ratio    in out number,   p_d3_value    in out number,
    p_det_disc    in out number,   p_disc        in out number,
    p_cost_flag   in out number,   p_unit_cost   in out number,
    p_store       in out number,
    p_tax_code    in out number,   p_tax_value   in out number,
    p_auto_disc   in out number,
    p_org_d1      in out number,   p_org_d2      in out number,   p_org_d3      in out number,
    p_org_bonus   in out number,   p_org_price   in out number,   p_org_extra   in out number,
    p_org_class   in out number,
    p_old_item    in varchar2,     p_old_unit    in number,       p_old_confg   in number,
    p_old_qty     in number,       p_old_bonus   in number,       p_old_extra   in number,
    p_old_price_curr in number,
    p_split       in boolean) is
    l_kind   varchar2(4) := doc_kind(p_type);
    mst      st_trns_mast%rowtype;
    inv      st_trns_mast%rowtype;
    l_cnfg   number;
    l_auto_done boolean := false;
    l_factor number;
    l_n      number;
    l_bal    number;
    l_retail number;
    l_left   number;
    l_neg    number;
    l_line   number;
    l_prc    number;
    l_d1 number; l_d2 number; l_d3 number; l_bon number; l_prc2 number; l_ext number; l_cls number;
    l_ret    number; l_org number;
    l_mode1  boolean;
  begin
    if g_bypass or nvl(l_kind, '-') not in ('SI', 'SR') then
      return;
    end if;

    -- updates first, without reading ST_TRNS_MAST: the header update of a soft delete (DELETE_FLAG) reaches the lines
    -- through the legacy trigger ST_TRNS_MAST_UP, where the header table is mutating
    if not p_inserting then
      -- sales invoice lines are never updated in the legacy form (block UPDATE_ALLOWED = false); return lines only
      -- allow discount changes (QUANTITY, BONUS, UNIT, PRICE, LOT ... UpdateAllowed = false)
      if l_kind = 'SR' then
        if changed_s(p_item, p_old_item) or changed(p_unit, p_old_unit) or changed(p_confg, p_old_confg)
           or changed(p_qty, p_old_qty) or changed(p_bonus, p_old_bonus) or changed(p_extra_bonus, p_old_extra)
           or changed(p_price_curr, p_old_price_curr) then
          err(-20125, 'لا يمكن تعديل الصنف / الوحدة / الشحنة / الكمية / السعر بعد الحفظ، احذف السطر وأعد إدخاله',
              'Item, unit, lot, quantity and price cannot be changed after saving: delete the line and enter it again');
        end if;
        line_discounts(p_price_curr, p_d1_ratio, p_d1_value, p_d2_ratio, p_d2_value, p_d3_ratio, p_d3_value, p_qty, p_item);
      end if;
      return;
    end if;
    select * into mst from st_trns_mast where trns_type_code = p_type and trns_serial = p_serial;

    item_check(p_group, p_item);
    p_store := mst.store_code;                                                   -- PRE-INSERT: line store = header store
    l_mode1 := l_kind = 'SR' and mst.ret_trns_serial is not null;
    if l_mode1 then
      select * into inv from st_trns_mast where trns_type_code = mst.ret_trns_type_code and trns_serial = mst.ret_trns_serial;
      -- ITEM2_RG / CONFG_RG of the "with invoice" mode: items and lots of the original invoice only
      select count(*), min(unit_code) into l_n, p_unit from st_trns_det
       where trns_type_code = inv.trns_type_code and trns_serial = inv.trns_serial and group_code = p_group and item_code = p_item;
      if l_n = 0 then
        err(-20113, 'الصنف ' || p_item || ' غير موجود في الفاتورة ' || inv.trns_type_code || '/' || inv.trns_serial,
            'Item ' || p_item || ' is not on invoice ' || inv.trns_type_code || '/' || inv.trns_serial);
      end if;
    elsif p_unit is null then
      p_unit := basic_unit(p_group, p_item);
    end if;
    l_factor := unit_factor(p_group, p_item, p_unit);

    -- lot
    if p_confg is null and l_kind = 'SI' then
      select nvl(max(insert_sale_cnfg), 0) into l_cnfg from st_basic;
      if l_cnfg = 0 or (nvl(p_auto_disc, 0) = 1 and not p_split) then
        -- earliest expiry with stock: legacy automatic mode (INSERT_SALE_CNFG = 0, ITEM_CODE WHEN-VALIDATE-ITEM); also the
        -- stand-in for DEVIDE_CONFGS while the row rule cannot change the quantity (trns_det_row, before trns_det_row2)
        select min(c.item_confg_id) keep (dense_rank first order by c.expire_date, c.item_confg_id)
          into p_confg
          from st_item_confg c
         where c.group_code = p_group and c.item_code = p_item
           and get_balance_confg(mst.store_code, p_group, p_item, c.item_confg_id, mst.trns_date, mst.date_serial) / l_factor > 0;
      elsif nvl(p_auto_disc, 0) = 1 and nvl(p_qty, 0) <> 0 then
        -- QUANTITY KEY-NEXT-ITEM: CALC_SALES_DISC_TOT with the lot still empty, then DEVIDE_CONFGS
        if p_org_price is null then
          calc_sales_disc(mst.customer_code, p_group, p_item, p_unit, l_d1, l_d2, l_d3, l_bon, l_prc2, l_ext, l_cls,
                          mst.class_code, null);
          p_org_d1 := l_d1; p_org_d2 := l_d2; p_org_d3 := l_d3; p_org_bonus := l_bon;
          p_org_price := l_prc2; p_org_extra := l_ext; p_org_class := l_cls;
        end if;
        p_d1_ratio := p_org_d1; p_d2_ratio := p_org_d2; p_d3_ratio := p_org_d3;
        p_price_curr := p_org_price; p_extra_ratio := p_org_extra;
        p_d1_value := null; p_d2_value := null; p_d3_value := null;
        if nvl(p_org_bonus, 0) <> 0 and round(round(p_org_bonus * p_qty / 100) * 100 / p_org_bonus) <> 0 then
          p_qty := round(round(p_org_bonus * p_qty / 100) * 100 / p_org_bonus);
        end if;
        p_bonus := case when p_org_bonus is not null and nvl(p_price_curr, 0) <> 0 then round(p_org_bonus * p_qty / 100) else 0 end;
        p_extra_bonus := case when p_extra_ratio is not null and nvl(p_price_curr, 0) <> 0 then trunc(p_extra_ratio * p_qty / 100) else 0 end;
        l_auto_done := true;
        si_devide(mst, p_group, p_item, p_unit, l_factor, p_item_serial, p_confg, p_qty, p_bonus, p_extra_bonus,
                  p_price_curr, p_d1_ratio, p_d1_value, p_d2_ratio, p_d2_value, p_d3_ratio, p_d3_value);
      end if;
    end if;
    if p_confg is null then
      err(-20114, case when l_kind = 'SR' then 'يجب ادخال الشحنة' else 'يجب إدخال رقم الشحنة' end, 'Must Enter Lot No');
    end if;
    if l_kind = 'SR' and not l_mode1 and p_confg = -1 then
      -- CONFG_RG "شحنة قديمة" (-1): the lot is created with its lot number / expiry by GET_THE_CONFIG, which needs the
      -- non-database lot items of the legacy line: in APEX this is the action "صنف بشحنة قديمة" of the return
      err(-20114, 'لإدخال صنف بشحنة قديمة (-1) استخدم زر "صنف بشحنة قديمة" في المرتجع (رقم الشحنة وتاريخ الصلاحية مطلوبان)',
          'To return an item of an old lot (-1) use the button "Item of an old lot" (lot number and expiry date are required)');
    end if;
    select count(*) into l_n from st_item_confg where item_confg_id = p_confg and item_code = p_item;
    if l_n = 0 then
      err(-20115, case when l_kind = 'SR' then 'الشحنة ليست خاصة بالوحدة' else 'الشحنة ' || p_confg || ' لا تخص الصنف ' || p_item end,
          'Lot ' || p_confg || ' does not belong to item ' || p_item);
    end if;

    if l_kind = 'SI' then
      -- sales order link (ITEM2_RG second branch)
      if mst.order_trns_type_code is not null then
        select count(*) into l_n from st_sales_order_det
         where trns_type_code = mst.order_trns_type_code and trns_serial = mst.order_trns_serial
           and item_group_code = p_group and item_code = p_item;
        if l_n = 0 then
          err(-20113, 'الصنف ' || p_item || ' غير موجود في أمر البيع ' || mst.order_trns_type_code || '/' || mst.order_trns_serial,
              'Item ' || p_item || ' is not in sales order ' || mst.order_trns_type_code || '/' || mst.order_trns_serial);
        end if;
      end if;
      -- price policy of the customer / class / lot (CALC_SALES_DISC_TOT)
      if p_org_price is null then
        calc_sales_disc(mst.customer_code, p_group, p_item, p_unit, l_d1, l_d2, l_d3, l_bon, l_prc2, l_ext, l_cls,
                        mst.class_code, p_confg);
        p_org_d1 := l_d1; p_org_d2 := l_d2; p_org_d3 := l_d3; p_org_bonus := l_bon;
        p_org_price := l_prc2; p_org_extra := l_ext; p_org_class := l_cls;
      end if;
      p_auto_disc := nvl(p_auto_disc, 0);
      if p_auto_disc = 1 then
        p_d1_ratio := p_org_d1; p_d2_ratio := p_org_d2; p_d3_ratio := p_org_d3;
        p_price_curr := p_org_price; p_extra_ratio := p_org_extra;
        p_d1_value := null; p_d2_value := null; p_d3_value := null;
        if not l_auto_done and mst.order_trns_type_code is null then
          -- CALC_SALES_DISC_TOT of a manual line: bonus / extra bonus from the policy ratios (BONUS disabled with AUTO_DISC);
          -- the quantity is rounded to the bonus steps when the row rule may change it (trns_det_row2)
          if p_split and nvl(p_qty, 0) <> 0 and nvl(p_org_bonus, 0) <> 0
             and round(round(p_org_bonus * p_qty / 100) * 100 / p_org_bonus) <> 0 then
            p_qty := round(round(p_org_bonus * p_qty / 100) * 100 / p_org_bonus);
          end if;
          p_bonus := case when p_org_bonus is not null and nvl(p_price_curr, 0) <> 0 then round(p_org_bonus * nvl(p_qty, 0) / 100) else 0 end;
          p_extra_bonus := case when p_extra_ratio is not null and nvl(p_price_curr, 0) <> 0 then trunc(p_extra_ratio * nvl(p_qty, 0) / 100) else 0 end;
        end if;
      end if;
      if p_price_curr is null then
        err(-20116, 'يجب إدخال سعر الوحدة للصنف ' || p_item, 'Unit price is required for item ' || p_item);
      end if;
      if p_price_curr > 0 then                        -- UNIT_PRICE_CURR WHEN-VALIDATE-ITEM
        select nvl(min(retail_sale_price), 0) into l_retail
          from st_item_unit where group_code = p_group and item_code = p_item and nvl(factor, 0) = 1;
        if l_retail > 0 and l_retail > p_price_curr then
          err(-20117, 'السعر يجب ان يكون اكبر من سعر التجزئة (' || l_retail || ') للصنف ' || p_item,
              'Price must be greater than Retail price (' || l_retail || ') for item ' || p_item);
        end if;
      end if;
    elsif l_mode1 then
      -- price, discounts and line serial of the original invoice line (ITEM_CONFG_ID WHEN-VALIDATE-ITEM)
      select count(*), avg(nvl(unit_price_curr, 0)), avg(nvl(disc1_ratio, 0)), avg(nvl(disc2_ratio, 0)), avg(nvl(disc3_ratio, 0)),
             avg(nvl(disc1_value, 0)), avg(nvl(disc2_value, 0)), avg(nvl(disc3_value, 0)), max(item_serial)
        into l_n, p_price_curr, p_d1_ratio, p_d2_ratio, p_d3_ratio, p_d1_value, p_d2_value, p_d3_value, p_item_serial
        from st_trns_det
       where trns_type_code = inv.trns_type_code and trns_serial = inv.trns_serial
         and group_code = p_group and item_code = p_item and item_confg_id = p_confg;
      if l_n = 0 then
        err(-20115, 'الشحنة ' || p_confg || ' غير موجودة في الفاتورة للصنف ' || p_item, 'Lot ' || p_confg || ' is not on the invoice for item ' || p_item);
      end if;
      select count(*) into l_n from st_trns_det where trns_type_code = p_type and trns_serial = p_serial and item_serial = p_item_serial;
      if l_n > 0 then
        err(-20126, 'الشحنة ' || p_confg || ' مكررة في هذا المرتجع', 'Lot ' || p_confg || ' is already on this return');
      end if;
    else
      -- return without invoice: price list of the item (ITEM_CODE WHEN-VALIDATE-ITEM)
      if p_price_curr is null then
        select max(case when iu.reduction_price is not null then iu.reduction_price
                        when s.deal_type = 1 then iu.wide_sale_price
                        else iu.retail_sale_price end)
          into p_price_curr
          from st_item_unit iu, st_store s
         where iu.group_code = p_group and iu.item_code = p_item and iu.unit_code = p_unit and s.store_code = mst.store_code;
        p_price_curr := round(nvl(p_price_curr, 0) / nvl(mst.currency_rate, 1), 2);
      end if;
      if p_d1_ratio is null and p_d1_value is null then
        select max(moh_disc) into p_d1_ratio from st_item where item_group_code = p_group and item_code = p_item;
      end if;
    end if;

    -- quantities
    p_bonus := nvl(p_bonus, 0);
    if p_extra_ratio is not null and p_extra_bonus is null then
      p_extra_bonus := round(p_extra_ratio * nvl(p_qty, 0) / 100);
    elsif p_extra_bonus is not null and nvl(p_qty, 0) <> 0 then
      p_extra_ratio := p_extra_bonus / p_qty * 100;
    end if;
    p_extra_bonus := nvl(p_extra_bonus, 0);
    if nvl(p_qty, 0) < 0 or p_bonus < 0 or p_extra_bonus < 0 then
      err(-20118, 'أدخل رقم بقيمة تبدأ من الصفر', 'Enter Value From Zero');
    end if;
    if nvl(p_qty, 0) + p_bonus + p_extra_bonus <= 0 then
      if l_kind = 'SR' then
        err(-20118, 'القيمة يجب أن تكون أكبر من أو تســاوى صفر', 'Value Must Be More Than or Equal Zero');
      end if;
      err(-20118, 'الكمية و البونص يجب أن يكون مجموعهما أكبر من صفر', 'Sum of Qty And Bonus Must Be More Than Zero');
    end if;
    if nvl(p_price_curr, 0) < 0 then
      err(-20116, 'السعر يجب أن تكون أكبر من صفر', 'Price Must Be More Than Zero');
    end if;
    p_basic_qty := (nvl(p_qty, 0) + p_bonus + p_extra_bonus) * l_factor;
    p_price := p_price_curr * nvl(mst.currency_rate, 1);
    if not l_mode1 then
      line_discounts(p_price_curr, p_d1_ratio, p_d1_value, p_d2_ratio, p_d2_value, p_d3_ratio, p_d3_value, p_qty, p_item);
    end if;

    if l_kind = 'SI' then
      -- PRE-INSERT: lump discount of the line
      if nvl(p_det_disc, 0) < 0 or (nvl(p_qty, 0) <> 0 and p_price_curr * p_qty < nvl(p_det_disc, 0))
         or (nvl(p_qty, 0) = 0 and nvl(p_det_disc, 0) <> 0) then
        err(-20120, 'قيمة الخصم يجب أن تكون أقل من مجموع الأصناف', 'Descount Value Must Be Less Than Total Items');
      end if;
      p_disc := nvl(p_disc, 0);
      -- sales order balance (PRE-INSERT: GET_PROPOSAL_UNIT_RFQ)
      if mst.order_trns_type_code is not null then
        l_left := get_proposal_unit_rfq(mst.order_trns_type_code, mst.order_trns_serial, p_group, p_item, p_unit);
        if p_basic_qty > l_left then
          err(-20121, 'الكمية المباعة اكبر من كمية امر البيع ' || round(l_left / l_factor, 3),
              'Invoice Qty More Than S.O Qty ' || round(l_left / l_factor, 3));
        end if;
      end if;
      -- stock (PRE-INSERT / POST-INSERT when ST_BASIC.NEG_SALE_BALANCE = 0)
      select nvl(max(neg_sale_balance), 0) into l_neg from st_basic;
      if l_neg = 0 then
        l_bal := get_balance_confg(mst.store_code, p_group, p_item, p_confg, mst.trns_date, mst.date_serial, p_item_serial);
        if nvl(l_bal, 0) < nvl(p_qty, 0) * l_factor then
          err(-20122, 'رصيــد هذه الشحنة لهذا صنف فى هذا التاريخ لا يسمــح: الصنف ' || p_item || ' الشحنة ' || p_confg
                      || ' الرصيد = ' || round(nvl(l_bal, 0) / l_factor, 2),
              'Lot Balance For This Item in This Date Can''t Allow: item ' || p_item || ' lot ' || p_confg
                      || ' balance = ' || round(nvl(l_bal, 0) / l_factor, 2));
        end if;
        if update_next_trns_confg(mst.store_code, p_group, p_item, p_confg, mst.trns_date, mst.date_serial, p_item_serial,
                                  nvl(l_bal, 0) - p_basic_qty) <> 0 then
          err(-20123, 'الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها (الصنف ' || p_item || ')',
              'Balance Can''t Allow There are Other Transaction conflict With This One (item ' || p_item || ')');
        end if;
      end if;
      p_unit_cost := null;
      p_cost_flag := 1;
      -- VAT on LINE_TOTAL (GET_LINE_TOTAL: base price minus the discount values as entered)
      l_line := round(nvl(p_qty, 0) * (p_price - (nvl(p_d1_value, 0) + nvl(p_d2_value, 0) + nvl(p_d3_value, 0)))
                      - nvl(p_det_disc, 0), 2);
      line_tax(p_group, p_item, mst.customer_code, null, mst.trns_date, l_line, p_tax_code, p_tax_value);
    else
      p_det_disc := 0;                                           -- QUANTITY WHEN-VALIDATE-ITEM resets the line discount
      p_disc := 0;
      p_cost_flag := 1;
      if l_mode1 then
        -- CHECK_RETURN_QTY: returned so far (all returns of the invoice, this lot) + this line <= sold
        select nvl(sum(nvl(d.quantity, 0) + nvl(d.bonus, 0) + nvl(d.extra_bonus, 0)), 0) into l_ret
          from st_trns_mast m, st_trns_det d
         where m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial
           and m.ret_trns_type_code = inv.trns_type_code and m.ret_trns_serial = inv.trns_serial
           and d.item_confg_id = p_confg and nvl(m.delete_flag, 0) = 0 and nvl(d.delete_flag, 0) = 0;
        select nvl(sum(nvl(quantity, 0) + nvl(bonus, 0) + nvl(extra_bonus, 0)), 0) into l_org
          from st_trns_det
         where trns_type_code = inv.trns_type_code and trns_serial = inv.trns_serial and item_confg_id = p_confg;
        if l_ret + (nvl(p_qty, 0) + p_bonus + p_extra_bonus) * l_factor > l_org then
          err(-20127, ' إجمالى الكمية المرتجعة اكبر من اجمالى الكمية المباعة - الكمية = ' || (l_org * l_factor),
              'The total return quantity should be less or equal than original quantity ' || (l_org * l_factor));
        end if;
        -- cost of the original sale (store / date of the invoice)
        p_unit_cost := get_unit_cost_confg(inv.store_code, p_group, p_item, p_confg, inv.trns_date, inv.date_serial, null);
        -- tax at the invoice's rate (GET_ACT_TAX_PRC) on BASIC_QTY x net price
        line_tax(p_group, p_item, mst.customer_code, null, mst.trns_date, 0, p_tax_code, p_tax_value);
        l_prc := get_act_tax_prc(inv.trns_type_code, inv.trns_serial, p_group, p_item);
        p_tax_value := round(l_prc * (p_basic_qty * (p_price_curr - (nvl(p_d1_value, 0) + nvl(p_d2_value, 0) + nvl(p_d3_value, 0)))) / 100, 2);
      else
        -- cost as of the end of the return date (legacy DATE_SERIAL 99999999 at PRE-INSERT)
        p_unit_cost := get_unit_cost_confg(mst.store_code, p_group, p_item, p_confg, mst.trns_date, 99999999, null);
        line_tax(p_group, p_item, mst.customer_code, null, mst.trns_date,
                 p_basic_qty * (p_price_curr - (nvl(p_d1_value, 0) + nvl(p_d2_value, 0) + nvl(p_d3_value, 0))), p_tax_code, p_tax_value);
      end if;
      if nvl(p_unit_cost, 0) = 0 then                            -- cost from the item file (IU_UNIT_COST)
        select max(iu_unit_cost) into p_unit_cost from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit;
      end if;
    end if;
  end det_core;

  procedure trns_det_row (
    p_inserting   in boolean,
    p_type        in number,   p_serial      in number,   p_item_serial in out number,
    p_group       in out number,   p_item        in varchar2, p_unit        in out number,
    p_confg       in out number,
    p_qty         in number,       p_bonus       in out number,
    p_extra_bonus in out number,   p_extra_ratio in out number,
    p_basic_qty   in out number,
    p_price_curr  in out number,   p_price       in out number,
    p_d1_ratio    in out number,   p_d1_value    in out number,
    p_d2_ratio    in out number,   p_d2_value    in out number,
    p_d3_ratio    in out number,   p_d3_value    in out number,
    p_det_disc    in out number,   p_disc        in out number,
    p_cost_flag   in out number,   p_unit_cost   in out number,
    p_store       in out number,
    p_tax_code    in out number,   p_tax_value   in out number,
    p_auto_disc   in out number,
    p_org_d1      in out number,   p_org_d2      in out number,   p_org_d3      in out number,
    p_org_bonus   in out number,   p_org_price   in out number,   p_org_extra   in out number,
    p_org_class   in out number,
    p_old_item    in varchar2,     p_old_unit    in number,       p_old_confg   in number,
    p_old_qty     in number,       p_old_bonus   in number,       p_old_extra   in number,
    p_old_price_curr in number) is
    l_qty number := p_qty;
  begin
    det_core(p_inserting, p_type, p_serial, p_item_serial, p_group, p_item, p_unit, p_confg, l_qty, p_bonus, p_extra_bonus,
             p_extra_ratio, p_basic_qty, p_price_curr, p_price, p_d1_ratio, p_d1_value, p_d2_ratio, p_d2_value, p_d3_ratio,
             p_d3_value, p_det_disc, p_disc, p_cost_flag, p_unit_cost, p_store, p_tax_code, p_tax_value, p_auto_disc,
             p_org_d1, p_org_d2, p_org_d3, p_org_bonus, p_org_price, p_org_extra, p_org_class, p_old_item, p_old_unit,
             p_old_confg, p_old_qty, p_old_bonus, p_old_extra, p_old_price_curr, false);
  end trns_det_row;

  procedure trns_det_row2 (
    p_inserting   in boolean,
    p_type        in number,   p_serial      in number,   p_item_serial in out number,
    p_group       in out number,   p_item        in varchar2, p_unit        in out number,
    p_confg       in out number,
    p_qty         in out number,   p_bonus       in out number,
    p_extra_bonus in out number,   p_extra_ratio in out number,
    p_basic_qty   in out number,
    p_price_curr  in out number,   p_price       in out number,
    p_d1_ratio    in out number,   p_d1_value    in out number,
    p_d2_ratio    in out number,   p_d2_value    in out number,
    p_d3_ratio    in out number,   p_d3_value    in out number,
    p_det_disc    in out number,   p_disc        in out number,
    p_cost_flag   in out number,   p_unit_cost   in out number,
    p_store       in out number,
    p_tax_code    in out number,   p_tax_value   in out number,
    p_auto_disc   in out number,
    p_org_d1      in out number,   p_org_d2      in out number,   p_org_d3      in out number,
    p_org_bonus   in out number,   p_org_price   in out number,   p_org_extra   in out number,
    p_org_class   in out number,
    p_old_item    in varchar2,     p_old_unit    in number,       p_old_confg   in number,
    p_old_qty     in number,       p_old_bonus   in number,       p_old_extra   in number,
    p_old_price_curr in number) is
  begin
    det_core(p_inserting, p_type, p_serial, p_item_serial, p_group, p_item, p_unit, p_confg, p_qty, p_bonus, p_extra_bonus,
             p_extra_ratio, p_basic_qty, p_price_curr, p_price, p_d1_ratio, p_d1_value, p_d2_ratio, p_d2_value, p_d3_ratio,
             p_d3_value, p_det_disc, p_disc, p_cost_flag, p_unit_cost, p_store, p_tax_code, p_tax_value, p_auto_disc,
             p_org_d1, p_org_d2, p_org_d3, p_org_bonus, p_org_price, p_org_extra, p_org_class, p_old_item, p_old_unit,
             p_old_confg, p_old_qty, p_old_bonus, p_old_extra, p_old_price_curr, true);
  end trns_det_row2;

  -- parts queued by si_devide for this invoice: one line each (ITEM_SERIAL max + 1, price and discounts of the first part,
  -- policy values of its own lot, LAST_EXPIRE_DATE), written with the row rule computed here and the rule standing aside
  procedure si_insert_splits (mst in st_trns_mast%rowtype) is
    r st_trns_det%rowtype;
    s t_split;
    l_d1 number; l_d2 number; l_d3 number; l_bon number; l_prc number; l_ext number; l_cls number;
  begin
    for i in 1 .. g_split.count loop
      s := g_split(i);
      if s.ttype = mst.trns_type_code and s.tserial = mst.trns_serial then
        r := null;
        r.trns_type_code := mst.trns_type_code; r.trns_serial := mst.trns_serial;
        select nvl(max(item_serial), 0) + 1 into r.item_serial from st_trns_det
         where trns_type_code = mst.trns_type_code and trns_serial = mst.trns_serial;
        r.group_code := s.grp; r.item_code := s.item; r.unit_code := s.unit; r.item_confg_id := s.confg;
        r.quantity := s.qty; r.bonus := s.bonus; r.extra_bonus := s.extra; r.unit_price_curr := s.price_curr;
        r.disc1_ratio := s.d1r; r.disc2_ratio := s.d2r; r.disc3_ratio := s.d3r;
        r.disc1_value := s.d1v; r.disc2_value := s.d2v; r.disc3_value := s.d3v;
        calc_sales_disc(mst.customer_code, s.grp, s.item, s.unit, l_d1, l_d2, l_d3, l_bon, l_prc, l_ext, l_cls, mst.class_code, s.confg);
        r.org_disc1_ratio := l_d1; r.org_disc2_ratio := l_d2; r.org_disc3_ratio := l_d3; r.org_bonus_ratio := l_bon;
        r.org_unit_price_curr := l_prc; r.org_extra_bonus_ratio := l_ext; r.org_class_code := l_cls;
        r.auto_disc := 0;
        det_core(true, r.trns_type_code, r.trns_serial, r.item_serial, r.group_code, r.item_code, r.unit_code, r.item_confg_id,
                 r.quantity, r.bonus, r.extra_bonus, r.extra_bonus_ratio, r.basic_qty, r.unit_price_curr, r.unit_price,
                 r.disc1_ratio, r.disc1_value, r.disc2_ratio, r.disc2_value, r.disc3_ratio, r.disc3_value, r.det_disc, r.disc,
                 r.cost_flag, r.unit_cost, r.store_code, r.tax_code1, r.tax_value1, r.auto_disc, r.org_disc1_ratio,
                 r.org_disc2_ratio, r.org_disc3_ratio, r.org_bonus_ratio, r.org_unit_price_curr, r.org_extra_bonus_ratio,
                 r.org_class_code, null, null, null, null, null, null, null, false);
        r.auto_disc := 1;                                       -- the new record of the legacy block (AUTO_DISC initial value 1)
        r.last_expire_date := get_last_ex_date(mst.store_code, s.grp, s.item);
        r.trns_date := mst.trns_date; r.date_serial := mst.date_serial; r.delete_flag := 0;
        r.freight := 0; r.customs := 0; r.transport := 0; r.insurance := 0; r.commission := 0; r.others := 0;
        g_bypass := true;
        insert into st_trns_det values r;
        g_bypass := false;
      end if;
    end loop;
    g_split.delete;
  exception when others then
    g_bypass := false;
    g_split.delete;
    raise;
  end si_insert_splits;

  -- ================================================================== ST_TRNS_SERVICES row rule (SI, SR)
  procedure trns_srv_row (
    p_inserting   in boolean,
    p_type        in number,   p_serial      in number,   p_service     in number,
    p_cost        in out number,   p_units       in out number,
    p_tax_code    in out number,   p_tax_value   in out number) is
    l_kind varchar2(4) := doc_kind(p_type);
    l_rate number;
    l_per  number;
    l_ret_type number; l_ret_serial number; l_n number;
  begin
    if g_bypass or nvl(l_kind, '-') not in ('SI', 'SR') then
      return;
    end if;
    select nvl(max(currency_rate), 1), max(ret_trns_type_code), max(ret_trns_serial) into l_rate, l_ret_type, l_ret_serial
      from st_trns_mast where trns_type_code = p_type and trns_serial = p_serial;
    if l_kind = 'SR' and l_ret_serial is not null then         -- SERVICE_RG of the "with invoice" mode
      select count(*) into l_n from st_trns_services
       where trns_type_code = l_ret_type and trns_serial = l_ret_serial and service_code = p_service;
      if l_n = 0 then
        err(-20128, 'الخدمة ' || p_service || ' غير موجودة في الفاتورة الأصلية', 'Service ' || p_service || ' is not on the original invoice');
      end if;
    end if;
    if p_cost is null then
      select max(unit_cost) into p_cost from st_pd_services where service_code = p_service;   -- SERVICE_RG default price
    end if;
    if nvl(p_cost, 0) <= 0 then
      err(-20124, 'سعر بيع الخدمة يجب أن يكون أكبر من صفر', 'Service Cost Must Be Greater Than Zero');
    end if;
    p_units := nvl(p_units, 1);
    begin
      select tax_per into l_per from tx_taxes_services where service_code = p_service;
      p_tax_value := (l_per / 100) * (p_cost / l_rate) * p_units;
    exception when others then
      p_tax_value := 0;
    end;
  end trns_srv_row;

  -- ================================================================== document totals / snapshots
  function lines_net (p_type in number, p_serial in number) return number is
    l number;
  begin
    select sum(round(nvl(quantity, 0) * (nvl(unit_price, 0) - (nvl(disc1_value, 0) + nvl(disc2_value, 0) + nvl(disc3_value, 0)))
                     - nvl(det_disc, 0), 2))
      into l from st_trns_det where trns_type_code = p_type and trns_serial = p_serial;
    return nvl(l, 0);
  end lines_net;

  procedure snap_trns (p_rowid in varchar2, p_type in number, p_serial in number) is
  begin
    g_snap_rowid := p_rowid;
    g_snap_net   := lines_net(p_type, p_serial);
    g_snap_det.delete;
    select item_serial, group_code, item_code, item_confg_id, store_code, trns_date, date_serial, basic_qty, 0
      bulk collect into g_snap_det
      from st_trns_det where trns_type_code = p_type and trns_serial = p_serial;
    g_snap_lines := g_snap_det.count;
  end snap_trns;

  -- ================================================================== ST_ISSUE_IO page rules
  function si_validate (
    p_request   in varchar2, p_rowid     in varchar2,
    p_type      in varchar2, p_date      in varchar2, p_store     in varchar2,
    p_customer  in varchar2, p_salesman  in varchar2,
    p_currency  in varchar2, p_rate      in varchar2, p_class     in varchar2,
    p_order_type in varchar2, p_order_serial in varchar2) return varchar2 is
    l_type   number := to_n(p_type);
    l_date   date   := to_d(p_date);
    l_store  number := to_n(p_store);
    l_cust   number := to_n(p_customer);
    l_sman   number := to_n(p_salesman);
    l_curr   number := nvl(to_n(p_currency), 1);
    l_rate   number := to_n(p_rate);
    l_class  number := to_n(p_class);
    l_otype  number := to_n(p_order_type);
    l_oser   number := to_n(p_order_serial);
    l_new    boolean := p_rowid is null;
    old      st_trns_mast%rowtype;
    t        st_trns_type%rowtype;
    so       st_sales_order%rowtype;
    l_lines  number := 0;
    l_msg    varchar2(4000);
    l_n      number;
  begin
    g_snap_rowid := null;
    g_split.delete;                                          -- DEVIDE_CONFGS parts of this page submit (si_after_save)
    if not l_new then
      begin
        select * into old from st_trns_mast where rowid = chartorowid(p_rowid);
      exception when no_data_found then
        return m('المستند غير موجود (ربما حذف من مستخدم آخر)', 'The document no longer exists');
      end;
      if nvl(old.post_flag, 0) = 1 or nvl(old.cust_post_flag, 0) = 1 or nvl(old.supp_post_flag, 0) = 1 then   -- CLOSE_POSTED
        return m('لا يمكن تعديل هذه الحركة لأنها مرحلة', 'Can''t Update This record: the document is posted');
      end if;
      if nvl(old.delete_flag, 0) = 1 then
        return m('لا يمكن تعديل مستند ملغي', 'The document is deleted');
      end if;
      select count(*) into l_lines from st_trns_det where trns_type_code = old.trns_type_code and trns_serial = old.trns_serial;
      if l_type <> old.trns_type_code then
        return m('لا يمكن تغيير نوع الحركة بعد الحفظ', 'The transaction type cannot be changed after saving');
      end if;
    end if;
    l_msg := type_error(l_type, 'SI');
    if l_msg is not null then return l_msg; end if;
    select * into t from st_trns_type where trns_type_code = l_type;

    -- PRE-TEXT-ITEM of STORE / CUSTOMER / SALESMAN / CURRENCY / CLASS / order: frozen once lines exist
    if l_lines > 0 and (changed(l_store, old.store_code) or changed(l_cust, old.customer_code) or changed(l_sman, old.salesman_code)
                        or l_curr <> nvl(old.currency_code, 1) or changed(l_rate, old.currency_rate) or changed(l_class, old.class_code)
                        or changed(l_otype, old.order_trns_type_code) or changed(l_oser, old.order_trns_serial)) then
      return m('برجاء حذف الاصناف اولا (لا يمكن تغيير المخزن / العميل / المندوب / العملة / الفئة / أمر البيع بعد إدخال الأصناف)',
               'Please Delete Inserted Items First (store / customer / salesman / currency / class / sales order cannot change)');
    end if;
    l_store := nvl(l_store, t.store_code);
    if l_store is null then
      return m('يجب إدخال المخزن', 'Store is required');
    end if;
    if l_new or changed(l_store, old.store_code) then
      l_msg := store_error(l_store);
      if l_msg is not null then return l_msg; end if;
    end if;
    -- date: only users with USERS.CHANGE_INV_DATE_FLAG = 1 (or user 0) may change it (SET_DATE_PRV); CHECK_DATE
    if usr <> 0 and user_flag('CHANGE_INV_DATE_FLAG') = 0 then
      if (l_new and trunc(l_date) <> trunc(sysdate)) or (not l_new and l_date <> old.trns_date) then
        return m('غير مسموح لك بتغيير تاريخ الفاتورة', 'You are not allowed to change the invoice date');
      end if;
    end if;
    if l_new or l_date <> old.trns_date or changed(l_cust, old.customer_code) then
      l_msg := date_error(l_date, l_cust);
      if l_msg is not null then return l_msg; end if;
    end if;
    -- sales order (list RFQ + make-invoice checks of ST_SALES_ORDER)
    if (l_otype is null) <> (l_oser is null) then
      return m('يجب إدخال نوع ورقم أمر البيع معاً', 'Enter both the sales order type and serial');
    end if;
    if l_otype is not null and (l_new or changed(l_otype, old.order_trns_type_code) or changed(l_oser, old.order_trns_serial)) then
      begin
        select * into so from st_sales_order where trns_type_code = l_otype and trns_serial = l_oser;
      exception when no_data_found then
        return m('أمر البيع ' || l_otype || '/' || l_oser || ' غير موجود', 'Sales order ' || l_otype || '/' || l_oser || ' does not exist');
      end;
      if nvl(so.approved, 0) = 0 then return m('يجب اعتماد امر البيع أولا', 'Approve the sales order first'); end if;
      if nvl(so.approved2, 0) = 0 then return m('يجب اعتماد امر البيع 2 أولا', 'Approve the sales order (level 2) first'); end if;
      if so.sl_trns_type_code is not null and so.sl_trns_serial is not null then
        return m('امر البيع تم تحويلها إلي فاتورة مبيعات', 'The sales order was already converted to a sales invoice');
      end if;
      select count(*) into l_n from st_trns_type where trns_type_code = l_otype and sales_trns_type_code = l_type;
      if nvl(so.closed, 0) = 1 or so.delete_date is not null or l_n = 0 or (l_cust is not null and so.customer_code <> l_cust)
         or so.order_date > l_date or get_proposal_rfq(so.trns_type_code, so.trns_serial, null, null) <= 0 then
        return m('أمر البيع ' || l_otype || '/' || l_oser || ' مغلق أو ملغي أو لعميل آخر أو لنوع فاتورة آخر أو تم صرفه بالكامل',
                 'Sales order ' || l_otype || '/' || l_oser || ' is closed, cancelled, for another customer / invoice type or fully invoiced');
      end if;
      l_cust := nvl(l_cust, so.customer_code);
      l_sman := nvl(l_sman, so.salesman_code);
    end if;
    -- customer (JOIN_TYPE 3 = customer transaction, CUSTOMER_RG)
    if l_cust is null and nvl(t.join_type, 0) = 3 then
      return m('يجب إدخال العميل', 'Customer is required');
    end if;
    if l_cust is not null and (l_new or changed(l_cust, old.customer_code)) then
      l_msg := customer_error(l_cust);
      if l_msg is not null then return l_msg; end if;
    end if;
    -- salesman (HAS_SALESMAN: required unless derived from the customer; SALESMAN_RG)
    if nvl(t.has_salesman, 0) = 1 and l_sman is null and (l_cust is null or get_last_salesman_indate(l_cust) is null) then
      return m('يجب إدخال المندوب', 'Salesman is required');
    end if;
    if l_sman is not null and (l_new or changed(l_sman, old.salesman_code) or changed(l_cust, old.customer_code)) then
      l_msg := salesman_error(l_sman, l_cust);
      if l_msg is not null then return l_msg; end if;
    end if;
    -- currency rate (CURRENCY_RATE WHEN-VALIDATE-ITEM)
    if l_rate is not null and l_rate <= 0 then
      return m('يجب ادخال معامل التحويل', 'You must enter the Conversion Code');
    end if;
    if l_curr = 1 and nvl(l_rate, 1) <> 1 then
      return m('معامل تحويل الريال يجب ان يكون ب 1', 'Rate Must Be 1');
    end if;
    -- customer class: only users with USERS.ENABLE_CHANGE_CLASS = 1 or group 0 (GET_USER_SEC)
    if (l_new and l_class is not null) or (not l_new and changed(l_class, old.class_code)) then
      if pw <> 0 and user_flag('ENABLE_CHANGE_CLASS') = 0 then
        return m('غير مسموح لك بتغيير الفئة', 'You are not allowed to change the class');
      end if;
    end if;
    if not l_new then
      snap_trns(p_rowid, old.trns_type_code, old.trns_serial);
    end if;
    return null;
  end si_validate;

  procedure si_after_save (p_request in varchar2, p_rowid in varchar2) is
    mst     st_trns_mast%rowtype;
    l_net   number;
    l_lines number;
    l_tax   number;
    l_srv   number;
    l_limit number;
    l_bal   number;
    l_max   number;
    l_v1 number; l_v2 number; l_v3 number; l_r1 number; l_r2 number; l_r3 number;
    l_linked number;
    l_rate  number;
    l_tot   number;
  begin
    if p_rowid is null then return; end if;
    select * into mst from st_trns_mast where rowid = chartorowid(p_rowid);
    if nvl(doc_kind(mst.trns_type_code), '-') <> 'SI' then return; end if;
    l_rate := nvl(mst.currency_rate, 1);
    -- lines split over lots by the row rule (DEVIDE_CONFGS): the other parts
    if g_split.count > 0 then
      si_insert_splits(mst);
    end if;

    -- invoice created from a sales order: copy the order lines (ST_SALES_ORDER.INSERT_DET) and link the order
    if p_request = 'CREATE' and mst.order_trns_type_code is not null then
      select count(*) into l_lines from st_trns_det where trns_type_code = mst.trns_type_code and trns_serial = mst.trns_serial;
      if l_lines = 0 then
        for o in (select * from st_sales_order_det
                   where trns_type_code = mst.order_trns_type_code and trns_serial = mst.order_trns_serial order by serial) loop
          insert into st_trns_det (trns_type_code, trns_serial, group_code, item_code, unit_code, item_confg_id, quantity, bonus,
                                   extra_bonus, extra_bonus_ratio, unit_price_curr, disc1_ratio, disc2_ratio, disc3_ratio,
                                   det_disc, auto_disc, org_disc1_ratio, org_disc2_ratio, org_disc3_ratio, org_bonus_ratio,
                                   org_unit_price_curr, org_extra_bonus_ratio, org_class_code, remark, delete_flag,
                                   freight, customs, transport, insurance, commission, others)
          values (mst.trns_type_code, mst.trns_serial, o.item_group_code, o.item_code, o.unit_code, o.item_confg_id, o.quantity, o.bonus,
                  o.extra_bonus, o.extra_bonus_ratio, o.unit_price_curr, o.disc1_ratio, o.disc2_ratio, o.disc3_ratio,
                  o.det_disc, o.auto_disc, o.org_disc1_ratio, o.org_disc2_ratio, o.org_disc3_ratio, o.org_bonus_ratio,
                  o.org_unit_price_curr, o.org_extra_bonus_ratio, o.org_class_code, o.remark, 0, 0, 0, 0, 0, 0, 0);
        end loop;
        update st_sales_order set sl_trns_type_code = mst.trns_type_code, sl_trns_serial = mst.trns_serial,
               doc_no = nvl(doc_no, mst.doc_no)
         where trns_type_code = mst.order_trns_type_code and trns_serial = mst.order_trns_serial;
      end if;
    end if;

    l_net := lines_net(mst.trns_type_code, mst.trns_serial);
    select count(*), nvl(sum(tax_value1), 0) into l_lines, l_tax
      from st_trns_det where trns_type_code = mst.trns_type_code and trns_serial = mst.trns_serial;
    select nvl(sum(nvl(service_cost, 0) * nvl(units_no, 0) + nvl(tax_value1, 0) * l_rate), 0) into l_srv
      from st_trns_services where trns_type_code = mst.trns_type_code and trns_serial = mst.trns_serial;

    -- invoice created from a sales order (ST_SALES_ORDER.SL_TRNS_*): lines are locked (CLOSE_POSTED)
    select count(*) into l_linked from st_sales_order
     where sl_trns_type_code = mst.trns_type_code and sl_trns_serial = mst.trns_serial;
    if l_linked > 0 and p_request <> 'CREATE' and g_snap_rowid = p_rowid and (l_lines <> g_snap_lines or l_net <> g_snap_net) then
      err(-20131, 'لا يمكن تعديل أصناف فاتورة محولة من أمر بيع', 'The items of an invoice created from a sales order cannot be changed');
    end if;

    -- invoice-level discount (DISC_VAL): below the invoice and within USERS.MAX_DISC_RATIO; spread per line (GET_NDB_DISC)
    if nvl(mst.disc_val, 0) <> 0 then
      if mst.disc_val > l_net then
        err(-20132, 'قيمة الخصم يجب أن تكون أقل من قيمة الفاتورة', 'Desc Value Must Be Less Than Invoice Value');
      end if;
      l_max := user_flag('MAX_DISC_RATIO');
      if l_net <> 0 and l_max < mst.disc_val / l_net * 100 then
        err(-20133, 'لا يمكن تخطي نسبة الخصم للمستخدم (' || l_max || '%)', 'The user discount ratio (' || l_max || '%) cannot be exceeded');
      end if;
      g_bypass := true;
      update st_trns_det d
         set d.disc = round(mst.disc_val * round(nvl(d.quantity, 0) * (nvl(d.unit_price, 0) - (nvl(d.disc1_value, 0) + nvl(d.disc2_value, 0)
                              + nvl(d.disc3_value, 0))) - nvl(d.det_disc, 0), 2) / (l_net * nullif(d.basic_qty, 0)), 6)
       where d.trns_type_code = mst.trns_type_code and d.trns_serial = mst.trns_serial and l_net <> 0;
      g_bypass := false;
    end if;

    l_r1 := mst.tot_disc1_ratio; l_v1 := mst.tot_disc1_value;
    l_r2 := mst.tot_disc2_ratio; l_v2 := mst.tot_disc2_value;
    l_r3 := mst.tot_disc3_ratio; l_v3 := mst.tot_disc3_value;
    tot_discounts(l_net, l_r1, l_v1, l_r2, l_v2, l_r3, l_v3);
    -- TOT_VAL := NET_VALUE_CURR (PRE-INSERT / detail PRE-INSERT, PRE-UPDATE)
    l_tot := round((l_net + l_tax + l_srv + nvl(mst.trnsport_val, 0) - nvl(mst.disc_val, 0)
                    - nvl(l_v1, 0) - nvl(l_v2, 0) - nvl(l_v3, 0)) / l_rate);
    if changed(l_r1, mst.tot_disc1_ratio) or changed(l_v1, mst.tot_disc1_value) or changed(l_r2, mst.tot_disc2_ratio)
       or changed(l_v2, mst.tot_disc2_value) or changed(l_r3, mst.tot_disc3_ratio) or changed(l_v3, mst.tot_disc3_value)
       or changed(l_tot, mst.tot_val) then
      update st_trns_mast
         set tot_disc1_ratio = l_r1, tot_disc1_value = l_v1, tot_disc2_ratio = l_r2, tot_disc2_value = l_v2,
             tot_disc3_ratio = l_r3, tot_disc3_value = l_v3, tot_val = l_tot
       where rowid = chartorowid(p_rowid);
    end if;

    -- credit limit (master PRE-INSERT: CREDIT_LIMIT < NET_VALUE + GET_CUSTOMER_BAL_ALL): checked when the invoice
    -- is created or grows; GET_CUSTOMER_BAL_ALL already contains this unposted invoice after the save
    if mst.customer_code is not null
       and (p_request = 'CREATE' or g_snap_rowid is null or g_snap_rowid <> p_rowid or l_net > g_snap_net) then
      select nvl(max(credit_limit), 0) into l_limit from customer where code = mst.customer_code;
      l_bal := get_customer_bal_all(mst.customer_code);
      if l_limit < l_bal then
        err(-20134, 'هذا العميل تخطى الحد الائتمانى (الحد ' || l_limit || ' - الرصيد مع الفاتورة ' || round(l_bal, 2) || ')',
            'This Customer Trespass His Credit Limit (limit ' || l_limit || ', balance incl. invoice ' || round(l_bal, 2) || ')');
      end if;
    end if;
    g_snap_rowid := null;
  exception when others then
    g_bypass := false;
    raise;
  end si_after_save;

  -- ================================================================== ST_ISSUE_RETURN page rules
  function sr_validate (
    p_request   in varchar2, p_rowid     in varchar2,
    p_type      in varchar2, p_date      in varchar2, p_store     in varchar2,
    p_customer  in varchar2, p_salesman  in varchar2,
    p_currency  in varchar2, p_rate      in varchar2,
    p_ret_inv_code in varchar2, p_invoice_no in varchar2) return varchar2 is
    l_type   number := to_n(p_type);
    l_date   date   := to_d(p_date);
    l_store  number := to_n(p_store);
    l_cust   number := to_n(p_customer);
    l_sman   number := to_n(p_salesman);
    l_curr   number := nvl(to_n(p_currency), 1);
    l_rate   number := to_n(p_rate);
    l_reason number := to_n(p_ret_inv_code);
    l_new    boolean := p_rowid is null;
    old      st_trns_mast%rowtype;
    t        st_trns_type%rowtype;
    inv      st_trns_mast%rowtype;
    l_rtype  number;
    l_rser   number;
    l_lines  number := 0;
    l_msg    varchar2(4000);
    l_n      number;
  begin
    g_snap_rowid := null;
    if not l_new then
      begin
        select * into old from st_trns_mast where rowid = chartorowid(p_rowid);
      exception when no_data_found then
        return m('المستند غير موجود (ربما حذف من مستخدم آخر)', 'The document no longer exists');
      end;
      if nvl(old.post_flag, 0) = 1 or nvl(old.cust_post_flag, 0) = 1 or nvl(old.supp_post_flag, 0) = 1 then
        return m('الفاتورة تم ترحيلها للأنظمة الأخري', 'The document is posted to the other systems');
      end if;
      if nvl(old.delete_flag, 0) = 1 then
        return m('لا يمكن تعديل مستند ملغي', 'The document is deleted');
      end if;
      select count(*) into l_lines from st_trns_det where trns_type_code = old.trns_type_code and trns_serial = old.trns_serial;
      if l_type <> old.trns_type_code then
        return m('لا يمكن تغيير نوع الحركة بعد الحفظ', 'The transaction type cannot be changed after saving');
      end if;
    end if;
    l_msg := type_error(l_type, 'SR');
    if l_msg is not null then return l_msg; end if;
    select * into t from st_trns_type where trns_type_code = l_type;

    -- original invoice ("with invoice" mode: INVOICE_NO = 'TYPE\SERIAL', list INVOICE_RGP)
    if not l_new then
      l_rtype := old.ret_trns_type_code; l_rser := old.ret_trns_serial;
    end if;
    if l_new or changed_s(p_invoice_no, old.invoice_no) then
      l_rtype := null; l_rser := null;
      if p_invoice_no is not null then
        if not regexp_like(p_invoice_no, '^\s*\d+\s*[\/-]\s*\d+\s*$') then
          return m('اكتب رقم الفاتورة الأصلية بالشكل نوع\مسلسل (مثل 10301\608) أو اتركه فارغا للمرتجع بدون فاتورة',
                   'Enter the original invoice as TYPE\SERIAL (e.g. 10301\608) or leave it empty for a return without invoice');
        end if;
        l_rtype := to_number(regexp_substr(p_invoice_no, '\d+', 1, 1));
        l_rser  := to_number(regexp_substr(p_invoice_no, '\d+', 1, 2));
      end if;
    end if;
    -- header locks once lines exist (PRE-TEXT-ITEMs)
    if l_lines > 0 and (changed(l_store, old.store_code) or changed(l_cust, old.customer_code) or l_curr <> nvl(old.currency_code, 1)
                        or changed(l_rate, old.currency_rate) or changed(l_rtype, old.ret_trns_type_code)
                        or changed(l_rser, old.ret_trns_serial)) then
      return m('برجاء حذف الاصناف اولا (لا يمكن تغيير المخزن / العميل / العملة / الفاتورة الأصلية بعد إدخال الأصناف)',
               'Please Delete Inserted Items First (store / customer / currency / original invoice cannot change)');
    end if;
    if l_rser is not null and (l_new or changed(l_rser, old.ret_trns_serial) or changed(l_rtype, old.ret_trns_type_code)) then
      begin
        select * into inv from st_trns_mast where trns_type_code = l_rtype and trns_serial = l_rser;
      exception when no_data_found then
        return m('الفاتورة ' || l_rtype || '\' || l_rser || ' غير موجودة', 'Invoice ' || l_rtype || '\' || l_rser || ' does not exist');
      end;
      select count(*) into l_n from st_trns_type it
       where it.trns_type_code = inv.trns_type_code and it.effect = 2 and it.trns_type = 2 and nvl(it.join_type, 0) = nvl(t.join_type, 0)
         and (pw = 0 or (it.trns_type_code in (select trns_type_code from st_trnstype_password where flag = 1 and password_number = pw)
                         and inv.store_code in (select store_code from st_store_password where password_number = pw)));
      if l_n = 0 or nvl(inv.delete_flag, 0) = 1 or inv.trns_date > nvl(l_date, trunc(sysdate))
         or (l_cust is not null and inv.customer_code <> l_cust) then
        return m('الفاتورة ' || l_rtype || '\' || l_rser || ' ليست فاتورة مبيعات صالحة للارتجاع لهذا العميل / التاريخ',
                 'Invoice ' || l_rtype || '\' || l_rser || ' is not a sales invoice that can be returned for this customer / date');
      end if;
      l_cust := nvl(l_cust, inv.customer_code);
      l_sman := nvl(l_sman, inv.salesman_code);
    end if;
    -- store
    l_store := nvl(l_store, t.store_code);
    if l_store is null then
      return m('يجب إدخال المخزن', 'Store is required');
    end if;
    if l_new or changed(l_store, old.store_code) then
      l_msg := store_error(l_store);
      if l_msg is not null then return l_msg; end if;
    end if;
    -- date: the item is disabled in the legacy form (always the day of entry); CHECK_DATE + closing
    if (l_new and trunc(l_date) <> trunc(sysdate)) or (not l_new and l_date <> old.trns_date) then
      return m('تاريخ المرتجع هو تاريخ اليوم ولا يمكن تغييره', 'The return date is the day of entry and cannot be changed');
    end if;
    if l_new or changed(l_cust, old.customer_code) then
      l_msg := date_error(l_date, l_cust);
      if l_msg is not null then return l_msg; end if;
    end if;
    -- customer / salesman
    if l_cust is null then
      return m('يجب إدخال العميل', 'Customer is required');
    end if;
    if l_new or changed(l_cust, old.customer_code) then
      l_msg := customer_error(l_cust);
      if l_msg is not null then return l_msg; end if;
    end if;
    if nvl(t.has_salesman, 0) = 1 and l_sman is null and get_last_salesman_indate(l_cust) is null then
      return m('يجب إدخال المندوب', 'Salesman is required');
    end if;
    if l_sman is not null and l_rser is null and (l_new or changed(l_sman, old.salesman_code) or changed(l_cust, old.customer_code)) then
      l_msg := salesman_error(l_sman, l_cust);
      if l_msg is not null then return l_msg; end if;
    end if;
    -- currency
    if l_rate is not null and l_rate <= 0 then
      return m('يجب ادخال معامل التحويل', 'You must enter the Conversion Code');
    end if;
    if l_curr = 1 and nvl(l_rate, 1) <> 1 then
      return m(' معامل تحويل الريال يجب ان يكون ب 1 ', 'Rate Must Be 1');
    end if;
    -- return reason (RET_INV_CODE required, list RET_INV_CODES)
    select count(*) into l_n from ret_inv_codes where complaint_code = l_reason;
    if l_reason is null or l_n = 0 then
      return m('يجب إدخال سبب الارتجاع (من جدول أسباب المرتجعات)', 'Enter the return reason');
    end if;
    if not l_new then
      snap_trns(p_rowid, old.trns_type_code, old.trns_serial);
    end if;
    return null;
  end sr_validate;

  procedure sr_after_save (p_request in varchar2, p_rowid in varchar2) is
    mst     st_trns_mast%rowtype;
    l_lines number;
    l_srv   number;
    l_max   number;
    l_n     number;
    l_msg   varchar2(4000);
  begin
    if p_rowid is null then return; end if;
    select * into mst from st_trns_mast where rowid = chartorowid(p_rowid);
    if nvl(doc_kind(mst.trns_type_code), '-') <> 'SR' then return; end if;
    select count(*) into l_lines from st_trns_det where trns_type_code = mst.trns_type_code and trns_serial = mst.trns_serial;
    select count(*) into l_srv from st_trns_services where trns_type_code = mst.trns_type_code and trns_serial = mst.trns_serial;
    -- PRE-INSERT / line POST-DELETE: no return without items or services (the APEX header is created first)
    if p_request <> 'CREATE' and l_lines + l_srv = 0 then
      err(-20141, 'غير مسموح بحفظ الفاتورة بدون أصنــــــاف أو خدمات !!! ', 'Can''t Save Invoice Without Items Or Service');
    end if;
    select max(trns_max_items) into l_max from st_basic;
    if l_max is not null and l_lines > l_max then
      err(-20142, 'لقد تم إدخال ' || l_lines || ' صنف فى هذه الحركة، غير مسموح بالمزيد من الأصناف',
          l_lines || ' items entered in this transaction, no more items are allowed');
    end if;
    -- with invoice: returned <= sold per lot (all returns of the invoice)
    if mst.ret_trns_serial is not null then
      for r in (select d.item_confg_id, d.item_code,
                       sum(nvl(d.quantity, 0) + nvl(d.bonus, 0) + nvl(d.extra_bonus, 0)) ret_qty,
                       (select sum(nvl(o.quantity, 0) + nvl(o.bonus, 0) + nvl(o.extra_bonus, 0)) from st_trns_det o
                         where o.trns_type_code = mst.ret_trns_type_code and o.trns_serial = mst.ret_trns_serial
                           and o.item_confg_id = d.item_confg_id) org_qty
                  from st_trns_mast m, st_trns_det d
                 where m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial
                   and m.ret_trns_type_code = mst.ret_trns_type_code and m.ret_trns_serial = mst.ret_trns_serial
                   and nvl(m.delete_flag, 0) = 0 and nvl(d.delete_flag, 0) = 0
                   and d.item_confg_id in (select item_confg_id from st_trns_det
                                            where trns_type_code = mst.trns_type_code and trns_serial = mst.trns_serial)
                 group by d.item_confg_id, d.item_code) loop
        if r.ret_qty > nvl(r.org_qty, 0) then
          err(-20127, ' إجمالى الكمية المرتجعة اكبر من اجمالى الكمية المباعة - الكمية = ' || nvl(r.org_qty, 0) || ' (' || r.item_code || ')',
              'The total return quantity should be less or equal than original quantity ' || nvl(r.org_qty, 0) || ' (' || r.item_code || ')');
        end if;
      end loop;
    end if;
    -- deleted lines: later issues of the lot must not go negative (line KEY-DELREC)
    if g_snap_rowid = p_rowid and g_snap_det.count > 0 then
      for i in 1 .. g_snap_det.count loop
        select count(*) into l_n from st_trns_det
         where trns_type_code = mst.trns_type_code and trns_serial = mst.trns_serial and item_serial = g_snap_det(i).line;
        if l_n = 0 then
          l_msg := next_trns_error(g_snap_det(i).store, g_snap_det(i).grp, g_snap_det(i).item, g_snap_det(i).confg,
                                   g_snap_det(i).tdate, g_snap_det(i).dserial, g_snap_det(i).line);
          if l_msg is not null then raise_application_error(-20143, l_msg); end if;
        end if;
      end loop;
    end if;
    g_snap_rowid := null;
  end sr_after_save;

  -- ================================================================== soft delete of ST_TRNS_MAST documents
  -- committed image of a row that the current transaction has already deleted (an autonomous transaction does not
  -- see the uncommitted delete of the page DML process)
  function committed_mast (p_rowid in varchar2, o_found out boolean) return st_trns_mast%rowtype is
    pragma autonomous_transaction;
    r st_trns_mast%rowtype;
  begin
    select * into r from st_trns_mast where rowid = chartorowid(p_rowid);
    o_found := true;
    rollback;
    return r;
  exception when no_data_found then
    o_found := false;
    rollback;
    return r;
  end committed_mast;

  procedure trns_soft_delete (p_rowid in varchar2) is
    r       st_trns_mast%rowtype;
    l_n     number;
    l_kind  varchar2(4);
    l_found boolean;
    l_msg   varchar2(4000);
  begin
    if p_rowid is null then return; end if;
    select count(*) into l_n from st_trns_mast where rowid = chartorowid(p_rowid);
    if l_n > 0 then return; end if;                       -- nothing was deleted
    r := committed_mast(p_rowid, l_found);
    if not l_found then
      return;                                             -- never committed: nothing to keep
    end if;
    l_kind := doc_kind(r.trns_type_code);
    if nvl(l_kind, '-') not in ('SI', 'SR') then return; end if;
    if nvl(r.post_flag, 0) = 1 or nvl(r.cust_post_flag, 0) = 1 or nvl(r.supp_post_flag, 0) = 1 then
      if l_kind = 'SR' then
        err(-20135, 'الفاتورة تم ترحيلها للأنظمة الأخري', 'The document is posted to the other systems');
      end if;
      err(-20135, 'لا يمكن حذف مستند مرحل', 'A posted document cannot be deleted');
    end if;
    if l_kind = 'SI' and nvl(r.print_flag, 0) = 1 then
      err(-20136, 'لايمكن حذف فاتورة مطبوعة', 'You can not delete printed invoice');
    end if;
    g_bypass := true;
    insert into st_trns_mast values r;
    -- DATE_SERIAL / salesman managers are recomputed by ST_TRNS_MAST_IN on insert: put the original values back
    update st_trns_mast
       set delete_flag = 1, delete_user = usr, delete_date = sysdate,
           date_serial = r.date_serial, salesman_branch_mgr = r.salesman_branch_mgr, salesman_sales_mgr = r.salesman_sales_mgr,
           supervisor_slsman = r.supervisor_slsman, mrch_slsman = r.mrch_slsman, alt_key = r.alt_key
     where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    g_bypass := false;
    if l_kind = 'SI' then
      -- POST-UPDATE (DELETE_FLAG = 1): release the sales order converted into this invoice
      update st_sales_order set sl_trns_type_code = null, sl_trns_serial = null
       where sl_trns_type_code = r.trns_type_code and sl_trns_serial = r.trns_serial;
    else
      -- KEY-DELREC of a return: removing the stock-in must not make later issues negative
      for d in (select * from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial) loop
        l_msg := next_trns_error(d.store_code, d.group_code, d.item_code, d.item_confg_id, d.trns_date, d.date_serial, d.item_serial);
        if l_msg is not null then raise_application_error(-20143, l_msg); end if;
      end loop;
    end if;
  exception when others then
    g_bypass := false;
    raise;
  end trns_soft_delete;

  -- ================================================================== ST_SALES_ORDER
  procedure so_mast_row (
    p_inserting in boolean,
    p_type in number, p_serial in number, p_order_date in out date,
    p_store in out number, p_customer in number, p_salesman in out number,
    p_currency in out number, p_rate in out number, p_invoice_number in out varchar2,
    p_approved in out number, p_old_approved in number, p_approved_user in out number, p_approved_date in out date,
    p_approved2 in out number, p_old_approved2 in number, p_approved2_user in out number, p_approved2_date in out date,
    p_closed in out number, p_auto_disc_init in out number, p_pay_term in varchar2, p_offer_expire_date in out date) is
  begin
    if g_bypass then return; end if;
    if p_inserting then
      p_order_date := nvl(p_order_date, trunc(sysdate));
      if p_store is null then p_store := type_store(p_type); end if;
      if p_customer is not null then
        if p_currency is null then
          select nvl(max(currency_code), 1) into p_currency from customer where code = p_customer;
        end if;
        if p_salesman is null then p_salesman := get_last_salesman_indate(p_customer); end if;
      end if;
      p_currency := nvl(p_currency, 1);
      if p_rate is null then
        select nvl(max(rate), 1) into p_rate from ac_currency where currency_code = p_currency;
      end if;
      if p_invoice_number is null then                      -- PRE-INSERT (legacy: text MAX over the table)
        select to_char(nvl(max(nvl(invoice_number, 0)) + 1, 1)) into p_invoice_number from st_sales_order;
      end if;
      p_approved  := nvl(p_approved, 0);
      p_approved2 := nvl(p_approved2, 0);
      p_closed    := nvl(p_closed, 0);
      p_auto_disc_init := nvl(p_auto_disc_init, 1);
      if p_offer_expire_date is null and p_pay_term is not null then
        p_offer_expire_date := p_order_date + 10;           -- PAY_TERM WHEN-VALIDATE-ITEM
      end if;
    end if;
    -- approval buttons: approver and date
    if nvl(p_approved, 0) <> nvl(p_old_approved, 0) then
      if nvl(p_approved, 0) = 1 then p_approved_user := usr; p_approved_date := sysdate;
      else p_approved_user := null; p_approved_date := null; end if;
    end if;
    if nvl(p_approved2, 0) <> nvl(p_old_approved2, 0) then
      if nvl(p_approved2, 0) = 1 then p_approved2_user := usr; p_approved2_date := sysdate;
      else p_approved2_user := null; p_approved2_date := null; end if;
    end if;
  end so_mast_row;

  -- quantities / prices of a quotation or sales-order line (CALC_SALES_DISC_TOT, BASIC_QTY, UNIT_PRICE, discounts)
  procedure sales_line (
    p_customer in number, p_class in number, p_rate in number,
    p_group in out number, p_item in varchar2, p_new_item in boolean,
    p_unit in out number, p_confg in number,
    p_temp_qty in out number, p_qty in out number,
    p_bonus in out number, p_bonus_ratio in out number, p_extra_bonus in out number, p_extra_ratio in out number,
    p_basic_qty in out number, p_price_curr in out number, p_price in out number,
    p_d1_ratio in out number, p_d1_value in out number, p_d2_ratio in out number, p_d2_value in out number,
    p_d3_ratio in out number, p_d3_value in out number, p_auto_disc in out number,
    p_org_d1 in out number, p_org_d2 in out number, p_org_d3 in out number, p_org_bonus in out number,
    p_org_price in out number, p_org_extra in out number, p_org_class in out number) is
    l_factor number;
    l_d1 number; l_d2 number; l_d3 number; l_bon number; l_prc number; l_ext number; l_cls number;
  begin
    item_check(p_group, p_item);
    if p_unit is null then p_unit := basic_unit(p_group, p_item); end if;
    l_factor := unit_factor(p_group, p_item, p_unit);
    if p_new_item or p_org_price is null then
      calc_sales_disc(p_customer, p_group, p_item, p_unit, l_d1, l_d2, l_d3, l_bon, l_prc, l_ext, l_cls, p_class, p_confg);
      p_org_d1 := l_d1; p_org_d2 := l_d2; p_org_d3 := l_d3; p_org_bonus := l_bon;
      p_org_price := l_prc; p_org_extra := l_ext; p_org_class := l_cls;
    end if;
    -- TEMP_QUANTITY is what the user types, QUANTITY the (approved) quantity
    p_temp_qty := nvl(p_temp_qty, p_qty);
    if p_qty is null then p_qty := p_temp_qty; end if;
    if nvl(p_temp_qty, 0) = 0 and p_qty is null then p_qty := 0; end if;
    p_auto_disc := nvl(p_auto_disc, 0);
    if p_auto_disc = 1 then
      p_d1_ratio := p_org_d1; p_d2_ratio := p_org_d2; p_d3_ratio := p_org_d3;
      p_bonus_ratio := p_org_bonus; p_price_curr := p_org_price; p_extra_ratio := p_org_extra;
      p_d1_value := null; p_d2_value := null; p_d3_value := null;
      if nvl(p_qty, 0) <> 0 and nvl(p_bonus_ratio, 0) <> 0
         and round(round(p_bonus_ratio * nvl(p_temp_qty, p_qty) / 100) * 100 / p_bonus_ratio) <> 0 then
        p_qty := round(round(p_bonus_ratio * nvl(p_temp_qty, p_qty) / 100) * 100 / p_bonus_ratio);
      end if;
      p_bonus := round(nvl(p_bonus_ratio, 0) * nvl(p_qty, 0) / 100);
      p_extra_bonus := trunc(nvl(p_extra_ratio, 0) * nvl(p_qty, 0) / 100);
    else
      if p_d1_ratio is null and p_d1_value is null then p_d1_ratio := p_org_d1; end if;
      if p_d2_ratio is null and p_d2_value is null then p_d2_ratio := p_org_d2; end if;
      if p_d3_ratio is null and p_d3_value is null then p_d3_ratio := p_org_d3; end if;
      if p_price_curr is null then p_price_curr := p_org_price; end if;
      if p_bonus is null and p_bonus_ratio is not null then p_bonus := round(p_bonus_ratio * nvl(p_qty, 0) / 100);
      elsif p_bonus is not null and nvl(p_qty, 0) <> 0 then p_bonus_ratio := p_bonus / p_qty * 100; end if;
      if p_extra_bonus is null and p_extra_ratio is not null then p_extra_bonus := round(p_extra_ratio * nvl(p_qty, 0) / 100);
      elsif p_extra_bonus is not null and nvl(p_qty, 0) <> 0 then p_extra_ratio := p_extra_bonus / p_qty * 100; end if;
    end if;
    p_bonus := nvl(p_bonus, 0); p_extra_bonus := nvl(p_extra_bonus, 0);
    if nvl(p_bonus_ratio, 0) < 0 or nvl(p_extra_ratio, 0) < 0 or nvl(p_qty, 0) < 0 or p_bonus < 0 or p_extra_bonus < 0
       or nvl(p_price_curr, 0) < 0 then
      err(-20118, 'أدخل رقم بقيمة تبدأ من الصفر', 'Enter Value From Zero');
    end if;
    if nvl(p_qty, 0) + p_bonus + p_extra_bonus <= 0 then
      err(-20118, 'الكمية و البونص يجب أن يكون مجموعهما أكبر من صفر', 'Sum of Qty And Bonus Must Be More Than Zero');
    end if;
    p_basic_qty := (nvl(p_bonus, 0) + nvl(p_extra_bonus, 0) + nvl(p_qty, 0)) * l_factor;
    p_price := nvl(p_price_curr, 0) * nvl(p_rate, 1);
    line_discounts(nvl(p_price_curr, 0), p_d1_ratio, p_d1_value, p_d2_ratio, p_d2_value, p_d3_ratio, p_d3_value, p_qty, p_item);
  end sales_line;

  function so_invoiced (p_type in number, p_serial in number) return boolean is
    l_n number;
  begin
    select count(*) into l_n from st_trns_mast m, st_trns_type t
     where m.order_trns_type_code = p_type and m.order_trns_serial = p_serial and nvl(m.delete_flag, 0) = 0
       and t.trns_type_code = m.trns_type_code and t.effect = 2;
    return l_n > 0;
  end so_invoiced;

  procedure so_det_row (
    p_inserting in boolean,
    p_type in number, p_serial in number, p_line in number,
    p_group in out number, p_item in varchar2, p_old_item in varchar2,
    p_unit in out number, p_old_unit in number, p_confg in out number, p_old_confg in number,
    p_temp_qty in out number, p_qty in out number,
    p_bonus in out number, p_bonus_ratio in out number, p_extra_bonus in out number, p_extra_ratio in out number,
    p_basic_qty in out number, p_price_curr in out number, p_price in out number,
    p_d1_ratio in out number, p_d1_value in out number, p_d2_ratio in out number, p_d2_value in out number,
    p_d3_ratio in out number, p_d3_value in out number, p_auto_disc in out number,
    p_org_d1 in out number, p_org_d2 in out number, p_org_d3 in out number, p_org_bonus in out number,
    p_org_price in out number, p_org_extra in out number, p_org_class in out number,
    p_tax_code in out number, p_tax_value in out number, p_last_expire in out date) is
    so      st_sales_order%rowtype;
    l_new_item boolean;
    l_factor number;
    l_n     number;
  begin
    if g_bypass then return; end if;
    select * into so from st_sales_order where trns_type_code = p_type and trns_serial = p_serial;
    -- ENABLE_DISABLE_BUTTONS: an invoiced order has read-only lines
    if so_invoiced(p_type, p_serial) then
      err(-20151, 'امر البيع تم تحويلها إلي فاتورة مبيعات', 'The sales order was converted to a sales invoice');
    end if;
    if p_inserting then
      p_auto_disc := nvl(p_auto_disc, nvl(so.auto_disc_init, 0));              -- WHEN-CREATE-RECORD
    end if;
    l_new_item := p_inserting or changed_s(p_item, p_old_item) or changed(p_unit, p_old_unit) or changed(p_confg, p_old_confg);
    item_check(p_group, p_item);
    if p_unit is null then
      p_unit := basic_unit(p_group, p_item);
    end if;
    l_factor := unit_factor(p_group, p_item, p_unit);
    -- lot: earliest expiry with stock when not chosen (DEVIDE_CONFGS); required, with stock at the order date
    if p_confg is null then
      select min(c.item_confg_id) keep (dense_rank first order by c.expire_date, c.item_confg_id) into p_confg
        from st_item_confg c
       where c.item_code = p_item and c.group_code = p_group
         and get_balance_confg(so.store_code, c.group_code, p_item, c.item_confg_id, so.order_date, null, p_line) / l_factor > 0;
    end if;
    if p_confg is null then
      err(-20152, 'يجب إدخال الشحنة (لا يوجد رصيد للصنف ' || p_item || ')', 'Enter the lot (no stock for item ' || p_item || ')');
    end if;
    if l_new_item then
      select count(*) into l_n from st_item_confg where item_confg_id = p_confg and item_code = p_item;
      if l_n = 0 then
        err(-20115, 'الشحنة ' || p_confg || ' لا تخص الصنف ' || p_item, 'Lot ' || p_confg || ' does not belong to item ' || p_item);
      end if;
      if get_balance_confg(so.store_code, p_group, p_item, p_confg, so.order_date, null, p_line) <= 0 then
        err(-20153, 'لا يوجد رصيد للشحنة ' || p_confg || ' في المخزن', 'Lot ' || p_confg || ' has no stock in the store');
      end if;
      p_last_expire := get_last_ex_date(so.store_code, p_group, p_item);
    end if;
    sales_line(so.customer_code, so.class_code, so.currency_rate, p_group, p_item, l_new_item, p_unit, p_confg,
               p_temp_qty, p_qty, p_bonus, p_bonus_ratio, p_extra_bonus, p_extra_ratio, p_basic_qty, p_price_curr, p_price,
               p_d1_ratio, p_d1_value, p_d2_ratio, p_d2_value, p_d3_ratio, p_d3_value, p_auto_disc,
               p_org_d1, p_org_d2, p_org_d3, p_org_bonus, p_org_price, p_org_extra, p_org_class);
    -- GET_TAX_DET: VAT on ROUND(BASIC_QTY x net price)
    line_tax(p_group, p_item, so.customer_code, null, so.order_date,
             round(p_basic_qty * (nvl(p_price_curr, 0) - (nvl(p_d1_value, 0) + nvl(p_d2_value, 0) + nvl(p_d3_value, 0)) * nvl(so.currency_rate, 1))),
             p_tax_code, p_tax_value);
  end so_det_row;

  -- number of lines outside the price policy (discount / bonus above the policy values, quantity above SALES_LIMIT)
  function policy_breaks (p_table in varchar2, p_type in number, p_serial in number) return number is
    l number;
  begin
    if p_table = 'SO' then
      select count(*) into l from (
        select p.item_group_code, p.item_code from st_sales_order_det p
         where p.trns_type_code = p_type and p.trns_serial = p_serial
           and (p.disc1_ratio > p.org_disc1_ratio or p.disc2_ratio > p.org_disc2_ratio or p.disc3_ratio > p.org_disc3_ratio)
        union
        select p.item_group_code, p.item_code from st_sales_order_det p
         where p.trns_type_code = p_type and p.trns_serial = p_serial
         group by p.item_group_code, p.item_code
        having sum(p.bonus) / nullif(sum(p.quantity), 0) * 100 > max(p.org_bonus_ratio)
            or sum(p.extra_bonus) / nullif(sum(p.quantity), 0) * 100 > max(p.org_extra_bonus_ratio)
        union
        select p.item_group_code, p.item_code from st_sales_order_det p, st_item_unit u
         where p.trns_type_code = p_type and p.trns_serial = p_serial
           and p.item_group_code = u.group_code and p.item_code = u.item_code and p.unit_code = u.unit_code
           and nvl(u.sales_limit, 0) <> 0 and nvl(p.basic_qty, 0) > nvl(u.sales_limit, 0));
    else
      select count(*) into l from (
        select p.group_code, p.item_code from st_proposal_det p
         where p.trns_type_code = p_type and p.trns_serial = p_serial
           and (p.disc1_ratio > p.org_disc1_ratio or p.disc2_ratio > p.org_disc2_ratio or p.disc3_ratio > p.org_disc3_ratio));
    end if;
    return l;
  end policy_breaks;

  function so_validate (
    p_request in varchar2, p_rowid in varchar2,
    p_type in varchar2, p_date in varchar2, p_store in varchar2, p_customer in varchar2, p_salesman in varchar2,
    p_currency in varchar2, p_rate in varchar2, p_class in varchar2, p_rfq in varchar2, p_doc_no in varchar2,
    p_approved in varchar2, p_approved2 in varchar2, p_closed in varchar2,
    p_td1r in varchar2, p_td1v in varchar2, p_td2r in varchar2, p_td2v in varchar2, p_td3r in varchar2, p_td3v in varchar2)
    return varchar2 is
    l_type  number := to_n(p_type);
    l_date  date   := nvl(to_d(p_date), trunc(sysdate));
    l_store number := to_n(p_store);
    l_cust  number := to_n(p_customer);
    l_sman  number := to_n(p_salesman);
    l_curr  number := nvl(to_n(p_currency), 1);
    l_rate  number := to_n(p_rate);
    l_class number := to_n(p_class);
    l_doc   number := to_n(p_doc_no);
    l_ap1   number := nvl(to_n(p_approved), 0);
    l_ap2   number := nvl(to_n(p_approved2), 0);
    l_cls   number := nvl(to_n(p_closed), 0);
    l_new   boolean := p_rowid is null;
    old     st_sales_order%rowtype;
    t       st_trns_type%rowtype;
    l_lines number := 0;
    l_msg   varchar2(4000);
    l_v     varchar2(200);
    l_n     number;
  begin
    g_snap_rowid := null;
    if not l_new then
      begin
        select * into old from st_sales_order where rowid = chartorowid(p_rowid);
      exception when no_data_found then
        return m('المستند غير موجود (ربما حذف من مستخدم آخر)', 'The document no longer exists');
      end;
      select count(*) into l_lines from st_sales_order_det where trns_type_code = old.trns_type_code and trns_serial = old.trns_serial;
      if l_type <> old.trns_type_code then
        return m('لا يمكن تغيير نوع الحركة بعد الحفظ', 'The transaction type cannot be changed after saving');
      end if;
      if old.delete_date is not null then
        return m('أمر البيع ملغي', 'The sales order is cancelled');
      end if;
    end if;
    l_msg := type_error(l_type, 'SO');
    if l_msg is not null then return l_msg; end if;
    select * into t from st_trns_type where trns_type_code = l_type;
    if l_cust is null then
      return m('يجب إدخال رقم العميل ', 'Customer is required');
    end if;
    if l_new or changed(l_cust, old.customer_code) then
      l_msg := customer_error(l_cust);
      if l_msg is not null then return l_msg; end if;
    end if;
    l_store := nvl(l_store, type_store(l_type));
    if l_store is null then return m('يجب إدخال المخزن', 'Store is required'); end if;
    if l_new or changed(l_store, old.store_code) then
      l_msg := store_error(l_store);
      if l_msg is not null then return l_msg; end if;
    end if;
    l_sman := nvl(l_sman, get_last_salesman_indate(l_cust));
    if l_sman is null and nvl(t.has_salesman, 0) = 1 then
      return m('يجب إدخال المندوب', 'Salesman is required');
    end if;
    if l_sman is not null and (l_new or changed(to_n(p_salesman), old.salesman_code) or changed(l_cust, old.customer_code)) then
      l_msg := salesman_error(l_sman, l_cust);
      if l_msg is not null then return l_msg; end if;
    end if;
    if l_curr = 1 and nvl(l_rate, 1) <> 1 then
      return m('معامل التحويل يجب أن يكون 1 !!!', 'Currency Rate Must Be 1 !!!');
    end if;
    -- ORDER_DATE: disabled item = day of entry; VALIDATE_DATE (future, ST_BASIC.MIN_DATE, salesman transfer)
    if (l_new and to_d(p_date) is not null and trunc(to_d(p_date)) <> trunc(sysdate)) or (not l_new and changed_d(to_d(p_date), old.order_date)) then
      return m('تاريخ أمر البيع هو تاريخ اليوم ولا يمكن تغييره', 'The sales order date is the day of entry and cannot be changed');
    end if;
    if l_new or changed(l_cust, old.customer_code) then
      l_msg := date_error(l_date, l_cust, false);
      if l_msg is not null then return l_msg; end if;
    end if;
    -- class: only when allowed, and not once lines exist (CLASS_CODE WHEN-VALIDATE-ITEM)
    if (l_new and l_class is not null) or (not l_new and changed(l_class, old.class_code)) then
      if pw <> 0 and user_flag('ENABLE_CHANGE_CLASS') = 0 then
        return m('غير مسموح لك بتغيير الفئة', 'You are not allowed to change the class');
      end if;
      if l_lines > 0 then
        return m('برجاء حذف الاصناف اولا', 'Please Delete Inserted Items First');
      end if;
    end if;
    -- PRE-INSERT duplicate checks (RFQ, customer PO / DOC_NO)
    if l_new then
      if p_rfq is not null then
        select max(trns_type_code || '-' || trns_serial) into l_v from st_sales_order where upper(rfq) = upper(p_rfq);
        if l_v is not null then return 'RFQ Repeated -' || l_v; end if;
      end if;
      if l_doc is not null then
        select max(trns_type_code || '-' || trns_serial) into l_v from st_sales_order where doc_no = l_doc;
        if l_v is not null then return 'Cust Po. Repeated -' || l_v; end if;
        select count(*) into l_n from st_trns_mast mm
         where mm.doc_no = l_doc and nvl(mm.delete_flag, 0) = 0
           and get_customer_ctgry(mm.customer_code, mm.salesman_code) = get_customer_ctgry(l_cust, l_sman);
        if l_n > 0 then return m('رقم المستند مكرر لنفس رقم القسم', 'Doc No Repeated for Same Ctgry'); end if;
      end if;
    end if;
    -- approval buttons (AUTH_SALES_ORDER / UN_AUTH ...), close / reopen
    if not l_new then
      if l_ap1 <> nvl(old.approved, 0) or l_ap2 <> nvl(old.approved2, 0) then
        if nvl(old.closed, 0) = 1 then
          return m('امر البيع مقفل بالفعل', 'The sales order is closed');
        end if;
        if l_ap1 = 1 and nvl(old.approved, 0) = 0 and pw <> 0 and user_flag('ALLOW_APPROVE') <> 1
           and policy_breaks('SO', old.trns_type_code, old.trns_serial) > 0 then
          return m('ليس لديك صلاحية للاعتماد', 'You dont have Permission to Auth.');
        end if;
        if l_ap2 = 1 and nvl(old.approved2, 0) = 0 then
          if l_ap1 = 0 then
            return m('لايمكن الاعتماد لحركة غير معتمدة من الادارة 1', 'Level 1 approval is required first');
          end if;
          if pw <> 0 and user_flag('ALLOW_APPROVE2') <> 1 and policy_breaks('SO', old.trns_type_code, old.trns_serial) > 0 then
            return m('ليس لديك صلاحية للاعتماد', 'You dont have Permission to Auth.');
          end if;
        end if;
        if (l_ap1 = 0 and nvl(old.approved, 0) = 1) or (l_ap2 = 0 and nvl(old.approved2, 0) = 1) then
          if so_invoiced(old.trns_type_code, old.trns_serial) then
            return m('تم عمل فاتورة مبيعات', 'A sales invoice exists');
          end if;
          select count(*) into l_n from pr_order_det where sl_trns_type_code = old.trns_type_code and sl_trns_serial = old.trns_serial;
          if l_n > 0 then
            return m('تم عمل امر شراء', 'A purchase order exists');
          end if;
          if l_ap1 = 0 and nvl(old.approved, 0) = 1 and l_ap2 = 1 then
            return m('لايمكن الغاء الاعتماد عن حركة معتمدة من الادارة 2', 'Cannot remove approval 1 while approval 2 exists');
          end if;
        end if;
      end if;
      if l_cls = 1 and nvl(old.closed, 0) = 1 and l_ap1 <> nvl(old.approved, 0) then
        return m('امر البيع مقفل بالفعل', 'The sales order is closed');
      end if;
      -- CALC_TOT_DISC: header discounts cannot change after approval
      if nvl(old.approved, 0) = 1 and (changed(to_n(p_td1r), old.tot_disc1_ratio) or changed(to_n(p_td1v), old.tot_disc1_value)
          or changed(to_n(p_td2r), old.tot_disc2_ratio) or changed(to_n(p_td2v), old.tot_disc2_value)
          or changed(to_n(p_td3r), old.tot_disc3_ratio) or changed(to_n(p_td3v), old.tot_disc3_value)) then
        return m('لا يمكن تعديل هذه الحركة', 'Can''t Update This record');
      end if;
      g_snap_rowid := p_rowid;
      g_snap_lines := l_lines;
    end if;
    return null;
  end so_validate;

  procedure so_after_save (p_request in varchar2, p_rowid in varchar2) is
    so      st_sales_order%rowtype;
    l_lines number;
    l_net   number;
    l_v1 number; l_v2 number; l_v3 number; l_r1 number; l_r2 number; l_r3 number;
  begin
    if p_rowid is null then return; end if;
    select * into so from st_sales_order where rowid = chartorowid(p_rowid);
    select count(*), nvl(sum((nvl(unit_price, 0) - (nvl(disc1_value, 0) + nvl(disc2_value, 0) + nvl(disc3_value, 0))) * nvl(quantity, 0)), 0)
      into l_lines, l_net
      from st_sales_order_det where trns_type_code = so.trns_type_code and trns_serial = so.trns_serial;
    -- detail POST-DELETE: the last line cannot be deleted
    if g_snap_rowid = p_rowid and g_snap_lines > 0 and l_lines = 0 then
      err(-20154, 'غير مسموح بحفظ  امر البيع بدون أصنــــــاف !!! ', 'A sales order cannot be saved without items');
    end if;
    -- invoiced orders: lines read-only (line deletes are only visible here)
    if g_snap_rowid = p_rowid and l_lines <> g_snap_lines and so_invoiced(so.trns_type_code, so.trns_serial) then
      err(-20151, 'امر البيع تم تحويلها إلي فاتورة مبيعات', 'The sales order was converted to a sales invoice');
    end if;
    l_r1 := so.tot_disc1_ratio; l_v1 := so.tot_disc1_value; l_r2 := so.tot_disc2_ratio; l_v2 := so.tot_disc2_value;
    l_r3 := so.tot_disc3_ratio; l_v3 := so.tot_disc3_value;
    tot_discounts(l_net, l_r1, l_v1, l_r2, l_v2, l_r3, l_v3);
    if changed(l_r1, so.tot_disc1_ratio) or changed(l_v1, so.tot_disc1_value) or changed(l_r2, so.tot_disc2_ratio)
       or changed(l_v2, so.tot_disc2_value) or changed(l_r3, so.tot_disc3_ratio) or changed(l_v3, so.tot_disc3_value) then
      update st_sales_order set tot_disc1_ratio = l_r1, tot_disc1_value = l_v1, tot_disc2_ratio = l_r2, tot_disc2_value = l_v2,
             tot_disc3_ratio = l_r3, tot_disc3_value = l_v3
       where rowid = chartorowid(p_rowid);
    end if;
    g_snap_rowid := null;
  end so_after_save;

  -- ================================================================== ST_PRICE_PROPOSAL
  function qt_converted (p_type in number, p_serial in number) return boolean is
    l_n number;
  begin
    select (select count(*) from st_sales_order where demo_trns_type_code = p_type and demo_trns_serial = p_serial and delete_date is null)
         + (select count(*) from st_trns_mast where demo_trns_type_code = p_type and demo_trns_serial = p_serial and nvl(delete_flag, 0) <> 1)
         + (select count(*) from st_proposal_mast where proposal_trns_type_code = p_type and proposal_trns_serial = p_serial and nvl(delete_flag, 0) = 0)
      into l_n from dual;
    return l_n > 0;
  end qt_converted;

  procedure qt_mast_row (
    p_inserting in boolean,
    p_type in number, p_serial in number, p_date in out date, p_date_serial in out number,
    p_store in out number, p_customer in number, p_supplier in number, p_posting_supplier in out number,
    p_salesman in out number, p_currency in out number, p_rate in out number, p_invoice_no in out varchar2,
    p_offer_expiry in out varchar2, p_proposal_expire in out date, p_delete_flag in out number,
    p_salesman_done in out number,
    p_approve in out number, p_old_approve in number, p_approve_user in out number, p_approve_date in out date,
    p_approve2 in out number, p_old_approve2 in number, p_approve2_user in out number, p_approve2_date in out date,
    p_accept in out number, p_old_accept in number, p_approve3_user in out number, p_approve3_date in out date,
    p_auto_disc_init in out number) is
  begin
    if g_bypass then return; end if;
    if p_inserting then
      p_date := trunc(nvl(p_date, sysdate));
      if p_date_serial is null then                                  -- PRE-INSERT: per date
        select nvl(max(nvl(date_serial, 0)) + 1, 1) into p_date_serial from st_proposal_mast where trns_date = p_date;
      end if;
      if p_store is null then p_store := type_store(p_type); end if;
      if p_customer is not null then
        if p_currency is null then
          select nvl(max(currency_code), 1) into p_currency from customer where code = p_customer;
        end if;
        if p_salesman is null then p_salesman := get_last_salesman_indate(p_customer); end if;
      end if;
      p_currency := nvl(p_currency, 1);
      if p_rate is null then
        select nvl(max(rate), 1) into p_rate from ac_currency where currency_code = p_currency;
      end if;
      if p_invoice_no is null then                                    -- TRNS_TYPE WHEN-VALIDATE-ITEM (legacy text MAX)
        select to_char(nvl(max(nvl(invoice_no, 0)) + 1, 1)) into p_invoice_no from st_proposal_mast;
      end if;
      p_offer_expiry := nvl(p_offer_expiry, '45');
      p_delete_flag := nvl(p_delete_flag, 0);
      p_salesman_done := nvl(p_salesman_done, 0);
      p_approve := nvl(p_approve, 0); p_approve2 := nvl(p_approve2, 0); p_accept := nvl(p_accept, 0);
      p_auto_disc_init := nvl(p_auto_disc_init, 0);
    end if;
    p_posting_supplier := nvl(p_supplier, p_posting_supplier);          -- SUPPLIER_CODE WHEN-VALIDATE-ITEM
    if p_proposal_expire is null then                                   -- PRE-INSERT / PRE-UPDATE
      p_proposal_expire := p_date + nvl(to_n(p_offer_expiry), 0);
    end if;
    if nvl(p_approve, 0) <> nvl(p_old_approve, 0) then
      if nvl(p_approve, 0) = 1 then p_approve_user := usr; p_approve_date := sysdate; else p_approve_user := null; p_approve_date := null; end if;
    end if;
    if nvl(p_approve2, 0) <> nvl(p_old_approve2, 0) then
      if nvl(p_approve2, 0) = 1 then p_approve2_user := usr; p_approve2_date := sysdate; else p_approve2_user := null; p_approve2_date := null; end if;
    end if;
    if nvl(p_accept, 0) <> nvl(p_old_accept, 0) then
      if nvl(p_accept, 0) = 1 then p_approve3_user := usr; p_approve3_date := sysdate; else p_approve3_user := null; p_approve3_date := null; end if;
    end if;
  end qt_mast_row;

  function qt_can_edit (qt in st_proposal_mast%rowtype) return varchar2 is
  begin
    if qt_converted(qt.trns_type_code, qt.trns_serial) then
      return m('تم تحويل عرض السعر الي امر بيع', 'This Price Proposal has been transfared to Sales Order');
    end if;
    if nvl(qt.salesman_done, 0) = 1 and pw <> 0
       and user_flag('ALLOW_APPROVE') <> 1 and user_flag('ALLOW_APPROVE2') <> 1 and user_flag('ALLOW_APPROVE3') <> 1 then
      return m('عرض السعر معتمد من المندوب ولا يمكن تعديله', 'The quotation is confirmed by the salesman and cannot be changed');
    end if;
    return null;
  end qt_can_edit;

  procedure qt_det_row (
    p_inserting in boolean,
    p_type in number, p_serial in number,
    p_date in out date, p_date_serial in out number, p_store in out number, p_delete_flag in out number,
    p_group in out number, p_item in varchar2, p_old_item in varchar2,
    p_unit in out number, p_old_unit in number, p_confg in number, p_old_confg in number,
    p_temp_qty in out number, p_qty in out number,
    p_bonus in out number, p_bonus_ratio in out number, p_extra_bonus in out number, p_extra_ratio in out number,
    p_basic_qty in out number, p_price_curr in out number, p_old_price_curr in number, p_price in out number,
    p_d1_ratio in out number, p_d1_value in out number, p_d2_ratio in out number, p_d2_value in out number,
    p_d3_ratio in out number, p_d3_value in out number, p_auto_disc in out number,
    p_org_d1 in out number, p_org_d2 in out number, p_org_d3 in out number, p_org_bonus in out number,
    p_org_price in out number, p_org_extra in out number, p_org_class in out number,
    p_tax_code in out number, p_tax_value in out number,
    p_choice in out number, p_unavailable in out number, p_transfer_qty in number,
    p_cost_flag in out number, p_unit_cost in out number, p_item_name in out varchar2, p_last_expire in out date) is
    qt       st_proposal_mast%rowtype;
    l_msg    varchar2(4000);
    l_new_item boolean;
    l_n      number;
    l_default number;
    l_exp    date;
    l_chg    number := user_flag('CHANGE_SALES_PRICE');
    l_has    number;
  begin
    if g_bypass then return; end if;
    select * into qt from st_proposal_mast where trns_type_code = p_type and trns_serial = p_serial;
    l_msg := qt_can_edit(qt);
    if l_msg is not null then raise_application_error(-20161, l_msg); end if;
    if nvl(qt.cust_accept_flag, 0) = 1 or (nvl(qt.approve, 0) = 1 and pw <> 0 and user_flag('ALLOW_APPROVE') <> 1) then
      err(-20162, 'الحركة الحالية معتمدة و لا يمكن تعديل الأصناف', 'The quotation is approved: its lines cannot be changed');
    end if;
    -- PRE-INSERT: copies of the header
    p_store := qt.store_code; p_date := qt.trns_date; p_date_serial := qt.date_serial; p_delete_flag := nvl(qt.delete_flag, 0);
    if p_inserting then
      p_auto_disc := nvl(p_auto_disc, nvl(qt.auto_disc_init, 0));
      p_cost_flag := 1; p_unit_cost := null;
      p_choice := nvl(p_choice, 0); p_unavailable := nvl(p_unavailable, 0);
    end if;
    l_new_item := p_inserting or changed_s(p_item, p_old_item) or changed(p_unit, p_old_unit) or changed(p_confg, p_old_confg);
    if p_group is null then select min(item_group_code) into p_group from st_item where item_code = p_item; end if;
    if p_unit is null then p_unit := basic_unit(p_group, p_item); end if;
    -- lot (ITEM_CONFG_LOV): of the item, not expired
    if p_confg is not null and l_new_item then
      select count(*), max(expire_date) into l_n, l_exp from st_item_confg where item_confg_id = p_confg and item_code = p_item;
      if l_n = 0 then
        err(-20115, 'الشحنة ' || p_confg || ' لا تخص الصنف ' || p_item, 'Lot ' || p_confg || ' does not belong to item ' || p_item);
      end if;
      if l_exp is not null and l_exp <= sysdate then
        err(-20163, 'الشحنة ' || p_confg || ' منتهية الصلاحية', 'Lot ' || p_confg || ' is expired');
      end if;
    end if;
    -- default price / discount of the item lists: batch price unless the user may change prices, else retail price
    if l_new_item then
      select max(case when p_confg is not null and c.item_confg_id is not null and l_chg <> 1 then c.unit_price
                      else iu.retail_sale_price end)
        into l_default
        from st_item_unit iu, st_item_confg c
       where iu.group_code = p_group and iu.item_code = p_item and iu.unit_code = p_unit and c.item_confg_id(+) = p_confg;
      if p_price_curr is null or (nvl(p_auto_disc, 0) = 0 and p_price_curr = 0) then
        p_price_curr := l_default;
      end if;
      if p_d1_ratio is null and p_d1_value is null then
        select max(case when p_confg is not null then c.disc_ratio else i.moh_disc end) into p_d1_ratio
          from st_item i, st_item_confg c
         where i.item_group_code = p_group and i.item_code = p_item and c.item_confg_id(+) = p_confg;
      end if;
    end if;
    sales_line(qt.customer_code, qt.class_code, qt.currency_rate, p_group, p_item, l_new_item, p_unit, p_confg,
               p_temp_qty, p_qty, p_bonus, p_bonus_ratio, p_extra_bonus, p_extra_ratio, p_basic_qty, p_price_curr, p_price,
               p_d1_ratio, p_d1_value, p_d2_ratio, p_d2_value, p_d3_ratio, p_d3_value, p_auto_disc,
               p_org_d1, p_org_d2, p_org_d3, p_org_bonus, p_org_price, p_org_extra, p_org_class);
    if nvl(p_price_curr, 0) <= 0 then
      err(-20164, 'سعر الصنف يجب أن يكون أكبر من صفر', 'Unit Price Must Be Greater Than Zero');
    end if;
    -- D8/D9: ratios between 0 and 100
    if nvl(p_d1_ratio, 0) >= 100 or nvl(p_d2_ratio, 0) >= 100 then
      err(-20119, 'أدخل رقم بقيمة تبدأ من الصفر و أقل من المئة', 'Enter Value From Zero and Less Than 100');
    end if;
    -- D4/D5: manual price change only with USERS.CHANGE_SALES_PRICE (and ST_TRNS_TYPE.HAS_SALES_PRICE), not below retail
    if (p_inserting and l_default is not null and p_price_curr <> l_default) or (not p_inserting and changed(p_price_curr, p_old_price_curr)) then
      select nvl(max(has_sales_price), 0) into l_has from st_trns_type where trns_type_code = p_type;
      if l_chg <> 1 or l_has <> 1 then
        err(-20165, 'غير مسموح لك بتغيير سعر الصنف', 'You are not allowed to change the item price');
      end if;
      select nvl(max(retail_sale_price), 0) into l_default from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit;
      if p_price_curr < l_default then
        err(-20166, 'سعر الصنف يجب أن يكون أكبر من ' || l_default, 'Unit Price Must Be Greater Than ' || l_default);
      end if;
    end if;
    -- CHOICE_FLAG / UNAVAILABLE_FLAG
    if nvl(p_choice, 0) = 1 and nvl(p_unavailable, 0) = 1 then
      err(-20167, 'لايمكن تفعيل أختيار في حالة غير متاح', 'You Cant Use Choice Because of Using Unavailable');
    end if;
    if nvl(p_choice, 0) = 1 and get_balance(qt.store_code, p_group, p_item, sysdate, null, null)
                                < nvl(p_qty, 0) + nvl(p_bonus, 0) + nvl(p_extra_bonus, 0) then
      p_choice := 0;                     -- legacy: 'لايمكن تفعيل أختيار في حالة الرصيد غير متوفر بالمخزن' (warning, flag reset)
    end if;
    if p_transfer_qty is not null and (p_transfer_qty > p_basic_qty or p_transfer_qty < 0) then
      err(-20168, 'كمية التحويل لا يجب ان تكون اكبر من مجموع الكميات', 'Transfer Qty Sholud be Less Than Basic Qty');
    end if;
    select max(name_e) into p_item_name from st_item where item_group_code = p_group and item_code = p_item;
    if l_new_item then p_last_expire := get_last_ex_date(qt.store_code, p_group, p_item); end if;
    -- VAT on BASIC_QTY x net price (TAX_LIB GET_TAX_VALUE on NET_LINE_TOTAL_BASIC)
    line_tax(p_group, p_item, qt.customer_code, null, qt.trns_date,
             (nvl(p_price, 0) - (nvl(p_d1_value, 0) + nvl(p_d2_value, 0) + nvl(p_d3_value, 0))) * p_basic_qty, p_tax_code, p_tax_value);
  end qt_det_row;

  function qt_net_value (qt in st_proposal_mast%rowtype) return number is
    l_tot number; l_tax number;
  begin
    select nvl(sum((nvl(unit_price, 0) - (nvl(disc1_value, 0) + nvl(disc2_value, 0) + nvl(disc3_value, 0))) * nvl(quantity, 0)), 0),
           nvl(sum(tax_value1), 0)
      into l_tot, l_tax from st_proposal_det where trns_type_code = qt.trns_type_code and trns_serial = qt.trns_serial;
    return (l_tot - nvl(qt.disc_val, 0) - nvl(qt.tot_disc1_value, 0) - nvl(qt.tot_disc2_value, 0) - nvl(qt.tot_disc3_value, 0)
            + nvl(qt.trnsport_val, 0) + l_tax + nvl(qt.tax_value1, 0)) / nvl(qt.currency_rate, 1);
  end qt_net_value;

  function qt_credit_error (qt in st_proposal_mast%rowtype) return varchar2 is
    l_limit number; l_bal number;
  begin
    if qt.customer_code is null then return null; end if;
    select nvl(max(credit_limit), 0) into l_limit from customer where code = qt.customer_code;
    l_bal := get_customer_bal_all(qt.customer_code);
    if l_limit < l_bal or (nvl(qt.approve, 0) = 0 and l_limit < l_bal + qt_net_value(qt)) then
      return m('تعديت حد الائتمان', 'Over Credit Limit');
    end if;
    return null;
  end qt_credit_error;

  function qt_validate (
    p_request in varchar2, p_rowid in varchar2,
    p_type in varchar2, p_date in varchar2, p_store in varchar2, p_customer in varchar2, p_supplier in varchar2,
    p_salesman in varchar2, p_currency in varchar2, p_rate in varchar2, p_class in varchar2, p_rfq in varchar2,
    p_salesman_done in varchar2, p_approve in varchar2, p_approve2 in varchar2, p_accept in varchar2,
    p_desc_a in varchar2, p_desc_e in varchar2, p_pay_term in varchar2, p_offer_expiry in varchar2,
    p_other_terms in varchar2, p_proposal_expire in varchar2) return varchar2 is
    l_type  number := to_n(p_type);
    l_date  date   := nvl(to_d(p_date), trunc(sysdate));
    l_store number := to_n(p_store);
    l_cust  number := to_n(p_customer);
    l_supp  number := to_n(p_supplier);
    l_sman  number := to_n(p_salesman);
    l_curr  number := nvl(to_n(p_currency), 1);
    l_rate  number := to_n(p_rate);
    l_class number := to_n(p_class);
    l_done  number := nvl(to_n(p_salesman_done), 0);
    l_ap1   number := nvl(to_n(p_approve), 0);
    l_ap2   number := nvl(to_n(p_approve2), 0);
    l_acc   number := nvl(to_n(p_accept), 0);
    l_new   boolean := p_rowid is null;
    old     st_proposal_mast%rowtype;
    t       st_trns_type%rowtype;
    l_lines number := 0;
    l_msg   varchar2(4000);
    l_v     varchar2(200);
    l_n     number;
    l_flags_changed boolean := false;
  begin
    g_snap_rowid := null;
    if not l_new then
      begin
        select * into old from st_proposal_mast where rowid = chartorowid(p_rowid);
      exception when no_data_found then
        return m('المستند غير موجود (ربما حذف من مستخدم آخر)', 'The document no longer exists');
      end;
      if nvl(old.delete_flag, 0) = 1 then return m('عرض السعر ملغي', 'The quotation is deleted'); end if;
      select count(*) into l_lines from st_proposal_det where trns_type_code = old.trns_type_code and trns_serial = old.trns_serial;
      if l_type <> old.trns_type_code then
        return m('لا يمكن تغيير نوع الحركة بعد الحفظ', 'The transaction type cannot be changed after saving');
      end if;
      l_flags_changed := l_done <> nvl(old.salesman_done, 0) or l_ap1 <> nvl(old.approve, 0)
                         or l_ap2 <> nvl(old.approve2, 0) or l_acc <> nvl(old.cust_accept_flag, 0);
      -- CLOSE_UPDATE: converted / confirmed documents are read only
      l_msg := qt_can_edit(old);
      if l_msg is not null then return l_msg; end if;
      if nvl(old.cust_accept_flag, 0) = 1 and (changed_s(p_desc_a, old.desc_a) or changed_s(p_desc_e, old.desc_e)
          or changed_s(p_pay_term, old.pay_term) or changed_s(p_offer_expiry, old.offer_expiry) or changed_s(p_other_terms, old.other_terms)
          or changed_d(to_d(p_proposal_expire), old.proposal_expire)) then
        return m('تم اعتماد المبيعات: لا يمكن تعديل البيان والشروط والتواريخ', 'Sales approval given: description, terms and dates cannot change');
      end if;
    end if;
    l_msg := type_error(l_type, 'QT');
    if l_msg is not null then return l_msg; end if;
    select * into t from st_trns_type where trns_type_code = l_type;
    if nvl(t.join_type, 0) not in (3, 4) then
      return m('نوع الحركة ' || l_type || ' لا يخص هذه الشاشة', 'Transaction type ' || l_type || ' does not belong to this screen');
    end if;
    -- customer or supplier (PRE-INSERT), customer of the type's category (CUSTOMER_RG)
    if l_cust is null and l_supp is null then
      return m('يجب إدخال رقم العميل أو رقم المورد فى عرض السعر', 'You Must Enter Customer No. Or Supplier No In Sales Proposal.');
    end if;
    if l_cust is not null and (l_new or changed(l_cust, old.customer_code)) then
      l_msg := customer_error(l_cust, l_type);
      if l_msg is not null then return l_msg; end if;
    end if;
    -- customer / supplier / rate / class frozen once lines exist
    if l_lines > 0 and (changed(l_cust, old.customer_code) or changed(l_supp, old.supplier_code) or changed(l_rate, old.currency_rate)
                        or changed(l_class, old.class_code)) then
      return m('برجاء حذف الاصناف اولا', 'Please Delete Inserted Items First');
    end if;
    l_store := nvl(l_store, type_store(l_type));
    if l_store is null then return m('يجب إدخال المخزن', 'Store is required'); end if;
    if l_new or changed(l_store, old.store_code) then
      l_msg := store_error(l_store);
      if l_msg is not null then return l_msg; end if;
    end if;
    l_sman := nvl(l_sman, get_last_salesman_indate(l_cust));
    if l_sman is null and nvl(t.has_salesman, 0) = 1 and l_cust is not null then
      return m('يجب إدخال المندوب', 'Salesman is required');
    end if;
    if to_n(p_salesman) is not null and (l_new or changed(to_n(p_salesman), old.salesman_code)) then
      l_msg := salesman_error(l_sman, l_cust);
      if l_msg is not null then return l_msg; end if;
    end if;
    if l_curr = 1 and nvl(l_rate, 1) <> 1 then
      return m('معامل التحويل يجب أن يكون 1 !!!', 'Currency Rate Must Be 1 !!!');
    end if;
    if (l_new and l_class is not null) or (not l_new and changed(l_class, old.class_code)) then
      if pw <> 0 and user_flag('ENABLE_CHANGE_CLASS') = 0 then
        return m('غير مسموح لك بتغيير الفئة', 'You are not allowed to change the class');
      end if;
    end if;
    -- TRNS_DATE: disabled item = day of entry; VALIDATE_DATE
    if (l_new and to_d(p_date) is not null and trunc(to_d(p_date)) <> trunc(sysdate)) or (not l_new and changed_d(to_d(p_date), old.trns_date)) then
      return m('تاريخ عرض السعر هو تاريخ اليوم ولا يمكن تغييره', 'The quotation date is the day of entry and cannot be changed');
    end if;
    if l_new or changed(l_cust, old.customer_code) then
      l_msg := date_error(l_date, l_cust);
      if l_msg is not null then return l_msg; end if;
    end if;
    if l_new and p_rfq is not null then
      select max(trns_type_code || '-' || trns_serial) into l_v from st_proposal_mast where upper(rfq) = upper(p_rfq);
      if l_v is not null then return 'RFQ Repeated -' || l_v; end if;
    end if;
    -- approval workflow buttons (SALESMAN_BTN, SALESMAN_MNGR_BTN, PURCH_BTN, SALES_BTN)
    if l_new and (l_done = 1 or l_ap1 = 1 or l_ap2 = 1 or l_acc = 1) then
      return m('احفظ عرض السعر وأصنافه أولا ثم اعتمده', 'Save the quotation and its items before approving it');
    end if;
    if l_flags_changed then
      if l_done <> nvl(old.salesman_done, 0) then
        if l_done = 1 then
          select count(*) into l_n from st_proposal_det
           where trns_type_code = old.trns_type_code and trns_serial = old.trns_serial and nvl(choice_flag, 0) = 1 and nvl(unavailable_flag, 0) = 0;
          if l_n = 0 then return m('لايمكن التحويل الي امر بيع بدون اختيار الأصناف', 'Choose the items first'); end if;
        elsif nvl(old.approve, 0) = 1 or (pw <> 0 and user_flag('ALLOW_APPROVE') <> 1) then
          return m('لايمكن الغاء الاعتماد عن حركة معتمدة من المشرف', 'Cannot remove the salesman confirmation of a supervisor-approved quotation');
        end if;
      end if;
      if l_ap1 <> nvl(old.approve, 0) then
        if pw <> 0 and user_flag('ALLOW_APPROVE') <> 1 then return m('ليس لديك صلاحية', 'You Dont have permission'); end if;
        if l_ap1 = 0 and l_ap2 = 1 then
          return m('لايمكن الغاء الاعتماد عن حركة معتمدة من الادارة 2', 'Cannot remove approval 1 while approval 2 exists');
        end if;
        if l_ap1 = 1 then l_msg := qt_credit_error(old); if l_msg is not null then return l_msg; end if; end if;
      end if;
      if l_ap2 <> nvl(old.approve2, 0) then
        if pw <> 0 and user_flag('ALLOW_APPROVE2') <> 1 then return m('ليس لديك صلاحية', 'You Dont have permission'); end if;
        if l_ap2 = 1 and l_ap1 = 0 then
          return m('لايمكن الاعتماد لحركة غير معتمدة من الادارة 1', 'Level 1 approval is required first');
        end if;
        if l_ap2 = 1 then l_msg := qt_credit_error(old); if l_msg is not null then return l_msg; end if; end if;
      end if;
      if l_acc <> nvl(old.cust_accept_flag, 0) then
        if user_flag('ALLOW_APPROVE3') <> 1 then return m('ليس لديك صلاحية', 'You Dont have permission'); end if;   -- no group-0 bypass (GET_USER_SEC)
        if l_acc = 1 then l_msg := qt_credit_error(old); if l_msg is not null then return l_msg; end if; end if;
      end if;
    elsif not l_new and nvl(old.approve, 0) = 1 and pw <> 0 and user_flag('ALLOW_APPROVE') <> 1
          and user_flag('ALLOW_APPROVE2') <> 1 and user_flag('ALLOW_APPROVE3') <> 1 then
      return m('الحركة الحالية معتمدة و لا يمكن تعديلها', 'The current transaction is approved and can''t be changed');
    end if;
    if not l_new then
      g_snap_rowid := p_rowid;
      g_snap_lines := l_lines;
    end if;
    return null;
  end qt_validate;

  procedure qt_after_save (p_request in varchar2, p_rowid in varchar2) is
    qt      st_proposal_mast%rowtype;
    l_lines number;
    l_net   number;
    l_v1 number; l_v2 number; l_v3 number; l_r1 number; l_r2 number; l_r3 number;
  begin
    if p_rowid is null then return; end if;
    select * into qt from st_proposal_mast where rowid = chartorowid(p_rowid);
    select count(*), nvl(sum((nvl(unit_price, 0) - (nvl(disc1_value, 0) + nvl(disc2_value, 0) + nvl(disc3_value, 0))) * nvl(quantity, 0)), 0)
      into l_lines, l_net
      from st_proposal_det where trns_type_code = qt.trns_type_code and trns_serial = qt.trns_serial;
    -- PRE-INSERT: a quotation needs items (the APEX header is created first, so from the first save of lines on)
    if p_request <> 'CREATE' and l_lines = 0 then
      err(-20169, 'غير مسموح بحفظ عرض السعر بدون أصنــــــاف  !!! ', 'Can''t Save Proposal Without Items');
    end if;
    -- lines of a confirmed / approved quotation cannot be deleted either
    if g_snap_rowid = p_rowid and l_lines < g_snap_lines
       and (nvl(qt.cust_accept_flag, 0) = 1 or (nvl(qt.approve, 0) = 1 and pw <> 0 and user_flag('ALLOW_APPROVE') <> 1)) then
      err(-20162, 'الحركة الحالية معتمدة و لا يمكن تعديل الأصناف', 'The quotation is approved: its lines cannot be changed');
    end if;
    l_r1 := qt.tot_disc1_ratio; l_v1 := qt.tot_disc1_value; l_r2 := qt.tot_disc2_ratio; l_v2 := qt.tot_disc2_value;
    l_r3 := qt.tot_disc3_ratio; l_v3 := qt.tot_disc3_value;
    tot_discounts(l_net, l_r1, l_v1, l_r2, l_v2, l_r3, l_v3);
    if changed(l_r1, qt.tot_disc1_ratio) or changed(l_v1, qt.tot_disc1_value) or changed(l_r2, qt.tot_disc2_ratio)
       or changed(l_v2, qt.tot_disc2_value) or changed(l_r3, qt.tot_disc3_ratio) or changed(l_v3, qt.tot_disc3_value) then
      update st_proposal_mast set tot_disc1_ratio = l_r1, tot_disc1_value = l_v1, tot_disc2_ratio = l_r2, tot_disc2_value = l_v2,
             tot_disc3_ratio = l_r3, tot_disc3_value = l_v3
       where rowid = chartorowid(p_rowid);
    end if;
    g_snap_rowid := null;
  end qt_after_save;

  -- ================================================================== ST_DELIVERY
  procedure dlv_mast_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_date in out date,
    p_delivery_serial in out number, p_note_no in out number, p_store in out number,
    p_order_type in number, p_order_serial in number,
    p_customer in out number, p_supplier in out number, p_salesman in out number,
    p_delete_flag in out number, p_state in out number) is
    so st_sales_order%rowtype;
    l_sales_type number;
  begin
    if g_bypass or not p_inserting then return; end if;
    p_date := trunc(nvl(p_date, sysdate));
    if p_store is null then p_store := type_store(p_type); end if;
    select max(sales_trns_type_code) into l_sales_type from st_trns_type where trns_type_code = p_type;
    if l_sales_type is null then
      err(-20171, 'يجب ربط اذن التسليم بسند اخراج في شاشة انواع الحركات', 'Link the delivery type to an issue type first');
    end if;
    if p_delivery_serial is null then
      select nvl(max(nvl(delivery_serial, 0)), 0) + 1 into p_delivery_serial from st_delivery_mast where trns_type_code = p_type;
    end if;
    if p_note_no is null then                              -- GET_NEXT_DELIVERY_DOC_NO (per type)
      select nvl(max(nvl(note_no, 0)), 0) + 1 into p_note_no from st_delivery_mast where trns_type_code = p_type;
    end if;
    if p_order_type is not null and p_order_serial is not null then
      begin
        select * into so from st_sales_order where trns_type_code = p_order_type and trns_serial = p_order_serial;
        p_customer := nvl(p_customer, so.customer_code);
        p_supplier := nvl(p_supplier, so.supplier_code);
        p_salesman := nvl(p_salesman, nvl(so.salesman_code, get_last_salesman_indate(so.customer_code)));
      exception when no_data_found then null;
      end;
    end if;
    p_delete_flag := nvl(p_delete_flag, 0);
    p_state := nvl(p_state, 1);
  end dlv_mast_row;

  function dlv_line_serial (p_type in number, p_serial in number, p_group in number, p_item in varchar2) return number is
    l_ot number; l_os number; l_line number;
  begin
    select order_trns_type_code, order_trns_serial into l_ot, l_os
      from st_delivery_mast where trns_type_code = p_type and trns_serial = p_serial;
    select min(d.serial) into l_line
      from st_sales_order_det d
     where d.trns_type_code = l_ot and d.trns_serial = l_os and d.item_code = p_item
       and (p_group is null or d.item_group_code = p_group)
       and not exists (select 1 from st_delivery_det x where x.trns_type_code = p_type and x.trns_serial = p_serial and x.serial = d.serial);
    if l_line is null then
      err(-20172, 'الصنف ' || p_item || ' غير موجود في أمر البيع أو تم إدخاله بالفعل', 'Item ' || p_item || ' is not on the sales order or already entered');
    end if;
    return l_line;
  end dlv_line_serial;

  procedure dlv_det_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_line in number,
    p_group in out number, p_item in varchar2, p_unit in out number, p_confg in out number,
    p_qty in number, p_bonus in out number, p_price in out number, p_price_curr in out number, p_store in out number) is
    dm st_delivery_mast%rowtype;
    od st_sales_order_det%rowtype;
  begin
    if g_bypass then return; end if;
    select * into dm from st_delivery_mast where trns_type_code = p_type and trns_serial = p_serial;
    if nvl(dm.delete_flag, 0) = 1 then
      err(-20173, 'المذكرة ملغاه بالفعل', 'The delivery note is cancelled');
    end if;
    if nvl(p_qty, 0) <= 0 then
      err(-20174, 'الكمية المسلمة يجب ان تكون اكبر من الصفر', 'The delivered quantity must be greater than zero');
    end if;
    begin
      select * into od from st_sales_order_det
       where trns_type_code = dm.order_trns_type_code and trns_serial = dm.order_trns_serial and serial = p_line;
    exception when no_data_found then
      err(-20172, 'السطر لا يطابق سطراً في أمر البيع', 'The line does not match a sales-order line');
    end;
    if p_item <> od.item_code then
      err(-20172, 'الصنف ' || p_item || ' لا يطابق سطر أمر البيع', 'Item ' || p_item || ' does not match the sales-order line');
    end if;
    p_group := nvl(p_group, od.item_group_code); p_unit := nvl(p_unit, od.unit_code); p_confg := nvl(p_confg, od.item_confg_id);
    p_price := nvl(p_price, od.unit_price); p_price_curr := nvl(p_price_curr, od.unit_price_curr);
    p_bonus := nvl(p_bonus, 0);
    p_store := dm.store_code;
    if unit_factor(p_group, p_item, p_unit) is null then
      err(-20175, 'يجب ادخال معامل التحويل', 'Enter the unit factor');
    end if;
  end dlv_det_row;

  function dlv_validate (
    p_request in varchar2, p_rowid in varchar2, p_type in varchar2, p_date in varchar2,
    p_order_type in varchar2, p_order_serial in varchar2) return varchar2 is
    l_type  number := to_n(p_type);
    l_date  date := nvl(to_d(p_date), trunc(sysdate));
    l_ot    number := to_n(p_order_type);
    l_os    number := to_n(p_order_serial);
    l_new   boolean := p_rowid is null;
    old     st_delivery_mast%rowtype;
    so      st_sales_order%rowtype;
    l_msg   varchar2(4000);
    l_n     number;
  begin
    if not l_new then
      select * into old from st_delivery_mast where rowid = chartorowid(p_rowid);
      if nvl(old.delete_flag, 0) = 1 then return m('المذكرة ملغاه بالفعل', 'The delivery note is cancelled'); end if;
      select count(*) into l_n from st_trns_mast where delivery_trns_type_code = old.trns_type_code and delivery_trns_serial = old.trns_serial
                                                    and nvl(delete_flag, 0) = 0;
      if l_n > 0 or old.post_trns_serial is not null then
        return m('مذكرة التسليم تم تحويلها إلي فاتورة مبيعات', 'The delivery note was converted to a sales invoice');
      end if;
      if changed(l_ot, old.order_trns_type_code) or changed(l_os, old.order_trns_serial) then
        select count(*) into l_n from st_delivery_det where trns_type_code = old.trns_type_code and trns_serial = old.trns_serial;
        if l_n > 0 then return m('برجاء حذف الاصناف اولا', 'Please Delete Inserted Items First'); end if;
      end if;
    end if;
    l_msg := type_error(l_type, 'DLV');
    if l_msg is not null then return l_msg; end if;
    l_msg := date_error(l_date, null, false);
    if l_msg is not null then return l_msg; end if;
    if l_ot is null or l_os is null then
      return m('يجب اختيار أمر البيع', 'Choose the sales order');
    end if;
    begin
      select * into so from st_sales_order where trns_type_code = l_ot and trns_serial = l_os;
    exception when no_data_found then
      return m('أمر البيع غير موجود', 'The sales order does not exist');
    end;
    if so.order_date > l_date then
      return m('لا يمكن ان يكون تاريخ التسليم اصغر من تاريخ الطلب', 'The delivery date cannot be before the order date');
    end if;
    if l_new or changed(l_ot, old.order_trns_type_code) or changed(l_os, old.order_trns_serial) then
      if check_valid_ord(l_ot, l_os) <> 1 then
        return m('تم عمل تسليم لكامل اصناف امر البيع', 'All items of the sales order are already delivered');
      end if;
    end if;
    return null;
  end dlv_validate;

  procedure dlv_after_save (p_request in varchar2, p_rowid in varchar2) is
    dm      st_delivery_mast%rowtype;
    l_lines number;
    l_total number;
    l_neg   number;
    l_bal   number;
  begin
    if p_rowid is null then return; end if;
    select * into dm from st_delivery_mast where rowid = chartorowid(p_rowid);
    select count(*), nvl(sum(nvl(unit_price, 0) * nvl(delivered_qty, 0) - nvl(det_disc, 0)), 0) into l_lines, l_total
      from st_delivery_det where trns_type_code = dm.trns_type_code and trns_serial = dm.trns_serial;
    if p_request <> 'CREATE' and l_lines = 0 then
      err(-20176, 'غير مسموح بحفظ مذكرة التسليم بدون أصنــــــاف !!!', 'A delivery note cannot be saved without items');
    end if;
    if nvl(dm.disc_val, 0) > 0 and nvl(dm.disc_val, 0) >= l_total and l_lines > 0 then
      err(-20177, 'قيمة الخصم يجب أن تكون أقل من قيمة مذكرة التسليم', 'The discount must be less than the delivery note value');
    end if;
    -- delivered (all non-cancelled notes of the order) <= ordered, per order line
    for r in (select d.serial, max(o.quantity) oq, max(nvl(o.bonus, 0)) ob, max(d.item_code) item,
                     (select sum(nvl(x.delivered_qty, 0)) from st_delivery_det x, st_delivery_mast xm
                       where xm.trns_type_code = x.trns_type_code and xm.trns_serial = x.trns_serial and nvl(xm.delete_flag, 0) = 0
                         and xm.order_trns_type_code = dm.order_trns_type_code and xm.order_trns_serial = dm.order_trns_serial
                         and x.serial = d.serial) dq,
                     (select sum(nvl(x.bonus, 0)) from st_delivery_det x, st_delivery_mast xm
                       where xm.trns_type_code = x.trns_type_code and xm.trns_serial = x.trns_serial and nvl(xm.delete_flag, 0) = 0
                         and xm.order_trns_type_code = dm.order_trns_type_code and xm.order_trns_serial = dm.order_trns_serial
                         and x.serial = d.serial) db
                from st_delivery_det d, st_sales_order_det o
               where d.trns_type_code = dm.trns_type_code and d.trns_serial = dm.trns_serial
                 and o.trns_type_code = dm.order_trns_type_code and o.trns_serial = dm.order_trns_serial and o.serial = d.serial
               group by d.serial) loop
      if r.dq > r.oq or r.db > r.ob then
        err(-20178, 'الكمية المستلمة أكبر من الكمية المطلوبة (' || r.item || ')', 'Delivered quantity exceeds the ordered quantity (' || r.item || ')');
      end if;
    end loop;
    -- lot balance at the delivery date (NEG_SALE_BALANCE = 0)
    select nvl(max(neg_sale_balance), 0) into l_neg from st_basic;
    if l_neg = 0 then
      for d in (select * from st_delivery_det where trns_type_code = dm.trns_type_code and trns_serial = dm.trns_serial) loop
        l_bal := get_balance_confg(dm.store_code, d.item_group_code, d.item_code, d.item_confg_id, dm.delivery_date);
        if nvl(l_bal, 0) < (nvl(d.delivered_qty, 0) + nvl(d.bonus, 0)) * unit_factor(d.item_group_code, d.item_code, d.unit_code) then
          err(-20179, 'رصيــد هذا الصنف فى هذا التاريخ لا يسمــح (' || d.item_code || ')', 'Item balance on this date does not allow (' || d.item_code || ')');
        end if;
      end loop;
    end if;
  end dlv_after_save;

  -- ================================================================== ST_ITEM_REQ / ST_ITEM_REQ_HANDLE
  procedure req_mast_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_date in out date, p_date_serial in out number,
    p_store in out number, p_from_store in number, p_approve in out number, p_close in out number) is
    l_comm number;
  begin
    if g_bypass then return; end if;
    if p_inserting then
      p_date := trunc(nvl(p_date, sysdate));
      if p_store is null then select max(store_code) into p_store from st_trns_type where trns_type_code = p_type; end if;
      if p_date_serial is null then
        select nvl(max(date_serial), 0) + 1 into p_date_serial from st_item_req where store_code = p_store and req_date = p_date;
      end if;
      p_approve := nvl(p_approve, 0); p_close := nvl(p_close, 0);
    end if;
    select nvl(max(comm_flag), 0) into l_comm from st_store where store_code = p_store;
    if l_comm = 1 then
      err(-20181, 'لا يمكنك إختيار حركة المخزن الرئيسى لها خاص بفرع (Offline)', 'The store of this type belongs to an offline branch');
    end if;
    if p_from_store is not null and p_from_store = p_store then
      err(-20182, 'لا يمكنك التحويل من نفس مخزن الحركة', 'You cannot transfer from the store of the transaction');
    end if;
  end req_mast_row;

  procedure req_det_row (
    p_inserting in boolean, p_type in number, p_serial in number,
    p_group in out number, p_item in varchar2, p_unit in out number,
    p_req_qty in out number, p_qty in out number, p_basic_qty in out number, p_price in number,
    p_date in out date, p_date_serial in out number, p_old_pr_flag in number) is
    l_n number;
  begin
    if g_bypass then return; end if;
    if nvl(p_old_pr_flag, 0) > 0 then
      err(-20183, 'لا يمكن تعديل سطر تم تحويله لطلب شراء / طلب تحويل', 'A converted line cannot be changed');
    end if;
    if p_inserting then
      select count(*) into l_n from pr_order_det_request where req_trns_type_code = p_type and req_trns_serial = p_serial;
      if l_n = 0 then
        select count(*) into l_n from st_trns_det_request where req_trns_type_code = p_type and req_trns_serial = p_serial;
      end if;
      if l_n = 0 then
        select count(*) into l_n from st_item_req_det where trns_type_code = p_type and trns_serial = p_serial and nvl(pr_flag, 0) > 0;
      end if;
      if l_n > 0 then
        err(-20184, 'لا يمكن انشاء سجل جديد بسبب ارتباط السجل الرئيسى بمرحلة تالية', 'The request is already processed: no new lines');
      end if;
      select req_date, date_serial into p_date, p_date_serial from st_item_req where trns_type_code = p_type and trns_serial = p_serial;
    end if;
    item_check(p_group, p_item);
    if p_unit is null then p_unit := basic_unit(p_group, p_item); end if;
    p_req_qty := nvl(p_req_qty, p_qty);
    p_qty := nvl(p_qty, p_req_qty);
    if nvl(p_qty, 0) <= 0 or nvl(p_req_qty, 0) <= 0 then
      err(-20185, 'الكمية يجب أن تكون أكبر من الصفر', 'The quantity must be greater than zero');
    end if;
    if p_price is not null and p_price <= 0 then
      err(-20186, 'السعر المتوقع يجب أن تكون أكبر من الصفر', 'The expected price must be greater than zero');
    end if;
    p_basic_qty := p_qty * unit_factor(p_group, p_item, p_unit);
  end req_det_row;

  function req_validate (
    p_request in varchar2, p_rowid in varchar2, p_type in varchar2, p_date in varchar2,
    p_store in varchar2, p_from_store in varchar2) return varchar2 is
    l_msg varchar2(4000);
    l_fs  number := to_n(p_from_store);
    l_st  number := to_n(p_store);
  begin
    if l_st is null then select max(store_code) into l_st from st_trns_type where trns_type_code = to_n(p_type); end if;
    l_msg := type_error(to_n(p_type), 'REQ', false);
    if l_msg is not null then return l_msg; end if;
    if p_rowid is null or to_d(p_date) is not null then
      l_msg := date_error(nvl(to_d(p_date), trunc(sysdate)), null, false);
      if l_msg is not null then return l_msg; end if;
    end if;
    if l_fs is not null then
      l_msg := store_error(l_fs);
      if l_msg is not null then return l_msg; end if;
      if l_fs = l_st then
        return m('لا يمكنك التحويل من نفس مخزن الحركة', 'You cannot transfer from the store of the transaction');
      end if;
    end if;
    return null;
  end req_validate;

  procedure req_after_save (p_request in varchar2, p_rowid in varchar2) is
    r       st_item_req%rowtype;
    l_lines number;
    l_max   number;
    l_single number;
    l_n     number;
  begin
    if p_rowid is null then return; end if;
    select * into r from st_item_req where rowid = chartorowid(p_rowid);
    select count(*) into l_lines from st_item_req_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    if p_request <> 'CREATE' and l_lines = 0 then
      err(-20187, 'يجب إدخال الاصناف', 'Enter the items');
    end if;
    select max(trns_max_items), nvl(max(single_item), 0) into l_max, l_single from st_basic;
    if l_max is not null and l_lines > l_max then
      err(-20142, 'لقد تم إدخال ' || l_lines || ' صنف فى هذه الحركة غير مسموح بالمزيد من الأصناف', 'Too many items');
    end if;
    if l_single = 1 then
      select count(*) into l_n from (select group_code, item_code, color_code, size_code from st_item_req_det
                                      where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial
                                      group by group_code, item_code, color_code, size_code having count(*) > 1);
      if l_n > 0 then err(-20188, 'غير مسموح بتكرار الصنف', 'Repeating items is not allowed'); end if;
    end if;
  end req_after_save;

  -- ================================================================== ST_PRUCHASE_REQUEST
  procedure prq_mast_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_date in out date, p_date_serial in out number,
    p_store in out number) is
    l_comm number;
  begin
    if g_bypass then return; end if;
    if p_store is null then select max(store_code) into p_store from st_trns_type where trns_type_code = p_type; end if;
    if p_store is null then
      err(-20191, 'ادخل رقم المخزن', 'Enter the store');
    end if;
    if p_inserting then
      p_date := trunc(nvl(p_date, sysdate));
      if p_date_serial is null then
        select nvl(max(date_serial), 0) + 1 into p_date_serial from pr_order_request where store_code = p_store and req_date = p_date;
      end if;
    end if;
    select nvl(max(comm_flag), 0) into l_comm from st_store where store_code = p_store;
    if l_comm = 1 then
      err(-20181, 'لا يمكنك إختيار حركة المخزن الرئيسى لها خاص بفرع (Offline)', 'The store of this type belongs to an offline branch');
    end if;
  end prq_mast_row;

  function prq_line_linked (p_type in number, p_serial in number, p_line in number) return varchar2 is
    l_n number;
  begin
    select count(*) into l_n from pr_order_det where req_trns_type_code = p_type and req_trns_serial = p_serial
                                                 and (p_line is null or req_item_serial = p_line);
    if l_n > 0 then return m('الحركة الحالية مرتبطة بحركة أمر شراء و لا يمكن الحذف', 'The request is linked to a purchase order'); end if;
    select count(*) into l_n from pr_req_det where pr_trns_type_code = p_type and pr_trns_serial = p_serial
                                               and (p_line is null or pr_item_serial = p_line);
    if l_n > 0 then return m('الحركة الحالية مرتبطة بحركة طلب عرض أسعار و لا يمكن الحذف', 'The request is linked to a request for quotation'); end if;
    return null;
  end prq_line_linked;

  procedure prq_det_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_line in number,
    p_group in out number, p_item in varchar2, p_unit in out number, p_qty in number, p_basic_qty in out number,
    p_supplier in out number, p_date in out date, p_date_serial in out number,
    p_old_group in number, p_old_item in varchar2, p_old_unit in number, p_old_qty in number) is
    l_msg varchar2(4000);
  begin
    if g_bypass then return; end if;
    if not p_inserting and (changed(p_group, p_old_group) or changed_s(p_item, p_old_item) or changed(p_unit, p_old_unit)
                            or changed(p_qty, p_old_qty)) then
      l_msg := prq_line_linked(p_type, p_serial, p_line);
      if l_msg is not null then raise_application_error(-20192, l_msg); end if;
    end if;
    if nvl(p_qty, 0) <= 0 then
      err(-20185, 'الكمية يجب أن تكون أكبر من الصفر', 'The quantity must be greater than zero');
    end if;
    item_check(p_group, p_item);
    if p_unit is null then p_unit := basic_unit(p_group, p_item); end if;
    p_basic_qty := p_qty * unit_factor(p_group, p_item, p_unit);
    if p_supplier is null then
      select max(supplier) into p_supplier from st_item where item_group_code = p_group and item_code = p_item;
    end if;
    if p_inserting then
      select req_date, date_serial into p_date, p_date_serial from pr_order_request where trns_type_code = p_type and trns_serial = p_serial;
    end if;
  end prq_det_row;

  function prq_validate (
    p_request in varchar2, p_rowid in varchar2, p_type in varchar2, p_date in varchar2, p_store in varchar2) return varchar2 is
    l_msg varchar2(4000);
    l_store number := to_n(p_store);
  begin
    l_msg := type_error(to_n(p_type), 'PRQ', false);
    if l_msg is not null then return l_msg; end if;
    l_msg := date_error(nvl(to_d(p_date), trunc(sysdate)), null, false);
    if l_msg is not null then return l_msg; end if;
    if l_store is not null then
      l_msg := store_error(l_store);
      if l_msg is not null then return l_msg; end if;
    end if;
    return null;
  end prq_validate;

  procedure prq_after_save (p_request in varchar2, p_rowid in varchar2) is
    r       pr_order_request%rowtype;
    l_lines number;
    l_max   number;
    l_single number;
    l_n     number;
  begin
    if p_rowid is null then return; end if;
    select * into r from pr_order_request where rowid = chartorowid(p_rowid);
    select count(*) into l_lines from pr_order_det_request where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    if p_request <> 'CREATE' and l_lines = 0 then
      err(-20193, 'يجب ادخال اصناف', 'Enter the items');
    end if;
    select max(trns_max_items), nvl(max(single_item), 0) into l_max, l_single from st_basic;
    if l_max is not null and l_lines > l_max then
      err(-20142, 'لقد تم إدخال ' || l_lines || ' صنف فى هذه الحركة، غير مسموح بالمزيد من الأصناف', 'Too many items');
    end if;
    if l_single = 1 then
      select count(*) into l_n from (select group_code, item_code from pr_order_det_request
                                      where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial
                                      group by group_code, item_code having count(*) > 1);
      if l_n > 0 then err(-20188, 'غير مسموح بتكرار الصنف', 'Repeating items is not allowed'); end if;
    end if;
  end prq_after_save;

  -- ================================================================== PR_MR / PR_QUOT_TRNS
  procedure rfq_det_row (p_group in number, p_color in number, p_size in number) is
    l_color number; l_size number;
  begin
    if g_bypass then return; end if;
    select nvl(max(color_flag), 0), nvl(max(size_flag), 0) into l_color, l_size from st_item_group where item_group_code = p_group;
    if l_color = 1 and p_color is null then err(-20194, 'يجب ادخال اللون', 'Enter the colour'); end if;
    if l_size = 1 and p_size is null then err(-20194, 'يجب ادخال المقاس', 'Enter the size'); end if;
  end rfq_det_row;

  function quot_has_po (p_type in number, p_serial in number, p_supplier in number) return boolean is
    l_n number;
  begin
    select count(*) into l_n from pr_order_det
     where quot_trns_type_code = p_type and quot_trns_serial = p_serial and (p_supplier is null or quot_supplier_id = p_supplier);
    return l_n > 0;
  end quot_has_po;

  procedure quot_mast_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_supplier in number,
    p_quot_serial in out number, p_currency in out number, p_rate in out number, p_disc_val in number,
    p_date_send in out date, p_accept in number, p_old_accept in number,
    p_quot_flag in number, p_old_quot_flag in number, p_old_disc_val in number) is
    l_req_date date;
  begin
    if g_bypass then return; end if;
    if p_inserting then
      if p_quot_serial is null then
        select nvl(max(nvl(quot_serial, 0)), 0) + 1 into p_quot_serial from pr_quot_mast where trns_type_code = p_type and trns_serial = p_serial;
      end if;
      if p_currency is null then
        select nvl(max(currency_code), 1) into p_currency from supplier where code = p_supplier;
      end if;
    elsif quot_has_po(p_type, p_serial, p_supplier)
          and (changed(p_accept, p_old_accept) or changed(p_quot_flag, p_old_quot_flag) or changed(p_disc_val, p_old_disc_val)) then
      err(-20195, ' الحركة الحالية تم عمل أمر شراء لها بالفعل ', 'A purchase order exists for this quotation');
    end if;
    p_currency := nvl(p_currency, 1);
    if p_rate is null then
      select nvl(max(rate), 1) into p_rate from ac_currency where currency_code = p_currency;
    end if;
    if nvl(p_disc_val, 0) < 0 then
      err(-20196, 'الخصم يجب أن يكون أكبر من أو يساوي صفر', 'The discount must be zero or more');
    end if;
    if nvl(p_accept, 0) = 1 and nvl(p_old_accept, 0) = 0 then
      p_date_send := nvl(p_date_send, trunc(sysdate));           -- accepting a supplier sets the PO date
    elsif nvl(p_accept, 0) = 0 and nvl(p_old_accept, 0) = 1 then
      p_date_send := null;
    end if;
    if p_date_send is not null then
      if trunc(p_date_send) > trunc(sysdate) then
        err(-20197, 'تاريخ الحركة أكبر من تاريخ اليوم', 'Transaction Date is greater than today''s date');
      end if;
      select max(req_date) into l_req_date from pr_req_mast where trns_type_code = p_type and trns_serial = p_serial;
      if l_req_date is not null and p_date_send < l_req_date then
        err(-20197, 'تاريخ أمر الشراء لا يمكن ان يكون اقل من تاريخ الطلب', 'The PO date cannot be before the request date');
      end if;
    end if;
  end quot_mast_row;

  procedure quot_det_row (
    p_inserting in boolean, p_type in number, p_serial in number, p_supplier in number, p_line in number,
    p_price in number, p_old_price in number, p_det_disc in number, p_arrival in date, p_color in number, p_size in number) is
    rd   pr_req_det%rowtype;
    qm   pr_quot_mast%rowtype;
    l_req_date date;
  begin
    if g_bypass then return; end if;
    begin
      select * into rd from pr_req_det where trns_type_code = p_type and trns_serial = p_serial and req_det_serial = p_line;
    exception when no_data_found then
      err(-20198, 'سطر عرض السعر يجب أن يطابق سطراً في طلب عرض الأسعار', 'A quotation line must match a line of the request for quotation');
    end;
    begin
      select * into qm from pr_quot_mast where trns_type_code = p_type and trns_serial = p_serial and supplier_id = p_supplier;
    exception when no_data_found then
      err(-20198, 'المورد ' || p_supplier || ' غير مضاف لطلب عرض الأسعار', 'Supplier ' || p_supplier || ' is not on the request for quotation');
    end;
    if quot_has_po(p_type, p_serial, p_supplier) then
      err(-20195, ' الحركة الحالية تم عمل أمر شراء لها بالفعل ', 'A purchase order exists for this quotation');
    end if;
    if changed(p_price, p_old_price) and nvl(qm.quot_flag, 0) <> 1 then
      err(-20199, 'يجب تفعيل مؤشر الرد للمورد قبل إدخال الأسعار', 'Tick the supplier reply flag before entering prices');
    end if;
    if p_price is not null and p_price <= 0 then
      err(-20199, 'السعر يجب أن يكون أكبر من الصفر', 'The price must be greater than zero');
    end if;
    if nvl(p_det_disc, 0) > nvl(rd.quantity, 0) * nvl(p_price, 0) then
      err(-20199, 'قيمة الخصم يجب أن تكون أقل من أو تساوي إجمالي العرض!!!!', 'The discount must not exceed the line total');
    end if;
    if p_arrival is not null then
      select max(req_date) into l_req_date from pr_req_mast where trns_type_code = p_type and trns_serial = p_serial;
      if l_req_date is not null and p_arrival < l_req_date then
        err(-20199, 'تاريخ الوصول لا يمكن ان يكون اقل من تاريخ الطلب', 'The arrival date cannot be before the request date');
      end if;
      if qm.date_send is not null and p_arrival < qm.date_send then
        err(-20199, 'تاريخ الوصول لا يمكن ان يكون اقل من تاريخ أمر الشراء', 'The arrival date cannot be before the PO date');
      end if;
    end if;
    rfq_det_row(rd.item_group_code, p_color, p_size);
  end quot_det_row;

  function rfq_validate (p_request in varchar2, p_rowid in varchar2) return varchar2 is
  begin
    g_snap_rowid := null;
    if p_rowid is not null then
      g_snap_rowid := p_rowid;
      g_snap_det.delete;
      select q.supplier_id, null, null, null, null, null, null, null, nvl(q.accept_flag, 0)
        bulk collect into g_snap_det
        from pr_quot_mast q, pr_req_mast r
       where r.rowid = chartorowid(p_rowid) and q.trns_type_code = r.trns_type_code and q.trns_serial = r.trns_serial;
    end if;
    return null;
  end rfq_validate;

  -- suppliers of an RFQ: generated price lines, removed suppliers, status (PR_MR KEY-DELREC / POST-INSERT)
  procedure rfq_sync (r in pr_req_mast%rowtype, p_rowid in varchar2) is
    l_n number;
  begin
    -- a supplier with an accepted quotation cannot be removed
    if g_snap_rowid = p_rowid then
      for i in 1 .. g_snap_det.count loop
        select count(*) into l_n from pr_quot_mast where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial
                                                     and supplier_id = g_snap_det(i).line;
        if l_n = 0 and g_snap_det(i).flag = 1 then
          err(-20195, 'لا يمكن حذف طلب الاسعار حيث انة تم الموافقة علية', 'An accepted quotation cannot be deleted');
        end if;
      end loop;
    end if;
    -- lines of removed suppliers
    delete from pr_quot_det d
     where d.trns_type_code = r.trns_type_code and d.trns_serial = r.trns_serial
       and not exists (select 1 from pr_quot_mast q where q.trns_type_code = d.trns_type_code and q.trns_serial = d.trns_serial
                                                      and q.supplier_id = d.supplier_id);
    -- one empty price line per RFQ line for every supplier without lines
    for q in (select supplier_id from pr_quot_mast q where q.trns_type_code = r.trns_type_code and q.trns_serial = r.trns_serial
                 and not exists (select 1 from pr_quot_det d where d.trns_type_code = q.trns_type_code and d.trns_serial = q.trns_serial
                                                               and d.supplier_id = q.supplier_id)) loop
      g_bypass := true;
      insert into pr_quot_det (trns_type_code, trns_serial, supplier_id, req_det_serial, unit_price)
      select trns_type_code, trns_serial, q.supplier_id, req_det_serial, null
        from pr_req_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      g_bypass := false;
    end loop;
    select count(*) into l_n from pr_quot_mast where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    if l_n = 0 then
      update pr_req_mast set req_status = 1
       where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and nvl(req_status, 0) <> 1;
    end if;
  exception when others then
    g_bypass := false;
    raise;
  end rfq_sync;

  procedure rfq_after_save (p_request in varchar2, p_rowid in varchar2) is
    r pr_req_mast%rowtype;
  begin
    if p_rowid is null then return; end if;
    select * into r from pr_req_mast where rowid = chartorowid(p_rowid);
    rfq_sync(r, p_rowid);
    g_snap_rowid := null;
  end rfq_after_save;

  procedure quot_after_save (p_request in varchar2, p_rowid in varchar2) is
    r      pr_req_mast%rowtype;
    l_n    number;
    l_acc  number;
    l_tot  number;
  begin
    if p_rowid is null then return; end if;
    select * into r from pr_req_mast where rowid = chartorowid(p_rowid);
    rfq_sync(r, p_rowid);
    -- replies cleared: prices removed (QUOT_FLAG unticked)
    update pr_quot_det d set d.unit_price = null
     where d.trns_type_code = r.trns_type_code and d.trns_serial = r.trns_serial and d.unit_price is not null
       and exists (select 1 from pr_quot_mast q where q.trns_type_code = d.trns_type_code and q.trns_serial = d.trns_serial
                                                  and q.supplier_id = d.supplier_id and nvl(q.quot_flag, 0) = 0);
    -- one accepted supplier per RFQ
    select count(*), sum(case when nvl(accept_flag, 0) = 1 then 1 else 0 end) into l_n, l_acc
      from pr_quot_mast where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    if nvl(l_acc, 0) > 1 then
      err(-20195, 'هناك عرض تم إختياره بالفعل', 'Another quotation is already accepted');
    end if;
    -- header discount <= quotation total, arrival dates >= PO date
    for q in (select * from pr_quot_mast where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial) loop
      select nvl(sum(nvl(rd.quantity, 0) * nvl(qd.unit_price, 0) - nvl(qd.det_disc, 0)), 0) into l_tot
        from pr_quot_det qd, pr_req_det rd
       where qd.trns_type_code = q.trns_type_code and qd.trns_serial = q.trns_serial and qd.supplier_id = q.supplier_id
         and rd.trns_type_code = qd.trns_type_code and rd.trns_serial = qd.trns_serial and rd.req_det_serial = qd.req_det_serial;
      if nvl(q.disc_val, 0) > l_tot then
        err(-20196, 'قيمة الخصم يجب أن تكون أقل من أو تساوي إجمالي عرض السعر', 'The discount must not exceed the quotation total');
      end if;
      if q.date_send is not null then
        select count(*) into l_n from pr_quot_det
         where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial and supplier_id = q.supplier_id and exp_arrv_date < q.date_send;
        if l_n > 0 then
          err(-20197, 'تاريخ الوصول لا يمكن ان يكون اقل من تاريخ أمر الشراء', 'The arrival date cannot be before the PO date');
        end if;
      end if;
    end loop;
    -- REQ_STATUS: 1 request, 2 replies received, 3 supplier chosen (4 = PO, set by the PO process)
    select count(*) into l_n from pr_quot_mast where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and nvl(quot_flag, 0) = 1;
    update pr_req_mast
       set req_status = case when nvl(l_acc, 0) > 0 and nvl(req_status, 0) in (1, 2) then 3
                             when nvl(l_acc, 0) = 0 and nvl(req_status, 0) = 3 then 2
                             when l_n > 0 and nvl(req_status, 0) = 1 then 2
                             when l_n = 0 and nvl(req_status, 0) = 2 then 1
                             else req_status end
     where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    g_snap_rowid := null;
  end quot_after_save;

end app_rules_sa;
/
show errors package app_rules_sa
show errors package body app_rules_sa
