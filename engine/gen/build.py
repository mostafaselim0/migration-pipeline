"""Build the client's APEX application from work/out/specs.json.
   python build.py db       -> run the DB code (engine core, product knowledge, client overlay), fill APP_PAGE_MAP /
                               APP_PAGE_SERIALS / APP_MENU, install audit+key triggers
   python build.py apex     -> write work/build/app (split export format)
   python build.py install  -> import work/build/app/install.sql with SQLcl
   python build.py all      -> db + apex + install"""
import os, sys, io, re, json, shutil, subprocess, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tools"))
import apexgen as G
import degrade
from apexgen import call, Id, Raw, attrs, nid, q, write
from db import connect
import oracledb

APPDIR = os.path.dirname(HERE)
sys.path.insert(0, APPDIR); import mp
SPECS = mp.work("out", "specs.json")

GROUPS = {  # legacy menu module prefix -> (seq, arabic, english, icon)
    "FILES_MENU": (10, "الحركات", "Transactions", "fa-exchange"),
    "CODES_MENU": (20, "الترميز والتعريفات", "Codes & Setup", "fa-list-ol"),
    "QUERY_MENU": (30, "الاستعلامات", "Queries", "fa-search"),
    "SYSTEM_MENU": (40, "عمليات النظام", "System Operations", "fa-cogs"),
    "SYSTEMS_MENU": (41, "الأنظمة", "Systems", "fa-cubes"),
    "USERS_MENU": (42, "المستخدمون", "Users", "fa-users"),
    "PRIVILIAGE_MENU": (43, "الصلاحيات", "Privileges", "fa-key"),
    "COMPANY_MENU": (44, "الشركات", "Companies", "fa-building"),
    "SUB_MENU": (45, "شاشات فرعية", "Sub Screens", "fa-folder-o"),
    "POS_MENU": (46, "نقاط البيع", "Point of Sale", "fa-shopping-cart"),
    "GRAPIC_MENU": (60, "الرسوم البيانية", "Charts", "fa-bar-chart"),
    "REPORTS_MENU": (50, "التقارير", "Reports", "fa-file-text-o"),
}
SYSTEM_ICONS = {0: "fa-cog", 1: "fa-book", 3: "fa-cubes", 4: "fa-users", 5: "fa-truck", 30: "fa-shopping-bag",
                31: "fa-line-chart", 88: "fa-percent", 99: "fa-shield"}


def load():
    data = json.load(io.open(SPECS, encoding="utf-8"))
    rpath = mp.work("out", "reports.json")
    data["reports_gen"] = json.load(io.open(rpath, encoding="utf-8")) if os.path.exists(rpath) else []
    byp = {r["page"]: r for r in data["reports_gen"]}
    for r in data["report_pages"]:
        if r["page"] in byp:
            r["generated"] = True
            r["ok"] = byp[r["page"]]["ok"]
    return data


# =========================================================================== DB side
def build_menu(data):
    """Menu tree rows for APP_MENU: system -> module group -> (legacy sub menus) -> form / report."""
    rows = []
    specs_by_form = {s["form"]: s for s in data["specs"]}
    for s in data["systems"]:
        rows.append(dict(id=1_000_000 + s["system"], parent_id=None, seq=s["order"] or s["system"], label_a=s["a"], label_e=s["e"],
                         kind="SYSTEM", page_id=None, system_number=s["system"], file_serial=None, icon=SYSTEM_ICONS.get(s["system"], "fa-folder")))
    sys_ids = {s["system"] for s in data["systems"]}

    def group_id(system, key):
        return 2_000_000 + system * 10_000 + (abs(hash(key)) % 9_999)

    groups = {}
    def ensure_group(system, prefix, label_a=None, label_e=None, parent=None, seq=None, icon=None):
        k = (system, prefix.upper())
        if k in groups: return groups[k]
        g = GROUPS.get(prefix.upper())
        gid = group_id(system, prefix.upper())
        while any(r["id"] == gid for r in rows): gid += 1
        rows.append(dict(id=gid, parent_id=parent or (1_000_000 + system), seq=seq or (g[0] if g else 70),
                         label_a=label_a or (g[1] if g else prefix.replace("_MENU", "").replace("_", " ")),
                         label_e=label_e or (g[2] if g else prefix.replace("_MENU", "").replace("_", " ").title()),
                         kind="GROUP", page_id=None, system_number=system, file_serial=None, icon=icon or (g[3] if g else "fa-folder-o")))
        groups[k] = gid
        return gid

    def attach(items, kind):
        # menu node rows (no file name): they own a legacy sub-menu named <suffix>_MENU or <suffix>
        nodes = {}
        for it in items:
            name = (it.get("name_e") or it.get("name_a") or "").strip()
            mn = it.get("menu") or ""
            if not name and "." in mn:
                nodes[(it["system"], mn.split(".", 1)[1].upper())] = it
        def parent_for(it, depth=0):
            system = it["system"]
            mn = it.get("menu") or ""
            prefix = mn.split(".")[0] if "." in mn else ("REPORTS_MENU" if kind == "REPORT" else "FILES_MENU")
            if prefix.upper() in GROUPS or depth > 3:
                return ensure_group(system, prefix)
            for suffix in (prefix.upper(), re.sub(r"_MENU$", "", prefix.upper())):
                node = nodes.get((system, suffix))
                if node is not None:
                    pid = parent_for(node, depth + 1)
                    return ensure_group(system, "N:" + suffix, node.get("desc_a"), node.get("desc_e"), parent=pid, seq=node.get("tree") or 500)
            base = ensure_group(system, "REPORTS_MENU" if kind == "REPORT" else "FILES_MENU")
            return ensure_group(system, prefix, parent=base)
        return parent_for

    fparent = attach(data["files"], "FORM")
    seen_form_rows = set()
    for f in data["files"]:
        name = (f["name_e"] or f["name_a"] or "").strip().upper()
        if f["status"] != 1 or not name or f["system"] not in sys_ids: continue
        s = specs_by_form.get(name)
        if not s: continue
        rows.append(dict(id=3_000_000 + f["system"] * 1000 + f["serial"], parent_id=fparent(f), seq=f["tree"] or 9000 + f["serial"],
                         label_a=f["desc_a"], label_e=f["desc_e"], kind="FORM", page_id=s["page"], system_number=f["system"],
                         file_serial=f["serial"], icon=None))
    generated_reports = {r["page"] for r in data.get("report_pages", []) if r.get("generated")}
    rparent = attach(data["reports"], "REPORT")
    for r in data.get("report_pages", []):
        if r["page"] not in generated_reports or r["system"] not in sys_ids: continue
        rows.append(dict(id=4_000_000 + r["system"] * 1000 + r["serial"], parent_id=rparent(r), seq=r["tree"] or 90000 + r["serial"],
                         label_a=r["desc_a"], label_e=r["desc_e"], kind="REPORT", page_id=r["page"], system_number=r["system"],
                         file_serial=r["serial"], icon=None))
    # drop empty groups (repeat for nesting)
    for _ in range(4):
        used = {r["parent_id"] for r in rows}
        rows = [r for r in rows if r["kind"] not in ("GROUP",) or r["id"] in used]
    return rows


