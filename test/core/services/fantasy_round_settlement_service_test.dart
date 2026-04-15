import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/fantasy_league_phase.dart';
import 'package:el7reef/core/services/fantasy_lifecycle_service.dart';
import 'package:el7reef/core/services/fantasy_round_settlement_service.dart';
import 'package:el7reef/data/repositories/fantasy_lifecycle_repository_impl.dart';
import 'package:el7reef/data/repositories/fantasy_round_settlement_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/fantasy_chip.dart';
import 'package:el7reef/domain/entities/fantasy_league_lifecycle.dart';
import 'package:el7reef/domain/entities/fantasy_round_settlement_marker.dart';
import 'package:el7reef/domain/entities/fantasy_slot.dart';
import 'package:el7reef/domain/entities/fantasy_team.dart';

void main() {
  group('FantasyRoundSettlementService', () {
    late FakeFirebaseFirestore firestore;
    late FantasyLifecycleService lifecycleService;
    late FantasyRoundSettlementService settlementService;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      lifecycleService = FantasyLifecycleService(
        lifecycleRepository: FantasyLifecycleRepositoryImpl(db: firestore),
        tournamentRepository: TournamentRepositoryImpl(db: firestore),
      );
      settlementService = FantasyRoundSettlementService(
        firestore: firestore,
        lifecycleService: lifecycleService,
        markerRepository: FantasyRoundSettlementRepositoryImpl(db: firestore),
      );
    });

    test('settles a global round once and updates teams, slots, lifecycle, and marker',
        () async {
      final openedAt = DateTime(2026, 4, 15, 12);
      final completedAt = DateTime(2026, 4, 15, 14);

      await _seedLifecycle(
        firestore,
        FantasyLeagueLifecycle(
          leagueId: 'global',
          currentGameweek: 2,
          phase: FantasyLeaguePhase.live,
          isGlobal: true,
          openedAt: openedAt,
          updatedAt: openedAt,
        ),
      );
      await _seedTeam(
        firestore,
        FantasyTeam(
          id: 'team-1',
          ownerPlayerId: 'owner-1',
          teamName: 'Alpha',
          totalPoints: 12,
          chipUsages: [
            ChipUsage(
              chipType: ChipType.tripleCaptain,
              gameweek: 2,
              activatedAt: openedAt,
            ),
          ],
          createdAt: openedAt,
          updatedAt: openedAt,
        ),
      );
      await _seedSlot(
        firestore,
        const FantasySlot(
          id: 'slot-a',
          fantasyTeamId: 'team-1',
          playerId: 'player-a',
          isStartingXI: true,
          role: FantasyPlayerRole.captain,
        ),
      );
      await _seedSlot(
        firestore,
        const FantasySlot(
          id: 'slot-b',
          fantasyTeamId: 'team-1',
          playerId: 'player-b',
          isStartingXI: true,
        ),
      );
      await _seedSlot(
        firestore,
        const FantasySlot(
          id: 'slot-c',
          fantasyTeamId: 'team-1',
          playerId: 'player-c',
          isStartingXI: false,
          benchPriority: 1,
        ),
      );
      await _seedSettledMatch(
        firestore,
        matchId: 'm1',
        completedAt: completedAt,
        mvpPlayerId: 'player-a',
      );
      await _seedMatchStat(
        firestore,
        matchId: 'm1',
        playerId: 'player-a',
        position: 'midfielder',
        goals: 1,
      );
      await _seedMatchStat(
        firestore,
        matchId: 'm1',
        playerId: 'player-b',
        position: 'forward',
        assists: 1,
      );
      await _seedMatchStat(
        firestore,
        matchId: 'm1',
        playerId: 'player-c',
        position: 'forward',
        goals: 1,
      );
      await firestore
          .collection(FirebasePaths.fanVotingSessions)
          .doc('m1')
          .set({
        'winnerPlayerId': 'player-a',
      });

      final result = await settlementService.settleRound(
        leagueId: 'global',
        settledAt: DateTime(2026, 4, 15, 16),
      );

      expect(result.alreadySettled, isFalse);
      expect(result.processedMatchCount, 1);
      expect(result.processedTeamCount, 1);
      expect(result.processedSlotCount, 3);
      expect(result.totalPointsApplied, 161);

      final teamDoc = await firestore
          .collection(FirebasePaths.fantasyTeams)
          .doc('team-1')
          .get();
      expect(teamDoc.data()?['currentGameweekPoints'], 161);
      expect(teamDoc.data()?['totalPoints'], 173);

      final slotA = await firestore
          .collection(FirebasePaths.fantasySlots)
          .doc('slot-a')
          .get();
      final slotB = await firestore
          .collection(FirebasePaths.fantasySlots)
          .doc('slot-b')
          .get();
      final slotC = await firestore
          .collection(FirebasePaths.fantasySlots)
          .doc('slot-c')
          .get();
      expect(slotA.data()?['pointsEarned'], 156);
      expect(slotB.data()?['pointsEarned'], 5);
      expect(slotC.data()?['pointsEarned'], 0);

      final markerDoc = await firestore
          .collection(FirebasePaths.fantasyRoundSettlements)
          .doc(
            FantasyRoundSettlementMarker.buildId(
              leagueId: 'global',
              gameweek: 2,
              settlementType: 'round_points',
            ),
          )
          .get();
      expect(markerDoc.exists, isTrue);
      expect(markerDoc.data()?['processedMatchCount'], 1);

      final lifecycleDoc = await firestore
          .collection(FirebasePaths.fantasyLeagues)
          .doc('global')
          .get();
      expect(lifecycleDoc.data()?['phase'], FantasyLeaguePhase.settled.name);
      expect(lifecycleDoc.data()?['settledAt'], isNotNull);

      final rerun = await settlementService.settleRound(
        leagueId: 'global',
        settledAt: DateTime(2026, 4, 15, 18),
      );
      expect(rerun.alreadySettled, isTrue);

      final teamAfterRerun = await firestore
          .collection(FirebasePaths.fantasyTeams)
          .doc('team-1')
          .get();
      expect(teamAfterRerun.data()?['totalPoints'], 173);
    });

    test('filters settled matches to the target tournament league only', () async {
      final openedAt = DateTime(2026, 5, 1, 12);

      await _seedLifecycle(
        firestore,
        FantasyLeagueLifecycle(
          leagueId: 'tournament-1',
          currentGameweek: 4,
          phase: FantasyLeaguePhase.live,
          isGlobal: false,
          openedAt: openedAt,
          updatedAt: openedAt,
        ),
      );
      await _seedTeam(
        firestore,
        FantasyTeam(
          id: 'team-1',
          ownerPlayerId: 'owner-1',
          teamName: 'Alpha',
          leagueIds: const ['global', 'tournament-1'],
          createdAt: openedAt,
          updatedAt: openedAt,
        ),
      );
      await _seedSlot(
        firestore,
        const FantasySlot(
          id: 'slot-a',
          fantasyTeamId: 'team-1',
          playerId: 'player-a',
          isStartingXI: true,
        ),
      );

      await _seedSettledMatch(
        firestore,
        matchId: 'm-good',
        completedAt: DateTime(2026, 5, 1, 14),
        playerIds: const ['player-a'],
        tournamentId: 'tournament-1',
      );
      await _seedMatchStat(
        firestore,
        matchId: 'm-good',
        playerId: 'player-a',
        position: 'forward',
        goals: 1,
      );

      await _seedSettledMatch(
        firestore,
        matchId: 'm-ignore',
        completedAt: DateTime(2026, 5, 1, 15),
        playerIds: const ['player-a'],
        tournamentId: 'tournament-2',
      );
      await _seedMatchStat(
        firestore,
        matchId: 'm-ignore',
        playerId: 'player-a',
        position: 'forward',
        goals: 2,
      );

      final result = await settlementService.settleRound(
        leagueId: 'tournament-1',
        settledAt: DateTime(2026, 5, 1, 18),
      );

      expect(result.processedMatchCount, 1);

      final teamDoc = await firestore
          .collection(FirebasePaths.fantasyTeams)
          .doc('team-1')
          .get();
      expect(teamDoc.data()?['currentGameweekPoints'], 6);
      expect(teamDoc.data()?['totalPoints'], 6);
    });

    test(
        'applies vice-captain fallback and promotes the first playable bench slot',
        () async {
      final openedAt = DateTime(2026, 6, 1, 12);
      final completedAt = DateTime(2026, 6, 1, 14);

      await _seedLifecycle(
        firestore,
        FantasyLeagueLifecycle(
          leagueId: 'global',
          currentGameweek: 3,
          phase: FantasyLeaguePhase.live,
          isGlobal: true,
          openedAt: openedAt,
          updatedAt: openedAt,
        ),
      );
      await _seedTeam(
        firestore,
        FantasyTeam(
          id: 'team-2',
          ownerPlayerId: 'owner-2',
          teamName: 'Beta',
          createdAt: openedAt,
          updatedAt: openedAt,
        ),
      );
      await _seedSlot(
        firestore,
        const FantasySlot(
          id: 'slot-cap',
          fantasyTeamId: 'team-2',
          playerId: 'captain-missing',
          isStartingXI: true,
          role: FantasyPlayerRole.captain,
        ),
      );
      await _seedSlot(
        firestore,
        const FantasySlot(
          id: 'slot-vice',
          fantasyTeamId: 'team-2',
          playerId: 'vice-player',
          isStartingXI: true,
          role: FantasyPlayerRole.viceCaptain,
        ),
      );
      await _seedSlot(
        firestore,
        const FantasySlot(
          id: 'slot-missing',
          fantasyTeamId: 'team-2',
          playerId: 'starter-missing',
          isStartingXI: true,
        ),
      );
      await _seedSlot(
        firestore,
        const FantasySlot(
          id: 'slot-bench',
          fantasyTeamId: 'team-2',
          playerId: 'bench-hero',
          isStartingXI: false,
          benchPriority: 1,
        ),
      );

      await _seedSettledMatch(
        firestore,
        matchId: 'm-vice',
        completedAt: completedAt,
        playerIds: const [
          'vice-player',
          'bench-hero',
        ],
      );
      await _seedMatchStat(
        firestore,
        matchId: 'm-vice',
        playerId: 'vice-player',
        position: 'forward',
        goals: 1,
      );
      await _seedMatchStat(
        firestore,
        matchId: 'm-vice',
        playerId: 'bench-hero',
        position: 'forward',
        goals: 1,
      );

      final result = await settlementService.settleRound(
        leagueId: 'global',
        settlementType: 'vice_autosub_case',
        settledAt: DateTime(2026, 6, 1, 18),
      );

      expect(result.alreadySettled, isFalse);
      expect(result.totalPointsApplied, 18);

      final teamDoc = await firestore
          .collection(FirebasePaths.fantasyTeams)
          .doc('team-2')
          .get();
      expect(teamDoc.data()?['currentGameweekPoints'], 18);
      expect(teamDoc.data()?['totalPoints'], 18);

      final captainSlot = await firestore
          .collection(FirebasePaths.fantasySlots)
          .doc('slot-cap')
          .get();
      final viceSlot = await firestore
          .collection(FirebasePaths.fantasySlots)
          .doc('slot-vice')
          .get();
      final missingSlot = await firestore
          .collection(FirebasePaths.fantasySlots)
          .doc('slot-missing')
          .get();
      final benchSlot = await firestore
          .collection(FirebasePaths.fantasySlots)
          .doc('slot-bench')
          .get();

      expect(captainSlot.data()?['pointsEarned'], 0);
      expect(viceSlot.data()?['pointsEarned'], 12);
      expect(missingSlot.data()?['pointsEarned'], 0);
      expect(benchSlot.data()?['pointsEarned'], 6);
      expect(captainSlot.data()?['isStartingXI'], isFalse);
      expect(missingSlot.data()?['isStartingXI'], isTrue);
      expect(benchSlot.data()?['isStartingXI'], isTrue);
    });

    test('bench boost keeps bench players counted without auto-subbing them',
        () async {
      final openedAt = DateTime(2026, 7, 1, 12);
      final completedAt = DateTime(2026, 7, 1, 14);

      await _seedLifecycle(
        firestore,
        FantasyLeagueLifecycle(
          leagueId: 'global',
          currentGameweek: 4,
          phase: FantasyLeaguePhase.live,
          isGlobal: true,
          openedAt: openedAt,
          updatedAt: openedAt,
        ),
      );
      await _seedTeam(
        firestore,
        FantasyTeam(
          id: 'team-3',
          ownerPlayerId: 'owner-3',
          teamName: 'Gamma',
          chipUsages: [
            ChipUsage(
              chipType: ChipType.benchBoost,
              gameweek: 4,
              activatedAt: openedAt,
            ),
          ],
          createdAt: openedAt,
          updatedAt: openedAt,
        ),
      );
      await _seedSlot(
        firestore,
        const FantasySlot(
          id: 'slot-start',
          fantasyTeamId: 'team-3',
          playerId: 'starter-player',
          isStartingXI: true,
        ),
      );
      await _seedSlot(
        firestore,
        const FantasySlot(
          id: 'slot-bench',
          fantasyTeamId: 'team-3',
          playerId: 'bench-scorer',
          isStartingXI: false,
          benchPriority: 1,
        ),
      );

      await _seedSettledMatch(
        firestore,
        matchId: 'm-bench',
        completedAt: completedAt,
        playerIds: const [
          'starter-player',
          'bench-scorer',
        ],
      );
      await _seedMatchStat(
        firestore,
        matchId: 'm-bench',
        playerId: 'starter-player',
        position: 'forward',
      );
      await _seedMatchStat(
        firestore,
        matchId: 'm-bench',
        playerId: 'bench-scorer',
        position: 'forward',
        goals: 1,
      );

      final result = await settlementService.settleRound(
        leagueId: 'global',
        settlementType: 'bench_boost_case',
        settledAt: DateTime(2026, 7, 1, 18),
      );

      expect(result.totalPointsApplied, 8);

      final benchSlot = await firestore
          .collection(FirebasePaths.fantasySlots)
          .doc('slot-bench')
          .get();
      expect(benchSlot.data()?['isStartingXI'], isFalse);
      expect(benchSlot.data()?['pointsEarned'], 6);
    });
  });
}

