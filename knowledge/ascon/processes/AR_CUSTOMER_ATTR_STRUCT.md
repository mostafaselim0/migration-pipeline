# AR_CUSTOMER_ATTR_STRUCT - متغيرات تعريف العميل / Customer Specification Structure

- Registry: system 4 serial 55 (no menu). Legacy `ASCON\AR\FMB\AR_CUSTOMER_ATTR_STRUCT.fmx` (no .fmb, no labels).
- APEX: corrected from a grid on `AR_CUSTOMER_ATTR_STRUCT` to `MASTER_DETAIL` with the legacy codes block `AR_CUSTOMER_ATTR_LOCKUPS`
  (`TAB_PARENT = CHR_STRU_LEVEL`, from `DELETE FROM AR_CUSTOMER_ATTR_LOCKUPS A WHERE A.TAB_PARENT`, texts الرمز / الأسم العربى / الأسم الإنجليزى).
  Rules in `APP_RULES3_AR`. Both tables empty; no customer has `ATTR_CODE`.
- What it is: the structure (levels, positions in a 24-character code) of the customer attribute code `CUSTOMER.ATTR_CODE`, with the
  allowed codes of each level (the CUSTOMER form builds `ATTR_CODE` from one list per level, `FORMAT_ATTR_CODE` / `LKP_CUST_ATTR`).

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| lock while customers have an attribute code (`SELECT COUNT(1) FROM CUSTOMER WHERE ATTR_CODE IS NOT NULL`): "لا يمكن حذف المستويات حيث أنه توجد ممجموعات أصناف معرفة بناء على هذه المستويات" | SQL, message | row rule `struct_row('ATTR')`, delete trigger `APP_RULES3_AR_ATTRSTRUCT_BD` | high |
| start = `NVL(MAX(CHR_STRU_END),0)+1`, length derived | SQL | row rule | high |
| "برجاء التأكد من إدخال --حقل النهاية-- و كونه أكبر من حقل البداية و كذلك كونه أقل من 24" | message | row rule | high |
| delete bottom-up: "يجب حذف السجلات من أسفل إلي أعلي" | message | delete trigger | high |
| "برجاء استكمال هيكل مجموعات الأصنـــاف" | message | confirmation (`warnings`) | medium |
| code length = level length: "يجب ان يكون طول التكويد مساوي لطول المستوى" | message | row rule `lockup_row('ATTR')` | high |

## Tests (rolled back)

Levels 1 (1-4) and 2 (5-10) derived; end 25 refused; incomplete warning; level 1 delete refused (bottom-up); level 2 deleted (batch 1).

## Coverage

- Reproduced: lock, numbering / length, bottom-up delete, code length, completeness confirmation, the codes block.
- Deliberately not reproduced: `DELETE FROM ST_LOCKUPS WHERE TAB_PARENT = :level` executed by the legacy delete - a copy-paste from the
  item-group structure form that deletes the *stock* structure codes of the same level number (data loss); `ST_BASIC.GROUP_PRE_CODE`
  read (item-group logic, not used here). Question: confirm the ST_LOCKUPS delete was a bug.
