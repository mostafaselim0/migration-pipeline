"""Derive one page spec per in-use legacy form (SYS_FILES registry) from:
   - Forms XML catalog (_pipeline/catalog.json, forms with .fmb source)
   - GN_FORM_ITEM labels (block.item + Arabic/English prompts), also for .fmx-only forms
   - .fmx string summaries (tables referenced)
   - SMART dictionary (columns, PK, FK)
Writes gen/out/specs.json and gen/out/specs_report.txt (every heuristic decision is recorded in spec["notes"])."""
import os, sys, re, io, json, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tools"))
import meta as metamod, labels as labmod
from db import connect

sys.path.insert(0, os.path.dirname(HERE)); import mp
ROOT = mp.SOURCES
OUT = mp.work("out")

# first page of each legacy system (knowledge product.json, client.json may override); other systems share 86000+ / 93000+
SYSTEM_BASE = {int(k): int(v) for k, v in dict(mp.kjson("product.json").get("system_pages") or {},
                                                **(mp.CFG.get("system_pages") or {})).items()}
OTHER_SCREENS, OTHER_REPORTS = 86000, 93000
AUDIT_RE = re.compile(r"^(CREATE|UPDATE|INSERT|MODIFY|LAST_UPDATE)_(USER_CODE|USER|USERS_CODE|DATE|COMPANY_CODE|PASSWORD_NUMBER|TIME|TIMESTAMP)$|^TIMESTAMP$")
SKIP_ITEM_TYPES = {"Push Button", "Button", "Image", "Chart Item", "Bean Area", "Sound", "OLE Container", "ActiveX Control", "Tree"}
NAME_RE_A = re.compile(r"(^|_)(NAME|DESC|DESCRIPTION|TITLE)(_A|_AR|_ARB)?$")
MAX_UI_COLS = 60


def pretty(col):
    s = col.replace("_", " ").strip().title()
    return re.sub(r"\bE\b$", "(En)", s)


class Ctx:
    def __init__(self):
        self.meta = metamod.load()
        self.lab = labmod.load()
        self.cat = json.load(io.open(mp.work("cache", "catalog.json"), encoding="utf-8"))
        self.src_forms = {}
        for f in self.cat["forms"]:
            self.src_forms.setdefault(f["form"].upper(), f)
        self.fmx = {d["form"].upper(): d for d in self.cat["fmx"]}
        self.lovs = collections.OrderedDict()

    def table(self, name):
        if not name: return None
        n = name.upper().strip().strip('"')
        if "." in n: n = n.split(".")[-1]
        return n if n in self.meta else None

    def cols(self, t):
        """Columns of a table; {} when the table does not exist in this installation (reviewed rules may name one)."""
        m = self.meta.get(t)
        return {c["name"]: c for c in m["cols"]} if m else {}

    # ------------------------------------------------------------------ LOVs
    def pk_index(self):
        if hasattr(self, "_pki"): return self._pki
        idx = collections.defaultdict(list)
        for t, m in self.meta.items():
            if m["kind"] == "TABLE" and len(m["pk"]) == 1 and not re.search(r"_(BK|OLD|TEMP|TMP|BAK|X|\d+)$", t):
                idx[m["pk"][0]].append(t)
        self._pki = idx
        return idx

    def lov_for_fk(self, table, col):
        """Shared LOV for table.col: declared single-column FK first, else a code table whose single-column PK has the same name."""
        for fk in self.meta[table]["fks"]:
            if fk["cols"] == [col]:
                parent, pcol = fk["parent"], fk["pcols"][0]
                return self.lov(parent, pcol)
        import logical
        lp = logical.logical_parent(table, col, self.meta)
        if lp:
            return self.lov(*lp)
        if col in ("CODE", "SERIAL", "SEQ", "ID", "NO") or not re.search(r"(_CODE|_NO|_ID|_NUMBER|_SERIAL)$", col):
            return None
        cands = [t for t in self.pk_index().get(col, []) if t != table]
        if not cands: return None
        tokens = {x for x in re.split(r"_", col) if len(x) >= 3 and x not in ("CODE", "NUMBER", "SERIAL")}
        def score(t):
            tt = set(t.split("_"))
            return (len(tokens & tt), -len(t))
        best = sorted(cands, key=score, reverse=True)
        if len(best) > 1 and score(best[0]) == score(best[1]):
            return None
        return self.lov(best[0], col)

    def lov(self, parent, pcol):
        if parent not in self.meta: return None
        key = f"{parent}.{pcol}"
        if key in self.lovs: return key
        pc = self.cols(parent)
        cands = []
        for c in self.meta[parent]["cols"]:
            if c["name"] == pcol or c["type"] not in ("VARCHAR2", "CHAR", "NVARCHAR2"): continue
            n = c["name"]
            if n.endswith("_E") or n.endswith("_EN") or n.endswith("_ENG"): continue
            score = 5 if NAME_RE_A.search(n) else 3 if "NAME" in n else 2 if "DESC" in n else 0
            if score: cands.append((-score, c["id"], n))
        if not cands:
            return None
        disp_a = sorted(cands)[0][2]
        disp_e = None
        for e in (disp_a + "_E", re.sub(r"_A$", "_E", disp_a), re.sub(r"_AR$", "_EN", disp_a), disp_a + "_ENG"):
            if e in pc and e != disp_a:
                disp_e = e; break
        rows = self.meta[parent]["rows"] or 0
        self.lovs[key] = {"name": key, "table": parent, "ret": pcol, "disp_a": disp_a, "disp_e": disp_e, "rows": rows}
        return key