Future<void> _seedLifecycle(
  FakeFirebaseFirestore firestore,
  FantasyLeagueLifecycle lifecycle,
) async {
  await firestore.collection(FirebasePaths.fantasyLeagues).doc(lifecycle.leagueId).set({
    'currentGameweek': lifecycle.currentGameweek,
    'phase': lifecycle.phase.name,
    'isLocked': lifecycle.isLocked,
    'isGlobal': lifecycle.isGlobal,
    'openedAt': lifecycle.openedAt?.millisecondsSinceEpoch,
    'updatedAt': lifecycle.updatedAt.millisecondsSinceEpoch,
  });
}

Future<void> _seedTeam(
  FakeFirebaseFirestore firestore,
  FantasyTeam team,
) async {
  await firestore.collection(FirebasePaths.fantasyTeams).doc(team.id).set({
    'ownerPlayerId': team.ownerPlayerId,
    'teamName': team.teamName,
    'leagueIds': team.leagueIds,
    'budget': team.budget,
    'totalPoints': team.totalPoints,
    'currentGameweekPoints': team.currentGameweekPoints,
    'freeTransfers': team.freeTransfers,
    'freeTransfersGameweek': team.freeTransfersGameweek,
    'totalTransfers': team.totalTransfers,
    'formation': team.formation,
    'chipUsages': team.chipUsages
        .map((usage) => usage.toJson())
        .toList(growable: false),
    'createdAt': team.createdAt.millisecondsSinceEpoch,
    'updatedAt': team.updatedAt.millisecondsSinceEpoch,
  });
}

