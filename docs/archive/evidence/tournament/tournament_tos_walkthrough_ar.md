<div dir="rtl" align="right">

<h1>شرح آخر خطوة في Tournament TOS</h1>

<blockquote><strong>الحالة: HISTORICAL EVIDENCE.</strong> هذا شرح للخطوة المنفذة وقت اللقطة، وليس تعليمات تنفيذ حالية. المرجع التنفيذي الوحيد هو <code>docs/core/00_Master_Product_Development_Plan.md</code>&rlm;.</blockquote>

<h2>آخر خطوة تم تنفيذها</h2>

<p>
دخلنا فعليًا في <code>Tournament Repair Sprint 2</code> الخاصة بـ
<strong>Guest Team Roster Domain and Permissions</strong>.
</p>

<p>
التركيز في هذه الخطوة كان على إصلاح نقطة مهمة جدًا:
الفريق الضيف لم يكن يملك roster معزولة بشكل صحيح داخل البطولة،
وكانت بعض القراءات في <code>matchday</code> تعتمد على قائمة ضيوف على مستوى البطولة كلها،
وليس على مستوى الفريق الضيف المحدد.
</p>

<h2>ماذا تغيّر فعليًا؟</h2>

<h3>1. تصحيح نموذج Guest Player</h3>

<p>
في الملفات:
</p>

<ul>
  <li><code>lib/domain/entities/guest_player.dart</code></li>
  <li><code>lib/data/models/guest_player_model.dart</code></li>
</ul>

<p>
أصبح <code>GuestPlayer</code> يحمل <code>guestTeamId</code> بشكل صريح.
</p>

<p>
هذا يعني أن اللاعب الضيف لم يعد يُربط فقط بالبطولة أو بفريق مسجل،
بل أصبح يمكن ربطه مباشرة بالفريق الضيف الذي ينتمي إليه.
</p>

<h3>2. إضافة Query معزولة حسب الفريق الضيف</h3>

<p>
في:
</p>

<ul>
  <li><code>lib/domain/repositories/guest_player_repository.dart</code></li>
  <li><code>lib/data/repositories/guest_player_repository_impl.dart</code></li>
</ul>

<p>
تمت إضافة:
</p>

<ul>
  <li><code>getGuestTeamPlayers(guestTeamId)</code></li>
</ul>

<p>
وهذا هو الأساس الذي يمنع خلط لاعبي فريق ضيف بلاعبي فريق ضيف آخر داخل نفس البطولة.
</p>

<h3>3. بناء خدمة إدارة roster للفريق الضيف</h3>

<p>
تم إنشاء:
</p>

<ul>
  <li><code>lib/core/services/guest_team_roster_service.dart</code></li>
</ul>

<p>
الخدمة تدعم الآن:
</p>

<ul>
  <li><code>getGuestRoster</code></li>
  <li><code>createGuestPlayer</code></li>
  <li><code>updateGuestPlayer</code></li>
  <li><code>archiveGuestPlayer</code></li>
  <li><code>setCaptain</code></li>
</ul>

<p>
وبداخلها صلاحيات صريحة تمنع أي مستخدم غير مصرح له من إدارة roster الفريق الضيف.
</p>

<h3>4. توسيع صلاحيات البطولة</h3>

<p>
في:
</p>

<ul>
  <li><code>lib/core/services/tournament_permission_service.dart</code></li>
</ul>

<p>
أضفنا صلاحيات صريحة بدل الاعتماد غير الدقيق على <code>canManageTeams</code> فقط:
</p>

<ul>
  <li><code>canManageGuestTeams</code></li>
  <li><code>canManageGuestRoster</code></li>
  <li><code>canIssueGuestClaims</code></li>
</ul>

<p>
وبالتالي أصبح لدينا boundary أوضح لإدارة الفرق الضيفة ولاعبيها.
</p>

<h3>5. إضافة Audit لعمليات roster الضيف</h3>

<p>
في:
</p>

<ul>
  <li><code>lib/core/enums/audit_action.dart</code></li>
  <li><code>lib/core/services/tournament_audit_emitter.dart</code></li>
  <li><code>lib/features/organizer/controllers/audit_timeline_controller.dart</code></li>
</ul>

<p>
أضفنا أحداثًا جديدة مثل:
</p>

<ul>
  <li><code>guestPlayerUpdated</code></li>
  <li><code>guestPlayerArchived</code></li>
  <li><code>guestTeamCaptainUpdated</code></li>
