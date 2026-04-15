import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/fantasy_league_phase.dart';
import 'package:el7reef/domain/entities/fantasy_chip.dart';
import 'package:el7reef/core/services/fantasy_transfer_policy_service.dart';
import 'package:el7reef/domain/entities/fantasy_league_lifecycle.dart';
import 'package:el7reef/domain/entities/fantasy_team.dart';

void main() {
  group('FantasyTransferPolicyService', () {
    const service = FantasyTransferPolicyService();

    test('migrates legacy teams without granting unexpected catch-up refills', () {
      final result = service.syncTeamForLifecycle(
        team: _buildTeam(freeTransfers: 1, freeTransfersGameweek: 0),
        lifecycle: _buildLifecycle(gameweek: 4),
        now: DateTime(2026, 4, 15, 12),
      );

      expect(result.changed, isTrue);
      expect(result.migratedLegacyTracking, isTrue);
      expect(result.roundsAdvanced, 0);
      expect(result.team.freeTransfers, 1);
      expect(result.team.freeTransfersGameweek, 4);
    });

    test('adds one free transfer on round advance and carries to a cap of 2', () {
      final result = service.syncTeamForLifecycle(
        team: _buildTeam(freeTransfers: 1, freeTransfersGameweek: 2),
        lifecycle: _buildLifecycle(gameweek: 3),
      );

      expect(result.changed, isTrue);
      expect(result.team.freeTransfers, 2);
      expect(result.team.freeTransfersGameweek, 3);
    });

    test('caps carried free transfers at 2 across multiple rounds', () {
      final result = service.syncTeamForLifecycle(
        team: _buildTeam(freeTransfers: 1, freeTransfersGameweek: 1),
        lifecycle: _buildLifecycle(gameweek: 4),
      );

      expect(result.team.freeTransfers, 2);
      expect(result.team.freeTransfersGameweek, 4);
    });

    test('does not reapply refill inside the same gameweek', () {
      final result = service.syncTeamForLifecycle(
        team: _buildTeam(freeTransfers: 2, freeTransfersGameweek: 4),
        lifecycle: _buildLifecycle(gameweek: 4),
      );

      expect(result.changed, isFalse);
      expect(result.team.freeTransfers, 2);
    });

    test('preserves exceptional balances above the carry cap', () {
      final result = service.syncTeamForLifecycle(
        team: _buildTeam(freeTransfers: 4, freeTransfersGameweek: 2),
        lifecycle: _buildLifecycle(gameweek: 3),
      );

      expect(result.team.freeTransfers, 4);
      expect(result.team.freeTransfersGameweek, 3);
    });

    test('blocks transfers during a live round', () {
      final decision = service.evaluateTransfer(
        team: _buildTeam(freeTransfers: 1, freeTransfersGameweek: 3),
        lifecycle: _buildLifecycle(
          gameweek: 3,
          phase: FantasyLeaguePhase.live,
        ),
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.policyPhase, 'global_live');
      expect(decision.blockedReason, contains('أثناء لعب الجولة'));
    });

    test('supports different allowed phases for global and tournament leagues', () {
      const customService = FantasyTransferPolicyService(
        globalAllowedTransferPhases: {
          FantasyLeaguePhase.draft,
          FantasyLeaguePhase.transferWindow,
        },
        tournamentAllowedTransferPhases: {
          FantasyLeaguePhase.transferWindow,
        },
      );

      final globalDecision = customService.evaluateTransfer(
        team: _buildTeam(freeTransfers: 1, freeTransfersGameweek: 1),
        lifecycle: _buildLifecycle(
          gameweek: 1,
          phase: FantasyLeaguePhase.draft,
        ),
      );
      final tournamentDecision = customService.evaluateTransfer(
        team: _buildTeam(freeTransfers: 1, freeTransfersGameweek: 1),
        lifecycle: _buildLifecycle(
          gameweek: 1,
          phase: FantasyLeaguePhase.draft,
          isGlobal: false,
          leagueId: 'tournament-1',
        ),
      );

      expect(globalDecision.isAllowed, isTrue);
      expect(tournamentDecision.isAllowed, isFalse);
      expect(tournamentDecision.policyPhase, 'tournament_draft');
    });

    test('returns audit metadata for free transfer, wildcard, and hit cases', () {
      final freeTransferDecision = service.evaluateTransfer(
        team: _buildTeam(freeTransfers: 1, freeTransfersGameweek: 3),
        lifecycle: _buildLifecycle(gameweek: 3),
      );
      final wildcardDecision = service.evaluateTransfer(
        team: _buildTeam(
          freeTransfers: 0,
          freeTransfersGameweek: 3,
          chipUsages: [
            ChipUsage(
              chipType: ChipType.wildcardGroups,
              gameweek: 3,
              activatedAt: DateTime(2026, 4, 10, 12),
            ),
          ],
        ),
        lifecycle: _buildLifecycle(gameweek: 3),
      );
      final hitDecision = service.evaluateTransfer(
        team: _buildTeam(freeTransfers: 0, freeTransfersGameweek: 3),
        lifecycle: _buildLifecycle(gameweek: 3),
      );

      expect(freeTransferDecision.usedFreeTransfer, isTrue);
      expect(freeTransferDecision.freeTransfersAfter, 0);

      expect(wildcardDecision.wildcardApplied, isTrue);
      expect(wildcardDecision.pointsDelta, 0);

      expect(hitDecision.hitApplied, isTrue);
      expect(hitDecision.pointsDelta, -4);
    });
  });
}

FantasyTeam _buildTeam({
  required int freeTransfers,
  required int freeTransfersGameweek,
  List<ChipUsage> chipUsages = const [],
}) {
  final now = DateTime(2026, 4, 1, 12);
  return FantasyTeam(
    id: 'team-1',
    ownerPlayerId: 'owner-1',
    teamName: 'Alpha',
    freeTransfers: freeTransfers,
    freeTransfersGameweek: freeTransfersGameweek,
    chipUsages: chipUsages,
    createdAt: now,
    updatedAt: now,
  );
}

FantasyLeagueLifecycle _buildLifecycle({
  required int gameweek,
  FantasyLeaguePhase phase = FantasyLeaguePhase.transferWindow,
  bool isGlobal = true,
  String leagueId = 'global',
}) {
  return FantasyLeagueLifecycle(
    leagueId: leagueId,
    currentGameweek: gameweek,
    phase: phase,
    isGlobal: isGlobal,
    updatedAt: DateTime(2026, 4, 15, 12),
  );
}