Future<void> _seedSlot(
  FakeFirebaseFirestore firestore,
  FantasySlot slot,
) async {
  await firestore.collection(FirebasePaths.fantasySlots).doc(slot.id).set({
    'fantasyTeamId': slot.fantasyTeamId,
    'playerId': slot.playerId,
    'isStartingXI': slot.isStartingXI,
    'benchPriority': slot.benchPriority,
    'isEliminated': slot.isEliminated,
    'role': slot.role.name,
    'pointsEarned': slot.pointsEarned,
  });
}

Future<void> _seedSettledMatch(
  FakeFirebaseFirestore firestore, {
  required String matchId,
  required DateTime completedAt,
  String? mvpPlayerId,
  List<String> playerIds = const ['player-a', 'player-b', 'player-c'],
  String? tournamentId,
}) async {
  await firestore.collection(FirebasePaths.matches).doc(matchId).set({
    'organizerId': 'org-1',
    'teamAPlayerIds': playerIds,
    'teamBPlayerIds': const ['other-player'],
    'status': 'settled',
    'mvpPlayerId': mvpPlayerId,
    'tournamentId': tournamentId,
    'createdAt': completedAt
        .subtract(const Duration(hours: 1))
        .millisecondsSinceEpoch,
    'completedAt': completedAt.millisecondsSinceEpoch,
  });
}

Future<void> _seedMatchStat(
  FakeFirebaseFirestore firestore, {
  required String matchId,
  required String playerId,
  required String position,
  int goals = 0,
  int assists = 0,
}) async {
  await firestore
      .collection(FirebasePaths.matches)
      .doc(matchId)
      .collection('player_stats')
      .doc(playerId)
      .set({
    'playerId': playerId,
    'matchId': matchId,
    'teamId': 'team-a',
    'played': true,
    'position': position,
    'goals': goals,
    'assists': assists,
    'saves': 0,
    'tackles': 0,
    'cleanSheet': false,
    'yellowCard': false,
    'redCard': false,
    'rating': 7.0,
  });
}
