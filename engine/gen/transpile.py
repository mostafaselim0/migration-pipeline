"""Transpile Forms triggers into rule sets - deterministic, no language model (stage generate, before specs.py).

For every screen that has Forms XML (a .fmb source was delivered) and no reviewed override, the trigger PL/SQL is
rewritten into the rule format the generator already consumes (knowledge/<product>/contracts/STAGE_C_RULES_ADDENDUM.md):

   WHEN-VALIDATE-ITEM / -RECORD, PRE-INSERT, PRE-UPDATE   -> row_rules[TABLE]: the trigger body runs in the generated
        APPX_<TABLE> row trigger; :BLOCK.ITEM -> :new.COLUMN, MESSAGE(x) + RAISE FORM_TRIGGER_FAILURE ->
        raise_application_error(-20150, x), Forms navigation built-ins removed, :GLOBAL.* -> application items
   WHEN-CREATE-RECORD (:BLOCK.ITEM := constant | sysdate | :GLOBAL.*)     -> defaults[TABLE.COLUMN]
   POST-QUERY (select expr into <display item> from t where <own columns>) -> computed[TABLE.ITEM]
   WHEN-BUTTON-PRESSED calling CALL_FORM / OPEN_FORM / NEW_FORM              -> links
   WHEN-BUTTON-PRESSED calling one stored procedure                          -> actions

Every rewritten body is parsed by the database before it is written (locals stand in for :new / :old); what does not
parse, and every trigger with logic the rewrite cannot express (alerts that branch, other blocks' items, program units,
COMMIT_FORM, EXECUTE_QUERY ...), goes to work/transpiled/<FORM>.residue.json - the short list the optional llm stage or a
reviewer works from.  Output: work/transpiled/<FORM>.json ({"pattern": "AUTO", "rules": {...}, "_transpiled": ...}).
Cosmetic triggers (navigation, keys, window/mouse events) are ignored."""
import os, sys, re, io, json, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tools")); sys.path.insert(0, os.path.dirname(HERE))
import mp
from db import connect

OUTDIR = mp.work("transpiled")
GLOBALS = {"USER_CODE": "v('G_USER_CODE')", "USERS_CODE": "v('G_USER_CODE')", "USER": "v('G_USER_CODE')", "USER_ID": "v('G_USER_CODE')",
           "COMPANY_CODE": "v('G_COMPANY_CODE')", "COMPANY": "v('G_COMPANY_CODE')", "COMP_CODE": "v('G_COMPANY_CODE')",
           "PASSWORD_NUMBER": "v('G_PASSWORD_NUMBER')", "PASSWORD": "v('G_PASSWORD_NUMBER')", "GROUP": "v('G_PASSWORD_NUMBER')",
           "LANG": "v('G_LANG')", "LANGUAGE": "v('G_LANG')"}
GLOBAL_ITEM = {"USER_CODE": "G_USER_CODE", "USERS_CODE": "G_USER_CODE", "USER": "G_USER_CODE", "COMPANY_CODE": "G_COMPANY_CODE",
               "COMPANY": "G_COMPANY_CODE", "COMP_CODE": "G_COMPANY_CODE", "PASSWORD_NUMBER": "G_PASSWORD_NUMBER", "LANG": "G_LANG"}
# statements that only move the cursor or restyle the screen: removed
COSMETIC = r"(go_item|go_block|go_record|go_form|set_item_property|set_item_instance_property|set_block_property|set_record_property|" \
           r"set_window_property|set_view_property|set_canvas_property|set_tab_page_property|set_form_property|set_application_property|" \
           r"set_menu_item_property|set_alert_property|set_lov_property|synchronize|show_view|hide_view|show_window|hide_window|" \
           r"next_item|previous_item|next_block|previous_block|next_record|previous_record|first_record|last_record|up|down|" \
           r"clear_message|bell|redisplay|display_item|pause|clear_item|clear_eol|scroll_up|scroll_down|show_editor|edit_textitem|" \
           r"set_cursor_style|set_timer|create_timer|delete_timer|enter|do_key\s*\(\s*'(next_item|previous_item|next_block|previous_block|" \
           r"enter|next_record|previous_record)'\s*\))"
