-- ST_ITEM_REQ (ST\FMB\ST_ITEM_REQ_RDF.xml) - material requests (header ST_ITEM_REQ + lines ST_ITEM_REQ_DET).
-- ORA-00918 fix: STORE_CODE, REQ_DATE, ITEM_CODE ... exist in both tables now, every column is qualified.
-- "ORDER BY ..., &P_ORDER" removed (no ORDER BY in the interactive report).
-- START_DATE / END_DATE are character parameters in the RDF and stay TO_DATE(..., 'DD-MM-YYYY')
-- (Oracle also accepts DD/MM/YYYY with that mask).
-- Formula columns kept: CF_TRNS_DESC, STORE_NAME, CF_FROM_STORE_NAME, ITEM_DESC, UNIT_NAME, and the
-- purchase / transfer request links of PRUCHASE_TRNS_TYPE_CODE (max() instead of "too many rows -> null").
select mast.trns_type_code,
       decode(:LANG, 'A', tt.desc_a, tt.desc_e) trns_desc,
       mast.trns_serial,
       mast.req_date,
       mast.store_code,
       decode(:LANG, 'A', st.name_a, st.name_e) store_name,
       mast.from_store_code f_store_code,
       decode(:LANG, 'A', fs.name_a, fs.name_e) from_store_name,
       mast.desc_a,
       mast.desc_e,
       det.item_serial,
       det.group_code,
       det.item_code,
       decode(:LANG, 'A', it.name_a, it.name_e) item_desc,
       det.unit_code,
       decode(:LANG, 'A', un.name_a, un.name_e) unit_name,
       det.quantity,
       nvl(det.pr_flag, 0) pr_flag,
       (select max(pr.trns_type_code) from pr_order_det_request pr
         where pr.req_trns_type_code = mast.trns_type_code and pr.req_trns_serial = mast.trns_serial
           and pr.req_item_serial = det.item_serial) pruchase_trns_type_code,
       (select max(pr.trns_serial) from pr_order_det_request pr
         where pr.req_trns_type_code = mast.trns_type_code and pr.req_trns_serial = mast.trns_serial
           and pr.req_item_serial = det.item_serial) pruchase_trns_serial,
       (select max(tr.trns_type_code) from st_trns_det_request tr
         where tr.req_trns_type_code = mast.trns_type_code and tr.req_trns_serial = mast.trns_serial
           and tr.req_item_serial = det.item_serial) req_trns_type_code,
       (select max(tr.trns_serial) from st_trns_det_request tr
         where tr.req_trns_type_code = mast.trns_type_code and tr.req_trns_serial = mast.trns_serial
           and tr.req_item_serial = det.item_serial) req_trns_serial
  from st_item_req mast
  join st_item_req_det det on det.trns_serial = mast.trns_serial and det.trns_type_code = mast.trns_type_code
  left join st_trns_type tt on tt.trns_type_code = mast.trns_type_code
  left join st_store st on st.store_code = mast.store_code
  left join st_store fs on fs.store_code = mast.from_store_code
  left join st_item it on it.item_code = det.item_code and it.item_group_code = det.group_code
  left join st_unit un on un.unit_code = det.unit_code
 where ((mast.trns_type_code >= :FROM_TRNS_CODE or :FROM_TRNS_CODE is null)
        and (mast.trns_type_code <= :TO_TRNS_CODE or :TO_TRNS_CODE is null))
   and ((mast.trns_serial >= :FROM_TRNS_SERIAL or :FROM_TRNS_SERIAL is null)
        and (mast.trns_serial <= :TO_TRNS_SERIAL or :TO_TRNS_SERIAL is null))
   and ((mast.req_date >= to_date(:START_DATE, 'DD-MM-YYYY') or :START_DATE is null)
        and (mast.req_date <= to_date(:END_DATE, 'DD-MM-YYYY') or :END_DATE is null))
   and ((mast.store_code >= :FROM_STORE_CODE or :FROM_STORE_CODE is null)
        and (mast.store_code <= :TO_STORE_CODE or :TO_STORE_CODE is null))
   and (:STATUS = 3 or nvl(det.pr_flag, 0) = :STATUS)
