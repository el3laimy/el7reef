<div dir="rtl" align="right">

<h1>خطة إصلاح Tournament Module مقسمة إلى Tasks و Sprints</h1>

<h2>الغرض من الخطة</h2>

<p>
هذه الخطة تحول تقرير المشاكل إلى مسار تنفيذ عملي واضح للفريق.
</p>

<p>
الهدف ليس إضافة Features عشوائية، بل إصلاح الحلقة التشغيلية كاملة عبر:
</p>

<ul>
  <li>البطولة</li>
  <li>الفرق الضيفة</li>
  <li><code>matchday</code></li>
  <li>إدخال النتيجة واعتمادها</li>
  <li>والفنتازي الموازية</li>
</ul>

<h2>افتراضات التنفيذ</h2>

<ul>
  <li>نعمل بمنهج <code>production-first</code>.</li>
  <li>لا نركز حاليًا على <code>migration-heavy work</code>.</li>
  <li>البيانات الحالية اختبارية ويمكن reset لها عند الحاجة.</li>
  <li>لا نبدأ UI كبيرة قبل تثبيت الـ domain والـ service contracts.</li>
  <li>كل Sprint يجب أن تنتهي بمسار قابل للتجربة، وليس نصف بنية فقط.</li>
</ul>

<h2>تقسيم الخطة إلى مسارين</h2>

<h3>المسار A — إصلاح التشغيل الفعلي للبطولة</h3>

<p>
هذا المسار إلزامي ويجب تنفيذه أولًا.
</p>

<p>
بدونه لن تعمل البطولة بشكل صحيح حتى لو أهملنا الفنتازي مؤقتًا.
</p>

<h3>المسار B — تشغيل Fantasy موازية تدعم الفرق الضيفة فعليًا</h3>

<p>
هذا المسار يأتي بعد تثبيت التشغيل الفعلي للبطولة.
</p>

<p>
وهو مطلوب فقط إذا كنا نريد Fantasy صحيحة للبطولات التي تحتوي على لاعبين ضيوف.
</p>

<h2>القاعدة الأساسية قبل التقسيم إلى Sprints</h2>

<p>
إذا أردنا إطلاق البطولة بسرعة مع جودة عالية:
</p>

<ul>
  <li>ننهي المسار A أولًا بالكامل</li>
  <li>ثم نقرر هل نفتح المسار B الآن أم نؤجل Mixed Fantasy قليلًا</li>
</ul>

<p>
هذا يمنع تضارب التطوير ويمنع خلط موضوعين كبيرين في وقت واحد.
</p>

<h2>حجم السبرنت المقترح</h2>

<ul>
  <li>كل <code>Sprint</code> = من 5 إلى 7 أيام عمل فعلية</li>
  <li>كل Sprint لها هدف واحد رئيسي</li>
  <li>كل Sprint تنتهي بـ <code>DoD</code> واضح</li>
</ul>

<h2>المسار A — إصلاح تشغيل البطولة</h2>

<h3>Sprint 1 — Match Activation and Live Result Flow</h3>

<p>
هدف الـ Sprint:
</p>

<p>
إصلاح المسار من <code>open</code> إلى <code>live</code> إلى <code>submit score</code> بحيث تصبح مباراة البطولة قابلة للعب فعليًا.
</p>

<h4>Tasks</h4>

<ul>
  <li><code>TOS-FIX-001</code>: إضافة <code>startMatch</code> command داخل <code>TournamentLifecycleService</code> أو <code>TournamentFixtureService</code>.</li>
  <li><code>TOS-FIX-002</code>: إضافة زر <code>Start Match</code> داخل <code>Tournament Operations Dashboard</code> و<code>Fixtures</code>.</li>
  <li><code>TOS-FIX-003</code>: منع <code>startMatch</code> إذا لم يكن هناك <code>check-in</code> و<code>lineup lock</code> للطرفين.</li>
  <li><code>TOS-FIX-004</code>: عند <code>startMatch</code> يتم إنشاء <code>live roster projection</code> من lineup المقفولة.</li>
  <li><code>TOS-FIX-005</code>: تعديل <code>ScoreSubmitController</code> ليقرأ roster المباراة الفعلية بدل الاعتماد على <code>teamAPlayerIds/teamBPlayerIds</code> الخام فقط.</li>
  <li><code>TOS-FIX-006</code>: تعديل <code>fan voting</code> و<code>match settlement</code> ليستخدما roster المباراة الفعلية.</li>
  <li><code>TOS-FIX-007</code>: إضافة اختبارات خدمة وواجهة لمسار <code>open -> live -> submit -> approve</code>.</li>
</ul>

<h4>Definition of Done</h4>

