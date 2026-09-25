"""Compile every report RDF of the application's report pages with rdfprint (package + model + layout into APP_RDF_REPORT) and
list the problems per report.  python rdfbatch.py [--only NAME,...]  ->  app/build/rdf_reports.json"""
import os, sys, io, json, time, argparse, traceback
HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
sys.path.insert(0, APP); import mp
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(APP, "gen"))
from db import connect
import rdfprint


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--only")
    a = ap.parse_args()
    reps = json.load(io.open(mp.work("out", "reports.json"), encoding="utf-8"))
    names = sorted({r["rdf_path"] for r in reps if r.get("ok") and r.get("rdf_path")})
    if a.only:
        want = {x.strip().upper() for x in a.only.split(",")}
        names = [n for n in names if rdfprint.report_id(n) in want]
    c = connect(); cur = c.cursor()
    out_p = mp.work("build", "rdf_reports.json")
    results = json.load(io.open(out_p, encoding="utf-8")) if os.path.exists(out_p) and a.only else {}
    t0 = time.time()
    for i, path in enumerate(names):
        full = path if os.path.isabs(path) else os.path.join(mp.SOURCES, path)
        try:
            r = rdfprint.compile_rdf(full); rdfprint.write(r); errs = rdfprint.load(r, cur)
            results[r["id"]] = {"file": path, "problems": r["problems"], "errors": errs[:10],
                                "features": sorted(set(o for o in feature_list(r["layout"])))}
        except Exception as e:
            results[os.path.basename(path)] = {"file": path, "exception": traceback.format_exc()[-600:]}
        if i % 20 == 0:
            print(f"{i + 1}/{len(names)} {time.time() - t0:.0f}s")
    json.dump(results, io.open(out_p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    bad = {k: v for k, v in results.items() if v.get("errors") or v.get("exception") or v.get("problems")}
    print(f"compiled {len(results)}, with problems {len(bad)} -> {out_p}")


def feature_list(layout):
    def walk(objs):
        for o in objs or []:
            yield o["k"]
            if o.get("po"): yield "po:" + o["po"]
            if o.get("ve"): yield "ve:" + o["ve"]
            if o["k"] == "rf" and o.get("dir") != "down": yield "dir:" + o.get("dir", "")
            yield from walk(o.get("ch"))
    for s in layout["sections"].values():
        yield from walk(s.get("objs")); yield from walk(s.get("margin"))


if __name__ == "__main__":
    main()
