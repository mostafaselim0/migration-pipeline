"""Shared DB helper for the engine scripts.  The default user and DSN are the current client's (engine/mp.py).
Passwords come from the Windows *User* environment (<SCHEMA>_PWD, SYS_PWD) which the restore stage fills; they are also
recorded in the operator's password file. Never hard-code them here."""
import os, sys, winreg
import oracledb
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _client():
    try:
        import mp
        return mp
    except BaseException:                                           # outside a pipeline run (no MP_CLIENT)
        return None


_mp = _client()
DSN = os.environ.get("APP_DSN") or (_mp.DSN if _mp else "localhost:1521/ORCLPDB")

def _env(name):
    v = os.environ.get(name)
    if v:
        return v
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
            return winreg.QueryValueEx(k, name)[0]
    except OSError:
        return None

def connect(user=None):
    user = (user or (_mp.SCHEMA if _mp else os.environ.get("MP_SCHEMA", ""))).lower()
    if user == "sys":
        return oracledb.connect(user="sys", password=_env("SYS_PWD"), dsn=DSN, mode=oracledb.AUTH_MODE_SYSDBA)
    pwd = _env(user.upper() + "_PWD")
    if not pwd:
        sys.exit(f"password for {user} not found in env {user.upper()}_PWD")
    return oracledb.connect(user=user, password=pwd, dsn=DSN)

def rows(cur, sql, binds=None):
    cur.execute(sql, binds or [])
    cols = [d[0].lower() for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]

def show(cur, sql, binds=None, n=40, w=60):
    cur.execute(sql, binds or [])
    cols = [d[0] for d in cur.description]
    print(" | ".join(cols))
    for r in cur.fetchmany(n):
        print(" | ".join("" if v is None else str(v).replace("\n", " ")[:w] for v in r))
    print()
