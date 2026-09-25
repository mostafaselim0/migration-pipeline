"""Fingerprints of a client's legacy system, used to compare it with the product knowledge (delta) and to teach the
knowledge a reviewed client (learn).  Everything is hashed, so the knowledge base stores no client data or source text.

   screens   one per active registry form (SYS_FILES): hashes of the form XML layout (blocks / items) and logic (triggers,
             program units), of the compiled .fmx (tables + SQL), and of its GN_FORM_ITEM labels
   reports   one per active registry report (SYS_REPORTS): hash of the RDF queries, parameters and PL/SQL
   tables    column list per table
   plsql     source text per stored procedure / function / package / trigger / view"""
import os, sys, re, io, json, hashlib, collections
HERE = os.path.dirname(os.path.abspath(__file__))
ENGINE = os.path.dirname(HERE)
sys.path.insert(0, ENGINE); sys.path.insert(0, os.path.join(ENGINE, "tools"))
import mp
from db import connect


def norm(s):
    """Code text without comments, case or layout differences."""
    s = re.sub(r"/\*.*?\*/", " ", s or "", flags=re.S)
    s = re.sub(r"--[^\n]*", " ", s)
    return re.sub(r"\s+", " ", s).strip().lower()


def h(obj):
    return hashlib.sha1(json.dumps(obj, sort_keys=True, ensure_ascii=False, default=str).encode("utf-8")).hexdigest()[:16]


def registry(cur):
    cur.execute("select system_number, file_serial, file_name_a, file_name_e, file_status from sys_files")
    forms = collections.defaultdict(list)
    for sysno, serial, na, ne, st in cur:
        name = (ne or na or "").strip().upper()
        if name and st == 1:
            forms[name].append(sysno)
    cur.execute("select system_number, report_file_name_a, report_file_name_e, report_status from sys_reports")
    reps = collections.defaultdict(list)
    for sysno, na, ne, st in cur:
        name = (ne or na or "").strip().upper()
        if name and st == 1:
            reps[name].append(sysno)
    cur.execute("select system_number, system_desc_a, system_desc_e from sys_systems order by 1")
    systems = {int(s): {"a": a, "e": e} for s, a, e in cur}
    return forms, reps, systems


def screen_prints(cat, labels):
    out = collections.defaultdict(dict)
    for f in cat.get("forms", []):
        name = (f.get("form") or "").upper()
        layout = [(b["block"], b.get("base_table"), b.get("dml_table"), norm(b.get("where")), b.get("insert_allowed"),
                   b.get("update_allowed"), b.get("delete_allowed")) for b in f["blocks"]]
        layout += [(i["block"], i["item"], i.get("column_name"), i.get("item_type"), i.get("lov_name"), i.get("required"))
                   for i in f["items"]]
        logic = [(t["level"], t.get("block"), t.get("item"), t["name"], norm(t.get("text"))) for t in f["triggers"]]
        logic += [(p["name"], norm(p.get("text"))) for p in f["program_units"]]
        logic += [(r.get("name"), norm(r.get("query"))) for r in f.get("record_groups", [])]
        out[name]["xml_layout"] = h(sorted(map(str, layout)))
        out[name]["xml_logic"] = h(sorted(map(str, logic)))
        out[name]["triggers"] = len(f["triggers"]); out[name]["plsql_lines"] = f.get("plsql_lines", 0)
    for d in cat.get("fmx", []):                  # the compiled form itself (not the tables it finds in this database)
        name = d["form"].upper()
        out[name]["fmx"] = h([sorted(norm(s) for s in d.get("sql_snippets", [])), sorted(d.get("trigger_names", []))])
    for form, items in (labels.get("form_items") or {}).items():
        out[form.upper()]["labels"] = h(sorted(items))
    return out


def report_prints(cat, resolved):
    """Registry report name -> hashes of the RDF the generator resolved for it (work/out/reports.json)."""
    by_path = {(r.get("path") or "").lower(): r for r in cat.get("reports", [])}
    out = {}
    for rs in resolved:
        r = by_path.get((rs.get("rdf_path") or "").lower())
        if not r:
            continue
        out[(rs.get("prm") or "").upper()] = {"rdf": rs.get("rdf"), "sql": h(sorted(norm(q["sql"]) for q in r["queries"])),
                                              "params": h(sorted(p["name"] or "" for p in r["params"])),
                                              "code": h(sorted(norm(c.get("text")) for c in r["code"] if c.get("text")))}
    return out


ENGINE_OBJ = re.compile(r"^(APP_|APPX_|RPT_|SRW$)")          # the engine's own objects are not the client's legacy system


def knowledge_tables():
    """Tables that the product knowledge's DB scripts create themselves (not part of a legacy dump)."""
    out = set()
    for p in mp.kfiles("db", "*.sql").values():
        out |= {m.upper() for m in re.findall(r'(?i)create\s+(?:global\s+temporary\s+)?table\s+"?(\w+)"?', io.open(p, encoding="utf-8").read())}
    return out


def table_prints(meta):
    skip = knowledge_tables()
    return {t: h([(c["name"], c["type"]) for c in v["cols"]]) for t, v in meta.items() if not ENGINE_OBJ.search(t) and t not in skip}


def schema_names():
    names = {mp.SCHEMA}
    p = mp.work("restore.json")
    if os.path.exists(p):
        names.add((json.load(io.open(p, encoding="utf-8")).get("source_schema") or mp.SCHEMA).upper())
    return names


def plsql_prints(cur):
    qual = re.compile(r'(?i)"?\b(' + "|".join(map(re.escape, schema_names())) + r')\b"?\s*\.')   # SMART.T, "OWNER".T -> T
    cur.execute("select type, name, text from user_source order by type, name, line")
    src = collections.defaultdict(list)
    for t, n, txt in cur:
        if not ENGINE_OBJ.search(n):
            src[f"{t} {n}"].append(txt)
    out = {k: h(norm(qual.sub("", "".join(v)))) for k, v in src.items()}
    cur.execute("select view_name, text_vc from user_views")
    for n, txt in cur:
        if not ENGINE_OBJ.search(n):
            out[f"VIEW {n}"] = h(norm(qual.sub("", txt or "")))
    return out


def snapshot():
    """Fingerprints of the current client (needs the catalog and generate stages: work/cache/catalog.json, labels.json,
    meta.json and work/out/reports.json)."""
    load = lambda *n: json.load(io.open(mp.work(*n), encoding="utf-8")) if os.path.exists(mp.work(*n)) else {}
    cat, labels, meta = load("cache", "catalog.json"), load("cache", "labels.json"), load("cache", "meta.json")
    cur = connect().cursor(); cur.arraysize = 5000
    forms, reps, systems = registry(cur)
    scr = screen_prints(cat, labels)
    rpp = report_prints(cat, load("out", "reports.json") or [])
    return {"systems": systems,
            "screens": {f: dict(scr.get(f, {}), systems=sorted(set(s))) for f, s in forms.items()},
            "reports": {r: dict(rpp.get(r, {}), systems=sorted(set(s))) for r, s in reps.items()},
            "tables": table_prints(meta),
            "plsql": plsql_prints(cur)}
