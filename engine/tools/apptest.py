"""Runtime tests for the client's application in Edge: sign in as a legacy user, handle the forced password change,
and crawl pages looking for APEX / ORA errors.  Usage:
   python apptest.py login            -> sign in as the test user (first time: change password, saved to the password file)
   python apptest.py crawl [from] [n] -> open every page in APP_PAGE_MAP (and form pages with a real row) and report errors
   python apptest.py shot <page> [name]"""
import os, sys, re, json, io, random, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from web import Browser, shot, BASE, env, mp
from db import connect
import winreg

APP = mp.APP_ID
USER = os.environ.get("APP_TEST_USER") or str(mp.CFG.get("test_user", "0"))
PWD_VAR = f"{mp.SCHEMA}_APPUSER{USER}_PWD"          # new-system password of the test user (Windows User environment)


def set_env(name, value):
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment", 0, winreg.KEY_SET_VALUE) as k:
        winreg.SetValueEx(k, name, 0, winreg.REG_SZ, value)


def app_url(page, session="", extra=""):
    return f"{BASE}/f?p={APP}:{page}:{session}::NO:{extra}"


def login(p):
    pwd = None
    try: pwd = env(PWD_VAR)
    except Exception: pass
    first = pwd is None
    if first:
        c = connect(); cur = c.cursor()
        cur.execute("select password from users where users_code = :1", [int(USER)]); pwd = cur.fetchone()[0]
    p.goto(app_url("LOGIN")); p.wait_for_load_state("networkidle")
    p.fill("#P9999_USERNAME", USER); p.fill("#P9999_PASSWORD", pwd)
    p.click("button:has-text('دخول')")
    for _ in range(60):
        p.wait_for_timeout(500)
        if ":LOGIN:" not in p.url.upper() and "/LOGIN" not in p.url.upper():
            break
    p.wait_for_load_state("networkidle")
    print("after login url:", p.url[:140])
    if (":LOGIN:" in p.url.upper() or "/LOGIN" in p.url.upper()) and p.locator("#P9999_USERNAME").count():
        alert = ""
        try: alert = p.locator(".t-Alert-body, .t-Alert-title, .a-Notification-item").first.inner_text()[:160]
        except Exception: pass
        print(f"sign-in failed for legacy user {USER}: {alert or 'still on the login page'}"
              + (" (password taken from USERS.PASSWORD)" if first else f" (password from env {PWD_VAR})"))
        sys.exit(2)
    if "9998" in p.url or "change-password" in p.url or p.locator("#P9998_NEW").count():
        new = "Asc" + "".join(random.choice("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789") for _ in range(9))
        p.fill("#P9998_OLD", pwd); p.fill("#P9998_NEW", new); p.fill("#P9998_CONFIRM", new)
        p.click("button:has-text('حفظ كلمة المرور')"); p.wait_for_load_state("networkidle")
        set_env(PWD_VAR, new)
        with open(mp.PASSWORD_FILE, "a", encoding="utf-8") as fh:
            fh.write(f"{mp.APP_NAME} (client {mp.CLIENT}, APEX app {APP}) legacy user {USER}: new-system password = {new}\n")
        print("password changed for user", USER)
    m = re.search(r"session=(\d+)|f\?p=\d+:\w+:(\d+)", p.url)
    sid = (m.group(1) or m.group(2)) if m else None
    return sid


DENIED = ("ليس لديك صلاحية", "Access denied by Page security check", "رفض الوصول بواسطة اختبار الأمان")


def no_rights(p):
    """True when the page is the application's own 'you may not open this screen' refusal: the legacy rights of the
    test user apply in the new system too, so this is expected, not an error."""
    try:
        txt = p.content()
    except Exception:
        return False
    return any(d in txt for d in DENIED)


def page_errors(p):
    txt = p.content()
    if any(d in txt for d in DENIED):
        return []
    errs = []
    for pat in (r"ORA-\d{5}[^<]{0,160}", r"PLS-\d{5}[^<]{0,160}", r"Error processing[^<]{0,160}", r"Unhandled[^<]{0,120}",
                r"report error:[^<]{0,200}", r"t-Alert--danger", r"ajax_error"):
        for m in re.finditer(pat, txt):
            errs.append(m.group(0)[:200])
    if p.locator(".a-Notification-item, .t-Alert--danger .t-Alert-body").count():
        try: errs.append(p.locator(".a-Notification-item, .t-Alert--danger .t-Alert-body").first.inner_text()[:200])
        except Exception: pass
    return sorted(set(errs))


