<div dir="rtl">

# خطة الإغلاق الأمني وإطلاق الحريف V1

**الإصدار:** 3.0

**الحالة:** `ACTIVE` — المصدر التنفيذي الوحيد لإكمال V1

**تاريخ خط الأساس:** 28 يوليو 2026

**المنتج:** Tournament Ego MVP

**المنصة:** Android فقط؛ لا أعمال أو اختبارات أو إعدادات تخص iOS

**Firebase:** المشروع `el7reef-app`&rlm;، قاعدة `(default)`&rlm;، إصدار Standard، المنطقة `nam5`&rlm;

---

## 1. القرار التنفيذي

الإصدار غير جاهز للنشر رغم اكتمال أجزاء كبيرة من تجربة البطولة والتصميم. بوابة الإصدار الجديدة هي **سلامة السلطة والبيانات أولًا**؛ فلا تُنشر Cloud Functions الحالية، ولا يبدأ Closed Testing، قبل إغلاق ثغرات التدقيق والتصويت والنزاعات وبيانات اللاعبين وإعادة CI إلى الحالة الخضراء.

تظل حلقة المنتج المستهدفة كما هي:

> إنشاء بطولة ← فرق ولاعبون مسجلون وضيوف ← مباراة وتشكيلة اختيارية ← أهداف وMVP وترجيح ← اعتماد ذري ← مجموعات وشجرة ← Pride Share ← Claim ← عودة إلى البطولة.

ترتيب التنفيذ الملزم:

`احتواء فوري → Backend موثوق → فصل الملف العام والخاص → UX المتبقي وCI → نشر Firebase → AAB وClosed Testing → Pilot وتدرج الإطلاق`

لا تدخل Fantasy أو Social المتقدم أو iOS أو إعادة تصميم بصرية عامة جديدة في هذه الخطة.

---

## 2. الحقيقة الحالية ومصادر العمل

### 2.1 الحالة المثبتة في 28 يوليو 2026

| البند | الحالة المثبتة | القرار |
| :--- | :--- | :--- |
| Git | الفرع `main`&rlm;، الرأس `8799959`&rlm;، وworking tree نظيف قبل إنشاء هذه الخطة | خط أساس التنفيذ |
| Firestore | `(default)` Standard في `nam5` داخل `el7reef-app`&rlm; | لا تغيير للاسم أو المنطقة أو الإصدار |
| Cloud Functions | `functions:list` أعاد قائمة فارغة | الـcallable غير الآمنة ليست مكشوفة إنتاجيًا الآن، لكنها تمنع أي نشر قادم |
| Android signing | لا يوجد `android/key.properties` ولا upload keystore محلي | Release AAB ينتظر OWNER |
| Android QA | AVD باسم `Pixel_4a_API_35_Lite` موجود، ولا يوجد جهاز Android متصل وقت المراجعة | يُعاد تشغيله عند موجة QA |
| CI | root lockfile موجود محليًا لكنه ignored وغير متتبع | clean checkout يفشل قبل الاختبارات |
| Hotspots | البوابة تفشل في 7 ملفات، لا 6 | ادعاء الخطة القديمة أصبح قديمًا |
| الاعتماديات | `firebase-admin 13.10.0` و`firebase-functions 6.6.0` و`fast-xml-parser 5.9.3`&rlm; | يلزم audit متصل جديد قبل الحكم النهائي |

### 2.2 تصنيف الخطط الموجودة

| المصدر | التصنيف من الآن | ما يُحفظ منه |
| :--- | :--- | :--- |
| الوثيقة `08_Unified_V1_Completion_And_Workspace_Plan.md`&rlm; | `SUPERSEDED` | القرارات المعمارية وأدلة التنفيذ السابقة فقط |
| التقرير `14_Execution_Progress_Report.md`&rlm; | لقطة تاريخية حتى 14 يوليو | الأدلة القديمة، لا أعداد التذاكر الحالية |
| الخطة `15_Team_Lineup_Ultimate_Squad_Redesign_Plan.md`&rlm; | `DONE` مع بوابة regression | لا تُعاد كمشروع تصميم جديد |
| الخطة `16_Architecture_Technical_Debt_Remediation_Tasks.md`&rlm; | مكتملة محليًا جزئيًا، و`OPS-001` مفتوحة | نشر Functions وsmoke فقط بعد الأمن |
| ملفات `05` و`06` و`07` و`tournament_tos_*` و`implementation_backlog*`&rlm; | تاريخية/مستبدلة | تُستخدم كمرجع ولا تُنفذ كـbacklog موازية |
| Runbooks الخصوصية وPlay | قوائم قبول تابعة لهذه الخطة | تُغلق داخل موجة الإصدار فقط |

