"""Write an APEX 24.2 application export (split format) for the client's application from work/out/specs.json.
Static pieces (icons, plugin settings, deployment, theme) are copied from the reference export app/export/f100;
everything else is generated: application definition, shared components, login/change-password/home pages
and one page set per legacy form."""
import os, sys, re, io, json, shutil, hashlib, collections

HERE = os.path.dirname(os.path.abspath(__file__))
APPDIR = os.path.dirname(HERE)
sys.path.insert(0, APPDIR); import mp
REF = os.path.join(APPDIR, "export", "f100")          # reference export (theme, icons, plugin settings): retargeted on copy
BUILD = mp.work("build", "app")

APP_ID = mp.APP_ID
WS_ID = mp.workspace_id()
OWNER = mp.SCHEMA

# Universal Theme 42 template ids (APEX 24.2)
T_STANDARD = 4072358936313175081
T_IRR = 2100526641005906379
T_BUTTONS = 2126429139436695430
T_DIALOG_REGION = 4501440665235496320
T_BUTTON = 4072362960822175091
T_ICON_BUTTON = 2349107722467437027
T_LABEL_OPT = 1609121967514267634
T_LABEL_REQ = 1609122147107268652
T_LOGIN_PAGE = 2101157952850466385
T_LOGIN_REGION = 2674157997338192145
T_LOGIN_LABEL = 2040785906935475274
T_HERO = 2674017834225413037
T_SIDE_NAV = 2467739217141810545
T_NAVBAR = 2847543055748234966
T_BLANK = 4072358936313175081

HEADER = """begin
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2024.11.30'
,p_release=>'24.2.0'
,p_default_workspace_id=>{ws}
,p_default_application_id=>{app}
,p_default_id_offset=>0
,p_default_owner=>'{owner}'
);
""".format(ws=WS_ID, app=APP_ID, owner=OWNER)
FOOTER = "wwv_flow_imp.component_end;\nend;\n/\n"


# ------------------------------------------------------------------ helpers
def nid(*key):
    """Deterministic component id (stable across rebuilds)."""
    h = int(hashlib.sha1("|".join(map(str, key)).encode("utf-8")).hexdigest()[:13], 16)
    return 8_000_000_000_000_000 + h


def q(s):
    """PL/SQL literal; long or multi-line text uses wwv_flow_string.join."""
    if s is None:
        return "null"
    s = str(s)
    if "\n" in s or len(s.encode("utf-8")) > 3000:
        lines = s.replace("\r", "").split("\n")
        parts = []
        for ln in lines:
            while len(ln.encode("utf-8")) > 3000:
                cut = max(ln.rfind(" ", 0, 1000), ln.rfind(",", 0, 1000))   # join() re-inserts a newline: cut where one is harmless
                cut = cut + 1 if cut > 200 else 1000
                parts.append(ln[:cut]); ln = ln[cut:]
            parts.append(ln)
        return "wwv_flow_string.join(wwv_flow_t_varchar2(\n" + ",\n".join("'" + p.replace("'", "''") + "'" for p in parts) + "))"
    return "'" + s.replace("'", "''") + "'"


def call(api, **kw):
    """Render one wwv_flow_imp_* call; values: int/float -> number, bool -> true/false, 'ID:<n>' -> wwv_flow_imp.id(n), RAW(...) as-is."""
    out = [f"{api}("]
    first = True
    for k, v in kw.items():
        if v is None: continue
        if isinstance(v, bool): val = "true" if v else "false"
        elif isinstance(v, (int, float)): val = str(v)
        elif isinstance(v, Id): val = f"wwv_flow_imp.id({v.v})"
        elif isinstance(v, Raw): val = v.s
        else: val = q(v)
        out.append((" " if first else ",") + f"p_{k}=>{val}")
        first = False
    out.append(");")
    return "\n".join(out) + "\n"


class Id:
    def __init__(self, v): self.v = v


class Raw:
    def __init__(self, s): self.s = s


def attrs(**kv):
    items = []
    for k, v in sorted(kv.items()):
        if v is None: continue
        items.append(f"  '{k}', " + q(v))
    return Raw("wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(\n" + ",\n".join(items) + ")).to_clob")


