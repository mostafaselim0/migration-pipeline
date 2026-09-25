# ST_SERVICE_STRUCTURE — تعريف هيكل مجموعات الخدمات / Services Structure (system 30, serial 40)

Deliverable: **none (no legacy source)**. Confidence: n/a.

## Evidence checked
* Registry: SYS_FILES 30/40, menu `SYSTEM_MENU.ST_GROUP_STRUCT`, file name ST_SERVICE_STRUCTURE.
* No `ST_SERVICE_STRUCTURE.fmb` / `.fmx` exists under `C:\Smart Transformation`, and GN_FORM_ITEM has no items for it (evidence
  pack empty). The generator therefore made an empty process page ("needs manual migration").
* The table the name points to is `ST_CHART_SERVICES` (levels CHR_STRU_LEVEL / START / END / LENGTH, Arabic / English names),
  read by the purchase-services chart ST_PU_SERVICES (its rule 1 "لابد من إدخال هيكل الخدمات أولا"). It is **empty** in the build
  copy, and so is ST_PU_SERVICES.

## Wave 3b
Swept: no legacy form, so no item properties, lists or buttons to carry over; none of the new keys applies.

## Open questions
* Is the services chart used? If yes, the structure screen is needed before any purchase service can be defined (ST_PU_SERVICES
  refuses every insert while ST_CHART_SERVICES is empty). The item-group structure screen ST_GROUP_STRUCT (GRID on
  ST_CHART_STRUCTURE with level / start / end / length rules) is the likely model, but the services form's own rules are not
  in the evidence, so nothing was built.

## Coverage
Reproduced: nothing (no legacy source).
Not reproduced: the whole screen — no evidence of its fields or rules (question above).