<ul>
  <li>يمكن بدء مباراة بطولة من الـ UI.</li>
  <li>يمكن إدخال النتيجة من نفس Flow البطولة بشكل طبيعي.</li>
  <li>لا يتم فتح إدخال النتيجة قبل تحقق الجاهزية التشغيلية.</li>
  <li>المسار يعمل على فرق مسجلة بشكل كامل.</li>
</ul>

<h4>التوازي الآمن</h4>

<ul>
  <li>مطور 1: service + state transition</li>
  <li>مطور 2: UI + controller wiring</li>
  <li>مطور 3: tests فقط بعد تثبيت interfaces</li>
</ul>

<h3>Sprint 2 — Guest Team Roster Domain and Permissions</h3>

<p>
هدف الـ Sprint:
</p>

<p>
إعطاء الفرق الضيفة roster حقيقية داخل البطولة مع صلاحيات واضحة للمنظم.
</p>

<h4>Tasks</h4>

<ul>
  <li><code>TOS-FIX-008</code>: إضافة <code>guestTeamId</code> إلى <code>GuestPlayer</code> و<code>GuestPlayerModel</code>.</li>
  <li><code>TOS-FIX-009</code>: إضافة queries في <code>GuestPlayerRepository</code> مثل <code>getGuestTeamPlayers(guestTeamId)</code>.</li>
  <li><code>TOS-FIX-010</code>: بناء <code>TournamentGuestRosterService</code> أو <code>GuestTeamRosterService</code>.</li>
  <li><code>TOS-FIX-011</code>: إضافة أوامر <code>createGuestPlayer</code>, <code>updateGuestPlayer</code>, <code>archiveGuestPlayer</code>, <code>setCaptain</code>.</li>
  <li><code>TOS-FIX-012</code>: توسيع <code>TournamentPermissionService</code> بصلاحيات صريحة: <code>canManageGuestTeams</code> و<code>canManageGuestRoster</code> و<code>canIssueGuestClaims</code>.</li>
  <li><code>TOS-FIX-013</code>: ربط صلاحيات المساعدين بهذه الأوامر بدل الاعتماد على <code>canManageTeams</code> العامة فقط.</li>
  <li><code>TOS-FIX-014</code>: إضافة audit events لعمليات guest roster.</li>
  <li><code>TOS-FIX-015</code>: اختبارات service وrepository على ownership وعزل اللاعبين الضيوف.</li>
</ul>

<h4>Definition of Done</h4>

<ul>
  <li>كل لاعب ضيف يعرف الفريق الضيف الذي ينتمي إليه صراحة.</li>
  <li>يمكن للمنظم إضافة لاعبين ضيوف لفريق ضيف داخل البطولة.</li>
  <li>لا يوجد أي خلط بين لاعبي فريق ضيف وآخر.</li>
</ul>

<h4>التوازي الآمن</h4>

<ul>
  <li>مطور 1: entity/model/repository</li>
  <li>مطور 2: permissions + audit</li>
  <li>مطور 3: tests</li>
</ul>

<h3>Sprint 3 — Guest Team Roster UI and Matchday Integration</h3>

<p>
هدف الـ Sprint:
</p>

<p>
إتاحة roster الفرق الضيفة من لوحة التشغيل وربطها مباشرة بـ <code>matchday</code>.
</p>

<h4>Tasks</h4>

<ul>
  <li><code>TOS-FIX-016</code>: بناء شاشة <code>Guest Team Roster</code> داخل موديول البطولة.</li>
  <li><code>TOS-FIX-017</code>: إضافة deep links من <code>Participants</code> و<code>Fixtures</code> إلى roster الفريق الضيف.</li>
  <li><code>TOS-FIX-018</code>: تعديل <code>MatchdayController</code> ليحمّل لاعبي الفريق الضيف من <code>guestTeamId</code> فقط.</li>
  <li><code>TOS-FIX-019</code>: إزالة السلوك الحالي الذي يجلب كل ضيوف البطولة عند إدارة فريق ضيف.</li>
  <li><code>TOS-FIX-020</code>: دعم claim link للاعب الضيف من شاشة roster نفسها.</li>
  <li><code>TOS-FIX-021</code>: دعم تعديل المركز ورقم القميص والملاحظات داخل roster.</li>
  <li><code>TOS-FIX-022</code>: اختبارات UI وintegration لهذا المسار.</li>
</ul>

<h4>Definition of Done</h4>

<ul>
  <li>المنظم يفتح roster الفريق الضيف من البطولة نفسها.</li>
  <li>يمكنه إضافة لاعبين ضيوف وتعديلهم.</li>
  <li><code>matchday</code> للفريق الضيف تعرض لاعبيه فقط.</li>
</ul>

