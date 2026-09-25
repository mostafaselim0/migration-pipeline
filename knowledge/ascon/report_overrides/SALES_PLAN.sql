-- SALES_PLAN (ST\FMB\SALES_PLAN_RDF.xml) - sales plans per period / store / transaction type.
-- Schema change: ST_SALES_PLAN / ST_SALES_PLAN_DET no longer have MAINAREA_ID, SUBAREA_ID or GROUP_CODE.
-- Header/detail are now joined on the current FK (PERIOD_CODE, STORE_CODE, TRNS_TYPE_CODE).
-- GROUP_CODE is taken from ST_ITEM (ITEM_CODE is unique there), so FROM_GROUP / TO_GROUP still filter.
-- MAINAREA_ID / SUBAREA_ID columns, their filters (P_FROM/TO_MAINAREA, P_FROM/TO_SUBAREA) and the
-- M_NAME / S_NAME formulas are dropped.
-- Formula columns kept: PERIOD_NAME, STORE_NAME, TRNS_NAME, ITEM_NAME, VAL (qty * price).
select m.period_code,
       decode(:LANG, 'A', p.period_name, p.period_name_e) period_name,
       m.store_code,
       decode(:LANG, 'A', st.name_a, st.name_e) store_name,
       m.trns_type_code,
       decode(:LANG, 'A', tt.desc_a, tt.desc_e) trns_name,
       it.item_group_code group_code,
       d.item_code,
       decode(:LANG, 'A', it.name_a, it.name_e) item_name,
       d.qty,
       d.price,
       nvl(d.qty * d.price, 0) val
  from st_sales_plan m
  join st_sales_plan_det d
    on d.period_code = m.period_code and d.store_code = m.store_code and d.trns_type_code = m.trns_type_code
  left join st_item it on it.item_code = d.item_code
  left join st_periods p on p.period_code = m.period_code
  left join st_store st on st.store_code = m.store_code
  left join st_trns_type tt on tt.trns_type_code = m.trns_type_code
 where (m.period_code >= :P_FROM_PERIOD or :P_FROM_PERIOD is null)
   and (m.period_code <= :P_TO_PERIOD or :P_TO_PERIOD is null)
   and (m.store_code >= :FROM_STORE_CODE or :FROM_STORE_CODE is null)
   and (m.store_code <= :TO_STORE_CODE or :TO_STORE_CODE is null)
   and (d.item_code >= :FROM_ITEM_CODE or :FROM_ITEM_CODE is null)
   and (d.item_code <= :TO_ITEM_CODE or :TO_ITEM_CODE is null)
   and (it.item_group_code >= :FROM_GROUP or :FROM_GROUP is null)
   and (it.item_group_code <= :TO_GROUP or :TO_GROUP is null)
   and (m.trns_type_code >= :P_FROM_TRNS or :P_FROM_TRNS is null or m.trns_type_code is null)
   and (m.trns_type_code <= :P_TO_TRNS or :P_TO_TRNS is null or m.trns_type_code is null)
