<div dir="rtl">

# خطة تقوية تجربة المستخدم وتصميم Liquid Glass لتطبيق الحريف

> **حالة الوثيقة:** سجل تنفيذ وقرارات UX/Firebase، وليست backlog نشطة. المتبقي المقبول منها نُقل إلى `docs/core/08_Unified_V1_Completion_And_Workspace_Plan.md`&rlm;، وأُلغي التوسع البصري العام قبل إغلاق حلقة النمو. أي عدّاد اختبارات أو حالة نشر مؤرخة داخلها هو دليل تاريخي فقط؛ الحالة الحية وسجل القبول في الوثيقتين `08` و`10`.

**النسخة:** 1.47  
**آخر مراجعة من واقع الكود:** 2026-07-09  
**النطاق:** Firebase/Auth، الإقلاع، أول استخدام، الصفحة الرئيسية، البطولات، وحالة نظام Liquid Glass  
**الاتجاه المنتجى:** Tournament Ego MVP

---

## 1. خلاصة اللقطة التاريخية

الخطة لم تعد تبدأ من نفس نقطة 2026-07-01. من واقع الكود الحالي تم تنفيذ جزء مهم من مشاكل الثقة:

1. تم تثبيت Android على مشروع Firebase الجديد `el7reef-app`&rlm;.
2. تسجيل الدخول بـ Google نجح بعد ضبط `google-services.json` وتوقيع debug.
3. تم منع الخروج القسري عند فشل تجهيز البروفايل، وأضيفت شاشة إصلاح بروفايل واختبارات تمنع رجوع السلوك القديم وتميز permission/network/timeout.
4. تم فصل خطأ `followers` في تحميل البطولات المتابعة عن باقي بطولات المستخدم، وتأكيد قواعد Firestore محلياً عبر emulator.
5. تم إنشاء `El7reefGlassSurface` بدرجات تصميم واضحة، وإزالة استخدام `GlassmorphicContainer` من الكود الحي داخل `lib/`&rlm;.
6. تم تثبيت مسار تسجيل/اعتماد النتائج الحساس عبر Cloud Functions باختبار Flutter مخصص، مع منع fallback المحلي افتراضياً حتى لا تتعارض القواعد المشددة مع الـ core flow.
7. تم فصل قراءة “بطولاتي كمنظم” عن list المباشر على `tournaments` عبر `tournamentMemberships`، لأن دمج private owner list مع public discover list في نفس rule يسبب رفضاً أو مخاطرة تسريب بطولات خاصة.
8. تم تنفيذ preflight للنشر: قواعد Firestore وفهارسها تجمع بنجاح في `--dry-run`، لكن نشر Cloud Functions متوقف حتى ترقية مشروع `el7reef-app` إلى Blaze لأن `cloudbuild.googleapis.com` لا يمكن تفعيله على الخطة الحالية.

المتبقي الحقيقي الآن ليس “إصلاح تسجيل دخول Google” ككود، بل:

1. إنشاء iOS app رسمي داخل `el7reef-app` عند إدخال iOS في QA أو release.
2. تجهيز توقيع release وإضافة SHA-1/SHA-256 الخاصين به في Firebase قبل Play Store.
3. إبقاء iOS خارج QA الحالي حتى يتم تنزيل `GoogleService-Info.plist` من المشروع الجديد وإعادة توليد FlutterFire.
4. استكمال تعميم section-level error states على أي أقسام core جديدة تظهر لاحقاً.
5. استكمال QA فعلي لرحلة أول استخدام والـ claim deep link على جهاز حقيقي بعد أن أصبحت رحلة رابط claim ثم Google sign-in أو profile repair ثم الرجوع لنفس شاشة claim مغطاة محلياً للاعب الضيف والفريق الضيف باختبارات widget.
6. ترحيل أي بطولات إنتاجية قديمة إلى `tournamentMemberships` وإضافة `visibility/discoverable` صريحين قبل الاعتماد الكامل على شاشة “بطولاتي” في بيانات قديمة.
7. استكمال استخدام variants المتخصصة من Liquid Glass على pride cards المتبقية مع QA أداء/قراءة على جهاز حقيقي، ومراقبة أي bottom sheets جديدة حتى تلتزم بسطح `sheet`&rlm;.

---

## 2. حالة التنفيذ من واقع الكود

