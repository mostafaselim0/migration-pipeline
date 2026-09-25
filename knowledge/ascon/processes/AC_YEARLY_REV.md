# AC_YEARLY_REV - شاشة مراجعة القيود / Entry Revision (+ serial 11 شاشة إلغاء مراجعة القيود)

- Registry: system 1 serial 10 "Entry Revesion" and serial 11 "Entry Cancel Revesion" (same form, parameter P_REV). APEX grid page 10250
  (both menu entries open it).
- Legacy module: `ASCON\AC\FMB\AC_YEARLY_REV.fmx` (no .fmb; labels of block AC_YEARLY_TRN).
- **Deliverable: screen correction**: override `app\legacy\overrides\AC_YEARLY_REV.json`, pattern `GRID` on AC_YEARLY_TRN, update only,
  every column read-only except the "مراجع" flag REV1. No PL/SQL needed.
- **Confidence: high** (block WHERE of the .fmx).

## Rules

| # | Rule | Legacy evidence | APEX |
|---|------|-----------------|------|
| 1 | Only the posted entries of the current year, and only when entries revision is switched on | block WHERE `NVL(REV1,0) = NVL(:P_REV,0) and entry_year = (select current_year from ac_basic where company_code = :2 AND NVL(REV_FLAG,0) = 1)` | `where` (AC_BASIC.REV_FLAG = 0 today, so the list is empty, as in the legacy) |
| 2 | Only REV1 (مراجع) is changed: revision screen ticks, cancel-revision screen unticks | items: all display except REV1 | grid update only, readonly columns |
| 3 | A reviewed entry cannot be deleted while revision is on | existing DB trigger REV_AC_YEARLY | kept (DB) |
| 4 | Access through FILE_PASSWORD of the menu entry | CHECK_FILE_PREV | APP_SEC page rights (both serials map to the page) |

## Wave 3b

POST_SYSTEM is shown as the legacy list POST_SYSTEM_LIST (record group SYSTEMS_A / SYSTEMS_E of `evidence\AC_YEARLY_REV.md`: SYS_SYSTEMS
except 0 / 99): `lov` (select list, read-only). "تفاصيل القيد" (BUT_GO_ENTRY) opens the entry of the current row: a link per row, not
supported by the generator (a page-level link cannot pass the row's entry).

## Coverage

- Reproduced: rules 1-4, the system column (POST_SYSTEM) as the legacy system list.
- Deviation: one page for both menu entries shows reviewed and unreviewed entries together (the legacy parameter P_REV split them);
  the flag column tells them apart.
- Reproduced (wave 3b, main session): "تفاصيل القيد" - the entry number of each row is a link that opens the entry in ACYRTR
  (`columns.AC_YEARLY_TRN.ENTRY_NO.link`, by the row's ROWID).
- Not reproduced: the journal serial status
  print.
