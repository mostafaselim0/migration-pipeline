r"""Parse the client's Forms XML, Reports XML and compiled .fmx files into a catalog (work/cache/catalog.json).
Only reads the legacy registry (SYS_FILES) and the table names from the database.  Run through the pipeline (stage catalog).
"""
import os, sys, re, io, json, glob, html, hashlib, collections
import xml.etree.ElementTree as ET
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE)); sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tools")); import mp

ROOT = mp.SOURCES
OUT = mp.work("cache", "catalog.json")

def read_xml(path):
    raw = open(path, "rb").read()
    m = re.match(rb"""<\?xml[^>]*encoding\s*=\s*['"]([^'"]+)['"]""", raw)
    enc = (m.group(1).decode() if m else "utf-8").lower()
    if enc in ("windows-1256", "cp1256", "ar8mswin1256"): enc = "cp1256"
    txt = raw.decode(enc, errors="replace")
    txt = re.sub(r"""encoding\s*=\s*['"][^'"]+['"]""", 'encoding="utf-8"', txt, count=1)
    txt = re.sub(r'\sxmlns="[^"]+"', "", txt, count=1)      # drop the Forms namespace so tag names stay plain
    return ET.fromstring(txt.encode("utf-8"))

def unesc(s):
    if s is None: return None
    s = html.unescape(s)
    s = html.unescape(s)          # Forms2XML double-escapes newlines (&amp;#10;)
    return s.replace("\t", "    ")

def lines(s): return 0 if not s else s.count("\n") + 1

TRIGGER_CLASS = [
    (r"^WHEN-VALIDATE-(ITEM|RECORD)$", "validation"),
    (r"^(PRE|POST)-(INSERT|UPDATE|DELETE|COMMIT|FORMS-COMMIT)$", "transaction"),
    (r"^KEY-COMMIT$", "transaction"),
    (r"^ON-(INSERT|UPDATE|DELETE|LOCK|COMMIT)$", "transaction"),
    (r"^POST-QUERY$", "derivation"),
    (r"^(PRE|POST)-QUERY$|^ON-(SELECT|FETCH)$|^KEY-EXEQRY$|^KEY-ENTQRY$", "query"),
    (r"^WHEN-NEW-(FORM|BLOCK|RECORD|ITEM)-INSTANCE$|^PRE-FORM$|^POST-FORM$|^PRE-BLOCK$|^POST-BLOCK$", "navigation/defaulting"),
    (r"^WHEN-BUTTON-PRESSED$", "action"),
    (r"^WHEN-(LIST|CHECKBOX|RADIO)-CHANGED$", "ui-event"),
    (r"^KEY-", "ui-key"),
    (r"^WHEN-(TIMER|WINDOW|TAB|MOUSE|IMAGE|TREE)", "ui-event"),
    (r"^ON-ERROR$|^ON-MESSAGE$", "messaging"),
    (r"^WHEN-CREATE-RECORD$|^WHEN-REMOVE-RECORD$|^WHEN-CLEAR-BLOCK$", "record-lifecycle"),
    (r"^(PRE|POST)-TEXT-ITEM$|^POST-CHANGE$", "ui-event"),
]
def classify(name):
    for pat, cls in TRIGGER_CLASS:
        if re.match(pat, name, re.I): return cls
    return "other"

