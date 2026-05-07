# El7reef Complete Product Blueprint — Draft 0

## 0. الهدف من الوثيقة

هذه الوثيقة ليست خطة تنفيذ، وليست قائمة Tasks. الهدف منها إيقاف البناء العشوائي، وتحديد نظام المنتج قبل كتابة كود جديد.

التطبيق ليس مجرد بطولات وفرق وماتشات. التطبيق الحقيقي هو نظام تشغيل رياضي صغير يتكوّن من:

- هوية لاعبين.
- أدوار وصلاحيات.
- فرق وعضويات.
- دعوات وانضمام.
- بطولات لها زمن وجدولة وترتيب مباريات.
- نتائج واعتماد ونزاعات.
- إحصائيات وMVP وهدافين.
- Guest claim.
- مشاركة ونمو.
- حماية بيانات وعزل حسابات.

أي تنفيذ جديد قبل حسم هذه الوثيقة يزيد خطر بناء أجزاء متناقضة.

---

## 1. Product North Star

**الحريف** هو تطبيق لإدارة بطولات ومباريات كرة قدم صغيرة بطريقة اجتماعية وممتعة، حيث يكون اللاعب والفريق والبطولة لهم قيمة وسمعة وذكريات قابلة للمشاركة.

الهدف الأساسي في V1 ليس بناء شبكة اجتماعية كاملة، بل بناء دورة مغلقة صلبة:

```text
Organizer creates tournament
Teams join/register
Matches are scheduled
Results are submitted/approved
Goals + MVP are recorded
Leaderboards and profiles update
Players share pride moments
Guest players can claim identity safely
```

لو أي حل لا يخدم هذه الدورة، فهو خارج V1 أو يحتاج تبرير قوي.

---

## 2. مبادئ تصميم غير قابلة للكسر

### 2.1 الرؤية لا تعني الإدارة

رؤية بطولة أو فريق أو لاعب لا تمنح أي صلاحية تعديل.

مثال:

- Viewer يرى بطولة عامة فقط.
- Player يرى بطولة فريقه.
- Team Captain يدير فريقه فقط.
- Organizer يدير البطولة فقط.

### 2.2 كل Action حساس يحتاج 3 طبقات حماية

أي إجراء مثل تعديل بطولة، دعوة لاعب، اعتماد نتيجة، إرسال claim link، أو تغيير موعد يجب أن يتحقق في:

1. UI visibility.
2. Controller/service guard.
3. Firestore rules أو trusted backend.

لا يكفي إخفاء زر في الواجهة.

### 2.3 لا يوجد User-scoped screen بدون UID filter

أي شاشة اسمها: بطولاتي، فرقي، مبارياتي، دعواتي، إدارتي، لازم query بتاعها مربوط بالمستخدم الحالي أو بدور واضح.

### 2.4 التاريخ لا يتغير بتغير الواقع الحالي

المباراة التي لعبها لاعب يجب ألا تتغير إذا خرج من الفريق لاحقًا. لذلك نحتاج snapshots للأحداث التاريخية.

### 2.5 V1 يجب أن يكون محدودًا لكن متماسكًا

الأخطر من نقص ميزة هو وجود ميزة نصف مبنية بصلاحيات غير واضحة.

---

## 3. أنواع المستخدمين

| النوع | الوصف | ملاحظات |
|---|---|---|
| Anonymous visitor | غير مسجل | لا يفعل شيئًا حساسًا |
| Registered player | لاعب بحساب | أساس الهوية |
| Guest player | لاعب مؤقت بدون حساب | يظهر في rosters/events ويمكنه claim لاحقًا |
| Team owner/captain | يدير فريقًا | يدعو لاعبين، يقدم الفريق للبطولات |
| Vice captain | مساعد قائد | صلاحيات محدودة حسب التصميم |
| Tournament organizer | منظم بطولة | يدير بطولة واحدة أو أكثر |
| Match official/referee | حكم/مشرف مباراة | مؤجل غالبًا، لكن دوره مهم |
| Viewer/fan | يشاهد فقط | لا يدير أي شيء |
| Support/admin | دعم داخلي | ليس V1 app UI غالبًا |

