-- =====================================================================================================
-- APP_ACT_ST : legacy buttons, warnings, displays and delete rules of the sales and stock screens (Stage C, wave 3,
--              app\legacy\STAGE_C_WAVE3.md). Everything the legacy screens did that the data-entry rules of wave 2
--              (APP_RULES_SA / APP_RULES_ST) and the conversions of APP_CONV did not reproduce yet.
--
--   Screens: ST_ISSUE_IO, ST_ISSUE_RETURN, ST_SALES_ORDER, ST_PRICE_PROPOSAL, ST_DELIVERY, ST_RESERVATION, ST_TRANSFER_FROM,
--            ST_TRANSFER_TO, ST_TAKING, ST_TAKING2, ST_OPEN_BALANCE, ST_ADJUST_IN, ST_ADJUST_OUT, ST_TRANSFER_REQUEST,
--            ST_ITEM_REQ, ST_ITEM_REQ_HANDLE. Evidence, rules and decisions: app\legacy\processes\<FORM>.md.
--
-- Conventions
--   * Called from the APEX page (action buttons, validations, after-save processes, warnings, info displays): no COMMIT /
--     ROLLBACK; a refusal raises raise_application_error(-20100..-20199, message) and APEX rolls the whole request back.
--     Legacy message texts, English when app_sec.lang = 'en'.
--   * Installation code (:GLOBAL.CUSTOMER_CODE of the legacy menu = SELECT CUSTOMER_CODE FROM CUSTOMER_PAR, Sysmenu.fmx):
--     CUSTOMER_PAR is empty on this database (production discovery _discovery\05_tables_rows.csv: 0 rows), so the code is
--     NULL: branches "= 'SDI'" / "= 'MAR'" ... never apply, and "<> 'SDI'" / "NOT IN (...)" tests are NULL, i.e. their
--     ELSE branch runs, as in the legacy.
--   * Action functions return the ROWID of the document to open (or null to stay) and set last_message.
--   * Uploaded files (action parameters of type file) are read from APEX_APPLICATION_TEMP_FILES (get_file); tests put a
--     file in with set_test_file.
--
-- Sections (name prefixes): si_ ST_ISSUE_IO, sr_ ST_ISSUE_RETURN, so_ ST_SALES_ORDER, qt_ ST_PRICE_PROPOSAL, rsv_ ST_RESERVATION,
--   dlv_ ST_DELIVERY, trf_ ST_TRANSFER_FROM, trt_ ST_TRANSFER_TO, trq_ ST_TRANSFER_REQUEST, obl_ ST_OPEN_BALANCE, adi_ ST_ADJUST_IN,
--   ado_ ST_ADJUST_OUT, tk_ / tk2_ ST_TAKING / ST_TAKING2, rq_ / rqh_ ST_ITEM_REQ / ST_ITEM_REQ_HANDLE.
-- Tests (all rolled back, plain and simulated APEX session): tmp\w3_sales\f1..f5\t_f*.py (ACT_PKG=app_act_st), t_coord.py.
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_act_st authid definer as

  -- ------------------------------------------------------------------ common helpers
  function m (p_a in varchar2, p_e in varchar2 default null) return varchar2;     -- message in the session language
  procedure err (p_code in pls_integer, p_a in varchar2, p_e in varchar2 default null);
  function num (p in varchar2) return number;                                     -- to_number, null on error
  function dat (p in varchar2) return date;                                       -- DD/MM/YYYY (page items), null on error
  function usr return number;                                                     -- G_USER_CODE (test user outside APEX)
  function pw return number;                                                      -- G_PASSWORD_NUMBER (0 = all rights)
  function rid (p_rowid in varchar2) return rowid;
  function last_message return varchar2;                                          -- legacy confirmation of the last action
  procedure set_message (p_a in varchar2, p_e in varchar2 default null);
  -- uploaded file of an action parameter of type file (name = the parameter value)
  procedure get_file (p_name in varchar2, o_blob out blob, o_filename out varchar2);

  -- ================================================================== ST_ISSUE_IO / ST_ISSUE_RETURN
  -- ------------------------------------------------------------------ ST_ISSUE_IO (sales invoice)
  -- soft_delete.check of the invoice page (CTRL.DEL_BTN / KEY-DELREC): error text or null
  function si_delete_check (p_rowid in varchar2) return varchar2;
  -- after the soft delete (POST-UPDATE with DELETE_FLAG = 1): the sales order converted into the invoice is released
  procedure si_after_delete (p_rowid in varchar2);
  -- CTRL.DEL_BTN third answer "نعم بحذف أمر البيع": delete the invoice and its sales order
  function si_can_delete_order (p_rowid in varchar2) return varchar2;
  function si_delete_with_order (p_rowid in varchar2) return varchar2;
  -- displays of the legacy invoice (POST-QUERY, CHECK_MAST_STATUS, GET_PROPOSAL_INFO):
  --   CREDIT_LIMIT, BALANCE, DAY_NO, DAYS, STATUS, ITEMS, DIFF_POLICY, SALES_LIMIT, TOTAL, NET
  function si_info (p_rowid in varchar2, p_what in varchar2) return varchar2;

  -- ------------------------------------------------------------------ ST_ISSUE_RETURN (sales return)
  -- soft_delete.check of the return page (KEY-DELREC of the header and of each line): error text or null
  function sr_delete_check (p_rowid in varchar2) return varchar2;
  -- PUSH_BUTTON401 "إنزال أصناف الفاتورة" (DECOMPOSE_INVOICE_DET / DECOMPOSE_INVOICE_SERVICE)
  function sr_can_decompose (p_rowid in varchar2) return varchar2;
  function sr_decompose (p_rowid in varchar2) return varchar2;
  -- CONFG_RG "شحنة قديمة" (-1) of a return without invoice: GET_THE_CONFIG creates the lot and the formation lines
  function sr_can_old_lot (p_rowid in varchar2) return varchar2;
  function sr_old_lot (p_rowid in varchar2, p_item in varchar2, p_unit in number, p_qty in number, p_bonus in number,
                       p_lot_number in varchar2, p_expire_date in date, p_unit_cost in number, p_price in number,
                       p_disc1 in number) return varchar2;
  -- PRINT_FLAG only for user 0 (WHEN-NEW-FORM-INSTANCE enables the item for :GLOBAL.USER_CODE = 0)
  function sr_validate_extra (p_rowid in varchar2, p_print_flag in varchar2) return varchar2;
  -- displays of the legacy return: CREDIT (remaining credit), INV_DATE (original invoice date), NOTICES (max limit / wholesale)
  function sr_info (p_rowid in varchar2, p_what in varchar2) return varchar2;
  -- ================================================================== ST_SALES_ORDER / ST_PRICE_PROPOSAL
  -- ================================================================== ST_SALES_ORDER (so_)
  -- display conditions of the action regions ('Y' / 'N'): CLOSE, REOPEN, CANCEL, ACTIVATE
  function so_can (p_what in varchar2, p_rowid in varchar2) return varchar2;
  -- CLOSE_SALES_ORDER / CANCEL_CLOSE / CANCEL buttons: return the order ROWID, legacy text in app_act_st.last_message
  function so_close (p_rowid in varchar2) return varchar2;
  function so_reopen (p_rowid in varchar2) return varchar2;
  -- CANCEL (legacy toggle): p_activate 0 = cancel the order, 1 = activate the cancelled order
  function so_cancel (p_rowid in varchar2, p_activate in number default 0) return varchar2;
  -- DEVIDE_CONFGS: the row rule marks the lines saved without a lot (so_mark_auto_lot, before APP_RULES_SA.SO_DET_ROW fills
  -- the earliest lot); after the save the marked lines are spread over the lots by expiry (so_split_lots)
  procedure so_mark_auto_lot (p_type in number, p_serial in number, p_line in number);
  procedure so_split_lots (p_request in varchar2, p_rowid in varchar2);
  -- after the page deleted an order (lines first): refused when a live sales invoice was made from it
  procedure so_after_delete (p_type in varchar2, p_serial in varchar2);
  -- warnings (legacy MSG alerts shown while the order was entered): credit limit, customer PO date after the order date
  function so_warn_credit (p_rowid in varchar2, p_customer in varchar2, p_approved in varchar2) return varchar2;
  function so_warn_po_date (p_order_date in varchar2, p_po_date in varchar2) return varchar2;
  -- displays: CREDIT_LIMIT, BALANCE, DAYS, DAY_NO, CREDIT_STATE, NET, TAX, ITEMS, AVAILABLE, UNAVAILABLE, DIFF_POLICY,
  -- SALES_LIMIT, WIDE_PRICE, INVOICE
  function so_info (p_what in varchar2, p_rowid in varchar2) return varchar2;

  -- ================================================================== ST_PRICE_PROPOSAL (qt_)
  -- display conditions: CHOICE (CHOICE_FLAG_ALL / UNAVAILABLE_FLAG_ALL), EXCEL (LOAD_EXCEL)
  function qt_can (p_what in varchar2, p_rowid in varchar2) return varchar2;
  -- CHOICE_FLAG_ALL / UNAVAILABLE_FLAG_ALL check boxes: p_flag 1 = tick, 0 = untick
  function qt_choice_all (p_rowid in varchar2, p_flag in number) return varchar2;
  function qt_unavailable_all (p_rowid in varchar2, p_flag in number) return varchar2;
  -- LOAD_EXCEL / LOAD_EXCEL_FILE: lines from an Excel / CSV file (p_file = uploaded file name)
  function qt_load_excel (p_rowid in varchar2, p_file in varchar2) return varchar2;
  -- KEY-DELREC (soft delete): error text or null
  function qt_delete_check (p_rowid in varchar2) return varchar2;
  -- displays: CREDIT_LIMIT, BALANCE, DAYS, DAY_NO, CREDIT_STATE, NET, TAX, CHOSEN_NET, NOT_CHOSEN, ITEMS, AVAILABLE,
  -- UNAVAILABLE, UNAVAILABLE_ALL, DIFF_POLICY, SALES_LIMIT, LINKS
  function qt_info (p_what in varchar2, p_rowid in varchar2) return varchar2;
  -- ================================================================== ST_RESERVATION / ST_DELIVERY
  -- ------------------------------------------------------------------ ST_RESERVATION (quantity reservation)
  -- header rules of the legacy lists of values (customer / supplier / salesman / account / type store by group),
  -- customer required for customer types (JOIN_TYPE 3), salesman of the customer
  function rsv_validate (p_request in varchar2, p_rowid in varchar2, p_type in varchar2, p_store in varchar2,
                         p_customer in varchar2, p_supplier in varchar2, p_salesman in varchar2,
                         p_account in varchar2) return varchar2;
  -- after save: customer / supplier defaults (salesman, currency, posting supplier), invoice no / description of a new
  -- document, invoice discount spread per line (GET_NDB_DISC), discount and cash-paid checks, item group rights
  procedure rsv_after_save (p_request in varchar2, p_rowid in varchar2);
  -- button "صرف الفاتورة" (CONV_TO_INVOICE): delivery note + the reservation becomes a sales invoice
  function rsv_can_invoice (p_rowid in varchar2) return varchar2;
  function rsv_to_invoice (p_rowid in varchar2) return varchar2;
  -- displays: TOTAL (items), SRV (services), NET, CHANGE (paid - net)
  function rsv_info (p_rowid in varchar2, p_what in varchar2) return varchar2;

  -- ------------------------------------------------------------------ ST_DELIVERY (delivery notes)
  -- NOTE_NO repeated (CHECK_DOC_NO): refused when ST_BASIC.DOC_REPEAT = 2, warning when 3
  function dlv_note_error (p_rowid in varchar2, p_type in varchar2, p_note_no in varchar2) return varchar2;
  function dlv_note_warning (p_rowid in varchar2, p_type in varchar2, p_note_no in varchar2) return varchar2;
  -- after DELETE: a note with a sales invoice or merged into a merge invoice cannot be deleted
  procedure dlv_after_delete (p_type in varchar2, p_serial in varchar2);
  -- button "تحويل الي فاتورة بيع" (INV_TRNS / MAKE_INV: INSERT_ISSUE_TRNS, DEVIDE_CONFGS, INSERT_DET, UPDATE_DISC)
  function dlv_can_invoice (p_rowid in varchar2) return varchar2;
  function dlv_first_sales_type (p_rowid in varchar2) return number;
  function dlv_to_invoice (p_rowid in varchar2, p_sales_type in number, p_date in date) return varchar2;
  -- button "إلغاء مذكرة التسليم" (DEL_BUTTON): the generated issue is deleted, the note flagged DELETE_FLAG = 1
  function dlv_can_cancel (p_rowid in varchar2) return varchar2;
  function dlv_cancel (p_rowid in varchar2) return varchar2;
  -- displays: INV (sales invoice), TOTAL, NET, LIMIT (credit limit), BAL (customer balance), REMAIN (remaining credit)
  function dlv_info (p_rowid in varchar2, p_what in varchar2) return varchar2;
  -- ================================================================== ST_TRANSFER_FROM / ST_TRANSFER_TO / ST_TRANSFER_REQUEST / ST_OPEN_BALANCE / ST_ADJUST_IN / ST_ADJUST_OUT
  -- ------------------------------------------------------------------ ST_TRANSFER_FROM (issue transfer)
  -- soft delete (KEY-DELREC: DELETE_FLAG = 1): check before, ST_TRNSFER / transfer request after
  function trf_delete_check (p_rowid in varchar2) return varchar2;
  procedure trf_after_delete (p_rowid in varchar2);
  -- DOC_REPEAT = 1: "رقم المستند مكرر" + "هل تريد الإستمرار" (warning)
  function trf_doc_warn (p_rowid in varchar2, p_type in varchar2, p_doc_no in varchar2) return varchar2;
  -- displays: receipt status of the transfer; COUNT / COST / PRICE / UNITS totals of the lines
  function trf_status (p_rowid in varchar2) return varchar2;
  function trf_totals (p_rowid in varchar2, p_what in varchar2) return varchar2;
  -- automatic receipt (ST_BASIC.AUTO_TRANSFER = 1, ST_TRNS_TYPE.REC_TRANSFER_TRNS): returns the receipt ROWID
  function trf_can_auto_receive (p_rowid in varchar2) return varchar2;
  function trf_auto_receive (p_rowid in varchar2) return varchar2;
  -- Excel load (LOAD_EXCEL_FILE): item, unit, quantity, lot id, lot number, expiry date; returns null (stay)
  function trf_can_load (p_rowid in varchar2) return varchar2;
  function trf_load_excel (p_rowid in varchar2, p_file in varchar2) return varchar2;

  -- ------------------------------------------------------------------ ST_TRANSFER_TO (receive transfer)
  function trt_delete_check (p_rowid in varchar2) return varchar2;
  procedure trt_after_delete (p_rowid in varchar2);
  function trt_doc_warn (p_rowid in varchar2, p_type in varchar2, p_doc_no in varchar2, p_from_store in varchar2) return varchar2;
  function trt_totals (p_rowid in varchar2, p_what in varchar2) return varchar2;          -- QTY / TOTAL

  -- ------------------------------------------------------------------ ST_TRANSFER_REQUEST
  function trq_doc_warn (p_rowid in varchar2, p_type in varchar2, p_doc_no in varchar2) return varchar2;
  function trq_store_balance (p_rowid in varchar2) return varchar2;                       -- رصيد المستودع per line

  -- ------------------------------------------------------------------ ST_OPEN_BALANCE
  function obl_delete_check (p_rowid in varchar2) return varchar2;
  function obl_totals (p_rowid in varchar2, p_what in varchar2) return varchar2;          -- QTY / COST
  function obl_can_load (p_rowid in varchar2) return varchar2;
  function obl_load_excel (p_rowid in varchar2, p_file in varchar2) return varchar2;
  -- a line with the lot parameters of the legacy line (alphanumeric lot number, expiry date, sales price, discount ratio):
  -- lot found or created by GET_CONFG_ID (the grid column ST_TRNS_DET.LOT_NUMBER is numeric, the legacy item was text)
  function obl_add_line (p_rowid in varchar2, p_item in varchar2, p_unit in number, p_qty in number, p_lot in varchar2,
                         p_expiry in date, p_price in number, p_cost in number, p_disc in number, p_prod in date) return varchar2;

  -- ------------------------------------------------------------------ ST_ADJUST_IN
  function adi_delete_check (p_rowid in varchar2) return varchar2;
  function adi_doc_warn (p_rowid in varchar2, p_type in varchar2, p_doc_no in varchar2) return varchar2;
  function adi_total (p_rowid in varchar2) return varchar2;
  function adi_can_add (p_rowid in varchar2) return varchar2;
  function adi_add_line (p_rowid in varchar2, p_item in varchar2, p_unit in number, p_qty in number, p_lot in varchar2,
                         p_expiry in date, p_price in number, p_cost in number, p_disc in number, p_prod in date) return varchar2;

  -- ------------------------------------------------------------------ ST_ADJUST_OUT
  function ado_delete_check (p_rowid in varchar2) return varchar2;
  function ado_doc_warn (p_rowid in varchar2, p_type in varchar2, p_doc_no in varchar2) return varchar2;
  function ado_total (p_rowid in varchar2) return varchar2;
  function ado_cost_center (p_rowid in varchar2, p_what in varchar2) return varchar2;     -- LIMIT / BALANCE
  function ado_reorder (p_rowid in varchar2) return varchar2;
  -- ================================================================== ST_TAKING / ST_TAKING2 / ST_ITEM_REQ / ST_ITEM_REQ_HANDLE
  -- ================================================================ ST_TAKING / ST_TAKING2 (F5)
  -- p_form 'ST_TAKING'  = count ST_STOCK_TAKING / ST_STOCK_TAKING_DET (store + date)
  --        'ST_TAKING2' = revaluation count ST_STOCK_TAKING_TEMP / ST_STOCK_TAKING_TEMP_DET (store + date + serial)
  function tk_can_fill  (p_rowid in varchar2, p_form in varchar2) return varchar2;   -- 'Y': saved count without lines
  function tk_has_lines (p_rowid in varchar2, p_form in varchar2) return varchar2;   -- 'Y': saved count with lines
  -- "إنزال أصناف المخزن" (DECOMPOSE): one line per item (basic unit) and lot of the store, book balance as quantity
  function tk_decompose (p_rowid in varchar2, p_form in varchar2) return varchar2;
  -- "إنزال تكلفة أصناف الجرد" (CALC_COST): unit cost of every line = book average cost of the lot at the count date
  function tk_calc_cost (p_rowid in varchar2, p_form in varchar2) return varchar2;
  -- ST_TAKING "من ملف" (UPLOAD_EXCEL / LOAD_EXCEL_FILE): from the 2nd row ITEM_CODE, UNIT_CODE, EXPIRE_DATE, LOT_NO, QTY,
  -- SALES_PRICE, DISC_RATIO; the lot is found or created (GET_THE_CONFIG / GET_CONFG_ID_SUPP)
  function tk_load_file (p_rowid in varchar2, p_file in varchar2) return varchar2;
  -- ST_TAKING "CSV" (UPLOAD_CSV / LOAD_CSV_FILE): from the 2nd row ITEM_CONFG_ID, QTY (or one column "lot,qty")
  function tk_load_lots (p_rowid in varchar2, p_file in varchar2) return varchar2;
  -- ST_TAKING after save: sales price and discount of the lot on each line (lot LOV values of the legacy line)
  procedure tk_after_save (p_request in varchar2, p_rowid in varchar2);
  -- info displays: adjustment status (STATUS) and total counted quantity (TOTAL_QTY)
  function tk_status    (p_rowid in varchar2, p_form in varchar2) return varchar2;
  function tk_total_qty (p_rowid in varchar2, p_form in varchar2) return varchar2;

  -- ================================================================ ST_ITEM_REQ / ST_ITEM_REQ_HANDLE (F5)
  function rq_can_fill (p_rowid in varchar2) return varchar2;                        -- 'Y': saved request that takes new lines
  -- "تزويد عام" (GENERAL_REQ / QUAN_BUTTON): items whose balance in the requesting store is below p_quan_limit
  function rq_fill_general (p_rowid in varchar2, p_quan_limit in number, p_from_group in number, p_to_group in number,
                            p_from_item in varchar2, p_to_item in varchar2) return varchar2;
  -- "أصناف حد الطلب" (REC_LIMIT): items of the requesting store whose balance is below ST_STORE_ITEM.REORDER_LIMIT
  function rq_fill_reorder (p_rowid in varchar2, p_from_group in number, p_to_group in number,
                            p_from_item in varchar2, p_to_item in varchar2) return varchar2;
  -- warnings (legacy "continue?" alerts of the line PRE-INSERT): CHK_OUTSTANDING_QTY and CHECK_EST
  function rq_warn_outstanding (p_rowid in varchar2, p_form in varchar2) return varchar2;
  function rq_warn_estimate (p_rowid in varchar2) return varchar2;
  -- delete of a request (after the delete, the page items still hold the keys): refused when converted
  procedure rq_delete_check (p_type in varchar2, p_serial in varchar2);
  -- info displays: number of items, project reference of the requesting store
  function rq_item_count (p_rowid in varchar2) return varchar2;
  function rq_proj_ref (p_rowid in varchar2) return varchar2;

  -- ------------------------------------------------------------------ tests only
  procedure set_test (p_user in number default null);
  procedure set_test_file (p_blob in blob, p_filename in varchar2);
  procedure reset_test;

end app_act_st;
/
show errors package app_act_st

