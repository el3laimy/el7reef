<div dir="rtl">

# الخطة التنفيذية الموحدة لإكمال El7reef V1

**الإصدار:** 2.0  
**الحالة:** `SUPERSEDED` — لقطة تاريخية؛ استُبدلت في 28 يوليو 2026
**تاريخ المراجعة:** 2026-07-11  
**المنتج:** Tournament Ego MVP  
**منصة الإصدار:** Android أولًا  
**نطاق الخطة:** تثبيت مساحة العمل، إغلاق حلقة البطولة والنمو، جاهزية Firebase وGoogle Play، ثم Pilot حقيقي

> مصدر التنفيذ والقبول النشط الآن هو `17_V1_Security_And_Release_Completion_Plan.md`&rlm;. تبقى هذه الوثيقة دليلًا تاريخيًا للقرارات والأعمال المنفذة حتى خط أساسها، ولا تُستخدم كـbacklog موازية.

---

## 1. الملخص التنفيذي

المشروع لا يحتاج إعادة بناء ولا توسيعًا جديدًا في Fantasy أو Social. النواة التشغيلية موجودة محليًا وتغطي البطولات، الفرق واللاعبين الضيوف، MatchEvent، النتائج، الترتيب، الهدافين، والـClaim الأساسي. الفجوة الحقيقية هي أن هذه القدرات لم تتحول بعد إلى **رحلة نمو منشورة ومقاسة وقابلة للإطلاق**.

الهدف التنفيذي الوحيد هو إثبات هذه الحلقة على بيئة Firebase المستهدفة وعلى جهاز Android حقيقي:

> إنشاء بطولة ← إضافة فرق ولاعبين مسجلين وضيوف ← تشغيل مباراة دون تشكيل إلزامي ← تسجيل أهداف وMVP للجميع ← اعتماد النتيجة ← مشاركة بطاقة برابط صالح ← فتح البروفايل أو Claim ← العودة لمتابعة البطولة.

تتحرك الخطة عبر ثلاثة مسارات متوازية:

1. **مسار المنتج والنمو:** SharePayload، App Links، Claim من البطاقة، Pride Hub، وبطاقات Champion/Player/Team.
2. **مسار المنصة والإطلاق:** Firebase Functions، rules/indexes، migration، signing، API 35، وسياسات Google Play.
3. **مسار الجودة والتشغيل:** تثبيت مساحة العمل، تبسيط Score Submit، الوصول، QA، والـPilot.

لا يُعتبر اكتمال الكود المحلي اكتمالًا للمنتج. الاكتمال يحتاج نشرًا آمنًا، AAB موقّعًا، روابط موثقة، QA جهاز، ونتائج Pilot فعلية.

---

## 2. حدود السلطة والتوثيق

هذه الوثيقة تستبدل ترتيب التنفيذ في:

- `05_Project_Roadmap_and_Sprint_Plan.md`
- `06_UX_Hardening_And_Liquid_Glass_Plan.md`
- `07_Tournament_Ego_UX_Audit_And_Repair_Plan.md`
- ملفات `tournament_tos_*`
- `implementation_backlog.md`
- `implementation_backlog_v2.md`

تظل هذه الملفات مراجع تاريخية ومعمارية، لكنها ليست قوائم عمل موازية. أي مهمة جديدة يجب أن ترتبط بتذكرة من هذه الخطة أو تُرفض باعتبارها توسع نطاق.

### 2.1 الأدوار

| الرمز | الدور | المسؤولية |
| :--- | :--- | :--- |
| `OWNER` | مالك المنتج/الحسابات | Blaze، الدومين، Play Console، السياسات، قرار الإطلاق |
| `ENG` | الهندسة | الكود، migrations، Functions، rules، App Links، الاختبارات |
| `DESIGN` | المنتج/التصميم | ترتيب CTA، بطاقات الفخر، النصوص العربية، سيناريوهات الجهاز |
| `QA` | الجودة | مصفوفة القبول، أجهزة Android، TalkBack، الشبكة، Pilot evidence |

يمكن لشخص واحد أداء أكثر من دور، لكن لا يجوز ترك مسؤولية خارجية بلا مالك صريح.

---

## 3. الحقيقة الحالية من مساحة العمل

### 3.1 مثبت محليًا ويجب الحفاظ عليه

| القدرة | الحالة | الدليل المقبول حاليًا | القرار |
| :--- | :---: | :--- | :--- |
| MatchEvent للأهداف وMVP | مثبت محليًا | services + tests للمسجل والضيف وmatch-side player | لا إعادة كتابة |
| Tournament lifecycle | مثبت محليًا | participants، groups، fixtures، standings، bracket، champion | لا إعادة بناء |
| Guest teams/players | مثبت محليًا | repositories، roster، matchday، claim tests | مواطنون درجة أولى |
| Routes إنشاء البطولة والفريق | مغلقة | route contract + intent tests | لا تذكرة إصلاح جديدة |
| بدء مباراة دون تشكيل | مغلق آليًا | fallback roster + service tests + nudge | يبقى QA جهاز فقط |
| Result/MVP/Top Scorers/Lineup Cards | موجودة | widget tests | تتحسن ولا تُستبدل |
| Firebase/Auth hardening | مثبت محليًا | config guard، profile repair، session tests | يحتاج runtime QA |
| Backend settlement | مثبت محليًا | 11 Functions tests + remote Flutter tests | يحتاج Blaze ونشرًا متزامنًا |
| Firestore security | مثبت محليًا | 168 emulator tests | يحتاج deploy preflight ونشرًا فعليًا |

### 3.2 غير مكتمل أو غير مثبت خارج الاختبارات

| الفجوة | النوع | أثرها |
| :--- | :---: | :--- |
| مساحة العمل تحتوي حزمة تغييرات كبيرة غير مقسمة | تشغيل | مراجعة وrollback صعبان |
| Functions/rules غير مثبتة على البيئة المستهدفة | P0 إطلاق | النتيجة قد تعمل محليًا فقط |
| App Links وweb fallback لا تزالان بلا تحقق Android/Play نهائي | P0 نمو | لا يمكن إثبات verified state أو رحلة الجهاز الكاملة قبل `UCP-106` و`UCP-203` و`UCP-208` |
| SharePayload موحد متصل بالبطاقات الأربع الحالية | P0 نمو | يحتاج E2E جهاز فعلي قبل إعلان الحلقة مكتملة |
| Claim متصل ببطاقة MVP الضيف برابط آمن | P0 نمو | يحتاج E2E مثبت/غير مثبت قبل اعتماد النمو |
| Post-Match Pride Hub غير مكتمل | P1 منتج | المشاركة تحتاج تنقلات إضافية |
| Champion/Player/Team Cards غير موجودة | P1 منتج | حزمة V1 ناقصة |
| Score Submit بلا draft مستعاد ورحلة قصيرة | P1 UX | خطر فقد الإدخال وبطء الملعب |
| release signing وAAB غير مثبتين | P0 إطلاق | لا إصدار متجر صالح |
| حذف الحساب والسياسات وData Safety ناقصة | P0 سياسة | احتمال رفض المتجر |
| QA جهاز وPilot غير منفذين | P0 قرار | لا دليل على قابلية الاستخدام الحقيقية |

