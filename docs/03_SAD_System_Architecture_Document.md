# وثيقة هيكلية النظام والتصميم عالي المستوى SAD — El7reef V1

**النسخة:** 1.0  
**التاريخ:** 2026-05-02  
**النطاق:** المعمارية الحالية والمستهدفة لأول إصدار Play Store  
**الاتجاه المنتجى:** Tournament Ego MVP

---

## 1. الهدف من الوثيقة

هذه الوثيقة تصف معمارية الحريف الحالية كما تظهر في الكود، وتقترح التصميم عالي المستوى المطلوب للوصول إلى V1. الهدف هو منع التشتت والتأكد أن كل تطوير جديد يخدم النظام المركزي: الدورات، المباريات، الأحداث، الإحصائيات، الكروت، والـ claim.

---

## 2. نظرة عامة على المعمارية الحالية

المشروع مبني بـ:

- Flutter.
- GetX للـ routing/state/dependency injection.
- Firebase Auth / Firestore / Storage / Messaging / Analytics.
- طبقات واضحة نسبيًا:
  - `lib/features`: UI/controllers/bindings.
  - `lib/domain`: entities/repositories interfaces.
  - `lib/data`: models/repository implementations.
  - `lib/core`: services/enums/widgets/lineup/theme/constants.
  - `lib/app`: routes/theme.

### 2.1 حجم الكود المراجع

- `lib`: 367 ملف Dart، حوالي 65k سطر.
- `test`: 52 ملف، حوالي 13k سطر.
- `firestore.rules`: 667 سطر.
- docs/md داخل المستودع: 27 ملف تقريبًا.

> لم يتم تشغيل Flutter/Dart داخل هذه البيئة لأن أدوات flutter/dart غير متاحة هنا. يوجد داخل المستودع `analysis_report.txt` يذكر أن تحليلًا سابقًا خرج بـ “No issues found”. يجب إعادة تشغيل الأوامر محليًا قبل أي release.

---

## 3. مكونات النظام الحالية

### 3.1 App Layer

- `main.dart`: تهيئة Firebase، تسجيل AuthService، GetMaterialApp، RTL Arabic، dark theme.
- `app_routes.dart`: route constants.
- `app_pages.dart`: GetPages وتعطيل بعض features عبر FeatureUnavailableScreen.

### 3.2 Feature Modules

| Feature | الحالة الحالية | ملاحظات |
|---|---|---|
| Auth | Login/Onboarding/Profile أساس موجود | يحتاج ربط أوضح بـ claim onboarding. |
| Home | 5 tabs: الرئيسية، اكتشاف، دورات، فرقي، بروفايل | يجب إعادة ترتيب الرسالة حول الدورات والفخر. |
| Tournament | list/detail/registration/operations/groups/fixtures/standings/bracket/assistants | أساس قوي لكن UX تشغيلي أكثر من emotional. |
| Match | discover/lobby/matchday/score/fan voting/challenges | قوي للودية، يحتاج توحيد حول match events. |
| Team | my teams/roster/guest members/invites | مهم جدًا ويحتاج team identity card. |
| Guest Claim | claim player/team/invite entry | foundation مهم للنمو. |
| Lineup | editors/result lineup/share | جيد ويحتاج ربط tournament/team pride. |
| Shareables | result/lineup cards | يحتاج توسيع إلى player/MVP/top scorers/champion. |
| Fantasy | موجود لكن gated | خارج V1. |
| Social | friends/search/activity feed | ليس قلب V1. |
| Organizer | audit/disputes | مفيد للثقة. |

---

## 4. مبادئ التصميم المستهدفة

1. **Match هو وحدة البناء:** كل دورة/تحدي/ودية تنتج مباراة أو أكثر.
2. **Events هي مصدر الإحصائيات:** لا نعتمد على حقول متفرقة فقط للأهداف والـ MVP.
3. **Guest-first:** اللاعب أو الفريق غير المسجل يشارك كاملًا، ثم يعمل claim لاحقًا.
4. **Trust by design:** audit وpermissions وstatus واضحة.
5. **Share by design:** كل لحظة مهمة تنتج كارت.
6. **Feature gates صريحة:** لا fantasy ولا fake surfaces داخل V1.
7. **Services مركزية:** العمليات الحساسة داخل services لا controllers.

