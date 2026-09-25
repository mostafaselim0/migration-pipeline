-- ASCON ERP on APEX: generic document print view (run as SMART)
-- app_print.document renders a print-ready HTML page for any master/detail document from a JSON description
-- emitted by the generator: {"title":..,"table":..,"cols":[{"c":..,"l":..}],"details":[{"table":..,"title":..,"join":[[dcol,mcol]],"cols":[..]}]}
set define off
create or replace package app_print authid definer as
  procedure document (p_spec in clob, p_rowid in varchar2);
  procedure company_logo;
end app_print;
/
create or replace package body app_print as

  function e(p in varchar2) return varchar2 is begin return apex_escape.html(p); end;

  function ident(p in varchar2) return varchar2 is
  begin
    return sys.dbms_assert.simple_sql_name(upper(p));
  end;

  function fmt(p_val in varchar2, p_type in varchar2) return varchar2 is
    n number;
  begin
    if p_val is null then return null; end if;
    if p_type = 'M' then                                   -- money / quantity columns
      n := to_number(p_val);
      return to_char(n, 'FM999G999G999G990D00');
    end if;
    if p_type = 'N' then                                   -- codes, numbers, years: as stored
      n := to_number(p_val);
      return case when n = trunc(n) then to_char(n, 'FM999999999999999999990') else to_char(n) end;
    end if;
    return p_val;
  end;

  procedure company_logo is
    l_blob blob;
    l_mime varchar2(100) := 'image/png';
  begin
    select company_logo into l_blob from company where company_code = nvl(v('G_COMPANY_CODE'), company_code) and rownum = 1;
    if l_blob is null or dbms_lob.getlength(l_blob) = 0 then return; end if;
    if dbms_lob.substr(l_blob, 2, 1) = hextoraw('FFD8') then l_mime := 'image/jpeg'; end if;
    owa_util.mime_header(l_mime, false);
    htp.p('Content-length: ' || dbms_lob.getlength(l_blob));
    htp.p('Cache-Control: max-age=3600');
    owa_util.http_header_close;
    wpg_docload.download_file(l_blob);
  exception when no_data_found then null;
  end;

  procedure document (p_spec in clob, p_rowid in varchar2) is
    j        json_object_t := json_object_t.parse(p_spec);
    cols     json_array_t := j.get_array('cols');
    dets     json_array_t := j.get_array('details');
    l_en     boolean := app_sec.lang = 'en';
    l_table  varchar2(130) := ident(j.get_string('table'));
    l_sql    varchar2(32767);
    l_cur    integer;
    l_cnt    integer;
    l_val    varchar2(4000);
    l_desc   dbms_sql.desc_tab2;
    l_colcnt integer;
    type t_map is table of varchar2(4000) index by varchar2(130);
    l_master t_map;
    type t_sum is table of number index by pls_integer;
    l_sum    t_sum;
    c        json_object_t;
    d        json_object_t;
    dcols    json_array_t;
    jn       json_array_t;
    l_comp   company%rowtype;
  begin
    begin
      select * into l_comp from company where company_code = nvl(v('G_COMPANY_CODE'), company_code) and rownum = 1;
    exception when no_data_found then null;
    end;
    htp.p('<div class="ascon-print" dir="' || case when l_en then 'ltr' else 'rtl' end || '">');
    htp.p('<div class="ap-head"><div class="ap-comp"><div class="ap-comp-name">' || e(case when l_en then nvl(l_comp.company_desc_e, l_comp.company_desc) else l_comp.company_desc end) || '</div>'
       || '<div class="ap-comp-sub">' || case when l_comp.tax_no is not null then case when l_en then 'VAT No. ' else 'الرقم الضريبي ' end || e(l_comp.tax_no) end || '</div>'
       || '<div class="ap-comp-sub">' || e(nvl(l_comp.legal_address, l_comp.street)) || '</div></div>'
       || '<img class="ap-logo" src="' || apex_page.get_url(p_page => 0, p_request => 'APPLICATION_PROCESS=COMPANY_LOGO') || '" onerror="this.style.display=''none''">'
       || '</div>');
    htp.p('<h1 class="ap-title">' || e(j.get_string('title')) || '</h1>');
    -- master record
    l_sql := 'select ';
    for i in 0 .. cols.get_size - 1 loop
      c := treat(cols.get(i) as json_object_t);
      l_sql := l_sql || case when i > 0 then ', ' end
               || case when c.has('x') then c.get_string('x') else 'to_char(t.' || ident(c.get_string('c'))
               || case when c.get_string('t') = 'D' then ', ''DD/MM/YYYY''' end || ')' end;
    end loop;
    l_sql := l_sql || ' from ' || l_table || ' t where t.rowid = chartorowid(:r)';
    l_cur := dbms_sql.open_cursor;
    dbms_sql.parse(l_cur, l_sql, dbms_sql.native);
    dbms_sql.bind_variable(l_cur, ':r', p_rowid);
    for i in 1 .. cols.get_size loop dbms_sql.define_column(l_cur, i, l_val, 4000); end loop;
    l_cnt := dbms_sql.execute(l_cur);
    if p_rowid is null or dbms_sql.fetch_rows(l_cur) = 0 then
      dbms_sql.close_cursor(l_cur);
      htp.p('<p class="ap-empty">' || case when l_en then 'No document selected.' else 'لم يتم اختيار مستند للطباعة.' end || '</p></div>');
      return;
    else
      htp.p('<table class="ap-fields"><tr>');
      declare
        k pls_integer := 0;
      begin
        for i in 1 .. cols.get_size loop
          c := treat(cols.get(i - 1) as json_object_t);
          dbms_sql.column_value(l_cur, i, l_val);
          l_master(upper(c.get_string('c'))) := l_val;
          if l_val is not null then                              -- empty header fields are not printed
            k := k + 1;
            htp.p(case when k > 1 and mod(k - 1, 3) = 0 then '</tr><tr>' end
               || '<td><span class="ap-l">' || e(c.get_string('l')) || '</span><span class="ap-v">' || e(fmt(l_val, c.get_string('t'))) || '</span></td>');
          end if;
        end loop;
      end;
      htp.p('</tr></table>');
    end if;
    dbms_sql.close_cursor(l_cur);
    -- detail blocks
    for k in 0 .. nvl(dets.get_size, 0) - 1 loop
      d := treat(dets.get(k) as json_object_t);
      dcols := d.get_array('cols'); jn := d.get_array('join');
      l_sql := 'select ';
      for i in 0 .. dcols.get_size - 1 loop
        c := treat(dcols.get(i) as json_object_t);
        l_sql := l_sql || case when i > 0 then ', ' end
                 || case when c.has('x') then c.get_string('x') else 'to_char(t.' || ident(c.get_string('c'))
                 || case when c.get_string('t') = 'D' then ', ''DD/MM/YYYY''' end || ')' end;
      end loop;
      l_sql := l_sql || ' from ' || ident(d.get_string('table')) || ' t where 1 = 1';
      for i in 0 .. jn.get_size - 1 loop
        l_sql := l_sql || ' and t.' || ident(treat(jn.get(i) as json_array_t).get_string(0)) || ' = :b' || i;
      end loop;
      -- extra filter of the detail grid (rules.blocks.<TABLE>.where; the document's values come from its row :r)
      if d.has('where') then l_sql := l_sql || ' and (' || d.get_string('where') || ')'; end if;
      if d.has('order') then l_sql := l_sql || ' order by t.' || replace(d.get_string('order'), ', ', ', t.'); end if;
      l_cur := dbms_sql.open_cursor;
      dbms_sql.parse(l_cur, l_sql, dbms_sql.native);
      for i in 0 .. jn.get_size - 1 loop
        dbms_sql.bind_variable(l_cur, ':b' || i, l_master(upper(treat(jn.get(i) as json_array_t).get_string(1))));
      end loop;
      if d.has('where') and instr(d.get_string('where'), ':r') > 0 then dbms_sql.bind_variable(l_cur, ':r', p_rowid); end if;
      for i in 1 .. dcols.get_size loop dbms_sql.define_column(l_cur, i, l_val, 4000); l_sum(i) := null; end loop;
      l_cnt := dbms_sql.execute(l_cur);
      -- read all lines first, then print only the columns that carry a value (not empty, not zero) on this document
      declare
        type t_row  is table of varchar2(4000) index by pls_integer;
        type t_rows is table of t_row index by pls_integer;
        type t_flag is table of boolean index by pls_integer;
        l_rows t_rows;
        l_used t_flag;
        n      pls_integer := 0;
      begin
        for i in 1 .. dcols.get_size loop l_used(i) := false; end loop;
        while dbms_sql.fetch_rows(l_cur) > 0 loop
          n := n + 1;
          for i in 1 .. dcols.get_size loop
            c := treat(dcols.get(i - 1) as json_object_t);
            dbms_sql.column_value(l_cur, i, l_val);
            l_rows(n)(i) := l_val;
            if l_val is not null and not (c.get_string('t') in ('N', 'M') and to_number(l_val) = 0) then l_used(i) := true; end if;
            if c.get_string('t') = 'M' and c.has('sum') and l_val is not null then
              l_sum(i) := nvl(l_sum(i), 0) + to_number(l_val);
            end if;
          end loop;
        end loop;
        dbms_sql.close_cursor(l_cur);
        if n = 0 then continue; end if;
        htp.p('<h2 class="ap-sub">' || e(d.get_string('title')) || '</h2><table class="ap-lines"><thead><tr><th>#</th>');
        for i in 1 .. dcols.get_size loop
          if l_used(i) then htp.p('<th>' || e(treat(dcols.get(i - 1) as json_object_t).get_string('l')) || '</th>'); end if;
        end loop;
        htp.p('</tr></thead><tbody>');
        for r in 1 .. n loop
          htp.p('<tr><td>' || r || '</td>');
          for i in 1 .. dcols.get_size loop
            if l_used(i) then
              c := treat(dcols.get(i - 1) as json_object_t);
              htp.p('<td class="' || case when c.get_string('t') in ('N', 'M') then 'n' end || '">' || e(fmt(l_rows(r)(i), c.get_string('t'))) || '</td>');
            end if;
          end loop;
          htp.p('</tr>');
        end loop;
        htp.p('</tbody><tfoot><tr><td>' || case when l_en then 'Total' else 'الإجمالي' end || '</td>');
        for i in 1 .. dcols.get_size loop
          if l_used(i) then
            htp.p('<td class="n">' || case when l_sum(i) is not null then to_char(l_sum(i), 'FM999G999G999G990D00') end || '</td>');
          end if;
        end loop;
        htp.p('</tr></tfoot></table>');
      end;
    end loop;
    htp.p('<div class="ap-sign"><div>' || case when l_en then 'Prepared by' else 'إعداد' end || '<br>' || e(v('G_USER_NAME')) || '</div><div>'
       || case when l_en then 'Reviewed by' else 'مراجعة' end || '</div><div>' || case when l_en then 'Approved by' else 'اعتماد' end || '</div></div>');
    htp.p('<div class="ap-foot">' || to_char(sysdate, 'DD/MM/YYYY HH24:MI') || '</div></div>');
  exception when others then
    if dbms_sql.is_open(l_cur) then dbms_sql.close_cursor(l_cur); end if;
    raise;
  end document;

end app_print;
/
show errors package body app_print
