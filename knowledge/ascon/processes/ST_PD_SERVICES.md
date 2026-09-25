# ST_PD_SERVICES - أرقام الخدمات / Service Types

- Registry: system 3 serial 216, menu `CODES_MENU.ST_PD_SERVICES`. Legacy `ASCON\ST\FMB\ST_PD_SERVICES.fmx` (no .fmb).
- APEX: page 20230, `GRID` on `ST_PD_SERVICES` (`SERVICE_CODE`, `NAME_A`, `NAME_E`, `UNIT_COST`; the other columns `MN_FLAG`, `LEAF`,
  `PERIOD_*`, `SERVICE_LEVEL` have no legacy label). No override: the only rule is a delete check, done by trigger
  `APP_RULES3_ST_PD_SERVICES_BD` (package `APP_RULES3_ST.code_delete`).
- Data: 1 service, used by 49 `ST_TRNS_SERVICES` rows (FKs from `ST_TRNS_SERVICES`, `ST_STAND_SERVICES`, `ST_TRNS_AUTH_SERVICES`).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| code = `NVL(MAX(SERVICE_CODE),0)+1` | embedded SQL | generic max+1 of `APPX_ST_PD_SERVICES` | high |
| names and unit cost required | table NOT NULL columns | required columns | high |
| a used service cannot be deleted: "تم تخصيص هذه الخدمة مع صنف أو أكثر - لا يمكن حذفها حالياً." | `SELECT COUNT(1) FROM ST_PD_DET_SRVC / ST_STAND_SERVICES / ST_TRNS_SERVICES WHERE SERVICE_CODE = :b1` | delete trigger `APP_RULES3_ST_PD_SERVICES_BD` (all three tables) | high |

## Tests (rolled back)

A6 deleting service 1 (used by transaction services) refused.

## Coverage

- Reproduced: numbering, delete protection.
- Not reproduced: record counter; toolbar print (`ST_PD_SERVICES.rdf`, code list).
