# ST_PURCH_PLAN - خطة المشتريات على فترات / Purchase Plan In Periods

- Registry: system 30 (Purchasing) serial 36, menu `FILES_MENU.ST_PURCH_PLAN`.
- Legacy module: `ASCON\ST\FMB\ST_PURCH_PLAN.fmx` (no .fmb, no GN_FORM_ITEM labels).
- **Deliverable: (c) cannot reconstruct** - no override written; the page stays a placeholder.
- **Confidence: high that it is a plain master-detail data-entry screen; reconstruction blocked because its tables do not exist in SMART.**

## What the screen is

A purchase plan per period and warehouse: header = period (`ST_PERIODS`) + store (`ST_STORE`) + notes; lines = item, quantity,
price, total, with column totals. Extra buttons copy the items of another period ("نسخ فترة" / "نسخ أصناف الفترة") and load items
("إنزال الأصناف"). It is ordinary data entry, not a process.

## Evidence

- Tables written by the form (embedded SQL): `ST_PURCH_PLAN (PERIOD_CODE, STORE_CODE, ...)` and `ST_PURCH_PLAN_DET (PERIOD_CODE, STORE_CODE, ITEM_CODE, QTY, PRICE)`:
  - `SELECT PERIOD_CODE, STORE_CODE FROM ST_PURCH_PLAN`
  - `SELECT ITEM_CODE, QTY, PRICE FROM ST_PURCH_PLAN_DET WHERE PERIOD_CODE = :b1 AND STORE_CODE = :b2` (read of the source period when copying)
  - `SELECT 1 FROM ST_PURCH_PLAN_DET S WHERE S.PERIOD_CODE = :b1 AND S.STORE_CODE = :b2` (existence check)
  - relation `ST_PURCH_PLAN_ST_PURCH_PLAN_` (master-detail on `PERIOD_CODE, STORE_CODE`); cursor `ST_PURCH_PLAN_DET_CUR`.
- **Neither `ST_PURCH_PLAN` nor `ST_PURCH_PLAN_DET` exists in SMART** (checked `user_objects` and `all_objects`); no DB code references them.
- Lookups: period LOV `ST_PERIODS` (0 rows in SMART), store LOV `ST_STORE` (STORE_STATUS = 1, STOP_FLAG = 0, password filter via `ST_STORE_PASSWORD`),
  item LOV `ST_ITEM` + basic unit `ST_ITEM_UNIT` (BASIC_UNIT = 1) with `RETAIL_SALE_PRICE` as default price, group password filter `ST_GROUP_PASSWORD`.
- Validation: "لابد من ادخال الكمية والسعر" (quantity and price are mandatory); "يجب حفظ السجل اولا" before copying.
- Many messages ("تم الانتهاء من نسخ اصناف العميل", `ST_CUST_GROUP_PRICE(_DET)` references) are leftovers of the customer-pricing form it was cloned from.

## Conclusion

`ST_PERIODS` is empty and the plan tables are missing, so the screen is not used in this installation. Creating tables is outside
Stage C (only packages may be added), and an override naming non-existent tables would break the generator.

## Questions for the key user / vendor

1. Is the purchase plan used at all? If not, retire the menu entry (SYS_FILES 30/36).
2. If it is needed: provide the DDL of `ST_PURCH_PLAN` / `ST_PURCH_PLAN_DET` from the vendor's scripts or another customer's schema
   (expected columns: master `PERIOD_CODE, STORE_CODE, NOTES`; detail `PERIOD_CODE, STORE_CODE, ITEM_CODE, QTY, PRICE` and probably `GROUP_CODE`),
   create them, then an override `{"pattern": "MASTER_DETAIL", "master": {"table": "ST_PURCH_PLAN"}, "details": [{"table": "ST_PURCH_PLAN_DET",
   "join": [["PERIOD_CODE","PERIOD_CODE"],["STORE_CODE","STORE_CODE"]]}]}` is enough; the "copy period" button would be a small procedure
   (`INSERT ... SELECT ITEM_CODE, QTY, PRICE FROM ST_PURCH_PLAN_DET WHERE PERIOD_CODE = :from AND STORE_CODE = :store`).
3. Are periods (`ST_PERIODS`, screen ST_PERIODS) going to be defined?

## Wave 3b
Swept for the wave-3b keys: not applicable. The screen stays unbuilt because its tables `ST_PURCH_PLAN` /
`ST_PURCH_PLAN_DET` do not exist in SMART (see Conclusion); the new keys (lists, computed columns, block settings, links) all
work on an existing table.

## Coverage
See above.
