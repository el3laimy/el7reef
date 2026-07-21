import 'package:flutter/foundation.dart';

import '../../../domain/entities/share_payload.dart';

@immutable
class TeamShareData {
  final String teamName;
  final String initials;
  final String? logoUrl;
  final String teamKindLabel;
  final String? tournamentName;
  final int? playerCount;
  final int? wins;
  final int? totalMatches;
  final SharePayload sharePayload;

  const TeamShareData({
    required this.teamName,
    required this.initials,
    this.logoUrl,
    required this.teamKindLabel,
    this.tournamentName,
    this.playerCount,
    this.wins,
    this.totalMatches,
    required this.sharePayload,
  });
}