# ---------------------------------------------------------------------- registry
def registry():
    c = connect(); cur = c.cursor()
    cur.execute("select system_number, system_desc_a, system_desc_e, tree_order from sys_systems order by tree_order")
    systems = [{"system": s, "a": a, "e": e, "order": o} for s, a, e, o in cur]
    cur.execute("""select system_number, file_serial, file_desc_a, file_desc_e, menu_name, file_name_a, file_name_e,
                          file_status, file_level, tree_order, parent from sys_files order by system_number, tree_order nulls last, file_serial""")
    files = [dict(zip(["system", "serial", "desc_a", "desc_e", "menu", "name_a", "name_e", "status", "level", "tree", "parent"], r)) for r in cur]
    cur.execute("""select system_number, report_serial, report_desc_a, report_desc_e, menu_name, report_file_name_a, report_file_name_e,
                          tree_order, report_status, report_level from sys_reports order by system_number, tree_order nulls last, report_serial""")
    reports = [dict(zip(["system", "serial", "desc_a", "desc_e", "menu", "name_a", "name_e", "tree", "status", "level"], r)) for r in cur]
    return systems, files, reports


# ---------------------------------------------------------------------- blocks
def blocks_from_source(ctx, form, f, notes):
    out = []
    for b in f["blocks"]:
        # Forms2XML omits DatabaseBlock when it has the default value (true): a block with a base table is a database block
        t = ctx.table(b.get("dml_table")) or ctx.table(b.get("base_table"))
        if not t:
            continue
        items = [it for it in f["items"] if it["block"] == b["block"]]
        tabc = collections.Counter(it.get("tab_page") for it in items if it.get("tab_page"))
        out.append({"name": b["block"], "table": t, "multi": (b.get("records_display") or 1) > 1,
                    "tab": tabc.most_common(1)[0][0].upper() if tabc else None,
                    "where": b.get("where"), "order_by": b.get("order_by"),
                    "insert": b.get("insert_allowed", True), "update": b.get("update_allowed", True), "delete": b.get("delete_allowed", True),
                    "items": [{"item": it["item"], "col": (it.get("column_name") or it["item"]).upper(), "type": it.get("item_type"),
                               "visible": it.get("visible", True) and bool(it.get("canvas")), "required": it.get("required"),
                               "prompt_e": it.get("prompt") or it.get("label"), "lov": it.get("lov_name"),
                               "elements": it.get("list_elements") or [], "db": it.get("database_item", True)} for it in items]})
    rels = []
    for r in f.get("relations", []):
        if r.get("master") and r.get("detail"):
            rels.append({"master": r["master"], "detail": r["detail"], "join": r.get("join")})
    return out, rels


def match_col(item, colset):
    if item in colset: return item
    if len(item) >= 12:
        hits = [c for c in colset if c.startswith(item)]
        if len(hits) == 1: return hits[0]
    return None


def blocks_from_labels(ctx, form, notes):
    fi = ctx.lab["form_items"].get(form, {})
    per_block = collections.OrderedDict()
    for code, v in fi.items():
        if "." not in code: continue
        blk, item = code.split(".", 1)
        per_block.setdefault(blk, []).append((item, v))
    out = []
    fmx_tables = set(ctx.fmx.get(form, {}).get("tables", []))
    for blk, items in per_block.items():
        t = ctx.table(blk)
        if not t:
            # block not named after a table: pick the fmx-referenced table with best column overlap
            best = None
            for cand in fmx_tables:
                if cand not in ctx.meta: continue
                cs = set(ctx.cols(cand))
                hit = sum(1 for i, _ in items if match_col(i, cs))
                if hit >= max(2, int(0.6 * len(items))) and (best is None or hit > best[0]):
                    best = (hit, cand)
            if best:
                t = best[1]; notes.append(f"block {blk} mapped to table {t} by column overlap")
        if not t:
            continue
        cs = set(ctx.cols(t))
        its = []
        for i, v in items:
            col = match_col(i, cs)
            if col:
                its.append({"item": i, "col": col, "type": {"T": "Text Item", "D": "Display Item", "C": "Check Box", "LS": "List Item", "R": "Radio Group"}.get(v["type"], "Text Item"),
                            "visible": True, "required": None, "prompt_e": v.get("e"), "prompt_a": v.get("a"), "lov": None, "elements": [], "db": True})
        if its:
            out.append({"name": blk, "table": t, "multi": None, "where": None, "order_by": None,
                        "insert": True, "update": True, "delete": True, "items": its})
    return out, []


GENERIC_TABLES = {"ITEM", "DUMMY", "USERS", "COMPANY", "PASSWORD", "GROUPS", "MONTHS", "TIME", "MSG", "MESSAGES"}


def name_score(form, table):
    f, t = form.upper(), table.upper()
    if f == t: return 5
    if t.startswith(f) or f.startswith(t): return 4
    ft = {x for x in re.split(r"[_\d]+", f) if len(x) >= 4}
    tt = {x for x in re.split(r"[_\d]+", t) if len(x) >= 4}
    return 2 if ft & tt else 0


def blocks_from_fmx(ctx, form, notes):
    """.fmx-only form without GN_FORM_ITEM labels: accept only a referenced table whose name matches the form,
    plus its FK-related referenced tables (master/detail). Anything else is left for manual migration."""
    d = ctx.fmx.get(form)
    if not d: return [], []
    refs = [t for t in d.get("tables", []) if t in ctx.meta and ctx.meta[t]["kind"] == "TABLE"
            and t not in GENERIC_TABLES and not t.startswith("TEMP")]
    scored = sorted(((name_score(form, t), -len(ctx.meta[t]["cols"]), t) for t in refs), reverse=True)
    if not scored or scored[0][0] == 0:
        notes.append("no referenced table matches the form name; referenced: " + ", ".join(refs[:12]))
        return [], []
    main = scored[0][2]
    keep = [main]
    for t in refs:
        if t == main: continue
        if any(fk["parent"] == main for fk in ctx.meta[t]["fks"]) and name_score(form, t) > 0:
            keep.append(t)
    if len(refs) > len(keep):
        notes.append(f"fmx references {len(refs)} tables; used {', '.join(keep)} (name match)")
    return [{"name": t, "table": t, "multi": None, "where": None, "order_by": None,
             "insert": True, "update": True, "delete": True, "items": None} for t in keep[:4]], []


