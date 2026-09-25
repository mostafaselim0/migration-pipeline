# ST_ISSUE_IO_PRINT - طباعة فواتير المبيعات / Print Sales Invoices

- Registry: system 3 serial 15, menu `FILES_MENU.ST_ISSUE_IO_PRINT`. Legacy module `ASCON\ST\FMB\ST_ISSUE_IO_PRINT.fmx` (no .fmb,
  no GN_FORM_ITEM labels).
- Purpose: list the sales invoices of a day / store and print them (report `st_customer_INVOICE`); no data entry.
- APEX: read-only `MASTER_DETAIL` pages 20320 / 20321 (override `ST_ISSUE_IO_PRINT.json`): master `ST_TRNS_MAST` with the columns the
  screen shows (type, serial, invoice / document number, date, store, customer, salesman, payment type, print flag, print date,
  description), detail `ST_TRNS_DET` "أصناف الفاتورة"; insert / update / delete off; the legacy block WHERE in `where`; newest first.
  The print itself is configured in `app\legacy\prints.json` (main session / prints agent).
- Confidence: high for the list, high for the print parameters (from `prints.json` evidence).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| sales invoices only: `TRNS_TYPE_CODE IN (SELECT .. FROM ST_TRNS_TYPE WHERE TRNS_TYPE = 2 AND EFFECT = 2)`, not deleted | block WHERE (same as ST_ISSUE_IO_VIEW) | `where` | high |
| user-group filters on transaction type (`ST_TRNSTYPE_PASSWORD`, `FLAG = 1`), customer (`AR_CUST_PASSWORD`) and store (`ST_STORE_PASSWORD`, `FLAG = 1`) | block WHERE | `where` with `:G_PASSWORD_NUMBER` | high |
| print state غير مطبوع / مطبوع / الكل: `((NVL(PRINT_FLAG,0) = 0 AND :state = 2) OR (NVL(PRINT_FLAG,0) = 1 AND :state = 1) OR :state = 3)`; day and store criteria | control block, WHERE text | interactive-report filters on `PRINT_FLAG`, `TRNS_DATE`, `STORE_CODE` (no page items on a generated list) | medium |
| print right: `SELECT NVL(PRINT_INV_FLAG,0) FROM USERS WHERE USERS_CODE = :user` -> "ليس لك صلاحية الطباعة" | embedded SQL, message | `prints.json` `right` | high |
| on the first print `PRINT_FLAG := 1`, `PRINT_DATE := sysdate` ('DD/MM/RRRR HH24:MI'), report parameter `P_FIRST` | print units (prints agent's evidence) | `prints.json` `first_print` sets `PRINT_FLAG`; `PRINT_DATE` is not set by the print engine (gap for the main session) | high |
| report `st_customer_INVOICE` with `P_TRNS_TYPE_CODE`, `P_TRNS_SERIAL`, `P_USERS_CODE`, `P_COMPANY`, `P_PASSWORD_NUMBER`, `COMP_CODE`, `LANG`; printer `USERS_PRINTER` (`IS_DEFAULT = 1`), PDF folder `USERS.PDF_PATH`, file prefix `ASCON_INV_`, WebUtil transfer and `DBMS_LOCK.SLEEP` | print units | `prints.json` (the two key parameters mapped); printer / PDF folder / WebUtil not reproduced (printer selection excluded by the wave-3 goal) | high |
| printed rows shown green (`SET_GREEN`) | identifier | not reproduced (visual) | high |

## Tests

No rule of this screen is implemented in `APP_RULES3_ST`; the list SQL (`where`) was parsed with the generated page
(`tmp\w3_st\page_check.py`, 0 failures). The print belongs to the main session.

## Coverage

- Reproduced: the invoice list with the legacy filters, the lines, the print right / first-print flag through `prints.json`.
- Not reproduced: range printing of all listed invoices in one run (the print engine prints one document; generator gap);
  `PRINT_DATE` on first print (engine gap, reported); the green colour of printed rows; printer / PDF folder handling (out of scope);
  ZATCA QR on the printed invoice (ZATCA deferred).
- Open question: were several invoices printed in one run from this list (range print), or one at a time?