أي `Todo` داخل خطة مستبدلة لا يصبح عملًا مطلوبًا تلقائيًا. يُنفذ فقط ما يحمل معرفًا في هذه الوثيقة.

---

## 3. حكم التقرير الأمني

مرجع التدقيق القابل للآلة: `docs/audits/2026-07-28_v1_security_completion_audit.json`&rlm;. نتيجة النطاق الحالي **1/5** بسبب تسريب بيانات شخصية موثق وغياب سلطة موثوقة لعدد من العمليات.

| المعرف | الحكم | الخطورة | الملاحظة الدقيقة |
| :--- | :---: | :---: | :--- |
| `SEC-AUDIT-001` | صحيح في الكود المرشح | حرج | `recordAuditEvent` يثبت هوية الفاعل والوقت فقط، لكنه يثق في الكيان والإجراء والـpayload. لا توجد Functions منشورة الآن، لذلك الخطر حاجز نشر مباشر لا callable إنتاجية عاملة حاليًا |
| `SEC-VOTE-001` | صحيح | عالٍ | transaction العميل لا يمكن أن تكتمل لأن rules تمنع تحديث `fanVotingSessions`&rlm;؛ كما أن إنشاء `userVotes` ضعيف التحقق |
| `SEC-DISPUTE-001` | صحيح | حرج | كل مستخدم مسجل يقرأ كل النزاعات، ويمكنه إنشاء نزاع باسمه على مباراة لا تخصه وبحقول غير مقيدة |
| `SEC-DISPUTE-002` | صحيح | عالٍ | الإنشاء/الإغلاق والتجميد/الفك ليست ذرية، و`pendingReview` مرفوضة في مسار تحديث المنظم الحالي |
| `SEC-PLAYER-001` | صحيح | عالٍ | أول إنشاء لـ`players/{uid}` يسمح بتزوير rating/counters/trust/role/createdAt وحقول إضافية |
| `SEC-PRIVACY-001` | صحيح | حرج | مستند اللاعب المقروء لكل المسجلين يحتوي الهاتف وقوائم الصداقة والمتابعة والحظر؛ `privacySetting` لا تحمي القراءة |
| `CI-LOCK-001` | صحيح مع تصحيح | عالٍ | root lock غير متتبع، والـhotspots الفاشلة 7 لا 6 |
| `DEP-AUDIT-001` | غير مثبت كرقم حالي | يحتاج إعادة فحص | لا نعتمد رقم 10 قبل `npm audit` متصل ومؤرخ. الإصدار المثبت من `fast-xml-parser` هو 5.9.3، بينما التنبيه High المحدد [`GHSA-8gc5-j5rx-235r`](https://github.com/advisories/GHSA-8gc5-j5rx-235r) يصيب إصدارات أقل من 5.5.6، لذلك لا يثبت وحده أن 5.9.3 مصاب |

أحداث التدقيق القديمة التي لا تحمل provenance موثوقًا لا يجوز عرضها بوصفها «سجلًا رسميًا». تُقرأ كـ`legacyUnverified` أو تُخفى من العرض الرسمي، ولا تُرقّى جماعيًا إلى موثوقة.

---

## 4. العقود العامة المطلوبة

### 4.1 التدقيق

- حذف export العام `recordAuditEvent`&rlm;.
- إضافة كاتب داخلي غير مُصدّر `appendAuditEvent({transaction, entityType, entityId, action, actorId, beforePayload, afterPayload, metadata, requestId})`&rlm;.
- يشتق Backend الإجراء والكيان وbefore/after من المستندات المقروءة داخل transaction، ولا يقبلها كحقيقة من العميل.
- الحدث الموثوق يحمل `source: trustedOperation` و`verificationVersion: 1` و`requestId` ووقت الخادم.

### 4.2 التصويت

- Callable واحدة: `castFanVote({matchId, candidateRef, requestId})`&rlm;؛ لا يوجد `userId` في الطلب.
- `candidateRef` يستخدم عقد `ParticipantRef` الحالي بالقيم `player` أو `guestPlayer` أو `matchSidePlayer` مع `id` فقط كهوية قرار؛ الاسم لا يُوثق من العميل.
- يشتق المصوّت من Auth، ويتحقق الخادم من الجلسة ووقت الخادم والمرشح والـroster الرسمية وعمر الحساب الموثوق وعدم مشاركة المصوّت وعدم وجود vote حتمي سابق باسم `${matchId}_${uid}`&rlm;.
- جلسة التصويت تُنشأ أثناء settlement الموثوق وتُغلق أثناء approval أو job موثوق. كل الكتابات المباشرة إلى `fanVotingSessions` و`userVotes` ممنوعة.
- الضيوف مؤهلون للفخر والتصويت؛ أي rating bonus يظل للاعب المسجل فقط.

### 4.3 النزاعات

- `openMatchDispute({matchId, type, description, evidencePaths, requestId})`&rlm;؛ `type` من enum الحالية، والوصف بين 10 و1000 حرف، والأدلة ثلاثة مسارات خاصة كحد أقصى وليست روابط تنزيل عامة.
- `decideMatchDispute({disputeId, decision, resolutionNote, requestId})` حيث `decision` واحدة من `upholdResult` أو `reopenForCorrection`&rlm;.
- يفتح النزاع مستخدم مسجل مشارك فعليًا في roster، أو لاعب ضيف تم ربطه بهذا الحساب، أو منظم المباراة. الحسم للمنظم فقط في V1.
- transaction الفتح تنشئ النزاع، تحفظ `matchStatusBeforeFreeze`، تضع `activeScoreDisputeId` على المباراة، تجمد نزاع النتيجة، وتكتب audit واحدة.
- `upholdResult` يغلق النزاع كـ`rejected` ويعيد الحالة السابقة؛ `reopenForCorrection` يغلقه كـ`resolved` وينقل المباراة إلى `pendingReview`؛ كلاهما يمسح marker ويكتب audit داخل transaction نفسها.
- `requestId` يجعل retry idempotent، وmarker يمنع سباق نزاعين مفتوحين من النوع نفسه.
- تُحفظ الأدلة تحت مساحة Storage خاصة بالنزاع، وتسمح قواعد Storage بالرفع والقراءة للرافع وبالقراءة لمنظم المباراة فقط. يقرأ الكود `evidenceUrls` القديمة كـlegacy ولا يعيد نشرها، بينما كل نزاع جديد يستخدم `evidencePaths`&rlm;.

### 4.4 الحساب والملف العام

- `ensurePlayerProfile()` بلا payload موثوق؛ يشتق UID وبيانات Auth المسموحة ويكتب defaults والوقت من الخادم.
- `updateOwnPlayerProfile({name, photoUrl, photoThumbUrl, photoFrame, position, privacySetting})` يحدّث الحقول القابلة للتحرير فقط.
- `setUsername({username, requestId})` يحجز الاسم ويحدث الملف الخاص والإسقاط العام ذريًا.
- يبقى `players/{uid}` هو مستند الحساب الخاص: المالك يقرأه، والـBackend يكتب الحقول الموثوقة، ولا يوجد client create بعد cutover.
- يضاف `playerPublicProfiles/{uid}` كإسقاط Backend-only. حقوله القصوى: `name`, `nameLower`, `username`, `usernameLower`, `photoUrl`, `photoThumbUrl`, `photoFrame`, `position`, `rating`, `totalMatches`, `wins`, `draws`, `losses`, `mvpCount`, `trustLevel`, `achievementIds`, `privacySetting`, `updatedAt`&rlm;.
- يُمنع تمامًا وجود `phone`, `friendIds`, `followingIds`, `blockedIds`, `trustWeight`, `role`, `createdAt` أو claim data في الإسقاط العام.
- عند `privacySetting != public` يحتفظ الإسقاط بالهوية الدنيا اللازمة للـroster فقط ويزيل الصورة والإحصاءات؛ يعرض التطبيق «هذا الحساب خاص». دعم friends-only الكامل يؤجل إلى Social V2.

---

## 5. موجات التنفيذ

### Wave 0 — الاحتواء وإعادة خط الأساس `P0`

| التذكرة | التنفيذ | القبول |
| :--- | :--- | :--- |
| `V3-001` | إضافة `fan_voting_enabled=false` و`disputes_enabled=false` محليًا، وإخفاء مداخل الشاشتين دون dead route | لا يمكن للمستخدم الوصول إلى مسار كتابة مكسور؛ لا نشر Remote Config قبل مراجعة OWNER |
| `V3-002` | إزالة callable العامة للتدقيق واستبدال اختبارات نجاحها باختبار رفض/غياب export | entrypoint لا يصدر `recordAuditEvent` وأي client direct write مرفوض |
| `V3-003` | قواعد احتواء مستقلة: منع dispute/vote/session direct writes، وتقييد player create مؤقتًا بمخطط وقيم defaults دقيقة حتى جاهزية `ensurePlayerProfile` | attack tests تمنع forged role/rating/createdAt والحقول الزائدة، مع بقاء تسجيل الدخول الحالي صالحًا مؤقتًا |
| `V3-004` | تحديث واجهة timeline لتمييز الأحداث بلا provenance كـ«قديم غير موثق» | لا يظهر حدث قديم كإجراء رسمي موثوق |

**بوابة W0:** قواعد الاحتواء 5/5 في التدقيق المحدود، وكل اختبارات Auth الحالية تمر قبل أي نشر.

### Wave 1 — العمليات الموثوقة والذرية `P0`

| التذكرة | التنفيذ | القبول |
| :--- | :--- | :--- |
| `V3-101` | كاتب audit داخلي داخل معاملات settlement/approval/claim/moderation والحساب | لا توجد API عامة لإنشاء حدث رسمي؛ failure يَفشل العملية كاملة أو يتبع سياسة صريحة لكل عملية |
| `V3-102` | `castFanVote` والـrepository/controller العميل كواجهة callable فقط | تصويت صحيح يزيد مرة واحدة، وduplicate/مشارك/حساب حديث/مرشح خارج roster/جلسة مغلقة تُرفض بلا كتابة |
| `V3-103` | `openMatchDispute` و`decideMatchDispute` ومعاملات الحالة المحددة أعلاه | failure injection وretry والتزامن لا تترك dispute أو match نصف مكتملة |
| `V3-104` | Rules وindexes للقراءة: `userVotes` لصاحب الصوت فقط بينما تعرض الجلسة العدادات المجمعة؛ النزاع وأدلته لرافعه أو منظم المباراة؛ كل الكتابات Backend-only | cross-user reads وarbitrary creates تفشل على Emulator |

**بوابة W1:** Functions unit + Auth/Firestore Emulator خضراء، وكل callable تشتق actor من Auth وتملك اختبار idempotency واختبار unauthorized.

### Wave 2 — فصل الخصوصية وسلامة الحساب `P0`

| التذكرة | التنفيذ | القبول |
| :--- | :--- | :--- |
| `V3-201` | تنفيذ `ensurePlayerProfile`, `updateOwnPlayerProfile`, `setUsername` بقيم ووقت خادميين | لا يستطيع العميل إنشاء أو تعديل role/rating/counters/trust/createdAt |
| `V3-202` | إضافة نموذج ومستودع `playerPublicProfiles` وتحويل public profile/search/leaderboard/roster/share identity إليه | لا توجد قراءة عامة من `players` داخل Flutter بعد الجرد الآلي |
| `V3-203` | ناشر backfill إداري: preview افتراضي، تأكيد صريح لـ`el7reef-app/(default)`، توقف عند conflict، وتقرير anomalies | العدد يطابق اللاعبين، ولا يظهر أي حقل محظور في أي projection |
| `V3-204` | ترتيب cutover: نشر Functions والإسقاطات → backfill/verify → إصدار Android الجديد → قفل `players` للمالك فقط | التطبيق الجديد يعمل؛ build قديم يفشل بأمان بدل كشف PII؛ لا rollback إلى rules مكشوفة |
| `V3-205` | إبقاء Social المخفي خارج V1؛ block يستخدم Backend الحالي، ولا تُنقل arrays الخاصة إلى ملف عام | لا surface اجتماعية نصف عاملة ولا تسريب علاقات |

**بوابة W2:** Emulator attack matrix تمنع قراءة هاتف أو علاقات لاعب آخر، وتمنع forged initial profile، وتثبت search/leaderboard/public roster عبر projection فقط.

### Wave 3 — إغلاق UX المعروف `P1`

| التذكرة | التنفيذ | القبول |
| :--- | :--- | :--- |
| `V3-301` | التشكيلة: الصور القديمة لا تطابق `main`؛ يثبت build جديد أولًا. بعدها تصبح `visualSlots` مصدر الحقيقة و`visualBench` getter مشتقًا، وكل assign/swap/drag/formation/resize/reset/cancel تمر عبر invariant واحدة | قبل الحفظ دائمًا `pitchKeys ∩ benchKeys = ∅` واتحادهما يساوي اللاعبين النشطين، للمسجل والضيف و5/7/11 لاعبًا |
| `V3-302` | الشجرة: وضع الجولات يبقى افتراضي الهاتف؛ وضع الخريطة يخرج من `ListView/RefreshIndicator` ويملأ المساحة حتى لا يتنافس pan مع scroll | تحريك الخريطة لا يحرك الصفحة، وتفتح على المواجهة الحالية بمقياس مقروء |
| `V3-303` | شريط زجاجي واحد للخريطة: «الجولات، الحالي، نظرة عامة، الكأس»؛ العقد تعرض شعارًا/initials ونتيجة LTR وحالة؛ الضغط يحدد المسار ويفتح Sheet بها «افتح المباراة» | 360/600dp وRTL وtext scale 200% بلا تداخل؛ BYE والترجيح والبطل واضحون |
| `V3-304` | TalkBack يحول الشجرة لمسار خطي حسب الدور، والتصميم الدائري يُستخدم فقط في بطاقة مشاركة `Road to Cup` لا في التشغيل | التنقل السمعي يقرأ الدور والفريقين والنتيجة والحالة بترتيب مفهوم |

**بوابة W3:** goldens وwidget tests عند 360/600، ثم تحقق على `Pixel_4a_API_35_Lite` وProfile Mode لشجرة 32 فريقًا.

### Wave 4 — CI والاعتماديات `P0/P1`

| التذكرة | التنفيذ | القبول |
| :--- | :--- | :--- |
| `V3-401` | إزالة تجاهل root `package-lock.json`، توليده ومراجعته تحت Node 20، وضبط `cache-dependency-path` على root وFunctions locks | `npm ci` و`npm --prefix functions ci` ينجحان من clean checkout، وإعادة package-lock-only لا تغير الملفين |
| `V3-402` | إصلاح الملفات السبعة فوق budget باستخراج المسؤوليات مع characterization tests؛ لا رفع جماعي للأرقام | `npm run check:hotspots` أخضر، وأي baseline reconciliation استثنائي موثق لكل ملف لا كزيادة صامتة |
| `V3-403` | تشغيل `npm audit --omit=dev --json` متصلًا بعد موافقة صريحة وحفظ artifact مؤرخ؛ audit root tooling منفصل | صفر High/Critical في production tree؛ كل Moderate لها fix أو استثناء بمالك وسبب وتاريخ انتهاء |
| `V3-404` | تحديث Firebase dependencies بإصدارات متوافقة واختبار مسار Storage/delete-account؛ لا `npm audit fix --force` | Functions unit/emulator وحذف الحساب وStorage smoke خضراء |

**بوابة W4:** GitHub Actions الخضراء هي الدليل؛ لا يُقبل نجاح الجهاز المحلي وحده.

### Wave 5 — النشر وAndroid Closed Testing `P0`

| التذكرة | المالك | القبول |
| :--- | :---: | :--- |
| `V3-501` تفعيل Blaze وbudget alerts | OWNER | النشر مسموح ومراقب |
| `V3-502` backup ثم نشر Functions + rules + indexes المتوافقة في نافذة واحدة | ENG | post-deploy smoke لكل callable والقواعد، ولا fallback محلي للكتابات الحساسة |
| `V3-503` release/upload signing وPlay App Signing وتحديث SHA في Firebase وassetlinks | OWNER + ENG | Release AAB موقّع، package `com.el7reef.app` وTarget API 35+، وApp Links verified ببصمة Play |
| `V3-504` Android E2E بحسابين | QA | Google login → بطولة → فرق/ضيوف → groups/knockout → optional lineup → goals/MVP/penalties → approval → standings/bracket → Pride share → Claim |
| `V3-505` بطولة «كأس العالم 2026» بعد rules cutover | QA | تظهر كمميزة للمستخدم المسجل غير المنظم، وتفتح الفرق والمجموعات والمباريات والترتيب والشجرة بلا أدوات إدارة |
| `V3-506` وصول وأداء | QA | TalkBack، رفض الكاميرا، شبكة بطيئة، WhatsApp return، QR من جهاز ثان، text scale 200%، وp95 أقل من 16ms دون إطار دافئ فوق 32ms في التشكيلة والشجرة |
| `V3-507` Play readiness | OWNER | اعتماد الخصوصية والاحتفاظ وData Safety وحساب المراجع وتعليماته ومطابقتها للـAAB النهائي |

**بوابة W5:** لا blocker في المسار الكامل، ولا High/Critical، وrules audit النهائي 5/5، وCI خضراء، وRelease AAB مثبت من Closed Testing.

### Wave 6 — Pilot والتدرج

- يبدأ Pilot بمنظم فعلي وبطولة صغيرة، مع قياس زمن إنشاء البطولة، تسجيل خمسة أهداف وMVP، أول مشاركة، نجاح Claim، وفشل/إعادة المحاولة.
- تبقى `fan_voting_enabled` و`disputes_enabled` مغلقتين حتى نجاح سيناريوهاتهما بحسابين؛ ثم تفعيل 10%، فـ50%، فـ100% بعد استقرار الأعطال والـauthorization errors.
- لا يُسمى الرجوع من Android share sheet «مشاركة مكتملة».
- rollback يعطل flags أو يعيد Functions idempotently؛ لا يعيد قواعد تسمح بقراءة PII ولا يعيد callable التدقيق العامة.

---

## 6. مصفوفة التحقق الإلزامية

### Security وBackend

- forged audit entity/action/payload مرفوضة ولا تنشئ مستندًا.
- كل انتقال dispute ينجح بالكامل أو لا يكتب شيئًا، مع retry متزامن.
- vote مكرر أو من مشارك أو لحساب حديث أو مرشح مزور مرفوض.
- إنشاء player مزور بـrole/rating/createdAt/extra field مرفوض.
- مستخدم ثانٍ لا يقرأ phone أو friend/follow/block lists ولا evidence نزاع لا يخصه.
- نتيجة scoped rules audit هي `5/5` مع JSON جديد، وليس تقريرًا وصفيًا فقط.

### Flutter وUX

- `dart analyze lib/`&rlm;.
- `flutter test --no-pub` كامل، مع الاختبارات المركزة للتشكيلة والشجرة وAuth/public profiles.
- goldens عند 360 و600dp، RTL وtext scale 200%.
- لا player مكرر بين الملعب والبدلاء في أي draft state.
- لا scroll conflict في خريطة الشجرة، ومسار TalkBack خطي.

### Functions وCI

- `npm run test:functions`&rlm;.
- `npm run test:functions:emulator`&rlm;.
- `npm run test:rules:emulator`&rlm;.
- `npm run check:format:changed` و`check:architecture` و`check:indexes` و`check:hotspots`&rlm;.
- `npm ci` في root و`npm --prefix functions ci` من checkout نظيف.
- `git diff --check`&rlm;.

### Android

- لا أعمال iOS.
- API 24 وAPI 35 على الأقل، مع Light/Dark system دون وميض داكن رغم ثبات ثيم التطبيق الفاتح.
- جهاز/محاكي نظيف، حسابان، ونسخة من Play Closed Testing قبل قرار الإطلاق.

---

## 7. تعريف الاكتمال

لا تُعلن V1 مكتملة إلا إذا كانت كل تذاكر `V3-001` إلى `V3-507` إما `DONE` بدليل قابل للإعادة، أو ألغيت بقرار OWNER موثق يزيل القدرة من الإصدار. لا يكفي نجاح اختبارات محلية لتذكرة تتطلب نشرًا أو جهازًا أو Play Console.

الدليل النهائي يتكون من:

1. CI خضراء من commit الإصدار.
2. JSON تدقيق قواعد 5/5 وJSON dependency audit بلا High/Critical.
3. تقرير backfill يثبت صفر PII في `playerPublicProfiles`&rlm;.
4. Release AAB موقّع وبصمة Play App Links verified.
5. فيديو/لقطات وسجل نتائج لمسار Android E2E بالحسابين.
6. اعتماد Data Safety والسياسات وحساب المراجع.
7. Pilot فعلي بلا فقد بيانات أو كتابة نصف مكتملة أو blocker في حلقة البطولة والمشاركة والـClaim.

</div>