# ---------------------------------------------------------------------- relations
def parse_join(join, master_blk, detail_blk):
    pairs = []
    if not join: return pairs
    for a, b in re.findall(r"([A-Z0-9_$#]+\.[A-Z0-9_$#]+)\s*=\s*([A-Z0-9_$#:]+\.[A-Z0-9_$#]+)", join.upper()):
        (ab, ac), (bb, bc) = a.split("."), b.lstrip(":").split(".")
        if ab == detail_blk.upper() and bb == master_blk.upper(): pairs.append([ac, bc])
        elif bb == detail_blk.upper() and ab == master_blk.upper(): pairs.append([bc, ac])
    return pairs


def fk_join(ctx, detail_t, master_t):
    for fk in ctx.meta[detail_t]["fks"]:
        if fk["parent"] == master_t:
            return [[c, p] for c, p in zip(fk["cols"], fk["pcols"])]
    # PK-prefix convention: detail PK starts with master PK columns
    mpk, dpk = ctx.meta[master_t]["pk"], ctx.meta[detail_t]["pk"]
    if mpk and len(dpk) > len(mpk) and dpk[:len(mpk)] == mpk:
        return [[c, c] for c in mpk]
    return []


# ---------------------------------------------------------------------- columns
def label_for(ctx, form, blk, item, col, it, colmeta):
    fi = ctx.lab["form_items"].get(form, {})
    v = fi.get(f"{blk}.{item}") or fi.get(f"{blk}.{col}") or {}
    g = ctx.lab["by_name"].get(col) or ctx.lab["by_name"].get(item) or {}
    a = v.get("a") or (it or {}).get("prompt_a") or g.get("a")
    e = v.get("e") or (it or {}).get("prompt_e") or g.get("e")
    cm = colmeta.get("comment")
    if not e: e = pretty(col)
    if not a: a = cm if cm and re.search(r"[\u0600-\u06FF]", cm or "") else None
    return a, e


def build_cols(ctx, form, block, role, master_join=None):
    t = block["table"]; cm = ctx.cols(t); pk = ctx.meta[t]["pk"]
    notes = []
    chosen = collections.OrderedDict()
    if block["items"] is not None:
        for it in block["items"]:
            if it.get("type") in SKIP_ITEM_TYPES: continue
            col = it["col"] if it["col"] in cm else match_col(it["item"], set(cm))
            if not col or col in chosen: continue
            chosen[col] = it
    else:
        for c in ctx.meta[t]["cols"]:
            chosen[c["name"]] = None
    # make sure keys and mandatory columns are present
    for c in pk:
        chosen.setdefault(c, None)
    for c in ctx.meta[t]["cols"]:
        if not c["nullable"] and not c["default"] and not AUDIT_RE.match(c["name"]):
            chosen.setdefault(c["name"], None)
    join_cols = {d for d, m in (master_join or [])}
    auto = auto_key(ctx.meta[t])
    only = block.get("columns")                        # override: explicit visible column list, in order
    if only:
        only = [x.upper() for x in only]
        chosen = collections.OrderedDict((c, chosen.get(c)) for c in only if c in cm)
        for c in pk: chosen.setdefault(c, None)
        for c in ctx.meta[t]["cols"]:
            if not c["nullable"] and not c["default"] and not AUDIT_RE.match(c["name"]):
                chosen.setdefault(c["name"], None)
    out = []
    for col, it in chosen.items():
        c = cm[col]
        if c.get("virtual"): continue
        if AUDIT_RE.match(col):
            continue                                   # filled by the generated audit trigger
        label_a, label_e = label_for(ctx, form, block["name"], (it or {}).get("item", col), col, it, c)
        widget = "TEXT"
        dt = c["type"]
        if dt in ("DATE",) or dt.startswith("TIMESTAMP"): widget = "DATE"
        elif dt == "NUMBER" or dt == "FLOAT": widget = "NUMBER"
        elif dt in ("VARCHAR2", "NVARCHAR2", "CHAR") and (c["len"] or 0) > 300: widget = "TEXTAREA"
        elif dt in ("CLOB", "NCLOB"): widget = "TEXTAREA"
        elif dt in ("BLOB", "LONG", "LONG RAW", "RAW", "XMLTYPE", "BFILE"): continue
        lov = None; static = None
        if it and it.get("elements"):
            static = [[str(e[0]).strip() if e[0] is not None else str(e[1]), None if e[1] is None else str(e[1])] for e in it["elements"] if e[1] is not None]
            if static: widget = "SELECT_STATIC"
        if widget in ("NUMBER", "TEXT") and not static:
            lov = ctx.lov_for_fk(t, col)
            if lov:
                widget = "POPUP" if (ctx.lovs[lov]["rows"] or 0) > 80 else "SELECT"
        if it and it.get("type") == "Check Box" and dt in ("NUMBER", "CHAR", "VARCHAR2"):
            widget = "CHECK"
        hidden = False; readonly = False; default_item = None
        if col in join_cols:
            hidden = True                              # detail FK columns take the master key
        elif it is not None and not it.get("visible", True):
            hidden = True
        elif it is None and block["items"] is not None:
            hidden = col in pk and col == auto        # key filled by trigger
        if it and it.get("type") == "Display Item":
            readonly = True
        if col == "VALUE" and hidden and dt == "NUMBER" and role == "detail":
            hidden = False                             # legacy forms split VALUE into debit/credit display items
            label_a, label_e = "القيمة (+ مدين / - دائن)", "Value (+ debit / - credit)"
        is_auto = (col == auto)
        required = (not c["nullable"]) and not c["default"] and not is_auto and col not in join_cols
        if only and col not in only and not (col in pk or required):
            hidden = True
        elif not only and len(out) >= MAX_UI_COLS and not (col in pk or required):
            hidden = True
        out.append({"name": col, "type": dt, "len": c["len"], "prec": c["prec"], "scale": c["scale"],
                    "label_a": label_a, "label_e": label_e, "widget": widget, "lov": lov, "static": static,
                    "required": required, "pk": col in pk, "auto": is_auto, "hidden": hidden, "readonly": readonly,
                    "default": default_for(t, col, c, required)})
    return out


