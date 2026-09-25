"""English translation of app 100 through the APEX translation repository (apex_lang):
map language 'en' -> translated app 1100 (left-to-right), seed, fill every Arabic string that has a known English
equivalent (GN_FORM_ITEM pairs, registry titles, generated specs, fixed UI strings), publish.
Run after every install:  python translate.py"""
import os, sys, re, io, json, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tools"))
from db import connect

sys.path.insert(0, os.path.dirname(HERE)); import mp
APP, LANG, TAPP = mp.APP_ID, "en", mp.TAPP_ID          # translated application ids must not end in zero
AR = re.compile(r"[؀-ۿ]")

UI = {
    "إجراءات": "Actions", "إلغاء": "Cancel", "رجوع": "Back", "حذف": "Delete", "حفظ التعديلات": "Apply Changes", "إضافة": "Create",
    "حفظ البيانات": "Save Data", "لا توجد بيانات": "No data found", "تعديل": "Edit", "حفظ النموذج": "Save Form", "تهيئة النموذج": "Initialize Form",
    "حفظ المستند": "Save Document", "تهيئة المستند": "Initialize Document", "معايير التقرير": "Report Parameters", "عرض التقرير": "Run Report",
    "تغيير كلمة المرور": "Change Password", "كلمة المرور الحالية": "Current Password", "كلمة المرور الجديدة": "New Password",
    "تأكيد كلمة المرور": "Confirm Password", "حفظ كلمة المرور": "Save Password", "تنبيه": "Notice", "الأنظمة": "Systems",
    "تسجيل الخروج": "Sign Out", "رقم المستخدم": "User Number", "كلمة المرور": "Password", "تذكر رقم المستخدم": "Remember user number",
    "دخول": "Sign In", "أسكون ERP": "ASCON ERP", "أسكون ERP - تسجيل الدخول": "ASCON ERP - Sign In",
    "تم تغيير كلمة المرور بنجاح": "Password changed successfully", "تطابق كلمة المرور": "Password match",
    "كلمة المرور الجديدة وتأكيدها غير متطابقين": "New password and confirmation do not match",
    "يجب اختيار كلمة مرور جديدة (6 أحرف على الأقل) قبل متابعة العمل على النظام الجديد.":
        "Please choose a new password (at least 6 characters) before continuing in the new system.",
    "ليس لديك صلاحية لفتح هذه الشاشة": "You are not allowed to open this screen",
    "ليس لديك صلاحية الإضافة في هذه الشاشة": "You are not allowed to add records on this screen",
    "ليس لديك صلاحية التعديل في هذه الشاشة": "You are not allowed to change records on this screen",
    "ليس لديك صلاحية الحذف في هذه الشاشة": "You are not allowed to delete records on this screen",
    "هذه الشاشة لمدير النظام فقط": "This screen is for the system administrator only",
    "القيمة (+ مدين / - دائن)": "Value (+ debit / - credit)", "English": "English", "عربي": "عربي",
    "معلومات": "Information", "تم حذف المستند": "Document deleted", "حذف المستند": "Delete document", "طباعة": "Print",
    "ليس لك صلاحية الطباعة": "You are not allowed to print", "معايير الطباعة": "Print parameters",
    "مرحباً &G_USER_NAME. - الشركة: &G_COMPANY_CODE.": "Welcome &G_USER_NAME_E. - Company: &G_COMPANY_CODE.",
    "&G_USER_NAME.": "&G_USER_NAME_E.",
}