### 3.3 خط الأساس عند إصدار الخطة

- `git diff --check`: ناجح.
- `dart analyze lib/`: ناجح بلا مشكلات.
- `flutter test`: ناجح، 495 اختبارًا.
- `npm run test:functions`: ناجح، 11 اختبارًا.
- `npm run test:rules:emulator`: ناجح، 168 اختبارًا.

هذه لقطة محلية وليست ضمانًا للنشر أو الأداء أو الامتثال.

### 3.4 إعادة تحقق Wave 0 — 2026-07-12

- نجح الأمر `flutter pub get`&rlm;.
- نجح الأمر `dart analyze lib/` بلا مشكلات.
- نجح الأمر `flutter test` بالكامل بنتيجة `538 passing`&rlm;.
- نجح الأمر `npm run test:functions` بنتيجة `27 passing`&rlm;.
- نجح الأمر `npm run test:rules:emulator` بنتيجة `168 passing`&rlm;.

لا تغير هذه الإعادة أرقام اللقطات التاريخية في الوثائق المؤرشفة. تفاصيل مصدر كل ادعاء وحدود صلاحيته في `docs/core/10_Documentation_Claim_Audit.md`&rlm;.

---

## 4. قرارات معمارية ومنتجية ملزمة

### D-01 — Firebase هو Backend الإصدار

لا يُفتح خيار “Backend بديل” داخل V1. الكود الحالي مبني على Cloud Functions for Firebase، ولذلك يلزم ترقية مشروع `el7reef-app` إلى Blaze ثم نشر Functions وrules/indexes المتوافقة معًا. تغيير المزود الآن يعيد فتح مخاطر أكبر من فائدته.

### D-02 — Android أولًا وAPI 35

الإصدار الأول Android فقط. يجب أن يثبت الـAAB الناتج `targetSdkVersion >= 35`، وهو شرط Google Play الحالي للتطبيقات والتحديثات الجديدة. لا يُستنتج ذلك من `flutter.targetSdkVersion` فقط؛ يُفحص الـartifact النهائي.

### D-03 — HTTPS App Links وليست custom scheme وحدها

روابط المشاركة تستخدم HTTPS verified App Links مع صفحة ويب صالحة عند عدم تثبيت التطبيق. يلزم:

- `android:autoVerify="true"`.
- `assetlinks.json` على `/.well-known/assetlinks.json`.
- package name الصحيح.
- SHA-256 الخاص بـPlay App Signing، وليس upload/release key المحلي فقط.
- اختبار حالة `verified` بأوامر `adb pm get-app-links`.

لا تُستخدم Firebase Dynamic Links؛ الخدمة أُوقفت في 2025 ولا تصلح لأي تنفيذ جديد. Firebase Hosting هنا يستضيف صفحات الويب و`assetlinks.json` فقط، بينما الربط يعتمد على Android App Links مباشرة.

### D-04 — حسم الدومين قبل تنفيذ الروابط

خلال Gate قصير لا يتجاوز نصف يوم:

1. إذا كانت ملكية `el7reef.app` وDNS مؤكدة، يُستخدم الدومين الحالي ويُربط بـFirebase Hosting.
2. إذا لم تكن الملكية مؤكدة فورًا، يُستخدم نطاق المشروع الرسمي `el7reef-app.web.app` للـPilot، ثم يُنقل الدومين لاحقًا دون تغيير schema الروابط.

ممنوع شحن نصوص مشاركة تشير إلى دومين غير مستضاف أو مسار يعيد 404.

### D-05 — SharePayload عقد واحد لكل أنواع الفخر

الحقول الدنيا:

- `cardType`
- `entityType`
- `entityId`
- `tournamentId` اختياري
- `matchId` اختياري
- `targetUrl`
- `campaignSource`
- `claimUrl` اختياري
- `schemaVersion`

لا يحمل payload اسمًا أو هاتفًا أو صورة أو PII. الهوية تُحل من backend أو route بعد فتح الرابط.

### D-06 — Claim token الحالي هو المصدر الأمني

لا يُنشأ token جديد داخل نموذج البطاقة. تستخدم `ShareLinkService` وClaimCode الحاليين مع الصلاحية والانتهاء وإعادة الاستخدام الآمنة. البطاقة تحمل URL فقط؛ الكود الحساس لا يُطبع داخل الصورة كبيانات خام إلا عبر QR لنفس الرابط الآمن.

### D-07 — account deletion مساران إلزاميان

لأن التطبيق ينشئ حسابات، يلزم:

1. مسار واضح داخل التطبيق لبدء حذف الحساب والبيانات المرتبطة.
2. صفحة ويب فعالة تسمح بطلب الحذف دون إعادة تثبيت التطبيق.

أي بيانات يجب الاحتفاظ بها لأسباب أمنية يجب توثيقها وسياسة الاحتفاظ بها، لا حذفها أو إبقاؤها ضمنيًا.

### D-08 — UGC إما مضبوط أو غير عام

الأسماء والصور والبروفايلات العامة محتوى ينشئه المستخدم. قبل الإطلاق العام:

- قبول شروط الاستخدام قبل إنشاء/رفع المحتوى.
- الإبلاغ عن المستخدم والمحتوى المسيء.
- الحظر عندما تكون هويات المستخدمين العامة قابلة للتفاعل.
- مسار مراجعة واتخاذ إجراء.

إذا تعذر بناء الحد الأدنى الآمن، تُقيد الأسطح العامة في Closed Testing بدل عرض UGC عام بلا أدوات حماية.

### D-09 — لا توسع بصري قبل إغلاق الحلقة

Liquid Glass والحركة لا يشكلان workstream مستقلًا. يُسمح فقط بإصلاح قراءة أو أداء أو وصول مثبت. الأسطح التشغيلية صلبة وبسيطة، والزجاج للحظات Result/MVP/Champion.

### D-10 — قياس المشاركة لا يدّعي ما لا يعرفه النظام

يتكون funnel بطاقات المفاخرة من ستة أحداث فقط: `pride_card_viewed` و`share_started` و`share_sheet_returned` و`share_link_opened` و`claim_started_from_card` و`claim_completed_from_card`&rlm;. يعني `share_started` فتح عملية المشاركة، و`share_sheet_returned` رجوع التحكم للتطبيق فقط. لا يُسمى أي منهما `share_completed` لأن Android و`share_plus` لا يثبتان أن المستخدم أرسل المحتوى فعلًا. يحمل كل حدث metadata من `SharePayload` فقط: card/entity IDs وcampaign/schema، بلا URL أو claim code أو اسم أو صورة أو هاتف أو `actorId`&rlm;.