NOT_AUTO_RE = re.compile(r"YEAR|FLAG|TYPE|DATE|MONTH|LEVEL|STATUS|KIND|PERIOD|LANG")


def auto_key(m):
    """Last PK column filled with max+1 when left empty: numeric, not part of a foreign key, not a year/flag/type-like code."""
    pk = m["pk"]
    if not pk: return None
    last = pk[-1]
    col = next((c for c in m["cols"] if c["name"] == last), None)
    if not col or col["type"] != "NUMBER": return None
    if any(last in fk["cols"] for fk in m["fks"]): return None
    if NOT_AUTO_RE.search(last): return None
    return last


def default_for(table, col, c, required):
    """Defaults the legacy forms set in WHEN-CREATE-RECORD / PRE-INSERT: today, current year, local currency, rate 1, company."""
    d = (c.get("default") or "").strip()
    if d and re.fullmatch(r"-?\d+(\.\d+)?", d):
        return {"type": "STATIC", "value": d}
    if d and re.fullmatch(r"'[^']*'", d):
        return {"type": "STATIC", "value": d.strip("'")}
    if c["type"] == "DATE" and required and not re.search(r"(EXPIRE|END|TO|DUE)_?DATE|DATE_TO$", col):
        return {"type": "EXPRESSION", "value": "to_char(sysdate, 'DD/MM/YYYY')"}
    if re.search(r"(^|_)YEAR$", col) and c["type"] == "NUMBER" and required:
        if table.startswith("AC_"):
            return {"type": "SQL_QUERY", "value": "select nvl(max(current_year), to_number(to_char(sysdate, 'YYYY'))) from ac_basic where company_code = :G_COMPANY_CODE"}
        return {"type": "EXPRESSION", "value": "to_number(to_char(sysdate, 'YYYY'))"}
    if col in ("CURRENCY_CODE", "CURR_CODE"):
        return {"type": "STATIC", "value": "1"}
    if col in ("RATE", "CURRENCY_RATE", "CURR_RATE", "EXCHANGE_RATE"):
        return {"type": "STATIC", "value": "1"}
    if col in ("COMPANY_CODE", "COMP_CODE"):
        return {"type": "ITEM", "value": "G_COMPANY_CODE"}
    return None


# ---------------------------------------------------------------------- per form
def debit_credit(ctx, form, blk, cols):
    """Legacy voucher lines show DEBIT_VALUE / CREDIT_VALUE items over one signed VALUE column: reproduce that in the grid."""
    cm = ctx.cols(blk["table"])
    if "VALUE" not in cm or cm["VALUE"]["type"] != "NUMBER":
        return None
    fi = ctx.lab["form_items"].get(form, {})
    names = {k.split(".", 1)[1] for k in fi if k.startswith(blk["name"] + ".")} | {(it.get("item") or "").upper() for it in (blk.get("items") or [])}
    if not ({"DEBIT_VALUE", "CREDIT_VALUE"} <= names or {"DEBIT", "CREDIT"} <= names):
        return None
    d_key, c_key = ("DEBIT_VALUE", "CREDIT_VALUE") if "DEBIT_VALUE" in names else ("DEBIT", "CREDIT")
    d = fi.get(f"{blk['name']}.{d_key}") or {}
    c = fi.get(f"{blk['name']}.{c_key}") or {}
    for col in cols:
        if col["name"] == "VALUE":
            col.update(hidden=True, dc_value=True, required=False)
    at = next((i for i, col in enumerate(cols) if col["name"] == "VALUE"), len(cols))
    cols[at + 1:at + 1] = [
        {"name": "DEBIT_VALUE", "type": "NUMBER", "len": 22, "prec": None, "scale": None, "label_a": d.get("a") or "مدين", "label_e": d.get("e") or "Debit",
         "widget": "NUMBER", "lov": None, "static": None, "required": False, "pk": False, "auto": False, "hidden": False, "readonly": False, "computed": True},
        {"name": "CREDIT_VALUE", "type": "NUMBER", "len": 22, "prec": None, "scale": None, "label_a": c.get("a") or "دائن", "label_e": c.get("e") or "Credit",
         "widget": "NUMBER", "lov": None, "static": None, "required": False, "pk": False, "auto": False, "hidden": False, "readonly": False, "computed": True}]
    return {"value": "VALUE", "debit": "DEBIT_VALUE", "credit": "CREDIT_VALUE"}


OVR_DIR = os.path.join(os.path.dirname(HERE), "legacy", "overrides")


def load_override(form):
    p = mp.kpath("overrides", f"{form}.json") or ""                 # client overlay, then shared knowledge
    if not os.path.exists(p):
        return None
    try:
        ov = json.load(io.open(p, encoding="utf-8"))
        return ov if isinstance(ov, dict) and ov.get("pattern") else None
    except Exception as e:
        print("override ignored (unreadable):", form, e)
        return None


