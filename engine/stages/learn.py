"""Stage learn: make the current client the reference of its product knowledge.

The knowledge (knowledge/<product>) holds rules reviewed for one real installation.  learn records the fingerprints of
that installation (screens, reports, tables, stored code; hashes only) in knowledge/<product>/fingerprints.json, so the
delta stage of every later client can tell SAME from CHANGED and NEW.
   python pipeline.py smart learn                  -> whole snapshot (first client of a product)
   python pipeline.py <client> learn FORM [...]    -> only these screens (after promote; see promote.py)"""
import os, sys, io, json, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fingerprint as FP
mp = FP.mp


def main(forms):
    path = os.path.join(mp.KNOWLEDGE, "fingerprints.json")
    snap = FP.snapshot()
    if forms:
        K = json.load(io.open(path, encoding="utf-8"))
        for f in forms:
            f = f.upper()
            if f in snap["screens"]:
                K["screens"][f] = snap["screens"][f]; print("learned screen", f)
            elif f in snap["reports"]:
                K["reports"][f] = snap["reports"][f]; print("learned report", f)
            else:
                print("not in this client's registry:", f)
    else:
        K = snap
    K["_about"] = f"fingerprints (hashes only) of the reference installation; last learned from client {mp.CLIENT} on {time.strftime('%Y-%m-%d')}"
    json.dump(K, io.open(path, "w", encoding="utf-8"), ensure_ascii=False, sort_keys=True, default=str)
    print(f"knowledge fingerprints: screens {len(K['screens'])}, reports {len(K['reports'])}, tables {len(K['tables'])}, "
          f"plsql {len(K['plsql'])} -> {path}")


if __name__ == "__main__":
    main(sys.argv[1:])
