# GN_FORM_ITEM - ترجمة الشاشات / Forms Translation

- Registry: system 99 serial 50 (TRANSLATION_MENU.GN_FORM_ITEM, order 4001). APEX list page 80180, document page 80181.
- Legacy module: `ASCON\SE\FMB\GN_FORM_ITEM.fmx`. Blocks SYS_SYSTEMS (system) -> GN_FORM (distinct FORM_CODE of the system) -> GN_FORM_ITEM
  (items: type, prompt / label / tooltip / hint in Arabic and English, "يظهر فى") -> GN_FORM_ITEM_RAD (radio buttons, width A / E).
- **Deliverable: (a) screen correction** - `app\legacy\overrides\GN_FORM_ITEM.json`: MASTER_DETAIL GN_FORM_ITEM -> GN_FORM_ITEM_RAD with the
  English columns and SHOW_IN_LANG added (the generated page had only the Arabic texts); keys editable on new rows only (wave 3b); no
  package code.
- **Confidence: high.**

GN_FORM_ITEM (32,097 rows) is the label source of the generator (`labels.py`) and of the English translation: edits here change the APEX labels at
the next build.

## Rules

| # | Legacy rule | Evidence | APEX |
|---|---|---|---|
| 1 | Edit the Arabic and English prompt, label, tooltip and hint of an item | labels GN_FORM_ITEM.*_A / *_E | columns added (`add_columns`) |
| 2 | "يظهر فى العربى و الإنجليزى / فى العربى فقط / فى الإنجليزى فقط" | SHOW_IN_LANG list item; data 0 / 1 / 2 / null | wave 3b: static list (0 / 1 / 2) |
| 3 | Radio-button labels of a radio item | GN_FORM_ITEM_RAD block | detail grid |
| 4 | Item / radio rows with details cannot be deleted | `SELECT 1 FROM GN_FORM_ITEM WHERE SYSTEM_NUMBER AND FORM_CODE`, `SELECT 1 FROM GN_FORM_ITEM_RAD ...` (relation checks) | the generated document delete removes the radio rows first |

## Wave 3b

- `ITEM_CODE: {"lov": null}` removes the wrong ST_ITEM list (item names such as `CTRL.SAVE_BTN` are free text).
- With that list gone, items and radio buttons can be created again (the only reason insert was off): `rules.blocks` insert on for both
  blocks; the keys SYSTEM_NUMBER, FORM_CODE, ITEM_CODE, ITEM_TYPE and RADIO_BUTTON are editable on a new row only (`readonly_after_insert`).
- SYSTEM_NUMBER shows the system name (list of SYS_SYSTEMS, the legacy master block).
- SHOW_IN_LANG (list item "يظهر فى"): static list 0 يظهر فى العربى و الإنجليزى / 1 يظهر فى العربى فقط / 2 يظهر فى الإنجليزى فقط - values from
  TRANSLATE.pll SET_ITEM_PROMPT (`SHOW_IN_LANG = 1` hides the item in English, `= 2` in Arabic), labels from the .fmx texts.
- ITEM_TYPE (list item "نوع الوحدة") stays a text field: the .fmx shows no labels for its values (T, D, B, C, LS, L, R, W, O, CNT).

## Coverage

- Reproduced: rules 1-4; creating items and radio buttons, the "shown in" list and the system name (wave 3b).
- Not reproduced: the system -> form tree navigation (the list page filters by system / form), the FORM_CODE / ITEM_CODE query lists,
  the ITEM_TYPE labels, translation / print buttons.