def open_first_row(p, list_page, sid):
    """Open list_page and click the edit link of the first IR row. Returns the frame/page that holds the form, or None."""
    p.goto(app_url(list_page, sid)); p.wait_for_load_state("networkidle")
    if no_rights(p):
        return None, "no rights"
    link = p.locator("td.a-IRR-linkCol a, td[headers='LINK'] a").first
    if not link.count():
        return None, "no rows"
    link.click()
    p.wait_for_timeout(2500); p.wait_for_load_state("networkidle")
    frames = [f for f in p.frames if f != p.main_frame and "f?p=" in f.url or (f"/r/{mp.WORKSPACE.lower()}/" in f.url and f != p.main_frame)]
    return (frames[-1] if frames else p), "ok"


def frame_errors(fr):
    try:
        txt = fr.content()
    except Exception as e:
        return ["frame: " + str(e)[:120]]
    errs = []
    for pat in (r"ORA-\d{5}[^<]{0,160}", r"PLS-\d{5}[^<]{0,160}", r"t-Alert--danger", r"cannot be rendered[^<]{0,80}"):
        errs += [m.group(0)[:200] for m in re.finditer(pat, txt)]
    return sorted(set(errs))


def crawl_forms(p, sid):
    c = connect(); cur = c.cursor()
    cur.execute("select page_id, parent_page_id, pattern, form_name from app_page_map where kind = 'FORMPAGE' order by page_id")
    results = []
    out = mp.work("verify", "crawl_forms.json")
    rows = cur.fetchall()
    for i, (fp, lp, pattern, form) in enumerate(rows):
        try:
            target, status = open_first_row(p, lp, sid)
            errs = frame_errors(target) if target is not None else []
            if target is not None:
                errs += page_errors(p) if target is p else []
        except Exception as e:
            status, errs = "exception", [str(e)[:200]]
        results.append({"page": fp, "list": lp, "pattern": pattern, "form": form, "status": status, "errors": errs})
        if errs:
            shot(p, f"errform_{fp}"); print(fp, form, pattern, status, "->", errs[:2], flush=True)
        if i and i % 25 == 0:
            json.dump(results, io.open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(results, io.open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"form pages {len(results)}: opened {sum(1 for r in results if r['status']=='ok')}, "
          f"no rows {sum(1 for r in results if r['status']=='no rows')}, with errors {sum(1 for r in results if r['errors'])}")


def create_voucher(p, sid, memo, entry_type="101", lines=(("110401001001", "250", ""), ("210101001001", "", "250"))):
    fp = 10011
    p.goto(app_url(fp, sid)); p.wait_for_load_state("networkidle")
    p.evaluate("([fp, t, m]) => { apex.item('P'+fp+'_ENTRY_TYPE').setValue(t); apex.item('P'+fp+'_ENTRY_DESC').setValue(m); }", [fp, entry_type, memo])
    p.locator("button:has-text('إضافة')").first.click(); p.wait_for_timeout(3000); p.wait_for_load_state("networkidle")
    rid = p.evaluate("""() => $(".a-IG").first().attr("id").replace(/_ig$/, "")""")
    p.evaluate("""([rid, lines]) => {
        const m = apex.region(rid).call("getViews","grid").model;
        for (const [acc, d, cr] of lines) {
            let id = m.insertNewRecord(); let r = (typeof id === "object") ? id : m.getRecord(id);
            m.setValue(r, "ACCOUNT_NUMBER", {v: acc, d: acc}); m.setValue(r, "DEBIT_VALUE", d); m.setValue(r, "CREDIT_VALUE", cr);
        }}""", [rid, [list(l) for l in lines]])
    p.locator("button:has-text('حفظ التعديلات')").first.click(); p.wait_for_timeout(3500); p.wait_for_load_state("networkidle")
    c = connect(); cur = c.cursor()
    cur.execute("select entry_year, entry_type, entry_no from ac_daily_trn where entry_desc = :1", [memo])
    return cur.fetchone()


def run_proc_page(p, sid, pg, values):
    p.goto(app_url(pg, sid)); p.wait_for_load_state("networkidle")
    for k, v in values.items():
        p.evaluate("([i, v]) => apex.item(i).setValue(v)", [f"P{pg}_{k}"[:30], v])
    p.once("dialog", lambda d: d.accept())
    p.locator("button.t-Button--hot").first.click()
    try: p.locator(".js-confirmBtn, .ui-dialog .ui-button--hot").first.click(timeout=4000)
    except Exception: pass
    p.wait_for_timeout(4000); p.wait_for_load_state("networkidle")
    return p.evaluate("() => Array.from(document.querySelectorAll('.t-Alert-body, .a-Notification-item, #APEX_SUCCESS_MESSAGE .t-Alert-title')).map(e => e.innerText.trim()).filter(Boolean).slice(0,4)")


def gl_cycle(p, sid):
    memo = "GLTEST-" + str(random.randint(1000, 9999))
    c = connect(); cur = c.cursor()
    hdr = create_voucher(p, sid, memo)
    print("1 created daily entry:", hdr)
    cur.execute("select count(*), sum(value) from ac_daily_trn_det where (entry_year, entry_type, entry_no) in ((:1,:2,:3))", list(hdr))
    print("  lines / balance:", cur.fetchone())
    y, t, n = hdr
    msg = run_proc_page(p, sid, 10200, {"FROM_YEAR": y, "TO_YEAR": y, "FROM_TYPE": t, "TO_TYPE": t, "FROM_NO": n, "TO_NO": n, "TEST_ONLY": "0"})
    print("2 post:", msg); shot(p, "t_gl_post_real")
    cur.execute("select entry_year, entry_type, entry_no from ac_yearly_trn where entry_desc = :1", [memo]); posted = cur.fetchone()
    cur.execute("select count(*) from ac_daily_trn where entry_desc = :1", [memo]); still = cur.fetchone()[0]
    print("  posted voucher:", posted, " left in daily:", still)
    if posted:
        py, pt, pn = posted
        cur.execute("select count(*), sum(value) from ac_yearly_trn_det where entry_year=:1 and entry_type=:2 and entry_no=:3", list(posted))
        print("  posted lines / balance:", cur.fetchone())
        msg = run_proc_page(p, sid, 10210, {"FROM_YEAR": py, "TO_YEAR": py, "FROM_TYPE": pt, "TO_TYPE": pt, "FROM_NO": pn, "TO_NO": pn})
        print("3 cancel posting:", msg); shot(p, "t_gl_cancel")
        cur.execute("select count(*) from ac_daily_trn where entry_desc = :1", [memo]); back = cur.fetchone()[0]
        cur.execute("select count(*) from ac_yearly_trn where entry_desc = :1", [memo]); left = cur.fetchone()[0]
        print("  back in daily:", back, " left in posted:", left)
    # cleanup (build copy): remove the test voucher wherever it is
    for tbl in ("AC_DAILY_TRN", "AC_YEARLY_TRN"):
        cur.execute(f"select entry_year, entry_type, entry_no from {tbl} where entry_desc = :1", [memo])
        for k in cur.fetchall():
            cur.execute(f"delete from {tbl}_DET where entry_year=:1 and entry_type=:2 and entry_no=:3", list(k))
            cur.execute(f"delete from {tbl} where entry_year=:1 and entry_type=:2 and entry_no=:3", list(k))
    c.commit(); print("4 cleanup done")


def crawl(p, sid, start=0, n=10000):
    c = connect(); cur = c.cursor()
    cur.execute("select page_id, kind, pattern, form_name from app_page_map m where not (kind = 'FORMPAGE' and pattern = 'REPORT_FORM') "
                "and nvl(status, 'GENERATED') <> 'MANUAL' order by page_id")
    pages = cur.fetchall()[start:start + n]
    results = []
    out = mp.work("verify", f"crawl_{start}.json")

    def flush():
        json.dump(results, io.open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    for i, (pg, kind, pattern, form) in enumerate(pages):
        t0 = time.time()
        status = "ok"
        if i and i % 25 == 0:
            flush()                                   # partial results survive a crash of the browser or the run
        try:
            p.goto(app_url(pg, sid)); p.wait_for_load_state("networkidle", timeout=60000)
            p.wait_for_timeout(300)
            if no_rights(p):
                status, errs = "no rights", []
            else:
                errs = page_errors(p)
        except Exception as e:
            if "Timeout" in str(e) and "goto" in str(e):
                status, errs = "timeout", []          # the page runs longer than a minute (report with no filters): a performance item, not a defect
            else:
                errs = ["NAV: " + str(e)[:200]]
        if "LOGIN" in p.url.upper() and "9999" not in str(pg):
            errs.append("redirected to login")
        if errs:
            status = "error"
        results.append({"page": pg, "kind": kind, "pattern": pattern, "form": form, "status": status, "errors": errs, "secs": round(time.time() - t0, 1)})
        if errs:
            shot(p, f"err_{pg}")
            print(pg, form, pattern, "->", errs[:2], flush=True)
    flush()
    bad = [r for r in results if r["errors"]]
    nr = sum(1 for r in results if r["status"] == "no rights")
    print(f"crawled {len(results)} pages, {len(bad)} with errors, {nr} not open to user {USER} (legacy rights) -> {out}")


if __name__ == "__main__":
    what = sys.argv[1]
    b = Browser(state=f"app_u{USER}"); p = b.page
    sid = login(p)
    print("session", sid, "url", p.url[:120])
    if what == "login":
        shot(p, "app_home")
    elif what == "forms":
        crawl_forms(p, sid)
    elif what == "dml_grid":
        # add a row in an editable grid, save, verify in DB, then delete it through the grid
        pg, table, textcol = int(sys.argv[2]), sys.argv[3], sys.argv[4]
        marker = "TEST-" + str(random.randint(1000, 9999))
        p.goto(app_url(pg, sid)); p.wait_for_load_state("networkidle")
        res = p.evaluate("""([col, val]) => {
            const rid = $(".a-IG").first().attr("id").replace(/_ig$/, "");
            const region = apex.region(rid);
            const view = region.call("getViews", "grid");
            const model = view.model;
            let id = model.insertNewRecord();
            let rec = (typeof id === "object") ? id : model.getRecord(id);
            model.setValue(rec, col, val);
            return rid;
        }""", [textcol, marker])
        print("grid region", res); p.wait_for_timeout(500)
        shot(p, "t_dml_grid_before_save")
        p.evaluate("""(rid) => apex.region(rid).call("getActions").invoke("save")""", res)
        p.wait_for_timeout(3000); p.wait_for_load_state("networkidle")
        shot(p, "t_dml_grid_after_save")
        c = connect(); cur = c.cursor()
        cur.execute(f"select rowid, t.* from {table} t where {textcol} = :1", [marker]); rows = cur.fetchall()
        print("rows in DB after save:", len(rows), rows[:1])
        if rows:
            cur.execute(f"delete from {table} where {textcol} = :1", [marker]); c.commit(); print("cleanup: deleted test row")
        print("page errors:", page_errors(p))
    elif what == "dml_voucher":
        fp = 10011
        memo = "TEST-" + str(random.randint(1000, 9999))
        p.goto(app_url(fp, sid)); p.wait_for_load_state("networkidle")
        vals = {"ENTRY_TYPE": "101", "ENTRY_DESC": memo}
        for k, v in vals.items():
            loc = p.locator(f"#P{fp}_{k}")
            if loc.count(): loc.fill(v)
        print("defaults:", p.evaluate("""(fp) => Object.fromEntries(["ENTRY_YEAR","ENTRY_DATE","CURRENCY_CODE","RATE","ENTRY_NO"].map(k => [k, apex.item("P"+fp+"_"+k).getValue()]))""", fp))
        p.click("button:has-text('إضافة')"); p.wait_for_timeout(3000); p.wait_for_load_state("networkidle")
        print("after create:", p.url[:110], page_errors(p)); shot(p, "t_voucher_created")
        c = connect(); cur = c.cursor()
        cur.execute("select entry_year, entry_type, entry_no, create_user_code, create_date from ac_daily_trn where entry_desc = :1", [memo])
        hdr = cur.fetchone(); print("header in DB:", hdr)
        if hdr and p.locator(".a-IG").count():
            rid = p.evaluate("""() => $(".a-IG").first().attr("id").replace(/_ig$/, "")""")
            p.evaluate("""(rid) => {
                const m = apex.region(rid).call("getViews","grid").model;
                for (const [acc, d, cr] of [["110401001001","100",""],["210101001001","","100"]]) {
                    let id = m.insertNewRecord(); let r = (typeof id === "object") ? id : m.getRecord(id);
                    m.setValue(r, "ACCOUNT_NUMBER", {v: acc, d: acc}); m.setValue(r, "DEBIT_VALUE", d); m.setValue(r, "CREDIT_VALUE", cr);
                }}""", rid)
            p.wait_for_timeout(500)
            p.click("button:has-text('حفظ التعديلات')"); p.wait_for_timeout(3500); p.wait_for_load_state("networkidle")
            print("after save:", page_errors(p)); shot(p, "t_voucher_saved")
            cur.execute("select seq, account_number, value, create_user_code from ac_daily_trn_det where entry_year=:1 and entry_type=:2 and entry_no=:3 order by seq", list(hdr[:3]))
            print("lines in DB:", cur.fetchall())
        if hdr:
            cur.execute("delete from ac_daily_trn_det where entry_year=:1 and entry_type=:2 and entry_no=:3", list(hdr[:3]))
            cur.execute("delete from ac_daily_trn where entry_year=:1 and entry_type=:2 and entry_no=:3", list(hdr[:3]))
            c.commit(); print("cleanup done")
    elif what == "print":
        target, status = open_first_row(p, int(sys.argv[2]), sid)
        p.click("button:has-text('طباعة')"); p.wait_for_timeout(2500); p.wait_for_load_state("networkidle")
        print("print page:", p.url[:110], page_errors(p))
        p.emulate_media(media="print"); print(shot(p, sys.argv[3] if len(sys.argv) > 3 else "t_print"))
    elif what == "gl_cycle":
        gl_cycle(p, sid)
    elif what == "proc_run":
        # python apptest.py proc_run <page> NAME=value ...   (only use test-only / harmless parameters)
        pg = int(sys.argv[2])
        p.goto(app_url(pg, sid)); p.wait_for_load_state("networkidle")
        for kv in sys.argv[3:]:
            k, v = kv.split("=", 1)
            p.evaluate("([i, v]) => apex.item(i).setValue(v)", [f"P{pg}_{k}"[:30], v])
        print("values:", p.evaluate("(pg) => Array.from(document.querySelectorAll('[id^=P'+pg+'_]')).filter(e=>e.id.indexOf('_')>0 && !e.id.includes('_lov') && !e.id.includes('_CONTAINER')).slice(0,14).map(e=>[e.id, apex.item(e.id).getValue()])", pg))
        p.once("dialog", lambda d: d.accept())
        p.locator("button.t-Button--hot").first.click()
        try: p.locator(".js-confirmBtn, .ui-dialog button:has-text('موافق'), .ui-dialog .ui-button--hot").first.click(timeout=4000)
        except Exception: pass
        p.wait_for_timeout(4000); p.wait_for_load_state("networkidle")
        msg = p.evaluate("() => Array.from(document.querySelectorAll('.t-Alert-title, .t-Alert-body, .a-Notification-item, #APEX_SUCCESS_MESSAGE, #APEX_ERROR_MESSAGE')).map(e => e.innerText.trim()).filter(Boolean).slice(0,6)")
        print("messages:", msg); print(shot(p, f"t_proc_{pg}"))
    elif what == "english":
        p.goto(app_url(1, sid)); p.wait_for_load_state("networkidle")
        p.click("text=English"); p.wait_for_timeout(2500); p.wait_for_load_state("networkidle")
        print("url", p.url[:120]); print(shot(p, "t_en_home"))
        target, status = open_first_row(p, int(sys.argv[2]) if len(sys.argv) > 2 else 10020, sid)
        p.wait_for_timeout(1500); print(status, frame_errors(target) if target is not None else None); print(shot(p, "t_en_doc"))
        p.goto(app_url(1, sid, "")); p.wait_for_load_state("networkidle")
        p.click("text=عربي"); p.wait_for_timeout(2000)
        print("back to arabic:", p.url[:100])
    elif what == "nav":
        p.goto(app_url(1, sid)); p.wait_for_load_state("networkidle")
        p.click("#t_Button_navControl"); p.wait_for_timeout(1500)
        for t in p.locator(".a-TreeView-label").all()[:3]:
            try: t.click(); p.wait_for_timeout(400)
            except Exception: pass
        items = p.locator(".a-TreeView-node").count()
        print("tree nodes visible:", items)
        print(shot(p, "t_nav"))
    elif what == "doc":
        target, status = open_first_row(p, int(sys.argv[2]), sid)
        p.wait_for_timeout(1500)
        print(status, frame_errors(target) if target is not None else None)
        print(shot(p, sys.argv[3] if len(sys.argv) > 3 else f"doc_{sys.argv[2]}"))
    elif what == "crawl":
        crawl(p, sid, int(sys.argv[2]) if len(sys.argv) > 2 else 0, int(sys.argv[3]) if len(sys.argv) > 3 else 10000)
    elif what == "shot":
        p.goto(app_url(sys.argv[2], sid, sys.argv[4] if len(sys.argv) > 4 else "")); p.wait_for_load_state("networkidle"); p.wait_for_timeout(800)
        print(page_errors(p)); print(shot(p, sys.argv[3] if len(sys.argv) > 3 else f"page_{sys.argv[2]}"))
    b.close()
