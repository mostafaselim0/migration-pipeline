"""One-time setup of a database server for the pipeline: the admin user MP_ADMIN that restores dumps, creates client
schemas and APEX workspaces.  Runs as SYS (Windows User env SYS_PWD).  Its password is generated and saved in the Windows
User env MP_ADMIN_PWD and in the operator's password file.
   python pipeline.py --init-server [--dsn host:port/service]"""
import os, sys, secrets, string
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tools"))
import oracledb
from db import _env

DSN = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--dsn=")), os.environ.get("MP_DSN", "localhost:1521/ORCLPDB"))
PASSWORD_FILE = os.environ.get("MP_PASSWORD_FILE") or os.path.join(os.path.expanduser("~"), "Pictures", "passwords.txt")


def main():
    sys_pwd = _env("SYS_PWD")
    if not sys_pwd:
        sys.exit("set the Windows User environment variable SYS_PWD (SYS password of the database) first")
    c = oracledb.connect(user="sys", password=sys_pwd, dsn=DSN, mode=oracledb.AUTH_MODE_SYSDBA)
    cur = c.cursor()
    cur.execute("select count(*) from dba_users where username = 'MP_ADMIN'")
    pwd = _env("MP_ADMIN_PWD")
    if cur.fetchone()[0] and pwd:
        print("MP_ADMIN already set up on", DSN); return
    pwd = pwd or "M" + "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(19))
    cur.execute("select count(*) from dba_users where username = 'MP_ADMIN'")
    if cur.fetchone()[0]:
        cur.execute(f'alter user mp_admin identified by "{pwd}" account unlock')
    else:
        cur.execute(f'create user mp_admin identified by "{pwd}" default tablespace users quota unlimited on users')
    for g in ("dba", "apex_administrator_role", "execute on sys.dbms_ijob", "execute on sys.dbms_crypto",
              "execute on sys.dbms_lock", "select on sys.v_$session", "select on sys.v_$process"):
        with_opt = " with grant option" if g.startswith(("execute", "select")) else ""
        try:
            cur.execute(f"grant {g} to mp_admin{with_opt}")
        except oracledb.DatabaseError as e:
            print("  grant skipped:", g, str(e).splitlines()[0])
    import winreg
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment", 0, winreg.KEY_SET_VALUE) as k:
        winreg.SetValueEx(k, "MP_ADMIN_PWD", 0, winreg.REG_SZ, pwd)
    with open(PASSWORD_FILE, "a", encoding="utf-8") as fh:
        fh.write(f"Migration Pipeline admin user MP_ADMIN ({DSN}): MP_ADMIN_PWD = {pwd}\n")
    print("MP_ADMIN ready on", DSN, "(password in env MP_ADMIN_PWD and the password file)")


if __name__ == "__main__":
    main()
