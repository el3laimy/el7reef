import 'package:flutter/foundation.dart';

import '../../../domain/entities/share_payload.dart';

@immutable
class QualificationShareData {
  final String tournamentName;
  final String groupName;
  final String teamName;
  final String teamKindLabel;
  final String initials;
  final String? logoUrl;
  final int rank;
  final int points;
  final int goalDifference;
  final SharePayload sharePayload;

  const QualificationShareData({
    required this.tournamentName,
    required this.groupName,
    required this.teamName,
    required this.teamKindLabel,
    required this.initials,
    this.logoUrl,
    required this.rank,
    required this.points,
    required this.goalDifference,
    required this.sharePayload,
  });

  String get semanticsLabel =>
      '$teamName متأهل رسميًا من $groupName في المركز $rank';
}