def spec_from_override(ctx, form, entries, ov):
    """Reviewed override (agent or developer): pattern + tables (+ joins); columns are still derived automatically."""
    notes = ["override: " + (ov.get("notes") or "reviewed")]
    title_a = ov.get("title_a") or entries[0]["desc_a"] or form
    title_e = ov.get("title_e") or entries[0]["desc_e"] or form
    spec = {"form": form, "system": entries[0]["system"], "serial": entries[0]["serial"], "entries": entries,
            "title_a": title_a, "title_e": title_e, "source": "override", "notes": notes, "pattern": ov["pattern"]}
    if ov["pattern"] in ("PROCESS", "PROC"):
        spec["pattern"] = "PROCESS"; spec["master"] = None; spec["details"] = []
        spec["proc"] = ov.get("proc")                   # process page definition (procedure + parameters)
        return spec
    if ov["pattern"] == "LINK":
        spec["master"] = None; spec["details"] = []; spec["link_page"] = ov.get("link_page")
        return spec
    def blk(t, multi):
        t = t.upper()
        items = None
        fi = ctx.lab["form_items"].get(form, {})
        cs = set(ctx.cols(t))
        gtype = {"T": "Text Item", "D": "Display Item", "C": "Check Box", "LS": "List Item", "R": "Radio Group"}
        its = [{"item": k.split(".", 1)[1], "col": match_col(k.split(".", 1)[1], cs), "type": gtype.get(v.get("type"), "Text Item"), "visible": True, "required": None,
                "prompt_e": v.get("e"), "prompt_a": v.get("a"), "lov": None, "elements": [], "db": True}
               for k, v in fi.items() if "." in k and match_col(k.split(".", 1)[1], cs)]
        return {"name": t, "table": t, "multi": multi, "where": ov.get("where"), "order_by": ov.get("order_by"),
                "insert": ov.get("insert", True), "update": ov.get("update", True), "delete": ov.get("delete", True),
                "items": None if (ov.get("all_columns") or ov.get("columns")) else ([i for i in its if i["col"]] or None)}
    mb = blk(ov["master"]["table"], ov["pattern"] == "GRID")
    if ov.get("columns") or ov["master"].get("columns"):
        mb["columns"] = ov["master"].get("columns") or ov.get("columns")
    spec["master"] = dict(mb, cols=build_cols(ctx, form, mb, "master" if ov["pattern"] == "MASTER_DETAIL" else "single"))
    spec["details"] = []
    for d in ov.get("details", []):
        if d["table"].upper() not in ctx.meta:                     # another version of the product: this detail table is absent
            degraded(form, f"detail grid {d['table'].upper()} of the reviewed rules left out: table does not exist in this installation", notes)
            continue
        db = blk(d["table"], True)
        if d.get("columns"): db["columns"] = d["columns"]; db["items"] = None
        j = d.get("join") or fk_join(ctx, db["table"], mb["table"])
        spec["details"].append(dict(db, join=j, cols=build_cols(ctx, form, db, "detail", j), title_a=d.get("title_a"), title_e=d.get("title_e")))
    for b in [spec["master"]] + spec["details"]:
        b.pop("items", None)
        b["is_view"] = ctx.meta[b["table"]]["kind"] == "VIEW"
    return spec


def make_col(ctx, t, col, label_a=None, label_e=None):
    """A page column for a table column the generator did not place (rules.add_columns)."""
    c = ctx.cols(t)[col]
    dt = c["type"]
    widget = "DATE" if dt == "DATE" or dt.startswith("TIMESTAMP") else "NUMBER" if dt in ("NUMBER", "FLOAT") else \
             "TEXTAREA" if (dt in ("CLOB", "NCLOB") or (c["len"] or 0) > 300) else "TEXT"
    lov = ctx.lov_for_fk(t, col) if widget in ("NUMBER", "TEXT") else None
    if lov:
        widget = "POPUP" if (ctx.lovs[lov]["rows"] or 0) > 80 else "SELECT"
    la, le = label_for(ctx, "", "", col, col, None, c)
    return {"name": col, "type": dt, "len": c["len"], "prec": c["prec"], "scale": c["scale"], "label_a": label_a or la, "label_e": label_e or le,
            "widget": widget, "lov": lov, "static": None, "required": False, "pk": False, "auto": False, "hidden": False, "readonly": False,
            "default": None}


