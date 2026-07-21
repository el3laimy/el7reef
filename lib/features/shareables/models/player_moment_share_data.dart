import 'package:flutter/foundation.dart';

import '../../../domain/entities/participant_ref.dart';
import '../../../domain/entities/share_payload.dart';

enum PlayerMilestoneMetric { goals, mvps }

sealed class PlayerMomentShareData {
  final ParticipantRef actor;
  final String playerName;
  final String initials;
  final String? photoUrl;
  final String? tournamentName;
  final SharePayload sharePayload;

  const PlayerMomentShareData({
    required this.actor,
    required this.playerName,
    required this.initials,
    this.photoUrl,
    this.tournamentName,
    required this.sharePayload,
  });

  bool get isGuest => actor.kind == ParticipantRefKind.guestPlayer;
  String get semanticsLabel;
}

@immutable
final class GoalScorerShareData extends PlayerMomentShareData {
  final String sideKey;
  final int goalsInMatch;
  final String? teamAName;
  final String? teamBName;
  final int scoreTeamA;
  final int scoreTeamB;

  const GoalScorerShareData({
    required super.actor,
    required super.playerName,
    required super.initials,
    super.photoUrl,
    super.tournamentName,
    required this.sideKey,
    required this.goalsInMatch,
    this.teamAName,
    this.teamBName,
    required this.scoreTeamA,
    required this.scoreTeamB,
    required super.sharePayload,
  });

  bool get isHatTrick => goalsInMatch >= 3;
  String? get sideLabel => switch (sideKey) {
    'A' => teamAName,
    'B' => teamBName,
    _ => null,
  };

  GoalScorerShareData copyWith({String? photoUrl, SharePayload? sharePayload}) {
    return GoalScorerShareData(
      actor: actor,
      playerName: playerName,
      initials: initials,
      photoUrl: photoUrl ?? this.photoUrl,
      tournamentName: tournamentName,
      sideKey: sideKey,
      goalsInMatch: goalsInMatch,
      teamAName: teamAName,
      teamBName: teamBName,
      scoreTeamA: scoreTeamA,
      scoreTeamB: scoreTeamB,
      sharePayload: sharePayload ?? this.sharePayload,
    );
  }

  @override
  String get semanticsLabel =>
      '$playerName سجل $goalsInMatch ${goalsInMatch == 1 ? 'هدف' : 'أهداف'}';
}

@immutable
final class PlayerMilestoneShareData extends PlayerMomentShareData {
  final PlayerMilestoneMetric metric;
  final int milestone;
  final int currentTotal;

  const PlayerMilestoneShareData({
    required super.actor,
    required super.playerName,
    required super.initials,
    super.photoUrl,
    super.tournamentName,
    required this.metric,
    required this.milestone,
    required this.currentTotal,
    required super.sharePayload,
  });

  String get metricLabel => switch (metric) {
    PlayerMilestoneMetric.goals => 'هدف',
    PlayerMilestoneMetric.mvps => 'مرة نجم المباراة',
  };

  PlayerMilestoneShareData copyWith({
    String? photoUrl,
    SharePayload? sharePayload,
  }) {
    return PlayerMilestoneShareData(
      actor: actor,
      playerName: playerName,
      initials: initials,
      photoUrl: photoUrl ?? this.photoUrl,
      tournamentName: tournamentName,
      metric: metric,
      milestone: milestone,
      currentTotal: currentTotal,
      sharePayload: sharePayload ?? this.sharePayload,
    );
  }

  @override
  String get semanticsLabel => '$playerName حقق إنجاز $milestone $metricLabel';
}