# logic the rewrite does not express: the trigger goes to the residue
UNSUPPORTED = r"\b(call_form|open_form|new_form|exit_form|commit_form|post|do_key|run_product|run_report_object|host|web\.show_document|" \
              r"execute_query|clear_block|clear_form|enter_query|create_record|delete_record|duplicate_record|duplicate_item|forms_ddl|" \
              r"user_exit|ole2\.|client_|webutil|read_image_file|write_image_file|show_lov|list_values|erase|default_value|" \
              r"get_item_property|get_block_property|get_record_property|get_form_property|get_application_property|get_window_property|" \
              r"get_lov_property|get_view_property|find_item|find_block|find_alert|find_lov|id_null|populate_group|populate_list|" \
              r"create_group|create_group_from_query|add_group_row|delete_group_row|get_group_row_count|get_group_char_cell|" \
              r"get_group_number_cell|set_group_char_cell|set_group_number_cell|copy_region|cut_region|paste_region|print|" \
              r"alert_button1|alert_button2|alert_button3|system\.(cursor_record|cursor_item|cursor_block|current_block|current_item|" \
              r"trigger_record|last_record|block_status|form_status|mouse_[a-z_]+|last_query|current_form)|:parameter\.)\b"
LOGIC_TRIGGERS = {"WHEN-VALIDATE-ITEM", "WHEN-VALIDATE-RECORD", "PRE-INSERT", "PRE-UPDATE"}


def lex(sql):
    """('code'|'lit'|'cmt', text) tokens; string literals and comments untouched."""
    out, i, n, buf = [], 0, len(sql), []
    def flush():
        if buf: out.append(("code", "".join(buf))); buf.clear()
    while i < n:
        ch = sql[i]
        if ch == "-" and sql.startswith("--", i):
            flush(); j = sql.find("\n", i); j = n if j < 0 else j; out.append(("cmt", sql[i:j])); i = j
        elif ch == "/" and sql.startswith("/*", i):
            flush(); j = sql.find("*/", i + 2); j = n if j < 0 else j + 2; out.append(("cmt", sql[i:j])); i = j
        elif ch == "'":
            flush(); j = i + 1
            while j < n:
                if sql[j] == "'" and j + 1 < n and sql[j + 1] == "'": j += 2; continue
                if sql[j] == "'": break
                j += 1
            out.append(("lit", sql[i:j + 1])); i = j + 1
        else:
            buf.append(ch); i += 1
    flush()
    return out


def code_only(text):
    return "".join(t if k == "code" else ("'" + " " * (len(t) - 2) + "'" if k == "lit" and len(t) >= 2 else " " * len(t)) for k, t in lex(text))


def strip_comments(text):
    return "".join(" " if k == "cmt" else t for k, t in lex(text))


def statements(body):
    """Split PL/SQL into top-level statements (by ';' outside parentheses / literals), keeping block structure words as text."""
    out, depth, start = [], 0, 0
    m = code_only(body)
    for i, ch in enumerate(m):
        if ch == "(": depth += 1
        elif ch == ")": depth -= 1
        elif ch == ";" and depth == 0:
            out.append(body[start:i + 1]); start = i + 1
    if body[start:].strip():
        out.append(body[start:])
    return out


class Unsupported(Exception):
    pass


