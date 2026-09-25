-- ST_TRANSFORM_COMPARE (ST\FMB\ST_TRANSFORM_COMPARE_RDF.xml) - store transfer comparison: items sent
-- (transfer-out, effect 5) against items received (transfer-in, effect 6) per transfer serial.
-- ORA-00918 fix: the duplicated select-list columns get the Reports item names
-- (TRNSFER_SERIAL / TRNSFER_SERIAL1, TRNSFER_FROM_STORE / TRNSFER_FROM_STORE1).
-- The store range binds :FROM_STORE_CODE / :TO_STORE_CODE are not RDF user parameters (they also clash with
-- the FROM_STORE_CODE / TO_STORE_CODE columns), so that optional filter is dropped.
-- Formula columns kept: store names (CF_FROM_STORE_NAME / CF_TO_STORE_CODE), item names, and the placeholders
-- FROM_DOC_NO / FROM_TRNS_DATE / TO_DOC_NO / TO_TRNS_DATE filled by TRNS_TYPE_FROM / TRNS_TYPE_TO.
with q as (
  select fm.trnsfer_serial trnsfer_serial,
         tm.trnsfer_serial trnsfer_serial1,
         fm.trnsfer_from_store trnsfer_from_store,
         tm.trnsfer_from_store trnsfer_from_store1,
         fd.item_code sent_item_code,
         fd.group_code sent_group_code,
         td.item_code recieved_item_code,
         td.group_code recieved_group_code,
         fm.store_code from_store_code,
         tm.store_code to_store_code,
         fd.basic_qty sent_quantity,
         td.basic_qty recieved_quantity,
         fd.unit_price from_cost,
         td.unit_cost to_cost
    from st_trns_mast fm, st_trns_mast tm, st_trns_det fd, st_trns_det td, st_trns_type ft, st_trns_type tt
   where (fd.group_code >= :FROM_ITEM_GROUP_CODE or :FROM_ITEM_GROUP_CODE is null)
     and (fd.group_code <= :TO_ITEM_GROUP_CODE or :TO_ITEM_GROUP_CODE is null)
     and (fd.item_code >= :FROM_ITEM_CODE or :FROM_ITEM_CODE is null)
     and (fd.item_code <= :TO_ITEM_CODE or :TO_ITEM_CODE is null)
     and fm.trnsfer_serial = tm.trnsfer_serial(+)
     and fm.trnsfer_from_store = tm.trnsfer_from_store(+)
     and (fm.trns_type_code = ft.trns_type_code and ft.effect = 5)
     and (tm.trns_type_code = tt.trns_type_code and tt.effect = 6)
     and fm.trnsfer_serial between :P_FROM_TRANSFER_SERIAL and :P_TO_TRANSFER_SERIAL
     and fm.trns_type_code = fd.trns_type_code
     and fm.trns_serial = fd.trns_serial
     and tm.trns_type_code = td.trns_type_code
     and tm.trns_serial = td.trns_serial
     and nvl(fm.delete_flag, 0) = 0
     and nvl(tm.delete_flag, 0) = 0
     and fd.item_code = td.item_code(+)
     and fd.group_code = td.group_code(+)
     and fd.item_serial = td.item_serial(+)
     and (:P_FROM_DATE is null or fm.trns_date >= :P_FROM_DATE)
     and (:P_TO_DATE is null or fm.trns_date <= :P_TO_DATE)
     and (:P_FROM_DATE is null or tm.trns_date >= :P_FROM_DATE)
     and (:P_TO_DATE is null or tm.trns_date <= :P_TO_DATE)
     and (:PASSWORD_NUMBER = 0
          or fd.group_code in (select gp.group_code from st_group_password gp where gp.password_number = :PASSWORD_NUMBER))
     and (:PASSWORD_NUMBER = 0
          or fm.store_code in (select sp.store_code from st_store_password sp where sp.password_number = :PASSWORD_NUMBER))
     and (:PASSWORD_NUMBER = 0
          or td.group_code in (select gp.group_code from st_group_password gp where gp.password_number = :PASSWORD_NUMBER))
     and (:PASSWORD_NUMBER = 0
          or tm.store_code in (select sp.store_code from st_store_password sp where sp.password_number = :PASSWORD_NUMBER))
  union
  select fm.trnsfer_serial,
         fm.trnsfer_serial,
         fm.trnsfer_from_store,
         fm.trnsfer_from_store,
         fd.item_code,
         fd.group_code,
         fd.item_code,
         fd.group_code,
         fm.store_code,
         fm.trnsfer_to_store,
         fd.basic_qty,
         0,
         fd.unit_cost,
         0
    from st_trns_mast fm, st_trns_det fd, st_trns_type ft
   where (fd.group_code >= :FROM_ITEM_GROUP_CODE or :FROM_ITEM_GROUP_CODE is null)
     and (fd.group_code <= :TO_ITEM_GROUP_CODE or :TO_ITEM_GROUP_CODE is null)
     and (fd.item_code >= :FROM_ITEM_CODE or :FROM_ITEM_CODE is null)
     and (fd.item_code <= :TO_ITEM_CODE or :TO_ITEM_CODE is null)
     and fm.trnsfer_serial between :P_FROM_TRANSFER_SERIAL and :P_TO_TRANSFER_SERIAL
     and fm.trns_date between :P_FROM_DATE and :P_TO_DATE
     and (fm.trns_type_code = ft.trns_type_code and ft.effect = 5)
     and fm.trns_type_code = fd.trns_type_code
     and fm.trns_serial = fd.trns_serial
     and nvl(fm.delete_flag, 0) = 0
     and (fd.group_code, fd.item_code) not in
         (select td.group_code, td.item_code
            from st_trns_mast tm, st_trns_det td, st_trns_type tt
           where tm.trnsfer_serial between :P_FROM_TRANSFER_SERIAL and :P_TO_TRANSFER_SERIAL
             and tm.trns_date between :P_FROM_DATE and :P_TO_DATE
             and tm.trnsfer_serial = fm.trnsfer_serial
             and tm.trnsfer_from_store = fm.trnsfer_from_store
             and (tm.trns_type_code = tt.trns_type_code and tt.effect = 6)
             and tm.trns_type_code = td.trns_type_code
             and tm.trns_serial = td.trns_serial
             and nvl(tm.delete_flag, 0) = 0)
     and (:PASSWORD_NUMBER = 0
          or fd.group_code in (select gp.group_code from st_group_password gp where gp.password_number = :PASSWORD_NUMBER))
     and (:PASSWORD_NUMBER = 0
          or fm.store_code in (select sp.store_code from st_store_password sp where sp.password_number = :PASSWORD_NUMBER))
  union
  select tm.trnsfer_serial,
         tm.trnsfer_serial,
         tm.trnsfer_from_store,
         tm.trnsfer_from_store,
         td.item_code,
         td.group_code,
         td.item_code,
         td.group_code,
         tm.trnsfer_from_store,
         tm.store_code,
         0,
         td.basic_qty,
         0,
         td.unit_cost
    from st_trns_mast tm, st_trns_det td, st_trns_type tt
   where (td.group_code >= :FROM_ITEM_GROUP_CODE or :FROM_ITEM_GROUP_CODE is null)
     and (td.group_code <= :TO_ITEM_GROUP_CODE or :TO_ITEM_GROUP_CODE is null)
     and (td.item_code >= :FROM_ITEM_CODE or :FROM_ITEM_CODE is null)
     and (td.item_code <= :TO_ITEM_CODE or :TO_ITEM_CODE is null)
     and tm.trnsfer_serial between :P_FROM_TRANSFER_SERIAL and :P_TO_TRANSFER_SERIAL
     and tm.trns_date between :P_FROM_DATE and :P_TO_DATE
     and (tm.trns_type_code = tt.trns_type_code and tt.effect = 6)
     and tm.trns_type_code = td.trns_type_code
     and tm.trns_serial = td.trns_serial
     and nvl(tm.delete_flag, 0) = 0
     and (td.group_code, td.item_code) not in
         (select fd.group_code, fd.item_code
            from st_trns_mast fm, st_trns_det fd, st_trns_type ft
           where fm.trnsfer_serial between :P_FROM_TRANSFER_SERIAL and :P_TO_TRANSFER_SERIAL
             and fm.trns_date between :P_FROM_DATE and :P_TO_DATE
             and fm.trnsfer_serial = tm.trnsfer_serial
             and fm.trnsfer_from_store = tm.trnsfer_from_store
             and (fm.trns_type_code = ft.trns_type_code and ft.effect = 5)
             and fm.trns_type_code = fd.trns_type_code
             and fm.trns_serial = fd.trns_serial
             and nvl(fm.delete_flag, 0) = 0)
     and (:PASSWORD_NUMBER = 0
          or td.group_code in (select gp.group_code from st_group_password gp where gp.password_number = :PASSWORD_NUMBER))
     and (:PASSWORD_NUMBER = 0
          or tm.store_code in (select sp.store_code from st_store_password sp where sp.password_number = :PASSWORD_NUMBER))
)
select q.trnsfer_serial,
       q.trnsfer_serial1,
       q.trnsfer_from_store,
       q.trnsfer_from_store1,
       q.from_store_code,
       decode(:LANG, 'A', fs.name_a, fs.name_e) from_store_name,
       q.to_store_code,
       decode(:LANG, 'A', ts.name_a, ts.name_e) to_store_name,
       (select max(m1.doc_no) from st_trns_mast m1
         where m1.trnsfer_serial = q.trnsfer_serial and m1.store_code = q.from_store_code
           and m1.trnsfer_to_store = q.to_store_code) from_doc_no,
       (select max(m1.trns_date) from st_trns_mast m1
         where m1.trnsfer_serial = q.trnsfer_serial and m1.store_code = q.from_store_code
           and m1.trnsfer_to_store = q.to_store_code) from_trns_date,
       (select max(m2.doc_no) from st_trns_mast m2
         where m2.trnsfer_serial = q.trnsfer_serial and m2.store_code = q.to_store_code
           and m2.trnsfer_from_store = q.from_store_code) to_doc_no,
       (select max(m2.trns_date) from st_trns_mast m2
         where m2.trnsfer_serial = q.trnsfer_serial and m2.store_code = q.to_store_code
           and m2.trnsfer_from_store = q.from_store_code) to_trns_date,
       q.sent_group_code,
       q.sent_item_code,
       decode(:LANG, 'A', si.name_a, si.name_e) sent_item_name,
       q.sent_quantity,
       q.from_cost,
       q.recieved_group_code,
       q.recieved_item_code,
       decode(:LANG, 'A', ri.name_a, ri.name_e) recieved_item_name,
       q.recieved_quantity,
       q.to_cost
  from q
  left join st_store fs on fs.store_code = q.from_store_code
  left join st_store ts on ts.store_code = q.to_store_code
  left join st_item si on si.item_code = q.sent_item_code and si.item_group_code = q.sent_group_code
  left join st_item ri on ri.item_code = q.recieved_item_code and ri.item_group_code = q.recieved_group_code