---

## 4. Role Matrix — Draft 0

### 4.1 صلاحيات البطولة

| Action | Organizer | Team Captain | Vice Captain | Player | Guest | Viewer |
|---|---:|---:|---:|---:|---:|---:|
| Create tournament | نعم | ربما لاحقًا | لا | لا | لا | لا |
| Edit tournament settings | نعم | لا | لا | لا | لا | لا |
| Open/close registration | نعم | لا | لا | لا | لا | لا |
| Approve/reject team | نعم | لا | لا | لا | لا | لا |
| Generate fixtures | نعم | لا | لا | لا | لا | لا |
| Assign match time/venue | نعم | لا | لا | لا | لا | لا |
| Reschedule any match | نعم | لا | لا | لا | لا | لا |
| Submit team to tournament | لا | نعم لفريقه | ربما | لا | لا | لا |
| Withdraw team | لا | نعم لفريقه | ربما | لا | لا | لا |
| View public tournament | نعم | نعم | نعم | نعم | محدود | نعم |
| Open organizer operations | نعم فقط | لا | لا | لا | لا | لا |

### 4.2 صلاحيات الفريق

| Action | Team Owner | Captain | Vice Captain | Player | Guest | Viewer |
|---|---:|---:|---:|---:|---:|---:|
| Edit team info | نعم | نعم حسب التصميم | لا/محدود | لا | لا | لا |
| Invite registered player | نعم | نعم | ربما | لا | لا | لا |
| Add guest player | نعم | نعم | ربما | لا | لا | لا |
| Remove player | نعم | نعم | ربما | لا | لا | لا |
| Assign vice captain | نعم | ربما | لا | لا | لا | لا |
| Share guest claim link | نعم | نعم | ربما | لا | لا | لا |
| Submit score for team match | حسب نظام النتيجة | ربما | ربما | لا | لا | لا |

### 4.3 صلاحيات المباراة والنتيجة

| Action | Organizer | Team Captain | Player | Referee | Viewer |
|---|---:|---:|---:|---:|---:|
| Set match schedule | نعم | لا | لا | ربما كمقترح | لا |
| Submit score | نعم أو captain حسب النظام | ربما | لا | نعم إن وجد | لا |
| Approve score | نعم | لا أو تأكيد محدود | لا | ربما | لا |
| Dispute score | نعم | نعم لفريقه | ربما | لا | لا |
| Lock final result | نعم | لا | لا | ربما | لا |
| Edit completed result | نعم مع audit | لا | لا | لا | لا |

---

## 5. Canonical Domain Entities

### 5.1 Identity

- `Player`
- `GuestPlayer`
- `PublicPlayerProfile`
- `ClaimCode`
- `ClaimPayload`

### 5.2 Teams

- `Team`
- `TeamMembership`
- `TeamInvite`
- `TeamRole`
- `GuestTeam` إن كان موجودًا في النظام

### 5.3 Tournaments

- `Tournament`
- `TournamentRole` أو organizer field واضح
- `TournamentTeamRegistration`
- `TournamentTeam`
- `TournamentStage`
- `TournamentGroup`
- `TournamentStanding`

### 5.4 Scheduling

- `Fixture`
- `Match`
- `MatchSide`
- `MatchSideSource`
- `TimeSlot`
- `Venue`
- `Court`

### 5.5 Match events and stats

- `MatchEvent`
- `ParticipantRef`
- `MatchLineupSnapshot`
- `MatchParticipantSnapshot`
- `PlayerMatchStats` legacy/registered-only إن وجد

### 5.6 Workflow/support

- `Invite`
- `FriendRequest`
- `Challenge`
- `Notification`
- `AuditEvent`
- `Dispute`

---

## 6. Source of Truth Map

