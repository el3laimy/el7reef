import 'package:flutter/material.dart';

import '../../../core/lineup/lineup_types.dart';

enum LineupShareOwnerType { officialTeam, temporarySide, guestTeam }

@immutable
class LineupSharePlayerData {
  final String id;
  final String displayName;
  final String initials;
  final int? shirtNumber;
  final String slotId;
  final SlotRole slotRole;
  final double slotX;
  final double slotY;
  final bool isTemporary;

  const LineupSharePlayerData({
    required this.id,
    required this.displayName,
    required this.initials,
    this.shirtNumber,
    required this.slotId,
    required this.slotRole,
    required this.slotX,
    required this.slotY,
    required this.isTemporary,
  });
}

@immutable
class LineupShareBenchPlayerData {
  final String id;
  final String displayName;
  final String initials;
  final int? shirtNumber;
  final bool isTemporary;

  const LineupShareBenchPlayerData({
    required this.id,
    required this.displayName,
    required this.initials,
    this.shirtNumber,
    required this.isTemporary,
  });
}

@immutable
class LineupShareData {
  final String matchId;
  final LineupShareOwnerType lineupOwnerType;
  final String ownerId;
  final String? sideKey;
  final String teamName;
  final String? teamLabel;
  final String? logoUrl;
  final String initials;
  final Color accentColor;
  final String formationCode;
  final String? formationLabel;
  final int teamSize;
  final String lineupTypeLabel;
  final String? matchLabel;
  final List<LineupSharePlayerData> pitchPlayers;
  final List<LineupShareBenchPlayerData> benchPlayers;
  final String? statusLabel;
  final String? updatedLabel;

  const LineupShareData({
    required this.matchId,
    required this.lineupOwnerType,
    required this.ownerId,
    this.sideKey,
    required this.teamName,
    this.teamLabel,
    this.logoUrl,
    required this.initials,
    required this.accentColor,
    required this.formationCode,
    this.formationLabel,
    required this.teamSize,
    required this.lineupTypeLabel,
    this.matchLabel,
    required this.pitchPlayers,
    this.benchPlayers = const [],
    this.statusLabel,
    this.updatedLabel,
  });
}
