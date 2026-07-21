import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_event.dart';
import '../../../domain/entities/participant_ref.dart';
import '../../profile/models/public_player_profile_data.dart';
import '../models/player_moment_share_data.dart';
import '../services/pride_share_payload_builder.dart';

class PlayerMomentShareController {
  const PlayerMomentShareController();

  static const _payloadBuilder = PrideSharePayloadBuilder();
  static const List<int> goalMilestones = [5, 10, 20];
  static const List<int> mvpMilestones = [3, 5, 10];

  GoalScorerShareData? buildGoalScorerIfEligible({
    required Match match,
    required Iterable<MatchEvent> events,
    required ParticipantRef actor,
    String? tournamentName,
    String? teamAName,
    String? teamBName,
    String? photoUrl,
  }) {
    final playerName = _requiredLabel(actor.displayName);
    if (!match.isOfficialTournamentResult ||
        !_hasProfile(actor) ||
        playerName == null) {
      return null;
    }

    final goals = events
        .where(
          (event) =>
              event.matchId == match.id &&
              event.isActive &&
              event.isGoal &&
              event.actor.kind == actor.kind &&
              event.actor.id == actor.id,
        )
        .toList(growable: false);
    if (goals.isEmpty) return null;

    final sideKey = goals.first.sideKey.trim().toUpperCase();
    if (sideKey != 'A' && sideKey != 'B') return null;

    return GoalScorerShareData(
      actor: actor.copyWith(displayName: playerName),
      playerName: playerName,
      initials: _initials(playerName),
      photoUrl: _optionalLabel(photoUrl),
      tournamentName: _optionalLabel(tournamentName),
      sideKey: sideKey,
      goalsInMatch: goals.length,
      teamAName: _optionalLabel(teamAName),
      teamBName: _optionalLabel(teamBName),
      scoreTeamA: match.scoreTeamA!,
      scoreTeamB: match.scoreTeamB!,
      sharePayload: _payloadBuilder.goalScorer(match: match, actor: actor),
    );
  }

  PlayerMilestoneShareData? buildMilestoneIfEligible({
    required PublicPlayerProfileData profile,
    required PlayerMilestoneMetric metric,
    String? tournamentName,
    String? tournamentId,
    String? matchId,
  }) {
    final playerName = _requiredLabel(profile.displayName);
    final playerId = _requiredLabel(profile.id);
    if (playerName == null || playerId == null) return null;

    final currentTotal = switch (metric) {
      PlayerMilestoneMetric.goals => profile.totalGoals,
      PlayerMilestoneMetric.mvps => profile.totalMvps,
    };
    final milestone = highestEarnedMilestone(
      metric: metric,
      currentTotal: currentTotal,
    );
    if (milestone == null) return null;

    final actor = ParticipantRef(
      kind: profile.kind,
      id: playerId,
      displayName: playerName,
    );
    if (!_hasProfile(actor)) return null;

    return PlayerMilestoneShareData(
      actor: actor,
      playerName: playerName,
      initials: _initials(playerName),
      photoUrl: _optionalLabel(profile.photoUrl),
      tournamentName: _optionalLabel(tournamentName),
      metric: metric,
      milestone: milestone,
      currentTotal: currentTotal,
      sharePayload: _payloadBuilder.playerMilestone(
        actor: actor,
        tournamentId: tournamentId,
        matchId: matchId,
      ),
    );
  }

  int? highestEarnedMilestone({
    required PlayerMilestoneMetric metric,
    required int currentTotal,
  }) {
    final milestones = metric == PlayerMilestoneMetric.goals
        ? goalMilestones
        : mvpMilestones;
    int? earned;
    for (final milestone in milestones) {
      if (currentTotal < milestone) break;
      earned = milestone;
    }
    return earned;
  }

  bool _hasProfile(ParticipantRef actor) =>
      actor.id.trim().isNotEmpty &&
      (actor.kind == ParticipantRefKind.player ||
          actor.kind == ParticipantRefKind.guestPlayer);

  String? _requiredLabel(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _optionalLabel(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String _initials(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.length == 1) return _take(words.first, 2);
    return '${_take(words.first, 1)}${_take(words[1], 1)}';
  }

  String _take(String value, int count) =>
      value.length <= count ? value : value.substring(0, count);
}