def write(rel, body):
    p = os.path.join(BUILD, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with io.open(p, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(f"prompt --{rel[:-4] if rel.endswith('.sql') else rel}\n")
        fh.write(HEADER + body + FOOTER)
    return rel


# ------------------------------------------------------------------ app-level ids
AUTHN = nid("authn", "custom")
AZ_PAGE = nid("authz", "PAGE_ACCESS")
AZ_INS = nid("authz", "PAGE_INSERT")
AZ_UPD = nid("authz", "PAGE_UPDATE")
AZ_DEL = nid("authz", "PAGE_DELETE")
AZ_ADMIN = nid("authz", "ADMIN")
NAV_LIST = nid("list", "nav")
NAVBAR_LIST = nid("list", "navbar")
CLOB_LOV = {}


def lov_id(name):
    return nid("lov", name)


# ------------------------------------------------------------------ widgets
def item_widget(col, lovs):
    """(display_as, extra kw, attributes) for a page item."""
    w = col["widget"]
    if w == "DATE":
        return "NATIVE_DATE_PICKER_APEX", {}, attrs(appearance_and_behavior="MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON", days_outside_month="VISIBLE",
                                                 display_as="POPUP", max_date="NONE", min_date="NONE", multiple_months="N", show_on="FOCUS",
                                                 show_time="N", use_defaults="Y")
    if w == "NUMBER":
        return "NATIVE_NUMBER_FIELD", {}, attrs(number_alignment="left", virtual_keyboard="decimal")
    if w == "TEXTAREA":
        return "NATIVE_TEXTAREA", {"cHeight": 3}, attrs(auto_height="N", character_counter="N", resizable="Y", trim_spaces="BOTH")
    if w in ("SELECT", "POPUP") and (col["lov"] in lovs or col.get("lov_sql")):
        src = {"named_lov": col["lov"]} if col["lov"] in lovs else {"lov": col["lov_sql"]}
        if w == "SELECT":
            return "NATIVE_SELECT_LIST", dict(src, lov_display_null="YES"), attrs(page_action_on_selection="NONE")
        return "NATIVE_POPUP_LOV", dict(src, lov_display_null="YES"), attrs(
            case_sensitive="N", display_as="POPUP", fetch_on_search="Y", initial_fetch="FIRST_ROWSET", manual_entry="N", match_type="CONTAINS", min_chars="0")
    if w == "SELECT_STATIC" and col.get("static"):
        return "NATIVE_SELECT_LIST", {"lov": static_lov(col["static"]), "lov_display_null": "YES"}, attrs(page_action_on_selection="NONE")
    if w == "RADIO" and col.get("static"):
        return "NATIVE_RADIOGROUP", {"lov": static_lov(col["static"]), "lov_display_null": "NO"}, attrs(
            number_of_columns=str(min(len(col["static"]), 4)), page_action_on_selection="NONE")
    if w == "CHECK":
        on, off = check_values(col)
        return "NATIVE_SINGLE_CHECKBOX", {}, attrs(checked_value=on, unchecked_value=off, use_defaults="N")
    return "NATIVE_TEXT_FIELD", {}, attrs(disabled="N", submit_when_enter_pressed="N", subtype="TEXT", trim_spaces="BOTH")


def check_values(col):
    if col.get("check"):
        return col["check"][0], (col["check"][1] if len(col["check"]) > 1 else "0")
    return ("1", "0") if col["type"] == "NUMBER" else ("Y", "N")


def static_lov(pairs):
    return "STATIC2:" + ",".join(f"{(d or r).replace(',', ' ').replace(';', ' ')};{r}" for d, r in pairs)


def data_type(col):
    t = col["type"]
    if t == "NUMBER" or t == "FLOAT": return "NUMBER"
    if t == "DATE": return "DATE"
    if t.startswith("TIMESTAMP"): return "TIMESTAMP"
    if t in ("CLOB", "NCLOB"): return "CLOB"
    return "VARCHAR2"


# ------------------------------------------------------------------ IG region
def show_cond(c, prefix="display_condition"):
    """Server-side condition of a column shown only with a right (rules.columns / computed "show_if"): a SQL condition, or a
    named legacy right "right:VIEW_COST" / "right:VIEW_BALANCE" (app_ui.has_right).  Without the right the column is not rendered."""
    s = c.get("show_if")
    if not s:
        return {}
    if s.lower().startswith("right:"):
        s = f"app_ui.has_right('{s.split(':', 1)[1].strip().upper()}') = 1"
    if prefix == "display_when":                               # page items
        return dict(display_when_type="EXPRESSION", display_when=s, display_when2="SQL")
    return {f"{prefix}_type": "EXPRESSION", prefix: s, f"{prefix}2": "SQL"}


def ig_region(pg, key, title, blk, seq, lovs, where=None, ajax_items=None, condition_item=None, hide_header=False, readonly=False,
              template=T_IRR, master=None, static_id=None, doc_grid=False):
    """master: (parent grid region id, parent grid key, {column: parent grid column}) for a grid under the selected line of
    another grid (detail of a detail); APEX filters it by that line and saves parent lines first."""
    rid = nid(pg, key, "region")
    out = []
    ops = "".join(x for x, ok in (("i", blk.get("insert", True)), ("u", blk.get("update", True)), ("d", blk.get("delete", True))) if ok)
    is_view = bool(blk.get("is_view"))
    editable = bool(ops) and not readonly and not is_view
    if template == T_IRR:
        rto = "#DEFAULT#" + (":t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc" if hide_header else "")
    else:
        rto = "#DEFAULT#:t-Region--noPadding:t-Region--scrollBody"
    dc = blk.get("debit_credit")
    src = dict(query_type="TABLE", query_table=blk["table"], query_where=where,
               query_order_by=blk.get("order_by") if blk.get("order_by") and "&" not in (blk.get("order_by") or "") else None,
               include_rowid_column=not is_view)
    if dc or sql_cols(blk):
        # SQL source: debit / credit over a signed VALUE, display-only columns computed per row (rules.computed, alias t)
        sel = (["t.rowid"] if not is_view else []) + [f"t.{c['name']}" for c in blk["cols"] if not c.get("computed")]
        if dc:
            v, dcol, ccol = dc["value"], dc["debit"], dc["credit"]
            sel += [f"case when t.{v} > 0 then t.{v} end {dcol}", f"case when t.{v} < 0 then -t.{v} end {ccol}"]
        sel += [f"({ssq(c['sql'])}) {c['name']}" for c in sql_cols(blk)]
        order = f"\n order by {alias_t(blk['order_by'], blk['table'])}" if blk.get("order_by") and "&" not in blk["order_by"] else ""
        src = dict(query_type="SQL", plug_source="select " + ",\n       ".join(sel) + f"\n  from {blk['table']} t"
                   + (f"\n where {alias_t(where, blk['table'])}" if where else "") + order, include_rowid_column=False)
    out.append(call("wwv_flow_imp_page.create_page_plug", id=Id(rid), plug_name=title, region_name=static_id,
                    region_template_options=rto,
                    plug_template=template, plug_display_sequence=seq, **src, plug_source_type="NATIVE_IG", ajax_items_to_submit=ajax_items,
                    master_region_id=Id(master[0]) if master else None,
                    plug_display_condition_type="ITEM_IS_NOT_NULL" if condition_item else None,
                    plug_display_when_condition=condition_item, prn_page_header=title))
    cols = []
    if editable:
        cols.append(("APEX$ROW_SELECTOR", call("wwv_flow_imp_page.create_region_column", id=Id(nid(pg, key, "c", "SEL")), name="APEX$ROW_SELECTOR",
                    item_type="NATIVE_ROW_SELECTOR", display_sequence=10, attributes=attrs(enable_multi_select="Y", hide_control="N", show_select_all="Y"),
                    enable_hide=True, is_primary_key=False), True))
        cols.append(("APEX$ROW_ACTION", call("wwv_flow_imp_page.create_region_column", id=Id(nid(pg, key, "c", "ACT")), name="APEX$ROW_ACTION",
                    item_type="NATIVE_ROW_ACTION", label="إجراءات", heading_alignment="CENTER", display_sequence=20, value_alignment="CENTER",
                    enable_hide=True, is_primary_key=False), True))
    if not is_view:
        cols.append(("ROWID", call("wwv_flow_imp_page.create_region_column", id=Id(nid(pg, key, "c", "ROWID")), name="ROWID", source_type="DB_COLUMN",
                    source_expression="ROWID", data_type="ROWID", session_state_data_type="VARCHAR2", is_query_only=True, item_type="NATIVE_HIDDEN",
                    display_sequence=30, attributes=attrs(value_protected="Y"), enable_filter=False, enable_hide=True, is_primary_key=True,
                    duplicate_value=False, include_in_export=False), False))
    join = {d: m for d, m in (blk.get("join") or [])}
    s = 40
    for c in blk["cols"]:
        cid = nid(pg, key, "c", c["name"])
        dt = data_type(c)
        common = dict(id=Id(cid), name=c["name"], source_type="DB_COLUMN", source_expression=c["name"], data_type=dt,
                      session_state_data_type="VARCHAR2", is_query_only=False, display_sequence=s, **show_cond(c))
        s += 10
        if c["name"] in join and master:                   # sub-grid: the value comes from the selected line of the parent grid
            cols.append((c["name"], call("wwv_flow_imp_page.create_region_column", **common, item_type="NATIVE_HIDDEN",
                        attributes=attrs(value_protected="Y"), enable_filter=False, enable_hide=True, is_primary_key=False,
                        parent_column_id=Id(nid(pg, master[1], "c", master[2][c["name"]])), duplicate_value=True,
                        include_in_export=False), False))
            continue
        if c["name"] in join:
            cols.append((c["name"], call("wwv_flow_imp_page.create_region_column", **common, item_type="NATIVE_HIDDEN",
                        attributes=attrs(value_protected="Y"), enable_filter=False, enable_hide=True, is_primary_key=False,
                        default_type="ITEM", default_expression=f"P{pg}_{join[c['name']]}", duplicate_value=True, include_in_export=False), False))
            continue
        if c.get("sql"):
            common["is_query_only"] = True
        if c["hidden"]:
            if c.get("dc_value"): common["is_query_only"] = True
            hk = {}
            dflt = c.get("default")                         # hidden columns keep their default (new rows)
            if dflt and not readonly:
                hk.update(default_type=dflt["type"], default_expression=dflt["value"])
                if dflt["type"] in ("EXPRESSION", "FUNCTION_BODY"): hk["default_language"] = "PLSQL"
            cols.append((c["name"], call("wwv_flow_imp_page.create_region_column", **common, item_type="NATIVE_HIDDEN",
                        attributes=attrs(value_protected="N"), enable_filter=False, enable_hide=True, is_primary_key=False,
                        duplicate_value=True, include_in_export=False, **hk), False))
            continue
        kw = {}
        w = c["widget"]
        if w == "DATE":
            it = "NATIVE_DATE_PICKER_APEX"; at = attrs(appearance_and_behavior="MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON", days_outside_month="VISIBLE",
                display_as="POPUP", max_date="NONE", min_date="NONE", multiple_months="N", show_on="FOCUS", show_time="N", use_defaults="Y")
            kw.update(filter_date_ranges="ALL", filter_lov_type="DISTINCT")
            align = "LEFT"
        elif w in ("SELECT", "POPUP") and (c["lov"] in lovs or c.get("lov_sql")):
            if w == "SELECT":
                it = "NATIVE_SELECT_LIST"; at = attrs(page_action_on_selection="NONE")
            else:
                it = "NATIVE_POPUP_LOV"; at = attrs(case_sensitive="N", display_as="POPUP", fetch_on_search="Y", initial_fetch="FIRST_ROWSET",
                                                    manual_entry="N", match_type="CONTAINS", min_chars="0")
            if c["lov"] in lovs:
                kw.update(lov_type="SHARED", lov_id=Id(lov_id(c["lov"])))
            else:
                kw.update(lov_type="SQL_QUERY", lov_source=c["lov_sql"].replace(":PAGE_", ":"))    # grid row: the column binds
                if c.get("cascade"):
                    kw.update(lov_cascade_parent_items=",".join(c["cascade"]), ajax_optimize_refresh=True)
            kw.update(lov_display_extra=True, lov_display_null=True, filter_lov_type="LOV")
            align = "LEFT"
        elif w in ("SELECT_STATIC", "RADIO") and c.get("static"):
            it = "NATIVE_SELECT_LIST"; at = attrs(page_action_on_selection="NONE")
            kw.update(lov_type="STATIC", lov_source=static_lov(c["static"]), lov_display_extra=True, lov_display_null=True, filter_lov_type="LOV")
            align = "LEFT"
        elif w == "CHECK":
            on, off = check_values(c)
            it = "NATIVE_SINGLE_CHECKBOX"; at = attrs(checked_value=on, unchecked_value=off, use_defaults="N")
            kw.update(filter_lov_type="DISTINCT")
            align = "CENTER"
        elif w == "NUMBER":
            it = "NATIVE_NUMBER_FIELD"; at = attrs(number_alignment="left", virtual_keyboard="decimal")
            kw.update(filter_lov_type="NONE")
            align = "RIGHT"
        elif w == "TEXTAREA":
            it = "NATIVE_TEXTAREA"; at = attrs(auto_height="N", character_counter="N", resizable="Y", trim_spaces="BOTH")
            kw.update(max_length=c["len"], filter_operators="C:S:CASE_INSENSITIVE:REGEXP", filter_text_case="MIXED", filter_exact_match=True, filter_lov_type="NONE")
            align = "LEFT"
        else:
            it = "NATIVE_TEXT_FIELD"; at = attrs(disabled="N", send_on_page_submit="N", submit_when_enter_pressed="N", subtype="TEXT", trim_spaces="BOTH")
            if c["type"] != "NUMBER": kw.update(max_length=c["len"])
            kw.update(filter_operators="C:S:CASE_INSENSITIVE:REGEXP", filter_text_case="MIXED", filter_exact_match=True, filter_lov_type="DISTINCT")
            align = "LEFT"
        lk = row_link(c)
        if lk:                                             # the row opens another screen (legacy drill-down on the line)
            it, at = "NATIVE_LINK", None
            kw.update(link_target=lk, link_text=f"&{c['name']}.")
            common["is_query_only"] = True
        if c.get("readonly") or readonly or c.get("sql"):
            kw["readonly_condition_type"] = "ALWAYS"
        elif c.get("ro_update"):                           # editable on a new row only
            kw.update(readonly_condition_type="ITEM_IS_NOT_NULL", readonly_condition="ROWID", readonly_for_each_row=True)
        dflt = c.get("default")
        if dflt and dflt["type"] in ("STATIC", "ITEM", "EXPRESSION", "SQL_QUERY", "FUNCTION_BODY") and not readonly:
            kw.update(default_type=dflt["type"], default_expression=dflt["value"])
            if dflt["type"] in ("EXPRESSION", "FUNCTION_BODY"): kw["default_language"] = "PLSQL"
        cols.append((c["name"], call("wwv_flow_imp_page.create_region_column", **common, item_type=it, heading=c["label_a"] or c["label_e"],
                    heading_alignment=align, value_alignment=align, attributes=at, is_required=bool(c["required"]) and not readonly,
                    enable_filter=True, filter_is_required=False, use_as_row_header=False, enable_sort_group=True, enable_control_break=True,
                    enable_hide=True, enable_pivot=False, is_primary_key=False, duplicate_value=True, include_in_export=True, **kw), True))
    out.extend(x[1] for x in cols)
    ig = nid(pg, key, "ig")
    igkw = dict(id=Id(ig), internal_uid=ig % 10**15, is_editable=editable)
    if editable:
        igkw.update(edit_operations=":".join(ops), add_authorization_scheme=Id(AZ_INS) if "i" in ops else None,
                    update_authorization_scheme=Id(AZ_UPD) if "u" in ops else None,
                    delete_authorization_scheme=Id(AZ_DEL) if "d" in ops else None,
                    lost_update_check_type="VALUES", add_row_if_empty=False, submit_checked_rows=False)
        if doc_grid:        # lines of a document: one save for header and all lines (the page button), like the legacy commit
            igkw["toolbar_buttons"] = "SEARCH_COLUMN:SEARCH_FIELD:ACTIONS_MENU:RESET"
    if master:                                              # empty sub-grid: say how it works
        igkw["no_data_found_message"] = ("لا توجد تفاصيل للسطر المختار - اختر سطراً من الجدول السابق أو أضف تفاصيل له"
                                         " / No details for the selected line: select a line above or add details")
    igkw.update(lazy_loading=False, requires_filter=False, select_first_row=True, fixed_row_height=True, pagination_type="SCROLL",
                show_total_row_count=True, show_toolbar=True, enable_save_public_report=False, enable_subscriptions=True, enable_flashback=True,
                define_chart_view=True, enable_download=True, enable_mail_download=True, fixed_header="PAGE", show_icon_view=False, show_detail_view=False)
    out.append(call("wwv_flow_imp_page.create_interactive_grid", **igkw))
    rpt = nid(pg, key, "igrpt"); view = nid(pg, key, "igview")
    out.append(call("wwv_flow_imp_page.create_ig_report", id=Id(rpt), interactive_grid_id=Id(ig), static_id=str(rpt % 100000),
                    type="PRIMARY", default_view="GRID", show_row_number=False, settings_area_expanded=True))
    out.append(call("wwv_flow_imp_page.create_ig_report_view", id=Id(view), report_id=Id(rpt), view_type="GRID",
                    srv_exclude_null_values=False, srv_only_display_columns=True, edit_mode=False))
    seqn = 0
    for name, _, visible in cols:
        if name == "APEX$ROW_SELECTOR": continue
        out.append(call("wwv_flow_imp_page.create_ig_report_column", id=Id(nid(pg, key, "rc", name)), view_id=Id(view), display_seq=seqn,
                        column_id=Id(nid(pg, key, "c", {"APEX$ROW_ACTION": "ACT", "ROWID": "ROWID"}.get(name, name))), is_visible=visible, is_frozen=False))
        seqn += 1
    return rid, "".join(out), editable


def row_link(c):
    """URL of a grid column that opens another screen for its row (rules.columns.<COL>.link: {"form", "doc", "items": {TARGET_ITEM:
    COLUMN of the row}}); None when the column has no link or the target screen is unknown."""
    l = c.get("link")
    if not l:
        return None
    f = (l.get("form") or "").upper()
    tp = FORM_PAGES.get(f) if l.get("doc") else SCREEN_PAGES.get(f)
    if not tp:
        print(f"   row link {c['name']} -> {f}: target page unknown")
        return None
    names = [f"P{tp}_{k.upper()}"[:30] for k in (l.get("items") or {})]
    vals = [f"&{v.upper()}." for v in (l.get("items") or {}).values()]
    return f"f?p=&APP_ID.:{tp}:&APP_SESSION.::&DEBUG.:RP:{','.join(names)}:{','.join(vals)}"


def ssq(sql):
    """Scalar subqueries of a computed column get NO_UNNEST: inside the query APEX builds around a grid (outer joins to the
    lists of values, row counting) 19c's scalar-subquery unnesting hits ORA-00600 [qcsvsci1] / ORA-07445 on some grids."""
    return re.sub(r"\(\s*select\s+(?!/\*\+)", "(select /*+ no_unnest */ ", sql or "", flags=re.I)


def alias_t(sql, table):
    """A block WHERE / ORDER BY written against the table name, reused in a query that aliases the table as t."""
    return re.sub(rf"\b{re.escape(table)}\s*\.", "t.", sql or "", flags=re.I)


def sql_cols(blk):
    """Display-only columns computed per row by a SQL expression (rules.computed)."""
    return [c for c in blk["cols"] if c.get("sql")]


def ig_dml(pg, key, rid, blk, seq, name, **kw):
    """Save process for an editable grid: native table DML, or generated PL/SQL when the grid reads a SQL query (debit / credit
    replacing a signed VALUE, computed display columns)."""
    pid = nid(pg, "p", "igdml", key)
    dc = blk.get("debit_credit")
    if not dc and not sql_cols(blk):
        return call("wwv_flow_imp_page.create_page_process", id=Id(pid), process_sequence=seq, process_point="AFTER_SUBMIT",
                    region_id=Id(rid), process_type="NATIVE_IG_DML", process_name=name, attribute_01="REGION_SOURCE",
                    attribute_05="Y", attribute_06="Y", attribute_08="Y", error_display_location="INLINE_IN_NOTIFICATION",
                    internal_uid=pid % 10**15, **kw)
    t = blk["table"]
    v = dc["value"] if dc else None
    cols = [c["name"] for c in blk["cols"] if not c.get("computed") and c["name"] != v]
    ins_cols, ins_vals, upd = list(cols), [":" + c for c in cols], [f"{c} = :{c}" for c in cols]
    if dc:
        val = f"nvl(to_number(:{dc['debit']}), 0) - nvl(to_number(:{dc['credit']}), 0)"
        ins_cols.append(v); ins_vals.append(val); upd.append(f"{v} = {val}")
    code = ("case :APEX$ROW_STATUS\n"
            "when 'C' then\n"
            f"  insert into {t} ({', '.join(ins_cols)})\n"
            f"  values ({', '.join(ins_vals)})\n"
            "  returning rowid into :ROWID;\n"
            "when 'U' then\n"
            f"  update {t} set {', '.join(upd)}\n"
            "   where rowid = :ROWID;\n"
            "when 'D' then\n"
            f"  delete from {t} where rowid = :ROWID;\n"
            "end case;")
    return call("wwv_flow_imp_page.create_page_process", id=Id(pid), process_sequence=seq, process_point="AFTER_SUBMIT",
                region_id=Id(rid), process_type="NATIVE_IG_DML", process_name=name, attribute_01="PLSQL_CODE", attribute_04=code,
                attribute_05="Y", attribute_06="N", attribute_08="Y", error_display_location="INLINE_IN_NOTIFICATION",
                internal_uid=pid % 10**15, **kw)


# ------------------------------------------------------------------ form region (NATIVE_FORM) + items
def form_region(pg, title, blk, lovs, template=T_STANDARD, seq=10, cols_per_row=3, readonly=False):
    rid = nid(pg, "form", "region")
    out = [call("wwv_flow_imp_page.create_page_plug", id=Id(rid), plug_name=title,
                region_template_options="#DEFAULT#" + (":t-Region--scrollBody" if template == T_STANDARD else ""),
                plug_template=template, plug_display_sequence=seq, query_type="TABLE", query_table=blk["table"], include_rowid_column=True,
                is_editable=not readonly, edit_operations="i:u:d" if not readonly else None,
                lost_update_check_type="VALUES" if not readonly else None, plug_source_type="NATIVE_FORM")]
    out.append(call("wwv_flow_imp_page.create_page_item", id=Id(nid(pg, "item", "ROWID")), name=f"P{pg}_ROWID", source_data_type="ROWID",
                    is_primary_key=True, item_sequence=5, item_plug_id=Id(rid), item_source_plug_id=Id(rid), use_cache_before_default="NO",
                    source="ROWID", source_type="REGION_SOURCE_COLUMN", display_as="NATIVE_HIDDEN", is_persistent="N", protection_level="S",
                    attributes=attrs(value_protected="Y")))
    n = 0
    for i, c in enumerate(blk["cols"]):
        name = f"P{pg}_{c['name']}"
        base = dict(id=Id(nid(pg, "item", c["name"])), name=name, source_data_type=data_type(c), is_required=bool(c["required"]) and not readonly,
                    item_sequence=10 * (i + 1), item_plug_id=Id(rid), item_source_plug_id=Id(rid), use_cache_before_default="NO",
                    source=c["name"], source_type="REGION_SOURCE_COLUMN", is_persistent="N", **show_cond(c, "display_when"))
        if c.get("sql"):                                   # computed display value of the record (rules.computed)
            base.update(item_source_plug_id=None, source_type="QUERY", is_required=False, source_data_type=None,
                        source=f"select {ssq(c['sql'])} from {blk['table']} t where t.rowid = :P{pg}_ROWID")
        elif c.get("computed"):
            continue
        if c["hidden"]:
            out.append(call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_HIDDEN", attributes=attrs(value_protected="N")))
            continue
        disp, extra, at = item_widget(c, lovs)
        if c.get("lov_sql") and extra.get("lov"):         # list SQL of the record's other fields (:PAGE_<COL>), refreshed when they change
            extra["lov"] = extra["lov"].replace(":PAGE_", f":P{pg}_")
            if c.get("cascade"):
                extra.update(lov_cascade_parent_items=",".join(f"P{pg}_{x}" for x in c["cascade"]), ajax_optimize_refresh="Y")
        span = 12 if c["widget"] == "TEXTAREA" else 12 // cols_per_row
        new_line = "Y" if (n % cols_per_row == 0 or span == 12) else "N"
        if span == 12: n = 0
        else: n += 1
        kw = dict(base, prompt=c["label_a"] or c["label_e"], display_as=disp, cSize=32,
                  cMaxlength=(c["len"] if c["type"] in ("VARCHAR2", "CHAR", "NVARCHAR2") and c["len"] else None),
                  begin_on_new_line=new_line, colspan=span, label_alignment="RIGHT",
                  field_template=T_LABEL_REQ if (c["required"] and not readonly) else T_LABEL_OPT, item_template_options="#DEFAULT#",
                  attributes=at, **extra)
        if c.get("readonly") or readonly or c.get("sql"):
            kw["read_only_when_type"] = "ALWAYS"
        elif c.get("ro_update"):                           # editable on a new record only
            kw.update(read_only_when_type="ITEM_IS_NOT_NULL", read_only_when=f"P{pg}_ROWID")
        dflt = c.get("default")
        if dflt and not readonly and not c.get("sql"):
            kw["item_default"] = dflt["value"]
            if dflt["type"] != "STATIC":
                kw["item_default_type"] = dflt["type"]
                if dflt["type"] in ("EXPRESSION", "FUNCTION_BODY"): kw["item_default_language"] = "PLSQL"
        out.append(call("wwv_flow_imp_page.create_page_item", **kw))
    return rid, "".join(out)


def safe_where(w):
    """Legacy block WHERE clauses may reference Forms items (:BLOCK.ITEM, :GLOBAL.X); only keep self-contained ones."""
    if not w: return None
    body = re.sub(r"'[^']*'", "", w)
    if re.search(r":(?!G_)[A-Za-z]", body) or "&" in body:
        return None
    return w


def buttons(pg, region_id, list_page=None, modal=False, readonly=False, stay=False, ops="iud", da=False):
    """da: Save / Create are handled by a dynamic action (legacy warnings are confirmed first, see warning_components)."""
    out = []
    cond_new = f"P{pg}_ROWID"
    if modal:
        out.append(call("wwv_flow_imp_page.create_page_button", id=Id(nid(pg, "btn", "CANCEL")), button_sequence=10, button_plug_id=Id(region_id),
                        button_name="CANCEL", button_action="DEFINED_BY_DA", button_template_options="#DEFAULT#", button_template_id=T_BUTTON,
                        button_image_alt="إلغاء", button_position="CLOSE", button_alignment="RIGHT"))
    else:
        out.append(call("wwv_flow_imp_page.create_page_button", id=Id(nid(pg, "btn", "CANCEL")), button_sequence=10, button_plug_id=Id(region_id),
                        button_name="CANCEL", button_action="REDIRECT_PAGE", button_template_options="#DEFAULT#", button_template_id=T_BUTTON,
                        button_image_alt="رجوع", button_position="CLOSE", button_alignment="RIGHT",
                        button_redirect_url=f"f?p=&APP_ID.:{list_page}:&APP_SESSION.::&DEBUG.:::"))
    if readonly:
        return "".join(out)
    if "d" in ops:
        out.append(call("wwv_flow_imp_page.create_page_button", id=Id(nid(pg, "btn", "DELETE")), button_sequence=20, button_plug_id=Id(region_id),
                    button_name="DELETE", button_action="SUBMIT", button_template_options="#DEFAULT#", button_template_id=T_BUTTON,
                    button_image_alt="حذف", button_position="DELETE", button_alignment="RIGHT", button_execute_validations="N",
                    confirm_message="&APP_TEXT$DELETE_MSG!RAW.", confirm_style="danger", button_condition=cond_new,
                    button_condition_type="ITEM_IS_NOT_NULL", database_action="DELETE", security_scheme=Id(AZ_DEL)))
    out.append(call("wwv_flow_imp_page.create_page_button", id=Id(nid(pg, "btn", "SAVE")), button_sequence=30, button_plug_id=Id(region_id),
                    button_name="SAVE", button_action="DEFINED_BY_DA" if da else "SUBMIT", button_template_options="#DEFAULT#", button_template_id=T_BUTTON,
                    button_is_hot="Y", button_image_alt="حفظ التعديلات", button_position="NEXT", button_alignment="RIGHT",
                    button_condition=cond_new, button_condition_type="ITEM_IS_NOT_NULL", database_action=None if da else "UPDATE",
                    security_scheme=Id(AZ_UPD)))
    if "i" in ops:
        out.append(call("wwv_flow_imp_page.create_page_button", id=Id(nid(pg, "btn", "CREATE")), button_sequence=40, button_plug_id=Id(region_id),
                        button_name="CREATE", button_action="DEFINED_BY_DA" if da else "SUBMIT", button_template_options="#DEFAULT#",
                        button_template_id=T_BUTTON, button_is_hot="Y", button_image_alt="إضافة", button_position="NEXT", button_alignment="RIGHT",
                        button_condition=cond_new, button_condition_type="ITEM_IS_NULL", database_action=None if da else "INSERT",
                        security_scheme=Id(AZ_INS)))
    return "".join(out)


def ops_of(blk):
    return "".join(x for x, ok in (("i", blk.get("insert", True)), ("u", blk.get("update", True)), ("d", blk.get("delete", True))) if ok)


def page_header(pg, name, title, alias, mode="NORMAL", width=None, help_text=None, extra_css=None):
    kw = dict(id=pg, name=name, alias=alias, step_title=title, autocomplete_on_off="OFF", page_template_options="#DEFAULT#",
              required_role=Id(AZ_PAGE), protection_level="C", help_text=help_text, inline_css=extra_css)
    if mode == "MODAL":
        kw.update(page_mode="MODAL", dialog_width=width or "900", dialog_chained="N", dialog_resizable="Y")
    return call("wwv_flow_imp_page.create_page", **kw)


def alias_of(spec, suffix=""):
    return (re.sub(r"[^A-Z0-9]+", "-", spec["form"].upper()).strip("-") + suffix)[:250]


def title_region(pg, text_a, seq=5):
    return ""  # page title shown by the UT header; kept as a hook


# ------------------------------------------------------------------ page patterns
def gen_grid(spec, lovs):
    pg = spec["page"]; m = spec["master"]
    body = page_header(pg, f"{spec['form']} - {spec['title_e']}", spec["title_a"], alias_of(spec))
    readonly = not (m.get("insert", True) or m.get("update", True) or m.get("delete", True))
    rid, src, editable = ig_region(pg, "ig", spec["title_a"], m, 10, lovs, hide_header=True, readonly=readonly,
                                   where=safe_where(m.get("where")))
    body += src
    if editable:
        acts = action_requests(spec)
        body += ig_dml(pg, "grid", rid, m, 10, "حفظ البيانات",
                       **(dict(process_when=",".join(acts), process_when_type="REQUEST_NOT_IN_CONDITION") if acts else {}))
    body += action_components(pg, spec, doc=False)       # grid rules: row_rules only (grids save by AJAX, page processes do not run)
    body += link_buttons(pg, spec, rid, doc=False)
    if spec.get("print_rdf"):
        body += print_buttons_on(pg, spec, rid, doc=False)
        return {pg: body, **gen_print(spec, doc=False)}
    return {pg: body}


def ir_list(spec, lovs, target_page, target_is_modal):
    """Interactive report over the master table with an edit link to target_page (by ROWID)."""
    pg = spec["page"]; m = spec["master"]
    body = page_header(pg, f"{spec['form']} - {spec['title_e']}", spec["title_a"], alias_of(spec))
    rid = nid(pg, "ir", "region")
    src = dict(query_type="TABLE", query_table=m["table"], query_where=safe_where(m.get("where")), include_rowid_column=True)
    if sql_cols(m):                                      # computed display columns: the list reads a query
        w = safe_where(m.get("where"))
        src = dict(query_type="SQL", include_rowid_column=False,
                   plug_source="select " + ",\n       ".join(["t.rowid"] + [f"t.{c['name']}" for c in m["cols"] if not c.get("computed")]
                                                            + [f"({ssq(c['sql'])}) {c['name']}" for c in sql_cols(m)])
                               + f"\n  from {m['table']} t" + (f"\n where {alias_t(w, m['table'])}" if w else ""))
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(rid), plug_name=spec["title_a"],
                 region_template_options="#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc", plug_template=T_IRR,
                 plug_display_sequence=10, **src, plug_source_type="NATIVE_IR", prn_page_header=spec["title_a"])
    ws = nid(pg, "ir", "ws")
    body += call("wwv_flow_imp_page.create_worksheet", id=Id(ws), name=spec["title_a"],
                 max_row_count_message="The maximum row count for this report is #MAX_ROW_COUNT# rows.  Please apply a filter to reduce the number of records in your query.",
                 no_data_found_message="لا توجد بيانات", base_pk1="ROWID", pagination_type="ROWS_X_TO_Y", pagination_display_pos="BOTTOM_RIGHT",
                 report_list_mode="TABS", lazy_loading=False, show_detail_link="C", show_notify="Y", download_formats="CSV:HTML:XLSX:PDF",
                 enable_mail_download="Y",
                 detail_link=f"f?p=&APP_ID.:{target_page}:&APP_SESSION.::&DEBUG.:RP:P{target_page}_ROWID:\\#ROWID#\\",
                 detail_link_text='<span role="img" aria-label="تعديل" class="fa fa-edit" title="تعديل"></span>',
                 owner="CLAUDE", internal_uid=ws % 10**15)
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    def ident(i):
        return letters[i] if i < 26 else letters[i // 26 - 1] + letters[i % 26]
    body += call("wwv_flow_imp_page.create_worksheet_column", id=Id(nid(pg, "ir", "col", "ROWID")), db_column_name="ROWID", display_order=0,
                 column_identifier="A", column_label="ROWID", column_type="OTHER", display_text_as="HIDDEN", heading_alignment="LEFT",
                 tz_dependent="N", use_as_row_header="N")
    shown = []
    for i, c in enumerate(m["cols"]):
        typ = {"NUMBER": "NUMBER", "DATE": "DATE", "TIMESTAMP": "DATE"}.get(data_type(c), "STRING")
        kw = dict(id=Id(nid(pg, "ir", "col", c["name"])), db_column_name=c["name"], display_order=i + 1, column_identifier=ident(i + 1),
                  column_label=c["label_a"] or c["label_e"], column_type=typ, heading_alignment="RIGHT" if typ == "NUMBER" else "LEFT",
                  column_alignment="RIGHT" if typ == "NUMBER" else None, tz_dependent="N", use_as_row_header="N")
        if c["lov"] in lovs and c["widget"] in ("SELECT", "POPUP"):
            kw.update(display_text_as="LOV_ESCAPE_SC", rpt_named_lov=Id(lov_id(c["lov"])), rpt_show_filter_lov="1")
        if c["hidden"]:
            kw.update(display_text_as="HIDDEN_ESCAPE_SC")
        kw.update(show_cond(c))                            # list column shown only with the right
        body += call("wwv_flow_imp_page.create_worksheet_column", **kw)
        if not c["hidden"] and len(shown) < 10:
            shown.append(c["name"])
    body += call("wwv_flow_imp_page.create_worksheet_rpt", id=Id(nid(pg, "ir", "rpt")), application_user="APXWS_DEFAULT", report_seq=10,
                 report_alias=str(nid(pg, "ir", "rpt") % 10**8), status="PUBLIC", is_default="Y", report_columns=":".join(shown))
    readonly = not m.get("insert", True)
    if not readonly:
        body += call("wwv_flow_imp_page.create_page_button", id=Id(nid(pg, "btn", "CREATE")), button_sequence=10, button_plug_id=Id(rid),
                     button_name="CREATE", button_action="REDIRECT_PAGE", button_template_options="#DEFAULT#", button_template_id=T_BUTTON,
                     button_is_hot="Y", button_image_alt="إضافة", button_position="RIGHT_OF_IR_SEARCH_BAR",
                     button_redirect_url=f"f?p=&APP_ID.:{target_page}:&APP_SESSION.::&DEBUG.:{target_page}::", security_scheme=Id(AZ_INS))
    if target_is_modal:
        ev = nid(pg, "da", "closed")
        body += call("wwv_flow_imp_page.create_page_da_event", id=Id(ev), name="Edit Report - Dialog Closed", event_sequence=10,
                     triggering_element_type="REGION", triggering_region_id=Id(rid), bind_type="bind", execution_type="IMMEDIATE",
                     bind_event_type="apexafterclosedialog")
        body += call("wwv_flow_imp_page.create_page_da_action", id=Id(nid(pg, "da", "refresh")), event_id=Id(ev), event_result="TRUE",
                     action_sequence=10, execute_on_page_init="N", action="NATIVE_REFRESH", affected_elements_type="REGION", affected_region_id=Id(rid))
    return pg, body


def gen_report_form(spec, lovs):
    pg, list_body = ir_list(spec, lovs, spec["form_page"], True)
    fp = spec["form_page"]; m = spec["master"]
    readonly = not (m.get("insert", True) or m.get("update", True) or m.get("delete", True))
    body = page_header(fp, f"{spec['form']} - {spec['title_e']} (form)", spec["title_a"], alias_of(spec, f"-FORM-{fp}"), mode="MODAL",
                       width="1100" if len(m["cols"]) > 12 else "800")
    rid, src = form_region(fp, spec["title_a"], m, lovs, template=T_DIALOG_REGION, cols_per_row=2, readonly=readonly)
    body += src
    brid = nid(fp, "buttons", "region")
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(brid), plug_name="Buttons", region_template_options="#DEFAULT#",
                 plug_template=T_BUTTONS, plug_display_sequence=20, plug_display_point="REGION_POSITION_03",
                 attributes=attrs(expand_shortcuts="N", output_as="TEXT", show_line_breaks="Y"))
    rules = spec.get("rules") or {}
    body += buttons(fp, brid, modal=True, readonly=readonly, ops=ops_of(m), da=bool(rules.get("warnings")))
    body += print_buttons_on(fp, spec, brid)
    body += link_buttons(fp, spec, brid)
    ev = nid(fp, "da", "cancel")
    body += call("wwv_flow_imp_page.create_page_da_event", id=Id(ev), name="Cancel Dialog", event_sequence=10, triggering_element_type="BUTTON",
                 triggering_button_id=Id(nid(fp, "btn", "CANCEL")), bind_type="bind", execution_type="IMMEDIATE", bind_event_type="click")
    body += call("wwv_flow_imp_page.create_page_da_action", id=Id(nid(fp, "da", "cancel", "a")), event_id=Id(ev), event_result="TRUE",
                 action_sequence=10, execute_on_page_init="N", action="NATIVE_DIALOG_CANCEL")
    if not readonly:
        skip = action_requests(spec) + (["DELETE"] if rules.get("soft_delete") else [])
        body += call("wwv_flow_imp_page.create_page_process", id=Id(nid(fp, "p", "dml")), process_sequence=10, process_point="AFTER_SUBMIT",
                     region_id=Id(rid), process_type="NATIVE_FORM_DML", process_name="حفظ النموذج", attribute_01="REGION_SOURCE",
                     attribute_05="Y", attribute_06="Y", attribute_08="Y", error_display_location="INLINE_IN_NOTIFICATION",
                     internal_uid=nid(fp, "p", "dml") % 10**15,
                     **(dict(process_when=",".join(skip), process_when_type="REQUEST_NOT_IN_CONDITION") if skip else {}))
        body += soft_delete_components(fp, spec, [])
        body += warning_components(fp, spec, [f"P{fp}_{c['name']}" for c in m["cols"]])
    body += action_components(fp, spec, doc=True, modal=True)
    if not readonly:
        body += call("wwv_flow_imp_page.create_page_process", id=Id(nid(fp, "p", "close")), process_sequence=50, process_point="AFTER_SUBMIT",
                     process_type="NATIVE_CLOSE_WINDOW", process_name="Close Dialog", error_display_location="INLINE_IN_NOTIFICATION",
                     process_when="CREATE,SAVE,DELETE", process_when_type="REQUEST_IN_CONDITION", internal_uid=nid(fp, "p", "close") % 10**15)
    body += call("wwv_flow_imp_page.create_page_process", id=Id(nid(fp, "p", "init")), process_sequence=10, process_point="BEFORE_HEADER",
                 region_id=Id(rid), process_type="NATIVE_FORM_INIT", process_name="تهيئة النموذج", error_display_location="INLINE_IN_NOTIFICATION",
                 internal_uid=nid(fp, "p", "init") % 10**15)
    body += rules_components(fp, spec, rid)
    return {pg: list_body, fp: body, **(gen_print(spec) if spec.get("print_rdf") else {})}


AUDIT_FK_RE = re.compile(r"^(CREATE|UPDATE|INSERT|MODIFY)_|PASSWORD_NUMBER$|USER_CODE$|COMPANY_CODE$")
SUM_RE = re.compile(r"VALUE|AMOUNT|AMNT|QTY|QUANTITY|TOTAL|PRICE|DEBIT|CREDIT|DISC|TAX|BONUS|COST|NET")
PRINT_CSS = """.ascon-print{font-family:'Segoe UI',Tahoma,Arial,sans-serif;font-size:13px;color:#000;background:#fff;padding:12px;max-width:1100px;margin:auto}
.ap-head{display:flex;justify-content:space-between;align-items:center;border-bottom:2px solid #333;padding-bottom:8px}
.ap-comp-name{font-size:18px;font-weight:700}.ap-comp-sub{font-size:12px;color:#333}.ap-logo{max-height:70px}
.ap-title{text-align:center;font-size:20px;margin:12px 0}.ap-sub{font-size:15px;margin:14px 0 6px}
.ap-fields{width:100%;border-collapse:collapse}.ap-fields td{border:1px solid #bbb;padding:4px 6px;width:33%;vertical-align:top}
.ap-l{display:block;font-size:11px;color:#555}.ap-v{font-weight:600}
.ap-lines{width:100%;border-collapse:collapse}.ap-lines th,.ap-lines td{border:1px solid #999;padding:3px 5px}.ap-lines th{background:#eee}
.ap-lines td.n{text-align:left;direction:ltr;white-space:nowrap}.ap-lines tfoot td{font-weight:700;background:#f5f5f5}
.ap-sign{display:flex;justify-content:space-around;margin-top:40px;text-align:center}.ap-sign div{width:30%;border-top:1px solid #333;padding-top:6px}
.ap-foot{margin-top:18px;font-size:10px;color:#666}
@media print{.t-Header,.t-Body-nav,.t-Footer,.t-Body-actions,.t-ButtonRegion,.no-print,.t-Body-title,.t-Region-header{display:none!important}
.t-Body-main,.t-Body-content,.t-Body-contentInner{margin:0!important;padding:0!important}.t-Region{border:0!important;box-shadow:none!important}}"""


_META = None


def meta():
    global _META
    if _META is None:
        _META = json.load(io.open(mp.work("cache", "meta.json"), encoding="utf-8"))
    return _META


def name_column(table):
    """Arabic name/description column of a code table (same choice as the LOVs)."""
    m = meta().get(table)
    if not m: return None
    best = None
    for c in m["cols"]:
        n = c["name"]
        if c["type"] not in ("VARCHAR2", "CHAR", "NVARCHAR2") or re.search(r"_(E|EN|ENG)$", n): continue
        score = 5 if re.search(r"(^|_)(NAME|DESC|DESCRIPTION|TITLE)(_A|_AR)?$", n) else 3 if "NAME" in n else 0
        if score and (best is None or score > best[0]): best = (score, n)
    return best[1] if best else None


def print_spec(spec):
    m = spec["master"]
    def cols(blk, skip=()):
        out = []
        for c in blk["cols"]:
            if c["hidden"] or c["name"] in skip: continue
            t = "N" if c["type"] == "NUMBER" else "D" if c["type"] == "DATE" else "S"
            o = {"c": c["name"], "l": c["label_a"] or c["label_e"], "t": t}
            if c.get("sql"):
                o["x"] = f"to_char({ssq(c['sql'])})"
            elif c.get("computed") and blk.get("debit_credit"):
                v = blk["debit_credit"]["value"]
                o["x"] = f"to_char(case when t.{v} > 0 then t.{v} end)" if c["name"] == blk["debit_credit"]["debit"] else f"to_char(case when t.{v} < 0 then -t.{v} end)"
            if t == "N" and (c.get("computed") or (SUM_RE.search(c["name"]) and not re.search(r"CODE|_NO$|SERIAL|SEQ|RATE|RATIO|PER", c["name"]))):
                o["t"] = "M"; o["sum"] = True
            out.append(o)
        # names of referenced codes (item, customer, store, account ...), also through composite foreign keys
        present = {o["c"] for o in out}
        tcols = {c["name"] for c in meta().get(blk["table"], {}).get("cols", [])}
        import logical
        fks = list(meta().get(blk["table"], {}).get("fks", []))
        for col in [o["c"] for o in out]:             # logical links after declared ones (column order: stable builds)
            lp = logical.logical_parent(blk["table"], col, meta())
            if lp:
                fks.append({"cols": [col], "parent": lp[0], "pcols": [lp[1]]})
        named = set()
        for fk in fks:
            last = fk["cols"][-1]
            if last in named or last not in present or any(x not in tcols for x in fk["cols"]) or AUDIT_FK_RE.search(last): continue
            disp = name_column(fk["parent"])
            if not disp: continue
            named.add(last)
            pos = next(i for i, o in enumerate(out) if o["c"] == last)
            lbl = out[pos]["l"] or ""
            name_lbl = lbl.replace("رقم", "اسم", 1) if "رقم" in lbl else (lbl + " - الاسم")
            cond = " and ".join(f"p.{pc} = t.{c}" for c, pc in zip(fk["cols"], fk["pcols"]))
            out.insert(pos + 1, {"c": f"NM{pos}_{last}"[:30], "l": name_lbl, "t": "S",
                                 "x": f"(select max(p.{disp}) from {fk['parent']} p where {cond})"})
        return out
    js = {"title": spec["title_a"], "table": m["table"], "cols": cols(m), "details": []}
    mcols = {c["name"] for c in m["cols"]}
    for d in spec["details"]:
        if d.get("parent"): continue                          # sub-grids (detail of a detail) are not printed
        join = [[dc, mc] for dc, mc in d["join"] if mc in mcols]
        if not join: continue
        pk = [c["name"] for c in d["cols"] if c.get("pk") and c["name"] not in {x for x, _ in join}]
        extra = {"order": ", ".join(pk)} if pk else {}
        if d.get("dwhere"):                   # the grid's own filter; document values read from the printed row
            extra["where"] = re.sub(r":PAGE_([A-Za-z0-9_$#]+)",
                                    lambda mm: f"(select m.{mm.group(1).upper()} from {m['table']} m where m.rowid = chartorowid(:r))", d["dwhere"])
        js["details"].append({"table": d["table"], "title": d.get("title_a") or d.get("title_e") or "التفاصيل",
                              "join": join, "cols": cols(d, skip={x for x, _ in join}), **extra})
    return js


def rdf_kinds(pr):
    """The prints of one document screen: the main print (kind MAIN) and optional further print buttons ("more")."""
    out = [dict(pr, key="MAIN")]
    for k, extra in enumerate(pr.get("more") or []):
        out.append(dict(extra, key=(extra.get("key") or f"K{k + 1}").upper()))
    return out


def print_page(spec):
    """Page number of the print page of a screen: document / form page + 1, or list page + 2 for grids and process screens."""
    return (spec["form_page"] + 1) if spec.get("form_page") else spec["page"] + 2


def rdf_id(pr, key="rdf"):
    import rdfprint
    return rdfprint.report_id(rdfprint.find_rdf(pr[key], pr.get("rdf_module")))


def rdf_params_sql(spec, pr, pp, doc=True):
    """PL/SQL block (before header of the print page): print right, first-print flag and the report parameters from the header row
    (doc: a document / form record by P<pp>_ROWID; otherwise a list print whose parameters are expressions only)."""
    t = spec["master"]["table"] if (doc and spec.get("master")) else "dual"
    tcols = {c["name"]: c["type"] for c in meta().get(t, {}).get("cols", [])} if t != "dual" else {}
    parts = []
    for name, src in (pr.get("params") or {}).items():
        src = src.strip()
        if src.startswith("@"):                              # a field of the screen itself (process / query screens submit it first)
            item = f"P{spec['page']}_{src[1:].upper()}"[:30]
            parts.append(f"'{name.upper()}=' || replace(v('{item}'), chr(30), ' ')")
            continue
        if re.fullmatch(r"[A-Za-z][A-Za-z0-9_$#]*", src):
            col = src.upper()
            if col not in tcols:
                print(f"   print {spec['form']}: column {col} not in {t}; parameter {name} skipped"); continue
            expr = f"to_char(t.{col}, 'DD-MM-YYYY')" if tcols[col] == "DATE" else f"t.{col}"
        else:
            expr = src
        parts.append(f"'{name.upper()}=' || replace({expr}, chr(30), ' ')")
    sep = " || chr(30) || "
    fp = pr.get("first_print") or {}
    flag = (fp.get("flag") or "").upper()
    flag_sel = f", nvl(t.{flag}, 0)" if flag and flag in tcols else ", 1"
    rid = rdf_id(pr)
    if pr.get("rdf_e"):                                  # the legacy printed an English twin report for LANG = E
        rid = f"' || case when app_sec.lang = 'en' then '{rdf_id(pr, 'rdf_e')}' else '{rid}' end || '"
    right = pr.get("right")
    code = ["declare", "  l_ok number := 1;", "  l_flag number;", "  l_p varchar2(32767);", "begin"]
    if right:
        code += [f"  begin execute immediate q'~{right.replace(':G_USER_CODE', ':1')}~' into l_ok using v('G_USER_CODE');",
                 "  exception when others then l_ok := 0; end;"]
    code += ["  if nvl(l_ok, 0) = 0 then",
             f"    :P{pp}_DENY := 'Y'; return;",
             "  end if;",
             f"  select {sep.join(parts) if parts else 'null'}{flag_sel}",
             "    into l_p, l_flag",
             f"    from {t} t" + (f" where rowid = :P{pp}_ROWID;" if t != "dual" else ";")]
    if flag and flag in tcols:
        code += ["  if l_flag = 0 then",
                 "    begin",
                 f"      update {t} set {flag} = 1 where rowid = :P{pp}_ROWID;",
                 f"      l_p := l_p || chr(30) || '{(fp.get('param') or 'P_FIRST').upper()}=1';",
                 "    exception when others then null;          -- the document stays unmarked; the print still shows",
                 "    end;",
                 "  end if;"]
    std = {"LANG": "case when app_sec.lang = 'en' then 'E' else 'A' end", "COMP_CODE": "v('G_COMPANY_CODE')", "P_COMPANY": "v('G_COMPANY_CODE')",
           "P_USERS_CODE": "v('G_USER_CODE')", "USERS_CODE": "v('G_USER_CODE')", "P_USER": "v('G_USER_CODE')", "P_PRIN_USER": "v('G_USER_CODE')",
           "P_PASSWORD_NUMBER": "v('G_PASSWORD_NUMBER')", "PASSWORD_NUMBER": "v('G_PASSWORD_NUMBER')", "P_SYSTEM_NUMBER": f"'{spec.get('system') or ''}'"}
    for k, v in std.items():
        if k not in {n.upper() for n in (pr.get("params") or {})}:
            code.append(f"  l_p := l_p || chr(30) || '{k}=' || {v};")
    code += [f"  :P{pp}_PARAMS := nvl(l_p, ' ');", "exception when no_data_found then", f"  :P{pp}_DENY := 'N';", "end;"]
    return rid, "\n".join(code)


def gen_print_rdf(spec, pp, body, doc=True):
    """Print page drawing the legacy report layout of the document (see rdfprint.py / APP_RDF).  With several prints per document
    (prints.json "more"), P<pp>_KIND chooses the report."""
    kinds = rdf_kinds(spec["print_rdf"])
    blocks = []
    for kd in kinds:
        rid, code = rdf_params_sql(spec, kd, pp, doc=doc)
        code = code.replace(f":P{pp}_PARAMS := nvl(l_p, ' ');", f":P{pp}_PARAMS := nvl(l_p, ' ');\n  :P{pp}_RDF := '{rid}';")
        blocks.append((kd["key"], code))
    if len(blocks) == 1:
        code = blocks[0][1]
    else:
        code = "begin\n  case nvl(:P{pp}_KIND, 'MAIN')\n".replace("{pp}", str(pp))
        for key, c in blocks:
            code += f"  when '{key}' then\n" + c + "\n"
        code += "  else null;\n  end case;\nend;"
    reg = nid(pp, "print")
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(reg), plug_name=spec["title_a"], region_template_options="#DEFAULT#",
                 plug_template=T_BLANK, plug_display_sequence=10, plug_source=f"app_rdf.render(:P{pp}_RDF, :P{pp}_PARAMS);",
                 plug_source_type="NATIVE_PLSQL", plug_query_options="DERIVED_REPORT_COLUMNS",
                 plug_display_condition_type="EXPRESSION", plug_display_when_condition=f":P{pp}_PARAMS is not null", plug_display_when_cond2="PLSQL")
    for k, (name, prot) in enumerate((("ROWID", "Y"), ("PARAMS", "Y"), ("DENY", "N"), ("KIND", "N"), ("RDF", "Y"))):
        body += call("wwv_flow_imp_page.create_page_item", id=Id(nid(pp, name.lower())), name=f"P{pp}_{name}", item_sequence=10 + k,
                     item_plug_id=Id(reg), display_as="NATIVE_HIDDEN", is_persistent="N", protection_level="S" if name == "ROWID" else None,
                     attributes=attrs(value_protected=prot))
    msg = ('<div class="t-Alert t-Alert--danger t-Alert--horizontal t-Alert--defaultIcons"><div class="t-Alert-wrap"><div class="t-Alert-content">'
           '<div class="t-Alert-body">ليس لك صلاحية الطباعة</div></div></div></div>')
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(nid(pp, "deny")), plug_name="deny", region_template_options="#DEFAULT#",
                 plug_template=T_BLANK, plug_display_sequence=5, plug_source=msg, plug_query_options="DERIVED_REPORT_COLUMNS",
                 plug_display_condition_type="VAL_OF_ITEM_IN_COND_EQ_COND2", plug_display_when_condition=f"P{pp}_DENY", plug_display_when_cond2="Y",
                 attributes=attrs(expand_shortcuts="N", output_as="HTML"))
    pid = nid(pp, "p", "params")
    body += call("wwv_flow_imp_page.create_page_process", id=Id(pid), process_sequence=10, process_point="BEFORE_HEADER",
                 process_type="NATIVE_PLSQL", process_name="معايير الطباعة", process_sql_clob=code, process_clob_language="PLSQL",
                 error_display_location="INLINE_IN_NOTIFICATION", internal_uid=pid % 10**15)
    return body


