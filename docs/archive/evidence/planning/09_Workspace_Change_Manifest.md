<div dir="rtl">

# Manifest مساحة العمل — UCP-001 إلى UCP-003

**الحالة:** `HISTORICAL SNAPSHOT — NOT AN ACTIVE PLAN`&rlm;

**المرجع الحالي:** `docs/core/00_Master_Product_Development_Plan.md`&rlm;

**تاريخ اللقطة:** 2026-07-11  
**المصدر:** `git status --short` و`git diff --name-only` و`git ls-files --others --exclude-standard`  
**الغرض:** جعل الحزمة الحالية قابلة للمراجعة على checkpoints، دون staging أو commit أو حذف أي عمل للمستخدم.

## 1. حجم الحزمة

| النوع | العدد |
| :--- | ---: |
| ملفات متتبعة معدلة | 113 |
| ملفات متتبعة محذوفة | 2 |
| ملفات متتبعة متأثرة إجمالًا | 115 |
| ملفات غير متتبعة | 40 |
| عناصر ظاهرة في `git status` | 148 |

لا تمثل هذه الأرقام تغييرات مستقلة بالضرورة؛ عدد من العناصر غير المتتبعة مجلدات تحتوي ملفات متعددة. أي staging لاحق يستخدم قائمة الملفات الفعلية، لا هذا العدد المجرد.

## 2. قواعد التصنيف

كل ملف في اللقطة يدخل في checkpoint واحد فقط. عند وجود ملف مشترك بين مجالين، يُنسب إلى المجال الذي يملك عقده التشغيلي واختباراته.

| checkpoint | العدد | المسارات المملوكة | سبب التجميع | البوابة الأدنى |
| :--- | ---: | :--- | :--- | :--- |
| A — Platform/Auth | 23 | `android/`، Firebase config، `lib/core/auth/`، `lib/core/firebase/`، `lib/core/navigation/`، auth/claim UI | جلسة المستخدم، مشروع Firebase، signing، واستئناف الروابط | auth/claim widget tests + Firebase config tests |
| B — Backend Security | 8 | `firestore.rules`، indexes، `functions/`، rules/functions tests | callable settlement والقواعد والأمان | `npm run test:functions` + rules emulator |
| C — Tournament Core | 58 | domain/repository/services والـlineup/team/tournament/matchday/tests المرتبطة | مصدر حقيقة البطولة والضيف والنتيجة والتشكيل | service/repository/widget tests + Flutter suite |
| D — UX Surfaces | 38 | routes، theme، home/profile/social/match/shareables/widgets/tests | الأسطح المرئية والـfeature gates والوصول | widget tests + QA جهاز عند الحاجة |
| E — Docs/Workspace | 21 | docs، ignore files، review tests، artefacts غير تنفيذية | توثيق، حوكمة، ومخرجات المراجعة | links/diff check + baseline |

## 3. محتوى checkpoints

### A — Platform/Auth

يشمل إعداد Android وFirebase، `AuthService`، تصنيف أخطاء الدخول وإصلاح البروفايل، حفظ المسار المؤجل، وشاشات claim/login/onboarding. الملفات غير المتتبعة المهمة في هذا checkpoint هي `auth_error_mapper.dart` و`auth_firebase_gateway.dart` و`firebase_config_guard.dart` و`pending_deep_link_service.dart` واختباراتها، إضافة إلى `profile_repair_screen.dart`.

**قرار staging:** لا يُدمج مع تغييرات UX أو البطولة؛ يجب أن يظل قادرًا على اجتياز login/profile repair/guest claim مستقلًا.

### B — Backend Security

يشمل `firestore.rules` و`firestore.indexes.json` و`functions/` و`test/functions/` و`test/rules/` و`match_settlement_service_remote_test.dart` و`package.json`.

أضيف في تحقق 12 يوليو 2026: `functions/audit_event.js` لعقد audit الآمن، و`functions/scripts/emulator_smoke.js` لبوابة Auth/Firestore/Storage/Functions القابلة للتكرار، واختبارا `audit_event.test.js` و`entrypoint.test.js` لمنع انتحال `actorId` وفشل تحميل exports مع SDK المثبت.

**قرار staging:** لا يُنشر أو يُدمج منفردًا عن Functions المتوافقة. هذا checkpoint يمتلك عقد submit/approve score ولا يتضمن تصميم الشاشات. بوابته الحالية: `npm run test:functions` ثم `npm run test:functions:emulator` ثم rules emulator&rlm;.

### C — Tournament Core

