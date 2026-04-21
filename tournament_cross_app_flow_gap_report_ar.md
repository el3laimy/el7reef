<div dir="rtl" align="right">

<h1>تقرير مراجعة مسارات البطولة عبر التطبيق</h1>

<h2>الغرض من التقرير</h2>

<p>
هذا التقرير يراجع تسلسل الخطوات المرتبطة بالبطولة عبر أجزاء التطبيق المختلفة، وليس داخل شاشة واحدة فقط.
</p>

<p>
التركيز هنا على:
</p>

<ul>
  <li>تسلسل التشغيل الفعلي من إنشاء البطولة حتى إعلان البطل</li>
  <li>مسار الفرق الضيفة واللاعبين الضيوف</li>
  <li>تأثير ذلك على <code>matchday</code> و<code>score submission</code></li>
  <li>إمكانية تشغيل <code>fantasy</code> موازية بشكل صحيح</li>
  <li>تحديد المشاكل الحالية مرتبة حسب الخطورة</li>
  <li>وضع توصية تنفيذية واضحة بمنهج <code>production-first</code> بدون إهدار وقت في <code>migration-heavy work</code></li>
</ul>

<h2>الحكم التنفيذي المختصر</h2>

<p>
الموديول اليوم قوي جدًا في:
</p>

<ul>
  <li>التسجيلات</li>
  <li>المشاركين</li>
  <li>المجموعات</li>
  <li>الـ fixtures</li>
  <li>الـ standings</li>
  <li>الـ knockout</li>
  <li>لوحة التشغيل الأساسية</li>
</ul>

<p>
لكن ما زال عنده فجوات تشغيلية حقيقية في المسار الممتد عبر التطبيق كله، وأهمها:
</p>

<ul>
  <li>المباراة لا تملك <code>Start Match</code> واضح داخل Flow البطولة</li>
  <li>مسار إدخال النتيجة ما زال يعتمد على لاعبين مسجلين فقط</li>
  <li>الفرق الضيفة لا تملك roster تشغيليًا واضحًا داخل البطولة</li>
  <li>لا يوجد تمثيل صحيح لارتباط اللاعب الضيف بفريق ضيف</li>
  <li>الفنتازي الحالية لا يمكنها دعم بطولة فيها لاعبين ضيوف بشكل احترافي كامل</li>
</ul>

<p>
الخلاصة التنفيذية:
</p>

<p>
قلب البطولة أصبح موجودًا، لكن الحلقة التشغيلية الكاملة عبر <code>guest roster -> matchday -> score -> fantasy</code> ما زالت غير مكتملة.
</p>

<h2>الخريطة الحالية للمسار</h2>

<ol>
  <li>إنشاء البطولة</li>
  <li>تسجيل فرق مسجلة أو فرق ضيفة</li>
  <li>اعتماد التسجيلات</li>
  <li>تحويل المعتمدين إلى <code>TournamentParticipant</code></li>
  <li>قفل قائمة المشاركين</li>
  <li>بناء المجموعات والـ fixtures</li>
  <li>نشر وجدولة المباريات</li>
  <li><code>Matchday</code> للحضور والتشكيل والتبديلات</li>
  <li>إدخال واعتماد النتائج</li>
  <li>تحديث standings أو bracket</li>
  <li>تشغيل الفنتازي الموازية</li>
</ol>

<p>
المشكلة الحالية أن الخطوات من <code>7</code> إلى <code>11</code> ما زالت غير متماسكة بالكامل إذا دخلنا سيناريوهات الفرق الضيفة واللاعبين الضيوف.
</p>

<h2>المشاكل الحالية مرتبة حسب الأولوية</h2>

<h3>F-01 — لا يوجد <code>Start Match</code> داخل Flow البطولة</h3>

<p>
مباريات البطولة تُنشأ بحالة <code>MatchStatus.open</code> داخل <code>lib/core/services/group_stage_builder.dart</code> و<code>lib/core/services/knockout_builder.dart</code>.
</p>

<p>
لكن:
</p>

