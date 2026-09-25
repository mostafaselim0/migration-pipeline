-- CUST_ORDER (ST\FMB\CUST_ORDER_RDF.xml) - approved sales orders with their invoiced / returned quantities.
-- Reports data model: Q_1 (order lines, groups G_ORDER_SERIAL -> G_ORDER_SERIAL_DETAIL)
--   -> Q_2 (sales invoices and returns of the order, linked on item group / item / unit / order type / serial)
--   -> Q_4 (st_sales_order_det_d delivery schedule, linked on type / serial / line).
-- Flattened as order lines LEFT JOIN Q_2 (one row per invoice / return line; lines with no invoice kept).
-- Q_4 is a second, independent detail of the same line; joining it too would cross-multiply the rows,
-- so it is not included.
-- ORA-00918 fix: RET_TRNS_TYPE_CODE / RET_TRNS_SERIAL exist in ST_TRNS_MAST and ST_TRNS_DET -> TM.; all columns
-- qualified. "ORDER BY TRNS_TYPE_CODE, SERIAL;" removed.
-- Formula columns kept: ORDER_NO, CF_PAYMENT_TERMS, CF_DELIVERY_TERMS, CF_TOTAL_LINE (price * qty),
-- LINE_INV_QTY (CS_1 = invoiced qty of the line) and CF_REM_QTY (qty - invoiced when the order is open).
-- Not kept: customer balance / credit-limit / due-amount header formulas (GET_CUSTOMER_* per order).
with l as (
  select so.order_serial,
         nvl(so.closed, 0) closed,
         so.order_date,
         sod.unit_price,
         so.disc_val,
         so.trnsport_val,
         so.loading_date,
         so.invoice_number,
         so.delivery_terms,
         so.pay_term payment_terms,
         so.customer_code,
         so.note,
         sod.serial,
         sod.item_group_code,
         sod.item_code,
         sod.quantity,
         sod.bonus,
         so.trns_type_code sales_trns_type_code,
         so.trns_serial sales_trns_serial,
         so.doc_no,
         so.trns_type_code,
         so.trns_serial,
         sod.unit_code,
         it.name_e it_name,
         ig.name_e ig_name,
         iu.name_e iu_name,
         c.name_e cust_name
    from st_sales_order so, st_sales_order_det sod, customer c, st_item it, st_item_group ig, st_unit iu
   where so.trns_type_code = sod.trns_type_code
     and so.trns_serial = sod.trns_serial
     and so.customer_code = c.code
     and (so.approved = 1)
     and sod.item_code = it.item_code
     and sod.item_group_code = ig.item_group_code
     and sod.unit_code = iu.unit_code
     and (so.store_code >= :FROM_STORE_CODE or :FROM_STORE_CODE is null)
     and (so.store_code <= :TO_STORE_CODE or :TO_STORE_CODE is null)
     and (c.mainarea_id >= :P_FROM_AREA or :P_FROM_AREA is null)
     and (c.mainarea_id <= :P_TO_AREA or :P_TO_AREA is null)
     and (sod.item_group_code >= :FROM_ITEM_GROUP_CODE or :FROM_ITEM_GROUP_CODE is null)
     and (sod.item_group_code <= :TO_ITEM_GROUP_CODE or :TO_ITEM_GROUP_CODE is null)
     and (sod.item_code >= :FROM_ITEM_CODE or :FROM_ITEM_CODE is null)
     and (sod.item_code <= :TO_ITEM_CODE or :TO_ITEM_CODE is null)
     and (so.customer_code >= :P_FROM_CUSTOMER or :P_FROM_CUSTOMER is null)
     and (so.customer_code <= :P_TO_CUSTOMER or :P_TO_CUSTOMER is null)
     and (sod.trns_type_code >= :P_FROM_TRNS or :P_FROM_TRNS is null)
     and (sod.trns_type_code <= :P_TO_TRNS or :P_TO_TRNS is null)
     and (sod.trns_serial >= :P_FROM_TRNS_SER or :P_FROM_TRNS_SER is null)
     and (sod.trns_serial <= :P_TO_TRNS_SER or :P_TO_TRNS_SER is null)
     and (so.order_date >= :P_FROM_DATE or :P_FROM_DATE is null)
     and (so.order_date <= :P_TO_DATE or :P_TO_DATE is null)
     and (((nvl(:REP_TYPE, 0) = 1
            and (so.trns_type_code, so.trns_serial) not in (select sdm.order_trns_type_code, sdm.order_trns_serial
                                                              from st_delivery_mast sdm
                                                             where nvl(sdm.delete_flag, 0) = 0)
            and (so.trns_type_code, so.trns_serial) not in (select stm.order_trns_type_code, stm.order_trns_serial
                                                              from st_trns_mast stm
                                                             where nvl(stm.delete_flag, 0) = 0
                                                               and stm.order_trns_type_code is not null
                                                               and stm.order_trns_serial is not null)
            and nvl(so.closed, 0) = 0)
           or nvl(:REP_TYPE, 0) = 0)
          or ((nvl(:REP_TYPE, 0) = 2
               and (so.trns_type_code, so.trns_serial) in
                   (select sdm1.order_trns_type_code, sdm1.order_trns_serial
                      from st_delivery_mast sdm1
                     where nvl(sdm1.delete_flag, 0) = 0
                       and (sdm1.trns_type_code, sdm1.trns_serial) not in
                           (select stm1.delivery_trns_type_code, stm1.delivery_trns_serial
                              from st_trns_mast stm1
                             where nvl(stm1.delete_flag, 0) = 0
                               and stm1.delivery_trns_type_code is not null
                               and stm1.delivery_trns_serial is not null))
               and (so.trns_type_code, so.trns_serial) not in (select stm2.order_trns_type_code, stm2.order_trns_serial
                                                                 from st_trns_mast stm2
                                                                where nvl(stm2.delete_flag, 0) = 0
                                                                  and stm2.order_trns_type_code is not null
                                                                  and stm2.order_trns_serial is not null)
               and nvl(so.closed, 0) = 0)
              or nvl(:REP_TYPE, 0) = 0)
          or ((nvl(:REP_TYPE, 0) = 3
               and ((so.trns_type_code, so.trns_serial) in
                        (select sdm2.order_trns_type_code, sdm2.order_trns_serial
                           from st_delivery_mast sdm2
                          where nvl(sdm2.delete_flag, 0) = 0
                            and (sdm2.trns_type_code, sdm2.trns_serial) in
                                (select stm3.delivery_trns_type_code, stm3.delivery_trns_serial
                                   from st_trns_mast stm3
                                  where nvl(stm3.delete_flag, 0) = 0
                                    and stm3.delivery_trns_type_code is not null
                                    and stm3.delivery_trns_serial is not null))
                    or (so.trns_type_code, so.trns_serial) in (select stm4.order_trns_type_code, stm4.order_trns_serial
                                                                 from st_trns_mast stm4
                                                                where nvl(stm4.delete_flag, 0) = 0
                                                                  and stm4.order_trns_type_code is not null
                                                                  and stm4.order_trns_serial is not null)
                    or nvl(so.closed, 0) = 1))
              or nvl(:REP_TYPE, 0) = 0))
     and (:P_PASSWORD_NUMBER = 0
          or (so.customer_code >= (select cp.from_customer_code from ar_customer_password cp
                                    where cp.password_number = :P_PASSWORD_NUMBER)
              and so.customer_code <= (select cp.to_customer_code from ar_customer_password cp
                                        where cp.password_number = :P_PASSWORD_NUMBER)))
     and (:P_PASSWORD_NUMBER = 0
          or (so.salesman_code >= (select cp.from_salesman from ar_customer_password cp
                                    where cp.password_number = :P_PASSWORD_NUMBER)
              and so.salesman_code <= (select cp.to_salesman from ar_customer_password cp
                                        where cp.password_number = :P_PASSWORD_NUMBER)))
     and (:P_PASSWORD_NUMBER = 0
          or so.trns_type_code in (select tp.trns_type_code from st_trnstype_password tp
                                    where tp.flag = 1 and tp.password_number = :P_PASSWORD_NUMBER))
),
d as (
  select tm.trns_date delivery_date,
         tm.invoice_no,
         tm.trns_serial delivery_serial,
         tm.trns_type_code delivery_trns_type_code,
         tm.order_trns_type_code,
         tm.order_trns_serial,
         td.group_code d_item_group_code,
         td.item_code d_item_code,
         td.unit_code d_unit_code,
         td.quantity inv_qty,
         1 aa
    from st_trns_det td, st_trns_mast tm, st_trns_type tt
   where tm.trns_type_code = td.trns_type_code
     and tm.trns_serial = td.trns_serial
     and tm.trns_type_code = tt.trns_type_code
     and tt.effect = 2 and tt.trns_type = 2
     and nvl(tm.delete_flag, 0) = 0
  union all
  select tm.trns_date,
         tm.invoice_no,
         tm.trns_serial,
         tm.trns_type_code,
         get_order_trns_type_code(tm.ret_trns_type_code, tm.ret_trns_serial),
         get_order_trns_serial(tm.ret_trns_type_code, tm.ret_trns_serial),
         td.group_code,
         td.item_code,
         td.unit_code,
         -1 * td.quantity,
         2
    from st_trns_det td, st_trns_mast tm, st_trns_type tt
   where tm.trns_type_code = td.trns_type_code
     and tm.trns_serial = td.trns_serial
     and tm.trns_type_code = tt.trns_type_code
     and tt.effect = 4 and tt.trns_type = 4
     and nvl(tm.delete_flag, 0) = 0
     and get_order_trns_type_code(tm.ret_trns_type_code, tm.ret_trns_serial) is not null
)
select l.customer_code,
       l.cust_name,
       nvl(l.trns_serial || ' ' || '/' || ' ' || l.trns_type_code, ' ') order_no,
       l.order_date,
       l.doc_no,
       l.order_serial,
       l.sales_trns_type_code,
       l.sales_trns_serial,
       l.disc_val,
       l.loading_date,
       l.trnsport_val,
       l.invoice_number,
       l.delivery_terms cf_delivery_terms,
       l.payment_terms,
       decode(:LANG, 'A', pt.type_name, pt.type_name_e) cf_payment_terms,
       l.note,
       l.trns_type_code,
       l.trns_serial,
       l.serial,
       l.item_group_code,
       l.ig_name,
       l.item_code,
       l.it_name,
       l.unit_code,
       l.iu_name,
       l.quantity,
       l.bonus,
       l.unit_price,
       nvl(l.unit_price, 0) * nvl(l.quantity, 0) cf_total_line,
       l.closed,
       d.delivery_trns_type_code,
       d.delivery_serial,
       d.delivery_date,
       d.invoice_no,
       d.aa,
       d.inv_qty,
       sum(d.inv_qty) over (partition by l.trns_type_code, l.trns_serial, l.serial) line_inv_qty,
       case when l.closed = 0
            then nvl(l.quantity, 0) - nvl(sum(d.inv_qty) over (partition by l.trns_type_code, l.trns_serial, l.serial), 0)
            else 0 end cf_rem_qty
  from l
  left join d
    on d.d_item_group_code = l.item_group_code
   and d.d_item_code = l.item_code
   and d.d_unit_code = l.unit_code
   and d.order_trns_type_code = l.trns_type_code
   and d.order_trns_serial = l.trns_serial
  left join st_payment_terms pt on to_char(pt.serial) = l.payment_terms