def print_buttons_on(pg, spec, region_id, doc=True, submit=False):
    """Print buttons of a screen (legacy print buttons, prints.json): main print and the further ones ("more").  'when': a SQL
    condition over the record (alias t) deciding whether the button is shown (e.g. voucher entry only when posted).  submit: the
    button submits the page (a process / query screen whose parameters the report reads) and a branch opens the print page."""
    pr = spec.get("print_rdf")
    if not pr:
        return ""
    pp = print_page(spec)
    out = ""
    t = spec["master"]["table"] if spec.get("master") else None
    for k, kd in enumerate(rdf_kinds(pr)):
        url_items = (f"P{pp}_ROWID,P{pp}_KIND:&P{pg}_ROWID.,{kd['key']}" if doc else f"P{pp}_KIND:{kd['key']}")
        cond = dict(button_condition=f"P{pg}_ROWID", button_condition_type="ITEM_IS_NOT_NULL") if doc else {}
        if doc and kd.get("when") and t:
            cond = dict(button_condition=f":P{pg}_ROWID is not null and exists (select 1 from {t} t where t.rowid = :P{pg}_ROWID and ({kd['when']}))",
                        button_condition2="PLSQL", button_condition_type="EXPRESSION")
        action = dict(button_action="SUBMIT") if submit else dict(button_action="REDIRECT_PAGE",
                                                                   button_redirect_url=f"f?p=&APP_ID.:{pp}:&APP_SESSION.::&DEBUG.::{url_items}")
        out += call("wwv_flow_imp_page.create_page_button", id=Id(nid(pg, "btn", "PRINT", kd["key"])), button_sequence=15 + k,
                    button_plug_id=Id(region_id), button_name=f"PRINT_{kd['key']}"[:30],
                    button_template_options="#DEFAULT#", button_template_id=T_BUTTON,
                    button_image_alt=kd.get("label_a") or ("طباعة" if kd["key"] == "MAIN" else kd["key"]),
                    button_position="NEXT", button_alignment="RIGHT", icon_css_classes="fa-print", **action, **cond)
    return out


