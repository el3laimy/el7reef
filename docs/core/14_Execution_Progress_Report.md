<div dir="rtl">

# لقطة تقدم تنفيذ خطة El7reef V1 حتى 14 يوليو 2026

**الحالة:** `ARCHIVED SNAPSHOT` حتى 14 يوليو 2026

**آخر تحديث:** 14 يوليو 2026  
**المصدر التنفيذي وقت اللقطة:** `docs/core/08_Unified_V1_Completion_And_Workspace_Plan.md`&rlm;

**المصدر التنفيذي الحالي:** `docs/core/17_V1_Security_And_Release_Completion_Plan.md`&rlm;

**قاعدة الاستخدام:** الأعداد والحالات أدناه أدلة تاريخية فقط؛ لا تُستخدم لتقرير جاهزية الإصدار بعد اكتشاف بوابات الأمن وCI في 28 يوليو 2026.

## 1. الملخص الحالي

| الحالة | عدد التذاكر | المعنى الحالي |
| :--- | :---: | :--- |
| `DONE` | 22 | القبول المطلوب مثبت بالدليل |
| `VERIFY` | 12 | التنفيذ موجود وينتظر دليل جهاز أو نشر أو اعتماد OWNER |
| `BLOCKED-EXTERNAL` | 11 | يحتاج Firebase/Play/توقيع/جهاز/قرار OWNER |
| **الإجمالي** | **45** | كل تذاكر Waves 0–5 مسجلة، وWave 6 بوابة Pilot وليست تذاكر كود إضافية |

لا يعني هذا أن الإصدار مكتمل. يعني أن العمل المحلي الرئيسي منظم ومقاس، وأن المتبقي معروف ومُسند إلى دليل أو حاجز محدد.

## 2. تقدم التنفيذ حتى 14 يوليو 2026

