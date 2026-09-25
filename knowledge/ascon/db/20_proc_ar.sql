-- =====================================================================================================
-- APP_PROC_AR : receivables (AR) process screens of the ASCON ERP, reconstructed for APEX (Stage C).
--   ARACUPDT                   post customer transactions to the GL                -> post_to_gl
--   AR_CPOSTING                cancel the GL posting of customer transactions      -> cancel_gl_posting
--   AR_INVOICE_ADJESTMENT_MAN  manual allocation of a customer payment to invoices -> manual_adjust
-- Evidence and rules: app\legacy\processes\ARACUPDT.md, AR_CPOSTING.md, AR_INVOICE_ADJESTMENT_MAN.md.
-- No COMMIT inside: the APEX page process commits (legacy: one COMMIT_FORM per button press).
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_proc_ar authid definer as

  -- AR_CPOSTING (system 4 serial 8): delete the GL vouchers created by the AR posting (ARACUPDT) for the
  -- selected customer transactions and reset AR_MAINTRNS / AR_SUBTRNS.POST_FLAG.
  -- p_allow_grouped = 1 answers "yes" to the legacy question about vouchers shared by several transactions.
  procedure cancel_gl_posting (
    p_from_date       in date,
    p_to_date         in date,
    p_from_trns_id    in number default null,
    p_to_trns_id      in number default null,
    p_from_mainarea   in number default null,
    p_to_mainarea     in number default null,
    p_from_subarea    in number default null,
    p_to_subarea      in number default null,
    p_from_serial     in number default null,
    p_to_serial       in number default null,
    p_allow_grouped   in number default 0,
    p_company_code    in number default null,
    p_user_code       in number default null,
    p_password_number in number default null);

  -- ARACUPDT (system 4 serial 6): post the selected unposted customer transactions (receipts, adjustments)
  -- to the GL, one voucher per transaction, through AR_GET_TRNS_DATA (DB) and AR_CREATE_ENTRY_EVERY_ONE (DB
  -- procedure copied into this package) - port of the form program unit AR_SET_EVERY_ENTRY_AC of AR\FMB\aracupdt.fmb.
  -- All or nothing: when a transaction of the selection cannot be posted, nothing is posted and the reasons
  -- are returned in the error message (and in AR_POST_MSG of the user until the rollback).
  procedure post_to_gl (
    p_from_date       in date,
    p_to_date         in date,
    p_from_trns_id    in number default null,
    p_to_trns_id      in number default null,
    p_from_mainarea   in number default null,
    p_to_mainarea     in number default null,
    p_from_subarea    in number default null,
    p_to_subarea      in number default null,
    p_from_serial     in number default null,
    p_to_serial       in number default null,
    p_company_code    in number default null,
    p_user_code       in number default null,
    p_password_number in number default null);

  -- AR_INVOICE_ADJESTMENT_MAN (system 4 serial 42): manual allocation of a payment / credit transaction
  -- (AR_TRNSTYPE.EFFECT = 1) to an open invoice bill (EFFECT = 0) of the same customer.
  --   p_action 1 = allocate p_amount of payment p_payment to invoice bill p_invoice
  --   p_action 2 = remove all allocations of payment p_payment (needs USERS.DELETE_AR_ADJESTMENT = 1)
  --   p_payment  = 'TRNS_ID:MAINAREA_ID:SUBAREA_ID:TRNS_SERIAL'
  --   p_invoice  = 'TRNS_ID:MAINAREA_ID:SUBAREA_ID:TRNS_SERIAL:BILL_SEQ'   (AR_SUBTRNS row of the invoice)
  --   p_disc     = discount of the allocation; null = the form's CALCULATE_DISCOUNT (early-payment periods)
  procedure manual_adjust (
    p_action          in number,
    p_payment         in varchar2,
    p_invoice         in varchar2 default null,
    p_amount          in number   default null,
    p_company_code    in number   default null,
    p_user_code       in number   default null,
    p_password_number in number   default null,
    p_disc            in number   default null);

  function last_count return number;

end app_proc_ar;
/

create or replace package body app_proc_ar as

  g_lang     varchar2(1) := 'A';
  g_company  number;
  g_user     number;
  g_password number;
  g_count    number := 0;

  function last_count return number is begin return g_count; end;

  procedure init_ctx (p_company_code in number, p_user_code in number, p_password_number in number) is
  begin
    g_company  := nvl(p_company_code, to_number(v('G_COMPANY_CODE')));
    g_user     := nvl(p_user_code, to_number(v('G_USER_CODE')));
    g_password := nvl(p_password_number, nvl(to_number(v('G_PASSWORD_NUMBER')), -1));
    g_lang     := case when lower(nvl(v('G_LANG'), 'ar')) like 'en%' then 'E' else 'A' end;
    if g_company is null then
      select min(company_code) into g_company from ac_basic;
    end if;
    g_count := 0;
  end init_ctx;

  procedure err (p_code in pls_integer, p_a in varchar2, p_e in varchar2) is
  begin
    raise_application_error(p_code, case when g_lang = 'E' then p_e else p_a end);
  end err;

  -- =============================================================================================
  -- AR_CPOSTING
  -- =============================================================================================
  procedure cancel_gl_posting (
    p_from_date in date, p_to_date in date,
    p_from_trns_id in number default null, p_to_trns_id in number default null,
    p_from_mainarea in number default null, p_to_mainarea in number default null,
    p_from_subarea in number default null, p_to_subarea in number default null,
    p_from_serial in number default null, p_to_serial in number default null,
    p_allow_grouped in number default 0,
    p_company_code in number default null, p_user_code in number default null, p_password_number in number default null)
  is
    l_from       date := trunc(p_from_date);
    l_to         date := trunc(p_to_date);
    l_have_rap   number;          -- SYS_SYSTEMS 15 (cash boxes)
    l_have_check number;          -- SYS_SYSTEMS 13 (banks / cheques)
    l_close      date;
    l_cnt        number;
    l_post       number;
    c_system     constant number := 4;   -- :GLOBAL.SYSTEM_NUMBER of the AR system
    cursor c_trns is
      select m.acc_year, m.acc_type, m.acc_no, m.trns_id, m.mainarea_id, m.subarea_id, m.trns_serial,
             m.trns_date, m.acc_post_date
        from ar_maintrns m
       where ((m.acc_post_date is not null and m.acc_post_date between l_from and l_to)
              or (m.acc_post_date is null and m.trns_date between l_from and l_to))
         and (p_from_trns_id  is null or m.trns_id     >= p_from_trns_id)
         and (p_to_trns_id    is null or m.trns_id     <= p_to_trns_id)
         and (p_from_mainarea is null or m.mainarea_id >= p_from_mainarea)
         and (p_to_mainarea   is null or m.mainarea_id <= p_to_mainarea)
         and (p_from_subarea  is null or m.subarea_id  >= p_from_subarea)
         and (p_to_subarea    is null or m.subarea_id  <= p_to_subarea)
         and (p_from_serial   is null or m.trns_serial >= p_from_serial)
         and (p_to_serial     is null or m.trns_serial <= p_to_serial)
         and m.trns_serial_tot is null
         and (   nvl(m.cash_flag, 0) not in (0, 1)
              or (c_system = 15 and nvl(m.cash_flag, 0) in (0, 1))
              or (nvl(m.cash_flag, 0) in (1) and l_have_rap = 0)
              or (nvl(m.cash_flag, 0) in (0) and l_have_check = 0))
         and nvl(m.post_flag, 0) = 1
         and nvl(m.link_flag, 0) = 0
         and m.acc_year is not null and m.acc_type is not null and m.acc_no is not null
         and (g_password = 0
              or m.trns_id in (select tp.trns_id from ar_trnstype_password tp
                                where tp.flag = 1 and tp.password_number = g_password))
       order by m.trns_id, m.trns_serial;
    type t_rows is table of c_trns%rowtype;
    l_rows t_rows;
  begin
    init_ctx(p_company_code, p_user_code, p_password_number);
    if l_from is null or l_to is null or l_to < l_from then
      err(-20111, 'التاريخ الاول يجب ان يكون اقل من التاريخ الثانى', 'The from date should be less than the to date');
    end if;
    if p_from_serial is not null and p_to_serial is not null and p_to_serial < p_from_serial then
      err(-20112, 'خطأ فى إدخال البيانات....!', 'Error in entered data');
    end if;
    select count(1) into l_have_rap   from sys_systems where system_number = 15;
    select count(1) into l_have_check from sys_systems where system_number = 13;
    begin
      select close_date into l_close from ac_basic where company_code = g_company;
    exception when no_data_found then l_close := null;
    end;

    open c_trns; fetch c_trns bulk collect into l_rows; close c_trns;
    if l_rows.count = 0 then
      err(-20113, 'لا توجد قيود يمكن الغاء ترحيلها', 'No posted entries to cancel');
    end if;

    for i in 1 .. l_rows.count loop
      if nvl(l_rows(i).acc_post_date, l_rows(i).trns_date) <= l_close then
        err(-20114, 'لا يمكن إلغاء ترحيل الحركة رقم ' || l_rows(i).trns_id || '/' || l_rows(i).trns_serial || ' لأنها تقع فى فترة مقفلة',
            'Cannot cancel the posting of transaction ' || l_rows(i).trns_id || '/' || l_rows(i).trns_serial || ' because it lies in a closed period');
      end if;
      -- lock the transaction; it may already have been reset as part of a voucher shared with an earlier row
      select nvl(post_flag, 0) into l_post
        from ar_maintrns
       where trns_id = l_rows(i).trns_id and mainarea_id = l_rows(i).mainarea_id
         and subarea_id = l_rows(i).subarea_id and trns_serial = l_rows(i).trns_serial
         for update;
      if l_post = 1 then
        select count(1) into l_cnt
          from ar_maintrns
         where acc_year = l_rows(i).acc_year and acc_type = l_rows(i).acc_type and acc_no = l_rows(i).acc_no
           and post_flag = 1;
        if l_cnt > 1 and nvl(p_allow_grouped, 0) = 0 then
          -- legacy: alert "سوف يتم إلغاء قيد لحركة مجمعة ...هل تريد الإستمرار" (OK / Cancel)
          err(-20115, 'سوف يتم إلغاء قيد لحركة مجمعة (' || l_rows(i).trns_id || '/' || l_rows(i).trns_serial
                      || ') ...اختر "إلغاء القيود المجمعة" للاستمرار',
              'The voucher of transaction ' || l_rows(i).trns_id || '/' || l_rows(i).trns_serial
                      || ' is shared by several transactions; tick "cancel collected vouchers" to continue');
        end if;
        delete from ac_yearly_trn_det
         where entry_year = l_rows(i).acc_year and entry_type = l_rows(i).acc_type and entry_no = l_rows(i).acc_no;
        delete from ac_yearly_trn
         where entry_year = l_rows(i).acc_year and entry_type = l_rows(i).acc_type and entry_no = l_rows(i).acc_no;
        for t in (select trns_id, mainarea_id, subarea_id, trns_serial
                    from ar_maintrns
                   where acc_year = l_rows(i).acc_year and acc_type = l_rows(i).acc_type and acc_no = l_rows(i).acc_no)
        loop
          update ar_maintrns set post_flag = 0
           where trns_id = t.trns_id and mainarea_id = t.mainarea_id and subarea_id = t.subarea_id and trns_serial = t.trns_serial;
          update ar_subtrns set post_flag = 0
           where trns_id = t.trns_id and mainarea_id = t.mainarea_id and subarea_id = t.subarea_id and trns_serial = t.trns_serial;
          g_count := g_count + 1;
        end loop;
      end if;
    end loop;
  end cancel_gl_posting;

  -- ---------------------------------------------------------------------------------------------
  -- legacy DB procedure AR_CREATE_ENTRY_EVERY_ONE (schema SMART, called by the legacy form), copied verbatim from
  -- USER_SOURCE into the package. Only change: its local VARCHAR2(n) variables use CHAR semantics. Reason: the
  -- build database is AL32UTF8 and its columns were converted to CHAR semantics after the standalone procedure
  -- was compiled, so the standalone copy fails with ORA-06502 'Bulk Bind: Truncated Bind' on long Arabic texts
  -- (see the .md). Keep it identical to the DB procedure otherwise (diff: legacy\processes\*.md, 'Port check').
  -- ---------------------------------------------------------------------------------------------
