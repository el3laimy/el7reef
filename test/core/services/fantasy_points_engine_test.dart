import 'package:flutter_test/flutter_test.dart';
import 'package:el7reef/features/fantasy/services/fantasy_points_engine.dart';
import 'package:el7reef/features/fantasy/services/auto_substitution_engine.dart';
import 'package:el7reef/domain/entities/fantasy_chip.dart';
import 'package:el7reef/domain/entities/player_match_stats.dart';
import 'package:el7reef/domain/entities/fantasy_slot.dart';

void main() {
  group('FantasyPointsEngine Tests (Phase 8.2)', () {

    test('1. Basic participation points (2 points) for simply playing', () {
      const stats = PlayerMatchStats(
        playerId: 'p1', matchId: 'm1', teamId: 't1', played: true,
      );
      final points = FantasyPointsEngine.calculateFantasyPoints(stats);
      expect(points, 2);
    });

    test('2. Goalkeeper goal yields 12 extra points', () {
      const stats = PlayerMatchStats(
        playerId: 'p1', matchId: 'm1', teamId: 't1', played: true,
        position: MatchPosition.goalkeeper, goals: 1,
      );
      final points = FantasyPointsEngine.calculateFantasyPoints(stats);
      expect(points, 2 + 12);
    });

    test('3. Defender goal yields 6 extra points and clean sheet yields 4', () {
      const stats = PlayerMatchStats(
        playerId: 'p1', matchId: 'm1', teamId: 't1', played: true,
        position: MatchPosition.defender, goals: 1, cleanSheet: true,
      );
      final points = FantasyPointsEngine.calculateFantasyPoints(stats);
      expect(points, 2 + 6 + 4);
    });

    test('4. Midfielder assist yields 3 points, clean sheet 1 point', () {
      const stats = PlayerMatchStats(
        playerId: 'p1', matchId: 'm1', teamId: 't1', played: true,
        position: MatchPosition.midfielder, assists: 1, cleanSheet: true,
      );
      final points = FantasyPointsEngine.calculateFantasyPoints(stats);
      expect(points, 2 + 3 + 1);
    });

    test('5. Forward goal (4 pts), assist (3 pts), zero for clean sheet', () {
      const stats = PlayerMatchStats(
        playerId: 'p1', matchId: 'm1', teamId: 't1', played: true,
        position: MatchPosition.forward, goals: 1, assists: 1, cleanSheet: true,
      );
      final points = FantasyPointsEngine.calculateFantasyPoints(stats);
      expect(points, 2 + 4 + 3 + 0);
    });

    test('6. Yellow card deducts 1 point, red card deducts 3 points', () {
      const stats = PlayerMatchStats(
        playerId: 'p1', matchId: 'm1', teamId: 't1', played: true,
        yellowCard: true, redCard: true,
      );
      final points = FantasyPointsEngine.calculateFantasyPoints(stats);
      expect(points, 2 - 1 - 3); // = -2
    });

    test('7. Saves mechanism (2 points for every 3 saves)', () {
      const stats = PlayerMatchStats(
        playerId: 'p1', matchId: 'm1', teamId: 't1', played: true,
        saves: 7, // Floor(7/3) * 2 = 2 * 2 = 4
      );
      final points = FantasyPointsEngine.calculateFantasyPoints(stats);
      expect(points, 2 + 4);
    });

    test('8. MVP Bonus (+25 points) and Double Award (+45 points)', () {
      const stats = PlayerMatchStats(
        playerId: 'p1', matchId: 'm1', teamId: 't1', played: true,
      );
      final mvpPoints = FantasyPointsEngine.calculateFantasyPoints(stats, isMvp: true);
      expect(mvpPoints, 2 + 25);
      
      final doubleAwardPoints = FantasyPointsEngine.calculateFantasyPoints(stats, isDoubleAward: true);
      // Double award completely overrides MVP logic via if-else priority
      expect(doubleAwardPoints, 2 + 45);
    });

    test('9. Active Captain multiplier (x2) and Triple Captain (x3)', () {
      int basePoints = 10;
      int regular = FantasyPointsEngine.applyRoleMultiplier(basePoints, FantasyPlayerRole.none);
      int captain = FantasyPointsEngine.applyRoleMultiplier(basePoints, FantasyPlayerRole.captain);
      int triple = FantasyPointsEngine.applyRoleMultiplier(basePoints, FantasyPlayerRole.captain, isTripleCaptain: true);
      
      expect(regular, 10);
      expect(captain, 20);
      expect(triple, 30);
    });

    test('10. calculateRoundPoints ignores bench by default', () {
      final slots = [
        const FantasySlot(id: '1', fantasyTeamId: 't1', playerId: 'p-start', isStartingXI: true),
        const FantasySlot(id: '2', fantasyTeamId: 't1', playerId: 'p-bench', isStartingXI: false),
      ];
      final stats = {
        'p-start': const PlayerMatchStats(playerId: 'p-start', matchId: 'm1', teamId: 't1', played: true), // 2 pts
        'p-bench': const PlayerMatchStats(playerId: 'p-bench', matchId: 'm1', teamId: 't1', played: true, goals: 1), // 6 pts
      };
      
      final total = FantasyPointsEngine.calculateRoundPoints(slots: slots, roundStats: stats);
      expect(total, 2); // Bench is totally ignored
    });

    test('11. Bench Boost chip includes bench points', () {
      final slots = [
        const FantasySlot(id: '1', fantasyTeamId: 't1', playerId: 'p-start', isStartingXI: true),
        const FantasySlot(id: '2', fantasyTeamId: 't1', playerId: 'p-bench', isStartingXI: false),
      ];
      final stats = {
        'p-start': const PlayerMatchStats(playerId: 'p-start', matchId: 'm1', teamId: 't1', played: true), // 2 pts
        'p-bench': const PlayerMatchStats(playerId: 'p-bench', matchId: 'm1', teamId: 't1', played: true, goals: 1), // 6 pts normally (assuming mixed/forward=4)
      };
      
      final total = FantasyPointsEngine.calculateRoundPoints(
        slots: slots,
        roundStats: stats,
        currentGameweek: 4,
        activeChips: [
          ChipUsage(
            chipType: ChipType.benchBoost,
            gameweek: 4,
            activatedAt: DateTime(2026, 4, 14),
          ),
        ],
      );
      expect(total, 2 + 6); // 2(participation) + (2 + 4 for goal) = 8
    });

    test('11.1 Bench Boost is ignored outside its activation gameweek', () {
      final slots = [
        const FantasySlot(id: '1', fantasyTeamId: 't1', playerId: 'p-start', isStartingXI: true),
        const FantasySlot(id: '2', fantasyTeamId: 't1', playerId: 'p-bench', isStartingXI: false),
      ];
      final stats = {
        'p-start': const PlayerMatchStats(playerId: 'p-start', matchId: 'm1', teamId: 't1', played: true),
        'p-bench': const PlayerMatchStats(playerId: 'p-bench', matchId: 'm1', teamId: 't1', played: true, goals: 1),
      };

      final total = FantasyPointsEngine.calculateRoundPoints(
        slots: slots,
        roundStats: stats,
        currentGameweek: 5,
        activeChips: [
          ChipUsage(
            chipType: ChipType.benchBoost,
            gameweek: 4,
            activatedAt: DateTime(2026, 4, 14),
          ),
        ],
      );

      expect(total, 2);
    });

    test('11.2 Triple Captain only affects the matching gameweek', () {
      final slots = [
        const FantasySlot(
          id: '1',
          fantasyTeamId: 't1',
          playerId: 'captain',
          isStartingXI: true,
          role: FantasyPlayerRole.captain,
        ),
      ];
      final stats = {
        'captain': const PlayerMatchStats(
          playerId: 'captain',
          matchId: 'm1',
          teamId: 't1',
          played: true,
          goals: 1,
        ),
      };

      final totalWithChip = FantasyPointsEngine.calculateRoundPoints(
        slots: slots,
        roundStats: stats,
        currentGameweek: 7,
        activeChips: [
          ChipUsage(
            chipType: ChipType.tripleCaptain,
            gameweek: 7,
            activatedAt: DateTime(2026, 4, 14),
          ),
        ],
      );
      final totalWithoutChip = FantasyPointsEngine.calculateRoundPoints(
        slots: slots,
        roundStats: stats,
        currentGameweek: 8,
        activeChips: [
          ChipUsage(
            chipType: ChipType.tripleCaptain,
            gameweek: 7,
            activatedAt: DateTime(2026, 4, 14),
          ),
        ],
      );

      expect(totalWithChip, 18);
      expect(totalWithoutChip, 12);
    });

    test('12. Auto Substitution swaps non-playing starter with top priority playing bench', () {
      final slots = [
        const FantasySlot(id: 's1', fantasyTeamId: 't1', playerId: 'starter-missing', isStartingXI: true),
        const FantasySlot(id: 'b1', fantasyTeamId: 't1', playerId: 'bench-did-not-play', isStartingXI: false, benchPriority: 1),
        const FantasySlot(id: 'b2', fantasyTeamId: 't1', playerId: 'bench-played', isStartingXI: false, benchPriority: 2),
      ];
      final stats = {
        'bench-did-not-play': const PlayerMatchStats(playerId: 'bench-did-not-play', matchId: 'm1', teamId: 't1', played: false),
        'bench-played': const PlayerMatchStats(playerId: 'bench-played', matchId: 'm1', teamId: 't1', played: true),
      };
      
      final newSlots = AutoSubstitutionEngine.processAutoSubstitutions(currentSlots: slots, roundStats: stats);
      
      final starterMissingSlot = newSlots.firstWhere((s) => s.playerId == 'starter-missing');
      final benchPlayedSlot = newSlots.firstWhere((s) => s.playerId == 'bench-played');
      final benchDidNotPlaySlot = newSlots.firstWhere((s) => s.playerId == 'bench-did-not-play');

      // The missing starter is benched
      expect(starterMissingSlot.isStartingXI, false);
      
      // The bench player with Priority 1 did NOT play, so they are ignored.
      expect(benchDidNotPlaySlot.isStartingXI, false);
      
      // The bench player with Priority 2 played, so they are subbed IN!
      expect(benchPlayedSlot.isStartingXI, true);
    });

    test('13. No auto substitution happens if all starters played', () {
       final slots = [
        const FantasySlot(id: 's1', fantasyTeamId: 't1', playerId: 's-played', isStartingXI: true),
        const FantasySlot(id: 'b1', fantasyTeamId: 't1', playerId: 'b-played', isStartingXI: false, benchPriority: 1),
      ];
      final stats = {
        's-played': const PlayerMatchStats(playerId: 's-played', matchId: 'm1', teamId: 't1', played: true),
        'b-played': const PlayerMatchStats(playerId: 'b-played', matchId: 'm1', teamId: 't1', played: true),
      };

      final newSlots = AutoSubstitutionEngine.processAutoSubstitutions(currentSlots: slots, roundStats: stats);
      
      expect(newSlots.firstWhere((s) => s.playerId == 's-played').isStartingXI, true);
      expect(newSlots.firstWhere((s) => s.playerId == 'b-played').isStartingXI, false);
    });

    test('14. No auto substitution happens if nobody on bench played', () {
      final slots = [
        const FantasySlot(id: 's1', fantasyTeamId: 't1', playerId: 's-missing', isStartingXI: true),
        const FantasySlot(id: 'b1', fantasyTeamId: 't1', playerId: 'b-missing', isStartingXI: false, benchPriority: 1),
      ];
      final stats = { 'b-missing': const PlayerMatchStats(playerId: 'b-missing', matchId: 'm1', teamId: 't1', played: false) };

      final newSlots = AutoSubstitutionEngine.processAutoSubstitutions(currentSlots: slots, roundStats: stats);
      
      expect(newSlots.firstWhere((s) => s.playerId == 's-missing').isStartingXI, true); // Stays true because no sub existed
    });

    test('15. processAutoSubstitutions ignores missing stats completely', () {
       final slots = [
        const FantasySlot(id: 's1', fantasyTeamId: 't1', playerId: 's-missing', isStartingXI: true),
        const FantasySlot(id: 'b1', fantasyTeamId: 't1', playerId: 'b-played', isStartingXI: false, benchPriority: 1),
      ];
      final stats = {
        // s-missing entirely omitted from stats map
        'b-played': const PlayerMatchStats(playerId: 'b-played', matchId: 'm1', teamId: 't1', played: true),
      };

      final newSlots = AutoSubstitutionEngine.processAutoSubstitutions(currentSlots: slots, roundStats: stats);
      
      expect(newSlots.firstWhere((s) => s.playerId == 's-missing').isStartingXI, false); 
      expect(newSlots.firstWhere((s) => s.playerId == 'b-played').isStartingXI, true); 
    });

  });
}
