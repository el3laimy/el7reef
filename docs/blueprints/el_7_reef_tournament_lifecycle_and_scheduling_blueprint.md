# El7reef Tournament Lifecycle & Scheduling Blueprint — Draft 0

**Status:** `REFERENCE — NOT AN ACTIVE PLAN`&rlm;. Any implementation gap must be registered in `docs/core/00_Master_Product_Development_Plan.md`&rlm;.

## 0. الهدف من الوثيقة

هذه الوثيقة تحدد كيف تتحول البطولة من فكرة إلى بطولة مكتملة داخل تطبيق الحريف.

التركيز هنا على:

- مراحل البطولة.
- التسجيل وقبول الفرق.
- توليد وترتيب المباريات.
- المواعيد والجدولة.
- حالات المباراة.
- النتائج والاعتماد.
- ما يدخل V1 وما يؤجل.

القاعدة الحاكمة:

> البطولة ليست CRUD. البطولة كيان زمني له lifecycle، أدوار، مواعيد، ترتيب مباريات، ونتائج معتمدة.

---

## 1. V1 Tournament Philosophy

V1 يجب أن يدعم بطولة صغيرة حقيقية، وليس كل أنواع البطولات.

### V1 target

```text
4–8 teams
single organizer
simple format
manual/semi-manual scheduling
organizer-approved results
basic standings/pride stats
```

### V1 non-goals

- دوري طويل كامل.
- automatic optimal scheduler.
- venue booking.
- referee assignment.
- complex multi-stage dependency graph.
- custom role delegation.

---

## 2. Tournament Lifecycle

### 2.1 حالات البطولة المقترحة

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

### 2.2 معنى كل حالة

| State | المعنى | من يديرها |
|---|---|---|
| draft | البطولة أنشئت ولم تُفتح للتسجيل | Organizer |
| registration_open | الفرق يمكنها التقديم أو المنظم يضيف فرق | Organizer |
| registration_closed | لا قبول فرق جديد إلا override | Organizer |
| fixtures_draft | المباريات تولدت أو تُجهز ولم تُنشر نهائيًا | Organizer |
| scheduled | المباريات منشورة بمواعيدها | Organizer |
| in_progress | البطولة بدأت، بعض المباريات تُلعب أو انتهت | System/Organizer |
| completed | كل النتائج النهائية معتمدة | Organizer/System |
| cancelled | البطولة أُلغيت قبل اكتمالها | Organizer |
| archived | للعرض التاريخي فقط | System/Organizer |

### 2.3 انتقالات مسموحة

```text
draft -> registration_open
registration_open -> registration_closed
registration_closed -> fixtures_draft
fixtures_draft -> scheduled
scheduled -> in_progress
in_progress -> completed
any non-completed -> cancelled
completed -> archived
cancelled -> archived
```

### 2.4 انتقالات ممنوعة أو تحتاج override

- `completed -> cancelled`: ممنوع.
- `scheduled -> draft`: ممنوع.
- تغيير format بعد `fixtures_draft`: ممنوع إلا reset fixtures.
- قبول فريق جديد بعد `scheduled`: ممنوع إلا tournament override واضح.
- تعديل نتيجة بعد `completed`: ممنوع إلا admin/support path مع audit.

---

## 3. Tournament Creation

### 3.1 Required fields V1

```text
id
name
organizerId
visibility
status
format
teamLimit
registrationOpenAt?
registrationCloseAt?
tournamentStartAt?
timezone
matchDurationMinutes
createdAt
updatedAt
```

### 3.2 Visibility

V1 يجب أن يختار واحدًا أو أكثر:

```text
public
private
inviteOnly
```

معنى visibility:

| Visibility | من يرى؟ | من ينضم؟ |
|---|---|---|
| public | أي authenticated أو كل users حسب rules | captain submits/registers |
| private | المدعوون/الأعضاء فقط | invite only |
| inviteOnly | من لديه دعوة/رابط | invite only |

مهم:

> Visibility لا تمنح أي صلاحية إدارة.

---

## 4. Registration Lifecycle

### 4.1 Team registration states

```text
not_submitted
pending
approved
rejected
withdrawn
disqualified
```

### 4.2 Registration flow V1

```text
Team captain selects team
→ submits to tournament
→ organizer reviews
→ organizer approves/rejects
→ approved teams enter fixture pool
```

### 4.3 Temporary V1 shortcut

