import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/match_attendance_status.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/core/enums/team_member_availability.dart';
import 'package:el7reef/core/enums/team_membership_role.dart';
import 'package:el7reef/core/services/match_event_service.dart';
import 'package:el7reef/core/services/match_settlement_service.dart';
import 'package:el7reef/core/services/official_match_roster_service.dart';
import 'package:el7reef/core/services/pending_pride_events_service.dart';
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
import 'package:el7reef/data/repositories/tournament_participant_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_lineup_entry.dart';
import 'package:el7reef/domain/entities/match_lineup_snapshot.dart';
import 'package:el7reef/domain/entities/match_participant_roster.dart';
import 'package:el7reef/domain/entities/match_side_player.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/penalty_shootout_result.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/player_match_stats.dart';
import 'package:el7reef/features/match/controllers/score_submit_controller.dart';
import 'package:el7reef/features/match/models/score_submit_draft.dart';
import 'package:el7reef/features/match/services/score_submit_draft_store.dart';
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

    test('restores a match draft after recreating the controller', () async {
      await _saveMatch(
        firestore,
        _match(
          id: 'match-local-draft',
          teamAPlayerIds: const ['player-a'],
          teamBPlayerIds: const ['player-b'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
      final draftStore = _InMemoryScoreSubmitDraftStore();
      final firstController = _controller(
        firestore: firestore,
        matchId: 'match-local-draft',
        draftStore: draftStore,
      );
      await firstController.loadMatchAndPlayers();
      firstController.teamAScoreController.text = '5';
      firstController.teamBScoreController.text = '0';
      firstController.setParticipantGoals(
        firstController.teamAParticipants.single,
        2,
      );
      firstController.selectMvp(
        firstController.participantKey(
          firstController.teamAParticipants.single,
        ),
      );
      await firstController.flushDraft();
      firstController.onClose();

      final restoredController = _controller(
        firestore: firestore,
        matchId: 'match-local-draft',
        draftStore: draftStore,
      );
      await restoredController.loadMatchAndPlayers();

      expect(restoredController.restoredDraft.value, isTrue);
      expect(restoredController.isDirty.value, isTrue);
      expect(restoredController.teamAScoreController.text, '5');
      expect(restoredController.teamBScoreController.text, '0');
      expect(restoredController.totalDraftGoalsForSide('A'), 2);
      expect(restoredController.teamAGoalSummary.attributedGoals, 2);
      expect(restoredController.teamAGoalSummary.unattributedGoals, 3);
      expect(restoredController.selectedMvpSelection?.actor.id, 'player-a');
      restoredController.onClose();
    });

    testWidgets('newer match result blocks stale draft submission', (
      tester,
    ) async {
      await _saveMatch(firestore, _match(id: 'match-stale-draft'));
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-stale-draft',
      );
      await controller.loadMatchAndPlayers();
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
      controller.teamAScoreController.text = '1';
      controller.teamBScoreController.text = '0';

      await MatchRepositoryImpl(db: firestore).updateMatch(
        _match(id: 'match-stale-draft').copyWith(
          status: MatchStatus.completed,
          scoreTeamA: 4,
          scoreTeamB: 3,
          completedAt: now,
        ),
      );

      final submitted = await controller.submit();
      final latest = await MatchRepositoryImpl(
        db: firestore,
      ).getMatch('match-stale-draft');

      expect(submitted, isNull);
      expect(controller.errorMessage.value, contains('تغيّرت نتيجة المباراة'));
      expect(latest?.scoreTeamA, 4);
      expect(latest?.scoreTeamB, 3);
      await _drainSnackbars(tester);
      controller.onClose();
    });

    testWidgets(
      'source refresh failure keeps the score retryable without settling it',
      (tester) async {
        await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
        await _saveMatch(firestore, _match(id: 'match-refresh-failure'));
        final matchRepository = _ControllableMatchRepository(firestore);
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-refresh-failure',
          matchRepository: matchRepository,
        );
        await controller.loadMatchAndPlayers();
        controller.teamAScoreController.text = '2';
        controller.teamBScoreController.text = '1';
        matchRepository.failReads = true;

        final failedSubmission = await controller.submit();
        final matchAfterFailure = await firestore
            .collection(FirebasePaths.matches)
            .doc('match-refresh-failure')
            .get();

        expect(failedSubmission, isNull);
        expect(controller.isLoading.value, isFalse);
        expect(controller.errorMessage.value, contains('حاول مرة أخرى'));
        expect(matchAfterFailure.data()?['scoreTeamA'], isNull);
        expect(matchAfterFailure.data()?['scoreTeamB'], isNull);

        matchRepository.failReads = false;
        final retriedSubmission = await controller.submit();

        expect(retriedSubmission?.scoreTeamA, 2);
        expect(retriedSubmission?.scoreTeamB, 1);
        expect(controller.isLoading.value, isFalse);
        expect(controller.errorMessage.value, isEmpty);
        await _drainSnackbars(tester);
        controller.onClose();
      },
    );

    testWidgets('successful submission clears the local match draft', (
      tester,
    ) async {
      await _saveMatch(firestore, _match(id: 'match-clear-local-draft'));
      final draftStore = _InMemoryScoreSubmitDraftStore();
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-clear-local-draft',
        draftStore: draftStore,
      );
      await controller.loadMatchAndPlayers();
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
      controller.teamAScoreController.text = '1';
      controller.teamBScoreController.text = '0';
      await controller.flushDraft();
      expect(draftStore.drafts, contains('match-clear-local-draft'));

      final submitted = await controller.submit();

      expect(submitted, isNotNull);
      expect(draftStore.drafts, isEmpty);
      expect(controller.isDirty.value, isFalse);
      await _drainSnackbars(tester);
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

    test(
      'tournament score flow resolves guest team participant names',
      () async {
        await _saveTournament(firestore, 'tournament-side-names');
        await _saveTournamentParticipant(
          firestore,
          id: 'participant-france',
          tournamentId: 'tournament-side-names',
          sourceEntityId: 'guest-team-france',
          displayName: 'فرنسا (FRA)',
        );
        await _saveTournamentParticipant(
          firestore,
          id: 'participant-england',
          tournamentId: 'tournament-side-names',
          sourceEntityId: 'guest-team-england',
          displayName: 'إنجلترا (ENG)',
        );
        await _saveMatch(
          firestore,
          _match(
            id: 'match-tournament-side-names',
            tournamentId: 'tournament-side-names',
            teamAId: 'guest-team-france',
            teamBId: 'guest-team-england',
            teamAParticipantId: 'participant-france',
            teamBParticipantId: 'participant-england',
          ),
        );
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-tournament-side-names',
        );

        await controller.loadMatchAndPlayers();

        expect(controller.teamASideName.value, 'فرنسا (FRA)');
        expect(controller.teamBSideName.value, 'إنجلترا (ENG)');
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
      await tester.tap(find.text('التالي: الهدافون'));
      await tester.pumpAndSettle();
      expect(find.text('متبقي 3 أهداف غير منسوبة.'), findsOneWidget);

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

    testWidgets('zero-goal submit voids stale goal MatchEvents', (
      tester,
    ) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
      await _saveMatch(
        firestore,
        _match(
          id: 'match-zero-goals-voids',
          teamAPlayerIds: const ['player-a'],
          teamBPlayerIds: const ['player-b'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
      final matchEventService = MatchEventService(
        repository: MatchEventRepositoryImpl(firestore: firestore),
        firestore: firestore,
      );
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-zero-goals-voids',
      );
      await controller.loadMatchAndPlayers();
      await matchEventService.recordGoal(
        eventId: 'goal-stale-a',
        matchId: 'match-zero-goals-voids',
        sideKey: 'A',
        actor: controller.teamAParticipants.single,
        createdBy: 'organizer-1',
      );
      await matchEventService.recordGoal(
        eventId: 'goal-stale-b',
        matchId: 'match-zero-goals-voids',
        sideKey: 'B',
        actor: controller.teamBParticipants.single,
        createdBy: 'organizer-1',
      );
      expect(
        await _activeGoalEvents(firestore, 'match-zero-goals-voids'),
        hasLength(2),
      );

      controller.teamAScoreController.text = '0';
      controller.teamBScoreController.text = '0';
      final updatedMatch = await controller.submit();

      expect(updatedMatch?.scoreTeamA, 0);
      expect(updatedMatch?.scoreTeamB, 0);
      expect(
        await _activeGoalEvents(firestore, 'match-zero-goals-voids'),
        isEmpty,
      );
      final allGoalEvents = await firestore
          .collection(FirebasePaths.matchEvents)
          .where('matchId', isEqualTo: 'match-zero-goals-voids')
          .where('eventType', isEqualTo: 'goal')
          .get();
      expect(allGoalEvents.docs, hasLength(2));
      expect(
        allGoalEvents.docs.map((doc) => doc.data()['status']),
        everyElement('voided'),
      );
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
      'settlement failure surfaces safe error and no partial score write',
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
          settlementService: _FailingMatchSettlementService(
            firestore: firestore,
          ),
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
        await tester.tap(find.text('التالي: الهدافون'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('التالي: MVP'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('التالي: المراجعة'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('اعتمد النتيجة وجهّز الفخر'));
        await tester.pumpAndSettle();

        expect(controller.errorMessage.value, contains('فشل حفظ النتيجة'));
        expect(
          controller.errorMessage.value,
          isNot(contains('settlement failed')),
        );
        expect(controller.pendingPrideEventRetry.value, isFalse);
        expect(find.text('تم تسجيل النتيجة ✅'), findsNothing);
        expect(
          await _activeGoalEvents(firestore, 'match-event-write-failure'),
          isEmpty,
        );
        final savedMatch = await firestore
            .collection(FirebasePaths.matches)
            .doc('match-event-write-failure')
            .get();
        expect(savedMatch.data()?['scoreTeamA'], isNull);
        expect(savedMatch.data()?['prideEventsPending'], isFalse);
        await _drainSnackbars(tester);
        await tester.pumpAndSettle();
        controller.onClose();
      },
    );

    testWidgets(
      'reloading a match with pending pride events restores retry state',
      (tester) async {
        await _saveMatch(
          firestore,
          _match(
            id: 'match-pride-retry-state',
            teamAPlayerIds: const ['player-a'],
            teamBPlayerIds: const ['player-b'],
            scoreTeamA: 1,
            scoreTeamB: 0,
            status: MatchStatus.completed,
            prideEventsPending: true,
          ),
        );
        await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
        await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-pride-retry-state',
        );

        await controller.loadMatchAndPlayers();

        expect(controller.pendingPrideEventRetry.value, isTrue);
        expect(controller.match.value?.prideEventsPending, isTrue);
        controller.onClose();
      },
    );

    testWidgets(
      'pending pride retry preserves stored penalties for tied knockout',
      (tester) async {
        await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
        await _saveMatch(
          firestore,
          _match(
            id: 'match-pride-retry-payload',
            teamAPlayerIds: const ['player-a'],
            teamBPlayerIds: const ['player-b'],
            scoreTeamA: 2,
            scoreTeamB: 2,
            penaltyScoreTeamA: 5,
            penaltyScoreTeamB: 4,
            stageType: TournamentStageType.knockoutStage,
            status: MatchStatus.completed,
            prideEventsPending: true,
          ),
        );
        await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
        await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
        await firestore
            .collection(FirebasePaths.matches)
            .doc('match-pride-retry-payload')
            .collection(PendingPrideEventsService.collectionName)
            .doc(PendingPrideEventsService.currentDocumentId)
            .set({
              'version': 1,
              'matchId': 'match-pride-retry-payload',
              'scoreTeamA': 2,
              'scoreTeamB': 2,
              'goals': [
                {
                  'sideKey': 'A',
                  'actor': {
                    'kind': 'player',
                    'id': 'player-a',
                    'displayName': 'أحمد',
                    'linkedPlayerId': null,
                  },
                  'goals': 1,
                  'minute': null,
                },
              ],
              'mvp': null,
              'createdBy': 'organizer-1',
              'createdAt': now.millisecondsSinceEpoch,
            });
        final settlementService = _RetryPenaltyBoundarySettlementService(
          firestore: firestore,
          expectedPenaltyShootout: const PenaltyShootoutResult(
            scoreTeamA: 5,
            scoreTeamB: 4,
          ),
        );
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-pride-retry-payload',
          settlementService: settlementService,
        );
        await controller.loadMatchAndPlayers();

        final updatedMatch = await controller.submit();

        expect(updatedMatch, isNotNull);
        expect(updatedMatch?.penaltyShootoutResult?.scoreTeamA, 5);
        expect(updatedMatch?.penaltyShootoutResult?.scoreTeamB, 4);
        expect(updatedMatch?.resolvedKnockoutDecision, KnockoutDecision.teamA);
        expect(controller.pendingPrideEventRetry.value, isFalse);
        expect(controller.errorMessage.value, isEmpty);
        await _drainSnackbars(tester);
        controller.onClose();
      },
    );

    testWidgets(
      'pending pride retry without payload does not clear pending state',
      (tester) async {
        await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
        await _saveMatch(
          firestore,
          _match(
            id: 'match-pride-retry-missing-payload',
            teamAPlayerIds: const ['player-a'],
            teamBPlayerIds: const ['player-b'],
            scoreTeamA: 1,
            scoreTeamB: 0,
            status: MatchStatus.completed,
            prideEventsPending: true,
          ),
        );
        await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
        await _savePlayer(firestore, _player(id: 'player-b', name: 'باسم'));
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-pride-retry-missing-payload',
        );
        await controller.loadMatchAndPlayers();

        final updatedMatch = await controller.submit();

        expect(updatedMatch, isNull);
        expect(controller.pendingPrideEventRetry.value, isTrue);
        final savedMatch = await firestore
            .collection(FirebasePaths.matches)
            .doc('match-pride-retry-missing-payload')
            .get();
        expect(savedMatch.data()?['prideEventsPending'], isTrue);
        expect(
          await _activeGoalEvents(
            firestore,
            'match-pride-retry-missing-payload',
          ),
          isEmpty,
        );
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
      await tester.tap(find.text('التالي: الهدافون'));
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

      await tester.tap(find.text('التالي: MVP'));
      await tester.pumpAndSettle();

      expect(find.text('اختار نجم المباراة'), findsOneWidget);
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

      expect(
        controller.emptyScoringParticipantsRouteForSide('A'),
        AppRoutes.matchLobbyById('match-empty-score-ui'),
      );
      expect(
        controller.emptyScoringParticipantsRouteForSide('B'),
        AppRoutes.matchLobbyById('match-empty-score-ui'),
      );

      await tester.pumpWidget(const GetMaterialApp(home: ScoreSubmitScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('التالي: الهدافون'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'لا يوجد لاعبون متاحون لهذا الطرف. أضف لاعبين للفريق أو لقائمة المباراة قبل تسجيل الأهداف.',
        ),
        findsNWidgets(2),
      );
      expect(find.text('إضافة لاعبين للمباراة'), findsNWidgets(2));
      expect(
        find.text(
          'لا يوجد لاعبون مسجلون لهذا الطرف. اللاعبون المؤقتون لا تُسجل لهم إحصائيات.',
        ),
        findsNothing,
      );
    });

    testWidgets('dirty score draft warns before exit and can be discarded', (
      tester,
    ) async {
      await _saveMatch(firestore, _match(id: 'match-dirty-exit'));
      final draftStore = _InMemoryScoreSubmitDraftStore();
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-dirty-exit',
        draftStore: draftStore,
      );
      Get.put<ScoreSubmitController>(controller);
      await controller.loadMatchAndPlayers();
      await tester.pumpWidget(const GetMaterialApp(home: ScoreSubmitScreen()));

      controller.teamAScoreController.text = '1';
      await controller.flushDraft();
      await tester.pump();
      expect(controller.isDirty.value, isTrue);
      expect(draftStore.drafts, contains('match-dirty-exit'));

      await tester.tap(find.byTooltip('إغلاق تسجيل النتيجة'));
      await tester.pumpAndSettle();
      expect(find.text('تخرج من تسجيل النتيجة؟'), findsOneWidget);

      await tester.tap(find.text('كمّل التسجيل'));
      await tester.pumpAndSettle();
      expect(find.byType(ScoreSubmitScreen), findsOneWidget);

      await tester.tap(find.byTooltip('إغلاق تسجيل النتيجة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('احذف واخرج'));
      await tester.pumpAndSettle();
      expect(draftStore.drafts, isEmpty);
    });

    testWidgets('four score steps fit 360 width at 200 percent text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _saveMatch(
        firestore,
        _match(
          id: 'match-accessible-steps',
          teamAPlayerIds: const ['player-access-a'],
          teamBPlayerIds: const ['player-access-b'],
        ),
      );
      await _savePlayer(
        firestore,
        _player(id: 'player-access-a', name: 'عبد الرحمن الحريف الهداف'),
      );
      await _savePlayer(
        firestore,
        _player(id: 'player-access-b', name: 'محمد أبو زيد حارس الميدان'),
      );
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-accessible-steps',
      );
      Get.put<ScoreSubmitController>(controller);
      await controller.loadMatchAndPlayers();

      await tester.pumpWidget(
        const GetMaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ScoreSubmitScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.tap(find.text('التالي: الهدافون'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final incrementTarget = tester.getSize(
        find.bySemanticsLabel('زيادة القيمة').first,
      );
      expect(incrementTarget.width, greaterThanOrEqualTo(48));
      expect(incrementTarget.height, greaterThanOrEqualTo(48));
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.tap(find.text('التالي: MVP'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('التالي: المراجعة'));
      await tester.pumpAndSettle();
      expect(find.text('راجع قبل الاعتماد'), findsOneWidget);
      expect(tester.takeException(), isNull);
      controller.onClose();
    });

    test('empty scorer state routes registered sides to team roster', () async {
      await _saveMatch(
        firestore,
        _match(id: 'match-empty-team-route', teamAId: 'team-alpha'),
      );
      final controller = _controller(
        firestore: firestore,
        matchId: 'match-empty-team-route',
      );

      await controller.loadMatchAndPlayers();

      expect(
        controller.emptyScoringParticipantsRouteForSide('A'),
        AppRoutes.teamProfileById('team-alpha'),
      );
      expect(
        controller.emptyScoringParticipantsActionLabelForSide('A'),
        'إدارة قائمة الفريق',
      );
      expect(
        controller.emptyScoringParticipantsRouteForSide('B'),
        AppRoutes.matchLobbyById('match-empty-team-route'),
      );
      controller.onClose();
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

    testWidgets(
      'tied knockout stays on score step until penalties pick one winner',
      (tester) async {
        await _saveMatch(
          firestore,
          _match(
            id: 'match-knockout-penalties',
            tournamentId: 'tournament-1',
            stageType: TournamentStageType.knockoutStage,
          ),
        );
        final settlementService = _RecordingMatchSettlementService(
          firestore: firestore,
        );
        final controller = _controller(
          firestore: firestore,
          matchId: 'match-knockout-penalties',
          settlementService: settlementService,
        );
        Get.put<ScoreSubmitController>(controller);
        await controller.loadMatchAndPlayers();

        await tester.pumpWidget(
          const GetMaterialApp(home: ScoreSubmitScreen()),
        );
        controller.teamAScoreController.text = '2';
        controller.teamBScoreController.text = '2';
        await tester.pump();

        expect(find.text('ركلات الترجيح'), findsOneWidget);
        expect(
          find.textContaining('لا تُضاف للأهداف أو ترتيب الهدافين'),
          findsOneWidget,
        );

        await tester.tap(find.text('التالي: الهدافون'));
        await tester.pump();
        expect(controller.currentStepIndex.value, 0);

        controller.teamAPenaltyScoreController.text = '5';
        controller.teamBPenaltyScoreController.text = '5';
        await tester.tap(find.text('التالي: الهدافون'));
        await tester.pump();
        expect(controller.currentStepIndex.value, 0);

        controller.teamBPenaltyScoreController.text = '4';
        await tester.tap(find.text('التالي: الهدافون'));
        await tester.pump();
        expect(controller.currentStepIndex.value, 1);

        await controller.submit();

        expect(settlementService.lastPenaltyShootout?.scoreTeamA, 5);
        expect(settlementService.lastPenaltyShootout?.scoreTeamB, 4);
        expect(controller.teamAGoalSummary.teamScore, 2);
        expect(controller.teamBGoalSummary.teamScore, 2);
        await _drainSnackbars(tester);
        controller.onClose();
      },
    );
  });
}

ScoreSubmitController _controller({
  required FakeFirebaseFirestore firestore,
  required String matchId,
  MatchRepositoryImpl? matchRepository,
  OfficialMatchRosterService? officialRosterService,
  MatchSettlementService? settlementService,
  ScoreSubmitDraftStore? draftStore,
}) {
  return ScoreSubmitController(
    matchId: matchId,
    matchRepository: matchRepository ?? MatchRepositoryImpl(db: firestore),
    settlementService:
        settlementService ??
        MatchSettlementService(
          firestore: firestore,
          tournamentLifecycleService: TournamentLifecycleService(
            firestore: firestore,
          ),
          allowLocalFallback: true,
        ),
    officialRosterService:
        officialRosterService ??
        OfficialMatchRosterService(firestore: firestore),
    sideRepository: MatchSideRepositoryImpl(firestore: firestore),
    sidePlayerRepository: MatchSidePlayerRepositoryImpl(firestore: firestore),
    teamRepository: TeamRepositoryImpl(firestore: firestore),
    participantRepository: TournamentParticipantRepositoryImpl(
      firestore: firestore,
    ),
    tournamentRepository: TournamentRepositoryImpl(firestore: firestore),
    assistantPermissionRepository: TournamentAssistantPermissionRepositoryImpl(
      firestore: firestore,
    ),
    pendingPrideEventsService: PendingPrideEventsService(firestore: firestore),
    draftStore: draftStore ?? _InMemoryScoreSubmitDraftStore(),
    currentUserIdProvider: () => 'organizer-1',
  );
}

class _ControllableMatchRepository extends MatchRepositoryImpl {
  _ControllableMatchRepository(FakeFirebaseFirestore firestore)
    : super(db: firestore);

  bool failReads = false;

  @override
  Future<Match?> getMatch(String matchId) {
    if (failReads) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'network unavailable',
      );
    }
    return super.getMatch(matchId);
  }
}

class _InMemoryScoreSubmitDraftStore implements ScoreSubmitDraftStore {
  final Map<String, ScoreSubmitDraft> drafts = {};

  @override
  Future<ScoreSubmitDraft?> load(String matchId) async => drafts[matchId];

  @override
  Future<void> save(ScoreSubmitDraft draft) async {
    drafts[draft.matchId] = draft;
  }

  @override
  Future<void> clear(String matchId) async {
    drafts.remove(matchId);
  }
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
    List<MatchSettlementGoalDraft> goalDrafts = const [],
    MatchSettlementMvpDraft? mvpDraft,
    PenaltyShootoutResult? penaltyShootout,
  }) async {
    throw StateError('settlement failed');
  }
}

class _RecordingMatchSettlementService extends MatchSettlementService {
  _RecordingMatchSettlementService({required FakeFirebaseFirestore firestore})
    : super(firestore: firestore);

  PenaltyShootoutResult? lastPenaltyShootout;

  @override
  Future<MatchSettlementResult> submitScore({
    required String matchId,
    required String actorId,
    required int scoreA,
    required int scoreB,
    String? mvpPlayerId,
    List<PlayerMatchStats> detailedStats = const [],
    List<MatchSettlementGoalDraft> goalDrafts = const [],
    MatchSettlementMvpDraft? mvpDraft,
    PenaltyShootoutResult? penaltyShootout,
  }) async {
    lastPenaltyShootout = penaltyShootout;
    return const MatchSettlementResult(
      status: MatchStatus.completed,
      ratingsApplied: false,
      alreadySettled: true,
    );
  }
}

class _RetryPenaltyBoundarySettlementService extends MatchSettlementService {
  final PenaltyShootoutResult expectedPenaltyShootout;

  _RetryPenaltyBoundarySettlementService({
    required FakeFirebaseFirestore firestore,
    required this.expectedPenaltyShootout,
  }) : super(firestore: firestore);

  @override
  Future<MatchSettlementResult> submitScore({
    required String matchId,
    required String actorId,
    required int scoreA,
    required int scoreB,
    String? mvpPlayerId,
    List<PlayerMatchStats> detailedStats = const [],
    List<MatchSettlementGoalDraft> goalDrafts = const [],
    MatchSettlementMvpDraft? mvpDraft,
    PenaltyShootoutResult? penaltyShootout,
  }) async {
    if (scoreA != scoreB ||
        penaltyShootout?.scoreTeamA != expectedPenaltyShootout.scoreTeamA ||
        penaltyShootout?.scoreTeamB != expectedPenaltyShootout.scoreTeamB) {
      throw StateError('retry did not preserve the stored penalty shootout');
    }
    return const MatchSettlementResult(
      status: MatchStatus.completed,
      ratingsApplied: false,
      alreadySettled: true,
    );
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

Match _match({
  required String id,
  String? tournamentId,
  String? teamAId,
  String? teamBId,
  String? teamAParticipantId,
  String? teamBParticipantId,
  List<String> teamAPlayerIds = const [],
  List<String> teamBPlayerIds = const [],
  int? scoreTeamA,
  int? scoreTeamB,
  int? penaltyScoreTeamA,
  int? penaltyScoreTeamB,
  TournamentStageType? stageType,
  MatchStatus status = MatchStatus.live,
  bool prideEventsPending = false,
}) {
  return Match(
    id: id,
    organizerId: 'organizer-1',
    tournamentId: tournamentId,
    teamAId: teamAId,
    teamBId: teamBId,
    teamAParticipantId: teamAParticipantId,
    teamBParticipantId: teamBParticipantId,
    teamAPlayerIds: teamAPlayerIds,
    teamBPlayerIds: teamBPlayerIds,
    scoreTeamA: scoreTeamA,
    scoreTeamB: scoreTeamB,
    penaltyScoreTeamA: penaltyScoreTeamA,
    penaltyScoreTeamB: penaltyScoreTeamB,
    stageType: stageType,
    status: status,
    prideEventsPending: prideEventsPending,
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

Future<void> _saveTournamentParticipant(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String tournamentId,
  required String sourceEntityId,
  required String displayName,
}) async {
  final timestamp = DateTime(2026, 5, 4, 20).millisecondsSinceEpoch;
  await firestore.collection(FirebasePaths.tournamentParticipants).doc(id).set({
    'tournamentId': tournamentId,
    'sourceType': TournamentParticipantSourceType.guestTeam.name,
    'sourceEntityId': sourceEntityId,
    'displayName': displayName,
    'status': TournamentParticipantStatus.finalized.name,
    'createdAt': timestamp,
    'updatedAt': timestamp,
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
  Get.closeAllSnackbars();
  await tester.pumpAndSettle();
}
