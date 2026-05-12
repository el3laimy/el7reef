# خطة إدارة المشروع — Project Roadmap & Sprint Plan

**النسخة:** 1.0  
**التاريخ:** 2026-05-02  
**النطاق:** الوصول إلى أول إصدار عملي على Google Play  
**الاتجاه المنتجى:** Tournament Ego MVP

---

## 1. القرار الإداري

يتم تغيير اتجاه المشروع من Friendly Match MVP إلى:

> **Tournament Ego MVP**

الدورات هي القلب ومحرك الانتشار. الماتشات هي وحدة البناء. الوديات والتحديات هي عنصر العودة بين الدورات. الفخر والـ Ego هما المحرك النفسي. المشاركة هي محرك النمو.

---

## 2. واقع المشروع الحالي

### 2.1 نقاط قوة

- أساس قوي نسبيًا للبطولات والفرق والضيوف والـ claim.
- خدمات مركزية كثيرة موجودة.
- Firestore rules موجودة وليست غائبة.
- Shareables موجودة كبداية.
- Tests كثيرة في core services/repositories.
- Fantasy gated حاليًا.

### 2.2 نقاط ضعف مانعة للإطلاق

- الرؤية القديمة داخل بعض docs موجهة للوديات.
- لا يوجد MatchEvent يدعم guest players كهدافين/MVP.
- الإحصائيات الحالية تميل للاعبين المسجلين فقط.
- share cards ناقصة لأنواع الفخر الأساسية.
- بعض routes/constants غير مكتملة.
- Android release يستخدم debug signing.
- UI البطولات أقرب لأدوات تشغيل داخلية وليس منتجًا emotional للاعبين.
- Play Store readiness غير مكتملة.

---

## 3. استراتيجية الإطلاق

### 3.1 هدف V1

إطلاق نسخة تسمح بدورة حقيقية صغيرة من 4 إلى 8 فرق، بها فرق ولاعبون ضيوف ومسجلون، نتائج، هدافون، MVP، كروت، وclaim.

### 3.2 Pilot قبل Play Store العام

يفضل تنفيذ Pilot على دورة واحدة أو دورتين حقيقيتين:

- 4 أو 6 فرق.
- 5v5 أو 7v7.
- منظم واحد.
- 40–80 لاعبًا، أغلبهم يمكن أن يبدأوا كضيوف.
- قياس: عدد الكروت، claims، النتائج، feedback.

### 3.3 مبدأ التنفيذ

لا نبني feature جديدة إلا إذا خدمت واحدًا من:

- تشغيل الدورة.
- فخر اللاعب.
- كارت قابل للمشاركة.
- claim/انتشار.
- ثقة النتيجة.
- نشاط بين الدورات.

---

## 4. Roadmap عالي المستوى

```text
Phase 0: Product & Code Baseline
Phase 1: Tournament Surface Cleanup
Phase 2: Guest-first Match Events Foundation
Phase 3: Tournament Score + Leaderboards
Phase 4: Ego Share Cards
Phase 5: Player/Team Ego Profiles
Phase 6: Challenges/Friendlies Retention Loop
Phase 7: Trust, QA, and Release Hardening
Phase 8: Closed Testing + Production Submission
```

---

## 5. Sprint Plan تفصيلي

> مدة sprint المقترحة: أسبوع واحد إذا المطور واحد/صغير، أو أسبوعين لو الفريق يحتاج QA يدوي موسع.

---

## Sprint 0 — تثبيت البوصلة وتنظيف الوثائق

### الهدف

تحويل كل المستندات والتوجيهات من Friendly-first إلى Tournament Ego MVP.

### المهام

- تحديث `AGENTS.md` ليعكس الاتجاه الجديد.
- تحديث `docs/implementation_plan.md` أو إنشاء `docs/v1_tournament_ego_plan.md`.
- مراجعة feature flags.
- تحديد surface المسموح في V1.
- إنشاء checklist جديد للدورة بدل Friendly QA فقط.

### المخرجات

- وثيقة Scope نهائية.
- قائمة features مؤجلة.
- قائمة routes المسموحة.

### Acceptance Criteria

- لا يوجد مستند رئيسي يصف الودية كقلب المنتج.
- الفريق يعرف V1 بوضوح.

