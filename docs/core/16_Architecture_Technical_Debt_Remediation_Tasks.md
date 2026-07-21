<div dir="rtl">

# مهام إصلاح المعمارية وتقليل الدين التقني

**الحالة:** قائمة تنفيذ تابعة للخطة الموحدة وليست Roadmap منتج مستقلة  
**آخر تحديث:** 2026-07-14  
**النطاق:** Tournament Ego Core Loop، Flutter، Cloud Functions، وعقود Firestore  
**المرجع التنفيذي الأعلى:** <bdi dir="ltr">docs/core/08_Unified_V1_Completion_And_Workspace_Plan.md</bdi>

ترتبط الشريحة الحرجة هنا بالتذاكر <bdi dir="ltr">UCP-004</bdi> و<bdi dir="ltr">UCP-104</bdi> و<bdi dir="ltr">UCP-108</bdi>. أما مهام التحسين الهيكلي اللاحقة فلا تبدأ قبل إدراجها في نافذة تنفيذ معتمدة داخل الخطة الموحدة؛ الهدف هو خفض المخاطر دون فتح Roadmap موازية أو إعادة كتابة شاملة.

## قواعد التنفيذ

- تنفيذ تذكرة واحدة أو مجموعة مترابطة صغيرة في كل تغيير قابل للمراجعة.
- كتابة اختبار يحمي السلوك الحالي قبل تفكيك أي ملف عالي الخطورة.
- عدم تغيير أسماء مجموعات Firestore أو routes العامة ضمن تذاكر إعادة الهيكلة.
- إبقاء عمليات النتيجة وMatchEvent والصلاحيات الحساسة داخل الخدمات والخادم.
- معاملة <bdi dir="ltr">player</bdi> و<bdi dir="ltr">guestPlayer</bdi> و<bdi dir="ltr">matchSidePlayer</bdi> كهويات كاملة في كل عقد إحصائي.
- تشغيل بوابات القبول المناسبة وتسجيل نتائجها قبل تعليم التذكرة كمكتملة.

## تعريف الاكتمال لكل تذكرة

- تحقق معيار القبول المكتوب للتذكرة، لا مجرد نقل الكود.
- نجاح الاختبارات المركزة للمنطقة المتغيرة.
- نجاح <bdi dir="ltr">dart analyze lib/</bdi> عند تغيير Dart.
- نجاح <bdi dir="ltr">npm run test:functions</bdi> عند تغيير Functions.
- نجاح اختبار Emulator عند تغيير حدود الثقة أو كتابات Firestore الحساسة.
- نجاح <bdi dir="ltr">git diff --check</bdi> وعدم وجود churn غير مرتبط.
- تحديث هذه القائمة بالدليل الفعلي والمخاطر المتبقية.

---

## Wave 0 — إغلاق خطر تسوية المباراة <bdi dir="ltr">P0</bdi>

### <bdi dir="ltr">ARCH-001</bdi> — Resolver موحّد وآمن لـroster المباراة

- [x] إضافة resolver في <bdi dir="ltr">functions/match_roster.js</bdi> يجمع roster كل طرف بالأسبقية: lineup snapshot، ثم roster الرسمي أو فريق الضيوف عند غياب snapshot، مع إضافة match-side players دائمًا.
- [x] دعم الحقول الحالية <bdi dir="ltr">starters</bdi> و<bdi dir="ltr">bench</bdi>، مع قراءة <bdi dir="ltr">entries</bdi> القديمة خلال الانتقال.
- [x] استبعاد عضويات الفريق ذات الحالة <bdi dir="ltr">inactive</bdi> أو المجهولة من fallback الرسمي.
- [x] إرجاع مفاتيح منفصلة للطرفين ومجموعة موحدة، بدل Set غير منسوبة لطرف.

**معيار القبول:** يمكن حل roster صحيح لمباراة بلا lineup، ولفريق ضيف، وللاعب مؤقت، دون قبول عضو متأخر عند وجود snapshot مجمد.