def audit_expr(col, ctype):
    n = col
    if re.search(r"_DATE$|_TIME$|TIMESTAMP$", n):
        return "sysdate" if ctype == "DATE" else ("systimestamp" if ctype.startswith("TIMESTAMP") else "to_char(sysdate,'YYYY-MM-DD HH24:MI:SS')")
    if re.search(r"USER_CODE$|USERS_CODE$|_USER$", n):
        return "to_number(v('G_USER_CODE'))" if ctype == "NUMBER" else "v('G_USER_CODE')"
    if n.endswith("COMPANY_CODE"):
        return "to_number(v('G_COMPANY_CODE'))" if ctype == "NUMBER" else "v('G_COMPANY_CODE')"
    if n.endswith("PASSWORD_NUMBER"):
        return "to_number(v('G_PASSWORD_NUMBER'))" if ctype == "NUMBER" else "v('G_PASSWORD_NUMBER')"
    return None


def trigger_sql(meta, table, key_exprs=None, row_rules=None):
    """key_exprs: {COLUMN: plsql expression} from reviewed rules; replaces the generic max+1 numbering.
    row_rules: PL/SQL statements (may use inserting/updating/:new/:old) appended for APEX sessions."""
    t = meta[table]
    if t["kind"] != "TABLE": return None
    cols = {c["name"]: c for c in t["cols"]}
    # reviewed rules written for another version of the product may use columns this installation lacks
    key_exprs = {k: v for k, v in (key_exprs or {}).items()
                 if k.upper() in cols and degrade.rule_refs_ok(table, cols, f":new.{k} := {v}", f"key rule for {k}")}
    row_rules = [r for r in (row_rules or []) if degrade.rule_refs_ok(table, cols, r, "row rule")]
    ins, upd = [], []
    for c in t["cols"]:
        n = c["name"]
        if re.match(r"^(CREATE|INSERT)_", n) or n == "TIMESTAMP":
            e = audit_expr(n, c["type"])
            if e: ins.append(f"      :new.{n} := nvl(:new.{n}, {e});")
        elif re.match(r"^(UPDATE|MODIFY|LAST_UPDATE)_", n):
            e = audit_expr(n, c["type"])
            if e:
                upd.append(f"      :new.{n} := {e};")
                ins.append(f"      :new.{n} := nvl(:new.{n}, {e});")
        elif n == "COMPANY_CODE" and not c["nullable"]:
            ins.append(f"      :new.{n} := nvl(:new.{n}, to_number(v('G_COMPANY_CODE')));")
    key = []
    pk = t["pk"]
    import specs as S
    for col, expr in key_exprs.items():
        key.append(f"      if :new.{col} is null then\n        :new.{col} := {expr};\n      end if;")
    if S.auto_key(t) and pk[-1] not in key_exprs:
        last = pk[-1]; others = pk[:-1]
        where = " and ".join(f"{o} = :new.{o}" for o in others)
        key.append(f"      if :new.{last} is null then\n"
                   f"        select nvl(max({last}), 0) + 1 into :new.{last} from {table}{' where ' + where if where else ''};\n"
                   f"      end if;")
    if not (ins or upd or key or row_rules):
        return None
    name = ("APPX_" + table)[:128]
    body = [f'create or replace trigger "{name}"', f"before insert or update on {table} for each row",
            "-- generated by app/gen/build.py: audit columns, keys and reviewed row rules for rows written from the APEX application",
            "begin", "  if v('APP_ID') is not null then", "    if inserting then"]
    body += ins + key + ["      null;", "    end if;", "    if updating then"] + upd + ["      null;", "    end if;"]
    for r in (row_rules or []):
        body += ["    -- reviewed rule", "    " + r.strip().replace("\n", "\n    ")]
    body += ["  end if;", "end;", "/"]
    return "\n".join(body)


def order_legacy_triggers(tables):
    """Make legacy BEFORE-ROW insert/update triggers FOLLOW the generated APPX_<table> trigger, so reviewed row rules
    (keys, derived values) run first — Oracle does not guarantee firing order otherwise."""
    c = connect(); cur = c.cursor()
    cur.execute("begin dbms_metadata.set_transform_param(dbms_metadata.session_transform, 'SQLTERMINATOR', false); end;")
    changed = 0
    for t in sorted(tables):
        appx = ("APPX_" + t)[:128]
        cur.execute("""select count(*) from user_triggers t join user_objects o on o.object_name = t.trigger_name and o.object_type = 'TRIGGER'
                        where t.trigger_name = :1 and t.status = 'ENABLED' and o.status = 'VALID'""", [appx])
        if not cur.fetchone()[0]: continue
        cur.execute("""select trigger_name, status from user_triggers where table_name = :1 and trigger_name <> :2
                        and trigger_type = 'BEFORE EACH ROW' and (triggering_event like '%INSERT%' or triggering_event like '%UPDATE%')""", [t, appx])
        for name, status in cur.fetchall():
            c2 = c.cursor()
            c2.execute("select dbms_metadata.get_ddl('TRIGGER', :1) from dual", [name])
            ddl = c2.fetchone()[0].read()
            if re.search(r"\bFOLLOWS\b", ddl, re.I): continue
            ddl = re.split(r"\n\s*ALTER TRIGGER ", ddl)[0].strip()
            new = re.sub(r"(?i)(\bFOR\s+EACH\s+ROW\b)", r'\1' + f'\n  FOLLOWS "{appx}"', ddl, count=1)
            if new == ddl: continue
            try:
                c2.execute(new)
                if status == "DISABLED": c2.execute(f'alter trigger "{name}" disable')
                changed += 1
            except Exception as e:
                print("   could not order", name, str(e)[:120])
    print("legacy triggers ordered after APPX:", changed)


