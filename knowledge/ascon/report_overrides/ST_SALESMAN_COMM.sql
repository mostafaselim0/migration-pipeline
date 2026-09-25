-- ST_SALESMAN_COMM (ST\FMB\ST_SALESMAN_COMM_RDF.xml) - salesmen commissions on sold / returned values.
-- ORA-00918 fix: DELETE_FLAG exists in ST_TRNS_MAST and ST_TRNS_DET now -> TRN_MST.DELETE_FLAG
-- (the transaction header flag). "ORDER BY SM.CODE" removed.
-- Formula columns kept: CF_GROUP_NAME, CF_ITEM_NAME, CF_NET_SOLD_VALUE (sold - returned),
-- CF_COMMISSION_VALUE (net * commission %), CF_COMM_SALES (sold * commission %).
select x.code,
       x.salesman,
       x.group_code,
       decode(:P_LANG, 'A', g.name_a, g.name_e) cf_group_name,
       x.item_code,
       decode(:P_LANG, 'A', i.name_a, i.name_e) cf_item_name,
       x.commission,
       x.sold_value,
       x.return_value,
       nvl(x.sold_value, 0) - nvl(x.return_value, 0) cf_net_sold_value,
       (nvl(x.sold_value, 0) - nvl(x.return_value, 0)) * nvl(x.commission, 0) / 100 cf_commission_value,
       nvl(x.sold_value, 0) * nvl(x.commission, 0) / 100 cf_comm_sales
  from (select sm.code,
               nvl(grp.comm, 0) commission,
               sm.name_a salesman,
               grp.group_code,
               grp.item_code,
               sum(decode(trn_typ.effect, 2, (nvl(trn_det.quantity, 0) * (nvl(trn_det.unit_price, 0) - nvl(trn_det.disc, 0))
                                              - nvl(trn_det.det_disc, 0)), 0)) sold_value,
               sum(decode(trn_typ.effect, 4, (nvl(trn_det.quantity, 0) * (nvl(trn_det.unit_price, 0) - nvl(trn_det.disc, 0))
                                              - nvl(trn_det.det_disc, 0)), 0)) return_value
          from salesman sm, st_trns_mast trn_mst, st_trns_det trn_det, st_trns_type trn_typ, st_store_item_sales_comm grp
         where trn_typ.effect in (2, 4)
           and grp.group_code = trn_det.group_code
           and grp.item_code = trn_det.item_code
           and grp.store_code = trn_det.store_code
           and grp.salesman = trn_mst.salesman_code
           and trn_typ.trns_type_code = trn_mst.trns_type_code
           and trn_det.trns_type_code = trn_mst.trns_type_code
           and trn_det.trns_serial = trn_mst.trns_serial
           and sm.code = trn_mst.salesman_code
           and (sm.code >= :P_FROM_SALESMAN or :P_FROM_SALESMAN is null)
           and (sm.code <= :P_TO_SALESMAN or :P_TO_SALESMAN is null)
           and (trn_mst.trns_date >= :P_FROM_TRNS_DATE or :P_FROM_TRNS_DATE is null)
           and (trn_mst.trns_date <= :P_TO_TRNS_DATE or :P_TO_TRNS_DATE is null)
           and (trn_typ.trns_type_code >= :P_FROM_TRNS_TYPE_CODE or :P_FROM_TRNS_TYPE_CODE is null)
           and (trn_typ.trns_type_code <= :P_TO_TRNS_TYPE_CODE or :P_TO_TRNS_TYPE_CODE is null)
           and (grp.group_code >= :P_FROM_GROUP_CODE or :P_FROM_GROUP_CODE is null)
           and (grp.group_code <= :P_TO_GROUP_CODE or :P_TO_GROUP_CODE is null)
           and nvl(trn_mst.delete_flag, 0) = 0
         group by sm.code, nvl(grp.comm, 0), sm.name_a, grp.group_code, grp.item_code) x
  left join st_item_group g on g.item_group_code = x.group_code
  left join st_item i on i.item_group_code = x.group_code and i.item_code = x.item_code