class FormCtx:
    def __init__(self, form, meta):
        self.form = form
        self.meta = meta
        self.blocks = {b["block"].upper(): b for b in form["blocks"]}
        self.items = collections.defaultdict(dict)                 # BLOCK -> ITEM -> item dict
        for it in form["items"]:
            self.items[(it["block"] or "").upper()][(it["item"] or "").upper()] = it
        self.alerts = {(a["name"] or "").upper(): a.get("message") for a in form.get("alerts", [])}
        self.units = {(p["name"] or "").upper() for p in form.get("program_units", [])}
        self.relations = form.get("relations", [])

    def table(self, block):
        b = self.blocks.get(block.upper())
        t = (b or {}).get("base_table") or (b or {}).get("dml_table")
        t = (t or "").upper().split(".")[-1].strip('"')
        return t if t in self.meta else None

    def column(self, block, item):
        it = self.items.get(block.upper(), {}).get(item.upper())
        if not it:
            return None
        if it.get("database_item") is False:
            return None
        t = self.table(block)
        col = (it.get("column_name") or it.get("item") or "").upper()
        return col if t and col in {c["name"] for c in self.meta[t]["cols"]} else None

    def master_of(self, block):
        """(master block, [(detail col, master col)]) from the form's relation, when the join uses real columns."""
        for r in self.relations:
            if (r.get("detail") or "").upper() == block.upper() and r.get("master"):
                pairs = []
                for a, b in re.findall(r"([A-Z0-9_$#]+\.[A-Z0-9_$#]+)\s*=\s*([A-Z0-9_$#:]+\.[A-Z0-9_$#]+)", (r.get("join") or "").upper()):
                    (ab, ac), (bb, bc) = a.split("."), b.lstrip(":").split(".")
                    if ab == block.upper(): pairs.append((ac, bc))
                    elif bb == block.upper(): pairs.append((bc, ac))
                mb = r["master"].upper()
                if pairs and all(self.column(block, d) and self.column(mb, m) for d, m in pairs):
                    return mb, [(self.column(block, d), self.column(mb, m)) for d, m in pairs]
        return None, []


def rewrite_refs(code, ctx, block, mode):
    """:BLOCK.ITEM and NAME_IN('BLOCK.ITEM') -> :new.COL (mode 'row'), :PAGE_COL (mode 'page', master block) or a correlated
    subquery on the master; :GLOBAL.* -> v('G_*'); :SYSTEM.RECORD_STATUS tests -> inserting / updating."""
    code = re.sub(r"(?i)\bname_in\s*\(\s*'(\w+)\.(\w+)'\s*\)", lambda m: f":{m.group(1)}.{m.group(2)}", code)
    code = re.sub(r"(?i):system\.record_status\s*(=|in)\s*\(?\s*'(NEW|INSERT)'(\s*,\s*'(NEW|INSERT)')?\s*\)?", "inserting", code)
    code = re.sub(r"(?i):system\.record_status\s*(=|in)\s*\(?\s*'(CHANGED|QUERY)'(\s*,\s*'(CHANGED|QUERY)')?\s*\)?", "updating", code)
    code = re.sub(r"(?i):system\.mode\s*=\s*'NORMAL'", "1=1", code)
    if re.search(r"(?i):system\.", code):
        raise Unsupported("reads :SYSTEM state")
    if re.search(UNSUPPORTED, code, re.I):
        raise Unsupported("uses " + re.search(UNSUPPORTED, code, re.I).group(1))
    mblock, mjoin = ctx.master_of(block)

    def own(m):                                    # ':ITEM' without a block name: an item of the trigger's own block
        it = m.group(1).upper()
        col = ctx.column(block, it)
        if col:
            return f":new.{col}" if mode == "row" else f":PAGE_{col}"
        raise Unsupported(f"control item {block}.{it}")
    code = re.sub(r"(?<![\w'.:])[:]\s*([A-Za-z]\w*)\b(?!\s*\.)", own, code)

    def ref(m):
        b, it = m.group(1).upper(), m.group(2).upper()
        if b == "GLOBAL":
            if it in GLOBALS: return GLOBALS[it]
            raise Unsupported(f"global {it}")
        if b == "PARAMETER":
            raise Unsupported(f"parameter {it}")
        if b == block.upper():
            col = ctx.column(b, it)
            if col:
                return f":new.{col}" if mode == "row" else f":PAGE_{col}"
            raise Unsupported(f"control item {b}.{it}")
        if mode == "row" and b == mblock:
            col = ctx.column(b, it)
            if col:
                mt = ctx.table(b)
                cond = " and ".join(f"m.{mc} = :new.{dc}" for dc, mc in mjoin)
                return f"(select m.{col} from {mt} m where {cond})"
        raise Unsupported(f"item of another block {b}.{it}")
    code = re.sub(r"(?<![\w'])[:]\s*([A-Za-z]\w*)\.([A-Za-z]\w*)", ref, code)
    left = [m.group(0) for m in re.finditer(r"(?<![\w'])[:]\s*[A-Za-z]\w*(\.\w+)?", code_only(code))
            if not re.match(r"(?i):(new|old)\.\w+$|:PAGE_\w+$", m.group(0))]
    if left:
        raise Unsupported("unresolved reference " + left[0])
    return code


