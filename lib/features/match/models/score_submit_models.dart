import '../../../domain/entities/participant_ref.dart';

class ScoreSubmitGoalDraft {
  final ParticipantRef actor;
  final String sideKey;
  final int goals;
  final int? minute;

  const ScoreSubmitGoalDraft({
    required this.actor,
    required this.sideKey,
    required this.goals,
    this.minute,
  });
}

class ScoreSideGoalSummary {
  final String sideKey;
  final int teamScore;
  final int attributedGoals;

  const ScoreSideGoalSummary({
    required this.sideKey,
    required this.teamScore,
    required this.attributedGoals,
  });

  int get unattributedGoals =>
      teamScore > attributedGoals ? teamScore - attributedGoals : 0;

  int get overAttributedGoals =>
      attributedGoals > teamScore ? attributedGoals - teamScore : 0;

  bool get hasUnattributedGoals => unattributedGoals > 0;
  bool get isOverAttributed => overAttributedGoals > 0;
}