### <bdi dir="ltr">ARCH-002</bdi> — ربط payload النتيجة بالـroster قبل أي كتابة

- [x] التحقق من أن كل هداف موجود في الطرف المرسل داخل <bdi dir="ltr">submitMatchSettlement</bdi>.
- [x] التحقق من أن MVP موجود في الطرف المرسل.
- [x] التحقق من <bdi dir="ltr">mvpPlayerId</bdi> القديم مقابل كل أنواع هوية roster.
- [x] منع كتابة <bdi dir="ltr">detailedStats</bdi> للاعب مسجل خارج roster.
- [x] إزالة مسار التجاوز الذي كان يقبل actors عندما تكون مفاتيح roster فارغة.
- [x] تحويل أخطاء عقد التسوية إلى <bdi dir="ltr">INVALID_ARGUMENT</bdi> بدل خطأ داخلي مبهم.
- [x] تنفيذ كل قراءات transaction، ومنها active MatchEvents، قبل بدء الكتابات.

**معيار القبول:** payload غير صالح لا يغير المباراة ولا ينشئ MatchEvent أو player stats، بينما مباراة بلا lineup تقبل لاعبًا حقيقيًا من roster الرسمي أو الضيف.

### <bdi dir="ltr">ARCH-003</bdi> — اختبارات وحدة لحالات roster الحرجة

- [x] اختبار snapshot الحالي مع مسجل وضيف ولاعب طرف مؤقت.
- [x] اختبار fallback لعضويات starter وbench واستبعاد inactive والحالة المفقودة.
- [x] اختبار guest-team participant دون lineup.
- [x] اختبار match-side player المسجل والمؤقت.
- [x] اختبار رفض actor خارج roster وactor من الطرف المقابل.
- [x] اختبار رفض detailed stats خارج roster وقبول legacy MVP الصحيح.

**الدليل:** <bdi dir="ltr">npm run test:functions</bdi> نجح بنتيجة <bdi dir="ltr">37 passing</bdi> في 2026-07-13.

### <bdi dir="ltr">ARCH-004</bdi> — عقد هوية مشترك بين Dart وFunctions

- [x] إضافة fixture واحدة في <bdi dir="ltr">test/fixtures/participant_identity_contract.json</bdi> للأنواع الثلاثة ومفتاح الهوية المتوقع.
- [x] استهلاك fixture من اختبار JavaScript لعقد settlement.
- [x] استهلاك fixture نفسها من اختبار Dart لـ<bdi dir="ltr">ParticipantRefModel</bdi>.

**الدليل:** نجح <bdi dir="ltr">flutter test --no-pub test/data/models/participant_ref_model_test.dart</bdi> بأربعة اختبارات.

### <bdi dir="ltr">ARCH-005</bdi> — إثبات End-to-End على Firebase Emulator

- [x] إضافة مباراة بلا lineup لها لاعب مسجل ولاعب ضيف في smoke fixture.
- [x] إثبات نجاح هدف وMVP للضيف وكتابة MatchEvent وplayer stats.
- [x] إثبات رفض لاعب خارج roster وبقاء المباراة في حالة <bdi dir="ltr">live</bdi> دون score.
- [x] تشغيل البوابات الست غير الموثقة وعمليات report/block/audit/delete الموجودة دون regression.

**الدليل:** نجح <bdi dir="ltr">npm run test:functions:emulator</bdi> مع <bdi dir="ltr">6/6 auth gates</bdi> وsettlement roster guards في 2026-07-13.

### <bdi dir="ltr">OPS-001</bdi> — نشر الشريحة الحرجة والتحقق على المشروع المستهدف

- [ ] ربط التغيير بـ<bdi dir="ltr">UCP-104</bdi> ونشر Functions مع rules/indexes المتوافقة بعد تفعيل Blaze.
- [ ] تنفيذ smoke حقيقي لمباراة مسجل + ضيف بلا lineup على <bdi dir="ltr">el7reef-app</bdi>.
- [ ] مراقبة <bdi dir="ltr">INVALID_ARGUMENT</bdi> للتفريق بين payload قديم ومحاولة actor خارج roster.
- [x] تجهيز rollback قبل النشر: لا توجد Functions سابقة، وتم تسجيل ruleset النشط وبصمته وسياسة حذف الوظائف الست الجديدة فقط عند فشل أول smoke.

