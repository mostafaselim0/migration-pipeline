# PR_MR: supplier requests for quotation (طلبات عروض أسعار الموردين), registry 30/34

**Deliverable:** screen rules (pattern AUTO), `app\legacy\overrides\PR_MR.json`, package `APP_RULES_SA`
(`rfq_det_row`, `quot_mast_row`, `rfq_validate`, `rfq_after_save` / `rfq_sync`).
**Confidence:** medium (compiled .fmx strings; never used: tables empty, no QUOT_TRNS_TYPE configured, so the list is empty).

## Rules implemented
| # | Rule | Where | Evidence (PR_MR.md) |
|---|---|---|---|
| F1 | List: RFQ types = ST_TRNS_TYPE.QUOT_TRNS_TYPE of the purchase-request types; group rights with FLAG = 1 (as the legacy block WHERE) | `where` | block WHERE |
| L1 | RFQ line: colour / size required when the item group has COLOR_FLAG / SIZE_FLAG ("يجب ادخال اللون" / "يجب ادخال المقاس") | row rule PR_REQ_DET | line validation SQL |
| S1 | Supplier (PR_QUOT_MAST): QUOT_SERIAL max + 1 per RFQ; currency of the supplier and its rate (supplier LOV); discount ≥ 0; accepting sets DATE_SEND, un-accepting clears it; no change of accept / reply / discount once a PO exists | row rule PR_QUOT_MAST (shared with PR_QUOT_TRNS) | supplier LOV, PR_QUOT_TRNS PRE-INSERT |
| A1 | After save: one empty price line per RFQ line for every supplier without lines (legacy POST-INSERT); lines of removed suppliers deleted; a supplier with an accepted quotation cannot be removed ("لا يمكن حذف طلب الاسعار حيث انة تم الموافقة علية"); REQ_STATUS back to 1 when no supplier is left | `rfq_after_save` (snapshot in `rfq_validate`) | supplier KEY-DELREC / POST-INSERT |
| R1 | REQ_STATUS read-only (set by the workflow) | `readonly` | status list |

## Not reproduced / notes
RFQs are created by the purchase-request conversion (not reproduced); header delete: blocked by the FKs while suppliers / lines exist
(legacy message 'توجد موردين مرتبطة بالعرض يجب حذف الموردين أولا' - wave 3: reproduced, see the end of this file). The legacy defect that nulled the
primary key of request lines on RFQ delete is not reproduced.

## Tests (ROLLBACK, temporary RFQ type 90014 via type 90013)
`t_misc.py` (RFQ part): QUOT_SERIAL / currency, generated price lines, accepted supplier removal.

## Wave 3 (delete)

| Legacy | APEX | Evidence / notes |
|---|---|---|
| PR_REQ_MAST KEY-DELREC: suppliers exist -> "توجد موردين مرتبطة بالعرض يجب حذف الموردين أولا"; else lines deleted with the header ("تم حذف العرض") | after-save DELETE `app_act_pr.rfq_after_delete`: the committed suppliers of the RFQ (flashback query) -> the legacy message, whole delete rolled back; lines removed by the generated cascade | the generated page deletes the detail grids first, so the check reads the committed state |

Tests (build copy, all rolled back, plain and inside a simulated APEX session of app 100 with the regenerated APPX_ triggers; scripts in the job folder `tmp\w3_purch`: t_vn.py, t_po.py, t_lot.py, t_st.py, t_quot.py, t_reg.py; static check chk.py): the rule runs without refusal for an RFQ without committed suppliers (the RFQ tables are empty; a refusal test needs committed
data, which the test rules forbid) - t_quot.py.

## Wave 3b
* REQ_STATUS "حالة الدورة": read-only list طلب عروض اسعار 1 / عروض أسعار من الموردين 2 / انتقاء عرض سعر وحيد 3 / عمل امر شراء 4 /
  استلام الكميات 5 / فواتير المشتريات 6 — the `DECODE(REQ_STATUS, 1, ..., 6, ...)` of the .fmx worklist query (list items REQ_STATUS /
  REQ_STATUS_DUMMY "مرحلة عرض السعر").
* Lists: TRNS_TYPE_CODE (RFQ types 7/25 with type rights), PR_TRNS_TYPE_CODE (purchase-request types 7/13), suppliers of the RFQ
  (not stopped, VN_SUPPLIER_PASSWORD range; .fmx supplier LOV); computed ITEM_NAME_A on the RFQ lines.
* Delete: `delete_lines: "refuse"` is **not** used — the legacy refused only while suppliers exist ("توجد موردين مرتبطة بالعرض يجب
  حذف الموردين أولا", wave-3 rule) and deleted the RFQ lines with the header, which the generator's default cascade does.
* Check: `check_forms.py PR_MR`.

## Coverage
Reproduced: RFQ rules (wave 2) and the delete rule / message (wave 3); cycle-status list, type / supplier
lists, item name (wave 3b).

Not reproduced, with the reason: the success text "تم حذف العرض" (the generated delete shows its own success message; a per-page
delete message needs a generator option); printing.
