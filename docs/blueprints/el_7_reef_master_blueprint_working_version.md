# El7reef Master Blueprint — Working Version

## 0. Purpose

هذه هي الوثيقة المرجعية الوحيدة الحالية لتطبيق الحريف. أي وثائق سابقة تعتبر مصادر خام أو ملاحق، وليست مصدر قرار يومي.

هدف الوثيقة: تثبيت تصور المنتج قبل تنفيذ المزيد من المهام.

---

## 1. Product North Star

الحريف هو تطبيق لإدارة بطولات كرة قدم صغيرة بطريقة سهلة، واضحة، وممتعة، مع إبراز لحظات الفخر للاعبين والفرق: أهداف، MVP، ترتيب، وبطاقات مشاركة.

V1 ليس شبكة اجتماعية كاملة، وليس نظام حجز ملاعب، وليس دوري احترافي معقد.

V1 هو:

```text
Tournament Ego MVP
```

أي: منظم يستطيع إنشاء بطولة حقيقية صغيرة، إدخال فرق ولاعبين، ترتيب مباريات، تسجيل نتائج، وإخراج لحظات قابلة للمشاركة.

---

## 2. Core UX Rule — وضوح الشاشات والتنقل

هذه قاعدة أساسية لا تقل أهمية عن الصلاحيات.

يجب أن تكون شاشات التطبيق واضحة، بسيطة، ومنطقية في التنقل. لا نريد منظمًا تائهًا بين شاشات متشابهة أو أزرار غامضة.

### 2.1 Organizer UX Rule

شاشة المنظم يجب أن تجيب فورًا على 4 أسئلة:

1. أين أنا الآن في دورة إنشاء/إدارة البطولة؟
2. ما الخطوة التالية؟
3. هل توجد مشكلة تمنعني من نشر/تشغيل البطولة؟
4. ما الذي يستطيع اللاعبون أو الفرق رؤيته الآن؟

### 2.2 ممنوع في V1

- شاشات إدارة كثيرة بلا ترتيب واضح.
- أزرار إدارية تظهر في public views.
- مصطلحات غامضة مثل “Operations” بدون معنى للمستخدم.
- خلط “عرض البطولة” مع “إدارة البطولة”.
- إجبار المنظم على فهم البنية الداخلية للنظام.

### 2.3 Organizer Navigation Model المقترح

بدل تشتيت المنظم، إدارة البطولة يجب أن تكون Wizard / Dashboard واضح:

```text
Tournament Organizer Dashboard
1. بيانات البطولة
2. الفرق والمشاركون
3. نظام البطولة
4. جدول المباريات
5. النتائج والاعتماد
6. الهدافون وMVP والمشاركة
7. النشر/الحالة
```

كل خطوة تعرض:

- الحالة الحالية.
- ما اكتمل.
- ما ينقص.
- زر action واضح.

---

## 3. V1 Offline/Hybrid Participation Rule

قاعدة مهمة جدًا:

> في V1، يجب أن يستطيع المنظم إنشاء بطولة كاملة حتى لو لا يوجد أي لاعب أو فريق مسجل في التطبيق.

أي أن البطولة يجب أن تدعم 3 أوضاع مشاركة:

### 3.1 كل المشاركين غير مسجلين

المنظم ينشئ:

- فرق كـ guest teams أو manual teams.
- لاعبين كـ guest players.
- مباريات وجدول ونتائج.
- هدافين/MVP من guest players.

ثم يمكن لاحقًا للاعبين استلام ملفاتهم عبر claim link.

### 3.2 بعض المشاركين مسجلون وبعضهم ضيوف

الفريق قد يحتوي:

- registered players.
- guest players.

والبطولة قد تحتوي:

- registered teams.
- guest/manual teams.

### 3.3 كل المشاركين مسجلون

هذا هو الوضع المثالي، لكن لا يجب أن يكون شرطًا لعمل البطولة.

### 3.4 نتيجة هذه القاعدة

لا يجوز أن يعتمد V1 على وجود:

- friend system كامل.
- player search كامل.
- team invite كامل.
- كل اللاعبين لديهم حسابات.

هذه features مهمة لاحقًا، لكنها لا يجب أن تمنع المنظم من تشغيل بطولة.

---

## 4. V1 Core Loop

```text
Organizer creates tournament
→ Organizer adds/approves teams
→ Teams may be registered or guest/manual
→ Organizer adds players if needed
→ Organizer generates/creates fixtures
→ Organizer schedules matches
→ Matches are played
→ Scores are submitted/approved
→ Goals + MVP are recorded
→ Top scorers/profiles/share cards update
→ Guest players can claim identity later
```

---

## 5. V1 Scope

### يدخل V1

- إنشاء بطولة بسيطة.
- منظم واحد واضح.
- فرق registered أو guest/manual.
- لاعبين registered أو guest.
- إضافة ضيوف بسرعة.
- ترتيب مباريات بسيط.
- مواعيد مباريات أساسية.
- إدخال نتائج واعتمادها.
- Goals/MVP.
- Top scorers.
- Public profiles.
- Guest claim عبر token.
- Share cards.
- صلاحيات أساسية قوية.

### لا يدخل V1

- friends graph كامل.
- challenges كامل.
- auto scheduling معقد.
- venue booking.
- payments.
- custom permissions.
- co-organizers متقدمين.
- referee system كامل.
- league engine معقد.

---

## 6. User Roles — V1

### 6.1 Organizer

ينشئ ويدير البطولة.

صلاحياته:

- تعديل بيانات البطولة.
- إضافة/قبول فرق.
- إضافة guest teams/players إذا لزم.
- توليد/إنشاء المباريات.
- تحديد المواعيد.
- اعتماد النتائج.
- إعلان no-show/forfeit إن تم دعمه.

### 6.2 Team Captain / Owner

يدير فريقًا محددًا فقط.

صلاحياته:

- إدارة roster فريقه.
- إضافة guest players لفريقه.
- مشاركة claim links لضيوفه.
- تقديم فريقه للبطولة إذا registration flow مفعل.

لا يدير البطولة نفسها.

### 6.3 Player

يشارك، يرى ملفه وإحصائياته، وقد يقبل دعوات لاحقًا.

### 6.4 Guest Player

لاعب مؤقت أنشأه organizer أو captain، ويمكن claim لاحقًا.

### 6.5 Viewer

يرى public surfaces فقط، ولا يدير أي شيء.

---

## 7. Core Permission Rule

> Visibility does not imply management.

رؤية البطولة لا تعني إدارتها.
رؤية الفريق لا تعني تعديل roster.
رؤية المباراة لا تعني إدخال نتيجة.

كل إجراء إداري يجب أن يتحقق في:

1. UI.
2. Controller/service.
3. Firestore rules أو backend.
4. Tests.

---

## 8. Tournament Lifecycle — V1

المراحل المقترحة:

```text
draft
setup_teams
setup_fixtures
scheduled
in_progress
completed
cancelled
archived
```

ملاحظة: هذه أسماء Product-friendly. يمكن mapping داخليًا إلى statuses موجودة في الكود.

### 8.1 Draft

المنظم أنشأ البطولة ولم يكمل الإعداد.

### 8.2 Setup Teams

المنظم يضيف أو يراجع الفرق.

V1 يجب أن يسمح بـ:

- guest/manual teams.
- registered teams.
- mixed teams.

### 8.3 Setup Fixtures

المنظم ينشئ/يولّد جدول المباريات.

### 8.4 Scheduled

كل مباراة لها ترتيب وموعد واضح، أو على الأقل fixtures منشورة بسياسة واضحة.

### 8.5 In Progress

بدأت البطولة وبعض المباريات لها نتائج.

### 8.6 Completed

كل النتائج معتمدة.

---

## 9. Scheduling — V1

V1 scheduling يجب أن يكون بسيطًا:

```text
Generated/manual pairings
+ organizer manually sets time/date/venue
```

الحقول الأساسية:

```text
roundNumber
matchNumber
scheduledAt
venueName?
courtName?
status
```