| المعلومة | المصدر الرسمي | مشتقة في | مين يغيرها |
|---|---|---|---|
| هوية اللاعب المسجل | `players/{uid}` | public profile, search | اللاعب/النظام |
| الضيف | `guestPlayers/{id}` | rosters, public guest profile | team manager/organizer |
| claim token | `claimCodes/{code}` | claim links فقط | ShareLinkService / claim flow |
| عضوية الفريق | `teamMemberships` | roster UI, permissions | owner/captain/rules |
| دور اللاعب داخل الفريق | `teamMembership.role` | buttons/guards | owner/captain/rules |
| منظم البطولة | `tournaments.organizerId` أو `tournamentRoles` | tournament operations | creator/system |
| مشاركة فريق في بطولة | `tournamentTeamRegistrations` | tournament teams/fixtures | captain + organizer |
| جدول المباراة | `matches.scheduledAt/round/venue` | calendar, matchday | organizer |
| نتيجة المباراة | approved `Match` result | standings/share cards | organizer/approval flow |
| أهداف/MVP | `matchEvents` | top scorers/profile/cards | score submit بعد تحقق |
| الترتيب | computed من approved matches | standings UI | resolver/system |
| التشكيلة التاريخية | lineup snapshot | result view/events | قبل/وقت المباراة |

قاعدة مهمة: لو data مشتقة اختلفت مع source، المصدر الرسمي يكسب.

---

## 7. State Machines

### 7.1 Tournament lifecycle

```text
draft
registration_open
registration_closed
fixtures_draft
scheduled
in_progress
completed
cancelled
archived
```

قواعد أولية:

- لا توليد fixtures قبل وجود فرق approved كافية.
- لا تعديل format بعد `scheduled` إلا بصلاحية organizer وبـ audit.
- لا قبول فرق بعد `registration_closed` إلا override واضح.
- لا إلغاء بطولة completed؛ فقط archive.

### 7.2 Tournament team registration lifecycle

```text
not_submitted
pending
approved
rejected
withdrawn
disqualified
```

### 7.3 Match lifecycle

```text
draft
scheduled
lineup_pending
ready
score_pending
score_submitted
under_review
disputed
approved
completed
postponed
cancelled
forfeit
```

### 7.4 Invite lifecycle

```text
pending
accepted
declined
expired
revoked
```

### 7.5 Claim lifecycle

```text
not_invited
invited
opened
claimed
conflict
expired
revoked
```

---

## 8. Tournament Structure

### 8.1 V1 tournament formats

V1 لا يجب أن يحاول دعم كل شيء. المقترح:

1. Single elimination بسيط.
2. Round robin بسيط لمجموعات صغيرة.
3. Groups + knockout يؤجل أو يدخل كـ V1.1 إذا كان موجودًا جزئيًا.

### 8.2 أسئلة يجب حسمها

- أقل عدد فرق؟ 4؟
- أقصى عدد فرق في V1؟ 8؟ 16؟
- هل عدد فردي مسموح؟
- هل التعادل مسموح؟
- هل الفرق تدخل مباشرة أم بموافقة organizer؟
- هل يمكن تغيير format بعد قبول فرق؟ غالبًا لا.

---

## 9. Tournament Scheduling & Fixture Order

### 9.1 لماذا الجدولة مركزية؟

البطولة ليست قائمة مباريات فقط. البطولة عملية زمنية:

```text
registration window
approved teams
fixture generation
round order
match schedule
venue/court assignment
result deadlines
reschedule/no-show handling
```

### 9.2 Tournament time fields

| Field | Required in V1? | Notes |
|---|---:|---|
| `registrationOpenAt` | نعم | بداية التسجيل |
| `registrationCloseAt` | نعم | لا fixtures نهائية قبلها إلا override |
| `tournamentStartAt` | نعم | بداية البطولة |
| `tournamentEndAt` | اختياري | تقديري |
| `timezone` | نعم | لا مواعيد بلا timezone strategy |
| `matchDurationMinutes` | نعم | default حسب sport |
| `bufferMinutes` | اختياري | بين المباريات |
| `schedulingMode` | نعم | manual / generated_pairings / full_auto |
| `resultDeadlineMinutes` | لاحقًا | بعد الموعد |
| `disputeDeadlineMinutes` | لاحقًا | بعد النتيجة |

### 9.3 Match schedule fields