def dictionary(cur):
    d = {}
    def add(a, e):
        if a and e and AR.search(a) and not AR.search(e) and a.strip() not in d:
            d[a.strip()] = e.strip()
    for a, e in UI.items():
        d[a] = e
    for a, e in mp.kjson("translations_manual.json").items():      # shared knowledge + the client's overlay
        if a and e: d[a.strip()] = e.strip()
    specs = json.load(io.open(mp.work("out", "specs.json"), encoding="utf-8"))
    for s in specs["specs"]:
        add(s["title_a"], s["title_e"])
        pr = s.get("proc") or {}
        add(pr.get("description_a"), pr.get("description_e"))
        add(pr.get("button_a"), pr.get("button_e"))
        add(pr.get("confirm_a"), pr.get("confirm_e"))
        add(pr.get("success_a"), pr.get("success_e"))
        add(pr.get("preview_title_a"), pr.get("preview_title_e"))
        for p in pr.get("params", []):
            add(p.get("label_a"), p.get("label_e"))
        for c in pr.get("preview_columns", []):
            add(c.get("label_a"), c.get("label_e"))
        for inf in (s.get("rules") or {}).get("info") or []:
            add(inf.get("label_a"), inf.get("label_e"))
        for a in s.get("actions") or []:
            for k in ("label", "confirm", "success"):
                add(a.get(k + "_a"), a.get(k + "_e"))
            for p in a.get("params") or []:
                add(p.get("label_a"), p.get("label_e"))
        for w in (s.get("rules") or {}).get("warnings") or []:
            add(w.get("name"), w.get("name_e"))
        for more in (s.get("print_rdf") or {}).get("more") or []:
            add(more.get("label_a"), more.get("label_e"))
        for l in s.get("links") or []:
            add(l.get("label_a"), l.get("label_e"))
        for b in ([s["master"]] if s.get("master") else []) + s.get("details", []):
            add(b.get("title_a"), b.get("title_e"))
            for c in b["cols"]:
                add(c["label_a"], c["label_e"])
                for la, le in (c.get("static_e") or {}).items():
                    add(la, le)
    for r in specs["reports"] + specs["files"]:
        add(r.get("desc_a"), r.get("desc_e"))
    for s in specs["systems"]:
        add(s["a"], s["e"])
    rp = mp.work("out", "reports.json")
    if os.path.exists(rp):
        for r in json.load(io.open(rp, encoding="utf-8")):
            add(r.get("title_a"), r.get("title_e"))
            for c in r.get("columns", []): add(c.get("label_a"), c.get("label_e"))
            for i in r.get("items", []): add(i.get("label_a"), i.get("label_e"))
    cur.execute("select prompt_a, prompt_e from gn_form_item where prompt_a is not null and prompt_e is not null "
                "union all select label_a, label_e from gn_form_item where label_a is not null and label_e is not null")
    for a, e in cur:
        add(re.sub(r"\s+", " ", a).strip(" :"), re.sub(r"\s+", " ", e).strip(" :"))
    return d


def translate_text(s, d):
    if s is None or not AR.search(s): return None
    k = s.strip()
    if k in d: return d[k]
    k2 = re.sub(r"\s+", " ", k).strip(" :")
    if k2 in d: return d[k2]
    m = re.match(r"^التفاصيل(?:\s+(\d+))?$", k2)
    if m:
        return "Lines" + (f" {m.group(1)}" if m.group(1) else "")
    m = re.match(r"^(من|إلى|الى)\s+(.*)$", k2)
    if m and m.group(2) in d:
        return ("From " if m.group(1) == "من" else "To ") + d[m.group(2)]
    return None


def run():
    c = connect(); cur = c.cursor()
    d = dictionary(cur)
    print("dictionary entries", len(d))
    cur.execute(f"begin apex_util.set_workspace('{mp.WORKSPACE}'); end;")
    cur.execute("select count(*) from apex_application_trans_map where primary_application_id = :1 and translated_app_language = :2", [APP, LANG])
    if cur.fetchone()[0] == 0:
        cur.execute("""begin apex_lang.create_language_mapping(p_application_id => :1, p_language => :2, p_translation_application_id => :3); end;""",
                    [APP, LANG, TAPP])
    cur.execute("begin apex_lang.seed_translations(p_application_id => :1, p_language => :2); end;", [APP, LANG])
    c.commit()
    cur.execute("""select id, from_string, to_string from apex_application_trans_repos
                    where application_id = :1 and language_code = :2""", [APP, LANG])
    rows = cur.fetchall()
    done = miss = 0
    missing = collections.Counter()
    upd = c.cursor()
    for rid, frm, to in rows:
        if frm is None: continue
        frm = str(frm)
        if frm in UI and not AR.search(frm):
            upd.execute("begin apex_lang.update_translated_string(p_id => :1, p_language => :2, p_string => :3); end;", [rid, LANG, UI[frm]])
            done += 1; continue
        if not AR.search(frm): continue
        # composite strings: translate each Arabic run separated by " - " or newline
        e = translate_text(frm, d)
        if e is None and " - " in frm:
            parts = [translate_text(p, d) or (p if not AR.search(p) else None) for p in frm.split(" - ")]
            if all(parts): e = " - ".join(parts)
        if e is None:
            miss += 1; missing[frm[:80]] += 1; continue
        upd.execute("begin apex_lang.update_translated_string(p_id => :1, p_language => :2, p_string => :3); end;", [rid, LANG, e])
        done += 1
    c.commit()
    cur.execute("begin apex_lang.publish_application(p_application_id => :1, p_language => :2); end;", [APP, LANG])
    c.commit()
    print(f"repository strings {len(rows)}, translated {done}, Arabic without English {miss}")
    with io.open(mp.work("out", "translation_missing.txt"), "w", encoding="utf-8") as fh:
        for s, n in missing.most_common():
            fh.write(f"{n}\t{s}\n")


if __name__ == "__main__":
    run()