def gen_print(spec, doc=True):
    pp = print_page(spec)
    body = page_header(pp, f"{spec['form']} - {spec['title_e']} (print)", spec["title_a"], alias_of(spec, f"-PRINT-{pp}"), extra_css=PRINT_CSS)
    if spec.get("print_rdf"):
        try:
            return {pp: gen_print_buttons(pp, gen_print_rdf(spec, pp, body, doc=doc))}
        except FileNotFoundError as e:
            print(f"   print {spec['form']}: report not found ({e}); generic print view used")
    if not doc or spec["pattern"] != "MASTER_DETAIL":
        return {}
    rid = nid(pp, "print")
    js = json.dumps(print_spec(spec), ensure_ascii=False, indent=0)     # one element per line: no line needs splitting
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(rid), plug_name=spec["title_a"], region_template_options="#DEFAULT#",
                 plug_template=T_BLANK, plug_display_sequence=10, plug_source=f"app_print.document(q'~{js}~', :P{pp}_ROWID);",
                 plug_source_type="NATIVE_PLSQL", plug_query_options="DERIVED_REPORT_COLUMNS")
    body += call("wwv_flow_imp_page.create_page_item", id=Id(nid(pp, "rowid")), name=f"P{pp}_ROWID", item_sequence=10, item_plug_id=Id(rid),
                 display_as="NATIVE_HIDDEN", is_persistent="N", protection_level="S", attributes=attrs(value_protected="Y"))
    return {pp: gen_print_buttons(pp, body)}


def gen_print_buttons(pp, body):
    brid = nid(pp, "btns")
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(brid), plug_name="Buttons", region_template_options="#DEFAULT#",
                 region_css_classes="no-print", plug_template=T_BUTTONS, plug_display_sequence=5, plug_display_point="REGION_POSITION_01",
                 attributes=attrs(expand_shortcuts="N", output_as="TEXT", show_line_breaks="Y"))
    body += call("wwv_flow_imp_page.create_page_button", id=Id(nid(pp, "btn", "PRINT")), button_sequence=10, button_plug_id=Id(brid),
                 button_name="PRINT", button_action="REDIRECT_URL", button_template_options="#DEFAULT#", button_template_id=T_BUTTON,
                 button_is_hot="Y", button_image_alt="طباعة", button_position="NEXT", button_redirect_url="javascript:window.print();",
                 icon_css_classes="fa-print")
    body += call("wwv_flow_imp_page.create_page_button", id=Id(nid(pp, "btn", "BACK")), button_sequence=20, button_plug_id=Id(brid),
                 button_name="BACK", button_action="REDIRECT_URL", button_template_options="#DEFAULT#", button_template_id=T_BUTTON,
                 button_image_alt="رجوع", button_position="PREVIOUS", button_redirect_url="javascript:history.back();")
    return body


