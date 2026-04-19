import '../../data/repositories/match_repository_impl.dart';
import '../../data/repositories/player_repository_impl.dart';
import '../../data/repositories/tournament_repository_impl.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/repositories/match_repository.dart';
import '../../domain/repositories/player_repository.dart';
import '../../domain/repositories/tournament_repository.dart';
import '../../domain/repositories/team_repository.dart';
import '../../data/repositories/team_repository_impl.dart';

class ActivityFeedEntry {
  final String id;
  final String actorId;
  final String actorName;
  final String actionText;
  final String highlightText;
  final DateTime occurredAt;
  final String iconEmoji;

  const ActivityFeedEntry({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.actionText,
    required this.highlightText,
    required this.occurredAt,
    required this.iconEmoji,
  });

  String timeAgo({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(occurredAt);

    if (diff.inMinutes <= 0) {
      return 'الآن';
    }
    if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    }
    if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
    }
    if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} يوم';
    }
    final weeks = (diff.inDays / 7).floor();
    return 'منذ $weeks أسبوع';
  }
}

class ActivityFeedService {
  final PlayerRepository _playerRepository;
  final MatchRepository _matchRepository;
  final TournamentRepository _tournamentRepository;
  final TeamRepository _teamRepository;

  ActivityFeedService({
    PlayerRepository? playerRepository,
    MatchRepository? matchRepository,
    TournamentRepository? tournamentRepository,
    TeamRepository? teamRepository,
  })  : _playerRepository = playerRepository ?? PlayerRepositoryImpl(),
        _matchRepository = matchRepository ?? MatchRepositoryImpl(),
        _tournamentRepository =
            tournamentRepository ?? TournamentRepositoryImpl(),
        _teamRepository = teamRepository ?? TeamRepositoryImpl();

  Future<List<ActivityFeedEntry>> buildFeedForPlayer(
    Player currentPlayer, {
    int limit = 8,
  }) async {
    final socialIds = <String>{
      ...currentPlayer.friendIds,
      ...currentPlayer.followingIds,
    }
      ..remove(currentPlayer.id)
      ..removeAll(currentPlayer.blockedIds);

    if (socialIds.isEmpty) {
      return const [];
    }

    final actors = await Future.wait(
      socialIds.take(8).map(_playerRepository.getPlayer),
    );

    final entries = <ActivityFeedEntry>[];
    for (final actor in actors.whereType<Player>()) {
      final activityFutures = await Future.wait([
        _matchRepository.getPlayerMatches(actor.id, limit: 3),
        _tournamentRepository.getOrganizerTournaments(actor.id),
      ]);

      final recentMatches = activityFutures[0] as List<Match>;
      final organizerTournaments = activityFutures[1] as List<Tournament>;

      final matchEntry = _buildMatchEntry(actor, recentMatches);
      if (matchEntry != null) {
        entries.add(matchEntry);
      }

      final tournamentEntry =
          _buildTournamentEntry(actor, organizerTournaments);
      if (tournamentEntry != null) {
        entries.add(tournamentEntry);
      }
    }

    final deduped = <String, ActivityFeedEntry>{};
    for (final entry in entries) {
      deduped[entry.id] = entry;
    }

    // Add personal prompts
    final personalPrompts = await _buildPersonalPrompts(currentPlayer);
    for (final prompt in personalPrompts) {
      deduped[prompt.id] = prompt;
    }

    final sorted = deduped.values.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return sorted.take(limit).toList();
  }

  Future<List<ActivityFeedEntry>> _buildPersonalPrompts(Player currentPlayer) async {
    final prompts = <ActivityFeedEntry>[];

    // 1. Rating Prompt
    final recentMatches = await _matchRepository.getPlayerMatches(currentPlayer.id, limit: 3);
    for (final match in recentMatches) {
      if (_isFeedReadyStatus(match) && _isRecent(match.completedAt ?? match.createdAt)) {
        // Assume player hasn't rated if the match is very recent (this is a simplified check)
        prompts.add(
          ActivityFeedEntry(
            id: 'prompt-rating-${match.id}',
            actorId: currentPlayer.id,
            actorName: 'إشعار',
            actionText: 'لديك تقييم معلق لمباراة انتهت بنتيجة',
            highlightText: '${match.scoreTeamA ?? '-'}-${match.scoreTeamB ?? '-'}',
            occurredAt: match.completedAt ?? match.createdAt,
            iconEmoji: '⏱️',
          ),
        );
        break; // Only show one rating prompt
      }
    }

    // 2. Team Addition Prompt
    if (currentPlayer.teamIds.isNotEmpty) {
      final teams = await Future.wait(currentPlayer.teamIds.take(3).map(_teamRepository.getTeam));
      for (final team in teams) {
        if (team != null && _isRecent(team.createdAt, days: 7)) {
          prompts.add(
            ActivityFeedEntry(
              id: 'prompt-team-${team.id}',
              actorId: currentPlayer.id,
              actorName: 'إشعار',
              actionText: 'تمت إضافتك مؤخراً إلى فريق',
              highlightText: team.name,
              occurredAt: team.createdAt,
              iconEmoji: '🛡️',
            ),
          );
        }
      }
    }

    return prompts;
  }

