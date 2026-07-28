<div dir="rtl">

# سجل تقاعد خطط الحريف واستعادتها

**الحالة:** `RECOVERY MAP — NOT AN ACTIVE PLAN`&rlm;

**تاريخ الجرد:** 29 يوليو 2026

**المرجع التنفيذي:** `docs/core/00_Master_Product_Development_Plan.md`&rlm;

**Checkpoint:** ‏commit `7eb4ece` والعلامة المحلية `docs-pre-consolidation-2026-07-28`&rlm;

هذا الملف لا يحمل أولويات أو مهامًا حية. وظيفته إثبات أن كل مصدر قديم استوعب أو حُفظ أو رُفض بقرار واضح، وتوفير مسار استعادة دقيق من Git دون إبقاء خطط متنافسة داخل المستودع.

## 1. طريقة الاستعادة

- يعرض الأمر `git show docs-pre-consolidation-2026-07-28:<old-path>`&rlm; النص الكامل لأي ملف متقاعد.
- يستعيد الأمر `git restore --source docs-pre-consolidation-2026-07-28 -- <old-path>`&rlm; ملفًا محددًا عند الحاجة إلى بحث تاريخي.
- يعكس `git revert <retirement-commit>`&rlm; عملية التقاعد كاملة دون استخدام `git reset --hard`&rlm;.
- لا تُستعاد خطة قديمة بوصفها backlog نشطة؛ تنقل الفكرة المطلوبة إلى المرجع الرئيسي بمعرّف جديد.

## 2. الملفات المحذوفة بعد الاستيعاب

| المسار القديم | Git blob قبل الحذف | آخر commit | القرار | المعرفات أو الأقسام المستوعبة |
| :--- | :--- | :--- | :---: | :--- |
| `product_plan.md` | `017e321fac821c7167e7306f7bafb0480d2bf023` | `d42a679` | `MERGED` | الرؤية والجمهور والمبادئ؛ `ELR-IDN-601`, `ELR-TEAM-602`, `ELR-BIZ-*` |
| `engineering_plan.md` | `19adac0fb25400ef3cc194a78799bb98b26e3c52` | `d42a679` | `MERGED` | الثوابت وDefinition of Ready/Done والذرية والخدمات المالكة |
| `implementation_backlog.md` | `f3bb178d23d3a3b41fb08d36fa8046e74102e3c9` | `4916d31` | `PARKED` | `IMP-001..035` → `ELR-FANT-001`؛ لا حالات Todo حية |
| `implementation_backlog_v2.md` | `e282dbf8d1b61acee952fd0fd4bda2ee9c2046ed` | `9a9a680` | `MERGED` | المنجز → `ELR-CORE-801..803`; المستقبل → `ELR-*-601..701`; Fantasy → `ELR-FANT-001` |
| `master_reference_alignment_gap_plan_ar.md` | `927d0bcaf5424cf2d93fd71d18d100b241d127f2` | `9a9a680` | `MERGED` | `ELR-IDN-601..602`, `ELR-GROW-601`, `ELR-TEAM-601`, `ELR-NOTIF-601`, `ELR-OPS-701`, `ELR-CORE-701` |
| `post_tournament_vision_priority_ar.md` | `536434e9d6267536561a3c422ee01df4baf14e70` | `9a9a680` | `MERGED` | ترتيب V1.1/V2 وشروط عدم تشتيت V1 |
| `tournament_repair_sprint_plan_ar.md` | `9d80b7e80a13e2bed0bd4a86a43713754188b33d` | `9a9a680` | `DONE/PARKED` | إصلاح البطولة → `ELR-CORE-801..803`; Fantasy → `ELR-FANT-001` |
| `tournament_tos_execution_rules.md` | `2b1780ee7289e4c1c1471bbce1d9d15c1ccb7989` | `bb7b330` | `MERGED` | الثوابت، الخدمة المالكة، الترتيب، Definition of Ready/Done |
| `tournament_tos_pilot_pass_checklist_ar.md` | `1b3926e7673417f3c4bc2c3d04205d3cb71c6ea2` | `9a9a680` | `MERGED` | Wave 6 ومصفوفة Android E2E وPilot |
| `tournament_tos_remaining_plan_ar.md` | `417bdb49d19572c23b7dbcd6b2f81c1cec92b373` | `9a9a680` | `DONE/MERGED` | `ELR-CORE-801..803`, `ELR-OPS-401..402`, Wave 6 |
| `docs/core/05_Project_Roadmap_and_Sprint_Plan.md` | `6c176d0a9e7916108589cb7ef2200ff5676f9e8c` | `9ec47e2` | `SUPERSEDED` | الرؤية وV1 والوديات الثانوية؛ التنفيذ الحالي في الأقسام 4 و8 |
| `docs/core/06_UX_Hardening_And_Liquid_Glass_Plan.md` | `c7fe7712c0cc4e5198926bd0c3e43c737b4c3191` | `9ec47e2` | `SUPERSEDED` | قرارات التصميم في `DESIGN.md`; المتبقي في `ELR-UX-301..304` |
| `docs/core/07_Tournament_Ego_UX_Audit_And_Repair_Plan.md` | `09e4c9e9937340db4f7bfcb045702c84a9e43454` | `9ec47e2` | `SUPERSEDED` | حلقة النمو في الرؤية؛ المنجز `ELR-GROW-801`; المتبقي ضمن V1 |
| `docs/core/08_Unified_V1_Completion_And_Workspace_Plan.md` | `22ed2df71bc5f012a311195a50b3a13260b983da` | `7eb4ece` | `SUPERSEDED` | بوابات V1 والقرارات المعمارية استوعبت في المرجع الرئيسي |
| `docs/core/15_Team_Lineup_Ultimate_Squad_Redesign_Plan.md` | `ecb510226b49a1b0b8467b3e072ce50524aaaa46` | `9ec47e2` | `DONE` | `ELR-UX-802`; regression الجديد `ELR-UX-301` |
| `docs/core/16_Architecture_Technical_Debt_Remediation_Tasks.md` | `1c6e2bd81e1823c70f515fbaa0825b213ae6855d` | `7eb4ece` | `SUPERSEDED` | `ELR-OPS-401..404` و`ELR-REL-502`; لا تُستخدم checkboxes القديمة |
| `docs/blueprints/El7reef_V1_Complete_Documentation.md` | `22dc9e4536363527a33254dc2515f6899f174814` | `f37c141` | `DUPLICATE` | نسخة مجمعة من وثائق `01..05`; تبقى `01..04` ويبقى التنفيذ هنا |
| `docs/blueprints/el_7_reef_complete_product_blueprint_draft_0.md` | `bfaffa86cb24bc42013b27e30438d66b09ceb96f` | `f37c141` | `MERGED` | الرؤية والثوابت والنطاق والـanti-goals في الأقسام 1–3 و13 |
| `docs/blueprints/el_7_reef_master_blueprint_working_version.md` | `4ea12dd974d9c9a87a9c573eb4bf74049ea659e6` | `f37c141` | `MERGED` | الرؤية والوضوح والنطاق؛ العقود المتخصصة تبقى في Blueprints المرجعية |

