"""Evidence packs for logic reconstruction (Stage C). For a legacy form, collect into app/legacy/evidence/<FORM>.md:
registry rows, GN_FORM_ITEM labels, .fmx strings (SQL + messages + identifiers), .fmb triggers/program units (if source exists),
PL/SQL library procedures it references (text dumped from .pll), and metadata of the tables involved.
   python evidence.py FORM [FORM ...]      |   python evidence.py --process   (all PROCESS-pattern forms)"""
import os, sys, re, io, json, glob, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tools"))
from db import connect

sys.path.insert(0, os.path.dirname(HERE)); import mp
ROOT = mp.SOURCES
EVD = mp.work("evidence"); PLL = mp.work("pll")
os.makedirs(EVD, exist_ok=True); os.makedirs(PLL, exist_ok=True)


def strings(raw, minlen=4):
    out = []
    for m in re.finditer(rb"[\x09\x0a\x0d\x20-\x7e\xc0-\xfe]{%d,}" % minlen, raw):
        out.append(m.group(0).decode("cp1256", "replace"))
    return out


def dump_pll():
    """Readable text of every .pll (the library source is stored as text inside the binary)."""
    idx = {}
    for p in mp.source_files("*.pll"):
        name = os.path.splitext(os.path.basename(p))[0].upper()
        txt = "\n".join(strings(open(p, "rb").read(), 3))
        out = os.path.join(PLL, f"{name}__{abs(hash(p)) % 10000}.txt")
        io.open(out, "w", encoding="utf-8").write(txt)
        for m in re.finditer(r"(?i)\b(PROCEDURE|FUNCTION)\s+([A-Z_][A-Z0-9_$#]{2,})", txt):
            idx.setdefault(m.group(2).upper(), set()).add(out)
    return idx


def proc_text(path, name, maxlen=12000):
    txt = io.open(path, encoding="utf-8").read()
    m = re.search(r"(?is)\b(PROCEDURE|FUNCTION)\s+" + re.escape(name) + r"\b.*?\bEND\s+" + re.escape(name) + r"\s*;", txt)
    if m: return m.group(0)[:maxlen]
    i = txt.upper().find(name)
    return txt[max(0, i - 200): i + 4000]