**التبعية:** <bdi dir="ltr">UCP-101</bdi> وبيانات اختبار يملكها OWNER.  
**الحالة:** نجح preflight الخاص بالقواعد والفهارس، وتوقف preflight الخاص بالـFunctions صراحة لأن المشروع يحتاج Blaze. راجع <bdi dir="ltr">docs/audits/2026-07-14_production_deploy_preflight.md</bdi>&rlm;.

---

## Wave 1 — حدود Backend واضحة وقابلة للاختبار <bdi dir="ltr">P1</bdi>

### <bdi dir="ltr">ARCH-101</bdi> — فصل core التسوية عن Firebase callable

- [x] نقل orchestration الخاص بـ<bdi dir="ltr">submitMatchSettlement</bdi> من <bdi dir="ltr">functions/index.js</bdi> إلى <bdi dir="ltr">functions/settlement_core.js</bdi> مع dependencies صريحة.
- [x] إبقاء <bdi dir="ltr">index.js</bdi> مسؤولًا عن auth وتحويل <bdi dir="ltr">SettlementError</bdi> إلى HttpsError فقط.
- [x] إضافة اختبارات تثبت عدم وجود writes عند permission أو roster أو status failure.

**معيار القبول:** اختبار core لا يحتاج تحميل Firebase Functions runtime، ولا تتغير استجابة callable العامة.

### <bdi dir="ltr">ARCH-102</bdi> — Idempotency واضحة لتسوية النتيجة

- [x] تعريف SHA-256 submission fingerprint محفوظ على المباراة مع المنفذ ووقت التسوية.
- [x] إعادة نفس النتيجة بأمان عند retry لنفس الطلب بعد timeout مع <bdi dir="ltr">alreadySettled: true</bdi>.
- [x] رفض payload مختلف بعد اكتمال المباراة دون مضاعفة MatchEvents أو stats.
- [x] اختبار retry متزامن على Firestore Emulator واختبار retry بعد نجاح الكتابة.

**معيار القبول:** لا يضاعف retry هدفًا أو MVP أو player stats، وتصبح قيمة <bdi dir="ltr">alreadySettled</bdi> ذات معنى فعلي.

### <bdi dir="ltr">ARCH-103</bdi> — Schema صارم لـdetailed stats

- [x] تطبيع الأرقام إلى integers غير سالبة وحدود منطقية، مع rating بين 0 و10، قبل الكتابة.
- [x] رفض duplicate player ids والحقول غير المعروفة والقيم والـposition غير الصالحة.
- [x] ربط team/side باللاعب من roster الخادمي وتجاهل <bdi dir="ltr">teamId</bdi> غير الموثوق من العميل.
- [x] اشتقاق قائمة fan-voting المؤهلة من roster المسجل الموثوق، مع الحفاظ على جلسة موجودة وأصواتها.

**معيار القبول:** لا يستطيع العميل إدخال إحصائية سالبة أو فريق مزور أو eligibility خارج roster.

### <bdi dir="ltr">ARCH-104</bdi> — إزالة ازدواج resolver بين submit وapprove

- [x] مقارنة <bdi dir="ltr">functions/match_roster.js</bdi> مع <bdi dir="ltr">functions/approval_core.js</bdi> و<bdi dir="ltr">OfficialMatchRosterService</bdi> وإزالة resolver النسخة من approval.
- [x] جعل rating roster projection مبنية على resolver المشترك مع فلتر registered-player صريح لكل طرف.
- [x] إضافة contract test لنفس المباراة عبر submit ثم approve والتحقق من rating deltas.

**معيار القبول:** اختلاف guest eligibility بين MatchEvent والتقييم قرار صريح ومختبر، لا نتيجة implementation مختلفين.

### <bdi dir="ltr">ARCH-105</bdi> — ثوابت وعقود Functions مركزية

