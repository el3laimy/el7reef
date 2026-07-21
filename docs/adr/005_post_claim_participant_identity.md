<div dir="rtl">

# ADR-005 — حل هوية اللاعب بعد claim

**الحالة:** مقبول ومُنفّذ محليًا  
**التاريخ:** 2026-07-13

## السياق

MatchEvent تاريخي يجب ألا يتغير بعد claim، لكن عرض أهداف الضيف منفصلة عن حسابه المسجل يكرر اللاعب في leaderboard ويقسم لحظة الفخر بين هويتين.

## البدائل

- backfill لكل الأحداث التاريخية: كتابة واسعة وصعبة التراجع، وقد تمس audit history.
- دمج وقت القراءة: يحافظ على الحدث الأصلي ويعرض الهوية الحالية.

## القرار

اعتماد read-time merge. يجلب <bdi dir="ltr">TournamentTopScorersResolver</bdi> روابط <bdi dir="ltr">GuestPlayer.linkedPlayerId</bdi> الحالية للضيوف الموجودين في الأحداث، ثم يحوّل مفتاح التجميع إلى <bdi dir="ltr">player:{linkedPlayerId}</bdi>.

- الحدث المخزن يظل <bdi dir="ltr">guestPlayer</bdi> لأغراض التاريخ والتدقيق.
- أهداف الضيف السابقة وأهداف الحساب المسجل تُجمع في صف واحد.
- الرابط وكروت الهدافين بعد claim يتجهان إلى بروفايل اللاعب المسجل؛ قبل claim يظل badge ومسار الضيف.

## النتائج

لا نحتاج migration واسعة، لكن كل read model إحصائي جديد يجب أن يستخدم نفس سياسة canonicalization. جرد أنواع production يظل بوابة نشر لأن parser الجديد يرفض النوع المجهول بدل تحويله ضمنيًا إلى لاعب.

## التحقق

- <bdi dir="ltr">test/core/services/tournament_top_scorers_resolver_test.dart</bdi>
- <bdi dir="ltr">test/features/tournament/tournament_operations_dashboard_test.dart</bdi>
- <bdi dir="ltr">test/features/shareables/top_scorers_share_card_test.dart</bdi>

</div>