PROCEDURE AR_CREATE_ENTRY_EVERY_ONE(IN_ENTRY_TYPE    AR_TRNSTYPE.ENTRY_TYPE%TYPE,
                                                      IN_EFFECT        AR_TRNSTYPE.EFFECT%TYPE,
                                                      IN_TRNS_ACCT     AR_TRNSTYPE.ACCOUNT_NO%TYPE,
                                                      IN_CUST_ACCT     AR_TRNSTYPE.ACCOUNT_NO%TYPE,
                                                      IN_DISC_ACCT     AR_TRNSTYPE.ACCOUNT_NO%TYPE,
                                                      IN_TOTAL_VALUE   AR_MAINTRNS.TOTAL_VALUE%TYPE,
                                                      IN_NET_VALUE     AR_MAINTRNS.NET_VALUE%TYPE,
                                                      IN_DISC_VALUE    AR_MAINTRNS.DISC_VALUE%TYPE,
                                                      IN_ENTRY_DATE    AR_MAINTRNS.TRNS_DATE%TYPE,
                                                      IN_COST_NO_TRNS  VN_TRNSTYPE.COST_NO%TYPE,
                                                      IN_COST_NO2_TRNS VN_TRNSTYPE.COST_NO2%TYPE,
                                                      IN_COST_NO_DISC  VN_TRNSTYPE.COST_NO%TYPE,
                                                      IN_COST_NO2_DISC VN_TRNSTYPE.COST_NO2%TYPE,
                                                      IN_COST_NO_CUST  VN_TRNSTYPE.COST_NO%TYPE,
                                                      IN_COST_NO2_CUST VN_TRNSTYPE.COST_NO2%TYPE,
                                                      IN_DOC_NO        AR_MAINTRNS.DOC_NO%TYPE,
                                                      IN_DESCRIPTION_A AR_MAINTRNS.DESCRIPTION_A%TYPE,
                                                      IN_DESCRIPTION_E AR_MAINTRNS.DESCRIPTION_A%TYPE,
                                                      IN_TRNS_ID       AR_MAINTRNS.TRNS_ID%TYPE,
                                                      IN_MAINAREA_ID   AR_MAINTRNS.MAINAREA_ID%TYPE,
                                                      IN_SUBAREA_ID    AR_MAINTRNS.SUBAREA_ID%TYPE,
                                                      IN_TRNS_SERIAL   AR_MAINTRNS.TRNS_SERIAL%TYPE,
                                                      IN_CURRENCY_RATE NUMBER,
                                                      IN_ACCOUNT_TYPE  NUMBER,
                                                      GCOMPANY_CODE    NUMBER,
                                                      GPASSWORD_NUMBER NUMBER,
                                                      GUSER_CODE       NUMBER,
                                                      GSYSTEM_NUMBER   NUMBER,
                                                      P_CUSTOMER_CODE  NUMBER,
                                                      P_ENTRY_YEAR     NUMBER,
                                                      P_ENTRY_TYPE     NUMBER,
                                                      P_ENTRY_NO       NUMBER,
                                                      P_POST_TYPE      NUMBER := 2,
                                                      P_PUT_HEADER     NUMBER := 1) IS
  TRNS_ACCT_NAME   VARCHAR2(100 CHAR);
  TRNS_ACCT_NAME_E VARCHAR2(100 CHAR);
  CUST_ACCT_NAME   VARCHAR2(100 CHAR);
  CUST_ACCT_NAME_E VARCHAR2(100 CHAR);
  DISC_ACCT_NAME   VARCHAR2(100 CHAR);
  DISC_ACCT_NAME_E VARCHAR2(100 CHAR);
  LAST_SER         NUMBER(6);
  CURR_YEAR        NUMBER(4);
  BASIC_TYPE       NUMBER(4);
  V_CURR_DATE      DATE;
  ACCOUNT_NAME_A   VARCHAR2(500 CHAR);
  ACCOUNT_NAME_E   VARCHAR2(500 CHAR);
  V_CUST_NAME      VARCHAR2(500 CHAR);
  TEMP_SEQ         NUMBER;
  V_CURRENCY_RATE  NUMBER;
  DET_SEQ          NUMBER;
  TAX_VALUE1 NUMBER;
  TAX_VALUE2 NUMBER;
  TAX_ACC    NUMBER;
  T_TAX_FLAG1 NUMBER;
  ADV_ACCOUNT_NO NUMBER;