- [x] تعريف أسماء collections في <bdi dir="ltr">firestore_collections.json</bdi> وقيم event/status المشتركة في <bdi dir="ltr">firestore_contract.js</bdi>.
- [x] إزالة strings المكررة من settlement وroster والأجزاء المشتركة التي لُمست داخل approval.
- [x] إضافة اختبار Dart يقارن العقد المنشور مع <bdi dir="ltr">FirebasePaths</bdi>.

**دليل Wave 1:** نجح <bdi dir="ltr">npm run test:functions</bdi> بنتيجة <bdi dir="ltr">57 passing</bdi>، ونجح <bdi dir="ltr">npm run test:functions:emulator</bdi> مع retry متزامن ومتتابع وحفظ جلسة التصويت في 2026-07-13.

### تحسينات مكتشفة أثناء Wave 1

- [x] <bdi dir="ltr">IMP-101</bdi> — منع score أكبر من 99 لتجنب fan-out غير محدود لكتابات MatchEvent.
- [x] <bdi dir="ltr">IMP-102</bdi> — منع مجموع أهداف منسوبة أكبر من score الطرف مع السماح بالأهداف غير المنسوبة.
- [x] <bdi dir="ltr">IMP-103</bdi> — إصلاح تحويل minute الفارغة إلى 0؛ أصبحت تبقى <bdi dir="ltr">null</bdi> وتُرفض الدقائق خارج 0–300.
- [x] <bdi dir="ltr">IMP-104</bdi> — رفض scorer مكرر لنفس الطرف قبل اصطدام event IDs الحتمية.
- [x] <bdi dir="ltr">IMP-105</bdi> — حفظ tackles وrating اللذين كان الخادم يسقطهما رغم وجودهما في <bdi dir="ltr">PlayerMatchStatsModel</bdi>.
- [x] <bdi dir="ltr">IMP-106</bdi> — عدم overwrite لجلسة fan voting موجودة أو مسح أصواتها عند تسوية النتيجة.
- [x] <bdi dir="ltr">IMP-107</bdi> — void لحدث MVP النشط عند إرسال تسوية بلا MVP typed بدل ترك حدث قديم فعالًا.

**معيار القبول:** لا يغيّر التجميع أسماء collections المنشورة، وأي drift جديد يفشل اختبارًا.

---

## Wave 2 — تفكيك Hotspots في Flutter دون إعادة كتابة <bdi dir="ltr">P1/P2</bdi>

لقطة 2026-07-13 أظهرت ملفات تتجاوز 700–1300 سطر. الحجم ليس عيبًا منفردًا، لكنه يزيد تكلفة التعديل عندما يجمع view وorchestration وformatting وnavigation في ملف واحد.

### <bdi dir="ltr">ARCH-201</bdi> — تفكيك شاشة تفاصيل البطولة

- [x] تثبيت characterization tests للـCTA والحالات الأساسية في <bdi dir="ltr">tournament_detail_screen.dart</bdi>، وتشمل المنظم والزائر وحالة الخطأ والهداف المسجل والضيف.
- [x] تثبيت الأقسام البصرية كـwidgets مستقلة داخل feature نفسها: story وquick actions وpublic links وtop scorers وregistration وorganizer CTA.
- [x] نقل navigation mapping إلى <bdi dir="ltr">TournamentDetailRoutes</bdi> المبني على <bdi dir="ltr">AppRoutes</bdi> مع اختبار عقد مستقل.
- [x] إبقاء controller والخدمات الحالية دون تغيير API في الشريحة الأولى.

**دليل <bdi dir="ltr">ARCH-201</bdi>:** نجح اختبارا route contract مع 27 حالة dashboard/detail قائمة، بإجمالي 29 اختبارًا.

### <bdi dir="ltr">ARCH-202</bdi> — فصل Dashboard عمليات البطولة

