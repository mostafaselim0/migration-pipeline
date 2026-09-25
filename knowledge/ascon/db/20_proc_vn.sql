-- =====================================================================================================
-- APP_PROC_VN : payables (VN) process screens of the ASCON ERP, reconstructed for APEX (Stage C).
--   VNACUPDT    post supplier transactions (VN_MAINTRNS) to the GL             -> post_to_gl
--   VNACCUPDT   cancel the GL posting of supplier transactions (VN_MAINTRNS)   -> cancel_gl_posting
-- Evidence and rules: app\legacy\processes\VNACUPDT.md, VNACCUPDT.md.
-- No COMMIT inside: the APEX page process commits (legacy: one COMMIT_FORM per button press).
-- =====================================================================================================
set define off
set sqlblanklines on

create or replace package app_proc_vn authid definer as

  -- VNACCUPDT (system 5 serial 12): delete the GL vouchers of the selected posted supplier transactions,
  -- reset VN_MAINTRNS.POST_FLAG / ACC_YEAR / ACC_TYPE / ACC_NO and remove the VN_TRNS_ENTRY links.
  procedure cancel_gl_posting (
    p_from_date       in date,
    p_to_date         in date,
    p_from_trns_id    in number default null,
    p_to_trns_id      in number default null,
    p_from_serial     in number default null,
    p_to_serial       in number default null,
    p_company_code    in number default null,
    p_user_code       in number default null,
    p_password_number in number default null);

  -- VNACUPDT (system 5 serial 11): post the selected unposted supplier transactions (payments, adjustments,
  -- discounts) to the GL, one voucher per transaction, through VN_GET_TRNS_DATA (DB) and VN_CREATE_ENTRY_EVERY_ONE
  -- (DB procedure copied into this package) - port of the form program unit VN_SET_EVERY_ENTRY_AC of VN\FMB\vnacupdt.fmb.
  -- All or nothing: when a transaction of the selection cannot be posted (VN_POST_MSG) or a voucher is not
  -- balanced, nothing is posted and the reason is returned in the error message.
  procedure post_to_gl (
    p_from_date       in date,
    p_to_date         in date,
    p_from_trns_id    in number default null,
    p_to_trns_id      in number default null,
    p_from_serial     in number default null,
    p_to_serial       in number default null,
    p_company_code    in number default null,
    p_user_code       in number default null,
    p_password_number in number default null);

  function last_count return number;

end app_proc_vn;
/

create or replace package body app_proc_vn as

  g_lang     varchar2(1) := 'A';
  g_company  number;
  g_count    number := 0;

  function last_count return number is begin return g_count; end;

  procedure err (p_code in pls_integer, p_a in varchar2, p_e in varchar2) is
  begin
    raise_application_error(p_code, case when g_lang = 'E' then p_e else p_a end);
  end err;

  procedure cancel_gl_posting (
    p_from_date in date, p_to_date in date,
    p_from_trns_id in number default null, p_to_trns_id in number default null,
    p_from_serial in number default null, p_to_serial in number default null,
    p_company_code in number default null, p_user_code in number default null, p_password_number in number default null)
  is
    l_from       date := trunc(p_from_date);
    l_to         date := trunc(p_to_date);
    l_from_id    number;
    l_to_id      number;
    l_from_ser   number;
    l_to_ser     number;
    l_have_rap   number;                 -- SYS_SYSTEMS 15 (cash boxes)
    l_have_check number;                 -- SYS_SYSTEMS 13 (banks / cheques)
    l_close      date;
    l_cnt        number;
    l_post       number;
    c_system     constant number := 5;   -- :GLOBAL.SYSTEM_NUMBER of the AP system
    cursor c_trns is
      select trns_id, trns_serial, acc_year, acc_type, acc_no, trns_date
        from vn_maintrns
       where trns_date between l_from and l_to
         and trns_id between l_from_id and l_to_id
         and trns_serial between l_from_ser and l_to_ser
         and nvl(link_flag, 0) = 0
         and (   nvl(pay_method, 0) not in (2, 4)
              or (c_system = 15 and nvl(pay_method, 0) in (2, 4))
              or (nvl(pay_method, 0) in (2) and l_have_rap = 0)
              or (nvl(pay_method, 0) in (4) and l_have_check = 0))
         and nvl(post_flag, 0) = 1
         and serial is null
         and vn_maintrns.trns_id in (select id from vn_trnstype where trns_type != 5 and effect in (0, 1))
       order by trns_date, trns_id, trns_serial;
    type t_rows is table of c_trns%rowtype;
    l_rows t_rows;
  begin
    g_company := nvl(p_company_code, to_number(v('G_COMPANY_CODE')));
    g_lang    := case when lower(nvl(v('G_LANG'), 'ar')) like 'en%' then 'E' else 'A' end;
    g_count   := 0;
    if g_company is null then
      select min(company_code) into g_company from ac_basic;
    end if;
    -- WHEN-VALIDATE-ITEM messages of the legacy form
    if l_from is null or l_to is null or l_to < l_from then
      err(-20141, 'لابد ان يكون الى تاريخ اقل من من تاريخ', 'The to date must not be before the from date');
    end if;
    if p_from_trns_id is not null and p_to_trns_id is not null and p_to_trns_id < p_from_trns_id then
      err(-20142, 'لابد ان يكون من رقم حركة اقل من الى حركة', 'From transaction must be less than to transaction');
    end if;
    if p_from_serial is not null and p_to_serial is not null and p_to_serial < p_from_serial then
      err(-20143, 'لابد ان يكون الى مسلسل اكبر من من مسلسل', 'To serial must be greater than from serial');
    end if;
    -- the legacy cursor uses BETWEEN on every range: empty bounds are opened here
    l_from_id  := nvl(p_from_trns_id, 0);   l_to_id  := nvl(p_to_trns_id, 999999999999);
    l_from_ser := nvl(p_from_serial, 0);    l_to_ser := nvl(p_to_serial, 999999999999);

    select count(1) into l_have_rap   from sys_systems where system_number = 15;
    select count(1) into l_have_check from sys_systems where system_number = 13;
    begin
      select close_date into l_close from ac_basic where company_code = g_company;
    exception when no_data_found then l_close := null;
    end;

    open c_trns; fetch c_trns bulk collect into l_rows; close c_trns;
    if l_rows.count = 0 then
      err(-20144, 'لا توجد حركات يمكن الغاء  ترحيلها', 'No posted transactions to cancel');
    end if;

    for i in 1 .. l_rows.count loop
      if l_rows(i).trns_date <= l_close then
        err(-20145, 'لا يمكن إلغاء ترحيل الحركة رقم ' || l_rows(i).trns_id || '/' || l_rows(i).trns_serial || ' لأنها تقع فى فترة مقفلة',
            'Cannot cancel the posting of transaction ' || l_rows(i).trns_id || '/' || l_rows(i).trns_serial || ' because it lies in a closed period');
      end if;
      select nvl(post_flag, 0) into l_post
        from vn_maintrns
       where trns_id = l_rows(i).trns_id and trns_serial = l_rows(i).trns_serial
         for update;
      if l_post = 1 then                       -- not already reset through a voucher shared with an earlier row
        update vn_maintrns set post_flag = 0
         where trns_id = l_rows(i).trns_id and trns_serial = l_rows(i).trns_serial;
        g_count := g_count + 1;
        if l_rows(i).acc_no is not null then
          -- other transactions of the same voucher (counted, then reset with it)
          select count(1) into l_cnt
            from vn_maintrns
           where acc_year = l_rows(i).acc_year and acc_type = l_rows(i).acc_type and acc_no = l_rows(i).acc_no
             and post_flag = 1;
          g_count := g_count + l_cnt;
          update vn_maintrns set post_flag = 0, acc_year = null, acc_type = null, acc_no = null
           where acc_year = l_rows(i).acc_year and acc_type = l_rows(i).acc_type and acc_no = l_rows(i).acc_no;
          delete from vn_trns_entry_det where trns_id = l_rows(i).trns_id and trns_serial = l_rows(i).trns_serial;
          delete from vn_trns_entry     where trns_id = l_rows(i).trns_id and trns_serial = l_rows(i).trns_serial;
          delete from ac_yearly_trn_det
           where entry_year = l_rows(i).acc_year and entry_type = l_rows(i).acc_type and entry_no = l_rows(i).acc_no;
          delete from ac_yearly_trn
           where entry_year = l_rows(i).acc_year and entry_type = l_rows(i).acc_type and entry_no = l_rows(i).acc_no;
        end if;
      end if;
    end loop;
  end cancel_gl_posting;

  -- ---------------------------------------------------------------------------------------------
  -- legacy DB procedure VN_CREATE_ENTRY_EVERY_ONE (schema SMART, called by the legacy form), copied verbatim from
  -- USER_SOURCE into the package. Only change: its local VARCHAR2(n) variables use CHAR semantics. Reason: the
  -- build database is AL32UTF8 and its columns were converted to CHAR semantics after the standalone procedure
  -- was compiled, so the standalone copy fails with ORA-06502 'Bulk Bind: Truncated Bind' on long Arabic texts
  -- (see the .md). Keep it identical to the DB procedure otherwise (diff: legacy\processes\*.md, 'Port check').
  -- ---------------------------------------------------------------------------------------------