def apply_rules(spec, ov, ctx=None):
    """Merge reviewed business rules (Stage C) into a spec: key expressions, validations, after-save checks, defaults."""
    rules = (ov or {}).get("rules")
    if not rules:
        return spec
    spec["rules"] = rules
    # extra columns the generator did not place (e.g. ST_TRNS_DET.EXPIRY_DATE for new lots), or hidden ones to show
    for key, opt in (rules.get("add_columns") or {}).items():
        t, col = key.upper().split(".", 1)
        opt = opt or {}
        for b in ([spec.get("master")] if spec.get("master") else []) + spec.get("details", []):
            if b["table"] != t: continue
            have = next((c for c in b["cols"] if c["name"] == col), None)
            if have:
                have["hidden"] = False
                if opt.get("label_a"): have["label_a"] = opt["label_a"]
                if opt.get("label_e"): have["label_e"] = opt["label_e"]
            elif ctx is not None and col in ctx.cols(t):
                have = make_col(ctx, t, col, opt.get("label_a"), opt.get("label_e")); b["cols"].append(have)
            if have is not None and opt.get("show_if"):
                have["show_if"] = opt["show_if"]
    # rules.sub_details: a grid under the selected line of another grid of the screen (detail of a detail)
    for sd in rules.get("sub_details") or []:
        t, parent = sd["table"].upper(), sd["parent"].upper()
        if ctx is None or t not in ctx.meta or not any(b["table"] == parent for b in spec.get("details", [])):
            spec["notes"].append(f"sub-detail {t}: its parent grid {parent} is not on this screen"); continue
        db = {"name": t, "table": t, "multi": True, "where": None, "order_by": sd.get("order_by"), "items": None,
              "insert": sd.get("insert", True), "update": sd.get("update", True), "delete": sd.get("delete", True)}
        if sd.get("columns"): db["columns"] = sd["columns"]
        j = sd.get("join") or fk_join(ctx, t, parent)
        if not j:
            spec["notes"].append(f"sub-detail {t}: no join to {parent}"); continue
        cols = build_cols(ctx, spec["form"], db, "detail", j)
        db.pop("items", None)
        spec["details"].append(dict(db, join=j, parent=parent, cols=cols, title_a=sd.get("title_a"), title_e=sd.get("title_e"),
                                    is_view=ctx.meta[t]["kind"] == "VIEW"))
    if rules.get("where") and spec.get("master"):
        spec["master"]["where"] = rules["where"]           # e.g. TRNS_TYPE_CODE in (...) for screens sharing ST_TRNS_MAST
    if rules.get("title_a"): spec["title_a"] = rules["title_a"]
    if rules.get("title_e"): spec["title_e"] = rules["title_e"]
    for b in ([spec.get("master")] if spec.get("master") else []) + spec.get("details", []):
        for c in b["cols"]:
            d = (rules.get("defaults") or {}).get(f"{b['table']}.{c['name']}") or (rules.get("defaults") or {}).get(c["name"]) \
                if b is spec.get("master") else (rules.get("defaults") or {}).get(f"{b['table']}.{c['name']}")
            if d: c["default"] = d
            if c["name"] in (rules.get("readonly") or []) or f"{b['table']}.{c['name']}" in (rules.get("readonly") or []):
                c["readonly"] = True
            if f"{b['table']}.{c['name']}" in (rules.get("hidden") or []):
                c["hidden"] = True
            if f"{b['table']}.{c['name']}" in (rules.get("optional") or []):
                c["required"] = False
    apply_column_rules(spec, rules, ctx)
    spec["notes"].append("business rules applied: " + ", ".join(sorted(rules)))
    return spec


def base_widget(c):
    dt = c["type"]
    if dt == "DATE" or dt.startswith("TIMESTAMP"): return "DATE"
    if dt in ("NUMBER", "FLOAT"): return "NUMBER"
    if dt in ("CLOB", "NCLOB") or (c.get("len") or 0) > 300: return "TEXTAREA"
    return "TEXT"


def apply_column_rules(spec, rules, ctx):
    """Per-column settings (rules.columns, "TABLE.COL" or "COL" for the master): the list of values - none, a SQL query
    ("lov": "select d, r from ..."), a static list or radio group ("static": [[label, value], ...], "widget": "RADIO") -, a check
    box ("widget": "CHECK", "values": [on, off]), "required", "readonly", "readonly_after_insert", "hidden", "default"
    ({type, value}; EXPRESSION / SQL_QUERY defaults also work on grid columns), labels.  rules.computed: display-only grid
    columns from a SQL expression over the row ("TABLE.NAME": {"sql": ..., "label_a": ..., "type": "NUMBER"}).
    rules.blocks: per block insert / update / delete flags ("TABLE": {"insert": false, ...})."""
    blocks = ([spec.get("master")] if spec.get("master") else []) + spec.get("details", [])
    for key, w in (rules.get("columns") or {}).items():
        t, col = key.upper().split(".", 1) if "." in key else ((spec.get("master") or {}).get("table"), key.upper())
        for b in blocks:
            if b["table"] != t: continue
            c = next((x for x in b["cols"] if x["name"] == col), None)
            if c is None and ctx is not None and col in ctx.cols(t):
                c = make_col(ctx, t, col); b["cols"].append(c)
            if c is None: continue
            w = w or {}
            if "lov" in w:
                c["lov"] = None; c.pop("lov_sql", None)
                c["widget"] = base_widget(c) if c["widget"] in ("SELECT", "POPUP", "SELECT_STATIC") else c["widget"]
                if w["lov"]:
                    c["lov_sql"] = w["lov"]; c["widget"] = w.get("widget") or "POPUP"
                    if w.get("cascade"):                  # the list depends on other fields of the same record (:PAGE_<COL> in the SQL)
                        c["cascade"] = [x.upper() for x in ([w["cascade"]] if isinstance(w["cascade"], str) else w["cascade"])]
            if w.get("static"):                       # [label_a, value] or [label_a, value, label_e]
                c["static"] = [[str(p[0]), str(p[1])] for p in w["static"]]; c["lov"] = None; c.pop("lov_sql", None)
                c["static_e"] = {str(p[0]): str(p[2]) for p in w["static"] if len(p) > 2 and p[2]}
                c["widget"] = "RADIO" if w.get("widget") == "RADIO" else "SELECT_STATIC"
            if w.get("widget") == "CHECK":
                c["widget"] = "CHECK"
                if w.get("values"): c["check"] = [str(v) for v in w["values"]]
            elif w.get("widget") in ("TEXT", "NUMBER", "DATE", "TEXTAREA"):
                c["widget"] = w["widget"]; c["lov"] = None
            for k in ("required", "readonly", "hidden"):
                if k in w: c[k] = bool(w[k])
            if w.get("readonly_after_insert"): c["ro_update"] = True
            if w.get("link"): c["link"] = w["link"]      # grid column opening another screen for its row
            if w.get("show_if"): c["show_if"] = w["show_if"]    # shown only to users with the right (else not rendered at all)
            if "default" in w: c["default"] = w["default"]
            for k in ("label_a", "label_e"):
                if w.get(k): c[k] = w[k]
    for key, w in (rules.get("computed") or {}).items():
        t, col = key.upper().split(".", 1)
        for b in blocks:
            if b["table"] != t or any(x["name"] == col for x in b["cols"]): continue
            typ = (w.get("type") or "VARCHAR2").upper()
            b["cols"].append({"name": col, "type": typ, "len": 4000, "prec": None, "scale": None,
                              "label_a": w.get("label_a") or col, "label_e": w.get("label_e") or col,
                              "widget": "NUMBER" if typ == "NUMBER" else "DATE" if typ == "DATE" else "TEXT", "lov": None, "static": None,
                              "required": False, "pk": False, "auto": False, "hidden": False, "readonly": True, "default": None,
                              "computed": True, "sql": w["sql"], "show_if": w.get("show_if")})
    for t, flags in (rules.get("blocks") or {}).items():
        tb, _, nth = t.upper().partition("#")               # "TABLE" = every block of it, "TABLE#2" = its second block
        same = [b for b in blocks if b["table"] == tb]
        for n, b in enumerate(same):
            if nth and str(n + 1) != nth: continue
            for k in ("insert", "update", "delete"):
                if k in flags: b[k] = bool(flags[k])
            if flags.get("where"):                      # extra filter of a detail grid (its rows besides the master link)
                b["dwhere"] = flags["where"]