def parse_form(path):
    root = read_xml(path)
    fm = root.find(".//FormModule")
    if fm is None: return None
    form = {"form": fm.get("Name"), "path": os.path.relpath(path, ROOT), "title": fm.get("Title"),
            "blocks": [], "items": [], "triggers": [], "lovs": [], "record_groups": [], "program_units": [], "relations": [], "alerts": []}
    for t in fm.findall("Trigger"):
        txt = unesc(t.get("TriggerText")); form["triggers"].append({"block": None, "item": None, "name": t.get("Name"), "level": "form", "text": txt, "lines": lines(txt), "class": classify(t.get("Name"))})
    for pu in fm.findall("ProgramUnit"):
        txt = unesc(pu.get("ProgramUnitText")); form["program_units"].append({"name": pu.get("Name"), "type": pu.get("ProgramUnitType"), "text": txt, "lines": lines(txt)})
    for rg in fm.findall("RecordGroup"):
        form["record_groups"].append({"name": rg.get("Name"), "type": rg.get("RecordGroupType"), "query": unesc(rg.get("RecordGroupQuery"))})
    for lov in fm.findall("LOV"):
        form["lovs"].append({"name": lov.get("Name"), "record_group": lov.get("RecordGroupName"), "title": lov.get("Title"),
                             "mappings": [(m.get("Name"), m.get("ReturnItem")) for m in lov.findall("LOVColumnMapping")]})
    for al in fm.findall("Alert"):
        form["alerts"].append({"name": al.get("Name"), "message": unesc(al.get("AlertMessage"))})
    for b in fm.findall("Block"):
        bd = {"block": b.get("Name"), "base_table": b.get("QueryDataSourceName"), "dml_table": b.get("DMLDataName"),
              "database_block": b.get("DatabaseBlock") == "true", "source_type": b.get("QueryDataSourceType"),
              "records_display": int(b.get("RecordsDisplayCount") or 1), "where": unesc(b.get("WhereClause")), "order_by": unesc(b.get("OrderByClause")),
              "insert_allowed": b.get("InsertAllowed") != "false", "update_allowed": b.get("UpdateAllowed") != "false", "delete_allowed": b.get("DeleteAllowed") != "false",
              "items": 0}
        for t in b.findall("Trigger"):
            txt = unesc(t.get("TriggerText")); form["triggers"].append({"block": bd["block"], "item": None, "name": t.get("Name"), "level": "block", "text": txt, "lines": lines(txt), "class": classify(t.get("Name"))})
        for it in b.findall("Item"):
            bd["items"] += 1
            form["items"].append({"block": bd["block"], "item": it.get("Name"), "item_type": it.get("ItemType") or "Text Item", "column_name": it.get("ColumnName"),
                                  "database_item": it.get("DatabaseItem") != "false", "data_type": it.get("DataType"), "max_length": it.get("MaximumLength"),
                                  "required": it.get("Required") == "true", "lov_name": it.get("LovName"), "prompt": unesc(it.get("Prompt")), "label": unesc(it.get("Label")),
                                  "format_mask": it.get("FormatMask"), "canvas": it.get("CanvasName"), "tab_page": it.get("TabPageName"),
                                  "visible": it.get("Visible") != "false", "list_elements": [(e.get("Name"), e.get("ListItemValue")) for e in it.findall("ListItemElement")]})
            for t in it.findall("Trigger"):
                txt = unesc(t.get("TriggerText")); form["triggers"].append({"block": bd["block"], "item": it.get("Name"), "name": t.get("Name"), "level": "item", "text": txt, "lines": lines(txt), "class": classify(t.get("Name"))})
        form["blocks"].append(bd)
    for r in fm.findall("Relation"):
        form["relations"].append({"name": r.get("Name"), "master": r.get("MasterBlock") or (r.get("Name") or "").split("_")[0], "detail": r.get("DetailBlock"), "join": unesc(r.get("JoinCondition")), "delete_rule": r.get("DeleteRecordBehavior")})
    # Relations in Forms2XML sit under the master block; capture those too
    for b in fm.findall("Block"):
        for r in b.findall("Relation"):
            form["relations"].append({"name": r.get("Name"), "master": b.get("Name"), "detail": r.get("DetailBlock"), "join": unesc(r.get("JoinCondition")), "delete_rule": r.get("DeleteRecordBehavior")})
    form["plsql_lines"] = sum(t["lines"] for t in form["triggers"]) + sum(p["lines"] for p in form["program_units"])
    return form

def cdata(el):
    return (el.text or "").strip() if el is not None else None

