"""Playwright helpers that drive the installed Microsoft Edge against local APEX.
Screenshots go to clients/<client>/work/verify/shots; session state is cached next to them."""
import os, sys, re, time
from playwright.sync_api import sync_playwright
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE)); import mp

BASE = os.environ.get("APP_BASE") or mp.CFG.get("ords_base", "http://localhost:8080/ords")
SHOTS = mp.work("verify", "shots")

def shot(page, name):
    p = os.path.join(SHOTS, name + ".png")
    page.screenshot(path=p, full_page=True)
    return p

def inputs(page):
    """Return visible form fields (id, name, type, label-ish) to learn a page's structure."""
    return page.evaluate("""() => Array.from(document.querySelectorAll('input,select,textarea,button'))
        .filter(e => e.offsetParent !== null)
        .map(e => [e.tagName, e.id, e.name, e.type, (e.getAttribute('aria-label')||e.placeholder||e.innerText||'').trim().slice(0,40)])""")

def env(name):
    import winreg
    v = os.environ.get(name)
    if v: return v
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
        return winreg.QueryValueEx(k, name)[0]

def builder_login(page, user="CLAUDE", workspace=mp.WORKSPACE):
    """Sign in to the APEX builder; returns the builder session id."""
    page.goto(BASE + "/r/apex/workspace-sign-in/oracle-apex-sign-in")
    page.wait_for_load_state("networkidle")
    if page.locator("#F4550_P1_PASSWORD").count():
        page.fill("#F4550_P1_COMPANY", workspace)
        page.fill("#F4550_P1_USERNAME", user)
        page.fill("#F4550_P1_PASSWORD", env("APEX_CLAUDE_PWD"))
        page.click("text=Sign In")
    for _ in range(60):
        if "sign-in" not in page.url and "session=" in page.url:
            break
        page.wait_for_timeout(500)
    page.wait_for_load_state("networkidle")
    m = re.search(r"session=(\d+)", page.url)
    return m.group(1) if m else None

def goto(page, url, tries=3):
    for i in range(tries):
        try:
            page.goto(url); page.wait_for_load_state("networkidle"); return
        except Exception as e:
            if i == tries - 1: raise
            page.wait_for_timeout(1500)

class Browser:
    def __init__(self, headless=True, state=None):
        self.pw = sync_playwright().start()
        self.browser = self.pw.chromium.launch(channel="msedge", headless=headless)
        self.state_file = mp.work("verify", f".state_{state}.json") if state else None
        kw = {"viewport": {"width": 1500, "height": 950}, "locale": "en-US"}
        if self.state_file and os.path.exists(self.state_file):
            kw["storage_state"] = self.state_file
        self.ctx = self.browser.new_context(**kw)
        self.ctx.set_default_timeout(60000)
        self.page = self.ctx.new_page()

    def save(self):
        if self.state_file:
            self.ctx.storage_state(path=self.state_file)

    def close(self):
        try: self.save()
        finally:
            self.browser.close(); self.pw.stop()