<ul>
  <li><code>matchday</code> يسمح فقط بالعمليات قبل انطلاق المباراة</li>
  <li><code>Score Review</code> داخل شاشات البطولة لا يُفتح طبيعيًا عندما تكون المباراة <code>open</code></li>
  <li><code>match_discover_screen</code> يفتح إدخال النتيجة فقط عندما تصبح المباراة <code>live</code></li>
</ul>

<p>
النتيجة:
</p>

<ul>
  <li>المنظم يستطيع عمل <code>check-in</code> و<code>lineup lock</code></li>
  <li>لكن لا توجد خطوة تشغيلية واضحة تنقل المباراة من <code>open</code> إلى <code>live</code></li>
  <li>وبالتالي مسار إدخال النتيجة متعطل طبيعيًا</li>
</ul>

<p>
هذه فجوة <code>P0</code>.
</p>

<h3>F-02 — مسار إدخال النتيجة يعتمد على <code>teamAPlayerIds/teamBPlayerIds</code> وليس على lineup المباراة</h3>

<p>
الملف <code>lib/features/match/controllers/score_submit_controller.dart</code> يحمّل اللاعبين من:
</p>

<ul>
  <li><code>match.teamAPlayerIds</code></li>
  <li><code>match.teamBPlayerIds</code></li>
</ul>

<p>
لكن Fixtures البطولة المولدة حاليًا لا تُعبئ هذه الحقول أصلًا عند البناء.
</p>

<p>
وفي الوقت نفسه:
</p>

<ul>
  <li><code>matchday</code> يحفظ <code>check-in</code> و<code>lineup snapshot</code></li>
  <li>لكنه لا يروّج lineup المقفولة لتصبح roster رسمية داخل كيان <code>Match</code></li>
</ul>

<p>
النتيجة:
</p>

<ul>
  <li>حتى لو أضفنا <code>Start Match</code> الآن، شاشة النتيجة ستظل لا تملك roster صحيحة</li>
  <li>الـ <code>MVP</code> والـ <code>player_stats</code> والتقييمات ستظل غير موثوقة</li>
  <li>الـ <code>fan voting</code> و<code>ratings</code> و<code>fantasy</code> ستبقى مرتبطة ببيانات ناقصة</li>
</ul>

<p>
هذه أيضًا فجوة <code>P0</code>.
</p>

<h3>F-03 — لا يوجد تمثيل صحيح لانتماء اللاعب الضيف إلى فريق ضيف</h3>

<p>
كيان <code>GuestPlayer</code> في <code>lib/domain/entities/guest_player.dart</code> يحتوي على:
</p>

<ul>
  <li><code>teamId</code></li>
  <li><code>tournamentId</code></li>
</ul>

<p>
لكنه لا يحتوي على:
</p>

<ul>
  <li><code>guestTeamId</code></li>
</ul>

<p>
وهذا يعني أنه لا يوجد مصدر حقيقة نظيف يحدد:
</p>

<p>
هذا اللاعب الضيف يتبع أي فريق ضيف بالضبط؟
</p>

<p>
الأثر العملي ظهر بوضوح في <code>lib/features/match/controllers/matchday_controller.dart</code>:
</p>

<ul>
  <li>عند تحميل جانب فريق ضيف، يتم جلب <code>كل</code> لاعبي البطولة الضيوف من <code>getTournamentGuestPlayers</code></li>
  <li>ثم يُعرضون كمرشحين لذلك الفريق الضيف</li>
</ul>

<p>
هذه مشكلة حرجة جدًا لأن معناها:
</p>

<ul>
  <li>الفريق الضيف قد يرى لاعبي فريق ضيف آخر</li>
  <li>قد يتم اختيار لاعب غير تابع لهذا الفريق في <code>check-in</code> أو <code>lineup</code></li>
  <li>الحسابات والنتائج تصبح غير موثوقة</li>
</ul>

<p>
هذه فجوة <code>P0</code> وهي أهم نقطة في مسار الفرق الضيفة.
</p>

