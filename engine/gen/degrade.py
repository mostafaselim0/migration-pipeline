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

LOG = {"skipped_rules": [], "dropped_triggers": [], "isolated_members": [], "invalid_left": []}
MEMBER = re.compile(r"(?i)^  (procedure|function)\s+(\w+)")


def save():
    json.dump(LOG, io.open(mp.work("build", "degraded.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


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


def isolate_members(cur, max_rounds=6):
    """For every invalid APP_* package body: stub the failing members until it compiles (or no progress)."""
    cur.execute("alter session set nls_length_semantics = CHAR")
    cur.execute("select object_name from user_objects where object_type = 'PACKAGE BODY' and status = 'INVALID' "
                "and object_name like 'APP\\_%' escape '\\' order by 1")
    for (pkg,) in cur.fetchall():
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
        for n in done:
            LOG["isolated_members"].append(f"{pkg}.{n}")
        if not ok:
            LOG["invalid_left"].append(pkg)
        print(f"   {pkg}: {len(done)} member(s) switched off pending review -> {'valid' if ok else 'STILL INVALID'}"
              + (f" ({', '.join(done[:8])})" if done else ""))
