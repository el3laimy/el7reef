import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/services/match_event_service.dart';
import 'package:el7reef/data/repositories/match_event_repository_impl.dart';
import 'package:el7reef/domain/entities/match_event.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';

void main() {
  group('MatchEventService', () {
    late FakeFirebaseFirestore firestore;
    late MatchEventService service;
    late DateTime now;

    const registeredActor = ParticipantRef(
      kind: ParticipantRefKind.player,
      id: 'player-1',
      displayName: 'Registered Hero',
    );
    const guestActor = ParticipantRef(
      kind: ParticipantRefKind.guestPlayer,
      id: 'guest-player-1',
      displayName: 'Guest Hero',
      linkedPlayerId: 'player-9',
    );

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = MatchEventService(
        repository: MatchEventRepositoryImpl(firestore: firestore),
      );
      now = DateTime(2026, 5, 3, 20);
    });

    test(
      'records and loads active goal and MVP events for all player kinds',
      () async {
        final goal = await service.recordGoal(
          eventId: 'goal-1',
          matchId: 'match-1',
          tournamentId: 'tournament-1',
          sideKey: 'a',
          actor: guestActor,
          minute: 7,
          createdBy: 'organizer-1',
          now: now,
        );
        final mvp = await service.recordMvp(
          eventId: 'mvp-1',
          matchId: 'match-1',
          tournamentId: 'tournament-1',
          sideKey: 'B',
          actor: registeredActor,
          createdBy: 'organizer-1',
          now: now.add(const Duration(minutes: 1)),
        );

        final matchEvents = await service.getMatchEvents('match-1');
        final tournamentGoals = await service.getTournamentGoalEvents(
          'tournament-1',
        );
        final loadedMvp = await service.getMvpEvent('match-1');

        expect(goal.id, 'goal-1');
        expect(goal.sideKey, 'A');
        expect(goal.actor.kind, ParticipantRefKind.guestPlayer);
        expect(goal.actor.linkedPlayerId, 'player-9');
        expect(mvp.eventType, MatchEventType.mvp);
        expect(matchEvents.map((event) => event.id), ['goal-1', 'mvp-1']);
        expect(tournamentGoals.map((event) => event.id), ['goal-1']);
        expect(loadedMvp?.id, 'mvp-1');
      },
    );

    test(
      'records multiple goals and sorts by minute then created time',
      () async {
        await service.recordGoals(
          matchId: 'match-1',
          tournamentId: 'tournament-1',
          createdBy: 'organizer-1',
          now: now,
          goals: const [
            MatchGoalDraft(
              eventId: 'goal-late',
              sideKey: 'A',
              actor: registeredActor,
              minute: 30,
            ),
            MatchGoalDraft(
              eventId: 'goal-early',
              sideKey: 'B',
              actor: guestActor,
              minute: 5,
            ),
          ],
        );

        final matchEvents = await service.getMatchEvents('match-1');

        expect(matchEvents.map((event) => event.id), [
          'goal-early',
          'goal-late',
        ]);
        expect(
          matchEvents.every((event) => event.eventType == MatchEventType.goal),
          isTrue,
        );
      },
    );

    test('records and loads a guest player MVP event', () async {
      final event = await service.recordMvp(
        eventId: 'mvp-guest-1',
        matchId: 'match-guest-mvp',
        tournamentId: 'tournament-1',
        sideKey: 'A',
        actor: guestActor,
        createdBy: 'organizer-1',
        now: now,
      );

      final loadedMvp = await service.getMvpEvent('match-guest-mvp');

      expect(event.eventType, MatchEventType.mvp);
      expect(event.actor.kind, ParticipantRefKind.guestPlayer);
      expect(event.actor.id, 'guest-player-1');
      expect(loadedMvp?.id, 'mvp-guest-1');
      expect(loadedMvp?.eventType, MatchEventType.mvp);
      expect(loadedMvp?.actor.kind, ParticipantRefKind.guestPlayer);
      expect(loadedMvp?.actor.id, 'guest-player-1');
    });

    test('voids an event so match and tournament queries exclude it', () async {
      await service.recordGoal(
        eventId: 'goal-1',
        matchId: 'match-1',
        tournamentId: 'tournament-1',
        sideKey: 'A',
        actor: registeredActor,
        createdBy: 'organizer-1',
        now: now,
      );

      await service.voidEvent('goal-1');

      final matchEvents = await service.getMatchEvents('match-1');
      final tournamentGoals = await service.getTournamentGoalEvents(
        'tournament-1',
      );
      final rawDoc = await firestore
          .collection(FirebasePaths.matchEvents)
          .doc('goal-1')
          .get();

      expect(matchEvents, isEmpty);
      expect(tournamentGoals, isEmpty);
      expect(rawDoc.data()?['status'], 'voided');
    });

    test('validates required fields, side keys, and minutes', () async {
      expect(
        service.recordGoal(
          matchId: ' ',
          sideKey: 'A',
          actor: registeredActor,
          createdBy: 'organizer-1',
        ),
        throwsArgumentError,
      );
      expect(
        service.recordGoal(
          matchId: 'match-1',
          sideKey: 'C',
          actor: registeredActor,
          createdBy: 'organizer-1',
        ),
        throwsArgumentError,
      );
      expect(
        service.recordGoal(
          matchId: 'match-1',
          sideKey: 'A',
          actor: registeredActor,
          minute: -1,
          createdBy: 'organizer-1',
        ),
        throwsArgumentError,
      );
      expect(
        service.recordMvp(
          matchId: 'match-1',
          sideKey: 'A',
          actor: const ParticipantRef(
            kind: ParticipantRefKind.guestPlayer,
            id: '',
            displayName: 'Missing Id',
          ),
          createdBy: 'organizer-1',
        ),
        throwsArgumentError,
      );
    });
  });
}