---

## 5. التصميم عالي المستوى المستهدف

```text
┌─────────────────────────────────────────┐
│                 Flutter UI              │
│ Screens / Widgets / Share Cards / RTL   │
└────────────────────┬────────────────────┘
                     │ GetX Controllers
┌────────────────────▼────────────────────┐
│            Application Services          │
│ TournamentLifecycle / MatchSettlement   │
│ MatchEventService / ShareCardService    │
│ GuestClaim / TeamRoster / Permissions   │
└────────────────────┬────────────────────┘
                     │ Repositories
┌────────────────────▼────────────────────┐
│              Domain Layer                │
│ Entities: Tournament, Match, Team,       │
│ Player, GuestPlayer, MatchEvent, Stats   │
└────────────────────┬────────────────────┘
                     │ Models + Firestore
┌────────────────────▼────────────────────┐
│              Firebase Backend            │
│ Auth / Firestore / Storage / Analytics   │
│ Security Rules / Indexes                 │
└─────────────────────────────────────────┘
```

---

## 6. الكيانات الأساسية

### 6.1 Tournament

موجود حاليًا ويمثل الدورة. يحتوي على organizerId, name, format, teamSize, maxTeams, status, assistants, participant summary, current stages, winner.

**تحسين مستهدف:** إضافة presentation fields اختيارية مثل coverImageUrl, accentColor, publicSlug لاحقًا.

### 6.2 Team / GuestTeam

Team يمثل فريقًا رسميًا. GuestTeam يمثل فريقًا مؤقتًا قابلًا للـ claim.

**تحسين مستهدف:** توحيد طريقة العرض عبر TeamIdentity DTO حتى لا تتكرر حالات official/guest داخل UI.

### 6.3 Player / GuestPlayer

Player هو حساب حقيقي. GuestPlayer هو لاعب مضاف يدويًا.

**تحسين مستهدف:** بناء PlayerIdentityRef:

```text
PlayerIdentityRef
- kind: registered | guest | matchSidePlayer
- id
- displayNameSnapshot
- photoUrlSnapshot?
- linkedPlayerId?
```

### 6.4 Match

موجود حاليًا ويحتوي tournament fields وteam ids وstatus والنتيجة.

**تحسين مستهدف:** إضافة/توحيد context:

```text
matchType: tournament | challenge | friendly
contextId: tournamentId/challengeId/null
```

أو الاكتفاء بـ `tournamentId` + challenge relation في V1 مع توثيق واضح.

### 6.5 MatchSide / MatchSidePlayer

موجودان ويدعمان sides مؤقتة ولاعبين داخل طرف المباراة. هذه نقطة قوة مهمة ويجب استخدامها كأساس للأحداث والـ share.

### 6.6 MatchEvent — إضافة مطلوبة

الكيان الناقص الأهم.

```text
MatchEvent
- id
- matchId
- tournamentId?
- eventType: goal | assist | mvp | ownGoal | card
- sideKey: A | B
- actor: PlayerIdentityRef
- assistedBy: PlayerIdentityRef?
- minute?
- createdBy
- createdAt
- status: active | voided | pendingReview
- source: organizer | captain | migration
```

### 6.7 Derived Stats

إحصائيات مشتقة من MatchEvents:

- TournamentScorerStanding.
- PlayerTournamentStats.
- TeamTournamentStats.
- PlayerCareerStats.

يمكن تخزينها كسnapshots لتحسين الأداء.

---

## 7. Firestore collections المقترحة

### 7.1 موجودة ومستخدمة

