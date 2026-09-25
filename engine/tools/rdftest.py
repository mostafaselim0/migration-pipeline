"""Offline check of an exact print (legacy/prints.json): compile + load the RDF, fill its parameters from a real document the way
the generated print page does, run APP_RDF and draw the pages in Edge (PNG + PDF).

  python rdftest.py FORM [--kind KEY] [--where "trns_type_code = 10301 and trns_serial = 626" | --rowid R | --latest]
                         [--lang A|E] [--out NAME] [--no-compile]
  python rdftest.py --rdf NAME --params "P_X=1;P_Y=2" [--out NAME]      (any report, parameters typed by hand)

Output: app/build/rdftest/<NAME>.png / .pdf / .html and a summary line (pages, data errors, runtime messages)."""
import os, sys, io, re, json, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
sys.path.insert(0, APP); import mp
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(APP, "gen"))
from db import connect
import oracledb
import rdfprint

OUT = mp.work("build", "rdftest")


def kinds(pr):
    out = [dict(pr, key="MAIN")]
    for k, extra in enumerate(pr.get("more") or []):
        out.append(dict(extra, key=(extra.get("key") or f"K{k + 1}").upper()))
    return out


def doc_params(cur, table, pr, rowid, lang, system):
    cur.execute("select column_name, data_type from user_tab_columns where table_name = :1", [table])
    cols = dict(cur.fetchall())
    parts = []
    for name, src in (pr.get("params") or {}).items():
        src = src.strip()
        if re.fullmatch(r"[A-Za-z][A-Za-z0-9_$#]*", src):
            if src.upper() not in cols:
                print(f"  parameter {name}: column {src} not in {table} (skipped)"); continue
            expr = f"to_char(t.{src}, 'DD-MM-YYYY')" if cols[src.upper()] == "DATE" else f"t.{src}"
        else:
            expr = src
        parts.append(f"'{name.upper()}=' || replace({expr}, chr(30), ' ')")
    cur.execute(f"select {' || chr(30) || '.join(parts) if parts else 'null'} from {table} t where rowid = :1", [rowid])
    p = cur.fetchone()[0] or ""
    std = {"LANG": lang, "COMP_CODE": "1", "P_COMPANY": "1", "P_USERS_CODE": "0", "USERS_CODE": "0", "P_USER": "0", "P_PRIN_USER": "0",
           "P_PASSWORD_NUMBER": "0", "PASSWORD_NUMBER": "0", "P_SYSTEM_NUMBER": str(system or "")}
    given = {n.upper() for n in (pr.get("params") or {})}
    return p + "".join(chr(30) + f"{k}={v}" for k, v in std.items() if k not in given)


def render(rid, layout, data, name):
    os.makedirs(OUT, exist_ok=True)
    js = io.open(os.path.join(APP, "static", "rdfprint.js"), encoding="utf-8").read()
    html = (f'<!doctype html><html lang="ar"><head><meta charset="utf-8"><title>{rid}</title></head><body style="margin:0">'
            f'<div id="r1"></div><script type="application/json" id="r1_layout">{layout.replace("</", "<\\/")}</script>'
            f'<script type="application/json" id="r1_data">{data.replace("</", "<\\/")}</script><script>{js}</script>'
            '<script>try { document.title = "pages=" + rdfPrint.render("r1"); } catch (e) { document.title = "ERR " + e.message + " " + e.stack; }</script>'
            '</body></html>')
    p = os.path.join(OUT, name + ".html")
    io.open(p, "w", encoding="utf-8").write(html)
    from playwright.sync_api import sync_playwright
    with sync_playwright() as pw:
        b = pw.chromium.launch(channel="msedge")
        pg = b.new_page(viewport={"width": 1250, "height": 1100}, device_scale_factor=1.25)
        msgs = []
        pg.on("pageerror", lambda e: msgs.append("PAGEERROR " + str(e)))
        pg.goto("file:///" + p.replace("\\", "/"))
        pg.wait_for_timeout(800)
        title = pg.title()
        height = pg.evaluate("() => document.documentElement.scrollHeight")
        pg.screenshot(path=os.path.join(OUT, name + ".png"), clip={"x": 0, "y": 0, "width": 1250, "height": min(height, 14000)})
        pg.pdf(path=os.path.join(OUT, name + ".pdf"), prefer_css_page_size=True, print_background=True)
        b.close()
    return title, msgs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("form", nargs="?")
    ap.add_argument("--kind", default="MAIN"); ap.add_argument("--where"); ap.add_argument("--rowid"); ap.add_argument("--latest", action="store_true")
    ap.add_argument("--lang", default="A"); ap.add_argument("--out"); ap.add_argument("--no-compile", action="store_true")
    ap.add_argument("--rdf"); ap.add_argument("--params")
    a = ap.parse_args()
    c = connect(); cur = c.cursor()
    if a.rdf:
        rdf, params, name = a.rdf, (a.params or "").replace(";", chr(30)), a.out or re.sub(r"\W", "_", a.rdf)
    else:
        pj = mp.kjson("prints.json")
        pr = next(k for k in kinds(pj[a.form.upper()]) if k["key"] == a.kind.upper())
        specs = json.load(io.open(mp.work("out", "specs.json"), encoding="utf-8"))["specs"]
        spec = next(s for s in specs if s["form"].upper() == a.form.upper())
        table = spec["master"]["table"]
        if a.rowid:
            rowid = a.rowid
        else:
            w = a.where or ((spec.get("rules") or {}).get("where") or spec["master"].get("where") or "1 = 1")
            w = w.replace(":G_PASSWORD_NUMBER", "0").replace(":G_USER_CODE", "0").replace(":G_COMPANY_CODE", "1")
            cur.execute(f"select rowid from {table} where {w} order by rowid desc fetch first 1 rows only")
            r = cur.fetchone()
            if not r: sys.exit(f"no document of {a.form} matches: {w}")
            rowid = r[0]
        params = doc_params(cur, table, pr, rowid, a.lang, spec.get("system"))
        rdf = pr["rdf"]; name = a.out or f"{a.form}_{a.kind}".upper()
        print("document", table, rowid, "|", params.replace(chr(30), " | ")[:400])
    res = rdfprint.compile_rdf(rdfprint.find_rdf(rdf, None if a.rdf else pr.get("rdf_module")))
    if not a.no_compile:
        rdfprint.write(res); errs = rdfprint.load(res, cur)
        if errs or res["problems"]: print("compile:", res["problems"], errs[:8])
    out = cur.var(oracledb.DB_TYPE_CLOB)
    cur.execute("begin :r := app_rdf.data_json(:rep, :par); end;", r=out, rep=res["id"], par=params)
    data = out.getvalue().read()
    d = json.loads(data)
    title, msgs = render(res["id"], json.dumps(res["layout"], ensure_ascii=False), data, name)
    print(f"{res['id']}: {title} | data errors: {(d.get('errors') or '').strip()[:500] or 'none'} | messages: {(d.get('messages') or '')[:200] or 'none'}"
          f" | browser: {msgs[:3] or 'ok'} -> {os.path.join(OUT, name)}.png")


if __name__ == "__main__":
    main()
