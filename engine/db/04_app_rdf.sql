-- ASCON ERP on APEX: runtime for the legacy Oracle Reports document layouts (run as SMART)
-- app/gen/rdfprint.py compiles an RDF into a package RPT_<ID> (the report's own PL/SQL) and stores the data model and the
-- page layout in APP_RDF_REPORT.  APP_RDF runs the report queries with the document parameters, builds the break groups,
-- computes formula columns, summaries and format triggers, formats the fields with the report's format masks and hands the
-- data plus the layout to the browser renderer (APP_RDF_ASSET 'rdfprint.js'), which places every object where the legacy
-- report placed it.
set define off

declare
  procedure ddl (p in varchar2) is begin execute immediate p; exception when others then if sqlcode not in (-955, -2264, -1430) then raise; end if; end;
begin
  ddl('create type app_rdf_dates as table of date');
  ddl('create table app_rdf_report (
         name        varchar2(128) constraint app_rdf_report_pk primary key,
         pkg         varchar2(128) not null,
         model       clob,
         layout      clob,
         source_file varchar2(400),
         problems    varchar2(4000),
         loaded_on   date)');
  ddl('create table app_rdf_asset (
         name     varchar2(128) constraint app_rdf_asset_pk primary key,
         content  clob,
         loaded_on date)');
end;
/

-- Oracle Reports built-in package: the subset used by the ASCON reports.  Attribute setters called from format triggers are
-- recorded and passed to the renderer (colours, fill, fonts, borders, field text); messages are collected for debugging.
create or replace package srw authid definer as
  program_abort      exception;
  do_sql_failure     exception;
  user_exit_failure  exception;
  unknown_user_exit  exception;
  run_report_failure exception;
  null_arguments     exception;
  maxrow_inerr       exception;
  bold_weight      constant varchar2(20) := 'bold';
  demibold_weight  constant varchar2(20) := 'bold';
  extrabold_weight constant varchar2(20) := 'bold';
  medium_weight    constant varchar2(20) := 'normal';
  light_weight     constant varchar2(20) := 'normal';
  plain_style      constant varchar2(20) := 'normal';
  italic_style     constant varchar2(20) := 'italic';
  oblique_style    constant varchar2(20) := 'italic';
  underline_style  constant varchar2(20) := 'underline';
  outline_style    constant varchar2(20) := 'normal';
  shadow_style     constant varchar2(20) := 'normal';
  inverted_style   constant varchar2(20) := 'normal';
  blink_style      constant varchar2(20) := 'normal';
  procedure message (p_num in number, p_msg in varchar2);
  procedure set_text_color (p_color in varchar2);
  procedure set_foreground_fill_color (p_color in varchar2);
  procedure set_background_fill_color (p_color in varchar2);
  procedure set_fill_pattern (p_pattern in varchar2);
  procedure set_foreground_border_color (p_color in varchar2);
  procedure set_background_border_color (p_color in varchar2);
  procedure set_border_pattern (p_pattern in varchar2);
  procedure set_border_width (p_width in number);
  procedure set_font_face (p_face in varchar2);
  procedure set_font_size (p_size in number);
  procedure set_font_weight (p_weight in varchar2);
  procedure set_font_style (p_style in varchar2);
  procedure set_field_char (p_type in number, p_value in varchar2);
  procedure set_field_num (p_type in number, p_value in number);
  procedure set_field_date (p_type in number, p_value in date);
  procedure set_format_mask (p_mask in varchar2);
  procedure run_report (p_command in varchar2);
  procedure do_sql (p_sql in varchar2);
  procedure user_exit (p_command in varchar2);
  procedure set_maxrow (p_query in varchar2, p_maxrow in number);
  procedure reference (p_value in varchar2);
  procedure reference (p_value in number);
  procedure reference (p_value in date);
  -- runtime side
  procedure reset_attrs;
  function  attrs return varchar2;
  procedure reset_messages;
  function  messages return varchar2;
end srw;
/
create or replace package body srw as
  g_attrs varchar2(4000);
  g_msgs  varchar2(32767);
  procedure add (k in varchar2, v in varchar2) is
  begin
    g_attrs := substr(g_attrs || '|' || k || '=' || replace(replace(v, '|', ' '), '=', ' '), 1, 4000);
  end;
  procedure message (p_num in number, p_msg in varchar2) is
  begin g_msgs := substr(g_msgs || p_num || ': ' || p_msg || chr(10), 1, 32000); end;
  procedure set_text_color (p_color in varchar2) is begin add('tc', p_color); end;
  procedure set_foreground_fill_color (p_color in varchar2) is begin add('ff', p_color); end;
  procedure set_background_fill_color (p_color in varchar2) is begin add('bf', p_color); end;
  procedure set_fill_pattern (p_pattern in varchar2) is begin add('fp', p_pattern); end;
  procedure set_foreground_border_color (p_color in varchar2) is begin add('bc', p_color); end;
  procedure set_background_border_color (p_color in varchar2) is begin null; end;
  procedure set_border_pattern (p_pattern in varchar2) is begin add('bp', p_pattern); end;
  procedure set_border_width (p_width in number) is begin add('bw', to_char(p_width, 'TM9', 'nls_numeric_characters=''.,''')); end;
  procedure set_font_face (p_face in varchar2) is begin add('fn', p_face); end;
  procedure set_font_size (p_size in number) is begin add('fs', to_char(p_size, 'TM9', 'nls_numeric_characters=''.,''')); end;
  procedure set_font_weight (p_weight in varchar2) is begin add('fw', p_weight); end;
  procedure set_font_style (p_style in varchar2) is begin add('fy', p_style); end;
  procedure set_field_char (p_type in number, p_value in varchar2) is begin add('v', p_value); end;
  procedure set_field_num (p_type in number, p_value in number) is begin add('v', to_char(p_value, 'TM9', 'nls_numeric_characters=''.,''')); end;
  procedure set_field_date (p_type in number, p_value in date) is begin add('v', to_char(p_value, 'DD-MON-RR', 'nls_date_language=AMERICAN')); end;
  procedure set_format_mask (p_mask in varchar2) is begin null; end;
  procedure run_report (p_command in varchar2) is begin null; end;
  procedure do_sql (p_sql in varchar2) is
  begin
    execute immediate p_sql;
  exception when others then
    message(0, sqlerrm); raise do_sql_failure;
  end;
  procedure user_exit (p_command in varchar2) is begin null; end;
  procedure set_maxrow (p_query in varchar2, p_maxrow in number) is begin null; end;
  procedure reference (p_value in varchar2) is begin null; end;
  procedure reference (p_value in number) is begin null; end;
  procedure reference (p_value in date) is begin null; end;
  procedure reset_attrs is begin g_attrs := null; end;
  function attrs return varchar2 is begin return g_attrs; end;
  procedure reset_messages is begin g_msgs := null; end;
  function messages return varchar2 is begin return g_msgs; end;
end srw;
/

-- RPT2XLS: the "export to Excel" utility embedded in 169 legacy reports (its body drives Excel through OLE2 on the client).
-- Same specification, empty body: format triggers call put_cell / new_line and return as before; Excel export in APEX is
-- the download of the report page.
create or replace package rpt2xls authid definer as
  bold      constant binary_integer := 1;
  italic    constant binary_integer := 2;
  underline constant binary_integer := 4;
  subtype xlhalign is binary_integer;
  center                constant xlhalign := -4108;
  centeracrossselection constant xlhalign := 7;
  distributed           constant xlhalign := -4117;
  fill                  constant xlhalign := 5;
  general               constant xlhalign := 1;
  justify               constant xlhalign := -4130;
  left                  constant xlhalign := -4131;
  right                 constant xlhalign := -4152;
  function get_number_cell_mapping (v_number number) return char;
  procedure put_cell (colno binary_integer, cellvalue in varchar2, fontname in varchar2 default null, fontsize in binary_integer default null,
                      fontstyle in binary_integer default null, fontcolor in binary_integer default null, bgrcolor in binary_integer default null,
                      format in varchar2 default null, horizontalalignment in xlhalign default null, verticalalignment in xlhalign default null,
                      border_linestyle in binary_integer default 1, border_weight in binary_integer default 1,
                      border_colorindex in binary_integer default 0, wraptext boolean default false, x_merge_offset integer default 0,
                      y_merge_offset integer default 0, rowheight integer default null, columnwidth integer default null);
  procedure new_line;
  procedure run;
  procedure release_memory;
  currentrow binary_integer := 1;
  var_index  binary_integer := 1;
end rpt2xls;
/
create or replace package body rpt2xls as
  function get_number_cell_mapping (v_number number) return char is
  begin
    return case when v_number > 26 then chr(ascii('A') + trunc((v_number - 1) / 26) - 1) end || chr(ascii('A') + mod(v_number - 1, 26));
  end;
  procedure put_cell (colno binary_integer, cellvalue in varchar2, fontname in varchar2 default null, fontsize in binary_integer default null,
                      fontstyle in binary_integer default null, fontcolor in binary_integer default null, bgrcolor in binary_integer default null,
                      format in varchar2 default null, horizontalalignment in xlhalign default null, verticalalignment in xlhalign default null,
                      border_linestyle in binary_integer default 1, border_weight in binary_integer default 1,
                      border_colorindex in binary_integer default 0, wraptext boolean default false, x_merge_offset integer default 0,
                      y_merge_offset integer default 0, rowheight integer default null, columnwidth integer default null) is
  begin var_index := var_index + 1; end;
  procedure new_line is begin currentrow := currentrow + 1; end;
  procedure run is begin null; end;
  procedure release_memory is begin currentrow := 1; var_index := 1; end;
end rpt2xls;
/

create or replace package app_rdf authid definer as
  -- data of one report run as JSON (params: 'NAME=value;NAME=value', values as text; dates DD/MM/YYYY)
  function data_json (p_report in varchar2, p_params in varchar2) return clob;
  -- print view: renderer script, layout, data and the call that draws the pages (PL/SQL dynamic content region)
  procedure render (p_report in varchar2, p_params in varchar2, p_title in varchar2 default null);
end app_rdf;
/
create or replace package body app_rdf as

  type t_cell is record (t varchar2(1), c varchar2(32767), n number, d date, b blob);
  type t_row  is table of t_cell index by pls_integer;
  type t_rows is table of t_row index by pls_integer;
  type t_idx  is table of pls_integer index by pls_integer;
  type t_acc  is record (fn varchar2(20), src varchar2(128), t varchar2(1), n number, cnt number, d date, c varchar2(32767), started boolean);
  type t_accs is table of t_acc index by varchar2(128);
  type t_blobs is table of blob index by varchar2(128);
  type t_cache is table of t_rows index by varchar2(32767);

  g_pkg     varchar2(128);
  g_model   json_object_t;
  g_types   json_object_t;
  g_scopes  json_object_t;
  g_sums    json_object_t;
  g_queries json_array_t;
  g_accs    t_accs;
  g_blobs   t_blobs;
  g_errors  varchar2(32767);
  g_cache   t_cache;
  g_depth   pls_integer := 0;

  c_nls_num  constant varchar2(40) := 'nls_numeric_characters=''.,''';
  c_nls_date constant varchar2(40) := 'nls_date_language=AMERICAN';
  -- the legacy Forms / Reports sessions ran with this date format: report PL/SQL relies on it for implicit conversions
  c_legacy_date constant varchar2(20) := 'DD-MM-RRRR';
  -- a printed report is for reading on paper: beyond this many rows per query the browser cannot draw it
  c_max_rows constant pls_integer := 20000;

  g_group_of json_object_t;
  g_only     apex_t_varchar2;       -- when set, only these summaries are fed (the column pass of a matrix)
  type t_map  is table of t_idx index by varchar2(4000);
  type t_maps is table of t_map index by varchar2(30000);
  g_maps     t_maps;                -- child query rows indexed by their link values, per query run
  g_last_key varchar2(32767);       -- cache key of the last query run
  g_cached   pls_integer := 0;      -- rows held in g_cache
  -- memory budget of the query cache (rows over all cached queries): a huge unfiltered report must not exhaust the PGA
  c_cache_rows constant pls_integer := 60000;

  procedure log_error (p in varchar2) is
  begin
    if p is not null then g_errors := substr(g_errors || p || chr(10), 1, 32000); end if;
  end;

  function to_num (p in varchar2) return number is
  begin
    return to_number(p, '999999999999999999999999999999D9999999999', 'nls_numeric_characters=''.,''');
  exception when others then
    begin return to_number(p); exception when others then return null; end;
  end;

  function type_of (p_name in varchar2) return varchar2 is
  begin
    return case when g_types.has(p_name) then g_types.get_string(p_name) else null end;
  end;

  function arr (p in json_array_t) return apex_t_varchar2 is
    r apex_t_varchar2 := apex_t_varchar2();
  begin
    if p is null then return r; end if;
    for i in 0 .. p.get_size - 1 loop r.extend; r(r.count) := p.get_string(i); end loop;
    return r;
  end;

  -- ---------------------------------------------------------------- report package calls (dynamic: one package per report)
  procedure pkg_set (p_names in apex_t_varchar2, p_c in apex_t_varchar2, p_n in apex_t_number, p_d in app_rdf_dates) is
  begin
    if p_names.count = 0 then return; end if;
    execute immediate 'begin ' || g_pkg || '.set_row(:1, :2, :3, :4); end;' using p_names, p_c, p_n, p_d;
  end;

  procedure pkg_get (p_names in apex_t_varchar2, o_c out apex_t_varchar2, o_n out apex_t_number, o_d out app_rdf_dates) is
  begin
    execute immediate 'begin ' || g_pkg || '.get_row(:1, :2, :3, :4); end;' using p_names, out o_c, out o_n, out o_d;
  end;

  procedure pkg_calc (p_names in apex_t_varchar2) is
    l_err varchar2(4000);
  begin
    if p_names.count = 0 then return; end if;
    execute immediate 'begin ' || g_pkg || '.calc(:1, :2); end;' using p_names, out l_err;
    if g_depth <= 1 then log_error(l_err); end if;     -- first pass errors are expected (summaries not yet known)
  end;

  function pkg_trigs (p_fns in apex_t_varchar2) return apex_t_varchar2 is
    r apex_t_varchar2;
  begin
    execute immediate 'begin :r := ' || g_pkg || '.trigs(:1); end;' using out r, p_fns;
    return r;
  end;

  function pkg_report_trigger (p_fn in varchar2) return varchar2 is
    r varchar2(1);
  begin
    execute immediate 'begin :r := ' || g_pkg || '.report_trigger(:1); end;' using out r, p_fn;
    return r;
  end;

  procedure set_one (p_name in varchar2, p_c in varchar2, p_n in number, p_d in date) is
  begin
    pkg_set(apex_t_varchar2(p_name), apex_t_varchar2(p_c), apex_t_number(p_n), app_rdf_dates(p_d));
  end;

  -- ---------------------------------------------------------------- formatting (Reports format masks are Oracle masks; N = digit)
  function fmt_n (p in number, p_mask in varchar2) return varchar2 is
    m varchar2(200);
  begin
    if p is null then return null; end if;
    if p_mask is null then return to_char(p, 'TM9', c_nls_num); end if;
    m := translate(p_mask, 'Nn', '99');
    return trim(to_char(p, m, c_nls_num));
  exception when others then
    return to_char(p, 'TM9', c_nls_num);
  end;

  function fmt_d (p in date, p_mask in varchar2) return varchar2 is
  begin
    if p is null then return null; end if;
    return to_char(p, nvl(p_mask, c_legacy_date), c_nls_date);
  exception when others then
    return to_char(p, c_legacy_date, c_nls_date);
  end;

  -- ---------------------------------------------------------------- parameters
  procedure set_params (p_params in varchar2) is
    l_params json_array_t := g_model.get_array('params');
    -- NAME=value pairs separated by chr(30) (values may contain ';'), or by ';' when typed by hand
    l_given  apex_t_varchar2 := apex_string.split(p_params, case when instr(p_params, chr(30)) > 0 then chr(30) else ';' end);
    type t_map is table of varchar2(4000) index by varchar2(128);
    l_map t_map;
    l_p json_object_t;
    l_n varchar2(128); l_t varchar2(1); l_v varchar2(4000);
    k pls_integer;
  begin
    for i in 1 .. l_given.count loop
      k := instr(l_given(i), '=');
      if k > 1 then l_map(upper(trim(substr(l_given(i), 1, k - 1)))) := substr(l_given(i), k + 1); end if;
    end loop;
    for i in 0 .. l_params.get_size - 1 loop
      l_p := treat(l_params.get(i) as json_object_t);
      l_n := l_p.get_string('n'); l_t := l_p.get_string('t');
      l_v := case when l_map.exists(l_n) then l_map(l_n) else l_p.get_string('init') end;
      begin
        case l_t
          when 'N' then set_one(l_n, null, to_num(l_v), null);
          when 'D' then set_one(l_n, null, null, case when l_v is not null then to_date(l_v, 'DD/MM/YYYY', c_nls_date) end);
          else set_one(l_n, l_v, null, null);
        end case;
      exception when others then
        begin
          if l_t = 'N' then set_one(l_n, null, to_number(l_v), null); end if;
          if l_t = 'D' then set_one(l_n, null, null, to_date(l_v)); end if;
        exception when others then log_error('parameter ' || l_n || ': ' || sqlerrm);
        end;
      end;
    end loop;
  end;

  -- ---------------------------------------------------------------- queries
  function lexicals (p_sql in varchar2, p_lex in json_array_t) return varchar2 is
    l_sql varchar2(32767) := p_sql;
    l_c apex_t_varchar2; l_n apex_t_number; l_d app_rdf_dates;
    l_names apex_t_varchar2 := arr(p_lex);
  begin
    if l_names.count = 0 then return l_sql; end if;
    pkg_get(l_names, l_c, l_n, l_d);
    for i in 1 .. l_names.count loop
      l_sql := regexp_replace(l_sql, '&' || l_names(i) || '([^A-Za-z0-9_$#]|$)',
                              replace(nvl(l_c(i), nvl(to_char(l_n(i), 'TM9', c_nls_num), ' ')), '\', '\\') || '\1', 1, 0, 'i');
    end loop;
    return l_sql;
  end;

  function run_query (p_q in json_object_t) return t_rows is
    l_sql   varchar2(32767) := lexicals(p_q.get_string('sql'), p_q.get_array('lex'));
    l_binds apex_t_varchar2 := arr(p_q.get_array('binds'));
    l_c apex_t_varchar2; l_n apex_t_number; l_d app_rdf_dates;
    l_key   varchar2(32767);
    cur     integer;
    cnt     integer;
    dsc     dbms_sql.desc_tab3;
    ign     integer;
    l_rows  t_rows;
    v_c varchar2(32767); v_n number; v_d date; v_cl clob; v_b blob;
    l_t     varchar2(1);
  begin
    -- bind references brought in by lexical values (e.g. &P_ITEM_RANGE = 'and item_code between :FROM_ITEM and :TO_ITEM')
    declare k pls_integer := 1; b varchar2(128);
    begin
      loop
        b := upper(regexp_substr(l_sql, ':([A-Za-z][A-Za-z0-9_$#]*)', 1, k, 'i', 1));
        exit when b is null;
        if g_types.has(b) and b not member of l_binds then l_binds.extend; l_binds(l_binds.count) := b; end if;
        k := k + 1;
      end loop;
    end;
    if l_binds.count > 0 then pkg_get(l_binds, l_c, l_n, l_d); end if;
    -- cache: same query with the same bind values (child queries run once per parent otherwise)
    l_key := p_q.get_string('name') || '|' || l_sql;
    for i in 1 .. l_binds.count loop
      l_key := l_key || '|' || nvl(l_c(i), nvl(to_char(l_n(i), 'TM9', c_nls_num), to_char(l_d(i), 'YYYYMMDDHH24MISS')));
    end loop;
    g_last_key := substr(l_key, 1, 29000);
    if length(l_key) < 30000 and g_cache.exists(l_key) then return g_cache(l_key); end if;
    cur := dbms_sql.open_cursor;
    begin
      dbms_sql.parse(cur, l_sql, dbms_sql.native);
      for i in 1 .. l_binds.count loop
        l_t := nvl(type_of(l_binds(i)), 'C');
        begin
          case l_t
            when 'N' then dbms_sql.bind_variable(cur, ':' || l_binds(i), l_n(i));
            when 'D' then dbms_sql.bind_variable(cur, ':' || l_binds(i), l_d(i));
            else dbms_sql.bind_variable(cur, ':' || l_binds(i), l_c(i), 32767);
          end case;
        exception when others then null;          -- bind name not present in the final SQL (inside a removed lexical)
        end;
      end loop;
      dbms_sql.describe_columns3(cur, cnt, dsc);
      for i in 1 .. cnt loop
        case
          when dsc(i).col_type = 2 then dbms_sql.define_column(cur, i, v_n);
          when dsc(i).col_type in (12, 180, 181, 231) then dbms_sql.define_column(cur, i, v_d);
          when dsc(i).col_type = 112 then dbms_sql.define_column(cur, i, v_cl);
          when dsc(i).col_type = 113 then dbms_sql.define_column(cur, i, v_b);
          else dbms_sql.define_column(cur, i, v_c, 32767);
        end case;
      end loop;
      ign := dbms_sql.execute(cur);
      while dbms_sql.fetch_rows(cur) > 0 loop
        if l_rows.count >= c_max_rows then
          log_error('query ' || p_q.get_string('name') || ': more than ' || c_max_rows || ' rows, the rest is not printed (narrow the parameters)');
          exit;
        end if;
        declare r t_row; x pls_integer := l_rows.count + 1;
        begin
          for i in 1 .. cnt loop
            case
              when dsc(i).col_type = 2 then dbms_sql.column_value(cur, i, v_n); r(i).t := 'N'; r(i).n := v_n;
              when dsc(i).col_type in (12, 180, 181, 231) then dbms_sql.column_value(cur, i, v_d); r(i).t := 'D'; r(i).d := v_d;
              when dsc(i).col_type = 112 then dbms_sql.column_value(cur, i, v_cl); r(i).t := 'C'; r(i).c := dbms_lob.substr(v_cl, 32767, 1);
              when dsc(i).col_type = 113 then dbms_sql.column_value(cur, i, v_b); r(i).t := 'B'; r(i).b := v_b;
              else dbms_sql.column_value(cur, i, v_c); r(i).t := 'C'; r(i).c := v_c;
            end case;
          end loop;
          l_rows(x) := r;
        end;
      end loop;
      dbms_sql.close_cursor(cur);
    exception when others then
      if dbms_sql.is_open(cur) then dbms_sql.close_cursor(cur); end if;
      log_error('query ' || p_q.get_string('name') || ': ' || sqlerrm);
    end;
    if length(l_key) < 30000 and g_cached + l_rows.count <= c_cache_rows then
      g_cache(l_key) := l_rows;
      g_cached := g_cached + l_rows.count;
    end if;
    return l_rows;
  end;

  -- compare two cells (nulls last, as Oracle sorts ascending)
  function cmp (a in t_cell, b in t_cell) return pls_integer is
  begin
    if a.t = 'N' then
      if a.n is null and b.n is null then return 0; elsif a.n is null then return 1; elsif b.n is null then return -1; end if;
      return case when a.n < b.n then -1 when a.n > b.n then 1 else 0 end;
    elsif a.t = 'D' then
      if a.d is null and b.d is null then return 0; elsif a.d is null then return 1; elsif b.d is null then return -1; end if;
      return case when a.d < b.d then -1 when a.d > b.d then 1 else 0 end;
    elsif a.t = 'B' then
      return 0;
    else
      if a.c is null and b.c is null then return 0; elsif a.c is null then return 1; elsif b.c is null then return -1; end if;
      return case when a.c < b.c then -1 when a.c > b.c then 1 else 0 end;
    end if;
  end;

  -- break columns of all break groups of a query, in group order: positions and directions
  procedure break_cols (p_q in json_object_t, o_pos out apex_t_number, o_dir out apex_t_varchar2) is
    l_groups json_array_t := p_q.get_array('groups');
    l_cols json_array_t; l_c json_object_t;
  begin
    o_pos := apex_t_number(); o_dir := apex_t_varchar2();
    for g in 0 .. l_groups.get_size - 2 loop
      l_cols := treat(l_groups.get(g) as json_object_t).get_array('cols');
      for i in 0 .. l_cols.get_size - 1 loop
        l_c := treat(l_cols.get(i) as json_object_t);
        if nvl(l_c.get_string('brk'), 'A') != 'N' and l_c.get_number('pos') is not null then
          o_pos.extend; o_pos(o_pos.count) := l_c.get_number('pos');
          o_dir.extend; o_dir(o_dir.count) := l_c.get_string('brk');
        end if;
      end loop;
    end loop;
  end;

  -- stable merge sort of row indexes by the break columns
  procedure sort_rows (p_rows in t_rows, p_pos in apex_t_number, p_dir in apex_t_varchar2, io_idx in out nocopy t_idx) is
    tmp t_idx;
    function less_eq (i in pls_integer, j in pls_integer) return boolean is
      c pls_integer;
    begin
      for k in 1 .. p_pos.count loop
        if p_rows(i).exists(p_pos(k)) and p_rows(j).exists(p_pos(k)) then
          c := cmp(p_rows(i)(p_pos(k)), p_rows(j)(p_pos(k)));
          if p_dir(k) = 'D' then c := -c; end if;
          if c < 0 then return true; elsif c > 0 then return false; end if;
        end if;
      end loop;
      return true;
    end;
    procedure msort (lo in pls_integer, hi in pls_integer) is
      mid pls_integer; i pls_integer; j pls_integer; k pls_integer;
    begin
      if hi <= lo then return; end if;
      mid := trunc((lo + hi) / 2);
      msort(lo, mid); msort(mid + 1, hi);
      i := lo; j := mid + 1; k := lo;
      while i <= mid and j <= hi loop
        if less_eq(io_idx(i), io_idx(j)) then tmp(k) := io_idx(i); i := i + 1; else tmp(k) := io_idx(j); j := j + 1; end if;
        k := k + 1;
      end loop;
      while i <= mid loop tmp(k) := io_idx(i); i := i + 1; k := k + 1; end loop;
      while j <= hi loop tmp(k) := io_idx(j); j := j + 1; k := k + 1; end loop;
      for x in lo .. hi loop io_idx(x) := tmp(x); end loop;
    end;
  begin
    if p_pos.count = 0 or io_idx.count < 2 then return; end if;
    msort(1, io_idx.count);
  end;

  -- ---------------------------------------------------------------- summaries
  procedure acc_open (p_sums in json_array_t) is
    l_name varchar2(128); l_s json_object_t; a t_acc;
  begin
    if p_sums is null then return; end if;
    for i in 0 .. p_sums.get_size - 1 loop
      l_name := p_sums.get_string(i);
      l_s := g_sums.get_object(l_name);
      a.fn := l_s.get_string('fn'); a.src := l_s.get_string('src'); a.t := nvl(type_of(a.src), 'N');
      a.n := null; a.cnt := 0; a.d := null; a.c := null; a.started := false;
      g_accs(l_name) := a;
    end loop;
  end;

  -- summaries whose reset group is p_group (report: '#REPORT')
  function sums_reset_at (p_group in varchar2) return json_array_t is
    r json_array_t := json_array_t();
    k json_key_list := g_sums.get_keys;
  begin
    if k is null then return r; end if;
    for i in 1 .. k.count loop
      if nvl(g_sums.get_object(k(i)).get_string('reset'), 'REPORT') = case when p_group = '#REPORT' then 'REPORT' else p_group end
         or (p_group = '#REPORT' and g_sums.get_object(k(i)).get_string('reset') is null) then
        r.append(k(i));
      end if;
    end loop;
    return r;
  end;

  -- feed the open accumulators whose source column belongs to p_group
  procedure acc_feed (p_group in varchar2) is
    l_names apex_t_varchar2 := apex_t_varchar2();
    l_sums  apex_t_varchar2 := apex_t_varchar2();
    l_c apex_t_varchar2; l_n apex_t_number; l_d app_rdf_dates;
    s varchar2(128);
    g_of json_object_t := g_group_of;
  begin
    s := g_accs.first;
    while s is not null loop
      if g_of.has(g_accs(s).src) and g_of.get_string(g_accs(s).src) = p_group and (g_only is null or s member of g_only) then
        l_names.extend; l_names(l_names.count) := g_accs(s).src;
        l_sums.extend; l_sums(l_sums.count) := s;
      end if;
      s := g_accs.next(s);
    end loop;
    if l_names.count = 0 then return; end if;
    pkg_get(l_names, l_c, l_n, l_d);
    for i in 1 .. l_sums.count loop
      declare a t_acc := g_accs(l_sums(i));
      begin
        if a.fn = 'count' then
          if coalesce(l_c(i), to_char(l_n(i)), to_char(l_d(i), 'J')) is not null then a.cnt := a.cnt + 1; end if;
        elsif a.t = 'N' then
          if l_n(i) is not null then
            a.cnt := a.cnt + 1;
            a.n := case a.fn
                     when 'minimum' then least(nvl(a.n, l_n(i)), l_n(i))
                     when 'maximum' then greatest(nvl(a.n, l_n(i)), l_n(i))
                     when 'first'   then case when a.started then a.n else l_n(i) end
                     when 'last'    then l_n(i)
                     else nvl(a.n, 0) + l_n(i) end;
            a.started := true;
          end if;
        elsif a.t = 'D' then
          if l_d(i) is not null then
            a.cnt := a.cnt + 1;
            a.d := case a.fn when 'minimum' then least(nvl(a.d, l_d(i)), l_d(i)) when 'maximum' then greatest(nvl(a.d, l_d(i)), l_d(i))
                             when 'first' then case when a.started then a.d else l_d(i) end else l_d(i) end;
            a.started := true;
          end if;
        else
          if l_c(i) is not null then
            a.cnt := a.cnt + 1;
            a.c := case a.fn when 'minimum' then least(nvl(a.c, l_c(i)), l_c(i)) when 'maximum' then greatest(nvl(a.c, l_c(i)), l_c(i))
                             when 'first' then case when a.started then a.c else l_c(i) end else l_c(i) end;
            a.started := true;
          end if;
        end if;
        g_accs(l_sums(i)) := a;
      end;
    end loop;
  end;

  -- summaries placed in p_group get their current accumulator values
  procedure acc_publish (p_sums in json_array_t) is
    l_names apex_t_varchar2 := apex_t_varchar2();
    l_c apex_t_varchar2 := apex_t_varchar2(); l_n apex_t_number := apex_t_number(); l_d app_rdf_dates := app_rdf_dates();
    a t_acc;
  begin
    if p_sums is null then return; end if;
    for i in 0 .. p_sums.get_size - 1 loop
      if g_accs.exists(p_sums.get_string(i)) then
        a := g_accs(p_sums.get_string(i));
        l_names.extend; l_c.extend; l_n.extend; l_d.extend;
        l_names(l_names.count) := p_sums.get_string(i);
        if a.fn = 'count' then l_n(l_n.count) := a.cnt;
        elsif a.fn = 'average' then l_n(l_n.count) := case when a.cnt > 0 then a.n / a.cnt end;
        elsif a.t = 'D' then l_d(l_d.count) := a.d;
        elsif a.t = 'C' then l_c(l_c.count) := a.c;
        else l_n(l_n.count) := case when a.fn = 'sum' then nvl(a.n, 0) else a.n end;
        end if;
      end if;
    end loop;
    pkg_set(l_names, l_c, l_n, l_d);
  end;

  -- ---------------------------------------------------------------- scope output (fields, images, format triggers, text refs)
  function blob_uri (p in blob) return clob is
    l_mime varchar2(40) := 'image/png';
    l_head raw(8);
  begin
    if p is null or dbms_lob.getlength(p) = 0 then return null; end if;
    l_head := dbms_lob.substr(p, 8, 1);
    if utl_raw.substr(l_head, 1, 2) = hextoraw('FFD8') then l_mime := 'image/jpeg';
    elsif utl_raw.substr(l_head, 1, 3) = hextoraw('474946') then l_mime := 'image/gif';
    elsif utl_raw.substr(l_head, 1, 2) = hextoraw('424D') then l_mime := 'image/bmp';
    end if;
    return 'data:' || l_mime || ';base64,' || replace(replace(apex_web_service.blob2clobbase64(p), chr(10)), chr(13));
  end;

  procedure emit_scope (p_scope in varchar2) is
    s json_object_t;
    l_arr json_array_t;
    l_o json_object_t;
    l_names apex_t_varchar2; l_masks apex_t_varchar2; l_objs apex_t_varchar2;
    l_c apex_t_varchar2; l_n apex_t_number; l_d app_rdf_dates;
    l_r apex_t_varchar2;
    l_txt varchar2(32767);
    l_any boolean;
  begin
    if not g_scopes.has(p_scope) then return; end if;
    s := g_scopes.get_object(p_scope);
    -- fields
    l_arr := s.get_array('fields');
    if l_arr is not null and l_arr.get_size > 0 then
      l_names := apex_t_varchar2(); l_masks := apex_t_varchar2(); l_objs := apex_t_varchar2();
      for i in 0 .. l_arr.get_size - 1 loop
        l_o := treat(l_arr.get(i) as json_object_t);
        l_objs.extend; l_objs(l_objs.count) := l_o.get_string('o');
        l_names.extend; l_names(l_names.count) := l_o.get_string('s');
        l_masks.extend; l_masks(l_masks.count) := l_o.get_string('m');
      end loop;
      pkg_get(l_names, l_c, l_n, l_d);
      apex_json.open_object('t');
      for i in 1 .. l_objs.count loop
        l_txt := case
                   when l_names(i) = '$SYSDATE' then fmt_d(sysdate, l_masks(i))
                   when type_of(l_names(i)) = 'N' then fmt_n(l_n(i), l_masks(i))
                   when type_of(l_names(i)) = 'D' then fmt_d(l_d(i), l_masks(i))
                   else l_c(i) end;
        if l_txt is not null then apex_json.write(l_objs(i), l_txt); end if;
      end loop;
      apex_json.close_object;
    end if;
    -- images (BLOB columns of the current rows)
    l_arr := s.get_array('images');
    if l_arr is not null and l_arr.get_size > 0 then
      apex_json.open_object('i');
      for i in 0 .. l_arr.get_size - 1 loop
        l_o := treat(l_arr.get(i) as json_object_t);
        if g_blobs.exists(l_o.get_string('s')) and g_blobs(l_o.get_string('s')) is not null then
          apex_json.write(l_o.get_string('o'), blob_uri(g_blobs(l_o.get_string('s'))));
        end if;
      end loop;
      apex_json.close_object;
    end if;
    -- format triggers: hidden objects and attribute changes
    l_arr := s.get_array('trigs');
    if l_arr is not null and l_arr.get_size > 0 then
      l_names := apex_t_varchar2(); l_objs := apex_t_varchar2();
      for i in 0 .. l_arr.get_size - 1 loop
        l_o := treat(l_arr.get(i) as json_object_t);
        l_objs.extend; l_objs(l_objs.count) := l_o.get_string('o');
        l_names.extend; l_names(l_names.count) := l_o.get_string('fn');
      end loop;
      l_r := pkg_trigs(l_names);
      apex_json.open_array('h');
      for i in 1 .. l_objs.count loop
        if substr(l_r(i), 1, 1) = 'N' then apex_json.write(l_objs(i)); end if;
      end loop;
      apex_json.close_array;
      l_any := false;
      for i in 1 .. l_objs.count loop
        if length(l_r(i)) > 1 then
          if not l_any then apex_json.open_object('s'); l_any := true; end if;
          apex_json.write(l_objs(i), substr(l_r(i), 3));
        end if;
      end loop;
      if l_any then apex_json.close_object; end if;
    end if;
    -- boilerplate text with &<column> references
    l_arr := s.get_array('texts');
    if l_arr is not null and l_arr.get_size > 0 then
      apex_json.open_object('x');
      for i in 0 .. l_arr.get_size - 1 loop
        l_o := treat(l_arr.get(i) as json_object_t);
        l_names := arr(l_o.get_array('refs'));
        pkg_get(l_names, l_c, l_n, l_d);
        apex_json.open_object(l_o.get_string('o'));
        for j in 1 .. l_names.count loop
          apex_json.write(l_names(j), case type_of(l_names(j)) when 'N' then fmt_n(l_n(j), null) when 'D' then fmt_d(l_d(j), null) else l_c(j) end);
        end loop;
        apex_json.close_object;
      end loop;
      apex_json.close_object;
    end if;
  end;

  -- ---------------------------------------------------------------- groups
  procedure process_query (p_q in json_object_t);

  procedure child_queries (p_group in varchar2) is
    l_q json_object_t;
  begin
    for i in 0 .. g_queries.get_size - 1 loop
      l_q := treat(g_queries.get(i) as json_object_t);
      if l_q.get_string('parent_group') = p_group then
        process_query(l_q);
      end if;
    end loop;
  end;

  procedure set_group_row (p_group in json_object_t, p_row in t_row) is
    l_cols json_array_t := p_group.get_array('cols');
    l_c json_object_t;
    l_names apex_t_varchar2 := apex_t_varchar2();
    v_c apex_t_varchar2 := apex_t_varchar2(); v_n apex_t_number := apex_t_number(); v_d app_rdf_dates := app_rdf_dates();
    p pls_integer; t varchar2(1);
  begin
    for i in 0 .. l_cols.get_size - 1 loop
      l_c := treat(l_cols.get(i) as json_object_t);
      p := l_c.get_number('pos'); t := l_c.get_string('t');
      if t = 'B' then
        g_blobs(l_c.get_string('n')) := case when p is not null and p_row.exists(p) then p_row(p).b end;
        continue;
      end if;
      l_names.extend; v_c.extend; v_n.extend; v_d.extend;
      l_names(l_names.count) := l_c.get_string('n');
      if p is not null and p_row.exists(p) then
        -- the column's declared type wins; convert when the SQL type differs
        case t
          when 'N' then v_n(v_n.count) := case p_row(p).t when 'N' then p_row(p).n when 'C' then to_num(p_row(p).c) end;
          when 'D' then v_d(v_d.count) := case p_row(p).t when 'D' then p_row(p).d end;
          else v_c(v_c.count) := case p_row(p).t when 'N' then to_char(p_row(p).n, 'TM9', c_nls_num)
                                                 when 'D' then to_char(p_row(p).d, 'DD-MON-RR', c_nls_date) else p_row(p).c end;
        end case;
      end if;
    end loop;
    pkg_set(l_names, v_c, v_n, v_d);
  end;

  function same_break (p_group in json_object_t, a in t_row, b in t_row) return boolean is
    l_cols json_array_t := p_group.get_array('cols');
    p pls_integer;
  begin
    for i in 0 .. l_cols.get_size - 1 loop
      p := treat(l_cols.get(i) as json_object_t).get_number('pos');
      if p is not null and a.exists(p) and b.exists(p) then
        if cmp(a(p), b(p)) != 0 then return false; end if;
      end if;
    end loop;
    return true;
  end;

  -- key of a group instance, from its break values: matrix cells find their column with it
  function row_key (p_group in json_object_t, p_row in t_row) return varchar2 is
    l_cols json_array_t := p_group.get_array('cols');
    p pls_integer;
    k varchar2(32767);
  begin
    for i in 0 .. l_cols.get_size - 1 loop
      p := treat(l_cols.get(i) as json_object_t).get_number('pos');
      if p is not null and p_row.exists(p) and p_row(p).t != 'B' then
        k := k || chr(31) || case p_row(p).t when 'N' then to_char(p_row(p).n, 'TM9', c_nls_num)
                                             when 'D' then to_char(p_row(p).d, 'YYYYMMDDHH24MISS') else p_row(p).c end;
      end if;
    end loop;
    return substr(k, 1, 4000);
  end;

  -- matrix (cross product): the columns are the distinct instances of the column group over all the rows of the enclosing
  -- record, not per row.  They are written before the row group, each with its key and its column summaries (fed with the
  -- cells of the column only); the renderer lays them across and finds each row's cell by the key.
  procedure emit_columns (p_q in json_object_t, p_ci in pls_integer, p_rows in t_rows, p_idx in t_idx, p_from in pls_integer, p_to in pls_integer) is
    l_groups json_array_t := p_q.get_array('groups');
    l_g json_object_t := treat(l_groups.get(p_ci) as json_object_t);
    l_name varchar2(128) := l_g.get_string('name');
    l_forms apex_t_varchar2 := arr(l_g.get_array('formulas'));
    l_sums json_array_t := l_g.get_array('xsums');
    l_cols json_array_t := l_g.get_array('cols');
    l_c json_object_t;
    l_idx t_idx;
    l_pos apex_t_number := apex_t_number(); l_dir apex_t_varchar2 := apex_t_varchar2();
    l_old apex_t_varchar2 := g_only;
    n pls_integer := 0; i pls_integer; j pls_integer;
  begin
    for r in p_from .. p_to loop n := n + 1; l_idx(n) := p_idx(r); end loop;
    for c in 0 .. l_cols.get_size - 1 loop
      l_c := treat(l_cols.get(c) as json_object_t);
      if l_c.get_number('pos') is not null and nvl(l_c.get_string('t'), 'C') != 'B' then
        l_pos.extend; l_pos(l_pos.count) := l_c.get_number('pos');
        l_dir.extend; l_dir(l_dir.count) := case l_c.get_string('brk') when 'D' then 'D' else 'A' end;
      end if;
    end loop;
    sort_rows(p_rows, l_pos, l_dir, l_idx);
    g_only := arr(l_sums);
    apex_json.open_array(l_name);
    i := 1;
    while i <= n loop
      j := i;
      while j < n and same_break(l_g, p_rows(l_idx(i)), p_rows(l_idx(j + 1))) loop j := j + 1; end loop;
      set_group_row(l_g, p_rows(l_idx(i)));
      acc_open(l_sums);
      pkg_calc(l_forms);
      acc_feed(l_name);
      for r in i .. j loop                                -- the cells of this column
        for gi in p_ci + 1 .. l_groups.get_size - 1 loop
          l_c := treat(l_groups.get(gi) as json_object_t);
          set_group_row(l_c, p_rows(l_idx(r)));
          pkg_calc(arr(l_c.get_array('formulas')));
          acc_feed(l_c.get_string('name'));
        end loop;
      end loop;
      set_group_row(l_g, p_rows(l_idx(i)));
      acc_publish(l_sums);
      pkg_calc(l_forms);
      apex_json.open_object;
      apex_json.write('k', row_key(l_g, p_rows(l_idx(i))));
      emit_scope(l_name);
      apex_json.close_object;
      i := j + 1;
    end loop;
    apex_json.close_array;
    g_only := l_old;
  exception when others then
    g_only := l_old;
    raise;
  end;

  procedure process_group (p_q in json_object_t, p_gi in pls_integer, p_rows in t_rows, p_idx in t_idx, p_from in pls_integer, p_to in pls_integer) is
    l_groups json_array_t := p_q.get_array('groups');
    l_g json_object_t := treat(l_groups.get(p_gi) as json_object_t);
    l_name varchar2(128) := l_g.get_string('name');
    l_leaf boolean := p_gi = l_groups.get_size - 1;
    l_forms apex_t_varchar2 := arr(l_g.get_array('formulas'));
    -- formulas that change state run once per record (when it opens, or when it closes if they need its child summaries)
    l_open  apex_t_varchar2 := case when l_g.has('f_open') then arr(l_g.get_array('f_open')) else l_forms end;
    l_close apex_t_varchar2 := case when l_g.has('f_close') then arr(l_g.get_array('f_close')) else l_forms end;
    l_pure  apex_t_varchar2 := case when l_g.has('f_pure') then arr(l_g.get_array('f_pure')) else l_forms end;
    l_key boolean := l_g.has('key');
    i pls_integer := p_from; j pls_integer;
  begin
    if l_g.has('xcol') then
      emit_columns(p_q, l_g.get_number('xcol'), p_rows, p_idx, p_from, p_to);
    end if;
    apex_json.open_array(l_name);
    while i <= p_to loop
      j := i;
      if not l_leaf then
        while j < p_to and same_break(l_g, p_rows(p_idx(i)), p_rows(p_idx(j + 1))) loop j := j + 1; end loop;
      end if;
      -- open the instance
      set_group_row(l_g, p_rows(p_idx(i)));
      acc_open(sums_reset_at(l_name));
      g_depth := g_depth + 2; pkg_calc(l_open); g_depth := g_depth - 2;
      apex_json.open_object;
      if l_key then apex_json.write('k', row_key(l_g, p_rows(p_idx(i)))); end if;
      apex_json.open_object('c');
      if not l_leaf then
        process_group(p_q, p_gi + 1, p_rows, p_idx, i, j);
        set_group_row(l_g, p_rows(p_idx(i)));        -- restore this level (a deeper level may share names in odd reports)
      end if;
      child_queries(l_name);
      apex_json.close_object;
      -- close the instance: summaries of the descendants, final formulas, feed the open summaries with this record, then
      -- running summaries placed in this group include the current record (Reports line numbers: count reset at the document)
      acc_publish(l_g.get_array('sums'));
      pkg_calc(l_close);
      acc_feed(l_name);
      if l_g.get_array('sums') is not null and l_g.get_array('sums').get_size > 0 then
        acc_publish(l_g.get_array('sums'));
        pkg_calc(l_pure);
      end if;
      emit_scope(l_name);
      apex_json.close_object;
      i := j + 1;
    end loop;
    apex_json.close_array;
  end;

  -- link key of a cell (child rows are indexed by it, the parent record looks its rows up with it)
  function cell_key (c in t_cell) return varchar2 is
  begin
    return case c.t when 'N' then to_char(c.n, 'TM9', c_nls_num) when 'D' then to_char(c.d, 'YYYYMMDDHH24MISS')
                    when 'B' then null else substr(c.c, 1, 1000) end;
  end;

  procedure process_query (p_q in json_object_t) is
    l_rows t_rows;
    l_idx  t_idx;
    l_pos  apex_t_number; l_dir apex_t_varchar2;
    l_links json_array_t := p_q.get_array('links');
    l_lk json_object_t;
    l_c apex_t_varchar2; l_n apex_t_number; l_d app_rdf_dates;
    l_pcs apex_t_varchar2 := apex_t_varchar2();       -- parent columns of the links
    l_cpos apex_t_number := apex_t_number();          -- child column positions
    l_pkey varchar2(32767);
    l_rk varchar2(4000);
    l_ok boolean := true;
    k pls_integer := 0;
  begin
    l_rows := run_query(p_q);
    if l_links is not null and l_links.get_size > 0 and l_rows.count > 0 then
      -- data links: the child rows matching the parent column values.  The rows of a query are indexed once by their link
      -- values (a query without binds runs once and is shared by every parent record)
      for x in 0 .. l_links.get_size - 1 loop
        l_lk := treat(l_links.get(x) as json_object_t);
        if l_lk.get_number('cpos') is not null and l_rows(1).exists(l_lk.get_number('cpos')) then
          l_pcs.extend; l_pcs(l_pcs.count) := l_lk.get_string('pc');
          l_cpos.extend; l_cpos(l_cpos.count) := l_lk.get_number('cpos');
        end if;
      end loop;
      if l_pcs.count > 0 then
        pkg_get(l_pcs, l_c, l_n, l_d);
        for x in 1 .. l_pcs.count loop                -- the parent value in the child column's type
          declare pc t_cell; t varchar2(1) := l_rows(1)(l_cpos(x)).t;
          begin
            pc.t := t;
            if t = 'N' then pc.n := nvl(l_n(x), to_num(l_c(x)));
            elsif t = 'D' then pc.d := l_d(x);
            else pc.c := coalesce(l_c(x), to_char(l_n(x), 'TM9', c_nls_num)); end if;
            if cell_key(pc) is null then l_ok := false; end if;     -- a null link value matches nothing
            l_pkey := l_pkey || chr(31) || cell_key(pc);
          end;
        end loop;
        if l_ok then
          declare mk varchar2(32767) := g_last_key || '#';
                  l_map t_map;
          begin
            for x in 1 .. l_cpos.count loop mk := mk || l_cpos(x) || ','; end loop;
            mk := substr(mk, 1, 30000);
            if g_maps.exists(mk) then
              l_map := g_maps(mk);
            else
              for r in 1 .. l_rows.count loop
                l_rk := null;
                for x in 1 .. l_cpos.count loop
                  l_rk := substr(l_rk || chr(31) || case when l_rows(r).exists(l_cpos(x)) then cell_key(l_rows(r)(l_cpos(x))) end, 1, 4000);
                end loop;
                if l_map.exists(l_rk) then l_map(l_rk)(l_map(l_rk).count + 1) := r;
                else l_map(l_rk)(1) := r; end if;
              end loop;
              if g_cache.exists(g_last_key) then g_maps(mk) := l_map; end if;   -- kept only with the cached rows
            end if;
            if l_pkey is not null and l_map.exists(substr(l_pkey, 1, 4000)) then
              l_idx := l_map(substr(l_pkey, 1, 4000)); k := l_idx.count;
            end if;
          end;
        end if;
      else
        for r in 1 .. l_rows.count loop k := k + 1; l_idx(k) := r; end loop;
      end if;
    else
      for r in 1 .. l_rows.count loop k := k + 1; l_idx(k) := r; end loop;
    end if;
    break_cols(p_q, l_pos, l_dir);
    sort_rows(l_rows, l_pos, l_dir, l_idx);
    if k > 0 then
      process_group(p_q, 0, l_rows, l_idx, 1, k);
    else
      apex_json.open_array(treat(p_q.get_array('groups').get(0) as json_object_t).get_string('name'));
      apex_json.close_array;
    end if;
  end;

  -- ---------------------------------------------------------------- main
  function data_json (p_report in varchar2, p_params in varchar2) return clob is
    l_model clob;
    l_q json_object_t;
    l_trig json_object_t;
    l_r varchar2(1);
    l_out clob;
    l_rep json_object_t;
    l_fmt varchar2(100);
  begin
    select value into l_fmt from nls_session_parameters where parameter = 'NLS_DATE_FORMAT';
    dbms_session.set_nls('NLS_DATE_FORMAT', '''' || c_legacy_date || '''');
    select pkg, model into g_pkg, l_model from app_rdf_report where name = upper(p_report);
    g_model := json_object_t.parse(l_model);
    g_types := g_model.get_object('types');
    g_scopes := g_model.get_object('scopes');
    g_sums := g_model.get_object('summaries');
    g_queries := g_model.get_array('queries');
    g_group_of := g_model.get_object('group_of');
    g_accs.delete; g_blobs.delete; g_cache.delete; g_maps.delete; g_cached := 0; g_errors := null; g_depth := 0; g_only := null;
    srw.reset_messages;
    set_params(p_params);
    apex_json.initialize_clob_output;
    apex_json.open_object;
    l_trig := g_model.get_object('triggers');
    for t in (select column_value k from table(apex_t_varchar2('beforeParameterFormTrigger', 'afterParameterFormTrigger', 'beforeReportTrigger'))) loop
      if l_trig is not null and l_trig.has(t.k) then
        begin
          l_r := pkg_report_trigger(l_trig.get_string(t.k));
          if l_r = 'N' then log_error('report trigger ' || l_trig.get_string(t.k) || ' returned false'); end if;
        exception when others then log_error('report trigger ' || l_trig.get_string(t.k) || ': ' || sqlerrm);
        end;
      end if;
    end loop;
    l_rep := g_model.get_object('report');
    acc_open(sums_reset_at('#REPORT'));
    g_depth := 2; pkg_calc(arr(l_rep.get_array('formulas'))); g_depth := 0;
    apex_json.open_object('report');
    apex_json.open_object('c');
    for i in 0 .. g_queries.get_size - 1 loop
      l_q := treat(g_queries.get(i) as json_object_t);
      if l_q.get_string('parent_group') is null then
        process_query(l_q);
      end if;
    end loop;
    apex_json.close_object;
    acc_publish(l_rep.get_array('sums'));
    pkg_calc(arr(l_rep.get_array('formulas')));
    acc_feed('#REPORT');
    emit_scope('#REPORT');
    apex_json.close_object;
    if g_errors is not null then apex_json.write('errors', g_errors); end if;
    if srw.messages is not null then apex_json.write('messages', srw.messages); end if;
    apex_json.close_object;
    l_out := apex_json.get_clob_output;
    apex_json.free_output;
    dbms_session.set_nls('NLS_DATE_FORMAT', '''' || replace(l_fmt, '''', '''''') || '''');
    g_cache.delete; g_maps.delete; g_blobs.delete; g_cached := 0;     -- the (pooled) session keeps no report data
    return l_out;
  exception when others then
    g_cache.delete; g_maps.delete; g_blobs.delete; g_cached := 0;
    if l_fmt is not null then dbms_session.set_nls('NLS_DATE_FORMAT', '''' || replace(l_fmt, '''', '''''') || ''''); end if;
    raise;
  end data_json;

  procedure out_clob (p in clob) is
    l_len pls_integer := dbms_lob.getlength(p);
    l_pos pls_integer := 1;
  begin
    while l_pos <= l_len loop
      htp.prn(dbms_lob.substr(p, 4000, l_pos));
      l_pos := l_pos + 4000;
    end loop;
  end;

  function script_safe (p in clob) return clob is
  begin
    return replace(p, '</', '<\/');
  end;

  procedure render (p_report in varchar2, p_params in varchar2, p_title in varchar2 default null) is
    l_layout clob; l_js clob; l_data clob;
    l_id varchar2(40) := 'rdf' || to_char(abs(dbms_random.random));
  begin
    select layout into l_layout from app_rdf_report where name = upper(p_report);
    select content into l_js from app_rdf_asset where name = 'rdfprint.js';
    l_data := data_json(p_report, p_params);
    htp.p('<div class="rdf-doc" id="' || l_id || '"></div>');
    htp.prn('<script type="application/json" id="' || l_id || '_layout">'); out_clob(script_safe(l_layout)); htp.p('</script>');
    htp.prn('<script type="application/json" id="' || l_id || '_data">'); out_clob(script_safe(l_data)); htp.p('</script>');
    htp.prn('<script>'); out_clob(l_js); htp.p('</script>');
    htp.p('<script>rdfPrint.render("' || l_id || '");</script>');
  exception when no_data_found then
    htp.p('<div class="t-Alert t-Alert--warning"><div class="t-Alert-body">' ||
          case when app_sec.lang = 'en' then 'The print layout of this document is not installed.' else 'تصميم طباعة هذا المستند غير مثبت.' end ||
          '</div></div>');
  end render;

end app_rdf;
/
show errors package body app_rdf
