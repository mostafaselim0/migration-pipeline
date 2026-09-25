"""Scan the git repository (all commits) for known credentials and password-like assignments before publishing."""
import subprocess, re, os, winreg, sys

GIT = os.environ.get("MP_GIT", r"C:\Program Files\MinGit\cmd\git.exe")
REPO = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# known credentials are read at run time from the passwords file (never written into the repository)
PWFILE = os.environ.get("MP_PASSWORD_FILE") or os.path.join(os.path.expanduser("~"), "Pictures", "passwords.txt")
known = []
if os.path.exists(PWFILE):
    for line in open(PWFILE, encoding="utf-8-sig", errors="replace"):
        for m in re.finditer(r"(?:=|password:|Password:)\s*([^\s;()]{8,})", line):
            tok = m.group(1).strip()
            if not tok.startswith("http") and "\\" not in tok and "." not in tok[:1]:
                known.append(tok)
with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
    i = 0
    while True:
        try:
            name, val, _ = winreg.EnumValue(k, i); i += 1
        except OSError:
            break
        if name.endswith("_PWD") and val:
            known.append(val)


def git(*a):
    return subprocess.run([GIT, *a], cwd=REPO, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout


revs = git("rev-list", "--all").split()
hits = 0
for s in known:
    out = git("grep", "-l", "-F", s, *revs)
    if out.strip():
        hits += 1
        print(f"KNOWN SECRET {s[:3]}... in:", out.strip().splitlines()[:5])
print("known-secret hits:", hits)
pat = r"(password|passwd|pwd|secret|token)\s*(=|:|=>)\s*['\"]?[A-Za-z0-9#@!$%^&*_\-]{8,}"
out = git("grep", "-n", "-I", "-i", "-E", pat, "--", ".", ":!*.xml", ":!*.json")
lines = [l for l in out.splitlines() if not re.search(r"(_PWD|getenv|env\(|os\.environ|\$pw|pwd\)|\{pwd\}|p_password|:P9998|hash_pwd|password_number|PASSWORD_NUMBER|l_pwd|p_pwd)", l, re.I)]
print("pattern hits:", len(lines))
for l in lines[:25]:
    print("  ", l[:200])
print("files tracked:", len(git("ls-files").splitlines()))