| البند | الحالة | الدليل من الكود | المتبقي |
| :--- | :--- | :--- | :--- |
| توحيد Firebase Android | تم | `android/app/google-services.json` و`lib/firebase_options.dart` Android و`.firebaserc` يشيرون إلى `el7reef-app`&rlm;. | iOS خارج نطاق QA الحالي حتى يتم إنشاء app رسمي داخل `el7reef-app`&rlm;. |
| توقيع debug المعتمد | تم | `android/app/build.gradle.kts` يستخدم `android/app/debug-el7reef-v2.keystore` في debug. | حفظ هذا keystore وعدم تغييره، وإضافة أي SHA جديد عند تغيير التوقيع. |
| توقيع release | جزئي | `android/app/build.gradle.kts` يقرأ `key.properties` إن وجد، ولا يسمح لـ release artifact المطلوب أن يرجع إلى debug signing عند غياب الملف، ويتحقق من وجود `storeFile` ومنع استخدام `debug-el7reef-v2.keystore` كتوقيع release. يوجد template غير سري في `android/key.properties.example`&rlm;. | إنشاء release keystore فعلي، وتجهيز `android/key.properties` محلياً، وإضافة SHA-1/SHA-256 الخاصين بالـ release في Firebase. |
| Google Sign-In error mapping | تم | `AuthErrorMapper` يترجم `ApiException: 10` والشبكة وإلغاء الدخول، و`auth_controller_test.dart` يثبت أن الإلغاء لا يعرض خطأ ولا يضيع النية المؤجلة. | مراقبة اللوج فقط لو ظهر نمط خطأ جديد من Google SDK. |
| منع logout القسري عند فشل profile | تم | `AuthService._loadPlayerProfileUnchecked` يضبط `AuthProfileStatus.repairRequired` ولا يستدعي `signOut()` عند فشل Firestore، و`auth_service_test.dart` يثبت أن الجلسة تظل قائمة بدون استدعاء Firebase/Google sign-out. | مراقبة اللوج فقط لو ظهر نمط فشل profile جديد. |
| شاشة إصلاح البروفايل | تم | `lib/features/auth/views/profile_repair_screen.dart` ومسار `AppRoutes.profileRepair` موجودان، و`AuthErrorMapper.mapProfileLoadError` يميز permission/network/timeout. | تحسين الصياغة UX لاحقاً حسب نتائج QA، بدون تغيير المسار الحالي. |
| Splash route decision | تم جزئياً | `SplashScreen` يقرأ `AuthProfileStatus` ويوجه إلى home/login/repair، و`splash_screen_test.dart` يثبت أن `repairRequired` يفتح شاشة إصلاح الحساب. | لا يوجد بعد `BootstrapStatusView` مستقل. |
| Firebase Config Guard | تم | `FirebaseConfigGuard` يفشل في debug عند تضارب مشروع Android، و`DefaultFirebaseOptions.ios` يرفض التشغيل حالياً برسالة Android-only بدلاً من استخدام مشروع `el7reef-app-2026`، و`firebase.json` لم يعد يحتوي iOS FlutterFire config قديم. | عند إدخال iOS: إنشاء iOS app داخل `el7reef-app` وتنزيل `GoogleService-Info.plist` وإعادة توليد `firebase_options.dart`. |
| فشل `followers` لا يكسر بطولاتي | تم | `TournamentController.loadMyTournaments` يفصل `followedTournamentsErrorMessage` عن `myTournamentsErrorMessage`، و`session_reset_coordinator_test.dart` يثبت أن فشل المتابعات لا يخفي بطولات المنظم أو المشارك. | مراقبة اللوج بعد النشر، وتكرار نفس النمط لأي query مستقلة جديدة. |
| Firestore rules لـ `collectionGroup('followers')` | تم ومؤكد محلياً | `firestore.rules` يحتوي match عام لـ `/{path=**}/followers/{followerUserId}` وتست `tournament_permissions.rules.test.js` يغطي query بـ `userId == uid`، وتم تشغيل `npm run test:rules:emulator` بتاريخ 2026-07-08 ونجح بـ `167 passing` على Firestore Emulator `STANDARD/CLOUD_FIRESTORE`&rlm;. | نشر القواعد إن لم تكن منشورة بعد، ثم مراقبة اللوج على جهاز حقيقي للتأكد من اختفاء `PERMISSION_DENIED`&rlm;. |
| Firestore rules لـ “بطولاتي كمنظم” | تم محلياً ويحتاج نشر/ترحيل | `TournamentRepositoryImpl.getOrganizerTournaments` يقرأ `tournamentMemberships` الخاصة بالمستخدم ثم يعمل `get` للبطولات، و`createTournament` يكتب عضوية المنظم في نفس batch. `firestore.rules` يمنع list المباشر على `tournaments` إلا للبطولات العامة `visibility=public/discoverable=true`، ويغطي `tournament_permissions.rules.test.js` عضويات المنظم وعدم قراءة عضوية مستخدم آخر. | نشر rules/indexes بعد قرار النشر، وترحيل البطولات القديمة بإضافة عضوية `organizer` لكل بطولة موجودة حتى تظهر في “بطولاتي”. |
| Next Action في Home | تم | `_NextActionHero` موجود في `lib/features/home/views/home_screen.dart` ويوجه حسب حالة اللاعب والبطولات. | ربطه أكثر بلحظات المباراة القادمة وبطاقات الفخر الفعلية. |
| Section error card | تم في الشاشات الأساسية الحالية | `SectionStateCard` موجود كمكون عام في `lib/core/widgets/section_state_card.dart` ويستخدم `El7reefGlassSurface.error` في أخطاء قائمة البطولات، تفاصيل البطولة، أقسام المباريات داخل Home، شاشة فرقي، وشاشة عمليات البطولة `TournamentOperationsDashboardScreen`&rlm;. | تطبيقه في أي أقسام core جديدة تفشل وحدها. |
| Empty states للفرق والبطولات والمباريات | تم في الشاشات الأساسية الحالية | `MyTeamsScreen` يعرض CTA واضح “إنشاء فريق الآن”، و`TournamentListScreen` يعرض “ابدأ دورة شعبية”، و`MatchDiscoverScreen` يعرض “أنشئ مباراة مفتوحة”، و`MatchdayScreen` يعرض `MatchdayEmptyRosterCard` عندما يكون الطرف بلا لاعبين مع CTA حقيقي إلى قائمة الفريق. `ScoreSubmitScreen` يعرض CTA مباشر عند غياب لاعبي طرف المباراة: الفريق الرسمي يفتح قائمة الفريق، والطرف بدون فريق رسمي يفتح لوبي المباراة. يغطي ذلك `my_teams_screen_test.dart` و`tournament_list_screen_test.dart` و`match_discover_screen_test.dart` و`matchday_screen_test.dart` و`score_submit_controller_test.dart`&rlm;. | تطبيق نفس النمط على أي شاشة core جديدة يظهر فيها فراغ قابل للتصرف. |
| Liquid Glass surface | تم في الكود الحي ويجري تحسين variants | `lib/core/widgets/el7reef_glass_surface.dart` يحتوي variants: base/raised/pride/error/sheet ويدعم `borderRadius` مخصص، و`MatchdayEmptyRosterCard` يستخدم `El7reefGlassSurface.raised`، و`MatchdayNoManagedSideCard` و`MatchdaySideSelector` و`MatchdayAttendanceSection` و`MatchdayLineupSection` و`MatchdaySubstitutionSection` و`ReadinessStepper` و`CollapsibleTeamSection` وكارت الدعوة داخل `MatchLobbyScreen` وحالات الفراغ في Home و`HomeMyMatchCard` و`MatchCard` و`ChallengeCard` و`FanVotingScreen` ومكونات `TeamRosterHeader` و`TeamRosterActions` و`TeamRosterFormationWorkspace` و`TeamRosterSection` و`TeamInviteEntryScreen` و`SearchPlayersScreen` و`FriendsScreen` و`UsernameScreen` و`ActivityFeedWidget` و`TournamentAssistantsScreen` و`ProfileScreen` و`PublicPlayerProfileScreen` تستخدم `El7reefGlassSurface.base`، وواجهات إنشاء مباراة/بطولة وإضافة مساعد بطولة وواجهات قائمة الفريق لإضافة لاعب/ضيف وحفظ قالب/نسخة جاهزة واختيار مصدر الصورة الشخصية تستخدم `El7reefGlassSurface.sheet`، وpreviews لكروت `MatchResultShareCard` و`MvpShareCard` و`TopScorersShareCard` و`LineupShareCard` تستخدم `El7reefGlassSurface.pride` مع إبقاء export mode بدون live blur، وتم حذف `lib/core/widgets/glassmorphic_container.dart` بعد اختفاء مراجع `GlassmorphicContainer` من `lib/`&rlm;. | تطبيق `pride` على كروت الفخر المتبقية عند تثبيت واجهات Champion/Player/Team، ومراقبة أي bottom sheets جديدة حتى تستخدم `sheet`. |
| Reduced visual effects | تم | `El7reefGlassSurface` يلغي blur عند `disableAnimations` أو `accessibleNavigation` أو تفعيل `FeatureFlags.reduceGlassBlurEnabled`، والمفتاح `reduce_glass_blur_enabled` موجود في Remote Config defaults بقيمة `false`، وتوجد اختبارات للمسارات الثلاثة. | تفعيل المفتاح عند الحاجة من Remote Config بعد QA أداء على جهاز ضعيف. |
| Onboarding إلى نية المستخدم | تم جزئياً | `OnboardingScreen` يعرض اختيارات: “أنظم بطولة”، “أنا كابتن فريق”، “أنا لاعب”، و“معايا رابط أو QR”، مع حفظ مسارات البطولة/الفريق/الاستكشاف في `PendingDeepLinkService` قبل login، وتوجد اختبارات للنيات الثلاث الأساسية. | تشغيل QA حقيقي لاختيار QR/Claim عند توفر جهاز ورابط فعلي، بدون فتح كاميرا فعلية داخل widget tests. |
| Deep link preservation للـ claim | تم محلياً | يوجد `PendingDeepLinkService` ويستخدم في `AuthController` و`ProfileRepairScreen` بعد login/profile ready. توجد اختبارات `pending_deep_link_service_test.dart` و`guest_claim_screen_test.dart` و`profile_repair_screen_test.dart` للحفظ والرجوع إلى مسار guest claim، ومنها سيناريو رابط claim ثم شاشة login ثم Google sign-in ناجح ثم الرجوع لنفس شاشة claim لكل من اللاعب الضيف والفريق الضيف، وسيناريو profile repair الجاهز الذي يستأنف claim اللاعب والفريق. | تشغيل QA على رابط/QR حقيقي من جهاز للتأكد من نفس المسار خارج الاختبارات. |
| Tournament detail story/quick actions | جزئي | توجد أقسام detail وtop scorers/error states، لكن الخطة البصرية الكاملة لم تكتمل. | إضافة story strip وquick actions حول النتيجة، الهداف، MVP، والمشاركة. |
| Pride cards visibility | جزئي | توجد shareables وخدمات pending pride events في نطاق المباراة. | جعل أزرار المشاركة ظاهرة بعد result/MVP/champion وليس داخل مسارات بعيدة. |
| مسار النتائج عبر Cloud Functions | تم محلياً وجاهز للنشر بعد Blaze | `MatchSettlementService` يستدعي `CloudSensitiveOpsService.submitMatchSettlement` و`approveMatchScore` قبل أي كتابة محلية، والـ fallback المحلي مقفول افتراضياً. `match_settlement_service_remote_test.dart` يثبت أن submit/approve يستخدمان callable payload ولا يكتبان محلياً، وأن فشل callable بدون fallback يعطي رسالة واضحة. تم توليد `functions/package-lock.json` لتثبيت dependencies. | ترقية `el7reef-app` إلى Blaze، ثم نشر Functions وFirestore rules معاً على نفس المشروع قبل اختبار runtime؛ عدم نشر rules المشددة وحدها إذا كانت Functions غير منشورة. |