BEGIN
  BASIC_TYPE := NVL(IN_ENTRY_TYPE, 2);
  CURR_YEAR  := TO_NUMBER(TO_CHAR(IN_ENTRY_DATE, 'YYYY'));
  IF P_ENTRY_YEAR IS NOT NULL AND P_ENTRY_TYPE IS NOT NULL AND
     P_ENTRY_NO IS NOT NULL AND BASIC_TYPE = P_ENTRY_TYPE AND
     CURR_YEAR = P_ENTRY_YEAR THEN
    DET_SEQ  := MAX_ENTRY_NO(P_ENTRY_YEAR, P_ENTRY_TYPE, P_ENTRY_NO);
    LAST_SER := P_ENTRY_NO;
  ELSE
    LAST_SER := CALC_SERIAL(CURR_YEAR, BASIC_TYPE, IN_ENTRY_DATE);
    DET_SEQ  := 1;
  END IF;
  BEGIN
    SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
      INTO TRNS_ACCT_NAME, TRNS_ACCT_NAME_E
      FROM AC_MASTER
     WHERE ACCOUNT_NUMBER = IN_TRNS_ACCT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      TRNS_ACCT_NAME   := NULL;
      TRNS_ACCT_NAME_E := NULL;
  END;
  BEGIN
    SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
      INTO DISC_ACCT_NAME, DISC_ACCT_NAME_E
      FROM AC_MASTER
     WHERE ACCOUNT_NUMBER = IN_DISC_ACCT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DISC_ACCT_NAME   := NULL;
      DISC_ACCT_NAME_E := NULL;
  END;
  BEGIN
    SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
      INTO CUST_ACCT_NAME, CUST_ACCT_NAME_E
      FROM AC_MASTER
     WHERE ACCOUNT_NUMBER = IN_CUST_ACCT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      CUST_ACCT_NAME   := NULL;
      CUST_ACCT_NAME_E := NULL;
  END;

  BEGIN
    SELECT NAME_A
      INTO V_CUST_NAME
      FROM CUSTOMER
     WHERE CODE = P_CUSTOMER_CODE;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  IF NVL(IN_EFFECT, 0) = 0 THEN
    IF P_PUT_HEADER = 1 THEN
      INSERT INTO AC_YEARLY_TRN
        (ENTRY_YEAR,
         ENTRY_TYPE,
         ENTRY_NO,
         DOC_NO,
         ENTRY_DATE,
         ENTRY_DESC,
         ENTRY_DESC_E,
         CURRENCY_CODE,
         RATE,
         ENTRY_TOTAL,
         MEMO,
         CREATE_COMPANY_CODE,
         CREATE_PASSWORD_NUMBER,
         CREATE_USER_CODE,
         CREATE_DATE,
         POST_SYSTEM)
      VALUES
        (CURR_YEAR,
         BASIC_TYPE,
         LAST_SER,
         IN_DOC_NO,
         IN_ENTRY_DATE,
         IN_DESCRIPTION_A || ' ' || IN_TRNS_ID || '/' || IN_MAINAREA_ID || '/' ||
         IN_SUBAREA_ID || '/' || IN_TRNS_SERIAL,
         IN_DESCRIPTION_E || ' ' || IN_TRNS_ID || '/' || IN_MAINAREA_ID || '/' ||
         IN_SUBAREA_ID || '/' || IN_TRNS_SERIAL,
         1,
         1,
         NVL(IN_TOTAL_VALUE, 0),
         SUBSTR(IN_DESCRIPTION_A || '#' || P_CUSTOMER_CODE || '#',1,490),
         GCOMPANY_CODE,
         GPASSWORD_NUMBER,
         GUSER_CODE,
         V_CURR_DATE,
         4);
    END IF;
    INSERT INTO AC_YEARLY_TRN_DET
      (ENTRY_YEAR,
       ENTRY_TYPE,
       ENTRY_NO,
       SEQ,
       ENTRY_DATE,
       ACCOUNT_NUMBER,
       ENTRY_DESC,
       ENTRY_DESC_E,
       VALUE,
       COST_CODE,
       COST_CODE2,
       BALANCE_FLAG,
       MEMO,
       CREATE_COMPANY_CODE,
       CREATE_PASSWORD_NUMBER,
       CREATE_USER_CODE,
       CREATE_DATE)
    VALUES
      (CURR_YEAR,
       BASIC_TYPE,
       LAST_SER,
       DET_SEQ,
       IN_ENTRY_DATE,
       IN_CUST_ACCT,
       CUST_ACCT_NAME,
       CUST_ACCT_NAME_E,
       NVL(IN_TOTAL_VALUE, 0) - NVL(IN_DISC_VALUE, 0),
       IN_COST_NO_TRNS,
       IN_COST_NO2_TRNS,
       0,
       SUBSTR(IN_DESCRIPTION_A || '#' || P_CUSTOMER_CODE || '#',1,490),
       GCOMPANY_CODE,
       GPASSWORD_NUMBER,
       GUSER_CODE,
       V_CURR_DATE);
    DET_SEQ := DET_SEQ + 1;
    UPDATE AR_MAINTRNS
       SET ACC_YEAR     = CURR_YEAR,
           ACC_TYPE     = BASIC_TYPE,
           ACC_NO       = LAST_SER,
           ACC_DATE     = IN_ENTRY_DATE,
           ACC_CUST_SEQ = 1
     WHERE TRNS_ID = IN_TRNS_ID
       AND MAINAREA_ID = IN_MAINAREA_ID
       AND SUBAREA_ID = IN_SUBAREA_ID
       AND TRNS_SERIAL = IN_TRNS_SERIAL;
    IF NVL(IN_DISC_VALUE, 0) != 0 THEN
      INSERT INTO AC_YEARLY_TRN_DET
        (ENTRY_YEAR,
         ENTRY_TYPE,
         ENTRY_NO,
         SEQ,
         ENTRY_DATE,
         ACCOUNT_NUMBER,
         ENTRY_DESC,
         ENTRY_DESC_E,
         VALUE,
         COST_CODE,
         COST_CODE2,
         BALANCE_FLAG,
         MEMO,
         CREATE_COMPANY_CODE,
         CREATE_PASSWORD_NUMBER,
         CREATE_USER_CODE,
         CREATE_DATE)
      VALUES
        (CURR_YEAR,
         BASIC_TYPE,
         LAST_SER,
         DET_SEQ,
         IN_ENTRY_DATE,
         IN_DISC_ACCT,
         DISC_ACCT_NAME,
         DISC_ACCT_NAME_E,
         NVL(IN_DISC_VALUE, 0),
         IN_COST_NO_DISC,
         IN_COST_NO2_DISC,
         0,
         SUBSTR(IN_DESCRIPTION_A || '#' || P_CUSTOMER_CODE || '#',1,490),
         GCOMPANY_CODE,
         GPASSWORD_NUMBER,
         GUSER_CODE,
         V_CURR_DATE);
      DET_SEQ := DET_SEQ + 1;
      UPDATE AR_MAINTRNS
         SET ACC_YEAR     = CURR_YEAR,
             ACC_TYPE     = BASIC_TYPE,
             ACC_NO       = LAST_SER,
             ACC_DATE     = IN_ENTRY_DATE,
             ACC_DISC_SEQ = 2
       WHERE TRNS_ID = IN_TRNS_ID
         AND MAINAREA_ID = IN_MAINAREA_ID
         AND SUBAREA_ID = IN_SUBAREA_ID
         AND TRNS_SERIAL = IN_TRNS_SERIAL;
    END IF;

    BEGIN
      BEGIN
        SELECT CURRENCY_RATE
          INTO V_CURRENCY_RATE
          FROM AR_MAINTRNS
         WHERE TRNS_ID = IN_TRNS_ID
           AND TRNS_SERIAL = IN_TRNS_SERIAL
           AND MAINAREA_ID = IN_MAINAREA_ID
           AND SUBAREA_ID = IN_SUBAREA_ID;
      EXCEPTION
        WHEN OTHERS THEN
          V_CURRENCY_RATE := 1;
      END;
      BEGIN
        SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
          INTO ACCOUNT_NAME_A, ACCOUNT_NAME_E
          FROM AC_MASTER
         WHERE ACCOUNT_NUMBER = IN_TRNS_ACCT;
      EXCEPTION
        WHEN OTHERS THEN
          ACCOUNT_NAME_A := '';
          ACCOUNT_NAME_E := '';
      END;
      IF P_POST_TYPE = 2 THEN
      
-- begin tax
                     SELECT NVL(SUM(TAX_VALUE1),0),NVL(SUM(TAX_VALUE2),0)
                     INTO   TAX_VALUE1,TAX_VALUE2
                     FROM   AR_SUBTRNS
                     WHERE TRNS_ID = IN_TRNS_ID
                     AND MAINAREA_ID = IN_MAINAREA_ID
                     AND SUBAREA_ID = IN_SUBAREA_ID
                     AND TRNS_SERIAL = IN_TRNS_SERIAL;
                
                     IF TAX_VALUE1 <> 0 THEN
                        SELECT CR_ACCOUNT_NO
                        INTO   TAX_ACC
                        FROM   TX_TAXES_TYPES 
                        WHERE  TAX_CODE = 1;
                
                        BEGIN
                        SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
                        INTO ACCOUNT_NAME_A, ACCOUNT_NAME_E
                        FROM AC_MASTER
                        WHERE ACCOUNT_NUMBER = TAX_ACC;
                          EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            ACCOUNT_NAME_A   := NULL;
                            ACCOUNT_NAME_E := NULL;
                        END;
                
                      INSERT INTO AC_YEARLY_TRN_DET
                      (ENTRY_YEAR,
                       ENTRY_TYPE,
                       ENTRY_NO,
                       SEQ,
                       ENTRY_DATE,
                       ACCOUNT_NUMBER,
                       ENTRY_DESC,
                       ENTRY_DESC_E,
                       VALUE,
                       COST_CODE,
                       COST_CODE2,
                       BALANCE_FLAG,
                       MEMO,
                       CREATE_COMPANY_CODE,
                       CREATE_PASSWORD_NUMBER,
                       CREATE_USER_CODE,
                       CREATE_DATE)
                      VALUES
                      (CURR_YEAR,
                       BASIC_TYPE,
                       LAST_SER,
                       DET_SEQ,
                       IN_ENTRY_DATE,
                       TAX_ACC,
                       ACCOUNT_NAME_A,
                       ACCOUNT_NAME_E,
                       -1*TAX_VALUE1,
                       NULL,
                       NULL,
                       0,
                       SUBSTR(IN_DESCRIPTION_A || '#' || P_CUSTOMER_CODE || '#',1,490),
                       GCOMPANY_CODE,
                       GPASSWORD_NUMBER,
                       GUSER_CODE,
                       V_CURR_DATE);
                       DET_SEQ := DET_SEQ + 1;                
                     END IF;
