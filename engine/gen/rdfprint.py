"""Exact document prints from the legacy Oracle Reports (.rdf converted to XML by rwconverter).

For one report this compiles:
  * a PL/SQL package RPT_<ID> holding the report's own PL/SQL (formula columns, format triggers, report triggers, program
    units; Reports bind references :NAME become package variables) plus a small typed API used by the runtime APP_RDF;
  * a data model (queries, break groups, links, summaries, formula order, and per repeating-frame scope the fields, masks and
    format triggers) for APP_RDF, which runs the queries and returns the document data as JSON;
  * a layout (every frame, repeating frame, field, text, line and box with its position in inches, font, colours, borders,
    elasticity and print-on-page settings) for the browser renderer app/static/rdfprint.js.
The result is stored in table APP_RDF_REPORT by build.py (see load()).

Usage: python rdfprint.py <RDF name or path> [...]   -> compiles, writes app/build/rdf/<ID>.* and loads them into SMART."""
import os, re, io, sys, json, hashlib, collections
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
APPDIR = os.path.dirname(HERE)                       # the engine folder (tools/, static/)
sys.path.insert(0, APPDIR); import mp
ROOT = mp.SOURCES                                    # the client's converted legacy files
OUT = mp.work("build", "rdf")
MODULES = mp.modules()                               # the client's module folders (AC, AR, ST ... PY, AS ...)

SYSTEM_PARAMS = ["DESTYPE", "DESNAME", "DESFORMAT", "MODE", "ORIENTATION", "BACKGROUND", "COPIES", "CURRENCY", "DECIMAL",
                 "THOUSANDS", "PRINTJOB", "USER", "PASSWORD"]


# ------------------------------------------------------------------ locate / load
def find_rdf(name, module=None):
    """Converted XML of a legacy report.  module: the legacy folder (AC, ST, AR, VN ...) when the same report name exists in
    several folders with different content (e.g. ACJRNL1 of AC reads AC_DAILY_TRN, the ST copy AC_YEARLY_TRN)."""
    if os.path.exists(name):
        return name
    base = re.sub(r"(?i)(_RDF)?(\.xml|\.rdf)?$", "", os.path.basename(name))
    for m in ([module.upper()] if module else []):
        for cand in (os.path.join(ROOT, m, "FMB", base + "_RDF.xml"), os.path.join(ROOT, m, base + "_RDF.xml")):
            if os.path.exists(cand):
                return cand
        d = os.path.join(ROOT, m, "FMB")
        if os.path.isdir(d):
            for f in os.listdir(d):
                if f.lower() == (base + "_RDF.xml").lower():
                    return os.path.join(d, f)
    for m in MODULES:
        for cand in (os.path.join(ROOT, m, "FMB", base + "_RDF.xml"), os.path.join(ROOT, m, base + "_RDF.xml")):
            if os.path.exists(cand):
                return cand
    for m in MODULES:                                   # case-insensitive fallback
        d = os.path.join(ROOT, m, "FMB")
        if os.path.isdir(d):
            for f in os.listdir(d):
                if f.lower() == (base + "_RDF.xml").lower():
                    return os.path.join(d, f)
    raise FileNotFoundError(name)


CD_OPEN, CD_CLOSE = "", ""      # CDATA boundaries survive parsing (rwconverter indents around every CDATA section)


def load_xml(path):
    raw = open(path, "rb").read()
    txt = raw.decode("cp1256", errors="replace")          # rwconverter wrote WINDOWS-1256 (NLS_LANG AR8MSWIN1256)
    txt = re.sub(r'encoding="[^"]*"', 'encoding="utf-8"', txt, count=1)
    txt = re.sub(r"<!\[CDATA\[(.*?)\]\]>", lambda m: "<![CDATA[" + CD_OPEN + m.group(1) + CD_CLOSE + "]]>", txt, flags=re.S)
    return ET.fromstring(txt.encode("utf-8"))


def cdata(el):
    """Exact CDATA content of an element (without the indentation rwconverter puts around it)."""
    if el is None:
        return ""
    t = el.text or ""
    a, b = t.find(CD_OPEN), t.rfind(CD_CLOSE)
    if a >= 0 and b > a:
        return t[a + 1:b].replace("\r", "")
    return t.strip().replace(CD_OPEN, "").replace(CD_CLOSE, "")


_DUP = None


def _duplicates():
    """Report names that exist in more than one module folder."""
    global _DUP
    if _DUP is None:
        seen = {}
        for m in MODULES:
            for d in (os.path.join(ROOT, m, "FMB"), os.path.join(ROOT, m)):
                if os.path.isdir(d):
                    for f in os.listdir(d):
                        if f.lower().endswith("_rdf.xml"):
                            seen.setdefault(f[:-8].upper(), set()).add(m)
        _DUP = {k for k, v in seen.items() if len(v) > 1}
    return _DUP


def report_id(path):
    base = re.sub(r"(?i)_RDF\.xml$", "", os.path.basename(path)).upper()
    ident = re.sub(r"[^A-Z0-9_]", "_", base)
    if base in _duplicates():                       # same name in several module folders: one package per folder
        parts = os.path.normpath(path).split(os.sep)
        mod = next((p.upper() for p in reversed(parts[:-1]) if p.upper() in MODULES), None)
        if mod:
            ident = f"{ident}_{mod}"
    return ident[:100]


# ------------------------------------------------------------------ PL/SQL lexer helpers
TOKEN_RE = re.compile(r"""
    (?P<q>[qQ]'(?P<qd>.)(?:.|\n)*?(?P=qd)')        # q-quoted literal (approximate: same close char)
  | (?P<s>'(?:[^']|'')*')                           # string literal
  | (?P<c1>--[^\n]*)                                # line comment
  | (?P<c2>/\*(?:.|\n)*?\*/)                        # block comment
  | (?P<bind>:\s*(?P<bn>[A-Za-z][A-Za-z0-9_$#]*))   # bind reference
  | (?P<lex>&(?P<ln>[A-Za-z][A-Za-z0-9_$#]*))       # lexical reference
""", re.X)
QCLOSE = {"[": "]", "{": "}", "(": ")", "<": ">"}


