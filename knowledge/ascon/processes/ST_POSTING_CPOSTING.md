# ST_POSTING_CPOSTING - ترحيل / إلغاء ترحيل حركات المخازن / Posting \ Cancel Posting Stores Transactions

- Registry: system 3 serial 510. APEX page 20290 was generated as a GRID on ST_TRNS_MAST (the form's only database block), which would have
  allowed editing transactions from a posting screen.
- **Deliverable: (b) process screen** (screen correction of the generated GRID)
  - PL/SQL: `app_proc_st.post_cancel(p_mode, ...)` in `app\db\20_proc_st.sql`; p_mode 1 = post (`post_trns` rules), 2 = cancel (`cancel_trns` rules).
  - Override: `app\legacy\overrides\ST_POSTING_CPOSTING.json` (parameter العملية = legacy list item FILTER; check boxes GL / AR / AP = buttons
    AC_BTN / AR_BTN / VN_BTN; "إلغاء القيود المجمعة" = alert MULT_ALET).
- **Confidence: high** - this .fmb is the source of the whole posting engine; rules, evidence, changes and tests are documented in
  `ST_POSTING.md` (posting) and `ST_CPOSTING.md` (cancellation).

Notes: the form was also called with parameters from the sales / purchase screens (`:PARAMETER.FROM_SCREEN` / `POST_ON_LINE` = 1: post one
transaction immediately). That "post on line" call is not part of this page; the transaction screens can call
`app_proc_st.post_trns(date, date, type, type, serial, serial, ...)` if the key user wants posting from the invoice.