def rules_components(pg, spec, main_region_id=None):
    """Validations (before DML) and after-save checks (after all DML, may raise to roll back) from reviewed rules."""
    rules = spec.get("rules") or {}
    out = ""
    for k, v in enumerate(rules.get("validations") or []):
        out += call("wwv_flow_imp_page.create_page_validation", id=Id(nid(pg, "val", k)), validation_name=v.get("name") or f"rule {k + 1}",
                    validation_sequence=100 + k, validation=v["plsql"].replace(":PAGE_", f":P{pg}_"), validation2="PLSQL",
                    validation_type="FUNC_BODY_RETURNING_ERR_TEXT", error_message=v.get("message") or "#ERROR#",
                    validation_condition=v.get("when") or "CREATE,SAVE", validation_condition_type="REQUEST_IN_CONDITION",
                    error_display_location="INLINE_IN_NOTIFICATION")
    for k, a in enumerate(rules.get("after_save") or []):
        out += call("wwv_flow_imp_page.create_page_process", id=Id(nid(pg, "after", k)), process_sequence=90 + k, process_point="AFTER_SUBMIT",
                    process_type="NATIVE_PLSQL", process_name=a.get("name") or f"after save {k + 1}",
                    process_sql_clob=a["plsql"].replace(":PAGE_", f":P{pg}_"), process_clob_language="PLSQL",
                    error_display_location="INLINE_IN_NOTIFICATION", process_when=a.get("when") or "CREATE,SAVE",
                    process_when_type="REQUEST_IN_CONDITION", internal_uid=nid(pg, "after", k) % 10**15)
    return out


FORM_PAGES = {}        # legacy form -> document page, filled by build.py before generating (targets of action buttons)


SCREEN_PAGES = {}      # legacy form -> its main (list / grid / process) page, filled by build.py (targets of link buttons)


def link_buttons(pg, spec, region_id, doc=True):
    """Buttons that only open another screen (legacy CALL_FORM / GO_BLOCK buttons): overrides "links": [{"label_a", "form",
    "items": {"TARGET_ITEM": "COLUMN of this record" | "'literal'"}, "doc": true = the target's document page}]."""
    out = ""
    for k, l in enumerate(spec.get("links") or []):
        f = (l.get("form") or "").upper()
        tp = FORM_PAGES.get(f) if l.get("doc") else SCREEN_PAGES.get(f)
        if not tp:
            print(f"   link {spec['form']} -> {f}: target page unknown; button skipped"); continue
        names, vals = [], []
        for ti, src in (l.get("items") or {}).items():
            names.append(f"P{tp}_{ti.upper()}"[:30])
            vals.append(src.strip("'") if src.startswith("'") else f"&P{pg}_{src.upper()}.")
        url = f"f?p=&APP_ID.:{tp}:&APP_SESSION.::&DEBUG.:RP:{','.join(names)}:{','.join(vals)}"
        out += call("wwv_flow_imp_page.create_page_button", id=Id(nid(pg, "btn", "LINK", k)), button_sequence=60 + k,
                    button_plug_id=Id(region_id), button_name=f"LINK_{k}", button_action="REDIRECT_URL",
                    button_template_options="#DEFAULT#", button_template_id=T_BUTTON,
                    button_image_alt=l.get("label_a") or l.get("label_e") or f, button_position="NEXT", button_alignment="RIGHT",
                    icon_css_classes=l.get("icon") or "fa-external-link", button_redirect_url=url,
                    **(dict(button_condition=f"P{pg}_ROWID", button_condition_type="ITEM_IS_NOT_NULL") if doc and names else {}))
    return out


def action_requests(spec):
    return [f"ACT_{a['name']}" for a in spec.get("actions") or []]


def action_components(fp, spec, doc=True, modal=False):
    """Action regions (legacy buttons such as quotation -> sales order), see legacy/STAGE_C_ACTIONS_ADDENDUM.md: parameters,
    one button, a process calling the reviewed PL/SQL, and a branch that opens the created document.  doc: a document /
    form page with P<page>_ROWID (the action needs a saved record); otherwise a grid page (page-level action)."""
    out = ""
    target_item = f"P{fp}_ACT_TARGET"
    for k, a in enumerate(spec.get("actions") or []):
        name = a["name"].upper()
        req = f"ACT_{name}"
        tfp = FORM_PAGES.get((a.get("target_form") or "").upper())
        rid = nid(fp, "act", name)
        params = a.get("params") or []
        def fix(s, conv=True):
            s = s.replace(":PAGE_", f":P{fp}_")
            for p in params:
                item = f"P{fp}_A{k}_{p['name']}"[:30]
                t = p.get("type", "text")
                val = {"date": f"to_date(:{item}, 'DD/MM/YYYY')", "number": f"to_number(:{item})"}.get(t, f":{item}") if conv else f":{item}"
                s = re.sub(rf":{re.escape(p['name'])}\b", val, s)
            return s
        if modal:
            tfp = None                                   # a modal form stays in its dialog
        cond = f":P{fp}_ROWID is not null" if doc else "1 = 1"
        if tfp:
            cond += f" and app_sec.can_page({tfp}, 'I')"
        if a.get("condition"):
            cond += f" and ({fix(a['condition'])})"
        out += call("wwv_flow_imp_page.create_page_plug", id=Id(rid), plug_name=a.get("label_a") or name,
                    region_template_options="#DEFAULT#:t-Region--scrollBody", plug_template=T_STANDARD, plug_display_sequence=200 + k,
                    plug_display_condition_type="EXPRESSION", plug_display_when_condition=cond, plug_display_when_cond2="PLSQL",
                    attributes=attrs(expand_shortcuts="N", output_as="TEXT", show_line_breaks="Y"))
        if k == 0:
            out += call("wwv_flow_imp_page.create_page_item", id=Id(nid(fp, "act", "target")), name=target_item, item_sequence=1,
                        item_plug_id=Id(rid), display_as="NATIVE_HIDDEN", is_persistent="N", attributes=attrs(value_protected="N"))
            out += call("wwv_flow_imp_page.create_page_item", id=Id(nid(fp, "act", "msg")), name=f"P{fp}_ACT_MSG", item_sequence=2,
                        item_plug_id=Id(rid), display_as="NATIVE_HIDDEN", is_persistent="N", attributes=attrs(value_protected="N"))
        for j, p in enumerate(params):
            item = f"P{fp}_A{k}_{p['name']}"[:30]
            base = dict(id=Id(nid(fp, "act", name, p["name"])), name=item, item_sequence=10 * (j + 1), item_plug_id=Id(rid),
                        prompt=p.get("label_a") or p.get("label_e") or p["name"], is_required=bool(p.get("required")), cSize=20,
                        begin_on_new_line="Y" if j % 3 == 0 else "N", colspan=4, label_alignment="RIGHT", is_persistent="N",
                        field_template=T_LABEL_REQ if p.get("required") else T_LABEL_OPT, item_template_options="#DEFAULT#")
            if p.get("default") is not None:
                base["item_default"] = fix(str(p["default"]), conv=False)
                dt = p.get("default_type") or "STATIC"
                if dt != "STATIC":
                    base["item_default_type"] = dt
                    if dt == "EXPRESSION": base["item_default_language"] = "PLSQL"
            t = p.get("type", "text")
            if t == "file":                              # the call receives the file name in APEX_APPLICATION_TEMP_FILES
                out += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_FILE",
                            attributes=attrs(allow_multiple_files="N", display_as="DROPZONE_INLINE", purge_file_at="REQUEST",
                                             storage_type="APEX_APPLICATION_TEMP_FILES", file_types=p.get("file_types") or None))
            elif p.get("lov_sql"):
                out += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_POPUP_LOV", lov=fix(p["lov_sql"], conv=False),
                            lov_display_null="YES", attributes=attrs(case_sensitive="N", display_as="POPUP", fetch_on_search="Y",
                                                                     initial_fetch="FIRST_ROWSET", manual_entry="N", match_type="CONTAINS", min_chars="0"))
            elif t == "date":
                out += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_DATE_PICKER_APEX", format_mask="DD/MM/YYYY",
                            attributes=attrs(appearance_and_behavior="MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON", days_outside_month="VISIBLE",
                                             display_as="POPUP", max_date="NONE", min_date="NONE", multiple_months="N", show_on="FOCUS",
                                             show_time="N", use_defaults="Y"))
            elif t == "number":
                out += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_NUMBER_FIELD",
                            attributes=attrs(number_alignment="left", virtual_keyboard="decimal"))
            else:
                out += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_TEXT_FIELD",
                            attributes=attrs(disabled="N", submit_when_enter_pressed="N", subtype="TEXT", trim_spaces="BOTH"))
        bid = nid(fp, "act", name, "btn")
        out += call("wwv_flow_imp_page.create_page_button", id=Id(bid), button_sequence=10, button_plug_id=Id(rid), button_name=req,
                    button_action="SUBMIT", button_template_options="#DEFAULT#", button_template_id=T_BUTTON, button_is_hot="Y",
                    button_image_alt=a.get("label_a") or name, button_position="NEXT", button_alignment="RIGHT",
                    button_execute_validations="N", confirm_message=a.get("confirm_a"), confirm_style="warning" if a.get("confirm_a") else None,
                    icon_css_classes=a.get("icon") or "fa-share")
        req_checks = ""
        for p in params:
            if p.get("required"):
                item = f"P{fp}_A{k}_{p['name']}"[:30]
                lbl = (p.get("label_a") or p["name"]).replace("'", "''")
                lbl_e = (p.get("label_e") or p["name"]).replace("'", "''")
                req_checks += (f"if :{item} is null then\n  raise_application_error(-20100, case when app_sec.lang = 'en' "
                               f"then '{lbl_e} is required' else 'يجب إدخال {lbl}' end);\nend if;\n")
        code = f"{req_checks}:{target_item} := {fix(a['call'])};"
        success = a.get("success_a") or "تم التنفيذ بنجاح"
        if a.get("message"):                     # message of the procedure (e.g. the created document numbers), else the fixed text
            code += f"\n:P{fp}_ACT_MSG := nvl({fix(a['message'])}, '{success.replace(chr(39), chr(39) * 2)}');"
            success = f"&P{fp}_ACT_MSG."
        pid = nid(fp, "act", name, "p")
        out += call("wwv_flow_imp_page.create_page_process", id=Id(pid), process_sequence=3, process_point="AFTER_SUBMIT",
                    process_type="NATIVE_PLSQL", process_name=a.get("label_a") or name, process_sql_clob=code, process_clob_language="PLSQL",
                    error_display_location="INLINE_IN_NOTIFICATION", process_when_button_id=Id(bid),
                    process_success_message=success, internal_uid=pid % 10**15)
        if tfp:
            out += call("wwv_flow_imp_page.create_page_branch", id=Id(nid(fp, "br", "act", name)),
                        branch_action=f"f?p=&APP_ID.:{tfp}:&APP_SESSION.::&DEBUG.::P{tfp}_ROWID:&{target_item}.&success_msg=#SUCCESS_MSG#",
                        branch_point="AFTER_PROCESSING", branch_type="REDIRECT_URL", branch_condition_type="EXPRESSION",
                        branch_condition=f":REQUEST = '{req}' and :{target_item} is not null", branch_condition_text="PLSQL",
                        branch_sequence=2 + k)
    if spec.get("actions"):
        stay = (f"f?p=&APP_ID.:{fp}:&APP_SESSION.::&DEBUG.::P{fp}_ROWID:&P{fp}_ROWID.&success_msg=#SUCCESS_MSG#" if doc
                else f"f?p=&APP_ID.:{fp}:&APP_SESSION.::&DEBUG.:::&success_msg=#SUCCESS_MSG#")
        out += call("wwv_flow_imp_page.create_page_branch", id=Id(nid(fp, "br", "act", "stay")),
                    branch_action=stay, branch_point="AFTER_PROCESSING", branch_type="REDIRECT_URL",
                    branch_condition_type="REQUEST_IN_CONDITION", branch_condition=",".join(action_requests(spec)), branch_sequence=9)
    return out


def info_components(fp, spec):
    """rules.info: read-only values the legacy screen displayed (balances, running totals, status texts) in a panel of the
    saved document; each value is one SQL query over the header items, computed when the page is shown."""
    infos = (spec.get("rules") or {}).get("info") or []
    if not infos:
        return ""
    rid = nid(fp, "info", "region")
    out = call("wwv_flow_imp_page.create_page_plug", id=Id(rid), plug_name="معلومات", region_template_options="#DEFAULT#:t-Region--scrollBody",
               plug_template=T_STANDARD, plug_display_sequence=25, plug_display_condition_type="ITEM_IS_NOT_NULL",
               plug_display_when_condition=f"P{fp}_ROWID", attributes=attrs(expand_shortcuts="N", output_as="TEXT", show_line_breaks="Y"))
    for k, inf in enumerate(infos):
        name = f"P{fp}_I_{inf.get('name') or k}"[:30]
        sql = inf["sql"].replace(":PAGE_", f":P{fp}_")
        out += call("wwv_flow_imp_page.create_page_item", id=Id(nid(fp, "info", k)), name=name, item_sequence=10 * (k + 1), item_plug_id=Id(rid),
                    use_cache_before_default="NO", prompt=inf.get("label_a") or inf.get("label_e") or name, source=sql, source_type="QUERY",
                    display_as="NATIVE_DISPLAY_ONLY", begin_on_new_line="Y" if k % 4 == 0 else "N", colspan=3, label_alignment="RIGHT",
                    field_template=T_LABEL_OPT, item_template_options="#DEFAULT#", is_persistent="N",
                    attributes=attrs(based_on="VALUE", format="PLAIN", send_on_page_submit="N", show_line_breaks="Y"))
    return out


def soft_delete_components(pg, spec, cascade_stmts):
    """rules.soft_delete: the legacy screens flagged deleted documents (DELETE_FLAG / user / date) instead of removing them."""
    sd = (spec.get("rules") or {}).get("soft_delete")
    if not sd:
        return ""
    t = spec["master"]["table"]
    sets = ", ".join(f"{k} = {v}" for k, v in (sd.get("set") or {"DELETE_FLAG": "1"}).items())   # SQL expressions, :G_* allowed
    code = "declare\n  l_err varchar2(4000);\n"
    if sd.get("check"):
        code += "  function chk return varchar2 is\n  begin\n" + sd["check"].replace(":PAGE_", f":P{pg}_") + "\n  end;\n"
    code += "begin\n"
    if sd.get("check"):
        code += "  l_err := chk;\n  if l_err is not null then raise_application_error(-20100, l_err); end if;\n"
    if sd.get("lines") == "delete":
        code += "".join("  " + s + "\n" for s in cascade_stmts)
    code += f"  update {t} set {sets} where rowid = :P{pg}_ROWID;\nend;"
    pid = nid(pg, "p", "softdel")
    return call("wwv_flow_imp_page.create_page_process", id=Id(pid), process_sequence=6, process_point="AFTER_SUBMIT",
                process_type="NATIVE_PLSQL", process_name="حذف المستند", process_sql_clob=code, process_clob_language="PLSQL",
                error_display_location="INLINE_IN_NOTIFICATION", process_when="DELETE", process_when_type="REQUEST_EQUALS_CONDITION",
                process_success_message=sd.get("message_a") or "تم حذف المستند", internal_uid=pid % 10**15)


def _warn_block(pg, ws, req_expr, rowid_expr, finish):
    fns, calls = [], []
    for k, w in enumerate(ws):
        body = w["plsql"].replace(":PAGE_ROWID", rowid_expr).replace(":PAGE_", f":P{pg}_")
        fns.append(f"  function w{k} return varchar2 is\n  begin\n{body}\n  end;")
        when = ",".join(x.strip() for x in (w.get("when") or "CREATE,SAVE").split(","))
        calls.append(f"  if instr(',{when},', ',' || {req_expr} || ',') > 0 then\n"
                     f"    l_t := w{k};\n    if l_t is not null then l_all := l_all || l_t || chr(10); end if;\n  end if;")
    return "declare\n  l_all varchar2(32767);\n  l_t varchar2(4000);\n" + "\n".join(fns) + "\nbegin\n" + "\n".join(calls) + "\n" + finish + "\nend;"


