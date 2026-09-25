-- =====================================================================================================
-- APP_RULES_PR : legacy business rules of the Purchasing data-entry screens (Stage C, wave 2)
--   PR_ORDER        purchase orders                 (PR_ORDER + PR_ORDER_DET / _SRVC / _ASST)
--   PR_INCOME_LOT   incoming lots                   (PR_INCOME_LOT + _DET / _SRVC / _ASST / _DET_EXPENS, AS_ASSET_ACCT_TOT)
--   ST_RECEIVE_COST purchase invoices               (ST_TRNS_MAST + ST_TRNS_DET / _DET_EXPENS / _DET_DUES), types EFFECT=1, TRNS_TYPE in (1,5)
--   ST_RETURN_COST  purchase returns per invoice    (ST_TRNS_MAST + ST_TRNS_DET), types EFFECT=3, TRNS_TYPE in (3,5), RET_TRNS_* set
--   ST_RETURN_COST2 purchase returns w/o invoice    (same tables, RET_TRNS_* null)
-- Used by app\legacy\overrides\<FORM>.json ("rules": validations / row_rules / after_save / defaults).
-- Evidence and rule list: app\legacy\processes\<FORM>.md.  Error codes -20120 .. -20149, Arabic messages.
-- ST_TRNS_MAST / ST_TRNS_DET are shared with stock and sales screens: every row rule is guarded by
-- is_purchase_type(); functions called from row triggers never fail on ORA-04091 (mutating table).
-- Existing legacy DB triggers are NOT duplicated: CLOSE_ST_TRNS_MAST (AC_BASIC min/max date), *_TAX (tax
-- period lock), ST_TRNS_MAST_IN (DATE_SERIAL), *_ALTKEY, ST_TRNS_DET_C_IN/UP/DL (cost and balance).
-- Wave 3: bypass flag for the rows written by the APP_ACT_PR buttons (23_act_pr.sql), TAX_LIB_NEW GET_TAX_VALUE /
-- GET_TAX_VALUE_MAST (line_tax / mast_tax) in the after-save of orders, lots, purchase invoices and returns (changed lines found
-- with a flashback query of the committed rows), DISTRIBUTE_DISC / UPDATE_COST, return-without-invoice price, CHECK_FILE_PREV.
-- =====================================================================================================
set define off

create or replace package app_rules_pr as
  -- ---------------------------------------------------------------- classification
  function is_receive_type (p_type number) return number;   -- purchase invoice: EFFECT=1, TRNS_TYPE in (1,5), NO_COST=0
  function is_return_type  (p_type number) return number;   -- purchase return : EFFECT=3, TRNS_TYPE in (3,5)
  function is_purchase_type(p_type number) return number;   -- either of the two
  function is_order_type   (p_type number) return number;   -- PR_ORDER        : EFFECT=7, TRNS_TYPE=14
  function is_lot_type     (p_type number) return number;   -- PR_INCOME_LOT   : EFFECT=7, TRNS_TYPE=15
  function default_type    (p_form varchar2) return number; -- RECEIVE | RETURN | ORDER | LOT : lowest type the user may use

  -- ---------------------------------------------------------------- small helpers (safe inside row triggers)
  function chg(p_new number,   p_old number)   return number;
  function chg(p_new varchar2, p_old varchar2) return number;
  function chg(p_new date,     p_old date)     return number;
  function item_group   (p_item varchar2) return number;
  function basic_unit   (p_group number, p_item varchar2) return number;
  function unit_factor  (p_group number, p_item varchar2, p_unit number) return number;
  function type_store   (p_type number) return number;
  function supplier_resp(p_supplier number) return number;
  function supplier_gln (p_supplier number) return varchar2;
  function supplier_currency(p_supplier number) return number;
  function currency_rate(p_currency number, p_date date default null, p_srv_rate number default 0) return number;
  function st_rate      (p_type number, p_serial number) return number;
  function st_supplier  (p_type number, p_serial number) return number;
  function st_store     (p_type number, p_serial number) return number;
  function st_invoice_no(p_type number, p_serial number) return varchar2;
  function next_st_doc_no(p_type number, p_store number) return number;
  function next_order_doc_no return varchar2;
  function next_lot_doc_no   return varchar2;
  function next_lot_serial(p_type number, p_serial number) return number;
  function order_date   (p_type number, p_serial number) return date;
  function lot_value    (p_type number, p_serial number, p_what varchar2) return number;
  function lot_arrival  (p_type number, p_serial number) return date;
  procedure pair_ratio(p_inserting boolean, p_qty number, p_old_qty number,
                       p_ratio in out number, p_old_ratio number, p_value in out number, p_old_value number);
  -- cascading line discounts (DISCn_RATIO / DISCn_VALUE per unit): d1 = r1*price/100, d2 = r2*(price-d1)/100, d3 = r3*(price-d1-d2)/100
  procedure disc_chain(p_inserting boolean, p_price number, p_old_price number,
                       r1 in out number, o_r1 number, v1 in out number, o_v1 number,
                       r2 in out number, o_r2 number, v2 in out number, o_v2 number,
                       r3 in out number, o_r3 number, v3 in out number, o_v3 number);
  -- ST_TRNS_DET: lot configuration (ITEM_CONFG_ID) of a purchase-invoice line, created when missing (GET_CONFG_ID)
  function receive_line_confg(p_type number, p_serial number, p_group number, p_item varchar2, p_unit number,
                              p_lot number, p_expiry date, p_sales_price number, p_sales_disc number, p_production date) return number;
  procedure check_next_posted(p_type number, p_serial number, p_group number, p_item varchar2);

  -- ---------------------------------------------------------------- page validations (return Arabic text or null)
  function check_st_header(p_form varchar2, p_rowid varchar2, p_type varchar2, p_date varchar2, p_store varchar2,
                           p_supplier varchar2, p_currency varchar2, p_rate varchar2, p_due_date varchar2,
                           p_doc_no varchar2, p_ret_type varchar2, p_ret_serial varchar2) return varchar2;
  function check_st_locked(p_rowid varchar2) return varchar2;
  function check_order_header(p_rowid varchar2, p_type varchar2, p_date varchar2, p_store varchar2,
                              p_supplier varchar2, p_currency varchar2, p_rate varchar2) return varchar2;
  function check_order_locked(p_rowid varchar2, p_confirm varchar2, p_close varchar2) return varchar2;
  function check_lot_header(p_rowid varchar2, p_type varchar2, p_flag varchar2, p_arrival varchar2, p_store varchar2,
                            p_supplier varchar2, p_currency varchar2, p_rate varchar2,
                            p_order_type varchar2, p_order_serial varchar2) return varchar2;
  function check_lot_locked(p_rowid varchar2) return varchar2;

  -- ---------------------------------------------------------------- row-rule checks (raise -201xx)
  procedure order_update_check(p_type number, p_serial number, p_old_confirm number, p_new_confirm number);
  procedure order_line_guard(p_type number, p_serial number);
  procedure lot_line_guard(p_type number, p_serial number);

  -- ---------------------------------------------------------------- after save / delete (raise -201xx -> whole save rolled back)
  procedure receive_after_save(p_rowid varchar2, p_request varchar2);
  procedure return_after_save (p_rowid varchar2, p_request varchar2, p_form varchar2);
  procedure st_after_delete   (p_rowid varchar2, p_form varchar2, p_type varchar2 default null, p_serial varchar2 default null);
  procedure order_after_save  (p_rowid varchar2, p_request varchar2);
  procedure order_after_delete(p_rowid varchar2, p_type varchar2 default null, p_serial varchar2 default null);
  procedure lot_after_save    (p_rowid varchar2, p_request varchar2);
  procedure lot_after_delete  (p_rowid varchar2, p_type varchar2 default null, p_serial varchar2 default null);
  -- stock may not become negative after this document (running balance per store / lot configuration)
  procedure check_stock(p_type number, p_serial number);

  -- ---------------------------------------------------------------- wave 3 (buttons of APP_ACT_PR, taxes)
  -- The legacy buttons wrote complete rows with plain INSERT / UPDATE (only the DB triggers ran). While APP_ACT_PR writes
  -- such rows, the row rules of the purchasing overrides stand aside: every row rule text tests "app_rules_pr.bypass = 0".
  procedure set_bypass(p_on boolean);
  function bypass return number;
  -- TAX_LIB_NEW.GET_TAX_VALUE, purchase path (no area, no customer): TAX_CODE1 / TAX_VALUE1 of a line for a value in riyal.
  -- Supplier row of the current tax type -> DECODE(supplier %, 0, 0, item %) else the item row; nothing found -> unchanged.
  procedure line_tax(p_group number, p_item varchar2, p_supplier number, p_date date, p_value number,
                     p_code in out number, p_tax in out number);
  -- TAX_LIB_NEW.GET_TAX_VALUE_MAST, purchase path: header TAX_CODE1 / TAX_VALUE1 (tax share of the invoice discount + tax on
  -- the transport expense). p_det_tax = total line (+ service) tax; null when the calling screen has no such block (PR_ORDER).
  procedure mast_tax(p_supplier number, p_date date, p_total number, p_disc number, p_det_tax number, p_transport number,
                     p_code in out number, p_tax in out number);
  -- CHECK_FILE_PREV(serial, 2) of the legacy library: any right on (system, serial) in FILE_PASSWORD; user 0 always
  function file_right(p_system number, p_serial number, p_user number default null) return number;
end app_rules_pr;
/

