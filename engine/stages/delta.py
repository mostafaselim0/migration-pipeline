"""Stage delta: what is different about this client compared with the product knowledge?

Compares the client's fingerprints (fingerprint.snapshot) with knowledge/<product>/fingerprints.json and classifies:
   modules   legacy systems (SYS_SYSTEMS) the knowledge has never seen
   screens   SAME (reviewed knowledge applies as is) / CHANGED (layout or logic differs) / NEW (unknown form) / UNVERIFIED
             (nothing comparable: no XML, no .fmx, no labels on one side)
   reports   SAME / CHANGED / NEW
   tables    NEW / MISSING / CHANGED columns
   plsql     the client's own stored code that differs from the product (it is carried over as is by the dump)
Writes work/delta.json, work/DELTA.md and work/llm/worklist.json (screens that need a reviewed rule set)."""
import os, sys, io, json, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fingerprint as FP
mp = FP.mp

COMPARE = ("xml_logic", "xml_layout", "fmx", "labels")


def compare(client, known):
    common = [k for k in COMPARE if k in client and k in known]
    if not common:
        return "UNVERIFIED", []
    diffs = [k for k in common if client[k] != known[k]]
    return ("CHANGED" if diffs else "SAME"), diffs


def source_kind(fp):
    return "xml" if "xml_logic" in fp else "fmx" if "fmx" in fp else "labels" if "labels" in fp else "none"