-- end tax
      
        IF NVL(IN_ACCOUNT_TYPE, 0) = 5 THEN
          FOR C_REC IN (SELECT *
                          FROM AR_MAINTRNS_ACCOUNT_DET
                         WHERE TRNS_ID = IN_TRNS_ID
                           AND MAINAREA_ID = IN_MAINAREA_ID
                           AND SUBAREA_ID = IN_SUBAREA_ID
                           AND TRNS_SERIAL = IN_TRNS_SERIAL) LOOP
            BEGIN
              SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
                INTO ACCOUNT_NAME_A, ACCOUNT_NAME_E
                FROM AC_MASTER
               WHERE ACCOUNT_NUMBER = C_REC.TRNS_ACCOUNT;
            EXCEPTION
              WHEN OTHERS THEN
                ACCOUNT_NAME_A := '';
                ACCOUNT_NAME_E := '';
            END;
            INSERT INTO AC_YEARLY_TRN_DET
              (ENTRY_YEAR,
               ENTRY_TYPE,
               ENTRY_NO,
               SEQ,
               ENTRY_DATE,
               ACCOUNT_NUMBER,
               ENTRY_DESC,
               ENTRY_DESC_E,
               VALUE,
               COST_CODE,
               COST_CODE2,
               BALANCE_FLAG,
               MEMO,
               CREATE_COMPANY_CODE,
               CREATE_PASSWORD_NUMBER,
               CREATE_USER_CODE,
               CREATE_DATE)
            VALUES
              (CURR_YEAR,
               BASIC_TYPE,
               LAST_SER,
               DET_SEQ,
               IN_ENTRY_DATE,
               C_REC.TRNS_ACCOUNT,
               ACCOUNT_NAME_A,
               ACCOUNT_NAME_E,
               -NVL(C_REC.VALUE, 0),
               C_REC.COST_CODE1,
               C_REC.COST_CODE2,
               0,
              -- SUBSTR(C_REC.ACC_DET_DESC || '#' || P_CUSTOMER_CODE || '#',1,490),
               SUBSTR(IN_DESCRIPTION_A || '||' || V_CUST_NAME || '||' || '#' || P_CUSTOMER_CODE || '#' ,1,490),
               GCOMPANY_CODE,
               GPASSWORD_NUMBER,
               GUSER_CODE,
               V_CURR_DATE);
            DET_SEQ := DET_SEQ + 1;
          END LOOP;
        ELSE
          INSERT INTO AC_YEARLY_TRN_DET
            (ENTRY_YEAR,
             ENTRY_TYPE,
             ENTRY_NO,
             SEQ,
             ENTRY_DATE,
             ACCOUNT_NUMBER,
             ENTRY_DESC,
             ENTRY_DESC_E,
             VALUE,
             COST_CODE,
             COST_CODE2,
             BALANCE_FLAG,
             MEMO,
             CREATE_COMPANY_CODE,
             CREATE_PASSWORD_NUMBER,
             CREATE_USER_CODE,
             CREATE_DATE)
          VALUES
            (CURR_YEAR,
             BASIC_TYPE,
             LAST_SER,
             DET_SEQ,
             IN_ENTRY_DATE,
             IN_TRNS_ACCT,
             ACCOUNT_NAME_A,
             ACCOUNT_NAME_E,
             -(NVL(IN_TOTAL_VALUE, 0)- NVL(TAX_VALUE1,0)),
             IN_COST_NO_TRNS,
             IN_COST_NO2_TRNS,
             0,
             SUBSTR(IN_DESCRIPTION_A || '#' || P_CUSTOMER_CODE || '#',1,490),
             GCOMPANY_CODE,
             GPASSWORD_NUMBER,
             GUSER_CODE,
             V_CURR_DATE);
          DET_SEQ := DET_SEQ + 1;
        END IF;
      END IF;
    END;
    UPDATE AR_MAINTRNS
       SET ACC_YEAR    = CURR_YEAR,
           ACC_TYPE    = BASIC_TYPE,
           ACC_NO      = LAST_SER,
           ACC_DATE    = IN_ENTRY_DATE,
           ACC_ACC_SEQ = 3
     WHERE TRNS_ID = IN_TRNS_ID
       AND MAINAREA_ID = IN_MAINAREA_ID
       AND SUBAREA_ID = IN_SUBAREA_ID
       AND TRNS_SERIAL = IN_TRNS_SERIAL;
  ELSE
    IF P_PUT_HEADER = 1 THEN
      INSERT INTO AC_YEARLY_TRN
        (ENTRY_YEAR,
         ENTRY_TYPE,
         ENTRY_NO,
         DOC_NO,
         ENTRY_DATE,
         ENTRY_DESC,
         ENTRY_DESC_E,
         CURRENCY_CODE,
         RATE,
         ENTRY_TOTAL,
         MEMO,
         CREATE_COMPANY_CODE,
         CREATE_PASSWORD_NUMBER,
         CREATE_USER_CODE,
         CREATE_DATE,
         POST_SYSTEM)
      VALUES
        (CURR_YEAR,
         BASIC_TYPE,
         LAST_SER,
         IN_DOC_NO,
         IN_ENTRY_DATE,
         IN_DESCRIPTION_A || ' ' || IN_TRNS_ID || '/' || IN_MAINAREA_ID || '/' ||
         IN_SUBAREA_ID || '/' || IN_TRNS_SERIAL,
         IN_DESCRIPTION_E || ' ' || IN_TRNS_ID || '/' || IN_MAINAREA_ID || '/' ||
         IN_SUBAREA_ID || '/' || IN_TRNS_SERIAL,
         1,
         1,
         (NVL(IN_TOTAL_VALUE, 0) + NVL(IN_DISC_VALUE, 0)),
         NULL,
         GCOMPANY_CODE,
         GPASSWORD_NUMBER,
         GUSER_CODE,
         V_CURR_DATE,
         4);
    END IF;
    IF P_POST_TYPE = 2 THEN

-- tax begin
                         SELECT NVL(TAX_VALUE1,0),NVL(TAX_VALUE2,0),NVL(T_TAX_FLAG1,0)
                         INTO   TAX_VALUE1,TAX_VALUE2,T_TAX_FLAG1
                         FROM   AR_MAINTRNS
                         WHERE TRNS_ID = IN_TRNS_ID
                         AND MAINAREA_ID = IN_MAINAREA_ID
                         AND SUBAREA_ID = IN_SUBAREA_ID
                         AND TRNS_SERIAL = IN_TRNS_SERIAL;
                    
                         IF TAX_VALUE1 <> 0 AND T_TAX_FLAG1 IN (1,2,3,4) THEN
                            SELECT CR_ACCOUNT_NO,ADV_ACCOUNT_NO
                            INTO   TAX_ACC,ADV_ACCOUNT_NO
                            FROM   TX_TAXES_TYPES 
                            WHERE  TAX_CODE = 1;
                    
                        BEGIN
                        SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
                        INTO ACCOUNT_NAME_A, ACCOUNT_NAME_E
                        FROM AC_MASTER
                        WHERE ACCOUNT_NUMBER = TAX_ACC;
                          EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            ACCOUNT_NAME_A   := NULL;
                            ACCOUNT_NAME_E := NULL;
                        END;
                    
                          INSERT INTO AC_YEARLY_TRN_DET
                          (ENTRY_YEAR,
                           ENTRY_TYPE,
                           ENTRY_NO,
                           SEQ,
                           ENTRY_DATE,
                           ACCOUNT_NUMBER,
                           ENTRY_DESC,
                           ENTRY_DESC_E,
                           VALUE,
                           COST_CODE,
                           COST_CODE2,
                           BALANCE_FLAG,
                           MEMO,
                           CREATE_COMPANY_CODE,
                           CREATE_PASSWORD_NUMBER,
                           CREATE_USER_CODE,
                           CREATE_DATE)
                          VALUES
                          (CURR_YEAR,
                           BASIC_TYPE,
                           LAST_SER,
                           DET_SEQ,
                           IN_ENTRY_DATE,
                           TAX_ACC,
                           ACCOUNT_NAME_A,
                           ACCOUNT_NAME_E,
                           DECODE(T_TAX_FLAG1,1,-1,2,-1,3,1,4,1) * TAX_VALUE1,
                           NULL,
                           NULL,
                           0,
                           SUBSTR(IN_DESCRIPTION_A || '#' || P_CUSTOMER_CODE || '#',1,490) ,
                           GCOMPANY_CODE,
                           GPASSWORD_NUMBER,
                           GUSER_CODE,
                           V_CURR_DATE);
                           DET_SEQ := DET_SEQ + 1;
                        IF NVL(T_TAX_FLAG1,0) IN (1,4) THEN
                           BEGIN
                             SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
                             INTO ACCOUNT_NAME_A, ACCOUNT_NAME_E
                             FROM AC_MASTER
                             WHERE ACCOUNT_NUMBER = ADV_ACCOUNT_NO;
                          EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                               ACCOUNT_NAME_A   := NULL;
                               ACCOUNT_NAME_E := NULL;
                          END;
                    
                          INSERT INTO AC_YEARLY_TRN_DET
                          (ENTRY_YEAR,
                           ENTRY_TYPE,
                           ENTRY_NO,
                           SEQ,
                           ENTRY_DATE,
                           ACCOUNT_NUMBER,
                           ENTRY_DESC,
                           ENTRY_DESC_E,
                           VALUE,
                           COST_CODE,
                           COST_CODE2,
                           BALANCE_FLAG,
                           MEMO,
                           CREATE_COMPANY_CODE,
                           CREATE_PASSWORD_NUMBER,
                           CREATE_USER_CODE,
                           CREATE_DATE)
                          VALUES
                          (CURR_YEAR,
                           BASIC_TYPE,
                           LAST_SER,
                           DET_SEQ,
                           IN_ENTRY_DATE,
                           ADV_ACCOUNT_NO,
                           ACCOUNT_NAME_A,
                           ACCOUNT_NAME_E,
                           DECODE(T_TAX_FLAG1,1,1,4,-1) * TAX_VALUE1,
                           NULL,
                           NULL,
                           0,
                           SUBSTR(IN_DESCRIPTION_A || '#' || P_CUSTOMER_CODE || '#',1,490),
                           GCOMPANY_CODE,
                           GPASSWORD_NUMBER,
                           GUSER_CODE,
                           V_CURR_DATE);
                           DET_SEQ := DET_SEQ + 1;
                         END IF;
                      END IF;