<h3>F-04 — لا توجد شاشة roster تشغيلية للفرق الضيفة داخل البطولة</h3>

<p>
المنظم يستطيع حاليًا:
</p>

<ul>
  <li>إنشاء <code>GuestTeam</code> من شاشة <code>tournament_guest_team_create</code></li>
  <li>اعتماده داخل التسجيلات</li>
  <li>إضافته كمشارك داخل البطولة</li>
</ul>

<p>
لكنه لا يستطيع داخل موديول البطولة نفسه:
</p>

<ul>
  <li>فتح roster للفريق الضيف</li>
  <li>إضافة لاعبين ضيوف له</li>
  <li>تعديل بيانات اللاعب الضيف</li>
  <li>تحديد مركزه أو رقم القميص</li>
  <li>تحديد القائد</li>
  <li>إزالة لاعب ضيف أو استبداله</li>
</ul>

<p>
الـ roster الحالية موجودة لفريق مسجل فقط عبر:
</p>

<ul>
  <li><code>TeamRosterService</code></li>
  <li><code>TeamRosterController</code></li>
  <li><code>TeamRosterScreen</code></li>
</ul>

<p>
وهذا المسار يعتمد على كيان <code>Team</code> المسجل، وليس <code>GuestTeam</code>.
</p>

<p>
بالتالي طلبك منطقي جدًا: صلاحيات المنظم على الفرق الضيفة غير كافية حاليًا لتشغيل البطولة فعليًا.
</p>

<p>
هذه فجوة <code>P0</code>.
</p>

<h3>F-05 — طبقة الصلاحيات الحالية عامة أكثر من اللازم</h3>

<p>
الخدمة <code>lib/core/services/tournament_permission_service.dart</code> توفر صلاحيات عامة مثل:
</p>

<ul>
  <li><code>canEditResults</code></li>
  <li><code>canManageTeams</code></li>
  <li><code>canEditSettings</code></li>
  <li><code>canAssignAssistants</code></li>
</ul>

<p>
لكن لا توجد صلاحيات صريحة لـ:
</p>

<ul>
  <li><code>canManageGuestTeams</code></li>
  <li><code>canManageGuestRoster</code></li>
  <li><code>canStartFixtures</code></li>
  <li><code>canPublishFixtures</code></li>
  <li><code>canShareGuestClaims</code></li>
  <li><code>canVerifyMatchdayLineup</code></li>
</ul>

<p>
الأثر:
</p>

<ul>
  <li>الصلاحيات ستظل مبهمة عند توسيع الـ guest operations</li>
  <li>المساعدون قد يحصلون على وصول أوسع أو أضيق من المطلوب</li>
  <li>سيصعب توسيع مسار الفرق الضيفة بشكل منضبط</li>
</ul>

<p>
هذه فجوة <code>P1</code>.
</p>

<h3>F-06 — الفنتازي الحالية لا تدعم اللاعبين الضيوف دعمًا حقيقيًا</h3>

<p>
الفنتازي الحالية مبنية على:
</p>

<ul>
  <li><code>FantasySlot.playerId</code></li>
  <li><code>PlayerFantasyValue.playerId</code></li>
  <li><code>FantasyMarketService</code> الذي يقرأ من <code>PlayerRepository</code></li>
  <li><code>FantasyRoundSettlementService</code> الذي يحسب النقاط من <code>playerId</code> فقط</li>
</ul>

<p>
هذا يعني أن الفنتازي تفترض أن كل لاعب له حساب <code>Player</code> مسجل داخل النظام.
</p>

<p>
لكن اللاعب الضيف اليوم هو:
</p>

<ul>
  <li><code>GuestPlayer</code></li>
  <li>وليس له <code>PlayerFantasyValue</code></li>
  <li>وليس له presence داخل السوق</li>
  <li>وليس له حضور صحيح داخل <code>FantasySlot</code></li>
</ul>

<p>
النتيجة:
</p>

