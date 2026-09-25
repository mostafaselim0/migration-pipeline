"""Stage verify: open the installed application in Edge (Playwright) as a legacy user and look for errors.
   login   first sign-in of the test user (forced password change handled; new password saved)
   crawl   every generated page of APP_PAGE_MAP (screens, reports, process pages)
   forms   every document page opened on its first existing record
Writes work/verify.json.  The test user is client.json "test_user", else legacy user 0, else the lowest user code."""
import os, sys, io, json, subprocess, collections
HERE = os.path.dirname(os.path.abspath(__file__))
ENGINE = os.path.dirname(HERE)
sys.path.insert(0, ENGINE); sys.path.insert(0, os.path.join(ENGINE, "tools"))
import mp
from db import connect


def test_user():
    if mp.CFG.get("test_user") is not None:
        return str(mp.CFG["test_user"])
    cur = connect().cursor()
    cur.execute("select min(users_code), max(case when users_code = 0 then 1 else 0 end) from users")
    lo, has0 = cur.fetchone()
    return "0" if has0 else str(lo)


def run(*args):
    env = dict(os.environ, APP_TEST_USER=USER)
    r = subprocess.run([sys.executable, os.path.join(ENGINE, "tools", "apptest.py"), *args], capture_output=True, text=True,
                       encoding="utf-8", errors="replace", env=env)
    out = (r.stdout or "") + (r.stderr or "")
    print(f"apptest {' '.join(args)}: exit {r.returncode}; " + " / ".join(out.strip().splitlines()[-2:]), flush=True)
    return r.returncode, out


USER = None


def main():
    global USER
    USER = test_user()
    res = {"test_user": USER}
    rc, out = run("login")
    res["login"] = {"ok": rc == 0 and "redirected to login" not in out, "tail": out.strip().splitlines()[-3:]}
    if not res["login"]["ok"]:
        json.dump(res, io.open(mp.work("verify.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        sys.exit("sign-in failed: see work/verify.json")
    run("crawl")
    run("forms")
    crawl = json.load(io.open(mp.work("verify", "crawl_0.json"), encoding="utf-8")) if os.path.exists(mp.work("verify", "crawl_0.json")) else []
    forms = json.load(io.open(mp.work("verify", "crawl_forms.json"), encoding="utf-8")) if os.path.exists(mp.work("verify", "crawl_forms.json")) else []
    res["pages"] = {"opened": len(crawl), "with_errors": sum(1 for r in crawl if r["errors"]),
                    "by_kind": dict(collections.Counter(r["kind"] for r in crawl)),
                    "errors": [{"page": r["page"], "form": r["form"], "errors": r["errors"][:2]} for r in crawl if r["errors"]][:200]}
    res["documents"] = {"pages": len(forms), "opened_with_record": sum(1 for r in forms if r["status"] == "ok"),
                        "no_rows": sum(1 for r in forms if r["status"] == "no rows"), "with_errors": sum(1 for r in forms if r["errors"]),
                        "errors": [{"page": r["page"], "form": r["form"], "errors": r["errors"][:2]} for r in forms if r["errors"]][:200]}
    json.dump(res, io.open(mp.work("verify.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"verify: pages {res['pages']['opened']} ({res['pages']['with_errors']} with errors), documents "
          f"{res['documents']['opened_with_record']} opened ({res['documents']['with_errors']} with errors)")


if __name__ == "__main__":
    main()
