# El7reef V1 — فهرس التوثيق

هذه الحزمة تحتوي على وثائق أول إصدار عملي من تطبيق الحريف وفق الاتجاه المنتجي: **Tournament Ego MVP**.

---

## 📁 `core/` — الوثائق الأساسية

| # | الوثيقة | الوصف |
|---|---------|-------|
| 1 | `01_PRD_Product_Requirements_Document.md` | وثيقة متطلبات المنتج |
| 2 | `02_SRS_Software_Requirements_Specification.md` | مواصفات متطلبات البرنامج |
| 3 | `03_SAD_System_Architecture_Document.md` | هيكلية النظام والتصميم عالي المستوى |
| 4 | `04_UI_UX_Designs.md` | تصميمات واجهة وتجربة المستخدم |
| 5 | `05_Project_Roadmap_and_Sprint_Plan.md` | خطة المشروع والـ Sprint Plan |
| 6 | `06_UX_Hardening_And_Liquid_Glass_Plan.md` | خطة تقوية تجربة المستخدم وحالات الاستخدام واتجاه Liquid Glass |
| 7 | `07_Tournament_Ego_UX_Audit_And_Repair_Plan.md` | تدقيق رحلة البطولة والمشاركة قبل توحيد الخطط |
| 8 | `08_Unified_V1_Completion_And_Workspace_Plan.md` | **الخطة التنفيذية الوحيدة النشطة لإكمال V1 وترتيب مساحة العمل** |
| 9 | `09_Workspace_Change_Manifest.md` | Manifest الحزمة الحالية وتقسيمها إلى checkpoints قابلة للمراجعة |
| 10 | `10_Documentation_Claim_Audit.md` | تدقيق الادعاءات الحية واللقطات التاريخية لوثائق التنفيذ |
| 11 | `11_Tournament_Membership_Migration_Runbook.md` | تشغيل آمن لترحيل عضويات منظمي البطولات القديمة |
| 12 | `12_Data_Inventory_Retention_And_Data_Safety.md` | جرد البيانات ومصفوفة الاحتفاظ وورقة Data Safety |
| 13 | `13_Play_Review_And_Moderation_Runbook.md` | حزمة مراجعة Play ومسار الإشراف على المحتوى |
| 14 | `14_Execution_Progress_Report.md` | تقرير التقدم الحي ومحاولات التحقق ومنع الدوران |

> ابتداءً من 2026-07-11، الوثيقة رقم 8 هي مصدر ترتيب التنفيذ والقبول الوحيد. الوثائق والخطط الأقدم تبقى مراجع قرار وأدلة تاريخية، ولا تُستخدم كـ backlog موازية.

---

## 📁 `blueprints/` — التصميمات والخطط المعمارية

- `el_7_reef_complete_product_blueprint_draft_0.md` — مسودة المخطط الشامل للمنتج
- `el_7_reef_master_blueprint_working_version.md` — نسخة العمل من المخطط الرئيسي
- `el_7_reef_tournament_lifecycle_and_scheduling_blueprint.md` — دورة حياة البطولة والجدولة
- `el_7_reef_role_and_permission_matrix.md` — مصفوفة الأدوار والصلاحيات
- `el_7_reef_v_1_scope_and_anti_goals.md` — نطاق V1 والأهداف المستبعدة
- `El7reef_V1_Complete_Documentation.md` — التوثيق الشامل لـ V1
- `GUEST_AWARE_STATS_ARCHITECTURE_PROPOSAL.md` — اقتراح معمارية الإحصائيات للضيوف

---

## 📁 `audits/` — التدقيقات والمراجعات

- `Master_Blueprint_vs_Current_Code_Gap_Audit.md` — تدقيق الفجوة بين المخطط والكود
- `el_7_reef_current_code_gap_audit_initial_pass.md` — المسح الأولي لفجوات الكود
- `V1_RELEASE_RISK_REVIEW.md` — مراجعة مخاطر إصدار V1
- `V1_RELEASE_SCOPE_AUDIT.md` — تدقيق نطاق الإصدار

---

## 📁 `security/` — تقارير الأمن والصلاحيات (P0)

- `P0_Task1` — فصل العرض العام عن لوحة المنظم
- `P0_Task2` — قواعد صلاحيات البطولة واختبارات المحاكي
- `P0_Task3` — تقوية قواعد Firestore للتسجيلات وأحداث المباراة
- `P0_Task4` — قواعد مجموعات عمليات البطولة
- `P0_Task5` — تقوية حراسات طبقة الخدمات

---

## 📁 `sprints/` — تقارير السبرنتات

### `sprint0/` (مهمتان)
- Surface Freeze Report
- Test Baseline Report

### `sprint1/` (27 تقرير)
المهام 1–9: من تأسيس MatchEvent حتى بطاقة مشاركة الهدافين.
يشمل تقارير المهام، مراجعات العمارة، واختبارات التقوية.

### `sprint2/` (25 تقرير)
المهام 1–11: من بطاقة MVP حتى إصلاح عزل الجلسة.
يشمل تقارير الأمن، ادعاء الضيوف، وتقوية الكود.

---

## 📁 `waves/` — تقارير Wave 2

- `Wave2_Task6` — واجهة التسجيل الأولى للضيوف
- `Wave2_Task7` — سياسة لوحات المتصدرين الرسمية
- `Wave2_Task8` — اتساق أحداث التسجيل

---

## 📁 `qa/` — اختبارات الجودة

- `friendly_match_core_loop_qa.md` — اختبار QA للحلقة الأساسية للمباريات الودية

---

## ملاحظة

يجب تشغيل الأوامر التالية قبل أي إصدار:

```bash
flutter pub get
dart analyze lib/
flutter test
flutter build appbundle --release
```
