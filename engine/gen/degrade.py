"""Graceful degradation when the product knowledge does not fit a client's database exactly (another version, fewer
modules, different columns).  Nothing is silently dropped: every step is recorded in work/build/degraded.json and in the
report, so the review knows exactly which reviewed rules are switched off for this installation.

   rule_refs_ok     generated trigger rules that use :new/:old columns the table does not have are left out
   isolate_members  a knowledge package body that does not compile keeps working: only its failing procedures / functions
                    are replaced by a stub raising ORA-20990 "needs review for this installation" (members are written
                    two-space indented, 'procedure x ... end x;', see knowledge/*/contracts)"""
import os, sys, re, io, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE)); sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tools"))
import mp

LOG = {"skipped_rules": [], "dropped_triggers": [], "isolated_members": [], "stubbed_packages": [], "script_errors": [], "invalid_left": []}
CORE = set()          # engine runtime packages (engine/db): never degraded - if they do not compile the build stops (build.py sets it)
MEMBER = re.compile(r"(?i)^  (procedure|function)\s+(\w+)")


def spec_subprograms(spec):
    """(kind, name, declaration text) of every procedure / function declared in a package spec."""
    s = re.sub(r"--[^\n]*", "", spec)
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    out = []
    for m in re.finditer(r"(?i)\b(procedure|function)\s+(\w+)", s):
        i, depth, quote = m.start(), 0, None
        j = i
        while j < len(s):
            ch = s[j]
            if quote:
                if ch == quote: quote = None
            elif ch in ("'", '"'): quote = ch
            elif ch == "(": depth += 1
            elif ch == ")": depth -= 1
            elif ch == ";" and depth == 0: break
            j += 1
        out.append((m.group(1).lower(), m.group(2), re.sub(r"\s+", " ", s[i:j]).strip()))
    return out


def stub_body_from_spec(cur, pkg):
    """Last resort for a knowledge package body that cannot be repaired member by member (errors in its package-level
    declarations, e.g. a cursor over a table this installation lacks): a body in which every subprogram of the spec raises
    ORA-20990 "needs review".  The package stays VALID, so every other page keeps working and each use of it fails with a
    clear message instead of ORA-04063."""
    cur.execute("select text from user_source where name = :1 and type = 'PACKAGE' order by line", [pkg])
    spec = "".join(r[0] for r in cur.fetchall())
    subs = spec_subprograms(spec)
    if not subs:
        return False
    body = [f"create or replace package body {pkg} as\n"]
    for kind, name, decl in subs:
        body.append(f"  {decl} is\n  begin\n"
                    f"    raise_application_error(-20990, 'Needs review for this installation: {pkg.lower()}.{name.lower()} "
                    f"(rule of the product knowledge that does not fit this database)');\n  end {name};\n")
    body.append(f"end {pkg};\n")
    try:
        cur.execute("".join(body))
    except Exception as e:
        LOG["script_errors"].append(f"{pkg}: whole-body stub failed: {str(e).splitlines()[0]}")
        return False
    cur.execute("select status from user_objects where object_type = 'PACKAGE BODY' and object_name = :1", [pkg])
    return cur.fetchone()[0] == "VALID"


