-- VN_TRN_DETAILS (VN\FMB\VN_TRN_DETAILS_RDF.xml) - supplier transactions in detail (VN_MAINTRNS + VN_SUBTRNS bills).
-- ORA-00918 fix: M.TOTAL_VALUE and S.TOTAL_VALUE had the same name; as in the Reports groups the transaction
-- total is TOTAL_VALUE2 and the bill total is TOTAL_VALUE.
-- P_DATE1 / P_DATE2 are character parameters in the RDF (implicit date conversion); converted explicitly with
-- TO_DATE(..., 'DD/MM/YYYY') (DD-MM-YYYY is accepted as well).
-- Formula columns kept: CF_SUPPLIER_NAME, CF_TRNS_TYPE, CF_TOTAL_VALUE_CURR2 (transaction total * rate),
-- CF_TOTAL_VALUE_CURR (bill total * rate), CF_NET_VAL_CURR (bill net * rate).
select m.supplier_id,
       decode(:LANG, 'A', sp.name_a, sp.name_e) cf_supplier_name,
       m.trns_id,
       decode(:LANG, 'A', vt.description_a, vt.description_e) cf_trns_type,
       m.trns_serial,
       m.trns_date,
       m.currency_code,
       decode(:LANG, 'A', c.currency_desc, c.currency_desc_e) currency_desc,
       c.rate,
       m.disc_account,
       m.total_value total_value2,
       m.total_value * c.rate cf_total_value_curr2,
       s.bill_id1,
       s.bill_id2,
       s.total_value,
       s.total_value * c.rate cf_total_value_curr,
       s.disc_value,
       s.net_value,
       s.net_value * c.rate cf_net_val_curr
  from vn_maintrns m, vn_subtrns s, ac_currency c, supplier sp, vn_trnstype vt
 where (:P_SUPP1 is null or m.supplier_id >= :P_SUPP1)
   and (:P_SUPP2 is null or m.supplier_id <= :P_SUPP2)
   and (:P_DATE1 is null or m.trns_date >= to_date(:P_DATE1, 'DD/MM/YYYY'))
   and (:P_DATE2 is null or m.trns_date <= to_date(:P_DATE2, 'DD/MM/YYYY'))
   and m.trns_id = s.trns_id(+)
   and m.trns_serial = s.trns_serial(+)
   and c.currency_code = nvl(m.currency_code, 1)
   and sp.code(+) = m.supplier_id
   and vt.id(+) = m.trns_id
   and (:P_PASSWORD_NUMBER = 0
        or (m.supplier_id >= (select vp.from_supplier_code from vn_supplier_password vp
                               where vp.password_number = :P_PASSWORD_NUMBER)
            and m.supplier_id <= (select vp.to_supplier_code from vn_supplier_password vp
                                   where vp.password_number = :P_PASSWORD_NUMBER)))
   and (:P_PASSWORD_NUMBER = 0
        or m.trns_id in (select tp.trns_id from vn_trnstype_password tp
                          where tp.flag = 1 and tp.password_number = :P_PASSWORD_NUMBER))