```text
players
guestPlayers
teams
guestTeams
teamMemberships
teamFormationTemplates
teamRosterSnapshots
matches
matchSides
matchSidePlayers
matchCheckIns
matchAttendances
matchLineupSnapshots
matchSubstitutions
tournaments
tournamentRegistrations
tournamentParticipants
tournamentGroups
groupStandingSnapshots
knockoutBrackets
knockoutTies
claimCodes
fanVotingSessions
userVotes
auditEvents
disputes
analyticsEvents
```

### 7.2 مطلوبة/موصى بها لـ V1

```text
matchEvents
playerTournamentStats
teamTournamentStats
tournamentScorerSnapshots
shareCardEvents
```

### 7.3 سبب إضافة matchEvents

الكود الحالي يسجل `player_stats` تحت `matches/{matchId}` للاعبين المسجلين فقط. هذا لا يكفي لأن المنتج الجديد يعتمد على guest players والـ Ego. يجب أن يكون الهدف أو MVP قابلًا للنسبة إلى لاعب ضيف أو matchSidePlayer وليس فقط Player document.

---

## 8. تدفقات النظام الأساسية

### 8.1 إنشاء دورة

```text
UI CreateTournamentSheet
→ TournamentController.createTournament
→ TournamentRepositoryImpl.createTournament
→ Firestore tournaments
→ TournamentList/Detail reload
```

**تعديل مطلوب:** إزالة fantasy toggle من UI أو إجباره false في V1.

### 8.2 تسجيل فريق ضيف في دورة

```text
TournamentRegistrationScreen
→ TournamentGuestTeamCreateController
→ GuestTeamRepository / TournamentRegistrationService
→ tournamentRegistrations
→ tournamentParticipants after approval/sync
→ optional ShareLinkService.createGuestTeamClaimLink
```

### 8.3 إضافة لاعب ضيف للفريق

```text
TeamRosterScreen
→ TeamRosterController.createGuestPlayerAndAdd
→ GuestPlayerRepository + TeamMembershipRepository
→ optional ShareLinkService.createGuestPlayerClaimLink
→ Claim flow later
```

### 8.4 توليد مباريات الدورة

```text
TournamentOperationsController.startGroupStage
→ TournamentLifecycleService.startGroupStage
→ GroupStageBuilder / FixtureService
→ tournamentGroups + matches
```

### 8.5 تسجيل نتيجة المباراة المستهدف

```text
ScoreSubmitScreen
→ ScoreSubmitController.submit
→ MatchSettlementService.submitScore
→ matches update
→ MatchEventService.upsertEvents(goal/mvp)
→ MatchSettlementService.approveScore or pendingReview
→ TournamentLifecycleService.refreshGroupStandings
→ StatsSnapshotService.refreshTopScorers
→ Share cards shown
```

### 8.6 Claim player

```text
Shared claim link
→ ClaimEntryScreen
→ GuestPlayerClaimController.loadClaimTarget
→ GuestClaimService.claimGuestPlayer
→ guestPlayers.linkedPlayerId = playerId
→ claimCodes.status = claimed
→ teamMemberships sync if needed
→ player profile shows previous stats
```

---

## 9. Services المستهدفة

### 9.1 موجودة يجب الحفاظ عليها

- TournamentLifecycleService
- TournamentRegistrationService
- TournamentParticipantService
- MatchSettlementService
- MatchStartService
- MatchdayService
- TeamRosterService
- GuestClaimService
- ShareLinkService
- AuditService
- DisputeService
- ShareCardCaptureService

### 9.2 جديدة مطلوبة

#### MatchEventService

مسؤول عن:

- إنشاء/تعديل/إلغاء events.
- validation: actor belongs to match side.
- validation: goals sum vs score.
- emit audit.
- expose events for UI and stats.

#### TournamentStatsService

مسؤول عن:

- بناء top scorers.
- player stats per tournament.
- team stats if not covered by group snapshots.

#### ShareCardEventTracker

مسؤول عن analytics لأحداث المشاركة.

#### PlayerIdentityResolver

مسؤول عن حل registered/guest/matchSidePlayer إلى display DTO موحد.

