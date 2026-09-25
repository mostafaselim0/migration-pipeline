-- =====================================================================================================
-- APP_PROC_ST : stock (ST) process screens of the ASCON ERP, reconstructed for APEX (Stage C).
--   ST_POSTING           post stock transactions to GL / AR / AP          -> post_trns
--   ST_CPOSTING          cancel the posting of stock transactions         -> cancel_trns
--   ST_POSTING_CPOSTING  combined post / cancel screen (FILTER 1 / 2)     -> post_cancel
--   ST_AUTO_ADJ          automatic stocktaking adjustment                 -> auto_adjust
--   ST_DIST_COST_N       redistribute cost on store transfers             -> dist_transfer_cost
--   (ST_ISSUE_IO_DLVR_TOUCH is not implemented: see app\legacy\processes\ST_ISSUE_IO_DLVR_TOUCH.md)
-- The posting engine (SET_POST_ENTRIES, MAKE_ENTRY, HANDLE_*, SET_POST_CUSTOMER, SET_POST_SUPPLIER,
-- MAKE_REVERSE_* ...) is ported from the program units of ST\FMB\ST_POSTING_CPOSTING.fmb; only the
-- Forms UI calls were replaced (see app\legacy\processes\ST_POSTING.md for the list of changes).
-- Each ported unit is preceded by a banner "legacy program unit <NAME>"; the drivers replacing the
-- button triggers and the ST_AUTO_ADJ / ST_DIST_COST_N procedures follow the ported units.
-- No COMMIT inside: APEX commits the page process (legacy committed once per button press).  UTF-8.
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_proc_st authid definer as

  -- ST_POSTING (system 3 serial 508, also 30/26 and 31/26): post the selected stock transactions.
  -- p_post_gl / p_post_ar / p_post_ap = 1 run the legacy buttons AC_BTN / AR_BTN / VN_BTN (in that order).
  procedure post_trns (
    p_from_date       in date,
    p_to_date         in date,
    p_from_type       in number,
    p_to_type         in number,
    p_from_serial     in number default null,
    p_to_serial       in number default null,
    p_from_customer   in number default null,
    p_to_customer     in number default null,
    p_from_salesman   in number default null,
    p_to_salesman     in number default null,
    p_supplier_code   in number default null,
    p_post_gl         in number default 1,
    p_post_ar         in number default 1,
    p_post_ap         in number default 1,
    p_company_code    in number default null,
    p_user_code       in number default null,
    p_password_number in number default null);

  -- ST_CPOSTING (system 3 serial 509, also 30/28 and 31/27): cancel the posting of the selected transactions.
  -- p_allow_grouped = 1 replaces the legacy confirmation "you are cancelling a grouped (collected) voucher".
  procedure cancel_trns (
    p_from_date       in date,
    p_to_date         in date,
    p_from_type       in number,
    p_to_type         in number,
    p_from_serial     in number default null,
    p_to_serial       in number default null,
    p_from_customer   in number default null,
    p_to_customer     in number default null,
    p_from_salesman   in number default null,
    p_to_salesman     in number default null,
    p_cancel_gl       in number default 1,
    p_cancel_ar       in number default 1,
    p_cancel_ap       in number default 1,
    p_allow_grouped   in number default 0,
    p_company_code    in number default null,
    p_user_code       in number default null,
    p_password_number in number default null);

  -- ST_POSTING_CPOSTING (system 3 serial 510): p_mode 1 = post, 2 = cancel posting (legacy list item FILTER).
  procedure post_cancel (
    p_mode            in number,
    p_from_date       in date,
    p_to_date         in date,
    p_from_type       in number,
    p_to_type         in number,
    p_from_serial     in number default null,
    p_to_serial       in number default null,
    p_from_customer   in number default null,
    p_to_customer     in number default null,
    p_from_salesman   in number default null,
    p_to_salesman     in number default null,
    p_gl              in number default 1,
    p_ar              in number default 1,
    p_ap              in number default 1,
    p_allow_grouped   in number default 0,
    p_company_code    in number default null,
    p_user_code       in number default null,
    p_password_number in number default null);

  -- counters of the last run (legacy display items ACCT_POSTED / CUST_POSTED / SUPP_POSTED)
  function last_gl_count return number;
  function last_ar_count return number;
  function last_ap_count return number;

  -- ST_AUTO_ADJ (system 3 serial 112): automatic stocktaking adjustment.
  -- Lines = items of the store whose book balance at the stocktaking date differs from the counted quantity
  -- (legacy block DET_BLK, filled by MAST_BLK.WHEN-NEW-ITEM-INSTANCE); usable in SQL for the page preview.
  type t_adj_line is record (
    group_code        number,
    item_code         varchar2(100),
    item_confg_id     number,
    item_name         varchar2(400),
    unit_code         number,
    unit_name         varchar2(200),
    factor            number,
    book_basic_qty    number,       -- BASIC_CURR_BALANCE_QTY
    book_qty          number,       -- CURR_BALANCE_QTY
    taking_basic_qty  number,       -- BASIC_QTY
    taking_qty        number,       -- QUANTITY
    unit_cost         number,
    expire_date       date,
    lot_number        varchar2(100),
    adj_error         number);      -- 1 = listed in ST_AUTO_ADJ_ERR by the last run
  type t_adj_lines is table of t_adj_line;
  function auto_adj_lines (p_store_code in number, p_taking_date in date) return t_adj_lines pipelined;

  -- MAKE_ADJUST: issue the whole book balance (or receive a negative one) with p_issue_type / p_rec_type,
  -- then receive the counted quantity.  p_group_code / p_item_code limit the run to one group / item
  -- (the legacy form let the user tick lines; "choose all" = no filter).
  procedure auto_adjust (
    p_taking_date     in date,
    p_store_code      in number,
    p_issue_type      in number,
    p_rec_type        in number,
    p_group_code      in number   default null,
    p_item_code       in varchar2 default null,
    p_company_code    in number   default null,
    p_user_code       in number   default null,
    p_password_number in number   default null);

  -- ST_DIST_COST_N (system 3 serial 521): redistribute the cost of store transfers day by day:
  -- transfer-out lines get GET_UNIT_COST_CONFG, the matching transfer-in lines get the same cost
  -- (the ST_TRNS_DET_C_UP trigger then rebuilds ST_TRNS_DET_COST and the following costs).
  procedure dist_transfer_cost (
    p_from_date       in date,
    p_to_date         in date,
    p_company_code    in number default null,
    p_user_code       in number default null,
    p_password_number in number default null);

end app_proc_st;
/

create or replace package body app_proc_st as

  -- ---------------------------------------------------------------------------------------------
  -- package state replacing the Forms globals / parameters / block items used by the legacy units
  -- ---------------------------------------------------------------------------------------------
  g_lang             varchar2(1)  := 'A';     -- :GLOBAL.LANG
  g_company          number;                  -- :GLOBAL.COMPANY_CODE
  g_password         number;                  -- :GLOBAL.PASSWORD_NUMBER (0 = administrators group)
  g_user             number;                  -- :GLOBAL.USER_CODE
  -- :GLOBAL.CUSTOMER_CODE is the vendor's installation code set by the ASCON main menu (not in the evidence).
  -- The legacy units only test it against 'BEN' / 'AZZ' (other installations).  The pipeline fills in the client's code
  -- (client.json "customer_code") when it runs this script.
  g_cust_code        varchar2(30) := '{{CUSTOMER_CODE}}';
  g_system_number    number       := 3;       -- :GLOBAL.SYSTEM_NUMBER (stock control)
  g_system_post_type number       := 4;       -- :PARAMETER.SYSTEM_POST_TYPE (ST_BASIC.POST_TYPE, 4 = per transaction type)
  g_first_record     number       := 0;       -- :GLOBAL.FIRST_RECORD (AP posting of several invoices into one voucher)
  g_supp_trns_serial number;                  -- :GLOBAL.SUPP_TRNS_SERIAL
  g_supplier_code    number;                  -- :CONTROL_BLOCK.SUPPLIER_CODE (only visible for installation BEN)
  g_allow_grouped    number       := 0;       -- answer to alert MULT_ALET
  g_acct_posted      number       := 0;       -- :ACCT_POSTED
  g_cust_posted      number       := 0;       -- :CUST_POSTED
  g_supp_posted      number       := 0;       -- :SUPP_POSTED

  type t_cur is record (                      -- current record of block ST_TRNS_MAST
    trns_type_code  number,
    trns_serial     number,
    trns_date       date,
    post_flag       number,
    cust_post_flag  number,
    supp_post_flag  number,
    join_type       number);
  g_cur t_cur;

  type t_filter is record (
    from_date date, to_date date, from_type number, to_type number,
    from_serial number, to_serial number, c1 number, c2 number, s1 number, s2 number);

  -- the query of block ST_TRNS_MAST (DEFAULT_WHERE incl. the transaction-type security filter)
  cursor c_block (f t_filter, p_filter number) is
    select m.trns_type_code, m.trns_serial
      from st_trns_mast m
     where (g_password = 0
            or m.trns_type_code in (select tp.trns_type_code from st_trnstype_password tp
                                     where tp.flag = 1 and tp.password_number = g_password))
       and nvl(m.delete_flag, 0) = 0
       and m.trns_type_code between f.from_type and f.to_type
       and m.trns_date between f.from_date and f.to_date
       and ((f.from_serial is null and f.to_serial is null) or m.trns_serial between f.from_serial and f.to_serial)
       and ((f.c1 is null and f.c2 is null) or m.customer_code between f.c1 and f.c2)
       and ((f.s1 is null and f.s2 is null) or m.salesman_code between f.s1 and f.s2)
       and (   (p_filter = 1 and get_join_type(m.trns_type_code) in (2, 3, 4) and nvl(m.post_flag, 0) = 0)
            or (p_filter = 2 and get_join_type(m.trns_type_code) in (2, 3, 4) and nvl(m.post_flag, 0) = 1)
            or (p_filter = 1 and get_join_type(m.trns_type_code) = 3 and nvl(m.cust_post_flag, 0) = 0)
            or (p_filter = 2 and get_join_type(m.trns_type_code) = 3 and nvl(m.cust_post_flag, 0) = 1)
            or (p_filter = 1 and get_join_type(m.trns_type_code) = 4 and nvl(m.supp_post_flag, 0) = 0)
            or (p_filter = 2 and get_join_type(m.trns_type_code) = 4 and nvl(m.supp_post_flag, 0) = 1))
     order by m.trns_type_code, m.trns_serial;


  function last_gl_count return number is begin return g_acct_posted; end;
  function last_ar_count return number is begin return g_cust_posted; end;
  function last_ap_count return number is begin return g_supp_posted; end;

  -- legacy library procedure MSG(arabic, english, finish): alert, and FORM_TRIGGER_FAILURE when finish = 1
  procedure app_msg (p_msg_a in varchar2, p_msg_e in varchar2, p_finish in number) is
    l varchar2(2000) := case when g_lang = 'E' and p_msg_e is not null then p_msg_e else p_msg_a end;
  begin
    if p_finish = 1 then
      raise_application_error(-20101, substr(l, 1, 2000));
    end if;
  end app_msg;

  -- warnings that the legacy form showed as an alert before skipping one transaction: kept in ST_POST_MSG
  procedure log_msg (p_trns_type_code in number, p_trns_serial in number, p_msg in varchar2) is
  begin
    insert into st_post_msg (trns_type_code, trns_serial, message)
    values (p_trns_type_code, p_trns_serial, substr(p_msg, 1, 800));
  end log_msg;

  procedure grouped_error (p_trns_type_code in number, p_trns_serial in number) is
  begin
    raise_application_error(-20102, case when g_lang = 'E'
      then 'Transaction ' || p_trns_type_code || '/' || p_trns_serial || ' belongs to a collected voucher; tick "cancel collected vouchers" to continue.'
      else 'الحركة ' || p_trns_type_code || '/' || p_trns_serial || ' ضمن قيد مجمع - انت بصدد إلغاء قيد مجمع، اختر "إلغاء القيود المجمعة" للاستمرار' end);
  end grouped_error;

  procedure init_ctx (p_company_code in number, p_user_code in number, p_password_number in number) is
  begin
    g_company  := nvl(p_company_code, to_number(v('G_COMPANY_CODE')));
    g_user     := nvl(p_user_code, to_number(v('G_USER_CODE')));
    g_password := nvl(p_password_number, nvl(to_number(v('G_PASSWORD_NUMBER')), -1));
    g_lang     := case when lower(nvl(v('G_LANG'), 'ar')) like 'en%' then 'E' else 'A' end;
    if g_company is null then
      select min(company_code) into g_company from ac_basic;
    end if;
    begin
      select post_type into g_system_post_type from st_basic;      -- WHEN-NEW-FORM-INSTANCE
    exception when others then
      g_system_post_type := 4;
    end;
    g_acct_posted := 0; g_cust_posted := 0; g_supp_posted := 0;
    g_first_record := 0; g_supp_trns_serial := null; g_supplier_code := null; g_allow_grouped := 0;
  end init_ctx;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit GET_DOC_NO (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
PROCEDURE GET_DOC_NO(B_SER OUT NUMBER ,FROM_SER OUT NUMBER ,TO_SER OUT NUMBER ,B_DOC OUT NUMBER ,P_BOX_CODE NUMBER) IS
BEGIN
  BEGIN
    select MIN(BOOK_SERIAL)
    INTO B_SER
    from RP_BOXS_BOOKS 
    where BOX_CODE = P_BOX_CODE
        AND NVL(STOP_FLAG,0)=0
        AND NVL(BOOK_TYPE,0) = 2
        AND NVL(BOOK_FINSH,0) = 0;

    select FROM_SERIAL, TO_SERIAL
    INTO FROM_SER  , TO_SER
    from RP_BOXS_BOOKS 
    where BOX_CODE = P_BOX_CODE
        AND BOOK_SERIAL = B_SER ;
EXCEPTION 
    WHEN NO_DATA_FOUND THEN 
      FROM_SER := NULL;
      TO_SER := NULL;
      app_msg('لا يتم ربط اي دفاتر علي هذا الصندوق','No Book For This Box',1);
END;
BEGIN
  SELECT NVL(MAX(BOOK_DOC_NO),0) + 1
  INTO B_DOC
  FROM RP_TRNS_MAST
  where TRNS_TYPE_CODE IN 
      (SELECT TRNS_TYPE_CODE 
      FROM RP_TRNS_TYPE 
      WHERE TRNS_TYPE = 2)
      AND BOX_CODE = P_BOX_CODE
        AND BOOK_SERIAL = B_SER  ;
  
  IF B_DOC < FROM_SER THEN 
      B_DOC := FROM_SER ;
  END IF;
END;
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit INSERT_RP_PC_TRNS (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION INSERT_RP_PC_TRNS(IN_TRNS_TYPE_CODE NUMBER,
                                                        IN_TRNS_SERIAL NUMBER) RETURN BOOLEAN IS
    TEMP_JOIN    NUMBER;
    TEMP_RP_TRNS_TYPE_CODE NUMBER;
    TEMP_PC_TRNS_TYPE_CODE NUMBER;
    TEMP_TRNS_SERIAL    NUMBER;
    TEMP_BOX_CODE        NUMBER;
    TEMP    NUMBER;
    temp_doc_no NUMBER;
    B_SER    NUMBER;
    FROM_SER NUMBER;
    TO_SER NUMBER;
    DOC_NUM NUMBER;
    TEMP_BOOK_SERIAL NUMBER;
    TEMP_BOOK_DOC_NO NUMBER;
    TEMP_BANK_CODE   NUMBER;
    TEMP_BRANCH_CODE NUMBER;
    T_CHANGE_AMMOUNT_CURR NUMBER;
    T_PAYMENT NUMBER;
    T_TRNS_DATE DATE;
    T_DESC_A VARCHAR2(200);
    T_DESC_E VARCHAR2(200);
    T_ATM_AMMOUNT NUMBER;
BEGIN
  SELECT    JOIN_TYPE,RP_TRNS_TYPE_CODE,PC_TRNS_TYPE_CODE
  INTO        TEMP_JOIN,TEMP_RP_TRNS_TYPE_CODE,TEMP_PC_TRNS_TYPE_CODE
  FROM        ST_TRNS_TYPE
  WHERE        TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE;

    SELECT PAYMENT,TRNS_DATE,DESC_A,DESC_E,NVL(ATM_AMMOUNT,0)+NVL(AMEX_AMMOUNT,0)+NVL(CHECK_AMMOUNT ,0) + NVL(VISA_AMMOUNT,0) +NVL(CARD_AMMOUNT,0)
    INTO     T_PAYMENT,T_TRNS_DATE,T_DESC_A,T_DESC_E,T_ATM_AMMOUNT
    FROM      ST_TRNS_MAST
    WHERE     TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE AND
                    TRNS_SERIAL = IN_TRNS_SERIAL;
                    
    SELECT COUNT(1)
    INTO   TEMP
    FROM   SYS_SYSTEMS
    WHERE  SYSTEM_NUMBER IN (13,15);  
    
  
  IF NVL(T_PAYMENT,0) != 0 AND TEMP != 0 THEN
      IF TEMP_RP_TRNS_TYPE_CODE IS NULL THEN
          insert into st_post_msg (trns_type_code,trns_serial,message) 
                                     values (in_trns_type_code,in_trns_serial,
                                            'يجب ادخال حركة للصندوق في الربط');
      return(false);
      ELSE
          BEGIN
                SELECT NVL(MAX(TRNS_SERIAL),0) + 1
                INTO TEMP_TRNS_SERIAL
                FROM RP_TRNS_MAST
                WHERE TRNS_TYPE_CODE= TEMP_RP_TRNS_TYPE_CODE;
            EXCEPTION WHEN OTHERS THEN
                    TEMP_TRNS_SERIAL:=1;
            END;

            begin
                    select    nvl(max(doc_no),TEMP_RP_trns_type_code || '00000') + 1 
                    into        temp_doc_no
                    from        RP_TRNS_MAST
                  where        trns_type_code = TEMP_RP_trns_type_code;       
            exception 
                when no_data_found then
                 null;
            end;

          BEGIN
                SELECT BOX_CODE
                INTO TEMP_BOX_CODE
                FROM RP_TRNS_TYPE
                WHERE TRNS_TYPE_CODE= TEMP_RP_TRNS_TYPE_CODE;
            EXCEPTION WHEN OTHERS THEN
                    NULL;
            END;
            
            LOOP     
                GET_DOC_NO(B_SER ,FROM_SER ,TO_SER  ,DOC_NUM , TEMP_BOX_CODE )  ;
              
              IF DOC_NUM NOT BETWEEN FROM_SER AND TO_SER THEN
                  UPDATE RP_BOXS_BOOKS B
                  SET STOP_FLAG =1
                  WHERE BOOK_SERIAL = B_SER 
                    AND  B.BOX_CODE = TEMP_BOX_CODE ;
              ELSE
                  TEMP_BOOK_SERIAL := B_SER ;
                  TEMP_BOOK_DOC_NO := DOC_NUM ;
              EXIT ;
              END IF ;
              EXIT WHEN FROM_SER IS NULL AND TO_SER IS NULL ;
            END LOOP ;    
            
          INSERT INTO RP_TRNS_MAST
          (TRNS_TYPE_CODE         ,
            TRNS_SERIAL            ,
            TRNS_DATE              ,
            DEL_FLAG               ,
            DOC_NO                 ,
            DESC_A                 ,
            DESC_E                 ,
            ACCOUNT_NO             ,
            AMOUNT                 ,
            POST_FLAG              ,
            AC_FLAG                ,
            BOOK_SERIAL            ,
            BOX_CODE               ,
            BOOK_DOC_NO            ,
            BENF_TYPE              )
            VALUES
            (TEMP_RP_TRNS_TYPE_CODE         ,
            TEMP_TRNS_SERIAL            ,
            T_TRNS_DATE              ,
            0               ,
            TEMP_DOC_NO                 ,
            T_DESC_A                 ,
            T_DESC_E                 ,
            NULL      ,
            T_PAYMENT                 ,
            1              ,
            1                ,
            TEMP_BOOK_SERIAL            ,
            TEMP_BOX_CODE               ,
            TEMP_BOOK_DOC_NO            ,
            0              );
            
            UPDATE ST_TRNS_MAST
            SET  RP_TRNS_TYPE_CODE = TEMP_RP_TRNS_TYPE_CODE,
                     RP_TRNS_SERIAL = TEMP_TRNS_SERIAL
            WHERE TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE AND
                        TRNS_SERIAL = IN_TRNS_SERIAL;

      END IF;
  END IF;
  
  IF NVL(T_ATM_AMMOUNT,0) != 0 AND TEMP != 0 THEN
      IF TEMP_PC_TRNS_TYPE_CODE IS NULL THEN
          insert into st_post_msg (trns_type_code,trns_serial,message) 
                                     values (in_trns_type_code,in_trns_serial,
                                           'يجب ادخال حركة للشبكة في الربط');
      return(false);          
      ELSE

          BEGIN
                SELECT NVL(MAX(TRNS_SERIAL),0) + 1
                INTO TEMP_TRNS_SERIAL
                FROM CHECK_MAST
                WHERE TRNS_TYPE_CODE= TEMP_PC_TRNS_TYPE_CODE;
            EXCEPTION WHEN OTHERS THEN
                    TEMP_TRNS_SERIAL:=1;
            END;

            begin
                    select    nvl(max(doc_no),TEMP_PC_trns_type_code || '00000') + 1 
                    into        temp_doc_no
                    from        CHECK_MAST
                  where        trns_type_code = TEMP_PC_trns_type_code;       
            exception 
                when no_data_found then
                 null;
            end;

          BEGIN
                SELECT BANK_CODE,BRANCH_CODE
                INTO TEMP_BANK_CODE,TEMP_BRANCH_CODE
                FROM CHECK_TRNS_TYPE
                WHERE TRNS_TYPE_CODE= TEMP_PC_TRNS_TYPE_CODE;
            EXCEPTION WHEN OTHERS THEN
                    NULL;
            END;
          
          INSERT INTO CHECK_MAST
          (TRNS_TYPE_CODE         ,
            TRNS_SERIAL            ,
            TRNS_DATE              ,
            DEL_FLAG               ,
            DOC_NO                 ,
            DESC_A                 ,
            DESC_E                 ,
            ACCOUNT_NO             ,
            BANK_CODE              ,
            BRANCH_CODE            ,
            BOOK_NO                ,
            CHEQUE_NO              ,
            AMOUNT                 ,
            APPROVED               ,
            POST_FLAG              ,
            AC_FLAG                ,
            BENF_TYPE              )
            VALUES
            (TEMP_PC_TRNS_TYPE_CODE         ,
            TEMP_TRNS_SERIAL            ,
            T_TRNS_DATE     ,
            0               ,
            TEMP_DOC_NO                 ,
            T_DESC_A                 ,
            T_DESC_E                 ,
            NULL        ,
            TEMP_BANK_CODE              ,
            TEMP_BRANCH_CODE            ,
            NULL                ,
            NULL                ,
            T_ATM_AMMOUNT        ,
            0               ,
            1              ,
            1                ,
            0              );
            
            UPDATE ST_TRNS_MAST
            SET  PC_TRNS_TYPE_CODE = TEMP_PC_TRNS_TYPE_CODE,
                     PC_TRNS_SERIAL = TEMP_TRNS_SERIAL
            WHERE TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE AND
                        TRNS_SERIAL = IN_TRNS_SERIAL;
            
      END IF;
  END IF;
  RETURN TRUE;
EXCEPTION
      WHEN OTHERS THEN
          insert into st_post_msg (trns_type_code,trns_serial,message) 
                                     values (in_trns_type_code,in_trns_serial,
                                           'خطأ اثناء ادخال حركة النقدية او البنك');
      return(false);            
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit GET_TRNS_DATA (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
PROCEDURE GET_TRNS_DATA (in_trns_type       in  st_trns_type.trns_type_code%type ,
                         out_join_type      out st_trns_type.join_type%type,
                         out_entry_type     out st_trns_type.entry_type%type,
                         out_cust_trns_code out st_trns_type.customer_trns_code%type,
                         out_supp_trns_code out st_trns_type.Supplier_trns_code%type,
                         out_supp_pay_trns_code out st_trns_type.Supplier_trns_code%type,
                         out_Post_type      out st_trns_type.Post_Type%type,
                         OUT_SUPP_DISC_TRNS_TYPE out st_trns_type.SUPP_DISC_TRNS_TYPE%type)

/* *********************************************************************** **
**  gets the Join data of the passed transaction type, it gets the number  **
**   of the GL entry type, or AR trns code, or AP trns code and the join   **
**   type value from st_trns_type table.                                   **
** *********************************************************************** */

IS

BEGIN
 select nvl(join_type,0) , nvl(entry_type,0) , nvl(customer_trns_code,0),
        nvl(supplier_trns_code,0),nvl(supplier_trns_pay_code,0),
        nvl(Post_type,0),NVL(SUPP_DISC_TRNS_TYPE,0)
   into out_join_type, out_entry_type, out_cust_trns_code, 
        out_Supp_trns_code, out_supp_pay_trns_code ,
        out_Post_type,OUT_SUPP_DISC_TRNS_TYPE
   from st_trns_type
   where trns_type_code = in_trns_type;

exception
 when others then
   out_join_type      := 0 ;
   out_entry_type     := 0 ;
   out_cust_trns_code := 0 ;
   out_Supp_trns_code := 0 ;
   out_post_type      := 0 ;
   out_supp_pay_trns_code := 0;
   OUT_SUPP_DISC_TRNS_TYPE := 0;
end;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit CHECK_COST_CENTERS (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION CHECK_COST_CENTERS(IN_TRNS_TYPE_CODE        NUMBER,
                                                        IN_TRNS_SERIAL            NUMBER,
                                                        COST_CENTER                 NUMBER,
                                                        COST_CENTER2                NUMBER) RETURN BOOLEAN IS

        W_STATUS NUMBER;
BEGIN
        if nvl(COST_CENTER,0) != 0 then
            begin 
                select cost_status
            into w_status
            from ac_cost_centers
            where cost_code = COST_CENTER;
            
            if w_status = 0 then
                    insert into st_post_msg (trns_type_code,trns_serial,message) 
                                 values (in_trns_type_code,in_TRNS_SERIAL,
                                                    ' رقم مركز التكلفة ليس على أدنى مستوى ');
                            return(false);
            end if;
              exception
                when others then      
                     insert into st_post_msg (trns_type_code,trns_serial,message) 
                                  values (in_trns_type_code,in_TRNS_SERIAL,
                                               ' رقم مركز التكلفة غير موجود فى نظام الحسابات ');
                                 return(false);
        end;
    end if;
               
    if nvl(COST_CENTER2,0) != 0 then
             begin 
                  select cost_status
                into w_status
                from ac_cost_centers2
                   where cost_code = COST_CENTER2;
                   if w_status = 0 then
                    insert into st_post_msg (trns_type_code,trns_serial,message) 
                                     values (in_trns_type_code,in_TRNS_serial,
                                            ' رقم مركز التكلفة 2 ليس على أدنى مستوى ');
                    return(false);
                   end if;
                exception
                   when others then      
                    insert into st_post_msg (trns_type_code,trns_serial,message) 
                                     values (in_trns_type_code,in_TRNS_serial,
                                            ' رقم مركز التكلفة 2 غير موجود فى نظام الحسابات ');
                    return(false);
            end;
       end if;
  RETURN(TRUE);
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit HANDLE_BROKER_VALUES (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION HANDLE_BROKER_VALUES(in_trns_type_code         IN NUMBER,
    in_serial_number          IN NUMBER,
    IN_Entry_No               IN NUMBER,
    IN_Account_No_Type     IN NUMBER,
    IN_Account_No                IN NUMBER,
    IN_cost_No                    IN NUMBER,
    IN_cost_No2                  IN NUMBER,
    IN_Cost_No_Type             IN NUMBER,
    IN_Cost_No2_Type            IN NUMBER,
    IN_Value_Type          IN NUMBER,
    IN_doc_no              IN NUMBER,
    IN_date                IN DATE,
    IN_Account_Ind                IN NUMBER,
    in_Trns_Post_type      IN NUMBER,
    in_entry_type                IN NUMBER,
    IN_trns_desc                  IN VARCHAR2,
    IN_trns_type_desc      IN VARCHAR2,
    IN_REQUEST_NO        IN VARCHAR2,
    IN_REQUEST_NO_E        IN VARCHAR2,
    D_TOT_VAL                        OUT NUMBER ) RETURN BOOLEAN IS
    
    Ldgr_Rec              st_ledger%rowtype;
    w_status                            NUMBER;
    total_value                        NUMBER:=0;    
    V_DISC_MAST           NUMBER;
    w_service            NUMBER ;
  V_BROKER_VALUE NUMBER ;
  V_ITEMS_TOTAL_CURR NUMBER ;
  V_DET_DISC      NUMBER ; 
  V_DISC_VAL       NUMBER ;
  V_SERVICE        NUMBER;    

BEGIN
      
IF IN_Value_Type <> 61 THEN  
            insert into st_post_msg (trns_type_code,trns_serial,message) 
            values (in_trns_type_code,in_serial_number,
            '  خطأ فى مؤشر القيمة -سمسار ');
            Return (FALSE);
End If;    
    FOR C_REC IN (   SELECT ROUND (SUM (NVL (unit_price, 0) * NVL (quantity, 0)), 2) Items_total,
                                         ROUND (SUM (NVL (det_disc, 0)), 2) Items_total_DISC,
                                         0 DISC_VAL,
                                         ROUND (
                                            SUM (
                                                 (  NVL (SUPP_FREIGHT, 0)
                                                  + NVL (SUPP_INSURANCE, 0)
                                                  + NVL (SUPP_OTHERS, 0))
                                               * NVL (quantity, 0)
                                               * NVL (FACTOR, 1))                         
                                                                 ,
                                            2)
                                            SUPP_COSTS,
                                         ROUND (SUM (NVL (FREIGHT, 0) * NVL (quantity, 0) * NVL (FACTOR, 1) 
                                                                                                           ),
                                                2)
                                            GAMAREK_TAKHLIS_NAKL,
                                         ROUND (SUM (NVL (CUSTOMS, 0) * NVL (quantity, 0) * NVL (FACTOR, 1) 
                                                                                                           ),
                                                2)
                                            BANKIA,
                                         ROUND (
                                            SUM (NVL (D.TRANSPORT, 0) * NVL (quantity, 0) * NVL (FACTOR, 1) 
                                                                                                           ),
                                            2)
                                            TAMIN,
                                         ROUND (SUM (NVL (D.OTHERS, 0) * NVL (quantity, 0) * NVL (FACTOR, 1) 
                                                                                                            ),
                                                2)
                                            OKHRA,
                                         s.Account_number1,
                                         s.Account_number2,
                                         s.Account_number3,
                                         s.Account_number4,
                                         s.cost_code s_cost,
                                         s.cost_code2 s_cost2,
                                         m.TRNSFER_TO_STORE,
                                         m.cost_code,
                                         m.cost_code2,
                                         G.cost_code cost_code_G,
                                         G.cost_code2 cost_code2_G,
                                         M.BROKER_VALUE ,
                                         M.BROKER_CODE
                                    FROM st_trns_det d,
                                         ST_TRNS_MAST M,
                                         st_store s,
                                         st_trns_type tt,
                                         ST_ITEM_UNIT UNT,
                                         ST_ITEM_GROUP G 
                                   WHERE     D.ITEM_CODE = UNT.ITEM_CODE
                                         AND D.GROUP_CODE = UNT.GROUP_CODE
                                         AND D.GROUP_CODE = G.ITEM_GROUP_CODE
                                         AND D.UNIT_CODE = UNT.UNIT_CODE
                                         AND NVL(M.DELETE_FLAG,0)    = 0
                                         AND NVL(D.DELETE_FLAG,0)    = 0
                                         AND d.trns_type_code = M.trns_type_code
                                         AND tt.trns_type_code = M.trns_type_code
                                         AND d.trns_serial = M.trns_serial
                                         AND d.trns_type_code = in_trns_type_code
                                         AND d.trns_serial = in_serial_number
                                         AND s.store_code = d.store_code
                                GROUP BY s.Account_number1,
                                         s.Account_number2,
                                         s.Account_number3,
                                         s.Account_number4,
                                         s.cost_code,
                                         s.cost_code2,
                                         m.TRNSFER_TO_STORE,
                                         m.cost_code,
                                         m.cost_code2,
                                         G.cost_code,
                                         G.cost_code2,M.BROKER_VALUE, M.BROKER_CODE )
        
    LOOP 
IF nvl(c_rec.BROKER_VALUE,0) > 0 THEN  
        --BROKER_VALUE := nvl(c_rec.BROKER_VALUE,0);
                  SELECT DISC_VAL * NVL(CURRENCY_RATE,1)
                    INTO V_DISC_MAST
                    FROM ST_TRNS_MAST
                   WHERE trns_type_code = in_trns_type_code
                                         and trns_serial = in_serial_number ; 


                -----------------BROKER----------------------------------    
                BEGIN
                     SELECT SUM (NVL (UNIT_PRICE, 0) * NVL (QUANTITY, 0)) ITEMS_TOTAL_CURR,
                            ROUND (SUM (NVL (DET_DISC, 0)), 2) ITEMS_TOTAL_DISC,
                            NVL (DISC_VAL, 0) DISC_VAL
                       INTO V_ITEMS_TOTAL_CURR, V_DET_DISC, V_DISC_VAL
                       FROM ST_TRNS_MAST M, ST_TRNS_DET D
                      WHERE     M.TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
                            AND M.TRNS_SERIAL = IN_SERIAL_NUMBER
                            AND NVL (M.DELETE_FLAG, 0) = 0
                            AND NVL(D.DELETE_FLAG,0)    = 0
                            AND D.TRNS_TYPE_CODE(+) = M.TRNS_TYPE_CODE
                            AND D.TRNS_SERIAL(+) = M.TRNS_SERIAL
                   GROUP BY NVL (DISC_VAL, 0);
                EXCEPTION
                   WHEN OTHERS
                   THEN
                      NULL;
                END;
                
                BEGIN
                   SELECT NVL (ROUND (SUM (NVL (SERVICE_COST, 0) * NVL (UNITS_NO, 0)), 2), 0)
                     INTO V_SERVICE
                     FROM ST_TRNS_MAST M, ST_TRNS_SERVICES D
                    WHERE     D.TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
                          AND D.TRNS_SERIAL = IN_SERIAL_NUMBER
                          AND NVL (M.DELETE_FLAG, 0) = 0
                          AND D.TRNS_TYPE_CODE = M.TRNS_TYPE_CODE
                          AND D.TRNS_SERIAL = M.TRNS_SERIAL;
                EXCEPTION
                   WHEN OTHERS
                   THEN
                      NULL;
                END;
                
                BEGIN
                   SELECT NVL (BROKER_VALUE, 0)                     /** NVL(CURRENCY_RATE,1)*/
                     INTO V_BROKER_VALUE
                     FROM ST_TRNS_MAST
                    WHERE     TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
                          AND TRNS_SERIAL = IN_SERIAL_NUMBER;
                EXCEPTION
                   WHEN OTHERS
                   THEN
                      NULL;
                END;
                -----------------BROKER----------------------------------

                                         
                                    Select nvl(round(Sum(nvl(service_cost,0) * nvl(units_no,0)),2),0)
                                    Into   w_service
                                    From   st_trns_mast m, st_trns_services d 
                                    Where  d.trns_type_code = in_trns_type_code
                                    and    d.trns_serial    = in_serial_number
                                    and    nvl(m.delete_flag,0)    = 0
                                    and    d.trns_type_code = m.trns_type_code
                                    and    d.trns_serial    = m.trns_serial;
                                            
        If IN_Entry_No is not null then
            Ldgr_Rec.Voucher_No := IN_Entry_No;
        end if;

       SELECT ACCOUNT_NUMBER,COST_CODE,COST_CODE2
         INTO  Ldgr_Rec.Account_No,Ldgr_Rec.COST_CODE,Ldgr_Rec.COST_CODE2
       FROM   ST_BROKER 
       WHERE  BROKER_CODE = c_rec.BROKER_CODE;            

        If Ldgr_Rec.Account_No is null Then 
            insert into st_post_msg (trns_type_code,trns_serial,message) 
            values (in_trns_type_code,in_serial_number,
            '  رقم الحساب غير موجود(السمسار) ');
            Return (FALSE);
        End If;

        begin 
            select account_status
            into w_status
            from ac_master
            where account_number = ldgr_rec.account_no;
        
            if w_status = 0 then
                insert into st_post_msg (trns_type_code,trns_serial,message) 
                values (in_trns_type_code,in_serial_number,
                ' رقم الحساب ليس على أدنى مستوى ');
                return(FALSE);
            end if;
        exception
            when others then      
                insert into st_post_msg (trns_type_code,trns_serial,message) 
                values (in_trns_type_code,in_serial_number,
                ' رقم الحساب غير موجود بملف المخلص فى نظام الحسابات ');
                return(FALSE);
        end;

        if IN_Cost_No_Type=1 then                                        
        Ldgr_Rec.Cost_Code:= IN_Cost_No;
      elsif IN_Cost_No_Type=2 then
        Ldgr_Rec.Cost_Code:= c_rec.s_cost;
      elsif IN_Cost_No_Type=3 then
        Ldgr_Rec.Cost_Code:= c_rec.cost_code;                
      elsif IN_Cost_No_Type=4 then
        Ldgr_Rec.Cost_Code:= c_rec.cost_code_G;                                                                                  
      elsif IN_Cost_No_Type=5 then
                select s.Cost_Code
                into   Ldgr_Rec.Cost_Code
                from   st_store s
                where  s.store_code = c_rec.trnsfer_to_store;
      elsif IN_Cost_No_Type=6 then
        Ldgr_Rec.Cost_Code:= NULL;                                                                                      
      Else                                        
        insert into st_post_msg (trns_type_code,trns_serial,message) 
                                   values (in_trns_type_code,in_serial_number,
                                           ' خطأ فى مؤشر رقم مركز التكلفة ');
                     Return (FALSE);
      End If;                                  
      if IN_Cost_No2_Type=1 then
        Ldgr_Rec.Cost_Code2:= IN_Cost_No2;
      elsif IN_Cost_No2_Type=2 then
        Ldgr_Rec.Cost_Code2:= c_rec.s_cost2;
      elsif IN_Cost_No2_Type=3 then
        Ldgr_Rec.Cost_Code2:= c_rec.cost_code2;                                      
      elsif IN_Cost_No2_Type=5 then
                select s.Cost_Code2
                into   Ldgr_Rec.Cost_Code2
                from   st_store s
                where  s.store_code = c_rec.trnsfer_to_store;
      elsif IN_Cost_No2_Type=4 then
        Ldgr_Rec.Cost_Code2:= c_rec.cost_code2_G;                        
      elsif IN_Cost_No2_Type=6 then
        Ldgr_Rec.Cost_Code2:= NULL;                                      
                
      Else    
        insert into st_post_msg (trns_type_code,trns_serial,message) 
                                   values (in_trns_type_code,in_serial_number,
                                           '2 خطأ فى مؤشر ملف المخلص رقم مركز التكلفة ');
                     Return (FALSE);
        End If; 

-- MESSAGE(ldgr_rec.cost_code2); PAUSE;                         

            IF CHECK_COST_CENTERS(in_trns_type_code,in_serial_number,
                                    ldgr_rec.cost_code,ldgr_rec.cost_code2)= FALSE THEN 
                                    RETURN (FALSE);
        END IF;


    
        ldgr_rec.doc_no    := IN_doc_no ;
        ldgr_rec.trns_date := IN_date   ;
        ldgr_rec.trns_type_code := in_trns_type_code ;
        ldgr_rec.trns_serial    := in_serial_number  ;                           
        ldgr_rec.post_flag      := in_Trns_Post_type;                            
        ldgr_rec.entry_type     := in_entry_type;

        if in_Trns_Post_type = 1 then
            if IN_trns_desc is null then
                ldgr_rec.entry_desc  :=  IN_trns_type_desc;
            else 
                ldgr_rec.entry_desc  :=  IN_trns_desc;
            end if;
    
            if g_lang = 'A' then
                ldgr_rec.memo           := ' حركة رقم '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
            else
                ldgr_rec.memo           := ' Transaction no '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
            end if;
        elsif in_Trns_Post_type = 2 then
            ldgr_rec.entry_desc     := IN_trns_type_desc;
            if g_lang = 'A' then
                ldgr_rec.memo           := ' نوع حركة رقم '||to_char(in_trns_type_code);
            else
            ldgr_rec.memo           := ' Transaction type no '||to_char(in_trns_type_code);
            end if;
        elsif in_Trns_Post_type = 3 then
            if g_lang = 'A' then
                ldgr_rec.entry_desc     := 'قيد مجمع مرحل من المخازن';
            else
                ldgr_rec.entry_desc     := 'Composed record from stores';
            end if;
            ldgr_rec.memo           := null;
        end if ;

    
        If nvl(IN_Account_Ind,0) = 2 Then   --????
            ldgr_rec.TOTAL_value := ((( nvl(c_rec.Items_Total,0)  - 
                                                       NVL(c_rec.Items_Total_DISC,0) - 
                                             NVL(c_rec.DISC_VAL,0) + 
                                             NVL(c_rec.SUPP_COSTS,0) + 
                                             NVL(c_rec.GAMAREK_TAKHLIS_NAKL,0) +
                                                                     NVL(c_rec.BANKIA,0) +
                                   NVL(c_rec.TAMIN,0) +
                                   NVL(c_rec.OKHRA,0) )* ( NVL(V_BROKER_VALUE,0) /(nvl(V_Items_Total_CURR,1)-
                                                NVL(V_DET_DISC,0) -
                                                NVL(V_DISC_VAL,0) + nvl(V_service,0)  )))) * -1;
        --    total_value := total_value - nvl(w_value,0) ;
        else
            ldgr_rec.TOTAL_value := ((( nvl(c_rec.Items_Total,0)  - 
                                                       NVL(c_rec.Items_Total_DISC,0) - 
                                             NVL(c_rec.DISC_VAL,0) + 
                                             NVL(c_rec.SUPP_COSTS,0) + 
                                             NVL(c_rec.GAMAREK_TAKHLIS_NAKL,0) +
                                                                     NVL(c_rec.BANKIA,0) +
                                   NVL(c_rec.TAMIN,0) +
                                   NVL(c_rec.OKHRA,0) )* ( NVL(V_BROKER_VALUE,0) /(nvl(V_Items_Total_CURR,1)-
                                                NVL(V_DET_DISC,0) -
                                                NVL(V_DISC_VAL,0) + nvl(V_service,0)  ))));
        --    total_value := total_value + nvl(w_value,0) ;
        End If;
            
        insert into st_ledger (TRNS_TYPE_CODE,
        TRNS_SERIAL   , 
        VOUCHER_NO    , 
        ACCOUNT_NO    , 
        COST_CODE     ,
        COST_CODE2     ,  
        TOTAL_value   , 
        DOC_NO        , 
        ENTRY_DESC    , 
        MEMO          ,
        MEMO_DET, 
        TRNS_DATE     ,
        entry_type    ,
        post_flag     )
        values(ldgr_rec.TRNS_TYPE_CODE,
        ldgr_rec.TRNS_SERIAL   , 
        ldgr_rec.VOUCHER_NO    , 
        ldgr_rec.ACCOUNT_NO    , 
        ldgr_rec.COST_CODE     ,
        ldgr_rec.COST_CODE2     ,  
        ldgr_rec.TOTAL_value   , 
        ldgr_rec.DOC_NO        , 
        ldgr_rec.ENTRY_DESC    , 
        ldgr_rec.MEMO          , 
        LDGR_REC.MEMO_DET,
        ldgr_rec.TRNS_DATE     ,
        ldgr_rec.entry_type    ,
        ldgr_rec.post_flag );
END IF ;
    END LOOP;
    D_TOT_VAL := total_value;

    RETURN (TRUE );                        
    
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit HANDLE_GROUP (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION HANDLE_GROUP(in_trns_type_code         IN NUMBER,
    in_serial_number          IN NUMBER,
    IN_Entry_No               IN NUMBER,
    IN_Account_No_Type     IN NUMBER,
    IN_Account_No                IN NUMBER,
    IN_cost_No                    IN NUMBER,
    IN_cost_No2                  IN NUMBER,
    IN_Cost_No_Type             IN NUMBER,
    IN_Cost_No2_Type            IN NUMBER,
    IN_Value_Type          IN NUMBER,
    IN_doc_no              IN NUMBER,
    IN_date                IN DATE,
    IN_Account_Ind                IN NUMBER,
    in_Trns_Post_type      IN NUMBER,
    in_entry_type                IN NUMBER,
    IN_trns_desc                  IN VARCHAR2,
    IN_trns_type_desc      IN VARCHAR2,
    IN_REQUEST_NO        IN VARCHAR2,
    IN_REQUEST_NO_E        IN VARCHAR2,
    D_TOT_VAL                        OUT NUMBER ) RETURN BOOLEAN IS
    
    Ldgr_Rec              st_ledger%rowtype;
    w_status                            NUMBER;
    w_value                                NUMBER;
    total_value                        NUMBER:=0;
BEGIN
    FOR GROUP_REC IN (Select                round(Sum((nvl(unit_price,0) - nvl(DISC1_VALUE,0) - nvl(DISC2_VALUE,0) - nvl(DISC3_VALUE,0)) * nvl(quantity,0)),2) Items_total,
                           round(Sum(nvl(unit_price,0) * nvl(quantity,0)),2) Items_SALES_total,
        ROUND(Sum(nvl(DC.unit_cost,0) * nvl(D.basic_qty,0)),2) cost_total,
        ROUND(SUM(NVL(DET_DISC,0) + ((NVL(CURRENCY_RATE,0) * (NVL(DISC1_VALUE,0) + NVL(DISC2_VALUE,0) + NVL(DISC3_VALUE,0))) * NVL(QUANTITY,0) * nvl(FACTOR,1))),2) ITEMS_TOTAL_DISC,
        ROUND(Sum(nvl(DISC,0) * nvl(quantity,0)*nvl(FACTOR,1)),2) DISC_VAL,
        ROUND(SUM((NVL(SUPP_FREIGHT,0)+NVL(SUPP_INSURANCE,0)+NVL(SUPP_OTHERS,0))* nvl(quantity,0)*nvl(FACTOR,1))/*NVL(BASIC_QTY,0)*/,2) SUPP_COSTS,
        ROUND(SUM(NVL(FREIGHT,0)    *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)  GAMAREK_TAKHLIS_NAKL,
        ROUND(SUM(NVL(CUSTOMS,0)    *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)  BANKIA,
        ROUND(SUM(NVL(D.TRANSPORT,0)*  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2) TAMIN,
        ROUND(SUM(NVL(D.OTHERS,0)   *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)   OKHRA,
        s.Account_number,s.cost_code  s_cost,s.cost_code2  s_cost2, m.TRNSFER_TO_STORE,m.cost_code,m.cost_code2,m.store_code
        From         st_trns_det d,ST_TRNS_DET_COST DC,ST_TRNS_MAST M, st_item_group  s,st_trns_type tt,ST_ITEM_UNIT UNT
        Where           D.ITEM_CODE      = UNT.ITEM_CODE
        AND         D.GROUP_CODE     = UNT.GROUP_CODE
        AND         D.UNIT_CODE      = UNT.UNIT_CODE
        AND         d.trns_type_code = M.trns_type_code
        and     tt.trns_type_code = M.trns_type_code
        and         d.trns_serial = M.trns_serial
        AND NVL(M.DELETE_FLAG,0)    = 0
        AND NVL(D.DELETE_FLAG,0)    = 0
        AND         d.trns_type_code = DC.trns_type_code
        and     D.ITEM_SERIAL = DC.ITEM_SERIAL
        and         d.trns_serial = DC.trns_serial
        AND            d.trns_type_code = in_trns_type_code
        and         d.trns_serial = in_serial_number
        and         s.item_group_code     = d.group_code
        Group by     s.Account_number,s.cost_code,s.cost_code2, m.TRNSFER_TO_STORE,m.cost_code,m.cost_code2,m.store_code)
    LOOP 
    
        If IN_Entry_No is not null then
            Ldgr_Rec.Voucher_No := IN_Entry_No;
        end if;

        if IN_Account_No_Type=15 then
            Ldgr_Rec.Account_No:= group_rec.Account_number;
        END IF;
    
        If Ldgr_Rec.Account_No is null Then 
            insert into st_post_msg (trns_type_code,trns_serial,message) 
            values (in_trns_type_code,in_serial_number,
            ' 4رقم الحساب غير موجود ');
            Return (FALSE);
        End If;
    
        begin 
            select account_status
            into w_status
            from ac_master
            where account_number = ldgr_rec.account_no;
        
            if w_status = 0 then
                insert into st_post_msg (trns_type_code,trns_serial,message) 
                values (in_trns_type_code,in_serial_number,
                ' رقم الحساب ليس على أدنى مستوى ');
                return(FALSE);
            end if;
        exception
            when others then      
                insert into st_post_msg (trns_type_code,trns_serial,message) 
                values (in_trns_type_code,in_serial_number,
                ' رقم الحساب ملف المجموعات غير موجود فى نظام الحسابات ');
                return(FALSE);
        end;
    
        if IN_Cost_No_Type=1 then
            Ldgr_Rec.Cost_Code:= IN_Cost_No;
        elsif IN_Cost_No_Type=2 then
            select s.Cost_Code
            into   Ldgr_Rec.Cost_Code
            from   st_store s
            where  s.store_code = group_rec.store_code;
        elsif IN_Cost_No_Type=3 then
            Ldgr_Rec.Cost_Code:= group_rec.cost_code;                                      
        elsif IN_Cost_No_Type=4 then
            Ldgr_Rec.Cost_Code:= group_rec.s_cost;                                                                            
        elsif IN_Cost_No_Type=5 then
            select s.Cost_Code
            into   Ldgr_Rec.Cost_Code
            from   st_store s
            where  s.store_code = group_rec.trnsfer_to_store;
        elsif IN_Cost_No_Type=6 then
            Ldgr_Rec.Cost_Code:= NULL;                                                                                      
        Else                                        
            insert into st_post_msg (trns_type_code,trns_serial,message) 
            values (in_trns_type_code,in_serial_number,
            ' خطأ فى مؤشر رقم مركز التكلفة ');
            Return (FALSE);
        End If;
    
        if IN_Cost_No2_Type=1 then
            Ldgr_Rec.Cost_Code2:= IN_Cost_No2;
        elsif IN_Cost_No2_Type=2 then
            select s.Cost_Code2
            into   Ldgr_Rec.Cost_Code2
            from   st_store s
            where  s.store_code = group_rec.store_code;
        elsif IN_Cost_No2_Type=3 then
            Ldgr_Rec.Cost_Code2:= group_rec.cost_code2;                                      
        elsif IN_Cost_No2_Type=2 then
            Ldgr_Rec.Cost_Code2:= group_rec.s_cost2;                                      
        elsif IN_Cost_No_Type=5 then
            select s.Cost_Code2
            into   Ldgr_Rec.Cost_Code2
            from   st_store s
            where  s.store_code = group_rec.trnsfer_to_store;
      Elsif IN_Cost_No2_Type=4 then
                                         Ldgr_Rec.Cost_Code2:= group_rec.COST_CODE2;     
        elsif IN_Cost_No2_Type=6 then
            Ldgr_Rec.Cost_Code2:= NULL;                                      
        Else    
            insert into st_post_msg (trns_type_code,trns_serial,message) 
            values (in_trns_type_code,in_serial_number,
            '2 خطأ فى مؤشر ملف المجموعة رقم مركز التكلفة ');
            Return (FALSE);
        End If; 
    
    
        IF CHECK_COST_CENTERS(in_trns_type_code,in_serial_number,
            ldgr_rec.cost_code,ldgr_rec.cost_code2)= FALSE THEN 
            RETURN (FALSE);
        END IF;
    
        If nvl(IN_Value_Type,0)=1 then
            w_value := nvl(group_rec.Items_Total,0);
        Elsif nvl(IN_Value_Type,0)=5 then
            w_value := NVL(group_REC.Items_Total_DISC,0)+ NVL(group_REC.DISC_VAL,0);
        Elsif nvl(IN_Value_Type,0)=35 then
      w_value := NVL(GROUP_REC.Items_SALES_total,0);
    Elsif nvl(IN_Value_Type,0)=36 then
      w_value := NVL(GROUP_REC.Items_Total_DISC,0);
    Elsif nvl(IN_Value_Type,0)=37 then
      w_value := NVL(GROUP_REC.DISC_VAL,0);
        Elsif nvl(IN_Value_Type,0)=2 then
            w_value := nvl(group_rec.Items_Total,0) - 
            NVL(group_REC.Items_Total_DISC,0) -
            NVL(group_REC.DISC_VAL,0) + 
            NVL(group_REC.SUPP_COSTS,0) + 
            NVL(group_REC.GAMAREK_TAKHLIS_NAKL,0) +
            NVL(group_REC.BANKIA,0) +
            NVL(group_REC.TAMIN,0) +
            NVL(group_REC.OKHRA,0);
        Elsif nvl(IN_Value_Type,0)=12 then
            w_value := nvl(group_rec.Items_Total,0) - 
            NVL(group_REC.Items_Total_DISC,0) -
            NVL(group_REC.DISC_VAL,0) + 
            NVL(group_REC.SUPP_COSTS,0);
        Elsif nvl(IN_Value_Type,0)=4 then
            w_value := NVL(group_REC.GAMAREK_TAKHLIS_NAKL,0);
        Elsif nvl(IN_Value_Type,0)=6 then
            w_value := NVL(group_REC.BANKIA,0);
        Elsif nvl(IN_Value_Type,0)=7 then
            w_value := NVL(group_REC.TAMIN,0);
        Elsif nvl(IN_Value_Type,0)=10 then
            w_value := NVL(group_REC.OKHRA,0);                                   
        Elsif nvl(IN_Value_Type,0)=3 then
            w_value := nvl(group_rec.cost_Total,0);                          
        Else
            insert into st_post_msg (trns_type_code,trns_serial,message) 
            values (in_trns_type_code,in_serial_number,
            ' خطأ فى مؤشر القيمة ');
            Return (FALSE);
        End If;               
    
        If nvl(IN_Account_Ind,0) = 2 Then   --دائن
            ldgr_rec.TOTAL_value := nvl(w_value,0) * -1;
            total_value := total_value - nvl(w_value,0) ;
        else
            ldgr_rec.TOTAL_value := nvl(w_value,0);
            total_value := total_value + nvl(w_value,0) ;
        End If;

        ldgr_rec.doc_no    := IN_doc_no ;
        ldgr_rec.trns_date := IN_date   ;
        ldgr_rec.trns_type_code := in_trns_type_code ;
        ldgr_rec.trns_serial    := in_serial_number  ;                           
        ldgr_rec.post_flag      := in_Trns_Post_type;                            
        ldgr_rec.entry_type     := in_entry_type;

        if in_Trns_Post_type = 1 then
            if IN_trns_desc is null then
                ldgr_rec.entry_desc  :=  IN_trns_type_desc;
            else 
                ldgr_rec.entry_desc  :=  IN_trns_desc;
            end if;
    
            if g_lang = 'A' then
                ldgr_rec.memo           := ' حركة رقم '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
            else
                ldgr_rec.memo           := ' Transaction no '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
            end if;
        elsif in_Trns_Post_type = 2 then
            ldgr_rec.entry_desc     := IN_trns_type_desc;
            if g_lang = 'A' then
                ldgr_rec.memo           := ' نوع حركة رقم '||to_char(in_trns_type_code);
            else
            ldgr_rec.memo           := ' Transaction type no '||to_char(in_trns_type_code);
            end if;
        elsif in_Trns_Post_type = 3 then
            if g_lang = 'A' then
                ldgr_rec.entry_desc     := 'قيد مجمع مرحل من المخازن';
            else
                ldgr_rec.entry_desc     := 'Composed record from stores';
            end if;
            ldgr_rec.memo           := null;
        end if ;
        
        insert into st_ledger (TRNS_TYPE_CODE,
        TRNS_SERIAL   , 
        VOUCHER_NO    , 
        ACCOUNT_NO    , 
        COST_CODE     ,
        COST_CODE2     ,  
        TOTAL_value   , 
        DOC_NO        , 
        ENTRY_DESC    , 
        MEMO          ,
        MEMO_DET, 
        TRNS_DATE     ,
        entry_type    ,
        post_flag     )
        values(ldgr_rec.TRNS_TYPE_CODE,
        ldgr_rec.TRNS_SERIAL   , 
        ldgr_rec.VOUCHER_NO    , 
        ldgr_rec.ACCOUNT_NO    , 
        ldgr_rec.COST_CODE     ,
        ldgr_rec.COST_CODE2     ,  
        ldgr_rec.TOTAL_value   , 
        ldgr_rec.DOC_NO        , 
        ldgr_rec.ENTRY_DESC    , 
        ldgr_rec.MEMO          , 
        LDGR_REC.MEMO_DET,
        ldgr_rec.TRNS_DATE     ,
        ldgr_rec.entry_type    ,
        ldgr_rec.post_flag );
    END LOOP;
    D_TOT_VAL := total_value;
    RETURN (TRUE );                        
    
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit HANDLE_GROUP_1 (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION HANDLE_GROUP_1(in_trns_type_code         IN NUMBER,
                                             in_serial_number          IN NUMBER,
                                             IN_Entry_No               IN NUMBER,
                                             IN_Account_No_Type     IN NUMBER,
                                             IN_Account_No                 IN NUMBER,
                                             IN_Cost_No_Type             IN NUMBER,
                                             IN_Cost_No2_Type            IN NUMBER,
                                             IN_Value_Type          IN NUMBER,
                                             IN_doc_no              IN NUMBER,
                                             IN_date                IN DATE,
                                             IN_Account_Ind                IN NUMBER,
                                             in_Trns_Post_type      IN NUMBER,
                                             in_entry_type                IN NUMBER,
                                             IN_trns_desc                  IN VARCHAR2,
                                             IN_trns_type_desc      IN VARCHAR2,
                                             IN_REQUEST_NO        IN VARCHAR2,
                                             IN_REQUEST_NO_E      IN VARCHAR2,
                                             D_TOT_VAL                        OUT NUMBER) RETURN BOOLEAN IS
        
        Ldgr_Rec              st_ledger%rowtype;
        w_status                            NUMBER;
        w_value                                NUMBER;
        total_value                        NUMBER:=0;
        
BEGIN
  FOR GROUP_REC IN (Select round(Sum((nvl(unit_price,0) - nvl(DISC1_VALUE,0) - nvl(DISC2_VALUE,0) - nvl(DISC3_VALUE,0)) * nvl(quantity,0)),2) Items_total,
                           round(Sum(nvl(unit_price,0) * nvl(quantity,0)),2) Items_SALES_total,
                                                                                     Sum(nvl(DC.unit_cost,0) * nvl(D.basic_qty,0)) cost_total,
                                                                                   --ROUND(Sum(nvl(det_disc,0) * nvl(quantity,0)*nvl(FACTOR,1)),2) Items_total_DISC,
                                                                                     --ROUND(Sum(nvl(DISC,0) * nvl(quantity,0)*nvl(FACTOR,1)),2) DISC_VAL,
                                                                                     ROUND(SUM(NVL(DET_DISC,0) + ((NVL(CURRENCY_RATE,0) * (NVL(DISC1_VALUE,0) + NVL(DISC2_VALUE,0) + NVL(DISC3_VALUE,0))) * NVL(QUANTITY,0) * nvl(FACTOR,1))),2) ITEMS_TOTAL_DISC ,     /*  ADDED BY AHMED AMIN */                                                                                      
                                                                                     ROUND(nvl(DISC_VAL,0) + nvl(TOT_DISC1_VALUE,0) + nvl(TOT_DISC2_VALUE,0) + nvl(TOT_DISC3_VALUE,0),2) DISC_VAL ,     /*  ADDED BY AHMED AMIN */                                                                                      
                                                                                     ROUND(SUM((NVL(SUPP_FREIGHT,0)+NVL(SUPP_INSURANCE,0)+NVL(SUPP_OTHERS,0))* nvl(quantity,0)*nvl(FACTOR,1))/*NVL(BASIC_QTY,0)*/,2) SUPP_COSTS,
                                                                                     ROUND(SUM(NVL(FREIGHT,0)    *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)  GAMAREK_TAKHLIS_NAKL,
                                                                                     ROUND(SUM(NVL(CUSTOMS,0)    *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)  CUSTOMS,
                                                                                     ROUND(SUM(NVL(D.TRANSPORT,0)*  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2) TRANSPORT,
                                                                                     ROUND(SUM(NVL(D.OTHERS,0)   *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)   OKHRA,
                                                                                     ROUND(SUM(NVL(D.INSURANCE,0) *  nvl(quantity,0)*nvl(FACTOR,1)),2)   INSURANCE,
                                                                                     ROUND(SUM(NVL(D.COMMISSION,0)*  nvl(quantity,0)*nvl(FACTOR,1)),2)   COMMISSION,                                                                                     
                                                                                     G.COST_CODE,G.COST_CODE2
                                                                    From         st_trns_det d, ST_TRNS_DET_COST DC ,ST_TRNS_MAST M, ST_ITEM_GROUP  G,st_trns_type tt,ST_ITEM_UNIT UNT
                                                                  Where           D.ITEM_CODE      = UNT.ITEM_CODE
                                                                  AND         D.GROUP_CODE     = UNT.GROUP_CODE
                                                                  AND         D.UNIT_CODE      = UNT.UNIT_CODE
                                                                  AND         d.trns_type_code = M.trns_type_code
                                                                    and     tt.trns_type_code = M.trns_type_code
                                                                    and         d.trns_serial = M.trns_serial
                                                                    AND NVL(M.DELETE_FLAG,0)    = 0
                                                                    AND NVL(D.DELETE_FLAG,0)    = 0
                                                                    AND         d.trns_type_code = DC.trns_type_code
                                                                    and     D.ITEM_SERIAL = DC.ITEM_SERIAL
                                                                    and         d.trns_serial = DC.trns_serial
                                                                    AND            d.trns_type_code = in_trns_type_code
                                                                    and         d.trns_serial = in_serial_number
                                                                    and         G.ITEM_GROUP_CODE  = d.GROUP_CODE
                                                                    Group by     G.COST_CODE,G.COST_CODE2 , DISC_VAL + TOT_DISC1_VALUE + TOT_DISC2_VALUE + TOT_DISC3_VALUE )LOOP 
                            
                            ldgr_rec.cost_code    :=    GROUP_REC.COST_CODE;
                            ldgr_rec.cost_code2    :=    GROUP_REC.COST_CODE2;
                            
                            If IN_Entry_No is not null then
                                   Ldgr_Rec.Voucher_No := IN_Entry_No;
                            end if;                                                                        
                                        
                               IF CHECK_COST_CENTERS(in_trns_type_code,in_serial_number,
                                                                    ldgr_rec.cost_code,ldgr_rec.cost_code2)= FALSE THEN 
                                                    RETURN (FALSE);
                                        END IF;

                                        If nvl(IN_Value_Type,0)=1 then
                                  w_value := nvl(GROUP_REC.Items_Total,0);
                             ------------------------------------------------ 
                           -- BY ME                                          
                          Elsif nvl(IN_Value_Type,0)=5 then
                          w_value := NVL(GROUP_REC.Items_Total_DISC,0)+ NVL(GROUP_REC.DISC_VAL,0);
                    Elsif nvl(IN_Value_Type,0)=35 then
                          w_value := NVL(GROUP_REC.Items_SALES_total,0);
                    Elsif nvl(IN_Value_Type,0)=36 then
                          w_value := NVL(GROUP_REC.Items_Total_DISC,0);
                    Elsif nvl(IN_Value_Type,0)=37 then
                          w_value := NVL(GROUP_REC.DISC_VAL,0);
                          Elsif nvl(IN_Value_Type,0)=2 then                            
                                  w_value := nvl(GROUP_REC.Items_Total,0) - 
                                                       NVL(GROUP_REC.Items_Total_DISC,0) -
                                             NVL(GROUP_REC.DISC_VAL,0) + 
                                             NVL(GROUP_REC.SUPP_COSTS,0) + 
                                             NVL(GROUP_REC.GAMAREK_TAKHLIS_NAKL,0) +
                                                                     NVL(GROUP_REC.CUSTOMS,0) +
                                   NVL(GROUP_REC.TRANSPORT,0) +
                                   NVL(GROUP_REC.OKHRA,0)+ NVL(GROUP_REC.COMMISSION,0) + NVL(GROUP_REC.INSURANCE,0) ;
                                   
                          Elsif nvl(IN_Value_Type,0)=12 then
                                  w_value := nvl(GROUP_rec.Items_Total,0) - 
                                             NVL(GROUP_REC.Items_Total_DISC,0) -
                                             NVL(GROUP_REC.DISC_VAL,0) + 
                                             NVL(GROUP_REC.SUPP_COSTS,0);
                                             
                        Elsif nvl(IN_Value_Type,0)=4 then
                                  w_value := NVL(GROUP_REC.GAMAREK_TAKHLIS_NAKL,0);
                          
                          Elsif nvl(IN_Value_Type,0)=6 then
                                  w_value := NVL(GROUP_REC.CUSTOMS,0);
                          
                          Elsif nvl(IN_Value_Type,0)=7 then
                                  w_value := NVL(GROUP_REC.INSURANCE,0);

                          Elsif nvl(IN_Value_Type,0)= 16 then
                                  w_value := NVL(GROUP_REC.TRANSPORT,0);
                                                            
                          Elsif nvl(IN_Value_Type,0)=10 then
                                  w_value := NVL(GROUP_REC.OKHRA,0);  

                          Elsif nvl(IN_Value_Type,0)= 9  then
                                  w_value := NVL(GROUP_REC.COMMISSION,0);                                                                   
                             ------------------------------------------------ 
                            
                            Elsif nvl(IN_Value_Type,0)=3 then
                                  w_value := nvl(GROUP_REC.cost_Total,0);
                            Else
                                   insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                   values (in_trns_type_code,in_serial_number,
                                               ' خطأ فى مؤشر القيمة ');
                                        Return (FALSE);
                            End If;               

                            If nvl(IN_Account_Ind,0) = 2 Then   --دائن
                                   ldgr_rec.TOTAL_value := nvl(w_value,0) * -1;
                                   total_value := total_value - nvl(w_value,0) ;
                            else
                                   ldgr_rec.TOTAL_value := nvl(w_value,0);
                                   total_value := total_value + nvl(w_value,0) ;
                            End If;
              
                -- Construct The ST_LEDGER Record

                            ldgr_rec.doc_no    := IN_doc_no ;
                            ldgr_rec.trns_date := IN_date   ;
                            ldgr_rec.trns_type_code := in_trns_type_code ;
                            ldgr_rec.trns_serial    := in_serial_number  ;
                            ldgr_rec.post_flag      := in_Trns_Post_type;
                            ldgr_rec.entry_type     := in_entry_type;

                            if in_Trns_Post_type = 1 then
                                if IN_trns_desc is null then
                                    ldgr_rec.entry_desc  :=  IN_trns_type_desc;
                                 else 
                                    ldgr_rec.entry_desc  :=  IN_trns_desc;
                                 end if;
                                             if g_lang = 'A' then
                                         ldgr_rec.memo           := ' حركة رقم '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
                                                else
                                         ldgr_rec.memo           := ' Transaction no '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
                                                end if;
                            elsif in_Trns_Post_type = 2 then
                                ldgr_rec.entry_desc     := IN_trns_type_desc;
                                                if g_lang = 'A' then
                                         ldgr_rec.memo           := ' نوع حركة رقم '||to_char(in_trns_type_code);
                                                else
                                         ldgr_rec.memo           := ' Transaction type no '||to_char(in_trns_type_code);
                                                end if;
                            elsif in_Trns_Post_type = 3 then
                                                if g_lang = 'A' then
                                         ldgr_rec.entry_desc     := 'قيد مفصل بمراكز تكلفة المجموعات';
                                                else
                                         ldgr_rec.entry_desc     := 'Detailed record from groups cost centers';
                                                end if;
                                 ldgr_rec.memo           := null;
                            end if ;

--message('group ldgr_rec.TOTAL_value = ' ||  ldgr_rec.TOTAL_value || '  total_value= ' ||  total_value ); pause; 
                      insert into st_ledger (TRNS_TYPE_CODE,
                                                       TRNS_SERIAL   , 
                                                       VOUCHER_NO    , 
                                                       ACCOUNT_NO    , 
                                                       COST_CODE     , 
                                                       COST_CODE2    , 
                                                       TOTAL_value   , 
                                                       DOC_NO        , 
                                                       ENTRY_DESC    , 
                                                       MEMO          , 
                                                       MEMO_DET,
                                                       TRNS_DATE     ,
                                                       entry_type    ,
                                                       post_flag     )
                                                values(ldgr_rec.TRNS_TYPE_CODE,
                                                       ldgr_rec.TRNS_SERIAL   , 
                                                       ldgr_rec.VOUCHER_NO    , 
                                                       IN_Account_No                    ,
                                                       ldgr_rec.COST_CODE     ,
                                                                                     ldgr_rec.COST_CODE2    ,  
                                                       ldgr_rec.TOTAL_value   , 
                                                       ldgr_rec.DOC_NO        , 
                                                       ldgr_rec.ENTRY_DESC    , 
                                                       ldgr_rec.MEMO          , 
                                                       LDGR_REC.MEMO_DET,
                                                       ldgr_rec.TRNS_DATE     ,
                                                       ldgr_rec.entry_type    ,
                                                       ldgr_rec.post_flag );
                END LOOP;
                D_TOT_VAL := total_value;                        
                RETURN(TRUE);
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit HANDLE_GROUP_2 (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION HANDLE_GROUP_2(in_trns_type_code         IN NUMBER,
                                             in_serial_number          IN NUMBER,
                                             IN_Entry_No               IN NUMBER,
                                             IN_Account_No_Type     IN NUMBER,
                                             IN_Account_No                 IN NUMBER,
                                             IN_Cost_No_Type             IN NUMBER,
                                             IN_Cost_No2_Type            IN NUMBER,
                                             IN_Value_Type          IN NUMBER,
                                             IN_doc_no              IN NUMBER,
                                             IN_date                IN DATE,
                                             IN_Account_Ind                IN NUMBER,
                                             in_Trns_Post_type      IN NUMBER,
                                             in_entry_type                IN NUMBER,
                                             IN_trns_desc                  IN VARCHAR2,
                                             IN_trns_type_desc      IN VARCHAR2,
                                             IN_REQUEST_NO        IN VARCHAR2,
                                             IN_REQUEST_NO_E      IN VARCHAR2,
                                             IN_Cost_No2                    IN NUMBER,
                                             IN_cost2                            IN NUMBER,
                                             D_TOT_VAL                        OUT NUMBER) RETURN BOOLEAN IS 
        
        Ldgr_Rec              st_ledger%rowtype;
        w_status                            NUMBER;
        w_value                                NUMBER;
        total_value                        NUMBER:=0;
        

BEGIN
  FOR GROUP_REC IN (Select     round(Sum((nvl(unit_price,0) - nvl(DISC1_VALUE,0) - nvl(DISC2_VALUE,0) - nvl(DISC3_VALUE,0)) * nvl(quantity,0)),2) Items_total,
                            round(Sum(nvl(unit_price,0) * nvl(quantity,0)),2) Items_SALES_total,
                                                                                     Sum(nvl(DC.unit_cost,0) * nvl(D.basic_qty,0)) cost_total,
                                                 --    ROUND(Sum(nvl(det_disc,0) * nvl(quantity,0)*nvl(FACTOR,1)),2) Items_total_DISC,
                                                                                 --    ROUND(Sum(nvl(DISC,0) * nvl(quantity,0)*nvl(FACTOR,1)),2) DISC_VAL,
                                                                                     ROUND(SUM(NVL(DET_DISC,0) + ((NVL(CURRENCY_RATE,0) * (NVL(DISC1_VALUE,0) + NVL(DISC2_VALUE,0) + NVL(DISC3_VALUE,0))) * NVL(QUANTITY,0) * nvl(FACTOR,1))),2) ITEMS_TOTAL_DISC ,     /*  ADDED BY AHMED AMIN */                                                                                      
                                                                                     ROUND(nvl(DISC_VAL,0) + nvl(TOT_DISC1_VALUE,0) + nvl(TOT_DISC2_VALUE,0) + nvl(TOT_DISC3_VALUE,0),2) DISC_VAL ,     /*  ADDED BY AHMED AMIN */                                                                      
                                                                                     ROUND(SUM((NVL(SUPP_FREIGHT,0)+NVL(SUPP_INSURANCE,0)+NVL(SUPP_OTHERS,0))* nvl(quantity,0)*nvl(FACTOR,1))/*NVL(BASIC_QTY,0)*/,2) SUPP_COSTS,
                                                                                     ROUND(SUM(NVL(FREIGHT,0)    *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)  GAMAREK_TAKHLIS_NAKL,
                                                                                     ROUND(SUM(NVL(CUSTOMS,0)    *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)  CUSTOMS,
                                                                                     ROUND(SUM(NVL(D.TRANSPORT,0)*  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2) TRANSPORT,
                                                                                     ROUND(SUM(NVL(D.OTHERS,0)   *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)   OKHRA,
                                                                                     ROUND(SUM(NVL(D.INSURANCE,0)   *  nvl(quantity,0)*nvl(FACTOR,1)),2)   INSURANCE,
                                                                                     ROUND(SUM(NVL(D.COMMISSION,0)   *  nvl(quantity,0)*nvl(FACTOR,1)),2)   COMMISSION,                                                                                     
                                                                                     G.COST_CODE2 COST_CODE
                                                                    From         st_trns_det d, ST_TRNS_DET_COST DC,ST_TRNS_MAST M, ST_ITEM_GROUP  G,st_trns_type tt,ST_ITEM_UNIT UNT
                                                                  Where           D.ITEM_CODE      = UNT.ITEM_CODE
                                                                  AND         D.GROUP_CODE     = UNT.GROUP_CODE
                                                                  AND         D.UNIT_CODE      = UNT.UNIT_CODE
                                                                  AND         d.trns_type_code = M.trns_type_code
                                                                    and         d.trns_serial = M.trns_serial
                                                                    AND NVL(M.DELETE_FLAG,0)    = 0
                                                                    AND NVL(D.DELETE_FLAG,0)    = 0
                                                                    AND         d.trns_type_code = DC.trns_type_code
                                                                    and         d.trns_serial = DC.trns_serial
                                                                    AND     D.ITEM_SERIAL = DC.ITEM_SERIAL
                                                                    and     tt.trns_type_code = M.trns_type_code
                                                                    AND         d.trns_type_code = in_trns_type_code
                                                                    and         d.trns_serial = in_serial_number
                                                                    and         G.ITEM_GROUP_CODE  = d.GROUP_CODE
                                                                    Group by     G.COST_CODE2 , DISC_VAL + TOT_DISC1_VALUE + TOT_DISC2_VALUE + TOT_DISC3_VALUE)LOOP 
                            
                            ldgr_rec.cost_code    :=    GROUP_REC.COST_CODE;
                            If IN_Cost_No2_Type=1 then
                                            Ldgr_Rec.Cost_code2:= IN_Cost_No2;
                            Elsif IN_Cost_No2_Type=2 then
                                                    select m.cost_code2
                                                    into Ldgr_Rec.Cost_Code2
                                                    from st_trns_mast m,st_store s
                                                    where m.trns_type_code=in_trns_type_code
                                                    and   m.trns_serial= in_serial_number  
                                                    and   m.store_code=s.store_code;
                                                    --Ldgr_Rec.Cost_Code2:= s_cost;
                                  Elsif IN_Cost_No2_Type=3 then
                                         Ldgr_Rec.Cost_Code2:= IN_cost2;
                                        Elsif IN_Cost_No2_Type=4 then
                                         Ldgr_Rec.Cost_Code2:= GROUP_REC.COST_CODE;
                               elsif IN_Cost_No2_Type=6 then
                                                Ldgr_Rec.Cost_Code2:= NULL;                                                  
                                        Else

                                   insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                   values (in_trns_type_code,in_serial_number,
                                                             '2 خطأ فى مؤشر ملف المجموعات رقم مركز التكلفة ');
                                        Return (FALSE);           
                                End If; 
                            
                            If IN_Entry_No is not null then
                                   Ldgr_Rec.Voucher_No := IN_Entry_No;
                            end if;                                                                        
                                        
                IF CHECK_COST_CENTERS(in_trns_type_code,in_serial_number,
                                                                    ldgr_rec.cost_code,ldgr_rec.cost_code2)= FALSE THEN 
                                            RETURN (FALSE);
                        END IF;

--MESSAGE('Link_Rec.Value_Type= '|| Link_Rec.Value_Type); PAUSE; 
                                        If nvl(IN_Value_Type,0)=1 then
                                  w_value := nvl(GROUP_REC.Items_Total,0);
                           ------------------------------------------------ 
                           -- BY ME                                                      
                          Elsif nvl(IN_Value_Type,0)=5 then
                          w_value := NVL(GROUP_REC.Items_Total_DISC,0)+ NVL(GROUP_REC.DISC_VAL,0);
                    Elsif nvl(IN_Value_Type,0)=35 then
                          w_value := NVL(GROUP_REC.Items_SALES_total,0);
                    Elsif nvl(IN_Value_Type,0)=36 then
                          w_value := NVL(GROUP_REC.Items_Total_DISC,0);
                    Elsif nvl(IN_Value_Type,0)=37 then
                          w_value := NVL(GROUP_REC.DISC_VAL,0);
                          Elsif nvl(IN_Value_Type,0)=2 then
                                  w_value := nvl(GROUP_REC.Items_Total,0) - 
                                             NVL(GROUP_REC.Items_Total_DISC,0) -
                                             NVL(GROUP_REC.DISC_VAL,0) + 
                                             NVL(GROUP_REC.SUPP_COSTS,0) + 
                                             NVL(GROUP_REC.GAMAREK_TAKHLIS_NAKL,0) +
                                                                     NVL(GROUP_REC.CUSTOMS,0) +
                                   NVL(GROUP_REC.TRANSPORT,0) + NVL(GROUP_REC.INSURANCE,0) + NVL(GROUP_REC.COMMISSION,0) +
                                   NVL(GROUP_REC.OKHRA,0);
                                   
                          Elsif nvl(IN_Value_Type,0)=12 then
                                  w_value := nvl(GROUP_rec.Items_Total,0) -
                                             NVL(GROUP_REC.Items_Total_DISC,0) - 
                                             NVL(GROUP_REC.DISC_VAL,0) + 
                                             NVL(GROUP_REC.SUPP_COSTS,0);
                                             
                        Elsif nvl(IN_Value_Type,0)=4 then
                                  w_value := NVL(GROUP_REC.GAMAREK_TAKHLIS_NAKL,0);
                          
                          Elsif nvl(IN_Value_Type,0)=6 then
                                  w_value := NVL(GROUP_REC.CUSTOMS,0);
                          
                          Elsif nvl(IN_Value_Type,0)=7 then
                                  w_value := NVL(GROUP_REC.INSURANCE,0);
                          
                          Elsif nvl(IN_Value_Type,0)= 16 then
                                  w_value := NVL(GROUP_REC.TRANSPORT,0);
                          
                          Elsif nvl(IN_Value_Type,0)= 9 then
                                  w_value := NVL(GROUP_REC.COMMISSION,0);  
                                                          
                          Elsif nvl(IN_Value_Type,0)=10 then
                                  w_value := NVL(GROUP_REC.OKHRA,0);                                   
                             ------------------------------------------------ 
                            Elsif nvl(IN_Value_Type,0)=3 then
                                  w_value := nvl(GROUP_REC.cost_Total,0);
                            Else
                                   insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                   values (in_trns_type_code,in_serial_number,
                                               ' خطأ فى مؤشر القيمة ');
                                        Return (FALSE);
                            End If;               
--MESSAGE('w_value= '|| w_value); PAUSE; 

                            If nvl(IN_Account_Ind,0) = 2 Then   --دائن
                                   ldgr_rec.TOTAL_value := nvl(w_value,0) * -1;
                                   total_value := total_value - nvl(w_value,0) ;
                            else
                                   ldgr_rec.TOTAL_value := nvl(w_value,0);
                                   total_value := total_value + nvl(w_value,0) ;
                            End If;
              
                -- Construct The ST_LEDGER Record

                            ldgr_rec.doc_no    := IN_doc_no ;
                            ldgr_rec.trns_date := IN_date   ;
                            ldgr_rec.trns_type_code := in_trns_type_code ;
                            ldgr_rec.trns_serial    := in_serial_number  ;
                            ldgr_rec.post_flag      := in_Trns_Post_type;
                            ldgr_rec.entry_type     := in_entry_type;

                            if in_Trns_Post_type = 1 then
                                if IN_trns_desc is null then
                                    ldgr_rec.entry_desc  :=  IN_trns_type_desc;
                                 else 
                                    ldgr_rec.entry_desc  :=  IN_trns_desc;
                                 end if;
                                             if g_lang = 'A' then
                                         ldgr_rec.memo           := ' حركة رقم '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
                                                else
                                         ldgr_rec.memo           := ' Transaction no '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
                                                end if;
                            elsif in_Trns_Post_type = 2 then
                                ldgr_rec.entry_desc     := IN_trns_type_desc;
                                                if g_lang = 'A' then
                                         ldgr_rec.memo           := ' نوع حركة رقم '||to_char(in_trns_type_code);
                                                else
                                         ldgr_rec.memo           := ' Transaction type no '||to_char(in_trns_type_code);
                                                end if;
                            elsif in_Trns_Post_type = 3 then
                                                if g_lang = 'A' then
                                         ldgr_rec.entry_desc     := 'قيد مفصل بمراكز تكلفة المجموعات';
                                                else
                                         ldgr_rec.entry_desc     := 'Detailed record from groups cost centers';
                                                end if;
                                 ldgr_rec.memo           := null;
                            end if ;
                            
                        
--message('group 2 ldgr_rec.TOTAL_value = ' ||  ldgr_rec.TOTAL_value || '  total_value= ' ||  total_value ); pause; 
                                insert into st_ledger (TRNS_TYPE_CODE,
                                                       TRNS_SERIAL   , 
                                                       VOUCHER_NO    , 
                                                       ACCOUNT_NO    , 
                                                       COST_CODE     , 
                                                       COST_CODE2     , 
                                                       TOTAL_value   , 
                                                       DOC_NO        , 
                                                       ENTRY_DESC    , 
                                                       MEMO          , 
                                                       MEMO_DET,
                                                       TRNS_DATE     ,
                                                       entry_type    ,
                                                       post_flag     )
                                                values(ldgr_rec.TRNS_TYPE_CODE,
                                                       ldgr_rec.TRNS_SERIAL   , 
                                                       ldgr_rec.VOUCHER_NO    , 
                                                       IN_Account_No                     , 
                                                       ldgr_rec.COST_CODE     ,
                                                                                     ldgr_rec.COST_CODE2    ,  
                                                       ldgr_rec.TOTAL_value   , 
                                                       ldgr_rec.DOC_NO        , 
                                                       ldgr_rec.ENTRY_DESC    , 
                                                       ldgr_rec.MEMO          , 
                                                       LDGR_REC.MEMO_DET ,
                                                       ldgr_rec.TRNS_DATE     ,
                                                       ldgr_rec.entry_type    ,
                                                       ldgr_rec.post_flag );
                END LOOP;
                D_TOT_VAL := total_value;                        
                RETURN(TRUE);                
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit HANDLE_GROUP_3 (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION HANDLE_GROUP_3(in_trns_type_code         IN NUMBER,
                                             in_serial_number          IN NUMBER,
                                             IN_Entry_No               IN NUMBER,
                                             IN_Account_No_Type     IN NUMBER,
                                             IN_Account_No                 IN NUMBER,
                                             IN_Cost_No_Type             IN NUMBER,
                                             IN_Cost_No2_Type            IN NUMBER,
                                             IN_Value_Type          IN NUMBER,
                                             IN_doc_no              IN NUMBER,
                                             IN_date                IN DATE,
                                             IN_Account_Ind                IN NUMBER,
                                             in_Trns_Post_type      IN NUMBER,
                                             in_entry_type                IN NUMBER,
                                             IN_trns_desc                  IN VARCHAR2,
                                             IN_trns_type_desc      IN VARCHAR2,
                                             IN_REQUEST_NO        IN VARCHAR2,
                                             IN_REQUEST_NO_E      IN VARCHAR2,
                                             IN_Cost_No                        IN NUMBER,
                                             IN_cost                            IN NUMBER,
                                             D_TOT_VAL                        OUT NUMBER) RETURN BOOLEAN IS 
        
        Ldgr_Rec              st_ledger%rowtype;
        w_status                            NUMBER;
        w_value                                NUMBER;
        total_value                        NUMBER:=0;
    V_BROKER_VALUE NUMBER ;
    V_ITEMS_TOTAL_CURR NUMBER ;
    V_DET_DISC      NUMBER ; 
    V_DISC_VAL       NUMBER ;
    V_SERVICE        NUMBER;        
BEGIN  


-----------------BROKER----------------------------------    
BEGIN
     SELECT SUM (NVL (UNIT_PRICE, 0) * NVL (QUANTITY, 0)) ITEMS_TOTAL_CURR,
            ROUND (SUM (NVL (DET_DISC, 0)), 2) ITEMS_TOTAL_DISC,
            NVL (DISC_VAL, 0) DISC_VAL
       INTO V_ITEMS_TOTAL_CURR, V_DET_DISC, V_DISC_VAL
       FROM ST_TRNS_MAST M, ST_TRNS_DET D
      WHERE     M.TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
            AND M.TRNS_SERIAL = IN_SERIAL_NUMBER
            AND NVL (M.DELETE_FLAG, 0) = 0
            AND NVL(D.DELETE_FLAG,0)    = 0
            AND D.TRNS_TYPE_CODE(+) = M.TRNS_TYPE_CODE
            AND D.TRNS_SERIAL(+) = M.TRNS_SERIAL
   GROUP BY NVL (DISC_VAL, 0);
EXCEPTION
   WHEN OTHERS
   THEN
      NULL;
END;

BEGIN
   SELECT NVL (ROUND (SUM (NVL (SERVICE_COST, 0) * NVL (UNITS_NO, 0)), 2), 0)
     INTO V_SERVICE
     FROM ST_TRNS_MAST M, ST_TRNS_SERVICES D
    WHERE     D.TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
          AND D.TRNS_SERIAL = IN_SERIAL_NUMBER
          AND NVL (M.DELETE_FLAG, 0) = 0
          AND D.TRNS_TYPE_CODE = M.TRNS_TYPE_CODE
          AND D.TRNS_SERIAL = M.TRNS_SERIAL;
EXCEPTION
   WHEN OTHERS
   THEN
      NULL;
END;

BEGIN
   SELECT NVL (BROKER_VALUE, 0)                     /** NVL(CURRENCY_RATE,1)*/
     INTO V_BROKER_VALUE
     FROM ST_TRNS_MAST
    WHERE     TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
          AND TRNS_SERIAL = IN_SERIAL_NUMBER;
EXCEPTION
   WHEN OTHERS
   THEN
      NULL;
END;
-----------------BROKER----------------------------------                                                                           
  FOR GROUP_REC IN (Select     round(Sum((nvl(unit_price,0) - nvl(DISC1_VALUE,0) - nvl(DISC2_VALUE,0) - nvl(DISC3_VALUE,0)) * nvl(quantity,0)),2) Items_total,
                            round(Sum(nvl(unit_price,0) * nvl(quantity,0)),2) Items_SALES_total,
                                                                                     Sum(nvl(DC.unit_cost,0) * nvl(D.basic_qty,0)) cost_total,
                                                                                     --ROUND(Sum(nvl(det_disc,0) * nvl(quantity,0)*nvl(FACTOR,1)),2) Items_total_DISC,
                                                                                     --ROUND(Sum(nvl(DISC,0) * nvl(quantity,0)*nvl(FACTOR,1)),2) DISC_VAL,
                                                                                   ROUND(SUM(NVL(DET_DISC,0) + ((NVL(CURRENCY_RATE,0) * (NVL(DISC1_VALUE,0) + NVL(DISC2_VALUE,0) + NVL(DISC3_VALUE,0))) * NVL(QUANTITY,0) * nvl(FACTOR,1))),2) ITEMS_TOTAL_DISC ,     /*  ADDED BY AHMED AMIN */                                                                                      
                                                                                     ROUND(nvl(DISC_VAL,0) + nvl(TOT_DISC1_VALUE,0) + nvl(TOT_DISC2_VALUE,0) + nvl(TOT_DISC3_VALUE,0),2) DISC_VAL ,     /*  ADDED BY AHMED AMIN */                                                                              
                                                                                     ROUND(SUM((NVL(SUPP_FREIGHT,0)+NVL(SUPP_INSURANCE,0)+NVL(SUPP_OTHERS,0))* nvl(quantity,0)*nvl(FACTOR,1))/*NVL(BASIC_QTY,0)*/,2) SUPP_COSTS,
                                                                                     ROUND(SUM(NVL(FREIGHT,0)    *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)  GAMAREK_TAKHLIS_NAKL,
                                                                                     ROUND(SUM(NVL(CUSTOMS,0)    *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)  CUSTOMS,
                                                                                     ROUND(SUM(NVL(D.TRANSPORT,0)*  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2) TRANSPORT,
                                                                                     ROUND(SUM(NVL(D.OTHERS,0)   *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)   OKHRA,
                                                                                     ROUND(SUM(NVL(D.INSURANCE,0)   *  nvl(quantity,0)*nvl(FACTOR,1)),2)   INSURANCE,
                                                                                     ROUND(SUM(NVL(D.COMMISSION,0)   *  nvl(quantity,0)*nvl(FACTOR,1)),2)   COMMISSION,                                                                                     
                                                                                     G.COST_CODE2
                                                                    From         st_trns_det d, ST_TRNS_DET_COST DC,st_trns_MAST M, ST_ITEM_GROUP  G,st_trns_type tt,ST_ITEM_UNIT UNT
                                                                  Where           D.ITEM_CODE      = UNT.ITEM_CODE
                                                                  AND         D.GROUP_CODE     = UNT.GROUP_CODE
                                                                  AND         D.UNIT_CODE      = UNT.UNIT_CODE
                                                                  AND         d.trns_type_code = M.trns_type_code
                                                                    and         d.trns_serial = M.trns_serial
                                                                    AND NVL(M.DELETE_FLAG,0)    = 0
                                                                    AND NVL(D.DELETE_FLAG,0)    = 0
                                                                    AND         d.trns_type_code = DC.trns_type_code
                                                                    and         d.trns_serial = DC.trns_serial
                                                                    AND     D.ITEM_SERIAL = DC.ITEM_SERIAL
                                                                    and     tt.trns_type_code = M.trns_type_code
                                                                    AND          d.trns_type_code = in_trns_type_code
                                                                    and         d.trns_serial = in_serial_number
                                                                    and         G.ITEM_GROUP_CODE  = d.GROUP_CODE
                                                                    Group by     G.COST_CODE2 , DISC_VAL + TOT_DISC1_VALUE + TOT_DISC2_VALUE + TOT_DISC3_VALUE)LOOP 
                            
                            ldgr_rec.cost_code2    :=    GROUP_REC.COST_CODE2;
                            If IN_Cost_No_Type=1 then                                  
                                             Ldgr_Rec.Cost_code:= IN_Cost_No;
                            Elsif IN_Cost_No_Type=2 then                                    
                                    select s.cost_code
                                                    into   Ldgr_Rec.Cost_Code
                                                    from st_trns_mast m,st_store s
                                                    where m.trns_type_code=in_trns_type_code
                                                    and   m.trns_serial= in_serial_number  
                                                    and   m.store_code=s.store_code;
                                                    
                                                    IF CHECK_COST_CENTERS(in_trns_type_code,in_serial_number,
                                                                    ldgr_rec.cost_code,ldgr_rec.cost_code2)= FALSE THEN 
                                                            RETURN (FALSE);
                                                    END IF;
                                      
                                      --Ldgr_Rec.Cost_Code:= s_cost;
                                  Elsif IN_Cost_No_Type=3 then
                                         Ldgr_Rec.Cost_Code:= IN_cost;
                              elsif IN_Cost_No_Type=6 then
                                                Ldgr_Rec.Cost_Code:= NULL;            
                            Else
                                   insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                   values (in_trns_type_code,in_serial_number,
                                                             '1 خطأ فى مؤشر رقم مركز التكلفة ');
                                        Return (FALSE);           
                                End If; 

                            
                            If IN_Entry_No is not null then
                                   Ldgr_Rec.Voucher_No := IN_Entry_No;
                            end if;                                                                        

                                        
                               IF CHECK_COST_CENTERS(in_trns_type_code,in_serial_number,
                                                                    ldgr_rec.cost_code,ldgr_rec.cost_code2)= FALSE THEN 
                                                    RETURN (FALSE);
                                        END IF;

                                        If nvl(IN_Value_Type,0)=1 then
                                  w_value := nvl(GROUP_REC.Items_Total,0);
                           ------------------------------------------------ 
                           -- BY ME                                                     
                          Elsif nvl(IN_Value_Type,0)=5 then
                                                    w_value := NVL(GROUP_REC.Items_Total_DISC,0)+ NVL(GROUP_REC.DISC_VAL,0);
                                        Elsif nvl(IN_Value_Type,0)=35 then
                          w_value := NVL(GROUP_REC.Items_SALES_total,0);
                    Elsif nvl(IN_Value_Type,0)=36 then
                          w_value := NVL(GROUP_REC.Items_Total_DISC,0);
                    Elsif nvl(IN_Value_Type,0)=37 then
                          w_value := NVL(GROUP_REC.DISC_VAL,0);
                          Elsif nvl(IN_Value_Type,0)=2 then
                                  w_value := nvl(GROUP_REC.Items_Total,0) - 
                                             NVL(GROUP_REC.Items_Total_DISC,0) -
                                             NVL(GROUP_REC.DISC_VAL,0) + 
                                             NVL(GROUP_REC.SUPP_COSTS,0) + 
                                             NVL(GROUP_REC.GAMAREK_TAKHLIS_NAKL,0) +
                                                                     NVL(GROUP_REC.CUSTOMS,0) +
                                   NVL(GROUP_REC.TRANSPORT,0) + NVL(GROUP_REC.INSURANCE,0) + NVL(GROUP_REC.COMMISSION,0) +
                                   NVL(GROUP_REC.OKHRA,0);
                          Elsif nvl(IN_Value_Type,0)=60 then
                                  w_value := ( NVL(GROUP_REC.ITEMS_TOTAL,0) - 
                                             NVL(GROUP_REC.ITEMS_TOTAL_DISC,0) -
                                             NVL(GROUP_REC.DISC_VAL,0) + 
                                             NVL(GROUP_REC.SUPP_COSTS,0) + 
                                             NVL(GROUP_REC.GAMAREK_TAKHLIS_NAKL,0) +
                                             NVL(GROUP_REC.CUSTOMS,0) +
                                             NVL(GROUP_REC.TRANSPORT,0) + NVL(GROUP_REC.INSURANCE,0) + NVL(GROUP_REC.COMMISSION,0) +
                                             NVL(GROUP_REC.OKHRA,0)  ) - ((( NVL(GROUP_REC.ITEMS_TOTAL,0) - 
                                             NVL(GROUP_REC.ITEMS_TOTAL_DISC,0) -
                                             NVL(GROUP_REC.DISC_VAL,0) + 
                                             NVL(GROUP_REC.SUPP_COSTS,0) + 
                                             NVL(GROUP_REC.GAMAREK_TAKHLIS_NAKL,0) +
                                             NVL(GROUP_REC.CUSTOMS,0) +
                                             NVL(GROUP_REC.TRANSPORT,0) + NVL(GROUP_REC.INSURANCE,0) + NVL(GROUP_REC.COMMISSION,0) +
                                             NVL(GROUP_REC.OKHRA,0))* ( NVL(V_BROKER_VALUE,0) /(nvl(V_Items_Total_CURR,1)-
                                                NVL(V_DET_DISC,0) -
                                                NVL(V_DISC_VAL,0) + nvl(V_service,0)  ))/** 100*/)) ; 
                          Elsif nvl(IN_Value_Type,0)=61 then
                                  w_value := ((( NVL(GROUP_REC.ITEMS_TOTAL,0) - 
                                             NVL(GROUP_REC.ITEMS_TOTAL_DISC,0) -
                                             NVL(GROUP_REC.DISC_VAL,0) + 
                                             NVL(GROUP_REC.SUPP_COSTS,0) + 
                                             NVL(GROUP_REC.GAMAREK_TAKHLIS_NAKL,0) +
                                             NVL(GROUP_REC.CUSTOMS,0) +
                                             NVL(GROUP_REC.TRANSPORT,0) + NVL(GROUP_REC.INSURANCE,0) + NVL(GROUP_REC.COMMISSION,0) +
                                             NVL(GROUP_REC.OKHRA,0))* ( NVL(V_BROKER_VALUE,0) /(nvl(V_Items_Total_CURR,1)-
                                                NVL(V_DET_DISC,0) -
                                                NVL(V_DISC_VAL,0) + nvl(V_service,0)  ))/** 100*/)) ;                                 
                                
                                   
                          Elsif nvl(IN_Value_Type,0)=12 then
                                  w_value := nvl(GROUP_rec.Items_Total,0) - 
                                             NVL(GROUP_REC.Items_Total_DISC,0) -
                                             NVL(GROUP_REC.DISC_VAL,0) + 
                                             NVL(GROUP_REC.SUPP_COSTS,0);
                                        Elsif nvl(IN_Value_Type,0)=4 then
                                  w_value := NVL(GROUP_REC.GAMAREK_TAKHLIS_NAKL,0);
                          
                          Elsif nvl(IN_Value_Type,0)=6 then
                                  w_value := NVL(GROUP_REC.CUSTOMS,0);
                          
                          Elsif nvl(IN_Value_Type,0)=7 then
                                  w_value := NVL(GROUP_REC.INSURANCE,0);
                          
                          Elsif nvl(IN_Value_Type,0)=10 then
                                  w_value := NVL(GROUP_REC.OKHRA,0);   

                          Elsif nvl(IN_Value_Type,0)=9 then
                                  w_value := NVL(GROUP_REC.COMMISSION,0); 
                                                                                                    
                          Elsif nvl(IN_Value_Type,0)=16  then
                                  w_value := NVL(GROUP_REC.TRANSPORT,0);                                                                                                     
                             ------------------------------------------------
                            Elsif nvl(IN_Value_Type,0)=3 then
                                  w_value := nvl(GROUP_REC.cost_Total,0);                                  
                            Else
                                   insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                   values (in_trns_type_code,in_serial_number,
                                               ' خطأ فى مؤشر القيمة ');
                                        Return (FALSE);
                            End If;               

                            If nvl(IN_Account_Ind,0) = 2 Then   --دائن
                                   ldgr_rec.TOTAL_value := nvl(w_value,0) * -1;
                                   total_value := total_value - nvl(w_value,0) ;
                            else
                                   ldgr_rec.TOTAL_value := nvl(w_value,0);
                                   total_value := total_value + nvl(w_value,0) ;
                            End If;
              
                -- Construct The ST_LEDGER Record
                      ldgr_rec.doc_no    := IN_doc_no ;
                            ldgr_rec.trns_date := IN_date   ;
                            ldgr_rec.trns_type_code := in_trns_type_code ;
                            ldgr_rec.trns_serial    := in_serial_number  ;
                            ldgr_rec.post_flag      := in_Trns_Post_type;
                            ldgr_rec.entry_type     := in_entry_type;

                            if in_Trns_Post_type = 1 then
                                if IN_trns_desc is null then
                                    ldgr_rec.entry_desc  :=  IN_trns_type_desc;
                                 else 
                                    ldgr_rec.entry_desc  :=  IN_trns_desc;
                                 end if;
                                             if g_lang = 'A' then
                                         ldgr_rec.memo           := ' حركة رقم '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
                                                else
                                         ldgr_rec.memo           := ' Transaction no '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
                                                end if;
                            elsif in_Trns_Post_type = 2 then
                                ldgr_rec.entry_desc     := IN_trns_type_desc;
                                                if g_lang = 'A' then
                                         ldgr_rec.memo           := ' نوع حركة رقم '||to_char(in_trns_type_code);
                                                else
                                         ldgr_rec.memo           := ' Transaction type no '||to_char(in_trns_type_code);
                                                end if;
                            elsif in_Trns_Post_type = 3 then
                                                if g_lang = 'A' then
                                         ldgr_rec.entry_desc     := 'قيد مفصل بمراكز تكلفة المجموعات';
                                                else
                                         ldgr_rec.entry_desc     := 'Detailed record from groups cost centers';
                                                end if;
                                 ldgr_rec.memo           := null;
                            end if ;
                    

--message('group 3 ldgr_rec.TOTAL_value = ' ||  ldgr_rec.TOTAL_value || '  total_value= ' ||  total_value ); pause; 
                   insert into st_ledger (TRNS_TYPE_CODE,
                                                       TRNS_SERIAL   , 
                                                       VOUCHER_NO    , 
                                                       ACCOUNT_NO    , 
                                                       COST_CODE     , 
                                                       COST_CODE2     , 
                                                       TOTAL_value   , 
                                                       DOC_NO        , 
                                                       ENTRY_DESC    , 
                                                       MEMO          , 
                                                       MEMO_DET ,
                                                       TRNS_DATE     ,
                                                       entry_type    ,
                                                       post_flag     )
                                                values(ldgr_rec.TRNS_TYPE_CODE,
                                                       ldgr_rec.TRNS_SERIAL   , 
                                                       ldgr_rec.VOUCHER_NO    , 
                                                       IN_Account_No                     ,
                                                       ldgr_rec.COST_CODE     ,
                                                                                     ldgr_rec.COST_CODE2    ,  
                                                       ldgr_rec.TOTAL_value   , 
                                                       ldgr_rec.DOC_NO        , 
                                                       ldgr_rec.ENTRY_DESC    , 
                                                       ldgr_rec.MEMO          , 
                                                       LDGR_REC.MEMO_DET,
                                                       ldgr_rec.TRNS_DATE     ,
                                                       ldgr_rec.entry_type    ,
                                                       ldgr_rec.post_flag );
                          
                END LOOP;
                D_TOT_VAL := total_value;                        
                RETURN(TRUE);                
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit HANDLE_STORE (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION HANDLE_STORE(in_trns_type_code         IN NUMBER,
                                             in_serial_number          IN NUMBER,
                                             IN_Entry_No               IN NUMBER,
                                             IN_Account_No_Type     IN NUMBER,
                                             IN_Account_No                IN NUMBER,
                                             IN_cost_No                    IN NUMBER,
                                             IN_cost_No2                  IN NUMBER,
                                             IN_Cost_No_Type             IN NUMBER,
                                             IN_Cost_No2_Type            IN NUMBER,
                                             IN_Value_Type          IN NUMBER,
                                             IN_doc_no              IN NUMBER,
                                             IN_date                IN DATE,
                                             IN_Account_Ind                IN NUMBER,
                                             in_Trns_Post_type      IN NUMBER,
                                             in_entry_type                IN NUMBER,
                                             IN_trns_desc                  IN VARCHAR2,
                                             IN_trns_type_desc      IN VARCHAR2,
                                             IN_REQUEST_NO        IN VARCHAR2,
                                             IN_REQUEST_NO_E        IN VARCHAR2,
                                             D_TOT_VAL                        OUT NUMBER ) RETURN BOOLEAN IS
                                                
                                                
        Ldgr_Rec              st_ledger%rowtype;
        w_status                            NUMBER;
        w_value                                NUMBER;
        total_value                        NUMBER:=0;
    w_Freight_Amount              number(30,15);
    w_customs                 number(30,15);
    w_trnsport                number(30,15);
    w_others                  number(30,15);
    w_insurance               number(30,15); 
    w_commission              number(30,15); 
    w_service               number(30,15) := 0 ; 
    V_DISC_MAST             number := 0 ; 
    V_BROKER_VALUE NUMBER ;
    V_ITEMS_TOTAL_CURR NUMBER ;
    V_ITEMS_TOTAL_CURR1 NUMBER ;    
    V_DET_DISC      NUMBER ; 
    V_DISC_VAL       NUMBER ;
    V_SERVICE        NUMBER;
    V_INCOME_ACCOUNT_NUMBER  NUMBER ;
BEGIN
        Select  NVL(FREIGHT_VAL,0)  FREIGHT_VAL,   /*--BEGIN--- MODIFIED ---BY AHMED AMIN */
                        NVL(CUSTOMS_VAL,0)  CUSTOMS,        
                        NVL(TRNSPORT_VAL,0) TRNSPORT,   
                        NVL(OTHERS_VAL,0)   OTHERS_VAL ,
                        NVL(INSURANCE_VAL,0) INSURANCE, 
                        NVL(COMMISSION_VAL,0) COMMISSION
        Into       w_Freight_Amount,
                        w_customs,
                        w_trnsport,
                        w_others,
                        W_INSURANCE , 
                        W_COMMISSION
        From   st_trns_mast m
        Where  m.trns_type_code = in_trns_type_code
        and    m.trns_serial    = in_serial_number;          

        FOR STORE_REC IN (Select     --round(Sum(nvl(unit_price,0) * nvl(quantity,0)),2) Items_total,
                                        round(Sum((nvl(unit_price,0) - nvl(DISC1_VALUE,0) - nvl(DISC2_VALUE,0) - nvl(DISC3_VALUE,0)) * nvl(quantity,0)),2) Items_total,
                              round(Sum(nvl(unit_price,0) * nvl(quantity,0)),2) Items_SALES_total,
                                                                                     ROUND(Sum(nvl(DC.unit_cost,0) * nvl(D.basic_qty,0)),2) cost_total,
                                                                ROUND(SUM(NVL(DET_DISC,0) + ((NVL(CURRENCY_RATE,0) * (NVL(DISC1_VALUE,0) + NVL(DISC2_VALUE,0) + NVL(DISC3_VALUE,0))) * NVL(QUANTITY,0) * nvl(FACTOR,1))),2) ITEMS_TOTAL_DISC,              
                                                                                     --ROUND(Sum(nvl(det_disc,0) /** nvl(quantity,0)* */ * nvl(FACTOR,1)),2) Items_total_DISC,
                                                                                     --ROUND(Sum(nvl(DISC,0) * nvl(quantity,0)*nvl(FACTOR,1)),2) DISC_VAL,
                                                                                     0 DISC_VAL ,
                                                                                     ROUND(SUM((NVL(SUPP_FREIGHT,0)+NVL(SUPP_INSURANCE,0)+NVL(SUPP_OTHERS,0))* nvl(quantity,0)*nvl(FACTOR,1))/*NVL(BASIC_QTY,0)*/,2) SUPP_COSTS,
                                                                                     ROUND(SUM(NVL(FREIGHT,0)    *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)  GAMAREK_TAKHLIS_NAKL,
                                                                                     ROUND(SUM(NVL(CUSTOMS,0)    *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)  BANKIA,
                                                                                     ROUND(SUM(NVL(D.TRANSPORT,0)*  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2) TAMIN,
                                                                                     ROUND(SUM(NVL(D.OTHERS,0)   *  nvl(quantity,0)*nvl(FACTOR,1)/*NVL(BASIC_QTY,0)*/),2)   OKHRA,
                                                                                     s.Account_number1,s.Account_number2,
                                                                                     s.Account_number3,s.Account_number4,
                                                                                     s.cost_code  s_cost,s.cost_code2  s_cost2, m.TRNSFER_TO_STORE,m.cost_code,m.cost_code2,G.cost_code cost_code_G ,G.cost_code2 cost_code2_G 
                                                                    From         st_trns_det d, ST_TRNS_DET_COST DC,ST_TRNS_MAST M, st_store  s,st_trns_type tt,ST_ITEM_UNIT UNT ,ST_ITEM_GROUP G
                                                                  Where           D.ITEM_CODE      = UNT.ITEM_CODE
                                                                  AND         D.GROUP_CODE     = UNT.GROUP_CODE
                                                                  AND    D.GROUP_CODE     = G.ITEM_GROUP_CODE
                                                                  AND         D.UNIT_CODE      = UNT.UNIT_CODE
                                                                  AND         d.trns_type_code = M.trns_type_code
                                                                    and     tt.trns_type_code = M.trns_type_code
                                                                    and         d.trns_serial = M.trns_serial
                                                                    AND         d.trns_type_code = DC.trns_type_code
                                                                    AND NVL (M.DELETE_FLAG, 0) = 0
                                                                    AND NVL (D.DELETE_FLAG, 0) = 0
                                                                    and     D.ITEM_SERIAL = DC.ITEM_SERIAL
                                                                    and         d.trns_serial = DC.trns_serial
                                                                    AND            d.trns_type_code = in_trns_type_code
                                                                    and         d.trns_serial = in_serial_number
                                                                    and         s.store_code     = d.store_code
                                                                    Group by     s.Account_number1,s.Account_number2,
                                                                                       s.Account_number3,s.Account_number4,
                                                                                s.cost_code,s.cost_code2, m.TRNSFER_TO_STORE,
                                                                                m.cost_code,m.cost_code2,G.cost_code ,G.cost_code2)LOOP 
                                        
--        MESSAGE('1'); PAUSE;                         
                            If IN_Entry_No is not null then
                                   Ldgr_Rec.Voucher_No := IN_Entry_No;
                            end if;
--        MESSAGE('2'); PAUSE;                         
                                  if IN_Account_No_Type=1 then
                       Ldgr_Rec.Account_No:= IN_Account_No;
                                   Elsif IN_Account_No_Type=2 then
                                     Ldgr_Rec.Account_No:= store_rec.Account_number1;
                                   Elsif IN_Account_No_Type=3 then
                                     Ldgr_Rec.Account_No:= store_rec.Account_number2;
                                   Elsif IN_Account_No_Type=4 then
                                           Ldgr_Rec.Account_No:= store_rec.Account_number3;
                                   Elsif IN_Account_No_Type=5 then
                                       BEGIN
                                           SELECT  INCOME_ACCOUNT_NUMBER
                                                      INTO    V_INCOME_ACCOUNT_NUMBER
                                                    FROM    CUSTOMER C , ST_TRNS_MAST M 
                                                    WHERE M.CUSTOMER_CODE = C.CODE
                                                    AND  trns_type_code = in_trns_type_code
                                               and trns_serial = in_serial_number ;
                                       EXCEPTION WHEN OTHERS THEN 
                                            NULL ;
                                       END  ;
                                       IF store_rec.Account_number4 IS NULL THEN 
                                           Ldgr_Rec.Account_No:= V_INCOME_ACCOUNT_NUMBER;
                                       ELSE
                                     Ldgr_Rec.Account_No:= store_rec.Account_number4;
                                       END IF ;
                                     
                                   Elsif IN_Account_No_Type=12 then
                                                select s.Account_number2
                                                into   Ldgr_Rec.Account_No
                                                from   st_store s
                                                where  s.store_code = store_rec.trnsfer_to_store;
                                        END IF;
--        MESSAGE('3'); PAUSE;     MESSAGE(Ldgr_Rec.Account_No);

                                  If Ldgr_Rec.Account_No is null Then 
                                  insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                   values (in_trns_type_code,in_serial_number,
                                                          ' 2رقم الحساب غير موجود ');
                                                Return (FALSE);
                                  End If;
                                        
--        MESSAGE('4'); PAUSE;                         
                                        begin 
                                  select account_status
                                  into w_status
                                  from ac_master
                                  where account_number = ldgr_rec.account_no;

                              if w_status = 0 then
                                    insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                     values (in_trns_type_code,in_serial_number,
                                                            ' رقم الحساب ليس على أدنى مستوى ');
                                    return(FALSE);
                                   end if;
                            exception
                                   when others then      
                                        insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                         values (in_trns_type_code,in_serial_number,
                                                                ' رقم الحساب بملف المخزن غير موجود فى نظام الحسابات ');
                                        return(FALSE);
                            end;
    --    MESSAGE('5'); PAUSE;                         
                  SELECT DISC_VAL * NVL(CURRENCY_RATE,1)
                    INTO V_DISC_MAST
                    FROM ST_TRNS_MAST
                   WHERE trns_type_code = in_trns_type_code
                                         and trns_serial = in_serial_number ; 


                    -----------------BROKER----------------------------------    
                    BEGIN
                         SELECT SUM (NVL (UNIT_PRICE, 0) * NVL (QUANTITY, 0)) ITEMS_TOTAL_CURR,
                                ROUND (SUM (NVL (DET_DISC, 0)), 2) ITEMS_TOTAL_DISC,
                                NVL (DISC_VAL, 0) DISC_VAL
                           INTO V_ITEMS_TOTAL_CURR, V_DET_DISC, V_DISC_VAL
                           FROM ST_TRNS_MAST M, ST_TRNS_DET D
                          WHERE     M.TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
                                AND M.TRNS_SERIAL = IN_SERIAL_NUMBER
                                AND NVL (M.DELETE_FLAG, 0) = 0
                                AND NVL (D.DELETE_FLAG, 0) = 0
                                AND D.TRNS_TYPE_CODE(+) = M.TRNS_TYPE_CODE
                                AND D.TRNS_SERIAL(+) = M.TRNS_SERIAL
                       GROUP BY NVL (DISC_VAL, 0);
                    EXCEPTION
                       WHEN OTHERS
                       THEN
                          NULL;
                    END;
                    
                    BEGIN
                       SELECT NVL (ROUND (SUM (NVL (SERVICE_COST, 0) * NVL (UNITS_NO, 0)), 2), 0)
                         INTO V_SERVICE
                         FROM ST_TRNS_MAST M, ST_TRNS_SERVICES D
                        WHERE     D.TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
                              AND D.TRNS_SERIAL = IN_SERIAL_NUMBER
                              AND NVL (M.DELETE_FLAG, 0) = 0
                              AND D.TRNS_TYPE_CODE = M.TRNS_TYPE_CODE
                              AND D.TRNS_SERIAL = M.TRNS_SERIAL;
                    EXCEPTION
                       WHEN OTHERS
                       THEN
                          NULL;
                    END;
                    
                    BEGIN
                       SELECT NVL (BROKER_VALUE, 0)                     /** NVL(CURRENCY_RATE,1)*/
                         INTO V_BROKER_VALUE
                         FROM ST_TRNS_MAST
                        WHERE     TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
                              AND TRNS_SERIAL = IN_SERIAL_NUMBER;
                    EXCEPTION
                       WHEN OTHERS
                       THEN
                          NULL;
                    END;
                    -----------------BROKER----------------------------------
                                         
                                    Select nvl(round(Sum(nvl(service_cost,0) * nvl(units_no,0)),2),0)
                                    Into   w_service
                                    From   st_trns_mast m, st_trns_services d 
                                    Where  d.trns_type_code = in_trns_type_code
                                    and    d.trns_serial    = in_serial_number
                                    and    nvl(m.delete_flag,0)    = 0
                                    and    d.trns_type_code = m.trns_type_code
                                    and    d.trns_serial    = m.trns_serial;

                                        if IN_Cost_No_Type=1 then                                        
                                      Ldgr_Rec.Cost_Code:= IN_Cost_No;
                                  elsif IN_Cost_No_Type=2 then
                                      Ldgr_Rec.Cost_Code:= store_rec.s_cost;
                                  elsif IN_Cost_No_Type=3 then
                                      Ldgr_Rec.Cost_Code:= store_rec.cost_code;                
                                  elsif IN_Cost_No_Type=4 then
                                      Ldgr_Rec.Cost_Code:= store_rec.cost_code_G;                                                                                  
                                  elsif IN_Cost_No_Type=5 then
                                                select s.Cost_Code
                                                into   Ldgr_Rec.Cost_Code
                                                from   st_store s
                                                where  s.store_code = store_rec.trnsfer_to_store;
                                  elsif IN_Cost_No_Type=6 then
                                      Ldgr_Rec.Cost_Code:= NULL;                                                                                      
                                  Else                                        
                                  insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                   values (in_trns_type_code,in_serial_number,
                                                           ' خطأ فى مؤشر رقم مركز التكلفة ');
                                          Return (FALSE);
                                  End If;                                  
                                  if IN_Cost_No2_Type=1 then
                                      Ldgr_Rec.Cost_Code2:= IN_Cost_No2;
                                  Elsif IN_Cost_No2_Type=7 then
                                                BEGIN
                                                select s.cost_code2
                                                    into Ldgr_Rec.Cost_Code2
                                                    from st_trns_mast m,SALESMAN s
                                                    where m.trns_type_code=in_trns_type_code
                                                    and   m.trns_serial= in_serial_number  
                                                    and   m.SALESMAN_code= s.code;
                                                EXCEPTION WHEN OTHERS THEN 
                                                    Ldgr_Rec.Cost_Code2 := NULL; 
                                                END;
                                  elsif IN_Cost_No2_Type=2 then
                                      Ldgr_Rec.Cost_Code2:= store_rec.s_cost2;
                                  elsif IN_Cost_No2_Type=3 then
                                      Ldgr_Rec.Cost_Code2:= store_rec.cost_code2;                                      
                                  elsif IN_Cost_No2_Type=5 then
                                                select s.Cost_Code2
                                                into   Ldgr_Rec.Cost_Code2
                                                from   st_store s
                                                where  s.store_code = store_rec.trnsfer_to_store;
                                  elsif IN_Cost_No2_Type=4 then
                                      Ldgr_Rec.Cost_Code2:= store_rec.cost_code2_G;                        
                                  elsif IN_Cost_No2_Type=6 then
                                      Ldgr_Rec.Cost_Code2:= NULL;                                      
                                                
                                  Else    
                                  insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                   values (in_trns_type_code,in_serial_number,
                                                           '2 خطأ فى مؤشر ملف المخزن رقم مركز التكلفة ');
                                          Return (FALSE);
                            End If; 

    -- MESSAGE(ldgr_rec.cost_code2); PAUSE;                         
    
                               IF CHECK_COST_CENTERS(in_trns_type_code,in_serial_number,
                                                                    ldgr_rec.cost_code,ldgr_rec.cost_code2)= FALSE THEN 
                                                                    RETURN (FALSE);
                                        END IF;

                                        If nvl(IN_Value_Type,0)=1 then
                                  w_value := nvl(store_rec.Items_SALES_total,0)  - 
                                                       NVL(STORE_REC.Items_Total_DISC,0) - NVL(V_DISC_MAST,0) - 
                                             NVL(STORE_REC.DISC_VAL,0) + 
                                             NVL(STORE_REC.SUPP_COSTS,0) + 
                                             NVL(STORE_REC.GAMAREK_TAKHLIS_NAKL,0) +
                                                                     NVL(STORE_REC.BANKIA,0) +
                                   NVL(STORE_REC.TAMIN,0) +
                                   NVL(STORE_REC.OKHRA,0);
                          Elsif nvl(IN_Value_Type,0)=2 then
                                  w_value := nvl(store_rec.Items_SALES_total,0) + nvl(w_service,0) - 
                                                       NVL(STORE_REC.Items_Total_DISC,0) - NVL(V_DISC_MAST,0) - 
                                             NVL(STORE_REC.DISC_VAL,0) + 
                                             NVL(STORE_REC.SUPP_COSTS,0) + 
                                             NVL(STORE_REC.GAMAREK_TAKHLIS_NAKL,0) +
                                                                     NVL(STORE_REC.BANKIA,0) +
                                   NVL(STORE_REC.TAMIN,0) +
                                   NVL(STORE_REC.OKHRA,0);
                          Elsif nvl(IN_Value_Type,0)=60 then
                               IF nvl(V_Items_Total_CURR,0) = 0 THEN 
                                     V_Items_Total_CURR1 := 1 ;
                               ELSE
                                     V_Items_Total_CURR1 := V_Items_Total_CURR ;
                               END IF;
                                   
                                  w_value := (nvl(store_rec.Items_Total,0) + nvl(w_service,0) - 
                                                       NVL(STORE_REC.Items_Total_DISC,0) - NVL(V_DISC_MAST,0) - 
                                             NVL(STORE_REC.DISC_VAL,0) + 
                                             NVL(STORE_REC.SUPP_COSTS,0) + 
                                             NVL(STORE_REC.GAMAREK_TAKHLIS_NAKL,0) +
                                                                     NVL(STORE_REC.BANKIA,0) +
                                   NVL(STORE_REC.TAMIN,0) +
                                   NVL(STORE_REC.OKHRA,0) ) - ((( nvl(store_rec.Items_Total,0)  - 
                                                       NVL(STORE_REC.Items_Total_DISC,0) - 
                                             NVL(STORE_REC.DISC_VAL,0) + 
                                             NVL(STORE_REC.SUPP_COSTS,0) + 
                                             NVL(STORE_REC.GAMAREK_TAKHLIS_NAKL,0) +
                                                                     NVL(STORE_REC.BANKIA,0) +
                                   NVL(STORE_REC.TAMIN,0) +
                                   NVL(STORE_REC.OKHRA,0) )* ( NVL(V_BROKER_VALUE,0) /(nvl(V_Items_Total_CURR1,1)-
                                                NVL(V_DET_DISC,0) -
                                                NVL(V_DISC_VAL,0) + nvl(V_service,0)  ))/** 100*/)) ;                                                 
                          Elsif nvl(IN_Value_Type,0)=3 then
                              w_value := nvl(store_rec.cost_Total,0);                          
                        Elsif nvl(IN_Value_Type,0)=4 then
                                  w_value := NVL(STORE_REC.GAMAREK_TAKHLIS_NAKL,0);
                          Elsif nvl(IN_Value_Type,0)=5 then
                                  w_value := NVL(STORE_REC.Items_Total_DISC,0)+ NVL(STORE_REC.DISC_VAL,0);
                        Elsif nvl(IN_Value_Type,0)=35 then
                          w_value := NVL(STORE_REC.Items_SALES_total,0);
                    Elsif nvl(IN_Value_Type,0)=36 then
                          w_value := NVL(STORE_REC.Items_Total_DISC,0);
                    Elsif nvl(IN_Value_Type,0)=37 then
                          w_value := NVL(STORE_REC.DISC_VAL,0);
                          Elsif nvl(IN_Value_Type,0)=6 then
                                  w_value := NVL(STORE_REC.BANKIA,0);
                          Elsif nvl(IN_Value_Type,0)=7 then
                                  w_value := NVL(STORE_REC.TAMIN,0);
                          Elsif nvl(IN_Value_Type,0)=10 then
                                  w_value := NVL(STORE_REC.OKHRA,0);                                   
                          Elsif nvl(IN_Value_Type,0)=12 then
                                  w_value := nvl(store_rec.Items_Total,0) - 
                                                       NVL(STORE_REC.Items_Total_DISC,0) -
                                             NVL(STORE_REC.DISC_VAL,0) + 
                                             NVL(STORE_REC.SUPP_COSTS,0);
                                        /*
                                        Elsif nvl(Link_Rec.Value_Type,0)=4 then
                                            w_value := NVL(w_Freight_Amount,0);
                                        Elsif nvl(Link_Rec.Value_Type,0)=6 then
                                            w_value := NVL(w_customs,0);*/
                                        Elsif nvl(IN_Value_Type,0)= 16 then
                                             w_value := nvl(w_trnsport,0);
                                        /*
                                        Elsif nvl(Link_Rec.Value_Type,0)=10 then
                                            w_value := NVL(w_others,0);                                   
                                        Elsif nvl(Link_Rec.Value_Type,0)=7 then
                                            w_value := NVL(W_INSURANCE,0);
                                        Elsif nvl(Link_Rec.Value_Type,0)= 9 then
                                            w_value := nvl(w_commission,0);*/
                                        Else
                                   insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                   values (in_trns_type_code,in_serial_number,
                                               ' خطأ فى مؤشر القيمة ');
                                        Return (FALSE);
                            End If;               

                            If nvl(IN_Account_Ind,0) = 2 Then   --دائن
                                   ldgr_rec.TOTAL_value := nvl(w_value,0) * -1;
                                   total_value := total_value - nvl(w_value,0) ;
                            else
                                   ldgr_rec.TOTAL_value := nvl(w_value,0);
                                   total_value := total_value + nvl(w_value,0) ;
                            End If;
              
                -- Construct The ST_LEDGER Record
        --MESSAGE('8'); PAUSE;                         
                            ldgr_rec.doc_no    := IN_doc_no ;
                            ldgr_rec.trns_date := IN_date   ;
                            ldgr_rec.trns_type_code := in_trns_type_code ;
                            ldgr_rec.trns_serial    := in_serial_number  ;
                            ldgr_rec.post_flag      := in_Trns_Post_type;
                            ldgr_rec.entry_type     := in_entry_type;

   
                            if in_Trns_Post_type = 1 then
                                if IN_trns_desc is null then
                                    ldgr_rec.entry_desc  :=  IN_trns_type_desc;
                                 else 
                                    ldgr_rec.entry_desc  :=  IN_trns_desc;
                                 end if;
                                             if g_lang = 'A' then
                                         ldgr_rec.memo           := ' حركة رقم '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
                                                else
                                         ldgr_rec.memo           := ' Transaction no '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
                                                end if;
                            elsif in_Trns_Post_type = 2 then
                                ldgr_rec.entry_desc     := IN_trns_type_desc;
                                                if g_lang = 'A' then
                                         ldgr_rec.memo           := ' نوع حركة رقم '||to_char(in_trns_type_code);
                                                else
                                         ldgr_rec.memo           := ' Transaction type no '||to_char(in_trns_type_code);
                                                end if;
                            elsif in_Trns_Post_type = 3 then
                                                if g_lang = 'A' then
                                         ldgr_rec.entry_desc     := 'قيد مجمع مرحل من المخازن';
                                                else
                                         ldgr_rec.entry_desc     := 'Composed record from stores';
                                                end if;
                                        
                                 ldgr_rec.memo           := null;
                            end if ;
                            
                    
 --message('bbbb ldgr_rec.TOTAL_value = ' ||  ldgr_rec.TOTAL_value || '  total_value= ' ||  total_value ); pause; 
                   insert into st_ledger (TRNS_TYPE_CODE,
                                               TRNS_SERIAL   , 
                                       VOUCHER_NO    , 
                                       ACCOUNT_NO    , 
                                       COST_CODE     , 
                                       COST_CODE2     , 
                                       TOTAL_value   , 
                                       DOC_NO        , 
                                       ENTRY_DESC    , 
                                       MEMO          ,
                                       MEMO_DET, 
                                       TRNS_DATE     ,
                                       entry_type    ,
                                       post_flag     )
                                values(ldgr_rec.TRNS_TYPE_CODE,
                                       ldgr_rec.TRNS_SERIAL   , 
                                       ldgr_rec.VOUCHER_NO    , 
                                       ldgr_rec.ACCOUNT_NO    , 
                                       ldgr_rec.COST_CODE     , 
                                       ldgr_rec.COST_CODE2     , 
                                       ldgr_rec.TOTAL_value   , 
                                       ldgr_rec.DOC_NO        , 
                                       ldgr_rec.ENTRY_DESC    , 
                                       ldgr_rec.MEMO          , 
                                       LDGR_REC.MEMO_DET,
                                       ldgr_rec.TRNS_DATE     ,
                                       ldgr_rec.entry_type    ,
                                       ldgr_rec.post_flag );
                                      

        END LOOP;

        
        D_TOT_VAL := total_value;
        RETURN (TRUE );                        
                                    
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit HANDLE_TAX_VALUES (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION HANDLE_TAX_VALUES(in_trns_type_code         IN NUMBER,
    in_serial_number          IN NUMBER,
    IN_Entry_No               IN NUMBER,
    IN_Account_No_Type     IN NUMBER,
    IN_Account_No                IN NUMBER,
    IN_cost_No                    IN NUMBER,
    IN_cost_No2                  IN NUMBER,
    IN_Cost_No_Type             IN NUMBER,
    IN_Cost_No2_Type            IN NUMBER,
    IN_Value_Type          IN NUMBER,
    IN_doc_no              IN NUMBER,
    IN_date                IN DATE,
    IN_Account_Ind                IN NUMBER,
    in_Trns_Post_type      IN NUMBER,
    in_entry_type                IN NUMBER,
    IN_trns_desc                  IN VARCHAR2,
    IN_trns_type_desc      IN VARCHAR2,
    IN_REQUEST_NO        IN VARCHAR2,
    IN_REQUEST_NO_E        IN VARCHAR2,
    D_TOT_VAL                        OUT NUMBER ) RETURN BOOLEAN IS
    
    Ldgr_Rec              st_ledger%rowtype;
    w_status                            NUMBER;
    w_value                                NUMBER;
    total_value                        NUMBER:=0;
    CUSTOM_ACCOUNT_NO     NUMBER;
    EXT_SUPP_FLAG         NUMBER;
    T_TRNS_TYPE           NUMBER;
    tax_total1                        number;
    tax_total2                        number;
    tax_value1                        number;
    tax_value2                        number;
    
BEGIN
    FOR C_REC IN (Select    tax_value1,tax_value2,store_code,trns_type_code,trns_serial,posting_supplier_code
        From     ST_TRNS_MAST M
        Where   m.trns_type_code = in_trns_type_code
        and         m.trns_serial = in_serial_number)
    LOOP 

        tax_total1 := nvl(c_rec.tax_value1,0);
        tax_total2 := nvl(c_rec.tax_value2,0);
        
        SELECT TRNS_TYPE
        INTO   T_TRNS_TYPE
        FROM  ST_TRNS_TYPE
        WHERE TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE;
        
        If IN_Entry_No is not null then
            Ldgr_Rec.Voucher_No := IN_Entry_No;
        end if;

       /*SELECT DECODE(T_TRNS_TYPE,2,CR_ACCOUNT_NO,4,CR_ACCOUNT_NO,1,DB_ACCOUNT_NO,3,DB_ACCOUNT_NO,DECODE(IN_Account_Ind,2,CR_ACCOUNT_NO,DB_ACCOUNT_NO)),CUSTOM_ACCOUNT_NO
       INTO   Ldgr_Rec.Account_No,CUSTOM_ACCOUNT_NO
       FROM   TX_TAXES_TYPES 
       WHERE  TAX_CODE = 1;*/           
       Ldgr_Rec.Account_No := IN_Account_No;
       
       SELECT CUSTOM_ACCOUNT_NO
       INTO   CUSTOM_ACCOUNT_NO
       FROM   TX_TAXES_TYPES 
       WHERE  TAX_CODE = 2;
       
        If Ldgr_Rec.Account_No is null Then 
            insert into st_post_msg (trns_type_code,trns_serial,message) 
            values (in_trns_type_code,in_serial_number,
            ' رقم الحساب غير موجود ');
            Return (FALSE);
        End If;

        begin 
            select account_status
            into w_status
            from ac_master
            where account_number = ldgr_rec.account_no;
        
            if w_status = 0 then
                insert into st_post_msg (trns_type_code,trns_serial,message) 
                values (in_trns_type_code,in_serial_number,
                ' رقم الحساب ليس على أدنى مستوى ');
                return(FALSE);
            end if;
        exception
            when others then      
                insert into st_post_msg (trns_type_code,trns_serial,message) 
                values (in_trns_type_code,in_serial_number,
                ' رقم الحساب الضريبي غير موجود فى نظام الحسابات ');
                return(FALSE);
        end;

        if IN_Cost_No_Type=1 then
            Ldgr_Rec.Cost_Code:= IN_Cost_No;
        elsif IN_Cost_No_Type=2 then
            select s.Cost_Code
            into   Ldgr_Rec.Cost_Code
            from   st_store s
            where  s.store_code = C_rec.store_code;
        elsif IN_Cost_No_Type=6 then
            Ldgr_Rec.Cost_Code:= NULL;                                                                                      
        Else                                        
            insert into st_post_msg (trns_type_code,trns_serial,message) 
            values (in_trns_type_code,in_serial_number,
            '1 خطأ فى مؤشر رقم مركز التكلفة ');
            Return (FALSE);
        End If;
    
        if IN_Cost_No2_Type=1 then
            Ldgr_Rec.Cost_Code2:= IN_Cost_No2;
        elsif IN_Cost_No2_Type=2 then
            select s.Cost_Code2
            into   Ldgr_Rec.Cost_Code2
            from   st_store s
            where  s.store_code = C_rec.store_code;
        elsif IN_Cost_No2_Type=6 then
            Ldgr_Rec.Cost_Code2:= NULL;    
        Else                                        
            insert into st_post_msg (trns_type_code,trns_serial,message) 
            values (in_trns_type_code,in_serial_number,
            '2 خطأ فى مؤشر ملف الضريبة رقم مركز التكلفة ');
            Return (FALSE);
        End If; 
    
        IF CHECK_COST_CENTERS(in_trns_type_code,in_serial_number,
            ldgr_rec.cost_code,ldgr_rec.cost_code2)= FALSE THEN 
            RETURN (FALSE);
        END IF;
    
        ldgr_rec.doc_no    := IN_doc_no ;
        ldgr_rec.trns_date := IN_date   ;
        ldgr_rec.trns_type_code := in_trns_type_code ;
        ldgr_rec.trns_serial    := in_serial_number  ;                           
        ldgr_rec.post_flag      := in_Trns_Post_type;                            
        ldgr_rec.entry_type     := in_entry_type;

        if in_Trns_Post_type = 1 then
            if IN_trns_desc is null then
                ldgr_rec.entry_desc  :=  IN_trns_type_desc;
            else 
                ldgr_rec.entry_desc  :=  IN_trns_desc;
            end if;
    
            if g_lang = 'A' then
                ldgr_rec.memo           := ' حركة رقم '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
            else
                ldgr_rec.memo           := ' Transaction no '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
            end if;
        elsif in_Trns_Post_type = 2 then
            ldgr_rec.entry_desc     := IN_trns_type_desc;
            if g_lang = 'A' then
                ldgr_rec.memo           := ' نوع حركة رقم '||to_char(in_trns_type_code);
            else
            ldgr_rec.memo           := ' Transaction type no '||to_char(in_trns_type_code);
            end if;
        elsif in_Trns_Post_type = 3 then
            if g_lang = 'A' then
                ldgr_rec.entry_desc     := 'قيد مجمع مرحل من المخازن';
            else
                ldgr_rec.entry_desc     := 'Composed record from stores';
            end if;
            ldgr_rec.memo           := null;
        end if ;

        Select    round(sum(nvl(d.tax_value1,0)),2)  /** currency_rate*/ tax_total1,
                        round(sum(nvl(d.tax_value2,0)),2)  /** currency_rate*/ tax_total2
        into        tax_value1,tax_value2                        
        From      st_trns_det d
        Where   d.trns_type_code = C_REC.trns_type_code
        and         d.trns_serial = C_REC.trns_serial
        AND NVL(D.DELETE_FLAG,0)    = 0;

        tax_total1 := tax_total1 + nvl(tax_value1,0);
        tax_total2 := tax_total1 + nvl(tax_value2,0);
        
        Select    round(sum(nvl(d.tax_value1,0)),2)  /** currency_rate*/ tax_total1,
                        round(sum(nvl(d.tax_value2,0)),2)  /** currency_rate*/ tax_total2
        into        tax_value1,tax_value2                        
        From     st_trns_services d
        WHERE      d.trns_type_code = C_REC.trns_type_code
        and         d.trns_serial = C_REC.trns_serial;
                
        tax_total1 := tax_total1 + nvl(tax_value1,0);
        tax_total2 := tax_total1 + nvl(tax_value2,0);

        for v_rec in (Select    round(nvl(d.tax_value1,0),2)  /** currency_rate*/ tax_value1,
                                                    round(nvl(d.tax_value2,0),2)  /** currency_rate*/ tax_value2,
                                                    supplier_code
                From      st_trns_det_expens d
                Where   d.trns_type_code = C_REC.trns_type_code
                and         d.trns_serial = C_REC.trns_serial ) loop

                        insert into st_ledger (TRNS_TYPE_CODE,
                        TRNS_SERIAL   , 
                        VOUCHER_NO    , 
                        ACCOUNT_NO    , 
                        COST_CODE     ,
                        COST_CODE2     ,  
                        TOTAL_value   , 
                        DOC_NO        , 
                        ENTRY_DESC    , 
                        MEMO          ,
                        MEMO_DET, 
                        TRNS_DATE     ,
                        entry_type    ,
                        post_flag     )
                        values(ldgr_rec.TRNS_TYPE_CODE,
                        ldgr_rec.TRNS_SERIAL   , 
                        ldgr_rec.VOUCHER_NO    , 
                        ldgr_rec.ACCOUNT_NO    , 
                        ldgr_rec.COST_CODE     ,
                        ldgr_rec.COST_CODE2     ,  
                        nvl(v_rec.tax_value1,0)  , 
                        ldgr_rec.DOC_NO        , 
                        ldgr_rec.ENTRY_DESC    , 
                        ldgr_rec.MEMO          , 
                        LDGR_REC.MEMO_DET,
                        ldgr_rec.TRNS_DATE     ,
                        ldgr_rec.entry_type    ,
                        ldgr_rec.post_flag );
                        total_value := total_value - ldgr_rec.TOTAL_value ;            

                    BEGIN
                    SELECT  NVL(EXT_SUPP_FLAG,0) 
                    INTO    EXT_SUPP_FLAG
                    FROM    TX_TAXES_SUPPLIERS
                    WHERE   SUPPLIER_CODE = v_rec.supplier_code AND TAX_CODE = 1;
                    EXCEPTION
                        WHEN OTHERS THEN
                            EXT_SUPP_FLAG := 0 ;
                    END;
            
                    IF EXT_SUPP_FLAG = 1 THEN
                        insert into st_ledger (TRNS_TYPE_CODE,
                        TRNS_SERIAL   , 
                        VOUCHER_NO    , 
                        ACCOUNT_NO    , 
                        COST_CODE     ,
                        COST_CODE2     ,  
                        TOTAL_value   , 
                        DOC_NO        , 
                        ENTRY_DESC    , 
                        MEMO          ,
                        MEMO_DET, 
                        TRNS_DATE     ,
                        entry_type    ,
                        post_flag     )
                        values(ldgr_rec.TRNS_TYPE_CODE,
                        ldgr_rec.TRNS_SERIAL   , 
                        ldgr_rec.VOUCHER_NO    , 
                        CUSTOM_ACCOUNT_NO    , 
                        ldgr_rec.COST_CODE     ,
                        ldgr_rec.COST_CODE2     ,  
                        -1 * nvl(v_rec.tax_value1,0)  , 
                        ldgr_rec.DOC_NO        , 
                        ldgr_rec.ENTRY_DESC    , 
                        ldgr_rec.MEMO          , 
                        LDGR_REC.MEMO_DET,
                        ldgr_rec.TRNS_DATE     ,
                        ldgr_rec.entry_type    ,
                        ldgr_rec.post_flag );
                    END IF;        
        end loop;
                

        w_value := nvl(tax_total1,0);
    
        If nvl(IN_Account_Ind,0) = 2 Then   --????
            ldgr_rec.TOTAL_value := nvl(w_value,0) * -1;
            total_value := total_value - nvl(w_value,0) ;
        else
            ldgr_rec.TOTAL_value := nvl(w_value,0);
            total_value := total_value + nvl(w_value,0) ;
        End If;
            
        insert into st_ledger (TRNS_TYPE_CODE,
        TRNS_SERIAL   , 
        VOUCHER_NO    , 
        ACCOUNT_NO    , 
        COST_CODE     ,
        COST_CODE2     ,  
        TOTAL_value   , 
        DOC_NO        , 
        ENTRY_DESC    , 
        MEMO          ,
        MEMO_DET, 
        TRNS_DATE     ,
        entry_type    ,
        post_flag     )
        values(ldgr_rec.TRNS_TYPE_CODE,
        ldgr_rec.TRNS_SERIAL   , 
        ldgr_rec.VOUCHER_NO    , 
        ldgr_rec.ACCOUNT_NO    , 
        ldgr_rec.COST_CODE     ,
        ldgr_rec.COST_CODE2     ,  
        ldgr_rec.TOTAL_value   , 
        ldgr_rec.DOC_NO        , 
        ldgr_rec.ENTRY_DESC    , 
        ldgr_rec.MEMO          , 
        LDGR_REC.MEMO_DET,
        ldgr_rec.TRNS_DATE     ,
        ldgr_rec.entry_type    ,
        ldgr_rec.post_flag );

        BEGIN
        SELECT  NVL(EXT_SUPP_FLAG,0) 
        INTO    EXT_SUPP_FLAG
        FROM    TX_TAXES_SUPPLIERS
        WHERE   SUPPLIER_CODE = c_rec.posting_supplier_code AND TAX_CODE = 1;
        EXCEPTION
            WHEN OTHERS THEN
                EXT_SUPP_FLAG := 0 ;
        END;

        IF EXT_SUPP_FLAG = 1 THEN
            insert into st_ledger (TRNS_TYPE_CODE,
            TRNS_SERIAL   , 
            VOUCHER_NO    , 
            ACCOUNT_NO    , 
            COST_CODE     ,
            COST_CODE2     ,  
            TOTAL_value   , 
            DOC_NO        , 
            ENTRY_DESC    , 
            MEMO          ,
            MEMO_DET, 
            TRNS_DATE     ,
            entry_type    ,
            post_flag     )
            values(ldgr_rec.TRNS_TYPE_CODE,
            ldgr_rec.TRNS_SERIAL   , 
            ldgr_rec.VOUCHER_NO    , 
            CUSTOM_ACCOUNT_NO    , 
            ldgr_rec.COST_CODE     ,
            ldgr_rec.COST_CODE2     ,  
            -1 * ldgr_rec.TOTAL_value  , 
            ldgr_rec.DOC_NO        , 
            ldgr_rec.ENTRY_DESC    , 
            ldgr_rec.MEMO          , 
            LDGR_REC.MEMO_DET,
            ldgr_rec.TRNS_DATE     ,
            ldgr_rec.entry_type    ,
            ldgr_rec.post_flag );
            total_value := total_value - ldgr_rec.TOTAL_value ;            
        END IF;        
    END LOOP;
    D_TOT_VAL := total_value;
    RETURN (TRUE );                        
    
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit HANDLE_VNDR_SRVS (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION HANDLE_VNDR_SRVS (in_trns_type_code         IN NUMBER,
                                             in_serial_number          IN NUMBER,
                                             IN_Entry_No               IN NUMBER,
                                             IN_Account_No_Type     IN NUMBER,
                                             IN_Account_No                IN NUMBER,
                                             IN_cost_No                    IN NUMBER,
                                             IN_cost_No2                  IN NUMBER,
                                             IN_Cost_No_Type             IN NUMBER,
                                             IN_Cost_No2_Type            IN NUMBER,
                                             IN_Value_Type          IN NUMBER,
                                             IN_doc_no              IN NUMBER,
                                             IN_date                IN DATE,
                                             IN_Account_Ind                IN NUMBER,
                                             in_Trns_Post_type      IN NUMBER,
                                             in_entry_type                IN NUMBER,
                                             IN_trns_desc                  IN VARCHAR2,
                                             IN_trns_type_desc      IN VARCHAR2,
                                             IN_REQUEST_NO        IN VARCHAR2,
                                             IN_REQUEST_NO_E        IN VARCHAR2,
                                             D_TOT_VAL                        OUT NUMBER ) RETURN BOOLEAN IS

        Ldgr_Rec              st_ledger%rowtype;
        w_status                            NUMBER;
        w_value                                NUMBER;
        total_value                        NUMBER:=0;
        EXT_SUPP_FLAG                    NUMBER;
BEGIN

        FOR VNDR_REC IN (Select      ACCOUNT_NO, NVL(FREIGHT_VAL,0) + NVL(OTHERS_VAL,0) +
                                                            NVL(CUSTOMS_VAL,0) + NVL(TRNSPORT_VAL,0) +
                                                            NVL(INSURANCE_VAL,0) + NVL(COMMISSION_VAL,0) VNDR_EXP,
                                                            NVL(TAX_VALUE1,0) TAX_VALUE1 , SUPPLIER_CODE
                                                                    From         ST_TRNS_DET_EXPENS D,SUPPLIER S
                                                                  Where   d.trns_type_code = in_trns_type_code
                                                                    and         d.trns_serial = in_serial_number
                                                                    and         s.CODE     = d.SUPPLIER_CODE)LOOP 
                                        
--        MESSAGE('1'); PAUSE;                         
                            If IN_Entry_No is not null then
                                   Ldgr_Rec.Voucher_No := IN_Entry_No;
                            end if;
--        MESSAGE('2'); PAUSE;                         
                                     Ldgr_Rec.Account_No:= VNDR_rec.Account_no;
--        MESSAGE('3'); PAUSE;                         

                                  If Ldgr_Rec.Account_No is null Then 
                                  insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                   values (in_trns_type_code,in_serial_number,
                                                          ' رقم الحساب غير موجود ');
                                                Return (FALSE);
                                  End If;
                                        
--        MESSAGE('4'); PAUSE;                         
                                        begin 
                                  select account_status
                                  into w_status
                                  from ac_master
                                  where account_number = ldgr_rec.account_no;

                              if w_status = 0 then
                                    insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                     values (in_trns_type_code,in_serial_number,
                                                            ' رقم الحساب ليس على أدنى مستوى ');
                                    return(FALSE);
                                   end if;
                            exception
                                   when others then      
                                        insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                         values (in_trns_type_code,in_serial_number,
                                                                ' رقم الحساب بملف الخدمات غير موجود فى نظام الحسابات ');
                                        return(FALSE);
                            end;
--        MESSAGE('5'); PAUSE;                         

                                        if IN_Cost_No_Type=1 then
                                      Ldgr_Rec.Cost_Code:= IN_Cost_No;
                                  End If;
                                  
                                  if IN_Cost_No2_Type=1 then
                                      Ldgr_Rec.Cost_Code2:= IN_Cost_No2;
                            End If; 

        -- MESSAGE(ldgr_rec.cost_code2); PAUSE;                         

                               IF CHECK_COST_CENTERS(in_trns_type_code,in_serial_number,ldgr_rec.cost_code,ldgr_rec.cost_code2)= FALSE THEN 
                                                                    RETURN (FALSE);
                                        END IF;
                                                               
                                        BEGIN
                                        SELECT  NVL(EXT_SUPP_FLAG,0) 
                                        INTO    EXT_SUPP_FLAG
                                        FROM    TX_TAXES_SUPPLIERS
                                        WHERE   SUPPLIER_CODE = VNDR_REC.SUPPLIER_CODE AND TAX_CODE = 1;
                                        EXCEPTION
                                            WHEN OTHERS THEN
                                                EXT_SUPP_FLAG := 0 ;
                                        END;
                                                          
                          if nvl(IN_Value_Type,0)=25 then
                                  w_value := nvl(VNDR_rec.VNDR_EXP,0) + ABS(EXT_SUPP_FLAG-1) * NVL(VNDR_REC.TAX_VALUE1,0);
                          Else
                                   insert into st_post_msg (trns_type_code,trns_serial,message) 
                                                   values (in_trns_type_code,in_serial_number,
                                               ' خطأ فى مؤشر القيمة ');
                                        Return (FALSE);
                          End If;               
                          
                            If nvl(IN_Account_Ind,0) = 2 Then   --دائن
                                   ldgr_rec.TOTAL_value := nvl(w_value,0) * -1;
                                   total_value := total_value - nvl(w_value,0) ;
                            else
                                   ldgr_rec.TOTAL_value := nvl(w_value,0);
                                   total_value := total_value + nvl(w_value,0) ;
                            End If;
              
                -- Construct The ST_LEDGER Record
--        MESSAGE('8'); PAUSE;                         

                            ldgr_rec.doc_no         := IN_doc_no ;
                            ldgr_rec.trns_date      := IN_date   ;
                            ldgr_rec.trns_type_code := in_trns_type_code ;
                            ldgr_rec.trns_serial    := in_serial_number  ;
                            ldgr_rec.post_flag      := in_Trns_Post_type;
                            ldgr_rec.entry_type     := in_entry_type;

                            if in_Trns_Post_type = 1 then
                                if IN_trns_desc is null then
                                    ldgr_rec.entry_desc  :=  IN_trns_type_desc;
                                 else 
                                    ldgr_rec.entry_desc  :=  IN_trns_desc;
                                 end if;
                                             if g_lang = 'A' then
                                         ldgr_rec.memo           := ' حركة رقم '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
                                                else
                                         ldgr_rec.memo           := ' Transaction no '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
                                                end if;
                            elsif in_Trns_Post_type = 2 then
                                ldgr_rec.entry_desc     := IN_trns_type_desc;
                                                if g_lang = 'A' then
                                         ldgr_rec.memo           := ' نوع حركة رقم '||to_char(in_trns_type_code);
                                                else
                                         ldgr_rec.memo           := ' Transaction type no '||to_char(in_trns_type_code);
                                                end if;
                            elsif in_Trns_Post_type = 3 then
                                                if g_lang = 'A' then
                                         ldgr_rec.entry_desc     := 'قيد مجمع مرحل من المخازن';
                                                else
                                         ldgr_rec.entry_desc     := 'Composed record from stores';
                                                end if;
                                        
                                 ldgr_rec.memo           := null;
                            end if ;
                            

                    
--message('bbbb ldgr_rec.TOTAL_value = ' ||  ldgr_rec.TOTAL_value || '  total_value= ' ||  total_value ); pause; 
                        if nvl(w_value,0) != 0  then
                       insert into st_ledger (TRNS_TYPE_CODE,
                                               TRNS_SERIAL   , 
                                       VOUCHER_NO    , 
                                       ACCOUNT_NO    , 
                                       COST_CODE     , 
                                       TOTAL_value   , 
                                       DOC_NO        , 
                                       ENTRY_DESC    , 
                                       MEMO          ,
                                       MEMO_DET, 
                                       TRNS_DATE     ,
                                       entry_type    ,
                                       post_flag     )
                                values(ldgr_rec.TRNS_TYPE_CODE,
                                       ldgr_rec.TRNS_SERIAL   , 
                                       ldgr_rec.VOUCHER_NO    , 
                                       ldgr_rec.ACCOUNT_NO    , 
                                       ldgr_rec.COST_CODE     , 
                                       ldgr_rec.TOTAL_value   , 
                                       ldgr_rec.DOC_NO        , 
                                       ldgr_rec.ENTRY_DESC    , 
                                       ldgr_rec.MEMO          , 
                                       LDGR_REC.MEMO_DET,
                                       ldgr_rec.TRNS_DATE     ,
                                       ldgr_rec.entry_type    ,
                                       ldgr_rec.post_flag );
              end if;
        END LOOP;
--        PAUSE;
        D_TOT_VAL := total_value;
        RETURN (TRUE );                        
                                    
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit MAKE_ENTRY (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION MAKE_ENTRY (IN_TRNS_TYPE_CODE ST_TRNS_MAST.TRNS_TYPE_CODE%TYPE,
                                         IN_SERIAL_NUMBER  ST_TRNS_MAST.TRNS_SERIAL%TYPE,
                                         IN_ENTRY_TYPE     ST_TRNS_TYPE.ENTRY_TYPE%TYPE,
                                         IN_STORE_CODE     ST_STORE.STORE_CODE%TYPE,
                                         IN_TRNS_POST_TYPE ST_TRNS_TYPE.POST_TYPE%TYPE)
RETURN BOOLEAN 
IS
    W_DOC_NO               ST_TRNS_MAST.DOC_NO%TYPE;    
    W_ACCOUNT_NUMBER2_DESC AC_YEARLY_TRN_DET.MEMO%TYPE;
    W_ACCOUNT_NUMBER3_DESC AC_YEARLY_TRN_DET.MEMO%TYPE;
    W_ACCOUNT_NUMBER4_DESC AC_YEARLY_TRN_DET.MEMO%TYPE;
    W_ITEMS_TOTAL_CURR      NUMBER(30,15);
    W_TRANSACTION_TOTAL     NUMBER(30,15);
    W_COST_TOTAL            NUMBER(30,15);
    W_COST_TOTAL2           NUMBER(30,15);
    W_FREIGHT_AMOUNT        NUMBER(30,15);
    W_DISCOUNT_AMOUNT       NUMBER(30,15);
    W_CUSTOMS               NUMBER(30,15);
    W_TRNSPORT              NUMBER(30,15);
    W_INSURANCE             NUMBER(30,15); 
    W_COMMISSION            NUMBER(30,15); 
    W_OTHERS                NUMBER(30,15);
    W_SALES_TOTAL_11        NUMBER;
    W_PAYMENT               NUMBER(30,15);
    W_ATM_AMMOUNT           NUMBER(30,15);
    W_VISA_AMMOUNT          NUMBER(30,15);
    W_CARD_AMMOUNT          NUMBER(30,15);
    W_CHECK_AMMOUNT         NUMBER(30,15);
    W_AMEX_AMMOUNT          NUMBER(30,15);
    W_DATE                  DATE;
    W_DISC_VAL              NUMBER(30,15);
    W_DET_DISC              NUMBER(30,15);
    W_SUPP_COSTS            NUMBER(30,15);
    W_GAMAREK_TAKHLIS_NAKL  NUMBER(30,15);
    W_BANKIA                NUMBER(30,15);
    W_TAMIN                 NUMBER(30,15);
    W_OKHRA                 NUMBER(30,15);
    D_TOT_VAL               NUMBER;
    TRNS_ACCOUNT1           NUMBER(12);
    TRNS_ACCOUNT2           NUMBER(12);
    TRNS_ACCOUNT3           NUMBER(12);
    TRNS_ACCOUNT4           NUMBER(12);
    W_COST                  NUMBER(9);
    W_COST2                 NUMBER(9);
    STORE_ACCOUNT1          NUMBER(12);
    STORE_ACCOUNT2          NUMBER(12);
    STORE_ACCOUNT3          NUMBER(12);
    STORE_ACCOUNT4          NUMBER(12);
    S_COST                  NUMBER(9);
    GROUP_ACCOUNT           NUMBER(12);
    G_COST                  NUMBER(9);
    CUSTOMER_ACCOUNT        NUMBER(12);
    CUSTOMER_NAME           VARCHAR2(200);
    V_DESC_A                VARCHAR2(2000);
    CUSTOMER_DIS_ACCOUNT    NUMBER(12);
    SUPPLIER_ACCOUNT        NUMBER(12);
    W_SERVICE               NUMBER;
    TOTAL_VALUE             NUMBER(30,15);
    W_VALUE                 NUMBER;
    LDGR_REC                ST_LEDGER%ROWTYPE;
    W_STATUS                AC_MASTER.ACCOUNT_STATUS%TYPE;
    TRNS_DESC               ST_TRNS_MAST.DESC_A%TYPE;  
    TRNS_TYPE_DESC          ST_TRNS_TYPE.DESC_A%TYPE;  
    W_CUSTOMER_CODE         ST_TRNS_MAST.CUSTOMER_CODE%TYPE;
    W_SUPPLIER_CODE         ST_TRNS_MAST.POSTING_SUPPLIER_CODE%TYPE;
    W_REQUEST_NO            ST_TRNS_MAST.DESC_A%TYPE;
    W_REQUEST_NO_E          ST_TRNS_MAST.DESC_A%TYPE;
    V_EFFECT                NUMBER;
    V_TRNS_TYPE             NUMBER;
    V_STORE                 NUMBER;
    SUPPLIER_NAME           VARCHAR2(200);
    TEMP_TOTAL_VALUE        NUMBER;
    DEF                     NUMBER;
    V_PAY_TYPE_CODE         NUMBER;   
    V_ATM_DESC              VARCHAR2(2000);
    V_ACCOUNT_NO            NUMBER; 
    V1_ATM_COMM             NUMBER;
    V1_VISA_COMM            NUMBER;
    V1_CARD_COMM            NUMBER;
    V1_AMEX_COMM            NUMBER;
    V1_STORE_CODE           NUMBER;
    W_COMM_AMMOUNT          NUMBER;
    V_STORE_NAME            VARCHAR2(250);
    W_TAX_VALUE1            NUMBER;
    W_TAX_TEMP              NUMBER;
    EXT_SUPP_FLAG           NUMBER;
    V_BROKER_VALUE          NUMBER;
    V_ITEMS_TOTAL_CURR      NUMBER;
    V_DET_DISC              NUMBER; 
    V_DISC_VAL              NUMBER;
    V_SERVICE               NUMBER;
    V_SUPP_DISC             NUMBER;
BEGIN

    SELECT DESC_A, DESC_E /*REQUEST_NO*/
      INTO W_REQUEST_NO, W_REQUEST_NO_E
      FROM ST_TRNS_MAST
      WHERE TRNS_TYPE_CODE = in_trns_type_code
       AND TRNS_SERIAL    = in_serial_number;

-----------------BROKER----------------------------------    
    BEGIN
         SELECT SUM (NVL (UNIT_PRICE, 0) * NVL (QUANTITY, 0)) ITEMS_TOTAL_CURR,
                ROUND (SUM (NVL (DET_DISC, 0)), 2) ITEMS_TOTAL_DISC,
                NVL (DISC_VAL, 0) DISC_VAL
           INTO V_ITEMS_TOTAL_CURR, V_DET_DISC, V_DISC_VAL
           FROM ST_TRNS_MAST M, ST_TRNS_DET D
          WHERE M.TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
            AND M.TRNS_SERIAL    = IN_SERIAL_NUMBER
            AND NVL (M.DELETE_FLAG, 0) = 0
            AND NVL (D.DELETE_FLAG, 0) = 0
            AND D.TRNS_TYPE_CODE(+) = M.TRNS_TYPE_CODE
            AND D.TRNS_SERIAL(+)    = M.TRNS_SERIAL
       GROUP BY NVL (DISC_VAL, 0);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    BEGIN
       SELECT NVL (ROUND (SUM (NVL (SERVICE_COST, 0) * NVL (UNITS_NO, 0)), 2), 0)
         INTO V_SERVICE
         FROM ST_TRNS_MAST M, ST_TRNS_SERVICES D
        WHERE D.TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
          AND D.TRNS_SERIAL = IN_SERIAL_NUMBER
          AND NVL (M.DELETE_FLAG, 0) = 0
          AND D.TRNS_TYPE_CODE = M.TRNS_TYPE_CODE
          AND D.TRNS_SERIAL    = M.TRNS_SERIAL;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    BEGIN
       SELECT NVL (BROKER_VALUE, 0)                     /** NVL(CURRENCY_RATE,1)*/
         INTO V_BROKER_VALUE
         FROM ST_TRNS_MAST
        WHERE TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
          AND TRNS_SERIAL    = IN_SERIAL_NUMBER;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
-----------------BROKER----------------------------------
     total_value := 0 ;
-- --------------------------------------------------------------------------      
    if nvl(in_entry_type ,0) = 0 then
      insert into st_post_msg (trns_type_code,trns_serial,message) 
    values (in_trns_type_code,in_serial_number,
                               ' رقم حركة الحسابات غير موجود ');
       return (FALSE);
    end if;

-- --------------------------------------------------------------------------  
    BEGIN
        SELECT SUM((NVL(UNIT_PRICE,0) - NVL(D.DISC1_VALUE,0) 
                                  - NVL(D.DISC2_VALUE,0)
                                  - NVL(D.DISC3_VALUE,0) 

                ) * NVL(QUANTITY,0)) ITEMS_TOTAL_CURR,
           SUM(NVL(UNIT_PRICE,0) * NVL(QUANTITY,0)) ITEMS_SALES_TOTAL_CURR,
               ROUND(SUM(NVL(DC.UNIT_COST,0) * NVL(D.BASIC_QTY,0)),2)  COST_TOTAL,
               SUM(NVL(DC.UNIT_COST,0) * NVL(D.BASIC_QTY,0))  COST_TOTAL2,
               ROUND(SUM(NVL(DET_DISC,0) + ((NVL(CURRENCY_RATE,0) * (NVL(DISC1_VALUE,0) + NVL(DISC2_VALUE,0) + NVL(DISC3_VALUE,0))) * NVL(QUANTITY,0) * NVL(FACTOR,1))),2) ITEMS_TOTAL_DISC,
               (NVL(DISC_VAL,0) + NVL(TOT_DISC1_VALUE,0) + NVL(TOT_DISC2_VALUE,0) + NVL(TOT_DISC3_VALUE,0)) DISC_VAL,
               (NVL(SUPP_FREIGHT_VAL,0) + NVL(SUPP_INSURANCE_VAL,0) + NVL(SUPP_OTHERS_VAL,0)) SUPP_COSTS,
               NVL(FREIGHT_VAL,0)  FREIGHT_VAL,   /*--BEGIN--- MODIFIED ---BY AHMED AMIN */
               NVL(CUSTOMS_VAL,0)  CUSTOMS,        
               NVL(TRNSPORT_VAL,0) TRNSPORT,   
               NVL(OTHERS_VAL,0)   OTHERS_VAL ,
               NVL(INSURANCE_VAL,0) INSURANCE, 
               NVL(COMMISSION_VAL,0) COMMISSION,  /*--END---- MODIFIED ---BY AHMED AMIN */
               NVL(PAYMENT,0), 
               NVL(ATM_AMMOUNT,0),   
               NVL(VISA_AMMOUNT,0),
               NVL(CARD_AMMOUNT,0),
               NVL(CHECK_AMMOUNT,0),
               NVL(AMEX_AMMOUNT,0),
               M.TRNS_DATE,DOC_NO,
               M.ACCOUNT_NUMBER1,
               NVL(M.ACCOUNT_NUMBER2,999999999999),
               NVL(M.ACCOUNT_NUMBER3,999999999999),
               NVL(M.ACCOUNT_NUMBER4,999999999999), 
               M.COST_CODE W_COST,
               M.COST_CODE2 W_COST2,
               M.CUSTOMER_CODE,
               M.POSTING_SUPPLIER_CODE, 
               EFFECT, 
               TRNS_TYPE,
               ACCOUNT_NUMBER2_DESC,
               ACCOUNT_NUMBER3_DESC,
               ACCOUNT_NUMBER4_DESC , 
               M.STORE_CODE , 
               NVL(ATM_DESC,DOC_NO) ATM_DESC,
               NVL(ROUND(SUM(NVL(D.TAX_VALUE1,0)),2) + NVL(M.TAX_VALUE1,0),0) TAX_VALUE1,
               ROUND(SUM(NVL(CURRENCY_RATE,0) * NVL(D.SUPP_DISC_VALUE,0) * NVL(D.QUANTITY,0)),2)
          INTO W_ITEMS_TOTAL_CURR, 
               W_SALES_TOTAL_11,
               W_COST_TOTAL,  
               W_COST_TOTAL2,
               W_DET_DISC,  
               W_DISC_VAL,
               W_SUPP_COSTS,
               W_FREIGHT_AMOUNT,
               W_CUSTOMS,
               W_TRNSPORT,
               W_OTHERS,
               W_INSURANCE , 
               W_COMMISSION , 
               W_PAYMENT,
               W_ATM_AMMOUNT,   
               W_VISA_AMMOUNT,
               W_CARD_AMMOUNT,                                
               W_CHECK_AMMOUNT,    
               W_AMEX_AMMOUNT,
               W_DATE,
               W_DOC_NO,
               TRNS_ACCOUNT1, 
               TRNS_ACCOUNT2, 
               TRNS_ACCOUNT3, 
               TRNS_ACCOUNT4,
               W_COST,
               W_COST2,
               W_CUSTOMER_CODE,
               W_SUPPLIER_CODE, 
               V_EFFECT, 
               V_TRNS_TYPE,
               W_ACCOUNT_NUMBER2_DESC,
               W_ACCOUNT_NUMBER3_DESC,
               W_ACCOUNT_NUMBER4_DESC,
               V1_STORE_CODE, 
               V_ATM_DESC,
               W_TAX_VALUE1,
               V_SUPP_DISC
          FROM ST_TRNS_MAST M, ST_TRNS_DET D, ST_TRNS_DET_COST DC, ST_TRNS_TYPE TT, ST_ITEM_UNIT UNT
         WHERE D.ITEM_CODE             = UNT.ITEM_CODE (+)
           AND D.GROUP_CODE            = UNT.GROUP_CODE(+)
           AND D.UNIT_CODE             = UNT.UNIT_CODE (+)
           AND M.TRNS_TYPE_CODE        = IN_TRNS_TYPE_CODE
           AND M.TRNS_SERIAL           = IN_SERIAL_NUMBER              
           AND NVL(M.DELETE_FLAG,0)    = 0
           AND NVL(D.DELETE_FLAG,0)    = 0
           AND D.TRNS_TYPE_CODE(+)     = M.TRNS_TYPE_CODE
           AND D.TRNS_SERIAL(+)        = M.TRNS_SERIAL
           AND D.TRNS_TYPE_CODE        = DC.TRNS_TYPE_CODE
           AND D.TRNS_SERIAL           = DC.TRNS_SERIAL
           AND D.ITEM_SERIAL           = DC.ITEM_SERIAL
           AND M.TRNS_TYPE_CODE        = TT.TRNS_TYPE_CODE              
        GROUP BY (NVL(DISC_VAL,0) + NVL(TOT_DISC1_VALUE,0) + NVL(TOT_DISC2_VALUE,0) + NVL(TOT_DISC3_VALUE,0)),
                 (NVL(SUPP_FREIGHT_VAL,0) + NVL(SUPP_INSURANCE_VAL,0) + NVL(SUPP_OTHERS_VAL,0)),
                 NVL(FREIGHT_VAL,0),NVL(CUSTOMS_VAL,0),NVL(TRNSPORT_VAL,0),NVL(INSURANCE_VAL,0),NVL(COMMISSION_VAL,0),
                 NVL(OTHERS_VAL,0),NVL(PAYMENT,0),NVL(ATM_AMMOUNT,0),NVL(VISA_AMMOUNT,0),NVL(CARD_AMMOUNT,0),
                 NVL(CHECK_AMMOUNT,0),NVL(AMEX_AMMOUNT,0),M.TRNS_DATE,DOC_NO,M.ACCOUNT_NUMBER1,M.ACCOUNT_NUMBER2,
                 M.ACCOUNT_NUMBER3,M.ACCOUNT_NUMBER4,M.COST_CODE,M.COST_CODE2,M.CUSTOMER_CODE,M.POSTING_SUPPLIER_CODE,
                 EFFECT,TRNS_TYPE,ACCOUNT_NUMBER2_DESC,ACCOUNT_NUMBER3_DESC,ACCOUNT_NUMBER4_DESC,M.STORE_CODE,
                 NVL(ATM_DESC,DOC_NO),M.TAX_VALUE1;
    END; 
  /*
    IF NVL(w_cost_total,0) = 0 THEN 
        w_cost_total := w_cost_total2;
    END IF;
  */
  BEGIN
      SELECT VISA_PRC, CARD_PRC, ATM_PRC, AMEX_PRC , ST_STORE.NAME_A
        INTO V1_VISA_COMM,V1_CARD_COMM ,V1_ATM_COMM ,V1_AMEX_COMM,V_STORE_NAME 
        FROM ST_STORE 
       WHERE ST_STORE.STORE_CODE = V1_STORE_CODE ;
  EXCEPTION WHEN OTHERS THEN   
      V1_VISA_COMM := 0 ;
      V1_ATM_COMM  := 0 ;
      V1_CARD_COMM := 0 ; 
      V1_AMEX_COMM := 0 ;
  END ;  

    BEGIN
      SELECT NVL(EXT_SUPP_FLAG,0) 
        INTO EXT_SUPP_FLAG
        FROM TX_TAXES_SUPPLIERS
       WHERE SUPPLIER_CODE = W_SUPPLIER_CODE AND TAX_CODE = 1;
    EXCEPTION WHEN OTHERS THEN
        EXT_SUPP_FLAG := 0;
    END;
    
    SELECT NVL(ROUND(SUM(NVL(SERVICE_COST,0) * NVL(UNITS_NO,0)),2),0),NVL(SUM(D.TAX_VALUE1),0)
      INTO W_SERVICE,W_TAX_TEMP
      FROM ST_TRNS_MAST M, ST_TRNS_SERVICES D 
     WHERE D.TRNS_TYPE_CODE     = IN_TRNS_TYPE_CODE
       AND D.TRNS_SERIAL        = IN_SERIAL_NUMBER
       AND NVL(M.DELETE_FLAG,0) = 0
       AND D.TRNS_TYPE_CODE     = M.TRNS_TYPE_CODE
     AND D.TRNS_SERIAL        = M.TRNS_SERIAL;

    W_TAX_VALUE1        := NVL(W_TAX_VALUE1,0) + NVL(W_TAX_TEMP,0);               
  W_COMM_AMMOUNT      := ROUND(NVL(((NVL(V1_ATM_COMM,0)/100)* NVL(W_ATM_AMMOUNT,0)),0),2)   +
                         ROUND(NVL(((NVL(V1_VISA_COMM,0)/100)* NVL(W_VISA_AMMOUNT,0)),0),2) +
                         ROUND(NVL(((NVL(V1_CARD_COMM,0)/100)* NVL(W_CARD_AMMOUNT,0)),0),2) +
                         ROUND(NVL(((NVL(V1_AMEX_COMM,0)/100)* NVL(W_AMEX_AMMOUNT,0)),0),2) ;                            
  W_ATM_AMMOUNT       := ROUND(NVL(W_ATM_AMMOUNT,0) - ROUND(NVL(((NVL(V1_ATM_COMM,0)/100)* NVL(W_ATM_AMMOUNT,0)),0),2),2) ;
  W_VISA_AMMOUNT      := ROUND(NVL(W_VISA_AMMOUNT,0) - ROUND(NVL(((NVL(V1_VISA_COMM,0)/100)* NVL(W_VISA_AMMOUNT,0)),0),2),2) ;
  W_CARD_AMMOUNT      := ROUND(NVL(W_CARD_AMMOUNT,0) - ROUND(NVL(((NVL(V1_CARD_COMM,0)/100)* NVL(W_CARD_AMMOUNT,0)),0),2),2) ;
  W_AMEX_AMMOUNT      := ROUND(NVL(W_AMEX_AMMOUNT,0) - ROUND(NVL(((NVL(V1_AMEX_COMM,0)/100)* NVL(W_AMEX_AMMOUNT,0)),0),2),2 );  
  W_DISCOUNT_AMOUNT   := NVL(W_DET_DISC,0)+ NVL(W_DISC_VAL,0);
  W_TRANSACTION_TOTAL := NVL(W_ITEMS_TOTAL_CURR,0) + NVL(W_FREIGHT_AMOUNT,0) + NVL(W_SERVICE,0) - 
                         NVL(W_DISCOUNT_AMOUNT,0) + NVL(W_CUSTOMS,0) + 
                         NVL(W_TRNSPORT,0) + NVL(W_INSURANCE,0) + 
                         NVL(W_COMMISSION,0) + NVL(W_OTHERS,0) - NVL(W_PAYMENT,0);

    /*IF V_EFFECT = 1 AND V_TRNS_TYPE =1  THEN
       W_COST_TOTAL :=  NVL(W_SALES_TOTAL_11,0) + NVL(W_SUPP_COSTS,0) +
                      NVL(W_FREIGHT_AMOUNT,0) + NVL(W_CUSTOMS,0) + NVL(W_TRNSPORT,0) + 
                      NVL(W_OTHERS,0) + NVL(W_COMMISSION,0) + NVL(W_INSURANCE,0) - NVL(W_DISCOUNT_AMOUNT,0);
    END IF; */

    BEGIN
    SELECT ACCOUNT_NO,NAME_A
      INTO CUSTOMER_ACCOUNT,CUSTOMER_NAME
      FROM CUSTOMER
     WHERE CODE = W_CUSTOMER_CODE;
  EXCEPTION WHEN OTHERS THEN
      CUSTOMER_ACCOUNT := NULL ;
  END;

  BEGIN
      SELECT ACCOUNT_NO,NAME_A
        INTO SUPPLIER_ACCOUNT,SUPPLIER_NAME
      FROM SUPPLIER
     WHERE CODE = W_SUPPLIER_CODE;
  EXCEPTION WHEN OTHERS THEN
      SUPPLIER_ACCOUNT := NULL ;
  END;

    DECLARE
        V_RETURN  NUMBER;
    BEGIN
        SELECT CUSTOMER_CODE
           INTO V_RETURN
           FROM ST_TRNS_MAST
         WHERE TRNS_TYPE_CODE = in_trns_type_code
           AND TRNS_SERIAL    = in_serial_number ;
        
        SELECT DISC_ACCOUNT
          INTO CUSTOMER_DIS_ACCOUNT
          FROM CUSTOMER
          WHERE CODE = V_RETURN;                                  
    EXCEPTION WHEN OTHERS THEN
        CUSTOMER_DIS_ACCOUNT :=NULL;
    END;
-- --------------------------------------------------------------------------  
  BEGIN
    SELECT DECODE(g_lang,'A',DESC_A,DESC_E) 
      INTO TRNS_DESC
      FROM ST_TRNS_MAST
     WHERE TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
       AND TRNS_SERIAL    = IN_SERIAL_NUMBER;
  EXCEPTION WHEN OTHERS THEN
      TRNS_DESC := NULL;
  END; 
-- --------------------------------------------------------------------------  
  BEGIN
    SELECT DECODE(g_lang,'A',DESC_A,DESC_E) 
      INTO TRNS_TYPE_DESC
      FROM ST_TRNS_TYPE
     WHERE TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE;
  EXCEPTION WHEN OTHERS THEN
      TRNS_TYPE_DESC := NULL;
  END;   
-- --------------------------------------------------------------------------  
  DECLARE
      CURSOR STACLNK_CUR IS
                    SELECT ENTRY_NO, ENTRY_SERIAL_NO, ACCOUNT_NO_TYPE, ACCOUNT_NO, COST_NO_TYPE, COST_NO, ACCOUNT_IND, VALUE_TYPE, TRNS_TYPE_CODE, COST_NO2_TYPE, COST_NO2
                      FROM STACLNK
                     WHERE TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
                  ORDER BY TRNS_TYPE_CODE,ENTRY_NO,ENTRY_SERIAL_NO;
      LINK_REC STACLNK_CUR%ROWTYPE; 
    BEGIN
        OPEN  STACLNK_CUR;
      FETCH STACLNK_CUR INTO LINK_REC;
         
         IF STACLNK_CUR%NOTFOUND THEN
        CLOSE STACLNK_CUR;
          INSERT INTO ST_POST_MSG (TRNS_TYPE_CODE,TRNS_SERIAL,MESSAGE) 
                                VALUES (IN_TRNS_TYPE_CODE,IN_SERIAL_NUMBER,
                                    ' لايوجد تفاصيل قيود لهذه الحركة ');
          RETURN (FALSE);                 -- No Link Defined yet !!!!
        END IF;
        CLOSE  STACLNK_CUR;
-- --------------------------------------------------------------------------                    
    For  Link_Rec in STACLNK_CUR  Loop 
            ldgr_rec.MEMO_DET := W_REQUEST_NO || ' ' || nvl(supplier_name,'') || ' ' || nvl(w_supplier_code,'') 
            || ' ' || nvl(customer_name,'') || ' ' || nvl(w_customer_code,'');
            
            If Link_Rec.Entry_No is not null then
                Ldgr_Rec.Voucher_No := Link_Rec.Entry_No;
            end if;
---- حسابات
            If Link_Rec.Account_No_Type=1 then
                Ldgr_Rec.Account_No:= Link_Rec.Account_No;
            ELSIF Link_Rec.Account_No_Type IN (2,3,4,5,12) THEN 
                IF HANDLE_STORE(in_trns_type_code,
                                                in_serial_number,
                                                Link_Rec.Entry_No,
                                                Link_Rec.Account_No_Type,
                                                Link_Rec.Account_No,
                                                Link_Rec.Cost_No,
                                                Link_Rec.Cost_No2,
                                                Link_Rec.Cost_No_Type,
                                                Link_Rec.Cost_No2_Type,
                                                Link_Rec.Value_Type,
                                                w_doc_no,
                                                w_date,
                                                Link_Rec.Account_Ind,
                                                in_Trns_Post_type,
                                                in_entry_type,
                                                trns_desc,
                                                trns_type_desc,
                                                W_REQUEST_NO, W_REQUEST_NO_E,
                                                D_TOT_VAL)=FALSE THEN 
                                            RETURN(FALSE);
                END IF;
                total_value := total_value + ROUND(D_TOT_VAL,2);
                GOTO END_OF_STORE_DET;
            Elsif Link_Rec.Account_No_Type = 66 then    
                    SELECT DECODE(V_TRNS_TYPE,2,CR_ACCOUNT_NO,4,CR_ACCOUNT_NO,1,DB_ACCOUNT_NO,3,DB_ACCOUNT_NO,DECODE(Link_Rec.Account_Ind,2,CR_ACCOUNT_NO,DB_ACCOUNT_NO))
              INTO Link_Rec.Account_No
              FROM TX_TAXES_TYPES 
             WHERE TAX_CODE = 2;
             
                            IF HANDLE_TAX_VALUES(in_trns_type_code,
                                                            in_serial_number,
                                                            Link_Rec.Entry_No,
                                                            Link_Rec.Account_No_Type,
                                                            Link_Rec.Account_No,
                                                            Link_Rec.Cost_No,
                                                            Link_Rec.Cost_No2,
                                                            Link_Rec.Cost_No_Type,
                                                            Link_Rec.Cost_No2_Type,
                                                            Link_Rec.Value_Type,
                                                            w_doc_no,
                                                            w_date,
                                                            Link_Rec.Account_Ind,
                                                            in_Trns_Post_type,
                                                            in_entry_type,
                                                            trns_desc,
                                                            trns_type_desc,
                                                            W_REQUEST_NO, W_REQUEST_NO_E,
                                                            D_TOT_VAL)=FALSE THEN 
                            
                                                            RETURN(FALSE);
                            END IF;
                            total_value := total_value + ROUND(D_TOT_VAL,2);
                            GOTO END_OF_TAX;    
            Elsif Link_Rec.Account_No_Type = 60 then    
                            IF HANDLE_BROKER_VALUES(in_trns_type_code,
                                                            in_serial_number,
                                                            Link_Rec.Entry_No,
                                                            Link_Rec.Account_No_Type,
                                                            Link_Rec.Account_No,
                                                            Link_Rec.Cost_No,
                                                            Link_Rec.Cost_No2,
                                                            Link_Rec.Cost_No_Type,
                                                            Link_Rec.Cost_No2_Type,
                                                            Link_Rec.Value_Type,
                                                            w_doc_no,
                                                            w_date,
                                                            Link_Rec.Account_Ind,
                                                            in_Trns_Post_type,
                                                            in_entry_type,
                                                            trns_desc,
                                                            trns_type_desc,
                                                            W_REQUEST_NO, W_REQUEST_NO_E,
                                                            D_TOT_VAL)=FALSE THEN 
                            
                                                            RETURN(FALSE);
                            END IF;
                            total_value := total_value + ROUND(D_TOT_VAL,2);
                            GOTO END_OF_BROKER;                                                            
            ELSIF Link_Rec.Account_No_Type IN (15) THEN                   
                IF HANDLE_GROUP(in_trns_type_code,
                                                in_serial_number,
                                                Link_Rec.Entry_No,
                                                Link_Rec.Account_No_Type,
                                                Link_Rec.Account_No,
                                                Link_Rec.Cost_No,
                                                Link_Rec.Cost_No2,
                                                Link_Rec.Cost_No_Type,
                                                Link_Rec.Cost_No2_Type,
                                                Link_Rec.Value_Type,
                                                w_doc_no,
                                                w_date,
                                                Link_Rec.Account_Ind,
                                                in_Trns_Post_type,
                                                in_entry_type,
                                                trns_desc,
                                                trns_type_desc,
                                                W_REQUEST_NO, W_REQUEST_NO_E,
                                                D_TOT_VAL)=FALSE THEN 
                
                                                RETURN(FALSE);
                END IF;
        
                total_value := total_value + ROUND(D_TOT_VAL,2);
                GOTO END_OF_STORE_DET;                              
            Elsif Link_Rec.Account_No_Type= 6 then                    
                Ldgr_Rec.Account_No := trns_Account1;                                
            Elsif Link_Rec.Account_No_Type=7 then                 
                Ldgr_Rec.Account_No := trns_Account2;
                ldgr_rec.MEMO_DET := W_ACCOUNT_NUMBER2_DESC;
            Elsif Link_Rec.Account_No_Type = 8 then                     
                Ldgr_Rec.Account_No:= trns_Account3;
                ldgr_rec.MEMO_DET := W_ACCOUNT_NUMBER3_DESC;
            Elsif Link_Rec.Account_No_Type=9 then                     
                Ldgr_Rec.Account_No:= trns_Account4;
                ldgr_rec.MEMO_DET := W_ACCOUNT_NUMBER4_DESC;
            Elsif Link_Rec.Account_No_Type=10 then
                Ldgr_Rec.Account_No:= customer_Account;
                ldgr_rec.MEMO_DET := customer_name ;
            Elsif Link_Rec.Account_No_Type=11 then    
                SELECT PAY_TYPE_CODE
                  INTO V_PAY_TYPE_CODE
                  FROM VN_BASIC
                 WHERE SERIAL = g_company ;                 
                IF V_PAY_TYPE_CODE IS NOT NULL THEN                    
                     BEGIN
                         SELECT ACCOUNT_NO
                           INTO V_ACCOUNT_NO
                           FROM VN_PAY_METHODE_ACC
                          WHERE SUPPLIER_CODE    = w_supplier_code
                            AND SETTEL_TYPE_CODE = V_PAY_TYPE_CODE ;
                     EXCEPTION
                         WHEN OTHERS THEN
                              V_ACCOUNT_NO := NULL ;
                     END ;         
                     IF V_ACCOUNT_NO IS NULL THEN               
                          BEGIN
                           SELECT Pay_Account_Number
                          INTO V_ACCOUNT_NO
                          FROM LC_SETTEL_TYPE
                         WHERE SETTEL_TYPE_CODE = V_PAY_TYPE_CODE ;
                       EXCEPTION
                            WHEN OTHERS THEN
                              V_ACCOUNT_NO := NULL ;
                       END ;                        
                     END IF ;       
                END IF ;      
                    Ldgr_Rec.Account_No:= NVL(V_ACCOUNT_NO,supplier_Account);
                    --ldgr_rec.MEMO_DET := SUPPLIER_name ;
                  v_desc_a := SUBSTR('توريد مواد من المورد ' ||supplier_name || ' طبقا لفاتورة المورد رقم ' ||V_ATM_DESC,1,240);
                    ldgr_rec.MEMO_DET := v_desc_a ;
        Elsif Link_Rec.Account_No_Type= 13 then    
            Ldgr_Rec.Account_No := customer_DIS_account;
        Elsif Link_Rec.Account_No_Type = 16 then                    
         select BANK_ACCOUNT 
               into Ldgr_Rec.Account_No 
               from st_store 
              where   STORE_CODE =  V1_store_code ;
                            
                 IF Ldgr_Rec.Account_No  IS NULL THEN 
                 insert into st_post_msg (trns_type_code,trns_serial,message) 
                     values (in_trns_type_code,in_serial_number,
                                     ' لا يوجد حساب للبنك مربوط مع المخزن');
                                      Return (FALSE);        
                      END IF ;                
        ELSIF Link_Rec.Account_No_Type IN (14) THEN                   
                IF HANDLE_VNDR_SRVS(in_trns_type_code,
                                                in_serial_number,
                                                Link_Rec.Entry_No,
                                                Link_Rec.Account_No_Type,
                                                Link_Rec.Account_No,
                                                Link_Rec.Cost_No,
                                                Link_Rec.Cost_No2,
                                                Link_Rec.Cost_No_Type,
                                                Link_Rec.Cost_No2_Type,
                                                Link_Rec.Value_Type,
                                                w_doc_no,
                                                w_date,
                                                Link_Rec.Account_Ind,
                                                in_Trns_Post_type,
                                                in_entry_type,
                                                trns_desc,
                                                trns_type_desc,
                                                W_REQUEST_NO, W_REQUEST_NO_E,
                                                D_TOT_VAL)=FALSE THEN 
                
                                                RETURN(FALSE);
                END IF;
                total_value := total_value + ROUND(D_TOT_VAL,2);
                GOTO END_OF_VNDR_DET;                          
            Else                
                insert into st_post_msg (trns_type_code,trns_serial,message) 
                                  values (in_trns_type_code,in_serial_number,
            
                                         ' خطأ فى مؤشر رقم الحساب ');
                Return (FALSE);
            End if;

            IF     Ldgr_Rec.Account_No IS NULL THEN
                insert into st_post_msg (trns_type_code,trns_serial,message) 
                                values (in_trns_type_code,in_serial_number,
                                       ' خطأ فى مؤشر رقم الحساب ');
              Return (FALSE);
            END IF;    
---- مراكز 1 و 2
            If Link_Rec.Cost_No_Type=4 AND Link_Rec.Cost_No2_Type=4 then
                IF HANDLE_GROUP_1(in_trns_type_code,
                                                in_serial_number,
                                                Link_Rec.Entry_No,
                                                Link_Rec.Account_No_Type,
                                                Ldgr_Rec.Account_No,
                                                Link_Rec.Cost_No_Type,
                                                Link_Rec.Cost_No2_Type,
                                                Link_Rec.Value_Type,
                                                w_doc_no,
                                                w_date,
                                                Link_Rec.Account_Ind,
                                                in_Trns_Post_type,
                                                in_entry_type,
                                                trns_desc,
                                                trns_type_desc,
                                                W_REQUEST_NO, W_REQUEST_NO_E,
                                                D_TOT_VAL)=FALSE THEN 
                                                RETURN(FALSE);
                END IF;
                
                total_value := total_value + ROUND(D_TOT_VAL,2);                                    
                GOTO END_OF_GROUP_DET;
            ELSIf Link_Rec.Cost_No_Type=4 AND Link_Rec.Cost_No2_Type!=4 then                        
                IF HANDLE_GROUP_2(in_trns_type_code,
                                                in_serial_number,
                                                Link_Rec.Entry_No,
                                                Link_Rec.Account_No_Type,
                                                Ldgr_Rec.Account_No,
                                                Link_Rec.Cost_No_Type,                                                                    
                                                Link_Rec.Cost_No2_Type,
                                                Link_Rec.Value_Type,
                                                w_doc_no,
                                                w_date,
                                                Link_Rec.Account_Ind,
                                                in_Trns_Post_type,
                                                in_entry_type,
                                                trns_desc,
                                                trns_type_desc,
                                                W_REQUEST_NO, W_REQUEST_NO_E,
                                                Link_Rec.Cost_No2,
                                                W_cost2,
                                                D_TOT_VAL)=FALSE THEN 
                                                
                                                RETURN(FALSE);
                END IF;                            
                total_value := total_value + ROUND(D_TOT_VAL,2);
                GOTO END_OF_GROUP_DET;
            ELSIf Link_Rec.Cost_No_Type!=4 AND Link_Rec.Cost_No2_Type=4 then                                                        
                IF HANDLE_GROUP_3(in_trns_type_code,
                                                in_serial_number,
                                                Link_Rec.Entry_No,
                                                Link_Rec.Account_No_Type,
                                                Ldgr_Rec.Account_No,
                                                Link_Rec.Cost_No_Type,                                                                    
                                                Link_Rec.Cost_No2_Type,
                                                Link_Rec.Value_Type,
                                                w_doc_no,
                                                w_date,
                                                Link_Rec.Account_Ind,
                                                in_Trns_Post_type,
                                                in_entry_type,
                                                trns_desc,
                                                trns_type_desc,
                                                W_REQUEST_NO, W_REQUEST_NO_E,
                                                Link_Rec.Cost_No,
                                                W_cost,
                                                D_TOT_VAL)=FALSE THEN 
                                                
                                                RETURN(FALSE);
                END IF;                                                                    
                total_value := total_value + ROUND(D_TOT_VAL,2);                                
                GOTO END_OF_GROUP_DET;
            ELSIf Link_Rec.Cost_No_Type!=4 AND Link_Rec.Cost_No2_Type!=4 then                    
                If Link_Rec.Cost_No_Type=1 then
                    
                    Ldgr_Rec.Cost_code:= Link_Rec.Cost_No;
                Elsif Link_Rec.Cost_No_Type = 2 then
                  BEGIN
                      select s.cost_code
                        into Ldgr_Rec.Cost_Code
                        from st_trns_mast m,st_store s
                        where m.trns_type_code=in_trns_type_code
                        and   m.trns_serial= in_serial_number  
                        and   m.store_code=s.store_code; 
                  EXCEPTION WHEN OTHERS THEN
                      Ldgr_Rec.Cost_Code := NULL;
                    END;                                                                                                     
                Elsif Link_Rec.Cost_No_Type=3 then
                    Ldgr_Rec.Cost_Code:= w_cost;
                Elsif Link_Rec.Cost_No_Type=5 then
                    BEGIN
                        select s.cost_code
                        into Ldgr_Rec.Cost_Code
                        from st_trns_mast m,st_store s
                        where m.trns_type_code=in_trns_type_code
                        and   m.trns_serial= in_serial_number  
                        and   nvl(m.trnsfer_to_store,m.store_code)=s.store_code;                                         
                    EXCEPTION WHEN OTHERS THEN
                        Ldgr_Rec.Cost_Code := NULL;    
                    END;                             
                Elsif Link_Rec.Cost_No_Type = 6 then
                    Ldgr_Rec.Cost_Code := NULL;    
                Else
                    insert into st_post_msg (trns_type_code,trns_serial,message) 
                               values (in_trns_type_code,in_serial_number,
                                           ' خطأ فى مؤشر رقم مركز التكلفة ');
                    Return (FALSE);
                End If; 

                If Link_Rec.Cost_No2_Type=1 then                                   
                    Ldgr_Rec.Cost_code2 := Link_Rec.Cost_No2;
              Elsif Link_Rec.Cost_No2_Type=7 then
                    BEGIN
                    select s.cost_code2
                        into Ldgr_Rec.Cost_Code2
                        from st_trns_mast m,SALESMAN s
                        where m.trns_type_code=in_trns_type_code
                        and   m.trns_serial= in_serial_number  
                        and   m.SALESMAN_code= s.code;
                    EXCEPTION WHEN OTHERS THEN 
                        Ldgr_Rec.Cost_Code2 := NULL; 
                    END;                               
                Elsif Link_Rec.Cost_No2_Type=2 then
                    BEGIN
                    select s.cost_code2
                        into Ldgr_Rec.Cost_Code2
                        from st_trns_mast m,st_store s
                        where m.trns_type_code=in_trns_type_code
                        and   m.trns_serial= in_serial_number  
                        and   m.store_code= s.store_code;
                    EXCEPTION WHEN OTHERS THEN 
                        Ldgr_Rec.Cost_Code2 := NULL; 
                    END;                               
                Elsif Link_Rec.Cost_No2_Type = 3 then
                    Ldgr_Rec.Cost_Code2:= w_cost2;
                Elsif Link_Rec.Cost_No2_Type = 5 then
                    BEGIN
                        select s.cost_code2
                        into   Ldgr_Rec.Cost_Code2
                        from   st_trns_mast m,st_store s
                        where  m.trns_type_code = in_trns_type_code
                        and    m.trns_serial    = in_serial_number  
                        and    m.trnsfer_to_store = s.store_code;      
                    EXCEPTION WHEN OTHERS THEN
                        Ldgr_Rec.Cost_Code2 := NULL;
                    END;
                Elsif Link_Rec.Cost_No2_Type = 6 then
                    Ldgr_Rec.Cost_Code2 := NULL;    
                Else
                    insert into st_post_msg (trns_type_code,trns_serial,message) 
                                       values (in_trns_type_code,in_serial_number,
                                               '2 خطأ فى مؤشر رقم مركز التكلفة ');
                    Return (FALSE);           
                End If; 
            END IF;
            -- --------------------------------------------------------------------------  
            -- Check cost_number
            IF     CHECK_COST_CENTERS(in_trns_type_code,in_serial_number,
                    ldgr_rec.cost_code,ldgr_rec.cost_code2)= FALSE THEN 
                RETURN (FALSE);
            END IF;
            -- --------------------------------------------------------------------------  
            --        PAUSE;MESSAGE('9999');PAUSE;                        
            If nvl(Link_Rec.Value_Type,0)=1 then
                w_value := nvl(w_Items_Total_CURR,0);
            Elsif nvl(Link_Rec.Value_Type,0)=5 then
              w_value := NVL(W_DET_DISC,0)+ NVL(W_DISC_VAL,0);
            Elsif nvl(Link_Rec.Value_Type,0)=36 then
              w_value := NVL(W_DET_DISC,0);
            Elsif nvl(Link_Rec.Value_Type,0)=37 then
              w_value := NVL(W_DISC_VAL,0);
            Elsif nvl(Link_Rec.Value_Type,0)=35 then
              w_value := NVL(W_SALES_TOTAL_11,0);
            Elsif nvl(Link_Rec.Value_Type,0) = 8 then
                w_value := nvl(W_Items_Total_CURR,0)+
                       NVL(W_SUPP_COSTS,0) + 
                       NVL(w_Freight_Amount,0) + nvl(w_service,0) +
                                 NVL(w_customs,0) +
                       NVL(w_trnsport,0) + 
                       NVL(w_others,0) + NVL(W_INSURANCE , 0 ) + NVL(W_COMMISSION , 0 ) ;                           
            Elsif nvl(Link_Rec.Value_Type,0) = 2 then
                        w_value := nvl(W_SALES_TOTAL_11,0) -
                                             /*nvl(w_payment,0) - 
                                             NVL(W_ATM_AMMOUNT,0) -
                                             NVL(W_visa_ammount,0)-
                                             NVL(W_card_ammount,0)-
                                             NVL(W_CHECK_ammount,0)-
                                             NVL(W_AMEX_AMMOUNT,0) -*/
                                    NVL(W_DET_DISC,0) -
                                    NVL(W_DISC_VAL,0) +
                                    NVL(W_SUPP_COSTS,0) + 
                                    NVL(w_Freight_Amount,0) + nvl(w_service,0) +
                                              NVL(w_customs,0) +
                                    NVL(w_trnsport,0) + 
                                    NVL(w_others,0) + 
                                    NVL(W_INSURANCE , 0 ) + 
                                    NVL(W_COMMISSION , 0 ) + nvl(w_tax_value1,0);  
            Elsif nvl(Link_Rec.Value_Type,0) = 34 then
                        w_value := nvl(W_SALES_TOTAL_11,0) -
                                             /*nvl(w_payment,0) - 
                                             NVL(W_ATM_AMMOUNT,0) -
                                             NVL(W_visa_ammount,0)-
                                             NVL(W_card_ammount,0)-
                                             NVL(W_CHECK_ammount,0)-
                                             NVL(W_AMEX_AMMOUNT,0) -*/
                                    NVL(W_DET_DISC,0) -
                                    NVL(W_DISC_VAL,0) +
                                    NVL(W_SUPP_COSTS,0) + 
                                    NVL(w_Freight_Amount,0) + nvl(w_service,0) +
                                              NVL(w_customs,0) +
                                    NVL(w_trnsport,0) + 
                                    NVL(w_others,0) + 
                                    NVL(W_INSURANCE , 0 ) + 
                                    NVL(W_COMMISSION , 0 );                          
            Elsif nvl(Link_Rec.Value_Type,0)=60 then
                                  w_value := (nvl(W_Items_Total_CURR,0)-
                                                NVL(W_DET_DISC,0) -
                                                NVL(W_DISC_VAL,0) + 
                                                NVL(W_SUPP_COSTS,0) + 
                                                NVL(w_Freight_Amount,0) + nvl(w_service,0) +
                                                NVL(w_customs,0) +
                                                NVL(w_trnsport,0) + 
                                                NVL(w_others,0) + 
                                                NVL(W_INSURANCE , 0 ) + 
                                                NVL(W_COMMISSION , 0 ) ) - (((nvl(W_Items_Total_CURR,0)-
                                                NVL(W_DET_DISC,0) -
                                                NVL(W_DISC_VAL,0) + 
                                                NVL(W_SUPP_COSTS,0) + 
                                                NVL(w_Freight_Amount,0) + nvl(w_service,0) +
                                                NVL(w_customs,0) +
                                                NVL(w_trnsport,0) + 
                                                NVL(w_others,0) + 
                                                NVL(W_INSURANCE , 0 ) + 
                                                NVL(W_COMMISSION , 0 ))* ( NVL(V_BROKER_VALUE,0) /(nvl(V_Items_Total_CURR,1)-
                                                NVL(V_DET_DISC,0) -
                                                NVL(V_DISC_VAL,0) + nvl(V_service,0)  ))/** 100*/)) ;        
            Elsif nvl(Link_Rec.Value_Type,0)= 12 then
                w_value := nvl(W_SALES_TOTAL_11,0) - 
                       NVL(W_DET_DISC,0) -
                       NVL(W_DISC_VAL,0) + 
                       NVL(W_SUPP_COSTS,0)-
                       nvl(w_payment,0) - 
                       nvl(W_ATM_AMMOUNT,0) -
                       NVL(W_visa_ammount,0)-
                                 NVL(W_card_ammount,0)-
                                 NVL(W_CHECK_ammount,0)-
                                 NVL(W_AMEX_AMMOUNT,0)  + ABS(EXT_SUPP_FLAG-1) * w_tax_value1;
        Elsif nvl(Link_Rec.Value_Type,0)= 33 then
                w_value := nvl(W_SALES_TOTAL_11,0) - 
                       NVL(W_DET_DISC,0) -
                       NVL(W_DISC_VAL,0) + 
                       NVL(W_SUPP_COSTS,0)-
                       nvl(w_payment,0) - 
                       nvl(W_ATM_AMMOUNT,0) -
                       NVL(W_visa_ammount,0)-
                                 NVL(W_card_ammount,0)-
                                 NVL(W_CHECK_ammount,0)-
                                 NVL(W_AMEX_AMMOUNT,0);
            Elsif nvl(Link_Rec.Value_Type,0)=4 then
                w_value := NVL(w_Freight_Amount,0);
            Elsif nvl(Link_Rec.Value_Type,0)=6 then
                w_value := NVL(w_customs,0);
            Elsif nvl(Link_Rec.Value_Type,0)=7 then
                w_value := NVL(W_INSURANCE,0);
            Elsif nvl(Link_Rec.Value_Type,0)=10 then
                w_value := NVL(w_others,0);                                   
            Elsif nvl(Link_Rec.Value_Type,0)=3 then
                w_value := nvl(w_cost_Total,0);
            Elsif nvl(Link_Rec.Value_Type,0)= 9 then
                w_value := nvl(w_commission,0);
            Elsif nvl(Link_Rec.Value_Type,0)=11 then
                 w_value := nvl(w_payment,0);
            Elsif nvl(Link_Rec.Value_Type,0)=17 then
                  w_value := nvl(w_atm_ammount,0);
                  ldgr_rec.MEMO_DET := 'قيمة المسدد شبكة ' || v_store_name;
            Elsif nvl(Link_Rec.Value_Type,0)=18 then
                  w_value := nvl(w_visa_ammount,0);
                  ldgr_rec.MEMO_DET := 'قيمة المسدد فيزا ' || v_store_name;
            Elsif nvl(Link_Rec.Value_Type,0)=19 then
                  w_value := nvl(w_card_ammount,0);
                  ldgr_rec.MEMO_DET := 'قيمة المسدد ماستر ' || v_store_name;
            Elsif nvl(Link_Rec.Value_Type,0)= 20 then
                  w_value := nvl(w_CHECK_ammount,0);                                           
            Elsif nvl(Link_Rec.Value_Type,0)= 21 then
                  w_value := nvl(w_amex_ammount,0);
                  ldgr_rec.MEMO_DET := 'قمية المسدد اماكس ' || v_store_name;
      Elsif nvl(Link_Rec.Value_Type,0)= 22 then
                  w_value := nvl(V_SUPP_DISC,0);
                  ldgr_rec.MEMO_DET := 'قمية الخصم للمورد ' || v_store_name;
            Elsif nvl(Link_Rec.Value_Type,0)= 24 then
            w_value := NVL(W_COMM_AMMOUNT ,0);
            ldgr_rec.MEMO_DET := 'عمولات بنكية';         
            Elsif nvl(Link_Rec.Value_Type,0)= 15 then
                 w_value := nvl(w_service,0);
            Elsif nvl(Link_Rec.Value_Type,0)= 16 then
                 w_value := nvl(w_trnsport,0);
            Elsif nvl(Link_Rec.Value_Type,0)= 30 then 
                w_value := nvl(w_supp_costs,0);
                v_desc_a := SUBSTR('توريد خدمات من المورد ' ||supplier_name || ' طبقا لفاتورة المورد رقم ' ||V_ATM_DESC,1,240);
                ldgr_rec.MEMO_DET := v_desc_a ;
            Elsif nvl(Link_Rec.Value_Type,0)= 66 then    
                IF HANDLE_TAX_VALUES(in_trns_type_code,
                                                in_serial_number,
                                                Link_Rec.Entry_No,
                                                Link_Rec.Account_No_Type,
                                                Link_Rec.Account_No,
                                                Link_Rec.Cost_No,
                                                Link_Rec.Cost_No2,
                                                Link_Rec.Cost_No_Type,
                                                Link_Rec.Cost_No2_Type,
                                                Link_Rec.Value_Type,
                                                w_doc_no,
                                                w_date,
                                                Link_Rec.Account_Ind,
                                                in_Trns_Post_type,
                                                in_entry_type,
                                                trns_desc,
                                                trns_type_desc,
                                                W_REQUEST_NO, W_REQUEST_NO_E,
                                                D_TOT_VAL)=FALSE THEN 
                
                                                RETURN(FALSE);
                END IF;
                total_value := total_value + ROUND(D_TOT_VAL,2);
                GOTO END_OF_TAX;
            Else
                insert into st_post_msg (trns_type_code,trns_serial,message) 
                               values (in_trns_type_code,in_serial_number,
                                       ' خطأ فى مؤشر القيمة ');
                Return (FALSE);
            End If;  
            
            If nvl(Link_Rec.Account_Ind,0) = 2 Then   --دائن
                ldgr_rec.TOTAL_value := nvl(ROUND(w_value,2),0) * -1;
                total_value := total_value - nvl(ROUND(w_value,2),0) ;
            Else
                ldgr_rec.TOTAL_value := nvl(ROUND(w_value,2),0);
                total_value := total_value + nvl(ROUND(w_value,2),0) ;
            End If;

            ldgr_rec.doc_no    := w_doc_no;
            ldgr_rec.trns_date := w_date;
            ldgr_rec.trns_type_code := in_trns_type_code ;
            ldgr_rec.trns_serial    := in_serial_number  ;
            ldgr_rec.post_flag      := in_Trns_Post_type;
            ldgr_rec.entry_type     := in_entry_type;

            if in_Trns_Post_type = 1 then
                if trns_desc is null then
                    ldgr_rec.entry_desc  :=  trns_type_desc;
                else 
                    ldgr_rec.entry_desc  :=  trns_desc;                           
                end if;
                if g_lang = 'A' then
                    ldgr_rec.memo           := ' حركة رقم '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
                else
                    ldgr_rec.memo           := ' Transaction no '||to_char(in_trns_type_code)||' / '||to_char(in_serial_number);
                end if;
            elsif in_Trns_Post_type = 2 then
                ldgr_rec.entry_desc     := trns_type_desc;
                if g_lang = 'A' then
                    ldgr_rec.memo           := ' نوع حركة رقم '||to_char(in_trns_type_code);
                else
                    ldgr_rec.memo           := ' Transaction type no '||to_char(in_trns_type_code);
                end if;
            elsif in_Trns_Post_type = 3 then
                if g_lang = 'A' then
                    ldgr_rec.entry_desc     := 'قيد مجمع مرحل من المخازن';
                else
                    ldgr_rec.entry_desc     := 'Composed record from stores';
                end if;                    
                ldgr_rec.memo           := null;
            end if ;
            
            If NVL(ldgr_rec.TOTAL_value,0) != 0  Then                   
                If Ldgr_Rec.Account_No is null AND NVL(ldgr_rec.TOTAL_value,0) != 0  Then                   
                    insert into st_post_msg (trns_type_code,trns_serial,message) 
                values (in_trns_type_code,in_serial_number,
                                      ' 1رقم الحساب غير موجود ');
                    Return (FALSE);

                    begin 
                        select account_status
                        into w_status
                        from ac_master
                        where account_number = ldgr_rec.account_no;

                        if w_status = 0 then
                            insert into st_post_msg (trns_type_code,trns_serial,message) 
                                         values (in_trns_type_code,in_serial_number,
                                                ' رقم الحساب ليس على أدنى مستوى ');
                        return(false);
                        end if;
                    exception
                        when others then      
                        insert into st_post_msg (trns_type_code,trns_serial,message) 
                                 values (in_trns_type_code,in_serial_number,
                                        ' رقم الحساب غير موجود فى نظام الحسابات ');
                        return(false);
                    end;
                End If;
                insert into st_ledger (TRNS_TYPE_CODE,
                               TRNS_SERIAL   , 
                               VOUCHER_NO    , 
                               ACCOUNT_NO    , 
                               COST_CODE     , 
                               COST_CODE2    , 
                               TOTAL_value   , 
                               DOC_NO        , 
                               ENTRY_DESC    , 
                               MEMO          ,
                               MEMO_DET      ,  
                               TRNS_DATE     ,
                               entry_type    ,
                               post_flag     )
                values(ldgr_rec.TRNS_TYPE_CODE,
                               ldgr_rec.TRNS_SERIAL   , 
                               ldgr_rec.VOUCHER_NO    , 
                               ldgr_rec.ACCOUNT_NO    , 
                               ldgr_rec.COST_CODE     , 
                               ldgr_rec.COST_CODE2     , 
                               ldgr_rec.TOTAL_value   , 
                               ldgr_rec.DOC_NO        , 
                               ldgr_rec.ENTRY_DESC    , 
                               ldgr_rec.MEMO          ,
                               ldgr_rec.MEMO_DET          ,  
                               ldgr_rec.TRNS_DATE     ,
                               ldgr_rec.entry_type    ,
                               ldgr_rec.post_flag );
        --pause;message(ldgr_rec.TOTAL_value);
                --PAUSE;MESSAGE('END');                                                                                             
            END IF;                             
            <<END_OF_STORE_DET>>
            <<END_OF_VNDR_DET>>                        
            <<END_OF_GROUP_DET>>
            <<END_OF_TAX>>                
            <<END_OF_BROKER>>                                                                                                        
            NULL;
        End Loop;
        
    --    COMMIT;EXIT_FORM;
        select SUM(total_value)
        into  temp_total_value
        from st_ledger
        WHERE trns_type_code = in_trns_type_code and
        trns_serial = in_serial_number;

        if temp_total_value != 0 then          
            if abs(temp_total_value) < 1 then -- less than 1 SR
                def := -1*temp_total_value ;
                update st_ledger
                set TOTAL_value = TOTAL_value + def
                WHERE trns_type_code = in_trns_type_code and
                trns_serial = in_serial_number AND
                ROWNUM = 1 
                AND TOTAL_value>0;
            else
                insert into st_post_msg (trns_type_code,trns_serial,message) 
                        values (in_trns_type_code,in_serial_number,
                                ' القيد غير متوازن ');
                return(false);
            end if;
        end if;
    END;
  return(true);
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit PUT_ENTRY_HEADER (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION put_entry_header (    in_trns_date    in date ,
                               in_entry_YEAR   in ac_trn_codes.entry_YEAR%type ,
                               in_entry_type   in ac_trn_codes.entry_type%type ,
                               in_entry_NO     NUMBER,
                                                        w_year  OUT  ac_trn_codes.entry_year%type,
                               in_Doc_no       in ac_daily_trn.doc_no%type ,
                               in_entry_desc   in ac_daily_trn.entry_desc%type ,
                               in_entry_desc_e in ac_daily_trn.entry_desc_e%type ,
                               in_memo         in ac_daily_trn.memo%type,
                               IN_POST_SYSTEM  IN NUMBER,
                               IN_TRNS_TYPE_CODE IN NUMBER,
                               IN_TRNS_SERIAL IN NUMBER
                           )
RETURN number IS    
    w_last_ser NUMBER;
    DUMMY NUMBER := 0 ;
    DUMMY1 NUMBER := 0 ;
    DUMMY2 NUMBER := 0 ;
    DUMMY3 NUMBER := 0 ;
BEGIN
    IF IN_ENTRY_YEAR IS NULL THEN
        w_year := TO_NUMBER(TO_CHAR(in_trns_date,'YYYY'));
      w_last_ser := CALC_SERIAL(w_year , in_entry_type , in_trns_date);
    ELSE
        w_year := IN_ENTRY_YEAR;        
        select count(1)
        into   dummy
        from   ac_yearly_trn
        where  entry_year = IN_ENTRY_YEAR and
                     entry_type = in_entry_type and
                     entry_no = in_entry_NO;
        if DUMMY = 0 then
          w_last_ser := in_entry_NO;
        else
            w_last_ser := CALC_SERIAL(w_year , in_entry_type , in_trns_date);
        end if;
    END IF;    

     insert into ac_YEARLY_trn(entry_year,entry_type,entry_no,doc_no,
                          entry_date,entry_desc,entry_desc_e,currency_code,rate,
                          entry_total,memo,create_company_code,create_password_number,
                           create_user_code, CREATE_DATE, CLOSE_FLAG,POST_SYSTEM)
  values           (w_year,in_entry_type,w_last_ser,in_Doc_no,in_trns_date,
                          in_entry_desc,
                          in_entry_desc_e,
                          1,1,0,in_memo,g_company,g_password,
                          g_user, SYSDATE, 0,IN_POST_SYSTEM);
    return(w_last_ser);  
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit PUT_ENTRY_DET (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
PROCEDURE put_entry_det(in_trns_date     in st_ledger.trns_date%type, 
                        in_entry_YEAR    in NUMBER, 
                        in_entry_type    in st_ledger.entry_type%type, 
                        in_last_serial   in number,
                        out_seq_w        in out number,
                        in_account_no    in st_ledger.account_no%type, 
                        in_total_value   in st_ledger.total_value%type, 
                        in_cost_code     in st_ledger.cost_code%type,
                        in_cost_code2    in st_ledger.cost_code2%type,
                        in_memo          in st_ledger.memo%type,
                        P_SUPPLIER_DESC  VARCHAR2  ,
                        P_SUPPLIER_DESC_E VARCHAR2  ,
                        P_STORE_DESC      VARCHAR2  ,
                        P_STORE_DESC_E      VARCHAR2  )
IS
    w_account_name    ac_daily_trn_det.entry_desc%type;
     w_account_name_e  ac_daily_trn_det.entry_desc%type;
    V_COUNT NUMBER;
    var_desc varchar2(1000);
    var_desc_e varchar2(1000);
BEGIN

    begin
     select account_name , account_name_e
       into w_account_name , w_account_name_e
       from ac_master
      where account_number = in_account_no;
    exception
     when others then
       w_account_name   := '';
       w_account_name_e := '';
    end;
/*
    if g_cust_code in ('BEN') then
        SELECT COUNT(1)
        INTO V_COUNT 
        FROM AC_YEARLY_TRN_DET
        WHERE ENTRY_YEAR=in_entry_YEAR
        AND ENTRY_TYPE=in_entry_type
        AND ENTRY_NO=in_last_serial
        AND ACCOUNT_NUMBER=in_ACCOUNT_No
        AND NVL(COST_CODE,0)=NVL(in_COST_CODE,0)
        AND NVL(COST_CODE2,0)=NVL(in_COST_CODE,0)
        AND SIGN(VALUE)=SIGN(in_total_value);
        
        IF V_COUNT>0 THEN
            UPDATE AC_YEARLY_TRN_DET
            SET VALUE=VALUE + in_total_value
            WHERE ENTRY_YEAR=in_entry_YEAR
            AND ENTRY_TYPE=in_entry_type
            AND ENTRY_NO=in_last_serial
            AND ACCOUNT_NUMBER=in_ACCOUNT_No
            AND NVL(COST_CODE,0)=NVL(in_COST_CODE,0)
            AND NVL(COST_CODE2,0)=NVL(in_COST_CODE,0);

             out_seq_w := out_seq_w + 1;
             
             RETURN;
        END IF;
    END IF;
*/
select confg_a
into var_desc
from general_fixed_parameter ;

VAR_DESC  := w_account_name ;
VAR_DESC_E:=      w_account_name_e ;
    
    insert into ac_YEARLY_trn_det (ENTRY_YEAR     ,
                               ENTRY_TYPE     ,
                               ENTRY_NO       ,
                               SEQ            ,
                               ACCOUNT_NUMBER ,
                               ENTRY_DESC   ,
                               ENTRY_DESC_E  ,
                               VALUE          ,
                               COST_CODE      ,
                               COST_CODE2     ,
                               BALANCE_FLAG   ,
                               MEMO           ,
                               MEMO_E         , ENTRY_DATE, CLOSE_VALUE ,
                               CREATE_COMPANY_CODE, CREATE_PASSWORD_NUMBER, 
                               CREATE_USER_CODE   , CREATE_DATE
                               ) 
                       values (in_entry_YEAR,
                               in_entry_type   ,
                               in_last_serial  ,
                               out_seq_w       ,
                               in_ACCOUNT_No   ,
                               VAR_DESC   ,  
                               VAR_DESC_E   ,  
                               in_total_value  ,
                               in_COST_CODE    ,
                               in_COST_CODE2   ,
                               0               ,
                               in_MEMO         ,
                               null            , in_trns_date ,0,
                               g_company, g_password, 
                               g_user   , SYSDATE
                               ) ;
     out_seq_w := out_seq_w + 1;
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit CHECK_VALID_POSTING (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION Check_Valid_posting(P_TRNS_TYPE_CODE NUMBER,P_TRNS_SERIAL NUMBER) RETURN BOOLEAN IS
    P_TRNS_DATE DATE;
    P_EFFECT NUMBER;
    P_STORE_CODE NUMBER;
    DUMMY NUMBER;
    V_CUR_BALANCE NUMBER;
    V_CUR_COST NUMBER;
    V_UNIT_COST NUMBER;
BEGIN

  SELECT    TRNS_DATE,STORE_CODE
  INTO        P_TRNS_DATE,P_STORE_CODE
  FROM        ST_TRNS_MAST
  WHERE        TRNS_TYPE_CODE = P_TRNS_TYPE_CODE AND
                  TRNS_SERIAL = P_TRNS_SERIAL;

  SELECT    EFFECT
  INTO        P_EFFECT
  FROM        ST_TRNS_TYPE
  WHERE        TRNS_TYPE_CODE = P_TRNS_TYPE_CODE;

    IF P_EFFECT IN (1,6) THEN
-- CONDITION 1 


 --as
----------------------------
    /*    FOR C_REC IN (SELECT ITEM_SERIAL, QUANTITY, UNIT_COST, UNIT_PRICE, BASIC_QTY, COST_FLAG, TRNS_TYPE_CODE,
                             TRNS_SERIAL, UNIT_CODE, GROUP_CODE, ITEM_CODE, FREIGHT, CUSTOMS, TRANSPORT, 
                             STAND_ITEM_GROUP_CODE, STAND_ITEM_CODE, STORE_CODE, RETURN_FLAG, ITEM_CONFG_ID, 
                             DET_DISC, BONUS, DISC, SUPP_INSURANCE, SUPP_FREIGHT, SUPP_OTHERS, OTHERS, 
                             UNIT_PRICE_CURR, STAND_ITEM, INSURANCE, COMMISSION, REDUC_TYPE, TRNS_DATE, DATE_SERIAL, 
                             DELETE_FLAG, TRNSFER_TYPE, TRNSFER_SERIAL, TRNSFER_FROM_STORE, TRNSFER_TO_STORE, 
                             OPER_TRNS_TYPE_CODE, OPER_TRNS_SERIAL, OPER_SEQ
                      FROM ST_TRNS_DET 
                                    WHERE TRNS_TYPE_CODE = P_TRNS_TYPE_CODE AND
                                                TRNS_SERIAL = P_TRNS_SERIAL) LOOP
            IF NVL(C_REC.QUANTITY,0) != 0 AND NVL(C_REC.UNIT_COST,0) <= 0 THEN
                INSERT INTO ST_POST_MSG (TRNS_TYPE_CODE,TRNS_SERIAL,MESSAGE) 
        VALUES (P_TRNS_TYPE_CODE,P_TRNS_SERIAL,'يوجد صنف بالحركة بدون تكلفة');
                
                RETURN FALSE;
            END IF;
        END LOOP;        
    ELSE*/
------------------------------------------------------




-- CONDITION 2 
/*        
        SELECT    COUNT(1)
        INTO        DUMMY
        FROM        ST_TRNS_MAST
        WHERE        (TRNS_TYPE_CODE,TRNS_SERIAL) IN 
                        (SELECT DISTINCT ST_TRNS_DET.TRNS_TYPE_CODE,TRNS_SERIAL 
                         FROM   ST_TRNS_DET,ST_TRNS_TYPE
                         WHERE    ST_TRNS_DET.TRNS_TYPE_CODE = ST_TRNS_TYPE.TRNS_TYPE_CODE AND
                                         EFFECT IN (1) AND
                                         ST_TRNS_DET.STORE_CODE = P_STORE_CODE AND
                                         TRNS_DATE <= P_TRNS_DATE AND
                                         (GROUP_CODE,ITEM_CODE) IN 
                                         (SELECT DISTINCT GROUP_CODE,ITEM_CODE
                                          FROM   ST_TRNS_DET 
                                          WHERE  TRNS_TYPE_CODE = P_TRNS_TYPE_CODE AND
                                                          TRNS_SERIAL = P_TRNS_SERIAL)) AND
                        NVL(DELETE_FLAG,0) = 0 AND
                        NVL(POST_FLAG,0) = 0 ;
        IF DUMMY > 0 THEN
                INSERT INTO ST_POST_MSG (TRNS_TYPE_CODE,TRNS_SERIAL,MESSAGE) 
        VALUES (P_TRNS_TYPE_CODE,P_TRNS_SERIAL,'يوجد حركة مشتريات او استلام تحويلات بتاريخ سابق لتاريخ الحركة غير مرحلة');
                RETURN FALSE;
        END IF;
*/
-- CONDITION 3 
                
        FOR C_REC IN (SELECT ITEM_SERIAL, QUANTITY, UNIT_COST, UNIT_PRICE, BASIC_QTY, COST_FLAG, TRNS_TYPE_CODE,
                             TRNS_SERIAL, UNIT_CODE, GROUP_CODE, ITEM_CODE, FREIGHT, CUSTOMS, TRANSPORT, 
                             STAND_ITEM_GROUP_CODE, STAND_ITEM_CODE, STORE_CODE, RETURN_FLAG, ITEM_CONFG_ID, 
                             DET_DISC, BONUS, DISC, SUPP_INSURANCE, SUPP_FREIGHT, SUPP_OTHERS, OTHERS, 
                             UNIT_PRICE_CURR, STAND_ITEM, INSURANCE, COMMISSION, REDUC_TYPE, TRNS_DATE, DATE_SERIAL, 
                             DELETE_FLAG, TRNSFER_TYPE, TRNSFER_SERIAL, TRNSFER_FROM_STORE, TRNSFER_TO_STORE, 
                             OPER_TRNS_TYPE_CODE, OPER_TRNS_SERIAL, OPER_SEQ FROM ST_TRNS_DET
                                    WHERE TRNS_TYPE_CODE = P_TRNS_TYPE_CODE AND
                                                TRNS_SERIAL = P_TRNS_SERIAL ) LOOP
                
                
                GET_BALANCE_COST_CONFG(V_CUR_BALANCE,V_CUR_COST,V_UNIT_COST,C_REC.STORE_CODE,
                                C_REC.GROUP_CODE,C_REC.ITEM_CODE,C_REC.ITEM_CONFG_ID,C_REC.TRNS_DATE,C_REC.DATE_SERIAL,C_REC.ITEM_SERIAL);
                IF nvl(V_CUR_BALANCE,0) < 0 /*OR nvl(V_CUR_COST,0) < 0 OR nvl(V_UNIT_COST,0) <= 0*/ THEN
                    INSERT INTO ST_POST_MSG (TRNS_TYPE_CODE,TRNS_SERIAL,MESSAGE) 
            VALUES (P_TRNS_TYPE_CODE,P_TRNS_SERIAL,'يوجد صنف بالحركة رصيده سالب');
                    --INSERT INTO ST_POST_MSG (TRNS_TYPE_CODE,TRNS_SERIAL,MESSAGE) 
            --VALUES (P_TRNS_TYPE_CODE,P_TRNS_SERIAL,'TRNS_DATE = ' || TO_DATE(C_REC.TRNS_DATE,'DD-MM-YYYY') || ' STORE_CODE = ' || C_REC.STORE_CODE || 'V_CUR_BALANCE = ' || V_CUR_BALANCE || 'V_CUR_COST = ' || V_CUR_COST || 'V_UNIT_COST = ' || V_UNIT_COST );
                
                    RETURN FALSE;                    
                END IF;
        END LOOP;
    END IF;
    
    RETURN TRUE;
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit PUT_ENTRY_HEADER_SECOND_TYPE (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION put_entry_header_Second_Type (
    IN_NEW_VOUCHER NUMBER,
    IN_MAX_YEAR NUMBER,
    IN_MAX_NO    NUMBER,    
    in_trns_date    in date ,
    in_entry_type   in ac_trn_codes.entry_type%type ,
    in_Doc_no       in ac_yearly_trn.doc_no%type ,
    in_entry_desc   in ac_yearly_trn.entry_desc%type ,
    in_entry_desc_e in ac_yearly_trn.entry_desc_e%type ,
    in_memo         in ac_yearly_trn.memo%type )
RETURN number IS
    w_curr_year    Number(15);
    w_last_ser     Number(15);
    
    v_curr_date        DATE;
BEGIN
    SELECT sysdate
    INTO v_curr_date
    FROM sys.dual;

    IF IN_NEW_VOUCHER=0 THEN    
      w_curr_year := TO_NUMBER (TO_CHAR(in_trns_date,'YYYY'))  ;
    ELSE
        w_curr_year := NVL(IN_MAX_YEAR,TO_NUMBER (TO_CHAR(in_trns_date,'YYYY')));
    END IF;

    
    IF IN_NEW_VOUCHER=0 THEN    
        w_last_ser:=IN_MAX_NO;
    ELSE
        begin
            select (nvl(last_serial,0) + 1) into w_last_ser
            from ac_trn_codes 
            where entry_year = w_curr_year and
            entry_type = in_entry_type;
        exception
            when no_data_found then
        
            insert into ac_trn_codes 
            (Entry_year, Entry_Type, Entry_desc, Entry_desc_e, Last_Serial,Serial_Flag)
            values 
            (w_curr_year , in_entry_type ,'قيود المخازن','Stock Entries' , 0 ,0);    
            w_last_ser := 1;
        end;
        update ac_trn_codes
        set last_serial = nvl(last_serial,0) + 1
        where entry_year = w_curr_year 
        and        entry_type = in_entry_type;
    END IF;

    insert into ac_yearly_trn(entry_year,entry_type,entry_no,doc_no,POST_SYSTEM,
    entry_date,entry_desc,entry_desc_e,currency_code,rate,
    entry_total,memo, CREATE_COMPANY_CODE, CREATE_PASSWORD_NUMBER, CREATE_USER_CODE, CREATE_DATE)
    values           (w_curr_year,in_entry_type,w_last_ser,in_Doc_no,g_system_number,in_trns_date,
    in_entry_desc,
    in_entry_desc_e,
    1,1,0,in_memo,g_company, g_password, g_user, v_curr_date);

    return(w_last_ser);  
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit SET_POST_ENTRIES (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
PROCEDURE SET_POST_ENTRIES  IS
  TRNS_REC              ST_TRNS_MAST%ROWTYPE;
  JOIN_TYPE             ST_TRNS_TYPE.JOIN_TYPE%TYPE;
  ENTRY_TYPE            ST_TRNS_TYPE.ENTRY_TYPE%TYPE;
  CUST_TRNS_CODE        ST_TRNS_TYPE.CUSTOMER_TRNS_CODE%TYPE;
  SUPP_TRNS_CODE        ST_TRNS_TYPE.SUPPLIER_TRNS_CODE%TYPE;
  PAY_SUPP_TRNS_CODE    ST_TRNS_TYPE.SUPPLIER_TRNS_CODE%TYPE;  
  TRNS_POST_TYPE        ST_TRNS_TYPE.POST_TYPE%TYPE;
  SUPP_DISC_TRNS_TYPE   ST_TRNS_TYPE.SUPP_DISC_TRNS_TYPE%TYPE;
  P_STORE_NAME          VARCHAR2(2000) ;
  P_STORE_NAME_E        VARCHAR2(2000);
  P_SUPPLIER_NAME       VARCHAR2(2000) ;
  P_SUPPLIER_NAME_E     VARCHAR2(2000) ;
  TEMP_CLOSE_DATE       DATE;
  V_DISTINCT            NUMBER := 0 ;
  V_MAX_YEAR                         NUMBER;
  V_MAX_TYPE                         NUMBER;
  V_MAX_NO                             NUMBER;
  V_NEW_VOUCHER                 NUMBER := 0;
  V_RP_TRNS_TYPE_CODE     NUMBER;
  V_RP_TRNS_SERIAL          NUMBER;
  V_PC_TRNS_TYPE_CODE     NUMBER;
  V_PC_TRNS_SERIAL            NUMBER;
  V_CUST_POST_FLAG             NUMBER;
  V_CUST_TRNS_ID                 NUMBER;
  V_CUST_TRNS_SERIAL         NUMBER;
  V_CUST_TRNS_PAY_CODE     NUMBER;
  V_CUST_TRNS_SERIAL_PAY NUMBER;
  V_SUPP_POST_FLAG      NUMBER;
  V_SUPP_TRNS_ID        NUMBER;
  V_SUPP_TRNS_SERIAL    NUMBER;
  V_CUSTOMER_ID         NUMBER;
  V_MAINAREA_ID         NUMBER;
  V_SUBAREA_ID          NUMBER;
  V_POST_SYSTEM         NUMBER;
BEGIN

  SELECT CLOSE_DATE 
    INTO TEMP_CLOSE_DATE
    FROM AC_BASIC
   WHERE COMPANY_CODE = g_company;

  -- legacy: DELETE ST_POST_MSG;  (cleared the messages of the transactions already processed in the same run;
  -- the driver now clears ST_POST_MSG once per run - see app\legacy\processes\ST_POSTING.md)
  NULL;
  -- ------------------------------------------------------------------------- 
  -- Loop On Stock transactions
  -- ------------------------------------------------------------------------- 
  SELECT MAX(AC_ENTRY_YEAR), MAX(AC_ENTRY_TYPE), MAX(AC_ENTRY_NO)
    INTO V_MAX_YEAR, V_MAX_TYPE, V_MAX_NO
    FROM ST_TRNS_MAST M, ST_TRNS_TYPE T
   WHERE T.TRNS_TYPE_CODE = M.TRNS_TYPE_CODE
     AND M.TRNS_DATE      BETWEEN g_cur.TRNS_DATE      AND g_cur.TRNS_DATE
     AND M.TRNS_TYPE_CODE BETWEEN g_cur.TRNS_TYPE_CODE AND g_cur.TRNS_TYPE_CODE
     AND M.TRNS_SERIAL    BETWEEN g_cur.TRNS_SERIAL    AND g_cur.TRNS_SERIAL
     AND NVL(M.POST_FLAG,0) = 0 
     AND NVL(M.DELETE_FLAG,0) = 0 
     AND T.EFFECT IN (1 , 2 , 3 , 4 , 5 , 6)
     AND T.JOIN_TYPE IN ( 2 , 3 , 4)
     AND (T.TRNS_TYPE <> 2 OR (T.TRNS_TYPE = 2 /*AND M.DELIVERY_DATE IS NOT NULL*/)) ;
  IF V_MAX_YEAR IS NULL OR V_MAX_TYPE IS NULL OR V_MAX_NO IS NULL    THEN    
      V_NEW_VOUCHER:=1;
  ELSE
    SELECT COUNT(1)
      INTO V_NEW_VOUCHER
      FROM ST_TRNS_MAST M, ST_TRNS_TYPE T
     WHERE T.TRNS_TYPE_CODE = M.TRNS_TYPE_CODE
       AND M.TRNS_DATE      BETWEEN g_cur.TRNS_DATE      AND g_cur.TRNS_DATE
       AND M.TRNS_TYPE_CODE BETWEEN g_cur.TRNS_TYPE_CODE AND g_cur.TRNS_TYPE_CODE
       AND M.TRNS_SERIAL    BETWEEN g_cur.TRNS_SERIAL    AND g_cur.TRNS_SERIAL
       AND NVL(M.POST_FLAG,0) = 0 
       AND NVL(M.DELETE_FLAG,0) = 0 
       AND T.EFFECT IN (1 , 2 , 3 , 4 , 5 , 6)
       AND T.JOIN_TYPE IN ( 2 , 3 , 4)
       AND (NVL(AC_ENTRY_YEAR,0) <> V_MAX_YEAR OR NVL(AC_ENTRY_TYPE,0) <> V_MAX_TYPE OR NVL(AC_ENTRY_NO,0) <> V_MAX_NO);
  END IF;

  FOR TRNS_REC IN 
      (SELECT M.TRNS_SERIAL, DOC_NO, TRNS_DATE, DATE_SERIAL, M.DESC_A, M.DESC_E, CURRENCY_RATE, 
            DISC_VAL, FREIGHT_VAL, CUSTOMS_VAL, TRNSPORT_VAL, INSURANCE_VAL, COMMISSION_VAL, 
            OTHERS_VAL, POST_FLAG, DELETE_FLAG, M.TRNS_TYPE_CODE, CURRENCY_CODE, SUPPLIER_CODE, 
            CUSTOMER_CODE, COST_CODE, ACCOUNT_NUMBER1, ACCOUNT_NUMBER2, ACCOUNT_NUMBER3, 
            ACCOUNT_NUMBER4, M.STORE_CODE, SALESMAN_CODE, TRNSFER_TYPE, TRNSFER_SERIAL, 
            TRNSFER_FROM_STORE, INVOICE_NO, CUST_POST_FLAG, CUST_TRNS_ID, CUST_TRNS_SERIAL, 
            SUPP_POST_FLAG, SUPP_TRNS_ID, SUPP_TRNS_SERIAL, RET_TRNS_TYPE_CODE, RET_TRNS_SERIAL, 
            PAYMENT, AC_ENTRY_YEAR, AC_ENTRY_TYPE, AC_ENTRY_NO, TRNSFER_TO_STORE, 
            CASH_CUSTOMER, SUPP_OTHERS_VAL, SUPP_INSURANCE_VAL, SUPP_FREIGHT_VAL, 
            REQUEST_NO, COST_CODE2, DUE_DATE, POSTING_SUPPLIER_CODE, STAND_DSCNT, 
            REQ_TRNS_TYPE_CODE, REQ_TRNS_SERIAL, LOT_NO, ACCOUNT_NUMBER2_DESC, ACCOUNT_NUMBER3_DESC, 
            ACCOUNT_NUMBER4_DESC, STORE_SESSION_ID, VISA_AMMOUNT, CHANGE_AMMOUNT, CARD_AMMOUNT, 
            ATM_AMMOUNT, ATM_DESC, VISA_DESC, DELETE_USER, UPDATE_USER, INSERT_USER, SPECIAL_DISC, 
            CASH_AMMOUNT, APPROVE_FLAG, OPER_CODE, OPER_SERIAL, COMM_FLAG, TRNSFORM_SERIAL, DELETE_DATE, 
            UPDATE_DATE, INSERT_DATE, DEMO_TRNS_TYPE_CODE, DEMO_TRNS_SERIAL, INV_PAY_DT,
            M.REDUCTION_RATIO, TRNS_SERIAL_TOTAL, PO_NO, INV_TYPE, PAY_TERM, DELIVERY_NO, 
            CUST_TRNS_PAY_CODE, CUST_TRNS_SERIAL_PAY, M.DELIVERY_TRNS_TYPE_CODE, M.DELIVERY_TRNS_SERIAL,
            MN_ISSUE_FLAG, PO_NUMBER, PURCH_CODE, INCOME_TRNS_TYPE_CODE, INCOME_TRNS_SERIAL, 
            PR_TRNS_TYPE_CODE, PR_TRNS_SERIAL, M.ORDER_TRNS_TYPE_CODE, ORDER_TRNS_SERIAL, SUPP_INV_DATE
       FROM ST_TRNS_MAST M, ST_TRNS_TYPE T
      WHERE T.TRNS_TYPE_CODE = M.TRNS_TYPE_CODE
          AND M.TRNS_DATE      BETWEEN g_cur.TRNS_DATE      AND g_cur.TRNS_DATE
             AND M.TRNS_TYPE_CODE BETWEEN g_cur.TRNS_TYPE_CODE AND g_cur.TRNS_TYPE_CODE
          AND M.TRNS_SERIAL    BETWEEN g_cur.TRNS_SERIAL    AND g_cur.TRNS_SERIAL
        AND NVL(M.POST_FLAG,0) = 0 
        AND NVL(M.DELETE_FLAG,0) = 0 
        AND T.EFFECT IN (1 , 2 , 3 , 4 , 5 , 6)
        AND T.JOIN_TYPE IN ( 2 , 3 , 4)
      ORDER BY TRNS_DATE ,DATE_SERIAL,M.TRNS_TYPE_CODE,TRNS_SERIAL 
      ) 
  LOOP
      BEGIN
          SELECT NAME_A ,NAME_E 
            INTO P_STORE_NAME, P_STORE_NAME_E
            FROM ST_STORE 
           WHERE STORE_CODE = TRNS_REC.STORE_CODE ;

          P_STORE_NAME   := 'رقم مخزن' || TRNS_REC.STORE_CODE || ' ' || P_STORE_NAME;
          P_STORE_NAME_E := 'Store Code ' || TRNS_REC.STORE_CODE || ' ' || P_STORE_NAME_E;
      EXCEPTION WHEN OTHERS THEN 
          P_STORE_NAME := NULL; 
          P_STORE_NAME_E := NULL; 
      END ;
      
      BEGIN 
          SELECT NAME_A, NAME_E
        INTO P_SUPPLIER_NAME ,P_SUPPLIER_NAME_E 
        FROM SUPPLIER 
           WHERE CODE = TRNS_REC.SUPPLIER_CODE ;
        
           P_SUPPLIER_NAME   := 'مورد ' || TRNS_REC.SUPPLIER_CODE || ' ' || P_SUPPLIER_NAME ;
           P_SUPPLIER_NAME_E := 'Supplier ' || TRNS_REC.SUPPLIER_CODE || ' ' || P_SUPPLIER_NAME_E ;
       
      EXCEPTION 
          WHEN OTHERS THEN NULL;
      END     ;
   ------------------------------------------------------------------------- 
   -- For each transaction , get its type join data
   ------------------------------------------------------------------------- 
      IF TRNS_REC.TRNS_DATE <=  TEMP_CLOSE_DATE THEN 
          app_msg('لا يمكن ترحيل الحركة رقم ' || TRNS_REC.TRNS_TYPE_CODE || '/' || TRNS_REC.TRNS_SERIAL || ' لأنها تقع فى فترة مقفلة','You canot post the transaction ' || TRNS_REC.TRNS_TYPE_CODE || '/' || TRNS_REC.TRNS_SERIAL || ' becouse it lies in a closed Period ',1); 
      END IF; 

          GET_TRNS_DATA(TRNS_REC.TRNS_TYPE_CODE,
                         JOIN_TYPE,ENTRY_TYPE,CUST_TRNS_CODE,SUPP_TRNS_CODE,PAY_SUPP_TRNS_CODE,
                         TRNS_POST_TYPE,SUPP_DISC_TRNS_TYPE);    
   -------------------------------------------------------------------------           
          IF g_system_post_type < 4 THEN
              TRNS_POST_TYPE := g_system_post_type ;
          END IF;
   -------------------------------------------------------------------------           

      IF g_cust_code IN ('AZZ') AND JOIN_TYPE = 4 AND NVL(ENTRY_TYPE,0)=0 THEN
          UPDATE ST_TRNS_MAST
          SET    POST_FLAG = 1
          WHERE TRNS_TYPE_CODE = TRNS_REC.TRNS_TYPE_CODE 
          AND        TRNS_SERIAL = TRNS_REC.TRNS_SERIAL;
          EXIT;
      END IF;

           IF JOIN_TYPE != '1' THEN -- join with others modules
        IF CHECK_VALID_POSTING(TRNS_REC.TRNS_TYPE_CODE,TRNS_REC.TRNS_SERIAL) THEN
             IF MAKE_ENTRY(TRNS_REC.TRNS_TYPE_CODE ,   
                       TRNS_REC.TRNS_SERIAL,
                       ENTRY_TYPE,
                       TRNS_REC.STORE_CODE,
                       TRNS_POST_TYPE) AND INSERT_RP_PC_TRNS(TRNS_REC.TRNS_TYPE_CODE,
                                                      TRNS_REC.TRNS_SERIAL)  THEN
   -------------------------------------------------------------------------           
  -- FILTER ST_LEDGER
   -------------------------------------------------------------------------         
          g_acct_posted := g_acct_posted + 1;
            null;
               DELETE ST_LEDGER WHERE NVL(TOTAL_VALUE,0) = 0 ;

               DECLARE
                 CURSOR S_C IS SELECT TRNS_TYPE_CODE , TRNS_SERIAL
                     FROM ST_LEDGER
                 GROUP BY TRNS_TYPE_CODE , TRNS_SERIAL
                 HAVING SUM(TOTAL_VALUE) != 0 ;
               BEGIN
                 FOR XY IN S_C LOOP
                 DELETE ST_LEDGER 
                 WHERE TRNS_TYPE_CODE = XY.TRNS_TYPE_CODE
               AND TRNS_SERIAL    = XY.TRNS_SERIAL;
                 END LOOP;
               END;
   ------------------------------------------------------------------------- 
   -- insert st Ledger into account system 
   ------------------------------------------------------------------------- 
   -- post_flag = 1   insert ONE VOUCHER FOR EVERY TRANSACTION
   -------------------------------------------------------------------------
               DECLARE
                 CURSOR S_L IS SELECT TRNS_TYPE_CODE ,
                          TRNS_SERIAL    ,
                          TRNS_DATE      , VOUCHER_NO ,
                          DOC_NO , ENTRY_DESC , MEMO , ENTRY_TYPE
                FROM ST_LEDGER
                WHERE POST_FLAG = 1 AND NVL(TOTAL_VALUE,0) != 0
                GROUP BY TRNS_DATE , TRNS_TYPE_CODE , TRNS_SERIAL,
                          VOUCHER_NO , DOC_NO , ENTRY_DESC , MEMO , ENTRY_TYPE
                ORDER BY TRNS_DATE , TRNS_TYPE_CODE , TRNS_SERIAL,
                          VOUCHER_NO ,DOC_NO , ENTRY_DESC , MEMO , ENTRY_TYPE;
                 LAST_SER  NUMBER(6);
                      V_YEAR NUMBER;
               BEGIN
                 FOR X_L IN S_L LOOP                
            SELECT DECODE(TRNS_TYPE,1,30,2,31,3,30,4,31,3)
              INTO V_POST_SYSTEM
              FROM ST_TRNS_TYPE T
             WHERE T.TRNS_TYPE_CODE = X_L.TRNS_TYPE_CODE ;
                   LAST_SER := PUT_ENTRY_HEADER (X_L.TRNS_DATE  ,
                                                                              TRNS_REC.AC_ENTRY_YEAR,  
                                         NVL(TRNS_REC.AC_ENTRY_TYPE,X_L.ENTRY_TYPE),
                                         TRNS_REC.AC_ENTRY_NO,
                                         V_YEAR,
                                         X_L.DOC_NO     ,
                                         X_L.ENTRY_DESC ,
                                         NULL,
                                         X_L.MEMO,
                                         V_POST_SYSTEM,
                                         X_L.TRNS_TYPE_CODE,
                                         X_L.TRNS_SERIAL);
         
                       
                           UPDATE ST_TRNS_MAST
                          SET    AC_ENTRY_YEAR = V_YEAR,
                          AC_ENTRY_TYPE = NVL(TRNS_REC.AC_ENTRY_TYPE,X_L.ENTRY_TYPE),
                          AC_ENTRY_NO = LAST_SER,
                          POST_FLAG = 1
                          WHERE TRNS_TYPE_CODE = X_L.TRNS_TYPE_CODE AND
                          TRNS_SERIAL = X_L.TRNS_SERIAL;

                     BEGIN
                              SELECT RP_TRNS_TYPE_CODE ,RP_TRNS_SERIAL  , PC_TRNS_TYPE_CODE , PC_TRNS_SERIAL , 
                                          NVL(CUST_POST_FLAG,0),CUST_TRNS_ID,CUST_TRNS_SERIAL,CUST_TRNS_PAY_CODE,CUST_TRNS_SERIAL_PAY,
                                          NVL(SUPP_POST_FLAG,0),SUPP_TRNS_ID,SUPP_TRNS_SERIAL,CUSTOMER_CODE
                              INTO V_RP_TRNS_TYPE_CODE ,V_RP_TRNS_SERIAL  , V_PC_TRNS_TYPE_CODE ,V_PC_TRNS_SERIAL ,
                                          V_CUST_POST_FLAG,V_CUST_TRNS_ID,V_CUST_TRNS_SERIAL,V_CUST_TRNS_PAY_CODE,V_CUST_TRNS_SERIAL_PAY,
                                          V_SUPP_POST_FLAG,V_SUPP_TRNS_ID,V_SUPP_TRNS_SERIAL,V_CUSTOMER_ID
                              FROM ST_TRNS_MAST
                              WHERE  TRNS_TYPE_CODE = X_L.TRNS_TYPE_CODE AND
                                TRNS_SERIAL = X_L.TRNS_SERIAL;                                                  
                     EXCEPTION WHEN OTHERS THEN
                         V_RP_TRNS_TYPE_CODE := NULL;
                         V_RP_TRNS_SERIAL         := NULL;
                         V_PC_TRNS_TYPE_CODE := NULL;
                         V_PC_TRNS_SERIAL         := NULL;
                        END;                     

                          IF V_RP_TRNS_TYPE_CODE IS NOT NULL THEN
                              UPDATE RP_TRNS_MAST SET
                               POST_ENTRY_YEAR = V_YEAR ,
                               POST_ENTRY_TYPE = NVL(TRNS_REC.AC_ENTRY_TYPE,X_L.ENTRY_TYPE) , 
                               POST_ENTRY_NO = LAST_SER
                              WHERE TRNS_TYPE_CODE = V_RP_TRNS_TYPE_CODE
                                  AND TRNS_SERIAL = V_RP_TRNS_SERIAL ; 
                               
                          END IF;                            

                          IF V_PC_TRNS_TYPE_CODE IS NOT NULL THEN
                              UPDATE CHECK_MAST SET
                               POST_ENTRY_YEAR = V_YEAR ,
                               POST_ENTRY_TYPE = NVL(TRNS_REC.AC_ENTRY_TYPE,X_L.ENTRY_TYPE) , 
                               POST_ENTRY_NO = LAST_SER
                              WHERE TRNS_TYPE_CODE = V_PC_TRNS_TYPE_CODE
                                  AND TRNS_SERIAL = V_PC_TRNS_SERIAL ;                                  
                          END IF;    
                          
                          IF V_CUST_POST_FLAG = 1 THEN
                              BEGIN
                                SELECT MAINAREA_ID, SUBAREA_ID
                                INTO V_MAINAREA_ID, V_SUBAREA_ID  
                                FROM CUSTOMER
                                WHERE CODE = V_CUSTOMER_ID ; 
                              EXCEPTION WHEN OTHERS THEN                          
                                       NULL;                  
                              END;      
                              
                              UPDATE AR_MAINTRNS
                              SET       ACC_YEAR = V_YEAR ,
                                           ACC_TYPE = NVL(TRNS_REC.AC_ENTRY_TYPE,X_L.ENTRY_TYPE) ,
                                     ACC_NO = LAST_SER
                               WHERE    TRNS_ID = V_CUST_TRNS_ID AND
                                               MAINAREA_ID = V_MAINAREA_ID AND
                                               SUBAREA_ID = V_SUBAREA_ID AND
                                               TRNS_SERIAL = V_CUST_TRNS_SERIAL ;                                

                              UPDATE AR_MAINTRNS
                              SET       ACC_YEAR = V_YEAR ,
                                           ACC_TYPE = NVL(TRNS_REC.AC_ENTRY_TYPE,X_L.ENTRY_TYPE) ,
                                     ACC_NO = LAST_SER
                               WHERE    TRNS_ID = V_CUST_TRNS_PAY_CODE AND
                                               MAINAREA_ID = V_MAINAREA_ID AND
                                               SUBAREA_ID = V_SUBAREA_ID AND                                 
                                               TRNS_SERIAL = V_CUST_TRNS_SERIAL_PAY ;                                
                                               
                          END IF;
                          
                          IF V_SUPP_POST_FLAG = 1 THEN
                              UPDATE VN_MAINTRNS
                              SET       ACC_YEAR = V_YEAR ,
                                           ACC_TYPE = NVL(TRNS_REC.AC_ENTRY_TYPE,X_L.ENTRY_TYPE) ,
                                     ACC_NO = LAST_SER
                               WHERE    TRNS_ID = V_SUPP_TRNS_ID AND
                                               TRNS_SERIAL = V_SUPP_TRNS_SERIAL ;
                          END IF;
                          
                   DECLARE
                       CURSOR S_D IS SELECT ACCOUNT_NO , COST_CODE , COST_CODE2 , TOTAL_VALUE , MEMO_DET
                          FROM ST_LEDGER
                         WHERE TRNS_TYPE_CODE = X_L.TRNS_TYPE_CODE 
                           AND TRNS_SERIAL    = X_L.TRNS_SERIAL
                           AND TRNS_DATE      = X_L.TRNS_DATE
                           AND VOUCHER_NO     = X_L.VOUCHER_NO
                           AND ENTRY_TYPE     = X_L.ENTRY_TYPE
                           AND POST_FLAG      = 1
                           AND  NVL(TOTAL_VALUE,0) != 0
                         ORDER BY TOTAL_VALUE DESC ;
                         
                              SEQ_W  NUMBER := 1;
                   BEGIN
                  FOR X_D IN S_D LOOP        
                      
                      
                    PUT_ENTRY_DET(X_L.TRNS_DATE , V_YEAR,NVL(TRNS_REC.AC_ENTRY_TYPE,X_L.ENTRY_TYPE), LAST_SER ,SEQ_W ,
                              X_D.ACCOUNT_NO , X_D.TOTAL_VALUE , X_D.COST_CODE ,X_D.COST_CODE2, 
                          X_D.MEMO_DET , P_SUPPLIER_NAME ,P_SUPPLIER_NAME_E , P_STORE_NAME ,P_STORE_NAME_E);
          
                  END LOOP;
                   END; 
                 END LOOP;      
               END;
  -- -------------------------------------------------------------------
  -- post_flag = 2   insert ONE VOUCHER FOR EVERY TRANSACTION TYPE
  -- -------------------------------------------------------------------
               DECLARE
                 CURSOR S_L IS  SELECT TRNS_TYPE_CODE ,
                          TRNS_SERIAL    ,
                          TRNS_DATE      , VOUCHER_NO ,
                          DOC_NO,ENTRY_DESC , ENTRY_TYPE , MEMO
                     FROM ST_LEDGER
                     WHERE POST_FLAG =  2
                     GROUP BY TRNS_DATE , TRNS_TYPE_CODE , TRNS_SERIAL    ,
                          VOUCHER_NO ,DOC_NO, ENTRY_DESC , ENTRY_TYPE,MEMO
                     ORDER BY TRNS_DATE , TRNS_TYPE_CODE , 
                          VOUCHER_NO ,DOC_NO, ENTRY_DESC , ENTRY_TYPE,MEMO;
     
                 LAST_SER              NUMBER(6);
               BEGIN
                 FOR X_L IN S_L LOOP
                      IF NOT V_DISTINCT = X_L.TRNS_TYPE_CODE THEN          
                       LAST_SER := PUT_ENTRY_HEADER_SECOND_TYPE (
                                                                               V_NEW_VOUCHER,
                                                                               V_MAX_YEAR,
                                                                               V_MAX_NO,        
                                                                               X_L.TRNS_DATE  ,
                                                 X_L.ENTRY_TYPE ,
                                                 X_L.DOC_NO     ,
                                                 X_L.ENTRY_DESC ,
                                                 NULL,
                                                 X_L.MEMO || ' قيد لكل نوع حركة  ' );

                              V_DISTINCT := X_L.TRNS_TYPE_CODE ; 
                       
                               UPDATE ST_TRNS_MAST
                              SET    AC_ENTRY_YEAR = TO_NUMBER(TO_CHAR(X_L.TRNS_DATE,'YYYY')),
                              AC_ENTRY_TYPE = X_L.ENTRY_TYPE,
                              AC_ENTRY_NO = LAST_SER,
                              POST_FLAG = 1
                              WHERE TRNS_TYPE_CODE = X_L.TRNS_TYPE_CODE AND
                              TRNS_SERIAL = X_L.TRNS_SERIAL;    
                                               
                       DECLARE
                      CURSOR S_D IS SELECT ACCOUNT_NO , COST_CODE ,  COST_CODE2,
                                       DECODE(SIGN(TOTAL_VALUE),-1,1,0),
                                       SUM(TOTAL_VALUE) TOTAL_VALUE1 
                                 FROM ST_LEDGER
                                 WHERE TRNS_TYPE_CODE = X_L.TRNS_TYPE_CODE 
                                   AND TRNS_DATE      = X_L.TRNS_DATE
                                   AND VOUCHER_NO     = X_L.VOUCHER_NO
                                   AND ENTRY_TYPE     = X_L.ENTRY_TYPE
                                   AND POST_FLAG      = 2
                                 GROUP BY ACCOUNT_NO , COST_CODE ,COST_CODE2, DECODE(SIGN(TOTAL_VALUE),-1,1,0)
                                 ORDER BY 4;
                      SEQ_W  NUMBER := 1;
                       BEGIN
                      
                      FOR X_D IN S_D LOOP            
                        PUT_ENTRY_DET(X_L.TRNS_DATE ,TO_NUMBER(TO_CHAR(X_L.TRNS_DATE,'YYYY')),X_L.ENTRY_TYPE , LAST_SER ,SEQ_W ,
                                  X_D.ACCOUNT_NO , X_D.TOTAL_VALUE1 , X_D.COST_CODE ,X_D.COST_CODE2,
                                  NULL , P_STORE_NAME , P_STORE_NAME_E , P_SUPPLIER_NAME ,P_SUPPLIER_NAME_E );        
                      END LOOP ;
                       END; 
                          ELSE                 
                       DECLARE
                      CURSOR S_D IS SELECT ACCOUNT_NO , COST_CODE ,  COST_CODE2,
                                       DECODE(SIGN(TOTAL_VALUE),-1,1,0),
                                       SUM(TOTAL_VALUE) TOTAL_VALUE1 
                                 FROM ST_LEDGER
                                 WHERE TRNS_TYPE_CODE = X_L.TRNS_TYPE_CODE 
                                   AND TRNS_DATE      = X_L.TRNS_DATE
                                   AND VOUCHER_NO     = X_L.VOUCHER_NO
                                   AND ENTRY_TYPE     = X_L.ENTRY_TYPE
                                   AND POST_FLAG      = 2
                                 GROUP BY ACCOUNT_NO , COST_CODE ,COST_CODE2, DECODE(SIGN(TOTAL_VALUE),-1,1,0)
                                 ORDER BY 4;
                      SEQ_W  NUMBER;

                       BEGIN
                      FOR X_D IN S_D LOOP            
                                      SELECT MAX(SEQ)+1
                                      INTO     SEQ_W
                                      FROM AC_YEARLY_TRN_DET
                                      WHERE ENTRY_YEAR=TO_NUMBER(TO_CHAR(X_L.TRNS_DATE,'YYYY'))
                                      AND ENTRY_TYPE=X_L.ENTRY_TYPE
                                      AND ENTRY_NO=LAST_SER;
                                      
                        PUT_ENTRY_DET(X_L.TRNS_DATE ,TO_NUMBER(TO_CHAR(X_L.TRNS_DATE,'YYYY')),X_L.ENTRY_TYPE , LAST_SER ,SEQ_W ,
                                  X_D.ACCOUNT_NO , X_D.TOTAL_VALUE1 , X_D.COST_CODE ,X_D.COST_CODE2,
                                  NULL , P_STORE_NAME , P_STORE_NAME_E , P_SUPPLIER_NAME ,P_SUPPLIER_NAME_E );        
                      END LOOP ;
                       END; 

                               UPDATE ST_TRNS_MAST
                              SET    AC_ENTRY_YEAR =TO_NUMBER(TO_CHAR(X_L.TRNS_DATE,'YYYY')),
                              AC_ENTRY_TYPE = X_L.ENTRY_TYPE,
                              AC_ENTRY_NO = LAST_SER,
                              POST_FLAG = 1
                              WHERE TRNS_TYPE_CODE = X_L.TRNS_TYPE_CODE AND
                              TRNS_SERIAL = X_L.TRNS_SERIAL;              
                    END IF;
                 END LOOP;      
               END;
  -- -------------------------------------------------------------------
  -- post_flag = 3   insert ONE VOUCHER FOR EVERY TRANSACTION TYPE 
  -- -------------------------------------------------------------------
                 DECLARE
                 CURSOR S_L IS  SELECT TRNS_TYPE_CODE ,
                          TRNS_SERIAL    ,
                          TRNS_DATE      , VOUCHER_NO ,
                          DOC_NO,ENTRY_DESC , ENTRY_TYPE , MEMO
                     FROM ST_LEDGER
                     WHERE POST_FLAG =  3
                     GROUP BY TRNS_DATE , TRNS_TYPE_CODE , TRNS_SERIAL    ,
                          VOUCHER_NO ,DOC_NO, ENTRY_DESC , ENTRY_TYPE,MEMO
                     ORDER BY TRNS_DATE , TRNS_TYPE_CODE , 
                          VOUCHER_NO , DOC_NO,ENTRY_DESC , ENTRY_TYPE,MEMO;
     
                 LAST_SER              NUMBER(6);
                 V_DISTINCT     NUMBER := 0 ;
                 V_ENTRY_TYPE        NUMBER;
                      V_YEAR NUMBER;
               BEGIN
                 FOR X_L IN S_L LOOP
                      IF NOT V_DISTINCT = 1 THEN          
          
                      LAST_SER := PUT_ENTRY_HEADER_SECOND_TYPE (
                                                                               V_NEW_VOUCHER,
                                                                               V_MAX_YEAR,
                                                                               V_MAX_NO,        
                                                                          X_L.TRNS_DATE  ,
                                             X_L.ENTRY_TYPE ,
                                             X_L.DOC_NO     ,
                                             X_L.ENTRY_DESC ,
                                             NULL,
                                             X_L.MEMO || ' قيد مجمع  ' );
                                             

                               V_ENTRY_TYPE := X_L.ENTRY_TYPE ; 
                               V_DISTINCT   := 1 ;                                                                           
                       DECLARE
                      CURSOR S_D IS SELECT ACCOUNT_NO , COST_CODE ,  COST_CODE2,
                                       DECODE(SIGN(TOTAL_VALUE),-1,1,0),
                                       SUM(TOTAL_VALUE) TOTAL_VALUE1 
                                 FROM ST_LEDGER                                    
                                 WHERE --TRNS_DATE      = x_l.trns_date
                                    VOUCHER_NO     = X_L.VOUCHER_NO
                                   --AND entry_type     = x_l.entry_type
                                   AND POST_FLAG      = 3
                                 GROUP BY ACCOUNT_NO , COST_CODE ,COST_CODE2, DECODE(SIGN(TOTAL_VALUE),-1,1,0)
                                 ORDER BY 4;
                      SEQ_W  NUMBER := 1;
                       BEGIN
                      FOR X_D IN S_D LOOP                     
                        PUT_ENTRY_DET(X_L.TRNS_DATE ,TO_NUMBER(TO_CHAR(X_L.TRNS_DATE,'YYYY')),X_L.ENTRY_TYPE , LAST_SER ,SEQ_W ,
                                  X_D.ACCOUNT_NO , X_D.TOTAL_VALUE1 , X_D.COST_CODE ,X_D.COST_CODE2,
                                  NULL , P_STORE_NAME , P_STORE_NAME_E , P_SUPPLIER_NAME ,P_SUPPLIER_NAME_E  );        
                      END LOOP ;
                       END;                              
                    END IF;
                                           
                          DECLARE
                              V_COUNT NUMBER;
                          BEGIN
                              SELECT COUNT(1)
                              INTO V_COUNT
                              FROM AC_YEARLY_TRN_DET
                              WHERE ENTRY_YEAR=V_YEAR
                              AND ENTRY_TYPE=V_ENTRY_TYPE
                              AND ENTRY_NO=LAST_SER;
                              
                              IF V_COUNT>0 THEN
                                   UPDATE ST_TRNS_MAST
                                  SET    AC_ENTRY_YEAR = V_YEAR,
                                  AC_ENTRY_TYPE = V_ENTRY_TYPE,
                                  AC_ENTRY_NO = LAST_SER,
                                  POST_FLAG = 1
                                  WHERE TRNS_TYPE_CODE = X_L.TRNS_TYPE_CODE AND
                                  TRNS_SERIAL = X_L.TRNS_SERIAL;
                              ELSE
                                  DELETE AC_YEARLY_TRN_DET
                                  WHERE ENTRY_YEAR=V_YEAR
                                  AND ENTRY_TYPE=V_ENTRY_TYPE
                                  AND ENTRY_NO=LAST_SER;
                              END IF;    
                          END;
                                 
                 END LOOP;      
               END;
                DELETE ST_LEDGER;
  -- -------------------------------------------------------------------
  -- END MAIN PART
  -- -------------------------------------------------------------------
           END IF;
       END IF; -- END CHECK VALIDE POSTING
    END IF;
  END LOOP;
 
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit INSERT_CUSTOMER_TRNS (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION INSERT_CUSTOMER_TRNS (
   IN_TRNS_TYPE_CODE      ST_TRNS_TYPE.TRNS_TYPE_CODE%TYPE,
   IN_TRNS_ID             AR_TRNSTYPE.ID%TYPE,
   IN_TRNS_DATE           DATE,
   IN_DOC_NO              AR_MAINTRNS.DOC_NO%TYPE,
   TOTAL_VALUE            AR_MAINTRNS.TOTAL_VALUE%TYPE,
   PAYMENT                AR_MAINTRNS.TOTAL_VALUE%TYPE,
   IN_DESC_A              AR_MAINTRNS.DESCRIPTION_A%TYPE,
   IN_DESC_E              AR_MAINTRNS.DESCRIPTION_E%TYPE,
   IN_CUSTOMER_ID         AR_MAINTRNS.CUSTOMER_ID%TYPE,
   IN_SALESMAN_ID         AR_MAINTRNS.SALESMAN_ID%TYPE,
   IN_BILL_ID1            AR_SUBTRNS.BILL_ID1%TYPE,
   IN_BILL_ID2            AR_SUBTRNS.BILL_ID2%TYPE,
   IN_STORE_CODE          ST_STORE.STORE_CODE%TYPE,
   IN_CTGRY_CODE          ST_CATEGORY_TYPE.CATEGORY_TYPE_CODE%TYPE,
   IN_EFFECT              NUMBER,
   IN_TRNS_TYPE           NUMBER,
   IN_INVOICE_NUMBER      ST_TRNS_MAST.INVOICE_NO%TYPE,
   IN_CUST_TRNS_ID        NUMBER,
   IN_CUST_TRNS_SERIAL    NUMBER,
   IN_ENTRY_YEAR          NUMBER,
   IN_ENTRY_TYPE          NUMBER,
   IN_ENTRY_NO            NUMBER,
   IN_SERIAL_NUMBER       NUMBER,
   W_DOC_NO               NUMBER,
   W_CTGRY_CODE           NUMBER)
   RETURN NUMBER
IS
   T_TRNS_SERIAL       NUMBER;
   IN_MAINAREA_ID      AR_MAINAREA.ID%TYPE;
   IN_SUBAREA_ID       AR_SUBAREA.ID%TYPE;
   IN_NET_VALUE        NUMBER;
   IN_DISC_VALUE       NUMBER;
   IN_RESIDUAL_VALUE   NUMBER;
   IN_TOTAL_VALUE      NUMBER;
   IN_BILL_SEQ         NUMBER;
   V_TEMP              NUMBER;
   PAY_TRNS_ID         NUMBER;
   PAY_TRNS_SERIAL     NUMBER;
   PAY_BILL_SEQ        NUMBER;
   V_POST_SYSTEM       NUMBER;
   DUMMY               NUMBER;
   V_PAY_TYPE_CODE     NUMBER;
   V_CURRENCY_CODE     NUMBER;
   V_CURRENCY_RATE     NUMBER;
   V_DUE_DATE          DATE;
   V_DELIVERY_DATE     DATE;
   CUST_CTGRY_CODE     NUMBER;
BEGIN
   SELECT CURRENCY_CODE,
          CURRENCY_RATE,
          DUE_DATE,
          DELIVERY_DATE
     INTO V_CURRENCY_CODE,
          V_CURRENCY_RATE,
          V_DUE_DATE,
          V_DELIVERY_DATE
     FROM ST_TRNS_MAST
    WHERE     TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
          AND TRNS_SERIAL = IN_SERIAL_NUMBER;

   SELECT DECODE (TRNS_TYPE,  1, 30,  2, 31,  3, 30,  4, 31,  3)
     INTO V_POST_SYSTEM
     FROM ST_TRNS_TYPE T
    WHERE T.TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE;

   IN_TOTAL_VALUE := TOTAL_VALUE;

   IF IN_MAINAREA_ID IS NULL OR IN_SUBAREA_ID IS NULL
   THEN
      BEGIN
         SELECT MAINAREA_ID, SUBAREA_ID
           INTO IN_MAINAREA_ID, IN_SUBAREA_ID
           FROM CUSTOMER
          WHERE CODE = IN_CUSTOMER_ID;
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;
   END IF;

   IF IN_MAINAREA_ID IS NULL OR IN_SUBAREA_ID IS NULL
   THEN
      app_msg('الشركة و الفرع غير معرفين لنوع الحركة رقم ' || IN_TRNS_ID,'',1);
   END IF;

   BEGIN
      IF IN_CUST_TRNS_SERIAL IS NOT NULL
      THEN
         SELECT COUNT (1)
           INTO DUMMY
           FROM AR_MAINTRNS
          WHERE     TRNS_ID = IN_CUST_TRNS_ID
                AND MAINAREA_ID = IN_MAINAREA_ID
                AND SUBAREA_ID = IN_SUBAREA_ID
                AND TRNS_SERIAL = IN_CUST_TRNS_SERIAL;


         IF NVL (DUMMY, 0) > 0
         THEN
            BEGIN
               SELECT NVL (MAX (TRNS_SERIAL), 0) + 1
                 INTO T_TRNS_SERIAL
                 FROM AR_MAINTRNS
                WHERE     TRNS_ID = IN_TRNS_ID
                      AND MAINAREA_ID = IN_MAINAREA_ID
                      AND SUBAREA_ID = IN_SUBAREA_ID;
            EXCEPTION
               WHEN OTHERS
               THEN
                  T_TRNS_SERIAL := 1;
            END;
         ELSE
            T_TRNS_SERIAL := IN_CUST_TRNS_SERIAL;
         END IF;
      ELSE
         BEGIN
            SELECT NVL (MAX (TRNS_SERIAL), 0) + 1
              INTO T_TRNS_SERIAL
              FROM AR_MAINTRNS
             WHERE     TRNS_ID = IN_TRNS_ID
                   AND MAINAREA_ID = IN_MAINAREA_ID
                   AND SUBAREA_ID = IN_SUBAREA_ID;
         EXCEPTION
            WHEN OTHERS
            THEN
               T_TRNS_SERIAL := 1;
         END;
      END IF;
   END;

   BEGIN
      SELECT NVL (MAX (BILL_SEQ), 0) + 1
        INTO IN_BILL_SEQ
        FROM AR_SUBTRNS
       WHERE     MAINAREA_ID = IN_MAINAREA_ID
             AND SUBAREA_ID = IN_SUBAREA_ID
             AND TRNS_ID = IN_TRNS_ID
             AND TRNS_SERIAL = T_TRNS_SERIAL;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         IN_BILL_SEQ := 1;
   END;
   
   BEGIN
      SELECT PAY_TYPE_CODE
        INTO V_PAY_TYPE_CODE
        FROM AR_BASIC
       WHERE COMPANY_CODE = g_company;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END;

   IF (IN_EFFECT = 2 AND IN_TRNS_TYPE = 2)
   THEN                                                         -- صادر مبيعات
      INSERT INTO AR_MAINTRNS (TRNS_ID,
                               MAINAREA_ID,
                               SUBAREA_ID,
                               TRNS_SERIAL,
                               CTGRY_CODE,
                               STORE_CODE,
                               TRNS_DATE,
                               DOC_NO,
                               TOTAL_VALUE,
                               DISC_VALUE,
                               NET_VALUE,
                               DESCRIPTION_A,
                               DESCRIPTION_E,
                               CUSTOMER_ID,
                               SALESMAN_ID,
                               LINK_FLAG,
                               POST_FLAG,
                               RESIDUAL_VALUE,
                               CURRENCY_CODE,
                               CURRENCY_RATE,
                               ACC_YEAR,
                               ACC_TYPE,
                               ACC_NO,
                               ACC_DATE,
                               POST_SYSTEM,
                               PAY_TYPE_CODE,
                               DELIVERY_DATE)
           VALUES (IN_TRNS_ID,
                   IN_MAINAREA_ID,
                   IN_SUBAREA_ID,
                   T_TRNS_SERIAL,
                   IN_CTGRY_CODE,
                   IN_STORE_CODE,
                   IN_TRNS_DATE,
                   IN_DOC_NO,
                   IN_TOTAL_VALUE,
                   0,
                   IN_TOTAL_VALUE - NVL (PAYMENT, 0),
                   IN_DESC_A,
                   IN_DESC_E,
                   IN_CUSTOMER_ID,
                   IN_SALESMAN_ID,
                   1,
                   1,
                   IN_TOTAL_VALUE - NVL (PAYMENT, 0),
                   V_CURRENCY_CODE,
                   V_CURRENCY_RATE,
                   IN_ENTRY_YEAR,
                   IN_ENTRY_TYPE,
                   IN_ENTRY_NO,
                   IN_TRNS_DATE,
                   V_POST_SYSTEM,
                   V_PAY_TYPE_CODE,
                   V_DELIVERY_DATE);

      INSERT INTO AR_SUBTRNS (TRNS_ID,
                              MAINAREA_ID,
                              SUBAREA_ID,
                              TRNS_SERIAL,
                              BILL_SEQ,
                              BILL_ID1,
                              BILL_ID2,
                              TOTAL_VALUE,
                              DISC_VALUE,
                              NET_VALUE,
                              RESIDUAL_VALUE,
                              STORE_CODE,
                              INV_DATE,
                              PAY_TYPE_CODE,
                              INVOICE_CLASS)
           VALUES (IN_TRNS_ID,
                   IN_MAINAREA_ID,
                   IN_SUBAREA_ID,
                   T_TRNS_SERIAL,
                   IN_BILL_SEQ,
                   W_CTGRY_CODE,
                   W_DOC_NO,
                   IN_TOTAL_VALUE,
                   0,
                   IN_TOTAL_VALUE,
                   IN_TOTAL_VALUE - NVL (PAYMENT, 0),
                   IN_STORE_CODE,
                   IN_TRNS_DATE,
                   V_PAY_TYPE_CODE,
                   V_DUE_DATE);

      --  -------------------------------------
      --  PAYMENT
      --  -------------------------------------
      IF NVL (PAYMENT, 0) > 0
      THEN
         BEGIN
            SELECT CUSTOMER_TRNS_PAY_CODE
              INTO PAY_TRNS_ID
              FROM ST_TRNS_TYPE
             WHERE TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE;

            IF PAY_TRNS_ID IS NULL
            THEN
               app_msg('رقم حركة السداد غير معرف فى شاشة انواع حركات المبيعات للحركة رقم  ' || IN_TRNS_TYPE_CODE,'',1);
            END IF;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               app_msg('رقم حركة السداد غير معرف فى شاشة انواع حركات المبيعات للحركة رقم  ' || IN_TRNS_TYPE_CODE,'',1);
               NULL;
         END;

         BEGIN
            SELECT NVL (MAX (TRNS_SERIAL), 0) + 1
              INTO PAY_TRNS_SERIAL
              FROM AR_MAINTRNS
             WHERE     TRNS_ID = PAY_TRNS_ID
                   AND MAINAREA_ID = IN_MAINAREA_ID
                   AND SUBAREA_ID = IN_SUBAREA_ID;
         EXCEPTION
            WHEN OTHERS
            THEN
               PAY_TRNS_SERIAL := 1;
         END;

         BEGIN
            SELECT NVL (MAX (BILL_SEQ), 0) + 1
              INTO PAY_BILL_SEQ
              FROM AR_SUBTRNS
             WHERE     MAINAREA_ID = IN_MAINAREA_ID
                   AND SUBAREA_ID = IN_SUBAREA_ID
                   AND TRNS_ID = PAY_TRNS_ID
                   AND TRNS_SERIAL = PAY_TRNS_SERIAL;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               PAY_BILL_SEQ := 1;
         END;

         INSERT INTO AR_MAINTRNS (TRNS_ID,
                                  MAINAREA_ID,
                                  SUBAREA_ID,
                                  TRNS_SERIAL,
                                  CTGRY_CODE,
                                  STORE_CODE,
                                  TRNS_DATE,
                                  DOC_NO,
                                  TOTAL_VALUE,
                                  DISC_VALUE,
                                  NET_VALUE,
                                  DESCRIPTION_A,
                                  DESCRIPTION_E,
                                  CUSTOMER_ID,
                                  SALESMAN_ID,
                                  LINK_FLAG,
                                  POST_FLAG,
                                  RESIDUAL_VALUE,
                                  PAY_METHOD,
                                  CURRENCY_CODE,
                                  CURRENCY_RATE,
                                  ACC_YEAR,
                                  ACC_TYPE,
                                  ACC_NO,
                                  ACC_DATE,
                                  POST_SYSTEM,
                                  PAY_TYPE_CODE,
                                  DELIVERY_DATE)
              VALUES (PAY_TRNS_ID,
                      IN_MAINAREA_ID,
                      IN_SUBAREA_ID,
                      PAY_TRNS_SERIAL,
                      IN_CTGRY_CODE,
                      IN_STORE_CODE,
                      IN_TRNS_DATE,
                      IN_DOC_NO,
                      PAYMENT,
                      0,
                      PAYMENT,
                      IN_DESC_A,
                      IN_DESC_E,
                      IN_CUSTOMER_ID,
                      IN_SALESMAN_ID,
                      1,
                      1,
                      0,
                      2,
                      V_CURRENCY_CODE,
                      V_CURRENCY_RATE,
                      IN_ENTRY_YEAR,
                      IN_ENTRY_TYPE,
                      IN_ENTRY_NO,
                      IN_TRNS_DATE,
                      V_POST_SYSTEM,
                      V_PAY_TYPE_CODE,
                      V_DELIVERY_DATE);

         INSERT INTO AR_SUBTRNS (TRNS_ID,
                                 MAINAREA_ID,
                                 SUBAREA_ID,
                                 TRNS_SERIAL,
                                 BILL_SEQ,
                                 BILL_ID1,
                                 BILL_ID2,
                                 TOTAL_VALUE,
                                 DISC_VALUE,
                                 NET_VALUE,
                                 RESIDUAL_VALUE,
                                 STORE_CODE,
                                 INV_DATE,
                                 PAY_TYPE_CODE,
                                 INVOICE_CLASS)
              VALUES (PAY_TRNS_ID,
                      IN_MAINAREA_ID,
                      IN_SUBAREA_ID,
                      PAY_TRNS_SERIAL,
                      PAY_BILL_SEQ,
                      W_CTGRY_CODE,
                      W_DOC_NO,
                      PAYMENT,
                      0,
                      PAYMENT,
                      0,
                      IN_STORE_CODE,
                      IN_TRNS_DATE,
                      V_PAY_TYPE_CODE,
                      V_DUE_DATE);
      END IF;
   --  ------------------------------------
   ELSIF    (IN_EFFECT = 4 AND IN_TRNS_TYPE = 4)               -- مرتجع مبيعات
         OR (IN_EFFECT = 1 AND IN_TRNS_TYPE = 1)            -- مشتريات من عميل
   THEN
      DECLARE
         V_DISC_VALUE       NUMBER;
         DSCNT_SOURCE       NUMBER;
         DSCNT_PERIOD       NUMBER;
         REMAIN_VALUE       NUMBER;
         DET_DESC           VARCHAR2 (150);
         PAY_METHOD         NUMBER;
         TRNS_TOTAL_VALUE   NUMBER;
         V_TRNS_SERIAL      NUMBER;
         V_RET_TRNS_TYPE    NUMBER;
         V_RET_TRNS_SERIAL  NUMBER;
         V_INVOICE_REF      NUMBER;
         V_INV_TRNS_ID      NUMBER;
         V_INV_TRNS_SERIAL  NUMBER;
         V_INV_SUBAREA_ID   NUMBER;
         V_INV_MAINAREA_ID  NUMBER;
         V_INV_BILL_SEQ     NUMBER;
         V_BILL_ID1         NUMBER;
         V_BILL_ID2         NUMBER;
      BEGIN
           BEGIN
                 SELECT RET_TRNS_TYPE_CODE, RET_TRNS_SERIAL, INVOICE_REF
                   INTO V_RET_TRNS_TYPE, V_RET_TRNS_SERIAL, V_INVOICE_REF
                   FROM ST_TRNS_MAST
                  WHERE TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
                    AND TRNS_SERIAL    = IN_SERIAL_NUMBER
                    AND NVL(DELETE_FLAG,0) = 0;
           EXCEPTION WHEN OTHERS THEN
                   V_RET_TRNS_TYPE   := NULL;
                   V_RET_TRNS_SERIAL := NULL;
                   V_INVOICE_REF     := NULL;
         END;
         
         IF V_RET_TRNS_TYPE IS NOT NULL AND V_RET_TRNS_SERIAL IS NOT NULL THEN
               BEGIN
                    SELECT MA.TRNS_ID, MA.TRNS_SERIAL, MA.MAINAREA_ID, MA.SUBAREA_ID, DA.BILL_SEQ, DA.BILL_ID1, DA.BILL_ID2
                      INTO V_INV_TRNS_ID, V_INV_TRNS_SERIAL, V_INV_MAINAREA_ID, V_INV_SUBAREA_ID, V_INV_BILL_SEQ, V_BILL_ID1, V_BILL_ID2
                      FROM ST_TRNS_MAST MT, AR_MAINTRNS MA, AR_SUBTRNS DA
                     WHERE MT.TRNS_TYPE_CODE        = V_RET_TRNS_TYPE
                       AND MT.TRNS_SERIAL           = V_RET_TRNS_SERIAL
                       AND NVL(MT.DELETE_FLAG,0)    = 0
                       AND NVL(MT.CUST_POST_FLAG,0) = 1   
                       AND MA.TRNS_ID     = MT.CUST_TRNS_ID
                       AND MA.TRNS_SERIAL = MT.CUST_TRNS_SERIAL
                       AND MA.CUSTOMER_ID = MT.CUSTOMER_CODE
                       AND MA.TRNS_ID     = DA.TRNS_ID    
                       AND MA.TRNS_SERIAL = DA.TRNS_SERIAL
                       AND MA.SUBAREA_ID  = DA.SUBAREA_ID 
                       AND MA.MAINAREA_ID = DA.MAINAREA_ID
                       AND DA.BILL_ID2    = MT.DOC_NO;
                  EXCEPTION WHEN OTHERS THEN
                      V_INV_TRNS_ID     := NULL;
                      V_INV_TRNS_SERIAL := NULL;
                      V_INV_SUBAREA_ID  := NULL;
                      V_INV_MAINAREA_ID := NULL;
                      V_INV_BILL_SEQ    := NULL;
                      V_BILL_ID1      := NULL;
                      V_BILL_ID2      := NULL;
                  END;
                  
                  IF V_INV_TRNS_ID IS NOT NULL AND V_INV_TRNS_SERIAL IS NOT NULL AND V_INV_SUBAREA_ID IS NOT NULL AND V_INV_MAINAREA_ID IS NOT NULL AND V_INV_BILL_SEQ IS NOT NULL THEN
                    V_TEMP := 1;
                ELSE
                    V_TEMP := 0;
                END IF;
             ELSIF V_RET_TRNS_TYPE IS NULL AND V_RET_TRNS_SERIAL IS NULL AND V_INVOICE_REF IS NOT NULL THEN
                     BEGIN
                    SELECT MA.TRNS_ID, MA.TRNS_SERIAL, MA.MAINAREA_ID, MA.SUBAREA_ID, DA.BILL_SEQ, DA.BILL_ID1, DA.BILL_ID2
                      INTO V_INV_TRNS_ID, V_INV_TRNS_SERIAL, V_INV_MAINAREA_ID, V_INV_SUBAREA_ID, V_INV_BILL_SEQ, V_BILL_ID1, V_BILL_ID2
                      FROM AR_MAINTRNS MA, AR_SUBTRNS DA
                     WHERE MA.TRNS_ID     = DA.TRNS_ID    
                       AND MA.TRNS_SERIAL = DA.TRNS_SERIAL
                       AND MA.SUBAREA_ID  = DA.SUBAREA_ID 
                       AND MA.MAINAREA_ID = DA.MAINAREA_ID
                       AND DA.BILL_ID2    = V_INVOICE_REF
                       AND NVL(MA.LINK_FLAG,0) = 1
                 AND DA.STORE_CODE = 999999999999
                 AND MA.TRNS_ID IN (SELECT ID
                                                    FROM AR_TRNSTYPE
                                                    WHERE EFFECT = 0
                                                     AND TRNS_TYPE = 6);
                  EXCEPTION WHEN OTHERS THEN
                      V_INV_TRNS_ID     := NULL;
                      V_INV_TRNS_SERIAL := NULL;
                      V_INV_SUBAREA_ID  := NULL;
                      V_INV_MAINAREA_ID := NULL;
                      V_INV_BILL_SEQ    := NULL;
                      V_BILL_ID1      := NULL;
                      V_BILL_ID2      := NULL;
                  END;
                  
                  IF V_INV_TRNS_ID IS NOT NULL AND V_INV_TRNS_SERIAL IS NOT NULL AND V_INV_SUBAREA_ID IS NOT NULL AND V_INV_MAINAREA_ID IS NOT NULL AND V_INV_BILL_SEQ IS NOT NULL THEN
                    V_TEMP := 1;
                ELSE
                    V_TEMP := 0;
                END IF;
             ELSE
                     V_TEMP := 0;    
             END IF;
         
         /*SELECT COUNT (1)
           INTO V_TEMP
           FROM ST_TRNS_MAST MT, ST_TRNS_TYPE TT
          WHERE MT.TRNS_TYPE_CODE = TT.TRNS_TYPE_CODE
            AND TT.EFFECT = 2
            AND TT.TRNS_TYPE = 2
            AND MT.INVOICE_NO = IN_INVOICE_NUMBER;*/
         BEGIN
             SELECT CTGRY_CODE
               INTO CUST_CTGRY_CODE
               FROM AR_CUST_SALESMAN
              WHERE SALESMAN_CODE = IN_SALESMAN_ID
                AND CUSTOMER_CODE = IN_CUSTOMER_ID;
         EXCEPTION WHEN OTHERS THEN
              CUST_CTGRY_CODE    := NULL;
         END;
         
         IF V_TEMP > 0
         THEN                                              -- مرتجع على فاتورة
            PAY_METHOD := 2;
            TRNS_TOTAL_VALUE := TOTAL_VALUE;
            V_DISC_VALUE := 0;

            INSERT INTO AR_MAINTRNS (TRNS_ID,
                                     MAINAREA_ID,
                                     SUBAREA_ID,
                                     TRNS_SERIAL,
                                     CTGRY_CODE,
                                     STORE_CODE,
                                     TRNS_DATE,
                                     DOC_NO,
                                     TOTAL_VALUE,
                                     DISC_VALUE,
                                     NET_VALUE,
                                     DESCRIPTION_A,
                                     DESCRIPTION_E,
                                     CUSTOMER_ID,
                                     SALESMAN_ID,
                                     LINK_FLAG,
                                     POST_FLAG,
                                     RESIDUAL_VALUE,
                                     PAY_METHOD,
                                     CURRENCY_CODE,
                                     CURRENCY_RATE,
                                     ACC_YEAR,
                                     ACC_TYPE,
                                     ACC_NO,
                                     ACC_DATE,
                                     POST_SYSTEM,
                                     PAY_TYPE_CODE,
                                     DELIVERY_DATE)
                 VALUES (IN_TRNS_ID,
                         IN_MAINAREA_ID,
                         IN_SUBAREA_ID,
                         T_TRNS_SERIAL,
                         NVL(CUST_CTGRY_CODE,IN_CTGRY_CODE),
                         IN_STORE_CODE,
                         IN_TRNS_DATE,
                         IN_DOC_NO,
                         TRNS_TOTAL_VALUE,
                         V_DISC_VALUE,
                         TRNS_TOTAL_VALUE - V_DISC_VALUE,
                         IN_DESC_A,
                         IN_DESC_E,
                         IN_CUSTOMER_ID,
                         IN_SALESMAN_ID,
                         1,
                         1,
                         0,
                         PAY_METHOD,
                         V_CURRENCY_CODE,
                         V_CURRENCY_RATE,
                         IN_ENTRY_YEAR,
                         IN_ENTRY_TYPE,
                         IN_ENTRY_NO,
                         IN_TRNS_DATE,
                         V_POST_SYSTEM,
                         V_PAY_TYPE_CODE,
                         V_DELIVERY_DATE);
                         
                         INSERT INTO AR_SUBTRNS  (TRNS_ID,
                                                                            MAINAREA_ID,
                                                                            SUBAREA_ID,
                                                                            TRNS_SERIAL,
                                                                            BILL_SEQ,
                                                                            INV_DATE,
                                                                            BILL_ID1,
                                                                            BILL_ID2,
                                                                            TOTAL_VALUE,
                                                                            DISC_VALUE,
                                                                            NET_VALUE,
                                                                            STORE_CODE,
                                                                            INVOICE_CLASS,
                                                                            INV_TRNS_ID,
                                                                            INV_TRNS_SERIAL,
                                                                            INV_MAINAREA_ID,
                                                                            INV_SUBAREA_ID,
                                                                            INV_BILL_SEQ,
                                                                            INV_VALUE)
                                                         VALUES (IN_TRNS_ID,
                                                     IN_MAINAREA_ID,
                                                     IN_SUBAREA_ID,
                                                     T_TRNS_SERIAL,
                                                                 1,
                                                                 IN_TRNS_DATE,
                                                                 V_BILL_ID1,
                                                                 V_BILL_ID2,
                                                                 TRNS_TOTAL_VALUE,
                                                     V_DISC_VALUE,
                                                     TRNS_TOTAL_VALUE - V_DISC_VALUE,
                                                                 IN_STORE_CODE,
                                                                 IN_TRNS_DATE,
                                                                 V_INV_TRNS_ID,    
                                                                 V_INV_TRNS_SERIAL,
                                                                 V_INV_MAINAREA_ID,
                                                                 V_INV_SUBAREA_ID,
                                                                 V_INV_BILL_SEQ,   
                                                                 TRNS_TOTAL_VALUE);
         ELSIF V_TEMP = 0
         THEN                                              -- مرتجع على العميل
            PAY_METHOD := 4;
            TRNS_TOTAL_VALUE := TOTAL_VALUE;
            V_DISC_VALUE := 0;

            INSERT INTO AR_MAINTRNS (TRNS_ID,
                                     MAINAREA_ID,
                                     SUBAREA_ID,
                                     TRNS_SERIAL,
                                     CTGRY_CODE,
                                     STORE_CODE,
                                     TRNS_DATE,
                                     DOC_NO,
                                     TOTAL_VALUE,
                                     DISC_VALUE,
                                     NET_VALUE,
                                     DESCRIPTION_A,
                                     DESCRIPTION_E,
                                     CUSTOMER_ID,
                                     SALESMAN_ID,
                                     LINK_FLAG,
                                     POST_FLAG,
                                     RESIDUAL_VALUE,
                                     PAY_METHOD,
                                     CURRENCY_CODE,
                                     CURRENCY_RATE,
                                     ACC_YEAR,
                                     ACC_TYPE,
                                     ACC_NO,
                                     ACC_DATE,
                                     POST_SYSTEM,
                                     PAY_TYPE_CODE,
                                     DELIVERY_DATE)
                 VALUES (IN_TRNS_ID,
                         IN_MAINAREA_ID,
                         IN_SUBAREA_ID,
                         T_TRNS_SERIAL,
                         NVL(CUST_CTGRY_CODE,IN_CTGRY_CODE),
                         IN_STORE_CODE,
                         IN_TRNS_DATE,
                         IN_DOC_NO,
                         TRNS_TOTAL_VALUE,
                         V_DISC_VALUE,
                         TRNS_TOTAL_VALUE - V_DISC_VALUE,
                         IN_DESC_A,
                         IN_DESC_E,
                         IN_CUSTOMER_ID,
                         IN_SALESMAN_ID,
                         1,
                         1,
                         0,
                         PAY_METHOD,
                         V_CURRENCY_CODE,
                         V_CURRENCY_RATE,
                         IN_ENTRY_YEAR,
                         IN_ENTRY_TYPE,
                         IN_ENTRY_NO,
                         IN_TRNS_DATE,
                         V_POST_SYSTEM,
                         V_PAY_TYPE_CODE,
                         V_DELIVERY_DATE);
         END IF;
      END;
   END IF;

   UPDATE ST_TRNS_MAST
      SET CUST_POST_FLAG = 1,
          CUST_TRNS_ID = IN_TRNS_ID,
          CUST_TRNS_SERIAL = T_TRNS_SERIAL,
          CUST_TRNS_PAY_CODE = PAY_TRNS_ID,
          CUST_TRNS_SERIAL_PAY = PAY_TRNS_SERIAL,
          CUST_MAINAREA_ID = IN_MAINAREA_ID,
          CUST_SUBAREA_ID = IN_SUBAREA_ID
    WHERE     TRNS_TYPE_CODE = IN_TRNS_TYPE_CODE
          AND TRNS_SERIAL = IN_SERIAL_NUMBER;

   RETURN (T_TRNS_SERIAL);
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit MAKE_CUSTOMER_ENTRY (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION make_customer_entry (
             in_trns_type_code   st_trns_mast.Trns_Type_Code%type,
             in_serial_number    st_trns_mast.Trns_Serial%type,
                 in_store_code         st_store.store_code%TYPE,
                 in_ctgry_code         st_category_type.category_type_code%TYPE,
             in_CustomerCode     st_trns_mast.Customer_Code%type,
             in_SalesManCode     st_trns_mast.SalesMan_code%type,
             in_DocumentCode     st_trns_mast.Doc_no%type,
             in_cust_trns_code   st_trns_type.customer_trns_code%type,
             in_cust_trns_pay_code   st_trns_type.customer_trns_code%type,             
                 IN_ST_EFFECT           ST_TRNS_TYPE.EFFECT%TYPE,
                 IN_ST_TRNS_TYPE       ST_TRNS_TYPE.TRNS_TYPE%TYPE,
                 IN_INVOICE_NO       VARCHAR2,
                 IN_ENTRY_YEAR    NUMBER,
                 IN_ENTRY_TYPE    NUMBER,
                 IN_ENTRY_NO    NUMBER)
RETURN boolean 
IS

   in_transactiondate   date;
   in_TransactionTotal  number(18,2);
   in_payment           number(18,2);
   --in_Description_A     varchar2(100);   
   --in_Description_e     varchar2(100);
   in_Description_A     st_trns_mast.desc_a%TYPE;   
   in_Description_e     st_trns_mast.desc_E%TYPE;      
   in_effect            number(1);   
   W_DOC_NO            NUMBER(30);
   W_CTGRY_CODE        NUMBER(3);
   w_freight_val        number(18,2); 
   w_disc_val           number(18,2);
   w_customs_val        number(18,2); 
   w_trnsport_val       number(18,2);
   w_insurance_val      number(18,2); 
   w_commission_val     number(18,2);
   w_others_val         number(18,2);    
   w_payment        number(18,2);
   w_service        number;
   w_trns_serial        ar_maintrns.trns_serial%type;
   w_det_disc  number;
   W_CUST_TRNS_ID NUMBER;
   W_CUST_TRNS_SERIAL NUMBER;
   w_tax_value1       NUMBER;
BEGIN
 if nvl(in_cust_trns_code,0) = 0 or nvl(in_CustomerCode,0) = 0 then
  return (false);  
 end if;

 begin
  --message('before select'); pause;
  --message('in_trns_type_code= ' || in_trns_type_code || ' in_serial_number= ' || in_serial_number ); pause;
  --raise form_trigger_failure;
  Select --round(Sum(nvl(unit_price,0) * nvl(quantity,0)),2) ,
               round(Sum((nvl(unit_price,0)) * nvl(quantity,0) / nvl(currency_rate,0) ),2) Items_total,
         nvl(freight_val,0)  , nvl(disc_val,0) + + NVL(TOT_disc1_VALUE,0) + NVL(TOT_disc2_VALUE,0) + NVL(TOT_disc3_VALUE,0),
         nvl(customs_val,0)  , nvl(trnsport_val,0),
         nvl(insurance_val,0), nvl(commission_val,0),
         nvl(others_val,0) , nvl(payment,0)+nvl(ATM_AMMOUNT,0),   
         m.trns_date,m.desc_a , m.desc_e ,nvl(sum(NVL(det_disc,0) + ((NVL(CURRENCY_RATE,0) * (NVL(disc1_VALUE,0) + NVL(disc2_VALUE,0) + NVL(disc3_VALUE,0))) * nvl(quantity,0))),0),
         CUST_TRNS_ID, CUST_TRNS_SERIAL,
         nvl(round(sum(nvl(d.tax_value1,0)),2) + nvl(m.tax_value1,0),0) tax_value1,GET_CUSTOMER_CTGRY(M.CUSTOMER_CODE,M.SALESMAN_CODE),M.DOC_NO
  Into   in_TransactionTotal, 
         w_freight_val  , w_disc_val ,
         w_customs_val  , w_trnsport_val,
         w_insurance_val, w_commission_val,
         w_others_val ,  w_payment,  
         in_Transactiondate, 
         in_Description_A, in_Description_E,w_det_disc,
         W_CUST_TRNS_ID, W_CUST_TRNS_SERIAL,w_tax_value1,W_CTGRY_CODE,W_DOC_NO
  From   st_trns_mast m, st_trns_det d 
  Where  m.trns_type_code = in_trns_type_code
  and    m.trns_serial    = in_serial_number
  and    nvl(m.delete_flag,0)    = 0
  AND NVL(D.DELETE_FLAG,0)    = 0
  and    d.trns_type_code(+) = m.trns_type_code
  and    d.trns_serial(+)    = m.trns_serial
  Group by nvl(freight_val,0)  , nvl(disc_val,0) + NVL(TOT_disc1_VALUE,0) + NVL(TOT_disc2_VALUE,0) + NVL(TOT_disc3_VALUE,0) ,
           nvl(customs_val,0)  , nvl(trnsport_val,0),
           nvl(insurance_val,0), nvl(commission_val,0),
           nvl(others_val,0) , nvl(payment,0)+nvl(ATM_AMMOUNT,0),
           m.trns_date,m.desc_a , m.desc_e,
           CUST_TRNS_ID, CUST_TRNS_SERIAL , m.tax_value1,GET_CUSTOMER_CTGRY(M.CUSTOMER_CODE,M.SALESMAN_CODE),M.DOC_NO;
  --message('after select'); pause;


  /* Formatted on 22/07/2025 02:38:09 م (QP5 v5.252.13127.32867) */
SELECT NVL (
          SUM (
               NVL (service_cost, 0) * NVL (units_no, 0)
             + NVL (d.tax_value1, 0)),
          0)
  INTO w_service
  FROM st_trns_mast m, st_trns_services d
 WHERE     d.trns_type_code = in_trns_type_code
       AND d.trns_serial = in_serial_number
       AND NVL (m.delete_flag, 0) = 0
       AND d.trns_type_code = m.trns_type_code
       AND d.trns_serial = m.trns_serial;
--message('in_TransactionTotal = ' || in_TransactionTotal ); pause;
--message('w_service = ' || w_disc_val ); pause;
--message('w_service = ' || w_det_disc ); pause;
--message('w_service = ' || nvl(w_service,0) ); pause;
  in_TransactionTotal := in_TransactionTotal + nvl(w_service,0)
                         + w_freight_val  - w_disc_val  - w_det_disc
                         + w_customs_val  + w_trnsport_val
                         + w_insurance_val+ w_commission_val
                         + w_others_val + w_tax_value1;
  in_payment          := w_payment; 
-- message('in_TransactionTotal = ' || in_TransactionTotal ); pause;
--raise form_trigger_failure; 

 exception
   when others then
     return(false);
 end;
--MESSAGE ('BEFORE insert_customer_trns '); PAUSE;
 w_trns_serial := insert_customer_trns(
                      in_trns_type_code,
                      in_cust_trns_code    ,
                      in_TransactionDate   ,
                      in_DocumentCode      , 
                      in_TransactionTotal  ,
                      in_payment           ,
                      in_Description_A     ,   
                      in_Description_e     ,   
                      in_CustomerCode      ,
                      in_SalesManCode      ,
                      in_trns_type_code    ,
                      in_serial_number     ,
                             in_store_code             ,
                            in_ctgry_code             ,
                            IN_ST_EFFECT,
                            IN_ST_TRNS_TYPE    ,
                            IN_INVOICE_NO,
                            W_CUST_TRNS_ID, W_CUST_TRNS_SERIAL,
                            IN_ENTRY_YEAR,
                            IN_ENTRY_TYPE,
                            IN_ENTRY_NO,
                            in_serial_number,
                            W_DOC_NO,    
                            W_CTGRY_CODE);
        
--message('w_trns_serial = ' || w_trns_serial ); pause;
--MESSAGE ('AFTER insert_customer_trns '); PAUSE;


 return (true);  
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit SET_POST_CUSTOMER (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
procedure set_Post_customer IS

  Trns_Rec          st_trns_mast%rowtype;
  Join_Type         st_trns_type.Join_Type%type;
  Entry_Type        st_trns_type.Entry_Type%type;
  Cust_Trns_Code    st_trns_type.Customer_Trns_code%type;
  Supp_Trns_Code    st_trns_type.Supplier_Trns_code%type;
  pay_Supp_Trns_Code    st_trns_type.Supplier_Trns_code%type;  
  Trns_Post_type    st_trns_type.Post_type%type;
  SUPP_DISC_TRNS_TYPE  st_trns_type.SUPP_DISC_TRNS_TYPE%type;
  pay_cust_Trns_Code st_trns_type.Customer_Trns_code%type;
  category_type_code ar_cust_salesman.CTGRY_CODE%type;
  dummy number;
BEGIN
  /* ******************************************************************* **
  **      Normal transactions Proccessing goes here (In,Out,DIn,DOut)    **
  ** ******************************************************************* */
  -- ------------------------------------------------------------------------- 
  -- Loop On Stock transactions
  -- ------------------------------------------------------------------------- 
 
   For Trns_Rec in (select m.trns_type_code ,m.trns_serial,m.store_code ,m.Customer_Code,m.SALESMAN_CODE,
                                                     m.doc_no,m.INVOICE_NO,m.AC_ENTRY_YEAR,m.AC_ENTRY_TYPE,m.AC_ENTRY_NO 
                                                     ,T.EFFECT,T.TRNS_TYPE
                      from st_trns_mast m , st_trns_type t
                     where M.TRNS_DATE      BETWEEN g_cur.TRNS_DATE      AND g_cur.TRNS_DATE
                       AND M.TRNS_TYPE_CODE BETWEEN g_cur.TRNS_TYPE_CODE AND g_cur.TRNS_TYPE_CODE
                       AND M.TRNS_SERIAL    BETWEEN g_cur.TRNS_SERIAL    AND g_cur.TRNS_SERIAL
--                     and   m.Store_code     between :from_Store and :to_Store
                     and nvl(m.cust_post_flag,0) = 0 
                     and nvl(m.delete_flag,0) = 0 
                     and t.trns_type_code = m.trns_type_code
                     and t.effect in (1 , 2 , 3 , 4 , 5)
                     and t.join_type in (3)
                     and (t.trns_type <> 2 or (t.trns_type = 2 /*and m.delivery_date is not null*/)) 
                   order by T.EFFECT,trns_date ,date_serial,m.trns_type_code,trns_serial 
                  ) Loop
  -- ------------------------------------------------------------------------- 
  -- For each transaction, get its type join data
  -- ------------------------------------------------------------------------- 
     get_trns_data(Trns_Rec.Trns_type_code,
                   Join_Type,Entry_Type,Cust_Trns_code,Supp_Trns_Code,
                   pay_Supp_Trns_Code,Trns_Post_Type,SUPP_DISC_TRNS_TYPE); 
                   
  -- -------------------------------------------------------------------------           
   if join_type = '3' then
           -- customer joint
    if nvl(cust_trns_code,0) != 0 and nvl(Trns_rec.Customer_Code,0) != 0 then
         begin
        /*
             select ctgry_code
             into  category_type_code
             from salesman
             where code = trns_rec.salesman_code;
*/
        
              
             SELECT CTGRY_CODE
             INTO category_type_code
             FROM AR_TRNSTYPE
             WHERE ID = cust_trns_code ; 
        
        exception
            when OTHERS then
                NULL;
        end;
         
    IF category_type_code IS NULL THEN
        -- legacy: CUSTOM_ALERT + RAISE FORM_TRIGGER_FAILURE
        app_msg(' لا يوجد قسم لرقم حركة العملاء التالي ' || cust_trns_code, 'No department please check', 1);
    END IF; 
           if make_customer_entry(Trns_Rec.trns_type_code ,   
                                   Trns_Rec.trns_serial,
                         --888888888888 , 
                                                                  Trns_Rec.store_code , 
                                                                  category_type_code,
                                   Trns_rec.Customer_Code,
                                   Trns_rec.SALESMAN_CODE,
                                   trns_rec.doc_no,
                                   cust_trns_code,pay_cust_Trns_Code,
                                   TRNS_REC.EFFECT,
                                   TRNS_REC.TRNS_TYPE,TRNS_REC.INVOICE_NO,
                                   TRNS_REC.AC_ENTRY_YEAR,
                                   TRNS_REC.AC_ENTRY_TYPE,
                                   TRNS_REC.AC_ENTRY_NO)
             
                              then
                           
--message('after make_customer_entry'); pause;
              g_cust_posted:= g_cust_posted+1;null;
            end if;
          end if;

        end if;
  -- ------------------------------------------------------------------------- 
   end loop;
End;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit INSERT_SUPPLIER_TRNS (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION INSERT_SUPPLIER_TRNS (V_ST_TRNS_TYPE               NUMBER,
                                                           V_ST_TRNS_SERIAL             NUMBER,
                                                           IN_TRNS_ID                   VN_TRNSTYPE.ID%TYPE,
                                                           IN_TRNS_DATE                 DATE,
                                                           IN_BILL_DATE                 DATE,
                                                           IN_DOC_NO                    VN_MAINTRNS.DOC_NO%TYPE,
                                                           IN_TOTAL_VALUE               VN_MAINTRNS.TOTAL_VALUE%TYPE,
                                                           IN_DESC_A                    VN_MAINTRNS.DESCRIPTION_A%TYPE,
                                                           IN_DESC_E                    VN_MAINTRNS.DESCRIPTION_E%TYPE,
                                                           IN_SUPPLIER_ID               VN_MAINTRNS.SUPPLIER_ID%TYPE,
                                                           IN_BILL_ID1                  VN_SUBTRNS.BILL_ID1%TYPE,
                                                           IN_BILL_ID2                  VN_SUBTRNS.BILL_ID2%TYPE,
                                                           IN_STORE_CODE                ST_STORE.STORE_CODE%TYPE,
                                                           IN_CURRENCY_CODE             NUMBER,
                                                           IN_CURRENCY_RATE             NUMBER,
                                                           OUT_PAY_TRNS_SERIAL   IN OUT NUMBER,
                                                           IN_SUPP_TRNS_ID              NUMBER,
                                                           IN_SUPP_TRNS_SERIAL          NUMBER,
                                                           W_AC_ENTRY_YEAR              NUMBER,
                                                           W_AC_ENTRY_TYPE              NUMBER,
                                                           W_AC_ENTRY_NO                NUMBER,
                                                           IN_PURCH_CODE                NUMBER) RETURN NUMBER
IS
   T_TRNS_SERIAL      NUMBER;
   TEMP_EFFECT        NUMBER;
   IN_BILL_SEQ        NUMBER;
   LOOP_INDEX         NUMBER := 0;
   V_TOTAL            NUMBER := 0;
   DUMMY              NUMBER;
   V_TEMP             NUMBER;
   REMAIN_VALUE       NUMBER;
   TEMP_BILL_SEQ      NUMBER;
   TRNS_TOTAL_VALUE   NUMBER;
   V_PAY_TYPE_CODE    NUMBER;
   V_POST_SYSTEM      NUMBER;
   V_ATM_DESC         VARCHAR2 (2000);
   V_SUPP_NAME        VARCHAR2 (2000);
   V_DESC_A           VARCHAR2 (2000);
   V_SUPPLIER_REF     VARCHAR2 (50);
BEGIN
   SELECT NVL (ATM_DESC, DOC_NO), SUPPLIER_REF
     INTO V_ATM_DESC, V_SUPPLIER_REF
     FROM ST_TRNS_MAST
    WHERE TRNS_TYPE_CODE = V_ST_TRNS_TYPE AND TRNS_SERIAL = V_ST_TRNS_SERIAL;

   SELECT DECODE (TRNS_TYPE,  1, 30,  2, 31,  3, 30,  4, 31,  3)
     INTO V_POST_SYSTEM
     FROM ST_TRNS_TYPE T
    WHERE T.TRNS_TYPE_CODE = V_ST_TRNS_TYPE;

   IF g_supplier_code IS NULL OR g_first_record = 0
   THEN
      BEGIN
         BEGIN
            SELECT PAY_TYPE_CODE
              INTO V_PAY_TYPE_CODE
              FROM VN_BASIC
             WHERE SERIAL = g_company;
         EXCEPTION
            WHEN OTHERS
            THEN
               V_PAY_TYPE_CODE := 0;
         END;

         IF NVL (V_PAY_TYPE_CODE, 0) = 0
         THEN
            app_msg('يجب تحديد رقم دفعة المشتريات',
                 'Must enter Purchase Pay Type',
                 1);
         END IF;
      END;

      BEGIN
         IF IN_SUPP_TRNS_SERIAL IS NOT NULL
         THEN
            SELECT COUNT (1)
              INTO DUMMY
              FROM VN_MAINTRNS
             WHERE     TRNS_ID = IN_SUPP_TRNS_ID
                   AND TRNS_SERIAL = IN_SUPP_TRNS_SERIAL;

            IF NVL (DUMMY, 0) > 0
            THEN
               BEGIN
                  SELECT NVL (MAX (TRNS_SERIAL), 0) + 1
                    INTO T_TRNS_SERIAL
                    FROM VN_MAINTRNS
                   WHERE TRNS_ID = IN_TRNS_ID;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     T_TRNS_SERIAL := 1;
               END;
            ELSE
               T_TRNS_SERIAL := IN_SUPP_TRNS_SERIAL;
            END IF;
         ELSE
            BEGIN
               SELECT NVL (MAX (TRNS_SERIAL), 0) + 1
                 INTO T_TRNS_SERIAL
                 FROM VN_MAINTRNS
                WHERE TRNS_ID = IN_TRNS_ID;
            EXCEPTION
               WHEN OTHERS
               THEN
                  T_TRNS_SERIAL := 1;
            END;
         END IF;
      END;
   ELSE
      T_TRNS_SERIAL := g_supp_trns_serial;
   END IF;

   BEGIN
      SELECT NVL (MAX (BILL_SEQ), 0) + 1
        INTO IN_BILL_SEQ
        FROM VN_SUBTRNS
       WHERE TRNS_ID = IN_TRNS_ID AND TRNS_SERIAL = T_TRNS_SERIAL;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         IN_BILL_SEQ := 1;
   END;

   BEGIN
      SELECT SUM (AMOUNT) / IN_CURRENCY_RATE
        INTO V_TOTAL
        FROM ST_TRNS_DET_DUES
       WHERE     TRNS_TYPE_CODE = V_ST_TRNS_TYPE
             AND TRNS_SERIAL = V_ST_TRNS_SERIAL;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         V_TOTAL := 0;
   END;

   IF g_supplier_code IS NULL OR g_first_record = 0
   THEN
      SELECT NAME_A
        INTO V_SUPP_NAME
        FROM SUPPLIER
       WHERE CODE = IN_SUPPLIER_ID;

      V_DESC_A :=
         SUBSTR (
               'توريد مواد من المورد '
            || V_SUPP_NAME
            || ' طبقا لفاتورة المورد رقم '
            || V_ATM_DESC,
            1,
            240);

      INSERT INTO VN_MAINTRNS (TRNS_ID,
                               TRNS_SERIAL,
                               TRNS_DATE,
                               DOC_NO,
                               TOTAL_VALUE,
                               DISC_VALUE,
                               NET_VALUE,
                               DESCRIPTION_A,
                               DESCRIPTION_E,
                               SUPPLIER_ID,
                               LINK_FLAG,
                               POST_FLAG,
                               RESIDUAL_VALUE,
                               CURRENCY_CODE,
                               CURRENCY_RATE,
                               ACC_YEAR,
                               ACC_TYPE,
                               ACC_NO,
                               ACC_DATE,
                               RESP_CODE,
                               POST_SYSTEM,
                               PAY_TYPE_CODE,
                               SUPPLIER_REF)
           VALUES (IN_TRNS_ID,
                   T_TRNS_SERIAL,
                   IN_TRNS_DATE,
                   IN_DOC_NO,
                   IN_TOTAL_VALUE / IN_CURRENCY_RATE,
                   0,
                   IN_TOTAL_VALUE / IN_CURRENCY_RATE,
                   /*v_desc_a ,
                   v_desc_a ,*/
                   IN_DESC_A,
                   IN_DESC_E,
                   IN_SUPPLIER_ID,
                   1,
                   1,
                   IN_TOTAL_VALUE / IN_CURRENCY_RATE,
                   IN_CURRENCY_CODE,
                   IN_CURRENCY_RATE,
                   W_AC_ENTRY_YEAR,
                   W_AC_ENTRY_TYPE,
                   W_AC_ENTRY_NO,
                   IN_TRNS_DATE,
                   IN_PURCH_CODE,
                   V_POST_SYSTEM,
                   V_PAY_TYPE_CODE,
                   V_SUPPLIER_REF);

      IF g_supplier_code IS NOT NULL
      THEN
         g_first_record := 1;
         g_supp_trns_serial := T_TRNS_SERIAL;
      END IF;
   ELSE
      UPDATE VN_MAINTRNS
         SET TOTAL_VALUE = TOTAL_VALUE + IN_TOTAL_VALUE / IN_CURRENCY_RATE,
             NET_VALUE = NET_VALUE + IN_TOTAL_VALUE / IN_CURRENCY_RATE,
             RESIDUAL_VALUE = RESIDUAL_VALUE + 0
       WHERE TRNS_ID = IN_TRNS_ID AND TRNS_SERIAL = T_TRNS_SERIAL;
   END IF;

   LOOP_INDEX := 0;

   FOR DUE
      IN (SELECT TRNS_TYPE_CODE,
                 TRNS_SERIAL,
                 DUE_SERIAL,
                 SUPP_DUE_DATE,
                 POSTING_SUPP_DUE_DATE,
                 AMOUNT,
                 AMOUNT_CURR,
                 PAYED_FLAG
            FROM ST_TRNS_DET_DUES
           WHERE     TRNS_TYPE_CODE = V_ST_TRNS_TYPE
                 AND TRNS_SERIAL = V_ST_TRNS_SERIAL)
   LOOP
      LOOP_INDEX := LOOP_INDEX + 1;

      INSERT INTO VN_SUBTRNS (TRNS_ID,
                              TRNS_SERIAL,
                              INV_DATE,
                              BILL_SEQ,
                              BILL_ID1,
                              BILL_ID2,
                              TOTAL_VALUE,
                              DISC_VALUE,
                              NET_VALUE,
                              RESIDUAL_VALUE,
                              DUE_DATE,
                              PAY_TYPE_CODE)
           VALUES (IN_TRNS_ID,
                   T_TRNS_SERIAL,
                   IN_BILL_DATE,
                   IN_BILL_SEQ,
                   V_ST_TRNS_TYPE || V_ST_TRNS_SERIAL,
                   DUE.DUE_SERIAL, -- LOOP_INDEX, --DUE.DUE_SERIAL,  --in_bill_id2    ,
                   DUE.AMOUNT / IN_CURRENCY_RATE,
                   0,
                   DUE.AMOUNT / IN_CURRENCY_RATE,
                   (DUE.AMOUNT                          /*-nvl(in_payment,0)*/
                              ) / IN_CURRENCY_RATE,
                   DUE.POSTING_SUPP_DUE_DATE,
                   V_PAY_TYPE_CODE);

      IN_BILL_SEQ := IN_BILL_SEQ + 1;
      LOOP_INDEX := DUE.DUE_SERIAL + 1;
   END LOOP;

   -- -------------------------------------------------------------------------------------
   BEGIN
      SELECT EFFECT
        INTO TEMP_EFFECT
        FROM VN_TRNSTYPE
       WHERE ID = IN_TRNS_ID;

      IF TEMP_EFFECT = 0
      THEN
         SELECT COUNT (1)
           INTO V_TEMP
           FROM ST_TRNS_MAST MT, ST_TRNS_TYPE TT
          WHERE     MT.TRNS_TYPE_CODE = TT.TRNS_TYPE_CODE
                AND TT.EFFECT = 1
                AND TT.TRNS_TYPE = 1
                AND (MT.TRNS_TYPE_CODE,MT.TRNS_SERIAL) IN
                                 (SELECT RET_TRNS_TYPE_CODE,RET_TRNS_SERIAL
                                    FROM ST_TRNS_MAST
                                   WHERE TRNS_TYPE_CODE = V_ST_TRNS_TYPE
                                     AND TRNS_SERIAL = V_ST_TRNS_SERIAL);

         IF V_TEMP > 0
         THEN                                              -- مرتجع على فاتورة
            FOR PUR_REC
               IN (SELECT MT.TRNS_SERIAL,
                          MT.TRNS_TYPE_CODE,
                          MT.SUPP_POST_FLAG,
                          SUPP_TRNS_ID,
                          SUPP_TRNS_SERIAL
                     FROM ST_TRNS_MAST MT, ST_TRNS_TYPE TT
                    WHERE     MT.TRNS_TYPE_CODE = TT.TRNS_TYPE_CODE
                          AND TT.EFFECT = 1
                          AND TT.TRNS_TYPE = 1
                          AND (MT.TRNS_TYPE_CODE,MT.TRNS_SERIAL) IN
                                 (SELECT RET_TRNS_TYPE_CODE,RET_TRNS_SERIAL
                                    FROM ST_TRNS_MAST
                                   WHERE TRNS_TYPE_CODE = V_ST_TRNS_TYPE
                                     AND TRNS_SERIAL = V_ST_TRNS_SERIAL))
            LOOP
               IF (NVL (PUR_REC.SUPP_POST_FLAG, 0) = 1)
               THEN                                   --تم ترحيل فاتورة الشراء
                  REMAIN_VALUE := IN_TOTAL_VALUE;
                  TEMP_BILL_SEQ := 1;

                  FOR BILL_REC
                     IN (  SELECT TOTAL_VALUE,
                                  NVL (RESIDUAL_VALUE, 0) RESIDUAL_VALUE,
                                  BILL_SEQ,
                                  BILL_ID2
                             FROM VN_SUBTRNS
                            WHERE BILL_ID1 = PUR_REC.TRNS_TYPE_CODE || PUR_REC.TRNS_SERIAL
                              AND TRNS_ID IN (SELECT ID FROM VN_TRNSTYPE WHERE EFFECT = 1)
                         ORDER BY BILL_SEQ)
                  LOOP
                     /*IF(BILL_REC.RESIDUAL_VALUE > 0) AND NVL(REMAIN_VALUE,0) > 0 THEN--             متبقى منها للسداد
                         IF(REMAIN_VALUE/in_currency_rate < BILL_REC.RESIDUAL_VALUE)THEN
                             TRNS_TOTAL_VALUE:=IN_TOTAL_VALUE;
                             REMAIN_VALUE := 0;
                         ELSE
                             REMAIN_VALUE:=REMAIN_VALUE/in_currency_rate-BILL_REC.RESIDUAL_VALUE;
                             TRNS_TOTAL_VALUE:=BILL_REC.RESIDUAL_VALUE;
                         END IF;*/

                     UPDATE VN_SUBTRNS
                        SET RESIDUAL_VALUE = RESIDUAL_VALUE - IN_TOTAL_VALUE
                      WHERE     BILL_ID1 =
                                      PUR_REC.TRNS_TYPE_CODE
                                   || PUR_REC.TRNS_SERIAL
                            AND BILL_SEQ = BILL_REC.BILL_SEQ
                            AND RESIDUAL_VALUE IS NOT NULL;

                     INSERT INTO VN_SUBTRNS (TRNS_ID,
                                             TRNS_SERIAL,
                                             INV_DATE,
                                             BILL_SEQ,
                                             BILL_ID1,
                                             BILL_ID2,
                                             TOTAL_VALUE,
                                             DISC_VALUE,
                                             NET_VALUE,
                                             RESIDUAL_VALUE,
                                             PAY_TYPE_CODE,
                                             INV_TRNS_ID,
                                             INV_TRNS_SERIAL,
                                             INV_BILL_SEQ)
                             VALUES (
                                       IN_TRNS_ID,
                                       T_TRNS_SERIAL,
                                       IN_BILL_DATE,
                                       TEMP_BILL_SEQ,
                                          PUR_REC.TRNS_TYPE_CODE
                                       || PUR_REC.TRNS_SERIAL,
                                       BILL_REC.BILL_ID2,
                                       IN_TOTAL_VALUE,
                                       0,
                                       IN_TOTAL_VALUE,
                                       IN_TOTAL_VALUE,
                                       V_PAY_TYPE_CODE,
                                       PUR_REC.SUPP_TRNS_ID,
                                       PUR_REC.SUPP_TRNS_SERIAL,
                                       BILL_REC.BILL_SEQ);

                     TEMP_BILL_SEQ := TEMP_BILL_SEQ + 1;
                  --END IF;
                  END LOOP;
               END IF;
            END LOOP;
         END IF;
      END IF;
   END;

   -- -------------------------------------------------------------------------------------
   --  message('before insert into ar_maintrns'); pause;

   RETURN (T_TRNS_SERIAL);
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit INSERT_SRVC_VNDR_TRNS (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION INSERT_SRVC_VNDR_TRNS (
    V_ST_TRNS_TYPE          NUMBER,
    V_ST_TRNS_SERIAL        NUMBER,
    in_trns_id            vn_trnstype.id%type ,
    in_trns_date          date ,
    in_doc_no             vn_maintrns.doc_no%type ,
    in_total_value        vn_maintrns.total_value%type ,
    in_desc_a             vn_maintrns.description_a%type ,
    in_desc_e             vn_maintrns.description_e%type ,
    in_Supplier_id        vn_maintrns.Supplier_id%type ,
    W_AC_ENTRY_YEAR   NUMBER,
    W_AC_ENTRY_TYPE   NUMBER,
    W_AC_ENTRY_NO     NUMBER,
    v_trns_serial number,
    in_CURRENCY_CODE number,
    in_CURRENCY_RATE number,
    in_serial number) return number
IS
    t_trns_serial     number;
    in_bill_seq         Number;
    DUE_DATE_VAR      NUMBER;
    V_POST_SYSTEM     NUMBER;
    V_ATM_DESC VARCHAR2(2000);
    v_supp_name VARCHAR2(2000);
    v_desc_a   VARCHAR2(2000); 
    V_SUPPLIER_REF VARCHAR2(50);
    V_PAY_TYPE_CODE number;
BEGIN
  BEGIN
     SELECT PAY_TYPE_CODE
       INTO V_PAY_TYPE_CODE
       FROM VN_BASIC
      WHERE SERIAL = g_company;
  EXCEPTION
     WHEN OTHERS
     THEN
        V_PAY_TYPE_CODE := 0;
  END;

  IF NVL (V_PAY_TYPE_CODE, 0) = 0
  THEN
     app_msg('يجب تحديد رقم دفعة المشتريات',
          'Must enter Purchase Pay Type',
          1);
  END IF;
    
    SELECT DECODE(TRNS_TYPE, 1, 30, 2, 31, 3, 30, 4, 31, 3)
    INTO V_POST_SYSTEM
    FROM ST_TRNS_TYPE T
   WHERE T.TRNS_TYPE_CODE = V_ST_TRNS_TYPE;
    if v_trns_serial is null then
      BEGIN
            begin
                select nvl(max(trns_serial),0) + 1
                into   t_trns_serial
                from   vn_maintrns
                where     trns_id = in_trns_id;
            exception 
                when others then
                    t_trns_serial := 1;
            end;
      END;
    
    SELECT NVL(ATM_DESC,DOC_NO),SUPPLIER_REF
      INTO V_ATM_DESC,V_SUPPLIER_REF
      FROM ST_TRNS_MAST
     WHERE TRNS_TYPE_CODE = V_ST_TRNS_TYPE
       AND TRNS_SERIAL    = V_ST_TRNS_SERIAL ;
       
      select name_a
      into v_supp_name
      from supplier
      where code = in_Supplier_id ;
      v_desc_a := SUBSTR('توريد خدمات من المورد ' || v_supp_name || ' طبقا لفاتورة المورد رقم ' ||V_ATM_DESC,1,240);
      
      insert into vn_maintrns 
                         (trns_id       ,
                                            trns_serial   ,
                                            trns_date     ,
                          doc_no        ,
                          total_value   ,
                          disc_value    ,
                          net_value     ,
                          description_a ,
                          description_e ,
                          Supplier_id   ,
                                            link_flag        ,
                          post_flag     ,
                                            residual_value,
                          currency_code ,
                          currency_rate,
                          ACC_YEAR, ACC_TYPE, ACC_NO,
                          ACC_DATE ,
                          POST_SYSTEM,
                          SUPPLIER_REF,
                          pay_type_code)
                  values  
                         (in_trns_id      ,
                          t_trns_serial   ,
                          in_trns_date    ,
                          in_doc_no       ,
                          in_total_value  / nvl(in_CURRENCY_rate,1), 
                          0                              ,
                          in_total_value / nvl(in_CURRENCY_rate,1), 
                          /*in_desc_a       ,
                          in_desc_e       ,*/
                          v_desc_a ,
                          v_desc_a ,
                          in_Supplier_id  ,
                          1                    ,
                                            1                              ,
                          in_total_value / nvl(in_CURRENCY_rate,1) , 
                          in_CURRENCY_CODE,
                          in_CURRENCY_rate,
                          W_AC_ENTRY_YEAR  ,
                                         W_AC_ENTRY_TYPE   ,
                                         W_AC_ENTRY_NO ,
                                     in_trns_date,
                                     V_POST_SYSTEM,
                                     V_SUPPLIER_REF,
                                     V_PAY_TYPE_CODE);

    else
        t_trns_serial:=v_trns_serial;

      UPDATE vn_maintrns 
        SET total_value=total_value+in_total_value, 
                NET_VALUE=NET_VALUE+in_total_value
        WHERE TRNS_ID=in_trns_id
        AND trns_serial=t_trns_serial;
    end if;

  BEGIN
        SELECT  Nvl(Max(bill_seq),0) + 1
    INTO    in_bill_seq
    FROM    vn_subtrns
    WHERE   trns_id     = in_trns_id
        AND   trns_serial = t_trns_serial;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
            in_bill_seq := 1;
  END;

-----to select the due date
begin
    SELECT NVL(DUE_DAYS,0)
    INTO DUE_DATE_VAR
    FROM SUPPLIER
    WHERE CODE= in_Supplier_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
     DUE_DATE_VAR:=0 ;
END;
    insert into  vn_subtrns 
                             (trns_id       ,
                              trns_serial   ,
                              bill_seq      ,
                              bill_id1      ,
                              bill_id2      ,
                              total_value   ,
                              disc_value    ,
                              net_value     ,
                                                residual_value,
                                                INV_DATE,
                                                DUE_DATE)
                      values  
                             (in_trns_id     ,
                              t_trns_serial  ,
                              in_bill_seq,
                              V_ST_TRNS_TYPE || V_ST_TRNS_SERIAL ,
                              V_ST_TRNS_TYPE || V_ST_TRNS_SERIAL || in_serial ,
                              in_total_value,
                              0             ,
                              in_total_value,
                              in_total_value ,
                              in_trns_date,
                              (in_trns_date + DUE_DATE_VAR));
    return t_trns_serial;
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit INSERT_SUPPLIER_TRNS_DISC (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION INSERT_SUPPLIER_TRNS_DISC(V_ST_TRNS_TYPE               NUMBER,
                                                                   V_ST_TRNS_SERIAL             NUMBER,
                                                                   IN_TRNS_ID                   VN_TRNSTYPE.ID%TYPE,
                                                                   IN_TRNS_DATE                 DATE,
                                                                   IN_BILL_DATE                 DATE,
                                                                   IN_DOC_NO                    VN_MAINTRNS.DOC_NO%TYPE,
                                                                   IN_TOTAL_VALUE               VN_MAINTRNS.TOTAL_VALUE%TYPE,
                                                                   IN_DESC_A                    VN_MAINTRNS.DESCRIPTION_A%TYPE,
                                                                   IN_DESC_E                    VN_MAINTRNS.DESCRIPTION_E%TYPE,
                                                                   IN_SUPPLIER_ID               VN_MAINTRNS.SUPPLIER_ID%TYPE,
                                                                   IN_BILL_ID1                  VN_SUBTRNS.BILL_ID1%TYPE,
                                                                   IN_BILL_ID2                  VN_SUBTRNS.BILL_ID2%TYPE,
                                                                   IN_STORE_CODE                ST_STORE.STORE_CODE%TYPE,
                                                                   IN_CURRENCY_CODE             NUMBER,
                                                                   IN_CURRENCY_RATE             NUMBER,
                                                                   OUT_PAY_TRNS_SERIAL   IN OUT NUMBER,
                                                                   IN_SUPP_TRNS_ID              NUMBER,
                                                                   IN_SUPP_TRNS_SERIAL          NUMBER,
                                                                   W_AC_ENTRY_YEAR              NUMBER,
                                                                   W_AC_ENTRY_TYPE              NUMBER,
                                                                   W_AC_ENTRY_NO                NUMBER,
                                                                   IN_PURCH_CODE                NUMBER,
                                                                   ACT_SUPP_TRNS_ID             NUMBER,
                                                                   ACT_SUPP_TRNS_SERIAL         NUMBER) RETURN NUMBER
IS
   T_TRNS_SERIAL      NUMBER;
   TEMP_EFFECT        NUMBER;
   IN_BILL_SEQ        NUMBER;
   LOOP_INDEX         NUMBER := 0;
   V_TOTAL            NUMBER := 0;
   DUMMY              NUMBER;
   V_TEMP             NUMBER;
   REMAIN_VALUE       NUMBER;
   TEMP_BILL_SEQ      NUMBER;
   TRNS_TOTAL_VALUE   NUMBER;
   V_PAY_TYPE_CODE    NUMBER;
   V_POST_SYSTEM      NUMBER;
   V_ATM_DESC         VARCHAR2 (2000);
   V_SUPP_NAME        VARCHAR2 (2000);
   V_DESC_A           VARCHAR2 (2000);
   V_SUPPLIER_REF     VARCHAR2 (50);
   V_ITEM_BILL_SEQ    NUMBER;
BEGIN
   SELECT NVL (ATM_DESC, DOC_NO), SUPPLIER_REF
     INTO V_ATM_DESC, V_SUPPLIER_REF
     FROM ST_TRNS_MAST
    WHERE TRNS_TYPE_CODE = V_ST_TRNS_TYPE AND TRNS_SERIAL = V_ST_TRNS_SERIAL;

   SELECT DECODE (TRNS_TYPE,  1, 30,  2, 31,  3, 30,  4, 31,  3)
     INTO V_POST_SYSTEM
     FROM ST_TRNS_TYPE T
    WHERE T.TRNS_TYPE_CODE = V_ST_TRNS_TYPE;

   IF g_supplier_code IS NULL OR g_first_record = 0
   THEN
   BEGIN
         BEGIN
            SELECT PAY_TYPE_CODE
              INTO V_PAY_TYPE_CODE
              FROM VN_BASIC
             WHERE SERIAL = g_company;
         EXCEPTION
            WHEN OTHERS
            THEN
               V_PAY_TYPE_CODE := 0;
         END;

         IF NVL (V_PAY_TYPE_CODE, 0) = 0
         THEN
            app_msg('يجب تحديد رقم دفعة المشتريات',
                 'Must enter Purchase Pay Type',
                 1);
         END IF;
      END;

      BEGIN
         IF IN_SUPP_TRNS_SERIAL IS NOT NULL
         THEN
            SELECT COUNT (1)
              INTO DUMMY
              FROM VN_MAINTRNS
             WHERE     TRNS_ID = IN_SUPP_TRNS_ID
                   AND TRNS_SERIAL = IN_SUPP_TRNS_SERIAL;

            IF NVL (DUMMY, 0) > 0
            THEN
               BEGIN
                  SELECT NVL (MAX (TRNS_SERIAL), 0) + 1
                    INTO T_TRNS_SERIAL
                    FROM VN_MAINTRNS
                   WHERE TRNS_ID = IN_TRNS_ID;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     T_TRNS_SERIAL := 1;
               END;
            ELSE
               T_TRNS_SERIAL := IN_SUPP_TRNS_SERIAL;
            END IF;
         ELSE
            BEGIN
               SELECT NVL (MAX (TRNS_SERIAL), 0) + 1
                 INTO T_TRNS_SERIAL
                 FROM VN_MAINTRNS
                WHERE TRNS_ID = IN_TRNS_ID;
            EXCEPTION
               WHEN OTHERS
               THEN
                  T_TRNS_SERIAL := 1;
            END;
         END IF;
      END;
   ELSE
      T_TRNS_SERIAL := g_supp_trns_serial;
   END IF;

   BEGIN
      SELECT NVL (MAX (BILL_SEQ), 0) + 1
        INTO IN_BILL_SEQ
        FROM VN_SUBTRNS
       WHERE TRNS_ID = IN_TRNS_ID AND TRNS_SERIAL = T_TRNS_SERIAL;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         IN_BILL_SEQ := 1;
   END;

   BEGIN
      SELECT SUM (AMOUNT) / IN_CURRENCY_RATE
        INTO V_TOTAL
        FROM ST_TRNS_DET_DUES
       WHERE     TRNS_TYPE_CODE = V_ST_TRNS_TYPE
             AND TRNS_SERIAL = V_ST_TRNS_SERIAL;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         V_TOTAL := 0;
   END;

   IF g_supplier_code IS NULL OR g_first_record = 0
   THEN
      SELECT NAME_A
        INTO V_SUPP_NAME
        FROM SUPPLIER
       WHERE CODE = IN_SUPPLIER_ID;

      V_DESC_A :=
         SUBSTR (
               'توريد مواد من المورد '
            || V_SUPP_NAME
            || ' طبقا لفاتورة المورد رقم '
            || V_ATM_DESC,
            1,
            240);

      INSERT INTO VN_MAINTRNS (TRNS_ID,
                               TRNS_SERIAL,
                               TRNS_DATE,
                               DOC_NO,
                               SUPPLIER_REF,
                               TOTAL_VALUE,
                               DISC_VALUE,
                               DESCRIPTION_A,
                               DESCRIPTION_E,
                               SUPPLIER_ID,
                               LINK_FLAG,
                               POST_FLAG,
                               INV_VALUE,
                               CURRENCY_CODE,
                               CURRENCY_RATE,
                               ACC_YEAR,
                               ACC_TYPE,
                               ACC_NO,
                               ACC_DATE,
                               RESP_CODE,
                               POST_SYSTEM,
                               PAY_TYPE_CODE,
                               RESIDUAL_VALUE,
                               PAY_METHOD,
                               PAY_FLAG,
                               CURRENCY_DIFF_VALUE)
           VALUES (IN_TRNS_ID,
                   T_TRNS_SERIAL,
                   IN_TRNS_DATE,
                   IN_DOC_NO,
                   V_SUPPLIER_REF,
                   ROUND(IN_TOTAL_VALUE / IN_CURRENCY_RATE,2),
                   0,
                   /*v_desc_a ,
                   v_desc_a ,*/
                   'خصم فاتورة مشتريات رقم ' || V_SUPPLIER_REF,
                   'خصم فاتورة مشتريات رقم ' || V_SUPPLIER_REF,
                   IN_SUPPLIER_ID,
                   1,
                   1,
                   ROUND(IN_TOTAL_VALUE / IN_CURRENCY_RATE,2),
                   IN_CURRENCY_CODE,
                   IN_CURRENCY_RATE,
                   W_AC_ENTRY_YEAR,
                   W_AC_ENTRY_TYPE,
                   W_AC_ENTRY_NO,
                   IN_TRNS_DATE,
                   IN_PURCH_CODE,
                   V_POST_SYSTEM,
                   V_PAY_TYPE_CODE,
                   0,
                   5,
                   0,
                   0);

      IF g_supplier_code IS NOT NULL
      THEN
         g_first_record := 1;
         g_supp_trns_serial := T_TRNS_SERIAL;
      END IF;
   ELSE
      UPDATE VN_MAINTRNS
         SET TOTAL_VALUE = TOTAL_VALUE + IN_TOTAL_VALUE / IN_CURRENCY_RATE,
             NET_VALUE = NET_VALUE + IN_TOTAL_VALUE / IN_CURRENCY_RATE,
             RESIDUAL_VALUE = RESIDUAL_VALUE + 0
       WHERE TRNS_ID = IN_TRNS_ID AND TRNS_SERIAL = T_TRNS_SERIAL;
   END IF;
   
      INSERT INTO VN_SUBTRNS (TRNS_ID,
                              TRNS_SERIAL,
                              INV_DATE,
                              BILL_SEQ,
                              BILL_ID1,
                              BILL_ID2,
                              TOTAL_VALUE,
                              DISC_VALUE,
                              NET_VALUE,
                              PAY_TYPE_CODE,
                              INV_TRNS_ID,
                              INV_TRNS_SERIAL,
                              INV_BILL_SEQ,
                              INV_SUPPLIER_REF)
           VALUES (IN_TRNS_ID,
                   T_TRNS_SERIAL,
                   IN_BILL_DATE,
                   1,
                   V_ST_TRNS_TYPE || V_ST_TRNS_SERIAL,
                   1,
                   ROUND(IN_TOTAL_VALUE / IN_CURRENCY_RATE,2),
                   0,
                   ROUND(IN_TOTAL_VALUE / IN_CURRENCY_RATE,2),
                   V_PAY_TYPE_CODE,
                   ACT_SUPP_TRNS_ID,
                   ACT_SUPP_TRNS_SERIAL,
                   1,
                   V_SUPPLIER_REF);
         
         FOR REC IN (SELECT GROUP_CODE, ITEM_CODE, SUPP_DISC_VALUE, QUANTITY, SUPP_DISC_RATIO FROM ST_TRNS_DET WHERE TRNS_TYPE_CODE = V_ST_TRNS_TYPE AND TRNS_SERIAL = V_ST_TRNS_SERIAL AND NVL(SUPP_DISC_VALUE,0) <> 0 AND NVL(DELETE_FLAG,0) = 0)LOOP
              BEGIN
                  SELECT NVL(MAX(BILL_SEQ),0) + 1
                    INTO V_ITEM_BILL_SEQ
                    FROM VN_SUBTRNS_ITEMS
                   WHERE TRNS_ID = IN_TRNS_ID
                     AND TRNS_SERIAL = T_TRNS_SERIAL;
              EXCEPTION WHEN OTHERS THEN
                  V_ITEM_BILL_SEQ := 1;
              END;
                       
                        Insert into VN_SUBTRNS_ITEMS
                           (TRNS_ID, TRNS_SERIAL, BILL_SEQ, BILL_ID1, BILL_ID2, 
                            GROUP_CODE, ITEM_CODE, DISC_VALUE, DISC_RATIO, TOTAL_DISC, 
                            SUPPLIER_REF)
                         Values
                           (IN_TRNS_ID, T_TRNS_SERIAL, V_ITEM_BILL_SEQ, V_ST_TRNS_TYPE, V_ST_TRNS_SERIAL, 
                            REC.GROUP_CODE, REC.ITEM_CODE, ROUND(REC.SUPP_DISC_VALUE * REC.QUANTITY * IN_CURRENCY_RATE,2), REC.SUPP_DISC_RATIO, 0, 
                            V_SUPPLIER_REF);
                 END LOOP;
   
   RETURN (T_TRNS_SERIAL);
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit MAKE_SUPPLIER_ENTRY (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION MAKE_SUPPLIER_ENTRY (
             in_trns_type_code   st_trns_mast.Trns_Type_Code%type,             
             in_serial_number    st_trns_mast.Trns_Serial%type,
                          in_store_code         st_store.store_code%TYPE,
             in_post_SupplierCode     st_trns_mast.Customer_Code%type,
             in_DocumentCode     st_trns_mast.Doc_no%type,
             in_supp_trns_code   st_trns_type.customer_trns_code%type,
             in_supp_pay_trns_code number,
             in_trns_supplier number,
             IN_PURCH_CODE NUMBER,
             IN_SUPP_DISC_TRNS_TYPE NUMBER)
RETURN boolean IS
    in_transactiondate   date;
    in_TransactionTotal  number;
    --in_Description_A     varchar2(100);   
    --in_Description_e     varchar2(100);   
    in_Description_A     ST_TRNS_MAST.DESC_A%TYPE;   
    in_Description_e     ST_TRNS_MAST.DESC_E%TYPE;   
    in_effect            number(1);   
    w_freight_val        number; 
    w_disc_val           number;
    w_customs_val        number; 
    w_trnsport_val       number;
    w_insurance_val      number; 
    w_commission_val     number;
    w_others_val         number;    
    w_trns_serial       vn_maintrns.trns_serial%type;
    
    w_payment                        number;
    w_currency_code          number;
    w_currency_rate      number;
    w_pay_trns_serial    number;
    W_SUPP_TRNS_ID       NUMBER;
    W_SUPP_TRNS_SERIAL     NUMBER;
    W_AC_ENTRY_YEAR     NUMBER;
    W_AC_ENTRY_TYPE     NUMBER;
    W_AC_ENTRY_NO     NUMBER;
    in_det_disc       number;
    V_ENTRY_DATE      DATE;
    W_TAX_VALUE1                 NUMBER;
  W_SUPP_CODE                 NUMBER;
  EXT_SUPP_FLAG             NUMBER;
  W_SUPP_DISC        NUMBER;
  w_trns_serial_DISC NUMBER;
BEGIN
    if nvl(in_supp_trns_code,0) = 0 or nvl(in_post_SupplierCode,0) = 0 then
      return (false);  
     end if;

     begin         
      SELECT --ROUND(SUM(NVL(UNIT_PRICE,0) * NVL(QUANTITY,0)),2) ,
                 Sum(nvl(unit_price,0)  *  nvl(quantity,0)) Items_total,
                 sum(nvl(det_disc,0) + ((nvl(CURRENCY_RATE,0) * (nvl(disc1_VALUE,0) + nvl(disc2_VALUE,0) + nvl(disc3_VALUE,0)))*  nvl(quantity,0))) det_disc,
             NVL(SUPP_FREIGHT_VAL,0)  ,
             NVL(SUPP_INSURANCE_VAL,0)  ,
             NVL(SUPP_OTHERS_VAL,0) ,
             NVL(DISC_VAL,0) + nvl(TOT_disc1_VALUE,0) + nvl(TOT_disc2_VALUE,0) + nvl(TOT_disc3_VALUE,0),
             NVL(PAYMENT,0) + NVL(ATM_AMMOUNT,0),
             M.currency_code,
             M.currency_RATE ,         
             NVL(M.SUPP_INV_DATE,M.TRNS_DATE) ,
             NVL(M.ENTRY_DATE,M.TRNS_DATE),
             M.DESC_A ,
             M.DESC_E,
                     SUPP_TRNS_ID, SUPP_TRNS_SERIAL,
                     AC_ENTRY_YEAR, AC_ENTRY_TYPE, AC_ENTRY_NO   ,
                     nvl(round(sum(nvl(d.tax_value1,0)),2) + nvl(m.tax_value1,0),0) tax_value1,
                   S.CODE      ,
                   sum(NVL(CURRENCY_RATE,0) * nvl(supp_disc_VALUE,0)*  nvl(quantity,0)) supp_disc                
         INTO   in_TransactionTotal,
                in_det_disc,
             w_freight_val ,
             w_insurance_val ,
             w_others_val ,
             w_disc_val ,
             w_payment ,
             w_currency_code,
             w_currency_rate,
             in_Transactiondate ,
             V_ENTRY_DATE,
             in_Description_A ,
             in_Description_E,
                     W_SUPP_TRNS_ID, W_SUPP_TRNS_SERIAL,
                     W_AC_ENTRY_YEAR, W_AC_ENTRY_TYPE, W_AC_ENTRY_NO,W_TAX_VALUE1,
                 W_SUPP_CODE,
                 W_SUPP_DISC
      FROM   ST_TRNS_MAST M, ST_TRNS_DET D ,AC_CURRENCY AC , SUPPLIER S
      WHERE  M.trns_type_code = in_trns_type_code
                   AND M.trns_serial = in_serial_number
                   AND S.CURRENCY_CODE = AC.CURRENCY_CODE
                   AND S.CODE = M.POSTING_SUPPLIER_CODE
                   AND NVL(M.delete_flag,0) = 0
                   AND NVL(D.DELETE_FLAG,0)    = 0
                   AND D.trns_type_code(+) = M.trns_type_code
                   AND D.trns_serial(+) = M.trns_serial
      GROUP BY     NVL(SUPP_FREIGHT_VAL,0)  ,
             NVL(SUPP_INSURANCE_VAL,0)  ,
             NVL(SUPP_OTHERS_VAL,0) ,
             NVL(DISC_VAL,0) + nvl(TOT_disc1_VALUE,0) + nvl(TOT_disc2_VALUE,0) + nvl(TOT_disc3_VALUE,0) ,
             NVL(PAYMENT,0) + NVL(ATM_AMMOUNT,0),
             m.currency_code,
             m.currency_RATE,
             NVL(M.ENTRY_DATE,M.TRNS_DATE),        
             NVL(M.SUPP_INV_DATE,M.TRNS_DATE),
             M.DESC_A ,
             M.DESC_E,
                     SUPP_TRNS_ID, SUPP_TRNS_SERIAL,
                     AC_ENTRY_YEAR, AC_ENTRY_TYPE, AC_ENTRY_NO,nvl(m.tax_value1,0),
                 S.CODE;

        BEGIN
        SELECT  NVL(EXT_SUPP_FLAG,0) 
        INTO    EXT_SUPP_FLAG
        FROM    TX_TAXES_SUPPLIERS
        WHERE   SUPPLIER_CODE = W_SUPP_CODE AND TAX_CODE = 1;
        EXCEPTION
            WHEN OTHERS THEN
                EXT_SUPP_FLAG := 0 ;
        END;

      in_TransactionTotal := in_TransactionTotal +
                       /*  w_freight_val + 
                         w_insurance_val + 
                         w_others_val */- 
                         w_disc_val - in_det_disc - nvl(w_payment,0) + ABS(EXT_SUPP_FLAG-1) * NVL(W_TAX_VALUE1,0); 
     end;
     w_trns_serial := insert_Supplier_trns(in_trns_type_code,in_serial_number,
                      in_Supp_trns_code    ,
                      V_ENTRY_DATE,
                      in_TransactionDate   ,
                      in_DocumentCode      , 
                      in_TransactionTotal  ,
                      in_Description_A     ,   
                      in_Description_e     ,   
                      in_post_SupplierCode ,
                      in_trns_type_code    ,
                      in_serial_number     ,
                                     in_store_code        ,
                                     w_currency_code      ,
                                     w_currency_rate      ,
                                     w_pay_trns_serial,
                                            W_SUPP_TRNS_ID, W_SUPP_TRNS_SERIAL,
                                            W_AC_ENTRY_YEAR, W_AC_ENTRY_TYPE, W_AC_ENTRY_NO,
                                            IN_PURCH_CODE);
                                            
     update st_trns_mast
    set Supp_post_flag   = 1 , 
        Supp_trns_id     = in_Supp_trns_code  ,
        Supp_trns_serial = w_trns_serial
  where trns_type_code = in_trns_type_code 
    and trns_serial    = in_serial_number;
 
  IF NVL(W_SUPP_DISC,0) <> 0 THEN

      w_trns_serial_DISC := insert_Supplier_trns_DISC(in_trns_type_code,in_serial_number,
                          IN_SUPP_DISC_TRNS_TYPE    ,
                          V_ENTRY_DATE,
                          in_TransactionDate   ,
                          in_DocumentCode      , 
                          W_SUPP_DISC          ,
                          in_Description_A     ,   
                          in_Description_e     ,   
                          in_post_SupplierCode ,
                          in_trns_type_code    ,
                          in_serial_number     ,
                                         in_store_code        ,
                                         w_currency_code      ,
                                         w_currency_rate      ,
                                         w_pay_trns_serial    ,
                                                W_SUPP_TRNS_ID, 
                                                W_SUPP_TRNS_SERIAL,
                                                W_AC_ENTRY_YEAR, 
                                                W_AC_ENTRY_TYPE, 
                                                W_AC_ENTRY_NO,
                                                IN_PURCH_CODE,
                                                in_Supp_trns_code,
                                                w_trns_serial);

         update st_trns_mast
        set Supp_DISC_trns_id     = IN_SUPP_DISC_TRNS_TYPE  ,
            Supp_DISC_trns_serial = w_trns_serial_DISC
      where trns_type_code = in_trns_type_code 
        and trns_serial    = in_serial_number;
  END IF;
  
  FOR C_REC IN (SELECT EXPENS_SERIAL , SUPPLIER_CODE, NVL(FREIGHT_VAL,0) + NVL(OTHERS_VAL,0) +
                                                            NVL(CUSTOMS_VAL,0) + NVL(TRNSPORT_VAL,0) +
                                                            NVL(INSURANCE_VAL,0) + NVL(COMMISSION_VAL,0) VNDR_EXP , NVL(TAX_VALUE1,0)  TAX_VALUE1,NVL(CURRENCY_CODE,1) CURRENCY_CODE,NVL(CURRENCY_RATE,1) CURRENCY_RATE
                                FROM ST_TRNS_DET_EXPENS 
                              where trns_type_code = in_trns_type_code 
                            and trns_serial    = in_serial_number) LOOP
            BEGIN
        SELECT  NVL(EXT_SUPP_FLAG,0) 
        INTO    EXT_SUPP_FLAG
        FROM    TX_TAXES_SUPPLIERS
        WHERE   SUPPLIER_CODE = C_REC.SUPPLIER_CODE AND TAX_CODE = 1;
        EXCEPTION
            WHEN OTHERS THEN
                EXT_SUPP_FLAG := 0 ;
        END;
        if g_cust_code not in ('BEN')    then 
            w_trns_serial := insert_srvc_vndr_trns(in_trns_type_code,in_serial_number,
                          in_Supp_trns_code    ,
                          in_TransactionDate   ,
                          in_DocumentCode      , 
                          C_REC.VNDR_EXP      + ABS(EXT_SUPP_FLAG-1) * NVL(C_REC.TAX_VALUE1,0) ,
                          in_Description_A     ,   
                          in_Description_e     ,   
                                                c_rec.supplier_code,
                                                W_AC_ENTRY_YEAR, W_AC_ENTRY_TYPE, W_AC_ENTRY_NO,null,C_REC.CURRENCY_CODE,C_REC.CURRENCY_RATE,C_REC.EXPENS_SERIAL);
        else                                            
            w_trns_serial := insert_srvc_vndr_trns(in_trns_type_code,in_serial_number,
                          in_Supp_trns_code    ,
                          in_TransactionDate   ,
                          in_DocumentCode      , 
                          C_REC.VNDR_EXP      + ABS(EXT_SUPP_FLAG-1) * NVL(C_REC.TAX_VALUE1,0) ,
                          in_Description_A     ,   
                          in_Description_e     ,   
                                                c_rec.supplier_code,
                                                W_AC_ENTRY_YEAR, W_AC_ENTRY_TYPE, W_AC_ENTRY_NO,
                                                w_trns_serial,C_REC.CURRENCY_CODE,C_REC.CURRENCY_RATE,C_REC.EXPENS_SERIAL);
        end if;
        
        update ST_TRNS_DET_EXPENS
        set Supp_trns_id     = in_Supp_trns_code  ,
                Supp_trns_serial = w_trns_serial
        where trns_type_code = in_trns_type_code 
        and trns_serial    = in_serial_number
        and EXPENS_SERIAL = c_rec.EXPENS_SERIAL;
                                            
  END LOOP;
    return (true);  
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit SET_POST_SUPPLIER (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
procedure SET_POST_SUPPLIER 
IS
    Trns_Rec           st_trns_mast%rowtype;
    Join_Type          st_trns_type.Join_Type%type;
    Entry_Type         st_trns_type.Entry_Type%type;
    Cust_Trns_Code     st_trns_type.Customer_Trns_code%type;
    Supp_Trns_Code     st_trns_type.Supplier_Trns_code%type;
    supp_pay_trns_code st_trns_type.Supplier_Trns_code%type;
    Trns_Post_type     st_trns_type.Post_type%type;
    category_type_code ar_cust_salesman.CTGRY_CODE%type;
    SUPP_DISC_TRNS_TYPE st_trns_type.SUPP_DISC_TRNS_TYPE%type;
    dummy number;
BEGIN
  /* ******************************************************************* **
  **      Normal transactions Proccessing goes here (In,Out,DIn,DOut)    **
  ** ******************************************************************* */
  -- ------------------------------------------------------------------------- 
  -- Loop On Stock transactions
  -- ------------------------------------------------------------------------- 
    g_first_record:=0;
    
  For Trns_Rec in 
      (select m.TRNS_SERIAL, DOC_NO, TRNS_DATE, DATE_SERIAL, M.DESC_A, M.DESC_E, CURRENCY_RATE, DISC_VAL, FREIGHT_VAL, CUSTOMS_VAL, TRNSPORT_VAL, INSURANCE_VAL, COMMISSION_VAL, OTHERS_VAL, POST_FLAG, DELETE_FLAG, M.TRNS_TYPE_CODE, CURRENCY_CODE, SUPPLIER_CODE, CUSTOMER_CODE, COST_CODE, ACCOUNT_NUMBER1, ACCOUNT_NUMBER2, ACCOUNT_NUMBER3, ACCOUNT_NUMBER4, M.STORE_CODE, SALESMAN_CODE, TRNSFER_TYPE, TRNSFER_SERIAL, TRNSFER_FROM_STORE, INVOICE_NO, CUST_POST_FLAG, CUST_TRNS_ID, CUST_TRNS_SERIAL, SUPP_POST_FLAG, SUPP_TRNS_ID, SUPP_TRNS_SERIAL, RET_TRNS_TYPE_CODE, RET_TRNS_SERIAL, PAYMENT, AC_ENTRY_YEAR, AC_ENTRY_TYPE, AC_ENTRY_NO, TRNSFER_TO_STORE, CASH_CUSTOMER, SUPP_OTHERS_VAL, SUPP_INSURANCE_VAL, SUPP_FREIGHT_VAL, REQUEST_NO, COST_CODE2, DUE_DATE, POSTING_SUPPLIER_CODE, STAND_DSCNT, REQ_TRNS_TYPE_CODE, REQ_TRNS_SERIAL, LOT_NO, ACCOUNT_NUMBER2_DESC, ACCOUNT_NUMBER3_DESC, ACCOUNT_NUMBER4_DESC, STORE_SESSION_ID, VISA_AMMOUNT, CHANGE_AMMOUNT, CARD_AMMOUNT, ATM_AMMOUNT, ATM_DESC, VISA_DESC, DELETE_USER, UPDATE_USER, INSERT_USER, SPECIAL_DISC, CASH_AMMOUNT, APPROVE_FLAG, OPER_CODE, OPER_SERIAL, COMM_FLAG, TRNSFORM_SERIAL, DELETE_DATE, UPDATE_DATE, INSERT_DATE, DEMO_TRNS_TYPE_CODE, DEMO_TRNS_SERIAL, INV_PAY_DT, M.REDUCTION_RATIO, TRNS_SERIAL_TOTAL, PO_NO, INV_TYPE, PAY_TERM, DELIVERY_NO, CUST_TRNS_PAY_CODE, CUST_TRNS_SERIAL_PAY, M.DELIVERY_TRNS_TYPE_CODE, M.DELIVERY_TRNS_SERIAL, MN_ISSUE_FLAG, PO_NUMBER, PURCH_CODE, INCOME_TRNS_TYPE_CODE, INCOME_TRNS_SERIAL, PR_TRNS_TYPE_CODE, PR_TRNS_SERIAL, M.ORDER_TRNS_TYPE_CODE, ORDER_TRNS_SERIAL, SUPP_INV_DATE
    from st_trns_mast m , st_trns_type t
       where M.TRNS_DATE      BETWEEN g_cur.TRNS_DATE      AND g_cur.TRNS_DATE
      AND M.TRNS_TYPE_CODE BETWEEN g_cur.TRNS_TYPE_CODE AND g_cur.TRNS_TYPE_CODE
      AND M.TRNS_SERIAL    BETWEEN g_cur.TRNS_SERIAL    AND g_cur.TRNS_SERIAL
       and nvl(m.supp_post_flag,0) = 0 
       and nvl(m.delete_flag,0) = 0 
       and t.trns_type_code = m.trns_type_code
       and t.effect in (1 , 2 , 3 , 4 , 5)
       and t.join_type in (4)
        and (m.SUPPLIER_CODE = g_supplier_code OR g_supplier_code IS NULL)
        and (t.trns_type <> 2 or (t.trns_type = 2 /*and m.delivery_date is not null*/)) 
    order by trns_date ,date_serial,m.trns_type_code,trns_serial 
    ) Loop
  -- ------------------------------------------------------------------------- 
  -- For each transaction, get its type join data
  -- ------------------------------------------------------------------------- 
        get_trns_data(Trns_Rec.Trns_type_code,Join_Type,Entry_Type,Cust_Trns_code,Supp_Trns_Code,supp_pay_trns_code,Trns_Post_Type,SUPP_DISC_TRNS_TYPE); 
      -- -------------------------------------------------------------------------
        if join_type = '4' then
        if nvl(Supp_trns_code,0) != 0 and nvl(Trns_rec.Supplier_Code,0) != 0 then
             if make_Supplier_entry(Trns_Rec.trns_type_code ,   
                                       Trns_Rec.trns_serial,
                                                                      Trns_Rec.store_code,
                                       Trns_rec.Posting_Supplier_Code,
                                       trns_rec.doc_no,
                                       supp_trns_code,
                                       supp_pay_trns_code,
                                       Trns_rec.Supplier_Code,
                                       TRNS_REC.PURCH_CODE,
                                       SUPP_DISC_TRNS_TYPE) then 
    
                    g_supp_posted:= g_supp_posted+1;null;
             end if;
            ELSE
              insert into st_post_msg (trns_type_code,trns_serial,message) 
                values (Trns_Rec.trns_type_code,Trns_Rec.trns_serial, ' الحركة لا تحتوى على مورد ');  
            end if;
      end if;
  -- ------------------------------------------------------------------------- 
    end loop;
End;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit CALCULATE_DISCOUNT (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION Calculate_DISCOUNT (
                        in_customer_id   IN  customer.code%TYPE,
                in_trns_id    IN  ar_maintrns.trns_id%TYPE,
                in_ctgry_code  IN  st_category_type.category_type_code%TYPE,
                PAY_DATE    IN    DATE,
                INV_TRNS_DATE  IN DATE,
                IN_TOTAL_VALUE  IN  NUMBER,
                DSCNT_PERIOD OUT NUMBER,
                DSCNT_SOURCE OUT NUMBER)
                RETURN Number IS
    DIFFERANCE_DAYS NUMBER;
    TEMP_DSCNT_PRCNT NUMBER;
    TEMP_DSCNT_VALUE NUMBER;
    ACTUAL_DISC_VALUE NUMBER;
    DISC_VALUE NUMBER;
    CURSOR CUST_DSCNT    IS
    SELECT    DSCNT_PRCNT,DSCNT_VALUE,PERIOD_SERIAL
    FROM        AR_CUST_DSCNT,AR_PERIOD
    WHERE        CUSTOMER_CODE = IN_CUSTOMER_ID AND
            DIFFERANCE_DAYS BETWEEN FROM_P AND TO_P AND
            PERIOD_SERIAL = SERIAL;


    CURSOR CLASS_DSCNT IS
    SELECT    DSCNT_PRCNT,DSCNT_VALUE,PERIOD_SERIAL
    FROM        CUSTOMER,AR_CUST_CLASS,AR_CUST_CLASS_DSCNT,AR_PERIOD
    WHERE        CODE = IN_CUSTOMER_ID AND
            DIFFERANCE_DAYS BETWEEN FROM_P AND TO_P AND
            CUSTOMER.CUST_CLASS = AR_CUST_CLASS.SERIAL AND
            AR_CUST_CLASS.SERIAL = AR_CUST_CLASS_DSCNT.SERIAL AND
            NVL(AR_CUST_CLASS.DSCNT_STOP_FLAG,0) = 0;


    CURSOR TRNS_DSCNT IS
    SELECT    DSCNT_PRCNT,DSCNT_VALUE,PERIOD_SERIAL
    FROM        AR_TRNSTYPE_DSCNT,AR_PERIOD
    WHERE        ID = IN_TRNS_ID AND
            DIFFERANCE_DAYS BETWEEN FROM_P AND TO_P AND
            AR_TRNSTYPE_DSCNT.PERIOD_SERIAL = AR_PERIOD.SERIAL;


    CURSOR CTGRY_DSCNT IS
    SELECT    DSCNT_PRCNT,DSCNT_VALUE,PERIOD_SERIAL
    FROM        AR_CTGRY_DSCNT,AR_PERIOD
    WHERE        CTGRY_CODE = IN_CTGRY_CODE AND
            DIFFERANCE_DAYS BETWEEN FROM_P AND TO_P AND
            AR_CTGRY_DSCNT.PERIOD_SERIAL = AR_PERIOD.SERIAL;

BEGIN
    DIFFERANCE_DAYS := PAY_DATE-INV_TRNS_DATE;
      if DIFFERANCE_DAYS < 0 then
         DIFFERANCE_DAYS := 1 ; 
      end if;
    OPEN CUST_DSCNT;
    FETCH CUST_DSCNT INTO TEMP_DSCNT_PRCNT,TEMP_DSCNT_VALUE,DSCNT_PERIOD;
    IF CUST_DSCNT%FOUND THEN
        DSCNT_SOURCE := 1;
        IF NVL(TEMP_DSCNT_VALUE,0) = 0 THEN
            DISC_VALUE := (TEMP_DSCNT_PRCNT * IN_TOTAL_VALUE) /(100 );
        ELSE
            ACTUAL_DISC_VALUE := (NVL(TEMP_DSCNT_PRCNT,0)  * IN_TOTAL_VALUE) /(100 );
            IF ACTUAL_DISC_VALUE > TEMP_DSCNT_VALUE THEN
                DISC_VALUE := TEMP_DSCNT_VALUE;
            ELSE
                DISC_VALUE := ACTUAL_DISC_VALUE;
            END IF;
        END IF;
    ELSE 
        OPEN CLASS_DSCNT;
        FETCH CLASS_DSCNT INTO TEMP_DSCNT_PRCNT,TEMP_DSCNT_VALUE,DSCNT_PERIOD;
        IF CLASS_DSCNT%FOUND THEN
            DSCNT_SOURCE := 2;
            IF NVL(TEMP_DSCNT_VALUE,0) = 0 THEN
                DISC_VALUE := (NVL(TEMP_DSCNT_PRCNT,0)  * IN_TOTAL_VALUE) /(100);
            ELSE
                ACTUAL_DISC_VALUE := (NVL(TEMP_DSCNT_PRCNT,0) * IN_TOTAL_VALUE) /(100 );
                IF ACTUAL_DISC_VALUE > TEMP_DSCNT_VALUE THEN
                    DISC_VALUE := TEMP_DSCNT_VALUE;
                ELSE
                    DISC_VALUE := ACTUAL_DISC_VALUE;
                END IF;
            END IF;
        ELSE
            OPEN TRNS_DSCNT;
            FETCH TRNS_DSCNT INTO TEMP_DSCNT_PRCNT,TEMP_DSCNT_VALUE,DSCNT_PERIOD;
            IF TRNS_DSCNT%FOUND THEN
                DSCNT_SOURCE := 3;
                IF NVL(TEMP_DSCNT_VALUE,0) = 0 THEN
                    DISC_VALUE := (NVL(TEMP_DSCNT_PRCNT,0) * IN_TOTAL_VALUE) /(100 );
                ELSE
                    ACTUAL_DISC_VALUE := (TEMP_DSCNT_PRCNT * IN_TOTAL_VALUE) /(100 );
                    IF ACTUAL_DISC_VALUE > TEMP_DSCNT_VALUE THEN
                        DISC_VALUE := TEMP_DSCNT_VALUE;
                    ELSE
                        DISC_VALUE := ACTUAL_DISC_VALUE;
                    END IF;
                END IF;
            ELSE
                OPEN CTGRY_DSCNT;
                FETCH CTGRY_DSCNT INTO TEMP_DSCNT_PRCNT,TEMP_DSCNT_VALUE,DSCNT_PERIOD;
                IF CTGRY_DSCNT%FOUND THEN
                    DSCNT_SOURCE := 4;
                    IF NVL(TEMP_DSCNT_VALUE,0) = 0 THEN
                        DISC_VALUE := (NVL(TEMP_DSCNT_PRCNT,0)  * IN_TOTAL_VALUE) /(100);
                    ELSE
                        ACTUAL_DISC_VALUE := (NVL(TEMP_DSCNT_PRCNT,0) * IN_TOTAL_VALUE) /(100 );
                        IF ACTUAL_DISC_VALUE > TEMP_DSCNT_VALUE THEN
                            DISC_VALUE := TEMP_DSCNT_VALUE;
                        ELSE
                            DISC_VALUE := ACTUAL_DISC_VALUE;
                        END IF;
                    END IF;
                ELSE
                    DISC_VALUE := 0;
                END IF;
                CLOSE CTGRY_DSCNT;
            END IF;
            CLOSE TRNS_DSCNT;
        END IF;
        CLOSE CLASS_DSCNT;
    END IF;
    CLOSE CUST_DSCNT;
    RETURN (ROUND(DISC_VALUE,2));
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit CHECK_VALID_CPOSTING (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION Check_Valid_cposting(P_TRNS_TYPE_CODE NUMBER,P_TRNS_SERIAL NUMBER) RETURN BOOLEAN IS
    P_TRNS_DATE DATE;
    P_EFFECT NUMBER;
    P_STORE_CODE NUMBER;
    DUMMY NUMBER;
    V_CUR_BALANCE NUMBER;
    V_CUR_COST NUMBER;
    V_UNIT_COST NUMBER;
BEGIN
  RETURN TRUE;
  SELECT    TRNS_DATE,STORE_CODE
  INTO        P_TRNS_DATE,P_STORE_CODE
  FROM        ST_TRNS_MAST
  WHERE        TRNS_TYPE_CODE = P_TRNS_TYPE_CODE AND
                  TRNS_SERIAL = P_TRNS_SERIAL;

  SELECT    EFFECT
  INTO        P_EFFECT
  FROM        ST_TRNS_TYPE
  WHERE        TRNS_TYPE_CODE = P_TRNS_TYPE_CODE;

    IF P_EFFECT IN (1,6) THEN
-- CONDITION 1 

        SELECT    COUNT(1)
        INTO        DUMMY
        FROM        ST_TRNS_MAST
        WHERE        (TRNS_TYPE_CODE,TRNS_SERIAL) IN 
                        (SELECT DISTINCT ST_TRNS_DET.TRNS_TYPE_CODE,TRNS_SERIAL 
                         FROM   ST_TRNS_DET,ST_TRNS_TYPE
                         WHERE    ST_TRNS_DET.TRNS_TYPE_CODE = ST_TRNS_TYPE.TRNS_TYPE_CODE AND
                                         EFFECT NOT IN (1,6) AND
                                         ST_TRNS_DET.STORE_CODE = P_STORE_CODE AND
                                         TRNS_DATE >= P_TRNS_DATE AND
                                         (GROUP_CODE,ITEM_CODE) IN 
                                         (SELECT DISTINCT GROUP_CODE,ITEM_CODE
                                          FROM   ST_TRNS_DET 
                                          WHERE  TRNS_TYPE_CODE = P_TRNS_TYPE_CODE AND
                                                          TRNS_SERIAL = P_TRNS_SERIAL)) AND
                        NVL(DELETE_FLAG,0) = 0 AND
                        NVL(POST_FLAG,0) = 1 ;

        IF DUMMY > 0 THEN
                INSERT INTO ST_POST_MSG (TRNS_TYPE_CODE,TRNS_SERIAL,MESSAGE) 
        VALUES (P_TRNS_TYPE_CODE,P_TRNS_SERIAL,'يوجد حركة مبيعات او تحويلات او مرتجع مرحلة بعد تاريخ الحركة المراد فك ترحيلها');
                RETURN FALSE;
        END IF;
    END IF;
    RETURN TRUE;
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit MAKE_REVERSE_ACC (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION MAKE_REVERSE_ACC RETURN BOOLEAN IS
  TEMP_CLOSE_DATE DATE;
  CNT   NUMBER := 0 ;
  S_ALERT NUMBER ;
BEGIN
    SELECT CLOSE_DATE 
    INTO     TEMP_CLOSE_DATE
    FROM   AC_BASIC
    WHERE  COMPANY_CODE = g_company;

    FOR C_REC IN 
        (SELECT    AC_ENTRY_YEAR,
                        AC_ENTRY_TYPE,
                        AC_ENTRY_NO,
                        TRNS_TYPE_CODE, 
                        RP_TRNS_SERIAL , 
                        TRNS_SERIAL , 
                        TRNS_DATE ,
                        PC_TRNS_TYPE_CODE  , 
                        PC_TRNS_SERIAL , 
                        RP_TRNS_TYPE_CODE
            FROM    ST_TRNS_MAST
        WHERE   TRNS_DATE      BETWEEN g_cur.TRNS_DATE      AND g_cur.TRNS_DATE
      AND   TRNS_TYPE_CODE BETWEEN g_cur.TRNS_TYPE_CODE AND g_cur.TRNS_TYPE_CODE
      AND   TRNS_SERIAL    BETWEEN g_cur.TRNS_SERIAL    AND g_cur.TRNS_SERIAL
            AND   NVL(POST_FLAG,0) = 1
            AND   NVL(DELETE_FLAG,0) = 0) 
    LOOP

    SELECT COUNT(1) INTO CNT 
        FROM ST_TRNS_MAST
        WHERE AC_ENTRY_YEAR = C_REC.AC_ENTRY_YEAR 
            AND    AC_ENTRY_TYPE = C_REC.AC_ENTRY_TYPE
            AND    AC_ENTRY_NO = C_REC.AC_ENTRY_NO
            AND NVL(DELETE_FLAG,0) = 0 
            AND NVL(POST_FLAG,0) = 1;

    IF CNT > 1 AND NVL(g_allow_grouped,0) = 0 THEN
        -- legacy: alert MULT_ALET (OK / Cancel); in APEX the user confirms with the parameter p_allow_grouped
        grouped_error(C_REC.TRNS_TYPE_CODE, C_REC.TRNS_SERIAL);
    END IF;

        IF CHECK_VALID_CPOSTING(C_REC.TRNS_TYPE_CODE,C_REC.TRNS_SERIAL) THEN
            IF C_REC.TRNS_DATE <=  TEMP_CLOSE_DATE THEN 
                app_msg('لا يمكن ترحيل الحركة رقم ' || C_REC.TRNS_TYPE_CODE || '/' || C_REC.TRNS_SERIAL || ' لأنها تقع فى فترة مقفلة','You canot post the transaction ' || C_REC.TRNS_TYPE_CODE || '/' || C_REC.TRNS_SERIAL || ' becouse it lies in a closed Period ',1); 
            END IF; 
    /*     
            DELETE    AC_DAILY_TRN_DET
            WHERE        ENTRY_YEAR = C_REC.AC_ENTRY_YEAR AND
                            ENTRY_TYPE = C_REC.AC_ENTRY_TYPE AND
                            ENTRY_NO = C_REC.AC_ENTRY_NO;
   
            DELETE    AC_DAILY_TRN
            WHERE        ENTRY_YEAR = C_REC.AC_ENTRY_YEAR AND
                            ENTRY_TYPE = C_REC.AC_ENTRY_TYPE AND
                            ENTRY_NO = C_REC.AC_ENTRY_NO;
    
 */
            DELETE    AC_YEARLY_TRN_DET
            WHERE        ENTRY_YEAR = C_REC.AC_ENTRY_YEAR AND
                            ENTRY_TYPE = C_REC.AC_ENTRY_TYPE AND
                            ENTRY_NO = C_REC.AC_ENTRY_NO;
 
            DELETE        AC_YEARLY_TRN
            WHERE            ENTRY_YEAR = C_REC.AC_ENTRY_YEAR AND
                                ENTRY_TYPE = C_REC.AC_ENTRY_TYPE AND
                                ENTRY_NO = C_REC.AC_ENTRY_NO;

/*    
            UPDATE        ST_TRNS_MAST
            SET              POST_FLAG = 0 
                            --AC_ENTRY_YEAR = NULL , 
                            --AC_ENTRY_NO = NULL , 
                            --AC_ENTRY_TYPE = NULL  
                WHERE AC_ENTRY_YEAR = C_REC.AC_ENTRY_YEAR 
                    AND    AC_ENTRY_TYPE = C_REC.AC_ENTRY_TYPE
                    AND    AC_ENTRY_NO = C_REC.AC_ENTRY_NO ;
*/

FOR TRN IN (SELECT TRNS_TYPE_CODE  , TRNS_SERIAL , PC_TRNS_TYPE_CODE , PC_TRNS_SERIAL , RP_TRNS_TYPE_CODE , RP_TRNS_SERIAL 
              FROM ST_TRNS_MAST 
                         WHERE AC_ENTRY_YEAR = C_REC.AC_ENTRY_YEAR 
                             AND AC_ENTRY_TYPE = C_REC.AC_ENTRY_TYPE
                         AND AC_ENTRY_NO = C_REC.AC_ENTRY_NO     
                           AND NVL(POST_FLAG,0) = 1
                             AND NVL(DELETE_FLAG,0) = 0    
                        )
    LOOP      
            UPDATE        ST_TRNS_MAST
            SET              POST_FLAG = 0 ,
                                PC_TRNS_TYPE_CODE = NULL,
                                PC_TRNS_SERIAL = NULL,
                                RP_TRNS_TYPE_CODE = NULL,
                                RP_TRNS_SERIAL = NULL
            WHERE            TRNS_TYPE_CODE = TRN.TRNS_TYPE_CODE AND
                                TRNS_SERIAL = TRN.TRNS_SERIAL;        

          DELETE CHECK_MAST
          WHERE  TRNS_TYPE_CODE = TRN.PC_TRNS_TYPE_CODE AND
                          TRNS_SERIAL = TRN.PC_TRNS_SERIAL;

          DELETE RP_TRNS_MAST
          WHERE  TRNS_TYPE_CODE = TRN.RP_TRNS_TYPE_CODE AND
                  TRNS_SERIAL = TRN.RP_TRNS_SERIAL;
                  
            g_acct_posted := nvl(g_acct_posted,0) + 1;
    END LOOP ;
        ELSE 
          app_msg('يوجد حركة مبيعات او تحويلات او مرتجع مرحلة بعد تاريخ الحركة المراد فك ترحيلها' ,'Found Sales or Transfer or Return Purchses Posted to GL in Date After This Transaction Date     ==System Cannot Cancel Post This Transaction== ',1 ) ;
        RETURN FALSE ;
        END IF;
    END LOOP;
    RETURN TRUE;
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit UPDATE_CUSTOMER (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
PROCEDURE update_customer(cust_id customer.code%type , 
                          updt_value number) IS
BEGIN
      update customer
      set    crn_bal_total = nvl(crn_bal_total,0) + updt_value
      where code = cust_id;
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit UPDATE_SALESMAN (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
PROCEDURE Update_Salesman ( cust_id customer.code%TYPE,
                    salesman_id salesman.code%TYPE,
                    updt_value  NUMBER) IS
BEGIN
  UPDATE  ar_cust_salesman
  SET        crn_bal_total = nvl(crn_bal_total,0) + updt_value
  WHERE   customer_code = cust_id
    AND   salesman_code = salesman_id;    
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit MAKE_REVERSE_CUSTOMER (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION MAKE_REVERSE_CUSTOMER
   RETURN BOOLEAN
IS
   TEMP_TOTAL_VALUE   NUMBER;
   TEMP_PAYED_VALUE   NUMBER;
   TEMP_MAINAREA_ID   NUMBER;
   TEMP_SUBAREA_ID    NUMBER;
   DUMMY              NUMBER;
   TEMP_EFFECT        NUMBER;
   TEMP_BILL_ID1      NUMBER;
   TEMP_BILL_ID2      NUMBER;
   V_DOC_NO           VARCHAR2 (50);
BEGIN
   FOR C_REC
      IN (SELECT CUST_TRNS_ID,
                 CUST_TRNS_SERIAL,
                 TRNS_TYPE_CODE,
                 TRNS_SERIAL,
                 CUSTOMER_CODE,
                 SALESMAN_CODE,
                 DOC_NO
            FROM ST_TRNS_MAST
           WHERE TRNS_DATE BETWEEN g_cur.TRNS_DATE AND g_cur.TRNS_DATE
             AND TRNS_TYPE_CODE BETWEEN g_cur.TRNS_TYPE_CODE AND g_cur.TRNS_TYPE_CODE
             AND TRNS_SERIAL BETWEEN g_cur.TRNS_SERIAL AND g_cur.TRNS_SERIAL
             AND NVL (CUST_POST_FLAG, 0) = 1)
   LOOP
      BEGIN
         SELECT EFFECT
           INTO TEMP_EFFECT
           FROM AR_TRNSTYPE
          WHERE ID = C_REC.CUST_TRNS_ID;
      EXCEPTION WHEN OTHERS THEN
          log_msg(C_REC.TRNS_TYPE_CODE, C_REC.TRNS_SERIAL,'تأثير الحركة غير معرف  ' || ' لا يمكن الغاء الترحيل ');
          RETURN FALSE;
      END;

      BEGIN
         SELECT MAINAREA_ID, SUBAREA_ID
           INTO TEMP_MAINAREA_ID, TEMP_SUBAREA_ID
           FROM CUSTOMER
          WHERE CODE = C_REC.CUSTOMER_CODE;
      EXCEPTION WHEN OTHERS THEN
          NULL;
      END;

      IF TEMP_MAINAREA_ID IS NULL OR TEMP_SUBAREA_ID IS NULL THEN
         log_msg(C_REC.TRNS_TYPE_CODE, C_REC.TRNS_SERIAL,'الشركة و الفرع غير معرفين لعميل رقم ' || C_REC.CUSTOMER_CODE || ' لا يمكن الغاء الترحيل ');
         RETURN FALSE;
      END IF;

      BEGIN
         SELECT TOTAL_VALUE,
                NVL (TOTAL_VALUE, 0) - AR_SUBTRNS_PAYED_VALUE(TRNS_ID,TRNS_SERIAL,MAINAREA_ID,SUBAREA_ID,BILL_SEQ),
                BILL_ID1,
                BILL_ID2
           INTO TEMP_TOTAL_VALUE,
                TEMP_PAYED_VALUE,
                TEMP_BILL_ID1,
                TEMP_BILL_ID2
           FROM AR_SUBTRNS
          WHERE TRNS_ID = C_REC.CUST_TRNS_ID
            AND MAINAREA_ID = TEMP_MAINAREA_ID
            AND SUBAREA_ID = TEMP_SUBAREA_ID
            AND TRNS_SERIAL = C_REC.CUST_TRNS_SERIAL;
      EXCEPTION WHEN OTHERS THEN
          TEMP_PAYED_VALUE := 0;
          TEMP_TOTAL_VALUE := 0;
      END;

      IF TEMP_TOTAL_VALUE <> TEMP_PAYED_VALUE AND TEMP_EFFECT = 0 THEN
         SELECT NVL (MAX (M.DOC_NO), 0)
           INTO V_DOC_NO
           FROM AR_MAINTRNS M, AR_SUBTRNS D
          WHERE M.TRNS_ID = D.TRNS_ID
            AND M.MAINAREA_ID = D.MAINAREA_ID
            AND M.SUBAREA_ID = D.SUBAREA_ID
            AND M.TRNS_SERIAL = D.TRNS_SERIAL
            AND BILL_ID1 = TEMP_BILL_ID1
            AND BILL_ID2 = TEMP_BILL_ID2
            AND M.trns_id IN (SELECT ID
                                FROM AR_TRNSTYPE
                               WHERE EFFECT = 1);

         log_msg(C_REC.TRNS_TYPE_CODE, C_REC.TRNS_SERIAL,'تم سداد/مرتجع جزء من الفاتورة ' || C_REC.TRNS_TYPE_CODE || '/' || C_REC.TRNS_SERIAL || ' - سند رقم ' || V_DOC_NO || ' لا يمكن الغاء الترحيل ');
         RETURN FALSE;
      END IF;

      UPDATE_CUSTOMER(C_REC.CUSTOMER_CODE, -TEMP_TOTAL_VALUE);
      UPDATE_SALESMAN(C_REC.CUSTOMER_CODE,C_REC.SALESMAN_CODE, -TEMP_TOTAL_VALUE);

      DELETE AR_SUBTRNS
       WHERE TRNS_ID = C_REC.CUST_TRNS_ID
         AND MAINAREA_ID = TEMP_MAINAREA_ID
         AND SUBAREA_ID = TEMP_SUBAREA_ID
         AND TRNS_SERIAL = C_REC.CUST_TRNS_SERIAL;

      DELETE AR_MAINTRNS
       WHERE TRNS_ID = C_REC.CUST_TRNS_ID
         AND MAINAREA_ID = TEMP_MAINAREA_ID
         AND SUBAREA_ID = TEMP_SUBAREA_ID
         AND TRNS_SERIAL = C_REC.CUST_TRNS_SERIAL;

      UPDATE ST_TRNS_MAST
         SET CUST_POST_FLAG = 0,
             CUST_TRNS_ID = NULL,
             CUST_TRNS_SERIAL = NULL,
             CUST_TRNS_PAY_CODE = NULL,
             CUST_TRNS_SERIAL_PAY = NULL
       WHERE TRNS_TYPE_CODE = C_REC.TRNS_TYPE_CODE
         AND TRNS_SERIAL = C_REC.TRNS_SERIAL;

      g_cust_posted := g_cust_posted + 1;
   END LOOP;

   RETURN TRUE;
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit UPDATE_SUPPLIER (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
PROCEDURE UPDATE_SUPPLIER(SUPP_id customer.code%type , 
                          updt_value number) IS
BEGIN
      update SUPPLIER
      set    crn_bal_total = nvl(crn_bal_total,0) + updt_value
      where code = SUPP_id;
END;

  -- ---------------------------------------------------------------------------------------------
  -- legacy program unit MAKE_REVERSE_SUPP (ST_POSTING_CPOSTING.fmb), ported verbatim except UI calls
  -- ---------------------------------------------------------------------------------------------
FUNCTION MAKE_REVERSE_SUPP RETURN BOOLEAN IS
    DUMMY NUMBER;
    CNT   NUMBER := 0;
    S_ALERT NUMBER ;
    TEMP_TOTAL_VALUE NUMBER ;
  TEMP_PAYED_VALUE NUMBER ;
  TEMP_BILL_ID1 NUMBER ;
  TEMP_BILL_ID2 NUMBER ;
  TEMP_EFFECT   NUMBER;
  V_DOC_NO      VARCHAR2(50);
BEGIN
    
    FOR C_REC IN 
        (SELECT    SUPP_TRNS_ID,
                    SUPP_TRNS_SERIAL,
                    TRNS_TYPE_CODE,
                    TRNS_SERIAL,
                    SUPPLIER_CODE,
                    SUPP_DISC_TRNS_ID, 
                    SUPP_DISC_TRNS_SERIAL
        FROM        ST_TRNS_MAST
        WHERE    TRNS_DATE      BETWEEN g_cur.TRNS_DATE      AND g_cur.TRNS_DATE
      AND TRNS_TYPE_CODE BETWEEN g_cur.TRNS_TYPE_CODE AND g_cur.TRNS_TYPE_CODE
      AND TRNS_SERIAL    BETWEEN g_cur.TRNS_SERIAL    AND g_cur.TRNS_SERIAL AND
                    NVL(SUPP_POST_FLAG,0) = 1 AND
                    NVL(DELETE_FLAG,0) = 0) LOOP

    SELECT COUNT(1) INTO CNT 
        FROM ST_TRNS_MAST
        WHERE        SUPP_TRNS_SERIAL = C_REC.SUPP_TRNS_SERIAL 
        AND        SUPP_TRNS_ID = C_REC.SUPP_TRNS_ID AND
                    NVL(DELETE_FLAG,0) = 0 
                    AND NVL(SUPP_POST_FLAG,0) = 1;

IF CNT > 1 AND NVL(g_allow_grouped,0) = 0 THEN
        -- legacy: alert MULT_ALET (OK / Cancel); in APEX the user confirms with the parameter p_allow_grouped
        grouped_error(C_REC.TRNS_TYPE_CODE, C_REC.TRNS_SERIAL);
    END IF;


        FOR REC IN (SELECT    TOTAL_VALUE,TOTAL_VALUE - NVL(RESIDUAL_VALUE,0) PAYED_VALUE, BILL_ID1,BILL_ID2
                                FROM        VN_SUBTRNS
                                WHERE        TRNS_ID = C_REC.SUPP_TRNS_ID
                                  AND TRNS_SERIAL = C_REC.SUPP_TRNS_SERIAL) LOOP 

            /*IF REC.PAYED_VALUE > 0 THEN
                log_msg(C_REC.TRNS_TYPE_CODE, C_REC.TRNS_SERIAL,'تم سداد جزء من الفاتورة ' || C_REC.TRNS_TYPE_CODE || '/' || C_REC.TRNS_SERIAL || ' لا يمكن الغاء الترحيل ');
                RETURN FALSE;
            END IF;*/
            
            BEGIN
         SELECT EFFECT
           INTO TEMP_EFFECT
           FROM VN_TRNSTYPE
          WHERE ID = C_REC.SUPP_TRNS_ID;
      EXCEPTION WHEN OTHERS THEN
          log_msg(C_REC.TRNS_TYPE_CODE, C_REC.TRNS_SERIAL,'تأثير الحركة غير معرف  ' || ' لا يمكن الغاء الترحيل ');
          RETURN FALSE;
      END;
            
            BEGIN
         SELECT S.TOTAL_VALUE,
                NVL (S.TOTAL_VALUE, 0) - VN_SUBTRNS_PAYED_VALUE(S.TRNS_ID,S.TRNS_SERIAL,S.BILL_SEQ),
                S.BILL_ID1,
                S.BILL_ID2
           INTO TEMP_TOTAL_VALUE,
                TEMP_PAYED_VALUE,
                TEMP_BILL_ID1,
                TEMP_BILL_ID2
           FROM VN_SUBTRNS S, VN_MAINTRNS V
          WHERE S.TRNS_ID = C_REC.SUPP_TRNS_ID
            AND S.TRNS_SERIAL = C_REC.SUPP_TRNS_SERIAL
            AND NVL(V.LINK_FLAG,0) <> 1
            AND S.TRNS_ID = V.TRNS_ID
            AND S.TRNS_SERIAL = V.TRNS_SERIAL;
      EXCEPTION WHEN OTHERS THEN
          TEMP_PAYED_VALUE := 0;
          TEMP_TOTAL_VALUE := 0;
      END;

      IF TEMP_TOTAL_VALUE <> TEMP_PAYED_VALUE AND TEMP_EFFECT = 1 THEN
         SELECT NVL (MAX (M.DOC_NO), 0)
           INTO V_DOC_NO
           FROM VN_MAINTRNS M, VN_SUBTRNS D
          WHERE M.TRNS_ID = D.TRNS_ID
            AND M.TRNS_SERIAL = D.TRNS_SERIAL
            AND BILL_ID1 = TEMP_BILL_ID1
            AND BILL_ID2 = TEMP_BILL_ID2
            AND M.trns_id IN (SELECT ID
                                FROM VN_TRNSTYPE
                               WHERE EFFECT = 0);

         log_msg(C_REC.TRNS_TYPE_CODE, C_REC.TRNS_SERIAL,'تم سداد/مرتجع جزء من الفاتورة ' || C_REC.TRNS_TYPE_CODE || '/' || C_REC.TRNS_SERIAL || ' - سند رقم ' || V_DOC_NO || ' لا يمكن الغاء الترحيل ');
         RETURN FALSE;
      END IF;
        
            UPDATE_SUPPLIER(C_REC.SUPPLIER_CODE,-REC.TOTAL_VALUE);
    
            UPDATE VN_SUBTRNS
            SET RESIDUAL_VALUE = RESIDUAL_VALUE + REC.PAYED_VALUE
            WHERE BILL_ID1 = REC.BILL_ID1
              AND BILL_ID2 = REC.BILL_ID2
              AND trns_id IN (SELECT ID FROM AR_TRNSTYPE WHERE EFFECT = 0);
        END LOOP;

        FOR EXP_REC IN (SELECT TRNS_TYPE_CODE, TRNS_SERIAL, EXPENS_SERIAL, SUPPLIER_CODE, FREIGHT_VAL, CUSTOMS_VAL, TRNSPORT_VAL, INSURANCE_VAL, COMMISSION_VAL, OTHERS_VAL, SUPP_TRNS_ID, SUPP_TRNS_SERIAL, DOC_NO
                       FROM ST_TRNS_DET_EXPENS 
                                    WHERE TRNS_TYPE_CODE = C_REC.TRNS_TYPE_CODE AND TRNS_SERIAL = C_REC.TRNS_SERIAL) LOOP
            FOR REC IN (SELECT    TOTAL_VALUE,TOTAL_VALUE - NVL(RESIDUAL_VALUE,0) PAYED_VALUE, BILL_ID1,BILL_ID2
                                    FROM        VN_SUBTRNS
                                    WHERE        TRNS_ID = EXP_REC.SUPP_TRNS_ID
                                      AND TRNS_SERIAL = EXP_REC.SUPP_TRNS_SERIAL) LOOP 
    
                IF REC.PAYED_VALUE > 0 THEN
                    log_msg(C_REC.TRNS_TYPE_CODE, C_REC.TRNS_SERIAL,'تم سداد جزء من الفاتورة ' || C_REC.TRNS_TYPE_CODE || '/' || C_REC.TRNS_SERIAL || ' لا يمكن الغاء الترحيل ');
                    RETURN FALSE;
                END IF;
            
                UPDATE_SUPPLIER(C_REC.SUPPLIER_CODE,-REC.TOTAL_VALUE);
        
                UPDATE VN_SUBTRNS
                SET RESIDUAL_VALUE = RESIDUAL_VALUE + REC.PAYED_VALUE
                WHERE BILL_ID1 = REC.BILL_ID1
                  AND BILL_ID2 = REC.BILL_ID2
                  AND trns_id IN (SELECT ID FROM AR_TRNSTYPE WHERE EFFECT = 0);
            END LOOP;

            DELETE    VN_SUBTRNS
            WHERE        TRNS_ID = EXP_REC.SUPP_TRNS_ID AND
                    TRNS_SERIAL = EXP_REC.SUPP_TRNS_SERIAL;

            DELETE    VN_MAINTRNS
            WHERE        TRNS_ID = EXP_REC.SUPP_TRNS_ID AND
                    TRNS_SERIAL = EXP_REC.SUPP_TRNS_SERIAL;    

            UPDATE    ST_TRNS_DET_EXPENS
            SET    SUPP_TRNS_SERIAL = NULL , 
                SUPP_TRNS_ID = NULL     
            WHERE        TRNS_TYPE_CODE = C_REC.TRNS_TYPE_CODE AND
                    TRNS_SERIAL = C_REC.TRNS_SERIAL AND
                    EXPENS_SERIAL  = EXP_REC.EXPENS_SERIAL;
                                        
        END LOOP;                                        

        DELETE    VN_SUBTRNS_ITEMS
        WHERE        TRNS_ID = C_REC.SUPP_DISC_TRNS_ID AND
                TRNS_SERIAL = C_REC.SUPP_DISC_TRNS_SERIAL;

        DELETE    VN_SUBTRNS
        WHERE        TRNS_ID = C_REC.SUPP_DISC_TRNS_ID AND
                TRNS_SERIAL = C_REC.SUPP_DISC_TRNS_SERIAL;

        DELETE    VN_MAINTRNS
        WHERE        TRNS_ID = C_REC.SUPP_DISC_TRNS_ID AND
                TRNS_SERIAL = C_REC.SUPP_DISC_TRNS_SERIAL;

        DELETE    VN_SUBTRNS
        WHERE        TRNS_ID = C_REC.SUPP_TRNS_ID AND
                TRNS_SERIAL = C_REC.SUPP_TRNS_SERIAL;

        DELETE    VN_MAINTRNS
        WHERE        TRNS_ID = C_REC.SUPP_TRNS_ID AND
                TRNS_SERIAL = C_REC.SUPP_TRNS_SERIAL;
    
        UPDATE    ST_TRNS_MAST
        SET        SUPP_POST_FLAG = 0  , 
            SUPP_TRNS_SERIAL = NULL , 
            SUPP_TRNS_ID = NULL    ,
            SUPP_DISC_TRNS_ID  = NULL, 
            SUPP_DISC_TRNS_SERIAL  = NULL
        WHERE        TRNS_TYPE_CODE = C_REC.TRNS_TYPE_CODE AND
                 TRNS_SERIAL = C_REC.TRNS_SERIAL;
        -- لتعديل الحركات المجمعة
        UPDATE    ST_TRNS_MAST
        SET        SUPP_POST_FLAG = 0, 
            SUPP_TRNS_SERIAL = NULL , 
            SUPP_TRNS_ID = NULL   ,
            SUPP_DISC_TRNS_ID  = NULL, 
            SUPP_DISC_TRNS_SERIAL  = NULL  
        WHERE        SUPP_TRNS_SERIAL = C_REC.SUPP_TRNS_SERIAL 
        AND                SUPP_TRNS_ID = C_REC.SUPP_TRNS_ID;
  g_supp_posted := g_supp_posted +1;
    END LOOP;
    RETURN TRUE;
END;

  -- =============================================================================================
  -- drivers replacing the button triggers AC_BTN / AR_BTN / VN_BTN of ST_POSTING_CPOSTING
  -- =============================================================================================
  -- button trigger validations (alert DATA_ERROR 'خطأ فى إدخال البيانات....!')
  procedure check_filter (f in out nocopy t_filter, p_supplier_code in number) is
    procedure data_error is
    begin
      raise_application_error(-20103, case when g_lang = 'E' then 'Error in entered data' else 'خطأ فى إدخال البيانات....!' end);
    end;
  begin
    -- WHEN-VALIDATE-ITEM of FROM_TRNS_SERIAL copies the value into TO_TRNS_SERIAL; same for a single customer / salesman
    if f.from_serial is not null and f.to_serial is null then f.to_serial := f.from_serial; end if;
    if f.to_serial is not null and f.from_serial is null then f.from_serial := f.to_serial; end if;
    if f.c1 is not null and f.c2 is null then f.c2 := f.c1; end if;
    if f.c2 is not null and f.c1 is null then f.c1 := f.c2; end if;
    if f.s1 is not null and f.s2 is null then f.s2 := f.s1; end if;
    if f.s2 is not null and f.s1 is null then f.s1 := f.s2; end if;
    if f.from_date is null or f.to_date is null or f.from_date > f.to_date then data_error; end if;
    if f.from_type is null or f.to_type is null or f.from_type > f.to_type then data_error; end if;
    if nvl(f.from_serial, 0) > nvl(f.to_serial, 0) then data_error; end if;
    if p_supplier_code is not null and f.to_type <> f.from_type then data_error; end if;
  end check_filter;

  -- make the block record current: lock the row (no double posting by two sessions) and read its flags (GET_POST_FLAG)
  function set_current (p_type in number, p_serial in number) return boolean is
  begin
    select trns_type_code, trns_serial, trns_date, nvl(post_flag, 0), nvl(cust_post_flag, 0), nvl(supp_post_flag, 0),
           get_join_type(trns_type_code)
      into g_cur.trns_type_code, g_cur.trns_serial, g_cur.trns_date, g_cur.post_flag, g_cur.cust_post_flag,
           g_cur.supp_post_flag, g_cur.join_type
      from st_trns_mast
     where trns_type_code = p_type and trns_serial = p_serial and nvl(delete_flag, 0) = 0
       for update;
    return true;
  exception when no_data_found then
    return false;
  end set_current;

  procedure run (p_filter in number, f in t_filter, p_gl in number, p_ar in number, p_ap in number) is
    type t_keys is table of c_block%rowtype;
    l_keys t_keys;
  begin
    delete from st_ledger;                           -- AC_BTN / AR_BTN / VN_BTN: DELETE FROM ST_LEDGER
    delete from st_post_msg;                         -- messages of this run only (see ST_POSTING.md)
    open c_block(f, p_filter);
    fetch c_block bulk collect into l_keys;          -- the block is queried once, then processed record by record
    close c_block;

    if p_filter = 1 then
      if nvl(p_gl, 0) = 1 then                       -- AC_BTN
        for i in 1 .. l_keys.count loop
          if set_current(l_keys(i).trns_type_code, l_keys(i).trns_serial) and g_cur.post_flag = 0 then
            set_post_entries;
            delete from st_ledger;                   -- work rows of a transaction that failed are not carried over
          end if;
        end loop;
      end if;
      if nvl(p_ar, 0) = 1 then                       -- AR_BTN
        for i in 1 .. l_keys.count loop
          if set_current(l_keys(i).trns_type_code, l_keys(i).trns_serial) and g_cur.cust_post_flag = 0 then
            set_post_customer;
          end if;
        end loop;
      end if;
      if nvl(p_ap, 0) = 1 then                       -- VN_BTN
        for i in 1 .. l_keys.count loop
          if set_current(l_keys(i).trns_type_code, l_keys(i).trns_serial) and g_cur.supp_post_flag = 0 then
            set_post_supplier;
          end if;
        end loop;
      end if;
    else
      if nvl(p_gl, 0) = 1 then                       -- AC_BTN with FILTER = 2
        for i in 1 .. l_keys.count loop
          if set_current(l_keys(i).trns_type_code, l_keys(i).trns_serial) and g_cur.post_flag = 1 then
            if make_reverse_acc then null; end if;
          end if;
        end loop;
      end if;
      if nvl(p_ar, 0) = 1 then                       -- AR_BTN with FILTER = 2
        for i in 1 .. l_keys.count loop
          if set_current(l_keys(i).trns_type_code, l_keys(i).trns_serial) and g_cur.cust_post_flag = 1 then
            if make_reverse_customer then null; end if;
          end if;
        end loop;
      end if;
      if nvl(p_ap, 0) = 1 then                       -- VN_BTN with FILTER = 2
        for i in 1 .. l_keys.count loop
          if set_current(l_keys(i).trns_type_code, l_keys(i).trns_serial) and g_cur.supp_post_flag = 1 then
            if make_reverse_supp then null; end if;
          end if;
        end loop;
      end if;
    end if;
    delete from st_ledger;
  end run;

  procedure post_cancel (
    p_mode in number, p_from_date in date, p_to_date in date, p_from_type in number, p_to_type in number,
    p_from_serial in number default null, p_to_serial in number default null,
    p_from_customer in number default null, p_to_customer in number default null,
    p_from_salesman in number default null, p_to_salesman in number default null,
    p_gl in number default 1, p_ar in number default 1, p_ap in number default 1, p_allow_grouped in number default 0,
    p_company_code in number default null, p_user_code in number default null, p_password_number in number default null)
  is
    f t_filter;
  begin
    init_ctx(p_company_code, p_user_code, p_password_number);
    if nvl(p_mode, 0) not in (1, 2) then
      raise_application_error(-20103, case when g_lang = 'E' then 'Choose posting or cancel posting' else 'اختر ترحيل أو إلغاء الترحيل' end);
    end if;
    if nvl(p_gl, 0) + nvl(p_ar, 0) + nvl(p_ap, 0) = 0 then
      raise_application_error(-20104, case when g_lang = 'E' then 'Choose at least one system (GL, AR, AP)' else 'اختر نظاماً واحداً على الأقل (الحسابات - العملاء - الموردين)' end);
    end if;
    f.from_date := trunc(p_from_date); f.to_date := trunc(p_to_date);
    f.from_type := p_from_type; f.to_type := p_to_type;
    f.from_serial := p_from_serial; f.to_serial := p_to_serial;
    f.c1 := p_from_customer; f.c2 := p_to_customer; f.s1 := p_from_salesman; f.s2 := p_to_salesman;
    check_filter(f, g_supplier_code);
    g_allow_grouped := nvl(p_allow_grouped, 0);
    run(p_mode, f, p_gl, p_ar, p_ap);
  end post_cancel;

  procedure post_trns (
    p_from_date in date, p_to_date in date, p_from_type in number, p_to_type in number,
    p_from_serial in number default null, p_to_serial in number default null,
    p_from_customer in number default null, p_to_customer in number default null,
    p_from_salesman in number default null, p_to_salesman in number default null,
    p_supplier_code in number default null,
    p_post_gl in number default 1, p_post_ar in number default 1, p_post_ap in number default 1,
    p_company_code in number default null, p_user_code in number default null, p_password_number in number default null)
  is
    f t_filter;
  begin
    init_ctx(p_company_code, p_user_code, p_password_number);
    if nvl(p_post_gl, 0) + nvl(p_post_ar, 0) + nvl(p_post_ap, 0) = 0 then
      raise_application_error(-20104, case when g_lang = 'E' then 'Choose at least one system (GL, AR, AP)' else 'اختر نظاماً واحداً على الأقل (الحسابات - العملاء - الموردين)' end);
    end if;
    f.from_date := trunc(p_from_date); f.to_date := trunc(p_to_date);
    f.from_type := p_from_type; f.to_type := p_to_type;
    f.from_serial := p_from_serial; f.to_serial := p_to_serial;
    f.c1 := p_from_customer; f.c2 := p_to_customer; f.s1 := p_from_salesman; f.s2 := p_to_salesman;
    g_supplier_code := p_supplier_code;
    check_filter(f, g_supplier_code);
    run(1, f, p_post_gl, p_post_ar, p_post_ap);
  end post_trns;

  procedure cancel_trns (
    p_from_date in date, p_to_date in date, p_from_type in number, p_to_type in number,
    p_from_serial in number default null, p_to_serial in number default null,
    p_from_customer in number default null, p_to_customer in number default null,
    p_from_salesman in number default null, p_to_salesman in number default null,
    p_cancel_gl in number default 1, p_cancel_ar in number default 1, p_cancel_ap in number default 1,
    p_allow_grouped in number default 0,
    p_company_code in number default null, p_user_code in number default null, p_password_number in number default null)
  is
  begin
    post_cancel(2, p_from_date, p_to_date, p_from_type, p_to_type, p_from_serial, p_to_serial,
                p_from_customer, p_to_customer, p_from_salesman, p_to_salesman,
                p_cancel_gl, p_cancel_ar, p_cancel_ap, p_allow_grouped,
                p_company_code, p_user_code, p_password_number);
  end cancel_trns;

  -- =============================================================================================
  -- ST_AUTO_ADJ  (ST\FMB\ST_AUTO_ADJ.fmb : MAST_BLK.WHEN-NEW-ITEM-INSTANCE + program unit MAKE_ADJUST)
  -- =============================================================================================
  function build_adj_lines (p_store_code in number, p_taking_date in date) return t_adj_lines is
    l_lines    t_adj_lines := t_adj_lines();
    l          t_adj_line;
    l_bal      number;
    l_cost     number;
    l_avg      number;
    l_tak_cost number;
    l_tak_qty  number;
  begin
    for c in (select distinct group_code grp, item_code itm, item_confg_id cfg
                from st_trns_det
               where store_code = p_store_code
              union
              select distinct group_code, item_code, item_confg_id
                from st_stock_taking_det
               where store_code = p_store_code and st_taking_date = p_taking_date
              order by 1, 2)
    loop
      get_balance_cost_confg(l_bal, l_cost, l_avg, p_store_code, c.grp, c.itm, c.cfg, p_taking_date, null, null);
      select avg(t.unit_cost), sum(t.basic_qty)
        into l_tak_cost, l_tak_qty
        from st_stock_taking_det t
       where t.store_code = p_store_code and t.st_taking_date = p_taking_date
         and t.group_code = c.grp and t.item_code = c.itm and t.item_confg_id = c.cfg;
      if nvl(l_bal, 0) != nvl(l_tak_qty, 0) then
        l := null;
        l.group_code := c.grp; l.item_code := c.itm; l.item_confg_id := c.cfg;
        begin
          select case when g_lang = 'E' then nvl(itm.name_e, itm.name_a) else itm.name_a end
            into l.item_name
            from st_item itm where itm.item_group_code = c.grp and itm.item_code = c.itm;
        exception when no_data_found then null;
        end;
        l.book_basic_qty   := nvl(l_bal, 0);
        l.unit_cost        := nvl(l_tak_cost, l_avg);
        l.taking_basic_qty := nvl(l_tak_qty, 0);
        begin
          select iu.unit_code, case when g_lang = 'E' then nvl(u.name_e, u.name_a) else u.name_a end, iu.factor
            into l.unit_code, l.unit_name, l.factor
            from st_item_unit iu, st_unit u
           where nvl(iu.basic_unit, 0) = 1 and iu.group_code = c.grp and iu.item_code = c.itm
             and iu.unit_code = u.unit_code;
        exception when no_data_found then
          app_msg('خطأ بوحدة الصنف ' || c.grp || '/' || c.itm, 'Error in item unit ' || c.grp || '/' || c.itm, 1);
        end;
        l.taking_qty := nvl(l.taking_basic_qty, 0) / nvl(l.factor, 1);
        l.book_qty   := nvl(l.book_basic_qty, 0) / nvl(l.factor, 1);
        if c.cfg is not null then
          begin
            select expire_date, lot_number into l.expire_date, l.lot_number
              from st_item_confg where item_code = c.itm and group_code = c.grp and item_confg_id = c.cfg;
          exception when no_data_found then null;
          end;
        end if;
        select count(1) into l.adj_error
          from st_auto_adj_err e
         where e.store_code = p_store_code and e.group_code = c.grp and e.item_code = c.itm and rownum = 1;
        l_lines.extend; l_lines(l_lines.count) := l;
      end if;
    end loop;
    return l_lines;
  end build_adj_lines;

  function auto_adj_lines (p_store_code in number, p_taking_date in date) return t_adj_lines pipelined is
    l_lines t_adj_lines;
  begin
    if p_store_code is null or p_taking_date is null then
      return;
    end if;
    g_lang := case when lower(nvl(v('G_LANG'), 'ar')) like 'en%' then 'E' else 'A' end;
    l_lines := build_adj_lines(p_store_code, trunc(p_taking_date));
    for i in 1 .. l_lines.count loop
      pipe row (l_lines(i));
    end loop;
    return;
  end auto_adj_lines;

  procedure auto_adjust (
    p_taking_date in date, p_store_code in number, p_issue_type in number, p_rec_type in number,
    p_group_code in number default null, p_item_code in varchar2 default null,
    p_company_code in number default null, p_user_code in number default null, p_password_number in number default null)
  is
    l_date          date := trunc(p_taking_date);
    l_lines         t_adj_lines;
    l_n             number;
    l_issue_serial  number;
    l_issue_dser    number;
    l_issue_item    number;
    l_rec_serial    number;
    l_rec_dser      number;
    l_rec_item      number;
    l_invoice_no    varchar2(25);
    l_rec_doc_no    number;
    l_mast_issue    number := 0;
    l_mast_rec      number := 0;
    l_err_flag      number := 0;
    l_dummy         number;

    function chosen (i pls_integer) return boolean is      -- DET_BLK.AUTO = 1 (all lines, or the requested group / item)
    begin
      return (p_group_code is null or l_lines(i).group_code = p_group_code)
         and (p_item_code is null or l_lines(i).item_code = p_item_code);
    end;

    procedure new_rec_master is
    begin
      select nvl(max(nvl(trns_serial, 0)), 0) + 1 into l_rec_serial from st_trns_mast where trns_type_code = p_rec_type;
      select nvl(max(nvl(date_serial, 0)), 0) + 1 into l_rec_dser from st_trns_mast where trns_date = l_date;
      l_rec_doc_no := to_number(to_char(p_issue_type) || to_char(l_issue_serial));
      insert into st_trns_mast (trns_type_code, trns_serial, trns_date, date_serial, doc_no, desc_a, desc_e,
                                currency_code, currency_rate, store_code, post_flag, delete_flag, taking_flag)
      values (p_rec_type, l_rec_serial, l_date, l_rec_dser, l_rec_doc_no,
              'تسوية الية للجرد بتاريخ ' || to_char(l_date, 'DD-MM-YYYY'),
              'Automatic adjustment for stocktaking in date ' || to_char(l_date, 'DD-MM-YYYY'),
              1, 1, p_store_code, 0, 0, 1);
      l_rec_item := 1;
    end new_rec_master;
  begin
    init_ctx(p_company_code, p_user_code, p_password_number);
    if l_date is null or p_store_code is null then
      raise_application_error(-20151, case when g_lang = 'E' then 'Enter the stocktaking date and the store' else 'يجب ادخال تاريخ الجرد ورقم المخزن' end);
    end if;
    -- MAST_BLK DEFAULT_WHERE / ST_STORE_LOV: stores of the user's group
    if g_password <> 0 then
      select count(1) into l_n from st_all_store_password where store_code = p_store_code and password_number = g_password;
      if l_n = 0 then
        raise_application_error(-20152, case when g_lang = 'E' then 'You have no permission on this store' else 'ليس لديك صلاحية على هذا المخزن' end);
      end if;
    end if;
    -- ST_TAKING_DATE / STORE_CODE WHEN-VALIDATE-ITEM: the stocktaking must exist
    select count(1) into l_n from st_stock_taking where st_taking_date = l_date and store_code = p_store_code;
    if l_n = 0 then
      raise_application_error(-20153, case when g_lang = 'E' then 'No stocktaking for this store on this date' else 'لا يوجد جرد لهذا المخزن فى هذا التاريخ' end);
    end if;
    if p_issue_type is null or p_rec_type is null then
      raise_application_error(-20154, case when g_lang = 'E' then 'Missing codes for issue and receive automatic adjustment'
                                           else 'يجب ادخال كود وارد وصادر التسوية الالية' end);
    end if;
    -- LOVs TRNS_TYPE_ISSUE / TRNS_TYPE_REC
    select count(1) into l_n from st_trns_type
     where trns_type_code = p_issue_type and effect = 2 and trns_type = 7
       and (store_code = p_store_code or store_code is null)
       and (g_password = 0 or trns_type_code in (select tp.trns_type_code from st_trnstype_password tp where tp.password_number = g_password));
    if l_n = 0 then
      raise_application_error(-20155, case when g_lang = 'E' then 'Invalid issue adjustment transaction' else 'حركة الصادر للتسوية الآلية غير صحيحة' end);
    end if;
    select count(1) into l_n from st_trns_type
     where trns_type_code = p_rec_type and effect = 1 and trns_type = 7
       and (store_code = p_store_code or store_code is null)
       and (g_password = 0 or trns_type_code in (select tp.trns_type_code from st_trnstype_password tp where tp.password_number = g_password));
    if l_n = 0 then
      raise_application_error(-20156, case when g_lang = 'E' then 'Invalid receive adjustment transaction' else 'حركة الوارد للتسوية الآلية غير صحيحة' end);
    end if;

    delete from st_auto_adj_err;                    -- legacy FORMS_DDL('TRUNCATE TABLE ST_AUTO_ADJ_ERR')
    l_lines := build_adj_lines(p_store_code, l_date);

    -- pass 1: take the book balance out (issue) or bring a negative balance back to zero (receive)
    for i in 1 .. l_lines.count loop
      if chosen(i) then
        if nvl(l_lines(i).book_basic_qty, 0) > 0 then
          select count(d.item_serial) into l_dummy
            from st_trns_det d, st_trns_mast m
           where d.group_code = l_lines(i).group_code and d.item_code = l_lines(i).item_code
             and m.store_code = p_store_code and nvl(m.delete_flag, 0) = 0
             and (   (m.trns_date > l_date)
                  or (m.trns_date = l_date and m.date_serial > l_issue_dser)
                  or (m.trns_date = l_date and m.date_serial = l_issue_dser and d.item_serial > l_issue_item))
             and m.trns_type_code = d.trns_type_code and m.trns_serial = d.trns_serial;
          if l_dummy > 0 and nvl(l_lines(i).taking_basic_qty, 0) < nvl(l_lines(i).book_basic_qty, 0) then
            -- the reduced balance must not make a later issue negative
            l_dummy := update_next_trns(p_store_code, l_lines(i).group_code, l_lines(i).item_code, l_date,
                                        l_issue_dser, l_issue_item, nvl(l_lines(i).taking_basic_qty, 0));
            if l_dummy != 0 then
              l_err_flag := 1;
              begin
                insert into st_auto_adj_err values (p_store_code, l_date, l_lines(i).group_code, l_lines(i).item_code,
                                                    l_lines(i).unit_code, nvl(l_lines(i).taking_qty, 0),
                                                    nvl(l_lines(i).taking_basic_qty, 0), l_lines(i).item_confg_id);
              exception when others then null;
              end;
              goto skip_insert;
            end if;
          end if;
          if l_mast_issue = 0 then
            l_mast_issue := 1;
            select nvl(max(nvl(trns_serial, 0)), 0) + 1 into l_issue_serial from st_trns_mast where trns_type_code = p_issue_type;
            select nvl(max(nvl(date_serial, 0)), 0) + 1 into l_issue_dser from st_trns_mast where trns_date = l_date;
            l_invoice_no := to_char(p_issue_type) || lpad(to_char(l_issue_serial), 7, '0');
            insert into st_trns_mast (trns_serial, trns_date, date_serial, desc_a, desc_e, currency_rate, post_flag, delete_flag,
                                      trns_type_code, currency_code, store_code, invoice_no, taking_flag)
            values (l_issue_serial, l_date, l_issue_dser,
                    'تسوية الية للجرد بتاريخ  ' || to_char(l_date, 'DD-MM-YYYY'),
                    'Automatic adjustment for stocktaking in date ' || to_char(l_date, 'DD-MM-YYYY'),
                    1, 0, 0, p_issue_type, 1, p_store_code, l_invoice_no, 1);
            l_issue_item := 1;
          end if;
          insert into st_trns_det (item_serial, quantity, unit_cost, unit_price, basic_qty, cost_flag, trns_type_code,
                                   trns_serial, unit_code, group_code, item_code, item_confg_id, store_code)
          values (l_issue_item, nvl(l_lines(i).book_qty, 0), l_lines(i).unit_cost, l_lines(i).unit_cost,
                  nvl(l_lines(i).book_basic_qty, 0), 1, p_issue_type, l_issue_serial, l_lines(i).unit_code,
                  l_lines(i).group_code, l_lines(i).item_code, l_lines(i).item_confg_id, p_store_code);
          l_issue_item := l_issue_item + 1;
        elsif nvl(l_lines(i).book_basic_qty, 0) < 0 then
          if l_mast_rec = 0 then
            l_mast_rec := 1;
            new_rec_master;
          end if;
          insert into st_trns_det (trns_type_code, trns_serial, item_serial, group_code, item_code, unit_code, quantity,
                                   unit_price, basic_qty, unit_cost, cost_flag, item_confg_id, store_code)
          values (p_rec_type, l_rec_serial, l_rec_item, l_lines(i).group_code, l_lines(i).item_code, l_lines(i).unit_code,
                  abs(l_lines(i).book_basic_qty), abs(l_lines(i).unit_cost * l_lines(i).factor),
                  abs(nvl(l_lines(i).book_basic_qty, 0)), abs(l_lines(i).unit_cost), 1, l_lines(i).item_confg_id, p_store_code);
          l_rec_item := l_rec_item + 1;
        end if;
      end if;
      <<skip_insert>>
      null;
    end loop;

    -- pass 2: receive the counted quantity (a second receipt voucher: the legacy resets MAST_REC_FLAG here)
    l_mast_issue := 0;
    l_mast_rec   := 0;
    for i in 1 .. l_lines.count loop
      if chosen(i) and nvl(l_lines(i).taking_basic_qty, 0) != 0 then
        select count(1) into l_dummy
          from st_auto_adj_err
         where group_code = l_lines(i).group_code and item_code = l_lines(i).item_code and store_code = p_store_code;
        if l_dummy = 0 then
          if l_mast_rec = 0 then
            l_mast_rec := 1;
            new_rec_master;
          end if;
          insert into st_trns_det (trns_type_code, trns_serial, item_serial, group_code, item_code, unit_code, quantity,
                                   unit_price, basic_qty, unit_cost, cost_flag, item_confg_id, store_code)
          values (p_rec_type, l_rec_serial, l_rec_item, l_lines(i).group_code, l_lines(i).item_code, l_lines(i).unit_code,
                  nvl(l_lines(i).taking_qty, 0), l_lines(i).unit_cost * l_lines(i).factor,
                  nvl(l_lines(i).taking_basic_qty, 0), l_lines(i).unit_cost, 1, l_lines(i).item_confg_id, p_store_code);
          l_rec_item := l_rec_item + 1;
        end if;
      end if;
    end loop;
    g_acct_posted := l_err_flag;        -- 1 = some lines were refused (alert UPDATE_ERROR), see ST_AUTO_ADJ_ERR
  end auto_adjust;

  -- =============================================================================================
  -- ST_DIST_COST_N  (compiled form only: the two cursors and two UPDATEs of the .fmx, run day by day)
  -- =============================================================================================
  procedure dist_transfer_cost (
    p_from_date in date, p_to_date in date,
    p_company_code in number default null, p_user_code in number default null, p_password_number in number default null)
  is
    l_day date;
  begin
    init_ctx(p_company_code, p_user_code, p_password_number);
    if p_from_date is null or p_to_date is null then
      raise_application_error(-20161, case when g_lang = 'E' then 'Enter the from date and the to date' else 'يجب ادخال من تاريخ والى تاريخ' end);
    end if;
    if trunc(p_to_date) < trunc(p_from_date) then
      raise_application_error(-20162, case when g_lang = 'E' then 'The from date must be before the to date' else 'من تاريخ يجب أن يكون أقل من إلى تاريخ' end);
    end if;
    l_day := trunc(p_from_date);
    while l_day <= trunc(p_to_date) loop
      -- "حركات تحويل يوم": cost of the transfer-out lines of the day
      for r in (select mt.trns_serial, mt.trns_type_code, mt.trnsfer_serial, mt.trnsfer_to_store, det.group_code, det.item_code,
                       det.unit_price, mt.store_code, det.item_confg_id,
                       get_unit_cost_confg(mt.store_code, det.group_code, det.item_code, det.item_confg_id, mt.trns_date,
                                           mt.date_serial, det.item_serial) item_cost,
                       det.item_serial
                  from st_trns_mast mt, st_trns_det det
                 where mt.trns_type_code = det.trns_type_code and mt.trns_serial = det.trns_serial
                   and mt.trnsfer_serial is not null and mt.trnsfer_from_store is not null
                   and mt.trns_type_code in (select trns_type_code from st_trns_type where effect = 5)
                   and mt.trns_date = l_day)
      loop
        update st_trns_det set unit_cost = r.item_cost
         where trns_type_code = r.trns_type_code and trns_serial = r.trns_serial and item_serial = r.item_serial
           and round(nvl(unit_cost, 0), 4) != round(nvl(r.item_cost, 0), 4);
        g_acct_posted := g_acct_posted + sql%rowcount;
      end loop;
      -- "حركات أستلام يوم": the matching transfer-in lines receive the same cost (unit price = cost x unit factor)
      for r in (select mt.trnsfer_serial, mt.trnsfer_to_store, det.group_code, det.item_code, det.unit_cost, mt.store_code,
                       det.item_serial, det.item_confg_id, det.basic_qty, det.trns_type_code, det.trns_serial
                  from st_trns_mast mt, st_trns_det det
                 where mt.trns_type_code = det.trns_type_code and mt.trns_serial = det.trns_serial
                   and mt.trnsfer_serial is not null and mt.trnsfer_from_store is not null
                   and mt.trns_type_code in (select trns_type_code from st_trns_type where effect = 5)
                   and mt.trns_date = l_day)
      loop
        update st_trns_det
           set unit_price = (select factor * r.unit_cost from st_item_unit
                              where group_code = st_trns_det.group_code and item_code = st_trns_det.item_code
                                and unit_code = st_trns_det.unit_code),
               unit_cost = r.unit_cost
         where (trns_type_code, trns_serial) in (select trns_type_code, trns_serial from st_trns_mast
                                                  where trnsfer_serial = r.trnsfer_serial and store_code = r.trnsfer_to_store
                                                    and trnsfer_from_store = r.store_code
                                                    and trns_type_code in (select trns_type_code from st_trns_type where effect = 6))
           and group_code = r.group_code and item_code = r.item_code and basic_qty = r.basic_qty
           and item_confg_id = r.item_confg_id and item_serial = r.item_serial
           and round(nvl(unit_cost, 0), 4) != round(nvl(r.unit_cost, 0), 4);
        g_cust_posted := g_cust_posted + sql%rowcount;
      end loop;
      l_day := l_day + 1;
    end loop;
  end dist_transfer_cost;

end app_proc_st;
/
show errors package body app_proc_st
