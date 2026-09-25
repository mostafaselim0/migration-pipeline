"""Stage restore: load the client's dump into its own schema on this server and give it an APEX workspace.

   dump (classic exp or Data Pump, .zip allowed)
     -> schema <client.json "schema"> with its own password (Windows User env <SCHEMA>_PWD + password file)
     -> pass 1 structure only; imported jobs removed, DB links dropped, job queue stopped while loading
     -> every VARCHAR2/CHAR column switched to CHAR semantics (legacy AR8MSWIN1256 -> AL32UTF8 keeps Arabic text whole)
     -> pass 2 data with triggers and foreign keys disabled (legacy triggers must not re-run on historical rows)
     -> foreign keys and triggers back on, PL/SQL recompiled with CHAR semantics, statistics gathered
     -> APEX workspace <client.json "workspace"> on the schema
Writes work/restore.json.  Needs the server admin user MP_ADMIN (python pipeline.py --init-server)."""
import os, sys, re, io, json, glob, time, secrets, string, zipfile, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
ENGINE = os.path.dirname(HERE)
sys.path.insert(0, ENGINE); sys.path.insert(0, os.path.join(ENGINE, "tools"))
import mp
import oracledb
from db import _env

ORACLE_HOME = mp.CFG.get("oracle_home") or os.environ.get("MP_ORACLE_HOME") or r"C:\app\AdminUser\product\19.3.0\dbhome_1"
ADMIN = "MP_ADMIN"
GRANTS = ["create session", "create table", "create view", "create sequence", "create procedure", "create trigger", "create type",
          "create synonym", "create materialized view", "create job", "alter session", "unlimited tablespace"]
OBJ_GRANTS = ["execute on sys.dbms_crypto", "select on sys.v_$session", "select on sys.v_$process", "execute on sys.dbms_lock"]
LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    print(s, flush=True); LOG.append(s)


def admin():
    pwd = _env(ADMIN + "_PWD")
    if not pwd:
        sys.exit("MP_ADMIN is not set up on this server: run  python pipeline.py --init-server  once")
    return oracledb.connect(user=ADMIN, password=pwd, dsn=mp.DSN)


# ------------------------------------------------------------------ the dump
def locate_dump():
    d = mp.CFG.get("dump")
    if not d:
        cands = [p for p in glob.glob(os.path.join(mp.CDIR, "dump", "*")) if p.lower().endswith((".dmp", ".zip"))]
        if not cands:
            sys.exit(f"no dump: put the client's .dmp (or .zip) in {os.path.join(mp.CDIR, 'dump')} or set \"dump\" in client.json")
        d = sorted(cands, key=os.path.getmtime)[-1]
    d = os.path.abspath(d)
    if d.lower().endswith(".zip"):
        out = mp.work("dump")
        with zipfile.ZipFile(d) as z:
            dmp = [n for n in z.namelist() if n.lower().endswith(".dmp")]
            if not dmp:
                sys.exit(f"{d}: no .dmp inside")
            target = os.path.join(out, os.path.basename(dmp[0]))
            if not os.path.exists(target) or os.path.getsize(target) != z.getinfo(dmp[0]).file_size:
                log("unzipping", dmp[0], "->", out)
                with z.open(dmp[0]) as src, open(target, "wb") as dst:
                    while True:
                        b = src.read(1 << 24)
                        if not b: break
                        dst.write(b)
        d = target
    return d


def dump_header(path):
    """('exp', owner, mode) for a classic export, ('datapump', None, None) otherwise."""
    head = open(path, "rb").read(512)
    if b"EXPORT:V" in head[:64]:
        parts = head.split(b"\n")
        owner = parts[1][1:].decode("ascii", "replace") if len(parts) > 2 and parts[1][:1] == b"D" else None
        mode = parts[2][1:].decode("ascii", "replace") if len(parts) > 2 and parts[2][:1] == b"R" else None
        return "exp", owner, mode
    return "datapump", None, None


