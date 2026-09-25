"""Arabic / English labels from GN_FORM_ITEM.
   form_items[FORM][BLOCK.ITEM] -> {"a","e","type"}  (prompt, else label, else hint)
   titles[FORM]                  -> {"a","e"}          (window title rows, ITEM_TYPE = W)
   by_name[ITEM]                 -> {"a","e"}          (most frequent prompt for that item name across all forms)"""
import os, sys, json, io, re, collections
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
from db import connect

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE)); import mp
CACHE = mp.work("cache", "labels.json")
BAD = re.compile(r"enter value|^\.+$|^-+$|^\?+$", re.I)
TYPE_RANK = {"T": 0, "LS": 1, "C": 2, "R": 3, "D": 4, "O": 5, "CNT": 6, "B": 7, "W": 8, "L": 9}


def clean(s):
    if s is None: return None
    s = re.sub(r"\s+", " ", str(s)).strip(" :.-‏‎")
    s = s.strip()
    return s or None


def build():
    c = connect(); cur = c.cursor(); cur.arraysize = 5000
    cur.execute("""select upper(form_code), upper(item_code), item_type, prompt_a, prompt_e, label_a, label_e, hint_a, hint_e,
                          tooltip_a, tooltip_e from gn_form_item""")
    form_items = collections.defaultdict(dict)
    titles = {}
    tabs = collections.defaultdict(dict)
    votes_a = collections.defaultdict(collections.Counter)
    votes_e = collections.defaultdict(collections.Counter)
    for form, code, typ, pa, pe, la, le, ha, he, ta, te in cur:
        a = clean(pa) or clean(la)
        e = clean(pe) or clean(le)
        if a and BAD.search(a): a = None
        if e and BAD.search(e): e = None
        if typ == "W":
            if a or e:
                titles.setdefault(form, {"a": a, "e": e})
            continue
        if typ == "CNT":
            if a or e:
                tabs[form].setdefault(code, {"a": a, "e": e})
            continue
        if not (a or e):
            continue
        cur_best = form_items[form].get(code)
        if cur_best is None or TYPE_RANK.get(typ, 9) < TYPE_RANK.get(cur_best["type"], 9) \
           or (not cur_best["a"] and a) or (not cur_best["e"] and e):
            merged = {"a": a or (cur_best or {}).get("a"), "e": e or (cur_best or {}).get("e"), "type": typ}
            form_items[form][code] = merged
        item = code.split(".")[-1]
        if typ in ("T", "D", "LS", "C", "R", "O"):
            if a: votes_a[item][a] += 1
            if e: votes_e[item][e] += 1
    by_name = {}
    for item in set(votes_a) | set(votes_e):
        by_name[item] = {"a": votes_a[item].most_common(1)[0][0] if votes_a[item] else None,
                         "e": votes_e[item].most_common(1)[0][0] if votes_e[item] else None}
    data = {"form_items": form_items, "titles": titles, "by_name": by_name, "tabs": tabs}
    json.dump(data, io.open(CACHE, "w", encoding="utf-8"), ensure_ascii=False)
    print("labels: forms", len(form_items), "titles", len(titles), "item names", len(by_name))
    return data


def load(refresh=False):
    if refresh or not os.path.exists(CACHE):
        return build()
    return json.load(io.open(CACHE, encoding="utf-8"))


if __name__ == "__main__":
    build()
