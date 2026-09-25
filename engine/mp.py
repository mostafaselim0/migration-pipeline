"""Client context shared by every engine script.

The client is chosen with the environment variable MP_CLIENT (pipeline.py sets it).  Its configuration is
clients/<client>/client.json; everything the engine writes goes to clients/<client>/work.  Reviewed knowledge is read from the
client's overlay first (clients/<client>/overlay) and then from the shared product knowledge (knowledge/<product>)."""
import os, re, io, json, glob

ENGINE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(ENGINE)
CLIENT = os.environ.get("MP_CLIENT", "").strip()
if not CLIENT:
    raise SystemExit("MP_CLIENT is not set: run the engine through  python pipeline.py <client> ...")
CDIR = os.path.join(REPO, "clients", CLIENT)
_cfg_path = os.path.join(CDIR, "client.json")
if not os.path.exists(_cfg_path):
    raise SystemExit(f"no client configuration {_cfg_path} (copy clients/_template/client.json)")
CFG = json.load(io.open(_cfg_path, encoding="utf-8"))

WORK = os.path.join(CDIR, "work")
OVERLAY = os.path.join(CDIR, "overlay")
KNOWLEDGE = os.path.join(REPO, "knowledge", CFG.get("knowledge", "ascon"))
# Legacy files of the client (docs/ONBOARDING.md): "xml" = output of legacy-server/Convert-*.ps1 (<MODULE>/.../*_fmb.xml,
# *_RDF.xml), "binaries" = the installation folder (ASCON: *.fmx, *.rdf, *.pll, *.mmx).  Default: clients/<c>/sources/XML
# and clients/<c>/sources/ASCON.  A plain string is the XML folder.
_src = CFG.get("sources") or {}
_src = {"xml": _src} if isinstance(_src, str) else _src
_sdir = os.path.join(CDIR, "sources")
# dump only: no sources delivered -> the product's reference sources on this server (knowledge product.json)
SOURCES_FROM_PRODUCT = not (_src.get("xml") or os.path.isdir(_sdir))
if SOURCES_FROM_PRODUCT:
    _pj = os.path.join(KNOWLEDGE, "product.json")
    _src = (json.load(io.open(_pj, encoding="utf-8")).get("reference_sources") or {}) if os.path.exists(_pj) else {}
SOURCES = os.path.abspath(_src.get("xml") or (os.path.join(_sdir, "XML") if os.path.isdir(os.path.join(_sdir, "XML")) else _sdir))
BINARIES = os.path.abspath(_src.get("binaries") or (os.path.join(_sdir, "ASCON") if os.path.isdir(os.path.join(_sdir, "ASCON")) else SOURCES))
BINARY_EXT = (".fmx", ".fmb", ".rdf", ".rep", ".pll", ".plx", ".mmx", ".mmb")

SCHEMA = CFG["schema"].upper()
DSN = CFG.get("dsn", "localhost:1521/ORCLPDB")
PDB = CFG.get("pdb", DSN.rsplit("/", 1)[-1])
APP_ID = int(CFG["app_id"])
TAPP_ID = int(CFG.get("translated_app_id") or APP_ID * 10 + 1)      # APEX: translated application ids must not end in 0
WORKSPACE = CFG.get("workspace", SCHEMA).upper()
# APEX component ids are unique across the whole instance: each client's application is installed with its own offset
ID_OFFSET = int(CFG["id_offset"]) if CFG.get("id_offset") is not None else APP_ID * 10 ** 13
APP_NAME = CFG.get("app_name", "ASCON ERP")
APP_ALIAS = CFG.get("app_alias", "ascon-erp")
CUSTOMER_CODE = CFG.get("customer_code")                           # installation code of the legacy system (CUSTOMER_PAR)
PASSWORD_FILE = os.environ.get("MP_PASSWORD_FILE") or os.path.join(os.path.expanduser("~"), "Pictures", "passwords.txt")
SKIP_DIRS = re.compile(r"[\\/](_ARCHIVE|ARCHIVE|old|backup|bk)[\\/]", re.I)