def drop_stale_appx(keep):
    """APPX_<table> triggers of tables the application no longer writes to (or with nothing left to do) are dropped; legacy
    triggers ordered after them (FOLLOWS) are re-created without that clause first."""
    c = connect(); cur = c.cursor()
    cur.execute("begin dbms_metadata.set_transform_param(dbms_metadata.session_transform, 'SQLTERMINATOR', false); end;")
    cur.execute(r"select trigger_name from user_triggers where trigger_name like 'APPX\_%' escape '\'")
    dropped = []
    for (name,) in cur.fetchall():
        if name in keep: continue
        c2 = c.cursor()
        c2.execute("select trigger_name from user_trigger_ordering where referenced_trigger_name = :1", [name])
        for (dep,) in c2.fetchall():
            c3 = c.cursor()
            c3.execute("select status from user_triggers where trigger_name = :1", [dep])
            status = c3.fetchone()[0]
            c3.execute("select dbms_metadata.get_ddl('TRIGGER', :1) from dual", [dep])
            ddl = re.split(r"\n\s*ALTER TRIGGER ", c3.fetchone()[0].read())[0].strip()
            c3.execute(re.sub(r'(?i)\s*FOLLOWS\s+("?[\w$#]+"?\.)?"?' + re.escape(name) + r'"?', "", ddl, count=1))
            if status == "DISABLED": c3.execute(f'alter trigger "{dep}" disable')
        c2.execute(f'drop trigger "{name}"')
        dropped.append(name)
    print("stale APPX triggers dropped:", dropped)


def runsql(path):
    """Run a SQL file as the client's schema (SQL*Plus, UTF-8); returns the error lines only."""
    return subprocess.run(["powershell", "-NoProfile", "-File", os.path.join(APPDIR, "tools", "runsql.ps1"), path, "-User", mp.SCHEMA,
                           "-Dsn", mp.DSN, "-Quiet"], capture_output=True, text=True, encoding="utf-8", errors="replace")


def db_scripts():
    """DB code, in order: engine core (01 core, 02 ui, 03 print, 04 rdf), the product knowledge packages (20_* processes and
    rules, reviewed once for the product) and the client's own packages (overlay/db, same name replaces the product one).
    {{CUSTOMER_CODE}} in a script is replaced by the client's legacy installation code."""
    import glob
    core = sorted(glob.glob(os.path.join(APPDIR, "db", "0[0-9]_*.sql")))
    know = [p for _, p in sorted(mp.kfiles("db", "*.sql").items())]
    for src in core + know:
        path = src
        text = io.open(src, encoding="utf-8").read()
        if "{{CUSTOMER_CODE}}" in text:                            # templated: write the client's copy under work/db
            path = mp.work("db", os.path.basename(src))
            io.open(path, "w", encoding="utf-8", newline="\n").write(text.replace("{{CUSTOMER_CODE}}", mp.CUSTOMER_CODE or "NONE"))
        out = runsql(path)
        errs = [l for l in out.stdout.splitlines() if l.strip() and "ORA-00955" not in l and "ERROR at line 1" not in l and "No errors" not in l
                and "ORA-01430" not in l and "ORA-02260" not in l and "ORA-01408" not in l]
        print(f"  {os.path.basename(path):28} {'ok' if not errs else 'CHECK: ' + ' | '.join(errs[:3])}")


