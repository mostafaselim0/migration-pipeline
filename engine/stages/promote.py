"""Stage promote: move reviewed client work into the product knowledge so every later client gets it.
   python pipeline.py <client> promote FORM [FORM ...]
For each form: overlay/overrides/<FORM>.json, overlay/processes/<FORM>.md and the form's overlay prints.json /
translations entries are copied into knowledge/<product>, and the form's fingerprint is learned from this client.
Only promote what is product behaviour; installation-specific rules stay in the client's overlay."""
import os, sys, io, json, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.dirname(HERE))
import mp


def main(forms):
    if not forms:
        sys.exit("name the forms to promote")
    for form in (f.upper() for f in forms):
        for sub, ext in (("overrides", ".json"), ("processes", ".md"), ("report_overrides", ".sql")):
            src = os.path.join(mp.OVERLAY, sub, form + ext)
            if os.path.exists(src):
                dst = os.path.join(mp.KNOWLEDGE, sub, form + ext)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copyfile(src, dst); print("promoted", os.path.relpath(src, mp.REPO), "->", os.path.relpath(dst, mp.REPO))
        for name in ("prints.json",):
            ov = os.path.join(mp.OVERLAY, name)
            if os.path.exists(ov):
                o = json.load(io.open(ov, encoding="utf-8"))
                if form in o:
                    kp = os.path.join(mp.KNOWLEDGE, name)
                    k = json.load(io.open(kp, encoding="utf-8"))
                    k[form] = o[form]
                    json.dump(k, io.open(kp, "w", encoding="utf-8"), ensure_ascii=False, indent=1); print("promoted", name, form)
    import learn
    learn.main(forms)


if __name__ == "__main__":
    main(sys.argv[1:])
