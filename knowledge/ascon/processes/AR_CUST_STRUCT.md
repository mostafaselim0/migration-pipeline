# AR_CUST_STRUCT - هيكل دليل العملاء / Structure of Customers

- Registry: system 4 serial 36, no menu name, order 2011. Legacy `ASCON\AR\FMB\AR_CUST_STRUCT.fmx` (no .fmb, no labels); cloned from
  the GL chart-of-accounts structure form (messages still say "دليل الحسابات").
- APEX: `overrides\AR_CUST_STRUCT.json`, `MASTER_DETAIL`, master `AR_CHART_STRUCTURES`, details `AR_CHART_STRUCTURES_CHILD`
  (`CHR_STRU_LEVEL`) and `AR_LOCKUPS` (`TAB_PARENT = CHR_STRU_LEVEL`). Wave 1 had switched insert / delete off; wave 3 switched them on
  again and enforces the legacy lock with rules (`APP_RULES3_AR`). Confidence: medium-high.
- Data: 3 levels (1-1, 2-4, 5-12); 126 customers exist, so the structure is locked.

## Rules

| Rule | Evidence | APEX | Confidence |
|---|---|---|---|
| lock: while `CUSTOMER` has rows only the level names may change: "لا يمكن تعديل بيانات هيكل دليل العملاء أثناء وجود بيانات في الدليل ولكن يمكن تعديل اسم المستوي فقط" | `SELECT COUNT(CODE) FROM CUSTOMER`, message | row rule `struct_row('CUST')` (insert, start / end / length change) and delete trigger `APP_RULES3_AR_STRUCT_BD` | high |
| start of a new level = `NVL(MAX(CHR_STRU_END),0)+1`; `LENGTH = END - START + 1` | embedded SQL | row rule; START / LENGTH read-only and derived | high |
| "برجاء التأكد من إدخال -- حقل النهاية -- و كونه اكبر من حقل البداية و كذلك كونه أقل من 12" | message | row rule (END >= START - level 1 of the data is 1..1 - and END <= 12) | high |
| delete bottom-up only: "يجب حذف السجلات من أسفل إلي أعلي"; a deleted level takes its children and codes with it | messages, `DELETE FROM AR_LOCKUPS / AR_CHART_STRUCTURES_CHILD` | delete trigger (after the statement); the document delete removes the detail rows | high |
| structure must reach position 12: "برجاء استكمال هيكل دليل الحسابات حتي الخانة الثانية عشر ...." | message (KEY-COMMIT) | `warnings` (confirmation) - APEX saves one level per document, so the legacy refusal of an incomplete multi-row save becomes a confirmation | medium |
| level code length = level length: "يجب ان يكون طول التكويد مساوي لطول المستوى" | message | row rule `lockup_row('CUST')` | high |
| child `SEQ = NVL(MAX(SEQ),0)+1 WHERE CHR_STRU_LEVEL` | embedded SQL | generated max+1 key | high |

## Tests (rolled back)

New level refused, end change refused, name change accepted, delete refused (customers exist); code of wrong length refused, right length
accepted; warning silent for a complete structure (batch 1).

## Coverage

- Reproduced: lock, start / end / length rules, bottom-up delete, code length, completeness (as a confirmation).
- Not reproduced: "التأكد من وجود شركة مسجلة" (company check at form start: the APEX session always has a company); meaning of
  `AR_CHART_STRUCTURES_CHILD.DIR` unknown (labels "القسم / الكود / الاختصار / التقاطع" may be its values; used by `ADD_CUSTOMER_CHILD`,
  table empty) - question for the key user.