### D-11 — rollout قابل للإيقاف دون تعطيل النتيجة

تضاف بوابتان واضحتان فقط للقدرات الجديدة: `pride_growth_links_enabled` و`post_match_pride_hub_enabled`، بقيمة محلية افتراضية `false` حتى ينجح التحقق على البيئة المستهدفة. فشل الروابط أو الـHub يعيد المستخدم إلى مشاركة الصورة الحالية؛ لا يعطل اعتماد النتيجة أو MatchEvent أو الترتيب.

---

## 5. نموذج التنفيذ: بوابات وشرائح قيمة

### 5.1 الحالات

| الحالة | معناها |
| :--- | :--- |
| `READY` | التبعيات والقبول واضحان ويمكن البدء |
| `ACTIVE` | قيد التنفيذ مع مالك واحد |
| `VERIFY` | الكود منتهٍ وينتظر أدلة القبول |
| `DONE` | كل أدلة القبول مرفقة |
| `BLOCKED-EXTERNAL` | ينتظر OWNER أو خدمة خارجية؛ لا يمنع الأعمال المحلية المستقلة |

### 5.1.1 سجل التنفيذ الحي

يُحدّث هذا السجل فور إنهاء كل تذكرة أو موجة. كلمة `DONE` لا تُكتب إلا مع دليل قابل لإعادة الفحص؛ و`BLOCKED-EXTERNAL` لا تعني أن العمل المحلي المتوازي يتوقف.

يُلخص `docs/core/14_Execution_Progress_Report.md` تقدم الجلسات ومحاولات التحقق وترتيب العمل التالي، بينما يظل الجدول أدناه المرجع النهائي لحالة كل تذكرة.

