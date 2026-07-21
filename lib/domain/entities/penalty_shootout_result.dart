import '../../core/enums/tournament_ops_enums.dart';

/// A penalty shootout score kept separate from regulation-time match goals.
class PenaltyShootoutResult {
  static const int maxScore = 99;

  final int scoreTeamA;
  final int scoreTeamB;

  const PenaltyShootoutResult({
    required this.scoreTeamA,
    required this.scoreTeamB,
  });

  bool get isValid =>
      scoreTeamA >= 0 &&
      scoreTeamA <= maxScore &&
      scoreTeamB >= 0 &&
      scoreTeamB <= maxScore &&
      scoreTeamA != scoreTeamB;

  KnockoutDecision? get decision {
    if (!isValid) return null;
    return scoreTeamA > scoreTeamB
        ? KnockoutDecision.teamA
        : KnockoutDecision.teamB;
  }
}