def scan(text):
    """Yield (kind, match) for literals, comments, binds and lexicals."""
    pos = 0
    while True:
        m = TOKEN_RE.search(text, pos)
        if not m:
            return
        if m.group("q"):
            # proper q-quote handling: q'[ ... ]'
            d = m.group("qd"); close = QCLOSE.get(d, d)
            end = text.find(close + "'", m.start() + 3)
            end = len(text) if end < 0 else end + 2
            yield "lit", m.start(), end, None
            pos = end
            continue
        kind = "lit" if m.group("s") else "com" if (m.group("c1") or m.group("c2")) else "bind" if m.group("bind") else "lex"
        name = m.group("bn") if kind == "bind" else m.group("ln") if kind == "lex" else None
        if kind == "bind" and m.start() > 0 and text[m.start() - 1] == ":":
            pos = m.end(); continue                       # '::' is not a bind
        if kind == "bind" and text[m.end("bind"):m.end("bind") + 1] == "=" and not m.group("bn"):
            pos = m.end(); continue
        yield kind, m.start(), m.end(), name
        pos = m.end()


def rewrite_binds(text, names, var):
    """Replace :NAME (and ': NAME') with its package variable when NAME is a report column/parameter; returns (text, unknown binds).
    A reference to a column the report does not define (broken in the RDF) becomes NULL."""
    out, last, unknown = [], 0, set()
    for kind, a, b, name in scan(text):
        if kind != "bind":
            continue
        up = name.upper()
        rep = var[up] if up in names else "null"
        if up not in names:
            unknown.add(up)
        pre = " " if a > 0 and (text[a - 1].isalnum() or text[a - 1] in "_$#") else ""       # ELSIF:X -> ELSIF g_X
        post = " " if b < len(text) and (text[b].isalnum() or text[b] in "_$#") else ""
        out.append(text[last:a]); out.append(pre + rep + post); last = b
    out.append(text[last:])
    return "".join(out), unknown


def sql_binds_lexicals(sql):
    binds, lex = [], []
    for kind, a, b, name in scan(sql):
        if kind == "bind" and name.upper() not in binds:
            binds.append(name.upper())
        if kind == "lex" and name.upper() not in lex:
            lex.append(name.upper())
    return binds, lex


def normalize_sql(sql):
    """': NAME' -> ':NAME' outside literals (Reports accepts the space, DBMS_SQL does not)."""
    out, last = [], 0
    for kind, a, b, name in scan(sql):
        if kind == "bind":
            out.append(sql[last:a]); out.append(":" + name); last = b
    out.append(sql[last:])
    s = "".join(out).strip()
    s = re.sub(r";\s*$", "", s)
    return s


# ------------------------------------------------------------------ data model
def dtype_of_item(el):
    dt = (el.get("datatype") or "").lower()
    odt = (el.get("oracleDatatype") or "").lower()
    if dt in ("number",) or odt == "number":
        return "N"
    if dt == "date" or odt in ("date", "timestamp"):
        return "D"
    if dt in ("blob",) or odt in ("binlob", "blob", "raw", "longraw"):
        return "B"
    return "C"


def dtype_attr(v):
    v = (v or "character").lower()
    return {"number": "N", "date": "D", "character": "C", "vchar2": "C", "char": "C"}.get(v, "C")


def wire_matrices(m, root):
    """Matrix reports: the dimension groups of a cross product are nested groups of one query (rows above columns above the
    cells).  Row totals are published by the row group; cell formulas and summaries by the row's instance of the column group
    (the cell); column totals need every row, so the runtime computes the distinct columns in a separate pass (xcol / xsums)
    when the layout prints the column group across."""
    lay = root.find("layout")
    across = {(rf.get("source") or "").upper() for rf in (lay.iter("repeatingFrame") if lay is not None else [])
              if rf.get("printDirection") == "across"}
    where = {g["name"]: (q, i) for q in m["queries"] for i, g in enumerate(q["groups"])}
    for mx in m["matrices"]:
        dims = mx["dims"]
        if not dims or any(d not in where for d in dims) or len({where[d][0]["name"] for d in dims}) != 1:
            continue
        q = where[dims[0]][0]
        order = sorted(dims, key=lambda d: where[d][1])
        inner, outer = order[-1], order[:-1]
        col = q["groups"][where[inner][1]]
        for n in mx["sums"]:
            prod = m["summaries"][n].get("product") or []
            if prod == [inner] and inner in across and outer:
                col.setdefault("xsums", []).append(n)
            elif len(prod) == 1 and prod[0] in outer:
                q["groups"][where[prod[0]][1]]["sums"].append(n)
            else:
                col["sums"].append(n)
        col["formulas"] = col["formulas"] + [f for f in mx["formulas"] if f not in col["formulas"]]
        for f in mx["formulas"] + mx["phs"]:
            m["group_of"][f] = inner
        if inner in across and outer:
            col["key"] = 1
            q["groups"][where[order[0]][1]]["xcol"] = where[inner][1]


