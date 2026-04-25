import 'package:flutter/material.dart';

@immutable
class MatchResultShareData {
  final String matchId;
  final String title;
  final String subtitle;
  final String teamAName;
  final String? teamALogoUrl;
  final String? teamAFormation;
  final Color teamAAccent;
  final String teamBName;
  final String? teamBLogoUrl;
  final String? teamBFormation;
  final Color teamBAccent;
  final int scoreA;
  final int scoreB;
  final String statusLabel;
  final String? winnerSide;
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
