-- AR_STTM (AR\FMB\AR_Sttm_RDF.xml) - customer statement with running balance.
-- Main data = Q_1 (payments, grouped payments, invoices, invoice discounts, opening row, unposted sales /
-- returns invoices and services from ST). Q_3 (open-invoice ageing, linked on CODE) is a sibling detail of
-- the customer group, not of the statement lines; joining it would multiply the lines, so it is not included.
-- ORA-00918 fix: the second INVOICE_NO (to_number('')) is INVOICE_NO1 as in the Reports group; typed NULLs
-- (RTV_CUSTOMER, INVOICE_NO1 are VARCHAR2 now) and :D1 - 1 cast to DATE so the UNION branches agree.
-- Optional filters "(:LEX_CUST = '0' OR customer IN (&LEX_CUST))" / LEX_CUST2 dropped (no customer list filter).
-- Grouped branches compute DECODE(:CONT_FLAG, ...) in an inline view and group by its alias.
-- Formula columns kept: CUSTOMER_NAME, OPENING_BALANCE (CF_beg_bal_dynamic), MAIN/SUB_AREA_NAME,
-- CF_INV_NO, CF_DESC, CF_DEBIT / CF_CREDIT, CURR_BAL (opening + running CR_DB) and CF_CR_DB_FLAG.
with q as (
  select decode(:CONT_FLAG, 0, c.code, c.attr_code) code,
         m.trns_date,
         decode(:LANG, 'A', m.description_a, m.description_e) description_a,
         m.trns_id,
         m.doc_no,
         m.trns_serial,
         -m.total_value cr_db,
         c.mainarea_id,
         c.subarea_id,
         0 disc_flag,
         0 bill_id1,
         0 bill_id2,
         t.effect,
         m.trns_id || '/' || m.trns_serial doc_no2,
         0 || 0 invoice_no,
         0 s_tab,
         m.acc_no,
         m.acc_type,
         m.acc_year,
         m.rtv_customer,
         cast(null as varchar2(100)) invoice_no1
    from customer c, ar_maintrns m, ar_trnstype t, ar_cust_salesman m1, salesman s
   where m.customer_id = c.code
     and m.trns_id = t.id
     and m.customer_id between :C1 and :C2
     and nvl(t.trns_type, 0) != 5
     and m.trns_date between :D1 and :D2
     and t.effect = 1
     and (:P_PASSWORD_NUMBER = 0
          or m.customer_id in (select cp.customer_code from ar_cust_password cp where cp.password_number = :P_PASSWORD_NUMBER))
     and (nvl(:CONT_FLAG, 0) = 0 or (nvl(:CONT_FLAG, 0) != 0 and m.serial is null))
     and c.cust_class between :FROM_CLASS and :TO_CLASS
     and (:FROM_SALES1 is null or s.supervisor_slsman >= :FROM_SALES1)
     and (:TO_SALES1 is null or s.supervisor_slsman <= :TO_SALES1)
     and (:FROM_SALES2 is null or m1.ctgry_mngr >= :FROM_SALES2)
     and (:TO_SALES2 is null or m1.ctgry_mngr <= :TO_SALES2)
     and (:FROM_SALES3 is null or m1.sales_mngr >= :FROM_SALES3)
     and (:TO_SALES3 is null or m1.sales_mngr <= :TO_SALES3)
     and (:FROM_CAT is null or m1.ctgry_code >= :FROM_CAT)
     and (:TO_CAT is null or m1.ctgry_code <= :TO_CAT)
     and (:FROM_SALES is null or m1.salesman_code >= :FROM_SALES)
     and (:TO_SALES is null or m1.salesman_code <= :TO_SALES)
     and (:C5 is null or c.mainarea_id >= :C5)
     and (:C5_2 is null or c.mainarea_id <= :C5_2)
     and (:C6 is null or c.subarea_id >= :C6)
     and (:C6_2 is null or c.subarea_id <= :C6_2)
     and m1.customer_code = c.code
     and m1.salesman_code = s.code
  union
  select g.code, g.trns_date, g.description_a, g.trns_id, g.doc_no, g.serial,
         sum(-g.total_value), max(g.mainarea_id), max(g.subarea_id),
         0, 0, 0, g.effect, g.doc_no2, 0 || 0, 0, g.entry_no, g.entry_type, g.entry_year,
         max(g.rtv_customer), cast(null as varchar2(100))
    from (select decode(:CONT_FLAG, 0, c.code, c.attr_code) code,
                 ts.trns_date, ts.description_a, ts.trns_id, ts.doc_no, m.serial, m.total_value,
                 c.mainarea_id, c.subarea_id, t.effect, ts.trns_id || '/' || ts.serial doc_no2,
                 ts.entry_no, ts.entry_type, ts.entry_year, m.rtv_customer
            from customer c, ar_maintrns m, ar_trnstype t, ar_cust_salesman m1, salesman s, ar_trns ts
           where m.customer_id = c.code
             and m.trns_id = t.id
             and m.serial = ts.serial
             and m.customer_id between :C1 and :C2
             and nvl(t.trns_type, 0) != 5
             and m.trns_date between :D1 and :D2
             and t.effect = 1
             and (:P_PASSWORD_NUMBER = 0
                  or m.customer_id in (select cp.customer_code from ar_cust_password cp
                                        where cp.password_number = :P_PASSWORD_NUMBER))
             and nvl(:CONT_FLAG, 0) != 0
             and m.serial is not null
             and c.cust_class between :FROM_CLASS and :TO_CLASS
             and (:FROM_SALES1 is null or s.supervisor_slsman >= :FROM_SALES1)
             and (:TO_SALES1 is null or s.supervisor_slsman <= :TO_SALES1)
             and (:FROM_SALES2 is null or m1.ctgry_mngr >= :FROM_SALES2)
             and (:TO_SALES2 is null or m1.ctgry_mngr <= :TO_SALES2)
             and (:FROM_SALES3 is null or m1.sales_mngr >= :FROM_SALES3)
             and (:TO_SALES3 is null or m1.sales_mngr <= :TO_SALES3)
             and (:FROM_CAT is null or m1.ctgry_code >= :FROM_CAT)
             and (:TO_CAT is null or m1.ctgry_code <= :TO_CAT)
             and (:FROM_SALES is null or m1.salesman_code >= :FROM_SALES)
             and (:TO_SALES is null or m1.salesman_code <= :TO_SALES)
             and (:C5 is null or c.mainarea_id >= :C5)
             and (:C5_2 is null or c.mainarea_id <= :C5_2)
             and (:C6 is null or c.subarea_id >= :C6)
             and (:C6_2 is null or c.subarea_id <= :C6_2)
             and m1.customer_code = c.code
             and m1.salesman_code = s.code) g
   group by g.code, g.trns_date, g.description_a, g.trns_id, g.doc_no, g.serial, g.effect, g.doc_no2,
            g.entry_no, g.entry_type, g.entry_year
  union
  select decode(:CONT_FLAG, 0, c.code, c.attr_code),
         m.trns_date,
         decode(:LANG, 'A', m.description_a, m.description_e),
         m.trns_id,
         m.doc_no,
         m.trns_serial,
         nvl(s.total_value, 0),
         c.mainarea_id,
         c.subarea_id,
         0,
         s.bill_id1,
         s.bill_id2,
         t.effect,
         s.bill_id1 || '/' || s.bill_id2,
         s.bill_id1 || lpad(s.bill_id2, 5, 0),
         0,
         m.acc_no,
         m.acc_type,
         m.acc_year,
         m.rtv_customer,
         cast(null as varchar2(100))
    from customer c, ar_maintrns m, ar_trnstype t, ar_subtrns s, ar_cust_salesman m1, salesman s1
   where m.customer_id = c.code
     and m.trns_id = t.id
     and m.customer_id between :C1 and :C2
     and nvl(t.trns_type, 0) != 5
     and m.trns_date between :D1 and :D2
     and m.trns_id = s.trns_id
     and t.effect = 0
     and m.mainarea_id = s.mainarea_id
     and m.subarea_id = s.subarea_id
     and m.trns_serial = s.trns_serial
     and c.cust_class between :FROM_CLASS and :TO_CLASS
     and (:FROM_SALES1 is null or s1.supervisor_slsman >= :FROM_SALES1)
     and (:TO_SALES1 is null or s1.supervisor_slsman <= :TO_SALES1)
     and (:FROM_SALES2 is null or m1.ctgry_mngr >= :FROM_SALES2)
     and (:TO_SALES2 is null or m1.ctgry_mngr <= :TO_SALES2)
     and (:FROM_SALES3 is null or m1.sales_mngr >= :FROM_SALES3)
     and (:TO_SALES3 is null or m1.sales_mngr <= :TO_SALES3)
     and (:FROM_CAT is null or m1.ctgry_code >= :FROM_CAT)
     and (:TO_CAT is null or m1.ctgry_code <= :TO_CAT)
     and (:FROM_SALES is null or m1.salesman_code >= :FROM_SALES)
     and (:TO_SALES is null or m1.salesman_code <= :TO_SALES)
     and (:C5 is null or c.mainarea_id >= :C5)
     and (:C5_2 is null or c.mainarea_id <= :C5_2)
     and (:C6 is null or c.subarea_id >= :C6)
     and (:C6_2 is null or c.subarea_id <= :C6_2)
     and m1.customer_code = c.code
     and m1.salesman_code = s1.code
  union
  select decode(:CONT_FLAG, 0, c.code, c.attr_code),
         m.trns_date,
         decode(:LANG, 'A', 'خصم حركة ' || nvl(s.det_desc, m.description_a),
                            'Trns Disc ' || nvl(s.det_desc_e, m.description_e)),
         m.trns_id,
         m.doc_no,
         m.trns_serial,
         decode(t.effect, 0, s.disc_value, 1, -s.disc_value),
         c.mainarea_id,
         c.subarea_id,
         1,
         s.bill_id1,
         s.bill_id2,
         t.effect,
         s.bill_id1 || '/' || s.bill_id2,
         s.bill_id1 || lpad(s.bill_id2, 5, 0),
         0,
         m.acc_no,
         m.acc_type,
         m.acc_year,
         m.rtv_customer,
         cast(null as varchar2(100))
    from customer c, ar_maintrns m, ar_trnstype t, ar_subtrns s, ar_cust_salesman m1, salesman s1
   where m.customer_id = c.code
     and m.trns_id = t.id
     and s.trns_id = m.trns_id
     and s.trns_serial = m.trns_serial
     and s.mainarea_id = m.mainarea_id
     and s.subarea_id = m.subarea_id
     and m.customer_id between :C1 and :C2
     and nvl(t.trns_type, 0) != 5
     and m.trns_date between :D1 and :D2
     and nvl(s.disc_value, 0) > 0
     and c.cust_class between :FROM_CLASS and :TO_CLASS
     and (:FROM_SALES1 is null or s1.supervisor_slsman >= :FROM_SALES1)
     and (:TO_SALES1 is null or s1.supervisor_slsman <= :TO_SALES1)
     and (:FROM_SALES2 is null or m1.ctgry_mngr >= :FROM_SALES2)
     and (:TO_SALES2 is null or m1.ctgry_mngr <= :TO_SALES2)
     and (:FROM_SALES3 is null or m1.sales_mngr >= :FROM_SALES3)
     and (:TO_SALES3 is null or m1.sales_mngr <= :TO_SALES3)
     and (:FROM_CAT is null or m1.ctgry_code >= :FROM_CAT)
     and (:TO_CAT is null or m1.ctgry_code <= :TO_CAT)
     and (:FROM_SALES is null or m1.salesman_code >= :FROM_SALES)
     and (:TO_SALES is null or m1.salesman_code <= :TO_SALES)
     and (:C5 is null or c.mainarea_id >= :C5)
     and (:C5_2 is null or c.mainarea_id <= :C5_2)
     and (:C6 is null or c.subarea_id >= :C6)
     and (:C6_2 is null or c.subarea_id <= :C6_2)
     and m1.customer_code = c.code
     and m1.salesman_code = s1.code
     and (:P_PASSWORD_NUMBER = 0
          or m.customer_id in (select cp.customer_code from ar_cust_password cp where cp.password_number = :P_PASSWORD_NUMBER))
  union
  select decode(:CONT_FLAG, 0, c.code, c.attr_code),
         cast(:D1 as date) - 1,
         decode(:LANG, 'A', 'رصــيـــــد أول المـــــــــدة', 'Opening Balance'),
         to_number(null),
         0,
         to_number(null),
         0,
         to_number(null),
         to_number(null),
         0,
         0,
         0,
         0,
         0 || '/' || 0,
         0 || 0,
         0,
         0,
         0,
         0,
         cast(null as varchar2(100)),
         cast(null as varchar2(100))
    from customer c, ar_cust_salesman m1, salesman s
   where c.code between :C1 and :C2
     and (:P_PASSWORD_NUMBER = 0
          or c.code in (select cp.customer_code from ar_cust_password cp where cp.password_number = :P_PASSWORD_NUMBER))
     and c.cust_class between :FROM_CLASS and :TO_CLASS
     and (:FROM_SALES1 is null or s.supervisor_slsman >= :FROM_SALES1)
     and (:TO_SALES1 is null or s.supervisor_slsman <= :TO_SALES1)
     and (:FROM_SALES2 is null or m1.ctgry_mngr >= :FROM_SALES2)
     and (:TO_SALES2 is null or m1.ctgry_mngr <= :TO_SALES2)
     and (:FROM_SALES3 is null or m1.sales_mngr >= :FROM_SALES3)
     and (:TO_SALES3 is null or m1.sales_mngr <= :TO_SALES3)
     and (:FROM_CAT is null or m1.ctgry_code >= :FROM_CAT)
     and (:TO_CAT is null or m1.ctgry_code <= :TO_CAT)
     and (:FROM_SALES is null or m1.salesman_code >= :FROM_SALES)
     and (:TO_SALES is null or m1.salesman_code <= :TO_SALES)
     and (:C5 is null or c.mainarea_id >= :C5)
     and (:C5_2 is null or c.mainarea_id <= :C5_2)
     and (:C6 is null or c.subarea_id >= :C6)
     and (:C6_2 is null or c.subarea_id <= :C6_2)
     and m1.customer_code = c.code
     and m1.salesman_code = s.code
  union
  select g.code, g.trns_date, g.desc_a, g.trns_type_code, g.doc_no, g.trns_serial,
         sum(g.sgn * (nvl(g.tax_value1, 0) - nvl(g.det_disc, 0)))
         + sum(g.sgn * nvl(g.quantity, 0) * nvl(g.unit_price, 0))
         - sum(g.sgn * (g.unit_price - g.net_unit_price) * nvl(g.quantity, 0)),
         g.mainarea_id, g.subarea_id,
         0, 100, 100, 9,
         g.trns_type_code || '/' || g.trns_serial,
         g.trns_type_code || lpad(g.trns_serial, 5, 0),
         1, 2, 3, 4,
         g.rtv_customer, g.invoice_no
    from (select decode(:CONT_FLAG, 0, c.code, c.attr_code) code,
                 m.trns_date, m.desc_a, m.trns_type_code, m.doc_no, m.trns_serial,
                 c.mainarea_id, c.subarea_id, m.rtv_customer, m.invoice_no,
                 decode(tt.effect, 2, 1, 4, -1) sgn,
                 d.tax_value1, d.det_disc, d.quantity, d.unit_price,
                 get_unit_price(d.trns_type_code, d.trns_serial, d.item_serial) net_unit_price
            from customer c, st_trns_mast m, st_trns_det d, st_trns_type tt, ar_cust_salesman m1, salesman s
           where m.customer_code = c.code
             and m.trns_type_code = d.trns_type_code
             and m.trns_serial = d.trns_serial
             and m.trns_type_code = tt.trns_type_code
             and ((tt.effect = 2 and tt.trns_type = 2) or (tt.effect = 4 and tt.trns_type = 4))
             and nvl(m.delete_flag, 0) = 0
             and m.customer_code between :C1 and :C2
             and m.trns_date between :D1 and :D2
             and nvl(m.cust_post_flag, 0) = 0
             and (:P_PASSWORD_NUMBER = 0
                  or m.customer_code in (select cp.customer_code from ar_cust_password cp
                                          where cp.password_number = :P_PASSWORD_NUMBER))
             and c.cust_class between :FROM_CLASS and :TO_CLASS
             and (:FROM_SALES1 is null or s.supervisor_slsman >= :FROM_SALES1)
             and (:TO_SALES1 is null or s.supervisor_slsman <= :TO_SALES1)
             and (:FROM_SALES2 is null or m1.ctgry_mngr >= :FROM_SALES2)
             and (:TO_SALES2 is null or m1.ctgry_mngr <= :TO_SALES2)
             and (:FROM_SALES3 is null or m1.sales_mngr >= :FROM_SALES3)
             and (:TO_SALES3 is null or m1.sales_mngr <= :TO_SALES3)
             and (:FROM_CAT is null or m1.ctgry_code >= :FROM_CAT)
             and (:TO_CAT is null or m1.ctgry_code <= :TO_CAT)
             and (:FROM_SALES is null or m1.salesman_code >= :FROM_SALES)
             and (:TO_SALES is null or m1.salesman_code <= :TO_SALES)
             and (:C5 is null or c.mainarea_id >= :C5)
             and (:C5_2 is null or c.mainarea_id <= :C5_2)
             and (:C6 is null or c.subarea_id >= :C6)
             and (:C6_2 is null or c.subarea_id <= :C6_2)
             and m1.customer_code = c.code
             and m1.salesman_code = s.code) g
   group by g.code, g.trns_date, g.desc_a, g.trns_type_code, g.doc_no, g.trns_serial,
            g.mainarea_id, g.subarea_id, g.rtv_customer, g.invoice_no
  union
  select g.code, g.trns_date, g.desc_a, g.trns_type_code, g.doc_no, g.trns_serial,
         sum(g.sgn * (g.service_cost * g.units_no)),
         g.mainarea_id, g.subarea_id,
         0, 100, 100, 9,
         g.trns_type_code || '/' || g.trns_serial,
         g.trns_type_code || lpad(g.trns_serial, 5, 0),
         1, 2, 3, 4,
         g.rtv_customer, g.invoice_no
    from (select decode(:CONT_FLAG, 0, c.code, c.attr_code) code,
                 m.trns_date, m.desc_a, m.trns_type_code, m.doc_no, m.trns_serial,
                 c.mainarea_id, c.subarea_id, m.rtv_customer, m.invoice_no,
                 decode(t.effect, 2, 1, 4, -1) sgn, d.service_cost, d.units_no
            from customer c, st_trns_mast m, st_trns_type t, st_trns_services d, ar_cust_salesman m1, salesman s
           where m.trns_type_code = d.trns_type_code
             and m.trns_serial = d.trns_serial
             and m.customer_code = c.code
             and m.trns_type_code = t.trns_type_code
             and m.customer_code between :C1 and :C2
             and m.trns_date between :D1 and :D2
             and ((t.effect = 2 and t.trns_type = 2) or (t.effect = 4 and t.trns_type = 4))
             and nvl(m.cust_post_flag, 0) = 0
             and nvl(m.delete_flag, 0) = 0
             and (:P_PASSWORD_NUMBER = 0
                  or m.customer_code in (select cp.customer_code from ar_cust_password cp
                                          where cp.password_number = :P_PASSWORD_NUMBER))
             and c.cust_class between :FROM_CLASS and :TO_CLASS
             and (:FROM_SALES1 is null or s.supervisor_slsman >= :FROM_SALES1)
             and (:TO_SALES1 is null or s.supervisor_slsman <= :TO_SALES1)
             and (:FROM_SALES2 is null or m1.ctgry_mngr >= :FROM_SALES2)
             and (:TO_SALES2 is null or m1.ctgry_mngr <= :TO_SALES2)
             and (:FROM_SALES3 is null or m1.sales_mngr >= :FROM_SALES3)
             and (:TO_SALES3 is null or m1.sales_mngr <= :TO_SALES3)
             and (:FROM_CAT is null or m1.ctgry_code >= :FROM_CAT)
             and (:TO_CAT is null or m1.ctgry_code <= :TO_CAT)
             and (:FROM_SALES is null or m1.salesman_code >= :FROM_SALES)
             and (:TO_SALES is null or m1.salesman_code <= :TO_SALES)
             and (:C5 is null or c.mainarea_id >= :C5)
             and (:C5_2 is null or c.mainarea_id <= :C5_2)
             and (:C6 is null or c.subarea_id >= :C6)
             and (:C6_2 is null or c.subarea_id <= :C6_2)
             and m1.customer_code = c.code
             and m1.salesman_code = s.code) g
   group by g.code, g.trns_date, g.desc_a, g.trns_type_code, g.doc_no, g.trns_serial,
            g.mainarea_id, g.subarea_id, g.rtv_customer, g.invoice_no
),
ob as (
  select k.code,
         (select nvl(sum(decode(t2.effect, 0, m2.total_value, 1, -(m2.total_value + nvl(m2.disc_value, 0)))), 0)
            from ar_maintrns m2, ar_trnstype t2
           where ((:CONT_FLAG = 0 and m2.customer_id = k.code)
                  or (:CONT_FLAG = 1 and m2.customer_id in (select c3.code
                                                               from customer c3
                                                              where c3.attr_code = to_char(k.code)
                                                                and (:C5 is null or c3.mainarea_id >= :C5)
                                                                and (:C5_2 is null or c3.mainarea_id <= :C5_2)
                                                                and (:C6 is null or c3.subarea_id >= :C6)
                                                                and (:C6_2 is null or c3.subarea_id <= :C6_2))))
             and m2.trns_id = t2.id
             and m2.trns_date < :D1
             and t2.trns_type != 5) opening_balance,
         case when :CONT_FLAG = 0
              then (select c4.name_a from customer c4 where c4.code = k.code)
              else (select decode(:LANG, 'A', l.tab_name_a, l.tab_name_e) from ar_customer_attr_lockups l
                     where l.tab_no = to_char(k.code))
         end customer_name
    from (select distinct code from q) k
)
select q.code,
       ob.customer_name,
       ob.opening_balance,
       q.trns_date,
       q.trns_id,
       q.trns_serial,
       q.doc_no,
       q.doc_no2,
       q.invoice_no,
       case when q.s_tab = 1 then q.doc_no2
            else nvl((select max(sm.trns_type_code || lpad(sm.trns_serial, 5, 0))
                        from st_trns_mast sm
                       where sm.cust_trns_id = q.trns_id and sm.cust_trns_serial = q.trns_serial
                         and sm.cust_mainarea_id = q.mainarea_id and sm.cust_subarea_id = q.subarea_id
                      having count(*) = 1), q.doc_no2)
       end inv_no,
       case when q.effect = 1
            then q.description_a || decode(:LANG, 'A', ' - رقم الحركة : ', ' - Transaction no. : ')
                 || q.trns_id || '\' || q.trns_serial
            else q.description_a
       end description_a,
       q.effect,
       q.disc_flag,
       q.mainarea_id,
       decode(:LANG, 'A', ma.name_a, ma.name_e) main_area_name,
       q.subarea_id,
       decode(:LANG, 'A', sa.name_a, sa.name_e) sub_area_name,
       q.bill_id1,
       q.bill_id2,
       q.s_tab,
       q.acc_no,
       q.acc_type,
       q.acc_year,
       q.rtv_customer,
       q.invoice_no1,
       q.cr_db,
       case when q.cr_db < 0 then -q.cr_db else 0 end cf_debit,
       case when q.cr_db > 0 then q.cr_db else 0 end cf_credit,
       ob.opening_balance
       + sum(q.cr_db) over (partition by q.code order by q.trns_date, q.trns_id, q.trns_serial, q.disc_flag, q.doc_no2
                            rows unbounded preceding) curr_bal,
       case when ob.opening_balance
                 + sum(q.cr_db) over (partition by q.code order by q.trns_date, q.trns_id, q.trns_serial, q.disc_flag, q.doc_no2
                                      rows unbounded preceding) >= 0
            then decode(:LANG, 'A', 'م', 'D') else decode(:LANG, 'A', 'د', 'C')
       end cf_cr_db_flag
  from q
  left join ob on ob.code = q.code
  left join ar_mainarea ma on ma.id = q.mainarea_id
  left join ar_subarea sa on sa.main_id = q.mainarea_id and sa.id = q.subarea_id