def parse_model(root):
    m = {"params": [], "queries": [], "links": [], "report": {"formulas": [], "sums": [], "phs": []}, "names": {}, "summaries": {},
         "formula_fn": {}, "group_of": {}, "group_query": {}, "group_parent": {}}
    names = m["names"]                                       # NAME -> type C/N/D/B
    data = root.find("data")
    for p in data.findall("userParameter"):
        n = p.get("name").upper()
        t = dtype_attr(p.get("datatype"))
        m["params"].append({"n": n, "t": t, "init": p.get("initialValue"), "mask": p.get("inputMask")})
        names[n] = t
    for p in data.findall("systemParameter"):
        n = p.get("name").upper()
        m["params"].append({"n": n, "t": "C", "init": p.get("initialValue"), "sys": 1})
        names[n] = "C"
    for n in SYSTEM_PARAMS:
        names.setdefault(n, "C")

    def col_objs(parent, grp):
        out = {"cols": [], "formulas": [], "sums": [], "phs": []}
        for el in parent:
            tag = el.tag
            if tag == "dataItem":
                n = el.get("name").upper()
                dd = el.find("dataDescriptor")
                pos = int(dd.get("order")) if dd is not None and dd.get("order") else None
                t = dtype_of_item(el)
                out["cols"].append({"n": n, "pos": pos, "t": t, "brk": (el.get("breakOrder") or "ascending")[0].upper(),
                                    "alias": (dd.get("descriptiveExpression") if dd is not None else n)})
                names[n] = t
            elif tag == "formula":
                n = el.get("name").upper()
                t = dtype_attr(el.get("datatype"))
                out["formulas"].append(n); names[n] = t
                m["formula_fn"][n] = (el.get("source") or "").lower()
            elif tag == "summary":
                n = el.get("name").upper()
                out["sums"].append(n)
                m["summaries"][n] = {"src": (el.get("source") or "").upper(), "fn": (el.get("function") or "sum").lower(),
                                     "reset": (el.get("reset") or "report").upper(), "grp": grp}
            elif tag == "placeholder":
                n = el.get("name").upper()
                t = dtype_attr(el.get("datatype"))
                out["phs"].append(n); names[n] = t
            if grp and tag in ("dataItem", "formula", "summary", "placeholder"):
                m["group_of"][el.get("name").upper()] = grp
        return out

    for ds in data.findall("dataSource"):
        q = {"name": ds.get("name").upper(), "sql": "", "groups": []}
        sel = ds.find("select")
        q["sql"] = normalize_sql(cdata(sel))
        q["binds"], q["lex"] = sql_binds_lexicals(q["sql"])
        prev = None
        for g in ds.findall("group"):
            gn = g.get("name").upper()
            co = col_objs(g, gn)
            q["groups"].append(dict(name=gn, **co))
            m["group_query"][gn] = q["name"]
            if prev:
                m["group_parent"][gn] = prev
            prev = gn
        m["queries"].append(q)
    rep = col_objs([el for el in data if el.tag in ("formula", "summary", "placeholder")], None)
    m["report"].update(formulas=rep["formulas"], sums=rep["sums"], phs=rep["phs"])
    for n in rep["formulas"] + rep["sums"] + rep["phs"]:
        m["group_of"][n] = "#REPORT"
    # matrix reports: a cross product of dimension groups with its own summaries (cell / row / column totals)
    m["matrices"] = []
    for cp in data.findall("crossProduct"):
        name = cp.get("name").upper()
        dims = [g.get("name").upper() for d in cp.findall("dimension") for g in d.findall("group")]
        co = col_objs([el for el in cp if el.tag in ("formula", "summary", "placeholder")], name)
        for n in co["sums"]:
            m["summaries"][n]["product"] = [x.strip().upper() for x in
                                             (next((el.get("productOrder") for el in cp.findall("summary") if el.get("name").upper() == n), "") or "").split(",") if x.strip()]
        m["matrices"].append({"name": name, "dims": dims, "formulas": co["formulas"], "sums": co["sums"], "phs": co["phs"]})
    wire_matrices(m, root)
    for lk in data.iter("link"):
        m["links"].append({"pg": (lk.get("parentGroup") or "").upper(), "pc": (lk.get("parentColumn") or "").upper(),
                           "cq": (lk.get("childQuery") or "").upper(), "cc": (lk.get("childColumn") or "").upper(),
                           "op": lk.get("condition") or "eq", "clause": lk.get("sqlClause") or "where"})
    # summary types: numbers, except min/max/first/last of a date or char column
    for n, s in m["summaries"].items():
        st = names.get(s["src"], "N")
        names[n] = st if s["fn"] in ("minimum", "maximum", "first", "last") else "N"
    # parent of every query: explicit link, else a bind reference to a column of another query's group
    for q in m["queries"]:
        pg = None
        lks = [lk for lk in m["links"] if lk["cq"] == q["name"]]
        if lks:
            pg = lks[0]["pg"]
        else:
            owners = [m["group_of"].get(b) for b in q["binds"] if m["group_of"].get(b) not in (None, "#REPORT")
                      and m["group_query"].get(m["group_of"].get(b)) != q["name"]]
            if owners:
                pg = owners[-1]
        q["parent_group"] = pg
        q["links"] = []
        for lk in lks:
            cpos = None
            for g in q["groups"]:
                for c in g["cols"]:
                    if c["n"] == lk["cc"] or (c["alias"] or "").upper() == lk["cc"]:
                        cpos = c["pos"]
            q["links"].append({"pc": lk["pc"], "cpos": cpos, "cc": lk["cc"], "op": lk["op"], "clause": lk["clause"]})
    return m


# ------------------------------------------------------------------ program units
HEAD_RE = re.compile(r"^\s*((?:function|procedure)\s+([\w$#]+).*?)\b(is|as)\b", re.I | re.S)


def program_units(root):
    units = []
    pu = root.find("programUnits")
    if pu is None:
        return units
    for el in pu:
        text = cdata(el.find("textSource"))
        kind = el.get("type") if (el.get("type") or "").startswith("package") else el.tag
        units.append({"kind": kind, "name": (el.get("name") or "").lower(), "text": text.strip()})
    return units


