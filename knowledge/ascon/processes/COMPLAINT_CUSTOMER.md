# COMPLAINT_CUSTOMER - تسجيل شكاوي العملاء / Customer's Complaint Entering

- Registry: system 4 serial 32 (`FILES_MENU.ITEM180`). Legacy `ASCON\AR\FMB\Complaint_customer.fmx` (no .fmb). Tables empty.
- APEX: generated master-detail `COMPLAINT_CUSTOMER_MASTER` / `COMPLAINT_CUSTOMER_DETAIL` (pages 30060-30062) kept; rules in `APP_RULES3_AR`.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| serial `NVL(MAX(COMPLAINT_CUSTOMER_M_SER),0)+1 WHERE CODE AND DATE` | SQL | generated key (same rule) | high |
| customer: active leaf customer (`NVL(CUSTOMER_STATUS,0) = 1 AND NVL(STOPFLAG,0) <> 1`): "خطء في رقم العميل" | LOV, message | row rule `complaint_mast_row` | high |
| complaint code from `COMPLAINT_CODES`: "خطء في رقم المشكلة"; required | LOV, message | row rule + `key_expr` (the generated key would have put max+1 into the code) | high |
| repeated complaint code in one complaint: "صنف مكرر" / "سجل تم إدخاله من قبل." | `SELECT COUNT(*) ... AND COMPLAINT_CODE`, messages | primary key | high |
| customer name shown | `SELECT NAME_A, NAME_E FROM CUSTOMER` | `info` panel | high |

## Tests (rolled back)

Unknown customer refused; serial 1 then 2 for the same customer and day; code required; unknown code refused; valid line saved (batch 1).

## Coverage

- Reproduced: all rules. Button "ملف شكاوى العملاء" (opens COMPLAINT_CODES) is a menu entry in APEX.
- Not reproduced: a list of values on the customer column (generator: no per-column LOV override; the value is validated).
