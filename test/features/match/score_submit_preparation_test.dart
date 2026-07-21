import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/features/match/models/score_submit_models.dart';
import 'package:el7reef/features/match/services/score_submit_preparation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScoreSubmitPreparation.validateScores', () {
    test('uses attributed goals when a score field is empty', () {
      final result = ScoreSubmitPreparation.validateScores(
        rawScoreA: '',
        rawScoreB: '1',
        sideAName: 'الحريف',
        sideBName: 'الخصم',
        attributedGoalsA: 2,
        attributedGoalsB: 1,
      );

      expect(result.isValid, isTrue);
      expect(result.scoreA, 2);
      expect(result.scoreB, 1);
    });

    test('returns the side-specific Arabic error for an invalid score', () {
      final result = ScoreSubmitPreparation.validateScores(
        rawScoreA: '3',
        rawScoreB: '-1',
        sideAName: 'الحريف',
        sideBName: 'الخصم',
        attributedGoalsA: 0,
        attributedGoalsB: 0,
      );

      expect(result.isValid, isFalse);
      expect(result.errorTitle, 'نتيجة غير صحيحة');
      expect(result.errorMessage, contains('الخصم'));
    });

    for (final scoreCase in const [
      (rawScore: '99', isValid: true),
      (rawScore: '100', isValid: false),
    ]) {
      test(
        'score ${scoreCase.rawScore} is ${scoreCase.isValid ? 'accepted' : 'rejected'} at the service boundary',
        () {
          final result = ScoreSubmitPreparation.validateScores(
            rawScoreA: scoreCase.rawScore,
            rawScoreB: '0',
            sideAName: 'الحريف',
            sideBName: 'الخصم',
            attributedGoalsA: 0,
            attributedGoalsB: 0,
          );

          expect(result.isValid, scoreCase.isValid);
        },
      );
    }

    test('rejects attributed goals above the submitted score', () {
      final result = ScoreSubmitPreparation.validateScores(
        rawScoreA: '1',
        rawScoreB: '0',
        sideAName: 'الحريف',
        sideBName: 'الخصم',
        attributedGoalsA: 2,
        attributedGoalsB: 0,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errorMessage,
        ScoreSubmitPreparation.attributionOverScoreMessage,
      );
    });
  });

  test('settlementGoals keeps guest identity and minute', () {
    const guest = ParticipantRef(
      kind: ParticipantRefKind.guestPlayer,
      id: 'guest-1',
      displayName: 'ضيف',
    );

    final goals = ScoreSubmitPreparation.settlementGoals(const [
      ScoreSubmitGoalDraft(actor: guest, sideKey: 'A', goals: 2, minute: 17),
    ]);

    expect(goals, hasLength(1));
    expect(goals.single.actor.kind, ParticipantRefKind.guestPlayer);
    expect(goals.single.goals, 2);
    expect(goals.single.minute, 17);
  });

  test('detailedStats binds registered players to their match sides', () {
    final now = DateTime(2026, 7, 13);
    final keeper = Player(
      id: 'player-a',
      name: 'حارس',
      position: 'GK',
      createdAt: now,
      lastActiveAt: now,
    );
    final forward = Player(
      id: 'player-b',
      name: 'مهاجم',
      position: 'FWD',
      createdAt: now,
      lastActiveAt: now,
    );

    final stats = ScoreSubmitPreparation.detailedStats(
      matchId: 'match-1',
      teamAId: 'team-a',
      teamBId: 'team-b',
      teamAPlayers: [keeper],
      teamBPlayers: [forward],
      playerStats: {
        keeper.id: _stats(goals: 0, saves: 3),
        forward.id: _stats(goals: 2, saves: 0),
      },
      teamACleanSheet: false,
      teamBCleanSheet: true,
    );

    expect(stats, hasLength(2));
    expect(stats[0].teamId, 'team-a');
    expect(stats[0].position.name, 'goalkeeper');
    expect(stats[0].saves, 3);
    expect(stats[1].teamId, 'team-b');
    expect(stats[1].position.name, 'forward');
    expect(stats[1].goals, 2);
    expect(stats[1].cleanSheet, isTrue);
  });
}

Map<String, dynamic> _stats({required int goals, required int saves}) => {
  'played': true,
  'goals': goals,
  'assists': 0,
  'saves': saves,
  'yellowCard': false,
  'redCard': false,
};