---

## Sprint 1 — Route & Surface Audit

### الهدف

منع التشتت والأسطح الناقصة.

### المهام

- مراجعة routes غير المسجلة: register, editProfile, playerProfile, createTeam, createTournament, leaderboard, achievements, myQrCode, activityFeed.
- قرار لكل route: register / hide / defer / implement minimal.
- إزالة fantasy toggle من CreateTournament.
- إخفاء أي social/fantasy surfaces غير ضرورية من V1.
- مراجعة Bottom Navigation labels.

### الملفات المحتملة

- `lib/app/routes/app_routes.dart`
- `lib/app/routes/app_pages.dart`
- `lib/features/home/views/home_screen.dart`
- `lib/features/tournament/views/tournament_list_screen.dart`
- `lib/core/constants/feature_flags.dart`

### Acceptance Criteria

- لا route أساسي يؤدي إلى شاشة ناقصة.
- لا fantasy exposure في دورة V1.
- navigation يعكس: Home / Tournaments / Matches / Teams / Me.

---

## Sprint 2 — Tournament UX V1

### الهدف

تحويل شاشة الدورات من قائمة إدارية إلى قلب المنتج.

### المهام

- تحسين Create Tournament sheet.
- إضافة copy يشرح دعم الفرق واللاعبين غير المسجلين.
- تحسين Tournament Card بإظهار story: عدد الفرق، الجولة، آخر نتيجة/المتصدر عند توفر البيانات.
- تحسين Tournament Detail بtabs واضحة: Overview, Teams, Fixtures, Standings, Scorers, Cards.
- فصل Organizer Ops عن view العام.

### Acceptance Criteria

- منظم جديد يستطيع إنشاء دورة وفهم الخطوات التالية.
- لاعب يفتح صفحة دورة ويفهم: الفرق، الجدول، الترتيب، الهدافين.

---

## Sprint 3 — MatchEvent Foundation

### الهدف

بناء مصدر الحقيقة للأهداف وMVP ودعم guest players.

### المهام

- إنشاء domain entity `MatchEvent`.
- إنشاء model/repository/service.
- دعم actor type: registered player, guest player, matchSidePlayer.
- إضافة Firestore collection `matchEvents`.
- إضافة rules.
- إضافة tests.
- إضافة migration compatibility من `player_stats` إن لزم.

### الملفات المحتملة

- `lib/domain/entities/match_event.dart`
- `lib/data/models/match_event_model.dart`
- `lib/domain/repositories/match_event_repository.dart`
- `lib/data/repositories/match_event_repository_impl.dart`
- `lib/core/services/match_event_service.dart`
- `firestore.rules`
- `test/core/services/match_event_service_test.dart`

### Acceptance Criteria

- يمكن تسجيل goal/MVP للاعب مسجل أو ضيف في test.
- لا يمكن تسجيل event للاعب خارج المباراة.
- void بدل delete.

---

## Sprint 4 — Score Submit v2

### الهدف

جعل تسجيل النتيجة ينتج بيانات فخر حقيقية.

### المهام

- تعديل `ScoreSubmitController` لتحميل كل لاعبي الطرفين: registered + guest/matchSidePlayers.
- بناء unified participant picker.
- إدخال score ثم goal scorers.
- اختيار MVP من كل المشاركين.
- validation: أهداف الفريق مقابل score.
- ربط MatchSettlementService بـ MatchEventService.
- success sheet تعرض share CTAs.

### الملفات المحتملة

- `lib/features/match/controllers/score_submit_controller.dart`
- `lib/features/match/views/score_submit_screen.dart`
- `lib/core/services/match_settlement_service.dart`
- `lib/core/services/official_match_roster_service.dart`
- `lib/features/match/models/...`

### Acceptance Criteria

- لاعب ضيف يستطيع أن يظهر كهداف.
- لاعب ضيف يستطيع أن يكون MVP.
- النتيجة تحفظ وتولد events.
- لا تظهر رسالة “اللاعبون المؤقتون لا تُسجل لهم إحصائيات”.

---

## Sprint 5 — Tournament Leaderboards

### الهدف