PROCEDURE VN_CREATE_ENTRY_EVERY_ONE (
   IN_EFFECT                 VN_TRNSTYPE.EFFECT%TYPE,
   IN_TRNS_ACCT              VN_TRNSTYPE.ACCOUNT_NO%TYPE,
   IN_SUPP_ACCT              VN_TRNSTYPE.ACCOUNT_NO%TYPE,
   IN_DISC_ACCT              VN_TRNSTYPE.ACCOUNT_NO%TYPE,
   IN_CURRENCY_ACCT          VN_TRNSTYPE.ACCOUNT_NO%TYPE,
   IN_TOTAL_VALUE            VN_MAINTRNS.TOTAL_VALUE%TYPE,
   IN_DISC_VALUE             VN_MAINTRNS.DISC_VALUE%TYPE,
   IN_ENTRY_DATE             VN_MAINTRNS.TRNS_DATE%TYPE,
   IN_COST_NO                VN_TRNSTYPE.COST_NO%TYPE,
   IN_COST_NO2               VN_TRNSTYPE.COST_NO%TYPE,
   IN_COST_NO_SUPP           VN_TRNSTYPE.COST_NO%TYPE,
   IN_COST_NO2_SUPP          VN_TRNSTYPE.COST_NO%TYPE,
   IN_DOC_NO                 VN_MAINTRNS.DOC_NO%TYPE,
   IN_DESCRIPTION_A          VN_MAINTRNS.DESCRIPTION_A%TYPE,
   IN_DESCRIPTION_E          VN_MAINTRNS.DESCRIPTION_A%TYPE,
   IN_TRNS_MEMO              VN_MAINTRNS.TRNS_MEMO%TYPE,
   IN_SUPP_MEMO              VN_MAINTRNS.SUPP_MEMO%TYPE,
   IN_TRNS_ID                VN_MAINTRNS.TRNS_ID%TYPE,
   IN_TRNS_SERIAL            VN_MAINTRNS.TRNS_SERIAL%TYPE,
   GCOMPANY_CODE             NUMBER,
   GPASSWORD_NUMBER          NUMBER,
   GUSER_CODE                NUMBER,
   GSYSTEM_NUMBER            NUMBER,
   P_ENTRY_YEAR       IN OUT NUMBER,
   P_ENTRY_TYPE       IN OUT NUMBER,
   P_ENTRY_NO         IN OUT NUMBER,
   P_POST_TYPE               NUMBER := 2,
   P_PUT_HEADER              NUMBER := 1)
IS
   TRNS_ACCT_NAME          VARCHAR2(100 CHAR);
   TRNS_ACCT_NAME_E        VARCHAR2(100 CHAR);
   SUPP_ACCT_NAME          VARCHAR2(100 CHAR);
   SUPP_ACCT_NAME_E        VARCHAR2(100 CHAR);
   DISC_ACCT_NAME          VARCHAR2(100 CHAR);
   DISC_ACCT_NAME_E        VARCHAR2(100 CHAR);
   CURR_ACCT_NAME          VARCHAR2(100 CHAR);
   CURR_ACCT_NAME_E        VARCHAR2(100 CHAR);
   ACCOUNT_NAME_A          VARCHAR2(100 CHAR);
   ACCOUNT_NAME_E          VARCHAR2(100 CHAR);
   LAST_SER                NUMBER (6);
   CURR_YEAR               NUMBER (4);
   BASIC_TYPE              NUMBER (4);
   SUM_ACC_VAL             NUMBER;
   DET_SEQ                 NUMBER;
   DUMMY                   NUMBER;
   P_CURRENCY_DIFF_VALUE   NUMBER;
   V_FLAG                  NUMBER := 0;
   V_DESC                  VARCHAR2(100 CHAR);
   V_SUP_CODE              NUMBER;
   V_SUPP_NAME             VARCHAR2(200 CHAR);
   V_SUPP_NAME_E           VARCHAR2(200 CHAR);
   DIFF_AMOUNT             NUMBER := 0;
   DISC_DIFF_AMOUNT        NUMBER := 0;
   CURR_DIFF_AMOUNT        NUMBER := 0;
   T_SERIAL_FLAG           NUMBER;
   TAX_VALUE1              NUMBER;
   TAX_ACC                 NUMBER;
   CUSTOM_ACC              NUMBER;
   CUSTOM_VALUE1           NUMBER;

   CURSOR C1
   IS
        SELECT VN.ACC_SER,
               VN.ACC_NUMBER,
               VN.ACC_VAL,
               VN.ACC_MEMO,
               VN.COST_CENTER,
               VN.COST_CENTER2,
               ACM.ACCOUNT_NAME,
               ACM.ACCOUNT_NAME_E
          FROM VN_MAINTRNS_ACC VN, AC_MASTER ACM
         WHERE     TRNS_ID = IN_TRNS_ID
               AND TRNS_SERIAL = IN_TRNS_SERIAL
               AND ACM.ACCOUNT_NUMBER = VN.ACC_NUMBER
      ORDER BY VN.ACC_SER;

   CURSOR C2
   IS
        SELECT VN.ACC_SER,
               VN.ACC_NUMBER,
               VN.ACC_VAL,
               VN.ACC_MEMO,
               VN.COST_CENTER,
               VN.COST_CENTER2,
               ACM.ACCOUNT_NAME,
               ACM.ACCOUNT_NAME_E
          FROM VN_MAINTRNS_SUPP_ACC VN, AC_MASTER ACM
         WHERE     TRNS_ID = IN_TRNS_ID
               AND TRNS_SERIAL = IN_TRNS_SERIAL
               AND ACM.ACCOUNT_NUMBER = VN.ACC_NUMBER
      ORDER BY VN.ACC_SER;