def formula_deps(text, names):
    deps = set()
    for kind, a, b, name in scan(text or ""):
        if kind == "bind" and name.upper() in names:
            deps.add(name.upper())
    return deps


def topo(formulas, deps):
    """Order formulas so that a formula referencing another formula of the same set comes after it (Reports computes by dependency)."""
    out, seen, busy = [], set(), set()
    def visit(f):
        if f in seen or f in busy: return
        busy.add(f)
        for d in sorted(deps.get(f, ())):
            if d in formulas: visit(d)
        busy.discard(f); seen.add(f); out.append(f)
    for f in formulas:
        visit(f)
    return out


PLSQL_TYPE = {"C": "varchar2(32767)", "N": "number", "D": "date", "B": "varchar2(1)"}


DECL_RE = re.compile(r"(\b[A-Za-z]\w*\s+(?:VARCHAR2|VARCHAR|CHAR)\s*\(\s*)(\d+)(\s*(?:BYTE|CHAR)?\s*\)\s*(?:CONSTANT\s+)?(?::=|DEFAULT)\s*)'((?:[^']|'')*)'",
                     re.I)


def widen_declarations(text):
    """The Reports PL/SQL engine accepted an initial value longer than the declared VARCHAR2 size (the ASCON amount-in-words
    helper declares  coma varchar2(2) := ' و '  and was printed daily); Oracle 19c raises ORA-06502.  Widen such declarations."""
    def fix(m):
        lit = m.group(4).replace("''", "'")
        n = int(m.group(2))
        return m.group(1) + (str(len(lit)) if len(lit) > n else m.group(2)) + m.group(3) + "'" + m.group(4) + "'"
    return DECL_RE.sub(fix, text)


def var_names(names):
    """Report names -> package variable names (Reports allows names such as 'LINE_DISC 1')."""
    out, used = {}, set()
    for n in sorted(names):
        v = "g_" + re.sub(r"[^A-Za-z0-9_$#]", "_", n)
        base, k = v, 1
        while v.upper() in used:
            k += 1; v = f"{base}_{k}"
        used.add(v.upper()); out[n] = v
    return out


STATEFUL_RE = re.compile(r":\s*[A-Za-z][\w$#]*\s*:=|\binto\s*:"
                         r"|(?:^|;|\bthen\b|\belse\b|\bbegin\b|\bloop\b)\s*(?!(?:return|if|elsif|while|when|case|and|or|not|exit)\b)"
                         r"[A-Za-z_][\w$#.]*\s*\([^;]*?:[A-Za-z]", re.I | re.M)