-- tax end

      IF NVL(IN_ACCOUNT_TYPE, 0) = 5 THEN
        FOR C_REC IN (SELECT *
                        FROM AR_MAINTRNS_ACCOUNT_DET
                       WHERE TRNS_ID = IN_TRNS_ID
                         AND MAINAREA_ID = IN_MAINAREA_ID
                         AND SUBAREA_ID = IN_SUBAREA_ID
                         AND TRNS_SERIAL = IN_TRNS_SERIAL) LOOP
          BEGIN
            SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
              INTO ACCOUNT_NAME_A, ACCOUNT_NAME_E
              FROM AC_MASTER
             WHERE ACCOUNT_NUMBER = C_REC.TRNS_ACCOUNT;
          EXCEPTION
            WHEN OTHERS THEN
              ACCOUNT_NAME_A := '';
              ACCOUNT_NAME_E := '';
          END;
          INSERT INTO AC_YEARLY_TRN_DET
            (ENTRY_YEAR,
             ENTRY_TYPE,
             ENTRY_NO,
             SEQ,
             ENTRY_DATE,
             ACCOUNT_NUMBER,
             ENTRY_DESC,
             ENTRY_DESC_E,
             VALUE,
             COST_CODE,
             COST_CODE2,
             BALANCE_FLAG,
             MEMO,
             CREATE_COMPANY_CODE,
             CREATE_PASSWORD_NUMBER,
             CREATE_USER_CODE,
             CREATE_DATE)
          VALUES
            (CURR_YEAR,
             BASIC_TYPE,
             LAST_SER,
             DET_SEQ,
             IN_ENTRY_DATE,
             C_REC.TRNS_ACCOUNT,
             ACCOUNT_NAME_A,
             ACCOUNT_NAME_E,
             NVL(C_REC.VALUE, 0),
             C_REC.COST_CODE1,
             C_REC.COST_CODE2,
             0,
             SUBSTR(IN_DESCRIPTION_A || '||' || V_CUST_NAME || '||' || '#' || P_CUSTOMER_CODE || '#',1,490),
             --SUBSTR(C_REC.ACC_DET_DESC || '#' || P_CUSTOMER_CODE || '#',1,490),
             GCOMPANY_CODE,
             GPASSWORD_NUMBER,
             GUSER_CODE,
             V_CURR_DATE);
          DET_SEQ := DET_SEQ + 1;
        END LOOP;
      else

       BEGIN
         SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
         INTO ACCOUNT_NAME_A, ACCOUNT_NAME_E
         FROM AC_MASTER
         WHERE ACCOUNT_NUMBER = IN_TRNS_ACCT;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
           ACCOUNT_NAME_A   := NULL;
           ACCOUNT_NAME_E := NULL;
     END;

        INSERT INTO AC_YEARLY_TRN_DET
          (ENTRY_YEAR,
           ENTRY_TYPE,
           ENTRY_NO,
           SEQ,
           ENTRY_DATE,
           ACCOUNT_NUMBER,
           ENTRY_DESC,
           ENTRY_DESC_E,
           VALUE,
           COST_CODE,
           COST_CODE2,
           BALANCE_FLAG,
           MEMO,
           CREATE_COMPANY_CODE,
           CREATE_PASSWORD_NUMBER,
           CREATE_USER_CODE,
           CREATE_DATE)
        VALUES
          (CURR_YEAR,
           BASIC_TYPE,
           LAST_SER,
           DET_SEQ,
           IN_ENTRY_DATE,
           IN_TRNS_ACCT,
           TRNS_ACCT_NAME,
           TRNS_ACCT_NAME_E,
           (NVL(IN_TOTAL_VALUE, 0) + DECODE(T_TAX_FLAG1,0,0,1,0,2,1,3,-1,4,0) * NVL(TAX_VALUE1,0)),
           IN_COST_NO_TRNS,
           IN_COST_NO2_TRNS,
           0,
           SUBSTR(IN_DESCRIPTION_A || '#' || P_CUSTOMER_CODE || '#',1,490),
           GCOMPANY_CODE,
           GPASSWORD_NUMBER,
           GUSER_CODE,
           V_CURR_DATE);
        DET_SEQ := DET_SEQ + 1;
      END IF;
    END IF;
    UPDATE AR_MAINTRNS
       SET ACC_YEAR    = CURR_YEAR,
           ACC_TYPE    = BASIC_TYPE,
           ACC_NO      = LAST_SER,
           ACC_DATE    = IN_ENTRY_DATE,
           ACC_ACC_SEQ = 1
     WHERE TRNS_ID = IN_TRNS_ID
       AND MAINAREA_ID = IN_MAINAREA_ID
       AND SUBAREA_ID = IN_SUBAREA_ID
       AND TRNS_SERIAL = IN_TRNS_SERIAL;
    IF NVL(IN_DISC_VALUE, 0) != 0 THEN
      INSERT INTO AC_YEARLY_TRN_DET
        (ENTRY_YEAR,
         ENTRY_TYPE,
         ENTRY_NO,
         SEQ,
         ENTRY_DATE,
         ACCOUNT_NUMBER,
         ENTRY_DESC,
         ENTRY_DESC_E,
         VALUE,
         COST_CODE,
         COST_CODE2,
         BALANCE_FLAG,
         MEMO,
         CREATE_COMPANY_CODE,
         CREATE_PASSWORD_NUMBER,
         CREATE_USER_CODE,
         CREATE_DATE)
      VALUES
        (CURR_YEAR,
         BASIC_TYPE,
         LAST_SER,
         DET_SEQ,
         IN_ENTRY_DATE,
         IN_DISC_ACCT,
         DISC_ACCT_NAME,
         DISC_ACCT_NAME_E,
         NVL(IN_DISC_VALUE, 0),
         IN_COST_NO_DISC,
         IN_COST_NO2_DISC,
         0,
         SUBSTR(IN_DESCRIPTION_A || '#' || P_CUSTOMER_CODE || '#',1,490),
         GCOMPANY_CODE,
         GPASSWORD_NUMBER,
         GUSER_CODE,
         V_CURR_DATE);
      DET_SEQ := DET_SEQ + 1;
      UPDATE AR_MAINTRNS
         SET ACC_YEAR     = CURR_YEAR,
             ACC_TYPE     = BASIC_TYPE,
             ACC_NO       = LAST_SER,
             ACC_DATE     = IN_ENTRY_DATE,
             ACC_DISC_SEQ = 2
       WHERE TRNS_ID = IN_TRNS_ID
         AND MAINAREA_ID = IN_MAINAREA_ID
         AND SUBAREA_ID = IN_SUBAREA_ID
         AND TRNS_SERIAL = IN_TRNS_SERIAL;
    END IF;
    INSERT INTO AC_YEARLY_TRN_DET
      (ENTRY_YEAR,
       ENTRY_TYPE,
       ENTRY_NO,
       SEQ,
       ENTRY_DATE,
       ACCOUNT_NUMBER,
       ENTRY_DESC,
       ENTRY_DESC_E,
       VALUE,
       COST_CODE,
       COST_CODE2,
       BALANCE_FLAG,
       MEMO,
       CREATE_COMPANY_CODE,
       CREATE_PASSWORD_NUMBER,
       CREATE_USER_CODE,
       CREATE_DATE)
    VALUES
      (CURR_YEAR,
       BASIC_TYPE,
       LAST_SER,
       DET_SEQ,
       IN_ENTRY_DATE,
       IN_CUST_ACCT,
       CUST_ACCT_NAME,
       CUST_ACCT_NAME_E,
       - (NVL(IN_TOTAL_VALUE, 0) + NVL(IN_DISC_VALUE, 0)),
       IN_COST_NO_CUST,
       IN_COST_NO2_CUST,
       0,
       SUBSTR(IN_DESCRIPTION_A || '||' || V_CUST_NAME || '||' || '#' || P_CUSTOMER_CODE || '#' ,1,490),
       GCOMPANY_CODE,
       GPASSWORD_NUMBER,
       GUSER_CODE,
       V_CURR_DATE);
    DET_SEQ := DET_SEQ + 1;
    UPDATE AR_MAINTRNS
       SET ACC_YEAR     = CURR_YEAR,
           ACC_TYPE     = BASIC_TYPE,
           ACC_NO       = LAST_SER,
           ACC_DATE     = IN_ENTRY_DATE,
           ACC_CUST_SEQ = 3
     WHERE TRNS_ID = IN_TRNS_ID
       AND MAINAREA_ID = IN_MAINAREA_ID
       AND SUBAREA_ID = IN_SUBAREA_ID
       AND TRNS_SERIAL = IN_TRNS_SERIAL;


  END IF;
  UPDATE AR_MAINTRNS
     SET POST_FLAG = 1
   WHERE TRNS_ID = IN_TRNS_ID
     AND MAINAREA_ID = IN_MAINAREA_ID
     AND SUBAREA_ID = IN_SUBAREA_ID
     AND TRNS_SERIAL = IN_TRNS_SERIAL;
  UPDATE AR_SUBTRNS
     SET POST_FLAG = 1
   WHERE TRNS_ID = IN_TRNS_ID
     AND MAINAREA_ID = IN_MAINAREA_ID
     AND SUBAREA_ID = IN_SUBAREA_ID
     AND TRNS_SERIAL = IN_TRNS_SERIAL;
