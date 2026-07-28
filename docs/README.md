# الحريف — فهرس التوثيق الحاكم

هذه الحزمة تحتوي على مواصفات وأدلة تطوير تطبيق الحريف وفق اتجاه **نواة مجد البطولات**. المرجع الوحيد للأولوية والحالة وصندوق الأفكار هو `docs/core/00_Master_Product_Development_Plan.md`&rlm;.

---

## 📁 `core/` — الوثائق الأساسية

| النوع | الوثيقة | الوصف |
|---|---------|-------|
| المرجع الحاكم | `00_Master_Product_Development_Plan.md` | **الخطة النشطة الوحيدة، لوحة V1، خارطة ما بعد الإصدار وصندوق الأفكار** |
| 1 | `01_PRD_Product_Requirements_Document.md` | وثيقة متطلبات المنتج |
| 2 | `02_SRS_Software_Requirements_Specification.md` | مواصفات متطلبات البرنامج |
| 3 | `03_SAD_System_Architecture_Document.md` | هيكلية النظام والتصميم عالي المستوى |
| 4 | `04_UI_UX_Designs.md` | تصميمات واجهة وتجربة المستخدم |
| 11 | `11_Tournament_Membership_Migration_Runbook.md` | تشغيل آمن لترحيل عضويات منظمي البطولات القديمة |
| 12 | `12_Data_Inventory_Retention_And_Data_Safety.md` | جرد البيانات ومصفوفة الاحتفاظ وورقة Data Safety |
| 13 | `13_Play_Review_And_Moderation_Runbook.md` | حزمة مراجعة Play ومسار الإشراف على المحتوى |

> ابتداءً من 2026-07-29، لا ينشأ ملف Roadmap أو Backlog جديد. تستخدم المراجع المتخصصة للتفاصيل فقط، بينما تتغير الأولوية والحالة داخل الوثيقة `00` وحدها.

---

## 📁 `blueprints/` — مراجع معمارية متخصصة

- `el_7_reef_tournament_lifecycle_and_scheduling_blueprint.md` — دورة حياة البطولة والجدولة
- `el_7_reef_role_and_permission_matrix.md` — مصفوفة الأدوار والصلاحيات
- `el_7_reef_v_1_scope_and_anti_goals.md` — نطاق V1 والأهداف المستبعدة
- `GUEST_AWARE_STATS_ARCHITECTURE_PROPOSAL.md` — اقتراح معمارية الإحصائيات للضيوف

هذه الملفات `REFERENCE — NOT AN ACTIVE PLAN`&rlm;، وتعود أي فجوة تنفيذية منها إلى معرّف داخل المرجع الحاكم.

---

## 📁 `archive/` — الاستعادة والأدلة التاريخية

- يسجل `PLANNING_RETIREMENT_MANIFEST.md`&rlm; الـGit blobs والـCrosswalk ومسارات استعادة الخطط المتقاعدة.
- يحفظ `evidence/planning/`&rlm; لقطات مساحة العمل والتقدم القديمة.
- يحفظ `evidence/tournament/`&rlm; تقارير رحلة البطولة التاريخية.

لا يحمل هذا المجلد حالات تنفيذ حية.

---

## 📁 `audits/` — التدقيقات والمراجعات

- `Master_Blueprint_vs_Current_Code_Gap_Audit.md` — تدقيق الفجوة بين المخطط والكود
- `el_7_reef_current_code_gap_audit_initial_pass.md` — المسح الأولي لفجوات الكود
- `V1_RELEASE_RISK_REVIEW.md` — مراجعة مخاطر إصدار V1
- `V1_RELEASE_SCOPE_AUDIT.md` — تدقيق نطاق الإصدار
- `2026-07-28_v1_security_completion_audit.json` — الحكم القابل للآلة على ثغرات الأمن وCI المرتبطة بخطة الإطلاق الحالية

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
