<div dir="rtl">

# ADR: انتقال عمليات V1 الحساسة

**التاريخ:** 2026-06-11

## ما اتخذناه الآن

- أُغلقت كل الأسطح المرئية للفانتازي داخل V1.
- أُضيفت بوابة `CloudSensitiveOpsService` كعقد جاهز لنداءات الخادم.
- `AuditService` و`MatchSettlementService` أصبحا يحاولان استعمال callable backend أولًا، ثم يعودان للمسار المحلي إذا لم يكن الخادم متاحًا.

## أسماء النداءات المتوقعة

- `recordAuditEvent`
- `submitMatchSettlement`
- `approveMatchScore`
- `applyMatchRatings`
- `settleFantasyRound`

## ما يزال قائمًا كقرار معماري لاحق

- تنفيذ functions نفسها داخل مشروع Firebase منفصل أو ضمن `functions/`.
- نقل i18n إلى ARB / generated localizations على مستوى المشروع كله.
- استبدال بقية الألوان والمقاسات اليدوية تدريجيًا عبر token sweep أوسع.
- تشديد `claimCodes` beyond proof-of-possession يحتاج تصميم claim token server-side إذا أردنا أمانًا أعلى.

## ملاحظات تشغيلية

- إذا لم تكن الـ callable functions منشورة، يبقى السلوك الحالي كما هو.
- هذا يضمن أن البناء والاختبارات المحلية لا يتأثران أثناء مرحلة الانتقال.

</div>