- [x] تثبيت dashboard كأقسام widgets مستقلة للـhero وwizard/next action وmetrics وsecondary operations وmaintenance.
- [x] فصل <bdi dir="ltr">TournamentOperationsReadModel</bdi> النقي عن GetX، مع إبقاء commands موزعة في participant/stage/fixture ops دون كسر bindings.
- [x] إضافة اختبارات لحالات live وpending review وترتيب next action قبل lifecycle actions.

**دليل <bdi dir="ltr">ARCH-202</bdi>:** نجحت 3 اختبارات read-model الجديدة و27 حالة dashboard/controller قائمة، بإجمالي 30 اختبارًا.

### <bdi dir="ltr">ARCH-203</bdi> — تخفيف Score Submit

- [x] تثبيت اختبارات الخطوات الأربع واستعادة draft والتعارض كحاجز قبل النقل.
- [x] استخراج step widgets من <bdi dir="ltr">score_submit_screen.dart</bdi> إلى <bdi dir="ltr">score_submit_steps.dart</bdi>.
- [x] فصل validation والتحويل إلى settlement drafts عن GetX/UI داخل <bdi dir="ltr">ScoreSubmitPreparation</bdi>.
- [x] الحفاظ على النص العربي وRTL ومسار الضيف دون تغيير UX غير مقصود.

**دليل <bdi dir="ltr">ARCH-203</bdi>:** نجح <bdi dir="ltr">flutter test --no-pub test/features/match/score_submit_preparation_test.dart test/features/match/score_submit_controller_test.dart test/features/match/score_submit_draft_store_test.dart</bdi> بنتيجة 47 اختبارًا، وتشمل 4 خطوات على عرض 360 مع تكبير النص 200%، استعادة draft، تعارض النتيجة الأحدث، وهوية الضيف في الأهداف وMVP.

### تحسينات مكتشفة أثناء <bdi dir="ltr">ARCH-203</bdi>

- [x] <bdi dir="ltr">IMP-203-1</bdi> — أصبحت نتيجة الحقل الفارغ تُشتق في وحدة نقية من مجموع الأهداف المنسوبة، بدل تكرار القرار بين انتقال الخطوة وsubmit.
- [x] <bdi dir="ltr">IMP-203-2</bdi> — أصبح ربط detailed stats بالطرف وتجهيز goal settlement drafts قابلين لاختبار وحدة دون GetX أو Firestore.

### <bdi dir="ltr">ARCH-204</bdi> — تقسيم Guest Claim إلى use cases

- [x] رسم حالات claim والكتابات الحساسة في <bdi dir="ltr">docs/adr/002_guest_claim_use_case_boundaries.md</bdi>.
- [x] فصل token validation وprofile merge وpost-commit reporting إلى <bdi dir="ltr">GuestClaimTokenPolicy</bdi> و<bdi dir="ltr">GuestClaimMergePolicy</bdi> و<bdi dir="ltr">GuestClaimCompletionReporter</bdi>.
- [x] إضافة وتثبيت اختبارات retry وpartial failure وclaimed guest identity.
- [x] عدم تغيير claim code schema أو collection names ضمن التفكيك.

**دليل <bdi dir="ltr">ARCH-204</bdi>:** نجح 16 اختبارًا لخدمة وسياسات Guest Claim، منها إثبات بقاء guest/membership/claim code دون كتابة جزئية عند تعارض roster.

### تحسينات مكتشفة أثناء <bdi dir="ltr">ARCH-204</bdi>

- [x] <bdi dir="ltr">IMP-204-1</bdi> — نقل analytics خارج Firestore transaction حتى لا يتكرر الحدث إذا أعاد Firestore تشغيل callback.
- [x] <bdi dir="ltr">IMP-204-2</bdi> — توحيد تسجيل اكتمال team claim؛ المسار المباشر بدون approval كان لا يسجل الحدث قبل التفكيك.

### <bdi dir="ltr">ARCH-205</bdi> — تفكيك دورة حياة البطولة حسب الأوامر