يشمل `TournamentFixtureService` و`MatchSettlementService` وformation/lineup helpers، entities/models/repository الخاصة بالبطولة، وواجهات/controllers الفريق والتشكيل وmatchday والبطولة واختباراتها.

**قرار staging:** لا يُخلط مع بطاقة مشاركة أو glass refactor. بعد كل تعديل فيه يجب تأكيد أهداف/MVP اللاعب الضيف والبدء دون تشكيل والـstandings.

### D — UX Surfaces

يشمل routes، theme وfeature flags، Home/Profile/Social gated surfaces، Match UI، share-card widgets، و`El7reefGlassSurface` و`SectionStateCard` واختباراتها.

**قرار staging:** يسمح بتغييرات التصميم والوصول فقط دون تغيير مباشر لقواعد Firestore أو settlement logic.

### E — Docs/Workspace

يشمل `.gitignore`، `docs/README.md`، ADR، خطط core، تقارير الاختبار المساندة، والملفات المساعدة مثل `photo_upload_service.dart` و`feature_flag_service.dart` التي تدعم واجهة/تشغيل checkpoints أخرى.

**قرار staging:** يوثق ويثبت المخرجات، ولا يغيّر سلوك core وحده.

## 4. عناصر غير متتبعة وموقفها

| العنصر | التصنيف | القرار الحالي |
| :--- | :--- | :--- |
| `functions/` و`test/functions/` | مصدر مطلوب | يحتفظ به ضمن B |
| `lib/core/auth/` و`lib/core/firebase/` و`lib/core/navigation/` | مصدر مطلوب | يحتفظ به ضمن A |
| widgets/utilities/اختبارات جديدة | مصدر مطلوب | يوزع بين C وD حسب المجال |
| `android/app/debug-el7reef-v2.keystore` | binary debug مقصود | لا يحذف؛ OWNER يؤكد fingerprint وعدم استخدامه release |
| `android/key.properties.example` | template غير سري | يحتفظ به؛ يمنع إضافة `key.properties` الحقيقي |
| `docs/core/06` و`07` و`08` | توثيق مطلوب | يحتفظ به؛ `08` هو المصدر التنفيذي |
| `.agents/skills/ExportBlock-*` | artifact غير مصنف | لا يحذف تلقائيًا؛ OWNER يقرر أرشفته أو تحويله إلى skill صالح |

## 5. نتيجة فحص الأسرار والملفات الثنائية — UCP-002

تم فحص الملفات المتغيرة وغير المتتبعة لأسماء private keys وservice accounts وpassword assignments وFirebase API keys، من دون طباعة أي قيمة.

| النتيجة | التفسير | الإجراء |
| :--- | :--- | :--- |
| لا private key أو service-account key ظاهر في الملفات المتأثرة | لا دليل على secret إنتاجي نصي | يستمر الفحص قبل كل commit/release |
| `google-services.json` و`firebase_options.dart` يظهران كمفاتيح Firebase client configuration | متوقع؛ ليست بديلًا عن قواعد Firestore | يبقيان تحت مراجعة Firebase config guard |
| `key.properties.example` يحتوي أسماء حقول signing فقط | template مقصود | يمنع tracking لـ`key.properties` الفعلي |
| `debug-el7reef-v2.keystore` ملف binary | debug artifact مقصود ومسموح استثنائيًا | لا يستخدم release؛ fingerprint يراجع مع OWNER |

## 6. وصفة checkpoint دون تغيير الـindex

لا ينفذ هذا الملف `git add` أو `git commit` تلقائيًا حتى لا يغيّر index مشتركًا. عند اعتماد المراجعة، يستخدم المالك staging حسب checkpoint بالترتيب التالي:

1. A — Platform/Auth
2. B — Backend Security
3. C — Tournament Core
4. D — UX Surfaces
5. E — Docs/Workspace

قبل كل checkpoint: `git diff --check` ثم الاختبار الأدنى في جدول القسم 2. لا ينتقل checkpoint إلى commit قبل مراجعة `git diff --cached --stat` و`git diff --cached`.

## 7. أوامر إعادة إنتاج اللقطة

```bash
git status --short
git diff --name-only
git ls-files --others --exclude-standard
git diff --check
```

## 8. النتيجة

`UCP-001` مكتملة: الحزمة مفهومة ومقسمة إلى checkpoints منطقية.  
`UCP-002` مكتملة: لا secret إنتاجي نصي مثبت في الفحص؛ تبقى مراجعة OWNER للـdebug keystore.  
`UCP-003` مكتملة منطقيًا: الوصفة والمجموعات جاهزة؛ staging/commit قرار مراجعة منفصل حتى لا يغير هذا العمل index مشتركًا.

</div>