def run_tool(exe, par_lines, logname):
    """Run imp / impdp with a parameter file (the password never appears on a command line)."""
    import tempfile
    fd, par = tempfile.mkstemp(suffix=".par", prefix="mp_"); os.close(fd)     # imp cannot open a parfile path with spaces
    io.open(par, "w", encoding="ascii").write("\n".join([f"userid={ADMIN}/\"{_env(ADMIN + '_PWD')}\"@{mp.DSN}"] + par_lines) + "\n")
    env = dict(os.environ, NLS_LANG="AMERICAN_AMERICA.AL32UTF8", ORACLE_HOME=ORACLE_HOME)
    try:
        r = subprocess.run([os.path.join(ORACLE_HOME, "bin", exe), f"parfile={par}"], capture_output=True, text=True,
                           encoding="utf-8", errors="replace", env=env)
    finally:
        io.open(par, "w").write("")
        os.remove(par)
    out = (r.stdout or "") + (r.stderr or "")
    io.open(mp.work("restore", logname + ".out"), "w", encoding="utf-8").write(out)
    tail = [l for l in out.splitlines() if re.search(r"(IMP|ORA|UDI)-\d+|successfully|completed|terminated", l)]
    log(f"  {exe} {logname}: exit {r.returncode}; " + " / ".join(tail[-2:]))
    if "terminated unsuccessfully" in out or "UDI-" in out or (exe.startswith("impdp") and r.returncode == 1):
        raise SystemExit(f"{exe} failed: see {mp.work('restore', logname + '.out')}")
    return r.returncode, out


def qp(path):
    """A path value for an imp / impdp parameter file."""
    return '"' + path + '"'


def datapump_schemas(cur, path):
    """Schemas contained in a Data Pump file (read with SQLFILE, nothing is imported)."""
    rc, out = run_tool("impdp.exe", [f"directory={dump_dir(cur, path)}", f"dumpfile={os.path.basename(path)}",
                                     "sqlfile=mp_users.sql", "include=USER", f"logfile=mp_{mp.CLIENT}_users.log"], "users")
    sqlf = os.path.join(os.path.dirname(path), "mp_users.sql")
    users = re.findall(r'CREATE USER "([^"]+)"', io.open(sqlf, encoding="utf-8", errors="replace").read()) if os.path.exists(sqlf) else []
    return users


def dump_dir(cur, path):
    name = ("MP_DUMP_" + re.sub(r"\W", "_", mp.CLIENT.upper()))[:128]
    cur.execute(f"create or replace directory {name} as '{os.path.dirname(path)}'")
    return name


# ------------------------------------------------------------------ database side
def q_ident(s):
    return '"' + s.replace('"', "") + '"'


def ensure_schema(cur):
    s = mp.SCHEMA
    cur.execute("select count(*) from dba_users where username = :1", [s])
    exists = cur.fetchone()[0] > 0
    pwd = _env(s + "_PWD")
    if exists and mp.CFG.get("replace_schema"):
        log(f"dropping existing schema {s} (client.json replace_schema = true)")
        cur.execute(f"drop user {q_ident(s)} cascade"); exists = False
    elif exists:
        sys.exit(f"schema {s} already exists: set \"replace_schema\": true in client.json to rebuild it from the dump")
    if not pwd:
        pwd = random_password()
        remember_password(s + "_PWD", pwd, f"Oracle schema {s} (client {mp.CLIENT}, {mp.DSN})")
    cur.execute(f'create user {q_ident(s)} identified by "{pwd}" default tablespace users temporary tablespace temp quota unlimited on users')
    for g in GRANTS:
        cur.execute(f"grant {g} to {q_ident(s)}")
    for g in OBJ_GRANTS + list(mp.CFG.get("extra_grants") or []):
        try: cur.execute(f"grant {g} to {q_ident(s)}")
        except oracledb.DatabaseError as e: log("  grant skipped:", g, str(e).splitlines()[0])
    log(f"schema {s} created")


def random_password():
    a = string.ascii_letters + string.digits
    return "M" + "".join(secrets.choice(a) for _ in range(15))


def remember_password(var, value, what):
    import winreg
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment", 0, winreg.KEY_SET_VALUE) as k:
        winreg.SetValueEx(k, var, 0, winreg.REG_SZ, value)
    os.environ[var] = value
    with open(mp.PASSWORD_FILE, "a", encoding="utf-8") as fh:
        fh.write(f"{what}: {var} = {value}\n")
    log(f"  password for {what} saved (env {var} and the password file)")


