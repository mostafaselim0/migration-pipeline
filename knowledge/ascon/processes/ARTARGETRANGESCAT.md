# ARTARGETRANGESCAT - ملف الاقسام / Departments File

- Registry: system 4 serial 30, menu `CODES_MENU.ARTARGETRANGESCAT`, order 2006.
- Legacy module: `ASCON\AR\FMB\ArTargetRangesCAT.fmx` (no .fmb, no GN_FORM_ITEM labels).
- APEX: `app\legacy\overrides\ARTARGETRANGESCAT.json`, pattern `MASTER_DETAIL`, master `ST_CATEGORY_TYPE`, 5 detail grids (wave 1);
  wave 3 added the rules, labels and the item loader (`APP_RULES3_AR`, `app\db\25_rules3_ar.sql`).
- Confidence: medium (blocks and SQL certain; the meaning of some columns inferred from labels).

## What the screen is

The AR "department" (= `ST_CATEGORY_TYPE`) with its commission policy: target ranges and commission percentages (with and without
discount), item commissions, the manager's ranges, monthly targets of the department's salesmen and each salesman's achievement ranges.

## Blocks -> tables

| Legacy block | Table | APEX join |
|---|---|---|
| `ST_CATEGORY_TYPE` (رقم القسم، الاسم، جدول اعمار الديون، نسبة عمولة الإضافي، عدد إيام خارج المستهدف، نسبة خصم المتأخرات، أقصي عدد إيام للمتأخرات، أقصي إيام سداد لفواتير الخصم) | `ST_CATEGORY_TYPE` | master |
| `ST_CATEGORY_COMM` / `ST_CATEGORY_COMM_DISC` (بدون الخصم / بالخصم) | `ST_CATEGORY_COMM` split by `DISC_FLAG` 0/1 | `CATEGORY_TYPE_CODE` |
| `ST_CATEGORY_COMM_ITEMS` / `..._DISC_ITEMS` (عمولات الاصناف) | `ST_CATEGORY_COMM_ITEMS` | `CATEGORY_TYPE_CODE`; `SERIAL`, `DISC_FLAG` typed |
| `ST_CATEGORY_COMM_MNGR` / `..._DISC_MNGR` | `ST_CATEGORY_COMM_MNGR` | `CATEGORY_TYPE_CODE` |
| `AR_SALESMAN_COMM` (المستهدف للمندوبين: السنة، الشهر، التحصيل، المبيعات، نسبة التحصيل) | `AR_SALESMAN_COMM` | `CTGRY_CODE`; salesman `CODE` typed |
| `AR_SALESMAN_PRC_COMM` (مسلسل، الفترة من، الفترة إلى، النسبة) | `AR_SALESMAN_PRC_COMM` | `CTGRY_CODE`; salesman `CODE` typed |
| `SALESMAN` (navigation: salesmen of the department) | - | not placed (salesmen are kept in AR_SALESMAN) |

## Rules and buttons

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| range serial `NVL(MAX(SERIAL),0)+1 WHERE CATEGORY_TYPE_CODE AND NVL(DISC_FLAG,0) = flag` (COMM, MNGR); `WHERE CTGRY_CODE` (PRC) | embedded SQL | `key_expr` `next_comm_serial` (the generated key would have used DISC_FLAG / per salesman) | high |
| range start `NVL(MAX(TO_P),-1)+1`; no new range while one has `TO_P IS NULL` | embedded SQL | row rule `comm_row`; FROM read-only | high (message for the open range is ours) |
| "الفترة الى يجب أن يكون أكبر من الفترة من" | .fmx message | row rule | high |
| "يجب حذف أخر مسلسل أولا" | .fmx message | compound delete triggers `APP_RULES3_AR_CTGCOMM_BD / _CTGMNGR_BD / _SLSPRC_BD` | high |
| a range with item commissions cannot be deleted (`SELECT 1 FROM ST_CATEGORY_COMM_ITEMS WHERE SERIAL AND CATEGORY_TYPE_CODE AND DISC_FLAG`) | embedded SQL | same trigger, message "لا يمكن إلغاء سجل رئيسي في و جود سجلات تابعة له" | medium |
| a department with ranges cannot be deleted (`SELECT 1 FROM ST_CATEGORY_COMM / _MNGR WHERE CATEGORY_TYPE_CODE`) | embedded SQL | delete hook on the document delete (REQUEST = DELETE) | high |
| `DISC_FLAG` 0 / 1 only (two legacy blocks) | block names | row rule; default 0 | high |
| salesman of a target / range must belong to the department (`AR_CTGRY_SALESMAN.CTGRY_CODE = :dept`) | LOV WHERE | row rules `salesman_comm_row`, `comm_row('PRC')` | high |
| item commission: item active, group derived from the item, range must exist | item LOV (`NVL(STOP_FLAG,0)=0`) | row rule `comm_items_row`; `GROUP_CODE` optional | high |
| "لابد من حفظ السجل أولا" | .fmx message | APEX shows the detail grids only for a saved department | high |
| button "انزال الاصناف": items by group / item / supplier / kind ranges not yet in the range (`INSERT ... NOT IN (...)`), range checks "'يجب أن يكون 'الي رقم ...> من رقم ..." / "من رقم صنف اكبر من الي رقم صنف" | embedded SQL, messages | document action `LOAD_ITEMS` -> `app_rules3_ar.load_comm_items` (commission left empty for the user, as the legacy loaded the block) | high |
| labels (CODE = كود المندوب, COMM = النسبة / نسبة التحصيل, SALES_COMM = نسبة البيع, ...) | .fmx texts | `add_columns` | medium |

## Tests (rolled back)

Ranges numbered per department and flag with continuous FROM; TO <= FROM refused; flag 3 refused; item group derived; item for a missing
range refused; range with items not deletable; middle range not deletable, last deletable; manager range numbered; salesman outside the
department refused; salesman range numbered per department; loader loads once and skips existing items; loader range check; department
delete (document delete) refused while ranges exist. Part of the 89-check batch-1 suite, all passed.

## Coverage

- Reproduced: all numbering, continuity, delete and membership rules, the item loader.
- Not reproduced: the `SALESMAN` navigation block (salesmen are maintained in AR_SALESMAN; the salesman grids take the salesman code
  directly); `CUST_AGE` has no list of values on `AR_AGES` (generator has no per-column LOV override); print buttons.
- Question: confirm that "MNGR" is the department manager's ranges.
