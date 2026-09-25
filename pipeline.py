"""Migration Pipeline: move a client of an Oracle Forms / Reports ERP (ASCON) to Oracle APEX.

   python pipeline.py <client>                   run every stage: restore catalog generate delta build verify report
   python pipeline.py <client> generate build    run chosen stages, in the order given
   python pipeline.py <client> --from generate   run from a stage to the end
   python pipeline.py <client> status            what ran, when, and the result
   python pipeline.py <client> learn             make this (reviewed) client the reference of its product knowledge
   python pipeline.py <client> llm [--budget N] [--max N] [--prepare]   optional, budgeted: draft rule sets (docs/LLM.md)
   python pipeline.py <client> promote FORM ...  copy reviewed overlay work into the product knowledge
   python pipeline.py --init-server              one-time: the admin user MP_ADMIN on this database server
   python pipeline.py --new <client>             create clients/<client>/client.json from the template

Every stage is a plain script under engine/ that reads clients/<client>/client.json (engine/mp.py) and writes only under
clients/<client>/work (logs in work/logs/<stage>.log).  No stage needs a language model."""
import os, sys, io, json, time, shutil, subprocess

REPO = os.path.dirname(os.path.abspath(__file__))
ENGINE = os.path.join(REPO, "engine")
G, S = os.path.join(ENGINE, "gen"), os.path.join(ENGINE, "stages")
ORDER = ["restore", "catalog", "generate", "delta", "build", "verify", "report"]
STAGES = {
    "restore":  [(S, "restore.py")],
    "catalog":  [(G, "meta.py"), (G, "labels.py"), (G, "catalog.py")],
    "delta":    [(S, "delta.py")],
    "generate": [(G, "transpile.py"), (G, "specs.py"), (G, "reports.py")],
    "build":    [(G, "build.py", "db"), (G, "build.py", "apex"), (G, "build.py", "install"), (G, "build.py", "translate")],
    "verify":   [(S, "verify.py")],
    "report":   [(S, "report.py")],
    "learn":    [(S, "learn.py")],
    "llm":      [(S, "llm.py")],
    "promote":  [(S, "promote.py")],
}


def run_stage(client, stage, extra):
    work = os.path.join(REPO, "clients", client, "work")
    os.makedirs(os.path.join(work, "logs"), exist_ok=True)
    logp = os.path.join(work, "logs", stage + ".log")
    env = dict(os.environ, MP_CLIENT=client, PYTHONIOENCODING="utf-8", PYTHONUTF8="1")
    t0 = time.time(); rc = 0
    print(f"=== {client}: {stage}", flush=True)
    with io.open(logp, "w", encoding="utf-8") as log:
        for step in STAGES[stage]:
            cwd, script, *args = step
            args = args + (extra if stage in ("llm", "promote", "learn") else [])
            log.write(f"--- {script} {' '.join(args)}\n"); log.flush()
            p = subprocess.Popen([sys.executable, os.path.join(cwd, script), *args], cwd=cwd, env=env, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
            for line in p.stdout:
                log.write(line); print("   " + line.rstrip()[:220], flush=True)
            rc = p.wait()
            if rc:
                break
    sp = os.path.join(work, "stages.json")
    st = json.load(io.open(sp, encoding="utf-8")) if os.path.exists(sp) else {}
    st[stage] = {"status": "ok" if rc == 0 else f"failed ({rc})", "finished": time.strftime("%Y-%m-%d %H:%M"),
                 "seconds": round(time.time() - t0)}
    json.dump(st, io.open(sp, "w", encoding="utf-8"), indent=1)
    print(f"=== {stage}: {st[stage]['status']} in {st[stage]['seconds']} s (log {os.path.relpath(logp, REPO)})", flush=True)
    return rc


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__); return 0
    if argv[0] == "--init-server":
        return subprocess.call([sys.executable, os.path.join(S, "init_server.py"), *argv[1:]])
    if argv[0] == "--new":
        dst = os.path.join(REPO, "clients", argv[1])
        if os.path.exists(os.path.join(dst, "client.json")):
            sys.exit(f"{dst} already exists")
        os.makedirs(os.path.join(dst, "dump"), exist_ok=True)
        tpl = json.load(io.open(os.path.join(REPO, "clients", "_template", "client.json"), encoding="utf-8"))
        tpl["schema"] = tpl["workspace"] = argv[1].upper()
        used = [100]                                                  # next free application id (100 = the reference client)
        for p in os.listdir(os.path.join(REPO, "clients")):
            cj = os.path.join(REPO, "clients", p, "client.json")
            if p != "_template" and os.path.exists(cj):
                used.append(int(json.load(io.open(cj, encoding="utf-8")).get("app_id") or 0))
        tpl["app_id"] = max(used) + 100
        json.dump(tpl, io.open(os.path.join(dst, "client.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print(f"created {os.path.relpath(dst, REPO)}\\client.json (application {tpl['app_id']}): put the dump in "
              f"{os.path.relpath(dst, REPO)}\\dump, then  python pipeline.py {argv[1]}")
        return 0
    client, rest = argv[0], argv[1:]
    if not os.path.exists(os.path.join(REPO, "clients", client, "client.json")):
        sys.exit(f"unknown client {client}: python pipeline.py --new {client}")
    if rest[:1] == ["status"]:
        sp = os.path.join(REPO, "clients", client, "work", "stages.json")
        print(json.dumps(json.load(io.open(sp)) if os.path.exists(sp) else {}, indent=1)); return 0
    if rest and rest[0] in ("llm", "promote", "learn"):
        return run_stage(client, rest[0], rest[1:])
    if rest[:1] == ["--from"]:
        stages = ORDER[ORDER.index(rest[1]):]
    else:
        stages = rest or ORDER
    for s in stages:
        if s not in STAGES:
            sys.exit(f"unknown stage {s}; stages: {', '.join(ORDER)} (+ learn, llm, promote)")
    for s in stages:
        if run_stage(client, s, []):
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
