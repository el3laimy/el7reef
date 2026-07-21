import '../../../app/theme/app_colors.dart';
import '../../../core/enums/match_status.dart';
import '../../../domain/entities/match.dart';
import '../../../features/lineup/controllers/match_result_lineup_controller.dart';
import '../models/match_result_share_data.dart';
import '../services/pride_share_payload_builder.dart';

class MatchResultShareController {
  const MatchResultShareController();

  static const _payloadBuilder = PrideSharePayloadBuilder();

  MatchResultShareData build({
    required Match match,
    required ResultLineupSide teamA,
    required ResultLineupSide teamB,
    required String teamAFormation,
    required String teamBFormation,
    String? tournamentName,
    String? mvpName,
    List<MatchResultScorerData> scorers = const [],
  }) {
    return buildFromLabels(
      match: match,
      teamAName: teamA.label,
      teamBName: teamB.label,
      teamALogoUrl: teamA.logoUrl,
      teamBLogoUrl: teamB.logoUrl,
      teamAFormation: teamAFormation,
      teamBFormation: teamBFormation,
      tournamentName: tournamentName,
      mvpName: mvpName,
      scorers: scorers,
    );
  }

  MatchResultShareData buildFromLabels({
    required Match match,
    required String teamAName,
    required String teamBName,
    String? teamALogoUrl,
    String? teamBLogoUrl,
    String teamAFormation = '',
    String teamBFormation = '',
    String? tournamentName,
    String? mvpName,
    List<MatchResultScorerData> scorers = const [],
  }) {
    final scoreA = match.scoreTeamA;
    final scoreB = match.scoreTeamB;
    if (scoreA == null || scoreB == null) {
      throw Exception('لا توجد نتيجة لمشاركتها بعد.');
    }

    return MatchResultShareData(
      matchId: match.id,
      title: 'نتيجة المباراة',
      subtitle: _subtitle(match),
      teamAName: teamAName,
      teamALogoUrl: teamALogoUrl,
      teamAFormation: _nullableFormation(teamAFormation),
      teamAAccent: AppColors.primary,
      teamBName: teamBName,
      teamBLogoUrl: teamBLogoUrl,
      teamBFormation: _nullableFormation(teamBFormation),
      teamBAccent: AppColors.accent,
      scoreA: scoreA,
      scoreB: scoreB,
      statusLabel: _statusLabel(match.status),
      winnerSide: match.winner,
      // Do not infer tournament names from match flags; only show a real
      // loaded name passed by the caller.
      tournamentName: _normalizeOptional(tournamentName),
      mvpName: mvpName,
      scorers: List.unmodifiable(
        scorers.where(
          (scorer) => scorer.displayName.trim().isNotEmpty && scorer.goals > 0,
        ),
      ),
      playedAt: match.completedAt ?? match.startedAt ?? match.scheduledAt,
      sharePayload: _payloadBuilder.matchResult(match: match),
    );
  }

  String _subtitle(Match match) {
    final location = match.location?.trim();
    if (location != null && location.isNotEmpty) {
      return location;
    }
    return 'نتيجة المباراة';
  }

  String _statusLabel(MatchStatus status) => switch (status) {
    MatchStatus.live => 'جارية',
    MatchStatus.completed => 'نهاية المباراة',
    MatchStatus.pendingReview => 'قيد المراجعة',
    MatchStatus.ratingWindow => 'نهاية المباراة',
    MatchStatus.settled => 'تم اعتماد النتيجة',
    MatchStatus.frozen => 'مجمّدة',
    MatchStatus.cancelled => 'ملغاة',
    MatchStatus.open || MatchStatus.full => 'لم تبدأ',
  };

  String? _nullableFormation(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