def gen_package(rid, model, root, units, stubs=frozenset()):
    pkg = f"RPT_{rid}"[:128]
    names = model["names"]
    V = var_names(names)
    fn_text = {u["name"]: u["text"] for u in units}
    problems = []
    pl_units = []
    other_pkgs = []
    for u in units:
        if u["kind"] in ("packageSpec", "packageBody"):
            if u["name"] != "rpt2xls":                     # RPT2XLS: shared stub in the database (04_app_rdf.sql)
                other_pkgs.append(u)
            continue
        text, unknown = rewrite_binds(u["text"], names, V)
        if unknown:
            problems.append(f"{u['name']}: unknown bind references {sorted(unknown)}")
        text = re.sub(r"^(?:\s*(?:--[^\n]*(?:\n|$)|/\*.*?\*/))+", "", text, flags=re.S)   # comment lines before the header
        hm = HEAD_RE.match(text)
        if not hm:
            problems.append(f"{u['name']}: cannot parse header"); continue
        text = re.sub(r"\bsrw\s*\.", "srw.", text, flags=re.I)
        text = widen_declarations(text)
        text = re.sub(r"\n\s*/\s*$", "", text.rstrip())                      # a SQL*Plus terminator line, not the '/' of '*/'
        name = hm.group(2).lower()
        if name in stubs:                                                    # does not compile (broken in the RDF itself): stub
            head = hm.group(1).strip()
            ret = "return true;" if re.search(r"return\s+boolean", head, re.I) else "return null;" if re.match(r"\s*function", head, re.I) else "null;"
            text = f"{head} is\n  begin\n    {ret}   -- rdfprint: the legacy program unit does not compile\n  end;"
        pl_units.append({"name": name, "head": hm.group(1).strip(), "text": text})
    unit_names = {u["name"] for u in pl_units}

    def resolve(fn):
        """Program unit of a formula / format trigger reference; the RDF truncates long references to 30 characters."""
        if fn in unit_names: return fn
        cands = [u for u in unit_names if u.startswith(fn)] if len(fn) >= 29 else []
        return cands[0] if len(cands) == 1 else fn
    # formula order per group (dependencies inside the group)
    deps = {f: formula_deps(fn_text.get(resolve(model["formula_fn"].get(f, "")), ""), names) for f in model["formula_fn"]}
    closure = {}
    def close(f, seen=()):
        if f in closure: return closure[f]
        out = set(deps.get(f, ()))
        for d in list(out):
            if d in deps and d not in seen:
                out |= close(d, seen + (f,))
        closure[f] = out
        return out
    # Reports evaluates formulas on demand: a formula of an enclosing group that reads a column of this group (e.g. an opening
    # balance taken from the first line) is known when this group's formulas need it.  Such ancestor formulas are evaluated
    # again with each record of this group, in dependency order.
    groups = {g["name"]: g for q in model["queries"] for g in q["groups"]}
    def ancestors(gname):
        out = []
        p = model["group_parent"].get(gname)
        q = next((q for q in model["queries"] if any(g["name"] == gname for g in q["groups"])), None)
        while p:
            out.append(p); p = model["group_parent"].get(p)
        top = q["groups"][0]["name"] if q else None
        if q and q.get("parent_group"):
            out += [q["parent_group"]] + ancestors(q["parent_group"])
        return out
    # A formula that changes state (assigns a placeholder, SELECT .. INTO a placeholder, passes placeholders to a procedure)
    # must run once per record, as in Reports: when the record opens, or - if it needs the record's child summaries / child
    # data - when it closes.  Pure formulas are simply evaluated in every pass.
    stateful = {f for f in model["formula_fn"] if STATEFUL_RE.search(fn_text.get(resolve(model["formula_fn"][f]), "") or "")}
    def names_of(g):
        return set(c["n"] for c in g["cols"]) | set(g["formulas"]) | set(g["sums"]) | set(g["phs"])
    def descendants(q, gi):
        out = [x for x in q["groups"][gi + 1:]]
        for g in [q["groups"][gi]] + out[:]:
            for cq in model["queries"]:
                if cq.get("parent_group") == g["name"]:
                    out += cq["groups"] + [d for i in range(len(cq["groups"])) for d in descendants(cq, i)]
        return out
    for q in model["queries"]:
        for gi, g in enumerate(q["groups"]):
            late_names = set(g["sums"]) | {n for d in descendants(q, gi) for n in names_of(d)}
            own = names_of(g)
            extra = [f for a in ancestors(g["name"]) for f in groups[a]["formulas"] if close(f) & own and f not in stateful]
            g["formulas"] = topo(list(dict.fromkeys(extra + g["formulas"])), deps)
            late = {f for f in g["formulas"] if f in stateful and (close(f) | deps.get(f, set())) & late_names}
            g["f_open"] = [f for f in g["formulas"] if f not in late]
            g["f_close"] = [f for f in g["formulas"] if f not in stateful or f in late]
            g["f_pure"] = [f for f in g["formulas"] if f not in stateful]
    model["report"]["formulas"] = topo(model["report"]["formulas"], deps)

    L = []
    L.append(f"create or replace package {pkg} authid definer as")
    L.append(f"  -- generated by app/gen/rdfprint.py from {report_id_src(root)}; do not edit (rebuild instead)")
    L.append("  procedure set_row (p_names in apex_t_varchar2, p_c in apex_t_varchar2, p_n in apex_t_number, p_d in app_rdf_dates);")
    L.append("  procedure get_row (p_names in apex_t_varchar2, o_c out apex_t_varchar2, o_n out apex_t_number, o_d out app_rdf_dates);")
    L.append("  procedure calc (p_names in apex_t_varchar2, o_err out varchar2);")
    L.append("  function  trigs (p_fns in apex_t_varchar2) return apex_t_varchar2;")
    L.append("  function  report_trigger (p_fn in varchar2) return varchar2;")
    L.append(f"end {pkg};")
    L.append("/")
    L.append(f"create or replace package body {pkg} as")
    for n in sorted(names):
        L.append(f"  {V[n]} {PLSQL_TYPE[names[n]]};")
    L.append("")
    for u in pl_units:
        L.append(f"  {u['head']};")
    L.append("")
    body_start = next(i for i, l in enumerate(L) if l.startswith("create or replace package body"))
    unit_lines = []
    for u in pl_units:
        first = sum(l.count("\n") + 1 for l in L[body_start:]) + 1          # line number inside the package body source
        L.append("  " + u["text"].replace("\n", "\n  "))
        unit_lines.append((u["name"], first, first + u["text"].count("\n")))
        L.append("")
    model["_unit_lines"] = unit_lines
    # set_row / get_row
    L.append("  procedure set_row (p_names in apex_t_varchar2, p_c in apex_t_varchar2, p_n in apex_t_number, p_d in app_rdf_dates) is")
    L.append("  begin")
    L.append("    for i in 1 .. p_names.count loop")
    L.append("      case p_names(i)")
    for n in sorted(names):
        t = names[n]
        if t == "B": continue
        src = {"C": "p_c(i)", "N": "p_n(i)", "D": "p_d(i)"}[t]
        L.append(f"        when '{n}' then {V[n]} := {src};")
    L.append("        when '#' then null;")
    L.append("        else null;")
    L.append("      end case;")
    L.append("    end loop;")
    L.append("  end set_row;")
    L.append("")
    L.append("  procedure get_row (p_names in apex_t_varchar2, o_c out apex_t_varchar2, o_n out apex_t_number, o_d out app_rdf_dates) is")
    L.append("  begin")
    L.append("    o_c := apex_t_varchar2(); o_n := apex_t_number(); o_d := app_rdf_dates();")
    L.append("    o_c.extend(p_names.count); o_n.extend(p_names.count); o_d.extend(p_names.count);")
    L.append("    for i in 1 .. p_names.count loop")
    L.append("      case p_names(i)")
    for n in sorted(names):
        t = names[n]
        if t == "B": continue
        dst = {"C": "o_c(i)", "N": "o_n(i)", "D": "o_d(i)"}[t]
        L.append(f"        when '{n}' then {dst} := {V[n]};")
    L.append("        when '#' then null;")
    L.append("        else null;")
    L.append("      end case;")
    L.append("    end loop;")
    L.append("  end get_row;")
    L.append("")
    # calc
    L.append("  procedure calc (p_names in apex_t_varchar2, o_err out varchar2) is")
    L.append("  begin")
    L.append("    for i in 1 .. p_names.count loop")
    L.append("      begin")
    L.append("        case p_names(i)")
    n_calc = 0
    for f, fn in sorted(model["formula_fn"].items()):
        fn = resolve(fn)
        if fn in unit_names:
            L.append(f"          when '{f}' then {V[f]} := {fn};"); n_calc += 1
        else:
            problems.append(f"formula {f}: function {fn} not found")
    L.append("          when '#' then null;")
    L.append("          else null;")
    L.append("        end case;")
    L.append("      exception when others then")
    L.append("        o_err := substr(o_err || p_names(i) || ': ' || sqlerrm || chr(10), 1, 4000);")
    L.append("      end;")
    L.append("    end loop;")
    L.append("  end calc;")
    L.append("")
    trig_fns = sorted({o["trig"] for o in iter_layout_objects(root) if o.get("trig")})
    L.append("  function trigs (p_fns in apex_t_varchar2) return apex_t_varchar2 is")
    L.append("    r apex_t_varchar2 := apex_t_varchar2();")
    L.append("    b boolean;")
    L.append("  begin")
    L.append("    r.extend(p_fns.count);")
    L.append("    for i in 1 .. p_fns.count loop")
    L.append("      begin")
    L.append("        srw.reset_attrs;")
    L.append("        b := true;")
    L.append("        case p_fns(i)")
    for fn in trig_fns:
        if resolve(fn) in unit_names:
            L.append(f"          when '{fn.upper()}' then b := {resolve(fn)};")
        else:
            problems.append(f"format trigger {fn} not found")
    L.append("          when '#' then null;")
    L.append("          else null;")
    L.append("        end case;")
    L.append("        r(i) := case when b then 'Y' else 'N' end || srw.attrs;")
    L.append("      exception when others then r(i) := 'Y';")
    L.append("      end;")
    L.append("    end loop;")
    L.append("    return r;")
    L.append("  end trigs;")
    L.append("")
    L.append("  function report_trigger (p_fn in varchar2) return varchar2 is")
    L.append("    b boolean := true;")
    L.append("  begin")
    L.append("    case lower(p_fn)")
    for key in ("beforeReportTrigger", "afterReportTrigger", "betweenPagesTrigger", "beforeParameterFormTrigger", "afterParameterFormTrigger"):
        fn = (root.get(key) or "").lower()
        if fn and fn in unit_names:
            L.append(f"      when '{fn}' then b := {fn};")
    L.append("      when '#' then null;")
    L.append("      else null;")
    L.append("    end case;")
    L.append("    return case when b then 'Y' else 'N' end;")
    L.append("  end report_trigger;")
    L.append(f"end {pkg};")
    L.append("/")
    src = "\n".join(L) + "\n"
    if other_pkgs:
        problems.append("report-local packages not supported: " + ", ".join(u["name"] for u in other_pkgs))
    return pkg, src, problems


