<div dir="rtl">

# جرد queries وميزانية القراءة لمسار البطولة

**التاريخ:** 2026-07-13

| التدفق | query الفعلي | index |
|---|---|---|
| تسوية MatchEvents الحالية | <bdi dir="ltr">matchId + status</bdi> | equality index merge؛ حد القراءة 205 |
| MatchEvents للمباراة | <bdi dir="ltr">matchId + eventType + status</bdi> | composite موثق |
| هدافو البطولة | <bdi dir="ltr">tournamentId + eventType + status</bdi> | composite موثق |
| هوية actor | <bdi dir="ltr">actor.kind + actor.id + status</bdi> | composite موثق |
| اكتشاف البطولة | <bdi dir="ltr">discoverable + visibility + status + createdAt desc</bdi> | composite موثق |
| بطولات المنظم/الفريق | organizer أو array contains مع <bdi dir="ltr">createdAt desc</bdi> | composite موثق |
| إعادة استخدام claim code | creator/target/status، وtournament اختياري، ثم <bdi dir="ltr">createdAt desc</bdi> | compositeان موثقان |
| مراحل البطولة والتسوية | مساواة على tournament/stage/group/bracket | single indexes أو index merge؛ لا <bdi dir="ltr">orderBy</bdi> خادمي زائد |

## ميزانية roster والتسوية

- snapshot التشكيلة: أقصى 4 وثائق.
- لاعبو طرف المباراة: أقصى 50 وثيقة.
- fallback لكل roster فريق رسمي أو ضيف: أقصى 50 وثيقة لكل طرف.
- وثائق الطرفين والـparticipants: بحد أقصى وثيقتين من كل نوع.
- MatchEvents النشطة: 205، أعلى من fan-out الأقصى لنتيجة 99–99 مع MVP.

القيم موجودة في <bdi dir="ltr">ROSTER_READ_LIMITS</bdi> و<bdi dir="ltr">ACTIVE_EVENT_READ_LIMIT</bdi> ومثبتة باختبارات Functions. لا يوجد <bdi dir="ltr">orderBy</bdi> في checks الخادمية الحرجة، ولذلك لم يُضف index غير مستخدم.

## توافق فهارس production

أظهر preflight بتاريخ 2026-07-14 أن production يحتوي 11 فهرسًا أقدم تستخدمها مسارات التحديات والمباريات والدعوات وفرق اللاعبين. حُفظت كلها داخل <bdi dir="ltr">firestore.indexes.json</bdi> بجانب الفهارس الجديدة، وأصبح <bdi dir="ltr">npm run check:indexes</bdi> يفشل إذا فُقد أي فهرس من baseline المنشور. نجح deploy dry-run للقواعد والفهارس بعد هذا الدمج دون نشر فعلي.

## أوامر التحقق

<pre dir="ltr"><code>npm run test:functions
npm run check:indexes
npm run test:functions:emulator
npm run test:rules:emulator</code></pre>

</div>
