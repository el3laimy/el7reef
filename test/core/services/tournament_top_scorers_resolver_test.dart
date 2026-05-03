import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/services/match_event_service.dart';
import 'package:el7reef/core/services/tournament_top_scorers_resolver.dart';
import 'package:el7reef/data/repositories/match_event_repository_impl.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';

void main() {
  group('TournamentTopScorersResolver', () {
    late FakeFirebaseFirestore firestore;
    late MatchEventService matchEventService;
    late TournamentTopScorersResolver resolver;
    late DateTime now;

    const registeredActor = ParticipantRef(
      kind: ParticipantRefKind.player,
      id: 'player-1',
      displayName: 'Ali',
    );
    const guestActor = ParticipantRef(
      kind: ParticipantRefKind.guestPlayer,
      id: 'guest-1',
      displayName: 'Bassem',
      linkedPlayerId: 'claimed-player-1',
    );
    const matchSideActor = ParticipantRef(
      kind: ParticipantRefKind.matchSidePlayer,
      id: 'msp-1',
      displayName: 'Temporary Scorer',
    );

    setUp(() {
      firestore = FakeFirebaseFirestore();
      matchEventService = MatchEventService(
        repository: MatchEventRepositoryImpl(firestore: firestore),
      );
      resolver = TournamentTopScorersResolver(
        matchEventService: matchEventService,
      );
      now = DateTime(2026, 5, 4, 20);
    });

    test('returns empty list for no events and non-positive limits', () async {
      expect(await resolver.getTopScorers('tournament-1'), isEmpty);
      expect(await resolver.getTopScorers('tournament-1', limit: 0), isEmpty);
      expect(await resolver.getTopScorers('tournament-1', limit: -1), isEmpty);
    });

    test('aggregates multiple goals for the same registered player', () async {
      await _recordGoals(
        service: matchEventService,
        tournamentId: 'tournament-1',
        actor: registeredActor,
        count: 3,
        now: now,
      );

      final scorers = await resolver.getTopScorers('tournament-1');

      expect(scorers, hasLength(1));
      expect(scorers.single.actor.kind, ParticipantRefKind.player);
      expect(scorers.single.actor.id, 'player-1');
      expect(scorers.single.actor.displayName, 'Ali');
      expect(scorers.single.goals, 3);
      expect(scorers.single.teamDisplayName, isNull);
    });

    test(
      'aggregates guest player goals and preserves linkedPlayerId',
      () async {
        await _recordGoals(
          service: matchEventService,
          tournamentId: 'tournament-1',
          actor: guestActor,
          count: 2,
          now: now,
        );

        final scorers = await resolver.getTopScorers('tournament-1');

        expect(scorers, hasLength(1));
        expect(scorers.single.actor.kind, ParticipantRefKind.guestPlayer);
        expect(scorers.single.actor.id, 'guest-1');
        expect(scorers.single.actor.displayName, 'Bassem');
        expect(scorers.single.actor.linkedPlayerId, 'claimed-player-1');
        expect(scorers.single.goals, 2);
      },
    );

    test(
      'excludes matchSidePlayer events from tournament leaderboard',
      () async {
        await _recordGoals(
          service: matchEventService,
          tournamentId: 'tournament-1',
          actor: registeredActor,
          count: 1,
          now: now,
        );
        await _recordGoals(
          service: matchEventService,
          tournamentId: 'tournament-1',
          actor: matchSideActor,
          count: 5,
          now: now.add(const Duration(minutes: 1)),
        );

        final scorers = await resolver.getTopScorers('tournament-1');

        expect(scorers, hasLength(1));
        expect(scorers.single.actor.kind, ParticipantRefKind.player);
        expect(scorers.single.actor.id, 'player-1');
        expect(scorers.single.goals, 1);
      },
    );

    test('ignores MVP events and voided goal events', () async {
      await matchEventService.recordMvp(
        eventId: 'mvp-1',
        matchId: 'match-1',
        tournamentId: 'tournament-1',
        sideKey: 'A',
        actor: registeredActor,
        createdBy: 'organizer-1',
        now: now,
      );
      await matchEventService.recordGoal(
        eventId: 'voided-goal-1',
        matchId: 'match-1',
        tournamentId: 'tournament-1',
        sideKey: 'A',
        actor: registeredActor,
        createdBy: 'organizer-1',
        now: now.add(const Duration(minutes: 1)),
      );
      await matchEventService.voidEvent('voided-goal-1');

      final scorers = await resolver.getTopScorers('tournament-1');

      expect(scorers, isEmpty);
    });

    test('sorts by goals descending and applies limit', () async {
      const oneGoalActor = ParticipantRef(
        kind: ParticipantRefKind.player,
        id: 'player-1',
        displayName: 'One Goal',
      );
      const twoGoalActor = ParticipantRef(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-2',
        displayName: 'Two Goals',
      );
      const threeGoalActor = ParticipantRef(
        kind: ParticipantRefKind.player,
        id: 'player-3',
        displayName: 'Three Goals',
      );

      await _recordGoals(
        service: matchEventService,
        tournamentId: 'tournament-1',
        actor: oneGoalActor,
        count: 1,
        now: now,
      );
      await _recordGoals(
        service: matchEventService,
        tournamentId: 'tournament-1',
        actor: twoGoalActor,
        count: 2,
        now: now.add(const Duration(minutes: 1)),
      );
      await _recordGoals(
        service: matchEventService,
        tournamentId: 'tournament-1',
        actor: threeGoalActor,
        count: 3,
        now: now.add(const Duration(minutes: 2)),
      );

      final scorers = await resolver.getTopScorers('tournament-1', limit: 2);

      expect(scorers.map((entry) => entry.actor.id), ['player-3', 'guest-2']);
      expect(scorers.map((entry) => entry.goals), [3, 2]);
    });

    test('isolates goal totals by tournament id', () async {
      const tournamentOneActor = ParticipantRef(
        kind: ParticipantRefKind.player,
        id: 'player-tournament-1',
        displayName: 'Tournament One Scorer',
      );
      const tournamentTwoActor = ParticipantRef(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-tournament-2',
        displayName: 'Tournament Two Scorer',
      );

      await _recordGoals(
        service: matchEventService,
        tournamentId: 'tournament-1',
        actor: tournamentOneActor,
        count: 2,
        now: now,
      );
      await _recordGoals(
        service: matchEventService,
        tournamentId: 'tournament-2',
        actor: tournamentTwoActor,
        count: 5,
        now: now.add(const Duration(minutes: 1)),
      );

      final scorers = await resolver.getTopScorers('tournament-1');

      expect(scorers, hasLength(1));
      expect(scorers.single.actor.id, 'player-tournament-1');
      expect(scorers.single.goals, 2);
      expect(
        scorers.any((entry) => entry.actor.id == 'guest-tournament-2'),
        isFalse,
      );
    });

    test('uses displayName then id as deterministic tie-breaker', () async {
      const sameNameLaterId = ParticipantRef(
        kind: ParticipantRefKind.player,
        id: 'player-z',
        displayName: 'Ali',
      );
      const sameNameEarlierId = ParticipantRef(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-a',
        displayName: 'Ali',
      );
      const firstNameActor = ParticipantRef(
        kind: ParticipantRefKind.player,
        id: 'player-b',
        displayName: 'Adam',
      );

      await _recordGoals(
        service: matchEventService,
        tournamentId: 'tournament-1',
        actor: sameNameLaterId,
        count: 2,
        now: now,
      );
      await _recordGoals(
        service: matchEventService,
        tournamentId: 'tournament-1',
        actor: sameNameEarlierId,
        count: 2,
        now: now.add(const Duration(minutes: 1)),
      );
      await _recordGoals(
        service: matchEventService,
        tournamentId: 'tournament-1',
        actor: firstNameActor,
        count: 2,
        now: now.add(const Duration(minutes: 2)),
      );

      final scorers = await resolver.getTopScorers('tournament-1');

      expect(scorers.map((entry) => entry.actor.id), [
        'player-b',
        'guest-a',
        'player-z',
      ]);
    });
  });
}

Future<void> _recordGoals({
  required MatchEventService service,
  required String tournamentId,
  required ParticipantRef actor,
  required int count,
  required DateTime now,
}) async {
  for (var index = 1; index <= count; index += 1) {
    await service.recordGoal(
      eventId: 'goal-$tournamentId-${actor.kind.name}-${actor.id}-$index',
      matchId: 'match-$tournamentId-${actor.id}',
      tournamentId: tournamentId,
      sideKey: 'A',
      actor: actor,
      createdBy: 'organizer-1',
      now: now.add(Duration(seconds: index)),
    );
  }
}