</ul>

<p>
حتى تصبح تغييرات roster الفرق الضيفة قابلة للتتبع داخل سجل التدقيق.
</p>

<h3>6. إصلاح Matchday Guest Side</h3>

<p>
في:
</p>

<ul>
  <li><code>lib/features/match/controllers/matchday_controller.dart</code></li>
</ul>

<p>
تم إصلاح تحميل جهة الفريق الضيف في <code>matchday</code> لتقرأ:
</p>

<ul>
  <li>لاعبي الفريق الضيف المحدد فقط</li>
</ul>

<p>
بدل:
</p>

<ul>
  <li>كل لاعبي الضيوف في البطولة</li>
</ul>

<p>
وهذا إصلاح مهم جدًا لأنه يمنع تسرب لاعبين من فريق ضيف آخر إلى شاشة check-in أو lineup الخاصة بفريق مختلف.
</p>

<h3>7. توسيع ShareLink permissions بشكل آمن</h3>

<p>
في:
</p>

<ul>
  <li><code>lib/core/services/share_link_service.dart</code></li>
</ul>

<p>
أصبح إصدار claim link للاعب الضيف يفهم أيضًا سياق:
</p>

<ul>
  <li>الفريق الضيف</li>
  <li>البطولة</li>
  <li>صلاحيات المنظم أو المساعد المناسب</li>
</ul>

<p>
مع إصلاح lazy dependency حتى لا تنكسر الاختبارات أو المسارات التي لا تحتاج الوصول إلى البطولة.
</p>

<h2>الاختبارات التي أُضيفت أو توسعت</h2>

<ul>
  <li><code>test/data/repositories/guest_player_repository_impl_test.dart</code></li>
  <li><code>test/core/services/guest_team_roster_service_test.dart</code></li>
  <li><code>test/features/match/matchday_screen_test.dart</code></li>
</ul>

<p>
وأصبحت هذه الاختبارات تثبت:
</p>

<ul>
  <li>عزل لاعبي كل فريق ضيف عن الآخر</li>
  <li>صلاحيات إدارة roster للمنظم، منشئ الفريق الضيف، والمساعد الكامل</li>
  <li>منع المستخدم غير المصرح له</li>
  <li>أن <code>matchday</code> لا تعرض لاعبي فريق ضيف آخر</li>
</ul>

<h2>التحقق الذي تم تشغيله</h2>

<ul>
  <li><code>flutter analyze</code></li>
  <li><code>flutter test test/data/repositories/guest_player_repository_impl_test.dart test/core/services/guest_team_roster_service_test.dart test/core/services/share_link_service_test.dart test/features/match/matchday_screen_test.dart</code></li>
</ul>

<p>
وكلها مرّت بالكامل.
</p>

<h2>ماذا تعني هذه الخطوة في الخطة؟</h2>

<p>
هذا يعني أن Sprint 2 لم تعد <code>Ready</code> فقط، بل دخلت التنفيذ الفعلي، وتم إغلاق foundation الأساسية لها:
</p>

<ul>
  <li><code>TOS-FIX-008</code></li>
  <li><code>TOS-FIX-009</code></li>
  <li><code>TOS-FIX-010</code></li>
  <li><code>TOS-FIX-011</code></li>
  <li><code>TOS-FIX-012</code></li>
  <li><code>TOS-FIX-013</code></li>
  <li><code>TOS-FIX-014</code></li>
  <li><code>TOS-FIX-015</code></li>
</ul>

<p>
لكن ما زال هناك جزء مهم تالٍ:
</p>

<ul>
  <li>إظهار إدارة roster الفريق الضيف داخل واجهات البطولة نفسها</li>
  <li>ثم ربط هذا المسار بنتائج المباريات المختلطة والفنتازي الموازية</li>
</ul>

<h2>الخطوة التالية المنطقية</h2>

<p>
الخطوة التالية الآن هي بدء <code>Tournament Repair Sprint 3</code>:
</p>

<ul>
  <li>إضافة UI لإدارة roster الفريق الضيف داخل tournament operations</li>
  <li>ربط هذه الإدارة مع <code>matchday</code> و<code>score flow</code> بشكل كامل</li>
  <li>التحضير لاحقًا لمسار mixed roster الذي تحتاجه الفنتازي الموازية</li>
</ul>

</div>