---

## 3. ما تم إغلاقه من الخطة القديمة

### 3.1 Firebase/Auth Android

تم تغيير القرار القديم. المشروع المعتمد حالياً للأندرويد هو `el7reef-app` وليس `el7reef-app-2026`&rlm;.

الأدلة:

- `android/app/google-services.json` يحتوي `project_id: el7reef-app`&rlm;.
- `lib/firebase_options.dart` في Android يحتوي `projectId: el7reef-app`&rlm;.
- `.firebaserc` يحتوي default project باسم `el7reef-app`&rlm;.
- `firebase.json` في Android/Dart Android يشير إلى `el7reef-app`&rlm;.
- `android/app/build.gradle.kts` يستخدم debug keystore ثابت باسم `debug-el7reef-v2.keystore`&rlm;.

قرار الخطة المعدل:

- Android V1 الآن على `el7reef-app`&rlm;.
- iOS مؤجل رسمياً خارج QA الحالي، ولا يجب تشغيله على `el7reef-app-2026`&rlm;.
- لا نرجع إلى `el7reef-app-2026` في Android إلا بقرار صريح جديد.

### 3.2 Profile Repair بدل logout

تم تنفيذ فصل Auth عن Profile.

السلوك الحالي:

1. إذا نجح Firebase Auth وفشل تجهيز `Player`&rlm;، الحالة تصبح `AuthProfileStatus.repairRequired`&rlm;.
2. المستخدم ينتقل إلى `/profile/repair` بدلاً من الرجوع إلى login.
3. شاشة الإصلاح تعرض retry وتسمح بخروج صريح فقط.

