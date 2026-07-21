<div dir="rtl">

# جرد تمثيل الوقت على حدود Firestore

**التاريخ:** <bdi dir="ltr">2026-07-13</bdi>

## النتيجة

الكود الحالي يستخدم تمثيلين:

- أغلب Tournament Ego Core يخزن الوقت كـmilliseconds رقمية، ومنها <bdi dir="ltr">matches</bdi> و<bdi dir="ltr">matchEvents</bdi> و<bdi dir="ltr">tournaments</bdi> و<bdi dir="ltr">tournamentParticipants</bdi> و<bdi dir="ltr">tournamentGroups</bdi> و<bdi dir="ltr">groupStandingSnapshots</bdi> و<bdi dir="ltr">knockoutBrackets</bdi> و<bdi dir="ltr">knockoutTies</bdi> و<bdi dir="ltr">guestPlayers</bdi> و<bdi dir="ltr">guestTeams</bdi> و<bdi dir="ltr">teamMemberships</bdi>.
- نماذج قديمة مثل <bdi dir="ltr">friendships</bdi> و<bdi dir="ltr">challenges</bdi> و<bdi dir="ltr">matchInvitations</bdi> تستخدم Firestore <bdi dir="ltr">Timestamp</bdi> مباشرة.

## قرار التوافق

- <bdi dir="ltr">FirestoreDateAdapter</bdi> يقرأ <bdi dir="ltr">Timestamp</bdi> وmilliseconds و<bdi dir="ltr">DateTime</bdi> خلال الانتقال.
- الكتابات الجديدة للمجموعة التي تُرحّل تستخدم <bdi dir="ltr">Timestamp</bdi>.
- الترحيل يتم collection واحدة في كل تذكرة؛ بدأت الشريحة الأولى بـ<bdi dir="ltr">matchEvents.createdAt</bdi> لأنها عقد مشترك بين Flutter وCloud Functions.
- لا يوجد backfill شامل في هذه التذكرة، وتظل القراءة متوافقة مع البيانات الرقمية القديمة.

## الشريحة الأولى — matchEvents

- Flutter يكتب <bdi dir="ltr">createdAt</bdi> كـ<bdi dir="ltr">Timestamp</bdi> ويقرأ الشكلين.
- Cloud Functions يكتب Admin SDK Timestamp بالفعل في مسار settlement الجديد.
- الاختبارات تغطي round-trip الجديد وقراءة milliseconds القديمة.

## الشرائح التالية

كل collection لاحقة تحتاج تذكرة مستقلة تشمل: query/index impact، backward-compatible read، اختبار النموذج، وخطة rollback قبل تحويل الكتابة.

</div>