def warning_components(pg, spec, items, region_id=None):
    """rules.warnings: legacy 'continue?' confirmations.
    * default: Save / Create first ask the server (AJAX callback WARN_CHECK); the user confirms before the page is submitted.
    * "lines": true (warnings about the document's lines): they run inside the save itself, after the header and every grid
      line (also the unsaved ones) are written; if one fires, the whole save is rolled back, the page keeps what the user typed
      and asks "save anyway?"; confirming saves again without asking (P<page>_WARN_OK)."""
    ws = (spec.get("rules") or {}).get("warnings") or []
    if not ws:
        return ""
    pre = [w for w in ws if not (w.get("lines") and region_id)]
    post = [w for w in ws if w.get("lines") and region_id]
    out = ""
    if pre:
        code = _warn_block(pg, pre, "apex_application.g_x01", "apex_application.g_x02", "  htp.prn(rtrim(l_all, chr(10)));")
        out += call("wwv_flow_imp_page.create_page_process", id=Id(nid(pg, "p", "warn")), process_sequence=1, process_point="ON_DEMAND",
                    process_type="NATIVE_PLSQL", process_name="WARN_CHECK", process_sql_clob=code, process_clob_language="PLSQL",
                    internal_uid=nid(pg, "p", "warn") % 10**15)
    ok_item = f"P{pg}_WARN_OK"
    if post:
        out += call("wwv_flow_imp_page.create_page_item", id=Id(nid(pg, "item", "WARN_OK")), name=ok_item, item_sequence=9999,
                    item_plug_id=Id(region_id), display_as="NATIVE_HIDDEN", is_persistent="N", attributes=attrs(value_protected="N"))
        code = _warn_block(pg, post, ":REQUEST", f":P{pg}_ROWID",
                           "  if l_all is not null then\n"
                           "    raise_application_error(-20998, substr('⚠ ' || rtrim(l_all, chr(10)), 1, 2000));\n  end if;")
        out += call("wwv_flow_imp_page.create_page_process", id=Id(nid(pg, "p", "warnlines")), process_sequence=80, process_point="AFTER_SUBMIT",
                    process_type="NATIVE_PLSQL", process_name="تنبيهات السطور (قبل الحفظ النهائي)", process_sql_clob=code,
                    process_clob_language="PLSQL", error_display_location="INLINE_IN_NOTIFICATION",
                    process_when=f":REQUEST in ('SAVE', 'CREATE') and nvl(:{ok_item}, 'N') <> 'Y'", process_when_type="EXPRESSION",
                    process_when2="PLSQL", internal_uid=nid(pg, "p", "warnlines") % 10**15)
        # a fired line warning comes back as an error: show it as a question instead, and save again when confirmed
        hook = ("(function () {\n"
                "  var orig = apex.message.showErrors;\n"
                "  apex.message.showErrors = function (errs) {\n"
                "    var list = Array.isArray(errs) ? errs : [errs];\n"
                "    var w = list.filter(function (e) { return e && String(e.message || '').indexOf('\\u26a0') >= 0; })[0];\n"
                "    if (!w || !window.mpWarnReq) { return orig.apply(this, arguments); }\n"
                "    var req = window.mpWarnReq; window.mpWarnReq = null;\n"
                "    var t = $('<div>').html(String(w.message)).text().replace('\\u26a0', '').trim();\n"
                "    var en = document.documentElement.lang === 'en';\n"
                "    apex.message.confirm(t + '\\n\\n' + (en ? 'Nothing was saved yet. Save anyway?' : 'لم يتم الحفظ بعد. هل تريد الحفظ رغم ذلك؟'),\n"
                "      function (ok) { if (ok) { apex.item('" + ok_item + "').setValue('Y'); apex.page.submit({request: req, validate: true}); } });\n"
                "  };\n"
                "})();")
        ev = nid(pg, "da", "warnhook")
        out += call("wwv_flow_imp_page.create_page_da_event", id=Id(ev), name="line warnings: ask instead of failing", event_sequence=5,
                    bind_type="bind", execution_type="IMMEDIATE", bind_event_type="ready")
        out += call("wwv_flow_imp_page.create_page_da_action", id=Id(nid(pg, "da", "warnhook", "a")), event_id=Id(ev), event_result="TRUE",
                    action_sequence=10, execute_on_page_init="Y", action="NATIVE_JAVASCRIPT_CODE", attribute_01=hook)
    page_items = ",".join("#" + i for i in items)
    for req in ("SAVE", "CREATE"):
        ev = nid(pg, "da", "warn", req)
        out += call("wwv_flow_imp_page.create_page_da_event", id=Id(ev), name=f"warnings {req}", event_sequence=20,
                    triggering_element_type="BUTTON", triggering_button_id=Id(nid(pg, "btn", req)), bind_type="bind",
                    execution_type="IMMEDIATE", bind_event_type="click")
        go = (f"  var go = function () {{ " + (f"window.mpWarnReq = req; apex.item('{ok_item}').setValue('N'); " if post else "")
              + "apex.page.submit({request: req, validate: true}); };\n")
        if pre:
            js = (f"var req = '{req}';\n" + go +
                  f"apex.server.process('WARN_CHECK', {{x01: req, x02: apex.item('P{pg}_ROWID').getValue(), pageItems: '{page_items}'}},"
                  " {dataType: 'text'}).then(function (t) {\n"
                  "  t = (t || '').trim();\n"
                  "  if (!t) { go(); return; }\n"
                  "  apex.message.confirm(t + '\\n\\n' + (document.documentElement.lang === 'en' ? 'Continue?' : 'هل تريد الاستمرار؟'),"
                  " function (ok) { if (ok) go(); });\n"
                  "});")
        else:
            js = f"var req = '{req}';\n" + go + "go();"
        out += call("wwv_flow_imp_page.create_page_da_action", id=Id(nid(pg, "da", "warn", req, "a")), event_id=Id(ev), event_result="TRUE",
                    action_sequence=10, execute_on_page_init="N", action="NATIVE_JAVASCRIPT_CODE", attribute_01=js)
    return out


def fill_components(fp, spec, grids, items, main_rid=None):
    """fills: buttons that add rows to a grid for the user to complete, like the legacy buttons that filled block records before
    COMMIT.  Each fill: {"label_a", "label_e", "table", "sql"} - sql returns one row per line, columns named like the grid's
    columns (a column COL__D gives the text shown for a list column COL); :PAGE_<COL> are the document's fields.  Optional
    "confirm_a", "icon", and "items": input fields of the fill that are not columns of the document (the legacy screen-only
    fields), [{"name", "label_a", "label_e", "type": "number|text|date", "lov": "select d, r ...", "cascade": ["NAME"]}], shown
    under the document header.  The rows appear as new, unsaved lines; nothing is written until the user saves."""
    out = ""
    by_table = {}
    for t, key, rid in grids:
        by_table.setdefault(t.upper(), (key, rid))
    for k, f in enumerate(spec.get("fills") or []):
        tgt = by_table.get((f.get("table") or "").upper())
        if not tgt:
            print(f"   fill {k} of {spec['form']}: grid {f.get('table')} not on the page")
            continue
        key, rid = tgt
        name = f"FILL{k}"
        own = []
        for j, p in enumerate(f.get("items") or []):
            if not main_rid: break
            iname = f"P{fp}_{p['name'].upper()}"[:30]; own.append(iname)
            base = dict(id=Id(nid(fp, "fillitem", k, p["name"])), name=iname, item_sequence=900 + 10 * k + j, item_plug_id=Id(main_rid),
                        prompt=p.get("label_a") or p.get("label_e") or p["name"], begin_on_new_line="Y" if j == 0 else "N", colspan=4,
                        label_alignment="RIGHT", field_template=T_LABEL_OPT, item_template_options="#DEFAULT#", is_persistent="N",
                        display_when=f"P{fp}_ROWID", display_when_type="ITEM_IS_NOT_NULL")
            if p.get("lov"):
                lv = p["lov"].replace(":PAGE_", f":P{fp}_")
                extra = dict(lov_cascade_parent_items=",".join(f"P{fp}_{x.upper()}" for x in p["cascade"]), ajax_optimize_refresh="Y") \
                    if p.get("cascade") else {}
                out += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_POPUP_LOV", lov=lv, lov_display_null="YES",
                            cSize=30, attributes=attrs(case_sensitive="N", display_as="POPUP", fetch_on_search="Y", initial_fetch="FIRST_ROWSET",
                                                       manual_entry="N", match_type="CONTAINS", min_chars="0"), **extra)
            elif (p.get("type") or "").lower() == "date":
                out += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_DATE_PICKER_APEX", format_mask="DD/MM/YYYY",
                            cSize=30, attributes=attrs(display_as="POPUP", max_date="NONE", min_date="NONE", multiple_months="N",
                                                       show_time="N", use_defaults="Y"))
            else:
                out += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_NUMBER_FIELD"
                            if (p.get("type") or "number").lower() == "number" else "NATIVE_TEXT_FIELD", cSize=30,
                            attributes=attrs(number_alignment="left", virtual_keyboard="decimal")
                            if (p.get("type") or "number").lower() == "number" else attrs(disabled="N", subtype="TEXT", trim_spaces="BOTH"))
        page_items = ",".join("#" + i for i in items + own)
        sql = f["sql"].replace(":PAGE_", f":P{fp}_")
        out += call("wwv_flow_imp_page.create_page_process", id=Id(nid(fp, "p", "fill", k)), process_sequence=10 + k, process_point="ON_DEMAND",
                    process_type="NATIVE_PLSQL", process_name=name,
                    process_sql_clob=f"declare\n  c sys_refcursor;\nbegin\n  open c for\n{sql};\n  apex_json.open_object;\n"
                                     "  apex_json.write('rows', c);\n  apex_json.close_object;\nend;",
                    process_clob_language="PLSQL", internal_uid=nid(fp, "p", "fill", k) % 10**15)
        out += call("wwv_flow_imp_page.create_page_button", id=Id(nid(fp, "btn", "fill", k)), button_sequence=5 + k, button_plug_id=Id(rid),
                    button_name=name, button_action="DEFINED_BY_DA", button_template_options="#DEFAULT#:t-Button--iconLeft",
                    button_template_id=T_BUTTON, button_image_alt=f.get("label_a") or f.get("label_e") or "تعبئة",
                    button_position="EDIT", button_alignment="RIGHT", icon_css_classes=f.get("icon") or "fa-download",
                    security_scheme=Id(AZ_INS))
        ev = nid(fp, "da", "fill", k)
        out += call("wwv_flow_imp_page.create_page_da_event", id=Id(ev), name=f"fill {f.get('table')}", event_sequence=30 + k,
                    triggering_element_type="BUTTON", triggering_button_id=Id(nid(fp, "btn", "fill", k)), bind_type="bind",
                    execution_type="IMMEDIATE", bind_event_type="click")
        confirm = (f.get("confirm_a") or "").replace("'", "\\'")
        js = ("var en = document.documentElement.lang === 'en';\n"
              "var run = function () {\n"
              f"  apex.server.process('{name}', {{pageItems: '{page_items}'}}, {{dataType: 'json'}}).then(function (d) {{\n"
              f"    var g = apex.region('{key}').call('getViews', 'grid'), m = g.model, rows = (d && d.rows) || [], n = 0;\n"
              "    rows.forEach(function (r) {\n"
              "      var id = m.insertNewRecord(), rec = (typeof id === 'object') ? id : m.getRecord(id);\n"
              "      Object.keys(r).forEach(function (c) {\n"
              "        if (/__D$/.test(c) || m.getFieldKey(c) === undefined) { return; }\n"
              "        var v = r[c] === null || r[c] === undefined ? '' : String(r[c]);\n"
              "        m.setValue(rec, c, r[c + '__D'] !== undefined ? {v: v, d: String(r[c + '__D'])} : v);\n"
              "      });\n"
              "      n++;\n"
              "    });\n"
              "    apex.message.showPageSuccess(n ? (en ? n + ' line(s) added: complete them, then save.' : 'تمت إضافة ' + n + ' سطر: راجعها وأكملها ثم اضغط حفظ.')\n"
              "                                 : (en ? 'Nothing to add.' : 'لا توجد سطور للإضافة.'));\n"
              "  });\n"
              "};\n"
              + (f"apex.message.confirm('{confirm}', function (ok) {{ if (ok) run(); }});" if confirm else "run();"))
        out += call("wwv_flow_imp_page.create_page_da_action", id=Id(nid(fp, "da", "fill", k, "a")), event_id=Id(ev), event_result="TRUE",
                    action_sequence=10, execute_on_page_init="N", action="NATIVE_JAVASCRIPT_CODE", attribute_01=js)
    return out


