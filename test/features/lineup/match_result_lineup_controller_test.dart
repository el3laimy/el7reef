import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/enums/match_attendance_status.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/team_member_availability.dart';
import 'package:el7reef/core/enums/team_membership_role.dart';
import 'package:el7reef/core/services/match_event_service.dart';
import 'package:el7reef/data/repositories/match_event_repository_impl.dart';
import 'package:el7reef/data/repositories/match_lineup_snapshot_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/match_side_player_repository_impl.dart';
import 'package:el7reef/data/repositories/match_side_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_event.dart';
import 'package:el7reef/domain/entities/match_lineup_entry.dart';
import 'package:el7reef/domain/entities/match_lineup_snapshot.dart';
import 'package:el7reef/domain/entities/match_side_player.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/features/lineup/controllers/match_result_lineup_controller.dart';
import 'package:el7reef/features/lineup/views/match_result_lineup_screen.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('MatchResultLineupController MVP share helpers', () {
    test('hasShareableMvp returns true when mvpEvent exists', () {
      final controller = _controller();
      controller.match.value = _match();
      controller.mvpEvent.value = _mvpEvent();

      expect(controller.hasShareableMvp, isTrue);
    });

    test('hasShareableMvp returns true when Match.mvpPlayerId exists', () {
      final controller = _controller();
      controller.match.value = _match(mvpPlayerId: 'legacy-mvp');
      controller.mvpEvent.value = null;

      expect(controller.hasShareableMvp, isTrue);
    });

    test('hasShareableMvp returns false when no MVP exists', () {
      final controller = _controller();
      controller.match.value = _match();
      controller.mvpEvent.value = null;

      expect(controller.hasShareableMvp, isFalse);
    });

    test('displayNameForParticipantId resolves lineup snapshot entry', () {
      final controller = _controller();
      controller.snapshots.assignAll([
        _snapshot(
          id: 'snapshot-a',
          teamId: 'team-a',
          starters: [_entry(playerId: 'player-1', displayName: 'Ali')],
        ),
      ]);

      expect(controller.displayNameForParticipantId('player-1'), 'Ali');
    });

    test('displayNameForParticipantId resolves match-side player fallback', () {
      final controller = _controller();
      controller.matchSidePlayers.assignAll([
        MatchSidePlayer(
          id: 'msp-1',
          matchId: 'match-1',
          sideKey: 'B',
          sideId: 'match-1_B',
          kind: 'temporary',
          displayName: 'Temporary Hero',
          ratingEligible: false,
          addedBy: 'organizer-1',
          createdAt: DateTime(2026),
        ),
      ]);

      expect(controller.displayNameForParticipantId('msp-1'), 'Temporary Hero');
    });

    test('isGuestParticipantId identifies guest lineup entries safely', () {
      final controller = _controller();
      controller.snapshots.assignAll([
        _snapshot(
          id: 'snapshot-a',
          teamId: 'team-a',
          starters: [
            _entry(guestPlayerId: 'guest-1', displayName: 'Guest MVP'),
            _entry(playerId: 'player-1', displayName: 'Registered MVP'),
          ],
        ),
      ]);

      expect(controller.isGuestParticipantId('guest-1'), isTrue);
      expect(controller.isGuestParticipantId('player-1'), isFalse);
      expect(controller.isGuestParticipantId('unknown'), isFalse);
    });

    test('sideKeyForParticipantId resolves direct snapshot sideKey', () {
      final controller = _controller();
      controller.match.value = _match();
      controller.snapshots.assignAll([
        _snapshot(
          id: 'snapshot-direct',
          guestTeamId: 'guest-team-b',
          sideKey: 'B',
          starters: [_entry(guestPlayerId: 'guest-1')],
        ),
      ]);

      expect(controller.sideKeyForParticipantId('guest-1'), 'B');
    });

    test('sideKeyForParticipantId resolves teamId mapping to A and B', () {
      final controller = _controller();
      controller.match.value = _match(teamAId: 'team-a', teamBId: 'team-b');
      controller.snapshots.assignAll([
        _snapshot(
          id: 'snapshot-team-a',
          teamId: 'team-a',
          starters: [_entry(playerId: 'player-a')],
        ),
        _snapshot(
          id: 'snapshot-team-b',
          teamId: 'team-b',
          starters: [_entry(playerId: 'player-b')],
        ),
      ]);

      expect(controller.sideKeyForParticipantId('player-a'), 'A');
      expect(controller.sideKeyForParticipantId('player-b'), 'B');
    });

    test('sideKeyForParticipantId resolves matchSideId pattern fallback', () {
      final controller = _controller();
      controller.match.value = _match(id: 'match-1');
      controller.snapshots.assignAll([
        _snapshot(
          id: 'snapshot-side-b',
          matchSideId: 'match-1_B',
          starters: [_entry(matchSidePlayerId: 'msp-1')],
        ),
      ]);

      expect(controller.sideKeyForParticipantId('msp-1'), 'B');
    });

    test('unknown participants return safe null or false helpers', () {
      final controller = _controller();
      controller.match.value = _match();

      expect(controller.displayNameForParticipantId('unknown'), isNull);
      expect(controller.isGuestParticipantId('unknown'), isFalse);
      expect(controller.sideKeyForParticipantId('unknown'), isNull);
    });

    test('mvpProfileTarget prefers registered MVP event actor', () {
      final controller = _controller();
      controller.match.value = _match();
      controller.mvpEvent.value = _mvpEvent(
        kind: ParticipantRefKind.player,
        id: 'player-mvp',
      );

      final target = controller.mvpProfileTarget;

      expect(target, isNotNull);
      expect(target!.kind, ParticipantRefKind.player);
      expect(target.id, 'player-mvp');
    });

    test('mvpProfileTarget supports guest MVP event actor', () {
      final controller = _controller();
      controller.match.value = _match();
      controller.mvpEvent.value = _mvpEvent(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-mvp',
      );

      final target = controller.mvpProfileTarget;

      expect(target, isNotNull);
      expect(target!.kind, ParticipantRefKind.guestPlayer);
      expect(target.id, 'guest-mvp');
    });

    test('mvpProfileTarget rejects match-side MVP event actor', () {
      final controller = _controller();
      controller.match.value = _match();
      controller.mvpEvent.value = _mvpEvent(
        kind: ParticipantRefKind.matchSidePlayer,
        id: 'msp-mvp',
      );

      expect(controller.mvpProfileTarget, isNull);
      expect(controller.hasShareableMvp, isTrue);
    });

    test('mvpProfileTarget infers legacy registered MVP from snapshot', () {
      final controller = _controller();
      controller.match.value = _match(mvpPlayerId: 'player-1');
      controller.snapshots.assignAll([
        _snapshot(
          id: 'snapshot-a',
          teamId: 'team-a',
          starters: [_entry(playerId: 'player-1')],
        ),
      ]);

      final target = controller.mvpProfileTarget;

      expect(target, isNotNull);
      expect(target!.kind, ParticipantRefKind.player);
      expect(target.id, 'player-1');
    });

    test('mvpProfileTarget infers legacy guest MVP from snapshot', () {
      final controller = _controller();
      controller.match.value = _match(mvpPlayerId: 'guest-1');
      controller.snapshots.assignAll([
        _snapshot(
          id: 'snapshot-a',
          guestTeamId: 'guest-team-a',
          starters: [_entry(guestPlayerId: 'guest-1')],
        ),
      ]);

      final target = controller.mvpProfileTarget;

      expect(target, isNotNull);
      expect(target!.kind, ParticipantRefKind.guestPlayer);
      expect(target.id, 'guest-1');
    });

    test('mvpProfileTarget does not infer unknown legacy MVP kind', () {
      final controller = _controller();
      controller.match.value = _match(mvpPlayerId: 'legacy-mvp');

      expect(controller.mvpProfileTarget, isNull);
      expect(controller.hasShareableMvp, isTrue);
    });
  });

  group('MatchResultLineupScreen MVP profile CTA', () {
    testWidgets('registered MVP event opens public player profile', (
      tester,
    ) async {
      final controller = _screenController();
      controller.match.value = _match();
      controller.mvpEvent.value = _mvpEvent(
        kind: ParticipantRefKind.player,
        id: 'player-mvp',
        displayName: 'Registered MVP',
      );
      controller.isLoading.value = false;
      Get.put<MatchResultLineupController>(controller);

      await tester.pumpWidget(_buildScreenApp());
      await tester.pumpAndSettle();

      expect(find.text('شارك نجم المباراة'), findsOneWidget);
      expect(find.text('افتح بروفايل النجم'), findsOneWidget);

      await tester.tap(find.text('افتح بروفايل النجم'));
      await tester.pumpAndSettle();

      expect(find.text('profile:player:player-mvp'), findsOneWidget);
    });

    testWidgets('guest MVP event opens public guest profile', (tester) async {
      final controller = _screenController();
      controller.match.value = _match();
      controller.mvpEvent.value = _mvpEvent(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-mvp',
        displayName: 'Guest MVP',
      );
      controller.isLoading.value = false;
      Get.put<MatchResultLineupController>(controller);

      await tester.pumpWidget(_buildScreenApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('افتح بروفايل النجم'));
      await tester.pumpAndSettle();

      expect(find.text('profile:guestPlayer:guest-mvp'), findsOneWidget);
    });

    testWidgets('no MVP hides profile CTA', (tester) async {
      final controller = _screenController();
      controller.match.value = _match();
      controller.isLoading.value = false;
      Get.put<MatchResultLineupController>(controller);

      await tester.pumpWidget(_buildScreenApp());
      await tester.pumpAndSettle();

      expect(find.text('افتح بروفايل النجم'), findsNothing);
      expect(find.text('شارك نجم المباراة'), findsNothing);
    });

    testWidgets('match-side MVP keeps share CTA but hides profile CTA', (
      tester,
    ) async {
      final controller = _screenController();
      controller.match.value = _match();
      controller.mvpEvent.value = _mvpEvent(
        kind: ParticipantRefKind.matchSidePlayer,
        id: 'msp-mvp',
        displayName: 'Temporary MVP',
      );
      controller.isLoading.value = false;
      Get.put<MatchResultLineupController>(controller);

      await tester.pumpWidget(_buildScreenApp());
      await tester.pumpAndSettle();

      expect(find.text('شارك نجم المباراة'), findsOneWidget);
      expect(find.text('افتح بروفايل النجم'), findsNothing);
    });
  });
}

