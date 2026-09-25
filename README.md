# Migration Pipeline

Moves a client of an Oracle Forms / Reports ERP (ASCON ERP, Arabic / English) to Oracle APEX 24.2 in one command:

```
python pipeline.py --new acme          # once per client: clients/acme/client.json
copy <their dump> clients\acme\dump\
python pipeline.py acme                # restore -> catalog -> generate -> delta -> build -> verify -> report
```

The result is the client's own APEX application (Arabic, plus the English copy) on its own schema and workspace:
all its data, its legacy users and rights, every registered screen and report, the legacy print layouts, and the
business rules reviewed for the product.  Then `clients/acme/work/REPORT.md` says what was built, and
`clients/acme/work/DELTA.md` says what is different about this client and needs a key user's eye.

* **Deterministic.** Plain Python and SQL.  No stage needs a language model; the same input gives the same application.
* **Token-light.** An LLM is an optional helper for the screens the product knowledge has not seen, one compact
  prompt per screen, with a hard token budget, a cached brief and every answer checked against the client's database
  ([docs/LLM.md](docs/LLM.md)).
* **Different clients.** A client's own database logic comes with its dump.  Modules the product knowledge does not
  know are generated like the others and listed.  Reviewed rules that do not fit a client's database are switched off
  one by one and listed, never silently.  A client's own rules live in its overlay ([docs/KNOWLEDGE.md](docs/KNOWLEDGE.md)).

**Is "only the dump" enough?**  For ASCON clients, yes: everything in the database, which includes most of the
business logic, plus screens, reports and reviewed rules from the product knowledge.  What a client changed inside its
Forms / Reports files needs its ASCON folder as well.  Details and the NAJD pilot numbers: [docs/FEASIBILITY.md](docs/FEASIBILITY.md).

## Documentation

| | |
|---|---|
| [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md) | stages, folders, the knowledge / overlay model, degradation, why it is deterministic |
| [docs/ONBOARDING.md](docs/ONBOARDING.md) | what the client gives, server setup, client.json, reading the report |
| [docs/FEASIBILITY.md](docs/FEASIBILITY.md) | what a dump alone gives, different modules and logic, the pilot |
| [docs/KNOWLEDGE.md](docs/KNOWLEDGE.md) | the product knowledge, learn / overlay / promote |
| [docs/LLM.md](docs/LLM.md) | the optional LLM step: cost control, data protection, review |
| [legacy-server/README.md](legacy-server/README.md) | converting a client's Forms / Reports to XML on its legacy server |

## Commands

```
python pipeline.py --init-server                 one-time: admin user MP_ADMIN on this database
python pipeline.py --new <client>                new client folder from clients/_template
python pipeline.py <client>                      all stages
python pipeline.py <client> <stage> [<stage>..]  restore catalog generate delta build verify report
python pipeline.py <client> --from <stage>       from a stage to the end
python pipeline.py <client> status               what ran, when, result
python pipeline.py <client> llm --prepare        optional: prompts for the screens on the worklist (docs/LLM.md)
python pipeline.py <client> promote FORM ...     client rules that are product behaviour -> knowledge
python pipeline.py <reference> learn             record the reviewed reference client's fingerprints
```

## Clients on this server

| client | dump | schema / workspace | app | state |
|---|---|---|---|---|
| smart | reference, restored by hand (repository `smart-transformation`) | SMART | 100 / 1101 | knowledge source; pipeline output identical to the hand-driven build |
| najd | `NAJD_2022-05-21.dmp` (classic exp, dump only) | NAJD | 200 / 2001 | pilot: 644 pages and 132 documents opened in Edge with 0 errors (docs/FEASIBILITY.md) |

## Requirements

Oracle 19c+ with APEX 24.2 and ORDS, the Oracle client tools (`imp`, `impdp`, SQL*Plus), SQLcl, Python 3.12 with
`oracledb` and `playwright` (Microsoft Edge).  Passwords are never stored in the repository: they live in Windows User
environment variables (`<SCHEMA>_PWD`, `MP_ADMIN_PWD`, `SYS_PWD`) and the operator's password file.  Run
`python engine/tools/secret_scan.py` before every push.