المتبقي:

- تحسين الصياغة UX لاحقاً حسب نتائج QA، بدون تغيير مسار repair الحالي.

### 3.3 Followers permission

تمت تغطية القاعدة المحلية والاستعلام:

```text
collectionGroup('followers')
  .where('userId', isEqualTo: currentUserId)
```

التست الحالي يؤكد أن المستخدم يقرأ followers الخاصة به ويفشل في قراءة followers الخاصة بمستخدم آخر.

تم تشغيل `npm run test:rules:emulator` بتاريخ 2026-07-08 على مشروع `el7reef-app` محلياً، وكانت النتيجة `167 passing` مع خروج ناجح `code 0`&rlm;.

المتبقي:

- نشر القواعد على `el7reef-app` إذا لم تكن آخر نسخة منشورة.
- التأكد من اختفاء الخطأ من لوج جهاز حقيقي بعد آخر نشر للقواعد.
- لو ظهر الخطأ مرة أخرى، تتم مراجعة index/query/rules المنشورة على نفس مشروع `el7reef-app`&rlm;.

---

## 4. المتبقي حسب الأولوية

### P0 - قبل أي QA نهائي على جهاز حقيقي

1. **إنهاء تضارب iOS Firebase**
   - تم إعلان V1 QA الحالي Android-only في الكود بمنع `DefaultFirebaseOptions.ios` من إرجاع إعدادات المشروع القديم.
   - تم إخراج iOS القديم من FlutterFire config داخل `firebase.json` حتى لا يعاد توليده بالخطأ.
   - عند إدخال iOS: إنشاء iOS app داخل `el7reef-app` وتنزيل `GoogleService-Info.plist` جديد.
   - بعد ذلك يتم تحديث `lib/firebase_options.dart` و`firebase.json` بالقيم الرسمية الجديدة.

2. **تجهيز release signing**
   - إنشاء release keystore.
   - تجهيز `android/key.properties` محلياً دون إدخاله إلى git.
   - التحقق من أن release build يفشل بوضوح إذا لم يكن `key.properties` موجوداً، أو إذا كان `storeFile` غير موجود، أو إذا حاول استخدام debug keystore.
   - استخراج SHA-1 وSHA-256 للـ release key وإضافتهما في Firebase Android app.

3. **Firebase Config Guard في debug**
   - إبقاء Android guard فعالاً ضد project mismatch.
   - إبقاء iOS blocked حتى تتوفر config رسمية للمشروع الجديد.
   - إبقاء تفاصيل الخطأ في debug فقط، وعدم عرضها للمستخدم النهائي.

4. **تأكيد followers runtime**
   - تم تأكيد القواعد محلياً عبر `npm run test:rules:emulator` بتاريخ 2026-07-08 بنتيجة `167 passing`&rlm;.
   - نشر القواعد إن لم تكن منشورة بعد، ثم تشغيل التطبيق على نفس مشروع `el7reef-app`&rlm;.
   - فتح البطولات والمتابعات.
   - التأكد أن `PERMISSION_DENIED` الخاص بـ `collectionGroup=followers` اختفى.

5. **تأكيد “بطولاتي” runtime**
   - تم تحويل بطولات المنظم إلى قراءة آمنة عبر `tournamentMemberships` بدلاً من list مباشر على `tournaments`&rlm;.
   - يجب نشر `firestore.rules` و`firestore.indexes.json` بعد اعتماد توقيت النشر.
   - يجب ترحيل البطولات القديمة بإنشاء عضوية `organizer` لكل بطولة موجودة؛ البطولات الجديدة ستكتب العضوية تلقائياً عند الإنشاء.
   - لا يتم فتح `allow list` واسع على `tournaments` كحل سريع لأنه قد يعرض بطولات خاصة خارج نطاق مالكها.

### P1 - تقوية تجربة الفشل والفارغ

