-- AR_SANAD_NEW (AR\FMB\AR_SANAD_NEW_RDF.xml) - collector (receipt voucher) documents statement.
-- ORA-00918 fix: M.DOC_NO was selected twice; the second one is DOC_NO1 as in the Reports group.
-- Groups G_CUSTOMER_ID (receipt) -> G_BILL_ID1 (settled invoices, outer-joined AR_SUBTRNS) are one query.
-- Formula columns kept: CUSTOMER_NAME, SUB_NAME_A (AR_SUBAREA name).
select m.customer_id,
       decode(:LANG, 'A', cu.name_a, cu.name_e) customer_name,
       m.mainarea_id,
       m.subarea_id,
       decode(:LANG, 'A', sa.name_a, sa.name_e) sub_name_a,
       m.trns_id,
       m.trns_serial,
       m.doc_no,
       m.doc_no doc_no1,
       m.trns_date,
       m.cheque_number,
       m.total_value inv_value,
       s.bill_id1,
       s.bill_id2,
       s.inv_date,
       s.total_value det_inv_value,
       s.disc_value
  from ar_subtrns s, ar_maintrns m, customer cu, ar_subarea sa
 where s.trns_id(+) = m.trns_id
   and s.mainarea_id(+) = m.mainarea_id
   and s.subarea_id(+) = m.subarea_id
   and s.trns_serial(+) = m.trns_serial
   and cu.code(+) = m.customer_id
   and sa.main_id(+) = m.mainarea_id
   and sa.id(+) = m.subarea_id
   and (m.trns_id >= :FROM_TRNS_ID or :FROM_TRNS_ID is null)
   and (m.trns_id <= :TO_TRNS_ID or :TO_TRNS_ID is null)
   and (m.mainarea_id >= :FROM_MAINAREA_ID or :FROM_MAINAREA_ID is null)
   and (m.mainarea_id <= :TO_MAINAREA_ID or :TO_MAINAREA_ID is null)
   and (m.subarea_id >= :FROM_SUBAREA_ID or :FROM_SUBAREA_ID is null)
   and (m.subarea_id <= :TO_SUBAREA_ID or :TO_SUBAREA_ID is null)
   and (m.salesman_id >= :C3 or :C3 is null)
   and (m.salesman_id <= :C4 or :C4 is null)
   and (m.cheque_number >= :FROM_CHK_NO or :FROM_CHK_NO is null)
   and (m.cheque_number <= :TO_CHK_NO or :TO_CHK_NO is null)
   and (m.trns_serial >= :FROM_TRNS_SERIAL or :FROM_TRNS_SERIAL is null)
   and (m.trns_serial <= :TO_TRNS_SERIAL or :TO_TRNS_SERIAL is null)
   and (m.trns_date >= :FROM_DATE or :FROM_DATE is null)
   and (m.trns_date <= :TO_DATE or :TO_DATE is null)
   and m.trns_id in (select t.id from ar_trnstype t where t.effect = 1 and t.trns_type <> 6)
   and m.trns_serial_tot is null
   and nvl(m.link_flag, 0) = 0
   and (:P_PASSWORD_NUMBER = 0
        or m.trns_id in (select tp.trns_id from ar_trnstype_password tp
                          where tp.flag = 1 and tp.password_number = :P_PASSWORD_NUMBER))
   and (:P_PASSWORD_NUMBER = 0
        or (m.customer_id >= (select cp.from_customer_code from ar_customer_password cp
                               where cp.password_number = :P_PASSWORD_NUMBER)
            and m.customer_id <= (select cp.to_customer_code from ar_customer_password cp
                                   where cp.password_number = :P_PASSWORD_NUMBER)))