لو team registration flow غير جاهز، يمكن السماح مؤقتًا بـ:

```text
Organizer manually adds approved teams
```

لكن يجب توثيق أنه shortcut وليس نظامًا نهائيًا.

### 4.4 Registration rules

- لا يدخل fixtures إلا `approved` teams.
- team captain يدير تسجيل فريقه فقط.
- organizer يوافق/يرفض فقط داخل بطولته.
- player العادي لا يقدم فريقًا إلا لو captain.
- لا قبول فريق بعد `registration_closed` إلا override.

---

## 5. Tournament Formats

### 5.1 Formats الممكنة

```text
single_elimination
round_robin
groups_knockout
league
```

### 5.2 V1 recommended formats

V1 يجب أن يختار format واحدًا كبداية، أو اثنين بحد أقصى.

الأكثر واقعية:

#### Option A — Single elimination only

مناسب لـ 4 أو 8 فرق.

مميزات:

- بسيط.
- fixtures أقل.
- مناسب لـ MVP سريع.

عيوب:

- الفريق يخسر مباراة ويخرج.
- أقل عدالة.

#### Option B — Round robin small

مناسب لـ 4 فرق.

مميزات:

- standings واضح.
- كل فريق يلعب أكثر.

عيوب:

- مباريات أكثر.
- tie-breakers مهمة.

### 5.3 Recommendation

V1 يبدأ بـ:

```text
single_elimination + manual scheduling
```

أو:

```text
round_robin_4_teams فقط إذا كان standings موجودًا ومستقرًا
```

لا ندعم groups+knockout قبل وجود dependency graph واضح.

---

## 6. Fixture Generation

### 6.1 معنى fixture

Fixture هو مباراة مخططة داخل البطولة، لها ترتيب ومكان زمني في المسابقة.

ليست فقط `teamA vs teamB`.

Fixture يحتاج:

```text
roundNumber
matchNumber
stage
sideA
sideB
scheduledAt?
status
```

### 6.2 Fixture generation modes

| Mode | الوصف | V1 suitability |
|---|---|---|
| manual | organizer ينشئ كل مباراة | مناسب لكنه متعب |
| generated_pairings | التطبيق يولد المواجهات، المنظم يحدد المواعيد | الأفضل V1 |
| full_auto | التطبيق يولد المواجهات والمواعيد | خارج V1 |

### 6.3 V1 recommended mode

```text
generated_pairings
+ manual schedule assignment
```

أي:

- التطبيق يولد ترتيب المباريات.
- المنظم يحدد التاريخ والوقت والملعب.

### 6.4 Basic fixture rules

- لا fixture بدون فرق approved.
- لا fixture بعدد فرق أقل من minimum.
- لا تعديل participants بعد publish إلا بإعادة توليد واضحة.
- لا publish fixtures بدون `roundNumber` و`matchNumber`.
- `scheduledAt` يمكن أن يكون nullable في draft فقط.

---

## 7. Fixture Order

### 7.1 Required ordering fields

```text
roundNumber
matchNumber
stage
bracketPosition?
groupId?
```

### 7.2 Single elimination example

8 teams:

```text
Round 1 / Quarter finals:
M1: Team 1 vs Team 8
M2: Team 4 vs Team 5
M3: Team 2 vs Team 7
M4: Team 3 vs Team 6

Round 2 / Semi finals:
M5: Winner M1 vs Winner M2
M6: Winner M3 vs Winner M4

Round 3 / Final:
M7: Winner M5 vs Winner M6
```

### 7.3 Dependency issue

V1 إن لم يدعم `Winner of Match`, يجب ألا يدّعي full knockout automation.

بدائل V1:

1. generate first round only, organizer creates next round manually.
2. create placeholder matches with side source.
3. postpone knockout automation to V1.1.

Recommendation:

```text
V1: generated first-round pairings + organizer-managed next rounds
or explicit MatchSideSource if already feasible.
```

---

## 8. Scheduling Model

### 8.1 Required fields per match

```text
scheduledAt
estimatedEndAt? // derived
venueName?
courtName?
timezone or tournament timezone
status
```

### 8.2 Timezone policy

- Store timestamps in UTC.
- Store tournament timezone separately.
- Display in tournament timezone by default.
- Avoid using device timezone silently for tournament schedule.

### 8.3 Match duration

Tournament should define:

```text
matchDurationMinutes
bufferMinutes
```

`estimatedEndAt` can be derived.

