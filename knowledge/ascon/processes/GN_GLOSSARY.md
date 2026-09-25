# GN_GLOSSARY - القاموس / Glossary

- Registry: system 99 serial 51 (TRANSLATION_MENU.GN_GLOSSARY, order 4002). APEX grid page 80190.
- Legacy module: `ASCON\SE\FMB\GN_GLOSSARY.fmx`. One block GN_GLOSSARY (عربى / لاتينى).
- **Deliverable: none needed - plain code table, no business rules.** The generated grid (WORD_A required key, WORD_E) is the legacy screen.
- **Confidence: high.**

Evidence checked: labels GN_GLOSSARY.WORD_A / WORD_E; embedded SQL (2) are the FORM_CODE / ITEM_CODE lists of the translation template
(`select distinct FORM_CODE from GN_FORM_ITEM`, `select item_code from GN_FORM_ITEM where form_code = :form_code`) with no item using them in this
form; Arabic texts are the prompts only; table GN_GLOSSARY (0 rows, PK WORD_A); no DB trigger; no DB code reads GN_GLOSSARY.


## Wave 3b

Checked, nothing to change (no override needed): a two-column word list; no check box / list item / display item.

## Coverage

Reproduced: the table maintenance. Not reproduced: the unused template lists, print (GN_GLOSSARY report) and translation buttons.
No override, no package code, no test beyond the generated grid.
