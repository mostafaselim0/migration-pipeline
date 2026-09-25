"""Report specs: one APEX page per SYS_REPORTS leaf.
For each registry report: find the RDF XML (by the parameter-form name, else by report names found inside the PRM .fmx),
parse parameters / queries / data links, flatten the linked queries into one SQL statement, map Reports bind variables to page
items, and validate the SQL against SMART (select * from (...) where 1=0).  Output: gen/out/reports.json"""
import os, sys, re, io, json, glob, collections
import xml.etree.ElementTree as ET
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tools"))
from db import connect
import labels as labmod

sys.path.insert(0, os.path.dirname(HERE)); import mp
ROOT = mp.SOURCES
OUT = mp.work("out", "reports.json")
SYS_DIR = {int(k): v for k, v in dict(mp.kjson("product.json").get("system_dirs") or {},
                                      **(mp.CFG.get("system_dirs") or {})).items()}       # system number -> preferred module folder
SYSTEM_PARAMS = {"LANG": "LANG", "P_LANG": "LANG", "LANGUAGE": "LANG",
                 "COMPANY_CODE": "COMPANY", "COMP_CODE": "COMPANY", "P_COMPANY_CODE": "COMPANY", "P_COMPANY": "COMPANY",
                 "PASSWORD_NUMBER": "GROUP", "P_PASSWORD_NUMBER": "GROUP",
                 "USER_CODE": "USER", "USERS_CODE": "USER", "P_USER_CODE": "USER", "P_USER": "USER"}
BUILTIN = {"DESNAME", "DESTYPE", "DESFORMAT", "MODE", "ORIENTATION", "COPIES", "CURRENCY", "THOUSANDS", "DECIMAL", "PRINTJOB",
           "BACKGROUND", "PARAMFORM", "COMPANY_NAME"}


# ------------------------------------------------------------------ RDF index and parsing
def rdf_index():
    idx = collections.defaultdict(list)
    for d in mp.modules():                      # every module folder of this client
        for p in glob.glob(os.path.join(ROOT, d, "**", "*_RDF.xml"), recursive=True):
            key = re.sub(r"_RDF\.xml$", "", os.path.basename(p), flags=re.I).upper()
            idx[key].append(p)
    return idx


def read_xml(path):
    raw = open(path, "rb").read()
    m = re.match(rb"""<\?xml[^>]*encoding\s*=\s*['"]([^'"]+)['"]""", raw)
    enc = (m.group(1).decode() if m else "utf-8").lower()
    if enc in ("windows-1256", "cp1256", "ar8mswin1256"): enc = "cp1256"
    txt = raw.decode(enc, errors="replace")
    txt = re.sub(r"""encoding\s*=\s*['"][^'"]+['"]""", 'encoding="utf-8"', txt, count=1)
    txt = re.sub(r'\sxmlns="[^"]+"', "", txt, count=1)
    return ET.fromstring(txt.encode("utf-8"))


def cdata(el):
    return (el.text or "").strip() if el is not None else ""


def parse_rdf(path):
    root = read_xml(path)
    rep = {"path": os.path.relpath(path, ROOT), "name": root.get("name"), "params": [], "queries": [], "groups": {}, "links": []}
    for p in root.iter("userParameter"):
        lov = None
        ss = p.find(".//selectStatement")
        if ss is not None and cdata(ss):
            lov = {"sql": cdata(ss), "hide_first": (ss.get("hideFirstColumn") or "no") == "yes"}
        rep["params"].append({"name": p.get("name").upper(), "datatype": (p.get("datatype") or "character").lower(),
                              "width": p.get("width"), "mask": p.get("inputMask"), "label": p.get("label"),
                              "initial": p.get("initialValue"), "lov": lov})
    for ds in root.iter("dataSource"):
        sel = ds.find(".//select")
        sql = cdata(sel)
        if not sql: continue
        groups = [g.get("name") for g in ds.findall("group")]
        rep["queries"].append({"name": ds.get("name"), "sql": sql, "groups": groups})
        for g in ds.iter("group"):
            rep["groups"][g.get("name")] = ds.get("name")
    for l in root.iter("link"):
        rep["links"].append({k: l.get(k) for k in ("parentGroup", "parentColumn", "childQuery", "childColumn", "condition", "sqlClause")})
    return rep