def gen_master_detail(spec, lovs):
    pg, list_body = ir_list(spec, lovs, spec["form_page"], False)
    fp = spec["form_page"]; m = spec["master"]
    readonly = not (m.get("insert", True) or m.get("update", True) or m.get("delete", True))
    body = page_header(fp, f"{spec['form']} - {spec['title_e']} (document)", spec["title_a"], alias_of(spec, f"-DOC-{fp}"))
    rid, src = form_region(fp, spec["title_a"], m, lovs, template=T_STANDARD, cols_per_row=3, readonly=readonly)
    body += src
    body += buttons(fp, rid, list_page=pg, readonly=readonly, ops=ops_of(m), da=bool((spec.get("rules") or {}).get("warnings")))
    pp = fp + 1
    if spec.get("print_rdf"):
        body += print_buttons_on(fp, spec, rid)
    else:
        body += call("wwv_flow_imp_page.create_page_button", id=Id(nid(fp, "btn", "PRINT")), button_sequence=15, button_plug_id=Id(rid),
                     button_name="PRINT", button_action="REDIRECT_PAGE", button_template_options="#DEFAULT#", button_template_id=T_BUTTON,
                     button_image_alt="طباعة", button_position="NEXT", button_alignment="RIGHT", icon_css_classes="fa-print",
                     button_redirect_url=f"f?p=&APP_ID.:{pp}:&APP_SESSION.::&DEBUG.::P{pp}_ROWID:&P{fp}_ROWID.",
                     button_condition=f"P{fp}_ROWID", button_condition_type="ITEM_IS_NOT_NULL")
    body += link_buttons(fp, spec, rid)
    detail_ids = []
    grids = {}                                                # table -> (region id, key, block) of the first grid on it
    fill_targets = {(f.get("table") or "").upper() for f in spec.get("fills") or []}
    for i, d in enumerate(spec["details"]):
        if d.get("parent"):                                   # detail of a detail: a grid under the selected line of its parent grid
            par = grids.get(d["parent"])
            pcols = {c["name"] for c in par[2]["cols"]} if par else set()
            join = [(dc, pc) for dc, pc in d["join"] if pc in pcols]
            if not par or not join:
                continue
            title = d.get("title_a") or d.get("title_e") or "تفاصيل السطر"
            drid, dsrc, editable = ig_region(fp, f"det{i}", title, dict(d, join=join), 30 + 10 * i, lovs, condition_item=f"P{fp}_ROWID",
                                             readonly=readonly, template=T_STANDARD, master=(par[0], par[1], dict(join)), doc_grid=True,
                                             static_id=f"det{i}" if d["table"] in fill_targets else None)
            body += dsrc
            if editable:
                detail_ids.append((drid, dict(d, join=join), i))
            continue
        mcols = {c["name"] for c in m["cols"]}
        join = [(dc, mc) for dc, mc in d["join"] if mc in mcols]
        if not join:
            continue
        where = "\n and ".join(f"{dc} = :P{fp}_{mc}" for dc, mc in join)
        extra_items = []
        if d.get("dwhere"):                                   # rules.blocks.<TABLE>.where: two grids on one table, month filter ...
            dw = d["dwhere"].replace(":PAGE_", f":P{fp}_")
            where += f"\n and ({dw})"
            extra_items = sorted(set(re.findall(rf":(P{fp}_[A-Z0-9_$#]+)", dw, re.I)))
        items = ",".join(list(dict.fromkeys([f"P{fp}_{mc}" for _, mc in join] + extra_items)))
        title = d.get("title_a") or d.get("title_e") or ("التفاصيل" if len(spec["details"]) == 1 else f"التفاصيل {i + 1}")
        drid, dsrc, editable = ig_region(fp, f"det{i}", title, dict(d, join=join), 30 + 10 * i, lovs, where=where, ajax_items=items,
                                         condition_item=f"P{fp}_ROWID", readonly=readonly, template=T_STANDARD, doc_grid=True,
                                         static_id=f"det{i}" if d["table"] in fill_targets else None)
        body += dsrc
        grids.setdefault(d["table"], (drid, f"det{i}", d))
        if editable:
            detail_ids.append((drid, dict(d, join=join), i))
    if not readonly:
        body += fill_components(fp, spec, [(d["table"], f"det{i}", nid(fp, f"det{i}", "region")) for i, d in enumerate(spec["details"])],
                                [f"P{fp}_{c['name']}" for c in m["cols"] if not c.get("computed")], main_rid=rid)
    if not readonly and "d" in ops_of(m):
        # deleting a document removes its lines first (legacy screens deleted the whole document); rules may still reject it
        stmts = []
        for dblk in spec["details"]:
            if not dblk.get("delete", True) or dblk.get("parent"): continue    # sub-grid rows go with their parent line (FK)
            join = [(dc, mc) for dc, mc in dblk["join"] if mc in {c["name"] for c in m["cols"]}]
            if join:
                stmts.append(f"delete from {dblk['table']} where " + " and ".join(f"{dc} = :P{fp}_{mc}" for dc, mc in join) + ";")
        rules = spec.get("rules") or {}
        soft = rules.get("soft_delete")
        if stmts and rules.get("delete_lines") == "refuse":
            # legacy "delete the lines first": a document with lines cannot be deleted (no cascade)
            msg = (rules.get("delete_lines_msg") or "لا يمكن حذف المستند لوجود سطور له").replace("'", "''")
            checks = [s.replace("delete from", "select count(*) into n from", 1) for s in stmts]
            code = "declare\n  n number;\nbegin\n" + "".join(f"  {c}\n  if n > 0 then raise_application_error(-20001, '{msg}'); end if;\n"
                                                           for c in checks) + "end;"
            body += call("wwv_flow_imp_page.create_page_process", id=Id(nid(fp, "p", "cascade")), process_sequence=5, process_point="AFTER_SUBMIT",
                         process_type="NATIVE_PLSQL", process_name="منع حذف مستند له سطور", process_sql_clob=code,
                         process_clob_language="PLSQL", error_display_location="INLINE_IN_NOTIFICATION",
                         process_when="DELETE", process_when_type="REQUEST_EQUALS_CONDITION", internal_uid=nid(fp, "p", "cascade") % 10**15)
            stmts = []
        elif stmts and not soft:
            body += call("wwv_flow_imp_page.create_page_process", id=Id(nid(fp, "p", "cascade")), process_sequence=5, process_point="AFTER_SUBMIT",
                         process_type="NATIVE_PLSQL", process_name="حذف تفاصيل المستند", process_sql_clob="\n".join(stmts),
                         process_clob_language="PLSQL", error_display_location="INLINE_IN_NOTIFICATION",
                         process_when="DELETE", process_when_type="REQUEST_EQUALS_CONDITION", internal_uid=nid(fp, "p", "cascade") % 10**15)
        body += soft_delete_components(fp, spec, stmts)
    acts = action_requests(spec)            # action buttons submit the page: the document itself is not saved by them
    if not readonly:
        skip = acts + (["DELETE"] if (spec.get("rules") or {}).get("soft_delete") else [])
        body += call("wwv_flow_imp_page.create_page_process", id=Id(nid(fp, "p", "dml")), process_sequence=10, process_point="AFTER_SUBMIT",
                     region_id=Id(rid), process_type="NATIVE_FORM_DML", process_name="حفظ المستند", attribute_01="REGION_SOURCE",
                     attribute_05="Y", attribute_06="Y", attribute_08="Y", error_display_location="INLINE_IN_NOTIFICATION",
                     internal_uid=nid(fp, "p", "dml") % 10**15,
                     **(dict(process_when=",".join(skip), process_when_type="REQUEST_NOT_IN_CONDITION") if skip else {}))
        for k, (drid, dblk, i) in enumerate(detail_ids):
            body += ig_dml(fp, i, drid, dblk, 20 + k, f"حفظ التفاصيل {k + 1}",
                           process_when=",".join(["DELETE"] + acts), process_when_type="REQUEST_NOT_IN_CONDITION" if acts else "REQUEST_NOT_EQUAL_CONDITION")
        # after create/save stay on the document (new rows get their ROWID back from the form DML process)
        body += call("wwv_flow_imp_page.create_page_branch", id=Id(nid(fp, "br", "stay")),
                     branch_action=f"f?p=&APP_ID.:{fp}:&APP_SESSION.::&DEBUG.::P{fp}_ROWID:&P{fp}_ROWID.&success_msg=#SUCCESS_MSG#",
                     branch_point="AFTER_PROCESSING", branch_type="REDIRECT_URL", branch_condition_type="REQUEST_IN_CONDITION",
                     branch_condition="CREATE,SAVE", branch_sequence=1)
        body += call("wwv_flow_imp_page.create_page_branch", id=Id(nid(fp, "br", "list")),
                     branch_action=f"f?p=&APP_ID.:{pg}:&APP_SESSION.::&DEBUG.:::&success_msg=#SUCCESS_MSG#",
                     branch_point="AFTER_PROCESSING", branch_type="REDIRECT_URL", branch_sequence=10)
    body += call("wwv_flow_imp_page.create_page_process", id=Id(nid(fp, "p", "init")), process_sequence=10, process_point="BEFORE_HEADER",
                 region_id=Id(rid), process_type="NATIVE_FORM_INIT", process_name="تهيئة المستند", error_display_location="INLINE_IN_NOTIFICATION",
                 internal_uid=nid(fp, "p", "init") % 10**15)
    body += rules_components(fp, spec, rid)
    body += info_components(fp, spec)
    body += action_components(fp, spec)            # also on read-only documents (e.g. posting a voucher shown read-only)
    if not readonly:
        body += warning_components(fp, spec, [f"P{fp}_{c['name']}" for c in m["cols"]], region_id=rid)
    return {pg: list_body, fp: body, **gen_print(spec)}


def gen_link(spec, lovs):
    pg = spec["page"]
    body = page_header(pg, f"{spec['form']} - {spec['title_e']}", spec["title_a"], alias_of(spec))
    body += call("wwv_flow_imp_page.create_page_branch", id=Id(nid(pg, "br", "link")),
                 branch_action=f"f?p=&APP_ID.:{spec['link_page']}:&APP_SESSION.::&DEBUG.:::", branch_point="BEFORE_HEADER",
                 branch_type="REDIRECT_URL", branch_sequence=10)
    return {pg: body}