def report_id_src(root):
    return root.get("name") or "report"


# ------------------------------------------------------------------ layout
_UNIT = 1.0


def num(v, default=0.0):
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def geo(el):
    g = el.find("geometryInfo")
    if g is None:
        return None
    return {"x": round(num(g.get("x")) * _UNIT, 5), "y": round(num(g.get("y")) * _UNIT, 5),
            "w": round(num(g.get("width")) * _UNIT, 5), "h": round(num(g.get("height")) * _UNIT, 5)}


def font_of(el):
    f = el.find("font")
    if f is None:
        return None
    out = {"f": f.get("face") or "Arial", "s": num(f.get("size"), 10)}
    if f.get("bold") == "yes": out["b"] = 1
    if f.get("italic") == "yes": out["i"] = 1
    if f.get("underline") == "yes": out["u"] = 1
    if f.get("textColor"): out["c"] = f.get("textColor")
    return out


KIND = {"frame": "fr", "repeatingFrame": "rf", "field": "fd", "text": "tx", "line": "ln", "rectangle": "rc",
        "roundedRectangle": "rr", "ellipse": "el", "image": "im", "arc": "ar", "polyline": "pl", "polygon": "pg", "matrix": "mx"}


def layout_object(el, scope, scopes, model):
    k = KIND.get(el.tag)
    if not k:
        return None
    o = {"k": k, "n": el.get("name")}
    g = geo(el)
    if g: o.update(g)
    al = el.find("advancedLayout"); gl = el.find("generalLayout"); vs = el.find("visualSettings")
    if al is not None:
        po = al.get("printObjectOnPage")
        if po and po != "firstPage": o["po"] = po
        if al.get("formatTrigger"): o["trig"] = al.get("formatTrigger").lower()
        if al.get("pageBreakBefore") == "yes": o["pb"] = 1
        if al.get("pageBreakAfter") == "yes": o["pa"] = 1
        if al.get("keepWithAnchoringObject") == "yes": o["kw"] = 1
    if gl is not None:
        if gl.get("verticalElasticity"): o["ve"] = gl.get("verticalElasticity")[0]
        if gl.get("horizontalElasticity"): o["he"] = gl.get("horizontalElasticity")[0]
        if gl.get("pageProtect") == "yes": o["pp"] = 1
    if vs is not None:
        fp = vs.get("fillPattern"); fb = vs.get("fillBackgroundColor"); ffc = vs.get("fillForegroundColor")
        if fp != "transparent" and (fb or ffc):
            # the XML leaves defaults out: no pattern is a solid fill, and a solid fill shows the foreground colour (white when
            # not given); the background colour only shows between the strokes of a hatch pattern
            o["fill"] = ffc or "white"
        lp = vs.get("linePattern")
        if lp:
            o["lp"] = lp
        if vs.get("lineForegroundColor"): o["lc"] = vs.get("lineForegroundColor")
        if vs.get("lineWidth"): o["lw"] = num(vs.get("lineWidth"))
        if vs.get("dash"): o["dash"] = vs.get("dash")
    ft = font_of(el)
    if ft: o["font"] = ft
    if k == "mx":                                    # the cell of a matrix: row frame x column frame
        o["hf"] = el.get("horizontalFrame"); o["vf"] = el.get("verticalFrame")
    if k == "rf":
        o["g"] = (el.get("source") or "").upper()
        o["dir"] = el.get("printDirection") or "down"
        if el.get("maxRecordsPerPage"): o["max"] = int(el.get("maxRecordsPerPage"))
        if el.get("verticalSpacing"): o["vsp"] = round(num(el.get("verticalSpacing")) * _UNIT, 5)
        if el.get("horizontalSpacing"): o["hsp"] = round(num(el.get("horizontalSpacing")) * _UNIT, 5)
    if k == "fd":
        src = el.get("source") or ""
        o["src"] = src.upper()
        o["al"] = el.get("alignment") or "start"
        if el.get("visible") == "no": o["hide"] = 1
        if src.upper() in ("PHYSICALPAGENUMBER", "PAGENUMBER", "TOTALPAGES", "LOGICALPAGENUMBER", "TOTALLOGICALPAGES", "TOTALPHYSICALPAGES",
                           "CURRENTDATE", "PANELNUMBER", "TOTALPANELS"):
            o["sys"] = src.upper()
        elif model["names"].get(src.upper()) == "B":
            o["img"] = 1
        mask = el.get("formatMask")
        if mask: o["mask"] = mask
    if k == "tx":
        ts = el.find("textSettings")
        o["al"] = (ts.get("justify") if ts is not None else None) or "start"
        segs = []
        for s in el.findall("textSegment"):
            seg = {"t": cdata(s.find("string"))}          # a segment's own trailing newline is a line break
            f = font_of(s)
            if f: seg["font"] = f
            segs.append(seg)
        if segs:
            segs[-1]["t"] = segs[-1]["t"].rstrip("\n")
        o["segs"] = segs
        refs = sorted({m.group(1).upper() for s in segs for m in re.finditer(r"&<?([A-Za-z][A-Za-z0-9_]*)>?", s["t"])} &
                      (set(model["names"]) | {"FIELD"}))
        if refs: o["refs"] = refs
    if k in ("ln", "pl", "pg"):
        pts = [[round(num(p.get("x")) * _UNIT, 5), round(num(p.get("y")) * _UNIT, 5)] for p in el.iter("point")]
        o["pts"] = pts
        if el.get("stretchWithFrame"): o["stretch"] = el.get("stretchWithFrame")
    # scope registration for the runtime
    sc = scopes.setdefault(scope, {"fields": [], "trigs": [], "texts": [], "images": []})
    if o.get("trig"):
        sc["trigs"].append({"o": o["n"], "fn": o["trig"].upper()})
    if k == "fd" and not o.get("sys") and o.get("src"):
        if o.get("img"):
            sc["images"].append({"o": o["n"], "s": o["src"]})
        else:
            sc["fields"].append({"o": o["n"], "s": o["src"], "m": o.get("mask")})
    if k == "fd" and o.get("sys") == "CURRENTDATE":
        sc["fields"].append({"o": o["n"], "s": "$SYSDATE", "m": o.get("mask")})
    if k == "tx" and o.get("refs"):
        sc["texts"].append({"o": o["n"], "refs": o["refs"]})
    # children
    child_scope = o["g"] if k == "rf" else scope
    ch = []
    for c in el:
        co = layout_object(c, child_scope, scopes, model)
        if co: ch.append(co)
    if ch: o["ch"] = ch
    return o