| المهمة | النتيجة | الدليل |
| :--- | :---: | :--- |
| تحديث الاعتمادات بعد إزالة الحزم غير المستخدمة | `DONE` | نجح `flutter pub get`، وأزيلت 32 حزمة مباشرة أو انتقالية مرتبطة بـFCM وAnalytics والخرائط والموقع وHive وConnectivity |
| تحليل كود Flutter كامل | `DONE` | `dart analyze lib/` أعاد `No issues found!`&rlm; |
| إصلاح عقد إعادة المصادقة في Fakes | `DONE` | حُدثت 9 Fakes كانت تمنع تجميع المجموعة الكاملة |
| إصلاح موافقة قواعد المجتمع داخل السطح الزجاجي | `DONE` | أضيف `Material` شفاف حول `CheckboxListTile` لإزالة assertion الخاص بـListTile/DecoratedBox |
| تثبيت بوابة الموافقة قبل Google Sign-In | `DONE` | اختبار واجهة يثبت تعطيل الزر قبل الموافقة وتفعيله بعدها؛ نجحت حزمة Auth + Claim المركزة 13/13 |
| تحديث اختبارات Claim للسلوك الجديد | `DONE` | تقبل السياسة قبل Google Sign-In وتحافظ مستودعات Fake على حياتها أثناء `offAll`&rlm; |
| اختبار Claim كامل | `DONE` | 10/10 اختبارات نجحت |
| بوابة Flutter الكاملة | `DONE` | 573/573 اختبارًا نجحت في 14 يوليو 2026 |
| بوابة Functions | `DONE` | 62/62 اختبارًا نجحت، وتشمل roster والتسوية idempotent والترحيل وبلاغات السلامة وعقد audit |
| تحميل Functions Runtime | `DONE` | أُصلح استيراد SDK إلى `firebase-functions/v1` واستخدام Timestamp/FieldValue المعياري؛ Emulator حمّل exports الستة بدل فشل `runWith` |
| Functions Emulator الموثق | `DONE` | 6/6 callables رفضت غير الموثق، ونجحت Auth tokens وكتابات report/block/audit؛ ثبت أن `actorId` المخزن يساوي المستخدم الموثق لا قيمة العميل |
| حذف الحساب عبر Emulators | `DONE` | Auth/Firestore/Storage smoke أثبت حذف الحساب والصورة والعلاقات وتجهيل audit/report وكتابة طلب `completed` دون Blaze |
| بوابة قواعد Firestore | `DONE` | 168/168 اختبارًا نجحت على Firestore Emulator في 12 يوليو 2026 |
| تحليل التغييرات الأخيرة | `DONE` | `dart analyze lib/` مع اختبارات Auth وClaim أعاد `No issues found!`&rlm; |
| سلامة الفروقات | `DONE` | `git diff --check` نجح بلا أخطاء whitespace |
| تنسيق ملفات الخطة المتغيرة | `DONE` | فُحص 147 ملف Dart متغيرًا فقط؛ `Formatted 147 files (0 changed)`&rlm; |
| فحص التنسيق الكامل | `VERIFY` | كشف 184 ملفًا نظيفًا غير داخل diff من أصل 616، بينها 45 ملف Fantasy؛ لم يكتب الفحص أي ملف ولم تُضخم الحزمة بإعادة تنسيق جماعية |
| بناء APK جديد | `DONE` | نجح البناء المحدود خلال 94.2 ثانية؛ artifact بتاريخ 12 يوليو 2026 وحجمه 187,967,778 بايت |
| فحص Manifest المدمج | `DONE` | لا `POST_NOTIFICATIONS` ولا موقع أو تخزين عام؛ `CAMERA` مبررة، و`c2dm.RECEIVE` انتقالية من `firebase-iid:21.1.0` بلا runtime prompt |
| نشر صفحات Hosting القانونية | `DONE` | نُشرت `/privacy` و`/delete-account` و`/community-guidelines` على `el7reef-app.web.app`&rlm; |
| smoke عام للصفحات القانونية | `DONE` | الروابط الثلاثة تعيد HTTPS 200 وتحتوي `dir="rtl"`&rlm; |
| نشر Cloud Functions | `BLOCKED-EXTERNAL` | preflight بتاريخ 14 يوليو أكد أن production بلا Functions وأن `artifactregistry.googleapis.com` و`cloudbuild.googleapis.com` يتطلبان Blaze؛ لم يحدث نشر |
| جرد هوية MatchEvent | `DONE` | قراءة production لحقل actor فقط أعادت صفر مستندات، فلا توجد أنواع legacy تحتاج migration |
| معاينة عضويات البطولات | `VERIFY` | فُحصت 5 بطولات؛ 5 عضويات منظّم مفقودة بلا تعارض أو مصدر تالف، والتطبيق ينتظر backup واعتماد كتابة مخول |
| توافق فهارس Firestore | `DONE` | حُفظت فهارس production الأحد عشر داخل الملف المحلي، وأصبح `check:indexes` يحرسها؛ deploy dry-run للقواعد والفهارس نجح |
| نشر Remote Config | `DONE` | نُشر القالب إلى `el7reef-app` مع `pride_growth_links_enabled=false` و`post_match_pride_hub_enabled=false`&rlm; |
| فحص package وTarget SDK | `DONE` | Manifest المبني يثبت `com.el7reef.app` و`android:targetSdkVersion="36"` ولا توجد مفاتيح Release متتبعة في Git |
| AAB تشخيصي | `DONE` | `bundleDebug` بحجم 95,357,353 بايت وبصمة SHA-256 `7dc972f…3aea6`؛ 701 مدخل ZIP اجتازت `unzip -t` بلا تلف، ولا يُعد signed Release AAB |
| Release signing guard | `DONE` | `bundleRelease` وصل Gradle وتوقف خلال 18 ثانية برسالة غياب `android/key.properties` بدل إنتاج AAB غير موقع أو استخدام debug keystore |
| أدوات Android | `DONE` | نُزل أرشيف Command-Line Tools الرسمي، وتحققت بصمته، وثُبت `sdkmanager 20.0` و`avdmanager` داخل Android SDK المحلي |
| تثبيت التطبيق على جهاز فعلي | `DONE` | أزيل الإصدار السابق وثُبت `app-debug.apk` على Samsung SM-G980F، Android 13/API 33، وشُغل التطبيق بنجاح |
| مطابقة شهادة App Links | `DONE` | بصمة SHA-256 لشهادة APK هي `05:6C:02:29:1B:E4:7F:F9:90:57:E2:C4:69:D7:13:9E:67:01:95:52:2F:89:97:D8:49:B6:9E:DD:46:95:9F:0C` وتطابق `hosting/.well-known/assetlinks.json`&rlm; |
| تحقق App Links على Android | `DONE` | أعاد `pm get-app-links` النطاق `el7reef-app.web.app: verified`، وأظهر `pm get-app-link-owners` الحزمة `com.el7reef.app` كمالك `VERIFIED` وافتراضي للرابط |
| فتح الروابط باردًا ودافئًا | `DONE` | فتح مسار البطولة باردًا في `MainActivity` خلال 3027ms، وسُلما مسارا المباراة واللاعب إلى النسخة الدافئة خلال 16ms و18ms |
| تشخيص رسالة Claim | `DONE` | وصل رابط `SAFE-CODE` إلى `GuestPlayerClaimController`، ثم فشلت القراءة الآمنة بصلاحيات Firestore لأن الكود تجريبي وغير موجود؛ الرسالة لا تدل على فشل parser أو App Link |
| Claim حقيقي وPilot على Android | `BLOCKED-EXTERNAL` | يحتاج Claim صالحًا وبيانات بطولة وحساب اختبار من OWNER، ثم تجربة قبل/بعد login وغير مثبت وWhatsApp وTalkBack؛ Release يبقى خلف signing وPlay fingerprint |