MatchResultLineupController _controller() {
  final firestore = FakeFirebaseFirestore();
  return MatchResultLineupController(
    matchRepository: MatchRepositoryImpl(db: firestore),
    teamRepository: TeamRepositoryImpl(firestore: firestore),
    snapshotRepository: MatchLineupSnapshotRepositoryImpl(firestore: firestore),
    matchSideRepository: MatchSideRepositoryImpl(firestore: firestore),
    matchSidePlayerRepository: MatchSidePlayerRepositoryImpl(
      firestore: firestore,
    ),
    matchEventService: MatchEventService(
      repository: MatchEventRepositoryImpl(firestore: firestore),
      firestore: firestore,
    ),
    tournamentRepository: TournamentRepositoryImpl(db: firestore),
  );
}

_NoopMatchResultLineupController _screenController() {
  final firestore = FakeFirebaseFirestore();
  return _NoopMatchResultLineupController(
    matchRepository: MatchRepositoryImpl(db: firestore),
    teamRepository: TeamRepositoryImpl(firestore: firestore),
    snapshotRepository: MatchLineupSnapshotRepositoryImpl(firestore: firestore),
    matchSideRepository: MatchSideRepositoryImpl(firestore: firestore),
    matchSidePlayerRepository: MatchSidePlayerRepositoryImpl(
      firestore: firestore,
    ),
    matchEventService: MatchEventService(
      repository: MatchEventRepositoryImpl(firestore: firestore),
      firestore: firestore,
    ),
    tournamentRepository: TournamentRepositoryImpl(db: firestore),
  );
}