def rdf_prints():
    """Exact document prints: compile the legacy reports named in legacy/prints.json (rdfprint.py) and load the renderer script."""
    import rdfprint
    names = set()
    for k, v in mp.kjson("prints.json").items():
        if k.startswith("_"): continue
        for kd in [v] + list(v.get("more") or []):                 # main print and the further print buttons, per module folder
            for key in ("rdf", "rdf_e"):
                if kd.get(key):
                    names.add((kd[key], kd.get("rdf_module")))
    c = connect(); cur = c.cursor()
    for n, mod in sorted(names, key=lambda x: (x[0], x[1] or "")):
        try:
            r = rdfprint.compile_rdf(rdfprint.find_rdf(n, mod)); rdfprint.write(r); errs = rdfprint.load(r, cur)
            print(f"  print  {r['id']:28} {'ok' if not (errs or r['problems']) else 'CHECK: ' + ' | '.join((r['problems'] + errs)[:3])}")
        except Exception as e:
            print(f"  print  {n:28} FAILED: {e}")
    # the report pages' RDFs ("print in the original design")
    rp = mp.work("out", "reports.json")
    paths = sorted({r["rdf_path"] for r in json.load(io.open(rp, encoding="utf-8")) if r.get("ok") and r.get("rdf_path")}) if os.path.exists(rp) else []
    comp, nerr = {}, 0
    for p in paths:
        full = p if os.path.isabs(p) else os.path.join(mp.SOURCES, p)
        try:
            r = rdfprint.compile_rdf(full); rdfprint.write(r); errs = rdfprint.load(r, cur)
            comp[r["id"]] = {"file": p, "problems": r["problems"], "errors": errs[:10]}
            nerr += bool(errs)
        except Exception as e:
            comp[os.path.basename(p)] = {"file": p, "exception": str(e)[:500]}; nerr += 1
    json.dump(comp, io.open(mp.work("build", "rdf_reports.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"  report RDFs compiled: {len(comp)}, with compile errors: {nerr}")
    js = io.open(os.path.join(APPDIR, "static", "rdfprint.js"), encoding="utf-8").read()
    cur.execute("delete from app_rdf_asset where name = 'rdfprint.js'")
    cur.setinputsizes(js=oracledb.DB_TYPE_CLOB)
    cur.execute("insert into app_rdf_asset (name, content, loaded_on) values ('rdfprint.js', :js, sysdate)", js=js)
    c.commit()


def db(data):
    db_scripts()
    rdf_prints()
    meta = json.load(io.open(mp.work("cache", "meta.json"), encoding="utf-8"))
    c = connect(); cur = c.cursor()
    cur.execute("delete from app_page_serials"); cur.execute("delete from app_page_map"); cur.execute("delete from app_menu")
    pm, ps = [], []
    for s in data["specs"]:
        notes = "; ".join(s["notes"])[:3900] or None
        pm.append([s["page"], "PROCESS" if s["pattern"] == "PROCESS" else "FORM", s["form"], s["system"], s["serial"], s["pattern"],
                   s["title_a"], s["title_e"], None, "MANUAL" if s["pattern"] == "PROCESS" else "GENERATED", notes])
        if s.get("form_page"):
            pm.append([s["form_page"], "FORMPAGE", s["form"], s["system"], s["serial"], s["pattern"], s["title_a"], s["title_e"], s["page"], "GENERATED", None])
            if s["pattern"] == "MASTER_DETAIL" or s.get("print_rdf"):
                pm.append([s["form_page"] + 1, "FORMPAGE", s["form"], s["system"], s["serial"], "PRINT", s["title_a"], s["title_e"], s["page"], "GENERATED", None])
        elif s.get("print_rdf"):                                 # grid / process screen printing its legacy list report
            pm.append([s["page"] + 2, "FORMPAGE", s["form"], s["system"], s["serial"], "PRINT", s["title_a"], s["title_e"], s["page"], "GENERATED", None])
        for e in s["entries"]:
            ps.append([s["page"], e["system"], e["serial"]])
    for r in data.get("report_pages", []):
        if r.get("generated"):
            rg = next((x for x in data["reports_gen"] if x["page"] == r["page"]), {})
            pm.append([r["page"], "REPORT", (r.get("name_e") or r.get("name_a") or "").upper(), r["system"], r["serial"], "REPORT",
                       r["desc_a"], r["desc_e"], None, "GENERATED" if r.get("ok") else "MANUAL",
                       ("; ".join(rg.get("notes", [])))[:3900] or None])
    cur.executemany("insert into app_page_map (page_id, kind, form_name, system_number, file_serial, pattern, title_a, title_e, parent_page_id, status, notes) "
                    "values (:1,:2,:3,:4,:5,:6,:7,:8,:9,:10,:11)", pm)
    cur.executemany("insert into app_page_serials values (:1,:2,:3)", list({tuple(x) for x in ps}))
    menu = build_menu(data)
    cur.executemany("insert into app_menu (id, parent_id, seq, label_a, label_e, kind, page_id, item_values, system_number, file_serial, icon) "
                    "values (:id, :parent_id, :seq, :label_a, :label_e, :kind, :page_id, null, :system_number, :file_serial, :icon)", menu)
    c.commit()
    print("page map", len(pm), "serials", len(ps), "menu rows", len(menu))
    # triggers for every table the generated pages write to
    tables = set()
    key_exprs = collections.defaultdict(dict)
    for s in data["specs"]:
        for b in ([s["master"]] if s.get("master") else []) + s.get("details", []):
            if b.get("insert", True) or b.get("update", True):
                tables.add(b["table"])
        for tcol, expr in ((s.get("rules") or {}).get("key_expr") or {}).items():
            tb, col = tcol.upper().split(".", 1)
            key_exprs[tb][col] = expr; tables.add(tb)
    row_rules = collections.defaultdict(list)
    for s in data["specs"]:
        for tb, code in ((s.get("rules") or {}).get("row_rules") or {}).items():
            if code not in row_rules[tb.upper()]:
                row_rules[tb.upper()].append(code); tables.add(tb.upper())
    gen = {t: trigger_sql(meta, t, key_exprs.get(t), row_rules.get(t)) for t in sorted(tables)}
    sqls = [x for x in gen.values() if x]
    drop_stale_appx({("APPX_" + t)[:128] for t, x in gen.items() if x})
    path = mp.work("db", "10_generated_triggers.sql")
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("-- generated: audit/key triggers for tables written by the APEX application\nset define off\n\n")
        fh.write("\n\n".join(sqls) + "\n")
    out = runsql(path)
    print("triggers", len(sqls), "errors:" if out.stdout.strip() else "ok", out.stdout.strip()[:2000])
    # a generated trigger that still does not compile would invalidate the legacy triggers ordered after it: drop it
    c = connect(); cur = c.cursor()
    cur.execute(r"""select o.object_name, (select min(text) from user_errors e where e.name = o.object_name and e.type = 'TRIGGER')
                     from user_objects o where o.object_type = 'TRIGGER' and o.status = 'INVALID' and o.object_name like 'APPX\_%' escape '\'""")
    bad = dict(cur.fetchall())
    if bad:
        drop_stale_appx({("APPX_" + t)[:128] for t, x in gen.items() if x} - set(bad))
        degrade.LOG["dropped_triggers"] += [f"{n}: {e}" for n, e in bad.items()]
    order_legacy_triggers(set(key_exprs) | set(row_rules))
    # re-creating APPX_<table> invalidates the legacy triggers that FOLLOW it: recompile everything left invalid
    c = connect(); cur = c.cursor()
    cur.execute("alter session set nls_length_semantics = CHAR")
    cur.execute("begin dbms_utility.compile_schema(schema => user, compile_all => false); end;")
    degrade.isolate_members(cur)                     # knowledge packages that do not fit: switch off only the failing members
    cur.execute("begin dbms_utility.compile_schema(schema => user, compile_all => false); end;")
    cur.execute("select object_type || ' ' || object_name from user_objects where status = 'INVALID' order by 1")
    print("invalid objects after recompile:", [r[0] for r in cur.fetchall()])
    degrade.save()


# =========================================================================== APEX side
STATIC = ["application/set_environment.sql", "application/delete_application.sql", "application/end_environment.sql",
          "application/plugin_settings.sql", "application/deployment/definition.sql", "application/deployment/checks.sql",
          "application/deployment/buildoptions.sql", "application/pages/page_groups.sql", "application/pages/page_00000.sql",
          "application/shared_components/navigation/listentry.sql", "application/shared_components/navigation/navigation_bar.sql",
          "application/shared_components/navigation/breadcrumbentry.sql", "application/shared_components/navigation/breadcrumbs/breadcrumb.sql",
          "application/shared_components/navigation/tabs/standard.sql", "application/shared_components/navigation/tabs/parent.sql",
          "application/shared_components/logic/application_settings.sql", "application/shared_components/logic/build_options.sql",
          "application/shared_components/globalization/language.sql", "application/shared_components/globalization/messages.sql",
          "application/shared_components/globalization/dyntranslations.sql",
          "application/shared_components/user_interface/templates/popuplov.sql", "application/shared_components/user_interface/themes.sql",
          "application/shared_components/user_interface/theme_style.sql", "application/shared_components/user_interface/theme_files.sql",
          "application/shared_components/user_interface/template_opt_groups.sql",
          "application/shared_components/user_interface/template_options.sql", "application/user_interfaces/combined_files.sql"]


REF_WS, REF_APP, REF_OWNER = 1600195100832328, 100, "SMART"      # identity of the reference export (engine/export/f100)


def retarget(text):
    """Point a reference-export file at the client's workspace, application id, parsing schema, name and alias."""
    text = text.replace(f"p_default_workspace_id=>{REF_WS}", f"p_default_workspace_id=>{G.WS_ID}")
    text = text.replace(f"p_default_application_id=>{REF_APP}", f"p_default_application_id=>{G.APP_ID}")
    text = text.replace(f"p_default_owner=>'{REF_OWNER}'", f"p_default_owner=>'{G.OWNER}'")
    text = text.replace(f"p_owner=>nvl(wwv_flow_application_install.get_schema,'{REF_OWNER}')",
                        f"p_owner=>nvl(wwv_flow_application_install.get_schema,'{G.OWNER}')")
    text = text.replace("p_name=>nvl(wwv_flow_application_install.get_application_name,'ASCON ERP')",
                        f"p_name=>nvl(wwv_flow_application_install.get_application_name,{G.q(mp.APP_NAME)})")
    text = text.replace("p_alias=>nvl(wwv_flow_application_install.get_application_alias,'ASCON-ERP')",
                        f"p_alias=>nvl(wwv_flow_application_install.get_application_alias,{G.q(mp.APP_ALIAS.upper())})")
    return text


def copy_ref(rel):
    dst = os.path.join(G.BUILD, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    text = io.open(os.path.join(G.REF, rel.replace("/", os.sep)), encoding="utf-8").read()
    io.open(dst, "w", encoding="utf-8", newline="\n").write(retarget(text))


def app_files():
    files = []
    for rel in STATIC:
        copy_ref(rel)
    for f in sorted(os.listdir(os.path.join(G.REF, "application", "shared_components", "files"))):
        rel = "application/shared_components/files/" + f
        copy_ref(rel)
        files.append(rel)
    return files


def gen_create_application():
    ref = retarget(io.open(os.path.join(G.REF, "application", "create_application.sql"), encoding="utf-8").read())
    ref = ref.replace("p_flow_language=>'en'", "p_flow_language=>'ar'")
    ref = ref.replace("p_flow_language_derived_from=>'FLOW_PRIMARY_LANGUAGE'", "p_flow_language_derived_from=>'SESSION'")
    ref = re.sub(r"p_authentication_id=>wwv_flow_imp\.id\(\d+\)", f"p_authentication_id=>wwv_flow_imp.id({G.AUTHN})", ref)
    ref = ref.replace("p_date_format=>'DS'", "p_date_format=>'DD/MM/YYYY'").replace("p_timestamp_format=>'DS'", "p_timestamp_format=>'DD/MM/YYYY HH24:MI'")
    ref = ref.replace("p_logo_text=>'ASCON ERP'", "p_logo_text=>'أسكون ERP'")
    ref = ref.replace("p_is_pwa=>'Y'", "p_is_pwa=>'N'")
    ref = ref.replace(",p_pwa_is_installable=>'N'\n", "").replace(",p_pwa_is_push_enabled=>'N'\n", "")
    ref = ref.replace("p_allow_feedback_yn=>'Y'", "p_allow_feedback_yn=>'N'\n,p_error_handling_function=>'app_ui.handle_error'")
    ref = ref.replace("p_flow_version=>'Release 1.0'", "p_flow_version=>'Release 1.0 (generated)'")
    p = os.path.join(G.BUILD, "application", "create_application.sql")
    io.open(p, "w", encoding="utf-8", newline="\n").write(ref)
    return "application/create_application.sql"


def gen_user_interfaces():
    body = call("wwv_flow_imp_shared.create_user_interface", id=Id(100), theme_id=42,
                home_url="f?p=&APP_ID.:1:&APP_SESSION.::&DEBUG.:::", login_url="f?p=&APP_ID.:LOGIN:&APP_SESSION.::&DEBUG.:::",
                theme_style_by_user_pref=False, built_with_love=False, global_page_id=0, navigation_list_id=Id(G.NAV_LIST),
                navigation_list_position="SIDE", navigation_list_template_id=G.T_SIDE_NAV,
                nav_list_template_options="#DEFAULT#:t-TreeNav--styleA:js-navCollapsed--icons", nav_bar_type="LIST",
                nav_bar_list_id=Id(G.NAVBAR_LIST), nav_bar_list_template_id=G.T_NAVBAR, nav_bar_template_options="#DEFAULT#")
    return write("user_interfaces.sql".join(["application/", ""]), body)


def gen_shared():
    rels = []
    # application items
    body = ""
    for n in ("G_USER_CODE", "G_USER_NAME", "G_USER_NAME_E", "G_PASSWORD_NUMBER", "G_COMPANY_CODE", "G_LANG"):
        body += call("wwv_flow_imp_shared.create_flow_item", id=Id(nid("appitem", n)), name=n, protection_level="I")
    rels.append(write("application/shared_components/logic/application_items.sql", body))
    # application process: force password change after first login with the legacy password
    body = call("wwv_flow_imp_shared.create_flow_process", id=Id(nid("appproc", "pwd")), process_sequence=1, process_point="BEFORE_HEADER",
                process_type="NATIVE_PLSQL", process_name="Force password change",
                process_sql_clob="if :APP_PAGE_ID not in (9998, 9999) and app_sec.must_change then\n"
                                 "  apex_util.redirect_url(p_url => apex_page.get_url(p_page => 9998));\nend if;",
                process_clob_language="PLSQL", security_scheme="MUST_NOT_BE_PUBLIC_USER")
    rels.append(write("application/shared_components/logic/application_processes/force_password_change.sql", body))
    body = call("wwv_flow_imp_shared.create_flow_process", id=Id(nid("appproc", "lang")), process_sequence=0, process_point="BEFORE_HEADER",
                process_type="NATIVE_PLSQL", process_name="Switch language",
                process_sql_clob="if :REQUEST in ('LANG_EN', 'LANG_AR') then\n"
                                 "  apex_util.set_session_lang(case :REQUEST when 'LANG_EN' then 'en' else 'ar' end);\n"
                                 "  apex_util.set_session_state('G_LANG', case :REQUEST when 'LANG_EN' then 'en' else 'ar' end);\n"
                                 "  apex_util.redirect_url(p_url => apex_page.get_url(p_page => :APP_PAGE_ID));\nend if;",
                process_clob_language="PLSQL", security_scheme="MUST_NOT_BE_PUBLIC_USER")
    rels.append(write("application/shared_components/logic/application_processes/switch_language.sql", body))
    body = call("wwv_flow_imp_shared.create_flow_process", id=Id(nid("appproc", "logo")), process_sequence=1, process_point="ON_DEMAND",
                process_type="NATIVE_PLSQL", process_name="COMPANY_LOGO", process_sql_clob="app_print.company_logo;",
                process_clob_language="PLSQL", security_scheme="MUST_NOT_BE_PUBLIC_USER")
    rels.append(write("application/shared_components/logic/application_processes/company_logo.sql", body))
    # authentication
    body = call("wwv_flow_imp_shared.create_authentication", id=Id(G.AUTHN), name="ASCON Users", scheme_type="NATIVE_CUSTOM",
                attribute_03="app_sec.authenticate", attribute_05="N", invalid_session_type="LOGIN",
                post_auth_process="app_sec.post_auth", use_secure_cookie_yn="N", ras_mode=0)
    rels.append(write("application/shared_components/security/authentications/ascon_users.sql", body))
    # authorization schemes
    body = ""
    for sid, name, op, msg in ((G.AZ_PAGE, "PAGE_ACCESS", "Q", "ليس لديك صلاحية لفتح هذه الشاشة"),
                               (G.AZ_INS, "PAGE_INSERT", "I", "ليس لديك صلاحية الإضافة في هذه الشاشة"),
                               (G.AZ_UPD, "PAGE_UPDATE", "U", "ليس لديك صلاحية التعديل في هذه الشاشة"),
                               (G.AZ_DEL, "PAGE_DELETE", "D", "ليس لديك صلاحية الحذف في هذه الشاشة")):
        body += call("wwv_flow_imp_shared.create_security_scheme", id=Id(sid), name=name, scheme_type="NATIVE_FUNCTION_BODY",
                     attribute_01=f"return app_sec.can_page(:APP_PAGE_ID, '{op}');", error_message=msg, caching="BY_USER_BY_PAGE_VIEW")
    body += call("wwv_flow_imp_shared.create_security_scheme", id=Id(G.AZ_ADMIN), name="ADMIN", scheme_type="NATIVE_FUNCTION_BODY",
                 attribute_01="return app_sec.is_admin;", error_message="هذه الشاشة لمدير النظام فقط", caching="BY_USER_BY_SESSION")
    rels.append(write("application/shared_components/security/authorizations/ascon_schemes.sql", body))
    # navigation menu (dynamic, from APP_MENU_V) and navigation bar
    menu_sql = ("select level,\n"
                "       case when app_sec.lang = 'en' then nvl(label_e, label_a) else nvl(label_a, label_e) end label,\n"
                "       case when page_id is not null then 'f?p=&APP_ID.:' || page_id || ':&APP_SESSION.::&DEBUG.:RP::' end target,\n"
                "       case when page_id = :APP_PAGE_ID then 'YES' else 'NO' end is_current_list_entry,\n"
                "       icon image, null image_attribute, null image_alt_attribute\n"
                "  from app_menu_v\n"
                " start with parent_id is null\n"
                "connect by prior id = parent_id\n"
                " order siblings by seq, id")
    body = call("wwv_flow_imp_shared.create_list", id=Id(G.NAV_LIST), name="Navigation Menu", list_type="SQL_QUERY", list_query=menu_sql,
                list_status="PUBLIC")
    rels.append(write("application/shared_components/navigation/lists/navigation_menu.sql", body))
    body = call("wwv_flow_imp_shared.create_list", id=Id(G.NAVBAR_LIST), name="Navigation Bar", list_status="PUBLIC")
    for key, seq, text, req, cond in (("en", 5, "English", "LANG_EN", "ar"), ("ar", 6, "عربي", "LANG_AR", "en")):
        body += call("wwv_flow_imp_shared.create_list_item", id=Id(nid("navbar", "lang", key)), list_item_display_sequence=seq,
                     list_item_link_text=text, list_item_link_target=f"f?p=&APP_ID.:&APP_PAGE_ID.:&APP_SESSION.:{req}:&DEBUG.:::",
                     list_item_icon="fa-language", list_item_disp_cond_type="EXPRESSION",
                     list_item_disp_condition=f"app_sec.lang = '{cond}'", list_item_disp_condition2="PLSQL",
                     list_item_current_type="TARGET_PAGE")
    top = nid("navbar", "user")
    body += call("wwv_flow_imp_shared.create_list_item", id=Id(top), list_item_display_sequence=10, list_item_link_text="&G_USER_NAME.",
                 list_item_link_target="#", list_item_icon="fa-user", list_text_02="has-username", list_item_current_type="TARGET_PAGE")
    body += call("wwv_flow_imp_shared.create_list_item", id=Id(nid("navbar", "pwd")), list_item_display_sequence=20,
                 list_item_link_text="تغيير كلمة المرور", list_item_link_target="f?p=&APP_ID.:9998:&APP_SESSION.::&DEBUG.:::",
                 list_item_icon="fa-key", list_item_disp_cond_type="USER_IS_NOT_PUBLIC_USER", parent_list_item_id=Id(top),
                 list_item_current_type="TARGET_PAGE")
    body += call("wwv_flow_imp_shared.create_list_item", id=Id(nid("navbar", "sep")), list_item_display_sequence=30, list_item_link_text="---",
                 list_item_link_target="separator", list_item_disp_cond_type="USER_IS_NOT_PUBLIC_USER", parent_list_item_id=Id(top),
                 list_item_current_type="TARGET_PAGE")
    body += call("wwv_flow_imp_shared.create_list_item", id=Id(nid("navbar", "out")), list_item_display_sequence=40, list_item_link_text="تسجيل الخروج",
                 list_item_link_target="&LOGOUT_URL.", list_item_icon="fa-sign-out", list_item_disp_cond_type="USER_IS_NOT_PUBLIC_USER",
                 parent_list_item_id=Id(top), list_item_current_type="TARGET_PAGE")
    rels.append(write("application/shared_components/navigation/lists/navigation_bar.sql", body))
    return rels


def gen_lovs(lovs):
    rels = []
    for l in lovs:
        disp = (f"case when app_sec.lang = 'en' then nvl({l['disp_e']}, {l['disp_a']}) else {l['disp_a']} end" if l.get("disp_e") else l["disp_a"])
        sql = f"select {l['ret']} || ' - ' || {disp} d, {l['ret']} r\n  from {l['table']}\n order by {l['ret']}"
        body = call("wwv_flow_imp_shared.create_list_of_values", id=Id(G.lov_id(l["name"])), lov_name=l["name"], lov_query=sql,
                    source_type="LEGACY_SQL", location="LOCAL")
        fn = re.sub(r"[^a-z0-9_]+", "_", l["name"].lower())
        rels.append(write(f"application/shared_components/user_interface/lovs/{fn}.sql", body))
    return rels


def gen_core_pages():
    rels = []
    # ---- 1 Home
    body = call("wwv_flow_imp_page.create_page", id=1, name="Home", alias="HOME", step_title="أسكون ERP", autocomplete_on_off="OFF",
                page_template_options="#DEFAULT#", protection_level="C")
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(nid(1, "hero")), plug_name="أسكون ERP",
                 region_template_options="#DEFAULT#", escape_on_http_output="Y", plug_template=G.T_HERO, plug_display_sequence=10,
                 plug_display_point="REGION_POSITION_01", plug_source="مرحباً &G_USER_NAME. - الشركة: &G_COMPANY_CODE.",
                 region_image="#APP_FILES#icons/app-icon-512.png", attributes=attrs(expand_shortcuts="N", output_as="HTML", show_line_breaks="Y"))
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(nid(1, "cards")), plug_name="الأنظمة", region_template_options="#DEFAULT#",
                 plug_template=G.T_STANDARD, plug_display_sequence=20, plug_source="app_ui.home_cards;", plug_source_type="NATIVE_PLSQL",
                 plug_query_options="DERIVED_REPORT_COLUMNS")
    rels.append(write("application/pages/page_00001.sql", body))
    # ---- 9998 change password
    pg = 9998
    body = call("wwv_flow_imp_page.create_page", id=pg, name="Change Password", alias="CHANGE-PASSWORD", step_title="تغيير كلمة المرور",
                autocomplete_on_off="OFF", page_template_options="#DEFAULT#", protection_level="C")
    rid = nid(pg, "r")
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(rid), plug_name="تغيير كلمة المرور", region_template_options="#DEFAULT#:t-Region--scrollBody",
                 plug_template=G.T_STANDARD, plug_display_sequence=10, attributes=attrs(expand_shortcuts="N", output_as="TEXT", show_line_breaks="Y"))
    body += call("wwv_flow_imp_page.create_page_plug", id=Id(nid(pg, "msg")), plug_name="تنبيه", region_template_options="#DEFAULT#:t-Alert--warning:t-Alert--horizontal",
                 plug_template=G.T_BLANK, plug_display_sequence=5,
                 plug_source="يجب اختيار كلمة مرور جديدة (6 أحرف على الأقل) قبل متابعة العمل على النظام الجديد.",
                 plug_display_condition_type="EXPRESSION", plug_display_when_condition="app_sec.must_change", plug_display_when_cond2="PLSQL",
                 attributes=attrs(expand_shortcuts="N", output_as="TEXT", show_line_breaks="Y"))
    for i, (n, lbl) in enumerate((("OLD", "كلمة المرور الحالية"), ("NEW", "كلمة المرور الجديدة"), ("CONFIRM", "تأكيد كلمة المرور"))):
        body += call("wwv_flow_imp_page.create_page_item", id=Id(nid(pg, "i", n)), name=f"P{pg}_{n}", is_required=True, item_sequence=10 * (i + 1),
                     item_plug_id=Id(rid), prompt=lbl, display_as="NATIVE_PASSWORD", cSize=30, cMaxlength=100, label_alignment="RIGHT",
                     field_template=G.T_LABEL_REQ, item_template_options="#DEFAULT#", is_persistent="N", attributes=attrs(submit_when_enter_pressed="N"))
    body += call("wwv_flow_imp_page.create_page_button", id=Id(nid(pg, "b")), button_sequence=10, button_plug_id=Id(rid), button_name="CHANGE",
                 button_action="SUBMIT", button_template_options="#DEFAULT#", button_template_id=G.T_BUTTON, button_is_hot="Y",
                 button_image_alt="حفظ كلمة المرور", button_position="NEXT", button_alignment="RIGHT")
    body += call("wwv_flow_imp_page.create_page_validation", id=Id(nid(pg, "v")), validation_name="تطابق كلمة المرور", validation_sequence=10,
                 validation=f":P{pg}_NEW = :P{pg}_CONFIRM", validation2="PLSQL", validation_type="EXPRESSION",
                 error_message="كلمة المرور الجديدة وتأكيدها غير متطابقين", associated_item=Id(nid(pg, "i", "CONFIRM")),
                 error_display_location="INLINE_WITH_FIELD_AND_NOTIFICATION")
    body += call("wwv_flow_imp_page.create_page_process", id=Id(nid(pg, "p")), process_sequence=10, process_point="AFTER_SUBMIT",
                 process_type="NATIVE_PLSQL", process_name="Change password",
                 process_sql_clob=f"app_sec.change_password(:P{pg}_OLD, :P{pg}_NEW);", process_clob_language="PLSQL",
                 error_display_location="INLINE_IN_NOTIFICATION", process_success_message="تم تغيير كلمة المرور بنجاح",
                 internal_uid=nid(pg, "p") % 10**15)
    body += call("wwv_flow_imp_page.create_page_branch", id=Id(nid(pg, "br")), branch_action="f?p=&APP_ID.:1:&APP_SESSION.::&DEBUG.:::&success_msg=#SUCCESS_MSG#",
                 branch_point="AFTER_PROCESSING", branch_type="REDIRECT_URL", branch_sequence=10)
    rels.append(write("application/pages/page_09998.sql", body))
    # ---- 9999 login (reference login page with Arabic labels)
    ref = retarget(io.open(os.path.join(G.REF, "application", "pages", "page_09999.sql"), encoding="utf-8").read())
    ref = ref.replace("p_step_title=>'ASCON ERP - Log In'", "p_step_title=>'أسكون ERP - تسجيل الدخول'")
    ref = ref.replace("p_prompt=>'Username'\n,p_placeholder=>'Username'", "p_prompt=>'رقم المستخدم'\n,p_placeholder=>'رقم المستخدم'")
    ref = ref.replace("p_prompt=>'Password'\n,p_placeholder=>'Password'", "p_prompt=>'كلمة المرور'\n,p_placeholder=>'كلمة المرور'")
    ref = ref.replace("p_prompt=>'Remember username'", "p_prompt=>'تذكر رقم المستخدم'")
    ref = ref.replace("p_button_image_alt=>'Sign In'", "p_button_image_alt=>'دخول'")
    ref = ref.replace("p_plug_name=>'ASCON ERP'", "p_plug_name=>'أسكون ERP'")
    p = os.path.join(G.BUILD, "application", "pages", "page_09999.sql")
    io.open(p, "w", encoding="utf-8", newline="\n").write(ref)
    rels.append("application/pages/page_09999.sql")
    return rels


def rdf_print_ok():
    """Reports whose legacy RDF compiled into a package without errors and drew without a renderer failure."""
    comp_p = mp.work("build", "rdf_reports.json"); run_p = mp.work("build", "rdf_reports_run.json")
    if not os.path.exists(comp_p):
        return set()
    comp = json.load(io.open(comp_p, encoding="utf-8"))
    ok = {k for k, v in comp.items() if not v.get("errors") and not v.get("exception")}
    if os.path.exists(run_p):
        bad = {v["rdf"] for v in json.load(io.open(run_p, encoding="utf-8")).values() if v.get("status") in ("error", "exception", "not compiled")}
        ok -= bad
    return ok


def apex(data):
    if os.path.exists(G.BUILD):
        shutil.rmtree(G.BUILD)
    os.makedirs(G.BUILD)
    files = app_files()
    create = gen_create_application()
    ui = gen_user_interfaces()
    shared = gen_shared()
    lovs_ok = {l["name"] for l in data["lovs"]}
    lov_rels = gen_lovs(data["lovs"])
    pages = gen_core_pages()
    gen_rels = []
    stats = collections.Counter()
    G.FORM_PAGES.clear()
    G.FORM_PAGES.update({s["form"].upper(): s["form_page"] for s in data["specs"] if s.get("form_page") and s["pattern"] == "MASTER_DETAIL"})
    G.SCREEN_PAGES.clear()
    G.SCREEN_PAGES.update({s["form"].upper(): s["page"] for s in data["specs"] if s.get("page")})
    for s in data["specs"]:
        try:
            out = G.GEN[s["pattern"]](s, lovs_ok)
        except Exception as e:
            print("GEN FAIL", s["form"], repr(e)); stats["fail"] += 1; continue
        for pg, body in out.items():
            gen_rels.append(write(f"application/pages/page_{pg:05d}.sql", body))
        stats[s["pattern"]] += 1
    # reports that print in their legacy design (compiled without errors by rdfprint and drawn by the engine: tools/rdfbatch*.py)
    ok_rdf = rdf_print_ok()
    import rdfprint
    for rs in data["reports_gen"]:
        if rs.get("ok") and rs.get("rdf_path"):
            rid = rdfprint.report_id(rs["rdf_path"])
            if rid in ok_rdf: rs["rdf_id"] = rid
    gen_rels.append(write(f"application/pages/page_{G.RDF_PRINT_PAGE:05d}.sql", G.gen_report_print_page(data["reports_gen"])[G.RDF_PRINT_PAGE]))
    for rs in data["reports_gen"]:
        try:
            out = G.gen_report(rs)
        except Exception as e:
            print("GEN FAIL report", rs["page"], rs.get("rdf"), repr(e)); stats["fail"] += 1; continue
        for pg, body in out.items():
            gen_rels.append(write(f"application/pages/page_{pg:05d}.sql", body))
        stats["REPORT" if rs.get("ok") else "REPORT_MANUAL"] += 1
    order = (["application/set_environment.sql", "application/delete_application.sql", create, ui]
             + [r for r in shared if "lists/" in r]
             + ["application/shared_components/navigation/listentry.sql"] + files
             + ["application/plugin_settings.sql"]
             + [r for r in shared if "authorizations/" in r]
             + [r for r in shared if "application_items" in r]
             + [r for r in shared if "application_processes" in r]
             + ["application/shared_components/navigation/navigation_bar.sql",
                "application/shared_components/logic/application_settings.sql",
                "application/shared_components/navigation/tabs/standard.sql", "application/shared_components/navigation/tabs/parent.sql"]
             + lov_rels
             + ["application/pages/page_groups.sql", "application/shared_components/navigation/breadcrumbs/breadcrumb.sql",
                "application/shared_components/navigation/breadcrumbentry.sql",
                "application/shared_components/user_interface/templates/popuplov.sql",
                "application/shared_components/user_interface/themes.sql", "application/shared_components/user_interface/theme_style.sql",
                "application/shared_components/user_interface/theme_files.sql",
                "application/shared_components/user_interface/template_opt_groups.sql",
                "application/shared_components/user_interface/template_options.sql",
                "application/shared_components/globalization/language.sql", "application/shared_components/logic/build_options.sql",
                "application/shared_components/globalization/messages.sql", "application/shared_components/globalization/dyntranslations.sql"]
             + [r for r in shared if "authentications/" in r]
             + ["application/user_interfaces/combined_files.sql", "application/pages/page_00000.sql"]
             + sorted(pages + gen_rels)
             + ["application/deployment/definition.sql", "application/deployment/checks.sql", "application/deployment/buildoptions.sql",
                "application/end_environment.sql"])
    with io.open(os.path.join(G.BUILD, "install.sql"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("prompt --install\n" + "".join(f"@@{r}\n" for r in order))
    print("apex files written:", dict(stats), "pages", len(gen_rels) + len(pages), "lovs", len(lov_rels))


def install():
    log = mp.work("build", "install.log")
    script = mp.work("build", "run_install.sql")
    io.open(script, "w", encoding="utf-8").write("whenever sqlerror exit failure\nset define off\n"
                                                 f"begin apex_application_install.set_offset({mp.ID_OFFSET}); end;\n/\n"
                                                 "@install.sql\n")
    env = dict(os.environ, NLS_LANG="AMERICAN_AMERICA.AL32UTF8", JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8")
    r = subprocess.run(["powershell", "-NoProfile", "-File", os.path.join(APPDIR, "tools", "sqlcl.ps1"), "-User", mp.SCHEMA,
                        "-Dsn", mp.DSN, "-File", script, "-WorkDir", G.BUILD], capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    io.open(log, "w", encoding="utf-8").write(r.stdout + "\n" + r.stderr)
    tail = (r.stdout + r.stderr).strip().splitlines()
    errs = [l for l in tail if re.search(r"ORA-|PLS-|Error|error|SEVERE", l)]
    print("install exit", r.returncode, "| last lines:", " / ".join(tail[-3:]))
    for e in errs[:25]: print("   ", e)
    return r.returncode or (1 if any(re.search(r"ORA-\d{5}", l) for l in tail) else 0)   # SQLcl can exit 0 after an error


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    data = load()
    if what in ("db", "all"): db(data)
    if what in ("apex", "all"): apex(data)
    if what in ("install", "all"):
        rc = install()
        if rc == 0 and what == "all":
            import translate; translate.run()
        sys.exit(rc)
    if what == "translate":
        import translate; translate.run()