إنتاج ترتيب وهدافين حقيقيين للدورة.

### المهام

- بناء TournamentStatsService.
- حساب top scorers من matchEvents.
- عرض Scorers tab في Tournament Detail.
- تحديث standings بعد approve score.
- بناء empty states.

### Acceptance Criteria

- بعد تسجيل نتيجة بها أهداف، يظهر الهدافون في صفحة الدورة.
- guest scorer يظهر باسمه وحالة claim.
- يمكن مشاركة كارت هدافين.

---

## Sprint 6 — Ego Share Cards Pack 1

### الهدف

تحويل البيانات إلى انتشار.

### المهام

- تصميم/تنفيذ MVP Card.
- تصميم/تنفيذ Player Card.
- تصميم/تنفيذ Top Scorers Card.
- تحسين Result Card ليظهر اسم الدورة وMVP.
- إضافة CTAs بعد score submit.
- تتبع share events analytics.

### الملفات المحتملة

- `lib/features/shareables/widgets/*`
- `lib/features/shareables/controllers/*`
- `lib/features/shareables/models/*`
- `lib/features/shareables/services/share_card_capture_service.dart`

### Acceptance Criteria

- كل كارت يعمل capture/share.
- الكارت واضح عربيًا ولا يحدث overflow في أسماء طويلة.
- يمكن مشاركته بعد نتيجة المباراة مباشرة.

---

## Sprint 7 — Player Claim & Ego Profile

### الهدف

جعل اللاعب يجد نفسه ويستلم بروفايله.

### المهام

- تحسين GuestPlayerClaim screen copy/UX.
- بعد claim، توجيه المستخدم إلى Player Profile.
- عرض إحصائيات اللاعب من guest history.
- إضافة Player Card CTA.
- إضافة حالة “غير مؤكد” لبروفايل guest.

### الملفات المحتملة

- `lib/features/guest_claim/*`
- `lib/features/profile/*`
- `lib/core/services/guest_claim_service.dart`
- `lib/core/services/share_link_service.dart`

### Acceptance Criteria

- لاعب ضيف يستطيع claim من رابط.
- بعد claim يرى أهدافه السابقة.
- يستطيع مشاركة كارت اللاعب.

---

## Sprint 8 — Team Ego & Challenges

### الهدف

تقوية القبيلة والعودة بين الدورات.

### المهام

- تحسين Team Profile/Team Roster كصفحة هوية.
- Team Card.
- Team lineup share CTA.
- تحدي فريق لفريق.
- ربط challenge match بنفس score/event/share loop.

### Acceptance Criteria

- فريق يشارك كارت فريق.
- فريق ينشئ تحديًا.
- نتيجة التحدي تنتج كارت وتظهر في سجل الفريق.

---

## Sprint 9 — Trust, Audit, Disputes UX

### الهدف

حماية الفخر من الخناقات.

### المهام

- ربط audit events بتعديل النتيجة/events.
- إضافة “طلب تصحيح” للاعب على goal/MVP.
- Dispute flow بسيط للمنظم.
- عرض حالة النتيجة بوضوح.

### Acceptance Criteria

- يمكن فتح dispute على نتيجة/إحصائية.
- المنظم يرى dispute ويقرر.
- audit يظهر من فعل ماذا ومتى.

---

## Sprint 10 — Release Hardening

### الهدف

تجهيز Play Store.

### المهام

- `flutter pub get`.
- `dart analyze lib/`.
- `flutter test`.
- مراجعة failing tests إن وجدت.
- إنشاء release keystore.
- تعديل `android/app/build.gradle.kts` release signing.
- ضبط versionCode/versionName.
- ضبط app label إلى “الحريف” أو “El7reef”.
- مراجعة permissions.
- تحديث target SDK حسب متطلبات Google Play.
- إعداد Privacy Policy وData Safety.
- إعداد screenshots وfeature graphic.

### Acceptance Criteria

- app-release.aab موقّع release.
- لا debug signing.
- لا permissions غير مبررة.
- build يثبت على جهاز اختبار.

---

## Sprint 11 — Closed Testing & Pilot

### الهدف

اختبار واقعي قبل production.

### المهام

