import '../../../domain/entities/player.dart';
import '../../../domain/entities/player_match_stats.dart';
import '../../../domain/entities/penalty_shootout_result.dart';
import '../../../core/services/match_settlement_service.dart';
import '../models/score_submit_models.dart';

class ScoreSubmitValidationResult {
  final int? scoreA;
  final int? scoreB;
  final String? errorTitle;
  final String? errorMessage;

  const ScoreSubmitValidationResult._({
    this.scoreA,
    this.scoreB,
    this.errorTitle,
    this.errorMessage,
  });

  const ScoreSubmitValidationResult.valid({
    required int scoreA,
    required int scoreB,
  }) : this._(scoreA: scoreA, scoreB: scoreB);

  const ScoreSubmitValidationResult.invalid({
    required String title,
    required String message,
  }) : this._(errorTitle: title, errorMessage: message);

  bool get isValid => scoreA != null && scoreB != null;
}

class ScoreSubmitPreparation {
  static const attributionOverScoreMessage =
      'عدد الأهداف المنسوبة أكبر من نتيجة الفريق.';

  const ScoreSubmitPreparation._();

  static ScoreSubmitValidationResult validateScores({
    required String rawScoreA,
    required String rawScoreB,
    required String sideAName,
    required String sideBName,
    required int attributedGoalsA,
    required int attributedGoalsB,
  }) {
    final scoreA = _parseScore(
      rawValue: rawScoreA,
      sideName: sideAName,
      fallback: attributedGoalsA,
    );
    if (scoreA.errorMessage != null) {
      return ScoreSubmitValidationResult.invalid(
        title: 'نتيجة غير صحيحة',
        message: scoreA.errorMessage!,
      );
    }

    final scoreB = _parseScore(
      rawValue: rawScoreB,
      sideName: sideBName,
      fallback: attributedGoalsB,
    );
    if (scoreB.errorMessage != null) {
      return ScoreSubmitValidationResult.invalid(
        title: 'نتيجة غير صحيحة',
        message: scoreB.errorMessage!,
      );
    }

    final parsedA = scoreA.score!;
    final parsedB = scoreB.score!;
    if (attributedGoalsA > parsedA || attributedGoalsB > parsedB) {
      return const ScoreSubmitValidationResult.invalid(
        title: 'نتيجة غير متسقة',
        message: attributionOverScoreMessage,
      );
    }
    return ScoreSubmitValidationResult.valid(scoreA: parsedA, scoreB: parsedB);
  }

  static ScoreSideGoalSummary goalSummary({
    required String sideKey,
    required String rawScore,
    required int attributedGoals,
  }) {
    final normalizedSideKey = sideKey.trim().toUpperCase();
    final parsed = int.tryParse(rawScore.trim());
    final validScore = parsed != null && parsed >= 0 ? parsed : null;
    return ScoreSideGoalSummary(
      sideKey: normalizedSideKey,
      teamScore: validScore ?? attributedGoals,
      attributedGoals: attributedGoals,
    );
  }

  static List<MatchSettlementGoalDraft> settlementGoals(
    Iterable<ScoreSubmitGoalDraft> drafts,
  ) {
    return drafts
        .where((draft) => draft.goals > 0)
        .map(
          (draft) => MatchSettlementGoalDraft(
            sideKey: draft.sideKey,
            actor: draft.actor,
            goals: draft.goals,
            minute: draft.minute,
          ),
        )
        .toList(growable: false);
  }

  static List<PlayerMatchStats> detailedStats({
    required String matchId,
    required String teamAId,
    required String teamBId,
    required Iterable<Player> teamAPlayers,
    required Iterable<Player> teamBPlayers,
    required Map<String, Map<String, dynamic>> playerStats,
    required bool teamACleanSheet,
    required bool teamBCleanSheet,
  }) {
    return [
      ...teamAPlayers.map(
        (player) => _playerStats(
          player: player,
          matchId: matchId,
          teamId: teamAId,
          stats: playerStats[player.id]!,
          cleanSheet: teamACleanSheet,
        ),
      ),
      ...teamBPlayers.map(
        (player) => _playerStats(
          player: player,
          matchId: matchId,
          teamId: teamBId,
          stats: playerStats[player.id]!,
          cleanSheet: teamBCleanSheet,
        ),
      ),
    ];
  }

  static ({int? score, String? errorMessage}) _parseScore({
    required String rawValue,
    required String sideName,
    required int fallback,
  }) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return (score: fallback, errorMessage: null);
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null ||
        parsed < 0 ||
        parsed > PenaltyShootoutResult.maxScore) {
      return (
        score: null,
        errorMessage: 'أدخل نتيجة صحيحة بين 0 و99 لـ $sideName.',
      );
    }
    return (score: parsed, errorMessage: null);
  }

  static PlayerMatchStats _playerStats({
    required Player player,
    required String matchId,
    required String teamId,
    required Map<String, dynamic> stats,
    required bool cleanSheet,
  }) {
    return PlayerMatchStats(
      playerId: player.id,
      matchId: matchId,
      teamId: teamId,
      played: stats['played'] as bool,
      position: _position(player.position),
      goals: stats['goals'] as int,
      assists: stats['assists'] as int,
      saves: stats['saves'] as int,
      yellowCard: stats['yellowCard'] as bool,
      redCard: stats['redCard'] as bool,
      cleanSheet: cleanSheet,
    );
  }

  static MatchPosition _position(String? position) {
    return switch (position) {
      'GK' => MatchPosition.goalkeeper,
      'DEF' => MatchPosition.defender,
      'MID' => MatchPosition.midfielder,
      'FWD' => MatchPosition.forward,
      _ => MatchPosition.mixed,
    };
  }
}