def rewrite_builtins(body, ctx):
    """MESSAGE -> l_msg, RAISE FORM_TRIGGER_FAILURE -> raise_application_error, SHOW_ALERT as a statement -> l_msg,
    cosmetic built-ins removed."""
    out = []
    for st in statements(body):
        s = st.strip()
        if not s:
            continue
        low = s.lower()
        if re.match(r"^(" + COSMETIC + r")\s*(\(|;)", low):
            out.append("null;"); continue
        m = re.match(r"(?is)^message\s*\((.*)\)\s*;$", s)
        if m:
            arg = re.sub(r"(?i),\s*(no_)?acknowledge\s*$", "", m.group(1).strip())
            out.append(f"l_msg := {arg};"); continue
        if re.match(r"(?i)^raise\s+form_trigger_failure\s*;$", s):
            out.append(f"raise_application_error(-20150, nvl(l_msg, '{ctx.form['form']}'));"); continue
        m = re.match(r"(?is)^(\w+\s*:=\s*)?show_alert\s*\(\s*'?(\w+)'?\s*\)\s*;$", s)
        if m:
            msg = ctx.alerts.get(m.group(2).upper())
            if m.group(1) or not msg:
                raise Unsupported("alert that branches the flow")
            out.append("l_msg := '" + msg.replace("'", "''") + "';"); continue
        if re.search(r"(?i)\bshow_alert\b", s):
            raise Unsupported("alert that branches the flow")
        if re.search(r"(?i)\bmessage\s*\(", s) or re.search(r"(?i)\bform_trigger_failure\b", s):
            # message / raise nested inside if / loop: rewrite in place (statement keeps its structure)
            s = re.sub(r"(?is)\bmessage\s*\(([^;]*?)\)\s*;", lambda mm: "l_msg := " + re.sub(r"(?i),\s*(no_)?acknowledge\s*$", "", mm.group(1).strip()) + ";", s)
            s = re.sub(r"(?i)\braise\s+form_trigger_failure\s*;", f"raise_application_error(-20150, nvl(l_msg, '{ctx.form['form']}'));", s)
        s = re.sub(r"(?i)\b(" + COSMETIC + r")\s*\([^;]*\)\s*;", "null;", s)
        out.append(s)
    return "\n".join(out)


def split_block(code):
    """(declarations, body, exception section) of a trigger body (DECLARE ... BEGIN ... [EXCEPTION ...] END; or bare statements)."""
    c = code.strip().rstrip("/").strip()
    m = re.match(r"(?is)^(?:declare\s+(?P<decl>.*?))?\bbegin\b(?P<body>.*)\bend\s*;?\s*$", c)
    if not m:
        return "", c, ""
    decl, body = m.group("decl") or "", m.group("body")
    depth, cut = 0, None
    mc = code_only(body)
    for mm in re.finditer(r"(?i)\b(begin|case|loop|exception|end)\b", mc):
        w = mm.group(1).lower()
        if w in ("begin", "case", "loop"): depth += 1
        elif w == "end": depth -= 1
        elif w == "exception" and depth == 0: cut = mm.start(); break
    if cut is not None:
        return decl, body[:cut], body[cut:]
    return decl, body, ""


