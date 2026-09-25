# ST_BROKER — ارقام السماسرة / Broker Codes (system 31, serial 19)

Deliverable: **business rules + labels** — `overrides/ST_BROKER.json` (AUTO, row rule, legacy labels),
`APP_RULES3_SA` (`broker_row`, `broker_delete`), delete hook `APP_R3_ST_BROKER_BD`. Page 60150. Confidence: **high**.

## Purpose and tables
`ST_BROKER` (BROKER_CODE, descriptions, ACCOUNT_NUMBER, COST_CODE, COST_CODE2; empty in the build copy), referenced by
`ST_TRNS_MAST.BROKER_CODE`.

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Number = max + 1 | generated APPX key | `SELECT NVL(MAX(BROKER_CODE),0)+1 FROM ST_BROKER` | high |
| 2 | No duplicate — "رقم مكرر تم إدخالة من قبل" | row rule `broker_row` | .fmx message | high |
| 3 | Account from the detail accounts (`ACCOUNT_STATUS = 1`) | row rule | account LOV SQL | high |
| 4 | Cost centres 1 / 2 from `AC_COST_CENTERS` / `AC_COST_CENTERS2`; active ones (`COST_STATUS = 1`) for a restricted user | row rule | cost centre LOV SQL | medium (password ranges of AC_PASSWORD_COST1/2 not repeated) |
| 5 | Delete refused while sales documents use the broker — "لايمكن مسح السجل لوجود ارتباطات" | trigger `APP_R3_ST_BROKER_BD` → `broker_delete` | `SELECT COUNT(1) FROM ST_TRNS_MAST WHERE (BROKER_CODE = :b1)` | high |

## Tests (`tmp\w3_prsa\t_w3prsa.py`)
BR1 summary account refused · BR2 broker numbered max + 1 · BR3 delete refused while an invoice uses the broker (fixture) ·
BR4 unused broker deleted. All PASS.

## Wave 3b
* `rules.columns`: the three legacy LOVs of the .fmx as lists — ACCOUNT_NUMBER (detail accounts, `AC_PASSWORD_MASTER` for a
  restricted user), COST_CODE / COST_CODE2 (`AC_COST_CENTERS` / `AC_COST_CENTERS2`; for a restricted user only active centres
  inside the user's `AC_PASSWORD_COST1` / `AC_PASSWORD_COST2` ranges, `RPAD(SUBSTR(code, 1, COST_END_POS), 9, 0)`). This
  closes the gap "password ranges of the cost-centre lists not repeated".
* Sweep: no radio group / check box / call-form button in the .fmx.
* Check: `check_forms.py ST_BROKER` (each list run unrestricted and as password number 1).

## Coverage
Reproduced: numbering, duplicate, account / cost-centre lists including the password ranges (wave 3b), delete restriction.
Not reproduced: delete confirmation alert, toolbar / translation code.
