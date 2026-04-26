import '../../core/enums/lineup_requirement.dart';
import '../../core/enums/match_status.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_lineup_snapshot.dart';
import '../../domain/repositories/match_repository.dart';
import '../../data/repositories/match_side_player_repository_impl.dart';
import '../../data/repositories/match_lineup_snapshot_repository_impl.dart';

/// Readiness assessment for starting a match.
class MatchStartReadiness {
  final bool canStart;
  final List<String> blockedReasons;

  const MatchStartReadiness({
    required this.canStart,
    this.blockedReasons = const [],
  });
}

/// Validates pre-conditions and transitions a match to [MatchStatus.live].
///
/// Centralizes all start-match logic so that neither [MatchLobbyController] nor
/// any other caller can bypass lineup / check-in requirements.
class MatchStartService {
  final MatchRepository _matchRepo;
  final MatchLineupSnapshotRepositoryImpl _snapshotRepo;
  final MatchSidePlayerRepositoryImpl? _sidePlayerRepo;

  MatchStartService({
    required MatchRepository matchRepo,
    required MatchLineupSnapshotRepositoryImpl snapshotRepo,
    MatchSidePlayerRepositoryImpl? sidePlayerRepo,
  }) : _matchRepo = matchRepo,
       _snapshotRepo = snapshotRepo,
       _sidePlayerRepo = sidePlayerRepo;

  /// Returns a readiness assessment without mutating state.  Use this from the
  /// UI to show why the start button is disabled.
  Future<MatchStartReadiness> getStartReadiness({
    required String matchId,
    required String actorId,
  }) async {
    final match = await _matchRepo.getMatch(matchId);
    if (match == null) {
      return const MatchStartReadiness(
        canStart: false,
        blockedReasons: ['المباراة غير موجودة.'],
      );
    }
    final reasons = await _collectBlockedReasons(
      match: match,
      actorId: actorId,
    );
    return MatchStartReadiness(
      canStart: reasons.isEmpty,
      blockedReasons: reasons,
    );
  }

  /// Validates and starts the match.  Throws if any pre-condition fails.
  Future<Match> startMatch({
    required String matchId,
    required String actorId,
  }) async {
    final match = await _matchRepo.getMatch(matchId);
    if (match == null) {
      throw Exception('المباراة غير موجودة.');
    }
    final reasons = await _collectBlockedReasons(
      match: match,
      actorId: actorId,
    );
    if (reasons.isNotEmpty) {
      throw Exception(reasons.first);
    }

    final now = DateTime.now();
    final updated = match.copyWith(status: MatchStatus.live, startedAt: now);
    await _matchRepo.updateMatch(updated);
    return updated;
  }

  Future<List<String>> _collectBlockedReasons({
    required Match match,
    required String actorId,
  }) async {
    final reasons = <String>[];

    // 1. Actor must be the organizer.
    if (match.organizerId != actorId) {
      reasons.add('فقط منشئ المباراة يمكنه بدء المباراة.');
    }

    // 2. Tournament fixtures must use the tournament fixture service because
    // it validates published status, check-ins, lineups, and participant sides.
    if (match.tournamentId != null && match.tournamentId!.isNotEmpty) {
      reasons.add('مباريات البطولة تبدأ من إدارة البطولة/الفيكستشر فقط.');
    }

    // 3. Match must be in a startable status.
    if (match.status == MatchStatus.cancelled) {
      reasons.add('لا يمكن بدء مباراة ملغاة.');
    } else if (match.status != MatchStatus.open &&
        match.status != MatchStatus.full) {
      reasons.add('حالة المباراة لا تسمح ببدء الآن.');
    }

    // 4. Match must not be frozen.
    if (match.isFrozen) {
      reasons.add('المباراة مجمّدة.');
    }

    final requirement = match.lineupRequirement;
    final isFriendlyMatch =
        match.tournamentId == null || match.tournamentId!.isEmpty;

    // 5. Friendly matches without required lineups only need one player per side.
    if (isFriendlyMatch && requirement != LineupRequirement.required) {
      final temporarySideCounts = await _loadTemporarySideCounts(match.id);
      final teamACount =
          match.teamAPlayerIds.length + (temporarySideCounts['A'] ?? 0);
      final teamBCount =
          match.teamBPlayerIds.length + (temporarySideCounts['B'] ?? 0);
      if (teamACount < 1) {
        reasons.add('الفريق الأول يحتاج لاعبًا واحدًا على الأقل.');
      }
      if (teamBCount < 1) {
        reasons.add('الفريق الثاني يحتاج لاعبًا واحدًا على الأقل.');
      }
      return reasons;
    }

    // 6. Lineup requirements.
    if (requirement == LineupRequirement.required) {
      final snapshots = await _snapshotRepo.getMatchSnapshots(match.id);
      final hasTeamALineup = _hasLineupForSide(
        snapshots: snapshots,
        teamId: match.teamAId,
        matchId: match.id,
        sideKey: 'A',
      );
      final hasTeamBLineup = _hasLineupForSide(
        snapshots: snapshots,
        teamId: match.teamBId,
        matchId: match.id,
        sideKey: 'B',
      );
      if (!hasTeamALineup) {
        reasons.add('تشكيلة الفريق الأول غير مقفولة.');
      }
      if (!hasTeamBLineup) {
        reasons.add('تشكيلة الفريق الثاني غير مقفولة.');
      }
    }

    // 7. Both sides must have players (at minimum).
    final temporarySideCounts = await _loadTemporarySideCounts(match.id);
    final teamACount =
        match.teamAPlayerIds.length + (temporarySideCounts['A'] ?? 0);
    final teamBCount =
        match.teamBPlayerIds.length + (temporarySideCounts['B'] ?? 0);
    if (teamACount < 1 && match.teamAId == null) {
      reasons.add('الفريق الأول ليس له لاعبين.');
    }
    if (teamBCount < 1 && match.teamBId == null) {
      reasons.add('الفريق الثاني ليس له لاعبين.');
    }

    return reasons;
  }

  Future<Map<String, int>> _loadTemporarySideCounts(String matchId) async {
    final repo = _sidePlayerRepo;
    if (repo == null) return const {};
    final players = await repo.getTemporaryPlayersForMatch(matchId);
    final counts = <String, int>{};
    for (final player in players) {
      counts[player.sideKey] = (counts[player.sideKey] ?? 0) + 1;
    }
    return counts;
  }

  bool _hasLineupForSide({
    required List<MatchLineupSnapshot> snapshots,
    required String? teamId,
    required String matchId,
    required String sideKey,
  }) {
    if (teamId != null) {
      return snapshots.any((snapshot) => snapshot.teamId == teamId);
    }
    final matchSideId = '${matchId}_${sideKey.trim().toUpperCase()}';
    return snapshots.any((snapshot) => snapshot.matchSideId == matchSideId);
  }
}
