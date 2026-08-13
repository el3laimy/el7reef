import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/core/auth/auth_session.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/team_membership_status.dart';
import 'package:el7reef/core/lineup/formation_engine.dart';
import 'package:el7reef/core/lineup/formation_library.dart';
import 'package:el7reef/core/lineup/lineup_types.dart';
import 'package:el7reef/core/lineup/lineup_utils.dart';
import 'package:el7reef/core/services/matchday_service.dart';
import 'package:el7reef/core/services/team_roster_service.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/match_lineup_snapshot_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/match_side_player_repository_impl.dart';
import 'package:el7reef/data/repositories/match_side_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_membership_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_side.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team_membership.dart';
import 'package:el7reef/features/lineup/controllers/match_side_lineup_editor_controller.dart';
import 'package:el7reef/features/lineup/controllers/team_lineup_editor_controller.dart';

void main() {
  group('TeamLineupEditorController tap-select lineup editing', () {
    test(
      'tracks selected player name and replaces starter with bench player',
      () {
        final controller = _teamLineupController();
        final starter = _registeredPlayer(id: 'p1', name: 'أحمد سالم');
        final bench = _guestPlayer(id: 'g1', name: 'محمود علي');
        final initialSlots = _slotsWithStarters([starter]);

        controller.match.value = _match();
        controller.playerCount.value = 5;
        controller.formationCode.value = getDefaultFormation(5);
        controller.members.assignAll([
          _teamMember(player: starter, status: TeamMembershipStatus.starter),
          _teamMember(player: bench, status: TeamMembershipStatus.bench),
        ]);
        controller.slots.assignAll(initialSlots);

        controller.selectLineupPlayer(bench);

        expect(controller.selectedLineupPlayerKey, bench.key);
        expect(controller.selectedLineupPlayerName, 'محمود علي');

        final starterSlot = controller.slots.firstWhere(
          (slot) => !slot.isEmpty,
        );
        final moved = controller.moveSelectedLineupPlayerToSlot(starterSlot);

        expect(moved, isTrue);
        expect(
          controller.slots
              .firstWhere((slot) => slot.id == starterSlot.id)
              .occupantKey,
          bench.key,
        );
        expect(
          controller.benchPlayers.map((player) => player.key),
          contains(starter.key),
        );
        expect(controller.selectedLineupPlayerKey, isNull);
        expect(controller.isLineupDirty.value, isTrue);
      },
    );

    test('moves selected starter back to bench', () {
      final controller = _teamLineupController();
      final starter = _registeredPlayer(id: 'p1', name: 'أحمد سالم');

      controller.match.value = _match();
      controller.playerCount.value = 5;
      controller.formationCode.value = getDefaultFormation(5);
      controller.members.assignAll([
        _teamMember(player: starter, status: TeamMembershipStatus.starter),
      ]);
      controller.slots.assignAll(_slotsWithStarters([starter]));

      final starterSlot = controller.slots.firstWhere((slot) => !slot.isEmpty);
      controller.selectLineupPlayer(starter, sourceSlotId: starterSlot.id);

      expect(controller.selectedLineupPlayerCanMoveToBench, isTrue);
      expect(controller.selectedLineupPlayerName, 'أحمد سالم');

      final moved = controller.moveSelectedLineupPlayerToBench();

      expect(moved, isTrue);
      expect(
        controller.slots
            .firstWhere((slot) => slot.id == starterSlot.id)
            .occupantKey,
        isNull,
      );
      expect(
        controller.benchPlayers.map((player) => player.key),
        contains(starter.key),
      );
      expect(controller.selectedLineupPlayerKey, isNull);
      expect(controller.isLineupDirty.value, isTrue);
    });

    test(
      'keeps a legacy duplicate registered membership out of the bench before save for 5v5, 7v7, and 11v11',
      () {
        for (final playerCount in [5, 7, 11]) {
          final controller = _teamLineupController();
          final starter = _registeredPlayer(
            id: 'membership-starter-$playerCount',
            name: 'محمد السيد',
          );
          final duplicate = _registeredPlayer(
            id: 'membership-legacy-copy-$playerCount',
            name: 'محمد السيد',
          );
          final bench = _registeredPlayer(
            id: 'membership-bench-$playerCount',
            name: 'رامي',
          );

          controller.members.assignAll([
            _teamMember(
              player: starter,
              status: TeamMembershipStatus.starter,
              participantId: 'player-mohamed',
            ),
            _teamMember(
              player: duplicate,
              status: TeamMembershipStatus.bench,
              participantId: 'player-mohamed',
            ),
            _teamMember(
              player: bench,
              status: TeamMembershipStatus.bench,
              participantId: 'player-ramy',
            ),
          ]);
          controller.slots.assignAll(
            _slotsWithStarters([starter], playerCount: playerCount),
          );

          expect(
            controller.benchPlayers.map((player) => player.key),
            equals([bench.key]),
            reason: '${playerCount}v$playerCount',
          );
          expect(
            controller.benchMembershipIds,
            equals([bench.id]),
            reason: '${playerCount}v$playerCount',
          );
        }
      },
    );

    test(
      'normalizes legacy duplicate guest members when the formation changes for 5v5, 7v7, and 11v11',
      () {
        for (final playerCount in [5, 7, 11]) {
          final controller = _teamLineupController();
          final firstGuest = _guestPlayer(
            id: 'membership-guest-starter-$playerCount',
            name: 'محمود الضيف',
          );
          final duplicateGuest = _guestPlayer(
            id: 'membership-guest-copy-$playerCount',
            name: 'محمود الضيف',
          );
          final bench = _guestPlayer(
            id: 'membership-guest-bench-$playerCount',
            name: 'علي',
          );

          controller.match.value = _match(teamSize: playerCount);
          controller.playerCount.value = playerCount;
          controller.formationCode.value = getDefaultFormation(playerCount);
          controller.members.assignAll([
            _teamMember(
              player: firstGuest,
              status: TeamMembershipStatus.starter,
              participantId: 'guest-mahmoud',
            ),
            _teamMember(
              player: duplicateGuest,
              status: TeamMembershipStatus.starter,
              participantId: 'guest-mahmoud',
            ),
            _teamMember(
              player: bench,
              status: TeamMembershipStatus.bench,
              participantId: 'guest-ali',
            ),
          ]);
          controller.slots.assignAll(
            _slotsWithStarters([
              firstGuest,
              duplicateGuest,
            ], playerCount: playerCount),
          );

          controller.changeFormation(getDefaultFormation(playerCount));

          expect(
            controller.slots.where((slot) => !slot.isEmpty),
            hasLength(1),
            reason: '${playerCount}v$playerCount',
          );
          expect(
            controller.starterMembershipIds,
            hasLength(1),
            reason: '${playerCount}v$playerCount',
          );
          expect(
            controller.benchPlayers.map((player) => player.key),
            equals([bench.key]),
            reason: '${playerCount}v$playerCount',
          );
        }
      },
    );
  });

  group('MatchSideLineupEditorController tap-select lineup editing', () {
    test('tracks selected temporary player name and replaces starter', () {
      final controller = _matchSideLineupController();
      final starter = _sidePlayer(id: 's1', name: 'مهند لاشين');
      final bench = _sidePlayer(id: 's2', name: 'رامي ربيعة');

      controller.match.value = _match();
      controller.matchSide.value = _temporarySide();
      controller.playerCount.value = 5;
      controller.formationCode.value = getDefaultFormation(5);
      controller.roster.assignAll([starter, bench]);
      controller.slots.assignAll(_slotsWithStarters([starter]));

      controller.selectLineupPlayer(bench);

      expect(controller.selectedLineupPlayerKey, bench.key);
      expect(controller.selectedLineupPlayerName, 'رامي ربيعة');

      final starterSlot = controller.slots.firstWhere((slot) => !slot.isEmpty);
      final moved = controller.moveSelectedLineupPlayerToSlot(starterSlot);

      expect(moved, isTrue);
      expect(
        controller.slots
            .firstWhere((slot) => slot.id == starterSlot.id)
            .occupantKey,
        bench.key,
      );
      expect(
        controller.benchPlayers.map((player) => player.key),
        contains(starter.key),
      );
      expect(controller.selectedLineupPlayerKey, isNull);
      expect(controller.isLineupDirty.value, isTrue);
    });

    test('moves selected temporary starter back to bench', () {
      final controller = _matchSideLineupController();
      final starter = _sidePlayer(id: 's1', name: 'مهند لاشين');

      controller.match.value = _match();
      controller.matchSide.value = _temporarySide();
      controller.playerCount.value = 5;
      controller.formationCode.value = getDefaultFormation(5);
      controller.roster.assignAll([starter]);
      controller.slots.assignAll(_slotsWithStarters([starter]));

      final starterSlot = controller.slots.firstWhere((slot) => !slot.isEmpty);
      controller.selectLineupPlayer(starter, sourceSlotId: starterSlot.id);

      expect(controller.selectedLineupPlayerCanMoveToBench, isTrue);
      expect(controller.selectedLineupPlayerName, 'مهند لاشين');

      final moved = controller.moveSelectedLineupPlayerToBench();

      expect(moved, isTrue);
      expect(
        controller.slots
            .firstWhere((slot) => slot.id == starterSlot.id)
            .occupantKey,
        isNull,
      );
      expect(
        controller.benchPlayers.map((player) => player.key),
        contains(starter.key),
      );
      expect(controller.selectedLineupPlayerKey, isNull);
      expect(controller.isLineupDirty.value, isTrue);
    });
  });
}

