import 'package:flutter/foundation.dart';

import '../../../domain/entities/share_payload.dart';

@immutable
class TopScorersShareEntryData {
  final int rank;
  final String displayName;
  final int goals;
  final bool isGuest;
  final String? photoUrl;
  final String initials;

  const TopScorersShareEntryData({
    required this.rank,
    required this.displayName,
    required this.goals,
    required this.isGuest,
    this.photoUrl,
    this.initials = 'ح',
  });

  String get goalLabel => goals == 1 ? '1 هدف' : '$goals أهداف';
}

@immutable
class TopScorersShareData {
  final String title;
  final String tournamentName;
  final List<TopScorersShareEntryData> scorers;
  final String brandLabel;
  final SharePayload? sharePayload;

  const TopScorersShareData({
    required this.title,
    required this.tournamentName,
    required this.scorers,
    this.brandLabel = 'الحريف',
    this.sharePayload,
  });
}
