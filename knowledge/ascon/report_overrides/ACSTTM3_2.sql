-- ACSTTM3_2 (AC\FMB\acsttm3_2_RDF.xml) - account statement by cost center 2 (:COST_CODE = cost_code2).
-- Reports data model: ACCOUNTS -> START_BALANCE (link account_number) -> entries (link account_number).
-- Flattened as acc -> sb (opening balance per account) -> ent (opening row + posted/unposted lines).
-- The parent-column binds :BEGIN_BALANCE / :START_BALANCE_CR are now joins (they caused ORA-01790).
-- Optional filter "post_system in (lexical LEX_POST_SYSTEM) or POST_FLAG = 0" dropped: all posting systems.
-- Formula columns kept: DEBIT_CR / CREDIT_CR, BALANCE_CR (running), TRNS_TYPE_NAME (trns_type_nameformula).
with acc as (
  select am.account_number,
         am.account_name,
         cu.currency_desc,
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
             and (:PASSWORD_NUMBER = 0
                  or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                        from ac_password_entry pe
                                                       where pe.company_code = :COMPANY_CODE
                                                         and pe.password_number = :PASSWORD_NUMBER))
             and ((:PASSWORD_NUMBER = 0 or :PASSWORD_NUMBER is null or :COMPANY_CODE is null)
                  or m.create_company_code = :COMPANY_CODE)
             and :REPORT_CHOICE in (1, 3)
             and (d.cost_code2 = :COST_CODE or :COST_CODE is null)
           group by d.account_number, a.begin_balance
          union
          select a.account_number, a.begin_balance
            from acc a
           where not exists (select 1
                               from ac_yearly_trn_det d1
                              where d1.entry_date < :START_DATE
                                and (d1.cost_code2 = :COST_CODE or :COST_CODE is null)
                                and d1.account_number = a.account_number)
             and not exists (select 1
                               from ac_daily_trn_det d2, ac_daily_trn m2
                              where m2.entry_date < :START_DATE
                                and (d2.cost_code2 = :COST_CODE or :COST_CODE is null)
                                and d2.account_number = a.account_number
                                and d2.entry_no = m2.entry_no
                                and d2.entry_type = m2.entry_type
                                and d2.entry_year = m2.entry_year)
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
             and (:PASSWORD_NUMBER = 0
                  or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                        from ac_password_entry pe
                                                       where pe.company_code = :COMPANY_CODE
                                                         and pe.password_number = :PASSWORD_NUMBER))
             and ((:PASSWORD_NUMBER = 0 or :PASSWORD_NUMBER is null or :COMPANY_CODE is null)
                  or (m.create_company_code = :COMPANY_CODE and m.create_password_number = :PASSWORD_NUMBER))
             and :REPORT_CHOICE in (2, 3)
             and (d.cost_code2 = :COST_CODE or :COST_CODE is null)
           group by d.account_number, a.begin_balance) x
   group by x.account_number
),
ent as (
  select s.account_number, 1 dummy_for_ordering, cast(:START_DATE as date) entry_date,
         cast(null as varchar2(100)) trn_no, 0 entry_year, 0 entry_type, 0 entry_no,
         'رصيد أول الفترة' entry_desc,
         0 doc_no, 0 value, 0 rate,
         'رصيد أول الفترة' memo,
         s.start_balance_cr db_cr_cr, 0 seq, cast(null as varchar2(500)) cost_name
    from sb s
   where :HIDE_OPEN_BAL = 0
  union
  select d.account_number, 2, m.entry_date,
         to_char(d.entry_type) || '/' || to_char(d.entry_no),
         d.entry_year, d.entry_type, d.entry_no,
         decode(d.entry_desc, acm.account_name, m.entry_desc, d.entry_desc),
         m.doc_no, abs(d.value), m.rate,
         decode(:MEMO_FLAG, 0, d.entry_desc, decode(d.memo, null, m.entry_desc, d.memo)),
         round(decode(m.close_flag, 1, d.close_value, d.value), 2), d.seq,
         decode(:LANG, 'E', c1.cost_desc_e, c1.cost_desc)
    from ac_yearly_trn m, ac_yearly_trn_det d, ac_master acm, ac_cost_centers c1, acc a
   where m.entry_year = d.entry_year
     and m.entry_type = d.entry_type
     and m.entry_no = d.entry_no
     and acm.account_number = d.account_number
     and d.account_number = a.account_number
     and m.entry_date between :START_DATE and :END_DATE
     and d.cost_code = c1.cost_code(+)
     and (:PASSWORD_NUMBER = 0
          or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                from ac_password_entry pe
                                               where pe.company_code = :COMPANY_CODE
                                                 and pe.password_number = :PASSWORD_NUMBER))
     and (:REPORT_CURRENCY = 1 or :REPORT_CURRENCY = acm.currency_code or nvl(m.close_flag, 0) = 1)
     and ((:PASSWORD_NUMBER = 0 or :PASSWORD_NUMBER is null or :COMPANY_CODE is null)
          or m.create_company_code = :COMPANY_CODE)
     and :REPORT_CHOICE in (1, 3)
     and (d.cost_code2 = :COST_CODE or :COST_CODE is null)
  union
  select d.account_number, 3, m.entry_date,
         to_char(d.entry_type) || '/' || to_char(d.entry_no),
         d.entry_year, d.entry_type, d.entry_no,
         d.entry_desc,
         m.doc_no, abs(d.value), m.rate,
         d.memo,
         round(d.value, 2), d.seq,
         decode(:LANG, 'E', c1.cost_desc_e, c1.cost_desc)
    from ac_daily_trn m, ac_daily_trn_det d, ac_master acm, ac_cost_centers c1, acc a
   where m.entry_year = d.entry_year
     and m.entry_type = d.entry_type
     and m.entry_no = d.entry_no
     and acm.account_number = d.account_number
     and d.account_number = a.account_number
     and m.entry_date between :START_DATE and :END_DATE
     and d.cost_code = c1.cost_code(+)
     and (:PASSWORD_NUMBER = 0
          or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                from ac_password_entry pe
                                               where pe.company_code = :COMPANY_CODE
                                                 and pe.password_number = :PASSWORD_NUMBER))
     and (:REPORT_CURRENCY = 1 or :REPORT_CURRENCY = acm.currency_code)
     and ((:PASSWORD_NUMBER = 0 or :PASSWORD_NUMBER is null or :COMPANY_CODE is null)
          or m.create_company_code = :COMPANY_CODE)
     and :REPORT_CHOICE in (2, 3)
     and (d.cost_code2 = :COST_CODE or :COST_CODE is null)
)
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
       tc.entry_desc trns_type_name,
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
                             order by e.entry_date, e.dummy_for_ordering, e.entry_year, e.entry_type desc, e.entry_no, e.seq
                             rows unbounded preceding) balance_cr,
       e.seq,
       e.cost_name
  from acc a
  left join sb s on s.account_number = a.account_number
  left join ent e on e.account_number = a.account_number
  left join ac_trn_codes tc on tc.entry_year = e.entry_year and tc.entry_type = e.entry_type
