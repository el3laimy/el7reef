import 'package:flutter/foundation.dart';

import '../../../domain/entities/share_payload.dart';

@immutable
class ChampionShareData {
  final String tournamentName;
  final String championName;
  final String teamKindLabel;
  final String? logoUrl;
  final String initials;
  final SharePayload sharePayload;

  const ChampionShareData({
    required this.tournamentName,
    required this.championName,
    required this.teamKindLabel,
    this.logoUrl,
    required this.initials,
    required this.sharePayload,
  });
}