| التذكرة | الحالة | آخر تحديث | الدليل أو الخطوة التالية |
| :--- | :---: | :--- | :--- |
| `UCP-001` | `DONE` | 2026-07-11 | `docs/core/09_Workspace_Change_Manifest.md` |
| `UCP-002` | `DONE` | 2026-07-11 | قسم الأسرار والـbinary في manifest نفسه |
| `UCP-003` | `DONE` | 2026-07-11 | checkpoints ووصفة staging دون تعديل index |
| `UCP-004` | `DONE` | 2026-07-11 | §3.4: `pub get` وanalyze وFlutter/functions/rules tests نجحت |
| `UCP-005` | `DONE` | 2026-07-11 | `docs/core/10_Documentation_Claim_Audit.md` يحدد المصدر الحي واللقطات التاريخية |
| `UCP-101` | `BLOCKED-EXTERNAL` | 2026-07-11 | `el7reef-app` يحتاج Blaze قبل تفعيل `cloudbuild.googleapis.com` و`artifactregistry.googleapis.com` |
| `UCP-102` | `BLOCKED-EXTERNAL` | 2026-07-12 | preflight Emulator كشف وأصلح فشل تحميل `runWith` مع Functions SDK v6 وواجهات Timestamp/FieldValue القديمة؛ الوظائف الست تُحمّل وتبدأ محليًا، والنشر الفعلي فقط ينتظر Blaze |
| `UCP-103` | `BLOCKED-EXTERNAL` | 2026-07-14 | نجح dry-run مستهدف: 5 بطولات مؤهلة و5 عضويات مفقودة بلا تعارض أو مصدر تالف؛ التطبيق ينتظر backup وبيانات اعتماد كتابة مخولة. راجع `docs/core/11_Tournament_Membership_Migration_Runbook.md` |
| `UCP-104` | `BLOCKED-EXTERNAL` | 2026-07-14 | قواعد وفهارس Firestore اجتازت deploy dry-run مع الحفاظ على 11 فهرس production؛ Functions preflight توقف عند شرط Blaze، ولا توجد Functions منشورة حاليًا |
| `UCP-105` | `BLOCKED-EXTERNAL` | 2026-07-12 | إعداد Gradle يدعم release signing ولا يضع السر في Git؛ `bundleRelease` توقف صراحة برسالة `Release signing is not configured` بدل إنتاج artifact غير موقع. إنشاء upload key وإدخال SHA-1/SHA-256 في Firebase مسؤولية OWNER |
| `UCP-106` | `BLOCKED-EXTERNAL` | 2026-07-11 | ينتظر تفعيل Play App Signing والحصول على بصمة Play من OWNER قبل تحديث assetlinks للإصدار |
| `UCP-107` | `BLOCKED-EXTERNAL` | 2026-07-12 | APK جديد يثبت `com.el7reef.app` وTarget SDK 36؛ AAB debug بحجم 95,357,353 بايت وبصمة SHA-256 موثقة و701 مدخل ZIP بلا تلف يثبت pipeline. `bundleRelease` وصل Gradle ثم رفض غياب signing خلال 18 ثانية كما يجب؛ signed AAB ينتظر مفتاح OWNER وPlay App Signing |
| `UCP-108` | `BLOCKED-EXTERNAL` | 2026-07-12 | ثُبت APK التشخيصي وشُغل على Samsung SM-G980F بنظام Android 13؛ نجح launch وApp Links المحلية. يبقى runtime smoke للوظائف المنشورة خلف Blaze، كما يبقى Release AAB خلف signing وPlay App Signing |
| `UCP-201` | `DONE` | 2026-07-11 | اختير `el7reef-app.web.app` لأن `el7reef.app` لا يحل DNS؛ نُشر fallback واختُبر `HTTPS /claim` بنجاح |
| `UCP-202` | `DONE` | 2026-07-11 | `SharePayload` v1 serializable وPII-safe؛ `flutter test test/domain/share_payload_test.dart` نجح |
| `UCP-203` | `VERIFY` | 2026-07-12 | على جهاز Samsung SM-G980F، أعاد `pm get-app-links` النطاق `el7reef-app.web.app: verified` وأظهر التطبيق مالكًا `VERIFIED`؛ بصمة APK التشخيصي تطابق `assetlinks.json` حرفيًا. يبقى إثبات بصمة Play للإصدار من `UCP-106` |
| `UCP-204` | `VERIFY` | 2026-07-12 | نجح فتح `tournament` باردًا خلال 3027ms، وتسليم `match?view=lineup` و`player/guestPlayer` دافئًا إلى `MainActivity` خلال 16–18ms. رابط Claim التجريبي وصل للمتحكم ثم رفض القراءة الآمنة لأن `SAFE-CODE` غير حقيقي؛ يبقى قبل/بعد login وprofile repair بكود صالح |
| `UCP-205` | `DONE` | 2026-07-11 | Result/MVP/TopScorers/Lineup تحمل `SharePayload` وURLs عامة؛ parser وHosting المنشور اختُبرا للمسارات الأربع |
| `UCP-206` | `DONE` | 2026-07-11 | MVP الضيف يولد Claim URL من سياسة `ShareLinkService` مع attribution آمن؛ اختبارات unauthorized/expiry/replay والـpayload نجحت |
| `UCP-207` | `DONE` | 2026-07-11 | الأحداث الستة من metadata `SharePayload` فقط موصولة بالمشاركة وفتح Claim/بدئه/اكتماله؛ اختبارات analytics/attribution نجحت |
| `UCP-208` | `BLOCKED-EXTERNAL` | 2026-07-12 | جانب «مثبت» يفتح التطبيق فعليًا، وفشل `SAFE-CODE` الآمن أثبت وصول الرابط للمتحكم لا وجود claim صالح. إغلاق E2E يحتاج Claim حقيقيًا وحساب اختبار OWNER، وتجربة غير مثبت، وتوقيع/بصمة الإصدار |
| `UCP-209` | `DONE` | 2026-07-12 | بوابتا النمو والـHub افتراضيهما `false` محليًا وفي Remote Config المنشور؛ اختبارات flags وfallback تثبت أن اعتماد النتيجة ومشاركة الصورة القديمة لا يتعطلان |
| `UCP-301` | `VERIFY` | 2026-07-11 | Post-Match Pride Hub يشارك Result وMVP مباشرة ويصل للهدافين من موضع واحد؛ اختبار callbacks أخضر، ويبقى قياس أول share ≤15 ثانية على Android |
| `UCP-302` | `DONE` | 2026-07-11 | `completeTournament()` يستدعي Celebration مباشرة؛ اختبار lifecycle/controller يثبت الاستدعاء، واختبار الواجهة يثبت الرجوع للبطولة |
| `UCP-303` | `DONE` | 2026-07-11 | Player Card للمسجل والضيف مع profile/claim target آمن، وصورة/initials fallback؛ اختبارات payload والبطاقة خضراء |
| `UCP-304` | `DONE` | 2026-07-11 | Team Card للمسجل والضيف مع شعار/بطولة/رابط فريق؛ parser وHosting fallback لمساري الفريق اختُبرا محليًا ثم نُشرا ونجح HTTPS smoke |
| `UCP-305` | `DONE` | 2026-07-11 | MVP وTop Scorers يستخدمان الصور عند توفرها وinitials عند الفشل؛ مهلة جلب الهوية ثانيتان واختبار الشبكة البطيئة أخضر |
| `UCP-306` | `DONE` | 2026-07-11 | منتقي فعلي لـ`4:5` و`9:16` موصول بنقاط المشاركة؛ Goldens عربية `360×450` و`360×640` بأسماء طويلة وtext scale 200% خضراء |
| `UCP-307` | `VERIFY` | 2026-07-11 | مهلة التحضير ثانيتان وDialog route مملوك لمسار المشاركة؛ اختبار العودة يثبت عدم pop للشاشة، ويبقى تحقق WhatsApp على جهاز |
| `UCP-401` | `DONE` | 2026-07-11 | Score Submit أصبح أربع خطوات مستقلة: النتيجة ← الهدافون ← MVP ← المراجعة؛ اختبار الواجهة يمر عبر الأربع حتى الاعتماد |
| `UCP-402` | `DONE` | 2026-07-11 | خطوة الهدافين تعرض رسالة واحدة حية للمتبقي غير المنسوب بدل ملخصين مكررين؛ اختبار `متبقي 3 أهداف غير منسوبة` أخضر |
| `UCP-403` | `DONE` | 2026-07-11 | مسودة `SharedPreferences` مع schema وبصمة حسب `matchId` تحفظ score/scorers/MVP وتستعاد بعد controller جديد وتُمسح بعد submit؛ اختبارات store/controller خضراء |
| `UCP-404` | `DONE` | 2026-07-11 | `PopScope` وتحذير dirty state مع حذف صريح؛ بصمة المصدر تمنع stale submit، وFirestore transaction يرفض تغير status المتزامن؛ اختبارات الخروج والتعارض خضراء |
| `UCP-405` | `DONE` | 2026-07-11 | لوحة المنظم تقدم المباراة `live` أو `pendingReview` كإجراء «اعمل الآن» قبل إعداد المراحل وتفتح Route النتيجة الحقيقي؛ اختبار التنقل أخضر |
| `UCP-406` | `VERIFY` | 2026-07-11 | أزرار العد والرجوع 48px مع Semantics، رحلة 360px عند text scale 200% بلا overflow أو raw enum؛ يبقى TalkBack يدويًا على Android |
| `UCP-407` | `VERIFY` | 2026-07-11 | الشاشات التشغيلية لا تستخدم `BackdropFilter` واختبار 360px/200% أخضر؛ يبقى قياس jank على جهاز Android متوسط |
| `UCP-501` | `VERIFY` | 2026-07-11 | جرد Auth/Firestore/Storage/Crashlytics/guest PII ومصفوفة الاحتفاظ في `docs/core/12_Data_Inventory_Retention_And_Data_Safety.md`؛ ينتظر اعتماد OWNER للمدد وبيانات الزوار |
| `UCP-502` | `VERIFY` | 2026-07-12 | re-auth + كتابة «حذف» + callable idempotent ومجهّل + failure recovery؛ Auth/Firestore/Storage Emulator أثبت حذف الحساب والصورة والعلاقات وتجهيل audit/report واكتمال الطلب. التنفيذ المحلي مكتمل، والنشر الفعلي فقط ينتظر Blaze |
| `UCP-503` | `VERIFY` | 2026-07-12 | نُشرت `/delete-account` وتعيد HTTPS 200 وRTL دون اعتماد على التطبيق وبها طلب بريد موثق؛ يبقى ربط URL داخل Play Console بواسطة OWNER |
| `UCP-504` | `VERIFY` | 2026-07-12 | سياسة عربية داخل التطبيق والويب مطابقة للجرد؛ `/privacy` منشورة وتعيد HTTPS 200 وRTL، ويبقى اعتماد OWNER القانوني |
| `UCP-505` | `VERIFY` | 2026-07-11 | worksheet لكل فئة بيانات وSDK في `docs/core/12_Data_Inventory_Retention_And_Data_Safety.md`؛ الإرسال النهائي ينتظر فحص AAB وOWNER |
| `UCP-506` | `VERIFY` | 2026-07-12 | موافقة صريحة وقواعد مجتمع عامة + report/block منفصلان؛ Emulator أثبت auth وكتابات report/block/audit، وأغلق انتحال `actorId` وحد payload؛ 27 اختبار Functions خضراء، والنشر وتعيين المراجع خارجيان |
| `UCP-507` | `DONE` | 2026-07-12 | `flutter pub get` أزال 32 اعتمادًا غير مستخدم، وبُني APK جديد؛ Manifest النهائي بلا `POST_NOTIFICATIONS` أو موقع أو تخزين عام، والكاميرا فقط مع تفسير الرفض وإعادة المحاولة. `c2dm.RECEIVE` انتقالية من `firebase-iid` ولا تعرض runtime prompt |
| `UCP-508` | `BLOCKED-EXTERNAL` | 2026-07-11 | `docs/core/13_Play_Review_And_Moderation_Runbook.md` يحوي الخطوات والروابط؛ حساب المراجع وبطولة/Claim ومالك الاستجابة مطلوبة من OWNER |
| `UCP-509` | `BLOCKED-EXTERNAL` | 2026-07-11 | Closed Testing ينتظر Blaze وrelease signing وPlay App Signing وAAB وجهاز Android وبيانات OWNER |
| `Wave 0` | `DONE` | 2026-07-11 | manifest، فحص الأسرار، checkpoints، baseline، وتدقيق الوثائق مكتملون |
| `Wave 1` | `BLOCKED-EXTERNAL` | 2026-07-12 | العمل وruntime smoke المحليان وlaunch على جهاز فعلي مكتملة؛ النشر الإنتاجي وrelease signing وAAB النهائي خلف Blaze وADC وOWNER |
| `Wave 2` | `VERIFY` | 2026-07-12 | App Links الخاصة بـdebug QA أصبحت verified على جهاز فعلي، ونجح cold/warm delivery؛ يبقى Claim حقيقي قبل/بعد login وتجربة غير مثبت وبصمة Play |
| `Wave 3` | `VERIFY` | 2026-07-11 | الحزمة البرمجية والروابط وGoldens مكتملة؛ يبقى قياس ≤15 ثانية وعودة WhatsApp على Android لإغلاق البوابة |
| `Wave 4` | `VERIFY` | 2026-07-11 | UCP-401–405 مكتملة؛ بوابة الاختبارات 69/69 خضراء، ويبقى TalkBack وقياس الأداء على جهاز متوسط لـ406–407 |
| `Wave 5` | `BLOCKED-EXTERNAL` | 2026-07-12 | الاختبارات وAPK وManifest وHosting والوثائق مكتملة محليًا أو منشورة؛ Functions وPlay Console وقرارات OWNER وAAB Release والجهاز هي الحواجز الخارجية |
| `Wave 6` | `BLOCKED-EXTERNAL` | 2026-07-12 | الجهاز متاح، لكن البدء الفعلي ينتظر Release AAB وحسابات المراجع والـPilot وبيانات بطولة فعلية |

