# Wave 2 / Task 6: Guest-first Score UI Report

## Summary

Implemented guest-first scoring in the match score submission flow. `ScoreSubmitScreen` now renders unified scoring participants from the full match participant roster instead of only registered `Player` rows, so registered players, guest players, and match-side players can receive goals from the visible UI.

The old copy that said temporary players do not receive stats was removed. The score form now keeps direct team score entry visible as a fallback, while attributed goal controls write `MatchEvent` goal drafts for pride data.

## Files Changed

- `lib/features/match/controllers/score_submit_controller.dart`
- `lib/features/match/views/score_submit_screen.dart`
- `test/features/match/score_submit_controller_test.dart`
- `docs/Wave2_Task6_Guest_First_Score_UI_Report.md`

No Firestore rules, route guards, claim flow, fantasy, rating, or tournament operation services were changed in this task.

## Unified Scoring Participants

`ScoreSubmitController` now exposes scoring participant lists from `OfficialMatchRosterService.loadParticipantRoster`:

- registered players as `ParticipantRefKind.player`
- guest players as `ParticipantRefKind.guestPlayer`
- match-side players as `ParticipantRefKind.matchSidePlayer`

`ScoreSubmitScreen` renders those participant refs directly. User-facing labels stay simple Arabic labels such as `ضيف` and `قائمة المباراة`; technical participant kinds are not exposed.

## Guest-only Score Behavior

A guest-only side now renders scorer controls. The organizer can increment/decrement guest goals just like registered-player goals.

Direct score fields are visible for all matches, including tournament matches, so a side with no participant rows still has a score-only fallback. The safe empty state is now:

`لا يوجد لاعبون متاحون لهذا الطرف. أضف لاعبين للفريق أو لقائمة المباراة قبل تسجيل الأهداف.`

## MVP Behavior

The MVP selector now uses `controller.allParticipants`, so guest players and match-side players are eligible MVP choices. Submitting a guest MVP writes an MVP `MatchEvent` using the guest `ParticipantRef`.

## Score Total Behavior

Tournament score totals no longer sum registered player stat rows only. Totals now use:

- direct team score fields when entered
- otherwise attributed goal drafts from registered, guest, and match-side participants
- registered player stat fallback only when the full participant roster cannot be loaded

Registered player goal counters remain synced to the existing detailed stats path, preserving registered-player rating/stat behavior. Guest and match-side goals are represented through `MatchEvent` goal drafts.

## Old Copy Removed

Removed:

`لا يوجد لاعبون مسجلون لهذا الطرف. اللاعبون المؤقتون لا تُسجل لهم إحصائيات.`

Replaced with the safe actionable empty state above. The friendly-match header copy was also updated so it no longer says stats are optional for registered players only.

## Tests Added/Updated

Updated `test/features/match/score_submit_controller_test.dart` to prove:

- guest goal drafts contribute to side totals
- match-side player goal drafts contribute to side totals
- mixed registered + guest totals work
- guest-only tournament match can submit a score
- guest goals write guest `MatchEvent` refs
- guest MVP writes a guest MVP `MatchEvent`
- guest-only score UI renders scorer controls
- old temporary-player-no-stats copy is absent
- no-player side shows the safe empty state
- existing registered-player scoring behavior still works

Existing top scorers coverage still proves guest goal events are counted.

## Commands Run

- `flutter pub get` - passed
- `dart format lib/features/match/controllers/score_submit_controller.dart lib/features/match/views/score_submit_screen.dart test/features/match/score_submit_controller_test.dart` - passed
- `dart analyze lib/` - passed, no issues found
- `flutter test test/features/match/score_submit_controller_test.dart` - passed, 25 tests
- `flutter test test/features/match/score_submit_controller_test.dart test/core/services/tournament_top_scorers_resolver_test.dart` - passed, 33 tests
- `flutter test` - passed, 376 tests
- `npm run test:rules:emulator` - first sandboxed attempt failed because the emulator could not bind localhost ports; rerun with approved elevated permissions passed, 80 rules tests

## Final Result

Guest-only tournament match scoring is now visible and functional through the score submission UI. Guest player goals and MVP selections use `MatchEvent` participant refs, and registered-player score flows remain covered.

## Remaining Risks / Follow-ups

- Guest-to-registered stats merge remains deferred.
- `matchSidePlayer` events are still excluded from the tournament top scorers resolver by current policy/tests.
- Official vs provisional leaderboard policy remains unresolved.
- Scheduling conflict rules remain unresolved.
- Direct score-only submission can record team totals without scorer attribution; that is intentional as the V1 fallback, but attributed pride data depends on participant goal drafts.