---

## 10. صلاحيات وأمن

### 10.1 الحالة الحالية

Firestore rules موجودة وتغطي معظم المجموعات. يوجد تحقق من owner/organizer/team manager/claim codes. لكن أي collections جديدة مثل `matchEvents` ستحتاج rules واضحة.

### 10.2 قواعد matchEvents المقترحة

- read: authenticated users على الأقل في V1.
- create/update: match organizer أو tournament organizer/assistant أو captain مصرح له حسب المرحلة.
- delete: لا حذف فعلي؛ استخدم status = voided.
- كل update يجب أن يحافظ على matchId/createdBy/createdAt.

### 10.3 قواعد shareCardEvents

- create: authenticated actor أو system client event.
- read: owner/admin فقط أو blocked حسب الحاجة.
- لا تحتوي بيانات حساسة.

---

## 11. قرارات معمارية

### ADR-001: اعتماد MatchEvent كمصدر الحقيقة للإحصائيات

**القرار:** إنشاء `matchEvents` بدل الاعتماد على player_stats فقط.  
**السبب:** دعم guest players والـ Ego والهدافين.  
**الأثر:** تعديل score submit وleaderboards والكروت.

### ADR-002: اللاعب الضيف مواطن درجة أولى

**القرار:** كل واجهة إحصائيات أو مشاركة يجب أن تقبل PlayerIdentityRef وليس Player فقط.  
**السبب:** واقع الدورات الشعبية.  
**الأثر:** تحديث UI components وservices.

### ADR-003: الكروت جزء من Core وليس Feature جانبية

**القرار:** كل lifecycle مهم ينتج CTA مشاركة.  
**السبب:** growth loop.  
**الأثر:** بناء share card registry.

### ADR-004: إيقاف Fantasy في V1

**القرار:** عدم إظهار fantasy في create tournament أو navigation.  
**السبب:** تشتيت وعدم اكتمال.  
**الأثر:** clean product surface.

---

## 12. مخاطر معمارية

| الخطر | التأثير | التخفيف |
|---|---|---|
| إضافة events بدون migration | تضارب stats القديمة والجديدة | phase migration + compatibility layer. |
| دعم guest في كل مكان يزيد التعقيد | bugs في UI/services | PlayerIdentityRef موحد. |
| Firestore indexes ناقصة | فشل queries في production | توثيق indexes وتشغيل emulator. |
| كثرة feature surfaces | تجربة مشتتة | feature gate وحذف من navigation. |
| direct writes من controllers | فقدان integrity | services فقط للعمليات الحساسة. |

---

## 13. متطلبات النشر

- release signing config بدل debug signing.
- applicationId نهائي.
- label عربي/إنجليزي مناسب.
- launcher icon نهائي.
- target SDK مطابق لمتطلبات Google Play.
- Privacy Policy + Data Safety.
- crash/error monitoring.
- closed testing.

---

## 14. خطة التطوير المعمارية المختصرة

1. **Architecture Freeze:** اعتماد Tournament Ego MVP وتحديث docs/AGENTS.
2. **MatchEvent foundation:** model/repository/service/rules/tests.
3. **Score Submit v2:** دعم الأهداف/MVP للضيوف والمسجلين.
4. **Stats snapshots:** ترتيب هدافين ولاعبين.
5. **Share Cards expansion:** Player/MVP/TopScorers/Team/Champion.
6. **UX wiring:** جعل الكروت CTAs واضحة في الرحلات.
7. **Release hardening:** signing/rules/tests/store.

---

## 15. الخلاصة

المعمارية الحالية جيدة كبداية، لكنها لا تكفي للرؤية النفسية الجديدة دون `MatchEvent` وPlayerIdentityRef وتوسيع shareables. القرار التقني الأهم قبل V1 هو تحويل المباراة من “score فقط” إلى “event-producing engine” يدعم الضيوف والمسجلين، لأن هذا هو مصدر الفخر والانتشار.