def iter_layout_objects(root):
    lay = root.find("layout")
    for el in lay.iter():
        if el.tag in KIND:
            al = el.find("advancedLayout")
            yield {"n": el.get("name"), "trig": (al.get("formatTrigger") or "").lower() if al is not None else ""}


def parse_layout(root, model):
    global _UNIT
    u = (root.get("unitOfMeasurement") or "inch").lower()
    _UNIT = {"inch": 1.0, "centimeter": 1 / 2.54, "point": 1 / 72.0}.get(u, 1.0)
    lay = root.find("layout")
    out = {"dir": "rtl" if (lay.get("direction") or "") == "rightToLeft" else "ltr", "unit": u, "sections": {}}
    scopes = {}
    for sec in lay.findall("section"):
        name = sec.get("name")
        body = sec.find("body")
        s = {"orient": sec.get("orientation") or "portrait"}
        if sec.get("width"): s["pw"] = round(num(sec.get("width")) * _UNIT, 5)
        if sec.get("height"): s["ph"] = round(num(sec.get("height")) * _UNIT, 5)
        mg = sec.find("margin")
        if mg is not None:
            s["margin"] = [o for o in (layout_object(c, "#REPORT", scopes, model) for c in mg) if o]
        if body is not None:
            s["body"] = body_geometry(s, body)
            s["objs"] = [o for o in (layout_object(c, "#REPORT", scopes, model) for c in body) if o]
        if out["dir"] == "rtl":
            mirror_section(s)
        out["sections"][name] = s
    return out, scopes


def body_geometry(s, body):
    """Body area of a section.  The XML leaves out values equal to Reports' defaults: a missing location is not 0 - the body
    sits below the page header drawn in the margin, centred across; a missing size is the page less equal margins."""
    pw = s.get("pw") or (11.0 if s["orient"] == "landscape" else 8.5)
    ph = s.get("ph") or (8.5 if s["orient"] == "landscape" else 11.0)
    loc = body.find("location")
    get = lambda el, k: round(num(el.get(k)) * _UNIT, 5) if el is not None and el.get(k) is not None else None
    x, y, w, h = get(loc, "x"), get(loc, "y"), get(body, "width"), get(body, "height")
    if y is None:
        tops = [o["y"] + o.get("h", 0) for o in s.get("margin", []) if o.get("y", 99) < ph / 3]
        y = max(tops + [0.5])
        if h is not None:
            y = min(y, ph - h)
        y = round(max(y, 0.0), 5)
    if h is None:
        h = round(max(ph - 2 * y, 1), 5)
    if w is None:
        w = round(max(pw - 2 * (x or 0.5), 1), 5)
    if x is None:
        x = round(max((pw - w) / 2, 0), 5)
    return {"w": w, "h": h, "x": x, "y": y}