1. تعميم `SectionStateCard` على أي أقسام core جديدة تفشل وحدها.
2. الاستمرار في فصل رسائل الخطأ حسب القسم قبل عرضها في Home أو التبويبات التابعة له.
3. إضافة empty states تقود إلى core loop:
   - “ابدأ دورة شعبية”.
   - “ضيف فريق حتى لو ضيف”.
   - “سجل أول نتيجة لتظهر كروت الفخر”.
4. مراقبة أي نمط جديد لفشل تجهيز البروفايل من لوج QA وإضافته إلى `AuthErrorMapper` عند الحاجة.

### P1 - أول استخدام وClaim

1. اختصار onboarding إلى رسالة V1 مباشرة عن البطولة والفريق والنتيجة والكارت.
2. بعد أول دخول، عرض intent حقيقي:
   - “أنظم بطولة”.
   - “أنا كابتن فريق”.
   - “أنا لاعب”.
   - “معايا رابط Claim”.
3. ربط كل اختيار بمسار موجود فعلاً، بدون أزرار وهمية.
4. تشغيل QR/Claim فعلي على جهاز بعد login/profile repair للتأكد من أن نفس المسار المحلي يعمل مع روابط حقيقية.

### P2 - Liquid Glass Design System

1. لا توجد مراجع حية متبقية لـ `GlassmorphicContainer` داخل `lib/`&rlm;.
2. تطبيق `El7reefGlassSurface.pride` على لحظات MVP/Champion/Top Scorers.
3. تم تطبيق `El7reefGlassSurface.sheet` على bottom sheets الحالية داخل `lib/`، ويجب إلزام أي bottom sheet جديد بنفس النمط.
4. تم إضافة policy لتقليل blur عبر `reduce_glass_blur_enabled` بجانب إعدادات accessibility.
5. ضبط الحركة في splash وhome لتقليل jank على أول frame.
6. إضافة مراجعة screenshots على جهاز حقيقي أو Playwright/Golden مناسب للشاشات الأساسية.

### P2 - Home/Tournament كـ Core Loop

1. ربط `NextActionHero` بالمباراة القادمة وآخر نتيجة، وليس حالة البطولات فقط.
2. إضافة story strip في Tournament detail:
   - الجولة الحالية.
   - آخر نتيجة.
   - المتصدر.
   - الهداف.
   - MVP الأخير.
3. جعل مشاركة result/MVP/champion مرئية فور لحظة الفخر.

---

## 5. خطة التنفيذ المعدلة

### المرحلة A: إغلاق ثقة Firebase النهائية

**الهدف:** منع عودة مشاكل المشروع/التوقيع.

الحالة الحالية:

- Android debug أصبح مثبتاً على `el7reef-app` ويستخدم keystore ثابت.
- `FirebaseConfigGuard` موجود ويكشف التضارب في debug.
- release artifact لم يعد يرجع إلى debug signing عند غياب `key.properties`، وأصبح يمنع `storeFile` غير الموجود أو استخدام debug keystore كتوقيع release.
- rules الخاصة بـ `followers` موجودة ومغطاة بتست محلي، وتم تأكيدها عبر Firestore Emulator بتاريخ 2026-07-08 بنتيجة `167 passing`&rlm;.
- مسار النتائج الحساس أصبح مغطى من جهة Flutter/Functions: `MatchSettlementService` يستخدم callable Functions، و`npm run test:functions` يؤكد منطق الاعتماد وguest MVP/goal payloads، و`match_settlement_service_remote_test.dart` يثبت عدم الكتابة المحلية عند نجاح callable.
- `functions/package-lock.json` موجود لتثبيت Dependencies الخاصة بالـ Functions قبل النشر.
- `npx firebase-tools deploy --only firestore:rules,firestore:indexes --project el7reef-app --dry-run` نجح بعد إضافة `tournamentMemberships` وفهارس شاشة “بطولاتي”.

المتبقي:

1. عند دخول iOS في النطاق: إنشاء app رسمي داخل `el7reef-app` وتحديث FlutterFire.
2. إنشاء release signing وإضافة SHA-1/SHA-256 في Firebase.
3. ترقية مشروع `el7reef-app` إلى Blaze حتى يمكن تفعيل `cloudbuild.googleapis.com` ونشر Cloud Functions.
4. نشر Firestore rules/indexes وCloud Functions الخاصة بـ `submitMatchSettlement` و`approveMatchScore` بتوقيت واحد، أو نشر rules/indexes فقط بعد قرار واعٍ بأن وظائف تسجيل النتائج لن تختبر قبل Blaze.
5. ترحيل البطولات القديمة إلى `tournamentMemberships` قبل الاعتماد على “بطولاتي” لبيانات إنتاجية قديمة.
6. تشغيل Android debug clean install واختبار Google Sign-In وfollowers و”بطولاتي” وتسجيل/اعتماد نتيجة على جهاز حقيقي.

معيار القبول:

- Android debug يدخل بحساب Google بدون `ApiException: 10`&rlm;.
- لا يظهر mismatch بين native Firebase وFlutterFire في اللوج.
- لا يظهر `PERMISSION_DENIED` في followers عند query المستخدم لنفسه.
- release build لا يعتمد على debug signing.

### المرحلة B: Section States عامة

**الهدف:** فشل قسم لا يكسر الصفحة.

الحالة الحالية:

1. تم إنشاء `SectionStateCard` عام.
2. تم نقل منطق `_SectionErrorCard` إليه.
3. تم تطبيقه في Home وTournament list وTournament detail وشاشة فرقي وشاشة عمليات البطولة.
4. يغطي اختبار شاشة عمليات البطولة ظهور الخطأ داخل `SectionStateCard` مع بقاء أدوات التشغيل الأساسية ظاهرة.
5. حالة الفراغ في شاشة فرقي أصبحت تقود مباشرة إلى إنشاء أول فريق.
6. حالة الفراغ في شاشة بطولاتي أصبحت تقود مباشرة إلى إنشاء دورة شعبية.
7. حالة الفراغ في تبويب اكتشاف المباريات أصبحت تقود مباشرة إلى إنشاء مباراة مفتوحة.
8. حالة الفراغ في Matchday عند اختيار طرف بلا لاعبين أصبحت تخفي أقسام check-in/lineup الفارغة وتقود إلى قائمة الفريق الحقيقية.
9. حالة الفراغ في ScoreSubmit عند غياب لاعبي طرف المباراة تعرض CTA مباشر: قائمة الفريق للطرف الرسمي أو لوبي المباراة للطرف بدون فريق رسمي.

المتبقي:

1. إضافته لأي core section جديد يفشل وحده.

معيار القبول:

- فشل المتابعات يظهر في قسم المتابعات فقط.
- باقي البطولات والمباريات تظهر إن كانت متاحة.
- كل empty state يحتوي CTA واحد واضح.

### المرحلة C: First-Run Intent وClaim

**الهدف:** المستخدم الجديد يعرف ماذا يفعل خلال أول 10 ثوانٍ.

الحالة الحالية:

1. تم تحويل onboarding إلى اختيارات نية واضحة.
2. تم ربط نيات إنشاء بطولة/إنشاء فريق/استكشاف البطولات بمسارات موجودة.
3. `PendingDeepLinkService` يحفظ النية ويعيدها بعد login/profile repair.
4. تم اختبار نيات onboarding الأساسية.
5. تم اختبار رحلة claim route بعد Google sign-in داخل widget test بدون كاميرا فعلية، لكل من player claim وteam claim.
6. تم اختبار استئناف claim route من `ProfileRepairScreen` عندما يصبح البروفايل جاهزاً، لكل من player claim وteam claim.

المتبقي:

1. تشغيل QR/Claim فعلي على جهاز بعد login/profile repair للتأكد من أن الروابط الحقيقية تسلك نفس المسار المحلي.

معيار القبول:

- لا توجد رسائل “قريباً” داخل core flow.
- كل اختيار يفتح شاشة موجودة وقابلة للاستخدام.

### المرحلة D: Liquid Glass rollout

**الهدف:** تحويل الشكل الجديد إلى نظام مستخدم في الشاشات المهمة.

الحالة الحالية:

1. `El7reefGlassSurface` موجود بمتغيرات base/raised/pride/error/sheet.
2. تم استخدامه في Home وTournament list وأخطاء الأقسام.
3. تم نقل `MatchdayEmptyRosterCard` إلى `El7reefGlassSurface.raised` كخطوة إضافية صغيرة داخل مسار المباراة.
4. تم نقل `MatchdayNoManagedSideCard` إلى `El7reefGlassSurface.base` بدون تغيير منطق الصلاحيات أو الرسائل.
5. تم نقل `MatchdaySideSelector` إلى `El7reefGlassSurface.base` بدون تغيير اختيار الطرف أو ربطه بالـ controller.
6. تم نقل `MatchdayAttendanceSection` إلى `El7reefGlassSurface.base` بدون تغيير check-in أو حالة قفل التشكيل.
7. تم نقل `MatchdayLineupSection` إلى `El7reefGlassSurface.base` بدون تغيير قفل التشكيل أو مسارات محرر/مشاركة التشكيلة.
8. تم نقل `MatchdaySubstitutionSection` إلى `El7reefGlassSurface.base` بدون تغيير تسجيل التبديلات أو سجلها.
9. تم نقل `ReadinessStepper` إلى `El7reefGlassSurface.base` بدون تغيير شروط بدء المباراة أو رسائل المنع.
10. تم نقل `CollapsibleTeamSection` إلى `El7reefGlassSurface.base` بدون تغيير إدارة لاعبي اللوبي أو مسارات التشكيلة.
11. تم نقل كارت الدعوة داخل `MatchLobbyScreen` إلى `El7reefGlassSurface.base` بدون تغيير QR أو رابط الدعوة أو نسخ الرابط.
12. تم نقل حالتي الفراغ في Home، المباريات الجارية وآخر مبارياتي، إلى `El7reefGlassSurface.base` بدون تغيير الرسائل أو شروط العرض.
13. تم نقل `HomeMyMatchCard` إلى `El7reefGlassSurface.base` بدون تغيير حساب نتيجة المستخدم أو لون الفوز/الخسارة/التعادل أو مسار فتح لوبي المباراة.
14. تم نقل `MatchCard` إلى `El7reefGlassSurface.base` بدون تغيير ظهور إدارة المباراة أو تفاصيل مشاركتي أو أزرار النتيجة والتصويت والتجميد.
15. تم نقل `ChallengeCard` إلى `El7reefGlassSurface.base` بدون تغيير أزرار قبول/رفض/إلغاء التحدي أو شارة حالته.
16. تم نقل `FanVotingScreen` إلى `El7reefGlassSurface.base` بدون تغيير مؤقت التصويت أو كروت اللاعبين أو رسائل انتهاء/فشل التصويت.
17. تم نقل مكونات قائمة الفريق `TeamRosterHeader` و`TeamRosterActions` و`TeamRosterFormationWorkspace` و`TeamRosterSection` إلى `El7reefGlassSurface.base` بدون تغيير إضافة اللاعبين أو الضيوف أو حفظ القوالب والنسخ الجاهزة.
18. تم نقل `TeamInviteEntryScreen` إلى `El7reefGlassSurface.base` بدون تغيير قبول دعوة الفريق أو مسار تسجيل الدخول أو حالة الرابط الخاطئ.
19. تم نقل كروت نتائج `SearchPlayersScreen` إلى `El7reefGlassSurface.base` بدون تغيير البحث أو إرسال التحدي أو طلب الإضافة.
20. تم نقل كروت `FriendsScreen` وحالة تحميل بروفايل الصديق إلى `El7reefGlassSurface.base` بدون تغيير تبويبات الأصدقاء أو قبول/رفض الطلبات أو قائمة الحظر والإزالة.
21. تم نقل كارت إدخال `UsernameScreen` وكارت القواعد إلى `El7reefGlassSurface.base` بدون تغيير التحقق من التوفر أو الحفظ أو مسار تخطي أول استخدام.
22. تم نقل حالات تحميل/فراغ/خطأ وكروت `ActivityFeedWidget` إلى `El7reefGlassSurface.base` بدون تغيير feature flag أو زر التحديث أو بناء عناصر النشاط.
23. تم نقل كارت المساعد وواجهة إضافة المساعد داخل `TournamentAssistantsScreen` إلى `El7reefGlassSurface.base` بدون تغيير إضافة/إزالة المساعدين أو presets الصلاحيات.
24. تم نقل كروت `ProfileScreen` و`PublicPlayerProfileScreen` إلى `El7reefGlassSurface.base` بدون تغيير رفع الصورة أو QR أو المشاركة أو claim guest profile.
25. تم حذف `lib/core/widgets/glassmorphic_container.dart` بعد التأكد من عدم وجود مراجع حية له داخل `lib/` أو `test/`&rlm;.
26. تم إضافة دعم `borderRadius` مخصص داخل `El7reefGlassSurface`، ونقل واجهات إنشاء مباراة وإنشاء بطولة وإضافة مساعد بطولة إلى `El7reefGlassSurface.sheet` مع الحفاظ على زوايا الورقة العلوية ومسارات الحفظ كما هي.
27. تم تطبيق `El7reefGlassSurface.pride` على previews لكروت نتيجة المباراة وMVP وهدافي البطولة والتشكيلة، مع إبقاء `exportMode` بدون live blur حتى تظل الصور المصدرة مستقرة في capture/share.
28. تم نقل واجهات قائمة الفريق السفلية لإضافة لاعب مسجل/ضيف وحفظ قالب التشكيلة وإنشاء نسخة جاهزة إلى `El7reefGlassSurface.sheet` بدون تغيير البحث أو validation أو حفظ القوالب والنسخ.
29. تم نقل واجهة اختيار مصدر الصورة الشخصية داخل `PhotoUploadService.showPickerDialog` إلى `El7reefGlassSurface.sheet` مع استخدام tokens التصميم بدلاً من ألوان hardcoded، وبدون تغيير منطق اختيار الكاميرا أو المكتبة.
30. تمت مراجعة مراجع `showModalBottomSheet` الحالية داخل `lib/`، وكل الاستدعاءات الحية الحالية أصبحت تستخدم `El7reefGlassSurface.sheet` مباشرة أو عبر helper.
31. تم إضافة reduced blur policy عبر `FeatureFlagKey.reduceGlassBlurEnabled` ومفتاح Remote Config `reduce_glass_blur_enabled`، بحيث يوقف `El7reefGlassSurface` استخدام `BackdropFilter` عند تفعيلها مع بقاء الخلفية والحدود والظل.
32. تم إضافة اختبار لـ `LineupShareCard` يثبت أن preview يستخدم `El7reefGlassSurface.pride` وأن `exportMode` لا يستخدم `El7reefGlassSurface` أو `BackdropFilter`.
33. تم تقوية release signing guard داخل `android/app/build.gradle.kts` بإضافة تحقق من وجود `storeFile` ومنع استخدام `debug-el7reef-v2.keystore` كتوقيع release، مع إضافة `android/key.properties.example` كقالب غير سري.
34. تم إخراج iOS من نطاق QA الحالي داخل الكود: `DefaultFirebaseOptions.ios` يرفض التشغيل برسالة واضحة بدلاً من استخدام `el7reef-app-2026`، وتم حذف iOS القديم من FlutterFire config داخل `firebase.json`، مع اختبار يثبت أن Android ما زال على `el7reef-app` وأن iOS blocked حتى migration.
35. تم تقوية تغطية claim deep link محلياً: `guest_claim_screen_test.dart` يثبت أن المستخدم الذي يفتح رابط claim وهو غير مسجل، يضغط تسجيل الدخول، ينجح Google sign-in، ثم يرجع لنفس شاشة guest player claim بنفس الكود بدلاً من ضياع السياق أو الهبوط على Home.
36. تم إغلاق نفس فجوة الاستئناف للفريق الضيف محلياً: `guest_claim_screen_test.dart` يثبت أن captain يفتح رابط guest team claim وهو غير مسجل، ينجح Google sign-in، ثم يرجع لنفس شاشة guest team claim مع ظهور الفريق المسجل الصالح للربط.
37. تم تقوية مسار profile repair: `profile_repair_screen_test.dart` يثبت أن الحساب عندما يصبح جاهزاً يستأنف pending route لكل من guest player claim وguest team claim، ثم يفرغ `PendingDeepLinkService` حتى لا يعيد فتح الرابط لاحقاً.