- [x] إبقاء fixture generation في <bdi dir="ltr">GroupStageBuilder/KnockoutBuilder</bdi> وفصل complete وstandings refresh في <bdi dir="ltr">TournamentCompletionPlanner</bdi> و<bdi dir="ltr">TournamentStandingsRefreshPlanner</bdi>.
- [x] فصل registration validation عن persistence في <bdi dir="ltr">TournamentRegistrationPolicy</bdi>.
- [x] إبقاء transaction/batch boundaries داخل services المالكة للكتابة؛ planners والسياسة وحدات نقية بلا Firestore.
- [x] تشغيل اختبارات groups/knockout/hybrid بعد كل extraction.

**دليل <bdi dir="ltr">ARCH-205</bdi>:** نجح 24 اختبارًا تشمل المسار الكامل groups → knockout → champion، idempotency، standings no-op، hybrid guest registration، السعة، والموعد النهائي.

### <bdi dir="ltr">ARCH-206</bdi> — تقليل تعقيد widgets التشكيلة والمشاركة

- [x] تثبيت golden/interaction coverage لـ<bdi dir="ltr">professional_pitch_card.dart</bdi> واختبارات preview/export لـ<bdi dir="ltr">lineup_share_card.dart</bdi> قبل النقل.
- [x] استخراج projection وnode/hit metrics وshare positioning إلى <bdi dir="ltr">PitchLayout</bdi> و<bdi dir="ltr">ProfessionalPitchLayoutMetrics</bdi> القابلين لاختبار الوحدة.
- [x] الحفاظ على شبكة 8px وCairo وRTL، وتوحيد Lineup Share على <bdi dir="ltr">PrideCardFormat</bdi> لدعم 4:5 و9:16.

**دليل <bdi dir="ltr">ARCH-206</bdi>:** نجحت 3 اختبارات layout نقية، و3 اختبارات lineup share، وgolden 11v11، و13 اختبار interaction/drag بإجمالي 20 اختبارًا.

### تحسينات مكتشفة أثناء <bdi dir="ltr">ARCH-206</bdi>

- [x] <bdi dir="ltr">IMP-206-1</bdi> — كان Lineup Share يستخدم نسبة 2:3 خارج عقد بقية Pride Cards؛ أصبح الافتراضي 4:5 مع دعم story 9:16 واختبار RTL لكليهما.

**معيار قبول Wave 2:** لا يتغير route أو UX core أو Firestore write، وتقل مسؤوليات كل hotspot مع اختبارات تحمي السلوك بدل تقسيم شكلي حسب عدد الأسطر.

---

## Wave 3 — عقود البيانات والهوية <bdi dir="ltr">P1</bdi>

### <bdi dir="ltr">ARCH-301</bdi> — سياسة parsing صريحة لـParticipantRef

- [x] جرد بيانات production للأنواع المخزنة قبل تغيير fallback الحالي.
- [x] استبدال تحويل النوع المجهول إلى <bdi dir="ltr">player</bdi> بسياسة fail صريحة، مع إسقاط draft محلي تالف بدل تحويل هويته.
- [x] إضافة invalid fixtures مشتركة لـDart وFunctions.

**الدليل:** اكتملت قراءة production في 2026-07-14 لحقل <bdi dir="ltr">actor</bdi> فقط عبر جلسة Firebase CLI المخولة. مجموعة <bdi dir="ltr">matchEvents</bdi> فارغة حاليًا، ولذلك لا توجد أنواع legacy أو سجلات غير صالحة تحتاج migration قبل النشر.

### <bdi dir="ltr">ARCH-302</bdi> — توحيد timestamps على حدود Firestore

- [x] جرد الحقول التي تستخدم milliseconds والحقول التي تستخدم Firestore Timestamp.
- [x] تعريف adapters مركزية للقراءة المتوافقة والكتابة الجديدة.
- [x] ترحيل <bdi dir="ltr">matchEvents.createdAt</bdi> للكتابة كـTimestamp مع backward-compatible reads.

**الدليل:** <bdi dir="ltr">docs/audits/2026-07-13_firestore_timestamp_inventory.md</bdi> و5 اختبارات adapter/model ناجحة.