TeamLineupEditorController _teamLineupController() {
  final firestore = FakeFirebaseFirestore();
  final teamRepository = TeamRepositoryImpl(firestore: firestore);
  final membershipRepository = TeamMembershipRepositoryImpl(
    firestore: firestore,
  );
  final guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
  return TeamLineupEditorController(
    authSession: const _FakeAuthSession(),
    matchRepository: MatchRepositoryImpl(firestore: firestore),
    teamRepository: teamRepository,
    tournamentRepository: TournamentRepositoryImpl(firestore: firestore),
    membershipRepository: membershipRepository,
    playerRepository: PlayerRepositoryImpl(firestore: firestore),
    guestPlayerRepository: guestPlayerRepository,
    snapshotRepository: MatchLineupSnapshotRepositoryImpl(firestore: firestore),
    matchdayService: MatchdayService(firestore: firestore),
    teamRosterService: TeamRosterService(
      teamRepository: teamRepository,
      membershipRepository: membershipRepository,
      guestPlayerRepository: guestPlayerRepository,
    ),
  );
}

MatchSideLineupEditorController _matchSideLineupController() {
  final firestore = FakeFirebaseFirestore();
  return MatchSideLineupEditorController(
    authSession: const _FakeAuthSession(),
    matchRepository: MatchRepositoryImpl(firestore: firestore),
    matchSideRepository: MatchSideRepositoryImpl(firestore: firestore),
    matchSidePlayerRepository: MatchSidePlayerRepositoryImpl(
      firestore: firestore,
    ),
    snapshotRepository: MatchLineupSnapshotRepositoryImpl(firestore: firestore),
    matchdayService: MatchdayService(firestore: firestore),
  );
}