def main():
    kp = mp.kpath("fingerprints.json")
    K = json.load(io.open(kp, encoding="utf-8")) if kp else {"screens": {}, "reports": {}, "tables": {}, "plsql": {}, "systems": {}}
    C = FP.snapshot()
    json.dump(C, io.open(mp.work("cache", "fingerprints.json"), "w", encoding="utf-8"), ensure_ascii=False)
    reviewed = {os.path.splitext(n)[0].upper() for n in mp.kfiles("overrides", "*.json")}
    processes = {os.path.splitext(n)[0].upper() for n in mp.kfiles("processes", "*.md")}
    prints = {k.upper() for k in mp.kjson("prints.json") if not k.startswith("_")}
    ksys = {int(k) for k in K.get("systems", {})}

    screens = {}
    for form, fp in sorted(C["screens"].items()):
        known = K["screens"].get(form)
        status, diffs = compare(fp, known) if known else ("NEW", [])
        screens[form] = {"status": status, "diff": diffs, "source": source_kind(fp), "systems": fp.get("systems", []),
                         "reviewed_rules": form in reviewed, "process": form in processes, "print": form in prints,
                         "triggers": fp.get("triggers", 0), "plsql_lines": fp.get("plsql_lines", 0)}
    reports = {}
    for rep, fp in sorted(C["reports"].items()):
        known = K["reports"].get(rep)
        if not known:
            st = "NEW" if fp.get("sql") else "NO_SOURCE"
        elif not fp.get("sql"):
            st = "NO_SOURCE"
        else:
            st = "SAME" if all(fp.get(k) == known.get(k) for k in ("sql", "params", "code")) else "CHANGED"
        reports[rep] = {"status": st, "systems": fp.get("systems", [])}
    kt, ct = K.get("tables", {}), C["tables"]
    tables = {"new": sorted(set(ct) - set(kt)), "missing": sorted(set(kt) - set(ct)),
              "changed": sorted(t for t in set(ct) & set(kt) if ct[t] != kt[t])}
    kc, cc = K.get("plsql", {}), C["plsql"]
    plsql = {"new": sorted(set(cc) - set(kc)), "missing": sorted(set(kc) - set(cc)),
             "changed": sorted(u for u in set(cc) & set(kc) if cc[u] != kc[u]), "same": len([u for u in set(cc) & set(kc) if cc[u] == kc[u]])}
    new_modules = {s: C["systems"][s] for s in C["systems"] if s not in ksys and any(s in v["systems"] for v in screens.values())}

    # screens that need a reviewed rule set: unknown or changed logic, with legacy code to read
    work = []
    for form, s in screens.items():
        logic_changed = s["status"] == "NEW" or (s["status"] == "CHANGED" and ({"xml_logic", "fmx"} & set(s["diff"])))
        if logic_changed and s["source"] in ("xml", "fmx"):
            work.append({"form": form, "status": s["status"], "diff": s["diff"], "source": s["source"],
                         "has_product_rules": s["reviewed_rules"], "plsql_lines": s["plsql_lines"]})
    work.sort(key=lambda w: (w["status"] != "CHANGED", -w["plsql_lines"]))
    json.dump(work, io.open(mp.work("llm", "worklist.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    res = {"knowledge": os.path.relpath(mp.KNOWLEDGE, mp.REPO), "customer_code": mp.CUSTOMER_CODE, "new_modules": new_modules,
           "screens": screens, "reports": reports, "tables": tables, "plsql": plsql, "worklist": len(work)}
    json.dump(res, io.open(mp.work("delta.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1, default=str)
    write_md(res, C, work)


def write_md(res, C, work):
    sc = collections.Counter(s["status"] for s in res["screens"].values())
    rc = collections.Counter(r["status"] for r in res["reports"].values())
    rules = sum(1 for s in res["screens"].values() if s["reviewed_rules"] and s["status"] == "SAME")
    L = [f"# Delta: {mp.CLIENT} against knowledge `{res['knowledge']}`", "",
         "| | same | changed | new | other |", "|---|---:|---:|---:|---:|",
         f"| screens ({len(res['screens'])}) | {sc['SAME']} | {sc['CHANGED']} | {sc['NEW']} | {sc['UNVERIFIED']} unverified |",
         f"| reports ({len(res['reports'])}) | {rc['SAME']} | {rc['CHANGED']} | {rc['NEW']} | {rc['NO_SOURCE']} without RDF |",
         f"| tables ({len(C['tables'])}) | {len(C['tables']) - len(res['tables']['new']) - len(res['tables']['changed'])} | "
         f"{len(res['tables']['changed'])} | {len(res['tables']['new'])} | {len(res['tables']['missing'])} product tables absent |",
         f"| stored PL/SQL units ({len(C['plsql'])}) | {res['plsql']['same']} | {len(res['plsql']['changed'])} | {len(res['plsql']['new'])} | "
         f"{len(res['plsql']['missing'])} product units absent |", "",
         f"- Screens that reuse the product's reviewed rules unchanged: **{rules}**.",
         f"- Screens that need a reviewed rule set (new or changed logic, legacy code available): **{len(work)}** (work/llm/worklist.json).",
         "- The client's stored PL/SQL, triggers and views come with the dump, so database-side business logic is always the client's own.",
         ""]
    if res["new_modules"]:
        L += ["## Modules the knowledge has not seen", ""] + [f"- system {s}: {v['a']} / {v['e']}" for s, v in res["new_modules"].items()] + [""]
    if mp.CUSTOMER_CODE in ("BEN", "AZZ"):
        L += [f"> customer code {mp.CUSTOMER_CODE} has installation-specific branches in the legacy code: review 20_proc_st.sql.", ""]
    for title, st in (("Changed screens", "CHANGED"), ("New screens", "NEW")):
        rows = [(f, s) for f, s in res["screens"].items() if s["status"] == st]
        if rows:
            L += [f"## {title} ({len(rows)})", "", "| form | systems | source | differs in | product rules |", "|---|---|---|---|---|"]
            L += [f"| {f} | {','.join(map(str, s['systems']))} | {s['source']} | {', '.join(s['diff']) or '-'} | "
                  f"{'yes' if s['reviewed_rules'] else '-'} |" for f, s in rows[:300]]
            L += [""]
    for title, key in (("New tables", "new"), ("Changed tables", "changed"), ("Product tables absent", "missing")):
        if res["tables"][key]:
            L += [f"## {title} ({len(res['tables'][key])})", "", ", ".join(res["tables"][key][:400]), ""]
    if res["plsql"]["changed"]:
        L += [f"## Stored code that differs from the product ({len(res['plsql']['changed'])})", "", ", ".join(res["plsql"]["changed"][:400]), ""]
    io.open(mp.work("DELTA.md"), "w", encoding="utf-8").write("\n".join(L))
    print(f"delta: screens {dict(sc)}, reports {dict(rc)}, tables new {len(res['tables']['new'])} changed {len(res['tables']['changed'])}, "
          f"plsql changed {len(res['plsql']['changed'])}, worklist {len(work)}")


if __name__ == "__main__":
    main()