<h4>التوازي الآمن</h4>

<ul>
  <li>مطور 1: service integration</li>
  <li>مطور 2: screens/controllers</li>
  <li>مطور 3: widget/integration tests</li>
</ul>

<h3>Sprint 4 — Guest Match Result Completion</h3>

<p>
هدف الـ Sprint:
</p>

<p>
جعل الفرق الضيفة قادرة على إنهاء المباراة بالكامل، من التشكيل إلى النتيجة إلى الاعتماد.
</p>

<h4>Tasks</h4>

<ul>
  <li><code>TOS-FIX-023</code>: تعديل <code>ScoreSubmit</code> لدعم roster تحتوي على لاعبين ضيوف ولاعبين مسجلين.</li>
  <li><code>TOS-FIX-024</code>: تعديل <code>MatchSettlementService</code> ليتعامل بشكل صحيح مع roster مختلطة.</li>
  <li><code>TOS-FIX-025</code>: دعم <code>MVP</code> و<code>player_stats</code> و<code>attendance truth</code> للضيف بشكل صحيح.</li>
  <li><code>TOS-FIX-026</code>: التأكد من أن اعتماد النتيجة يحدث <code>standings/bracket refresh</code> بنفس السلوك الحالي.</li>
  <li><code>TOS-FIX-027</code>: اختبارات end-to-end لمباراة مجموعات فيها فريق ضيف.</li>
</ul>

<h4>Definition of Done</h4>

<ul>
  <li>فريق ضيف يمكنه لعب مباراة مجموعات كاملة.</li>
  <li>يمكن إدخال نتيجته واعتمادها بدون workarounds.</li>
  <li>التحديثات التالية تعمل طبيعيًا: standings أو bracket.</li>
</ul>

<h3>Sprint 5 — Pilot Pass and Production Hardening</h3>

<p>
هدف الـ Sprint:
</p>

<p>
تجربة المسار الكامل على بيانات جديدة وتثبيت أي gaps تشغيلية متبقية.
</p>

<h4>Tasks</h4>

<ul>
  <li><code>TOS-FIX-028</code>: تنفيذ <code>pilot pass</code> كامل على بطولة فيها فرق مسجلة وفرق ضيفة.</li>
  <li><code>TOS-FIX-029</code>: تسجيل friction points الفعلية أثناء الاستخدام.</li>
  <li><code>TOS-FIX-030</code>: إصلاح أي gaps حرجة في الـ UX أو الـ permissions أو الـ state guards.</li>
  <li><code>TOS-FIX-031</code>: توسيع regression tests للمسارات التي ظهر فيها friction.</li>
</ul>

<h4>Definition of Done</h4>

<ul>
  <li>البطولة تعمل end-to-end مع guest teams تشغيليًا.</li>
  <li>لا توجد blockers حقيقية للمنظم في التشغيل اليومي.</li>
  <li>يمكن اعتبار المسار A مكتملًا عمليًا.</li>
</ul>

<h2>المسار B — Fantasy موازية تدعم guest players فعليًا</h2>

<p>
هذا المسار لا يجب أن يبدأ قبل اكتمال المسار A.
</p>

<p>
والسبب:
</p>

<p>
لا معنى لبناء Fantasy صحيحة فوق roster ومباريات ونتائج غير مستقرة.
</p>

<h3>Sprint 6 — Competition Player Core</h3>

<p>
هدف الـ Sprint:
</p>

<p>
بناء طبقة هوية موحدة للاعب التنافسي داخل البطولة، سواء كان مسجلًا أو ضيفًا.
</p>

<h4>Tasks</h4>

<ul>
  <li><code>TOS-FIX-032</code>: تعريف كيان جديد مثل <code>CompetitionPlayer</code> أو <code>TournamentAthlete</code>.</li>
  <li><code>TOS-FIX-033</code>: الحقول المقترحة: <code>id</code>, <code>tournamentId</code>, <code>participantId</code>, <code>sourceType</code>, <code>playerId?</code>, <code>guestPlayerId?</code>, <code>displayName</code>, <code>position</code>, <code>jerseyNumber</code>, <code>isFantasyEligible</code>.</li>
  <li><code>TOS-FIX-034</code>: بناء repository وخدمة لإنشاء وتحديث هذا الكيان من roster الفعلية.</li>
  <li><code>TOS-FIX-035</code>: ربط lineup و<code>player_stats</code> و<code>MVP</code> بهذه الهوية الموحدة بدل الاعتماد المباشر على <code>playerId</code> فقط.</li>
  <li><code>TOS-FIX-036</code>: اختبارات domain وservice للهوية الموحدة.</li>
</ul>

<h4>Definition of Done</h4>