### 5.2 Definition of Ready

لا تبدأ التذكرة إلا إذا كان لها:

1. هدف مستخدم واحد.
2. ملفات أو boundaries متوقعة.
3. تبعيات معروفة.
4. معايير قبول آلية ويدوية.
5. مالك واحد.
6. قرار واضح لما هو خارج نطاقها.

### 5.3 Definition of Done

لا تُغلق التذكرة إلا بعد:

1. `dart format` للملفات المتأثرة.
2. `git diff --check`.
3. تحليل واختبار مركزين ثم البوابة الأوسع المناسبة.
4. تحديث الوثائق عند تغير السلوك أو التشغيل.
5. عدم إضافة زر ميت أو “قريبًا” داخل core flow.
6. تسجيل دليل QA اليدوي إذا كانت التذكرة بصرية أو مرتبطة بجهاز/رابط.

---

## 6. موجات التنفيذ

> التقديرات أدلة تخطيط وليست مواعيد تعاقدية. تعتمد على شخص هندسي واحد، وتُعاد معايرتها بعد Wave 0.

### Wave 0 — تثبيت مساحة العمل

**المدة الإرشادية:** 1–2 يوم  
**المالك:** ENG  
**الهدف:** تحويل الحزمة الحالية إلى checkpoints قابلة للمراجعة والرجوع.

| ID | المهمة | الحجم | المخرج |
| :--- | :--- | :---: | :--- |
| `UCP-001` | إنشاء manifest لكل ملف متغير وربطه بمجموعة عمل | S | جدول: path، السبب، المجموعة، الاختبار |
| `UCP-002` | فحص الأسرار والملفات الثنائية والمخرجات المحلية | S | تقرير keep/archive/delete بدون حذف مجهول |
| `UCP-003` | تقسيم الحزمة إلى checkpoints منطقية | M | Firebase/Auth، Backend، Tournament، UX، Docs |
| `UCP-004` | إعادة تشغيل baseline الكامل بعد التقسيم | S | سجل أوامر ونتائج محدث |
| `UCP-005` | مراجعة الادعاءات القديمة في docs | S | لا أرقام أو حالات متعارضة مع الكود |

**بوابة W0:**

- كل ملف متغير مفسر.
- لا secret إنتاجي داخل Git.
- لا commit ضخم غير قابل للمراجعة.
- baseline أخضر بعد التقسيم.

### Wave 1 — منصة قابلة للنشر

**المدة الإرشادية:** 2–4 أيام عمل + وقت الموافقات الخارجية  
**الملاك:** OWNER + ENG + QA  
**يمكن تنفيذها بالتوازي مع تصميم Wave 2.**

| ID | المهمة | المالك | التبعية | القبول |
| :--- | :--- | :---: | :--- | :--- |
| `UCP-101` | ترقية Firebase إلى Blaze وضبط budget alerts | OWNER | لا شيء | Functions deployment مسموح ومراقب |
| `UCP-102` | Deploy preflight للـFunctions/rules/indexes | ENG | 101 | dry-run/validation بلا أخطاء |
| `UCP-103` | migration idempotent لـ`tournamentMemberships` | ENG | W0 | dry-run + rerun لا يكرر أو يتلف |
| `UCP-104` | نشر Functions وrules/indexes كتغيير متوافق | ENG | 102، 103 | smoke test على المشروع المستهدف |
| `UCP-105` | إنشاء release/upload signing خارج Git | OWNER + ENG | لا شيء | SHA-1/SHA-256 مسجلان في Firebase |
| `UCP-106` | تفعيل Play App Signing وتسجيل بصمته | OWNER | 105 | بصمة Play متاحة لـassetlinks |
| `UCP-107` | بناء AAB وفحص target API/package/project | ENG + QA | 104، 105 | signed AAB، API 35+، package صحيح |
| `UCP-108` | runtime smoke للـAuth والنتائج والضيف | QA | 104، 107 | Google login، بطولاتي، submit/approve، guest goal/MVP |

**بوابة W1:** النتيجة الحساسة تعمل على Firebase الفعلي بلا local fallback، والـAAB صالح للرفع.

