# Onboarding a new client

## What the client gives

| | needed | how |
|---|---|---|
| **Database dump** | **yes** | Their ASCON schema exported with Data Pump (`expdp schemas=<SCHEMA>`) or classic `exp owner=<SCHEMA>`. A `.zip` is fine. |
| Forms / Reports folder | recommended | Their ASCON installation folder (the one with `AC`, `AR`, `ST` ... holding `.fmx`, `.fmb`, `.rdf`, `.pll`, `.mmx`), plus the XML produced on their Forms server by `legacy-server/Convert-FMBtoXML.ps1` and `Convert-RDFtoXML.ps1`. |
| Installation code | if known | The ASCON "customer code" (`:GLOBAL.CUSTOMER_CODE`); a few legacy procedures behave differently for some installations. |

With the dump alone the application is complete on the database side (all data, and every trigger, procedure and view,
which is where most ASCON business logic lives), and screens and reports come from the product's reference sources.
Anything the client customised *inside* its Forms or Reports only shows up once the folder is delivered.  See
[FEASIBILITY.md](FEASIBILITY.md).

## One-time server setup

```
python pipeline.py --init-server
```
Creates the admin user `MP_ADMIN` in the PDB (needs Windows User env `SYS_PWD`).  Requirements of the server: Oracle
19c+ with APEX 24.2 and ORDS, SQLcl (`C:\sqlcl\bin\sql.exe`, or env `MP_SQLCL`), Python 3.12 with `oracledb` and
`playwright` (Edge), the Oracle client tools `imp` / `impdp` (`client.json` `oracle_home`, or env `MP_ORACLE_HOME`).

## Per client

```
python pipeline.py --new acme                 # creates clients/acme/client.json and clients/acme/dump/
   ... edit client.json (app_id at least), copy the dump into clients/acme/dump/
   ... optional: the ASCON folder -> clients/acme/sources/ASCON, the converted XML -> clients/acme/sources/XML
python pipeline.py acme                       # restore catalog generate delta build verify report
```
Then read `clients/acme/work/REPORT.md` and `clients/acme/work/DELTA.md`.  The application is at
`http://<server>:8080/ords/r/<workspace>/<alias>/login` (Arabic) with the English version one click away.

Re-running: every stage can be re-run on its own (`python pipeline.py acme generate build`), `--from build` runs from a
stage to the end, `status` shows what ran.  `restore` refuses to overwrite an existing schema unless
`"replace_schema": true`.

## client.json

| key | meaning | default |
|---|---|---|
| `schema` | the client's Oracle schema on this server | required |
| `workspace` | its APEX workspace | = schema |
| `app_id` | APEX application id (the English copy gets `app_id*10+1`) | required |
| `translated_app_id`, `id_offset` | override the two derived values | derived |
| `app_name`, `app_alias` | application name and URL alias | ASCON ERP, ascon-erp |
| `knowledge` | the product knowledge folder | ascon |
| `customer_code` | ASCON installation code | none |
| `dsn` | database | localhost:1521/ORCLPDB |
| `dump`, `source_schema` | dump file (else newest in `dump/`), and the schema inside it when it holds several | auto |
| `replace_schema` | allow `restore` to drop and rebuild the schema and workspace | false |
| `sources` | `{"xml": ..., "binaries": ...}` when not in `clients/<c>/sources` | product reference |
| `modules` | module folders to use, when auto-detection is wrong | auto |
| `system_pages`, `system_dirs` | page ranges / report folders for systems the product knowledge does not know | product.json |
| `test_user` | legacy user code the verify stage signs in with | 0, else the lowest |
| `extra_grants` | more grants the legacy code needs, e.g. `"execute on sys.utl_http"` | none |

## Reading the result

1. **REPORT.md, Data**: rows restored, rejected rows (should be 0), foreign keys the legacy data breaks, invalid legacy
   objects (they were invalid at the client too, compare with the source database).
2. **DELTA.md**: SAME screens run on reviewed product rules.  CHANGED / NEW screens and new modules work as generated
   data-entry screens (tables, lists, labels, keys, rights) but without reviewed Forms-level rules; those are the
   screens to test first and to give rules to (overlay, or the optional `llm` stage).
3. **REPORT.md, switched-off rules**: reviewed product rules that do not fit this database (another version of a table).
   Each one either needs a client version in the overlay or can stay off.
4. **REPORT.md, Verification**: pages with errors.

## Giving a client its own rules

Put the reviewed file in `clients/<c>/overlay/` with the same name as in the knowledge:
`overrides/<FORM>.json` (screen rules, contract in `knowledge/<product>/contracts/`), `db/<nn>_<name>.sql` (packages;
a file with the same name replaces the product's), `prints.json` entries.  Then `python pipeline.py <c> generate build`.
