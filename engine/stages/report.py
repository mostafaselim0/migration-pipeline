"""Stage report: one page per client (work/REPORT.md) from what the other stages recorded."""
import os, sys, re, io, json, collections
HERE = os.path.dirname(os.path.abspath(__file__))
ENGINE = os.path.dirname(HERE)
sys.path.insert(0, ENGINE)
import mp


def load(name):
    p = mp.work(name)
    return json.load(io.open(p, encoding="utf-8")) if os.path.exists(p) else None


def log(stage):
    p = mp.work("logs", stage + ".log")
    return io.open(p, encoding="utf-8", errors="replace").read() if os.path.exists(p) else ""


def main():
    st = load("stages.json") or {}
    rs, dl, vf = load("restore.json"), load("delta.json"), load("verify.json")
    specs = load(os.path.join("out", "specs.json"))
    reps = load(os.path.join("out", "reports.json")) or []
    L = [f"# {mp.APP_NAME}: migration report for {mp.CLIENT}", "",
         f"Schema **{mp.SCHEMA}**, APEX workspace **{mp.WORKSPACE}**, application **{mp.APP_ID}** (Arabic) and **{mp.TAPP_ID}** (English), "
         f"knowledge `{os.path.relpath(mp.KNOWLEDGE, mp.REPO)}`.", "",
         "Legacy Forms/Reports: " + ("**not delivered (dump only)**: the product's reference sources were used, so screens and "
                                     "reports the client customised in Forms/Reports appear as the product's standard ones; "
                                     "its database logic (triggers, procedures, views) is its own."
                                     if mp.SOURCES_FROM_PRODUCT else f"the client's own (`{mp.SOURCES}`)."), "",
         "| stage | status | when | seconds |", "|---|---|---|---:|"]
    for k, v in st.items():
        L.append(f"| {k} | {v.get('status')} | {v.get('finished', '')} | {v.get('seconds', '')} |")
    L.append("")
    if rs:
        L += ["## Data", "",
              f"- Dump `{os.path.basename(rs['dump'])}` ({rs['kind']}), source schema {rs['source_schema']}: {rs['tables']} tables, "
              f"{rs['rows']:,} rows, objects {rs['objects']}.",
              f"- Text columns switched to CHAR semantics: {rs['char_columns_converted']} (failed {len(rs['char_failed'])}).",
              f"- Removed from the copy: {rs['jobs_removed']} jobs, DB links {rs['db_links_dropped'] or 'none'} "
              "(imported jobs and links would reach the client's live systems).",
              f"- Objects whose DDL named the source schema, re-created for {mp.SCHEMA}: {len(rs.get('remapped_ok', []))}"
              + (f" (failed: {'; '.join(rs['remapped_failed'][:5])})" if rs.get("remapped_failed") else "") + ".",
              f"- Foreign keys the legacy data violates (kept, not validated): {len(rs['fk_novalidate'])}; rejected-row messages: {rs['rejected_row_messages']}.",
              f"- Invalid objects after restore (legacy): {len(rs['invalid_objects'])}" + (f": {', '.join(rs['invalid_objects'][:30])}" if rs['invalid_objects'] else ""), ""]
    if dl:
        sc = collections.Counter(s["status"] for s in dl["screens"].values())
        rc = collections.Counter(r["status"] for r in dl["reports"].values())
        L += ["## Difference from the product knowledge (details: DELTA.md)", "",
              f"- Screens: {dict(sc)}; reports: {dict(rc)}.",
              f"- Modules the knowledge has not seen: {', '.join(str(s) + ' ' + (v.get('e') or v.get('a') or '') for s, v in dl['new_modules'].items()) or 'none'}.",
              f"- Tables: {len(dl['tables']['new'])} new, {len(dl['tables']['changed'])} changed, {len(dl['tables']['missing'])} product tables absent.",
              f"- Stored PL/SQL: {dl['plsql']['same']} same as the product, {len(dl['plsql']['changed'])} changed, {len(dl['plsql']['new'])} new "
              "(all carried over with the dump).",
              f"- Screens waiting for a reviewed rule set: {dl['worklist']} (work/llm/worklist.json; optional stage `llm`).", ""]
    if specs:
        pat = collections.Counter(s["pattern"] for s in specs["specs"])
        src = collections.Counter(s["source"] for s in specs["specs"])
        rules = sum(1 for s in specs["specs"] if s.get("rules"))
        L += ["## Generated application", "",
              f"- Screens: {len(specs['specs'])} ({dict(pat)}); structure taken from {dict(src)}.",
              f"- Screens with reviewed rules applied: {rules}.",
              f"- Report pages: {sum(1 for r in reps if r.get('ok'))} generated of {len(reps)} registered reports."]
        b = log("build")
        for pat_, label in ((r"apex files written: (.*)", "Export"), (r"install exit (\d+)", "Install exit code"),
                            (r"invalid objects after recompile: (.*)", "Invalid objects after the build"),
                            (r"report RDFs compiled: (.*)", "Report RDFs compiled (original-design printing)")):
            m = re.findall(pat_, b)
            if m: L.append(f"- {label}: {m[-1][:600]}")
        checks = [l.strip() for l in b.splitlines() if "CHECK:" in l]
        if checks:
            L += [f"- Knowledge DB scripts that did not compile cleanly on this schema ({len(checks)}):"] + [f"  - `{c[:220]}`" for c in checks[:40]]
        dg = load(os.path.join("build", "degraded.json"))
        if dg and any(dg.values()):
            L += ["", "### Reviewed product rules switched off for this installation (they do not fit its database)", ""]
            L += [f"- package member `{m}`: raises ORA-20990 \"needs review\" when used" for m in dg["isolated_members"]]
            L += [f"- {s}" for s in dg["skipped_rules"]]
            L += [f"- generated trigger dropped: {s}" for s in dg["dropped_triggers"]]
            L += [f"- package still invalid: {s}" for s in dg["invalid_left"]]
        L.append("")
    if vf:
        L += ["## Verification (Edge, signed in as legacy user " + str(vf.get("test_user")) + ")", ""]
        if "pages" in vf:
            L += [f"- Pages opened: {vf['pages']['opened']}, with errors: {vf['pages']['with_errors']}.",
                  f"- Document pages opened on a real record: {vf['documents']['opened_with_record']} of {vf['documents']['pages']} "
                  f"(no records: {vf['documents']['no_rows']}), with errors: {vf['documents']['with_errors']}."]
            for e in (vf["pages"]["errors"] + vf["documents"]["errors"])[:25]:
                L.append(f"  - page {e['page']} {e['form']}: {'; '.join(e['errors'])[:200]}")
        else:
            L.append(f"- Sign-in failed: {vf['login']}")
        L.append("")
    L += ["## Next", "",
          "1. Key users test the screens listed as CHANGED / NEW in DELTA.md first; everything else runs on reviewed product rules.",
          "2. Optional: `python pipeline.py " + mp.CLIENT + " llm --budget 300000` drafts rule sets for the worklist into overlay/ (review before use).",
          "3. After review: `python pipeline.py " + mp.CLIENT + " generate build verify report` rebuilds with the overlay.",
          "4. Reviewed overlay files that are really product behaviour: `python pipeline.py " + mp.CLIENT + " promote FORM ...`.", ""]
    io.open(mp.work("REPORT.md"), "w", encoding="utf-8").write("\n".join(L))
    print("report ->", mp.work("REPORT.md"))


if __name__ == "__main__":
    main()