def work(*parts):
    """Path under the client's work folder (parent folders are created)."""
    p = os.path.join(WORK, *parts)
    os.makedirs(os.path.dirname(p) if os.path.splitext(p)[1] else p, exist_ok=True)
    return p


def kpath(*parts):
    """Reviewed knowledge file: the client's overlay wins over the shared product knowledge.  None when neither has it."""
    for base in (OVERLAY, KNOWLEDGE):
        p = os.path.join(base, *parts)
        if os.path.exists(p):
            return p
    return None


def kfiles(subdir, pattern="*"):
    """All knowledge files of a folder by base name (shared first, then the client's overlay replacing same-named files)."""
    out = {}
    for base in (KNOWLEDGE, OVERLAY):
        for p in glob.glob(os.path.join(base, subdir, pattern)):
            out[os.path.basename(p)] = p
    return out


def kjson(name):
    """A JSON knowledge file merged key by key: the client's overlay entries replace or add to the shared ones."""
    data = {}
    for base in (KNOWLEDGE, OVERLAY):
        p = os.path.join(base, name)
        if os.path.exists(p):
            d = json.load(io.open(p, encoding="utf-8"))
            if isinstance(d, dict):
                data.update(d)
    return data


_MODULES = None


def modules():
    """The client's legacy modules: top-level folders of the sources holding converted forms or reports (AC, AR, ST, PY ...).
    A client with more modules simply has more folders; nothing is hard-coded."""
    global _MODULES
    if _MODULES is None:
        _MODULES = CFG.get("modules") or _module_dirs(SOURCES, ("*_fmb.xml", "*_RDF.xml")) or _module_dirs(BINARIES, ("*.fmx", "*.rdf"))
    return _MODULES


def _module_dirs(root, patterns):
    found = []
    if os.path.isdir(root):
        for d in sorted(os.listdir(root)):
            full = os.path.join(root, d)
            if (os.path.isdir(full) and not d.startswith(("_", ".")) and d.upper() != "LOGS"
                    and os.path.abspath(full) != BINARIES and not SKIP_DIRS.search(full + os.sep)
                    and any(glob.glob(os.path.join(full, "**", p), recursive=True) for p in patterns)):
                found.append(d.upper())
    return found


def workspace_id():
    """APEX workspace id of the client: client.json "workspace_id", else the id the restore stage recorded
    (work/cache/workspace.json), else looked up in APEX_WORKSPACES as the client's schema."""
    if CFG.get("workspace_id"):
        return int(CFG["workspace_id"])
    p = os.path.join(WORK, "cache", "workspace.json")
    if os.path.exists(p):
        return int(json.load(io.open(p, encoding="utf-8"))["id"])
    import sys
    sys.path.insert(0, os.path.join(ENGINE, "tools"))
    from db import connect
    cur = connect(SCHEMA).cursor()
    cur.execute("select workspace_id from apex_workspaces where workspace = :1", [WORKSPACE])
    r = cur.fetchone()
    if not r:
        raise SystemExit(f"APEX workspace {WORKSPACE} not found: run the restore stage first")
    json.dump({"workspace": WORKSPACE, "id": int(r[0])}, io.open(work("cache", "workspace.json"), "w", encoding="utf-8"))
    return int(r[0])


def source_files(pattern):
    """Legacy files of the client, archive folders excluded: binaries ('*.fmx', '*.pll' ...) from the installation folder,
    converted XML ('*_fmb.xml', '*_RDF.xml') from the XML folder (not from inside the installation folder)."""
    if pattern.lower().endswith(BINARY_EXT):
        return [p for p in glob.glob(os.path.join(BINARIES, "**", pattern), recursive=True) if not SKIP_DIRS.search(p)]
    inside = BINARIES.lower() + os.sep
    return [p for p in glob.glob(os.path.join(SOURCES, "**", pattern), recursive=True)
            if not SKIP_DIRS.search(p) and not (BINARIES != SOURCES and p.lower().startswith(inside))]