def program_unit_calls(code, ctx):
    return sorted({u for u in ctx.units if re.search(r"(?<![\w.])" + re.escape(u) + r"\s*\(", code, re.I) or re.search(r"(?<![\w.])" + re.escape(u) + r"\s*;", code, re.I)})


def to_row_rule(trg, ctx, meta):
    block = (trg.get("block") or "").upper()
    table = ctx.table(block)
    if not table:
        raise Unsupported("block without a base table")
    code = strip_comments(trg["text"] or "")
    pus = program_unit_calls(code, ctx)
    if pus:
        raise Unsupported("calls program unit " + ", ".join(pus[:3]))
    decl, body, exc = split_block(code)
    decl = rewrite_refs(decl, ctx, block, "row")
    body = rewrite_builtins(rewrite_refs(body, ctx, block, "row"), ctx)
    exc = rewrite_builtins(rewrite_refs(exc, ctx, block, "row"), ctx) if exc.strip() else ""
    if exc and not re.match(r"(?is)^\s*exception\b", exc):
        exc = "exception " + exc
    if not re.search(r"(?i)raise_application_error|:new\.\w+\s*:=", body + exc):
        raise Unsupported("no effect left after removing screen-only statements")
    name = trg["name"].upper()
    if name == "PRE-INSERT":
        when = "inserting"
    elif name == "PRE-UPDATE":
        when = "updating"
    elif name == "WHEN-VALIDATE-ITEM" and trg.get("item"):
        col = ctx.column(block, trg["item"])
        if not col:
            raise Unsupported(f"validate item {trg['item']} is not a column")
        when = (f"inserting or (updating and ((:new.{col} is null and :old.{col} is not null) or "
                f"(:new.{col} is not null and :old.{col} is null) or :new.{col} <> :old.{col}))")
    else:
        when = "inserting or updating"
    core = f"  declare\n    l_msg varchar2(4000);\n    {decl.strip()}\n  begin\n{body.strip()}\n  {exc.strip()}\n  end;"
    # the rule belongs to this screen only: a table shared by several screens (ST_TRNS_MAST ...) must not run another
    # screen's checks; the page -> form lookup is added after the compile check (APP_PAGE_MAP exists only after a build)
    guard = f"(select max(form_name) from app_page_map where page_id = to_number(v('APP_PAGE_ID'))) = '{ctx.form['form']}'"
    head = f"-- {ctx.form['form']} {block}.{trg.get('item') or ''} {name} (transpiled)\n"
    return table, (head + f"if ({when}) then\n{core}\nend if;", head + f"if ({when}) and {guard} then\n{core}\nend if;")


def to_defaults(trg, ctx):
    block = (trg.get("block") or "").upper()
    table = ctx.table(block)
    if not table:
        raise Unsupported("block without a base table")
    out, rest = {}, []
    for st in statements(strip_comments(trg["text"] or "")):
        s = st.strip()
        if not s or re.match(r"(?i)^(begin|end|null)\s*;?$", s):
            continue
        m = re.match(r"(?is)^:(\w+)\.(\w+)\s*:=\s*(.+?)\s*;$", s)
        if m and m.group(1).upper() == block:
            col = ctx.column(block, m.group(2))
            val = m.group(3).strip()
            if not col:
                rest.append(s); continue
            typ = next((c["type"] for c in ctx.meta[table]["cols"] if c["name"] == col), "VARCHAR2")
            if re.match(r"^'.*'$|^-?\d+(\.\d+)?$", val):
                out[f"{table}.{col}"] = {"type": "STATIC", "value": val.strip("'")}
            elif re.match(r"(?i)^(sysdate|trunc\s*\(\s*sysdate\s*\))$", val):
                out[f"{table}.{col}"] = {"type": "EXPRESSION", "value": "to_char(sysdate, 'DD/MM/YYYY')" if typ == "DATE" else "sysdate"}
            elif re.match(r"(?i)^:global\.(\w+)$", val) and re.match(r"(?i)^:global\.(\w+)$", val).group(1).upper() in GLOBAL_ITEM:
                out[f"{table}.{col}"] = {"type": "ITEM", "value": GLOBAL_ITEM[re.match(r"(?i)^:global\.(\w+)$", val).group(1).upper()]}
            else:
                rest.append(s)
        else:
            rest.append(s)
    return out, rest