def gen_proc_page(spec, lovs):
    """Process screen reconstructed in Stage C: parameters + run button calling a DB procedure (+ optional preview report)."""
    pg = spec["page"]; pr = spec["proc"]
    body = page_header(pg, f"{spec['form']} - {spec['title_e']}", spec["title_a"], alias_of(spec))
    rid = nid(pg, "proc", "region")
    desc = pr.get("description_a")
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(rid), plug_name=spec["title_a"],
                 region_template_options="#DEFAULT#:t-Region--scrollBody", plug_template=T_STANDARD, plug_display_sequence=10,
                 plug_source=desc, attributes=attrs(expand_shortcuts="N", output_as="TEXT", show_line_breaks="Y"))
    args = []
    for k, p in enumerate(pr.get("params", [])):
        item = f"P{pg}_{p['name']}"[:30]
        base = dict(id=Id(nid(pg, "pp", p["name"])), name=item, item_sequence=10 * (k + 1), item_plug_id=Id(rid),
                    prompt=p.get("label_a") or p.get("label_e") or p["name"], is_required=bool(p.get("required")), cSize=20,
                    begin_on_new_line="Y" if k % 3 == 0 else "N", colspan=4, label_alignment="RIGHT",
                    field_template=T_LABEL_REQ if p.get("required") else T_LABEL_OPT, item_template_options="#DEFAULT#")
        if p.get("default") is not None:
            base["item_default"] = p["default"]
            if p.get("default_type") and p["default_type"] != "STATIC":
                base["item_default_type"] = p["default_type"]
                if p["default_type"] == "EXPRESSION": base["item_default_language"] = "PLSQL"
        t = p.get("type", "text")
        if t == "multi" and p.get("lov_sql"):             # several values, passed as one colon-separated string
            body += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_CHECKBOX", lov=p["lov_sql"],
                         attributes=attrs(number_of_columns="3"))
        elif p.get("lov_sql"):
            body += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_POPUP_LOV", lov=p["lov_sql"], lov_display_null="YES",
                         attributes=attrs(case_sensitive="N", display_as="POPUP", fetch_on_search="Y", initial_fetch="FIRST_ROWSET",
                                          manual_entry="N", match_type="CONTAINS", min_chars="0"))
        elif t == "date":
            body += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_DATE_PICKER_APEX", format_mask="DD/MM/YYYY",
                         attributes=attrs(appearance_and_behavior="MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON", days_outside_month="VISIBLE",
                                          display_as="POPUP", max_date="NONE", min_date="NONE", multiple_months="N", show_on="FOCUS",
                                          show_time="N", use_defaults="Y"))
        elif t == "number":
            body += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_NUMBER_FIELD",
                         attributes=attrs(number_alignment="left", virtual_keyboard="decimal"))
        elif t == "check":
            body += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_SINGLE_CHECKBOX",
                         attributes=attrs(checked_value="1", unchecked_value="0", use_defaults="N"))
        else:
            body += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_TEXT_FIELD",
                         attributes=attrs(disabled="N", submit_when_enter_pressed="N", subtype="TEXT", trim_spaces="BOTH"))
        conv = {"date": f"to_date(:{item}, 'DD/MM/YYYY')", "number": f"to_number(:{item})", "check": f"to_number(nvl(:{item},'0'))"}.get(t, f":{item}")
        args.append(f"{p['arg']} => {conv}")
    for a, v in (pr.get("fixed_args") or {}).items():
        args.append(f"{a} => {v}")
    body += call("wwv_flow_imp_page.create_page_button", id=Id(nid(pg, "run")), button_sequence=10, button_plug_id=Id(rid), button_name="RUN",
                 button_action="SUBMIT", button_template_options="#DEFAULT#", button_template_id=T_BUTTON, button_is_hot="Y",
                 button_image_alt=pr.get("button_a") or "تنفيذ", button_position="NEXT", button_alignment="RIGHT",
                 confirm_message=pr.get("confirm_a"), confirm_style="danger" if pr.get("confirm_a") else None, icon_css_classes="fa-cogs",
                 security_scheme=Id(AZ_PAGE if pr.get("run_right") == "query" else AZ_INS))   # display screens: the query right
    if pr.get("preview_sql"):
        prv = nid(pg, "preview")
        body += call("wwv_flow_imp_page.create_page_plug", id=Id(prv), plug_name=pr.get("preview_title_a") or "معاينة",
                     region_template_options="#DEFAULT#", plug_template=T_IRR, plug_display_sequence=20, query_type="SQL",
                     plug_source=pr["preview_sql"], plug_source_type="NATIVE_IR",
                     ajax_items_to_submit=",".join(f"P{pg}_{p['name']}"[:30] for p in pr.get("params", [])))
        ws = nid(pg, "pws")
        body += call("wwv_flow_imp_page.create_worksheet", id=Id(ws), name="preview", no_data_found_message="لا توجد بيانات",
                     pagination_type="ROWS_X_TO_Y", pagination_display_pos="BOTTOM_RIGHT", report_list_mode="TABS", lazy_loading=False,
                     show_detail_link="N", show_notify="Y", download_formats="CSV:HTML:XLSX:PDF", enable_mail_download="Y", owner="CLAUDE",
                     internal_uid=ws % 10**15)
        letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        for i, c in enumerate(pr.get("preview_columns", [])):
            body += call("wwv_flow_imp_page.create_worksheet_column", id=Id(nid(pg, "pwc", c["name"])), db_column_name=c["name"], display_order=i + 1,
                         column_identifier=letters[i % 26] + ("" if i < 26 else str(i // 26)), column_label=c.get("label_a") or c["name"],
                         column_type=c.get("type", "STRING"), heading_alignment="LEFT", tz_dependent="N", use_as_row_header="N")
    # print buttons submit the parameters first (the report reads them, @NAME in prints.json); "print_runs": the legacy print button
    # also ran the preparation (work table of the report), so printing runs the procedure too
    kinds = rdf_kinds(spec["print_rdf"]) if spec.get("print_rdf") else []
    when = dict(process_when_button_id=Id(nid(pg, "run")))
    if kinds and pr.get("print_runs"):
        reqs = ", ".join(["'RUN'"] + ["'" + ("PRINT_" + kd["key"])[:30] + "'" for kd in kinds])
        when = dict(process_when=f":REQUEST in ({reqs})", process_when_type="EXPRESSION", process_when2="PLSQL")
    code = f"{pr['procedure']}(\n  " + ",\n  ".join(args) + ");" if args else f"{pr['procedure']};"
    success = pr.get("success_a") or "تم التنفيذ بنجاح"
    if pr.get("message"):                               # message computed after the run (counts, created numbers ...)
        body += call("wwv_flow_imp_page.create_page_item", id=Id(nid(pg, "pp", "RUN_MSG")), name=f"P{pg}_RUN_MSG", item_sequence=999,
                     item_plug_id=Id(rid), display_as="NATIVE_HIDDEN", is_persistent="N", attributes=attrs(value_protected="N"))
        code += f"\n:P{pg}_RUN_MSG := nvl({pr['message']}, '{success.replace(chr(39), chr(39) * 2)}');"
        success = f"&P{pg}_RUN_MSG."
    body += call("wwv_flow_imp_page.create_page_process", id=Id(nid(pg, "p", "run")), process_sequence=10, process_point="AFTER_SUBMIT",
                 process_type="NATIVE_PLSQL", process_name=spec["title_e"][:250] or "Run",
                 process_sql_clob=code, process_clob_language="PLSQL", error_display_location="INLINE_IN_NOTIFICATION",
                 process_success_message=success, internal_uid=nid(pg, "p", "run") % 10**15, **when)
    if kinds:
        pp = print_page(spec)
        for k, kd in enumerate(kinds):
            body += call("wwv_flow_imp_page.create_page_branch", id=Id(nid(pg, "br", "print", kd["key"])),
                         branch_action=f"f?p=&APP_ID.:{pp}:&APP_SESSION.::&DEBUG.::P{pp}_KIND:{kd['key']}",
                         branch_point="AFTER_PROCESSING", branch_type="REDIRECT_URL", branch_sequence=1 + k,
                         branch_condition_type="REQUEST_EQUALS_CONDITION", branch_condition=f"PRINT_{kd['key']}"[:30])
    body += call("wwv_flow_imp_page.create_page_branch", id=Id(nid(pg, "br")), branch_action=f"f?p=&APP_ID.:{pg}:&APP_SESSION.::&DEBUG.:::&success_msg=#SUCCESS_MSG#",
                 branch_point="AFTER_PROCESSING", branch_type="REDIRECT_URL", branch_sequence=10)
    body += link_buttons(pg, spec, rid, doc=False)
    if spec.get("print_rdf"):
        body += print_buttons_on(pg, spec, rid, doc=False, submit=True)
        return {pg: body, **gen_print(spec, doc=False)}
    return {pg: body}


def gen_process(spec, lovs):
    if spec.get("proc"):
        return gen_proc_page(spec, lovs)
    if spec.get("link_page"):
        return gen_link(spec, lovs)
    pg = spec["page"]
    body = page_header(pg, f"{spec['form']} - {spec['title_e']}", spec["title_a"], alias_of(spec))
    notes = "<br>".join(n.replace("<", "&lt;") for n in spec["notes"])
    html = (f'<div class="t-Alert t-Alert--wizard t-Alert--defaultIcons t-Alert--warning"><div class="t-Alert-wrap">'
            f'<div class="t-Alert-content"><h2 class="t-Alert-title">{spec["title_a"]}</h2>'
            f'<div class="t-Alert-body"><p>هذه الشاشة من نوع عمليات/معالجة في النظام القديم ({spec["form"]}) وسيتم ترحيل منطقها يدوياً.</p>'
            f'<p dir="ltr">Legacy process screen {spec["form"]} ({spec["title_e"]}): business logic is being migrated.</p>'
            f'<p dir="ltr" style="font-size:12px;opacity:.7">{notes}</p></div></div></div></div>')
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(nid(pg, "info")), plug_name=spec["title_a"], region_template_options="#DEFAULT#",
                 plug_template=T_BLANK, plug_display_sequence=10, plug_source=html, plug_query_options="DERIVED_REPORT_COLUMNS",
                 attributes=attrs(expand_shortcuts="N", output_as="HTML"))
    return {pg: body}


def gen_report(rs):
    """Parameter region + interactive report over the flattened RDF SQL. rs from gen/out/reports.json."""
    pg = rs["page"]
    name = f"{rs.get('rdf') or rs['prm']} - {rs['title_e'] or ''}"[:250]
    alias = re.sub(r"[^A-Z0-9]+", "-", ("R-" + (rs.get("rdf") or rs["prm"])).upper()).strip("-")[:240] + f"-{pg}"
    body = page_header(pg, name, rs["title_a"] or rs["title_e"], alias)
    if not rs.get("ok"):
        notes = "<br>".join(n.replace("<", "&lt;").replace("&", "&amp;") for n in rs["notes"])
        html = (f'<div class="t-Alert t-Alert--wizard t-Alert--defaultIcons t-Alert--warning"><div class="t-Alert-wrap"><div class="t-Alert-content">'
                f'<h2 class="t-Alert-title">{rs["title_a"] or ""}</h2><div class="t-Alert-body">'
                f'<p>هذا التقرير ({rs.get("rdf") or rs["prm"]}) يحتاج إلى معالجة يدوية قبل تشغيله على النظام الجديد.</p>'
                f'<p dir="ltr" style="font-size:12px;opacity:.75">{notes}</p></div></div></div></div>')
        body += call("wwv_flow_imp_page.create_page_plug", id=Id(nid(pg, "info")), plug_name=rs["title_a"] or rs["prm"],
                     region_template_options="#DEFAULT#", plug_template=T_BLANK, plug_display_sequence=10, plug_source=html,
                     plug_query_options="DERIVED_REPORT_COLUMNS", attributes=attrs(expand_shortcuts="N", output_as="HTML"))
        return {pg: body}
    prid = nid(pg, "params")
    visible_items = [i for i in rs["items"] if not i["role"] and i["known"]]
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(prid), plug_name="معايير التقرير",
                 region_template_options="#DEFAULT#:t-Region--scrollBody", plug_template=T_STANDARD, plug_display_sequence=10,
                 attributes=attrs(expand_shortcuts="N", output_as="TEXT", show_line_breaks="Y"))
    n = 0
    for k, it in enumerate(rs["items"]):
        base = dict(id=Id(nid(pg, "pi", it["item"])), name=it["item"], item_sequence=10 * (k + 1), item_plug_id=Id(prid), use_cache_before_default="YES")
        role = it["role"]
        if role or not it["known"]:
            dflt = {"LANG": dict(item_default="case when :G_LANG = 'en' then 'E' else 'A' end", item_default_type="EXPRESSION", item_default_language="PLSQL"),
                    "COMPANY": dict(item_default="G_COMPANY_CODE", item_default_type="ITEM"),
                    "GROUP": dict(item_default="G_PASSWORD_NUMBER", item_default_type="ITEM"),
                    "USER": dict(item_default="G_USER_CODE", item_default_type="ITEM")}.get(role, {})
            if not role and it.get("initial") is not None:
                dflt = dict(item_default=it["initial"])
            body += call("wwv_flow_imp_page.create_page_item", **base, display_as="NATIVE_HIDDEN", **dflt, attributes=attrs(value_protected="N"))
            continue
        label = it["label_a"] or it["label_e"]
        kw = dict(prompt=label, cSize=20, begin_on_new_line="Y" if n % 4 == 0 else "N", colspan=3, label_alignment="RIGHT",
                  field_template=T_LABEL_OPT, item_template_options="#DEFAULT#")
        n += 1
        if it.get("initial") is not None and it["datatype"] != "date":
            kw["item_default"] = it["initial"]
        if it["lov"]:
            body += call("wwv_flow_imp_page.create_page_item", **base, **kw, display_as="NATIVE_POPUP_LOV", lov=it["lov"], lov_display_null="YES",
                         attributes=attrs(case_sensitive="N", display_as="POPUP", fetch_on_search="Y", initial_fetch="FIRST_ROWSET",
                                          manual_entry="Y", match_type="CONTAINS", min_chars="0"))
        elif it["datatype"] == "date":
            body += call("wwv_flow_imp_page.create_page_item", **base, **kw, display_as="NATIVE_DATE_PICKER_APEX", format_mask="DD/MM/YYYY",
                         attributes=attrs(appearance_and_behavior="MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON", days_outside_month="VISIBLE",
                                          display_as="POPUP", max_date="NONE", min_date="NONE", multiple_months="N", show_on="FOCUS",
                                          show_time="N", use_defaults="Y"))
        elif it["datatype"] == "number":
            body += call("wwv_flow_imp_page.create_page_item", **base, **kw, display_as="NATIVE_NUMBER_FIELD",
                         attributes=attrs(number_alignment="left", virtual_keyboard="decimal"))
        else:
            body += call("wwv_flow_imp_page.create_page_item", **base, **kw, display_as="NATIVE_TEXT_FIELD",
                         attributes=attrs(disabled="N", submit_when_enter_pressed="N", subtype="TEXT", trim_spaces="BOTH"))
    body += call("wwv_flow_imp_page.create_page_button", id=Id(nid(pg, "run")), button_sequence=10, button_plug_id=Id(prid), button_name="RUN",
                 button_action="DEFINED_BY_DA", button_template_options="#DEFAULT#", button_template_id=T_BUTTON, button_is_hot="Y",
                 button_image_alt="عرض التقرير", button_position="NEXT", button_alignment="RIGHT", icon_css_classes="fa-play")
    if rs.get("rdf_id"):
        body += report_rdf_print(pg, rs, prid)
    rid = nid(pg, "ir")
    items_csv = ",".join(i["item"] for i in rs["items"])
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(rid), plug_name=rs["title_a"] or rs["prm"],
                 region_template_options="#DEFAULT#", plug_template=T_IRR, plug_display_sequence=20, query_type="SQL",
                 plug_source=rs["sql"], plug_source_type="NATIVE_IR", ajax_items_to_submit=items_csv, prn_page_header=rs["title_a"])
    ws = nid(pg, "ws")
    body += call("wwv_flow_imp_page.create_worksheet", id=Id(ws), name=rs["title_a"] or rs["prm"],
                 max_row_count_message="The maximum row count for this report is #MAX_ROW_COUNT# rows.  Please apply a filter to reduce the number of records in your query.",
                 no_data_found_message="لا توجد بيانات", pagination_type="ROWS_X_TO_Y", pagination_display_pos="BOTTOM_RIGHT",
                 report_list_mode="TABS", lazy_loading=False, show_detail_link="N", show_notify="Y", download_formats="CSV:HTML:XLSX:PDF",
                 enable_mail_download="Y", owner="CLAUDE", internal_uid=ws % 10**15)
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    shown = []
    for i, c in enumerate(rs["columns"]):
        ident = letters[i] if i < 26 else letters[i // 26 - 1] + letters[i % 26]
        typ = c["type"]
        body += call("wwv_flow_imp_page.create_worksheet_column", id=Id(nid(pg, "wc", c["name"])), db_column_name=c["name"], display_order=i + 1,
                     column_identifier=ident, column_label=c["label_a"] or c["label_e"], column_type=typ,
                     heading_alignment="RIGHT" if typ == "NUMBER" else "LEFT", column_alignment="RIGHT" if typ == "NUMBER" else None,
                     format_mask="DD/MM/YYYY" if typ == "DATE" else None, tz_dependent="N", use_as_row_header="N")
        if len(shown) < 16: shown.append(c["name"])
    body += call("wwv_flow_imp_page.create_worksheet_rpt", id=Id(nid(pg, "rpt")), application_user="APXWS_DEFAULT", report_seq=10,
                 report_alias=str(nid(pg, "rpt") % 10**8), status="PUBLIC", is_default="Y", report_columns=":".join(shown))
    ev = nid(pg, "da", "run")
    body += call("wwv_flow_imp_page.create_page_da_event", id=Id(ev), name="Run report", event_sequence=10, triggering_element_type="BUTTON",
                 triggering_button_id=Id(nid(pg, "run")), bind_type="bind", execution_type="IMMEDIATE", bind_event_type="click")
    body += call("wwv_flow_imp_page.create_page_da_action", id=Id(nid(pg, "da", "run", "a")), event_id=Id(ev), event_result="TRUE",
                 action_sequence=10, execute_on_page_init="N", action="NATIVE_REFRESH", affected_elements_type="REGION", affected_region_id=Id(rid))
    return {pg: body}


RDF_PRINT_PAGE = 9990


def report_rdf_print(pg, rs, prid):
    """'Print in the original design' on a report page: the entered parameters go to the legacy RDF, drawn by the report engine
    on the shared page 9990 (which re-checks the right to this report page)."""
    parts = [f"'{it['bind'].upper()}=' || replace(:{it['item']}, chr(30), ' ')" for it in rs["items"]]
    given = {it["bind"].upper() for it in rs["items"]}
    std = {"LANG": "case when app_sec.lang = 'en' then 'E' else 'A' end", "COMP_CODE": "v('G_COMPANY_CODE')", "P_COMPANY": "v('G_COMPANY_CODE')",
           "P_USERS_CODE": "v('G_USER_CODE')", "P_PASSWORD_NUMBER": "v('G_PASSWORD_NUMBER')", "PASSWORD_NUMBER": "v('G_PASSWORD_NUMBER')",
           "P_SYSTEM_NUMBER": f"'{rs.get('system') or ''}'"}
    parts += [f"'{k}=' || {v}" for k, v in std.items() if k not in given]
    out = call("wwv_flow_imp_page.create_page_item", id=Id(nid(pg, "rdfp")), name=f"P{pg}_RDFP", item_sequence=999, item_plug_id=Id(prid),
               display_as="NATIVE_HIDDEN", attributes=attrs(value_protected="Y"))
    bid = nid(pg, "rdfprint")
    out += call("wwv_flow_imp_page.create_page_button", id=Id(bid), button_sequence=20, button_plug_id=Id(prid), button_name="RDF_PRINT",
                button_action="SUBMIT", button_template_options="#DEFAULT#", button_template_id=T_BUTTON, button_image_alt="طباعة بالتصميم الأصلي",
                button_position="NEXT", button_alignment="RIGHT", icon_css_classes="fa-print", button_execute_validations="N")
    pid = nid(pg, "p", "rdfp")
    out += call("wwv_flow_imp_page.create_page_process", id=Id(pid), process_sequence=10, process_point="AFTER_SUBMIT",
                process_type="NATIVE_PLSQL", process_name="معايير الطباعة", process_sql_clob=f":P{pg}_RDFP := " + " || chr(30) ||\n  ".join(parts) + ";",
                process_clob_language="PLSQL", error_display_location="INLINE_IN_NOTIFICATION", process_when_button_id=Id(bid),
                internal_uid=pid % 10**15)
    out += call("wwv_flow_imp_page.create_page_branch", id=Id(nid(pg, "br", "rdfp")),
                branch_action=f"f?p=&APP_ID.:{RDF_PRINT_PAGE}:&APP_SESSION.::&DEBUG.::P{RDF_PRINT_PAGE}_SRC:{pg}",
                branch_point="AFTER_PROCESSING", branch_type="REDIRECT_URL", branch_when_button_id=Id(bid), branch_sequence=10)
    return out


def gen_report_print_page(reports):
    """Page 9990: a report printed in its legacy design.  The report is chosen from the calling report page (never from the URL),
    the right to that page is checked, and the parameters are the ones entered there."""
    pp = RDF_PRINT_PAGE
    body = call("wwv_flow_imp_page.create_page", id=pp, name="Report print (legacy design)", alias="REPORT-PRINT", step_title="طباعة التقرير",
                autocomplete_on_off="OFF", page_template_options="#DEFAULT#", protection_level="C", inline_css=PRINT_CSS)
    mapping = "\n".join(f"    when {rs['page']} then '{rs['rdf_id']}'" for rs in reports if rs.get("rdf_id"))
    code = (f"declare\n  l_src number := to_number(:P{pp}_SRC);\nbegin\n  :P{pp}_RDF := null; :P{pp}_PARAMS := null;\n"
            f"  if l_src is null or not app_sec.can_page(l_src) then\n    :P{pp}_DENY := 'Y'; return;\n  end if;\n"
            f"  :P{pp}_RDF := case l_src\n{mapping}\n    else null end;\n"
            f"  :P{pp}_PARAMS := apex_util.get_session_state('P' || l_src || '_RDFP');\nend;")
    reg = nid(pp, "print")
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(reg), plug_name="طباعة التقرير", region_template_options="#DEFAULT#",
                 plug_template=T_BLANK, plug_display_sequence=10, plug_source=f"app_rdf.render(:P{pp}_RDF, :P{pp}_PARAMS);",
                 plug_source_type="NATIVE_PLSQL", plug_query_options="DERIVED_REPORT_COLUMNS",
                 plug_display_condition_type="EXPRESSION", plug_display_when_condition=f":P{pp}_RDF is not null", plug_display_when_cond2="PLSQL")
    for k, (name, prot, lvl) in enumerate((("SRC", "Y", "S"), ("RDF", "Y", None), ("PARAMS", "Y", None), ("DENY", "N", None))):
        body += call("wwv_flow_imp_page.create_page_item", id=Id(nid(pp, name.lower())), name=f"P{pp}_{name}", item_sequence=10 + k,
                     item_plug_id=Id(reg), display_as="NATIVE_HIDDEN", is_persistent="N", protection_level=lvl, attributes=attrs(value_protected=prot))
    msg = ('<div class="t-Alert t-Alert--danger t-Alert--horizontal t-Alert--defaultIcons"><div class="t-Alert-wrap"><div class="t-Alert-content">'
           '<div class="t-Alert-body">ليس لك صلاحية الطباعة</div></div></div></div>')
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(nid(pp, "deny")), plug_name="deny", region_template_options="#DEFAULT#",
                 plug_template=T_BLANK, plug_display_sequence=5, plug_source=msg, plug_query_options="DERIVED_REPORT_COLUMNS",
                 plug_display_condition_type="VAL_OF_ITEM_IN_COND_EQ_COND2", plug_display_when_condition=f"P{pp}_DENY", plug_display_when_cond2="Y",
                 attributes=attrs(expand_shortcuts="N", output_as="HTML"))
    pid = nid(pp, "p", "params")
    body += call("wwv_flow_imp_page.create_page_process", id=Id(pid), process_sequence=10, process_point="BEFORE_HEADER",
                 process_type="NATIVE_PLSQL", process_name="معايير الطباعة", process_sql_clob=code, process_clob_language="PLSQL",
                 error_display_location="INLINE_IN_NOTIFICATION", internal_uid=pid % 10**15)
    return {pp: gen_print_buttons(pp, body)}


GEN = {"GRID": gen_grid, "REPORT_FORM": gen_report_form, "MASTER_DETAIL": gen_master_detail, "PROCESS": gen_process, "LINK": gen_process}

