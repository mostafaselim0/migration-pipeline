"""Optional stage llm: draft reviewed-rule overrides for the screens the delta could not cover (work/llm/worklist.json).

It is the only stage that uses a language model, and it is never part of a normal run:
   python pipeline.py <client> llm --prepare              write one compact prompt per screen (no model call); a person
                                                          can paste them into Claude and save the answers (see docs/LLM.md)
   python pipeline.py <client> llm --import               validate answers saved as work/llm/answers/<FORM>.json
   python pipeline.py <client> llm --budget 300000        call the Anthropic API (pip install anthropic, env ANTHROPIC_API_KEY)
          [--max 20] [--model claude-sonnet-5] [FORM ...] until the token budget is spent
Sending a client's legacy code to the API is a data transfer to an external service: only run it with the client's consent.

Token economy: the brief is identical for every screen (prompt-cached); each prompt carries only this screen's structure and
its business-logic triggers (navigation, key and cosmetic triggers are left out), cut to --chars (default 20000).
Every answer is checked against the client's database before it is written: SQL is parsed, PL/SQL compiled, columns
must exist; anything that fails is dropped and turned into a question.  Drafts go to overlay/overrides/<FORM>.json with
"_review": "llm draft" and are used by the next generate/build, so they must be reviewed (docs/LLM.md)."""
import os, sys, re, io, json, time
HERE = os.path.dirname(os.path.abspath(__file__))
ENGINE = os.path.dirname(HERE)
sys.path.insert(0, ENGINE); sys.path.insert(0, os.path.join(ENGINE, "tools"))
import mp
from db import connect

LOGIC_CLASSES = {"validation", "transaction", "derivation", "action", "navigation/defaulting", "record-lifecycle"}
ARGS = sys.argv[1:]


def opt(name, default=None, cast=str):
    if name in ARGS:
        i = ARGS.index(name)
        return cast(ARGS[i + 1]) if i + 1 < len(ARGS) and not ARGS[i + 1].startswith("--") else True
    return default


def load(*p):
    path = mp.work(*p)
    return json.load(io.open(path, encoding="utf-8")) if os.path.exists(path) else None


def squeeze(s):
    s = re.sub(r"/\*.*?\*/", "", s or "", flags=re.S)
    s = "\n".join(l.rstrip() for l in s.splitlines() if l.strip() and not l.strip().startswith("--"))
    return re.sub(r"[ \t]+", " ", s)


def screen_text(spec, meta):
    """The generated screen: pattern, blocks, columns (name type key/null), current rules."""
    L = [f"Screen {spec['form']}: {spec.get('title_a')} / {spec.get('title_e')}; pattern {spec['pattern']}"]
    for role, b in [("master", spec.get("master"))] + [("detail", d) for d in spec.get("details", [])]:
        if not b:
            continue
        t = meta.get(b["table"], {})
        cols = ", ".join(f"{c['name']} {c['type']}{' PK' if c['name'] in t.get('pk', []) else ''}{'' if c['nullable'] else ' NN'}"
                         for c in t.get("cols", []))
        L.append(f"{role} {b['table']}{' join ' + str(b.get('join')) if b.get('join') else ''}: {cols}")
    return "\n".join(L)


def legacy_text(form, cat, limit):
    f = next((x for x in cat.get("forms", []) if (x.get("form") or "").upper() == form), None)
    out = []
    residue = load("transpiled", form + ".residue.json")
    if f and residue is not None:
        # the transpiler already turned the plain triggers into rules: only what it could not express is sent
        out.append("-- rules already transpiled from the plain triggers; only the triggers below still need a rule set")
        for r in residue:
            if r.get("severity") != "low":
                out.append(f"-- {r['trigger']} {r.get('block') or ''}.{r.get('item') or ''} (not transpiled: {r['reason']})\n{squeeze(r['text'])}")
        f = dict(f, triggers=[])
    if f:
        for b in f["blocks"]:
            if b.get("where"):
                out.append(f"block {b['block']} where: {squeeze(b['where'])}")
        for t in f["triggers"]:
            if t["class"] in LOGIC_CLASSES and t.get("text"):
                out.append(f"-- {t['level']} {t.get('block') or ''}.{t.get('item') or ''} {t['name']}\n{squeeze(t['text'])}")
        for p in f["program_units"]:
            if p.get("text"):
                out.append(f"-- program unit {p['name']}\n{squeeze(p['text'])}")
        for it in f["items"]:
            if it.get("list_elements"):
                out.append(f"-- list {it['block']}.{it['item']}: {it['list_elements']}")
    d = next((x for x in cat.get("fmx", []) if x["form"].upper() == form), None)
    if d:
        out.append("-- SQL found in the compiled form:\n" + "\n".join(sorted({squeeze(s) for s in d.get("sql_snippets", [])})))
        out.append("-- messages in the compiled form: " + " | ".join(d.get("arabic_labels", [])[:60]))
    text = "\n".join(out)
    return text[:limit] + ("\n-- (cut)" if len(text) > limit else "")


