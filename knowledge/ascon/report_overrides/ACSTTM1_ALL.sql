-- ACSTTM1_ALL (AC\FMB\acsttm1_ALL_RDF.xml) - grouped account statement: the accounts chosen in the
-- parameter form are merged into one statement (Reports used the constant account_number 1 for all).
-- The lexical account list "account_number IN (&LEX_ACC_NO)" is now the bind :LEX_ACC_NO split on ',' or ':'
-- (comma list as the old form built it, or an APEX multi-select value).
-- Header: ACCOUNTS returned DISTINCT (1, currency, begin balance); here one row with the summed begin balance.
-- Flattened as hdr -> sb (opening balance) -> ent (opening row + posted/unposted lines of the chosen accounts).
-- Optional filter "post_system in (lexical LEX_POST_SYSTEM) or POST_FLAG = 0" dropped: all posting systems.
-- Added per-line ENTRY_ACCOUNT_NUMBER / ENTRY_ACCOUNT_NAME so the merged lines can be told apart.
with sel as (
  select to_number(trim(regexp_substr(:LEX_ACC_NO, '[^,:]+', 1, level)) default null on conversion error) account_number
    from dual
 connect by level <= regexp_count(:LEX_ACC_NO, '[^,:]+')
),
hdr as (
  select 1 account_number,
         max(decode(:LANG, 'A', cu.currency_desc, cu.currency_desc_e)) currency_desc,
         sum(nvl(decode(ab.current_year, extract(year from cast(:START_DATE as date)),
                        decode(:REPORT_CURRENCY, 1, am.begin_year_loc, am.begin_year_for),
                        decode(:REPORT_CURRENCY, 1, am.begin_period_loc, am.begin_period_for)), 0)) begin_balance
    from ac_master am, ac_currency cu, ac_basic ab
   where am.account_number in (select s.account_number from sel s)
     and :REPORT_CURRENCY = am.currency_code
     and am.currency_code = cu.currency_code
     and ab.company_code = :COMPANY_CODE
     and am.account_status = 1
   group by am.currency_code
),
sb as (
  select 1 account_number, nvl(sum(x.start_balance_cr), 0) start_balance_cr
    from (select 1 account_number1,
                 sum(decode(:REPORT_CURRENCY, 1, d.value * decode(nvl(d.balance_flag, 0), 0, m.rate, 1),
                            decode(m.close_flag, 1, m.close_flag, d.value))) + max(h.begin_balance) start_balance_cr
            from ac_yearly_trn_det d, ac_yearly_trn m, hdr h
           where d.entry_no = m.entry_no
             and d.entry_type = m.entry_type
             and d.entry_date = m.entry_date
             and d.entry_date < :START_DATE
             and d.account_number in (select s.account_number from sel s)
             and (:PASSWORD_NUMBER = 0
                  or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                        from ac_password_entry pe
                                                       where pe.company_code = :COMPANY_CODE
                                                         and pe.password_number = :PASSWORD_NUMBER))
             and (:REPORT_CURRENCY = m.currency_code or nvl(m.close_flag, 0) = 1)
             and :REPORT_CHOICE in (1, 3)
           group by 1
          union
          select 1, 0
            from dual
          union
          select 1,
                 sum(decode(:REPORT_CURRENCY, 1, d.value * decode(nvl(d.balance_flag, 0), 0, m.rate, 1), d.value))
                 + max(h.begin_balance)
            from ac_daily_trn_det d, ac_daily_trn m, hdr h
           where d.entry_no = m.entry_no
             and d.entry_type = m.entry_type
             and d.entry_year = m.entry_year
             and d.account_number in (select s.account_number from sel s)
             and (:PASSWORD_NUMBER = 0
                  or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                        from ac_password_entry pe
                                                       where pe.company_code = :COMPANY_CODE
                                                         and pe.password_number = :PASSWORD_NUMBER))
             and m.entry_date < :START_DATE
             and :REPORT_CURRENCY = m.currency_code
             and :REPORT_CHOICE in (2, 3)
           group by 1) x
),
ent as (
  select 1 dummy_for_ordering, cast(:START_DATE as date) entry_date,
         cast(null as varchar2(100)) trn_no, 0 entry_year, 0 entry_type, 0 entry_no,
         cast(null as number) entry_account_number,
         decode(:LANG, 'A', 'رصيد أول الفترة', 'Opening Balance') entry_desc,
         0 doc_no, 0 value, 0 rate,
         decode(:LANG, 'A', 'رصيد أول الفترة', 'Opening Balance') memo,
         s.start_balance_cr db_cr_cr, 0 seq, cast(null as varchar2(1)) p_type
    from sb s
  union
  select 2, m.entry_date,
         to_char(d.entry_type) || '/' || to_char(d.entry_no),
         d.entry_year, d.entry_type, d.entry_no, d.account_number,
         decode(:LANG, 'A', decode(d.entry_desc, acm.account_name, m.entry_desc, d.entry_desc),
                            decode(d.entry_desc_e, acm.account_name_e, m.entry_desc_e, d.entry_desc_e)),
         m.doc_no, abs(d.value), m.rate,
         decode(:LANG, 'A', decode(:MEMO_FLAG, 0, m.entry_desc, decode(d.memo, null, m.entry_desc, d.memo)),
                            decode(:MEMO_FLAG, 0, m.entry_desc_e, decode(d.memo_e, null, m.entry_desc_e, d.memo_e))),
         round(decode(m.close_flag, 1, d.close_value, d.value), 2), d.seq, '*'
    from ac_yearly_trn m, ac_yearly_trn_det d, ac_master acm
   where m.entry_year = d.entry_year
     and m.entry_type = d.entry_type
     and m.entry_no = d.entry_no
     and acm.account_number = d.account_number
     and d.account_number in (select s.account_number from sel s)
     and (:PASSWORD_NUMBER = 0
          or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                from ac_password_entry pe
                                               where pe.company_code = :COMPANY_CODE
                                                 and pe.password_number = :PASSWORD_NUMBER))
     and m.entry_date between :START_DATE and :END_DATE
     and (:REPORT_CURRENCY = 1 or :REPORT_CURRENCY = acm.currency_code or nvl(m.close_flag, 0) = 1)
     and :REPORT_CHOICE in (1, 3)
  union
  select 2, m.entry_date,
         to_char(d.entry_type) || '/' || to_char(d.entry_no),
         d.entry_year, d.entry_type, d.entry_no, d.account_number,
         decode(:LANG, 'A', d.entry_desc, d.entry_desc_e),
         m.doc_no, abs(d.value), m.rate,
         decode(:LANG, 'A', decode(:MEMO_FLAG, 0, m.entry_desc, decode(d.memo, null, m.entry_desc, d.memo)),
                            decode(:MEMO_FLAG, 0, m.entry_desc_e, decode(d.memo_e, null, m.entry_desc_e, d.memo_e))),
         round(d.value, 2), d.seq, null
    from ac_daily_trn m, ac_daily_trn_det d, ac_master acm
   where m.entry_year = d.entry_year
     and m.entry_type = d.entry_type
     and m.entry_no = d.entry_no
     and d.account_number in (select s.account_number from sel s)
     and (:PASSWORD_NUMBER = 0
          or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                from ac_password_entry pe
                                               where pe.company_code = :COMPANY_CODE
                                                 and pe.password_number = :PASSWORD_NUMBER))
     and acm.account_number = d.account_number
     and m.entry_date between :START_DATE and :END_DATE
     and (:REPORT_CURRENCY = 1 or :REPORT_CURRENCY = acm.currency_code)
     and :REPORT_CHOICE in (2, 3)
)
select h.account_number,
       h.currency_desc,
       h.begin_balance,
       s.start_balance_cr,
       e.dummy_for_ordering,
       e.entry_date,
       e.trn_no,
       e.entry_year,
       e.entry_type,
       e.entry_no,
       e.entry_account_number,
       decode(:LANG, 'A', ea.account_name, ea.account_name_e) entry_account_name,
       e.entry_desc,
       e.doc_no,
       e.value,
       e.rate,
       e.memo,
       e.db_cr_cr,
       case when e.db_cr_cr >= 0 then e.db_cr_cr end debit_cr,
       case when e.db_cr_cr < 0 then -e.db_cr_cr end credit_cr,
       sum(e.db_cr_cr) over (order by e.dummy_for_ordering, e.entry_date, e.entry_year, e.entry_type, e.entry_no,
                                      e.entry_account_number, e.seq
                             rows unbounded preceding) balance_cr,
       e.seq,
       e.p_type
  from hdr h
  left join sb s on s.account_number = h.account_number
  left join ent e on 1 = 1
  left join ac_master ea on ea.account_number = e.entry_account_number
