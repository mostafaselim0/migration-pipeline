"""Run every report page's RDF through the print engine (APP_RDF + rdfprint.js) with the page's default parameters
(date ranges: 1 January of this year .. today) and record the outcome.
  python rdfbatch_run.py [--only RDF,...] [--shots]   ->  app/build/rdf_reports_run.json  (+ app/build/rdftest/rep_<RDF>.png)"""
import os, sys, io, re, json, time, argparse, datetime
HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
sys.path.insert(0, APP); import mp
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(APP, "gen"))
from db import connect
import oracledb, rdfprint

OUT = mp.work("build", "rdftest")
DATE_FROM_RE = re.compile(r"(^|_)(FROM|FRM|F|START|BEGIN|D1|DATE1|FDATE|FR)(_|$)|FROM_?DATE|DATE_?FROM|^D1$|^P_D1$", re.I)
DATE_TO_RE = re.compile(r"(^|_)(TO|END|D2|DATE2|TDATE)(_|$)|TO_?DATE|DATE_?TO|^D2$|^P_D2$", re.I)


def params_for(rs, model):
    today = datetime.date.today(); jan1 = today.replace(month=1, day=1)
    vals = {}
    types = {p["n"]: p["t"] for p in model["params"]}
    for it in rs["items"]:
        b = it["bind"].upper()
        role = it["role"]
        if role == "LANG": vals[b] = "A"
        elif role == "COMPANY": vals[b] = "1"
        elif role == "GROUP": vals[b] = "0"
        elif role == "USER": vals[b] = "0"
        elif it.get("initial") not in (None, ""): vals[b] = it["initial"]
    for n, t in types.items():
        if n in vals: continue
        if t == "D" or re.search(r"DATE|^D[12]$", n):
            if DATE_TO_RE.search(n): vals[n] = today.strftime("%d/%m/%Y")
            elif DATE_FROM_RE.search(n): vals[n] = jan1.strftime("%d/%m/%Y")
    std = {"LANG": "A", "COMP_CODE": "1", "P_COMPANY": "1", "P_USERS_CODE": "0", "P_PASSWORD_NUMBER": "0", "PASSWORD_NUMBER": "0"}
    for k, v in std.items(): vals.setdefault(k, v)
    return chr(30).join(f"{k}={v}" for k, v in vals.items())


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--only"); ap.add_argument("--shots", action="store_true")
    ap.add_argument("--timeout", type=int, default=90, help="seconds per report (database)")
    a = ap.parse_args()
    reps = [r for r in json.load(io.open(mp.work("out", "reports.json"), encoding="utf-8")) if r.get("ok")]
    if a.only:
        want = {x.strip().upper() for x in a.only.split(",")}
        reps = [r for r in reps if rdfprint.report_id(r["rdf_path"]) in want]
    c = connect(); c.call_timeout = a.timeout * 1000; cur = c.cursor()
    js = io.open(os.path.join(APP, "static", "rdfprint.js"), encoding="utf-8").read()
    out_p = mp.work("build", "rdf_reports_run.json")
    results = json.load(io.open(out_p, encoding="utf-8")) if os.path.exists(out_p) and a.only else {}
    os.makedirs(OUT, exist_ok=True)
    from playwright.sync_api import sync_playwright
    with sync_playwright() as pw:
        b = pw.chromium.launch(channel="msedge")
        pg = b.new_page(viewport={"width": 1250, "height": 1000})
        errs = []
        pg.on("pageerror", lambda e: errs.append(str(e)[:300]))
        for i, rs in enumerate(reps):
            rid = rdfprint.report_id(rs["rdf_path"])
            key = f"{rs['page']}"
            res = {"rdf": rid, "page": rs["page"], "title": rs.get("title_a")}
            try:
                cur.execute("select model, layout from app_rdf_report where name = :1", [rid])
                row = cur.fetchone()
                if not row:
                    res["status"] = "not compiled"; results[key] = res; continue
                model = json.loads(row[0].read()); layout = row[1].read()
                params = params_for(rs, model)
                res["params"] = params.replace(chr(30), " | ")
                t0 = time.time()
                outv = cur.var(oracledb.DB_TYPE_CLOB)
                cur.execute("begin :r := app_rdf.data_json(:rep, :par); end;", r=outv, rep=rid, par=params)
                data = outv.getvalue().read()
                res["db_seconds"] = round(time.time() - t0, 2); res["json_kb"] = len(data) // 1024
                d = json.loads(data)
                res["data_errors"] = (d.get("errors") or "").strip()[:1500]
                html = (f'<!doctype html><html lang="ar"><head><meta charset="utf-8"></head><body style="margin:0"><div id="r1"></div>'
                        f'<script type="application/json" id="r1_layout">{layout.replace("</", "<\\/")}</script>'
                        f'<script type="application/json" id="r1_data">{data.replace("</", "<\\/")}</script><script>{js}</script></body></html>')
                p = os.path.join(OUT, f"rep_{rid}.html")
                io.open(p, "w", encoding="utf-8").write(html)
                errs.clear()
                pg.goto("file:///" + p.replace("\\", "/"), timeout=120000)
                t1 = time.time()
                r = pg.evaluate("() => { try { return String(rdfPrint.render('r1')); } catch (e) { return 'ERR ' + e.message + ' ' + (e.stack || '').slice(0, 300); } }")
                res["render_seconds"] = round(time.time() - t1, 2)
                res["pages"] = r
                res["js_errors"] = errs[:3]
                if a.shots and not str(r).startswith("ERR"):
                    pg.screenshot(path=os.path.join(OUT, f"rep_{rid}.png"), clip={"x": 0, "y": 0, "width": 1250, "height": 1700}, timeout=60000)
                res["status"] = "error" if (str(r).startswith("ERR") or errs) else ("data errors" if res["data_errors"] else "ok")
            except Exception as e:
                res["status"] = "exception"; res["exception"] = str(e)[:500]
                try: c.rollback()
                except Exception: pass
            results[key] = res
            if i % 10 == 0:
                print(f"{i + 1}/{len(reps)} {rid} {res.get('status')} {res.get('pages')} db {res.get('db_seconds')}s", flush=True)
                json.dump(results, io.open(out_p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        b.close()
    json.dump(results, io.open(out_p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    import collections
    print(collections.Counter(v.get("status") for v in results.values()))


if __name__ == "__main__":
    main()