def save():
    json.dump(LOG, io.open(mp.work("build", "degraded.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def load():
    """Merge what an earlier step of this build recorded (build.py db and apex run as separate processes)."""
    p = mp.work("build", "degraded.json")
    if os.path.exists(p):
        for k, v in json.load(io.open(p, encoding="utf-8")).items():
            LOG.setdefault(k, [])
            LOG[k] = v + [x for x in LOG[k] if x not in v]
    return LOG


def switched_off_pattern():
    """Regex matching a call to any package member switched off by isolate_members / stub_body_from_spec, or None."""
    load()
    pats = [re.escape(m).replace(r"\.", r"\.") + r"\b" for m in LOG.get("isolated_members", [])]
    pats += [re.escape(p) + r"\.\w+" for p in LOG.get("stubbed_packages", [])]
    return re.compile("(?i)\\b(" + "|".join(pats) + ")") if pats else None


RUNTIME_ERR = re.compile(r"ORA-(20\d{3}|01403|06502|01422|00942|00904|01476|01722|06503|04063|04068|06550)")
BIND = re.compile(r"(?<![\w:]):[A-Za-z]\w*")          # :PAGE_X / :P123_X / :G_LANG -> null when a fragment is evaluated


def probe_defaults(specs, cur):
    """Item defaults are evaluated when a page renders; a default that raises (a member of the knowledge that runs but
    does not fit this data, e.g. 'needs review' or no_data_found) would break the whole page.  Evaluate every SQL and
    expression default once, with the page items null, and drop the ones that raise a runtime error."""
    n = 0

    def fails(sql):
        try:
            cur.execute("select * from (" + BIND.sub("null", sql) + ") where rownum <= 1")
            cur.fetchall()
            return None
        except Exception as e:
            msg = str(e).splitlines()[0]
            return msg if RUNTIME_ERR.search(msg) else None

    for s in specs:
        infos = (s.get("rules") or {}).get("info")
        if infos:
            keep = []
            for inf in infos:
                why = fails(inf.get("sql") or "select null from dual")
                if why:
                    LOG["skipped_rules"].append(f"{s['form']}: info value {inf.get('name')} dropped, it fails on this data ({why[:100]})"); n += 1
                else:
                    keep.append(inf)
            s["rules"]["info"] = keep
        blocks = ([s.get("master")] if s.get("master") else []) + s.get("details", [])
        for b in blocks:
            for c in b.get("cols", []):
                d = c.get("default")
                if not (isinstance(d, dict) and d.get("value") and d.get("type") in ("SQL_QUERY", "EXPRESSION")):
                    continue
                v = str(d["value"])
                why = fails(v if d["type"] == "SQL_QUERY" else f"select ({v}) from dual")
                if why:
                    LOG["skipped_rules"].append(f"{s['form']}: default of {b['table']}.{c['name']} dropped, it fails on this data ({why[:100]})")
                    c["default"] = None; n += 1
    return n


def scrub_specs(specs):
    """Rendering-time fragments (defaults, computed columns, lists of values, filters) that call a switched-off member would
    break the page with ORA-20990 before the user sees it: they are dropped and listed.  Validations and save-time rules keep
    calling the stub, so a save fails with the explicit 'needs review' message instead of silently skipping the rule."""
    pat = switched_off_pattern()
    if not pat:
        return 0
    n = 0
    for s in specs:
        for key in ("actions", "links", "fills"):    # document buttons: condition, call and message of the reviewed action
            items = s.get(key)
            if not items:
                continue
            keep = []
            for a in items:
                text = " ".join(str(a.get(k) or "") for k in ("condition", "call", "message", "when", "sql"))
                m = pat.search(text)
                if m:
                    LOG["skipped_rules"].append(f"{s['form']}: button {a.get('name') or a.get('label_e') or key} dropped, it calls {m.group(1)} (switched off)")
                    n += 1
                else:
                    keep.append(a)
            s[key] = keep
        infos = (s.get("rules") or {}).get("info")
        if infos:                                    # info panel of a document: one SQL per displayed value
            keep = []
            for inf in infos:
                if pat.search(inf.get("sql") or ""):
                    LOG["skipped_rules"].append(f"{s['form']}: info value {inf.get('name')} dropped, it calls {pat.search(inf['sql']).group(1)} (switched off)")
                    n += 1
                else:
                    keep.append(inf)
            s["rules"]["info"] = keep
        blocks = ([s.get("master")] if s.get("master") else []) + s.get("details", [])
        for b in blocks:
            for key in ("where", "dwhere"):
                if b.get(key) and pat.search(b[key]):
                    LOG["skipped_rules"].append(f"{s['form']}: filter of {b['table']} dropped, it calls {pat.search(b[key]).group(1)} (switched off)")
                    b[key] = None; n += 1
            keep = []
            for c in b.get("cols", []):
                d = c.get("default")
                if isinstance(d, dict) and d.get("value") and pat.search(str(d["value"])):
                    LOG["skipped_rules"].append(f"{s['form']}: default of {b['table']}.{c['name']} dropped, it calls {pat.search(str(d['value'])).group(1)} (switched off)")
                    c["default"] = None; n += 1
                if c.get("lov_sql") and pat.search(c["lov_sql"]):
                    LOG["skipped_rules"].append(f"{s['form']}: list of values of {b['table']}.{c['name']} dropped, it calls {pat.search(c['lov_sql']).group(1)} (switched off)")
                    c.pop("lov_sql", None); c.pop("cascade", None); c["lov"] = None
                    if c.get("widget") in ("SELECT", "POPUP"):
                        c["widget"] = "NUMBER" if c.get("type") in ("NUMBER", "FLOAT") else "TEXT"
                    n += 1
                if c.get("sql") and c.get("computed") and pat.search(c["sql"]):
                    LOG["skipped_rules"].append(f"{s['form']}: computed column {b['table']}.{c['name']} dropped, it calls {pat.search(c['sql']).group(1)} (switched off)")
                    n += 1; continue
                keep.append(c)
            b["cols"] = keep
    return n


def rule_refs_ok(table, cols, code, what):
    """True when every :new.X / :old.X in the code is a column of the table; otherwise the rule is recorded as skipped."""
    miss = sorted({m.upper() for m in re.findall(r"(?i):(?:new|old)\.(\w+)", code)} - set(cols))
    if miss:
        LOG["skipped_rules"].append(f"{table}: {what} left out, columns {', '.join(miss)} do not exist in this installation")
        return False
    return True


def _stub(lines, err_lines, pkg):
    """Replace the members containing the error lines (1-based) by a raising stub.  Returns (new lines, member names)."""
    names, out = [], list(lines)
    spans = []
    for el in sorted(set(err_lines)):
        start = next((i for i in range(min(el, len(lines)) - 1, -1, -1) if MEMBER.match(lines[i])), None)
        if start is None:
            continue
        name = MEMBER.match(lines[start]).group(2)
        end = next((j for j in range(start + 1, len(lines)) if re.match(rf"(?i)^  end\s+{name}\s*;", lines[j])), None)
        hdr = next((j for j in range(start, end or start) if re.search(r"(?i)\b(is|as)\s*(--.*)?$", lines[j])), None)
        if end is None or hdr is None or el - 1 > end or any(s[0] == start for s in spans):
            continue                                                # not inside a member (package-level declaration)
        spans.append((start, hdr, end, name))
    for start, hdr, end, name in sorted(spans, reverse=True):
        out[hdr + 1:end] = ["  begin\n",
                            f"    raise_application_error(-20990, 'Needs review for this installation: {pkg.lower()}.{name.lower()} "
                            "(rule of the product knowledge that does not fit this database)');\n"]
        names.append(name)
    return out, names


def isolate_members(cur, max_rounds=40):
    """For every invalid APP_* package body: stub the failing members until it compiles (or no progress); the compiler
    reports at most 20 errors per compilation, hence the many rounds.  A body that still does not compile is replaced
    by a body of stubs (stub_body_from_spec)."""
    cur.execute("alter session set nls_length_semantics = CHAR")
    cur.execute("select object_name from user_objects where object_type = 'PACKAGE BODY' and status = 'INVALID' "
                "and object_name like 'APP\\_%' escape '\\' order by 1")
    invalid = [r[0] for r in cur.fetchall()]
    core_bad = [p for p in invalid if p in CORE]
    if core_bad:                     # the runtime every client gets (sign-in, menu, printing) must compile as it is
        msgs = []
        for p in core_bad:
            cur.execute("select line, text from user_errors where name = :1 and type = 'PACKAGE BODY' and attribute = 'ERROR' order by sequence", [p])
            msgs += [f"{p} line {l}: {t.strip()[:160]}" for l, t in cur.fetchmany(6)]
        sys.exit("engine runtime package(s) do not compile on this schema (usually a missing grant: execute on sys.dbms_crypto, "
                 "select on sys.v_$session ... - see engine/stages/restore.py OBJ_GRANTS):\n   " + "\n   ".join(msgs))
    for pkg in invalid:
        done = []
        for _ in range(max_rounds):
            cur.execute("select line from user_errors where name = :1 and type = 'PACKAGE BODY' and attribute = 'ERROR'", [pkg])
            errs = [r[0] for r in cur.fetchall()]
            if not errs:
                break
            cur.execute("select text from user_source where name = :1 and type = 'PACKAGE BODY' order by line", [pkg])
            lines = [r[0] for r in cur.fetchall()]
            new, names = _stub(lines, errs, pkg)
            if not names:
                break
            done += names
            try:
                cur.execute("create or replace " + "".join(new))
            except Exception:
                pass                                                # compiled with errors: next round looks again
        cur.execute("select status from user_objects where object_type = 'PACKAGE BODY' and object_name = :1", [pkg])
        ok = cur.fetchone()[0] == "VALID"
        whole = False
        if not ok:
            whole = stub_body_from_spec(cur, pkg)
            ok = whole
        if whole:
            LOG["stubbed_packages"].append(pkg)
        else:
            for n in done:
                LOG["isolated_members"].append(f"{pkg}.{n}")
        if not ok:
            LOG["invalid_left"].append(pkg)
        print(f"   {pkg}: " + (f"every member switched off pending review (package-level declarations do not fit) -> {'valid' if ok else 'STILL INVALID'}"
                               if whole or not ok and not done else
                               f"{len(done)} member(s) switched off pending review -> {'valid' if ok else 'STILL INVALID'}"
                               + (f" ({', '.join(done[:8])})" if done else "")))
