import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/features/tournament/models/tournament_operations_read_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prompts the organizer to add the first and second team', () {
    const model = TournamentOperationsReadModel(fixtures: []);

    final first = model.nextAction(
      activeParticipantsCount: 0,
      canAddParticipants: true,
      canFinalizeParticipants: false,
      canStartGroupStage: false,
      canPublishFixtures: false,
      canStartKnockout: false,
      canCompleteTournament: false,
      fixtureTeamLabel: (_, {required isHome}) => '',
    );
    final second = model.nextAction(
      activeParticipantsCount: 1,
      canAddParticipants: true,
      canFinalizeParticipants: false,
      canStartGroupStage: false,
      canPublishFixtures: false,
      canStartKnockout: false,
      canCompleteTournament: false,
      fixtureTeamLabel: (_, {required isHome}) => '',
    );

    expect(first?.kind, TournamentOpsNextActionKind.addParticipant);
    expect(first?.label, 'أضف أول فريق');
    expect(second?.label, 'أضف الفريق الثاني');
  });

  test('live fixture wins over pending review as the next action', () {
    final model = TournamentOperationsReadModel(
      fixtures: [
        _match('pending', MatchStatus.pendingReview),
        _match('live', MatchStatus.live),
      ],
    );

    final action = _nextAction(model);

    expect(model.urgentFixture?.id, 'live');
    expect(action?.kind, TournamentOpsNextActionKind.recordLiveScore);
    expect(action?.label, 'سجّل النتيجة الآن');
    expect(action?.matchId, 'live');
  });

  test('pending review becomes the next action when no match is live', () {
    final model = TournamentOperationsReadModel(
      fixtures: [_match('pending', MatchStatus.pendingReview)],
    );

    final action = _nextAction(model);

    expect(action?.kind, TournamentOpsNextActionKind.reviewPendingScore);
    expect(action?.label, 'راجع النتيجة المعلقة');
    expect(action?.detail, contains('فريق A ضد فريق B'));
  });

  test('falls back to the lifecycle action after urgent fixtures', () {
    final model = TournamentOperationsReadModel(
      fixtures: [
        _match('draft-1', MatchStatus.open),
        _match('draft-2', MatchStatus.open),
      ],
    );

    final action = model.nextAction(
      activeParticipantsCount: 4,
      canFinalizeParticipants: false,
      canStartGroupStage: false,
      canPublishFixtures: true,
      canStartKnockout: false,
      canCompleteTournament: false,
      fixtureTeamLabel: _teamLabel,
    );

    expect(model.draftFixturesCount, 2);
    expect(action?.kind, TournamentOpsNextActionKind.publishFixtures);
    expect(action?.requirements.first, contains('2'));
  });

  test(
    'completed fixtures stay released and never become publishable drafts',
    () {
      final model = TournamentOperationsReadModel(
        fixtures: [
          _match(
            'settled',
            MatchStatus.settled,
            fixtureStatus: FixtureStatus.completed,
          ),
          _match(
            'upcoming',
            MatchStatus.open,
            fixtureStatus: FixtureStatus.published,
          ),
        ],
      );

      expect(model.draftFixturesCount, 0);
      expect(model.publishedFixturesCount, 1);
      expect(model.releasedFixturesCount, 2);
    },
  );

  test('the earliest published open fixture becomes the operational CTA', () {
    final model = TournamentOperationsReadModel(
      fixtures: [
        _match(
          'later',
          MatchStatus.open,
          fixtureStatus: FixtureStatus.published,
          scheduledAt: DateTime(2026, 7, 19),
        ),
        _match(
          'next',
          MatchStatus.open,
          fixtureStatus: FixtureStatus.published,
          scheduledAt: DateTime(2026, 7, 18),
        ),
      ],
    );

    final action = model.nextAction(
      activeParticipantsCount: 48,
      canFinalizeParticipants: false,
      canStartGroupStage: false,
      canPublishFixtures: false,
      canStartKnockout: false,
      canCompleteTournament: false,
      fixtureTeamLabel: _teamLabel,
    );

    expect(action?.kind, TournamentOpsNextActionKind.prepareUpcomingFixture);
    expect(action?.label, 'جهّز المباراة القادمة');
    expect(action?.matchId, 'next');
  });
}

TournamentOpsNextAction? _nextAction(TournamentOperationsReadModel model) {
  return model.nextAction(
    activeParticipantsCount: 4,
    canFinalizeParticipants: true,
    canStartGroupStage: true,
    canPublishFixtures: true,
    canStartKnockout: true,
    canCompleteTournament: true,
    fixtureTeamLabel: _teamLabel,
  );
}

String _teamLabel(Match _, {required bool isHome}) =>
    isHome ? 'فريق A' : 'فريق B';

Match _match(
  String id,
  MatchStatus status, {
  FixtureStatus fixtureStatus = FixtureStatus.draft,
  DateTime? scheduledAt,
}) {
  return Match(
    id: id,
    organizerId: 'organizer-1',
    status: status,
    fixtureStatus: fixtureStatus,
    scheduledAt: scheduledAt,
    createdAt: DateTime(2026, 7, 13),
  );
}
