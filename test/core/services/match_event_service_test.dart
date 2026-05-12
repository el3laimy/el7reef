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
        firestore: firestore,
      );
      now = DateTime(2026, 5, 3, 20);
    });

    test(
      'records and loads active goal and MVP events for all player kinds',
      () async {
        await _seedMatch(firestore, matchId: 'match-1');
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
      'allows active assistant to record goal and derives tournament id',
      () async {
        await _seedMatch(firestore, matchId: 'match-1');
        await _seedAssistantPermission(firestore);

        final goal = await service.recordGoal(
          eventId: 'assistant-goal-1',
          matchId: 'match-1',
          sideKey: 'A',
          actor: guestActor,
          minute: 11,
          createdBy: 'assistant-1',
          now: now,
        );

        expect(goal.createdBy, 'assistant-1');
        expect(goal.tournamentId, 'tournament-1');
        expect(goal.eventType, MatchEventType.goal);
        final loaded = await service.getMatchEvents('match-1');
        expect(loaded.single.id, 'assistant-goal-1');
      },
    );

    test('allows active assistant to record MVP', () async {
      await _seedMatch(firestore, matchId: 'match-1');
      await _seedAssistantPermission(firestore);

      final mvp = await service.recordMvp(
        eventId: 'assistant-mvp-1',
        matchId: 'match-1',
        tournamentId: 'tournament-1',
        sideKey: 'B',
        actor: registeredActor,
        createdBy: 'assistant-1',
        now: now,
      );

      expect(mvp.createdBy, 'assistant-1');
      expect(mvp.tournamentId, 'tournament-1');
      expect(mvp.eventType, MatchEventType.mvp);
      final loaded = await service.getMvpEvent('match-1');
      expect(loaded?.id, 'assistant-mvp-1');
    });

    test(
      'records multiple goals and sorts by minute then created time',
      () async {
        await _seedMatch(firestore, matchId: 'match-1');
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
      await _seedMatch(firestore, matchId: 'match-guest-mvp');
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
      await _seedMatch(firestore, matchId: 'match-1');
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

    test('denies random user goal and MVP event creation', () async {
      await _seedMatch(firestore, matchId: 'match-1');

      expect(
        () => service.recordGoal(
          eventId: 'forged-goal-1',
          matchId: 'match-1',
          tournamentId: 'tournament-1',
          sideKey: 'A',
          actor: registeredActor,
          createdBy: 'account-b',
          now: now,
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'لا تملك صلاحية تسجيل أحداث هذه المباراة',
            ),
          ),
        ),
      );
      expect(
        () => service.recordMvp(
          eventId: 'forged-mvp-1',
          matchId: 'match-1',
          tournamentId: 'tournament-1',
          sideKey: 'A',
          actor: guestActor,
          createdBy: 'account-b',
          now: now,
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'لا تملك صلاحية تسجيل أحداث هذه المباراة',
            ),
          ),
        ),
      );

      final events = await service.getMatchEvents('match-1');
      expect(events, isEmpty);
    });

    test('denies assistant without canRecordGoalsAndMvp', () async {
      await _seedMatch(firestore, matchId: 'match-1');
      await _seedAssistantPermission(firestore, canRecordGoalsAndMvp: false);

      expect(
        () => service.recordGoal(
          eventId: 'assistant-denied-goal-1',
          matchId: 'match-1',
          tournamentId: 'tournament-1',
          sideKey: 'A',
          actor: registeredActor,
          createdBy: 'assistant-1',
          now: now,
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'لا تملك صلاحية تسجيل أحداث هذه المباراة',
            ),
          ),
        ),
      );
      expect(
        () => service.recordMvp(
          eventId: 'assistant-denied-mvp-1',
          matchId: 'match-1',
          tournamentId: 'tournament-1',
          sideKey: 'B',
          actor: guestActor,
          createdBy: 'assistant-1',
          now: now,
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'لا تملك صلاحية تسجيل أحداث هذه المباراة',
            ),
          ),
        ),
      );
      expect(await service.getMatchEvents('match-1'), isEmpty);
    });

    test('denies revoked assistant goal and MVP event creation', () async {
      await _seedMatch(firestore, matchId: 'match-1');
      await _seedAssistantPermission(firestore, status: 'revoked');

      expect(
        () => service.recordGoal(
          eventId: 'revoked-goal-1',
          matchId: 'match-1',
          tournamentId: 'tournament-1',
          sideKey: 'A',
          actor: registeredActor,
          createdBy: 'assistant-1',
          now: now,
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'لا تملك صلاحية تسجيل أحداث هذه المباراة',
            ),
          ),
        ),
      );
      expect(
        () => service.recordMvp(
          eventId: 'revoked-mvp-1',
          matchId: 'match-1',
          tournamentId: 'tournament-1',
          sideKey: 'B',
          actor: guestActor,
          createdBy: 'assistant-1',
          now: now,
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'لا تملك صلاحية تسجيل أحداث هذه المباراة',
            ),
          ),
        ),
      );
      expect(await service.getMatchEvents('match-1'), isEmpty);
    });

    test('denies assistant from another tournament', () async {
      await _seedMatch(
        firestore,
        matchId: 'match-2',
        organizerId: 'organizer-2',
        tournamentId: 'tournament-2',
      );
      await _seedAssistantPermission(firestore, tournamentId: 'tournament-1');

      expect(
        () => service.recordGoal(
          eventId: 'wrong-tournament-assistant-goal-1',
          matchId: 'match-2',
          tournamentId: 'tournament-2',
          sideKey: 'A',
          actor: registeredActor,
          createdBy: 'assistant-1',
          now: now,
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'لا تملك صلاحية تسجيل أحداث هذه المباراة',
            ),
          ),
        ),
      );
      expect(
        () => service.recordMvp(
          eventId: 'wrong-tournament-assistant-mvp-1',
          matchId: 'match-2',
          tournamentId: 'tournament-2',
          sideKey: 'B',
          actor: guestActor,
          createdBy: 'assistant-1',
          now: now,
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'لا تملك صلاحية تسجيل أحداث هذه المباراة',
            ),
          ),
        ),
      );
      expect(await service.getMatchEvents('match-2'), isEmpty);
    });

    test(
      'friendly match remains organizer-only and ignores assistant permission',
      () async {
        await _seedMatch(firestore, matchId: 'friendly-1', tournamentId: null);
        await _seedAssistantPermission(firestore);

        final organizerGoal = await service.recordGoal(
          eventId: 'friendly-organizer-goal-1',
          matchId: 'friendly-1',
          sideKey: 'A',
          actor: registeredActor,
          createdBy: 'organizer-1',
          now: now,
        );
        expect(organizerGoal.tournamentId, isNull);

        expect(
          () => service.recordGoal(
            eventId: 'friendly-assistant-goal-1',
            matchId: 'friendly-1',
            sideKey: 'A',
            actor: guestActor,
            createdBy: 'assistant-1',
            now: now,
          ),
          throwsA(
            predicate(
              (error) => error.toString().contains(
                'لا تملك صلاحية تسجيل أحداث هذه المباراة',
              ),
            ),
          ),
        );
        final events = await service.getMatchEvents('friendly-1');
        expect(events.map((event) => event.id), ['friendly-organizer-goal-1']);
      },
    );

    test(
      'denies missing match and tournament mismatch event creation',
      () async {
        await _seedMatch(firestore, matchId: 'match-1');

        expect(
          () => service.recordGoal(
            eventId: 'missing-match-goal-1',
            matchId: 'missing-match',
            tournamentId: 'tournament-1',
            sideKey: 'A',
            actor: registeredActor,
            createdBy: 'organizer-1',
            now: now,
          ),
          throwsA(
            predicate(
              (error) => error.toString().contains('تعذر العثور على المباراة'),
            ),
          ),
        );
        expect(
          () => service.recordGoal(
            eventId: 'mismatch-goal-1',
            matchId: 'match-1',
            tournamentId: 'other-tournament',
            sideKey: 'A',
            actor: registeredActor,
            createdBy: 'organizer-1',
            now: now,
          ),
          throwsA(
            predicate(
              (error) => error.toString().contains('لا تطابق المباراة'),
            ),
          ),
        );
      },
    );

    test('validates required fields, side keys, and minutes', () async {
      await _seedMatch(firestore, matchId: 'match-1', tournamentId: null);
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

Future<void> _seedAssistantPermission(
  FakeFirebaseFirestore firestore, {
  String tournamentId = 'tournament-1',
  String userId = 'assistant-1',
  String addedBy = 'organizer-1',
  bool canRecordGoalsAndMvp = true,
  String status = 'active',
}) {
  final timestamp = DateTime(2026, 5, 3, 19).millisecondsSinceEpoch;
  return firestore
      .collection(FirebasePaths.tournaments)
      .doc(tournamentId)
      .collection('assistants')
      .doc(userId)
      .set({
        'tournamentId': tournamentId,
        'userId': userId,
        'addedBy': addedBy,
        'status': status,
        'preset': 'customLimited',
        'permissions': {
          'canViewMatchday': true,
          'canStartMatch': false,
          'canSubmitScore': false,
          'canRecordGoalsAndMvp': canRecordGoalsAndMvp,
          'canApproveScore': false,
          'canDeclareForfeit': false,
        },
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'revokedAt': status == 'revoked' ? timestamp : null,
      });
}

Future<void> _seedMatch(
  FakeFirebaseFirestore firestore, {
  required String matchId,
  String organizerId = 'organizer-1',
  String? tournamentId = 'tournament-1',
}) {
  return firestore.collection(FirebasePaths.matches).doc(matchId).set({
    'organizerId': organizerId,
    'tournamentId': tournamentId,
    'createdAt': DateTime(2026, 5, 3, 20).millisecondsSinceEpoch,
  });
}