_PRINTS = None


def prints():
    """prints.json: exact print layout (legacy RDF) per document screen (shared knowledge + the client's overlay)."""
    global _PRINTS
    if _PRINTS is None:
        _PRINTS = {k.upper(): v for k, v in mp.kjson("prints.json").items() if not k.startswith("_")}
    return _PRINTS


def apply_extras(spec, ov):
    """Document action buttons (conversions, legacy/STAGE_C_ACTIONS_ADDENDUM.md) and the legacy print layout (RDF) of a document."""
    if ov and ov.get("actions") and spec.get("pattern") in ("MASTER_DETAIL", "GRID", "REPORT_FORM"):
        spec["actions"] = ov["actions"]
    if ov and ov.get("links"):                       # buttons that only open another screen
        spec["links"] = ov["links"]
    if ov and ov.get("fills"):                       # buttons that add rows to a grid for the user to complete before saving
        spec["fills"] = ov["fills"]
    pr = (ov or {}).get("print") or prints().get(spec["form"].upper())
    if pr and (spec.get("pattern") in ("MASTER_DETAIL", "REPORT_FORM", "GRID") or (spec.get("pattern") == "PROCESS" and spec.get("proc"))):
        spec["print_rdf"] = pr
    return spec


DEGRADED = []            # (form, what) - reviewed knowledge that does not fit this installation (work/out/specs_degraded.json)


def degraded(form, what, notes=None):
    DEGRADED.append({"form": form, "what": what})
    if notes is not None:
        notes.append("degraded: " + what)


def build_spec(ctx, form, entries):
    ov = load_override(form)
    if ov and ov.get("pattern") != "AUTO":
        mt = ((ov.get("master") or {}).get("table") or "").upper()
        if ov["pattern"] in ("GRID", "MASTER_DETAIL", "REPORT_FORM") and mt not in ctx.meta:
            # the reviewed screen is built on a table this installation does not have: generate the screen from the client's
            # own sources instead and say so (rules of the override are not applied, they refer to that table)
            spec = build_spec_auto(ctx, form, entries)
            degraded(form, f"reviewed rules skipped: their table {mt or '?'} does not exist in this installation", spec["notes"])
            return apply_extras(spec, None)
        return apply_extras(apply_rules(spec_from_override(ctx, form, entries, ov), ov, ctx), ov)
    spec = build_spec_auto(ctx, form, entries)
    return apply_extras(apply_rules(spec, ov, ctx) if ov else spec, ov)