### <bdi dir="ltr">ARCH-303</bdi> — حل هوية الضيف بعد claim

- [x] اختيار read-time merge وتسجيله في <bdi dir="ltr">ADR-005</bdi>.
- [x] منع مضاعفة goals عند دمج guest identity مع player identity في مفتاح canonical واحد.
- [x] اختبار leaderboard والتنقل وكارت الهدافين قبل وبعد claim.

**الدليل:** نجح 47 اختبارًا مركّزًا للـresolver والتنقل وكروت الفخر، وتشمل حالات dashboard الضيف قبل claim وبعده.

### <bdi dir="ltr">ARCH-304</bdi> — مصفوفة ملكية الكتابات الحساسة

- [x] جرد كل كتابة من Flutter إلى matches وmatchEvents وstats وclaim/audit collections.
- [x] تصنيف كل عملية: client-safe أو service-only أو callable-only.
- [x] إزالة direct MatchEvent retry من controller وإبقاؤه داخل callable settlement؛ rules تمنع كتابات MatchEvent/stats/audit من العميل.

**الدليل:** <bdi dir="ltr">docs/audits/2026-07-13_sensitive_write_ownership.md</bdi>، و41 اختبار Score Submit، وarchitecture guard.

### <bdi dir="ltr">ARCH-305</bdi> — ميزانية queries وindexes

- [x] تسجيل queries الفعلية لكل core flow ومطابقتها مع <bdi dir="ltr">firestore.indexes.json</bdi>.
- [x] إثبات عدم وجود orderBy زائد في checks الخادمية الحرجة وعدم إضافة index غير مستخدم.
- [x] وضع حدود معلنة ومختبرة لقراءات roster وactive MatchEvents.

**الدليل:** <bdi dir="ltr">docs/audits/2026-07-13_core_query_and_index_budget.md</bdi> و62 اختبار Functions ناجحًا.

### تحسينات مكتشفة أثناء <bdi dir="ltr">ARCH-305</bdi>

- [x] <bdi dir="ltr">IMP-305-1</bdi> — استعادة 11 فهرسًا منشورًا كان الملف المحلي لا يحافظ عليها، ثم إضافة <bdi dir="ltr">check:indexes</bdi> إلى CI حتى لا يحذف نشر لاحق فهارس production دون قرار صريح.

---

## Wave 4 — حواجز تمنع عودة الدين التقني <bdi dir="ltr">P2</bdi>

### <bdi dir="ltr">ARCH-401</bdi> — Architecture dependency checks

- [x] منع views من استيراد implementations في data layer مباشرة عند وجود service/controller boundary.
- [x] منع sensitive controllers من استخدام Firestore أو MatchEvent writes مباشرة.
- [x] إضافة <bdi dir="ltr">tool/architecture_guard.js</bdi> قابل للتشغيل في CI مع allowlist فارغة تكشف entries القديمة.

### <bdi dir="ltr">ARCH-402</bdi> — بوابة CI موحدة

- [x] تشغيل format check و<bdi dir="ltr">dart analyze lib/</bdi> وFlutter tests وFunctions tests.
- [x] تشغيل rules/functions emulator في job مستقل؛ التشغيل دائم حاليًا أشد من شرط الملفات ذات الصلة.
- [x] فشل البوابة عند <bdi dir="ltr">git diff --check</bdi> أو تجاوز حواجز المعمارية/hotspots.

### <bdi dir="ltr">ARCH-403</bdi> — ميزانية hotspot ومراجعة دورية

- [x] توليد أكبر 20 ملف production عبر <bdi dir="ltr">npm run report:hotspots</bdi> دون حد عام لكل الملفات.
- [x] تجميد نمو أكبر 11 hotspot معروفًا عند baseline؛ الزيادة تحتاج extraction أو قرارًا موثقًا.
- [x] مراجعة القائمة بعد Waves 2–4 وتحويل القرارات المتكررة إلى guards وADR بدل مهام مفتوحة.

### <bdi dir="ltr">ARCH-404</bdi> — توثيق القرارات المعمارية الحية