def prompt_for(w, spec, meta, cat, limit):
    parts = [screen_text(spec, meta)]
    prod = mp.kpath("overrides", w["form"] + ".json")
    if w["status"] == "CHANGED" and prod and os.path.commonpath([prod, mp.KNOWLEDGE]) == mp.KNOWLEDGE:
        parts.append("The product's reviewed override for this screen (its legacy code differs at this client: "
                     f"{', '.join(w['diff'])}). Return the full override adjusted to the legacy code below:\n"
                     + io.open(prod, encoding="utf-8").read())
    parts.append("Legacy business logic of the screen:\n" + legacy_text(w["form"], cat, limit))
    return "\n\n".join(parts)


# ------------------------------------------------------------------ validation against the client's database
def check(form, ov, meta, cur):
    """Drop what does not work on this database; returns (clean override, problems)."""
    probs = []
    rules = ov.get("rules") or {}
    binds = lambda s: {b: None for b in set(re.findall(r":(\w+)", s)) if not re.match(r"(?i)^(new|old)$", b)}

    def sql_ok(sql, what):
        try:
            cur.execute(f"select * from ({sql}) where 1 = 0", binds(sql)); return True
        except Exception as e:
            probs.append(f"{what}: {str(e).splitlines()[0]}"); return False

    def plsql_ok(body, what):
        blk = f"declare function f return varchar2 is begin {body}\nend; begin null; end;"
        try:
            cur.execute(blk, binds(body)); return True
        except Exception as e:
            probs.append(f"{what}: {' '.join(str(e).splitlines()[:2])}"); return False

    def trig_ok(table, code, what):
        try:
            cur.execute(f'create or replace trigger "MP_LLM_CHECK" before insert or update on {table} for each row disable\nbegin\n{code}\nend;')
            cur.execute("select count(*) from user_errors where name = 'MP_LLM_CHECK'"); n = cur.fetchone()[0]
            if n:
                cur.execute("select text from user_errors where name = 'MP_LLM_CHECK' order by sequence")
                probs.append(f"{what}: {cur.fetchone()[0]}")
            return n == 0
        except Exception as e:
            probs.append(f"{what}: {str(e).splitlines()[0]}"); return False
        finally:
            try: cur.execute('drop trigger "MP_LLM_CHECK"')
            except Exception: pass

    def col_ok(tc, what):
        t, _, c = tc.upper().rpartition(".")
        t = t or ((ov.get("master") or {}).get("table") or "").upper()
        if t in meta and c in {x["name"] for x in meta[t]["cols"]}:
            return True
        probs.append(f"{what}: column {tc} does not exist"); return False

    for k in ("readonly", "hidden", "optional"):
        if k in rules: rules[k] = [c for c in rules[k] if col_ok(c, k)]
    for tc, v in list((rules.get("columns") or {}).items()):
        if not col_ok(tc, "columns") or (isinstance(v.get("lov"), str) and not sql_ok(v["lov"], f"lov {tc}")):
            rules["columns"].pop(tc)
    for tc, v in list((rules.get("computed") or {}).items()):
        t = tc.upper().rpartition(".")[0]
        if t not in meta or not sql_ok(f"select {v.get('sql')} x from {t} t", f"computed {tc}"):
            rules["computed"].pop(tc)
    for tc, v in list((rules.get("defaults") or {}).items()):
        if not col_ok(tc, "defaults") or (v.get("type") == "SQL_QUERY" and not sql_ok(v.get("value", ""), f"default {tc}")):
            rules["defaults"].pop(tc)
    for tc, expr in list((rules.get("key_expr") or {}).items()):
        t = tc.upper().rpartition(".")[0]
        if not col_ok(tc, "key_expr") or not trig_ok(t, f":new.{tc.rpartition('.')[2]} := {expr};", f"key_expr {tc}"):
            rules["key_expr"].pop(tc)
    for t, code in list((rules.get("row_rules") or {}).items()):
        if t.upper() not in meta or not trig_ok(t, code, f"row_rules {t}"):
            rules["row_rules"].pop(t)
    for k in ("validations", "after_save"):
        if k in rules:
            rules[k] = [v for v in rules[k] if plsql_ok(v.get("plsql", "") if k == "validations" else f"{v.get('plsql', '')}\nreturn null;",
                                                          f"{k} {v.get('name')}")]
    if rules.get("where"):
        t = ((ov.get("master") or {}).get("table") or "")
        if t and not sql_ok(f"select 1 from {t} where {rules['where']}", "where"):
            rules.pop("where")
    return ov, probs


