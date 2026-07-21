import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:el7reef/features/match/models/score_submit_draft.dart';
import 'package:el7reef/features/match/services/score_submit_draft_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'saved score draft survives a fresh store instance and clears',
    () async {
      final firstStore = SharedPreferencesScoreSubmitDraftStore();
      const draft = ScoreSubmitDraft(
        matchId: 'match-1',
        sourceFingerprint: 'live||||',
        scoreA: '3',
        scoreB: '2',
        penaltyScoreA: '5',
        penaltyScoreB: '4',
        goalsByParticipantKey: {'guestPlayer:guest-1': 2},
        selectedMvpKey: 'guestPlayer:guest-1',
        registeredStats: {
          'player-1': ScoreSubmitRegisteredStatsDraft(
            assists: 1,
            yellowCard: true,
          ),
        },
      );

      await firstStore.save(draft);
      final restored = await SharedPreferencesScoreSubmitDraftStore().load(
        'match-1',
      );

      expect(restored?.scoreA, '3');
      expect(restored?.scoreB, '2');
      expect(restored?.penaltyScoreA, '5');
      expect(restored?.penaltyScoreB, '4');
      expect(restored?.goalsByParticipantKey, {'guestPlayer:guest-1': 2});
      expect(restored?.selectedMvpKey, 'guestPlayer:guest-1');
      expect(restored?.registeredStats['player-1']?.assists, 1);
      expect(restored?.registeredStats['player-1']?.yellowCard, isTrue);

      await firstStore.clear('match-1');
      expect(await firstStore.load('match-1'), isNull);
    },
  );
}