المهام:

1. تطبيق pride variant على كروت الفخر المتبقية مثل Champion/Player/Team عند تثبيت واجهاتها النهائية.
2. مراجعة القراءة والحركة على جهاز حقيقي، وتجربة تفعيل `reduce_glass_blur_enabled` على جهاز ضعيف قبل اعتماد القيمة عن بعد.

معيار القبول:

- النصوص مقروءة في الملعب/إضاءة عالية.
- لا يوجد jank واضح في scroll.
- الزجاج يخدم الفخر والتمييز، وليس زخرفة عامة.

---

## 6. أوامر التحقق المطلوبة

```bash
flutter pub get
dart analyze lib/
flutter test
npm run test:rules:emulator
```

تم تشغيل هذه الحزمة حتى مستوى القواعد بتاريخ 2026-07-08:

- `npm run test:rules:emulator` نجح محلياً على Firestore Emulator بنتيجة `167 passing`&rlm;.

تم تشغيل تحقق إضافي بتاريخ 2026-07-09 بعد تغطية مسار النتائج عبر callable:

- `dart analyze test/core/services/match_settlement_service_remote_test.dart` بدون مشاكل.
- `flutter test test/core/services/match_settlement_service_remote_test.dart` نجح بـ 3 اختبارات.
- `npm run test:functions` نجح بـ `11 passing`&rlm;.
- `node --check functions/index.js` و`node --check functions/approval_core.js` و`node --check functions/settlement_payload.js` بلا أخطاء syntax.
- `npm install --package-lock-only --prefix functions` نجح وولّد `functions/package-lock.json`، مع تحذير npm audit عن 8 ثغرات moderate في شجرة dependencies الحالية.
- `npm run test:rules:emulator` نجح بعد تنظيف rules بنتيجة `167 passing`&rlm;.
- `npx firebase-tools deploy --only firestore:rules --project el7reef-app --dry-run` نجح وCompile القواعد بدون issues.
- `npx firebase-tools deploy --only functions,firestore:rules --project el7reef-app --dry-run` فشل قبل النشر لأن المشروع ليس على Blaze ولا يمكن تفعيل `cloudbuild.googleapis.com` حالياً.
- `flutter pub get` نجح مع تحذير وجود حزم أحدث غير متوافقة مع القيود الحالية.
- `dart analyze lib/` بدون مشاكل.
- `flutter test` نجح بـ `467` اختبار.

أوامر Android/Firebase إضافية عند جاهزية release:

```bash
flutter build apk --debug
flutter build appbundle --release
npx -y firebase-tools@latest deploy --only firestore:rules --project el7reef-app
```

---

## 7. مؤشرات القياس

| المؤشر | الهدف |
| :--- | :--- |
| رجوع المستخدم إلى login بعد Google Auth ناجح | صفر إلا عند sign-out صريح. |
| أخطاء Firebase project mismatch في اللوج | صفر على Android. |
| خطأ `followers PERMISSION_DENIED` للمستخدم على بياناته | صفر بعد نشر rules. |
| وجود CTA واضح للمستخدم الجديد | موجود في أول شاشة بعد الدخول. |

## 8. مخاطر ومتابعات
| فشل قسم داخل Home أو Tournaments | يظهر داخل القسم فقط. |
| استخدام Liquid Glass | واضح في login/home/tournament/pride بدون إضعاف القراءة. |
| release signing | لا يستخدم debug key في build النهائي. |

---

## 8. مخاطر ومتابعات

1. iOS خارج نطاق QA الحالي وممنوع من استخدام مشروع Firebase القديم؛ الخطر يعود فقط إذا تم إدخال iOS بدون تنزيل config رسمي من `el7reef-app`.
2. release build يفشل حالياً بوضوح عند غياب `key.properties`، أو عند `storeFile` غير صالح، أو عند محاولة استخدام debug keystore؛ وهذا مقصود. المتبقي إنشاء release keystore فعلي قبل Play Store.
3. تغيير keystore debug مرة أخرى سيكسر SHA المسجل في Firebase.
4. `firebase.json` يحتوي إعداد FlutterFire بجانب إعدادات deploy؛ يجب الانتباه لأي تحذيرات CLI وعدم الخلط بينها وبين فشل rules.
5. لا يجب نشر Firestore rules المشددة التي تمنع direct score/matchEvents/player_stats/fanVoting writes وحدها إذا كانت Cloud Functions غير منشورة على نفس المشروع؛ مسار Flutter المحلي يعتمد الآن على callable أولاً والـ fallback المحلي مقفول افتراضياً.
6. نشر Functions متوقف حتى ترقية `el7reef-app` إلى Blaze؛ dry-run حاول تفعيل `cloudfunctions.googleapis.com` و`artifactregistry.googleapis.com` واصطدم تحديداً بـ `cloudbuild.googleapis.com` لأنه يتطلب Blaze.
7. `functions/package-lock.json` أظهر 8 ثغرات npm audit بدرجة moderate؛ لا يتم تشغيل `npm audit fix` تلقائياً قبل مراجعة أثره على Firebase Functions.
8. Liquid Glass قد يرفع تكلفة الرسم لو انتشر بدون سياسة blur واضحة.
9. deep links الخاصة بالـ claim تحتاج اختبار كامل بعد login/profile repair.

</div>