| Field | Required in V1? | Notes |
|---|---:|---|
| `roundNumber` | نعم | ترتيب الجولة |
| `matchNumber` | نعم | ترتيب المباراة داخل البطولة |
| `stage` | نعم | group / knockout / final |
| `scheduledAt` | نعم أو nullable مؤقت | يفضل إجباري قبل publish |
| `venueName` | اختياري V1 | Venue entity لاحقًا |
| `courtName` | اختياري | لو أكثر من ملعب |
| `estimatedEndAt` | مشتق | من duration |
| `status` | نعم | scheduled/postponed/completed/etc |
| `dependsOn` | V1.1 | knockout dependency |

### 9.4 V1 scheduling mode المقترح

V1 لا يبدأ بـ auto-scheduler معقد. الأفضل:

```text
- Organizer creates tournament.
- Organizer sets registration close date.
- Organizer approves teams.
- App generates fixture pairings/order.
- Organizer manually assigns date/time/venue.
- App blocks obvious conflicts.
```

### 9.5 Conflict rules V1

- نفس الفريق لا يلعب مباراتين في نفس الوقت.
- المباراة لا تبدأ قبل إغلاق التسجيل.
- completed match لا يعاد جدولته إلا بصلاحية organizer وبـ audit.
- scheduledAt لا يكون null عند publish final fixtures.

### 9.6 يؤجل من V1

- player availability calendar.
- multi-venue optimization.
- automatic optimal scheduling.
- referee assignment.
- complex dependency graph لكل formats.

---

## 10. Fixtures Dependency Graph

للـ knockout، المباراة قد تعتمد على نتيجة مباراة سابقة.

نموذج مطلوب لاحقًا:

```text
MatchSideSource
- type: team | winnerOfMatch | loserOfMatch | placeholder
- teamId?
- sourceMatchId?
- label?
```

V1 يمكن أن يبدأ بـ manual assignment أو generated placeholders، لكن لا نكذب على أنفسنا: knockout الحقيقي يحتاج dependency graph.

---

## 11. Team Membership, Invites, and Roster Lock

### 11.1 Team roles

```text
owner
captain
viceCaptain
player
pending
guest
removed
left
```

### 11.2 Team invite flow

```text
captain searches/selects player
send invite
player accepts/declines
membership becomes active
```

### 11.3 Guest player flow

```text
captain adds guest
player appears in roster/match events
claim link can be shared
registered user claims guest identity
future profile/stats merge policy applies
```

### 11.4 Roster lock

V1 يجب أن يقرر:

- هل roster يتقفل عند بداية البطولة؟
- هل الإضافة بعد القفل تحتاج organizer approval؟
- هل اللاعب يمكن أن يكون في فريقين داخل نفس البطولة؟ لا.
- هل guest يمكن أن يكون في فريقين داخل نفس البطولة؟ لا.

---

## 12. Match Lifecycle, Result Approval, and Disputes

### 12.1 V1 result model المقترح

أبسط نموذج قابل للإطلاق:

```text
score submitted
organizer reviews
approved/locked
```

لكن لو captain يدخل النتيجة، لازم نحدد:

- هل الخصم يوافق؟
- هل المنظم هو الحكم النهائي؟
- ماذا يحدث عند dispute؟

### 12.2 Dispute model

Minimum:

```text
Dispute
- matchId
- openedBy
- reason
- status: open/resolved/rejected
- createdAt
- resolvedBy?
- resolution?
```

### 12.3 Evidence

V1 ممكن يجعل evidence اختياريًا. لكن لازم نقرر هل:

- صورة النتيجة optional؟
- dispute يحتاج سبب؟
- المنظم يستطيع override؟

---

## 13. Ranking Rules & Tie-breakers

V1 standings يجب أن يوثق:

| Rule | V1 |
|---|---|
| Win points | 3 |
| Draw points | حسب هل التعادل مسموح |
| Loss points | 0 |
| Primary sort | points |
| Secondary | goalDifference |
| Third | goalsFor |
| Fourth | goalsAgainst أو manual |
| Head-to-head | V1.1 أو manual |
| Forfeit | 3-0 مثلًا، لا يحسب للهدافين |

لازم يظهر للمنظم/المستخدم إن tie-breaker النهائي قد يكون يدويًا في V1.