def neutralize(cur):
    """Imported DBMS_JOB / scheduler jobs and DB links point at the client's live systems: remove them."""
    s = mp.SCHEMA; n = 0
    cur.execute("select job from dba_jobs where schema_user = :1", [s])
    for (job,) in cur.fetchall():
        cur.execute("begin sys.dbms_ijob.remove(:1); end;", [job]); n += 1
    cur.execute("select job_name from dba_scheduler_jobs where owner = :1", [s])
    for (job,) in cur.fetchall():
        cur.execute("begin dbms_scheduler.drop_job(:1, force => true); end;", [f'"{s}"."{job}"']); n += 1
    cur.execute("select db_link from dba_db_links where owner = :1", [s])
    links = [r[0] for r in cur.fetchall()]
    if links:
        cur.execute(f"""create or replace procedure {q_ident(s)}.mp_drop_link(p varchar2) is
                        begin execute immediate 'drop database link ' || p; end;""")
        for l in links:
            cur.execute(f"begin {q_ident(s)}.mp_drop_link(:1); end;", [l])
        cur.execute(f"drop procedure {q_ident(s)}.mp_drop_link")
    return n, links


def failed_statements(text):
    """Statements imp could not run (IMP-00017), rebuilt from its log: imp prints each source line in quoted chunks of a
    fixed width, so a chunk of full width continues on the next one."""
    parts = re.split(r"IMP-00017: following statement failed with ORACLE error (\d+):\r?\n", text)
    raw = []
    for err, body in zip(parts[1::2], parts[2::2]):
        segs = []
        for line in body.splitlines():
            if line.startswith(' "') and line.endswith('"'):
                segs.append(line[2:-1])
            else:
                break
        raw.append((int(err), segs))
    width = max((len(s) for _, segs in raw for s in segs), default=0)
    return [(err, "".join(s + ("" if len(s) == width else "\n") for s in segs).rstrip("\n")) for err, segs in raw]


def replay_remapped(cur, outfile, src):
    """Classic imp remaps the owner of each object but not schema names written inside DDL (a trigger 'ON LEGACY_OWNER.T').
    Re-run those statements with the source schema replaced by the client's."""
    text = io.open(outfile, encoding="utf-8", errors="replace").read()
    qual = re.compile(r'(?i)"?\b' + re.escape(src) + r'\b"?\s*\.')
    done, failed = [], []
    for err, sql in failed_statements(text):
        if err != 942 or not qual.search(sql):
            continue
        sql2 = qual.sub(f'"{mp.SCHEMA}".', sql)
        name = re.search(r'(?i)create\s+(?:or\s+replace\s+)?(\w+(?:\s+body)?)\s+("?[\w$#]+"?\.)?"?([\w$#]+)', sql2)
        label = f"{name.group(1).upper()} {name.group(3)}" if name else sql2[:60]
        try:
            cur.execute(sql2); done.append(label)
        except oracledb.DatabaseError as e:
            failed.append(f"{label}: {str(e).splitlines()[0]}")
    log(f"statements re-run with schema {src} -> {mp.SCHEMA}: {len(done)} ok, {len(failed)} failed")
    return done, failed


def char_semantics(cur):
    s = mp.SCHEMA
    cur.execute("""select c.table_name, c.column_name, c.data_type, c.char_length from dba_tab_columns c
                    join dba_tables t on t.owner = c.owner and t.table_name = c.table_name
                   where c.owner = :1 and c.char_used = 'B' and c.data_type in ('VARCHAR2', 'CHAR') and t.table_name not like 'BIN$%'
                   order by 1, 2""", [s])
    cols = cur.fetchall(); bad = []
    for t, c, dt, n in cols:
        try:
            cur.execute(f'alter table {q_ident(s)}.{q_ident(t)} modify ({q_ident(c)} {dt}({n} char))')
        except oracledb.DatabaseError as e:
            bad.append(f"{t}.{c}: {str(e).splitlines()[0]}")
    log(f"CHAR semantics: {len(cols) - len(bad)} of {len(cols)} columns converted" + (f"; {len(bad)} failed (first: {bad[0]})" if bad else ""))
    return len(cols), bad


