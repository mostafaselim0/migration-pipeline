-- ST_ITEM_CARD_BASIC_QTY (ST\FMB\ST_Item_Card_Basic_Qty_RDF.xml) - item transaction card, quantities only.
-- Q_1 = store transactions (ST_TRNS_MAST/DET) UNION one opening row per store item (ST_STORE_ITEM).
-- Lexicals: &P_ORDER / &P_ORDER2 (select-list item code) -> their defaults TRN_DET.ITEM_CODE / SI.ITEM_CODE;
-- &P_ITEM_RANGE (item range built by the form from FROM_ITEM_CODE / TO_ITEM_CODE) -> the same condition written
-- with those binds; &P_ITEM_RANGE2 duplicated the SI item filter already in the query -> dropped.
-- Opening-row store filter used ":TO_STORE_CODE ... <= :FROM_STORE_CODE" (typo) -> <= :TO_STORE_CODE.
-- Q_2 (unit name/factor of the chosen unit, linked on GROUP/ITEM/UNIT_CODE formula) -> UNIT_NAME_P / UNIT_FACTOR.
-- Formula columns: REC_QTY / ISSUE_QTY (P_UNIT = 1 -> basic unit, else largest unit) and CURRENT_BALANCE =
-- GET_BALANCE(store, group, item, FROM_DATE - 1) + running signed quantity (with no FROM_DATE it starts at 0).
with q as (
  select trn_det.store_code,
         decode(:LANG, 'A', st.name_a, 'E', st.name_e) store_name,
         trn_det.group_code,
         decode(:LANG, 'A', itm_grp.name_a, 'E', itm_grp.name_e) group_name,
         trn_det.item_code,
         decode(:LANG, 'A', itm.name_a, 'E', itm.name_e) itm_name,
         itm.peice_no,
         trn_mst.trns_date,
         trn_mst.date_serial,
         trn_det.item_serial,
         trn_mst.doc_no,
         decode(trn_typ.effect,
                5, decode(:LANG, 'A', 'تحويل إلى مخزن ' || stt.name_a, 'Transfer to store ' || stt.name_e),
                6, decode(:LANG, 'A', 'تحويل من مخزن ' || stf.name_a, 'Transfer from store ' || stf.name_e),
                decode(:LANG, 'A', trn_typ.desc_a, 'E', trn_typ.desc_e) || '/' || trn_mst.trns_serial) trns_desc,
         trn_typ.effect,
         trn_det.unit_cost,
         trn_det.basic_qty,
         trn_det.unit_price,
         trn_det.quantity,
         1 ord,
         decode(nvl(stb.neg_sale_balance, 0), 1, decode(trn_typ.effect, 1, 10, 6, 20, 4, 30, 2, 40, 5, 50, 3, 60), 1) order22,
         itm.model_no
    from st_trns_det trn_det, st_trns_mast trn_mst, st_trns_type trn_typ, st_store st, st_store stt, st_store stf,
         st_item_group itm_grp, st_item itm, st_basic stb
   where trn_mst.delete_flag = 0
     and ((:FROM_STORE_CODE is null) or (:TO_STORE_CODE is null)
          or (:FROM_STORE_CODE is not null and :TO_STORE_CODE is not null
              and trn_det.store_code between :FROM_STORE_CODE and :TO_STORE_CODE))
     and ((:FROM_ITEM_GROUP_CODE is null) or (:TO_ITEM_GROUP_CODE is null)
          or (:FROM_ITEM_GROUP_CODE is not null and :TO_ITEM_GROUP_CODE is not null
              and trn_det.group_code between :FROM_ITEM_GROUP_CODE and :TO_ITEM_GROUP_CODE))
     and ((:FROM_DATE is null) or (:FROM_DATE is not null and trn_mst.trns_date >= :FROM_DATE))
     and ((:TO_DATE is null) or (:TO_DATE is not null and trn_mst.trns_date <= :TO_DATE))
     and trn_det.trns_type_code = trn_mst.trns_type_code
     and trn_det.trns_serial = trn_mst.trns_serial
     and trn_det.trns_type_code = trn_typ.trns_type_code
     and trn_det.store_code = st.store_code
     and stf.store_code(+) = trn_mst.trnsfer_from_store
     and stt.store_code(+) = trn_mst.trnsfer_to_store
     and itm_grp.item_group_code = trn_det.group_code
     and itm.item_code = trn_det.item_code
     and itm.item_group_code = trn_det.group_code
     and (:P_PASSWORD_NUMBER = 0
          or trn_det.store_code in (select sp.store_code from st_store_password sp where sp.password_number = :P_PASSWORD_NUMBER))
     and (:P_PASSWORD_NUMBER = 0
          or trn_det.group_code in (select gp.group_code from st_group_password gp where gp.password_number = :P_PASSWORD_NUMBER))
     and (:P_PASSWORD_NUMBER = 0
          or trn_typ.trns_type_code in (select tp.trns_type_code from st_trnstype_password tp
                                         where tp.flag = 1 and tp.password_number = :P_PASSWORD_NUMBER))
     and (:FROM_ITEM_CODE is null or trn_det.item_code >= :FROM_ITEM_CODE)
     and (:TO_ITEM_CODE is null or trn_det.item_code <= :TO_ITEM_CODE)
  union
  select si.store_code,
         decode(:LANG, 'A', st.name_a, 'E', st.name_e),
         si.group_code,
         decode(:LANG, 'A', itm_grp.name_a, 'E', itm_grp.name_e),
         si.item_code,
         decode(:LANG, 'A', itm.name_a, 'E', itm.name_e),
         itm.peice_no,
         cast(:FROM_DATE as date),
         0, 0, 0,
         decode(:LANG, 'A', 'رصيد أول المدة', 'Begin Balance'),
         1, 0, 0, 0, 0,
         0, 0,
         itm.model_no
    from st_store_item si, st_store st, st_item_group itm_grp, st_item itm
   where (:FROM_STORE_CODE is null or si.store_code >= :FROM_STORE_CODE)
     and (:TO_STORE_CODE is null or si.store_code <= :TO_STORE_CODE)
     and (:FROM_ITEM_GROUP_CODE is null or si.group_code >= :FROM_ITEM_GROUP_CODE)
     and (:TO_ITEM_GROUP_CODE is null or si.group_code <= :TO_ITEM_GROUP_CODE)
     and (:FROM_ITEM_CODE is null or si.item_code >= :FROM_ITEM_CODE)
     and (:TO_ITEM_CODE is null or si.item_code <= :TO_ITEM_CODE)
     and si.store_code = st.store_code
     and si.group_code = itm_grp.item_group_code
     and si.item_code = itm.item_code
     and itm.item_group_code = itm_grp.item_group_code
     and (:P_PASSWORD_NUMBER = 0
          or si.store_code in (select sp.store_code from st_store_password sp where sp.password_number = :P_PASSWORD_NUMBER))
     and (:P_PASSWORD_NUMBER = 0
          or si.group_code in (select gp.group_code from st_group_password gp where gp.password_number = :P_PASSWORD_NUMBER))
),
k as (
  select store_code, group_code, item_code,
         case when :FROM_DATE is null then 0
              else get_balance(store_code, group_code, item_code, cast(:FROM_DATE as date) - 1) end opening_qty,
         (select max(u.factor) from st_item_unit u
           where u.group_code = x.group_code and u.item_code = x.item_code) max_unit_factor,
         (select max(decode(:LANG, 'A', un.name_a, un.name_e)) from st_item_unit u, st_unit un
           where u.group_code = x.group_code and u.item_code = x.item_code and u.unit_code = un.unit_code
             and nvl(u.basic_unit, 0) = 1) basic_unit_name,
         (select max(decode(:LANG, 'A', un.name_a, un.name_e)) from st_item_unit u, st_unit un
           where u.group_code = x.group_code and u.item_code = x.item_code and u.unit_code = un.unit_code
             and u.factor = (select max(u2.factor) from st_item_unit u2
                              where u2.group_code = x.group_code and u2.item_code = x.item_code)) max_unit_name
    from (select distinct store_code, group_code, item_code from q) x
),
r as (
  select q.*,
         case when :P_UNIT = 1 then 1 else nvl(k.max_unit_factor, 1) end unit_factor,
         case when :P_UNIT = 1 then k.basic_unit_name else k.max_unit_name end unit_name_p,
         k.opening_qty
         + sum(decode(q.effect, 1, 1, 2, -1, 3, -1, 4, 1, 5, -1, 6, 1) * q.basic_qty)
               over (partition by q.store_code, q.group_code, q.item_code
                     order by q.ord, q.trns_date, q.order22, q.date_serial, q.item_serial
                     rows unbounded preceding) balance_basic
    from q
    join k on k.store_code = q.store_code and k.group_code = q.group_code and k.item_code = q.item_code
)
select store_code,
       store_name,
       group_code,
       group_name,
       item_code,
       itm_name,
       peice_no,
       model_no,
       unit_name_p,
       unit_factor,
       ord,
       trns_date,
       doc_no,
       trns_desc,
       effect,
       date_serial,
       item_serial,
       quantity,
       basic_qty,
       unit_cost,
       unit_price,
       case when effect in (1, 4, 6) then basic_qty / unit_factor else 0 end rec_qty,
       case when effect in (2, 3, 5) then basic_qty / unit_factor else 0 end issue_qty,
       balance_basic / unit_factor current_balance
  from r