---

## 14. Guest Claim and Identity Merge

### 14.1 الحالي المقبول

- public guest profile لا يظهر claim CTA بدون token.
- token-aware CTA يظهر فقط مع code/type/targetId matching.
- organizer/captain يمكنه resend link من roster.
- claimCodes broad listing ممنوع.

### 14.2 الناقص

- إزالة `guestPlayers.claimCode` و `guestTeams.claimCode`.
- server-mediated claim completion.
- merge guest stats into registered profile.
- conflict recovery/support tool.

### 14.3 قرار V1

Guest claim مقبول كـ V1 guarded، لكن stats merge وserver-mediated verification V1.1.

---

## 15. Search, Friends, Invites, and Challenges

### 15.1 Search

أنواع البحث المطلوبة:

| Search target | Purpose |
|---|---|
| Player | friend/team invite/challenge |
| Team | tournament registration/challenge |
| Tournament | discovery/join/follow |
| Venue | scheduling لاحقًا |

### 15.2 Friends

Friends ليست شرطًا لكل شيء. يمكن في V1 دعوة لاعب لفريق بدون friend graph كامل، لكن يجب تحديد ذلك بوضوح.

### 15.3 Challenges

Challenges مؤجلة إن لم تخدم tournament V1. لا نعيد فتحها قبل استقرار roles/teams/matches.

---

## 16. Notifications and Deep Link Continuation

### 16.1 Notification model

```text
Notification
- userId
- type
- title
- body
- targetRoute
- readAt
- createdAt
```

### 16.2 أحداث تحتاج notification

- team invite.
- tournament registration accepted/rejected.
- match scheduled/rescheduled.
- score submitted/approved/disputed.
- claim link.
- MVP/top scorers share moment.

### 16.3 Deep link after login

لو مستخدم فتح claim link وهو logged out:

```text
open link
store pending deep link
login/register
resume exact route with query payload
```

هذا مفصلي. بدون هذا، claim flow يفشل في الواقع.

---

## 17. Privacy and Visibility

### 17.1 Tournament visibility

```text
public
private
inviteOnly
```

### 17.2 Profile visibility

- public player profile يظهر إحصائيات عامة.
- phone/email لا يظهران.
- guest profile يظهر اسمًا محدودًا وقد يكون قابلًا للclaim فقط عبر token.

### 17.3 Team roster visibility

يجب حسم:

- هل roster عام؟
- هل يظهر للفرق المشاركة فقط؟
- هل guest phone مخفي؟ نعم.

---

## 18. Session and Firestore Cache Isolation

هذه P0 بسبب bug الحسابات.

### 18.1 القواعد

- عند logout، كل user-scoped controllers تمسح state فورًا.
- عند UID switch، كل state القديم يُمسح قبل load الجديد.
- أي list اسمها my/owned/managed يجب أن تحتوي uid/role filter.
- Firestore cache لا يجب أن يسبب عرض بيانات حساب A في حساب B.

### 18.2 مطلوب لاحقًا

وثيقة مستقلة:

```text
Session Isolation Policy
```

تشمل:

- GetX lifecycle.
- FirebaseAuth state changes.
- Firestore persistence/clear strategy.
- account-switch tests.

---

## 19. Firestore Rules Strategy

### 19.1 لا يوجد write حساس بدون rules test

أي ownership/write path يحتاج rules emulator tests.

### 19.2 Collections تحتاج rules review

- players
- teams
- teamMemberships
- tournaments
- tournamentTeams/registrations
- matches
- matchEvents
- guestPlayers
- guestTeams
- claimCodes
- invites
- notifications
- auditEvents

### 19.3 Role enforcement

UI guards تساعد UX فقط. Firestore rules أو backend يجب أن يمنع:

- account B editing account A tournament.
- player managing organizer operations.
- participant approving teams.
- unauthorized score approval.

---

## 20. Audit Log

كل action حساس يجب أن يسجل:

```text
AuditEvent
- actorId
- action
- entityType
- entityId
- before?
- after?
- createdAt
- source: client/server
```