## 3. سجل منع الدوران دون تقدم

نستخدم القواعد التالية في بقية التنفيذ:

1. لا يُعاد الأمر نفسه دون تغيير سبب الفشل أو إضافة دليل جديد.
2. الحد الأقصى ثلاث محاولات للسبب الجذري نفسه؛ بعدها يتحول إلى `BLOCKED-EXTERNAL` مع سجل واضح.
3. كل محاولة يجب أن تنتج واحدًا من: تعديل كود، اختبار مركز، artifact أحدث، أو تشخيص قابل للتنفيذ.
4. لا تُستخدم حالة `DONE` عند نجاح اختبار جزئي لتذكرة قبولها يتطلب جهازًا أو نشرًا.
5. أي انتظار يتجاوز المدة المعقولة يُفحص عبر حالة العملية ووقت artifact بدل polling غير المحدود.

### سجل المحاولات الحالية

| البوابة | المحاولة | ما تغير | القرار |
| :--- | :---: | :--- | :--- |
| Flutter tests | 1 | كشفت Fake واحدًا ناقصًا | إصلاح العقد بدل إعادة عمياء |
| Flutter tests | 2 | كشفت 8 Fakes أخرى وassertion في Login | إصلاح كل تطبيقات العقد والسطح |
| Claim tests | 1 | كشفت أن قبول السياسة وحياة GetX غير ممثلين في الاختبار | تحديث السيناريو والـfixtures |
| Policy gate test | 1 | المنطق صحيح لكن مؤقتات `flutter_animate` بقيت بعد التخلص من الشجرة | استخدام `pumpAndSettle` بدل قبول فشل زائف أو إعادة عمياء |
| Policy gate test | 2 | Auth + Claim أصبحت 13/13 خضراء | تثبيت regression مستقل للموافقة قبل تسجيل الدخول |
| Flutter tests | 3 | 537/537 خضراء قبل اختبار الموافقة الجديد | إغلاق خط الأساس السابق |
| Flutter tests | 4 | 538/538 خضراء بعد الاختبار الجديد | تحديث بوابة الاختبار المحلي بالدليل النهائي |
| Flutter tests | 5 | إعادة البوابة بعد إصلاحات المعمارية والفهارس | 573/573 خضراء |
| Rules emulator | 1 | شُغل الاختبار الكامل بعد آخر تغييرات القواعد والخدمات | 168/168 خضراء وإغلاق بوابة القواعد المحلية |
| Format gate | 1 | الفحص الكامل كشف 184 ملفًا، ثم أثبت التصنيف أن جميعها نظيفة خارج diff وبينها 45 Fantasy | عدم إنشاء 184 تغييرًا شكليًا خارج حزمة V1 |
| Changed-file format | 1 | فُحصت كل ملفات Dart المتغيرة وعددها 205 | 205/205 منسقة دون تعديل إضافي |
| Changed-file format | 2 | إعادة الفحص على diff الحالي بعد تجاوز قيد sandbox الموثق | 147/147 منسقة دون تعديل |
| APK build | 1 | انتهت الجلسة دون artifact أحدث قابل للإثبات | لم تُحسب نجاحًا |
| APK build | 2 | أضيف حد 300 ثانية و`--no-pub` بدل الانتظار المفتوح | نجح خلال 94.2 ثانية وأغلق `UCP-507` |
| Functions deploy | 1 | وصل Firebase CLI إلى تفعيل APIs المطلوبة | توقف صراحة عند Blaze؛ لا إعادة قبل تغير الخطة المالية |
| Functions deploy preflight | 2 | فحص Functions والقواعد والفهارس دون نشر | أكد عائق Blaze وكشف صفر Functions منشورة؛ اكتملت نقطة rollback |
| Firestore indexes preflight | 1 | مقارنة 11 فهرسًا منشورًا بالملف المحلي | منع حذف فهارس قائمة، ونجح dry-run بعد دمج baseline |
| Functions emulator | 1 | كشف `functions.runWith is not a function` ومنع تحميل الحزمة | إصلاح الاستيراد وإضافة entrypoint regression |
| Functions emulator | 2 | كشف Timestamp legacy يفشل عند أول طلب موثق | استخدام imports المعيارية لـTimestamp وFieldValue |
| Functions emulator | 3 | 6/6 auth gates وreport/block/audit نجحت | إغلاق runtime smoke المحلي الأساسي دون Blaze |
| Deletion emulator | 1 | أضيف Storage/Auth/Firestore smoke لكن تشغيله رُفض بسبب حد استخدام موافقات الأدوات | لا تحايل؛ ينتظر موافقة صريحة أو تجدد الحد |
| Deletion emulator | 2 | وافق المستخدم صراحة وشُغلت Emulators الأربعة | حذف Auth/Storage/Firestore والتجهيل وطلب الإكمال نجح بالكامل |
| AAB debug | 1 | طُلب بناء محدود بخمس دقائق | رفضته بيئة الموافقات قبل التنفيذ؛ لم يُنتج artifact ولم يُحسب نجاحًا |
| AAB debug | 2 | تغيرت نافذة الموافقات وأعيد الأمر نفسه بحد زمني | نجح وأثبت pipeline دون تغيير حالة Release signing |
| AAB release | 1 | شُغلت محاولة محدودة بعد إثبات غياب المفتاح | signing guard رفض البناء برسالة واضحة خلال 18 ثانية؛ لا إعادة قبل توفير مفتاح OWNER |
| Android CLI | 1 | نُزلت الحزمة الرسمية 164MB ببطء، ورفض التثبيت تجاوز بصمة غير صالحة الصياغة | التوقف الآمن قبل فك الأرشيف |
| Android CLI | 2 | طوبقت القيمة الرسمية ذات 40 خانة كـSHA-1 ثم فُك الأرشيف | تثبيت `sdkmanager 20.0` و`avdmanager` بنجاح |
| Android image | 1 | بدأ تنزيل Android 35 Google APIs بعد قبول الحزمة | أوقف عند 12% بعد خمس دقائق بلا تقدم عملي؛ لا `/dev/kvm` والجزء لم يُحفظ، لذا لا إعادة قبل تغير البيئة |
| Physical Android | 1 | وصل جهاز Samsung SM-G980F وظهر في `flutter devices` و`adb` | اختيار الجهاز الفعلي بدل استكمال Emulator البطيء |
| APK install | 1 | طوبقت بصمة شهادة APK مع `assetlinks.json` قبل التثبيت | إزالة النسخة السابقة وتثبيت APK التشخيصي بنجاح |
| App Links | 1 | طلب النظام إعادة التحقق من النطاق ثم فُحص المالك والـdefault handler | النطاق verified والحزمة مالك VERIFIED؛ بصمة Play ما زالت خارجية |
| Claim link | 1 | استُخدم `SAFE-CODE` لاختبار النقل فقط | الرابط وصل لمتحكم Claim، ورفضت Firestore القراءة الآمنة؛ لا يُعاد الاختبار كـE2E قبل توفير code صالح |
| Cold/warm routes | 1 | فُتح tournament بعد force-stop ثم match/player والتطبيق دافئ | `MainActivity` استقبل المسارات الثلاثة دون crash بزمن 3027ms و16ms و18ms |