#### Runbook النشر والرجوع

1. تسجيل نسخ Functions والقواعد والفهارس المنشورة قبل التغيير.
2. أخذ export/backup مناسب للبيانات قبل migration.
3. تشغيل migration في dry-run وإرفاق counts قبل/بعد؛ إذا لم توجد بيانات قديمة، تُغلق كتقرير no-op بدل تشغيل كتابة غير لازمة.
4. نشر Functions أولًا إذا كانت backward compatible، ثم rules/indexes، ثم تشغيل smoke؛ أو استخدام نافذة نشر واحدة موثقة إن كانت التبعيات متبادلة.
5. عند فشل smoke: إيقاف الـfeature gate المتأثر، إعادة Functions/rules للنسخة السابقة، وعدم محاولة “إصلاح مباشر” على بيانات الإنتاج.
6. توثيق owner ووقت البداية والنهاية ونتيجة كل خطوة.

### Wave 2 — أول Vertical Slice للنمو: MVP ضيف ← Claim

**المدة الإرشادية:** 4–6 أيام  
**المالك:** ENG، مع OWNER للدومين  
**الهدف:** إثبات أصغر حلقة نمو كاملة قبل بناء بطاقات جديدة.

| ID | المهمة | الحجم | التبعية | القبول |
| :--- | :--- | :---: | :--- | :--- |
| `UCP-201` | حسم الدومين واستضافة web fallback | S | OWNER | كل URL يعيد صفحة صالحة بلا 404 |
| `UCP-202` | تعريف SharePayload/versioning | S | W0 | unit tests للـserialization والخصوصية |
| `UCP-203` | إعداد Android App Links وassetlinks | M | 201، 106 | domain state = verified على جهاز |
| `UCP-204` | استقبال cold/warm links وربطها بـGetX/PendingDeepLink | M | 203 | قبل/بعد login وprofile repair |
| `UCP-205` | ربط البطاقات الأربع الحالية بـSharePayload | M | 202، 204 | Result/MVP/TopScorers/Lineup تملك target صالحًا |
| `UCP-206` | Claim URL آمن للـMVP الضيف | M | 205 | صلاحية، expiry، replay، unauthorized tests |
| `UCP-207` | funnel analytics بدون PII | S | 202 | الأحداث الستة مع card/entity IDs وcampaign/schema فقط |
| `UCP-208` | E2E: share MVP guest ثم claim | M | 206، 207 | جهاز مثبت وغير مثبت، قبل/بعد login |
| `UCP-209` | rollout gates وfallback للصورة الحالية | S | 205 | تعطيل الروابط/Hub لا يمنع اعتماد النتيجة أو مشاركة الصورة |

**بوابة W2:** لاعب ضيف يفتح رابط MVP المشارك، يصل لهويته الصحيحة، ويبدأ Claim دون طلب رابط يدوي جديد.

### Wave 3 — لحظة الفخر وحزمة البطاقات

**المدة الإرشادية:** 6–9 أيام  
**الملاك:** ENG + DESIGN + QA  
**الهدف:** تقليل الزمن من اعتماد النتيجة إلى أول مشاركة، وإغلاق بطاقات V1.

#### الترتيب الصحيح داخل الموجة

1. Pride Hub فوق البطاقات الحالية.
2. Champion Card لأنها نهاية البطولة الموعودة.
3. Player Card لأنها تحمل الهوية والـClaim.
4. Team Card لأنها تكمل حزمة V1 ولا تعطل الحلقة الفردية.

| ID | المهمة | القبول الأساسي |
| :--- | :--- |
| `UCP-301` | Post-Match Pride Hub | Result وMVP وTop Scorers من موضع واحد، أول share ≤15 ثانية |
| `UCP-302` | Champion Celebration + Card | تظهر مباشرة بعد `completeTournament()` وتدعم الرجوع |
| `UCP-303` | Player Card | profile/claim target صحيح للمسجل والضيف |
| `UCP-304` | Team Card | الفريق والشعار والبطولة ورابط الفريق الصحيح |
| `UCP-305` | تحسين MVP/TopScorers | صورة عند توفرها، initials fallback، لا انتظار شبكة غير محدود |
| `UCP-306` | نسب 9:16 و4:5 | golden/screenshots بأسماء عربية طويلة وtext scale مناسب |
| `UCP-307` | capture/share robustness | اتصال بطيء، صورة فاشلة، عودة من WhatsApp بلا dialog عالق |

**بوابة W3:** كل لحظة فخر الإلزامية في V1 لها بطاقة مفهومة خلال ثانيتين ورابط صالح.

### Wave 4 — تشغيل المنظم وتسجيل النتيجة

**المدة الإرشادية:** 5–7 أيام  
**الملاك:** ENG + DESIGN + QA  
**يمكن بدء تصميمها أثناء Wave 3، لكن لا تُدمج قبل استقرار Pride Hub.**

| ID | المهمة | القبول الأساسي |
| :--- | :--- |
| `UCP-401` | Score Submit من أربع خطوات | score ← scorers ← MVP ← review |
| `UCP-402` | goal attribution مختصر | المتبقي غير المنسوب واضح دون تكرار قائمتين كاملتين |
| `UCP-403` | draft محلي حسب matchId | استعادة بعد الخروج وإغلاق العملية، ومسح بعد نجاح submit |
| `UCP-404` | حماية الخروج والتعارض | تحذير عند dirty state وعدم الكتابة فوق نتيجة أحدث |
| `UCP-405` | Organizer “اعمل الآن” | المباراة الحية/النتيجة المعلقة أولًا، ثم الإجراء التالي فقط |
| `UCP-406` | وصول ومصطلحات | 48×48، Semantics، TalkBack، text scale 200%، عربية بلا raw enums |
| `UCP-407` | اختبار أداء جهاز متوسط | لا jank مانع ولا blur ثقيل في الشاشات التشغيلية |

**بوابة W4:** منظم بيد واحدة يسجل خمسة أهداف وMVP ويفتح المشاركة خلال أقل من دقيقة.

### Wave 5 — امتثال Google Play والإصدار المغلق

**المدة الإرشادية:** 4–7 أيام، بالتوازي مع Waves 2–4  
**الملاك:** OWNER + ENG + QA  
**الهدف:** جعل الإصدار قابلًا للمراجعة، لا مجرد قابل للبناء.