def mirror(objs, width):
    """Right-to-left reports keep their x positions measured from the right edge (the Paper Layout's origin is the upper right
    corner; the Arabic RDFs carry the same x as their English twins).  The renderer works from the left, so flip them."""
    for o in objs:
        if "x" in o:
            o["x"] = round(width - o["x"] - o.get("w", 0), 5)
        if o.get("pts"):
            o["pts"] = [[round(width - p[0], 5), p[1]] for p in o["pts"]]
        mirror(o.get("ch", []), width)


def mirror_section(s):
    pw = s.get("pw") or (11.0 if s["orient"] == "landscape" else 8.5)
    b = s.get("body")
    if b:
        mirror(s.get("objs", []), b["w"])
        b["x"] = round(max(pw - b["x"] - b["w"], 0), 5)
    mirror(s.get("margin", []), pw)


# ------------------------------------------------------------------ compile
def compile_rdf(name, stubs=frozenset()):
    path = find_rdf(name)
    root = load_xml(path)
    rid = report_id(path)
    model = parse_model(root)
    units = program_units(root)
    if root.find("layout") is None:
        raise ValueError(f"{os.path.basename(path)}: the report has no page layout (a data-only / Excel report); it cannot be printed")
    layout, scopes = parse_layout(root, model)
    # fields inside a group frame that show a report-level formula / summary: Reports prints their final value (it formats after
    # fetching everything), so they are computed with the report scope; the renderer looks them up there
    rep_scope = scopes.setdefault("#REPORT", {"fields": [], "trigs": [], "texts": [], "images": []})
    for sc, v in scopes.items():
        if sc == "#REPORT": continue
        keep = []
        for f in v["fields"]:
            (rep_scope["fields"] if model["group_of"].get(f["s"]) == "#REPORT" else keep).append(f)
        v["fields"] = keep
    pkg, src, problems = gen_package(rid, model, root, units, stubs)
    if stubs:
        problems = problems + [f"program units that do not compile, replaced by stubs: {sorted(stubs)}"]
    model_out = {"id": rid, "pkg": pkg, "file": os.path.relpath(path, ROOT), "title": root.get("previewerTitle") or root.get("name"),
                 "params": model["params"], "queries": model["queries"], "summaries": model["summaries"],
                 "report": model["report"], "types": model["names"], "group_of": model["group_of"], "matrices": model.get("matrices") or [],
                 "triggers": {k: (root.get(k) or "").lower() for k in ("beforeParameterFormTrigger", "afterParameterFormTrigger",
                                                                     "beforeReportTrigger", "afterReportTrigger") if root.get(k)},
                 "scopes": scopes}
    return {"id": rid, "pkg": pkg, "path": path, "model": model_out, "layout": layout, "plsql": src, "problems": problems,
            "unit_lines": model.get("_unit_lines") or [], "stubs": set(stubs), "name": name}


def write(res):
    os.makedirs(OUT, exist_ok=True)
    base = os.path.join(OUT, res["id"])
    io.open(base + ".pks.sql", "w", encoding="utf-8", newline="\n").write("set define off\n" + res["plsql"])
    io.open(base + ".model.json", "w", encoding="utf-8").write(json.dumps(res["model"], ensure_ascii=False, indent=1))
    io.open(base + ".layout.json", "w", encoding="utf-8").write(json.dumps(res["layout"], ensure_ascii=False, separators=(",", ":")))
    return base


def load(res, cur=None):
    """Compile the package and store model + layout in APP_RDF_REPORT."""
    sys.path.insert(0, os.path.join(APPDIR, "tools"))
    from db import connect
    own = cur is None
    if own:
        c = connect(); cur = c.cursor()
    cur.execute("alter session set nls_length_semantics = CHAR")     # legacy Arabic was single-byte: varchar2(n) means n characters
    for attempt in range(6):
        errs = []
        for block in re.split(r"\n/\n", res["plsql"]):
            block = block.strip()
            if not block: continue
            try:
                cur.execute(block)
            except Exception as e:
                errs.append(str(e))
        cur.execute("select name, type, line, position, text from user_errors where name = :1 order by name, sequence", [res["pkg"]])
        rows = cur.fetchall()
        for n, typ, line, pos, text in rows:
            errs.append(f"{n} {line}:{pos} {text}")
        # program units of the RDF that do not compile (broken in the legacy file itself): replace them by stubs and retry
        lines = [line for n, typ, line, pos, text in rows if typ == "PACKAGE BODY"]
        bad = {u for u, a, b in res.get("unit_lines") or [] if any(a <= l <= b for l in lines)} - set(res.get("stubs") or ())
        if not bad:
            break
        res.update(compile_rdf(res["path"], stubs=frozenset(set(res.get("stubs") or ()) | bad)))
        write(res)
    import oracledb
    cur.execute("delete from app_rdf_report where name = :1", [res["id"]])
    cur.setinputsizes(model=oracledb.DB_TYPE_CLOB, layout=oracledb.DB_TYPE_CLOB)
    cur.execute("""insert into app_rdf_report (name, pkg, model, layout, source_file, problems, loaded_on)
                   values (:name, :pkg, :model, :layout, :src, :prob, sysdate)""",
                dict(name=res["id"], pkg=res["pkg"], model=json.dumps(res["model"], ensure_ascii=False),
                     layout=json.dumps(res["layout"], ensure_ascii=False), src=res["model"]["file"],
                     prob="\n".join(res["problems"] + errs).encode("utf-8")[:3900].decode("utf-8", "ignore") or None))
    cur.connection.commit()
    return errs


if __name__ == "__main__":
    for a in sys.argv[1:]:
        r = compile_rdf(a)
        b = write(r)
        errs = load(r)
        print(r["id"], "->", r["pkg"], "problems:", r["problems"], "compile errors:", errs[:10])