def build(form, pll_idx, meta, cur, cat_forms, lab):
    form = form.upper()
    md = [f"# Evidence pack: {form}\n"]
    cur.execute("""select system_number, file_serial, file_desc_a, file_desc_e, menu_name, tree_order from sys_files
                    where upper(nvl(file_name_e, file_name_a)) = :1""", [form])
    md.append("## Registry (SYS_FILES)\n")
    for r in cur.fetchall(): md.append(f"- system {r[0]} serial {r[1]}: {r[2]} / {r[3]} (menu {r[4]}, order {r[5]})")
    md.append("\n## Labels (GN_FORM_ITEM: block.item, type, Arabic / English)\n")
    cur.execute("""select item_code, item_type, prompt_a, prompt_e, label_a, label_e from gn_form_item where upper(form_code) = :1
                   order by item_code""", [form])
    for r in cur.fetchall():
        md.append(f"- {r[0]} [{r[1]}] {r[2] or r[4] or ''} / {r[3] or r[5] or ''}")
    tables = set()
    f = cat_forms.get(form)
    if f:
        md.append("\n## Forms source (.fmb): blocks\n")
        for b in f["blocks"]:
            md.append(f"- block {b['block']}: base table {b.get('base_table')}, rows {b.get('records_display')}, where {b.get('where')}")
            if b.get("base_table"): tables.add(b["base_table"].upper())
        md.append("\n## Forms source: items\n")
        for it in f["items"]:
            md.append(f"- {it['block']}.{it['item']} ({it['item_type']}) prompt={it.get('prompt')} lov={it.get('lov_name')}")
        md.append("\n## Forms source: triggers\n")
        for t in f["triggers"]:
            if t["text"]:
                md.append(f"### {t['level']} {t.get('block') or ''}.{t.get('item') or ''} {t['name']}\n```sql\n{t['text']}\n```")
        for pu in f["program_units"]:
            if pu["text"]:
                md.append(f"### program unit {pu['name']} ({pu['type']})\n```sql\n{pu['text']}\n```")
        for rg in f["record_groups"]:
            if rg.get("query"): md.append(f"### record group {rg['name']}\n```sql\n{rg['query']}\n```")
    fmx = [p for p in mp.source_files("*.fmx")
           if os.path.splitext(os.path.basename(p))[0].upper() == form]
    used_procs = set()
    if fmx:
        raw = open(fmx[0], "rb").read()
        ss = strings(raw, 4)
        sql = [s for s in ss if re.search(r"(?is)\b(select|insert\s+into|update\s+\w+\s+set|delete\s+from|begin|declare)\b", s)]
        arabic = [s for s in ss if re.search(r"[\u0600-\u06FF]{3,}", s)]
        idents = sorted({t for s in ss for t in re.findall(r"\b[A-Z][A-Z0-9_]{3,}\b", s.upper())})
        for t in idents:
            if t in meta: tables.add(t)
            if t in pll_idx: used_procs.add(t)
        md.append(f"\n## Compiled form (.fmx {os.path.relpath(fmx[0], ROOT)}): embedded SQL ({len(sql)})\n")
        for s in sql: md.append(f"```sql\n{s.strip()[:3000]}\n```")
        md.append("\n## .fmx Arabic texts (messages, prompts)\n")
        for s in arabic[:200]: md.append(f"- {s.strip()[:300]}")
        md.append("\n## .fmx identifiers (items, blocks, program units, tables)\n")
        md.append(", ".join(idents[:1500]))
    if f:
        for t in f["triggers"] + f["program_units"]:
            for nm in re.findall(r"\b[A-Z_][A-Z0-9_]{3,}\b", (t.get("text") or "").upper()):
                if nm in pll_idx: used_procs.add(nm)
                if nm in meta: tables.add(nm)
    if used_procs:
        md.append("\n## PL/SQL library procedures referenced (.pll text)\n")
        for p in sorted(used_procs):
            for path in sorted(pll_idx[p])[:1]:
                md.append(f"### {p} (from {os.path.basename(path)})\n```sql\n{proc_text(path, p)}\n```")
    md.append("\n## Tables involved (SMART)\n")
    for t in sorted(tables):
        if t not in meta: continue
        m = meta[t]
        md.append(f"### {t} ({m['kind']}, rows {m['rows']}) PK {m['pk']}")
        md.append("columns: " + ", ".join(f"{c['name']} {c['type']}{'' if c['nullable'] else ' NOT NULL'}" for c in m["cols"]))
        if m["fks"]: md.append("FKs: " + "; ".join(f"{','.join(fk['cols'])} -> {fk['parent']}({','.join(fk['pcols'])})" for fk in m["fks"]))
    cur.execute("select trigger_name, table_name, triggering_event from user_triggers where table_name in (select column_value from table(:1)) and trigger_name not like 'APPX%'",
                [cur.connection.gettype("SYS.ODCIVARCHAR2LIST").newobject(sorted(tables)[:1000])]) if tables else None
    if tables:
        trg = cur.fetchall()
        if trg:
            md.append("\n## Existing DB triggers on these tables\n")
            for tn, tb, ev in trg: md.append(f"- {tn} on {tb} ({ev})")
    path = os.path.join(EVD, f"{form}.md")
    io.open(path, "w", encoding="utf-8").write("\n".join(md))
    return path, len("\n".join(md))


def main(forms):
    pll_idx = dump_pll()
    meta = json.load(io.open(mp.work("cache", "meta.json"), encoding="utf-8"))
    cat = json.load(io.open(mp.work("cache", "catalog.json"), encoding="utf-8"))
    cat_forms = {}
    for f in cat["forms"]: cat_forms.setdefault(f["form"].upper(), f)
    lab = None
    c = connect(); cur = c.cursor()
    for form in forms:
        p, n = build(form, pll_idx, meta, cur, cat_forms, lab)
        print(f"{form:30} {n:8} chars -> {p}")


if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["--process"]:
        specs = json.load(io.open(mp.work("out", "specs.json"), encoding="utf-8"))
        args = [s["form"] for s in specs["specs"] if s["pattern"] == "PROCESS"]
    main(args)
