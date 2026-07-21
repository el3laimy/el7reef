import 'package:flutter/foundation.dart';

import '../../../domain/entities/share_payload.dart';

sealed class TournamentAnnouncementShareData {
  final String tournamentName;
  final SharePayload sharePayload;

  const TournamentAnnouncementShareData({
    required this.tournamentName,
    required this.sharePayload,
  });

  String get semanticsLabel;
}

@immutable
final class TournamentInviteShareData extends TournamentAnnouncementShareData {
  final String teamSizeLabel;
  final int maxTeams;
  final String? location;
  final DateTime? startDate;
  final DateTime? registrationDeadline;

  const TournamentInviteShareData({
    required super.tournamentName,
    required this.teamSizeLabel,
    required this.maxTeams,
    this.location,
    this.startDate,
    this.registrationDeadline,
    required super.sharePayload,
  });

  @override
  String get semanticsLabel => 'دعوة التسجيل في بطولة $tournamentName';
}

@immutable
final class UpcomingFixtureShareData extends TournamentAnnouncementShareData {
  final String teamAName;
  final String teamBName;
  final DateTime scheduledAt;
  final String stageLabel;
  final String? location;

  const UpcomingFixtureShareData({
    required super.tournamentName,
    required this.teamAName,
    required this.teamBName,
    required this.scheduledAt,
    required this.stageLabel,
    this.location,
    required super.sharePayload,
  });

  @override
  String get semanticsLabel =>
      'بوستر المباراة القادمة بين $teamAName و$teamBName';
}