### 8.4 V1 scheduling constraints

V1 should block:

- same team scheduled in two matches at the same time.
- match scheduled before tournamentStartAt.
- match scheduled before registrationCloseAt unless tournament is still draft.
- rescheduling completed match without organizer override.

### 8.5 V1 can allow

- no venue.
- text-only venue/court.
- manual schedule edits before match starts.

---

## 9. Time Slots and Venues

### 9.1 TimeSlot entity

Not required for minimal V1, but useful V1.1.

```text
TimeSlot
- id
- tournamentId
- venueId?
- startsAt
- endsAt
- status: available/reserved/blocked
- assignedMatchId?
```

### 9.2 Venue entity

V1 can use text fields:

```text
venueName
courtName
```

V1.1 can introduce:

```text
Venue
- id
- name
- address
- courtCount
```

Recommendation:

```text
V1: text venue/court
V1.1: Venue/TimeSlot entities
```

---

## 10. Match Lifecycle

### 10.1 Match states

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

### 10.2 V1 simplified match lifecycle

```text
draft
scheduled
score_submitted
approved
completed
postponed
cancelled
forfeit
```

### 10.3 Match state meanings

| State | Meaning |
|---|---|
| draft | fixture exists but not published/scheduled |
| scheduled | match has participants and scheduledAt |
| score_submitted | score entered but not final |
| approved | organizer approved score |
| completed | final/locked |
| postponed | schedule moved or pending new time |
| cancelled | match cancelled |
| forfeit | result assigned due to no-show |

### 10.4 State transition rules

```text
draft -> scheduled
scheduled -> score_submitted
score_submitted -> approved
approved -> completed
scheduled -> postponed
postponed -> scheduled
scheduled -> cancelled
scheduled -> forfeit
```

Forbidden:

- completed -> score_submitted.
- cancelled -> score_submitted.
- forfeit -> normal goals credited, unless special override.

---

## 11. Score Submission and Approval

### 11.1 V1 recommended flow

```text
score submitted
→ organizer approval
→ match completed
→ standings/stats official
```

### 11.2 Who submits?

Decision needed.

Options:

#### Option A — Organizer submits only

Safest and simplest.

Pros:

- less dispute complexity.
- clear authority.

Cons:

- organizer burden.

#### Option B — Captains submit, organizer approves

More realistic.

Pros:

- distributed work.

Cons:

- needs dispute/confirmation rules.

### 11.3 Recommendation

V1:

```text
Captain or organizer may submit
Organizer approves
Only approved results update official standings
```

If current code cannot safely support captain submit, use organizer-only for V1.

---

## 12. MatchEvents and Official Stats

### 12.1 When to write MatchEvents

Current flow writes goal/MVP events from score submit. But official stats should only be considered official after result approval, unless marked provisional.

Options:

1. write events immediately as provisional.
2. write events only after approval.
3. write immediately, but leaderboard filters by approved match.

Recommendation:

```text
V1: write events on submit, but official leaderboards should only count approved/completed matches if feasible.
```

If current implementation counts active goal events regardless of match approval, mark as risk.

### 12.2 Forfeit goals

Forfeit should not create player goal events by default.

---

## 13. Standings and Ranking Rules

### 13.1 Required ranking fields

```text
played
won
drawn
lost
goalsFor
goalsAgainst
goalDifference
points
```

### 13.2 V1 tie-breakers

Recommended:

1. points desc.
2. goalDifference desc.
3. goalsFor desc.
4. goalsAgainst asc.
5. manual organizer decision if still tied.

### 13.3 Result source

Standings must use approved/completed matches only.

If standings currently include non-approved scores, mark as P1 risk.

---

## 14. Rescheduling

### 14.1 V1 rescheduling

V1 simplest:

- Organizer can reschedule.
- Team captain cannot directly reschedule.
- Optional: captain can contact organizer outside app.

### 14.2 V1.1 reschedule request

```text
captain requests reschedule
opponent notified
organizer approves/rejects
match updated
notification sent
```

### 14.3 Audit

Any reschedule after publish should record:

```text
old scheduledAt
new scheduledAt
actorId
reason?
createdAt
```

---

## 15. No-show / Forfeit

### 15.1 V1 policy required

Questions:

- after how many minutes is no-show?
- who declares it?
- default result?

Recommended V1:

```text
Organizer declares forfeit
Default score: 3-0
No player goals credited
Standing points awarded
Audit event required
```