| ID | المهمة | المالك | القبول |
| :--- | :--- | :---: | :--- |
| `UCP-501` | جرد البيانات وretention matrix | OWNER + ENG | Auth/Firestore/Storage/Analytics/guest PII موثقة |
| `UCP-502` | حذف الحساب داخل التطبيق | ENG | re-auth، confirmation، idempotency، failure recovery |
| `UCP-503` | صفحة ويب لطلب حذف الحساب | OWNER + ENG | تعمل بدون التطبيق ومربوطة في Play Console |
| `UCP-504` | Privacy Policy داخل التطبيق والويب | OWNER | URL فعالة ومطابقة للسلوك الفعلي |
| `UCP-505` | Data Safety worksheet | OWNER + ENG | كل SDK ونوع بيانات وغرضه مراجع |
| `UCP-506` | شروط UGC والإبلاغ والحظر | OWNER + ENG | report content/user + block حيث يلزم + review path |
| `UCP-507` | مراجعة permissions | QA | camera/photos denial وprominent disclosure عند الحاجة |
| `UCP-508` | reviewer package | OWNER + QA | حساب اختبار، خطوات login/QR/claim، سياسة، بيانات تواصل |
| `UCP-509` | Closed Testing release | OWNER + QA | لا crash/blocker وسياسة Play كاملة |

**بوابة W5:** لا رابط سياسة ميت، حذف الحساب قابل للطلب داخل التطبيق والويب، Data Safety مطابقة، ونسخة closed testing مقبولة.

### Wave 6 — QA شامل وPilot

**المدة الإرشادية:** 3 أيام QA + بطولة فعلية + دورة إصلاح  
**الملاك:** QA + OWNER + ENG  
**الهدف:** استبدال الافتراضات بأدلة استخدام حقيقية.

#### مصفوفة البطولة

- 4–8 فرق.
- فريق مسجل واحد على الأقل وفريق ضيف واحد على الأقل.
- أغلبية لاعبين ضيوف.
- مرحلة مجموعات ثم إقصاء إن كان الحجم يسمح.
- مباراة دون تشكيل ومباراة بتشكيل.
- هدف وMVP للاعب ضيف ثم Claim من البطاقة.

#### القياسات

| المؤشر | الهدف الأولي |
| :--- | :---: |
| إكمال إنشاء بطولة بلا مساعدة | ≥90% |
| مباراة تعطلت بسبب غياب التشكيلة | 0 |
| اعتماد النتيجة إلى أول Share Sheet | ≤15 ثانية |
| النتائج التي نتج عنها مشاركة واحدة | ≥60% |
| الروابط التي فتحت كيانًا صحيحًا | 100% من عينة QA |
| Claim مكتمل من بطاقة ضيف | حالة ناجحة واحدة على الأقل دون تدخل هندسي |
| أهداف غير منسوبة بلا قصد | 0 في سيناريو QA المنضبط |
| crashes أو data-loss blockers | 0 |

#### قرار ما بعد الـPilot

- `GO`: كل P0 أخضر، لا data loss، والسياسات مكتملة.
- `GO WITH FIXES`: P1 UX فقط مع owner وموعد قريب، ولا تؤثر في الثقة أو البيانات.
- `NO-GO`: فشل Claim، النتيجة، App Links، signing، account deletion، أو أمان البيانات.

**بوابة W6:** تقرير Pilot مكتمل، كل P0 أخضر، ولا data loss أو crash blocker، وقرار `GO` موقّع من OWNER وQA.

---

## 7. خريطة التبعيات والمسار الحرج

```text
W0 Workspace
├── W1 Backend Deploy ───────────────┐
├── W2 Share/App Links ──> W3 Pride ├──> W6 Pilot
├── W5 Store Compliance ─────────────┤
└── W4 Score UX (بعد ثبات Pride Hub) ┘
```

### المسار الحرج

`W0 → Blaze/Signing/Domain → App Links + Guest MVP Claim → Pride Hub → Closed Testing → Pilot`

### ما يمكن تنفيذه بالتوازي

- OWNER يبدأ Blaze والدومين وPlay signing أثناء W0.
- Data inventory والسياسات تبدأ أثناء W2.
- تصميم Pride Hub وScore Wizard يبدأ مبكرًا، لكن الدمج يتبع بوابات التبعيات.
- migration تُطور وتُختبر قبل موعد النشر، ولا تنتظر البطاقات.

---

## 8. ما لن يُنفذ في V1

1. Fantasy أو Guest Fantasy أو توسيع market/settlement.
2. Social feed متقدم أو chat أو friends expansion.
3. Unified search عام أو join requests أو notification inbox كامل.
4. هوية لاعب عميقة: reputation، playing style، تاريخ كامل، أو ratings معقدة.
5. iOS قبل Android Pilot وFirebase config رسمي للمشروع نفسه.
6. Maps أو pitch booking أو external match-data providers.
7. Upcoming Match Card قبل اكتمال حزمة الفخر الأساسية.
8. Admin dashboard عام أو أدوات صيانة واسعة.
9. إعادة بناء MatchEvent أو تغيير أسماء collections.
10. حذف كود Fantasy/Social backend؛ يظل مخفيًا خلف feature gates.
11. تعميم Liquid Glass أو إضافة animations لمجرد التجميل.
12. أي زر أو صفحة لا تملك خدمة حقيقية ومعيار قبول.

طلبات هذه القائمة تُنقل إلى V1.1 ولا تُضاف “سريعًا” داخل موجة حالية.

---

## 9. مصفوفة التحقق النهائية

| المجال | آلي | يدوي/خارجي |
| :--- | :--- | :--- |
| Workspace | `git diff --check`، secret scan، targeted tests | مراجعة checkpoints |
| Flutter | `dart analyze lib/`، `flutter test` | جهاز صغير، text 200%، TalkBack |
| Functions | `npm run test:functions` | deploy + callable smoke |
| Firestore | `npm run test:rules:emulator` | deployed rules behavior |
| Migration | dry-run + rerun tests | عينة بيانات staging/production backup |
| App Links | route/parser tests | `adb pm get-app-links` = verified، installed/uninstalled |
| Share/Claim | payload/expiry/replay tests | WhatsApp، cold/warm start، login/repair |
| Cards | widget/golden/screenshots | أسماء طويلة، صورة فاشلة، شبكة بطيئة |
| Score Draft | persistence/conflict tests | قتل التطبيق والعودة |
| Release | build checks | signed AAB، Play pre-launch report |
| Policies | link checks | Play Console forms ومراجعة OWNER |
| Pilot | analytics integrity | تقرير زمني وملاحظات ميدانية |

### 9.1 الجدول الزمني الإرشادي

| الأسبوع | الهدف الرئيسي | الأعمال المتوازية |
| :---: | :--- | :--- |
| 1 | W0 وتثبيت baseline | Blaze، الدومين، Play Console، data inventory |
| 2 | W1 deploy readiness + بداية W2 | policies وrelease signing |
| 3 | إغلاق MVP Guest Claim slice | تصميم Pride Hub وScore Wizard |
| 4 | W3 Pride Hub وChampion/Player | W5 deletion/privacy/UGC |
| 5 | Team Card + W4 Score/Organizer | closed testing preparation |
| 6 | QA شامل وClosed Testing | إصلاح blockers فقط |
| 7 | Pilot وقرار GO/NO-GO | دورة إصلاح واحدة عند الحاجة |

