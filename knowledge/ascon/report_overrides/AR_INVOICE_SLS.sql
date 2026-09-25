-- AR_INVOICE_SLS (AR\FMB\AR_INVOICE_SLS_RDF.xml) - detailed invoice statement by salesman / customer.
-- Fix: "OR:C3" / "OR:C4" had no blank before the bind, so the bind was never mapped (DPY-4010 on :C3).
-- Groups G_SALESMAN_ID -> G_customer_id -> G_total_value are one query; flattened as one row per invoice.
-- Formula columns kept: SALES_NAME (CF_sales_name), CUST_NAME (CF_cust_name), CF_PAYED (total - residual)
-- and CF_CREDIT (customer payments before :D1, a customer-level formula repeated on each invoice row).
select a.salesman_id,
       decode(:LANG, 'A', sm.name_a, sm.name_e) sales_name,
       a.customer_id,
       decode(:LANG, 'A', cu.name_a, cu.name_e) cust_name,
       a.trns_date,
       a.doc_no,
       nvl(c.total_value, a.total_value) total_value,
       nvl(c.residual_value, c.residual_value) residual_value,
       nvl(nvl(c.total_value, a.total_value), 0) - nvl(c.residual_value, 0) cf_payed,
       round((sysdate - a.trns_date), 0) days_no,
       (select sum(p.total_value)
          from ar_maintrns p, ar_trnstype pt
         where p.trns_id = pt.id
           and pt.effect = 1
           and p.customer_id = a.customer_id
           and p.trns_date < :D1) cf_credit
  from ar_maintrns a, ar_trnstype b, ar_subtrns c, salesman sm, customer cu
 where a.trns_id = b.id
   and b.effect = 0
   and b.trns_type != 5
   and a.customer_id between :C1 and :C2
   and (a.salesman_id >= :C3 or :C3 is null)
   and (a.salesman_id <= :C4 or :C4 is null)
   and (a.trns_date >= :D1 or :D1 is null)
   and (a.trns_date <= :D2 or :D2 is null)
   and (a.trns_date + :A1) <= sysdate
   and a.trns_id = c.trns_id(+)
   and a.trns_serial = c.trns_serial(+)
   and a.mainarea_id = c.mainarea_id(+)
   and a.subarea_id = c.subarea_id(+)
   and sm.code(+) = a.salesman_id
   and cu.code(+) = a.customer_id
