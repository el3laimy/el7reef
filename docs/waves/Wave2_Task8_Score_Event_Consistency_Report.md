# Wave 2 / Task 8: Score/Event Consistency & Error Handling

## Product Policy Decision

For V1, the official team score does not have to equal the sum of attributed player goals.

- Team score total is the official score for the side.
- Attributed goals are goals assigned to registered, guest, or match-side participants and written as `MatchEvent` documents.
- Unattributed goals are `team score total - attributed goals`.
- Unattributed goals are allowed, but must be visible and honest.
- Top scorers count only attributed goals from official settled matches.
- Unattributed goals do not enter top scorers.
- Over-attribution is invalid: attributed goals cannot exceed the team score total.

## Files Changed

- `lib/features/match/controllers/score_submit_controller.dart`
- `lib/features/match/views/score_submit_screen.dart`
- `test/features/match/score_submit_controller_test.dart`
- `docs/waves/Wave2_Task8_Score_Event_Consistency_Report.md`

No Firestore rules were changed.

## Attributed / Unattributed Goal Behavior

Score submission now computes a side summary for each team:

- `teamScore`: official side score.
- `attributedGoals`: total goals assigned to participants.
- `unattributedGoals`: remaining team goals that are not assigned to a participant.
- `overAttributedGoals`: attributed goals above the official side score.

The score submit screen now displays per side:

- `نتيجة الفريق: X`
- `الأهداف المنسوبة: X`
- `أهداف غير منسوبة: X` when applicable.
- A clear note: `لن تظهر في الهدافين.`

## Validation Behavior

Unattributed goals are allowed by default.

Example: score `5-0` with `2` attributed goals is accepted and displays `3` unattributed goals.

Over-attribution is blocked.

Example: score `1-0` with `2` attributed goals is rejected with:

`عدد الأهداف المنسوبة أكبر من نتيجة الفريق.`

## Event Failure Handling

Silent `catch (_)` blocks were removed from goal/MVP event recording paths.

If score settlement succeeds but goal/MVP `MatchEvent` writes fail:

- A safe Arabic error is surfaced.
- Raw exception text is not exposed.
- Normal success/share flow is not shown.
- Draft goal and MVP selection state remains available for retry.
- The controller marks `pendingPrideEventRetry` so a later submit can retry pride event writes for an already submitted score.

Safe error copy:

`تم حفظ النتيجة، لكن فشل تسجيل أحداث الأهداف أو أفضل لاعب. حاول مرة أخرى قبل مشاركة النتيجة.`

## Share / Success Behavior

The success bottom sheet is shown only when score submission and required event writes complete successfully.

If the result is score-only with no attributed goals, the success sheet does not imply top scorer data exists:

`تم حفظ النتيجة بدون أهداف منسوبة؛ لن تُضاف أهداف للهدافين من هذه المباراة.`

If attributed and unattributed goals both exist, the success copy states that unattributed goals do not appear in top scorers.

## Roster Error Behavior

`fullRosterErrorMessage` is now visible in `ScoreSubmitScreen`.

The organizer can still submit score-only, but the UI clearly explains that scorer/MVP controls may be incomplete.

## Participant Key Behavior

MVP selection now uses the unique participant roster key:

`kind:id`

Examples:

- `player:same-id`
- `guestPlayer:same-id`
- `matchSidePlayer:same-id`

This prevents registered players, guest players, and match-side players with the same raw id string from colliding in UI selection and event resolution.

The persisted `Match.mvpPlayerId` still receives the participant raw id to preserve existing match/rating behavior, while the `MatchEvent` MVP actor keeps the full participant identity.

## Tests Added / Updated

Updated `test/features/match/score_submit_controller_test.dart` to cover:

- `5-0` with `2` attributed goals displays `3` unattributed goals.
- Unattributed goals warning does not block submit by default.
- Attributed goals greater than score blocks submit.
- Event recording failure surfaces a safe error and does not show the success/share sheet.
- `fullRosterErrorMessage` is visible in the score submit screen.
- MVP selection distinguishes same raw id across different participant kinds.
- Registered, guest, and match-side goals all contribute correctly to attributed totals.
- Existing guest-first score event tests still pass.

Official top scorer tests were covered by the full Flutter test suite and remained passing.

## Commands Run

```bash
flutter pub get
```

Result: passed.

```bash
dart format lib/features/match/controllers/score_submit_controller.dart lib/features/match/views/score_submit_screen.dart test/features/match/score_submit_controller_test.dart
```

Result: passed.

```bash
dart analyze lib/
```

Result: passed, no issues found.

```bash
flutter test test/features/match/score_submit_controller_test.dart
```

Result: passed, all targeted score submit tests passed.

```bash
flutter test
```

Result: passed, full Flutter test suite passed.

```bash
npm run test:rules:emulator
```

Result: could not start with the repository script in this environment.

Reason: `firebase-tools@15.13.0` requires Node.js `>=20.0.0 || >=22.0.0 || >=24.0.0`, while the current environment has Node.js `v18.19.1`.

The same rules emulator suite was then run with a Node 18 compatible Firebase CLI without changing project files:

```bash
env FIREBASE_CLI_DISABLE_UPDATE_CHECK=true npx firebase-tools@13.35.1 --config firebase.rules.test.json emulators:exec --only firestore "npm run test:rules"
```

Result: passed, `80 passing`.

## Final Result

Score submission is now honest and failure-safe for V1:

- Attributed and unattributed goals are visible per side.
- Unattributed goals are allowed and clearly excluded from top scorers.
- Over-attribution is blocked.
- Goal/MVP event failures are surfaced safely and do not trigger false success/share UI.
- Roster loading failures are visible to the organizer.
- MVP participant selection uses `kind:id` keys to avoid identity collisions.
- Dart analysis and Flutter tests pass.
- Firestore rules emulator tests pass using `firebase-tools@13.35.1` under Node 18.

## Remaining Risks

- Assistant roles are not implemented in this task.
- Scheduling conflict rules remain unresolved.
- Guest-to-registered stats merge is deferred.
- Direct score-only submission means top scorers may not match the final score by design.
- The repository `npm run test:rules:emulator` script still requires Node.js 20+ because it resolves to `firebase-tools@15.13.0`; Node 18 works only with the explicit `firebase-tools@13.35.1` workaround used above.