def parse_report(path):
    root = read_xml(path)
    rep = {"report": root.get("name"), "path": os.path.relpath(path, ROOT), "params": [], "queries": [], "code": [], "sections": [], "fields": 0, "tables": set()}
    for p in root.iter("userParameter"):
        rep["params"].append({"name": p.get("name"), "datatype": p.get("datatype"), "width": p.get("width"), "initial": p.get("initialValue"), "lov": None})
    for ds in root.iter("dataSource"):
        sel = ds.find(".//select")
        if sel is None: sel = ds.find(".//selectStatement")
        sql = cdata(sel)
        if sql:
            rep["queries"].append({"name": ds.get("name"), "sql": sql})
            for m in re.finditer(r"\b(?:from|join)\s+([a-z0-9_$.]+)", sql, re.I): rep["tables"].add(m.group(1).upper())
    for sel in root.iter("selectStatement"):   # LOV queries for parameters
        sql = cdata(sel)
        if sql and not any(q["sql"] == sql for q in rep["queries"]):
            rep["code"].append({"name": "param_lov", "type": "lov", "text": sql, "lines": lines(sql)})
    for f in root.iter("function"):
        txt = cdata(f.find("textSource")); rep["code"].append({"name": f.get("name"), "type": "function", "text": txt, "lines": lines(txt)})
    for fm in root.iter("formula"):
        rep["code"].append({"name": fm.get("name"), "type": "formula", "text": None, "lines": 0, "source": fm.get("source"), "datatype": fm.get("datatype")})
    for s in root.iter("section"):
        rep["sections"].append({"name": s.get("name"), "width": s.get("widthInChar"), "height": s.get("heightInChar"), "orientation": s.get("orientation")})
    rep["fields"] = sum(1 for _ in root.iter("field"))
    rep["frames"] = sum(1 for _ in root.iter("repeatingFrame"))
    rep["tables"] = sorted(rep["tables"])
    main_sql = rep["queries"][0]["sql"] if rep["queries"] else ""
    norm = re.sub(r"\s+", " ", re.sub(r"--.*?$", "", main_sql, flags=re.M)).strip().lower()
    rep["sql_hash"] = hashlib.md5(norm.encode("utf-8")).hexdigest() if norm else None
    rep["sql_lines"] = sum(lines(q["sql"]) for q in rep["queries"])
    rep["code_lines"] = sum(cd["lines"] for cd in rep["code"])
    return rep

def family_key(name):
    s = name.lower()
    s = re.sub(r"_rdf$", "", s)
    s = re.sub(r"(_e|_eng|_en)$", "", s)                      # language twin
    s = re.sub(r"(_new|_old|_o|_org|_last|_test|_bk|_prm|_all|_tot|_det|_sum)+$", "", s)
    s = re.sub(r"[_ ]?\d{1,2}$", "", s)                         # numeric variant
    s = re.sub(r"_\d{2}[-_]\d{2}[-_]\d{4}$|_\d{8}$|_\d{4}$", "", s)
    s = re.sub(r"_(hmc|hom|shanifi|rad|kh|as|ta)\d*$", "", s)   # customer variants
    return s.strip("_")

def fmx_strings(path, min_len=4):
    raw = open(path, "rb").read()
    out = []
    for m in re.finditer(rb"[\x20-\x7e\xc0-\xfe]{%d,}" % min_len, raw):
        try: s = m.group(0).decode("cp1256")
        except Exception: continue
        out.append(s)
    return out

def summarize_fmx(path, table_names):
    strs = fmx_strings(path)
    sqls = [s for s in strs if re.search(r"\bselect\b.*\bfrom\b", s, re.I)]
    tables = sorted({t for s in strs for t in re.findall(r"\b([A-Z][A-Z0-9_]{3,})\b", s.upper()) if t in table_names})
    arabic = [s for s in strs if re.search(r"[\u0600-\u06FF]{3,}", s)]
    triggers = sorted({s for s in strs if re.match(r"^(WHEN|PRE|POST|KEY|ON)-[A-Z-]+$", s)})
    return {"strings": len(strs), "sql_snippets": sqls[:200], "tables": tables, "arabic_labels": arabic[:300], "trigger_names": triggers}