def save_draft(form, ans, meta, cur, model):
    ov = ans.get("override") or {}
    ov, probs = check(form, ov, meta, cur)
    ov["_review"] = f"llm draft ({model}, {time.strftime('%Y-%m-%d')}): review before production"
    ov["_questions"] = list(ans.get("questions") or []) + [f"dropped (did not work on this database): {p}" for p in probs]
    ov["_confidence"] = ans.get("confidence")
    p = os.path.join(mp.OVERLAY, "overrides", form + ".json")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    json.dump(ov, io.open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return p, probs


def parse_answer(text):
    m = re.search(r"\{.*\}", text, re.S)
    return json.loads(m.group(0)) if m else {}


def main():
    work = load("llm", "worklist.json") or []
    forms, skip = [], False
    for a in ARGS:                                                    # screen names given on the command line
        if skip or a in ("--budget", "--max", "--model", "--chars"):
            skip = not skip; continue
        if not a.startswith("--"):
            forms.append(a.upper())
    if forms:
        known = {w["form"]: w for w in work}
        dscr = (load("delta.json") or {}).get("screens", {})
        work = [known.get(f) or dict(dscr.get(f, {"status": "NEW", "diff": []}), form=f) for f in forms]
    work = work[:opt("--max", len(work), int)]
    specs = {s["form"].upper(): s for s in (load("out", "specs.json") or {}).get("specs", [])}
    meta, cat = load("cache", "meta.json") or {}, load("cache", "catalog.json") or {}
    brief = io.open(mp.kpath("contracts", "LLM_BRIEF.md"), encoding="utf-8").read()
    limit = opt("--chars", 20000, int)
    model = opt("--model", "claude-sonnet-5")
    pdir = mp.work("llm", "prompts"); adir = mp.work("llm", "answers")
    prompts = {w["form"]: prompt_for(w, specs[w["form"]], meta, cat, limit) for w in work if w["form"] in specs}
    est = {f: (len(brief) + len(p)) // 3 + 1500 for f, p in prompts.items()}           # ~3 chars per token (Arabic), + answer

    if opt("--prepare") or not (opt("--budget") or opt("--import")):
        io.open(os.path.join(pdir, "_BRIEF.md"), "w", encoding="utf-8").write(brief)
        for f, p in prompts.items():
            io.open(os.path.join(pdir, f + ".md"), "w", encoding="utf-8").write(p)
        print(f"prompts written: {len(prompts)} in {pdir} (estimated {sum(est.values()):,} tokens in total; the brief is the same for all)")
        print(f"save each answer (the JSON object) as {adir}\\<FORM>.json, then: python pipeline.py {mp.CLIENT} llm --import")
        return
    cur = connect().cursor()
    if opt("--import"):
        for f in prompts:
            a = os.path.join(adir, f + ".json")
            if os.path.exists(a):
                p, probs = save_draft(f, parse_answer(io.open(a, encoding="utf-8").read()), meta, cur, "manual")
                print(f"{f:30} draft -> {os.path.relpath(p, mp.REPO)} ({len(probs)} dropped)")
        return
    import anthropic                                                  # pip install anthropic; env ANTHROPIC_API_KEY
    client = anthropic.Anthropic()
    budget, spent, log = int(opt("--budget", 300000, int)), 0, []
    for f, p in prompts.items():
        if spent + est[f] > budget:
            print(f"budget reached ({spent:,} of {budget:,} tokens): {f} and the rest left for later"); break
        r = client.messages.create(model=model, max_tokens=4000,
                                   system=[{"type": "text", "text": brief, "cache_control": {"type": "ephemeral"}}],
                                   messages=[{"role": "user", "content": p}])
        u = r.usage
        used = u.input_tokens + u.output_tokens + (getattr(u, "cache_creation_input_tokens", 0) or 0) + (getattr(u, "cache_read_input_tokens", 0) or 0) // 10
        spent += used
        text = "".join(b.text for b in r.content if getattr(b, "type", "") == "text")
        io.open(os.path.join(adir, f + ".json"), "w", encoding="utf-8").write(text)
        try:
            path, probs = save_draft(f, parse_answer(text), meta, cur, model)
            print(f"{f:30} {used:>7,} tokens  draft -> {os.path.relpath(path, mp.REPO)} ({len(probs)} dropped)")
        except Exception as e:
            print(f"{f:30} {used:>7,} tokens  answer not usable: {e}")
        log.append({"form": f, "tokens": used})
    json.dump({"model": model, "budget": budget, "spent": spent, "screens": log}, io.open(mp.work("llm", "run.json"), "w"), indent=1)
    print(f"llm: {len(log)} screens, {spent:,} tokens (budget {budget:,})")


if __name__ == "__main__":
    main()