create or replace package body app_act_st as

  g_msg        varchar2(4000);
  g_t_user     number;
  g_t_blob     blob;
  g_t_filename varchar2(400);

  -- declarations of ST_ISSUE_IO / ST_ISSUE_RETURN
  -- =================================================================================== F1 helpers
  -- declarations of ST_SALES_ORDER / ST_PRICE_PROPOSAL
  -- ================================================================== shared by both screens
  type so_t_mark is record (ttype number, tserial number, line number, txid varchar2(100));
  type so_t_marks is table of so_t_mark index by pls_integer;
  so_g_marks so_t_marks;
  -- declarations of ST_RESERVATION / ST_DELIVERY

  -- =================================================================================== F3 helpers
  -- declarations of ST_TRANSFER_FROM / ST_TRANSFER_TO / ST_TRANSFER_REQUEST / ST_OPEN_BALANCE / ST_ADJUST_IN / ST_ADJUST_OUT
  -- =================================================================================== F4 helpers
  -- declarations of ST_TAKING / ST_TAKING2 / ST_ITEM_REQ / ST_ITEM_REQ_HANDLE
  -- ================================================================ ST_TAKING / ST_TAKING2 (F5)
  type tk_hdr is record (store number, tdate date, serial number, found boolean := false);

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
    return to_number(p default null on conversion error);
  end num;

  function dat (p in varchar2) return date is
  begin
    return to_date(p default null on conversion error, 'DD/MM/YYYY');
  end dat;

  function usr return number is
  begin
    return nvl(num(v('G_USER_CODE')), g_t_user);
  end usr;

  function pw return number is
  begin
    return nvl(num(v('G_PASSWORD_NUMBER')), 0);
  end pw;

  function rid (p_rowid in varchar2) return rowid is
  begin
    return chartorowid(p_rowid);
  exception when others then
    return null;
  end rid;

  function last_message return varchar2 is
  begin
    return g_msg;
  end last_message;

  procedure set_message (p_a in varchar2, p_e in varchar2 default null) is
  begin
    g_msg := m(p_a, p_e);
  end set_message;

  procedure get_file (p_name in varchar2, o_blob out blob, o_filename out varchar2) is
  begin
    if g_t_blob is not null then
      o_blob := g_t_blob; o_filename := g_t_filename;
      return;
    end if;
    if p_name is null then
      err(-20190, 'يجب اختيار الملف', 'Please choose the file');
    end if;
    select blob_content, filename into o_blob, o_filename
      from apex_application_temp_files
     where name = p_name;
  exception when no_data_found then
    err(-20190, 'يجب اختيار الملف', 'Please choose the file');
  end get_file;

  procedure set_test (p_user in number default null) is
  begin
    g_t_user := p_user;
  end set_test;

  procedure set_test_file (p_blob in blob, p_filename in varchar2) is
  begin
    g_t_blob := p_blob; g_t_filename := p_filename;
  end set_test_file;

  procedure reset_test is
  begin
    g_t_user := null; g_t_blob := null; g_t_filename := null; g_msg := null;
  end reset_test;

  -- =================================================================================== ST_ISSUE_IO / ST_ISSUE_RETURN
  function si_fmt (p in number) return varchar2 is
  begin
    return case when p is null then null else trim(to_char(p, 'FM999G999G999G990D00')) end;
  end si_fmt;

  function si_mast (p_rowid in varchar2, o_found out boolean) return st_trns_mast%rowtype is
    r st_trns_mast%rowtype;
  begin
    o_found := false;
    if app_act_st.rid(p_rowid) is null then return r; end if;
    select * into r from st_trns_mast where rowid = app_act_st.rid(p_rowid);
    o_found := true;
    return r;
  exception when no_data_found then
    return r;
  end si_mast;

  function si_posted (r in st_trns_mast%rowtype) return boolean is
  begin
    return nvl(r.post_flag, 0) = 1 or nvl(r.cust_post_flag, 0) = 1 or nvl(r.supp_post_flag, 0) = 1;
  end si_posted;

  -- balance of the later movements of a lot without this stock-in line (line KEY-DELREC: GET_BALANCE_CONFG before the line,
  -- UPDATE_NEXT_TRNS_CONFG from it); ST_BASIC.NEG_SALE_BALANCE = 1 allows negative stock
  function sr_next_error (p_store in number, p_group in number, p_item in varchar2, p_confg in number,
                          p_date in date, p_dser in number, p_line in number) return varchar2 is
    l_neg number;
    l_bal number;
  begin
    select nvl(max(neg_sale_balance), 0) into l_neg from st_basic;
    if l_neg <> 0 then return null; end if;
    l_bal := get_balance_confg(p_store, p_group, p_item, p_confg, p_date, p_dser, p_line);
    if update_next_trns_confg(p_store, p_group, p_item, p_confg, p_date, p_dser, p_line, nvl(l_bal, 0)) <> 0 then
      return app_act_st.m('الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها. (الصنف ' || p_item || ' الشحنة ' || p_confg || ')',
                          'Balance Not Enough, There Exist Next Trans. Conflicts With This Trans. (item ' || p_item || ' lot ' || p_confg || ')');
    end if;
    return null;
  end sr_next_error;

  -- =================================================================================== ST_ISSUE_IO
  function si_delete_check (p_rowid in varchar2) return varchar2 is
    r st_trns_mast%rowtype;
    l_found boolean;
  begin
    r := si_mast(p_rowid, l_found);
    if not l_found then
      return app_act_st.m('المستند غير موجود (ربما حذف من مستخدم آخر)', 'The document no longer exists');
    end if;
    if nvl(app_rules_sa.doc_kind(r.trns_type_code), '-') <> 'SI' then
      return app_act_st.m('المستند ليس فاتورة مبيعات', 'The document is not a sales invoice');
    end if;
    if nvl(r.delete_flag, 0) = 1 then
      return app_act_st.m('المستند محذوف بالفعل', 'The document is already deleted');
    end if;
    if nvl(r.print_flag, 0) = 1 then                                          -- CTRL.DEL_BTN
      return app_act_st.m('لايمكن حذف فاتورة مطبوعة', 'You can not delete printed invoice');
    end if;
    if si_posted(r) then                                                     -- CLOSE_POSTED: DELETE_ALLOWED false
      return app_act_st.m('لا يمكن حذف مستند مرحل', 'A posted document cannot be deleted');
    end if;
    return null;
  end si_delete_check;

  procedure si_after_delete (p_rowid in varchar2) is
    r st_trns_mast%rowtype;
    l_found boolean;
  begin
    r := si_mast(p_rowid, l_found);
    if not l_found or nvl(r.delete_flag, 0) <> 1 then return; end if;
    -- POST-UPDATE (DELETE_FLAG = 1)
    update st_sales_order set sl_trns_type_code = null, sl_trns_serial = null
     where sl_trns_type_code = r.trns_type_code and sl_trns_serial = r.trns_serial;
  end si_after_delete;

  function si_can_delete_order (p_rowid in varchar2) return varchar2 is
    r st_trns_mast%rowtype;
    l_found boolean;
    l_n number;
  begin
    r := si_mast(p_rowid, l_found);
    if not l_found or si_delete_check(p_rowid) is not null then return 'N'; end if;
    select count(*) into l_n from st_sales_order where sl_trns_type_code = r.trns_type_code and sl_trns_serial = r.trns_serial;
    return case when l_n > 0 then 'Y' else 'N' end;
  exception when others then
    return 'N';
  end si_can_delete_order;

  function si_delete_with_order (p_rowid in varchar2) return varchar2 is
    r st_trns_mast%rowtype;
    l_found boolean;
    l_msg varchar2(4000);
    l_orders varchar2(4000);
  begin
    l_msg := si_delete_check(p_rowid);
    if l_msg is not null then
      raise_application_error(-20180, l_msg);
    end if;
    r := si_mast(p_rowid, l_found);
    for o in (select trns_type_code, trns_serial from st_sales_order
               where sl_trns_type_code = r.trns_type_code and sl_trns_serial = r.trns_serial) loop
      l_orders := l_orders || case when l_orders is not null then ', ' end || o.trns_type_code || '/' || o.trns_serial;
    end loop;
    -- CTRL.DEL_BTN alert button 3: the sales order lines and header first (errors ignored, as the legacy block did)
    begin
      savepoint si_del_order;
      delete from st_sales_order_det
       where (trns_type_code, trns_serial) in (select trns_type_code, trns_serial from st_sales_order
                                                where sl_trns_type_code = r.trns_type_code and sl_trns_serial = r.trns_serial);
      delete from st_sales_order where sl_trns_type_code = r.trns_type_code and sl_trns_serial = r.trns_serial;
    exception when others then
      rollback to savepoint si_del_order;
      l_orders := null;
    end;
    -- then DO_KEY('DELETE_RECORD'): the legacy soft delete (the lines follow through ST_TRNS_MAST_UP)
    update st_trns_mast set delete_flag = 1, delete_user = app_act_st.usr, delete_date = sysdate
     where rowid = app_act_st.rid(p_rowid);
    si_after_delete(p_rowid);
    app_act_st.set_message('تم حذف الفاتورة ' || r.trns_type_code || '/' || r.trns_serial
                           || case when l_orders is not null then ' وأمر البيع ' || l_orders end,
                           'Invoice ' || r.trns_type_code || '/' || r.trns_serial || ' deleted'
                           || case when l_orders is not null then ' with sales order ' || l_orders end);
    return null;
  end si_delete_with_order;

  function si_info (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    r st_trns_mast%rowtype;
    l_found boolean;
    l_limit number; l_day_no number; l_bal number; l_days number; l_n number;
    l_txt varchar2(4000);
  begin
    r := si_mast(p_rowid, l_found);
    if not l_found then return null; end if;
    if p_what in ('CREDIT_LIMIT', 'BALANCE', 'DAY_NO', 'DAYS', 'STATUS') then
      if r.customer_code is null then return null; end if;
      select nvl(max(credit_limit), 0), nvl(max(day_no), 0) into l_limit, l_day_no from customer where code = r.customer_code;
      if p_what = 'CREDIT_LIMIT' then return si_fmt(l_limit); end if;
      if p_what = 'DAY_NO' then return to_char(l_day_no); end if;
      l_bal := get_customer_bal_all(r.customer_code);
      if p_what = 'BALANCE' then return si_fmt(l_bal); end if;
      l_days := get_customer_days_all(r.customer_code);
      if p_what = 'DAYS' then return to_char(l_days); end if;
      -- CHECK_MAST_STATUS (red / green of CREDIT_LIMIT and DAY_NO), texts of CHECK_CUSTOMER_STATUS
      if l_limit < l_bal or (l_limit < l_bal + nvl(r.tot_val, 0) * nvl(r.currency_rate, 1) and nvl(r.post_flag, 0) = 0) then
        l_txt := app_act_st.m('العميل متعدي الحد الائتماني', 'Customer over the credit limit');
      else
        l_txt := app_act_st.m('ضمن الحد الائتماني', 'Within the credit limit');
      end if;
      if nvl(l_days, 0) > nvl(l_day_no, 0) then
        l_txt := l_txt || ' - ' || app_act_st.m('العميل متعدي فترة السماح', 'Customer over the allowed days');
      else
        l_txt := l_txt || ' - ' || app_act_st.m('ضمن فترة السماح', 'Within the allowed days');
      end if;
      return l_txt;
    elsif p_what = 'ITEMS' then                                 -- GET_PROPOSAL_INFO: ITEMS_COUNT
      select count(*) into l_n from (select group_code, item_code from st_trns_det
                                      where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial
                                      group by group_code, item_code);
      return to_char(l_n);
    elsif p_what = 'DIFF_POLICY' then                           -- lines over the price policy
      select count(*) into l_n
        from st_trns_det p
       where p.trns_type_code = r.trns_type_code and p.trns_serial = r.trns_serial
         and ((p.disc1_ratio > p.org_disc1_ratio or p.disc2_ratio > p.org_disc2_ratio or p.disc3_ratio > p.org_disc3_ratio)
              or (p.group_code, p.item_code) in (select p2.group_code, p2.item_code from st_trns_det p2
                                                  where p2.trns_type_code = p.trns_type_code and p2.trns_serial = p.trns_serial
                                                  group by p2.group_code, p2.item_code
                                                 having sum(p2.bonus) / nullif(sum(p2.quantity), 0) * 100 > max(p2.org_bonus_ratio)
                                                     or sum(p2.extra_bonus) / nullif(sum(p2.quantity), 0) * 100 > max(p2.org_extra_bonus_ratio)));
      return to_char(l_n);
    elsif p_what = 'SALES_LIMIT' then                           -- items above ST_ITEM_UNIT.SALES_LIMIT
      select count(*) into l_n from (select p.group_code, p.item_code from st_trns_det p, st_item_unit u
                                      where p.trns_type_code = r.trns_type_code and p.trns_serial = r.trns_serial
                                        and p.group_code = u.group_code and p.item_code = u.item_code and p.unit_code = u.unit_code
                                        and nvl(u.sales_limit, 0) <> 0 and nvl(p.basic_qty, 0) > nvl(u.sales_limit, 0)
                                      group by p.group_code, p.item_code);
      return to_char(l_n);
    elsif p_what = 'TOTAL' then                                 -- TOTAL_VALUE_CURR: quantity x price of the lines
      select sum(nvl(quantity, 0) * nvl(unit_price_curr, 0)) into l_bal
        from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      return si_fmt(nvl(l_bal, 0));
    elsif p_what = 'NET' then                                   -- NET_VALUE_CURR (= TOT_VAL)
      return si_fmt(r.tot_val);
    end if;
    return null;
  end si_info;

  -- =================================================================================== ST_ISSUE_RETURN
  function sr_delete_check (p_rowid in varchar2) return varchar2 is
    r st_trns_mast%rowtype;
    l_found boolean;
    l_msg varchar2(4000);
  begin
    r := si_mast(p_rowid, l_found);
    if not l_found then
      return app_act_st.m('المستند غير موجود (ربما حذف من مستخدم آخر)', 'The document no longer exists');
    end if;
    if nvl(app_rules_sa.doc_kind(r.trns_type_code), '-') <> 'SR' then
      return app_act_st.m('المستند ليس مرتجع مبيعات', 'The document is not a sales return');
    end if;
    if nvl(r.delete_flag, 0) = 1 then
      return app_act_st.m('المستند محذوف بالفعل', 'The document is already deleted');
    end if;
    if si_posted(r) then                                                     -- header KEY-DELREC
      return app_act_st.m('الفاتورة تم ترحيلها للأنظمة الأخري', 'Invoice Posted To Another Systems');
    end if;
    -- detail KEY-DELREC with MASTER_DELETE = 1, last line first: removing the stock-in must not make a later issue negative
    for d in (select * from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial
               order by item_serial desc) loop
      l_msg := sr_next_error(r.store_code, d.group_code, d.item_code, d.item_confg_id, r.trns_date, r.date_serial, d.item_serial);
      if l_msg is not null then return l_msg; end if;
    end loop;
    return null;
  end sr_delete_check;

  function sr_open (r in st_trns_mast%rowtype) return varchar2 is
  begin
    if nvl(app_rules_sa.doc_kind(r.trns_type_code), '-') <> 'SR' then
      return app_act_st.m('المستند ليس مرتجع مبيعات', 'The document is not a sales return');
    end if;
    if nvl(r.delete_flag, 0) = 1 then
      return app_act_st.m('لا يمكن تعديل مستند ملغي', 'The document is deleted');
    end if;
    if si_posted(r) then
      return app_act_st.m('الفاتورة تم ترحيلها للأنظمة الأخري', 'The document is posted to the other systems');
    end if;
    return null;
  end sr_open;

  function sr_can_decompose (p_rowid in varchar2) return varchar2 is
    r st_trns_mast%rowtype;
    l_found boolean;
    l_n number;
  begin
    r := si_mast(p_rowid, l_found);
    if not l_found or r.ret_trns_serial is null or sr_open(r) is not null then return 'N'; end if;
    -- the button worked only while the item block was empty (GET_BLOCK_PROPERTY('ST_TRNS_DET', STATUS) = 'NEW')
    select count(*) into l_n from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    return case when l_n = 0 then 'Y' else 'N' end;
  exception when others then
    return 'N';
  end sr_can_decompose;

  -- one line through the return row rule (app_rules_sa.trns_det_row2), written while the rule stands aside
  procedure sr_insert_line (r in out nocopy st_trns_det%rowtype) is
  begin
    app_rules_sa.trns_det_row2(true, r.trns_type_code, r.trns_serial, r.item_serial, r.group_code, r.item_code, r.unit_code,
                               r.item_confg_id, r.quantity, r.bonus, r.extra_bonus, r.extra_bonus_ratio, r.basic_qty,
                               r.unit_price_curr, r.unit_price, r.disc1_ratio, r.disc1_value, r.disc2_ratio, r.disc2_value,
                               r.disc3_ratio, r.disc3_value, r.det_disc, r.disc, r.cost_flag, r.unit_cost, r.store_code,
                               r.tax_code1, r.tax_value1, r.auto_disc, r.org_disc1_ratio, r.org_disc2_ratio, r.org_disc3_ratio,
                               r.org_bonus_ratio, r.org_unit_price_curr, r.org_extra_bonus_ratio, r.org_class_code,
                               null, null, null, null, null, null, null);
    if r.item_serial is null then
      select nvl(max(item_serial), 0) + 1 into r.item_serial from st_trns_det
       where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    end if;
    app_rules_sa.set_bypass(true);
    insert into st_trns_det values r;
    app_rules_sa.set_bypass(false);
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end sr_insert_line;

  procedure sr_max_items (r in st_trns_mast%rowtype, p_more in number) is
    l_max number;
    l_n number;
  begin
    select max(trns_max_items) into l_max from st_basic;
    select count(*) into l_n from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    if l_max is not null and l_n + p_more > l_max then
      app_act_st.err(-20181, 'لقد تم إدخال ' || (l_n + p_more) || ' صنف فى هذه الحركة، غير مسموح بالمزيد من الأصناف',
                     ' has been entered ' || (l_n + p_more) || ' Item in this transaction, No more items are allowed ');
    end if;
  end sr_max_items;

  function sr_decompose (p_rowid in varchar2) return varchar2 is
    m st_trns_mast%rowtype;
    l_found boolean;
    l_msg varchar2(4000);
    d st_trns_det%rowtype;
    l_lines number := 0;
    l_srv number := 0;
    l_n number;
    l_cost number; l_units number; l_tcode number; l_tval number;
  begin
    m := si_mast(p_rowid, l_found);
    if not l_found then
      app_act_st.err(-20182, 'المستند غير موجود (ربما حذف من مستخدم آخر)', 'The document no longer exists');
    end if;
    l_msg := sr_open(m);
    if l_msg is not null then raise_application_error(-20182, l_msg); end if;
    if m.ret_trns_serial is null then
      app_act_st.err(-20182, 'إنزال أصناف الفاتورة متاح فقط للمرتجع على فاتورة', 'Only a return with an invoice can load the invoice items');
    end if;
    select count(*) into l_n from st_trns_det where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial;
    if l_n > 0 then
      app_act_st.err(-20182, 'تم إدخال أصناف في المرتجع: إنزال أصناف الفاتورة متاح فقط لمرتجع بدون أصناف',
                     'The return already has items: the invoice items can only be loaded into an empty return');
    end if;
    -- DECOMPOSE_INVOICE_DET: every invoice lot still to return (sold - returned on all live returns of the invoice), the
    -- quantity, bonus and extra bonus left; price / discounts / unit / line serial come from the invoice line (row rule)
    for c in (select i.group_code, i.item_code, i.item_confg_id, min(i.item_serial) first_serial,
                     sum(nvl(i.quantity, 0)) org_q, sum(nvl(i.bonus, 0)) org_b, sum(nvl(i.extra_bonus, 0)) org_e,
                     (select nvl(sum(nvl(rd.quantity, 0)), 0) from st_trns_mast rm, st_trns_det rd
                       where rm.trns_type_code = rd.trns_type_code and rm.trns_serial = rd.trns_serial
                         and rm.ret_trns_type_code = m.ret_trns_type_code and rm.ret_trns_serial = m.ret_trns_serial
                         and rd.item_confg_id = i.item_confg_id and rd.item_code = i.item_code
                         and nvl(rm.delete_flag, 0) = 0 and nvl(rd.delete_flag, 0) = 0) ret_q,
                     (select nvl(sum(nvl(rd.bonus, 0)), 0) from st_trns_mast rm, st_trns_det rd
                       where rm.trns_type_code = rd.trns_type_code and rm.trns_serial = rd.trns_serial
                         and rm.ret_trns_type_code = m.ret_trns_type_code and rm.ret_trns_serial = m.ret_trns_serial
                         and rd.item_confg_id = i.item_confg_id and rd.item_code = i.item_code
                         and nvl(rm.delete_flag, 0) = 0 and nvl(rd.delete_flag, 0) = 0) ret_b,
                     (select nvl(sum(nvl(rd.extra_bonus, 0)), 0) from st_trns_mast rm, st_trns_det rd
                       where rm.trns_type_code = rd.trns_type_code and rm.trns_serial = rd.trns_serial
                         and rm.ret_trns_type_code = m.ret_trns_type_code and rm.ret_trns_serial = m.ret_trns_serial
                         and rd.item_confg_id = i.item_confg_id and rd.item_code = i.item_code
                         and nvl(rm.delete_flag, 0) = 0 and nvl(rd.delete_flag, 0) = 0) ret_e
                from st_trns_det i
               where i.trns_type_code = m.ret_trns_type_code and i.trns_serial = m.ret_trns_serial
                 and nvl(i.delete_flag, 0) = 0
               group by i.group_code, i.item_code, i.item_confg_id
               order by i.item_code, min(i.item_serial)) loop
      if (c.org_q + c.org_b + c.org_e) > (c.ret_q + c.ret_b + c.ret_e) then
        d := null;
        d.trns_type_code := m.trns_type_code; d.trns_serial := m.trns_serial;
        d.group_code := c.group_code; d.item_code := c.item_code; d.item_confg_id := c.item_confg_id;
        d.quantity := greatest(c.org_q - c.ret_q, 0);
        d.bonus := greatest(c.org_b - c.ret_b, 0);
        d.extra_bonus := greatest(c.org_e - c.ret_e, 0);
        d.trns_date := m.trns_date; d.date_serial := m.date_serial; d.delete_flag := 0;
        d.freight := 0; d.customs := 0; d.transport := 0; d.insurance := 0; d.commission := 0; d.others := 0;
        sr_insert_line(d);
        l_lines := l_lines + 1;
      end if;
    end loop;
    sr_max_items(m, 0);
    -- DECOMPOSE_INVOICE_SERVICE: the invoice services (SERVICE_COST := invoice cost / rate, as the legacy)
    for s in (select * from st_trns_services
               where trns_type_code = m.ret_trns_type_code and trns_serial = m.ret_trns_serial
                 and service_serial not in (select service_serial from st_trns_services
                                             where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial)
               order by service_serial) loop
      l_cost := s.service_cost / nvl(m.currency_rate, 1); l_units := s.units_no; l_tcode := null; l_tval := null;
      app_rules_sa.trns_srv_row(true, m.trns_type_code, m.trns_serial, s.service_code, l_cost, l_units, l_tcode, l_tval);
      app_rules_sa.set_bypass(true);
      insert into st_trns_services (trns_type_code, trns_serial, service_serial, service_code, service_cost, units_no, tax_code1, tax_value1)
      values (m.trns_type_code, m.trns_serial, s.service_serial, s.service_code, l_cost, l_units, l_tcode, l_tval);
      app_rules_sa.set_bypass(false);
      l_srv := l_srv + 1;
    end loop;
    if l_lines + l_srv = 0 then
      app_act_st.err(-20182, 'لا توجد أصناف متبقية للارتجاع في الفاتورة ' || m.ret_trns_type_code || '\' || m.ret_trns_serial,
                     'Nothing left to return on invoice ' || m.ret_trns_type_code || '\' || m.ret_trns_serial);
    end if;
    app_act_st.set_message('تم إنزال ' || l_lines || ' صنف' || case when l_srv > 0 then ' و ' || l_srv || ' خدمة' end
                           || ' من الفاتورة ' || m.ret_trns_type_code || '\' || m.ret_trns_serial,
                           l_lines || ' item(s)' || case when l_srv > 0 then ' and ' || l_srv || ' service(s)' end
                           || ' loaded from invoice ' || m.ret_trns_type_code || '\' || m.ret_trns_serial);
    return p_rowid;
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end sr_decompose;

  function sr_can_old_lot (p_rowid in varchar2) return varchar2 is
    r st_trns_mast%rowtype;
    l_found boolean;
  begin
    r := si_mast(p_rowid, l_found);
    if not l_found or r.ret_trns_serial is not null or sr_open(r) is not null then return 'N'; end if;
    return 'Y';
  exception when others then
    return 'N';
  end sr_can_old_lot;

  -- GET_THE_CONFIG: the lot of the returned "old lot" (found or created by GET_CONFG_ID with the lot number / expiry of the
  -- line), one formation IN line in the first live header of the first AUTO_TRNS type EFFECT 1 / TRNS_TYPE 7 of the store
  -- (904) and one OUT line in the first header of the first AUTO_TRNS type EFFECT 2 / TRNS_TYPE 7 (901), quantity 1 each
  function sr_the_config (m in st_trns_mast%rowtype, p_group in number, p_item in varchar2, p_unit in number,
                          p_price in number, p_lot_number in varchar2, p_expire_date in date, p_disc1 in number,
                          p_unit_cost in number) return number is
    l_in_type number; l_out_type number; l_in_serial number; l_out_serial number; l_n number;
    l_exp_flag number; l_col_flag number; l_size_flag number;
    l_supplier number; l_retail number; l_iu_cost number;
    l_confg number;
    l_lot varchar2(100) := p_lot_number;
    l_date date; l_dser number; l_serial number;
  begin
    select min(trns_type_code) into l_in_type from st_trns_type where nvl(auto_trns, 0) = 1 and effect = 1 and trns_type = 7;
    select min(trns_type_code) into l_out_type from st_trns_type where nvl(auto_trns, 0) = 1 and effect = 2 and trns_type = 7;
    if l_in_type is null or l_out_type is null then
      app_act_st.err(-20183, 'خطأ بمؤشرات النظام', 'System Parameter Error');
    end if;
    select count(*), min(trns_serial) into l_n, l_in_serial from st_trns_mast
     where trns_type_code = l_in_type and store_code = m.store_code and nvl(delete_flag, 0) = 0;
    if l_n = 0 then
      app_act_st.err(-20183, 'وارد خطأ بمؤشرات النظام', 'Income System Parameter Error');
    end if;
    -- (the legacy tested the IN count again here, then failed on the insert without an OUT header)
    select min(trns_serial) into l_out_serial from st_trns_mast
     where trns_type_code = l_out_type and store_code = m.store_code and nvl(delete_flag, 0) = 0;
    if l_out_serial is null then
      app_act_st.err(-20183, 'صادر خطأ بمؤشرات النظام', 'Outcome System Parameter Error');
    end if;
    begin
      select nvl(expire_flag, 0), nvl(color_flag, 0), nvl(size_flag, 0) into l_exp_flag, l_col_flag, l_size_flag
        from st_item_group where item_group_code = p_group;
    exception when no_data_found then
      l_exp_flag := 0; l_col_flag := 0; l_size_flag := 0;
    end;
    begin
      select i.supplier, u.retail_sale_price, u.iu_unit_cost into l_supplier, l_retail, l_iu_cost
        from st_item i, st_item_unit u
       where i.item_group_code = p_group and i.item_code = p_item
         and u.group_code = i.item_group_code and u.item_code = i.item_code and u.unit_code = p_unit;
    exception when no_data_found then
      l_supplier := null; l_retail := 0; l_iu_cost := 0;
    end;
    -- SET_LOT_REQ(1): UNIT_COST required (defaulted to IU_UNIT_COST by ITEM_CONFG_ID WHEN-VALIDATE-ITEM)
    if nvl(p_unit_cost, l_iu_cost) is null then
      app_act_st.err(-20183, 'يجب إدخال تكلفة الوحدة للشحنة القديمة (لا توجد تكلفة في ملف الأصناف)',
                     'Enter the unit cost of the old lot (the item has no cost)');
    end if;
    -- the colour / size of the line are not on the page (ST_BASIC.COLOR_FLAG = SIZE_FLAG = 0 here): passed empty
    l_confg := get_confg_id(p_item, p_group, l_supplier, p_price, l_lot, case when l_exp_flag = 1 then p_expire_date end,
                            nvl(p_disc1, 0), m.store_code, true, null, null);
    if nvl(l_confg, 0) in (0, -1) then
      app_act_st.err(-20183, 'خطأ بمحددات الشحنة', 'Error in ASCON Confg ID');
    end if;
    -- formation IN line (COST_FLAG 0, price = line price) and OUT line (COST_FLAG 1, price = cost)
    select trns_date, date_serial into l_date, l_dser from st_trns_mast where trns_type_code = l_in_type and trns_serial = l_in_serial;
    select nvl(max(nvl(item_serial, 0)), 0) + 1 into l_serial from st_trns_det where trns_type_code = l_in_type and trns_serial = l_in_serial;
    app_rules_sa.set_bypass(true);
    insert into st_trns_det (item_serial, quantity, unit_cost, unit_price, basic_qty, cost_flag, trns_type_code, trns_serial,
                             unit_code, group_code, item_code, store_code, item_confg_id, trns_date, date_serial, delete_flag, sales_price)
    values (l_serial, 1, nvl(p_unit_cost, l_iu_cost), p_price, 1, 0, l_in_type, l_in_serial,
            p_unit, p_group, p_item, m.store_code, l_confg, l_date, l_dser, 0, l_retail);
    select trns_date, date_serial into l_date, l_dser from st_trns_mast where trns_type_code = l_out_type and trns_serial = l_out_serial;
    select nvl(max(nvl(item_serial, 0)), 0) + 1 into l_serial from st_trns_det where trns_type_code = l_out_type and trns_serial = l_out_serial;
    insert into st_trns_det (item_serial, quantity, unit_cost, unit_price, basic_qty, cost_flag, trns_type_code, trns_serial,
                             unit_code, group_code, item_code, store_code, item_confg_id, trns_date, date_serial, delete_flag, sales_price)
    values (l_serial, 1, nvl(p_unit_cost, l_iu_cost), nvl(p_unit_cost, l_iu_cost), 1, 1, l_out_type, l_out_serial,
            p_unit, p_group, p_item, m.store_code, l_confg, l_date, l_dser, 0, l_retail);
    app_rules_sa.set_bypass(false);
    return l_confg;
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end sr_the_config;

  function sr_old_lot (p_rowid in varchar2, p_item in varchar2, p_unit in number, p_qty in number, p_bonus in number,
                       p_lot_number in varchar2, p_expire_date in date, p_unit_cost in number, p_price in number,
                       p_disc1 in number) return varchar2 is
    m st_trns_mast%rowtype;
    l_found boolean;
    l_msg varchar2(4000);
    l_group number; l_item varchar2(30); l_unit number; l_n number;
    l_price_curr number; l_disc1 number;
    d st_trns_det%rowtype;
    l_single number;
  begin
    m := si_mast(p_rowid, l_found);
    if not l_found then
      app_act_st.err(-20184, 'المستند غير موجود (ربما حذف من مستخدم آخر)', 'The document no longer exists');
    end if;
    l_msg := sr_open(m);
    if l_msg is not null then raise_application_error(-20184, l_msg); end if;
    if m.ret_trns_serial is not null then                          -- CONFG_RG: the -1 row only without invoice
      app_act_st.err(-20184, 'الشحنة القديمة متاحة فقط في المرتجع بدون فاتورة', 'An old lot is only possible in a return without invoice');
    end if;
    -- item (ITEM_CODE WHEN-VALIDATE-ITEM: item code, else the unit's international code), basic unit by default
    begin
      select item_group_code, item_code into l_group, l_item from st_item where item_code = trim(p_item) and nvl(stop_flag, 0) = 0;
    exception when no_data_found then
      begin
        select i.item_group_code, i.item_code into l_group, l_item from st_item i, st_item_unit u
         where i.item_code = u.item_code and i.item_group_code = u.group_code and nvl(i.stop_flag, 0) = 0
           and u.inter_code = trim(p_item) and nvl(u.basic_unit, 0) = 1;
      exception when no_data_found then
        app_act_st.err(-20184, 'صنف غير موجود', 'Item doesn''t exist');
      when too_many_rows then
        app_act_st.err(-20184, 'صنف مكرر', 'Repeated item');
      end;
    when too_many_rows then
      app_act_st.err(-20184, 'صنف مكرر', 'Repeated item');
    end;
    l_unit := p_unit;
    if l_unit is null then
      select min(unit_code) keep (dense_rank first order by case when nvl(basic_unit, 0) = 1 then 0 else 1 end, unit_code)
        into l_unit from st_item_unit where group_code = l_group and item_code = l_item;
    end if;
    select count(*) into l_n from st_item_unit where group_code = l_group and item_code = l_item and unit_code = l_unit;
    if l_n = 0 then
      app_act_st.err(-20184, 'يجب ادخال الوحدة', 'Must Enter Unit');
    end if;
    -- SET_LOT_REQ(1): lot number and expiry date required
    if trim(p_lot_number) is null or p_expire_date is null then
      app_act_st.err(-20184, 'يجب إدخال رقم الشحنة وتاريخ الصلاحية للشحنة القديمة', 'Enter the lot number and the expiry date of the old lot');
    end if;
    if nvl(p_qty, 0) + nvl(p_bonus, 0) <= 0 or nvl(p_qty, 0) < 0 or nvl(p_bonus, 0) < 0 then
      app_act_st.err(-20184, 'القيمة يجب أن تكون أكبر من أو تســاوى صفر', 'Value Must Be More Than or Equal Zero');
    end if;
    if p_price is not null and p_price < 0 then
      app_act_st.err(-20184, 'السعر يجب أن تكون أكبر من صفر', 'Price Must Be More Than Zero');
    end if;
    if p_unit_cost is not null and p_unit_cost < 0 then
      app_act_st.err(-20184, 'تكلفة الوحدة يجب أن تكون أكبر من صفر', 'Unit cost must not be negative');
    end if;
    -- WHEN-NEW-ITEM-INSTANCE of the lines: TRNS_MAX_ITEMS / SINGLE_ITEM
    sr_max_items(m, 1);
    select nvl(max(single_item), 0) into l_single from st_basic;
    if l_single = 1 then
      select count(*) into l_n from st_trns_det where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial
         and group_code = l_group and item_code = l_item;
      if l_n > 0 then
        app_act_st.err(-20184, 'غير مسموح بتكرار الصنف', 'REPEAETING ITEMS IS NOT ALLOWD');
      end if;
    end if;
    -- default price of a return without invoice (ITEM_CODE / UNIT_CODE WHEN-VALIDATE-ITEM) and DISC1 = ST_ITEM.MOH_DISC
    l_price_curr := p_price;
    if l_price_curr is null then
      select max(case when iu.reduction_price is not null then iu.reduction_price
                      when s.deal_type = 1 then iu.wide_sale_price
                      else iu.retail_sale_price end)
        into l_price_curr
        from st_item_unit iu, st_store s
       where iu.group_code = l_group and iu.item_code = l_item and iu.unit_code = l_unit and s.store_code = m.store_code;
      l_price_curr := round(nvl(l_price_curr, 0) / nvl(m.currency_rate, 1), 2);
    end if;
    l_disc1 := p_disc1;
    if l_disc1 is null then
      select max(moh_disc) into l_disc1 from st_item where item_group_code = l_group and item_code = l_item;
    end if;
    -- PRE-INSERT: GET_THE_CONFIG with :UNIT_PRICE (local currency), then the line
    d := null;
    d.item_confg_id := sr_the_config(m, l_group, l_item, l_unit, l_price_curr * nvl(m.currency_rate, 1), p_lot_number,
                                     p_expire_date, l_disc1, p_unit_cost);
    d.trns_type_code := m.trns_type_code; d.trns_serial := m.trns_serial;
    select nvl(max(item_serial), 0) + 1 into d.item_serial from st_trns_det
     where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial;
    d.group_code := l_group; d.item_code := l_item; d.unit_code := l_unit;
    d.quantity := nvl(p_qty, 0); d.bonus := nvl(p_bonus, 0); d.extra_bonus := 0;
    d.unit_price_curr := l_price_curr; d.disc1_ratio := l_disc1;
    d.trns_date := m.trns_date; d.date_serial := m.date_serial; d.delete_flag := 0;
    d.freight := 0; d.customs := 0; d.transport := 0; d.insurance := 0; d.commission := 0; d.others := 0;
    sr_insert_line(d);
    app_act_st.set_message('تم إدخال الصنف ' || l_item || ' بالشحنة ' || d.item_confg_id || ' (رقم التشغيلة ' || trim(p_lot_number) || ')',
                           'Item ' || l_item || ' entered with lot ' || d.item_confg_id || ' (lot number ' || trim(p_lot_number) || ')');
    return p_rowid;
  end sr_old_lot;

  function sr_validate_extra (p_rowid in varchar2, p_print_flag in varchar2) return varchar2 is
    r st_trns_mast%rowtype;
    l_found boolean;
    l_flag number := nvl(app_act_st.num(p_print_flag), 0);
  begin
    if nvl(app_act_st.usr, 0) = 0 then return null; end if;
    r := si_mast(p_rowid, l_found);
    if (not l_found and l_flag <> 0) or (l_found and l_flag <> nvl(r.print_flag, 0)) then
      return app_act_st.m('مؤشر الطباعة يعدله المستخدم 0 فقط', 'Only user 0 can change the print flag');
    end if;
    return null;
  end sr_validate_extra;

  function sr_info (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    r st_trns_mast%rowtype;
    l_found boolean;
    l_limit number; l_bal number; l_d date;
    l_txt varchar2(4000);
    l_max number; l_show number; l_cur number; l_wide number; l_factor number; l_uname varchar2(200);
  begin
    r := si_mast(p_rowid, l_found);
    if not l_found then return null; end if;
    if p_what = 'CREDIT' then
      -- POST-QUERY / INVOICE_NO WHEN-VALIDATE-ITEM: CREDIT_LIMIT - customer balance of AR_MAINTRNS
      if r.customer_code is null then return null; end if;
      select nvl(max(credit_limit), 0) into l_limit from customer where code = r.customer_code;
      select nvl(sum(decode(att.effect, 0, (a.total_value * a.currency_rate), 1, -1 * ((a.total_value + a.disc_value) * a.currency_rate))), 0)
        into l_bal from ar_maintrns a, ar_trnstype att where a.customer_id = r.customer_code and a.trns_id = att.id;
      return si_fmt(l_limit - l_bal);
    elsif p_what = 'INV_DATE' then                              -- POST-QUERY: INV_TRNS_DATE
      if r.ret_trns_serial is null then return null; end if;
      select max(trns_date) into l_d from st_trns_mast where trns_type_code = r.ret_trns_type_code and trns_serial = r.ret_trns_serial;
      return to_char(l_d, 'DD/MM/YYYY');
    elsif p_what = 'NOTICES' then
      -- QUANTITY / BONUS / EXTRA_BONUS WHEN-VALIDATE-ITEM (MSG level 0): the store maximum (ST_STORE_ITEM.MAX_LIMIT, 0 = none);
      -- UNIT_PRICE_CURR WHEN-VALIDATE-ITEM of a return without invoice: price below the wholesale price
      select nvl(max(allow_view_balance), 0) into l_show from users where users_code = nvl(app_act_st.usr, 0);
      for d in (select * from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial order by item_serial) loop
        select nvl(max(decode(nvl(max_limit, 0), 0, 999999999, max_limit)), 999999999) into l_max
          from st_store_item where item_code = d.item_code and group_code = d.group_code and store_code = r.store_code;
        select nvl(max(factor), 1), max(wide_sale_price) into l_factor, l_wide
          from st_item_unit where group_code = d.group_code and item_code = d.item_code and unit_code = d.unit_code;
        select max(decode(app_act_st.m('a', 'e'), 'e', name_e, name_a)) into l_uname from st_unit where unit_code = d.unit_code;
        l_cur := case when l_show = 1 then round(nvl(get_balance_confg(r.store_code, d.group_code, d.item_code, d.item_confg_id,
                                                                       r.trns_date, r.date_serial, d.item_serial), 0) / l_factor, 2) end;
        if nvl(d.bonus, 0) + nvl(d.quantity, 0) + nvl(d.extra_bonus, 0) + nvl(l_cur, 0) > l_max
           and nvl(d.bonus, 0) + nvl(d.quantity, 0) + nvl(d.extra_bonus, 0) > 0 then
          l_txt := l_txt || case when l_txt is not null then chr(10) end || d.item_code || ': '
                   || app_act_st.m('!!رصيد الصنف سوف يزيد عن الحـد الأقصي - الحد الأقصى هو  = ' || l_max || ' ' || l_uname,
                                   'Item Balance Will Be More Than Max Limit!! Max Limit is = ' || l_max || ' ' || l_uname);
        end if;
        if r.ret_trns_serial is null and nvl(l_wide, 0) / nvl(r.currency_rate, 1) <> 0 and nvl(d.unit_price_curr, 0) <> 0
           and l_wide / nvl(r.currency_rate, 1) > d.unit_price_curr then
          l_txt := l_txt || case when l_txt is not null then chr(10) end || d.item_code || ': '
                   || app_act_st.m('يجب ان لا يقل سعر الصنف عن سعر الجملة', 'The item price has to be more than the whole price');
        end if;
      end loop;
      return l_txt;
    elsif p_what = 'TOTAL' then                                 -- net of the return lines (GET_LINE_TOTAL)
      select sum(round(nvl(quantity, 0) * (nvl(unit_price, 0) - (nvl(disc1_value, 0) + nvl(disc2_value, 0) + nvl(disc3_value, 0)))
                       - nvl(det_disc, 0), 2)) into l_bal
        from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      return si_fmt(nvl(l_bal, 0));
    end if;
    return null;
  end sr_info;
  -- =================================================================================== ST_SALES_ORDER / ST_PRICE_PROPOSAL
  function so_fmt (p in number) return varchar2 is
  begin
    return to_char(p, 'FM999G999G999G990D00');
  end so_fmt;

  function so_user_flag (p_col in varchar2) return number is
    l number;
  begin
    execute immediate 'select nvl(max(' || dbms_assert.simple_sql_name(p_col) || '), 0) from users where users_code = :u'
      into l using app_act_st.usr;
    return l;
  exception when others then
    return 0;
  end so_user_flag;

  -- CUSTOMER credit fields of the legacy POST-QUERY: CREDIT_LIMIT, DAY_NO, CRN_BAL_TOTAL, CRN_DAY_TOTAL
  procedure so_credit (p_customer in number, o_limit out number, o_days_allowed out number, o_bal out number, o_days out number) is
  begin
    select nvl(max(credit_limit), 0), nvl(max(day_no), 0) into o_limit, o_days_allowed from customer where code = p_customer;
    o_bal := get_customer_bal_all(p_customer);
    o_days := get_customer_days_all(p_customer);
  exception when others then
    null;
  end so_credit;

  -- net value after discounts and VAT (NET_VALUE_CURR) of an order / quotation, in the document currency
  function so_net (p_table in varchar2, p_type in number, p_serial in number, p_chosen in boolean default false) return number is
    l_tot number; l_tax number; l_hd number; l_ht number; l_tr number; l_rate number;
    l_ch  number := case when p_chosen then 1 else 0 end;
  begin
    if p_table = 'SO' then
      select nvl(sum((nvl(unit_price, 0) - (nvl(disc1_value, 0) + nvl(disc2_value, 0) + nvl(disc3_value, 0))) * nvl(quantity, 0)), 0),
             nvl(sum(tax_value1), 0)
        into l_tot, l_tax from st_sales_order_det where trns_type_code = p_type and trns_serial = p_serial;
      select nvl(disc_val, 0) + nvl(tot_disc1_value, 0) + nvl(tot_disc2_value, 0) + nvl(tot_disc3_value, 0), nvl(tax_value1, 0),
             nvl(trnsport_val, 0), nvl(currency_rate, 1)
        into l_hd, l_ht, l_tr, l_rate from st_sales_order where trns_type_code = p_type and trns_serial = p_serial;
    else
      select nvl(sum((nvl(unit_price, 0) - (nvl(disc1_value, 0) + nvl(disc2_value, 0) + nvl(disc3_value, 0))) * nvl(quantity, 0)), 0),
             nvl(sum(tax_value1), 0)
        into l_tot, l_tax from st_proposal_det
       where trns_type_code = p_type and trns_serial = p_serial
         and (l_ch = 0 or (nvl(choice_flag, 0) = 1 and nvl(delete_flag, 0) = 0));
      select nvl(case when l_ch = 1 then 0 else disc_val end, 0) + nvl(tot_disc1_value, 0) + nvl(tot_disc2_value, 0)
             + nvl(tot_disc3_value, 0), nvl(tax_value1, 0), nvl(trnsport_val, 0), nvl(currency_rate, 1)
        into l_hd, l_ht, l_tr, l_rate from st_proposal_mast where trns_type_code = p_type and trns_serial = p_serial;
    end if;
    return (l_tot - l_hd + l_tr + l_tax + l_ht) / l_rate;
  end so_net;

  -- ================================================================== ST_SALES_ORDER
  function so_can (p_what in varchar2, p_rowid in varchar2) return varchar2 is
    so st_sales_order%rowtype;
  begin
    select * into so from st_sales_order where rowid = app_act_st.rid(p_rowid);
    -- ENABLE_DISABLE_BUTTONS: CLOSE_SALES_ORDER while open, CANCEL_CLOSE while closed; CANCEL toggles DELETE_DATE
    return case
             when p_what = 'CLOSE' and nvl(so.closed, 0) <> 1 and so.delete_date is null then 'Y'
             when p_what = 'REOPEN' and nvl(so.closed, 0) = 1 and so.delete_date is null then 'Y'
             when p_what = 'CANCEL' and so.delete_date is null then 'Y'
             when p_what = 'ACTIVATE' and so.delete_date is not null then 'Y'
             else 'N' end;
  exception when others then
    return 'N';
  end so_can;

  function so_lock (p_rowid in varchar2) return st_sales_order%rowtype is
    so    st_sales_order%rowtype;
    l_rid rowid := app_act_st.rid(p_rowid);
  begin
    select * into so from st_sales_order where rowid = l_rid for update wait 10;
    return so;
  exception when no_data_found then
    app_act_st.err(-20181, 'أمر البيع غير موجود (ربما حذف من مستخدم آخر)', 'The sales order no longer exists');
  end so_lock;

  -- CLOSE_SALES_ORDER
  function so_close (p_rowid in varchar2) return varchar2 is
    so st_sales_order%rowtype := so_lock(p_rowid);
  begin
    if so.closed = 1 then
      app_act_st.err(-20181, 'امر البيع مقفل بالفعل', 'sales order was closed  ');
    end if;
    update st_sales_order set closed = 1 where rowid = app_act_st.rid(p_rowid);
    app_act_st.set_message('تم اقفال أمر البيع', 'Sales Order Closed');
    return p_rowid;
  end so_close;

  -- CANCEL_CLOSE
  function so_reopen (p_rowid in varchar2) return varchar2 is
    so st_sales_order%rowtype := so_lock(p_rowid);
  begin
    if so.closed = 0 then
      app_act_st.err(-20181, 'امر البيع مفتوح بالفعل', 'sales order was open  ');
    end if;
    update st_sales_order set closed = 0 where rowid = app_act_st.rid(p_rowid);
    app_act_st.set_message('تم فتح أمر البيع', 'Sales Order opened');
    return p_rowid;
  end so_reopen;

  -- CANCEL: refused once invoiced, once a purchase order was made from it, and for approved or closed orders; then DELETE_DATE /
  -- DELETE_USER are set (cancel) or cleared (activate)
  function so_cancel (p_rowid in varchar2, p_activate in number default 0) return varchar2 is
    so  st_sales_order%rowtype := so_lock(p_rowid);
    l_n number;
  begin
    if nvl(p_activate, 0) = 1 and so.delete_date is null then
      app_act_st.err(-20181, 'أمر البيع غير ملغي', 'The sales order is not cancelled');
    elsif nvl(p_activate, 0) = 0 and so.delete_date is not null then
      app_act_st.err(-20181, 'أمر البيع ملغي', 'The sales order is cancelled');
    end if;
    select count(*) into l_n from st_trns_mast m
     where nvl(m.delete_flag, 0) = 0 and m.order_trns_type_code = so.trns_type_code and m.order_trns_serial = so.trns_serial;
    if l_n <> 0 then
      app_act_st.err(-20181, 'تم عمل فاتورة مبيعات', 'RFQ Posted To Issue Trns');
    end if;
    select count(*) into l_n from pr_order_det where sl_trns_type_code = so.trns_type_code and sl_trns_serial = so.trns_serial;
    if l_n <> 0 then
      app_act_st.err(-20181, 'تم عمل امر شراء', 'RFQ Posted To Po Order Trns');
    end if;
    if so.approved = 1 or so.closed = 1 then
      app_act_st.err(-20181, 'لا يمكن إلغاء أمر بيع معتمد أو مغلق', 'Cannot cancel closed or approved sales oerder.');
    end if;
    if so.delete_date is null then
      update st_sales_order set delete_date = sysdate, delete_user = app_act_st.usr where rowid = app_act_st.rid(p_rowid);
      app_act_st.set_message('تم إلغاء أمر البيع', 'Sales Order Cancelled.');
    else
      update st_sales_order set delete_date = null, delete_user = null where rowid = app_act_st.rid(p_rowid);
      app_act_st.set_message('تم تنشيط أمر البيع', 'Sales Order Activated.');
    end if;
    return p_rowid;
  end so_cancel;

  function so_txid return varchar2 is
  begin
    return nvl(dbms_transaction.local_transaction_id, '-');
  end so_txid;

  procedure so_mark_auto_lot (p_type in number, p_serial in number, p_line in number) is
    k pls_integer := so_g_marks.count + 1;
  begin
    so_g_marks(k).ttype := p_type;
    so_g_marks(k).tserial := p_serial;
    so_g_marks(k).line := p_line;
    so_g_marks(k).txid := so_txid;
  end so_mark_auto_lot;

  -- one line of the order written after DEVIDE_CONFGS: BASIC_QTY (PRE-INSERT / PRE-UPDATE), UNIT_PRICE and VAT (GET_TAX_DET)
  procedure so_line_values (so in st_sales_order%rowtype, d in out nocopy st_sales_order_det%rowtype, p_factor in number) is
  begin
    d.basic_qty := (nvl(d.bonus, 0) + nvl(d.extra_bonus, 0) + nvl(d.quantity, 0)) * p_factor;
    d.unit_price := nvl(d.unit_price_curr, 0) * nvl(so.currency_rate, 1);
    app_rules_sa.line_tax(d.item_group_code, d.item_code, so.customer_code, null, so.order_date,
                          round(d.basic_qty * (nvl(d.unit_price_curr, 0) - (nvl(d.disc1_value, 0) + nvl(d.disc2_value, 0)
                                                                              + nvl(d.disc3_value, 0)) * nvl(so.currency_rate, 1))),
                          d.tax_code1, d.tax_value1);
  end so_line_values;

  -- DEVIDE_CONFGS of one line (KEY-NEXT-ITEM of TEMP_QUANTITY with AUTO_DISC, or of BONUS for a bonus-only line, lot empty)
  procedure so_split_line (so in st_sales_order%rowtype, p_line in number) is
    d        st_sales_order_det%rowtype;
    n        st_sales_order_det%rowtype;
    f        number;
    l_all    number;
    l_bonus  number;
    l_extra  number;
    l_rbonus number;
    l_rextra number;
    l_begin  number;
    l_tot    number := 0;
    l_bal    number;
    l_b      number;
    l_e      number;
    i        pls_integer := 1;
    l_neg    number;
    l_unit   varchar2(200);
    l_last   rowid;
  begin
    begin
      select * into d from st_sales_order_det where trns_type_code = so.trns_type_code and trns_serial = so.trns_serial and serial = p_line;
    exception when no_data_found then
      return;
    end;
    if not ((nvl(d.auto_disc, 0) = 1 and nvl(d.temp_quantity, 0) <> 0)
            or (nvl(d.auto_disc, 0) = 0 and nvl(d.temp_quantity, 0) = 0 and nvl(d.bonus, 0) <> 0)) then
      return;
    end if;
    select nvl(max(factor), 1) into f from st_item_unit where group_code = d.item_group_code and item_code = d.item_code and unit_code = d.unit_code;
    l_all := nvl(d.quantity, 0) * f;
    l_begin := l_all;
    l_bonus := nvl(d.bonus, 0) * f;   l_rbonus := l_bonus;
    l_extra := nvl(d.extra_bonus, 0) * f;   l_rextra := l_extra;
    select rowid into l_last from st_sales_order_det where trns_type_code = d.trns_type_code and trns_serial = d.trns_serial and serial = d.serial;
    for c in (select item_confg_id, expire_date from st_item_confg
               where group_code = d.item_group_code and item_code = d.item_code
               order by expire_date, item_confg_id) loop
      l_bal := nvl(get_min_balance_confg_after(so.store_code, d.item_group_code, d.item_code, c.item_confg_id, so.order_date, null, d.serial), 0);
      if l_bal > 0 then
        if i = 1 then
          d.item_confg_id := c.item_confg_id;
          if l_bal >= l_all + l_bonus + l_extra then
            update st_sales_order_det set item_confg_id = d.item_confg_id where rowid = l_last;
            l_tot := l_tot + nvl(d.basic_qty, 0);
            exit;
          end if;
          if l_bal < l_all then
            d.bonus := 0; d.bonus_ratio := 0; d.extra_bonus := 0; d.extra_bonus_ratio := 0;
            d.temp_quantity := l_bal / f; d.quantity := l_bal / f;
            l_all := l_all - l_bal;
          else
            -- the rest of the lot takes the bonus, then the extra bonus (the legacy put the same rest in both fields)
            d.temp_quantity := l_all / f; d.quantity := l_all / f;
            l_b := least(l_rbonus, l_bal - l_all);
            l_e := least(l_rextra, l_bal - l_all - l_b);
            d.bonus := l_b / f; d.extra_bonus := l_e / f;
            d.bonus_ratio := case when d.quantity <> 0 then d.bonus / d.quantity * 100 else 0 end;
            d.extra_bonus_ratio := case when d.quantity <> 0 then d.extra_bonus / d.quantity * 100 else 0 end;
            l_all := 0;
            l_rbonus := l_rbonus - l_b;
            l_rextra := l_rextra - l_e;
          end if;
          so_line_values(so, d, f);
          update st_sales_order_det
             set item_confg_id = d.item_confg_id, temp_quantity = d.temp_quantity, quantity = d.quantity, bonus = d.bonus,
                 bonus_ratio = d.bonus_ratio, extra_bonus = d.extra_bonus, extra_bonus_ratio = d.extra_bonus_ratio,
                 basic_qty = d.basic_qty, unit_price = d.unit_price, tax_code1 = d.tax_code1, tax_value1 = d.tax_value1
           where rowid = l_last;
          l_tot := l_tot + d.basic_qty;
        else
          n := d;
          n.alt_key := null;
          select nvl(max(serial), 0) + 1 into n.serial from st_sales_order_det where trns_type_code = d.trns_type_code and trns_serial = d.trns_serial;
          n.item_confg_id := c.item_confg_id;
          n.last_expire_date := get_last_ex_date(so.store_code, d.item_group_code, d.item_code);
          calc_sales_disc(so.customer_code, d.item_group_code, d.item_code, d.unit_code, n.org_disc1_ratio, n.org_disc2_ratio,
                          n.org_disc3_ratio, n.org_bonus_ratio, n.org_unit_price_curr, n.org_extra_bonus_ratio, n.org_class_code,
                          so.class_code, n.item_confg_id);
          if l_bal >= l_all + l_rbonus + l_rextra then
            n.temp_quantity := l_all / f; n.quantity := l_all / f;
            n.bonus := l_rbonus / f; n.extra_bonus := l_rextra / f;
            l_all := 0; l_rbonus := 0; l_rextra := 0;
          elsif l_bal < l_all then
            n.temp_quantity := l_bal / f; n.quantity := l_bal / f;
            n.bonus := 0; n.extra_bonus := 0;
            l_all := l_all - l_bal;
          else
            n.temp_quantity := l_all / f; n.quantity := l_all / f;
            l_b := least(l_rbonus, l_bal - l_all);
            l_e := least(l_rextra, l_bal - l_all - l_b);
            n.bonus := l_b / f; n.extra_bonus := l_e / f;
            l_all := 0; l_rbonus := l_rbonus - l_b; l_rextra := l_rextra - l_e;
          end if;
          n.bonus_ratio := case when n.quantity <> 0 then n.bonus / n.quantity * 100 else 0 end;
          n.extra_bonus_ratio := case when n.quantity <> 0 then n.extra_bonus / n.quantity * 100 else 0 end;
          so_line_values(so, n, f);
          insert into st_sales_order_det values n returning rowid into l_last;
          l_tot := l_tot + n.basic_qty;
          exit when l_all = 0 and l_rbonus = 0 and l_rextra = 0;
        end if;
        i := i + 1;
      end if;
    end loop;
    if l_tot <> l_begin + l_bonus + l_extra then
      select nvl(max(neg_sale_balance), 0) into l_neg from st_basic;
      if l_neg = 0 then
        select max(decode(app_sec.lang, 'en', name_e, name_a)) into l_unit from st_unit where unit_code = d.unit_code;
        app_act_st.err(-20182, 'أقصى كمية يمكن إخراجها حتى لا تتعارض مع الحركات التالية = ' || d.item_code || ' ' || l_tot / f || ' ' || l_unit,
                       'Maximum Amount Can Be Sold Without Conflicting With Next Transactions = ' || d.item_code || ' ' || l_tot / f || ' ' || l_unit);
      end if;
      -- negative balances allowed: the rest stays on the last line
      update st_sales_order_det
         set temp_quantity = nvl(temp_quantity, 0) + l_all / f, quantity = nvl(quantity, 0) + l_all / f,
             bonus = nvl(bonus, 0) + l_rbonus / f, extra_bonus = nvl(extra_bonus, 0) + l_rextra / f,
             basic_qty = nvl(basic_qty, 0) + l_all + l_rbonus + l_rextra
       where rowid = l_last;
    end if;
  end so_split_line;

  procedure so_split_lots (p_request in varchar2, p_rowid in varchar2) is
    so    st_sales_order%rowtype;
    l_tx  varchar2(100) := so_txid;
    k     pls_integer;
    marks so_t_marks;
  begin
    if p_rowid is null or so_g_marks.count = 0 then
      so_g_marks.delete;
      return;
    end if;
    select * into so from st_sales_order where rowid = app_act_st.rid(p_rowid);
    marks := so_g_marks;
    so_g_marks.delete;
    app_rules_sa.set_bypass(true);
    k := marks.first;
    while k is not null loop
      if marks(k).txid = l_tx and marks(k).ttype = so.trns_type_code and marks(k).tserial = so.trns_serial then
        so_split_line(so, marks(k).line);
      end if;
      k := marks.next(k);
    end loop;
    app_rules_sa.set_bypass(false);
  exception when others then
    app_rules_sa.set_bypass(false);
    so_g_marks.delete;
    raise;
  end so_split_lots;

  -- ENABLE_DISABLE_BUTTONS: DELETE_ALLOWED false once a live sales invoice refers to the order
  procedure so_after_delete (p_type in varchar2, p_serial in varchar2) is
    l_n number;
  begin
    select count(*) into l_n from st_trns_mast m
     where m.order_trns_type_code = app_act_st.num(p_type) and m.order_trns_serial = app_act_st.num(p_serial)
       and nvl(m.delete_flag, 0) = 0;
    if l_n > 0 then
      app_act_st.err(-20183, 'امر البيع تم تحويلها إلي فاتورة مبيعات', 'Sales Order Posted To Sales Invoice');
    end if;
  end so_after_delete;

  -- TEMP_QUANTITY / QUANTITY WHEN-VALIDATE-ITEM: MSG('تعديت حد الائتمان', 0)
  function so_warn_credit (p_rowid in varchar2, p_customer in varchar2, p_approved in varchar2) return varchar2 is
    so     st_sales_order%rowtype;
    l_cust number := app_act_st.num(p_customer);
    l_lim  number; l_dn number; l_bal number; l_days number;
    l_net  number := 0;
  begin
    if l_cust is null then return null; end if;
    if p_rowid is not null then
      begin
        select * into so from st_sales_order where rowid = app_act_st.rid(p_rowid);
        l_net := so_net('SO', so.trns_type_code, so.trns_serial);
      exception when no_data_found then null;
      end;
    end if;
    so_credit(l_cust, l_lim, l_dn, l_bal, l_days);
    if l_lim < l_bal or (l_lim < l_bal + nvl(l_net, 0) and nvl(app_act_st.num(p_approved), 0) = 0) then
      return app_act_st.m('تعديت حد الائتمان', 'Over Credit Limit');
    end if;
    return null;
  exception when others then
    return null;
  end so_warn_credit;

  -- PO_CUST_DATE WHEN-VALIDATE-ITEM: order date before the customer PO date -> OK / Cancel alert (legacy text)
  function so_warn_po_date (p_order_date in varchar2, p_po_date in varchar2) return varchar2 is
    l_od date := nvl(app_act_st.dat(p_order_date), trunc(sysdate));
    l_pd date := app_act_st.dat(p_po_date);
  begin
    if l_pd is not null and l_od < l_pd then
      return app_act_st.m('تاريخ الحركة أكبر من تاريخ اليوم  ', 'Transaction Date is greater than Po Cust Date Date');
    end if;
    return null;
  end so_warn_po_date;

  -- GET_PROPOSAL_INFO of the order (counters) and the other displayed values
  function so_info (p_what in varchar2, p_rowid in varchar2) return varchar2 is
    so      st_sales_order%rowtype;
    l_lim   number; l_dn number; l_bal number; l_days number;
    l_items number; l_avail number; l_diff number; l_limit number;
    l_v     varchar2(4000);
  begin
    select * into so from st_sales_order where rowid = app_act_st.rid(p_rowid);
    if p_what in ('CREDIT_LIMIT', 'BALANCE', 'DAYS', 'DAY_NO', 'CREDIT_STATE') then
      if so.customer_code is null then return null; end if;
      so_credit(so.customer_code, l_lim, l_dn, l_bal, l_days);
      if p_what = 'CREDIT_LIMIT' then return so_fmt(l_lim);
      elsif p_what = 'BALANCE' then return so_fmt(l_bal);
      elsif p_what = 'DAYS' then return to_char(l_days);
      elsif p_what = 'DAY_NO' then return to_char(l_dn);
      end if;
      -- CHECK_MAST_STATUS: red credit limit / allowed days
      if l_lim < l_bal or (l_lim < l_bal + so_net('SO', so.trns_type_code, so.trns_serial) and nvl(so.approved, 0) = 0) then
        l_v := app_act_st.m('تعديت حد الائتمان', 'Over Credit Limit');
      end if;
      if nvl(l_days, 0) > nvl(l_dn, 0) then
        l_v := l_v || case when l_v is not null then ' - ' end || app_act_st.m('العميل متعدي فترة السماح', 'Over the allowed days');
      end if;
      return l_v;
    elsif p_what = 'NET' then
      return so_fmt(so_net('SO', so.trns_type_code, so.trns_serial));
    elsif p_what = 'TAX' then
      select nvl(sum(tax_value1), 0) + nvl(so.tax_value1, 0) into l_lim
        from st_sales_order_det where trns_type_code = so.trns_type_code and trns_serial = so.trns_serial;
      return so_fmt(l_lim);
    elsif p_what = 'INVOICE' then
      select max(m.trns_type_code || '/' || m.trns_serial) into l_v from st_trns_mast m
       where m.order_trns_type_code = so.trns_type_code and m.order_trns_serial = so.trns_serial and nvl(m.delete_flag, 0) = 0;
      return l_v;
    elsif p_what = 'WIDE_PRICE' then
      -- PRE-INSERT of a line (ST_BASIC.LESS_WIDE_SALE_PRICE = 1): 'سعر الصنف أقل من سعر الجملة'
      select listagg(d.item_code, ', ') within group (order by d.serial) into l_v
        from st_sales_order_det d, st_item_unit u
       where d.trns_type_code = so.trns_type_code and d.trns_serial = so.trns_serial
         and u.group_code = d.item_group_code and u.item_code = d.item_code and u.unit_code = d.unit_code
         and nvl(u.wide_sale_price, 0) <> 0 and nvl(d.unit_price_curr, 0) <> 0 and u.wide_sale_price > d.unit_price_curr;
      return l_v;
    end if;
    -- GET_PROPOSAL_INFO
    select count(*) into l_items from (select distinct item_group_code, item_code, item_confg_id from st_sales_order_det
                                        where trns_type_code = so.trns_type_code and trns_serial = so.trns_serial);
    begin
      select count(*) into l_avail from (
        select item_group_code, item_code, item_confg_id from st_sales_order_det
         where trns_type_code = so.trns_type_code and trns_serial = so.trns_serial
         group by item_group_code, item_code, item_confg_id
        having sum(nvl(basic_qty, 0)) <= get_balance_confg(so.store_code, item_group_code, item_code, item_confg_id, sysdate, null, null));
    exception when others then l_avail := 0;
    end;
    begin
      select count(*) into l_diff from st_sales_order_det p
       where p.trns_type_code = so.trns_type_code and p.trns_serial = so.trns_serial
         and (p.disc1_ratio > p.org_disc1_ratio or p.disc2_ratio > p.org_disc2_ratio or p.disc3_ratio > p.org_disc3_ratio);
      select l_diff + count(*) into l_diff from (
        select distinct p.item_group_code, p.item_code from st_sales_order_det p
         where p.trns_type_code = so.trns_type_code and p.trns_serial = so.trns_serial
           and (p.item_group_code, p.item_code) not in (select p2.item_group_code, p2.item_code from st_sales_order_det p2
                                                          where p2.trns_type_code = p.trns_type_code and p2.trns_serial = p.trns_serial
                                                            and (p2.disc1_ratio > p2.org_disc1_ratio or p2.disc2_ratio > p2.org_disc2_ratio
                                                                 or p2.disc3_ratio > p2.org_disc3_ratio))
         group by p.item_group_code, p.item_code
        having (sum(p.bonus) / sum(p.quantity) * 100) > max(p.org_bonus_ratio)
            or (sum(p.extra_bonus) / sum(p.quantity) * 100) > max(p.org_extra_bonus_ratio));
    exception when others then l_diff := 0;              -- legacy: an error (quantity 0) resets the counter
    end;
    select count(*) into l_limit from (
      select p.item_group_code, p.item_code from st_sales_order_det p, st_item_unit u
       where p.trns_type_code = so.trns_type_code and p.trns_serial = so.trns_serial
         and p.item_group_code = u.group_code and p.item_code = u.item_code and p.unit_code = u.unit_code
         and nvl(u.sales_limit, 0) <> 0 and nvl(p.basic_qty, 0) > nvl(u.sales_limit, 0)
       group by p.item_group_code, p.item_code);
    return to_char(case p_what
                     when 'ITEMS' then l_items
                     when 'AVAILABLE' then greatest(l_avail - l_limit, 0)
                     when 'UNAVAILABLE' then l_items - l_avail
                     when 'DIFF_POLICY' then l_diff
                     when 'SALES_LIMIT' then l_limit end);
  exception when others then
    return null;
  end so_info;

  -- ================================================================== ST_PRICE_PROPOSAL
  function qt_converted_msg (q in st_proposal_mast%rowtype) return varchar2 is
    l_n number;
  begin
    -- CLOSE_UPDATE: converted quotations (live order or invoice with DEMO_TRNS = the quotation, or a live split quotation)
    select (select count(*) from st_sales_order where demo_trns_type_code = q.trns_type_code and demo_trns_serial = q.trns_serial and delete_date is null)
         + (select count(*) from st_trns_mast where demo_trns_type_code = q.trns_type_code and demo_trns_serial = q.trns_serial and nvl(delete_flag, 0) <> 1)
      into l_n from dual;
    if l_n > 0 then
      return app_act_st.m('تم تحويل عرض السعر الي امر بيع', 'This Price Proposal has been transfared to Sales Order');
    end if;
    select count(*) into l_n from st_proposal_mast
     where proposal_trns_type_code = q.trns_type_code and proposal_trns_serial = q.trns_serial and nvl(delete_flag, 0) = 0;
    if l_n > 0 then
      return app_act_st.m('عرض السعر تم ترحيلة إلي عرض السعر', 'Price Proposal Posted To Price Proposal');
    end if;
    if nvl(q.salesman_done, 0) = 1 and app_act_st.pw <> 0 and so_user_flag('ALLOW_APPROVE') <> 1
       and so_user_flag('ALLOW_APPROVE2') <> 1 and so_user_flag('ALLOW_APPROVE3') <> 1 then
      return app_act_st.m('عرض السعر معتمد من المندوب ولا يمكن تعديله', 'The quotation is confirmed by the salesman and cannot be changed');
    end if;
    return null;
  end qt_converted_msg;

  function qt_can (p_what in varchar2, p_rowid in varchar2) return varchar2 is
    q st_proposal_mast%rowtype;
  begin
    select * into q from st_proposal_mast where rowid = app_act_st.rid(p_rowid);
    if nvl(q.delete_flag, 0) = 1 then return 'N'; end if;
    if p_what = 'CHOICE' then
      -- the check boxes of the entry screen: the lines can be changed (not accepted by sales, not converted)
      return case when nvl(q.cust_accept_flag, 0) = 0 and qt_converted_msg(q) is null then 'Y' else 'N' end;
    elsif p_what = 'EXCEL' then
      return 'Y';
    end if;
    return 'N';
  exception when others then
    return 'N';
  end qt_can;

  function qt_lines_locked (q in st_proposal_mast%rowtype) return varchar2 is
    l_msg varchar2(4000) := qt_converted_msg(q);
  begin
    if l_msg is not null then return l_msg; end if;
    if nvl(q.approve, 0) = 1 and app_act_st.pw <> 0 and so_user_flag('ALLOW_APPROVE') <> 1 then
      return app_act_st.m('الحركة الحالية معتمدة و لا يمكن تعديل الأصناف', 'The quotation is approved: its lines cannot be changed');
    end if;
    return null;
  end qt_lines_locked;

  function qt_lock (p_rowid in varchar2) return st_proposal_mast%rowtype is
    q     st_proposal_mast%rowtype;
    l_rid rowid := app_act_st.rid(p_rowid);
  begin
    select * into q from st_proposal_mast where rowid = l_rid for update wait 10;
    if nvl(q.delete_flag, 0) = 1 then
      app_act_st.err(-20184, 'عرض السعر ملغي', 'The quotation is deleted');
    end if;
    return q;
  exception when no_data_found then
    app_act_st.err(-20184, 'عرض السعر غير موجود (ربما حذف من مستخدم آخر)', 'The quotation no longer exists');
  end qt_lock;

  -- CHOICE_FLAG_ALL: tick = choose every available line (not unavailable, store balance >= the item's quantity on the
  -- quotation); untick = un-choose every chosen line. CHOICE_FLAG WHEN-VALIDATE-ITEM is applied to each changed line.
  function qt_choice_all (p_rowid in varchar2, p_flag in number) return varchar2 is
    q     st_proposal_mast%rowtype := qt_lock(p_rowid);
    l_msg varchar2(4000);
    l_bal number;
    l_act number;
    l_n   number := 0;
  begin
    if q.cust_accept_flag = 1 then
      app_act_st.set_message('تم اعتماد المبيعات', 'Sales Approval Done');
      return p_rowid;
    end if;
    l_msg := qt_lines_locked(q);
    if l_msg is not null then
      raise_application_error(-20184, l_msg);
    end if;
    app_rules_sa.set_bypass(true);
    for d in (select rowid rid, d.* from st_proposal_det d
               where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial order by item_serial) loop
      if nvl(p_flag, 0) = 1 then
        if d.item_code is not null and nvl(d.basic_qty, 0) <> 0 and nvl(d.choice_flag, 0) = 0 and nvl(d.unavailable_flag, 0) = 0 then
          l_bal := get_balance(q.store_code, d.group_code, d.item_code, sysdate, null, null);
          select sum(nvl(basic_qty, 0)) into l_act from st_proposal_det
           where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial
             and item_code = d.item_code and unit_code = d.unit_code and group_code = d.group_code;
          if l_bal >= l_act and l_bal >= nvl(d.quantity, 0) + nvl(d.bonus, 0) + nvl(d.extra_bonus, 0) then
            update st_proposal_det set choice_flag = 1 where rowid = d.rid;
            l_n := l_n + 1;
          end if;
        end if;
      elsif d.item_code is not null and nvl(d.unit_price, 0) <> 0 and nvl(d.basic_qty, 0) <> 0
            and nvl(d.choice_flag, 0) = 1 and nvl(d.unavailable_flag, 0) = 0 then
        update st_proposal_det set choice_flag = 0 where rowid = d.rid;
        l_n := l_n + 1;
      end if;
    end loop;
    app_rules_sa.set_bypass(false);
    app_act_st.set_message('تم تحديث ' || l_n || ' صنف', l_n || ' line(s) updated');
    return p_rowid;
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end qt_choice_all;

  -- UNAVAILABLE_FLAG_ALL: tick = mark every line that is not chosen as unavailable; untick = clear the flag on every line
  function qt_unavailable_all (p_rowid in varchar2, p_flag in number) return varchar2 is
    q     st_proposal_mast%rowtype := qt_lock(p_rowid);
    l_msg varchar2(4000);
    l_n   number := 0;
  begin
    if q.cust_accept_flag = 1 then
      app_act_st.set_message('تم اعتماد المبيعات', 'Sales Approval Done');
      return p_rowid;
    end if;
    l_msg := qt_lines_locked(q);
    if l_msg is not null then
      raise_application_error(-20184, l_msg);
    end if;
    app_rules_sa.set_bypass(true);
    if nvl(p_flag, 0) = 1 then
      update st_proposal_det set unavailable_flag = 1
       where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial
         and item_code is not null and nvl(unit_price, 0) <> 0 and nvl(quantity, 0) <> 0
         and nvl(unavailable_flag, 0) = 0 and nvl(choice_flag, 0) = 0;
    else
      update st_proposal_det set unavailable_flag = 0
       where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial
         and item_code is not null and nvl(unit_price, 0) <> 0 and nvl(quantity, 0) <> 0
         and nvl(unavailable_flag, 0) = 1;
    end if;
    l_n := sql%rowcount;
    app_rules_sa.set_bypass(false);
    app_act_st.set_message('تم تحديث ' || l_n || ' صنف', l_n || ' line(s) updated');
    return p_rowid;
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end qt_unavailable_all;

  -- GET_EXCEL_TAX_VALUE: tax types of the latest start date <= the quotation date; area (never given), customer exemption
  -- (TAX_PER 0) or the item's rate
  procedure qt_excel_tax (p_group in number, p_item in varchar2, p_customer in number, p_value in number, p_date in date,
                          o_code out number, o_value out number) is
    l_n number;
  begin
    for i in (select tax_code from tx_taxes_types
               where start_date = (select max(start_date) from tx_taxes_types where start_date <= p_date) order by tax_code) loop
      select count(*) into l_n from tx_taxes_customers
       where customer_code = p_customer and tax_code = i.tax_code and (p_item is null or nvl(tax_per, 0) = 0);
      if l_n <> 0 then
        for c in (select * from tx_taxes_customers where customer_code = p_customer and tax_code = i.tax_code) loop
          o_code := c.tax_code; o_value := c.tax_per * p_value / 100;
        end loop;
      else
        for c in (select * from tx_taxes_items where group_code = p_group and item_code = p_item and tax_code = i.tax_code) loop
          o_code := c.tax_code; o_value := c.tax_per * p_value / 100;
        end loop;
      end if;
    end loop;
  end qt_excel_tax;

  function qt_cell_num (p in varchar2, p_row in number, p_col in varchar2) return number is
    l number;
  begin
    if trim(p) is null then return null; end if;
    l := to_number(trim(p) default null on conversion error);
    if l is null then
      app_act_st.err(-20185, 'قيمة غير رقمية في السطر ' || p_row || ' عمود ' || p_col || ': ' || p,
                     'Not a number in row ' || p_row || ' column ' || p_col || ': ' || p);
    end if;
    return l;
  end qt_cell_num;

  function qt_cell_date (p in varchar2, p_row in number) return date is
    l date;
    s varchar2(100) := trim(p);
  begin
    if s is null then return null; end if;
    l := to_date(s default null on conversion error, 'DD/MM/YYYY');
    if l is null then l := to_date(substr(s, 1, 10) default null on conversion error, 'YYYY-MM-DD'); end if;
    if l is null then l := to_date(s default null on conversion error, 'DD-MM-YYYY'); end if;
    if l is null then
      app_act_st.err(-20185, 'تاريخ غير صحيح في السطر ' || p_row || ': ' || p, 'Invalid date in row ' || p_row || ': ' || p);
    end if;
    return l;
  end qt_cell_date;

  -- LOAD_EXCEL + LOAD_EXCEL_FILE: sheet 1 from row 2 until the first empty item code; columns: 1 group, 2 item, 3 unit,
  -- 4 sales price, 5 lot id, 6 lot number, 7 expiry (DD/MM/YYYY), 8 quantity, 9-11 discount 1-3 (fractions, x 100),
  -- 12 bonus, 13 extra bonus. Rows with errors are skipped and reported (legacy: text file next to the Excel file).
  function qt_load_excel (p_rowid in varchar2, p_file in varchar2) return varchar2 is
    q        st_proposal_mast%rowtype := qt_lock(p_rowid);
    l_blob   blob;
    l_fn     varchar2(400);
    l_n      number;
    l_err    varchar2(1000);
    l_report varchar2(32767);
    l_rows   number := 0;
    l_group  number; l_item varchar2(100); l_unit number; l_price number; l_confg number; l_lot varchar2(100);
    l_exp    date; l_qty number; l_d1 number; l_d2 number; l_d3 number; l_bonus number; l_extra number;
    l_br     number; l_er number; l_line number; l_v1 number; l_v2 number; l_v3 number; l_basic number; l_total number;
    l_tcode  number; l_tval number;
    l_o1 number; l_o2 number; l_o3 number; l_ob number; l_op number; l_oe number; l_oc number; l_last date;
  begin
    select count(*) into l_n from st_proposal_det where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial;
    if not (l_n = 0 and q.trns_type_code is not null and q.customer_code is not null and q.trns_date is not null) then
      if q.trns_type_code is null then
        app_act_st.err(-20185, 'لابد من أدخال البيانات أولا', 'You Should Insert Data First');
      end if;
      app_act_st.err(-20185, 'لابد من حذف البيانات أولا', 'You Should Delete Data First');
    end if;
    app_act_st.get_file(p_file, l_blob, l_fn);
    app_rules_sa.set_bypass(true);
    for r in (select line_number, col001, col002, col003, col004, col005, col006, col007, col008, col009, col010, col011,
                     col012, col013
                from table(apex_data_parser.parse(p_content => l_blob, p_file_name => l_fn))
               where line_number >= 2
               order by line_number) loop
      l_item := trim(r.col002);
      exit when l_item is null;
      l_err := null;
      l_group := qt_cell_num(r.col001, r.line_number, 1);
      l_unit := qt_cell_num(r.col003, r.line_number, 3);
      l_price := qt_cell_num(r.col004, r.line_number, 4);
      l_confg := qt_cell_num(r.col005, r.line_number, 5);
      l_lot := trim(r.col006);
      l_exp := qt_cell_date(r.col007, r.line_number);
      l_qty := qt_cell_num(r.col008, r.line_number, 8);
      l_d1 := qt_cell_num(r.col009, r.line_number, 9) * 100;
      l_d2 := qt_cell_num(r.col010, r.line_number, 10) * 100;
      l_d3 := qt_cell_num(r.col011, r.line_number, 11) * 100;
      l_bonus := qt_cell_num(r.col012, r.line_number, 12);
      l_extra := qt_cell_num(r.col013, r.line_number, 13);
      l_br := case when nvl(l_qty, 0) <> 0 then round(l_bonus * 100 / l_qty, 2) else 0 end;
      l_er := case when nvl(l_qty, 0) <> 0 then round(l_extra * 100 / l_qty, 2) else 0 end;
      if l_group is null then
        select min(item_group_code) into l_group from st_item where item_code = l_item;
      end if;
      select count(*) into l_n from st_item_group where item_group_code = l_group and nvl(group_status, 0) = 1;
      if l_n = 0 then l_err := ' GROUP NOT EXIST-'; end if;
      if l_confg is null and l_lot is not null and l_exp is not null then
        select max(item_confg_id) into l_confg from st_item_confg
         where group_code = l_group and item_code = l_item and lot_number = l_lot and expire_date = l_exp;
      end if;
      if l_confg is not null then
        select count(*) into l_n from st_item_confg where group_code = l_group and item_code = l_item and item_confg_id = l_confg;
        if l_n = 0 then l_err := ' Item Confg NOT EXIST-'; end if;
      end if;
      if l_price is null then
        select min(retail_sale_price) into l_price from st_item_unit where item_code = l_item and group_code = l_group and unit_code = l_unit;
      end if;
      if l_price is null or l_price < 0 then l_err := l_err || ' SALES PRICE IS NULL-'; end if;
      if l_d1 is null then
        select min(moh_disc) into l_d1 from st_item where item_code = l_item and item_group_code = l_group;
      end if;
      if l_d1 is null or l_d1 < 0 then l_err := l_err || ' DISC RATIO 1 IS NULL-'; end if;
      if l_d2 is null or l_d2 < 0 then l_err := l_err || ' DISC RATIO 2 IS NULL-'; end if;
      if l_d3 is null or l_d3 < 0 then l_err := l_err || ' DISC RATIO 3 IS NULL-'; end if;
      if l_bonus is null or nvl(l_br, 0) < 0 then l_err := l_err || ' BONUS IS NULL-'; end if;
      if l_extra is null or nvl(l_er, 0) < 0 then l_err := l_err || ' EXTRA BONUS IS NULL-'; end if;
      select count(*) into l_n from st_item_unit where unit_code = l_unit and item_code = l_item and group_code = l_group;
      if l_n = 0 then l_err := l_err || ' UNIT NOT EXIST-'; end if;
      select count(*) into l_n from st_item where item_code = l_item and item_group_code = l_group;
      if l_n = 0 then l_err := l_err || ' Item Code NOT EXIST UNDER Item Group-'; end if;
      if l_err is null then
        select nvl(max(item_serial), 0) + 1 into l_line from st_proposal_det where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial;
        l_v1 := case when nvl(l_d1, 0) <> 0 then l_d1 * l_price / 100 else 0 end;
        l_v2 := case when nvl(l_d2, 0) <> 0 then l_d2 * (l_price - l_v1) / 100 else 0 end;
        l_v3 := case when nvl(l_d3, 0) <> 0 then l_d3 * (l_price - l_v1 - l_v2) / 100 else 0 end;
        l_basic := round(l_br * l_qty / 100) + round(l_er * l_qty / 100) + nvl(l_qty, 0);
        l_total := ((nvl(l_price, 0) * nvl(q.currency_rate, 1)) - (nvl(l_v1, 0) + nvl(l_v2, 0) + nvl(l_v3, 0))) * nvl(l_basic, 0);
        l_tcode := null; l_tval := 0;
        begin
          qt_excel_tax(l_group, l_item, q.customer_code, l_total, q.trns_date, l_tcode, l_tval);
        exception when others then
          l_tcode := null; l_tval := 0;
        end;
        l_o1 := null; l_o2 := null; l_o3 := null; l_ob := null; l_op := null; l_oe := null; l_oc := null;
        begin
          calc_sales_disc(q.customer_code, l_group, l_item, l_unit, l_o1, l_o2, l_o3, l_ob, l_op, l_oe, l_oc, q.class_code, l_confg);
        exception when others then null;
        end;
        begin
          l_last := get_last_ex_date(q.store_code, l_group, l_item);
        exception when others then l_last := null;
        end;
        begin
          insert into st_proposal_det
            (trns_type_code, trns_serial, item_serial, date_serial, store_code, delete_flag, group_code, item_code, unit_code, quantity,
             bonus, basic_qty, item_confg_id, unit_price, unit_price_curr, cost_flag, disc, det_disc, trns_date, disc1_ratio,
             disc2_ratio, disc1_value, disc2_value, tax_code1, tax_value1, disc3_ratio, disc3_value, bonus_ratio, extra_bonus_ratio,
             extra_bonus, auto_disc, unavailable_flag, choice_flag, temp_quantity, org_class_code, org_disc1_ratio, org_disc2_ratio,
             org_disc3_ratio, org_bonus_ratio, org_extra_bonus_ratio, org_unit_price_curr, last_expire_date)
          values
            (q.trns_type_code, q.trns_serial, l_line, q.date_serial, q.store_code, q.delete_flag, l_group, l_item, l_unit, l_qty,
             nvl(l_bonus, 0), l_basic, l_confg, l_price * nvl(q.currency_rate, 1), l_price, 1, 0, 0, q.trns_date, l_d1,
             l_d2, l_v1, l_v2, l_tcode, l_tval, l_d3, l_v3, l_br, l_er,
             nvl(l_extra, 0), 0, 0, 0, l_qty, l_oc, l_o1, l_o2,
             l_o3, l_ob, l_oe, l_op, l_last);
          l_rows := l_rows + 1;
        exception when others then
          l_report := substr(l_report || chr(10) || 'ERROR IN INSERTION OF ITEM ' || l_item, 1, 30000);
        end;
      else
        l_report := substr(l_report || chr(10) || ' ITEM CODE= ' || l_item || ' GROUP CODE= ' || l_group || ' ' || l_err, 1, 30000);
      end if;
    end loop;
    app_rules_sa.set_bypass(false);
    app_act_st.set_message(substr('تم تحميل ملف الأكسل' || ' (' || l_rows || ')' || l_report, 1, 3900),
                           substr('File Loades' || ' (' || l_rows || ')' || l_report, 1, 3900));
    return p_rowid;
  exception when others then
    app_rules_sa.set_bypass(false);
    raise;
  end qt_load_excel;

  -- KEY-DELREC: approved (supervisor or sales) quotations and quotations converted to a sales order cannot be deleted; converted /
  -- split quotations and salesman-confirmed ones without approval rights are read only (CLOSE_UPDATE: DELETE_ALLOWED false)
  function qt_delete_check (p_rowid in varchar2) return varchar2 is
    q   st_proposal_mast%rowtype;
    l_n number;
  begin
    begin
      select * into q from st_proposal_mast where rowid = app_act_st.rid(p_rowid);
    exception when no_data_found then
      return app_act_st.m('عرض السعر غير موجود (ربما حذف من مستخدم آخر)', 'The quotation no longer exists');
    end;
    if nvl(q.cust_accept_flag, 0) <> 0 or nvl(q.approve, 0) <> 0 then
      return app_act_st.m('الحركة الحالية معتمدة و لا يمكن الحذف', 'The current transaction is approved and can''t be deleted');
    end if;
    select count(*) into l_n from st_sales_order
     where demo_trns_type_code = q.trns_type_code and demo_trns_serial = q.trns_serial and delete_date is null;
    if l_n > 0 then
      return app_act_st.m('عرض السعر تم تحويلة إلى أمر بيع', 'Price Proposal Converted To Sales Order');
    end if;
    return qt_converted_msg(q);
  end qt_delete_check;

  function qt_info (p_what in varchar2, p_rowid in varchar2) return varchar2 is
    q       st_proposal_mast%rowtype;
    l_lim   number; l_dn number; l_bal number; l_days number;
    l_items number; l_avail number; l_unall number := 0; l_diff number; l_limit number;
    l_v     varchar2(4000);
    l_comp  number;
  begin
    select * into q from st_proposal_mast where rowid = app_act_st.rid(p_rowid);
    if p_what in ('CREDIT_LIMIT', 'BALANCE', 'DAYS', 'DAY_NO', 'CREDIT_STATE') then
      if q.customer_code is null then return null; end if;
      so_credit(q.customer_code, l_lim, l_dn, l_bal, l_days);
      if p_what = 'CREDIT_LIMIT' then return so_fmt(l_lim);
      elsif p_what = 'BALANCE' then return so_fmt(l_bal);
      elsif p_what = 'DAYS' then return to_char(l_days);
      elsif p_what = 'DAY_NO' then return to_char(l_dn);
      end if;
      if l_lim < l_bal or (l_lim < l_bal + so_net('QT', q.trns_type_code, q.trns_serial) and nvl(q.approve, 0) = 0) then
        l_v := app_act_st.m('تعديت حد الائتمان', 'Over Credit Limit');
      end if;
      if nvl(l_days, 0) > nvl(l_dn, 0) then
        l_v := l_v || case when l_v is not null then ' - ' end || app_act_st.m('العميل متعدي فترة السماح', 'Over the allowed days');
      end if;
      return l_v;
    elsif p_what = 'NET' then
      return so_fmt(so_net('QT', q.trns_type_code, q.trns_serial));
    elsif p_what = 'CHOSEN_NET' then
      -- GET_TOTAL_A: the chosen lines (NET_VALUE_A)
      return so_fmt(so_net('QT', q.trns_type_code, q.trns_serial, true));
    elsif p_what = 'TAX' then
      select nvl(sum(tax_value1), 0) + nvl(q.tax_value1, 0) into l_lim
        from st_proposal_det where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial;
      return so_fmt(l_lim);
    elsif p_what = 'NOT_CHOSEN' then
      -- TO_SALES_ORDER_BTN / TRNSFER_FROM_BTN: 'يوجد عدد أصناف N غير مختارة'
      select count(*) into l_items from st_proposal_det
       where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial and nvl(choice_flag, 0) = 0;
      return to_char(l_items);
    elsif p_what = 'LINKS' then
      -- POST-QUERY: sales order (and its invoice), transfer made from the quotation; quotation / transfer request split from it
      for r in (select 1 k, app_act_st.m('أمر البيع ', 'Sales order ') || trns_type_code || '/' || trns_serial
                        || nvl2(sl_trns_type_code, app_act_st.m(' - فاتورة البيع ', ' - invoice ') || sl_trns_type_code || '/' || sl_trns_serial, null) t
                  from st_sales_order where demo_trns_type_code = q.trns_type_code and demo_trns_serial = q.trns_serial and delete_date is null
                union all
                select 2, app_act_st.m('حركة التحويل ', 'Transfer ') || trns_type_code || '/' || trns_serial
                  from st_trns_mast where pro_trns_type_code = q.trns_type_code and pro_trns_serial = q.trns_serial and delete_date is null
                union all
                select 3, app_act_st.m('عرض السعر ', 'Quotation ') || trns_type_code || '/' || trns_serial
                  from st_proposal_mast where proposal_trns_type_code = q.trns_type_code and proposal_trns_serial = q.trns_serial and nvl(delete_flag, 0) = 0
                union all
                select 4, app_act_st.m('طلب التحويل ', 'Transfer request ') || trns_type_code || '/' || trns_serial
                  from st_trns_mast_request where proposal_trns_type_code = q.trns_type_code and proposal_trns_serial = q.trns_serial and nvl(delete_flag, 0) = 0
                order by 1, 2) loop
        l_v := l_v || case when l_v is not null then '، ' end || r.t;
      end loop;
      return l_v;
    end if;
    -- GET_PROPOSAL_INFO
    l_comp := nvl(app_act_st.num(v('G_COMPANY_CODE')), 1);
    select count(*) into l_items from (select distinct group_code, item_code from st_proposal_det
                                        where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial);
    for it in (select group_code, item_code, sum(basic_qty) basic_qty from st_proposal_det
                where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial
                  and nvl(basic_qty, 0) > get_balance(q.store_code, group_code, item_code, sysdate, null, null)
                group by group_code, item_code) loop
      if it.basic_qty > get_balance_all_stores(q.store_code, it.group_code, it.item_code, sysdate, null, null, l_comp) then
        l_unall := l_unall + 1;
      end if;
    end loop;
    begin
      select count(*) into l_avail from (
        select group_code, item_code from st_proposal_det
         where trns_type_code = q.trns_type_code and trns_serial = q.trns_serial
         group by group_code, item_code
        having sum(nvl(basic_qty, 0)) <= get_balance(q.store_code, group_code, item_code, sysdate, null, null));
    exception when others then l_avail := 0;
    end;
    select count(*) into l_diff from st_proposal_det p
     where p.trns_type_code = q.trns_type_code and p.trns_serial = q.trns_serial
       and (p.disc1_ratio > p.org_disc1_ratio or p.disc2_ratio > p.org_disc2_ratio or p.disc3_ratio > p.org_disc3_ratio
            or p.bonus_ratio > p.org_bonus_ratio or p.extra_bonus_ratio > p.org_extra_bonus_ratio
            or (nvl(p.bonus_ratio, 0) = 0 and nvl(p.bonus, 0) <> 0) or (nvl(p.extra_bonus_ratio, 0) = 0 and nvl(p.extra_bonus, 0) <> 0));
    select count(*) into l_limit from (
      select p.group_code, p.item_code from st_proposal_det p, st_item_unit u
       where p.trns_type_code = q.trns_type_code and p.trns_serial = q.trns_serial
         and p.group_code = u.group_code and p.item_code = u.item_code and p.unit_code = u.unit_code
         and nvl(u.sales_limit, 0) <> 0 and nvl(p.basic_qty, 0) > nvl(u.sales_limit, 0)
       group by p.group_code, p.item_code);
    return to_char(case p_what
                     when 'ITEMS' then l_items
                     when 'AVAILABLE' then greatest(l_avail - l_limit, 0)
                     when 'UNAVAILABLE' then l_items - l_avail - l_unall
                     when 'UNAVAILABLE_ALL' then l_unall
                     when 'DIFF_POLICY' then l_diff
                     when 'SALES_LIMIT' then l_limit end);
  exception when others then
    return null;
  end qt_info;
  -- =================================================================================== ST_RESERVATION / ST_DELIVERY
  function rsv_fmt (p in number) return varchar2 is
  begin
    return case when p is null then null else to_char(p, 'FM999G999G999G990D00') end;
  end rsv_fmt;

  function rsv_type (p_type in number) return st_trns_type%rowtype is
    t st_trns_type%rowtype;
  begin
    select * into t from st_trns_type where trns_type_code = p_type;
    return t;
  exception when no_data_found then
    return t;
  end rsv_type;

  function rsv_is_rsv_type (p_type in number) return boolean is
    t st_trns_type%rowtype := rsv_type(p_type);
  begin
    return nvl(t.effect, 0) = 2 and nvl(t.trns_type, 0) = 17;
  end rsv_is_rsv_type;

  -- library CHECK_DATE (TRANSLATE.pll) + the AC_BASIC open period of the DB trigger CLOSE_ST_TRNS_MAST (Arabic first)
  procedure dlv_check_date (p_date in date) is
    l_min  date;
    l_amin date;
    l_amax date;
  begin
    if trunc(p_date) > trunc(sysdate) then
      app_act_st.err(-20151, 'تاريخ الحركة أكبر من تاريخ اليوم', 'Transaction Date is greater than Today Date');
    end if;
    select min(min_date) into l_min from st_basic;
    l_min := nvl(l_min, to_date('01-01-1900', 'DD-MM-YYYY'));
    if trunc(p_date) < trunc(l_min) then
      app_act_st.err(-20151, 'الحد الأدنى لتاريخ الحركة هو ' || to_char(l_min, 'DD/MM/YYYY'),
                     'The least value accepted for Transaction Date is ' || to_char(l_min, 'DD/MM/YYYY'));
    end if;
    select min(min_date), min(max_date) into l_amin, l_amax from ac_basic;
    if l_amin is not null and l_amax is not null and p_date not between l_amin and l_amax then
      app_act_st.err(-20151, 'تاريخ الحركة خارج الفترة المفتوحة (' || to_char(l_amin, 'DD/MM/YYYY') || ' - ' || to_char(l_amax, 'DD/MM/YYYY') || ')',
                     'The transaction date is outside the open period (' || to_char(l_amin, 'DD/MM/YYYY') || ' - ' || to_char(l_amax, 'DD/MM/YYYY') || ')');
    end if;
  end dlv_check_date;

  function dlv_factor (p_group in number, p_item in varchar2, p_unit in number) return number is
    l number;
  begin
    select max(factor) into l from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit;
    return nvl(l, 1);
  end dlv_factor;

  -- the sales invoice generated from a delivery note: INSERT_ISSUE_TRNS writes ST_TRNS_MAST.DELIVERY_TRNS_TYPE_CODE / SERIAL;
  -- the legacy POST-QUERY read it back from ST_TRNS_DET.OPER_TRNS_TYPE_CODE / SERIAL (both are accepted); live documents only
  procedure dlv_invoice_of (p_type in number, p_serial in number, o_type out number, o_serial out number) is
  begin
    select min(trns_type_code), min(trns_serial) keep (dense_rank first order by trns_type_code) into o_type, o_serial
      from (select m.trns_type_code, m.trns_serial from st_trns_mast m
             where m.delivery_trns_type_code = p_type and m.delivery_trns_serial = p_serial and nvl(m.delete_flag, 0) = 0
            union
            select d.trns_type_code, d.trns_serial from st_trns_det d
             where d.oper_trns_type_code = p_type and d.oper_trns_serial = p_serial and nvl(d.delete_flag, 0) = 0);
  end dlv_invoice_of;

  function dlv_merged (p_type in number, p_serial in number) return boolean is
    l_n number;
  begin
    select count(*) into l_n from st_merg_det where delivery_trns_type_code = p_type and delivery_trns_serial = p_serial;
    return l_n > 0;
  end dlv_merged;

  function dlv_user_flag (p_col in varchar2) return number is
    l number;
  begin
    execute immediate 'select max(nvl(' || dbms_assert.simple_sql_name(p_col) || ', 0)) from users where users_code = :u'
      into l using app_act_st.usr;
    return nvl(l, 0);
  end dlv_user_flag;

  -- =================================================================================== ST_RESERVATION
  function rsv_validate (p_request in varchar2, p_rowid in varchar2, p_type in varchar2, p_store in varchar2,
                         p_customer in varchar2, p_supplier in varchar2, p_salesman in varchar2,
                         p_account in varchar2) return varchar2 is
    l_type  number := app_act_st.num(p_type);
    l_cust  number := app_act_st.num(p_customer);
    l_supp  number := app_act_st.num(p_supplier);
    l_sman  number := app_act_st.num(p_salesman);
    l_acc   number := app_act_st.num(p_account);
    l_pw    number := app_act_st.pw;
    t       st_trns_type%rowtype;
    l_n     number;
  begin
    if l_type is null then return null; end if;              -- the screen validation (APP_RULES_ST.val_trns) reports it
    t := rsv_type(l_type);
    -- TRNS_TYPE LOV: STORE_CODE IS NULL OR group 0 OR the type's store is granted to the group (ST_STORE_PASSWORD)
    if t.store_code is not null and l_pw <> 0 then
      select count(*) into l_n from st_store_password where password_number = l_pw and store_code = t.store_code;
      if l_n = 0 then
        return app_act_st.m('نوع الحركة غير مسموح به (مخزن الحركة غير مسموح للمجموعة): ', 'Transaction type not allowed (store of the type): ') || l_type;
      end if;
    end if;
    -- SHOW_HIDE_ITEMS: customer transactions (JOIN_TYPE 3) show the customer (as the sales invoice screen: required)
    if nvl(t.join_type, 0) = 3 and l_cust is null then
      return app_act_st.m('يجب إدخال رقم العميل', 'Enter the customer');
    end if;
    -- CUSTOMER_RG: NVL(STOPFLAG,0) <> 1, group range of AR_CUSTOMER_PASSWORD
    if l_cust is not null then
      select count(*) into l_n from customer where code = l_cust and nvl(stopflag, 0) <> 1;
      if l_n = 0 then
        return app_act_st.m('رقم العميل غير صحيح أو موقوف: ', 'Invalid or stopped customer: ') || l_cust;
      end if;
      if l_pw <> 0 then
        select count(*) into l_n from ar_customer_password
         where password_number = l_pw and l_cust between from_customer_code and to_customer_code;
        if l_n = 0 then
          return app_act_st.m('ليس لديك صلاحية على هذا العميل: ', 'You have no permission on this customer: ') || l_cust;
        end if;
      end if;
    end if;
    -- SUPPLIER_RG: group range of VN_SUPPLIER_PASSWORD
    if l_supp is not null then
      select count(*) into l_n from supplier where code = l_supp;
      if l_n = 0 then
        return app_act_st.m('رقم المورد غير صحيح: ', 'Invalid supplier: ') || l_supp;
      end if;
      if l_pw <> 0 then
        select count(*) into l_n from vn_supplier_password
         where password_number = l_pw and l_supp between from_supplier_code and to_supplier_code;
        if l_n = 0 then
          return app_act_st.m('ليس لديك صلاحية على هذا المورد: ', 'You have no permission on this supplier: ') || l_supp;
        end if;
      end if;
    end if;
    -- SALESMAN_RG: a salesman of the customer (AR_CUST_SALESMAN) and in the group range AR_CUSTOMER_PASSWORD.FROM/TO_SALESMAN
    if l_sman is not null then
      select count(*) into l_n from salesman where code = l_sman;
      if l_n = 0 then
        return app_act_st.m('رقم المندوب غير صحيح: ', 'Invalid salesman: ') || l_sman;
      end if;
      if l_cust is not null then
        select count(*) into l_n from ar_cust_salesman where customer_code = l_cust and salesman_code = l_sman;
        if l_n = 0 then
          return app_act_st.m('المندوب ليس من مندوبي العميل', 'The salesman is not a salesman of the customer');
        end if;
      end if;
      if l_pw <> 0 then
        select count(*) into l_n from ar_customer_password
         where password_number = l_pw and l_sman between from_salesman and to_salesman;
        if l_n = 0 then
          return app_act_st.m('ليس لديك صلاحية على هذا المندوب: ', 'You have no permission on this salesman: ') || l_sman;
        end if;
      end if;
    end if;
    -- ACCOUNT_RG: group rights AC_PASSWORD_MASTER (the active-account check is in APP_RULES_ST.val_trns)
    if l_acc is not null and l_pw <> 0 and v('G_COMPANY_CODE') is not null then
      select count(*) into l_n from ac_password_master
       where password_number = l_pw and company_code = app_act_st.num(v('G_COMPANY_CODE')) and account_number = l_acc;
      if l_n = 0 then
        return app_act_st.m('ليس لديك صلاحية على هذا الحساب: ', 'You have no permission on this account: ') || l_acc;
      end if;
    end if;
    return null;
  end rsv_validate;

  procedure rsv_after_save (p_request in varchar2, p_rowid in varchar2) is
    r        st_trns_mast%rowtype;
    t        st_trns_type%rowtype;
    l_sman   number;
    l_cur    number;
    l_rate   number;
    l_inv    st_trns_mast.invoice_no%type;
    l_desc_a st_trns_mast.desc_a%type;
    l_desc_e st_trns_mast.desc_e%type;
    l_items  number;
    l_srv    number;
    l_net    number;
    l_pw     number := app_act_st.pw;
    l_n      number;
    l_item   varchar2(100);
  begin
    if p_rowid is null or p_request not in ('CREATE', 'SAVE') then return; end if;
    begin
      select * into r from st_trns_mast where rowid = app_act_st.rid(p_rowid);
    exception when no_data_found then return;
    end;
    if not rsv_is_rsv_type(r.trns_type_code) then return; end if;
    t := rsv_type(r.trns_type_code);

    -- CUSTOMER_CODE WHEN-VALIDATE-ITEM: salesman = MIN(AR_CUST_SALESMAN.SALESMAN_CODE) of the customer
    l_sman := r.salesman_code;
    if l_sman is null and r.customer_code is not null then
      select min(salesman_code) into l_sman from ar_cust_salesman where customer_code = r.customer_code;
    end if;
    if l_sman is null and nvl(t.has_salesman, 0) = 1 and r.customer_code is not null then
      app_act_st.err(-20152, 'يجب إدخال رقم المندوب', 'Enter the salesman');
    end if;
    l_cur := r.currency_code; l_rate := r.currency_rate;
    l_inv := r.invoice_no; l_desc_a := r.desc_a; l_desc_e := r.desc_e;
    if p_request = 'CREATE' then
      -- CUSTOMER_CODE / SUPPLIER_CODE WHEN-VALIDATE-ITEM: the document takes the currency of the customer (supplier) and
      -- its AC_CURRENCY rate (only applied on the first save, when the page still has the default currency 1)
      if nvl(r.currency_code, 1) = 1 then
        if r.customer_code is not null then
          select nvl(max(currency_code), 1) into l_cur from customer where code = r.customer_code;
        elsif r.supplier_code is not null then
          select nvl(max(currency_code), 1) into l_cur from supplier where code = r.supplier_code;
        end if;
        if nvl(l_cur, 1) <> 1 then
          select max(rate) into l_rate from ac_currency where currency_code = l_cur;
        else
          l_cur := 1; l_rate := nvl(r.currency_rate, 1);
        end if;
      end if;
      -- TRNS_TYPE_CODE WHEN-VALIDATE-ITEM / PRE-INSERT: INVOICE_NO = type || serial (LPAD 5 with '0');
      -- DESC_A / DESC_E = type description || ' مستند رقم ' / ' Doc No. ' || DOC_NO
      if l_inv is null then
        l_inv := to_char(r.trns_type_code) || lpad(to_char(r.trns_serial), 5, '0');
      end if;
      if l_desc_a is null or l_desc_a = t.desc_a then
        l_desc_a := substr(t.desc_a || ' مستند رقم ' || r.doc_no, 1, 500);
      end if;
      if l_desc_e is null then
        l_desc_e := substr(t.desc_e || ' Doc No. ' || r.doc_no, 1, 500);
      end if;
    end if;
    if nvl(l_sman, -1) <> nvl(r.salesman_code, -1) or nvl(l_cur, -1) <> nvl(r.currency_code, -1)
       or nvl(l_rate, -1) <> nvl(r.currency_rate, -1) or nvl(l_inv, '#') <> nvl(r.invoice_no, '#')
       or nvl(l_desc_a, '#') <> nvl(r.desc_a, '#') or nvl(l_desc_e, '#') <> nvl(r.desc_e, '#')
       or (r.supplier_code is not null and nvl(r.posting_supplier_code, -1) <> r.supplier_code) then
      -- SUPPLIER_CODE WHEN-VALIDATE-ITEM: POSTING_SUPPLIER_CODE := SUPPLIER_CODE
      update st_trns_mast
         set salesman_code = l_sman, currency_code = l_cur, currency_rate = l_rate, invoice_no = l_inv,
             desc_a = l_desc_a, desc_e = l_desc_e,
             posting_supplier_code = case when supplier_code is not null then supplier_code else posting_supplier_code end
       where rowid = app_act_st.rid(p_rowid);
    end if;

    -- item LOV (ITEM2_RG): items of the item groups granted to the user's group (ST_GROUP_PASSWORD)
    if l_pw <> 0 then
      select min(d.item_code) into l_item from st_trns_det d
       where d.trns_type_code = r.trns_type_code and d.trns_serial = r.trns_serial
         and not exists (select 1 from st_group_password g where g.password_number = l_pw and g.group_code = d.group_code);
      if l_item is not null then
        app_act_st.err(-20153, 'ليس لديك صلاحية على مجموعة الصنف: ' || l_item, 'You have no permission on the item group of item ' || l_item);
      end if;
    end if;
    -- DET_DISC_CURR WHEN-VALIDATE-ITEM: the line discount must be below the line value
    select min(item_code) into l_item from st_trns_det
     where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial
       and nvl(det_disc, 0) > 0 and nvl(det_disc, 0) >= nvl(quantity, 0) * nvl(unit_price, 0);
    if l_item is not null then
      app_act_st.err(-20154, 'قيمة الخصم يجب أن تكون أقل من مجموع الأصناف (' || l_item || ')',
                     'Descount Value Must Be Less Than Total Items (' || l_item || ')');
    end if;
    -- totals: TOTAL_VALUE = Σ LINE_TOTAL (QUANTITY * UNIT_PRICE - DET_DISC), SERVICE_TOTAL = Σ UNITS_NO * SERVICE_COST
    select nvl(sum(nvl(quantity, 0) * nvl(unit_price, 0) - nvl(det_disc, 0)), 0), count(*) into l_items, l_n
      from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    select nvl(sum(nvl(units_no, 0) * nvl(service_cost, 0)), 0) into l_srv
      from st_trns_services where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    -- PRE-INSERT / DISC_VAL_CURR WHEN-VALIDATE-ITEM: the invoice discount must be below the invoice value
    if nvl(r.disc_val, 0) > 0 and r.disc_val >= l_items and l_n > 0 then
      app_act_st.err(-20154, 'قيمة الخصم يجب أن تكون أقل من قيمة الفاتورة', 'Disc Value Must Be Less Than Invoice Value');
    end if;
    -- PAYMENT_CURR / ATM_AMMOUNT_CURR WHEN-VALIDATE-ITEM: cash + network paid cannot exceed the net value
    l_net := l_items + l_srv - nvl(r.disc_val, 0) + nvl(r.trnsport_val, 0);
    if p_request = 'SAVE' and nvl(r.payment, 0) + nvl(r.atm_ammount, 0) > l_net then
      app_act_st.err(-20155, 'المدفوع نقدى اكبر من إجمالى الاصناف و الخدمات', 'Cash Payment is greater than Invoice Net Value');
    end if;
    -- UNIT_PRICE_CURR WHEN-VALIDATE-ITEM: UNIT_PRICE = UNIT_PRICE_CURR * rate; the page line price is entered in riyal (UNIT_PRICE,
    -- default by APP_RULES_ST.det_row from the item price list), so the document-currency price follows it
    update st_trns_det d
       set d.unit_price_curr = d.unit_price / nvl(nullif(l_rate, 0), 1)
     where d.trns_type_code = r.trns_type_code and d.trns_serial = r.trns_serial and d.unit_price is not null
       and nvl(d.unit_price_curr, -1) <> d.unit_price / nvl(nullif(l_rate, 0), 1);
    -- GET_NDB_DISC / detail PRE-INSERT (DISC := NDB_DISC): the invoice discount per basic unit of each line
    update st_trns_det d
       set d.disc = case when l_items <> 0 and nvl(d.basic_qty, 0) <> 0 and d.quantity is not null and d.unit_price is not null
                         then nvl(r.disc_val, 0) * (nvl(d.quantity, 0) * nvl(d.unit_price, 0) - nvl(d.det_disc, 0)) / (l_items * d.basic_qty)
                         else 0 end
     where d.trns_type_code = r.trns_type_code and d.trns_serial = r.trns_serial
       and nvl(d.disc, -1) <> case when l_items <> 0 and nvl(d.basic_qty, 0) <> 0 and d.quantity is not null and d.unit_price is not null
                                   then nvl(r.disc_val, 0) * (nvl(d.quantity, 0) * nvl(d.unit_price, 0) - nvl(d.det_disc, 0)) / (l_items * d.basic_qty)
                                   else 0 end;
  end rsv_after_save;

  function rsv_can_invoice (p_rowid in varchar2) return varchar2 is
    r st_trns_mast%rowtype;
  begin
    select * into r from st_trns_mast where rowid = app_act_st.rid(p_rowid);
    return case when rsv_is_rsv_type(r.trns_type_code) and nvl(r.post_flag, 0) = 0 and nvl(r.delete_flag, 0) = 0 then 'Y' else 'N' end;
  exception when others then
    return 'N';
  end rsv_can_invoice;

  -- program unit INSERT_DELIVERY_TRNS: a delivery note (state 3 "مرحلة الشحن") with the lines of the reservation
  procedure rsv_insert_delivery (r in st_trns_mast%rowtype) is
    l_type    number;
    l_serial  number;
    l_dser    number;
    l_note    number;
    l_line    number := 0;
    l_desc_a  varchar2(400);
    l_desc_e  varchar2(400);
  begin
    select max(delivery_trns_type_code) into l_type from st_trns_type where trns_type_code = r.trns_type_code;
    if l_type is null then
      app_act_st.err(-20156, 'يجب ربط حركة الحجز برقم حركة مذكرة تسليم في شاشة أرقام الحركات!!!',
                     'You Must Join Reservation Trans with Delivery Doc Trans No In Trans No Screen');
    end if;
    select nvl(max(trns_serial), 0) + 1 into l_serial from st_delivery_mast where trns_type_code = l_type;
    select nvl(max(delivery_serial), 0) + 1 into l_dser from st_delivery_mast
     where trns_type_code = l_type and order_trns_type_code = r.order_trns_type_code and order_trns_serial = r.order_trns_serial;
    -- NOTE_NO: not recoverable from the compiled form (variable V_NOTE_NO); the delivery screen's own number is used
    -- (GET_NEXT_DELIVERY_DOC_NO, variant of this installation: MAX(NOTE_NO) + 1 per delivery type)
    select nvl(max(nvl(note_no, 0)), 0) + 1 into l_note from st_delivery_mast where trns_type_code = l_type;
    l_desc_a := 'أمر التسليم رقم ' || l_type || ' / ' || l_serial || ' من أمر بيع رقم ' || r.order_trns_type_code || ' / ' || r.order_trns_serial;
    l_desc_e := 'Delivery Document No. ' || l_type || ' / ' || l_serial || ' From Sales Order No. ' || r.order_trns_type_code || ' / ' || r.order_trns_serial;
    insert into st_delivery_mast (trns_type_code, trns_serial, desc_a, desc_e, delivery_serial, delivery_date, store_code, note_no,
                                  customer_code, supplier_code, salesman_code, delivary_state, order_trns_type_code, order_trns_serial,
                                  disc_val, trnsport_val)
    values (l_type, l_serial, substr(l_desc_a, 1, 200), substr(l_desc_e, 1, 200), l_dser, r.trns_date, r.store_code, l_note,
            r.customer_code, r.supplier_code, r.salesman_code, 3, r.order_trns_type_code, r.order_trns_serial,
            r.disc_val, r.trnsport_val);
    for d in (select * from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial order by item_serial) loop
      l_line := l_line + 1;
      insert into st_delivery_det (trns_type_code, trns_serial, serial, item_group_code, item_code, unit_code, delivered_qty,
                                   unit_price, unit_price_curr, bonus, item_confg_id)
      values (l_type, l_serial, l_line, d.group_code, d.item_code, d.unit_code, d.quantity,
              d.unit_price, d.unit_price_curr, d.bonus, d.item_confg_id);
    end loop;
  end rsv_insert_delivery;

  function rsv_to_invoice (p_rowid in varchar2) return varchar2 is
    r        st_trns_mast%rowtype;
    l_issue  number;
    l_serial number;
  begin
    begin
      select * into r from st_trns_mast where rowid = app_act_st.rid(p_rowid) for update;
    exception when no_data_found then
      app_act_st.err(-20150, 'الحركة غير موجودة، أعد تحميل الصفحة', 'The document no longer exists, reload the page');
    end;
    if not rsv_is_rsv_type(r.trns_type_code) then
      app_act_st.err(-20150, 'الحركة ليست حركة حجز', 'The document is not a reservation');
    end if;
    -- CONV_TO_INVOICE: the sales type linked to the reservation type
    select max(sales_trns_type_code) into l_issue from st_trns_type where trns_type_code = r.trns_type_code;
    if l_issue is null then
      app_act_st.err(-20157, 'يجب تعريف رقم حركة المبيعات فى شاشة أنواع الحركات', 'You Must Define Sales Trans In Trans Types Screen');
    end if;
    app_rules_sa.set_bypass(true);
    begin
      rsv_insert_delivery(r);
      select nvl(max(trns_serial), 0) + 1 into l_serial from st_trns_mast where trns_type_code = l_issue;
      -- the legacy dropped the child foreign keys (FORMS_DDL) around these updates; they do not exist on this database
      update st_trns_mast set trns_type_code = l_issue, trns_serial = l_serial
       where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      update st_trns_det set trns_type_code = l_issue, trns_serial = l_serial
       where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      update st_trns_stand_det set trns_type_code = l_issue, trns_serial = l_serial
       where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      update st_trns_services set trns_type_code = l_issue, trns_serial = l_serial
       where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      app_rules_sa.set_bypass(false);
    exception when others then
      app_rules_sa.set_bypass(false);
      raise;
    end;
    app_act_st.set_message('تـم عمـل الفـاتـورة بنـجــاح (' || l_issue || '/' || l_serial || ')',
                           'Invoice Made Successfully (' || l_issue || '/' || l_serial || ')');
    return p_rowid;                            -- the same row, now a sales invoice
  end rsv_to_invoice;

  function rsv_info (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    r       st_trns_mast%rowtype;
    l_items number;
    l_srv   number;
    l_net   number;
  begin
    select * into r from st_trns_mast where rowid = app_act_st.rid(p_rowid);
    select nvl(sum(nvl(quantity, 0) * nvl(unit_price, 0) - nvl(det_disc, 0)), 0) into l_items
      from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    select nvl(sum(nvl(units_no, 0) * nvl(service_cost, 0)), 0) into l_srv
      from st_trns_services where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    l_net := l_items + l_srv - nvl(r.disc_val, 0) + nvl(r.trnsport_val, 0);
    return case upper(p_what)
             when 'TOTAL'  then rsv_fmt(l_items)
             when 'SRV'    then rsv_fmt(l_srv)
             when 'NET'    then rsv_fmt(l_net)
             when 'CHANGE' then case when r.payment is not null or r.atm_ammount is not null
                                     then rsv_fmt(nvl(r.payment, 0) + nvl(r.atm_ammount, 0) - l_net) end
           end;
  exception when others then
    return null;
  end rsv_info;

  -- =================================================================================== ST_DELIVERY
  function dlv_note_count (p_rowid in varchar2, p_type in varchar2, p_note_no in varchar2) return number is
    l_n number;
  begin
    if app_act_st.num(p_note_no) is null or app_act_st.num(p_type) is null then return 0; end if;
    -- CHECK_DOC_NO: SELECT COUNT(1) FROM ST_DELIVERY_MAST TM, ST_TRNS_TYPE TT WHERE .. EFFECT 7 .. TRNS_TYPE 31 .. NOTE_NO = :b2
    select count(*) into l_n
      from st_delivery_mast tm, st_trns_type tt
     where tm.trns_type_code = tt.trns_type_code and tm.trns_type_code = app_act_st.num(p_type)
       and nvl(tt.effect, 0) = 7 and nvl(tt.trns_type, 0) = 31 and tm.note_no = app_act_st.num(p_note_no)
       and (p_rowid is null or tm.rowid <> app_act_st.rid(p_rowid));
    return l_n;
  end dlv_note_count;

  function dlv_doc_rep return number is
    l number;
  begin
    select nvl(max(doc_repeat), 0) into l from st_basic;          -- GET_USER_SEC: VAR.DOC_REP
    return l;
  end dlv_doc_rep;

  function dlv_note_error (p_rowid in varchar2, p_type in varchar2, p_note_no in varchar2) return varchar2 is
  begin
    if dlv_doc_rep = 2 and dlv_note_count(p_rowid, p_type, p_note_no) > 0 then
      return app_act_st.m('لا يمكن تكرار المستند', 'Cannot repeat Doc number');
    end if;
    return null;
  end dlv_note_error;

  function dlv_note_warning (p_rowid in varchar2, p_type in varchar2, p_note_no in varchar2) return varchar2 is
  begin
    if dlv_doc_rep = 3 and dlv_note_count(p_rowid, p_type, p_note_no) > 0 then
      return app_act_st.m('رقم المستند مكرر', 'The Document Number Is Repeated');
    end if;
    return null;
  end dlv_note_warning;

  procedure dlv_after_delete (p_type in varchar2, p_serial in varchar2) is
    l_type   number := app_act_st.num(p_type);
    l_serial number := app_act_st.num(p_serial);
    l_it     number;
    l_is     number;
  begin
    if l_type is null or l_serial is null then return; end if;
    -- master KEY-DELREC / PRE-DELETE: "يجب حذف فاتورة البيع اولا"; ST_MERG_DET: "لا يمكن حذف مذكرة التسليم لوجود فاتورة مبيعات عليها"
    dlv_invoice_of(l_type, l_serial, l_it, l_is);
    if l_it is not null then
      app_act_st.err(-20158, 'يجب حذف فاتورة البيع اولا (' || l_it || '/' || l_is || ')', 'Delete the sales invoice first (' || l_it || '/' || l_is || ')');
    end if;
    if dlv_merged(l_type, l_serial) then
      app_act_st.err(-20158, 'لا يمكن حذف مذكرة التسليم لوجود فاتورة مبيعات عليها', 'Sales Invoice Found...Can''t delete record');
    end if;
  end dlv_after_delete;

  function dlv_can_invoice (p_rowid in varchar2) return varchar2 is
    dm   st_delivery_mast%rowtype;
    l_it number;
    l_is number;
  begin
    select * into dm from st_delivery_mast where rowid = app_act_st.rid(p_rowid);
    dlv_invoice_of(dm.trns_type_code, dm.trns_serial, l_it, l_is);
    return case when nvl(dm.delete_flag, 0) = 0 and l_it is null then 'Y' else 'N' end;
  exception when others then
    return 'N';
  end dlv_can_invoice;

  -- INV_TRNS: SELECT SALES_TRNS_TYPE_CODE FROM ST_TRNS_TYPE WHERE TRNS_TYPE_CODE = :TRNS_TYPE_CODE
  function dlv_first_sales_type (p_rowid in varchar2) return number is
    l number;
  begin
    select max(t.sales_trns_type_code) into l
      from st_delivery_mast dm, st_trns_type t
     where dm.rowid = app_act_st.rid(p_rowid) and t.trns_type_code = dm.trns_type_code;
    return l;
  exception when others then
    return null;
  end dlv_first_sales_type;

  -- program unit INSERT_DET: one invoice line (COST_FLAG 1, UNIT_COST null, FREIGHT .. OTHERS 0)
  procedure dlv_insert_det (d in st_trns_det%rowtype, p_factor in number) is
  begin
    insert into st_trns_det (trns_type_code, trns_serial, item_serial, trns_date, date_serial, delete_flag, store_code, group_code,
                             item_code, item_confg_id, quantity, basic_qty, bonus, unit_code, unit_cost, unit_price, unit_price_curr,
                             cost_flag, disc, det_disc, freight, customs, transport, insurance, commission, others)
    values (d.trns_type_code, d.trns_serial, d.item_serial, trunc(d.trns_date), d.date_serial, 0, d.store_code, d.group_code,
            d.item_code, d.item_confg_id, d.quantity, (nvl(d.quantity, 0) + nvl(d.bonus, 0)) * nvl(p_factor, 1), d.bonus, d.unit_code,
            null, d.unit_price, d.unit_price_curr, 1, d.disc, d.det_disc, 0, 0, 0, 0, 0, 0);
  end dlv_insert_det;

  function dlv_to_invoice (p_rowid in varchar2, p_sales_type in number, p_date in date) return varchar2 is
    dm        st_delivery_mast%rowtype;
    so        st_sales_order%rowtype;
    t         st_trns_type%rowtype;
    dr        st_trns_det%rowtype;
    l_it      number;
    l_is      number;
    l_serial  number;
    l_dser    number;
    l_doc     number;
    l_inv     st_trns_mast.invoice_no%type;
    l_items   number;
    l_net     number;
    l_rate    number;
    l_cur     number;
    l_n       number;
    l_neg     number;
    l_factor  number;
    l_bal     number;
    l_item    number := 0;
    l_rest_q  number;
    l_rest_b  number;
    l_avail   number;
    l_take_q  number;
    l_take_b  number;
    l_total   number;
    l_totq    number;
    l_rowid   rowid;
  begin
    begin
      select * into dm from st_delivery_mast where rowid = app_act_st.rid(p_rowid) for update;
    exception when no_data_found then
      app_act_st.err(-20150, 'يجب حفظ السجل أولا', 'You must save changes first');
    end;
    -- INV_TRNS / MAKE_INV checks in the legacy order
    if nvl(dm.delivary_state, 0) <> 3 then
      app_act_st.err(-20159, 'لابد ان تكون حالة المذكرة في مرحلة الشحن لتحويلها الي فاتورة',
                     'THE DELIVARY STATE MUST BE IN SHIPPED MODE TO TRANSFER TO INVOICE');
    end if;
    dlv_invoice_of(dm.trns_type_code, dm.trns_serial, l_it, l_is);
    if l_it is not null then
      app_act_st.err(-20159, 'مذكرة التسليم تم تحويلها إلي فاتورة مبيعات', 'Delivery Document Posted To Sales Invoice');
    end if;
    if nvl(dm.delete_flag, 0) = 1 then
      app_act_st.err(-20159, 'المذكرة ملغاه بالفعل', 'The Delivery Document Already Canceld');
    end if;
    if p_sales_type is null or p_date is null then
      app_act_st.err(-20159, 'يجب إدخال رقم حركة فاتورة المبيعات و تاريخ الفاتورة', 'Sales Invoice Trns And Invoice Date Must Be Entered ');
    end if;
    -- SALES_DATE WHEN-VALIDATE-ITEM
    if trunc(p_date) < trunc(dm.delivery_date) then
      app_act_st.err(-20159, 'تاريخ الفاتورة يجب أن يكون أكبر من يساوى تارخ الإستلام', 'Invoice Date Must Be Greater Than Or Equal Deliverd Date ');
    end if;
    dlv_check_date(p_date);
    -- SALES_TRNS_TYPE LOV (SALES_TRNS_TYPE_RG): EFFECT 2 types of the note's store, granted to the group with FLAG = 1
    t := rsv_type(p_sales_type);
    if nvl(t.effect, 0) <> 2 or nvl(t.store_code, -1) <> nvl(dm.store_code, -2) then
      app_act_st.err(-20159, 'نوع الحركة غير مسموح به: ' || p_sales_type, 'Transaction type not allowed: ' || p_sales_type);
    end if;
    if app_act_st.pw <> 0 then
      select count(*) into l_n from st_trnstype_password
       where password_number = app_act_st.pw and trns_type_code = p_sales_type and flag = 1;
      if l_n = 0 then
        app_act_st.err(-20159, 'نوع الحركة غير مسموح به: ' || p_sales_type, 'Transaction type not allowed: ' || p_sales_type);
      end if;
    end if;

    -- INSERT_ISSUE_TRNS: header (GET_SALES_TRNS_SERIAL, DATE_SERIAL from ST_TRNS_MAST_IN, DEMO_TRNS_* of the sales order)
    begin
      select * into so from st_sales_order where trns_type_code = dm.order_trns_type_code and trns_serial = dm.order_trns_serial;
    exception when no_data_found then null;
    end;
    l_cur := nvl(so.currency_code, 1);
    l_rate := nvl(so.currency_rate, 1);
    select nvl(max(trns_serial), 0) + 1 into l_serial from st_trns_mast where trns_type_code = p_sales_type;
    select nvl(max(date_serial), 0) + 1 into l_dser from st_trns_mast where trns_date = trunc(p_date);
    -- DOC_NO: the note number, else GET_NEXT_SALES_DOC_NO (MAX(DOC_NO) + 1 of the sales invoices);
    -- INVOICE_NO: type || serial (LPAD 5 with '0')
    if dm.note_no is not null then
      l_doc := dm.note_no;
    else
      select max(nvl(tm.doc_no, 0)) + 1 into l_doc from st_trns_mast tm, st_trns_type tt
       where tm.trns_type_code = tt.trns_type_code and nvl(tt.effect, 0) = 2 and nvl(tt.trns_type, 0) = 2;
      l_doc := nvl(l_doc, 1);
    end if;
    l_inv := to_char(p_sales_type) || lpad(to_char(l_serial), 5, '0');
    -- TOT_VAL = NET_VALUE_CURR: (Σ (UNIT_PRICE * DELIVERED_QTY - DET_DISC) - DISC_VAL + TRNSPORT_VAL) / rate
    select nvl(sum(nvl(unit_price, 0) * nvl(delivered_qty, 0) - nvl(det_disc, 0)), 0) into l_items
      from st_delivery_det where trns_type_code = dm.trns_type_code and trns_serial = dm.trns_serial;
    l_net := (l_items - nvl(dm.disc_val, 0) + nvl(dm.trnsport_val, 0)) / nullif(l_rate, 0);
    select nvl(max(neg_sale_balance), 0) into l_neg from st_basic;

    app_rules_sa.set_bypass(true);
    begin
      insert into st_trns_mast (trns_type_code, trns_serial, trns_date, date_serial, store_code, delete_flag, currency_code, currency_rate,
                                customer_code, supplier_code, salesman_code, desc_a, desc_e, doc_no, invoice_no, disc_val, trnsport_val,
                                delivery_trns_type_code, delivery_trns_serial, order_trns_type_code, order_trns_serial,
                                demo_trns_type_code, demo_trns_serial, insert_user, insert_date, post_flag, po_no, tot_val)
      values (p_sales_type, l_serial, trunc(p_date), l_dser, dm.store_code, 0, l_cur, l_rate,
              dm.customer_code, dm.supplier_code, dm.salesman_code,
              substr('فاتورة مبيعات رقم ' || p_sales_type || '/' || l_serial || ' من مذكرة التسليم  ' || dm.trns_type_code || '/' || dm.trns_serial, 1, 500),
              substr('Sales Invoice No. ' || p_sales_type || '/' || l_serial || ' From Delivery document.  ' || dm.trns_type_code || '/' || dm.trns_serial, 1, 500),
              l_doc, l_inv, dm.disc_val, dm.trnsport_val, dm.trns_type_code, dm.trns_serial, dm.order_trns_type_code, dm.order_trns_serial,
              so.demo_trns_type_code, so.demo_trns_serial, app_act_st.usr, sysdate, 0, dm.note_no, l_net)
      returning rowid, date_serial into l_rowid, l_dser;

      -- lines: the note's lot when given (with the balance check of INSERT_ISSUE_TRNS), otherwise DEVIDE_CONFGS
      for d in (select * from st_delivery_det where trns_type_code = dm.trns_type_code and trns_serial = dm.trns_serial order by serial) loop
        l_factor := dlv_factor(d.item_group_code, d.item_code, d.unit_code);
        dr := null;
        dr.trns_type_code := p_sales_type; dr.trns_serial := l_serial; dr.trns_date := trunc(p_date); dr.date_serial := l_dser;
        dr.store_code := dm.store_code; dr.group_code := d.item_group_code; dr.item_code := d.item_code; dr.unit_code := d.unit_code;
        dr.unit_price := d.unit_price; dr.unit_price_curr := d.unit_price_curr; dr.disc := 0; dr.det_disc := d.det_disc;
        if d.item_confg_id is not null then
          l_item := l_item + 1;
          dr.item_serial := l_item; dr.item_confg_id := d.item_confg_id; dr.quantity := d.delivered_qty; dr.bonus := d.bonus;
          if l_neg = 0 then
            l_bal := get_balance_confg(dm.store_code, d.item_group_code, d.item_code, d.item_confg_id, trunc(p_date), l_dser, l_item);
            if nvl(l_bal, 0) < (nvl(d.delivered_qty, 0) + nvl(d.bonus, 0)) * l_factor then
              app_act_st.err(-20160, 'رصيــد الصنف ' || d.item_code || ' فى هذا التاريخ لا يسمــح  .... !!! رصيــد الصنف فى هذا التاريخ='
                                     || round(nvl(l_bal, 0) / l_factor, 2),
                             'Item ' || d.item_code || ' Balance In This Date Is Insufficient !!! Item Balance in this date equals '
                                     || round(nvl(l_bal, 0) / l_factor, 2));
            end if;
          end if;
          dlv_insert_det(dr, l_factor);
        else
          -- DEVIDE_CONFGS: lots by expiry, the quantity a lot may give = GET_MIN_BALANCE_CONFG_AFTER (no later movement negative);
          -- quantity first, then the free goods
          l_rest_q := nvl(d.delivered_qty, 0) * l_factor;
          l_rest_b := nvl(d.bonus, 0) * l_factor;
          l_total := 0;
          for c in (select item_confg_id from st_item_confg where group_code = d.item_group_code and item_code = d.item_code
                     order by expire_date, item_confg_id) loop
            exit when l_rest_q + l_rest_b <= 0;
            l_avail := greatest(nvl(get_min_balance_confg_after(dm.store_code, d.item_group_code, d.item_code, c.item_confg_id,
                                                                trunc(p_date), l_dser, l_item + 1), 0), 0);
            l_total := l_total + l_avail;
            if l_avail > 0 then
              l_take_q := least(l_rest_q, l_avail);
              l_take_b := least(l_rest_b, l_avail - l_take_q);
              if l_take_q + l_take_b > 0 then
                l_item := l_item + 1;
                dr.item_serial := l_item; dr.item_confg_id := c.item_confg_id;
                dr.quantity := l_take_q / l_factor; dr.bonus := l_take_b / l_factor;
                dlv_insert_det(dr, l_factor);
                l_rest_q := l_rest_q - l_take_q;
                l_rest_b := l_rest_b - l_take_b;
              end if;
            end if;
          end loop;
          if l_rest_q + l_rest_b > 0 and l_neg = 0 then
            app_act_st.err(-20160, 'أقصى كمية يمكن إخراجها حتى لا تتعارض مع الحركات التالية = ' || round(l_total / l_factor, 2) || ' للصنف ' || d.item_code,
                           'Maximum Amount Can Be Sold Without Conflicting With Next Transactions = ' || round(l_total / l_factor, 2) || ' Item ' || d.item_code);
          end if;
        end if;
      end loop;

      -- UPDATE_DISC: the note discount spread per basic unit of the invoice lines (value share, as GET_NDB_DISC)
      if nvl(dm.disc_val, 0) > 0 then
        select sum(nvl(basic_qty, 0)), sum(nvl(quantity, 0) * nvl(unit_price, 0)) into l_totq, l_total
          from st_trns_det where trns_type_code = p_sales_type and trns_serial = l_serial;
        update st_trns_det d
           set d.disc = case when nvl(l_total, 0) <> 0 and nvl(d.basic_qty, 0) <> 0
                             then dm.disc_val * nvl(d.quantity, 0) * nvl(d.unit_price, 0) / (l_total * d.basic_qty)
                             when nvl(l_totq, 0) <> 0 then dm.disc_val / l_totq
                             else 0 end
         where d.trns_type_code = p_sales_type and d.trns_serial = l_serial;
      end if;
      app_rules_sa.set_bypass(false);
    exception when others then
      app_rules_sa.set_bypass(false);
      raise;
    end;
    app_act_st.set_message('تم عمل اخراج رقم ' || p_sales_type || '/' || l_serial,
                           'Issue Inserted No. ' || p_sales_type || '/' || l_serial);
    return rowidtochar(l_rowid);
  end dlv_to_invoice;

  function dlv_can_cancel (p_rowid in varchar2) return varchar2 is
    dm st_delivery_mast%rowtype;
    l_page number;
  begin
    select * into dm from st_delivery_mast where rowid = app_act_st.rid(p_rowid);
    if nvl(dm.delete_flag, 0) = 1 then return 'N'; end if;
    l_page := app_act_st.num(v('APP_PAGE_ID'));
    if l_page is not null and not app_sec.can_page(l_page, 'U') then return 'N'; end if;
    return 'Y';
  exception when others then
    return 'N';
  end dlv_can_cancel;

  function dlv_cancel (p_rowid in varchar2) return varchar2 is
    dm st_delivery_mast%rowtype;
  begin
    begin
      select * into dm from st_delivery_mast where rowid = app_act_st.rid(p_rowid) for update;
    exception when no_data_found then
      app_act_st.err(-20150, 'يجب حفظ السجل أولا', 'You must save changes first');
    end;
    -- DEL_BUTTON WHEN-BUTTON-PRESSED
    if nvl(dm.delete_flag, 0) = 1 then
      app_act_st.err(-20161, 'المذكرة ملغاه بالفعل', 'The Delivery Document Already Canceld');
    end if;
    if dlv_merged(dm.trns_type_code, dm.trns_serial) then
      app_act_st.err(-20161, 'لا يمكن حذف مذكرة التسليم لوجود فاتورة مبيعات عليها', 'Sales Invoice Found...Can''t delete record');
    end if;
    -- the issue generated from the note (SALES_TRNS_TYPE_CODE / SERIAL of the POST-QUERY) is deleted
    for i in (select m.trns_type_code, m.trns_serial from st_trns_mast m
               where m.delivery_trns_type_code = dm.trns_type_code and m.delivery_trns_serial = dm.trns_serial and nvl(m.delete_flag, 0) = 0
              union
              select d.trns_type_code, d.trns_serial from st_trns_det d
               where d.oper_trns_type_code = dm.trns_type_code and d.oper_trns_serial = dm.trns_serial and nvl(d.delete_flag, 0) = 0) loop
      delete from st_trns_det where trns_type_code = i.trns_type_code and trns_serial = i.trns_serial;
      delete from st_trns_mast where trns_type_code = i.trns_type_code and trns_serial = i.trns_serial;
    end loop;
    update st_delivery_mast set delete_flag = 1 where rowid = app_act_st.rid(p_rowid);
    app_act_st.set_message('تم إلغاء مذكرة التسليم', 'Successful canceled delivery document');
    return p_rowid;
  end dlv_cancel;

  function dlv_info (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    dm      st_delivery_mast%rowtype;
    l_it    number;
    l_is    number;
    l_items number;
    l_limit number;
    l_bal   number;
    l_what  varchar2(30) := upper(p_what);
  begin
    select * into dm from st_delivery_mast where rowid = app_act_st.rid(p_rowid);
    if l_what = 'INV' then
      dlv_invoice_of(dm.trns_type_code, dm.trns_serial, l_it, l_is);
      return case when l_it is not null then l_it || '/' || l_is end;
    end if;
    if l_what in ('TOTAL', 'NET') then
      select nvl(sum(nvl(unit_price, 0) * nvl(delivered_qty, 0) - nvl(det_disc, 0)), 0) into l_items
        from st_delivery_det where trns_type_code = dm.trns_type_code and trns_serial = dm.trns_serial;
      return rsv_fmt(case when l_what = 'TOTAL' then l_items else l_items - nvl(dm.disc_val, 0) + nvl(dm.trnsport_val, 0) end);
    end if;
    -- POST-QUERY: CREDIT_LIMIT, CRN_BAL_TOTAL ("الرصيد الجارى") and the remaining credit ("متبقى الإئتمان"); shown to users
    -- allowed to see balances (WHEN-NEW-FORM-INSTANCE reads USERS.ALLOW_VIEW_BALANCE for these items)
    if dm.customer_code is null or dlv_user_flag('ALLOW_VIEW_BALANCE') <> 1 then return null; end if;
    select max(credit_limit) into l_limit from customer where code = dm.customer_code;
    select nvl(sum(decode(att.effect, 0, (a.total_value * a.currency_rate), 1, -1 * ((a.total_value + a.disc_value) * a.currency_rate))), 0)
      into l_bal
      from ar_maintrns a, ar_trnstype att
     where a.customer_id = dm.customer_code and a.trns_id = att.id;
    return case l_what
             when 'LIMIT'  then rsv_fmt(l_limit)
             when 'BAL'    then rsv_fmt(l_bal)
             when 'REMAIN' then rsv_fmt(nvl(l_limit, 0) - l_bal)
           end;
  exception when others then
    return null;
  end dlv_info;
  -- =================================================================================== ST_TRANSFER_FROM / ST_TRANSFER_TO / ST_TRANSFER_REQUEST / ST_OPEN_BALANCE / ST_ADJUST_IN / ST_ADJUST_OUT
  function trf_mast (p_rowid in varchar2) return st_trns_mast%rowtype is
    r st_trns_mast%rowtype;
  begin
    select * into r from st_trns_mast where rowid = app_act_st.rid(p_rowid);
    return r;
  exception when no_data_found then
    return null;
  end trf_mast;

  function trf_fmt (p in number, p_dec in pls_integer default 2) return varchar2 is
  begin
    if p is null then return null; end if;
    return to_char(p, 'FM999G999G999G999G990' || case when p_dec > 0 then 'D' || rpad('0', p_dec, '0') end);
  end trf_fmt;

  function trf_effect (p_type in number) return number is
    l number;
  begin
    select max(effect) into l from st_trns_type where trns_type_code = p_type;
    return l;
  end trf_effect;

  function trf_doc_repeat return number is
    l number;
  begin
    select nvl(max(doc_repeat), 0) into l from st_basic;
    return l;
  end trf_doc_repeat;

  -- DOC_NO unchanged on an existing document: the legacy WHEN-VALIDATE-ITEM did not fire
  function trf_same_doc_no (p_rowid in varchar2, p_doc_no in number, p_request in boolean default false) return boolean is
    l number;
  begin
    if p_rowid is null then return false; end if;
    if p_request then
      select max(doc_no) into l from st_trns_mast_request where rowid = app_act_st.rid(p_rowid);
    else
      select max(doc_no) into l from st_trns_mast where rowid = app_act_st.rid(p_rowid);
    end if;
    return l = p_doc_no;
  end trf_same_doc_no;

  function trf_user_flag (p_col in varchar2) return number is
    l number;
    u number := nvl(app_act_st.usr, -1);
  begin
    if u = 0 then return 1; end if;
    execute immediate 'select nvl(max(' || dbms_assert.simple_sql_name(p_col) || '), 0) from users where users_code = :u' into l using u;
    return l;
  end trf_user_flag;

  -- legacy SHOW_COST (ST_BASIC) and USERS.ALLOW_VIEW_COST decide whether cost values are shown
  function trf_can_view_cost return boolean is
    l number;
  begin
    select nvl(max(show_cost), 0) into l from st_basic;
    return l = 1 and trf_user_flag('ALLOW_VIEW_COST') = 1;
  end trf_can_view_cost;

  -- transfer received: receiving date stamped or a live receipt document exists
  function trf_received (p_serial in number, p_from in number) return boolean is
    l_d date;
    l_n number;
  begin
    if p_serial is null then return false; end if;
    select max(trnsfer_receiving_date) into l_d from st_trnsfer
     where trnsfer_serial = p_serial and trnsfer_from_store = p_from and nvl(delete_flag, 0) = 0;
    select count(*) into l_n
      from st_trns_mast m, st_trns_type t
     where t.trns_type_code = m.trns_type_code and t.effect = 6 and t.trns_type = 9
       and m.trnsfer_serial = p_serial and m.trnsfer_from_store = p_from and nvl(m.delete_flag, 0) = 0;
    return l_d is not null or l_n > 0;
  end trf_received;

  -- lowest running balance of a lot from the position of a document onwards, all lines of that document removed
  -- (legacy detail KEY-DELREC: GET_BALANCE_CONFG before the line + UPDATE_NEXT_TRNS_CONFG, run for every line of the
  -- deleted document)
  function trf_lot_min_without (p_store in number, p_confg in number, p_type in number, p_serial in number,
                                p_date in date, p_dser in number) return number is
    l_run number;
    l_min number;
  begin
    select nvl(sum(case when t.effect in (1, 4, 6) then 1 when t.effect in (2, 3, 5) then -1 else 0 end * nvl(c.basic_qty, 0)), 0)
      into l_run
      from st_trns_det_cost c, st_trns_type t
     where t.trns_type_code = c.trns_type_code
       and c.store_code = p_store and c.item_confg_id = p_confg and nvl(c.delete_flag, 0) = 0
       and not (c.trns_type_code = p_type and c.trns_serial = p_serial)
       and (c.trns_date < p_date or (c.trns_date = p_date and c.date_serial < p_dser));
    l_min := l_run;
    for r in (select case when t.effect in (1, 4, 6) then 1 when t.effect in (2, 3, 5) then -1 else 0 end * nvl(c.basic_qty, 0) q
                from st_trns_det_cost c, st_trns_type t
               where t.trns_type_code = c.trns_type_code
                 and c.store_code = p_store and c.item_confg_id = p_confg and nvl(c.delete_flag, 0) = 0
                 and not (c.trns_type_code = p_type and c.trns_serial = p_serial)
                 and (c.trns_date > p_date or (c.trns_date = p_date and c.date_serial >= p_dser))
               order by c.trns_date, c.date_serial, c.item_serial)
    loop
      l_run := l_run + r.q;
      if l_run < l_min then l_min := l_run; end if;
    end loop;
    return l_min;
  end trf_lot_min_without;

  -- common soft-delete check of the ST_TRNS_MAST screens (master KEY-DELREC of the legacy forms)
  function trf_doc_del_check (p_form in varchar2, p_rowid in varchar2) return varchar2 is
    r     st_trns_mast%rowtype := trf_mast(p_rowid);
    l_eff number;
    l_min number;
  begin
    if r.trns_type_code is null then
      return app_act_st.m('الحركة غير موجودة، أعد تحميل الصفحة', 'The document no longer exists, reload the page');
    end if;
    if nvl(r.post_flag, 0) = 1 then
      return app_act_st.m('لا يمكن حذف حركات مرحلة', 'You cann''t delete Posted transactions');
    end if;
    if p_form = 'ST_TRANSFER_FROM' and trf_received(r.trnsfer_serial, r.store_code) then
      return app_act_st.m('تم استلام التحويل ولا يمكن الحذف', 'The transfer has been received and cannot be deleted');
    end if;
    l_eff := trf_effect(r.trns_type_code);
    if l_eff in (1, 4, 6) then
      -- removing a receipt must not make a later transaction of the lot negative
      for d in (select distinct nvl(store_code, r.store_code) store_code, item_confg_id, item_code
                  from st_trns_det
                 where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and item_confg_id is not null
                   and nvl(delete_flag, 0) = 0)
      loop
        l_min := trf_lot_min_without(d.store_code, d.item_confg_id, r.trns_type_code, r.trns_serial, r.trns_date, r.date_serial);
        if l_min < 0 then
          return app_act_st.m('الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها. الصنف ' || d.item_code,
                              'Balance Not Allow Other Transaction Conflict With This Transaction. Item ' || d.item_code);
        end if;
      end loop;
    end if;
    return null;
  end trf_doc_del_check;

  -- legacy duplicate DOC_NO question (DOC_REPEAT = 1; with DOC_REPEAT = 0 the page validation refuses instead)
  function trf_dup_msg return varchar2 is
  begin
    return app_act_st.m('رقم المستند مكرر', 'The document number is repeated');
  end trf_dup_msg;

  -- Excel cells: numbers with separators, dates as DD/MM/YYYY (legacy TO_DATE(.., 'DD/MM/YYYY')), YYYY-MM-DD (date cells
  -- read by APEX_DATA_PARSER) or an Excel serial day number
  function trf_xl_num (p in varchar2) return number is
  begin
    return to_number(trim(replace(p, ',', '')) default null on conversion error);
  end trf_xl_num;

  function trf_xl_date (p in varchar2) return date is
    s varchar2(100) := trim(p);
    n number;
  begin
    if s is null then return null; end if;
    n := trf_xl_num(s);
    if n is not null and n between 1 and 2958465 and instr(s, '/') = 0 and instr(s, '-') = 0 then
      return date '1899-12-30' + trunc(n);
    end if;
    if regexp_like(s, '^\d{4}-\d{1,2}-\d{1,2}') then
      return to_date(substr(s, 1, 10) default null on conversion error, 'YYYY-MM-DD');
    end if;
    return nvl(to_date(regexp_substr(s, '^[0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{4}') default null on conversion error, 'DD/MM/YYYY'),
               to_date(s default null on conversion error, 'DD/MM/YYYY'));
  end trf_xl_date;

  function trf_err_text (p in varchar2) return varchar2 is
  begin
    return regexp_replace(regexp_replace(p, '^ORA-[0-9]+: ', ''), chr(10) || '.*$', '', 1, 0, 'n');
  end trf_err_text;

  procedure trf_add_line (p_log in out nocopy varchar2, p_line in varchar2) is
  begin
    if length(p_log) > 3000 then
      if p_log not like '%...' then p_log := p_log || chr(10) || '...'; end if;
      return;
    end if;
    p_log := p_log || chr(10) || p_line;
  end trf_add_line;

  -- receipt line with lot parameters (ST_OPEN_BALANCE / ST_adjust_IN detail PRE-INSERT + GET_THE_CONFIG): the lot number
  -- (text), expiry date, sales price and discount ratio find or create the lot with GET_CONFG_ID(.., TRUE)
  function trf_lot_line (p_form in varchar2, p_rowid in varchar2, p_item in varchar2, p_unit in number, p_qty in number,
                         p_lot in varchar2, p_expiry in date, p_price in number, p_cost in number, p_disc in number,
                         p_prod in date) return varchar2 is
    r      st_trns_mast%rowtype;
    l_grp  number;
    l_n    number;
    l_unit number := p_unit;
    l_fact number;
    l_expf number;
    l_supp number;
    l_lot  varchar2(800) := trim(p_lot);
    l_conf number;
    l_cost number := p_cost;
    l_ser  number;
    l_disc number := nvl(p_disc, 0);
  begin
    begin
      select * into r from st_trns_mast where rowid = app_act_st.rid(p_rowid) for update;
    exception when no_data_found then
      app_act_st.err(-20184, 'لابد من الحفظ أولا', 'You Should Save First');
    end;
    if nvl(r.post_flag, 0) = 1 or nvl(r.delete_flag, 0) != 0 then
      app_act_st.err(-20184, 'لا يمكن تعديل حركة مرحلة', 'A posted transaction cannot be changed');
    end if;
    select count(*), min(item_group_code) into l_n, l_grp from st_item where item_code = trim(p_item) and nvl(stop_flag, 0) = 0;
    if l_n = 0 then
      app_act_st.err(-20184, 'صنف غير موجود', 'Item doesn''t exist');
    elsif l_n > 1 then
      app_act_st.err(-20184, 'صنف مكرر', 'Repeated item');
    end if;
    if l_unit is null then
      select min(unit_code) into l_unit from st_item_unit where group_code = l_grp and item_code = trim(p_item) and nvl(basic_unit, 0) = 1;
    end if;
    select max(factor) into l_fact from st_item_unit where group_code = l_grp and item_code = trim(p_item) and unit_code = l_unit;
    if l_fact is null then
      app_act_st.err(-20184, 'الوحدة غير معرفة لهذا الصنف', 'The unit is not defined for this item');
    end if;
    select nvl(max(expire_flag), 0) into l_expf from st_item_group where item_group_code = l_grp;
    -- PRE-INSERT: IF :LOT_NUMBER IS NULL OR :EXPIRE_DATE IS NULL [OR :PRODUCTION_DATE IS NULL OR :DISC1_RATIO IS NULL] .. THEN
    --   MSG('يجب إدخال محددات الشحنات', 'Must Enter Parameter For Config', 1)
    if l_lot is null or (l_expf = 1 and p_expiry is null)
       or (p_form = 'ST_ADJUST_IN' and (p_prod is null or p_disc is null)) then
      app_act_st.err(-20184, 'يجب إدخال محددات الشحنات', 'Must Enter Parameter For Config');
    end if;
    if p_qty is null or p_qty < 0 or (p_form = 'ST_ADJUST_IN' and p_qty = 0) then
      app_act_st.err(-20184, 'القيمة يجب أن تكون أكبر من الصفر', 'Value must be greater than Zero');
    end if;
    if p_price is null then
      app_act_st.err(-20184, 'يجب إدخال سعر الوحدة', 'Enter the unit price');
    end if;
    if l_disc < 0 then
      app_act_st.err(-20184, 'أدخل رقم بقيمة تبدأ من الصفر', 'Enter Value From Zero');
    end if;
    if p_form = 'ST_ADJUST_IN' then
      -- EXPIRE_DATE / PRODUCTION_DATE WHEN-VALIDATE-ITEM of ST_adjust_IN (commented out in ST_OPEN_BALANCE)
      if trunc(r.trns_date) >= trunc(p_expiry) then
        app_act_st.err(-20184, 'تاريخ الصلاحية يجب أن يكون أكبر من تاريخ الحركة', 'Expire Date Must Be More Than Tranaction Date');
      end if;
      if trunc(p_prod) >= trunc(p_expiry) then
        app_act_st.err(-20184, 'تاريخ الانتاج يجب أن يكون اصغر من تاريخ الصلاحية', 'Expire Date Must Be More Than Production Date');
      end if;
      if trunc(p_prod) >= trunc(r.trns_date) then
        app_act_st.err(-20184, 'تاريخ الانتاج يجب أن يكون اصغر من تاريخ الحركة', 'Trns Date Must Be Less Than Production Date');
      end if;
    else
      -- CHECK_NEXT_POSTED_TRANS
      select count(*) into l_n
        from st_trns_det td, st_trns_mast tm
       where tm.trns_type_code = td.trns_type_code and tm.trns_serial = td.trns_serial and nvl(tm.post_flag, 0) = 1
         and td.group_code = l_grp and td.item_code = trim(p_item) and tm.trns_date > r.trns_date and tm.store_code = r.store_code
         and rownum = 1;
      if l_n > 0 then
        app_act_st.err(-20184, 'الصنف ' || trim(p_item) || ' له حركة مرحلة بتاريخ لاحق',
                       'The item ' || trim(p_item) || ' has posted transaction with a leading date');
      end if;
    end if;
    -- supplier: ST_OPEN_BALANCE header SUPPLIER_CODE, else (and always for ST_adjust_IN) ST_ITEM.SUPPLIER
    if p_form = 'ST_OPEN_BALANCE' then l_supp := r.supplier_code; end if;
    if l_supp is null then
      select max(supplier) into l_supp from st_item where item_group_code = l_grp and item_code = trim(p_item);
    end if;
    l_conf := get_confg_id(trim(p_item), l_grp, l_supp, p_price, l_lot, case when l_expf = 1 then p_expiry end, l_disc, r.store_code, true);
    if nvl(l_conf, -1) < 0 then
      app_act_st.err(-20184, 'تعذر إنشاء الشحنة', 'The lot could not be created');
    end if;
    select nvl(max(item_serial), 0) + 1 into l_ser from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    if l_cost is null then
      -- unit cost: average cost of the lot at the position, else ST_ITEM.UNIT_COST, else (ST_adjust_IN) UNIT_PRICE / factor
      l_cost := get_unit_cost_confg(r.store_code, l_grp, trim(p_item), l_conf, r.trns_date, r.date_serial, l_ser);
      if nvl(l_cost, 0) = 0 then
        select max(unit_cost) into l_cost from st_item where item_group_code = l_grp and item_code = trim(p_item);
      end if;
      if nvl(l_cost, 0) = 0 then
        if p_form = 'ST_ADJUST_IN' then
          l_cost := p_price / l_fact;
        else
          app_act_st.err(-20184, 'يجب إدخال تكلفة الوحدة', 'Enter the unit cost');
        end if;
      end if;
    end if;
    insert into st_trns_det (trns_type_code, trns_serial, item_serial, group_code, item_code, unit_code, item_confg_id,
                             quantity, basic_qty, unit_price, unit_cost, disc1_ratio, disc1_value, cost_flag, store_code,
                             trns_date, date_serial, delete_flag, expiry_date, production_date)
    values (r.trns_type_code, r.trns_serial, l_ser, l_grp, trim(p_item), l_unit, l_conf,
            p_qty, p_qty * l_fact, p_price, l_cost, l_disc, l_disc * p_price / 100, 0, r.store_code,
            r.trns_date, r.date_serial, 0, p_expiry, case when p_form = 'ST_OPEN_BALANCE' then p_prod end);
    app_act_st.set_message('تم إضافة الصنف ' || trim(p_item) || '، الشحنة رقم ' || l_conf,
                           'Item ' || trim(p_item) || ' added, lot ' || l_conf);
    return null;
  end trf_lot_line;

  -- =================================================================================== ST_TRANSFER_FROM
  function trf_delete_check (p_rowid in varchar2) return varchar2 is
  begin
    return trf_doc_del_check('ST_TRANSFER_FROM', p_rowid);
  end trf_delete_check;

  procedure trf_after_delete (p_rowid in varchar2) is
    r st_trns_mast%rowtype := trf_mast(p_rowid);
  begin
    if r.trns_type_code is null or nvl(r.delete_flag, 0) != 1 then return; end if;
    -- st_trAnsfer_FROM.fmx KEY-DELREC: UPDATE ST_TRNSFER SET DELETE_FLAG = 1 .. ; UPDATE ST_TRNS_MAST_REQUEST SET TO_TRANSFER_FLAG = 0 ..
    if r.trnsfer_serial is not null then
      update st_trnsfer set delete_flag = 1 where trnsfer_serial = r.trnsfer_serial and trnsfer_from_store = r.store_code;
    end if;
    if r.req_trns_type_code is not null and r.req_trns_serial is not null then
      update st_trns_mast_request set to_transfer_flag = 0
       where trns_type_code = r.req_trns_type_code and trns_serial = r.req_trns_serial;
    end if;
  end trf_after_delete;

  function trf_doc_warn (p_rowid in varchar2, p_type in varchar2, p_doc_no in varchar2) return varchar2 is
    l_type number := app_act_st.num(p_type);
    l_doc  number := app_act_st.num(p_doc_no);
    l_n    number;
  begin
    if l_doc is null or trf_doc_repeat = 0 or trf_same_doc_no(p_rowid, l_doc) then return null; end if;
    -- SELECT COUNT(1) FROM ST_TRNS_MAST TM, ST_TRNS_TYPE TT WHERE .. TM.TRNS_TYPE_CODE = :b1 AND TM.STORE_CODE = TT.STORE_CODE
    --   AND NVL(TT.EFFECT,0) = 5 AND NVL(TT.TRNS_TYPE,0) = 9 AND TM.DOC_NO = :b2 AND NVL(TM.DELETE_FLAG,0) = 0
    select count(*) into l_n
      from st_trns_mast tm, st_trns_type tt
     where tm.trns_type_code = tt.trns_type_code and tm.trns_type_code = l_type and tm.store_code = tt.store_code
       and nvl(tt.effect, 0) = 5 and nvl(tt.trns_type, 0) = 9 and tm.doc_no = l_doc and nvl(tm.delete_flag, 0) = 0
       and (p_rowid is null or tm.rowid != app_act_st.rid(p_rowid));
    return case when l_n > 0 then trf_dup_msg end;
  end trf_doc_warn;

  function trf_status (p_rowid in varchar2) return varchar2 is
    r      st_trns_mast%rowtype := trf_mast(p_rowid);
    l_from number;
    l_def  number;
    l_date date;
    l_rtyp number;
    l_rser number;
    l_rdoc number;
  begin
    if r.trns_type_code is null or r.trnsfer_serial is null then return null; end if;
    l_from := case when trf_effect(r.trns_type_code) = 5 then r.store_code else r.trnsfer_from_store end;
    select min(m.trns_type_code) keep (dense_rank first order by m.trns_serial),
           min(m.trns_serial), min(m.doc_no) keep (dense_rank first order by m.trns_serial)
      into l_rtyp, l_rser, l_rdoc
      from st_trns_mast m, st_trns_type t
     where t.trns_type_code = m.trns_type_code and t.effect = 6 and t.trns_type = 9
       and m.trnsfer_serial = r.trnsfer_serial and m.trnsfer_from_store = l_from and nvl(m.delete_flag, 0) = 0;
    if l_rser is null then
      return app_act_st.m('التحويل لم يستلم', 'The transfer has not been received');
    end if;
    -- SELECT SUM(DECODE(T.EFFECT, 5, 1 * BASIC_QTY, 6, -1 * BASIC_QTY)) DEF_QUANTITY FROM .. M.DELETE_FLAG != 1 AND D.DELETE_FLAG != 1
    select nvl(sum(decode(t.effect, 5, d.basic_qty, 6, -d.basic_qty)), 0) into l_def
      from st_trns_mast m, st_trns_det d, st_trns_type t
     where m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial
       and m.trnsfer_serial = r.trnsfer_serial and m.trnsfer_from_store = l_from
       and nvl(m.delete_flag, 0) != 1 and nvl(d.delete_flag, 0) != 1
       and m.trns_type_code = t.trns_type_code and t.effect in (5, 6) and t.trns_type = 9;
    select max(trnsfer_receiving_date) into l_date from st_trnsfer where trnsfer_serial = r.trnsfer_serial and trnsfer_from_store = l_from;
    return case when l_def = 0 then app_act_st.m('تم إستلام التحويل مطابق', 'The transfer was received identical')
                else app_act_st.m('تم إستلام التحويل وتوجد أصناف غير مطابقة', 'The transfer was received with items not matching') end
           || app_act_st.m(' بتاريخ ', ' on ') || to_char(l_date, 'DD/MM/YYYY')
           || app_act_st.m(' برقم حركة ', ' transaction ') || l_rtyp || '/' || l_rser
           || app_act_st.m(' برقم مستند ', ' document ') || l_rdoc;
  end trf_status;

  function trf_totals (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    r st_trns_mast%rowtype := trf_mast(p_rowid);
    l number;
    s varchar2(4000);
  begin
    if r.trns_type_code is null then return null; end if;
    if p_what = 'COUNT' then        -- عدد الاصناف
      select count(*) into l from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      return to_char(l);
    elsif p_what = 'COST' then      -- إجمالى بالتكلفة (only with SHOW_COST and USERS.ALLOW_VIEW_COST)
      if not trf_can_view_cost then return null; end if;
      select sum(nvl(basic_qty, 0) * nvl(unit_cost, 0)) into l from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      return trf_fmt(l);
    elsif p_what = 'PRICE' then     -- إجمالى بسعر البيع
      select sum(nvl(quantity, 0) * nvl(unit_price, 0)) into l from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      return trf_fmt(l);
    elsif p_what = 'UNITS' then     -- الكميات الاجمالية: SELECT UNIT_CODE, SUM(BASIC_QTY / FACTOR) .. GROUP BY UNIT_CODE
      for u in (select iu.unit_code, max(nvl(decode(app_sec.lang, 'en', un.name_e, un.name_a), to_char(iu.unit_code))) uname,
                       sum(d.basic_qty / nullif(iu.factor, 0)) qty
                  from st_trns_det d, st_item_unit iu, st_unit un
                 where d.trns_type_code = r.trns_type_code and d.trns_serial = r.trns_serial
                   and iu.group_code = d.group_code and iu.item_code = d.item_code and un.unit_code (+) = iu.unit_code
                 group by iu.unit_code order by iu.unit_code)
      loop
        s := s || case when s is not null then ' | ' end || u.uname || ': ' || trf_fmt(u.qty, 0);
      end loop;
      return s;
    end if;
    return null;
  end trf_totals;

  function trf_rec_type (p_type in number) return number is
    l number;
  begin
    select max(t2.trns_type_code) into l
      from st_trns_type t1, st_trns_type t2
     where t1.trns_type_code = p_type and nvl(t1.rec_transfer_trns, 0) != 0
       and t2.trns_type_code = t1.rec_transfer_trns and t2.effect = 6 and t2.trns_type = 9;
    return l;
  end trf_rec_type;

  function trf_auto_on return boolean is
    l number;
  begin
    -- SELECT NVL(AUTO_TRANSFER, 0) FROM ST_BASIC WHERE SERIAL = :GLOBAL.COMPANY_CODE
    select nvl(max(auto_transfer), 0) into l from st_basic
     where serial = nvl(app_act_st.num(v('G_COMPANY_CODE')), serial);
    return l = 1;
  end trf_auto_on;

  function trf_can_auto_receive (p_rowid in varchar2) return varchar2 is
    r   st_trns_mast%rowtype := trf_mast(p_rowid);
    l_n number;
  begin
    if r.trns_type_code is null or nvl(r.delete_flag, 0) != 0 or r.trnsfer_serial is null then return 'N'; end if;
    if nvl(trf_effect(r.trns_type_code), -1) != 5 or not trf_auto_on or trf_rec_type(r.trns_type_code) is null then return 'N'; end if;
    if trf_received(r.trnsfer_serial, r.store_code) then return 'N'; end if;
    select count(*) into l_n from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and nvl(delete_flag, 0) = 0;
    return case when l_n > 0 then 'Y' else 'N' end;
  exception when others then
    return 'N';
  end trf_can_auto_receive;

  -- st_trAnsfer_FROM.fmx after saving an issue transfer: IF AUTO_TRANSFER = 1 AND REC_TRANSFER_TRNS != 0 THEN
  -- "هل تريد استلام التحويل تلقائي" -> INSERT INTO ST_TRNS_MAST (.. DOC_NO 1110100001, DATE_SERIAL 999999999, DESC_A
  -- 'حركة استلام تحويل اتوماتيك بموجب سند تحويل يدوي رقم ' || TRNSFER_SERIAL ..), the issued lines copied
  -- (SELECT .. FROM ST_TRNS_DET WHERE .. NVL(DELETE_FLAG, 0) = 0 -> INSERT INTO ST_TRNS_DET ..) and
  -- UPDATE ST_TRNSFER SET TRNSFER_RECEIVING_DATE = .. (data: 24 automatic receipts 11201, all identical to this shape)
  function trf_auto_receive (p_rowid in varchar2) return varchar2 is
    r      st_trns_mast%rowtype;
    l_rt   number;
    l_ser  number;
    l_rid  rowid;
    l_n    number := 0;
  begin
    begin
      select * into r from st_trns_mast where rowid = app_act_st.rid(p_rowid) for update;
    exception when no_data_found then
      app_act_st.err(-20181, 'الحركة غير موجودة، أعد تحميل الصفحة', 'The document no longer exists, reload the page');
    end;
    if nvl(r.delete_flag, 0) != 0 or nvl(trf_effect(r.trns_type_code), -1) != 5 or r.trnsfer_serial is null then
      app_act_st.err(-20181, 'نوع الحركة غير مسموح به فى هذه الشاشة: ' || r.trns_type_code,
                     'Transaction type not allowed on this screen: ' || r.trns_type_code);
    end if;
    if not trf_auto_on then
      app_act_st.err(-20181, 'الاستلام التلقائي للتحويلات غير مفعل (مؤشرات النظام بالمخازن)',
                     'Automatic transfer receipt is not enabled (stock system settings)');
    end if;
    l_rt := trf_rec_type(r.trns_type_code);
    if l_rt is null then
      app_act_st.err(-20181, 'يجب تحديد حركة استلام التحويل لنوع الحركة ' || r.trns_type_code,
                     'Define the receiving transaction type of type ' || r.trns_type_code);
    end if;
    if trf_received(r.trnsfer_serial, r.store_code) then
      app_act_st.err(-20181, 'تم استلام هذا التحويل من قبل', 'This transfer has already been received');
    end if;
    select nvl(max(trns_serial) + 1, 1) into l_ser from st_trns_mast where trns_type_code = l_rt;
    insert into st_trns_mast (trns_serial, doc_no, trns_date, date_serial, desc_a, currency_rate, freight_val, customs_val,
                              trnsport_val, insurance_val, commission_val, others_val, post_flag, delete_flag, trns_type_code,
                              currency_code, store_code, trnsfer_type, trnsfer_serial, trnsfer_from_store, trnsfer_to_store,
                              insert_user, insert_date, taking_flag, print_flag, prepare_flag, rev_flag, dlvr_flag, cust_auth_flag,
                              dlvr_loc_flag, bonus_tax, without_tax, dlvr2_flag)
    values (l_ser, 1110100001, r.trns_date, 999999999, 'حركة استلام تحويل اتوماتيك بموجب سند تحويل يدوي رقم ' || r.trnsfer_serial,
            1, 0, 0, 0, 0, 0, 0, 0, 0, l_rt, 1, r.trnsfer_to_store, 1, r.trnsfer_serial, r.store_code, r.trnsfer_to_store,
            app_act_st.usr, sysdate, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    returning rowid into l_rid;
    for d in (select * from st_trns_det
               where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and nvl(delete_flag, 0) = 0
               order by item_serial)
    loop
      insert into st_trns_det (item_serial, quantity, unit_cost, unit_price, basic_qty, cost_flag, trns_type_code, trns_serial,
                               unit_code, group_code, item_code, freight, customs, transport, store_code, item_confg_id, others,
                               insurance, commission, trns_date, date_serial, delete_flag, trnsfer_serial, trnsfer_from_store,
                               trnsfer_to_store)
      values (d.item_serial, d.quantity, d.unit_cost, d.unit_price, d.basic_qty, 1, l_rt, l_ser,
              d.unit_code, d.group_code, d.item_code, 0, 0, 0, r.trnsfer_to_store, d.item_confg_id, 0,
              0, 0, r.trns_date, 999999999, 0, r.trnsfer_serial, r.store_code, r.trnsfer_to_store);
      l_n := l_n + 1;
    end loop;
    update st_trnsfer set trnsfer_receiving_date = r.trns_date
     where trnsfer_serial = r.trnsfer_serial and trnsfer_from_store = r.store_code;
    app_act_st.set_message('تم استلام التحويل تلقائيا، حركة الاستلام رقم ' || l_rt || '/' || l_ser || ' (' || l_n || ' صنف)',
                           'The transfer was received automatically, receipt ' || l_rt || '/' || l_ser || ' (' || l_n || ' items)');
    return rowidtochar(l_rid);
  end trf_auto_receive;

  function trf_can_load (p_rowid in varchar2) return varchar2 is
    r st_trns_mast%rowtype := trf_mast(p_rowid);
  begin
    if r.trns_type_code is null or nvl(r.delete_flag, 0) != 0 or nvl(r.post_flag, 0) = 1 then return 'N'; end if;
    if trf_received(r.trnsfer_serial, r.store_code) then return 'N'; end if;
    return 'Y';
  exception when others then
    return 'N';
  end trf_can_load;

  -- LOAD_EXCEL_FILE of st_trAnsfer_FROM.fmx (template ASCON\ST\old\TRANSFER.xlsx): from row 2 until the first empty item code,
  -- columns Item Code, Unit Code, Qty, Ascon Confg, Lot No., Expire Date.  Lot: the given lot of the item (" Item Confg NOT
  -- EXIST-"), else MAX(ITEM_CONFG_ID) with this lot number and expiry date, else MIN(ITEM_CONFG_ID) with
  -- GET_BALANCE_CONFG(store, .., date, NULL, NULL) >= quantity.  The legacy filled the detail block (saved with the
  -- normal line rules) and wrote the rejected rows to C:\ITEMS_LOAD_ERROR.TXT; here every row is inserted with the line
  -- rules of the page (APP_RULES_ST.det_row) and the rejected rows are listed in the message.
  function trf_load_excel (p_rowid in varchar2, p_file in varchar2) return varchar2 is
    r       st_trns_mast%rowtype;
    l_blob  blob;
    l_fname varchar2(400);
    l_item  varchar2(100);
    l_group number;
    l_unit  number;
    l_qty   number;
    l_confg number;
    l_lot   varchar2(100);
    l_exp   date;
    l_fact  number;
    l_ser   number;
    l_err   varchar2(1000);
    l_log   varchar2(4000);
    l_ok    number := 0;
    l_bad   number := 0;
    l_n     number;
    l_line  number := 1;
  begin
    begin
      select * into r from st_trns_mast where rowid = app_act_st.rid(p_rowid) for update;
    exception when no_data_found then
      app_act_st.err(-20182, 'لابد من الحفظ أولا', 'You Should Save First');
    end;
    if nvl(r.post_flag, 0) = 1 or nvl(r.delete_flag, 0) != 0 then
      app_act_st.err(-20182, 'لا يمكن تعديل حركة مرحلة', 'A posted transaction cannot be changed');
    end if;
    if trf_received(r.trnsfer_serial, r.store_code) then
      app_act_st.err(-20182, 'تم استلام التحويل ولا يمكن التعديل', 'The transfer has been received and cannot be changed');
    end if;
    app_act_st.get_file(p_file, l_blob, l_fname);
    for x in (select line_number, col001, col002, col003, col004, col005, col006
                from table(apex_data_parser.parse(p_content => l_blob, p_file_name => l_fname))
               where line_number >= 2
               order by line_number)
    loop
      l_item := trim(x.col001);
      exit when l_item is null or x.line_number > l_line + 1;     -- EXIT WHEN V_ITEM_CODE IS NULL (a skipped empty row too)
      l_line := x.line_number;
      l_err := null; l_group := null; l_confg := null;
      l_unit := trf_xl_num(x.col002);
      l_qty := trf_xl_num(x.col003);
      l_confg := trf_xl_num(x.col004);
      l_lot := trim(x.col005);
      l_exp := trf_xl_date(x.col006);
      -- SELECT NAME_E, NAME_E, ITEM_GROUP_CODE FROM ST_ITEM WHERE ITEM_CODE = :b1
      select count(*), min(item_group_code) into l_n, l_group from st_item where item_code = l_item;
      if l_n != 1 then
        l_err := ' Item Code NOT EXIST-';
      end if;
      if l_err is null and l_confg is null and l_lot is not null and l_exp is not null then
        select max(item_confg_id) into l_confg from st_item_confg
         where group_code = l_group and item_code = l_item and lot_number = l_lot and expire_date = l_exp;
      end if;
      if l_err is null and l_confg is not null then
        select count(*) into l_n from st_item_confg where group_code = l_group and item_code = l_item and item_confg_id = l_confg;
        if l_n = 0 then l_err := ' Item Confg NOT EXIST-'; end if;
      end if;
      if l_err is null and nvl(l_qty, 0) <= 0 then
        l_err := ' QUANTITY IS NULL-';
      end if;
      if l_err is null then
        if l_unit is null then
          select min(unit_code) into l_unit from st_item_unit where group_code = l_group and item_code = l_item and nvl(basic_unit, 0) = 1;
        end if;
        select max(factor) into l_fact from st_item_unit where group_code = l_group and item_code = l_item and unit_code = l_unit;
        if l_fact is null then
          l_err := ' UNIT NOT EXIST-';
        end if;
      end if;
      if l_err is null and l_confg is null then
        select min(item_confg_id) into l_confg from st_item_confg
         where group_code = l_group and item_code = l_item
           and get_balance_confg(r.store_code, group_code, item_code, item_confg_id, r.trns_date, null, null) >= l_qty * l_fact;
      end if;
      if l_err is null then
        savepoint trf_xl_row;
        begin
          select nvl(max(item_serial), 0) + 1 into l_ser from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
          insert into st_trns_det (trns_type_code, trns_serial, item_serial, group_code, item_code, unit_code, item_confg_id,
                                   quantity, basic_qty, cost_flag, unit_cost, unit_price, store_code, trns_date, date_serial,
                                   delete_flag, trnsfer_serial, trnsfer_from_store, trnsfer_to_store)
          values (r.trns_type_code, r.trns_serial, l_ser, l_group, l_item, l_unit, l_confg,
                  l_qty, l_qty * l_fact, 1,
                  case when l_confg is not null then get_unit_cost_confg(r.store_code, l_group, l_item, l_confg, r.trns_date, r.date_serial, l_ser) end,
                  (select max(unit_price) from st_item_confg where item_confg_id = l_confg),
                  r.store_code, r.trns_date, r.date_serial, 0, r.trnsfer_serial, r.store_code, r.trnsfer_to_store);
          l_ok := l_ok + 1;
        exception when others then
          rollback to savepoint trf_xl_row;
          l_err := ' ' || trf_err_text(sqlerrm);
        end;
      end if;
      if l_err is not null then
        l_bad := l_bad + 1;
        trf_add_line(l_log, ' ITEM CODE= ' || l_item || ' GROUP CODE= ' || l_group || ' ' || l_err);
      end if;
    end loop;
    app_act_st.set_message('تم تحميل ملف الأكسل: ' || l_ok || ' صنف' || case when l_bad > 0 then '، أصناف لم يتم تحميلها: ' || l_bad || l_log end,
                           'File Loaded: ' || l_ok || ' items' || case when l_bad > 0 then ', rows not loaded: ' || l_bad || l_log end);
    return null;
  end trf_load_excel;

  -- =================================================================================== ST_TRANSFER_TO
  function trt_delete_check (p_rowid in varchar2) return varchar2 is
  begin
    return trf_doc_del_check('ST_TRANSFER_TO', p_rowid);
  end trt_delete_check;

  procedure trt_after_delete (p_rowid in varchar2) is
    r st_trns_mast%rowtype := trf_mast(p_rowid);
  begin
    if r.trns_type_code is null or nvl(r.delete_flag, 0) != 1 then return; end if;
    -- ST_TRANSFER_TO.fmx KEY-DELREC: UPDATE ST_TRNSFER SET TRNSFER_RECEIVING_DATE = NULL WHERE TRNSFER_SERIAL = .. AND TRNSFER_FROM_STORE = ..
    if r.trnsfer_serial is not null then
      update st_trnsfer set trnsfer_receiving_date = null
       where trnsfer_serial = r.trnsfer_serial and trnsfer_from_store = r.trnsfer_from_store;
    end if;
  end trt_after_delete;

  function trt_doc_warn (p_rowid in varchar2, p_type in varchar2, p_doc_no in varchar2, p_from_store in varchar2) return varchar2 is
    l_type number := app_act_st.num(p_type);
    l_doc  number := app_act_st.num(p_doc_no);
    l_n    number;
  begin
    if l_doc is null or trf_doc_repeat = 0 or trf_same_doc_no(p_rowid, l_doc) then return null; end if;
    -- .. AND NVL(TT.EFFECT,0) = 6 AND NVL(TT.TRNS_TYPE,0) = 9 AND TM.DOC_NO = :b2 AND TRNSFER_FROM_STORE = :b3 AND NVL(TM.DELETE_FLAG,0) = 0
    select count(*) into l_n
      from st_trns_mast tm, st_trns_type tt
     where tm.trns_type_code = tt.trns_type_code and tm.trns_type_code = l_type
       and nvl(tt.effect, 0) = 6 and nvl(tt.trns_type, 0) = 9 and tm.doc_no = l_doc
       and tm.trnsfer_from_store = app_act_st.num(p_from_store) and nvl(tm.delete_flag, 0) = 0
       and (p_rowid is null or tm.rowid != app_act_st.rid(p_rowid));
    return case when l_n > 0 then trf_dup_msg end;
  end trt_doc_warn;

  function trt_totals (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    r st_trns_mast%rowtype := trf_mast(p_rowid);
    l number;
  begin
    if r.trns_type_code is null then return null; end if;
    if p_what = 'QTY' then          -- اجمالى الكمية
      select sum(quantity) into l from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      return trf_fmt(l, 0);
    elsif p_what = 'TOTAL' then     -- الإجمالى
      select sum(nvl(quantity, 0) * nvl(unit_price, 0)) into l from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      return trf_fmt(l);
    end if;
    return null;
  end trt_totals;

  -- =================================================================================== ST_TRANSFER_REQUEST
  function trq_doc_warn (p_rowid in varchar2, p_type in varchar2, p_doc_no in varchar2) return varchar2 is
    l_type number := app_act_st.num(p_type);
    l_doc  number := app_act_st.num(p_doc_no);
    l_n    number;
  begin
    if l_doc is null or trf_doc_repeat = 0 or trf_same_doc_no(p_rowid, l_doc, true) then return null; end if;
    -- SELECT COUNT(1) FROM ST_TRNS_MAST_REQUEST TM, ST_TRNS_TYPE TT WHERE .. TM.TRNS_TYPE_CODE = :b1 AND NVL(TT.EFFECT,0) = 7
    --   AND NVL(TT.TRNS_TYPE,0) = 9 AND TM.DOC_NO = :b2 AND NVL(TM.DELETE_FLAG,0) = 0
    select count(*) into l_n
      from st_trns_mast_request tm, st_trns_type tt
     where tm.trns_type_code = tt.trns_type_code and tm.trns_type_code = l_type
       and nvl(tt.effect, 0) = 7 and nvl(tt.trns_type, 0) = 9 and tm.doc_no = l_doc and nvl(tm.delete_flag, 0) = 0
       and (p_rowid is null or tm.rowid != app_act_st.rid(p_rowid));
    return case when l_n > 0 then trf_dup_msg end;
  end trq_doc_warn;

  -- STORE_BALANCE "رصيد المستودع" of each line (program unit GET_CONFIG_BALANCE: the lots of the item summed with
  -- GET_BALANCE_CONFG(request STORE_CODE, .., TRNS_DATE) / factor); shown only with USERS.ALLOW_VIEW_BALANCE = 1
  function trq_store_balance (p_rowid in varchar2) return varchar2 is
    h st_trns_mast_request%rowtype;
    s varchar2(4000);
    b number;
  begin
    begin
      select * into h from st_trns_mast_request where rowid = app_act_st.rid(p_rowid);
    exception when no_data_found then return null;
    end;
    if trf_user_flag('ALLOW_VIEW_BALANCE') != 1 then return null; end if;
    for d in (select d.item_code, d.group_code, d.unit_code, nvl(iu.factor, 1) factor
                from st_trns_det_request d, st_item_unit iu
               where d.trns_type_code = h.trns_type_code and d.trns_serial = h.trns_serial
                 and iu.group_code (+) = d.group_code and iu.item_code (+) = d.item_code and iu.unit_code (+) = d.unit_code
               order by d.item_serial)
    loop
      select nvl(sum(get_balance_confg(h.store_code, c.group_code, c.item_code, c.item_confg_id, h.trns_date)), 0) into b
        from st_item_confg c where c.group_code = d.group_code and c.item_code = d.item_code;
      s := s || case when s is not null then ' | ' end || d.item_code || ': ' || trf_fmt(b / d.factor, 0);
      if length(s) > 3800 then
        s := s || ' ...';
        exit;
      end if;
    end loop;
    return s;
  end trq_store_balance;

  -- =================================================================================== ST_OPEN_BALANCE
  function obl_delete_check (p_rowid in varchar2) return varchar2 is
  begin
    return trf_doc_del_check('ST_OPEN_BALANCE', p_rowid);
  end obl_delete_check;

  function obl_totals (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    r st_trns_mast%rowtype := trf_mast(p_rowid);
    l number;
  begin
    if r.trns_type_code is null then return null; end if;
    if p_what = 'QTY' then          -- SUM_QTY (summary of QUANTITY)
      select sum(quantity) into l from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      return trf_fmt(l, 0);
    elsif p_what = 'COST' then      -- TOTAL_VALUE_RYAL (summary of LINE_TOTAL_RYAL := UNIT_COST * QUANTITY)
      select sum(nvl(unit_cost, 0) * nvl(quantity, 0)) into l from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
      return trf_fmt(l);
    end if;
    return null;
  end obl_totals;

  function obl_can_load (p_rowid in varchar2) return varchar2 is
    r st_trns_mast%rowtype := trf_mast(p_rowid);
  begin
    return case when r.trns_type_code is not null and nvl(r.delete_flag, 0) = 0 and nvl(r.post_flag, 0) = 0 then 'Y' else 'N' end;
  end obl_can_load;

  -- ST_OPEN_BALANCE.fmb LOAD_EXCEL_FILE (template ASCON\ST\old\Opening_balance.xlsx): from row 2 until the first empty
  -- item code, columns 1 group (empty = MIN(ITEM_GROUP_CODE) of the item), 2 item, 3 unit, 4 quantity, 5 lot number,
  -- 6 expiry date, 7 sales price, 8 cost price, 9 manufacturing date, 10 discount ratio; the legacy checks and English
  -- error texts per row (" ITEM CODE= .. GROUP CODE= .. <errors>", written to <file>.TXT, here listed in the message);
  -- valid rows inserted directly: UNIT_COST = cost price, UNIT_PRICE = sales price, COST_FLAG 0, lot by GET_THE_CONFIG
  -- (GET_CONFG_ID, created when missing, supplier = header SUPPLIER_CODE else ST_ITEM.SUPPLIER), PRODUCTION_DATE = manf date.
  function obl_load_excel (p_rowid in varchar2, p_file in varchar2) return varchar2 is
    r       st_trns_mast%rowtype;
    l_blob  blob;
    l_fname varchar2(400);
    l_group number;
    l_item  varchar2(100);
    l_unit  number;
    l_qty   number;
    l_lot   varchar2(100);
    l_exp   date;
    l_sales number;
    l_cost  number;
    l_manf  date;
    l_disc  number;
    l_err   varchar2(1000);
    l_log   varchar2(4000);
    l_var   number;
    l_fact  number;
    l_ser   number;
    l_confg number;
    l_supp  number;
    l_expf  number;
    l_single number;
    l_ok    number := 0;
    l_bad   number := 0;
    l_line  number := 1;
  begin
    begin
      select * into r from st_trns_mast where rowid = app_act_st.rid(p_rowid) for update;
    exception when no_data_found then
      app_act_st.err(-20183, 'لابد من الحفظ أولا', 'You Should Save First');
    end;
    if r.store_code is null then
      app_act_st.err(-20183, 'لابد من أدخال المخزن أولا', 'You Should Store Code First');
    end if;
    if obl_can_load(p_rowid) = 'N' then
      app_act_st.err(-20183, 'لا يمكن تعديل حركة مرحلة', 'A posted transaction cannot be changed');
    end if;
    select nvl(max(single_item), 0) into l_single from st_basic;
    app_act_st.get_file(p_file, l_blob, l_fname);
    for x in (select line_number, col001, col002, col003, col004, col005, col006, col007, col008, col009, col010
                from table(apex_data_parser.parse(p_content => l_blob, p_file_name => l_fname))
               where line_number >= 2
               order by line_number)
    loop
      l_item := trim(x.col002);
      exit when l_item is null or x.line_number > l_line + 1;     -- EXIT WHEN V_ITEM_CODE IS NULL (a skipped empty row too)
      l_line := x.line_number;
      l_err := null;
      l_group := trf_xl_num(x.col001);
      l_unit := trf_xl_num(x.col003);
      l_qty := trf_xl_num(x.col004);
      l_lot := trim(x.col005);
      l_exp := trf_xl_date(x.col006);
      l_sales := trf_xl_num(x.col007);
      l_cost := trf_xl_num(x.col008);
      l_manf := trf_xl_date(x.col009);
      l_disc := trf_xl_num(x.col010);
      if l_group is null then
        select min(item_group_code) into l_group from st_item where item_code = l_item;
      end if;
      select count(*) into l_var from st_item_group where item_group_code = l_group and nvl(group_status, 0) = 1;
      if l_var = 0 then l_err := ' GROUP NOT EXIST-'; end if;
      if l_single = 1 then
        select count(*) into l_var from st_trns_det
         where item_code = l_item and group_code = l_group and trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
        if l_var > 0 then l_err := l_err || ' ITEM EXIST-'; end if;
      end if;
      if l_sales is null or l_sales < 0 or l_sales > 99999999.99 then l_err := l_err || ' SALES PRICE IS NULL-'; end if;
      if l_disc is null or l_disc < 0 or l_disc > 99999999.99 then l_err := l_err || ' DISC RATIO IS NULL-'; end if;
      if l_cost is null or l_cost < 0 or l_cost > 99999999.99 then l_err := l_err || ' COST PRICE IS NULL-'; end if;
      if l_qty is null or l_qty < 0 or l_qty > 99999999.99 then l_err := l_err || ' QUANTITY IS NULL-'; end if;
      if l_exp is null then l_err := l_err || ' EXPIRE DATE IS NULL-'; end if;
      if l_lot is null then l_err := l_err || ' LOT NO IS NULL-'; end if;
      select count(*) into l_var from st_item_unit where unit_code = l_unit and item_code = l_item and group_code = l_group;
      if l_var = 0 then l_err := l_err || ' UNIT NOT EXIST-'; end if;
      select count(*) into l_var from st_item where item_code = l_item and item_group_code = l_group;
      if l_var = 0 then l_err := l_err || ' Item Code NOT EXIST UNDER Item Group-'; end if;
      -- CHECK_NEXT_POSTED_TRANS
      select count(*) into l_var
        from st_trns_det td, st_trns_mast tm
       where tm.trns_type_code = td.trns_type_code and tm.trns_serial = td.trns_serial and nvl(tm.post_flag, 0) = 1
         and td.group_code = l_group and td.item_code = l_item and tm.trns_date > r.trns_date and tm.store_code = r.store_code
         and rownum = 1;
      if l_var > 0 then l_err := l_err || ' The item ' || l_item || ' has posted transaction with a leading date -'; end if;
      if l_err is null then
        savepoint obl_xl_row;
        begin
          select nvl(max(item_serial), 0) + 1 into l_ser from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
          select nvl(max(factor), 1) into l_fact from st_item_unit where group_code = l_group and item_code = l_item and unit_code = l_unit;
          -- GET_THE_CONFIG (form program unit): expiry only for groups with ST_ITEM_GROUP.EXPIRE_FLAG = 1
          select nvl(max(expire_flag), 0) into l_expf from st_item_group where item_group_code = l_group;
          l_supp := r.supplier_code;
          if l_supp is null then
            select max(supplier) into l_supp from st_item where item_group_code = l_group and item_code = l_item;
          end if;
          l_confg := get_confg_id(l_item, l_group, l_supp, l_sales, l_lot, case when l_expf = 1 then l_exp end, l_disc, r.store_code, true);
          if nvl(l_confg, -1) < 0 then
            raise_application_error(-20183, 'ERROR IN INSERTION OF ITEM ' || l_item);
          end if;
          insert into st_trns_det (item_serial, quantity, unit_cost, unit_price, basic_qty, cost_flag, trns_type_code, trns_serial,
                                   unit_code, group_code, item_code, store_code, item_confg_id, trns_date, date_serial, delete_flag,
                                   production_date)
          values (l_ser, l_qty, l_cost, l_sales, l_qty * l_fact, 0, r.trns_type_code, r.trns_serial,
                  l_unit, l_group, l_item, r.store_code, l_confg, r.trns_date, r.date_serial, 0, l_manf);
          l_ok := l_ok + 1;
        exception when others then
          rollback to savepoint obl_xl_row;
          l_err := 'ERROR IN INSERTION OF ITEM ' || l_item || ': ' || trf_err_text(sqlerrm);
        end;
      end if;
      if l_err is not null then
        l_bad := l_bad + 1;
        trf_add_line(l_log, case when l_err like 'ERROR IN INSERTION%' then l_err
                                 else ' ITEM CODE= ' || l_item || ' GROUP CODE= ' || l_group || ' ' || l_err end);
      end if;
    end loop;
    app_act_st.set_message('تم تحميل ملف الأكسل: ' || l_ok || ' صنف' || case when l_bad > 0 then '، أصناف لم يتم تحميلها: ' || l_bad || l_log end,
                           'File Loades: ' || l_ok || ' items' || case when l_bad > 0 then ', rows not loaded: ' || l_bad || l_log end);
    return null;
  end obl_load_excel;

  function obl_add_line (p_rowid in varchar2, p_item in varchar2, p_unit in number, p_qty in number, p_lot in varchar2,
                         p_expiry in date, p_price in number, p_cost in number, p_disc in number, p_prod in date) return varchar2 is
  begin
    return trf_lot_line('ST_OPEN_BALANCE', p_rowid, p_item, p_unit, p_qty, p_lot, p_expiry, p_price, p_cost, p_disc, p_prod);
  end obl_add_line;

  -- =================================================================================== ST_ADJUST_IN
  function adi_can_add (p_rowid in varchar2) return varchar2 is
  begin
    return obl_can_load(p_rowid);
  end adi_can_add;

  function adi_add_line (p_rowid in varchar2, p_item in varchar2, p_unit in number, p_qty in number, p_lot in varchar2,
                         p_expiry in date, p_price in number, p_cost in number, p_disc in number, p_prod in date) return varchar2 is
  begin
    return trf_lot_line('ST_ADJUST_IN', p_rowid, p_item, p_unit, p_qty, p_lot, p_expiry, p_price, p_cost, p_disc, p_prod);
  end adi_add_line;

  function adi_delete_check (p_rowid in varchar2) return varchar2 is
  begin
    return trf_doc_del_check('ST_ADJUST_IN', p_rowid);
  end adi_delete_check;

  -- ST_adjust_IN.fmb DOC_NO WHEN-VALIDATE-ITEM: SELECT COUNT(1) FROM ST_TRNS_MAST WHERE TRNS_TYPE_CODE = .. AND DOC_NO = ..
  -- -> alert DOC_REPEAT (continue or stop)
  function adi_doc_warn (p_rowid in varchar2, p_type in varchar2, p_doc_no in varchar2) return varchar2 is
    l_doc number := app_act_st.num(p_doc_no);
    l_n   number;
  begin
    if l_doc is null or trf_doc_repeat = 0 or trf_same_doc_no(p_rowid, l_doc) then return null; end if;
    select count(*) into l_n from st_trns_mast
     where trns_type_code = app_act_st.num(p_type) and doc_no = l_doc and (p_rowid is null or rowid != app_act_st.rid(p_rowid));
    return case when l_n > 0 then trf_dup_msg end;
  end adi_doc_warn;

  -- SUM_LINE_TOTAL (summary of LINE_TOTAL = NVL(:QUANTITY,0) * (NVL(:UNIT_PRICE,0) - NVL(:DISC1_VALUE,0)))
  function adi_total (p_rowid in varchar2) return varchar2 is
    r st_trns_mast%rowtype := trf_mast(p_rowid);
    l number;
  begin
    if r.trns_type_code is null then return null; end if;
    select sum(nvl(quantity, 0) * (nvl(unit_price, 0) - nvl(disc1_value, 0))) into l
      from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    return trf_fmt(l, 4);
  end adi_total;

  -- =================================================================================== ST_ADJUST_OUT
  function ado_delete_check (p_rowid in varchar2) return varchar2 is
  begin
    return trf_doc_del_check('ST_ADJUST_OUT', p_rowid);
  end ado_delete_check;

  -- ST_adjust_out.fmx: NVL(DOC_REPEAT, 0) of ST_BASIC and SELECT COUNT(1) FROM ST_TRNS_MAST WHERE TRNS_TYPE_CODE = :b1 AND DOC_NO = :b2
  function ado_doc_warn (p_rowid in varchar2, p_type in varchar2, p_doc_no in varchar2) return varchar2 is
  begin
    return adi_doc_warn(p_rowid, p_type, p_doc_no);
  end ado_doc_warn;

  -- SUM_LINE_TOTAL (LINE_TOTAL from :QUANTITY and :UNIT_PRICE)
  function ado_total (p_rowid in varchar2) return varchar2 is
    r st_trns_mast%rowtype := trf_mast(p_rowid);
    l number;
  begin
    if r.trns_type_code is null then return null; end if;
    select sum(nvl(quantity, 0) * nvl(unit_price, 0)) into l
      from st_trns_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    return trf_fmt(l);
  end ado_total;

  -- COST_CODE: "حد اقصى" = AC_COST_CENTERS.MAX_LIMIT, "رصيد" = GET_COST_BAL(COST_CODE, TRNS_DATE) =
  -- SELECT NVL(SUM(VALUE), 0) FROM AC_YEARLY_TRN_DET WHERE COST_CODE = :b1 AND (ENTRY_DATE <= :b2 OR :b2 IS NULL).
  -- (The "لقد تجاوز مركز التكلفة الحد الاقصى" message is only for :GLOBAL.CUSTOMER_CODE = 'ZED': not this installation.)
  function ado_cost_center (p_rowid in varchar2, p_what in varchar2) return varchar2 is
    r st_trns_mast%rowtype := trf_mast(p_rowid);
    l number;
  begin
    if r.trns_type_code is null or r.cost_code is null then return null; end if;
    if p_what = 'LIMIT' then
      select max(max_limit) into l from ac_cost_centers where cost_code = r.cost_code;
    else
      select nvl(sum(value), 0) into l from ac_yearly_trn_det where cost_code = r.cost_code and (entry_date <= r.trns_date or r.trns_date is null);
    end if;
    return trf_fmt(l);
  end ado_cost_center;

  -- REORDER_LIMIT "حد الطلب" of each line (SELECT REORDER_LIMIT FROM ST_ITEM WHERE ITEM_CODE = :b1 AND ITEM_GROUP_CODE = :b2)
  function ado_reorder (p_rowid in varchar2) return varchar2 is
    r st_trns_mast%rowtype := trf_mast(p_rowid);
    s varchar2(4000);
  begin
    if r.trns_type_code is null then return null; end if;
    for d in (select d.item_code, max(i.reorder_limit) lim
                from st_trns_det d, st_item i
               where d.trns_type_code = r.trns_type_code and d.trns_serial = r.trns_serial
                 and i.item_group_code = d.group_code and i.item_code = d.item_code and i.reorder_limit is not null
               group by d.item_code order by d.item_code)
    loop
      s := s || case when s is not null then ' | ' end || d.item_code || ': ' || trf_fmt(d.lim, 0);
      if length(s) > 3800 then
        s := s || ' ...';
        exit;
      end if;
    end loop;
    return s;
  end ado_reorder;
  -- =================================================================================== ST_TAKING / ST_TAKING2 / ST_ITEM_REQ / ST_ITEM_REQ_HANDLE
  function tk_get (p_rowid in varchar2, p_form in varchar2) return tk_hdr is
    h tk_hdr;
  begin
    if upper(p_form) = 'ST_TAKING2' then
      select store_code, st_taking_date, serial into h.store, h.tdate, h.serial
        from st_stock_taking_temp where rowid = app_act_st.rid(p_rowid);
    else
      select store_code, st_taking_date into h.store, h.tdate
        from st_stock_taking where rowid = app_act_st.rid(p_rowid);
    end if;
    h.found := true;
    return h;
  exception when no_data_found then
    h.found := false;
    return h;
  end tk_get;

  function tk_must (p_rowid in varchar2, p_form in varchar2) return tk_hdr is
    h tk_hdr := tk_get(p_rowid, p_form);
  begin
    if not h.found then
      app_act_st.err(-20191, 'يجب حفظ الجرد أولا', 'Save the stocktaking first');
    end if;
    return h;
  end tk_must;

  function tk_lines (h in tk_hdr, p_form in varchar2) return number is
    l_n number;
  begin
    if upper(p_form) = 'ST_TAKING2' then
      select count(*) into l_n from st_stock_taking_temp_det
       where store_code = h.store and st_taking_date = h.tdate and serial = h.serial;
    else
      select count(*) into l_n from st_stock_taking_det where store_code = h.store and st_taking_date = h.tdate;
    end if;
    return l_n;
  end tk_lines;

  function tk_can_fill (p_rowid in varchar2, p_form in varchar2) return varchar2 is
    h tk_hdr := tk_get(p_rowid, p_form);
  begin
    return case when h.found and tk_lines(h, p_form) = 0 then 'Y' else 'N' end;
  exception when others then
    return 'N';
  end tk_can_fill;

  function tk_has_lines (p_rowid in varchar2, p_form in varchar2) return varchar2 is
    h tk_hdr := tk_get(p_rowid, p_form);
  begin
    return case when h.found and tk_lines(h, p_form) > 0 then 'Y' else 'N' end;
  exception when others then
    return 'N';
  end tk_has_lines;

  function tk_factor (p_group in number, p_item in varchar2, p_unit in number) return number is
    l number;
  begin
    select max(factor) into l from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit;
    return nvl(l, 1);
  end tk_factor;

  -- next TAKING_NUMBER (legacy PRE-INSERT: MAX + 1 per date and store, and serial for the TEMP lines)
  function tk_next_no (h in tk_hdr, p_form in varchar2) return number is
    l number;
  begin
    if upper(p_form) = 'ST_TAKING2' then
      select nvl(max(nvl(taking_number, 0)), 0) + 1 into l from st_stock_taking_temp_det
       where st_taking_date = h.tdate and store_code = h.store and serial = h.serial;
    else
      select nvl(max(nvl(taking_number, 0)), 0) + 1 into l from st_stock_taking_det
       where st_taking_date = h.tdate and store_code = h.store;
    end if;
    return l;
  end tk_next_no;

  procedure tk_insert (h in tk_hdr, p_form in varchar2, p_no in number, p_group in number, p_item in varchar2,
                       p_unit in number, p_confg in number, p_qty in number, p_factor in number, p_price in number,
                       p_cost in number, p_sales_price in number default null, p_disc_ratio in number default null) is
  begin
    if upper(p_form) = 'ST_TAKING2' then
      insert into st_stock_taking_temp_det (st_taking_date, store_code, serial, taking_number, group_code, item_code, unit_code,
                                            item_confg_id, quantity, basic_qty, unit_price, unit_cost)
      values (h.tdate, h.store, h.serial, p_no, p_group, p_item, p_unit, p_confg, p_qty, p_qty * p_factor, p_price, p_cost);
    else
      insert into st_stock_taking_det (store_code, st_taking_date, taking_number, group_code, item_code, unit_code, item_confg_id,
                                       quantity, basic_qty, unit_price, unit_cost, sales_price, disc1_ratio, disc1_value)
      values (h.store, h.tdate, p_no, p_group, p_item, p_unit, p_confg, p_qty, p_qty * p_factor, p_price, p_cost,
              p_sales_price, p_disc_ratio,
              case when nvl(p_disc_ratio, 0) <> 0 and nvl(p_price, 0) <> 0 then p_disc_ratio * p_price / 100 else 0 end);
    end if;
  end tk_insert;

  -- ST_TAKING program unit GET_THE_CONFIG: the lot of the given parameters, created when missing (GET_CONFG_ID_SUPP);
  -- expiry / colour / size only for groups with the flag
  function tk_the_config (p_group in number, p_item in varchar2, p_unit_price in number, p_lot_number in varchar2,
                          p_expire_date in date, p_store in number) return number is
    l_exp  number;
    l_col  number;
    l_siz  number;
    l_lot  varchar2(200) := p_lot_number;
    l_id   number;
  begin
    begin
      select expire_flag, color_flag, size_flag into l_exp, l_col, l_siz from st_item_group where item_group_code = p_group;
    exception when no_data_found then
      l_exp := 0; l_col := 0; l_siz := 0;
    end;
    l_id := get_confg_id_supp(p_item, p_group, p_unit_price, l_lot, case when l_exp = 1 then p_expire_date end, p_store, true,
                              null, null);
    return l_id;
  end tk_the_config;

  -- ST_TAKING line PRE-INSERT: UNIT_COST := GET_UNIT_COST_CONFG(store, group, item, lot, date, UNIT_CODE) - the unit code
  -- lands in the DT_SERIAL argument (legacy), UNIT_PRICE := UNIT_COST * FACTOR
  function tk_insert_cost (h in tk_hdr, p_group in number, p_item in varchar2, p_confg in number, p_unit in number) return number is
  begin
    return get_unit_cost_confg(h.store, p_group, p_item, p_confg, h.tdate, p_unit);
  end tk_insert_cost;

  function tk_decompose (p_rowid in varchar2, p_form in varchar2) return varchar2 is
    h      tk_hdr := tk_must(p_rowid, p_form);
    l_pw   number := app_act_st.pw;
    l_no   number;
    l_n    number := 0;
    l_cost number;
    l_bal  number;
  begin
    if tk_lines(h, p_form) > 0 then
      app_act_st.err(-20192, 'يوجد تفاصيل', 'The stocktaking already has lines');
    end if;
    l_no := tk_next_no(h, p_form);
    -- DECOMPOSE WHEN-BUTTON-PRESSED (ST_TAKING_fmb.xml; same query in ST_TAKING2.fmx without DISC_RATIO)
    for d in (select st_item.item_group_code, st_item.item_code, st_unit.unit_code, st_item_confg.item_confg_id,
                     st_item_confg.expire_date, st_item_confg.disc_ratio, st_item_confg.unit_price lot_price
                from st_item, st_unit, st_item_unit, st_item_confg, st_store_item
               where st_unit.unit_code = st_item_unit.unit_code
                 and st_item.item_code = st_item_unit.item_code
                 and st_item.item_group_code = st_item_unit.group_code
                 and st_item.item_group_code = st_item_confg.group_code
                 and st_item.item_code = st_item_confg.item_code
                 and st_item.item_group_code = st_store_item.group_code
                 and st_item.item_code = st_store_item.item_code
                 and st_store_item.store_code = h.store
                 and st_item.stop_flag = 0
                 and nvl(basic_unit, 0) = 1
                 and (l_pw = 0 or st_item.item_group_code in (select group_code from st_group_password where password_number = l_pw))
               order by st_item.item_group_code, st_item.item_code, st_item_confg.item_confg_id)
    loop
      l_cost := abs(get_unit_cost_confg(h.store, d.item_group_code, d.item_code, d.item_confg_id, h.tdate, null, null));
      l_bal := get_balance_confg(h.store, d.item_group_code, d.item_code, d.item_confg_id, h.tdate, null, null);
      if upper(p_form) != 'ST_TAKING2' then
        l_cost := tk_insert_cost(h, d.item_group_code, d.item_code, d.item_confg_id, d.unit_code);
      end if;
      -- basic unit: factor 1; QUANTITY := BASIC_QTY := book balance; UNIT_PRICE := UNIT_COST
      tk_insert(h, p_form, l_no, d.item_group_code, d.item_code, d.unit_code, d.item_confg_id, nvl(l_bal, 0), 1,
                nvl(l_cost, 0), nvl(l_cost, 0), d.lot_price, d.disc_ratio);
      l_no := l_no + 1;
      l_n := l_n + 1;
    end loop;
    app_act_st.set_message('تم إنزال أصناف المخزن: ' || l_n || ' سطر', 'Store items loaded: ' || l_n || ' lines');
    return p_rowid;
  end tk_decompose;

  function tk_calc_cost (p_rowid in varchar2, p_form in varchar2) return varchar2 is
    h      tk_hdr := tk_must(p_rowid, p_form);
    l_cost number;
    l_fac  number;
    l_n    number := 0;
  begin
    -- CALC_COST WHEN-BUTTON-PRESSED: :UNIT_COST := GET_UNIT_COST_CONFG(store, group, item, lot, date, NULL, NULL);
    -- :UNIT_PRICE := NVL(:UNIT_COST, 0) * NVL(FACTOR, 1)
    if upper(p_form) = 'ST_TAKING2' then
      for l in (select rowid rid, group_code, item_code, unit_code, item_confg_id from st_stock_taking_temp_det
                 where store_code = h.store and st_taking_date = h.tdate and serial = h.serial order by taking_number) loop
        l_cost := get_unit_cost_confg(h.store, l.group_code, l.item_code, l.item_confg_id, h.tdate, null, null);
        l_fac := tk_factor(l.group_code, l.item_code, l.unit_code);
        update st_stock_taking_temp_det set unit_cost = nvl(l_cost, 0), unit_price = nvl(l_cost, 0) * l_fac where rowid = l.rid;
        l_n := l_n + 1;
      end loop;
    else
      for l in (select rowid rid, group_code, item_code, unit_code, item_confg_id from st_stock_taking_det
                 where store_code = h.store and st_taking_date = h.tdate order by taking_number) loop
        l_cost := get_unit_cost_confg(h.store, l.group_code, l.item_code, l.item_confg_id, h.tdate, null, null);
        l_fac := tk_factor(l.group_code, l.item_code, l.unit_code);
        update st_stock_taking_det set unit_cost = nvl(l_cost, 0), unit_price = nvl(l_cost, 0) * l_fac where rowid = l.rid;
        l_n := l_n + 1;
      end loop;
    end if;
    app_act_st.set_message('تم إنزال تكلفة أصناف الجرد: ' || l_n || ' سطر', 'Stocktaking costs loaded: ' || l_n || ' lines');
    return p_rowid;
  end tk_calc_cost;

  -- a cell of the uploaded sheet: text, number (',' thousands removed) or date (legacy DD/MM/RRRR; the parser may also
  -- return ISO dates or Excel day numbers)
  function tk_num (p in varchar2) return number is
  begin
    return to_number(replace(trim(p), ',', '') default null on conversion error);
  end tk_num;

  function tk_date (p in varchar2) return date is
    s varchar2(200) := trim(p);
    d date;
  begin
    if s is null then return null; end if;
    if regexp_like(s, '^[0-9]+(\.[0-9]+)?$') and to_number(s) between 1 and 80000 then
      return date '1899-12-30' + trunc(to_number(s));
    end if;
    if regexp_like(s, '^[0-9]{4}-[0-9]{2}-[0-9]{2}') then          -- XLSX date cells (apex_data_parser: YYYY-MM-DD)
      return to_date(substr(s, 1, 10) default null on conversion error, 'YYYY-MM-DD');
    end if;
    if regexp_like(s, '^[0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}') then  -- legacy text DD/MM/RRRR
      d := to_date(regexp_substr(s, '^[0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}') default null on conversion error, 'DD/MM/RRRR');
    end if;
    return trunc(d);
  end tk_date;

  function tk_load_file (p_rowid in varchar2, p_file in varchar2) return varchar2 is
    h        tk_hdr := tk_must(p_rowid, 'ST_TAKING');
    l_blob   blob;
    l_fn     varchar2(400);
    l_item   varchar2(100);
    l_unit   number;
    l_exp    date;
    l_lot    varchar2(200);
    l_qty    number;
    l_price  number;
    l_disc   number;
    l_group  number;
    l_factor number;
    l_confg  number;
    l_cost   number;
    l_no     number;
    l_n      number := 0;
    l_prev   number := 1;
  begin
    -- UPLOAD_EXCEL: "يوجد تفاصيل" when the count already has lines
    if tk_lines(h, 'ST_TAKING') > 0 then
      app_act_st.err(-20192, 'يوجد تفاصيل', 'The stocktaking already has lines');
    end if;
    app_act_st.get_file(p_file, l_blob, l_fn);
    l_no := tk_next_no(h, 'ST_TAKING');
    for r in (select line_number, col001, col002, col003, col004, col005, col006, col007
                from table(apex_data_parser.parse(p_content => l_blob, p_file_name => l_fn))
               where line_number >= 2
               order by line_number)
    loop
      l_item := trim(r.col001);
      -- legacy: exit when V_ITEM_CODE is null (the parser leaves empty rows out: a gap in the row numbers is one)
      exit when l_item is null or r.line_number > l_prev + 1;
      l_prev := r.line_number;
      l_unit := tk_num(r.col002);
      l_exp := tk_date(r.col003);
      l_lot := trim(r.col004);
      l_qty := tk_num(r.col005);
      l_price := tk_num(r.col006);
      l_disc := tk_num(r.col007);
      begin
        select item_group_code into l_group from st_item where item_code = l_item;
      exception when others then
        app_act_st.err(-20193, 'خطأ بالصنف ' || l_item, 'Error Item ' || l_item);
      end;
      begin
        select factor into l_factor from st_item_unit where item_code = l_item and group_code = l_group and unit_code = l_unit;
      exception when others then
        l_factor := 1;
      end;
      -- line PRE-INSERT: "يجب إدخال محددات الشحنات" without expiry date or unit
      if l_exp is null or l_unit is null then
        app_act_st.err(-20194, 'يجب إدخال محددات الشحنات (الصف ' || r.line_number || ')',
                       'Must Enter Parameter For Config (row ' || r.line_number || ')');
      end if;
      l_confg := tk_the_config(l_group, l_item, l_price, l_lot, l_exp, h.store);
      if nvl(l_confg, -1) <= 0 then
        app_act_st.err(-20194, 'يجب إدخال محددات الشحنات (الصف ' || r.line_number || ')',
                       'Must Enter Parameter For Config (row ' || r.line_number || ')');
      end if;
      l_cost := tk_insert_cost(h, l_group, l_item, l_confg, l_unit);
      tk_insert(h, 'ST_TAKING', l_no, l_group, l_item, l_unit, l_confg, l_qty, l_factor, l_cost * l_factor, l_cost,
                l_price, l_disc);
      l_no := l_no + 1;
      l_n := l_n + 1;
    end loop;
    app_act_st.set_message('تم تحميل ملف الأكسل (' || l_n || ' سطر)', 'File Loades (' || l_n || ' lines)');
    return p_rowid;
  end tk_load_file;

  function tk_load_lots (p_rowid in varchar2, p_file in varchar2) return varchar2 is
    h        tk_hdr := tk_must(p_rowid, 'ST_TAKING');
    l_blob   blob;
    l_fn     varchar2(400);
    l_c1     varchar2(4000);
    l_c2     varchar2(4000);
    l_confg  number;
    l_qty    number;
    l_item   varchar2(100);
    l_unit   number;
    l_exp    date;
    l_lotno  varchar2(200);
    l_price  number;
    l_disc   number;
    l_group  number;
    l_factor number;
    l_cost   number;
    l_no     number;
    l_n      number := 0;
    l_prev   number := 1;
    l_errs   varchar2(4000);
    procedure log_err (p_line in varchar2) is
    begin
      if nvl(length(l_errs), 0) < 3500 then
        l_errs := l_errs || case when l_errs is not null then ' | ' end || p_line;
      end if;
    end log_err;
  begin
    if tk_lines(h, 'ST_TAKING') > 0 then
      app_act_st.err(-20192, 'يوجد تفاصيل', 'The stocktaking already has lines');
    end if;
    app_act_st.get_file(p_file, l_blob, l_fn);
    l_no := tk_next_no(h, 'ST_TAKING');
    for r in (select line_number, col001, col002
                from table(apex_data_parser.parse(p_content => l_blob, p_file_name => l_fn))
               where line_number >= 2
               order by line_number)
    loop
      l_c1 := trim(r.col001);
      l_c2 := trim(r.col002);
      exit when l_c1 is null or r.line_number > l_prev + 1;         -- legacy: exit when LINEBUF is null (empty row)
      l_prev := r.line_number;
      if l_c2 is null and instr(l_c1, ',') > 0 then                  -- legacy line "ITEM_CONFG_ID,QTY" in one cell
        l_c2 := substr(l_c1, instr(l_c1, ',') + 1);
        l_c1 := substr(l_c1, 1, instr(l_c1, ',') - 1);
      end if;
      l_confg := tk_num(l_c1);
      l_qty := tk_num(l_c2);
      begin
        select g.item_code, u.unit_code, g.expire_date, g.lot_number, g.unit_price, g.disc_ratio
          into l_item, l_unit, l_exp, l_lotno, l_price, l_disc
          from st_item_confg g, st_item_unit u
         where g.item_confg_id = l_confg and u.item_code = g.item_code and u.group_code = g.group_code
           and nvl(u.basic_unit, 0) = 1;
      exception when others then
        log_err(l_c1 || ',' || l_c2 || ' - Error confg ' || l_c1);   -- legacy error file C:\ITEMS_LOAD_ERROR.TXT
        continue;
      end;
      begin
        select item_group_code into l_group from st_item where item_code = l_item;
      exception when others then
        log_err(l_c1 || ',' || l_c2 || ' - Error Item ' || l_item);
        continue;
      end;
      begin
        select factor into l_factor from st_item_unit where item_code = l_item and group_code = l_group and unit_code = l_unit;
      exception when others then
        l_factor := 1;
      end;
      if l_exp is null or l_unit is null then
        app_act_st.err(-20194, 'يجب إدخال محددات الشحنات (الشحنة ' || l_confg || ')',
                       'Must Enter Parameter For Config (lot ' || l_confg || ')');
      end if;
      l_cost := tk_insert_cost(h, l_group, l_item, l_confg, l_unit);
      tk_insert(h, 'ST_TAKING', l_no, l_group, l_item, l_unit, l_confg, l_qty, l_factor, l_cost * l_factor, l_cost,
                l_price, l_disc);
      l_no := l_no + 1;
      l_n := l_n + 1;
    end loop;
    app_act_st.set_message('تم تحميل ملف الأكسل (' || l_n || ' سطر)' || case when l_errs is not null then ' - أخطاء: ' || l_errs end,
                           'File Loades (' || l_n || ' lines)' || case when l_errs is not null then ' - errors: ' || l_errs end);
    return p_rowid;
  end tk_load_lots;

  function tk_diff (a in number, b in number) return boolean is
  begin
    return (a is null and b is not null) or (a is not null and b is null) or a <> b;
  end tk_diff;

  procedure tk_after_save (p_request in varchar2, p_rowid in varchar2) is
    h tk_hdr := tk_get(p_rowid, 'ST_TAKING');
  begin
    if not h.found then return; end if;
    for l in (select d.rowid rid, d.sales_price, d.disc1_ratio, d.disc1_value, d.unit_price,
                     c.unit_price lot_price, c.disc_ratio lot_disc
                from st_stock_taking_det d, st_item_confg c
               where c.item_confg_id(+) = d.item_confg_id and d.store_code = h.store and d.st_taking_date = h.tdate)
    loop
      -- DISC1_RATIO / DISC1_VALUE WHEN-VALIDATE-ITEM: "أدخل رقم بقيمة تبدأ من الصفر"
      if nvl(l.disc1_ratio, 0) < 0 or nvl(l.disc1_value, 0) < 0 then
        app_act_st.err(-20195, 'أدخل رقم بقيمة تبدأ من الصفر', 'Enter Value From Zero');
      end if;
      declare
        l_sp   number := nvl(l.lot_price, l.sales_price);                    -- SALES_PRICE: lot price (ITEM_CONFG_LOV)
        l_rat  number := nvl(l.disc1_ratio, l.lot_disc);                     -- DISC1_RATIO: lot DISC_RATIO (LOV)
        l_val  number := case when nvl(l_rat, 0) <> 0 and nvl(l.unit_price, 0) <> 0 then l_rat * l.unit_price / 100 else 0 end;
      begin
        if    tk_diff(l_sp, l.sales_price) or tk_diff(l_rat, l.disc1_ratio) or tk_diff(l_val, l.disc1_value) then
          update st_stock_taking_det set sales_price = l_sp, disc1_ratio = l_rat, disc1_value = l_val where rowid = l.rid;
        end if;
      end;
    end loop;
  end tk_after_save;

  function tk_status (p_rowid in varchar2, p_form in varchar2) return varchar2 is
    h       tk_hdr := tk_get(p_rowid, p_form);
    l_cnt   number;
    l_it    number;
    l_is    number;
    l_rt    number;
    l_rs    number;
    l_like  varchar2(100);
  begin
    if not h.found then return null; end if;
    if upper(p_form) = 'ST_TAKING2' then
      -- ST_TAKING2.fmx: adjustments of this revaluation count (ST_TRNS_MAST.SERIAL_TAKING_TEMP)
      select count(1) into l_cnt from st_trns_mast
       where trns_type_code in (select trns_type_code from st_trns_type where effect in (1, 2) and trns_type = 7)
         and store_code = h.store and trns_date = h.tdate and serial_taking_temp = h.serial;
      if l_cnt > 0 then
        select min(trns_type_code), min(trns_serial) into l_it, l_is from st_trns_mast
         where trns_type_code in (select trns_type_code from st_trns_type where effect = 2 and trns_type = 7)
           and store_code = h.store and trns_date = h.tdate and serial_taking_temp = h.serial;
        select min(trns_type_code), min(trns_serial) into l_rt, l_rs from st_trns_mast
         where trns_type_code in (select trns_type_code from st_trns_type where effect = 1 and trns_type = 7)
           and store_code = h.store and trns_date = h.tdate and serial_taking_temp = h.serial;
      end if;
    else
      -- ST_STOCK_TAKING POST-QUERY: documents of ST_AUTO_ADJ for this store and date
      l_like := 'Automatic adjustment for stocktaking in date ' || to_char(h.tdate, 'DD-MM-YYYY');
      select count(1) into l_cnt from st_trns_mast
       where trns_type_code in (select trns_type_code from st_trns_type where effect in (1, 2) and trns_type = 7)
         and store_code = h.store and trns_date = h.tdate and nvl(delete_flag, 0) = 0 and desc_e like l_like;
      if l_cnt > 0 then
        select min(trns_type_code), min(trns_serial) into l_it, l_is from st_trns_mast
         where trns_type_code in (select trns_type_code from st_trns_type where effect = 2 and trns_type = 7)
           and store_code = h.store and trns_date = h.tdate and nvl(delete_flag, 0) = 0 and desc_e like l_like;
        select min(trns_type_code), min(trns_serial) into l_rt, l_rs from st_trns_mast
         where trns_type_code in (select trns_type_code from st_trns_type where effect = 1 and trns_type = 7)
           and store_code = h.store and trns_date = h.tdate and nvl(delete_flag, 0) = 0 and desc_e like l_like;
      end if;
    end if;
    if nvl(l_cnt, 0) = 0 then
      return app_act_st.m('لم يتم تسوية الجرد', 'Non Adjustement Taking ');
    end if;
    return app_act_st.m('تم عمل تسوية جرد حركة وارد رقم ' || l_rt || '/' || l_rs || ' حركة صادر ' || l_it || '/' || l_is,
                        'Adjustment Trns With No ' || l_rt || '/' || l_rs || ' Issue Trns ' || l_it || '/' || l_is);
  end tk_status;

  function tk_total_qty (p_rowid in varchar2, p_form in varchar2) return varchar2 is
    h tk_hdr := tk_get(p_rowid, p_form);
    l number;
  begin
    if not h.found then return null; end if;
    if upper(p_form) = 'ST_TAKING2' then
      select sum(quantity) into l from st_stock_taking_temp_det
       where store_code = h.store and st_taking_date = h.tdate and serial = h.serial;
    else
      select sum(quantity) into l from st_stock_taking_det where store_code = h.store and st_taking_date = h.tdate;
    end if;
    return rtrim(to_char(nvl(l, 0), 'FM999G999G999G990D999', 'NLS_NUMERIC_CHARACTERS=''.,'''), '.');
  end tk_total_qty;

  -- ================================================================ ST_ITEM_REQ / ST_ITEM_REQ_HANDLE (F5)
  function rq_get (p_rowid in varchar2) return st_item_req%rowtype is
    r st_item_req%rowtype;
  begin
    select * into r from st_item_req where rowid = app_act_st.rid(p_rowid);
    return r;
  exception when no_data_found then
    return r;
  end rq_get;

  -- the request takes new lines: not converted (legacy "لا يمكن انشاء سجل جديد بسبب ارتباط السجل الرئيسى بمرحلة تالية")
  function rq_open (r in st_item_req%rowtype) return boolean is
    l_n number;
  begin
    select count(*) into l_n from pr_order_det_request where req_trns_type_code = r.trns_type_code and req_trns_serial = r.trns_serial;
    if l_n = 0 then
      select count(*) into l_n from st_trns_det_request where req_trns_type_code = r.trns_type_code and req_trns_serial = r.trns_serial;
    end if;
    if l_n = 0 then
      select count(*) into l_n from st_item_req_det
       where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and nvl(pr_flag, 0) > 0;
    end if;
    return l_n = 0;
  end rq_open;

  function rq_can_fill (p_rowid in varchar2) return varchar2 is
    r st_item_req%rowtype := rq_get(p_rowid);
  begin
    return case when r.trns_type_code is not null and rq_open(r) then 'Y' else 'N' end;
  exception when others then
    return 'N';
  end rq_can_fill;

  -- appends one line per item (basic unit) with the requested quantity; items with no quantity are counted as skipped
  procedure rq_add_line (r in st_item_req%rowtype, p_serial in out number, p_group in number, p_item in varchar2,
                         p_unit in number, p_qty in number, p_added in out number, p_skipped in out number) is
  begin
    if nvl(p_qty, 0) <= 0 then
      p_skipped := p_skipped + 1;
      return;
    end if;
    insert into st_item_req_det (trns_type_code, trns_serial, item_serial, group_code, item_code, unit_code, req_qty, quantity,
                                 basic_qty, req_date, date_serial, pr_flag)
    values (r.trns_type_code, r.trns_serial, p_serial, p_group, p_item, p_unit, p_qty, p_qty,
            p_qty * nvl((select max(factor) from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit), 1),
            r.req_date, r.date_serial, 0);
    p_serial := p_serial + 1;
    p_added := p_added + 1;
  end rq_add_line;

  function rq_fill_msg (p_added in number, p_skipped in number) return varchar2 is
  begin
    return app_act_st.m('تم إضافة ' || p_added || ' صنف' ||
                          case when p_skipped > 0 then ' (لم يتم إضافة ' || p_skipped || ' صنف لأن الكمية المطلوبة (الحد الأدنى للصنف بالمخزن) صفر)' end,
                        p_added || ' items added' ||
                          case when p_skipped > 0 then ' (' || p_skipped || ' items skipped: the requested quantity (store minimum limit) is zero)' end);
  end rq_fill_msg;

  function rq_fill_general (p_rowid in varchar2, p_quan_limit in number, p_from_group in number, p_to_group in number,
                            p_from_item in varchar2, p_to_item in varchar2) return varchar2 is
    r        st_item_req%rowtype := rq_get(p_rowid);
    l_serial number;
    l_qty    number;
    l_added  number := 0;
    l_skip   number := 0;
  begin
    if r.trns_type_code is null then
      app_act_st.err(-20196, 'يجب حفظ الطلب أولا', 'Save the request first');
    end if;
    if not rq_open(r) then
      app_act_st.err(-20184, 'لا يمكن انشاء سجل جديد بسبب ارتباط السجل الرئيسى بمرحلة تالية', 'The request is already processed: no new lines');
    end if;
    if nvl(p_quan_limit, 0) <= 0 then
      app_act_st.err(-20185, 'الكمية يجب أن تكون أكبر من الصفر', 'The quantity must be greater than zero');
    end if;
    select nvl(max(item_serial), 0) + 1 into l_serial from st_item_req_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    -- ST_ITEM_REQ.fmx QUAN_BUTTON: items (basic unit) whose balance in the requesting store is below the limit
    for it in (select it.item_group_code, it.item_code, iu.unit_code
                 from st_item it, st_item_unit iu, st_unit u, st_item_group sg
                where it.item_code = iu.item_code and it.item_group_code = iu.group_code and iu.unit_code = u.unit_code
                  and iu.basic_unit = 1 and nvl(it.stop_flag, 0) = 0
                  and (p_from_group is null or it.item_group_code >= p_from_group)
                  and (p_to_group is null or it.item_group_code <= p_to_group)
                  and (p_from_item is null or it.item_code >= p_from_item)
                  and (p_to_item is null or it.item_code <= p_to_item)
                  and get_balance(r.store_code, it.item_group_code, it.item_code) < nvl(p_quan_limit, 0)
                  and sg.item_group_code = it.item_group_code and nvl(sg.stop_flag, 0) = 0
                order by it.item_code)
    loop
      -- requested quantity: SELECT NVL(MIN_LIMIT, 0) QTY FROM ST_STORE_ITEM (requesting store)
      select nvl(max(nvl(min_limit, 0)), 0) into l_qty from st_store_item
       where store_code = r.store_code and group_code = it.item_group_code and item_code = it.item_code;
      rq_add_line(r, l_serial, it.item_group_code, it.item_code, it.unit_code, l_qty, l_added, l_skip);
    end loop;
    app_act_st.set_message(rq_fill_msg(l_added, l_skip));
    return p_rowid;
  end rq_fill_general;

  function rq_fill_reorder (p_rowid in varchar2, p_from_group in number, p_to_group in number,
                            p_from_item in varchar2, p_to_item in varchar2) return varchar2 is
    r        st_item_req%rowtype := rq_get(p_rowid);
    l_serial number;
    l_added  number := 0;
    l_skip   number := 0;
  begin
    if r.trns_type_code is null then
      app_act_st.err(-20196, 'يجب حفظ الطلب أولا', 'Save the request first');
    end if;
    if not rq_open(r) then
      app_act_st.err(-20184, 'لا يمكن انشاء سجل جديد بسبب ارتباط السجل الرئيسى بمرحلة تالية', 'The request is already processed: no new lines');
    end if;
    select nvl(max(item_serial), 0) + 1 into l_serial from st_item_req_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    -- ST_ITEM_REQ.fmx REC_LIMIT: items of the requesting store below the reorder limit, quantity = MIN_LIMIT
    for it in (select it.item_group_code, it.item_code, iu.unit_code, nvl(sgs.min_limit, 0) qty
                 from st_item it, st_item_unit iu, st_unit u, st_item_group sg, st_store_item sgs
                where it.item_code = iu.item_code and it.item_group_code = iu.group_code and iu.unit_code = u.unit_code
                  and sgs.group_code = it.item_group_code and sgs.item_code = it.item_code and sgs.store_code = r.store_code
                  and iu.basic_unit = 1 and nvl(it.stop_flag, 0) = 0
                  and (p_from_group is null or it.item_group_code >= p_from_group)
                  and (p_to_group is null or it.item_group_code <= p_to_group)
                  and (p_from_item is null or it.item_code >= p_from_item)
                  and (p_to_item is null or it.item_code <= p_to_item)
                  and nvl(get_balance(r.store_code, it.item_group_code, it.item_code), 0) < nvl(sgs.reorder_limit, 0)
                  and sg.item_group_code = it.item_group_code and nvl(sg.stop_flag, 0) = 0
                order by it.item_code)
    loop
      rq_add_line(r, l_serial, it.item_group_code, it.item_code, it.unit_code, it.qty, l_added, l_skip);
    end loop;
    app_act_st.set_message(rq_fill_msg(l_added, l_skip));
    return p_rowid;
  end rq_fill_reorder;

  function rq_warn_outstanding (p_rowid in varchar2, p_form in varchar2) return varchar2 is
    r     st_item_req%rowtype := rq_get(p_rowid);
    l_dem number;
    l_in  number;
    l_msg varchar2(4000);
  begin
    if r.trns_type_code is null then return null; end if;
    -- program unit CHK_OUTSTANDING_QTY (called by the line PRE-INSERT); the legacy binds :b1 / :b2 are the request's own
    -- TRNS_TYPE_CODE / TRNS_SERIAL; ST_ITEM_REQ also compares COLOR_CODE / SIZE_CODE with "=" (ST_ITEM_REQ_HANDLE does not)
    for l in (select group_code, item_code, unit_code, color_code, size_code from st_item_req_det
               where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial order by item_serial) loop
      if upper(p_form) = 'ST_ITEM_REQ_HANDLE' then
        select nvl(sum(quantity), 0) into l_dem from pr_order_det
         where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial
           and group_code = l.group_code and item_code = l.item_code and unit_code = l.unit_code;
        select nvl(sum(nvl(d.income_quantity, 0)), 0) into l_in from pr_income_lot_det d, pr_income_lot m
         where d.trns_type_code = m.trns_type_code and d.trns_serial = m.trns_serial
           and m.order_trns_type_code = r.trns_type_code and m.order_trns_serial = r.trns_serial
           and d.group_code = l.group_code and d.item_code = l.item_code and d.unit_code = l.unit_code;
      else
        select nvl(sum(quantity), 0) into l_dem from pr_order_det
         where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial
           and group_code = l.group_code and item_code = l.item_code and unit_code = l.unit_code
           and color_code = l.color_code and size_code = l.size_code;
        select nvl(sum(nvl(d.income_quantity, 0)), 0) into l_in from pr_income_lot_det d, pr_income_lot m, st_item_confg con
         where d.trns_type_code = m.trns_type_code and d.trns_serial = m.trns_serial
           and m.order_trns_type_code = r.trns_type_code and m.order_trns_serial = r.trns_serial
           and d.group_code = l.group_code and d.item_code = l.item_code and d.unit_code = l.unit_code
           and d.item_confg_id = con.item_confg_id and con.color_code = l.color_code and con.size_code = l.size_code;
      end if;
      if l_dem - l_in > 0 and nvl(length(l_msg), 0) < 3500 then
        l_msg := l_msg || case when l_msg is not null then chr(10) end ||
                 app_act_st.m('هناك كمية ' || (l_dem - l_in) || ' من الصنف ' || l.item_code || ' لم يتم إستلامها',
                              'There is a quantity ' || (l_dem - l_in) || ' of item ' || l.item_code || ' not received yet');
      end if;
    end loop;
    return l_msg;
  end rq_warn_outstanding;

  function rq_warn_estimate (p_rowid in varchar2) return varchar2 is
    r     st_item_req%rowtype := rq_get(p_rowid);
    l_n   number;
    l_est number;
    l_tot number;
  begin
    if r.trns_type_code is null then return null; end if;
    -- CHECK_EST: only with ST_BASIC.EST_FLAG = 1 (project estimates)
    select count(1) into l_n from st_basic where est_flag = 1;
    if l_n = 0 then return null; end if;
    for l in (select group_code, item_code, unit_code, color_code, size_code from st_item_req_det
               where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial) loop
      select max(quantity) into l_est from st_proj_est_det d
       where d.store_code = r.store_code and group_code = l.group_code and item_code = l.item_code and unit_code = l.unit_code
         and d.trns_serial in (select max(trns_serial) from st_proj_est_det
                                where store_code = r.store_code and group_code = l.group_code and item_code = l.item_code
                                  and unit_code = l.unit_code)
         and color_code = l.color_code and size_code = l.size_code;
      select sum(quantity) into l_tot from st_item_req_det d, st_item_req m
       where d.trns_type_code = m.trns_type_code and d.trns_serial = m.trns_serial and m.store_code = r.store_code
         and group_code = l.group_code and item_code = l.item_code and unit_code = l.unit_code
         and color_code = l.color_code and size_code = l.size_code;
      if l_tot > l_est then
        return app_act_st.m('هناك أصناف تعدت الكمية المحددة فى تقدير المشروع',
                            'Some items exceeded the quantity of the project estimate');
      end if;
    end loop;
    return null;
  end rq_warn_estimate;

  procedure rq_delete_check (p_type in varchar2, p_serial in varchar2) is
    l_type   number := app_act_st.num(p_type);
    l_serial number := app_act_st.num(p_serial);
    l_n      number;
  begin
    -- header KEY-DELREC: linked purchase request (PR_ORDER_DET_REQUEST) or transfer request (ST_TRNS_DET_REQUEST)
    select count(1) into l_n from pr_order_det_request d where req_trns_type_code = l_type and req_trns_serial = l_serial;
    if l_n = 0 then
      select count(1) into l_n from st_trns_det_request d where req_trns_type_code = l_type and req_trns_serial = l_serial;
    end if;
    if l_n > 0 then
      app_act_st.err(-20197, 'طلب النواقص الحالي له طلب شراء او عروض أسعار مرتبطة و لا يمكن الحذف',
                     'This material request has linked purchase / transfer requests and cannot be deleted');
    end if;
  end rq_delete_check;

  function rq_item_count (p_rowid in varchar2) return varchar2 is
    r st_item_req%rowtype := rq_get(p_rowid);
    l number;
  begin
    if r.trns_type_code is null then return null; end if;
    select count(*) into l from st_item_req_det where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial;
    return to_char(l);
  end rq_item_count;

  function rq_proj_ref (p_rowid in varchar2) return varchar2 is
    r st_item_req%rowtype := rq_get(p_rowid);
    l varchar2(4000);
  begin
    if r.trns_type_code is null then return null; end if;
    select max(proj_ref) into l from st_proj_est_mast
     where store_code = r.store_code and trns_serial in (select max(trns_serial) from st_proj_est_mast where store_code = r.store_code);
    return l;
  end rq_proj_ref;

end app_act_st;
/
show errors package body app_act_st