## 3. الملفات المنقولة كأدلة تاريخية

| المسار القديم | Git blob | آخر commit | المسار الجديد | التصنيف |
| :--- | :--- | :--- | :--- | :---: |
| `tournament_cross_app_flow_gap_report_ar.md` | `30247fa344a6ddae0fd919fe9cb03dac4fcca74f` | `9a9a680` | `docs/archive/evidence/tournament/tournament_cross_app_flow_gap_report_ar.md` | `HISTORICAL EVIDENCE` |
| `tournament_tos_walkthrough_ar.md` | `2242065a620ecebbade25f522685fdf00a2e2976` | `9a9a680` | `docs/archive/evidence/tournament/tournament_tos_walkthrough_ar.md` | `HISTORICAL EVIDENCE` |
| `docs/core/09_Workspace_Change_Manifest.md` | `9ff1fc35bce80eed3549e2fe8075d0e9f9ee417d` | `9ec47e2` | `docs/archive/evidence/planning/09_Workspace_Change_Manifest.md` | `HISTORICAL SNAPSHOT` |
| `docs/core/10_Documentation_Claim_Audit.md` | `3ec1a269f2323cfc9e5f1d5d4d2d5124266d940a` | `9ec47e2` | `docs/archive/evidence/planning/10_Documentation_Claim_Audit.md` | `HISTORICAL SNAPSHOT` |
| `docs/core/14_Execution_Progress_Report.md` | `6fd552a7390a2c8d1fe8fa697ea694f6b71b92d9` | `7eb4ece` | `docs/archive/evidence/planning/14_Execution_Progress_Report.md` | `HISTORICAL SNAPSHOT` |
| `A1_changes.diff` | `849463b389d42831ff30ab72cf1ebc76113e5c3c` | `271dfbc` | `docs/archive/evidence/planning/A1_changes.diff` | `HISTORICAL PATCH EVIDENCE` |

## 4. الملفات المعاد تسميتها دون فقد المحتوى

| المسار القديم | Git blob | المسار الجديد | القرار |
| :--- | :--- | :--- | :--- |
| `docs/core/17_V1_Security_And_Release_Completion_Plan.md` | `2149431ab684f530c67f2dd2dd8153ab2e0bd626` | `docs/core/00_Master_Product_Development_Plan.md` | توسع إلى المرجع الأم؛ aliases ‏`V3-*` محفوظة |
| `docs/sprints/sprint2/Sprint2_Task6_Claim_Code_Security_Hardening_Plan.md` | `ec745a9206346758ec4eaa467eb20f3e683869d7` | `docs/sprints/sprint2/Sprint2_Task6_Claim_Code_Security_Audit.md` | دليل تهديد تاريخي؛ ليس خطة نشطة |

## 5. المصادر المرجعية التي تبقى

- تبقى الملفات `AGENTS.md` و`PRODUCT.md` و`DESIGN.md`&rlm;.
- تبقى الوثائق الأساسية `docs/core/01..04` والـRunbooks ‏`11..13`&rlm;.
- تبقى ADRs وتقارير الأمن وSprints وWaves وQA&rlm;.
- تبقى Blueprints المتخصصة لدورة حياة البطولة والصلاحيات ونطاق V1 ومعمارية إحصائيات الزوار، مع وسمها كمراجع لا خطط نشطة.

## 6. commit التقاعد

**Retirement commit:** `PENDING` — يحدث بعد تنفيذ `git rm` و`git mv` ونجاح حارس التوثيق، ثم يسجل hash النهائي في commit توثيق لاحق.

</div>
