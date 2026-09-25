"""Load SMART dictionary metadata (tables, views, columns, PK, FK, row counts, comments) into gen/cache/meta.json."""
import os, sys, json, io, collections
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
from db import connect

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE)); import mp
CACHE = mp.work("cache")
os.makedirs(CACHE, exist_ok=True)
META = os.path.join(CACHE, "meta.json")


def build():
    c = connect(); cur = c.cursor()
    cur.arraysize = 5000
    tabs = {}
    cur.execute("select table_name, num_rows, 'TABLE' from user_tables where table_name not like 'BIN$%' "
                "union all select view_name, null, 'VIEW' from user_views")
    for t, n, k in cur:
        tabs[t] = {"name": t, "kind": k, "rows": n, "cols": [], "pk": [], "fks": [], "comment": None}
    cur.execute("""select table_name, column_name, data_type, char_length, data_length, data_precision, data_scale,
                          nullable, data_default, column_id, virtual_column
                   from user_tab_cols where hidden_column = 'NO' order by table_name, column_id""")
    for t, col, dt, cl, dl, pr, sc, nl, dflt, cid, virt in cur:
        if t not in tabs: continue
        tabs[t]["cols"].append({"name": col, "type": dt, "len": cl or dl, "prec": pr, "scale": sc,
                                "nullable": nl == "Y", "default": (dflt or "").strip() or None, "id": cid,
                                "virtual": virt == "YES"})
    cur.execute("select table_name, column_name, comments from user_col_comments where comments is not null")
    for t, col, cm in cur:
        if t in tabs:
            for cc in tabs[t]["cols"]:
                if cc["name"] == col: cc["comment"] = cm
    cur.execute("""select c.table_name, cc.column_name from user_constraints c
                   join user_cons_columns cc on cc.constraint_name = c.constraint_name
                   where c.constraint_type = 'P' order by c.table_name, cc.position""")
    for t, col in cur:
        if t in tabs: tabs[t]["pk"].append(col)
    cur.execute("""select c.table_name, c.constraint_name, r.table_name, cc.column_name, rc.column_name, cc.position
                   from user_constraints c
                   join user_constraints r on r.constraint_name = c.r_constraint_name
                   join user_cons_columns cc on cc.constraint_name = c.constraint_name
                   join user_cons_columns rc on rc.constraint_name = r.constraint_name and rc.position = cc.position
                   where c.constraint_type = 'R' and c.status = 'ENABLED' or (c.constraint_type = 'R')
                   order by c.table_name, c.constraint_name, cc.position""")
    fks = collections.OrderedDict()
    for t, cn, parent, col, pcol, pos in cur:
        fks.setdefault((t, cn), {"name": cn, "parent": parent, "cols": [], "pcols": []})
        fks[(t, cn)]["cols"].append(col); fks[(t, cn)]["pcols"].append(pcol)
    for (t, cn), fk in fks.items():
        if t in tabs: tabs[t]["fks"].append(fk)
    # unique keys (used when a parent has no PK but a UK)
    cur.execute("""select c.table_name, c.constraint_name, cc.column_name from user_constraints c
                   join user_cons_columns cc on cc.constraint_name = c.constraint_name
                   where c.constraint_type = 'U' order by c.table_name, c.constraint_name, cc.position""")
    for t, cn, col in cur:
        if t in tabs:
            tabs[t].setdefault("uks", {}).setdefault(cn, []).append(col)
    json.dump(tabs, io.open(META, "w", encoding="utf-8"), ensure_ascii=False)
    print("meta: tables/views", len(tabs), "fks", sum(len(t["fks"]) for t in tabs.values()))
    return tabs


def load(refresh=False):
    if refresh or not os.path.exists(META):
        return build()
    return json.load(io.open(META, encoding="utf-8"))


if __name__ == "__main__":
    build()