## 4. حالة الموجات

| الموجة | الحالة | المكتمل | المتبقي المحدد |
| :--- | :---: | :--- | :--- |
| Wave 0 | `DONE` | تثبيت مساحة العمل والـbaseline والتوثيق | لا شيء |
| Wave 1 | `BLOCKED-EXTERNAL` | backend/migration محليًا واختباراته وlaunch جهاز فعلي | Blaze، ADC، نشر Functions، signing، Release AAB |
| Wave 2 | `VERIFY` | SharePayload وApp Links debug verified وcold/warm delivery والـClaim المحلي | Claim صالح قبل/بعد login وغير مثبت وبصمة Play |
| Wave 3 | `VERIFY` | Pride Hub والبطاقات والنسب والـfallbacks | قياس ≤15 ثانية وعودة WhatsApp على Android |
| Wave 4 | `VERIFY` | Score UX والمسودة والتعارض و«اعمل الآن» | TalkBack وقياس jank على جهاز متوسط |
| Wave 5 | `BLOCKED-EXTERNAL` | الحذف والخصوصية وUGC والجرد وData Safety وHosting المنشور | نشر Functions، Play Console، اعتماد OWNER، AAB وجهاز |
| Wave 6 | `BLOCKED-EXTERNAL` | سيناريو Pilot ومعاييره موثقة | AAB وحسابات وتجربة بطولة فعلية |

