# ST_SUPPLIER_AGREEMENT — إتفاقية مورد / Supplier Agreement (system 30, serial 37)

Deliverable: **screen correction + business rules + buttons** — `overrides/ST_SUPPLIER_AGREEMENT.json` (MASTER_DETAIL
ST_SUPP_AGRMNT + suppliers ST_SUPP_AGRMNT_SUPP + items ST_SUPP_AGRMNT_DET; labels, read-only audit / approval columns,
defaults, row rules, validation, 4 actions), `APP_RULES3_PR` (`agrmnt_*`, `ratio_check`, `value_check`, `year_end`).
Pages 50230 / 50231. Confidence: **medium** (.fmx only; ST_SUPP_AGRMNT is empty, PR_ORDER.AGRMNT_NO unused).

## Why a screen correction
The generated page showed the **SUPPLIER file** — wrong. The legacy form maintains the agreement of a manufacturer
(KIND_CODE) under a contract type (CNTRCT_CODE) with its suppliers and items (price, quantity, bonus levels, discounts, targets).

## Rules
| # | Rule | Where | Evidence | Confidence |
|---|------|-------|----------|------------|
| 1 | Serial = max + 1 | generated key | `SELECT NVL(MAX(SERIAL),0)+1 FROM ST_SUPP_AGRMNT` | high |
| 2 | Required: manufacturer, contract type, dates — "يجب ادخال البيانات"; end after start — "يجب أن يكون توقيت الإنتهاء أكبر من توقيت البدء" | validation `agrmnt_validate` | messages | high |
| 3 | One agreement per manufacturer and contract type in the period — "يوجد تعاقد اخر لنفس المصنع مسجل علي نفس الفترة" | validation | `SELECT COUNT(1) FROM ST_SUPP_AGRMNT WHERE KIND_CODE = :b1 AND CNTRCT_CODE = :b2 AND END_DATE >= :b3` | high |
| 4 | Defaults: start today, end = 31/12 of the year, not stopped, approval 0 | `defaults` | WHEN-CREATE-RECORD values | medium |
| 5 | Approval level (APPROVE) is set only by the buttons; a new agreement starts at 0 | row rule `agrmnt_row` | approval buttons | high |
| 6 | Changing the end date needs `USERS.EDIT_AGRMNT_DATE` — "لايوجد لديك صلاحية تعديل التاريخ" | row rule | button "تعديل التاريخ" + message | high |
| 7 | Supplier: active supplier of the agreement's manufacturer (`VN_SUPP_KIND`, any supplier when the manufacturer has none) | row rule `agrmnt_supp_row` | supplier LOV | medium |
| 8 | Item line: item required "إختر صنف لهذا السجل أولاً", active item with a basic unit, no repeated item "صنف مكرر", name and supplier of the item, basic unit, sales price = retail price, discount 1 = MOH discount of the item | row rule `agrmnt_det_row` | line triggers / messages | high |
| 9 | Ratios 0 ≤ r < 100 — "أدخل رقم بقيمة تبدأ من الصفر و أقل من المئة"; values ≥ 0 — "ادخل قيمة اكبر من او تساوى صفر" | row rule | messages | high |
| 10 | Bonus ↔ bonus ratio, extra bonus ↔ ratio, discount ratio / value chain on the sales price, M_DISC value from its ratio, basic quantity | row rule (APP_RULES_PR `pair_ratio`, `disc_chain`) | WVI triggers | medium-high |

## Buttons
| Button | Implementation | Evidence |
|--------|----------------|----------|
| إعتماد (approve) | action APPROVE → `agrmnt_approve`: users of level n (`USERS.SUPP_AGRMNT_APPROVAL`) approve agreements at level n − 1; shown only then (`agrmnt_can`) | button, approval queue query of the .fmx |
| الغاء إعتماد (cancel approval) | action UNAPPROVE → `agrmnt_unapprove`: needs a level ≥ the agreement's "تحتاج صلاحية أكبر لإلغاء هذا الإعتماد"; refused once a purchase order used it "لقد تم إستخدام هذه الإتفاقية فى أمر شراء"; level back to 0 | messages, `PR_ORDER.AGRMNT_NO` SQL |
| إنزال أصناف المورد/المصنع (load items) | action LOAD_ITEMS → `agrmnt_load_items`: active items of the manufacturer supplied by the agreement's suppliers, not yet listed, with retail price and MOH discount | button + SQL |
| نسخ اتفاقية مورد (copy) | action COPY (new manufacturer, contract type, end date) → `agrmnt_copy`: new serial, start today, not approved, ORG_SERIAL = source serial, note "نسخ من مسلسل تعاقد", suppliers and lines copied; "تم اضافة مسلسل تعاقد" | `INSERT INTO ST_SUPP_AGRMNT (...)` of the .fmx |