<ul>
  <li>لا يمكن تشغيل فنتازي متوازية صحيحة لبطولة فيها لاعبون ضيوف بشكل احترافي كامل</li>
  <li>وأي محاولة ترقيع مباشرة فوق <code>playerId</code> الحالي ستخلق دينًا تقنيًا كبيرًا</li>
</ul>

<p>
هذه فجوة <code>P0</code> إذا كان المطلوب Fantasy موازية تشمل البطولات المختلطة فعليًا.
</p>

<h3>F-07 — Lifecycle الفنتازي ليست موصولة بالكامل بمراحل البطولة التشغيلية</h3>

<p>
الخدمة <code>FantasyLifecycleService</code> تستنتج lifecycle من <code>Tournament.status</code> كـ fallback جيد، لكن لا توجد orchestration كاملة تضمن:
</p>

<ul>
  <li>فتح الجولة عند اللحظة الصحيحة</li>
  <li>قفلها قبل بدء المباريات</li>
  <li>تشغيل settlement بعد اكتمال النتائج الرسمية للمرحلة</li>
  <li>تمييز اللاعبين المُقصين وتفعيل مسار <code>emergency transfer</code></li>
</ul>

<p>
والدليل أن <code>EmergencyTransferService</code> موجود لكنه غير موصول بمسار البطولة الفعلي.
</p>

<p>
هذه فجوة <code>P1</code>.
</p>

<h3>F-08 — الفريق الضيف يمكن إنشاؤه بدون roster ابتدائي</h3>

<p>
شاشة إنشاء الفريق الضيف الحالية تنشئ:
</p>

<ul>
  <li><code>GuestTeam</code></li>
</ul>

<p>
لكنها لا تنشئ تلقائيًا:
</p>

<ul>
  <li>قائدًا ضيفًا</li>
  <li>Roster ابتدائية</li>
  <li>حدًا أدنى من اللاعبين</li>
</ul>

<p>
الأثر:
</p>

<ul>
  <li>يمكن اعتماد participant لا يملك roster جاهزة أصلًا</li>
  <li>المشكلة تظهر متأخرًا داخل <code>matchday</code></li>
</ul>

<p>
هذه فجوة <code>P1</code>.
</p>

<h2>السيناريوهات العملية وما الذي يحدث فيها الآن</h2>

<h3>السيناريو 1 — بطولة كلها فرق مسجلة</h3>

<p>
الحالة الحالية:
</p>

<ul>
  <li>التسجيل جيد</li>
  <li>المشاركون جيدون</li>
  <li>المجموعات والـ fixtures جيدة</li>
  <li>لكن ما زال ينقص <code>Start Match</code></li>
  <li>وما زالت النتيجة معتمدة على <code>teamAPlayerIds/teamBPlayerIds</code> بدل lineup snapshot</li>
</ul>

<p>
الحكم:
</p>

<p>
المسار قريب من الاكتمال لكنه ليس production-complete بعد.
</p>

<h3>السيناريو 2 — بطولة فيها فرق ضيفة بدون claim</h3>

<p>
الحالة الحالية:
</p>

<ul>
  <li>يمكن إنشاء الفريق الضيف واعتماده</li>
  <li>لكن لا توجد roster تشغيليًا واضحة له داخل البطولة</li>
  <li>ولا يوجد عزل صحيح للاعبيه عن باقي الضيوف في البطولة</li>
</ul>

<p>
الحكم:
</p>

<p>
هذا السيناريو غير آمن حاليًا ولا ينبغي اعتباره جاهزًا.
</p>

<h3>السيناريو 3 — فريق ضيف يلعب مباراة مجموعات ويجب إدخال النتيجة</h3>

<p>
الحالة الحالية:
</p>

<ul>
  <li>يمكن الوصول إلى <code>matchday</code></li>
  <li>لكن اختيار اللاعبين غير معزول بشكل صحيح</li>
  <li>ولا يوجد <code>Start Match</code></li>
  <li>ومسار <code>Score Submit</code> نفسه لا يدعم guest roster دعمًا حقيقيًا</li>
