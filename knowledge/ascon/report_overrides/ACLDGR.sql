-- ACLDGR (AC\FMB\acldgr_RDF.xml) - general ledger: opening balance + monthly debit/credit totals per account.
-- Reports data model: account_rg (password filter) -> ACCOUNTS -> START_BALANCE -> entries (all links on account_number).
-- Flattened as acc -> sb (opening balance per account) -> ent (opening row + monthly totals).
-- The parent-column binds :BEGIN_BALANCE / :START_BALANCE are now joins (they caused ORA-01790).
-- START_BALANCE could return one row per source (posted + unposted); it is summed per account here.
-- Accounts without a START_BALANCE row are skipped, as R_ACCOUNTS (COUNT_ENTRIES > 0) did.
-- As in the RDF, months are grouped by month number only (a range over several years merges the same month).
-- Formula columns kept: DB_CR_CR / DB_CR_SR (db_crformula / db_cr_srformula) and a running BALANCE_CR.
with acc as (
  select am.account_number,
         decode(:LANG, 'A', am.account_name, am.account_name_e) account_name,
         decode(:LANG, 'A', cu.currency_desc, cu.currency_desc_e) currency_desc,
         nvl(decode(ab.current_year, extract(year from cast(:START_DATE as date)),
                    decode(:REPORT_CURRENCY, 1, am.begin_year_loc, am.begin_year_for),
                    decode(:REPORT_CURRENCY, 1, am.begin_period_loc, am.begin_period_for)), 0) begin_balance
    from ac_master am, ac_currency cu, ac_basic ab
   where am.account_number between :FROM_ACCOUNT_NUMBER and :TO_ACCOUNT_NUMBER
     and :REPORT_CURRENCY = am.currency_code
     and am.currency_code = cu.currency_code
     and am.account_status = 1
     and ab.company_code = :COMPANY_CODE
     and (:PASSWORD_NUMBER = 0
          or am.account_number in (select pm.account_number
                                     from ac_password_master pm
                                    where pm.account_number = am.account_number
                                      and pm.password_number = :PASSWORD_NUMBER
                                      and pm.company_code = :COMPANY_CODE))
),
sb as (
  select x.account_number, sum(x.start_balance) start_balance
    from (select d.account_number,
                 sum(d.value * decode(nvl(d.balance_flag, 0), 0, m.rate, 1)) + a.begin_balance start_balance
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
             and (:REPORT_CURRENCY = m.currency_code or nvl(m.close_flag, 0) = 1)
             and (:PASSWORD_NUMBER = 0 or :PASSWORD_NUMBER is null or :COMPANY_CODE is null
                  or m.create_company_code = :COMPANY_CODE)
             and :REPORT_CHOICE in (1, 3)
           group by d.account_number, a.begin_balance
          union
          select a.account_number, a.begin_balance
            from acc a
           where a.account_number not in (select d1.account_number
                                            from ac_yearly_trn_det d1
                                           where d1.entry_date < :START_DATE
                                             and :REPORT_CHOICE in (1, 3)
                                          union
                                          select d2.account_number
                                            from ac_daily_trn_det d2, ac_daily_trn m2
                                           where d2.entry_no = m2.entry_no
                                             and d2.entry_type = m2.entry_type
                                             and d2.entry_year = m2.entry_year
                                             and m2.entry_date < :START_DATE
                                             and :REPORT_CHOICE in (1, 3))
          union
          select d.account_number,
                 sum(d.value * decode(nvl(d.balance_flag, 0), 0, m.rate, 1)) + a.begin_balance
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
             and (:PASSWORD_NUMBER = 0 or :PASSWORD_NUMBER is null or :COMPANY_CODE is null
                  or m.create_company_code = :COMPANY_CODE)
             and :REPORT_CHOICE in (2, 3)
           group by d.account_number, a.begin_balance) x
   group by x.account_number
),
mon as (
  select 2 dummy_order,
         d.account_number,
         to_number(to_char(m.entry_date, 'mm')) month_order,
         sum(round(decode(m.close_flag, 1, decode(sign(d.close_value), 1, d.close_value, 0),
                                           decode(sign(d.value), 1, d.value, 0)), 2)) debit_cr,
         sum(round(decode(m.close_flag, 1, decode(sign(d.close_value), -1, -d.close_value, 0),
                                           decode(sign(d.value), -1, -d.value, 0)), 2)) credit_cr,
         sum(round(decode(nvl(d.balance_flag, 0), 1, decode(sign(d.value), 1, d.value, 0),
                          decode(m.currency_code, 1, decode(sign(d.value), 1, d.value, 0),
                                 decode(sign(d.value), 1, d.value, 0) * m.rate)), 2)) debit_sr,
         sum(round(decode(nvl(d.balance_flag, 0), 1, decode(sign(d.value), -1, -d.value, 0),
                          decode(m.currency_code, 1, decode(sign(d.value), -1, -d.value, 0),
                                 decode(sign(d.value), -1, -d.value, 0) * m.rate)), 2)) credit_sr
    from ac_yearly_trn m, ac_yearly_trn_det d, ac_master acm, acc a
   where m.entry_year = d.entry_year
     and m.entry_type = d.entry_type
     and m.entry_no = d.entry_no
     and acm.account_number = d.account_number
     and d.account_number = a.account_number
     and (:PASSWORD_NUMBER = 0
          or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                from ac_password_entry pe
                                               where pe.company_code = :COMPANY_CODE
                                                 and pe.password_number = :PASSWORD_NUMBER))
     and d.entry_date between :START_DATE and :END_DATE
     and (:REPORT_CURRENCY = 1 or :REPORT_CURRENCY = acm.currency_code or nvl(m.close_flag, 0) = 1)
     and (:PASSWORD_NUMBER = 0 or :PASSWORD_NUMBER is null or :COMPANY_CODE is null
          or m.create_company_code = :COMPANY_CODE)
     and :REPORT_CHOICE in (1, 3)
   group by d.account_number, to_number(to_char(m.entry_date, 'mm'))
  union
  select 3,
         d.account_number,
         to_number(to_char(m.entry_date, 'mm')),
         sum(round(decode(sign(d.value), 1, d.value, 0), 2)),
         sum(round(decode(sign(d.value), -1, -d.value, 0), 2)),
         sum(round(decode(nvl(d.balance_flag, 0), 1, decode(sign(d.value), 1, d.value, 0),
                          decode(m.currency_code, 1, decode(sign(d.value), 1, d.value, 0),
                                 decode(sign(d.value), 1, d.value, 0) * m.rate)), 2)),
         sum(round(decode(nvl(d.balance_flag, 0), 1, decode(sign(d.value), -1, -d.value, 0),
                          decode(m.currency_code, 1, decode(sign(d.value), -1, -d.value, 0),
                                 decode(sign(d.value), -1, -d.value, 0) * m.rate)), 2))
    from ac_daily_trn m, ac_daily_trn_det d, ac_master acm, acc a
   where m.entry_year = d.entry_year
     and m.entry_type = d.entry_type
     and m.entry_no = d.entry_no
     and (:PASSWORD_NUMBER = 0
          or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                from ac_password_entry pe
                                               where pe.company_code = :COMPANY_CODE
                                                 and pe.password_number = :PASSWORD_NUMBER))
     and acm.account_number = d.account_number
     and d.account_number = a.account_number
     and m.entry_date between :START_DATE and :END_DATE
     and (:REPORT_CURRENCY = 1 or :REPORT_CURRENCY = acm.currency_code)
     and (:PASSWORD_NUMBER = 0 or :PASSWORD_NUMBER is null or :COMPANY_CODE is null
          or m.create_company_code = :COMPANY_CODE)
     and :REPORT_CHOICE in (2, 3)
   group by d.account_number, to_number(to_char(m.entry_date, 'mm'))
),
ent as (
  select 1 dummy_order,
         s.account_number,
         0 month_order,
         decode(:LANG, 'A', 'رصيد يوم', 'Opening Balance') || to_char(cast(:START_DATE as date), 'yyyy/mm/dd') month,
         decode(sign(s.start_balance), 1, s.start_balance, 0) debit_cr,
         decode(sign(s.start_balance), -1, -s.start_balance, 0) credit_cr,
         decode(sign(s.start_balance), 1, s.start_balance, 0) debit_sr,
         decode(sign(s.start_balance), -1, -s.start_balance, 0) credit_sr
    from sb s
  union
  select 2,
         x.account_number,
         x.month_order,
         case when :LANG = 'A'
              then decode(x.month_order, 1, 'يناير', 2, 'فبراير', 3, 'مارس', 4, 'ابريل', 5, 'مايو', 6, 'يونيو',
                                         7, 'يوليو', 8, 'أغسطس', 9, 'سبتمبر', 10, 'أكتوبر', 11, 'نوفمبر', 12, 'ديسمبر')
              else decode(x.month_order, 1, 'January', 2, 'February', 3, 'March', 4, 'April', 5, 'May', 6, 'June',
                                         7, 'July', 8, 'August', 9, 'September', 10, 'October', 11, 'November', 12, 'December')
         end,
         sum(x.debit_cr), sum(x.credit_cr), sum(x.debit_sr), sum(x.credit_sr)
    from mon x
   group by x.account_number, x.month_order
)
select a.account_number,
       a.account_name,
       a.currency_desc,
       a.begin_balance,
       s.start_balance,
       e.dummy_order,
       e.month_order,
       e.month month_name,
       e.debit_cr,
       e.credit_cr,
       e.debit_cr - e.credit_cr db_cr_cr,
       sum(e.debit_cr - e.credit_cr) over (partition by a.account_number order by e.dummy_order, e.month_order
                                           rows unbounded preceding) balance_cr,
       e.debit_sr,
       e.credit_sr,
       e.debit_sr - e.credit_sr db_cr_sr
  from acc a
  join sb s on s.account_number = a.account_number
  join ent e on e.account_number = a.account_number