# ------------------------------------------------------------------ SQL helpers
def lex(sql):
    """Tokenise into ('code'|'lit'|'cmt', text): string literals (incl. q-quotes), -- and /* */ comments, code."""
    out, i, n, buf = [], 0, len(sql), []
    def flush():
        if buf: out.append(("code", "".join(buf))); buf.clear()
    while i < n:
        ch = sql[i]
        if ch == "-" and sql.startswith("--", i):
            flush(); j = sql.find("\n", i); j = n if j < 0 else j
            out.append(("cmt", sql[i:j])); i = j
        elif ch == "/" and sql.startswith("/*", i):
            flush(); j = sql.find("*/", i + 2); j = n if j < 0 else j + 2
            out.append(("cmt", sql[i:j])); i = j
        elif ch in "qQ" and i + 2 < n and sql[i + 1] == "'" and (i == 0 or not (sql[i - 1].isalnum() or sql[i - 1] == "_")):
            flush(); close = {"[": "]", "(": ")", "{": "}", "<": ">"}.get(sql[i + 2], sql[i + 2])
            j = sql.find(close + "'", i + 3); j = n if j < 0 else j + 2
            out.append(("lit", sql[i:j])); i = j
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


def split_quotes(sql):
    return [(k != "code", t) for k, t in lex(sql) if k != "cmt"] if False else [(k == "lit", t) for k, t in lex(sql)]


def strip_comments(sql):
    """Drop comments and normalise ': NAME' bind syntax (accepted by Oracle) to ':NAME'."""
    return "".join(" " if k == "cmt" else (re.sub(r"(?<![\w:]):\s+([A-Za-z]\w*)", r":\1", t) if k == "code" else t) for k, t in lex(sql))


def present_binds(sql, names):
    return [n for n in names if re.search(r":" + re.escape(n) + r"\b", sql)]


def binds_in(sql):
    names = []
    for lit, t in split_quotes(sql):
        if not lit:
            names += [m.upper() for m in re.findall(r"(?<![\w:]):([A-Za-z]\w*)", t)]
    return list(dict.fromkeys(names))


def rename_binds(sql, mapping, types=None):
    """:BIND -> :ITEM, typed binds wrapped: date -> to_date(:ITEM,'DD/MM/YYYY'), number -> to_number(:ITEM)."""
    types = types or {}
    def rep(m):
        b = m.group(1).upper()
        item = mapping.get(b)
        if not item: return m.group(0)
        t = types.get(b)
        if t == "date": return f"to_date(:{item}, 'DD/MM/YYYY')"
        if t == "number": return f"to_number(:{item})"
        return ":" + item
    parts = []
    for lit, t in split_quotes(sql):
        if not lit:
            t = re.sub(r"(?<![\w:]):([A-Za-z]\w*)", rep, t)
        parts.append(t)
    return "".join(parts)


def drop_lexicals(sql, notes):
    parts, found = [], []
    for lit, t in split_quotes(sql):
        if not lit and "&" in t:
            found += re.findall(r"&(\w+)", t)
            t = re.sub(r"(?i)\border\s+by\s+&\w+\s*(,\s*&\w+\s*)*", " ", t)
            t = re.sub(r"(?i)\bin\s*\(\s*&\w+\s*\)", " in (null)", t)
            t = re.sub(r"(?i)\bin\s+&\w+", " in (null)", t)
            t = re.sub(r"(?i)\bwhere\s+&\w+", " where 1=1 ", t)
            t = re.sub(r"(?i)\b(and|or)\s+&\w+", " ", t)
            t = re.sub(r"(?i)(\bselect\b|,)(\s*)&\w+(?=\s*(,|\bfrom\b))", r"\1\2 null ", t)   # select-list lexical -> null column
            t = re.sub(r"&\w+", " ", t)                                                        # condition fragments -> removed
        parts.append(t)
    if found:
        notes.append("lexical parameters removed: " + ", ".join(sorted(set(found))))
    return "".join(parts)


