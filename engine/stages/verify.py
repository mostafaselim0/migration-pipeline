"""Stage verify: open the installed application in Edge (Playwright) as a legacy user and look for errors.
   login   first sign-in of the test user (forced password change handled; new password saved)
   crawl   every generated page of APP_PAGE_MAP (screens, reports, process pages)
   forms   every document page opened on its first existing record
Writes work/verify.json.  The test user is client.json "test_user", else legacy user 0, else the lowest user code."""
import os, sys, io, re, json, subprocess, collections
HERE = os.path.dirname(os.path.abspath(__file__))
ENGINE = os.path.dirname(HERE)
sys.path.insert(0, ENGINE); sys.path.insert(0, os.path.join(ENGINE, "tools"))
import mp
from db import connect


def test_user():
    """client.json "test_user", else legacy user 0 when it is active, else the active user assigned to the most systems
    (a stopped user - USERS.STOP_FLAG = 1 - is refused by app_sec.authenticate, as in the legacy login)."""
    if mp.CFG.get("test_user") is not None:
        return str(mp.CFG["test_user"])
    cur = connect().cursor()
    cur.execute("""select u.users_code
                     from users u left join (select users_code, count(*) n from sys_systems_users group by users_code) s
                       on s.users_code = u.users_code
                    where nvl(u.stop_flag, 0) = 0 and u.password is not null
                    order by case when u.users_code = 0 then 0 else 1 end, nvl(s.n, 0) desc, u.users_code""")
    r = cur.fetchone()
    if not r:
        sys.exit("no active legacy user with a password to sign in with: set \"test_user\" in client.json")
    return str(r[0])


def run(*args):
    env = dict(os.environ, APP_TEST_USER=USER)
    r = subprocess.run([sys.executable, os.path.join(ENGINE, "tools", "apptest.py"), *args], capture_output=True, text=True,
                       encoding="utf-8", errors="replace", env=env)
    out = (r.stdout or "") + (r.stderr or "")
    print(f"apptest {' '.join(args)}: exit {r.returncode}; " + " / ".join(out.strip().splitlines()[-2:]), flush=True)
    return r.returncode, out


USER = None


def apex_causes(since):
    """page -> root-cause texts APEX logged for the application since the crawl started (the browser only shows
    'contact your administrator'; the activity log holds the ORA / PLS text behind it)."""
    out = collections.defaultdict(list)
    try:
        cur = connect().cursor()
        cur.execute("""select page_id, component_type, component_name, ora_sqlerrm, message from app_error_log
                        where logged_on >= :1 order by logged_on""", [since])
        for pg, ctype, cname, sqlerrm, msg in cur.fetchall():
            text = (sqlerrm or msg or "").strip()
            root = next((l.strip() for l in text.splitlines() if re.search(r"(ORA|PLS)-\d{5}", l) and "ORA-06512" not in l), text.splitlines()[0] if text else "")
            cause = (f"{ctype or ''} {cname or ''}: ".strip(": ") + ": " if (ctype or cname) else "") + root
            if cause and cause[:300] not in out[pg]:
                out[pg].append(cause[:300])
    except Exception as e:
        print("app_error_log not readable:", str(e).splitlines()[0])
    return out


def main():
    global USER
    USER = test_user()
    res = {"test_user": USER}
    import datetime
    started = datetime.datetime.now()
    rc, out = run("login")
    res["login"] = {"ok": rc == 0 and "redirected to login" not in out, "tail": out.strip().splitlines()[-3:]}
    if not res["login"]["ok"]:
        json.dump(res, io.open(mp.work("verify.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        sys.exit("sign-in failed: see work/verify.json")
    for f in ("crawl_0.json", "crawl_forms.json"):
        if os.path.exists(mp.work("verify", f)):
            os.remove(mp.work("verify", f))                 # results of an earlier run must not pass for this one
    rc1, out1 = run("crawl")
    rc2, out2 = run("forms")
    res["runs"] = {"crawl": {"exit": rc1, "tail": out1.strip().splitlines()[-4:]}, "forms": {"exit": rc2, "tail": out2.strip().splitlines()[-4:]}}
    crawl = json.load(io.open(mp.work("verify", "crawl_0.json"), encoding="utf-8")) if os.path.exists(mp.work("verify", "crawl_0.json")) else []
    forms = json.load(io.open(mp.work("verify", "crawl_forms.json"), encoding="utf-8")) if os.path.exists(mp.work("verify", "crawl_forms.json")) else []
    if not crawl:
        json.dump(res, io.open(mp.work("verify.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        sys.exit("the page crawl produced no results (browser run failed): see work/verify.json 'runs'")
    causes = apex_causes(started)
    for r in crawl + forms:
        if r["errors"] and causes.get(r["page"]):
            r["errors"] = [e for e in r["errors"] if e != "t-Alert--danger"] + ["cause: " + c for c in causes[r["page"]][:2]]
    res["pages"] = {"opened": len(crawl), "with_errors": sum(1 for r in crawl if r["errors"]),
                    "no_rights": sum(1 for r in crawl if r.get("status") == "no rights"),
                    "timeouts": [{"page": r["page"], "form": r["form"]} for r in crawl if r.get("status") == "timeout"],
                    "by_kind": dict(collections.Counter(r["kind"] for r in crawl)),
                    "errors": [{"page": r["page"], "form": r["form"], "errors": r["errors"][:2]} for r in crawl if r["errors"]][:200]}
    res["documents"] = {"pages": len(forms), "opened_with_record": sum(1 for r in forms if r["status"] == "ok"),
                        "no_rows": sum(1 for r in forms if r["status"] == "no rows"), "no_rights": sum(1 for r in forms if r["status"] == "no rights"),
                        "with_errors": sum(1 for r in forms if r["errors"]),
                        "errors": [{"page": r["page"], "form": r["form"], "errors": r["errors"][:2]} for r in forms if r["errors"]][:200]}
    json.dump(res, io.open(mp.work("verify.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"verify: pages {res['pages']['opened']} ({res['pages']['with_errors']} with errors, {res['pages']['no_rights']} closed to the test user), "
          f"documents {res['documents']['opened_with_record']} opened ({res['documents']['with_errors']} with errors)")


if __name__ == "__main__":
    main()
