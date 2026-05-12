# Service vs Rules Permission Gap

**التاريخ:** 2026-05-09

## الملخص

يوجد عدم اتساق مقصود حالياً بين طبقة الخدمات وقواعد Firestore في صلاحيات مساعدي البطولة.

`TournamentPermissionService` يحتوي منطقاً يسمح للمساعدين ببعض العمليات حسب الدور، بينما `firestore.rules` لا تسمح بعمليات الكتابة الحساسة إلا للمنظم الرئيسي عبر `organizerId`.

## أين تظهر الفجوة

| العملية | Service Layer | Firestore Rules |
| --- | --- | --- |
| تعديل نتائج المباريات | organizer + full + resultsOnly + emergency | organizer فقط |
| إدارة فرق البطولة | organizer + full + emergency | organizer فقط |
| إدارة الفرق/اللاعبين الضيوف في البطولة | organizer + full + emergency | organizer فقط |
| إصدار روابط claim لضيوف البطولة | organizer + full + emergency | organizer فقط |
| بدء المباراة | بحسب خدمات matchday/start | غالباً organizer فقط حسب وثيقة المباراة |

## التأثير الحالي

الوضع آمن قبل تفعيل صلاحيات المساعدين بالكامل لأن Firestore Rules هي الحاجز النهائي وتمنع غير المنظم من الكتابة.

أي واجهة تمنح مساعداً صلاحية في الخدمة قد تظهر نجاحاً منطقياً محلياً ثم تفشل عند الكتابة إلى Firestore إذا لم تُحدّث القواعد.

## المطلوب قبل تفعيل المساعدين في الإنتاج

1. تعريف مصدر الحقيقة لصلاحيات المساعدين داخل القواعد: subcollection `tournaments/{tournamentId}/assistants/{assistantUserId}`.
2. إضافة helper rules تتحقق من `status == active` ومن مفاتيح permissions المطلوبة.
3. تحديث قواعد عمليات البطولة والمباريات لتقبل organizer أو assistant بصلاحية محددة.
4. إضافة اختبارات rules لكل صلاحية: submit score، record goals/MVP، approve score، manage teams.
5. إبقاء أي صلاحية غير ممثلة في القواعد غير مفعلة في الواجهة.

## قرار V1 الحالي

لا يتم توسيع قواعد الكتابة للمساعدين في هذه المهمة. الأولوية الحالية هي إغلاق الثغرات الحرجة وإبقاء الحاجز النهائي محافظاً حتى يتم تنفيذ صلاحيات المساعدين end-to-end.