def trim_order_by(sql):
    """Remove a trailing ORDER BY (not allowed inside some wrappers and useless for an interactive report)."""
    depth, last = 0, None
    s = sql
    for m in re.finditer(r"\(|\)|\border\s+by\b", s, flags=re.I):
        tok = m.group(0)
        if tok == "(": depth += 1
        elif tok == ")": depth -= 1
        elif depth == 0: last = m.start()
    return s[:last] if last is not None else s


def describe(cur, sql, binds):
    cur.execute(f"select * from ({sql}) where 1=0", {b: None for b in binds})
    return [(d[0], d[1].name if hasattr(d[1], "name") else str(d[1])) for d in cur.description]


def safe_alias(name, used):
    a = re.sub(r"\W+", "_", name.upper()).strip("_")[:28] or "COL"
    if a[0].isdigit(): a = "C_" + a
    base, n = a, 2
    while a in used:
        a = f"{base[:25]}_{n}"; n += 1
    used.add(a)
    return a


# ------------------------------------------------------------------ build
def find_rdf(idx, name, system):
    prm = name.upper().strip()
    cands = [re.sub(r"_PRM$", "", prm), re.sub(r"_PRM(?=_)", "", prm), prm.replace("_PRM", ""), prm]
    pref_dir = SYS_DIR.get(system, "")
    for c in cands:
        paths = idx.get(c) or []
        if paths:
            paths = sorted(paths, key=lambda p: (0 if os.sep + pref_dir + os.sep in p else 1, len(p)))
            return c, paths[0], "name"
    # fall back to report names referenced inside the parameter form binary
    fmx = [p for p in mp.source_files("*.fmx")
           if os.path.splitext(os.path.basename(p))[0].upper() == prm]
    if fmx:
        raw = open(fmx[0], "rb").read().upper()
        hits = [k for k in idx if len(k) >= 5 and not k.endswith("_E") and k.encode() in raw and k != prm]
        if hits:
            k = max(hits, key=len)
            return k, sorted(idx[k], key=len)[0], "fmx"
    return None, None, None