END;

  -- =============================================================================================
  -- ARACUPDT : port of WHEN-BUTTON-PRESSED of EXECUTE_REP + program unit AR_SET_EVERY_ENTRY_AC
  -- (AR\FMB\aracupdt_fmb.xml). The vouchers themselves are written by the DB procedures the form called:
  -- AR_GET_TRNS_DATA (accounts / cost centres of the transaction type; standalone) and AR_CREATE_ENTRY_EVERY_ONE
  -- (AC_YEARLY_TRN + AC_YEARLY_TRN_DET, AR_MAINTRNS.ACC_* / POST_FLAG, AR_SUBTRNS.POST_FLAG; the package copy above).
  -- =============================================================================================
  procedure post_to_gl (
    p_from_date in date, p_to_date in date,
    p_from_trns_id in number default null, p_to_trns_id in number default null,
    p_from_mainarea in number default null, p_to_mainarea in number default null,
    p_from_subarea in number default null, p_to_subarea in number default null,
    p_from_serial in number default null, p_to_serial in number default null,
    p_company_code in number default null, p_user_code in number default null, p_password_number in number default null)
  is
    c_system          constant number := 4;   -- GSYSTEM_NUMBER passed by the button (AR system)
    l_from            date := trunc(p_from_date);
    l_to              date := trunc(p_to_date);
    l_have_rap        number;                 -- SYS_SYSTEMS 15 (cash boxes)
    l_have_check      number;                 -- SYS_SYSTEMS 13 (banks / cheques)
    l_close           date;
    l_post            number;
    -- outputs of AR_GET_TRNS_DATA
    l_trns_account    number;
    l_cust_account    number;
    l_disc_account    number;
    l_entry_type      number;
    l_account_joint   number;
    l_cost_no_trns    number;
    l_cost_no2_trns   number;
    l_cost_no_disc    number;
    l_cost_no2_disc   number;
    l_cost_no_cust    number;
    l_cost_no2_cust   number;
    l_effect          number;
    l_post_type       number;
    l_account_type    number;
    -- AR_TRNSTYPE cost settings, salesman cost centres (cost type 6)
    l_wcost_no_type   number;
    l_wcost_no2_type  number;
    l_wcost_flag      number;
    l_vcost_code      number;
    l_vcost_code2     number;
    l_v_cost_no_cust  number;
    l_v_cost_no2_cust number;
    l_nmsg            pls_integer := 0;
    l_list            varchar2(4000);
    cursor c_trns is
      select m.trns_id, m.mainarea_id, m.subarea_id, m.trns_serial, m.trns_date, m.acc_post_date, m.doc_no,
             m.total_value, m.disc_value, m.net_value, m.description_a, m.description_e, m.customer_id, m.salesman_id,
             m.customer_account, m.disc_account, m.cost_code1, m.cost_code2, m.trns_account, m.currency_rate, m.cash_flag
        from ar_maintrns m, ar_trnstype tt
       where m.trns_id = tt.id
         and ((m.acc_post_date is not null and m.acc_post_date between l_from and l_to)
              or (m.acc_post_date is null and m.trns_date between l_from and l_to))
         and (p_from_trns_id  is null or m.trns_id     >= p_from_trns_id)
         and (p_to_trns_id    is null or m.trns_id     <= p_to_trns_id)
         and (p_from_mainarea is null or m.mainarea_id >= p_from_mainarea)
         and (p_to_mainarea   is null or m.mainarea_id <= p_to_mainarea)
         and (p_from_subarea  is null or m.subarea_id  >= p_from_subarea)
         and (p_to_subarea    is null or m.subarea_id  <= p_to_subarea)
         and (p_from_serial   is null or m.trns_serial >= p_from_serial)
         and (p_to_serial     is null or m.trns_serial <= p_to_serial)
         and nvl(m.post_flag, 0) = 0
         and nvl(m.pay_flag, 0) = 0
         and tt.account_joint = 1
         and (   nvl(m.cash_flag, 0) = 2
              or (nvl(m.cash_flag, 0) in (1) and l_have_rap = 1)
              or (nvl(m.cash_flag, 0) in (0, 3) and l_have_check = 1))
         and m.trns_serial_tot is null
         and (g_password = 0
              or m.trns_id in (select tp.trns_id from ar_trnstype_password tp
                                where tp.flag = 1 and tp.password_number = g_password))
       order by m.trns_id, m.trns_serial;
    type t_rows is table of c_trns%rowtype;
    l_rows t_rows;

    -- legacy: INSERT INTO AR_POST_MSG (texts of the form), shown in block AR_POST_MSG instead of committing
    procedure add_msg (r in c_trns%rowtype, p_code in varchar2, p_a in varchar2, p_e in varchar2) is
    begin
      insert into ar_post_msg (trns_id, mainarea_id, subarea_id, trns_serial, user_code, message)
      values (r.trns_id, r.mainarea_id, r.subarea_id, r.trns_serial, g_user, p_code);
      l_nmsg := l_nmsg + 1;
      if l_nmsg <= 12 then
        l_list := substrb(l_list || chr(10) || r.trns_id || '/' || r.mainarea_id || '/' || r.subarea_id || '/' || r.trns_serial
                         || ': ' || case when g_lang = 'E' then p_e else p_a end, 1, 1400);
      end if;
    end add_msg;
  begin
    init_ctx(p_company_code, p_user_code, p_password_number);
    -- WHEN-VALIDATE-ITEM of FROM_DATE / TO_DATE / FROM_TRNS_SERIAL / TO_TRNS_SERIAL
    if l_from is null or l_to is null or l_to < l_from then
      err(-20111, 'التاريخ الاول يجب ان يكون اقل من التاريخ الثانى', 'The from date should be less than the to date');
    end if;
    if p_from_serial is not null and p_to_serial is not null and p_to_serial < p_from_serial then
      err(-20112, 'خطأ فى إدخال البيانات....!', 'Error in entered data');
    end if;
    select count(1) into l_have_rap   from sys_systems where system_number = 15;
    select count(1) into l_have_check from sys_systems where system_number = 13;
    begin
      select nvl(close_date, to_date('01-01-2000', 'DD-MM-YYYY')) into l_close from ac_basic where company_code = g_company;
    exception when no_data_found then
      l_close := to_date('01-01-2000', 'DD-MM-YYYY');
    end;

    -- GET_TRNS_COUNT_AC = 0 -> alert NO_TRNS (the security filter of the cursor is applied here too)
    open c_trns; fetch c_trns bulk collect into l_rows; close c_trns;
    if l_rows.count = 0 then
      err(-20116, 'لا يوجد حركات يمكن ترحيلها', 'No Transactions Exist for Posting');
    end if;

    delete ar_post_msg where user_code = g_user;

    for i in 1 .. l_rows.count loop
      -- lock the transaction; skip it if a concurrent run posted it meanwhile (not in the legacy form)
      select nvl(post_flag, 0) into l_post
        from ar_maintrns
       where trns_id = l_rows(i).trns_id and mainarea_id = l_rows(i).mainarea_id
         and subarea_id = l_rows(i).subarea_id and trns_serial = l_rows(i).trns_serial
         for update;
      continue when l_post <> 0;

      begin
        ar_get_trns_data(l_rows(i).trns_id, l_rows(i).customer_id, l_rows(i).trns_account, l_rows(i).customer_account,
                         l_rows(i).disc_account, l_rows(i).cost_code1, l_rows(i).cost_code2,
                         l_trns_account, l_cust_account, l_disc_account, l_entry_type, l_account_joint,
                         l_cost_no_trns, l_cost_no2_trns, l_cost_no_disc, l_cost_no2_disc, l_cost_no_cust, l_cost_no2_cust,
                         l_effect, l_post_type, l_account_type);
      exception when others then null;
      end;
      begin
        select cost_no_type, cost_no2_type, cost_flag
          into l_wcost_no_type, l_wcost_no2_type, l_wcost_flag
          from ar_trnstype
         where id = l_rows(i).trns_id;
      exception when others then null;
      end;
      begin
        select cost_code1, cost_code2 into l_vcost_code, l_vcost_code2 from salesman where code = l_rows(i).salesman_id;
      exception when others then
        l_vcost_code := null; l_vcost_code2 := null;
      end;
      -- cost centre type 6 = the salesman's cost centres, per COST_FLAG side (1 trns, 2 customer, 3 discount)
      if l_wcost_no_type = 6 then
        if l_wcost_flag in (1, 4, 5, 7) then l_cost_no_trns := l_vcost_code; end if;
        if l_wcost_flag in (2, 4, 6, 7) then l_cost_no_cust := l_vcost_code; end if;
        if l_wcost_flag in (3, 5, 6, 7) then l_cost_no_disc := l_vcost_code; end if;
      end if;
      if l_wcost_no2_type = 6 then
        if l_wcost_flag in (1, 4, 5, 7) then l_cost_no2_trns := l_vcost_code2; end if;
        if l_wcost_flag in (2, 4, 6, 7) then l_cost_no2_cust := l_vcost_code2; end if;
        if l_wcost_flag in (3, 5, 6, 7) then l_cost_no2_disc := l_vcost_code2; end if;
      end if;
      if l_wcost_no_type = 4 then
        l_v_cost_no_cust := l_cost_no_trns;  l_v_cost_no2_cust := l_cost_no2_trns;
      else
        l_v_cost_no_cust := l_cost_no_cust;  l_v_cost_no2_cust := l_cost_no2_cust;
      end if;

      if l_close < nvl(l_rows(i).acc_post_date, l_rows(i).trns_date) then
        if l_account_joint = 1 then
          if nvl(l_rows(i).cash_flag, 0) != 2 then
            -- cash-box / cheque receipts: the legacy form also created RP_TRNS_MAST / CHECK_MAST documents
            -- (INSERT_RP_PC_TRNS). Only reachable when SYS_SYSTEMS 13 or 15 is installed; not ported.
            add_msg(l_rows(i), 'TREASURY POSTING NOT IMPLEMENTED',
                    'حركة نقدية/شيكات: الترحيل مع نظام الخزينة أو البنوك غير منفذ في النظام الجديد',
                    'cash / cheque transaction: posting with the treasury systems is not implemented');
          elsif nvl(l_cust_account, 0) != 0 then
            if nvl(l_effect, 9) in (0, 1) then
              if (nvl(l_rows(i).disc_value, 0) != 0 and nvl(l_disc_account, 0) != 0) or nvl(l_rows(i).disc_value, 0) = 0 then
                begin
                  ar_create_entry_every_one(
                    l_entry_type,                          -- NVL(P_ENTRY_TYPE, ENTRY_TYPE), P_ENTRY_TYPE is NULL
                    l_effect,
                    l_trns_account,
                    l_cust_account,
                    l_disc_account,
                    l_rows(i).total_value * l_rows(i).currency_rate,
                    l_rows(i).net_value * l_rows(i).currency_rate,
                    l_rows(i).disc_value * l_rows(i).currency_rate,
                    nvl(l_rows(i).acc_post_date, l_rows(i).trns_date),
                    l_cost_no_trns, l_cost_no2_trns,
                    l_cost_no_disc, l_cost_no2_disc,
                    l_v_cost_no_cust, l_v_cost_no2_cust,
                    l_rows(i).doc_no,
                    l_rows(i).description_a,
                    l_rows(i).description_e,
                    l_rows(i).trns_id, l_rows(i).mainarea_id, l_rows(i).subarea_id, l_rows(i).trns_serial,
                    nvl(l_rows(i).currency_rate, 1),
                    l_account_type,
                    g_company, g_password, g_user, c_system,
                    l_rows(i).customer_id,
                    null, null, null,                     -- P_ENTRY_YEAR / TYPE / NO: a new voucher per transaction
                    2, 1);                                -- P_POST_TYPE, P_PUT_HEADER
                exception when others then
                  err(-20118, 'خطأ أثناء ترحيل الحركة ' || l_rows(i).trns_id || '/' || l_rows(i).mainarea_id || '/'
                              || l_rows(i).subarea_id || '/' || l_rows(i).trns_serial || ': ' || sqlerrm,
                      'Error while posting transaction ' || l_rows(i).trns_id || '/' || l_rows(i).mainarea_id || '/'
                              || l_rows(i).subarea_id || '/' || l_rows(i).trns_serial || ': ' || sqlerrm);
                end;
                g_count := g_count + 1;
              end if;
            end if;
          else
            add_msg(l_rows(i), 'CUST ACCOUNT NULL', 'حساب العميل غير معرف لنوع الحركة', 'customer account not defined');
          end if;
        else
          add_msg(l_rows(i), 'NOT ACCOUNT_JOINT = 1', 'نوع الحركة غير مرتبط بالحسابات', 'transaction type not linked to the GL');
        end if;
      else
        add_msg(l_rows(i), 'CLOSE_DATE ', 'تقع فى فترة مقفلة', 'lies in a closed period');
      end if;
    end loop;

    -- legacy: AR_POST_MSG not empty -> the messages are shown and nothing is committed
    if l_nmsg > 0 then
      err(-20117, 'لم يتم الترحيل - يوجد ' || l_nmsg || ' حركة لا يمكن ترحيلها:' || l_list,
          'Nothing was posted - ' || l_nmsg || ' transaction(s) cannot be posted:' || l_list);
    end if;
  end post_to_gl;

  -- =============================================================================================
  -- AR_INVOICE_ADJESTMENT_MAN
  -- =============================================================================================
  function part (p_key in varchar2, p_n in pls_integer) return number is
  begin
    return to_number(regexp_substr(p_key, '[^:]+', 1, p_n));
  end part;

  -- stored residuals re-derived from the allocation lines, with the formulas of DB procedure AR_ADJUST_RESIDUAL
  -- (payment: total - own lines) and of AR_SUBTRNS_PAYED_VALUE (invoice bill: total - allocations), without its COMMIT.
  -- The payment's lines count with their net value (TOTAL - DISC, as AR_RESIDUAL_VALUE_DATE): the same as the line
  -- totals when no discount is given. p_totals = 1 also sets the legacy DISC_VALUE = TRNS_TOTAL - TRNS_NET and
  -- NET_VALUE = TRNS_NET of the payment (AR_SUBTRNS PRE-INSERT of the manual form).
  procedure refresh_payment_residual (p_trns_id number, p_mainarea number, p_subarea number, p_serial number,
                                      p_totals number default 0) is
    l_tot number;
    l_net number;
  begin
    select nvl(sum(s.total_value), 0), nvl(sum(s.total_value - nvl(s.disc_value, 0)), 0) into l_tot, l_net
      from ar_subtrns s
     where s.trns_id = p_trns_id and s.trns_serial = p_serial and s.mainarea_id = p_mainarea and s.subarea_id = p_subarea;
    update ar_maintrns m
       set residual_value = total_value - l_net,
           disc_value     = case when p_totals = 1 then l_tot - l_net else disc_value end,
           net_value      = case when p_totals = 1 then l_net else net_value end
     where trns_id = p_trns_id and mainarea_id = p_mainarea and subarea_id = p_subarea and trns_serial = p_serial;
  end refresh_payment_residual;

  procedure refresh_invoice_residual (p_trns_id number, p_mainarea number, p_subarea number, p_serial number, p_bill_seq number) is
    l_paid number;
  begin
    -- evaluated before the UPDATE: the function reads AR_SUBTRNS (mutating-table rule inside the statement)
    l_paid := ar_subtrns_payed_value(p_trns_id, p_serial, p_mainarea, p_subarea, p_bill_seq);
    update ar_subtrns
       set residual_value = total_value - l_paid
     where trns_id = p_trns_id and mainarea_id = p_mainarea and subarea_id = p_subarea and trns_serial = p_serial
       and bill_seq = p_bill_seq;
  end refresh_invoice_residual;

  procedure manual_adjust (
    p_action in number, p_payment in varchar2, p_invoice in varchar2 default null, p_amount in number default null,
    p_company_code in number default null, p_user_code in number default null, p_password_number in number default null,
    p_disc in number default null)
  is
    l_pay        ar_maintrns%rowtype;
    l_inv        ar_subtrns%rowtype;
    l_inv_cust   number;
    l_pay_open   number;
    l_inv_open   number;
    l_amount     number;
    l_disc       number;
    l_period     number;
    l_source     number;
    l_seq        number;
    l_flag       number;
    l_plus_inv   number;
    l_desc_a     varchar2(500);
    l_desc_e     varchar2(500);
    l_n          number;
    k1 number; k2 number; k3 number; k4 number; k5 number;
  begin
    init_ctx(p_company_code, p_user_code, p_password_number);
    if p_payment is null then
      err(-20121, 'اختر حركة السداد', 'Choose the payment transaction');
    end if;
    begin
      k1 := part(p_payment, 1); k2 := part(p_payment, 2); k3 := part(p_payment, 3); k4 := part(p_payment, 4);
      select * into l_pay
        from ar_maintrns
       where trns_id = k1 and mainarea_id = k2 and subarea_id = k3 and trns_serial = k4
         for update;
    exception when no_data_found or value_error or invalid_number then
      err(-20122, 'حركة السداد غير موجودة', 'Payment transaction not found');
    end;
    -- block AR_MAINTRNS DEFAULT_WHERE: payment types only, plus the group security filters
    select count(1) into l_n from ar_trnstype where id = l_pay.trns_id and effect = 1;
    if l_n = 0 then
      err(-20123, 'الحركة المختارة ليست حركة سداد', 'The selected transaction is not a payment');
    end if;
    if g_password <> 0 then
      select count(1) into l_n from dual
       where l_pay.trns_id in (select tp.trns_id from ar_trnstype_password tp where tp.flag = 1 and tp.password_number = g_password)
         and l_pay.customer_id in (select cp.customer_code from ar_cust_password cp where cp.password_number = g_password)
         and l_pay.salesman_id in (select sp.salesman_code from ar_salesman_password sp where sp.password_number = g_password);
      if l_n = 0 then
        err(-20124, 'ليس لديك صلاحية على هذه الحركة', 'You have no permission on this transaction');
      end if;
    end if;

    if p_action = 2 then
      -- DEL_BTN: USERS.DELETE_AR_ADJESTMENT, no discount, then delete the detail lines and give the values back
      select nvl(max(delete_ar_adjestment), 0) into l_flag from users where users_code = g_user;
      if l_flag <> 1 then
        err(-20125, 'ليس لديك صلاحية', 'You do not have the permission');
      end if;
      select count(1) into l_n
        from ar_subtrns
       where trns_id = l_pay.trns_id and mainarea_id = l_pay.mainarea_id and subarea_id = l_pay.subarea_id
         and trns_serial = l_pay.trns_serial and nvl(disc_value, 0) <> 0;
      if l_n > 0 then
        err(-20126, 'لا يمكن حذف حركة سداد لها خصم', 'A payment with a discount cannot be deleted');
      end if;
      for d in (select * from ar_subtrns
                 where trns_id = l_pay.trns_id and mainarea_id = l_pay.mainarea_id and subarea_id = l_pay.subarea_id
                   and trns_serial = l_pay.trns_serial)
      loop
        delete from ar_subtrns
         where trns_id = d.trns_id and mainarea_id = d.mainarea_id and subarea_id = d.subarea_id
           and trns_serial = d.trns_serial and bill_seq = d.bill_seq;
        if d.inv_trns_id is not null then     -- legacy: UPDATE AR_SUBTRNS SET RESIDUAL_VALUE = RESIDUAL_VALUE + :b1 (invoice bill)
          refresh_invoice_residual(d.inv_trns_id, d.inv_mainarea_id, d.inv_subarea_id, d.inv_trns_serial, d.inv_bill_seq);
        end if;
        g_count := g_count + 1;
      end loop;
      refresh_payment_residual(l_pay.trns_id, l_pay.mainarea_id, l_pay.subarea_id, l_pay.trns_serial);
      return;
    end if;

    if p_action <> 1 then
      err(-20127, 'اختر العملية', 'Choose the action');
    end if;
    -- block AR_MAINTRNS DEFAULT_WHERE: only payments with an open value (TOTAL_VALUE - AR_RESIDUAL_VALUE_DATE(...,SYSDATE) > 0).
    -- Removal (action 2) is not limited to open payments: the legacy user could delete the lines of a payment just allocated in full.
    l_pay_open := nvl(l_pay.total_value, 0)
                  - ar_residual_value_date(l_pay.trns_id, l_pay.trns_serial, l_pay.mainarea_id, l_pay.subarea_id, sysdate);
    if l_pay_open <= 0 then
      err(-20128, 'حركة السداد مسواة بالكامل', 'The payment is already fully allocated');
    end if;
    if p_invoice is null then
      err(-20129, 'اختر الفاتورة', 'Choose the invoice');
    end if;
    begin
      k1 := part(p_invoice, 1); k2 := part(p_invoice, 2); k3 := part(p_invoice, 3); k4 := part(p_invoice, 4); k5 := part(p_invoice, 5);
      select * into l_inv
        from ar_subtrns
       where trns_id = k1 and mainarea_id = k2 and subarea_id = k3 and trns_serial = k4 and bill_seq = k5
         for update;
      select customer_id into l_inv_cust
        from ar_maintrns
       where trns_id = l_inv.trns_id and mainarea_id = l_inv.mainarea_id and subarea_id = l_inv.subarea_id
         and trns_serial = l_inv.trns_serial;
    exception when no_data_found or value_error or invalid_number then
      err(-20130, 'الفاتورة غير موجودة', 'Invoice not found');
    end;
    select count(1) into l_n from ar_trnstype where id = l_inv.trns_id and effect = 0;
    if l_n = 0 or l_inv_cust <> l_pay.customer_id then
      err(-20131, 'الفاتورة ليست من فواتير عميل حركة السداد', 'The invoice does not belong to the customer of the payment');
    end if;
    -- BILL_LOV: residual of the bill = total - AR_SUBTRNS_PAYED_VALUE
    l_inv_open := nvl(l_inv.total_value, 0)
                  - ar_subtrns_payed_value(l_inv.trns_id, l_inv.trns_serial, l_inv.mainarea_id, l_inv.subarea_id, l_inv.bill_seq);
    if l_inv_open = 0 then
      err(-20132, 'الفاتورة مسددة بالكامل', 'The invoice is fully paid');
    end if;
    l_amount := round(nvl(p_amount, least(l_pay_open, l_inv_open)), 2);
    if l_amount <= 0 then
      err(-20133, 'القيمة يجب أن تكون أكبر من الصفر', 'The value must be greater than zero');
    end if;
    if l_amount > round(l_inv_open, 2) then
      err(-20134, 'القيمة المتبقية بالفاتورة أصغر من القيمة المدخلة للسداد', 'The invoice residual is less than the entered value');
    end if;
    -- CALCULATE_DISCOUNT (BILL_ID1 / TOTAL_VALUE WHEN-VALIDATE-ITEM of the manual form): days = payment date - INV_DATE
    -- of the bill, percentage of the invoice total (INV_TOTAL_VALUE), class cursor without the period join; the user may
    -- type another discount (DISC_VALUE WHEN-VALIDATE-ITEM: not above the allocated value)
    app_rules_ar.calc_discount(l_pay.customer_id, l_pay.trns_id, l_pay.ctgry_code,
                               trunc(l_pay.trns_date) - trunc(l_inv.inv_date), l_inv.total_value,
                               l_disc, l_period, l_source, 0);
    if p_disc is not null then
      l_disc := p_disc;
    end if;
    l_disc := round(nvl(l_disc, 0), 2);
    if l_disc < 0 or l_disc > l_amount then
      err(-20136, 'قيمة الخصم لابد أن تكون أقل من القيمة المدخلة للفاتورة',
          'Discount value has to be less than the total value of the invoice');
    end if;
    -- the payment is consumed by the net value of the allocation (TOTAL - DISC)
    if l_amount - l_disc > round(l_pay_open, 2) then
      err(-20135, 'قيمة الفواتير المسددة يجب أن تكون مساوية القيمة الكلية للسداد',
          'The allocated invoices cannot exceed the total of the payment');
    end if;

    select nvl(max(bill_seq), 0) + 1 into l_seq
      from ar_subtrns
     where trns_id = l_pay.trns_id and mainarea_id = l_pay.mainarea_id and subarea_id = l_pay.subarea_id
       and trns_serial = l_pay.trns_serial;
    -- detail description (texts of the .fmx; formats confirmed on the existing allocation lines)
    if l_amount = round(l_inv.total_value, 2) then
      l_desc_a := 'سداد كامل الفاتورة (' || l_inv.bill_id2 || '/' || l_inv.bill_id1 || ') بسند قبض رقم() بقيمة خصم(' || l_disc || ')';
      l_desc_e := 'Pay total invoice value (' || l_inv.bill_id2 || '/' || l_inv.bill_id1 || ') with doc no() with discount value(' || l_disc || ')';
    elsif l_amount = round(l_inv_open, 2) then
      l_desc_a := 'سداد باقى الفاتورة (' || l_inv.bill_id2 || '/' || l_inv.bill_id1 || ') بسند قبض رقم() بقيمة خصم(' || l_disc || ')';
      l_desc_e := 'Pay remain invoice value (' || l_inv.bill_id2 || '/' || l_inv.bill_id1 || ') with doc no() with discount value(' || l_disc || ')';
    else
      l_desc_a := 'سداد جزء من الفاتورة (' || l_inv.bill_id2 || '/' || l_inv.bill_id1 || ') بسند قبض رقم()';
      l_desc_e := 'Pay part of invoice value (' || l_inv.bill_id2 || '/' || l_inv.bill_id1 || ') with doc no()';
    end if;

    insert into ar_subtrns (trns_id, mainarea_id, subarea_id, trns_serial, bill_seq, inv_date, bill_id1, bill_id2,
                            total_value, disc_value, net_value, store_code, det_desc, det_desc_e, inv_pay_date, post_flag,
                            inv_trns_id, inv_trns_serial, inv_mainarea_id, inv_subarea_id, inv_bill_seq, without_comm_flag,
                            dscnt_period, dscnt_source)
    values (l_pay.trns_id, l_pay.mainarea_id, l_pay.subarea_id, l_pay.trns_serial, l_seq, l_pay.trns_date,
            l_inv.bill_id1, l_inv.bill_id2, l_amount, l_disc, l_amount - l_disc, l_inv.store_code, l_desc_a, l_desc_e,
            l_pay.trns_date, l_pay.post_flag, l_inv.trns_id, l_inv.trns_serial, l_inv.mainarea_id, l_inv.subarea_id,
            l_inv.bill_seq, 0, l_period, l_source);

    -- residual bookkeeping (legacy: UPDATE AR_SUBTRNS / AR_MAINTRNS SET RESIDUAL_VALUE = RESIDUAL_VALUE + :b1,
    -- DISC_VALUE = TRNS_TOTAL - TRNS_NET, NET_VALUE = TRNS_NET)
    refresh_invoice_residual(l_inv.trns_id, l_inv.mainarea_id, l_inv.subarea_id, l_inv.trns_serial, l_inv.bill_seq);
    refresh_payment_residual(l_pay.trns_id, l_pay.mainarea_id, l_pay.subarea_id, l_pay.trns_serial, 1);
    -- AR_TRNSTYPE.PLUS_INV_NO_FLAG: append the invoice number to the payment description
    select nvl(max(plus_inv_no_flag), 0) into l_plus_inv from ar_trnstype where id = l_pay.trns_id;
    if l_plus_inv = 1 then
      update ar_maintrns set description_a = description_a || ' ' || 'ف(' || l_inv.bill_id2 || '/' || l_inv.bill_id1 || ')'
       where trns_id = l_pay.trns_id and mainarea_id = l_pay.mainarea_id and subarea_id = l_pay.subarea_id
         and trns_serial = l_pay.trns_serial;
    end if;
    g_count := 1;
  end manual_adjust;