def main():
    from db import connect
    cur = connect().cursor()
    cur.execute("select table_name from user_tables")
    table_names = {r[0].upper() for r in cur}
    cur.execute("""select upper(file_name_a) from sys_files where file_name_a is not null
                   union select upper(file_name_e) from sys_files where file_name_e is not null""")
    registry = {r[0].strip().lower() for r in cur if r[0]}
    cat = {"forms": [], "reports": [], "fmx": [], "families": {}}
    for p in sorted(mp.source_files("*_fmb.xml")):
        try:
            f = parse_form(p)
            if f: cat["forms"].append(f)
        except Exception as e: print("form parse error", p, e)
    for p in sorted(mp.source_files("*_RDF.xml")):
        try: cat["reports"].append(parse_report(p))
        except Exception as e: print("report parse error", p, e)
    # families
    fam = collections.defaultdict(list)
    for r in cat["reports"]:
        k = family_key(re.sub(r"_RDF$", "", r["report"], flags=re.I)); r["family"] = k; fam[k].append(r["report"])
    # merge families with identical main SQL hash
    by_hash = collections.defaultdict(set)
    for r in cat["reports"]:
        if r["sql_hash"]: by_hash[r["sql_hash"]].add(r["family"])
    cat["families"] = {k: {"members": v, "count": len(v)} for k, v in fam.items()}
    cat["identical_sql_groups"] = [sorted(v) for v in by_hash.values() if len(v) > 1]
    # compiled-only forms that are in the registry (in use, but no .fmb / XML delivered)
    with_xml = {(f["form"] or "").lower() for f in cat["forms"]}
    fmx_only = registry - with_xml
    fmx_paths = {}
    for p in mp.source_files("*.fmx"):
        fmx_paths.setdefault(os.path.splitext(os.path.basename(p))[0].lower(), p)
    for name in sorted(fmx_only):
        if name in fmx_paths:
            d = summarize_fmx(fmx_paths[name], table_names); d["form"] = name.upper(); d["path"] = os.path.relpath(fmx_paths[name], mp.BINARIES); cat["fmx"].append(d)
    json.dump(cat, io.open(OUT, "w", encoding="utf-8"), ensure_ascii=False)
    # summary
    print(f"forms parsed: {len(cat['forms'])}  blocks={sum(len(f['blocks']) for f in cat['forms'])} items={sum(len(f['items']) for f in cat['forms'])} triggers={sum(len(f['triggers']) for f in cat['forms'])} plsql_lines={sum(f['plsql_lines'] for f in cat['forms'])}")
    tc = collections.Counter(t["class"] for f in cat["forms"] for t in f["triggers"]); print("  trigger classes:", dict(tc))
    print(f"reports parsed: {len(cat['reports'])}  params={sum(len(r['params']) for r in cat['reports'])} queries={sum(len(r['queries']) for r in cat['reports'])} sql_lines={sum(r['sql_lines'] for r in cat['reports'])} code_lines={sum(r['code_lines'] for r in cat['reports'])}")
    print(f"  families: {len(cat['families'])}   families with >1 member: {sum(1 for v in cat['families'].values() if v['count']>1)}   identical-SQL cross-family groups: {len(cat['identical_sql_groups'])}")
    big = sorted(cat["families"].items(), key=lambda kv: -kv[1]["count"])[:12]; print("  biggest families:", [(k, v["count"]) for k, v in big])
    print(f"compiled-only in-use forms summarised: {len(cat['fmx'])}  with SQL snippets: {sum(1 for d in cat['fmx'] if d['sql_snippets'])}  avg tables/form: {sum(len(d['tables']) for d in cat['fmx'])/max(1,len(cat['fmx'])):.1f}")
    print("written", OUT)

if __name__ == "__main__":
    main()