create or replace package body app_rules_pr as
  e_mutating exception;
  pragma exception_init(e_mutating, -4091);
  g_bypass boolean := false;

  procedure set_bypass(p_on boolean) is
  begin
    g_bypass := nvl(p_on, false);
  end;

  function bypass return number is
  begin
    return case when g_bypass then 1 else 0 end;
  end;

  -- ================================================================ conversions
  function n(p varchar2) return number is
  begin
    return to_number(trim(p));
  exception when others then
    begin return to_number(replace(trim(p), ',', '')); exception when others then return null; end;
  end;

  function d(p varchar2) return date is
  begin
    if p is null then return null; end if;
    begin return to_date(trim(p), 'DD/MM/YYYY'); exception when others then null; end;
    begin return to_date(substr(trim(p), 1, 10), 'YYYY-MM-DD'); exception when others then null; end;
    begin return to_date(trim(p)); exception when others then return null; end;
  end;

  function pwd return number is
  begin
    return nvl(n(v('G_PASSWORD_NUMBER')), 0);
  end;

  -- AC_BASIC.CLOSE_DATE of the session company (legacy TRNS_DATE WVI / CLOSE_ACC)
  function close_date return date is
    v_comp number := n(v('G_COMPANY_CODE'));
    v_date date;
  begin
    select max(close_date) into v_date from ac_basic where company_code = nvl(v_comp, company_code);
    return v_date;
  end;

  function type_allowed(p_type number) return boolean is
    v number;
    v_pwd number := pwd;
  begin
    if v_pwd = 0 then return true; end if;
    select count(*) into v from st_trnstype_password where flag = 1 and password_number = v_pwd and trns_type_code = p_type;
    return v > 0;
  end;

  -- ================================================================ classification
  function type_is(p_type number, p_effect number, p_types varchar2, p_no_cost number default null) return number is
    v number;
  begin
    if p_type is null then return 0; end if;
    select count(*) into v from st_trns_type
     where trns_type_code = p_type and effect = p_effect
       and instr(',' || p_types || ',', ',' || to_char(trns_type) || ',') > 0
       and (p_no_cost is null or nvl(no_cost, 0) = p_no_cost);
    return case when v > 0 then 1 else 0 end;
  end;

  function is_receive_type (p_type number) return number is begin return type_is(p_type, 1, '1,5', 0); end;
  function is_return_type  (p_type number) return number is begin return type_is(p_type, 3, '3,5'); end;
  function is_purchase_type(p_type number) return number is
  begin
    return case when is_receive_type(p_type) = 1 or is_return_type(p_type) = 1 then 1 else 0 end;
  end;
  function is_order_type   (p_type number) return number is begin return type_is(p_type, 7, '14'); end;
  function is_lot_type     (p_type number) return number is begin return type_is(p_type, 7, '15'); end;

  function default_type(p_form varchar2) return number is
    v number;
    v_pwd number := pwd;
  begin
    select min(t.trns_type_code) into v from st_trns_type t
     where ((p_form = 'RECEIVE' and t.effect = 1 and t.trns_type in (1, 5) and nvl(t.no_cost, 0) = 0)
         or (p_form = 'RETURN'  and t.effect = 3 and t.trns_type in (3, 5))
         or (p_form = 'ORDER'   and t.effect = 7 and t.trns_type = 14)
         or (p_form = 'LOT'     and t.effect = 7 and t.trns_type = 15))
       and (v_pwd = 0 or t.trns_type_code in (select trns_type_code from st_trnstype_password where flag = 1 and password_number = v_pwd));
    return v;
  end;

  -- ================================================================ helpers
  function chg(p_new number, p_old number) return number is
  begin
    return case when (p_new is null and p_old is null) or p_new = p_old then 0 else 1 end;
  end;
  function chg(p_new varchar2, p_old varchar2) return number is
  begin
    return case when (p_new is null and p_old is null) or p_new = p_old then 0 else 1 end;
  end;
  function chg(p_new date, p_old date) return number is
  begin
    return case when (p_new is null and p_old is null) or p_new = p_old then 0 else 1 end;
  end;

  function item_group(p_item varchar2) return number is
    v number;
  begin
    select min(item_group_code) into v from st_item where item_code = p_item;
    return v;
  end;

  function basic_unit(p_group number, p_item varchar2) return number is
    v number;
  begin
    select min(unit_code) into v from st_item_unit
     where group_code = p_group and item_code = p_item and nvl(basic_unit, 0) = 1;
    if v is null then
      select min(unit_code) into v from st_item_unit where group_code = p_group and item_code = p_item;
    end if;
    return v;
  end;

  function unit_factor(p_group number, p_item varchar2, p_unit number) return number is
    v number;
  begin
    select max(factor) into v from st_item_unit where group_code = p_group and item_code = p_item and unit_code = p_unit;
    return nvl(v, 1);
  end;

  function type_store(p_type number) return number is
    v number;
  begin
    select max(t.store_code) into v from st_trns_type t, st_store s
     where t.trns_type_code = p_type and s.store_code = t.store_code
       and nvl(s.store_status, 0) = 1 and nvl(s.stop_flag, 0) = 0;
    return v;
  end;

  function supplier_resp(p_supplier number) return number is
    v number;
  begin
    select min(code) into v from vn_supp_resp where supp_code = p_supplier;
    return v;
  end;

  function supplier_gln(p_supplier number) return varchar2 is
    v varchar2(100);
  begin
    select min(gln) into v from rsd_supplier_gln where supplier_code = p_supplier;
    return v;
  end;

  function supplier_currency(p_supplier number) return number is
    v number;
  begin
    select max(nvl(currency_code, 1)) into v from supplier where code = p_supplier;
    return nvl(v, 1);
  end;

  -- AC_CURRENCY.RATE; PR_ORDER (p_srv_rate = 1) first looks at AC_CURRENCY_SRV_RATE for the date (legacy SUPPLIER_CODE WVI)
  function currency_rate(p_currency number, p_date date default null, p_srv_rate number default 0) return number is
    v number;
  begin
    if nvl(p_currency, 1) = 1 then return 1; end if;
    if p_srv_rate = 1 then
      begin
        select max(nvl(rate, 0)) into v from ac_currency_srv_rate
         where currency_code = p_currency and nvl(p_date, trunc(sysdate)) between from_date and to_date;
      exception when others then v := null;
      end;
    end if;
    if nvl(v, 0) = 0 then
      select max(nvl(rate, 0)) into v from ac_currency where currency_code = p_currency;
    end if;
    return case when nvl(v, 0) = 0 then 1 else v end;
  end;

  function st_rate(p_type number, p_serial number) return number is
    v number;
  begin
    select max(currency_rate) into v from st_trns_mast where trns_type_code = p_type and trns_serial = p_serial;
    return nvl(v, 1);
  exception when e_mutating then return 1;
  end;

  function st_supplier(p_type number, p_serial number) return number is
    v number;
  begin
    select max(supplier_code) into v from st_trns_mast where trns_type_code = p_type and trns_serial = p_serial;
    return v;
  exception when e_mutating then return null;
  end;

  function st_store(p_type number, p_serial number) return number is
    v number;
  begin
    select max(store_code) into v from st_trns_mast where trns_type_code = p_type and trns_serial = p_serial;
    return v;
  exception when e_mutating then return null;
  end;

  function st_invoice_no(p_type number, p_serial number) return varchar2 is
    v varchar2(100);
  begin
    if p_type is null or p_serial is null then return null; end if;
    select max(invoice_no) into v from st_trns_mast where trns_type_code = p_type and trns_serial = p_serial;
    return v;
  exception when e_mutating then return null;
  end;

  -- legacy GET_NEXT_DOC_NO (ST_RETURN_COST .fmx): max+1 per type and store, first number = store digits 1-2,4-5 || 000001
  function next_st_doc_no(p_type number, p_store number) return number is
    v number;
  begin
    if p_type is null or p_store is null then return null; end if;
    select nvl(max(doc_no), 0) + 1 into v from st_trns_mast
     where trns_type_code = p_type and store_code = p_store and nvl(delete_flag, 0) = 0;
    if v = 1 then
      v := to_number(substr(to_char(p_store), 1, 2) || substr(to_char(p_store), 4, 2) || lpad('1', 6, '0'));
    end if;
    return v;
  exception when e_mutating then return null;
  end;

  -- legacy PR_ORDER.TRNS_TYPE_CODE WVI: NVL(MAX(DOC_NO),0)+1 over all purchase orders (numeric max here)
  function next_order_doc_no return varchar2 is
    v number;
  begin
    select nvl(max(to_number(doc_no default null on conversion error)), 0) + 1 into v from pr_order;
    return to_char(v);
  exception when e_mutating then return null;
  end;

  -- legacy PR_INCOME_LOT.TRNS_TYPE_CODE WVI: NVL(MAX(TO_NUMBER(DOC_NO)),0)+1 over all lots
  function next_lot_doc_no return varchar2 is
    v number;
  begin
    select nvl(max(to_number(doc_no default null on conversion error)), 0) + 1 into v from pr_income_lot;
    return to_char(v);
  exception when e_mutating then return null;
  end;

  -- legacy PR_INCOME_LOT PRE-INSERT: LOT_SERIAL = NVL(MAX(LOT_SERIAL),0)+1 per transaction type
  function next_lot_serial(p_type number, p_serial number) return number is
    v number;
  begin
    select nvl(max(lot_serial), 0) + 1 into v from pr_income_lot where trns_type_code = p_type;
    return v;
  exception when e_mutating then return p_serial;
  end;

  function order_date(p_type number, p_serial number) return date is
    v date;
  begin
    select max(pr_order_date) into v from pr_order where trns_type_code = p_type and trns_serial = p_serial;
    return v;
  exception when e_mutating then return null;
  end;

  function lot_value(p_type number, p_serial number, p_what varchar2) return number is
    v number;
  begin
    select max(case p_what when 'ORDER_TYPE' then order_trns_type_code when 'ORDER_SERIAL' then order_trns_serial
                           when 'STORE' then store_code when 'RATE' then currency_rate when 'SUPPLIER' then supplier_code end)
      into v from pr_income_lot where trns_type_code = p_type and trns_serial = p_serial;
    return v;
  exception when e_mutating then return null;
  end;

  function lot_arrival(p_type number, p_serial number) return date is
    v date;
  begin
    select max(arrival_date) into v from pr_income_lot where trns_type_code = p_type and trns_serial = p_serial;
    return v;
  exception when e_mutating then return null;
  end;

  -- ratio <-> value pairs of a line (BONUS / BONUS_RATIO, EXTRA_BONUS / EXTRA_BONUS_RATIO):
  -- legacy QUANTITY / *_RATIO WVI: value := ROUND(ratio * qty / 100); value WVI: ratio := ROUND(value * 100 / qty, 2)
  procedure pair_ratio(p_inserting boolean, p_qty number, p_old_qty number,
                       p_ratio in out number, p_old_ratio number, p_value in out number, p_old_value number) is
  begin
    if nvl(p_qty, 0) = 0 then return; end if;
    if p_inserting then
      if p_value is null and nvl(p_ratio, 0) <> 0 then
        p_value := round(p_ratio * p_qty / 100);
      elsif p_value is not null and p_ratio is null then
        p_ratio := round(p_value * 100 / p_qty, 2);
      end if;
    else
      if chg(p_value, p_old_value) = 1 then
        p_ratio := case when p_value is null then null else round(p_value * 100 / p_qty, 2) end;
      elsif nvl(p_ratio, 0) <> 0 and (chg(p_ratio, p_old_ratio) = 1 or chg(p_qty, p_old_qty) = 1) then
        p_value := round(p_ratio * p_qty / 100);
      end if;
    end if;
  end;

  procedure disc_level(p_inserting boolean, p_base number, p_base_changed boolean,
                       r in out number, o_r number, v in out number, o_v number) is
  begin
    if nvl(p_base, 0) = 0 then return; end if;
    if (p_inserting and v is not null and r is null) or (not p_inserting and chg(v, o_v) = 1) then
      r := case when v is null then null else v * 100 / p_base end;
    elsif r is not null and ((p_inserting and v is null) or chg(r, o_r) = 1 or p_base_changed) then
      v := r * p_base / 100;
    end if;
  end;

  procedure disc_chain(p_inserting boolean, p_price number, p_old_price number,
                       r1 in out number, o_r1 number, v1 in out number, o_v1 number,
                       r2 in out number, o_r2 number, v2 in out number, o_v2 number,
                       r3 in out number, o_r3 number, v3 in out number, o_v3 number) is
    v_changed boolean := (not p_inserting) and chg(p_price, p_old_price) = 1;
    v_b1 number; v_b2 number;
  begin
    disc_level(p_inserting, p_price, v_changed, r1, o_r1, v1, o_v1);
    v_b1 := p_price - nvl(v1, 0);
    disc_level(p_inserting, v_b1, v_changed or chg(v1, o_v1) = 1, r2, o_r2, v2, o_v2);
    v_b2 := v_b1 - nvl(v2, 0);
    disc_level(p_inserting, v_b2, v_changed or chg(v1, o_v1) = 1 or chg(v2, o_v2) = 1, r3, o_r3, v3, o_v3);
  end;

  -- legacy ST_RECEIVE_COST PRE-INSERT: "يجب إدخال محددات الشحنات" + GET_THE_CONFIG (GET_CONFG_ID with create-if-missing);
  -- the expiry date is only part of the configuration when ST_ITEM_GROUP.EXPIRE_FLAG = 1 (colour / size not used here)
  function receive_line_confg(p_type number, p_serial number, p_group number, p_item varchar2, p_unit number,
                              p_lot number, p_expiry date, p_sales_price number, p_sales_disc number, p_production date) return number is
    v_expire_flag number;
    v_lot   varchar2(100) := to_char(p_lot);
    v_id    number;
    v_supp  number;
    v_store number;
  begin
    if p_lot is null or p_sales_price is null or p_sales_disc is null or p_production is null or p_unit is null then
      raise_application_error(-20121, 'يجب إدخال محددات الشحنات: رقم التشغيلة وتاريخ الصلاحية وتاريخ الانتاج وسعر البيع ونسبة خصم البيع والوحدة - الصنف ' || p_item);
    end if;
    select max(nvl(expire_flag, 0)) into v_expire_flag from st_item_group where item_group_code = p_group;
    if nvl(v_expire_flag, 0) = 1 and p_expiry is null then
      raise_application_error(-20121, 'يجب إدخال تاريخ الصلاحية للصنف ' || p_item);
    end if;
    v_supp  := st_supplier(p_type, p_serial);
    v_store := st_store(p_type, p_serial);
    v_id := get_confg_id(p_item, p_group, v_supp, p_sales_price, v_lot,
                         case when nvl(v_expire_flag, 0) = 1 then p_expiry end,
                         nvl(p_sales_disc, 0), v_store, true, null, null);
    if nvl(v_id, -1) < 0 then
      raise_application_error(-20121, 'تعذر تحديد الشحنة للصنف ' || p_item);
    end if;
    return v_id;
  end;

  -- legacy CHECK_NEXT_POSTED_TRANS (ST_TRNS_DET PRE-INSERT of a purchase invoice)
  procedure check_next_posted(p_type number, p_serial number, p_group number, p_item varchar2) is
    v_date date; v_t number; v_s number;
  begin
    select max(trns_date) into v_date from st_trns_mast where trns_type_code = p_type and trns_serial = p_serial;
    select max(tm.trns_type_code), max(tm.trns_serial) into v_t, v_s
      from st_trns_det td, st_trns_mast tm, st_trns_type tt
     where tm.trns_type_code = td.trns_type_code and tm.trns_serial = td.trns_serial
       and tm.trns_type_code = tt.trns_type_code and tt.effect != 1
       and nvl(tm.post_flag, 0) = 1 and nvl(tm.delete_flag, 0) = 0
       and td.group_code = p_group and td.item_code = p_item and tm.trns_date > v_date
       and rownum = 1;
    if v_t is not null then
      raise_application_error(-20123, 'الصنف ' || p_item || ' له حركة مرحلة ' || v_t || '/' || v_s || ' بتاريخ لاحق');
    end if;
  exception when e_mutating then null;
  end;

  -- ================================================================ taxes (TAX_LIB_NEW, attached library of the purchasing forms)
  procedure line_tax(p_group number, p_item varchar2, p_supplier number, p_date date, p_value number,
                     p_code in out number, p_tax in out number) is
    l_item_per number;
    l_n        number;
  begin
    for t in (select tax_code from tx_taxes_types
               where start_date = (select max(start_date) from tx_taxes_types where start_date <= p_date)
               order by tax_code) loop
      if p_group is not null and p_item is not null then
        select nvl(min(tax_per), 0) into l_item_per
          from tx_taxes_items where group_code = p_group and item_code = p_item and tax_code = t.tax_code;
      end if;
      -- TX_TAXES_AREAS (MAINAREA_ID) and TX_TAXES_CUSTOMERS are not used by purchase documents (both arguments NULL)
      select count(*) into l_n from tx_taxes_suppliers where supplier_code = p_supplier and tax_code = t.tax_code;
      if l_n > 0 then
        for s in (select tax_code, decode(tax_per, 0, 0, nvl(l_item_per, tax_per)) tax_per
                    from tx_taxes_suppliers where supplier_code = p_supplier and tax_code = t.tax_code) loop
          p_code := s.tax_code;
          p_tax  := s.tax_per * p_value / 100;
        end loop;
      else
        for i in (select tax_code, tax_per from tx_taxes_items
                   where group_code = p_group and item_code = p_item and tax_code = t.tax_code) loop
          p_code := i.tax_code;
          p_tax  := i.tax_per * p_value / 100;
        end loop;
      end if;
    end loop;
  end;

  procedure mast_tax(p_supplier number, p_date date, p_total number, p_disc number, p_det_tax number, p_transport number,
                     p_code in out number, p_tax in out number) is
    l_n number;
  begin
    for t in (select tax_code from tx_taxes_types
               where start_date = (select max(start_date) from tx_taxes_types where start_date <= p_date)
               order by tax_code) loop
      if nvl(p_disc, 0) <> 0 and nvl(p_det_tax, 0) <> 0 and nvl(p_total, 0) <> 0 then
        p_code := t.tax_code;
        p_tax  := (p_det_tax / p_total) * - p_disc;
      else
        p_tax := 0;
      end if;
      if p_supplier is not null then
        select count(*) into l_n from tx_taxes_suppliers where supplier_code = p_supplier and tax_code = t.tax_code;
        if l_n > 0 then
          for s in (select tax_code, tax_per from tx_taxes_suppliers where supplier_code = p_supplier and tax_code = t.tax_code) loop
            p_code := s.tax_code;
            p_tax  := nvl(p_tax, 0) + s.tax_per * nvl(p_transport, 0) / 100;
          end loop;
        else
          for f in (select tax_code, transport_tax_per from tx_taxes_fixed_srv where tax_code = t.tax_code) loop
            p_code := f.tax_code;
            p_tax  := nvl(p_tax, 0) + f.transport_tax_per * nvl(p_transport, 0) / 100;
          end loop;
        end if;
      end if;
    end loop;
  end;

  function file_right(p_system number, p_serial number, p_user number default null) return number is
    v_user number := nvl(p_user, n(v('G_USER_CODE')));
    l_n number;
  begin
    if v_user = 0 then return 1; end if;
    select count(*) into l_n from file_password
     where users_code = v_user and system_number = p_system and file_serial = p_serial
       and (nvl(insert_flag, 0) <> 0 or nvl(delete_flag, 0) <> 0 or nvl(update_flag, 0) <> 0 or nvl(query_flag, 0) <> 0);
    return case when l_n > 0 then 1 else 0 end;
  end;

  -- ================================================================ page validations
  function st_row(p_rowid varchar2) return st_trns_mast%rowtype is
    r st_trns_mast%rowtype;
  begin
    if p_rowid is null then return r; end if;
    select * into r from st_trns_mast where rowid = chartorowid(p_rowid);
    return r;
  exception when no_data_found then return r;
  end;

  function st_lines(p_type number, p_serial number) return number is
    v number;
  begin
    select count(*) into v from st_trns_det where trns_type_code = p_type and trns_serial = p_serial;
    return v;
  end;

  function check_st_header(p_form varchar2, p_rowid varchar2, p_type varchar2, p_date varchar2, p_store varchar2,
                           p_supplier varchar2, p_currency varchar2, p_rate varchar2, p_due_date varchar2,
                           p_doc_no varchar2, p_ret_type varchar2, p_ret_serial varchar2) return varchar2 is
    v_type number := n(p_type);   v_date date := d(p_date);    v_store number := n(p_store);
    v_supp number := n(p_supplier); v_curr number := nvl(n(p_currency), 1); v_rate number := n(p_rate);
    v_due  date := d(p_due_date); v_doc number := n(p_doc_no);
    v_rt   number := n(p_ret_type); v_rs number := n(p_ret_serial);
    o      st_trns_mast%rowtype := st_row(p_rowid);
    inv    st_trns_mast%rowtype;
    v      number; v_min date; v_close date; v_rep number;
    v_new  boolean := p_rowid is null;
  begin
    if v_type is null then return 'يجب اختيار نوع الحركة'; end if;
    if (p_form = 'RECEIVE' and is_receive_type(v_type) = 0) or (p_form in ('RETURN', 'RETURN2') and is_return_type(v_type) = 0) then
      return 'نوع الحركة ' || v_type || ' غير مسموح به في هذه الشاشة';
    end if;
    if v_new and not type_allowed(v_type) then return 'لا توجد صلاحية على نوع الحركة ' || v_type; end if;
    if not v_new and (chg(v_type, o.trns_type_code) = 1) then return 'لا يمكن تغيير نوع الحركة بعد الحفظ'; end if;
    -- store (PRE-INSERT: mandatory and not stopped)
    if v_store is null then return 'يجب إدخال رقم المخزن'; end if;
    if v_new or chg(v_store, o.store_code) = 1 then
      select count(*) into v from st_store where store_code = v_store and nvl(stop_flag, 0) = 0 and nvl(store_status, 0) = 1;
      if v = 0 then return 'المخزن الحالى متوقف أو غير فعال'; end if;
    end if;
    -- dates (TRNS_DATE WVI)
    if v_date is null then return 'يجب إدخال تاريخ الحركة'; end if;
    if v_new or chg(v_date, o.trns_date) = 1 then
      select min(min_date) into v_min from st_basic;
      if v_min is not null and trunc(v_date) < trunc(v_min) then
        return 'الحد الأدنى لتاريخ الحركة هو ' || to_char(v_min, 'DD/MM/YYYY');
      end if;
      v_close := close_date;
      if v_close is not null and v_date <= v_close then return 'يجب ان يكون تاريخ القيد بعد تاريخ اخر اقفال'; end if;
    end if;
    -- currency rate (CURRENCY_RATE WVI)
    if nvl(v_rate, 0) <= 0 then return 'يجب ادخال معامل التحويل'; end if;
    if v_curr = 1 and v_rate <> 1 then return 'معامل تحويل الريال يجب ان يكون ب 1'; end if;
    -- date / currency / rate / store are fixed once lines exist (PRE-TEXT-ITEM of TRNS_DATE, CURRENCY_RATE)
    if not v_new and st_lines(o.trns_type_code, o.trns_serial) > 0
       and (chg(v_date, o.trns_date) = 1 or chg(v_curr, o.currency_code) = 1 or chg(v_rate, o.currency_rate) = 1
            or chg(v_store, o.store_code) = 1) then
      return 'لا يمكن تعديل تاريخ الحركة أو العملة أو معامل التحويل أو المخزن بعد إدخال الأصناف';
    end if;
    -- supplier (SUPPLIER_RG: active suppliers)
    if v_supp is not null and (v_new or chg(v_supp, o.supplier_code) = 1) then
      select count(*) into v from supplier where code = v_supp and nvl(supplier_status, 0) = 1
         and (p_form = 'RECEIVE' or nvl(stopflag, 0) = 0);
      if v = 0 then return 'المورد ' || v_supp || ' غير موجود أو غير فعال أو متوقف'; end if;
    end if;
    if p_form = 'RECEIVE' and v_due is not null and v_due < v_date then
      return 'لايمكن ان يكون تاريخ الأستحقاق أقل من تاريخ الحركة';
    end if;
    -- document number (CHECK_DOC_NO, ST_BASIC.DOC_REPEAT = 2 forbids repeats)
    if v_doc is not null then
      select max(nvl(doc_repeat, 0)) into v_rep from st_basic;
      if v_rep = 2 then
        select count(*) into v from st_trns_mast
         where trns_type_code = v_type and doc_no = v_doc and nvl(delete_flag, 0) = 0
           and (p_rowid is null or rowid <> chartorowid(p_rowid));
        if v > 0 then return 'لا يمكن تكرار المستند'; end if;
      end if;
    end if;
    -- returns
    if p_form = 'RETURN' then
      if v_rt is null or v_rs is null then return 'يجب إدخال رقم ونوع فاتورة المشتريات المرتجع منها'; end if;
      begin
        select * into inv from st_trns_mast where trns_type_code = v_rt and trns_serial = v_rs;
      exception when no_data_found then return 'فاتورة المشتريات ' || v_rt || '/' || v_rs || ' غير موجودة';
      end;
      if is_receive_type(v_rt) = 0 or nvl(inv.delete_flag, 0) <> 0 then return 'فاتورة المشتريات ' || v_rt || '/' || v_rs || ' غير صالحة للارتجاع'; end if;
      if inv.store_code <> v_store then return 'فاتورة المشتريات من مخزن آخر'; end if;
      if inv.trns_date > v_date then return 'تاريخ فاتورة المشتريات بعد تاريخ المرتجع'; end if;
      if v_supp is not null and inv.supplier_code is not null and inv.supplier_code <> v_supp then
        return 'مورد المرتجع يختلف عن مورد فاتورة المشتريات';
      end if;
      if not v_new and st_lines(o.trns_type_code, o.trns_serial) > 0
         and (chg(v_rt, o.ret_trns_type_code) = 1 or chg(v_rs, o.ret_trns_serial) = 1) then
        return 'لا يمكن تغيير فاتورة المشتريات بعد إدخال الأصناف';
      end if;
    elsif p_form = 'RETURN2' and (v_rt is not null or v_rs is not null) then
      return 'مرتجع بدون فاتورة: لا يتم إدخال رقم فاتورة المشتريات';
    end if;
    return null;
  end;

  -- ENABLE_DISABLE_UPDATE / CLOSE_POSTED / CLOSE_ACC: posted (GL / AP / AR), cancelled or closed-period documents are read-only
  function check_st_locked(p_rowid varchar2) return varchar2 is
    o st_trns_mast%rowtype := st_row(p_rowid);
    v_close date;
  begin
    if p_rowid is null or o.trns_type_code is null then return null; end if;
    if nvl(o.post_flag, 0) = 1 or nvl(o.supp_post_flag, 0) = 1 or nvl(o.cust_post_flag, 0) = 1 then
      return 'لا يمكن تعديل هذه الحركة لأنها مرحلة';
    end if;
    if nvl(o.delete_flag, 0) = 1 then return 'لا يمكن تعديل حركة ملغاة'; end if;
    v_close := close_date;
    if v_close is not null and o.trns_date <= v_close then return 'لا يمكن تعديل حركة في فترة مقفلة'; end if;
    return null;
  end;

  function check_order_header(p_rowid varchar2, p_type varchar2, p_date varchar2, p_store varchar2,
                              p_supplier varchar2, p_currency varchar2, p_rate varchar2) return varchar2 is
    v_type number := n(p_type); v_store number := n(p_store); v_supp number := n(p_supplier);
    v_curr number := nvl(n(p_currency), 1); v_rate number := n(p_rate);
    o pr_order%rowtype; v number;
  begin
    if p_rowid is not null then
      begin select * into o from pr_order where rowid = chartorowid(p_rowid); exception when no_data_found then null; end;
    end if;
    if v_type is null or is_order_type(v_type) = 0 then return 'نوع أمر الشراء غير صحيح'; end if;
    if p_rowid is null and not type_allowed(v_type) then return 'لا توجد صلاحية على نوع الحركة ' || v_type; end if;
    if p_rowid is not null and chg(v_type, o.trns_type_code) = 1 then return 'لا يمكن تغيير نوع الحركة بعد الحفظ'; end if;
    if v_store is null then return 'يجب ربط الحركة بالمخزن'; end if;
    if nvl(v_rate, 0) <= 0 then return 'يجب ادخال معامل التحويل'; end if;
    if v_curr = 1 and v_rate <> 1 then return 'العملة هى العملة المحلية، معامل التحويل يساوي 1'; end if;
    if v_supp is not null and (p_rowid is null or chg(v_supp, o.supplier_code) = 1) then
      select count(*) into v from supplier where code = v_supp;
      if v = 0 then return 'المورد غير موجود'; end if;
      if p_rowid is not null then
        select count(*) into v from pr_order_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
        if v > 0 then return 'لا يمكن تغيير المورد بعد إدخال الأصناف'; end if;
      end if;
    end if;
    return null;
  end;

  -- CHECK_CLOSE: confirmed or closed orders are read-only; only the confirm / close flags may be switched off
  function check_order_locked(p_rowid varchar2, p_confirm varchar2, p_close varchar2) return varchar2 is
    o pr_order%rowtype;
  begin
    if p_rowid is null then return null; end if;
    begin select * into o from pr_order where rowid = chartorowid(p_rowid); exception when no_data_found then return null; end;
    if (nvl(o.confirm_flag, 0) = 1 or nvl(o.close_flag, 0) = 1)
       and nvl(n(p_confirm), 0) = nvl(o.confirm_flag, 0) and nvl(n(p_close), 0) = nvl(o.close_flag, 0) then
      return 'أمر الشراء معتمد أو مقفل ولا يمكن تعديله - يجب إلغاء الاعتماد أو الإقفال أولاً';
    end if;
    return null;
  end;

  function check_lot_header(p_rowid varchar2, p_type varchar2, p_flag varchar2, p_arrival varchar2, p_store varchar2,
                            p_supplier varchar2, p_currency varchar2, p_rate varchar2,
                            p_order_type varchar2, p_order_serial varchar2) return varchar2 is
    v_type number := n(p_type); v_flag number := nvl(n(p_flag), 1); v_arr date := d(p_arrival);
    v_store number := n(p_store); v_supp number := n(p_supplier); v_curr number := nvl(n(p_currency), 1);
    v_rate number := n(p_rate); v_ot number := n(p_order_type); v_os number := n(p_order_serial);
    o pr_income_lot%rowtype; po pr_order%rowtype; v number; v_pu number;
  begin
    if p_rowid is not null then
      begin select * into o from pr_income_lot where rowid = chartorowid(p_rowid); exception when no_data_found then null; end;
    end if;
    if v_type is null or is_lot_type(v_type) = 0 then return 'نوع الرسالة الواردة غير صحيح'; end if;
    if p_rowid is null and not type_allowed(v_type) then return 'لا توجد صلاحية على نوع الحركة ' || v_type; end if;
    if p_rowid is not null and chg(v_type, o.trns_type_code) = 1 then return 'لا يمكن تغيير نوع الحركة بعد الحفظ'; end if;
    if v_flag not in (1, 2, 3) then return 'نوع الرسالة (أصناف / خدمات) غير صحيح'; end if;
    select max(pu_trns_type) into v_pu from st_trns_type where trns_type_code = v_type;
    if v_pu is null then return 'يجب التاكد من ربط الحركة مع حركة مشتريات'; end if;
    if v_arr is null then return 'يجب إدخال تاريخ الوصول الفعلى'; end if;
    if trunc(v_arr) > trunc(sysdate) then return 'لا بد ان يكون تاريخ وصول الرسالة أصغر من او يساوي تاريخ اليوم'; end if;
    if v_store is null then return '!رقم المخزن غير موجود بالرسالة'; end if;
    if v_curr = 1 and nvl(v_rate, 1) <> 1 then return 'العملة هى العملة المحلية، معامل التحويل يساوي 1'; end if;
    if nvl(v_rate, 1) <= 0 or v_rate > 99999999.99 then return 'معامل التحويل لا بد أن يكون أكبر من الصفر و اقل من 99999999.99'; end if;
    if p_rowid is not null and chg(v_supp, o.supplier_code) = 1 then
      select count(*) into v from pr_income_lot_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
      if v > 0 then return 'لا يمكن تغيير المورد بعد إدخال الأصناف'; end if;
    end if;
    -- purchase order (PR_ORDER_MAST_RG): confirmed, not closed, same supplier, not used by another lot, still outstanding
    if v_ot is not null or v_os is not null then
      if v_ot is null or v_os is null then return 'يجب إدخال نوع ورقم أمر الشراء'; end if;
      if p_rowid is null or chg(v_ot, o.order_trns_type_code) = 1 or chg(v_os, o.order_trns_serial) = 1 then
        begin
          select * into po from pr_order where trns_type_code = v_ot and trns_serial = v_os;
        exception when no_data_found then return 'أمر الشراء ' || v_ot || '/' || v_os || ' غير موجود';
        end;
        if nvl(po.confirm_flag, 0) <> 1 then return 'أمر الشراء غير معتمد'; end if;
        if nvl(po.close_flag, 0) = 1 then return 'أمر الشراء مقفل'; end if;
        if v_supp is not null and po.supplier_code <> v_supp then return 'مورد أمر الشراء يختلف عن مورد الرسالة'; end if;
        if po.pr_order_date - 1 > v_arr then return 'تاريخ أمر الشراء بعد تاريخ وصول الرسالة'; end if;
        select count(*) into v from pr_income_lot
         where order_trns_type_code = v_ot and order_trns_serial = v_os
           and (p_rowid is null or rowid <> chartorowid(p_rowid));
        if v > 0 then return 'أمر الشراء مرتبط برسالة واردة أخرى'; end if;
        if nvl(get_pr_order_status(v_ot, v_os, nvl(po.st_srv_asst_flag, 1)), 0) <= 0 then
          return 'لا توجد كميات متبقية للاستلام على أمر الشراء';
        end if;
      end if;
    end if;
    return null;
  end;

  -- WHEN-NEW-RECORD-INSTANCE: lots transferred to the stores (POST_FLAG / PU_TRNS_*) are read-only
  function check_lot_locked(p_rowid varchar2) return varchar2 is
    o pr_income_lot%rowtype;
  begin
    if p_rowid is null then return null; end if;
    begin select * into o from pr_income_lot where rowid = chartorowid(p_rowid); exception when no_data_found then return null; end;
    if nvl(o.post_flag, 0) = 1 or (o.pu_trns_type_code is not null and o.pu_trns_serial is not null) then
      return 'الحركة الحالية تم إستلامها فى المخازن و لا يمكن تعديلها';
    end if;
    return null;
  end;

  -- ================================================================ row-rule checks
  -- AUTH / NOT_AUTH buttons: confirming needs saved lines with quantity and price; un-confirming is refused
  -- once an incoming lot refers to the order
  procedure order_update_check(p_type number, p_serial number, p_old_confirm number, p_new_confirm number) is
    v number;
  begin
    if nvl(p_old_confirm, 0) = 0 and nvl(p_new_confirm, 0) = 1 then
      select count(*) into v from pr_order_det where trns_type_code = p_type and trns_serial = p_serial;
      if v = 0 then
        select count(*) into v from pr_order_srvc where trns_type_code = p_type and trns_serial = p_serial;
      end if;
      if v = 0 then
        select count(*) into v from pr_order_asst where trns_type_code = p_type and trns_serial = p_serial;
      end if;
      if v = 0 then raise_application_error(-20132, 'يجب إدخال أصناف قبل اعتماد أمر الشراء'); end if;
      select count(*) into v from pr_order_det
       where trns_type_code = p_type and trns_serial = p_serial
         and (nvl(quantity, 0) + nvl(bonus, 0) + nvl(extra_bonus, 0) <= 0 or nvl(vn_price, 0) <= 0);
      if v = 0 then
        select count(*) into v from pr_order_srvc
         where trns_type_code = p_type and trns_serial = p_serial and (nvl(quantity, 0) <= 0 or nvl(unit_cost, 0) <= 0);
      end if;
      if v = 0 then
        select count(*) into v from pr_order_asst where trns_type_code = p_type and trns_serial = p_serial and nvl(quantity, 0) <= 0;
      end if;
      if v > 0 then raise_application_error(-20132, 'بعض الاصناف ليس لها كمية أو سعر'); end if;
    elsif nvl(p_old_confirm, 0) = 1 and nvl(p_new_confirm, 0) = 0 then
      select count(*) into v from pr_income_lot where order_trns_type_code = p_type and order_trns_serial = p_serial;
      if v > 0 then raise_application_error(-20133, 'لا يمكن الغاء الاعتماد لوجود رسائل واردة على أمر الشراء'); end if;
    end if;
  end;

  procedure order_line_guard(p_type number, p_serial number) is
    v_conf number; v_close number;
  begin
    select max(nvl(confirm_flag, 0)), max(nvl(close_flag, 0)) into v_conf, v_close
      from pr_order where trns_type_code = p_type and trns_serial = p_serial;
    if v_conf = 1 or v_close = 1 then
      raise_application_error(-20143, 'أمر الشراء معتمد أو مقفل ولا يمكن تعديل أصنافه');
    end if;
  exception when e_mutating then null;
  end;

  procedure lot_line_guard(p_type number, p_serial number) is
    v number;
  begin
    select count(*) into v from pr_income_lot
     where trns_type_code = p_type and trns_serial = p_serial
       and (nvl(post_flag, 0) = 1 or (pu_trns_type_code is not null and pu_trns_serial is not null));
    if v > 0 then
      raise_application_error(-20144, 'الحركة الحالية تم إستلامها فى المخازن و لا يمكن تعديل تفاصيلها');
    end if;
  exception when e_mutating then null;
  end;

  -- ================================================================ stock balance
  -- legacy KEY-DELREC / GET_MIN_BALANCE_CONFG_AFTER: the running balance of each lot configuration in the store
  -- may not become negative from this document onwards (EFFECT 1,4,6 in / 2,3,5 out)
  procedure check_stock_cfg(p_store number, p_group number, p_item varchar2, p_confg number, p_date date, p_date_serial number) is
    v_min number;
  begin
    select min(bal) into v_min from (
      select d.trns_date, d.date_serial,
             sum(decode(t.effect, 1, 1, 2, -1, 3, -1, 4, 1, 5, -1, 6, 1, 0) * nvl(d.basic_qty, 0))
               over (order by d.trns_date, d.date_serial, d.trns_type_code, d.trns_serial, d.item_serial rows unbounded preceding) bal
        from st_trns_det d, st_trns_type t
       where t.trns_type_code = d.trns_type_code
         and d.store_code = p_store and d.group_code = p_group and d.item_code = p_item and d.item_confg_id = p_confg
         and nvl(d.delete_flag, 0) = 0)
     where trns_date > p_date or (trns_date = p_date and nvl(date_serial, 0) >= nvl(p_date_serial, 0));
    if v_min < -0.0001 then
      raise_application_error(-20130, 'الرصيد لا يسمح، توجد حركة تالية لهذه الحركة تتعارض معها - الصنف ' || p_item
                                      || ' الشحنة ' || p_confg || ' الرصيد ' || round(v_min, 3));
    end if;
  end;

  procedure check_stock(p_type number, p_serial number) is
  begin
    for r in (select distinct store_code, group_code, item_code, item_confg_id, trns_date, date_serial
                from st_trns_det where trns_type_code = p_type and trns_serial = p_serial and nvl(delete_flag, 0) = 0) loop
      check_stock_cfg(r.store_code, r.group_code, r.item_code, r.item_confg_id, r.trns_date, r.date_serial);
    end loop;
  end;

  -- ================================================================ purchase invoice (ST_RECEIVE_COST)
  -- CALC_UNIT_COST + GET_NDB_* (master expenses spread over the lines by value) + UPDATE_COST (average per item and price)
  procedure recalc_receive_costs(m st_trns_mast%rowtype) is
    v_rate  number := nvl(m.currency_rate, 1);
    v_total number;
    v_line  number; v_line_curr number; v_share number; v_cost number;
    f number; c number; t number; cm number; i number; o number; sf number; si number; so number; ds number;
  begin
    select sum((nvl(quantity, 0) * (nvl(unit_price_curr, 0) - nvl(disc1_value, 0) - nvl(disc2_value, 0) - nvl(disc3_value, 0)
                - nvl(supp_disc_value, 0))) * v_rate - nvl(det_disc, 0))
      into v_total
      from st_trns_det where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial;
    for l in (select rowid rid, d.* from st_trns_det d where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial) loop
      v_line_curr := nvl(l.quantity, 0) * (nvl(l.unit_price_curr, 0) - nvl(l.disc1_value, 0) - nvl(l.disc2_value, 0)
                     - nvl(l.disc3_value, 0) - nvl(l.supp_disc_value, 0)) - nvl(l.det_disc, 0) / v_rate;
      v_line := v_line_curr * v_rate;
      if nvl(v_total, 0) <> 0 and nvl(l.basic_qty, 0) <> 0 and l.quantity is not null and l.unit_price_curr is not null then
        v_share := v_line / v_total / l.basic_qty;
      else
        v_share := 0;
      end if;
      f  := nvl(m.freight_val, 0) * v_share;        c  := nvl(m.customs_val, 0) * v_share;
      t  := nvl(m.trnsport_val, 0) * v_share;       cm := nvl(m.commission_val, 0) * v_share;
      i  := nvl(m.insurance_val, 0) * v_share;      o  := nvl(m.others_val, 0) * v_share;
      sf := nvl(m.supp_freight_val, 0) * v_share;   si := nvl(m.supp_insurance_val, 0) * v_share;
      so := nvl(m.supp_others_val, 0) * v_share;    ds := nvl(m.disc_val, 0) * v_share;
      v_cost := case when nvl(l.basic_qty, 0) = 0 then v_line_curr else v_line / l.basic_qty end
                + f + c + t + cm + i + o + so + si + sf - ds;
      if chg(f, l.freight) + chg(c, l.customs) + chg(t, l.transport) + chg(cm, l.commission) + chg(i, l.insurance)
         + chg(o, l.others) + chg(sf, l.supp_freight) + chg(si, l.supp_insurance) + chg(so, l.supp_others)
         + chg(ds, l.disc) + chg(round(v_cost, 8), round(l.unit_cost, 8)) > 0 then
        update st_trns_det
           set freight = f, customs = c, transport = t, commission = cm, insurance = i, others = o,
               supp_freight = sf, supp_insurance = si, supp_others = so, disc = ds, unit_cost = v_cost
         where rowid = l.rid;
      end if;
    end loop;
    -- UPDATE_COST: one average unit cost per item and lot price inside the invoice
    for a in (select sum(d.unit_cost * d.basic_qty) tc, sum(d.basic_qty) q, d.item_code, d.group_code, c.unit_price
                from st_trns_det d, st_item_confg c
               where d.trns_type_code = m.trns_type_code and d.trns_serial = m.trns_serial and c.item_confg_id = d.item_confg_id
               group by d.item_code, d.group_code, c.unit_price) loop
      if nvl(a.q, 0) <> 0 then
        update st_trns_det d
           set unit_cost = a.tc / a.q
         where d.trns_type_code = m.trns_type_code and d.trns_serial = m.trns_serial
           and d.item_code = a.item_code and d.group_code = a.group_code
           and d.item_confg_id in (select item_confg_id from st_item_confg
                                    where item_code = a.item_code and group_code = a.group_code
                                      and (unit_price = a.unit_price or (unit_price is null and a.unit_price is null)))
           and abs(nvl(d.unit_cost, 0) - a.tc / a.q) > 0.00000001;
      end if;
    end loop;
  end;

  -- Purchase invoice / return lines (ST_RECEIVE_COST, ST_RETURN_COST, ST_RETURN_COST2), wave 3:
  --  * ST_RETURN_COST2: a line saved without price takes the lot cost of the line (UNIT_COST x unit factor, in the currency);
  --  * GET_TAX_VALUE on the changed lines (value LINE_TOTAL_RYAL = (qty x (price - DISC1..3) - line discount) x rate) and on the
  --    changed supplier-expense lines (value TOTAL_SUPP_LINE, supplier of the expense line); GET_TAX_VALUE_MAST on the header;
  --  * ST_RECEIVE_COST, invoice generated from an incoming lot (CLOSE_POSTED): lines can be changed but not added or removed.
  procedure st_lines_derive(m st_trns_mast%rowtype, p_form varchar2) is
    old st_trns_det%rowtype;
    olde st_trns_det_expens%rowtype;
    v_found boolean;
    v_hdr st_trns_mast%rowtype;
    v_hdr_found boolean := false;
    v_rate number := nvl(m.currency_rate, 0);
    v_code number; v_tax number; v_price number; v_up number; v_cost number;
    v_any boolean := false;
    v_det_tax number; v_total number; v_n number;
  begin
    begin
      select * into v_hdr from st_trns_mast as of timestamp systimestamp
       where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial;
      v_hdr_found := true;
    exception when others then v_hdr_found := false;
    end;
    if p_form = 'RECEIVE' and m.income_trns_type_code is not null and v_hdr_found then
      select count(*) into v_n from (
        (select item_serial from st_trns_det where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial
         minus
         select item_serial from st_trns_det as of timestamp systimestamp where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial)
        union all
        (select item_serial from st_trns_det as of timestamp systimestamp where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial
         minus
         select item_serial from st_trns_det where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial));
      if v_n > 0 then
        raise_application_error(-20147, 'فاتورة مولدة من رسالة واردة: لا يمكن إضافة أو حذف أصناف');
      end if;
    end if;
    for l in (select rowid rid, d.* from st_trns_det d where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial) loop
      begin
        select * into old from st_trns_det as of timestamp systimestamp
         where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial and item_serial = l.item_serial;
        v_found := true;
      exception when others then v_found := false;
      end;
      v_price := l.unit_price_curr;
      if p_form = 'RETURN2' and l.unit_price_curr is null then
        -- cost of the line: UNIT_COST when given, else the average cost of the lot configuration that ST_TRNS_DET_C_IN
        -- recorded for this line in ST_TRNS_DET_COST
        select coalesce(l.unit_cost, max(c.unit_cost)) into v_cost from st_trns_det_cost c
         where c.trns_type_code = l.trns_type_code and c.trns_serial = l.trns_serial and c.item_serial = l.item_serial;
        if v_cost is not null then
          v_price := round(v_cost * unit_factor(l.group_code, l.item_code, l.unit_code) / nvl(nullif(m.currency_rate, 0), 1), 2);
        end if;
      end if;
      v_code := l.tax_code1; v_tax := l.tax_value1;
      if not v_found or chg(v_price, l.unit_price_curr) = 1
         or chg(l.item_code, old.item_code) + chg(l.quantity, old.quantity) + chg(l.bonus, old.bonus) + chg(l.extra_bonus, old.extra_bonus)
          + chg(l.unit_price_curr, old.unit_price_curr) + chg(l.disc1_value, old.disc1_value) + chg(l.disc2_value, old.disc2_value)
          + chg(l.disc3_value, old.disc3_value) + chg(l.supp_disc_value, old.supp_disc_value) + chg(l.det_disc, old.det_disc) > 0 then
        v_any := true;
        line_tax(l.group_code, l.item_code, m.supplier_code, m.trns_date,
                 ((nvl(l.quantity, 0) * (nvl(v_price, 0) - (nvl(l.disc1_value, 0) + nvl(l.disc2_value, 0) + nvl(l.disc3_value, 0))))
                  - nvl(l.det_disc, 0) / nvl(nullif(m.currency_rate, 0), 1)) * v_rate,
                 v_code, v_tax);
      end if;
      if chg(v_code, l.tax_code1) + chg(v_tax, l.tax_value1) + chg(v_price, l.unit_price_curr) > 0 then
        v_up := case when chg(v_price, l.unit_price_curr) = 1 then v_price * nvl(m.currency_rate, 1) else l.unit_price end;
        g_bypass := true;
        update st_trns_det
           set tax_code1 = v_code, tax_value1 = v_tax, unit_price_curr = v_price, unit_price = v_up
         where rowid = l.rid;
        g_bypass := false;
      end if;
    end loop;
    if p_form = 'RECEIVE' then
      for e in (select rowid rid, x.* from st_trns_det_expens x where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial) loop
        begin
          select * into olde from st_trns_det_expens as of timestamp systimestamp
           where trns_type_code = e.trns_type_code and trns_serial = e.trns_serial and expens_serial = e.expens_serial;
          v_found := true;
        exception when others then v_found := false;
        end;
        if not v_found or chg(e.supplier_code, olde.supplier_code) + chg(e.freight_val, olde.freight_val) + chg(e.customs_val, olde.customs_val)
           + chg(e.trnsport_val, olde.trnsport_val) + chg(e.insurance_val, olde.insurance_val) + chg(e.commission_val, olde.commission_val)
           + chg(e.others_val, olde.others_val) > 0 then
          v_code := e.tax_code1; v_tax := e.tax_value1;
          line_tax(null, null, e.supplier_code, m.trns_date,
                   nvl(e.customs_val, 0) + nvl(e.freight_val, 0) + nvl(e.insurance_val, 0) + nvl(e.trnsport_val, 0)
                   + nvl(e.commission_val, 0) + nvl(e.others_val, 0), v_code, v_tax);
          if chg(v_code, e.tax_code1) + chg(v_tax, e.tax_value1) > 0 then
            g_bypass := true;
            update st_trns_det_expens set tax_code1 = v_code, tax_value1 = v_tax where rowid = e.rid;
            g_bypass := false;
          end if;
        end if;
      end loop;
    end if;
    if v_any or not v_hdr_found
       or chg(m.disc_val, v_hdr.disc_val) + chg(m.trnsport_val, v_hdr.trnsport_val) + chg(m.tot_disc1_value, v_hdr.tot_disc1_value)
        + chg(m.tot_disc2_value, v_hdr.tot_disc2_value) + chg(m.tot_disc3_value, v_hdr.tot_disc3_value) > 0 then
      select nvl(sum(tax_value1), 0),
             sum(((nvl(quantity, 0) * (nvl(unit_price_curr, 0) - (nvl(disc1_value, 0) + nvl(disc2_value, 0) + nvl(disc3_value, 0))))
                  - nvl(det_disc, 0) / nvl(nullif(m.currency_rate, 0), 1)) * v_rate)
        into v_det_tax, v_total
        from st_trns_det where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial;
      select v_det_tax + nvl(sum(tax_value1), 0) into v_det_tax
        from st_trns_services where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial;
      v_code := m.tax_code1; v_tax := m.tax_value1;
      mast_tax(m.supplier_code, m.trns_date, v_total, m.disc_val, v_det_tax, m.trnsport_val, v_code, v_tax);
      if chg(v_code, m.tax_code1) + chg(v_tax, m.tax_value1) > 0 then
        g_bypass := true;
        update st_trns_mast set tax_code1 = v_code, tax_value1 = v_tax
         where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial;
        g_bypass := false;
      end if;
    end if;
  exception when others then
    g_bypass := false;
    raise;
  end;

  procedure check_max_items(p_type number, p_serial number) is
    v number; v_max number;
  begin
    select max(trns_max_items) into v_max from st_basic;
    if v_max is null then return; end if;
    select count(*) into v from st_trns_det where trns_type_code = p_type and trns_serial = p_serial;
    if v > v_max then
      raise_application_error(-20125, 'لقد تم إدخال ' || v || ' صنف فى هذه الحركة، غير مسموح بأكثر من ' || v_max || ' صنف');
    end if;
  end;

  procedure receive_after_save(p_rowid varchar2, p_request varchar2) is
    m st_trns_mast%rowtype;
    v_rate number; v_items number; v_supp_total number; v_due_sum number; v_cnt number; v_first number;
    e_fr number; e_cu number; e_tr number; e_in number; e_co number; e_ot number;
  begin
    if p_rowid is null then return; end if;
    begin
      select * into m from st_trns_mast where rowid = chartorowid(p_rowid);
    exception when no_data_found then return;
    end;
    if is_receive_type(m.trns_type_code) = 0 then return; end if;
    st_lines_derive(m, 'RECEIVE');
    select * into m from st_trns_mast where rowid = chartorowid(p_rowid);
    v_rate := nvl(m.currency_rate, 1);
    v_cnt := st_lines(m.trns_type_code, m.trns_serial);
    -- PRE-INSERT: "لا يمكن حفظ الفاتورة بدون أصناف" (lines are entered after the header is created)
    if p_request = 'SAVE' and v_cnt = 0 then
      raise_application_error(-20124, 'لا يمكن حفظ الفاتورة بدون أصناف');
    end if;
    check_max_items(m.trns_type_code, m.trns_serial);
    -- KEY-COMMIT: unit costs of all lines, then UPDATE_COST
    recalc_receive_costs(m);
    -- CHECK_DET_EXP: supplier expense lines may not exceed the invoice expenses
    select nvl(sum(freight_val), 0), nvl(sum(customs_val), 0), nvl(sum(trnsport_val), 0), nvl(sum(insurance_val), 0),
           nvl(sum(commission_val), 0), nvl(sum(others_val), 0)
      into e_fr, e_cu, e_tr, e_in, e_co, e_ot
      from st_trns_det_expens where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial;
    if e_fr + e_cu + e_tr + e_in + e_co + e_ot <> 0
       and (e_fr > nvl(m.freight_val, 0) or e_cu > nvl(m.customs_val, 0) or e_tr > nvl(m.trnsport_val, 0)
            or e_in > nvl(m.insurance_val, 0) or e_co > nvl(m.commission_val, 0) or e_ot > nvl(m.others_val, 0)) then
      raise_application_error(-20126, 'يجب ان يتساوى مصاريف الموردين مع اجمالي تكاليف الاخرى للحركة');
    end if;
    -- supplier total in currency (SUPP_TOTAL_AFTER): items after line discounts - invoice discounts + VAT + supplier expenses
    select nvl(sum(nvl(quantity, 0) * (nvl(unit_price_curr, 0) - nvl(disc1_value, 0) - nvl(disc2_value, 0) - nvl(disc3_value, 0)
                   - nvl(supp_disc_value, 0)) - nvl(det_disc, 0) / v_rate), 0),
           nvl(sum(nvl(tax_value1, 0)), 0) / v_rate
      into v_items, v_supp_total
      from st_trns_det where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial;
    if v_items - nvl(m.tot_disc1_value, 0) - nvl(m.tot_disc2_value, 0) - nvl(m.tot_disc3_value, 0) < 0 then
      raise_application_error(-20145, 'قيم الاصناف أقل من صفر');
    end if;
    v_supp_total := v_items - nvl(m.tot_disc1_value, 0) - nvl(m.tot_disc2_value, 0) - nvl(m.tot_disc3_value, 0)
                    + v_supp_total + nvl(m.tax_value1, 0) / v_rate - nvl(m.disc_val, 0) / v_rate
                    + (nvl(m.supp_freight_val, 0) + nvl(m.supp_insurance_val, 0) + nvl(m.supp_others_val, 0)) / v_rate;
    if (nvl(m.payment, 0) + nvl(m.atm_ammount, 0)) / v_rate > v_supp_total + 0.0001 then
      raise_application_error(-20129, 'يجب ان تكون القيمه المدفوعه اصغر من القيمة الكليه');
    end if;
    -- KEY-COMMIT: the due-date instalments (ST_TRNS_DET_DUES) always add up to the supplier total
    select nvl(sum(amount_curr), 0), count(*), min(due_serial) into v_due_sum, v_cnt, v_first
      from st_trns_det_dues where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial;
    if round(v_due_sum, 4) <> round(v_supp_total - nvl(m.payment, 0) / v_rate, 4) then
      if v_cnt = 0 then
        insert into st_trns_det_dues (trns_type_code, trns_serial, due_serial, supp_due_date, posting_supp_due_date,
                                      amount_curr, amount, payed_flag)
        values (m.trns_type_code, m.trns_serial, 1, m.trns_date, m.trns_date,
                v_supp_total - nvl(m.payment, 0) / v_rate, (v_supp_total - nvl(m.payment, 0) / v_rate) * v_rate, 0);
      else
        update st_trns_det_dues
           set amount_curr = nvl(amount_curr, 0) + (v_supp_total - nvl(m.payment, 0) / v_rate - v_due_sum),
               amount      = (nvl(amount_curr, 0) + (v_supp_total - nvl(m.payment, 0) / v_rate - v_due_sum)) * v_rate
         where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial and due_serial = v_first;
      end if;
    end if;
    select count(*) into v_cnt from st_trns_det_dues
     where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial and nvl(amount_curr, 0) < 0;
    if v_cnt > 0 then raise_application_error(-20128, 'اجمالى قيمة الاقساط في شاشة تواريخ الإستحقاق لا تساوى القيمة الكلية للمورد بالعملة'); end if;
    select count(*) into v_cnt from st_trns_det_dues
     where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial and supp_due_date < m.trns_date;
    if v_cnt > 0 then raise_application_error(-20127, 'تاريخ الإستحقاق يجب أن يكون أكبر من أو يساوي تاريخ الفاتورة'); end if;
    check_stock(m.trns_type_code, m.trns_serial);
  end;

  -- ================================================================ purchase returns (ST_RETURN_COST / ST_RETURN_COST2)
  procedure return_after_save(p_rowid varchar2, p_request varchar2, p_form varchar2) is
    m st_trns_mast%rowtype; inv st_trns_mast%rowtype;
    v_cnt number; v_q number; v_b number; v_iq number; v_ib number;
    procedure exp_check(p_ret number, p_inv number, p_msg varchar2) is
    begin
      if nvl(p_ret, 0) > nvl(p_inv, 0) + 0.0001 then raise_application_error(-20138, p_msg); end if;
    end;
  begin
    if p_rowid is null then return; end if;
    begin
      select * into m from st_trns_mast where rowid = chartorowid(p_rowid);
    exception when no_data_found then return;
    end;
    if is_return_type(m.trns_type_code) = 0 then return; end if;
    v_cnt := st_lines(m.trns_type_code, m.trns_serial);
    if p_request = 'SAVE' and v_cnt = 0 then
      raise_application_error(-20124, 'لا يمكن الحفظ بدون تفاصيل');
    end if;
    check_max_items(m.trns_type_code, m.trns_serial);
    for l in (select rowid rid, d.* from st_trns_det d where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial) loop
      select count(*) into v_cnt from st_item_confg where item_confg_id = l.item_confg_id and item_code = l.item_code and group_code = l.group_code;
      if v_cnt = 0 then raise_application_error(-20137, 'الشحنة ' || l.item_confg_id || ' لا تخص الصنف ' || l.item_code); end if;
    end loop;
    if p_form = 'RETURN' and m.ret_trns_type_code is not null then
      select * into inv from st_trns_mast where trns_type_code = m.ret_trns_type_code and trns_serial = m.ret_trns_serial;
      for l in (select rowid rid, d.* from st_trns_det d where trns_type_code = m.trns_type_code and trns_serial = m.trns_serial) loop
        -- the returned lot must be on the purchase invoice; prices and discounts come from the invoice line (RETURN LOV)
        select count(*) into v_cnt from st_trns_det
         where trns_type_code = inv.trns_type_code and trns_serial = inv.trns_serial
           and group_code = l.group_code and item_code = l.item_code and item_confg_id = l.item_confg_id;
        if v_cnt = 0 then
          raise_application_error(-20137, 'الصنف ' || l.item_code || ' (الشحنة ' || l.item_confg_id || ') غير موجود في فاتورة المشتريات ' || inv.trns_type_code || '/' || inv.trns_serial);
        end if;
        if l.unit_price_curr is null then
          update st_trns_det d
             set (unit_price_curr, unit_price, disc1_ratio, disc1_value, disc2_ratio, disc2_value, disc3_ratio, disc3_value) =
                 (select o.unit_price_curr, o.unit_price, o.disc1_ratio, o.disc1_value, o.disc2_ratio, o.disc2_value, o.disc3_ratio, o.disc3_value
                    from st_trns_det o
                   where o.trns_type_code = inv.trns_type_code and o.trns_serial = inv.trns_serial
                     and o.group_code = l.group_code and o.item_code = l.item_code and o.item_confg_id = l.item_confg_id
                     and rownum = 1)
           where rowid = l.rid;
        end if;
      end loop;
      st_lines_derive(m, 'RETURN');
      -- returned quantities of all returns of the invoice <= purchased quantities (message of the legacy form)
      for k in (select d.group_code, d.item_code, d.item_confg_id from st_trns_det d
                 where d.trns_type_code = m.trns_type_code and d.trns_serial = m.trns_serial
                 group by d.group_code, d.item_code, d.item_confg_id) loop
        select nvl(sum(nvl(d.quantity, 0)), 0), nvl(sum(nvl(d.bonus, 0) + nvl(d.extra_bonus, 0)), 0) into v_q, v_b
          from st_trns_mast r, st_trns_det d
         where r.trns_type_code = d.trns_type_code and r.trns_serial = d.trns_serial
           and r.ret_trns_type_code = inv.trns_type_code and r.ret_trns_serial = inv.trns_serial
           and nvl(r.delete_flag, 0) = 0 and nvl(d.delete_flag, 0) = 0
           and d.group_code = k.group_code and d.item_code = k.item_code and d.item_confg_id = k.item_confg_id;
        select nvl(sum(nvl(quantity, 0)), 0), nvl(sum(nvl(bonus, 0) + nvl(extra_bonus, 0)), 0) into v_iq, v_ib
          from st_trns_det
         where trns_type_code = inv.trns_type_code and trns_serial = inv.trns_serial
           and group_code = k.group_code and item_code = k.item_code and item_confg_id = k.item_confg_id;
        if v_q > v_iq or v_b > v_ib then
          raise_application_error(-20136, 'إجمالى الكمية المرتجعة اكبر من اجمالى الكمية المشتراه - الكمية = '
                                          || v_iq || ' / المجاني = ' || v_ib || ' - الصنف ' || k.item_code);
        end if;
      end loop;
      -- expenses of all returns of the invoice <= invoice expenses (messages of the legacy form)
      for s in (select sum(nvl(freight_val, 0)) fr, sum(nvl(customs_val, 0)) cu, sum(nvl(trnsport_val, 0)) tr,
                       sum(nvl(commission_val, 0)) co, sum(nvl(insurance_val, 0)) ins, sum(nvl(others_val, 0)) ot,
                       sum(nvl(supp_freight_val, 0)) sfr, sum(nvl(supp_insurance_val, 0)) sin, sum(nvl(supp_others_val, 0)) sot,
                       sum(nvl(disc_val, 0)) dv
                  from st_trns_mast
                 where ret_trns_type_code = inv.trns_type_code and ret_trns_serial = inv.trns_serial and nvl(delete_flag, 0) = 0) loop
        exp_check(s.fr,  inv.freight_val,        'قيمة مصاريف الشحن أكبر من قيمة مصاريف شحن فاتورة المشتريات!!!');
        exp_check(s.cu,  inv.customs_val,        'قيمة مصاريف الجمارك أكبر من قيمة مصاريف الجمارك فاتورة المشتريات!!!');
        exp_check(s.tr,  inv.trnsport_val,       'قيمة مصاريف النقل أكبر من قيمة مصاريف النقل  فاتورة المشتريات!!!');
        exp_check(s.co,  inv.commission_val,     'قيمة العمولات أكبر من قيمة العمولات فاتورة المشتريات!!!');
        exp_check(s.ins, inv.insurance_val,      'قيمة التأمين أكبر من قيمة التأمين في فاتورة المشتريات!!!');
        exp_check(s.ot,  inv.others_val,         'قيمة المصاريف الأخري أكبر من قيمة المصاريف الأخري في فاتورة المشتريات!!!');
        exp_check(s.sfr, inv.supp_freight_val,   'قيمة مصاريف شحن المورد أكبر من قيمة مصاريف شحن المورد في فاتورة المشتريات!!!');
        exp_check(s.sin, inv.supp_insurance_val, 'قيمة مصاريف تمويل المورد أكبر من قيمة مصاريف تمويل المورد في فاتورة المشتريات!!!');
        exp_check(s.sot, inv.supp_others_val,    'قيمة مصاريف أخري للمورد أكبر من قيمة مصاريف أخري للمورد في فاتورة المشتريات!!!');
        exp_check(s.dv,  inv.disc_val,           'قيمة الخصم أكبر من قيمة خصم فاتورة المشتريات!!!');
      end loop;
    elsif p_form = 'RETURN2' or m.ret_trns_type_code is null then
      st_lines_derive(m, 'RETURN2');
    else
      st_lines_derive(m, 'RETURN');
    end if;
    check_stock(m.trns_type_code, m.trns_serial);
  end;

  -- DELETE button (validations are skipped, no DELETE row trigger): the committed row decides; legacy KEY-DELREC removed
  -- the lines (cost reversal by ST_TRNS_DET_C_DL) and released the incoming lot of a lot-generated invoice
  procedure st_after_delete(p_rowid varchar2, p_form varchar2, p_type varchar2 default null, p_serial varchar2 default null) is
    o st_trns_mast%rowtype;
    v_close date;
    type t_cfg is record (store number, grp number, item varchar2(100), confg number, dt date, ds number);
    type t_cfgs is table of t_cfg;
    cfgs t_cfgs;
  begin
    if p_rowid is null then return; end if;
    begin
      -- committed row (flashback query: the page's own uncommitted DELETE is not visible there)
      select * into o from st_trns_mast as of timestamp systimestamp where rowid = chartorowid(p_rowid);
    exception when others then
      o.trns_type_code := n(p_type); o.trns_serial := n(p_serial);   -- not readable (e.g. created seconds ago): page values
    end;
    if o.trns_type_code is null or o.trns_serial is null or is_purchase_type(o.trns_type_code) = 0 then return; end if;
    if nvl(o.post_flag, 0) = 1 or nvl(o.supp_post_flag, 0) = 1 or nvl(o.cust_post_flag, 0) = 1 then
      raise_application_error(-20134, 'لا يمكن حذف حركات مرحلة');
    end if;
    v_close := close_date;
    if v_close is not null and o.trns_date <= v_close then
      raise_application_error(-20134, 'لا يمكن حذف حركة في فترة مقفلة');
    end if;
    select store_code, group_code, item_code, item_confg_id, trns_date, date_serial bulk collect into cfgs
      from (select distinct store_code, group_code, item_code, item_confg_id, trns_date, date_serial
              from st_trns_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial);
    delete from st_trns_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    delete from st_trns_det_dues where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    delete from st_trns_det_expens where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    if o.income_trns_type_code is not null and o.income_trns_serial is not null then
      update pr_income_lot set post_flag = 0, pu_trns_type_code = null, pu_trns_serial = null
       where trns_type_code = o.income_trns_type_code and trns_serial = o.income_trns_serial;
    end if;
    for k in 1 .. cfgs.count loop
      check_stock_cfg(cfgs(k).store, cfgs(k).grp, cfgs(k).item, cfgs(k).confg, cfgs(k).dt, cfgs(k).ds);
    end loop;
  end;

  -- ================================================================ purchase orders
  -- PR_ORDER_DET PRE-INSERT DISTRIBUTE_DISC, SET_TAX_DET (line WHEN-VALIDATE-ITEM of VN_PRICE / QUANTITY / BONUS* / EXTRA_BONUS* /
  -- DISC* and BONUS_WITH_VAT WHEN-CHECKBOX-CHANGED) and SET_TAX_MAST (TOT_DISCn and line quantity / price WVI).  The legacy
  -- recalculated a line when one of those items changed: the committed row (flashback query) tells which lines changed.
  procedure order_taxes(o pr_order%rowtype) is
    old pr_order_det%rowtype;
    v_found boolean;
    v_hdr_found boolean := false;
    v_old_bwv number; v_old_t1 number; v_old_t2 number; v_old_t3 number;
    v_bwv_chg boolean;
    v_any boolean := false;
    v_code number; v_tax number; v_base number; v_disc number;
    v_tot2 number; v_net number; v_tot number;
  begin
    begin
      select nvl(bonus_with_vat, 0), tot_disc1_value, tot_disc2_value, tot_disc3_value
        into v_old_bwv, v_old_t1, v_old_t2, v_old_t3
        from pr_order as of timestamp systimestamp where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
      v_hdr_found := true;
    exception when others then v_hdr_found := false;
    end;
    v_bwv_chg := not v_hdr_found or v_old_bwv <> nvl(o.bonus_with_vat, 0);
    -- DISTRIBUTE_DISC (new lines): DISC = DISC_VAL * NET_PRICE2 / (TOTAL_PRICE2 * QUANTITY), NET_PRICE2 = price * qty - line discount,
    -- TOTAL_PRICE2 = sum of NET_PRICE2 in riyal; only when DISC_VAL, NET_PRICE and TOTAL_PRICE are not 0
    select sum((nvl(vn_price, 0) * nvl(quantity, 0) - nvl(det_disc, 0)) * nvl(o.currency_rate, 0)),
           sum(((nvl(vn_price, 0) * nvl(quantity, 0)) - nvl(det_disc, 0)
                - (nvl(disc, 0) + nvl(disc1_value, 0) + nvl(disc2_value, 0) + nvl(disc3_value, 0)) * nvl(quantity, 0)) * nvl(o.currency_rate, 0))
      into v_tot2, v_tot
      from pr_order_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    for l in (select rowid rid, d.* from pr_order_det d where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial) loop
      begin
        select * into old from pr_order_det as of timestamp systimestamp
         where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial and serial = l.serial;
        v_found := true;
      exception when others then v_found := false;
      end;
      v_disc := l.disc;
      if not v_found then
        v_net := (nvl(l.vn_price, 0) * nvl(l.quantity, 0)) - nvl(l.det_disc, 0)
                 - (nvl(l.disc, 0) + nvl(l.disc1_value, 0) + nvl(l.disc2_value, 0) + nvl(l.disc3_value, 0)) * nvl(l.quantity, 0);
        if not (nvl(o.disc_val, 0) = 0 or nvl(v_net, 0) = 0 or nvl(v_tot, 0) = 0) then
          v_disc := (nvl(o.disc_val, 0) * ((nvl(l.vn_price, 0) * nvl(l.quantity, 0)) - nvl(l.det_disc, 0)))
                    / (nvl(v_tot2, 1) * nvl(l.quantity, 1));
        end if;
      end if;
      v_code := l.tax_code1; v_tax := l.tax_value1;
      if not v_found or v_bwv_chg
         or chg(l.quantity, old.quantity) + chg(l.bonus, old.bonus) + chg(l.extra_bonus, old.extra_bonus) + chg(l.vn_price, old.vn_price)
          + chg(l.disc1_value, old.disc1_value) + chg(l.disc2_value, old.disc2_value) + chg(l.disc3_value, old.disc3_value)
          + chg(l.item_code, old.item_code) > 0 then
        v_any := true;
        v_base := (nvl(l.vn_price, 0) - (nvl(l.disc1_value, 0) + nvl(l.disc2_value, 0) + nvl(l.disc3_value, 0))) * nvl(o.currency_rate, 1)
                  * case when nvl(o.bonus_with_vat, 0) = 0 then l.quantity
                         else nvl(l.quantity, 0) + nvl(l.bonus, 0) + nvl(l.extra_bonus, 0) end;
        line_tax(l.group_code, l.item_code, o.supplier_code, o.pr_order_date, v_base, v_code, v_tax);
      end if;
      if chg(v_code, l.tax_code1) + chg(v_tax, l.tax_value1) + chg(v_disc, l.disc) > 0 then
        g_bypass := true;
        update pr_order_det set tax_code1 = v_code, tax_value1 = v_tax, disc = v_disc where rowid = l.rid;
        g_bypass := false;
      end if;
    end loop;
    if v_any or not v_hdr_found or chg(o.tot_disc1_value, v_old_t1) + chg(o.tot_disc2_value, v_old_t2) + chg(o.tot_disc3_value, v_old_t3) > 0 then
      v_code := o.tax_code1; v_tax := o.tax_value1;
      -- the PR_ORDER form has no ST_TRNS_DET block: NAME_IN('ST_TRNS_DET.TAX_VALUE1_TOTAL') failed (FRM-40105) -> line tax NULL
      mast_tax(o.supplier_code, o.pr_order_date, null,
               nvl(o.disc_val, 0) + nvl(o.tot_disc1_value, 0) + nvl(o.tot_disc2_value, 0) + nvl(o.tot_disc3_value, 0), null, 0,
               v_code, v_tax);
      if chg(v_code, o.tax_code1) + chg(v_tax, o.tax_value1) > 0 then
        g_bypass := true;
        update pr_order set tax_code1 = v_code, tax_value1 = v_tax where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
        g_bypass := false;
      end if;
    end if;
  exception when others then
    g_bypass := false;
    raise;
  end;

  procedure order_after_save(p_rowid varchar2, p_request varchar2) is
    o pr_order%rowtype; v number; v_tot number;
  begin
    if p_rowid is null then return; end if;
    begin select * into o from pr_order where rowid = chartorowid(p_rowid); exception when no_data_found then return; end;
    order_taxes(o);
    select count(*) into v from (select 1 from pr_order_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial
                                 union all select 1 from pr_order_srvc where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial
                                 union all select 1 from pr_order_asst where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial);
    if p_request = 'SAVE' and v = 0 then
      raise_application_error(-20124, 'لا يمكن حفظ الحركة بدون تفاصيل');
    end if;
    -- PR_ORDER_DET PRE-INSERT "لابد من ادخال سعر الوحدة" for the lines added by the import buttons (PARA1 / PARA2)
    if p_request = 'SAVE' then
      for l in (select item_code from pr_order_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial
                   and nvl(vn_price, 0) = 0 and rownum = 1) loop
        raise_application_error(-20141, 'لابد من ادخال سعر الوحدة - الصنف ' || l.item_code);
      end loop;
    end if;
    select nvl(sum(nvl(vn_price, 0) * nvl(quantity, 0) - nvl(det_disc, 0)), 0) into v_tot
      from pr_order_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    if nvl(o.disc_val, 0) > 0 and nvl(o.disc_val, 0) > v_tot then
      raise_application_error(-20140, 'الخصم لا يمكن ان يكون اكبر من الفاتورة');
    end if;
    select max(trns_max_items) into v from st_basic;
    if v is not null then
      select count(*) into v_tot from pr_order_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
      if v_tot > v then
        raise_application_error(-20125, 'لقد تم إدخال ' || v_tot || ' صنف فى هذه الحركة، غير مسموح بأكثر من ' || v || ' صنف');
      end if;
    end if;
  end;

  -- PRE-DELETE / POST-DELETE of the legacy form; confirmed or closed orders cannot be deleted (CHECK_CLOSE)
  procedure order_after_delete(p_rowid varchar2, p_type varchar2 default null, p_serial varchar2 default null) is
    o pr_order%rowtype;
  begin
    if p_rowid is null then return; end if;
    begin
      -- committed row (flashback query: the page's own uncommitted DELETE is not visible there)
      select * into o from pr_order as of timestamp systimestamp where rowid = chartorowid(p_rowid);
    exception when others then
      o.trns_type_code := n(p_type); o.trns_serial := n(p_serial);
    end;
    if o.trns_type_code is null or o.trns_serial is null then return; end if;
    if nvl(o.confirm_flag, 0) = 1 or nvl(o.close_flag, 0) = 1 then
      raise_application_error(-20131, 'أمر الشراء معتمد أو مقفل ولا يمكن حذفه');
    end if;
    delete from pr_order_det_d     where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    delete from pr_order_store_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    delete from pr_order_det       where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    delete from pr_order_srvc      where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    delete from pr_order_asst      where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    update st_po_item_supp set pr_order_trns_type_code = null, pr_order_trns_serial = null
     where pr_order_trns_type_code = o.trns_type_code and pr_order_trns_serial = o.trns_serial;
  end;

  -- ================================================================ incoming lots
  -- GET_TAX_DET (line WHEN-VALIDATE-ITEM of ITEM_CODE / INCOME_QUANTITY / VN_PRICE / DISC* / SUPP_DISC* / DET_DISC):
  -- value = INCOME_BASIC_QTY * (VN_PRICE - DISC1..3) * CURRENCY_RATE; KEY-COMMIT: DISTRIBUTE_DISC (flag 1, 2) then UPDATE_COST
  procedure lot_lines_derive(o pr_income_lot%rowtype, p_request varchar2) is
    old pr_income_lot_det%rowtype;
    v_found boolean;
    v_code number; v_tax number; v_disc number; v_sum number; v_net number;
  begin
    select sum(((nvl(income_quantity, 0) * nvl(vn_price, 0)) - nvl(det_disc, 0)) * nvl(o.currency_rate, 1)) into v_sum
      from pr_income_lot_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    for l in (select rowid rid, d.* from pr_income_lot_det d where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial) loop
      begin
        select * into old from pr_income_lot_det as of timestamp systimestamp
         where trns_type_code = l.trns_type_code and trns_serial = l.trns_serial and serial = l.serial;
        v_found := true;
      exception when others then v_found := false;
      end;
      -- lines added by the "item import" button are completed on the page before the save (legacy PRE-INSERT of the block)
      if p_request = 'SAVE' and (l.production_date is null or l.sales_price is null or l.sales_disc_ratio is null or l.lot_number is null
                                 or l.expire_date is null or l.unit_code is null) then
        raise_application_error(-20121, 'يجب إدخال محددات الشحنات: رقم التشغيلة وتاريخ الصلاحية وتاريخ الانتاج وسعر البيع ونسبة خصم البيع - الصنف ' || l.item_code);
      end if;
      if p_request = 'SAVE' and nvl(l.income_quantity, 0) + nvl(l.income_bonus, 0) <= 0 then
        raise_application_error(-20139, 'يجب إدخال الكمية المستلمة - الصنف ' || l.item_code);
      end if;
      v_code := l.tax_code1; v_tax := l.tax_value1;
      if not v_found
         or chg(l.item_code, old.item_code) + chg(l.income_quantity, old.income_quantity) + chg(l.vn_price, old.vn_price)
          + chg(l.disc1_value, old.disc1_value) + chg(l.disc2_value, old.disc2_value) + chg(l.disc3_value, old.disc3_value)
          + chg(l.disc1_ratio, old.disc1_ratio) + chg(l.disc2_ratio, old.disc2_ratio) + chg(l.disc3_ratio, old.disc3_ratio)
          + chg(l.supp_disc_value, old.supp_disc_value) + chg(l.supp_disc_ratio, old.supp_disc_ratio) + chg(l.det_disc, old.det_disc) > 0 then
        line_tax(l.group_code, l.item_code, o.supplier_code, o.arrival_date,
                 (nvl(l.income_basic_qty, 0) * nvl(nvl(l.vn_price, 0) - (nvl(l.disc1_value, 0) + nvl(l.disc2_value, 0) + nvl(l.disc3_value, 0)), 0))
                   * nvl(o.currency_rate, 0),
                 v_code, v_tax);
      end if;
      v_disc := l.disc;
      v_net := ((nvl(l.income_quantity, 0) * nvl(l.vn_price, 0)) - nvl(l.det_disc, 0)) * nvl(o.currency_rate, 1);
      if nvl(o.st_srv_asst_flag, 1) in (1, 2) and not (nvl(o.disc_val, 0) = 0 or nvl(v_net, 0) = 0 or nvl(v_sum, 0) = 0) then
        v_disc := (nvl(o.disc_val, 0) * v_net) / (nvl(v_sum, 1) * nvl(l.income_quantity, 1));
      end if;
      if chg(v_code, l.tax_code1) + chg(v_tax, l.tax_value1) + chg(v_disc, l.disc) > 0 then
        g_bypass := true;
        update pr_income_lot_det set tax_code1 = v_code, tax_value1 = v_tax, disc = v_disc where rowid = l.rid;
        g_bypass := false;
      end if;
    end loop;
    -- UPDATE_COST: one average unit cost per item, group and sales price (rows with an empty sales price are not touched)
    for a in (select sum(unit_cost * income_basic_qty) total_cost, sum(income_basic_qty) qty, item_code, group_code, sales_price
                from pr_income_lot_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial
               group by item_code, group_code, sales_price) loop
      if a.qty <> 0 and a.total_cost is not null then
        g_bypass := true;
        update pr_income_lot_det set unit_cost = a.total_cost / a.qty
         where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial
           and item_code = a.item_code and group_code = a.group_code and sales_price = a.sales_price
           and decode(unit_cost, a.total_cost / a.qty, 0, 1) = 1;
        g_bypass := false;
      end if;
    end loop;
  exception when others then
    g_bypass := false;
    raise;
  end;

  procedure lot_after_save(p_rowid varchar2, p_request varchar2) is
    o pr_income_lot%rowtype; v number; v_fr number;
  begin
    if p_rowid is null then return; end if;
    begin select * into o from pr_income_lot where rowid = chartorowid(p_rowid); exception when no_data_found then return; end;
    lot_lines_derive(o, p_request);
    select count(*) into v from (select 1 from pr_income_lot_det  where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial
                                 union all select 1 from pr_income_lot_srvc where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial
                                 union all select 1 from pr_income_lot_asst where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial);
    if p_request = 'SAVE' and v = 0 then
      raise_application_error(-20124, 'لا يمكن حفظ الرسالة بدون تفاصيل');
    end if;
    -- CHECK_DET_EXP (lot version: freight only)
    select nvl(sum(nvl(freight_val, 0)), 0), count(*) into v_fr, v
      from pr_income_det_expens where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    if v > 0 and v_fr > nvl(o.freight_val, 0) then
      raise_application_error(-20126, 'يجب ان يتساوى مصاريف الموردين مع اجمالي تكاليف الاخرى للحركة');
    end if;
  end;

  -- KEY-DELREC / PRE-DELETE: posted lots cannot be deleted; details are removed with the header
  procedure lot_after_delete(p_rowid varchar2, p_type varchar2 default null, p_serial varchar2 default null) is
    o pr_income_lot%rowtype;
  begin
    if p_rowid is null then return; end if;
    begin
      -- committed row (flashback query: the page's own uncommitted DELETE is not visible there)
      select * into o from pr_income_lot as of timestamp systimestamp where rowid = chartorowid(p_rowid);
    exception when others then
      o.trns_type_code := n(p_type); o.trns_serial := n(p_serial);
    end;
    if o.trns_type_code is null or o.trns_serial is null then return; end if;
    if nvl(o.post_flag, 0) = 1 or (o.pu_trns_type_code is not null and o.pu_trns_serial is not null) then
      raise_application_error(-20135, 'الحركة الحالة تم إستلامها فى المخازن و لا يمكن الحذف');
    end if;
    delete from pr_income_lot_srvc     where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    delete from pr_income_lot_asst_det where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    delete from pr_income_lot_asst     where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    delete from as_asset_acct_tot      where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    delete from pr_income_lot_det      where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
    delete from pr_income_det_expens   where trns_type_code = o.trns_type_code and trns_serial = o.trns_serial;
  end;
end app_rules_pr;
/
show errors package app_rules_pr
show errors package body app_rules_pr