def build_spec_auto(ctx, form, entries):
    notes = []
    src = ctx.src_forms.get(form)
    if src:
        blocks, rels = blocks_from_source(ctx, form, src, notes); source = "fmb"
    else:
        blocks, rels = blocks_from_labels(ctx, form, notes); source = "fmx+labels"
        if not blocks:
            blocks, rels = blocks_from_fmx(ctx, form, notes); source = "fmx"
    if not blocks:
        source = source if (src or form in ctx.fmx or form in ctx.lab["form_items"]) else "none"
    menus = {(e.get("menu") or "").split(".")[0].upper() for e in entries}
    if source == "fmx" and menus & {"SYSTEM_MENU", "SYSTEMS_MENU"}:
        notes.append("system operation (posting/closing type) without source: process screen")
        blocks = []
    title_a = entries[0]["desc_a"] or (ctx.lab["titles"].get(form) or {}).get("a") or form
    title_e = entries[0]["desc_e"] or (ctx.lab["titles"].get(form) or {}).get("e") or form
    spec = {"form": form, "system": entries[0]["system"], "serial": entries[0]["serial"], "entries": entries,
            "title_a": title_a, "title_e": title_e, "source": source, "notes": notes}
    # de-duplicate blocks on the same table (keep the first)
    seen = set(); uniq = []
    for b in blocks:
        if b["table"] in seen:
            notes.append(f"block {b['name']} duplicates table {b['table']}; ignored"); continue
        seen.add(b["table"]); uniq.append(b)
    blocks = uniq
    if not blocks:
        spec["pattern"] = "PROCESS"; spec["master"] = None; spec["details"] = []
        notes.append("no database block found: process/parameter screen, needs manual migration")
        return spec
    byname = {b["name"]: b for b in blocks}
    # relations: from source, else FK between block tables
    edges = []
    for r in rels:
        m, d = byname.get(r["master"]), byname.get(r["detail"])
        if m and d:
            j = parse_join(r["join"], m["name"], d["name"]) or fk_join(ctx, d["table"], m["table"])
            if j: edges.append((m["name"], d["name"], j))
    if not edges:
        for d in blocks:
            for m in blocks:
                if m is d: continue
                j = fk_join(ctx, d["table"], m["table"])
                if j: edges.append((m["name"], d["name"], j))
    children = collections.defaultdict(list); parents = collections.defaultdict(list)
    for m, d, j in edges:
        if d not in [x[0] for x in children[m]]:
            children[m].append((d, j)); parents[d].append(m)
    if edges:
        roots = [b["name"] for b in blocks if not parents[b["name"]] and children[b["name"]]]
        root = max(roots, key=lambda n: len(children[n])) if roots else edges[0][0]
        mb = byname[root]
        spec["pattern"] = "MASTER_DETAIL"
        mb["multi"] = False
        spec["master"] = dict(mb, cols=build_cols(ctx, form, mb, "master"))
        spec["details"] = []
        tabs = ctx.lab.get("tabs", {}).get(form, {})
        for dname, j in children[root]:
            db = byname[dname]
            tl = tabs.get(db.get("tab") or "", {}) or {}
            cols = build_cols(ctx, form, db, "detail", j)
            dc = debit_credit(ctx, form, db, cols)
            spec["details"].append(dict(db, multi=True, join=j, cols=cols, title_a=tl.get("a"), title_e=tl.get("e"), debit_credit=dc))
            if dc: notes.append(f"{db['table']}: VALUE entered as debit / credit columns")
        others = [b["name"] for b in blocks if b["name"] != root and b["name"] not in [d for d, _ in children[root]]]
        if others: notes.append("blocks not placed on the page (deeper levels or unrelated): " + ", ".join(others))
    else:
        mb = max(blocks, key=lambda b: len(b["items"] or []) if b["items"] is not None else 0) if len(blocks) > 1 else blocks[0]
        cols = build_cols(ctx, form, mb, "single")
        ui = [c for c in cols if not c["hidden"]]
        multi = mb["multi"]
        if multi is None:
            multi = len(ui) <= 10
            notes.append(f"record layout unknown (no .fmb); chose {'grid' if multi else 'report + form'} from {len(ui)} visible columns")
        spec["pattern"] = "GRID" if multi else "REPORT_FORM"
        spec["master"] = dict(mb, cols=cols); spec["details"] = []
        if len(blocks) > 1:
            notes.append("unrelated blocks not placed: " + ", ".join(b["name"] for b in blocks if b is not mb))
    for b in [spec["master"]] + spec["details"]:
        b.pop("items", None)
        b["is_view"] = ctx.meta[b["table"]]["kind"] == "VIEW"
        if b["is_view"]:
            b["insert"] = b["update"] = b["delete"] = False
            notes.append(f"{b['table']} is a view: read-only")
    if spec["master"]["is_view"] and spec["pattern"] != "GRID":
        spec["pattern"] = "GRID"; spec["details"] = []
        notes.append("master is a view: shown as a read-only grid")
    return spec


def assign_pages(specs, reports):
    used = collections.defaultdict(int)
    for s in specs:
        base = SYSTEM_BASE.get(s["system"], OTHER_SCREENS)
        used[base] += 1
        s["page"] = base + 10 * used[base]
        s["form_page"] = s["page"] + 1 if s["pattern"] in ("REPORT_FORM", "MASTER_DETAIL") else None
    rused = collections.defaultdict(int)
    for r in reports:
        base = SYSTEM_BASE[r["system"]] + 5000 if r["system"] in SYSTEM_BASE else OTHER_REPORTS
        rused[base] += 1
        r["page"] = base + 10 * rused[base]


def main():
    ctx = Ctx()
    systems, files, reports = registry()
    by_form = collections.OrderedDict()
    for f in files:
        name = (f["name_e"] or f["name_a"] or "").strip().upper()
        if f["status"] != 1 or not name:
            continue
        by_form.setdefault(name, []).append(f)
    specs = [build_spec(ctx, form, entries) for form, entries in by_form.items()]
    rep_leaves = [r for r in reports if (r["name_e"] or r["name_a"]) and r["status"] == 1]
    assign_pages(specs, rep_leaves)
    data = {"systems": systems, "files": files, "reports": reports, "report_pages": rep_leaves,
            "specs": specs, "lovs": list(ctx.lovs.values())}
    json.dump(data, io.open(os.path.join(OUT, "specs.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1, default=str)
    json.dump(DEGRADED, io.open(os.path.join(OUT, "specs_degraded.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    if DEGRADED:
        print(f"reviewed knowledge that does not fit this installation: {len(DEGRADED)} item(s) (out/specs_degraded.json)")
    cnt = collections.Counter(s["pattern"] for s in specs); src = collections.Counter(s["source"] for s in specs)
    with io.open(os.path.join(OUT, "specs_report.txt"), "w", encoding="utf-8") as fh:
        fh.write(f"forms {len(specs)}  patterns {dict(cnt)}  sources {dict(src)}  lovs {len(ctx.lovs)}  report pages {len(rep_leaves)}\n\n")
        for s in specs:
            m = s["master"]
            fh.write(f"{s['page']:>6} {s['form']:<28} {s['pattern']:<14} {s['source']:<11} "
                     f"{(m or {}).get('table','-'):<26} det={','.join(d['table'] for d in s['details'])} "
                     f"cols={len((m or {}).get('cols', []))} | {s['title_e']}\n")
            for n in s["notes"]: fh.write(f"         - {n}\n")
    print(f"forms {len(specs)}  patterns {dict(cnt)}  sources {dict(src)}  lovs {len(ctx.lovs)}  report pages {len(rep_leaves)}")


if __name__ == "__main__":
    main()