Widget _buildScreenApp() {
  return GetMaterialApp(
    home: const MatchResultLineupScreen(),
    getPages: [
      GetPage(
        name: AppRoutes.playerProfile,
        page: () => Scaffold(
          body: Text(
            'profile:${Get.parameters['kind']}:${Get.parameters['id']}',
          ),
        ),
      ),
    ],
  );
}

class _NoopMatchResultLineupController extends MatchResultLineupController {
  _NoopMatchResultLineupController({
    required super.matchRepository,
    required super.teamRepository,
    required super.snapshotRepository,
    required super.matchSideRepository,
    required super.matchSidePlayerRepository,
    required super.matchEventService,
    required super.tournamentRepository,
  });

  @override
  void onInit() {}
}

Match _match({
  String id = 'match-1',
  String? teamAId = 'team-a',
  String? teamBId = 'team-b',
  String? mvpPlayerId,
}) {
  return Match(
    id: id,
    organizerId: 'organizer-1',
    teamAId: teamAId,
    teamBId: teamBId,
    status: MatchStatus.completed,
    scoreTeamA: 2,
    scoreTeamB: 1,
    mvpPlayerId: mvpPlayerId,
    createdAt: DateTime(2026),
  );
}

MatchEvent _mvpEvent({
  ParticipantRefKind kind = ParticipantRefKind.player,
  String id = 'player-1',
  String displayName = 'Ali',
}) {
  return MatchEvent(
    id: 'mvp-match-1',
    matchId: 'match-1',
    eventType: MatchEventType.mvp,
    sideKey: 'A',
    actor: ParticipantRef(kind: kind, id: id, displayName: displayName),
    createdBy: 'organizer-1',
    createdAt: DateTime(2026),
  );
}

MatchLineupSnapshot _snapshot({
  required String id,
  String matchId = 'match-1',
  String? teamId,
  String? guestTeamId,
  String? matchSideId,
  String? sideKey,
  required List<MatchLineupEntry> starters,
}) {
  return MatchLineupSnapshot(
    id: id,
    matchId: matchId,
    teamId: teamId,
    guestTeamId: guestTeamId,
    matchSideId: matchSideId,
    sideKey: sideKey,
    starters: starters,
    lockedBy: 'organizer-1',
    lockedAt: DateTime(2026),
  );
}

MatchLineupEntry _entry({
  String? playerId,
  String? guestPlayerId,
  String? matchSidePlayerId,
  String displayName = 'Participant',
}) {
  return MatchLineupEntry(
    attendanceId:
        'attendance-${playerId ?? guestPlayerId ?? matchSidePlayerId}',
    playerId: playerId,
    guestPlayerId: guestPlayerId,
    matchSidePlayerId: matchSidePlayerId,
    role: TeamMembershipRole.player,
    availability: TeamMemberAvailability.available,
    attendanceStatus: MatchAttendanceStatus.present,
    displayName: displayName,
  );
}