إذا تأخر Blaze أو الدومين، تستمر الأعمال المحلية المستقلة، لكن لا يُعلن تاريخ Pilot قبل إزالة العائق الخارجي.

### أوامر بوابة الإصدار

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
dart analyze lib/
flutter test
npm run test:functions
npm run test:rules:emulator
flutter build appbundle --release
```

تضاف اختبارات مركزة قبل هذه الحزمة، ولا تُستخدم الحزمة الكاملة بدل الاختبارات المركزة أثناء التطوير.

---

## 10. سجل المخاطر

| الخطر | الاحتمال | الأثر | الاستجابة | إشارة التصعيد |
| :--- | :---: | :---: | :--- | :--- |
| نشر rules قبل Functions | متوسط | حرج | نشر متزامن وخطة rollback | فشل callable أو PERMISSION_DENIED |
| worktree كبير يخلط تغييرات | مرتفع | مرتفع | W0/checkpoints وعدم reset | ملف بلا سبب أو اختبار |
| App Links غير verified | متوسط | مرتفع | Hosting + assetlinks + Play SHA | domain state ليس `verified` |
| Claim URL يُسرب PII أو يعاد استخدامه خطأ | منخفض/متوسط | حرج | codes الحالية + expiry/replay tests | payload يحتوي بيانات شخصية |
| migration تخفي بطولات قديمة | متوسط | مرتفع | dry-run، backup، idempotency | فرق counts قبل/بعد |
| صورة/blur يعطل capture | متوسط | متوسط | initials fallback وexportMode صلب | صورة فارغة أو dialog عالق |
| account deletion يحذف تاريخ بطولة مطلوب | متوسط | حرج | retention/anonymization policy | علاقات إحصائية مكسورة |
| UGC بلا moderation | متوسط | مرتفع | report/block أو تقييد السطح العام | محتوى عام بلا إجراء |
| Pilot يثبت UX بطيئًا | متوسط | متوسط | إصلاح P1 قبل GO | زمن المشاركة أو الإدخال يفشل الهدف |
| scope creep إلى Fantasy/Social | مرتفع | مرتفع | قائمة “لن يُنفذ” وChange Control | تذكرة بلا أثر على الحلقة |

---

## 11. إدارة التغيير والتقارير

### 11.1 Change Control

أي بند جديد يجب أن يجيب:

1. أي KPI أو Release Gate يحسن؟
2. لماذا لا ينتظر V1.1؟
3. ما الذي سيخرج من النطاق مقابله؟
4. ما أثره على البيانات والقواعد والـPilot؟

إذا لم توجد إجابات قابلة للقياس، يُرفض البند من V1.

### 11.2 تقرير نهاية كل موجة

1. ما أُنجز مع IDs.
2. الملفات المتغيرة.
3. السلوك والـUX المتغيران.
4. الاختبارات والأوامر ونتائجها.
5. الأدلة اليدوية أو روابط البيئة.
6. المخاطر المفتوحة.
7. قرار البوابة: أخضر/أصفر/أحمر.
8. أول تذكرة `READY` في الموجة التالية.

### 11.3 قاعدة الإغلاق

لا تُغلق موجة بعدد التذاكر المنتهية؛ تُغلق فقط عندما تتحقق بوابة الخروج بأدلة قابلة لإعادة الفحص.

---

## 12. تعريف اكتمال V1

يكتمل V1 فقط عندما تثبت الأدلة الحالية أن:

1. مساحة العمل مقسمة ومراجعة ولا تحتوي أسرار إنتاج أو ملفات مجهولة.
2. Functions وrules/indexes منشورة ومتوافقة على `el7reef-app`.
3. migration القديمة آمنة وقابلة لإعادة التشغيل.
4. signed AAB يستهدف API 35 أو أعلى ويستخدم Play App Signing.
5. دورة مختلطة كاملة تعمل على جهاز Android حقيقي.
6. اللاعب الضيف يحصل على هدف وMVP ثم يبدأ Claim من بطاقة مشاركة.
7. Result وMVP وTop Scorers وChampion وPlayer وTeam لها مسارات مشاركة صالحة؛ Lineup تبقى اختيارية ومدعومة.
8. Score Submit يحفظ draft، يمنع الفقد، ويعمل بيد واحدة ضمن الهدف الزمني.
9. App Links verified وتعمل في cold/warm start ومع التطبيق مثبتًا وغير مثبت.
10. حذف الحساب داخل التطبيق وصفحة الويب والسياسة وData Safety مكتملة.
11. لا توجد core buttons ميتة أو Fantasy/Social leaks.
12. ينجح Pilot بلا data loss أو blocker، ويصدر قرار `GO` موثق.

أي حالة أقل من ذلك هي تقدم مرحلي وليست إصدارًا مكتملًا.

---

## 13. أول سبع خطوات تبدأ الآن

1. `UCP-001`: manifest التغييرات الحالية.
2. `UCP-002`: فحص الأسرار والملفات الثنائية.
3. `OWNER`: ترقية Blaze وتأكيد ملكية `el7reef.app` وPlay Console.
4. `UCP-003`: تقسيم checkpoints وإعادة baseline.
5. `UCP-103`: تصميم migration لـ`tournamentMemberships`.
6. `UCP-202`: تثبيت SharePayload بعقد واختبارات.
7. `UCP-501`: بدء data inventory بالتوازي.

لا يبدأ بناء Champion Card قبل نجاح عقد SharePayload، ولا يبدأ Pilot قبل W1 وW2 وW5.

---

## 14. المراجع الرسمية المستخدمة في قرارات الإطلاق

- [متطلبات حذف الحساب في Google Play](https://support.google.com/googleplay/android-developer/answer/13327111)
- [متطلبات Target API في Google Play](https://developer.android.com/google/play/requirements/target-sdk)
- [مقدمة Android App Links](https://developer.android.com/training/app-links/about)
- [إعداد والتحقق من assetlinks.json](https://developer.android.com/training/app-links/configure-assetlinks)
- [اختبار تحقق App Links](https://developer.android.com/training/app-links/verify-applinks)
- [متطلبات Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469)
- [سياسة المحتوى الذي ينشئه المستخدم](https://support.google.com/googleplay/android-developer/answer/9876937)
- [إدارة Cloud Functions وخطة Blaze](https://firebase.google.com/docs/functions/manage-functions)
- [Firebase Hosting والدومينات](https://firebase.google.com/docs/hosting)
- [إيقاف Firebase Dynamic Links](https://firebase.google.com/support/dynamic-links-faq)

</div>