def set_triggers_fks(cur, enable, state=None):
    s = mp.SCHEMA
    if not enable:
        cur.execute("select trigger_name from dba_triggers where owner = :1 and status = 'ENABLED' and base_object_type = 'TABLE'", [s])
        trg = [r[0] for r in cur.fetchall()]
        cur.execute("select table_name, constraint_name from dba_constraints where owner = :1 and constraint_type = 'R' and status = 'ENABLED'", [s])
        fks = cur.fetchall()
        for t in trg:
            cur.execute(f"alter trigger {q_ident(s)}.{q_ident(t)} disable")
        for t, c in fks:
            cur.execute(f"alter table {q_ident(s)}.{q_ident(t)} disable constraint {q_ident(c)}")
        return {"triggers": trg, "fks": fks}
    novalidate = []
    for t, c in state["fks"]:
        try:
            cur.execute(f"alter table {q_ident(s)}.{q_ident(t)} enable constraint {q_ident(c)}")
        except oracledb.DatabaseError:
            cur.execute(f"alter table {q_ident(s)}.{q_ident(t)} enable novalidate constraint {q_ident(c)}")
            novalidate.append(f"{t}.{c}")
    for t in state["triggers"]:
        cur.execute(f"alter trigger {q_ident(s)}.{q_ident(t)} enable")
    return novalidate


def compile_and_stats(cur):
    s = mp.SCHEMA
    cur.execute("alter session set nls_length_semantics = CHAR")
    cur.execute("begin dbms_utility.compile_schema(schema => :1, compile_all => true, reuse_settings => false); end;", [s])
    cur.execute("begin dbms_stats.gather_schema_stats(ownname => :1, degree => 4); end;", [s])
    cur.execute("select object_type || ' ' || object_name from dba_objects where owner = :1 and status = 'INVALID' order by 1", [s])
    return [r[0] for r in cur.fetchall()]


def workspace(cur):
    """The client's own APEX workspace on its (just re-created) schema.  An existing workspace of that name is removed
    first: APEX keeps the assignment of the dropped schema and refuses the new one (WORKSPACE_NOT_ASSIGNED).  Its
    applications go with it; the build stage installs them again."""
    ws, s = mp.WORKSPACE, mp.SCHEMA
    cur.execute("select workspace_id from apex_workspaces where workspace = :1", [ws])
    if cur.fetchone():
        cur.execute("begin apex_instance_admin.remove_workspace(p_workspace => :1, p_drop_users => 'N', p_drop_tablespaces => 'N'); end;", [ws])
        log(f"APEX workspace {ws} removed (re-created on the new schema)")
    cur.execute("begin apex_instance_admin.add_workspace(p_workspace => :1, p_primary_schema => :2); end;", [ws, s])
    cur.execute("select workspace_id from apex_workspaces where workspace = :1", [ws])
    r = cur.fetchone()
    log(f"APEX workspace {ws} created ({r[0]})")
    json.dump({"workspace": ws, "id": int(r[0])}, io.open(mp.work("cache", "workspace.json"), "w", encoding="utf-8"))
    return int(r[0])


# ------------------------------------------------------------------ main
QUIET_PREV = None


