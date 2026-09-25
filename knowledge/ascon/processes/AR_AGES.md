# AR_AGES - ملف اعمار الديون / Customer Age Files

- Registry: system 4 serial 35 (no menu). Legacy `ASCON\AR\FMB\Ar_Ages.fmx` (no .fmb, no labels). 1 row.
- APEX: generated report + form on `AR_AGES` (pages 30180/30181) kept; labels corrected (`add_columns`). No package code.

## Evidence checked

- Embedded SQL: only `SELECT NVL(MAX(AGE_ID),0)+1 FROM AR_AGES` (= the generated max+1 key).
- Messages: only the generic ones of the ASCON code-table template ("لا يجوز حذف السجل لإرتباطة بجداول اخري", "رقم مكرر تم إدخالة من قبل",
  unit texts copied from the template). Texts give the labels: الرقم، الأسم عربى، الأسم لاتينى، الفترة الاولى .. السابعة، أساسي.
- Used by: `ST_CATEGORY_TYPE.CUST_AGE` (ARTARGETRANGESCAT) and age reports.

## Coverage

- A plain code table: no business rules beyond the key (generated) and uniqueness (primary key).
- Labels of the seven periods and "أساسي" (`IS_DEFAULT`) set with `add_columns`.
- Question: may more than one table be "أساسي"? No evidence of a check in the form.