  ActivityFeedEntry? _buildMatchEntry(Player actor, List<Match> matches) {
    final recentMatch = matches
        .where(
          (match) =>
              _isFeedReadyStatus(match) &&
              _isRecent(match.completedAt ?? match.createdAt),
        )
        .cast<Match?>()
        .firstWhere((match) => match != null, orElse: () => null);

    if (recentMatch == null) {
      return null;
    }

    final occurredAt = recentMatch.completedAt ?? recentMatch.createdAt;
    final scoreText =
        '${recentMatch.scoreTeamA ?? '-'}-${recentMatch.scoreTeamB ?? '-'}';

    if (recentMatch.mvpPlayerId == actor.id) {
      return ActivityFeedEntry(
        id: 'match-mvp-${recentMatch.id}-${actor.id}',
        actorId: actor.id,
        actorName: actor.name,
        actionText: 'اختير نجم المباراة في لقاء انتهى بنتيجة',
        highlightText: scoreText,
        occurredAt: occurredAt,
        iconEmoji: '⭐',
      );
    }

    if (_didWin(actor.id, recentMatch)) {
      return ActivityFeedEntry(
        id: 'match-win-${recentMatch.id}-${actor.id}',
        actorId: actor.id,
        actorName: actor.name,
        actionText: 'حقق فوزاً في مباراة انتهت بنتيجة',
        highlightText: scoreText,
        occurredAt: occurredAt,
        iconEmoji: '⚽',
      );
    }

    if (recentMatch.isGoldenRating) {
      return ActivityFeedEntry(
        id: 'match-golden-${recentMatch.id}-${actor.id}',
        actorId: actor.id,
        actorName: actor.name,
        actionText: 'شارك في مباراة ذهبية بنتيجة',
        highlightText: scoreText,
        occurredAt: occurredAt,
        iconEmoji: '🔥',
      );
    }

    return ActivityFeedEntry(
      id: 'match-played-${recentMatch.id}-${actor.id}',
      actorId: actor.id,
      actorName: actor.name,
      actionText: 'أنهى مباراة بنتيجة',
      highlightText: scoreText,
      occurredAt: occurredAt,
      iconEmoji: '🎯',
    );
  }

  ActivityFeedEntry? _buildTournamentEntry(
    Player actor,
    List<Tournament> tournaments,
  ) {
    final tournament = tournaments
        .where((item) => _isRecent(item.createdAt, days: 14))
        .cast<Tournament?>()
        .firstWhere((item) => item != null, orElse: () => null);

    if (tournament == null) {
      return null;
    }

    return ActivityFeedEntry(
      id: 'tournament-${tournament.id}-${actor.id}',
      actorId: actor.id,
      actorName: actor.name,
      actionText: 'أنشأ بطولة جديدة باسم',
      highlightText: tournament.name,
      occurredAt: tournament.createdAt,
      iconEmoji: '🏆',
    );
  }

  bool _didWin(String playerId, Match match) {
    if (match.scoreTeamA == null || match.scoreTeamB == null) {
      return false;
    }
    final inTeamA = match.teamAPlayerIds.contains(playerId);
    final inTeamB = match.teamBPlayerIds.contains(playerId);
    if (!inTeamA && !inTeamB) {
      return false;
    }

    if (inTeamA) {
      return match.scoreTeamA! > match.scoreTeamB!;
    }
    return match.scoreTeamB! > match.scoreTeamA!;
  }

  bool _isFeedReadyStatus(Match match) {
    return match.status.name == 'completed' ||
        match.status.name == 'settled' ||
        match.status.name == 'pendingReview';
  }

  bool _isRecent(DateTime date, {int days = 7}) {
    return !date.isBefore(DateTime.now().subtract(Duration(days: days)));
  }
}