## Open questions
* **Approval levels**: the legacy queue lists agreements whose APPROVE = user level − 1. In the data every user with an approval
  right has level 3 (users 0, 2, 3, 101, 103, 110), so no one can approve a new agreement (level 0 → 1). Is the equality right, or
  may a higher level approve directly?
* Cancel approval: back to 0 (implemented) or one level down?
* Totals ("الأجمالي", "إجمالي التعاقد", "إجمالي التعاقد (الكلي)") and the level / target tabs ("الحالة 1..4", "مستوى البونص والخصم
  على الصنف", "مستوى الخصم على المستهدف", "خصم مدة الدفع - السماح", "مستوى الهدف على الصنف"): computed displays / NB* columns whose
  rules are not visible; the target values P1..P4 are editable columns, the NB* level columns are not shown.

## Tests (`tmp\w3_prsa\t_w3prsa.py`, page 50231; approval fixtures at levels 2 and 3, one used by a purchase order)
AG1 numbering, approval 0 · AG2 end before start · AG3 overlapping agreement · AG4 own agreement passes · AG5 inactive
supplier refused · AG6 line derivations · AG7 ratio ≥ 100 · AG8 repeated item · AG9 negative value · AG10 load items ·
AG11 end date without right · AG12 end date with right · AG13 approval not editable · AG14 level-3 user cannot approve level 0 ·
AG15-AG16 approve level 2 → 3 · AG17 approve twice refused · AG17b user without level · AG17c cancel needs a higher level ·
AG18 cancel refused (used by a PO) · AG19 cancel → 0 · AG20 copy onto a running agreement refused · AG21-AG22 copy. All PASS.

## Wave 3b
* `rules.columns` ST_SUPP_AGRMNT.STOP_FLAG: check box 1/0 "متوقف" (was a number with the legend "(1 نعم)").
* Legacy LOVs of the .fmx as lists:
  - suppliers of the agreement (grid ST_SUPP_AGRMNT_SUPP): active suppliers of the agreement's manufacturer (`CODE IN (SELECT SUPP_CODE
    FROM VN_SUPP_KIND WHERE KIND_CODE = :ST_SUPP_AGRMNT.KIND_CODE)`), all active suppliers when the manufacturer has none (row rule 7);
    the header manufacturer is read through the line's SERIAL (`cascade: SERIAL`);
  - lines: GROUP_CODE from active groups (`STOP_FLAG = 0, GROUP_STATUS = 1`); ITEM_CODE from active items with a basic unit, of
    the chosen group or all (`cascade: GROUP_CODE`); UNIT_CODE from the units of the item (`ST_ITEM_UNIT`, basic unit marked
    "وحدة أساسية", `cascade: GROUP_CODE, ITEM_CODE`).
* Check: `check_forms.py ST_SUPPLIER_AGREEMENT` (4 lists run; units of item 101010001: 1 row); generated grid columns carry the
  cascade parents SERIAL / GROUP_CODE / GROUP_CODE,ITEM_CODE.
* Not covered: the totals and level / target tabs (formulas not visible).

## Coverage
Reproduced: corrected structure, header / line rules, approval and cancel with levels, end-date right, load items, copy; stop
check box and the legacy supplier / group / item / unit lists (wave 3b).
Not reproduced: totals and level / target tabs (computed displays whose formulas are not visible, question), "أختيار الكل / تعديل"
bulk edit of lines (no evidence of what it edits), save-first messages (Forms mechanics: APEX actions run on the saved document),
language switch.
