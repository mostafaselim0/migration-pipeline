-- ACSTTM1 (AC\FMB\acsttm1_RDF.xml) - account statement for all accounts.
-- Reports data model: ACCOUNTS -> START_BALANCE (link account_number) -> entries (link account_number).
-- Flattened as acc -> sb (opening balance per account) -> ent (opening row + posted/unposted lines).
-- The parent-column binds :BEGIN_BALANCE / :START_BALANCE_CR are now joins (they caused ORA-01790).
-- Optional filter "post_system in (lexical LEX_POST_SYSTEM) or POST_FLAG = 0" dropped: all posting systems.
-- Formula columns kept: DEBIT_CR / CREDIT_CR (debitformula / creditformula), BALANCE_CR (running summary),
-- COST_DESC / COST2_DESC (cost_descformula / cost2_descformula).
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
     and ab.company_code = :COMPANY_CODE
     and am.account_status = 1
     and (:PASSWORD_NUMBER = 0
          or am.account_number in (select pm.account_number
                                     from ac_password_master pm
                                    where pm.password_number = :PASSWORD_NUMBER
                                      and pm.company_code = :COMPANY_CODE))
),
sb as (
  select x.account_number, nvl(sum(x.start_balance_cr), 0) start_balance_cr
    from (select d.account_number,
                 sum(decode(:REPORT_CURRENCY, 1, d.value * decode(nvl(d.balance_flag, 0), 0, m.rate, 1),
                            decode(m.close_flag, 1, m.close_flag, d.value))) + a.begin_balance start_balance_cr
            from ac_yearly_trn_det d, ac_yearly_trn m, acc a
           where d.entry_no = m.entry_no
             and d.entry_type = m.entry_type
             and d.entry_year = m.entry_year
             and d.account_number = a.account_number
             and (nvl(d.cost_code, 0) >= :FROM_COST or :FROM_COST is null)
             and (nvl(d.cost_code, 0) <= :TO_COST or :TO_COST is null)
             and (nvl(d.cost_code2, 0) >= :FROM_COST2 or :FROM_COST2 is null)
             and (nvl(d.cost_code2, 0) <= :TO_COST2 or :TO_COST2 is null)
             and m.entry_date < :START_DATE
             and (:PASSWORD_NUMBER = 0
                  or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                        from ac_password_entry pe
                                                       where pe.company_code = :COMPANY_CODE
                                                         and pe.password_number = :PASSWORD_NUMBER))
             and (:REPORT_CURRENCY = m.currency_code or nvl(m.close_flag, 0) = 1)
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
             and (nvl(d.cost_code, 0) >= :FROM_COST or :FROM_COST is null)
             and (nvl(d.cost_code, 0) <= :TO_COST or :TO_COST is null)
             and (nvl(d.cost_code2, 0) >= :FROM_COST2 or :FROM_COST2 is null)
             and (nvl(d.cost_code2, 0) <= :TO_COST2 or :TO_COST2 is null)
             and (:PASSWORD_NUMBER = 0
                  or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                        from ac_password_entry pe
                                                       where pe.company_code = :COMPANY_CODE
                                                         and pe.password_number = :PASSWORD_NUMBER))
             and m.entry_date < :START_DATE
             and :REPORT_CURRENCY = m.currency_code
             and :REPORT_CHOICE in (2, 3)
           group by d.account_number, a.begin_balance) x
   group by x.account_number
),
ent as (
  select s.account_number, 1 dummy_for_ordering, cast(:START_DATE as date) entry_date,
         cast(null as varchar2(100)) trn_no, 0 entry_year, 0 entry_type, 0 entry_no,
         decode(:LANG, 'A', 'رصيد أول الفترة', 'Opening Balance') entry_desc,
         0 doc_no, 0 value, 0 rate,
         decode(:LANG, 'A', 'رصيد أول الفترة', 'Opening Balance') memo,
         s.start_balance_cr db_cr_cr, 0 seq, cast(null as varchar2(1)) p_entry_type, 0 cost_code, 0 cost_code2
    from sb s
  union
  select d.account_number, 2, m.entry_date,
         to_char(d.entry_type) || '/' || to_char(d.entry_no),
         d.entry_year, d.entry_type, d.entry_no,
         decode(d.entry_desc, acm.account_name, m.entry_desc, d.entry_desc),
         m.doc_no, abs(d.value), m.rate,
         decode(:LANG, 'A', decode(:MEMO_FLAG, 0, d.entry_desc, decode(d.memo, null, m.entry_desc, d.memo)),
                            decode(:MEMO_FLAG, 0, d.entry_desc_e, decode(d.memo_e, null, m.entry_desc_e, d.memo_e))),
         round(decode(m.close_flag, 1, d.close_value, d.value), 2), d.seq, '*', d.cost_code, d.cost_code2
    from ac_yearly_trn m, ac_yearly_trn_det d, ac_master acm, acc a
   where m.entry_year = d.entry_year
     and m.entry_type = d.entry_type
     and m.entry_no = d.entry_no
     and acm.account_number = d.account_number
     and d.account_number = a.account_number
     and (nvl(d.cost_code, 0) >= :FROM_COST or :FROM_COST is null)
     and (nvl(d.cost_code, 0) <= :TO_COST or :TO_COST is null)
     and (nvl(d.cost_code2, 0) >= :FROM_COST2 or :FROM_COST2 is null)
     and (nvl(d.cost_code2, 0) <= :TO_COST2 or :TO_COST2 is null)
     and (:PASSWORD_NUMBER = 0
          or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                from ac_password_entry pe
                                               where pe.company_code = :COMPANY_CODE
                                                 and pe.password_number = :PASSWORD_NUMBER))
     and m.entry_date between :START_DATE and :END_DATE
     and (:REPORT_CURRENCY = 1 or :REPORT_CURRENCY = acm.currency_code or nvl(m.close_flag, 0) = 1)
     and :REPORT_CHOICE in (1, 3)
  union
  select d.account_number, 2, m.entry_date,
         to_char(d.entry_type) || '/' || to_char(d.entry_no),
         d.entry_year, d.entry_type, d.entry_no,
         decode(:LANG, 'A', d.entry_desc, d.entry_desc_e),
         m.doc_no, abs(d.value), m.rate,
         decode(:LANG, 'A', decode(:MEMO_FLAG, 0, m.entry_desc, decode(d.memo, null, m.entry_desc, d.memo)),
                            decode(:MEMO_FLAG, 0, m.entry_desc_e, decode(d.memo_e, null, m.entry_desc_e, d.memo_e))),
         round(d.value, 2), d.seq, null, d.cost_code, d.cost_code2
    from ac_daily_trn m, ac_daily_trn_det d, ac_master acm, acc a
   where m.entry_year = d.entry_year
     and m.entry_type = d.entry_type
     and m.entry_no = d.entry_no
     and (nvl(d.cost_code, 0) >= :FROM_COST or :FROM_COST is null)
     and (nvl(d.cost_code, 0) <= :TO_COST or :TO_COST is null)
     and (nvl(d.cost_code2, 0) >= :FROM_COST2 or :FROM_COST2 is null)
     and (nvl(d.cost_code2, 0) <= :TO_COST2 or :TO_COST2 is null)
     and (:PASSWORD_NUMBER = 0
          or (m.entry_year, m.entry_type) in (select pe.entry_year, pe.entry_type
                                                from ac_password_entry pe
                                               where pe.company_code = :COMPANY_CODE
                                                 and pe.password_number = :PASSWORD_NUMBER))
     and acm.account_number = d.account_number
     and d.account_number = a.account_number
     and m.entry_date between :START_DATE and :END_DATE
     and (:REPORT_CURRENCY = 1 or :REPORT_CURRENCY = acm.currency_code)
     and :REPORT_CHOICE in (2, 3)
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
                             order by e.dummy_for_ordering, e.entry_date, e.entry_year, e.entry_type, e.entry_no, e.seq
                             rows unbounded preceding) balance_cr,
       e.seq,
       e.p_entry_type,
       e.cost_code,
       decode(:LANG, 'A', c1.cost_desc, c1.cost_desc_e) cost_desc,
       e.cost_code2,
       decode(:LANG, 'A', c2.cost_desc, c2.cost_desc_e) cost2_desc
  from acc a
  left join sb s on s.account_number = a.account_number
  left join ent e on e.account_number = a.account_number
  left join ac_cost_centers c1 on c1.cost_code = e.cost_code
  left join ac_cost_centers2 c2 on c2.cost_code = e.cost_code2
