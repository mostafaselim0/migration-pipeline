-- ACSTTM2 (AC\FMB\acsttm2_RDF.xml) - account statement for accounts that have a balance.
-- Reports data model: ACCOUNTS -> START_BALANCE (link account_number) -> entries (link account_number).
-- Flattened as acc -> sb (opening balance per account) -> ent (opening row + posted/unposted lines).
-- The parent-column binds :BEGIN_BALANCE / :START_BALANCE_CR are now joins (they caused ORA-01790).
-- Optional filter "post_system in (lexical LEX_POST_SYSTEM) or POST_FLAG = 0" dropped: all posting systems.
-- R_ACCOUNTS format trigger (hide accounts whose CS_BALANCE_CR = 0) is applied as the final filter.
-- Formula columns kept: DEBIT_CR / CREDIT_CR, BALANCE_CR (running), P_ENTRY_TYPE ('*' = posted, CF_1).
with acc as (
  select am.account_number,
         decode(:LANG, 'A', am.account_name, am.account_name_e) account_name,
         decode(:LANG, 'A', cu.currency_desc, cu.currency_desc_e) currency_desc,
         nvl(decode(ab.current_year, extract(year from cast(:START_DATE as date)),
                    decode(:REPORT_CURRENCY, 1, am.begin_year_loc, am.begin_year_for),
                    decode(:REPORT_CURRENCY, 1, am.begin_period_loc, am.begin_period_for)), 0) begin_balance
    from ac_master am, ac_currency cu, ac_basic ab
   where am.account_number between :FROM_ACCOUNT_NUMBER and :TO_ACCOUNT_NUMBER
     and am.currency_code = :REPORT_CURRENCY
     and am.currency_code = cu.currency_code
     and ab.company_code = :COMPANY_CODE
     and am.account_status = 1
),
sb as (
  select x.account_number, sum(x.start_balance_cr) start_balance_cr
    from (select d.account_number,
                 sum(decode(:REPORT_CURRENCY, 1, d.value * decode(nvl(d.balance_flag, 0), 0, m.rate, 1),
                            decode(m.close_flag, 1, m.close_flag, d.value))) + a.begin_balance start_balance_cr
            from ac_yearly_trn_det d, ac_yearly_trn m, acc a
           where d.entry_no = m.entry_no
             and d.entry_type = m.entry_type
             and d.entry_date = m.entry_date
             and d.account_number = a.account_number
             and d.entry_date < :START_DATE
             and (:REPORT_CURRENCY = m.currency_code or nvl(m.close_flag, 0) = 1)
             and ((:PASSWORD_NUMBER = 0 or :PASSWORD_NUMBER is null or :COMPANY_CODE is null)
                  or (m.create_company_code = :COMPANY_CODE and m.create_password_number = :PASSWORD_NUMBER))
             and :REPORT_CHOICE in (1, 3)
           group by d.account_number, a.begin_balance
          union
          select a.account_number, a.begin_balance
            from acc a
          union
          select d.account_number,
                 sum(decode(:REPORT_CURRENCY, 1, d.value * decode(nvl(d.balance_flag, 0), 0, m.rate, 1), d.value))
                 + a.begin_balance
            from ac_daily_trn_det d, ac_daily_trn m, acc a
           where d.entry_no = m.entry_no
             and d.entry_type = m.entry_type
             and d.entry_year = m.entry_year
             and d.account_number = a.account_number
             and m.entry_date < :START_DATE
             and :REPORT_CURRENCY = m.currency_code
             and ((:PASSWORD_NUMBER = 0 or :PASSWORD_NUMBER is null or :COMPANY_CODE is null)
                  or (m.create_company_code = :COMPANY_CODE and m.create_password_number = :PASSWORD_NUMBER))
             and :REPORT_CHOICE in (2, 3)
           group by d.account_number, a.begin_balance) x
   group by x.account_number
),
ent as (
  select s.account_number, 1 dummy_for_ordering, cast(:START_DATE as date) entry_date,
         cast(null as varchar2(100)) trn_no, 0 entry_year, 0 entry_type, 0 entry_no,
         'رصيد أول الفترة' entry_desc,
         0 doc_no, 0 value, 0 rate,
         decode(:LANG, 'A', 'رصيد أول الفترة', 'Opening Balance') memo,
         s.start_balance_cr db_cr_cr, 0 seq, 0 posted
    from sb s
  union
  select d.account_number, 2, m.entry_date,
         to_char(d.entry_type) || '/' || to_char(d.entry_no),
         d.entry_year, d.entry_type, d.entry_no,
         decode(d.entry_desc, acm.account_name, m.entry_desc, d.entry_desc),
         m.doc_no, abs(d.value), m.rate,
         decode(:LANG, 'A', decode(:MEMO_FLAG, 0, m.entry_desc, m.entry_desc || d.memo),
                            decode(:MEMO_FLAG, 0, m.entry_desc_e, m.entry_desc_e || d.memo_e)),
         round(decode(m.close_flag, 1, d.close_value, d.value), 2), d.seq, 1
    from ac_yearly_trn m, ac_yearly_trn_det d, ac_master acm, acc a
   where m.entry_year = d.entry_year
     and m.entry_type = d.entry_type
     and m.entry_no = d.entry_no
     and acm.account_number = d.account_number
     and d.account_number = a.account_number
     and m.entry_date between :START_DATE and :END_DATE
     and (:REPORT_CURRENCY = 1 or :REPORT_CURRENCY = acm.currency_code or nvl(m.close_flag, 0) = 1)
     and ((:PASSWORD_NUMBER = 0 or :PASSWORD_NUMBER is null or :COMPANY_CODE is null)
          or (m.create_company_code = :COMPANY_CODE and m.create_password_number = :PASSWORD_NUMBER))
     and :REPORT_CHOICE in (1, 3)
  union
  select d.account_number, 2, m.entry_date,
         to_char(d.entry_type) || '/' || to_char(d.entry_no),
         d.entry_year, d.entry_type, d.entry_no,
         d.entry_desc,
         m.doc_no, abs(d.value), m.rate,
         decode(:LANG, 'A', d.memo, d.memo_e),
         round(d.value, 2), d.seq, 0
    from ac_daily_trn m, ac_daily_trn_det d, ac_master acm, acc a
   where m.entry_year = d.entry_year
     and m.entry_type = d.entry_type
     and m.entry_no = d.entry_no
     and acm.account_number = d.account_number
     and d.account_number = a.account_number
     and m.entry_date between :START_DATE and :END_DATE
     and (:REPORT_CURRENCY = 1 or :REPORT_CURRENCY = acm.currency_code)
     and ((:PASSWORD_NUMBER = 0 or :PASSWORD_NUMBER is null or :COMPANY_CODE is null)
          or (m.create_company_code = :COMPANY_CODE and m.create_password_number = :PASSWORD_NUMBER))
     and :REPORT_CHOICE in (2, 3)
),
res as (
  select a.account_number,
         a.account_name,
         a.currency_desc,
         a.begin_balance,
         s.start_balance_cr,
         e.dummy_for_ordering,
         e.entry_date,
         e.trn_no,
         e.entry_year,
         e.entry_type,
         e.entry_no,
         e.entry_desc,
         e.doc_no,
         e.value,
         e.rate,
         e.memo,
         e.db_cr_cr,
         case when e.db_cr_cr >= 0 then e.db_cr_cr end debit_cr,
         case when e.db_cr_cr < 0 then -e.db_cr_cr end credit_cr,
         sum(e.db_cr_cr) over (partition by a.account_number
                               order by e.dummy_for_ordering, e.entry_date, e.entry_year, e.entry_type desc, e.entry_no, e.seq
                               rows unbounded preceding) balance_cr,
         sum(e.db_cr_cr) over (partition by a.account_number) account_balance_cr,
         e.seq,
         case when e.posted = 1 then '*' end p_entry_type
    from acc a
    left join sb s on s.account_number = a.account_number
    left join ent e on e.account_number = a.account_number
)
select account_number, account_name, currency_desc, begin_balance, start_balance_cr, dummy_for_ordering,
       entry_date, trn_no, entry_year, entry_type, entry_no, entry_desc, doc_no, value, rate, memo,
       db_cr_cr, debit_cr, credit_cr, balance_cr, account_balance_cr, seq, p_entry_type
  from res
 where nvl(account_balance_cr, 0) <> 0
