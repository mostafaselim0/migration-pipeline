# GN_SYS - Application Server Confg

- Registry: system 99 serial 62, menu `SYSTEM_MENU.SYS_FORMS`, order 6002. APEX grid page 80220.
- Legacy module: `ASCON\SE\FMB\GN_SYS.fmx` (no .fmb, no GN_FORM_ITEM labels).
- **Deliverable: (a) screen correction** (wave 1) -> `app\legacy\overrides\GN_SYS.json`, pattern `GRID` on `GENERAL_FIXED_PARAMETER`, **update only**;
  wave 3 adds the column prompts (`rules.add_columns` labels). No business rules beyond the row count.
- **Confidence: medium-high** (single table; row-count rule inferred from the SQL).

## What the screen is

Technical configuration of the Forms/Reports installation: the one row of `GENERAL_FIXED_PARAMETER`
(`HOST_NAME`, `HOST_IP`, `REPORT_SERVER_NAME`, `CONFG_A`, `CONFIG_E`, `BI_IP`, `EUL_AR`, `EUL_EG`, `EXTERNAL_HOST` - no PK, 1 row, all columns filled).
.fmx identifiers also show `PORT`, `MACHINE`, `ADRESS`, `APPLICATION` (display items / prompts).

## Rules (evidence: embedded SQL)

1. `SELECT COUNT(*) FROM GENERAL_FIXED_PARAMETER G` - the form counts the rows; with a one-row configuration table this is the usual
   "insert only when empty" guard. APEX: insert and delete disabled, the existing row is editable.
2. LOVs `select distinct FORM_CODE from GN_FORM_ITEM` and `select item_code from GN_FORM_ITEM where form_code = :form_code`
   (record groups `FORM_CODE_RG`, `ITEM_CODE_RG`): helper lists of the template whose target items are not identifiable in the .fmx; not reproduced.
3. Column prompts (wave 3): Host name / Host IP / Report server / Config (A / E) / BI IP / EUL (AR / EN) / External host, with Arabic prompts.

No DB code in SMART reads `GENERAL_FIXED_PARAMETER` (checked `user_source`); in APEX the page is informational. The page is protected like every
page by the legacy screen rights (FILE_PASSWORD 99 / 62); user 0 always has access.

## Open questions

- Is the legacy report-server URL still needed (Oracle Reports called from APEX during coexistence), or can the menu entry be retired?


## Wave 3b

Checked, nothing to change: server parameters (text fields), update only as the legacy; no check box / list item / display item.

## Coverage

- Reproduced: rules 1 and 3.
- Not reproduced: rule 2 (template lists without a target), WEBUTIL / translation buttons.