end app_proc_ar;
/
show errors package body app_proc_ar

-- =====================================================================================================
-- APP_PROC_AR_CREDIT : CUSTOMER_CREDIT_LIMIT (another Stage C batch, see app\legacy\processes\CUSTOMER_CREDIT_LIMIT.md).
-- Restored verbatim from the compiled source in SMART (user_source) after this file was rewritten for APP_PROC_AR.
-- =====================================================================================================
create or replace package app_proc_ar_credit authid definer as

  -- Record the change in CUSTOMER_CREDIT_LIMIT (applied) and set CUSTOMER.CREDIT_LIMIT.
  -- p_credit_limit null = remove the limit (legacy accepted an empty value).
  procedure apply_credit_limit (
    p_customer_code in number,
    p_credit_limit  in number,
    p_user_code     in number);

end app_proc_ar_credit;
/

create or replace package body app_proc_ar_credit as

  procedure apply_credit_limit (
    p_customer_code in number,
    p_credit_limit  in number,
    p_user_code     in number)
  is
    l_old customer.credit_limit%type;
  begin
    if p_customer_code is null then
      raise_application_error(-20101, 'يجب اختيار العميل');
    end if;
    if p_credit_limit is not null and p_credit_limit <= 0 then
      raise_application_error(-20102, 'القيمة يجب أن تكون أكبر من صفر أو خالية.');
    end if;
    if p_user_code is null then
      raise_application_error(-20103, 'لم يتم تحديد المستخدم');
    end if;

    -- same customer population as the legacy LOV; lock the customer row while the limit changes
    begin
      select credit_limit
        into l_old
        from customer
       where code = p_customer_code
         and nvl(customer_status, 0) = 1
         and nvl(stopflag, 0) = 0
         for update;
    exception
      when no_data_found then
        raise_application_error(-20104, 'العميل غير موجود أو غير نشط أو موقوف');
    end;

    if (l_old is null and p_credit_limit is null) or l_old = p_credit_limit then
      raise_application_error(-20105, 'الحد الائتماني الجديد مساوٍ للحد الحالي، لم يتم أي تعديل');
    end if;

    -- log row in the legacy format: UPDATE_DATE = day only, UPDATE_TIME = 'HH24:MI', UPDATE_FLAG = 1 (applied)
    insert into customer_credit_limit
      (code, credit_limit, old_credit_limit, update_user, update_date, update_time, update_flag)
    values
      (p_customer_code, p_credit_limit, l_old, p_user_code, trunc(sysdate), to_char(sysdate, 'HH24:MI'), 1);

    update customer
       set credit_limit = p_credit_limit
     where code = p_customer_code;
  end apply_credit_limit;

end app_proc_ar_credit;
/
show errors package body app_proc_ar_credit