V1 لا يحتاج auto scheduler معقد.

لكن لا يجوز أن تكون المباريات بلا ترتيب واضح.

---

## 10. Match Result — V1

الاقتراح الأبسط:

```text
score submitted
→ organizer approved
→ official result
```

النتائج المعتمدة فقط يجب أن تكون مصدر standings الرسمية.

لو تم عرض top scorers قبل الاعتماد، يجب اعتبارها provisional أو تعديل resolver ليحسب official فقط.

---

## 11. Guest Claim — V1

V1 يدعم:

- guest players.
- claim link.
- token-aware public profile CTA.
- organizer/captain resend claim link.
- no broad claimCodes listing.

V1 لا يدعم بعد:

- server-mediated claim completion.
- إزالة كل raw claimCode legacy fields.
- merge كامل لإحصائيات guest بعد claim.

---

## 12. Screen Structure — V1

### 12.1 Public Tournament View

للمشاهدين واللاعبين:

- overview.
- teams.
- fixtures.
- standings.
- scorers.
- match results.

Read-only إلا لو المستخدم له دور واضح.

### 12.2 Organizer Dashboard

للمنظم فقط:

- setup progress.
- teams/participants.
- fixtures/schedule.
- results approval.
- share/growth.
- warnings/blockers.

### 12.3 Team Roster Surface

لقائد الفريق:

- players.
- guests.
- claim link resend.
- membership actions.

### 12.4 Player/Profile Surface

- stats.
- guest badge.
- claim CTA فقط مع token.

---

## 13. Current Known Risks

### P0

- account/session isolation.
- tournament ownership confusion.
- managed vs public tournament surfaces.
- missing tournament rules emulator tests.

### P1

- scheduling policy not fully enforced.
- official vs provisional stats unclear.
- assistant roles exist but V1 likely should avoid them.
- deep link continuation after login.

### P2

- friends.
- challenges.
- notifications.
- admin/support tools.

---

## 14. Open Product Decisions

1. هل V1 يسمح للمنظم بإضافة manual guest teams؟ القرار المقترح: نعم.
2. هل V1 يسمح بفريق كامل بدون أي registered player؟ القرار المقترح: نعم.
3. هل registration by captain يدخل V1 أم المنظم يضيف الفرق يدويًا؟ يحتاج قرار.
4. هل format V1 single elimination فقط؟ المقترح: نعم كبداية.
5. هل captain يرسل النتيجة أم المنظم فقط؟ يحتاج قرار.
6. هل scheduledAt إجباري قبل publish؟ المقترح: نعم، أو fixtures تبقى draft.
7. هل standings تحسب approved فقط؟ المقترح: نعم.
8. هل public discovery موجود في V1؟ نعم، read-only فقط.

---

## 15. Decision Log

### D001 — V1 هو Tournament Ego MVP

النسخة الأولى تركز على بطولة صغيرة حقيقية مع pride loop.

### D002 — Visibility لا تعني Management

أي بطولة مرئية ليست قابلة للإدارة إلا لمنظّمها.

### D003 — V1 يجب أن يدعم بطولات بدون مستخدمين مسجلين

المنظم يجب أن يستطيع إنشاء بطولة كاملة بفرق ولاعبين guests/manual.

### D004 — friends/challenges خارج V1

لا تدخل قبل استقرار الفرق والبطولات والصلاحيات.

### D005 — الجدولة جزء أساسي من البطولة

لا توجد بطولة حقيقية بلا ترتيب ومواعيد.

### D006 — organizer screen يجب أن تكون guided وواضحة

الإدارة ليست شاشة غامضة؛ يجب أن تكون flow منطقيًا.

---

## 16. Next Step

لا تنفيذ جديد قبل:

1. مراجعة هذه الوثيقة.
2. تثبيت القرارات المفتوحة.
3. عمل Gap Audit نهائي للكود مقابل هذا الـ Master Blueprint.

أي Codex prompt لاحق يجب أن يشير لهذه الوثيقة فقط كمصدر المنتج الأساسي.

