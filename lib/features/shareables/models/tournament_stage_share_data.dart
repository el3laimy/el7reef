import 'package:flutter/foundation.dart';

import '../../../domain/entities/share_payload.dart';

enum TournamentStagePrideKind { groupStandings, knockoutBracket }

@immutable
class TournamentStageShareRowData {
  final String leading;
  final String title;
  final String? subtitle;
  final String? trailing;
  final bool emphasized;
  final bool earned;

  const TournamentStageShareRowData({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.emphasized = false,
    this.earned = false,
  });
}

@immutable
class TournamentStageShareData {
  final TournamentStagePrideKind kind;
  final String tournamentName;
  final String title;
  final String statusLabel;
  final List<TournamentStageShareRowData> rows;
  final SharePayload sharePayload;

  const TournamentStageShareData({
    required this.kind,
    required this.tournamentName,
    required this.title,
    required this.statusLabel,
    required this.rows,
    required this.sharePayload,
  });
}