- [x] تسجيل ADR لـroster precedence وsettlement idempotency وpost-claim identity.
- [x] تحديث SAD بخط الأساس المنفذ في 2026-07-13.
- [x] ربط كل ADR باختبارات أو Emulator smoke قابلة للتحقق.

---

## ترتيب التنفيذ المقترح

1. [x] <bdi dir="ltr">ARCH-001 → ARCH-005</bdi>: إغلاق خطر settlement محليًا.
2. [ ] <bdi dir="ltr">OPS-001</bdi>: اكتمل preflight والrollback، ويبقى النشر والتحقق الحقيقي ضمن <bdi dir="ltr">UCP-104/UCP-108</bdi> بعد Blaze.
3. [x] <bdi dir="ltr">ARCH-101 → ARCH-105</bdi>: جعل backend قابلًا للاختبار وإضافة idempotency وعقد بيانات موحد.
4. [x] <bdi dir="ltr">ARCH-203</bdi> ثم <bdi dir="ltr">ARCH-201/202</bdi>: تفكيك أكثر مسارات المنتج تغيرًا بعد تثبيت characterization tests.
5. [x] <bdi dir="ltr">ARCH-301 → ARCH-305</bdi>: اكتملت محليًا ومع جرد production، دون حاجة migration لهويات MatchEvent.
6. [x] <bdi dir="ltr">ARCH-401 → ARCH-404</bdi>: تحويل الدروس إلى حواجز CI وتوثيق حي.

## مؤشرات النجاح

- [x] صفر MatchEvents أو stats لهوية خارج roster في اختبارات الوحدة وEmulator المحلي.
- [x] retries لتسوية النتيجة لا تضاعف البيانات.
- [x] لا توجد كتابة حساسة جديدة من controller مباشرة إلى Firestore.
- [x] كل hotspot تم لمسه يملك characterization tests ومسؤولية أضيق قابلة للوصف بجملة واحدة.
- [x] عقود الهوية المشتركة تفشل عند drift بين Dart وFunctions.
- [x] لم تنخفض تغطية الضيوف أو RTL أو رحلة البطولة في الاختبارات المركزة.

## لقطة التحقق النهائية — 2026-07-14

- [x] <bdi dir="ltr">dart analyze lib/</bdi>: لا توجد مشاكل.
- [x] <bdi dir="ltr">flutter test --no-pub</bdi>: عدد 573 اختبارًا ناجحًا.
- [x] <bdi dir="ltr">npm run test:functions</bdi>: عدد 62 اختبارًا ناجحًا.
- [x] <bdi dir="ltr">npm run test:rules:emulator</bdi>: عدد 168 اختبارًا ناجحًا.
- [x] <bdi dir="ltr">npm run test:functions:emulator</bdi>: نجاح <bdi dir="ltr">6/6 auth gates</bdi> وحراسات roster والتسوية وعمليات report/block/audit/delete.
- [x] <bdi dir="ltr">npm run check:architecture</bdi> و<bdi dir="ltr">npm run check:indexes</bdi> و<bdi dir="ltr">npm run check:hotspots</bdi> و<bdi dir="ltr">npm run check:format:changed</bdi>: ناجحة.
- [x] <bdi dir="ltr">git diff --check</bdi>: ناجح.
- [x] جرد هويات production: صفر <bdi dir="ltr">matchEvents</bdi> وصفر أنواع غير صالحة في لقطة 2026-07-14.
- [x] deploy dry-run لقواعد وفهارس Firestore: ناجح بعد الحفاظ على كل فهارس production.
- [x] rollback dry-run للقواعد: تحقق من ruleset النشط دون أي كتابة.
- [ ] deploy dry-run للـFunctions: توقف لأن المشروع يحتاج Blaze لتفعيل Cloud Build وArtifact Registry.
- [ ] نشر <bdi dir="ltr">OPS-001</bdi> وsmoke الحقيقي والمراقبة: يحتاج بيانات اختبار OWNER وتفعيل Blaze؛ rollback أصبح موثقًا وجاهزًا.

</div>