BEGIN
   -- --------------------------------------------------------------
   BEGIN
      SELECT SUPPLIER_ID
        INTO V_SUP_CODE
        FROM VN_MAINTRNS
       WHERE TRNS_ID = IN_TRNS_ID AND TRNS_SERIAL = IN_TRNS_SERIAL;
   EXCEPTION
      WHEN OTHERS
      THEN
         V_SUP_CODE := NULL;
   END;

   IF V_SUP_CODE IS NOT NULL
   THEN
      BEGIN
         SELECT NAME_A, NAME_E
           INTO V_SUPP_NAME, V_SUPP_NAME_E
           FROM SUPPLIER
          WHERE CODE = V_SUP_CODE;
      EXCEPTION
         WHEN OTHERS
         THEN
            V_SUPP_NAME := NULL;
      END;
   END IF;

   BASIC_TYPE := NVL (P_ENTRY_TYPE, 2);
   CURR_YEAR := TO_NUMBER (TO_CHAR (IN_ENTRY_DATE, 'YYYY'));
   P_ENTRY_YEAR := CURR_YEAR;

   SELECT SERIAL_FLAG
     INTO T_SERIAL_FLAG
     FROM AC_TRN_CODES
    WHERE ENTRY_TYPE = BASIC_TYPE AND ENTRY_YEAR = CURR_YEAR;

   IF     P_ENTRY_YEAR IS NOT NULL
      AND P_ENTRY_TYPE IS NOT NULL
      AND P_ENTRY_NO IS NOT NULL
      AND BASIC_TYPE = P_ENTRY_TYPE
      AND CURR_YEAR = P_ENTRY_YEAR
      AND (   T_SERIAL_FLAG = 0
           OR (    T_SERIAL_FLAG = 1
               AND SUBSTR (LPAD (P_ENTRY_NO, 6, '0'), 1, 2) =
                      LPAD (TO_CHAR (IN_ENTRY_DATE, 'MM'), 2, '0')))
   THEN
      DET_SEQ := MAX_ENTRY_NO (P_ENTRY_YEAR, P_ENTRY_TYPE, P_ENTRY_NO);
      LAST_SER := P_ENTRY_NO;
   ELSE
      LAST_SER := CALC_SERIAL (CURR_YEAR, BASIC_TYPE, IN_ENTRY_DATE);
      DET_SEQ := 1;
   END IF;

   P_ENTRY_NO := LAST_SER;

   SELECT COUNT (1)
     INTO DUMMY
     FROM AC_YEARLY_TRN
    WHERE     ENTRY_YEAR = P_ENTRY_YEAR
          AND ENTRY_TYPE = P_ENTRY_TYPE
          AND ENTRY_NO = P_ENTRY_NO;

   IF DUMMY <> 0
   THEN
      LAST_SER := CALC_SERIAL (CURR_YEAR, BASIC_TYPE, IN_ENTRY_DATE);
      P_ENTRY_NO := LAST_SER;
      DET_SEQ := 1;
   END IF;

   BEGIN
      SELECT NVL (SUM (NVL (CURRENCY_DIFF_VALUE, 0)), 0)
        INTO P_CURRENCY_DIFF_VALUE
        FROM VN_SUBTRNS
       WHERE TRNS_ID = IN_TRNS_ID AND TRNS_SERIAL = IN_TRNS_SERIAL;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         P_CURRENCY_DIFF_VALUE := 0;
   END;

   BEGIN
      SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
        INTO TRNS_ACCT_NAME, TRNS_ACCT_NAME_E
        FROM AC_MASTER
       WHERE ACCOUNT_NUMBER = IN_TRNS_ACCT;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         TRNS_ACCT_NAME := NULL;
         TRNS_ACCT_NAME_E := NULL;
   END;

   BEGIN
      SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
        INTO SUPP_ACCT_NAME, SUPP_ACCT_NAME_E
        FROM AC_MASTER
       WHERE ACCOUNT_NUMBER = IN_SUPP_ACCT;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         SUPP_ACCT_NAME := NULL;
         SUPP_ACCT_NAME_E := NULL;
   END;

   BEGIN
      SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
        INTO DISC_ACCT_NAME, DISC_ACCT_NAME_E
        FROM AC_MASTER
       WHERE ACCOUNT_NUMBER = IN_DISC_ACCT;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         DISC_ACCT_NAME := NULL;
         DISC_ACCT_NAME_E := NULL;
   END;

   BEGIN
      SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
        INTO CURR_ACCT_NAME, CURR_ACCT_NAME_E
        FROM AC_MASTER
       WHERE ACCOUNT_NUMBER = IN_CURRENCY_ACCT;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         CURR_ACCT_NAME := NULL;
         CURR_ACCT_NAME_E := NULL;
   END;

   V_DESC := '  ' || IN_TRNS_ID || '/' || IN_TRNS_SERIAL;
   INSERT_TRNS_ENTRY (IN_TRNS_ID,
                      IN_TRNS_SERIAL,
                      P_ENTRY_YEAR,
                      P_ENTRY_TYPE,
                      P_ENTRY_NO);

   IF NVL (IN_EFFECT, 0) = 1
   THEN
      IF P_PUT_HEADER = 1
      THEN
         INSERT INTO AC_YEARLY_TRN (ENTRY_YEAR,
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
              VALUES (CURR_YEAR,
                      BASIC_TYPE,
                      LAST_SER,
                      IN_DOC_NO,
                      IN_ENTRY_DATE,
                      IN_DESCRIPTION_A || V_DESC,
                      IN_DESCRIPTION_E || V_DESC,
                      1,
                      1,
                      NVL (IN_TOTAL_VALUE, 0),
                      NULL,
                      GCOMPANY_CODE,
                      GPASSWORD_NUMBER,
                      GUSER_CODE,
                      SYSDATE,
                      GSYSTEM_NUMBER);
      END IF;

      FOR C_REC IN C2
      LOOP
         --INSERT INTO P_ERR VALUES('A',-1* C_REC.ACC_VAL,1,1,1); COMMIT;
         IF NVL (C_REC.ACC_VAL, 0) > 0
         THEN
            INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
                 VALUES (CURR_YEAR,
                         BASIC_TYPE,
                         LAST_SER,
                         DET_SEQ,
                         IN_ENTRY_DATE,
                         C_REC.ACC_NUMBER,
                         C_REC.ACCOUNT_NAME,
                         C_REC.ACCOUNT_NAME_E,
                         -1 * C_REC.ACC_VAL,
                         C_REC.COST_CENTER,
                         C_REC.COST_CENTER2,
                         0,
                         C_REC.ACC_MEMO || V_DESC,
                         GCOMPANY_CODE,
                         GPASSWORD_NUMBER,
                         GUSER_CODE,
                         SYSDATE);

            INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                   IN_TRNS_SERIAL,
                                   P_ENTRY_YEAR,
                                   P_ENTRY_TYPE,
                                   P_ENTRY_NO,
                                   DET_SEQ);
            DET_SEQ := DET_SEQ + 1;
         END IF;
      END LOOP;

      FOR I IN C1
      LOOP
         IF NVL (I.ACC_VAL, 0) > 0
         THEN
            --INSERT INTO P_ERR VALUES('B',NVL(I.ACC_VAL,0),1,1,1); COMMIT;
            INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
                 VALUES (CURR_YEAR,
                         BASIC_TYPE,
                         LAST_SER,
                         DET_SEQ,
                         IN_ENTRY_DATE,
                         I.ACC_NUMBER,
                         I.ACCOUNT_NAME,
                         I.ACCOUNT_NAME_E,
                         NVL (I.ACC_VAL, 0),
                         I.COST_CENTER,
                         I.COST_CENTER2,
                         0,
                         I.ACC_MEMO || V_DESC,
                         GCOMPANY_CODE,
                         GPASSWORD_NUMBER,
                         GUSER_CODE,
                         SYSDATE);

            INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                   IN_TRNS_SERIAL,
                                   P_ENTRY_YEAR,
                                   P_ENTRY_TYPE,
                                   P_ENTRY_NO,
                                   DET_SEQ);
            DET_SEQ := DET_SEQ + 1;
         END IF;
      END LOOP;

      IF P_POST_TYPE IN (2)
      THEN
         IF IN_TRNS_ACCT IS NOT NULL AND NVL (IN_TOTAL_VALUE, 0) > 0
         THEN
            --INSERT INTO P_ERR VALUES('C',NVL(IN_TOTAL_VALUE,0),1,1,1); COMMIT;
            INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
                 VALUES (CURR_YEAR,
                         BASIC_TYPE,
                         LAST_SER,
                         DET_SEQ,
                         IN_ENTRY_DATE,
                         IN_TRNS_ACCT,
                         TRNS_ACCT_NAME,
                         TRNS_ACCT_NAME_E,
                         NVL (IN_TOTAL_VALUE, 0),
                         IN_COST_NO,
                         IN_COST_NO2,
                         0,
                         IN_DESCRIPTION_A || V_DESC,
                         GCOMPANY_CODE,
                         GPASSWORD_NUMBER,
                         GUSER_CODE,
                         SYSDATE);

            INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                   IN_TRNS_SERIAL,
                                   P_ENTRY_YEAR,
                                   P_ENTRY_TYPE,
                                   P_ENTRY_NO,
                                   DET_SEQ);
            DET_SEQ := DET_SEQ + 1;
         END IF;
      END IF;

      FOR XX
         IN (SELECT BILL_ID1,
                    BILL_ID2,
                    ROUND (DET.TOTAL_VALUE * NVL (CURRENCY_RATE, 0), 2)
                       TOTAL_VALUE,
                    DET.DISC_VALUE * NVL (CURRENCY_RATE, 0) DISC_VALUE,
                    DET.NET_VALUE * NVL (CURRENCY_RATE, 0) NET_VALUE,
                    DET.RESIDUAL_VALUE * NVL (CURRENCY_RATE, 0)
                       RESIDUAL_VALUE,
                    DET.PAY_TYPE_CODE,
                    VN_INVOICE_NO,
                    ACC.ACCOUNT_NO,
                    ACC.DISC_ACCOUNT,
                    MST.COST_NO COST_CODE,
                    ACC.COST_CODE2,
                    DET.ACC_MEMO
               FROM VN_SUBTRNS DET, VN_MAINTRNS MST, VN_PAY_METHODE_ACC ACC
              WHERE     ACC.SUPPLIER_CODE = MST.SUPPLIER_ID
                    AND ACC.SETTEL_TYPE_CODE = DET.PAY_TYPE_CODE
                    AND DET.TRNS_ID = MST.TRNS_ID
                    AND DET.TRNS_SERIAL = MST.TRNS_SERIAL
                    AND DET.TRNS_ID = IN_TRNS_ID
                    AND DET.TRNS_SERIAL = IN_TRNS_SERIAL)
      LOOP
         BEGIN
            SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
              INTO ACCOUNT_NAME_A, ACCOUNT_NAME_E
              FROM AC_MASTER
             WHERE ACCOUNT_NUMBER = XX.ACCOUNT_NO;
         EXCEPTION
            WHEN OTHERS
            THEN
               ACCOUNT_NAME_A := '';
               ACCOUNT_NAME_E := '';
         END;

         --INSERT INTO P_ERR VALUES('D',-1*XX.TOTAL_VALUE,1,1,1); COMMIT;
         IF NVL (XX.TOTAL_VALUE, 0) > 0
         THEN
            INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
                    VALUES (
                              CURR_YEAR,
                              BASIC_TYPE,
                              LAST_SER,
                              DET_SEQ,
                              IN_ENTRY_DATE,
                              XX.ACCOUNT_NO,
                              ACCOUNT_NAME_A,
                              ACCOUNT_NAME_E,
                              -1 * XX.TOTAL_VALUE,
                              XX.COST_CODE,
                              XX.COST_CODE2,
                              0,
                                 IN_DESCRIPTION_A
                              || V_DESC
                              || '  '
                              || V_SUPP_NAME
                              || ' '
                              || XX.ACC_MEMO,
                              GCOMPANY_CODE,
                              GPASSWORD_NUMBER,
                              GUSER_CODE,
                              SYSDATE);

            DIFF_AMOUNT := NVL (DIFF_AMOUNT, 0) + NVL (XX.TOTAL_VALUE, 0);

            INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                   IN_TRNS_SERIAL,
                                   P_ENTRY_YEAR,
                                   P_ENTRY_TYPE,
                                   P_ENTRY_NO,
                                   DET_SEQ);
            DET_SEQ := DET_SEQ + 1;
         END IF;
      END LOOP;

      -------------------------------
      IF     IN_SUPP_ACCT IS NOT NULL
         AND (NVL (IN_TOTAL_VALUE, 0) - NVL (DIFF_AMOUNT, 0)) > 0
      THEN
         --INSERT INTO P_ERR VALUES('E',-1*(NVL(IN_TOTAL_VALUE,0)-NVL(DIFF_AMOUNT,0)),1,1,1); COMMIT;
         INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
              VALUES (CURR_YEAR,
                      BASIC_TYPE,
                      LAST_SER,
                      DET_SEQ,
                      IN_ENTRY_DATE,
                      IN_SUPP_ACCT,
                      SUPP_ACCT_NAME,
                      SUPP_ACCT_NAME_E,
                      -1 * (NVL (IN_TOTAL_VALUE, 0) - NVL (DIFF_AMOUNT, 0)),
                      IN_COST_NO_SUPP,
                      IN_COST_NO2_SUPP,
                      0,
                      IN_DESCRIPTION_A || V_DESC || '  ' || V_SUPP_NAME,
                      GCOMPANY_CODE,
                      GPASSWORD_NUMBER,
                      GUSER_CODE,
                      SYSDATE);

         INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                IN_TRNS_SERIAL,
                                P_ENTRY_YEAR,
                                P_ENTRY_TYPE,
                                P_ENTRY_NO,
                                DET_SEQ);
         DET_SEQ := DET_SEQ + 1;
      END IF;

      -- tax begin

      SELECT NVL (SUM (DET.TAX_VALUE1 * CURRENCY_RATE), 0),
             NVL (SUM ( (DET.TOTAL_VALUE - DET.INV_VALUE) * CURRENCY_RATE),
                  0)
        INTO TAX_VALUE1, CUSTOM_VALUE1
        FROM VN_SUBTRNS DET, VN_MAINTRNS MST
       WHERE     DET.TRNS_ID = MST.TRNS_ID
             AND DET.TRNS_SERIAL = MST.TRNS_SERIAL
             AND DET.TRNS_ID = IN_TRNS_ID
             AND DET.TRNS_SERIAL = IN_TRNS_SERIAL;


      IF TAX_VALUE1 <> 0
      THEN
         SELECT DB_ACCOUNT_NO, CUSTOM_ACCOUNT_NO
           INTO TAX_ACC, CUSTOM_ACC
           FROM TX_TAXES_TYPES
          WHERE TAX_CODE = 1;

         BEGIN
            SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
              INTO TRNS_ACCT_NAME, TRNS_ACCT_NAME_E
              FROM AC_MASTER
             WHERE ACCOUNT_NUMBER = TAX_ACC;
         EXCEPTION
            WHEN OTHERS
            THEN
               TRNS_ACCT_NAME := '';
               TRNS_ACCT_NAME_E := '';
         END;

         INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
              VALUES (CURR_YEAR,
                      BASIC_TYPE,
                      LAST_SER,
                      DET_SEQ,
                      IN_ENTRY_DATE,
                      TAX_ACC,
                      TRNS_ACCT_NAME,
                      TRNS_ACCT_NAME_E,
                      TAX_VALUE1,
                      IN_COST_NO,
                      IN_COST_NO2,
                      0,
                      SUBSTR (IN_DESCRIPTION_A, 1, 200),
                      GCOMPANY_CODE,
                      GPASSWORD_NUMBER,
                      GUSER_CODE,
                      SYSDATE);

         INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                IN_TRNS_SERIAL,
                                P_ENTRY_YEAR,
                                P_ENTRY_TYPE,
                                P_ENTRY_NO,
                                DET_SEQ);
         DET_SEQ := DET_SEQ + 1;

         IF NVL (CUSTOM_VALUE1, 0) = 0
         THEN
            BEGIN
               SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
                 INTO TRNS_ACCT_NAME, TRNS_ACCT_NAME_E
                 FROM AC_MASTER
                WHERE ACCOUNT_NUMBER = CUSTOM_ACC;
            EXCEPTION
               WHEN OTHERS
               THEN
                  TRNS_ACCT_NAME := '';
                  TRNS_ACCT_NAME_E := '';
            END;

            INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
                 VALUES (CURR_YEAR,
                         BASIC_TYPE,
                         LAST_SER,
                         DET_SEQ,
                         IN_ENTRY_DATE,
                         CUSTOM_ACC,
                         TRNS_ACCT_NAME,
                         TRNS_ACCT_NAME_E,
                         -1 * TAX_VALUE1,
                         IN_COST_NO,
                         IN_COST_NO2,
                         0,
                         SUBSTR (IN_DESCRIPTION_A, 1, 200),
                         GCOMPANY_CODE,
                         GPASSWORD_NUMBER,
                         GUSER_CODE,
                         SYSDATE);

            INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                   IN_TRNS_SERIAL,
                                   P_ENTRY_YEAR,
                                   P_ENTRY_TYPE,
                                   P_ENTRY_NO,
                                   DET_SEQ);
            DET_SEQ := DET_SEQ + 1;
         END IF;
      END IF;
   -- tax end;

   ELSIF NVL (IN_EFFECT, 0) = 0
   THEN
      IF P_PUT_HEADER = 1
      THEN
         --INSERT INTO P_ERR VALUES('ESLAM',CURR_YEAR,BASIC_TYPE,LAST_SER,1); COMMIT;
         INSERT INTO AC_YEARLY_TRN (ENTRY_YEAR,
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
              VALUES (CURR_YEAR,
                      BASIC_TYPE,
                      LAST_SER,
                      IN_DOC_NO,
                      IN_ENTRY_DATE,
                      IN_DESCRIPTION_A,
                      IN_DESCRIPTION_E,
                      1,
                      1,
                      (NVL (IN_TOTAL_VALUE, 0) + NVL (IN_DISC_VALUE, 0)),
                      NULL,
                      GCOMPANY_CODE,
                      GPASSWORD_NUMBER,
                      GUSER_CODE,
                      SYSDATE,
                      GSYSTEM_NUMBER);

         INSERT_TRNS_ENTRY (IN_TRNS_ID,
                            IN_TRNS_SERIAL,
                            P_ENTRY_YEAR,
                            P_ENTRY_TYPE,
                            P_ENTRY_NO);
      END IF;

      DET_SEQ := DET_SEQ + 1;

      IF P_POST_TYPE IN (2)
      THEN
         IF IN_TRNS_ACCT IS NOT NULL
         THEN
            IF NVL (IN_TOTAL_VALUE, 0) > 0
            THEN
               --INSERT INTO P_ERR VALUES('F',- NVL(IN_TOTAL_VALUE,0),1,1,1); COMMIT;
               INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
                    VALUES (CURR_YEAR,
                            BASIC_TYPE,
                            LAST_SER,
                            DET_SEQ,
                            IN_ENTRY_DATE,
                            IN_TRNS_ACCT,
                            TRNS_ACCT_NAME,
                            TRNS_ACCT_NAME_E,
                            -NVL (IN_TOTAL_VALUE, 0),
                            IN_COST_NO,
                            IN_COST_NO2,
                            0,
                            IN_DESCRIPTION_A || V_DESC,
                            GCOMPANY_CODE,
                            GPASSWORD_NUMBER,
                            GUSER_CODE,
                            SYSDATE);

               INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                      IN_TRNS_SERIAL,
                                      P_ENTRY_YEAR,
                                      P_ENTRY_TYPE,
                                      P_ENTRY_NO,
                                      DET_SEQ);
               DET_SEQ := DET_SEQ + 1;
            END IF;
         END IF;
      END IF;

      IF NVL (P_CURRENCY_DIFF_VALUE, 0) <> 0 AND IN_CURRENCY_ACCT IS NOT NULL
      THEN
         --INSERT INTO P_ERR VALUES('G',P_CURRENCY_DIFF_VALUE,1,1,1); COMMIT;
         INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
              VALUES (CURR_YEAR,
                      BASIC_TYPE,
                      LAST_SER,
                      DET_SEQ,
                      IN_ENTRY_DATE,
                      IN_CURRENCY_ACCT,
                      CURR_ACCT_NAME,
                      CURR_ACCT_NAME_E,
                      P_CURRENCY_DIFF_VALUE,
                      IN_COST_NO,
                      IN_COST_NO2,
                      0,
                      IN_DESCRIPTION_A || V_DESC,
                      GCOMPANY_CODE,
                      GPASSWORD_NUMBER,
                      GUSER_CODE,
                      SYSDATE);

         INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                IN_TRNS_SERIAL,
                                P_ENTRY_YEAR,
                                P_ENTRY_TYPE,
                                P_ENTRY_NO,
                                DET_SEQ);
         DET_SEQ := DET_SEQ + 1;
      END IF;

      FOR I IN C1
      LOOP
         IF NVL (I.ACC_VAL, 0) > 0
         THEN
            --INSERT INTO P_ERR VALUES('H',-1*NVL(I.ACC_VAL,0),CURR_YEAR,BASIC_TYPE,LAST_SER); COMMIT;
            INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
                 VALUES (CURR_YEAR,
                         BASIC_TYPE,
                         LAST_SER,
                         DET_SEQ,
                         IN_ENTRY_DATE,
                         I.ACC_NUMBER,
                         I.ACCOUNT_NAME,
                         I.ACCOUNT_NAME_E,
                         -1 * NVL (I.ACC_VAL, 0),
                         I.COST_CENTER,
                         I.COST_CENTER2,
                         0,
                         I.ACC_MEMO || V_DESC,
                         GCOMPANY_CODE,
                         GPASSWORD_NUMBER,
                         GUSER_CODE,
                         SYSDATE);

            INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                   IN_TRNS_SERIAL,
                                   P_ENTRY_YEAR,
                                   P_ENTRY_TYPE,
                                   P_ENTRY_NO,
                                   DET_SEQ);
            DET_SEQ := DET_SEQ + 1;
         END IF;
      END LOOP;

      FOR C_REC IN C2
      LOOP
         IF C_REC.ACC_VAL > 0
         THEN
            --INSERT INTO P_ERR VALUES('I',C_REC.ACC_VAL,1,1,1); COMMIT;
            INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
                 VALUES (CURR_YEAR,
                         BASIC_TYPE,
                         LAST_SER,
                         DET_SEQ,
                         IN_ENTRY_DATE,
                         C_REC.ACC_NUMBER,
                         C_REC.ACCOUNT_NAME,
                         C_REC.ACCOUNT_NAME_E,
                         C_REC.ACC_VAL,
                         C_REC.COST_CENTER,
                         C_REC.COST_CENTER2,
                         0,
                         C_REC.ACC_MEMO || V_DESC,
                         GCOMPANY_CODE,
                         GPASSWORD_NUMBER,
                         GUSER_CODE,
                         SYSDATE);

            INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                   IN_TRNS_SERIAL,
                                   P_ENTRY_YEAR,
                                   P_ENTRY_TYPE,
                                   P_ENTRY_NO,
                                   DET_SEQ);
            DET_SEQ := DET_SEQ + 1;
         END IF;
      END LOOP;

      FOR XX
         IN (SELECT ROUND (MST.TOTAL_VALUE * NVL (CURRENCY_RATE, 1), 2)
                       TOTAL_VALUE,
                    (MST.DISC_VALUE * NVL (CURRENCY_RATE, 1)) DISC_VALUE,
                    (MST.NET_VALUE * NVL (CURRENCY_RATE, 1)) NET_VALUE,
                    (MST.RESIDUAL_VALUE * NVL (CURRENCY_RATE, 1))
                       RESIDUAL_VALUE,
                    MST.PAY_TYPE_CODE,
                    ACC.ACCOUNT_NO,
                    ACC.DISC_ACCOUNT,
                    MST.COST_NO COST_CODE,
                    ACC.COST_CODE2,
                    MST.CURRENCY_DIFF_VALUE
               FROM VN_MAINTRNS MST, VN_PAY_METHODE_ACC ACC
              WHERE     ACC.SUPPLIER_CODE = MST.SUPPLIER_ID
                    AND ACC.SETTEL_TYPE_CODE = MST.PAY_TYPE_CODE
                    AND MST.TRNS_ID = IN_TRNS_ID
                    AND MST.TRNS_SERIAL = IN_TRNS_SERIAL)
      LOOP
         BEGIN
            SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
              INTO ACCOUNT_NAME_A, ACCOUNT_NAME_E
              FROM AC_MASTER
             WHERE ACCOUNT_NUMBER = XX.ACCOUNT_NO;
         EXCEPTION
            WHEN OTHERS
            THEN
               ACCOUNT_NAME_A := '';
               ACCOUNT_NAME_E := '';
         END;

         IF (NVL (XX.TOTAL_VALUE, 0) - NVL (XX.CURRENCY_DIFF_VALUE, 0)) > 0
         THEN
            --INSERT INTO P_ERR VALUES('J',NVL(XX.TOTAL_VALUE,0)-NVL(XX.CURRENCY_DIFF_VALUE,0),LAST_SER,DET_SEQ,XX.ACCOUNT_NO); COMMIT;
            INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
                    VALUES (
                              CURR_YEAR,
                              BASIC_TYPE,
                              LAST_SER,
                              DET_SEQ,
                              IN_ENTRY_DATE,
                              XX.ACCOUNT_NO,
                              ACCOUNT_NAME_A,
                              ACCOUNT_NAME_E,
                                NVL (XX.TOTAL_VALUE, 0)
                              - NVL (XX.CURRENCY_DIFF_VALUE, 0),
                              IN_COST_NO_SUPP,--XX.COST_CODE,
                              IN_COST_NO2_SUPP,--XX.COST_CODE2,
                              0,
                                 IN_DESCRIPTION_A
                              || V_DESC
                              || '  '
                              || V_SUPP_NAME,
                              GCOMPANY_CODE,
                              GPASSWORD_NUMBER,
                              GUSER_CODE,
                              SYSDATE);

            DIFF_AMOUNT := NVL (DIFF_AMOUNT, 0) + NVL (XX.TOTAL_VALUE, 0);
            CURR_DIFF_AMOUNT :=
               NVL (CURR_DIFF_AMOUNT, 0) + NVL (XX.CURRENCY_DIFF_VALUE, 0);

            INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                   IN_TRNS_SERIAL,
                                   P_ENTRY_YEAR,
                                   P_ENTRY_TYPE,
                                   P_ENTRY_NO,
                                   DET_SEQ);

            DET_SEQ := DET_SEQ + 1;
         END IF;

         IF NVL (XX.DISC_VALUE, 0) > 0
         THEN
            BEGIN
               SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
                 INTO ACCOUNT_NAME_A, ACCOUNT_NAME_E
                 FROM AC_MASTER
                WHERE ACCOUNT_NUMBER = XX.DISC_ACCOUNT;
            EXCEPTION
               WHEN OTHERS
               THEN
                  ACCOUNT_NAME_A := '';
                  ACCOUNT_NAME_E := '';
            END;

            --INSERT INTO P_ERR VALUES('K',-1 * NVL(XX.DISC_VALUE,0),1,1,1); COMMIT;
            INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
                 VALUES (CURR_YEAR,
                         BASIC_TYPE,
                         LAST_SER,
                         DET_SEQ,
                         IN_ENTRY_DATE,
                         XX.DISC_ACCOUNT,
                         ACCOUNT_NAME_A,
                         ACCOUNT_NAME_E,
                         -1 * NVL (XX.DISC_VALUE, 0),
                         XX.COST_CODE,
                         XX.COST_CODE2,
                         0,
                         IN_DESCRIPTION_A || V_DESC,
                         GCOMPANY_CODE,
                         GPASSWORD_NUMBER,
                         GUSER_CODE,
                         SYSDATE);

            DISC_DIFF_AMOUNT :=
               NVL (DISC_DIFF_AMOUNT, 0) + NVL (XX.DISC_VALUE, 0);

            INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                   IN_TRNS_SERIAL,
                                   P_ENTRY_YEAR,
                                   P_ENTRY_TYPE,
                                   P_ENTRY_NO,
                                   DET_SEQ);
            DET_SEQ := DET_SEQ + 1;
         END IF;
      END LOOP;

      ------------------------------------
      IF     IN_SUPP_ACCT IS NOT NULL
         AND ROUND (
                  (  (NVL (IN_TOTAL_VALUE, 0) + NVL (IN_DISC_VALUE, 0))
                   - NVL (DIFF_AMOUNT, 0))
                - (NVL (P_CURRENCY_DIFF_VALUE, 0) - NVL (CURR_DIFF_AMOUNT, 0)),
                2) > 0
      THEN
         --INSERT INTO P_ERR VALUES('L',ROUND(((NVL(IN_TOTAL_VALUE,0) + NVL(IN_DISC_VALUE,0))- NVL(DIFF_AMOUNT,0))- (NVL(P_CURRENCY_DIFF_VALUE,0)-NVL(CURR_DIFF_AMOUNT,0)),2),1,1,1); COMMIT;
         INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
                 VALUES (
                           CURR_YEAR,
                           BASIC_TYPE,
                           LAST_SER,
                           DET_SEQ,
                           IN_ENTRY_DATE,
                           IN_SUPP_ACCT,
                           SUPP_ACCT_NAME,
                           SUPP_ACCT_NAME_E,
                             (  (  NVL (IN_TOTAL_VALUE, 0)
                                 + NVL (IN_DISC_VALUE, 0))
                              - NVL (DIFF_AMOUNT, 0))
                           - (  NVL (P_CURRENCY_DIFF_VALUE, 0)
                              - NVL (CURR_DIFF_AMOUNT, 0)),
                           IN_COST_NO_SUPP,
                           IN_COST_NO2_SUPP,
                           0,
                           IN_DESCRIPTION_A || V_DESC || '  ' || V_SUPP_NAME,
                           GCOMPANY_CODE,
                           GPASSWORD_NUMBER,
                           GUSER_CODE,
                           SYSDATE);

         INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                IN_TRNS_SERIAL,
                                P_ENTRY_YEAR,
                                P_ENTRY_TYPE,
                                P_ENTRY_NO,
                                DET_SEQ);
         DET_SEQ := DET_SEQ + 1;
      END IF;

      IF NVL (IN_DISC_VALUE, 0) - NVL (DISC_DIFF_AMOUNT, 0) > 0
      THEN
         --iNSERT INTO P_ERR VALUES('M',-1 * NVL(IN_DISC_VALUE , 0)-NVL(DISC_DIFF_AMOUNT,0),1,1,1); COMMIT;
         INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
                 VALUES (
                           CURR_YEAR,
                           BASIC_TYPE,
                           LAST_SER,
                           DET_SEQ,
                           IN_ENTRY_DATE,
                           IN_DISC_ACCT,
                           DISC_ACCT_NAME,
                           DISC_ACCT_NAME_E,
                             -1 * NVL (IN_DISC_VALUE, 0)
                           - NVL (DISC_DIFF_AMOUNT, 0),
                           IN_COST_NO,
                           IN_COST_NO2,
                           0,
                           IN_DESCRIPTION_A || V_DESC,
                           GCOMPANY_CODE,
                           GPASSWORD_NUMBER,
                           GUSER_CODE,
                           SYSDATE);

         INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                IN_TRNS_SERIAL,
                                P_ENTRY_YEAR,
                                P_ENTRY_TYPE,
                                P_ENTRY_NO,
                                DET_SEQ);
         DET_SEQ := DET_SEQ + 1;
      END IF;

      -- tax begin

      SELECT NVL (SUM (MST.TAX_VALUE1 * CURRENCY_RATE), 0),
             NVL (SUM ( (MST.TOTAL_VALUE - MST.INV_VALUE) * CURRENCY_RATE),
                  0)
        INTO TAX_VALUE1, CUSTOM_VALUE1
        FROM VN_MAINTRNS MST
       WHERE MST.TRNS_ID = IN_TRNS_ID AND MST.TRNS_SERIAL = IN_TRNS_SERIAL;


      IF TAX_VALUE1 <> 0
      THEN
         SELECT CR_ACCOUNT_NO, CUSTOM_ACCOUNT_NO
           INTO TAX_ACC, CUSTOM_ACC
           FROM TX_TAXES_TYPES
          WHERE TAX_CODE = 1;

         BEGIN
            SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
              INTO TRNS_ACCT_NAME, TRNS_ACCT_NAME_E
              FROM AC_MASTER
             WHERE ACCOUNT_NUMBER = TAX_ACC;
         EXCEPTION
            WHEN OTHERS
            THEN
               TRNS_ACCT_NAME := '';
               TRNS_ACCT_NAME_E := '';
         END;

         INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
              VALUES (CURR_YEAR,
                      BASIC_TYPE,
                      LAST_SER,
                      DET_SEQ,
                      IN_ENTRY_DATE,
                      TAX_ACC,
                      TRNS_ACCT_NAME,
                      TRNS_ACCT_NAME_E,
                      -1 * TAX_VALUE1,
                      IN_COST_NO,
                      IN_COST_NO2,
                      0,
                      SUBSTR (IN_DESCRIPTION_A, 1, 200),
                      GCOMPANY_CODE,
                      GPASSWORD_NUMBER,
                      GUSER_CODE,
                      SYSDATE);

         INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                IN_TRNS_SERIAL,
                                P_ENTRY_YEAR,
                                P_ENTRY_TYPE,
                                P_ENTRY_NO,
                                DET_SEQ);
         DET_SEQ := DET_SEQ + 1;

         IF NVL (CUSTOM_VALUE1, 0) = 0
         THEN
            BEGIN
               SELECT ACCOUNT_NAME, ACCOUNT_NAME_E
                 INTO TRNS_ACCT_NAME, TRNS_ACCT_NAME_E
                 FROM AC_MASTER
                WHERE ACCOUNT_NUMBER = CUSTOM_ACC;
            EXCEPTION
               WHEN OTHERS
               THEN
                  TRNS_ACCT_NAME := '';
                  TRNS_ACCT_NAME_E := '';
            END;

            INSERT INTO AC_YEARLY_TRN_DET (ENTRY_YEAR,
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
                 VALUES (CURR_YEAR,
                         BASIC_TYPE,
                         LAST_SER,
                         DET_SEQ,
                         IN_ENTRY_DATE,
                         CUSTOM_ACC,
                         TRNS_ACCT_NAME,
                         TRNS_ACCT_NAME_E,
                         TAX_VALUE1,
                         IN_COST_NO,
                         IN_COST_NO2,
                         0,
                         SUBSTR (IN_DESCRIPTION_A, 1, 200),
                         GCOMPANY_CODE,
                         GPASSWORD_NUMBER,
                         GUSER_CODE,
                         SYSDATE);

            INSERT_TRNS_ENTRY_DET (IN_TRNS_ID,
                                   IN_TRNS_SERIAL,
                                   P_ENTRY_YEAR,
                                   P_ENTRY_TYPE,
                                   P_ENTRY_NO,
                                   DET_SEQ);
            DET_SEQ := DET_SEQ + 1;
         END IF;
      END IF;
   -- tax end;

   END IF;

   UPDATE VN_MAINTRNS
      SET POST_FLAG = 1,
          ACC_YEAR = CURR_YEAR,
          ACC_TYPE = BASIC_TYPE,
          ACC_NO = LAST_SER,
          ACC_ACC_SEQ = DET_SEQ,
          ACC_DATE = IN_ENTRY_DATE
    WHERE TRNS_ID = IN_TRNS_ID AND TRNS_SERIAL = IN_TRNS_SERIAL;
END;

  -- =============================================================================================
  -- VNACUPDT : port of WHEN-BUTTON-PRESSED of EXECUTE_REP + program unit VN_SET_EVERY_ENTRY_AC
  -- (VN\FMB\vnacupdt_fmb.xml). The vouchers are written by the DB procedures the form used:
  -- VN_GET_TRNS_DATA (accounts / cost centres of the transaction type; standalone) and VN_CREATE_ENTRY_EVERY_ONE
  -- (AC_YEARLY_TRN + AC_YEARLY_TRN_DET, VN_TRNS_ENTRY(_DET), VN_MAINTRNS.POST_FLAG / ACC_*; the package copy above).
  -- The form carried its own copy of VN_CREATE_ENTRY_EVERY_ONE, identical to the DB procedure except debugging
  -- MSG(n,1,0) alerts.
  -- =============================================================================================
  procedure post_to_gl (
    p_from_date in date, p_to_date in date,
    p_from_trns_id in number default null, p_to_trns_id in number default null,
    p_from_serial in number default null, p_to_serial in number default null,
    p_company_code in number default null, p_user_code in number default null, p_password_number in number default null)
  is
    c_system          constant number := 5;   -- GSYSTEM_NUMBER passed by the button (AP system)
    l_from            date := trunc(p_from_date);
    l_to              date := trunc(p_to_date);
    l_user            number;
    l_password        number;
    l_have_rap        number;                 -- SYS_SYSTEMS 15 (cash boxes)
    l_have_check      number;                 -- SYS_SYSTEMS 13 (banks / cheques)
    l_close           date;
    l_post            number;
    -- outputs of VN_GET_TRNS_DATA
    l_trns_account    number;
    l_supp_account    number;
    l_supp_name_a     varchar2(500);
    l_supp_name_e     varchar2(500);
    l_disc_account    number;
    l_curr_account    number;
    l_account_joint   number;
    l_cost_no_trns    number;
    l_cost_no2_trns   number;
    l_cost_no_supp    number;
    l_cost_no2_supp   number;
    l_effect          number;
    -- VN_TRNSTYPE cost settings
    l_wcost_no_type   number;
    l_wcost_no2_type  number;
    l_wcost_flag      number;
    l_v_cost_no_supp  number;
    l_v_cost_no2_supp number;
    -- IN OUT voucher key carried from one transaction to the next (V_ENTRY_YEAR / TYPE / NO of the button)
    l_entry_year      number;
    l_entry_type      number;
    l_entry_no        number;
    l_total           number;
    l_nmsg            pls_integer := 0;
    l_list            varchar2(4000);
    type t_vouchers is table of varchar2(40);
    l_vouchers        t_vouchers := t_vouchers();
    cursor c_trns is
      select m.trns_id, m.trns_serial, m.trns_date, m.acc_post_date, m.doc_no, m.total_value, m.disc_value,
             m.description_a, m.description_e, m.supplier_id, m.supplier_account, m.disc_account,
             m.cost_no cost_code1, m.cost_no2 cost_code2, m.trns_account, m.currency_rate, m.pay_method,
             m.trns_memo, m.supp_memo
        from vn_maintrns m, vn_trnstype tt
       where m.trns_id = tt.id
         and ((m.acc_post_date is not null and m.acc_post_date between l_from and l_to)
              or (m.acc_post_date is null and m.trns_date between l_from and l_to))
         and (p_from_trns_id is null or m.trns_id     >= p_from_trns_id)
         and (p_to_trns_id   is null or m.trns_id     <= p_to_trns_id)
         and (p_from_serial  is null or m.trns_serial >= p_from_serial)
         and (p_to_serial    is null or m.trns_serial <= p_to_serial)
         and nvl(m.post_flag, 0) = 0
         and nvl(m.pay_flag, 0) = 0
         and tt.account_joint = 1
         and (   nvl(m.pay_method, 0) = 5
              or (nvl(m.pay_method, 0) in (2) and l_have_rap = 1)
              or (nvl(m.pay_method, 0) in (4, 6) and l_have_check = 1))
         and (l_password = 0
              or m.trns_id in (select tp.trns_id from vn_trnstype_password tp
                                where tp.flag = 1 and tp.password_number = l_password))
       order by m.trns_id, m.trns_serial;
    type t_rows is table of c_trns%rowtype;
    l_rows t_rows;

    -- legacy: INSERT INTO VN_POST_MSG (texts of the form), shown in block VN_POST_MSG instead of committing
    procedure add_msg (r in c_trns%rowtype, p_code in varchar2, p_a in varchar2, p_e in varchar2) is
    begin
      insert into vn_post_msg (trns_id, trns_serial, user_code, message)
      values (r.trns_id, r.trns_serial, l_user, p_code);
      l_nmsg := l_nmsg + 1;
      if l_nmsg <= 12 then
        l_list := substrb(l_list || chr(10) || r.trns_id || '/' || r.trns_serial || ': '
                          || case when g_lang = 'E' then p_e else p_a end, 1, 1400);
      end if;
    end add_msg;
  begin
    g_company  := nvl(p_company_code, to_number(v('G_COMPANY_CODE')));
    l_user     := nvl(p_user_code, to_number(v('G_USER_CODE')));
    l_password := nvl(p_password_number, nvl(to_number(v('G_PASSWORD_NUMBER')), -1));
    g_lang     := case when lower(nvl(v('G_LANG'), 'ar')) like 'en%' then 'E' else 'A' end;
    g_count    := 0;
    if g_company is null then
      select min(company_code) into g_company from ac_basic;
    end if;
    -- WHEN-VALIDATE-ITEM messages of the legacy form
    if l_from is null or l_to is null or l_to < l_from then
      err(-20141, 'لابد ان يكون الى تاريخ اقل من من تاريخ', 'Must be To Date Less Than From Date');
    end if;
    if p_from_trns_id is not null and p_to_trns_id is not null and p_to_trns_id < p_from_trns_id then
      err(-20142, 'لابد ان يكون من رقم حركة اقل من الى حركة', 'Must be From Transaction No Less Than To Transaction No');
    end if;
    if p_from_serial is not null and p_to_serial is not null and p_to_serial < p_from_serial then
      err(-20143, 'لابد ان يكون الى مسلسل اكبر من من مسلسل', 'Must be To Serial No More Than From Serial No');
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
      err(-20146, 'لا يوجد حركات يمكن ترحيلها', 'No Transactions Exist for Posting');
    end if;

    delete vn_post_msg where user_code = l_user;

    for i in 1 .. l_rows.count loop
      -- lock the transaction; skip it if a concurrent run posted it meanwhile (not in the legacy form)
      select nvl(post_flag, 0) into l_post
        from vn_maintrns
       where trns_id = l_rows(i).trns_id and trns_serial = l_rows(i).trns_serial
         for update;
      continue when l_post <> 0;

      -- the form passes its IN OUT P_ENTRY_TYPE as the ENTRY_TYPE output of VN_GET_TRNS_DATA
      vn_get_trns_data(l_rows(i).trns_id, l_rows(i).supplier_id, l_rows(i).trns_account, l_rows(i).supplier_account,
                       l_rows(i).disc_account, l_rows(i).cost_code1, l_rows(i).cost_code2,
                       l_trns_account, l_supp_account, l_supp_name_a, l_supp_name_e, l_disc_account, l_curr_account,
                       l_entry_type, l_account_joint, l_cost_no_trns, l_cost_no2_trns, l_cost_no_supp, l_cost_no2_supp,
                       l_effect);
      select cost_no_type, cost_no2_type, cost_flag
        into l_wcost_no_type, l_wcost_no2_type, l_wcost_flag
        from vn_trnstype
       where id = l_rows(i).trns_id;
      -- cost type 6 (salesman): the legacy unit assigns VCOST_CODE / VCOST_CODE2, which are never filled (NULL)
      if l_wcost_no_type = 6 then
        if l_wcost_flag in (1, 4, 5, 7) then l_cost_no_trns := null; end if;
        if l_wcost_flag in (2, 4, 6, 7) then l_cost_no_supp := null; end if;
      end if;
      if l_wcost_no2_type = 6 then
        if l_wcost_flag in (1, 4, 5, 7) then l_cost_no2_trns := null; end if;
        if l_wcost_flag in (2, 4, 6, 7) then l_cost_no2_supp := null; end if;
      end if;
      if l_wcost_no_type = 4 then
        l_v_cost_no_supp := l_cost_no_trns;  l_v_cost_no2_supp := l_cost_no2_trns;
      else
        l_v_cost_no_supp := l_cost_no_supp;  l_v_cost_no2_supp := l_cost_no2_supp;
      end if;

      if l_close < nvl(l_rows(i).acc_post_date, l_rows(i).trns_date) then
        if l_account_joint = 1 then
          if nvl(l_rows(i).pay_method, 0) != 5 then
            -- cash / cheque payments: the legacy form also created RP_TRNS_MAST / CHECK_MAST documents
            -- (INSERT_RP_PC_TRNS). Only reachable when SYS_SYSTEMS 13 or 15 is installed; not ported.
            add_msg(l_rows(i), 'TREASURY POSTING NOT IMPLEMENTED',
                    'حركة نقدية/شيكات: الترحيل مع نظام الخزينة أو البنوك غير منفذ في النظام الجديد',
                    'cash / cheque transaction: posting with the treasury systems is not implemented');
          elsif nvl(l_supp_account, 0) != 0 then
            if nvl(l_effect, 9) in (0, 1) then
              if (nvl(l_rows(i).disc_value, 0) != 0 and nvl(l_disc_account, 0) != 0) or nvl(l_rows(i).disc_value, 0) = 0 then
                begin
                  vn_create_entry_every_one(
                    l_effect,
                    l_trns_account,
                    l_supp_account,
                    l_disc_account,
                    l_curr_account,
                    l_rows(i).total_value * l_rows(i).currency_rate,
                    l_rows(i).disc_value * l_rows(i).currency_rate,
                    nvl(l_rows(i).acc_post_date, l_rows(i).trns_date),
                    l_cost_no_trns, l_cost_no2_trns,
                    l_v_cost_no_supp, l_v_cost_no2_supp,
                    l_rows(i).doc_no,
                    l_rows(i).description_a,
                    l_rows(i).description_e,
                    l_rows(i).trns_memo,
                    l_rows(i).supp_memo,
                    l_rows(i).trns_id, l_rows(i).trns_serial,
                    g_company, l_password, l_user, c_system,
                    l_entry_year, l_entry_type, l_entry_no,
                    2, 1);                                -- P_POST_TYPE, P_PUT_HEADER
                exception when others then
                  err(-20149, 'خطأ أثناء ترحيل الحركة ' || l_rows(i).trns_id || '/' || l_rows(i).trns_serial || ': ' || sqlerrm,
                      'Error while posting transaction ' || l_rows(i).trns_id || '/' || l_rows(i).trns_serial || ': ' || sqlerrm);
                end;
                g_count := g_count + 1;
                l_vouchers.extend;
                l_vouchers(l_vouchers.count) := l_entry_year || '/' || l_entry_type || '/' || l_entry_no;
              end if;
            end if;
          else
            add_msg(l_rows(i), 'SUPP ACCOUNT NULL', 'حساب المورد غير معرف لنوع الحركة', 'supplier account not defined');
          end if;
        else
          add_msg(l_rows(i), 'NOT ACCOUNT_JOINT = 1', 'نوع الحركة غير مرتبط بالحسابات', 'transaction type not linked to the GL');
        end if;
      else
        add_msg(l_rows(i), 'CLOSE_DATE ', 'تقع فى فترة مقفلة', 'lies in a closed period');
      end if;
    end loop;

    -- legacy: VN_POST_MSG not empty -> the messages are shown and nothing is committed
    if l_nmsg > 0 then
      err(-20147, 'لم يتم الترحيل - يوجد ' || l_nmsg || ' حركة لا يمكن ترحيلها:' || l_list,
          'Nothing was posted - ' || l_nmsg || ' transaction(s) cannot be posted:' || l_list);
    end if;
    -- legacy: SUM(AC_YEARLY_TRN_DET.VALUE) of the voucher != 0 -> ROLLBACK + "القيد غير متوازن".
    -- The form tested only the last voucher of the run (V_ENTRY_*); every voucher of the run is tested here.
    for v in 1 .. l_vouchers.count loop
      select nvl(sum(value), 0) into l_total
        from ac_yearly_trn_det
       where entry_year = to_number(regexp_substr(l_vouchers(v), '[^/]+', 1, 1))
         and entry_type = to_number(regexp_substr(l_vouchers(v), '[^/]+', 1, 2))
         and entry_no   = to_number(regexp_substr(l_vouchers(v), '[^/]+', 1, 3));
      if l_total != 0 then
        err(-20148, '!!!القيد غير متوازن (' || l_vouchers(v) || ')', 'Entry Not Balanced!!! (' || l_vouchers(v) || ')');
      end if;
    end loop;
  end post_to_gl;

end app_proc_vn;
/
show errors package body app_proc_vn