def to_computed(trg, ctx, lab):
    """POST-QUERY: 'select <expr> into :BLOCK.<display item> from <t> where <conds over own columns>' -> computed column."""
    block = (trg.get("block") or "").upper()
    table = ctx.table(block)
    if not table:
        raise Unsupported("block without a base table")
    out, rest = {}, []
    code = strip_comments(trg["text"] or "")
    for st in statements(code):
        s = st.strip()
        if not s or re.match(r"(?i)^(begin|end|null|declare.*)\s*;?$", s, re.S):
            continue
        m = re.match(r"(?is)^select\s+(.+?)\s+into\s+:(\w+)\.(\w+)\s+from\s+(.+?)\s*;$", s)
        if not (m and m.group(2).upper() == block):
            rest.append(s); continue
        expr, item, rest_sql = m.group(1).strip(), m.group(3).upper(), m.group(4)
        if "," in code_only(expr) and "(" not in expr:
            rest.append(s); continue                           # several targets
        it = ctx.items.get(block, {}).get(item)
        if not it or ctx.column(block, item):
            rest.append(s); continue                           # writes a database column: not a display value
        try:
            body = rewrite_refs(f"select {expr} from {rest_sql}", ctx, block, "row")
        except Unsupported:
            rest.append(s); continue
        body = body.replace(":new.", "t.")
        label = it.get("prompt") or it.get("label") or (lab.get("form_items", {}).get(ctx.form["form"], {}).get(f"{block}.{item}") or {}).get("a") or item
        out[f"{table}.{item}"] = {"sql": f"(select * from ({body}) where rownum = 1)", "label_a": label, "type": "VARCHAR2"}
    return out, rest


FORMS_BUILTINS = r"^(clear_record|clear_block|clear_form|clear_item|execute_query|enter_query|do_key|commit_form|exit_form|post|" \
                 r"create_record|delete_record|duplicate_record|next_record|previous_record|first_record|last_record|go_[a-z]+|" \
                 r"show_[a-z_]+|hide_[a-z_]+|set_[a-z_]+|get_[a-z_]+|call_form|open_form|new_form|run_product|run_report_object|host|" \
                 r"message|bell|synchronize|list_values|print|help|edit_textitem|forms_ddl|user_exit|web\.[a-z_]+|null|raise|return|exit|" \
                 r"commit|rollback|copy|erase|default_value|abort_query|lock_record|down|up|redisplay|pause|scroll_[a-z]+|enter|" \
                 r"populate_[a-z_]+|create_group[a-z_]*|delete_group[a-z_]*|add_group_row|display_error|replace_menu|hide_menu|show_menu)$"


def db_callable(cur, name):
    """True when name is a procedure / function / package member of the client's schema (or a public synonym to one)."""
    parts = name.upper().split(".")
    try:
        if len(parts) == 1:
            cur.execute("select count(*) from user_objects where object_name = :1 and object_type in ('PROCEDURE', 'FUNCTION') "
                        "union all select count(*) from all_synonyms s join all_objects o on o.owner = s.table_owner and o.object_name = s.table_name "
                        "where s.synonym_name = :1 and o.object_type in ('PROCEDURE', 'FUNCTION')", [parts[0]])
            return any(r[0] for r in cur.fetchall())
        if len(parts) == 2:
            cur.execute("select count(*) from all_procedures where owner in (user, 'APEX_240200') and object_name = :1 and procedure_name = :2", parts)
            return cur.fetchone()[0] > 0
    except Exception:
        return False
    return False


