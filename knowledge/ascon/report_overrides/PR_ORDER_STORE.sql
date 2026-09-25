-- PR_ORDER_STORE (ST\FMB\PR_ORDER_STORE_RDF.xml) - purchase orders in detail (PR_ORDER + PR_ORDER_DET lines).
-- Schema change: ST_STORE.STORE_COMP_EMP_CODE no longer exists (no equivalent column in SMART), so it is dropped
-- together with the store-keeper formulas that read PY_PRSNL_H through it (CF_3 / CF_4 / CF_5).
-- Duplicate names fixed: B.NOTES -> NOTES2 (as in the Reports group); the second A.OUT_DOC (OUT_DOC2) is dropped
-- (same value as OUT_DOC). SERIAL / PEICE_NO qualified. "ORDER BY SERIAL" removed.
-- Formula columns kept: VENDOR_NAME, CURR_NAME, STORE_NAME, GROUP_NAME, ITEM_NAME, UNIT_NAME, PACK_UNIT_NAME,
-- UNIT_COST (vn_price * currency_rate), TOTAL_COST (vn_price * qty - det_disc), PAYMENT_METHOD_NAME,
-- PAYMENT_CONDETION_NAME, PORT_DEST_DESC, TERM_SHIP_NAME, SERVICE_VALUE (PR_ORDER_SRVC total of the order).
select 0 salesman_code,
       a.trns_type_code,
       a.trns_serial,
       a.doc_no,
       a.pr_order_date,
       a.supplier_code supp_code,
       sp.name_e vendor_name,
       a.currency_code,
       cu.currency_desc_e curr_name,
       a.currency_rate,
       a.payment_condition_code,
       decode(:LANG, 'A', pc.cond_desca, pc.cond_desce) payment_condetion_name,
       a.payment_method,
       decode(:LANG, 'A', pm.pay_cond_desc, pm.pay_cond_desc_e) payment_method_name,
       a.due_date,
       a.out_doc,
       a.supp_quot_no,
       a.disc_val,
       a.term_ship,
       a.term_ship_code,
       ts.name_e term_ship_name,
       a.port_dest_code,
       decode(:LANG, 'A', lp.port_name, lp.port_name_e) port_dest_desc,
       a.notes,
       a.store_code,
       st.name_e store_name,
       st.stop_reason,
       (select round(sum((sv.unit_cost / nvl(a.currency_rate, 1)) * sv.quantity), 2)
          from pr_order_srvc sv
         where sv.trns_type_code = a.trns_type_code and sv.trns_serial = a.trns_serial) service_value,
       b.serial,
       b.group_code,
       decode(:LANG, 'A', g.name_a, g.name_e) group_name,
       b.item_code,
       nvl(t.peice_no, b.item_code) item_code_new,
       decode(:LANG, 'A', t.name_a, t.name_e) item_name,
       b.unit_code,
       decode(:LANG, 'A', u.name_a, u.name_e) unit_name,
       b.quantity,
       b.vn_price,
       nvl(b.vn_price, 0) * nvl(a.currency_rate, 1) unit_cost,
       b.det_disc,
       (nvl(b.vn_price, 0) * nvl(b.quantity, 0)) - nvl(b.det_disc, 0) total_cost,
       b.packaging_unit_code,
       decode(:LANG, 'A', pu.name_a, pu.name_e) pack_unit_name,
       b.packaging_quantity,
       b.notes notes2,
       0 settel_type_code,
       0 shipment_type_code,
       0 recv_cond_code
  from pr_order a
  join pr_order_det b on b.trns_type_code = a.trns_type_code and b.trns_serial = a.trns_serial
  join st_item t on t.item_group_code = b.group_code and t.item_code = b.item_code
  join st_store st on st.store_code = a.store_code
  left join supplier sp on sp.code = a.supplier_code
  left join ac_currency cu on cu.currency_code = a.currency_code
  left join lc_pay_credit_cond pc on pc.cond_no = a.payment_condition_code
  left join lc_pay_cond pm on pm.pay_cond_code = a.payment_method
  left join st_term_ship ts on ts.term_ship_code = a.term_ship_code
  left join lc_port lp on lp.port_code = a.port_dest_code
  left join st_item_group g on g.item_group_code = b.group_code
  left join st_unit u on u.unit_code = b.unit_code
  left join st_unit pu on pu.unit_code = b.packaging_unit_code
 where (a.trns_type_code >= :P_FROM_TRNS_TYPE_CODE or :P_FROM_TRNS_TYPE_CODE is null)
   and (a.trns_type_code <= :P_TO_TRNS_TYPE_CODE or :P_TO_TRNS_TYPE_CODE is null)
   and (a.trns_serial >= :P_FROM_TRNS_SERIAL or :P_FROM_TRNS_SERIAL is null)
   and (a.trns_serial <= :P_TO_TRNS_SERIAL or :P_TO_TRNS_SERIAL is null)
