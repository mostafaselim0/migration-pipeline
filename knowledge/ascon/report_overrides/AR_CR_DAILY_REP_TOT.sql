-- AR_CR_DAILY_REP_TOT (AR\FMB\AR_CR_DAILY_REP_TOT_RDF.xml) - salesman visits / collected cheques and transfers
-- (AR_MAINTRNS_DAILY).
-- ORA-00918 fix: CASH_FLAG (and others) exist in CUSTOMER too; every column is qualified with its table.
-- D1 / D2 are character parameters in the RDF (compared to TRNS_DATE with the session date format);
-- they are converted explicitly with TO_DATE(..., 'DD/MM/YYYY') (DD-MM-YYYY is accepted as well).
-- Formula column kept: CHEQUE_STATUS (cf_1formula, uses GET_COUNT_CHEQUE).
select m.doc_no,
       m.trns_date,
       m.total_value,
       m.customer_id,
       c.name_a cust_name,
       m.salesman_id,
       s.name_a sls_name,
       m.cheque_number,
       decode(m.cash_flag, 0, 'شيك', 3, 'حوالة') cash_flag,
       m.bank_code,
       b.name_a bank_name,
       m.chk_date,
       decode(m.trns_status, 0, 'تحت الاجراء', 1, 'معتمده', 2, 'مرفوضه') trns_status,
       m.trns_status_user_code,
       m.trns_status_date,
       m.auth_trns_date,
       m.cash_flag cash_flag_t,
       case when nvl(m.cash_flag, 0) = 0
            then case when nvl(get_count_cheque(m.trns_id, m.mainarea_id, m.subarea_id, m.trns_serial), 0) != 0
                      then 'تم توريد الشيك' else 'الشيك لدى المندوب' end
            else case when m.auth_trns_date is not null
                      then 'تم اعتماد الحوالة' else 'الحوالة لدى المندوب' end
       end cheque_status,
       m.trns_id,
       m.trns_serial,
       m.mainarea_id,
       m.subarea_id
  from ar_maintrns_daily m, customer c, bank b, salesman s
 where m.customer_id = c.code
   and m.bank_code = b.code(+)
   and m.salesman_id = s.code(+)
   and (:C1 is null or m.customer_id >= :C1)
   and (:C2 is null or m.customer_id <= :C2)
   and (:C5 is null or m.mainarea_id >= :C5)
   and (:C5_2 is null or m.mainarea_id <= :C5_2)
   and (:FROM_SALES1 is null or m.supervisor_slsman >= :FROM_SALES1)
   and (:TO_SALES1 is null or m.supervisor_slsman <= :TO_SALES1)
   and (:FROM_CAT is null or m.ctgry_code >= :FROM_CAT)
   and (:TO_CAT is null or m.ctgry_code <= :TO_CAT)
   and (:FROM_SALES is null or m.salesman_id >= :FROM_SALES)
   and (:TO_SALES is null or m.salesman_id <= :TO_SALES)
   and (:P_TRNS_STATUS = 3 or m.trns_status = :P_TRNS_STATUS)
   and (:P_CASH_FLAG = 5 or m.cash_flag = :P_CASH_FLAG)
   and (:D1 is null or m.trns_date >= to_date(:D1, 'DD/MM/YYYY'))
   and (:D2 is null or m.trns_date <= to_date(:D2, 'DD/MM/YYYY'))