def to_button(trg, ctx, registry, cur):
    """WHEN-BUTTON-PRESSED: CALL_FORM / OPEN_FORM / NEW_FORM -> link; a single stored-procedure call -> action."""
    block = (trg.get("block") or "").upper()
    code = strip_comments(trg["text"] or "")
    sts = [s.strip() for s in statements(code) if s.strip() and not re.match(r"(?i)^(begin|end|null|declare.*)\s*;?$", s.strip(), re.S)]
    item = ctx.items.get(block, {}).get((trg.get("item") or "").upper()) or {}
    label = item.get("prompt") or item.get("label") or trg.get("item") or "button"
    if ctx.master_of(block)[0]:
        raise Unsupported("button on a detail block")
    real = [s for s in sts if not re.match(r"(?i)^(" + COSMETIC + r")\s*\(", s)]
    if len(real) == 1:
        m = re.match(r"(?is)^(call_form|open_form|new_form)\s*\(\s*'?([\w.]+)'?", real[0])
        if m:
            target = m.group(2).split(".")[-1].upper()
            if target in registry:
                return "link", {"label_a": label, "form": target}
            raise Unsupported(f"opens {target}, not a registered screen")
        m = re.match(r"(?is)^([\w.]+)\s*(\((.*)\))?\s*;$", real[0])
        if m and not re.match(r"(?i)^(if|for|while|loop|case|select|insert|update|delete)\b", real[0]) and m.group(1).upper() not in ctx.units:
            name = m.group(1)
            if re.match(FORMS_BUILTINS, name.lower()):
                raise Unsupported(f"screen built-in {name} (no data effect)")
            if not db_callable(cur, name):
                raise Unsupported(f"{name} is not a procedure of the schema")
            args = rewrite_refs(m.group(3) or "", ctx, block, "page")
            return "action", {"name": (trg.get("item") or "BTN").upper()[:20], "label_a": label, "call": f"{name}({args});" if m.group(2) else f"{name};",
                              "confirm_a": None, "success_a": label}
    raise Unsupported("button logic beyond one call")


def parse_ok(cur, table, rule, meta):
    """Compile check of a row rule as an anonymous block with locals for :new / :old."""
    cols = meta[table]["cols"]
    decl = []
    for c in cols:
        t = c["type"]
        typ = "number" if t in ("NUMBER", "FLOAT") else "date" if t == "DATE" or t.startswith("TIMESTAMP") else "clob" if "LOB" in t else "varchar2(4000)"
        decl.append(f"new_{c['name']} {typ}; old_{c['name']} {typ};")
    body = re.sub(r"(?i):new\.(\w+)", r"new_\1", re.sub(r"(?i):old\.(\w+)", r"old_\1", rule))
    body = re.sub(r"(?i)\binserting\b", "(1=1)", body); body = re.sub(r"(?i)\bupdating\b", "(1=0)", body)
    blk = "declare\n" + "\n".join(decl) + "\nbegin\n" + body + "\nend;"
    try:
        cur.parse(blk)
        return None
    except Exception as e:
        lines = [l.strip() for l in str(e).splitlines() if l.strip()]
        return " ".join(lines[:2])[:220]