def build():
    lab = labmod.load()
    c = connect(); cur = c.cursor()
    idx = rdf_index()
    specs = json.load(io.open(mp.work("out", "specs.json"), encoding="utf-8"))
    out = []
    for r in specs["report_pages"]:
        name = (r.get("name_e") or r.get("name_a") or "").strip()
        notes = []
        rs = {"page": r["page"], "system": r["system"], "serial": r["serial"], "prm": name.upper(), "title_a": r["desc_a"], "title_e": r["desc_e"],
              "notes": notes, "ok": False}
        key, path, how = find_rdf(idx, name, r["system"])
        if not path:
            notes.append("no RDF found for parameter form " + name)
            out.append(rs); continue
        rs["rdf"] = key; rs["rdf_path"] = os.path.relpath(path, ROOT)
        if how == "fmx": notes.append(f"RDF {key} found by name inside the parameter form")
        try:
            rep = parse_rdf(path)
        except Exception as e:
            notes.append(f"RDF parse error {e}"); out.append(rs); continue
        ovr = mp.kpath("report_overrides", f"{key}.sql") or ""
        if os.path.exists(ovr):
            rep["queries"] = [{"name": "OVERRIDE", "sql": io.open(ovr, encoding="utf-8").read(), "groups": []}]
            rep["links"] = []
            notes.append("SQL from reviewed override legacy/report_overrides/" + os.path.basename(ovr))
        if not rep["queries"]:
            notes.append("RDF has no SQL query"); out.append(rs); continue
        # ---- flatten main query + linked child queries (eq links only)
        qmap = {q["name"]: q for q in rep["queries"]}
        child_q = {l["childQuery"] for l in rep["links"]}
        def is_header(q):
            s = re.sub(r"\s+", " ", q["sql"].upper())
            return bool(re.match(r"^\s*SELECT\s+(COMPANY_LOGO|LOGO|IMG)\b", s)) or (len(s) < 120 and " FROM COMPANY" in s)
        def descendants(qn, seen=()):
            kids = {l["childQuery"] for l in rep["links"] if rep["groups"].get(l["parentGroup"]) == qn} - set(seen)
            return len(kids) + sum(descendants(k, seen + (qn,)) for k in kids)
        roots = [q for q in rep["queries"] if q["name"] not in child_q and not is_header(q)]
        main = max(roots, key=lambda q: (descendants(q["name"]), len(q["sql"]))) if roots else rep["queries"][0]
        if main is not rep["queries"][0]:
            notes.append(f"main query {main['name']} (first query is a header/logo query)")
        chain = [main]
        for lvl in range(2):
            parent = chain[-1]
            kids = collections.OrderedDict()
            for l in rep["links"]:
                if rep["groups"].get(l["parentGroup"]) == parent["name"] and l["childQuery"] in qmap and (l["condition"] or "eq") == "eq":
                    kids.setdefault(l["childQuery"], []).append((l["parentColumn"].upper(), l["childColumn"].upper()))
            if not kids: break
            kq, cols = next(iter(kids.items()))
            q = dict(qmap[kq]); q["join"] = cols
            chain.append(q)
            if len(kids) > 1: notes.append("other linked queries not shown: " + ", ".join(list(kids)[1:]))
        # ---- binds -> page items
        params = {p["name"]: p for p in rep["params"]}
        all_binds = []
        for q in chain:
            q["sql0"] = trim_order_by(drop_lexicals(strip_comments(q["sql"]), notes)).strip().rstrip(";")
            all_binds += binds_in(q["sql0"])
        all_binds = list(dict.fromkeys(all_binds))
        pg = r["page"]
        mapping, used = {}, set()
        for b in all_binds:
            item = f"P{pg}_{b}"[:30]
            n = 2
            while item in used: item = f"P{pg}_{b}"[:27] + f"_{n}"; n += 1
            used.add(item); mapping[b] = item
        types = {p["name"]: ("date" if p["datatype"] == "date" else "number" if p["datatype"] == "number" else None) for p in rep["params"]}
        # ---- describe each query and build the flattened select
        try:
            used_alias = set(); sel, frm = [], []
            q_cols = []
            for i, q in enumerate(chain):
                sqlq = rename_binds(q["sql0"], mapping, types)
                cols = describe(cur, sqlq, present_binds(sqlq, mapping.values()))
                q_cols.append(cols)
                a = f"q{i + 1}"
                if i == 0:
                    frm.append(f"({sqlq}) {a}")
                else:
                    prev = q_cols[i - 1]; pnames = {n.upper(): n for n, _ in prev}; cnames = {n.upper(): n for n, _ in cols}
                    conds = []
                    for pc, cc in q["join"]:
                        if pc in pnames and cc in cnames:
                            conds.append(f'{a}."{cnames[cc]}" = q{i}."{pnames[pc]}"')
                    if not conds:
                        notes.append(f"link columns not found for {q['name']}; detail query dropped"); chain = chain[:i]; q_cols = q_cols[:i]; break
                    frm.append(f"left join ({sqlq}) {a} on " + " and ".join(conds))
            columns = []
            for i, cols in enumerate(q_cols):
                for n, t in cols:
                    if t in ("DB_TYPE_BLOB", "DB_TYPE_CLOB", "DB_TYPE_NCLOB", "DB_TYPE_LONG", "DB_TYPE_LONG_RAW", "DB_TYPE_BFILE", "DB_TYPE_RAW"):
                        continue
                    if i > 0 and any(n.upper() == cc for _, cc in chain[i]["join"]):
                        continue                          # join column duplicates the parent value
                    alias = safe_alias(n, used_alias)
                    sel.append(f'q{i + 1}."{n}" {alias}')
                    typ = "NUMBER" if "NUMBER" in t else "DATE" if ("DATE" in t or "TIMESTAMP" in t) else "STRING"
                    g = lab["by_name"].get(n.upper()) or lab["by_name"].get(re.sub(r"\d+$", "", n.upper())) or {}
                    columns.append({"name": alias, "src": n, "type": typ, "label_a": g.get("a"), "label_e": g.get("e") or n.replace("_", " ").title()})
            sql = "select " + ",\n       ".join(sel) + "\n  from " + "\n  ".join(frm)
            describe(cur, sql, present_binds(sql, mapping.values()))
        except Exception as e:
            msg = str(e).split("\n")[0][:300]
            notes.append("SQL does not run on the new schema: " + msg)
            rs["sql_error"] = msg; rs["raw_sql"] = main["sql"][:4000]
            out.append(rs); continue
        # ---- parameter items
        items = []
        for b in all_binds:
            p = params.get(b, {"name": b, "datatype": "character", "label": None, "initial": None, "lov": None, "mask": None})
            role = SYSTEM_PARAMS.get(b)
            g = lab["by_name"].get(b) or lab["by_name"].get(re.sub(r"^(FROM|TO|F|T)_", "", b)) or {}
            label_a = p.get("label") if p.get("label") and "?" not in p.get("label") else g.get("a")
            if label_a and re.match(r"^(FROM|F)_", b) and not re.match(r"^\s*من\b", label_a): label_a = "من " + label_a
            if label_a and re.match(r"^(TO|T)_", b) and not re.match(r"^\s*(إلى|إلي|الى|الي|حتى)\b", label_a): label_a = "إلى " + label_a
            lov = None
            if p.get("lov") and not role:
                try:
                    lsql = rename_binds(drop_lexicals(strip_comments(p["lov"]["sql"]), []), mapping, types).strip().rstrip(";")
                    if re.search(r":(?!P\d+_)[A-Za-z]", "".join(t for l, t in split_quotes(lsql) if not l)):
                        raise ValueError("LOV references a bind that is not a report parameter")
                    lcols = describe(cur, lsql, present_binds(lsql, mapping.values()))
                    if len(lcols) >= 2:
                        lov = f'select "{lcols[1][0]}" || \' - \' || "{lcols[0][0]}" d, "{lcols[0][0]}" r from ({lsql})'
                    else:
                        lov = f'select "{lcols[0][0]}" d, "{lcols[0][0]}" r from ({lsql})'
                    describe(cur, lov, present_binds(lov, mapping.values()))
                except Exception as e:
                    notes.append(f"LOV of {b} dropped: {str(e)[:120]}"); lov = None
            items.append({"bind": b, "item": mapping[b], "role": role, "datatype": p.get("datatype") or "character",
                          "mask": p.get("mask"), "initial": p.get("initial"), "label_a": label_a, "label_e": g.get("e") or b.replace("_", " ").title(),
                          "lov": lov, "known": b in params})
        rs.update(ok=True, sql=sql, columns=columns, items=items, queries=[q["name"] for q in chain])
        if len(rep["queries"]) > len(chain):
            notes.append(f"{len(rep['queries']) - len(chain)} unlinked/secondary queries not shown (summaries, logos, headers)")
        out.append(rs)
    json.dump(out, io.open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    ok = sum(1 for r in out if r["ok"])
    print(f"reports {len(out)}: ok {ok}, no rdf {sum(1 for r in out if 'rdf' not in r)}, sql errors {sum(1 for r in out if r.get('sql_error'))}")
    errs = collections.Counter(re.sub(r"\d+", "#", r["sql_error"])[:70] for r in out if r.get("sql_error"))
    for e, n in errs.most_common(12): print(f"   {n:3} {e}")


if __name__ == "__main__":
    build()
