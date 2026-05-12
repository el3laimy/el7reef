import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/fantasy_league_phase.dart';
import 'package:el7reef/features/fantasy/services/chip_manager_service.dart';
import 'package:el7reef/domain/entities/fantasy_chip.dart';
import 'package:el7reef/domain/entities/fantasy_league_lifecycle.dart';
import 'package:el7reef/domain/entities/fantasy_team.dart';

void main() {
  group('ChipManagerService', () {
    const service = ChipManagerService();

    test('activates a chip for the current gameweek', () {
      final now = DateTime(2026, 4, 15, 12);
      final updatedTeam = service.activateChip(
        currentTeam: _buildTeam(),
        targetChip: ChipType.benchBoost,
        lifecycle: _buildLifecycle(),
        now: now,
      );

      expect(updatedTeam.chipUsages, hasLength(1));
      expect(updatedTeam.chipUsages.single.chipType, ChipType.benchBoost);
      expect(updatedTeam.chipUsages.single.gameweek, 3);
      expect(updatedTeam.updatedAt, now);
    });

    test('blocks activating a second chip in the same gameweek', () {
      final team = _buildTeam(
        chipUsages: [
          ChipUsage(
            chipType: ChipType.tripleCaptain,
            gameweek: 3,
            activatedAt: DateTime(2026, 4, 10, 12),
          ),
        ],
      );

      final reason = service.getUnavailableReason(
        currentTeam: team,
        targetChip: ChipType.benchBoost,
        lifecycle: _buildLifecycle(),
      );

      expect(reason, contains('خاصية واحدة فقط'));
    });

    test('blocks reusing a consumed one-time chip', () {
      final team = _buildTeam(
        chipUsages: [
          ChipUsage(
            chipType: ChipType.benchBoost,
            gameweek: 1,
            activatedAt: DateTime(2026, 4, 1, 12),
            consumedAt: DateTime(2026, 4, 2, 12),
          ),
        ],
      );

      final reason = service.getUnavailableReason(
        currentTeam: team,
        targetChip: ChipType.benchBoost,
        lifecycle: _buildLifecycle(),
      );

      expect(reason, contains('مرة واحدة فقط'));
    });

    test('blocks chip activation in a locked lifecycle', () {
      final reason = service.getUnavailableReason(
        currentTeam: _buildTeam(),
        targetChip: ChipType.wildcardGroups,
        lifecycle: _buildLifecycle(
          phase: FantasyLeaguePhase.locked,
          isLocked: true,
        ),
      );

      expect(reason, contains('مغلقة'));
    });
  });
}

FantasyTeam _buildTeam({
  List<ChipUsage> chipUsages = const [],
}) {
  final now = DateTime(2026, 4, 1, 12);
  return FantasyTeam(
    id: 'team-1',
    ownerPlayerId: 'owner-1',
    teamName: 'Alpha',
    chipUsages: chipUsages,
    createdAt: now,
    updatedAt: now,
  );
}

FantasyLeagueLifecycle _buildLifecycle({
  FantasyLeaguePhase phase = FantasyLeaguePhase.transferWindow,
  bool isLocked = false,
}) {
  return FantasyLeagueLifecycle(
    leagueId: 'global',
    currentGameweek: 3,
    phase: phase,
    isLocked: isLocked,
    updatedAt: DateTime(2026, 4, 15, 12),
  );
}