## 5. ترتيب العمل التالي

اكتملت كل المهام الهندسية المحلية داخل حزمة V1 التي لا تحتاج Blaze أو أسرار OWNER، بما فيها Emulators الأربعة وsigning guard وأدلة APK/AAB التشخيصية والتحقق الأساسي على جهاز Android فعلي.

1. توفير Claim صالح وحساب اختبار وبيانات بطولة من OWNER لإغلاق login/repair والمشاركة والعودة من WhatsApp على الجهاز الحالي.
2. تنفيذ TalkBack ورفض الكاميرا وقياس jank و≤15 ثانية يدويًا على الجهاز الحالي أثناء الرحلة الحقيقية.
3. توفير Release signing وPlay App Signing لإنتاج AAB نهائي وربطه بـClosed Testing.
4. اعتماد OWNER لسياسة الخصوصية وفترات الاحتفاظ وData Safety وحساب المراجع.
5. ترقية Firebase إلى Blaze لاحقًا لنشر Functions وإجراء smoke الإنتاجي ثم تنفيذ Pilot؛ لا يمنع ذلك بقية العمل المحلي.

## 6. معيار الانتهاء الكامل

لن يُعلن انتهاء جميع الخطط إلا عندما:

- تصبح كل التذاكر `DONE` أو تُغلق بقرار OWNER موثق يلغيها من النطاق.
- تنجح بوابات Firebase المنشورة وAAB وApp Links على جهاز Android حقيقي.
- تنجح رحلة البطولة والنتيجة والمشاركة وClaim في Closed Testing ثم Pilot فعلي.
- تُطابق Data Safety والسياسات الـAAB النهائي والسلوك المنشور.

