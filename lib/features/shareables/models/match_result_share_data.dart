import 'package:flutter/material.dart';

@immutable
class MatchResultShareData {
  final String matchId;
  final String title;
  final String subtitle;

  /// Already-resolved side A display name.
  ///
  /// Friendly matches should pass the name from FriendlyMatchSideView so saved
  /// matchSides names are used in exports.
  final String teamAName;
  final String? teamALogoUrl;
  final String? teamAFormation;
  final Color teamAAccent;

  /// Already-resolved side B display name.
  ///
  /// Friendly matches should pass the name from FriendlyMatchSideView so saved
  /// matchSides names are used in exports.
  final String teamBName;
  final String? teamBLogoUrl;
  final String? teamBFormation;
  final Color teamBAccent;
  final int scoreA;
  final int scoreB;
  final String statusLabel;
  final String? winnerSide;

  /// Real loaded tournament name only. Keep null when the name is unavailable.
  final String? tournamentName;
  final String? mvpName;
  final DateTime? playedAt;

  const MatchResultShareData({
    required this.matchId,
    required this.title,
    required this.subtitle,
    required this.teamAName,
    this.teamALogoUrl,
    this.teamAFormation,
    required this.teamAAccent,
    required this.teamBName,
    this.teamBLogoUrl,
    this.teamBFormation,
    required this.teamBAccent,
    required this.scoreA,
    required this.scoreB,
    required this.statusLabel,
    this.winnerSide,
    this.tournamentName,
    this.mvpName,
    this.playedAt,
  });
}
