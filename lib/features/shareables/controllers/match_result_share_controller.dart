import '../../../app/theme/app_colors.dart';
import '../../../core/enums/match_status.dart';
import '../../../domain/entities/match.dart';
import '../../../features/lineup/controllers/match_result_lineup_controller.dart';
import '../models/match_result_share_data.dart';

class MatchResultShareController {
  const MatchResultShareController();

  MatchResultShareData build({
    required Match match,
    required ResultLineupSide teamA,
    required ResultLineupSide teamB,
    required String teamAFormation,
    required String teamBFormation,
    String? tournamentName,
    String? mvpName,
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
      teamAName: teamA.label,
      teamALogoUrl: teamA.logoUrl,
      teamAFormation: _nullableFormation(teamAFormation),
      teamAAccent: AppColors.primary,
      teamBName: teamB.label,
      teamBLogoUrl: teamB.logoUrl,
      teamBFormation: _nullableFormation(teamBFormation),
      teamBAccent: AppColors.error,
      scoreA: scoreA,
      scoreB: scoreB,
      statusLabel: _statusLabel(match.status),
      winnerSide: match.winner,
      // Do not infer tournament names from match flags; only show a real
      // loaded name passed by the caller.
      tournamentName: _normalizeOptional(tournamentName),
      mvpName: mvpName,
      playedAt: match.completedAt ?? match.startedAt ?? match.scheduledAt,
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