V1 يمكن أن يسجل داخليًا فقط، بدون UI.

---

## 21. Forfeit / No-show

V1 يحتاج قرار، حتى لو بسيط:

- من يعلن no-show؟ Organizer فقط.
- النتيجة الاعتبارية؟ 3-0 مثلًا.
- هل goals تحسب للهدافين؟ لا.
- هل standings تتأثر؟ نعم.

---

## 22. Environment and Release Safety

قبل release:

- dev Firebase.
- staging Firebase.
- production Firebase.
- rules deployment process.
- index deployment process.
- Android app links لكل environment.
- test accounts ثابتة.
- seed tournament.
- manual QA script.

لا يجوز اختبار account-switch أو claim flow على بيئة غير مفهومة.

---

## 23. Observability

نحتاج minimum events:

```text
login
logout
uid_switched
permission_denied
tournament_created
fixture_generated
match_rescheduled
score_submitted
score_approved
claim_link_shared
claim_opened
claim_submitted
claim_failed
```

مع منع تسجيل secrets مثل claim code raw في logs.

---

## 24. Migration and Legacy Data

بسبب تغييرات models/rules، يجب وضع policy:

```text
read old docs safely
write new docs with new schema
manual cleanup later
no destructive migration without backup
```

أسئلة:

- ماذا عن tournaments بلا organizerId واضح؟
- ماذا عن matches بلا scheduledAt؟
- ماذا عن guestPlayers فيها claimCode؟
- ماذا عن legacy statuses؟

---

## 25. V1 Scope — Draft

### يدخل V1

- Tournament creation بسيط.
- Team creation/roster.
- Guest players.
- Team registration/approval للبطولة.
- Manual/semi-manual fixture scheduling.
- Match scores.
- Organizer approval.
- Goals/MVP MatchEvents.
- Top scorers.
- Public profiles.
- Guest claim guarded flow.
- Share cards.
- Basic role enforcement.
- Basic rules emulator tests للـ critical writes.

### لا يدخل V1

- full friends graph.
- full challenges system.
- automatic optimal scheduler.
- venue booking.
- payments.
- referee system كامل.
- complex multi-stage leagues.
- advanced moderation.
- custom permissions.
- full admin dashboard.

---

## 26. V1.1 Scope — Draft

- Server-mediated guest claim completion.
- Remove raw `guestPlayers.claimCode` and `guestTeams.claimCode`.
- Guest-to-player stats merge.
- Notifications.
- Team invites to registered players.
- Friend/search system.
- Reschedule request flow.
- Venue/time slots.
- Referee/match official role.
- Stronger tournament role delegation.
- Admin/support tools.

---

## 27. P0/P1/P2 Risk Register

### P0

- Account B seeing/managing account A tournaments.
- User-scoped data leaking after logout/login switch.
- Firestore rules allowing unauthorized tournament/team/match writes.
- Public UI accidentally exposing management actions.

### P1

- No scheduling model.
- No team registration/approval clarity.
- No roster lock/eligibility rules.
- No result approval/dispute clarity.
- No deep link continuation after login.

### P2

- No full friends system.
- No full challenge system.
- No advanced notifications.
- No referee role.
- No automated optimal scheduling.

---

## 28. Required Design Documents Before More Code

1. `Product_Blueprint_Workflow_and_Roles.md`
2. `Role_Permission_Matrix.md`
3. `Tournament_Scheduling_Fixtures_Blueprint.md`
4. `Source_of_Truth_and_State_Machines.md`
5. `Session_Isolation_Policy.md`
6. `Firestore_Rules_Strategy.md`
7. `V1_Scope_and_Anti_Goals.md`

---

## 29. Immediate Non-Implementation Next Step

لا نرسل implementation task.

الخطوة التالية هي مراجعة هذه الوثيقة، ثم تحويلها إلى 3 وثائق أساسية:

1. Product workflow.
2. Permissions and roles.
3. Scheduling and match lifecycle.

بعدها فقط نقرر ما إذا كان Task 11 سيكون:

- session isolation fix،
- tournament ownership fix،
- role model refactor،
- أو إعادة ترتيب V1 scope.