<ul>
  <li>كل لاعب مؤثر في المباراة يملك هوية تنافسية موحدة داخل البطولة.</li>
  <li>الضيف والمسجل يدخلان نفس pipeline التشغيلي.</li>
</ul>

<h3>Sprint 7 — Mixed Fantasy Market and Slots</h3>

<p>
هدف الـ Sprint:
</p>

<p>
نقل الفنتازي من الاعتماد على <code>playerId</code> فقط إلى الاعتماد على <code>competitionPlayerId</code>.
</p>

<h4>Tasks</h4>

<ul>
  <li><code>TOS-FIX-037</code>: تعديل <code>FantasySlot</code> لتشير إلى <code>competitionPlayerId</code>.</li>
  <li><code>TOS-FIX-038</code>: بناء market values للاعبين الضيوف والمسجلين على نفس الطبقة.</li>
  <li><code>TOS-FIX-039</code>: تعديل <code>FantasyMarketService</code> و<code>FantasyCreateTeamController</code> و<code>FantasyTeamController</code>.</li>
  <li><code>TOS-FIX-040</code>: تعديل leaderboard وtransfer market لتستخدم الهوية الجديدة.</li>
  <li><code>TOS-FIX-041</code>: اختبارات UI وservice للمسار الجديد.</li>
</ul>

<h4>Definition of Done</h4>

<ul>
  <li>يمكن اختيار لاعب ضيف أو مسجل في فنتازي البطولة إذا كان <code>isFantasyEligible</code>.</li>
  <li>السوق والتشكيلة لا ينهاران في البطولات المختلطة.</li>
</ul>

<h3>Sprint 8 — Fantasy Settlement and Elimination Wiring</h3>

<p>
هدف الـ Sprint:
</p>

<p>
ربط نتائج البطولة واعتمادها بتسوية الفنتازي على الهوية الموحدة الجديدة.
</p>

<h4>Tasks</h4>

<ul>
  <li><code>TOS-FIX-042</code>: تعديل <code>FantasyRoundSettlementService</code> ليقرأ stats من <code>competitionPlayerId</code>.</li>
  <li><code>TOS-FIX-043</code>: ربط <code>TournamentLifecycle</code> بمراحل <code>FantasyLifecycle</code> بصورة صريحة.</li>
  <li><code>TOS-FIX-044</code>: تفعيل <code>EmergencyTransferService</code> عند الإقصاء الفعلي أو خروج الفريق.</li>
  <li><code>TOS-FIX-045</code>: إضافة smoke tests لمسار البطولة المختلطة + الفنتازي الموازية.</li>
</ul>

<h4>Definition of Done</h4>

<ul>
  <li>الفنتازي الموازية تعمل على بطولة فيها ضيوف ومسجلون.</li>
  <li>اعتماد النتيجة يؤثر على الفنتازي بشكل صحيح.</li>
  <li>الإقصاء والتبديلات الاضطرارية تعملان بصورة منطقية.</li>
</ul>

<h2>ما الذي يمكن تأجيله؟</h2>

<ul>
  <li>أي <code>migration</code> معقدة</li>
  <li>أي polish بصري إضافي لا يحل مشكلة تشغيلية</li>
  <li>أي توسيع اجتماعي أو Growth surface حول claim أو sharing beyond what is needed for operations</li>
</ul>

<h2>الخطة المختصرة إذا أردنا أسرع مسار آمن</h2>

<p>
إذا أردنا أسرع مسار عملي للإطلاق الداخلي أو التجربة الواقعية:
</p>

<ol>
  <li>نفذ Sprints 1 إلى 5 بالكامل</li>
  <li>بعد ذلك فعّل Fantasy فقط للبطولات التي لا تحتوي على guest players غير ممثلين</li>
  <li>ثم ابدأ Sprints 6 إلى 8 عندما نقرر أن Mixed Fantasy أصبحت أولوية مباشرة</li>
</ol>

<p>
هذا هو المسار الأقل مخاطرة والأكثر احترافية.
</p>

<h2>الحكم التنفيذي النهائي</h2>

<p>
أفضل تقسيم عملي الآن هو:
</p>

<ul>
  <li><strong>5 Sprints</strong> لإصلاح البطولة تشغيليًا بالكامل مع دعم guest teams</li>
  <li><strong>3 Sprints إضافية</strong> فقط إذا أردنا Fantasy موازية تدعم الضيوف فعليًا بشكل معماري صحيح</li>
</ul>

<p>
وبهذه الطريقة نتجنب:
</p>

<ul>
  <li>خلط النطاقات</li>
  <li>تضارب التطوير</li>
  <li>الترقيع فوق بنية fantasy لا تدعم الضيوف أصلًا</li>
</ul>

</div>
