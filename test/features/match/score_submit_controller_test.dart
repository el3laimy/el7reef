import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/match_attendance_status.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/team_member_availability.dart';
import 'package:el7reef/core/enums/team_membership_role.dart';
import 'package:el7reef/core/services/match_event_service.dart';
import 'package:el7reef/core/services/match_settlement_service.dart';
import 'package:el7reef/core/services/official_match_roster_service.dart';
import 'package:el7reef/core/services/tournament_lifecycle_service.dart';
import 'package:el7reef/data/repositories/match_event_repository_impl.dart';
import 'package:el7reef/data/models/guest_player_model.dart';
import 'package:el7reef/data/models/match_lineup_snapshot_model.dart';
import 'package:el7reef/data/models/match_model.dart';
import 'package:el7reef/data/models/match_side_player_model.dart';
import 'package:el7reef/data/models/player_model.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/match_side_player_repository_impl.dart';
import 'package:el7reef/data/repositories/match_side_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_assistant_permission_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_event.dart';
import 'package:el7reef/domain/entities/match_lineup_entry.dart';
import 'package:el7reef/domain/entities/match_lineup_snapshot.dart';
import 'package:el7reef/domain/entities/match_participant_roster.dart';
import 'package:el7reef/domain/entities/match_side_player.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/player_match_stats.dart';
import 'package:el7reef/features/match/controllers/score_submit_controller.dart';
import 'package:el7reef/features/match/views/score_submit_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScoreSubmitController full participant roster', () {
    late FakeFirebaseFirestore firestore;
    late DateTime now;

    setUp(() {
      Get.testMode = true;
      firestore = FakeFirebaseFirestore();
      now = DateTime(2026, 5, 4, 20);
    });

    tearDown(Get.reset);

    test('loads full participants for registered players', () async {
      await _saveMatch(
        firestore,
        _match(
          id: 'match-registered',
          teamAPlayerIds: const ['player-a'],
          teamBPlayerIds: const ['player-b'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-registered',
      );

      await controller.loadMatchAndPlayers();

      expect(controller.teamAPlayers.map((player) => player.id), ['player-a']);
      expect(controller.teamBPlayers.map((player) => player.id), ['player-b']);
      expect(
        controller.teamAParticipants.single.kind,
        ParticipantRefKind.player,
      );
      expect(controller.teamAParticipants.single.id, 'player-a');
      expect(
        controller.teamBParticipants.single.kind,
        ParticipantRefKind.player,
      );
      expect(controller.teamBParticipants.single.id, 'player-b');
      expect(controller.allParticipants, hasLength(2));
      controller.onClose();
    });

    test('loads guest participants from the full roster', () async {
      await _saveMatch(firestore, _match(id: 'match-guest'));
      await _saveGuestPlayer(
        firestore,
        GuestPlayer(
          id: 'guest-1',
          displayName: 'ضيف مهاري',
          normalizedName: 'ضيف مهاري',
          createdBy: 'organizer-1',
          createdAt: now,
          updatedAt: now,
          linkedPlayerId: 'claimed-player',
        ),
      );
      await _saveLineupSnapshot(
        firestore,
        _snapshot(
          id: 'snapshot-guest',
          matchId: 'match-guest',
          sideKey: 'A',
          entries: [
            _entry(
              attendanceId: 'attendance-guest',
              guestPlayerId: 'guest-1',
              displayName: 'ضيف مهاري',
            ),
          ],
        ),
      );
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-guest',
      );

      await controller.loadMatchAndPlayers();

      expect(controller.teamAPlayers, isEmpty);
      expect(controller.teamAParticipants, hasLength(1));
      expect(
        controller.teamAParticipants.single.kind,
        ParticipantRefKind.guestPlayer,
      );
      expect(controller.teamAParticipants.single.id, 'guest-1');
      expect(
        controller.teamAParticipants.single.linkedPlayerId,
        'claimed-player',
      );
      expect(
        controller.isParticipantOnSide(
          controller.teamAParticipants.single,
          'A',
        ),
        isTrue,
      );
      controller.onClose();
    });

    test(
      'loads temporary match-side participants from the full roster',
      () async {
        await _saveMatch(firestore, _match(id: 'match-temporary'));
        await _saveMatchSidePlayer(
          firestore,
          MatchSidePlayer(
            id: 'temporary-1',
            matchId: 'match-temporary',
            sideKey: 'B',
            sideId: 'match-temporary_B',
            kind: 'temporary',
            displayName: 'لاعب مؤقت',
            ratingEligible: false,
            addedBy: 'organizer-1',
            createdAt: now,
          ),
        );
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-temporary',
        );

        await controller.loadMatchAndPlayers();

        expect(controller.teamBParticipants, hasLength(1));
        expect(
          controller.teamBParticipants.single.kind,
          ParticipantRefKind.matchSidePlayer,
        );
        expect(controller.teamBParticipants.single.id, 'temporary-1');
        expect(
          controller.sideKeyForParticipant(controller.teamBParticipants.single),
          'B',
        );
        controller.onClose();
      },
    );

    test(
      'keeps registered roster usable when full participant roster load fails',
      () async {
        await _saveMatch(
          firestore,
          _match(
            id: 'match-roster-failure',
            teamAPlayerIds: const ['player-a'],
            teamBPlayerIds: const ['player-b'],
          ),
        );
        await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
        await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-roster-failure',
          officialRosterService: _FailingParticipantRosterService(
            firestore: firestore,
          ),
        );

        await expectLater(controller.loadMatchAndPlayers(), completes);

        expect(controller.errorMessage.value, isEmpty);
        expect(controller.fullParticipantRoster.value, isNull);
        expect(controller.fullRosterErrorMessage.value, isNotEmpty);
        expect(controller.teamAParticipants, isEmpty);
        expect(controller.teamBParticipants, isEmpty);
        expect(controller.allParticipants, isEmpty);
        expect(controller.teamAPlayers.map((player) => player.id), [
          'player-a',
        ]);
        expect(controller.teamBPlayers.map((player) => player.id), [
          'player-b',
        ]);
        expect(controller.playerStats, contains('player-a'));
        expect(controller.playerStats, contains('player-b'));

        controller.incrementStat('player-a', 'goals');

        expect(controller.playerStats['player-a']?['goals'], 1);
        controller.onClose();
      },
    );

    test('adds goal drafts for registered participants', () async {
      await _saveMatch(
        firestore,
        _match(
          id: 'match-registered-goals',
          teamAPlayerIds: const ['player-a'],
          teamBPlayerIds: const ['player-b'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-registered-goals',
      );
      await controller.loadMatchAndPlayers();

      final participant = controller.teamAParticipants.single;
      controller.setParticipantGoals(participant, 2);

      expect(controller.allGoalDrafts, hasLength(1));
      expect(
        controller.allGoalDrafts.single.actor.kind,
        ParticipantRefKind.player,
      );
      expect(controller.allGoalDrafts.single.actor.id, 'player-a');
      expect(controller.allGoalDrafts.single.sideKey, 'A');
      expect(controller.allGoalDrafts.single.goals, 2);
      expect(controller.totalDraftGoalsForSide('A'), 2);
      expect(controller.totalDraftGoalsForSide('B'), 0);
      expect(controller.totalTeamAGoals, 2);
      expect(controller.teamAScoreController.text, '2');
      expect(controller.playerStats['player-a']?['goals'], 2);
      controller.onClose();
    });

    test('adds goal drafts for guest participants', () async {
      await _saveMatch(firestore, _match(id: 'match-guest-goals'));
      await _saveGuestPlayer(
        firestore,
        GuestPlayer(
          id: 'guest-scorer',
          displayName: 'ضيف هداف',
          normalizedName: 'ضيف هداف',
          createdBy: 'organizer-1',
          createdAt: now,
          updatedAt: now,
          linkedPlayerId: 'claimed-scorer',
        ),
      );
      await _saveLineupSnapshot(
        firestore,
        _snapshot(
          id: 'snapshot-guest-goals',
          matchId: 'match-guest-goals',
          sideKey: 'A',
          entries: [
            _entry(
              attendanceId: 'attendance-guest-scorer',
              guestPlayerId: 'guest-scorer',
              displayName: 'ضيف هداف',
            ),
          ],
        ),
      );
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-guest-goals',
      );
      await controller.loadMatchAndPlayers();

      controller.setParticipantGoals(controller.teamAParticipants.single, 1);

      expect(controller.allGoalDrafts, hasLength(1));
      expect(
        controller.allGoalDrafts.single.actor.kind,
        ParticipantRefKind.guestPlayer,
      );
      expect(controller.allGoalDrafts.single.actor.id, 'guest-scorer');
      expect(
        controller.allGoalDrafts.single.actor.linkedPlayerId,
        'claimed-scorer',
      );
      expect(controller.allGoalDrafts.single.sideKey, 'A');
      expect(controller.totalDraftGoalsForSide('A'), 1);
      expect(controller.totalTeamAGoals, 1);
      expect(controller.teamAScoreController.text, '1');
      controller.onClose();
    });

    test('adds goal drafts for temporary match-side participants', () async {
      await _saveMatch(firestore, _match(id: 'match-temporary-goals'));
      await _saveMatchSidePlayer(
        firestore,
        MatchSidePlayer(
          id: 'temporary-scorer',
          matchId: 'match-temporary-goals',
          sideKey: 'B',
          sideId: 'match-temporary-goals_B',
          kind: 'temporary',
          displayName: 'لاعب مؤقت',
          ratingEligible: false,
          addedBy: 'organizer-1',
          createdAt: now,
        ),
      );
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-temporary-goals',
      );
      await controller.loadMatchAndPlayers();

      controller.setParticipantGoals(controller.teamBParticipants.single, 3);

      expect(controller.allGoalDrafts, hasLength(1));
      expect(
        controller.allGoalDrafts.single.actor.kind,
        ParticipantRefKind.matchSidePlayer,
      );
      expect(controller.allGoalDrafts.single.actor.id, 'temporary-scorer');
      expect(controller.allGoalDrafts.single.sideKey, 'B');
      expect(controller.totalDraftGoalsForSide('B'), 3);
      expect(controller.totalTeamBGoals, 3);
      expect(controller.teamBScoreController.text, '3');
      controller.onClose();
    });

    test('mixed registered and guest goals contribute to side total', () async {
      await _saveMatch(
        firestore,
        _match(id: 'match-mixed-goals', teamAPlayerIds: const ['player-a']),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _saveGuestPlayer(
        firestore,
        GuestPlayer(
          id: 'guest-a',
          displayName: 'ضيف الفريق',
          normalizedName: 'ضيف الفريق',
          createdBy: 'organizer-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _saveLineupSnapshot(
        firestore,
        _snapshot(
          id: 'snapshot-mixed-goals',
          matchId: 'match-mixed-goals',
          sideKey: 'A',
          entries: [
            _entry(
              attendanceId: 'attendance-player-a',
              playerId: 'player-a',
              displayName: 'أحمد',
            ),
            _entry(
              attendanceId: 'attendance-guest-a',
              guestPlayerId: 'guest-a',
              displayName: 'ضيف الفريق',
            ),
          ],
        ),
      );
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-mixed-goals',
      );
      await controller.loadMatchAndPlayers();

      final registered = controller.teamAParticipants.firstWhere(
        (participant) => participant.id == 'player-a',
      );
      final guest = controller.teamAParticipants.firstWhere(
        (participant) => participant.id == 'guest-a',
      );
      controller.setParticipantGoals(registered, 1);
      controller.setParticipantGoals(guest, 2);

      expect(controller.totalDraftGoalsForSide('A'), 3);
      expect(controller.totalTeamAGoals, 3);
      expect(controller.teamAScoreController.text, '3');
      expect(controller.playerStats['player-a']?['goals'], 1);
      expect(controller.goalsForParticipant(guest), 2);
      controller.onClose();
    });

    test(
      'registered guest and match-side goals contribute to side total',
      () async {
        await _saveMatch(
          firestore,
          _match(
            id: 'match-all-kind-goals',
            teamAPlayerIds: const ['player-a'],
          ),
        );
        await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
        await _saveGuestPlayer(
          firestore,
          GuestPlayer(
            id: 'guest-a',
            displayName: 'ضيف الفريق',
            normalizedName: 'ضيف الفريق',
            createdBy: 'organizer-1',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await _saveMatchSidePlayer(
          firestore,
          MatchSidePlayer(
            id: 'temporary-a',
            matchId: 'match-all-kind-goals',
            sideKey: 'A',
            sideId: 'match-all-kind-goals_A',
            kind: 'temporary',
            displayName: 'لاعب قائمة',
            ratingEligible: false,
            addedBy: 'organizer-1',
            createdAt: now,
          ),
        );
        await _saveLineupSnapshot(
          firestore,
          _snapshot(
            id: 'snapshot-all-kind-goals',
            matchId: 'match-all-kind-goals',
            sideKey: 'A',
            entries: [
              _entry(
                attendanceId: 'attendance-player-a',
                playerId: 'player-a',
                displayName: 'أحمد',
              ),
              _entry(
                attendanceId: 'attendance-guest-a',
                guestPlayerId: 'guest-a',
                displayName: 'ضيف الفريق',
              ),
              _entry(
                attendanceId: 'attendance-temporary-a',
                matchSidePlayerId: 'temporary-a',
                displayName: 'لاعب قائمة',
              ),
            ],
          ),
        );
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-all-kind-goals',
        );
        await controller.loadMatchAndPlayers();

        final registered = controller.teamAParticipants.firstWhere(
          (participant) => participant.kind == ParticipantRefKind.player,
        );
        final guest = controller.teamAParticipants.firstWhere(
          (participant) => participant.kind == ParticipantRefKind.guestPlayer,
        );
        final temporary = controller.teamAParticipants.firstWhere(
          (participant) =>
              participant.kind == ParticipantRefKind.matchSidePlayer,
        );
        controller.setParticipantGoals(registered, 1);
        controller.setParticipantGoals(guest, 2);
        controller.setParticipantGoals(temporary, 3);

        expect(controller.totalDraftGoalsForSide('A'), 6);
        expect(controller.teamAGoalSummary.attributedGoals, 6);
        expect(controller.teamAGoalSummary.unattributedGoals, 0);
        expect(controller.totalTeamAGoals, 6);
        expect(controller.teamAScoreController.text, '6');
        controller.onClose();
      },
    );

    test('ignores invalid goal draft participants safely', () async {
      await _saveMatch(
        firestore,
        _match(id: 'match-invalid-goals', teamAPlayerIds: const ['player-a']),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-invalid-goals',
      );
      await controller.loadMatchAndPlayers();

      controller.setParticipantGoals(
        const ParticipantRef(
          kind: ParticipantRefKind.player,
          id: 'outside-player',
          displayName: 'خارج القائمة',
        ),
        1,
      );
      controller.setParticipantGoals(controller.teamAParticipants.single, -1);

      expect(controller.allGoalDrafts, isEmpty);
      expect(controller.totalDraftGoalsForSide('A'), 0);
      controller.onClose();
    });

    test('full roster null prevents adding goal drafts safely', () async {
      await _saveMatch(
        firestore,
        _match(
          id: 'match-null-roster-goals',
          teamAPlayerIds: const ['player-a'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-null-roster-goals',
        officialRosterService: _FailingParticipantRosterService(
          firestore: firestore,
        ),
      );
      await controller.loadMatchAndPlayers();

      controller.setParticipantGoals(
        const ParticipantRef(
          kind: ParticipantRefKind.player,
          id: 'player-a',
          displayName: 'أحمد',
        ),
        1,
      );

      expect(controller.fullParticipantRoster.value, isNull);
      expect(controller.allGoalDrafts, isEmpty);
      controller.onClose();
    });

    test('clears individual and all goal drafts', () async {
      await _saveMatch(
        firestore,
        _match(
          id: 'match-clear-goals',
          teamAPlayerIds: const ['player-a'],
          teamBPlayerIds: const ['player-b'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-clear-goals',
      );
      await controller.loadMatchAndPlayers();
      final sideA = controller.teamAParticipants.single;
      final sideB = controller.teamBParticipants.single;
      controller.setParticipantGoals(sideA, 1);
      controller.setParticipantGoals(sideB, 2);

      controller.clearParticipantGoals(sideA);

      expect(controller.allGoalDrafts, hasLength(1));
      expect(controller.allGoalDrafts.single.actor.id, 'player-b');

      controller.clearGoalDrafts();

      expect(controller.allGoalDrafts, isEmpty);
      controller.onClose();
    });

    testWidgets('submit with registered goal drafts writes goal MatchEvents', (
      tester,
    ) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
      await _saveMatch(
        firestore,
        _match(
          id: 'match-registered-goal-events',
          teamAPlayerIds: const ['player-a'],
          teamBPlayerIds: const ['player-b'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-registered-goal-events',
      );
      await controller.loadMatchAndPlayers();

      controller.teamAScoreController.text = '2';
      controller.teamBScoreController.text = '0';
      controller.selectMvp('player-a');
      controller.setParticipantGoals(controller.teamAParticipants.single, 2);
      final updatedMatch = await controller.submit();

      expect(updatedMatch?.scoreTeamA, 2);
      final goals = await _activeGoalEvents(
        firestore,
        'match-registered-goal-events',
      );
      expect(goals, hasLength(2));
      expect(
        goals.map((event) => event['id']),
        containsAll([
          'goal-match-registered-goal-events-A-player-player-a-1',
          'goal-match-registered-goal-events-A-player-player-a-2',
        ]),
      );
      for (final goal in goals) {
        final actor = goal['actor'] as Map<String, dynamic>;
        expect(goal['eventType'], 'goal');
        expect(goal['sideKey'], 'A');
        expect(goal['createdBy'], 'organizer-1');
        expect(goal['minute'], isNull);
        expect(actor['kind'], 'player');
        expect(actor['id'], 'player-a');
        expect(actor['displayName'], 'أحمد');
      }
      expect(
        await _activeMvpEvents(firestore, 'match-registered-goal-events'),
        hasLength(1),
      );
      await _drainSnackbars(tester);
      controller.onClose();
    });

    testWidgets('submit with guest goal drafts writes goal MatchEvents', (
      tester,
    ) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
      await _saveMatch(firestore, _match(id: 'match-guest-goal-events'));
      await _saveGuestPlayer(
        firestore,
        GuestPlayer(
          id: 'guest-scorer',
          displayName: 'ضيف هداف',
          normalizedName: 'ضيف هداف',
          createdBy: 'organizer-1',
          createdAt: now,
          updatedAt: now,
          linkedPlayerId: 'claimed-scorer',
        ),
      );
      await _saveLineupSnapshot(
        firestore,
        _snapshot(
          id: 'snapshot-guest-goal-events',
          matchId: 'match-guest-goal-events',
          sideKey: 'A',
          entries: [
            _entry(
              attendanceId: 'attendance-guest-scorer',
              guestPlayerId: 'guest-scorer',
              displayName: 'ضيف هداف',
            ),
          ],
        ),
      );
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-guest-goal-events',
      );
      await controller.loadMatchAndPlayers();

      controller.teamAScoreController.text = '1';
      controller.teamBScoreController.text = '0';
      controller.setParticipantGoals(controller.teamAParticipants.single, 1);
      await controller.submit();

      final goals = await _activeGoalEvents(
        firestore,
        'match-guest-goal-events',
      );
      final actor = goals.single['actor'] as Map<String, dynamic>;
      expect(
        goals.single['id'],
        'goal-match-guest-goal-events-A-guestPlayer-guest-scorer-1',
      );
      expect(goals.single['sideKey'], 'A');
      expect(actor['kind'], 'guestPlayer');
      expect(actor['id'], 'guest-scorer');
      expect(actor['displayName'], 'ضيف هداف');
      expect(actor['linkedPlayerId'], 'claimed-scorer');
      expect(
        await _activeMvpEvents(firestore, 'match-guest-goal-events'),
        isEmpty,
      );
      await _drainSnackbars(tester);
      controller.onClose();
    });

    testWidgets(
      'guest-only tournament match can submit score, guest goals, and guest MVP',
      (tester) async {
        await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
        await _saveTournament(firestore, 'tournament-guest-score');
        await _saveMatch(
          firestore,
          _match(
            id: 'match-tournament-guest-score',
            tournamentId: 'tournament-guest-score',
          ),
        );
        await _saveGuestPlayer(
          firestore,
          GuestPlayer(
            id: 'guest-tournament-scorer',
            displayName: 'ضيف البطولة',
            normalizedName: 'ضيف البطولة',
            createdBy: 'organizer-1',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await _saveLineupSnapshot(
          firestore,
          _snapshot(
            id: 'snapshot-tournament-guest-score',
            matchId: 'match-tournament-guest-score',
            sideKey: 'A',
            entries: [
              _entry(
                attendanceId: 'attendance-tournament-guest',
                guestPlayerId: 'guest-tournament-scorer',
                displayName: 'ضيف البطولة',
              ),
            ],
          ),
        );
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-tournament-guest-score',
        );
        await controller.loadMatchAndPlayers();

        controller.setParticipantGoals(controller.teamAParticipants.single, 2);
        controller.selectMvp('guest-tournament-scorer');
        final updatedMatch = await controller.submit();

        expect(updatedMatch?.scoreTeamA, 2);
        expect(updatedMatch?.scoreTeamB, 0);
        expect(updatedMatch?.mvpPlayerId, 'guest-tournament-scorer');
        final goals = await _activeGoalEvents(
          firestore,
          'match-tournament-guest-score',
        );
        expect(goals, hasLength(2));
        for (final goal in goals) {
          final actor = goal['actor'] as Map<String, dynamic>;
          expect(goal['tournamentId'], 'tournament-guest-score');
          expect(goal['sideKey'], 'A');
          expect(actor['kind'], 'guestPlayer');
          expect(actor['id'], 'guest-tournament-scorer');
        }
        final mvpEvents = await _activeMvpEvents(
          firestore,
          'match-tournament-guest-score',
        );
        final mvpActor = mvpEvents.single['actor'] as Map<String, dynamic>;
        expect(mvpEvents.single['tournamentId'], 'tournament-guest-score');
        expect(mvpActor['kind'], 'guestPlayer');
        expect(mvpActor['id'], 'guest-tournament-scorer');
        await _drainSnackbars(tester);
        controller.onClose();
      },
    );

    testWidgets(
      'submit with temporary match-side goal drafts writes goal MatchEvents',
      (tester) async {
        await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
        await _saveMatch(firestore, _match(id: 'match-temporary-goal-events'));
        await _saveMatchSidePlayer(
          firestore,
          MatchSidePlayer(
            id: 'temporary-scorer',
            matchId: 'match-temporary-goal-events',
            sideKey: 'B',
            sideId: 'match-temporary-goal-events_B',
            kind: 'temporary',
            displayName: 'لاعب مؤقت',
            ratingEligible: false,
            addedBy: 'organizer-1',
            createdAt: now,
          ),
        );
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-temporary-goal-events',
        );
        await controller.loadMatchAndPlayers();

        controller.teamAScoreController.text = '0';
        controller.teamBScoreController.text = '1';
        controller.setParticipantGoals(controller.teamBParticipants.single, 1);
        await controller.submit();

        final goals = await _activeGoalEvents(
          firestore,
          'match-temporary-goal-events',
        );
        final actor = goals.single['actor'] as Map<String, dynamic>;
        expect(
          goals.single['id'],
          'goal-match-temporary-goal-events-B-matchSidePlayer-temporary-scorer-1',
        );
        expect(goals.single['sideKey'], 'B');
        expect(actor['kind'], 'matchSidePlayer');
        expect(actor['id'], 'temporary-scorer');
        expect(actor['displayName'], 'لاعب مؤقت');
        await _drainSnackbars(tester);
        controller.onClose();
      },
    );

    testWidgets(
      'goal draft mismatch warns by helper but does not block submit',
      (tester) async {
        await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
        await _saveMatch(
          firestore,
          _match(
            id: 'match-goal-mismatch',
            teamAPlayerIds: const ['player-a'],
            teamBPlayerIds: const ['player-b'],
          ),
        );
        await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
        await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-goal-mismatch',
        );
        await controller.loadMatchAndPlayers();

        controller.teamAScoreController.text = '2';
        controller.teamBScoreController.text = '0';
        controller.setParticipantGoals(controller.teamAParticipants.single, 1);

        expect(controller.totalDraftGoalsForSide('A'), 1);
        expect(controller.goalDraftMismatchForSide('A'), isTrue);

        final updatedMatch = await controller.submit();

        expect(updatedMatch?.scoreTeamA, 2);
        expect(updatedMatch?.scoreTeamB, 0);
        expect(controller.teamAGoalSummary.unattributedGoals, 1);
        expect(
          await _activeGoalEvents(firestore, 'match-goal-mismatch'),
          hasLength(1),
        );
        await _drainSnackbars(tester);
        controller.onClose();
      },
    );

    testWidgets('score summary shows unattributed goals and still submits', (
      tester,
    ) async {
      await _saveMatch(
        firestore,
        _match(
          id: 'match-unattributed-summary',
          teamAPlayerIds: const ['player-a'],
          teamBPlayerIds: const ['player-b'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-unattributed-summary',
      );
      Get.put<ScoreSubmitController>(controller);
      await controller.loadMatchAndPlayers();
      controller.setParticipantGoals(controller.teamAParticipants.single, 2);
      controller.teamAScoreController.text = '5';
      controller.teamBScoreController.text = '0';

      await tester.pumpWidget(const GetMaterialApp(home: ScoreSubmitScreen()));
      await tester.pumpAndSettle();

      expect(controller.teamAGoalSummary.teamScore, 5);
      expect(controller.teamAGoalSummary.attributedGoals, 2);
      expect(controller.teamAGoalSummary.unattributedGoals, 3);
      expect(find.text('نتيجة الفريق: 5'), findsOneWidget);
      expect(find.text('الأهداف المنسوبة: 2'), findsOneWidget);
      expect(find.text('أهداف غير منسوبة: 3'), findsOneWidget);
      expect(find.text('لن تظهر في الهدافين.'), findsOneWidget);

      final updatedMatch = await controller.submit();

      expect(updatedMatch?.scoreTeamA, 5);
      expect(updatedMatch?.scoreTeamB, 0);
      expect(
        await _activeGoalEvents(firestore, 'match-unattributed-summary'),
        hasLength(2),
      );
      await _drainSnackbars(tester);
      controller.onClose();
    });

    testWidgets('attributed goals greater than score blocks submission', (
      tester,
    ) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
      await _saveMatch(
        firestore,
        _match(
          id: 'match-over-attributed',
          teamAPlayerIds: const ['player-a'],
          teamBPlayerIds: const ['player-b'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-over-attributed',
      );
      await controller.loadMatchAndPlayers();

      controller.setParticipantGoals(controller.teamAParticipants.single, 2);
      controller.teamAScoreController.text = '1';
      controller.teamBScoreController.text = '0';
      final updatedMatch = await controller.submit();

      expect(updatedMatch, isNull);
      expect(controller.teamAGoalSummary.isOverAttributed, isTrue);
      expect(
        controller.errorMessage.value,
        ScoreSubmitController.attributionOverScoreMessage,
      );
      await _expectNoGoalEvents(firestore, 'match-over-attributed');
      await _drainSnackbars(tester);
      controller.onClose();
    });

    testWidgets('submit with registered MVP writes one MVP MatchEvent', (
      tester,
    ) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
      await _saveMatch(
        firestore,
        _match(
          id: 'match-registered-mvp',
          teamAPlayerIds: const ['player-a'],
          teamBPlayerIds: const ['player-b'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-registered-mvp',
      );
      await controller.loadMatchAndPlayers();

      controller.teamAScoreController.text = '1';
      controller.teamBScoreController.text = '0';
      controller.selectMvp('player-a');
      await controller.submit();

      final events = await _activeMvpEvents(firestore, 'match-registered-mvp');
      final actor = events.single['actor'] as Map<String, dynamic>;
      expect(events.single['id'], 'mvp-match-registered-mvp');
      expect(events.single['eventType'], 'mvp');
      expect(events.single['matchId'], 'match-registered-mvp');
      expect(events.single['sideKey'], 'A');
      expect(events.single['createdBy'], 'organizer-1');
      expect(events.single['status'], 'active');
      expect(actor['kind'], 'player');
      expect(actor['id'], 'player-a');
      expect(actor['displayName'], 'أحمد');
      expect(actor['linkedPlayerId'], isNull);
      await _expectNoGoalEvents(firestore, 'match-registered-mvp');
      await _drainSnackbars(tester);
      controller.onClose();
    });

    testWidgets(
      'submit with temporary match-side MVP writes one MVP MatchEvent',
      (tester) async {
        await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
        await _saveMatch(firestore, _match(id: 'match-temporary-mvp'));
        await _saveMatchSidePlayer(
          firestore,
          MatchSidePlayer(
            id: 'temporary-mvp',
            matchId: 'match-temporary-mvp',
            sideKey: 'B',
            sideId: 'match-temporary-mvp_B',
            kind: 'temporary',
            displayName: 'لاعب مؤقت',
            ratingEligible: false,
            addedBy: 'organizer-1',
            createdAt: now,
          ),
        );
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-temporary-mvp',
        );
        await controller.loadMatchAndPlayers();

        controller.teamAScoreController.text = '0';
        controller.teamBScoreController.text = '1';
        controller.selectMvp('temporary-mvp');
        await controller.submit();

        final events = await _activeMvpEvents(firestore, 'match-temporary-mvp');
        final actor = events.single['actor'] as Map<String, dynamic>;
        expect(events.single['id'], 'mvp-match-temporary-mvp');
        expect(events.single['sideKey'], 'B');
        expect(actor['kind'], 'matchSidePlayer');
        expect(actor['id'], 'temporary-mvp');
        expect(actor['displayName'], 'لاعب مؤقت');
        await _expectNoGoalEvents(firestore, 'match-temporary-mvp');
        await _drainSnackbars(tester);
        controller.onClose();
      },
    );

    testWidgets(
      'MVP selection uses kind id key to avoid participant id collision',
      (tester) async {
        await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
        await _saveMatch(
          firestore,
          _match(
            id: 'match-mvp-key-collision',
            teamAPlayerIds: const ['same-id'],
          ),
        );
        await _savePlayer(firestore, _player(id: 'same-id', name: 'لاعب مسجل'));
        await _saveGuestPlayer(
          firestore,
          GuestPlayer(
            id: 'same-id',
            displayName: 'ضيف بنفس المعرف',
            normalizedName: 'ضيف بنفس المعرف',
            createdBy: 'organizer-1',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await _saveLineupSnapshot(
          firestore,
          _snapshot(
            id: 'snapshot-mvp-key-collision',
            matchId: 'match-mvp-key-collision',
            sideKey: 'B',
            entries: [
              _entry(
                attendanceId: 'attendance-guest-collision',
                guestPlayerId: 'same-id',
                displayName: 'ضيف بنفس المعرف',
              ),
            ],
          ),
        );
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-mvp-key-collision',
        );
        await controller.loadMatchAndPlayers();
        final guest = controller.teamBParticipants.singleWhere(
          (participant) => participant.kind == ParticipantRefKind.guestPlayer,
        );

        controller.teamAScoreController.text = '0';
        controller.teamBScoreController.text = '1';
        controller.selectMvp(controller.participantKey(guest));
        await controller.submit();

        final events = await _activeMvpEvents(
          firestore,
          'match-mvp-key-collision',
        );
        final actor = events.single['actor'] as Map<String, dynamic>;
        expect(controller.participantKey(guest), 'guestPlayer:same-id');
        expect(actor['kind'], 'guestPlayer');
        expect(actor['id'], 'same-id');
        expect(actor['displayName'], 'ضيف بنفس المعرف');
        await _drainSnackbars(tester);
        controller.onClose();
      },
    );

    testWidgets('submit with no MVP writes no MVP MatchEvent', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
      await _saveMatch(
        firestore,
        _match(
          id: 'match-no-mvp',
          teamAPlayerIds: const ['player-a'],
          teamBPlayerIds: const ['player-b'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-no-mvp',
      );
      await controller.loadMatchAndPlayers();

      controller.teamAScoreController.text = '0';
      controller.teamBScoreController.text = '0';
      await controller.submit();

      expect(await _activeMvpEvents(firestore, 'match-no-mvp'), isEmpty);
      await _expectNoGoalEvents(firestore, 'match-no-mvp');
      await _drainSnackbars(tester);
      controller.onClose();
    });

    testWidgets('submitScore failure writes no MVP MatchEvent', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
      await _saveMatch(
        firestore,
        _match(
          id: 'match-submit-failure',
          teamAPlayerIds: const ['player-a'],
          teamBPlayerIds: const ['player-b'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-submit-failure',
        settlementService: _FailingMatchSettlementService(firestore: firestore),
      );
      await controller.loadMatchAndPlayers();

      controller.teamAScoreController.text = '1';
      controller.teamBScoreController.text = '0';
      controller.selectMvp('player-a');
      controller.setParticipantGoals(controller.teamAParticipants.single, 1);
      final updatedMatch = await controller.submit();

      expect(updatedMatch, isNull);
      expect(
        await _activeMvpEvents(firestore, 'match-submit-failure'),
        isEmpty,
      );
      await _expectNoGoalEvents(firestore, 'match-submit-failure');
      await _drainSnackbars(tester);
      controller.onClose();
    });

    testWidgets(
      'event recording failure surfaces safe error and no success sheet',
      (tester) async {
        await _saveMatch(
          firestore,
          _match(
            id: 'match-event-write-failure',
            teamAPlayerIds: const ['player-a'],
            teamBPlayerIds: const ['player-b'],
          ),
        );
        await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
        await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-event-write-failure',
          matchEventService: _FailingMatchEventService(firestore: firestore),
        );
        Get.put<ScoreSubmitController>(controller);
        await controller.loadMatchAndPlayers();
        controller.teamAScoreController.text = '1';
        controller.teamBScoreController.text = '0';
        controller.setParticipantGoals(controller.teamAParticipants.single, 1);

        await tester.pumpWidget(
          const GetMaterialApp(home: ScoreSubmitScreen()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('اعتمد النتيجة وجهّز الفخر'));
        await tester.pumpAndSettle();

        expect(controller.errorMessage.value, contains('فشل تسجيل أحداث'));
        expect(
          controller.errorMessage.value,
          isNot(contains('event write failed')),
        );
        expect(controller.pendingPrideEventRetry.value, isTrue);
        expect(find.text('تم تسجيل النتيجة ✅'), findsNothing);
        expect(
          await _activeGoalEvents(firestore, 'match-event-write-failure'),
          isEmpty,
        );
        final savedMatch = await firestore
            .collection(FirebasePaths.matches)
            .doc('match-event-write-failure')
            .get();
        expect(savedMatch.data()?['scoreTeamA'], 1);
        await _drainSnackbars(tester);
        controller.onClose();
      },
    );

    testWidgets(
      'repeated submit does not create duplicate active goal MatchEvents',
      (tester) async {
        await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
        await _saveMatch(
          firestore,
          _match(
            id: 'match-repeat-goals',
            teamAPlayerIds: const ['player-a'],
            teamBPlayerIds: const ['player-b'],
          ),
        );
        await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
        await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-repeat-goals',
        );
        await controller.loadMatchAndPlayers();

        controller.teamAScoreController.text = '2';
        controller.teamBScoreController.text = '0';
        controller.setParticipantGoals(controller.teamAParticipants.single, 2);
        await controller.submit();
        await firestore
            .collection(FirebasePaths.matches)
            .doc('match-repeat-goals')
            .update({'status': MatchStatus.live.name});
        await controller.submit();

        final goals = await _activeGoalEvents(firestore, 'match-repeat-goals');
        expect(goals, hasLength(2));
        expect(
          goals.map((event) => event['id']),
          containsAll([
            'goal-match-repeat-goals-A-player-player-a-1',
            'goal-match-repeat-goals-A-player-player-a-2',
          ]),
        );
        await _drainSnackbars(tester);
        controller.onClose();
      },
    );

    testWidgets(
      'repeated submit does not create duplicate active MVP MatchEvents',
      (tester) async {
        await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
        await _saveMatch(
          firestore,
          _match(
            id: 'match-repeat-mvp',
            teamAPlayerIds: const ['player-a'],
            teamBPlayerIds: const ['player-b'],
          ),
        );
        await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
        await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-repeat-mvp',
        );
        await controller.loadMatchAndPlayers();

        controller.teamAScoreController.text = '1';
        controller.teamBScoreController.text = '0';
        controller.selectMvp('player-a');
        await controller.submit();
        await firestore
            .collection(FirebasePaths.matches)
            .doc('match-repeat-mvp')
            .update({'status': MatchStatus.live.name});
        await controller.submit();

        final events = await _activeMvpEvents(firestore, 'match-repeat-mvp');
        expect(events, hasLength(1));
        expect(events.single['id'], 'mvp-match-repeat-mvp');
        await _expectNoGoalEvents(firestore, 'match-repeat-mvp');
        await _drainSnackbars(tester);
        controller.onClose();
      },
    );

    testWidgets(
      'submits registered detailed stats while allowing guest MVP selection',
      (tester) async {
        await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
        await _saveMatch(
          firestore,
          _match(
            id: 'match-submit',
            teamAPlayerIds: const ['player-a'],
            teamBPlayerIds: const ['player-b'],
          ),
        );
        await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
        await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
        await _saveGuestPlayer(
          firestore,
          GuestPlayer(
            id: 'guest-mvp',
            displayName: 'ضيف المباراة',
            normalizedName: 'ضيف المباراة',
            createdBy: 'organizer-1',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await _saveLineupSnapshot(
          firestore,
          _snapshot(
            id: 'snapshot-submit-guest',
            matchId: 'match-submit',
            sideKey: 'A',
            entries: [
              _entry(
                attendanceId: 'attendance-guest-mvp',
                guestPlayerId: 'guest-mvp',
                displayName: 'ضيف المباراة',
              ),
            ],
          ),
        );
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-submit',
        );
        await controller.loadMatchAndPlayers();

        controller.incrementStat('player-a', 'goals');
        controller.teamAScoreController.text = '1';
        controller.teamBScoreController.text = '0';
        controller.selectMvp('guest-mvp');
        final updatedMatch = await controller.submit();

        expect(updatedMatch?.mvpPlayerId, 'guest-mvp');
        expect(updatedMatch?.scoreTeamA, 1);
        expect(updatedMatch?.scoreTeamB, 0);
        final playerAStats = await firestore
            .collection(FirebasePaths.matches)
            .doc('match-submit')
            .collection('player_stats')
            .doc('player-a')
            .get();
        final playerBStats = await firestore
            .collection(FirebasePaths.matches)
            .doc('match-submit')
            .collection('player_stats')
            .doc('player-b')
            .get();
        final guestStats = await firestore
            .collection(FirebasePaths.matches)
            .doc('match-submit')
            .collection('player_stats')
            .doc('guest-mvp')
            .get();
        expect(playerAStats.exists, isTrue);
        expect(playerAStats.data()?['goals'], 1);
        expect(playerBStats.exists, isTrue);
        expect(guestStats.exists, isFalse);
        final events = await _activeMvpEvents(firestore, 'match-submit');
        final actor = events.single['actor'] as Map<String, dynamic>;
        expect(events.single['id'], 'mvp-match-submit');
        expect(events.single['eventType'], 'mvp');
        expect(events.single['sideKey'], 'A');
        expect(actor['kind'], 'guestPlayer');
        expect(actor['id'], 'guest-mvp');
        expect(actor['displayName'], 'ضيف المباراة');
        expect(actor['linkedPlayerId'], isNull);
        await _expectNoGoalEvents(firestore, 'match-submit');
        await _drainSnackbars(tester);
        controller.onClose();
      },
    );

    testWidgets('guest-only match side renders scorer controls', (
      tester,
    ) async {
      await _saveMatch(firestore, _match(id: 'match-guest-score-ui'));
      await _saveGuestPlayer(
        firestore,
        GuestPlayer(
          id: 'guest-ui-scorer',
          displayName: 'ضيف الواجهة',
          normalizedName: 'ضيف الواجهة',
          createdBy: 'organizer-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _saveLineupSnapshot(
        firestore,
        _snapshot(
          id: 'snapshot-guest-score-ui',
          matchId: 'match-guest-score-ui',
          sideKey: 'A',
          entries: [
            _entry(
              attendanceId: 'attendance-guest-ui',
              guestPlayerId: 'guest-ui-scorer',
              displayName: 'ضيف الواجهة',
            ),
          ],
        ),
      );
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-guest-score-ui',
      );
      Get.put<ScoreSubmitController>(controller);
      await controller.loadMatchAndPlayers();

      await tester.pumpWidget(const GetMaterialApp(home: ScoreSubmitScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ضيف الواجهة'), findsOneWidget);
      expect(find.text('أهداف'), findsOneWidget);
      expect(
        find.text(
          'لا يوجد لاعبون مسجلون لهذا الطرف. اللاعبون المؤقتون لا تُسجل لهم إحصائيات.',
        ),
        findsNothing,
      );

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();

      expect(controller.totalTeamAGoals, 1);
      expect(controller.teamAScoreController.text, '1');
      expect(
        controller.allGoalDrafts.single.actor.kind,
        ParticipantRefKind.guestPlayer,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('أفضل لاعب (MVP)'), findsOneWidget);
      expect(find.text('ضيف الواجهة (ضيف)'), findsOneWidget);
    });

    testWidgets('no-player side shows safe actionable empty state', (
      tester,
    ) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(1440, 3200);
      tester.view.devicePixelRatio = 1.0;

      await _saveMatch(firestore, _match(id: 'match-empty-score-ui'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-empty-score-ui',
      );
      Get.put<ScoreSubmitController>(controller);
      await controller.loadMatchAndPlayers();

      await tester.pumpWidget(const GetMaterialApp(home: ScoreSubmitScreen()));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'لا يوجد لاعبون متاحون لهذا الطرف. أضف لاعبين للفريق أو لقائمة المباراة قبل تسجيل الأهداف.',
        ),
        findsNWidgets(2),
      );
      expect(
        find.text(
          'لا يوجد لاعبون مسجلون لهذا الطرف. اللاعبون المؤقتون لا تُسجل لهم إحصائيات.',
        ),
        findsNothing,
      );
    });

    testWidgets('full roster loading error is visible in score screen', (
      tester,
    ) async {
      await _saveMatch(
        firestore,
        _match(
          id: 'match-roster-error-visible',
          teamAPlayerIds: const ['player-a'],
          teamBPlayerIds: const ['player-b'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-roster-error-visible',
        officialRosterService: _FailingParticipantRosterService(
          firestore: firestore,
        ),
      );
      Get.put<ScoreSubmitController>(controller);
      await controller.loadMatchAndPlayers();

      await tester.pumpWidget(const GetMaterialApp(home: ScoreSubmitScreen()));
      await tester.pumpAndSettle();

      expect(controller.fullRosterErrorMessage.value, isNotEmpty);
      expect(
        find.textContaining('تعذر تحميل قائمة المشاركين الكاملة'),
        findsOneWidget,
      );
      expect(
        find.textContaining('اختيارات الهدافين وMVP قد تكون غير مكتملة'),
        findsOneWidget,
      );
      controller.onClose();
    });
  });
}

ScoreSubmitController _controller({
  required FakeFirebaseFirestore firestore,
  required String matchId,
  OfficialMatchRosterService? officialRosterService,
  MatchSettlementService? settlementService,
  MatchEventService? matchEventService,
}) {
  return ScoreSubmitController(
    matchId: matchId,
    matchRepository: MatchRepositoryImpl(db: firestore),
    settlementService:
        settlementService ??
        MatchSettlementService(
          firestore: firestore,
          tournamentLifecycleService: TournamentLifecycleService(
            firestore: firestore,
          ),
        ),
    matchEventService:
        matchEventService ??
        MatchEventService(
          repository: MatchEventRepositoryImpl(firestore: firestore),
          firestore: firestore,
        ),
    officialRosterService:
        officialRosterService ??
        OfficialMatchRosterService(firestore: firestore),
    sideRepository: MatchSideRepositoryImpl(firestore: firestore),
    sidePlayerRepository: MatchSidePlayerRepositoryImpl(firestore: firestore),
    teamRepository: TeamRepositoryImpl(firestore: firestore),
    tournamentRepository: TournamentRepositoryImpl(firestore: firestore),
    assistantPermissionRepository:
        TournamentAssistantPermissionRepositoryImpl(firestore: firestore),
    currentUserIdProvider: () => 'organizer-1',
  );
}

class _FailingMatchSettlementService extends MatchSettlementService {
  _FailingMatchSettlementService({required FakeFirebaseFirestore firestore})
    : super(firestore: firestore);

  @override
  Future<MatchSettlementResult> submitScore({
    required String matchId,
    required String actorId,
    required int scoreA,
    required int scoreB,
    String? mvpPlayerId,
    List<PlayerMatchStats> detailedStats = const [],
  }) async {
    throw StateError('settlement failed');
  }
}

class _FailingParticipantRosterService extends OfficialMatchRosterService {
  _FailingParticipantRosterService({required FakeFirebaseFirestore firestore})
    : super(firestore: firestore);

  @override
  Future<MatchParticipantRoster> loadParticipantRoster({
    required String matchId,
    Match? match,
  }) async {
    throw StateError('full roster unavailable');
  }
}

class _FailingMatchEventService extends MatchEventService {
  _FailingMatchEventService({required FakeFirebaseFirestore firestore})
    : super(
        repository: MatchEventRepositoryImpl(firestore: firestore),
        firestore: firestore,
      );

  @override
  Future<MatchEvent> recordGoal({
    String? eventId,
    required String matchId,
    String? tournamentId,
    required String sideKey,
    required ParticipantRef actor,
    int? minute,
    required String createdBy,
    DateTime? now,
  }) {
    throw StateError('event write failed');
  }
}

Match _match({
  required String id,
  String? tournamentId,
  List<String> teamAPlayerIds = const [],
  List<String> teamBPlayerIds = const [],
}) {
  return Match(
    id: id,
    organizerId: 'organizer-1',
    tournamentId: tournamentId,
    teamAPlayerIds: teamAPlayerIds,
    teamBPlayerIds: teamBPlayerIds,
    status: MatchStatus.live,
    createdAt: DateTime(2026, 5, 4, 20),
  );
}

Player _player({required String id, required String name}) {
  final now = DateTime(2026, 5, 4, 20);
  return Player(id: id, name: name, createdAt: now, lastActiveAt: now);
}

MatchLineupSnapshot _snapshot({
  required String id,
  required String matchId,
  required String sideKey,
  required List<MatchLineupEntry> entries,
}) {
  return MatchLineupSnapshot(
    id: id,
    matchId: matchId,
    matchSideId: '${matchId}_$sideKey',
    sideKey: sideKey,
    starters: entries,
    lockedBy: 'organizer-1',
    lockedAt: DateTime(2026, 5, 4, 20),
  );
}

MatchLineupEntry _entry({
  required String attendanceId,
  String? playerId,
  String? guestPlayerId,
  String? matchSidePlayerId,
  required String displayName,
}) {
  return MatchLineupEntry(
    attendanceId: attendanceId,
    playerId: playerId,
    guestPlayerId: guestPlayerId,
    matchSidePlayerId: matchSidePlayerId,
    role: TeamMembershipRole.player,
    availability: TeamMemberAvailability.available,
    attendanceStatus: MatchAttendanceStatus.present,
    displayName: displayName,
  );
}

Future<void> _saveMatch(FakeFirebaseFirestore firestore, Match match) async {
  await firestore
      .collection(FirebasePaths.matches)
      .doc(match.id)
      .set(MatchModel.fromEntity(match).toJson());
}

Future<void> _saveTournament(
  FakeFirebaseFirestore firestore,
  String tournamentId,
) async {
  await firestore.collection(FirebasePaths.tournaments).doc(tournamentId).set({
    'organizerId': 'organizer-1',
    'name': 'بطولة الضيوف',
    'format': 'groupsOnly',
    'teamSize': 5,
    'maxTeams': 8,
    'status': 'groupStage',
    'registeredTeamIds': <String>[],
    'assistants': <Map<String, dynamic>>[],
    'isFantasyEnabled': false,
    'createdAt': DateTime(2026, 5, 4, 20).millisecondsSinceEpoch,
  });
}

Future<void> _savePlayer(FakeFirebaseFirestore firestore, Player player) async {
  await firestore
      .collection(FirebasePaths.players)
      .doc(player.id)
      .set(PlayerModel.fromEntity(player).toJson());
}

Future<void> _saveGuestPlayer(
  FakeFirebaseFirestore firestore,
  GuestPlayer guestPlayer,
) async {
  await firestore
      .collection(FirebasePaths.guestPlayers)
      .doc(guestPlayer.id)
      .set(GuestPlayerModel.fromEntity(guestPlayer).toJson());
}

Future<void> _saveMatchSidePlayer(
  FakeFirebaseFirestore firestore,
  MatchSidePlayer player,
) async {
  await firestore
      .collection(FirebasePaths.matchSidePlayers)
      .doc(player.id)
      .set(MatchSidePlayerModel.fromEntity(player).toJson());
}

Future<void> _saveLineupSnapshot(
  FakeFirebaseFirestore firestore,
  MatchLineupSnapshot snapshot,
) async {
  await firestore
      .collection(FirebasePaths.matchLineupSnapshots)
      .doc(snapshot.id)
      .set(MatchLineupSnapshotModel.fromEntity(snapshot).toJson());
}

Future<List<Map<String, dynamic>>> _activeMvpEvents(
  FakeFirebaseFirestore firestore,
  String matchId,
) async {
  final snapshot = await firestore
      .collection(FirebasePaths.matchEvents)
      .where('matchId', isEqualTo: matchId)
      .where('eventType', isEqualTo: 'mvp')
      .where('status', isEqualTo: 'active')
      .get();
  return snapshot.docs
      .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
      .toList(growable: false);
}

Future<List<Map<String, dynamic>>> _activeGoalEvents(
  FakeFirebaseFirestore firestore,
  String matchId,
) async {
  final snapshot = await firestore
      .collection(FirebasePaths.matchEvents)
      .where('matchId', isEqualTo: matchId)
      .where('eventType', isEqualTo: 'goal')
      .where('status', isEqualTo: 'active')
      .get();
  return snapshot.docs
      .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
      .toList(growable: false);
}

Future<void> _expectNoGoalEvents(
  FakeFirebaseFirestore firestore,
  String matchId,
) async {
  final snapshot = await firestore
      .collection(FirebasePaths.matchEvents)
      .where('matchId', isEqualTo: matchId)
      .where('eventType', isEqualTo: 'goal')
      .get();
  expect(snapshot.docs, isEmpty);
}

Future<void> _drainSnackbars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpAndSettle();
}