def main():
    global QUIET_PREV
    t0 = time.time()
    path = locate_dump()
    kind, owner, mode = dump_header(path)
    c = admin(); cur = c.cursor()
    src = (mp.CFG.get("source_schema") or owner or "").upper()
    if kind == "datapump" and not src:
        users = datapump_schemas(cur, path)
        if len(users) != 1:
            sys.exit(f"the dump holds schemas {users}: set \"source_schema\" in client.json")
        src = users[0]
    log(f"dump {path} ({os.path.getsize(path) // 2**20} MB): {kind}{' mode ' + mode if mode else ''}, source schema {src} -> {mp.SCHEMA}")
    ensure_schema(cur)
    cur.execute("select value from v$parameter where name = 'job_queue_processes'"); QUIET_PREV = cur.fetchone()[0]
    cur.execute("alter system set job_queue_processes = 0")
    try:
        # pass 1: structure
        if kind == "exp":
            run_tool("imp.exe", [f"file={qp(path)}", f"fromuser={src}", f"touser={mp.SCHEMA}", "rows=n", "ignore=y", "grants=n",
                                 "statistics=none", f"log={qp(mp.work('restore', 'imp_structure.log'))}"], "imp_structure")
            remapped = replay_remapped(cur, mp.work("restore", "imp_structure.out"), src)
        else:
            d = dump_dir(cur, path)
            run_tool("impdp.exe", [f"directory={d}", f"dumpfile={os.path.basename(path)}", f"remap_schema={src}:{mp.SCHEMA}",
                                   "content=metadata_only", "transform=segment_attributes:n",
                                   "exclude=USER,SYSTEM_GRANT,ROLE_GRANT,DEFAULT_ROLE,TABLESPACE_QUOTA,DB_LINK,JOB,PROCOBJ,STATISTICS",
                                   f"logfile=mp_{mp.CLIENT}_structure.log"], "impdp_structure")
            remapped = ([], [])                                        # Data Pump remaps schema names inside DDL itself
        jobs, links = neutralize(cur)
        ncols, badcols = char_semantics(cur)
        state = set_triggers_fks(cur, False)
        log(f"disabled for loading: {len(state['triggers'])} triggers, {len(state['fks'])} foreign keys")
        # pass 2: data
        if kind == "exp":
            run_tool("imp.exe", [f"file={qp(path)}", f"fromuser={src}", f"touser={mp.SCHEMA}", "rows=y", "ignore=y", "indexes=n",
                                 "constraints=n", "grants=n", "statistics=none", "commit=y", "buffer=20971520",
                                 f"log={qp(mp.work('restore', 'imp_data.log'))}"], "imp_data")
            state2 = set_triggers_fks(cur, False)                      # pass 2 re-creates nothing new, but be sure
            state["triggers"] = sorted(set(state["triggers"]) | set(state2["triggers"]))
        else:
            run_tool("impdp.exe", [f"directory={dump_dir(cur, path)}", f"dumpfile={os.path.basename(path)}",
                                   f"remap_schema={src}:{mp.SCHEMA}", "content=data_only", "data_options=skip_constraint_errors",
                                   f"logfile=mp_{mp.CLIENT}_data.log"], "impdp_data")
        j2, l2 = neutralize(cur)
        novalidate = set_triggers_fks(cur, True, state)
    finally:
        cur.execute(f"alter system set job_queue_processes = {int(QUIET_PREV)}")
    invalid = compile_and_stats(cur)
    wsid = workspace(cur)
    cur.execute("select count(*), nvl(sum(num_rows), 0) from dba_tables where owner = :1", [mp.SCHEMA]); ntab, nrows = cur.fetchone()
    cur.execute("select object_type, count(*) from dba_objects where owner = :1 group by object_type order by 1", [mp.SCHEMA])
    objects = dict(cur.fetchall())
    rej = []
    for f in glob.glob(mp.work("restore", "*.out")):
        rej += [l for l in io.open(f, encoding="utf-8").read().splitlines() if re.search(r"ORA-12899|ORA-01401|IMP-00019|ORA-31693|ORA-29913", l)]
    res = {"dump": path, "kind": kind, "source_schema": src, "schema": mp.SCHEMA, "workspace": mp.WORKSPACE, "workspace_id": wsid,
           "tables": ntab, "rows": int(nrows), "objects": objects, "char_columns_converted": ncols - len(badcols), "char_failed": badcols,
           "jobs_removed": jobs + j2, "db_links_dropped": sorted(set(links + l2)), "fk_novalidate": novalidate,
           "remapped_ok": remapped[0], "remapped_failed": remapped[1],
           "rejected_row_messages": len(rej), "rejected_sample": rej[:20], "invalid_objects": invalid,
           "seconds": round(time.time() - t0), "log": LOG}
    json.dump(res, io.open(mp.work("restore.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    log(f"restored {ntab} tables / {nrows} rows in {res['seconds']} s; invalid objects {len(invalid)}; "
        f"FKs left NOVALIDATE {len(novalidate)}; rejected-row messages {len(rej)}")


if __name__ == "__main__":
    main()