def main():
    cat = json.load(io.open(mp.work("cache", "catalog.json"), encoding="utf-8"))
    meta = json.load(io.open(mp.work("cache", "meta.json"), encoding="utf-8"))
    labp = mp.work("cache", "labels.json")
    lab = json.load(io.open(labp, encoding="utf-8")) if os.path.exists(labp) else {}
    cur = connect().cursor()
    cur.execute("select upper(file_name_a) from sys_files where file_name_a is not null union select upper(file_name_e) from sys_files where file_name_e is not null")
    registry = {r[0].strip() for r in cur if r[0]}
    os.makedirs(OUTDIR, exist_ok=True)
    for old in os.listdir(OUTDIR):
        os.remove(os.path.join(OUTDIR, old))
    totals = collections.Counter()
    for form in cat["forms"]:
        name = (form.get("form") or "").upper()
        if not name or name not in registry:
            continue
        if mp.kpath("overrides", f"{name}.json"):
            totals["reviewed override exists"] += 1
            continue
        ctx = FormCtx(form, meta)
        rules = {"row_rules": collections.OrderedDict(), "defaults": {}, "computed": {}}
        links, actions, residue, done = [], [], [], []
        for trg in form["triggers"]:
            tname = (trg.get("name") or "").upper()
            if not trg.get("text") or not trg.get("block"):
                continue                                       # form-level triggers: cosmetic or global (residue only if logic)
            try:
                if tname in LOGIC_TRIGGERS:
                    table, (rule_check, rule) = to_row_rule(trg, ctx, meta)
                    err = parse_ok(cur, table, rule_check, meta)
                    if err:
                        raise Unsupported("does not compile: " + err)
                    rules["row_rules"].setdefault(table, []).append(rule)
                    done.append(f"{tname} {trg['block']}.{trg.get('item') or ''} -> row rule on {table}")
                elif tname == "WHEN-CREATE-RECORD":
                    d, rest = to_defaults(trg, ctx)
                    rules["defaults"].update(d)
                    if d: done.append(f"{tname} {trg['block']} -> defaults {', '.join(d)}")
                    if rest: raise Unsupported("statements beyond simple defaults: " + rest[0][:80])
                elif tname == "POST-QUERY":
                    c, rest = to_computed(trg, ctx, lab)
                    rules["computed"].update(c)
                    if c: done.append(f"{tname} {trg['block']} -> computed {', '.join(c)}")
                    if rest: residue.append({"trigger": tname, "block": trg["block"], "item": trg.get("item"), "reason": "display logic beyond a lookup (not needed on the new screens unless it derives stored values)", "text": trg["text"][:4000], "severity": "low"}); totals["display-only residue"] += 1
                elif tname == "WHEN-BUTTON-PRESSED":
                    kind, obj = to_button(trg, ctx, registry, cur)
                    (links if kind == "link" else actions).append(obj)
                    done.append(f"{tname} {trg['block']}.{trg.get('item')} -> {kind}")
                else:
                    continue                                   # cosmetic / key / ui-event triggers
                totals["transpiled"] += 1
            except Unsupported as e:
                low = str(e).startswith(("no effect left", "screen built-in"))      # screen-only behaviour: nothing to migrate
                residue.append({"trigger": tname, "block": trg.get("block"), "item": trg.get("item"), "reason": str(e),
                                "text": (trg.get("text") or "")[:4000], **({"severity": "low"} if low else {})})
                totals["screen-only residue" if low else "residue"] += 1
        rules["row_rules"] = {t: "\n".join(rs) for t, rs in rules["row_rules"].items()}
        rules = {k: v for k, v in rules.items() if v}
        if rules or links or actions:
            out = {"pattern": "AUTO", "notes": f"transpiled from the form's triggers ({len(done)} rules); residue in {name}.residue.json",
                   "rules": rules, "_transpiled": done}
            if links: out["links"] = links
            if actions: out["actions"] = actions
            json.dump(out, io.open(os.path.join(OUTDIR, f"{name}.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            totals["screens with transpiled rules"] += 1
        if residue:
            json.dump(residue, io.open(os.path.join(OUTDIR, f"{name}.residue.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("transpile:", dict(totals), "->", os.path.relpath(OUTDIR, mp.REPO))


if __name__ == "__main__":
    main()