- إنشاء closed testing track.
- دعوة 12 tester على الأقل إذا الحساب الشخصي جديد.
- تشغيل Pilot بدورة حقيقية صغيرة.
- جمع feedback عبر checklist.
- إصلاح blockers.
- تقديم production access عند تحقق الشروط.

### Acceptance Criteria

- 12 tester opted-in لمدة 14 يومًا متصلة إذا كان الحساب يتطلب ذلك.
- تسجيل 3–5 مباريات حقيقية على الأقل.
- مشاركة 10+ كروت.
- claim ناجح للاعبين ضيوف.

---

## 6. QA Plan

### 6.1 سيناريوهات إجبارية

1. دورة 4 فرق، فرق ضيوف فقط.
2. دورة مختلطة: فريق مسجل + فريق ضيف.
3. لاعب ضيف يسجل هدفًا ثم يعمل claim.
4. MVP لاعب ضيف ثم claim.
5. ترتيب هدافين بعد 3 مباريات.
6. مشاركة كارت نتيجة ومVP وهدافين.
7. اعتراض على هدف ثم حل الاعتراض.
8. تحدي بين فريقين خارج الدورة.
9. ودي بلا دورة مع لاعبين ضيوف.

### 6.2 اختبارات تقنية

- Repositories serialization/deserialization.
- Services validations.
- Firestore rules emulator.
- Widget tests للكروت المهمة.
- Manual QA على Android device.

---

## 7. Release Gates

### Product Gate

- الدورة تعمل من البداية حتى أول leaderboard.
- اللاعب الضيف ليس ناقصًا في الفخر.
- الكروت مغرية وواضحة.
- لا fake features في المسار الأساسي.

### Engineering Gate

- Analyze clean.
- Core tests pass.
- Firestore rules tested.
- Release signing done.
- No critical crash في pilot.

### Store Gate

- Target SDK compliant.
- Privacy Policy جاهزة.
- Data Safety صحيح.
- Closed testing completed إذا مطلوب.
- Screenshots من flow الحقيقي.

---

## 8. المخاطر وخطة التخفيف

| الخطر | الاحتمال | التأثير | التخفيف |
|---|---:|---:|---|
| MatchEvent refactor يأخذ وقتًا | متوسط | عالي | تنفيذه مبكرًا كسبرنت مستقل. |
| UX البطولات معقد للمنظم | متوسط | عالي | wizard + checklists + defaults. |
| كروت غير جذابة | متوسط | عالي | اختبارها بصريًا مع لاعبين حقيقيين. |
| Claim abuse | متوسط | متوسط | expiry + approval + audit. |
| Google Play readiness يتأخر | متوسط | عالي | Sprint منفصل للrelease. |
| Firebase تكلفة الصور | منخفض/متوسط | متوسط | ضغط الصور وتأجيل media-heavy. |

---

## 9. ترتيب الأولويات الدائم

1. دورة تعمل.
2. لاعب يظهر ويفتخر.
3. ضيف يستطيع claim.
4. نتيجة تولد أحداث وإحصائيات.
5. كارت ينتشر.
6. ثقة واعتماد.
7. تحديات/وديات للعودة.
8. أي شيء آخر.

---

## 10. أول 10 مهام تنفيذية مباشرة

1. تحديث docs وAGENTS إلى Tournament Ego MVP.
2. إزالة fantasy toggle من CreateTournament.
3. حسم routes غير المسجلة/غير المستخدمة.
4. تصميم MatchEvent model/service/repository/rules.
5. تعديل ScoreSubmit ليعرض guest + registered participants.
6. بناء TopScorers service/snapshot.
7. بناء MVP Card.
8. بناء Player Card.
9. تحسين Guest Claim بعد الكارت.
10. إصلاح Android release signing.

---

## 11. الخلاصة

الطريق إلى Play Store ليس إضافة features كثيرة. الطريق هو إثبات حلقة واحدة قوية:

> دورة → ماتش → أحداث → ترتيب/هدافين → كارت → مشاركة → Claim → عودة.

لو الحلقة دي اشتغلت في دورة شعبية حقيقية، الحريف لديه منتج قابل للنمو. لو لم تعمل، أي إضافة أخرى ستكون تزيينًا فوق أساس غير مكتمل.