</ul>

<p>
الحكم:
</p>

<p>
هذا السيناريو مكسور وظيفيًا الآن.
</p>

<h3>السيناريو 4 — بطولة Fantasy موازية فيها لاعبون ضيوف</h3>

<p>
الحالة الحالية:
</p>

<ul>
  <li>غير مدعومة معماريًا بشكل صحيح</li>
  <li>لأن الفنتازي تعتمد على <code>playerId</code> المسجل، وليس على هوية تنافسية موحدة للاعب داخل البطولة</li>
</ul>

<p>
الحكم:
</p>

<p>
هذا السيناريو غير جاهز حاليًا، وأي تشغيل له الآن سيكون شكليًا أكثر من كونه صحيحًا.
</p>

<h2>ماذا نحتاج بخصوص صلاحيات المنظم على الفرق الضيفة؟</h2>

<p>
لكي يعمل هذا المسار بشكل احترافي، نحتاج إضافة صلاحيات واضحة ومباشرة للمنظم ومساعديه الموثوقين.
</p>

<p>
الحد الأدنى المطلوب:
</p>

<ul>
  <li><code>canManageGuestTeams</code></li>
  <li><code>canManageGuestRoster</code></li>
  <li><code>canCreateGuestPlayers</code></li>
  <li><code>canEditGuestPlayers</code></li>
  <li><code>canArchiveGuestPlayers</code></li>
  <li><code>canIssueGuestClaimLinks</code></li>
  <li><code>canStartMatch</code></li>
  <li><code>canSubmitScore</code></li>
  <li><code>canApproveScore</code></li>
</ul>

<p>
ويجب أن تكون هذه الصلاحيات مربوطة بأدوار المساعدين الحالية، وليس فقط بالمنظم الرئيسي.
</p>

<h2>التوصية المعمارية الصحيحة للفرق الضيفة</h2>

<p>
التوصية الصحيحة بمنهج <code>production-first</code> هي:
</p>

<ol>
  <li>إضافة <code>guestTeamId</code> صريح داخل <code>GuestPlayer</code></li>
  <li>بناء <code>GuestTeamRosterService</code> أو <code>TournamentGuestRosterService</code> بدل محاولة استخدام <code>TeamRosterService</code> الحالية كما هي</li>
  <li>إضافة شاشة <code>Guest Team Roster</code> داخل موديول البطولة نفسه</li>
  <li>إتاحة للمنظم: إضافة لاعب ضيف، تعديل المركز، رقم القميص، ملاحظات، حذف أو أرشفة، مشاركة رابط claim</li>
  <li>ربط <code>Matchday</code> بهذا الـ roster بدل جلب كل لاعبي البطولة الضيوف</li>
  <li>عند قفل التشكيل، يتم ترحيل الـ lineup الرسمية إلى كيان المباراة أو إلى <code>MatchRosterProjection</code> واضح</li>
</ol>

<h2>التوصية الصحيحة لمسار النتيجة</h2>

<p>
المسار الصحيح يجب أن يصبح:
</p>

<p>
<code>open -> check-in -> lineup lock -> start match -> live roster projection -> submit score -> approve score -> standings/bracket refresh</code>
</p>

<p>
ويجب أن يعتمد <code>ScoreSubmit</code> على roster المباراة الفعلية، لا على <code>teamAPlayerIds/teamBPlayerIds</code> العامة فقط.
</p>

<h2>كيف يجب تنفيذ Fantasy موازية بشكل صحيح؟</h2>

<p>
إذا كنا نريد Fantasy موازية لبطولة قد تحتوي على لاعبين ضيوف، فهناك قرار معماري مهم:
</p>

<ul>
  <li>إما أن نقول إن Fantasy v1 تدعم فقط اللاعبين المسجلين داخل التطبيق</li>
  <li>أو نبني طبقة موحدة للاعب التنافسي داخل البطولة</li>
</ul>

<p>
التوصية الاحترافية هي الثانية، لكن على مرحلتين:
</p>