### 15.2 Forfeit effects

- match status = forfeit/completed.
- score stored.
- standings updated.
- no MatchEvent goal records.

---

## 16. Notifications Needed by Scheduling

V1 may not implement full notifications, but scheduling depends on them.

Minimum future notifications:

- tournament registration accepted/rejected.
- fixtures published.
- match scheduled.
- match rescheduled.
- score submitted.
- score approved.
- match postponed/cancelled.

If no notifications in V1, manual QA must accept that users need to check app manually.

---

## 17. Data Model Draft

### 17.1 Tournament

```text
Tournament
- id
- name
- organizerId
- status
- visibility
- format
- teamLimit
- registrationOpenAt
- registrationCloseAt
- tournamentStartAt
- tournamentEndAt?
- timezone
- matchDurationMinutes
- bufferMinutes?
- createdAt
- updatedAt
```

### 17.2 TournamentTeamRegistration

```text
TournamentTeamRegistration
- id
- tournamentId
- teamId
- submittedBy
- status
- approvedBy?
- approvedAt?
- rejectedBy?
- rejectedAt?
- rejectedReason?
- createdAt
- updatedAt
```

### 17.3 Match / Fixture

```text
Match
- id
- tournamentId
- roundNumber
- matchNumber
- stage
- groupId?
- bracketPosition?
- sideA
- sideB
- scheduledAt?
- venueName?
- courtName?
- status
- scoreA?
- scoreB?
- resultStatus
- submittedBy?
- approvedBy?
- approvedAt?
- createdAt
- updatedAt
```

### 17.4 MatchSideSource

```text
MatchSideSource
- type: team | winnerOfMatch | loserOfMatch | placeholder
- teamId?
- sourceMatchId?
- displayName?
```

---

## 18. Permission Requirements

### 18.1 Organizer only

- update tournament scheduling settings.
- generate fixtures.
- assign match schedule.
- approve results.
- declare forfeit.
- cancel/postpone match.

### 18.2 Captain

- submit team registration.
- maybe submit score for own team.
- view team/tournament schedule.

### 18.3 Player/viewer

- read only.

---

## 19. Tests Required Before V1

### 19.1 Unit/widget tests

- non-organizer does not see schedule/edit controls.
- organizer sees operations.
- scheduled match displays time correctly.
- no CTA/action for unauthorized users.

### 19.2 Repository/controller tests

- organized tournaments query scoped to organizerId.
- public discovery does not grant operations.
- fixture generation uses approved teams only.
- conflict check prevents same team same time.

### 19.3 Rules emulator tests

- non-organizer cannot update tournament schedule.
- non-organizer cannot generate/update fixtures.
- captain cannot approve tournament registrations.
- captain cannot approve final score if organizer-only approval.
- organizer can update own tournament.
- account B cannot update account A tournament.

### 19.4 Manual QA

- Account A creates tournament.
- Account B sees it only if public, read-only.
- Account B cannot manage it.
- Organizer schedules match.
- Match appears in correct round/order.
- Result approval updates standings.

---

## 20. Open Decisions

These must be answered before implementation:

1. V1 format: single elimination only or round robin too?
2. Minimum teams and maximum teams?
3. Does captain submit score in V1?
4. Are standings official only after organizer approval?
5. Is scheduledAt mandatory before publishing fixtures?
6. Does V1 include tournament registration by captain, or organizer manually adds teams?
7. Does V1 include venue text fields?
8. Is rescheduling organizer-only in V1?
9. What default forfeit score?
10. What timezone source is used?

---

## 21. Recommended V1 Decisions

To keep V1 coherent:

```text
Format: single elimination first
Teams: 4 or 8
Organizer: exactly one
Registration: organizer approval required
Fixtures: generated pairings + manual scheduling
scheduledAt: required before publish
Score: captain or organizer submits, organizer approves
Standings/stats: approved matches only if feasible
Reschedule: organizer-only
Forfeit: organizer-only, default 3-0, no goal events
Venue: text field only
Notifications: deferred/manual checking accepted
```

---

## 22. Immediate Next Step After This Document

Do not implement scheduling yet.

Next design/audit step:

```text
Current Code Gap Audit against:
- V1 Scope
- Role Matrix
- Tournament Lifecycle & Scheduling
```

The audit should identify:

- fields already present.
- fields missing.
- dangerous queries.
- admin operations without role checks.
- rules gaps.
- tests missing.
