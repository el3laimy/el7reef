<div dir="rtl">

# مصفوفة ملكية الكتابات الحساسة

> **تنبيه تاريخي:** هذه المصفوفة دليل لحالة 2026-07-13 وليست عقد التنفيذ الحالي. أزيل النداء العام `recordAuditEvent` ضمن `ELR-SEC-002`، وتوجد نتيجة الاحتواء الحالية في `docs/audits/2026-07-29_wave0_containment_audit.json`&rlm;. تحكم الأولويات والعقود الحالية الخطة `docs/core/00_Master_Product_Development_Plan.md`&rlm;.

**التاريخ:** 2026-07-13  
**النطاق:** Tournament Ego Core Loop

| البيانات | مالك الكتابة | تصنيف العميل | حماية rules | الدليل |
|---|---|---|---|---|
| نتيجة المباراة، MatchEvents، player stats، fan voting bootstrap | <bdi dir="ltr">submitMatchSettlement</bdi> | <bdi dir="ltr">callable-only</bdi> | منع create/update لـMatchEvents وplayer stats ومنع حقول النتيجة في update العميل | settlement unit + emulator smoke |
| اعتماد النتيجة والتقييمات | <bdi dir="ltr">approveMatchScore</bdi> | <bdi dir="ltr">callable-only</bdi> | العميل لا يكتب ratings أو status settled | approval unit + emulator smoke |
| إنشاء مباراة وتعديلات التشغيل غير النهائية | <bdi dir="ltr">MatchRepository/Matchday services</bdi> | <bdi dir="ltr">client-safe</bdi> بشروط | organizer/assistant وحقول مسموحة فقط | rules tests |
| إصدار claim code | <bdi dir="ltr">ShareLinkService</bdi> | <bdi dir="ltr">client-safe</bdi> بشروط | creator يملك الهدف ونوعه صالح | claim rules tests |
| دمج guest player/team | <bdi dir="ltr">GuestClaimService</bdi> | <bdi dir="ltr">service-only</bdi> | possession code + identity invariants + transaction | guest claim tests |
| audit event | <bdi dir="ltr">recordAuditEvent</bdi> | <bdi dir="ltr">callable-only</bdi> | منع create/update/delete من العميل | backend rules + function tests |

## نتيجة الجرد

- لا يوجد controller يستورد <bdi dir="ltr">cloud_firestore</bdi> أو يستخدم <bdi dir="ltr">FirebaseFirestore</bdi> مباشرة.
- أزيل مسار retry الذي كان يستدعي <bdi dir="ltr">MatchEventService.recordGoal/recordMvp/voidEvent</bdi> من controller؛ retry يمر الآن عبر التسوية الخادمية الحتمية.
- نقل تحديث صورة البروفايل من view إلى <bdi dir="ltr">ProfileController</bdi> بواجهة repository.
- يمنع <bdi dir="ltr">tool/architecture_guard.js</bdi> عودة هذه الأنماط، مع allowlist فارغة ومراجعة تلقائية لأي entry قديمة.

## حدود مقصودة

توجد implementations لـMatchEvent في data وخيار local fallback داخل <bdi dir="ltr">MatchSettlementService</bdi> للاختبارات فقط؛ القيمة الافتراضية <bdi dir="ltr">false</bdi> وrules تمنع الكتابة من تطبيق production.

</div>