## 7. تقدم جلسة 13 يوليو 2026 — Street Ultimate Squad

| المهمة | النتيجة | الدليل |
| :--- | :---: | :--- |
| مراجعة لقطتي شاشة خطة الفريق وربطهما بالكود | `DONE` | وُثقت المشكلات والمكونات ومسار الإصلاح في `docs/core/15_Team_Lineup_Ultimate_Squad_Redesign_Plan.md`&rlm; |
| بناء بطاقة لاعب موحدة | `DONE` | أضيف `lib/features/lineup/widgets/squad_player_card.dart` للصورة/initials والرقم الحقيقي والاسم والمركز والقائد وهوية الزائر أو المؤقت |
| إعادة تصميم الملعب | `DONE` | استُبدلت خلفية التحرير الذهبية بملعب شارع code-native، وخُفف المنظور، ووُحد إسقاط البطاقات وخطوط الربط |
| تحسين 11v11 الكثيف | `DONE` | أضيف `Dense Squad` ببطاقات 48px وإسقاط أعرض وارتفاع تكيفي واسم أول مختصر، دون تغيير بيانات اللاعب أو Semantics الكاملة |
| منع تداخل 11v11 | `DONE` | اختُبرت كل الخطط السبع على عرض 320px وتكبير نص 200%، بما فيها خطوط الخمسة لاعبين في `3-5-2` و`5-4-1`، دون تداخل |
| Golden لخطة 11v11 | `DONE` | أضيف `test/features/lineup/goldens/ultimate_squad_11v11_320.png` كمرجع بصري ثابت لخطة `3-5-2`&rlm; |
| توحيد التحكم والحفظ | `DONE` | شريط تكتيكي واحد وحفظ واحد فقط عند dirty state، دون لوحة حالة كبيرة أو شريط حفظ عائم مكرر |
| تطوير البدلاء | `DONE` | dock مضغوط بنفس بطاقات الملعب مع استمرار النقر والسحب والتبديل |
| الوصول والاستجابة | `DONE` | Semantics عربية للاسم والرقم والمركز والهوية، ومسار نقر كامل، واختبار 320px عند `textScale=2.0`&rlm; |
| اختبارات التشكيلة والفريق المركزة | `DONE` | 30/30 اختبارًا نجحت بعد إضافة Golden 11v11 |
| اختبارات الرحلات المشتركة | `DONE` | 60/60 اختبارًا نجحت للتشكيلة والفريق والمشاركة ويوم المباراة |
| تحليل Flutter | `DONE` | `dart analyze lib/` أعاد `No issues found!`&rlm; |
| بوابة Flutter الكاملة | `DONE` | 542/542 اختبارًا نجحت في 13 يوليو 2026 |
| تحقق الجهاز الفعلي | `DONE` | شُغلت الهوية الجديدة على Samsung SM-G980F وأُخذت لقطتا الملعب والبدلاء داخل `ScreenShots/`&rlm; |
| بناء APK مع Dense Squad | `DONE` | الحجم 187,971,781 بايت، SHA-256 `5ff4dd7229f8955889af8f08dda51a4c106935efdd6e201d2c5b62cf4c1eab3d`&rlm; |
| تثبيت APK مع Dense Squad | `DONE` | ثُبت على Samsung SM-G980F في 13 يوليو 2026 الساعة 15:29، وشُغلت خطة الفريق بحالة «محفوظة»؛ الدليل `ScreenShots/Screenshot_20260713_dense_squad_installed_7v7.png`&rlm; |
| مراجعة لقطة اختفاء الحفظ | `DONE` | أثبتت `ScreenShots/Screenshot_20260713_153700.jpg` أن زر الحفظ موجود خارج الجزء المرئي من الشريط الأفقي، وليس مفقودًا من الحالة |
| تثبيت ظهور الحفظ | `DONE` | فُصلت أدوات العدد والخطة عن صف إجراءات dirty، وأصبح زر الحفظ الوحيد ثابتًا داخل عرض 320px عند تكبير النص 200% |
| اختيار حجم التشكيلة | `DONE` | فُعل اختيار 5v5 حتى 11v11 في شاشة الفريق وربط بـ`changeVisualPlayerCount` مع الحفاظ على اللاعبين ونقل الفائض للبدلاء |
| استعادة العدد المحفوظ | `DONE` | أُصلح fallback كان يعيد الخطة إلى 7 عند وجود خانات فارغة؛ اختبار واجهة يثبت حفظ 11v11 واستعادتها بعد إعادة التحميل |
| تحقق إصلاح الحفظ والعدد | `DONE` | 30/30 اختبارًا مركزًا و542/542 اختبارًا كاملًا، و`dart analyze lib/` دون مشكلات |
| بناء APK لإصلاح الحفظ والعدد | `DONE` | الحجم 187,971,781 بايت، SHA-256 `615777a9e56f9f0f573ded235e4f084f7b964dfc602f88484d313a30ae39562b`&rlm; |
| تثبيت APK لإصلاح الحفظ والعدد | `DONE` | ثُبت البناء ذو البصمة `615777a9` على Samsung SM-G980F؛ أثبتت قائمة الجهاز وجود 5v5 حتى 11v11، وظهور زر الحفظ كاملًا في 11v11، ثم حُفظت 7v7 بخطة 3-1-2 واستُعيدت بعد إغلاق التطبيق وتشغيله. الأدلة: `ScreenShots/Screenshot_20260713_save_count_fix_11v11_dirty.png` و`ScreenShots/Screenshot_20260713_save_count_fix_restart_verified.png`&rlm; |
| حفظ اللاعبين عند تغيير الحجم | `DONE` | أصبح التصغير ينقل كل الفائض إلى البدلاء دون فقد، وأصبح التكبير يملأ الخانات الجديدة تلقائيًا من اللاعبين خارج الملعب مع تفضيل مراكزهم وإبقاء الزائد فقط في البدلاء |
| استعادة خطة ناقصة الخانات | `DONE` | أصبح `formationLabel` المحفوظ هو المرجع الأساسي للعدد والخطة، فلا تتحول 11v11 إلى 8v8 أو 5v5 بسبب وجود خانات فارغة؛ يبقى الاستنتاج من التعيينات fallback للبيانات القديمة فقط |
| اختبار انحدار 7→5→11 | `DONE` | أضيف سيناريو بثمانية لاعبين يثبت وجود 5 في الملعب و3 بدلاء بعد حفظ 5v5، ثم وجود الثمانية في الملعب عند العودة إلى 11v11، مع ثبات المجموعة كاملة بعد الحفظ وإعادة التحميل |
| تحقق إصلاح دورة تغيير الحجم | `DONE` | نجحت اختبارات التشكيلة والفريق 29/29، والبوابة الكاملة 543/543، و`dart analyze lib/` دون مشكلات، و`git diff --check` دون أخطاء |
| بناء APK لإصلاح فقد اللاعبين | `DONE` | بُني `app-debug.apk` في 13 يوليو 2026 الساعة 16:52 بحجم 187,971,781 بايت، SHA-256 `87c221e8b87faa9900043250e12581b6917c137266ffcfab5bc6cbf18721c4f6`&rlm; |
| تحقق جهاز لإصلاح فقد اللاعبين | `VERIFY` | البناء جاهز؛ جهاز `ADB` غير متصل حاليًا، وينتظر التحقق البصري من 7v7→5v5→11v11 ولقطات المستخدم الجديدة |

</div>