<h3>المرحلة A — تشغيل البطولة أولًا</h3>

<ul>
  <li>إكمال guest roster</li>
  <li>إكمال match start</li>
  <li>إكمال score flow الصحيح</li>
</ul>

<h3>المرحلة B — بناء طبقة لاعب تنافسي موحد للفنتازي</h3>

<p>
مثال اسم مناسب:
</p>

<ul>
  <li><code>CompetitionPlayer</code></li>
  <li>أو <code>TournamentAthlete</code></li>
</ul>

<p>
ويحمل:
</p>

<ul>
  <li><code>id</code></li>
  <li><code>tournamentId</code></li>
  <li><code>participantId</code></li>
  <li><code>sourceType: registered / guest</code></li>
  <li><code>playerId?</code></li>
  <li><code>guestPlayerId?</code></li>
  <li><code>displayName</code></li>
  <li><code>position</code></li>
  <li><code>jerseyNumber</code></li>
  <li><code>isFantasyEligible</code></li>
</ul>

<p>
وعندها تصبح:
</p>

<ul>
  <li>الـ lineups</li>
  <li>الـ match stats</li>
  <li>الـ MVP</li>
  <li>الـ fan voting</li>
  <li>الـ fantasy slots</li>
</ul>

<p>
كلها مبنية على هوية موحدة واحدة، بدل تشتيتها بين <code>Player</code> و<code>GuestPlayer</code>.
</p>

<p>
أما إذا لم نرد فتح هذا المسار الآن، فالتوصية الواضحة هي:
</p>

<p>
عدم تفعيل Fantasy مرتبطة بالبطولة إذا كانت تحتوي على لاعبين ضيوف غير مُمثلين داخل طبقة Fantasy الصحيحة.
</p>

<h2>الترتيب المقترح للتنفيذ من الآن</h2>

<ol>
  <li>إضافة <code>Start Match</code> داخل موديول البطولة</li>
  <li>تحويل lineup المقفولة إلى roster رسمية للمباراة قبل <code>Score Submit</code></li>
  <li>إضافة <code>guestTeamId</code> إلى <code>GuestPlayer</code></li>
  <li>بناء <code>Guest Team Roster Screen</code> داخل البطولة مع صلاحيات المنظم</li>
  <li>ربط <code>Matchday</code> بالـ guest roster الصحيحة بدل قائمة ضيوف البطولة العامة</li>
  <li>بعد ذلك فقط نقرر إما:
    <ul>
      <li>Fantasy v1 لللاعبين المسجلين فقط</li>
      <li>أو بناء <code>CompetitionPlayer</code> لتشغيل Fantasy شاملة للضيوف</li>
    </ul>
  </li>
</ol>

<h2>الحكم النهائي</h2>

<p>
مشكلة الفرق الضيفة الحالية ليست مجرد نقص شاشة أو زر.
</p>

<p>
المشكلة أعمق من ذلك:
</p>

<ul>
  <li>لا يوجد ownership domain واضح للاعب الضيف داخل الفريق الضيف</li>
  <li>لا يوجد roster تشغيليًا واضحة للفرق الضيفة داخل البطولة</li>
  <li>مسار النتيجة غير موصول بالـ lineup الرسمية</li>
  <li>الفنتازي الحالية لا تملك abstraction صحيحًا يدعم الضيوف</li>
</ul>

<p>
لذلك:
</p>

<p>
نعم، يجب إضافة صلاحيات المنظم على تعديل الفرق الضيفة وإضافة لاعبين ضيوف.
</p>

<p>
لكن التنفيذ الصحيح لا يكون بزر isolated فقط، بل عبر:
</p>

<p>
<code>guest roster domain + permissions + matchday integration + score flow correction + fantasy decision</code>
</p>

<p>
وبدون هذه السلسلة، ستظل البطولة تعمل جيدًا مع الفرق المسجلة، لكنها ستتكسر أو تصبح غير موثوقة كلما دخلنا في سيناريوهات الضيوف والفنتازي الموازية.
</p>

</div>