Match _match({int teamSize = 5}) {
  return Match(
    id: 'match-1',
    organizerId: 'owner-1',
    status: MatchStatus.open,
    teamSize: teamSize,
    createdAt: DateTime(2026, 7, 10, 12),
  );
}

MatchSide _temporarySide() {
  final now = DateTime(2026, 7, 10, 12);
  return MatchSide(
    id: 'side-a',
    matchId: 'match-1',
    sideKey: 'A',
    type: 'temporary',
    displayName: 'نجوم الشارع',
    createdBy: 'owner-1',
    createdAt: now,
    updatedAt: now,
  );
}

TeamLineupEditorMember _teamMember({
  required LineupPlayer player,
  required TeamMembershipStatus status,
  String? participantId,
}) {
  final now = DateTime(2026, 7, 10, 12);
  return TeamLineupEditorMember(
    membership: TeamMembership(
      id: player.id,
      teamId: 'team-1',
      playerId: player.isRegistered ? (participantId ?? player.id) : null,
      guestPlayerId: player.isGuest ? (participantId ?? player.id) : null,
      status: status,
      joinedAt: now,
      updatedAt: now,
    ),
    player: player,
  );
}

List<FormationSlot> _slotsWithStarters(
  List<LineupPlayer> starters, {
  int playerCount = 5,
}) {
  final slots = FormationEngine.generateFormationSlots(
    playerCount: playerCount,
    formationCode: getDefaultFormation(playerCount),
  );
  return LineupUtils.assignPlayersToGeneratedSlots(
    slots: slots,
    starters: starters,
  ).slots;
}

LineupPlayer _registeredPlayer({required String id, required String name}) {
  return LineupPlayer(
    id: id,
    name: name,
    preferredPosition: 'MID',
    isRegistered: true,
  );
}

LineupPlayer _guestPlayer({required String id, required String name}) {
  return LineupPlayer(
    id: id,
    name: name,
    preferredPosition: 'ATT',
    isRegistered: false,
  );
}

LineupPlayer _sidePlayer({required String id, required String name}) {
  return LineupPlayer(
    id: id,
    name: name,
    preferredPosition: 'DEF',
    isRegistered: false,
    isTemporary: true,
  );
}

class _FakeAuthSession implements AuthSession {
  const _FakeAuthSession();

  @override
  String? get currentUserId => 'owner-1';

  @override
  Player? get currentPlayer => Player(
    id: 'owner-1',
    name: 'Owner One',
    createdAt: DateTime(2026, 7, 10, 12),
    lastActiveAt: DateTime(2026, 7, 10, 12),
  );
}
