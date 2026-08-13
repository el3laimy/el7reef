<div dir="rtl">

# ADR: انتقال عمليات V1 الحساسة

> **تحديث القرار:** الجزء الذي سمح بـ`recordAuditEvent` اختياري مرسل من العميل أصبح مستبدلًا بالقرار `ELR-SEC-901` وباحتواء `ELR-SEC-002`&rlm;. أزيل النداء العام، ولا يُعتمد أي حدث كتدقيق موثوق إلا إذا أنشأته عملية خادمية موثوقة. تبقى بقية هذه الوثيقة سجلًا تاريخيًا لانتقال يونيو 2026.

**التاريخ:** 2026-06-11

## ما اتخذناه الآن

- أُغلقت كل الأسطح المرئية للفانتازي داخل V1.
- أُضيفت بوابة `CloudSensitiveOpsService` كعقد جاهز لنداءات الخادم.
- أُضيف مشروع callable backend داخل `functions/` في نفس الريبو.
- `MatchSettlementService` أصبح يستعمل backend أولًا لتسجيل واعتماد النتائج، ويفشل مغلقًا في الإنتاج إذا لم تُرجع الدالة نتيجة صالحة.
- المسار المحلي داخل `MatchSettlementService` مخصص للاختبارات فقط عبر `allowLocalFallback: true`، وليس fallback إنتاجيًا.
- الدالة `approveMatchScore` أصبحت تعتمد النتيجة server-side وتطبق rating، وتغلق تصويت الجمهور، وتعيد حساب ترتيب المجموعات أو تقدم الإقصاء داخل transaction واحدة قدر الإمكان&rlm;.
- `AuditService` يظل optional: فشل `recordAuditEvent` لا يعطل core flow مؤقتًا.

## أسماء النداءات المتوقعة

- `recordAuditEvent`
- `submitMatchSettlement`
- `approveMatchScore`

## ما يزال قائمًا كقرار معماري لاحق

- نقل i18n إلى ARB / generated localizations على مستوى المشروع كله.
- استبدال بقية الألوان والمقاسات اليدوية تدريجيًا عبر token sweep أوسع.
- تشديد `claimCodes` beyond proof-of-possession يحتاج تصميم claim token server-side إذا أردنا أمانًا أعلى.
- تنفيذ audit/backfill منفصل إذا ظهرت نتائج إنتاجية قديمة لديها `ratingsAppliedAt` بدون آثار rating أو bracket صحيحة&rlm;.

## ملاحظات تشغيلية

- إذا لم تكن دوال `submitMatchSettlement` و`approveMatchScore` منشورة، يفشل تسجيل/اعتماد النتائج من العميل بدل الكتابة المباشرة إلى Firestore.
- الاختبارات التي تحتاج المسار المحلي تمرر `allowLocalFallback: true` صراحة.
- `firebase.json` يربط `functions.source` بمجلد `functions`.

</div>
